# Five characters, one seeded run

`./run_scenario.sh` plays one headless run of the character layer end to end:
five characters on the meadow at `(-480, 420)` of seed 1234, none of them
privileged, each reached only through the atomic action surface. In 160 ticks
they greet each other, walk, pick something up, trade coins for a cloak, fall
into a quarrel that snaps onto the tactical board, and come back to real time
when it resolves. The transcript is [`scenario-evidence.txt`](scenario-evidence.txt);
two separate processes print it byte for byte.

![Wren the mage and Rook the rogue standing together on the meadow just after
the trade, with the observer beside them](assets/scenario-market.png)

*Wren (the pointed hat) and Rook (green) at the market at tick 66, a moment after
the cloak and the twelve coins changed hands. The third figure is the observer --
the camera's stand-in, which takes no part in anything. All three are the rigged
KayKit adventurer models the character-models step installed, playing their idle
clip; the simulation knows only the tags `mage`, `rogue` and `ranger`.*

## The cast

Five `Character`s on one sheet, in one `ActionScene`, differing in exactly one
field -- the `Callable` on `Character.decide`. The run prints them as five rows
of one shape:

| | who | side | driven by | level |
|---|---|---|---|---|
| #1 | Wren | market | **a person** -- a list of choices written down in advance | 2 |
| #2 | Rook | market | a rule -- mind the stall, answer whoever speaks, take what is offered | 2 |
| #3 | Bram | green | a rule -- stand about, then close on Sable and strike | 3 |
| #4 | Sable | amber | a rule -- the same, pointed at Bram | 3 |
| #5 | Odo | alone | a rule -- walk away from everything and stay away | 1 |

"Driven by" is a column of this report and of the scenario file that handed the
functions out. It is not a field on anything: `ControlLoop` reads
`Character.decide` and calls it, `ActionEngine.resolve` takes a scene, a
character and a choice, and neither has a parameter in which the difference could
be stated. The suite calls all five decision functions directly with the same two
arguments and requires the same answer shape from each -- an `Action`, or nothing.

**Wren is the human path, exercised rather than asserted.** Its ten turns are
written down in `ScriptedScenario.wren_choices`, in the order a person took them,
and the run carries out all ten. A screen is not a thing a simulation can have,
so a person's recorded turns are the only shape a person can take in a headless
run -- and this run takes it.

## What the run does, with the tick it does it on

| tick | what happens |
|---|---|
| 1 | Wren says "good morning" to Rook by name |
| 6 | Rook is interrupted mid-wait -- section 2.2's "dialogue opens" -- and answers |
| 11 | Wren is interrupted by the answer, and starts its walk again |
| 31 | Wren arrives at the stall; 34, the lantern is picked up |
| 54 | Wren arrives back at Rook and offers 12 coins for the silk cloak |
| 62 | Rook accepts: the cloak and the coins move in one exchange |
| 70 | Wren examines the cloak it now carries |
| 77 | Bram and Sable have come within `ENGAGE_RADIUS`; the board appears under them |
| 78 | both abandon what they were doing -- "combat began" -- and choose to strike |
| 85 | the match is decided; the survivor is handed back to real time |
| 104 | Wren, who never left real time, shouts "what was that noise?" |

The whole of it in one line of counts, off the loop itself:

```
reviews=40 changes=0 finished=71 attacked=7 combat began=2 spoken to=2
```

### The trade moved both halves

Read off the two inventories rather than off the transcript's wording:

| | before | after |
|---|---|---|
| Wren's money | 30 | 18 |
| Rook's money | 8 | 20 |
| the silk cloak | Rook carries it | Wren carries it |

`Inventory.trade` is all-or-nothing, so there is no state in which one half moved.

### The fight snapped on and came back off

```
t= 77  --     Bram and somebody of another band have met
    snap-in around #3 at (-426.100, 1.811, 407.000) radius=24.0 span=30.0 storey=0 joined=2
    snap-in board 15a5a4b9f14a7bfc cells=441 standable=440 holes=1 cliffs=6
    ...
    over rounds=4 survivors=1 winner=#2
t=133  --     the fight is over; real time again
    over turns=8 rounds=4 ending=decided survivors=1 fallen=1
    snap-out #3 fell
    snap-out #4 cell (-142,135) -> (-424.500, 2.092, 406.500) back to cell (-142,135) hp=16/38
```

