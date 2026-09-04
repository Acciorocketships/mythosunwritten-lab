#!/usr/bin/env bash
# Put the orchestrator's own questions to the shipping model both ways -- as the
# prompt stands, and with its naming line lifted to the top -- and count how many
# of each arm came back with nothing readable in them.
#
#   OPENROUTER_API_KEY=sk-... ./tools/prompt_lead_probe.sh [--repeats N]
#
# This makes network calls. It writes no file in the tree and touches no prompt:
# the two arms are built in memory out of the prompts the shipped orchestrator
# run puts.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://tools/prompt_lead_probe.gd" -- "$@"
