#!/usr/bin/env bash
# Run just the flight suite headless: the objects that cross the board when a
# blow travels. Exits 0 when everything passes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/flight_suite.gd"
