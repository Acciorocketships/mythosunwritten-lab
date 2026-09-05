# What an ask that costs the world no time costs

Twelve of the thirteen things a mind may answer with are actions, and every one
of them costs the character a span of ticks — the `occupies` column of
`ActionCatalog.ROWS`, spent standing in the world before anything happens. The
other three are the tools `ModelPrompt` offers beside the menu — `recall`,
`learn`, `done` — and they cost **nothing**. They touch what the character
remembers and what it is after, they answer on the tick they are asked, and the
world afterwards is exactly the world before.

That is a hole, and a cheap local model walked straight into it. This step
reproduces the walk, prices the tools, and measures the same run again.

```
./run_asks.sh                   # a person, a program and a model at one door
./run_budget_suite.sh           # just this step's suite (58 checks)
./run_agent.sh                  # the shipped run, unchanged and still replaying
```

| file | what it is |
|---|---|
| `sim/tool_budget.gd` | the rule: how many are free, what the next one costs |
| `sim/action_scene.gd` | `+` the world's ledger: `asks_taken`, `spent_until`, `asks_refused` |
| `sim/control_loop.gd` | `+` a character standing out a charged turn is not asked |
| `sim/model_mind.gd` | `+` ask the world before carrying a tool out |
| `sim/model_prompt.gd` | `+` print the world's refusal when there was one |
| `sim/scripted_asks.gd` | the three-minds run |
| `tests/test_tool_budget.gd` | the suite |

## The loop, reproduced

`./run_agent.sh --live --ticks 3000` on the shipped six-character world, seed
1234, with `LOCAL_MODEL_ENDPOINT` pointed at a loopback `ollama` and
`LOCAL_MODEL=qwen2.5:3b-instruct` — the same arms the local comparison uses.

| | before the guard |
|---|---|
| turns | 6,158 |
| model calls | 6,160 over 3,000 ticks — **2.053 a tick** |
| of those turns, the `recall` tool | **5,417 (88.0%)** |
| characters that resolved no action at all | **4 of 5** |

Rook, Bram, Sable and Odo took 1,357 turns each, every single one of them a
`recall`, and not one of them resolved an action in three thousand ticks. Only
Pell acted — 730 turns, all of them `pick_up`, 229 resolved. The first four turns
of the run are the whole run:

```
Rook   1        1        2  61c4c589e491b02a  recall about=pell     (a tool, not an action: 1 thing came back)
Bram   1        1        2  e93b8c696aa47b56  recall about:the la…  (a tool, not an action: 0 things came back)
Sable  1        1        2  60b5070aee3adb9b  recall about=lately   (a tool, not an action: 0 things came back)
Odo    1        1        2  0cb1af14149ac60d  recall about=words    (a tool, not an action: 0 things came back)
```

and the last four are the same four lines. Nothing had to go wrong for this to
happen: an ask that costs no world time leaves the character in front of the
world it was in front of before, so the next question is the same question and
the same answer comes back for as long as anybody keeps asking.

## Which guard, and why not the other one

Two shapes were named when the hole was found. **The one built is the budget**:
the world charges for an ask that costs it no time.

> A character may make `ToolBudget.FREE` = **2** asks of that kind between the
> actions it takes. One past that is refused in the world's own words, and that
> one costs it a turn: the world counts the turn — `ActionScene.note_action`, the
> same count a refused action moves — and the character stands `ToolBudget.costs()`
> = **4 ticks** before it may choose again. The free ones come back when it
> takes a turn on an *action*, and not when it pays for a look.

Neither number is invented. **4 ticks** is what `ActionCatalog` already charges
for `examine` — the action that is looking at something — because looking back
through your own memory is the same shape of turn as looking at what is in front
of you, and the world should not charge two prices for a look. **2** is a choice
and is stated as one: enough to look something up and follow it up, which is what
section 10's "optional tool for querying older ones" is for, and few enough that
a mind that only looks cannot outrun the world.

**The other shape — feeding the tool's own result back into what the character
sees, so a repeat is visibly the same answer — was considered and not built, on
the evidence of the run above.** Half of it already exists: `ModelMind` keeps the
lines a `recall` turned up and `ModelPrompt.memory_lines` prints them into the
very next prompt. The looping run is what it looks like when that is not enough.
Three of the four looping characters were shown `looked back for "lately": 0
things` and asked for the same thing again — 1,357 times each. Making an answer
visible relies on the mind reading it; a budget is arithmetic the world does, and
it holds for a mind that reads nothing.

One intermediate version was built and measured and is not what shipped: with the
free asks restored by the *payment* rather than by an action, a mind that only
looks still gets three questions per span, and the call rate fell by only about a
quarter (181 calls a minute to 133 on the same endpoint). The rule that shipped
ties the free asks to acting, which is the thing being asked for.

## It is a rule of the world, checked by running three minds through it

The rule lives in `sim/tool_budget.gd` and the ledger it reads and writes lives
on `ActionScene`. Nothing in either knows what is deciding for the character, and
`ControlLoop._ask` — the one function every path that asks anybody anything goes
through — will not ask a character that is standing out a charged turn.

