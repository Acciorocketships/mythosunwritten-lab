#!/usr/bin/env bash
# What the village lights cost, on the scene the game actually draws.
# See measure_lights.gd. Needs a display; use xvfb-run on a headless machine.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --script res://tools/measure_lights.gd -- "$@"
