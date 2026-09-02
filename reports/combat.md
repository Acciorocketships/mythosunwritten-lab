# Turn economy, the two-layer damage matrix, shoves and N commanders

The third layer of the combat core, and the first that can be played to a
conclusion. The [board layer](combat-board.md) reads the generated ground as a
lattice of cells; the [piece layer](combat-pieces.md) puts an army on it and
answers *what may this piece legally do*; this layer answers the next question —
**what happens when it does it** — and adds the one thing that turns a set of
legal moves into a game: whose turn it is, and how much a turn buys.

A match now runs end to end from a written-down list of decisions, headless, in
six rounds, and prints the same bytes in any two processes:

```
./run_match.sh
```

---

## The shape of it

Four new files under `sim/`, and one small one that lets a board be typed out.

| file | what it is |
|---|---|
| `damage.gd` | the one resolution seam, the modifiers, and the level scaling |
| `combat_resolution.gd` | what happens in a reached cell: capture, strike, shove |
| `combat_match.gd` | the turn economy, for any number of commanders |
| `scripted_match.gd` | one whole match as a constant, for the headless command |
| `board_sketch.gd` | a board typed out one character per cell |

`Piece` grew three numbers — a level, the health it has left, and the defence it
stands behind — and two questions, `max_health()` and `defence()`, that the two
tiers answer differently. Nothing else moved.

---

## The turn economy

**One round is one turn per commander.** Turn order is the commanders' ids,
ascending; a round is one pass down that list. Nothing anywhere counts to two, so
five commanders are the same loop as two, which the suite checks by playing two,
three and five and writing out the order and the round number for each.

A turn buys exactly three things, each once:

| | what it is | spent by |
|---|---|---|
| **the move** | the commander steps, onto any cell its loadout reaches | `move_commander()` |
| **the weapon action** | one attack, resolving against every piece in its pattern | `attack()` |
| **one minion** | one of *this* commander's minions, for one move or one capture | `activate_minion()` |

**Turning is free** and is not one of the three. `face()` may be called any
number of times and touches none of the three flags — which is checkable rather
than merely stated, because those three flags are the entire budget. The suite
turns a commander through four quarter turns and then finds all three actions
still available.

"And no more" is enforced by refusal, not by trust. A second move returns false
*and leaves the commander where it was*; a second minion activation returns false
*and leaves that minion where it was*; another commander's minion is refused on
your turn and accepted on its owner's, which is what shows the refusal was about
ownership. Every one of those is asserted on the board's state, not on the
return value alone.

An action that could not have happened does **not** spend its slot. An attack
still on its cooldown is refused, and the commander may still swing with a
different one. Being unable to act is not the same as having acted.

### A cooldown is counted in rounds, because a turn *is* a round

This class carried a per-commander turn count for cooldowns to be measured
against, until the mutation check asked whether anything could tell that count
apart from `round_number`. Nothing could. Every living commander takes exactly
one turn between two round increments, so the two numbers start equal and are
advanced by the same passes forever — they are one number counted twice.

So the count is gone and `turn_number()` returns the round. It would stop being
one number the moment a commander could join a match in progress, skip a turn, or
take two; none of those exists, and when one does, the per-commander count comes
back *with a test that can see the difference*. This is the same finding the
piece layer made about its three movement modes, made a second time by the same
method.

---

## The damage matrix

Two layers that scale independently. Section 3.7 of the design, implemented as
three functions, because one of the four pairings is a different kind of thing.

| attacker → target | rule | reads a level? | layer |
|---|---|---|---|
| minion → minion | **binary capture** — the target dies, the attacker takes the cell | no | tactical |
| minion → player | damage = $f(\text{minion level})$, less the player's defence | yes | numeric |
| player → minion | weapon damage, less the minion's level-scaled defence, against its level-scaled health | yes | numeric |
| player → player | weapon damage, less defence | yes | numeric |

### The capture reads nothing

`CombatResolution.capture()` removes the target and moves the attacker onto its
cell. Those two operations are its entire body: no level, no health, no defence,
no die, and nothing it could fail on. A level-1 Toadstool takes a level-40 Ent
and a level-40 Ent takes a level-1 Toadstool by the same two lines, and a Cat on
its last hit point takes a full-health Ent thirty-nine levels above it — all
three are in the suite, with the numbers written out.

