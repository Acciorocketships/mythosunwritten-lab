# Randomised items, per-item drops, and the frontier that stays ahead of your gear

The second layer of the items phase. The first one
([items.md](items.md)) built one item out of one budget; this one asks the two
questions that turn an item into a loot loop: **what does a creature carry**, and
**what does killing it leave behind** — and then answers, as a number rather than
as an intention, the promise section 5 makes about grinding.

Two new files under `sim/`, and neither of them knows what a fight is.

| file | what it is |
|---|---|
| `item_drop.gd` | one roll per carried item, kept about one time in five |
| `item_frontier.gd` | distance from spawn → level → what an item from there can be worth |

Reproduce every number below with:

```
./run_drops.sh
```

The full transcript of that command is [drops-evidence.txt](drops-evidence.txt).

---

## What the generator rolls

The forge was already there; what was missing was a picture of what it produces.
Over $2400$ rolls at source level $8$ — twelve hundred worn, twelve hundred held:

| tier | rolled | share | intended | $P$ at $L=8$ |
|---|---|---|---|---|
| common | 1213 | 50.54% | 50.00% | 32 |
| uncommon | 584 | 24.33% | 25.00% | 48 |
| rare | 313 | 13.04% | 13.00% | 72 |
| legendary | 174 | 7.25% | 7.00% | 112 |
| mythic | 97 | 4.04% | 4.00% | 168 |
| eternal | 19 | 0.79% | 1.00% | 256 |

The mean multiplier those weights imply is $\bar r = 6.81$, so the mean budget at
$L = 8$ should be $54.48$; it came out at $54.18$. Where that budget goes depends
entirely on what the item is:

| rolls | $n$ | mean $P$ | mean mov | mean def | mean eff | mov% | def% | eff% |
|---|---|---|---|---|---|---|---|---|
| worn | 1200 | 54.000 | 23.047 | 22.523 | 8.431 | 42.68 | 41.71 | 15.61 |
| held | 1200 | 54.360 | 7.295 | 8.002 | 39.063 | 13.42 | 14.72 | 71.86 |
| both | 2400 | 54.180 | 15.171 | 15.262 | 23.747 | 28.00 | 28.17 | 43.83 |

Worn gear spends about six sevenths of itself on movement and defence and splits
that almost evenly; held gear spends about five sevenths on effects. That is not
a rule written anywhere — it is the two effect bands in the forge (worn
$0$–$30\%$, held $55$–$90\%$) seen from the other end. All $2400$ rolls spend
their budget to the point, which is [items.md](items.md)'s claim re-checked on a
sample twenty times larger.

---

## One item in five

> *Drops: each of a defeated enemy's items drops with some probability (~20%
> each), not always.* — section 4

The rule is one constant, `ItemDrop.CHANCE_PERCENT = 20`, compared against a draw
in $[0, 99]$. So the intended rate is exactly $0.2$ by construction, and the only
open question is whether the generator delivers it:

| sample | rolls | fell | realised | intended | difference |
|---|---|---|---|---|---|
| gear forged per kill, 2000 kills | 10000 | 2000 | 0.2000 | 0.2 | $+0.0000$ |
| one fixed carry, 40000 further kills | 200000 | 40104 | 0.20052 | 0.2 | $+0.00052$ |

The wide sample's standard error is $\sqrt{0.2 \times 0.8 / 200000} = 0.0009$, so
$+0.00052$ is about six tenths of one standard error. The first row landing on
exactly $2000$ of $10000$ is luck, not construction; the two rows are reported
together so that neither has to carry the claim alone.

Each of the five places in a carried loadout comes out at the same rate
($0.2015$, $0.1990$, $0.2010$, $0.1945$, $0.2040$), and the number of items one
kill leaves follows the binomial it should:

| dropped | kills | share | $\binom{5}{k}0.2^k0.8^{5-k}$ |
|---|---|---|---|
| 0 | 638 | 0.3190 | 0.3277 |
| 1 | 845 | 0.4225 | 0.4096 |
| 2 | 403 | 0.2015 | 0.2048 |
| 3 | 107 | 0.0535 | 0.0512 |
| 4 | 7 | 0.0035 | 0.0064 |
| 5 | 0 | 0.0000 | 0.0003 |

Five carried items at one chance in five is **one dropped item per kill on
average**, and a third of kills leaving nothing at all.

### The verdict is addressed, not sequential

The obvious implementation draws five numbers from one stream and hands them out
in order. This one gives each carried item its own stream, named

```
drop:<kill>#<index>:<item name>
```

so a verdict is a function of the kill, the item's place and its name, and of
nothing else that was carried. The difference is worth the line it costs: with a
shared sequence, adding a dagger to a corpse silently rerolls the armour. The
test truncates a carried list by two items and finds every surviving verdict
unmoved; the paired control shifts each item one place along and finds every draw
moved, so "unmoved" means the address held rather than that the roll ignores its
inputs.

