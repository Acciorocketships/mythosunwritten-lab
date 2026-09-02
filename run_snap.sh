#!/usr/bin/env bash
# Run just the snap suite headless. Exits 0 when everything passes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/snap_suite.gd"
