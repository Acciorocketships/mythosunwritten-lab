# Nineteen seconds to ask the ground one question at a new place

What it costs to ask `TerrainQuery.ground_height_at` about a position nothing
has been near, where that cost actually goes, and what a bound read off the
village placement rule takes off it.

All numbers are seed 1234 on this machine, one engine at a time.

## 1. Where the water builds went, before anything was changed

The adopted ground answers through 192-unit blocks
(`scripts/terrain/field/WorldFieldBlockCache.gd`). Each block has two halves: a
heightfield region, which is cheap, and a **water context** -- the hydrostatic
fill for that block -- which costs about a second and is effectively the whole
bill. `tools/ground_block_cost.gd` already counted how many a fresh position
builds. It did not say who asked.

`tools/ground_build_callers.gd` (new) walks `TerrainQuery.water_column_at`'s own
composition by hand, reading the cache's build counters between steps, so every
water context is attributed to the call site that caused it. Each position gets
its own cold stack, so the counts are that position's own.

**Before the change**, three fresh positions from the sweep
`tools/ground_scatter_cost.gd` times (`reports/ground-build-callers.log`):

| caller | (-1023, -139) | (-46, 1722) | (931, -417) |
| --- | ---: | ---: | ---: |
| `sim/terrain_query.gd:136` the query's own patch | 1 | 1 | 1 |
| `sim/terrain_query.gd:139` settlement layer | 11 | 19 | 12 |
| `sim/terrain_query.gd:140` road layer | 49 | 70 | 71 |
| `sim/terrain_query.gd:143` aerial layer | 0 | 0 | 0 |
| **whole position** | **61** | **90** | **84** |

This corrects the premise this item was written on. The settlement layer is real
but it is the smaller half: **the road layer is two thirds to five sixths of the
bill**, and nearly all of that is one line --
`sim/path_network.gd:818`, `_build_tile` calling `places_near`, which swept a
five-by-five square of 260-unit settlement cells and sited a village in every
one of them to find the one or two places a road could come from. The rest is
`sim/path_network.gd:820`, `edges_from`, routing those places together.

Inside the settlement layer the shape was as the item described:
`sim/settlement_field.gd:504`, `_build_pad_tile`, sweeping a three-by-three
square of cells on a 32-unit pad-tile miss, each cell paying `_build_inland`'s
pad scans and `_build_shore`'s grid over the whole cell.

## 2. What was changed

Two exact refusals. Neither is approximate, and neither reads any ground.

**A bound on where a village can stand** (`sim/settlement_field.gd`). An
ordinary cell jitters every candidate into the middle half of itself
(`JITTER_LOW`..`JITTER_HIGH`), and the shore rule drops any bearing that leaves
that same band, so no village of such a cell stands further than a quarter of a
cell -- 65 units -- from its middle on either axis. The cell holding the world
origin is the one exception: its village is placed on a ring around the origin,
so its bound is that ring's outer radius. `centre_reach()` states that bound and
`cell_could_reach()` asks whether any village a cell could hold can come within
a given distance of a position. A "no" is a proof, so the cell is skipped; a
"maybe" leaves the cell built and tested exactly as before. It is used by
`settlements_near()` and by `_build_pad_tile()`.

**The road layer asking for what it keeps** (`sim/path_network.gd:195`). A
*place* is a village's centre, and `places_near()` drops every village whose
centre is further than `reach`. It was asking the lattice for villages within
`reach` plus the widest anything a village owns, which returns the same places
after that line and costs a wider ring of cells to find them: twenty-five cells
against nine.

Nothing about where villages stand, how many there are, or how they are laid out
is touched. `SettlementField.site_reach()` had one caller and lost it, so it
went with it.

## 3. What it costs now

**Attribution, same three positions** (`reports/ground-build-callers-after.log`):

| caller | (-1023, -139) | (-46, 1722) | (931, -417) |
| --- | ---: | ---: | ---: |
| the query's own patch | 1 | 1 | 1 |
| settlement layer | 11 → **0** | 19 → **8** | 12 → **2** |
| road layer | 49 → **14** | 70 → **25** | 71 → **25** |
| **whole position** | 61 → **15** | 90 → **34** | 84 → **28** |

Mean 78.3 → 25.7 water contexts, a threefold cut. The settlement layer's share
has gone from a quarter of the bill to a twelfth of it.

**Water builds and seconds per fresh position**, `tools/ground_block_cost.gd`,
six positions on a circle at each distance band
(`reports/ground-block-cost-before-rerun.log`, `reports/ground-block-cost-after.log`):

| band | s/position before | s/position after | water builds/position before | after |
| --- | ---: | ---: | ---: | ---: |
| 96 units out | 14.01 | **10.49** | 18.8 | **7.7** |
| 950 units out | 26.38 | **14.92** | 27.3 | **17.5** |
| 2000 units out | 36.06 | **18.74** | 32.2 | **14.0** |
| all three bands | 25.49 | **14.71** | 26.1 | **13.1** |
| peak resident memory | 8.54 GiB | **7.81 GiB** | | |

