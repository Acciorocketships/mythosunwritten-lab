#!/usr/bin/env bash
# Run the whole test suite headless. Exits 0 when everything passes.
#
#   ./run_tests.sh                      # every suite
#   ./run_tests.sh test_rng test_items  # only the suites named, by file stem
#   ./run_tests.sh --layers-only        # just the sim-must-not-see-render check
#
# One run, several engines. The suites used to run end to end inside a single
# engine process, and on the adopted ground that process no longer fits this
# machine: nothing between suites gives back what the last one built, and a
# suite that calls OS.execute holds a second full engine on top of the first,
# so the kernel took the run twice before it could reach its own summary. So a
# run now walks its suites RUN_TESTS_BATCH at a time (default 1), each batch in
# its own engine, which starts from nothing and gives every page back when it
# exits. The transcript is still one transcript and the run still ends on one
# summary line, counted from the per-suite lines the engines printed into it.
#
# What the run cost is written down rather than guessed at: a sampler records
# the resident memory of every engine on the machine every two seconds against
# the suite the run was in, and the run ends by printing the peak of each suite.
# RUN_TESTS_MEMLOG says where that recording is kept.
#
# A run refuses to start while another engine is up. An abandoned run holds its
# whole heap, and two runs on one machine decide each other's verdicts: one
# clearing "leftover" engines kills the other's suite, which is how a passing
# test_terrain was once recorded as killed. The refusal names what is running,
# and names whatever still holds the run lock even when the run that took it is
# gone. From the other side: a run that is killed outright, so that its EXIT
# trap never runs, does not leave an engine behind either -- the sampler sees
# its parent go and takes the engines with it.
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
# A third way exists now that a batch is a process: the kernel can kill a batch
# outright. The suite it was inside is named and failed, and the run carries on
# with the suites after it, because the point of a run is a verdict for every
# suite and one suite that cannot be afforded must not silence seventy-two.
#
# What the runner does handle is an error raised in its own frame, which used to
# be `_initialize()` and hung the process; see the head of bin/test_main.gd.
# ./run_runner_guard.sh checks all of it against suites planted to provoke them.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./godot_env.sh

SCRIPT="res://bin/test_main.gd"
LAYERS_ONLY=0
if [[ "${1:-}" == "--layers-only" ]]; then
	SCRIPT="res://bin/check_layers.gd"
	LAYERS_ONLY=1
	shift
fi

SILENCE="${RUN_TESTS_SILENCE:-7200}"
# How many suites one engine is asked to run. One is the safe bound measured on
# this machine -- see the memory table any run prints -- and raising it trades
# engine starts (about five seconds each, measured) for a higher peak.
BATCH="${RUN_TESTS_BATCH:-1}"

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

# ---------------------------------------------------------------------------
# Before anything: is this machine free?
#
# The check is psutil's and not `ps`'s because in the sandbox these runs happen
# in, `ps` and `kill -0` answer "Operation not permitted" whatever is really
# there, while pgrep and psutil see the truth.
# ---------------------------------------------------------------------------
python3 - <<'PY' || exit 3
import sys, time

try:
	import psutil
except ImportError:  # no psutil: say so rather than pretend the check ran
	print("run_tests: psutil is not installed, so the machine could not be",
	      file=sys.stderr)
	print("run_tests: checked for engines left behind by an earlier run.",
	      file=sys.stderr)
	sys.exit(3)

now = time.time()
found = []
for proc in psutil.process_iter(["pid", "name", "cmdline", "create_time"]):
	try:
		if not (proc.info["name"] or "").startswith("godot"):
			continue
		cmd = proc.info["cmdline"] or []
		found.append((
			proc.pid,
			(now - proc.info["create_time"]) / 60.0,
			proc.memory_info().rss / 2 ** 30,
			" ".join(cmd[cmd.index("--") + 1:]) if "--" in cmd else " ".join(cmd[-2:]),
		))
	except psutil.Error:
		continue

