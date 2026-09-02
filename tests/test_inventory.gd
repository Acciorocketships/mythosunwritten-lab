extends TestSuite
## One inventory per character, and what is equipped is a view onto it.
##
## Six claims:
##
##   1. There is one store. What a character has on is a slot of its inventory
##      pointing at something that inventory carries: equipping what is not
##      carried is refused, letting something go takes it off on the way out, and
##      taking something off leaves it carried. Shown structurally as well as by
##      the interface -- releasing an entry from the inventory empties the
##      commander's loadout, which could not happen if the board held a copy.
##   2. Equipping and unequipping move defence, movement grants and attack
##      patterns, and they move them through the item budget and the ability
##      gate. The published six-wearer table is asserted row by row, so if any
##      board number had moved when the gear moved into the inventory, this
##      fails.
##   3. An item is picked up off the ground and dropped back onto it, by the same
##      `transfer` a gift goes through; and the drop the defeat path already
##      rolls puts the loser's gear on the ground, where somebody else takes it
##      and wears it.
##   4. Money is the inventory's, and a trade moves it in either direction. A
##      gift is that same trade with nothing coming back, which is section 2.1's
##      own definition; a trade nobody can pay for moves nothing at all.
##   5. Two characters that acquired and put on the same things in opposite
##      orders are the same character: one fingerprint, one worn order, one set
##      of board numbers.
##   6. The documented command runs twice in two processes and prints the same
##      bytes.
class_name TestInventory

## The level every worked loadout in this suite is forged at.
const LEVEL := 8

## The gate table `./run_loadout.sh` publishes and `tests/test_character_sheet.gd`
## already asserts: one suit of four common level-8 worn items and a common
## level-8 sword, read by wearers of six ability scores. Repeated here against a
## commander whose gear lives in its character's inventory, because the claim
## this task has to make good is that moving it there moved no number.
## Each row is score, defence, cut, cleave.
const GATE_ROWS := [
	[8, 6, 12, 20],
	[6, 4, 9, 15],
	[4, 3, 6, 10],
	[3, 2, 5, 7],
	[2, 1, 3, 5],
	[0, 0, 0, 0],
]

## The seed and the kill the drop case is rolled against, which are the ones
## `bin/inventory_main.gd` prints.
const SEED := 1234
const KILL := "goblin-42"


func _init() -> void:
	suite_name = "inventory"


func run() -> void:
	_one_store_and_a_view_onto_it()
	_equipping_reads_the_budget_and_the_gate()
	_the_ground_and_the_drop()
	_money_moves_either_way()
	_order_is_not_part_of_what_is_owned()
	_two_processes_agree()


# --- 1. One store ----------------------------------------------------------


func _one_store_and_a_view_onto_it() -> void:
	var sheet := Character.make("Wren", LEVEL)
	var boots := Armour.worn(Armour.BOOTS, LEVEL)
	var sword := Weapon.held(Weapon.sword(), LEVEL)

	# Nothing can be worn that is not carried. This is the acceptance in one line.
	check(not sheet.inventory.equip(boots),
		"an inventory equipped a piece it was not carrying")
	equal(sheet.equipment.size(), 0, "and put it in a slot anyway")

	check(sheet.inventory.carry(boots), "the inventory refused to carry the boots")
	check(sheet.inventory.equip(boots), "and then refused to put on what it carries")
	equal(sheet.equipment.size(), 1, "one thing on")
	equal(sheet.inventory.size(), 1, "and the same one thing carried")
	check(sheet.equipment[Armour.BOOTS] == boots,
		"the boots slot holds something other than the boots carried")

	# Carrying twice is carrying once: two of one object is not two objects.
	check(not sheet.inventory.carry(boots), "the same object was carried twice")
	equal(sheet.inventory.size(), 1, "and counted twice")

	# Everything equipped is carried, always. Checked over a whole loadout.
	sheet.inventory.take_up(sword)
	for slot in Armour.SLOTS:
		sheet.inventory.take_up(Armour.worn(slot, LEVEL))
	for slot in sheet.equipment:
		check(sheet.inventory.has(sheet.equipment[slot]),
			"%s is worn and not carried" % slot)
	equal(sheet.equipment.size(), 5, "four worn slots and a hand")
	equal(sheet.inventory.size(), 6,
		"the boots that were replaced are still carried, unworn")

	# Taking something off leaves it carried; letting it go takes it off.
	var helmet: Variant = sheet.equipment[Armour.HELMET]
	check(sheet.inventory.unequip(Armour.HELMET) == helmet,
		"unequipping did not hand back what came off")
	check(sheet.inventory.has(helmet), "taking a helmet off threw it away")
	check(not sheet.inventory.is_equipped(helmet), "and left it worn")
	check(sheet.inventory.release(helmet), "the helmet could not be let go of")
	check(not sheet.inventory.has(helmet), "and was still carried afterwards")

	# The structural half: the board holds no copy. Release the chestplate from
	# the inventory and the commander is not wearing one -- which is only
	# possible if `Commander.armour` is a view.
	var commander := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	commander.adopt(sheet)
	var plate: Variant = sheet.equipment[Armour.CHESTPLATE]
	equal(commander.armour.size(), 3, "the commander wears what its character has on")
	check(commander.worn_in(Armour.CHESTPLATE) == plate,
		"the commander's chestplate is not its character's chestplate")
	sheet.inventory.release(plate)
	equal(commander.armour.size(), 2,
		"the commander kept a chestplate its character no longer has")
	check(commander.worn_in(Armour.CHESTPLATE) == null,
		"and still answers with it by slot")

	# The same for the hand.
	check(commander.weapon == sword, "the commander holds what its character holds")
	sheet.inventory.release(sword)
	check(commander.weapon == null, "the commander kept a sword nobody has")
	equal(commander.attack_count(), 0, "and could still swing it")


