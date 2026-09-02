# One inventory, and equipment as a view onto it

The character sheet named two things it did not have. `inventory` was an empty
`Array` and `equipment` an empty `Dictionary`, while what a character on the
board actually wore lived somewhere else entirely — `Commander.armour` and
`Commander.weapon`, two fields of the board piece. So the project had a
character who owned nothing and a piece wearing things nobody owned. This task
closed that: `sim/inventory.gd` is the one place a character's belongings live,
and what it has on is a slot of that inventory pointing at one of the things it
carries.

Three words are used throughout. A **commander** is a character standing on the
combat board — section 3.3's king, the piece whose death despawns its minions. An
item's **power budget** is section 4's one formula, $P = r(\text{rarity}) \times
L_{\text{source}}$, split across movement, defence and effects; the **ability
gate** is section 4's rule that a high-level item under-performs for a user whose
relevant ability score is too low, $v_{\text{eff}} = \lfloor v \cdot \min(A, L) /
L \rfloor$ for a score $A$ and an item level $L$. Neither of the last two was
touched here — this task consumes them.

Everything below can be re-run: `./run_inventory.sh` prints the worked cases,
`./run_inventory_suite.sh` runs the suite on its own, `./run_tests.sh` runs all
thirty, `./tools/inventory_mutations.sh` breaks each rule on purpose, and
`reports/inventory-evidence.txt` is the full transcript.

---

## 1. One store, and a view

```
one inventory: what a character carries, and what it has on
  Wren level=8 status=8 hp=68/68 [str - con - cha - dex - wis - int -]
  inventory: 5 carried, 5 equipped, 50 money
  carried:
    * common armour boots L8 P=32 mov=4 def=28 eff=0 dex [] common boots
    * common armour leggings L8 P=32 mov=8 def=24 eff=0 dex [] common leggings
    * common armour chestplate L8 P=32 mov=16 def=16 eff=0 con [] common chestplate
    * common armour helmet L8 P=32 mov=0 def=32 eff=0 con [] common helmet
    * common weapon hand L8 P=32 mov=0 def=0 eff=32 str [sword:32] common sword
  equipped, by slot (the starred rows above, and nothing else):
    boots      common armour boots L8 P=32 mov=4 def=28 ...
    ...
  every equipped thing is carried: yes, all 5 of them
  a legendary helmet nobody handed over: carried no, equipping it refused
```

The starred rows *are* the equipped rows. `Inventory` holds one list, `carried`,
and one dictionary, `_equipped`, whose values are elements of that list.
`equip()` refuses anything the inventory is not already carrying, and `release()`
clears the slot before it removes anything. So "nothing can be worn or held that
the character does not have" is not a check somebody remembered to write — there
is nowhere else for a worn thing to be. `Character.equipment` is a getter with no
setter that returns `inventory.equipment()`, rebuilt on every read.

`Commander.armour` and `Commander.weapon` went the same way: both are now getters
over `sheet.inventory.worn()` and `sheet.inventory.held()`. The suite shows this
structurally rather than by assertion — releasing the chestplate from the
character's inventory leaves the commander wearing two pieces instead of three,
which could not happen if the board held a copy.

## 2. No board number moved

The published six-wearer table, one suit of four common level-8 worn items and a
common level-8 sword, printed by `./run_loadout.sh` after the change:

| score | fraction of the item | chestplate reach | defence | cut | cleave | cells reached |
|---|---|---|---|---|---|---|
| 8 | 100% | 2 | 6 | 12 | 20 | 21 |
| 6 | 75% | 1 | 4 | 9 | 15 | 8 |
| 4 | 50% | 1 | 3 | 6 | 10 | 8 |
| 3 | 37% | 0 | 2 | 5 | 7 | 4 |
| 2 | 25% | 0 | 1 | 3 | 5 | 4 |
| 0 | 0% | 0 | 0 | 0 | 0 | 4 |

Every row is identical to the one `reports/loadout.md` published before this
task, and `tests/test_inventory.gd` asserts the defence, cut and cleave columns
row by row against a commander whose gear lives in its character's inventory. The
task's stop condition — stop and report if holding equipment as a view would
change any board number — did not fire.

What equipping is worth, one piece at a time, and the same numbers coming back
off:

| worn | defence | grants | move-cells | attacks | cut | cleave |
|---|---|---|---|---|---|---|
| nothing | 0 | 1 | 4 | 0 | 0 | 0 |
| + boots | 1 | 2 | 8 | 0 | 0 | 0 |
| + leggings | 3 | 3 | 16 | 0 | 0 | 0 |
| + chestplate | 4 | 4 | 24 | 0 | 0 | 0 |
| + helmet | 6 | 4 | 24 | 0 | 0 | 0 |
| + sword | 6 | 4 | 24 | 2 | 12 | 20 |
| − sword | 6 | 4 | 24 | 0 | 0 | 0 |
| − helmet | 4 | 4 | 24 | 0 | 0 | 0 |
| − chestplate | 3 | 3 | 16 | 0 | 0 | 0 |
| − leggings | 1 | 2 | 8 | 0 | 0 | 0 |
| − boots | 0 | 1 | 4 | 0 | 0 | 0 |

The gear is still carried at the bottom of that table — five things, none of them
on — because taking a breastplate off is not the same as leaving it on the floor.
Nothing in this table is stored anywhere: defence is `Armour.reduction` over the
defence axes of what is equipped, the grants are what each item's movement axis
paid for, and the two damage columns are the sword's effects axis divided by the
catalogue's weights. Moving the gear into the inventory changed where the loop
finds the items, not what it reads off them.

