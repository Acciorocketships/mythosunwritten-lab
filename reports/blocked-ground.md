# A tree holds its square: what stands on the ground blocks the board

Until now the tactical board asked the terrain query what was in the way and
nobody else. Water, the void off a floating island, the pond in an island's
basin and the footprint of a building closed a cell; everything the scatter
layer had grown or stood on that same ground — every fir, canopy tree, boulder,
stone circle, fence, cart, crate and barrel — was walked straight through, and
a fight in a wood was a fight in an open field with trees drawn on it.

This is the board asking the scatter layer the question it already answers.

## The rule, and why it is that rule

Two things had to be decided, and both are decided in the place that already
knows the answer rather than in the board.

**What is in the way** is a column on the catalog row, in `sim/scatter_catalog.gd`
beside the weight and the size, because whether you can walk through a fern is a
fact about ferns. There are two answers:

| stands | what it means | rows |
|---|---|---|
| `through` | pushed past, stepped over, stood on | bush, fern, hardy shrub, flower, mushroom, petal drift, fallen log, reed, cattail, toadstool, lily pad, glowing orb, pebble, gravel, lantern post |
| `solid` | occupies the ground it stands on | fir, canopy tree, blossom tree, dead tree, boulder, rock spire, stone circle, fence, cart, crate, barrel |

The groups are the obvious ones with one deliberate exception each way. Stone
splits on its lattice, which is what the two lattices already say about it: a
pebble or a patch of gravel on the fine lattice is walked over and a boulder or a
spire on the coarse one is rock. The made things are solid where somebody built
them to be in the way — a fence, a cart, a crate, a barrel — and walked past
where they are a post: a lantern on a pole is a thin thing in a three-unit
square, and stopping a piece with one would be stopping it with a signpost.

**How tall a thing has to be to stop a line of sight** is not a new number. The
board already holds that a face of earth standing more than a piece can climb
above the lowest ground beside it stops a line, and that threshold is
`CombatBoard.STEP_UP` = `TerrainQuery.HOP_HEIGHT` = 3.0 units — what a walker
climbs. The same yardstick is laid against the size the thing actually rolled:
what you could scramble over you can see over. So

* a solid thing closes the cell to a piece, always;
* a solid thing **taller than 3.0 units** closes the line through it as well.

That is where "a boulder is not a tuft of grass" stops being a slogan and starts
doing work, because the catalog's per-biome sizes finally mean something
mechanical: the same `boulder` row is 0.9–1.7 units in deep forest and 2.2–4.4 on
the highland, so a boulder in the woods is cover you shoot over and a boulder on
the moor is a wall. Every tree in the table rolls taller than 3.0 in every biome,
so a wood is a place with sight lines in it.

Two more decisions fall out of the layers rather than being taken here. A cell
only carries what stands on it when it resolved to the **ground** storey — a
board on an island passing over a wood far below is not in its branches, which is
the same rule, and the same sentence, that the village underneath it already
had. And a cell the board reads as a **hole** carries nothing, even where
something stands on a dry corner of it: the scatter layer stands things on the
ground, and that cell is not about the ground.

## Where the answer comes from

`CombatBoardBuilder` builds a `DecorationScatter` from the same terrain query it
was given and asks it `solid_items_within(the board's own rectangle)`. That walks
the cells of the flora and prop lattices overlapping the rectangle and asks each
one the very `item_in_cell` a chunk asks when it decides what model to stand
there. Nothing is kept, nothing is passed in, and there is no list of trees
anywhere: **whether a cell is blocked is a pure function of the world seed and
the cell**, exactly as its height and its hole are. The render layer and the
board cannot come to disagree about where a tree is, because neither of them has
an answer of its own.

The fast call has one refusal in front of it that cannot change the answer. A
lattice's rows are laid end to end along the single roll in `[0, 1)` that decides
a cell, so a roll past the end of the *last solid row's* stretch can only land on
something walked through. `ScatterCatalog.solid_ceiling` is that point, derived
from the table rather than written down (0.128 on the flora lattice, where the
four trees are the first four rows), and seven flora cells in eight leave for one
hash without the ground under them being asked about at all. It is the same
trick, for the same reason, as the existing `FLORA_CEILING`. `tests/test_scatter.gd`
compares the two ways of asking over nine rectangles — some ten thousand cells of
the two lattices — and checks the ceiling really does bound every solid row in
every biome.

## A fight on wooded ground

`./run_encounter.sh --seed 14` plays the shipped two-band encounter on seed 14,
where the meeting place — the same constant as ever, `(-480, 420)` — falls in
deep forest instead of in this seed's meadow:

```
tick 16 fighting chunks=32 islands=9 props=628 begun=1 ended=0 standing=8 ...
    snap-in around #1 at (-484.400, 5.043, 420.000) radius=24.0 span=30.0 storey=0 joined=6
    snap-in board 00d9f7fc1915b997 cells=441 standable=346 holes=7 closed=88 line=83 cliffs=13
    snap-in #1 (-484.400, 420.000) -> cell (-162,140) centre (-484.500, 421.500) moved 1.503 rings=0
    snap-in #4 (-475.600, 420.000) -> cell (-159,139) centre (-475.500, 418.500) moved 1.503 rings=1
```