That is what keeps the tactical layer from ever going spongy however far the
numeric one has scaled, which is the keystone of section 3.1.

### The seam

Every point of player-facing damage in the game is returned from one function:

```gdscript
Damage.resolve(power, multiplier, defence) -> int
    = max(MINIMUM, floor(power * multiplier / 100) - defence)
```

$$\text{dealt} = \max\left(1,\ \left\lfloor \frac{P \cdot m}{100} \right\rfloor - A\right)$$

for a power $P$, a modifier $m$ in hundredths, and a defence $A$. The modifier
multiplies the *attack*, not the result, so terrain and facing make a blow land
harder rather than make armour work less. Everything is integer arithmetic, so
two runs cannot drift.

The suite checks the seam by reading the sources rather than by trusting the
arrangement, and **it finds the files to read by opening `sim/`, not from a list
typed into the test**. Two properties, at two scopes, and the difference between
them is deliberate:

* **One seam, over every file.** Exactly one of the 52 files under `sim/`
  contains the string `Damage.resolve(`, and it contains it exactly once. No
  exceptions, no subset — the check reads whatever the directory holds.
* **No random source, over the 24 files that name the combat layer.** A file is
  a combat file when it names one of the layer's own class names — `LayerCheck`'s
  list of what the render layer may not name, plus `CombatBoard` — and no such
  file names `randi`, `randf`, `randomize`, a `RandomNumberGenerator` or the
  project's own `SimRng` at all. That scope is 24 files rather than all 52
  because **generation is seeded-random by design**: terrain, biomes, islands,
  settlements, paths and scatter all draw on `SimRng`, so forbidding it across
  the whole directory would forbid the world rather than the fight. One file
  names the combat layer without being part of one — `sim/world.gd`, which holds
  the roster and hands out a board while seeding the generator — and it is
  excused by name; the suite then requires that it calls no rule of a fight, so
  the excuse cannot quietly become a place to put one.

The suite also reads the body of `capture()` and requires that it mentions
neither `Damage` nor `health` nor `level`.

**Both halves are shown to bite, not asserted.** The scan used to read a list of
fourteen paths written into the test, and ten combat files had joined `sim/`
since — `combat_policy.gd`, `combat_board.gd`, `combat_board_builder.gd`,
`combat_snap.gd`, `combatant.gd`, `combatant_roster.gd`, `board_sketch.gd`,
`encounter.gd`, `scripted_encounter.gd` and `simulation.gd`. A second
`Damage.resolve(...)` call added to `sim/combat_policy.gd` passed all 23 suites
and 172 929 checks under that list; it now fails, and so does an unused `randi()`
in the same file. Both are in `tools/resolution_mutations.sh`, which requires
every one of its 46 broken rules to be caught. The run is written out in
[the source-scan evidence](combat-source-scan-evidence.md).

**The dice question is left open here, deliberately, and this is the seam it is
left at.** Section 13 of the design lists three options — a to-hit roll against
an armour class, armour as flat damage reduction, or both — and says it leans
towards rolls while naming the constraint plainly: dice variance trades away
exact multi-step planning. This layer implements armour as damage reduction and
resolves everything deterministically. Whether an attack roll is added is
decided in the items phase, and if it is, it is an edit to `Damage.resolve()`
and to nothing else, because there is nowhere else it could go.

Why not decide it now? Because an item's power budget is rarity times the level
of what dropped it, split across movement, defence and effects, and a high-level
item under-performs for a user whose ability score is too low. Both of those are
the items phase's arithmetic and both are what a dice model would have to be
balanced against; choosing one before that arithmetic exists is choosing it with
no way to judge it. Two smaller reasons point the same way: every number below is
asserted exactly, which is only possible while the layer is deterministic, and
the whole project's byte-identical-across-processes property would be at risk
from a random stream whose discipline has not been settled for combat.

**The minion layer stays deterministic permanently.** That is not a deferral —
it is what makes the tactical layer worth having.

