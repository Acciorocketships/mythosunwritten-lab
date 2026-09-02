# The enemy packs, and the one skeleton that covers everyone

Two questions decided the shape of all the character work, and both are now
answered by measurement rather than by assumption.

**One skeleton covers every character in the game.** All six adventurers and all
four skeleton enemies carry the same 23-bone rig, named `Rig_Medium`, and they
carry it identically -- same bone names, same parentage, same rest pose. One
animation library plays on all ten. That library is 131 clips and it is free.

**The gap is the minion roster.** None of the four minion types -- Toadstool,
Cat, Ent, Frog -- exists as a model in any free pack. The packs that would hold
creatures like those are KayKit's three Mystery Monthly series, and they are
$19.99 each, so they were not fetched.

Everything below is reproducible from the commands it quotes. Nothing under
`sim/` or `render/` changed: the headless world fingerprint is
`a6aa8e5776ebfe8c`, the same value it had before this task, and all 19 test
suites pass.

---

## 1. What was fetched, and the one thing that could not be

Three packs were added to `tools/fetch_kaykit.sh` by slug and installed by
running it. No account, no sign-in, one command:

```
./tools/fetch_kaykit.sh
```

| slug | directory | models | what it is |
|---|---|---:|---|
| `kaykit-skeletons` | `assets/kaykit_skeletons` | 19 | 4 rigged undead + 13 hand props + 2 clip files |
| `kaykit-character-animations` | `assets/kaykit_character_animations` | 16 | the clip libraries + 2 mannequins |
| `board-game-bits` | `assets/kaykit_board_game_bits` | 162 | abstract board pieces |

Board Game Bits is in the list because the design names it for "game-piece
minions" (§9.10) and it is free; it is the only installed thing that speaks to
the minion question at all. Section 4 says what it can and cannot do.

### The pack that could not be fetched

The design also names **Mystery Monthly**. There are three series of it, and all
three are paid. Asking the script for one by name gives itch.io's own refusal
rather than a workaround:

```
$ ./tools/fetch_kaykit.sh kaykit-series-4
== kaykit-series-4 -> assets/kaykit_mystery_series_4
  itch.io refused kaykit-series-4: you must buy this game to download
!! kaykit-series-4 failed
```

This is not a sign-in problem — no browser session would help. The pack page
lists `"price":"19.99"` and the download endpoint answers
`{"errors":["you must buy this game to download"]}`. Per the task's boundary
nothing was bought. The three slugs stay in the script's table, commented as
paid, and are deliberately **not** in the default list, so the plain
`./tools/fetch_kaykit.sh` stays a clean one-command install.

The script previously died with a Python `KeyError` on a paid pack and then
reused the *previous* pack's download page, which is how the same upload id
appeared under two different pack names in the first run. Both are fixed: the
refusal is now reported verbatim, and the download page is cleared between
packs.

---

## 2. Every rigged model, measured

```
./tools/measure_rigs.sh
```

Height is the model's own bounding height in metres as the artist drew it,
measured from the rest-pose vertices. **Floor** is the y of the lowest point:
every one of these sits within 2 mm of its own origin, so a character dropped at
a ground height stands on it rather than sunk into or floating above it.

Heights include headgear — the Mage's 2.655 m is mostly witch hat, and the
bodies all sit near 2.2 m. KayKit draws these deliberately chunky and slightly
over-scale; 2.2 m is the rig's own height, not a mistake.

**Adventurers** (`assets/kaykit_adventurers/.../Characters/gltf/`) — 23 bones each, rig `Rig_Medium`:

| file | triangles | height | bones |
|---|---:|---:|---:|
| `Barbarian.glb` | 7,123 | 2.398 m | 23 |
| `Knight.glb` | 5,800 | 2.543 m | 23 |
| `Mage.glb` | 6,668 | 2.655 m | 23 |
| `Ranger.glb` | 8,900 | 2.275 m | 23 |
| `Rogue.glb` | 7,562 | 2.180 m | 23 |
| `Rogue_Hooded.glb` | 7,185 | 2.173 m | 23 |

