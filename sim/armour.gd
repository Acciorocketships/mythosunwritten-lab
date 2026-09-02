extends RefCounted
## A piece of gear worn in a slot: one `Item`, read as a way of moving and as
## something that takes the edge off a blow.
##
## Section 3.4: a commander's movement *is* their gear. The base is one cardinal
## step and each piece of armour adds a movement capability, so the loadout is
## the piece. Section 4 says where the capability is paid from: an item's power
## budget, split across movement, defence and effects, so that a point spent on
## moving is a point not spent on taking blows.
##
## This class is the meeting of those two sentences, and it holds no number of
## its own. It carries an `Item` and answers two questions about it -- what does
## it let its wearer do, and what does it stop -- both of them read through the
## item's ability-score gate, so the same object is worth different amounts to
## different wearers.
##
## ## One price, and it is the same price everywhere: a point buys a cell
##
## A movement grant costs one point of the item's movement axis per cell it
## reaches. A pattern of `n` offsets ridden `r` cells costs `n * r`:
##
## | slot | capability | cells | price |
## |---|---|---|---|
## | boots | the diagonal step, king-like with the base under it | 4 offsets x 1 | 4 |
## | leggings | the knight's hop, which carries over what is between | 8 offsets x 1 | 8 |
## | chestplate | the queen-like slide, one cell per eight points | 8 directions x r | 8r |
## | helmet | none at any price | -- | -- |
##
## The same sentence prices a held item too, where a point of movement buys a
## turn off a cooldown per cell the attack covers -- see `Weapon`. So "a point
## buys a cell" is the whole of what the movement axis does, worn or held, and
## there is no second rule to keep in step with this one.
##
## Two of the three placeholder constants this file used to carry are gone, and
## the third is not a placeholder. `DEFENCE_PER_TIER` and `HIGH_TIER` are the
## budget now: what a piece takes off a blow is its defence axis, and whether it
## grants anything is whether its movement axis can pay. The tier itself went
## with them -- an item's rarity and its level are the two numbers the one tier
## stood in for. `CHESTPLATE_REACH` stays, because section 3.4 says a chestplate
## is queen-like *up to two cells*: the cap is the design's own sentence and no
## budget lifts it.
class_name Armour

## The slots, which are the item layer's own names for them rather than a second
## copy: an armour piece is worn where its item says it is worn.
const BOOTS := Item.SLOT_BOOTS
const LEGGINGS := Item.SLOT_LEGGINGS
const CHESTPLATE := Item.SLOT_CHESTPLATE
const HELMET := Item.SLOT_HELMET

## The four of them, in the item layer's fixed order.
const SLOTS := Item.ARMOUR_SLOTS

## How far a chestplate's queen-like slide may reach however much is spent on
## it. Section 3.4's own words -- "queen-like, up to 2 cells" -- so this is a
## rule of the design and not a number waiting for a budget to replace it.
const CHESTPLATE_REACH := 2

## How many points of an item's defence axis one point of reduction costs.
##
## Sixteen, and it is $|\text{slots}|^2$ rather than a number chosen to taste.
## Four because a blow lands somewhere on a body rather than on the piece its
## owner would pick, so what stops it is the mean over the four worn slots; four
## again because a commander carries four worn items for the one in its hands,
## which is the exchange rate between a whole suit's budget and a weapon's. The
## consequence is checked rather than asserted: at equal level a front-on blow
## still gets through and position is still worth roughly an order of magnitude,
## which is the shape reports/combat.md publishes.
const POINTS_PER_DEFENCE := 16

## Which ability score each slot is read against, for the pieces this file
## builds. Boots and leggings are worn by moving in them, so they read against
## DEX; a chestplate and a helmet are worn by standing up in them, so CON.
const SLOT_ABILITY := {
	BOOTS: Ability.DEX,
	LEGGINGS: Ability.DEX,
	CHESTPLATE: Ability.CON,
	HELMET: Ability.CON,
}

## The item this is. Every number the piece has comes off it and none is stored
## here, so a piece cannot disagree with the budget it was made from.
var item: Item = null

## Where it is worn: the item's own slot, kept as one storage.
var slot: String:
	get:
		return "" if item == null else item.slot


## Wear an item as armour. The item decides the slot, so nothing can be worn in
## a place it was not made for.
static func of_item(worn: Item) -> Armour:
	var armour := Armour.new()
	armour.item = worn
	return armour


## Forge a piece for a slot at a level and a rarity, spending on movement
## exactly what the slot's capability costs and everything else on taking blows.
##
## `spent_on_moving` overrides that: it is how many points of the budget go to
## the movement axis, which is what builds the mobile-and-fragile and the
## slow-and-armoured ends of the same budget. The weights are handed over as
## amounts, which the largest-remainder split returns exactly because they sum to
## the budget.
static func worn(
	in_slot: String,
	at_level: int,
	of_rarity: String = ItemRarity.COMMON,
	spent_on_moving: int = -1,
) -> Armour:
	var total := ItemBudget.total(of_rarity, at_level)
	var moving := affordable(in_slot, total) if spent_on_moving < 0 else spent_on_moving
	moving = clampi(moving, 0, total)
	var weights: Array[int] = [moving, total - moving, 0]
	return of_item(Item.armour(
		"%s %s" % [of_rarity, in_slot], in_slot, at_level, of_rarity,
		str(SLOT_ABILITY.get(in_slot, Ability.CON)), weights
	))