# --- 2. The budget and the gate --------------------------------------------


func _equipping_reads_the_budget_and_the_gate() -> void:
	var commander := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	var bare_defence := commander.defence()
	var bare_grants := commander.move_grants().size()
	equal([bare_defence, bare_grants, commander.attack_count()], [0, 1, 0],
		"a commander with nothing on has no defence, one grant and no attack")

	for slot in Armour.SLOTS:
		commander.equip(Armour.worn(slot, LEVEL))
	commander.wield(Weapon.held(Weapon.sword(), LEVEL))
	equal(commander.move_grants().size(), 4,
		"the base plus a grant for each piece that paid for one")
	equal(commander.attack_count(), 2, "the sword's two attacks")
	check(commander.defence() > 0, "a whole suit stops nothing")

	# The published table, row by row. Every number here is read off the item
	# budget through the gate, out of the character's inventory.
	for row in GATE_ROWS:
		for ability in Ability.ALL:
			commander.set_score(ability, int(row[0]))
		equal([commander.defence(), commander.damage_of(0), commander.damage_of(1)],
			[int(row[1]), int(row[2]), int(row[3])],
			"the gate table moved at score %d" % int(row[0]))

	# Unequipping takes the numbers back off, and the gear is still carried.
	for ability in Ability.ALL:
		commander.set_score(ability, LEVEL)
	var dressed_defence := commander.defence()
	var dressed_cells := _attack_cells(commander)
	commander.sheet.inventory.unequip(Item.SLOT_HAND)
	equal(commander.attack_count(), 0, "the sword came off and left its attacks")
	for slot in Armour.SLOTS:
		commander.unequip(slot)
	equal([commander.defence(), commander.move_grants().size()],
		[bare_defence, bare_grants],
		"taking everything off did not put the commander back where it started")
	equal(commander.sheet.inventory.size(), 5, "and threw the gear away doing it")

	# Putting it back on puts the numbers back, from the same objects.
	for entry in commander.sheet.inventory.carried:
		commander.sheet.inventory.equip(entry)
	equal([commander.defence(), _attack_cells(commander)],
		[dressed_defence, dressed_cells],
		"the same gear put back on is worth something different")

	# The item is unchanged by any of it: the gate is on the reading.
	var plate := commander.worn_in(Armour.CHESTPLATE)
	equal([plate.item.level, plate.item.budget()], [LEVEL, ItemBudget.total(ItemRarity.COMMON, LEVEL)],
		"the chestplate's own budget moved when it was worn")


# --- 3. The ground and the drop --------------------------------------------


