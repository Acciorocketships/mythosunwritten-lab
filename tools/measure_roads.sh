#!/usr/bin/env bash
# Where roads run together, and whether the roadway is walkable. See
# tools/measure_roads.gd. Reads the fields headless; no display needed.
#
#   ./tools/measure_roads.sh
#   ./tools/measure_roads.sh --seed 1234 --at -157.2 49.1 --within 1.85
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/measure_roads.gd -- "$@"
