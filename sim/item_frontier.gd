extends RefCounted
## How far from spawn a creature stands, what level that makes it, and therefore
## what its gear can be worth.
##
## Section 5 states the gradient -- "enemy level (HP, defense, damage) rises with
## distance from the player's spawn" -- and the anti-invincibility property that
## follows from it: "your gear budget is capped by what you've killed, which is
## always behind the frontier ... grinding a safe zone can't break it: that zone
## drops only its own tier, below the next ring."
##
## This file is the first place in the project where distance becomes a level. It
## lives with the items because the property it exists to make measurable is a
## property of budgets, and because the budget is the only thing in the project
## that reads it so far. Nothing here knows what a fight is.
##
## ## The gradient
##
##     ring(d)  = floor(d / RING_SPAN)
##     L(d)     = SPAWN_LEVEL + LEVELS_PER_RING * ring(d)
##
## A step function, not a smooth one, and that is the point: a ring is a band of
## ground where every creature is worth the same, so "the ring beyond" is a
## well-defined place to compare against rather than a figure of speech.
##
## ## Why the ceiling is the whole argument
##
## An item's level *is* the level of the creature that dropped it, so every item
## obtainable at distance $d$ is worth $r \times L(d)$ for one of six fixed
## multipliers. The best of them -- the eternal one, one roll in a hundred -- is
##
##     C(d) = r_max * L(d) = 32 * L(d)
##
## and no amount of killing at distance $d$ produces anything above it. Grinding
## therefore *saturates*: the best-of-N curve climbs to $C(d)$ and stops, while
## one ring out the same curve climbs to $C(d + \text{RING\_SPAN})$, which is
## strictly higher because $L$ strictly increases. Only advancing raises the cap.
##
## What is deliberately *not* claimed: that no item from a near ring can beat a
## typical item from the next one. A lucky eternal is worth eight commons, so it
## does buy a few rings of head start -- that is section 4's rarity working as a
## shortcut through the level gradient, and section 5's "skill lets a clever
## player punch slightly past their gear tier". `bin/drops_main.gd` measures how
## far past, rather than leaving it to be imagined.
class_name ItemFrontier

## How wide a ring is, in world units. Four terrain chunks across, so a ring is
## a walk rather than a step, and roughly twenty cells of the tactical lattice.
const RING_SPAN := 64.0

## What a creature standing on spawn is worth.
const SPAWN_LEVEL := 1

## How much a ring adds. One, so that the gradient is the plainest thing that
## rises, and so the ratio between neighbouring rings falls towards one with
## distance rather than exploding.
const LEVELS_PER_RING := 1

## What a creature carries: one held item and four worn ones. The number matters
## to the measurement -- five carried items at one chance in five is one dropped
## item per kill on average -- and to nothing else.
const HELD_CARRIED := 1
const WORN_CARRIED := 4


## Which ring a distance from spawn falls in. Ring 0 contains spawn itself.
static func ring_at(distance: float) -> int:
	return int(floor(maxf(0.0, distance) / RING_SPAN))


## The inner edge of a ring, in world units.
static func distance_of_ring(ring: int) -> float:
	return maxi(0, ring) * RING_SPAN


## What a creature of that ring is worth.
static func level_of_ring(ring: int) -> int:
	return SPAWN_LEVEL + LEVELS_PER_RING * maxi(0, ring)


## What a creature standing that far from spawn is worth.
static func level_at(distance: float) -> int:
	return level_of_ring(ring_at(distance))


## The richest tier there is, taken as the last of the six rather than named, so
## that a seventh tier would raise the ceiling below without editing it.
static func top_tier() -> String:
	return ItemRarity.TIERS[ItemRarity.TIERS.size() - 1]


## The most any item from that ring can be worth: the top multiplier against the
## ring's level. The number grinding converges on and cannot pass.
static func ceiling_of_ring(ring: int) -> int:
	return ItemBudget.total(top_tier(), level_of_ring(ring))


static func ceiling_at(distance: float) -> int:
	return ceiling_of_ring(ring_at(distance))


## The gear one creature carries: one held item, then four worn ones, forged
## against the level its ring gives it. The labels are derived from the source
## name so that the same creature, asked twice, is carrying the same things.
static func carried_at_level(world_seed: int, source: String, level: int) -> Array[Item]:
	var gear: Array[Item] = []
	for index in maxi(0, HELD_CARRIED):
		gear.append(ItemForge.forge(world_seed, "%s/held%d" % [source, index], level, Item.KIND_WEAPON))
	for index in maxi(0, WORN_CARRIED):
		gear.append(ItemForge.forge(world_seed, "%s/worn%d" % [source, index], level, Item.KIND_ARMOUR))
	return gear


## The gear a creature standing `distance` from spawn carries.
static func carried_at(world_seed: int, source: String, distance: float) -> Array[Item]:
	return carried_at_level(world_seed, source, level_at(distance))


## The largest budget in a list of items, or 0 for an empty one.
static func best_budget(items: Array[Item]) -> int:
	var best := 0
	for item in items:
		best = maxi(best, item.budget())
	return best


## Every budget in a list, added up.
static func total_budget(items: Array[Item]) -> int:
	var total := 0
	for item in items:
		total += item.budget()
	return total
