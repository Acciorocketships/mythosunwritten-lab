# Where test_settlements' memory goes

Cycle 3886, work item `W-settlements-oom`. Machine: 27.4 GiB total, one engine
at a time, `tools/godot/godot4` (Godot 4.7.2), commit of this file's branch.

## What was wrong

In the certifying run `adopt-full-suite-3765` the engine running
`tests/test_settlements.gd` grew to 24.29 GiB and was SIGKILLed (exit 137)
before the suite returned any verdict.

## The reproduction

    RUN_TESTS_PROGRESS=15 RUN_TESTS_MEMLOG=.testruns/memory.diagnose.log \
      ./run_tests.sh test_settlements

Killed at **20.89 GiB** after **49.7 min**, with a single silent stretch of
**1971 s** — the whole of `_a_share_of_villages_stand_on_a_shore`, which makes
no check while it is gathering. The same shape as run 3765; it died earlier only
because this machine had less free at the start.

## The measurement

`tools/settlements_memory_probe.gd --shape gather` builds one seed's stack and
gathers villages over the same 7×7 settlement-cell square the suite's first
phase uses, then gives the memory back one holder at a time. Resident memory is
field two of `/proc/self/statm`; engine-tracked is `Performance.MEMORY_STATIC`.

| step | resident | engine-tracked | WaterField profiles / traces / basins |
| --- | ---: | ---: | ---: |
| start | 0.14 GiB | 0.03 GiB | 0 / 0 / 0 |
| 19 villages gathered over 49 cells (180 s) | 5.18 GiB | 3.58 GiB | 41 / 41 / 12 |
| WaterField statics purged, stack still held | 5.16 GiB | 3.47 GiB | 0 / 0 / 0 |
| last reference to the stack dropped | 5.14 GiB | **0.03 GiB** | 0 / 0 / 0 |

Three conclusions, in the order they matter:

1. **It is not a leak.** Every byte the engine believes is allocated comes back
   when the last reference to the `AdoptedGround` / `TerrainQuery` stack goes.
2. **It is not the adopted water caches.** `WaterField._profiles`,
   `_trace_regions` and `_basin_cache` — the unbounded statics
   `sim/adopted_ground.gd`'s `_purge_water_statics` exists to clear — hold
   0.11 GiB of the 3.58, three per cent.
3. **One live world is 3.44 GiB**: the two `WorldFieldBlockCache` instances at
   `FIELD_BLOCKS = 16`, plus the `SettlementField` and `IslandField` per-cell
   caches.

Resident memory does **not** follow the engine's number down — 5.14 GiB stayed
resident after everything was freed, because the allocator keeps the pages. So
what the kernel's killer reads is a high-water mark of *simultaneous* live
worlds. The only lever on it is how many stacks are alive at once.

## The line

`tests/test_settlements.gd:270`, before this cycle:

    shores.append({"site": site, "terrain": terrain})

inside a loop over eight `SHORE_SEEDS`. Every seed's stack stayed referenced
until after the loop: 8 × 3.44 GiB = **27.5 GiB** against a 27.4 GiB machine.

## The fix

The survey now asks each shore village its two questions while that village's
own world is still the one in hand, and carries only `Settlement` data — which
holds no reference to any ground — across the loop. Nothing the suite asserts
changed: the 90 check call sites are textually identical before and after
(`checks_before.txt`, `checks_after.txt`).

Alternatives considered and rejected:

* **Bound the adopted `WaterField` statics.** Measured at 0.11 GiB — three per
  cent of one world. It would not have helped, and it changes adopted code the
  game also runs.
* **Lower `AdoptedGround.FIELD_BLOCKS` below 16.** Trades memory for rebuild
  seconds on every caller, the game included. The suite's problem was eight live
  stacks, not one stack being too big.
* **Lower `AdoptedGround.SHARED_SEEDS` to 1.** Would not have helped: the
  suite's own list held the references, not the shared dictionary. Eviction was
  already happening, and already purging the statics, all through the failure.
* **Split the suite, or accept a named red of honest cost.** Not needed once the
  survey holds one world.

## The verdict run

    RUN_TESTS_PROGRESS=15 RUN_TESTS_MEMLOG=.testruns/memory.verdict.log \
      ./run_tests.sh test_settlements

| | before | after |
| --- | ---: | ---: |
| verdict | engine died, exit 137 | `FAIL settlements 4208.2 s, 30734 checks, 99 failed` |
| peak resident | 20.89 GiB (killed) | **22.20 GiB** |
| headroom on 27.4 GiB | 0.11 GiB at the kill | 5.2 GiB |
| wall time | 49.7 min (killed) | 70.5 min (1.17 h) |
| longest silence | 1971 s | 525 s |
| seeds, checks | died at ~6 of 8 seeds, 316 checks | 8 seeds, 225 villages, 30734 checks |

Seed 1234 (`SEED`), the suite's own constant; the survey's own eight seeds are
`SHORE_SEEDS = [1234, 7, 3, 19, 42, 101, 5, 11]`.

The 99 failed checks are assertions — the inherited town-composition failures
that inbox item `I-2918426db438` records (`'signpost' is not a catalog tag`,
`only 48 wet samples`, the bridge-carving digests, `6 wide upper storeys swept`
against the 10 the sweep wants). They are a different item. What this one owed
was a verdict instead of a corpse, and the suite now gives one.

## What the remaining 22.20 GiB is

Read off the progress lines of the verdict run, which now carry resident memory
beside the check they were printed at:

| phase | resident after |
| --- | ---: |
| engine start | 0.60 GiB |
| `run()` builds seed 1234 and gathers 49 cells | 7.71 GiB |
| `_asking_the_cells_in_another_order_changes_nothing` | 7.79 GiB |
| `_a_different_seed_puts_the_villages_somewhere_else` (seed 7) | 12.84 GiB |
| `_a_share_of_villages_stand_on_a_shore`, per seed | 13.25 → 14.79 → 19.84 → 20.13 → 20.85 → 21.44 → 22.07 → 22.17 GiB |
| everything after it (eighteen more phases) | flat, 22.17–22.20 GiB |

The staircase is the survey's eight cold worlds. Even holding one at a time, the
high-water mark rises about a gibibyte a seed, because `run()`'s own stack for
seed 1234 stays pinned for the whole suite and `AdoptedGround._shared` keeps the
previous seed as well — three stacks live where two would do, and a heap that
fragments across eight build-and-free cycles.

That margin, 5.2 GiB, is enough and was not spent further. If it ever needs to
be, the next lever is a way for a caller to say it has finished with a world —
an `AdoptedGround.forget(seed)` beside `shared_for_seed` — which would take the
survey from three live stacks to two. It is not needed today and is not worth a
second seventy-minute run to prove until it is.
