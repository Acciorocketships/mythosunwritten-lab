# Characters milestone — independent check

What this file is: the evidence behind the review of the milestone "Characters
and the atomic action interface" (`W-characters`). Every line below was produced
by running a command in this repository on 2026-09-01 and reading the output;
nothing here is taken from the worker's write-up. Where a claim could not be
checked, the reason is stated rather than the claim repeated.

Two terms used throughout, re-explained because this project coined them:

* **character sheet** — the one data type (`sim/character.gd`, class `Character`)
  that holds everything a character *is*: six ability scores, level, status,
  health, inventory, equipment, identity text, and a handle called `decide`.
* **decision function** — whatever is attached to `decide`. It is a plain
  callable of the form $f(\text{scene}, \text{actor}) \to \text{action}$. The
  design's "no preferential treatment" principle says this handle is the *only*
  thing that differs between a character a person drives and a character a
  program drives.

---

## 1. What was run, and what it said

Everything was run headless. The two mutation harnesses were run last, one after
the other, with nothing else running against the repository, because they edit
`sim/` in place.

| command | result |
| --- | --- |
| `./run_tests.sh` | all 33 suites passed, 191,854 checks, 15m35s |
| `./run_tests.sh --layers-only` | layer check OK, combat check OK, asset check OK |
| `./run_headless.sh` | seed 1234: tick 0 `b963fd807b8c432d`, tick 50 `809a88491e407272`, final `d178d38879097c1c` |
| `./run_sheet.sh` | 14 fields on each of two sheets, the same 14 |
| `./run_inventory.sh` | one inventory; equipping, dropping, defeat-loot, money both ways |
| `./run_actions.sh` | 12 actions / 17 call names; four worked failures; two minds, one fingerprint |
| `./run_loop.sh` | four interruptions; bias 16.1% vs 100%; slow decider 80/80 ticks |
| `./run_scenario.sh` (×3) | `8ade11b4858cfd0a8563094d756a46a897fdb4b3cbca71bed6c5d932251e9a57` every time, byte-identical to `reports/scenario-evidence.txt` |
| `tools/piece_mutations.sh` | all 19 broken rules were caught |
| `tools/resolution_mutations.sh` | all 61 broken rules were caught |
| `./run_scenario.sh` (after both harnesses) | same digest — `sim/` was restored intact |

---

## 2. The adversarial check: is any character privileged?

The principle under test: the human-driven character and every other share one
sheet, one inventory, one action set and one set of combat rules, and the
decision function is the only difference. The review looked for a path in either
direction — something a person-driven character can do that a program-driven one
cannot, or the reverse — with a probe written for the review:

    tools/godot/godot4 --headless --path . --script res://tools/critic_privilege_probe.gd

### A — the engine is blind to the decision function

Each of the twelve atomic actions was resolved for the same character on three
scenes staged identically, differing only in what was on `decide`: nothing at
all, a person's recorded list, a program's rule. Compared: the outcome sentence
and the scene fingerprint (a 16-character digest of every position, health,
inventory, offer and spoken word in the scene).

| actions tried | outcomes that moved with the decider |
| --- | --- |
| 12 | **0** |

Every one of the twelve gave the same outcome text and the same fingerprint all
three ways. Nothing on `decide` reaches `ActionEngine.resolve`.

### B — the control loop is blind to it too

One list of five choices, driven two ways over 60 ticks: once by the shape a
person's turns take (the scenario's `recorded_turns`), once by a program's rule
computing the same answer.

| | person's list | program's rule |
| --- | --- | --- |
| journal lines | 16 | 16 |
| turns resolved | 5 of 5 | 5 of 5 |
| scene fingerprint | `0ffbacab94604aea` | `0ffbacab94604aea` |

Lines that differ between the two journals: **0**.

### C — the whole seeded run with the person replaced by a program

The checked-in 110-tick scenario has one person in it (Wren). Its decision
function was replaced by a program returning the identical choices at the
identical index; nothing else was changed.

| transcript lines | lines that differ |
| --- | --- |
| 289 / 289 | **0** |

