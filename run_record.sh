#!/usr/bin/env bash
# Put the shipped model run's questions to a real language model, once, and
# write what comes back into net/model_recording.gd.
#
#   OPENROUTER_API_KEY=sk-... ./run_record.sh --live
#
# This is the only command in the repository that makes a network call, and it
# is never run by the test suite or by any other run script. Without --live it
# says what it would do and changes nothing. With --live and no key it says so
# and changes nothing.
#
# After it has written the recording, ./run_agent.sh replays that exchange, so
# the transcript under reports/ has to be regenerated with it and the suite's
# copy of it updated:
#
#   ./run_agent.sh > reports/agent-evidence.txt
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/record_main.gd" -- "$@"