if found:
	print("", file=sys.stderr)
	print("run_tests: an engine from another run is still on this machine, so",
	      file=sys.stderr)
	print("run_tests: this run will not start. Two engines on one machine take",
	      file=sys.stderr)
	print("run_tests: each other's memory and each other's verdicts: the run",
	      file=sys.stderr)
	print("run_tests: that clears 'leftovers' kills the other run's suite.",
	      file=sys.stderr)
	for pid, age, rss, what in found:
		print("run_tests:   pid %d, up %.1f min, holding %.2f GiB, running: %s"
		      % (pid, age, rss, what or "(no suites named)"), file=sys.stderr)
	print("run_tests: end that run, or kill those pids, then start this one.",
	      file=sys.stderr)
	sys.exit(3)
PY

# And is another run's shell between engines, where the check above sees
# nothing? The lock says so. It is opened for append so the holder's own note
# survives being read.
exec 9>>"$RUNDIR/run.lock"
if ! flock -n 9; then
	echo "" >&2
	echo "run_tests: another run of this suite holds $RUNDIR/run.lock:" >&2
	sed 's/^/run_tests:   /' "$RUNDIR/run.lock" >&2 || true
	# The note says which run took the lock; this says what is still holding it,
	# which is not always the same thing once a run has been killed outright.
	python3 - "$RUNDIR/run.lock" <<'HOLDER' >&2 || true
import os, sys

try:
	import psutil
except ImportError:
	sys.exit(0)

want = os.stat(sys.argv[1]).st_ino
for proc in psutil.process_iter(["pid", "name", "cmdline"]):
	try:
		for handle in proc.open_files():
			if os.stat(handle.path).st_ino == want:
				print("run_tests:   held open by pid %d: %s"
				      % (proc.pid, " ".join(proc.info["cmdline"] or [])[:90]))
	except Exception:
		continue
HOLDER
	echo "run_tests: wait for it, or end it, then start this one." >&2
	exit 3
fi
: >"$RUNDIR/run.lock"
echo "pid $$ started $(date -Is) as: $0 $*" >&9

