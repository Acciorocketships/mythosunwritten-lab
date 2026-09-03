# One character sheet

The project had a character sheet's worth of numbers in two places and no
character. The six ability scores lived in a dictionary hanging off a board
piece, put there so section 4's ability gate could reach the fight; the level
and the hit points lived on the piece itself; and nothing anywhere held a
backstory, a goal or a standing. This task made the sheet a type. `Character`,
in `sim/character.gd`, carries the whole of section 2 — the six scores, the
level, the status, the health, handles for what a character carries and wears,
the four identity fields, and the two handles the memory and sentiment
milestones fill — and `Commander` reads it instead of keeping anything of its
own.

Two words are used throughout and are worth defining once. A **commander** is a
character standing on the combat board: section 3.3's king, the piece whose
death despawns its minions. The **ability gate** is section 4's rule that a
high-level item under-performs for a user whose relevant ability score is too
low, so a score is a number the fight is decided by and not decoration.

Everything below can be re-run: `./run_sheet.sh` prints the worked sheets,
`./run_tests.sh` runs the suites, and `reports/character-sheet-evidence.txt` is
the full transcript of what was run for this report.

---

## 1. The sheet

```
two characters, one type: res://sim/character.gd
  Wren level=3 status=3 hp=38/38 [str 12 con 11 cha 9 dex 14 wis 8 int 10]
      a marsh lantern-keeper's daughter, out of the reeds | goal: find the lantern her mother left on the far bank | traits: curious, stubborn | tendencies: cautious, friendly
      decision function attached: no
  Bramble level=3 status=12 hp=38/38 [str 7 con 8 cha 16 dex 9 wis 13 int 12]
      third child of a blossom-grove house, never in a fight | goal: be owed a favour by everyone who matters | traits: charming, idle | tendencies: greedy, diplomatic
      decision function attached: yes
  fields on each sheet: 14, and the same 14
  scores, level, assigned_status, health, character_name, inventory, equipment, backstory, goal, traits, tendencies, memory, sentiment, decide
```

| section 2 says | on the sheet | filled by |
|---|---|---|
| ability scores STR CON CHA DEX WIS INT | `scores`, keyed by name out of `Ability` | now |
| level — battle strength | `level` | now |
| status — diplomatic standing | `assigned_status`, read through `status()` | now |
| health / HP | `health`, with `max_health()` from the level | now |
| inventory | `inventory` — an empty handle | `W-character-inventory` |
| equipment | `equipment` — an empty handle | `W-character-inventory` |
| backstory / bio | `backstory` | now |
| current goal | `goal` | now |
| personality traits | `traits` | now |
| behavioural tendencies | `tendencies` | now |
| persistent memory | `memory` — an empty handle | the agent milestones |
| sentiment map | `sentiment` — an empty handle | §6 and §13 |

> **Superseded.** The `sentiment` handle in the two lists above is retired. §10
> puts relationships on edges between entities rather than inside a sheet, and
> the world now keeps one `RelationshipGraph`; the field is gone from
> `sim/character.gd`. See [reports/relationships.md](relationships.md).

The two handles that are empty are named now, and deliberately: the alternative
is one type today and an amendment to it later, and then for a while the project
has two answers to "what is a character".

The fourteenth field, `decide`, is the only thing that will ever differ between
a character a person drives and a character an agent drives. Nothing in `sim/`
calls it yet — the atomic action interface is the next work item — and nothing
in `sim/` asks what is on the other end of it.

---

## 2. Status is a separate number, without anyone saying who is a player

Section 2 gives a character two threat numbers: the level is military and the
status is diplomatic, and it adds that "for the player, status = level". Written
literally that sentence needs a field saying which characters are players, which
is exactly the thing this task was not allowed to build.

It is written as a default instead. `assigned_status` starts unassigned, and
`status()` reads the level while it is. So:

```
status is a separate attribute from level
  who        level  status  assigned
  Wren          3       3  -
  Bramble       3      12  12
```

