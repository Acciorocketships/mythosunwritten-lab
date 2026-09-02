#!/usr/bin/env bash
# Fetch the free KayKit asset packs from itch.io into assets/.
#
#   ./tools/fetch_kaykit.sh              # fetch every pack the table points at
#   ./tools/fetch_kaykit.sh kaykit-forest
#
# The packs are CC0 (public domain) and free at name-your-own-price, so this
# needs no account and no sign-in. The binaries are NOT committed -- see the
# README section "Where the art comes from" -- so this is what a fresh clone
# runs to get a world that renders as art rather than as coloured primitives.
#
# The itch.io download flow, which this reproduces with curl:
#   1. GET any page on the site to receive the itchio_token cookie, which is
#      also the CSRF token the site's own javascript posts back.
#   2. POST <game>/download_url with that token. This is what the page's
#      "No thanks, just take me to the downloads" link does; it answers with a
#      short-lived download-page URL and puts a download key in the session.
#   3. GET that page and read the upload ids off the download buttons.
#   4. POST <game>/file/<upload_id> with the token, which answers with a signed
#      storage URL, and follow it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

DEST="assets"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
JAR="$WORK/cookies.txt"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126 Safari/537.36"

# slug -> directory under assets/. One directory per pack, named for the pack.
declare -A PACKS=(
	[kaykit-forest]=kaykit_forest_nature
	[city-builder-bits]=kaykit_city_builder_bits
	[kaykit-medieval-builder-pack]=kaykit_medieval_builder
	[kaykit-dungeon-pack]=kaykit_dungeon_remastered
	[kaykit-adventurers]=kaykit_adventurers
	[halloween-bits]=kaykit_halloween_bits
	[resource-bits]=kaykit_resource_bits
	[kaykit-medieval-hexagon]=kaykit_medieval_hexagon
	[kaykit-skeletons]=kaykit_skeletons
	[kaykit-character-animations]=kaykit_character_animations
	[board-game-bits]=kaykit_board_game_bits
	# Named by the design but NOT free: the three Mystery Monthly series are
	# $19.99 each on itch.io. Asking for one by name gives the exact refusal
	# ("you must buy this game to download"); they are not in the default list.
	[kaykit-series-4]=kaykit_mystery_series_4
	[kaykit-series-5]=kaykit_mystery_series_5
	[kaykit-series-6]=kaykit_mystery_series_6
)

WANTED=("$@")
if [ ${#WANTED[@]} -eq 0 ]; then
	WANTED=(kaykit-forest city-builder-bits kaykit-medieval-builder-pack \
		kaykit-dungeon-pack kaykit-adventurers halloween-bits resource-bits \
		kaykit-medieval-hexagon kaykit-skeletons kaykit-character-animations \
		board-game-bits)
fi

# 1. A token. Any page on the site sets it; the site's javascript reads the same
#    cookie and posts it back as csrf_token, so we do exactly that.
curl -sS -c "$JAR" -A "$UA" https://kaylousberg.itch.io/ -o /dev/null
CSRF=$(python3 - "$JAR" <<'PY'
import re, sys, urllib.parse
m = re.search(r'itchio_token\s+(\S+)', open(sys.argv[1]).read())
if not m:
	sys.exit("no itchio_token cookie: itch.io did not hand out a session")
print(urllib.parse.unquote(m.group(1)))
PY
)

fetch_pack() {
	local slug="$1" dir="${PACKS[$1]:-}"
	[ -n "$dir" ] || { echo "unknown pack '$slug'" >&2; return 1; }
	local out="$DEST/$dir"
	if [ -d "$out" ] && [ -n "$(find "$out" -name '*.gltf' -o -name '*.glb' 2>/dev/null | head -1)" ]; then
		echo "== $slug -> $out (already installed, skipping)"
		return 0
	fi
	echo "== $slug -> $out"
	local game="https://kaylousberg.itch.io/$slug"

	# 2. The "no thanks, just take me to the downloads" step. A paid pack answers
	#    {"errors":["you must buy this game to download"]} here, which is the
	#    exact refusal worth reporting rather than a traceback.
	local page
	page=$(curl -sS -b "$JAR" -c "$JAR" -A "$UA" --data-urlencode "csrf_token=$CSRF" \
		"$game/download_url" | python3 -c '
import json, sys
r = json.load(sys.stdin)
if "url" not in r:
	sys.exit("  itch.io refused %s: %s" % ("'"$slug"'", "; ".join(r.get("errors", [str(r)]))))
print(r["url"])') || return 1

	# 3. The upload ids, with their names, off the download page.
	rm -f "$WORK/dl.html"
	curl -sS -b "$JAR" -c "$JAR" -A "$UA" "$page" -o "$WORK/dl.html"
	mapfile -t uploads < <(python3 - "$WORK/dl.html" <<'PY'
import re, sys
html = open(sys.argv[1]).read()
for block in re.findall(r'<div class="upload">.*?(?=<div class="upload">|<div class="trouble_link")', html, re.S):
	uid = re.search(r'data-upload_id="(\d+)"', block)
	name = re.search(r'class="name"[^>]*>([^<]*)<', block) or re.search(r'title="([^"]*)" class="name"', block)
	paid = re.search(r'data-min_price="(\d+)"', block)
	if uid and not paid:
		print("%s\t%s" % (uid.group(1), (name.group(1) if name else "download").strip()))
PY
	)
	[ ${#uploads[@]} -gt 0 ] || { echo "  no free upload on $slug" >&2; return 1; }

	mkdir -p "$out"
	for row in "${uploads[@]}"; do
		local uid="${row%%$'\t'*}" name="${row#*$'\t'}"
		echo "   upload $uid ($name)"
		# 4. A signed storage URL for that upload, then the bytes.
		local url
		url=$(curl -sS -b "$JAR" -c "$JAR" -A "$UA" -H "X-Requested-With: XMLHttpRequest" \
			--data-urlencode "csrf_token=$CSRF" "$game/file/$uid?source=game_download" \
			| python3 -c 'import json,sys; print(json.load(sys.stdin)["url"])')
		curl -sSL -A "$UA" "$url" -o "$WORK/pack.zip"
		unzip -q -o "$WORK/pack.zip" -d "$out"
		rm -f "$WORK/pack.zip"
	done

	# Godot imports glTF; the duplicate FBX/OBJ/Blend copies of the same models
	# are dead weight in the import cache, so they go.
	# Some packs ship read-only files; make them writable before pruning.
	chmod -R u+w "$out"
	find "$out" -type f \( -iname '*.fbx' -o -iname '*.obj' -o -iname '*.mtl' \
		-o -iname '*.blend' -o -iname '*.blend1' -o -iname '*.unitypackage' \) -delete
	find "$out" -type d -empty -delete
	echo "   $(find "$out" \( -name '*.gltf' -o -name '*.glb' \) | wc -l) glTF models"
}

for slug in "${WANTED[@]}"; do
	fetch_pack "$slug" || echo "!! $slug failed" >&2
done

echo
echo "Installed under $DEST/:"
for d in "$DEST"/kaykit_*; do
	[ -d "$d" ] || continue
	printf '  %-34s %5s models  %s\n' "$(basename "$d")" \
		"$(find "$d" \( -name '*.gltf' -o -name '*.glb' \) | wc -l)" \
		"$(du -sh "$d" | cut -f1)"
done
