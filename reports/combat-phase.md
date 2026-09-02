# The tactical layer: a fight, and what the combat phase settled

This project is a fantasy world simulator you walk around in real time. When two
fighters come close enough, the ground under them is read as a chess-like board, a
turn-based match is played on it, and the survivors are set back down and walk on.
That freeze and melt is the **snap**; it now runs end to end.

A **commander** is a character — you, or a villager driven by a language model —
and it is the king: when it dies, every **minion** it owns (its chess-piece units)
leaves too. A **cell** is one square, $s = 3.0$ world units across, centred at
$((i+\tfrac12)s,\ (j+\tfrac12)s)$ in the world's own frame, so a patch of ground
gives the same board whoever asks and wherever the fight began.

## The board, over real terrain

![A shoreline read as a board: pale squares over grass, amber along the water's edge, dark plates over the lake](reports/assets/combat-board-shore.png)

```
xvfb-run -a ./run_render.sh --seed 29 --start 196 182 --paused --board \
    --camera 0 30 38 --aim 3 \
    --screenshot "$PWD/reports/assets/combat-board-shore.png" --screenshot-frame 120
```

Pale squares are standable; dark plates are **holes** — water, a chasm, the void
under a floating island; amber squares are **cliff edges**, whose neighbour lies
more than $2.0$ world units below, and so the squares a shove kills from. Every
answer is forwarded to the rule that already decides where a walker may go, so
piece and walker climb alike.

## A fight, before, during and after

![Before: two commanders walking towards each other, nobody on a square](reports/assets/snap-before.png)

![During: the commanders adjacent, each on a cell centre](reports/assets/snap-during.png)

![After: the survivor walking east again](reports/assets/snap-after.png)

```
xvfb-run -a ./run_render.sh --seed 1234 --scenario encounter --board \
  --camera 0 20 15 --aim 0 --fov 42 --focus 25 \
  --screenshot "$PWD/reports/assets/snap-before.png" --screenshot-tick 13
```

with `--screenshot-tick 19` and `30` for the others; a *tick* is one step of the
simulation, and waiting for one rather than for a frame makes a capture
reproducible. At tick 13 nobody is on a square; at tick 19 everybody stands on a
cell centre; at tick 30 the survivor has walked $5.4$ units off its last cell and
the lattice has not moved, because it never does.

Everything within $24$ world units of the commander whose approach started the
fight joins, a minion only if its commander did, and the fight takes one turn per
world tick while that tick also streams the terrain and walks everyone else.

## What a turn buys

| a round | one turn per commander — two, three and five are played |
|---|---|
| the move | a step to any cell the commander's armour reaches |
| the weapon action | one attack, against every piece in its pattern |
| one minion | of *this* commander, one move or one capture |
| turning | free, unlimited, not one of the three |

The budget is enforced by refusal: a second move returns false and leaves the
commander where it stood.

## What a blow does

| attacker → target | rule | layer |
|---|---|---|
| minion → minion | binary capture: the target dies, the attacker takes its cell | tactical |
| minion → commander | $\lfloor P m/100 \rfloor - A$, the power $P$ scaling with its level | numeric |
| commander → minion | weapon damage against level-scaled minion health and defence | numeric |
| commander → commander | weapon damage against defence | numeric |

Every player-facing point comes out of one function,
$\text{dealt} = \max(1, \lfloor P m / 100 \rfloor - A)$ for a power $P$, a
modifier $m$ in hundredths, a defence $A$. Position sets $m$, and modifiers
multiply: high ground $\times 1.5$, a **flank** (from the target's side)
$\times 1.5$, a **backstab** (from behind) $\times 2$. Killing an equal commander
takes 13 sword blows from the front and 2 from behind and above: arithmetic, not a
rule, pushes a serious fight onto the chess layer.

## The shove

A shove is an attack whose push is more than zero. It goes straight away from the
attacker, and four clauses are asked of the cell being entered, in order — a hole
removes the target instantly; a drop deeper than $2.0$ units removes it; anything
solid, anyone standing there, or the board's edge stops it; plain ground takes one
step. **A push of $n$ cells is that rule applied $n$ times, once per cell
entered**: the target is walked a cell at a time and the four clauses asked afresh
at each, so it stops or dies at the first cell that stops or kills it, and the
outcome names the cell reached, not the cell aimed at.

It did not start that way. An independent check broke 25 of this layer's rules on
purpose to see which no test noticed; one of the six survivors was this shove,
which computed one far cell and checked only that. The phase fixed the rule rather
than narrow it to a push of one. Below: 68 hit points, pushed two cells.

| crossing | far-end check only | walked per cell |
|---|---|---|
| a chasm | $(1,1)$, 68/68 | **removed at $(1,2)$** |
| a building | $(5,1)$, 68/68 | **stopped at $(5,3)$** |
| an eight-unit pit | $(9,1)$, 68/68 | **removed at $(9,2)$** |
| a minion | $(11,1)$, 68/68 | **stopped at $(11,3)$** |

That check's other surviving finding is also closed. Two structural guarantees —
exactly one file deals damage, no combat file draws on a random number — were
checked against 14 filenames typed into a test, with nine combat files since
written outside it. That list is now a scan of the directory: all 52 files for the
damage seam, and for the randomness ban the 24 naming a combat class, since the
terrain is seeded-random by design.

## Verified, each re-run today

*Snapshot of the cycle this report was written in, kept as written. Three of its
rows have since moved for reasons recorded elsewhere: the suite and the two
mutation harnesses have grown, and `./run_encounter.sh` now reads
`over rounds=4 survivors=1` because the demo's weapons were put on the item power
budget — see `reports/encounter-item-backed.md`.*

| claim | command, and what it printed |
|---|---|
| every rule has a test that bites | `tools/piece_mutations.sh` catches 17 of 17 rules broken on purpose, `tools/resolution_mutations.sh` 41 of 41 |
| the project passes | `./run_tests.sh` — 23 suites, 172 949 checks |
| the fight layer names no art, the drawing layer no fight state | `./run_tests.sh --layers-only` — three checks pass |
| the world did not move | `./run_headless.sh --seed 1234 --ticks 100` — `a6aa8e5776ebfe8c`, its value before combat existed |
| a match is byte-identical in two processes | two `./run_match.sh` runs, both `sha256 8b4d427e…` |
| a fight runs inside a live world | `./run_encounter.sh` — snap-in at tick 16, `over rounds=3 survivors=1` |

## Where section 3 stands

Realised: the board over generated terrain including floating islands; the four
minions with their separate move and capture patterns; movement as the union of
what armour grants; weapon patterns rotating with facing; the turn economy for any
number of commanders with no fixed sides; the damage matrix; terrain and facing
multipliers; the shove; the king rule; the snap both ways.

Not realised: chess-engine minion play — moves in a live fight come from a dull
greedy rule that exists only so a fight ends; a human interface for choosing a
move; animation, since a piece jumps between cells.

## Decided here

* **A step and a jump are one rule**, so there are two kinds of movement grant and
  not three: a king's step and a knight's leap both ignore everything between start
  and landing. Found by breaking the code, not by reading it.
* **A cooldown is counted in rounds**: a commander's turn count and the round
  number were provably the same number.
* **A fight is anchored on the commander that triggered it**, not the midpoint
  between fighters: a board is told which storey it sits on by a height, and nobody
  stands at a midpoint, so over a floating island a midpoint names no storey.
* **One spatial representation** — the language-model layer's local terrain view,
  left open by the design, is a window onto this lattice.

## Deliberately left open

* **The roll and armour model.** The design offers a to-hit roll against an armour
  class, armour as flat damage reduction, or both. This layer implements reduction
  and is fully deterministic — no combat file names a random source. It
  waits because an item's power is its rarity times the level of whatever dropped
  it, split across movement, defence and effects: the items phase's arithmetic, and
  exactly what a dice model must be balanced against, so choosing now means
  choosing blind. A roll, if wanted later, is an edit to the one function above.
  Minion against minion stays deterministic permanently — not a deferral.
* **Original minions beyond the four**, which the design defers too.
* **What terrain is worth numerically** beyond the three multipliers above, and
  **line of sight**, which the board measures and no rule yet reads.
