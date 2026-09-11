#!/usr/bin/env bash
# Print the weapon catalogue, what dominates what, and the seeded run in which
# the five new shapes are held, swung and landed. See tools/weapon_patterns.gd.
#
#   ./tools/weapon_patterns.sh
#   ./tools/weapon_patterns.sh --ticks 120
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/weapon_patterns.gd -- "$@"