> **Since settled.** The items phase made the decision: armour stays flat damage
> reduction, every attack lands, and a small centred die says *how hard* a blow
> lands rather than *whether* it lands. See [reports/dice.md](dice.md) for the
> three options costed and the measurement. Two things about this report survive
> that decision intact. **Every exact number below is still the arithmetic** —
> the die is one more multiplier, and switching it off is passing `STEADY`, which
> collapses `resolve()` digit for digit to the function described here. And the
> prediction above was right about the arithmetic: the model is entirely inside
> `Damage.resolve()`. It was incomplete about the plumbing — four further files
> carry one integer, the fight's seed, from the match down to the seam, and
> `reports/dice.md` accounts for each. The transcripts quoted below were produced
> with the die switched off and are still reproducible that way; a fight with a
> seed writes an extra `dice` line at its head and a `swing=` field on every blow.

### Where the numbers come from

Only the minion tier scales with level *here*, because that is what the matrix
asks for: a player's damage comes off a weapon and a player's defence off armour,
and both of those are level-scaled by the item power budget instead — an item is
worth the level of what dropped it, so a player's numbers rise with the gradient
without a level term appearing in this file. That is
[reports/loadout.md](loadout.md), and the row for a commander's defence below is
the only line of this table that it changed.

| | formula | level 1 | level 8 | level 40 |
|---|---|---|---|---|
| minion health | $6 + 4L$ | 10 | 38 | 166 |
| minion defence | $1 + L$ | 2 | 9 | 41 |
| minion blow (vs a player) | $2 + 2L$ | 4 | 18 | 82 |
| commander health | $20 + 6L$ | 26 | 68 | 260 |
| commander defence | $\lfloor \sum \text{defence points} / 16 \rfloor$ over everything carried | — | — | — |

Weapons carry their shapes, and the design's are these. The damage column is now
read as the *weights* by which a weapon's attacks divide the effects axis of the
item behind it; the numbers below are what a weapon with no item behind it deals,
which is to say the reference the catalogue is written at
([loadout.md §4](loadout.md)):

| weapon | attack | cells | cooldown | damage |
|---|---|---|---|---|
| spear | thrust | 2 | 1 | 8 |
| dagger | stab | 2 | 1 | 6 |
| sword | cut | 3 | 1 | 10 |
| sword | cleave | 6 | 3 | 16 |
| bow | loose | 248 | 3 | 12 |
| staff | fireball | 9 | 5 | 4 |
| flail | sweep | 8 | 1 | 5 |
| shield | shove | 1 | 2 | 0, pushes 1 |

### A cheap area attack cannot clear an army

The design names this constraint in as many words, so it is checked with nine
minions standing in the nine cells of one fireball:

| minion level | health | defence | cleave 16 → | blows to kill | fireball 4 → | blows to kill |
|---|---|---|---|---|---|---|
| 1 | 10 | 2 | 14 | **1** | 2 | 5 |
| 3 | 18 | 4 | 12 | 2 | 1 | 18 |
| 8 | 38 | 9 | 7 | 6 | 1 | 38 |
| 20 | 86 | 21 | 1 | 86 | 1 | 86 |

Nine cells of fireball leave nine minions standing, every time. One cleave kills
a level-1 minion outright and needs six landings on a level-8 one — the
out-scaling at the frontier that section 3.1 calls for, and it falls out of the
weapon numbers meeting the level scaling rather than being a rule anywhere.

---

## Terrain and facing

Three modifiers, each with the number it applies. They **multiply**, so a
backstab from high ground is $\times 3$ and not $\times 2.5$.

| rule | when it applies | multiplier |
|---|---|---|
| **high ground** | the attacker's cell stands $\ge 1.0$ world unit above the target's | $\times 1.5$ |
| **flank** | the attacker is off the target's side | $\times 1.5$ |
| **backstab** | the attacker is behind the target | $\times 2$ |

The relation is one comparison. The vector from the target to the attacker is
rotated into the target's own frame — the frame every pattern in the layer is
written in — and read off: mostly ahead is the front, mostly behind is the back,
and anything shallower than the diagonal is a flank. **A target with no facing
has no back to stab**, so every blow on a minion is a front-on one, which is
what section 3.5's facing-free minion tier means arithmetically.

Four attackers stand around one target with the same spear, on level ground,
differing only in where they stand:

| from | relation | multiplier | 8 becomes |
|---|---|---|---|
| in front | front | $\times 1$ | 8 |
| either side | flank | $\times 1.5$ | 12 |
| behind | back | $\times 2$ | 16 |
| behind, from 2 units up | back + high ground | $\times 3$ | 24 |

