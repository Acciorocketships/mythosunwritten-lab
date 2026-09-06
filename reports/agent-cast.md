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
| Rook | 19 | 19 | 18 | 11.9 |
| Bram | 12 | 12 | 11 | 7.5 |
| Sable | 12 | 12 | 11 | 7.5 |
| Odo | 9 | 8 | 8 | 5.6 |
| Pell | 19 | 18 | 16 | 11.9 |
| **total** | **71** | **69** | **64** | **44.4** |

The run is 160 ticks, so 71 calls is **0.444 calls a tick**. `ControlLoop` states
the world is stepped at twenty ticks a second, which makes an hour of play 72,000
ticks, so at this rate an hour comes to

> **31,950 model calls an hour for five characters — about 6,390 each.**

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
| Rook | 82 | 19 | 6 | 57 | 3 | 0.16 |
| Bram | 62 | 12 | 15 | 35 | 12 | 1.00 |
| Sable | 62 | 12 | 16 | 34 | 13 | 1.08 |
| Odo | 53 | 9 | 19 | 25 | 19 | 2.11 |
| Pell | 81 | 19 | 6 | 56 | 6 | 0.32 |
| **total** | **340** | **71** | **62** | **207** | **53** | **0.75** |

*Held* is the bias: the mind offered back the action it had already chosen,
because the world says its character has not finished it. *Polled* is a question
already outstanding — the channel was read once and the character went on
standing in the world. **71 of 340 asks cost a call: 20.9%.** The ratio the
milestone asks for is the last column: **53 mid-action re-evaluations against 71
model calls, 0.75, and not one of those re-evaluations was a call.**

## Several answers outstanding at once, and none of them queueing

Each character's mind takes its own ticket from the channel and is polled on its
own tick. A mind with no answer yet returns `null`, which every driver already
reads as "nothing chosen, the character stands there". So concurrency here is not
a mode anything switches into — it is the same thing happening more than once.

The run samples, every tick, who is waiting:

```
ticks with more than one answer outstanding  65 of 160
the most outstanding at once                 5
ticks by how many were outstanding           0:38 1:57 2:45 3:15 4:2 5:3
```

For each of the 69 questions the run prints how many ticks the asking character
stood with nothing committed, how many *other* answers were outstanding across
that same span, and how many ticks each of the other five was serviced for in it.
Every row reads the same way:

```
who    turn asked answered waited alongside  ticks each of the others was serviced for   actions
Sable  11     116      120      4         2  Wren 4 Rook 4 Bram 4 Odo 4 Pell 4                2
Bram   12     137      141      4         4  Wren 4 Rook 4 Sable 4 Odo 4 Pell 4               3
Sable  12     140      144      4         3  Wren 4 Rook 4 Bram 4 Odo 4 Pell 4                1
```

A simulation that blocked would show zeroes in those columns. It shows the span,
every time.

The claim that the answers do not *serialise* is a different one, and it is this
line:

```
the longest span, by how many other answers were outstanding across it
  0:3   1:3   2:4   3:4   4:4
```

A channel that served questions in turn would make one put while five others were
outstanding take about eighteen ticks. The longest span in the whole run is four,
and four is not more common when more are pending than when none are — the
longest span with four others outstanding is four ticks, the same as the longest
with two or three. Sixty-six of the sixty-nine spans took the stated three ticks;
the three that ran to four are a character that was not serviced on the tick its
answer was ready — a commander waiting for its turn on the tactical board — which
is the loop's cadence and not the channel's.

## What the models did with the world, none of it written down

Nobody told Pell to want a brass lantern in particular; it was set out after one,
and it spent the run asking. Wren — the character a person drives — had taken that
lantern out of the market pile and nothing told anybody. So Pell asked the two
characters standing near it, was offered the wrong thing, turned to the one who
really had it, and got no answer at all:

```
said #7 to #2 "Do either of you have a brass lantern to sell or trade? I have 9 coins."
said #2 to #7 "I don't have a brass lantern, Pell, but I do have a silk cloak I'd sell for 9 coins."
said #1 aloud  "a fair bargain"
said #7 to #1 "Wren, do you have a brass lantern to sell? I have 9 coins."
said #7 to #1 "Thank you, Rook. I'll pass on the cloak — I'm set on a brass lantern. Wren, would you sell me one?"
said #7 to #1 "Wren, I'll take your silence as a no. I have 9 coins if you change your mind about a brass lantern."
said #7 to #2 "Farewell, then. I'll seek a brass lantern elsewhere."
```

