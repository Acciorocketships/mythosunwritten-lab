#!/usr/bin/env bash
# What the quiet stretches in test_scatter and test_ui_panel are actually made of.
#
# Both suites go quiet for more than 1500 s in one place, and in both places the
# suite is not sampling the ground at all: it is waiting on child engines it
# launched with OS.execute, each of which builds this seed's world from nothing
# before it can answer. This times those children one by one, with the exact
# argument lists the suites pass, so the gap can be added up rather than guessed.
#
# One engine at a time: this machine has one engine slot.
#
#   ./tools/quiet_gap_cost.sh [output log]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./godot_env.sh

LOG="${1:-reports/scattered-sweeps/subprocess-cost.log}"
mkdir -p "$(dirname "$LOG")"
ROOT="$PWD"

: >"$LOG"
say() { echo "$*" | tee -a "$LOG"; }

say "# what one child engine costs, measured $(date -Is)"
say "# engine: $GODOT"
say ""

time_one() {
	local label="$1"; shift
	local began ended
	began="$(date +%s.%N)"
	env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" "$@" >/dev/null 2>&1 || true
	ended="$(date +%s.%N)"
	say "$(printf '%-52s %8.1f s' "$label" "$(echo "$ended - $began" | bc)")"
}

say "## tests/test_scatter.gd:875-877 -- _two_processes_dress_the_world_the_same_way"
say "## godot4 --headless --path . --script res://bin/headless_main.gd -- --seed <seed> --ticks 0 --scatter"
for spec in "same_a 1234" "same_b 1234" "different 4321"; do
	set -- $spec
	time_one "scatter headless, seed $2 ($1)" \
		--headless --path "$ROOT" --script res://bin/headless_main.gd \
		-- --seed "$2" --ticks 0 --scatter
done

say ""
say "## tests/test_ui_panel.gd:550-554 -- _the_panel_changes_nothing_about_the_world"
say "## godot4 --headless --path . --fixed-fps 60 --quit-after 60 -- --seed 5 --no-grass --no-atmosphere [extra]"
time_one "render shell, seed 5, no panel" \
	--headless --path "$ROOT" --fixed-fps 60 --quit-after 60 \
	-- --seed 5 --no-grass --no-atmosphere
time_one "render shell, seed 5, --sheet --scenario encounter" \
	--headless --path "$ROOT" --fixed-fps 60 --quit-after 60 \
	-- --seed 5 --no-grass --no-atmosphere --sheet --scenario encounter
time_one "render shell, seed 5, --scenario encounter" \
	--headless --path "$ROOT" --fixed-fps 60 --quit-after 60 \
	-- --seed 5 --no-grass --no-atmosphere --scenario encounter

say ""
say "# done $(date -Is)"
