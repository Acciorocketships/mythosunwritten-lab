# A turn lasts as long as the weapon action that spends it

A commander on the tactical board used to be a spectator in its own fight. It
chose `attack` on every re-evaluation, and not one of those blows ever landed:
the whole quarrel was fought by `CombatPolicy`, the board's stand-in chooser.
This is the rule that settles it, why the two other candidate rules were rejected
on measurements rather than on taste, and the runs that show it working.

`./run_turn.sh` is the walkthrough. `./run_scenario.sh` and `./run_skirmish.sh`
are the two existing runs it changes.

## What was wrong, in four numbers

Nothing was broken. Four rules, each correct on its own, could not all be true at
once:

| rule | where | number |
| --- | --- | --- |
| an atomic `attack` occupies ticks | `ActionCatalog.ROWS` | 6 ticks |
| a fight takes a whole turn every tick | `Encounter.advance` | 1 turn per tick |
| being hit ends what you were doing | `ControlLoop.ATTACKED` | — |
| a blow may only be struck on the actor's turn | `ActionEngine._attack` | — |

With two commanders on a board, a round is two ticks, so each is struck every
other tick. A six-tick span therefore never survives to its end, and even if it
had, six ticks is three rounds later — it would no longer be that commander's
turn. Here is the scenario's quarrel before the change, taken from the run's own
journal:

```
t= 78  Bram   began attack(target=4 item=common sword), 6 ticks
t= 78  Sable  began attack(target=3 item=common spear), 6 ticks
      face #1 east
      attack #1 cut cells=3 hits=1
        hit #1->#2 power=5 x150 swing=105 flank def=0 dealt=7 hp=31/38
    round 1 turn #2 at (-142,135) facing=north hp=31/38 def=0 spear + boots(4/4)
t= 79  Sable  interrupted (attacked), abandoned attack(target=3 item=common spear) 1/6t
t= 79  Sable  began attack(target=3 item=common spear), 6 ticks
      face #2 west
      attack #2 thrust cells=2 hits=1
        hit #2->#1 power=12 x100 swing=101 front def=0 dealt=12 hp=26/38
    round 2 turn #1 at (-143,135) facing=east hp=26/38 def=0 sword + boots(4/4)
t= 80  Bram   interrupted (attacked), abandoned attack(target=4 item=common sword) 2/6t
t= 80  Bram   began attack(target=4 item=common sword), 6 ticks
```

Every `attack #N` line is `CombatPolicy` swinging; every `began`/`interrupted`
pair is a character choosing and being cut off. Over the whole fight: **eight
weapon actions resolved, none of them chosen by anybody, and zero chosen blows
carried out.**

And the same fight after:

```
t= 78  Bram   began attack(target=4 item=common sword), 6 ticks
t= 83  Bram   thought again at 5/6t, wanted the same thing
t= 84  Bram   finished attack(target=4 item=common sword) -> attack ok attack=cut cells=3 hits=1 dealt=7
      attack #1 cut cells=3 hits=1
        hit #1->#2 power=5 x150 swing=105 flank def=0 dealt=7 hp=31/38
      face #1 east
    round 1 turn #2 at (-142,135) facing=north hp=31/38 def=0 spear + boots(4/4)
t= 85  Sable  began attack(target=3 item=common spear), 6 ticks
t= 90  Sable  thought again at 5/6t, wanted the same thing
t= 91  Sable  finished attack(target=3 item=common spear) -> attack ok attack=thrust cells=2 hits=1 dealt=12
      attack #2 thrust cells=2 hits=1
        hit #2->#1 power=12 x100 swing=101 front def=0 dealt=12 hp=26/38
      face #2 west
    round 2 turn #1 at (-143,135) facing=east hp=26/38 def=0 sword + boots(4/4)
```

The two damage numbers are the same numbers as before — `dealt=7` off the same
`swing=105`, `dealt=12` off the same `swing=101`. Nothing about what a landing
blow does changed; what changed is who asked for it.

**Eight weapon actions resolved, all eight of them chosen.** The fight is the
same fight — four rounds, eight turns, one survivor — lived at the rate the
characters in it actually act.

## The rule

