#!/usr/bin/env bash
# Print, tick by tick, what a seeded run's ground reads and whether a fight is
# on -- the two things tests write tick numbers down about, so those numbers can
# be re-derived rather than assumed. See seeded_ticks.gd.
#
#   ./tools/seeded_ticks.sh --seed 1234 --scenario market --ticks 90
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/seeded_ticks.gd -- "$@"
