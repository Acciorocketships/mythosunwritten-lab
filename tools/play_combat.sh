#!/usr/bin/env bash
# A whole fight played from key presses, in one seeded run: entered from real
# time, taken a turn at a time, and left for real time again.
# See play_combat.gd. Draws nothing, so it runs headless.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/play_combat.gd -- "$@"