Each of those is paired with a second run in which the target is turned to face
its attacker, and the same number is required to stop holding.

**What that is worth in a duel.** A commander with a sword and 8 points of
armour, against another the same:

| defender level | health | front | flank | back | back + high ground |
|---|---|---|---|---|---|
| 1 | 26 | 13 blows | 4 | 3 | **2** |
| 5 | 50 | 25 | 8 | 5 | **3** |
| 20 | 140 | 70 | 20 | 12 | **7** |
| 40 | 260 | 130 | 38 | 22 | **12** |

Position is worth six to eleven times the damage. A front-on slugging match
between equals is a stalemate; the fight is decided by who gets behind whom. That
is the numeric layer being pushed onto the chess layer by arithmetic rather than
by a rule.

---

## The shove

A shove is **not a separate mechanic**. It is an attack whose `push` is more than
zero: a pattern of cells written for a wielder facing north, rotated by the
wielder's facing, clipped to the board, on a cooldown. The `shield` in the weapon
catalogue carries one — one cell ahead, no damage, a push of one, two turns.

What makes it lethal is not the item but where the target is standing. The push
goes directly away from the attacker, and four things can be in the cell it is
about to enter, checked in the order that matters:

1. **a hole** — open water, a chasm, the void off a floating island's rim: the
   target is removed instantly;
2. **a fall deeper than a piece can climb down** (`CombatBoard.STEP_DOWN`, 2
   world units): removed instantly;
3. **anything solid, anyone standing there, or the board's edge**: the push stops
   and nothing happens;
4. **plain ground**: the target takes one step and is otherwise untouched.

**A push of $n$ cells is that rule applied $n$ times, once per cell, not once at
the far end.** The target is walked one cell at a time and the four checks are
asked afresh at each of them, so it stops or dies at the *first* cell that stops
or kills it and nothing is carried over a chasm, a building, a pit or another
piece by having been shoved harder. A push stopped part-way leaves the target
standing on the last cell it legally reached, and the outcome names that cell —
or, when it dies part-way, the cell it died in — never the cell the push was
aimed at. `Attack.push` therefore means what it says for any distance, which is
what the items phase needs: a shove of more than one cell is a natural effect for
a generated weapon to carry, and it now obeys the same four clauses the shield's
does.

The suite shoves a level-8 commander at full health — 68 hit points behind a
tier-3 chestplate — into a chasm and over a lip, and it dies both times, taking
its minions with it by the same king rule as any other death. The third case is
what shows the first two are about the ground rather than about the shove: the
same attack over plain ground moves the target one cell and leaves its health
alone.

### One cell at a time, measured

The four configurations below are the ones the review reproduced, each with the
feature on the cell a push of **two** has to cross and plain ground on the cell
it was aimed at. Reading only the landing cell put an untouched commander down on
the far side of all four; walking the push stops or kills it at the feature.

| the cell crossed | reading only where it lands | walking one cell at a time |
|---|---|---|
| a chasm at (1,2) | pushed to (1,1), 68/68 | **removed at (1,2)** |
| a building footprint at (5,2) | pushed to (5,1), 68/68 | **stopped at (5,3)**, 68/68 |
| an eight-unit pit at (9,2) | pushed to (9,1), 68/68 | **removed at (9,2)** |
| an Ent standing at (11,2) | pushed to (11,1), 68/68 | **stopped at (11,3)**, 68/68 |

Partway stops name the cell reached: aimed three cells from (5,4), the target
walks one cell and is stopped by the building, and the outcome reads `(5,3)`, not
the aimed `(5,1)`; aimed three cells from (1,4) it walks one cell and dies in the
chasm at `(1,2)`; aimed three cells from (7,1) it walks to the last row and the
board's edge ends the push at `(7,0)`.

The distance is now read *as cells*, and `tools/resolution_mutations.sh` breaks it
in both directions to prove the suite notices. Clamping `Attack.push` to one
(`mini(1, maxi(0, pushes))`) fails 5 checks; tripling it (`3 * maxi(0, pushes)`)
fails 6; restoring the single check at the far end fails as well. Before this
change the clamp broke nothing at all — the multi-cell path had never been
executed, because the shield is the only item in the catalogue that pushes and it
pushes one. The shield is untouched by all of this: a push of one is one
application of the same rule, and the scripted match's transcript is byte-for-byte
what it was.

