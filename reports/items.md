# One item, one power budget: rarity, level, and the movement-against-defence trade

The first layer of the items phase, and the one everything else in section 4
stands on. A weapon and a piece of armour are **the same class** here, carrying
an item level, one of six rarity tiers, and a single pool of power divided across
movement, defence and effects — so that mobility and protection are two ways of
spending one thing rather than two separate stats that happen to sit on the same
object.

Nothing here knows how items are dropped, what a creature carries, or how
difficulty rises with distance. It also names no class of the combat layer at
all: not the pieces, not the board, not the damage seam. Both of those are
[checked by reading `sim/`](#what-is-checked), not asserted here.

---

## The shape of it

Six files under `sim/`, and one entry point that prints every number below.

| file | what it is |
|---|---|
| `ability.gd` | the six ability scores, as a vocabulary and nothing else |
| `item_rarity.gd` | the six tiers, their multipliers, and how many effects each allows |
| `item_budget.gd` | $P = r \times L$, and the rule that spends it without losing a point |
| `item_effect.gd` | one effect, and the slice of the budget that bought it |
| `item.gd` | the item: level, rarity, three axes, and the ability-score gate |
| `item_forge.gd` | seed + source → item, deterministically. The only file that draws |

Reproduce every table below with:

```
./run_items.sh
```

---

## The budget

Section 4 gives one formula for every item in the game:

$$P = r(\text{rarity}) \times L_{\text{source}}$$

$L_{\text{source}}$ is the level of the creature that dropped the item, and it
*is* the item's level — one number, not two. The budget multiplies it; the
ability gate below divides by it. There is nothing else an item's level is for,
and nothing else the budget is built from.

| tier | $r$ | against common | $P$ at $L=8$ |
|---|---|---|---|
| common | 4 | 1.00× | 32 |
| uncommon | 6 | 1.50× | 48 |
| rare | 9 | 2.25× | 72 |
| legendary | 14 | 3.50× | 112 |
| mythic | 21 | 5.25× | 168 |
| eternal | 32 | 8.00× | 256 |

Each tier is about half again the one below, so eternal is **eight** times common
— not eighty, and the difference matters. A common item from a level-16 creature
and an eternal from a level-2 one are both worth exactly 64. Rarity is therefore
a shortcut through the level gradient and never a replacement for it, which is
what keeps section 5's "your gear budget is capped by what you have killed" true
in the face of a lucky drop.

### The budget is spent, not referenced

$$P = \text{movement} + \text{defence} + \text{effects}$$

exactly, in integers, on every item. Sixty forged items, at levels 1–12,
alternating a worn piece and a held one; the last column is $P - \text{sum}$.

| # | rarity | kind | slot | $L$ | $P$ | mov | def | eff | sum | $P-$sum |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | common | armour | helmet | 1 | 4 | 2 | 1 | 1 | 4 | 0 |
| 1 | common | weapon | hand | 2 | 8 | 1 | 1 | 6 | 8 | 0 |
| 2 | rare | armour | leggings | 3 | 27 | 16 | 6 | 5 | 27 | 0 |
| 3 | common | weapon | hand | 4 | 16 | 3 | 3 | 10 | 16 | 0 |
| 4 | common | armour | chestplate | 5 | 20 | 16 | 3 | 1 | 20 | 0 |
| 5 | common | weapon | hand | 6 | 24 | 2 | 1 | 21 | 24 | 0 |
| 6 | common | armour | boots | 7 | 28 | 15 | 7 | 6 | 28 | 0 |
| 7 | rare | weapon | hand | 8 | 72 | 7 | 12 | 53 | 72 | 0 |
| 8 | common | armour | chestplate | 9 | 36 | 0 | 28 | 8 | 36 | 0 |
| 9 | uncommon | weapon | hand | 10 | 60 | 2 | 20 | 38 | 60 | 0 |
| 10 | rare | armour | leggings | 11 | 99 | 14 | 79 | 6 | 99 | 0 |
| 11 | uncommon | weapon | hand | 12 | 72 | 3 | 19 | 50 | 72 | 0 |
| 12 | common | armour | helmet | 1 | 4 | 3 | 1 | 0 | 4 | 0 |
| 13 | common | weapon | hand | 2 | 8 | 1 | 0 | 7 | 8 | 0 |
| 14 | common | armour | boots | 3 | 12 | 3 | 6 | 3 | 12 | 0 |
| 15 | common | weapon | hand | 4 | 16 | 0 | 2 | 14 | 16 | 0 |
| 16 | uncommon | armour | leggings | 5 | 30 | 11 | 14 | 5 | 30 | 0 |
| 17 | legendary | weapon | hand | 6 | 84 | 19 | 19 | 46 | 84 | 0 |
| 18 | common | armour | boots | 7 | 28 | 11 | 9 | 8 | 28 | 0 |
| 19 | mythic | weapon | hand | 8 | 168 | 8 | 22 | 138 | 168 | 0 |
| 20 | common | armour | boots | 9 | 36 | 8 | 17 | 11 | 36 | 0 |
| 21 | legendary | weapon | hand | 10 | 140 | 3 | 11 | 126 | 140 | 0 |
| 22 | uncommon | armour | helmet | 11 | 66 | 41 | 13 | 12 | 66 | 0 |
| 23 | mythic | weapon | hand | 12 | 252 | 15 | 63 | 174 | 252 | 0 |
| 24 | common | armour | boots | 1 | 4 | 3 | 0 | 1 | 4 | 0 |
| 25 | rare | weapon | hand | 2 | 18 | 3 | 4 | 11 | 18 | 0 |
| 26 | legendary | armour | leggings | 3 | 42 | 21 | 18 | 3 | 42 | 0 |
| 27 | uncommon | weapon | hand | 4 | 24 | 2 | 7 | 15 | 24 | 0 |
| 28 | common | armour | boots | 5 | 20 | 18 | 1 | 1 | 20 | 0 |
| 29 | uncommon | weapon | hand | 6 | 36 | 5 | 9 | 22 | 36 | 0 |
| 30 | common | armour | leggings | 7 | 28 | 13 | 7 | 8 | 28 | 0 |
| 31 | common | weapon | hand | 8 | 32 | 5 | 6 | 21 | 32 | 0 |
| 32 | legendary | armour | leggings | 9 | 126 | 106 | 16 | 4 | 126 | 0 |
| 33 | common | weapon | hand | 10 | 40 | 2 | 2 | 36 | 40 | 0 |
| 34 | mythic | armour | chestplate | 11 | 231 | 5 | 157 | 69 | 231 | 0 |
| 35 | common | weapon | hand | 12 | 48 | 9 | 3 | 36 | 48 | 0 |
| 36 | rare | armour | helmet | 1 | 9 | 1 | 6 | 2 | 9 | 0 |
| 37 | common | weapon | hand | 2 | 8 | 1 | 2 | 5 | 8 | 0 |
| 38 | common | armour | leggings | 3 | 12 | 3 | 7 | 2 | 12 | 0 |
| 39 | uncommon | weapon | hand | 4 | 24 | 1 | 7 | 16 | 24 | 0 |
| 40 | uncommon | armour | chestplate | 5 | 30 | 5 | 16 | 9 | 30 | 0 |
| 41 | uncommon | weapon | hand | 6 | 36 | 10 | 1 | 25 | 36 | 0 |
| 42 | legendary | armour | leggings | 7 | 98 | 33 | 65 | 0 | 98 | 0 |
| 43 | rare | weapon | hand | 8 | 72 | 17 | 4 | 51 | 72 | 0 |
| 44 | common | armour | chestplate | 9 | 36 | 18 | 17 | 1 | 36 | 0 |
| 45 | common | weapon | hand | 10 | 40 | 10 | 6 | 24 | 40 | 0 |
| 46 | common | armour | helmet | 11 | 44 | 3 | 31 | 10 | 44 | 0 |
| 47 | uncommon | weapon | hand | 12 | 72 | 19 | 3 | 50 | 72 | 0 |
| 48 | uncommon | armour | boots | 1 | 6 | 3 | 2 | 1 | 6 | 0 |
| 49 | common | weapon | hand | 2 | 8 | 1 | 1 | 6 | 8 | 0 |
| 50 | rare | armour | chestplate | 3 | 27 | 13 | 13 | 1 | 27 | 0 |
| 51 | uncommon | weapon | hand | 4 | 24 | 7 | 1 | 16 | 24 | 0 |
| 52 | mythic | armour | helmet | 5 | 105 | 50 | 34 | 21 | 105 | 0 |
| 53 | uncommon | weapon | hand | 6 | 36 | 0 | 9 | 27 | 36 | 0 |
| 54 | legendary | armour | boots | 7 | 98 | 46 | 28 | 24 | 98 | 0 |
| 55 | common | weapon | hand | 8 | 32 | 4 | 3 | 25 | 32 | 0 |
| 56 | uncommon | armour | boots | 9 | 54 | 29 | 11 | 14 | 54 | 0 |
| 57 | common | weapon | hand | 10 | 40 | 2 | 8 | 30 | 40 | 0 |
| 58 | common | armour | boots | 11 | 44 | 5 | 38 | 1 | 44 | 0 |
| 59 | common | weapon | hand | 12 | 48 | 2 | 12 | 34 | 48 | 0 |

**60 of 60 spend their budget to the point.** The suite goes further and checks
the arithmetic itself rather than a sample of it: every budget from 0 to 300
against ten different shapes — 3 010 splits — sums to its budget exactly, with no
axis ever below zero.

---

## The rounding rule, and where the remainder goes

The task's stop condition asks that if the three-way split cannot hold exactly
under integer arithmetic, the rounding rule and the destination of the remainder
be stated rather than left to drift. **The split does hold exactly**, and this is
the rule that makes it:

An item is shaped by three integer weights — how much of itself it wants to be
movement, defence and effects. Those weights almost never divide $P$ evenly, so
the **largest-remainder** method is used:

1. each axis takes $\lfloor P w_i / W \rfloor$, where $W = \sum_j w_j$;
2. that leaves $P - \sum_i \lfloor P w_i / W \rfloor$ points over, which is always
   fewer points than there are axes — **at most two**;
3. each leftover point goes to the axis whose discarded fraction was largest, and
   a tie goes to the earlier axis in the fixed order *movement, defence,
   effects*.

The remainder therefore lands on the axis that was rounded down hardest, and
never off the item. That the sum is exactly $P$ is not luck: $\sum_i P w_i = PW$,
so the discarded remainders sum to a multiple of $W$, so step 2's leftover is
exactly $\left(\sum_i P w_i \bmod W\right)/W$ and step 3 hands out precisely that
many points.

Worked, on the item the gate section uses below: 72 across weights 30/45/25 gives
floors of 21, 32 and 18 with remainders 60, 40 and 0. That is 71 spent, and the
one point left goes to movement — the hardest-rounded axis — for
$22 + 32 + 18 = 72$.

**The rule is shown to be doing work rather than assumed to be.** Replacing it
with a plain floor and no remainder pass loses points on 1 073 of the same 1 204
splits, and disagrees with the rule on exactly those 1 073; on the worked case
above it gives 71 and not 72.

The same rule runs once more, one level down, to divide the effects axis among an
item's individual effects — so those also sum to the effects axis exactly, for
the same reason and by the same code.

---

## The trade, measured

Effects take a share off the top, and **everything else on the item is one number
cut two ways**: a point of movement is a point of defence not taken. There is no
second source of either.

Measured over 400 forged worn items at source level 8, keeping the 194 that came
out common — that is, at the identical budget $P = 32$ — the Pearson correlation
between the movement axis and the defence axis is

$$r(\text{movement}, \text{defence}) = -0.9382$$

The same items in five equal bands by movement:

| band | n | movement range | mean movement | mean defence | mean effects |
|---|---|---|---|---|---|
| 0 | 38 | 0–4 | 1.45 | 24.95 | 5.61 |
| 1 | 39 | 4–10 | 7.26 | 19.36 | 5.38 |
| 2 | 39 | 10–15 | 12.67 | 13.74 | 5.59 |
| 3 | 39 | 15–21 | 17.92 | 9.15 | 4.92 |
| 4 | 39 | 21–32 | 24.54 | 3.85 | 3.62 |

Mean defence falls across every band as mean movement rises: the most mobile
fifth of items at this budget average **3.85** defence against the least mobile
fifth's **24.95**.

**The measurement is shown to be about the shared budget and not about the
generator's taste.** Drop the equal-budget filter and run the identical
correlation over all 400 worn items, whose budgets differ:
$r = -0.0586$ — all but gone, because a bigger budget lifts both axes at once.
The trade is a consequence of the budget being one pool, and it disappears the
moment the pool stops being shared.

### The same two numbers, drawn

![Left: 194 worn items that all came out at budget 32, movement against defence, sitting under the line movement + defence = 32 because effects took the rest, r = -0.9382. Right: the same 400 worn items with the equal-budget filter dropped, r = -0.0586.](reports/assets/item-trade.png)

Both panels are the same generator on the same seed, and the only difference
between them is the equal-budget filter. On the left the points fill a triangle
under $\text{movement} + \text{defence} = 32$ and nothing sits above it, which is
the budget being one pool seen directly rather than through a correlation. On the
right the same items with their budgets allowed to differ scatter into a cloud
with no trade in it at all.

```
./tools/item_trade_dump.sh > reports/assets/item-trade.csv
python3 tools/plot_item_trade.py
```

The dump uses the same seed, the same batches and the same filter as the trade
table above, so the correlations recomputed from the 800 rows of the CSV are the
four `./run_items.sh` prints, to the digit.

Held items at the same budget give $r = -0.4534$: weaker, and legitimately so.
A held item spends 55–90% of itself on effects, so the number left for movement
and defence to fight over is both small and variable, and the fight is
correspondingly noisier. That is the design's own asymmetry — a worn item *is*
mostly how it moves and what it stops — showing up in the measurement.

---

## The ability-score gate

Section 4: a high-level item under-performs for a user whose relevant ability
score is too low. The rule, applied wherever a value is read off an item:

$$v_{\text{effective}} = \left\lfloor \frac{v \cdot \min(A, L)}{L} \right\rfloor$$

where $A$ is the user's score in the ability the item names and $L$ is the item's
level. One integer division and not two, so there is no double rounding to argue
about. A user at or above the item's level reads every value in full; below it,
they read that fraction of **every** axis — movement, defence and effects alike.

The gate is on the *reading*, never on the item. Two characters holding the same
object read different numbers off it and the object is unchanged, which is what
lets it be traded, dropped and picked up by someone it suits better with nothing
recomputed.

### Worked through, in numbers

The acceptance's own example: a level-8 wisdom armour worn by someone with
wisdom 6.

```
rare armour chestplate L8 P=72 mov=22 def=32 eff=18 wis [warding:18] warding hauberk
```

Its budget is $r(\text{rare}) \times L = 9 \times 8 = 72$, spent
$22 + 32 + 18 = 72$. A wearer with wisdom 6 reaches
$q = \min(6, 8)/8 = \tfrac{3}{4}$ of it:

| wis | $q$ | movement | defence | effects | sum | $\lfloor P q \rfloor$ |
|---|---|---|---|---|---|---|
| 0 | 0% | 0 | 0 | 0 | 0 | 0 |
| 2 | 25% | 5 | 8 | 4 | 17 | 18 |
| 4 | 50% | 11 | 16 | 9 | 36 | 36 |
| **6** | **75%** | **16** | **24** | **13** | **53** | **54** |
| 7 | 87% | 19 | 28 | 15 | 62 | 63 |
| **8** | **100%** | **22** | **32** | **18** | **72** | **72** |
| 12 | 100% | 22 | 32 | 18 | 72 | 72 |

So the wisdom-6 wearer gets 24 defence out of the chestplate's 32 and 16 movement
out of its 22 — it is a level-8 item and they are not a level-8 wearer. At
wisdom 8 they read all of it, and above wisdom 8 they read no more: the gate
takes value from the unqualified, it does not hand extra to the overqualified.

**One rounding consequence, stated rather than smoothed away.** The last column
is the gate applied to the whole budget at once; the "sum" column is the three
axes gated separately, which is what actually happens because the gate is applied
where each value is read. Three floors cost at most two points against one, and
the difference never favours the reader. On this item it is one point at wisdom
6, and at most one point at every score.

---

## Determinism

An item is addressed by $(\text{seed}, \text{source})$ — the world's seed and a
text label for whatever it came off — and the label is folded into an independent
stream. Forging an item somewhere else in the world therefore cannot shift the
numbers this one sees, which is the property a world streamed in chunks needs and
a stream position could not give: the sixth item of a run is byte-identical to
the same item forged on its own.

Across processes: `./run_items.sh` is run twice as two separate subprocesses by
the suite and the two transcripts are compared byte for byte. They are identical,
and the comparison is shown to be able to tell two transcripts apart.

The draw order is fixed and written down in `sim/item_forge.gd`, because it is the
whole of what makes two runs agree — adding an eighth draw at the end leaves every
existing item unchanged, and inserting one in the middle does not.

---

## What is checked

`tests/test_items.gd`, 119 checks, every number written out by hand and compared
exactly. Every claim with a premise is paired with a run in which that premise is
broken: a point added to an axis behind the budget's back, the wearer's score
raised to the item's level, the equal-budget filter dropped, the
largest-remainder rule replaced with a plain floor, an unknown rarity name.

Structural checks read `sim/` rather than trusting the arrangement, and find the
layer's files by opening the directory:

* **the item layer names no class of the combat layer at all.** Not the pieces,
  not the board, not the resolution seam. So the item layer can be read, tested
  and changed on its own, and cannot quietly start deciding what a blow is worth.
* **and the naming goes one way.** The two layers do meet now — `sim/armour.gd`,
  `sim/weapon.gd`, `sim/commander.gd` and `sim/scripted_match.gd` read a budget, a
  gate and a rarity off this layer, which is what makes a loadout change what a
  commander may do. What survives that meeting is the *direction* of it, and the
  check requires both halves: at least one combat file names an item class, and no
  item file names a combat one. The item layer's own files are the ones that
  **declare** its class names, so mentioning `Item` does not make a file part of
  it. Added by [loadout.md](loadout.md).
* **exactly one file of the item layer draws a random number, and it is the
  forge.** A budget, a split, a gate and a description are arithmetic; if any of
  them could draw, "the same seed gives the same item" would be a property of how
  often they were called. This also keeps the item layer clear of the combat
  source scan's rule against a random source, since it shares no vocabulary with
  the files that scan covers.

Both scans are paired with a positive control — the same scan for a string that
*is* in every one of those files finds it in every one of them — so an empty
result means "not there" and not "the scan read nothing".

---

## What this layer deliberately does not do

* **No drops, no loot tables, no distance gradient** — *when this was written*.
  The forge is handed a level and a kind and returns one item; it is still never
  asked whether an item appears, which creature was carrying it, or how far from
  spawn that creature stood. All three questions are answered next door, by two
  files that read this layer and add nothing to it: see [drops.md](drops.md).
* **Nothing the combat layer reads had changed *when this was written*.** That is
  no longer true, and the sentence is kept rather than quietly rewritten because
  the next step is what changed it: `sim/armour.gd`'s `DEFENCE_PER_TIER` and
  `HIGH_TIER` are gone, and the fixed weapon damage numbers are now the weights by
  which a weapon divides the effects axis of the item behind it. The fight reads
  these budgets. See [loadout.md](loadout.md).
* **No class, no skill tree, no learned ability, not even as a placeholder.**
  `sim/ability.gd` is six strings and a validity test; it is not a character
  sheet, and there is no owner of an ability score anywhere in the project yet.
* **Effects are a name and a cost, not yet the composable base.** Section 4's
  unified effect base — melee, projectile, spell and action sharing one class,
  customised by damage, hitbox, movement and animation — is a larger thing and it
  is not here. What is here is the part the budget needs: an effect costs points,
  and the cost is real.

---

## How the items phase closed (added at the phase report, cycle 102)

This section is the detail behind the published phase report. It is appended
rather than folded in, so the account above stays what it was when written.

### What the independent review checked, and with what

The review (`W-items-review`) wrote its own probe, `tools/critic_items_probe.gd`,
rather than reading the five item reports, and ran it alongside the full suite,
the three structure checks, the four item entry points and both mutation
harnesses run sequentially. Full output: [items-review-evidence.txt](items-review-evidence.txt).

Seven of the milestone's eight acceptance lines held. Two things broke.

**1. Weapons with no item behind them, in shipped `sim/` code.** A `Weapon` could
be wielded as a bare catalogue shape, in which case `Weapon.power_for()` fell
back to the catalogue's own damage numbers. Five call sites in
`sim/scripted_encounter.gd` did exactly that.

| read | bare `Weapon.sword()` | `Weapon.held(sword(), 2)` |
|---|---|---|
| cut / cleave | 10 / 16 | 3 / 5 (budget 8) |
| cut, every ability score 0 | 10 | 0 |

The bare shape is worth 26 points of effects axis, which a common item needs a
level-7 source to buy — so a level-2 commander was carrying level-7 damage that
no budget paid for and no ability score gated.

Closed by `W-encounter-item-backed`. All five commanders now hold weapons forged
at their own level, and `tests/test_effects.gd` sweeps every file under `sim/`
for a line that names one weapon without `Weapon.held(`. The scan was shown
failing first, naming exactly those five lines, before anything moved. Two
deliberately broken controls check that the scan can both catch and acquit.

The demo fight is measurably different afterwards, which is the point:

| `./run_encounter.sh` | before | after |
|---|---|---|
| rounds | 3 | 4 |
| winner's remaining health | 14 / 32 | 5 / 32 |
| first blow dealt | 16 | 5 |

Full before/after: [encounter-item-backed-evidence.txt](encounter-item-backed-evidence.txt).

**2. An item that did not spend its whole budget.** `Item._spend_on_effects`
returned an empty list whenever it was handed no effect names, silently dropping
whatever `ItemBudget.split` had already assigned to the effects axis.

| legendary level-9 weapon, budget 126 | movement | defence | effects | carried | gap |
|---|---|---|---|---|---|
| weights `[0, 0, 100]`, no names — before | 0 | 0 | 0 | 0 | **126** |
| weights `[10, 10, 80]`, no names — before | 13 | 12 | 0 | 25 | **101** |
| weights `[0, 0, 100]`, no names — after | 0 | 0 | 126 | 126 | 0 |
| weights `[10, 10, 80]`, no names — after | 13 | 12 | 101 | 126 | 0 |

Closed by `W-item-budget-invariant`: a non-empty effects share with no names is
now carried as a single effect labelled with the item's own name, which is the
convention `Weapon.held` already used. Folding the share into defence instead was
rejected — the weights state *how* the item is divided, so folding would return a
shape nobody asked for and would corrupt the equal-budget movement-against-defence
correlation. The largest-remainder rule is untouched, and an item that genuinely
spent nothing on effects still lists none. Sweep after the change: 20 000 forged
items, 0 inexact, worst $|\text{gap}| = 0$.
Full before/after: [item-budget-hole-evidence.txt](item-budget-hole-evidence.txt).

### What was left open on purpose

`Item`'s three axes stay writable after construction, so exactness is a
guarantee of the constructors and not of the class — the review's B6 case. Making
them read-only would have forced edits to `tests/test_items.gd` and to the
review's own probe, both of which write an axis deliberately to show that
`spends_budget()` is a live report rather than a constant. `sim/item.gd` now
states the guarantee and whose job it is to keep it.

### Verified at the phase report

Run from the project root, one command at a time:

| command | result |
|---|---|
| `./run_tests.sh` | all 28 suites passed, 191 274 checks |
| `./run_tests.sh --layers-only` | layer check OK, combat check OK, asset check OK |
| `./run_headless.sh --seed 1234 --ticks 100` | `final=d4e31b0904ff45c0`, unchanged |

The unchanged world fingerprint is the standing check that the item layer never
reached world generation: item randomness is drawn from streams forked off the
world seed by name, so a stray draw shared with the world would move it.