## Boots add the diagonal step. With the base cardinal step under it, that is a
## king. The default level is the cheapest common item that can pay for the step
## out of half of itself.
static func boots(at_level: int = 2, of_rarity: String = ItemRarity.COMMON) -> Armour:
	return worn(BOOTS, at_level, of_rarity)


## Leggings add the knight's hop -- which, being a landing, carries over whatever
## is in between. Twice the cells of the diagonal, so twice the price, so twice
## the level at the same rarity.
static func leggings(at_level: int = 4, of_rarity: String = ItemRarity.COMMON) -> Armour:
	return worn(LEGGINGS, at_level, of_rarity)


## A chestplate adds a queen-like slide, one cell per eight points of movement
## and never more than two. Below eight it grants nothing and is armour, which is
## what a chestplate under the old `HIGH_TIER` was -- except that now the bar is
## a price rather than a tier, and what is not spent on clearing it is defence.
static func chestplate(at_level: int = 8, of_rarity: String = ItemRarity.COMMON) -> Armour:
	return worn(CHESTPLATE, at_level, of_rarity)


## A helmet grants no movement at any budget, so its whole budget is defence.
## Here so that "each armour piece adds a movement capability" is a claim about
## the pieces that do, rather than a rule every slot has to be bent to satisfy.
static func helmet(at_level: int = 2, of_rarity: String = ItemRarity.COMMON) -> Armour:
	return worn(HELMET, at_level, of_rarity)


# --- The price list -------------------------------------------------------


## What a grant costs: one point per cell it reaches, over `covers` offsets
## ridden `reach` cells.
static func price(covers: int, reach: int) -> int:
	return maxi(0, covers) * maxi(0, reach)


## The most a slot can usefully spend on moving, out of what there is.
##
## Nothing is spent on a capability the budget cannot buy outright: boots that
## cannot afford the whole diagonal keep their points and are armour. A
## chestplate rounds down to a whole cell, for the same reason -- half a cell of
## reach is not a thing a board can offer.
static func affordable(in_slot: String, budget: int) -> int:
	var spare := maxi(0, budget)
	match in_slot:
		BOOTS:
			var step := price(PieceGeometry.DIAGONALS.size(), 1)
			return step if spare >= step else 0
		LEGGINGS:
			var hop := price(PieceGeometry.KNIGHT_HOPS.size(), 1)
			return hop if spare >= hop else 0
		CHESTPLATE:
			var cell := price(PieceGeometry.ALL_DIRECTIONS.size(), 1)
			@warning_ignore("integer_division")
			var paid := spare / cell
			return mini(paid, CHESTPLATE_REACH) * cell
	return 0


## How many points of reduction a heap of defence points is worth.
@warning_ignore("integer_division")
static func reduction(points: int) -> int:
	return maxi(0, points) / POINTS_PER_DEFENCE


# --- What a wearer reads off it -------------------------------------------


## The points on the movement axis, as a wearer with this score reads them.
func movement_for(score: int) -> int:
	return 0 if item == null else item.movement_for(score)


## The points on the defence axis, as that wearer reads them. Points, not
## reduction: a body's whole heap is converted once, by `reduction()`, because
## converting piece by piece would round once per piece.
func defence_for(score: int) -> int:
	return 0 if item == null else item.defence_for(score)


## The movement this piece grants that wearer, or null for a piece that grants
## none -- because its slot never does, or because its movement axis cannot pay.
func grant_for(score: int) -> MoveGrant:
	var points := movement_for(score)
	match slot:
		BOOTS:
			if points >= price(PieceGeometry.DIAGONALS.size(), 1):
				return MoveGrant.land(PieceGeometry.DIAGONALS, BOOTS)
		LEGGINGS:
			if points >= price(PieceGeometry.KNIGHT_HOPS.size(), 1):
				return MoveGrant.land(PieceGeometry.KNIGHT_HOPS, LEGGINGS)
		CHESTPLATE:
			var reach := reach_for(score)
			if reach > 0:
				return MoveGrant.slide(PieceGeometry.ALL_DIRECTIONS, reach, CHESTPLATE)
	return null


## How far a chestplate's slide reaches for that wearer: one cell per eight
## points, never past section 3.4's two. Zero for every other slot.
@warning_ignore("integer_division")
func reach_for(score: int) -> int:
	if slot != CHESTPLATE:
		return 0
	var cells := movement_for(score) / price(PieceGeometry.ALL_DIRECTIONS.size(), 1)
	return mini(cells, CHESTPLATE_REACH)


## One line describing the piece as that wearer reads it, for a report line and a
## failure message.
func line_for(score: int) -> String:
	var granted := grant_for(score)
	return "%s %s L%d mov=%d def=%d %s" % [
		"-" if item == null else item.rarity, slot,
		0 if item == null else item.level,
		movement_for(score), defence_for(score),
		"-" if granted == null else granted.line(),
	]


## The piece as somebody who reaches all of it reads it.
func line() -> String:
	return line_for(0 if item == null else item.level)
