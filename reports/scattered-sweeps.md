# The suites that go quiet for half an hour are not sampling the ground

**Verdict: no surviving suite has a scattered ground sweep worth reordering, and
the four suites this item names go quiet for a different reason entirely — each
is waiting on child engines it launched itself.**

This item was written from a true diagnosis (`reports/terrain-lod-silence.md`):
on the adopted ground, a position no query has been near costs far more than a
position beside one already visited, because the settlement layer memoises its
fan-out per 32-unit pad tile and the adopted water field per 192-unit block. The
item's step from there was that the four suites which went quiet for more than
1500 s in the certifying run are paying that price, and that visiting their
sample positions in block order would return the difference.

Both halves of that step are checked here, and both fail.

1. **The quiet stretches are not sweeps.** In all four suites the long gap is
   the suite waiting on two or three *child engines*, each of which builds this
   seed's world from nothing before it can answer. Section 1 reads that off the
   certifying run's own transcript and section 2 times the children.
2. **There is no scattered sweep left to reorder.** Section 3 enumerates every
   place any suite a run enters asks the ground about a position inside a loop —
   212 call sites in 16 suites — and every wide one is already in block order,
   already clustered, or deliberately scattered *as the check itself*.

Nothing was reordered, so nothing about what any suite asserts changed —
`git diff --stat -- tests/` is empty for this item, which is the strongest form
of "the checks before and after are the same ones" there is — and the saving
from this item is **zero seconds**. What that leaves is written down in
section 5, along with the lever that would actually work.

## 1. Where the four suites go quiet, read off the certifying run

`tests/test_suite.gd` prints a progress line at most once every 30 s, and only
when a check completes. So a gap in the transcript is a stretch during which
*no check ran at all*, and the line that ends the gap names the check that ended
it. Read straight out of `reports/adopted-base-full-suite.log`:

| suite | gap | the line before it | the line that ends it | what ran in between |
|---|---|---|---|---|
| scatter | 1177 s → 2915 s = **1738 s** | `a world at rest has dressed only 406 things` | `the scatter report should exit 0` | `tests/test_scatter.gd:875-877`, three `_run_headless` children |
| islands | 2593 s → 4253 s = **1660 s** | `the walk never dropped an island in 126 ticks` | `the island report should exit 0` | `tests/test_islands.gd:1128-1130`, three `_run_headless` children |
| atmosphere | 440 s → 2107 s = **1667 s** | `headless run should exit 0` | `render shell should exit 0` | `tests/test_atmosphere.gd`, render-shell children |
| ui panel | 473 s → 2040 s = **1567 s** | `the headless run printed no asset report` | `the shell printed no world fingerprint` | `tests/test_ui_panel.gd:550-554`, three `_run_shell` children |

The check counts on those progress lines close the argument: scatter goes from
1464 checks to 1467 across 1738 s, and a check completing anywhere inside that
window would have printed its own line. Nothing ran. The suite was blocked in
`OS.execute`.

Two of the four — **atmosphere and ui panel — never ask the ground about a
position inside a loop at all** (section 3). They cannot be paying a
scattered-sampling cost, because they do no sampling.

## 2. What one child engine costs

`tools/quiet_gap_cost.sh` runs the children with the exact argument lists the
suites pass, one at a time, and times each.

Measured on this machine with nothing else running, 2026-09-18
(`reports/scattered-sweeps/subprocess-cost.log`):

| the suite's gap | child | wall |
|---|---|---|
| **test_scatter**, `:875-877` | `--script res://bin/headless_main.gd -- --seed 1234 --ticks 0 --scatter` | 183.1 s |
| | the same command again (the check runs it twice on purpose) | 188.0 s |
| | the same with `--seed 4321` | 157.2 s |
| | **three children** | **528.3 s** |
| **test_ui_panel**, `:550-554` | `--fixed-fps 60 --quit-after 60 -- --seed 5 --no-grass --no-atmosphere` | 217.3 s |
| | the same with `--sheet --scenario encounter` | 190.1 s |
| | the same with `--scenario encounter` | 173.2 s |
| | **three children** | **580.6 s** |

Two things follow.

