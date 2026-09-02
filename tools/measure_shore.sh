#!/usr/bin/env bash
# How near the water the world's villages stand. See measure_shore.gd.
# Reads the fields headless; no display needed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/measure_shore.gd -- "$@"
