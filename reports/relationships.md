# Relationships on edges between characters, maintained by the world

Section 10 of the design asks for one thing and gives the reason in the same
sentence: *"Relationships live on edges between entities, not inside any single
NPC's memory — a shared graph retrieved when interacting with that target."*
Until now the project had the handle and not the thing: `Character.sentiment` was
an empty `Dictionary` on the character sheet, nothing ever wrote to it, and the
one thing that read it — the observation packet's test for whether a character
knows another's name — could therefore never answer yes except for characters
standing in the same band.

This is that graph, built. Edges between entity ids, in one store the world owns,
each carrying **trust**, **fear**, **respect**, **familiarity** and a short
summary of the interactions that made it; each field moved only by something the
engine actually carried out; all of it maintained on `sim/character_upkeep.gd`,
the path every character passes whoever is deciding for it.

It also settles the first of the design's open questions (section 13): which
scalar or composite is the raw sentiment term that the ownership maths reads.

```
./run_scenario.sh              # a trade and a quarrel, and what they made of five characters
./run_turn.sh                  # five blows, and the fear and respect they left
./run_agent.sh                 # a person-driven character's edges beside five model-driven ones
./run_world.sh                 # an answer that tried to write an edge, refused
./run_relationships_suite.sh   # the suite, 137 checks
```

## An edge is one record between two entities, with two sides

`sim/relationship_edge.gd` is one record per *pair*, keyed by the two ids in
order, so `graph.between(a, b)` and `graph.between(b, a)` hand back the same
object — not equal objects, the same one. The suite asserts it with `is_same()`.
That is the whole of what "between rather than inside" buys: a pair of per-sheet
dictionaries would be two accounts of one history, the character serviced first
would write its half, the other's half would be written out of a world that had
already moved, and nothing anywhere would say which was right. There is nothing
to keep in step here because there is only ever one of them.

What it holds is two-sided. A blow has a striker and a struck; a gift has a giver
and a receiver. One set of numbers for both would say the character who swung the
sword is as frightened as the one who was hit. So the four fields exist once per
end, and `edge.toward(id)` reads the end belonging to whoever is looking:

| field | what it is | moved by |
|---|---|---|
| trust | would this character rely on the other | trades honoured, gifts received; taken away by being struck |
| fear | would it rather the other were not near | being struck, in proportion to what the blow took |
| respect | how much it rates what the other can do | being struck; a little, by an exchange honoured |
| familiarity | how much of the other it has actually seen | *every* happening between the two, words included |