func _the_ground_and_the_drop() -> void:
	var sheet := Character.make("Wren", LEVEL)
	var boots := Armour.worn(Armour.BOOTS, LEVEL, ItemRarity.RARE)
	var pile := Inventory.ground([boots])
	equal([pile.size(), sheet.inventory.size()], [1, 0], "the ground has the boots")

	check(Inventory.transfer(pile, sheet.inventory, [boots]),
		"the boots could not be picked up")
	equal([pile.size(), sheet.inventory.size()], [0, 1],
		"picking up did not move them")
	check(sheet.inventory.equip(boots), "picked-up boots could not be put on")

	check(Inventory.transfer(sheet.inventory, pile, [boots]),
		"the boots could not be dropped")
	equal([pile.size(), sheet.inventory.size()], [1, 0], "dropping did not move them")
	check(pile.carried[0] == boots, "the ground got something else back")
	check(not sheet.inventory.is_equipped(boots),
		"dropping the boots left them on the character's feet")

	# Nothing can be taken from a pile that does not have it.
	check(not Inventory.transfer(pile, sheet.inventory, [Armour.worn(Armour.HELMET, LEVEL)]),
		"a helmet was taken off a pile that never held one")
	equal(sheet.inventory.size(), 0, "and arrived anyway")

	# Defeat, through the drop path the item layer already has.
	var loser := Character.make("Bramble", LEVEL)
	for slot in Armour.SLOTS:
		loser.inventory.take_up(Armour.worn(slot, LEVEL))
	loser.inventory.take_up(Weapon.held(Weapon.sword(), LEVEL))
	var before := loser.inventory.items()
	var expected := ItemDrop.drops(SEED, KILL, before)

	var ground := Inventory.ground()
	var fell: Array = loser.inventory.spill_into(ground, SEED, KILL)
	equal(fell.size(), expected.size(),
		"the inventory's drop and the drop layer's drop disagree on how many fell")
	for index in fell.size():
		check(Inventory.item_of(fell[index]) == expected[index],
			"the inventory dropped something the drop layer did not")
	equal(ground.size(), expected.size(), "what fell is not on the ground")
	equal(loser.inventory.size(), before.size() - expected.size(),
		"the loser is still carrying what it dropped")
	for entry in ground.carried:
		check(not loser.inventory.has(entry), "a dropped item is in two places")

	# And somebody takes it and wears it, and it is worth something on a board.
	check(expected.size() > 0,
		"this kill dropped nothing, so the case shows nothing (pick another kill)")
	var finder := Character.make("Thistle", LEVEL)
	check(Inventory.transfer(ground, finder.inventory, ground.carried.duplicate()),
		"the loot could not be taken off the ground")
	equal(ground.size(), 0, "the ground still holds the loot")
	for entry in finder.inventory.carried:
		check(finder.inventory.equip(entry), "taken loot could not be worn")
	var commander := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	commander.adopt(finder)
	check(commander.defence() > 0 or commander.attack_count() > 0,
		"loot picked up off the ground is worth nothing on the board")


# --- 4. Money --------------------------------------------------------------


func _money_moves_either_way() -> void:
	var seller := Inventory.of([], 30)
	var buyer := Inventory.of([], 120)
	var blade := Weapon.held(Weapon.dagger(), LEVEL)
	seller.carry(blade)

	# Out one way.
	check(Inventory.trade(seller, buyer, [blade], 0, [], 45), "the sale was refused")
	equal([seller.money, buyer.money], [75, 75], "the coins did not move")
	check(buyer.has(blade) and not seller.has(blade), "the dagger did not move")

	# And back the other.
	check(Inventory.trade(buyer, seller, [blade], 0, [], 40),
		"the sale could not be reversed")
	equal([seller.money, buyer.money], [35, 115], "the coins did not move back")
	check(seller.has(blade) and not buyer.has(blade), "the dagger did not come back")

	# A gift is a trade with nothing coming back. Section 2.1's own definition.
	check(Inventory.trade(seller, buyer, [blade], 25), "the gift was refused")
	equal([seller.money, buyer.money], [10, 140], "the gift moved the wrong coins")
	check(buyer.has(blade), "the gift did not arrive")

	# What cannot happen: paying with money that is not there.
	check(not Inventory.trade(seller, buyer, [], 9999),
		"an inventory paid more than it had")
	equal([seller.money, buyer.money], [10, 140], "and the coins moved anyway")
	check(not seller.pay(11), "an inventory paid out more than it held")
	equal(seller.money, 10, "and the purse moved")

	# The one-way move has the same guard, and it is the guard that matters:
	# without it a transfer would take coins the giver never had and the
	# receiver would still be credited, which is money made out of nothing.
	check(not Inventory.transfer(seller, buyer, [], 500),
		"a transfer moved coins the giver did not have")
	equal([seller.money, buyer.money], [10, 140],
		"and a refused transfer still moved coins")
	seller.gain(5)
	equal(seller.money, 15, "coins taken in did not arrive")

	# Nothing moves when any part of a trade cannot happen.
	var stranger := Armour.worn(Armour.HELMET, LEVEL)
	check(not Inventory.trade(seller, buyer, [stranger], 5),
		"an inventory gave away something it did not have")
	equal([seller.money, buyer.money], [15, 140],
		"and the coins of a refused trade moved")


