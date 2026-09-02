# The board reads items: defence, movement, damage and cooldowns out of the power budget

The combat layer used to read three placeholder constants out of `sim/armour.gd`
— `DEFENCE_PER_TIER`, `HIGH_TIER`, `CHESTPLATE_REACH` — and a table of fixed
damage numbers out of `sim/weapon.gd`. It now reads the item layer instead. A
commander's defence is what the items it carries spent on their defence axis;
which movement grants it has is what they paid for out of their movement axis;
what its weapon deals and how long that weapon waits come off the item in its
hands; and every one of those readings goes through section 4's ability-score
gate, so the same object is worth different amounts to different people.

Two of the three constants are gone. The third survives and is named below with
the reason it had to.

Everything here is reproducible from the commands it quotes:

```
./run_loadout.sh          # the price list, the worked boards, the tables below
                          # (its whole output: reports/loadout-evidence.txt)
./run_match.sh            # the scripted three-commander match, now item-equipped
./run_pieces.sh           # 360 checks
./run_resolution.sh       # 339 checks
```

The world's fingerprint did not move: `./run_headless.sh` gives
`d4e31b0904ff45c0` at seed 1234 and tick 100, the value it had before this task.
All 27 suites pass headless (189 779 checks), all three structure checks pass,
and both mutation harnesses catch every rule they are required to catch — 19 of
19 and 46 of 46.

---

## 1. One price, and it is the same price everywhere: a point buys a cell

An item's power budget is $P = r(\text{rarity}) \times L$, split across movement,
defence and effects (see [items.md](items.md)). The combat layer's whole reading
of the movement axis is one sentence: **a point of it buys one cell.** A pattern
of $n$ offsets ridden $r$ cells costs $n \times r$.

| slot | capability | cells | price |
|---|---|---|---|
| boots | the diagonal step — king-like with the base under it | 4 offsets × 1 | 4 |
| leggings | the knight's hop, which carries over what is between | 8 offsets × 1 | 8 |
| chestplate | the queen-like slide, per cell of reach | 8 directions × 1 | 8 |
| chestplate | …and the second cell | 8 directions × 2 | 16 |
| helmet | none at any price | — | — |

The same sentence prices a *held* item, where a point of movement buys a turn off
a cooldown per cell the attack covers (§4 below). So there is one rule for the
movement axis, worn or held, and no second one to keep in step with it.

**The three constants.**

* `DEFENCE_PER_TIER` — **gone.** What a piece takes off a blow is its defence
  axis. There is no tier anywhere in `sim/armour.gd` any more: an item's rarity
  and its level are the two numbers the one tier used to stand in for.
* `HIGH_TIER` — **gone.** Whether a chestplate grants the queen-like slide is
  whether its movement axis can pay for a cell of it, which is also why the grant
  now has *sizes* rather than being on or off.
* `CHESTPLATE_REACH` — **survives, at 2.** It is not a placeholder. Section 3.4
  says a chestplate is queen-like *"up to 2 cells"*, so the cap is the design's
  own sentence and no budget lifts it. A budget below it buys less; a budget
  above it buys defence instead.

One more number is new, and it is the only conversion in the layer:
`Armour.POINTS_PER_DEFENCE = 16`. Sixteen points of an item's defence axis buy
one point of reduction, and sixteen is $|\text{slots}|^2$: four because a blow
lands somewhere on a body rather than on the piece its owner would pick, so what
stops it is the mean over the four worn slots; four again because a commander
carries four worn items for the one in its hands, which is the exchange rate
between a whole suit's budget and a weapon's. §5 measures what that choice
actually produces rather than asserting it was right.

---

## 2. A loadout changes what a commander may do, on a worked board

The board is the piece suite's own fixture — a building at (4,4), a hole at
(8,4), earth too high to climb at (4,8), a step down at (8,8) — so that what
stops a slide is visible. `C` is the commander at (6,6); `o` is a cell it may
move to. Every board below is printed by `./run_loadout.sh`.

**Bare — one cardinal step, 4 cells.** No item, no grant.

```
 . . . . # . . . ~ . . . .
 . . . . . . o . . . . . .
 . . . . . o C o . . . . .
 . . . . . . o . . . . . .
 . . . . ^ . . . , . . . .
```

**Boots, `boots(4/4)` — the diagonal too, which is a king. 8 cells.** A common
item off a level-2 creature: eight points, four of which are the diagonal's price
and four of which are left to stop blows.