The summary is shared and written in the world's voice — `#1 gave 12 coins to #2
for 1 thing`, not *I was robbed* — because these are the world's record of what
happened and not either character's reading of it. What a character *makes* of
what happened is the four numbers; what it *remembers* of it is
`CharacterMemory`, written out of what that character could see. Only the last
four lines are kept: it is a summary, and a log that kept everything would be the
memory store a second time.

## The rules, and the happening that moves each field

Every rule is one of two shapes. `raise` closes a share of the distance left to
1; `lower` gives up a share of what is there. So no rule can leave $[0, 1]$
however many times it applies, and every one is worth most the first time — the
first exchange with a stranger tells you far more than the fortieth, which is the
shape all four of these actually have.

| happening | the world's record it is read from | end | field | rule |
|---|---|---|---|---|
| any of the three below | — | both | familiarity | raise by `MET` = 0.25 |
| a line heard | `ActionScene.said` | either | trust, fear, respect | **unmoved** |
| a trade honoured | `ActionScene.trades` | both | trust | raise by `TRADE_TRUST` = 0.20 |
| a trade honoured | `ActionScene.trades` | both | respect | raise by `TRADE_RESPECT` = 0.10 |
| a gift — an honoured trade with nothing coming back | `ActionScene.trades` | the receiver's | trust | raise by `GIFT_TRUST` = 0.35 |
| a blow struck | `ActionScene.blows` | the struck one's | fear | raise by the share of its full health the blow took |
| a blow struck | `ActionScene.blows` | the struck one's | trust | lower by `STRUCK_TRUST` = 0.50 |
| a blow struck | `ActionScene.blows` | the struck one's | respect | raise by `STRUCK_RESPECT` = 0.25 |

Three of those deserve their reasons written down.

**Words move familiarity and nothing else, on purpose.** Section 6 says pure talk
raising sentiment is *"deliberately hard — only truly novel diplomacy is even
considered"*, gated by an ability check. A rule here that let trust rise with
every "good morning" would be exactly the cheese that sentence forbids, and it
would arrive before the check meant to gate it. So talking does the one thing
talking plainly does: the two now know each other somewhat. Raising trust by
*what was said* is a check, and it is the next work item.

**Being struck raises respect as well as fear.** A blow is a demonstration of
what somebody can do. Respect here reads capability, not liking — which is
exactly why it is not in the sentiment term below.

**Only the struck end moves.** Striking somebody tells you nothing about them you
did not already know; being struck does. The striker's end gains familiarity,
like every end of every happening, and nothing else.

Nothing that did not happen moves anything. A *proposed* trade moves nothing, a
*denied* one moves nothing, and a refused action moves nothing — the engine
writes no record for any of the three, so there is nothing to fold. The suite
plays all three through the engine and asserts the graph is still empty.

## The one number the ownership maths reads

Section 13's first open question, closed:

$$s(A \to B) \;=\; \mathrm{familiarity} \times (\mathrm{trust} - \mathrm{fear})
\;\in\; [-1, 1]$$

It is `RelationshipGraph.sentiment(from_id, to_id)`, and it is the only number
the graph offers — the suite reads the class's method list and requires that
`sentiment` is the sole public method returning a float, so the ownership item
cannot quietly read a second one. Three choices, each with a reason:

* **Trust minus fear, and not either alone.** Ownership asks whether this
  character would rather that one held the ground it is standing on. Trust is why
  it would; fear is why it would not; and fear is not the absence of trust — a
  character can hold both about the same warlord at once, and what is left when
  you take one from the other is precisely the question ownership asks.
* **Respect is left out.** Respect measures capability, not welcome: a feared,
  respected warlord and a trusted, respected healer would count the same. Section
  6 already carries capability twice over — it scales each character's sentiment
  by that character's *status* and *level* — so putting respect in the raw term
  would count the same thing once as the opinion and again as the weight. It
  stays on the edge because it is real and a later rule may read it; ownership
  does not.
* **Familiarity multiplies rather than adds.** An opinion about somebody barely
  met should not decide who owns ground. Two characters who have exchanged one
  greeting have familiarity near zero and so a sentiment near zero however warm
  the greeting; the same trust after forty dealings counts in full. Multiplying
  is also what keeps the term inside $[-1, 1]$ without a second clamp.

No weighting by status or level happens here and no distance is read: those are
section 6's, and belong to the ownership item that reads this one.

## Maintained by the world, not by whoever is deciding

The three writers are called from `sim/character_upkeep.gd` and from no other
file under `sim/`. The suite scans every file in the directory for `.heard(`,
`.traded(` and `.struck(`, requires the list to be exactly the shared path, and
is shown to catch a planted call in a driver so that its silence about the real
files means something. `character_upkeep.gd` names no decision function, no mind
and no channel, so there is nothing in it to branch on.

**What is folded is the world's records, not each character's share of them.** A
happening has two ends, so folding per character would fold it twice. Instead the
upkeep reads `ActionScene.said`, `.trades` and `.blows` from wherever the graph
had got to, and the mark saying where that is lives *on the graph*. Three
consequences, all asserted:

* servicing the six characters in the opposite order gives a byte-identical
  graph;
* a second upkeep over the same world folds nothing — one thing that happened is
  one move of one edge, however many upkeeps a run happens to make;
* a character with **no decision function at all** still has its edges kept, and
  so does a character nobody ever services, because the edges were never its to
  keep.

### A person-driven character's edges beside a model-driven one's

From the shipped `./run_agent.sh` — six characters, five deciding through a
language model and one driven by a person's recorded choices, 160 ticks, seed
1234:

```
what the world recorded between them
  8 edges, made of 27 happenings, and not one of them on anybody's sheet
  sentiment is familiarity x (trust - fear), which is the one number section 6 reads
  who    driven by with     trust    fear   respect   familiarity  sentiment
  Wren   a person  Rook      0.00    0.00      0.00          0.92      +0.00
  Wren   a person  Bram      0.00    0.00      0.00          0.25      +0.00
  Wren   a person  Sable     0.00    0.00      0.00          0.25      +0.00
  Wren   a person  Pell      0.00    0.00      0.00          0.25      +0.00
  Rook   a model   Wren      0.00    0.00      0.00          0.92      +0.00
  Rook   a model   Pell      0.00    0.00      0.00          0.58      +0.00
  Bram   a model   Sable     0.00    0.00      0.00          0.92      +0.00
  Bram   a model   Pell      0.00    0.00      0.00          0.25      +0.00
  Bram   a model   Wren      0.00    0.00      0.00          0.25      +0.00
  Sable  a model   Bram      0.00    0.00      0.00          0.92      +0.00
  Sable  a model   Pell      0.00    0.00      0.00          0.44      +0.00
  Sable  a model   Wren      0.00    0.00      0.00          0.25      +0.00
  Odo    a model   nothing has passed between it and anybody
  Pell   a model   Rook      0.00    0.00      0.00          0.58      +0.00
  Pell   a model   Bram      0.00    0.00      0.00          0.25      +0.00
  Pell   a model   Sable     0.00    0.00      0.00          0.44      +0.00
  Pell   a model   Wren      0.00    0.00      0.00          0.25      +0.00
```

Wren is the character a person drives. Its four edges sit in the same table as
the model-driven ones, carrying the same kind of numbers, of the same order: 0.92
against Rook and 0.25 against the three it only heard, next to Bram and Sable's
0.92 with each other and Pell's 0.58 with Rook. Odo walked away from everybody
and has no edges, which is a fact about where Odo went and not about what is on
its `decide`. This is the finding of the earlier review — that
the two per-character stores filled only along the model layer's path — not
repeated for the third store.

Everything is zero but familiarity because this run is all talk: nobody trades
and nobody lands a blow. The other three fields are shown moving on the two runs
that do.

### A trade and a quarrel

From the shipped `./run_scenario.sh` — five characters, a market and a fight:

```
what the world recorded between them (2 edges, 13 happenings)
  sentiment is familiarity x (trust - fear), the one number section 6 reads
  #1 -> #2 trust 0.20 fear 0.00 respect 0.10 familiarity 0.76 sentiment +0.15
  #2 -> #1 trust 0.20 fear 0.00 respect 0.10 familiarity 0.76 sentiment +0.15
    made of #2 said to #1 "what will it be?" ; #1 gave 12 coins to #2 for 1 thing ; #1 shouted where #2 "a fair bargain" ; #1 shouted where #2 "what was that noise?"
  #3 -> #4 trust 0.00 fear 0.77 respect 0.68 familiarity 0.90 sentiment -0.70
  #4 -> #3 trust 0.00 fear 0.47 respect 0.68 familiarity 0.90 sentiment -0.42
    made of #3 struck #4 for 5 of 38 ; #4 struck #3 for 12 of 38 ; #3 struck #4 for 5 of 38 ; #4 struck #3 for 11 of 38
```

Two traders end at $+0.15$ toward each other; two who fought end at $-0.70$ and
$-0.42$, and the asymmetry is the asymmetry of the fight — #3 took more damage
than it dealt, so it fears more. Nobody wrote either number: they are the
engine's own records of an exchange it honoured and four blows it landed, folded
through the rules above.

### Five blows

From the shipped `./run_turn.sh`, where two commanders both choose `attack`:

```
what the blows made of them (5 blows landed, 1 edge)
  #1 struck #2 for 17 of 38 on tick 7
  #2 struck #1 for 11 of 38 on tick 14
  #1 struck #2 for 12 of 38 on tick 21
  #2 struck #1 for 12 of 38 on tick 28
  #1 struck #2 for 12 of 38 on tick 35
  #1 -> #2 trust 0.00 fear 0.51 respect 0.44 familiarity 0.76 sentiment -0.39
  #2 -> #1 trust 0.00 fear 0.74 respect 0.58 familiarity 0.76 sentiment -0.57
```

Fear is read from the share of *that character's own full health* a blow took, so
a scratch from a giant and a killing stroke are not the same event. #2 was struck
three times to #1's two and fears accordingly. The edge outlives #2, which the
run drops from the world when it falls: the graph is the record of what happened
and a character falling does not unmake it.

## A model may not write an edge

This is the point of the store being the world's. A character that could write
its own record could be loved by everybody merely by saying so.

* **No operation names one.** The orchestrator's table (`sim/world_effects.gd`)
  has seven operations and none of them is a relationship. A line naming one
  therefore reads as *no operation at all*, and put through the engine anyway it
  is refused in the same words any unknown operation is refused in. From
  `./run_world.sh`:

```
the relationships, which are the world's record and not a model's
  #1 <-> #4 1 happening | #1 trust 0.00 fear 0.00 respect 0.00 familiarity 0.25 | #4 trust 0.00 fear 0.00 respect 0.00 familiarity 0.25
  and an answer that tried to write one:
    the line          relate target=#2 trust=1.0 fear=0.0
    read as           0 operations -- there is none of that name in the table
    through the engine would not -- there is no such operation
    and the graph     unmoved
```

* **No file of the model-facing layers names the graph.** The suite opens
  `model_mind.gd`, `model_prompt.gd`, `model_cast.gd`, `model_channel.gd`,
  `orchestrator.gd`, `orchestrator_prompt.gd`, `check_prompt.gd`,
  `check_desk.gd` and `ability_check.gd` and requires that none of them contains
  `RelationshipGraph`, `RelationshipEdge` or `relationships` in code.
  `tests/test_orchestrator.gd`'s existing "reaches into a mind" scan, which used
  to ban `.sentiment`, now bans the graph by name instead.
* **No action and no tool offers one.** The twelve atomic actions are unchanged,
  the three prompt tools are unchanged, and the character prompt contains none of
  the four field names.

## What a character may see about a relationship

**Its own edges, and nothing else.** The graph is reached from the observation
packet through `knows(self_id, …)` and `edges_of(self_id)` — both keyed by the id
of the character the packet belongs to — so what two other people are to each
other is not addressable from where this character stands, any more than another
character's memory is. `edges_of` walks the store and returns only edges the
character is an end of; the suite builds a three-character graph where 1↔2 and
2↔3 exist and asserts that 1 is handed one edge, 2 is handed two, and a character
nothing has happened to is handed none.

The four numbers are deliberately **not** written into the packet today. They are
what section 6's ownership maths reads and what section 6's diplomacy check
moves, and neither exists yet; putting them in front of a decision function
before either does would change what characters choose, which is not what
recording what happened is for. What the packet asks the graph is what it has
always asked: whether these two have met.

That question now has a better answer. It used to be read off the looker's own
empty `sentiment` dictionary, so it was always *no*; it is read off the world's
edge now, so it is *yes* once something has actually passed between the two — and
it is mutual, because having met somebody is not a fact one of the two can hold
privately. The retired dictionary could not have been: two sheets would each have
kept their own half of it.

## `Character.sentiment` is retired, not filled

The sheet's empty handle is gone, the same way its single free-text `goal: String`
went when the structured goal set landed. Section 2 lists a sentiment map among
what a character has; section 10 is more specific and wins. Nothing was lost with
the field — nothing ever wrote to it, and its one reader reads the graph now.
`tests/test_character_sheet.gd` asserts by reflection that the sheet no longer
carries a field of that name.

## Headless and deterministic

* **Two processes agree.** `./run_agent.sh` and `./run_scenario.sh` each run
  twice in separate processes print byte-identical output (`cmp` exit 0). So does
  `./run_headless.sh --seed 1234 --ticks 100`.
* **The world fingerprint on seed 1234 did not move.** `d178d38879097c1c` before
  this work and `d178d38879097c1c` after — the terrain streamer's fingerprint has
  nothing to do with what characters do to each other.
* **Four `ActionScene` fingerprints did move, and here is why.** The graph joined
  `ActionScene.fingerprint()`, which is the digest of everything an action can
  move: two runs that agree on every action must agree on the edges those actions
  left behind, and a fingerprint that ignored them would be blind to a whole
  store. The moves, all attributed to that:

| run | before | after |
|---|---|---|
| `./run_check.sh` | `11725229a9e8314a` | `305f10e2de31025f` |
| `./run_scenario.sh` | `7efa1a16f912e51d` | `2810e3d79c9c7ece` |
| `./run_world.sh` | `939f85ef6e27b820` | `e667d199e628967b` |
| `./run_agent.sh` | `d506019b20bd1ce8` | `bcd16fab0ee99f47` |

  Those four are the move *this* work made, and they are left as they were
  measured. Three of them have since moved again for an unrelated reason — the
  model recording was re-made on 2026-09-05 against a changed prompt, so the
  three runs that replay it now end at `550e14813932bf8c` (`./run_check.sh`),
  `37bd8b92ef92dd5d` (`./run_world.sh`) and `5bc35efd0901430d`
  (`./run_agent.sh`). `./run_scenario.sh` replays no model reply and is still at
  `2810e3d79c9c7ece`.

* **One behavioural move on the agent run, and it is the one the work asks for.**
  Bram and Sable are of different bands and had only ever met by speaking. Under
  the old rule they could never learn each other's names; under the new one they
  do, so their observation packets name each other, their prompt digests change,
  and the replay channel — which falls back to answering the *n*-th question with
  the *n*-th recorded reply when a digest does not match — hands two adjacent
  replies to Pell and Sable the other way round on the last two turns of the run
  (`go_to target=#2` and `go_to target=#3` swap). The set of actions chosen is
  otherwise unchanged, and Bram's and Sable's memories each gain one line, for
  the same reason: a character they can now name is a character they write down
  by name. No field was added to the packet and no rule about choosing changed.
* **The layer check passes**: nothing under `sim/` references `render/` or names
  an asset path.

```
layer check:     OK -- res://sim references nothing in the render layer
combat check:    OK -- res://render draws the fight and holds none of it
interface check: OK -- res://render/ui names its art through sprout_pack.gd alone
asset check:     OK -- res://sim names asset tags and no asset
```

## What it costs

The stop condition on this work was: if maintaining edges on the shared upkeep
path measurably slows the shipped run, report the cost with numbers rather than
moving the maintenance into whichever driver is cheapest. It does not, so it did
not fire. Three runs of `./run_agent.sh` — 160 ticks, six characters — each way,
with the fold left in and with it replaced by a constant zero:

| | run 1 | run 2 | run 3 | mean |
|---|---|---|---|---|
| maintaining edges | 36.68 s | 35.93 s | 36.12 s | **36.24 s** |
| maintenance off | 36.59 s | 36.58 s | 36.49 s | **36.55 s** |

The difference is inside the noise, and in the direction that says there is
nothing to measure. That is what the shape of the work buys: the fold is
proportional to what has *newly* happened in the world, not to how many
characters are serviced or how often — the mark lives on the graph, so a
servicing that finds nothing new does three integer comparisons and returns.

## Suites

```
./run_relationships_suite.sh    PASS  relationships  137 checks
./run_tests.sh                  all 45 suites passed (195730 checks)
./run_tests.sh --layers-only    four rules, all OK
./tools/piece_mutations.sh      all 19 broken rules were caught
./tools/resolution_mutations.sh all 61 broken rules were caught
```

The suite before this work was 44 suites and 195,593 checks, of which four
suites failed once the graph joined `ActionScene.fingerprint()` — those four are
the checked-in transcripts in the table above, regenerated and re-passing.

## What this deliberately does not do

* **No ownership arithmetic.** No distance, no radius, no softmin, no threshold
  and no weighting by status or level. That is the next item, and it reads
  `sentiment()` and nothing else here.
* **No sentiment diffusion.** Section 6 marks it `[REACH]`; there is no term here
  for anybody's sentiment toward anybody else's.
* **No new decision-time behaviour.** The twelve actions, the three tools and the
  fields of the observation packet are what they were.
