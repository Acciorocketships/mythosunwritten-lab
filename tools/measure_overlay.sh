#!/usr/bin/env bash
# What the board overlay costs once it follows the ground, and where a slope is.
# See measure_overlay.gd. Draws nothing, so it runs headless.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/measure_overlay.gd -- "$@"
