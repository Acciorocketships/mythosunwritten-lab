#!/usr/bin/env bash
# Stack captured frames into one labelled comparison image. See
# compare_strip.gd. Needs a display for the captions; use xvfb-run.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --script res://tools/compare_strip.gd -- "$@"
