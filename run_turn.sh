#!/usr/bin/env bash
# Print the turn/action seam headless: two commanders on one board, both
# choosing to strike, and what the board waits for.
#
#   ./run_turn.sh
#
# A turn lasts as long as the weapon action that spends it, so a blow a
# commander chooses lands on that commander's own turn. The same duel is then
# played with one of the two unable to answer in time, to show that a turn
# nobody answered passes rather than holding the fight up. Two runs print
# identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/turn_main.gd"