## 3. The ground, and the drop

A pile on the ground is an `Inventory` with nobody attached, which makes picking
something up, dropping it, handing it over and paying for it one operation:

```
  the ground: 1 carried, 0 equipped, 0 money
    rare armour boots L8 P=72 mov=4 def=68 eff=0 dex [] rare boots
  Wren takes them:      moved -- ground 0 carried, Wren 6 carried, 5 equipped
  and puts them on:     worn yes
  Wren drops them back: moved -- ground 1 carried, Wren 5 carried, 4 equipped
  dropping took them off on the way out: worn no, carried no
```

Defeat uses the drop path the item layer already had. `Inventory.spill_into()`
calls `ItemDrop.verdicts()` over what is carried, in carried order, and moves the
entries whose items fell — it rolls nothing itself, so the one-in-five rate and
the addressed streams are exactly the drop layer's:

```
    drop:goblin-42#0:common boots  roll   4  dropped
    drop:goblin-42#1:common leggin roll  78  stayed on the body
    drop:goblin-42#2:common chestp roll  95  stayed on the body
    drop:goblin-42#3:common helmet roll  23  stayed on the body
    drop:goblin-42#4:common sword  roll  28  stayed on the body
  which is the drop layer's own verdict, unchanged:
    goblin-42: 1 of 5 dropped
  Thistle walks up and takes everything on the ground:
    took and wore common armour boots L8 ...
  and on the board that loot is defence 1, 8 move-cells, 0 attacks
```

That is the end-to-end case the acceptance asks for, in one headless run: a
defeated character's gear lands somewhere a second character can walk up to, take
and wear, and it is worth something on the board once worn.

The one thing the drop *cannot* do yet is hand over a weapon that swings. What
the forge produces is an `Item` with a shape name out of its own list ("blade",
"buckler"), and an attack pattern comes from the weapon catalogue ("sword",
"shield"); the two lists do not meet, and making them meet is a design decision
about which catalogue shape a forged blade is, which this task has no mandate to
take. So an item taken up bare is `Weapon.around(item)`: it defends its holder out
of its own defence axis and carries no attack. Putting a catalogue shape behind a
looted item is one existing call, `Weapon.from_item(shape, item)`.

## 4. Money, and giving

Money is one integer on the inventory. `transfer()` moves entries and coins one
way, all or nothing; `trade()` is two transfers checked together, so nobody is
left having paid for something that did not arrive.

| when | Wren | Bramble |
|---|---|---|
| at the start | 30 coins, 1 item | 120 coins, 0 items |
| a sale: the dagger out, 45 back | 75 coins, 0 items | 75 coins, 1 item |
| the other way, sold back for 40 | 35 coins, 1 item | 115 coins, 0 items |
| a gift: the dagger and 25 coins, nothing back | 10 coins, 0 items | 140 coins, 1 item |

Section 2.1 defines giving as "a trade with nothing in return", and that is what
the fourth row is: the same `trade()` call with the return side empty. There is no
`give()` function, because there is nothing for it to do that this does not.
A trade for more coins than the giver has moves nothing at all — neither the
coins nor the items — and so does a transfer, which matters more than it sounds:
without that guard the payer would refuse and the receiver would still be
credited, which is money made out of nothing.

## 5. Order is not part of what you own

```
  acquired and worn forwards:  boots leggings chestplate helmet hand
  acquired and worn backwards: boots leggings chestplate helmet hand
  the two fingerprints agree: yes
  and on the board: def 6/6, move-cells 24/24, cut 12/12
```

Two characters bought the same five things in opposite orders and put them on in
opposite orders. What is worn comes back in the slot order `Commander` has sorted
its armour into since the loadout landed, and `fingerprint()` sorts what is
carried, so the two are one string. The suite also asserts the worn order
explicitly — boots, chestplate, helmet, leggings — because "the two agree" would
still hold if both were wrong the same way.

## 6. What was run

| command | result |
|---|---|
| `./run_tests.sh` | all 30 suites passed, 191,473 checks |
| `./run_inventory_suite.sh` | PASS, 90 checks |
| `./tools/inventory_mutations.sh` | all 12 broken rules caught |
| `./tools/piece_mutations.sh` | all 19 broken rules caught |
| `./tools/resolution_mutations.sh` | all 61 broken rules caught |
| `./run_headless.sh` | seed 1234: `b963fd807b8c432d` / `809a88491e407272` / `d178d38879097c1c` |
| `./run_loadout.sh` | the six-wearer table above, unmoved |

The three fingerprints are the triple `reports/character-sheet.md` §7 records as
current, so the world did not move — no generation rule was touched.

The mutation harness is new and is the reason the suite's claims are worth
something. Two of its twelve mutations survived the first run — reversing the
worn-order sort, and dropping the overdraft guard from `transfer()` — and both
were real holes in the suite rather than harmless edits; the checks that close
them are in `tests/test_inventory.gd` §4 and §5.

## 7. What is deliberately not here

* **No UI.** An inventory is data. Nothing under `sim/` names a render class, a
  scene or an asset path, and `bin/check_layers.gd` still passes all three
  checks.
* **No language model, no prompt, no network call.**
* **No change to the power budget.** How $P$ is computed and split is untouched;
  this layer reads it.
* **No consumables yet.** Section 2 lists them among what an inventory holds and
  the inventory will hold one — an entry is anything with an `Item` behind it —
  but nothing in the project yet says what *using* one does, and inventing that
  here would be inventing a rule.
* **No trade action.** `trade()` is the item-layer operation two characters'
  inventories go through. The atomic action that proposes, accepts and denies one
  is `W-atomic-actions`.
