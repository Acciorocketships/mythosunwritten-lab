# The difficulty-class agent

A character agent **loops**: it is asked what to do next, over and over, for as
long as the character is alive. Section 7 asks for a second shape of
language-model call that does the opposite — **one-off, and triggered by
something happening in the world**. Something is attempted that the rules have
no answer for; a model judges how hard it is; the *engine* rolls; and on a
success a second call, with a different system prompt, says what changed, out of
a list of operations the engine owns.

And then the character remembers it, so the same kind of attempt is never rolled
for twice.

```
./run_check.sh              # the run: four attempts, two rolled, two remembered
./run_check_suite.sh        # just this step's suite (118 checks)
OPENROUTER_API_KEY=... ./run_record.sh --live --checks   # re-make this recording
```

| file | what it is |
|---|---|
| `sim/ability_check.gd` | one check as a record, and the whole of the arithmetic: `bounded`, `rolled`, `beats` |
| `sim/check_prompt.gd` | the two system prompts, and how a judgement is read back |
| `sim/check_effects.gd` | the four operations the engine exposes, and the one door that carries one out |
| `sim/check_desk.gd` | the agent: takes a check up, asks, rolls, resolves, remembers |
| `sim/scripted_check.gd` | the run |
| `tests/test_checks.gd` | the suite, including the three source scans below |
| `sim/action_engine.gd` | `+` the hook: `_interact` raises a check |
| `sim/action_scene.gd` | `+ var raised`, `+ raise_check(...)` — the world's queue |
| `sim/character_memory.gd` | `+ var checks`, `+ settle_check(...)`, `+ check_for(...)` |
| `net/model_recording.gd` | `+ CHECK_ROWS`, with its own date |
| `bin/record_main.gd` | `+ --checks`, to record that one table alone |

## Where a check comes from, and why it is not a poll

**`ActionEngine._interact`.** That is the whole answer, it is written into the
code as `AbilityCheck.HOOK`, and the suite reads every file under `sim/` to
confirm that `raise_check(` appears in exactly one of them.

Section 2.1's `interact` is the generic interaction — the lockpick hook. Before
this step it had three outcomes for a shut thing:

| what the character offers | what the world did, and still does |
|---|---|
| nothing | flat refusal: *"the chest needs a lockpick"* |
| something it is not carrying | flat refusal: *"Rook carries no boots"* |
| **the item it carries that is not the one that opens it** | **a check is raised** |
| the item that opens it | it opens |

Only the third changed. The first two are still refusals, and the fourth still
just works — so nothing that ran before this step raises a check, and every
fingerprint in the repository is what it was.

The third case is the one worth a difficulty class, and the reason is the shape
of the situation rather than a taste for dice: the character has brought a tool
the world has no rule for. That is exactly the gap section 7 exists to fill.

Nothing polls. `CheckDesk.step` over a world nobody is attempting anything in
raises nothing, asks nothing and rolls nothing, however long it is stepped —
which the suite checks over two hundred ticks. A run in which nobody tries
anything unusual makes no call from this layer at all.

## The agent picks two things; the engine does the arithmetic

The judging call is shown the attempt and the character's own sheet, and is
asked for two things and told it is not to decide the outcome:

```
You judge how hard something is. You do not decide whether it works.

Someone in a world has attempted this:

  Rook tries to work the oak chest (#2) with an iron pry bar.

Who is attempting it:
  Rook, level 2.
  ability scores: str 5, con 4, cha 3, dex 4, wis 3, int 2.

Judge how likely you think that is to succeed, and from your judgement give two things:
  a difficulty class -- a whole number from 1 to 30, higher being harder;
  the one ability score it should be tested against, out of: str, con, cha, dex, wis, int.

Answer with one line and nothing else:
  dc=<whole number> ability=<one of the six>
```

It answered `dc=12 ability=str`. Everything after that is the engine's, and all
of it is three functions in `sim/ability_check.gd`:

```
bounded(said)                       -> clampi(said, 1, 30)
rolled(roll_seed, check_id, context)-> 1 + SimRng.hash_ints(...) % 20
beats(score, roll, difficulty)      -> score + roll >= difficulty
```

So the shipped run's first check is `str 5 + roll 15 = 20 vs dc 12`, and it
passes.

The die is **hashed from the check, never drawn out of a stream** — the same
discipline the combat layer keeps for a blow, and enforced across this layer by
the same scan in `tests/test_combat_resolution.gd`. A stream's numbers depend on
how many were drawn before them, and since a check settled out of memory draws
nothing, a streamed die would make whether an attempt succeeded depend on what
the character happened to have tried earlier. The class the model said is kept beside the class the engine used, so a
model that says `dc=9999` is recorded as having said it and bounded to 30 — the
suite checks both numbers.

