# Where a character stands, said so a recording can survive it

*W-observation-rerecord, cycle 3634. Evidence:
[observation-position-evidence.txt](observation-position-evidence.txt).*

The packet a character is handed opened with a line saying where that character
is standing, and it said it to three decimal places:

```
  you        commander level 2 status 2 hp 32/32 at (-478.000, -2.352, 416.000) facing 0.00 in the world
```

A recorded model reply is keyed to the sha256 of the prompt that asked it
(`net/model_recording.gd`), so every digit in that line is a digit that has to
come out the same for the recording to go on answering. Three decimals of a world
unit is a millimetre. It now reads:

```
  you        commander level 2 status 2 hp 32/32 at (-478, -2, 416) facing 0.00 in the world
```

## The decision, and the two facts it is between

**What stays.** The character's own position stays in the packet, and stays in
the frame it was already in — absolute world coordinates. That is the frame every
position the action catalogue accepts is written in, and the model uses it: in
the goal comparison a character standing at `(-476, 422)`, told it is after being
at `(-471.0, 416.0)`, answers `go_to target=(-471, 416)`. Take the line away and
a character cannot name a place near itself at all, which is the ability the
ground legend bought in the first place.

**What goes.** The three decimal places. Nothing in the packet and nothing in the
catalogue can read a millimetre. The character's own remembered lines already
speak in whole metres — *"I saw Wren (#1), a commander, about 8m away."* — the
trail in tenths, the ground window in cells of three units with heights rounded
to whole units, and the shortest move any action makes is a stride of
`ActionEngine.STEP`, which is $0.9$. The extra digits were the float's own
printout rather than something anybody could read or act on.

`tests/test_observation.gd` checks that as a *grain* rather than as a format: a
character that shifts by $0.4$ of a unit writes the same line, and one that walks
two units does not.

## The measurement says the coarser grain would not have saved it either

The recommendation this work came from was that the prompt should stop carrying
absolute coordinates, on the theory that the coordinates were why the walk-motion
change (`e68c45f`) took recorded answers from $71$ of $71$ questions to $15$ of
$71$. That theory is wrong, and the way to show it is to re-derive the collapse
under each scheme rather than to argue about it.

Two git worktrees, at `424edcc` (the commit before the walk-motion change) and at
`e68c45f` (the change), each played the shipped run and dumped all $71$ prompts.
Each of the second tree's questions is then matched against the multiset of the
first tree's prompt digests — which is exactly what `ModelChannel._row_for` does
when it looks for the row recorded for this very prompt.

| what the packet says about a position | questions the recording still answers |
|---|---|
| three decimal places, as it was | 15 of 71 |
| **whole world units, what ships now** | **15 of 71** |
| the tactical cell, 3.0 units | 15 of 71 |
| whole units, and the entity offsets and distances with them | 15 of 71 |
| cell grain, and the entity offsets and distances with them | 15 of 71 |
| cell grain, the entity offsets, and the trail's own distances | 15 of 71 |

Not one recovered question. Widening the change past this item's boundary — to
the offsets, the distances and the trail — recovers none either. And the ceiling
is not much better:

| what is left of the packet | questions the recording still answers |
|---|---|
| the trail and the remembered lines deleted outright | 29 of 71 |
| …and every number in the whole packet replaced by a letter | 48 of 71 |

So even a packet with no numbers in it at all and no memory attached loses $23$ of
the $71$.

## What class of change still invalidates a recording, exactly

Pair each question after the change with the nearest question the same character
was asked before it, with every position already coarsened and the trail's
distances rounded, and read what still differs:

```
 101  - I saw Wren (#N), a commander, about Nm away.
  82  lately     the last N of N things you remember
  74  moved Nm north
  66  moved Nm east
  51  dropped Nm
```

A walk used to be a teleport at the end of a twenty-tick wind-up; it is now a
stride a tick. So a character does not merely stand somewhere else — it *has
lived through* something else. It remembers a different number of things, its
trail holds twenty small moves where it held one large one, the people it can see
are partway through their own journeys, and the run's questions are put by
different characters at different moments. That is a different run, and no way of
writing a position makes a recording of one run answer the questions of another.

The two classes, stated plainly:

* **A change that moves a character without changing what it then does** — ground
  resampled a hair differently, a placement rounded somewhere else, arithmetic
  re-associated. The old line broke on anything above half a millimetre. The new
  one is unmoved by anything under half a unit. This is what the change buys, and
  `tests/test_observation.gd` holds it.
