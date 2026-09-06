#!/usr/bin/env bash
# Run just the enemies suite headless. Exits 0 when it passes.
#
#   ./run_enemies_suite.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/enemies_suite.gd"
