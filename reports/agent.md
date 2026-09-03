# The first character whose mind is a language model

> **This describes the first step of the model layer, and the run it quotes has
> since been superseded.** `./run_agent.sh` now drives *five* characters through
> models rather than one, and the transcript, the recording and every number
> below were taken from the one-character version. What the current run does, and
> what it costs, is [reports/agent-cast.md](agent-cast.md). Everything this
> report says about the *shape* of the layer — the `net/` split, the prompt, the
> channel, the non-blocking loop — still holds and is where that shape is
> explained.

One non-player character in the shipped seeded run chooses its actions with a
language model. It does so through the same `Callable` on `Character.decide`
that a person's written-down plan and a program's rule already go in, it is
driven by the same control loop, and everything it chooses is resolved by the
same engine. Nothing about the loop changed to make this possible.

    ./run_agent.sh                 # the shipped run: replays a recorded exchange
    ./run_agent.sh --live          # the same questions, put to a real model
    ./run_agent_suite.sh           # just this step's suite
    OPENROUTER_API_KEY=... ./run_record.sh --live    # make the recording

Six new files, and one more factory in a seventh:

| file | what it is |
|---|---|
| `sim/model_prompt.gd` | what a model is asked, and how its answer reads back as one `Action` |
| `sim/model_channel.gd` | where an answer comes from — a recording, or a call put to a transport |
| `sim/model_mind.gd` | one character's mind: observe → prompt → ask → read back |
| `sim/scripted_agent.gd` | the shipped run: six characters, one of them a model |
| `net/model_call.gd` | **outside `sim/`**: the connection, the thread and the clock |
| `net/model_recording.gd` | **outside `sim/`**: the exchange, carried out once and written down |
| `sim/decision_source.gd` | `+ DecisionSource.model()`, four lines, beside `plan` and `scripted` |

## Why there is now a `net/` directory

The simulation already keeps a rule that this step ran straight into:
**nothing under `sim/` reads a clock.** Every duration in the world is a count of
ticks, and `tests/test_control_loop.gd` scans every file under `sim/` for `OS`
and `Time` and fails on either. A language model answers in seconds and over a
socket, so the first version of `sim/model_channel.gd` — which held an
`HTTPClient`, a `Thread` and a millisecond timeout — failed that scan in eleven
places. That was the rule doing its job, not getting in the way.

The connection, the thread, the timeout and the environment variable moved to
`net/model_call.gd`, outside the simulation, and what crosses the line is two
callables and no types:

```
a transport:      func(prompt: String) -> Callable
a call in flight: func() -> Dictionary       # {} while outstanding
```

`ModelChannel` asks a transport and polls the flight; who is doing the waiting,
and on what, is not its business. The transport is handed in from the entry
point, exactly as a decision function is handed to a character, so `sim/` needs
no name out of `net/` and the dependency runs one way — the same shape as
`sim/` and `render/`.

This step adds the other half of the rule as a check of its own:
`tests/test_agent.gd` scans every file under `sim/` for `HTTPClient`,
`TLSOptions`, `StreamPeer*`, `Thread`, `Mutex`, `Semaphore`, `OS`, `Time` and
`Engine`, and finds none. The simulation counts ticks and calls nothing.

**A second standing rule moved the recording out too, and this one was a
surprise.** `tests/test_character_sheet.gd` scans every file under `sim/` for
words that would mean it knows what sort of character it is holding — `player`,
`npc`, `human`, `llm`, `ai` — and reads string literals as code on purpose, so
that a branch cannot hide in one. A table of things a language model *said* is
therefore the last thing that can live under `sim/`. It failed on the endpoint,
`openrouter.ai`, and the next reply mentioning a person would have failed on that.
Both the rule and the failure are right: the recording is data that came off the
wire, so it lives beside the wire in `net/model_recording.gd`, and the
simulation is handed it — `ModelChannel.for_run(exchange, transport)` — rather
than reaching for it. Nothing under `sim/` names it. Two rules, the same shape,
and the same answer: the simulation is given what it needs and fetches nothing.

## Was a live call made? Yes, and the recording was made again from scratch

**A live call was made, and the exchange was re-recorded from scratch when the
observation packet changed.** The packet a mind is handed now carries what the
character heard and a legend for the window of ground, so every prompt of the
run is a different prompt and the old replies are answers to questions nobody
asks any more. `OPENROUTER_API_KEY` was present, the machine could reach the
network, and `./run_record.sh --live` put the run's questions to
**`anthropic/claude-fable-5`** at `https://openrouter.ai/api/v1/chat/completions`
on 2026-09-02. Seventeen questions were asked and sixteen answered before the run
ended; the sixteen are checked in as `ModelRecording.ROWS` verbatim — including
the answer that chose a position the world then refused, which was not edited
out.

