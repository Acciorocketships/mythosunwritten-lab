#!/usr/bin/env bash
# Run just the goal suite headless. Exits 0 when it passes.
#
#   ./run_goal_suite.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/goal_suite.gd"
