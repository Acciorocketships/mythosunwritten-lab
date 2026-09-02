#!/usr/bin/env bash
# Print what a character sheet holds, headless: two characters of one type, the
# status that is not the level, one level-up, and the ability-score gate read
# through the sheet.
#
#   ./run_sheet.sh
#
# Every number comes from sim/; nothing here chooses anything and nothing draws.
# Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/sheet_main.gd"
