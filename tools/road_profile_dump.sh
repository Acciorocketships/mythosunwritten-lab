#!/usr/bin/env bash
# The ground along a road through a junction, as CSV on stdout. See
# tools/road_profile_dump.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/road_profile_dump.gd -- "$@"
