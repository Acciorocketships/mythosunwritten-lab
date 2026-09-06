# Who owns a point: proximity-weighted sentiment scaled by status and level

Section 6 of the design is the game's overarching goal and one paragraph of it is
a formula: *"Ownership is computed per point as a distance-weighted average of
weighted sentiment: take all entities within a large radius, weight each by
proximity (closer = higher, e.g. softmin), and combine with their weighted
sentiment toward each player they know of. If the top ownership score exceeds a
threshold, that player owns the point; otherwise it's neutral."* And: *"Weighted
sentiment = a character's raw sentiment toward a target, scaled by that
character's status and level."*

That paragraph is now `sim/ownership_field.gd`, and nothing else is.

The three numbers section 13 lists as open — the softmin temperature, the radius,
and the threshold — are settled here, and each is settled by a measurement on the
shipped seeded run against a criterion stated before the table that settles it.
`./run_ownership.sh` prints every one of those tables.

```
./run_ownership.sh             # the six tables the three constants rest on
./run_ownership.sh --cost      # ...and what one sweep of the grid costs
./run_ownership_suite.sh       # the suite, 55 checks
```

## The rule

For a point $p$ and a claimant $c$, over every entity $i$ standing within
`RADIUS` of $p$ **other than $c$ itself**:

$$O(c, p) = \frac{\sum_i w_i(p) \, m_i \, s(i \to c)}{\sum_i w_i(p) \, m_i}
  \qquad m_i = \mathrm{status}(i) + \mathrm{level}(i)
  \qquad w_i(p) = e^{-|p - i| / T}$$

$s(i \to c) \in [-1, 1]$ is `RelationshipGraph.sentiment()` — familiarity $\times$
(trust $-$ fear), the one number the relationship work settled for this maths to
read. The claimant with the greatest $O$ owns $p$ if that score is above
`THRESHOLD`; otherwise $p$ is neutral.

Five choices are in that expression, and each is section 6's own words or a
consequence of them:

* **It is an average, so there is a denominator.** Section 6 says "distance-
  weighted *average*", and dividing is what makes the score a number in
  $[-1, 1]$ whatever size the crowd is. Without it a claimant could own ground by
  being liked slightly by a great many, and one threshold could not serve both an
  empty moor and a market day.
* **An entity that has never met the claimant is in the denominator.** Having no
  opinion of somebody is an opinion about whether they should hold the ground you
  are standing on: not this one. Strangers dilute a claim rather than being
  skipped, which is exactly what makes crowded contested ground come out neutral.
* **A claimant is not a voter in its own claim.** There is no self-edge in the
  graph, so a claimant standing on the point would otherwise enter its own
  denominator with a sentiment of zero and dilute itself — standing on ground
  would weaken your hold on it. The suite pins this with a number: in the
  hand-checked world the score is 0.841, and 0.287 if the claimant voted.
* **Status and level are added, not multiplied.** A product would let either at
  zero erase the other, so a general with no standing would carry no weight at
  all. A sum lets each move the answer on its own, which is what "both paths
  matter" means.
* **Every character in the world is a possible claimant.** Section 6 says "each
  player they know of", and this file has no way to ask which characters a person
  is driving — `tests/test_character_sheet.gd` fails the build if any file under
  `sim/` names one. The claimants are whoever the near entities have met and who
  is still standing.

## The one measurement that decides what the three numbers are *for*

Because the rule is an average, **the score is scale-free in distance**: a point
100 units from a lone friendly character scores exactly what a point one unit
away scores, since in both cases that character is the whole of the neighbourhood
being averaged over. Distance decides *which* neighbours are heard and how loudly
against each other; it does not decide whether anybody is heard at all.

That is not a defect in the arithmetic — it is what "distance-weighted average"
means — and it fixes the job of each constant:

| constant | what it actually does |
|---|---|
| radius | gives territory an edge, because nothing else does |
| temperature | decides whose opinion wins inside that edge |
| threshold | decides how favourable a neighbourhood has to be |

Each was then chosen against the measurement about the job it does.

