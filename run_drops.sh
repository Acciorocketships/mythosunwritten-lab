#!/usr/bin/env bash
# Print the drop layer's own tables headless: what the generator rolls over
# twelve hundred items of each kind, the realised one-in-five drop rate, one
# kill worked in full, the frontier against the ring beyond it, and the world
# fingerprint before and after thousands of item rolls.
#
#   ./run_drops.sh
#
# Every number comes from sim/ and a fixed seed written into bin/drops_main.gd;
# nothing here chooses anything. Two runs print identical bytes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/drops_main.gd"
