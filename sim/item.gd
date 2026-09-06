extends RefCounted
## The one thing an item is: a level, a rarity, and one power budget spent
## across movement, defence and effects.
##
## A sword and a pair of boots are the same class here, differing only in the
## `kind` field and in how their budget was divided. That is not tidiness for its
## own sake -- section 4 gives one budget formula for every item in the game, and
## two classes would mean two places for it to drift. It is also the reason a
## helmet can carry a fireball and a staff can carry a way of moving: nothing in
## the representation says which axis belongs to which sort of gear.
##
## ## The budget
##
##     P = r(rarity) * L_source = movement + defence + effects
##
## The item's `level` *is* $L_{\text{source}}$, the level of the creature that
## dropped it. There is no second number and no derived one: an item is worth the
## creature it came off, times what its tier multiplies that by. The arithmetic
## of dividing $P$ -- and the rule for where a rounding remainder goes -- is
## `ItemBudget`, so that the split is one implementation used twice rather than a
## convention repeated.
##
## Movement and defence therefore genuinely compete. Effects take a share off
## the top and what is left is a single number cut in two: a point of movement is
## a point of defence not taken, which is the whole of "a godlike-mobility
## chestplate has weak defence" and it is arithmetic rather than a guideline.
##
## ## The ability-score gate
##
## Section 4: a high-level item under-performs for a user whose relevant ability
## score is too low. The rule, applied wherever a value is read off the item:
##
##     v_effective = floor(v * min(A, L) / L)
##
## where `A` is the user's score in the ability the item names and `L` is the
## item's level. A user at or above the item's level reads every value in full;
## a user below it reads that fraction of every value, movement and defence and
## effects alike. One integer division, not two, so there is no double rounding
## to argue about: a level-8 item read by a score of 6 is worth exactly
## three-quarters of itself, floored once per axis.
##
## The gate is on the *reading*, never on the item. Two characters holding the
## same object read different numbers off it, and the object itself is unchanged
## -- which is what lets it be traded, dropped, and picked up by someone it suits
## better without anything being recomputed.
##
## ## What the constructors guarantee, and what a later writer owns
##
## `spends_budget()` is true of every item `from_shape` builds -- including one
## given an effects share and no effect names, which carries that share as a
## single effect named after the item rather than losing it. That is a guarantee
## of the *constructors*, not of the class: `movement`, `defence` and `effects`
## are plain public fields, so anything that writes one after construction owns
## keeping the sum, and until it does `spends_budget()` reports false while
## `budget()` stays where it was. Nothing in the project writes an axis except
## two checks that do it deliberately to show the report is live
## (`tests/test_items.gd` and `tools/critic_items_probe.gd`). They are left able
## to, because a check that cannot break its premise proves nothing; the fields
## are the version that survives until items are traded or enchanted, at which
## point whatever does the enchanting is the thing that has to re-spend the
## budget rather than edit one axis of it.
##
## ## What this layer does not know
##
## It does not know how items are dropped, what a creature carries, or how
## difficulty rises with distance -- none of that is here and none of it is
## referenced. It also names no class of the combat layer at all: not the pieces,
## not the board, not the resolution seam. The item layer and the fight meet in
## exactly one later step, and until then each can be read on its own.
class_name Item

## The three kinds the design names. Section 2 gives a character "inventory
## (weapons, armor, consumables, money -- tradeable/usable)", so a consumable is
## an item like the other two and not a fourth representation. Lower case
## throughout: these are field values, not class names.
##
## Only one rule anywhere reads `kind`, and it is not in this file: `ActionEngine`
## refuses to use up anything that is not `KIND_CONSUMABLE`, because using a
## thing up is the one operation whose whole point is that the item does not come
## back. Everything else -- the budget, the gate, the slot -- is the same
## arithmetic for all three.
const KIND_WEAPON := "weapon"
const KIND_ARMOUR := "armour"
const KIND_CONSUMABLE := "consumable"

## Where a piece of gear is worn or held. The four body slots section 3.4 names,
## plus the hand, so that a whole loadout can be described without a second
## vocabulary living somewhere else.
const SLOT_BOOTS := "boots"
const SLOT_LEGGINGS := "leggings"
const SLOT_CHESTPLATE := "chestplate"
const SLOT_HELMET := "helmet"
const SLOT_HAND := "hand"

## The slots in a fixed order, worn ones first. A draw that needs a repeatable
## order reads this.
const ARMOUR_SLOTS := [SLOT_BOOTS, SLOT_LEGGINGS, SLOT_CHESTPLATE, SLOT_HELMET]

