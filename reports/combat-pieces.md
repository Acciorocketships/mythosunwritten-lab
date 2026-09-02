# The two-tier army: four minions, commanders with facing, movement as armour

The second layer of the combat core, and the first that has anything standing on
the board. The [board layer](combat-board.md) reads the generated ground as a
lattice of cells and says what each one is; this layer puts pieces on it and
answers one question about them — **what may this piece legally do?**

Nothing here has hit points, a damage number or a notion of whose turn it is.
Those are the next task's. What is here is the shape of the army: four minions
that move the way chess pieces move, commanders that have a front and wear their
movement as gear, and one resolver that turns any of them into a list of cells.

---

## The shape of it

Ten files under `sim/`, and the whole layer is a small vocabulary used three
times over.

| file | what it is |
|---|---|
| `piece_geometry.gd` | directions, quarter turns, and three pattern generators |
| `move_grant.gd` | one way a piece may leave its cell: a landing or a slide |
| `piece.gd` | something standing on a cell: an id, an owner, a cell, an appearance |
| `minion.gd` | the four, as grants |
| `armour.gd` | an item worn in a slot, which may carry a movement grant |
| `attack.gd` | a pattern of cells and a cooldown in turns |
| `weapon.gd` | an item carrying one or more attacks |
| `commander.gd` | a piece with a facing, a loadout and a weapon |
| `piece_map.gd` | who is standing where, and the king rule |
| `legal_moves.gd` | the one resolver, for every piece in the game |

The load-bearing idea is that **a minion, a pair of boots and a fireball are all
the same kind of thing**: a list of lattice offsets. A Cat is a slide along four
diagonals; a chestplate is a slide of two cells along eight; a bow is a ring of
offsets at a distance. There is no branch anywhere in `legal_moves.gd` that asks
which minion it is holding or which weapon a commander wields.

### A step and a jump are the same rule

There were nearly three kinds of movement grant — a step, a slide and a hop —
and there are two, because a step and a hop turned out to be the same thing
written twice. A king's step and a knight's leap differ only in how long the
offset is: **neither reads anything between where it started and where it lands**,
and for a one-cell offset there is nothing between to read. So a chess knight
"jumps over" pieces not because it has a power the king lacks, but because it is
a landing pattern with an offset long enough for the question to arise.

