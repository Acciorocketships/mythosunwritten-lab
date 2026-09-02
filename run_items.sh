#!/usr/bin/env bash
# Print the item layer's own tables headless: the rarity multipliers, sixty
# forged items against their budgets, the movement-against-defence trade, and
# the ability-score gate worked through one item.
#
#   ./run_items.sh
#
# Every number comes from sim/ and a fixed seed written into bin/items_main.gd;
# nothing here chooses anything. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/items_main.gd"