The exact command a person with a key would run to redo it:

    OPENROUTER_API_KEY=sk-... ./run_record.sh --live
    ./run_agent.sh > reports/agent-evidence.txt

Three things in `net/` had to be fixed before that command could produce a
usable recording. None of them is new to this task; re-recording is what walked
into them:

* **The token ceiling was under the model's own working.** `MAX_TOKENS` was 96,
  and one answer to this run's prompt was measured at 89 completion tokens for
  the seven tokens of `examine target=#6` — the rest is what the model spends
  before it answers. Against the larger packet it went over, and the replies came
  back cut off mid-line (`go_to` with the target still to come, `say text=Wren,`)
  or with no readable content at all. It is now 512: an answer is still one line,
  but a run that stops paying part-way through a thought is not cheaper, it is
  broken.
* **A reply with nothing to read crashed the reader.** `String(content)` on a
  null content is not a value in GDScript, it is an error, and it took the
  recorder down mid-question. A missing or refused answer is now a stated absence
  — `the model declined: …` or `the model answered with nothing to read (…)` —
  which the recorder already knows how to refuse to write down. It fired once for
  real: of the four recording attempts this took, one was blocked by the
  provider's usage policy, said so, and
  wrote nothing rather than recording a silence.
* **The recorder used to drop functions out of the file it rewrites.** It
  regenerated everything below the marker in `net/model_recording.gd` but never
  wrote `exchange()` back, so the first live recording left a file nothing could
  load. It writes all three functions now.

Nothing else in the repository makes a network call. `./run_tests.sh` does not,
`./run_agent.sh` does not, and `./run_agent.sh` would not even on a machine with
a key: the shipped run takes the recording *unconditionally*, without looking at
the environment, because a run that consulted the environment would print one
thing on one machine and another on another, and the shipped transcript would
stop being a fact about the seed.

## The one difference between the six characters

The run is `ScriptedScenario` — the same seed 1234, the same meadow, the same
market, trade and quarrel — with one more character standing in the market.

```
Wren   #1 driven by a person Wren level=2 status=2 hp=32/32 [str 5 con 4 …]
Rook   #2 driven by a rule   Rook level=2 status=2 hp=32/32 [str 5 con 4 …]
Bram   #3 driven by a rule   Bram level=3 status=3 hp=38/38 [str 5 con 4 …]
Sable  #4 driven by a rule   Sable level=3 status=3 hp=38/38 [str 5 con 4 …]
Odo    #5 driven by a rule   Odo level=1 status=1 hp=26/26 [str 5 con 4 …]
Pell   #7 driven by a model  Pell level=2 status=2 hp=32/32 [str 5 con 4 …]
```

Six `Character` sheets of one class in one `ActionScene`. The "driven by" column
is printed by `sim/scripted_agent.gd`, the file that handed the decision
functions out, and it exists nowhere else — not on the sheet, not in the
observation, not in the engine.

**The check is over the source, not an assertion.** `tests/test_agent.gd` reads
`sim/decision_source.gd` off disk, finds the five factories it declares in
order, and extracts every inner function they return. After making parameter
names that differ only by a leading underscore the same, all five are the one
string:

```
return func(scene: ActionScene, actor: Combatant) -> Action:
```

and each is then called with the same two arguments on the same scene and must
answer with an `Action` or with nothing. Separately, the loop, the engine, the
scene, the action, the catalogue and the character sheet are read off disk with
comments and string literals stripped, and no line of any of them names a model,
a prompt, a channel, a mind, a recording or an observation. The scan is shown to
have teeth on three lines that would name one — `if sheet.decide ==
DecisionSource.model:`, `if mind.is_waiting():`, `var reply :=
channel.reply_to(ticket, tick)` — and shown not to fire on the line the loop
really has, on a comment saying the words, or on `remodelled`.

## The model chooses; it never resolves

The prompt is a menu and a view. The menu is read straight out of
`ActionCatalog.ROWS`, so it cannot become a thirteenth list of the twelve
actions; the view is the observation packet `sim/observation.gd` assembles,
verbatim. There is no rule in it. `ModelPrompt.RULE_WORDS` states that as a
check, and the suite runs it over a real 2,357-character prompt — the legend and
the heard speech included, and the legend scanned again on its own:

| what is searched for | hits |
|---|---|
| distance, reach, cost, damage, possible/impossible, legal/illegal, allowed, forbidden, cannot, succeed, fail, cooldown, radius, range | **0** |
| goal, quest, should, must, try to, your task | **0** |
| the twelve action names | **12 of 12** |

