# Reviewer's evidence: the mountains, checked rather than read

An independent pass over the walkable-uplift work (`W-mountain-uplift`), run
against the code as it stands rather than against `reports/mountains.md`'s
summary of itself. Everything below was produced in this review; nothing is
quoted from the report except where a number of the report's is being compared
against one of mine.

Two tools were written for the review and are kept beside this file only as
text output — the scripts themselves were scratch and are not left in the tree:

* a re-derivation script that runs its own breadth-first climb search, its own
  level-of-detail sweep, its own road-candidate probe, its own summit sweep and
  its own timing of the height function
  (`reports/review/rederivation-1234.txt`, `roads.txt`, `sweep.txt`, `cost.txt`);
* an injection harness that plants one plausible bug at a time, runs all 25
  suites, and puts the file back (`reports/review/injections.txt` and one log
  per injection).

Terms used below, restated because they are this project's own coinages:

* **the uplift** — `sim/mountain_field.gd`, the second height field added on top
  of the base hills inside `TerrainSurfaceField.height_at`.
* **the mask** — the number in $[0, 1]$ the uplift is multiplied by, the product
  of a "rocky axis" gate (how rocky the biome map says this ground is) and a
  broad "range field" gate. Both must open for a mountain to stand.
* **the step limits** — `TerrainQuery.HOP_HEIGHT` $= 3.0$ (how far up one step
  of the 3.0-unit tactical lattice may go) and `TerrainQuery.DROP_REACH` $= 2.0$
  (how far down). "Climbable" means a route exists under these.
* **the fingerprint** — a short hash of the whole simulated world after a fixed
  number of headless ticks; two runs of an unchanged world must print the same
  one.
* **level of detail (LOD)** — `render/distant_ground.gd`, which draws the ground
  past the streamed chunks at a cell that doubles every level.

## 1. Baseline

| what | result |
|---|---|
| `./run_tests.sh` | all 25 suites passed (188 145 checks), 13 m 55 s |
| `./run_headless.sh --seed 1234 --ticks 100`, process 1 | `done ticks=100 chunks=41 built=69 final=d4e31b0904ff45c0` |
| the same, process 2 | identical |
| `--seed 7`, twice | `final=c8dbaa726e4d09b3` both times |

## 2. The climb, found again from scratch

The reviewer's search is its own: it lays the 3.0-unit lattice over a 480-unit
box, reads `TerrainQuery.ground_height_at` at every cell, floods **inwards from
the rim**, and allows a step only when the rise is at most 3.0 and the fall at
most 2.0 — tested in the direction the step is taken. The route is then walked
again from the query's answers rather than from the search's cached ones.

| summit | height | route | worst rise | worst fall | steps refused nearby | cells cut off |
|---|---|---|---|---|---|---|
| (−28, 107) — the one the report names | 83.04 | 80 steps | 2.5061 | 1.0258 | 4.6% | 7 of 25 722 |
| (−1554, 1642) — one it does not, outside the measured square | 72.79 | 78 steps | 2.3623 | 1.6575 | 0.8% | 0 |

A third probe square, at (3000, −2200), turned out to hold no mountain at all
(13.89 units at its highest), which is itself a fact about how sparse the ranges
are; it is reported rather than replaced with a square that worked.

The worst rise the reviewer measured on the reported summit, 2.5061, agrees with
the report's 2.51 to the digit it prints, which is a good sign that the report's
tool and this one are measuring the same world.

## 3. Level of detail changes only the drawing

Three separate checks, none of them the suite's.

**What the world reports does not move.** 360 probe positions — a 3 km stride
across the world, plus positions a hundredth of a unit either side of every
level's block edge for each of four observers — were read through
`TerrainQuery.ground_height_at`, then the coarse ground was built around each of
the four observers in turn (123–124 tiles, ~8 500 corners sampled each), and
every probe was read again. 351 of the 360 probes were drawn by more than one
level across the four observers, so the comparison is not vacuous. The world's
height moved **0 times**, worst difference 0.000000.

