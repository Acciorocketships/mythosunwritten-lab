#!/usr/bin/env bash
# Put this machine's run queue under a named load, and take it off again.
#
#   tools/busy_load.sh 1200 180        # 1200 runnable shells for 180 seconds
#
# The runner's silence watchdog used to count loop iterations rather than
# seconds: one `sleep 1` plus one `stat` was taken for one second whatever it
# really cost. What makes that cost more than a second is not a full machine --
# an engine holding 22.56 GiB of this machine's 27.4 was measured and moved it
# by half a percent -- but a machine that cannot get round to the loop. This is
# the smallest honest way to produce one.
#
# It prints the load average it reached, so a measurement taken under it can
# say what "under load" meant.
set -uo pipefail
workers="${1:-1200}"
seconds="${2:-180}"
pids=()
for (( i = 0; i < workers; i++ )); do
	( end=$(( SECONDS + seconds )); while (( SECONDS < end )); do :; done ) &
	pids+=($!)
done
sleep 5
echo "busy_load: $workers runnable shells, load average now $(cut -d' ' -f1-3 /proc/loadavg)"
trap 'kill "${pids[@]}" 2>/dev/null; exit 0' TERM INT
wait "${pids[@]}" 2>/dev/null
echo "busy_load: done"
