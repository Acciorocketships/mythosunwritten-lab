#!/usr/bin/env bash
# Produce the upstream delta for a re-import, sorted into what may be applied
# and what has to be decided.
#
#   ./tools/upstream_delta.sh                 # pin..upstream HEAD, into a temp dir
#   ./tools/upstream_delta.sh --out DIR       # ...into DIR (must not exist)
#   ./tools/upstream_delta.sh --old HASH      # pretend the pin was HASH (rehearsal)
#   ./tools/upstream_delta.sh --new HASH      # stop at HASH instead of upstream HEAD
#
# This repository did not merge mythosunwritten, it squash-imported the tree at
# a pinned commit (ADOPTION.md, "Import method"), so the two histories share no
# ancestor and `git merge` has nothing to merge. Taking an upstream update means
# applying the old-pin..new-HEAD delta to the adopted paths, by hand where it
# touches something this project has built on, and then advancing the pin.
# This script does the mechanical half and names the rest.
#
# It writes a work directory and changes nothing in this checkout. It clones the
# source repo blobless and read-only; it never pushes there.
#
# Exit codes:
#   0  a delta was produced; read the classification it printed
#   1  the pin is already the new HEAD -- nothing to import
#   2  the delta could not be produced (no network, unreadable pin, bad hash)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO="$PWD"

ADOPTION="ADOPTION.md"
OUT=""; OLD=""; NEW=""

fail() { echo "upstream-delta: CANNOT RUN -- $*" >&2; exit 2; }

