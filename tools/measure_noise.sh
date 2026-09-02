#!/usr/bin/env bash
# How noisy a saved frame is over a rectangle of its pixels. See
# measure_noise.gd. Reads pixels off disk, so it needs no display.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_noise.gd -- "$@"
