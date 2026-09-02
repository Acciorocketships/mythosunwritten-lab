#!/usr/bin/env bash
# What the playing camera sees of a floating island, as numbers.
# See measure_island_read.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec "$GODOT" --headless --path . --script res://tools/measure_island_read.gd -- "$@"