Of the 441 cells of that fight's board, 7 are water and **88 are closed by what
is standing on them**, 83 of which stop a line of sight as well. `rings=1` on
combatant #4 is the seating search stepping outwards: the cell it was standing
over would not take it.

The same board, printed cell by cell:

```
$ ./run_headless.sh --seed 14 --ticks 1 --board-at -484.4 420
board-at -172 130 21 21 -516.0 390.0 -453.0 453.0 0 5.0429 441 00d9f7fc1915b997
board -164 136 6.1647 0.1556 0 0 ----- ---- move line -----
board -163 136 6.2937 0.1291 0 0 stand ---- ---- ---- -----
board -162 136 6.3861 0.2933 0 0 stand ---- ---- ---- -----
board -161 136 6.4696 0.4222 0 0 ----- ---- move ---- -----
board -160 136 6.5484 0.4083 0 0 ----- ---- move line -----
...
board-tally 441 346 7 83 13 0
```

The digest on the `board-at` line is the fight's own — `00d9f7fc1915b997`, the
same string the `snap-in board` line printed — which is what "a board is a
function of the place and the seed" means in practice: a board read there
afterwards *is* the board that fight was played on. `--board-at` is new, and it
exists for exactly this.

Drawn from those 441 lines, one character per cell — `#` closes a piece and a
line, `o` closes a piece only, `~` is a hole, `,` is a cliff edge, `.` is open:

```
      210987654321098765432
  130 .##...#......#....#.#
  131 ....#......##.##.....
  132 ...o..#....##........
  133 .........##.....#....
  134 ....##........#......
  135 ....#..........#..#..
  136 ........#..o#....##..
  137 .......#.......#.....
  138 ...#.#......#..#.#...
  139 #...#....##....#...#.
  140 .....#.#...#.###.....
  141 ....#.#....#.........
  142 .#..#......#....#...,
  143 ....o......#.#......,
  144 ##..##..#.#........#~
  145 .#..........#..#...,~
  146 .##..........o#...,~,
  147 .........#.....#.,~,.
  148 ...###.o.##.....,~,..
  149 .#.....#......#,~,.##
  150 ...........##.,~,..#.
```

That is a wood with a stream down one corner, and it is the ground six
combatants are standing on.

## Every blocked cell has something on it, and every solid thing blocks a cell

The two claims check each other, and they can be checked from printed output
alone. On seed 1234 the origin is deep forest, and the board there sits inside
the square of chunks `--scatter` lists, so one command prints both:

```
$ ./run_headless.sh --ticks 1 --board-at 0 0 --scatter
board-at -10 -10 21 21 -30.0 -30.0 33.0 33.0 0 22.7924 441 032f7bf3cf684df3
board-tally 441 347 0 92 64 0
```

Matching the 441 board lines against the 325 scattered things standing inside
that rectangle, by the cell each of them falls in:

| | |
|---|---|
| cells closing a piece | 94 |
| cells holding something solid | 94 |
| the two sets | identical |
| cells closing a line | 92 |
| cells whose tallest solid thing is over 3.0 units | 92 |
| line-closers that are neither a tall thing nor a face of earth | 0 |
| things standing on the board that are walked through | 220 |
| cells holding only walked-through things, still open | 152 |

The 105 solid things are 53 canopy trees, 43 firs, 4 dead trees, 3 blossom trees
and 2 boulders; the 220 walked-through ones are ferns, bushes, flowers,
mushrooms, fallen logs, petal drifts and pebbles, and not one of them closes
anything. The two boulders are the rule's own illustration:

```
scatter boulder 14.267 -17.980 ... 1.27 rock ground     cell (4,-6)
board 4 -6 25.8401 0.2497 0 0 ----- ---- move ---- -----
```

1.27 units of stone in a deep forest: it takes the square, and you shoot over
it. (The other boulder's cell closes a line too — because a 5.36-unit fir stands
in the same square.)

`tests/test_combat_board.gd` makes the same comparison the other way and over
whole boards: for every cell of three boards in three kinds of country it asks
the scatter layer, a cell at a time, what is standing there, and requires that
nothing solid means an open cell unless the ground itself is the reason, that
something solid means a closed one, and that something solid over 3.0 units means
a closed line.

## No board becomes unplayable

**Nothing is ever un-blocked to keep a board connected.** A cell is closed
because something is standing on it, and that is a function of the seed and the
cell; repairing a board for one fight would make the same ground answer
differently in the next one, and two boards over one wood would stop agreeing —
which is the one thing this layer must not do. So the board does not give way.
What protects a fight is the two things the fight layer already does, and both
are measured rather than hoped for.

**A commander is never left standing in a tree.** Seating skips any cell that
blocks movement, so a piece that walked into a thicket is put on the nearest open
cell instead; if there is none within `CombatSnap.SEARCH_RINGS` (four rings,
twelve world units), the fight is refused and nobody is moved at all.

