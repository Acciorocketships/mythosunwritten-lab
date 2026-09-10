#!/usr/bin/env bash
# The review's own probe of the playable layer: a person's mind against a
# language model's, through one driver, in one world, at one seed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/critic_playable_probe.gd "$@"