## Where a thing that is neither worn nor held goes: nowhere. A draught is
## carried and traded like anything else and cannot be put on, which
## `Inventory.is_wearable` already reads off an empty slot -- so this is the name
## of a value the inventory has always understood rather than a new rule.
const SLOT_NONE := ""

## What it is called.
var item_name: String = ""

## `KIND_WEAPON`, `KIND_ARMOUR` or `KIND_CONSUMABLE`. The one field that says
## which sort of thing this is, and no rule in this file reads it.
var kind: String = KIND_WEAPON

## Where it is worn or held.
var slot: String = SLOT_HAND

## The item's level, which is the level of the creature that dropped it. Both
## halves of the design read this one number: the budget multiplies it, and the
## ability gate divides by it.
var level: int = 0

## One of `ItemRarity`'s six tiers.
var rarity: String = ItemRarity.COMMON

## Which of the six ability scores the item is read against.
var governing: String = Ability.STR

## Points of the budget spent on ways of moving.
var movement: int = 0

## Points of the budget spent on taking blows.
var defence: int = 0

## What the effects share bought, each carrying the points it cost.
var effects: Array[ItemEffect] = []


## Build an item by spending its budget through `ItemBudget`.
##
## The caller gives a *shape* -- three weights -- and never three amounts, so
## there is no way to hand an item more power than its rarity and level entitle
## it to. That is the point of the constructor being the only door in.
static func from_shape(
	of_kind: String,
	called: String,
	worn_in: String,
	at_level: int,
	of_rarity: String,
	read_against: String,
	weights: Array[int],
	effect_names: Array[String] = [],
	effect_weights: Array[int] = [],
) -> Item:
	var item := Item.new()
	item.item_name = called
	item.kind = of_kind
	item.slot = worn_in
	item.level = maxi(0, at_level)
	item.rarity = of_rarity
	item.governing = read_against

	var parts := ItemBudget.split(
		ItemBudget.total(of_rarity, item.level), weights
	)
	item.movement = parts[ItemBudget.MOVEMENT]
	item.defence = parts[ItemBudget.DEFENCE]
	item.effects = _spend_on_effects(
		parts[ItemBudget.EFFECTS], effect_names, effect_weights, called
	)
	return item


## A held item. Nothing about the class makes this different from the next
## function; the pair exists so a caller reads as what it is building.
static func weapon(
	called: String,
	at_level: int,
	of_rarity: String,
	read_against: String,
	weights: Array[int],
	effect_names: Array[String] = [],
	effect_weights: Array[int] = [],
) -> Item:
	return from_shape(
		KIND_WEAPON, called, SLOT_HAND, at_level, of_rarity, read_against,
		weights, effect_names, effect_weights
	)


## A worn item.
static func armour(
	called: String,
	worn_in: String,
	at_level: int,
	of_rarity: String,
	read_against: String,
	weights: Array[int],
	effect_names: Array[String] = [],
	effect_weights: Array[int] = [],
) -> Item:
	return from_shape(
		KIND_ARMOUR, called, worn_in, at_level, of_rarity, read_against,
		weights, effect_names, effect_weights
	)


## Something used up. It goes in no slot, so it cannot be worn or held, and its
## whole budget is on the effects axis: a draught is what its effect is worth and
## nothing else. Section 4 puts every ability on an item, and a consumable is the
## one that spends itself when the ability is used.
##
## The shape is fixed here rather than asked of the caller for that reason: a
## consumable with points on movement or defence would be points nobody can ever
## read, because nothing wears it.
static func consumable(
	called: String,
	at_level: int,
	of_rarity: String,
	read_against: String,
	effect_names: Array[String] = [],
	effect_weights: Array[int] = [],
) -> Item:
	return from_shape(
		KIND_CONSUMABLE, called, SLOT_NONE, at_level, of_rarity, read_against,
		[0, 0, 1] as Array[int], effect_names, effect_weights
	)


