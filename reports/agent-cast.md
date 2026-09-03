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
| Rook | 24 | 23 | 23 | 15.0 |
| Bram | 12 | 12 | 10 | 7.5 |
| Sable | 12 | 12 | 10 | 7.5 |
| Odo | 12 | 12 | 10 | 7.5 |
| Pell | 19 | 18 | 18 | 11.9 |
| **total** | **79** | **77** | **71** | **49.4** |

The run is 160 ticks, so 79 calls is **0.494 calls a tick**. `ControlLoop` states
the world is stepped at twenty ticks a second, which makes an hour of play 72,000
ticks, so at this rate an hour comes to

> **35,550 model calls an hour for five characters — about 7,110 each.**

That is the number. It is a count of questions put, not an estimate of latency or
price, and it is the one thing that does not change between a replayed run and a
live one.

Read plainly: five characters cost about two calls a second between them. A cast
of fifty at the same rate would be twenty a second, and *that* is where section
12's back-off starts to matter — not at five. The measurement says the cast run
can be produced without either deferred piece, and it was: the shipped run is
recorded, replayed and byte-identical without them.

## Being asked again is not a new call

Section 2.2 says a character re-evaluates while an action is in progress and is
biased toward continuing. `ControlLoop` puts that at once every five ticks. A
mind that started a new exchange on each of those would call a model four times a
second per character. It does not, and the run prices the difference: every ask
of a mind is exactly one of three things, and the three sum to the asks.

| who | asked | calls | held | polled | re-evaluations | re-evaluations per call |
|---|---|---|---|---|---|---|
| Rook | 95 | 24 | 2 | 69 | 0 | 0.00 |
| Bram | 62 | 12 | 17 | 33 | 13 | 1.08 |
| Sable | 60 | 12 | 16 | 32 | 13 | 1.08 |
| Odo | 63 | 12 | 15 | 36 | 15 | 1.25 |
| Pell | 82 | 19 | 8 | 55 | 6 | 0.32 |
| **total** | **362** | **79** | **58** | **225** | **47** | **0.59** |

*Held* is the bias: the mind offered back the action it had already chosen,
because the world says its character has not finished it. *Polled* is a question
already outstanding — the channel was read once and the character went on
standing in the world. **79 of 362 asks cost a call: 21.8%.** The ratio the
milestone asks for is the last column: **47 mid-action re-evaluations against 79
model calls, 0.59, and not one of those re-evaluations was a call.**

## Several answers outstanding at once, and none of them queueing

Each character's mind takes its own ticket from the channel and is polled on its
own tick. A mind with no answer yet returns `null`, which every driver already
reads as "nothing chosen, the character stands there". So concurrency here is not
a mode anything switches into — it is the same thing happening more than once.

The run samples, every tick, who is waiting:

```
ticks with more than one answer outstanding  77 of 160
the most outstanding at once                 5
ticks by how many were outstanding           0:29 1:54 2:55 3:14 4:5 5:3
```

For each of the 77 questions the run prints how many ticks the asking character
stood with nothing committed, how many *other* answers were outstanding across
that same span, and how many ticks each of the other five was serviced for in it.
Every row reads the same way:

```
who    turn asked answered waited alongside  ticks each of the others was serviced for   actions
Pell   18     152      155      3         2  Wren 3 Rook 3 Bram 3 Sable 3 Odo 3               2
Rook   23     154      157      3         2  Wren 3 Bram 3 Sable 3 Odo 3 Pell 3               1
Odo    12     155      158      3         1  Wren 3 Rook 3 Bram 3 Sable 3 Pell 3              0
```

A simulation that blocked would show zeroes in those columns. It shows the span,
every time.

The claim that the answers do not *serialise* is a different one, and it is this
line:

```
the longest span, by how many other answers were outstanding across it
  0:3   1:3   2:4   3:3   4:4
```

A channel that served questions in turn would make one put while five others were
outstanding take about eighteen ticks. The longest span in the whole run is four,
and four is not more common when more are pending than when none are. The seven
spans that ran to four rather than the stated three are a character that was not
serviced on the tick its answer was ready — a commander waiting for its turn on
the tactical board — which is the loop's cadence and not the channel's.

## What the models did with the world, none of it written down

Nobody told Rook to sell anything. Rook was given a silk cloak in the staging and
found a buyer:

```
t= 58  Rook   finished trade_propose(target=7 give=[silk cloak] want_money=10)
               -> trade_propose refused: Pell has only 9 money
t= 72  Rook   finished trade_propose(target=7 give=[silk cloak] want_money=8)
               -> trade_propose ok to=7 give=1 give_money=0 want=0 want_money=8
```

Ten, refused by the engine in the engine's own words, then eight. Pell had said
what it was after, and Rook — asked nothing, told nothing — passed the question
along to the one character in the market it could not decide for:

```
said #7 to #2 "Ah, a lovely cloak I'm sure, Rook, but today I'm after a brass
              lantern—do you have one, or know who might?"
said #2 to #7 "alas, Pell, no lantern on me—but Wren might know. Wren, have you a
              brass lantern for our friend here?"
said #7 to #1 "Wren, good friend—have you a brass lantern to sell? I've coin
              ready for a fair price."
```

Bram and Sable, two strangers of different bands, introduced themselves, agreed
to go halves on a pile of goods, and then fought about it:

```
said #3 to #4 "A wanderer, eh? ... I spied a pile of goods to the west. Care to
              have a look together, or shall we split whatever's worth claiming?"
said #4 to #3 "A pile of goods, you say? Very well, Bram — lead on west, and
              we'll split what we find fairly. But mark me: fair means fair, and
              my spear settles disputes."
t= 76  --     Bram and somebody of another band have met
              snap-in around #3 ... joined=2
```

The board appeared under them because they walked within nine units of each
other, which is the engagement rule and not a decision anybody made. It snapped
in twice over the run — they broke off and closed again — and the loop counted
three "combat began" interruptions. No line anywhere says these two quarrel.

Three of them also used the memory tools without being prompted: Bram, Sable and
Odo each kept one lesson — *"#4 is a commander named Sable, whom I met near
(-436, 407)"* — and nobody used `recall`, which is a fact about this draw and not
about the tool.

## The refusals are the same refusals

Twenty of the run's eighty-one resolutions were refusals, and they read the same
whichever kind of mind chose them:

```
t= 43  Rook   finished examine(target=6) -> examine refused: there is nothing with id 6
t= 46  Pell   finished examine(target=6) -> examine refused: there is nothing with id 6
t= 77  Wren   finished examine(target=silk cloak) -> examine refused: Wren carries no silk cloak
```

The first two are models; the third is the person. Same sentence shape, same
engine, same call. The suite makes the point directly rather than by inspection:
it builds an observation packet and a prompt for the human-driven character and
for a model-driven one and requires both to carry all twelve rows of the one
action list.

## No key, no network, two processes, same bytes

```
947abdbb5e2d3160c5a49c4cb238eff49870b12e06135063639cee206897bd77  first run
947abdbb5e2d3160c5a49c4cb238eff49870b12e06135063639cee206897bd77  second run
947abdbb5e2d3160c5a49c4cb238eff49870b12e06135063639cee206897bd77  reports/agent-evidence.txt
```

The 94 replies the run replays were put to `anthropic/claude-fable-5` over
`openrouter.ai` once, on 2026-09-02, by `./run_record.sh --live` — the only
command in the repository that touches the network, and one no test and no other
run script calls. Everything else replays them.

Making a recording at this cast's volume needed two changes that a
seventeen-question run never met:

**A declined answer no longer strands a character.** `ModelChannel.reply_to()`
hands back `""` both for "not yet" and for "answered with nothing", and a mind
that could not tell those apart waited forever on a ticket nothing would ever
answer. `ModelChannel.has_answered()` separates them: an empty answer closes the
ticket, is recorded as a turn with the provider's reason on it, and the character
is asked again on its next tick. Measured over four recording passes the provider
declined one or two questions in seventy — the same prompt answered on one pass
and refused on the next, so a flaky classifier and not a judgement. The recorder
now puts each question up to six times before taking silence as the answer, and
writes a surviving silence down as what it was rather than throwing the whole
pass away.

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

- All 41 suites pass (195,308 checks); the agent suite alone is 1,157 of them,
  every one with no key, no network and no model.
- `./run_headless.sh` at seed 1234 still ends at `d178d38879097c1c` — unmoved.
- `./run_tests.sh --layers-only`: layer, combat, interface and asset checks OK.
- Nothing under `sim/` opens a connection, starts a thread, reads the environment
  or reads a clock; the transport, the credential and the recorded prose stay in
  `net/` and reach the simulation as `Callable`s and a dictionary handed in. The
  suite scans every file under `sim/` for both.

## What this run does not settle

- **The cast is five.** Whether the rate holds at fifty or five hundred is not
  measured here, and the linear reading above is an extrapolation, not a result.
- **Rook cost twice what Odo did** (24 calls against 12) because it was in a
  market with people to answer and Odo was walking alone. Call volume tracks how
  eventful a character's surroundings are, which is the thing section 12's
  distance-based back-off would exploit — and the first evidence that it would
  work.
- **Nobody used `recall`.** Three of the five kept a lesson; none looked one up.
  Whether that is the tool, the prompt or the draw is not answered by one run.

The full transcript, all 909 lines of it, is
[reports/agent-evidence.txt](agent-evidence.txt). The one-character run this grew
out of is [reports/agent.md](agent.md).
