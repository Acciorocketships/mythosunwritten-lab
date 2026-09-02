# Asking the candidate bound once per cell: the raw recordings

Every number in the "the same bound, once per cell" section of
`reports/islands.md` comes from the runs pasted below. They were taken in one
sitting on one machine, on one tree.

**What "before" and "after" mean here.** "Before" is the tree as it stood at the
start of this change, reached by `IslandField.gate_cells_by_candidate = false`,
which makes `_cells_around` build every cell in range and discard the islands
that turn out to be too far — byte for byte what it did. "After" is the shipped
tree: each cell is asked for its candidate — where its island would stand and how
far its outline could reach, both hashed out of the cell, the band and the seed —
and is built only where those hashes cannot rule it out.

**One caution about reading these against the last recorded series.** The
previous recording (`reports/island-overhead-cost-evidence.md`, two cycles back)
was made on a different tree: the island basin and its water level have been
reworked since, which moves ground, islands and therefore villages. So the
seed-1234 fingerprint here is `a6aa8e5776ebfe8c` where that recording has
`020507a9a1d52a1e`, and the six-seed village count is 25 where it was 27 —
neither of which this change caused, as the before/after pair below shows: the
same 25 villages with identical digests either way.

## The series, in one table

| | last recorded (cycle 58) | before (this tree, gate off) | after (this tree) |
|---|---|---|---|
| overhead question, cold field, ms per ask | 67.5 | 66.8 | **3.36** |
| islands built per overhead ask | — | 36.75 of 98 | **0.90 of 98** |
| one settlement cell, cold, ms | 22.0 | 21.7 | **6.41** |
| one settlement cell, warm, ms | 22.5 | 21.3 | **7.28** |
| headless, 100 ticks, seed 1234, s | 6.83 | 7.48 | **6.45** |
| whole suite | 8m46s (161,870 checks) | 9m00s (169,814) | **6m20s (169,814)** |
| one warm island lookup, µs | — | 23.9 | **25.5** |
| one `surfaces_at`, µs | — | 1462 | **657** |
| villages over 6 seeds × 25 cells | 27 | 25 | **25, same digests** |

The "islands built per ask" row is the one the change is really about: 98 is the
two walkable storeys' 49 cells each that the overhead question scans, and 0.90 is
how many of them are now built. The proposal predicted roughly 1.5; it is 0.90.

## The bench: `tests/bench_settlements.gd`, with and without `--ungated`

`builds_per_ask` is new: `IslandField.builds` counts the cells a field has
actually built, including the ones that turn out to hold no island, and the field
is fresh per ask, so it is that ask's own count. A build samples the ground about
150 times; everything else in the layer is hashes.

### before — every cell in range built

```
bench settlements gate=off
bench settlements seed=1234 cells=25 villages=5 sites=a944e9c7013a498a ae91b3d783fc7cea 89f90e2544ea8161 c02678d9477e59b6 35fc8c53dded0549
bench settlements seed=7 cells=25 villages=3 sites=f2056e63ac51ee90 27116ce02d9864e2 7fbd0ca009ac6a41
bench settlements seed=3 cells=25 villages=4 sites=1772f7a319365f0d ea2b3c35308de15c fdc416e9b2e3c157 ab3bf556ea8494b9
bench settlements seed=19 cells=25 villages=3 sites=840a597536d3c79a d388a5ad100db299 69c87495e8bfea17
bench settlements seed=42 cells=25 villages=2 sites=0ae99160bc9eff3e 3bd18b6f3e9f1400
bench settlements seed=101 cells=25 villages=8 sites=192817c88c565f61 2683ac1aa99d42ce 8b97cd57d714b571 1d13a2342e97788e 12b2d5daa3f97869 8bead2f90be62afa 66ed4f86ebb34130 6f4aab387765e79f
bench settlements seeds=6 cells=150 villages=25 warm_usec_per_cell=21263
bench settlements cold cells=54 villages=13 cold_usec_per_cell=21678
bench overhead form=padded-lower asked=144 refused=90 usec_per_ask=93446 builds_per_ask=49.00
bench overhead form=both-storeys asked=144 refused=60 usec_per_ask=123303 builds_per_ask=78.60
bench overhead form=both-storeys-gated asked=144 refused=60 usec_per_ask=66816 builds_per_ask=36.75
```

