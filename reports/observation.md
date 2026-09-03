# What a character can see

Section 10 of the design gives every character a **local, structured
observation**: the packet a language model is later handed so that it can choose
an atomic action. This is that packet. It is assembled out of the world by
`sim/observation.gd`, it is built and tested headless, and there is no language
model, no prompt, no network call and no new dependency anywhere near it —
producing what a model will read must not itself require one.

    ./run_observation.sh          # the walkthrough and the measurement
    ./run_observation_suite.sh    # just the observation suite

Three files:

| file | what it is |
|---|---|
| `sim/observation.gd` | the packet: who is nearby, what is lying about, the ground and its legend, what was heard, and what has changed |
| `sim/observation_trail.gd` | the first-person deltas — "moved 0.9m north-east", "gained brass lantern" |
| `sim/scripted_observation.gd` | the walkthrough: fifteen observations off the shipped scenario, and the measurement |

## The terrain question section 13 leaves open, settled by measurement

Section 10 says the terrain part of an observation "must converge with the
combat lattice — do not build a third representation", and section 13 lists the
representation as open. It is settled here in the strongest available way: the
observation's terrain **is a `CombatBoard`**, built by the world's own
`CombatBoardBuilder`, reached through the existing type. Nothing in
`sim/observation.gd` computes a height, a walkability, a hole, a blocking face
or a cliff edge; every one of those is a cell of that board.

The test does not take that on trust. `tests/test_observation.gd` builds a board
for a *fight* at the same place and compares fingerprints:

```
var fight_board := CombatBoardBuilder.new(scene.terrain).build(
    wren.x, wren.z, wren.y, Observation.NEARBY)
equal(fight_board.digest(), seen.board.digest(), ...)
```

They are equal. There is one lattice and one board, and if the two could ever
differ this check fails.

**Is a 3.0-unit cell, chosen for chess legibility, too coarse for local
awareness?** That was the stop condition on this task. It is not, and here is the
measurement rather than the opinion.