`joined=2`: the fight took the two who met and nobody else. Measured from the
board's anchor at `(-426.1, 407.0)`, Wren is 50.8 world units away and Rook 52.7
-- both well outside `Encounter.JOIN_RADIUS` of 24 -- and Odo is 121.7 out. All
three go on being serviced on every one of the 160 ticks, fight or no fight, and
the market's own beats land while the quarrel is running. That is what "combat is
local" means as a number rather than a claim.

![Bram the knight and Sable the barbarian standing on the tactical lattice, the
board's cells drawn faintly over the grass](assets/scenario-quarrel.png)

*The same run at tick 80, with `--board` drawing the lattice the fight is resolved
on. Bram (helmeted, left) and Sable (right) are standing on cells; the pale
quadrilaterals under the grass are the board. The observer is in the foreground.*

## Reproducible from the seed

The run is a pure function of the scenario's constants and the world's fields.
Nothing in it reads a clock, an address or a random stream: the only number drawn
anywhere is the control loop's continue-bias, and that is *hashed* from the seed,
the character and the tick.

```
$ ./run_scenario.sh > a.txt
$ ./run_scenario.sh > b.txt
$ cmp a.txt b.txt && echo identical
identical
$ sha256sum reports/scenario-evidence.txt
8ade11b4858cfd0a8563094d756a46a897fdb4b3cbca71bed6c5d932251e9a57  reports/scenario-evidence.txt
```

The scene's own fingerprint at the end of the run -- every position, every
inventory, every offer, everything said -- is `f005fcd196acb1e7`, and it is
printed as the last line of the transcript. `tests/test_scenario.gd` runs the
command twice in two subprocesses, requires the bytes to match, and then requires
the transcript checked in here to be those same bytes, so this file cannot drift
from what the command prints.

The world fingerprint did not move: `./run_headless.sh --assets` still gives
`done ticks=100 chunks=41 built=69 final=d178d38879097c1c` at seed 1234, and
still loads zero visual files and zero render scripts. Nothing about generation
was touched.

## Two things the run found

The task this run answers says that a scenario is a scenario: if it needs a rule
that does not exist, report it rather than adding one. Two showed up.

### 1. A recorded list is drained by being asked

> **Since resolved.** `DecisionSource` now has a plan-shaped constructor beside
> its queue-shaped one: `DecisionSource.plan` offers the choice at the index of
> how many actions the character has actually had carried out, which the world
> counts in `ActionScene.actions_taken`, so being asked spends nothing. Wren's
> function is that rather than the scenario-local `recorded_turns` this section
> describes, and the run's bytes did not change. `DecisionSource.recorded` was
> kept as the queue, with its reasons written down. See
> reports/decision-plan.md. The section below describes what this run measured
> when it was written.

`DecisionSource.recorded` is a queue -- it hands over the *next* choice on every
call. That is right for `DecisionSource.drive`, where one call is one resolution,
and wrong under `ControlLoop`, which calls a decision function again every
`ControlLoop.REVIEW_EVERY` ticks to ask whether the character has changed its
mind. A queue answers that question with the next written-down choice; the
continue bias then keeps what is already running; and the choice is gone. A
person walking for twenty ticks loses three of their turns to having been asked.

Measured rather than argued: the suite plays this run twice with the same ten
choices, once read against what has been carried out and once through
`DecisionSource.recorded`, and counts how many turns each takes.

| Wren's decision function | turns resolved of 10 | re-evaluations in the run |
|---|---|---|
| read against what has been carried out | **10** | 40 |
| `DecisionSource.recorded`, a queue | **4** | 36 |

Six of the ten written-down turns went into answering questions instead of being
taken.

So Wren's function was `ScriptedScenario.recorded_turns`: the same recorded list,
offered at the index of how many turns the character has actually had *resolved*,
which `ControlLoop.actions_of` already counts. Asked twice while one action is
still running, a person says the same thing twice -- which is what somebody who
has not changed their mind says. It reads no position, no distance and no
possibility, and the loop cannot tell it from the four rules beside it.

This was scenario code, not a rule of the world. Whether `DecisionSource` should
grow a constructor for it was left to the layer that owns human input; it has
since been made, and the constructor is `DecisionSource.plan`.

### 2. An atomic attack cannot land in a fight that strikes every turn

> **Since resolved.** A turn now lasts as long as the weapon action that spends
> it: while the commander whose turn it is is part-way through an `attack`, the
> board plays no turn, so the span runs to its end on its own turn and the blow
> lands. In this run's fight every blow struck on the board is now one of the two
> commanders' own choices -- eight weapon actions, eight chosen attacks -- and
> `CombatPolicy` swings for nobody who chooses for itself. The same eight turns
> take about seven ticks each instead of one, which is why the run is 160 ticks
> rather than 110. See reports/turn-action-seam.md. The section below describes
> what this run measured when it was written.

`attack` occupies 6 ticks -- the catalogue's own column. A fight takes one whole
turn per tick, so with two commanders on the board a blow lands on each of them
every other tick. Being hit is one of section 2.2's four interruptions, so the
6-tick span is abandoned and begun again long before it runs out:

```
t= 78  Bram   began attack(target=4 item=common sword), 6 ticks
t= 80  Bram   interrupted (attacked), abandoned attack(target=4 item=common sword) 2/6t
t= 80  Bram   began attack(target=4 item=common sword), 6 ticks
t= 82  Bram   interrupted (attacked), abandoned attack(target=4 item=common sword) 2/6t
```

Both fighters chose to strike on every one of their re-evaluations, and not one
of those blows completed its span. The fight was resolved entirely by
`CombatPolicy`, which is the layer that plays a turn when nobody has chosen one.

Nothing here is broken -- every rule did what it says. What is missing is a
shared clock: the action layer measures an action in ticks and the turn economy
measures a turn in turns, and there is no rule anywhere that says how a
character's chosen weapon action becomes the weapon action of its own turn. The
seam itself works -- `./run_actions.sh`'s duel resolves an `attack` through
`ActionEngine.resolve` on the active commander's turn and it lands, spending that
turn's one weapon action -- so what has nobody in charge of it is the timing, not
the path.

`tests/test_scenario.gd` holds the seam as a check rather than a note. It used to
read the attack's cost off the catalogue, count the abandoned spans, and require
that no chosen attack completed; it now requires the opposite -- that both
fighters land blows they chose, that none is abandoned mid-swing, and that the
number of weapon actions the match resolved equals the number of chosen attacks
that finished, so nothing swung for anybody.

## What is applied here rather than invented

> **Since resolved.** When this run was written, nothing under `sim/` drove
> begin -> advance -> conclude for an action-surface scene, so `ScriptedScenario`
> applied the roster's four rules by hand: the pairing rule, the engage radius,
> one whole turn per tick through `Encounter.advance`, and the ordering inside
> the tick. All four now live once, in `ActionScene.fight_step()`, and this run
> calls it -- as does the world's own `CombatantRoster` and the second
> action-surface run, `./run_skirmish.sh`. See reports/fight-driver.md. The
> transcript below is unchanged to the byte.

The band is also why Wren and Rook can stand at arm's length to trade. The
world's only engagement rule is proximity between commanders of *different*
bands: it knows nothing about intent, so the only thing that can say "these two
are not enemies" is the band they are already in. Wren and Rook share one; Bram,
Sable and Odo each have their own.

## What else was checked

* all 33 suites pass headless, 191 854 checks, exit 0 -- `tests/test_scenario.gd`
  is the new one, 66 checks
* the three structure checks are OK: `sim/` references nothing in `render/`,
  `render/` draws the fight and holds none of it, and `sim/` names asset tags and
  no asset
* `tools/piece_mutations.sh` -- "all 19 broken rules were caught" -- and then, on
  its own and only after that line had printed, `tools/resolution_mutations.sh`
  -- "all 61 broken rules were caught". Neither harness touches anything this
  work added; they are run because the new file joins the source scans those
  suites make, and both scans still bite.
* two lists in the test suite had to be widened to admit `sim/scripted_scenario.gd`
  -- the files allowed to name one particular weapon (`tests/test_effects.gd`)
  and the files of the combat layer that read the item layer
  (`tests/test_items.gd`). Both failed first, naming the file, which is the
  checks doing their job.

## The commands

```
./run_scenario.sh                    # the transcript above, 160 ticks, seed 1234
./run_scenario.sh --ticks 200
./run_scenario_suite.sh              # just this suite
./run_tests.sh                       # every suite

xvfb-run -a ./run_render.sh --seed 1234 --scenario market \
    --camera 0 4.5 9.0 --aim 1.5 --screenshot-tick 6 \
    --screenshot "$PWD/reports/assets/scenario-market.png"
xvfb-run -a ./run_render.sh --seed 1234 --scenario quarrel --board \
    --camera 4 4.0 6.0 --aim 1.4 --screenshot-tick 4 \
    --screenshot "$PWD/reports/assets/scenario-quarrel.png"
```

The two render scenarios are the same run: `Simulation.begin_scenario` plays the
scenario headless to a stated tick and stands whoever is still standing where
that run left them, so the pictures are of the run rather than of a re-staging.
The render shell names a string and nothing else -- it may not name the combat
layer, and it does not name the scenario's cast either.