Whole bench, wall clock: 45.4 s.

### after — the shipped tree

```
bench settlements gate=on
bench settlements seed=1234 cells=25 villages=5 sites=a944e9c7013a498a ae91b3d783fc7cea 89f90e2544ea8161 c02678d9477e59b6 35fc8c53dded0549
bench settlements seed=7 cells=25 villages=3 sites=f2056e63ac51ee90 27116ce02d9864e2 7fbd0ca009ac6a41
bench settlements seed=3 cells=25 villages=4 sites=1772f7a319365f0d ea2b3c35308de15c fdc416e9b2e3c157 ab3bf556ea8494b9
bench settlements seed=19 cells=25 villages=3 sites=840a597536d3c79a d388a5ad100db299 69c87495e8bfea17
bench settlements seed=42 cells=25 villages=2 sites=0ae99160bc9eff3e 3bd18b6f3e9f1400
bench settlements seed=101 cells=25 villages=8 sites=192817c88c565f61 2683ac1aa99d42ce 8b97cd57d714b571 1d13a2342e97788e 12b2d5daa3f97869 8bead2f90be62afa 66ed4f86ebb34130 6f4aab387765e79f
bench settlements seeds=6 cells=150 villages=25 warm_usec_per_cell=7282
bench settlements cold cells=54 villages=13 cold_usec_per_cell=6406
bench overhead form=padded-lower asked=144 refused=90 usec_per_ask=5597 builds_per_ask=1.39
bench overhead form=both-storeys asked=144 refused=60 usec_per_ask=3342 builds_per_ask=0.90
bench overhead form=both-storeys-gated asked=144 refused=60 usec_per_ask=3355 builds_per_ask=0.90
```

Whole bench, wall clock: 3.4 s.

The `sites=` fields are `Settlement.digest()` — cell, centre, radius, core
radius, pad height, biome, spawn and shore flags, and every building's tag,
position, yaw and footprint. Diffing the two runs' `sites=` lines is empty: the
same 25 villages, same cells, same positions, same buildings.

Note also what the `both-storeys` row does to the band-level gate that the last
cycle added. Ungated, asking the bound per band first was worth 123.3 → 66.8 ms;
gated, the two rows are 3.34 and 3.36 ms — the same number twice. The per-cell
form subsumes the band-level one, which is now doing nothing but paying for a
second walk of the same cells. It is left in place because it costs 0.02 ms and
still documents the veto's intent; there is no measurable case for either keeping
or removing it.

## The warm path, and the candidate memo it forced

`./run_bench.sh --seed 1234` times two per-position calls: a bare island lookup
(`walkable_island_over`, what the mesher and the terrain query ask per position)
out of a memo a walking observer has already warmed, and a whole `surfaces_at`.

| | before | gate, no candidate memo | after (gate + candidate memo) |
|---|---|---|---|
| one warm island lookup, µs | 23.9 | 149.9 | 25.5 |
| one `surfaces_at`, µs | 1462 | 775 | 657 |

The middle column is a regression the change caused and had to fix. With the gate
in, the cells the scan walks are mostly cells it *never builds*, so they are never
in the island memo, so every scan re-hashed ~98 candidates: cheap against a build
(2.2 ms) and dear against a dictionary lookup. Candidates are now memoised in
their own table (8192 of them, against 512 islands — a candidate is a handful of
floats where an island is two heightfields), which puts the warm lookup back
where it was, within the run-to-run spread. `_cells_around` also takes the island
memo's answer ahead of the bound where it has one, for the same reason: the bound
is a way of not paying for a build, and a build already paid for needs no excuse.

## The headless walks

