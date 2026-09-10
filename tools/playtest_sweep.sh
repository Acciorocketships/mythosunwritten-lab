#!/usr/bin/env bash
# Delete playtest frames that this pass's session logs do not account for.
#
#   ./tools/playtest_sweep.sh [--dry-run]
#
# A playtest is a set of frames and the traces that made them. A frame left over
# from an earlier pass looks exactly like one from this pass and is a quiet lie
# in a report, so the only frames kept in `reports/assets/playtest-*.png` are the
# ones some `reports/playtest-*.log` says it wrote -- after
# `tools/playtest_retick.sh` has renamed them to the ticks they were taken on.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

dry=""
[ "${1:-}" = "--dry-run" ] && dry="yes"

kept=$(mktemp)
trap 'rm -f "$kept"' EXIT
# The name a frame ends up under is the one `tools/playtest_retick.sh` gives it:
# the tick the shell says it was taken on, not the tick the run asked for. So the
# kept name is rebuilt from the trace the same way that script rebuilds it.
grep -hoE "render-shell screenshot t=[0-9]+ reports/assets/[^ ]+\.png" reports/playtest-*.log \
	| sed -E "s/render-shell screenshot t=([0-9]+) (.*)-t[0-9]+\.png/\2-t\1.png/" >> "$kept"
# And a frame another report has already published stays, even though no session
# log here made it. `reports/fight-drawn.md` shows a playtest frame as the
# *before* picture its fix is judged against; sweeping that away because this
# pass's runs did not write it would take a published report's evidence with it.
# reports/playtest.md is excluded because it is this pass's own report: its
# frames have to come from this pass's own logs or not at all.
for report in reports/*.md; do
	[ "$report" = "reports/playtest.md" ] && continue
	# `|| true`: a report with no playtest frame in it is the ordinary case, and
	# under `pipefail` grep's empty-handed exit would end the sweep at the first
	# one of them.
	{ grep -ohE "playtest-[a-z0-9-]+-t[0-9]+\.png" "$report" 2>/dev/null || true; } \
		| sed -E "s#^#reports/assets/#"
done >> "$kept"
sort -u -o "$kept" "$kept"

gone=0
for frame in reports/assets/playtest-*.png; do
	[ -e "$frame" ] || continue
	if ! grep -qxF "$frame" "$kept"; then
		echo "stale: $frame"
		[ -n "$dry" ] || rm -f "$frame" "$frame.import"
		gone=$((gone + 1))
	fi
done
echo "$(wc -l < "$kept") frame(s) accounted for, $gone stale$([ -n "$dry" ] && echo " (dry run)")"
