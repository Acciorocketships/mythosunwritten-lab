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

attempt "a suite that never returns and never says anything" \
	env RUN_TESTS_SILENCE="$STALL_WAIT" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/stalling runner_fixtures/passing
[[ $status -ne 0 ]] || note "a suite hung and the run exited 0"
(( elapsed >= STALL_WAIT )) || note "the run ended too soon to have been killed by the watchdog"
has '^RUN   stalling$' "the stalling suite was not named before it ran"
has "stalling.*stalled: printed nothing for ${STALL_WAIT}s" \
	"the stalled suite is not reported red, named with the budget it crossed"
# The whole point of one engine per suite: a suite nobody can afford to wait for
# costs itself a verdict and nothing else.
has '^PASS  passing ' "the run did not carry on to the suite after the stalled one"
has ' suites failed ' "a run with a stalled suite in it did not end on its own summary line"

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
	echo "runner guard OK: stalled suite costs only itself, a suite says where it"
	echo "runner guard OK: has got to, and a check that could not be read fails the run"
	exit 0
fi
echo "runner guard FAILED"
exit 1
