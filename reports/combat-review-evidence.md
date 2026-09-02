# Independent review of the combat layer — evidence

*Reviewer's working record for `W-combat-review`. Everything below was produced
on the working tree as it stood, by a reviewer who did not build the layer. The
tree was restored after every edit; the sim/ checksums at the end of the review
match the ones taken before it began, and the full suite was re-run to confirm.*

Two words used throughout, both this project's own:

* an **injection** is one deliberate edit to a single line of `sim/`, chosen to
  be a bug a person could plausibly write, after which the suites are run to see
  whether any of them notices;
* a **detection gap** is a rule that survives an injection — the code was broken
  on purpose and every suite stayed green, so nothing is checking that rule.

---

## 1. What was checked, and how

Each rule of section 3 was read off the code rather than off the reports, and
then broken on purpose. **25 injections across eight rule families**, run against
the seven suites that name any combat symbol at all:

| suite | checks | what it covers |
|---|---|---|
| `test_determinism` | 15 | two headless processes, same seed, same bytes |
| `test_combat_board` | 22 343 | the lattice read off the generated world |
| `test_combat_pieces` | 256 | the four minions, facing, movement as armour |
| `test_combat_resolution` | 229 | turn economy, damage matrix, shove, N commanders |
| `test_combat_snap` | 858 | world position ↔ cell, and back |
| `test_layering` | 24 | `sim/` may not see `render/` |
| `test_characters` | 1 295 | the render shell's reading of pieces |

The other sixteen suites were excluded after checking that **none of them names a
single combat symbol** (`CombatResolution`, `CombatMatch`, `CombatPolicy`,
`LegalMoves`, `PieceMap`, `Minion`, `Commander`, `Damage.`, `Encounter`,
`CombatSnap`) — so the seven above are the whole of the layer's coverage, and an
injection green against them is green against the full suite.

## 2. Result of the sweep

**19 of 25 injections were caught. 6 survived.**

| # | rule family | injected bug | suites |
|---|---|---|---|
| E1 | turn economy | `end_turn` forgets to refresh the minion activation | caught |
| **E2** | **turn economy** | **a refused attack still spends the turn's action** | **survived** |
| E3 | turn economy | a minion that only stepped does not spend the activation | caught |
| E4 | turn economy | turn order is by descending id | caught |
| M1 | minion patterns | the Toadstool captures on all eight neighbours | caught |
| M2 | minion patterns | the Frog is missing one of its eight hops | caught |
| M3 | minion patterns | the Cat's slide is capped at two cells | caught |
| F1 | facing | a quarter turn goes anticlockwise | caught |
| F2 | facing | the target's frame is entered by turning the wrong way | caught |
| F3 | facing | an exact diagonal counts as a flank rather than a back | caught |
| A1 | movement as armour | equipping a slot twice keeps both pieces | caught |
| A2 | movement as armour | armour replaces the base step instead of adding to it | caught |
| A3 | movement as armour | the chestplate reaches three cells | caught |
| D1 | damage matrix | a minion hits a commander for its level, not its power | caught |
| **D2** | **damage matrix** | **an area attack spares the attacker's own minions** | **survived** |
| D3 | damage matrix | a wound never takes the last hit point | caught |
| K1 | king rule | a commander shoved into a hole leaves its minions standing | caught |
| K2 | king rule | a commander shoved off a ledge leaves its minions standing | caught |
| **S1** | **shoves** | **a shove always pushes exactly one cell** | **survived** |
| **S2** | **shoves** | **a shove off the board's edge is a fall** | **survived** |
| **N1** | **N commanders** | **a death before the active commander skips the next turn** | **survived** |
| N2 | N commanders | a match with one commander left is not over | caught |
| **L1** | **one seam** | **a second file calls the damage seam** | **survived** |
| L2 | no randomness | the mover chooses at random | caught |
| L3 | no randomness | the encounter's join radius is drawn at random | caught |

Four confirmation injections were then run:

| # | injected bug | suites |
|---|---|---|
| N1b | `_advance` drops its fallback for a reaped active commander | **survived** |
| N1c | `_slot` is never maintained across turns at all | **survived** |
| S1b | the push distance is tripled | caught |
| D2b | an area attack spares *every* minion | caught |

The project's own two mutation harnesses were re-run and both remain green —
`tools/resolution_mutations.sh` 36 of 36, `tools/piece_mutations.sh` 17 of 17 —
so none of the six gaps above is a rule those harnesses already cover.

---

## 3. The six gaps, reproduced

### S1 — a push of more than one cell reads only the cell it lands on

`CombatResolution._push()` computes the destination as
`from + direction * distance` and then applies its four checks — a hole, a fall,
something solid or occupied, plain ground — to **that cell only**. For a push of
one this is exactly the rule `reports/combat.md` states. For a push of two it
stops being that rule, silently.