# --- 5. Order --------------------------------------------------------------


func _order_is_not_part_of_what_is_owned() -> void:
	var forwards := Character.make("Wren", LEVEL)
	var backwards := Character.make("Bramble", LEVEL)
	var slots := Armour.SLOTS.duplicate()
	var reversed_slots := slots.duplicate()
	reversed_slots.reverse()

	for slot in slots:
		forwards.inventory.take_up(Armour.worn(slot, LEVEL))
	forwards.inventory.take_up(Weapon.held(Weapon.sword(), LEVEL))
	backwards.inventory.take_up(Weapon.held(Weapon.sword(), LEVEL))
	for slot in reversed_slots:
		backwards.inventory.take_up(Armour.worn(slot, LEVEL))
	forwards.inventory.gain(70)
	backwards.inventory.gain(70)

	equal(forwards.inventory.fingerprint(), backwards.inventory.fingerprint(),
		"two inventories with the same contents in different orders differ")
	equal(_slots_of(forwards), _slots_of(backwards),
		"two characters wear the same pieces in different slot orders")

	# And the order is the slot order Commander has always sorted its armour
	# into, not the order the pieces were put on. Written out, because "the two
	# agree" would still hold if both were wrong in the same way.
	var worn := PackedStringArray()
	for piece in forwards.inventory.worn():
		worn.append(piece.slot)
	equal(worn, PackedStringArray([
		Armour.BOOTS, Armour.CHESTPLATE, Armour.HELMET, Armour.LEGGINGS,
	]), "what is worn does not come back in slot order")

	var left := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	var right := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	left.adopt(forwards)
	right.adopt(backwards)
	equal(_loadout_of(left), _loadout_of(right),
		"two commanders in the same gear, equipped in different orders, differ")
	equal(left.loadout_line(), right.loadout_line(),
		"and print different loadout lines")

	# The order is really different, so the agreement above is worth something.
	var forward_names := PackedStringArray()
	for entry in forwards.inventory.carried:
		forward_names.append(Inventory.slot_of(entry))
	var backward_names := PackedStringArray()
	for entry in backwards.inventory.carried:
		backward_names.append(Inventory.slot_of(entry))
	not_equal(forward_names, backward_names,
		"the two inventories were filled in the same order after all")


# --- 6. Two processes ------------------------------------------------------


func _two_processes_agree() -> void:
	var first := _run_inventory()
	var second := _run_inventory()
	equal(first["exit_code"], 0, "the documented command failed")
	equal(first["output"], second["output"],
		"two runs of ./run_inventory.sh printed different bytes")
	not_equal(first["output"], "", "the run printed something")


func _run_inventory() -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/inventory_main.gd",
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


# --- Helpers ---------------------------------------------------------------


## Which slots a character has filled, in the order its equipment view reports.
func _slots_of(sheet: Character) -> PackedStringArray:
	var slots := PackedStringArray()
	for slot in sheet.equipment:
		slots.append(slot)
	return slots


## Every board number a loadout is worth, in one comparable value.
func _loadout_of(commander: Commander) -> Array:
	var grants := PackedStringArray()
	for grant in commander.move_grants():
		grants.append(grant.line())
	return [
		commander.defence(), grants, commander.attack_count(),
		commander.damage_of(0), commander.damage_of(1),
	]


## How many cells the held weapon's attacks cover from where the commander is.
func _attack_cells(commander: Commander) -> int:
	var covered := 0
	for index in commander.attack_count():
		covered += commander.attack_cells(index).size()
	return covered
