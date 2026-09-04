# Every non-player character deciding through a model, all at once

`./run_agent.sh` plays one seeded run of six characters. Five of them decide
through a language model. The sixth is driven by a person's choices, written down
in advance, because a headless run has no screen — and it is there so the run
carries its own comparison.

Nothing in the run is scripted any more except where people stand. The version
before this one had one model character and four written rules: Rook minded a
stall, Bram and Sable quarrelled from tick 55, Odo walked away. Those rules are
gone. What is left written down is the staging — who is in the scene, where, and
carrying what — and everything that happens after tick 0 is what five models
chose when they were shown the world.

```
Wren   #1 driven by a person   level=2  [str 5 con 4 cha 3 dex 4 wis 3 int 2]
Rook   #2 driven by a model    level=2
Bram   #3 driven by a model    level=3
Sable  #4 driven by a model    level=3
Odo    #5 driven by a model    level=1
Pell   #7 driven by a model    level=2
```

Six rows of one shape, differing in one column. There is no field on `Character`
naming that column, nothing in the observation reporting it, and nothing in the
engine branching on it. The file that hands the decision functions out is the
only place in the project that knows.

---

## What the run cost, which is the number this step exists for

The vision defers two pieces of engineering to section 12 — a back-off that asks
less often for characters far from any person, and a speculative next action
computed while the current one runs. Neither is built here. What decides whether
either is ever needed is how many calls a run of this shape actually makes, so
the run counts them and prints them.

| who | model calls | answers read | actions resolved | calls per 100 ticks |
|---|---|---|---|---|
| Rook | 14 | 14 | 13 | 8.8 |
| Bram | 9 | 9 | 8 | 5.6 |
| Sable | 12 | 12 | 11 | 7.5 |
| Odo | 12 | 12 | 10 | 7.5 |
| Pell | 23 | 22 | 15 | 14.4 |
| **total** | **70** | **69** | **57** | **43.8** |

The run is 160 ticks, so 70 calls is **0.438 calls a tick**. `ControlLoop` states
the world is stepped at twenty ticks a second, which makes an hour of play 72,000
ticks, so at this rate an hour comes to

> **31,500 model calls an hour for five characters — about 6,300 each.**

That is the number. It is a count of questions put, not an estimate of latency or
price, and it is the one thing that does not change between a replayed run and a
live one.

Read plainly: five characters cost about nine calls a second between them at the
world's stated tick rate. A cast of fifty at the same rate would be ninety a
second, and *that* is where section 12's back-off starts to matter — not at five.
The measurement says the cast run can be produced without either deferred piece,
and it was: the shipped run is recorded, replayed and byte-identical without
them.

## Being asked again is not a new call

Section 2.2 says a character re-evaluates while an action is in progress and is
biased toward continuing. `ControlLoop` puts that at once every five ticks. A
mind that started a new exchange on each of those would call a model four times a
second per character. It does not, and the run prices the difference: every ask
of a mind is exactly one of three things, and the three sum to the asks.

| who | asked | calls | held | polled | re-evaluations | re-evaluations per call |
|---|---|---|---|---|---|---|
| Rook | 68 | 14 | 12 | 42 | 8 | 0.57 |
| Bram | 52 | 9 | 20 | 23 | 16 | 1.78 |
| Sable | 63 | 12 | 17 | 34 | 13 | 1.08 |
| Odo | 63 | 12 | 15 | 36 | 15 | 1.25 |
| Pell | 97 | 23 | 7 | 67 | 3 | 0.13 |
| **total** | **343** | **70** | **71** | **202** | **55** | **0.79** |

*Held* is the bias: the mind offered back the action it had already chosen,
because the world says its character has not finished it. *Polled* is a question
already outstanding — the channel was read once and the character went on
standing in the world. **70 of 343 asks cost a call: 20.4%.** The ratio the
milestone asks for is the last column: **55 mid-action re-evaluations against 70
model calls, 0.79, and not one of those re-evaluations was a call.**

## Several answers outstanding at once, and none of them queueing

Each character's mind takes its own ticket from the channel and is polled on its
own tick. A mind with no answer yet returns `null`, which every driver already
reads as "nothing chosen, the character stands there". So concurrency here is not
a mode anything switches into — it is the same thing happening more than once.

The run samples, every tick, who is waiting:

```
ticks with more than one answer outstanding  61 of 160
the most outstanding at once                 5
ticks by how many were outstanding           0:40 1:59 2:37 3:18 4:3 5:3
```

For each of the 69 questions the run prints how many ticks the asking character
stood with nothing committed, how many *other* answers were outstanding across
that same span, and how many ticks each of the other five was serviced for in it.
Every row reads the same way:

```
who    turn asked answered waited alongside  ticks each of the others was serviced for   actions
Sable  12     134      138      4         2  Wren 4 Rook 4 Bram 4 Odo 4 Pell 4                1
Odo    11     145      148      3         2  Wren 3 Rook 3 Bram 3 Sable 3 Pell 3              1
Pell   22     151      154      3         1  Wren 3 Rook 3 Bram 3 Sable 3 Odo 3               1
```

A simulation that blocked would show zeroes in those columns. It shows the span,
every time.

The claim that the answers do not *serialise* is a different one, and it is this
line:

```
the longest span, by how many other answers were outstanding across it
  0:3   1:3   2:4   3:4   4:3
```

A channel that served questions in turn would make one put while five others were
outstanding take about eighteen ticks. The longest span in the whole run is four,
and four is not more common when more are pending than when none are — the
longest span with four others outstanding is three ticks, shorter than the
longest with two. Sixty-four of the sixty-nine spans took the stated three ticks;
the five that ran to four are a character that was not serviced on the tick its
answer was ready — a commander waiting for its turn on the tactical board — which
is the loop's cadence and not the channel's.

## What the models did with the world, none of it written down

Nobody told Pell to want a brass lantern in particular; it was set out after one,
and it spent the run asking. Wren — the character a person drives — had taken that
lantern out of the market pile at tick 29 and nothing told anybody. So Pell asked
the character standing beside it, and Rook, asked nothing and told nothing, ran
out of patience over ninety ticks:

```
said #7 to #2 "where can I find a brass lantern"
said #2 to #7 "I don't know where to find a brass lantern, sorry"
said #7 to #2 "where can I find a brass lantern, Rook"
said #2 to #7 "I already told you, Pell — I don't know where to find one"
said #2 to #7 "Pell, asking again won't change my answer — try the pile I saw nearby, maybe"
said #2 to #7 "Pell, I've answered you three times now — leave me be"
said #2 to #7 "Enough, Pell — go ask Wren if you like"
said #2 to #7 "I already pointed you at the pile I saw nearby — and leave me be after this, Pell"
said #2 to #7 "That's the last you'll hear from me, Pell — good luck at the market."
said #7 to #2 "Thank you, Rook. I'll head to the market then."
```

Rook's count of how many times it had answered is Rook's own; nothing in the
prompt tallies it, and nothing in the engine tracks who has asked what. Pell did
take the advice — it turned to Wren, who really did have the lantern, and twice
offered coin for it from `4.38` units away, which the engine refused because a
trade is proposed within `2.50`.

Bram and Sable, two strangers of different bands, introduced themselves, agreed
to walk north together, and the board came up under them:

```
said #4 to #3 "Hail, fellow commander."
said #3 to #4 "Well met, Sable. Just wandering these lands."
said #4 to #3 "The road ahead looks quiet. Care to walk together a while?"
said #3 to #4 "A walk sounds fine. Lead the way."
said #4 to #3 "Quiet lands make for easy travel. Shall we wander north together, then?"
said #3 to #4 "Lead on, Sable. I'll keep pace."
t= 88  --     Bram and somebody of another band have met
              snap-in around #3 ... joined=2
```

The board appeared under them because they closed within nine units of each
other, which is the engagement rule and not a decision anybody made — two
characters who had just agreed to travel together were put on a tactical grid by
their distance alone, and neither ever chose to attack. From tick 88 to the end
of the run the board holds them: every `go_to` either of them chooses is refused
with *"the board decides where a fighter goes"*, four times between them, and
what they do instead is turn to face each other and, once, speak.

Two of them used the memory tools without being prompted, and in opposite
directions: Odo kept one lesson — `learn text=Keep heading north across the
rising slope.` — and Pell called `recall` seven times, six of them for the
lantern, drawing back up to ten things it already remembered. Which of the five
reaches for which tool is a fact about this draw and not about the tools.

## The refusals are the same refusals