Reading a silence as a refusal is Pell's own move; nothing in the prompt says
that an unanswered question means no, and nothing in the engine tracks who has
asked what. Rook, meanwhile, took the opening and put the offer through the
engine rather than through speech: `trade_propose target=#7 give=[silk cloak]
want_money=9`, twice, both accepted by the engine as well-formed offers, and Pell
answered with a counter-offer of its own money for the same cloak.

Bram and Sable, two strangers of different bands, introduced themselves, agreed
to travel together, and the board came up under them:

```
said #4 to #3 "Hail, traveler. I am Sable."
said #3 to #4 "Well met, Sable. I am Bram."
said #4 to #3 "Oh, just wandering — looking for a bit of adventure, maybe some coin. Care to travel together?"
said #3 to #4 "A soldier out this way could find plenty of adventure, I'd wager. Traveling together suits me fine — where shall we head?"
said #4 to #3 "East, then — up toward the high ground. Quiet roads seldom stay quiet, and hills hide the best adventures."
said #3 to #4 "Northeast, toward that stranger perhaps — but careful, Sable. Eyes up."
t=116  --     Bram and somebody of another band have met
              snap-in around #3 ... joined=2
```

The board appeared under them because they closed within nine units of each
other, which is the engagement rule and not a decision anybody made — two
characters who had just agreed to travel together were put on a tactical grid by
their distance alone, and neither ever chose to attack. From tick 116 to the end
of the run the board holds them: every `go_to` either of them chooses is refused
with *"the board decides where a fighter goes"*, four times between them, and
what they do instead is turn to face each other.

One of the five used the memory tools without being prompted: Pell called
`recall about=brass lantern` twice, drawing back four and then five things it
already remembered. Nobody wrote a lesson on this draw. Which of the five reaches
for which tool is a fact about the draw and not about the tools — an earlier
recording of this same run had Odo keeping a lesson and Pell recalling seven
times.

## The refusals are the same refusals

Eighteen of the run's seventy-one resolutions were refusals, and they read the
same whichever kind of mind chose them:

```
t=110  Rook   finished examine(target=6) -> examine refused: there is nothing with id 6
t=129  Wren   finished go_to(target=2) -> go_to refused: the board decides where a fighter goes
t=133  Wren   finished trade_propose(target=2 give=[] give_money=12 want=[silk cloak] want_money=0)
              -> trade_propose refused: Rook is out of reach (6.00 > 2.50)
```

The first is a model; the last two are the person. Same sentence shape, same
engine, same call. The suite makes the point directly rather than by inspection:
it builds an observation packet and a prompt for the human-driven character and
for a model-driven one and requires both to carry every row of the one action
list.

(The counts and the lines above are this recording's draw. `net/model_recording.gd`
was remade on 2026-09-06, when three actions were added to the one list and the
prompt the recording is keyed to changed; the passages further up that describe
*what happened* in the shipped run are this page's own older draw and were left as
they were written.)

## No key, no network, two processes, same bytes

```
0bc39073d2b1f2f131053b40aa73cad6670129b57de3fb094ca9660a4acd270d  first run
0bc39073d2b1f2f131053b40aa73cad6670129b57de3fb094ca9660a4acd270d  second run
0bc39073d2b1f2f131053b40aa73cad6670129b57de3fb094ca9660a4acd270d  reports/agent-evidence.txt
```

The 101 replies the run and its four sibling runs replay were put to
**`z-ai/glm-5.3-flash`** over `openrouter.ai` once, on 2026-09-05, by
`./run_record.sh --live` — the only command in the repository that touches the
network, and one no test and no other run script calls. Everything else replays
them. 87 of the 101 answer the three character runs; the rest answer the
difficulty-class run and the orchestrator run.

**Not one of the 101 was declined and not one came back empty.** Every question
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

- All 50 suites pass (196,390 checks); the agent suite alone is 1,112 of them,
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
- **Rook and Pell each cost twice what Odo did** (19 calls against 9) because
  they stood in a market with people to answer and a thing one of them wanted,
  while Odo walked away from everybody. Call volume tracks how eventful a
  character's surroundings are, which is the thing section 12's distance-based
  back-off would exploit — and the first evidence that it would work.
- **The tools are used unevenly.** One of the five used `recall`, twice; the
  other four used neither, and nobody wrote a lesson. The draw before this one
  had a different one of the five keeping a lesson. Whether that is the tool, the
  prompt or the draw is not answered by one run.

The full transcript, all 826 lines of it, is
[reports/agent-evidence.txt](agent-evidence.txt). The one-character run this grew
out of is [reports/agent.md](agent.md).
