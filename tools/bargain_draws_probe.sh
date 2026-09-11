#!/usr/bin/env bash
# Play the bargain run through every recorded draw there is and print what each
# one did beside what held whatever it did.
#
#   ./tools/bargain_draws_probe.sh
#
# No window, no network, no key: every table replayed here is already in the
# repository (net/model_recording.gd and net/bargain_draws.gd).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/bargain_draws_probe.gd
