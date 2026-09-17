# The delta import, rehearsed against an oracle

ADOPTION.md's section "Taking an upstream update: the delta import" is the
procedure. This file is its proof.

The procedure had never been run: the base was adopted at `f3203d96` and
upstream has not moved since, so the first real import would also have been the
first test of it. That is the wrong order. So it was rehearsed on history
instead, where the answer is already known — take an upstream commit *before*
the pin, pretend the adoption had imported that one, apply the delta up to the
pin by the procedure, and compare against the adopted tree this repository
actually holds.

    $ ./tools/upstream_delta_rehearsal.sh --back 9 --out <a scratch dir outside this checkout>

Everything below is that run. It took **41.9 s** wall clock and wrote 1.5 GB
into the work directory; it changed nothing in this checkout, and the source
repository was cloned read-only and never written to. With no `--out` the
script makes its own temporary directory, which is the ordinary way to run it;
a path was named here only so the numbers below could be measured afterwards.

## The pin did not move, and was not moved

    $ ./tools/upstream_watch.sh
    upstream-watch: base is CURRENT -- ADOPTION.md pin f3203d96 == upstream HEAD f3203d96 (https://github.com/Acciorocketships/mythosunwritten)
    $ echo $?
    0

Upstream HEAD is still exactly the pin, so nothing was owed and the two
Provenance lines in ADOPTION.md are untouched. The rehearsal is about a
*historical* range and advances nothing.

## The range, and why this one

`--back N` is `pin~N`, and `~` walks **first parents**. Upstream merges its own
branches, so `pin~N` is not "N commits ago": a range that crosses a merge holds
more commits, and far more changed paths, than the number suggests. The script
therefore prints the commit it resolved and the true commit count rather than
letting the flag stand for either:

      --back 9 resolves to d225c722; the range holds 16 upstream commit(s) (first-parent walk, so a merge in range widens it)

The candidates, measured in the same blobless clone:

| Range | Old commit | Commits in range | Changed paths |
| --- | --- | --- | --- |
| `pin~1` | `2b296430` | 1 | 4 |
| `pin~2` | `50ea00cb` | 8 | 4 |
| `pin~3` (the script's default) | `01a6e1b4` | 9 | 9,198 |
| `pin~5` | `7648599b` | 12 | 9,209 |
| **`pin~9`** (used here) | **`d225c722`** | **16** | **10,547** |

`pin~1` and `pin~2` were rejected for being too easy, not too hard: they change
four paths, all documentation (`AGENTS.md` and three QA files), and would have
exercised none of the three collision resolutions. `pin~9` was chosen because it
is the largest range available and the only one that exercises every part of the
procedure: it modifies `project.godot`, `.gitignore` and `tests/test_biomes.gd`,
all four of the renamed classes, and every adopted script this project's own
code calls into.

This is not a reduced case. At 10,547 changed paths against the 12,376 upstream
tracks at the pin, **85% of the whole base changes at once** — a real delta
cannot be much bigger than this one, so the costs below are full-size costs, not
a sample scaled up.

| | |
| --- | --- |
| blobless clone of upstream (949 commits, trees only) | 1.8 MB, 0.42 s |
| ...against a full history clone | ~189 MB |
| the clone once both trees are checked out (blobs fetched on demand) | 164 MB |
| the two upstream worktrees on disk | 355 MB + 504 MB |
| `delta-apply.patch` (10,544 paths, `--binary`) | 84.3 MB |
| `git apply --check --binary` of it | 1.40 s |
| `git apply --binary` of it | 1.62 s |
| whole rehearsal, clone included | 41.9 s, 1.5 GB |

## What the procedure was given

`tools/upstream_delta.sh` sorted the 10,547 paths without being told anything it
could derive:

    upstream-delta: d225c722..f3203d96, 10547 changed path(s)
      apply mechanically  : 10544  -> git apply --binary .../delta-apply.patch
      dropped as carve-out: 0
      decide by hand      :
          project.godot            re-run tools/upstream_merge_project_godot.py at the new pin
          .gitignore               merge into the adopted block; the raw hunk will not apply
          tests/test_biomes.gd     retargeted to tests/test_mythos_biomes.gd (patch written)
          0 adopted path(s) this repo has rewritten since the import
          7 changed adopted script(s) this project's own code calls into:
              scripts/core/Helper.gd  (Helper used by sim/adopted_ground.gd)
              scripts/core/Helper.gd  (Helper used by tools/adopted_ground_probe.gd)
              scripts/terrain/TerrainWorldTuning.gd  (TerrainWorldTuning used by sim/adopted_ground.gd)
              scripts/terrain/TerrainWorldTuning.gd  (TerrainWorldTuning used by tools/adopted_ground_probe.gd)
              scripts/terrain/field/TerrainSurfaceField.gd  (TerrainSurfaceField used by sim/adopted_ground.gd)
              scripts/terrain/field/TerrainSurfaceField.gd  (TerrainSurfaceField used by tools/adopted_ground_probe.gd)
              scripts/terrain/field/WorldFieldBlockCache.gd  (WorldFieldBlockCache used by sim/adopted_ground.gd)
              scripts/terrain/field/WorldFieldBlockCache.gd  (WorldFieldBlockCache used by tools/adopted_ground_probe.gd)
              scripts/terrain/heightfield/HeightfieldPlan.gd  (HeightfieldPlan used by sim/adopted_ground.gd)
              scripts/terrain/water/WaterField.gd  (WaterField used by sim/adopted_ground.gd)
              scripts/terrain/water/WaterPlan.gd  (WaterPlan used by sim/adopted_ground.gd)

      new global class_name(s) upstream introduces (each a fresh collision risk):
          BiomeAtmosphereField
          BiomeGroundMap
          FabricContinuousRoofPlan
          FabricSurfaceOwnership
          LandformField
          LatticeTerrainSurfaceRegion
          SpiritOrb
          TerrainGradePatch
          TerrainStreamingTelemetry
          VillageFrontageDomain
          VillageOutskirtsConstruction
          VillageWorldScale

None of the twelve is printed with a `COLLIDES with …` marker, which is the
script's way of saying it checked each one against every global this repository
declares in `sim/ net/ render/ bin/ tools/ tests/` and found no clash.

## The starting point, built forward and not backwards

The tempting shortcut is to reverse the delta out of the current tree and then
re-apply it; that proves nothing, because reverse-then-forward is the identity.
So the starting point is built *forward* from upstream at the old commit, by
ADOPTION.md's own import rules, and never consults the pinned tree:

      upstream@f3203d96: 12376 path(s); 12351 adopted byte-identically, 2 merged by hand, 1 renamed, 23 carved out
      repo-as-if-imported-at-d225c722: 3492 upstream file(s) in place, 14 .gitignore rule(s) rolled back

The first line is itself a derivation rather than a claim, and it confirms the
adoption record exactly: of the 12,376 paths upstream holds at the pin, 12,351
sit at the same path in this repository with the same bytes, one (their
`tests/test_biomes.gd`) sits at the renamed path with the same bytes, two
(`project.godot`, `.gitignore`) are the hand-merged files, and 23 are absent —
and every one of those 23 is on ADOPTION.md's exclusion list. The script prints
an `UNEXPLAINED absence:` line if any is not, and printed none. Nothing is
unaccounted for in either direction.

## The result, against the oracle

      the raw .gitignore hunk, applied as-is: refused, as it must -- ours is a merged file, so this is a hand decision
      .gitignore decided by hand: block rebuilt in their order, 3 rule(s) held + 14 added = 17
    rehearsal: comparing against the adopted tree this repo actually holds
      content differences : 0
      extra in the result : 0
      missing from result : 169   (all .uid sidecars: yes)
    rehearsal: REPRODUCED

**Zero files differ in content. Zero extra files appeared.** The whole residue
is 169 missing files, and all 169 are Godot `.uid` sidecars — the small files
Godot writes beside a script to give it a stable resource id:

| Residue | Count | Why the procedure cannot produce it |
| --- | --- | --- |
| `.uid` sidecars for files the delta adds | 169 (164 `.gd`, 4 `.gdshader`, 1 `.gdshaderinc`) | Godot writes them on import; the source repo gitignores them, this repo commits them (ADOPTION.md, "The engine seam"). `godot4 --headless --path . --import` is step 6 of the procedure for exactly this reason. |

Every one of the 169 belongs to a file the delta *adds* — checked, not assumed:

    residual sidecars: 169
    whose owning file is ADDED by the delta: 169
    whose owning file is NOT added by the delta: []

## What the rehearsal caught, and why it was worth running

The first run of this rehearsal did **not** reproduce, and what it caught is the
reason to rehearse at all rather than to trust the procedure at its first real
use:

      content differences : 1
      missing from result : 169   (all .uid sidecars: NO)
    Files repoE/.gitignore and oracle/.gitignore differ

    $ diff repoE/.gitignore oracle/.gitignore
    66d65
    < /renders/
    67a67
    > /renders/

One line, in the wrong place. The `.gitignore` step had been written to splice
upstream's new rules in after a fixed anchor line (`/renders/`). That happens to
be right whenever every new rule belongs *below* the anchor, which is true of
the narrow `pin~3` range and false here: this wider range adds `/artifacts/`,
which upstream keeps *above* `/renders/`.

The anchor was the mistake — an adopted rule can arrive anywhere in the block,
so there is no line to splice after. The rule that has no such assumption is to
rebuild the block instead of patching it: **the adopted block holds the rules
the adoption took from upstream, kept in upstream's own order at the new
commit**, with membership being what the block already held plus what the delta
adds. Nothing is placed at a guessed position, and nothing this repository
handles in its own sections (`.godot/`, `*.uid`, `assets/`, `/addons/`) is
dragged in by the reordering. With that rule both ranges reproduce:

| Range | Changed paths | Result | Residue |
| --- | --- | --- | --- |
| `pin~3` (`01a6e1b4`), 17.4 s | 9,198 | REPRODUCED | 149 `.uid` sidecars |
| `pin~9` (`d225c722`), 41.9 s | 10,547 | REPRODUCED | 169 `.uid` sidecars |

A procedure that is only correct on the easy half of its inputs looks exactly
like a correct one until the day it matters. This is what the oracle bought.

## The carve-outs survived

Present upstream at the pin, absent from the rehearsal's result:

| Carve-out | Upstream at the pin | In the result |
| --- | --- | --- |
| `.superpowers/` | present (17 files) | absent |
| `.cursor/` | present (1 file) | absent |
| `.cursorignore` | present | absent |
| `.vscode/` | present (1 file) | absent |
| `.editorconfig` | present | absent |
| `.gitattributes` | present | absent |
| `icon.svg.import` | present | absent |
| `addons/`, `assets/` | upstream tracks 0 paths under either | nothing adopted into either |

`assets/` deserves the extra word, because the result *does* contain one: this
repository's own CC0 KayKit pack, byte-identical to the oracle's. Upstream
tracks nothing under that path, so the procedure contributed nothing to it and
took nothing away — which is what the carve-out asks for.

## The four renamed classes survived

The adoption renamed this project's own colliding globals with a `Sim` prefix.
The rehearsed delta modifies all four of upstream's declaring files, which is
the case that would break the rename if anything would:

    $ git -C up.git diff --name-only d225c722 f3203d96 -- \
        scripts/terrain/biome/BiomeProfile.gd scripts/terrain/field/TerrainChunkMesher.gd \
        scripts/terrain/field/TerrainSurfaceField.gd scripts/terrain/water/WaterField.gd
    scripts/terrain/biome/BiomeProfile.gd
    scripts/terrain/field/TerrainChunkMesher.gd
    scripts/terrain/field/TerrainSurfaceField.gd
    scripts/terrain/water/WaterField.gd

After the apply, counting `class_name` declarations in `.gd` files only:

| This project's class | Declared at | Upstream's class | Declared at |
| --- | --- | --- | --- |
| `SimBiomeProfile` | `sim/biome_profile.gd` | `BiomeProfile` | `scripts/terrain/biome/BiomeProfile.gd` |
| `SimTerrainChunkMesher` | `sim/terrain_chunk_mesher.gd` | `TerrainChunkMesher` | `scripts/terrain/field/TerrainChunkMesher.gd` |
| `SimTerrainSurfaceField` | `sim/terrain_surface_field.gd` | `TerrainSurfaceField` | `scripts/terrain/field/TerrainSurfaceField.gd` |
| `SimWaterField` | `sim/water_field.gd` | `WaterField` | `scripts/terrain/water/WaterField.gd` |

Each of the eight names is declared exactly once, and no bare name is loose in
`sim/`. Godot's global class table is flat — two files declaring one name is a
hard parse error — so "exactly once each" is the whole of what the rename has to
guarantee, and the delta landed on all four without touching it.

## The hand-merged `project.godot` survived, by rule rather than by luck

`tools/upstream_merge_project_godot.py` is the collision resolution written as a
rule: this repository's whole `project.godot`, then a banner, then exactly five
of upstream's sections verbatim. Run on this repository's pre-adoption
`project.godot` and upstream's at the pin, it reproduces the committed file byte
for byte:

    $ git show faf11f55^:project.godot > ours-pre.godot
    $ python3 tools/upstream_merge_project_godot.py ours-pre.godot <theirs at the pin> f3203d96 > rebuilt
    $ diff <(git show faf11f55:project.godot) rebuilt && echo IDENTICAL
    IDENTICAL

It also printed nothing on stderr, which is the rule saying it recognised every
section upstream has; a section upstream *adds* would be named there rather than
dropped in silence.

That is what makes it safe to re-run at a different commit, which is what the
rehearsal does. The delta adds four shader globals (`biome_ground_a`,
`biome_ground_b`, `biome_ground_color`, `biome_ground_origin`) inside
`[shader_globals]`; the rule carries them over because that section is adopted
wholesale, and the result matched the oracle exactly.

## Where this repository has diverged from the adopted paths

Derived by diffing the adoption commit (`faf11f55`) against `HEAD`, not from
memory:

    $ git diff --name-only faf11f55 HEAD | sort > changed-here
    $ comm -12 <(sort mechanical-paths) changed-here
    (empty)

**No adopted path has been rewritten since the import.** Everything this project
has changed since lives in its own files — `sim/`, `bin/`, `tests/`, `tools/`,
`reports/`, the `run_*.sh` runners, `ADOPTION.md` and `docs/`.

That is the reassuring half of the answer and not the useful half. The place a
real delta will hurt is where this project's own code *calls into* an adopted
script without having edited it — a textual apply succeeds and the behaviour
changes underneath. Derived by matching the global `class_name`s our files name
against the adopted files the delta touches:

| This project's file | Adopted scripts it binds to | Changed by the rehearsed delta |
| --- | --- | --- |
| `sim/adopted_ground.gd` | `HeightfieldPlan`, `Helper`, `TerrainSurfaceField`, `TerrainWorldTuning`, `WaterField`, `WaterFieldContext`, `WaterPlan`, `WorldFieldBlockCache` | 7 of the 8 |
| `tools/adopted_ground_probe.gd` | `Helper`, `TerrainSurfaceField`, `TerrainWorldTuning`, `WorldFieldBlockCache` | all 4 |
| `sim/terrain_query.gd` | reaches the same stack through `AdoptedGround` | — |

`sim/adopted_ground.gd` is the whole seam between this project's discrete board
and their continuous ground, so in practice that one file is the conflict
surface, and everything it names is worth reading in any real delta.

## What the procedure cannot do mechanically

Five kinds, each one an actual event in this rehearsal rather than a worry:

1. **A file this project built on.** `scripts/terrain/TerrainWorldTuning.gd` is
   a file nobody here has edited, so its whole diff applies without a murmur.
   Inside that clean apply:

       -const HEIGHTFIELD_AMPLITUDE := 22.0
       +const HEIGHTFIELD_AMPLITUDE := 32.0
       -static func make_relief(world_seed: int, water: WaterPlan,
       -static func make_heightfield(world_seed: int, water: WaterPlan = null,
       -        relief = null) -> HeightfieldPlan:
       +static func make_heightfield(world_seed: int,
       +        water: WaterPlan = null) -> HeightfieldPlan:

   `sim/adopted_ground.gd` calls `TerrainWorldTuning.make_heightfield()` and
   `make_water()` for every world this project generates. The retuned constant
   reshapes all of them — heights, water levels, and the measured costs and
   cache fingerprints recorded against them — and nothing in the apply notices.
   The dropped third parameter is the sharper warning: our two call sites pass
   one and two arguments and so happen to survive, but that is arity luck, and
   `make_relief` disappeared from the API entirely (this project has no call
   site for it — checked, not assumed). This is why the classification lists the
   binding files separately, and why the suites are step 6 and not an
   afterthought.

2. **A class this project renamed.** Upstream's `WaterField`, `BiomeProfile`,
   `TerrainSurfaceField` and `TerrainChunkMesher` are all modified by this
   delta, and this repository's four same-named classes are `Sim`-prefixed
   precisely so those modifications can land untouched. That worked here — but
   only because the rename is on *our* side. Had upstream renamed one of its
   own, the patch would have arrived as a delete plus an add, and which of the
   two global names then survives is a decision.

3. **A merged configuration file.** `git apply` on upstream's `.gitignore` hunk
   is refused outright:

       error: patch failed: .gitignore:12
       error: .gitignore: patch does not apply

   because theirs lives here as a labelled block inside a much longer file of
   ours, so the hunk's context does not exist. The 14 new rules had to be placed
   by hand — and, as the section above records, placing them *correctly* needed
   a second attempt, because the obvious mechanical stand-in for the hand
   decision (splice after a known line) was wrong. `project.godot` is the same
   problem solved the other way: it has a rule, so it is re-merged rather than
   patched.

4. **A new global name.** The delta introduces twelve. None collides with this
   project's globals, so all twelve applied — but that is an outcome of the
   check, not a property of the procedure. Godot's global class table is flat
   and a collision is a hard parse error, so this has to be asked every time.

5. **Anything the engine generates.** The 169 `.uid` sidecars. A patch carries
   files, not the engine's import step.

## Re-running it

    $ ./tools/upstream_delta_rehearsal.sh              # pin~3, into a temp dir
    $ ./tools/upstream_delta_rehearsal.sh --back 9     # the wider range recorded above

Exit 0 means the adopted tree was reproduced up to the residue it printed;
exit 1 lists what did not match. Both are the whole cost in the table above —
under a minute, and nothing written outside the work directory.