The scan catches `You cannot attack a target outside your weapon's reach.` and
does not fire on `Choose the one thing your character does next.`

**What happens when the model chooses something the world will not allow** is
the point, and the run produced a natural case rather than a staged one. Pell
examined the market pile, walked to it, and asked to examine it again; while that
examine was running Wren took the lantern off it and the empty pile left the
world:

```
t= 34  Wren   finished pick_up(item=brass lantern) -> pick_up ok item=brass lantern from=6
t= 34  Pell   began examine(target=6), 4 ticks
t= 38  Pell   finished examine(target=6) -> examine refused: there is nothing with id 6
```

The second refusal of the run is turn 15's position, and it is the third finding
below.

That refusal is `ActionEngine`'s own sentence, produced by the same call any
other caller makes. The suite pins the identity rather than trusting the
example: the same impossible jump, chosen once by a model and once by a rule for
the same character in the same world, comes back with `ok` equal and `reason`
equal, character for character — the engine's own "further than DEX" sentence,
reached by the same call from both.

## Nobody waits on the model

A `ModelMind` is polled, never waited on. Asked while its answer is outstanding
it returns `null`, which is the same `null` a person out of recorded choices
returns and is read the same way by `ControlLoop._ask`:

```
t=  1  Pell   has not decided yet, and waits in the world
t=  4  Pell   began examine(target=6), 4 ticks
```

The claim is measured off the loop's own counters, not argued. For every one of
the sixteen turns, the transcript prints how long Pell stood there and how many
ticks each other character was serviced for across exactly that span:

| turn | Pell waited | Wren | Rook | Bram | Sable | Odo | actions the others resolved in it |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 3 | 3 | 3 | 0 |
| 2 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| … | | | | | | | |
| 15 | 3 | 3 | 3 | 0 | 3 | 3 | 2 |
| 16 | 3 | 3 | 3 | 0 | 3 | 3 | 1 |

Every other character was serviced for the whole span, every time. The zeroes
under Bram from turn 15 are Bram having lost the quarrel and left the world — a
character that has fallen out of it is serviced no further. The suite asserts
the equality for every character present at both ends of a wait, requires at
least four to be present, and requires that the others resolved actions across
the waits at all, so the measurement is not about a world in which nothing was
happening.

**A live answer takes as long as it takes, and that is the stronger
measurement.** The replay uses a stated `ModelChannel.THINKS_FOR` of 3 ticks, in
exactly the sense `DecisionSource.deliberate` uses a stated number of ticks: a
recording has no latency of its own, and an answer that arrived instantly would
not exercise the thing this layer exists to survive. `./run_agent.sh --live
--ticks 400` was then run against the real model, with a tick given the 50 ms the
world is stated to be stepped at, and the waits are the real ones —
`reports/agent-live-evidence.txt`:

| turn | Pell waited | Wren | Rook | Bram | Sable | Odo | actions the others resolved in it |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 152 | 152 | 152 | 131 | 152 | 152 | 90 |
| 2 | 116 | 116 | 116 | 0 | 116 | 116 | 37 |

A hundred and sixteen to a hundred and fifty-two ticks — six to eight seconds,
longer than before because the packet is longer and the model has more of it to
read — with a real HTTPS call outstanding on a worker thread, and in each of them
every other character was serviced for exactly the same number of ticks and got
37 and 90 actions done between them. Bram's 131 in the first row is Bram losing
the quarrel part-way through the wait, and his 0 in the second is Bram gone. The
second turn is also the live proof of the thing this step added: Pell was handed
two lines it had heard and answered one of them. That file is evidence and is not pinned by any
test: a live call cannot be, because the model's answer is its own each time.

## The exchange, in full

Sixteen turns. `asked` and `answered` are ticks; `observed` is the digest of the
observation packet the model was handed.

