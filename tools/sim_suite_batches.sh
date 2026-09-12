#!/usr/bin/env bash
# Run the sim-layer suites in small named batches, one engine at a time.
#
#   ./tools/sim_suite_batches.sh                 # every sim-layer batch
#   ./tools/sim_suite_batches.sh 3 4 5           # only batches 3, 4 and 5
#
# Why batches at all. Two things multiply this suite's memory on the adopted
# ground. A suite that calls OS.execute -- and 34 of them do, test_terrain
# among them -- starts a SECOND engine and blocks until it exits, so the peak
# is parent plus child, not parent alone. And the parent's footprint only
# grows as it walks from suite to suite, because each suite visits its own
# seeds. Run end to end in one process the two compound and the kernel takes
# the run: that is what happened to terrain-seam-suites-3726b, killed at
# RUN test_terrain with a second engine from another run also on the machine.
#
# So each batch is its own `./run_tests.sh <suites>` process, which starts from
# nothing and gives every page back when it exits, and the batches are run one
# after another with the machine checked clear in between. A batch that fails
# does not stop the run: the point is a verdict for every suite, so the failure
# is recorded and the next batch starts.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Small batches, heaviest suites most alone. The order follows bin/test_main.gd
# so a reader can line the two up.
BATCHES=(
	"test_rng test_determinism test_layering"
	"test_terrain"
	"test_streaming test_terrain_lod"
	"test_mountains test_biomes"
	"test_water"
	"test_islands test_island_cover"
	"test_settlements test_scatter"
	"test_combat_board test_combat_pieces"
	"test_combat_resolution test_combat_snap"
	"test_live_world test_asset_tags"
	"test_characters test_character_sheet test_items test_inventory"
	"test_drops test_ground_items test_effects"
	"test_actions test_control_loop test_walk_motion"
	"test_observation test_scenario"
	"test_agent test_memory"
	"test_goals test_upkeep test_tool_budget"
	"test_relationships test_ownership test_checks"
	"test_goodwill test_territory"
	"test_orchestrator test_fight_driver test_enemies"
	"test_turn_seam test_strike_record test_attack_clips"
	"test_weapon_patterns test_flights test_held_items"
	"test_player_input test_player_actions test_bargain"
	"test_player_inventory test_player_combat"
	"test_walk_in_fight test_fight_cooloff"
)

# Engines left behind by an earlier run hold their whole heap and are the
# difference between a batch that fits and a batch the kernel takes. In this
# sandbox `ps` and `kill -0` answer "Operation not permitted" whatever is
# really there, while pgrep and psutil see the truth -- so the check is
# psutil's, and so is the kill.
clear_engines() {
	python3 - <<'PY'
import psutil, time

def engines():
	found = []
	for p in psutil.process_iter(['pid', 'cmdline']):
		try:
			cmd = ' '.join(p.info['cmdline'] or [])
		except Exception:
			continue
		if 'godot4' in cmd and '--script' in cmd and 'python3' not in cmd and '/bin/bash' not in cmd:
			found.append(p)
	return found

left = engines()
if not left:
	print('    machine clear: no engine running')
else:
	for p in left:
		try:
			print('    killing leftover engine pid %d holding %.2f GB'
			      % (p.pid, p.memory_info().rss / 1e9))
			p.kill()
		except Exception as exc:
			print('    could not kill %d: %s' % (p.pid, exc))
	time.sleep(3)
	still = engines()
	print('    %d engine(s) still up after the kill' % len(still) if still
	      else '    machine clear')
print('    memory available: %.1f GB' % (psutil.virtual_memory().available / 1e9))
PY
}

wanted=("$@")
selected() {
	[[ ${#wanted[@]} -eq 0 ]] && return 0
	local n="$1" w
	for w in "${wanted[@]}"; do [[ "$w" == "$n" ]] && return 0; done
	return 1
}

declare -a passed=() failed=()
for i in "${!BATCHES[@]}"; do
	n=$(( i + 1 ))
	selected "$n" || continue
	suites="${BATCHES[$i]}"
	echo ""
	echo "=============================================================="
	echo "BATCH $n/${#BATCHES[@]}: $suites"
	echo "  started $(date -Is)"
	clear_engines
	echo "--------------------------------------------------------------"
	start=$SECONDS
	# shellcheck disable=SC2086
	./run_tests.sh $suites
	status=$?
	took=$(( SECONDS - start ))
	if [[ $status -eq 0 ]]; then
		echo "BATCH $n OK   ($suites) in ${took}s"
		passed+=("$n:$suites")
	else
		echo "BATCH $n FAIL exit=$status ($suites) in ${took}s"
		failed+=("$n:$suites exit=$status")
	fi
done

echo ""
echo "=============================================================="
echo "SUMMARY  ${#passed[@]} batch(es) passed, ${#failed[@]} failed"
for f in "${failed[@]:-}"; do [[ -n "$f" ]] && echo "  FAILED $f"; done
[[ ${#failed[@]} -eq 0 ]]
