#!/usr/bin/env bash
# Unpack the two Daniel Mistage STYLIZED packs this project draws from -- Fantasy
# Village and Fantasy Market -- out of the .rar files the user dropped in assets/.
#
#   ./tools/extract_mistage.sh
#
# The archives stay where they are; this only writes assets/mistage_village/ and
# assets/mistage_market/, both ignored by git for the same reason the JustCreate
# pack is: they are reproducible from a file already on disk, and paid art is not
# something to redistribute. README, "Where the art comes from".
#
# ---------------------------------------------------------------------------
# The texture fix, which is the only thing done here beyond unpacking
# ---------------------------------------------------------------------------
# Every FBX in both packs names its textures by an absolute Windows path off the
# artist's own machine:
#
#   C:\Users\DanielPC\Armory Built In\Assets\Daniel Mistage\
#       STYLIZED Fantasy Village - Low Poly 3D Art\Textures\TEXTURE_BLUE.png
#
# None of those resolve here, so Godot falls back to looking for the *basename*
# beside the model and in its parent directories (verified: three levels up still
# binds). The archives ship the same atlases under different names -- prefixed
# SFV_ for the village and SFT_ for the market -- so the whole fix is to put each
# shipped atlas at the pack root under the basename the FBX asks for. Five files.
# No material path is hand-edited and no FBX is rewritten.
#
# The four names the village FBX ask for and the two the market FBX ask for were
# read straight out of the binaries; the mapping below is that list, and
# tools/mistage_textures.py --report reprints it from the archives.
#
# One basename in the village pack has no shipped counterpart: TEXTURE.png, which
# the FBX resolve to "STYLIZED The Alchemist's Workshop", a different Mistage
# pack. It is named by exactly two of the village's eight materials --
# SFV_TRANSPARENT (window glass) and SFV_DOUBLE_SIDED_MATERIAL (ivies, six
# flowers) -- and by no model's main material. See reports/mistage-packs.md.
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

unpack assets/mistage_village assets/FantasyVillageFBX.rar \
	"SFV_TEXTURE_BLUE.png=TEXTURE_BLUE.png" \
	"SFV_TEXTURE_ORANGE.png=TEXTURE_BRICK.png" \
	"SFV_NATURE.png=NATURE.png"

unpack assets/mistage_market assets/FantasyMarketFBX.rar \
	"SFT_MAIN_TEXTURE.png=TEXTURE.png" \
	"SFT_NATURE_TEXTURE.png=NATURE 2.png"
