#!/usr/bin/env bash
# Print the model run headless: six characters -- five whose minds are language
# models and one driven by a person's recorded choices -- living one seeded run
# of the shipped market and quarrel, with a table of every turn any of the five
# took, a table of what everybody else did while each of them waited, what the
# run cost in model calls, and what an hour of play would cost at the same rate.
#
#   ./run_agent.sh                 # replays the recorded exchange
#   ./run_agent.sh --ticks 200
#   ./run_agent.sh --seed 7
#   ./run_agent.sh --live          # puts the same questions to a real model
#
# No window and no rendering. Without --live there is no network call, no
# credential and no model: the answers come from net/model_recording.gd, and two
# runs print identical bytes. With --live the same five decision functions call a
# model over HTTPS on worker threads; the simulation does not wait for any of
# them, and the transcript will not match the checked-in one because a model's
# answer is its own.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/agent_main.gd" -- "$@"