## A model's words are not a resolution

The suite makes this concrete twice.

**Same reply, different dice, different verdict.** `dc=12 ability=str` run at
twelve roll seeds produces both verdicts and several different rolls. Nothing
about the answer decides the outcome; the die does.

**Prose claiming success changes nothing.** A judging answer of

```
dc=24 ability=str
The bar bites, the lid splinters and the chest flies open, coins everywhere.
```

leaves the chest shut at every seed where `5 + roll < 24`, records no operations
at all, and costs one call rather than two — because the second call is only ever
made on the success branch.

## The second call, and what it is allowed to touch

A different system prompt, and the suite asserts the two opening lines differ,
that the digests differ, that only the resolving one names the operations, and
that **neither prompt mentions the roll** — the judging call is written before
the die is drawn, and the resolving call is told only that the attempt worked.

```
You say what changes in a world after something has already worked.

This happened, and it worked:

  Rook tries to work the oak chest (#2) with an iron pry bar, and succeeded.
  ...
What is within 12 paces of it:
  #2 oak chest, shut
  #3 oak chest, shut
  #4 hazel crate, shut

Say what that success changes. You may name only these operations; anything else changes nothing:
  open   target=#<id>           -- a shut thing comes open
  shut   target=#<id>           -- an open thing falls shut
  move   target=#<id> to=(<x>, <z>) -- a thing is shoved, at most 4.0 units, onto ground that carries it
  spill  target=#<id>           -- everything inside an open thing ends up on the ground beside it

Answer with at most 3 lines, one operation each, and nothing else.
```

It answered `open target=#2`. The model wrote a line; `CheckEffects` found
object 2, checked it was a shut thing in that scene, and set it open. This is
section 8's *scoped* orchestrator: the model names a tool, the engine is the
tool.

Everything about that is bounded and checked:

* a line that is not one of the four — `delete target=#2`, `chest.shut = false`,
  `The chest opens and a trap springs.` — is not read as an operation at all, and
  changes nothing;
* an operation that does not apply is refused and says why: `open` on something
  already open, `spill` on something empty or shut, `move` further than
  `NUDGE = 4.0` or onto ground that would not hold it;
* more than `AT_MOST = 3` operations has the rest refused with that as the
  reason;
* all four are exercised in the suite, and the count is compared against the
  size of the table, so adding a fifth operation without testing it fails.

## The context is stored, and a similar attempt is not rolled again

A check carries a **triggering context**: the shape of the attempt, written as
`interact:<kind of thing>:<what was offered>`. Two attempts are *similar* when
that string is the same. This is a stated definition rather than a judgement —
a second oak chest pried at with the same bar is similar; a hazel crate is not.

When a check settles, `CharacterMemory.settle_check` writes two things through
the same door every other write in that store uses (a function handed an
`Observation`): a row into a new third segment, `checks`, and a first-person line
into the log the character's own prompt already carries.

```
checks     2, one per triggering context
  interact:oak chest:iron pry bar -- str 5 + roll 15 = 20 vs dc 12, passed
  interact:hazel crate:whittling knife -- dex 4 + roll 6 = 10 vs dc 10, passed
and in its own account of itself:
  I worked the oak chest with an iron pry bar: it gave.
  I worked the hazel crate with a whittling knife: it gave.
```

Taking a check up, the desk looks there *first*, before writing any prompt. A
shape already in there is settled from the stored row: no call, no roll, the same
verdict. On a stored success the operations that worked the first time are
carried out again by the engine, with the thing they were about swapped for the
thing in front of the character now — so `open target=#2` becomes
`open target=#3`, and an operation that was about something else is not repeated.

## The run

Four attempts on four shut things, none of which either tool opens.

| # | context | settled by | ability | score | roll | total | dc | verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | `interact:oak chest:iron pry bar` | rolled | str | 5 | 15 | 20 | 12 | passed → `open target=#2` |
| 2 | `interact:oak chest:iron pry bar` | **remembered** | str | 5 | 15 | 20 | 12 | passed → `open target=#3` |
| 3 | `interact:hazel crate:whittling knife` | rolled | dex | 4 | 6 | 10 | 10 | passed → `open target=#4` |
| 4 | `interact:hazel crate:whittling knife` | **remembered** | dex | 4 | 6 | 10 | 10 | passed → `open target=#5` |

