# The sim layer's suites on the adopted ground

This file answers the one acceptance line of `W-adopt-terrain-seam` that was
still open: *the sim-layer suites still pass, or every changed expectation is
justified suite by suite; the old flat-terrain source is removed or kept behind
a named switch with the reason recorded.* The other five lines were recorded met
at cycle 3726 with their own quoted runs and are not revisited here.

The line has two halves and they are answered differently. The first half — what
the suites say — is read off transcripts that already exist, because a full run
of this project's suite costs sixteen hours and the run that certified the
adopted base is the record of it. Reading it suite by suite turned up one red
that is this seam's own rather than somebody else's, and §7 is that red: what it
was, how it was measured, and the change that made it green. The second half — what became of the old
flat-terrain source — is no longer a choice: the user's no-adapter directive
(`I-1e5f2bcd2729`) settled it, `W-ground-rebuild` carried it out, and here it is
read off the tree and quoted.

## 1. Which suites are the sim layer, and where each verdict comes from

Fifty-seven of this project's seventy-three suites are the sim layer: everything
from `test_rng` to `test_fight_cooloff` in the order `bin/test_main.gd` runs
them. The remaining sixteen — `test_window_glow` through `test_panel_sentences`
— draw things on a screen and belong to `W-adopt-render-seam`.

Three transcripts carry the verdicts, and every line quoted below is copied from
one of them:

| Transcript | What it is | Suites |
| --- | --- | --- |
| `reports/adopted-base-full-suite.log` | the certifying run: one `./run_tests.sh` over all 73 suites, 16.1 h, commit `221b74af`, job `adopt-full-suite-3866` | all 57 |
| `reports/ground-rebuild-suites.log` (+ `reports/ground-rebuild-terrain-recheck.log`) | `W-ground-rebuild`'s sweep on the rebuilt ground, 6.6 h, commit `03f2202e` | 13 of the 57 |
| `reports/terrain-seam-simlayer.log` | this run, seven suites the sweep did not name, on today's tree | 7 of the 57 |
| `reports/terrain-seam-landing.log` | this run, after the change of §7: the two suites that walk an ordinary world, and four already measured an hour earlier as the regression check | 6 of the 57 |

## 2. Why a verdict taken before the ground rebuild is a verdict on today's ground

The certifying run predates the rebuild, so the question has to be asked: is
what it printed still true of the tree as it stands? For the sim layer the answer
is yes, and it rests on three links rather than on optimism.

**The tree did not move between the certifying run and the rebuild.** The run was
made at commit `221b74af`; the last commit before the rebuild is `29fd00ac`. In
between, nothing under `sim/` or `bin/` changed at all:

    $ git diff --name-only 221b74af 29fd00ac -- sim bin
    (nothing)

and `tests/` gained only two runner fixtures.

**The rebuild moved no answer.** `W-ground-rebuild` measured this rather than
assuming it: `tools/terrain_seam_probe.gd` prints every combat cell's elevation,
support, hole, water, depth, bank, biome and passability for a 576-cell window,
and its output is byte-identical on both sides of the rebuild — `diff` over the
full 576 lines is empty, not merely the digests (reports/ground-rebuild.md §5):

| Window | Before (`29fd00ac`) | After (`03f2202e`) | Differing lines |
| --- | --- | --- | --- |
| origin `(0, 0)` | `163a7495018510db` | `163a7495018510db` | 0 |
| lakeside `(84.5, 294)` | `10c837b2c5152091` | `10c837b2c5152091` | 0 |

The world fingerprint is the same on both sides too: `./run_headless.sh --seed
1234 --ticks 3` prints `done ticks=3 chunks=32 built=32 final=fbc08ae26a275337`
before the rebuild and after it.

**Every sim-layer suite whose own file changed was re-run.** Nine sim-layer test
files have changed since the certifying run — `test_biomes`, `test_drops`,
`test_island_cover`, `test_islands`, `test_mountains`, `test_settlements`,
`test_terrain`, `test_terrain_lod`, `test_water` — and all nine are in the
rebuild's sweep. No suite carries a verdict from a run of a different file.

And where the two runs overlap they agree, which is the check on the argument
rather than the argument itself: `test_water` 7 of 5320 both times, `test_streaming`
2 of 4661 both times, `test_combat_board` 2 of 23362 both times, `test_determinism`,
`test_drops` and `test_layering` green both times. This run adds two more:
`test_fight_driver` 4 of 51 both times, `test_walk_in_fight` 3 of 54 both times.
The only suites that moved are the four the rebuild changed on purpose, and §5
says why each one moved.

## 3. The fifty-seven suites, every verdict quoted

