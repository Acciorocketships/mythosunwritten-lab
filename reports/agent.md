# The first character whose mind is a language model

> **This describes the first step of the model layer, and the run it was written
> from has since been superseded.** `./run_agent.sh` now drives *five* characters
> through models rather than one, against a different model and a different
> recording. Everything this report says about the *shape* of the layer — the
> `net/` split, the prompt, the channel, the non-blocking loop — still holds and
> is where that shape is explained, and every number and quotation below has been
> re-taken off the run and the recording the tree holds today. Where a figure is
> the first one-character run's, it is labelled as that run's; that recording is
> not in the tree any more and is in git history. What the current run does, and
> what it costs, is [reports/agent-cast.md](agent-cast.md).

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

**A live call was made, and the exchange has been re-recorded from scratch every
time the questions changed.** A prompt change makes every old reply an answer to
a question nobody asks any more, so the recording is not patched, it is re-made.
The recording the tree holds today was made on 2026-09-05: `OPENROUTER_API_KEY`
was present, the machine could reach the network, and `./run_record.sh --live`
put every question of all five runs to **`z-ai/glm-5.3-flash`** at
`https://openrouter.ai/api/v1/chat/completions`. **101 replies came back, not one
of them declined and not one of them empty**, and they are checked in as
`ModelRecording`'s five tables verbatim — including the answers the world then
refused, which were not edited out. Which model answers and why, with the
comparison the choice came out of, is [reports/model.md](model.md).

The one-character exchange this page was first written from was a different
recording from a different provider, and it is not in the tree any more — it is in
git history. Every number below that came off it is marked as the first step's,
and the current run's numbers are in [reports/agent-cast.md](agent-cast.md).

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
  or with no readable content at all. It went to 512 then, and stands at 1200
  now, which is slack rather than a budget: nothing is paid for a token that is
  not produced, and the ceiling has to cover both whatever working the model
  still does and the longest answer any of the five runs asks for — the
  orchestrator's persona block, not a character's one line. An answer is still
  one line, but a run that stops paying part-way through a thought is not
  cheaper, it is broken.
* **A reply with nothing to read crashed the reader.** `String(content)` on a
  null content is not a value in GDScript, it is an error, and it took the
  recorder down mid-question. A missing or refused answer is now a stated absence
  — `the model declined: …` or `the model answered with nothing to read (…)` —
  which the recorder already knows how to refuse to write down. It fired for real
  against the provider this project used then: one of the four recording attempts
  was blocked by that provider's usage policy, said so, and wrote nothing rather
  than recording a silence. It has not fired once against the model that answers
  now — the pass that ships came back with 101 replies and no silence at all —
  which is a fact about the provider and not about the path, so the path stays.
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
market — with one more character standing in it. As this step left it, one of the
six decided through a model and four followed written rules; the run in the tree
today prints the same head with five of the six reading `driven by a model`, and
that is the only column that has moved:

```
Wren   #1 driven by a person Wren level=2 status=2 hp=32/32 [str 5 con 4 …]
Rook   #2 driven by a model  Rook level=2 status=2 hp=32/32 [str 5 con 4 …]
Bram   #3 driven by a model  Bram level=3 status=3 hp=38/38 [str 5 con 4 …]
Sable  #4 driven by a model  Sable level=3 status=3 hp=38/38 [str 5 con 4 …]
Odo    #5 driven by a model  Odo level=1 status=1 hp=26/26 [str 5 con 4 …]
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
check, and the suite runs it over a real prompt — 3,267 characters in the run the
tree holds now, the legend and the heard speech included, and the legend scanned
again on its own:

| what is searched for | hits |
|---|---|
| distance, reach, cost, damage, possible/impossible, legal/illegal, allowed, forbidden, cannot, succeed, fail, cooldown, radius, range | **0** |
| goal, quest, should, must, try to, your task | **0** |
| the twelve action names | **12 of 12** |

The scan catches `You cannot attack a target outside your weapon's reach.` and
does not fire on `Choose the one thing your character does next.`

**What happens when the model chooses something the world will not allow** is
the point, and every run of this shape has produced natural cases rather than
staged ones. In the run the tree holds now, Pell was shown the market pile,
asked to examine it, and while that examine was running Wren took the last thing
off it and the empty pile left the world:

```
t= 27  Pell   began examine(target=6), 4 ticks
t= 29  Wren   finished pick_up(item=brass lantern) -> pick_up ok item=brass lantern from=6
t= 31  Pell   finished examine(target=6) -> examine refused: there is nothing with id 6
```