**The sweep the item names**, `tools/ground_scatter_cost.gd --seed 1234 --span
2000 --count 900 --sample 60` (`reports/ground-scatter-cost-before-rerun.log`,
`reports/ground-scatter-cost-after.log`):

| | recorded before | before, rerun this session | after |
| --- | ---: | ---: | ---: |
| a first visit (scattered order) | 19.489 s | 19.698 s | **15.806 s** |
| the worst single position | 115.07 s | 116.10 s | **60.77 s** |
| a second visit (block order) | 2.404 s | 2.433 s | **2.429 s** |
| peak resident memory | not recorded | 9.80 GiB | **9.40 GiB** |

**A second visit did not get slower**: 2.433 s before against 2.429 s after,
inside the noise of the two runs. **Peak resident memory fell** on both tools --
7.81 GiB against 8.54 GiB, 9.40 GiB against 9.80 GiB -- so nothing here was
bought with memory.

## 4. The target, and the measured refusal

The item asked for a fresh position costing about what the query's own water
contexts cost, roughly 5 s against 19.49 s. **That was not reached, and the
measurement says why.** The query's own patch is *one* water context, not two or
three; a fresh position now costs 15.81 s on the scattered sweep and 14.71 s
averaged over the three bands, against seven to eighteen water contexts. The
settlement layer is no longer the lever -- it is down to nought, two and eight
contexts on the three positions opened up.

What is left is the road layer, and it is not fan-out that can be ruled out on
arithmetic. To know whether a road runs over a position you have to know the
road graph around it, and to know that you have to site every village and
landmark within the link radius and *route* between them -- and routing samples
the ground along each candidate line for up to a hundred and seventy units.
`edges_from` was 14, 14 and 16 contexts of the three positions' remaining
15, 34 and 28.

So the measured floor of a fresh position on the adopted ground, as the stack
stands, is **seven to eighteen water contexts, ten to nineteen seconds**, and
the next lever is the road layer's own width rather than anything in the
settlement lattice. Making the water context itself cheaper reaches into the
adopted base's field code and is its own item.

## 5. The world did not move

* **A sweep of positions is byte-identical.** `tools/ground_world_dump.gd`
  (new) writes, at full float precision and in a fixed order: every village in
  the 49 cells from (-3,-3) to (3,3) with its centre, radius, core, levelled
  height, biome, spawn and shore flags, and every building, prop and lit window
  standing in it; then a 41x41 grid at 24-unit steps over a 960-unit square, and
  twelve positions of the scattered sweep, each with carved height, water
  surface, wetness, bankness, uncarved height, biome, road strength, road
  distance and which village covers it. 2842 lines.

  ```
  godot4 --headless --path . -s res://tools/ground_world_dump.gd -- --seed 1234
  cmp reports/ground-world-dump-before.txt reports/ground-world-dump-after.txt
  ```

  Identical: `sha256 5a2491c317567d61815c9a7394fa257bfc4a5d4931f887451d75d86c2481b6f1`
  both sides.

* **The headless digest is unchanged.**
  `./run_headless.sh --seed 1234 --ticks 100 --digest` prints
  `digest=febc847c5c2a4e12` with the change and `digest=febc847c5c2a4e12`
  without it (the change stashed, HEAD at fedd923b) --
  `reports/ground-fresh-position-digest.log` and
  `reports/ground-fresh-position-digest-baseline.log`.

  The value this item expected, `37b4398871269849`, is **stale at HEAD**: the
  unchanged tree prints `febc847c5c2a4e12` too. It is recorded nowhere in the
  repo, and the last commit to touch `sim/` was e0303a1e, so the drift is older
  than this work. What this item can show, and does, is that the digest is the
  same on both sides of its own change.

* **The refusals are exact rather than approximate.** `centre_reach()` is an
  upper bound read off the placement rule itself, not a measurement of where
  villages happen to be, so a cell it rules out provably holds no village within
  the distance asked about. The `places_near` change returns the same set
  because the line after it already dropped everything the wider ask added.

## 6. The suites

Nothing under `tests/` changed in this item. Seven suites read the settlement
or road layer; every one of them reaches a verdict, and every verdict is
**identical check for check** to what it was before.

```
./run_tests.sh test_mountains test_drops test_terrain test_window_glow \
    test_islands test_settlements test_scatter
./run_tests.sh test_settlements                  # re-run alone, see below
./run_tests.sh test_window_glow                  # on HEAD, change stashed
```