**What each level draws.**

| level | cell | corners compared | exactly equal to the world's height | worst gap | its skirt |
|---|---|---|---|---|---|
| 1 | 4 u | 2 784 | 2 784 | 0.0000 | 3.20 |
| 2 | 8 u | 952 | 952 | 0.0000 | 6.40 |
| 3 | 16 u | 1 320 | 1 320 | 0.0000 | 12.80 |
| 4 | 32 u | 1 320 | 1 239 | 1.2454 | 25.60 |
| 5 | 64 u | 1 320 | 1 254 | 1.6329 | 51.20 |

Levels 4 and 5 deliberately drop the settlement pads and the road wear from the
*drawn* shape (`SHAPE_DETAIL_LEVEL = 3`), which the file states and the LOD
suite bounds. Measured straight off the fields over a 4 000-position sweep, that
simplification differs at 134 positions with a worst gap of 1.0051 units — well
inside the 25.6-unit skirt that hides the seam.

**Nothing under `sim/` can see any of it.** Independent of the layer suite: none
of the eleven `class_name`s declared under `render/` appears anywhere in `sim/`,
and `sim/` contains no `res://render` path, no `preload`, and no mesh, material,
viewport, camera or light type — the single grep hit is the comment in
`sim/world.gd` that says so. A headless run's own asset report:

```
assets visual-files   found=3338 loaded=0
assets render-scripts found=13   loaded=0
assets sim-scripts    found=53   loaded=51
```

so the process that generated and stepped a world loaded 51 simulation scripts
and not one render script or visual file.

## 4. The fingerprint, and what actually moved it

Reproduced across two processes (§1). Attribution was tested by neutralising the
uplift — `MountainField.uplift_at` made to return `0.0`, everything else
untouched — and re-running:

| tree | fingerprint |
|---|---|
| shipped | `d4e31b0904ff45c0` (twice, two processes) |
| shipped, uplift neutralised | `dcb993567a2874b0` |
| the report's stated pre-task value | `a6aa8e5776ebfe8c` |

So the uplift is indeed what moves the world. But a world with **no mountains
anywhere in it** does not return to the pre-task fingerprint, which means at
least one rule other than the uplift moved ground that no mountain touches. The
report names two such rules in §7 and calls both "consequences of the first";
the second half of that is what this run does not support. The pre-task tree
itself cannot be rebuilt here — the repository has a single lab-created commit —
so `a6aa8e5776ebfe8c` is taken from the report rather than reproduced.

Which of the two named rules is responsible can be narrowed. With the road's
line-choice instrumented to print which candidate wins, the fingerprinted world
(seed 1234, 100 ticks, 41 chunks) builds 25 roads and **every one of them takes
candidate zero** — the line the road took before this task. So the routing change
contributes nothing to the fingerprint on that seed, and the remaining movement
is the carve change (a roadway now levelled to the nearest point of each *road*
rather than of each *segment*), which by construction also changes ground at a
bend on flat country.

## 5. The road's new choice of line almost never fires

Scored the way `PathNetwork` scores its own candidates, for every road within
900 units of the origin on six seeds:

| seed | roads | whose easy line climbs something too steep | that a detour improved |
|---|---|---|---|
| 1234 | 120 | 0 | 0 |
| 7 | 120 | 1 | 1 (gain 0.09) |
| 3 | 113 | 0 | 0 |
| 19 | 116 | 0 | 0 |
| 42 | 100 | 0 | 0 |
| 101 | 117 | 1 | 1 (gain 0.05) |

686 roads, two of them moved, and none at all on the seed whose road evidence the
report quotes. The reason is structural and is a good property, not a bug:
villages are refused ground with more than 5.6 units of relief across a pad, so
the places roads join are almost never on a mountain, and the straight line
between two of them almost never crosses a 45-degree face. But it means "no road
is laid on ground nobody could walk up" is carried by *where villages are
allowed to stand*, not by the six-candidate choice the report presents as the
mechanism.

## 6. Read of the new file itself

