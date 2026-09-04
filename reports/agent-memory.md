# What a character remembers

Until this step a character forgot everything between one decision and the next.
`ModelMind` assembled a packet, wrote a prompt, read an answer back and threw all
of it away; a character shown the same surroundings twice was asked the same
question twice and gave the same answer twice, forever. Section 10 asks for two
things instead, and this step is both of them:

* **a first-person log of experiences and facts** — "I saw Rook (#2), a
  commander, about 6m away", "Wren (#1) shouted: a fair bargain", "I moved 4.5m
  north";
* **durable lessons** — sentences the character keeps and is biased by
  afterwards.

Both live on the character's own sheet, both survive every decision it makes,
and everything in either of them came out of something that character could
perceive.

```
./run_agent.sh              # the shipped run, now with a memory in the packet
./run_lesson.sh             # does a lesson change what is chosen? four arms
./run_memory_suite.sh       # just this step's suite (89 checks)
OPENROUTER_API_KEY=... ./run_record.sh --live    # re-make both recordings
```

| file | what it is |
|---|---|
| `sim/character_memory.gd` | the store: two segments, one door, no index |
| `sim/scripted_lesson.gd` | the four-armed run that measures what a lesson changes |
| `tests/test_memory.gd` | the suite, including the two source scans below |
| `sim/character.gd` | `+ var memory: CharacterMemory` on the sheet |
| `sim/model_prompt.gd` | `+` the memory block, `+` two tools, `+ tool_of()` |
| `sim/model_mind.gd` | `+` witness before asking, `+` carry a tool call out |
| `net/model_recording.gd` | `+ LESSON_ROWS`, recorded in the same pass as `ROWS` |

## The two segments, and where they live

`CharacterMemory` holds `events` and `lessons`, and a `Character` holds one of
them. That is the whole of "carried by the character and surviving across
decisions": nothing between two decisions replaces a sheet, so nothing between
two decisions can lose a memory. Two sheets never share one — the suite makes a
lesson on one and looks for it on the other.

`ModelMind` is what reads and writes it, and holds none of it itself. A mind
thrown away and rebuilt between two ticks loses nothing at all.

## Nothing enters it that the character could not perceive

This is the acceptance line the design most needed to be *shown* rather than
promised, so it is shown twice: once by reading the store's source off disk, and
once by the world.

**The source, first.** Two scans in `tests/test_memory.gd`, both run over
`sim/character_memory.gd` with comments and string literals stripped:

1. **The only world type the file names is `Observation`.** Every CamelCase name
   in the code is collected; the engine's own containers (`Array`, `Dictionary`,
   `PackedStringArray`, `RefCounted`, `String`) and the file's own class name are
   set aside; what is left must be exactly `{Observation}`. A line that reached
   past the packet for anything the character was not shown would have to name a
   scene, a combatant, an engine, a board or an inventory, and the scan would
   have it.
2. **Every function that writes into either segment takes an `Observation`.**
   The source is walked function by function; any function whose body contains
   `events.append(` or `lessons.append(` must declare an `: Observation`
   parameter. There are two such functions and both do. This is why the private
   `_write()` takes the packet rather than the fingerprint it needs: making it
   take the fingerprint would have left one door in the file that had never seen
   a packet.

Both scans are then shown to have teeth, on lines that must fire
(`ActionScene.inventory_of`, a writer declared as `func remember(text: String)`)
and lines that must not (the same words in a comment, the same words in a string,
an ALL-CAPS constant, a writer that does take a packet).

Between them the two say the whole thing. The log is written out of the packet;
the packet is one character's own reading of its own surroundings; so the log is
what that character saw and heard, and there is no third door.

**The world, second.** In the suite, Rook says *"a word in your ear"* to Wren
while Odo stands one unit away and a fourth character stands three hundred units
off:

| character | in its memory afterwards |
|---|---|
| Wren, spoken to | `Rook (#2) said to me: "a word in your ear"` |
| Rook, who spoke | `I said: "a word in your ear"` |
| Odo, one unit away | nothing about it at all |
| the far-off one | in nobody's memory; nobody has seen it |

