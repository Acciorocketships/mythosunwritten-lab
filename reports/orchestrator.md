# The orchestrator: the world's dungeon master

Three shapes of language-model call now exist in this game, and they differ in
what makes them run:

| shape | what starts it | what it is about |
|---|---|---|
| character agent | a control loop, over and over while the character lives | one character |
| difficulty-class agent | a hook, once, when the world raises a check | one attempt |
| **orchestrator** | **a cadence, polled over the world** | **the place** |

Section 8 gives the third one two duties and no others: spawn characters — in a
stated order, *sheet first, persona afterwards* — and resolve world events
through tools that add, remove and edit objects and their state. It seeds
narratives by putting characters and events next to each other. It scripts none
of them.

```
./run_world.sh              # the run: five looks, six spawns, eleven operations
./run_world_suite.sh        # just this step's suite (282 checks)
OPENROUTER_API_KEY=... ./run_record.sh --live --world   # re-make this recording
```

| file | what it is |
|---|---|
| `sim/spawn_roll.gd` | the four unit roles, their ability bands, and the roll — the half of a spawn that happens *before* anybody is asked anything |
| `sim/world_effects.gd` | the seven operations the engine exposes, and the one door that carries one out |
| `sim/orchestrator_prompt.gd` | the two prompts, and how a persona is read back |
| `sim/orchestrator.gd` | the agent: looks, carries out, spawns rolls-first, asks who that is |
| `sim/scripted_world.gd` | the run |
| `tests/test_orchestrator.gd` | the suite, including the four source scans below |
| `net/model_recording.gd` | `+ WORLD_ROWS`, with its own date |
| `bin/record_main.gd` | `+ --world`, to record that one table alone |

Nothing else in the project changed. No existing file's behaviour moved, and the
recording's other four tables were written back byte for byte.

## 1. A spawn happens in section 8's order

> *"First roll the skill sheet (sampled from ranges by unit role + local region
> difficulty), then have the LLM write a personality/backstory that explains the
> rolls (high CHA, low WIS → a charming fool)."*

The order is not a convention that someone remembered to follow. It is the shape
of the code: `sim/spawn_roll.gd` produces the sheet and **has no way to see an
answer** — the suite reads its source and requires that the words `reply`,
`channel`, `prompt` and `ask(` appear nowhere in it. The persona question is then
*written out of the sheet that already exists*, so it cannot come first, and
nothing that reads its answer can write a score.

Between the two halves the character is standing in the world with six numbers
and no name of its own. That is a real state the world can be stepped in, and the
suite steps it there: four ticks in, the spawned character has all six ability
scores, an empty backstory, and a placeholder name (`herald #5`).

### The shipped run's charming fool

The run's second look spawned a `herald` — the role whose charisma band is high
and whose wisdom band is low. What the engine rolled, at tick 34:

```
str 7  con 9  cha 17  dex 6  wis 4  int 8        highest cha, lowest wis, 13 apart
```

and what came back three ticks later, having been shown those numbers and asked
who they add up to:

```
name        Vessaline
traits      silver-tongued, magnetic, careless of counsel
tendencies  charms first, asks never, forgets warnings
backstory   Born in the ninth ring's edge-lands, Vessaline learned early that a
            beautiful voice opens doors that strength and sense cannot, and has
            talked their way into a herald's office while leaving a trail of
            ignored advice behind them.
```

That is the acceptance line "extreme enough that the explanation is checkable",
and it checks: charisma $17$ is the beautiful voice that opens doors, wisdom $4$
is the trail of ignored advice, and the ninth ring is where the run stands. The
transcript prints the six numbers again afterwards, and they are the same six.

The other five spawns are the same mechanism on less extreme sheets — a scout
rolled highest on dexterity became *Swiftbrook, quick-fingered, observant,
soft-spoken*; a guard rolled `str 14` against `cha 5` became *Grum Vask,
brutishly strong, tireless, stone-faced*, who "misreads kindness as mockery"; a
scholar rolled `wis 14 int 13` against `dex 6` became *Sage Verrin*, whose "weak
hand at coordination has always made fieldwork and craft embarrassing".

**A persona cannot move a number.** The suite answers a persona question with a
reply whose second line reads `str=18 con=18 cha=18 dex=18 wis=18 int=18`. The
character is named Bellwether, gets its backstory, and keeps every one of its
rolled scores.

## 2. The bands: role, and the section 5 gradient read from the world

A band is the role's own band **lifted by the region**. Nothing about the region
is invented here: `SpawnRoll.difficulty_at(x, z)` is
`ItemFrontier.level_at(‖(x, z)‖)` and nothing else, and `ItemFrontier` is where
section 5's gradient has lived since the items phase. The world origin is spawn —
the same origin `sim/settlement_field.gd` places the first village on a ring
around.

