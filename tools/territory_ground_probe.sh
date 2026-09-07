#!/usr/bin/env bash
# Print the passability map the territory run's post was placed against.
#
#   ./tools/territory_ground_probe.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://tools/territory_ground_probe.gd"
