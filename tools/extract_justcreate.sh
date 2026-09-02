#!/usr/bin/env bash
# Unpack the JustCreate "Fantasy Village" FBX pack the user dropped in assets/.
#
#   ./tools/extract_justcreate.sh
#
# The archive stays where it is; this only writes assets/justcreate_village/,
# which is ignored by git for the same reason the KayKit packs are -- it is
# reproducible from a file already on disk, so carrying 12 MB of binaries in
# every clone buys nothing. README, "Where the art comes from".
#
# One thing is done beyond unzipping. Every FBX in the pack names its texture by
# an absolute Windows path (C:\JustCreate\Project012\Unity\Textures\Texture_01.png)
# which resolves nowhere here; Godot then falls back to the basename *next to the
# model*, and the pack ships its one atlas at the archive root instead. So the
# atlas is copied into each model directory. That is the whole fix -- no material
# path is hand-edited, and tools/check_justcreate_textures.sh proves the binding.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ARCHIVE="assets/Models_FBX_FantasyVillage_1.42.zip"
DEST="assets/justcreate_village"

if [[ ! -f "$ARCHIVE" ]]; then
	echo "archive not found at $ARCHIVE" >&2
	echo "this pack is the user's purchase; it is not fetched by any script" >&2
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

# The atlas beside every model, so the importer's basename fallback finds it.
ATLAS="$DEST/Texture_01.png"
[[ -f "$ATLAS" ]] || { echo "pack atlas missing from archive" >&2; exit 1; }
COPIES=0
while IFS= read -r dir; do
	[[ "$dir" == "$DEST" ]] && continue
	cp "$ATLAS" "$dir/"
	COPIES=$((COPIES + 1))
done < <(find "$DEST" -type d)

echo "extracted $(find "$DEST" -name '*.fbx' | wc -l) models into $DEST"
echo "atlas copied into $COPIES model directories"
