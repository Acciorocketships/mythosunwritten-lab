#!/usr/bin/env bash
# Print what a loadout is worth on a board headless: the price of every movement
# grant in cells, one board per loadout with the cells it reaches marked, the
# chestplate's ladder, the movement-against-defence trade at one budget, a
# front-on duel between equals at seven levels, and the ability-score gate.
#
#   ./run_loadout.sh
#
# Every number comes from sim/ and a board typed out in bin/loadout_main.gd;
# nothing here chooses anything and nothing draws. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/loadout_main.gd"
