# Both paths move ownership: a fight against a friendship, measured

Section 6 makes one claim the whole territory design rests on:

> both paths matter: winning battles (raising your level, removing rival
> owners) and winning hearts (raising sentiment) both shift ownership.

The ownership rule is built, the goodwill machinery is built, and fights that
fell a commander are built. This step proves the sentence end to end on the
implementation: one seed, one cast, one piece of ground, two runs that differ
in exactly one stated way, and ownership of the same six named points read
before and after for both. Measurement only — no rule was changed anywhere.

```
./run_territory.sh                    # both runs and the comparison
./run_territory.sh --arm fight        # just the fight run
./run_territory.sh --arm friendship   # just the friendship run
./run_territory_suite.sh              # just this step's suite (41 checks)
```

| file | what it is |
|---|---|
| `sim/scripted_territory.gd` | the comparison |
| `bin/territory_main.gd`, `run_territory.sh` | the command |
| `tests/test_territory.gd` | the suite |
| `tools/territory_ground_probe.gd` | the passability map the rival's post was placed against |
| `reports/territory-evidence.txt` | what the command prints, checked in |

## 1. The setup, and the one difference

Five people on the seeded world every scripted run uses (`seed 1234`, the green
at `(-480, 420)`): **Wren** (level 2), the three neighbours of the goodwill run
— **Bram**, **Sable**, **Odo**, each wanting one thing — and **Rook** (level
2), a rival at a post 34 units north. Everyone is in one band, so no fight can
begin by two people drifting close together; the only fight possible is one
somebody chooses.

Both runs open identically: Rook gives each neighbour two small gifts — six
honoured trades, written into the relationship graph by the engine itself
(trust 0.73, familiarity 0.44 per neighbour) — and returns to its post, while
Wren waits. By the parting tick 170 the rival owns the ground: the incumbent
that one path must remove and the other must out-earn.

From tick 170 the runs differ in exactly one thing — which written rule drives
Wren:

* **fight** — walk to Rook's post and attack until the rival falls. The chosen
  blow snaps the world to a board; eleven sword cuts over twelve turns fell
  Rook by tick 287.
* **friendship** — hand each neighbour the thing it actually wanted, then one
  small gift: six honoured trades, the same effort the incumbent spent, three
  of them deeds. The deeds close goals the world was watching; a model judges
  each (0.6, 0.7, 0.5 — replayed from the goodwill recording) and the judged
  share lands as trust on top of the trade's own.

Both runs are headless, make no live model call, and print identical bytes
across two processes (`sha256 394f2b1c…` for the full transcript, twice). The
parting fingerprints of the two runs agree (`cba3f4c6f8cbd555`), so "identical
until they part" is printed, not promised.

## 2. Ownership of the same named points, before and after

Score is `OwnershipField.at`'s, in $[-1, 1]$; owning takes more than the 0.05
threshold. Before is the shared world at tick 170.

| point | before: owner (Wren / Rook) | after the fight | after the friendship |
|---|---|---|---|
| the green | **Rook** (0.0000 / 0.2092) | **nobody** (0.0000 / 0.0000) | **Wren** (0.3442 / 0.2414) |
| Bram's door | **Rook** (0.0000 / 0.2605) | **nobody** (0.0000 / 0.0000) | **Wren** (0.3476 / 0.2744) |
| Sable's door | **Rook** (0.0000 / 0.2559) | **nobody** (0.0000 / 0.0000) | **Wren** (0.3507 / 0.2766) |
| Odo's door | **Rook** (0.0000 / 0.2484) | **nobody** (0.0000 / 0.0000) | **Wren** (0.3332 / 0.2184) |
| Rook's post | **Rook** (0.0000 / 0.2528) | **nobody** (0.0000 / 0.0000) | **Rook** (0.0645 / 0.2270) |
| the far road | nobody | nobody | nobody |

Both paths moved the same ground, and the far road — out of everybody's
earshot — moved under neither: the effect is the rule's locality, not a global
flag flipping.

## 3. The two effects, as numbers

Over the same 961-point sampled grid (300 × 300 units, step 10):

| moment | who holds what |
|---|---|
| at the parting | Rook 491, Bram 64 |
| after the fight | nobody holds anything |
| after the friendship | Wren 318, Rook 173, Bram 64 |

* **The fight moved 555 points; the friendship moved 318** — 0.57 points moved
  by friendship for every one the fight moved.
* The fight moved *more* ground than the rival himself held (491): Bram's 64
  points were a claim resting on the fallen one's goodwill toward Bram, and
  they went neutral with him. Removing a rival owner also removes his opinions
  from everybody else's claims.
* The two paths shift ownership **differently in kind**. The fight *vacates*:
  every named point went Rook → nobody, and Wren gained not a millisentiment
  of claim by winning (0.0000 everywhere — nobody nearby thinks better of a
  victor). The friendship *captures*: the green and all three doors went
  Rook → Wren (0.34 vs 0.24 at the green), while the rival kept his own post,
  where his voice is still the nearest (0.227 vs 0.064).
* Neither path dominates outright: the fight moved 1.75× as many points, but
  every one of them to neutral; the friendship moved fewer, but took ownership
  of them. That is reported as measured, not tuned.

## 4. What the comparison does not isolate, named plainly

* **The rival does not fight back.** Rook is unarmed by scenario choice, so
  "winning the fight" carries no risk or health cost to the winner here.
* **The judged amounts replay the goodwill recording by position.** The deed
  prompts differ from the recorded ones only in tick stamps and cast ids, and
  every reply prints a line saying its prompt is not the one recorded. A live
  model could judge differently.
* **Effort is equalised against the incumbent, not between the paths.** Six
  exchanges answer six exchanges, while the fight spends one walk and eleven
  blows. The paths differ in cost as well as in kind; this run measures
  effect, not price.
* **Only half of section 6's battle sentence is exercised.** "Raising your
  level, removing rival owners" — no rule raises a level on a kill yet, so
  only the removing is measured. (A finding, not a change made here.)
* **The incumbent's claim is built by the same trade machinery the friendship
  uses** — it is the engine's only way to make anybody own anything — so
  "before" is not independent of the hearts path.

## 5. Where the constants came in

Nothing was retuned. `OwnershipField`'s shipped constants (softmin, T=12,
R=120, threshold 0.05) are used through `OwnershipField.at` — no second copy of
the arithmetic. The one placement decision, the rival's post at `(0, −34)`
relative to the green, was made against a printed passability map
(`tools/territory_ground_probe.gd`): a river crosses the ground south-east of
the green at this seed, and walks here are straight lines that a river blocks.
