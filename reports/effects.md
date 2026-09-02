# One composable effect base: an arrow is a composition, not a class

Section 4 asks for one base class rather than a hierarchy — "melee attacks,
projectiles, spells, and actions share one base, customized by effect, damage,
properties, hitbox shape, sprite, animation, and movement". This step builds
that base, re-expresses the seven-weapon catalogue over it without moving a
number, and then says two things the earlier code had no way to say: **an
arrow**, and **a magic missile**. Neither is a new class. Each is the same
constructor call the spear is, with different values in fields that were already
there.

That is the whole point. A generator can set fields; it cannot write a class. So
every axis along which a randomised item may later vary has to be a field on one
base, and no rule anywhere may ask which item it is looking at.

---

## The base

One file, `sim/attack.gd`, and the seven customisation points are seven of its
fields:

| customisation point | field | what it holds |
|---|---|---|
| hitbox shape | `offsets` | the cells it covers, written facing north |
| damage | `damage` | what one landing is worth, before defence |
| properties | `properties` | named whole numbers: `push`, `split`, `homing` |
| movement | `movement` | `instant`, or `projectile` — how it gets there |
| effect | `effects` | what it does besides damage, by mechanic name |
| sprite | `sprite_tag` | which art says so — a tag, never a path |
| animation | `animation_tag` | which motion says so — a tag, never a path |

plus the two every one of them has: a name, and a cooldown in turns. Everything
left out of a composition takes the value that means *this effect does not do
that*, so a spear pays nothing for the movement it does not have.

Three of those points are new, and each is arithmetic rather than behaviour:

* **movement** — `travels()` asks the movement table, and `travel_to(from, cell)`
  is the lattice line between the two, `from` excluded and the target included.
  An instant effect is already where it is aimed, so the ground it crossed is the
  one cell it landed on. This is the only reason anything could ever stand in a
  projectile's way; whether it *does* is the board's answer, as for every other
  pattern.
* **split** — `strike_count()` is the `split` property, and `damage_share(i)`
  divides the damage across those landings exactly, in whole numbers, the
  remainder going to the earliest. The same largest-remainder shape the power
  budget divides an item by.
* **homing** — `reachable_from()` is the shape widened by the `homing` property.
  With no homing it is exactly `cells_from()`, which is why nothing that does not
  home pays for the field.

A shove was already this: an effect whose `push` is more than zero. Split and
homing arrived on the same terms and cost the same — one dictionary entry each,
no new targeting system, no line of the resolution step changed.

---

## The seven, re-expressed

Every number the combat suites assert is unchanged. What each weapon *gained* is
the three columns on the right.

| weapon | attack | cells | cooldown | damage | push | movement | sprite | animation |
|---|---|---|---|---|---|---|---|---|
| spear | thrust | 2 | 1 | 8 | 0 | instant | point | lunge |
| dagger | stab | 2 | 1 | 6 | 0 | instant | blade | slash |
| sword | cut | 3 | 1 | 10 | 0 | instant | blade | slash |
| sword | cleave | 6 | 3 | 16 | 0 | instant | blade | swing |
| bow | loose | 248 | 3 | 12 | 0 | **projectile** | arrow | shoot |
| staff | fireball | 9 | 5 | 4 | 0 | instant | flame | cast |
| flail | sweep | 8 | 1 | 5 | 0 | instant | impact | spin |
| shield | shove | 1 | 2 | 0 | 1 | instant | impact | bash |

**Nothing moved, and one thing changed.** No cell count, cooldown, damage or push
in that table is different from what `sim/weapon.gd` held before, and the
combat-piece and combat-resolution suites — which assert those numbers directly —
pass untouched. The one substantive change is the bow: its `loose` is now a
projectile carrying the arrow tag, because that is what it always was and there
was previously nowhere to write it down. It changes no number, no cell, and no
outcome; the stop condition on this task did not fire.

Two smaller changes are worth naming. `Weapon.index_of(name)` — a lookup of an
attack by its name — was removed. Nothing called it, and it was the only place in
the layer that compared an item's name to anything, which is exactly the thing
the source scan below now forbids. And `Attack.line()` gained the new fields;
nothing read it before, so nothing compared against its old form.

As printed by `./run_effects.sh`:

```
weapon       attack
spear        thrust cooldown=1 damage=8 cells=2 fronted instant sprite=point anim=lunge
dagger       stab cooldown=1 damage=6 cells=2 fronted instant sprite=blade anim=slash
sword        cut cooldown=1 damage=10 cells=3 fronted instant sprite=blade anim=slash
sword        cleave cooldown=3 damage=16 cells=6 fronted instant sprite=blade anim=swing
bow          loose cooldown=3 damage=12 cells=248 symmetric projectile sprite=arrow anim=shoot
staff        fireball cooldown=5 damage=4 cells=9 fronted instant effects=flame sprite=flame anim=cast
flail        sweep cooldown=1 damage=5 cells=8 symmetric instant sprite=impact anim=spin
shield       shove cooldown=2 damage=0 cells=1 fronted instant push=1 sprite=impact anim=bash
```

