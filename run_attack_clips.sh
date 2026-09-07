#!/usr/bin/env bash
# Run just the attack-clip suite headless: the two combat clip libraries, the
# table from the simulation's seven motion tags to the clips that play them, and
# the branch of the animation rule that picks one.
#
#   ./run_attack_clips.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/attack_clips_suite.gd"