Column three is the certifying run. Column four is the later verdict where one
exists — the rebuild's sweep, its `test_terrain` re-run, or this run — and an
em dash where the certifying run is the whole record.

| # | Suite | Certifying run (`221b74af`) | On the rebuilt ground |
| --- | --- | --- | --- |
| 1 | `test_rng` | `PASS  rng               0.0 s, 1325 checks` | — |
| 2 | `test_determinism` | `PASS  determinism     833.9 s, 15 checks` | `PASS  determinism     836.9 s, 15 checks` |
| 3 | `test_terrain` | `PASS  terrain         485.1 s, 32 checks` | `PASS  terrain         491.8 s, 72 checks` |
| 4 | `test_streaming` | `FAIL  streaming       902.3 s, 4661 checks, 2 failed` | `PASS  streaming       959.7 s, 4679 checks` — **fixed in this item**, §7 |
| 5 | `test_terrain_lod` | `FAIL  test_terrain_lod stalled: printed nothing for 1800s` | `FAIL  test_terrain_lod stalled: printed nothing for 3600s, budget 3600s` |
| 6 | `test_mountains` | `FAIL  mountains       477.4 s, 3030 checks, 6 failed` | `FAIL  mountains       445.6 s, 13 checks, 5 failed` |
| 7 | `test_biomes` | `FAIL  biomes          429.1 s, 212 checks, 1 failed` | `PASS  biomes          439.7 s, 212 checks` |
| 8 | `test_water` | `FAIL  water          1920.4 s, 5320 checks, 7 failed` | `FAIL  water          1971.8 s, 5320 checks, 7 failed` |
| 9 | `test_islands` | `FAIL  islands        4441.6 s, 105160 checks, 32 failed` | `FAIL  islands        2468.6 s, 60185 checks, 10 failed` |
| 10 | `test_island_cover` | `PASS  island cover   1726.9 s, 4922 checks` | `FAIL  island cover   1042.9 s, 1245 checks, 3 failed` |
| 11 | `test_settlements` | `FAIL  test_settlements: the engine died (exit 137) before the suite returned` | `FAIL  test_settlements: the engine died (exit 137) before the suite returned` |
| 12 | `test_scatter` | `FAIL  scatter        3092.8 s, 1478 checks, 2 failed` | `FAIL  scatter        1398.8 s, 1478 checks, 2 failed` |
| 13 | `test_combat_board` | `FAIL  combat board   1016.7 s, 23362 checks, 2 failed` | `FAIL  combat board    441.0 s, 23362 checks, 2 failed` |
| 14 | `test_combat_pieces` | `PASS  combat pieces   185.4 s, 314 checks` | — |
| 15 | `test_combat_resolution` | `PASS  combat resolution    2.3 s, 1762 checks` | — |
| 16 | `test_combat_snap` | `FAIL  combat snap    1622.2 s, 1976 checks, 71 failed` | `FAIL  combat snap     803.9 s, 1976 checks, 71 failed` |
| 17 | `test_live_world` | `PASS  live world      986.6 s, 79 checks` | `PASS  live world      516.8 s, 79 checks` (and throws, §7.5) |
| 18 | `test_layering` | `PASS  layering          0.6 s, 63 checks` | `PASS  layering          0.3 s, 63 checks` |
| 19 | `test_asset_tags` | `FAIL  asset tags      450.0 s, 1677 checks, 2 failed` | — |
| 20 | `test_characters` | `PASS  characters       97.7 s, 1315 checks` | — |
| 21 | `test_character_sheet` | `PASS  character sheet    0.3 s, 109 checks` | — |
| 22 | `test_items` | `PASS  items             0.4 s, 179 checks` | — |
| 23 | `test_inventory` | `PASS  inventory         1.2 s, 90 checks` | — |
| 24 | `test_drops` | `PASS  drops           530.4 s, 65 checks` | `PASS  drops           288.6 s, 65 checks` |
| 25 | `test_ground_items` | `FAIL  ground items    488.5 s, 2607 checks, 2 failed` | `FAIL  ground items    298.7 s, 2607 checks, 2 failed` |
| 26 | `test_effects` | `PASS  effects           2.6 s, 1555 checks` | — |
| 27 | `test_actions` | `PASS  actions         569.2 s, 351 checks` | — |
| 28 | `test_control_loop` | `PASS  control loop    576.4 s, 138 checks` | — |
| 29 | `test_walk_motion` | `FAIL  walk motion     201.8 s, 93 checks, 2 failed` | — |
| 30 | `test_observation` | `FAIL  observation     343.1 s, 248 checks, 6 failed` | `FAIL  observation     181.8 s, 248 checks, 6 failed` |
| 31 | `test_scenario` | `FAIL  scenario        655.3 s, 161 checks, 16 failed` | `FAIL  scenario        591.7 s, 161 checks, 16 failed` |
| 32 | `test_agent` | `FAIL  agent           608.5 s, 1503 checks, 2 failed` | — |
| 33 | `test_memory` | `FAIL  memory          670.1 s, 106 checks, 1 failed` | — |
| 34 | `test_goals` | `FAIL  goals           536.9 s, 133 checks, 1 failed` | — |
| 35 | `test_upkeep` | `PASS  upkeep          145.9 s, 95 checks` | — |
| 36 | `test_tool_budget` | `PASS  tool budget     133.2 s, 58 checks` | — |
| 37 | `test_relationships` | `PASS  relationships   165.7 s, 149 checks` | — |
| 38 | `test_ownership` | `FAIL  ownership       108.6 s, 55 checks, 4 failed` | — |
| 39 | `test_checks` | `FAIL  checks          340.6 s, 121 checks, 5 failed` | — |
| 40 | `test_goodwill` | `FAIL  goodwill        422.8 s, 130 checks, 1 failed` | — |
| 41 | `test_territory` | `PASS  territory       240.6 s, 41 checks` | — |
| 42 | `test_orchestrator` | `FAIL  orchestrator    353.0 s, 282 checks, 1 failed` | — |
| 43 | `test_fight_driver` | `FAIL  fight driver    138.1 s, 51 checks, 4 failed` | `FAIL  fight driver    136.8 s, 51 checks, 4 failed` |
| 44 | `test_enemies` | `PASS  enemies         725.6 s, 582 checks` | — |
| 45 | `test_turn_seam` | `PASS  turn seam       325.7 s, 23 checks` | — |
| 46 | `test_strike_record` | `PASS  strike record   130.5 s, 227 checks` | — |
| 47 | `test_attack_clips` | `PASS  attack clips     90.0 s, 1261 checks` | — |
| 48 | `test_weapon_patterns` | `PASS  weapon patterns   89.4 s, 3497 checks` | — |
| 49 | `test_flights` | `PASS  flights         927.0 s, 10672 checks` | — |
| 50 | `test_held_items` | `PASS  held items      273.7 s, 159 checks` | — |
| 51 | `test_player_input` | `PASS  player input    296.3 s, 141 checks` | — |
| 52 | `test_player_actions` | `PASS  player actions  323.9 s, 262 checks` | — |
| 53 | `test_bargain` | `PASS  bargain         952.6 s, 2083 checks` | — |
| 54 | `test_player_inventory` | `PASS  player inventory  203.1 s, 57 checks` | — |
| 55 | `test_player_combat` | `PASS  player combat   206.5 s, 73 checks` | — |
| 56 | `test_walk_in_fight` | `FAIL  walk-in fight   277.2 s, 54 checks, 3 failed` | `FAIL  walk-in fight   126.2 s, 54 checks, 3 failed` |
| 57 | `test_fight_cooloff` | `PASS  fight cool-off  459.7 s, 40 checks` | — |