### D — what the board reads off each

Two commanders built identically, one carrying a person's decision function and
one a program's. Ten numbers compared: level 8, health 68, max health 68, status
8, defence 6, four move grants, the same loadout line, 2 attacks, first-attack
damage 12, attack cells `[(-1,-1), (0,-1), (1,-1)]`.

| numbers compared | numbers that differ |
| --- | --- |
| 10 | **0** |

### E — who reads the handle

Five files under `sim/` name `decide` in code. Two of them *call* it —
`control_loop.gd` and `decision_source.gd`. The other three
(`scripted_scenario.gd`, `scripted_actions.gd`, `scripted_loop.gd`) are the
walkthroughs, and they only *assign* it. A decision function is called with two
arguments, and the probe confirmed both are the same objects either way: the
scene it is in and the actor it is choosing for.

A separate scan (`tests/test_character_sheet.gd`) reads every `sim/*.gd`, strips
comments but keeps string literals, and looks for eleven words that would mean a
file knows which kind of character it holds. It reports nothing over `sim/`, and
it catches its own deliberately broken control line (2 hits). The review
re-ran the equivalent grep by hand: every occurrence of "player", "human", "npc",
"agent" and "llm" under `sim/` is inside a documentation comment.

### The one asymmetry found, and it runs the other way

`DecisionSource.recorded` — the library's person-shaped decider — is a queue: it
hands over the *next* choice on every call. The control loop calls a decision
function again every `ControlLoop.REVIEW_EVERY` = 5 ticks to ask whether the
character has changed its mind, so entries are spent answering questions rather
than being carried out. Measured on the checked-in scenario:

    tools/godot/godot4 --headless --path . --script res://tools/critic_recorded_drain_probe.gd

| how the same ten choices are read | turns resolved | re-evaluations over 110 ticks |
| --- | --- | --- |
| against what has been carried out (`recorded_turns`) | **10 of 10** | 40 |
| as a queue (`DecisionSource.recorded`) | **4 of 10** | 36 |

This disadvantages the person-shaped path, not the program-shaped one, and it is
a property of the *library's* queue rather than of the engine or the loop: the
scenario supplies its own person-shaped decider and gets all ten turns. It is
already filed as inbox item `I-500a3b416b8c`, point 2, and the suite already
measures it (`tests/test_scenario.gd`,
`_a_recorded_list_is_drained_by_being_asked`). The review reproduces it and adds
nothing new.

**Conclusion of the adversarial pass:** no path was found by which either kind of
character can do something the other cannot. How it was looked for: the twelve
actions resolved three ways each, the loop driven two ways, the whole seeded run
replayed with the person replaced, ten combat numbers compared, the five readers
of the handle enumerated, and the word scan re-run by hand.

---

## 3. Acceptance lines, one at a time

`met` means the review checked it against the code *and* against a run.

### W-character-sheet

| line | verdict | how |
| --- | --- | --- |
| one type carries every field section 2 names | met | `./run_sheet.sh`: 14 fields, the same 14, listed by name |
| a person and an agent are one type, shown by a source scan with a broken control | met | scan read at `tests/test_character_sheet.gd:145`; control catches 2 hits; suite passes |
| Commander reads scores off the sheet; item-gate numbers unchanged | met in substance | `Commander.scores` is gone; `score_for` reads the sheet. Gate table from `./run_sheet.sh` (score 8 → def 6, cut 12, cleave 20, down to 0/0/0/0) matches the published table in `reports/loadout.md`. **"Before and after" could not be re-derived** — see §4. |
| level-up spends one point on one score | met | `./run_sheet.sh`: level 3→4, DEX 14→15, health 38→44, five other scores unmoved |
| status is separate from level | met | `./run_sheet.sh`: Wren level 3 status 3 (unassigned), Bramble level 3 status 12 |
| the seed-1234 digests on record still match | **not met as written** | only tick 0 matches; see §4 |

### W-character-inventory

