#!/usr/bin/env bash
# Prove tools/upstream_delta.sh on a delta whose answer is already known.
#
#   ./tools/upstream_delta_rehearsal.sh [--back N] [--out DIR]
#
# --back N is `pin~N`, which walks *first parents*. Upstream merges its own
# branches, so a range that crosses a merge contains more than N commits and
# more changed paths than the walk suggests; the resolved commit and the true
# commit count are both printed rather than assumed.
#
# The import procedure has never been run for real -- upstream has not moved
# since the adoption. So it is rehearsed on history instead, where an oracle
# exists: take an upstream commit N commits before the pin, pretend the
# adoption had imported *that*, apply the delta from it up to the pin by the
# procedure, and the answer must be the adopted tree this repository already
# holds. Anything left over is a thing the procedure cannot do, and is printed
# rather than absorbed.
#
# Nothing here touches this checkout. Everything is built in a work directory
# and the source repo is cloned read-only.
#
# Exit codes:
#   0  the rehearsal reproduced the adopted tree, up to the residue it printed
#   1  it did not -- the differences are listed
#   2  the rehearsal could not run
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO="$PWD"
BACK=3; OUT=""
fail() { echo "rehearsal: CANNOT RUN -- $*" >&2; exit 2; }
while (( $# )); do
  case "$1" in
    --back) BACK="${2:-3}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) fail "unknown argument $1" ;;
  esac
done
[[ -z "$OUT" ]] && OUT="$(mktemp -d -t upstream-rehearsal-XXXXXX)"
[[ -d "$OUT" ]] || mkdir -p "$OUT" || fail "cannot create $OUT"
OUT="$(cd "$OUT" && pwd)"

PIN="$(sed -n 's/^- Source commit: `\([0-9a-f]\{40\}\)`.*/\1/p' ADOPTION.md | head -1)"
[[ -n "$PIN" ]] || fail "no pin in ADOPTION.md"
IMPORT_COMMIT="$(git log --diff-filter=A --format=%H -- ADOPTION.md | tail -1)"
[[ -n "$IMPORT_COMMIT" ]] || fail "cannot find the adoption commit"

# 1. The delta, produced by the procedure itself, from BACK commits before the pin.
echo "rehearsal: producing the delta (pin~$BACK .. pin) with tools/upstream_delta.sh"
rm -rf "$OUT/delta"
./tools/upstream_delta.sh --old "$PIN~$BACK" --new "$PIN" --out "$OUT/delta" >"$OUT/delta.log" 2>&1 \
  || { cat "$OUT/delta.log"; fail "tools/upstream_delta.sh failed"; }
sed -n '/changed path/,$p' "$OUT/delta.log"
OLD="$(git -C "$OUT/delta/up.git" rev-parse "$PIN~$BACK")"
echo "  --back $BACK resolves to ${OLD:0:8}; the range holds $(git -C "$OUT/delta/up.git" rev-list --count "$OLD..$PIN") upstream commit(s) (first-parent walk, so a merge in range widens it)"

# 2. The oracle: this repository exactly as the adoption commit left it.
echo "rehearsal: unpacking the oracle (this repo at the adoption commit)"
rm -rf "$OUT/oracle"; mkdir -p "$OUT/oracle"
git archive "$IMPORT_COMMIT" | tar -x -C "$OUT/oracle" || fail "cannot unpack the oracle"

# 3. The starting point: the same repository as if it had imported at OLD,
#    built forward from upstream@OLD by ADOPTION.md's import rules.
echo "rehearsal: building the repo-as-if-imported-at-${OLD:0:8}"
git show "$IMPORT_COMMIT^:project.godot" > "$OUT/ours-pre-project.godot" \
  || fail "cannot read this repo's pre-adoption project.godot"
python3 - "$REPO" "$OUT" "$PIN" "$OLD" "$IMPORT_COMMIT" <<'PY' || exit 2
import os, shutil, subprocess, sys
repo, out, pin, old, import_commit = sys.argv[1:6]
UP = out + "/delta/up.git"
def up(*a): return subprocess.run(["git","-C",UP,*a],capture_output=True,text=True).stdout

def tree(rev):
    d = {}
    for line in up("ls-tree","-r",rev).splitlines():
        meta, path = line.split("\t", 1)
        d[path] = meta.split()[2]
    return d

def repo_tree(rev):
    d = {}
    for line in subprocess.run(["git","-C",repo,"ls-tree","-r",rev],
                               capture_output=True,text=True).stdout.splitlines():
        meta, path = line.split("\t", 1)
        d[path] = meta.split()[2]
    return d

new_t, old_t, ora_t = tree(pin), tree(old), repo_tree(import_commit)
# The adopted set is derived, not remembered: every upstream path the adoption
# commit holds at the same path with the same bytes.
adopted = {p for p, h in new_t.items() if ora_t.get(p) == h}
RENAME = {"tests/test_biomes.gd": "tests/test_mythos_biomes.gd"}
adopted |= {v for k, v in RENAME.items() if ora_t.get(v) == new_t.get(k)}
CARVE_DIR = (".superpowers/", ".cursor/", ".vscode/", "assets/", "addons/")
CARVE = {".cursorignore", ".editorconfig", ".gitattributes", "icon.svg.import"}
DECIDE = {"project.godot", ".gitignore"}
carved = lambda p: p.startswith(CARVE_DIR) or p in CARVE

absent = sorted(p for p in new_t if p not in adopted and p not in DECIDE
                and p not in RENAME)
print(f"  upstream@{pin[:8]}: {len(new_t)} path(s); {len(adopted)} adopted byte-identically, "
      f"{len(DECIDE)} merged by hand, {len(RENAME)} renamed, {len(absent)} carved out")
leak = [p for p in absent if not carved(p)]
if leak: print("  UNEXPLAINED absence:", leak)

E = out + "/repoE"
if os.path.exists(E): shutil.rmtree(E)
shutil.copytree(out + "/oracle", E, symlinks=True)
# strip everything the adoption took from upstream, and its Godot .uid sidecar
for p in adopted:
    for f in (p, p + ".uid"):
        fp = os.path.join(E, f)
        if os.path.exists(fp): os.remove(fp)
# put upstream@OLD in its place, minus the carve-outs and the hand-merged files
copied = 0
for p in old_t:
    if carved(p) or p in DECIDE: continue
    dst = os.path.join(E, RENAME.get(p, p))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(os.path.join(out, "delta/old", p), dst); copied += 1
# the .uid sidecars Godot wrote at import time persist with the files that existed then
old_set = {RENAME.get(p, p) for p in old_t}
for p in adopted & old_set:
    s = os.path.join(out, "oracle", p + ".uid")
    if os.path.exists(s): shutil.copy2(s, os.path.join(E, p + ".uid"))
# project.godot: the documented section merge, re-run at OLD
merged = subprocess.run([sys.executable, repo + "/tools/upstream_merge_project_godot.py",
                         out + "/ours-pre-project.godot",
                         out + "/delta/old/project.godot", old[:8]],
                        capture_output=True, text=True)
open(E + "/project.godot", "w").write(merged.stdout)
# .gitignore: the adopted block carries only the rules upstream had at OLD
rules = lambda f: {l.strip() for l in open(f) if l.strip() and not l.startswith("#")}
rolled = rules(out + "/delta/new/.gitignore") - rules(out + "/delta/old/.gitignore")
open(E + "/.gitignore", "w").writelines(
    [l for l in open(out + "/oracle/.gitignore") if l.strip() not in rolled])
print(f"  repo-as-if-imported-at-{old[:8]}: {copied} upstream file(s) in place, "
      f"{len(rolled)} .gitignore rule(s) rolled back")
PY

# 4. Run the procedure forward over it.
echo "rehearsal: applying the delta by the procedure"
cd "$OUT/repoE" || fail "no repoE"
git apply --check --binary "$OUT/delta/delta-apply.patch" || fail "the mechanical patch does not apply"
git apply --binary "$OUT/delta/delta-apply.patch" || fail "apply failed"
git apply --binary "$OUT/delta/delta-rename.patch" || fail "the retargeted rename patch failed"
echo -n "  the raw .gitignore hunk, applied as-is: "
if git apply --check "$OUT/delta/decide-gitignore.patch" 2>/dev/null; then
  echo "APPLIES (unexpected -- the adopted block must have stopped diverging)"
else
  echo "refused, as it must -- ours is a merged file, so this is a hand decision"
fi
python3 "$REPO/tools/upstream_merge_project_godot.py" \
  "$OUT/ours-pre-project.godot" "$OUT/delta/new/project.godot" "${PIN:0:8}" > project.godot
python3 - "$OUT" <<'PY'
import sys
out = sys.argv[1]
# Their ignore rules live here as a labelled block, so the raw hunk cannot
# apply and there is no anchor line to splice new rules after -- an added rule
# may belong anywhere in the block, including above the ones already there.
# The block is therefore rebuilt rather than patched: it holds the rules the
# adoption took from them, kept in *their* order at the new commit. Membership
# is what the block already had plus what the delta adds; nothing is inserted
# at a guessed position, and nothing this repo handles in its own sections
# (.godot/, *.uid, assets/, addons/ ...) is dragged in by the reordering.
rules = lambda f: [l.rstrip("\n") for l in open(f) if l.strip() and not l.startswith("#")]
old, new = set(rules(out + "/delta/old/.gitignore")), rules(out + "/delta/new/.gitignore")
added = [l for l in new if l not in old]

lines = open(".gitignore").read().splitlines(keepends=True)
start = next(i for i, l in enumerate(lines) if l.startswith("# --- Adopted from mythosunwritten"))
first = next(i for i in range(start, len(lines)) if not lines[i].startswith("#"))
end = next(i for i in range(first, len(lines)) if not lines[i].strip())
held = {l.rstrip("\n") for l in lines[first:end]}
keep = [r for r in new if r in held or r in added]
open(".gitignore", "w").write(
    "".join(lines[:first]) + "".join(r + "\n" for r in keep) + "".join(lines[end:]))
print(f"  .gitignore decided by hand: block rebuilt in their order, "
      f"{len(held)} rule(s) held + {len(added)} added = {len(keep)}")
PY
cd "$REPO"

# 5. The oracle comparison.
echo "rehearsal: comparing against the adopted tree this repo actually holds"
diff -rq --no-dereference "$OUT/repoE" "$OUT/oracle" > "$OUT/residual.txt" 2>&1
DIFFER=$(grep -c '^Files .* differ' "$OUT/residual.txt" || true)
EXTRA=$(grep -c "^Only in $OUT/repoE" "$OUT/residual.txt" || true)
MISSING=$(grep -c "^Only in $OUT/oracle" "$OUT/residual.txt" || true)
NONUID=$(grep -v '\.uid$' "$OUT/residual.txt" | grep -c . || true)
echo "  content differences : $DIFFER"
echo "  extra in the result : $EXTRA"
echo "  missing from result : $MISSING   (all .uid sidecars: $([ "$NONUID" -eq 0 ] && echo yes || echo NO))"
if (( DIFFER == 0 && EXTRA == 0 && NONUID == 0 )); then
  echo "rehearsal: REPRODUCED -- the only residue is $MISSING Godot .uid sidecar(s) for files the"
  echo "           delta adds; 'godot4 --headless --path . --import' writes those. See"
  echo "           $OUT/residual.txt"
  exit 0
fi
echo "rehearsal: NOT reproduced -- see $OUT/residual.txt"
sed "s#$OUT/##g" "$OUT/residual.txt" | grep -v '\.uid$' | head -40
exit 1
