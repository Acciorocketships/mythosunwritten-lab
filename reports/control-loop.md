# The control loop, and a world that never waits for a decision

Section 2.2 of the design is three sentences. An action is *in progress* over
time; while it runs the character re-evaluates at some frequency, and may change
its mind but is biased toward continuing; and it re-evaluates immediately when
the action finishes or is interrupted — attacked while moving, combat starting,
dialogue opening. Section 12 adds one requirement on top of it: the simulation
never waits on a decision, "the character waits in-world instead of lagging the
game".

`sim/control_loop.gd` is those four things and nothing else. It decides nothing
and it resolves nothing: it reads a decision function off `Character.decide`,
calls it, and hands the answer to `ActionEngine.resolve`. What it contributes is
*when* it does that.

Everything below comes from `./run_loop.sh`, which prints the whole transcript
headless and exits 0.

## An action costs ticks, and the cost is in the one action table

Every row of `ActionCatalog.ROWS` now carries an `occupies` column beside its
section 2.1 wording and its section 10 call names:

```
the one list: 12 actions, 17 call names
  go_to          MoveTo MoveRelative Roam Flee         20t  go to (position / item / character)
  jump           Jump                                   4t  jump (position)
  attack         Attack                                 6t  attack (target, with which item)
  say            Talk                                   5t  say (text; targeted, or shout -> everyone in range hears)
  trade_propose  ProposeTrade                           4t  trade (propose; items + money in/out)
  trade_accept   AcceptTrade                            3t  trade (accept)
  trade_deny     DenyTrade                              2t  trade (deny)
  pick_up        Take                                   3t  pick up (ground or chest)
  drop           Drop                                   2t  drop (ground or chest)
  examine        Query ViewInventory AccessInventory    4t  examine (observable info on an item/person in sight)
  interact       Interact                               6t  interact (generic; target entity + item used)
  wait           Wait                                   1t  wait (duration)
```

It is in the table rather than beside the loop for the same reason the two name
columns are in the table: a cost written beside the loop would be a thirteenth
list of the twelve actions, and lists of the twelve actions drift.
`ActionCatalog.faults()` gained one line for it — a row that costs nothing is a
fault, and the suite runs the checker over a table with a free action in it and
requires the catch. A `wait` is the one action that names its own duration,
because section 2.1 spells it "wait (duration)"; that reading lives in
`ControlLoop.occupies()` and nowhere else.

**A committed action has not happened yet.** The engine resolves it when the
span runs out, so an abandoned span never reaches the engine at all — a walker
struck halfway is still standing where it started, and the suite checks that by
reading the walker's position. This is what keeps an atomic action atomic: one
call, one answer, one place it is decided.

## The cadence is one constant

`ControlLoop.REVIEW_EVERY` is 5 ticks — about four times a second at the rate
the world is stepped. One walk, watched for 25 ticks, with nothing in the world
to interrupt it:

```
cadence: one walk, 25 ticks watched
  a go_to costs 20 ticks; re-evaluated every 5
  t=  1  Rook   began go_to(target=(-450.000, 420.000)), 20 ticks
  t=  6  Rook   thought again at 5/20t, wanted the same thing
  t= 11  Rook   thought again at 10/20t, wanted the same thing
  t= 16  Rook   thought again at 15/20t, wanted the same thing
  t= 21  Rook   finished go_to(...) -> go_to ok at=(-450.300, 420.000) walked=29.7 steps=33
  t= 21  Rook   began go_to(target=(-450.000, 420.000)), 20 ticks
  reviews=3 changes=0 finished=1 attacked=0 combat began=0 spoken to=0
```

The last two lines share a tick: the walk finished and the next decision was
made in the same tick, which is what "re-evaluates immediately" means when the
clock is a tick counter.

"One constant rather than scattered" is checked by reading the source rather
than asserted: exactly one file under `sim/` declares `REVIEW_EVERY`, that file
uses it once, and every other file that mentions it writes
`ControlLoop.REVIEW_EVERY` — a read of the one constant rather than a number of
its own.

## All four interruptions are read off the world

Nobody reports an interruption and nothing has to remember to. At the end of
each tick the loop compares the world against what it was a tick ago: a health
score that fell, a fight that was not under way before, a word addressed to
somebody by name. Each of section 2.2's events has its own headless case and its
own check in the suite.

**Being attacked while acting.** The one whose turn it is settles in to wait out
twenty ticks -- a wait is not spent out of a turn, so the turn passes at once --
and the other spends its own turn on a spear. The blow therefore lands on the
striker's own turn, into a wait that is still running.

```
  Rook waits out its turn; Vex spends its own on a spear. Rook starts on 38 health
  t=  1  Rook   began wait(ticks=20), 20 ticks
  t=  2  Vex    began attack(target=1 item=common spear), 6 ticks
  t=  8  Vex    finished attack(...) -> attack ok attack=thrust cells=2 hits=1 dealt=8
  t=  8  Rook   interrupted (attacked), abandoned wait(ticks=20) 7/20t
  Rook ends on 30 health
```

This case is played through `ActionScene.fight_step()` rather than on a board
nobody drives, because the turn is now what a commander spends an attack out of:
see reports/turn-action-seam.md.

**Combat starting.** Two characters walking; the fight begins under them between
one tick and the next.

