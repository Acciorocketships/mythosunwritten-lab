# Watching upstream: is the adopted base still upstream's HEAD?

This repository adopted mythosunwritten as its base at a commit pinned in
[`ADOPTION.md`](../ADOPTION.md), and that repository keeps developing. A pin
against a live repository goes stale quietly: nothing in this tree changes on
the day upstream moves, so nothing here notices unless something asks.

`tools/upstream_watch.sh` is what asks.

    $ ./tools/upstream_watch.sh
    upstream-watch: base is CURRENT -- ADOPTION.md pin f3203d96 == upstream HEAD f3203d96 (https://github.com/Acciorocketships/mythosunwritten)

One line, one fact. Both halves of the comparison come from outside the
script: the pinned commit and the source URL are read out of `ADOPTION.md`'s
Provenance section, and the current HEAD comes from `git ls-remote`. The
script carries no copy of either, so advancing the pin in `ADOPTION.md` moves
the watch with it and there is never a second hash to forget.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | The base is current: upstream HEAD equals the pin. |
| 3 | Upstream has moved. The new HEAD is printed in full. |
| 4 | `--pins` found a second copy of the base commit somewhere in the tree. |
| 2 | The check could not run — no network, unreadable pin, or a reply without a HEAD. |

The separation of 3 from 2 is the point of the design. A watch that reports
"current" when it could not reach upstream is worse than no watch, because it
manufactures reassurance. This one names the failure instead:

    $ https_proxy=http://127.0.0.1:1 ./tools/upstream_watch.sh
    upstream-watch: CANNOT CHECK -- git ls-remote https://github.com/Acciorocketships/mythosunwritten HEAD failed: fatal: unable to access ... Connection refused (network down? upstream renamed?)
    $ echo $?
    2

## What it costs

Measured on this machine, ten consecutive runs of the default check: 0.23,
0.25, 0.26, 0.26, 0.26, 0.26, 0.29, 0.29, 0.30, 0.30 seconds — about a quarter
of a second, every time. It clones nothing and writes nothing: `git ls-remote`
reads the remote's ref advertisement and exits. Upstream is queried, never
touched.

That price is what makes a standing cadence affordable, and it is why the
default answer stops at "current or moved" and does not volunteer a distance.

## The optional distance, and what it costs extra

`--count` also says how many commits behind the base has fallen. A distance
cannot be read off the ref advertisement — it needs the commit graph between
the pin and HEAD — so this fetches commit objects (trees and blobs filtered
out, `--filter=tree:0`) into a throwaway bare repository, counts, and deletes
it. Measured here, three fetches of upstream's 949 commits: 0.48, 0.43, 0.44
seconds and 712 KiB on disk each time, against the ~189 MB a full clone of
their history would cost (`ADOPTION.md`). So the distance roughly triples the
wall time of the check and is the only part that touches the network for
objects rather than refs.

The cheap answer is always available without paying it: run the script with no
arguments. When the pin already equals HEAD, `--count` skips the fetch
entirely and says so, because the distance is zero by the line above.

Rehearsed against a real upstream commit seventeen commits behind HEAD (the
pin in `ADOPTION.md` was temporarily set to `0869a3de` and restored
byte-identical afterwards):

    upstream-watch: upstream has MOVED -- ADOPTION.md pin 0869a3de, upstream HEAD f3203d96 (f3203d96d1a7612059162d16487d29ab6f0c4944); file a finding, do not absorb it here
    upstream-watch: the base is 17 commit(s) behind upstream HEAD (counted by a treeless fetch, not a clone)

## The pin lives in exactly one place

`--pins` audits that claim against the tree rather than asserting it. It scans
every tracked line that mentions the adoption and carries a hash-shaped token,
skips tokens that resolve to a commit in *this* repository (our own history
being cited — the adoption commit `faf11f55`, for instance — is not a pin of
the base), and requires every remaining token to be a prefix of the pin in
`ADOPTION.md`.

    $ ./tools/upstream_watch.sh --pins
    upstream-watch: base is CURRENT -- ADOPTION.md pin f3203d96 == upstream HEAD f3203d96 (...)
    upstream-watch:   abbreviated copy, agrees with the pin: .gitignore:59
    upstream-watch:   abbreviated copy, agrees with the pin: project.godot:47
    upstream-watch: pin audit clean -- ADOPTION.md holds the only full pin; 2 other tracked mention(s) abbreviate it to f3203d96 and name ADOPTION.md

Three files are skipped because they *are* the watch and quote hashes for a
living: `ADOPTION.md` (the pin's home), this document (whose transcripts quote
upstream commits on purpose), and `tools/upstream_watch.sh` — which the audit
does not take on trust but checks directly, failing if the script has grown a
hash-shaped token of its own. It has none.

The two other mentions are provenance comments — `.gitignore`'s adopted block
and the `project.godot` note about their input actions — which abbreviate the
hash to eight characters and point the reader at `ADOPTION.md`. No tool reads
them. A drifted third copy fails this audit with `SECOND PIN` and a non-zero exit.
Rehearsed by planting one in a tracked file and removing it again:

    upstream-watch: SECOND PIN -- docs/_drift_probe.md:1:Adopted from mythosunwritten at commit deadbee1234...
    upstream-watch: the pin must live only in ADOPTION.md; see the lines above
    $ echo $?
    4

## When it runs, and what a moved upstream obliges

The check is registered as a project probe on a ten-cycle cadence, so it
recurs by arrangement rather than by anyone remembering it. The standing rule
`M-upstream-watch-runs-on-cadence-and-a-move-is-a-finding` records the same
occasion in the project's own memory.

When it exits 3, the obligation is narrow and deliberate: **file a finding
into the planning inbox naming the new upstream HEAD, and stop.** A delta is
not absorbed inside whatever work happened to notice it. Incorporating an
upstream update — re-importing the changed paths, re-resolving collisions, and
only then advancing the pin in `ADOPTION.md` — is its own planned item
(`W-upstream-delta-import`), because the base is adopted by squash import and
keeping up with it is a delta re-import, not a `git merge`
(`M-upstream-sync-is-a-delta-reimport-not-a-git-merge`).

## Today's answer

At cycle 3873, the command above printed `base is CURRENT`: upstream HEAD is
`f3203d96d1a7612059162d16487d29ab6f0c4944`, exactly the pin. Nothing is owed
yet — which is the only time a watch can be built calmly.