| what | number |
|---|---|
| cell size | 3.0 world units (the lattice's own, `CombatBoard.CELL_SIZE`) |
| printed window | 7×7 cells = 21×21 world units |
| board actually built | 28×28 cells = 84×84 world units, out to `NEARBY` = 40.0 |
| terrain's share of a typical packet | 558 of 1,113 characters, 50% (173 of those are the legend) |
| one walking step (`ActionEngine.STEP`) | 0.9 world units — a cell is about three steps |

The coarseness costs nothing where it would matter, because **entity positions
are not snapped to it**. Every entity and object in the packet carries a
continuous relative offset and a continuous distance — `(+8.0, +0.1, +0.0)`,
`8.00` — read off the world, not off a cell. The lattice answers what the
*ground* does (can I stand here, is that a hole, does that face block a line);
the entity list answers where everybody is, to a thousandth of a unit. So the
one thing a coarse cell could have spoiled is not carried on cells at all.

No second representation was built, and none is needed.

## What was heard, and who says who heard it

A character can hear. The packet carries the last six lines of speech **that
this character could hear**, oldest first, each saying who spoke, what they
said, and whether it was said to this character or shouted to everyone within
earshot. A character's own words are in it too, written as `you`, because a
character that could not tell it had already spoken has no way to know it is
repeating itself.

```
  heard      3 lines of speech, oldest first
    you said to #2 "good morning"
    #2 Rook said to you "what will it be?"
    you shouted "a fair bargain"
```

**Who heard a line is the engine's answer, not a second one.**
`ActionEngine._say` already works out who hears what — the one character a line
was aimed at, or everyone within `VOICE` of a shout — and writes that list into
`ActionScene.said` as `heard_by`. The observation filters by that list and by
nothing else. There is no earshot in `sim/observation.gd`, no comparison of
positions, and no second opinion about who was near enough; the suite asserts
it the hard way, by walking every line ever said against every character and
requiring the packet to agree with `heard_by` exactly.

One consequence is the engine's rule and worth stating plainly: a line spoken
*to* somebody is heard by that somebody alone, so standing beside two people
talking is not the same as hearing them. Changing that would be changing how
`say` resolves, which is not this task's to change.

## The ground window says what its marks mean

The window used to arrive as a grid of punctuation with no key. It now carries a
legend, inside the packet, read out of the same two tables the marks themselves
come from so a mark and its meaning cannot drift apart:

```
  legend     @ where you stand; ~ a hole with nothing to stand on; x a building;
             # a face of ground too tall to climb; ! the edge of a drop;
             . ground to walk on; ? not read
```

(One line in the packet; wrapped here.) It says what a mark **is** and never
what may be done about it — what a character may do on a piece of ground is the
engine's answer and is nowhere in the packet. `tests/test_agent.gd` runs the
same rule-word scan over the legend on its own as it runs over the whole prompt,
so a meaning that grew into a rule fails there and names itself.

## What is in the packet, and what "absent" means

Each field is either present with a value or **absent with a stated reason**.
There is no blank anywhere, and reading one is never guessing.

For each nearby entity, in section 10's own order: `id`, `type`, `name`,
`offset`, `distance`, `line_of_sight`, `doing`, `health`, `equipment`. For each
nearby object: `id`, `type`, `name`, `offset`, `distance`, `line_of_sight`,
`state`, and — when it is open — what it holds. Plus the ground, plus this
character's own last few changes.

The six reasons a field can be absent:

| reason | when |
|---|---|
| `this character has not met it` | the name of a stranger |
| `it has no name` | a minion, or a character nobody has named |
| `not in line of sight` | what it is doing, how hurt it looks, what it has on |
| `nothing is driving this scene` | nobody is deciding, so no action is under way to see |
| `nothing has been watching this character` | an observation assembled with no trail |
| `it is no longer in the world` | the name of somebody who spoke and has since fallen |

A line from the run, with an absence and its reason:

```
    #4   commander  ?        (+12.0, +1.2, +0.0)  12.00 seen   doing go_to you      health unhurt     wearing boots=common boots hand=common spear
         not shown: name (this character has not met it)
```

Bram can see Sable perfectly well — how hurt Sable is, what Sable is wearing,
that Sable is walking towards *him* — and does not know Sable's name, because
they have never met. A name is knowledge, a silhouette is not.

### Listed is not the same as seen

Everything within `NEARBY` is *listed*; only what is in line of sight is *filled
in*. That split is deliberate and it is section 10's own: it gives every entity a
`line_of_sight` field and every object a "visibility/accessibility", and neither
field means anything if a thing out of sight is simply left out. So somebody
behind a bluff appears with an id, a type and where the sound is coming from, and
with their name, their action, their health and their gear all absent for the
stated reason `not in line of sight`. Nothing about them is *asserted* that could
not be perceived; what is asserted is that something is there.

### Visibility is answered, never assumed

* **A name** appears only when the looking character knows it, and knowing is a
  fact about the *looker*: either the two share a band (you know the people you
  stand with) or -- as of the relationship graph, which superseded the empty
  per-sheet map this line described; see
  [reports/relationships.md](relationships.md) -- the world's own edge between
  the two exists. Before that it was the looker's own `Character.sentiment`
  having an entry for the
  target, which is that sheet's record of everyone it knows of. Knowing is not
  mutual — the suite checks that Wren knowing Mott leaves Mott still not knowing
  Wren.
* **An action** appears only for somebody in line of sight, and it is the
  action's own kind out of the one catalogue — `go_to`, `attack`, `wait` — plus
  who it is aimed at, and only when the looker can see that target too.
  Deliberately not a readable sentence per action: there are twelve actions and
  one list of them, and a table of phrases here would be a thirteenth.
* **Health and equipment** come back through `ActionEngine.observed_of`, which is
  the same call `examine` already made. How hurt somebody looks is a word
  (`unhurt`, `hurt`, `badly hurt`) and not a hit-point count, and it is answered
  in one place in the project rather than two.
* **Line of sight** is traced across the board, cell by cell, stopped by exactly
  what stops a line there: a building, or a face of ground taller than a piece
  can climb. A hole does not stop it — you can see across a chasm, the same rule
  that lets you shoot across one. The two end cells are never tested, because a
  piece can stand on a cell that blocks lines (the top of a bluff is standable
  and its face is what blocks), and testing them would make anyone on high
  ground invisible.

## It is local

Nothing in the packet is read from anywhere but the character's own
surroundings. There is no weather, no season, **no tick**, no seed, no region
summary, no count of how many characters exist and no list of who is alive; the
suite reads the finished text and checks for each of those words. Anyone further
away than `NEARBY` = 40.0 world units is not in the packet at all, which the
suite also checks by putting somebody beyond it and looking for them by id.

Two consequences worth stating:

* **No clock.** A tick is a clock and a character standing in a field cannot
  read one. What has changed is said in words — "moved 0.9m north-east" — and
  never as a timestamp.
* **No player.** Section 10 writes the entity type as
  "NPC/player/monster/object". That distinction cannot be made from this side and
  must not be: `Character` has no field saying who is driving it, deliberately,
  and an observation that answered the question would be exactly the preferential
  treatment the design forbids. The type reported is what a thing *is* —
  `commander`, `cat`, `frog`, `pile`. The observation is available to a character
  a person drives on precisely the terms it is available to one a program drives,
  because there is nothing in it that could tell them apart.

## The recent changes are a diff, not a report

`ObservationTrail` is shown the scene once a tick, keeps a snapshot of each
character — position, health, what is carried, what is worn, money, whether it
is on a board — and writes the **difference** in words. Nothing under `sim/` was
changed to make this work and nothing reports to it: "gained brass lantern" is
not an action anybody recorded, it is the plain fact that a lantern is in the
pack now and was not before.

That is why the wording never claims to know *how* something changed. An item
that arrives says `gained`, not `picked up`, because a trade, a gift and a
pick-up all look the same from outside and only one of them would have been
true. The trade in the shipped run reads, from the two sides:

```
  Wren           Rook
  gained silk cloak      gave up silk cloak
  spent 12 coins         gained 12 coins
```

Both sentences are diffs of the same exchange, and neither was written by the
code that carried it out.

The trail is capped at `KEEP` = 6 changes and it is **first-person**: an
observation reports its own character's changes and nobody else's, so nothing in
it is knowledge of somewhere that character has not been.

One bug this shipped-run walkthrough caught and the suite now guards: this
engine's packed arrays share their storage when handed out of a dictionary, so
an observation taken at tick 1 was quietly filling in with everything that
happened up to tick 80. `recent_of()` hands back a copy, and the suite takes an
observation, changes the world, and checks the observation did not move.

## How big one is

The number that matters later: this has to fit in a model's context. Measured on
the shipped scenario at seed **1234**, at ticks **1, 66 and 80**, one observation
per character:

| tick | who | entities | objects | cells | recent | entries | characters |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | #1 Wren | 1 | 1 | 49 | 0 | 51 | 1058 |
| 1 | #2 Rook | 1 | 1 | 49 | 0 | 51 | 1059 |
| 1 | #3 Bram | 1 | 1 | 49 | 0 | 51 | 1197 |
| 1 | #4 Sable | 1 | 0 | 49 | 0 | 50 | 1113 |
| 1 | #5 Odo | 0 | 0 | 49 | 0 | 49 | 859 |
| 66 | #1 Wren | 1 | 0 | 49 | 6 | 58 | 1192 |
| 66 | #2 Rook | 1 | 0 | 49 | 2 | 54 | 1093 |
| 66 | #3 Bram | 1 | 0 | 49 | 0 | 50 | 1112 |
| 66 | #4 Sable | 1 | 0 | 49 | 0 | 50 | 1113 |
| 66 | #5 Odo | 0 | 0 | 49 | 2 | 51 | 899 |
| 80 | #1 Wren | 1 | 0 | 49 | 6 | 59 | 1225 |
| 80 | #2 Rook | 1 | 0 | 49 | 2 | 55 | 1130 |
| 80 | #3 Bram | 1 | 0 | 49 | 3 | 53 | 1182 |
| 80 | #4 Sable | 1 | 0 | 49 | 3 | 53 | 1189 |
| 80 | #5 Odo | 0 | 0 | 49 | 2 | 51 | 899 |

**A typical observation in the shipped scenario is 1,113 characters and 51
entries** — 859 at the smallest (Odo alone in a field with nothing to report) and
1,225 at the largest. The 49 cells of ground are the same in every one of them,
because the window is fixed. (The `entries` column counts heard lines too, which
is why a packet can hold 59 entries at tick 80 where it held 56 before.)

**What the legend and the heard speech cost**, measured at the same ticks and
the same seed as the measurement before them:

| | before | now | growth |
|---|---:|---:|---:|
| a typical observation, in characters | 863 | 1,113 | +250, +29% |
| the smallest | 610 | 859 | +249 |
| the largest | 948 | 1,225 | +277 |
| a typical observation, in entries | 51 | 51 | 0 |
| the whole walkthrough, in bytes | 14,532 | 18,639 | +4,107 |

Nearly all of it is fixed cost paid once per packet: the legend line is 173
characters and the reworded heading another 30, so the block of ground grew by
203 whatever is happening on it. The heard section adds a 46-character heading
and one short line per line actually heard — three lines of dialogue cost about
150 characters. The entry count barely moves because the 49 cells of the window
dominate it.

What a wider window of the same lattice would cost, re-rendered off the very
same board:

| cells across | cells | ground lines | ground characters |
|---:|---:|---:|---:|
| 5 | 25 | 7 | 430 |
| 7 | 49 | 9 | 558 |
| 9 | 81 | 11 | 726 |
| 28 | 784 | 31 | 4608 |

(Each row now carries the heading, the legend and the grid; the legend is the
same 173 characters in all four, which is why every row grew by 203 and not in
proportion to its cells.)

The last row is the whole board the observation was read from. It is built and
it is not printed: it reaches 40.0 world units so that a line of sight to
anything in the packet can be traced across it, while the 7×7 window is what a
character is told about the ground under its feet. Printing all of it would make
the terrain five times the rest of the packet put together, for cells nobody is
going to step on this turn.

The ground reads as a picture, north up, each token a cell's own character and
its height relative to where the character stands. Wren at the market, standing
three cells from the pond:

```
  ground     7x7 cells of 3.0, north up, east right; each mark is followed by how far that cell stands above you
  legend     @ where you stand; ~ a hole with nothing to stand on; x a building; # a face of ground too tall to climb; ! the edge of a drop; . ground to walk on; ? not read
    .0   .0   .0   .0   .0   .0   .0
    .0   .0   .0   .0   .0   .0   .0
    .0   .0   .0   .0   .0   .0   .0
    !0   .0   .0   @0   .0   .0   .0
    ~-   !-1  !-1  !0   .0   .0   .0
    ~-   ~-   ~-   ~-   !0   .0   .0
    !-1  ~-   ~-   ~-   ~-   !-1  !-1
```

Every one of those marks is a flag of the cell, read off the fight's own board,
and every one of them is named in the packet that carries it.

## Determinism

An observation is a pure function of the world state and the observing
character. The walkthrough plays its run twice inside one process and compares
all fifteen fingerprints; and two whole processes on one seed print **identical
bytes** — 18,639 of them. The fingerprint of the fifteen observations at seed
1234 is `ebe23cc51093bba6`; at seed 7 it is `fa28210761e583e6`. (Both moved when
the packet grew, which is the point of a fingerprint; the world's own
`d178d38879097c1c` did not.)

## What did not move

The observation is a reading of the world and it changes nothing in it.

* **The world fingerprint is unchanged.** `./run_headless.sh` prints
  `final=d178d38879097c1c`, byte-identical to before this task.
* **`./run_scenario.sh` and `./run_encounter.sh` are byte-identical**, verified
  by reverting this task's two edits to existing simulation files, capturing the
  transcripts, reapplying, and diffing.
* Two existing files were touched, both without changing behaviour:
  `ActionEngine._observed` was renamed `observed_of` and made public, because it
  is now asked by two callers and must be answered once; and
  `ScriptedScenario.played_to` gained an optional `watching` callable, which is
  how something that wants to see a run go past rather than only its end gets a
  look. No existing caller passes one.
* `./run_tests.sh` passes and `bin/check_layers.gd` passes.