Thirteen of the run's sixty-seven resolutions were refusals, and they read the
same whichever kind of mind chose them:

```
t= 31  Pell   finished examine(target=6) -> examine refused: there is nothing with id 6
t= 61  Rook   finished examine(target=6) -> examine refused: there is nothing with id 6
t= 77  Wren   finished examine(target=silk cloak) -> examine refused: Wren carries no silk cloak
```

The first two are models; the third is the person. Same sentence shape, same
engine, same call. The suite makes the point directly rather than by inspection:
it builds an observation packet and a prompt for the human-driven character and
for a model-driven one and requires both to carry all twelve rows of the one
action list.

## No key, no network, two processes, same bytes

```
90523142039bef5b61d46bce681ddbe297a0de92a116883b4b80198e8cc2f5aa  first run
90523142039bef5b61d46bce681ddbe297a0de92a116883b4b80198e8cc2f5aa  second run
90523142039bef5b61d46bce681ddbe297a0de92a116883b4b80198e8cc2f5aa  reports/agent-evidence.txt
```

The 99 replies the run and its four sibling runs replay were put to
**`z-ai/glm-5.3-flash`** over `openrouter.ai` once, on 2026-09-04, by
`./run_record.sh --live` — the only command in the repository that touches the
network, and one no test and no other run script calls. Everything else replays
them. 85 of the 99 answer the three character runs; the rest answer the
difficulty-class run and the orchestrator run.

**Not one of the 99 was declined and not one came back empty.** Every question
that pass put came back with something a reader could take a line from, so
nothing in the shipped transcript is a silence. That is a fact about this
provider and this draw, and the machinery for a silence stays because the
previous provider needed it: it declined nine of its own pass's questions under
its content policy.

Making a recording at this cast's volume needed two changes that a
seventeen-question run never met:

**A declined answer no longer strands a character.** `ModelChannel.reply_to()`
hands back `""` both for "not yet" and for "answered with nothing", and a mind
that could not tell those apart waited forever on a ticket nothing would ever
answer. `ModelChannel.has_answered()` separates them: an empty answer closes the
ticket, is recorded as a turn with the provider's reason on it, and the character
is asked again on its next tick. The recorder puts each question up to six times
before taking silence as the answer, and writes a surviving silence down as what
it was rather than throwing the whole pass away. On the pass that ships neither
path fired; on the pass before it, against a different provider, both did.

**Recorded replies are matched by prompt fingerprint, not by position.** A
recording is written in the order its answers *arrive*, and a character in a
fight is not serviced every tick, so its answer can be picked up several ticks
after it was ready and land in the table behind an answer to a later question.
Reading rows by position alone then hands one character's reply to another from
that point on — which is exactly what happened, once, at the end of the first
clean recording. Every row already carries the prompt's fingerprint, so the
replay now takes the earliest unspent row recorded for this very prompt, falling
back to position when none matches and saying so in the transcript.

## What holds

- All 49 suites pass (196,324 checks); the agent suite alone is 1,101 of them,
  every one with no key, no network and no model.
- `./run_headless.sh` at seed 1234 still ends at `5014980a58150055` — unmoved.
- `./run_tests.sh --layers-only`: layer, combat, interface and asset checks OK.
- Nothing under `sim/` opens a connection, starts a thread, reads the environment
  or reads a clock; the transport, the credential and the recorded prose stay in
  `net/` and reach the simulation as `Callable`s and a dictionary handed in. The
  suite scans every file under `sim/` for both.

## What this run does not settle

- **The cast is five.** Whether the rate holds at fifty or five hundred is not
  measured here, and the linear reading above is an extrapolation, not a result.
- **Pell cost two and a half times what Bram did** (23 calls against 9) because
  it stood in a market with people to answer and a thing it wanted, while Bram
  walked north and then stood on a board. Call volume tracks how eventful a
  character's surroundings are, which is the thing section 12's distance-based
  back-off would exploit — and the first evidence that it would work.
- **The tools are used unevenly.** One of the five kept a lesson and one used
  `recall`, seven times; the other three used neither. Whether that is the tool,
  the prompt or the draw is not answered by one run.

The full transcript, all 886 lines of it, is
[reports/agent-evidence.txt](agent-evidence.txt). The one-character run this grew
out of is [reports/agent.md](agent.md).
