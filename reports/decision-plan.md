# A written-down plan is not drained by being asked

A character's next action is chosen by one `Callable` on its sheet —
`Character.decide`, taking the world and the character and returning one `Action`
or nothing. Section 1's "no preferential treatment" principle puts the whole of
the player/NPC difference in that one field, so the shape a person's turns take
in it is not a detail of a test harness: it is the shape the eventual
human-input layer will hand the simulation.

Until now the library had one shape for written-down choices,
`DecisionSource.recorded`, and it was **a queue**: it hands over the *next* entry
every time it is called. `ControlLoop` calls a decision function more than once
per action — every `ControlLoop.REVIEW_EVERY` (5) ticks while an action runs, to
ask whether the character has changed its mind. So a question was answered with a
turn, the continue bias then kept what was already running, and the turn was
gone. A list survived untouched only if every action in it cost fewer than five
ticks, which a `go_to` at twenty never does.

## The rule

**`DecisionSource.plan(choices)`: the choice offered is the one at the index of
how many actions the character has actually had carried out.** Being asked
changes nothing; only the world carrying something out moves the plan on.

Three consequences, and they are the whole of the shape:

* **Asked again while the action is still running**, it offers that same action
  back — which is what somebody who has not changed their mind says, and what
  makes a review line in the transcript read `wanted the same thing`.
* **Asked again after an action was abandoned part-way through** (struck while
  walking, say), it offers that action again: an interrupted walk was not taken,
  so it is still what was planned.
* **Asked once an action has been resolved**, it moves on to the next entry.

The position comes from the world, not from the driver. `ActionEngine.resolve` is
the one path every action takes, so it is where the count is kept
(`ActionScene.actions_taken`, read by `ActionScene.actions_of`). That matters for
two reasons beyond tidiness: a plan works the same under `DecisionSource.drive`
and under `ControlLoop`, so a user interface would not be coupled to whichever
one is stepping the world; and there is no longer a reference ring — the loop
used to hold the scene, the scene the sheet, the sheet the list and the list the
loop, which is why `ScriptedScenario.release` had to exist to cut it.

## The measurement, before and after

The same ten choices (Wren's, in the checked-in five-character run at seed 1234,
160 ticks), counted two ways: what `ControlLoop.actions_of` resolved, and what
the decision function will still hand over when the run is done. Ten were written
down, so for a list that survives being asked the two add up to ten.

| Wren's decision function | turns resolved | left in the source | accounted for | re-evaluations |
|---|---|---|---|---|
| **before** — read against what has been carried out (scenario-local helper) | 10 | — | — | 57 |
| **before** — `DecisionSource.recorded`, a queue | **4** | — | — | 53 |
| **after** — `DecisionSource.plan` | **10** | 0 | **10 of 10** | 57 |
| **after** — `DecisionSource.recorded`, a queue | **4** | 0 | **4 of 10** | 53 |

Six of the ten went into answering questions instead of being taken, and are
accounted for nowhere. The plan loses none. Raw output of both runs:
[reports/decision-plan-evidence.txt](decision-plan-evidence.txt), produced by
`tools/critic_recorded_drain_probe.gd`. The claim is held in the suite by
`tests/test_scenario.gd::_a_plan_is_not_drained_by_being_asked`, which plays both
runs and computes both numbers, and at unit scale by
`tests/test_control_loop.gd::_being_asked_again_does_not_spend_a_planned_turn`,
where a two-entry list under one loop has both entries carried out as a plan and
loses one as a queue.

## Why `recorded()` was kept rather than removed

Three reasons, and the third is the one that decides it.

1. Under `DecisionSource.drive` one call *is* one resolution, so the two shapes
   are the same thing there and the queue is the simpler of them — it reads
   neither of its two arguments.
2. It is the one decision function that ignores both the world and the character
   it is handed, which is what makes the shared
   `func(scene, actor) -> Action` signature demonstrable: a recorded list and a
   rule reading the world can only share a signature if one of them can ignore
   it.
3. **The two genuinely mean different things on an interruption.** A queue treats
   an abandoned action as spent; a plan treats it as still wanted. Both are
   things somebody might mean, and `tests/test_control_loop.gd` wants the first
   of them: the case that shows an interrupted action never reaches the engine is
   written with a queue precisely so that the abandoned wait is not immediately
   re-committed.

It is also, of course, what the drain is measured against: a measurement of a
shape that no longer exists is not a measurement.

## Argued against what a human-input layer needs

This was settled now, before any interface exists, because the interface is what
will sit in `Character.decide` and the loop will ask it the same way it asks
everything else. Three properties a plan has and a queue does not:

* **A question is not a commitment.** The loop asks the player's decision
  function every five ticks whether they have changed their mind. With a queue,
  merely being asked spends the next thing the player asked for; with a plan, the
  answer is "still doing that" and the player's queued intent is untouched. This
  is the property the user interface actually needs, because it cannot control
  how often the loop asks.
* **Idempotent reads.** The plan can be called any number of times with the same
  answer, so a viewer or a debug overlay may ask "what will this character do
  next?" without changing the answer. A queue cannot be inspected without being
  consumed.
* **An interrupted action is still what was wanted.** A player attacked mid-walk
  has not thereby cancelled the walk. A plan re-offers it; the player can still
  change their mind, because on their next real decision they will replace the
  plan — which is exactly what an interface does when the person clicks
  something else.

The one thing a plan does *not* settle is what happens when a person has not
decided yet: that is `DecisionSource.deliberate`'s answer — return null, and the
character waits in the world while everybody else carries on. A real interface
is a plan whose entries arrive over time, which is the two of these together.

## What did not move

* `./run_headless.sh` prints the same bytes it printed before the change
  (`done ticks=100 chunks=41 built=69 final=d178d38879097c1c`): no generation
  rule was touched and the world did not move.
* `./run_scenario.sh` prints the same bytes too, and
  `reports/scenario-evidence.txt` is still what the command prints. The scenario
  now uses `DecisionSource.plan` where it used its own local
  `ScriptedScenario.recorded_turns`, and the two agree turn for turn — which is
  the point: the scenario had already had to write this shape by hand, and now
  it does not.
* All 35 suites pass — 191,944 checks, against 191,932 before the change; the
  twelve new ones are the two measurements above (control loop 71 → 78, scenario
  68 → 73). `./run_tests.sh --layers-only` still reports the three structure
  checks OK.
