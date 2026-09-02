#!/usr/bin/env bash
# What a board costs to read, and how many cells a fight spans.
# See measure_board.gd. Draws nothing, so it runs headless.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/measure_board.gd -- "$@"
