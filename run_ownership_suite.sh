#!/usr/bin/env bash
# Run the suite that says section 6's ownership rule is one function of a world
# position and the state of the world, reading relationship edges and character
# sheets and nothing else.
#
#   ./run_ownership_suite.sh
#
# No window, no rendering, no network and no credential.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "res://bin/ownership_suite.gd"