Counted on the tree as it now stands: **23 of the 57 report red**, and a
twenty-fourth, `test_live_world`, reports green over a test function that threw
(§4.6). The honest count is **33 green of 57**. `test_streaming` is the one that
moved — it was red in every run on the adopted base, it is the only red this seam
itself caused, and §7 is how it was found and what was done about it.

## 4. The reds, each with the item that holds it

Twenty-three reds, and not one of them is a suite this seam may quietly weaken.
Every one is named below with the reason it is red and the item or inbox finding
that owns it. The boundary this item works under is that a red with a cause
predating the terrain seam is *named*, not fixed here; only a red the seam itself
caused belongs to this item, and §7 is that red.

### 4.1 Two reds of cost, not of assertion

| Suite | Verdict | Whose |
| --- | --- | --- |
| `test_terrain_lod` | `FAIL  test_terrain_lod stalled: printed nothing for 3600s, budget 3600s` | `W-terrain-lod-silence`. Stuck rather than slow, and measured: alone on an idle machine it did 26 checks in 1130 s and then finished none for 3600 s while its engine grew from 8.45 to 10.62 GiB. Every suite that finishes does its longest piece of work in under 1735 s. |
| `test_settlements` | `FAIL  test_settlements: the engine died (exit 137) before the suite returned` | `W-settlements-oom`. Size, not silence: 23.31 GiB by itself on a 27.4 GiB machine, against 23.15 GiB in the certifying run. |

Neither says anything about what the ground answers, and neither moved across
the rebuild.

### 4.2 Three reds that predate the adoption, held by `I-59d87f7cd259`

That finding was filed before the base was adopted, and its three reds are
carried as explicit acceptance on `W-adopt-suites` so that the adoption cannot
launder them.

