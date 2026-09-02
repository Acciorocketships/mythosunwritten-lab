#!/usr/bin/env bash
# Run the same simulation with rendering, in a window.
#
#   ./run_render.sh              # seed 1234
#   ./run_render.sh --seed 7
#
#   ./run_render.sh --sheet --scenario encounter   # ...with the character sheet
#
# Needs a display. Escape quits, Space pauses, R restarts on the next seed.
# --no-model-tint draws the pack models in the colours they ship in, which is
# only useful for photographing what the biome tint is doing.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec "$GODOT" --path . -- "$@"
