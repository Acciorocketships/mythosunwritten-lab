extends RefCounted
## Turns a seed and a source into an item, deterministically.
##
## The forge is the only file of the item layer that draws a random number, and
## it draws them from the project's own `SimRng` rather than the engine's, so the
## same seed and the same source produce the same item in any process on any
## host. Everything else about an item -- what its budget is, how it is spent,
## what a user reads off it -- is arithmetic with no seed anywhere near it.
##
## ## What it is not
##
## It is not a drop, a loot table or a difficulty gradient. It is not asked
## *whether* an item appears, *which* creature was carrying it, or *how far from
## spawn* that creature stood. Those three questions are the next step's, and
## the forge is deliberately unable to answer any of them: it is handed a level
## and a kind and returns one item.
##
## ## The address, and why it is a label rather than a counter
##
## An item is addressed by `(seed, source)` -- the world's seed and a text label
## for whatever it came off. The label is folded into an independent stream by
## `SimRng.fork`, so two items are unrelated draws even when they are forged one
## after another, and forging an item somewhere else in the world cannot shift
## the numbers this one sees. A stream position would have made an item depend on
## how many items had been forged before it, which is exactly the property a
## world streamed in chunks cannot have.
##
## ## The draw order
##
## Fixed, and listed here because it is the whole of what makes two runs agree:
##
##   1. rarity, from `RARITY_WEIGHTS`;
##   2. the shape of the gear -- which slot, or which sort of held thing;
##   3. the effects share, from the band its kind allows;
##   4. how much of what is left goes to movement, in hundredths;
##   5. which ability score it is read against;
##   6. how many separate effects it divides its effects share into;
##   7. which effects those are, and their relative weights.
##
## Adding an eighth draw at the end leaves every existing item unchanged;
## inserting one in the middle does not. That is a real constraint on later work
## and it is why the list is written down rather than left to be read off the
## code.
class_name ItemForge

## How likely each tier is, weakest first, out of a hundred. Declining hard:
## half of everything forged is common and one item in a hundred is eternal.
##
## This is the forge's own distribution and not a loot table -- it says nothing
## about which creature carries what or whether it falls when the creature dies.
const RARITY_WEIGHTS := [50, 25, 13, 7, 4, 1]

## How much of a held item goes to effects, at least and at most, in hundredths.
## A held thing is mostly what it does: its attacks, its reach, its cooldowns.
const HAND_EFFECTS_BAND := Vector2i(55, 90)

## The same for a worn item. A worn thing is mostly how it moves and how much it
## takes off a blow, and its effects are the narrow remainder.
const WORN_EFFECTS_BAND := Vector2i(0, 30)

## The sorts of held things. Names of shapes, never of models: which figure a
## "blade" is drawn as is a table in another layer.
const HAND_SHAPES := ["blade", "spear", "bow", "staff", "flail", "buckler"]

## What an effect can be. Mechanics, in one word each.
const EFFECT_NAMES := [
	"flame", "frost", "shock", "keen", "warding",
	"leap", "blink", "homing", "splitting", "siphon",
]


## One item, from a seed and a source label.
static func forge(
	world_seed: int, source: String, source_level: int, of_kind: String
) -> Item:
	var draw := SimRng.new(world_seed).fork("item:%s" % source)

	var rarity: String = ItemRarity.TIERS[_weighted(draw, RARITY_WEIGHTS)]
	var worn := of_kind == Item.KIND_ARMOUR
	var shape: String = (
		Item.ARMOUR_SLOTS[draw.next_int(0, Item.ARMOUR_SLOTS.size() - 1)] if worn
		else HAND_SHAPES[draw.next_int(0, HAND_SHAPES.size() - 1)]
	)
	var band := WORN_EFFECTS_BAND if worn else HAND_EFFECTS_BAND
	var effects_share := draw.next_int(band.x, band.y)
	var movement_of_rest := draw.next_int(0, ItemBudget.WEIGHT_TOTAL)
	var governing: String = Ability.ALL[draw.next_int(0, Ability.ALL.size() - 1)]

	var slots := draw.next_int(1, maxi(1, ItemRarity.effect_slots(rarity)))
	var names: Array[String] = []
	var weights: Array[int] = []
	for _slot in slots:
		names.append(_unused_effect(draw, names))
		weights.append(draw.next_int(1, ItemBudget.WEIGHT_TOTAL))

	var called := "%s %s" % [rarity, shape]
	if worn:
		return Item.armour(
			called, shape, source_level, rarity, governing,
			ItemBudget.shape(effects_share, movement_of_rest), names, weights
		)
	return Item.weapon(
		called, source_level, rarity, governing,
		ItemBudget.shape(effects_share, movement_of_rest), names, weights
	)


## A run of items from one source, addressed `source#0`, `source#1`, and so on.
## Each is an independent forge call, so any one of them can be reproduced on its
## own without generating the ones before it.
static func batch(
	world_seed: int, source: String, source_level: int, of_kind: String, count: int
) -> Array[Item]:
	var forged: Array[Item] = []
	for index in maxi(0, count):
		forged.append(forge(world_seed, "%s#%d" % [source, index], source_level, of_kind))
	return forged


## Pick an index from a weight table. Walks the table in its fixed order and
## takes the first entry the draw lands inside, so the mapping from a drawn
## number to a tier is the same everywhere the table is.
static func _weighted(draw: SimRng, weights: Array) -> int:
	var total := 0
	for weight in weights:
		total += maxi(0, int(weight))
	if total <= 0:
		return 0
	var landed := draw.next_int(0, total - 1)
	var walked := 0
	for index in weights.size():
		walked += maxi(0, int(weights[index]))
		if landed < walked:
			return index
	return weights.size() - 1


## An effect the item does not already carry. Advances through the fixed list
## from wherever the draw landed, so a repeat costs one step rather than a
## re-draw -- which keeps the number of draws per item fixed and therefore keeps
## the draw order above true.
static func _unused_effect(draw: SimRng, taken: Array[String]) -> String:
	var at := draw.next_int(0, EFFECT_NAMES.size() - 1)
	for step in EFFECT_NAMES.size():
		var candidate: String = EFFECT_NAMES[(at + step) % EFFECT_NAMES.size()]
		if not taken.has(candidate):
			return candidate
	return EFFECT_NAMES[at]
