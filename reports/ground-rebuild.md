# Rebuilding the ground on their code

The base adoption (see [ADOPTION.md](../ADOPTION.md)) replaced this project's
from-scratch terrain with mythosunwritten's streamed continuous heightfield.
The first port of the sim onto it, written at cycle 3726, did that with three
adapter classes: inner classes of `sim/adopted_ground.gd` that *extended* this
repo's retired ground fields and overrode their sampling primitives, so that
everything above kept its old read surface while the answers came from the
adopted stack. The user ruled that out (side-conversation directive 26,
2026-09-15):

> instead of making adapters, in places where the code can't easily just be
> added on top, can you please just start with the other code and build on top
> of it? that will lead to a cleaner final product than trying to write
> adapters between two different regimes

This is that rebuild. The ground reading is written against the adopted types
themselves and the retired generation stack is out of the tree.

## 1. Every place the port bridged the two regimes

A *bridge* here means code whose job was to translate between the adopted
stack and this repo's retired one. That is different from a *layer*: something
this project has that the base does not, sitting on top of the base's answers.
The user's directive is about bridges. Layers are what the whole port is for.

Enumerated by file and class, every one of them, before anything was changed:

| # | Where | What it was | Disposition |
| --- | --- | --- | --- |
| 1 | `sim/adopted_ground.gd` → `AdoptedGround.Biomes extends BiomeField` | overrode `axes_at`, `moisture_at`, `marsh_strength_at`, `weights_at` so the retired biome field answered from `Helper.biome_*` | **rebuilt here** |
| 2 | `sim/adopted_ground.gd` → `AdoptedGround.Surface extends SimTerrainSurfaceField` | overrode `height_at`, `hill_height_at`, and answered `0.0` for the whole uplift decomposition | **rebuilt here** |
| 3 | `sim/adopted_ground.gd` → `AdoptedGround.Water extends SimWaterField` | overrode `sample_column`, `is_water_at`, `table_level_at` | **rebuilt here** |
| 4 | `sim/terrain_query.gd` → `TerrainQuery.for_seed` | built the three adapters and handed them to the layers above | **rebuilt here** |
| 5 | `sim/terrain_query.gd` → `TerrainQuery.for_seed_legacy` | the named switch that kept the whole retired stack constructible | **deleted** |
| 6 | `sim/terrain_query.gd` → members `surface_field`, `biome_field`, `water_field` | typed against the retired classes, so every reader of the query was typed against them too | **rebuilt here** (one `ground: AdoptedGround`) |
| 7 | `sim/island_field.gd` → `IslandField.water`, `.biomes` | typed `SimWaterField` / `BiomeField` | **rebuilt here** |
| 8 | `sim/settlement_field.gd` → `SettlementField.water`, `.biomes` | same | **rebuilt here** |
| 9 | `sim/path_network.gd` → `PathNetwork.water` | same | **rebuilt here** |
| 10 | `sim/world.gd` → `SimWorld.surface_field`, `.biome_field` | same, re-exported to the render shell | **rebuilt here** (one `ground`) |
| 11 | `sim/decoration_scatter.gd`, `sim/simulation.gd` | read `terrain.water_field.*` / `world.biome_field.*` | **rebuilt here** (retyped) |
| 12 | `AdoptedGround.weights` | folds their seven biome names onto this project's five | **decided**, see §4; the roster change is filed as its own item |
| 13 | `sim/biome_catalog.gd`, `sim/biome_profile.gd` (`SimBiomeProfile`) | — | **additive**: see §3 |
| 14 | `sim/terrain_chunk_mesher.gd` (`SimTerrainChunkMesher`), `sim/terrain_streamer.gd`, `sim/terrain_chunk_geometry.gd`, `sim/water_sheet*.gd` | — | **scheduled** as `W-adopt-render-seam`: see §3 |
| 15 | `sim/value_noise.gd` (`ValueNoise`) | — | **additive**: the floating-island layer's own noise. `ridged_sample` was used by nothing but the deleted mountain field and went with it. |
| 16 | `render/distant_ground.gd`, `render/grass_layer.gd`, `render/main.gd` | read the ground through the query's retired-typed members | **rebuilt here** (retyped only; the render seam itself is `W-adopt-render-seam`) |
| 17 | `bin/island_bench.gd`, `tools/critic_items_probe.gd`, `tools/measure_shore.gd`, `tools/measure_roads.gd`, `tools/road_profile_dump.gd`, `tools/measure_overlay.gd`, `tools/measure_grass.gd`, `tools/grass_mask_map.gd`, `tools/_probe_density.gd`, `tools/survey_island_grass.gd` | constructed or read the retired stack | **rebuilt here** |
| 18 | `tools/measure_mountains.gd` | its `uplift` report read the retired decomposition | **rebuilt here**: that one report is gone, relief / windows / climb / faces / biome heights stay |

Nothing else in the tree bridged the two. The check is a grep for the four
retired class names, which now returns only the prose in this file:

    $ grep -rn "BiomeField\|SimTerrainSurfaceField\|SimWaterField\|MountainField" \
        --include=*.gd . | grep -v "^./scripts/"

