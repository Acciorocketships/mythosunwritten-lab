#!/usr/bin/env bash
# Print what the enemy layer costs a tick, measured against the same world with
# the layer switched off. See measure_enemies.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_enemies.gd -- "$@"
