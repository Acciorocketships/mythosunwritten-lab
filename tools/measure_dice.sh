#!/usr/bin/env bash
# Measure what the die settled in the items phase costs.
#
#   ./tools/measure_dice.sh > reports/dice-evidence.txt
#
# Nothing is asserted here; everything is counted. The suite checks the rules,
# this says how much they are worth.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://tools/measure_dice.gd"
