# The dice question, settled: what an attack rolls, and what armour does

Section 13 of the design opens with a decision it did not make: whether a
player-facing attack rolls to hit, and whether armour is a to-hit class, flat
damage reduction, or both. The combat phase deliberately did not settle it
either, and said why — any roll model has to be balanced against the item
arithmetic, and the item arithmetic did not exist yet. It does now, so this is
where the decision gets made.

**This report is for a reader with no prior context.** Two terms recur and are
worth fixing first.

* The **tactical layer** is the chess-like part of a fight: one *minion*
  (a Toadstool, Cat, Ent or Frog — pawn, bishop, rook, knight) taking another.
  It is *binary*: the taken piece dies, whatever either one's level is. No
  number is read, so no number can be rolled.
* The **numeric layer** is everything a *commander* (a player or an NPC leader)
  is involved in: damage numbers, armour, hit points. This is the part that
  scales forever with level, and it is the only part any die was ever going to
  be allowed to touch.

---

## 1. The three options, and what each costs a plan

The design lists three and says it leans towards including rolls, with one
constraint written down: *dice variance trades away exact multi-step planning*.
That constraint is the whole of the decision, because the tactical layer exists
precisely to make multi-step plans the way a weaker player beats a stronger one.

So the right question is not "how much randomness feels good" but **what does
each option do to a deliberately planned two-move combination?**

| option | what it is | what it costs a planned $n$-move combination |
|---|---|---|
| (a) to-hit | an attack roll against an armour class; a miss deals nothing | the plan lands with probability $(1-p)^n$ for a single-blow miss chance $p$. **Nothing the planner can do changes this** — margin does not help, because a missed blow dealt nothing at all. |
| (b) armour as reduction | every attack lands; armour subtracts | the plan is never *cancelled*. If a die is put on the magnitude, the plan can be off by *how much*, which a planner can cover by leaving slack. |
| (c) both | a to-hit roll *and* reduction | carries (a)'s $(1-p)^n$ **and** adds (b)'s magnitude spread on top. Strictly worse for planning than either. |

The arithmetic of (a) is unforgiving. A two-move combination fails more often
than it succeeds as soon as

$$p > 1 - \tfrac{1}{\sqrt{2}} \approx 0.293$$

and ordinary d20 to-hit numbers sit well inside that. A roll needing 8 or more
on a d20 — a *generous* target — misses 35% of the time, so the two-move
combination the whole tactical layer exists to reward would land 42% of the
time:

| single-blow miss chance $p$ | 1 blow | 2 blows | 3 blows | 4 blows |
|---|---|---|---|---|
| 0.20 | 0.800 | 0.640 | 0.512 | 0.410 |
| 0.25 | 0.750 | 0.563 | 0.422 | 0.316 |
| **0.293** | 0.707 | **0.500** | 0.353 | 0.250 |
| 0.35 | 0.650 | **0.423** | 0.275 | 0.179 |
| 0.45 | 0.550 | 0.303 | 0.166 | 0.092 |

That is this task's own stop condition, reached on paper before a line was
written. Option (a) is out, and (c) with it.

### The second reason, which is the one only the items phase could see

Section 4 gives every item an **ability-score gate**: a high-level item
under-performs for a user whose relevant ability score is too low. That gate is
already implemented, and it is *continuous*:

$$v_{\text{eff}} = \left\lfloor v \cdot \frac{\min(A, L)}{L} \right\rfloor$$

where $A$ is the user's score and $L$ is the item's level. The design's own
example — "a high-INT staff rarely succeeds for a low-INT user" — is therefore
**already in the game**, expressed as a smaller number rather than as a miss
chance. A to-hit roll would have charged for the same thing a second time, on
top, and the only way to see that is to have the item arithmetic in front of
you. This is exactly why the combat phase handed the decision forward.

### What was chosen

> **Option (b): armour is flat damage reduction, every attack lands, and the die
> is on how hard a blow lands rather than on whether it lands.**

---

## 2. The model, in one function

The whole of it is `Damage.resolve()` in `sim/damage.gd`:

```
blow  = floor(power * multiplier / 100)
dealt = max(MINIMUM, round(blow * swing / 100) - defence)
```

* `multiplier` is the board's doing — high ground ×1.5, a flank ×1.5, a backstab
  ×2, and a backstab from high ground ×3, carried in hundredths so the whole
  layer stays integer arithmetic.
