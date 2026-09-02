#!/usr/bin/env bash
# Which biome a position is in, and what the ground does there. See
# biome_at.gd. Reads the fields headless; no display needed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script res://tools/biome_at.gd -- "$@"
