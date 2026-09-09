#!/usr/bin/env bash
# Run the whole test suite headless. Exits 0 when everything passes.
#
#   ./run_tests.sh                      # every suite
#   ./run_tests.sh test_rng test_items  # only the suites named, by file stem
#   ./run_tests.sh --layers-only        # just the sim-must-not-see-render check
#
# Two of the ways a suite can go wrong cannot be handled by the runner itself,
# because of how this engine treats a runtime error. An error abandons the
# function it was raised in and returns to that function's caller; there is no
# way to catch one, and no way to ask afterwards whether one happened. So:
#
#   * a suite whose helper reads past the end of an array carries on and is
#     reported as a pass -- the full run of cycle 194 printed `PASS goals` for a
#     suite that had thrown. Any SCRIPT ERROR in the output fails the run here,
#     attributed to the suite named on the last RUN line before it.
#   * a suite that never returns -- an endless loop, or a child process that
#     never exits -- cannot be interrupted from inside the process at all. A run
#     that prints nothing for RUN_TESTS_SILENCE seconds (default 7200, well past
#     the slowest suite here) is killed and reported against the suite it was in.
#
# What the runner does handle is an error raised in its own frame, which used to
# be `_initialize()` and hung the process; see the head of bin/test_main.gd.
# ./run_runner_guard.sh checks all three against suites planted to provoke them.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

SCRIPT="res://bin/test_main.gd"
if [[ "${1:-}" == "--layers-only" ]]; then
	SCRIPT="res://bin/check_layers.gd"
	shift
fi

SILENCE="${RUN_TESTS_SILENCE:-7200}"

# The transcript belongs to the run, not to the shell that launched it. A full
# suite takes hours and routinely outlives the sandbox its launching cycle sat
# in, and $TMPDIR points inside that sandbox; a transcript written there is
# unlinked mid-run when the sandbox is torn down, and the closing checks below
# then read a path that is gone. So it is kept beside the checkout the run is
# testing, which outlives any one launching shell. RUN_TESTS_RUNDIR overrides
# the location -- ./run_runner_guard.sh uses it to delete a transcript on
# purpose. The EXIT trap still removes both files when the run ends normally.
RUNDIR="${RUN_TESTS_RUNDIR:-$PWD/.testruns}"
mkdir -p "$RUNDIR"
OUT="$(mktemp "$RUNDIR/transcript.XXXXXXXX")"
STALLED="$(mktemp "$RUNDIR/stalled.XXXXXXXX")"
trap 'rm -f "$OUT" "$STALLED"' EXIT

env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
	--headless --path . --script "$SCRIPT" -- "$@" >"$OUT" 2>&1 &
engine=$!

# Say it as it happens; tail stops on its own when the engine does.
tail -n +1 -f --pid="$engine" "$OUT" &
echoer=$!

# The bounded wait. It measures silence rather than total time, so an honest run
# of several hours is left alone and a run with nothing left to say is not.
(
	quiet=0
	seen=-1
	while [[ -d "/proc/$engine" ]]; do
		sleep 1
		size="$(stat -c %s "$OUT" 2>/dev/null || echo 0)"
		if [[ "$size" == "$seen" ]]; then
			quiet=$(( quiet + 1 ))
		else
			quiet=0
			seen="$size"
		fi
		if (( quiet >= SILENCE )); then
			echo "yes" >"$STALLED"
			kill -KILL "$engine" 2>/dev/null || true
			break
		fi
	done
) &
watchdog=$!

status=0
wait "$engine" || status=$?
kill -KILL "$watchdog" 2>/dev/null || true
wait "$echoer" 2>/dev/null || true

# Which suite the run was in when it last said anything, and which it was in
# when the first runtime error came out. Both read the runner's own RUN lines.
last_named() { awk '/^RUN   /{s=substr($0, 7)} END{print (s == "" ? "no suite yet" : s)}' "$OUT"; }
errored_in() { awk '/^RUN   /{s=substr($0, 7)} /^SCRIPT ERROR/{print (s == "" ? "no suite yet" : s); exit}' "$OUT"; }

# Neither closing check can be run on a file that is not there, and a check
# that could not be run is not a check that passed: `grep` on a missing path
# exits 2, which an `if` reads as "no match", and `[[ -s ]]` on one is simply
# false. Both would turn a run with a runtime error in it, or a run killed for
# silence, into a clean exit 0. So a transcript that has gone missing under the
# run is a failure of the run, named and loud.
readable_or_fail() {
	local path="$1" what="$2"
	[[ -f "$path" && -r "$path" ]] && return 0
	echo "" >&2
	echo "run_tests: the run's $what is missing or unreadable: $path" >&2
	echo "run_tests: it was written at the start of this run and is gone now, so" >&2
	echo "run_tests: neither the runtime-error check nor the stall check could be" >&2
	echo "run_tests: run. Nothing can be concluded about this run; it is failed here." >&2
	exit 2
}
readable_or_fail "$OUT" "transcript"
readable_or_fail "$STALLED" "stall flag"

if [[ -s "$STALLED" ]]; then
	echo ""
	echo "run_tests: nothing printed for ${SILENCE}s while running suite '$(last_named)'." >&2
	echo "run_tests: the run was killed. Nothing inside the process could end it." >&2
	exit 2
fi

if grep -q '^SCRIPT ERROR' "$OUT"; then
	echo ""
	echo "run_tests: suite '$(errored_in)' raised a runtime error (SCRIPT ERROR above)." >&2
	echo "run_tests: the engine returned to the caller and the runner could not see it," >&2
	echo "run_tests: so the run is failed here whatever the summary said." >&2
	if [[ $status -eq 0 ]]; then
		status=1
	fi
fi

exit "$status"
