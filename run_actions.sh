#!/usr/bin/env bash
# Print the atomic action set headless: section 2.1's list beside section 10's
# call names, every action called once with what came of it, an attack refused
# for being outside a bow's pattern and the same attack landed with a spear, and
# the same choice driven by a person's recorded choices and by a rule.
#
#   ./run_actions.sh
#
# Every number comes from sim/ and the constants in sim/scripted_actions.gd;
# nothing here chooses anything and nothing draws. Two runs print identical
# bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/actions_main.gd"
