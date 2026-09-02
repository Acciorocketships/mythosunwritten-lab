#!/usr/bin/env bash
# Measure every rigged model in the installed character packs and print the
# distinct skeletons they use. See measure_rigs.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_rigs.gd -- "$@"
