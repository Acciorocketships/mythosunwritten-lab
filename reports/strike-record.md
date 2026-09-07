# The record of a blow

A blow is the one thing in this world that has to be *drawn*. A swing is a
motion; an arrow is a thing crossing the ground. Until this change the world's
record of a blow was

```gdscript
{"from": id, "to": id, "tick": int, "dealt": int, "out_of": int}
```

which is enough to work out what two people are to each other and not nearly
enough to draw anything. It does not say which motion, which art, where the blow
started, where it landed, which way the striker was turned, or whether the effect
arrived instantly or crossed the ground to get there. Every remaining piece of
this milestone — a weapon in a hand, a clip chosen by the attack's own tag, an
arrow that crosses the board — needs those before it can begin.

Nothing here was invented. `sim/attack.gd` already carried the sprite tag, the
animation tag and the movement; the board already knew the facing, the cells and
the turn. The record had to carry what the attack already knew, and reach the
render layer through the snapshot rather than through a simulation object.

`./run_strike.sh` is the walkthrough;
[reports/strike-evidence.txt](strike-evidence.txt) is its transcript.

## What one row says

One row per weapon action resolved on a board, in `ActionScene.blows`:

| field | what it says |
| --- | --- |
| `from`, `by`, `to` | who struck, what they are called, and who was struck — `0`, which is nobody, for a swing that found no one |
| `dealt`, `out_of`, `hits` | what it took in all, of the health the first one it found has at full, and how many it found |
| `attack`, `cooldown` | the effect's own name, and how many turns it waits before it may be used again |
| `facing`, `from_cell`, `to_cell`, `cells` | which way the striker was turned, the cell it stood on, the cell the blow landed on, and every cell the pattern covered |
| `sprite`, `animation`, `movement` | which art says what it is, which motion says it happened, and whether it landed where it was aimed or crossed the ground |
| `tick`, `round`, `fight` | the tick it began on, the round it was struck in, and which fight of this world's it belongs to |

The three tags are names out of `sim/asset_tags.gd` and nothing else: `point`,
`lunge`, `instant` for a spear's thrust; `arrow`, `shoot`, `projectile` for a
bow's. `./run_tests.sh --layers-only` still passes all four rules, so the
simulation names no asset path and never has.

## Where a blow is written down, and why there is only one place

Three things can spend a weapon action, and all three go through
`CombatMatch.attack`:

| who spends it | through | for |
| --- | --- | --- |
| a person | `BoardTurn.swing` | a character somebody is playing |
| the character itself | `ActionEngine._attack` | a decision function, scripted or a model's |
| the board's stand-in | `CombatPolicy._swing` | a commander nobody drives |

So `CombatMatch.attack` is where the row is written: it appends to the match's
own `struck` list, in the board's id space. `ActionScene` takes the rows off the
board (`_take_blows`), translates the ids through the fight's own
`Encounter.by_piece` map, and appends them to `blows` — the one function,
`note_blow`, that this world says a blow happened with. `ActionEngine` no longer
writes one itself; if it still did, blows chosen through the action surface would
be in the world twice and every other blow once.

The taking happens on both sides of each `fight_step`, so a blow struck between
two ticks — which is what a person's blow is — is in the world's record on the
next tick, carrying the tick it *began* on rather than the tick it was collected
on. The board is told where the world's clock is in `ActionScene.advance`, the
one place the clock moves.

**The check that there is one channel and not two is a scan, not a list.**
`tests/test_strike_record.gd` reads every `.gd` file under `sim/` and `render/`,
drops the comment lines, and looks for each shape a blow could be published in —
appending to the world's record, recording one on the board, defining `note_blow`
and naming it. It then asserts that each shape happens in exactly one file, and
that the file that appends is the file that defines it and the only file that
names it. Nothing in the test lists which file that should be, so a second
channel would fail it by existing rather than by being forgotten.

## The same record from either hand

`./run_strike.sh` stands two commanders on one board with the same spear. Alder's
turns are a person's, taken through `BoardTurn`; Briar's are its own decision
function's, serviced by `ControlLoop` and answered by `ActionEngine`. The first
blow each of them struck, field by field:

```
  field        Alder (a person)             Briar (its own choice)
  from         1                            2
  by           Alder                        Briar
  to           2                            1
  tick         10                           18
  round        1                            1
  fight        1                            1
  dealt        17                           12
  out_of       38                           38
  hits         1                            1
  attack       thrust                       thrust
  facing       1                            3
  from_cell    (-161,140)                   (-159,140)
  to_cell      (-159,140)                   (-161,140)
  cells        (-160,140) (-159,140)        (-161,140) (-160,140)
  sprite       point                        point
  animation    lunge                        lunge
  movement     instant                      instant
  cooldown     1                            1
  same fields: yes
```

