#!/usr/bin/env bash
# Count which clip the rule chooses as the world walks. See measure_motion.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_motion.gd -- "$@"
