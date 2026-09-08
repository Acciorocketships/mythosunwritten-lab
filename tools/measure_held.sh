#!/usr/bin/env bash
# Measure the hand-slot bones and the held gear models. See measure_held.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_held.gd -- "$@"
