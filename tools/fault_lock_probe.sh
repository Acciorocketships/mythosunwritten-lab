#!/usr/bin/env bash
# What one line the action catalogue cannot read costs a character: the shipped
# model run with one unreadable reply put into it, the same line handed to a
# plan, a person and a model, and the four refusals that are not the
# catalogue's. See fault_lock_probe.gd. No key, no network, no model.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/fault_lock_probe.gd -- "$@"
