#!/usr/bin/env bash
# Print what a character carries and what it has on, headless: one inventory per
# character, equipment as a view onto it, an item picked up off the ground and
# dropped back, the defeat drop landing where somebody can take it, money moving
# either way, and two characters with the same things in different orders.
#
#   ./run_inventory.sh
#
# Every number comes from sim/ and a fixed seed written into bin/inventory_main.gd;
# nothing here chooses anything and nothing draws. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/inventory_main.gd"