Wren is a character nobody assigned a standing to. Her status is her level, and
stays her level through a level-up, forever, because that is what an unassigned
status *is*. Bramble is a minor noble the orchestrator gave a standing of 12 to
and who has never been in a fight; his two numbers are 3 and 12, and a level-up
moves one of them and not the other. Neither sheet was asked what
kind of character it was.

---

## 3. A level-up is one point on one score

```
one level-up: one point on one score, and nothing else
  when       level  health  str con cha dex wis int
  before         3      38   12  11   9  14   8  10
  after DEX      4      44   12  11   9  15   8  10
```

`Character.level_up` is three lines: one point on the named score, `set_level`
of one more, and a refusal if the name is not one of the six. Nothing else on
the sheet is written, so nothing else on the sheet can move — not the other five
scores, not the status, not a word of the identity, all of which the suite
checks. A refused level-up raises nothing, because a level-up that quietly lost
its point would be worse than one that did not happen.

A point spent on a score nobody has rolled *records* it, at 1. That is a real
change to what the character can use: an unrecorded score reads an item in full
and a recorded 1 does not (§5), so the first point on a score is where the gate
starts to bite on it.

---

## 4. One level, and no copy of it

The acceptance asks that the level health, defence, damage and the item power
budget read is the same level. The tempting way to get that is to keep the sheet
and the board piece in step; the way taken here is to leave the piece nothing to
keep in step *with*.

`Piece.level` and `Piece.health` became properties over a pair of accessors:

```gdscript
var level: int = 1:
	set(to): _write_level(to)
	get: return _read_level()
```

A minion's accessors read `_level` on the minion, as before. A commander's read
`sheet.level` on its character. So a commander holds no copy of its level or its
hit points, and the suite shows the consequence from both ends: after
`sheet.level_up(...)` the piece's level, its `max_health()` and its health have
all moved, and after `piece.wound(5)` the sheet's health has. An item forged at
the commander's level is an item at the sheet's level, with the sheet's level's
budget.

```
  the level everything reads is that one level:
    piece level 4, sheet level 4, health 44/44
    a common helmet forged at that level: P=16, item level 4
```

---

## 5. Nothing moved

`Commander.scores` is gone and `score_for` reads `sheet.score(...)`. The rule it
carries is unchanged, including the part that looks odd out of context: an
*unrecorded* score is not zero, because zero is a real score and a character
with six of them could wear nothing usefully. An unrecorded score reads the item
at the item's own level, which is to say in full.

Ten run scripts were captured from the tree before any edit and again after, and
every one is byte-identical:

| run script | before vs after |
|---|---|
| `./run_items.sh` | identical |
| `./run_loadout.sh` | identical |
| `./run_encounter.sh` | identical |
| `./run_match.sh` | identical |
| `./run_pieces.sh` | identical |
| `./run_resolution.sh` | identical |
| `./run_snap.sh` | identical |
| `./run_drops.sh` | identical |
| `./run_effects.sh` | identical |
| `./run_headless.sh` | identical |

The gate table in particular — one suit of four common level-8 worn items and a
common level-8 sword, read by six different wearers — is the same table on both
sides of the move, and is now asserted row by row in the new suite so that it
cannot drift quietly:

| score | defence | cut | cleave |
|---|---|---|---|
| unrecorded | 6 | 12 | 20 |
| 8 | 6 | 12 | 20 |
| 6 | 4 | 9 | 15 |
| 4 | 3 | 6 | 10 |
| 3 | 2 | 5 | 7 |
| 2 | 1 | 3 | 5 |
| 0 | 0 | 0 | 0 |

The stop condition — stop and report if any combat or item number changes — did
not fire.

