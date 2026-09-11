# Adoption of mythosunwritten as this project's base

This repository adopted the user's own further-along implementation of the same
game — its streamed continuous-heightfield terrain, rivers and shader water,
procedural villages, biomes/atmosphere, and character controller — as the base
this project's simulation, model-driven characters, board combat and interface
layers are being ported onto. The user's direction (2026-09-11): "adopt that
game as a base, and merge/rebase the additional features you built on top of
it… only edit the code in this repo."

## Provenance

- Source: https://github.com/Acciorocketships/mythosunwritten
- Source commit: `f3203d96d1a7612059162d16487d29ab6f0c4944`
  ("Record branch consolidation, cleanup and complete regression baseline",
  2026-09-10)
- The source repository was read only; nothing there was changed.

## Import method: squash import of the pinned commit

The tree at `f3203d96` was copied in as ordinary files in one adoption commit,
rather than merged with `git merge --allow-unrelated-histories`. Reasons:

- The histories are unrelated, so a merge buys no ancestry — only a second
  root. Their full history is ~189 MB of pack data and thousands of commits
  (the source repo's own consolidation doc records 4,488 changed paths on one
  branch alone); carrying it would roughly double this repo's object store and
  interleave two unrelated logs forever.
- The source commit is pinned here by hash and URL, so any file's history is
  one `git log` away *in the source repo*, which remains intact.
- The source repo's own `docs/branch-consolidation-2026-09-10.md` already
  performed its history consolidation and archived its branches; this import
  inherits that consolidated state, not the branch churn behind it.

## What was deliberately left out

| Left out | Size | Why |
| --- | --- | --- |
| Their git history (`.git`) | ~189 MB | Squash import; pinned by hash above. |
| `assets/` (KayKitAdventurers pack etc.) | not in their repo either | Gitignored upstream — their own clones supply it locally. 25 of their files reference `res://assets/KayKitAdventurers/...` (character/weapon models); this repo carries the same CC0 pack at `assets/kaykit_adventurers/` (fetched by `tools/fetch_kaykit.sh`), and reconciling the two paths belongs to the render-seam work. Terrain generation does not need it. |
| `addons/` (GUT) | not in their repo either | Gitignored upstream. Their 154-script/1,195-test GUT suite (`tests/gutconfig.json`, `extends GutTest`) cannot run until GUT is installed; the suite-certification item decides how. |
| `.superpowers/` | 132 KB | Their local agent-workflow scaffolding, not game content. |
| `.cursor/`, `.cursorignore` | 64 KB | Editor scaffolding; collides with this repo's ignored local `.cursor/` scratch. |
| `.vscode/`, `.editorconfig`, `.gitattributes` | < 10 KB | Editor/VCS config that would govern this whole tree; this repo keeps its own. |
| Their `.gitignore` | — | Merged into this repo's `.gitignore` (see the adopted block there) instead of replacing it. |
| `icon.svg.import` | 1 KB | This repo ignores `*.import` (regenerated). |

Everything else was imported at its original path: `scripts/`, `terrain/`,
`characters/`, `scenes/`, `ui/`, `items/`, `docs/`, `AGENTS.md`,
`export_presets.cfg`, `icon.svg`, `logo.png`, `review_teleports.json`,
`biome_review_teleports.json`, and their `tests/` and `tools/` contents merged
into this repo's directories of the same names.

## Collision resolutions (nothing this project built moved)

The tracked-path intersection of the two repos was exactly three files:

- `project.godot` — hand-merged. This repo's `[application]` (main scene
  `res://render/main.tscn`, features `"4.7"`) and `[rendering]` (AA, canvas
  filter) kept; their `[debug]`, `[filesystem]`, `[input]`, `[physics]`
  (gravity 18) and `[shader_globals]` adopted verbatim. Their `[display]`
  window size was not adopted (this repo's pixel-interface measurements are
  taken against the default window). Nothing in `sim/`, `net/`, `render/`
  reads gravity or uses `CharacterBody3D`, so gravity 18 only affects their
  controller.
- `.gitignore` — theirs merged into ours as a labelled block.
- `tests/test_biomes.gd` — both repos had one. Ours stays (it is preloaded by
  name in `bin/test_main.gd` and named by suite runners); theirs was imported
  as `tests/test_mythos_biomes.gd`. GUT discovers tests by the `test_` prefix,
  so the rename does not hide it from their harness; their own docs mention
  `test_biomes` only in narrative history.

Four global `class_name`s collided (`BiomeProfile`, `TerrainChunkMesher`,
`TerrainSurfaceField`, `WaterField` — this repo's own from-scratch terrain in
`sim/`, against their much larger terrain stack). Ours were renamed with a
`Sim` prefix (`SimBiomeProfile`, `SimTerrainChunkMesher`,
`SimTerrainSurfaceField`, `SimWaterField`) — 207 occurrences across 50 of our
files — because their side has 538 scripts and this repo's terrain is the half
being superseded. File paths did not change.

This project's `sim/`, `net/`, `render/`, `bin/`, `feature_profiles/`, the
`tests/` suites, the `tools/` probes and every `run_*.sh` runner (including
`./run_tests.sh`) survive at their old paths.

## The engine seam

The source repo is a Godot 4.5 project; this repo runs Godot 4.7.2
(`tools/godot/godot4`). The merged `project.godot` declares `"4.7"` and both
halves load under it — see the headless world-generation run and suite runs
recorded in the adoption work result. Known, inherited consequences:

- Their `.tscn` files reference scripts by `uid://…` but the source repo
  gitignored `*.uid` sidecars, so first import regenerates ids and Godot
  resolves those references by path with warnings. Their own docs record these
  as non-fatal ("UID/path resolution warnings… not fatal startup errors").
  The sidecars Godot 4.7 generated are committed here, so ids are stable from
  this commit on.
- Their GUT suite needs `addons/gut/` installed (see above) and its
  `gutconfig.json` scans all of `res://tests/`, which now also holds this
  repo's non-GUT suites; scoping that scan is part of certifying their suite
  from this repo, not of this import.

## Inherited open failures

The source repo's docs are explicit that consolidation "does not resolve the
documented baseline cliff, cold-start, composition and historical-water
failures" (`AGENTS.md`; `docs/branch-consolidation-2026-09-10.md`). Its
recorded baseline (`docs/qa/known-baseline-2026-09-09.json`) is 154 scripts,
1,195 tests: 1,164 passed, 30 failed, 1 pending, and its full-suite runs end
in a `recursive_mutex lock failed` abort (exit 134) after the summary prints.
These are filed as inherited known issues in the planning inbox, not absorbed
silently.
