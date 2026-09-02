#!/usr/bin/env bash
# What the instanced grass costs, on the scene the game actually draws.
# See measure_grass.gd. Needs a display; use xvfb-run on a headless machine.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --script res://tools/measure_grass.gd -- "$@"
