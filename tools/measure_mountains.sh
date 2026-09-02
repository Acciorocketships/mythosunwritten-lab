#!/usr/bin/env bash
# How much relief the ground has, and whether a character can walk to the top
# of it. See measure_mountains.gd. Reads the fields headless; no display needed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/measure_mountains.gd -- "$@"