And because it is an ordinary attack, it obeys everything one obeys. Facing the
wrong way, the pattern covers the cell behind and the target is not touched;
turned back, the same call reaches it; and having swung once, the next two turns
are refused with `on cooldown`.

---

## N commanders, no fixed sides

There is no notion of a side anywhere in this layer. Capture and targeting are
one comparison — the attacker's owner id against the target's — so any commander
may target any other, and a commander's own minions are the only pieces it cannot
take. The suite walks all six ordered pairs of three commanders and captures in
every one of them, then checks that a minion may not take one of its own.

Turn order generalises for the same reason: it is a list, and a round is a pass
down it. Two, three and five commanders are played and written out.

---

## The scripted match

`sim/scripted_match.gd` holds a board, eleven pieces and every decision of a
whole match as constants. Nothing in it decides anything — there is no policy, no
search and no language model, which is what lets the outcome be asserted against
exact numbers.

```
 y=0   . . . . . . . . . . . . .
 y=1   . . . . . . ~ ~ . . . . .     a chasm at (6,1) and (7,1)
 y=2   . . . . . . . . . . . . .
 …
 y=8   . . . . . . . . . v v . .     a pit floor eight units down
 y=9   . . . . . . . . v v v . .
```

Every commander is equipped out of the item layer, at its own level — gear is
worth the creature it came off, so a level-1 commander carries level-1 gear:

| | level | weapon | armour | mov/def points | defence | health |
|---|---|---|---|---|---|---|
| #1 | 3 | shield, common L3, all defence | common L3 boots, **rare** L3 chestplate | 4/8, 16/11, 0/12 | 1 | 38 |
| #2 | 2 | sword, common L2 | common L2 boots | 4/4 | 0 | 32 |
| #3 | 1 | spear, common L1 | common L1 boots, common L1 helmet | 4/0, 0/4 | 0 | 26 |

#1 is the one with the lucky drop: a rare chestplate off a level-3 creature is 27
points where a common one is 12, and 16 of them buy the two-cell queen-like slide
its decisions use. The other two could not have afforded it at their level and
rarity, which is the whole of why they move like kings and #1 moves like a queen.
The defences are small because the gear is: two items off level-3 creatures are
19 points between them, and 16 points buy one of reduction. What that changed
against the numbers this report used to publish is tabulated in
[loadout.md §7](loadout.md).

Two holes of two different kinds, and a commander goes into each by a different
branch of the same rule. The transcript, in full:

