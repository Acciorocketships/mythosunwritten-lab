extends SceneTree
## Print what a character carries and what it has on, headless. Nothing else.
##
## Run it with:  ./run_inventory.sh
##
## Every number below is read off `sim/` -- one inventory per character, the item
## power budget, the ability-score gate, and the drop roll the defeat path
## already makes. Nothing here draws a random number outside that roll and
## nothing reads a clock, so two runs print the same bytes.

## The seed the drop roll is made against. One number, written here, so the
## verdicts below are reproducible and can be checked against `./run_drops.sh`.
const SEED := 1234

## Who is defeated, as the drop layer addresses a kill. The stream one item's
## verdict is drawn from is built from this and the item's place in what was
## carried, so the same kill drops the same things every run.
const KILL := "goblin-42"

## The level the worked loadout is forged at, and the level of the two
## characters wearing it.
const LEVEL := 8


func _initialize() -> void:
	_one_inventory()
	_equipping_reads_the_budget()
	_the_ground()
	_defeat_puts_it_on_the_ground()
	_money_moves_both_ways()
	_order_is_not_part_of_what_you_own()
	quit(0)


# --- 1. One inventory ------------------------------------------------------


func _one_inventory() -> void:
	print("one inventory: what a character carries, and what it has on")
	var wren := _outfitted("Wren")
	print("  %s" % wren.sheet_line())
	print("  inventory: %s" % wren.inventory.line())
	print("  carried:")
	for entry in wren.inventory.carried:
		print("    %s%s" % [
			"* " if wren.inventory.is_equipped(entry) else "  ",
			Inventory.entry_line(entry),
		])
	print("  equipped, by slot (the starred rows above, and nothing else):")
	for slot in wren.equipment:
		print("    %-10s %s" % [slot, Inventory.entry_line(wren.equipment[slot])])
	print("  every equipped thing is carried: %s" % _every_equipped_is_carried(wren))

	# What cannot happen: wearing something the character does not have.
	var stranger := Armour.worn(Armour.HELMET, LEVEL, ItemRarity.LEGENDARY)
	print("  a legendary helmet nobody handed over: carried %s, equipping it %s" % [
		"yes" if wren.inventory.has(stranger) else "no",
		"succeeded" if wren.inventory.equip(stranger) else "refused",
	])
	print("  and the helmet slot still holds: %s" % Inventory.entry_line(
		wren.inventory.equipped_in(Armour.HELMET)))
	print("")


# --- 2. Equipping, through the budget and the gate --------------------------


func _equipping_reads_the_budget() -> void:
	print("equipping and unequipping, read through the item budget and the gate")
	print("  a level-%d suit and sword, put on one piece at a time" % LEVEL)
	print("  worn                     def  grants  move-cells  attacks  cut  cleave")
	var commander := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	_loadout_row(commander, "nothing")
	for slot in Armour.SLOTS:
		commander.equip(Armour.worn(slot, LEVEL))
		_loadout_row(commander, "+ %s" % slot)
	commander.wield(Weapon.held(Weapon.sword(), LEVEL))
	_loadout_row(commander, "+ sword")

	print("  and back off again, one piece at a time -- the numbers return:")
	commander.sheet.inventory.unequip(Item.SLOT_HAND)
	_loadout_row(commander, "- sword")
	var backwards := Armour.SLOTS.duplicate()
	backwards.reverse()
	for slot in backwards:
		commander.unequip(slot)
		_loadout_row(commander, "- %s" % slot)
	print("  it still carries all five: %d things, %d equipped" % [
		commander.sheet.inventory.size(), commander.sheet.equipment.size(),
	])

	# The gate reaches the same numbers through the inventory, unchanged.
	print("  everything put back on, and read by wearers of five ability scores:")
	print("  score  def  cut  cleave  move-cells")
	for entry in commander.sheet.inventory.carried:
		commander.sheet.inventory.equip(entry)
	for score in [LEVEL, 6, 4, 2, 0]:
		for ability in Ability.ALL:
			commander.set_score(ability, score)
		print("  %5d %4d %4d %7d %11d" % [
			score, commander.defence(), commander.damage_of(0),
			commander.damage_of(1), _move_cells(commander),
		])
	print("")


# --- 3. The ground ---------------------------------------------------------