Nothing in the store measures a position, and that table is what buys it. Who
heard a line is `ActionEngine._say`'s answer, written into the scene as
`heard_by`; `Observation` filters by that list and by nothing else; the memory
writes down what the packet holds. The engine's rule — a line said *to* somebody
is heard by that somebody alone — reaches the memory unchanged because there is
no second opinion anywhere on the way.

## Recent goes into the context; older is asked for

The prompt carries **every lesson** and **the last `CharacterMemory.RECENT` (8)
events**. It does not carry the rest. Reaching the rest is a *tool*, and there
are two:

```
recall         about=words   -- look back through everything you remember for anything about it
learn          text=words    -- keep one sentence in mind from now on, in every later moment
```

Neither is an atomic action, and neither is a row of `ActionCatalog`: section
2.1's list is twelve long and stays twelve long. A tool touches the character's
own memory, changes nothing in the world and takes no time in it. A reply naming
one is read by `ModelPrompt.tool_of()` rather than `action_of()`; `ModelMind`
carries it out, records the turn, returns no action — so the character stands
where it is, exactly as it does when a model says nothing readable — and asks
again with what the tool did in the next prompt. A tool call costs one exchange.

`recall` reads the same two segments the context is written out of. There is no
index, no embedding and no consolidation pass, which is section 10's own
sequencing: recent-plus-query first, the heavier machinery when scale demands it.
The suite checks the identity rather than trusting it: it takes an entry the
context does *not* carry, asks for it back, and requires the line handed over to
be that entry of `events` — not a copy of it living somewhere else — and requires
that looking back added nothing to the store.

## A lesson measurably changes what is chosen

`./run_lesson.sh` is the measurement. One character, one moment, four arms, and
the lesson is the only thing that can be doing the work:

* the world is staged from scratch for every arm, from seed 1234, and stepped
  100 ticks with the same five characters doing the same things while the model
  character chooses nothing and writes down what it sees every
  `ControlLoop.REVIEW_EVERY` ticks;
* every arm's observation has the same fingerprint — `9a14b32a0f3eefc1`,
  printed;
* every arm's prompt is identical outside its `What you remember` block, checked
  by stripping that block out of all four and comparing what is left;
* arm 0 keeps no lesson; arms 1–3 each keep one, through `learn()`, the same door
  a model's own `learn` goes through.

The six things in the log are the same in all four arms. What came back:

| arm | lesson kept | chose |
|---|---|---|
| no lesson | — | `say(text="a fair bargain indeed, Wren" target=1)` |
| the ground first | *"Whenever I have been slow to go and look at what is lying on the ground here, it has been gone by the time I turned round. Wren's bargains keep; the ground does not."* | `say(text=what do you offer, Wren? target=1)` |
| Rook, not Wren | *"Wren calls the whole market to every bargain and has never yet meant me. Rook is the only one here who has ever actually traded with me."* | `recall about=trade with Rook` — a tool, so *— nothing readable —* |
| let them come | *"The three times I have answered a shout in this market, the one who shouted had already turned away and I was left talking to nobody. I do better letting them come to me."* | `say(text=a fair bargain, then. target=1)` |

**3 of 3 lessons changed the choice; 1 of 3 changed which action was chosen**, and
the run reports that in two columns on purpose: a different *action* and a merely
different *wording* are different claims. Named plainly: with nothing kept, the
character agreed with Wren's shout; having kept that the ground does not wait, it
asked Wren what was on offer; having kept that answering shouts has never worked,
it agreed in fewer words. The arm that changed which action is the Rook one, and
it changed it by not choosing an action at all: it answered `recall about=trade
with Rook`, which is a look back through its own memory rather than a move in the
world, and this harness puts one question and reads one action back, so the arm
shows nothing readable and the run scores it as such rather than pretending it
was a choice.

