# Two hours of nothing from test_terrain_lod: slow, by a factor of five

**Verdict: slow, not stuck — and the suite no longer exists.**

The suite that went quiet, `tests/test_terrain_lod.gd`, was deleted at commit
`bc994710` ("Draw the world with the adopted shell"), together with
`tests/test_grass.gd`, `tests/test_reflection.gd` and two probes, because the
layer it tested — `render/distant_ground.gd` — left the tree when the render
shell became an inherited scene of the adopted `scenes/world.tscn`. So it can
no longer be made to reach a verdict, and its cost no longer falls on any run.
Everything below is therefore a diagnosis of the stall and a measurement of
what the adopted ground costs, not a repair of a live suite.

The cost mechanism it died of is live code, and it is the point of this note:
**on the adopted ground the price of a sweep is set by how scattered it is, not
by how many samples it takes.**

## 1. Where it went quiet

Read off `reports/watchdog/test_terrain_lod.log`, the run that gave this suite
the machine to itself under the corrected 3600 s silence budget:

```
  ..  terrain_lod      304 s, 24 checks: only 32544 vertices were compared against the world's height
  ..  terrain_lod     1130 s, 26 checks: 0 positions gave a different ground height once a different level was...
FAIL  test_terrain_lod stalled: printed nothing for 3600s, budget 3600s
```

That last message is the `equal()` at `tests/test_terrain_lod.gd:267` (as of
`bc994710^`), inside `_the_world_reports_one_height_whichever_level_drew_it()`
which begins at line 225. `run()` at line 26 calls the checks in source order,
so the check that started next and never returned is
`_the_simplified_shape_stays_inside_its_stated_envelope()` at **line 297** —
specifically its loop at **lines 302–312**:

```gdscript
for i in 900:
    var x := float((i * 977) % 4000) - 2000.0
    var z := float((i * 1861) % 4000) - 2000.0
    var full := terrain.ground_height_at(x, z)
    var carved := terrain.ground.water_column(x, z).x
```

900 positions, scattered by a modular stride over a 4000-unit square.

## 2. What that loop costs on this machine

`tools/ground_scatter_cost.gd` replays that exact position sequence against the
same seed (`reports/ground-scatter-cost.log`):

| | positions | wall | per position |
|---|---|---|---|
| cold build of the seed's plans | — | 73.6 s | — |
| the check's own order, first visit | 60 | 1169.3 s | **19.49 s** |
| the same 60 positions, second visit | 60 | 144.3 s | 2.40 s |

Extrapolated over the loop: **900 × 19.49 s ≈ 17 541 s ≈ 4.9 hours for that one
check**, against a silence budget of 3600 s. The engine was killed roughly a
fifth of the way into a single check. Nothing was stuck; the flat resident
memory in the certifying run was telling the truth.

The suite builds **one** world, not many: every `SimWorld.new(SEED)` (eleven of
them) and `TerrainQuery.for_seed(SEED)` (three) resolve to the same
`AdoptedGround` through `AdoptedGround.shared_for_seed`, so the 73.6 s cold
build is paid once. It also launches two render-shell subprocesses at lines 574
and 575, each a whole engine of its own.

## 3. Why one sampled position costs twenty seconds

`tools/ground_block_cost.gd` reads the block cache's own build counters
(`reports/ground-block-cost.log`). Six `ground_height_at` calls, per distance
band:

| band | positions | wall | per position | region builds | water builds | evictions |
|---|---|---|---|---|---|---|
| 96 units out | 6 | 83.5 s | 13.92 s | 113 | 113 (73.2 s) | 97 |
| 950 units out | 6 | 157.4 s | 26.24 s | 164 | 164 (155.5 s) | 164 |
| 2000 units out | 6 | 213.0 s | 35.51 s | 193 | 193 (210.5 s) | 193 |

**One query builds twenty to thirty-two 192-unit blocks**, and 96–99% of the
time is the water context. The chain, named:

- `sim/terrain_query.gd:135` `water_column_at()` composes the settlement layer
  on top of the carved ground: `settlement_field.ground_delta_at(...)`.
- `sim/settlement_field.gd:551` `ground_delta_at()` → `:493` `pads_near()` →
  `:504` `_build_pad_tile()`, which sweeps a 3×3 grid of site cells
  (`reach = ceil((PAD_TILE_MARGIN + PAD_RADIUS_MAX) / SITE_CELL) = 1`) calling
  `settlement_in_cell()` at `:457`.
- Each settlement candidate probes the water column (e.g.
  `sim/settlement_field.gd:799`), and each fresh probe builds a water context in
  `scripts/terrain/field/WorldFieldBlockCache.gd:88` at about 1.4 s.

