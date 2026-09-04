#!/usr/bin/env bash
# How many positions a model named in the shipped run, how far each one was from
# the character that named it, and how many the engine refused for not being
# somewhere it could walk to. See position_space_probe.gd. No key, no network,
# no model; two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/position_space_probe.gd -- "$@"
