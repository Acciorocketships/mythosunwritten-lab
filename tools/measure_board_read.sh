#!/usr/bin/env bash
# Price the ways the grass can give way over a board square, by photographing
# them and measuring the frames.
#
#   ./tools/measure_board_read.sh                       # the shipping camera
#   ./tools/measure_board_read.sh --out /tmp/boardread  # keep the frames
#
# One seed, one place, one camera and one frame, so two treatments differ in the
# treatment and in nothing else. The place is a meadow, which is the frame the
# question is about: grass-heavy ground with a board on it.
#
# Every run is --paused at a fixed frame rate, so the wind is at the same moment
# of its cycle in all of them and a blade stands where it stands in every frame.
#
# The treatments are the two uniforms render/grass_layer.gd writes, given to the
# shell as --grass-give-way <thin> <fade>: how much shorter a blade stands over a
# painted square, and what share of its pixels are thrown away instead. What
# comes out is in tools/measure_board_read.py, which reads the frames; the
# frames themselves are what reports/board-readable.md shows.
#
# Needs a display. Use xvfb-run on a machine with no screen -- this does that
# itself.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

OUT="${TMPDIR:-/tmp}/board-read-$$"
SEED=1234
SPOT=(--start 228 -60)
FRAME=60
while [[ $# -gt 0 ]]; do
	case "$1" in
		--out) OUT="$2"; shift 2 ;;
		--seed) SEED="$2"; shift 2 ;;
		--at) SPOT=(--start "$2" "$3"); shift 3 ;;
		*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done
mkdir -p "$OUT"

# One frame. The engine is run directly rather than through ./run_render.sh so
# that --fixed-fps can be given: it is what makes the wind land in the same
# place in every frame of the set.
shoot() {
	local name="$1"; shift
	xvfb-run -a "$GODOT" --path . --fixed-fps 30 -- \
		--seed "$SEED" "${SPOT[@]}" --paused \
		--screenshot "$OUT/$name.png" --screenshot-frame "$FRAME" "$@" \
		> "$OUT/$name.log" 2>&1
}

# The two grass-free frames say where the paint lands; the rest are what is
# being priced. Four at a time, because each is a whole world being built.
shoot bare-board --board --no-grass &
shoot bare-plain --no-grass &
shoot grass-plain &
shoot grass-through --board --grass-give-way 0.0 0.0 &
wait
shoot grass-short-080 --board --grass-give-way 0.80 0.0 &
shoot grass-short-100 --board --grass-give-way 1.0 0.0 &
shoot grass-fade-080 --board --grass-give-way 0.0 0.80 &
shoot grass-fade-100 --board --grass-give-way 0.0 1.0 &
wait

echo
echo "frames in $OUT"
echo
python3 tools/measure_board_read.py \
	--board "$OUT/bare-board.png" --plain "$OUT/bare-plain.png" \
	--grassy "$OUT/grass-plain.png" \
	--frame "grass stands through (before)=$OUT/grass-through.png" \
	--frame "shortened to a fifth (0.80)=$OUT/grass-short-080.png" \
	--frame "shortened to nothing (1.00)=$OUT/grass-short-100.png" \
	--frame "dithered away (0.80)=$OUT/grass-fade-080.png" \
	--frame "dithered away (1.00)=$OUT/grass-fade-100.png"

# And what each way costs to draw. A second pass, because the frames above are
# run at a fixed frame rate -- which is what makes the wind stand still across
# the set -- and a fixed frame rate makes the frame time the rate rather than the
# cost. These runs are real-time, one at a time so they are not each other's
# load, and long enough to get past the streaming: the shell averages the frame
# time from frame 90 onwards and prints it on its stop line.
#
# --disable-vsync and --delta-smoothing disable, because without them the answer
# is the display's and not the picture's: the first set taken here came back as
# 133.4 ms for every treatment including no board at all, which is one frame in
# eight of a 60 Hz display and not a measurement of anything.
echo
echo "what each way costs to draw, on the same grass-heavy view:"
printf '%-30s %10s %10s %10s\n' "treatment" "frame_ms" "blades" "drawn"
price() {
	local name="$1"; shift
	xvfb-run -a "$GODOT" --path . --disable-vsync --delta-smoothing disable -- \
		--seed "$SEED" "${SPOT[@]}" --paused \
		--screenshot "$OUT/priced-$name.png" --screenshot-frame 240 "$@" \
		> "$OUT/priced-$name.log" 2>&1
	local stop
	stop="$(grep -o 'grass=[0-9]* drawn=[0-9]*.*frame_ms=[0-9.]* timed=[0-9]*' \
		"$OUT/priced-$name.log" | tail -1)"
	printf '%-30s %10s %10s %10s\n' "$name" \
		"$(sed -n 's/.*frame_ms=\([0-9.]*\).*/\1/p' <<< "$stop")" \
		"$(sed -n 's/.*grass=\([0-9]*\).*/\1/p' <<< "$stop")" \
		"$(sed -n 's/.*drawn=\([0-9]*\).*/\1/p' <<< "$stop")"
}
price no-grass --board --no-grass
price no-board
price grass-through --board --grass-give-way 0.0 0.0
price grass-short-080 --board --grass-give-way 0.80 0.0
price grass-short-100 --board --grass-give-way 1.0 0.0
price grass-fade-080 --board --grass-give-way 0.0 0.80
price grass-fade-100 --board --grass-give-way 0.0 1.0
