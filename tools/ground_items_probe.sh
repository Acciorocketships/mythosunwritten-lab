#!/usr/bin/env bash
# Print the numbers behind "items you can see": the gear table, how many shipped
# items take the fallback, one seeded run of the drops, and one round trip.
# See ground_items_probe.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/ground_items_probe.gd -- "$@"
