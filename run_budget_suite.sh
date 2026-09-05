#!/usr/bin/env bash
# Run the suite that says an ask costing the world no time cannot be made
# forever: what the world charges for one past the budget, and that it charges
# every character alike whoever is deciding for it.
#
#   ./run_budget_suite.sh
#
# No window, no rendering, no network and no credential.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/budget_suite.gd"
