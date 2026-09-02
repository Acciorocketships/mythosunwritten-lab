# Characters: fourteen new tags, one animation setup, and the end of the ball

The observer used to be drawn as a glowing sphere. It is now a rigged, animated
character that stands still when the world says it is standing still and walks
when the world says it is walking — and the simulation gained not one word about
animation to make that happen.

![The observer walking through a meadow, seed 1234 at tick 40: a KayKit ranger
seen from behind, mid-stride, with the streamed grass, trees and floating
islands around it](assets/observer-character.png)

Three things carry the whole change, and each is small on purpose:

| where | what |
|---|---|
| `sim/asset_tags.gd` | fourteen new tag names in two new categories, `characters` and `creatures`. Strings. No model, no clip, no rig. |
| `render/character_rig.gd` | which skeleton a model wears, and one clip library per skeleton — shared by every model that wears it. |
| `render/character_view.gd` + `render/character.tscn` | one scene owning the animation player, the animation tree and the two hand sockets, with the model as a swappable child, and one pure function turning simulation state into a clip name. |

Everything below is reproducible from the commands it quotes. **The world's
fingerprint did not move**: `./run_headless.sh` gives `a6aa8e5776ebfe8c` at seed
1234 and tick 100, the same value it had before this task. All 20 suites pass
(171,509 checks), and a headless run still loads no visual file and no render
script at all.

---

## 1. A character is a tag, exactly as a fir is

The catalog grew from 44 names in 6 categories to 58 in 8. The two new
categories are people:

| category | tags |
|---|---|
| `characters` | `barbarian` `knight` `mage` `ranger` `rogue` `hooded_rogue` |
| `creatures` | `minion_toadstool` `minion_cat` `minion_ent` `minion_frog` `skeleton_warrior` `skeleton_rogue` `skeleton_mage` `skeleton_minion` |

Two naming choices are worth stating, because both had a plausible alternative.

**The character tags are appearances, not classes.** The design is explicit that
there are no classes — every ability lives on an item (§3.5, §4) — so a tag
named `knight` says which figure is standing there and nothing about what it can
do. That is the same thing a `fir` tag says, and it is the only thing any tag in
this project says.

**`minion_toadstool`, not `toadstool`.** A toadstool growing in the marsh is
flora and has had a tag since the scatter layer was built; a Toadstool holding a
lane is a chess piece. Two different things need two different names, and the
prefix is the cheapest way to say so.

The render table resolves all fourteen on exactly the terms it already used —
one row per tag, a scene path first and a placeholder underneath:

```
$ ./run_assets.sh
[characters]
  barbarian        scene .../Characters/gltf/Barbarian.glb rig Rig_Medium
  knight           scene .../Characters/gltf/Knight.glb rig Rig_Medium
  ...
tags=58 resolved=58 missing=0 unknown-rows=0 dropped-tints=0
```

A row gained one field, `scene_rig` — which skeleton the model is rigged on,
empty for everything that has no bones. It is on the row rather than in a second
table beside it so that a tag still has exactly one row, and so that repointing a
character at a different model cannot leave its animation behind on the old one.

Every row is drawn on the catalog's own contact sheet, in its rest pose, because
`./run_asset_sheet.sh` builds a model and does not animate one:

![Every tag in the catalog laid out in a grid; the last two rows are the six
adventurers and the eight creatures](assets/asset-tag-sheet.png)

### The four minions have no creature model, and that is said out loud

`W-creature-packs` measured this and it has not changed: **no installed pack
holds a toadstool, a cat, an ent or a frog as a creature.** The packs that would
are KayKit's three Mystery Monthly series at \$19.99 each, and nothing was
bought.

So the four rows point at **Board Game Bits**, which the design itself names for
"game-piece minions" (§9.10) and which is free and installed. Each piece is
chosen for the *chess analog* the design gives the minion, not for looking like
the animal:

| minion | analog (§3.3) | row points at | height | what it actually is |
|---|---|---|---:|---|
| Toadstool | pawn | `pawn_A_blue` | 0.915 | the pawn. Literally the piece. |
| Cat | bishop | `pawn_B_blue` | 1.215 | a taller pointed pawn |
| Ent | rook | `building_blue` | 1.000 | the pack's building piece — a little house, the nearest thing it has to a tower |
| Frog | knight | `meeple_blue` | 1.240 | the meeple, the one piece in the pack shaped like a figure |

One colour, because they are one side; the pack ships four, which is what §3.8's
several commanders will want. This is an abstract stand-in and it is meant to be
recognised as one. A test pins it — `_the_minions_are_named_as_uncovered()`
fails if a minion row ever quietly acquires a rig or stops naming a board piece —
so the day a pack does arrive the row and the check move together.