| turn | asked | answered | observed | the model said | what the engine answered |
|---:|---:|---:|---|---|---|
| 1 | 1 | 4 | `c37b1498…` | `examine target=#6` | ok, pile, holds 1 |
| 2 | 8 | 11 | `27454396…` | `go_to target=#6` | ok, walked 5.4 |
| 3 | 31 | 34 | `0fe628de…` | `examine target=#6` | **refused: there is nothing with id 6** |
| 4–8 | 38…66 | 41…69 | `1f7e6536…` ×3, `aebf6b4f…`, `ec135210…` | `examine target=#3`, five times | ok, Bram, unhurt, sword |
| 9 | 73 | 76 | `b7d18c0c…` | `say text=Hello, Wren. What news? target=#1` | ok, heard by 1 |
| 10 | 81 | 84 | `811ea882…` | `say text=A fair bargain, you say? What are you offering? target=#1` | ok, heard by 1 |
| 11–12 | 89…95 | 92…98 | `bc2746f8…` ×2 | `wait ticks=3` | ok |
| 13 | 101 | 104 | `bc2746f8…` | `go_to target=#1` | ok, walked 1.8 |
| 14 | 124 | 127 | `0223ca9e…` | `say text=I heard it too—it came from the drop to the south-west. Stay close while we look. target=#1` | ok, heard by 1 |
| 15 | 132 | 135 | `f9d15f9b…` | `go_to target=(-6.0, -6.0)` | **refused: the position is too far to walk to at once** |
| 16 | 155 | 158 | `688c9252…` | `go_to target=(-216.0, 184.7)` | still running when the run ended |

Turn 10 is the whole point of this step in one row. Wren shouted "a fair
bargain" at tick 75; the engine put Pell in that line's `heard_by`; Pell's next
observation carried it; and Pell answered it. Turn 14 is the same thing again
with Wren's "what was that noise?". Neither could have happened before, because
neither line was anywhere in what Pell could see.

Turns 15 and 16 are the other one: **the model chose a position**, which it never
did once in seventeen turns against a window with no key.

The full table is `reports/agent-evidence.txt`, and it carries more than the
digest: under every row is a line saying what was actually in that observation
(`saw: 2 nearby Wren #1 4.0 seen Rook #2 5.8 seen | 2 heard | 0 about | ground
7x7, 2 recent`), and the last section of the file is the run's first question in
full — menu, packet and all 2,357 characters of it — so the transcript is
evidence on its own rather than something reproducible in principle.

## The two behaviours the first run measured, measured again

The first model-driven run of this file found two things and reported them
rather than working around them. Both were about the packet, both are now closed
in it, and the run prints the numbers itself every time rather than leaving them
to be counted off a transcript by hand:

| | the first run | this run |
|---|---:|---:|
| turns | 17 | 16 |
| turns that chose `say` | 11 | 3 |
| different lines among them | 10 | 3 |
| the same line chosen more than once | yes, twice | no |
| turns asked with the observation the turn before was asked with | 10 | 4 |
| turns that chose a position | **0** | **2** |

The first run's numbers are counted from its seventeen checked-in replies under
the same definitions; this run's are the ones `./run_agent.sh` prints under
*what the first run of this file measured, measured again*.

The qualitative change is larger than the counts. In the first run turns 6
through 17 were all greetings aimed at Rook, most of them variations on one
sentence, because saying something changed nothing Pell could observe. In this
run the three lines are a greeting, an answer to a shout Pell heard, and an
answer to a second shout — a conversation rather than a loop.

## What this run found

**1. A character can observe what has been said — closed.** The first run's
repetition came of speech being nowhere in the packet: `scene.said` was not read
and `ObservationTrail` reports movement, health, money and items only, so from
the speaker's side saying something changed nothing observable. The packet now
carries the last six lines the character could hear, and *could hear* is
`ActionEngine._say`'s own answer: the observation filters by the `heard_by` the
engine already writes into `ActionScene.said`, and there is no earshot, no
distance and no second range rule anywhere in `sim/observation.gd`. A character's
own words are in it too, as `you`, which is what lets it know it has already
spoken. One consequence of the engine's rule, unchanged and worth stating: a
line aimed at somebody is heard by that somebody alone, so standing beside two
people talking is still not hearing them.

**2. The ground window says what its marks mean — closed.** The legend is in the
packet, generated from the same table the marks come from, and it is a key to a
picture rather than a rule: it says `~ a hole with nothing to stand on`, never
what may be done about one. The suite runs the prompt's own rule-word scan over
the legend on its own, so a meaning that grew into a rule fails there and names
itself. The measurable consequence is in the table above — the model chose a
position twice, having chosen none in seventeen turns before — and one of those
two was refused by the engine, which is the next finding.

**3. A position in the packet is a world position, and a model may mean an
offset.** Turn 15 chose `go_to target=(-6.0, -6.0)` and the engine answered *the
position is too far to walk to at once*: Pell was standing at (-474, 417), so a
position that reads as "six back and six left" is six hundred units away. The
packet gives the character's own position absolutely and everything else as an
offset, and `go_to` takes a world position — all three are true and consistent,
and nothing in the prompt says which the parameter is, because saying so is a
sentence about what an action means rather than about what can be seen. Turn 16
then chose a world position and walked to it. Reported, not worked around: it is
a question for whoever next changes the action surface or the packet's wording,
and either change is larger than this step.