| line | verdict | how |
| --- | --- | --- |
| one inventory; equipped is a subset of carried | met | `./run_inventory.sh`; `Character.equipment` is a getter over `inventory.equipment()` with no setter |
| equipping changes defence, movement and attacks through the existing gate, no second copy | met | `./run_inventory.sh`: five wearers, def 6/4/3/1/0 and move-cells 24/8/8/4/4; `Commander.armour`/`.weapon` are getters over the inventory |
| pick up and drop, and defeat's drop path | met | `./run_inventory.sh`: boots taken, worn, dropped back; a defeat rolling 1 of 5 items onto the ground and another character taking it |
| money moves either way, including a gift | met | 30/120 → 75/75 → 35/115 → 10/140; a 9999-coin trade refused with the purse unchanged |
| order of acquisition does not matter | met | forwards and backwards give the same fingerprint, def 6/6, move-cells 24/24, cut 12/12 |
| fingerprint unchanged and suites pass | met in substance | current triple reproduced; all 33 suites pass |

### W-atomic-actions

| line | verdict | how |
| --- | --- | --- |
| every action of section 2.1 exists and is callable | met | `./run_actions.sh` prints 12 actions / 17 call names and calls every one |
| section 2.1's list and section 10's call surface are one list, with a check | met | one table in `sim/action_catalog.gd`; `faults()` run over six broken copies in `tests/test_actions.gd` |
| any action may fail with a reason; four named worked cases | met | all four in `./run_actions.sh`: jump "10.40 is further than DEX 4 jumps (4.50)"; "the offer from Rook was denied"; "Vex is outside the pattern of a common bow from here"; "the chest needs a lockpick" |
| the engine resolves, the caller only chooses, shown by a source check with a broken control | met | scan at `tests/test_actions.gd:485`; three broken controls caught, four honest lines not fired on |
| a human decision function and a scripted one drive the identical surface | met | `./run_actions.sh` "two minds": both print fingerprint `00c0c818a30279b7` |
| fingerprint unchanged and suites pass | met in substance | as above |

### W-control-loop

| line | verdict | how |
| --- | --- | --- |
| an action occupies ticks; the cadence is one named constant | met | `ControlLoop.REVIEW_EVERY` = 5; `./run_loop.sh` shows a 20-tick walk reviewed at 5/20, 10/20, 15/20 |
| re-evaluation on each of the four named events, each with its own case | met | `./run_loop.sh`: finishing (t=4 and t=8 share a tick with the next `began`), attacked (wait abandoned at 6/20t as health goes 32→14), combat began (both walkers drop their walk at 4/20t), spoken to (interrupted at 7/20t; a shout interrupts nobody) |
| the bias is one number, measured at it and at a broken one | met | 0.85 → 193 reviews, 31 changes, 16.1%; 0.00 → 239 reviews, 239 changes, 100.0% |
| a slow decision function does not stall the world | met | Ash thinking for 40 ticks: Bryn 80 ticks / 2 actions and Cass 80 / 2 either way; all 42 journal lines of the other two identical |
| the same seed gives the same transcript in two processes | met | the suite runs `./run_loop.sh` twice and compares bytes; scenario checked separately below |

### W-character-scenario

| line | verdict | how |
| --- | --- | --- |
| several unprivileged characters, driven only through the action surface, transcript checked in | met | five characters, one `ActionScene`, 110 ticks; `reports/scenario-evidence.txt` reproduced byte-for-byte |
| movement, speech, a trade moving items and money, a pick-up, and a fight that snaps on and off the board | met | three walks; a word at t=1 answered at t=6; lantern at t=34; trade at t=62 moving 12 coins and the cloak (money 30→18 and 8→20); snap-in t=77 (`joined=2`, board `15a5a4b9f14a7bfc`), decided in 4 rounds, real time again t=85; shout t=104 |
| one character driven by a human-shaped decision function fed recorded choices | met | Wren's ten written-down turns, all ten resolved in written order |
| reproducible: same seed, same transcript, two processes; digest quoted | met | three separate runs, digest `8ade11b4…` every time |
| at least one rendered frame showing the rigged animated models | met | `reports/assets/scenario-market.png` and `…-quarrel.png`, both embedded in `reports/scenario.md`; the review opened both and the KayKit mage, rogue, ranger, knight and barbarian rigs are visible. **The quarrel frame's caption overclaims** — see §5. |

