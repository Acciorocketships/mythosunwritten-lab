#!/usr/bin/env bash
# Whether the far side of a blade of grass is lit wrongly, and by how much: the
# same paused frame drawn once per shading variant. See measure_blade_normals.gd.
# Needs a display; use xvfb-run on a headless machine.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --path . --script res://tools/measure_blade_normals.gd -- "$@"
