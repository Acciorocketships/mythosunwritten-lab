#!/usr/bin/env bash
# Draw catalog character and creature tags side by side, at world scale, each
# holding a frame of a named clip. See tools/character_sheet.gd.
#
#   xvfb-run -a ./tools/character_sheet.sh --screenshot "$PWD/out.png" \
#       minion_toadstool minion_cat minion_ent minion_frog skeleton_warrior:Idle_A
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --resolution 1800x760 res://tools/character_sheet.tscn -- "$@"