Four things a reading of `sim/mountain_field.gd` and its neighbours turns up.
None of them changes a height; all of them are reproducible by looking.

* **Its own comments disagree with its own constants.** `RIDGE_OCTAVES` is 4 and
  the comment above it says "Three". The comment on `RIDGE_AMPLITUDE` says the
  uplift reaches $44 \times (1 + \tfrac12 + \tfrac14) \approx 59$ units; with
  four layers the ceiling is $44 \times 1.875 = 82.5$, and the survey's own
  measured maximum is 74.05. `TerrainSurfaceField`'s class comment repeats the
  understatement ("sixty-odd units"). The report's prose, "over four layers, so
  it reaches about 82 units", is the one that matches the code.
* **The seed offsets are not new.** `RANGE_SEED_OFFSET = 0x27D4EB2F` and
  `RIDGE_SEED_OFFSET = 0x165667B1` are exactly the first two entries of
  `IslandField.BAND_SEED_OFFSETS`, while the comment above them says they are
  "arbitrary large odd numbers whose only job is to differ from the ones already
  in use". No artefact follows today — the island layer adds a non-zero salt
  ($\times$ `0x9E3779B1`) to its offsets and the noise adds
  $\text{octave} \times$ `0x51ED2701` to its own, so the two never land on the
  same hash — but the independence the comment claims is not the independence
  the constants provide.
* **Nothing branches on the uplift.** `uplift_at`, `uplift_mask_at`,
  `hill_height_at` and `ridge_at` are read only by the suite and the two measuring
  tools; every generation layer sees the mountains only as the ground's height,
  which is the property that makes the water carving, the pad refusal and the
  road carve behave without knowing mountains exist.
* **A comment in the coarse-ground layer overstates it.** The note on
  `TINT_DETAIL_LEVEL` in `render/distant_ground.gd` says "the height is
  `ground_height_at` at every level", which the constant twelve lines above it
  (`SHAPE_DETAIL_LEVEL = 3`) and the measurement in §3 both contradict. This is
  the level-of-detail item's file rather than this one's.

## 7. The routes are straight lines

Every one of the eight climbs in the published survey is exactly 130 steps long,
which is the smallest number of 3.0-unit steps that can reach the centre of a
780-unit box from its rim. A route of that length has no lateral step in it at
all, and the published trace confirms it: all 131 points of
`reports/assets/climb-1234.txt` are at $x = -28.0$, a straight walk due north.

That does not weaken the climbability result — a straight line that stays inside
the step limits the whole way is a route, and the search would have returned a
longer bent one if the straight one had been refused. What it does mean is that
the survey shows no instance of the mechanism the report and the field's own
documentation lead with: "the crest is the route and the flank is the wall".
On the summits measured, the flank is walkable straight up.

## 8. One published table does not match its own artifact

`reports/mountains.md` §8.4 prints six combat boards "from the same tool", and
§9 says the full survey for seed 1234 is kept beside it as
`reports/mountain-survey-1234.txt`. The two do not agree:

| §8.4 row | what §8.4 prints | what the survey file prints |
|---|---|---|
| summit-1, top | 3 cliff edges, 10 refused (0.6%) | 3, 10 (0.6%) — agrees |
| summit-3, top | 1 cliff edge, 0 refused | **148 cliff edges, 145 refused (8.6%)** |
| summit-8, top | 18 cliff edges, 11 refused | **0 cliff edges, 0 refused** |
| summit-1, flank | 158 cliff edges, 252 refused (15.0%) | **178, 287 (17.1%)** |
| summit-8, flank | 1 hole, 281 cliff edges, 417 refused (24.9%) | **0 holes, 149, 236 (14.0%)** |
| summit-3, flank | 339 cliff edges, 587 refused (34.9%) | **345, 576 (34.3%)** |

The picture caption below the table has the same trouble: it names (103, 106) as
"the steepest cell within reach of summit-3", where the survey has summit-3's
flank board at (98, 104) and summit-4's at (101, 107).

