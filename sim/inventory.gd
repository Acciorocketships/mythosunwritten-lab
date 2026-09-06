extends RefCounted
## What a character carries, and -- as a view onto that and not as a second
## store -- what it has on.
##
## Section 2 gives a character "inventory (weapons, armor, consumables, money --
## tradeable/usable)" and "equipment (currently equipped)". Written as two
## collections those are two places for the same object to be, and the first bug
## is somebody wearing a breastplate they sold last week. So there is one
## collection here, `carried`, and being equipped is a *slot pointing at an entry
## of it*. Equipping something not carried is refused; dropping something worn
## takes it off on the way out. Nothing can be worn or held that the character
## does not have, and that is a property of the representation rather than a rule
## somebody remembered to check.
##
## ## What an entry is
##
## Anything with an `Item` behind it: an `Armour`, a `Weapon`, or a bare `Item`
## picked up off the ground before anybody decided what to do with it. All three
## answer `item_of()`, and the slot an entry occupies is its item's slot -- so
## there is one vocabulary of slots, the item layer's, and this file invents no
## second one. A `Weapon` carrying no item at all is the catalogue reading itself
## (see sim/weapon.gd); it is carried in the hand because that is where a weapon
## goes, and it is the one entry whose slot is not read off an item.
##
## ## No number of the fight is stored here
##
## An inventory holds objects and one integer of money. What a worn item stops,
## what it lets its wearer do, and what a held one deals are read off the item's
## power budget through the wearer's ability score, every time, by `Commander`.
## Moving gear into this file therefore moved no number: the board reads the same
## items through the same gate, and `Commander.armour` and `Commander.weapon` are
## now views onto `worn()` and `held()` rather than fields of their own.
##
## ## Ordering, and why two inventories can be compared
##
## `carried` keeps insertion order, because the drop roll addresses an item by
## its place in what was carried and a drop verdict has to be reproducible. What
## is *worn* is returned in slot order -- the order `Commander` has always sorted
## its armour into -- so two characters that equipped the same four pieces in
## different orders wear them in the same order. `fingerprint()` completes the
## picture by sorting what is carried too, so "the same items and the same money,
## acquired in any order" is one string that can be compared.
##
## ## The ground is an inventory
##
## A pile of loot on the ground is one of these with nobody attached: it holds
## entries and it may hold money. Picking something up and dropping it are then
## the same operation as giving it to somebody -- `transfer()` -- and defeat's
## loot drop is `spill_into()`, which rolls the verdicts `ItemDrop` already rolls
## and moves what fell. There is one path by which an object changes hands and
## every one of those four things is it.
class_name Inventory

## The hand, and the four worn slots, in the order equipment is reported in. The
## item layer's own names and the item layer's own order: worn first, then what
## is held, so a report reads from the feet up and ends at the hands.
const SLOT_ORDER: Array = [
	Item.SLOT_BOOTS, Item.SLOT_LEGGINGS, Item.SLOT_CHESTPLATE,
	Item.SLOT_HELMET, Item.SLOT_HAND,
]

## Everything the character has, in the order it came by it. Worn things are in
## here too -- that is the whole point -- so this is never a partial list.
var carried: Array = []

## Coins. Section 2 lists money among what an inventory holds, so it is held
## here, as one quantity, and no character sheet carries a second copy of it.
var money: int = 0

# Which entry of `carried` occupies which slot. The values are entries of
# `carried` and never anything else: `equip()` refuses what is not carried and
# `release()` clears the slot before it removes anything, so this dictionary
# cannot come to name something the character does not have.
var _equipped: Dictionary = {}


## An inventory holding some entries and some money. Nothing is equipped: what
## somebody has and what they have on are different questions, and this answers
## the first one.
static func of(entries: Array = [], with_money: int = 0) -> Inventory:
	var inventory := Inventory.new()
	inventory.money = maxi(0, with_money)
	inventory.carry_all(entries)
	return inventory


## A pile on the ground. The same class: a place items lie is a place items are,
## and the only difference between a pile and a pack is whether anybody is
## standing in it. Named so that a caller reads as what it is building.
static func ground(entries: Array = [], with_money: int = 0) -> Inventory:
	return of(entries, with_money)


