#!/usr/bin/env bash
# Run the suite that says the two per-character stores -- what a character
# remembers and what it is after -- are maintained on a path every character
# passes, whoever is deciding for it.
#
#   ./run_upkeep_suite.sh
#
# No window, no rendering, no network and no credential.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/upkeep_suite.gd"
