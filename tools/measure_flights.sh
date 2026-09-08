#!/usr/bin/env bash
# Print what each shipped attack flies as, and how many take the fallback
# body. See tools/measure_flights.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/measure_flights.gd