That work is memoised per **32-unit pad tile** (`PAD_TILE`, `:423`). A walk that
moves 0.9 units a tick re-uses one pad tile for dozens of ticks and pays this
once. A sweep whose consecutive positions are hundreds of units apart pays it at
**every single position**.

## 4. It is not the cache being too small

The obvious suspect was `sim/adopted_ground.gd:82`, `const FIELD_BLOCKS := 16` —
a cache smaller than one query's own footprint, so that a single call evicts
blocks it is about to want again. `tools/ground_cache_size.gd` tests it
directly, same seed, same twenty scattered positions
(`reports/ground-cache-size.log`):

| cache | wall | per position | water builds | evictions | held |
|---|---|---|---|---|---|
| 16 blocks (today) | 677.6 s | 33.88 s | 614 | 598 | 16 |
| 64 blocks | 637.2 s | 31.86 s | 450 | 386 | 64 |
| 192 blocks | 592.1 s | 29.61 s | 405 | 213 | 192 |

A twelvefold cache buys **12%**. Builds fall from 614 to 405 and stop there,
because ~20 blocks per query is the genuine footprint of composing the
settlement layer, not thrash. Peak resident memory stayed at 9.4–9.5 GiB across
all three, so the cache is not what the engine's ten gigabytes are made of
either — the plans' own memoisation is.

**Raising `FIELD_BLOCKS` is not the fix, and nothing here was changed.**

## 5. What this means beyond the retired suite

The five suites that went quiet past 1500 s in the certifying run and still
reached verdicts — `test_scatter` at 1735 s, `test_atmosphere` 1664 s,
`test_islands` 1658 s, `test_grass` 1571 s, `test_ui_panel` 1564 s — are paying
the same price. The lever is not the silence budget and not the block cache: it
is whether a sweep is scattered or local. A suite that walks the ground pays a
pad tile once; a suite that samples it at random pays a settlement neighbourhood
per position.

## Commands

```
godot4 --headless --path . -s res://tools/ground_scatter_cost.gd \
  -- --seed 1234 --span 2000 --count 900 --sample 60
godot4 --headless --path . -s res://tools/ground_block_cost.gd -- --seed 1234 --blocks 6
godot4 --headless --path . -s res://tools/ground_cache_size.gd \
  -- --seed 1234 --cache 16 --sample 20 --span 2000
```

Seed 1234 throughout — the suite's own `SEED`. Peak resident memory across the
probe runs: 9.36–9.49 GiB, measured with `psutil` from outside the engine.

## Appendix: the checks the suite made, before and after

Nothing in this item changed what the suite asserts, because nothing in this
item touched the suite. Its fourteen checks, in `run()` order at `bc994710^`
(the last commit at which the file existed), are:

1. `_the_cell_coarsens_with_distance` (l.45)
2. `_the_coarse_ground_covers_the_view_exactly` (l.65)
3. `_level_one_contains_every_chunk_the_streamer_could_load` (l.130)
4. `_the_radius_grows_without_the_count_growing_quadratically` (l.150)
5. `_every_vertex_is_the_worlds_own_height` (l.184)
6. `_the_world_reports_one_height_whichever_level_drew_it` (l.225) — the last to finish
7. `_the_simplified_shape_stays_inside_its_stated_envelope` (l.297) — **where it went quiet**
8. `_two_tiles_of_a_level_meet_on_the_same_numbers` (l.325)
9. `_a_tile_is_a_pure_function_of_its_key` (l.370)
10. `_the_skirt_is_deeper_than_the_worst_seam` (l.419)
11. `_a_tile_away_from_a_boundary_is_not_rebuilt_by_walking` (l.451)
12. `_the_ground_never_opens_up_while_it_is_walked_across` (l.488)
13. `_headless_meshes_no_distant_ground_at_all` (l.543)
14. `_the_world_is_byte_identical_with_and_without_the_distant_ground` (l.573)

`git show bc994710^:tests/test_terrain_lod.gd` recovers the file. The three
files added by this item — `tools/ground_scatter_cost.gd`,
`tools/ground_block_cost.gd`, `tools/ground_cache_size.gd` — are measurement
probes and assert nothing.

## What is left open

The suite cannot reach a verdict: it was retired two commits ago along with the
layer it tested. Whether the ground's scattered-sampling cost should be brought
down — by giving the settlement layer a cheap "is there any village within
reach of this position" early-out before it builds a pad tile, which would skip
the whole fan-out at the great majority of positions — is a change to live sim
code and belongs to its own item, not to a diagnosis.
