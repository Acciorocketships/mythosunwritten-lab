#!/usr/bin/env bash
# The numbers behind the rules the island grass is written in, headless.
# See survey_island_grass.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/survey_island_grass.gd -- "$@"