* `swing` is the die, in the same hundredths, centred on 100.
* `MINIMUM` is 1: a blow always takes at least a point off, which is what stops
  any level gap from making a commander unkillable.

Two steps rather than one, and the second rounds to **nearest**. That was not
the first attempt: folding the swing in beside the multiplier and flooring once
was tried, and the measurement in §4 caught it shaving about **0.45 points off
every landed blow in the game** — the die would have been a quiet across-the-board
nerf rather than a die. Rounding to nearest makes the mean land on the
deterministic number exactly.

Switching the die off is passing `STEADY` (a swing of exactly 100), at which the
second step is the identity and the arithmetic collapses, digit for digit, to
the deterministic function the combat phase shipped. **Every number in
`reports/combat.md` is still this arithmetic**, and the suite still asserts them
exactly.

### The die's size is derived, not chosen

The positional ladder is $100 < 150 < 200 < 300$. The die must not invert it:
the *worst* roll from a better position has to beat the *best* roll from a worse
one, or a player who did manoeuvre round the back would sometimes be punished
for it. For two rungs $m_1 < m_2$:

$$m_2 (100 - 2S) > m_1 (100 + 2S)$$

The tightest pair is the narrowest rung, $200/150$, giving $100 > 14S$, so
$S < 7.14$. A sweep over every width confirms it and adds the part the algebra
misses — that integer rounding eats a thin margin:

| `SWING` | band | spread | inverts the ladder? | strictly ordered from |
|---|---|---|---|---|
| 3 | [94, 106] | 1.128 | no | power 2 |
| **4** | **[92, 108]** | **1.174** | **no** | **power 2** ← shipped |
| 5 | [90, 110] | 1.222 | no | power 6 |
| 6 | [88, 112] | 1.273 | no | power 6 |
| 7 | [86, 114] | 1.326 | no | power 85 |
| 8 | [84, 116] | 1.381 | **YES — unusable** | never |

Seven is the largest width that never inverts the ladder; **four is the largest
under which a better position is strictly better at every blow of two points or
more**. Four is what ships. Rung by rung, for a 16-point blow with no armour:

| rung | worst roll of the better rung | best roll of the worse one | margin |
|---|---|---|---|
| ×100 → ×150 | 22 | 17 | +5 |
| ×150 → ×200 | 29 | 26 | +3 |
| ×200 → ×300 | 44 | 35 | +9 |

The die is two dice of nine faces, summed, so the distribution is triangular:
a blow lands near its plain number far more often than at either extreme. One
flat die of the same width would have spent the same spread much worse.

### Where the roll comes from

Not from a stream. A stream's numbers depend on how many were drawn before them,
so a blow's roll would depend on how many *other* blows had been struck first,
and resolving the same blow in a different order would give a different answer.
Instead the roll is **hashed from the blow** — the fight's seed, who threw it, at
whom, from where, against how much health, with how much power — which is the
discipline `sim/item_drop.gd` already follows. Two processes therefore agree
without having had to execute the same history.

A fight's seed is the world's seed folded with where on the map the fight is
standing, so two fights in one world roll differently and replaying one rolls the
same numbers again.

---

## 3. What it touched, and what it did not

`reports/combat.md` predicted that adding a roll would be an edit to
`Damage.resolve()` and to nothing else. That was **almost** right, and here is
the exact accounting.

| file | what changed | why it had to |
|---|---|---|
| `sim/damage.gd` | the whole model: `resolve()`, `swing_for()`, `fight_seed_for()`, the constants | the decision itself |
| `sim/combat_resolution.gd` | one extra `fight_seed` parameter, carried down to the seam | a roll needs to know *which fight* it is in, and the seam takes only numbers |
| `sim/combat_match.gd` | holds `fight_seed`, passes it on, writes one `dice` line at the head of the transcript | a fight is where a seed belongs |
| `sim/encounter.gd` | derives the fight's seed from the world's and the anchor position | the only place that knows what world a fight is in |
| `sim/scripted_match.gd` | names the seed the hand-written demonstration match is played at | so the die is shown doing its work against fixed decisions |

