#!/usr/bin/env bash
# Run the whole test suite headless. Exits 0 when everything passes.
#
#   ./run_tests.sh                # every suite
#   ./run_tests.sh --layers-only  # just the sim-must-not-see-render check
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

SCRIPT="res://bin/test_main.gd"
if [[ "${1:-}" == "--layers-only" ]]; then
	SCRIPT="res://bin/check_layers.gd"
fi

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "$SCRIPT"
