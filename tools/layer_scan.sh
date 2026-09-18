#!/usr/bin/env bash
# The layer scan: nothing under sim/ may name a render type or a resource path.
# See tools/layer_scan.gd. No window, no rendering, a few seconds.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://tools/layer_scan.gd" -- "$@"
