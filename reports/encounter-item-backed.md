# The demo's weapons are forged now, and the numbers came down

`sim/scripted_encounter.gd` is the scenario `./run_encounter.sh`,
`./run_headless.sh` and the renderer all play, so it is the fight every
screenshot and transcript in this project shows. Five of its commanders were
handed a **bare catalogue shape** — `wield(Weapon.sword())` — rather than a
weapon forged onto an `Item`. A bare shape has no power budget behind it, no
item level, no rarity, and no ability score can gate it: it reads the
catalogue's own damage numbers straight off the table in `sim/weapon.gd`.

*Terms used below.* An **item's power budget** is one pool of points,
$P = r(\text{rarity}) \times L_{\text{source}}$, split across three axes —
movement, defence, effects. A weapon's blows are bought out of its **effects
axis**; the catalogue's damage numbers are only the *weights* by which that axis
is divided among the weapon's attacks. The **ability-score gate** is the rule
that an item under-performs for a wielder whose relevant ability score is below
the item's level. All three live on the `Item`, so a weapon with no `Item` meets
none of them.

## 1. The defect, reproduced as numbers before anything moved

`tools/encounter_item_probe.gd`, run against the code as it stood:

```
=== A. a bare catalogue sword against one forged at level 2
  bare Weapon.sword()          cut/cleave = 10/16
  Weapon.held(sword(), 2)      cut/cleave = 3/5  (budget 8)
  the bare shape is worth 26 points of effects axis

=== B. the same pair read by a commander with every score at 0
  bare Weapon.sword()          cut = 10
  Weapon.held(sword(), 2)      cut = 0

=== C. the commanders sim/scripted_encounter.gd musters
  ground #1 level=2 sword cut:10/1 cleave:16/3 item=none
  ground #4 level=2 spear thrust:8/1 item=none
  ground #7 level=1 dagger stab:6/1 item=none
  island #1 level=2 sword cut:10/1 cleave:16/3 item=none
  island #3 level=2 spear thrust:8/1 item=none
```

Read straight: the bare shape is worth $26$ points of effects axis, which a
common item needs a level-7 source to buy, so a level-2 commander was swinging
roughly three times what its level entitles it to. And section B is the gate
failing to reach: with every ability score recorded as $0$, the item-backed
sword deals nothing and the bare one still deals $10$.

## 2. The scan, and it failing against the code it was written for

`tests/test_effects.gd::_every_weapon_handed_out_has_an_item_behind_it` sweeps
every file under `sim/` line by line. A line that names one particular weapon
(`Weapon.sword(`, `Weapon.spear(`, …) must also say `Weapon.held(`; and a line
that both names a weapon and hands it over with `wield(` must say the same. Both
sweeps are run again over lines that are *not* on disk and that they must catch
— a bare `wield(Weapon.sword())` and a forged `wield(Weapon.held(Weapon.sword(),
2))` — so an empty result means the violation is not there rather than that the
scan did not look. A third check requires the sweep to *find* the forged calls
($\ge 8$ of them), so "no bare one" cannot be satisfied by reading nothing.

Against the unfixed code the suite reported, exactly:

```
FAIL  effects        1474 checks, 3 failed
        - every line under sim/ that names one weapon forges it onto an item
      expected: []
      actual:   ["res://sim/scripted_encounter.gd:101", "res://sim/scripted_encounter.gd:110",
                 "res://sim/scripted_encounter.gd:119", "res://sim/scripted_encounter.gd:154",
                 "res://sim/scripted_encounter.gd:161"]
        - no wield() call under sim/ hands over a weapon with no item behind it
      expected: []
      actual:   [the same five lines]
        - the sweep found 3 item-backed weapons handed out under sim/
```

The five line numbers are the five the review named. The third failure is the
positive side: before the fix only `sim/scripted_match.gd`'s three calls were
forged; after it there are eight.

## 3. The change

Five call sites, in the form `sim/scripted_match.gd` already used, each forged
at the level its own commander already has — no level and no rarity was tuned to
recover the old numbers:

| was (old line) | is (new line) |
|---|---|
| `:101` `wield(Weapon.sword())` | `:120` `wield(Weapon.held(Weapon.sword(), BAND_LEVEL))` |
| `:110` `wield(Weapon.spear())` | `:131` `wield(Weapon.held(Weapon.spear(), BAND_LEVEL))` |
| `:119` `wield(Weapon.dagger())` | `:142` `wield(Weapon.held(Weapon.dagger(), BYSTANDER_LEVEL))` |
| `:154` `wield(Weapon.sword())` (island) | `:178` `wield(Weapon.held(Weapon.sword(), BAND_LEVEL))` |
| `:161` `wield(Weapon.spear())` (island) | `:186` `wield(Weapon.held(Weapon.spear(), BAND_LEVEL))` |

(The line numbers moved because the file's header table gained a paragraph
saying why every weapon in it is forged.)

