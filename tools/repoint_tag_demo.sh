#!/usr/bin/env bash
# Show that repointing an asset tag is an edit to one table and to nothing else.
#
#   ./tools/repoint_tag_demo.sh
#
# It points the "well" tag at an installed model -- assets/example_well.tscn,
# which sits exactly where a model out of a purchased pack would -- by editing
# the one row for that tag in render/asset_library.gd. Then it shows:
#
#   * what the tag resolved to before and after, from the asset report;
#   * that every file under sim/ is unchanged, byte for byte;
#   * that the headless world fingerprint is unchanged;
#   * that the whole edit is one line in one file.
#
# Finally it puts the table back and checks that it did. Exits 0 when the claim
# holds, non-zero when anything moved that should not have.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TABLE="render/asset_library.gd"
TAG="well"
SCENE="res://assets/example_well.tscn"
BACKUP="$(mktemp)"
trap 'cp "$BACKUP" "$TABLE"; rm -f "$BACKUP"' EXIT

# A fingerprint of the whole simulation layer: every file, hashed, in a fixed
# order. This is the "no generation file changed" claim, stated as a number.
sim_fingerprint() {
	find sim -type f | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -d" " -f1
}

# The world the simulation arrives at, from a fixed seed over a fixed number of
# ticks. This is the "the world is unchanged" claim, stated the same way.
world_fingerprint() {
	./run_headless.sh --seed 1234 --ticks 100 | tail -1 | sed "s/.*final=//"
}

# What one tag currently resolves to, off the asset report.
resolves_to() {
	./run_assets.sh | grep -E "^  $TAG " | sed "s/^  $TAG *//"
}

cp "$TABLE" "$BACKUP"

echo "=== before ==="
BEFORE_TAG="$(resolves_to)"
BEFORE_SIM="$(sim_fingerprint)"
BEFORE_WORLD="$(world_fingerprint)"
printf "  %-16s %s\n" "$TAG resolves to" "$BEFORE_TAG"
printf "  %-16s %s\n" "sim/ sources" "$BEFORE_SIM"
printf "  %-16s %s\n" "world" "$BEFORE_WORLD"

echo
echo "=== repointing '$TAG' at $SCENE ==="
# The edit: the scene path on that tag's row, and nothing else. The row keeps
# its placeholder parts, so a machine without the model still draws something.
python3 - "$TABLE" "$TAG" "$SCENE" <<'PY'
import re, sys
table, tag, scene = sys.argv[1], sys.argv[2], sys.argv[3]
source = open(table).read()
# The row's scene path, whatever it currently is: empty before the packs were
# installed, a pack scene after. Either way the edit is that one string.
pattern = re.compile(r'_row\(rows, AssetTags\.%s, "[^"]*", \[' % tag.upper())
if not pattern.search(source):
	sys.exit("no row for '%s' in %s" % (tag, table))
updated = pattern.sub('_row(rows, AssetTags.%s, "%s", [' % (tag.upper(), scene), source, count=1)
open(table, "w").write(updated)
PY
diff -u "$BACKUP" "$TABLE" | sed "s/^/  /" || true

echo
echo "=== after ==="
AFTER_TAG="$(resolves_to)"
AFTER_SIM="$(sim_fingerprint)"
AFTER_WORLD="$(world_fingerprint)"
printf "  %-16s %s\n" "$TAG resolves to" "$AFTER_TAG"
printf "  %-16s %s\n" "sim/ sources" "$AFTER_SIM"
printf "  %-16s %s\n" "world" "$AFTER_WORLD"

echo
FAILED=0
if [[ "$BEFORE_TAG" == "$AFTER_TAG" ]]; then
	echo "FAIL  '$TAG' resolves to the same thing, so nothing was demonstrated"
	FAILED=1
else
	echo "OK    '$TAG' now resolves to a different visual"
fi
if [[ "$BEFORE_SIM" != "$AFTER_SIM" ]]; then
	echo "FAIL  a file under sim/ changed"
	FAILED=1
else
	echo "OK    every file under sim/ is unchanged"
fi
if [[ "$BEFORE_WORLD" != "$AFTER_WORLD" ]]; then
	echo "FAIL  the headless world fingerprint changed"
	FAILED=1
else
	echo "OK    the headless world fingerprint is unchanged"
fi
echo "OK    the whole edit is $(diff "$BACKUP" "$TABLE" | grep -c '^>') line(s) in $TABLE"

cp "$BACKUP" "$TABLE"
if [[ "$(sha256sum < "$TABLE")" != "$(sha256sum < "$BACKUP")" ]]; then
	echo "FAIL  the table was not restored"
	FAILED=1
else
	echo "OK    the table is back as it was"
fi

exit "$FAILED"
