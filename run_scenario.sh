#!/usr/bin/env bash
# Print the character scenario headless: five characters -- one of them driven by
# a person's recorded choices, four by rules -- walking, speaking, trading,
# picking something up, and falling into a fight that snaps onto the tactical
# board and returns to real time when it resolves.
#
#   ./run_scenario.sh                 # 110 ticks, seed 1234
#   ./run_scenario.sh --ticks 200
#   ./run_scenario.sh --seed 7
#
# No window and no rendering at all. Every choice comes from sim/ and the
# constants in sim/scripted_scenario.gd; nothing here chooses anything and
# nothing reads a clock. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/scenario_main.gd" -- "$@"
