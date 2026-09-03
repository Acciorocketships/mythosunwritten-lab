#!/usr/bin/env bash
# Run the suite that says relationships live on edges between entities, are held
# by the world, and are moved only by things that actually happened in it.
#
#   ./run_relationships_suite.sh
#
# No window, no rendering, no network and no credential.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/relationships_suite.gd"
