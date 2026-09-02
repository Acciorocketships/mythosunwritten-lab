#!/usr/bin/env bash
# What the coarse distant ground costs. See measure_lod.gd for the geometry and
# build half; this also runs the render shell twice, with the layer and without
# it, for the frame times.
#
#   ./tools/measure_lod.sh              # seed 1234
#   ./tools/measure_lod.sh --seed 7
#
# The frame numbers are SOFTWARE RASTERISATION: this machine has no GPU, so the
# renderer is llvmpipe. Treat them as a ratio between the two runs, never as a
# frame rate.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_lod.gd -- "$@"

FRAMES="${LOD_FRAMES:-200}"
for mode in "with" "without"; do
	extra=()
	if [[ "$mode" == "without" ]]; then extra=(--no-distant-ground); fi
	line=$(xvfb-run -a "$GODOT" --path . --quit-after "$FRAMES" \
		-- "$@" --paused "${extra[@]}" 2>/dev/null | grep "render-shell stop" || true)
	echo "lod-measure frames $mode: $(echo "$line" | grep -o 'far=[0-9]*') $(echo "$line" | grep -o 'fartris=[0-9]*') $(echo "$line" | grep -o 'frame_ms=[0-9.]*') $(echo "$line" | grep -o 'timed=[0-9]*') [software rasterisation]"
done
