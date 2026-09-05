#!/usr/bin/env bash
# Print, headless, what the world charges a character for an ask that costs it no
# time -- put to one mind of each kind at once: a person's live choices, a
# program's rule, and a language model.
#
#   ./run_asks.sh                  # replays the recorded lines
#   ./run_asks.sh --live           # puts the model arm's questions to a real model
#
# No window and no rendering. Without --live there is no network call, no
# credential and no model, and two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/asks_main.gd" -- "$@"
