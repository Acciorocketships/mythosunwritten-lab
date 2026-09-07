#!/usr/bin/env bash
# Print the territory comparison headless: section 6's claim that winning
# battles and winning hearts both shift ownership, measured on this
# implementation as two runs of one world.
#
# One seed, one cast, one piece of ground. Both runs open identically -- a rival
# builds a claim by trading with the neighbours -- and from a stated tick they
# differ in exactly one written rule: in one Wren walks to the rival and wins the
# fight, in the other Wren hands each neighbour the thing it wanted. Ownership of
# the same six named points is printed before and after for both, as one table.
#
#   ./run_territory.sh                    # both runs and the comparison
#   ./run_territory.sh --arm fight        # just the fight run
#   ./run_territory.sh --arm friendship   # just the friendship run
#   ./run_territory.sh --seed 7 --ticks 400
#
# No window, no rendering, no network and no credential: the three deed
# questions replay the recorded goodwill exchange, so two runs of this command
# print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/territory_main.gd" -- "$@"