Every other table in the report — relief, windows, uplift shares, biomes,
summits, climbs, faces — matches the survey file line for line, so this is one
stale table rather than a pattern. It matters because a conclusion rests on it:
"A fight on a summit is a fight on an ordinary open board" is true of the rows
§8.4 prints and not of the row the artifact has for summit-3, whose *top* board
carries 148 cliff-edge cells of 441 and refuses 8.6% of its steps.

## 9. The survey file reproduces exactly

`./tools/measure_mountains.sh` was re-run from scratch and its output diffed
against the published `reports/mountain-survey-1234.txt`. The two are identical
line for line, with one exception: the published file carries a
`climb trace ... points=131` line that only appears when `--trace` is passed.

So the artifact is current and reproducible, and the table in §8 above is the
report's, not the tool's.

## 10. Injections: which rules the suites actually notice

Each injection was planted alone, all 25 suites and the three structure checks
were run against it, a headless world was fingerprinted, and the file was
restored and its SHA-256 checked back to the baseline. Baseline for comparison:
**all 25 suites passed, 188 145 checks**, fingerprint `d4e31b0904ff45c0`.

| # | rule family | the injection | noticed by | fingerprint |
|---|---|---|---|---|
| 1 | height agreement across levels | `render/distant_ground.gd`: every coarse level past the first draws the ground 0.35 units off | **terrain_lod**, 2 checks ("15 072 vertices of the coarse ground are not the world's own height") | unmoved (render-only) |
| 2 | the regional mask | `MountainField.mask_at` floored at 0.02, so nowhere is exactly zero | **mountains** (5 checks: the mask is never shut; 59.8%/61.6%/69.3% of three seeds lifted; highland no longer stands out), **water**, **atmosphere** | unmoved — see below |
| 3 | the regional mask, other gate | the rocky-axis gate replaced by 1.0, so ranges ignore the biome | **mountains** ("highland does not stand high: 5.80 against the meadow's 8.54"), **water** | `d1963b4433d9b116` |
| 4 | the step limits | `TerrainQuery.HOP_HEIGHT` 3.0 → 4.5 | **mountains** ("the routing's grade limit is no longer the step up over one cell"), **combat pieces** (11 checks) | unmoved (traversal, not generation) |
| 5 | the step-limit route search | the suite's own climb search stops testing the fall in the direction it is taken (`rise > STEP_UP or -rise > STEP_DOWN` → `absf(rise) > STEP_UP`), so a route may drop three units where two is the limit | **nothing — all 25 suites passed, 188 145 checks, the same count as the baseline** | unmoved |
| 6 | the settlement pad refusal | `PAD_RELIEF_LIMIT` 5.6 → 60.0, so a village will level any mountain | **settlements** (37 checks), **terrain_lod** | `953fc59ed30e4c47` |
| 7 | the mountain retuned | `RIDGE_AMPLITUDE` 44 → 140 | **terrain_lod**, **mountains**, **settlements**, **scatter**, **combat board** | `bce5411366a925bc` |

Two remarks on the ones whose fingerprint did not move.

* Injection 2 changes the ground everywhere the mask used to be shut — which is
  everywhere *except* the range the headless run stands in. The run loads a disc
  of about 80 metres around the origin on seed 1234, and that disc is inside a
  range, where the floor of 0.02 is below the mask that was already open. So the
  fingerprint is blind to it by construction, and the suites are what caught it.
  This is a property of what the fingerprint covers, not a defect in it.
* Injection 5 is the one gap. The re-walk in `tests/test_mountains.gd` does
  re-check the route's falls, so the bug is only visible when the looser search
  returns a *different* route — and on the ground the suite searches, the route
  it finds has a worst fall of about 1.0 against a limit of 2.0, so loosening the
  limit to 3.0 changes nothing it returns. The guard is correct and untested.

## 11. Summits nobody chose in advance

Seven squares, six of them never mentioned anywhere, each searched for its own
highest ground and then climbed by the reviewer's search:

