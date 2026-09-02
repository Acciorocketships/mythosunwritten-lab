#!/usr/bin/env bash
# What a village is made of, and what that costs to draw. See
# tools/measure_village.gd.
#
#   ./tools/measure_village.sh                    # eight seeds, headless, exact
#   xvfb-run -a ./tools/measure_village.sh --rendered --seed 1234 --start -100 34
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

for arg in "$@"; do
	if [[ "$arg" == "--rendered" ]]; then
		exec "$GODOT" --path . --resolution 640x360 \
			--script res://tools/measure_village.gd -- "$@"
	fi
done
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_village.gd -- "$@"
