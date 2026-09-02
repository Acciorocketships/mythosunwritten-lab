#!/usr/bin/env bash
# Play the whole cycle headless and print its transcript: real time, the snap
# onto the tactical board, a match played to its end, the snap back off, and
# real time again.
#
#   ./run_encounter.sh                    # 90 ticks, seed 1234
#   ./run_encounter.sh --ticks 200
#   ./run_encounter.sh --island     # the same cycle on a floating island's top
#
# No window and no rendering at all. Every decision is written down in
# sim/scripted_encounter.gd and sim/combat_policy.gd; nothing here chooses
# anything. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/encounter_main.gd" -- "$@"
