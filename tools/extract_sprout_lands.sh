#!/usr/bin/env bash
# Unpack the Sprout Lands UI pack the user chose as this project's UI kit, out of
# the zip they dropped in assets/.
#
#   ./tools/extract_sprout_lands.sh
#
# The archive stays where it is; this only writes assets/sprout_lands_ui/, which
# is ignored by git for the same reason the JustCreate and Mistage packs are --
# and for one reason more. The others are paid art nobody should redistribute;
# this one carries a licence that says so in as many words:
#
#   "You can modify the assets."
#   "You can not redistribute or resale, even if modified."
#   "You can only use these assets in non-commercial projects."
#       -- read_me.txt, Cup Nooble
#
# So: not in git, not fetchable by any script (there is deliberately no
# tools/fetch_sprout_lands.sh the way there is a tools/fetch_kaykit.sh), and a
# commercial release would need the paid Premium pack. README, "Where the art
# comes from".
#
# ---------------------------------------------------------------------------
# The six aliases, which are the only thing done here beyond unzipping
# ---------------------------------------------------------------------------
# The pack's own layout is a directory tree written for a person browsing it, not
# for a program: "Sprite sheets/Dialouge UI/", a spelling; one file whose name
# ends in a space before the extension; spaces everywhere. The render layer names
# six files out of it, so the extractor puts a flat alias for each at the pack
# root, exactly the way tools/extract_mistage.sh puts each shipped atlas under
# the basename its models ask for. render/ui/sprout_pack.gd names the aliases and
# nothing else, so a rename inside the pack is one line here rather than a search
# through the UI.
#
# Nothing is edited. An alias is a byte-for-byte copy of the pack file beside it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ARCHIVE="assets/Sprout Lands - UI Pack - Basic pack.zip"
DEST="assets/sprout_lands_ui"

if [[ ! -f "$ARCHIVE" ]]; then
	echo "archive not found at $ARCHIVE" >&2
	echo "this pack is the user's download; it is not fetched by any script" >&2
	echo "  https://cupnooble.itch.io/sprout-lands-ui-pack" >&2
	exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
python3 - "$ARCHIVE" "$DEST" <<'PY'
import sys, zipfile
archive, dest = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(archive) as z:
	z.extractall(dest)
PY

# The pack unzips into one directory named after itself; the aliases are written
# at $DEST so nothing outside this file ever spells that name.
ROOT="$DEST/Sprout Lands - UI Pack - Basic pack"
if [[ ! -d "$ROOT" ]]; then
	echo "the archive did not contain the expected pack directory" >&2
	exit 1
fi

# alias = pack file. The alias is what render/ui/sprout_pack.gd names.
alias_file() {
	local name="$1" source="$2"
	if [[ ! -f "$ROOT/$source" ]]; then
		echo "pack file missing from the archive: $source" >&2
		exit 1
	fi
	cp "$ROOT/$source" "$DEST/$name"
}

# The master sheet. Carries the wooden nine-slice frames the panel is built out
# of, which exist in no other file of the pack.
alias_file ui_sheet.png "Sprite sheets/Sprite sheet for Basic Pack.png"
# The buttons, as their own file: four tints, each an idle face with a drop
# shadow and a pressed face without one.
alias_file buttons.png "Sprite sheets/buttons/Square Buttons 26x26.png"
# The generic icon sheet: eighteen columns by three rows of 16x16, the same six
# icons in white, cream and tan.
alias_file icons.png "Sprite sheets/Icons/All Icons.png"
# The hearts, full and half and empty.
alias_file hearts.png "emojis-free/emoji style ui/Inventory_Herat_Spritesheet.png"
# The inventory slots: three sizes in three tints.
alias_file slots.png "emojis-free/emoji style ui/Inventory_Blocks_Spritesheet.png"
# The bundled pixel font, on an 8x14 cell.
alias_file pixel_font.ttf "fonts/pixelFont-7-8x14-sproutLands.ttf"

echo "extracted $(find "$ROOT" -type f | wc -l) pack files into $DEST"
echo "aliased $(cd "$DEST" && ls -1 ui_sheet.png buttons.png icons.png hearts.png slots.png pixel_font.ttf | wc -l) of them at the pack root"
echo "licence: non-commercial only, no redistribution even when modified -- see"
echo "  $ROOT/read_me.txt"
