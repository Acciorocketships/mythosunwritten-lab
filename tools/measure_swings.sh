#!/usr/bin/env bash
# Which motion each weapon plays and when it starts and stops, off the same
# snapshot the render shell draws from. See tools/measure_swings.gd.
#
#   ./tools/measure_swings.sh [--ticks N]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_swings.gd -- "$@"