```
board 2e033e9fc43c33d1 cells=169 standable=167 holes=2 cliffs=15
commanders 3
  #1 commander owner=1 level=3 hp=38/38 def=1 power=0
  #2 commander owner=2 level=2 hp=32/32 def=0 power=0
  #3 commander owner=3 level=1 hp=26/26 def=0 power=0
  #4 frog owner=1 level=3 hp=18/18 def=4 power=8
  #5 cat owner=1 level=3 hp=18/18 def=4 power=8
  #6 ent owner=1 level=3 hp=18/18 def=4 power=8
  #7 toadstool owner=2 level=2 hp=14/14 def=3 power=6
  #8 ent owner=2 level=2 hp=14/14 def=3 power=6
  #9 cat owner=2 level=2 hp=14/14 def=3 power=6
  #10 cat owner=3 level=1 hp=10/10 def=2 power=4
  #11 frog owner=3 level=1 hp=10/10 def=2 power=4
round 1 turn #1 at (6,6) facing=north hp=38/38 def=1 shield + boots(4/8) chestplate(16/11)
  move #1 (6,6)->(6,5)
  minion capture #4 takes #7 at (5,2)
round 1 turn #2 at (6,2) facing=south hp=32/32 def=0 sword + boots(4/4)
  face #2 west
  attack #2 cut cells=3 hits=1
    hit #2->#4 power=3 x100 front def=4 dealt=1 hp=17/18
  minion move #8 (8,2)->(8,4)
round 1 turn #3 at (9,7) facing=north hp=26/26 def=0 spear + boots(4/0) helmet(0/4)
  move #3 (9,7)->(8,6)
  minion capture #11 takes #8 at (8,4)
round 2 turn #1 at (6,5) facing=north hp=38/38 def=1 shield + boots(4/8) chestplate(16/11)
  move #1 (6,5)->(6,3)
  attack #1 shove cells=1 hits=1
    hit #1->#2 power=0 x150 flank def=0 dealt=0 hp=32/32 shoved into (6,1) removed=2
  commander #2 is out
  minion move #5 (7,6)->(8,5)
round 2 turn #3 at (8,6) facing=north hp=26/26 def=0 spear + boots(4/0) helmet(0/4)
  move #3 (8,6)->(7,6)
  minion capture #10 takes #5 at (8,5)
round 3 turn #1 at (6,3) facing=north hp=38/38 def=1 shield + boots(4/8) chestplate(16/11)
  move #1 (6,3)->(6,5)
  refused attack #1: on cooldown
  minion move #4 (5,2)->(7,3)
round 3 turn #3 at (7,6) facing=north hp=26/26 def=0 spear + boots(4/0) helmet(0/4)
  move #3 (7,6)->(6,6)
  face #3 north
  attack #3 thrust cells=2 hits=1
    hit #3->#1 power=4 x200 back def=1 dealt=7 hp=31/38
  minion move #10 (8,5)->(7,4)
round 4 turn #1 at (6,5) facing=north hp=31/38 def=1 shield + boots(4/8) chestplate(16/11)
  move #1 (6,5)->(8,7)
  face #1 south
  minion move #4 (7,3)->(8,5)
round 4 turn #3 at (6,6) facing=north hp=26/26 def=0 spear + boots(4/0) helmet(0/4)
  move #3 (6,6)->(7,7)
  face #3 east
  attack #3 thrust cells=2 hits=1
    hit #3->#1 power=4 x150 flank def=1 dealt=5 hp=26/38
  minion capture #10 takes #4 at (8,5)
round 5 turn #1 at (8,7) facing=south hp=26/38 def=1 shield + boots(4/8) chestplate(16/11)
  minion move #6 (5,6)->(5,7)
round 5 turn #3 at (7,7) facing=east hp=26/26 def=0 spear + boots(4/0) helmet(0/4)
  move #3 (7,7)->(8,8)
  face #3 north
  attack #3 thrust cells=2 hits=1
    hit #3->#1 power=4 x100 front def=1 dealt=3 hp=23/38
  minion move #10 (8,5)->(7,6)
round 6 turn #1 at (8,7) facing=south hp=23/38 def=1 shield + boots(4/8) chestplate(16/11)
  attack #1 shove cells=1 hits=1
    hit #1->#3 power=0 x100 front def=0 dealt=0 hp=26/26 shoved into (8,9) removed=3
  commander #3 is out
over rounds=6 survivors=1 winner=#1
```

Five things in that are worth reading twice.

* **Round 1, #3 takes #2's Ent** while it is nowhere near #1 and allied with
  nobody. A level-1 Frog takes a level-2 Ent; the levels do not enter into it.
* **Round 2, #1 shoves #2 into the chasm** at full health, and `removed=2` is the
  king rule: #2 and the one minion it still owned leave together.
* **Round 3, #1's shove is refused** — the cooldown, in the transcript.
* **Round 3, #3 backstabs #1 for 7** — a level-1 spear worth 4, doubled to 8,
  less 1 of armour. Round 4 it flanks for 5, and round 5, from the front, for 3.
  Three numbers off one weapon, decided entirely by where it stood — and the
  weapon's 4 is itself the whole effects axis of a common item off a level-1
  creature, so where the spear's number comes from is now the same question as
  where the armour's does.
* **Round 6, #1 shoves #3 into the pit**, `removed=3`, and the match is over.

---

## Determinism

The transcript is a pure function of `scripted_match.gd`: the board is typed out
rather than generated, the decisions are a constant, nothing under it reads a
clock or a random number, and every quantity in the arithmetic is an integer. The
suite plays it twice in the same process and compares, and then runs
`bin/match_main.gd` twice as **separate subprocesses** and compares the bytes —
which is the half that matters, because a second process lays its memory out
differently and can therefore see a dependence on an address or on the order a
dictionary happens to iterate in that in-process repetition cannot.

---

## What is checked, and how it is shown to bite