```
 . . . . # . . . ~ . . . .
 . . . . . o o o . . . . .
 . . . . . o C o . . . . .
 . . . . . o o o . . . . .
 . . . . ^ . . . , . . . .
```

**Leggings, `leggings(8/8)` — the knight's hop. 12 cells.** A common item off a
level-4 creature: sixteen points, eight of them the hop's price. The hop carries
over the building and lands past the hole, because a landing reads only where it
lands.

```
 . . . . # o . o ~ . . . .
 . . . . o . o . o . . . .
 . . . . . o C o . . . . .
 . . . . o . o . o . . . .
 . . . . ^ o . o , . . . .
```

**A chestplate is a ladder, not a switch.** Eight points buy one cell of the
queen-like slide and sixteen buy two — and below eight it grants nothing and is
armour, which is what a chestplate under the old `HIGH_TIER` was.

`chestplate(8/0)`, a level-2 common item, **8 cells**:

```
 . . . . # . . . ~ . . . .
 . . . . . o o o . . . . .
 . . . . . o C o . . . . .
 . . . . . o o o . . . . .
 . . . . ^ . . . , . . . .
```

`chestplate(16/0)`, a level-4 common item, **13 cells** — and it is stopped by
the building to the north-west, the hole to the north-east and the wall of earth
to the south-west, exactly as a Cat and an Ent are:

```
 . . . . # . o . ~ . . . .
 . . . . . o o o . . . . .
 . . . . o o C o o . . . .
 . . . . . o o o . . . . .
 . . . . ^ . o . o . . . .
```

**All three at once — the union, 21 cells, and no piece in chess:**

```
 . . . . # o o o ~ . . . .
 . . . . o o o o o . . . .
 . . . . o o C o o . . . .
 . . . . o o o o o . . . .
 . . . . ^ o o o o . . . .
```

The ladder as a table, one slot at seven levels of common gear. Movement
saturates — the capability costs what it costs, so past level 4 every further
point goes to defence, which is why armour slowly gains on weapons as levels rise
(§5):

| level | budget | movement | defence | reach |
|---|---|---|---|---|
| 1 | 4 | 0 | 4 | 0 |
| 2 | 8 | 8 | 0 | 1 |
| 3 | 12 | 8 | 4 | 1 |
| 4 | 16 | 16 | 0 | 2 |
| 8 | 32 | 16 | 16 | 2 |
| 20 | 80 | 16 | 64 | 2 |
| 40 | 160 | 16 | 144 | 2 |

Nothing is spent on a capability the budget cannot buy outright: leggings off a
level-1 creature have four points and the hop costs eight, so they keep all four
and are armour rather than wasting them on a grant they will not get.

---

## 3. The trade, in play rather than in the item table

Two commanders of the same level, each carrying **four worn items off creatures
of that level — the same sixty-four points of budget**. One spent on every
movement grant it could afford; the other spent nothing on moving at all. What
each reaches, and what each survives against a sword off a creature of their own
level (cut 6, cleave 10; both stand at 44 hit points):

| build | budget | defence | cells reached | cut → | blows to kill | cleave → | blows to kill |
|---|---|---|---|---|---|---|---|
| mobile | 64 | 2 | 21 | 4 | 11 | 8 | 6 |
| armoured | 64 | 4 | 4 | 2 | **22** | 6 | 8 |

The armoured one survives twice as many cuts. The mobile one reaches five times
as many cells. Neither number was chosen: both fall out of the same sixty-four
points being spent in two different places, and there is no third source of
either.

(The cell counts are on the fixture board of §2, whose building, hole and wall
cost the mobile build three of the twenty-four cells it would reach on open
ground.)

---

## 4. A weapon deals what its budget bought

The catalogue's damage numbers are no longer numbers the fight reads. They are
the **weights** by which a weapon's attacks divide the item's effects axis — a
sword is "ten parts cut to sixteen parts cleave" whatever it is worth — and the
catalogue's own numbers come back exactly when that axis equals their sum. A
weapon with no item behind it reads at precisely that sum, which is why every row
of the catalogue in [combat.md](combat.md) is still the answer for one.

| level | budget | cut | cleave |
|---|---|---|---|
| 2 | 8 | 3 | 5 |
| 4 | 16 | 6 | 10 |
| 8 | 32 | 12 | 20 |
| 20 | 80 | 31 | 49 |
| reference | 26 | 10 | 16 |