**The gap is the children.** 528 s of child engine against a 1738 s gap, and
581 s against a 1567 s gap, with the rest of each gap being the parent's own
work either side of them — and with a caveat that pushes the child numbers up
rather than down: these ran with the machine to themselves, while inside a suite
each child starts next to a parent engine already holding several gibibytes. The
measured totals are a floor, not a ceiling.

**Most of the fall is already banked, and not by this item.** The certifying run
measured these gaps at 1738 s and 1567 s; the same children cost 528 s and 581 s
today. That reduction is `W-ground-fresh-position-cost` — a fresh ground
question fell from 19.698 s to 15.806 s and the water contexts it builds from
78.3 to 25.7, and a child engine's whole job is fresh ground questions. It is
not this item, which changed no code at all.

## 3. The enumeration: every suite that asks the ground inside a loop

`tools/ground_sweep_census.py` walks `tests/` rather than spot-checking it. It
is repeatable — `python3 tools/ground_sweep_census.py` prints
`reports/scattered-sweeps/census.txt` — and its rule has four mechanical parts:

1. **What a position query is.** Every function declared under `sim/` or
   `scripts/terrain/` whose first two parameters are a float `x` and a float
   `z`. The set is read off the source at run time (112 of them today), so it
   cannot drift from it.
2. **What a sweep is.** A call to one of those, with two arguments, textually
   inside at least one `for`/`while` in the same function, found by indentation.
3. **What a surviving suite is.** One named in `const SUITES` in
   `bin/test_main.gd` — 70 of the 225 `test_*.gd` files in `tests/`. The rest
   came with the adopted base and no run enters them.
4. **What scattered means.** Consecutive samples more than `BLOCK_WORLD` = 192
   world units apart, so that every sample lands in a block the one before it
   did not touch. Where the stride can be read off the source the census says
   so; where it cannot, the site is marked and was read by hand.

The result: **16 of 70 suites, 212 call sites.** Every one of the 212 is in the
census file; this table gives each suite's *widest* sweep, which is the only one
a reorder could pay for.

| suite | wall (certifying run) | widest sweep | positions | square | step between samples | order matters? | why no reorder |
|---|---|---|---|---|---|---|---|
| islands | 4442 s FAIL | `test_islands.gd:159` | 400 | 900 u | modular, hundreds of u — **scattered** | **yes** | the scattered order *is* the check: it makes the field busy with "a pile of unrelated samples in between" to prove placement does not drift |
| scatter | 3093 s FAIL | `test_scatter.gd:717` via `_square(10)` | 441 chunks of 16 u | 336 u | 16 u, chunk row-major | no | already in block order: a 336-unit square is 2×2 blocks |
| atmosphere | 2337 s FAIL | — | 0 | — | — | — | asks the ground about no position inside any loop |
| ui panel | 2040 s PASS | — | 0 | — | — | — | asks the ground about no position inside any loop |
| water | 1920 s FAIL | `test_water.gd:80` | 3600 | 540 u | 9 u, row-major | no | already in block order |
| island cover | 1727 s PASS | `test_island_cover.gd:306` | one island's props | one island | metres | no | already clustered: every position is inside one island's footprint |
| combat snap | 1622 s FAIL | `test_combat_snap.gd:503` | 49 boards | 1560 u | 260 u — **scattered** | no | 260 u > 192 u, so each board is its own block *in any order*; sorting by block is the identity on this grid |
| combat board | 1017 s FAIL | `test_combat_board.gd:427` | 3 boards | 3 named places | — | no | three positions; each board's cells are one neighbourhood |
| live world | 987 s PASS | `test_live_world.gd:283` | the fight's members | one board | metres | no | already clustered |
| streaming | 902 s FAIL | `test_streaming.gd:238` | points along a path | a walk | metres | no | a walk is the cheap case: consecutive positions share a pad tile |
| enemies | 726 s PASS | `test_enemies.gd:77` | 81 cells | 9×9 cells | one cell, row-major | no | already in block order; the flagged call, `EnemyField.cell_at`, is arithmetic and reads no ground |
| terrain | 485 s PASS | `test_terrain.gd:78` | 400 | a 2000 u line | 5 u along x | no | a line walk is already in block order |
| mountains | 477 s FAIL | `test_mountains.gd:129` | 12769 (113×113) | 336 u | 3 u, row-major | no | already in block order |
| board overlay | 461 s PASS | `test_board_overlay.gd:75` | board cells × cuts | one board | metres | no | already clustered |
| asset tags | 450 s FAIL | `test_asset_tags.gd:524` | ≤ 76 | 912 u | up to 912 u — **scattered** | **yes** | it returns the *first* pair of positions whose foliage differs, and that pair is what the checks after it are about |
| biomes | 429 s FAIL | `test_biomes.gd:152` | 5184 | 1296 u | 18 u, and already walked block by block | no | the check already sweeps in 12×12 blocks on purpose |
| settlements | no verdict in that run | `test_settlements.gd:904` | road points | road polylines | metres | no | a walk along a road |
| ui digits | 204 s PASS | — | 0 | — | — | — | the one site is a false positive of the name filter (`PixelUi.build`), resolved by reading |

