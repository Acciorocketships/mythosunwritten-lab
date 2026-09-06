# What a character is after

Until this step a character sheet carried one line of prose called `goal`, and
nothing read it. The prompt a model was handed named no outcome at all — on
purpose, so that nothing scripted a story before there was a layer to hold one.
Section 10 asks for something the single line could not be: **several goals at
once, over two horizons, each completable, replaceable and reprioritisable**, and
each shaping what the character chooses.

This step is that, plus the rule that keeps it from becoming a quest system:
**the model chooses, and the world says whether a goal is met.**

```
./run_goal.sh               # does a goal change what is chosen? four arms
./run_agent.sh              # the shipped run, now with three goals on one sheet
./run_goal_suite.sh         # just this step's suite (130 checks)
OPENROUTER_API_KEY=... ./run_record.sh --live    # re-make all three recordings
```

| file | what it is |
|---|---|
| `sim/goal.gd` | one goal: horizon, kind, parameters, priority, how it closed |
| `sim/goal_set.gd` | several at once: add, close, replace, reprioritise |
| `sim/goal_check.gd` | the world's answer, kind by kind, out of the engine's own state |
| `sim/scripted_goal.gd` | the four-armed run that measures what a goal changes |
| `tests/test_goals.gd` | the suite, including the source scan below |
| `sim/character.gd` | `- var goal: String`, `+ var goals: GoalSet` |
| `sim/model_prompt.gd` | `+` the goals block, `+` a third tool, `done` |
| `sim/model_mind.gd` | `+` settle the goals before every question, `+` carry `done` out |
| `sim/action_scene.gd` | `+ var trades`, the world's own record of a trade honoured |
| `sim/action_engine.gd` | `+ scene.note_trade(...)` on the one path a trade goes through |
| `net/model_recording.gd` | `+ GOAL_ROWS`, recorded in the same pass as the other two |

## The one goal string is retired, not carried forward

`Character.goal` is gone and `Character.goals` is a `GoalSet`. It was retired
rather than kept beside the new field for the reason the action list is one table
with two columns instead of two lists: two places saying what a character wants
drift, and there is no third thing that could tell you which one was current.

Nothing expressive was lost. A goal still carries the character's own words for
itself, so a sentence somebody would have written into the old field goes into a
goal instead — and now something reads it. A sheet nobody has set a goal for
holds an empty set, prints `goals: -` on its identity line, and is written into a
prompt that says *"What you are after: nothing in particular."* A character a
person drives is therefore exactly the sheet it was before this step.

## A goal is a wanted state, never a route

Eight kinds, and every one of them names something the world could be *like*, not
something to do:

| kind | wanted state | who answers it |
|---|---|---|
| `be_at` | at a position, or beside a character or thing | the world |
| `hold` | carrying a named thing | the world |
| `money` | carrying at least so much money | the world |
| `traded` | a trade with somebody has been honoured | the world |
| `apart_from` | so far clear of somebody | the world |
| `felled` | somebody is out of the world | the world |
| `standing` | at least so much diplomatic standing | the world |
| `unwritten` | the character's own words for something else | the character |

No kind names a route, an order of steps, or a verb out of `ActionCatalog`. The
suite checks that literally: every line of a written goals block is searched for
each of the twelve action names as a whole word, and a hit fails the suite. A
goal that named an action would be an instruction, and what to do about a goal is
the character's own answer.

Several sit on one sheet at once, sorted by how pressing they are. Closing keeps
the goal in the set with how and when it closed — what a character has already
done is worth as much to the next decision as what it has not. Replacing keeps
the old goal's number and its place in the order and drops the old goal rather
than recording it as finished, because a goal given up on was never met.

## The world answers, and where it cannot it says so

Seven of the eight kinds name something the engine holds, and `GoalCheck` reads
the answer off the scene before every question the character is put. Nobody is
asked. Where a comparison needs a number it is either the goal's own (`amount`,
`span`) or the engine's own (`ActionEngine.ARRIVE`, `ActionEngine.REACH`) — there
is no third threshold invented anywhere in the file.

One kind is different, and it is stated rather than hidden. `unwritten` is the
character's own words for something the engine holds no state for: *"be thought
well of in this market"*. There is no field in the simulation that is being
thought well of, and calling it a sentiment number that does not exist yet, or a
distance from a spawn point, would be the check making up its own answer. So the
world does not answer it, the prompt says so beside it, and the character closes
it with the one tool the prompt offers for that — `done goal=N`.

**The boundary is enforced, not documented.** `done` on a goal the world answers
is refused with the world named as the reason, and the refusal is recorded and
printed. Both hands are tried in the run itself:

```
both hands, tried -- the `done` line below is written down by this run, not said by
  the model, which was offered the tool in all four arms above and did not use it
  no  what it is after                               answered by              what `done` did
  1   be carrying 900 money or more                  the world                refused: the world answers this one
  2   be thought well of in this market              the character itself     closed: the character said so
```