The wait is bought by the cell, like every other cell in this report. A cleave
covers six, so six points of the item's movement axis take one turn off it and
twelve take two — and nothing takes it below one, because a turn is the smallest
thing there is:

| movement spent | cut waits | cleave waits |
|---|---|---|
| 0 | 1 | 3 |
| 6 | 1 | 2 |
| 12 | 1 | 1 |
| 18 | 1 | 1 |

**A shield is still a shield.** Its shove has no damage to divide, so no budget
gives it any: an *eternal* level-40 shield is worth 1280 points and its shove
still deals nothing at all. What it does is push, and that is all it does.

---

## 5. What the calibration actually produces

`POINTS_PER_DEFENCE = 16` is the one number in this work that was chosen rather
than derived from a price, so here is what it does. Two equals at each level,
each carrying four common worn items and a common sword off creatures of their
own level — a level-appropriate duel, all the way up the gradient:

| level | health | defence | cut | front → | blows | flank → | back → | back + high ground → | blows |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 26 | 0 | 2 | 2 | 13 | 3 | 4 | 6 | 5 |
| 2 | 32 | 0 | 3 | 3 | 11 | 4 | 6 | 9 | 4 |
| 3 | 38 | 1 | 5 | 4 | 10 | 6 | 9 | 14 | 3 |
| 4 | 44 | 2 | 6 | 4 | 11 | 7 | 10 | 16 | 3 |
| 8 | 68 | 6 | 12 | 6 | 12 | 12 | 18 | 30 | 3 |
| 20 | 140 | 18 | 31 | 13 | 11 | 28 | 44 | 75 | 2 |
| 40 | 260 | 38 | 62 | 24 | 11 | 55 | 86 | 148 | 2 |

**A front-on duel between equals takes about eleven blows at every level.** That
is the property worth having: the numeric layer scales without changing the shape
of a fight, which is what section 5's "raw numbers are the infinite axis" needs
if it is not to spongify the board. And a backstab from high ground ends it in
two or three, so **position is worth four to five times a front-on blow** at
every level too.

Both of those are shapes `reports/combat.md` already published, measured then
against a flat 8 points of armour and a flat catalogue weapon: 25 to 130 blows
front-on and position worth 6× to 11×. The direction is the same and the numbers
are tighter, because both sides of the comparison now scale together instead of
one being fixed.

---

## 6. The ability-score gate reaches the numbers a fight is decided by

One suit and one sword off level-8 creatures, read by six wearers. The objects
are the same objects throughout — the gate is on the reading, never on the item:

| score | fraction of the item | chestplate reach | defence | cut | cleave | cells reached |
|---|---|---|---|---|---|---|
| 8 | 100% | 2 | 6 | 12 | 20 | 21 |
| 6 | 75% | 1 | 4 | 9 | 15 | 8 |
| 4 | 50% | 1 | 3 | 6 | 10 | 8 |
| 3 | 37% | 0 | 2 | 5 | 7 | 4 |
| 2 | 25% | 0 | 1 | 3 | 5 | 4 |
| 0 | 0% | 0 | 0 | 0 | 0 | 4 |

A wearer three-quarters of the way to the item's level stops two-thirds as much,
hits for three-quarters as much, and loses a cell of their queen. A wearer at a
quarter is a bare commander that happens to be wearing something. And the items
are untouched by any of it — the same four lines print before and after:

```
common armour boots      L8 P=32 mov=4  def=28 eff=0 dex [] common boots
common armour chestplate L8 P=32 mov=16 def=16 eff=0 con [] common chestplate
common armour helmet     L8 P=32 mov=0  def=32 eff=0 con [] common helmet
common armour leggings   L8 P=32 mov=8  def=24 eff=0 dex [] common leggings
common weapon hand       L8 P=32 mov=0  def=0  eff=32 str [sword:32] common sword
```

**Where the score comes from, and what is honestly missing.** Section 2 puts
ability scores on a character sheet, and there is no character sheet in the
project yet. `Commander` gained the smallest thing that lets the gate reach the
board: a dictionary of scores by ability name, and nothing else about a
character. A score nobody has recorded is *not* zero — zero is a real score, and
a commander with six of them could wear nothing — so an unrecorded score reads
the item at its own level, which is to say in full. Recording one is what makes
the gate bite. When the character sheet arrives, it owns these six numbers and
this dictionary goes.

---

## 7. The stop condition: what moved in the published report, and why