Both mutation harnesses were re-run, sequentially and with nothing else running:
`./tools/piece_mutations.sh` caught all 19 of its broken rules and
`./tools/resolution_mutations.sh` all 61 of its. One of the 61 had to follow
`score_for` to its new body — it now replaces
`return sheet.score(read.governing, read.level)` with `return read.level` — and
still fails the suite, so "every wearer reads every item in full" is still a
rule somebody is checking.

Suites: **29 of 29 pass, 191,382 checks**, against 28 and 191,273 before. The
difference is the new suite's 108 checks and one check in the items suite, which
names the files that read the item layer and gained `sim/character.gd` — the
sheet names `Ability`, which is that layer's vocabulary for the gate.

---

## 6. One type, and a scan that looked

Two sheets built identically differ in exactly one field value, `decide`, and
their scripts and field lists are equal. That is reflection over two objects,
which is worth little on its own; the claim that matters is that no *file* under
`sim/` can ask which kind of character it is holding.

So every `.gd` file under `sim/` is read, comments are cut at the first `#` that
is not inside a string (so `"%s#%d"` is a format and not a comment), string
literals are kept (so a branch comparing against `"npc"` is a finding), the rest
is split into words on case and underscore boundaries, and each word is checked
against eleven: *player, players, npc, npcs, human, humans, llm, ai, bot, bots,
robot*. The result over the whole of `sim/` is empty.

An empty result is worth nothing unless the scan can produce a non-empty one, so
it is run in the suite against a control line written to fail it —

```gdscript
const CONTROL_LINE := "func is_player() -> bool:\n\treturn npc_brain == null\n"
```

— and is required to find exactly the two kind-words in it. It is also required
*not* to find them in a comment, and *to* find them in a string literal.

As a second check the same method was appended to a real file for one run:

```
-- the suite as shipped --
character sheet: 108 checks, 0 failed

-- with 'func is_player() -> bool: return decide.is_null()' appended to sim/character.gd --
character sheet: 108 checks, 1 failed
  - sim/ asks which kind of character it holds: res://sim/character.gd names 'player'

-- reverted --
character sheet: 108 checks, 0 failed
```

---

## 7. The world fingerprint, and a stale number on the record

No generation rule was touched, and `./run_headless.sh` is byte-identical before
and after — the same 100 traced ticks, the same chunk, island, village, road and
prop counts, the same digests:

```
tick 0   ... b963fd807b8c432d
tick 50  ... 809a88491e407272
done ticks=100 chunks=41 built=69 final=d178d38879097c1c
```

The acceptance line for this task quotes tick 0 `b963fd807b8c432d`, tick 50
`eb2d8c9369212120` and final `d4e31b0904ff45c0`. The first matches; the other two
do not, and did not match before this task started either. They were superseded
by the roads work, which removed the two-centreline blend from the path carve and
recorded the move itself: `reports/mountains.md` §8.2 states that "the world
fingerprint moved from `d4e31b0904ff45c0` to `d178d38879097c1c` because of it".
So the digests on record are one deliberate, attributed generation change out of
date. What this task can show, and does, is that it moved nothing: the whole
headless run is the same bytes on both sides. The current triple —
`b963fd807b8c432d`, `809a88491e407272`, `d178d38879097c1c` — is what a later
acceptance line should quote.

---

## 8. What is deliberately not here

* **No classes, skills, learned spells or passives.** Six scores, a level and a
  status are the whole of what a character *is*; everything a character can *do*
  stays on an item. There is nothing on the sheet to put a spell in.
* **No language model, no prompt, no network call.** `decide` is a handle with
  nothing on the other end of it and nothing in `sim/` calls it.
* **No panel.** The sheet is data. Nothing under `sim/` names a render class, a
  font, a texture or an asset path, and `bin/check_layers.gd` still passes all
  three of its checks.
* **No inventory yet.** `inventory` and `equipment` are named and empty; what a
  character carries and what it has on is the next work item. Until then a
  commander's worn `armour` and held `weapon` are still the board's own, which is
  the one place the project still has a sheet's field in two forms — and closing
  that is that item's job, not this one's.