## The world the numbers were measured on

`./run_scenario.sh` at its own seed and length — the run the project ships. Five
characters: two traded and came to like each other, two fought and one of them
fell, one walked away and met nobody.

```
   #1 Wren   level=2 status=2 carry=4 at (-476.1, 416.0)
   #2 Rook   level=2 status=2 carry=4 at (-478.0, 416.0)
   #4 Sable  level=3 status=3 carry=6 at (-424.5, 406.5)
   #5 Odo    level=1 status=1 carry=2 at (-484.0, 514.0)
   the graph: 2 edges, 10 happenings
     #1 -> #2 sentiment +0.1525
     #2 -> #1 sentiment +0.1525
     #3 -> #4 sentiment -0.5891  (#3 has fallen: this opinion has no say)
     #4 -> #3 sentiment -0.1405  (#3 has fallen: it can hold no ground)
```

The sampled ground is a stated grid: 41 × 41 = **1681 points**, 6 units apart,
240 × 240 world units centred on the meeting place.

## The proximity shape: softmin, because nearness has no working length scale

Two shapes were measured and only two — softmin $e^{-d/T}$ and nearness
$1/(1 + (d/T)^2)$. Swept with no radius at all, so the radius could not confound
the temperature:

| shape | $T$ | held | probe | kept | p50 | p90 | max |
|---|---|---|---|---|---|---|---|
| softmin | 3 | 41.5% | 0.1525 | 100.0% | 0.0005 | 0.1525 | 0.1525 |
| softmin | 6 | 43.0% | 0.1525 | 100.0% | 0.0080 | 0.1524 | 0.1525 |
| softmin | 12 | 44.4% | 0.1497 | 98.1% | 0.0279 | 0.1474 | 0.1500 |
| softmin | 24 | 48.4% | 0.1296 | 84.9% | 0.0474 | 0.1216 | 0.1303 |
| softmin | 48 | 54.4% | 0.0972 | 63.7% | 0.0546 | 0.0895 | 0.0977 |
| softmin | 96 | 60.5% | 0.0744 | 48.8% | 0.0551 | 0.0699 | 0.0746 |
| nearness | 3 | 51.3% | 0.1517 | 99.4% | 0.0515 | 0.0937 | 0.1512 |
| nearness | 6 | 51.3% | 0.1494 | 97.9% | 0.0515 | 0.0933 | 0.1491 |
| nearness | 12 | 51.3% | 0.1412 | 92.6% | 0.0517 | 0.0921 | 0.1416 |
| nearness | 24 | 52.5% | 0.1191 | 78.1% | 0.0522 | 0.0890 | 0.1221 |
| nearness | 48 | 54.8% | 0.0863 | 56.6% | 0.0539 | 0.0805 | 0.0935 |
| nearness | 96 | 62.0% | 0.0638 | 41.8% | 0.0548 | 0.0685 | 0.0711 |

*held* is the share of the grid with an owner; *probe* is the top score on the
ground the two who traded stand on; *kept* is that as a share of the $+0.1525$
they actually feel.

**Nearness holds 51.3% of the ground at $T = 3$, at $T = 6$ and at $T = 12$** —
the same figure to a tenth of a percent across a fourfold change in the one
number that is supposed to be its length scale — and its median top score sits at
0.0515 at every temperature swept, which is to say half the grid is parked on the
threshold with no structure in it. Its polynomial tail is why: an entity at ten
times the scale still carries a hundredth of the weight of one standing on the
point, so the far crowd never stops deciding and territory never gets an edge.

Softmin over the same span moves held ground from 41.5% to 44.4% and its median
top score from 0.0005 to 0.0279. A constant chosen by measurement needs a
measurement that responds to it, and only one of the two shapes has one. Neither
was invented beyond the two: the stop condition on this work allowed at most two
shapes and both sets of numbers are above whichever way it had come out.

## The temperature: 12, the warmest that does not dilute a claim at its strongest

The criterion, stated before the sweep: the widest neighbourhood a point can
average over while the ground somebody is actually standing on still scores what
its neighbours actually feel. At least 95% of it kept.