`BAND_LEVEL = 2` and `BYSTANDER_LEVEL = 1` are new named constants standing
where the scenario previously wrote those levels as bare literals in each
`commander_at` and `minion_at` call. That is the whole reason they exist: a
band's level is now two things at once — how much health and defence its pieces
have, and how large the budget behind its commander's weapon is — and one
constant is what stops those drifting apart.

The null-item fallback in `Weapon.power_for()` **survives**, and
`sim/weapon.gd` now says in the file what it is for: it is the **reporting**
path by which the catalogue states its own reference numbers (the table at the
top of that file, and the reports quoting it), and it is not an equipping path.
The scan in §2 is what holds that line.

Same probe, after:

```
=== C. the commanders sim/scripted_encounter.gd musters
  ground #1 level=2 sword cut:3/1 cleave:5/3 item=common level 2 budget 8
  ground #4 level=2 spear thrust:8/1 item=common level 2 budget 8
  ground #7 level=1 dagger stab:4/1 item=common level 1 budget 4
  island #1 level=2 sword cut:3/1 cleave:5/3 item=common level 2 budget 8
  island #3 level=2 spear thrust:8/1 item=common level 2 budget 8
```

The spear does not move: it is a one-attack weapon, so the whole of its $8$-point
effects axis lands on its single thrust, and $8$ is what the catalogue says a
thrust is worth. That coincidence is worth naming, because it is the clearest
illustration of the rule — the catalogue is a *shape*, and a shape whose single
weight happens to equal its budget reads the same either way.

## 4. What it did to the fight, said plainly

The stop condition did **not** fire: both scenarios still resolve inside their
ticks. But the transcripts moved, in the same way in both.

| | ground, before | ground, after | island, before | island, after |
|---|---|---|---|---|
| commander's cut / cleave | 10 / 16 | **3 / 5** | 10 / 16 | **3 / 5** |
| winner | `#1` | `#1` | `#1` | `#1` |
| rounds | 3 | **4** | 2 | **3** |
| turns | 5 | **7** | 3 | **5** |
| ending | decided | decided | decided | decided |
| fallen | 3 | 3 | 2 | 2 |
| the killing blow | `#1` cut, `dealt=10` | **`#3` toadstool, back, `dealt=12`** | `#1` cut from high ground, `dealt=15` | **`#3` cat, back, `dealt=12`** |
| `#1`'s health when the fight ends | 14/32 | **5/32** | 26/32 | **18/32** |

**The reason, and it is not an accident.** A commander's weapon damage now comes
off a level-2 item's effects axis, which is $8$ points; a *minion's* damage does
not come off any item at all — it is $f(\text{minion level})$, the unbounded
numeric axis of the damage matrix — so it did not move. The commander's blows
fell by roughly two thirds while its minions' did not fall at all, and the
consequence is that in both scenarios the removal that decides the fight
stopped being the commander's sword and became a **minion striking an exposed
back** ($\times 200$ positional multiplier, $12$ points). The same commander
still wins, over one more round, because position rather than raw damage now
carries the fight. That is the design's own claim (§3.1: out-position, do not
power through) arriving in the shipped demo as a consequence of putting the
demo's weapons on the budget — not as something aimed at.

Regenerated, because they quote these numbers verbatim:
`reports/dice-encounter-evidence.txt` and `reports/combat-snap-evidence.txt`
(both are `./run_encounter.sh` transcripts).

## 5. What did not move

| checked | result |
|---|---|
| full suite | `all 28 suites passed (191256 checks)` |
| structure checks | layer / combat / asset — all three `OK` |
| `tools/piece_mutations.sh` | `all 19 broken rules were caught` |
| `tools/resolution_mutations.sh` | `all 61 broken rules were caught` |
| world fingerprint, seed 1234 | tick 0 `b963fd807b8c432d`, tick 50 `eb2d8c9369212120`, final `d4e31b0904ff45c0` — unchanged |

The two mutation harnesses edit `sim/` in place, so they were run one after the
other with nothing else running against the repository, each confirmed to have
printed its final line before the next command started.

## 6. One thing the review's own scan gets slightly wrong

Re-running `tools/critic_items_probe.gd` after the fix, its section A4 — "wield()
calls under sim/ that hand over a shape with no Item" — still reports one hit:

```
res://sim/commander.gd:236 func wield(held: Weapon) -> void:
```

That is the declaration of `wield()` itself, not a call. The critic's predicate
is "a line containing `wield(` and not `Weapon.held(`", which the function's own
signature satisfies. The scan added in §2 requires the line to *also* name a
particular weapon constructor, so it excludes the declaration and reads zero.
A4's sections A3 and A5 still read `BROKE` and should: they construct their own
commanders to measure the bare-versus-forged gap, which is the fallback being
measured deliberately, and the fallback is still there on purpose. What changed
is that nothing under `sim/` can reach it any more.