**Skeletons** (`assets/kaykit_skeletons/.../characters/gltf/`) — 23 bones each, rig `Rig_Medium`:

| file | triangles | height | bones |
|---|---:|---:|---:|
| `Skeleton_Warrior.glb` | 5,934 | 2.590 m | 23 |
| `Skeleton_Rogue.glb` | 5,278 | 2.308 m | 23 |
| `Skeleton_Mage.glb` | 4,588 | 2.630 m | 23 |
| `Skeleton_Minion.glb` | 5,288 | 2.166 m | 23 |

**Mannequins** (`assets/kaykit_character_animations/.../characters/`) — reference
models, not characters to ship:

| file | triangles | height | bones | note |
|---|---:|---:|---:|---|
| `Mannequin_Medium.glb` | 6,916 | 2.204 m | 21 | named `Rig_Medium` but **is not it** — see §3 |
| `Mannequin_Large.glb` | 9,148 | 3.981 m | 23 | the `Rig_Large` proportions |

The enemies are *cheaper* than the heroes: the four undead average 5,272
triangles against the adventurers' 7,206, and `Skeleton_Mage` at 4,588 is the
lightest rigged model on disk. That matters because enemies outnumber heroes on
a board.

Twelve of them at real size, each beside a one-metre post:

![The ten shippable rigged characters plus both mannequins, laid out at real size on a common ground plane with a one-metre scale post beside each. The six adventurers on top, the four skeleton enemies in the middle, and the two mannequins at the bottom showing the Rig_Large proportions against Rig_Medium.](assets/rigged-characters.png)

```
xvfb-run -a ./tools/model_sheet.sh --cell 6 \
    --screenshot "$PWD/reports/assets/rigged-characters.png" <the twelve files>
```

---

## 3. The skeleton is `Rig_Medium`, and it is shared — checked, not assumed

The whole character phase rests on this one fact, so it was measured rather than
taken from the pack's marketing.

`tools/measure_rigs.gd` compares two things per model:

- **skeleton** — a short hash of the *set* of `bone<parent` pairs, sorted. Sorted
  is the point. The six adventurers list the same 23 bones in six different
  orders, so a naive comparison of the bone list in file order reports six
  different skeletons, which is wrong: an animation track addresses a bone by
  *name*, never by index. Order is not part of what "the same skeleton" means.
- **rest pose** — a second hash over each bone's rest position to the
  millimetre. Two rigs can agree on every bone name and still be different
  sizes, and a clip carries bone positions, so this catches a rig that would
  play the clips and come out stretched.

The result, over every rigged file on disk:

```
VERDICT: 30 rigged models, 2 distinct skeletons by bone name, 3 by rest pose
```

Resolved:

| | skeleton | rest pose | who |
|---|---|---|---|
| **`Rig_Medium`** | `aa6fceac` | `f669538c` | all 6 adventurers, all 4 skeletons, every `Rig_Medium` clip file |
| `Rig_Large` | `aa6fceac` | `74fd52b4` | `Mannequin_Large` and the 6 `Rig_Large` clip files |
| (mannequin) | `1003b2b8` | `2e246d7e` | `Mannequin_Medium` alone |

The 23 bones, with each bone's parent:

```
root<              hips<root          spine<hips         chest<spine
head<chest         upperarm.l<chest   lowerarm.l<upperarm.l   wrist.l<lowerarm.l
hand.l<wrist.l     handslot.l<hand.l  upperarm.r<chest   lowerarm.r<upperarm.r
wrist.r<lowerarm.r hand.r<wrist.r     handslot.r<hand.r  upperleg.l<hips
lowerleg.l<upperleg.l   foot.l<lowerleg.l  toes.l<foot.l  upperleg.r<hips
lowerleg.r<upperleg.r   foot.r<lowerleg.r  toes.r<foot.r
```

`handslot.l` and `handslot.r` are the weapon sockets. They are part of the
shared rig, which is why the 31 adventurer hand props and the 13 skeleton hand
props socket onto heroes and enemies alike.