OUT="$(mktemp "$RUNDIR/transcript.XXXXXXXX")"
STALLED="$(mktemp "$RUNDIR/stalled.XXXXXXXX")"
FIFO="$RUNDIR/pipe.$$"
# The memory recording is evidence and outlives the run; the transcript and the
# stall flag are the run's own scratch and do not.
MEMLOG="${RUN_TESTS_MEMLOG:-$RUNDIR/memory.$(date +%Y%m%d-%H%M%S).log}"
cleanup() {
	# Never `kill 0` -- that is the whole process group, this shell included.
	[[ -n "${sampler:-}" ]] && kill -KILL "$sampler" 2>/dev/null
	rm -f "$OUT" "$STALLED" "$FIFO"
	return 0
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# The recording. Every two seconds: how many engines are up, what they hold
# between them, what the machine has left, and which suite the run was in --
# read from the RUN lines the engines write into the transcript.
# ---------------------------------------------------------------------------
python3 - "$OUT" "$MEMLOG" <<'PY' 9>&- &
import os, sys, time

try:
	import psutil
except ImportError:
	sys.exit(0)

transcript, memlog = sys.argv[1], sys.argv[2]
suite, pos, tail = "(starting)", 0, b""
# The run's shell can be killed outright, and then its EXIT trap never runs.
# An orphaned sampler would sit here for ever holding the run's lock, which is
# the very thing this runner refuses to start next to, so it ends with its
# parent.
parent = os.getppid()
with open(memlog, "w", buffering=1) as log:
	log.write("# resident memory of every engine of one ./run_tests.sh run\n")
	log.write("# this machine has %.1f GiB\n"
	          % (psutil.virtual_memory().total / 2 ** 30))
	log.write("# time suite engines rss_gib avail_gib\n")
	while True:
		if os.getppid() != parent:
			# The run's shell was killed outright -- by a supervisor's timeout,
			# by the probe that gives up on this run at 180 s, by anything that
			# does not let the EXIT trap run. Its engines would otherwise stay
			# up holding their whole heap and decide the next run's verdict.
			for proc in psutil.process_iter(["name"]):
				try:
					if (proc.info["name"] or "").startswith("godot"):
						proc.kill()
				except psutil.Error:
					continue
			break
		try:
			with open(transcript, "rb") as handle:
				handle.seek(pos)
				chunk = handle.read()
				pos += len(chunk)
			tail += chunk
			for line in tail.split(b"\n")[:-1]:
				text = line.decode("utf-8", "replace")
				if text.startswith("RUN   "):
					suite = text[6:].strip()
			tail = tail.split(b"\n")[-1]
		except OSError:
			pass
		rss, engines = 0.0, 0
		for proc in psutil.process_iter(["name"]):
			try:
				if (proc.info["name"] or "").startswith("godot"):
					rss += proc.memory_info().rss
					engines += 1
			except psutil.Error:
				continue
		log.write("%s %s %d %.2f %.2f\n" % (
			time.strftime("%H:%M:%S"), suite, engines, rss / 2 ** 30,
			psutil.virtual_memory().available / 2 ** 30,
		))
		time.sleep(2)
PY
sampler=$!
# Out of the job table: when this is killed at the end of the run, bash would
# otherwise print the whole sampler source as the "Killed" job's command line.
disown "$sampler" 2>/dev/null || true

# ---------------------------------------------------------------------------
# One engine. Everything it prints lands in the transcript, and the run's own
# echo follows it from where this engine started writing.
# ---------------------------------------------------------------------------
run_engine() {
	local start_off
	# A transcript can go missing under a run -- a sandbox teardown does it, and
	# ./run_runner_guard.sh does it on purpose. That is checked for and reported
	# between batches; here it must not take the shell down without a word.
	start_off="$(stat -c %s "$OUT" 2>/dev/null || echo 0)"

	rm -f "$FIFO"
	mkfifo "$FIFO"
	# The engine greets every start with its version line; one run wants one
	# greeting, so all but the first are dropped on the way to the transcript.
	sed -u '/^Godot Engine v/d' <"$FIFO" >>"$OUT" 9>&- &
	local filter=$!

	env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
		--headless --path . --script "$SCRIPT" -- "$@" >"$FIFO" 2>&1 9>&- &
	local engine=$!

	# Say it as it happens; tail stops on its own when the filter does.
	tail -c "+$(( start_off + 1 ))" -f --pid="$filter" "$OUT" 9>&- &
	local echoer=$!

	# The bounded wait. It measures silence rather than total time, so an honest
	# run of several hours is left alone and a run with nothing left to say is
	# not.
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
	) 9>&- &
	local watchdog=$!

	engine_status=0
	wait "$engine" || engine_status=$?
	kill -KILL "$watchdog" 2>/dev/null || true
	wait "$filter" 2>/dev/null || true
	wait "$echoer" 2>/dev/null || true
	engine_slice_from="$start_off"
}

# What this engine's slice of the transcript says: how many suites it entered,
# and how many of those it finished. A suite that was entered and not finished
# is the suite the engine died inside.
slice_counts() {
	tail -c "+$(( engine_slice_from + 1 ))" "$OUT" | awk '
		/^RUN   /  { entered += 1 }
		/^(PASS|FAIL)  / && !/no such suite/ { done_ += 1 }
		END { print entered + 0, done_ + 0 }
	'
}

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

stalled_or_continue() {
	readable_or_fail "$OUT" "transcript"
	readable_or_fail "$STALLED" "stall flag"
	if [[ -s "$STALLED" ]]; then
		echo ""
		echo "run_tests: nothing printed for ${SILENCE}s while running suite '$(last_named)'." >&2
		echo "run_tests: the run was killed. Nothing inside the process could end it." >&2
		exit 2
	fi
}

# ---------------------------------------------------------------------------
# The layer check is one script and one engine; it has no suites to spread.
# ---------------------------------------------------------------------------
if (( LAYERS_ONLY )); then
	run_engine "$@"
	stalled_or_continue
	if grep -q '^SCRIPT ERROR' "$OUT"; then
		echo ""
		echo "run_tests: the layer check raised a runtime error (SCRIPT ERROR above)." >&2
		exit 1
	fi
	exit "$engine_status"
fi