### One kill, worked

`goblin-42`, standing $128$ units from spawn — ring 2, level 3:

```
  #  fell  roll  stream                          item
  0   yes    19  drop:goblin-42#0:common staff  common weapon hand L3 P=12 mov=0 def=1 eff=11 dex [blink:11]
  1    no    84  drop:goblin-42#1:uncommon legg uncommon armour leggings L3 P=18 mov=0 def=13 eff=5 int [blink:3|homing:2]
  2    no    70  drop:goblin-42#2:common boots  common armour boots L3 P=12 mov=2 def=10 eff=0 dex []
  3    no    63  drop:goblin-42#3:common boots  common armour boots L3 P=12 mov=6 def=3 eff=3 int [warding:3]
  4    no    95  drop:goblin-42#4:mythic boots  mythic armour boots L3 P=63 mov=26 def=26 eff=11 con [shock:9|splitting:2]
```

One item fell: the staff. The mythic boots stayed on the body, which is the whole
point of a chance rather than a certainty.

The same seed and the same kill produce that same line **in two separate
processes**: `tests/test_drops.gd` runs `bin/drops_main.gd` twice as a subprocess
and compares the transcripts byte for byte, then checks that the line it computes
in-process for `goblin-42` appears in what both of them printed.

---

## The frontier, as a number

Section 5 promises a structural guarantee:

> *your gear budget is capped by what you've killed, which is always behind the
> frontier … Grinding a safe zone can't break it: that zone drops only its own
> tier, below the next ring. Only advancing makes you stronger.*

To measure that, distance has to become a level, and this is the first place in
the project where it does:

$$\text{ring}(d) = \left\lfloor \frac{d}{64} \right\rfloor, \qquad L(d) = 1 + \text{ring}(d)$$

A step function on purpose: a ring is a band of ground where every creature is
worth the same, so "the ring beyond" is a place rather than a figure of speech.
Sixty-four world units is four terrain chunks — a walk, not a step.

Because an item's level **is** the level of the creature that dropped it, every
item obtainable at distance $d$ is worth $r \times L(d)$ for one of six fixed
multipliers, and the best of them is

$$C(d) = r_{\max} L(d) = 32 \, L(d)$$

No amount of killing at distance $d$ produces anything above $C(d)$. Ground for
400 kills a ring, five items a kill:

| $d$ | ring | $L(d)$ | ceiling $C(d)$ | best ground out | mean ground out | $L(d{+}1)$ | $C(d{+}1)$ | best the next ring carried |
|---|---|---|---|---|---|---|---|---|
| 0 | 0 | 1 | 32 | 32 | 6.78 | 2 | 64 | 64 |
| 64 | 1 | 2 | 64 | 64 | 13.80 | 3 | 96 | 96 |
| 128 | 2 | 3 | 96 | 96 | 20.40 | 4 | 128 | 128 |
| 256 | 4 | 5 | 160 | 160 | 34.20 | 6 | 192 | 192 |
| 512 | 8 | 9 | 288 | 288 | 60.90 | 10 | 320 | 320 |
| 1024 | 16 | 17 | 544 | 544 | 114.59 | 18 | 576 | 576 |

Six rings of six: the grind never passed its own ceiling, that ceiling was always
under the next ring's, and the best the next ring was carrying was always more
than the best the grind produced. And the grind **saturates** — at ring 2:

| kills | best budget found | own ceiling | next ring's ceiling |
|---|---|---|---|
| 1 | 42 | 96 | 128 |
| 10 | 42 | 96 | 128 |
| 100 | 96 | 96 | 128 |
| 1000 | 96 | 96 | 128 |
| 2000 | 96 | 96 | 128 |

A hundred kills reaches the cap and two thousand do not move it. That is the
shape of the guarantee: **grinding has a ceiling, and only walking raises it.**

### What is *not* claimed, with its number

That no item from a near ring can beat a *typical* item from the next one is
false, and deliberately so: a lucky eternal is worth eight commons, so rarity is
a shortcut through the level gradient — the same fact
[items.md](items.md) records as "a common item from a level-16 creature and an
eternal from a level-2 one are both worth exactly 64". The exact chance that one
item rolled at ring $d$ is worth more than one rolled at ring $d+k$, summed over
the thirty-six tier pairs:

| ring $d$ | $L(d)$ | $k=1$ | $k=2$ | $k=4$ | $k=8$ |
|---|---|---|---|---|---|
| 0 | 1 | 0.1622 | 0.0738 | 0.0275 | 0.0000 |
| 1 | 2 | 0.1717 | 0.1622 | 0.0738 | 0.0275 |
| 2 | 3 | 0.3320 | 0.1622 | 0.0738 | 0.0275 |
| 4 | 5 | 0.3320 | 0.3320 | 0.1622 | 0.0738 |
| 8 | 9 | 0.3320 | 0.3320 | 0.3320 | 0.1622 |
| 16 | 17 | 0.3320 | 0.3320 | 0.3320 | 0.3320 |

