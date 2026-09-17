# The certifying full-suite run on the adopted base

One `./run_tests.sh` over all seventy-three suites, on the adopted
mythosunwritten base, on this machine: 27.4 GiB, 32 processors, no swap. Started
2026-09-15 01:25:52, ended 17:31:48, as job `adopt-full-suite-3866` on commit
`221b74af`. Its transcript is `adopted-base-full-suite.log` beside this file and
its memory recording is `adopted-base-full-suite-memory.log`; both are committed,
and everything below is read off them.

The line the run ended on, quoted:

    29 of 73 suites failed (182 failed checks of 188955)

That line undercounts by one, and the run said so itself three lines above it --
see "The thirtieth red" below. The transcript holds no exit line, because the
runner prints none; what it holds is that summary and a runtime-error block, and
either one alone means a failed run.

## What it cost

| | |
|---|---|
| wall time | 965.9 min (16.10 h) |
| peak memory | 25.46 GiB, in suite 12 (test_scatter), against this machine's 27.4 GiB -- 1.9 GiB spare at the worst moment |
| suites over 10 GiB | 30 of 73 |
| suites over 20 GiB | 2 of 73 (test_scatter 25.46, test_settlements 23.15) |
| longest quiet stretch | 3234 s, in suite 11 (test_settlements) |
| verdicts | 44 pass, 29 red in the summary, 1 more red the summary missed |

A full run is an overnight job on this machine, and that is now a measurement
rather than an expectation. The per-suite wall times sum to 963.5 min against
the run's 965.9 min, so 2.4 min of the sixteen hours is the run itself -- the
engine that lists the suites, seventy-three engine starts, the closing checks --
and everything else is a suite doing its work.

The ten heaviest suites, and the ten longest:

| # | suite | peak | wall | # | suite | peak | wall |
|---|---|---|---|---|---|---|---|
| 12 | test_scatter | 25.46 GiB | 51.8 min | 9 | test_islands | 19.28 GiB | 74.2 min |
| 11 | test_settlements | 23.15 GiB | 68.8 min | 61 | test_grass | 18.68 GiB | 69.6 min |
| 9 | test_islands | 19.28 GiB | 74.2 min | 11 | test_settlements | 23.15 GiB | 68.8 min |
| 61 | test_grass | 18.68 GiB | 69.6 min | 12 | test_scatter | 25.46 GiB | 51.8 min |
| 8 | test_water | 17.77 GiB | 32.1 min | 5 | test_terrain_lod | 9.86 GiB | 48.6 min |
| 2 | test_determinism | 15.18 GiB | 14.0 min | 63 | test_atmosphere | 11.47 GiB | 39.2 min |
| 10 | test_island_cover | 15.12 GiB | 29.0 min | 67 | test_ui_panel | 11.08 GiB | 34.1 min |
| 7 | test_biomes | 14.06 GiB | 7.2 min | 66 | test_render_shell | 11.11 GiB | 32.2 min |
| 3 | test_terrain | 13.97 GiB | 8.2 min | 8 | test_water | 17.77 GiB | 32.1 min |
| 16 | test_combat_snap | 13.87 GiB | 27.2 min | 58 | test_window_glow | 11.51 GiB | 31.0 min |

The bound that made the run possible is one engine per suite: every suite starts
from nothing and gives every page back when it exits. Thirty of the seventy-three
suites hold more than 10 GiB at their peak, and the single engine that used to
run all of them released nothing between one and the next -- the kernel killed it
twice on this machine, once at 23.2 GiB and once at 12.5 GiB, that second time
three suites in, at the first suite that builds terrain.

## Two things the run got wrong about itself, and both are fixed

Reading the table back against the transcript turned up two defects in the
measurement rather than in the run:

1. **Every suite was numbered one too high.** The numbers came from the order of
   labels in the recording, and the recording begins with the stretch before the
   first engine has said anything, labelled `(starting)`. That is a phase of the
   run, not a suite of it, so it took the number 1 and pushed every real suite
   up by one: the run reported its peak "in suite 13 (test_scatter)" when
   test_scatter is the twelfth suite of the run.
2. **One suite had no row at all.** The table named seventy-two of seventy-three.
   The one it dropped was the last, `test_panel_sentences`, which passes in 0.0 s:
   the sampler takes a sample every two seconds and learns which suite it is in
   by reading the transcript, so a suite whose whole life is shorter than that
   interval can fall between two samples -- and the last suite of a run has no
   next engine to be sampled against. Confirmed in the recording: its final line,
   `17:31:48 test_ui_digits 1 0.30 22.48 418682`, is the *next* engine's startup
   memory still labelled with the previous suite, and the run ended before the
   next sample.