## 4. The three checks whose order is the check, left alone

The item's stop condition says a check that depends on the order it visits
positions is left alone and listed with the reason. There are three, and none
was touched:

- **`tests/test_islands.gd:159-168`**, `_placement_is_a_pure_function_of_cell_and_seed`.
  400 positions on a modular stride over a 900-unit square. Its own comment says
  what the order is for: *"A field that has already been asked hundreds of
  unrelated questions — other cells, other bands, positions all over the world —
  still agrees."* Sorting these into block order would make them related
  questions and the check would stop proving what it says it proves.
- **`tests/test_water.gd:70-74`** (and `tests/test_terrain.gd:63-66`, the same
  shape). The probe list is walked forwards, then 400 unrelated samples are
  taken, then the list is walked **backwards** and compared against the forward
  answers. The reversal is the check.
- **`tests/test_asset_tags.gd:524-529`**, `_two_positions_with_different_foliage`,
  and **`tests/test_scatter.gd:131-143`**, `_chunks_of_biome`. Both walk
  outwards ring by ring and **return the first** position (or the first *n*
  chunks) that satisfy a condition, nearest the origin first. Reordering changes
  which positions come back, and those positions are what the checks after them
  are about.

## 5. What this does not buy, stated plainly

- The silence budget is **3600 s of clock** and the worst honest quiet gap ever
  measured is **1735 s** (`test_scatter` in the certifying run). No suite here
  is near the watchdog, and nothing in this item was ever going to protect one
  from it. The item said so itself; it holds.
- The saving from this item is **zero seconds**, because no sweep was reordered.
  That is separate from `W-ground-fresh-position-cost`, which is already landed
  and did buy something measured: a fresh ground question fell from 19.698 s to
  15.806 s, and the water contexts one question builds from 78.3 to 25.7. Every
  number in the table in section 3 is from the certifying run, which predates
  that change; no number in this report is attributed to this item, because this
  item changed no suite.
- What *is* now measured, and was not before, is where the four long silences
  actually go: into child engines. Section 2 gives the number.

## 6. The lever that would work, and why it is not this item

Each of these four suites launches two or three whole engines and waits. Every
child starts from nothing: it re-imports the project, rebuilds this seed's
plans, and streams the world around an observer before it can print the one line
the parent reads. The parent, meanwhile, already holds a built world for the
same seed and sits idle.

That is a real cost and a real silence, and it is not a sweep. Three things
could be done about it, in rising order of how much they change:

1. Nothing (today): the children are how these checks prove that *a second
   process* reaches the same world, which is exactly the claim that cannot be
   made in-process. The cost is the price of the claim.
2. Make the silence legible without making the run shorter: print a line before
   each child is launched. This would not return any wall time and would move a
   gap the watchdog can already afford, so it is not worth doing on its own.
3. Give the children less to do — fewer ticks, a smaller streamed radius, or one
   child answering several questions instead of one child per question. This
   changes what the checks cover and needs its own item and its own argument.

None of the three is "sweep in block order", so none of them belongs here.

## Commands

```
python3 tools/ground_sweep_census.py > reports/scattered-sweeps/census.txt
./tools/quiet_gap_cost.sh reports/scattered-sweeps/subprocess-cost.log
```

Seeds: 1234 and 4321 for the scatter children (`tests/test_scatter.gd:41`,
`:875-877`), 5 for the render shells (`tests/test_ui_panel.gd:40`, `:550-554`).
The certifying run quoted throughout is `reports/adopted-base-full-suite.log`,
produced by `./run_tests.sh` with no suites named.
