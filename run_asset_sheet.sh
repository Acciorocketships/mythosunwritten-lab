#!/usr/bin/env bash
# Draw every asset tag in the catalog side by side, as a contact sheet.
#
#   ./run_asset_sheet.sh                                 # in a window
#   xvfb-run -a ./run_asset_sheet.sh --screenshot "$PWD/sheet.png"
#
# Needs a display. This is the render layer looking at its own table; the
# simulation is not running behind it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec "$GODOT" --path . --resolution 1600x1000 res://render/asset_sheet.tscn -- "$@"
