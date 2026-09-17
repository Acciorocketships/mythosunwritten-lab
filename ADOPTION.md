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

The two lines above are the only full statement of the pin in this repository:
`tools/upstream_watch.sh` reads both of them rather than carrying its own copy,
and `tools/upstream_watch.sh --pins` audits the tree for a second one. Editing
the pin here is therefore the whole of advancing it.

## Is the pin still upstream's HEAD?

Upstream keeps developing, so the pin is a moving target. Ask:

    $ ./tools/upstream_watch.sh
    upstream-watch: base is CURRENT -- ADOPTION.md pin f3203d96 == upstream HEAD f3203d96 (https://github.com/Acciorocketships/mythosunwritten)

About a quarter of a second, no clone, exit 0 when current, 3 when upstream has
moved (the new HEAD is printed) and 2 when it could not ask at all — it never
reports "current" without an answer from upstream. It runs on a ten-cycle probe
cadence, and a move obliges a finding in the planning inbox rather than an
in-passing fix. See [docs/upstream-watch.md](docs/upstream-watch.md).

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

## Taking an upstream update: the delta import

Because the import was a squash copy and not a merge, the two repositories
share no ancestor, and `git merge` has nothing to merge — there is no common
commit for it to diff against. The equivalent of "merge upstream in" here is:
take the delta between the pinned commit and upstream's new HEAD, apply it to
the paths this repository adopted, decide by hand the places where this project
has since built on one of them, and then move the pin. The procedure below is
that, written out; `tools/upstream_delta.sh` performs its mechanical half, and
`tools/upstream_delta_rehearsal.sh` proves it against a delta whose answer is
already known. The full rehearsal transcript is
[docs/upstream-delta-import.md](docs/upstream-delta-import.md).

**1. Establish that upstream has actually moved.**

    $ ./tools/upstream_watch.sh
    upstream-watch: upstream has MOVED -- ...      # exit 3, and it prints the new HEAD

Exit 0 means there is nothing to import and the rest of this section does not
run. The pin is advanced only against a real move (step 6).

**2. Produce the delta, sorted into what may be applied and what may not.**

    $ ./tools/upstream_delta.sh --out ../delta-work

It reads the pin and the URL out of the Provenance section above, clones the
source repo blobless and read-only (`--filter=blob:none`, about 2 MB of commits
and trees against ~189 MB for a full history), checks out the two trees, and
writes four things next to a printed classification:

| File | What it holds |
| --- | --- |
| `delta-apply.patch` | every changed adopted path that may be applied as-is |
| `delta-rename.patch` | the one path the import renamed, already retargeted |
| `decide-project.godot.patch` | for reference; this file is re-merged, not patched |
| `decide-gitignore.patch` | for reference; this file is merged by hand |

Nothing in the work directory touches this checkout.

**3. Drop the carve-outs.** Every path in the table under "What was
deliberately left out" stays out. The script excludes them from the patch by
pathspec; if that list and the table below ever disagree, the table is right
and the script is wrong.

**4. Apply the mechanical half.**

    $ git apply --check --binary ../delta-work/delta-apply.patch   # refuse to guess
    $ git apply --binary ../delta-work/delta-apply.patch
    $ git apply --binary ../delta-work/delta-rename.patch

`--check` first, always: a hunk that does not apply is a file this project has
edited since the import, which is a decision and not a failure to route around.

**5. Decide the rest by hand.** The classification names four kinds:

- **`project.godot`** — re-run the merge instead of patching it:
  `python3 tools/upstream_merge_project_godot.py <this repo's pre-adoption
  project.godot> <their project.godot at the new commit> <new short hash>`.
  That script *is* the collision resolution recorded below, written as a rule,
  and it warns on any section of theirs the rule does not cover.
- **`.gitignore`** — theirs lives in this repo as a labelled block inside a
  much longer file of ours, so their hunk has no context to apply against and
  `git apply` refuses it. Rebuild the block rather than splicing into it: it
  holds the rules the adoption took from them, **kept in their order at the new
  commit**, its membership being what the block already held plus what the
  delta adds. There is no line to add new rules *after* — a rule they add may
  belong above the ones already there, and the rehearsal caught exactly that.
- **Adopted paths this repository has rewritten since the import** — the script
  derives this list by diffing the adoption commit against `HEAD`; do not
  recall it. Rebuild on their new version rather than re-applying ours over it
  (the standing direction: start from their code, do not write adapters).
- **Adopted scripts this project's own code calls into** — derived the same
  way, by matching the global `class_name`s our files name against the adopted
  files the delta changes. These apply cleanly and are still decisions: a
  constant they retune changes every world we generate from it.

Any global `class_name` the delta *introduces* is a fresh collision risk
against this repository's own globals; the script lists them and says which
collide. A collision is resolved on our side, as the four below were.

**6. Re-import, re-run, and only then advance the pin.**

    $ ./tools/godot/godot4 --headless --path . --import   # new scripts have no .uid yet
    $ ./run_tests.sh                                      # hours; see README

Then edit the two Provenance lines at the top of this file to the new hash and
date — that edit *is* advancing the pin, because nothing else in the tree holds
a copy — and confirm it:

    $ ./tools/upstream_watch.sh          # exit 0, base is current again
    $ ./tools/upstream_watch.sh --pins   # no second copy of the new hash appeared

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