This is a weaker result than the draw this page was first written from, where all
three lessons moved the action outright. It is the same measurement on a
different recording, and a recording is one draw: what holds across both is that
the lesson is the only thing that differs and the answer differs every time.

The lessons are the character's own sentences and not borrowed rules. The suite
runs the prompt's own rule-word scan — *distance, reach, cost, damage, possible,
allowed, cannot, succeed, fail, cooldown, radius, range* — over all four prompts
and finds nothing.

## How much memory there is

Measured on the shipped run (`./run_agent.sh`, seed 1234, 160 ticks), on Pell,
the character that comes to remember most, over its 22 turns:

| | |
|---|---|
| entries | **32** — 32 events, 0 lessons |
| by kind | 11 things seen, 20 lines of speech, 1 state change |
| characters held | **1,954** |
| characters a packet carries | **503 of 1,954 (26%)** — every lesson and the last 8 events |
| the memory block in the last question | **703 characters of 4,570 (15%)** |
| tools the model used | 7 recalls, 0 lessons written |

The stop condition on this item was the other direction — stop and report if the
memory outgrew what a context can carry — and it did not fire: 1,954 characters
against a question already 4,570 characters long is not a retrieval problem, and
the recent-plus-query split is only just starting to carry weight. The number to
watch is *characters held*; a packet now carries 26% of it where it once carried
76%, so the fraction is falling as the store grows, which is exactly the trend
that would eventually be the evidence for an index. It is not evidence for one
yet: `recall` returned at most ten entries in a run of 160 ticks, and a linear
walk over thirty-two of them costs nothing.

Two honest notes about that table:

* **The tools are used unevenly, and the shipped recording uses both.** Both are
  offered in every prompt, and the whole path works end to end — the suite drives
  a mind through `recall about=lantern` and `learn text=…` against a real store
  and checks that the query found a real entry, that the lesson landed on the
  character's own sheet, and that the mind then went back to choosing an action.
  On the recording that ships, Pell called `recall` seven times unprompted, six of
  them for the brass lantern it was after, and Odo wrote one lesson — `learn
  text=Keep heading north across the rising slope.` The other three of the five
  used neither. Which of those a given draw does is the model's business; that it
  *can* is this step's.
* **The log does not hold what an `examine` told the character.** An action's
  outcome is not in the observation packet — the packet carries state
  transitions, and examining changes no state — so it cannot come in through the
  one door. In the shipped run that shows in the questions: ten of the sixty-nine
  turns were put off an observation identical to the one before, and Sable
  answered `wait(ticks=1)` three times running off one byte-identical prompt. A
  character that wants to keep what it learned that way has `learn`. Widening the
  door would have cost the perception check above, which is worth more.

## Determinism, and what did not move

* `./run_agent.sh` and `./run_lesson.sh` are headless, need no key, no network
  and no model, and print identical bytes in two processes — checked by both
  suites running each command twice and comparing, and against the transcripts
  checked in at `reports/agent-evidence.txt` and `reports/lesson-evidence.txt`.
* Both recordings are made by one command in one pass — `./run_record.sh --live`
  writes `ROWS` and `LESSON_ROWS` together — so the two can never be a recording
  of two different days.
* Nothing under `sim/` reads a clock or names the render layer: the standing
  scans in `tests/test_control_loop.gd` and `tests/test_agent.gd` cover the two
  new files automatically, and `./run_tests.sh --layers-only` passes.
* No file that resolves the world names a character's memory. The suite scans
  every file under `sim/` for the word and requires the set that has it to be
  exactly the six that are meant to: the sheet, the store, the mind, the prompt
  and the two runs. No engine rule moved into the store.
* `net/model_call.gd`'s token ceiling went from 512 to 1,200. One question of
  eighteen came back with nothing readable in it and `length` as the reason: the
  model had spent the whole ceiling working and never reached its line. The
  ceiling is about the working, not the answer, and the working grows with the
  question — the same lesson the 96 → 512 raise taught, learned again at a larger
  prompt.