The task said to report the before and after rather than quietly restating the
report if replacing a stub moved a number `reports/combat.md` publishes. It did,
in one place: **the scripted three-commander match**, whose commanders are levels
1, 2 and 3 and whose gear is now level-1, level-2 and level-3 gear.

| | before | after | why |
|---|---|---|---|
| #1 defence | 8 | 1 | boots and a chestplate off level-3 creatures are 19 points, and 19 points are 1 of reduction |
| #2 defence | 2 | 0 | boots off a level-2 creature are 4 points |
| #3 defence | 4 | 0 | boots and a helmet off level-1 creatures are 4 points |
| #2's cut | 10 | 3 | a common level-2 sword has 8 points of effects to divide 10:16 |
| #3's thrust | 8 | 4 | a common level-1 spear has 4 |
| #3's backstab on #1 | 8 dealt | 7 dealt | 4 doubled is 8, less 1 of armour |
| #1's health at the end | 25/38 | 23/38 | three blows of 7, 5 and 3 instead of 8, 4 and 1 |
| the conclusion | `over rounds=6 survivors=1 winner=#1` | **unchanged** | the two removals are shoves, and a shove is decided by the ground |

**Why it moved that far.** The old constants gave a level-3 commander 8 points of
armour — nearly the whole of a catalogue sword's cut — while a level-3 *weapon*
under the budget is worth 12 points in total. The stub was not merely a
placeholder for the number; it was a placeholder at the wrong scale, and it was
only ever compared against catalogue weapons that are worth roughly a level-8
item. Now both sides of the comparison are level-appropriate and the fight at
level 3 looks like the fight at level 40 (§5).

Three published numbers that did **not** move, and were checked: the world
fingerprint `d4e31b0904ff45c0`; the real-time encounter's conclusion
`over rounds=3 survivors=1 winner=#1` (which *did* move a cycle later, to
`rounds=4`, when the encounter's own weapons were put on the budget too — see
`reports/encounter-item-backed.md`; the winner is still `#1`); and the whole
minion-versus-minion layer,
which reads no item, no level and no hit point and is still two lines long.

The scripted match's own header table, and the transcript, are updated in
`sim/scripted_match.gd` and `reports/combat.md`. #1 is the one with the lucky
drop — a **rare** chestplate off a level-3 creature is 27 points where a common
one is 12, and sixteen of them buy the two-cell queen the decisions use. The
other two could not have afforded it at their level and rarity, which is now the
whole of why they move like kings and #1 moves like a queen.

---

## 8. What is checked, and how it is shown to bite

**360 checks** in `tests/test_combat_pieces.gd` (was 343) and **339** in
`tests/test_combat_resolution.gd` (was 314). The new ones are the price list, the
chestplate ladder as cells on a board, the leggings that cannot afford their hop,
the defence table by level, the weapon's damage and cooldown tables, the trade at
one budget, and the gate — each paired, as everything in these suites is, with a
run in which the rule's own premise is broken and the same numbers are required
to stop holding.

The rules whose premise is the code itself are broken by editing the code. Both
harnesses were run one at a time with nothing else against the repository:

```
./tools/piece_mutations.sh        # all 19 broken rules were caught
./tools/resolution_mutations.sh   # all 46 broken rules were caught
```

Both runs are written out in full, in
[piece-mutations-evidence.txt](piece-mutations-evidence.txt) and
[combat-mutations-evidence.txt](combat-mutations-evidence.txt).

Ten mutations name a rule this work introduced or reshaped -- four in the piece
harness and six in the resolution one: a chestplate
granting a slide it did not pay for; leggings granting the hop they did not pay
for; a chestplate ignoring §3.4's two-cell cap; a grant costing one point however
far it reaches; a point of budget being a point of reduction; what is in a
commander's hands not defending it; every wearer reading every item in full; a
weapon dealing the catalogue's damage whatever it is worth; a weapon with no
damage to divide still dealing its budget; and a cooldown bought down by the
point rather than by the cell.

**The structural claim about the two layers changed, on purpose, and is
stronger.** `tests/test_items.gd` used to require that no file naming an item
class named a combat one. That was the right rule while the layers had not met;
they meet now, in `sim/armour.gd`, `sim/weapon.gd`, `sim/commander.gd` and
`sim/scripted_match.gd`. What survives is the *direction*: the item layer is
found by which files **declare** its class names, no file of it names a class of
the combat layer, and at least one combat file names an item class — both sides
asserted, because a rule with nothing on either side of it is not a rule. The
fight reads items; items never read the fight.