# ---------------------------------------------------------------------------
# The suites this run will work through: the ones named on the command line, or
# the engine's own list, so that the list lives in exactly one place.
# ---------------------------------------------------------------------------
declare -a pending=()
if (( $# > 0 )); then
	pending=("$@")
else
	mapfile -t pending < <(
		env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" \
			--headless --path . --script "$SCRIPT" -- --list 2>/dev/null \
			| grep '^test_'
	)
	if (( ${#pending[@]} == 0 )); then
		echo "run_tests: the engine named no suites, so there is nothing to run" >&2
		echo "run_tests: and nothing can be concluded. Failed here." >&2
		exit 2
	fi
fi

status=0
while (( ${#pending[@]} > 0 )); do
	chunk=("${pending[@]:0:BATCH}")
	rest=("${pending[@]:BATCH}")

	run_engine --batch "${chunk[@]}"
	stalled_or_continue

	if (( engine_status > 1 )); then
		# Not a verdict: the engine went away. Name the suite it was inside,
		# fail it, and carry on with the ones after it.
		read -r entered done_ < <(slice_counts)
		if (( entered > done_ && entered > 0 )); then
			killed="${chunk[$(( entered - 1 ))]}"
			printf 'FAIL  %-14s the engine died (exit %d) before the suite returned\n' \
				"$killed" "$engine_status" >>"$OUT"
			echo "FAIL  $killed: the engine died (exit $engine_status) before the suite returned"
		fi
		if (( entered < 1 )); then
			entered=1
		fi
		pending=("${chunk[@]:$entered}" "${rest[@]}")
		status=1
		continue
	fi

	if (( engine_status != 0 )); then
		status=1
	fi
	pending=("${rest[@]}")
done

readable_or_fail "$OUT" "transcript"

if grep -q '^SCRIPT ERROR' "$OUT"; then
	echo ""
	echo "run_tests: suite '$(errored_in)' raised a runtime error (SCRIPT ERROR above)." >&2
	echo "run_tests: the engine returned to the caller and the runner could not see it," >&2
	echo "run_tests: so the run is failed here whatever the summary said." >&2
	status=1
fi

kill -KILL "$sampler" 2>/dev/null || true
sampler=""

# ---------------------------------------------------------------------------
# What the run cost, suite by suite, and then the one sentence that ends it.
# The counts are read back off the lines the engines printed, so the arithmetic
# of a suite stays the engine's and the arithmetic of a run stays the run's.
# ---------------------------------------------------------------------------
echo ""
echo "resident memory of this run, by suite (every engine on the machine):"
awk '
	!/^#/ && NF >= 5 {
		if (!($2 in first)) { first[$2] = ++n; order[n] = $2 }
		if ($4 + 0 > peak[$2]) peak[$2] = $4 + 0
	}
	END {
		for (i = 1; i <= n; i++) {
			s = order[i]
			printf "  %2d  %-22s peak %6.2f GiB\n", i, s, peak[s]
			if (peak[s] > worst) { worst = peak[s]; who = s; where = i }
		}
		printf "  peak of the whole run: %.2f GiB, in suite %d (%s)\n", worst, where, who
	}
' "$MEMLOG" 2>/dev/null || echo "  (no memory recording: $MEMLOG)"
echo "  recorded in $MEMLOG"

echo ""
awk '
	# A suite names itself, and a name can hold a space ("asset tags"), so the
	# numbers are read off the end of the line rather than counted into from
	# the front. PASS ends "<n> checks"; FAIL ends "<n> checks, <m> failed"
	# unless the suite threw, was missing, or its engine died, and those three
	# are one failure each with no checks to their name.
	/^PASS  / {
		suites += 1
		if (match($0, /[0-9]+ checks$/)) {
			split(substr($0, RSTART, RLENGTH), w, " ")
			checks += w[1] + 0
		}
	}
	/^FAIL  / {
		suites += 1; failed += 1
		if (match($0, /[0-9]+ checks, [0-9]+ failed$/)) {
			split(substr($0, RSTART, RLENGTH), w, " ")
			checks += w[1] + 0
			failures += w[3] + 0
		} else {
			failures += 1
		}
	}
	END {
		if (failed == 0)
			printf "all %d suites passed (%d checks)\n", suites, checks
		else
			printf "%d of %d suites failed (%d failed checks of %d)\n", \
				failed, suites, failures, checks
	}
' "$OUT"

exit "$status"
