#!/usr/bin/env bash
# Unpack the three Daniel Mistage STYLIZED armoury packs -- Battle Pack, Forge &
# Armory, and the Alchemy Pack -- out of the .rar files the user dropped in
# assets/.
#
#   ./tools/extract_armoury.sh
#
# Same shape and same reasoning as tools/extract_mistage.sh, which does the
# village and the market: the archives stay where they are, this only writes
# assets/mistage_battle/, assets/mistage_forge/ and assets/mistage_alchemy/, and
# all three are ignored by git because they are reproducible from a file already
# on disk and paid art is not something to redistribute. README, "Where the art
# comes from".
#
# ---------------------------------------------------------------------------
# The texture fix, which is the only thing done here beyond unpacking
# ---------------------------------------------------------------------------
# Every FBX in all three packs names its textures by an absolute Windows path off
# the artist's own machine, so none of them resolve here and Godot falls back to
# looking for the *basename* beside the model and in its parent directories. Each
# pack ships its atlases at the archive root under a pack-prefixed name -- SFBP_
# for the battle pack, SFFA_ for the forge, AWS_ for the alchemy pack -- while
# the FBX ask for the unprefixed name. The whole fix is to put each shipped atlas
# at the pack root a second time under the basename the FBX asks for. Nine files
# across three packs. No material path is hand-edited and no FBX is rewritten.
#
# The mapping below is read straight out of the binaries;
# ./tools/fbx_texture_map.py assets/mistage_battle assets/mistage_forge \
#     assets/mistage_alchemy
# reprints it and is the evidence for it. Unlike the village pack, none of these
# three name an atlas belonging to a different pack: every basename asked for has
# a shipped counterpart, so after this script no material is left unbound.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BSDTAR="${BSDTAR:-}"
if [[ -z "$BSDTAR" ]]; then
	for candidate in bsdtar "$HOME/.miniforge3/bin/bsdtar" /usr/bin/bsdtar; do
		if command -v "$candidate" >/dev/null 2>&1; then BSDTAR="$candidate"; break; fi
	done
fi
if [[ -z "$BSDTAR" ]] || ! command -v "$BSDTAR" >/dev/null 2>&1; then
	echo "bsdtar not found; it is what reads RAR5 here (no unrar needed)" >&2
	echo "set BSDTAR=/path/to/bsdtar" >&2
	exit 127
fi

# pack | archive | shipped atlas -> the basename the FBX ask for, repeated
unpack() {
	local dest="$1" archive="$2"; shift 2
	if [[ ! -f "$archive" ]]; then
		echo "archive not found at $archive" >&2
		echo "this pack is the user's purchase; it is not fetched by any script" >&2
		exit 1
	fi
	rm -rf "$dest"
	mkdir -p "$dest"
	"$BSDTAR" xf "$archive" -C "$dest"
	local pair shipped wanted
	for pair in "$@"; do
		shipped="${pair%%=*}"
		wanted="${pair#*=}"
		if [[ ! -f "$dest/$shipped" ]]; then
			echo "pack atlas $shipped missing from $archive" >&2
			exit 1
		fi
		cp "$dest/$shipped" "$dest/$wanted"
	done
	echo "$(find "$dest" -name '*.fbx' | wc -l) models into $dest, $# atlas name(s) mapped"
}

unpack assets/mistage_battle assets/BattlePackFBX.rar \
	"SFBP_TEXTURE.png=TEXTURE.png" \
	"SFBP_TEXTURE_BLACK.png=TEXTURE_BLACK.png" \
	"SFBP_TEXTURE_BLUE.png=TEXTURE_BLUE.png" \
	"SFBP_TEXTURE_GREEN.png=TEXTURE_GREEN.png" \
	"SFBP_TEXTURE_PURPLE.png=TEXTURE_PURPLE.png" \
	"SFBP_TEXTURE_RED.png=TEXTURE_RED.png" \
	"SFBP_NATURE.png=NATURE.png"

unpack assets/mistage_forge assets/ForgeFBX.rar \
	"SFFA_MAIN_TEXTURE.png=TEXTURE.png"

unpack assets/mistage_alchemy assets/AlchemyPackFBX.rar \
	"AWS_MAIN_TEXTURE.png=TEXTURE.png"