Thirteen of that run's sixty-seven resolutions are refusals, each in the engine's
own words; four of them are this one, reaching for a pile that has gone.

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
t=  4  Pell   began go_to(target=2), 20 ticks
```

The claim is measured off the loop's own counters, not argued. For every one of
the run's 69 turns, the transcript prints how long the asking character stood
there and how many ticks each other character was serviced for across exactly
that span:

| who | turn | waited | Wren | Rook | Bram | Sable | Odo | Pell | actions the others resolved in it |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Rook | 1 | 3 | 3 | — | 3 | 3 | 3 | 3 | 0 |
| Pell | 2 | 3 | 3 | 3 | 3 | 3 | 3 | — | 1 |
| Sable | 12 | 4 | 4 | 4 | 4 | — | 4 | 4 | 1 |
| Odo | 2 | 3 | 3 | 3 | 3 | 3 | — | 3 | 1 |

Every other character was serviced for the whole span, every time — the run
prints all 69 rows and none of them is short. Nobody falls out of this world, so
there are no zeroes in it; the transcript's own note says a character that has
fallen out of the world is serviced no further and shows 0, which is the shape a
death would take. The suite asserts the equality for every character present at
both ends of a wait, requires at least four to be present, and requires that the
others resolved actions across the waits at all, so the measurement is not about
a world in which nothing was happening.

**A live answer takes as long as it takes, and that is the stronger
measurement.** The replay uses a stated `ModelChannel.THINKS_FOR` of 3 ticks, in
exactly the sense `DecisionSource.deliberate` uses a stated number of ticks: a
recording has no latency of its own, and an answer that arrived instantly would
not exercise the thing this layer exists to survive. `./run_agent.sh --live` was
then run against the real model, with a tick given the 50 ms the world is stated
to be stepped at, and the waits are the real ones — `reports/agent-live-evidence.txt`,
31 calls put and 28 answered inside 160 ticks:

| who | turn | asked | answered | waited | each of the other five was serviced for | actions they resolved in it |
|---|---:|---:|---:|---:|---:|---:|
| Odo | 2 | 16 | 116 | **100** | 100 each | 16 |
| Sable | 3 | 34 | 106 | 72 | 72 each | 8 |
| Bram | 3 | 54 | 105 | 51 | 51 each | 6 |
| Rook | 5 | 68 | 92 | 24 | 24 each | 3 |

Not one of the 28 waits took the replay's stated three ticks; the longest was a
hundred, which at 50 ms a tick is five seconds of a real HTTPS call outstanding on
a worker thread. Across every one of those hundred ticks each of the other five
characters was serviced, and between them they resolved sixteen actions while Odo
stood there waiting. 159 of the 160 ticks had more than one answer outstanding,
five at the most — with real latency everybody is waiting nearly all the time, and
the world does not care. That file is evidence and is not pinned by any test: a
live call cannot be, because the model's answer is its own each time.

## The exchange, in full

The sixteen-turn exchange this section used to tabulate belonged to the
one-character recording, which has since been replaced twice; it is in git
history and not in the tree. What the tree holds is the five-character exchange,
and its table — every turn, what the model said, what it read back as and what
the engine answered — is printed by `./run_agent.sh` and checked in at
`reports/agent-evidence.txt`, with the numbers read out in
[reports/agent-cast.md](agent-cast.md).

The two things that table was quoted here to show both still hold, and both are
in the current transcript:

* **A character answers what it heard.** Pell says *"where can I find a brass
  lantern"* to Rook; the engine puts Rook in that line's `heard_by`; Rook's next
  observation carries it, and Rook answers *"I don't know where to find a brass
  lantern, sorry"*. Twelve more lines follow between the two of them. Neither
  could have happened before speech was in the packet, because neither line was
  anywhere in what the other could see.
* **A model chooses a position.** It did so thirteen times in the current run,
  against none at all in the first one-character run, whose window of ground had
  no legend to say what its marks meant.

The transcript carries more than a table: every row names the digest of the
observation the model was handed (`observed 61c4c589e491b02a`), so two rows
answered off the same view of the world are visible as such, and the last section
of the file is the run's first question in full — menu, packet and all 3,267
characters of it — so the transcript is evidence on its own rather than something
reproducible in principle.

## The two behaviours the first run measured, measured again

The first model-driven run of this file found two things and reported them
rather than working around them. Both were about the packet, both are now closed
in it, and the run prints the numbers itself every time rather than leaving them
to be counted off a transcript by hand:

| | the first run | the run in the tree now |
|---|---:|---:|
| turns | 17 | 69, across five characters |
| turns that chose `say` | 11 | 29 |
| different lines among them | 10 | 28 |
| the same line chosen more than once | yes, twice | once, twice |
| turns asked with the observation the turn before was asked with | 10 | 10 |
| turns that chose a position | **0** | **13** |

The first run's numbers are counted from its seventeen replies under the same
definitions; the current column is what `./run_agent.sh` prints under *what the
first run of this file measured, measured again*, and the two are not the same
run — one character against five, and a different recording — so the row to read
is the last one, which is about the packet rather than about the cast.

The qualitative change is larger than the counts. In the first run turns 6
through 17 were all greetings aimed at Rook, most of them variations on one
sentence, because saying something changed nothing the character could observe.
In the run the tree holds now, 28 of the 29 lines are different from each other,
and they are answers: Rook answers Pell five times in a row and each answer is
sharper than the last, Bram and Sable agree on a direction and set off, and the
one line said twice — *"The road ahead looks quiet. Care to walk together a
while?"* — was said twice because the first was interrupted part-way through.

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
position thirteen times, having chosen none at all in the seventeen turns of the
run before the legend existed — and the first one the first run chose was refused
by the engine, which is the next finding.

**3. A position in the packet is a world position, and a model may mean an
offset — since closed.** The first run chose `go_to target=(-6.0, -6.0)` and the
engine answered *the position is too far to walk to at once*: the character was
standing at (-474, 417), so a position that reads as "six back and six left" is
six hundred units away. The packet gives the character's own position absolutely
and everything else as an offset, and `go_to` took a world position — all three
true and consistent, with nothing in the prompt saying which the parameter was.
That was reported here rather than worked around, and it has since been answered
in the action surface: `go_to` now takes either `target=` (a world position) or
`offset=` (a step from where the character stands), so the key says which space
the number is in. In the run the tree holds now the models use both, and the
thirteen positions chosen include five offsets the engine walked. See
`reports/position-space-evidence.txt`.

**4. The action surface was sufficient.** Nothing was added to it, and nothing
needed to be. In the run the tree holds now, every one of the 69 answers named
one of the twelve actions or one of the three tools and read back as a
well-formed `Action`; the word *fault* does not appear once in the transcript, so
`ActionCatalog.fault()` refused none of them, and the thirteen choices the world
refused were refused by the *engine*, with a sentence, which is the difference
this layer is built on. The suite
exercises the other direction too: fourteen written replies, at least one per row
of the one list, each of which must read back as exactly the action it names, so
a row that grew a form nothing could express would fail the check.

**5. What a character was shown and what its action meets are two different
worlds.** In the run the tree holds now, Pell was shown the market pile at tick
24, answered `examine target=#6` at 27, and the examine ran from 27 to 31 — but
Wren had taken the last thing out of that pile at tick 29, so the pile left the
world between the looking and the doing and the answer was *there is nothing with
id 6*. In a live run the gap is far wider: one question was put at tick 16 and
answered at 116, a hundred ticks of world in between. Two spans contribute: the
one the
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
all 99 prompts still reproduce exactly — and it is exactly the check that said an
old recording had gone stale when the packet grew, which is why the exchange has
been re-recorded rather than reused every time the questions moved.

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
| the simulation never blocks | tick counts of the other five across every one of the run's 69 waits |
| a character can observe what it heard | the packet's speech is filtered by `ActionEngine._say`'s own `heard_by`, asserted line by line against every character in `tests/test_observation.gd` |
| the window of ground says what its marks mean | the legend is in the packet and in the prompt, generated from `Observation.GLYPHS`/`MEANS`, and the rule-word scan is run over it alone |
| no credential, no network in the suite or the shipped run | `./run_tests.sh` and `./run_agent.sh` replay; only `./run_record.sh --live` calls |
| byte-identical across two processes | `./run_agent.sh` run twice by the suite, compared, and compared with the checked-in transcript |
| no generation rule changed | `./run_headless.sh` final fingerprint `5014980a58150055`, unmoved |
| the layer split holds | `bin/check_layers.gd`: all four checks OK |
| nothing under `sim/` opens a connection, starts a thread or reads a clock | scan over every file under `sim/`, teeth shown; the one file that does all three is `net/model_call.gd` |
| the simulation holds no model's words | `tests/test_character_sheet.gd`'s kind-word scan, which the recording failed under `sim/` and passes from `net/` |
| the live path works inside the simulation, not only in the recorder | `reports/agent-live-evidence.txt`: 31 real calls, the longest wait 100 ticks, nobody else stopped |