| $T$ | 3 | 6 | **12** | 24 | 48 | 96 |
|---|---|---|---|---|---|---|
| kept at the market | 100.0% | 100.0% | **98.1%** | 84.9% | 63.7% | 48.8% |

Twelve is the warmest that keeps 95%. At 24 a sixth of a claim has already been
averaged away by neighbours fifty units off; at 96 half of it has.

## The radius: 120, the smallest at which most ground is averaging

The criterion: section 6 asks for an **average**, and an average over one opinion
is not one. So the radius is the smallest at which most of the sampled ground
hears two entities or more, rather than being decided by whichever single
character happens to be nearest.

| $R$ | 20 | 40 | 60 | 90 | **120** | 180 | 240 |
|---|---|---|---|---|---|---|---|
| hears nobody | 93.9% | 77.6% | 57.6% | 30.6% | **7.3%** | 0.0% | 0.0% |
| hears exactly one | 4.2% | 14.2% | 23.6% | 26.5% | **15.5%** | 0.0% | 0.0% |
| hears two or more | 1.9% | 8.2% | 18.9% | 43.0% | **77.2%** | 100.0% | 100.0% |
| entities per point | 0.08 | 0.32 | 0.71 | 1.53 | **2.60** | 3.73 | 4.00 |
| held | 2.0% | 7.8% | 15.2% | 25.3% | **37.5%** | 44.5% | 44.4% |
| owner differs from unbounded | 43.4% | 39.1% | 30.7% | 19.4% | **7.3%** | 0.1% | 0.0% |

A hundred and twenty is the first radius over which the majority of ground is
averaging rather than looking up its nearest neighbour, and the last at which any
ground is out of earshot at all: the shipped run is four characters spread over
about a hundred units, and at 180 every point on the grid hears all four, which
is a world without distance in it.

## The threshold: 0.05, what one honoured exchange between strangers earns

There is no valley in the data to put a threshold in. The top scores over the
grid are a gradient — deciles 0.0000, 0.0000, 0.0000, 0.0013, 0.0035, 0.0116,
0.0374, 0.0992, 0.1417, 0.1525, 0.1525 — and the widest gap between neighbouring
ones is 0.0028, which is nothing. So it is pinned from both ends by two numbers
the world itself hands over.

**From below**, it is what a single honoured exchange between two strangers
earns. `RelationshipGraph` moves familiarity by `MET` and trust by `TRADE_TRUST`
on one trade, so the sentiment that comes of it is $0.25 \times 0.20 = 0.05$.
Ground is yours when the neighbourhood, on balance, favours you by at least as
much as one completed dealing — the least anybody can actually have earned.
`tests/test_ownership.gd` fails if those two numbers ever part, so retuning what a
trade is worth cannot leave the threshold defended by a sentence that stopped
being true.

**From above**, the strongest claim the shipped run reaches anywhere is 0.1497,
on the ground the two who traded are standing on. A threshold over that owns
nothing, ever, on a world that plays the way this one does. 0.05 clears it
threefold.

| threshold | 0.005 | 0.01 | 0.02 | **0.05** | 0.10 | 0.15 | 0.20 | 0.30 |
|---|---|---|---|---|---|---|---|---|
| **neutral** | 42.8% | 48.4% | 54.6% | **62.5%** | 70.1% | 89.3% | 100.0% | 100.0% |
| held | 57.2% | 51.6% | 45.4% | **37.5%** | 29.9% | 10.7% | 0.0% | 0.0% |
| owners | 2 | 2 | 2 | **2** | 2 | 2 | 0 | 0 |

**At the chosen threshold, 62.5% of the sampled ground comes out neutral**, and
37.5% is held between two claimants.

## Status and level both enter, and each moves ownership on its own

The same run, four times. Rook's sheet is changed *after* the run and *before* the
question, so the world's history is identical in all four and exactly one number
differs at the moment of asking. Standing is pinned in the level row, because an
unassigned status tracks the level and would otherwise move with it.