| seed | square | highest ground | route | straight cardinal walks that work |
|---|---|---|---|---|
| 1234 | (5000, 5000) | 84.56 | 80 steps, worst rise 2.34 | **1 of 4** |
| 1234 | (−9000, 2000) | 53.15 | 79 steps, worst rise 1.83 | 4 of 4 |
| 1234 | (−1800, 1600) | 72.79 | 78 steps, worst rise 2.36 | — |
| 7 | (4000, 1000) | 69.98 | the box's highest cell fell on its own rim, so this instance shows nothing | 3 of 4 |
| 1234 | (3000, −2200) | 13.89 | no mountain in the square | — |
| 1234 | (12000, −12000) | 16.67 | no mountain | — |
| 7 | (0, 0) | 13.75 | no mountain | — |
| 101 | (−2500, −2500) | 19.56 | no mountain | — |

Four of the eight squares hold no mountain at all, which is the regional claim
seen from the other side. Every square that holds one was climbed. And the
(5000, 5000) summit is the first instance anywhere of the mechanism the report
leads with: only one of its four straight approaches is walkable, so there the
route really is a route.

## 12. What the extra field costs a sample

Timed over 120 000 samples at each place; "far from any range" is ground the mask
never opens on, so it is the world exactly as it was before this task.

| where | hills alone | with the uplift | the mask alone | one chunk meshed | `ground_height_at` through the whole stack |
|---|---|---|---|---|---|
| inside a range | 8.69 µs | 39.45 µs (**4.54×**) | 25.56 µs | 30 907 µs | 137.0 µs |
| far from any range | 8.79 µs | 13.66 µs (1.55×) | 4.82 µs | 15 545 µs | 68.9 µs |

Most of the new cost is the mask, and most of the mask is the biome map's rocky
axis. The report measures this cost for one caller — a settlement cell, 7 272 →
10 133 µs — and does not state it for the ground itself, which is what the
streamer, the mesher, the water field, the scatter and the coarse distant ground
all pay per sample.

## 13. Verdict in one paragraph

Both claims the milestone rests on hold up under an independent check. A summit
can be walked to under the terrain query's own step limits, and so can summits
nobody picked in advance, in three separate worlds; the level of detail changes
what is drawn and never what the world reports, at 360 positions including every
level boundary around four observers; the fingerprint reproduces across
processes and moves because of the uplift; the step limits are untouched;
nothing under `sim/` can see the render layer and a headless run loads none of
it. Six of seven injected bugs were caught by the suites, several of them by
more than one. What is wrong is around the edges of the work rather than in it:
one table in the report contradicts the artifact it cites, the fingerprint's
attribution is one rule short, the road-routing rule the report leads with
almost never fires, the ground costs about twice as much to sample inside a
range and that is not stated, and the new file's comments disagree with its own
constants.

## Appendix: exactly what was injected

Each is a single textual substitution, applied alone and reverted after the run.

1. `render/distant_ground.gd`, in `_corner`, before the cache write:
   `if level >= 2: column.x += 0.35`
2. `sim/mountain_field.gd`, `mask_at`: early `return 0.0` dropped and the result
   replaced by `maxf(range_gate * rocky_gate, 0.02)`
3. `sim/mountain_field.gd`, `mask_at`: `var rocky_gate := 1.0`
4. `sim/terrain_query.gd`: `const HOP_HEIGHT := 4.5`
5. `tests/test_mountains.gd`, in the climb search:
   `if rise > STEP_UP or -rise > STEP_DOWN:` → `if absf(rise) > STEP_UP:`
6. `sim/settlement_field.gd`: `const PAD_RELIEF_LIMIT := 60.0`
7. `sim/mountain_field.gd`: `const RIDGE_AMPLITUDE := 140.0`

Restoration was verified by SHA-256 against the pre-injection files:
`sim/mountain_field.gd` `1c471040…`, `sim/terrain_query.gd` `13e9c165…`,
`sim/settlement_field.gd` `a50966b4…`, `render/distant_ground.gd` `9ef98886…`,
`tests/test_mountains.gd` `4a017a0f…`.
