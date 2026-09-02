#!/usr/bin/env bash
# Play the scripted three-commander match headless and print its transcript.
#
#   ./run_match.sh
#
# Every decision is written down in sim/scripted_match.gd; nothing here chooses
# anything. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/match_main.gd"
