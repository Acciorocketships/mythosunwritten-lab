#!/usr/bin/env bash
# Check that a suite which misbehaves is reported by name instead of being
# passed over or waited on forever.
#
#   ./run_runner_guard.sh
#
# It runs the ordinary command over the suites in tests/runner_fixtures/, each
# planted to break the runner in one of the three ways this engine allows, and
# requires of each run that it ends on its own, names the suite it was in, and
# exits non-zero. Two ordinary runs bracket them: one where everything passes
# and one where a check fails, to show those are unchanged.
#
# Takes about two minutes. The suites it borrows are the two cheapest real ones.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

WAIT="${RUNNER_GUARD_WAIT:-300}"
STALL_WAIT="${RUNNER_GUARD_STALL_WAIT:-20}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

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
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng test_asset_tags
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
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/throwing test_asset_tags
[[ $status -ne 0 ]] || note "a suite threw and the run exited 0"
has '^RUN   throwing$' "the throwing suite was not named before it ran"
has "suite 'throwing' raised a runtime error" "the run does not say which suite threw"
has '^PASS  asset tags ' "the run did not carry on to the suite after it"

attempt "a suite the runner itself cannot enter" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/not_a_suite test_asset_tags
[[ $status -ne 0 ]] || note "the runner broke on a suite and the run exited 0"
has '^RUN   test_rng$' "the run did not get as far as naming a suite"
has 'not_a_suite .*threw a runtime error' "the run does not say which suite broke it"
has "suite 'not_a_suite' raised a runtime error" "the wrapper blamed the wrong suite"
has '^PASS  asset tags ' "the run did not carry on to the suite after it"
has ' suites failed ' "the summary was not printed"

attempt "a suite that never returns and never says anything" \
	env RUN_TESTS_SILENCE="$STALL_WAIT" \
	timeout -s KILL "$WAIT" ./run_tests.sh test_rng runner_fixtures/stalling
[[ $status -ne 0 ]] || note "a suite hung and the run exited 0"
has '^RUN   stalling$' "the stalling suite was not named before it ran"
has "suite 'stalling'" "the run does not say which suite it was in when it stopped"

echo ""
if [[ $failed -eq 0 ]]; then
	echo "runner guard OK: each of the three is named and none of them hangs"
	exit 0
fi
echo "runner guard FAILED"
exit 1
