#!/usr/bin/env bash
# An inventory operated from key presses, in one seeded run.
# See play_inventory.gd. Draws nothing, so it runs headless.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/play_inventory.gd -- "$@"