```
  t=  1  Rook   began go_to(target=(-453.000, 420.000)), 20 ticks
  t=  1  Vex    began go_to(target=(-447.000, 420.000)), 20 ticks
  t=  5  Rook   interrupted (combat began), abandoned go_to(...) 4/20t
  t=  5  Vex    interrupted (combat began), abandoned go_to(...) 4/20t
```

Both walks are dropped. Only the one whose turn it is is asked for something
new, because a character on a board chooses on its own turn.

**A conversation opening.** Being addressed by name interrupts; being shouted at
does not, because a shout is the one kind of speech nobody has to answer. The
suite checks both directions — a shout heard by everybody interrupts nobody, and
the walker is still walking after it.

```
  t=  3  Wren   began say(text=a word with you target=1), 5 ticks
  t=  8  Wren   finished say(...) -> say ok shout=false heard_by=1
  t=  8  Rook   interrupted (spoken to), abandoned go_to(...) 7/20t
  Rook never arrived: still at (-480.000, 420.000)
```

**An action finishing** is the fourth, and the one that needs no interference:
the `finished` line and the next `began` line carry the same tick.

## The bias is one number, and it is measured

`ControlLoop.CONTINUE_BIAS` is 0.85: at a re-evaluation that proposes something
*different*, that is the chance the character stays with what it is already
doing. It is a chance rather than a margin because a decision function returns a
choice and not a score, and inventing a score would put a rule about preferences
inside the loop — the one thing this layer must not hold.

A number that changes nothing when you remove it is not doing anything. So a
deliberately restless character — one that wants somewhere else every single
time it is asked, making every re-evaluation a real disagreement — is run for
1200 ticks at the bias and again with the bias deleted:

| continue bias | reviews | changes | changed |
| --- | --- | --- | --- |
| 0.85 | 193 | 31 | **16.1%** |
| 0.00 (broken) | 239 | 239 | **100.0%** |

16.1% against the 15.0% the number states, over 193 re-evaluations. With the
bias taken away the character abandons every single thing it starts.

The number is consulted in exactly one line of the whole simulation, and the
suite checks that by scanning `sim/` for any line that compares against it. What
it draws is *hashed* from the seed, the character and the tick rather than taken
off a stream — the discipline `sim/damage.gd` already keeps with the die, and
for the same reason: a stream makes the answer depend on how many questions came
before it. That also makes the next section structural rather than lucky.

## A decision that takes arbitrarily long does not stall anybody

No model anywhere — the model layer is a later milestone. The stand-in is
`DecisionSource.deliberate(inner, ticks)`, which wraps any decision function and
will not answer for a stated number of ticks. **It counts its slowness in ticks,
never in time**: it reads `ActionScene.tick` and nothing else, so nothing under
`sim/` had to learn what a clock is. A decision function with no answer yet
returns null, which every driver already reads as "nothing chosen"; the
character stands there with nothing committed and everybody else is serviced in
the same tick.

Three characters, eighty ticks, one of them taking forty ticks to make up its
mind, run beside the same world where all three answer at once:

```
run                           Ash ticks/actions  Bryn ticks/actions Cass ticks/actions
everybody answers at once     80 / 3             80 / 2             80 / 2
Ash takes 40 ticks to think   80 / 1             80 / 2             80 / 2
```

**Bryn was serviced for 80 ticks with a fast Ash and 80 with a slow one**, and so
was Cass. Each resolved the same number of actions either way, and all 42 lines
of their journals are identical between the two runs — the loop compares them
and says so. Ash, meanwhile:

```
  t=  1  Ash    has not decided yet, and waits in the world
  t= 41  Ash    began go_to(target=(1.500, 0.000)), 20 ticks
  t= 61  Ash    finished go_to(...) -> go_to ok at=(1.500, 0.000) walked=1.5 steps=2
```

It stood at (0.000, 0.000) for the whole time it was thinking, then acted. The
world did not wait; the character did.

## Nothing under `sim/` reads a clock

The suite scans every file under `sim/` with comments stripped for `Time`, `OS`,
`Engine`, `Performance`, `get_ticks_msec`, `get_ticks_usec`,
`get_unix_time_from_system` and the rest, and finds none. The scan is then run
over two lines that do read a clock and must catch both, and over two lines that
really are under `sim/` and must not — so the empty result is the code's doing
and not the scan's.

This is why the slow decider counts in ticks. Making it block on real time would
have required exactly the thing this check forbids.

## Determinism

Two separate processes, same seed:

```
$ ./run_loop.sh | sha256sum
928c67df9a94501075655d7a9643b4c41445e2179059d0c2a0029583381dcb18
$ ./run_loop.sh | sha256sum
928c67df9a94501075655d7a9643b4c41445e2179059d0c2a0029583381dcb18
```

The suite runs the script twice itself and compares the bytes, so this is a
check rather than a note.

Generation is untouched, and the world's fingerprint has not moved:

```
$ ./run_headless.sh
done ticks=100 chunks=41 built=69 final=d178d38879097c1c
$ ./run_headless.sh
done ticks=100 chunks=41 built=69 final=d178d38879097c1c
```

## Running it

```
./run_loop.sh                   # the whole transcript above
./run_loop_suite.sh             # just the control-loop suite (71 checks)
./run_tests.sh                  # all 32 suites (191,787 checks)
```
