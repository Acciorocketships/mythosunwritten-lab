# One driver for a fight, on the action surface

`sim/action_scene.gd` now holds the whole of the real-time -> board -> real-time
cycle, in one method, and everything that drives a fight calls it: the world's
own `CombatantRoster`, the five-character run, and a new second run built on the
atomic action surface. Before this there were two drivers and the second one was
written by hand in a scenario.

    ./run_skirmish.sh          # the second action-surface run: a patrol of two and one stranger
    ./run_scenario.sh          # the five-character run, byte-for-byte as before
    ./run_headless.sh          # the world, byte-for-byte as before

## Which shape was chosen, and why

The task offered two: *the action layer gets the roster's cycle*, or *the roster
drives an `ActionScene`*. **The action layer got the cycle.** `ActionScene`
gained `fight_step()`, `ENGAGE_RADIUS` and the pairing rule; `CombatantRoster`
kept the real-time walk, the counters and the world-facing view, and holds an
`ActionScene` to put them on.

The reason is the direction the rules were already pointing. Every part of a
fight the roster ran was already reached through classes the scene owns -- the
scene's actors are `Combatant`s, its fight is an `Encounter`, and
`ActionEngine.attack` already handed a blow to `scene.fight` rather than
resolving one. What the roster contributed on top of that was one thing the
action surface does not have and should not gain: continuous movement by heading
and speed. Moving the cycle down to the scene therefore moved only the parts both
sides needed, and left the roster holding only the part that is genuinely its
own.

The other shape -- `CombatantRoster.step(scene)`, a roster that drives a scene it
does not own -- would have put the four rules in a class the action surface has
to name in order to hold a fight at all, which is the shape a scenario would go
on copying rather than calling. It would also have left two containers of
combatants (a roster's `members` and a scene's `actors`) with one id space
between them, which `sim/action_scene.gd`'s own docstring names as the drift it
exists to avoid.

## The four rules, and where they are now

Each is one string, searched for over `sim/`:

```
$ grep -rn "_two_who_have_met(" sim/ --include=*.gd
sim/action_scene.gd:312:	var anchor := _two_who_have_met()
sim/action_scene.gd:371:func _two_who_have_met() -> Combatant:

$ grep -rn "ENGAGE_RADIUS :=" sim/ --include=*.gd
sim/action_scene.gd:55:const ENGAGE_RADIUS := 9.0

$ grep -rn "fight.advance()" sim/ --include=*.gd
sim/action_scene.gd:305:		turn["lines"] = fight.advance()

$ grep -rn "func fight_step(" sim/ --include=*.gd
sim/action_scene.gd:297:func fight_step() -> Dictionary:
```

One file, four rules, and the search is held as a check rather than as a
paragraph: `tests/test_fight_driver.gd` opens `sim/`, reads every file it finds
rather than a list typed into the test, and requires each of the four strings to
appear in exactly one of them -- then requires that one to be the same file for
all four. The same scan for `func `, which is in every file, finds it in every
file, so an answer of one means "only there" and not "the scan read nothing".

And who calls it:

```
$ grep -rln "scene.fight_step()" sim/ --include=*.gd
sim/combatant_roster.gd
sim/scripted_scenario.gd
sim/scripted_skirmish.gd
```

## What `fight_step()` decides

One tick of whichever fight is on, or of the one about to begin. Two halves, and
the order between them is the rule:

* a fight that is on takes **one whole turn** through `Encounter.advance`, and if
  that turn finished it, the survivors are handed back to real time in the same
  call;
* only when no fight is on is the **pairing rule** asked -- two commanders of
  different bands within `ENGAGE_RADIUS` (9.0 world units, three lattice cells),
  pairs walked in id order, the lower-id one anchoring the board. So a fight that
  ends on a tick does not immediately start another with whoever is still
  standing next to it.

Every driver calls it once per tick, **after** that tick's characters have been
serviced -- the roster after its combatants have walked, a scenario after its
control loop has run -- so a fight that begins on one tick is noticed as an
interruption on the next.

It returns four fields rather than a list of lines, because a caller writing a
transcript has to interleave its own sentences with the fight's: `began` is the
anchoring commander when a fight began this tick, `lines` is what the fight
wrote, `ended` says whether it finished, and `over` is the snap-out. Nothing in
the scene formats anything; how a run announces a fight is the run's business,
which is why the five-character transcript is unchanged to the byte.

## What did not change

`CombatantRoster.step` used to run `advance -> walk everyone not in the fight ->
conclude`. It now runs `walk everybody -> fight_step()`, which is the same thing:
`Combatant.walk` returns at once for anyone who is `fighting`, so "everybody" and
"everybody not in the fight" are the same set while a fight is on, and walking
before the turn rather than after it cannot change either, because a walk reads
only its own combatant and the ground.

Nothing about what a fight *does* moved. The damage matrix, the capture rule, the
turn economy and everything `CombatResolution` decides are untouched; this moved
who calls the fight.

One rule was unified rather than kept twice, and it was a rule about clearing up
after a fight rather than about the fight: `ActionScene` used to drop an actor
whose piece was not alive, and `CombatantRoster` dropped whoever the encounter
said had fallen. Those differ for a minion despawned by the king rule, which
never lost a hit point. The roster's version is the one that survived, so a
king's minions leave the world on the action surface too.

## The second scenario

`./run_skirmish.sh` is the proof that a scene on the action surface can reach a
fight without a copy of the block. Three commanders in two bands: Ash and Fen are
one watch standing together, Corvid is a stranger who walks in from 34 units
east. Every tick the run services its characters with `ControlLoop` and then
calls `scene.fight_step()`, and that is the entirety of what it says about
fighting -- no radius, no pairing loop, no cadence, no conclusion.

It is a patrol rather than a duel so that it exercises the parts of the pairing
rule a duel cannot show: the pair is chosen in id order, so the first pair the
rule can accept is Ash and the stranger and the board is anchored on Ash; and a
band is not a side of the board, so Fen -- who triggered nothing -- joins the
fight it did not start because it is inside `Encounter.JOIN_RADIUS` of the anchor.

    t= 21  Corvid finished go_to(target=1) -> go_to ok at=(-478.344, 420.097) walked=32.4 steps=36
    t= 21  --     Ash meets somebody of another band
        snap-in around #1 at (-480.000, -2.033, 420.000) radius=24.0 span=30.0 storey=0 joined=3
        snap-in board c1bbe0c17d86ad90 cells=441 standable=401 holes=40 cliffs=42
    ...
    t= 31  --     the fight is over; real time again
        over turns=10 rounds=4 ending=decided survivors=1 fallen=2
        snap-out #1 fell
        snap-out #2 fell
        snap-out #3 cell (-160,139) -> (-478.500, -2.106, 418.500) back to cell (-160,139) hp=6/44

Two of three were on the board against one, the fight was decided in 4 rounds
over 10 turns, and the survivor was handed back to real time at t=31 with 6 of 44
hit points. `tests/test_fight_driver.gd` plays it twice and requires identical
transcripts, and requires the run to have begun exactly one fight, ended it, put
all three commanders on the board, and left somebody behind.