**A wood can still hold two fighters apart, and that is terrain rather than a
fault.** Over 49 boards spread across 1,560 units of seed 1234 and the eight ways
two combatants can meet at `ActionScene.ENGAGE_RADIUS`:

| | |
|---|---|
| pairs seated | 392 |
| pieces that found no seat | 0 |
| pieces moved off ground they could not stand on | 100 |
| pairs seated in walkable pockets separated from each other | 2 |

The two are honest: a fighter who backed into a thicket is in a thicket, and a
match that cannot be decided ends at `Encounter.MAX_ROUNDS` rather than hanging —
`tests/test_fight_cooloff.gd` plays several whole fights out to exactly that.
`tests/test_combat_snap.gd` runs this sweep and pins it: every piece seated,
every seat open, some pieces moved off ground something was standing on, and
separated pairs at most a tenth of the sweep.

How much a board loses, over the same 49 boards: the ground's own largest
walkable region keeps a mean of **85.4%** of itself once the trees are on it, and
**50.5%** in the worst board of the 49 — a thick patch of deep forest at
(-260, -780), where 201 of 283 standable cells are one region and the rest are
pockets. The share of a board's cells closed by what stands on them runs from 7%
on open highland to 22% in deep forest.

## What moved, and what did not

**The world's fingerprint moved**, and for one reason. Seed 1234, 100 ticks:

```
before:  done ticks=100 chunks=39 built=66 final=32656f55cc5eeb1c
after:   done ticks=100 chunks=39 built=66 final=63d2944d25181c5f
```

Nothing about the generated world changed — the two runs print identical bytes
for the first 36 lines, and the same chunk, island, village, road and prop counts
at every traced tick to the end. The world's fingerprint carries the fight under
way, the fight carries its board, and that board now says 108 of its 441 cells
are closed. From round 2 on, the two transcripts differ in 59 lines, all of them
inside the fight: the pieces walk round the trees, and one shove that used to
push a combatant to (-2,-14) no longer lands it there. That is the change doing
what it is for.

**The scatter layer itself is untouched.** Its rolls, its weights, its jitter and
its sizes are what they were; a row gained a column saying how it stands. So
every chunk's dressing digest is the same, and a world with no fight in it
fingerprints exactly as it did.

**`./run_headless.sh --snap` reports one more number.** The site score used to be
`stand`, the share of a board a piece may stand on, against a threshold of 0.90;
with the trees on the board that number fell to 0.821 at the shipped meeting
place and only 6 of 289 candidates passed. The threshold has always been about
the ground — "a fight on ground that is mostly hole is a fight on a few islands
of cells" — so it now reads `open`, the share the ground itself leaves (no hole,
no building), and `stand` is reported beside it. The shipped meeting place scores
`open=0.909 stand=0.821`, exactly the 0.909 it scored before, and 16 of the 289
candidates pass where 15 did before the change. The gap between the two numbers
is how wooded a place is, and the `flora` threshold goes on keeping a fight out
of a canopy.

**A board costs more to read.** Measured over 12 boards on seed 1234, cold:

| | per board |
|---|---|
| before | 411 ms |
| after | 483 ms |
| the same without the ceiling shortcut | 749 ms |

Seventeen per cent, paid once when a fight starts. Reading a 63-unit square of
the scatter layer is about fifteen chunks' worth of its decisions, and the
shortcut is what keeps it to that.

## What it cost outside the board

**The shipped model recording had to be bought again.** A character's prompt
carries its observation packet, the packet carries a window onto this very board
and the sight lines traced across it, and the replay is keyed to the prompt's
fingerprint. Two of the six characters in the shipped cast run stand where the
window changed, so the run walked off the end of the recording:

```
the run ran out of recorded replies:
  Bram: this reply was recorded for another question:
        the prompt put here fingerprints da2cdc445c37064e and the recorded one ada02c35b9bf2b39
  Pell: ... 7c306389cc4b7b7f and the recorded one e12c51905bda77ba
```

That is the third measured way a recording dies and the project's standing answer
is to budget a live pass for it, so one was bought:
`./run_record.sh --live --cast`, 2026-09-11, `z-ai/glm-5.3-flash` over
`openrouter.ai`. It puts only the three tables the character runs read — the
shipped run (108 replies), the lesson comparison (4) and the goal comparison (4);
the difficulty-class, orchestrator, goodwill and bargain tables were written back
byte for byte with their own dates, and their four suites passed before and after
without being touched. The four transcripts under `reports/` that replay or
depend on those tables were regenerated with it: `agent-evidence.txt`,
`lesson-evidence.txt`, `goal-evidence.txt` and `scenario-evidence.txt` (the last
of which uses no model at all — its world simply has trees in it now).

Two runs of `./run_agent.sh` print identical bytes and match the checked-in
transcript, `22e07a890136b5afb5cfc48d2d3e620eb0b006351b2aeb65491cc531cd12808b`.

**Which suites moved.** Of the seventeen suites that touch a board, an
observation, a fight or a recording, thirteen passed unchanged. The four that
failed all failed for the same reason — a checked-in transcript is no longer what
its command prints — and all four pass on the regenerated ones: `agent`,
`goals`, `memory` and `scenario`.
