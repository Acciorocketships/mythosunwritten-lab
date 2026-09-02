#!/usr/bin/env bash
# What the grass on the floating islands costs, on the scene the game draws.
# See measure_island_grass.gd. Needs a display; use xvfb-run on a headless machine.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --script res://tools/measure_island_grass.gd -- "$@"
