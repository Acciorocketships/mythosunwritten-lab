# How long the runner actually let a silent engine live.
#
# Reads one ./run_tests.sh memory recording. The recording carries, every two
# seconds, the wall clock, how many engines are up, and how many bytes of
# transcript there are. The silence the watchdog enforced is the stretch from
# the last moment the transcript grew to the moment the engine went away -- the
# same quantity the watchdog is supposed to bound, read off the machine rather
# than off the watchdog's own counter.
function secs(hms,   t) { split(hms, t, ":"); return t[1]*3600 + t[2]*60 + t[3] }
!/^#/ && NF >= 6 {
	now = secs($1); if (now < prev) day += 86400; prev = now; now += day
	if ($6 != bytes) { bytes = $6; grew_at = now }
	if ($3 + 0 > 0) { alive_at = now; if (!started) started = now }
	if ($5 + 0 > 0 && ($5 + 0 < least || least == 0)) least = $5 + 0
	if ($4 + 0 > heaviest) heaviest = $4 + 0
}
END {
	printf "last transcript growth at %.0f s into the run\n", grew_at - started
	printf "engine last seen alive at %.0f s into the run\n", alive_at - started
	printf "SILENCE THE RUNNER ENFORCED: %.0f s (+/- 2 s, the sampler's step)\n", \
		alive_at - grew_at
	printf "engines held at most %.2f GiB; the machine's free memory fell to %.2f GiB\n", \
		heaviest, least
}