That is not a tidying-up after the fact. The
[mutation check](#what-is-checked-and-how-it-is-shown-to-bite) below is what
found it: swapping the Frog's grant from `hop` to `step` changed nothing the
suite could see, because it changed nothing at all. A distinction no mutation of
it can break is a distinction the code does not make.

---

## The four minions

| minion | analog | moves | captures |
|---|---|---|---|
| **Toadstool** | pawn | one cardinal cell | one **diagonal** cell |
| **Cat** | bishop | diagonal lines until blocked | the same |
| **Ent** | rook | cardinal lines until blocked | the same |
| **Frog** | knight | an L-hop over everything | the same |

The Toadstool is the one whose two patterns differ, and it differs **without a
facing**. A chess pawn walks forwards because it has a front; this one walks on
all four cardinals because it does not. That is the whole of what removing facing
from the minion tier costs, and it is what makes a minion's legal moves a
function of the board and of who occupies it and of nothing the piece carries.
The suite checks that literally: it walks each minion's property list and
requires that no minion carries a property called `facing` at all, not even an
unused one.

---

## The board fixture

Every pattern below is checked against a board typed out by hand, and against a
cell list written out in full. The board layer is tested against the generated
world because what it claims is that it reads that world correctly; this layer
claims that a Cat stops at a wall and a Frog does not, and checking *that* against
generated ground would mean hunting the world for a wall in the right place.

```
 y=0   . . . . . . . . . . . . .
 y=1   ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~     a chasm, right across
 y=2   . . . . . . . . . . . . .
 y=3   . . . . . . . . . . . . .
 y=4   . . . . # . . . ~ . . . .     a building at (4,4), a hole at (8,4)
 y=5   . . . . . . . . . . . . .
 y=6   . . . . . . . . . . . . .
 y=7   . . . . . . . . . . . . .
 y=8   . . . . ^ . . . , . . . .     earth too high at (4,8), a step at (8,8)
 y=9   . . . . . . . . . . . . .
 y=10  . . . . . . . . . . . . .
 y=11  . . . . . . . . . . . . .
 y=12  . . . . . . . . . . . . .
```

| glyph | height | what it is | what it is for |
|---|---|---|---|
| `.` | 0 | plain ground | everything |
| `,` | −2 | a step down, and back up | a slider crossing a legal change of height |
| `^` | +4 | ground too high to climb | a slider stopped by the board's step limit |
| `~` | none | a hole | a slider stopped by a hole, a Frog crossing one |
| `#` | 0 | a building | a slider stopped by an obstacle, a Frog crossing one |

The two heights are chosen against the board's own constants rather than picked:
$-2$ is exactly `CombatBoard.STEP_DOWN` and so the deepest legal step, and $+4$ is
above `CombatBoard.STEP_UP` and so the shallowest illegal climb. The suite checks
both, because if either constant moved the fixture would quietly stop testing what
it says it does.

**The four features sit on the four diagonals out of (6,6) on purpose.** One Cat
standing in the middle of the board meets all four of them at once, so a single
written-out cell list carries four separate rules:

```
a Cat at (6,6) moves to:
  (5,5)                                      north-west, stopped by the building
  (7,5)                                      north-east, stopped by the hole
  (5,7)                                      south-west, stopped by the face it cannot climb
  (7,7) (8,8) (9,9) (10,10) (11,11) (12,12)  south-east, down the step at (8,8) and on to the corner
```

---

## Surrounded: one occupancy, four exact answers

Ring the middle cell with eight enemy minions and ask each of the four what it
may do. This is the clearest single picture of what the tier is:

| minion | moves | captures |
|---|---|---|
| Toadstool | *nothing* | the four diagonals |
| Cat | *nothing* | the four diagonals |
| Ent | *nothing* | the four cardinals |
| Frog | **all eight L-hops** | *nothing* |

Three of them are stuck and can only take what is beside them. The Frog steps
over the ring untouched — and captures nothing, because everything it can reach
is empty. That is the design's terrain-ignoring assassin, and it is also why the
design says commanders cannot be glass cannons.

The chasm across row 1 makes the same point about ground rather than pieces. A
Frog at (5,2) lands at (4,0) and (6,0) on the far side of it; a Cat, an Ent and a
Toadstool standing on that same cell reach **no cell at all** with $y < 1$.

### What a landing does and does not ignore

A landing consults nothing between where it starts and where it arrives — a wall, a village, a
chasm and a wall of enemy minions are all equally irrelevant to it. That is one
absence of a loop in `legal_moves.gd`, not a special case.

It still has to land. The landing is checked with `CombatBoard.can_step(from,
to)`, which requires standable ground within
`HOP_HEIGHT` up and `DROP_REACH` down. **This is a decision, not an oversight.**
A board is read on one storey, so a large drop across it is a cliff face; a Frog
that ignored the reach rule could leap from the ground onto a floating island's
top and out of the storey its board was read on. It crosses what is *between*,
which is the niche the design gives it, and still has to land somewhere a piece
could stand. The suite pins this by filling the two far-side landing cells with
holes and requiring the Frog to lose them.

The same rule stops every piece at the fixture's wall of earth, which stands four
units above everything beside it where the board allows a climb of three:

| piece | standing | reaches the wall at (4,8)? |
|---|---|---|
| Toadstool | (4,7), against it | no — the other three cardinals only |
| Frog | (6,7), two cells off | no — seven of its eight L-hops, and the eighth is the wall |
| commander, full loadout | (4,7) | no — no grant it wears reaches ground it cannot climb |
| Toadstool | (4,8), on top of it | **cannot get down**: the drop is four and a piece may fall two |

That last row is the board's one-way ledge, seen from a piece. `STEP_UP` is 3 and
`STEP_DOWN` is 2, both taken from the terrain query's walking constants rather
than restated here, so what a piece may climb is the same fact as what a walker
may climb.

---

## Movement as armour

A commander's base movement is one cardinal step. Each piece of armour worn may
add one movement grant, and the commander's pattern is the union.

| loadout | cells reached from (6,6) | what it is |
|---|---|---|
| bare | 4 | one cardinal step |
| + boots | 8 | a king |
| + leggings | 12 | a step and a knight |
| + high-tier chestplate | 13 | a queen of two cells, blocked three ways |
| boots + leggings + chestplate | **21** | a piece chess has no name for |

The union is taken as a list of grants rather than as a merged pattern, because
the three kinds resolve differently against the board: a slide is stopped by what
a hop ignores. The union of the *cells* is what falls out of resolving them all.

```
the full loadout at (6,6):
  y=4        (5,4) (6,4) (7,4)
  y=5  (4,5) (5,5) (6,5) (7,5) (8,5)
  y=6  (4,6) (5,6)   .   (7,6) (8,6)
  y=7  (4,7) (5,7) (6,7) (7,7) (8,7)
  y=8        (5,8) (6,8) (7,8) (8,8)
```

Read the shape: the chestplate's queen would have reached (4,4), (8,4) and (4,8)
as well, and does not, because those are the building, the hole and the face it
cannot climb. Movement granted by an item is still movement across ground.

**"High tier" is a real qualifier, not decoration.** The design says a *high-tier*
chestplate grants the queen-like move, so a chestplate below the bar has to be a
thing that exists and grants nothing. It is, and the suite checks that equipping
one leaves the commander at one cardinal step. A helmet grants no movement at any
tier, so that "each armour piece adds a movement capability" is a claim about the
pieces that do rather than a rule every slot is bent to satisfy.

### The stop condition, asked rather than assumed

The task says: if the union of armour grants produces a commander that can reach
any cell on the board, stop and report the loadout rather than capping it
silently. So the question is asked, by
`LegalMoves.reaches_every_standable_cell()`, and answered:

> **The fullest loadout in the game reaches 21 of the fixture's 154 standable
> cells.** It does not come close, and the same check on a board read off the
> generated world at seed 1234 answers the same way.

There is nothing to cap. The three grants are a king, a knight and a queen
bounded at two cells; the only unbounded slider in the layer belongs to the Cat
and the Ent, and no armour grants one. If a future item does, this check is
already the thing that will notice.

---

## Weapons, attacks and facing

An attack is a pattern of cells relative to its wielder and a cooldown in turns.
That is all of it. The design's examples are each one call to one of the three
generators and a number:

| weapon | attack | pattern | cells | cooldown | has a front? |
|---|---|---|---|---|---|
| spear | thrust | `line(ahead, 1, 2)` | 2 | 1 | yes |
| dagger | stab | the two front corners | 2 | 1 | yes |
| sword | cut | the front and the two beside it | 3 | 1 | yes |
| sword | cleave | the same arc, two cells out | 6 | 3 | yes |
| bow | loose | `ring(5, 10)` | 248 | 3 | **no** |
| staff | fireball | `block((0,−4), 1)` | 9 | 5 | yes |
| flail | sweep | `ring(1, 1.5)` | 8 | 1 | **no** |

The sword carries two attacks, which is where *a stronger attack waits longer* is
visible inside a single item: the cut is three cells every turn, the cleave is six
cells every third.

**Whether a weapon has a front is a fact about its pattern, not a flag anybody
set.** Patterns are written for a wielder facing north and rotated by the facing
when their cells are asked for. A spear aimed at (6,4) and (6,5) reaches nothing
behind its wielder until the wielder turns; a bow's ring and a flail's sweep are
symmetric about the wielder and rotate onto themselves. Both are the same
rotation applied to two different lists, and the suite derives the "has a front"
column above by rotating each pattern rather than by reading a property.

An attack's cells are **not** filtered by what is standing in them or by what the
ground is. The sword's cleave from (6,6) covers (4,4) and (8,4) — a building and
a hole — and it should: an attack is a pattern of cells, not a list of places to
stand. What happens in those cells is the resolution step's business.

### Turning is free, and cannot be otherwise

`Commander.face()` takes a direction and sets it. It takes no turn number,
because there is nothing for it to spend one on, and it leaves every cooldown
exactly as it found it. That is not a promise made in a comment — it is the whole
body of the function. The suite spends the sword's cleave on turn 1, turns the
commander six times, and requires the readiness line to still read
`cut:0 cleave:3`.

### A cooldown is asked about, not ticked

An attack records the turn it next becomes available on, and readiness is a
comparison against the turn being asked about. Nothing has to be ticked, so
nothing can be ticked twice or forgotten — which matters because the turn economy
that would do the ticking does not exist yet, and this layer must not grow a
private copy of one.

---

## The king rule

Every piece carries an owner. **A commander owns itself**: when it is added to a
piece map its owner is set to its own id, so "everything this commander owns" is
one comparison and the commander is inside it. A minion carries the id of the
commander it was summoned by.

That makes section 3.3's king rule a single operation. `PieceMap.kill()` on a
commander removes the commander and every piece owned by it and returns all of
them together — there is no second pass over the board afterwards, and no moment
in between in which the minions of a dead commander are still standing. The suite
checks both halves: after one call the minions are gone *and* their cells are
empty, and the other commander's minions are untouched. Killing a minion takes
the same path with a different answer to one question, and removes that minion
alone.

---

## What is checked, and how it is shown to bite

**256 checks**, every pattern written out as an exact cell list against the
fixture above. Nothing is compared to a list the code under test produced, and
nothing is compared to a count.

Each of those assertions is also broken on purpose *inside* the suite: for each
claim there is a second run in which the one thing the rule is about is changed —
the hole is filled in, the wall is taken away, the enemy becomes a friend, the
armour comes off, the cooldown is asked about a turn too early — and the same
expected list is required to stop holding.

That catches an assertion that is vacuous. It does not catch an assertion that is
merely *absent*, so there is a second check that edits the simulation instead of
the world:

```
./tools/piece_mutations.sh
```

It breaks one rule of `sim/` at a time — the line the rule is actually written on
— runs the piece suite, and records whether the suite noticed. Every edit is
undone afterwards, including on an interrupted run.

```
rule broken                                      file                     the suite
------------------------------------------------ ------------------------ ---------
a slide is not stopped by a piece                sim/legal_moves.gd       failed, as it must
a slide ignores the climb limit                  sim/legal_moves.gd       failed, as it must
a landing ignores the climb limit                sim/legal_moves.gd       failed, as it must
a landing is ridden to, not arrived on           sim/legal_moves.gd       failed, as it must
a piece may take its own side                    sim/legal_moves.gd       failed, as it must
the Toadstool captures the way it moves          sim/minion.gd            failed, as it must
the Cat rides cardinally                         sim/minion.gd            failed, as it must
the Ent rides diagonally                         sim/minion.gd            failed, as it must
the Frog's L is one cell shorter                 sim/minion.gd            failed, as it must
a commander's base step is more than one cell    sim/commander.gd         failed, as it must
an attack does not turn with its wielder         sim/attack.gd            failed, as it must
turning spends the attack it was aimed with      sim/commander.gd         failed, as it must
a cooldown is not counted                        sim/commander.gd         failed, as it must
armour below high tier still grants movement     sim/armour.gd            failed, as it must
a chestplate is unbounded                        sim/armour.gd            failed, as it must
a commander's death spares its minions           sim/piece_map.gd         failed, as it must
a pattern is not put in one order                sim/piece_geometry.gd    failed, as it must

all 17 broken rules were caught
```

*(That was this task's run. The harness now carries 19: the two armour mutations
above became four when a loadout's grants started being paid for out of the item
power budget — see [loadout.md](loadout.md) — and
`reports/piece-mutations-evidence.txt` holds the current run.)*

**It was not green the first time, and that is the point.** The first run left
two rules unnoticed:

* *a landing ignores the climb limit* — no test had a piece standing where it
  could see ground too high to climb by stepping or by leaping. The wall of earth
  at (4,8) was in the fixture and nothing stood next to it. Four claims were
  added, and they are the table in
  [what a landing does and does not ignore](#what-a-landing-does-and-does-not-ignore).
* *the Frog steps instead of hopping* — uncatchable, because it changed nothing.
  That is what collapsed three movement modes into two.

One found a missing test; the other found a fake distinction in the code. Neither
would have shown up in a suite that only checks that the right answers come out.

---

## Determinism, and the layer split

Nothing here accumulates and nothing here is ordered by chance. The suite puts
the same five pieces down in two different orders and requires every destination
list to match cell for cell, asks the same question twice and requires the same
answer, and builds the fixture twice and compares the board's fingerprint.

Every pattern comes back through one canonical order — sorted by row then column,
duplicates dropped — so two equal patterns are the same array whichever generator
or whichever order produced them. Reversing that order is one of the mutations
above, and the suite catches it.

The whole layer is under `sim/`. It names asset tags (`minion_toadstool` and its
three siblings) and no model, no scene and no path; `./run_tests.sh --layers-only`
passes, so the simulation still does not know the render layer exists and still
does not know what anything looks like.

---

## Boundaries kept

* **No turn economy and no damage numbers.** A cooldown is a turn *number handed
  in by whoever is asking*, because the thing that would own a turn counter does
  not exist yet and this layer must not grow a private copy of one. Nothing here
  has hit points, a level or a damage figure.
* **Items are stubs.** `Armour` is a slot, a tier and at most one movement grant;
  `Weapon` is a name and a list of attacks. No rarity, no item level, no power
  budget, no defence — those are the item layer's, and a placeholder for them here
  would be a second place they later have to be removed from.
* **No original minions.** Four, exactly the four the design names.

---

## What this layer does not answer

Deliberately, and all of it belongs to the resolution step that comes next:

* **What happens in an attacked cell.** An attack is a pattern of cells; whether
  a piece in one is captured, damaged or missed is not asked here.
* **Line of sight.** The board carries `blocks_line` and this layer never reads
  it. An attack pattern is clipped to the board and to nothing else.
* **Shoving.** The board carries `cliff_edge` and a `drop`, and no piece rule
  reads either.
* **Whose turn it is, and how many pieces may act.** One turn per player, a
  character move plus one weapon action, one minion activation — none of that is
  here.