`traded` needed one small thing from the engine: `ActionScene.trades`, written by
`ActionEngine` on the one path a trade goes through. A denied offer writes
nothing, which the suite checks both ways round — the world records the trades it
honoured, not the ones it was asked for.

## A goal measurably changes what is chosen

`./run_goal.sh` is the lesson comparison's twin. One character, one moment, the
same question put four times, with everything held still except what the
character is after. The world is staged from scratch per arm from one seed and
stepped 100 ticks with the character choosing nothing, so:

* every arm's observation has the same fingerprint — `9a14b32a0f3eefc1` — so it
  is the same *situation* and not merely a similar one;
* every arm remembers the same six things, and no arm keeps a lesson;
* every arm's prompt is identical outside its `What you are after` block, checked
  by stripping that block out of all four and comparing what is left.

So a difference in what comes back is a difference the goal made:

| arm | what it is after | the model chose |
|---|---|---|
| no goal | — | `recall about=bargain` — a tool, so *— nothing readable —* |
| the empty stall | be at (-471.0, 416.0) | `go_to(target=(-471.000, 416.000))` |
| a trade with Rook | have traded with #2 | `trade_propose(target=2 want_money=9)` |
| thought well of here | be thought well of in this market | `say(text=a fair bargain indeed, friend Wren target=1)` |

All three changed **which action** was chosen and all three changed the choice.
The position arm is worth pausing on: the character stood at `(-476.0, 422.0)`,
was after `(-471.0, 416.0)` — `7.8` away, as the world told it — and answered by
naming that exact position. The trade arm proposed to the one character its goal
named. The arm with no goal at all reached for a *tool* rather than an action —
`recall`, a look back through its own memory — which the comparison reports as
nothing readable, because a tool is not an action and there is no action there to
compare against.

The full transcript is `reports/goal-evidence.txt`.

## And in the shipped run, unprompted

`./run_agent.sh` gives Pell three goals as scenario setup — beside the other
trader, carrying the brass lantern, thought well of here — and then leaves it
alone. What happened is the model's own:

```
turn 1   go_to target=#2         go_to ok at=(-477.423, 417.731) walked=4.5 steps=5
t= 10    be beside #2            closed by the world: #2 is 1.8 away
```

The first thing it did was walk to the character its most pressing goal named,
and the world closed that goal out of its own state ten ticks in, while the walk
was still running — no step towards it was written down anywhere, and Pell was
never asked whether it had arrived.

The second goal it pursued for the rest of the run and did not get. It asked
after a brass lantern out loud, looked at the market pile the lantern had been in
four separate times, and was still reaching for it when the ground under the
market turned into a tactical board and the engine stopped answering it about
where to walk:

```
t= 45  Pell   finished examine(target=6)
              -> examine ok id=6 name=pile kind=pile shut=false holds=1 money=0 distance=6.652
t= 88  Pell   finished go_to(target=6)
              -> go_to refused: the board decides where a fighter goes
t=112  Pell   finished examine(target=6)
              -> examine refused: there is nothing with id 6
```

Wren picked the lantern up and the pile went out of the world with it.
Nothing in the prompt told Pell that, nothing told it where the lantern went, and
both refusals are the engine's own sentences — the same ones any other caller
gets. The goal is still open at the end of the run and the table says so. The
third, `be thought well of in this market`, is Pell's own to close and Pell never
closed it.

## Nothing hard-codes a story

The machinery holds no goal. `tests/test_goals.gd` reads every file under `sim/`
with comments and string literals stripped and collects the ones that construct a
`Goal`; the answer must be exactly two files, both scenario setup:

```
res://sim/scripted_agent.gd     the shipped run's own character
res://sim/scripted_goal.gd      the controlled comparison's four arms
```

`goal.gd`, `goal_set.gd`, `goal_check.gd`, `model_prompt.gd` and `model_mind.gd`
make none, and the scan is shown to have teeth on a line that would be a story
written into the machinery. There is no quest, no giver, no chain, no reward and
no step: nothing gives a goal, nothing pays for one, no other character knows any
of them exists, and the word "reward" does not appear in a prompt.

The prompt still holds no rule either. The rule-word scan — distance, reach,
cost, damage, possibility and their neighbours — runs over the goals block on its
own and over the whole prompt, and finds nothing in either.

## Determinism, and what did not move

| check | result |
|---|---|
| `./run_goal.sh` twice | identical bytes, and identical to `reports/goal-evidence.txt` |
| `./run_agent.sh` twice | identical bytes, and identical to `reports/agent-evidence.txt` |
| key, network, model in the suite | none: all three runs replay `net/model_recording.gd` |
| world fingerprint (`./run_headless.sh`) | unchanged |
| layer, combat, interface and asset checks | pass |

The recording has been re-made live since this step was written, most recently on
2026-09-04: 77 replies for the shipped run, 4 for the lesson comparison and 4 for
the goal comparison, all from `z-ai/glm-5.3-flash` in one pass. Not one of them
was declined and not one came back empty.