> **A turn lasts as long as the weapon action that spends it.**
>
> While the commander whose turn it is is part-way through an `attack` it
> committed to, the board plays no turn at all. The tick that span runs out the
> blow is resolved — still on its own turn — and spends that turn's one weapon
> action; the turn is then played out and passes on.
>
> Only an attack holds a turn, because only an attack is spent out of one. A
> commander that has committed nothing when its turn comes up holds nothing: the
> turn is played the tick it comes up, and the commander has passed.

Three sentences of code carry it, one file each:

* `ActionScene.fight_step()` returns without playing a turn while
  `_turn_is_being_spent()`. What is in progress is not stored there — the scene
  reads it through `in_progress`, a window onto whatever is stepping the
  characters — so a scene nobody steps plays a turn every time it is asked,
  which is what the world's own `CombatantRoster` does and why the world's fights
  did not move.
* `ControlLoop._may_choose()` lets a character on a board choose on its own turn
  and once on it. That is what makes the blow it commits to the blow of its own
  turn, and it is why nobody else's blow can land on it mid-swing. The gate is on
  *choosing* only: an action already under way runs on whosever turn it is, so
  being struck part-way through something is still one of section 2.2's
  interruptions.
* `CombatPolicy._swing()` returns at once for a commander that
  `chooses_for_itself()` — one with a decision function on its sheet. The move,
  the facing and the minion stay the board's; the weapon action is the
  character's. Nothing here asks *what sort* of decision function it is: a
  person's recorded turns and a program's rule are one `Callable` and both
  answer `true`.

### What it costs, measured

The board waits, and the wait is bounded by one action's span. From
`./run_turn.sh`, which computes the bound off the catalogue rather than typing
it:

```
what the board waits for (an attack occupies 6 ticks)
  run                         turns   landed  longest    bound
  both choosing                   5        5        7        7
  one deliberating                8        5        7        7
```

`longest` is the largest gap in ticks between two turns being played; `bound` is
an attack's span plus the tick the turn is played on. A fight of the same number
of turns therefore takes about seven times as many ticks as it used to. That is
the price of the rule and it is the whole of the price.

### A fight never waits on a decision

Section 12 requires that the simulation never blocks on a decision. It still
does not, and the reason is structural rather than a timeout: a commander that
has committed nothing holds nothing, so there is nothing for the board to wait
on. `./run_turn.sh` plays the same duel with one side wrapped in
`DecisionSource.deliberate`, which refuses to answer for twenty ticks at a time:

```
  t=  1  Hale   has not decided yet, and waits in the world
      move #1 (-161,140)->(-160,140)
      face #1 east
    round 1 turn #2 at (-159,140) facing=north hp=38/38 def=0 spear + bare
  t=  2  Odile  began attack(target=1 item=common spear), 6 ticks
  ...
  t= 25  Hale   began attack(target=2 item=common spear), 6 ticks
  t= 31  Hale   finished attack(target=2 item=common spear) -> attack ok ... dealt=12
```

Hale's turn comes up at tick 1, it has no answer, and the turn is played and
passed in the same tick. Odile's blows go on landing through three rounds. Hale
strikes as soon as it has an answer, and the fight reaches a decision. The
deliberating run plays **more** turns in the same number of ticks than the run
where both answer — eight against five — because turns nobody answered cost the
board a single tick each.

## The two rules that were rejected, and on what

The other two candidates were named in the work item. Neither is a matter of
taste; each fails on something the current code measures.

### A held action, applied on the commander's next turn

The commander commits to an attack; the span runs; when it completes the blow is
*held* and applied whenever that commander's turn next comes around.

**Rejected because the span still does not complete.** Holding a finished action
changes nothing about the four numbers above: the span is abandoned at 1/6 or 2/6
of its length by the next blow to land, and an abandoned span never reaches the
engine at all. That is not an opinion — it was the measurement the run reported:
zero completed attacks out of every blow both fighters chose.

Holding at *commitment* time instead — registering the choice with the fight the
moment it is made, and applying it a turn later whatever happens to the span —
does land blows, but it breaks a rule the control-loop layer is built on: an
interrupted action never reaches `ActionEngine`. The suite already pins that with
a measurement of its own — a walker struck at 7/20 of a twenty-tick walk is still
standing where it started, checked by reading its position rather than the
journal — so this variant would have to delete an existing check to pass.