---

## 4. What the review could not verify, and why

**"The same figures quoted before and after", and "the fingerprint is unchanged
by the milestone."** The repository has one commit (`Initial commit`), and every
file this milestone touched is uncommitted. There is therefore no before-state in
the repository to re-derive a "before" figure from. What the review *can* say is
what it measured now: the gate table published in `reports/loadout.md` is the
table `./run_sheet.sh` prints today, and `./run_headless.sh` at seed 1234 gives
tick 0 `b963fd807b8c432d`, tick 50 `809a88491e407272`, final `d178d38879097c1c`,
stable across runs. Whether those numbers moved during the milestone is not
checkable from here; it rests on the workers' byte-comparisons, which the review
did not repeat.

**The stale digest quotation.** `W-character-sheet`'s last acceptance line quotes
tick 0 `b963fd807b8c432d`, tick 50 `eb2d8c9369212120`, final `d4e31b0904ff45c0`.
Reproduced with `./run_headless.sh`: only tick 0 matches. The other two moved
before this milestone started, in the road-levelling fix recorded in
`reports/mountains.md` §8.2, and this is already filed as inbox item
`I-96d57d83a061`. The line cannot be met as written by any change to the
character layer; its substance — no generation rule moved — is met.

**"No second copy of those numbers anywhere in the project."** Checked by reading
`sim/commander.gd` (both `armour` and `weapon` are getters over the inventory)
and by the suite's structural check. An exhaustive negative over the whole
project was not proved.

---

## 5. The one finding

**The quarrel frame's caption describes a lattice the frame does not show.**

`reports/scenario.md` captions `assets/scenario-quarrel.png` as "Bram the knight
and Sable the barbarian standing on the tactical lattice, the board's cells drawn
faintly over the grass", and the italic line under it tells the reader "the pale
quadrilaterals under the grass are the board".

Reproduced:

```
xvfb-run -a ./run_render.sh --seed 1234 --scenario quarrel --board \
    --camera 4 4.0 6.0 --aim 1.4 --screenshot-tick 4 --screenshot q_board.png
    → render-shell stop … board=441/1 …

xvfb-run -a ./run_render.sh --seed 1234 --scenario quarrel \
    --camera 4 4.0 6.0 --aim 1.4 --screenshot-tick 4 --screenshot q_noboard.png
    → render-shell stop … board=0/0 …
```

So the overlay really is in the scene: 441 cells with `--board`, none without.
What it contributes to the picture, measured over the ground region the two
fighters stand on (rows 230–470, columns 450–1152 of the 1152×648 frame), as mean
brightness out of 255:

| pair | difference in mean brightness |
| --- | --- |
| two renders both with `--board` (the noise floor) | 0.119 |
| with `--board` against without | **1.449** |

The overlay lifts the ground by about 1.4 grey levels out of 255 — twelve times
the render-to-render noise, and well under what a reader can see. Viewed at 3×
contrast enhancement, no cell edges are resolvable in either the checked-in frame
or a fresh re-render at the documented camera; the grass (19,096 blades in this
view) covers them.

The acceptance line this frame answers asks only that a rendered frame show the
characters as the rigged models, and it does. The problem is the caption, which
sends the reader looking for quadrilaterals that are not there — and the
character report (`W-characters-report`) is about to reuse this material.

Smallest change: re-word the caption to say the fight is on the board
(`board=441/1` in the render-shell line) rather than that its cells are visible;
or, if the picture is wanted, re-render this frame with the grass layer off or
from a steeper camera so the lattice reads.

---

## 6. The probes this review wrote

Neither touches `sim/`, `tests/` or any run script; both only read the code they
are pointed at and print numbers.

* `tools/critic_privilege_probe.gd` — sections A to E above.
* `tools/critic_recorded_drain_probe.gd` — the recorded-list measurement.
