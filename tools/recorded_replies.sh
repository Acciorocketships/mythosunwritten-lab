#!/usr/bin/env bash
# How much of the shipped model run the checked-in recording still answers.
#
#   ./tools/recorded_replies.sh
#
# Replays. Calls nothing, needs no key.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://tools/recorded_replies.gd"
