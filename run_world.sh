#!/usr/bin/env bash
# Print the orchestrator run headless: one world with one character walking a
# written-down plan through it, and the world's dungeon master looking at that
# world every 30 ticks and changing it through the operations the engine exposes
# -- placing and removing things, opening and shutting them, shoving them, and
# spawning characters whose sheets are rolled before anybody is asked who they
# are.
#
#   ./run_world.sh                 # replays the recorded exchange
#   ./run_world.sh --ticks 300
#   ./run_world.sh --every 20      # a look at the world more often
#   ./run_world.sh --live          # puts the same questions to a real model
#
# No window and no rendering. Without --live there is no network call, no
# credential and no model: the answers come from net/model_recording.gd, and two
# runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/world_main.gd" -- "$@"