## 2. What the rebuilt ground is

`sim/adopted_ground.gd` is one class, `AdoptedGround`, with no inner classes and
no inheritance from anything retired. It owns, per seed:

* their `WaterPlan` — where rivers run and ponds stand;
* their `HeightfieldPlan` with the water wired in (the carved ground) and a
  second without it (the uncarved ground);
* two `WorldFieldBlockCache`es binding those plans to O(1) region and water
  lookups.

Every answer is one of the base's own calls on those objects:

| Question | Answered by |
| --- | --- |
| how high the carved ground is | `TerrainSurfaceField.surface_y(fields.region_at(p), x, z)` |
| how high the uncarved ground is | the same over `base_fields` |
| whether a position is wet | `WaterFieldContext.is_wet(point)` |
| how high the water stands | `WaterFieldContext.level_at(point)` |
| the biome mix | `Helper.biome_weights5(Vector3(x, 0, z), seed)` |
| the three style axes | `Helper.biome_forest01 / biome_rocky01 / biome_moisture01` |

Three things the sim needs and the base has no name for are implemented here
against those fields rather than inherited from the classes that used to carry
them:

* **The column.** The sim reads the ground as two ordered surfaces, bed and
  water surface, wet exactly when the second is above the first. On dry ground
  the base has no water surface at all, so the dry column sinks its surface
  `DRY_DROP = 0.5` below the bed — the adopted stack's own
  `WaterField.SHORE_DRY_DEPTH`.
* **The bank.** Dry here, wet within `BANK_REACH = 2.0` in one of eight
  directions. The base *does* have a shore distance
  (`WaterFieldContext.shore_distance_at`), but reaching it obliges every block
  cache to carry a shore-contour limit, which is a streaming cost paid on every
  block for an answer four layers want at a handful of positions. So this stays
  what it has always been in this project.
