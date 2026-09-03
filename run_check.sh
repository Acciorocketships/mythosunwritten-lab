#!/usr/bin/env bash
# Print the difficulty-class run headless: one character making four attempts the
# world has no rule for, each of which raises an ability check at the one hook in
# ActionEngine._interact. Two of the four are judged by a model and rolled by the
# engine; the other two are settled out of the character's own memory, with no
# model call and no roll, because an attempt of that shape was settled before.
#
#   ./run_check.sh                 # replays the recorded exchange
#   ./run_check.sh --ticks 120
#   ./run_check.sh --roll-seed 9   # different dice, word-for-word the same questions
#   ./run_check.sh --live          # puts the same questions to a real model
#
# No window and no rendering. Without --live there is no network call, no
# credential and no model: the answers come from net/model_recording.gd, and two
# runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/check_main.gd" -- "$@"