**4. The action surface was sufficient.** Nothing was added to it, and nothing
needed to be. Every one of the model's sixteen answers named one of the twelve
actions and read back as a well-formed `Action`; `ActionCatalog.fault()` refused
none of them, and the two choices the world refused were refused by the *engine*,
with a sentence, which is the difference this layer is built on. The suite
exercises the other direction too: fourteen written replies, at least one per row
of the one list, each of which must read back as exactly the action it names, so
a row that grew a form nothing could express would fail the check.

**5. What a character was shown and what its action meets are two different
worlds.** Pell's third observation was taken at tick 31 and still showed the
pile with a lantern on it; the answer came back at 34, the examine ran from 34 to
38, and Wren emptied the pile at 34 — so the thing being examined left the world
between the looking and the doing. In the live run the gap is far wider —
observed at tick 1, answered at 98 — and the first turn was refused for the same
reason. Two spans contribute: the one the
answer takes, and the one the action itself takes, and only the first is the
model's. This is not a bug in anything here; it is what an asynchronous decision
*is*, and section 12 already names the answer for it (speculative next action,
re-evaluation on interruption). It is worth writing down because it is easy to
miss at 3 ticks and impossible to miss at ninety. Nothing was changed for it in
this step.

## The recording, and why it is keyed the way it is

`net/model_recording.gd` is generated, not written. `./run_record.sh --live`
plays the shipped run against a channel that replays what has been recorded and
calls the model for what has not — so every question is asked at the tick the
replaying run will ask it at, and the prompts are therefore the same prompts.
That is the one place in the project where the world does wait for a model, and
it is right there because the recorder is not simulating a world; it is
transcribing an exchange.

Each row carries the reply verbatim, how many milliseconds that call took, and
the first sixteen characters of the sha256 of the prompt. The prompt itself is
not kept: it is two thousand characters the code already generates. The digest is
what makes drift *visible* — rows are replayed in order, so a recording still
answers a run whose observations have changed under it, and the transcript says
in that case that the question being answered is not the question that was
recorded. Nothing in the shipped run currently says it, which is the check that
the sixteen prompts still reproduce exactly — and it is exactly the check that
said the old recording had gone stale when the packet grew, which is why the
exchange was re-recorded rather than reused.

The recorder plays twenty ticks past the end of the shipped run. A question put
in the last few ticks is answered — and paid for — after the last tick has gone
by, so it used to be dropped, and the shipped run would then reach a question the
recording had no reply for and stand the character there for the rest of it. The
extra rows are read in order like any other; a row the shipped run never reaches
costs nothing but the call that made it.

## What holds

| claim | how |
|---|---|
| a model-backed decision function is the same `Callable` | source check over `sim/decision_source.gd`: five factories, one inner signature |
| the loop and the engine cannot tell | source scan over six files, shown to have teeth |
| the prompt states no rule | word scan over a real prompt, 0 hits, teeth shown |
| and no outcome the character was not given | a character after nothing has a goals block of one line saying so, and the word "goal" appears once, as a tool's key — see [reports/goals.md](goals.md) |
| an illegal choice is refused with a reason | model and rule get the identical `ok` and `reason`; the run produced a live case |
| the simulation never blocks | tick counts of the other five across every one of 16 waits |
| a character can observe what it heard | the packet's speech is filtered by `ActionEngine._say`'s own `heard_by`, asserted line by line against every character in `tests/test_observation.gd` |
| the window of ground says what its marks mean | the legend is in the packet and in the prompt, generated from `Observation.GLYPHS`/`MEANS`, and the rule-word scan is run over it alone |
| no credential, no network in the suite or the shipped run | `./run_tests.sh` and `./run_agent.sh` replay; only `./run_record.sh --live` calls |
| byte-identical across two processes | `./run_agent.sh` run twice by the suite, compared, and compared with the checked-in transcript |
| no generation rule changed | `./run_headless.sh` final fingerprint `d178d38879097c1c`, unmoved |
| the layer split holds | `bin/check_layers.gd`: all four checks OK |
| nothing under `sim/` opens a connection, starts a thread or reads a clock | scan over every file under `sim/`, teeth shown; the one file that does all three is `net/model_call.gd` |
| the simulation holds no model's words | `tests/test_character_sheet.gd`'s kind-word scan, which the recording failed under `sim/` and passes from `net/` |
| the live path works inside the simulation, not only in the recorder | `reports/agent-live-evidence.txt`: two real calls, 116 and 152 ticks, nobody else stopped |
