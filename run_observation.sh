#!/usr/bin/env bash
# Print the observation walkthrough headless: what each of five characters can
# see at two stated ticks of the shipped scenario -- nearby entities, nearby
# objects, the window of tactical lattice under them, and what has changed about
# them recently -- followed by how big each packet came to.
#
#   ./run_observation.sh
#   ./run_observation.sh --seed 7
#
# No window, no rendering, and no language model anywhere: this is the packet a
# model will later be handed, and producing it requires none. Two runs print
# identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/observation_main.gd" -- "$@"