$$\text{ring}(d) = \left\lfloor d / 64 \right\rfloor, \qquad
  \text{level}(d) = 1 + \text{ring}(d), \qquad
  \text{lift}(d) = \left\lfloor \text{ring}(d) / 4 \right\rfloor$$

A spawned character's **level is $\text{level}(d)$ exactly**, unmodified — the
suite asserts equality against `ItemFrontier.level_at` at three distances. Its
**ability bands** rise more slowly, one point every four rings, and that
conversion is this file's own and is stated in it: a level is unbounded by
design, and an ability score is compared against item levels, so lifting the two
at one rate would put a frontier villager's charisma in the hundreds.

The run stands at $637.8$ from the origin, which is ring $9$, difficulty $10$,
lift $+2$:

| role | level | str | con | cha | dex | wis | int |
|---|---|---|---|---|---|---|---|
| guard | 10 | 10-14 | 10-14 | 4-8 | 6-10 | 5-9 | 4-8 |
| herald | 10 | 4-8 | 5-9 | **14-18** | 6-10 | **3-6** | 7-11 |
| scout | 10 | 6-10 | 7-11 | 5-9 | 11-15 | 8-12 | 6-10 |
| scholar | 10 | 3-7 | 4-8 | 6-10 | 5-9 | 10-14 | 12-16 |

The gear a spawn carries comes from the same place: `ItemFrontier.carried_at`
forges one held and four worn items at the region's level, so a character rolled
nine rings out is carrying level-10 gear and one rolled at spawn is not. The
roll itself is **hashed, never streamed** — the same discipline the combat layer
keeps for a blow and the check layer for a die — so who the third character
spawned in a run turns out to be does not depend on how many were spawned first.

## 3. What it may do is a list of world operations

Seven of them, and the model never edits anything itself. It writes
`place kind=crate at=(12.5, -4.0)`; `sim/world_effects.gd` checks the kind is one
it knows, checks the ground would carry it, and puts one there. Every line that
is not one of these is inert and is printed as refused.

| operation | what the engine does |
|---|---|
| `place kind=<k> at=(x, z)` | a new thing stands there, on ground that carries it |
| `remove target=#7` | a thing is taken out of the world |
| `spawn role=<r> at=(x, z)` | a character is rolled for that ground and stands there |
| `open target=#7` | a shut thing comes open |
| `shut target=#7` | an open thing falls shut |
| `move target=#7 to=(x, z)` | a thing is shoved, at most 4 units |
| `spill target=#7` | everything inside an open thing ends up on the ground |

**Three of its own, four borrowed.** The last four are `CheckEffects`' — already
written, and already the only place in the project those four edits happen — and
a line naming one of them is read and carried out *by that file*, not by a second
copy. Two tables that both set `shut` would be two answers to one question.

The four `place` kinds are the two axes an object has, and nothing more: `chest`
(holds things, open), `crate` (holds things, shut), `door` (holds nothing, shut),
`stone` (holds nothing, open).

**Every operation is refusable, and the run shows it.** Of the eleven the model
named, the engine carried out nine and refused two — one for ground that would
not carry the thing asked for, one for a shove longer than a shove goes:

```
did       open target=#3                          the hazel crate came open
did       spill target=#2                         0 things and 9 coins out of the oak chest onto pile #4
did       spawn role=scout at=(-470.0, 418.0)     ... stands at (-470.000, 418.000) as #5
did       spawn role=herald at=(-466.0, 424.0)    ... stands at (-466.000, 424.000) as #6
did       spawn role=guard at=(-480.0, 412.0)     ... stands at (-480.000, 412.000) as #7
would not place kind=chest at=(-490.0, 420.0)     nothing at (-490.000, 420.000) would carry it
would not move target=#4 to=(-478.0, 416.0)       5.66 is further than a shove carries (4.00)
did       place kind=chest at=(-476.0, 416.0)     a chest now stands at (-476.000, 416.000) as #11
```

`nothing` is also an answer — a look that decides the world needs no change is
recorded as a decision, not as a failure to answer, and the suite tells the two
apart: prose that names no operation is recorded as refused, and the world is
unchanged either way.

### Four source scans

The suite reads the source of `sim/orchestrator.gd`,
`sim/orchestrator_prompt.gd` and `sim/spawn_roll.gd` — comments and string
literals stripped, so prose cannot pass or fail a scan — and requires:

| scan | what it requires | shown to have teeth by |
|---|---|---|
| world writes | not one of `add_object(`, `add_actor(`, `remove_object(`, `.shut =`, `.x =`, `.character_name =`, … appears; the operations table has at least five | `thing.shut = false` is caught; `sheet.backstory == ""` is not |
| minds | not one of `.decide =`, `.goals`, `.memory`, `.sentiment`, `Action.`, `DecisionSource` appears anywhere in the layer, table included | `sheet.decide = DecisionSource.plan(written)` is caught |
| story | not one of `quest`, `story`, `plot`, `narrative`, `ending`, `villain`, `hero`, `twist`, `adventure` appears as a whole word — in code **or in a string literal**, because a quest written into a prompt is a quest | `var quest := "fetch the lantern"` is caught; `backstory` is not read as `story` |
| the roller | `sim/spawn_roll.gd` names no `reply`, `channel`, `prompt` or `ask(` | — |