`Attack.push` is documented as "how many cells it pushes what it lands on" and is
accepted as any non-negative integer; the only attack in the catalogue that
pushes, the shield's shove, pushes one, which is why nothing notices.

Reproduced on a typed board, one attack `heave` identical to the shield's shove
except that it pushes two, victim on `(x,3)`, pusher on `(x,4)` facing north:

```
victim (3,3),  chasm at (3,2)  [hole]        -> fell=false pushed=true ended (3,1) hp=38/38
victim (6,3),  building at (6,2) [no move]   -> fell=false pushed=true ended (6,1) hp=38/38
victim (10,3), 8-unit pit at (10,2)          -> fell=false pushed=true ended (10,1) hp=38/38
victim (1,5),  an Ent standing at (1,4)      -> ended (1,3), the Ent still at (1,4)
```

The same four cases with `push = 1`:

```
x=3  -> fell=true  (into the chasm, removed)
x=6  -> fell=false pushed=false (the building stops it)
x=10 -> fell=true  (over the lip of the pit)
```

Expected: the target falls into the chasm, is stopped by the building, falls into
the pit, is stopped by the Ent. Actual: in all four it crosses the obstacle and
lands unharmed on the far side. This is a defect in the code, not only a gap in
the tests, and it becomes reachable the moment the items phase generates an
attack with a push above one.

### L1 — the one-seam guarantee is enforced over a hand-written file list

`tests/test_combat_resolution.gd::_combat_sources()` returns a literal list of
**14** paths. Both guarantees the suite makes — "exactly one file calls
`Damage.resolve(`" and "no file of the combat layer names a random number" — are
checked over that list and no further. **Nine combat files are outside it:**

```
sim/board_sketch.gd            sim/combat_snap.gd
sim/combat_board.gd            sim/combatant.gd
sim/combat_board_builder.gd    sim/combatant_roster.gd
sim/combat_policy.gd           sim/encounter.gd
                               sim/scripted_encounter.gd
```

Adding a second `Damage.resolve(...)` call to `sim/combat_policy.gd` leaves every
suite green. `reports/combat.md` states the property as "exactly one file under
`sim/` contains the string `Damage.resolve(`" — which is *true today* (verified
by grepping all 52 files of `sim/`) but is not what is enforced.

The randomness half of the same claim has a backstop the seam half does not:
injections L2 and L3 put `randi()` into `combat_policy.gd` and `encounter.gd`,
and both were caught — not by the source scan, but by the determinism tests
noticing that two processes stopped agreeing. A second call to the damage seam
changes no output, so nothing catches it.

### D2 — the friendly-fire rule of an area attack is unchecked

`CombatResolution.commander_attack()` excludes only the attacker itself
(`standing.id != commander.id`), so an area attack burns the attacker's own
minions. The file's own comment calls this load-bearing: "one rule fewer, and
what stops a wide cheap pattern from being free."

Reproduced — a staff's fireball from `(6,6)` facing north, one of the attacker's
own Toadstools at `(6,2)` and an enemy's at `(7,2)`:

```
hits=2
  its own   minion #3: dealt=2 hp=8/10
  the enemy's minion #4: dealt=2 hp=8/10
```

Changing the exclusion to `standing.owner_id != commander.owner_id` — sparing
your own army, which is what most games do and therefore the most likely wrong
edit — leaves every suite green. Changing it to spare *every* minion (D2b) is
caught, so what is untested is precisely the friendly-fire rule.

### E2 — a refused action is not distinguished from a spent one

`reports/combat.md`: "An action that could not have happened does **not** spend
its slot. An attack still on its cooldown is refused, and the commander may still
swing with a different one." The code does this correctly. Nothing checks it.

Reproduced — a commander holding a two-attack weapon (`heavy`, cooldown 3;
`light`, cooldown 1):

```
round 1: heavy -> ok=true
round 2: heavy -> ok=false  reason=on cooldown
round 2: light -> ok=true             <- the action was not spent
```

Moving `_acted = true` above the `ok` check in `CombatMatch.attack()` — so a
refusal costs the whole turn's weapon action — leaves every suite green.

### S2 — a shove at the board's rim is undefined by omission

`_push()` returns and does nothing when the destination is off the board.
`reports/combat.md` lists "the board's edge" among the things that stop a push.
Nothing checks it. Reproduced — victim on rim cell `(4,0)`, pusher `(4,1)`:

```
board contains (4,-1): false
fell=false pushed=false dealt=0 ended (4,0) hp=38
```

Making that branch a fall instead — kill the target, despawn its army — leaves
every suite green. Either behaviour passes, so the rim case is not decided by the
tests, only by the code.

### N1 — `_slot`'s maintenance across turns cannot be reached

`CombatMatch._reap()` carries a correction — "a commander removed from before the
active one shifts it down a slot" — and `_advance()` carries a fallback for the
active commander itself having been removed (`_slot if at < 0 else at + 1`).
Three injections that remove one, the other, or both leave every suite green
(N1, N1b, N1c).

