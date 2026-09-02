#!/usr/bin/env bash
# Lay out pack models side by side at real size. See tools/model_sheet.gd.
#
#   xvfb-run -a ./tools/model_sheet.sh --screenshot "$PWD/out.png" a.fbx b.fbx
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --resolution 1600x1000 res://tools/model_sheet.tscn -- "$@"