* **A change to how far a character has got by the time it is asked** — the
  walk-motion change, a change to a cost in ticks, a change to who is serviced
  when. Nothing in the packet's representation touches this, and the only answer
  is a live re-recording. Measured above: $0$ of the $56$ lost questions recovered
  by any coarsening, and $33$ of them recovered only by deleting the packet's
  memory and every number in it.

## The re-recording, and what it cost

The prompt changed, so the recording had to be made again. Before the change the
checked-in recording answered $101$ of $101$ questions across the four tables
whose prompts carry an observation packet; with the change and the old recording
still in place it answered $0$ of $100$; after the live passes it answers $93$ of
$93$.

| | before | with the change, old recording | after the re-record |
|---|---|---|---|
| questions the four runs put | 101 | 100 | 93 |
| questions with a reply recorded for them | **101** | **0** | **93** |
| questions answered by position instead | 0 | 100 | 0 |
| questions with nothing at all | 0 | 0 | 0 |

`./run_agent.sh` prints identical bytes on two processes and matches
`reports/agent-evidence.txt`; the seed-1234 world fingerprint is
`32656f55cc5eeb1c` before and after, unchanged, because an observation is a
reading and changes nothing in the world.

Three passes of the one command that touches the network, one of them thrown
away:

```
OPENROUTER_API_KEY=... ./run_record.sh --live --cast      # 83 calls
OPENROUTER_API_KEY=... ./run_record.sh --live --bargain   # 19 calls, discarded
OPENROUTER_API_KEY=... ./run_record.sh --live --bargain   # 20 calls, ships
```

$122$ calls in all, $101$ of them checked in, not one of them empty. The
difficulty-class, orchestrator and goodwill tables carry no observation packet
and were written back unchanged, keeping their own dates.

### The bargain table was recorded twice, and here is why

The first bargain draw did not close the sale. Hob proposed `give=[brass lantern]
want_money=8` on tick 4 from six units away, the engine refused it — *"Fen is out
of reach (6.00 > 2.50)"* — and he spent the remaining hundred and twenty ticks
examining the pile. `tests/test_bargain.gd` hard-asserts the end-to-end purchase,
so six of its checks failed: the trader should have accepted a bargain, the
lantern should be in the person's pack, the person paid the price, the trader no
longer carries it, the sale closed what the trader was after, and the pack is
shut again. The pass was made a second time and that draw closed the sale, and
that is what ships.

That is a recording chosen on the outcome of a test, so it is stated here rather
than buried. Two things follow from it.

It is not the position line. With this same packet and the *old* 2026-09-07
bargain rows replayed by position, the run closes the sale and the suite passes
with $74$ checks — the world still allows the purchase, and the first draw of the
day simply did not make it. Nothing about the coarser position stopped Hob from
walking to Fen; walking to Fen is `go_to target=#1` and needs no coordinate at
all.

One more thing fell out of the re-take, and it is not about positions at all: the
dialogue panel over the new bargain draw is **0.6715% off-grid** where it has
always been 0.0000%, because Hob's line contains an em dash, the pixel font has
no glyph for one, and the engine draws its own missing-glyph box whose edges land
between pixels. Measured, reported in
[dialogue-trade.md](dialogue-trade.md), and left standing rather than
re-recorded away.

It is a real problem with the test. A suite that hard-asserts an end-to-end
purchase carried out by a language model makes re-recording that one table a
lottery with the suite's colour as the prize, and it will be re-recorded every
time this prompt changes. What the run should be asserting is the *machinery* —
that a pack is shown exactly while a trade stands, that a keyboard can name an
item in an ask, that a refusal reads the same for both kinds of mind — none of
which needs the model to succeed at haggling. Filed as a finding rather than
fixed here, because the action catalogue and the bargain suite are outside this
item's boundary.

## Reproducing everything above

```
./tools/recorded_replies.sh                       # what the recording still answers
./run_observation_suite.sh                        # the grain, as a check
./run_agent_suite.sh                              # the recorded-replies check
./run_agent.sh                                    # twice, and cmp
./run_headless.sh --seed 1234 --ticks 100         # the world fingerprint
./tools/readme_model_numbers.sh                   # the prose against the transcripts
```
