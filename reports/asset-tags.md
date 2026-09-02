# Asset tags: generation names tags, never asset paths

World generation now names **tags** — `fir`, `boulder`, `bridge_wood`,
`lantern_post` — and one table in the render layer turns a tag into a visual.
Generation names no scene, no path and no pack, and an automated check fails the
build if it ever starts to.

![Every tag in the catalog, built from the mapping table](assets/asset-tag-sheet.png)

## What the split is

| Layer | File | Holds |
| --- | --- | --- |
| simulation | `sim/asset_tags.gd` | the vocabulary: 58 tag names in 8 categories, and nothing else |
| render | `render/asset_visual.gd` | what one row *is*: a scene path, or placeholder parts |
| render | `render/asset_library.gd` | the mapping table: one row per tag |

The biome catalog already names tags from the vocabulary (`sim/biome_catalog.gd`
now says `AssetTags.FIR` where it used to say `"fir"` — the same string, so the
world fingerprint is untouched). The settlement, path and scatter layers will
name the rest; every tag those layers need is already in the catalog:

| Category | Tags |
| --- | --- |
| `flora` | `grass` `flower` `fern` `bush` `hardy_shrub` `reed` `cattail` `lily_pad` `mushroom` `toadstool` `petal_drift` `fir` `canopy_tree` `blossom_tree` `dead_tree` `fallen_log` |
| `rocks` | `pebble` `gravel` `boulder` `rock_spire` `stone_henge` |
| `props` | `fence` `cart` `signpost` `barrel` `crate` `market_stall` `water_wheel` `crafting_bench` |
| `buildings` | `house` `cottage` `tavern` `workshop` `tower` `well` |
| `bridges` | `bridge_wood` `bridge_stone` `rope_ladder` |
| `lanterns` | `lantern_post` `hanging_lantern` `campfire` `glowing_orb` `window_glow` |

Each row is a scene path first and placeholder primitives second. Every path is
empty today, because the bought packs are not on this machine, so every tag
draws primitives — the image above is the whole table, built and photographed by
`./run_asset_sheet.sh`.

## The palette did not move

A placeholder part either keeps its own colour (a trunk is brown everywhere) or
carries a tint role — `tree`, `rock`, `ground`, `water` — and takes that colour
from the blended biome profile where it stands. The same `fir` is bright green
in the meadow and deep green under canopy; the table knows neither colour. The
palette stays in `sim/biome_catalog.gd`, exactly as it already does for the
ground.

## Repointing costs one line

`tools/repoint_tag_demo.sh` points the `well` tag at an installed model on disk
and measures what else moved:

```
=== before ===
  well resolves to placeholder cylinder:rock+box+box+prism h=2.95
  sim/ sources     91670a58655ee3fcffb235b91619ac819ef3fe5881e65876ad4f9836d8778d24
  world            f7d01c97ab426fa4

=== repointing 'well' at res://assets/example_well.tscn ===
  -	_row(rows, AssetTags.WELL, "", [
  +	_row(rows, AssetTags.WELL, "res://assets/example_well.tscn", [

=== after ===
  well resolves to scene res://assets/example_well.tscn
  sim/ sources     91670a58655ee3fcffb235b91619ac819ef3fe5881e65876ad4f9836d8778d24
  world            f7d01c97ab426fa4

OK    'well' now resolves to a different visual
OK    every file under sim/ is unchanged
OK    the headless world fingerprint is unchanged
OK    the whole edit is 1 line(s) in render/asset_library.gd
OK    the table is back as it was
```

Full output: [`asset-tag-repoint-evidence.txt`](asset-tag-repoint-evidence.txt).

`assets/example_well.tscn` is a hand-made scene sitting exactly where a pack
model will sit, so the scene half of the table is a path that really loads
rather than a promise.

## What is enforced

`./run_tests.sh --layers-only` now runs two checks, and both must pass:

```
layer check: OK -- res://sim references nothing in the render layer
asset check: OK -- res://sim names asset tags and no asset
```

The asset check (`tests/asset_check.gd`) looks for two different things in two
different places. Paths and file extensions are looked for **inside string
literals only** — that is the only place a path can be, and looking in code as
well would flag `BiomeCatalog.blend()` as a Blender file. Loaders (`preload`,
`load`, `ResourceLoader`, `PackedScene`, `instantiate`, `AssetLibrary`) and pack
names (`kaykit`, `mistage`, …) are looked for **in code**, as whole words, so
`load_radius` is fine and `load(path)` is not. Comments are stripped, so prose
may discuss any of it.

The suite exercises the checker on nine offending lines and eight innocent ones
that exist nowhere on disk, because a check that can never fail is worth
nothing.

## Headless loads none of it

```
$ ./run_headless.sh --seed 1234 --ticks 100 --assets
...
assets visual-files found=3 loaded=0
assets render-scripts found=4 loaded=0
assets sim-scripts found=20 loaded=20 -> res://sim/water_sheet_builder.gd,+16 more
```

The probe walks the project for every file that only exists to be looked at and
asks the engine's own resource cache which of them the process has loaded. It is
asked from outside the render layer on purpose: a counter kept by the asset
table could only be read by loading the asset table, which is the very thing
that must not happen. The third line is the control — without it, two zeros
would be indistinguishable from a probe that never worked. The test suite runs
this as a subprocess and fails on any of the four claims.

## Fingerprints

Unchanged by this task, which is the point: naming a tag through a constant
rather than a literal is the same string, and the render layer's table is not
something generation can see.

| Run | Before | After |
| --- | --- | --- |
| `--seed 1234 --ticks 100` | `f7d01c97ab426fa4` | `f7d01c97ab426fa4` |
| `--seed 7 --ticks 50` | `8455942278ae42ba` | `8455942278ae42ba` |

All ten suites pass headless: 13990 checks, up from 13132.

## Left open

The packs themselves. Section 9.10 of the design calls KayKit "the stylized base
already in the project"; it is not on this machine, and neither is the
reference-image folder. Until they arrive, every row is a placeholder and the
drop-in procedure in the README's *Asset tags* section is the plan rather than a
thing that has been done.

**Since closed.** The packs arrived and the rows were filled in, three times.
Eight free KayKit packs took 34 of the rows —
[reports/asset-packs.md](asset-packs.md) — the JustCreate village pack the user
bought took 20 more, which is every building, most props, both lanterns, the
campfire and five flora rows:
[reports/justcreate-village.md](justcreate-village.md) — and the two Daniel
Mistage packs then took the hero geometry back off four of those and gave
`window_glow` its first model: [reports/mistage-packs.md](mistage-packs.md).
Fifty-four of the fifty-eight tags now name a scene; the contact sheet at the top of
this page is the JustCreate table, one round behind. Each repoint cost exactly
what this report predicted — one line in one file, no file under `sim/` moved,
and the same headless world fingerprint either side.

| tag | pack | why |
| --- | --- | --- |
| `house` `tavern` `workshop` | Mistage village | timber-framed townhouses with lit windows the pack draws itself |
| `market_stall` | Mistage market | a stall and its vendor goods in one model |
| `window_glow` | Mistage village | the pack's own glow-window material and pane |
| `cottage` `tower` `well`, most props | JustCreate village | see [mistage-packs.md](mistage-packs.md) for the three numbers that kept the cottage here |
| flora, rocks, bridges | KayKit | 2–10x cheaper for the same job at the sizes those are scattered at |
