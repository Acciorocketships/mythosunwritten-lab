#!/usr/bin/env bash
# What the lighting and atmosphere stack costs, on the scene the game draws.
# See measure_atmosphere.gd. Needs a display; use xvfb-run on a headless machine.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --script res://tools/measure_atmosphere.gd -- "$@"
