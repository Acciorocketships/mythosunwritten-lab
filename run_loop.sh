#!/usr/bin/env bash
# Print the control loop headless: one walk re-evaluated on its cadence, each of
# section 2.2's four interruptions in its own scene, how often the continue bias
# actually changes a decision at its value and at zero, and three characters one
# of which takes forty ticks to make up its mind.
#
#   ./run_loop.sh
#
# Every number comes from sim/ and the constants in sim/control_loop.gd and
# sim/scripted_loop.gd; nothing here chooses anything, nothing draws, and nothing
# reads a clock. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/loop_main.gd"
