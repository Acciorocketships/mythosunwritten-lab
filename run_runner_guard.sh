#!/usr/bin/env bash
# Check that a suite which misbehaves is reported by name instead of being
# passed over or waited on forever.
#
#   ./run_runner_guard.sh
#
# It runs the ordinary command over the suites in tests/runner_fixtures/, each
# planted to break the runner in one of the three ways this engine allows, and
# requires of each run that it ends on its own, names the suite it was in, and
# exits non-zero. A stalled suite is held to more than that: it must be reported
# red, named with the budget it crossed, and the run must carry on to the suite
# after it and still end on one summary line. One more requires that a suite
# says where it has got to while it is still working, because a suite that
# printed only at its end is what made the budget unjudgeable. Two ordinary runs
# bracket them: one where everything passes and one where a check fails, to show
# those are unchanged. Two more delete the runner's own transcript and stall flag
# under a running run, the way a sandbox teardown does to a run that outlives the
# cycle that launched it, and require that a check which could not be read fails
# the run instead of passing it.
#
# Takes about a minute. The only real suite it borrows is the cheapest one there
# is, test_rng; everything else it needs it plants in tests/runner_fixtures/,
# so the runner's own verdict does not depend on whether some real suite is
# green this week.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

WAIT="${RUNNER_GUARD_WAIT:-300}"
STALL_WAIT="${RUNNER_GUARD_STALL_WAIT:-20}"
# How many runnable shells the stall-under-load check puts on this machine. It
# only has to be enough that the watchdog cannot have the processor whenever it
# asks: measured here, 1200 on 32 processors took a 120 s budget to 162 s.
GUARD_BUSY="${RUNNER_GUARD_BUSY:-1200}"
LOG="$(mktemp)"
# Somewhere we can reach the runner's own transcript and stall flag, so the two
# checks at the end can delete them on purpose.
RUNDIR="$(mktemp -d)"
trap 'rm -f "$LOG"; rm -rf "$RUNDIR"' EXIT

failed=0
note() { echo "  GUARD FAIL: $1" >&2; failed=1; }
has() { grep -q "$1" "$LOG" || note "$2"; }

# Run the ordinary command, bounded by this check's own wait so that a
# regression is a failed check in seconds rather than a hung terminal.
attempt() {
	local title="$1"; shift
	echo ""
	echo "=== $title"
	echo "    \$ $*"
	local start=$SECONDS
	"$@" >"$LOG" 2>&1
	status=$?
	elapsed=$(( SECONDS - start ))
	sed 's/^/    | /' "$LOG"
	echo "    -> exit $status after ${elapsed}s"
	if [[ $status -eq 137 ]]; then
		note "the run had to be killed from outside -- it did not end on its own"
	fi
}

attempt "a run where nothing is wrong still passes" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/passing
[[ $status -eq 0 ]] || note "expected exit 0, got $status"
has '^RUN   test_rng$' "the first suite was not named before it ran"
has '^PASS  rng ' "the per-suite pass line is not what it was"
has '^all 2 suites passed' "the summary is not what it was"

attempt "a failed check is still a failed run" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/failing
[[ $status -eq 1 ]] || note "expected exit 1, got $status"
has '^FAIL  failing ' "the failing suite has no failure line"
has '^1 of 2 suites failed' "the summary is not what it was"

attempt "a suite that raises a runtime error below its run()" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/throwing runner_fixtures/passing
[[ $status -ne 0 ]] || note "a suite threw and the run exited 0"
has '^RUN   throwing$' "the throwing suite was not named before it ran"
has "suite 'throwing' raised a runtime error" "the run does not say which suite threw"
has '^PASS  passing ' "the run did not carry on to the suite after it"

attempt "a suite the runner itself cannot enter" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/not_a_suite runner_fixtures/passing
[[ $status -ne 0 ]] || note "the runner broke on a suite and the run exited 0"
has '^RUN   test_rng$' "the run did not get as far as naming a suite"
has 'not_a_suite .*threw a runtime error' "the run does not say which suite broke it"
has "suite 'not_a_suite' raised a runtime error" "the wrapper blamed the wrong suite"
has '^PASS  passing ' "the run did not carry on to the suite after it"
has ' suites failed ' "the summary was not printed"

# What a stalled suite must say now, and what it must have cost. The budget is
# spent off the clock, so the check is a wall-time one: the run may not end
# before the budget, the silence it reports must be at least the budget, and it
# must not be much more than it -- a watchdog that overshoots by half its budget
# is the bug this replaced. The slack is one loop body plus the engine's own
# start, which is seconds; a tenth of the budget or five seconds, whichever is
# larger, covers that without covering a 35% drift.
# $1 is the budget the run was given, $2 how long the rest of the run -- engine
# starts, the suites after the stalled one -- is allowed to take on top of it.
stall_is_wall_time() {
	local budget="$1" overhead="$2" line silent_for slack
	line="$(grep -o 'stalled: printed nothing for [0-9]*s, budget [0-9]*s' "$LOG" | head -1)"
	if [[ -z "$line" ]]; then
		note "the stalled suite is not reported red, named with what it cost and the budget"
		return
	fi
	echo "    | measured: $line"
	silent_for="$(awk '{print $5}' <<<"$line" | tr -cd '0-9')"
	slack=$(( budget / 10 )); (( slack < 5 )) && slack=5
	(( silent_for >= budget )) \
		|| note "the run reports ${silent_for}s of silence, less than the ${budget}s budget"
	(( silent_for <= budget + slack )) \
		|| note "the run reports ${silent_for}s of silence against a ${budget}s budget: the budget the run prints is not the budget it enforces"
	(( elapsed >= budget )) || note "the run ended too soon to have been killed by the watchdog"
	(( elapsed <= budget + slack + overhead )) \
		|| note "the run took ${elapsed}s to enforce a ${budget}s budget"
}

