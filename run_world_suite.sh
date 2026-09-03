#!/usr/bin/env bash
# Run just the orchestrator suite: the world's dungeon master, its spawns rolled
# before anybody is asked who they are, and the operations table that is the
# only way it can change anything.
#
#   ./run_world_suite.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/world_suite.gd"
