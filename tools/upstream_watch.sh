#!/usr/bin/env bash
# Say in one line whether the adopted base is still upstream's HEAD.
#
#   ./tools/upstream_watch.sh            # the cheap answer: one ls-remote
#   ./tools/upstream_watch.sh --count    # ...plus how many commits behind
#   ./tools/upstream_watch.sh --pins     # ...audit: ADOPTION.md is the only pin
#
# This repository adopted mythosunwritten at a commit pinned in ADOPTION.md,
# and that repository keeps developing. The pin is therefore a moving target,
# and this is the watch that notices. Both the pin and the source URL are read
# out of ADOPTION.md -- this script carries no copy of either -- so the pin
# stays in exactly one place and advancing it there moves the watch with it.
#
# Nothing is cloned and nothing upstream is touched: `git ls-remote` reads the
# remote's ref advertisement and exits. It is sub-second (see docs/upstream-
# watch.md) and safe to run on every cadence.
#
# Exit codes, so a caller can branch without parsing prose:
#   0  base is current -- upstream HEAD equals the pin
#   3  upstream has MOVED -- the new HEAD is printed; file a finding
#   4  --pins found a second copy of the base commit in the tree
#   2  the check could not run (no network, unreadable pin, bad reply).
#      It never reports "current" when it could not ask.
# A moved upstream (3) outranks a failed pin audit (4) when both are true.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ADOPTION="ADOPTION.md"
TIMEOUT="${UPSTREAM_WATCH_TIMEOUT:-60}"

fail() { echo "upstream-watch: CANNOT CHECK -- $*" >&2; exit 2; }

[[ -r "$ADOPTION" ]] || fail "$ADOPTION is not readable from $(pwd)"

# The pin and the source URL, read out of ADOPTION.md's Provenance section.
PIN="$(sed -n 's/^- Source commit: `\([0-9a-f]\{40\}\)`.*/\1/p' "$ADOPTION" | head -1)"
URL="$(sed -n 's|^- Source: \(https\?://[^ ]*\)$|\1|p' "$ADOPTION" | head -1)"
[[ -n "$PIN" ]] || fail "no 40-hex 'Source commit' line found in $ADOPTION"
[[ -n "$URL" ]] || fail "no 'Source:' URL line found in $ADOPTION"
SHORT="${PIN:0:8}"

audit_pins() {
  # Every tracked line that mentions the adoption and carries a hash-shaped
  # token must agree with the pin above. Tokens that resolve to a commit in
  # THIS repository are our own history being cited (the adoption commit, for
  # instance) and are not pins of the base; a token that resolves nowhere here
  # is an upstream hash, and a drifted second copy of one fails the audit.
  local bad=0 line file text tok n=0 skipped=0
  # Three files are the watch itself and quote hashes for a living: the pin's
  # own home, this script (asserted below to carry no hash at all), and the
  # documentation, whose transcripts quote upstream commits on purpose.
  local self_docs=" $ADOPTION docs/upstream-watch.md tools/upstream_watch.sh "
  if grep -q -E '\b[0-9a-f]{7,40}\b' tools/upstream_watch.sh; then
    echo "upstream-watch: SECOND PIN -- tools/upstream_watch.sh has grown a hash of its own" >&2
    bad=1
  fi
  while IFS= read -r line; do
    file="${line%%:*}"; text="${line#*:}"; text="${text#*:}"
    if [[ "$self_docs" == *" $file "* ]]; then skipped=$((skipped + 1)); continue; fi
    for tok in $(grep -o -E '\b[0-9a-f]{7,40}\b' <<<"$text"); do
      git rev-parse --verify --quiet "$tok^{commit}" >/dev/null 2>&1 && continue
      if [[ "$PIN" == "$tok"* ]]; then
        echo "upstream-watch:   abbreviated copy, agrees with the pin: ${line%%:*}:$(cut -d: -f2 <<<"$line")"
        n=$((n + 1))
      else
        echo "upstream-watch: SECOND PIN -- $line" >&2
        bad=1
      fi
    done
  done < <(git grep -I -n -E 'mythosunwritten|ADOPTION\.md' -- . \
           | grep -E '\b[0-9a-f]{7,40}\b' || true)
  if (( bad )); then
    echo "upstream-watch: the pin must live only in $ADOPTION; see the lines above" >&2
    return 1
  fi
  echo "upstream-watch: pin audit clean -- $ADOPTION holds the only full pin; $n other tracked mention(s) abbreviate it to $SHORT and name $ADOPTION; $skipped line(s) skipped in the watch's own files (tools/upstream_watch.sh carries no hash, checked above)"
  return 0
}

count_behind() {
  # The cheap answer above needed no objects. A distance needs the commit graph
  # between the pin and HEAD, so this fetches commits (trees and blobs filtered
  # out) into a throwaway bare repo. Cost is stated in docs/upstream-watch.md;
  # it is orders of magnitude above the ls-remote, which is why it is opt-in
  # and why the default answer never pays it.
  local head="$1" work n
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  git init --quiet --bare "$work" || { echo "upstream-watch: distance unavailable (init failed)" >&2; return 1; }
  if ! GIT_TERMINAL_PROMPT=0 timeout "$TIMEOUT" \
        git -C "$work" fetch --quiet --filter=tree:0 --no-tags "$URL" "$head" 2>/dev/null; then
    echo "upstream-watch: distance unavailable (treeless fetch failed); the line above still stands" >&2
    return 1
  fi
  n="$(git -C "$work" rev-list --count "$PIN..FETCH_HEAD" 2>/dev/null)" || {
    echo "upstream-watch: distance unavailable (the pin is not an ancestor of upstream HEAD -- upstream may have rewritten history)" >&2
    return 1
  }
  echo "upstream-watch: the base is $n commit(s) behind upstream HEAD (counted by a treeless fetch, not a clone)"
}

WANT_COUNT=0 WANT_PINS=0
for arg in "$@"; do
  case "$arg" in
    --count) WANT_COUNT=1 ;;
    --pins)  WANT_PINS=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) fail "unknown argument: $arg" ;;
  esac
done

REMOTE="$(GIT_TERMINAL_PROMPT=0 timeout "$TIMEOUT" git ls-remote --exit-code "$URL" HEAD 2>&1)" || \
  fail "git ls-remote $URL HEAD failed: ${REMOTE:-no output} (network down? upstream renamed?)"
HEAD_SHA="$(awk '/[[:space:]]HEAD$/ {print $1; exit}' <<<"$REMOTE")"
[[ "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]] || fail "upstream answered without a HEAD sha: ${REMOTE:-empty}"

status=0
if [[ "$HEAD_SHA" == "$PIN" ]]; then
  echo "upstream-watch: base is CURRENT -- $ADOPTION pin $SHORT == upstream HEAD $SHORT ($URL)"
else
  echo "upstream-watch: upstream has MOVED -- $ADOPTION pin $SHORT, upstream HEAD ${HEAD_SHA:0:8} ($HEAD_SHA); file a finding, do not absorb it here"
  status=3
fi

(( WANT_COUNT )) && [[ "$HEAD_SHA" != "$PIN" ]] && count_behind "$HEAD_SHA"
(( WANT_COUNT )) && [[ "$HEAD_SHA" == "$PIN" ]] && echo "upstream-watch: distance is 0 by the line above; no fetch needed"
(( WANT_PINS )) && { audit_pins || { (( status == 0 )) && status=4; }; }

exit "$status"