# --- What an entry is -----------------------------------------------------


## The `Item` behind an entry: the item itself, or the item its wrapper carries.
## Null for an entry with no item, which is a catalogue weapon reading itself.
static func item_of(entry: Variant) -> Item:
	if entry is Item:
		return entry
	if entry is Armour or entry is Weapon:
		return entry.item
	return null


## Where an entry is worn or held. The item's own slot, so the vocabulary is the
## item layer's; a weapon with no item behind it is held, because that is what a
## weapon is, and everything else with no item goes nowhere.
static func slot_of(entry: Variant) -> String:
	var item := item_of(entry)
	if item != null:
		return item.slot
	return Item.SLOT_HAND if entry is Weapon else ""


## Whether an entry can be worn or held at all. Something with no slot is
## carried and traded like anything else and simply cannot be put on.
static func is_wearable(entry: Variant) -> bool:
	return slot_of(entry) != ""


# --- What is carried ------------------------------------------------------


## How many things are carried.
func size() -> int:
	return carried.size()


## Whether this exact object is carried. Identity, not equality: two commons off
## the same creature are two objects and losing one must not lose the other.
func has(entry: Variant) -> bool:
	for held_entry in carried:
		if held_entry == entry:
			return true
	return false


## Take something into the inventory. Refuses nothing but a null and a thing
## already carried, so taking twice cannot leave two of one object.
func carry(entry: Variant) -> bool:
	if entry == null or has(entry):
		return false
	carried.append(entry)
	return true


## Take several things, and say how many were taken.
func carry_all(entries: Array) -> int:
	var taken := 0
	for entry in entries:
		if carry(entry):
			taken += 1
	return taken


## Let something go. It comes off first if it was worn, so nothing stays equipped
## once it has left -- which is the invariant this whole file exists for.
func release(entry: Variant) -> bool:
	var index := carried.find(entry)
	if index < 0:
		return false
	for slot in _equipped.keys():
		if _equipped[slot] == entry:
			_equipped.erase(slot)
	carried.remove_at(index)
	return true


## The items behind everything carried, in the order carried. This is what the
## drop roll is addressed against, so its order is the order of `carried` and
## nothing sorts it.
func items() -> Array[Item]:
	var behind: Array[Item] = []
	for entry in carried:
		behind.append(item_of(entry))
	return behind


# --- What is equipped, which is a view onto what is carried ---------------


## Put something on. Refused unless it is already carried and has a slot to go
## in; whatever was in that slot comes off and stays carried.
func equip(entry: Variant) -> bool:
	if not has(entry) or not is_wearable(entry):
		return false
	_equipped[slot_of(entry)] = entry
	return true


## Take something into the inventory and put it on in one move, for a caller
## that has just been handed a thing and means to use it.
func take_up(entry: Variant) -> bool:
	carry(entry)
	return equip(entry)


## Put on what is carried: the first thing carried for each empty slot, and
## nothing already occupied.
##
## What a character is *wearing* is not part of what it was rolled with --
## `SpawnRoll` fills an inventory and stops, because dressing is not rolling --
## so somebody stood up out of a roll would otherwise walk about carrying its
## armour in a sack, with no defence and no attack. This is the one call that
## dresses them, and everybody who is stood up from a roll makes it.
##
## A held item is taken up as the shape the forge drew it as (`Weapon.for_item`),
## so what it swings is the pattern that shape has and the numbers are the ones
## its own budget bought. Taken up bare it would be `Weapon.around` -- a budget
## with nothing to spend it swinging.
##
## First into a slot keeps it: which of two forged breastplates is worn is not
## something this call has an opinion about, and the order things are carried in
## is one every process reads the same way. Returns how many things went on.
func dress() -> int:
	var worn_now := 0
	for entry in carried.duplicate():
		if not is_wearable(entry):
			continue
		var slot := slot_of(entry)
		if equipped_in(slot) != null:
			continue
		if slot != Item.SLOT_HAND or entry is Weapon:
			if take_up(entry):
				worn_now += 1
			continue
		var shaped := Weapon.for_item(item_of(entry))
		if shaped == null:
			continue
		release(entry)
		if take_up(shaped):
			worn_now += 1
	return worn_now