**So: one skeleton covers everyone.** The answer to the task's second question
is the first branch, not the per-pack clip list.

### Two traps found while measuring, both worth knowing before building

1. **`Rig_Large` has the same bone names as `Rig_Medium` but a different rest
   pose.** Its mannequin is 3.981 m against 2.204 m — about 1.8× — and the size
   gap is visible in the contact sheet above. Godot will happily play a
   `Rig_Large` clip on a `Rig_Medium` character because every track resolves by
   name, and the character will come out stretched. The bone-name check alone
   would have missed this; the rest-pose check is what caught it. Keep the two
   clip sets apart by rest pose, not by folder name.
2. **`Mannequin_Medium.glb` is named for the rig but is not the rig.** Its
   parent node says `Rig_Medium`, yet it ships 21 bones, not 23 — it is missing
   both `handslot` sockets — and its rest pose differs from the real
   `Rig_Medium`. It is a reference model, harmless as long as nobody treats the
   file name as the rig identity. This is exactly the assumption the task asked
   to have checked.

---

## 4. What the packs can cover, and what they cannot

> What was built on this: [`reports/characters.md`](characters.md) —
> `W-character-visuals` turned all ten rigged models plus the four minions into
> catalog tags, put one shared `Rig_Medium` library behind them, and replaced the
> observer sphere with an animated character.

### The four minion types — all four are gaps as creatures

| minion | analog | model in any installed pack | status |
|---|---|---|---|
| Toadstool | pawn | none | **gap** |
| Cat | bishop | none | **gap** |
| Ent | rook | none | **gap** |
| Frog | knight | none | **gap** |

No installed pack holds a frog, a cat, an ent, or a toadstool. This is the same
`toadstool` gap already on record for the scenery catalog, now confirmed to
extend to creatures.

What Board Game Bits does give is the *abstract* reading of the minion layer —
board pieces, in four colours (blue, green, red, yellow), which is a natural fit
for §3.8's several commanders with no fixed sides:

| piece | size (w × h × d) | fits |
|---|---|---|
| `pawn_A_<colour>` | 0.500 × 0.915 × 0.500 | Toadstool — it is literally a pawn |
| `pawn_B_<colour>` | 0.750 × 1.215 × 0.750 | a taller second piece |
| `meeple_<colour>` | 1.000 × 1.240 × 0.400 | the tallest, most character-like piece |
| `cube_<colour>` | 0.500 × 0.500 × 0.500 | a marker, not a piece |
| `token_<colour>` | 1.079 × 0.100 × 1.079 | a flat cell marker |
| `tile_<colour>` | 1.000 × 0.200 × 1.000 | a board cell |

That is enough to put a legible, four-player-coloured minion layer on the board
that reads as chess rather than as coloured primitives, and it is honest about
being abstract. It is **not** the cute-fantasy Toadstool/Cat/Ent/Frog the design
asks for. Whoever builds the minion tags should know they are choosing between
an abstract piece now and a bought pack later, not filling a gap.

The pieces are also roughly one third the size of the 3.0-unit combat cell, so
they would need scaling up rather than down.

### Enemy roles — one species, four roles, covered

| role | model | triangles | note |
|---|---|---:|---|
| armoured melee | `Skeleton_Warrior.glb` | 5,934 | helmet and cloak; shield props ship with it |
| light / ranged | `Skeleton_Rogue.glb` | 5,278 | `Skeleton_Crossbow`, `Skeleton_Blade`, `Skeleton_Quiver`, `Skeleton_Arrow` |
| caster | `Skeleton_Mage.glb` | 4,588 | `Skeleton_Staff` |
| cheap chaff | `Skeleton_Minion.glb` | 5,288 | smallest at 2.166 m |

Thirteen hand props ship with them — axe, blade, crossbow, staff, quiver, four
arrow states, and four shields — and they socket onto the shared `handslot`
bones, so an enemy's weapon is a swap, not a model.

**The gaps in enemy roles:**