Two things in that run are worth naming because they are about a person rather
than about the record. The person spends a turn every ten ticks and ends it a
tick after swinging: a person is not instant, and a blow landing in the very tick
the board passes to their opponent would take that opponent's turn away before it
could commit to anything — being struck ends what you had begun, which is
section 2.2's rule and not this file's. With those two, both sides land blows and
the run is a comparison rather than an execution.

## How it reaches the render layer

`CombatantRoster.snapshot()` — the dictionary the render shell already receives
every frame, beside the pieces and the ground — now carries the world's clock and
the most recent eight blows, each deep-copied because this engine's arrays share
their storage when assigned. The last section of the run prints exactly what
leaves:

```
what leaves the simulation, in the snapshot
  tick=31 round=3 fighting=yes fights_begun=1 blows=5
  #1 -> #2 thrust from (-161,140) to (-159,140) over 2 cells, lunge at tick 10
  #2 -> #1 thrust from (-159,140) to (-161,140) over 2 cells, lunge at tick 18
  ...
```

`FightSource.blow_in(snapshot)` is the render-side consumer, and it is a function
of that dictionary alone: it takes the newest row belonging to the fight now on
the board whose action has not finished waiting, and adds two subtractions —
`rounds_ago` and `ticks_ago` — off numbers in the same dictionary. The suite
hands it a snapshot written by hand, with no world, no roster, no fight and no
commander anywhere in the test, and it answers in full.

**The readout reads the same record.** The combat panel's last-blow strip used to
infer which blow was struck from a cooldown reading — an action whose whole wait
is still on it was spent this round. That reading was true and is still true, but
it could only ever say *which action*, never which way its striker was facing or
which cells it covered. The strip now names the blow out of the record, and the
cooldown rows on the panel went back to saying only what a commander may do next.

## What moved

| | before | after |
| --- | --- | --- |
| seed-1234 world fingerprint, 100 ticks | `32656f55cc5eeb1c` | `32656f55cc5eeb1c` |
| `./run_turn.sh` | — | byte-identical |
| `./run_encounter.sh` | — | byte-identical |
| `./run_scenario.sh` | — | byte-identical |
| `./run_headless.sh --ticks 60` | — | byte-identical |
| `./run_actions.sh`, `./run_loop.sh`, `./run_world.sh` | — | byte-identical |
| `./run_skirmish.sh` scene fingerprint | `b3b15913b10aca9e` | `a5901ad5d04898ff` |

Seven of the eight runs compared are byte-identical to the same runs on the
previous commit, which is what "the record reports what already happens" has to
mean: no combat rule changed, nothing costs more or less, nobody takes a
different number of hit points off anybody.

The one line that moves is the skirmish run's scene fingerprint, and it moves for
the reason the change was made. `ActionScene.fingerprint()` folds in the
relationship graph, and the graph is fed by the world's record of blows. Before
this change only blows chosen through the atomic action surface were recorded, so
in a fight the board played for two commanders — which is what the skirmish is —
the graph never heard about any of them. Now it hears about all of them, so the
two who fought are further apart afterwards than they used to be. Every other
number in that run — positions, health, the fight's beginning and end, what is
carried — is unchanged. No checked-in transcript quotes that fingerprint, so
nothing under `reports/` had to be re-recorded.

One thing folded from the record is deliberately *not* folded: a swing that found
nobody. It is on the world's record, because something happened and something
will draw it, but there is nobody for the other end of an edge, so
`CharacterUpkeep` steps over it.

## Where the numbers came from

```
./run_strike.sh                 # the walkthrough above, twice, diffed clean
./run_strike_suite.sh           # PASS  strike record  299 checks
./run_tests.sh                  # all 57 suites passed (200,574 checks)
./run_tests.sh --layers-only    # layer, combat, interface and asset checks all OK
```

Two hand-written lists in the suite had to grow, both of them lists of *files*
rather than of behaviour: `tests/test_items.gd` names every file under `sim/`
that reads the item layer and `tests/test_effects.gd` names every file that hands
out a weapon, and `sim/scripted_strike.gd` forges the spear its two commanders
carry. Both are there so that a file quietly picking up the item layer shows up;
this one did, and is named with its reason.

One thing found on the way and not fixed here, because it is older than this
change: `tests/test_goals.gd:320` raises "Out of bounds get index '1'" on
`sim/goals`' refusal list, on this commit and on the one before it. A runtime
error inside a claim does not fail the suite -- the goals suite reports PASS
either way -- so the rest of that claim has been silently not running.