| run | level | status | carry | probe | cells held | neutral |
|---|---|---|---|---|---|---|
| shipped | 2 | 2 | 4 | 0.1497 | #1: 499, #2: 131 | 62.5% |
| status +4 | 2 | 6 | 8 | 0.1511 | #1: 691, #2: 5 | 58.6% |
| level +4 | 6 | 2 | 8 | 0.1511 | #1: 691, #2: 5 | 58.6% |
| both +4 | 6 | 6 | 12 | 0.1516 | #1: 740, #2: 4 | 55.7% |

Raising Rook's standing alone, and raising Rook's level alone, each take Wren's
territory from 499 to 691 of the 1681 sampled points and each cut neutral ground
by four points of a percent. They move it by the same amount, because section 6
adds the two, and raising both moves it further still. That is the design's
non-transitive claim made mechanical: winning battles and winning hearts are two
separate ways of shifting the same map.

The suite proves the same thing again on a world small enough to check by hand,
and proves the corollary section 2 gives for free: with no assigned standing, the
status tracks the level, so levelling up alone raises a character's weight twice
over.

## What the rule reads, and what it may not

Relationship edges, through `RelationshipGraph.sentiment()` and `.knows()`;
character sheets, for a status and a level; and where the entities are, which is a
position and not an event. That is all of it.

`tests/test_ownership.gd` scans the code of `sim/ownership_field.gd` and
`sim/ownership_claim.gd` — comments stripped, string literals kept — for every
word that would mean the rule knows what a fight, a conversation, a quest, a
check, a goal, an item or an engine is, and fails if one appears. The scan is run
against a deliberately broken control line and required to find four words in it,
so an empty result over the two real files means the scan looked. Every *writing*
method on the graph is in the forbidden list too, so "it does not change
sentiment" is the same check; and the suite separately samples 400 points and
asserts the graph's fingerprint and every sheet's numbers are unchanged.

The reason is not tidiness. Sentiment is moved by `RelationshipGraph`, out of the
world's own record of what happened. A rule that reached past the graph to the
events would be a second opinion about what those events meant, and there is one.

Somebody no longer standing is not in the cast, so it neither votes nor holds
ground — which is how the fallen stop holding territory without this file knowing
what falling is. The shipped run shows it: Bram fell in the quarrel, and Sable's
$-0.1405$ toward it and its own $-0.5891$ toward Sable both count for nothing.

## What it costs

Stated rather than assumed, and the count is separated from the clock because
nothing under `sim/` may read one:

* **4.00 entities looked at per point** — the whole standing cast, once, to find
  who is near.
* **2.60 near enough to have a say on average**, 4 at the most. The near ones are
  read twice: once for their weight, once per claimant for their opinion.
* **1681 points in 27.3 ms — 16.3 µs a point**, headless, timed by
  `bin/ownership_main.gd` from outside the simulation.

`./run_ownership.sh` reads no clock at all, so it prints identical bytes across
two processes (sha256 `4257d3d0…`, twice). `--cost` adds the timing as the last
line, after everything the report says.

## Determinism, fingerprints and layers

Headless and deterministic per seed throughout. The world's own fingerprints are
unmoved by this work, because this work only reads:

| run | before | after |
|---|---|---|
| `./run_headless.sh` seed 1234, tick 50 | `d20ae8129e075741` | `d20ae8129e075741` |
| `./run_headless.sh` seed 1234, tick 100 | `32656f55cc5eeb1c` | `32656f55cc5eeb1c` |
| `./run_scenario.sh` seed 1234, 160 ticks | `0a52522bc69b952e` | `0a52522bc69b952e` |

`./run_tests.sh` — all 56 suites pass, 200 184 checks, of which the new ownership
suite is 55. `./run_tests.sh --layers-only` passes all four checks.

## What is deliberately not here

* **No new way to change sentiment.** This reads the graph and computes from it.
* **Nothing render-side.** A picture of ownership belongs to the readout item.
* **No sentiment diffusion, no alliances or pacts.** Both are `[REACH]` in the
  design.

Raw output in `reports/ownership-evidence.txt`.
