#!/usr/bin/env bash
# The world at one seed with a person in its cast, printed in full, so two
# processes can be compared byte for byte.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/critic_playable_determinism.gd "$@"
