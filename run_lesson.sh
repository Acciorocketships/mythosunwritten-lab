#!/usr/bin/env bash
# Print the lesson comparison headless: one character in one moment, asked the
# same question four times -- once with nothing kept in its memory and once for
# each of three lessons it has kept.
#
#   ./run_lesson.sh                # replays the recorded exchange
#   ./run_lesson.sh --live         # puts the same four questions to a real model
#
# No window and no rendering. Without --live there is no network call, no
# credential and no model: the answers come from net/model_recording.gd, and two
# runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/lesson_main.gd" -- "$@"