**The prediction was right about the arithmetic and wrong about the plumbing.**
Not one of the four extra files decides anything about the die: they carry one
integer. Nothing outside `sim/damage.gd` draws a random number, chooses a
distribution, or branches on a roll — and that is enforced by the source scan
rather than promised (§5).

The minion layer was not touched at all, and structurally could not have been:
`CombatResolution.capture()` never reaches the seam, so there is nowhere for a
seed to enter it.

---

## 4. The cost of the variance, measured

Everything below is counted, not asserted:
`./tools/measure_dice.sh` → [`reports/dice-evidence.txt`](dice-evidence.txt).

### The die is what it says it is

200,000 blows:

| | min | max | mean | sd |
|---|---|---|---|---|
| measured | 92 | 108 | 99.9943 | 3.6498 |
| intended | 92 | 108 | 100 | 3.6515 |

with the per-face shares matching the triangular ideal to within 0.0014
throughout.

### The die costs nothing on average

| power | × | defence | deterministic | mean over 20,000 fights | ratio |
|---|---|---|---|---|---|
| 3 | 100 | 0 | 3 | 3.0000 | 1.0000 |
| 8 | 100 | 2 | 6 | 6.0001 | 1.0000 |
| 16 | 100 | 2 | 14 | 14.0051 | 1.0004 |
| 16 | 150 | 2 | 22 | 22.0066 | 1.0003 |
| 16 | 200 | 8 | 24 | 24.0166 | 1.0007 |
| 16 | 300 | 8 | 40 | 40.0196 | 1.0005 |
| 40 | 100 | 8 | 32 | 32.0033 | 1.0001 |
| 3 | 100 | 100 | 1 | 1.0000 | 1.0000 |

This table is the one that caught the first implementation, whose ratios ran
0.85 to 0.99.

### The same match, replayed 400 times

The project's hand-written three-commander match is 44 fixed decisions on a
fixed board. Replayed under 400 different fight seeds:

* **400 of 400 fights reached the same conclusion** — `over rounds=6 survivors=1
  winner=#1`. The die changed the story in none of them.
* 2,400 blows compared against the same match with the die switched off: **34
  landed for a different number (1.4%)**, averaging 0.014 points off per blow,
  worst single blow off by 1.

That low figure is honest rather than flattering: the blows in that match are
3–4 points each, and a ±8% die on a 3-point blow rounds back to 3 most of the
time. **The die's effect scales with the blow** — invisible on chip damage,
material on real hits, which is the next measurement.

### One deliberately planned two-move combination, 20,000 times

The plan: a level-8 commander has manoeuvred behind a level-8 commander wearing
a full armoured suit, and lands a cut and then a cleave, both backstabs, over
two turns. Nothing about the positioning is in doubt. With the die off the two
blows come to **12 + 24 = 36 points**.

| | min | max | mean | sd | deterministic |
|---|---|---|---|---|---|
| two-blow total | 31 | 41 | 35.998 | 1.460 | 36 |

a spread of −13.9% to +13.9%, concentrated hard in the middle (25.8% of fights
land on exactly 36; 69% land within one point of it).

Whether the plan *works* depends on how much slack the planner left:

| margin the planner left | target's hit points | plans that killed | share |
|---|---|---|---|
| −2 | 38 | 3,119 | 0.156 |
| −1 | 37 | 7,400 | 0.370 |
| **0** (exact to the point) | 36 | **12,598** | **0.630** |
| 1 | 35 | 16,901 | 0.845 |
| 2 | 34 | 19,154 | 0.958 |
| 3 | 33 | 19,908 | 0.995 |
| 5 | 31 | 20,000 | 1.000 |

**The stop condition did not fire.** A two-move combination planned exactly to
the point still succeeds 63% of the time — more often than it fails — and one
point of slack takes it to 85%, two points to 96%, five points to certainty.

That last column is the whole argument for option (b) in one place. Under a
to-hit model, no amount of slack would have moved those numbers at all: the plan
would have landed $(1-p)^2$ of the time no matter how much margin the planner
built in. Here, **margin buys certainty**, which is what makes a plan a plan.

---

## 5. What stops this drifting

Four structural checks read the sources rather than trusting the arrangement.

1. **One seam.** Exactly one file under `sim/` calls `Damage.resolve()`, exactly
   once. Unchanged from the combat phase.
2. **One roll site.** Exactly one file under `sim/` calls `Damage.swing_for()`,
   exactly once — a second roll site would be a second model.