Both were in the table's `awk` in `run_tests.sh`. The numbers now come from the
order the transcript entered the suites in, the starting phase is printed as
`--` rather than as suite 1, and a suite the sampler never caught gets a row
saying so instead of no row. Replayed over this very recording, the table now
reads:

      --  (starting)             peak   0.30 GiB     0.1 min  quiet up to     2 s
       1  test_rng               peak   0.25 GiB     0.0 min  quiet up to     0 s
     ...
      11  test_settlements       peak  23.15 GiB    68.8 min  quiet up to  3234 s
      12  test_scatter           peak  25.46 GiB    51.8 min  quiet up to  1735 s
     ...
      73  test_panel_sentences   not sampled: no 2 s sample fell inside it
      peak of the whole run: 25.46 GiB, in suite 12 (test_scatter)
      longest quiet stretch: 3234 s, in suite 11 (test_settlements)

and a live three-suite run numbers them 1, 2, 3 with the starting phase at `--`.
A suite shorter than the sampling interval still cannot have its peak measured;
what has changed is that the table says which suite that was instead of running
one row short of the run.

## The silence budget this run ran under, and the budget now

The run printed `the silence budget this run ran under: 1800s`, and that number
was set from three suites, where 455 s was the worst gap between checks and four
times it looked like margin. Over all seventy-three, the worst gap in a suite
that still reached a verdict is 1735 s (test_scatter) -- so 1800 s stood 65 s,
3.6%, above honest work. Worse, the watchdog counted turns round a loop rather
than seconds, so the budget it enforced stretched with the machine: 1802 s at
9.86 GiB, and more than 3234 s at 23.15 GiB, where it never fired at all.

Both are settled, in `reports/watchdog/README.md`: the budget is read off the
clock, so the printed number is the enforced one, and it is 3600 s -- twice the
worst honest gap. This run is therefore the last one whose stall verdicts have to
be read with the budget's history in hand.

## The reds, each for its own reason

Twenty-nine in the summary line, plus the thirtieth the summary missed. Suite
numbers are the run order of the corrected table.

### Three reds of cost, not of assertion

| # | suite | what happened | its own reason |
|---|---|---|---|
| 5 | test_terrain_lod | killed for silence at 1802 s | Stuck, not slow -- and this is now measured rather than assumed. Alone on an idle machine under the 3600 s budget it did 26 checks in 1130 s and then finished none for 3600 s while its engine grew from 8.45 to 10.62 GiB. Every suite that finishes does its longest piece of work in under 1735 s. Belongs to W-terrain-lod-silence. |
| 11 | test_settlements | engine kernel-killed, exit 137, after 68.8 min | Size, not silence: it reached 23.15 GiB by itself on a 27.4 GiB machine. It had also been quiet for 3234 s, and no silence budget short of never firing would have caught it first. Belongs to W-settlements-oom. |
| 58 | test_window_glow | killed for silence at 1852 s | A wrong verdict by the runner, not a fault of the suite. Alone under the corrected budget it reaches a verdict in 2255.7 s, 20651 checks with one failing; its worst gap alone is 1115 s against 1735 s of honest work elsewhere. The one failing check is the suite's own business; being called stalled was the old budget's. |

### Nineteen reds of the port: what the adopted base changed under a suite

None of these is the runner's business, and none of them is memory. They are the
port's own work. Fourteen are the ground-and-board seam in one form or another --
the discrete board and the sim still ask the old ground its questions, and the
adopted continuous ground answers zero, flat or nothing -- which is the reason
W-ground-rebuild and W-adopt-terrain-seam exist. The other five are other layers
of the same port: test_asset_tags is the foliage material layer, test_ownership
is the shipped run's own numbers, and test_reflection and test_render_shell are
the render shell drawing the adopted world. Each is named in its own words:

| # | suite | failed | what it says |
|---|---|---|---|
| 4 | test_streaming | 2 of 4661 | "the observer only travelled 0.000000 world units" -- the walk never moves, so nothing streams out and no ground is dropped |
| 6 | test_mountains | 6 of 3030 | "highland does not stand high: it averages 0.00 units of uplift against the meadow's 0.00"; the highest ground in the box is 20.99 up; 42 of 4614 road steps climb more than 3.0 in a cell |
| 7 | test_biomes | 1 of 212 | "resolving seed 1234's biomes in this process gave a different map" -- the biome resolve is not yet order-independent on the adopted ground |
| 8 | test_water | 7 of 5320 | "expected water in view of seed 19, found 0 wet samples", and six more of the same shape: no banks, nothing to test passability against, no sheet at the origin |
| 9 | test_islands | 32 of 105160 | the aerial islands are not attached to the query: `ground_at()` did not report the island, "the island's ground (-inf) is not above the ground plane", and twelve repeats of "the observer fell through the island at (234.494044, -332.536384)" |
| 12 | test_scatter | 2 of 1478 | "expected ground of both biomes to measure, found 0 forest and 26 highland chunks"; 0 pieces of waterside flora |
| 13 | test_combat_board | 2 of 23362 | "the four sample boards should hold both holes and ground, got 0 and 1634" -- every cell reads as ground, so no hole and no island ever reach a board |
| 16 | test_combat_snap | 71 of 1976 | one line per place and facing: "a pair meeting at (-780.0, -520.0) facing 0 could not be seated". Nowhere on the adopted ground can two people be seated on a board |
| 25 | test_ground_items | 2 of 2607 | "the shipped scenarios hold 51 items, not 54" and "nobody fell in 140 ticks of the skirmish" -- the second is downstream of no fight starting |
| 30 | test_observation | 6 of 248 | "on open ground everybody is in sight" is now false, and the absent-field reason comes back "not in line of sight" where the suite expects "nothing is driving this scene"; also nobody stands on the tactical board at tick 80 |
| 31 | test_scenario | 16 of 161 | the fight never happens: "the world falls into a fight, at tick -1", 0 ticks of fight, 0 blows chosen, 0 landed, and one extra person left standing (5 where 4 was expected) |
| 43 | test_fight_driver | 4 of 51 | "the skirmish begins exactly one fight": expected 1, got 0; all three commanders on the board: expected 3, got 0 |
| 56 | test_walk_in_fight | 3 of 54 | the walk-in never lands in a fight: 32 expected where 0 happened |
| 61 | test_grass | 2 of 894 | "the same island grew 1036 patches here and 1035 after being moved 137, 219: its grass is being decided by where it hangs"; and the probe found only 5 islands |
| 63 | test_atmosphere | 2 of 156 | "the spot this check stands in is not a twilight marsh any more", and that view holds 0 glowing orbs beside 0 reeds |
| 19 | test_asset_tags | 2 of 1677 | "'fir' built no surface to take a colour", and two 'fir' in one biome do not share a material |
| 38 | test_ownership | 4 of 55 | the shipped run's own numbers have moved: no two edges, no ten happenings, held ground now 502 of 1681 sampled cells |
| 64 | test_reflection | 1 of 31 | "the run with the mirror drew 0 mirror frames, so comparing it against a run with none shows nothing" |
| 66 | test_render_shell | 1 of 46 | "the handle sweep covered 5 of the 9 handle kinds; something the world hands out was not loaded to test" |

### Six reds of recorded evidence: a checked-in transcript is not what the command prints now

The adopted base changed what these commands print, and the transcripts checked
in beside them were recorded before it. Each names its own file:

| # | suite | failed | the file it holds against the command |
|---|---|---|---|
| 32 | test_agent | 2 of 1503 | the recorded model replies are for other questions -- "the prompt put here fingerprints c011dc91befe193d and the recorded one 09f4ae51d0f48cee", for Bram, Sable and Pell -- so the run ran out of replies, and the checked-in transcript then differs |
| 33 | test_memory | 1 of 106 | "the checked-in transcript is not what the command prints" |
| 34 | test_goals | 1 of 133 | "the checked-in transcript is not what the command prints" |
| 39 | test_checks | 5 of 121 | the shipped run now raises three checks where four are recorded, and `res://reports/check-evidence.txt` is not what `res://run_check.sh` prints |
| 40 | test_goodwill | 1 of 130 | `res://reports/goodwill-evidence.txt` is not what `res://run_goodwill.sh` prints |
| 42 | test_orchestrator | 1 of 282 | `res://reports/world-evidence.txt` is not what `res://run_world.sh` prints |

Only test_agent's is a model-recording invalidation -- the prompts changed, so
the recorded replies no longer answer them. The other five are ordinary
transcript drift.

### One red of the check's own making

| # | suite | failed | its own reason |
|---|---|---|---|
| 29 | test_walk_motion | 2 of 93 | The suite asserts that exactly two files advance a character across the ground, and the third match is `res://tools/measure_ui.gd:500`, `pen.x += font.get_glyph_advance(0, size, glyph).x` -- a text pattern catching a glyph pen, not a character walking. The check is too loose, and nothing in the sim moved. |

### The thirtieth red

`test_live_world` (suite 17) printed `PASS  live world      986.6 s, 79 checks`,
and raised a runtime error on the way there:

    SCRIPT ERROR: Out of bounds get index '5' (on base: 'Dictionary')
              at: TestLiveWorld._a_cast_is_stood_where_it_can_walk_from (res://tests/test_live_world.gd:296)

This engine cannot catch a runtime error or be asked afterwards whether one
happened: the error abandons the function it was raised in and returns to the
caller, and the caller carries on. So the suite reported a pass over a test
function that never finished. The runner's closing check is what catches it, and
it did, by name and with the suite attributed from the last RUN line before the
error:

    run_tests: suite 'test_live_world' raised a runtime error (SCRIPT ERROR above).
    run_tests: the engine returned to the caller and the runner could not see it,
    run_tests: so the run is failed here whatever the summary said.

It is the only `SCRIPT ERROR` in 5227 lines of transcript. The honest count for
this run is therefore **30 red of 73**, and the summary line's 29 is the
count of suites that reported their own verdict as red. Naming it here is the
whole point of the check: a suite that throws and passes is the one failure a
green summary can hide.
