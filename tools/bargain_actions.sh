#!/usr/bin/env bash
# Print the bargain run: a person's written-down key presses buying a named
# item from a model-driven trader, replaying the shipped recorded exchange.
#
#   ./tools/bargain_actions.sh
#
# No window, no network, no key: the trader's replies come from
# net/model_recording.gd, and two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/bargain_actions.gd