attempt "a suite that never returns and never says anything" \
	env RUN_TESTS_SILENCE="$STALL_WAIT" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/stalling runner_fixtures/passing
[[ $status -ne 0 ]] || note "a suite hung and the run exited 0"
has '^RUN   stalling$' "the stalling suite was not named before it ran"
stall_is_wall_time "$STALL_WAIT" 30
# The whole point of one engine per suite: a suite nobody can afford to wait for
# costs itself a verdict and nothing else.
has '^PASS  passing ' "the run did not carry on to the suite after the stalled one"
has ' suites failed ' "a run with a stalled suite in it did not end on its own summary line"

# The same thing on a machine that cannot get round to the watchdog. This is the
# check the old watchdog could not pass: it counted `sleep 1` plus one `stat` as
# one second, so on a full run queue its budget stretched by 35% and the number
# the run printed stopped being the number it enforced. The load is put on and
# taken off inside this check so nothing else on the machine has to know.
tools/busy_load.sh "$GUARD_BUSY" 300 >"$RUNDIR/busy.log" 2>&1 &
busy=$!
for _ in $(seq 1 60); do grep -q 'load average' "$RUNDIR/busy.log" && break; sleep 1; done
sed 's/^/    | /' "$RUNDIR/busy.log"
# Only the stalling suite: on a machine this busy the engine needs longer than
# this check's own twenty-second budget just to start, so a second suite after
# it would be killed for the silence of its own startup. That is the budget
# being small, not the watchdog being wrong, and the real budget is measured in
# hours. What the run does after a stalled suite is checked above, unloaded.
attempt "a stalled suite on a machine with no time for the watchdog" \
	env RUN_TESTS_SILENCE="$STALL_WAIT" \
	timeout -s KILL "$WAIT" ./run_tests.sh runner_fixtures/stalling
kill -TERM "$busy" 2>/dev/null || true
[[ $status -ne 0 ]] || note "a suite hung under load and the run exited 0"
# Not the RUN line: on a machine this busy the engine can be killed before it
# gets as far as printing one, and the run then names the suite from the batch
# it was given. Either way the suite must be named, red, and counted.
has '^FAIL  runner_fixtures/stalling stalled' "the stalled suite is not named and red"
has ' suites failed ' "a run with a stalled suite in it did not end on its own summary line"
stall_is_wall_time "$STALL_WAIT" 60

attempt "a suite says where it has got to while it is still working" \
	env RUN_TESTS_PROGRESS=0 \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng
[[ $status -eq 0 ]] || note "expected exit 0, got $status"
has '^  \.\.  rng ' "a suite printed nothing between its RUN line and its PASS line"
has '^  \.\.  rng .* checks: ' "a progress line does not say what the suite was checking"
has '^PASS  rng .* checks$' "the pass line no longer ends in its check count"
has '^all 1 suites passed' "progress lines broke the summary's arithmetic"

# Delete every file matching $1 in the run directory, over and over, for as long
# as the run lasts. Repeating rather than deleting once means that whatever the
# runner writes last is still followed by a deletion, so the file is reliably
# gone by the time the closing checks look for it.
keep_deleting() {
	( for (( tick = 0; tick < $2; tick++ )); do
		rm -f "$RUNDIR"/$1 2>/dev/null
		sleep 0.05
	  done ) &
	deleter=$!
}

keep_deleting 'transcript.*' 1200
attempt "a run whose transcript is deleted under it" \
	env RUN_TESTS_RUNDIR="$RUNDIR" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/throwing
kill "$deleter" 2>/dev/null || true
[[ $status -ne 0 ]] || note "the transcript vanished under a run that threw, and it exited 0"
has "transcript is missing or unreadable" "the run does not name the transcript it could not read"

keep_deleting 'stalled.*' 1200
attempt "a run killed for silence whose stall flag is deleted under it" \
	env RUN_TESTS_SILENCE="$STALL_WAIT" RUN_TESTS_RUNDIR="$RUNDIR" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/stalling
kill "$deleter" 2>/dev/null || true
[[ $status -ne 0 ]] || note "a run was killed for silence with its flag deleted, and it exited 0"
has "stall flag is missing or unreadable" "the run does not name the stall flag it could not read"

echo ""
if [[ $failed -eq 0 ]]; then
	echo "runner guard OK: each of the three is named, none of them hangs, a"
	echo "runner guard OK: stalled suite costs only itself and is killed at the budget"
	echo "runner guard OK: the run prints -- on a busy machine too -- a suite says where"
	echo "runner guard OK: it has got to, and a check that could not be read fails the run"
	exit 0
fi
echo "runner guard FAILED"
exit 1