Read the top-left corner: near spawn, where levels *double* from one ring to the
next, a ring-0 item beats a ring-1 item only $16\%$ of the time and a ring-8 item
never. Read the bottom row: far out, where $L(16) = 17$ and $L(24) = 25$ differ by
less than half, the two distributions overlap heavily and a near item wins a third
of the time. That is section 5's "skill lets a clever player punch slightly past
their gear tier", quantified — and it is bounded, because the ceiling is only
$32/6.81 = 4.7$ times the mean, so luck buys a few rings and never the frontier.

---

## The item stream and the world-generation stream

Both are named against the world seed, and neither can move the other:

| stream | opened by | named |
|---|---|---|
| item generation | `sim/item_forge.gd` | `item:<source>` |
| drop verdicts | `sim/item_drop.gd` | `drop:<kill>#<index>:<item name>` |
| observer motion | `sim/world.gd` | the world's own `SimRng`, held on the world |
| terrain, biome, water, islands, settlements, scatter | the generation fields | not a stream at all — hashed per world position |

`SimRng.fork(label)` builds a **fresh** generator from the seed and the label
rather than advancing a shared one, and neither item file holds a generator
between calls — there is no state on either class. So an item roll has nothing to
perturb. Shown rather than argued, on the world's own fingerprint:

```
fresh world digest:                  b963fd807b8c432d
after 5000 item rolls (975 fell):    b963fd807b8c432d
unchanged by the rolls:              yes

after 50 ticks, world with no rolls: eb2d8c9369212120
after 50 ticks, world with rolls:    eb2d8c9369212120
the two worlds agree:                yes
```

The second pair is the one that matters: the rolls happen *between* ticks, which
is where a shared stream would do its damage. The suite makes the same comparison
and pairs it with a control — one more tick *does* move the fingerprint — so the
equalities are between two live fingerprints and not two copies of a constant.

The stop condition for this step was to report a shared stream as a defect rather
than work around it. **It did not fire.** Nothing was found to work around.

---

## What is checked

`tests/test_drops.gd`, 65 checks, and every claim with a premise is paired with a
run in which the premise is broken:

| claim | the paired broken run |
|---|---|
| the realised rate is one in five | the same draws read at a threshold of fifty come out at a half |
| a verdict is addressed, not sequential | shifting each item one place moves every draw |
| the frontier stays ahead | a ring compared against itself shows no gap |
| item rolls cannot move the world | one more tick does move the fingerprint |
| the item layer cannot reach world generation | the same scan finds `TerrainStreamer` in `sim/world.gd` |

Two structural checks read `sim/` by opening the directory rather than trusting a
list:

* **the item layer is now eight files**, found by which file *declares* each of
  the layer's class names — `ability.gd`, `item.gd`, `item_budget.gd`,
  `item_drop.gd`, `item_effect.gd`, `item_forge.gd`, `item_frontier.gd`,
  `item_rarity.gd` — and none of them names a class of the combat layer, while at
  least one combat file names an item class. The naming still runs one way.
* **and none of them names a class of world generation** — not `SimWorld`, not a
  field, not a streamer. The two random streams are separate because neither
  layer can reach the other, which is cheaper to keep true than a convention.

All 28 suites pass headless (189844 checks), the three structure checks pass on
their own, and every documented entry point exits 0 — run one at a time, logged
in [drops-suite-evidence.txt](drops-suite-evidence.txt).

`tests/test_items.gd` gained one number in the process: **two** files of the item
layer draw a random number now, not one, and they are the two places where chance
is the point — the forge, which decides what an item is, and the drop, which
decides whether a carried one falls. Everything else in the layer is arithmetic.

---

## What this layer deliberately does not do

* **A drop lands as data.** `ItemDrop.drops()` returns the items that fell. There
  is no ground to put them on, no container, no inventory screen and no character
  sheet — none of those exist yet and section 4 does not ask for them here.
* **Nothing spawns.** `ItemFrontier` turns a distance into a level and forges what
  a creature at that distance would carry, but no creature is placed anywhere by
  it. Wiring the gradient into where enemies actually stand belongs with the
  characters phase, which is where creatures start existing.
* **The gradient is the plainest thing that rises.** One level a ring, sixty-four
  units a ring. It is a first setting rather than a tuned one; what this step
  fixes is that the anti-invincibility property is now *measured against whatever
  the gradient is*, so changing it re-runs a table instead of re-opening an
  argument.
* **No terrain, biome, water, island or settlement generation was touched.** The
  world fingerprint is this phase's regression signal, and it is unchanged.
