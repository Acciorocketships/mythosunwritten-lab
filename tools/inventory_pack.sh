#!/usr/bin/env bash
# Inventory an installed pack: model, triangles, size, floor, albedo. See
# tools/inventory_pack.gd.
#
#   ./tools/inventory_pack.sh assets/justcreate_village --require-textures
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/inventory_pack.gd -- "$@"
