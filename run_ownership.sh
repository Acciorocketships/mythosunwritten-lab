#!/usr/bin/env bash
# Print the measurement that chose section 6's three open numbers -- the softmin
# temperature, the radius and the threshold -- against the shipped seeded run.
#
#   ./run_ownership.sh          # the tables; no clock is read, so two runs
#                               # print identical bytes
#   ./run_ownership.sh --cost   # ...and what sampling the grid took
#
# No window, no rendering, no network and no credential.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/ownership_main.gd" -- "$@"