## Divide the effects share among named effects, exactly, by the same rule that
## divided the axes. An effect that came out worth nothing is not carried: an
## item does not list what it spent nothing on.
##
## A caller that asks for an effects share but names no effect gets one effect
## worth the whole share, labelled with the item's own name. That branch is the
## only reason this function takes the item's name at all, and it is what keeps
## the budget exact for a caller the project does not have yet: the share has
## already been assigned to the effects axis by the time this is called, so
## returning nothing would spend it nowhere. The alternative -- folding the share
## into defence before the split -- was not taken, because the weights are a
## statement about *how the item is divided* and folding would answer a different
## question than the one asked: a shape of [0, 0, 100] would come back a pure
## defence item, and the movement-against-defence trade measured at equal budget
## would be reading shapes nobody asked for. Naming the effect after the item is
## also what the layer above already does when it forges a held item from a
## catalogue shape -- its one effect is named after the shape -- so this is the
## existing convention reaching one case further rather than a second one.
static func _spend_on_effects(
	amount: int,
	names: Array[String],
	weights: Array[int],
	unnamed_as: String = "",
) -> Array[ItemEffect]:
	var carried: Array[ItemEffect] = []
	if names.is_empty():
		if amount > 0:
			carried.append(ItemEffect.make(unnamed_as, amount))
		return carried
	var shares: Array[int] = weights.duplicate()
	while shares.size() < names.size():
		shares.append(1)
	shares.resize(names.size())
	var parts := ItemBudget.split(amount, shares)
	for index in names.size():
		if parts[index] > 0:
			carried.append(ItemEffect.make(names[index], parts[index]))
	return carried


# --- The budget -----------------------------------------------------------


## $P = r(\text{rarity}) \times L_{\text{source}}$, recomputed from the item's own
## two fields rather than stored, so an item cannot disagree with its budget.
func budget() -> int:
	return ItemBudget.total(rarity, level)


## What the effects axis is worth: the sum of what the effects cost.
func effects_power() -> int:
	var total := 0
	for effect in effects:
		total += effect.magnitude
	return total


## What the item actually carries across all three axes.
func power() -> int:
	return movement + defence + effects_power()


## Whether the item spends its budget exactly. True of every item this class can
## build; a caller can ask, and a report tabulates the answer rather than
## asserting it in prose. It reports rather than guarantees: see the class
## docstring on who owns the sum after an axis is written.
func spends_budget() -> bool:
	return power() == budget()


## The three axes as an array in `ItemBudget`'s fixed order.
func axes() -> Array[int]:
	var values: Array[int] = [movement, defence, effects_power()]
	return values


# --- The ability-score gate -----------------------------------------------


## $\lfloor v \cdot \min(A, L) / L \rfloor$ -- one value as a user with score `A`
## reads it off an item of level `L`.
##
## A score at or above the item's level reads the value in full. Below it, the
## value is scaled by the shortfall. An item of level zero has nothing to fall
## short of, so it is read in full by anyone.
@warning_ignore("integer_division")
static func realise(value: int, score: int, item_level: int) -> int:
	if item_level <= 0:
		return maxi(0, value)
	return maxi(0, value) * clampi(score, 0, item_level) / item_level


## The fraction of the item a score reaches, in hundredths. For reports and
## failure messages only -- no value is computed through this, because gating a
## value in two steps would round twice.
@warning_ignore("integer_division")
func qualification(score: int) -> int:
	if level <= 0:
		return 100
	return 100 * clampi(score, 0, level) / level


## The movement this item grants a user with the given score in its ability.
func movement_for(score: int) -> int:
	return realise(movement, score, level)


## The defence it gives that user.
func defence_for(score: int) -> int:
	return realise(defence, score, level)


## What its effects are worth to that user.
func effects_for(score: int) -> int:
	return realise(effects_power(), score, level)


## One named effect as that user reads it.
func effect_for(index: int, score: int) -> int:
	if index < 0 or index >= effects.size():
		return 0
	return realise(effects[index].magnitude, score, level)


## What the whole item is worth to that user: the sum of the three gated axes.
##
## This is the sum of three separately floored values, so it can sit up to two
## points below the gate applied to the whole budget at once. That is stated
## rather than smoothed away: the gate is applied where each value is read,
## because that is where it belongs, and reading three values costs three
## roundings. The gap is at most two points and never favours the reader.
func power_for(score: int) -> int:
	return movement_for(score) + defence_for(score) + effects_for(score)


## Whether a user's score reaches the whole item.
func is_qualified(score: int) -> bool:
	return level <= 0 or score >= level


# --- Description ----------------------------------------------------------


## The effects as one field, in the order they were bought.
func effects_line() -> String:
	var written := PackedStringArray()
	for effect in effects:
		written.append(effect.line())
	return "|".join(written)


## One line describing the item, in the form reports and tests compare. Every
## number that makes the item what it is appears here, so two items printing the
## same line are the same item.
func line() -> String:
	return "%s %s %s L%d P=%d mov=%d def=%d eff=%d %s [%s] %s" % [
		rarity, kind, slot, level, budget(), movement, defence, effects_power(),
		governing, effects_line(), item_name,
	]