- **One species only.** Every enemy on disk is undead. There is no beast, no
  goblin, no orc, nothing for a forest or a marsh to be dangerous with. A world
  whose only enemy is a skeleton is a narrow world.
- **No large creature at all.** `Rig_Large` ships 28 clips and a bare untextured
  mannequin — and nothing else. There is no skinned large character in any free
  pack, so those 28 clips currently have nothing to play on. Large creatures are
  precisely what the paid Mystery Monthly packs hold.
- **No neutral villagers.** The six adventurers are the only non-hostile
  characters, so every villager would be a re-coloured adventurer.

---

## 5. The animation library, which comes free with the shared rig

Because one skeleton covers everyone, one library covers everyone. From the
Character Animations pack, on `Rig_Medium`, **131 distinct clips** (excluding
the T-Pose each file repeats):

| file | clips | what is in it |
|---|---:|---|
| `Rig_Medium_General.glb` | 14 | Death_A/B, Hit_A/B, Idle_A/B, Interact, PickUp, Spawn_Air, Spawn_Ground, Throw, Use_Item |
| `Rig_Medium_MovementBasic.glb` | 10 | Walking_A/B/C, Running_A/B, and the five Jump states |
| `Rig_Medium_MovementAdvanced.glb` | 12 | Crawling, Crouching, Sneaking, four Dodges, two Strafes, Walking_Backwards, two bow/rifle runs |
| `Rig_Medium_CombatMelee.glb` | 21 | 1H / 2H / dual-wield / unarmed attacks, Block, Blocking, Block_Attack, Block_Hit |
| `Rig_Medium_CombatRanged.glb` | 19 | bow draw/release/idle, 1H and 2H shooting, five Magic clips including Summon |
| `Rig_Medium_Simulation.glb` | 13 | sitting, lying, standing up, Cheering, Waving |
| `Rig_Medium_Special.glb` | 14 | **thirteen `Skeletons_*` clips** — Awaken_Floor, Awaken_Standing, Death_Resurrect, Taunt, Inactive poses |
| `Rig_Medium_Tools.glb` | 28 | chopping, digging, hammering, sawing, pickaxing, lockpicking, fishing |

Two things stand out for this project specifically:

- `Rig_Medium_Special.glb` carries a dedicated set of skeleton clips — enemies
  rising from the floor, taunting, dying and resurrecting. The enemy behaviour
  the design wants is already animated.
- `Rig_Medium_Tools.glb` carries 28 work clips including `Lockpick` and
  `Lockpicking`. §2.1 names lockpicking as the example of the generic `interact`
  action, and the clip for it already exists.

`Ranged_Magic_Summon` is worth noting too: minions are summoned via items
(§3.3), and there is a summon animation for it.

The Adventurers and Skeletons packs each ship their own smaller copies of
`Rig_Medium_General` and `Rig_Medium_MovementBasic` — 25 clips, all duplicated
in the Character Animations pack. Only the Character Animations copies are worth
loading.

`Rig_Large` ships 28 clips of which 12 exist nowhere else (`Melee_2H_Slam`,
`Melee_Unarmed_Smash`, `Flexing`, …). They are unusable until a large creature
model exists.

---

## 6. Reproducing this

```
./tools/fetch_kaykit.sh                     # install; skips what is already there
./tools/fetch_kaykit.sh kaykit-series-4     # the exact paid-pack refusal
./tools/measure_rigs.sh                     # the tables in §2 and §3
./tools/measure_models.sh pawn_A_red meeple_red cube_red token_red tile_red
./run_tests.sh                              # 19 suites, 169,914 checks
./run_headless.sh                           # fingerprint a6aa8e5776ebfe8c
```

Full captured output: [`reports/creature-packs-evidence.txt`](creature-packs-evidence.txt).

`tools/measure_rigs.gd` is new and is a workbench, not part of the game — it
reads files on disk and knows nothing about tags, the simulation, or the render
layer. This task added the two `tools/` scripts, one report, one screenshot and
824 pack files under `assets/`, and touched nothing else. The layer check still
passes: `res://sim` references nothing in the render layer and names asset tags
rather than assets.