Seven walks, `./run_headless.sh --seed S --ticks T`, before and after. The full
traces — one line per traced tick, not just the final fingerprint — diff empty
pair for pair.

| walk | before | after | fingerprint |
|---|---|---|---|
| seed 1234, 100 ticks | 7.48 s | 6.45 s | `a6aa8e5776ebfe8c` both |
| seed 7, 100 ticks | 5.71 s | 5.15 s | `c8dbaa726e4d09b3` both |
| seed 3, 100 ticks | 6.36 s | 6.00 s | `3bcda7c1a542c8b9` both |
| seed 19, 100 ticks | 6.55 s | 5.89 s | `447d00523ce42548` both |
| seed 42, 100 ticks | 6.27 s | 5.53 s | `1ba840cdf66ee7af` both |
| seed 101, 100 ticks | 7.20 s | 5.90 s | `2dcaa69eae41b180` both |
| seed 1234, 600 ticks | 28.12 s | 26.92 s | `2c05279879c5b57d` both |

The walk gains least, and the reason is worth stating: what a walking observer's
island streamer does is *load* the islands near it, and an island that is loaded
has to be built. The gate only skips cells that were going to be discarded, and
near an observer a good share of them are not.

## The suite

Both runs are `./run_tests.sh` on this tree, differing only in the gate's default:

```
before:  ungated_suite_secs=539.93   1 of 18 suites failed (1 failed checks of 169814)
after:   final_suite_secs=379.56     all 18 suites passed (169814 checks)
```

9m00s to 6m20s, a 30% cut, over the identical 169,814 checks. The one failed
check in the "before" run is the equality test's own saving guard, described at
the end of this file: with the gate off by default both of its fields are
ungated, so nothing is being compared against anything and the guard says so.

Structure checks, `./run_tests.sh --layers-only`:

```
layer check: OK -- res://sim references nothing in the render layer
asset check: OK -- res://sim names asset tags and no asset
```

## The equality check, and it failing when the bound is wrong

`tests/test_islands.gd._the_cell_gate_never_changes_the_answer` runs two fields
of the same world side by side, alike but for `gate_cells_by_candidate`, over a
15 × 15 grid of positions spanning 500 world units, in four seeds, in all three
bands, comparing `islands_over` and `islands_near` at three distances (0, the
band's streamer load radius, and a village pad's radius) — digest for digest,
island for island:

```
        islands: cell gate matched the ungated scan on 10800 asks, 1889 with an island, building 317 cells against 1984
suite=islands checks=103672 failures=0 msec=67905
```

Loosening the bound wrongly — taking the candidate's reach to be three quarters
of what it is, `apart - reach * 0.75 <= distance`, which lets the gate refuse
cells whose island does reach — makes it fail, and the failures name the missing
islands:

```
suite=islands checks=103666 failures=159 msec=72728
  FAIL the cell gate changed what is within 0.0 of (-250.0, -214.3) of band 0 on seed 11: gated [], ungated ["-3,-3,0:337759f88e10d41f"]
  FAIL the cell gate changed what is within 36.0 of (-250.0, -35.7) of band 0 on seed 11: gated ["-4,-1,0:379ccd9fb7981e39"], ungated ["-4,-1,0:379ccd9fb7981e39", "-3,-1,0:0d94284eafa0d244"]
  FAIL the cell gate changed what is within 0.0 of (-178.6, -35.7) of band 0 on seed 11: gated [], ungated ["-3,-1,0:0d94284eafa0d244"]
```

159 of the 10 800 asks disagree, and the first of them is an island the terrain
query would have reported someone standing on and the gated scan never built.

The other half of the check — that the gate is buying something — is what fires
when the whole suite is run with the gate off, and it is the only thing that
does. Both fields are then ungated, so the two answers still agree on all 10 800
asks and only the saving is missing:

```
        islands: cell gate matched the ungated scan on 10800 asks, 1889 with an island, building 1984 cells against 1984
FAIL  islands        103672 checks, 1 failed
        - the gated scan built 1984 cells against the ungated 1984, which is not the saving the gate is for
```
