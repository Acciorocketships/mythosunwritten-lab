#!/usr/bin/env bash
# What each anti-aliasing mode removes from a frame and what it costs, measured
# on the frame the game actually draws. See measure_aa.gd. Needs a display; use
# xvfb-run on a headless machine.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --script res://tools/measure_aa.gd -- "$@"
