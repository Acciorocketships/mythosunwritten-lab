#!/usr/bin/env bash
# What the biome tint costs in materials and in build time. See measure_tint.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_tint.gd -- "$@"
