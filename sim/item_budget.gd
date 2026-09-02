extends RefCounted
## The one power budget, and the rule that spends it across three axes without
## losing a point.
##
## Section 4: *an item's total power = rarity x the level of the creature that
## dropped it, distributed across movement + defence + effects.* Written out:
##
##     P = r(rarity) * L_source
##
## and then
##
##     P = movement + defence + effects,   exactly, in integers.
##
## The second line is the one that does the work. If it held only approximately
## then "movement and defence trade off on the same item" would be a claim about
## intent rather than about arithmetic, and a generator could quietly hand out a
## godlike-mobility chestplate that also had full defence by losing a rounding
## error in the item's favour every time. So the split is exact, and this file is
## where that is arranged.
##
## ## The rounding rule, and where the remainder goes
##
## An item is shaped by three integer weights -- how much of itself it wants to
## be movement, defence and effects. Those weights almost never divide $P$
## evenly. The rule is the *largest remainder* method:
##
##   1. each axis takes `floor(P * w_i / W)`, where `W` is the sum of the
##      weights;
##   2. that leaves `P - sum(floor)` points over, which is always fewer points
##      than there are axes -- at most two;
##   3. each leftover point goes to the axis with the largest discarded
##      fraction, and ties go to the earlier axis in the fixed order
##      *movement, defence, effects*.
##
## The remainder therefore goes to the axis that was rounded down hardest, and
## never off the item. That the sum is exactly $P$ is not a property that has to
## be tested for luckily: `sum(P*w_i) = P*W`, so the discarded remainders sum to
## a multiple of `W`, so step 2's leftover is exactly `sum(rem_i)/W` and step 3
## hands out precisely that many points.
##
## The same rule is used a second time, one level down, to divide the effects
## axis among an item's individual effects -- so an item's effects also sum to
## its effects budget exactly, for the same reason and by the same code.
class_name ItemBudget

## The three axes, in the fixed order every weight list, every split and every
## tie-break uses. Section 4's own list, in section 4's own order.
const MOVEMENT := 0
const DEFENCE := 1
const EFFECTS := 2

## Their names, for a report line and a failure message.
const AXES := ["movement", "defence", "effects"]

## The weight total a shape is written against. Weights are read as a proportion
## of their own sum, so this is a convention for legibility -- three weights that
## sum to a hundred read as percentages -- and not a requirement `split()` makes.
const WEIGHT_TOTAL := 100


## $P = r(\text{rarity}) \times L_{\text{source}}$.
##
## The item's level *is* the source level: an item is worth the creature it came
## off, and there is no second number. A negative or zero source level yields a
## budget of nothing, which is the right answer -- there is nothing to spend.
static func total(rarity: String, source_level: int) -> int:
	return ItemRarity.multiplier(rarity) * maxi(0, source_level)


## Spend `amount` across weighted parts so that the parts sum to `amount`
## exactly. The rounding rule is the file's docstring; the returned array is the
## same length as `weights`, in the same order.
@warning_ignore("integer_division")
static func split(amount: int, weights: Array[int]) -> Array[int]:
	var parts: Array[int] = []
	if weights.is_empty():
		return parts

	var to_spend := maxi(0, amount)
	var denominator := 0
	for weight in weights:
		denominator += maxi(0, weight)

	# Every part asked for nothing. The budget still has to land somewhere, and
	# the fixed order says where: the first part. Silently dropping it is the
	# one outcome this whole file exists to prevent.
	if denominator == 0:
		for index in weights.size():
			parts.append(to_spend if index == 0 else 0)
		return parts

	var remainders: Array[int] = []
	var spent := 0
	for weight in weights:
		var product := to_spend * maxi(0, weight)
		var share := product / denominator
		parts.append(share)
		remainders.append(product % denominator)
		spent += share

	# At most `weights.size() - 1` points are left, and each goes to the part
	# that was rounded down hardest. A strict comparison keeps ties with the
	# earlier part, which is what makes the tie-break the fixed axis order.
	for _point in to_spend - spent:
		var best := 0
		for index in range(1, remainders.size()):
			if remainders[index] > remainders[best]:
				best = index
		parts[best] += 1
		remainders[best] = -1
	return parts


## The sum of a split. Used by every caller that wants to say "and it is exactly
## the budget" rather than assume it.
static func sum(parts: Array[int]) -> int:
	var total_of := 0
	for part in parts:
		total_of += part
	return total_of


## A shape written the way a report reads it: three weights out of a hundred,
## given an effects share and how much of what is left goes to movement.
##
## This is where movement and defence are made to compete, and it is deliberately
## the only place. Effects take their share off the top; *everything else on the
## item is one number split two ways*, so a point of movement is a point of
## defence not taken. There is no third source of either.
@warning_ignore("integer_division")
static func shape(effects_share: int, movement_of_rest: int) -> Array[int]:
	var effects := clampi(effects_share, 0, WEIGHT_TOTAL)
	var rest := WEIGHT_TOTAL - effects
	var movement := rest * clampi(movement_of_rest, 0, WEIGHT_TOTAL) / WEIGHT_TOTAL
	var weights: Array[int] = [movement, rest - movement, effects]
	return weights
