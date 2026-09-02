#!/usr/bin/env bash
# Print the size of every installed pack model, as drawn. See measure_models.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_models.gd -- "$@"
