#!/usr/bin/env bash
# Print the goodwill run headless: the two ways section 6 says sentiment goes up,
# played as two arms of one world and measured against the ownership rule.
#
# One character, three neighbours who each want one thing. In one arm the
# character talks to all three, three times each; in the other it hands each of
# them the thing they were after and says nothing. Both arms print what the
# character came to own, side by side, together with how often the persuasion
# gate lets anything through over two hundred roll seeds and what talking could
# ever be worth at its ceiling.
#
#   ./run_goodwill.sh                 # replays the recorded exchange
#   ./run_goodwill.sh --ticks 200
#   ./run_goodwill.sh --roll-seed 9   # different dice, word-for-word the same questions
#   ./run_goodwill.sh --live          # puts the same questions to a real model
#
# No window and no rendering. Without --live there is no network call, no
# credential and no model: the answers come from net/model_recording.gd, and two
# runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/goodwill_main.gd" -- "$@"
