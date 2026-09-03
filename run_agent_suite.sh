#!/usr/bin/env bash
# Run just the model-agent suite headless. Exits 0 when it passes.
#
#   ./run_agent_suite.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/agent_suite.gd"