| Suite | The part of its red that `I-59d87f7cd259` holds |
| --- | --- |
| `test_scenario` | the checked-in transcript is stale: `- and the checked-in transcript is what the command prints`. One of its sixteen failures; the other fifteen are §4.5. |
| `test_agent` | the model recording is invalidated and only a live pass can repair it: `- the run ran out of recorded replies: Bram: this reply was recorded for another question: the prompt put here fingerprints c011dc91befe193d and the recorded one 09f4ae51d0f48cee` |
| `test_walk_motion` | the mover scan catches a text cursor: the scan finds three files that advance a coordinate where two are expected, and the third is `tools/measure_ui.gd:500`, `pen.x += font.get_glyph_advance(0, size, glyph).x`. A pen is not a person, and nothing in the sim moved. |

### 4.3 The four inherited-base findings are not in this list at all

`I-5f98c39114cb` (3 cliff-dressing tests), `I-7907295ec48c` (the field-streamer
cold-start deadline and the exit-134 mutex abort), `I-2918426db438` (19 town
composition tests) and `I-822b50ca8426` (8 historical water contour and skin
tests) are all inherited reds of the adopted base's **own** GUT suites. Those
suites are not among the fifty-seven: they are written `extends GutTest`, the GUT
addon is a carve-out of the import, and they have never parsed in this checkout.
`tests/test_path_features.gd` is one of them, which is why naming it in the
rebuild's sweep produced `SCRIPT ERROR: Parse Error: Could not find base class
"GutTest"` rather than a verdict. Nothing this seam did touches them, and nothing
here counts them.

### 4.4 Six reds of recorded evidence: a checked-in transcript is not what the command prints now

| Suite | Verdict | What it says |
| --- | --- | --- |
| `test_memory` | `FAIL  memory          670.1 s, 106 checks, 1 failed` | `- the checked-in transcript is not what the command prints` |
| `test_goals` | `FAIL  goals           536.9 s, 133 checks, 1 failed` | the same line |
| `test_checks` | `FAIL  checks          340.6 s, 121 checks, 5 failed` | `- res://reports/check-evidence.txt is not what res://run_check.sh prints`, and the shipped run now raises three checks where four are recorded |
| `test_goodwill` | `FAIL  goodwill        422.8 s, 130 checks, 1 failed` | `- res://reports/goodwill-evidence.txt is not what res://run_goodwill.sh prints` |
| `test_orchestrator` | `FAIL  orchestrator    353.0 s, 282 checks, 1 failed` | `- res://reports/world-evidence.txt is not what res://run_world.sh prints` |
| `test_ownership` | `FAIL  ownership       108.6 s, 55 checks, 4 failed` | the shipped run's own numbers have moved: `- the shipped run no longer has two edges`, `- the shipped run no longer has ten happenings`, `- the share of sampled ground that is held has moved: 502 of 1681` |

All six are the same thing: a world with different ground under it produces a
different run, and the transcript checked in beside the command was recorded on
the old ground. Regenerating them is `W-adopt-suites`' acceptance line 2 — *every
red is fixed or named with its pre-existing cause* — and regenerating them here
would be certifying this seam against transcripts this seam had just rewritten.

### 4.5 Ten reds of the port: a constant chosen on the retired ground

These are the suites whose assertions still stand and whose *sample points* do
not. Each was a measurement of the old world written into the suite, and the
adopted world is a different world. Three of them say so in their own doc
comments, which is how the pattern was recognised:

| Suite | Verdict | The constant, and where it came from |
| --- | --- | --- |
| `test_combat_board` | `FAIL  combat board    441.0 s, 23362 checks, 2 failed` | `const WATER_SAMPLE_AT := Vector2(526.7, -526.7)`, documented as *"the middle of the wettest 360-unit square within a kilometre"* on the retired ground. On the adopted ground that square is dry, so the four sample boards hold `0` holes: `- the four sample boards should hold both holes and ground, got 0 and 1634`. That water is a hole in a board is not in doubt — this item's third acceptance line seats a fight on a lake shore where `holes=89`, and the rebuild's lakeside window reads 152 water cells and 152 holes. |
| `test_water` | `FAIL  water          1971.8 s, 5320 checks, 7 failed` | `const RIVER_SEED := 19`, documented as *"a seed whose ground near the origin has a river running across it, found with the headless water report"* — the retired water field's report. Seed 19's origin is dry on the adopted ground, so all seven failures are of one shape: `- expected water in view of seed 19, found 0 wet samples`. |
| `test_mountains` | `FAIL  mountains       445.6 s, 13 checks, 5 failed` | the climb box's centre, found by `tools/measure_mountains.sh` on the retired height field: `- the highest ground in the box is only 20.99 units up; there is no mountain here`. Deliberately not re-derived — moving it would be choosing the answer. §5 below. |
| `test_islands` | `FAIL  islands        2468.6 s, 60185 checks, 10 failed` | sample sizes: `- only 16 islands were sampled for the ratio check`, `- seed 1234 has no aerial island in cell (-4.000000, -4.000000)`. The adopted ground places fewer and sparser aerial islands. |
| `test_island_cover` | `FAIL  island cover   1042.9 s, 1245 checks, 3 failed` | the same shape: `- found only 2 overlapping pairs to compare cover on`, `- only 991 things were placed across four seeds, too few to conclude from`. |
| `test_scatter` | see §6 | `- expected ground of both biomes to measure, found 0 forest and 26 highland chunks` |
| `test_combat_snap` | see §6 | a 7×7 grid of meeting places at 260-unit spacing and eight facings; on the old ground all 392 pairs could be seated, and the suite's doc comment records that measurement as its expectation. |
| `test_ground_items` | see §6 | `- the shipped scenarios hold 51 items, not 54` |
| `test_observation` | see §6 | `- on open ground everybody is in sight` is no longer true where the suite stands |
| `test_scenario` | see §6 | the other fifteen of its sixteen: `- the world falls into a fight, at tick -1`, `- the fight was on for 0 ticks` |
| `test_fight_driver` | see §6 | the skirmish's fight does not begin: `- the skirmish begins exactly one fight` expected 1, got 0; all three commanders on the board, expected 3, got 0 |
| `test_walk_in_fight` | see §6 | the same shape from the other side: the walk-in never lands in a fight, 32 expected where 0 happened |

One more red stands slightly apart and is named here so that nothing is left
unowned: `test_asset_tags` (`FAIL  asset tags      450.0 s, 1677 checks, 2 failed`)
says `- 'fir' built no surface to take a colour` and that two `fir` in one biome
do not share a material. That is the foliage *material* layer rather than the
ground, so it follows `W-adopt-render-seam` — the item that puts the adopted
world on screen.

Every one of the twelve above belongs to `W-adopt-suites`, whose whole outcome is the game
running on the adopted base with the suite certifying it. Re-deriving a sample
point here — picking a new `WATER_SAMPLE_AT` until `test_combat_board` goes green
— would be this item choosing the ground it is graded on.

### 4.6 One suite that passes and throws