The reason is structural rather than a missing test. `_advance(ending)` recovers
its position with `_order.find(ending)`, so the carried `_slot` is only read when
that search fails — i.e. when the commander whose turn is ending has already left
the board. It cannot have: the only ways a piece leaves are a capture (minions
only), a blow, and a shove, and `commander_attack()` excludes the attacker from
its own pattern while `_push()` always pushes *away* from the attacker. So the
active commander is never among the reaped, `find()` always succeeds, and
`_slot`'s value between turns has no effect on anything.

Demonstrated: three commanders, #1 flails #2 down over four rounds, and the order
and the active commander come out the same with the correction present or absent:

```
order [1, 2, 3], active #1
after #2 fell: order [1, 3], active #3, round 4
```

---

## 4. The two claims, checked in the code

**"The minion layer contains no random input."** True, and stronger than the
suite's version of it. No file of the combat layer — all 23, not the 14 the suite
scans — contains `randi`, `randf`, `randomize`, `RandomNumberGenerator`, or a
reference to the project's own `Rng`. The capture path reads nothing numeric:
`CombatResolution.capture()` is four statements, none of which names `Damage`, a
health or a level.

**"All player-facing damage passes through one resolution point."** True today.
Across all 52 files of `sim/`, the string `Damage.resolve(` appears exactly once,
at `sim/combat_resolution.gd:87`, and `Piece.wound()` is called from exactly one
place, the line under it. So an attack roll really would be one edit. What is
weak is the *enforcement*, not the property — see L1.

## 5. Determinism and the layer split, re-verified independently

Not taken from the suites. Run from the shell, in separate processes:

| command | result |
|---|---|
| `./run_match.sh` ×2 | identical, 68 lines, `sha256[0:16] = 8b4d427e9ca11dd6` |
| `./run_encounter.sh` ×2 | identical, 126 lines, `afd190aade5c9ac0` |
| `./run_encounter.sh --island` ×2 | identical, 104 lines, `adb9f9e836f57aa0` |
| `./run_headless.sh --seed 1234 --ticks 120` ×2, second with a different `HOME`, `TZ=Asia/Tokyo`, `LANG=de_DE.UTF-8` | identical |
| the same at `--seed 4321` | 30 differing lines — so the comparison above is not vacuous |

All three combat entry points reached a conclusion rather than idling
(`over rounds=3 survivors=1 winner=#1`, `rounds=6`, `rounds=2`). *Read as of the
cycle this review ran: the two encounter figures are now `rounds=4` and
`rounds=3`, and the line counts and hashes in the table above with them, because
the encounter's weapons were later forged onto items rather than handed over as
bare catalogue shapes — `reports/encounter-item-backed.md`. All three still reach
a conclusion, which is what this row claims.*

The layer split was re-checked by hand rather than through `LayerCheck`:

* every `extends` in `sim/`: 50 × `RefCounted`, 2 × `Piece`. No engine node type.
* `sim/` names no `res://render` path, no `render/` fragment, no `.tscn`, no
  `preload(`, and none of the presentation types (`Node3D`, `MeshInstance3D`,
  `Camera3D`, `Material`, `Mesh`, `Shader`, `RenderingServer`, `Input`,
  `get_tree`, `add_child`, `_process`, …) — zero hits, comments included.
* `render/` names no combat class except `CombatBoard`, the stated exception,
  which reaches it as a detached copy through `World.combat_board()`.
* `./run_headless.sh --assets` — of 3 338 visual files in the project, **0 were
  loaded**; of 12 render scripts, **0 were loaded**; 50 of 52 `sim/` scripts were.

## 6. Rules of section 3 checked against the code

| rule | where it lives | verdict |
|---|---|---|
| turn economy — one round is one turn per commander, three things per turn | `combat_match.gd` | holds; ordering, the three flags and refusal all bite |
| the four minion patterns | `minion.gd`, `legal_moves.gd` | holds; each of the four broken separately and each caught |
| facing — patterns rotate, turning is free, minions have none | `attack.gd`, `commander.gd`, `damage.gd` | holds; rotation direction, frame and diagonal boundary all bite |
| movement as armour — base step ∪ one grant per piece | `commander.gd`, `armour.gd` | holds; slot replacement, base retention and reach all bite |
| the damage matrix — one binary pairing, three numeric ones | `combat_resolution.gd`, `damage.gd` | holds; friendly fire is the one rule unchecked (D2) |
| the king rule — a commander's death despawns its army | `piece_map.gd` | holds on both death paths, damage and shove |
| shoves | `combat_resolution.gd` | holds **for a push of one only** (S1) |
| N commanders, no fixed sides | `combat_match.gd`, `combat_policy.gd` | holds; nothing groups two owners; 2, 3 and 5 played |