## Take off whatever is in a slot and return it. It stays carried: taking your
## boots off is not the same as leaving them behind.
func unequip(slot: String) -> Variant:
	if not _equipped.has(slot):
		return null
	var removed: Variant = _equipped[slot]
	_equipped.erase(slot)
	return removed


## What is in a slot, or null.
func equipped_in(slot: String) -> Variant:
	return _equipped.get(slot, null)


## Whether this exact object is being worn or held.
func is_equipped(entry: Variant) -> bool:
	for slot in _equipped.keys():
		if _equipped[slot] == entry:
			return true
	return false


## Everything equipped, by slot, in `SLOT_ORDER`. The view section 2 calls
## "equipment": built fresh from what is carried on every call, so there is
## nothing here that can fall out of step with the inventory.
func equipment() -> Dictionary:
	var view := {}
	for slot in SLOT_ORDER:
		if _equipped.has(slot):
			view[slot] = _equipped[slot]
	return view


## What is worn, as armour, in slot order -- the four body slots and not the
## hand. A bare item that was put on is wrapped on the way out, because `Armour`
## stores nothing of its own: it is a way of reading an item, so wrapping one is
## free and cannot introduce a second copy of anything.
func worn() -> Array[Armour]:
	var pieces: Array[Armour] = []
	for slot in Item.ARMOUR_SLOTS:
		var entry: Variant = _equipped.get(slot, null)
		if entry == null:
			continue
		pieces.append(entry if entry is Armour else Armour.of_item(item_of(entry)))
	pieces.sort_custom(func(left: Armour, right: Armour) -> bool:
		return left.slot < right.slot)
	return pieces


## What is worn in one slot, as armour, or null.
func armour_in(slot: String) -> Armour:
	for piece in worn():
		if piece.slot == slot:
			return piece
	return null


## What is in the hands, as a weapon, or null for empty hands.
##
## An item taken up without a catalogue shape behind it is a weapon with no
## attack: it still defends its holder out of its own defence axis, and it swings
## at nothing, because an attack pattern comes off the catalogue and picking an
## object up does not invent one.
func held() -> Weapon:
	var entry: Variant = _equipped.get(Item.SLOT_HAND, null)
	if entry == null:
		return null
	if entry is Weapon:
		return entry
	return Weapon.around(item_of(entry))


## The name of the weapon this holds, or of the first weapon carried, or "" for
## somebody carrying none.
##
## A *name*, because `Action.attack` names an item and `ActionEngine` derives
## which of that item's attacks reaches -- section 10 spells the call
## `Attack(target, weapon/attack-mode derived from item)`, so choosing the mode
## anywhere but the engine would be half a resolution in the wrong place. Every
## mind that swings asks this, for the reason they all ask one scene the same
## question about who is nearby.
func weapon_name() -> String:
	var first := ""
	for entry in carried:
		var item := item_of(entry)
		if item == null or item.kind != Item.KIND_WEAPON:
			continue
		if is_equipped(entry):
			return item.item_name
		if first == "":
			first = item.item_name
	return first


# --- Money ----------------------------------------------------------------


## Take coins in. Negative amounts are ignored rather than reversed: money leaves
## by `pay()`, so there is one direction per function and no sign to get wrong.
func gain(amount: int) -> void:
	money += maxi(0, amount)


## Pay coins out, if there are that many. Nothing moves when there are not.
func pay(amount: int) -> bool:
	var wanted := maxi(0, amount)
	if wanted > money:
		return false
	money -= wanted
	return true


# --- Changing hands -------------------------------------------------------