**339 checks** in `tests/test_combat_resolution.gd`, every one written out as an
exact number. Nothing is compared to a figure the code under test produced.

Where a rule has a premise that can be broken from outside — a level, a piece of
armour, a facing, the ground under a cell — the check is paired with a second run
in which that premise is broken and the same number is required to stop holding:
the armour comes off and the blow is 8 bigger, the target turns to face its
attacker and the flank becomes a front, the ground beyond the target becomes
plain and the shove becomes a step.

The rules whose premise is the code itself are broken by editing the code:

```
./tools/resolution_mutations.sh
```

It replaces one line of `sim/` at a time — the line the rule is actually written
on — runs the resolution suite, and records whether the suite noticed. Every edit
is undone afterwards, including on an interrupted run. All 46 are caught, six of
them naming rules the item layer brought in: a point of budget being a point of
reduction, what is in a commander's hands not defending it, every wearer reading
every item in full, a weapon dealing the catalogue's damage whatever it is worth,
a weapon with no damage to divide still dealing its budget, and a cooldown bought
down by the point rather than by the cell. The full table is in
[combat-mutations-evidence.txt](combat-mutations-evidence.txt).

**It was not green the first time, and that is the point.** The first run left
three rules unnoticed:

* *a minion may be sent anywhere on the board* — nothing checked that the match
  refuses an illegal minion destination. A check was added.
* *a minion takes the commander's cell when it strikes* — the assertion existed,
  but it could not fail, because `PieceMap.move_piece()` already refuses an
  occupied cell. The distinction only becomes visible once the blow **kills** and
  the cell is free; a check for that case was added, and it bites.
* *cooldowns are counted in everybody's turns* — uncatchable, because a
  commander's own turn count and the round number are provably the same number.
  That is what collapsed the per-commander count out of the layer.

One found a missing test, one found an assertion that could not fail, and one
found a distinction the code was not making. None would have shown up in a suite
that only checks that the right answers come out.

---

## The stop condition

The task said to stop and report the numbers if the binary capture rule and the
numeric layer could not coexist — if some level gap made a commander either
unkillable or trivially killable. **They coexist**, and here are the two ends.

**Nothing is unkillable.** `Damage.MINIMUM` is 1: a blow that armour would
otherwise cancel entirely still lands for one point. The weakest weapon in the
catalogue, with no positioning at all, against a hundred points of armour, deals
1. That floor is not a softener bolted on afterwards — it is the condition under
which reduction-style armour and an unbounded level axis can share a board at
all, and without it there would be a level gap past which an attack does
literally nothing.

**Nothing is trivially killable.** The heaviest blow the catalogue can produce —
a cleave, backstabbing from high ground, $16 \times 3 = 48$ less 8 of armour = 40
— needs **7 landings** to drop a level-40 commander's 260 hit points, and the
cleave waits three turns between them.

**The gap is carried by the numeric layer and answered by the tactical one.**
Against a level-20 minion a cleave deals 1 of 86, and 86 landings is not a plan;
against the same minion, any minion of any level captures it in one move. And a
level-40 minion's blow drops a level-5 commander in a single hit, so the
higher-level army is genuinely dangerous rather than merely tough. The only
scalable path against a superior foe is therefore to out-position them — which is
the mechanically-forced chess layer section 3.1 asks for, arriving as a
consequence of the numbers rather than as a rule.

---

## Boundaries kept

* **No to-hit roll and no armour class.** The layer is deterministic; the roll
  model was the items phase's decision, at `Damage.resolve()` and nowhere else.
  It has since been made, and it is *not* a to-hit roll — see
  [reports/dice.md](dice.md).
* **No language-model or chess-engine decision-making.** Every decision in the
  match is a constant in `scripted_match.gd`.
* **No real-time overworld interaction.** Entering and leaving combat — the snap
  onto the board and back — is the next task. Nothing here knows a fight has a
  beginning.

## What this layer does not answer

* **Line of sight.** The board carries `blocks_line` and nothing here reads it;
  an attack pattern is clipped to the board and to nothing else.
* **Where an army comes from.** Minions are placed, not summoned; the item that
  summons them is the items phase's.
* **Who should do what.** There is no policy of any kind — section 3.9's minion
  AI is a later task, and this layer exists so that one has rules to play by.
