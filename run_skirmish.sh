#!/usr/bin/env bash
# Print the skirmish headless: a patrol of two and one stranger who walks into
# them, meeting on the atomic action surface and falling into a fight that the
# scene itself drives.
#
#   ./run_skirmish.sh                 # 80 ticks, seed 1234
#   ./run_skirmish.sh --ticks 200
#   ./run_skirmish.sh --seed 7
#
# This is the second scenario built on the action surface, and it reaches a fight
# without writing down a rule of one: `ActionScene.fight_step()` holds the
# pairing rule, the engage radius, the cadence and the ordering, and the world's
# own `CombatantRoster` calls the same thing. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/skirmish_main.gd" -- "$@"
