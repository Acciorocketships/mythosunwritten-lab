#!/usr/bin/env bash
# Why a pile on the ground cannot be seen: rows, placements and drawn sizes.
# See measure_ground_read.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_ground_read.gd -- "$@"
