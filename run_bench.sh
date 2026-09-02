#!/usr/bin/env bash
# What the island layer costs per call, in microseconds.
#
#   ./run_bench.sh [--seed N]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://bin/island_bench.gd -- "$@"
