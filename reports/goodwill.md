# How goodwill is earned

Section 6 gives two ways a character's sentiment toward another goes up, and
says plainly that one of them is meant to be much harder than the other:

> Raising sentiment: completing quests raises it (amount judged by an LLM from
> the quest's nature). Pure talk can raise it but is deliberately hard — only
> truly novel diplomacy is even considered, so the game can't be cheesed by
> chatting up everyone. Gated by an ability check: CHA + roll vs a DC factoring
> WIS and max(status, level) — [OPEN] exact formula.

Both are built here. The exact formula — section 13's third open question — is
settled, and what the two are worth against each other is **measured** on one
seeded run rather than asserted.

```
./run_goodwill.sh            # the run: two arms, three ceilings, the gate swept
./run_goodwill_suite.sh      # just this step's suite (130 checks)
OPENROUTER_API_KEY=... ./run_record.sh --live --goodwill   # re-make this recording
```

| file | what it is |
|---|---|
| `sim/goodwill.gd` | the amount: what a reply may say, what the engine will move an edge by, and how one becomes the other |
| `sim/goodwill_prompt.gd` | the one question, in its two situations |
| `sim/deed.gd` | what a deed is, and who the world's own records say did it |
| `sim/deed_desk.gd` | the desk that watches for one, asks what it was worth, and writes that down |
| `sim/scripted_goodwill.gd` | the run |
| `tests/test_goodwill.gd` | the suite |
| `sim/ability_check.gd` | `+ TALK_HOOK`, `+ AT_A_PERSON`, `+ class_for_talk(...)`, `+ TALK_FLOOR` |
| `sim/check_desk.gd` | `+` the person branch: no judging call, and a goodwill resolution |
| `sim/action_engine.gd` | `+` the second hook: `_say` raises a check |
| `sim/action_scene.gd` | `+ raise_talk_check(...)`, `+ var favours`, `+ note_favour(...)` — the world's record of goodwill earned |
| `sim/character_upkeep.gd` | `+` the fourth fold |
| `sim/relationship_graph.gd` | `+ favoured(...)` — the fourth writer |
| `sim/goal.gd`, `sim/goal_check.gd` | `+ open_at` — the last tick the world said a goal was unmet |
| `net/model_recording.gd` | `+ GOODWILL_ROWS`, with its own date |
| `bin/record_main.gd` | `+ --goodwill`, to record that one table alone |

## 1. A deed: something somebody wanted, that somebody else brought about

There is no quest system, no quest log, no quest-giver and no reward. What a
character wants is its own `GoalSet` — section 10's structured intent, put there
by whoever set the scene up and by nothing in the machinery. A **deed** is the
name for the case where the world's own records say another character is why one
of those goals is now finished.

Who did it is read back off the engine's own writing, never claimed:

| wanted state | the record read | who did it |
|---|---|---|
| `HOLD` — carrying a named thing | the latest honoured trade in which this character *received things* | the other party |
| `MONEY` — having an amount | the latest honoured trade in which this character *received money* | the other party |
| `TRADED` — having traded | the trade that answers the goal | the other party |
| `FELLED` — somebody no longer standing | the latest blow landed on them | whoever struck it |

The other four kinds the engine answers name nobody, by name and with the reason
printed: `BE_AT` and `APART_FROM` are things a character did by walking,
`STANDING` is what it rose to, and `UNWRITTEN` is the one kind the character
closes itself — crediting anybody for that would let a character hand out
goodwill by saying it was owed.

### The window, which is why an old dealing cannot be credited

A record only counts if it happened **while the goal was still open**. The world
looks at every open goal it can answer every time it services the character
holding it, and now stamps the tick on each one it finds unmet (`Goal.open_at`).
A closed goal therefore carries the last moment the world said *not yet*, and the
record that brought it about has to be at or after that moment.

That is what stops the obvious misreading: a character that bought bread from a
merchant forty ticks ago and then found the cap it wanted lying on the ground was
not given the cap by the merchant. **No constant does this work** — no
"recently", no number of ticks — because the world already knows exactly when it
last said no. The suite plants that case and requires nobody to be credited.

## 2. Talk: the same desk, a class the engine computes

Section 6's second way goes through the difficulty-class desk that already
exists, not through a second checking mechanism. The engine gained a second hook,
`AbilityCheck.TALK_HOOK` in `ActionEngine._say`: a line addressed to **one**
character raises a check on winning that character round. A shout raises none —
it is addressed to nobody in particular — and neither does a line to anything
that keeps no character sheet.

The words are said either way. A persuasion that fails is a line of speech like
any other: heard, written into the world's record, and moving familiarity through
`RelationshipGraph.heard` exactly as before. What the check decides is only what
the words *earn*.

### The formula, and every choice in it

$$\mathrm{DC} = 15 + \mathrm{WIS}(\text{listener})
  + \max\big(\mathrm{status}(\text{listener}), \mathrm{level}(\text{listener})\big)$$

bounded to the engine's usual $[1, 30]$, against $\mathrm{CHA}(\text{speaker})
+ d20$.

* **The listener's wisdom and standing, not the speaker's.** Section 6 gives the
  terms but not whose they are. They belong to the one being talked at: wisdom is
  what sees through a line, and standing — diplomatic or military, whichever is
  greater — is how little this person needs anything from you. Reading them off
  the speaker would make a wise, powerful character *worse* at diplomacy.
* **The greater of status and level, not the sum.** Section 6 wrote `max`, and
  the shape is right: the two are alternative kinds of standing rather than parts
  of one. A warlord of no rank and a herald of no army are each hard to impress,
  and neither is twice as hard as the other. (`OwnershipField.carry` adds them
  instead — there they are being *spent*, and both count.)
* **The floor is 15, chosen against a stated criterion.** A speaker whose charm
  exactly equals the listener's wisdom, against the least standing there is
  (level 1, no assigned status), must succeed on a quarter of the faces of the
  die. That is 16 or better on a d20, so the floor is $16 - 1 = 15$. The suite
  counts the faces rather than believing the sentence.

**No model is asked how hard it is.** For a check at a person the judging call is
skipped entirely: section 6 wrote the class down, so `AbilityCheck.class_for_talk`
answers it and the engine rolls. A persuasion that fails therefore costs **no
model call at all**. The only call it can cost is the resolving one, on a
success, and that call is asked one thing: how much.

### One attempt per person, ever

The triggering context of a check at a person is **the person, and nothing
else** — `persuade:#<id>`. Two attempts to win the same character round are the
same attempt however differently they are worded, so the second is settled out of
the speaker's own memory with no call, no roll, and **no second helping of
goodwill**. That is where "only truly novel diplomacy is even considered" lives:
talking again to somebody you have already talked round, or already failed to
talk round, is not novel — and the words are not read to decide that, because a
rule that read the words would be a rule about what a character may say.

The same shape cannot be in flight twice either. A model answers three ticks
later; without that branch a character that spoke again inside the window would
find nothing in its memory yet and be rolled a second time. The suite has that
case, and it fails without the fix.

## 3. The amount: judged by a model, applied and bounded by the engine

One question, `GoodwillPrompt`, in two situations — a deed, and a persuasion the
engine has already rolled a success for. It describes what happened and asks for
one number from 0 to 1. Three answers are possible and only three:

| the reply | what happens |
|---|---|
| no `goodwill=` number in it | refused; nothing changes, and the transcript says so |
| a number outside $[0, 1]$ | refused; a reply saying seven has not answered the question asked |
| a number inside it | read as a share of `Goodwill.MOST` and applied |

**The two desks never touch the relationship graph.** They write one row into
`ActionScene.favours` — the world's own record of goodwill having been earned —
and stop. `CharacterUpkeep` folds that record into the graph on the path every
character passes, from a mark the graph itself carries, exactly as it folds a
line of speech, a trade and a blow; and `RelationshipGraph.favoured` is what
decides which field moves and at which end. So the path from a reply to an edge
runs through the same place a blow's does, and the standing rule that **no
model-facing file names the graph** survives untouched —
`tests/test_relationships.gd` reads the source of every one of them and now has
`sim/goodwill.gd`, `sim/goodwill_prompt.gd` and `sim/deed_desk.gd` on that list
too.

The bound is checked twice on the way: `ActionScene.note_favour` refuses a share
outside what the engine will move an edge by and writes nothing, and
`RelationshipGraph.favoured` refuses it again at fold time. There is no sentence
a model can write that reaches the world any other way: a reply saying the two
are now firm friends moves nothing, which the suite checks.

**Why `MOST` is a half.** It is what one blow costs. `RelationshipGraph`'s
`STRUCK_TRUST` is the share of trust being struck gives up; `MOST` is the share
of the distance left to complete trust that the best imaginable single deed
closes. One good turn is worth one bad one. The suite fails if the two numbers
ever part, so the sentence cannot quietly stop being true.

**Bounding scales rather than clips, and that is not a detail.** The recorded
model answers this question with 0.5, 0.6, 0.6 and 0.7 — every one of which
*clamps* to exactly 0.5. Clamping would have made a deed the model judged half
again as valuable as another move an edge by precisely as much, and the amount
would have been the engine's after all, read off a table with the model's answer
thrown away at the door. Read as a share of `MOST` instead, those four answers
become four different moves — 0.250, 0.300, 0.300 and 0.350 — and still cannot
exceed the ceiling.

## 4. What it comes to, measured

`./run_goodwill.sh` stands one character, Wren, among three neighbours who each
want one thing, and plays the same world twice. In the **talk** arm Wren walks to
each of the three and speaks to them three times — nine lines, chatting up
everybody as thoroughly as the run allows. In the **deeds** arm Wren walks to
each of the three, hands over the thing that character was after, and says
nothing at all. The deeds arm is deliberately the *smaller* run: ten turns
against thirteen.

```
arm        actions  calls    at centre  best       held     best trust owner of the centre
talk       13       1        0.0763     0.1734     404      0.300      #1
deeds      10       3        0.1600     0.1655     491      0.662      #1
talk x3    13       3        0.2891     0.2891     491      0.500      #1
talk x1    7        3        0.1250     0.1250     491      0.500      #1
deeds max  10       3        0.1850     0.1850     491      0.740      #1
```

*(`at centre` is section 6's ownership score for Wren on the ground the four are
standing on; `held` is how many of 961 sampled points Wren owns outright, over a
300 × 300 square; the threshold is 0.0500. The last three rows are ceilings —
see below.)*

**Doing something moved the ground 2.1 times as far as talking, off a third
fewer turns.** Nine conversations bought 0.0763; three gifts bought 0.1600.

Where the difference is, and where it is not:

* **Talking with nothing earned is worth exactly nothing.** Sentiment is
  $\mathrm{familiarity} \times (\mathrm{trust} - \mathrm{fear})$, and familiarity
  *multiplies*. Two of Wren's three neighbours were talked at three times each
  and not won round: familiarity 0.578, trust 0.000, sentiment **0.0000**. They
  do not dilute the claim a little — they contribute nothing to it at all.
* **What one thing earns is trust**, and that is where a deed and a persuasion
  can be put side by side. The one persuasion that landed earned trust 0.300; the
  three deeds earned 0.662, 0.610 and 0.636 on top of what the gift itself was
  already worth under the graph's ordinary rules.

### The gate, swept rather than claimed

The difficulty is a fact about the formula and these four sheets, not about one
seed. So the run sweeps every roll seed from 1 to 200 with **no model call
anywhere in the table** — a persuasion that fails costs none:

| attempts landed | seeds | share |
|---|---|---|
| 0 | 49 | 24.5% |
| 1 | 86 | 43.0% |
| 2 | 49 | 24.5% |
| 3 | 16 | 8.0% |

1.16 of 3 land on average — 38.7% — for a character built for talking (CHA 13)
against ordinary neighbours (WIS 8–10, level 2–3). The seed the run ships is not
chosen by taste: it is the lowest at which **exactly one** of the three lands, so
the transcript shows a success, two failures, and the repeat of both costing
nothing. The suite checks the shipped seed against that rule.

### The ceilings, which have no model in them

A comparison of one draw against another is one draw, so the run also plays each
arm at its ceiling: every roll landing, and every reply answering with the
largest number the question allows. The reply is written down rather than
recorded, because it is a bound and not a model's opinion; everything else goes
through exactly the machinery the shipped arms use.

* **talk ×1 at its ceiling — 0.1250.** Three lines, one each, all landing, at the
  most any one thing may be worth.
* **deeds at its ceiling — 0.1850.** The same three gifts, at the same maximum.

Those two are the honest comparison, because they are the same number of
*happenings*: familiarity moves once per happening whatever the happening was. At
equal happenings, **a gift beats the best persuasion there is** (0.185 against
0.125; trust 0.740 against 0.500).

* **talk ×3 at its ceiling — 0.2891**, which is more than either. This is worth
  stating plainly rather than hiding: nine conversations *can* outweigh three
  gifts. What buys that lead is familiarity and not goodwill — nine happenings
  put familiarity at 0.578 against a single dealing's 0.250 — and it costs three
  times the turns and requires winning all three rolls, which happens on 8% of
  roll seeds. The gate is not what is being beaten there; the familiarity rule
  from the previous step is.

## 5. Headless, deterministic, and with no model in the shipped run

`./run_goodwill.sh` replays `net/model_recording.gd`'s `GOODWILL_ROWS` — four
replies recorded once from a real model — so it needs no key, no network and no
model, and two processes print the same bytes. The suite runs the command as a
child process and requires its output to equal `reports/goodwill-evidence.txt`
byte for byte.

The world fingerprints at the end of the two arms:

| arm | fingerprint |
|---|---|
| talk | `9ef744906319fab0` |
| deeds | `1be825305c6e19fd` |

## What is deliberately absent

* **No quest system, no quest log, no quest-giver object.** The word does not
  appear in the machinery. The three neighbours' goals are scenario setup, in the
  run file, and `tests/test_goals.gd` still requires that the only files under
  `sim/` that construct a `Goal` are the three scripted scenarios.
* **No sentiment diffusion.** Section 6's `[REACH]` term is not built.
* **No new writer on the relationship graph reachable from a prompt.** The
  desks write a record; the shared servicing path folds it; the graph decides
  what it means. `tests/test_relationships.gd`'s scan for a file that moves an
  edge itself now covers `.favoured(` as well as the other three, and still finds
  only `sim/character_upkeep.gd`.
* **No second rolling site.** The die is still drawn in exactly one function,
  `AbilityCheck.rolled`, and the comparison made in exactly one,
  `AbilityCheck.beats`. `tests/test_checks.gd`'s source scans still pass, and
  `tests/test_goodwill.gd` adds the same two scans over the four new files, both
  shown to have teeth.
* **No rule in either prompt.** Neither question says that words are worth less
  than deeds, that goodwill should be rare, or anything else about how the answer
  should come out. All of the rarity is in the engine: one attempt per person,
  against a class the engine computes, with a die the engine rolls. The suite
  scans both prompts for a list of words that would be such a rule, and plants
  one to show the scan would notice.
