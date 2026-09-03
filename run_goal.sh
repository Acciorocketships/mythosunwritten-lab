#!/usr/bin/env bash
# Print the goal comparison headless: one character in one moment, asked the
# same question four times -- once after nothing at all and once for each of
# three goals put on its sheet.
#
#   ./run_goal.sh                # replays the recorded exchange
#   ./run_goal.sh --live         # puts the same four questions to a real model
#
# No window and no rendering. Without --live there is no network call, no
# credential and no model: the answers come from net/model_recording.gd, and two
# runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/goal_main.gd" -- "$@"
