#!/usr/bin/env bash
# Run the simulation with no rendering at all, for a fixed number of ticks.
#
#   ./run_headless.sh                     # 100 ticks, seed 1234
#   ./run_headless.sh --seed 7 --ticks 500
#   ./run_headless.sh --chunks --biomes
#   ./run_headless.sh --scatter           # everything grown or stood on the ground
#   ./run_headless.sh --scenario market   # set a named scenario out and live it
#   ./run_headless.sh --scenario market --frozen   # ...or photograph it instead
#   ./run_headless.sh --assets            # what visual material the run loaded
#
# Prints one line per traced tick and exits 0.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

# DISPLAY is unset deliberately: headless must not silently fall back to a
# window if one happens to be available.
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://bin/headless_main.gd -- "$@"