* **Standing versus running water.** The old field had a water table to compare
  a level against; the adopted stack has hydrostatic fill instead, flat over
  standing water and falling with the ground along a river. So "still" is
  measured: probe the level `STANDING_PROBE = 9.0` out in four directions and
  see whether it holds to within `STANDING_EPS = 0.01`. (Unchanged from the
  cycle-3726 seam, which is what the item's boundaries asked for.)

`TerrainQuery` now holds one `ground` member instead of three field members,
and `IslandField`, `SettlementField` and `PathNetwork` take the ground rather
than a water field and a biome field. Nothing about what those layers *do*
changed — only which type they read the ground through, which is exactly the
boundary the item drew.

## 3. What could not go, and why

Four `Sim`-prefixed class names exist in this tree because the import hit four
`class_name` collisions with the base. Two of them went with the retired stack:

* `SimWaterField` (`sim/water_field.gd`) — **deleted**
* `SimTerrainSurfaceField` (`sim/terrain_surface_field.gd`) — **deleted**

The other two stay, and here is why:

* **`SimBiomeProfile` (`sim/biome_profile.gd`) stays.** It is not a duplicate
  of the base's `BiomeProfile` in anything but its name. The base's is a
  `Resource` carrying `foliage_tints` and a particle recipe table; this one is a
  plain `RefCounted` carrying `tree_tint`, `rock_tint` and a `prop_tags` list,
  which is what this project's scatter catalog, item model and board legend read
  and what the base's profile does not have. It is not translating between two
  regimes; it is this project's own record of what a biome looks like, and the
  layer check forbids the simulation to hold a `Resource` at all. Renaming it
  would be churn with nothing behind it.
* **`SimTerrainChunkMesher` (`sim/terrain_chunk_mesher.gd`) stays, for now.**
  It turns `TerrainQuery` into plain per-chunk geometry for this project's own
  streamer and fingerprint. Whether the base's `TerrainChunkMesher` and its
  streaming replace it is the render seam's question, not the ground's, and it
  already has an item: `W-adopt-render-seam`. It reads the ground only through
  `TerrainQuery`, so it bridges nothing.

`sim/biome_catalog.gd` and `sim/value_noise.gd` are additive for the same kind
of reason: the catalog is this project's palette and prop-tag table, and the
noise is the floating-island layer's own primitive. Neither has a counterpart
in the base and neither translates between the two.

## 4. The biome vocabulary: five names, decided rather than defaulted

The base has seven biomes (`Helper.BIOME_NAMES`): `meadow`, `deep_forest`,
`highland`, `blossom_grove`, `twilight_marsh`, `amber_heath`, `jade_wetlands`.
This project has five, and five of theirs are ours name for name. The two
extras fold into `meadow`.

**That fold is kept, and here is the reasoning rather than the inheritance.**
`amber_heath` is open warm ground and `jade_wetlands` is common lush lowland;
both are open, walkable, unremarkable country, which is what `meadow` is here.
The alternative worth considering was folding `jade_wetlands` into
`twilight_marsh` on the grounds that both are wet. It was rejected: in
`Helper.biome_weights5` the marsh pocket is `smoothstep(0.74, 0.96, ...)` of a
750-unit field — rare by construction, which is what the design asks of it —
while `jade_wetlands` is `smoothstep(0.64, 0.88, moisture)` of what the pockets
leave, which is not rare. Folding it into the marsh would have put marsh fog,
marsh foliage density and marsh prop tags over a large share of the world and
destroyed the rare-eerie-hollow the marsh is for.

**Adopting all seven is its own item, not this one.** The item's second stop
condition asks exactly this, and the answer is that the roster reaches well
past the ground: `render/asset_sheet.gd`, `render/grass_layer.gd`,
`render/item_sheet.gd`, `sim/scatter_catalog.gd`, `sim/item_model.gd`,
`sim/island_cover.gd` and the asset-tag suites all key on the five names, and
two new biomes would each need a palette, a fog, a foliage density and a prop
tag set before anything could be drawn in one. So the decision recorded here is
"five for now, on the reasoning above", and the roster change is filed
separately.

## 5. What the sim answers, before and after

The sweep is `tools/terrain_seam_probe.gd`: for every combat cell in a square
around a centre it prints the cell's elevation, the surface it supports, whether
it is a hole, whether it is water, how deep, whether it is a bank, its biome and
whether it is passable — the adopted fields sampled at the cell's centre through
`TerrainQuery`, which is the same call chain the combat board builder uses.

    $ tools/godot/godot4 --headless --path . -s res://tools/terrain_seam_probe.gd \
        -- --seed 1234 --centre-x 0 --centre-z 0 --cells 24
    $ tools/godot/godot4 --headless --path . -s res://tools/terrain_seam_probe.gd \
        -- --seed 1234 --centre-x 84.5 --centre-z 294 --cells 24

Two windows, because the origin window of seed 1234 is entirely dry and would
say nothing about the water, bank and hole columns. The second is the lakeside
window the cycle-3726 seam sited its encounter on.

| Window | Cells | Before (HEAD `29fd00ac`) | After (`03f2202e`) | Differing lines |
| --- | --- | --- | --- | --- |
| origin `(0, 0)` | 576 | `163a7495018510db` | `163a7495018510db` | 0 |
| lakeside `(84.5, 294)` | 576 | `10c837b2c5152091` | `10c837b2c5152091` | 0 |

`diff` over the full 576-line output is empty in both cases, not merely the
digests. The second window is the one that exercises the rebuilt water
arithmetic: 152 of its 576 cells are water, all 152 read as holes in the board,
and 29 more are banks.

There is therefore nothing to explain: the rebuild moved no answer. That is the
expected result and the reason it is worth stating — the three adapter classes
never changed an answer either, they only stood in the way, so removing them
should be invisible from above and is.

**The world fingerprint did not move.** `SimWorld.digest()` folds the seed, the
tick, the observer's position and storey, the biome and profile digest under it,
the water state, and every loaded chunk's, island's and village's own digest, in
sorted key order. At tick 3 of seed 1234:

    $ ./run_headless.sh --seed 1234 --ticks 3
    done ticks=3 chunks=32 built=32 final=fbc08ae26a275337

`fbc08ae26a275337` before the rebuild and after it.

## 6. Determinism

Each window was swept in two separate engine processes and the whole output
compared byte for byte:

| Window | Process A | Process B | Differing lines |
| --- | --- | --- | --- |
| origin | `163a7495018510db` | `163a7495018510db` | 0 |
| lakeside | `10c837b2c5152091` | `10c837b2c5152091` | 0 |

## 7. The suites

See §8 below for the run and its verdicts.

Two suites changed shape rather than expectation:

* **`tests/test_mountains.gd`** loses four of its seven checks:
  `_ridged_sample_is_the_folded_field`, `_the_uplift_is_a_pure_function`,
  `_the_mask_is_exactly_zero_outside_a_range` and `_the_uplift_is_regional`.
  All four were about the retired `MountainField` and about
  `SimTerrainSurfaceField`'s decomposition of its own height into hills plus
  uplift. The adopted heightfield has no such decomposition — its ridged relief
  *is* the ground — so those four had nothing left to be about and went with the
  layer they documented. The three that assert something about the *world* are
  kept: rocky country stands high (re-pointed from the uplift to the ground's
  own uncarved height, because a height has a datum and an uplift did not), a
  summit can be climbed, and a road is never laid on ground nobody could walk
  up.
* **`tests/test_settlements.gd`**'s water invariant used to build a second,
  bare copy of the retired water field to compare the composed query against.
  It now compares against `AdoptedGround` itself — the same object the query
  reads through — which makes "the settlement layer never creates or destroys
  water" a statement about the layer rather than about two generators agreeing.

No suite was deleted: none of them tested *only* the deleted generation stack.
Every other touched suite is re-pointed at the rebuilt types and asserts exactly
what it asserted before.

## 8. Verdicts

*(filled in by the suite run; see the table below.)*
