#!/usr/bin/env bash
# Print a walk tick by tick, off the snapshot the render layer gets. See
# measure_walk.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_walk.gd -- "$@"
