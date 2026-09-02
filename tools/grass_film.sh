#!/usr/bin/env bash
# Save a numbered sequence of frames of the running game. See grass_film.gd.
# Needs a display; use xvfb-run on a headless machine.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --fixed-fps 30 --script res://tools/grass_film.gd -- "$@"
