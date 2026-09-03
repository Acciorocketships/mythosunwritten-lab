#!/usr/bin/env bash
# Whether the pixel interface is drawn in whole pixels: it renders the character
# sheet over the world, then measures the frame it saved. See tools/measure_ui.gd
# for what the two numbers mean.
#
#   ./tools/measure_ui.sh                                  # needs a display
#   xvfb-run -a ./tools/measure_ui.sh
#   xvfb-run -a ./tools/measure_ui.sh --keep reports/assets/character-sheet.png
#   xvfb-run -a ./tools/measure_ui.sh --scenario quarrel --tick 240
#   xvfb-run -a ./tools/measure_ui.sh --panel readout --tick 30   # the combat readout
#   ./tools/measure_ui.sh --icons reports/assets/drawn-icons.png   # no display needed
#   ./tools/measure_ui.sh --effects reports/assets/effect-art.png  # no display needed
#
# --panel says which of the two panels is measured. Either way both are drawn,
# so one frame can be looked at and measured twice.
#
# Everything after the recognised options goes to the render shell unchanged, so
# a frame can be aimed anywhere a run of ./run_render.sh can.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

# --icons writes the eleven icons this project drew, magnified, and --effects
# writes the six effect sprites and the seven animations they are put through.
# Both measure nothing and need no display, so they are handled before anything
# is rendered.
if [[ "${1:-}" == "--icons" || "${1:-}" == "--effects" ]]; then
	WHICH="$1"
	shift
	exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
		--script res://tools/measure_ui.gd -- "$WHICH" "$@"
fi

FRAME=""
KEEP=""
SCENARIO="encounter"
PANEL="sheet"
TICK=0
RESOLUTION="1280x720"
EXTRA=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--keep) KEEP="$2"; shift 2 ;;
		--scenario) SCENARIO="$2"; shift 2 ;;
		--panel) PANEL="$2"; shift 2 ;;
		--tick) TICK="$2"; shift 2 ;;
		--resolution) RESOLUTION="$2"; shift 2 ;;
		*) EXTRA+=("$1"); shift ;;
	esac
done

if [[ -n "$KEEP" ]]; then
	mkdir -p "$(dirname "$KEEP")"
	FRAME="$KEEP"
else
	FRAME="$(mktemp -t sprout-ui-XXXXXX.png)"
	trap 'rm -f "$FRAME"' EXIT
fi

WAIT=(--screenshot-frame 40)
if [[ "$TICK" -gt 0 ]]; then
	WAIT=(--screenshot-tick "$TICK")
fi

OUT="$("$GODOT" --path . --resolution "$RESOLUTION" --fixed-fps 30 -- \
	--seed 1234 --scenario "$SCENARIO" --sheet --readout \
	--screenshot "$FRAME" "${WAIT[@]}" "${EXTRA[@]}" 2>&1)" || {
	echo "$OUT" >&2; exit 1
}

LINE="$(grep -m1 "^render-shell $PANEL " <<<"$OUT" || true)"
if [[ -z "$LINE" ]]; then
	echo "the shell drew no $PANEL panel; is the pack unpacked?" >&2
	echo "$OUT" >&2
	exit 1
fi
read -r SCALE X Y W H <<<"$(sed -E 's/.*scale=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+) w=([0-9]+) h=([0-9]+).*/\1 \2 \3 \4 \5/' <<<"$LINE")"

grep -E '^render-shell (boot|sheet|readout) ' <<<"$OUT"
exec env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
	--script res://tools/measure_ui.gd -- \
	--frame "$FRAME" --at "$X" "$Y" --size "$W" "$H" --scale "$SCALE"