| suite | with the change | before |
| --- | --- | --- |
| `test_mountains` | FAIL mountains 248.4 s, 13 checks, 5 failed | FAIL mountains 445.6 s, 13 checks, 5 failed |
| `test_drops` | FAIL drops 208.2 s, 65 checks, 1 failed | PASS drops 288.6 s, 65 checks |
| `test_terrain` | PASS terrain 0.9 s, 53 checks | -- |
| `test_window_glow` | FAIL window glow 2274.5 s, 20651 checks, 1 failed | FAIL window glow 2271.7 s, 20651 checks, 1 failed |
| `test_islands` | FAIL islands 1751.3 s, 60185 checks, 10 failed | FAIL islands 2468.6 s, 60185 checks, 10 failed |
| `test_settlements` | FAIL settlements 3330.8 s, 30734 checks, 99 failed | FAIL settlements 4208.2 s, 30734 checks, 99 failed |
| `test_scatter` | FAIL scatter 1528.4 s, 1478 checks, 2 failed | FAIL scatter 3092.8 s, 1478 checks, 2 failed |

Where the "before" column comes from: `test_mountains`, `test_drops` and
`test_islands` from `reports/ground-rebuild-suites.log`; `test_scatter` from
the certifying run `reports/adopted-base-full-suite.log`; `test_settlements`
from the reading recorded against the preceding commit fedd923b;
`test_window_glow` from a run of this cycle on HEAD with the change stashed
(`reports/ground-fresh-position-window-glow-baseline.log`), because that suite
had never reached a verdict on the adopted base -- the certifying run recorded
`test_window_glow stalled: printed nothing for 1800s`. It reaches one now, and
it is the same verdict with and without this change, down to the message:
`only 4 lit windows on any workshop in the whole sample`, and the same village
tally either way (`123 villages light [house=1100, cottage=1033, tavern=244,
workshop=4, tower=36]`).

`test_drops` is the one suite whose verdict moved, and it did not move here.
Its single failing check is
`the same scan does find world generation where world generation lives`
(`tests/test_drops.gd:499`), which asserts that `sim/world.gd` names
`TerrainStreamer`. The render seam deleted `sim/terrain_streamer.gd` at
bc994710, so the check cannot pass on any tree since, and the PASS it is held
against predates that commit.

**Every suite got faster, and every peak got smaller.**

| suite | wall time before → after | peak resident before → after |
| --- | --- | --- |
| `test_mountains` | 445.6 s → **248.4 s** | |
| `test_islands` | 2468.6 s → **1751.3 s** | 19.28 GiB → **17.46 GiB** |
| `test_settlements` | 4208.2 s → **3330.8 s** | 22.20 GiB → **20.54 GiB** |
| `test_scatter` | 3092.8 s → **1528.4 s** | 25.46 GiB → **17.92 GiB** |

`test_settlements`' longest silent stretch -- the thing that started this line
of work -- fell from **1971 s to 320 s**.

One thing to state rather than hide: in the seven-suite batch,
`test_settlements`' engine was killed (exit 137) before it returned, at a
sampled peak of 18.82 GiB. Its recorded reading was taken from a run of that
suite alone, so it was re-run alone, with nothing else on the machine, and
reached its verdict there. This machine has 27.4 GiB and this suite has always
run within a couple of gigabytes of it; the batch is not how it was measured
before and is not how it is measured here.

## 7. The bound, checked against the villages themselves

The skip added in section 2 is only exact if `centre_reach()` is really a bound,
so it is checked against the world rather than only argued from the placement
rule. `tools/centre_reach_check.py` (new) reads the numbers out of
`sim/settlement_field.gd` -- so nothing is copied here to drift -- and measures
every village in a dump against the bound its own cell states. It needs no
engine.

```
python3 tools/centre_reach_check.py reports/ground-world-dump-before.txt
python3 tools/centre_reach_check.py reports/ground-world-dump-after.txt
```

Both sides, `reports/ground-centre-reach-check.log`:

```
bound: 65.0 units for an ordinary cell, 104.0 for the cell holding the origin
villages checked: 19
worst offset, as a share of its own cell's bound: 0.9841
OK every village stands inside the bound its cell states
```

Nineteen villages stand in the 49 cells the dump covers and not one is outside
the bound, while the furthest stands at 98.4% of it. So the bound is a bound,
and it is tight enough that there is nothing left in it to give back: widening
it would buy no cells and narrowing it would start dropping villages.

The three places the bound is read off the code are each checked by hand as
well: the inland candidate is jittered into `JITTER_LOW`..`JITTER_HIGH` of its
cell (`sim/settlement_field.gd:915`), the shore candidate is dropped unless it
lands in that same band (`:758`, `_inside_jitter_band` at `:801`), and the spawn
cell's candidate is placed on the ring at `SPAWN_RING_MIN`..`SPAWN_RING_MAX`
around the origin, which is that cell's own middle (`:909`). Those are the only
three ways a village centre is ever set.

The `places_near` change has the same kind of check behind it:
`Settlement.distance_to` (`sim/settlement.gd:101`) returns
`max(0, |centre - position| - radius)`, which is never more than the distance to
the centre, so every village whose centre is within `reach` is still returned
when the lattice is asked for `reach` itself -- which is exactly the set the
line after it keeps.