## Move entries and money from one inventory to another, all or nothing.
##
## This is picking something up, dropping it, handing it over and paying for it,
## and it is one function because they are one operation seen from four places.
## Nothing moves unless everything can: an inventory that cannot pay keeps its
## items, and a list naming something the giver does not have moves no coins.
static func transfer(
	from: Inventory, to: Inventory, entries: Array = [], coins: int = 0
) -> bool:
	if from == null or to == null or from == to:
		return false
	var wanted := maxi(0, coins)
	if wanted > from.money:
		return false
	for entry in entries:
		if not from.has(entry):
			return false
	for entry in entries:
		from.release(entry)
		to.carry(entry)
	from.pay(wanted)
	to.gain(wanted)
	return true


## A trade: items and money out, items and money in, both ways at once.
##
## Section 2.1 defines giving as "a trade with nothing in return", and that is
## not a second function here -- it is this one with `back` and `back_coins`
## empty. Either side may be empty; both being empty is a trade that does
## nothing and reports true. All or nothing, in the same sense as above: the
## whole exchange is checked before any of it happens, so nobody is left having
## paid for something that did not arrive.
static func trade(
	left: Inventory,
	right: Inventory,
	given: Array = [],
	given_coins: int = 0,
	back: Array = [],
	back_coins: int = 0,
) -> bool:
	if left == null or right == null or left == right:
		return false
	if maxi(0, given_coins) > left.money or maxi(0, back_coins) > right.money:
		return false
	for entry in given:
		if not left.has(entry):
			return false
	for entry in back:
		if not right.has(entry):
			return false
	transfer(left, right, given, given_coins)
	transfer(right, left, back, back_coins)
	return true


# --- Defeat ---------------------------------------------------------------


## What this inventory's owner leaves behind when it is defeated: the entries
## whose items fell, by the roll `ItemDrop` already makes.
##
## The verdicts come from `ItemDrop.verdicts` over `items()`, in the order
## carried, so this is the same one-in-five roll on the same addressed streams
## that the drop layer has always made -- nothing here rolls anything. What it
## adds is the other half of the sentence: the verdict comes back as the *entry*,
## the wrapper and all, so what fell can be picked up and worn rather than being
## a bare number on the ground.
func fallen(world_seed: int, kill: String) -> Array:
	var verdicts := ItemDrop.verdicts(world_seed, kill, items())
	var dropped := []
	for index in verdicts.size():
		if verdicts[index]:
			dropped.append(carried[index])
	return dropped


## Roll the drop and move what fell onto a pile, returning what moved.
##
## The loser stops carrying it and the ground starts carrying it, through the
## same `transfer()` that a gift and a purchase go through, so what defeat leaves
## behind is somewhere a character can walk up to and take.
func spill_into(pile: Inventory, world_seed: int, kill: String) -> Array:
	var dropped := fallen(world_seed, kill)
	transfer(self, pile, dropped, 0)
	return dropped


# --- Description ----------------------------------------------------------


## One entry named the way a report names it: what it is worth, and what it is.
static func entry_line(entry: Variant) -> String:
	if entry == null:
		return "nothing"
	var item := item_of(entry)
	if item != null:
		return item.line()
	if entry is Weapon:
		return "no item behind it: %s" % entry.weapon_name
	return "no item behind it"


## What is carried and what is worn, in one string, independent of the order any
## of it was acquired in.
##
## Two characters that bought the same four pieces in different weeks and put
## them on in different orders print the same line here. The carried entries are
## sorted, because acquisition order is not part of what somebody owns; the worn
## slots are already in slot order, which is the order `Commander` has sorted its
## armour into since the loadout landed.
func fingerprint() -> String:
	var lines := PackedStringArray()
	for entry in carried:
		lines.append(entry_line(entry))
	var sorted := Array(lines)
	sorted.sort()
	var slots := PackedStringArray()
	for slot in SLOT_ORDER:
		if _equipped.has(slot):
			slots.append("%s=%s" % [slot, entry_line(_equipped[slot])])
	return "money=%d carried=[%s] worn=[%s]" % [
		money, " | ".join(PackedStringArray(sorted)), " ".join(slots),
	]


## A short line for a report: how much is carried, how much is on, and the money.
func line() -> String:
	return "%d carried, %d equipped, %d money" % [
		carried.size(), _equipped.size(), money,
	]