`test_live_world` printed `PASS  live world      986.6 s, 79 checks` and raised

    SCRIPT ERROR: Out of bounds get index '5' (on base: 'Dictionary')
              at: TestLiveWorld._a_cast_is_stood_where_it_can_walk_from (res://tests/test_live_world.gd:296)

This engine cannot catch a runtime error: it abandons the function it was raised
in and returns to the caller, so the suite reported a pass over a test function
that never finished. The runner's closing check caught it by name, and it is the
thirtieth red of a run whose summary line says twenty-nine. The function it died
in — *a cast is stood where it can walk from* — is the same ground §7 is about,
and it is named there.

## 5. The changed expectations, justified suite by suite

The acceptance line offers two ways to be satisfied — the suites still pass, or
every changed expectation is justified suite by suite. Both halves matter, so
here is every sim-layer suite whose file changed while this seam and the ground
rebuild were being built, and what changed in it. Nine changed; seven of the nine
changed only in which type they name.

**Mechanical re-pointing, no assertion touched** — `test_biomes`, `test_drops`,
`test_island_cover`, `test_islands`, `test_settlements`, `test_terrain_lod`,
`test_water`. Each of these built its own copy of the retired generation stack
(`SimTerrainSurfaceField`, `SimWaterField`, `BiomeField`, `MountainField`) and
now reads the one `AdoptedGround` for the seed. Nothing they claim changed.

Two of them changed their verdict because of it, and that is the rebuild's most
useful finding rather than a weakened check:

* `test_biomes` went **red to green**. Its one failure was `- resolving seed
  1234's biomes in this process gave a different map`: it built `BiomeField.new(SEED)`
  twice and compared the two. It now reads the one ground every other layer in
  the process reads, so there is no second answer to disagree with.
* `test_island_cover` went **green to red** and `test_islands` went from 32
  failures to 10. Both had been building their islands on the retired ground
  while the world they were checking ran on the adopted one — they were measuring
  a generation stack nothing else constructed any more. Deleting it forced them
  onto the real ground. The twelve repeats of `- the observer fell through the
  island at (234.494044, -332.536384)` are gone, because there is now one ground
  and the observer does not fall through it; what is left is sample sizes, §4.5.

**`test_terrain`: a claim added, and the bar not lowered.** Re-pointed at the
real ground, its seed check failed — `two seeds produced nearly the same ground:
37 of 50 samples differed`, against a bar of more than forty. Measured rather
than guessed at, the thirteen agreeing samples were the first thirteen, `x` from
0 to 108 along `z = 4`, and every one was exactly `0.000000000` on both seeds.
That is the adopted base's own flat spawn clearing: `HeightfieldPlan.height01`
ends with a falloff that is exactly zero inside sixty units of the origin for
every seed and fades back in over the next hundred and eighty. The bar was not
lowered. The clearing is now asserted in its own right — twenty points on a ring
inside it, each exactly `0.0` and each identical across two seeds — and the
difference is asked of ground outside it, from `x = 300`. The suite passes with
**72 checks where it had 32**:

    PASS  terrain         491.8 s, 72 checks
    all 1 suites passed (72 checks)

**`test_mountains`: four checks deleted with the layer they documented, three
claims kept.** The deleted four — `_ridged_sample_is_the_folded_field`,
`_the_uplift_is_a_pure_function`, `_the_mask_is_exactly_zero_outside_a_range`,
`_the_uplift_is_regional` — were all about the retired `MountainField` and about
`SimTerrainSurfaceField`'s decomposition of its height into hills plus uplift.
The adopted heightfield has no such decomposition: its ridged relief *is* the
ground, so those four had nothing left to be about. Of the three claims about the
*world*:

* **rocky country stands high** now asks the ground's own uncarved height
  against the meadow's mean rather than an uplift against zero, because a height
  has a datum and an uplift does not — and it **passes**, where the certifying
  run read `highland does not stand high: it averages 0.00 units of uplift
  against the meadow's 0.00`;
* **a summit can be climbed** and **a road is never laid on unwalkable land**
  are unchanged and still red, with the same numbers the certifying run printed.

So `test_mountains` reads 5 failed of 13 where it read 6 of 3030: the lost 3017
checks are the four deleted claims' sample loops, and the lost failure is the
uplift one, which passed as soon as it was asked of a height.

No suite was deleted, and no suite's assertions were weakened. The full working
is `reports/ground-rebuild.md` §7.2–§7.4.

## 6. The seven suites this run put on the rebuilt ground

Seven of the fifty-seven had a verdict only from the certifying run, and all
seven are the ones this seam is most answerable for: the board, the fight and
what a character sees. They were run by name, one engine per suite, with nothing
else on the machine:

    $ lab progress run terrain-seam-3881-simlayer --log reports/terrain-seam-simlayer.log \
        -- ./run_tests.sh test_fight_driver test_walk_in_fight test_observation \
           test_ground_items test_scenario test_combat_snap test_scatter

    RUN   test_fight_driver
    FAIL  fight driver    137.4 s, 51 checks, 4 failed
    RUN   test_walk_in_fight
    FAIL  walk-in fight   125.1 s, 54 checks, 3 failed
    RUN   test_observation
    FAIL  observation     181.4 s, 248 checks, 6 failed
    RUN   test_ground_items
    FAIL  ground items    258.3 s, 2607 checks, 2 failed
    RUN   test_scenario
    FAIL  scenario        591.7 s, 161 checks, 16 failed
    RUN   test_combat_snap
    FAIL  combat snap     803.9 s, 1976 checks, 71 failed
    RUN   test_scatter
    FAIL  scatter        1398.8 s, 1478 checks, 2 failed

    7 of 7 suites failed (104 failed checks of 6575)

58.9 min, peak 19.89 GiB in `test_scatter`, no `SCRIPT ERROR` anywhere in the
transcript, `reports/terrain-seam-simlayer.log`.

Seven failure counts, and every one of them is the number the certifying run
printed sixteen hours into a different process on a different commit: 4, 3, 6,
2, 16, 71, 2. That is the point of running them. Together with the five overlaps
the rebuild's sweep already had, twelve sim-layer suites have now been asked the
same question twice on either side of the ground rebuild and have given the same
answer twelve times. The verdicts in §3 are verdicts on today's ground.

None of the seven is red for a reason this seam can fix by itself: `test_scatter`
wants forest and highland chunks in a box the old ground had them in;
`test_combat_snap` wants all 392 pairs of its 7×7 grid of meeting places to be
seatable, which is a measurement of the old world written down as an expectation;
the other five are the fight that the shipped skirmish no longer falls into and
the transcripts recorded before it stopped. All belong to `W-adopt-suites`, §4.5.

## 7. The one red this seam has to answer for

Twenty-four reds have owners elsewhere. One does not, and finding it is what
made this reading worth doing rather than transcribing.

### 7.1 A suite that was green before the base was adopted

`test_streaming` fails two checks, and has done in every run on the adopted base:

    FAIL  streaming       952.1 s, 4661 checks, 2 failed
            - the observer only travelled 0.000000 world units, too little to stream anything out
            - the walk never dropped any ground

It was green in every full run on the old base, at a slightly higher check count
because the failing check stops the rest of its function:

    $ git grep -h "streaming" 0fac5d37 -- reports        # the last commit before the import
    PASS  streaming      4702 checks

Neither check is a constant chosen on the old ground, and neither was weakened:
they say that a world, stepped two hundred times, moves its view and drops the
ground behind it. `0.000000` is not "not far enough" — it is a view that never
moved at all.

### 7.2 The cause, measured

`tools/spawn_stand_probe.gd` prints the ground under each of the three
written-down spots the ordinary cast is stood on, where the landing search put
each character, and where the view is after two hundred ticks. On `test_streaming`'s
own seed, before any change:

    seed 7 ticks 200
    spot Pip     at=(0.000, 0.000) height=0.000 water=true passable=false
    spot Nettle  at=(-7.000, 4.000) height=0.000 water=true passable=false
    spot Corin   at=(6.000, -5.000) height=0.000 water=true passable=false
    reach Pip     first standable at 192.0 units, (-55.735, 183.733)
    reach Nettle  first standable at 186.0 units, (-55.899, 183.457)
    reach Corin   first standable at 198.0 units, (-56.528, 182.868)
    cast 3 following #1
    stood #1 at=(0.000, 0.000, 0.000) passable=false
    stood #2 at=(-7.000, 0.000, 4.000) passable=false
    stood #3 at=(6.000, 0.000, -5.000) passable=false
    observer at=(0.000, 0.000) after 200 ticks, 0.000 from the origin

Every line of that is the answer. The three spots are under water. The landing
search, whose whole job is to move a character off ground nobody can stand on,
moved nobody — it hands back the spot it was given when it finds nothing. And
the nearest ground anybody *can* stand on is 192 units away, more than three
times the search's reach of 60.

Why 60 is exactly the wrong number is the adopted base's own arithmetic.
`HeightfieldPlan.height01` ends by multiplying the height it computed by a
falloff:

```gdscript
var falloff: float = SlopeProfile.smootherstep(
    clampf((Vector2(pos.x, pos.z).length() - 60.0) / 180.0, 0.0, 1.0))
return clampf(h * falloff, 0.0, 1.0)
```

Inside sixty units of the world origin that falloff is zero, so the ground is
exactly `0.000` whatever the seed chose — the flat spawn clearing `test_terrain`
now asserts in its own right (§5) — and it fades back in over the next hundred
and eighty. A seed whose water table near the origin stands above zero therefore
floods the entire disc, and `LANDING_REACH = 60.0` is the disc's own radius. The
search can never leave the lake it is searching in. Seed 1234's clearing is dry,
which is why every run quoted in this item's other five acceptance lines walks
perfectly well.

So this is the terrain seam's own red, in the precise sense the item's boundary
means: nothing about the suite's expectations changed, and nothing predates the
adoption. A rule of this project's — *put a character where it can walk from* —
met a ground whose shape it was not written for, and silently stopped working.

### 7.3 The fix, and how far it reaches

`WorldCast._standable_near` keeps its near rings exactly as they were and carries
on past the clearing when they find nothing:

    const LANDING_FAR_REACH := 240.0
    const LANDING_FAR_STEP := 12.0

240 because that is where the falloff has finished and the ground is fully
itself again; four times coarser because what is wanted out there is somewhere
to stand rather than the nearest such place. The ring lattice is fixed, so two
processes still put the same character in the same place.

The blast radius is stated rather than hoped for, and it is the narrowest it
could be. `_standable_near` returns at its first line when the written-down spot
is already passable, and the far rings are only reached when the near rings found
nothing — which is exactly the case in which the old code returned a position in
the water. **A world that already stood its cast somewhere standable stands it in
the same place.** Measured on seed 1234, whose origin is dry:

    spot Pip     at=(0.000, 0.000) height=0.000 water=false passable=true
    stood #1 at=(0.000, 0.000, 0.000) passable=true
    stood #2 at=(-7.000, 0.000, 4.000) passable=true
    stood #3 at=(6.000, 0.000, -5.000) passable=true

— the written-down spots, untouched. And on seed 7, where the old code left three
people standing in a lake:

    stood #1 at=(-55.735, 12.000, 183.733) passable=true
    stood #2 at=(-105.708, 8.000, 168.684) passable=true
    stood #3 at=(15.421, 12.000, 198.782) passable=true
    observer at=(-54.133, 190.326) after 200 ticks, 197.875 from the origin
    chunks built 27 -> 43, loaded 40

197.875 units from the origin against an unload radius of 56, and 43 chunks built
against 40 still loaded — which is the two failing checks, answered.

### 7.4 The suites, re-run

`test_streaming` and `test_live_world` are the two suites that walk an ordinary
world, and the four suites this run had already measured an hour earlier on the
unchanged tree were run beside them as the regression check:

    $ lab progress run terrain-seam-3881-landing --log reports/terrain-seam-landing.log \
        -- ./run_tests.sh test_streaming test_live_world test_fight_driver \
           test_walk_in_fight test_observation test_ground_items

    RUN   test_streaming
    PASS  streaming       959.7 s, 4679 checks
    RUN   test_live_world
    PASS  live world      516.8 s, 79 checks
    RUN   test_fight_driver
    FAIL  fight driver    136.8 s, 51 checks, 4 failed
    RUN   test_walk_in_fight
    FAIL  walk-in fight   126.2 s, 54 checks, 3 failed
    RUN   test_observation
    FAIL  observation     181.8 s, 248 checks, 6 failed
    RUN   test_ground_items
    FAIL  ground items    298.7 s, 2607 checks, 2 failed

    4 of 6 suites failed (15 failed checks of 7718)

`test_streaming` is **green**, at 4679 checks where the failing run reached 4661
— the eighteen it gains are the checks that follow the two that used to fail.
The four regression suites print 4, 3, 6 and 2 failures, which are the four
numbers they printed an hour earlier before the change, so the far rings moved
nothing that was already working. 37.5 min, peak 9.82 GiB,
`reports/terrain-seam-landing.log`.

`test_live_world` is unchanged: it reports `PASS` and raises the same runtime
error, and the runner fails the run for it —

    run_tests: suite 'test_live_world' raised a runtime error (SCRIPT ERROR above).

— which is §7.5.

### 7.5 What this does not fix

`test_live_world` still throws in `_a_cast_is_stood_where_it_can_walk_from`, and
for a reason of its own rather than the ground's:

    SCRIPT ERROR: Out of bounds get index '5' (on base: 'Dictionary')
              at: TestLiveWorld._a_cast_is_stood_where_it_can_walk_from (res://tests/test_live_world.gd:296)

The line is `began[one.id]`, and `began` was filled from the cast before the run.
Index 5 is somebody who was not in the world when the run started — an enemy that
walked into it while it was being stepped, which the probe sees too (`stood #4`
at tick 0 on seed 1234, `ended #5` two hundred ticks later). The suite has to
decide what it means to ask how far a newcomer moved. That is `W-adopt-suites`'
to settle, and it is named in §4.6 rather than fixed here.

## 8. The retired flat-terrain source, read off the tree

The acceptance line as first written offered a choice — *removed, or kept behind
a named switch with the reason recorded*. That choice was withdrawn by the user's
no-adapter directive (`I-1e5f2bcd2729`): port by rebuilding on the base's own
code, not by adapting the old code onto it. `W-ground-rebuild` carried it out at
commit `03f2202e`, and here it is read off the tree rather than decided again.

The four files are gone, in one commit, and nothing brought them back:

    $ ls sim/biome_field.gd sim/terrain_surface_field.gd sim/water_field.gd sim/mountain_field.gd
    (none present)

    $ git log --oneline --diff-filter=D -- sim/terrain_surface_field.gd \
        sim/water_field.gd sim/biome_field.gd sim/mountain_field.gd
    03f2202e Rebuild the sim's ground on the adopted base and take the old stack out of the tree

Also deleted with them: `TerrainQuery.for_seed_legacy` — the one switch that did
exist, which would have let a caller ask for the old ground — and
`ValueNoise.ridged_sample`, the folded noise the retired mountain layer was made
of. There is no named switch, because there is nothing left for a switch to
choose between.

What stands in their place is one class. `sim/adopted_ground.gd` declares
`class_name AdoptedGround` with no inner classes and no inheritance from anything
retired: height is `TerrainSurfaceField.surface_y` over a `WorldFieldBlockCache`
region, water is `WaterFieldContext.is_wet`/`level_at` over a `WaterPlan`, biomes
are `Helper.biome_weights5` and the three biome axes — every one of them the
adopted base's own type. `sim/terrain_query.gd` holds exactly one member for the
ground:

    ## The ground itself: the adopted heightfield, water plan and biome fields for
    ## this seed. How high the land is, where the water is, and which biome the
    ## ground is are all one object's answers, because in the adopted stack they
    ## are one stack of plans rather than three independent noise fields.
    var ground: AdoptedGround = null

Three names survive as prose rather than as code. `README.md` still described
`SimTerrainSurfaceField` and `BiomeField` as parts of the live stack; that is
corrected in the same commit as this file. `ADOPTION.md` and
`docs/upstream-delta-import.md` name them in tables of what the import renamed
and what it maps to upstream, which is history and stays.