**4 checks, 4 model calls, 2 rolls, 2 settled out of memory.** Which is 1.00
calls a settled check against the 1.50 it would have been had every one of them
been judged afresh. Both verdicts are reused whichever way they went: on the draw
this page was first written from the crate check failed at `dc 12` and was
remembered as a failure, so the character did not try its luck at it again; on
this one the same reply came back as `dc=10`, the same roll of 10 cleared it, and
the remembered row carried the success — and its operations — to the second
crate.

The world after: chests #2 and #3 and crates #4 and #5 all open. Fingerprint
`550e14813932bf8c`, printed by the run and identical across processes.

## The model never resolves, read off the source

Three scans over `sim/ability_check.gd`, `sim/check_prompt.gd` and
`sim/check_desk.gd`, with comments and string literals stripped so prose about a
die is not read as one. (`sim/scripted_check.gd` is deliberately outside them: it
is the run that *sets a world out*, so of course it puts objects into a scene.)

| scan | what it requires | teeth shown on |
|---|---|---|
| the die | `hash_ints` / `hash_unit` / `next_int` / `next_u32` / `next_float` / `next_range` / `randi` / `randf` appear on exactly one line in the layer, in `AbilityCheck.rolled`, and no file of the layer holds a stream | `var roll := rng.next_int(1, 20)` and a hashed one |
| the comparison | a difficulty class is compared by magnitude on exactly one line, in `AbilityCheck.beats` | `if check.total >= check.difficulty:` |
| the world | `.shut =`, `.x =`, `.z =`, `add_object(`, `remove_object(`, `contents.release(` appear **nowhere** outside the operations table — and at least three times inside it, so the scan is not passing by finding nothing | `thing.shut = false` |

The clock and socket scan `tests/test_agent.gd` already runs over all of `sim/`
covers these files for free: no `OS`, no `Time`, no `Thread`, no `HTTPClient`.
Everything that touches the network is still in `net/`, reached as a `Callable`.

## Recording one table without disturbing the other three

`net/model_recording.gd` held three tables recorded in one pass. A fourth table
was needed, and a whole re-recording pass would have been the wrong price: **the
provider does not answer the same prompt twice the same way even at temperature
zero**, so every number quoted off the other three runs' transcripts is a fact
about the draw that recorded them and would move for nothing.

So `./run_record.sh --live --checks` puts only this run's questions and writes
the other three tables back byte for byte, keeping their own `RECORDED_ON`. The
difficulty-class table has its own `CHECKS_RECORDED_ON` and its own provenance
line. A pass with no `--checks` still records all four together.

The whole exchange is four rows:

```
{"prompt": "b723d1dc859f2ded", "reply": "dc=12 ability=str", "ms": 1271},
{"prompt": "4b265df7f4e73b4a", "reply": "open target=#2",    "ms": 1194},
{"prompt": "424074711a1ba4fe", "reply": "dc=10 ability=dex", "ms": 1293},
{"prompt": "8b86636a0af3979b", "reply": "open   target=#4",  "ms": 5622},
```

Four rows for four checks — two judgements and the two resolutions they earned.
The two checks settled out of memory are the ones that are *not* in the table,
and the recording is itself the evidence that they were never asked about.

## Open, and out of scope

* **Section 6's diplomacy formula** — charisma plus a roll against a class
  factoring wisdom and the greater of status and level — is *not* settled here.
  This layer lets a model pick the class and the ability, which is section 7's
  rule; section 6's is a fixed formula the engine would compute, over a different
  hook, and it belongs to the territory milestone. Nothing here forecloses it:
  a second hook can raise a check whose class the engine sets rather than asks
  for.
* **The freeform typed player action** (`/<anything>`, class by plausibility) is
  section 7's reach goal and is out of scope. The layer would take it as one more
  hook.
* **"Similar" is one string.** `interact:<thing>:<item>` is a deliberately blunt
  definition. It is exact, cheap and readable, and it is the thing most likely to
  want revisiting: a character who has forced an oak chest arguably knows
  something about forcing a hazel crate.
* **A judgement that cannot be read lapses the check** rather than being asked
  again. One unreadable answer costs the attempt, not the run.
* **The roll seed and the recording are a pair.** A failed check asks one
  question and a passed one asks two, so a seed at which a different attempt
  succeeded would put a question the recording has no reply for. That is the same
  contract the prompts are under — change one, re-record — and it is written into
  `ScriptedCheck.ROLL_SEED`'s own note rather than left to be discovered.
