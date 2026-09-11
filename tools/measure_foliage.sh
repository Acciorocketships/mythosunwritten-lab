#!/usr/bin/env bash
# How often a tree stands between the playing camera and the person, and where
# the worst place to stand is. See measure_foliage.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_foliage.gd -- "$@"
