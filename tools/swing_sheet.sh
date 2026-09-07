#!/usr/bin/env bash
# Photograph a seeded fight while it is being fought: seven weapons in a row,
# each drawn with its own motion. See tools/swing_sheet.gd.
#
#   xvfb-run -a ./tools/swing_sheet.sh \
#       --screenshot-ticks "6:$PWD/reports/assets/swings-tick-6.png"
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --resolution 1800x620 res://tools/swing_sheet.tscn -- "$@"