### The board grants a turn on the tick a span ends

Whoever's action span runs out is given a turn, then and there.

**Rejected because on the measured behaviour no span ever ends, so no turn is
ever granted.** Two commanders striking each other abandon every span; a board
that only advances when a span completes would have advanced zero turns and the
fight would never have reached its conclusion, its round limit, or the snap back
to real time — the world would simply have stayed in a fight.

It also costs a stated identity in the combat layer. `CombatMatch` documents that
a commander's turn count and `round_number` are the same number counted twice,
which holds precisely because "every living commander takes exactly one turn
between two round increments" — and the file says in as many words that this
stops being true "the moment a commander could join a match already in progress,
or skip a turn, or take two". Granting turns in span-completion order is exactly
that, so a cooldown counted in turns would stop meaning what it says.

## What moved, and what did not

| | before | after |
| --- | --- | --- |
| `./run_headless.sh` | `d178d38879097c1c` | `d178d38879097c1c`, byte-identical |
| scenario: weapon actions resolved / chosen | 8 / 0 | 8 / 8 |
| scenario: ticks, fight outcome | 110, decided in 4 rounds | 160, decided in 4 rounds |
| skirmish: chosen blows landed | 0 | 4 |
| suites | 34 | 35 |

The world did not move: no generation rule was touched, and the world's own
fights are unchanged because a scene nobody steps leaves `in_progress` unset and
takes a turn every time it is asked.

The skirmish changed shape as well as timing, and the change is worth stating.
Its two watchmen share a band and their rule will not strike a band-mate; the
board has no bands, only owners, so once the stranger falls the two who are left
stand facing each other. `CombatPolicy` used to make them cut each other down.
Now nobody swings for them, and the fight runs to `Encounter.MAX_ROUNDS` and
reports `ending=limit` — the first scripted run to reach the round limit the
fight layer has always carried, and exactly the case that limit exists for.

## One rule for everyone

Nothing in any of this asks who is driving a character. `Commander.chooses_for_itself()`
asks whether there is a decision function, never what kind; `ControlLoop` reads
the `Callable` off the sheet and has nothing to branch on; the engine's own scan
— every line of the five action-surface files, comments and string literals
stripped, against the words a line would use to ask who is calling — still finds
nothing, and still catches the control lines that do ask.

`tests/test_turn_seam.gd` plays the same duel twice, once driven by a person's
written-down turns and once by a program's rule, and compares the worlds they
leave behind by fingerprint. They are the same world and the same number of blows.

## What holds this

`tests/test_turn_seam.gd`, five claims plus a determinism witness:

1. both commanders land a blow they chose; none is refused for being out of turn
   and none is abandoned mid-swing;
2. the number of weapon actions the match resolved equals the number of chosen
   attacks that finished — the check that fails hardest on the old behaviour,
   where those counts were eight and zero;
3. the longest a turn was ever held is at most an attack's span plus one,
   computed off the catalogue, and is greater than one tick;
4. with one side deliberating, its turns come up and pass, the fight plays at
   least as many turns as when both answer, and it still reaches a decision;
5. a person's recorded turns and a program's rule leave the same world.

`tests/test_scenario.gd`'s seventh claim was inverted rather than deleted: it used
to require that no chosen attack completed, and now requires that both fighters
land blows they chose and that every weapon action the match resolved was one
somebody chose.

## One defect found on the way

A commander's own blow is resolved by `ActionEngine` between one call to
`Encounter.advance()` and the next, and `advance()` copied the match's transcript
from a mark taken at the top of its own call — so every line the chosen blow
wrote, the `attack #N` line and the `hit #N->#M` line under it, was dropped from
the fight's transcript. It is a cursor now (`Encounter._copied`), read from
wherever it was left, so nothing the match writes is lost and nothing is written
twice. This is why the damage numbers appear in the "after" transcript above at
all.

## Running it

```
./run_turn.sh          # both blows land, a turn nobody answered, and what the board waits for
./run_scenario.sh      # the five-character run; its quarrel is now fought by its characters
./run_skirmish.sh      # the patrol and the stranger; the stand-off that follows
./run_tests.sh         # every suite, the turn seam among them
```
