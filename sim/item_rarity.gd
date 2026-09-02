extends RefCounted
## The six rarity tiers and what each is worth.
##
## Section 4 names them: common, uncommon, rare, legendary, mythic, eternal. A
## tier is not a bonus and not a label -- it is one multiplier, and the only
## thing it multiplies is the level of the creature that dropped the item. That
## single number is the whole of what rarity does to an item's power, which is
## why it lives in a table of six integers rather than in a rule anywhere.
##
## ## The multipliers, and the one thing they are chosen to say
##
## | tier | $r$ | against common |
## |---|---|---|
## | common | 4 | 1.00x |
## | uncommon | 6 | 1.50x |
## | rare | 9 | 2.25x |
## | legendary | 14 | 3.50x |
## | mythic | 21 | 5.25x |
## | eternal | 32 | 8.00x |
##
## Each tier is about half again the one below it, so eternal is eight times
## common. Eight, and not eighty, on purpose: it means a common item dropped by
## a level-16 creature and an eternal dropped by a level-2 one carry exactly the
## same power. Rarity is therefore a shortcut through the level gradient and
## never a replacement for it -- section 5's "your gear budget is capped by what
## you have killed" survives a lucky drop, because a lucky drop at your own tier
## is worth three rings of ordinary progress and not thirty.
##
## ## More effects at higher rarity
##
## Section 4 also says a higher tier gives a higher chance of *more effects*.
## That is `EFFECT_SLOTS`: the largest number of separate effects an item of the
## tier may divide its effects budget into. A generator draws somewhere between
## one and that, so the tier raises the chance rather than fixing the count --
## an eternal item may still come out with a single effect, and a common one
## never comes out with four.
class_name ItemRarity

const COMMON := "common"
const UNCOMMON := "uncommon"
const RARE := "rare"
const LEGENDARY := "legendary"
const MYTHIC := "mythic"
const ETERNAL := "eternal"

## The six tiers, weakest first. Order is the meaning: `rank()` is a position in
## this list and the tables below are read by that position.
const TIERS := [COMMON, UNCOMMON, RARE, LEGENDARY, MYTHIC, ETERNAL]

## $r(\text{rarity})$: what one level of the creature that dropped the item is
## worth at each tier. See the table above for why the top is eight times the
## bottom rather than an order of magnitude.
const MULTIPLIERS := [4, 6, 9, 14, 21, 32]

## The most separate effects an item of each tier may carry.
const EFFECT_SLOTS := [1, 2, 2, 3, 3, 4]

## What is returned for a tier name that is not one of the six: nothing, so that
## a typo produces a worthless item rather than a quietly average one.
const UNKNOWN_MULTIPLIER := 0


## Whether a name is one of the six tiers.
static func is_rarity(tier: String) -> bool:
	return TIERS.has(tier)


## The position of a tier, weakest 0, or -1 for a name that is not a tier.
static func rank(tier: String) -> int:
	return TIERS.find(tier)


## $r(\text{rarity})$ -- the multiplier the power budget is built from.
static func multiplier(tier: String) -> int:
	var at := rank(tier)
	return UNKNOWN_MULTIPLIER if at < 0 else MULTIPLIERS[at]


## The most separate effects a tier may divide its effects budget into.
static func effect_slots(tier: String) -> int:
	var at := rank(tier)
	return 0 if at < 0 else EFFECT_SLOTS[at]
