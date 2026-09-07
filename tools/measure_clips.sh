#!/usr/bin/env bash
# What the two combat clip files cost: assembly time and memory, for the two
# libraries loaded before this item, the two added by it, and the four together.
# One process per set, because the engine caches every file it opens. See
# tools/measure_clips.gd.
#
#   ./tools/measure_clips.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

run() {
	env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
		--script res://tools/measure_clips.gd -- --only "$1" | grep -v "^Godot Engine"
}

run base
echo
run combat
echo
run all