Here they are beside two real enemies, all at world scale, each with a one-unit
post beside it:

![Four board pieces and two rigged skeleton enemies standing in a row on a
common ground plane, each with a one-metre post beside it. The pieces are
roughly a third the height of the skeletons](assets/minions-and-enemy.png)

```
xvfb-run -a ./tools/character_sheet.sh --cell 3.2 \
    --screenshot "$PWD/reports/assets/minions-and-enemy.png" \
    minion_toadstool minion_cat minion_ent minion_frog \
    skeleton_warrior:Idle_A skeleton_minion:Walking_A
```

The size gap in that picture is the useful part: a board piece is about a third
of the 3.0-unit combat cell and about half the height of the enemy standing next
to it, so a minion layer built out of these will need scaling *up*, not down.

---

## 2. The clip is a pure function of the snapshot

This is the load-bearing claim of the whole task, so it is a function with no
arguments but its input, and a test that is shown to fail when the rule breaks.

```gdscript
static func clip_for(state: Dictionary) -> String:
    if not bool(state.get("alive", true)):        return CLIP_DEATH
    if bool(state.get("hurt", false)):            return CLIP_HIT
    if float(state.get("rise", 0.0)) >= HOP_RISE: return CLIP_JUMP
    var speed := float(state.get("speed", 0.0))
    if speed < WALK_SPEED:                        return CLIP_IDLE
    if speed < RUN_SPEED:                         return CLIP_WALK
    return CLIP_RUN
```

No member is read, none is written, nothing outside the argument is consulted.
Feed it the same state in any process at any time and it gives the same answer,
whatever the view drew before. `observer_state(snapshot)` is the only bridge from
the world, and it reads four keys with defaults.

| clip | pack name | reached when |
|---|---|---|
| idle | `Idle_A` | speed below 0.05 units/tick |
| walk | `Walking_A` | speed in [0.05, 1.30) |
| run | `Running_A` | speed at or above 1.30 |
| jump | `Jump_Full_Short` | rise of 0.60 or more in one tick |
| hit | `Hit_A` | the state says it was hurt |
| death | `Death_A` | the state says it is not alive |

The order matters and is itself a rule: a dead character is not running however
fast it was going, and being hit interrupts a walk. Both orderings are checked.

### What the simulation had to gain, and what it did not

Two floats on the world, and nothing else:

- `observer_speed` — how far it went across the ground on the last tick
- `observer_rise` — how far it went up or down, signed

Both are motion, not display. A viewer cannot work them out without remembering
where the observer was last frame, and a viewer that remembers where the world
was is a viewer holding a second copy of the world. So the world says.

Both are deliberately **outside** `digest()`: they are differences of a position
the fingerprint already covers, so folding them in would fold the same fact in
twice and would move the fingerprint of a world that has not changed. That is
why `a6aa8e5776ebfe8c` is still `a6aa8e5776ebfe8c`.

`alive` and `hurt` are the two keys the world does *not* produce. There is no
combat yet, so nothing can be hit and nothing can die. They are branches in the
rule rather than absences because the rule is the thing being fixed, not the
state: when combat lands and the snapshot starts carrying them, no line of
`clip_for` changes.

### Which clips the world as it stands actually reaches

Counted rather than reasoned about:

```
$ ./tools/measure_motion.sh --seed 1234 --ticks 4000
motion seed=1234 ticks=4000 speed<=0.900 rise=[-1.595,+1.686] hop>=0.60
  Idle_A                1    0.0%
  Walking_A          3993   99.8%
  Running_A             0    0.0%
  Jump_Full_Short       7    0.2%
  Hit_A                 0    0.0%
  Death_A               0    0.0%
```

A second seed agrees: at seed 7 over the same 4000 ticks it is 1 idle, 3988
walks and 12 jumps.

Three of the six are live. The observer walks at a fixed 0.9 units a tick, which
sits deliberately between the idle threshold and the run threshold, so it walks —
and it *jumps seven times in four thousand ticks*, which is the one-hop climb
onto a floating island's rim. Nothing in the world runs, gets hurt or dies yet,
which is a fact about the world and not about the rule.

All six are exercised anyway, on all six models, out of one library:

![Six adventurers side by side, each holding a frame of a different clip: idle,
walking, running, jumping, being hit, and dead on the ground](assets/character-clips.png)

```
xvfb-run -a ./tools/character_sheet.sh --cell 3.0 \
    --screenshot "$PWD/reports/assets/character-clips.png" \
    ranger:Idle_A knight:Walking_A barbarian:Running_A \
    rogue:Jump_Full_Short mage:Hit_A hooded_rogue:Death_A
```

### The purity test is shown to fail

