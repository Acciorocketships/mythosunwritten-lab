#!/usr/bin/env bash
# The armoury walkthrough: every held shape in a hand, and one character whose
# hand changes mid-run, read off the snapshot the way the shell reads it.
# See held_items.gd.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/held_items.gd -- "$@"
