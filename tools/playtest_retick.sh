#!/usr/bin/env bash
# Rename playtest frames to the tick they were actually taken on.
#
#   ./tools/playtest_retick.sh [reports/playtest-*.log ...]
#
# `--screenshot-ticks "12:a.png"` means "the first frame drawn at tick 12 or
# later". This machine renders through llvmpipe at a handful of frames a second
# while the world steps twelve times a second, so a run asked for consecutive
# ticks gets whatever ticks its frames happened to land on -- and the shell says
# which, in `render-shell screenshot t=<tick> <path>`.
#
# A frame named for a tick it was not taken on is a quiet lie in a report, so
# every `-t<N>.png` is renamed to the tick its own log records. Idempotent: a
# frame already named for its tick is left alone.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

logs=("$@")
if [ ${#logs[@]} -eq 0 ]; then
	mapfile -t logs < <(ls reports/playtest-*.log)
fi

# Renaming in place is not safe on its own: a session that asks for consecutive
# ticks gets frames whose new names are other frames' old names -- `-t8.png`
# becomes `-t10.png` while `-t10.png` is still waiting to become `-t13.png`, and
# a one-pass rename would carry the first frame's pixels into the second frame's
# name. So every move goes through a name nothing else can be asked for, and the
# second pass puts them down. A frame already on its own tick still makes the
# round trip, which costs nothing and keeps the two passes symmetrical.
moved=0
declare -a from_tmp=() to_final=()
for log in "${logs[@]}"; do
	while read -r tick path; do
		[ -f "$path" ] || continue
		wanted="$(sed -E "s/-t[0-9]+\.png$/-t$tick.png/" <<< "$path")"
		tmp="$path.retick"
		mv "$path" "$tmp"
		from_tmp+=("$tmp")
		to_final+=("$wanted")
		if [ "$wanted" != "$path" ]; then
			echo "$(basename "$path") -> $(basename "$wanted")"
			moved=$((moved + 1))
		fi
	done < <(grep -oE "render-shell screenshot t=[0-9]+ [^ ]+\.png" "$log" \
		| sed -E "s/render-shell screenshot t=([0-9]+) (.*)/\1 \2/")
done
for i in "${!from_tmp[@]}"; do
	mv "${from_tmp[$i]}" "${to_final[$i]}"
done
echo "reticked $moved frame(s)"