A test that cannot fail proves nothing, and "this function is pure" is exactly
the claim that quietly stops being tested. So it is demonstrated twice.

**In the suite, permanently.** `_the_clip_test_would_notice()` runs the same
two-snapshot comparison against `_broken_clip_for` — a rule that answers out of
what it answered last time instead of out of the state, which is the shape of
every bug where a view keeps a copy of the world — and *requires* it to get the
second snapshot wrong. If it ever gets it right, the check above has stopped
distinguishing anything.

**Against the real rule, once, by hand.** `clip_for` was edited to stop reading
the state's speed and always answer "standing still". The suite:

```
FAIL  characters     1295 checks, 507 failed
        - an observer walking at 0.90 units a tick should be walking
      expected: Walking_A
      actual:   Idle_A
        - a character running should play Running_A
      expected: Running_A
      actual:   Idle_A
```

507 of 1295 checks fail. The edit was reverted; the full captured output is in
[`reports/character-visuals-evidence.txt`](character-visuals-evidence.txt).

### And the simulation still names none of it

Two checks, both automated. The project's own pair:

```
$ ./run_tests.sh --layers-only
layer check: OK -- res://sim references nothing in the render layer
asset check: OK -- res://sim names asset tags and no asset
```

Plus a narrower one this task adds, because the six clip names are pack strings
that the existing checks would not have caught:
`_the_simulation_never_names_an_animation()` scans every file under `sim/` for
each clip name, both rig names, and `AnimationPlayer` / `AnimationTree` /
`AnimationLibrary`. Zero hits.

---

## 3. One scene, one animation setup, a swappable model

`render/character.tscn` is five nodes:

```
Character (Node3D, character_view.gd)
├── Model            <- the swappable child
├── AnimationPlayer
├── AnimationTree
├── HandLeft         (BoneAttachment3D -> handslot.l)
└── HandRight        (BoneAttachment3D -> handslot.r)
```

The player, the tree and the sockets are *above* the model, never inside it.
That is the whole reason a swap is cheap: `set_model(tag)` replaces one child and
re-points the three things that read into it — both mixers' `root_node`, the
shared library, and the sockets' external skeleton. Nothing else is rebuilt.

The shape is taken from the user's own build of this game
(`github.com/Acciorocketships/mythosunwritten`, `characters/character.tscn`),
read for how its rig is wired and not copied: that project is physics-first with
no simulation/render split, and its character script reads a clock and touches
the world in ways `bin/check_layers.gd` forbids here.

**Two mixers, one library, a clear division of labour.** The tree is what runs in
the game — it blends standing into walking into running on one number and lays a
one-off or a death over the result. It holds the library *directly* rather than
sourcing it from the player, which matters for a real reason found while
building this: an `AnimationTree` that reads its clips through `anim_player` does
nothing at all when its node is not inside a running scene tree, which is
precisely the situation a headless test and a contact-sheet tool are in. The
player is for playing one named clip outright and stopping on a frame of it,
which is how every still in this report was taken. Only one of them ever runs, so
they never write the same bone in the same frame.

**The swap is demonstrated, not asserted.** `_a_swapped_model_carries_on_animating()`
mounts a knight, walks it for half a second, and checks its hip bone has moved
away from its rest pose — so there is really something to carry on. Then it
swaps in a mage and checks four things: the model and the skeleton are new, the
clip is still `Walking_A`, `CharacterRig.libraries_assembled` **has not gone up**
(a swap that rebuilt the animation setup would show there), and the new
skeleton is posed away from *its* rest pose too.

### Which way is forwards

The engine's convention is that a node faces its own $-Z$. These models face
$+Z$, and that was measured off the art rather than assumed: on every adventurer
the cape and the quiver — things worn on the back — sit entirely at negative $z$,
and the knight's helmet visor, which is on his face, reaches $+0.766$.

| mesh | centre $z$ |
|---|---:|
| `Knight_Cape` | $-0.215$ |
| `Ranger_Quiver` | $-0.392$ |
| `Knight_HelmetVisor` | $+0.340$ |

Getting this backwards is invisible in a still and unmistakable in motion,
because the character moonwalks. So `yaw_for_heading()` puts $+Z$ along the
heading, and a test checks it at sixteen headings *and* re-measures the cape and
the visor, so the day someone repoints a row at a model drawn the other way
round the suite says so.

---

## 4. One skeleton means one library

`W-creature-packs` measured that all six adventurers and all four skeleton
enemies carry the same 23-bone rig named `Rig_Medium` — same bone names, same
parentage, same rest pose. A Godot animation track addresses a bone by *name*, so
one library of clips plays on all ten.

`render/character_rig.gd` is therefore a table keyed by **rig**, not by model:

| rig | library | who wears it |
|---|---|---|
| `Rig_Medium` | assembled from `Rig_Medium_General.glb` + `Rig_Medium_MovementBasic.glb`, 24 clips | all 6 adventurers, all 4 skeleton enemies |
| `Rig_Large` | its own, from the matching two files | **nothing on disk** — the pack ships the clips and a bare mannequin and no skinned character |

The second entry is not decoration. `Rig_Large` has the *same twenty-three bone
names* and a rest pose about 1.8× taller, so Godot will happily play a Large clip
on a Medium character and hand back a stretched one. Keeping it as a separate
library, with nothing pointing at it, is what makes the sharing above a measured
fact rather than a default. A test checks all of it: ten tags resolve to the same
library **object** (identity, not equality — two libraries holding the same clips
would still be two copies of the clips), asking for it ten times assembles it
once, asking for the second rig assembles a second, and no tag in the whole
catalog names `Rig_Large`.

Two of the eight `Rig_Medium` clip files are loaded, because between them they
hold every clip anything can currently be asked to play. The other six —
CombatMelee, CombatRanged, Tools, Simulation, Special, MovementAdvanced, 106
clips — wait because nothing yet produces the state that would choose one. Adding
one is adding one line, and the library it lands in is still the one library.

### The rig a row names is checked against the file

The table says `Rig_Medium`; the test opens the model and counts. For each of the
ten rigged tags it checks there is a node named `Rig_Medium`, that the skeleton
under it has exactly 23 bones, that both `handslot` sockets exist, and that the
*sorted* set of bone names is identical across all ten.

Sorted is the point, and it is the trap `W-creature-packs` fell into first: the
six adventurers list the same 23 bones in six different orders, so an
order-sensitive comparison reports six different skeletons, which is simply
wrong. The other trap is `Mannequin_Medium.glb`, whose parent node says
`Rig_Medium` and which ships 21 bones — which is why the bone count is checked
and the file name is not trusted.

---

## 5. Headless still loads nothing

The same check the project already performs, from outside the render layer,
because a counter kept by the asset table could only be read by loading the asset
table:

```
$ ./run_headless.sh --assets
done ticks=100 chunks=41 built=69 final=a6aa8e5776ebfe8c
assets visual-files  found=3338 loaded=0
assets render-scripts found=11 loaded=0
assets sim-scripts    found=31 loaded=31 -> ...
```

`visual-files` went from 3337 to 3338 (`render/character.tscn`) and
`render-scripts` from 9 to 11 (`character_view.gd`, `character_rig.gd`). Both
still load **zero**. The `sim-scripts` line is the control: without it, two zeros
would be indistinguishable from a probe that never worked.

And the fingerprint is unchanged, which is the other half of the same claim: the
simulation gained two floats and a snapshot key and lost nothing.

---

## 6. What this deliberately did not do

- **No character sheet.** No ability score, no HP, no inventory, no action
  interface. The view reads what the observer already carried plus two floats.
- **Nothing is equipped.** The two hand sockets exist and follow `handslot.l`
  and `handslot.r` from the moment a model is mounted, so equipping a weapon
  later is `add_child`. Nothing is in them; that waits for `W-items`.
- **The world still holds one character.** `render/main.gd` draws one
  `CharacterView` where it used to draw one sphere. Which adventurer it is is one
  constant, `OBSERVER_TAG` — currently `ranger` — because that is what the
  swappable-model shape is for.
- **`Running_A`, `Hit_A` and `Death_A` are unreachable in the live world**, and
  the measurement above says so rather than the prose implying otherwise.

---

## 7. Reproducing this

```
./run_tests.sh                      # 20 suites, 171,509 checks
./run_tests.sh --layers-only        # the two split checks
./run_headless.sh --assets          # fingerprint a6aa8e5776ebfe8c, loaded=0
./run_assets.sh                     # 58 tags, 58 resolved
./tools/measure_motion.sh --seed 1234 --ticks 4000

xvfb-run -a ./run_render.sh --seed 1234 --start -232 -224 \
    --camera 0 3.6 7.5 --aim 1.7 --screenshot-tick 40 \
    --screenshot "$PWD/reports/assets/observer-character.png"
xvfb-run -a ./run_asset_sheet.sh --screenshot "$PWD/reports/assets/asset-tag-sheet.png"
```

Full captured output:
[`reports/character-visuals-evidence.txt`](character-visuals-evidence.txt).

`tools/character_sheet.gd` and `tools/measure_motion.gd` are new and are
workbenches, not part of the game. Both go through `AssetLibrary` and
`CharacterView` rather than loading files, so what they photograph and count is
what the table resolves and what the view plays.
