#!/usr/bin/env bash
# Draw the grass layer's clearing mask over a square of world. See
# grass_mask_map.gd. Needs no display.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --headless --path . --script res://tools/grass_mask_map.gd -- "$@"