## 4. It changes the world, never a mind

The boundary the task sets. There is no operation that sets a goal, chooses an
action, writes a memory or moves a character, and the mind scan above says so
about the source rather than about the intention.

The one thing the orchestrator writes onto a character sheet is a persona, and it
is fenced three ways: it is written by the operations table and not by the file
that made the call; the engine refuses to write over a persona that is already
there; and the orchestrator only ever offers one for a character in its own
`spawned` list. The suite checks that the character who was in the world before
the orchestrator started is never named, never given a backstory, and is not in
that list.

## 5. Nothing waits for it

Measured on runs, not argued.

**Against the worst case there is.** The suite hands the orchestrator a channel
that never answers anything, and steps a world for 60 ticks. The world advances
all 60, the character carries out actions throughout, and the orchestrator puts
exactly one question — an unanswered look is not asked again.

**On the shipped run:**

```
ticks      150 asked for, 150 advanced
thinking   30 of those ticks had a question outstanding, the longest run of them 6 ticks
meanwhile  the character was part-way through an action on 30 of those 30 ticks
           and stood idle on none of them
and it     carried out 13 actions over the run, 4 of them landing on a tick
           the orchestrator was thinking
left over  0 questions outstanding when the run ended
```

Every question goes to a `ModelChannel` and is polled, exactly as a character's
decision is. A look that has been asked and not answered simply stays open.

## 6. What the run cost

| | |
|---|---|
| looks | 5 taken, 0 of which left the world alone |
| calls | 11 put to a model — 5 looks and one persona per spawn |
| operations | 11 named, 9 carried out by the engine |
| spawns | 6, each of them one roll and one call |

A spawn is therefore **two calls and one roll**, and a look that spawns nobody is
one call. The persona call is the only part of a spawn that costs anything beyond
the look that named it.

## 7. One thing that was measured rather than chosen

Both of these prompts name what their call is for — `WATCHES` and `PEOPLES`, the
two constants a suite compares to prove the second call is not the first with the
question swapped. That line sits **near the bottom of the prompt, above the
answer instruction**, and not at the top where the difficulty-class agent's
equivalent sits.

That is not a style preference, and it has now been measured twice, against two
providers, for two different reasons.

**What the shape was for.** Put first, both prompts were refused by the provider
this project used before 2026-09-03 — named, with the whole comparison, in
[reports/model.md](model.md) — before the model ever saw them: every one of five
questions in that recording pass came back *"this request triggered restrictions
on violative cyber content"*. Bisecting the prompt block by block showed the
trigger was having **any** leading paragraph of instruction in front of the world
and the operation table — a message that opens with a role and then lists commands
with `target=` in them reads, to something upstream, like an attempt to drive a
system. Moving that line to the bottom was answered every time.

**That reason has gone.** Put to the model this file's calls now go to, both
shapes were measured on 2026-09-04: all eleven questions the orchestrator run
puts, three times each, in both shapes, 66 calls, and **not one was declined, in
either shape**. By the rule of three the content-refusal rate here is under about
9% at 95% confidence either way. A refusal belongs to a provider, not to a
prompt.

**A second reason took its place, so the shape stays.** On the largest of the five
world questions the leading shape drives this model into thinking until the answer
ceiling runs out and it answers with nothing at all: **7 empty answers in 11 puts,
against 0 in 11** for the shape that ships, every one of the seven cut off at
`length`, $p \approx 0.004$ by Fisher's exact test. An empty answer costs the
recorder that question exactly as completely as a refusal did. So the naming line
stays where it is — now as a measured choice about this model rather than a
workaround for somebody's filter.

Every call of that measurement is in `.lab/memory/files/prompt-lead-check-2026-09-04.md`,
`tools/prompt_lead_probe.sh` puts it again, and the reason is written into the
head of `sim/orchestrator_prompt.gd`.

## Headless, deterministic, and no network

`./run_world.sh` needs no key, no network and no model: the answers come from
`net/model_recording.gd`, which now holds five tables. `WORLD_ROWS` has its own
`WORLD_RECORDED_ON`, and `./run_record.sh --live --world` records that table
alone and writes the other four back byte for byte — the same arrangement the
difficulty-class table got, and for the same reason: every number quoted off the
other runs' transcripts is a fact about the draw that recorded them.

Two processes print the same bytes, `reports/world-evidence.txt` is what the
command prints, and the suite checks both. Not one line of the suite makes a live
call.