`./run_asks.sh` is that claim as a run rather than as a reading of the source.
Three characters stand far enough apart that nothing one does can reach another,
and each reaches for the same thing four times before it does anything:

* **Ash** is a person — `DecisionSource.live`, a hand pressing between ticks;
* **Bryn** is a program — `DecisionSource.scripted`, a rule reading the world;
* **Cass** is a language model — `DecisionSource.model`, a `ModelMind`.

```
Ash, a person (#1)
  tick 1  asked, and may: 1 of 2 free
  tick 2  asked, and may: 2 of 2 free
  tick 3  asked, and may not: Ash has already asked 2 things of no world time since it last acted; this one costs it a turn
  tick 4  asked, and may not: Ash is standing out the turn its last ask cost it, until tick 7
  t=  4  Ash    spent a turn on an ask that costs the world no time, and stands until tick 7
  t=  7  Ash    began wait(ticks=1), 1 ticks

the three side by side
  1 sentence over 5 refusals across 3 characters, with the names taken off the front:
    "... has already asked 2 things of no world time since it last acted; this one costs it a turn"
  Ash    charged 1 turn, 4 ticks apiece, and resolved 1 action afterwards
  Bryn   charged 2 turns, 4 ticks apiece, and resolved 1 action afterwards
  Cass   charged 2 turns, 4 ticks apiece, and resolved 1 action afterwards
```

One sentence, one price, and every one of the three asked again and acting when
its span ran out. **A refused ask costs one turn and not the rest of the run**:
Ash's fourth press, made while standing, is refused with the world's other
sentence and charges nothing further — over five such presses in the suite the
turn count and the stand-until both stay where they were.

## The same soak, after the guard

The same command, the same seed, the same endpoint and the same model, with the
guard in:

| | before | after |
|---|---|---|
| turns | 6,158 | **3,009** |
| model calls over 3,000 ticks | 6,160 — 2.053 a tick | **3,010 — 1.003 a tick** |
| turns that were the `recall` tool | 5,417 (88.0%) | **2,281 (75.8%), of which the world refused 2,260** |
| characters that resolved no action | 4 of 5 | **4 of 5** |
| turns the least-served character got | 1,357 (Bram, Sable, Odo, Rook) | **568 (Sable, Odo)** |
| wall clock | 34:59.67 at 92% of one core | **30:51.85 at 91%** |

The action mix, off the two transcripts: before, 5,417 `recall` and 730 `pick_up`
and nothing else; after, 2,281 `recall` — of which **only 21 actually ran**, the
other 2,260 refused by the world — and 728 `pick_up`. The bill halved: **1.003
calls a tick against 2.053**, 72,240 calls an hour for five characters against
147,840, and against a paid endpoint half the money.

**And the honest half of the result: the guard prices the loop, it does not cure
the model.** Rook, Bram, Sable and Odo still resolved no action in three thousand
ticks. What changed is that each of them now pays a turn for every question past
the second, so the world asked them 1,301–1,319 times instead of 3,000, and 99%
of the looking they asked for never happened. A rule of the world can make a
tool cost something; it cannot make a mind choose an action. What is left is not
the tool surface: a character with nothing committed is asked again every tick,
which is `ControlLoop`'s cadence and outside this step.

## Does the run's own per-tick cost grow as turns pile up?

Measured, and the answer is **no**.

* The endpoint's own log says the throughput never decayed: **181 ± 3 calls a
  minute for thirty-two straight minutes** in the before run, while that run's
  turns went from 0 to 6,158, with the model's median latency flat at
  **0.128–0.130 s**. The after run held ~101 a minute the same way. A per-tick
  cost growing with accumulated turns would show as a falling call rate, and
  there is none.
* The engine's own per-tick cost, measured on the same three thousand ticks and
  the same six characters with no live call in them (`./run_agent.sh --ticks
  3000`, replayed): **53.97 s at 99% of one core — 18 ms a tick**, comfortably
  inside the 50 ms the world is stated to be stepped at.

So the thirty-five minutes is a level and not a slope, and two thirds of the
level is not the engine: a live run deliberately sleeps `ScriptedAgent.TICK_MS`
= 50 ms a tick (`bin/agent_main.gd`, `_pacing`), which is 2.5 minutes of the run,
and the rest is what a tick costs **while calls are in flight** — about 0.6 s
against the 18 ms the same tick costs with none. That cost barely moved when the
calls halved (0.65 s a tick at 2.05 calls a tick, 0.57 s at 1.00), so it is
roughly per-tick-with-anything-outstanding rather than per-call, and it lives in
the live transport rather than in the world. **That is a separate fault and it is
reported rather than fixed here.**

## What is not in this step

No tool was added or removed, no action was added or removed, no model was
swapped, and no prompt was rewritten. The prompt gains one line, and only in the
question after a refusal — the same way it has always carried what a `recall`
turned up — so `./run_agent.sh` replays the shipped recording byte for byte and
`reports/agent-evidence.txt` is untouched by this step.