3. **One permitted random source.** No file of the combat layer names a random
   source *except* `sim/damage.gd`, and `sim/damage.gd` must name one, or the
   exception would be excusing nothing. Before this phase the rule was "none at
   all"; it is now "exactly one, and it is the file the model lives in", which is
   checked in both directions.
4. **No streams anywhere, including the permitted file.** `SimRng.new(`,
   `next_u32(`, `fork(` and the rest are forbidden across the whole combat
   layer. The die must be a hash of the blow, and this is what stops anyone
   quietly swapping one for the other.

Plus the boundary the task set, checked behaviourally as well as structurally:
the same minion capture played under 200 different fight seeds produces one
outcome, written the same way every time, and the body of `capture()` contains
no mention of a swing, a seed, a health or a level.

### Mutation coverage

`./tools/resolution_mutations.sh` breaks one rule of `sim/` at a time and
requires the suite to notice. It went from 46 mutations to 61 — **15 new ones for
the die**, and three existing ones rewritten onto the new arithmetic. All 61 were
caught ([evidence](dice-mutations-evidence.txt)), as were all 19 of
`./tools/piece_mutations.sh` ([evidence](dice-piece-mutations-evidence.txt)); the
two were run sequentially with nothing else touching the repository. The new
ones include:
applying the die to what got past the armour instead of to the blow; rounding
down instead of to nearest; making a low roll deal nothing (which is option (a),
smuggled in); widening the die past the ladder's bound; collapsing two dice to
one; dropping the fight seed, the target's health, or the blow's position from
the hash; letting a fight with no seed roll anyway; drawing from a stream instead
of hashing; rolling the die in a second file; letting a roll decide a minion
capture; and hiding the swing from the transcript.

One of those — *applying the die to what got past the armour rather than to the
blow* — **survived the first run**, and the fix was a test rather than a change
to the code. The two models only diverge when armour is a large fraction of the
blow: a 40-point blow against 30 points of armour deals 7 to 13 under the model
that ships, and 9 to 11 under the alternative. So **armour does not damp the
die**, which is the same principle the multiplier already followed — modifiers
apply to the attack, not to the result — and it is now asserted.

---

## 6. What is still deterministic, permanently

* Minion against minion: binary capture, level-blind, no die, forever.
* Every number in `reports/combat.md`: still the arithmetic, reachable by
  passing `STEADY`.
* The world: reproducible per seed as it always was. A fight's rolls are a
  function of the world seed and where the fight stands, so the same seed
  replays the same fight.

### Reproducibility, shown with the die in play

| what | how | result |
|---|---|---|
| the hand-written match, two processes | `./run_match.sh` twice, compared byte for byte inside the suite | identical; the transcript's head reads `dice seed=1234 swing=92..108` and every blow carries its `swing=` |
| a fight in the generated world, two processes | `./run_encounter.sh` twice, `cmp` | identical ([transcript](dice-encounter-evidence.txt)); the fight's own seed, `4244964848`, is the world's folded with where it stands |
| the world itself did not move | `./run_headless.sh --seed 1234 --ticks 100` → `d4e31b0904ff45c0` | unchanged. The world fingerprint folds in combatants only when the roster is non-empty, and a plain headless run never musters any, so nothing in this task could reach it |
| every suite | `./run_tests.sh` | 28 suites, 191,250 checks, all passing |

## 7. Files

| | |
|---|---|
| the model | [`sim/damage.gd`](../sim/damage.gd) |
| the plumbing | [`sim/combat_resolution.gd`](../sim/combat_resolution.gd), [`sim/combat_match.gd`](../sim/combat_match.gd), [`sim/encounter.gd`](../sim/encounter.gd), [`sim/scripted_match.gd`](../sim/scripted_match.gd) |
| the checks | [`tests/test_combat_resolution.gd`](../tests/test_combat_resolution.gd) |
| the measurement | [`tools/measure_dice.gd`](../tools/measure_dice.gd), `./tools/measure_dice.sh` → [`reports/dice-evidence.txt`](dice-evidence.txt) |
| the mutation harnesses | [`tools/resolution_mutations.sh`](../tools/resolution_mutations.sh), [`tools/piece_mutations.sh`](../tools/piece_mutations.sh) |