func _the_ground() -> void:
	print("picking something up off the ground, and dropping it back")
	var wren := _outfitted("Wren")
	var boots := Armour.worn(Armour.BOOTS, LEVEL, ItemRarity.RARE)
	var pile := Inventory.ground([boots])
	print("  the ground: %s" % pile.line())
	print("    %s" % Inventory.entry_line(boots))

	print("  Wren takes them:      %s" % _moved(
		Inventory.transfer(pile, wren.inventory, [boots]), pile, wren))
	wren.inventory.equip(boots)
	print("  and puts them on:     worn %s, and the boots slot now holds" % (
		"yes" if wren.inventory.is_equipped(boots) else "no"))
	print("    %s" % Inventory.entry_line(wren.inventory.equipped_in(Armour.BOOTS)))
	print("  Wren drops them back: %s" % _moved(
		Inventory.transfer(wren.inventory, pile, [boots]), pile, wren))
	print("  dropping took them off on the way out: worn %s, carried %s" % [
		"yes" if wren.inventory.is_equipped(boots) else "no",
		"yes" if wren.inventory.has(boots) else "no",
	])
	print("  and the boots slot is empty: %s -- Wren's own pair is carried still" % (
		"yes" if wren.inventory.equipped_in(Armour.BOOTS) == null else "no"))
	print("  and the ground has them again: %s" % Inventory.entry_line(pile.carried[0]))
	print("")


# --- 4. Defeat -------------------------------------------------------------


func _defeat_puts_it_on_the_ground() -> void:
	print("defeat drops loot where somebody else can take it")
	var loser := _outfitted("Bramble")
	print("  %s carried %d things worth %d points in all" % [
		loser.character_name, loser.inventory.size(),
		ItemFrontier.total_budget(loser.inventory.items()),
	])
	var pile := Inventory.ground()
	var before := loser.inventory.items()
	loser.inventory.spill_into(pile, SEED, KILL)
	print("  the drop roll, one stream per item, at seed %d against %s:" % [SEED, KILL])
	for index in before.size():
		print("    %-30s roll %3d  %s" % [
			ItemDrop.stream_label(KILL, index, before[index]).substr(0, 30),
			ItemDrop.roll(SEED, KILL, index, before[index]),
			"dropped" if ItemDrop.falls(SEED, KILL, index, before[index])
				else "stayed on the body",
		])
	print("  which is the drop layer's own verdict, unchanged:")
	print("    %s" % ItemDrop.line(SEED, KILL, before).split(" [")[0])
	print("  the loser now carries %d, the ground carries %d" % [
		loser.inventory.size(), pile.size(),
	])

	var finder := _bare("Thistle")
	print("  %s walks up and takes everything on the ground:" % finder.character_name)
	Inventory.transfer(pile, finder.inventory, pile.carried.duplicate())
	for entry in finder.inventory.carried:
		finder.inventory.equip(entry)
		print("    took and wore %s" % Inventory.entry_line(entry))
	print("  the ground is empty: %s" % pile.line())
	var commander := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	commander.adopt(finder)
	print("  and on the board that loot is defence %d, %d move-cells, %d attacks" % [
		commander.defence(), _move_cells(commander), commander.attack_count(),
	])
	print("")


# --- 5. Money --------------------------------------------------------------


func _money_moves_both_ways() -> void:
	print("money is a quantity the inventory owns, and a trade moves it either way")
	var seller := _bare("Wren")
	var buyer := _bare("Bramble")
	seller.inventory.gain(30)
	buyer.inventory.gain(120)
	var blade := Weapon.held(Weapon.dagger(), LEVEL)
	seller.inventory.carry(blade)
	_purses("at the start", seller, buyer)

	print("  a sale: the dagger out, 45 coins back")
	Inventory.trade(seller.inventory, buyer.inventory, [blade], 0, [], 45)
	_purses("after the sale", seller, buyer)
	print("    the dagger is the buyer's: %s" % (
		"yes" if buyer.inventory.has(blade) else "no"))

	print("  the other way: the buyer sells it back for 40")
	Inventory.trade(buyer.inventory, seller.inventory, [blade], 0, [], 40)
	_purses("after the return", seller, buyer)

	print("  a gift, which is a trade with nothing coming back:")
	Inventory.trade(seller.inventory, buyer.inventory, [blade], 25)
	_purses("after the gift", seller, buyer)
	print("    the buyer gave back: 0 items, 0 coins")

	print("  what cannot happen: paying more than is carried")
	var before := seller.inventory.money
	var refused := not Inventory.trade(seller.inventory, buyer.inventory, [], 9999)
	print("    a trade for 9999 coins was %s, and the purse is still %d" % [
		"refused" if refused else "allowed", before,
	])
	print("")


