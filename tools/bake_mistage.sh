#!/usr/bin/env bash
# Merge, scale and write out the Mistage models this project draws. See
# tools/bake_mistage.gd for the recipes and the number behind every scale.
#
#   ./tools/bake_mistage.sh            # every recipe
#   ./tools/bake_mistage.sh house      # only recipes whose name contains this
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/bake_mistage.gd -- "$@"
