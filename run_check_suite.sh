#!/usr/bin/env bash
# Run just the difficulty-class suite headless. Exits 0 when it passes.
#
#   ./run_check_suite.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/check_suite.gd"
