#!/usr/bin/env bash
# Print the world's record of a blow headless: two commanders on one board with
# the same spear, one played by hand through BoardTurn and one by its own
# decision function through the atomic action surface.
#
#   ./run_strike.sh
#
# Both spend their weapon action through the same call, so both blows are written
# into the same record with the same fields filled -- printed side by side, and
# then again as the snapshot carries them out to whatever draws them. Two runs
# print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/strike_main.gd"