---

## The two it could not hold before

```
weapon       attack
hunting bow  arrow cooldown=2 damage=12 cells=11 fronted projectile sprite=arrow anim=shoot
wand         magic missile cooldown=3 damage=10 cells=104 symmetric projectile split=3 homing=1 effects=arcane sprite=bolt anim=cast
```

**The arrow** is a lane of eleven cells two to twelve ahead, an `Attack.compose`
call with `movement` set to `projectile` and `sprite` set to the arrow tag. Its
pattern generator, its rotation, its cooldown and its damage are the spear's and
the bow's. What travelling buys is the cells in between, from `(4,9)`:

| effect | target | cells crossed |
|---|---|---|
| arrow | (4,5) | (4,8) (4,7) (4,6) (4,5) |
| arrow | (8,5) | (5,8) (6,7) (7,6) (8,5) |
| arrow | (8,7) | (5,8) (6,8) (7,7) (8,7) |
| arrow | (1,12) | (3,10) (2,11) (1,12) |
| thrust | (4,5) | (4,5) |
| thrust | (8,5) | (8,5) |
| thrust | (8,7) | (8,7) |
| thrust | (1,12) | (1,12) |

The same lane composed `instant` covers exactly the same cells and crosses
nothing, which is what says the four cells are the movement's doing and not the
shape's.

**The magic missile** is a projectile that splits and homes: three properties and
no code. Its ten damage divides three ways as 4, 3, 3 — exactly, by the same rule
the item budget uses — and its ring of 104 cells widens to 168 with a bend of one.

| split | shares | sum |
|---|---|---|
| 1 | 10 | 10 |
| 2 | 5 5 | 10 |
| 3 | 4 3 3 | 10 |
| 4 | 3 3 2 2 | 10 |
| 5 | 2 2 2 2 2 | 10 |
| 6 | 2 2 2 2 1 1 | 10 |

| homing | shape cells | reachable cells |
|---|---|---|
| 0 | 104 | 104 |
| 1 | 104 | 168 |
| 2 | 104 | 233 |
| 3 | 104 | 305 |

Both are wielded, aimed, rotated and put on cooldown by exactly the code a spear
is. Nothing was added to the commander, the board or the turn to hold them, and
`Weapon.arrow().get_script()` is the same script as the spear's thrust.

---

## Sprites and animations are tags, and a second vocabulary

`sim/asset_tags.gd` now holds two vocabularies rather than one, and the split is
deliberate.

The **catalog** is the list of things that can be standing in the world — a fir,
a bridge, a lantern post — and the render layer's table has a row that builds
every one of them as a scene. An effect's sprite and its animation are neither:
they are named state travelling with something that happened, on the same terms
a character's animation already travels on. So they sit beside the catalog as
`EFFECT_SPRITES` (`arrow`, `bolt`, `blade`, `point`, `flame`, `impact`) and
`ANIMATIONS` (`lunge`, `slash`, `swing`, `shoot`, `cast`, `spin`, `bash`), and
nothing is both a prop and a sprite.

Keeping them out of the catalog is what lets this step honour its boundary of not
reaching into `render/`: adding a row to the catalog would have required adding a
row to the render layer's table in the same breath. What these tags resolve to is
still the render table's business — it simply has no rows for them yet, which is
work for whoever draws a fight.

`tests/asset_check.gd` still passes over the whole of `sim/`, and each tag is put
through it individually as a string literal, so `sprite=arrow` is checked to read
as a name and not as art.

---

## Nothing asks which item it is holding

Shown by opening `sim/` — all 59 files of it — rather than by a list written down
in the test. Four scans, each paired with a run that must fail it:

1. **No line both names an item and asks a question.** A name in a *list* of
   names — the forge's item shapes, the sprite vocabulary — is not a branch; a
   name beside a comparison is. The catalogue's nineteen names are written down
   more than twenty times under `sim/`, and not one of those lines compares.
2. **`weapon_name` and `attack_name` are read only to write down what happened.**
   Eight lines under `sim/` name either field; the three outside their own
   classes put a name into a transcript. None compares. The negative control
   matters here: `"-" if weapon == null else weapon.weapon_name` has a comparison
   on it and is *not* flagged, because what is compared is a null and not a name.
3. **The constructors that hand out one particular weapon are only ever handed
   over.** Found by scanning, the files are exactly the ones that set a scenario
   up -- four of them since the end-to-end character run joined them:

```
sim/scripted_match.gd:149:     first.wield(Weapon.held(Weapon.shield(), 3, ItemRarity.COMMON, 0, 12))
sim/scripted_match.gd:154:     second.wield(Weapon.held(Weapon.sword(), 2))
sim/scripted_match.gd:160:     third.wield(Weapon.held(Weapon.spear(), 1))
sim/scripted_encounter.gd:120: (green.piece as Commander).wield(Weapon.held(Weapon.sword(), BAND_LEVEL))
sim/scripted_encounter.gd:131: (amber.piece as Commander).wield(Weapon.held(Weapon.spear(), BAND_LEVEL))
sim/scripted_encounter.gd:142: (distant.piece as Commander).wield(Weapon.held(Weapon.dagger(), BYSTANDER_LEVEL))
sim/scripted_encounter.gd:178: (green.piece as Commander).wield(Weapon.held(Weapon.sword(), BAND_LEVEL))
sim/scripted_encounter.gd:186: (amber.piece as Commander).wield(Weapon.held(Weapon.spear(), BAND_LEVEL))
sim/scripted_scenario.gd:228:  (bram.piece as Commander).wield(Weapon.held(Weapon.sword(), _level_of(BRAM)))
sim/scripted_scenario.gd:232:  (sable.piece as Commander).wield(Weapon.held(Weapon.spear(), _level_of(SABLE)))
```

Every one of the ten is a `wield(` on the same line: a scenario handing a
weapon to somebody, never reading it back. The last two arrived with
[reports/scenario.md](scenario.md), and the list in the test had to be widened
to admit the file -- which is the check doing its job rather than a slip.

4. **And every one of the eight is *forged*.** This scan
   (`_every_weapon_handed_out_has_an_item_behind_it`) asks the other half of
   section 4's first sentence structurally rather than by assertion: a `Weapon`
   is a shape plus an `Item`, the `Item` may be null, and a null one reads the
   catalogue's own damage numbers — which no power budget paid for and no
   ability score can gate. So every line that names one particular weapon must
   also say `Weapon.held(`, and so must every line that both names one and hands
   it over. Two broken controls (a bare `wield(Weapon.sword())`, which the scan
   must flag, and a forged one, which it must not) and a positive count of at
   least eight forged calls keep an empty result meaning "not there" rather than
   "did not look". This scan is the one that catches the five encounter call
   sites that used to hand a commander a bare shape — see
   [reports/encounter-item-backed.md](encounter-item-backed.md), which is where
   the transcript that changed as a result is written up.

A fifth scan, off this list because it is about the base rather than about
naming, adds the structural half: no file under `sim/` contains
`extends Attack`, so nothing is a *kind* of the base — checked against the
control that every file does contain `extends `.

---

## What is checked

`tests/test_effects.gd`, 1474 checks, every number written out by hand and
compared exactly. Each claim with a premise is paired with the premise broken:

| claim | how it is broken |
|---|---|
| the arrow crosses four cells | re-composed `instant`, it crosses one |
| the missile reaches 168 cells | re-composed without homing, it reaches its 104 |
| ten damage splits 4/3/3 | re-composed without the split, one landing takes ten |
| the split divides exactly | a plain floor loses points on 143 of 246 sweeps |
| the catalogue's numbers | compared against a table with the spear's damage moved |
| no line compares an item's name | the same scan over `weapon_name == "sword"` fires |
| no line matches on one | the same scan over `match attack.attack_name:` fires |
| the constructor scan | fires on `Weapon.sword()`, not on `Weapon.make(…)` |
| nothing extends the base | the same scan over `extends ` finds all 59 files |

The split sweep walks all 246 combinations of damage 0–40 against 1–6 landings:
every one sums to its whole damage, no landing is worth less than nothing, and no
two landings of the same effect differ by more than one point.

Determinism is checked from outside, as it is for the item layer: `./run_effects.sh`
run twice in two separate processes prints identical bytes. There is no seed
anywhere in this layer, and nothing in it draws.

---

## Commands

```
./run_effects.sh        # the tables above
./run_effect_suite.sh   # just this suite
./run_tests.sh          # every suite
```

## Evidence

* all 27 suites pass headless, 189 732 checks, exit 0
* `./run_tests.sh --layers-only` — layer check, combat check and asset check all OK
* headless world fingerprint `d4e31b0904ff45c0`, unchanged
* `./run_pieces.sh` 343 checks and `./run_resolution.sh` 314 checks, both unchanged
* the project's two mutation harnesses are still green — `tools/piece_mutations.sh`
  17 of 17 and `tools/resolution_mutations.sh` 41 of 41 broken rules caught
* nothing under `render/` was touched

### The mutation harnesses had to be re-pointed

Five of the resolution harness's mutations named source text that the
re-expression removed — `attack.push = maxi(0, pushes)` in `sim/attack.gd`, and
three `Attack.make("fireball"…)` / `Attack.make("shove"…)` lines in
`sim/weapon.gd`. The harness fails loudly on a target it cannot find (it prints
`COULD NOT APPLY` and counts the rule as unchecked), so this could not have gone
silently wrong, but it did have to be fixed. The five now point at the equivalent
line in the new source — the property loop inside `Attack.compose`, and the
`damage` and `Attack.PUSH` entries of the two composition blocks — and all five
are caught again. The piece harness needed no change: the line it breaks, the
rotation an attack turns by, is untouched.