# --- 6. Order --------------------------------------------------------------


func _order_is_not_part_of_what_you_own() -> void:
	print("two characters with the same things in different orders are the same")
	var forwards := _bare("Wren")
	var backwards := _bare("Bramble")
	var slots := Armour.SLOTS.duplicate()
	for slot in slots:
		forwards.inventory.take_up(Armour.worn(slot, LEVEL))
	forwards.inventory.take_up(Weapon.held(Weapon.sword(), LEVEL))
	var reversed_slots := slots.duplicate()
	reversed_slots.reverse()
	backwards.inventory.take_up(Weapon.held(Weapon.sword(), LEVEL))
	for slot in reversed_slots:
		backwards.inventory.take_up(Armour.worn(slot, LEVEL))
	forwards.inventory.gain(70)
	backwards.inventory.gain(70)

	print("  acquired and worn forwards:  %s" % _slot_order(forwards))
	print("  acquired and worn backwards: %s" % _slot_order(backwards))
	print("  the two fingerprints agree: %s" % (
		"yes" if forwards.inventory.fingerprint() == backwards.inventory.fingerprint()
		else "no"))
	print("  %s" % forwards.inventory.fingerprint().substr(0, 74))
	var left := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	var right := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	left.adopt(forwards)
	right.adopt(backwards)
	print("  and on the board: def %d/%d, move-cells %d/%d, cut %d/%d" % [
		left.defence(), right.defence(),
		_move_cells(left), _move_cells(right),
		left.damage_of(0), right.damage_of(0),
	])
	print("")


# --- Helpers ---------------------------------------------------------------


## A character carrying and wearing a whole level-8 loadout.
func _outfitted(called: String) -> Character:
	var sheet := _bare(called)
	for slot in Armour.SLOTS:
		sheet.inventory.take_up(Armour.worn(slot, LEVEL))
	sheet.inventory.take_up(Weapon.held(Weapon.sword(), LEVEL))
	sheet.inventory.gain(50)
	return sheet


## A character with nothing.
func _bare(called: String) -> Character:
	return Character.make(called, LEVEL)


func _every_equipped_is_carried(sheet: Character) -> String:
	for slot in sheet.equipment:
		if not sheet.inventory.has(sheet.equipment[slot]):
			return "no -- %s is worn and not carried" % slot
	return "yes, all %d of them" % sheet.equipment.size()


## One row of the loadout table: what a commander's gear is worth on a board.
func _loadout_row(commander: Commander, worn: String) -> void:
	print("  %-22s %5d %7d %11d %8d %4d %7d" % [
		worn, commander.defence(), commander.move_grants().size(),
		_move_cells(commander), commander.attack_count(),
		commander.damage_of(0), commander.damage_of(1),
	])


## How many cells the commander's grants reach in the open, ignoring any board:
## the union of every offset every grant carries, ridden as far as it may go.
func _move_cells(commander: Commander) -> int:
	var reached := {}
	for grant in commander.move_grants():
		var reach := 1
		if grant.mode == MoveGrant.SLIDE and grant.reach != MoveGrant.UNBOUNDED:
			reach = grant.reach
		for offset in grant.offsets:
			for step in range(1, reach + 1):
				reached[offset * step] = true
	return reached.size()


func _moved(happened: bool, pile: Inventory, sheet: Character) -> String:
	return "%s -- ground %s, %s %s" % [
		"moved" if happened else "refused", pile.line(),
		sheet.character_name, sheet.inventory.line(),
	]


func _purses(when: String, seller: Character, buyer: Character) -> void:
	print("    %-18s %s %d coins %d items | %s %d coins %d items" % [
		when, seller.character_name, seller.inventory.money, seller.inventory.size(),
		buyer.character_name, buyer.inventory.money, buyer.inventory.size(),
	])


func _slot_order(sheet: Character) -> String:
	var slots := PackedStringArray()
	for slot in sheet.equipment:
		slots.append(slot)
	return " ".join(slots)