while (( $# )); do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    --old) OLD="${2:-}"; shift 2 ;;
    --new) NEW="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) fail "unknown argument $1" ;;
  esac
done

# The pin and the URL live in ADOPTION.md and nowhere else; this script carries
# no copy of either, exactly as tools/upstream_watch.sh does not.
[[ -r "$ADOPTION" ]] || fail "$ADOPTION is not readable from $REPO"
PIN="$(sed -n 's/^- Source commit: `\([0-9a-f]\{40\}\)`.*/\1/p' "$ADOPTION" | head -1)"
URL="$(sed -n 's|^- Source: \(https\?://[^ ]*\)$|\1|p' "$ADOPTION" | head -1)"
[[ -n "$PIN" ]] || fail "no 40-hex 'Source commit' line found in $ADOPTION"
[[ -n "$URL" ]] || fail "no 'Source:' URL line found in $ADOPTION"
[[ -n "$OLD" ]] || OLD="$PIN"

# The adoption commit is the one that added ADOPTION.md. Everything this repo
# has changed since is a candidate for conflict, so it is derived, not listed.
IMPORT_COMMIT="$(git log --diff-filter=A --format=%H -- "$ADOPTION" | tail -1)"
[[ -n "$IMPORT_COMMIT" ]] || fail "cannot find the commit that added $ADOPTION"

if [[ -z "$OUT" ]]; then OUT="$(mktemp -d -t upstream-delta-XXXXXX)"; else
  [[ -e "$OUT" ]] && fail "$OUT already exists; give a path that does not"
  mkdir -p "$OUT" || fail "cannot create $OUT"
fi
OUT="$(cd "$OUT" && pwd)"

# --- 1. the two upstream trees, cheaply ------------------------------------
# A blobless clone downloads commits and trees only (about 2 MB for their ~950
# commits); each checkout then fetches just the blobs that tree needs. A full
# history clone is ~189 MB (ADOPTION.md).
echo "upstream-delta: cloning $URL blobless into $OUT/up.git"
git clone --quiet --filter=blob:none --no-checkout "$URL" "$OUT/up.git" \
  || fail "clone failed (no network?)"
if [[ -z "$NEW" ]]; then
  NEW="$(git -C "$OUT/up.git" rev-parse HEAD)" || fail "cannot read upstream HEAD"
fi
OLD="$(git -C "$OUT/up.git" rev-parse --verify --quiet "$OLD^{commit}")" \
  || fail "old commit not found upstream"
NEW="$(git -C "$OUT/up.git" rev-parse --verify --quiet "$NEW^{commit}")" \
  || fail "new commit not found upstream"

if [[ "$OLD" == "$NEW" ]]; then
  echo "upstream-delta: nothing to import -- ${OLD:0:8} is already the new HEAD"
  exit 1
fi
echo "upstream-delta: delta ${OLD:0:8}..${NEW:0:8} ($(git -C "$OUT/up.git" rev-list --count "$OLD..$NEW") upstream commit(s))"
git -C "$OUT/up.git" worktree add --quiet --detach "$OUT/old" "$OLD" || fail "cannot check out $OLD"
git -C "$OUT/up.git" worktree add --quiet --detach "$OUT/new" "$NEW" || fail "cannot check out $NEW"

# --- 2. the carve-outs, from ADOPTION.md's "What was deliberately left out" --
# Paths the adoption did not take. A delta that touches one is dropped, not
# applied; if this list and that table ever disagree, the table wins.
CARVE=(':(exclude).superpowers' ':(exclude).cursor' ':(exclude).cursorignore'
       ':(exclude).vscode' ':(exclude).editorconfig' ':(exclude).gitattributes'
       ':(exclude)icon.svg.import' ':(exclude)assets' ':(exclude)addons')
# The paths the adoption resolved by hand rather than by copy. These never go
# into the mechanical patch.
DECIDE=(':(exclude)project.godot' ':(exclude).gitignore' ':(exclude)tests/test_biomes.gd')

# --- 3. the patches ---------------------------------------------------------
git -C "$OUT/up.git" diff --binary "$OLD" "$NEW" -- . "${CARVE[@]}" "${DECIDE[@]}" \
  > "$OUT/delta-apply.patch"
# tests/test_biomes.gd was imported under a different name, because this repo
# already had one. The patch is retargeted rather than the file re-collided.
git -C "$OUT/up.git" diff --binary "$OLD" "$NEW" -- tests/test_biomes.gd \
  | sed -e 's#a/tests/test_biomes\.gd#a/tests/test_mythos_biomes.gd#' \
        -e 's#b/tests/test_biomes\.gd#b/tests/test_mythos_biomes.gd#' \
  > "$OUT/delta-rename.patch"
git -C "$OUT/up.git" diff "$OLD" "$NEW" -- project.godot > "$OUT/decide-project.godot.patch"
git -C "$OUT/up.git" diff "$OLD" "$NEW" -- .gitignore     > "$OUT/decide-gitignore.patch"

# --- 4. the classification --------------------------------------------------
{
  git -C "$OUT/up.git" diff --name-only "$OLD" "$NEW" > "$OUT/.all"
  git -C "$OUT/up.git" diff --name-only "$OLD" "$NEW" -- . "${CARVE[@]}" "${DECIDE[@]}" \
    > "$OUT/.mechanical"
  comm -23 <(sort "$OUT/.all") <(sort "$OUT/.mechanical") > "$OUT/.notmechanical"

  # Paths this repo has touched since the import, and the adopted scripts whose
  # global class names this project's own code calls. Both are derived here so
  # that neither is a remembered list.
  git -C "$REPO" diff --name-only "$IMPORT_COMMIT" HEAD | sort > "$OUT/.changed-here"
  comm -12 <(sort "$OUT/.mechanical") "$OUT/.changed-here" > "$OUT/decide-rewritten-here.txt"
  python3 - "$REPO" "$IMPORT_COMMIT" "$OUT" <<'PY'
import os, re, subprocess, sys
repo, import_commit, out = sys.argv[1], sys.argv[2], sys.argv[3]
def git(*a): return subprocess.run(["git","-C",repo,*a],capture_output=True,text=True).stdout
adopted = set(git("show","--name-only","--diff-filter=A","--format=",import_commit).split())
here = [p for p in git("ls-tree","-r","--name-only","HEAD").split()
        if p and p not in adopted and not p.endswith(".uid")
        and p.split("/")[0] not in ("assets", "reports")]
decl = {}
for p in adopted:
    if p.endswith(".gd") and os.path.isfile(os.path.join(repo, p)):
        m = re.search(r'^class_name\s+([A-Za-z0-9_]+)',
                      open(os.path.join(repo,p),encoding="utf-8",errors="ignore").read(4000), re.M)
        if m: decl[m.group(1)] = p
used = {}
for p in here:
    fp = os.path.join(repo, p)
    if not os.path.isfile(fp): continue
    txt = open(fp, encoding="utf-8", errors="ignore").read()
    for c in set(re.findall(r'\b[A-Z][A-Za-z0-9_]{3,}\b', txt)):
        if c in decl: used.setdefault(decl[c], set()).add((c, p))
touched = set(open(out+"/.mechanical").read().split())
with open(out+"/decide-built-on.txt","w") as fh:
    for path in sorted(used):
        if path in touched:
            for c, p in sorted(used[path]):
                fh.write(f"{path}\t{c}\t{p}\n")
PY

  echo
  echo "upstream-delta: ${OLD:0:8}..${NEW:0:8}, $(wc -l < "$OUT/.all") changed path(s)"
  echo "  apply mechanically  : $(wc -l < "$OUT/.mechanical")  -> git apply --binary $OUT/delta-apply.patch"
  echo "  dropped as carve-out: $(comm -23 "$OUT/.notmechanical" <(printf 'project.godot\n.gitignore\ntests/test_biomes.gd\n' | sort) | wc -l)"
  echo "  decide by hand      :"
  [[ -s "$OUT/decide-project.godot.patch" ]] && \
    echo "      project.godot            re-run tools/upstream_merge_project_godot.py at the new pin"
  [[ -s "$OUT/decide-gitignore.patch" ]] && \
    echo "      .gitignore               merge into the adopted block; the raw hunk will not apply"
  [[ -s "$OUT/delta-rename.patch" ]] && \
    echo "      tests/test_biomes.gd     retargeted to tests/test_mythos_biomes.gd (patch written)"
  n="$(wc -l < "$OUT/decide-rewritten-here.txt")"
  echo "      $n adopted path(s) this repo has rewritten since the import"
  sed 's/^/          /' "$OUT/decide-rewritten-here.txt"
  m="$(cut -f1 "$OUT/decide-built-on.txt" | sort -u | wc -l)"
  echo "      $m changed adopted script(s) this project's own code calls into:"
  awk -F'\t' '{print "          " $1 "  (" $2 " used by " $3 ")"}' "$OUT/decide-built-on.txt"
  echo
  echo "  new global class_name(s) upstream introduces (each a fresh collision risk):"
  git -C "$OUT/up.git" diff "$OLD" "$NEW" -- '*.gd' \
    | sed -n 's/^+class_name \([A-Za-z0-9_]*\).*/\1/p' | sort -u \
    | while read -r c; do
        h="$(git -C "$REPO" grep -l "^class_name $c\$" -- sim/ net/ render/ bin/ tools/ tests/ 2>/dev/null | tr '\n' ' ')"
        printf '      %-32s %s\n' "$c" "${h:+COLLIDES with $h}"
      done
  echo
  echo "  then: godot4 --headless --path . --import   (new scripts have no .uid sidecar yet)"
  echo "        edit the two Provenance lines in $ADOPTION to ${NEW:0:8}"
  echo "        ./tools/upstream_watch.sh  &&  ./tools/upstream_watch.sh --pins"
} | tee "$OUT/classification.txt"
rm -f "$OUT/.all" "$OUT/.mechanical" "$OUT/.notmechanical" "$OUT/.changed-here"
echo "upstream-delta: work directory $OUT"
