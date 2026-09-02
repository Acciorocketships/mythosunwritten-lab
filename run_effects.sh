#!/usr/bin/env bash
# Print what the composable effect base claims about itself, headless.
#
#   ./run_effects.sh
#
# Nothing here chooses anything and nothing draws a number, so two runs print
# identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/effects_main.gd"
