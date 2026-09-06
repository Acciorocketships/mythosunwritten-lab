#!/usr/bin/env bash
# Draw randomly generated items, one row per rarity tier, as a contact sheet.
#
#   ./run_item_sheet.sh                                       # in a window
#   xvfb-run -a ./run_item_sheet.sh --screenshot "$PWD/items.png"
#   ./run_item_sheet.sh --seed 7                              # a different draw
#   ./run_item_sheet.sh --pile                                # one heap, from above
#
# Needs a display. This is the item layer's output looked at rather than read:
# every item on it is one the forge really produced, resolved through the
# asset-tag table into a model. The simulation is not running behind it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec "$GODOT" --path . --resolution 1800x1200 res://render/item_sheet.tscn -- "$@"
