extends RefCounted
## Section 6's ownership rule: who owns a point of ground, as one function of a
## world position and the state of the world.
##
## Section 6, in full: "Ownership is computed per point as a distance-weighted
## average of weighted sentiment: take all entities within a large radius, weight
## each by proximity (closer = higher, e.g. softmin), and combine with their
## weighted sentiment toward each player they know of. If the top ownership score
## exceeds a threshold, that player owns the point; otherwise it's neutral."
## And: "Weighted sentiment = a character's raw sentiment toward a target, scaled
## by that character's status and level -- higher-status characters carry
## diplomatic weight, higher-level characters carry military weight."
##
## That paragraph, and nothing else, is this file.
##
## ## The rule, in one expression
##
## For a point $p$ and a claimant $c$, over every entity $i$ standing within
## `RADIUS` of $p$ other than $c$ itself:
##
## $$O(c, p) = \frac{\sum_i w_i(p) \, m_i \, s(i \to c)}{\sum_i w_i(p) \, m_i}
##   \qquad m_i = \mathrm{status}(i) + \mathrm{level}(i)$$
##
## with $w_i(p)$ the proximity weight of `PROXIMITY` at distance $|p - i|$, and
## $s(i \to c) \in [-1, 1]$ the raw sentiment `RelationshipGraph.sentiment()`
## hands back. The claimant with the greatest $O$ owns $p$ if that score is above
## `THRESHOLD`; otherwise $p$ is neutral.
##
## Five choices are in that expression and each is section 6's own words or a
## consequence of them:
##
##   * **it is an average, so the denominator is there.** Section 6 says
##     "distance-weighted *average* of weighted sentiment", and dividing is what
##     makes the score a number in $[-1, 1]$ whatever size the crowd is. Without
##     it a claimant could own ground by being liked a little by a great many,
##     and one threshold could not serve both an empty moor and a market day.
##   * **an entity that has never met the claimant is in the denominator.**
##     Having no opinion of somebody is an opinion about whether they should hold
##     the ground you are standing on: not this one. So strangers dilute a claim
##     rather than being skipped, and that is exactly what makes crowded
##     contested ground come out neutral.
##   * **a claimant is not a voter in its own claim.** There is no self-edge in
##     the graph -- `RelationshipGraph` refuses one -- so a claimant standing at
##     the point would otherwise enter its own denominator with a sentiment of
##     zero and dilute itself. Standing on ground would then weaken your hold on
##     it, which is the opposite of what section 6 describes.
##   * **status and level are added, not multiplied.** Section 6 wants both to
##     count: diplomatic weight and military weight. A product would let either
##     one at zero erase the other, so a general with no standing would carry no
##     weight at all; a sum lets each move the answer on its own, which is what
##     "both paths matter" means.
##   * **every character in the world is a possible claimant.** Section 6 says
##     "each player they know of", and this file has no way to ask which
##     characters are driven by a person: the claimants are whoever the near
##     entities have met and who is still standing. That is the "no preferential
##     treatment" principle holding in the one place it would be easiest to
##     break.
##
## ## What this file may read, and what it may not
##
## Relationship edges, through `RelationshipGraph.sentiment()` and `.knows()`;
## and character sheets, for a status and a level. Where the entities are, which
## is a position and not an event. That is all of it.
##
## Nothing here knows what a fight is, what a conversation is or what a quest is.
## It does not read a blow, a line of speech, a trade, an offer, a check, an
## encounter or a goal, and `tests/test_ownership.gd` scans the code of this file
## and of `OwnershipClaim` for every one of those words and fails if one appears.
## The reason is not tidiness:
## sentiment is moved by `RelationshipGraph`, out of the world's own record of
## what happened, and a rule that reached past the graph to the events would be a
## second opinion about what those events meant. There is one.
##
## Equally, nothing here *writes*. Ownership is a reading of the graph and never
## a way of changing it, so a run may ask this question as often as it likes and
## the world is the same afterwards.
##
## ## The three numbers section 6 leaves open
##
## Section 13 lists them as an open decision: "Ownership thresholds and weighting
## functions -- softmin temperature, radius, and threshold." They are settled
## below, and each is settled by a measurement on the shipped seeded run rather
## than by taste. `./run_ownership.sh` is that measurement and prints every table
## the choices rest on; the short of it is in the note on each constant.
##
## One thing measured there decides what each of the three is *for*, and it is
## worth having before reading them. Because the rule is an average, the score is
## scale-free in distance: a point 100 units from a lone friendly character
## scores exactly what a point one unit away scores, since in both cases that
## character is the whole of the neighbourhood being averaged over. Distance
## decides which neighbours are heard and how loudly against each other; it does
## not decide whether anybody is heard at all. So the radius is what gives
## territory an edge, because nothing else does; the temperature decides whose
## opinion wins inside that edge; and the threshold decides how favourable a
## neighbourhood has to be. Each is chosen against the measurement that is about
## the job it actually does.
class_name OwnershipField

## Nobody: what an unowned point's owner is. Re-exported from the claim so that
## a caller comparing against it need name only this file.
const NOBODY := OwnershipClaim.NOBODY

# --- The proximity shape --------------------------------------------------

## Softmin: $w = e^{-d/T}$. Section 6's own suggestion. One length scale, and
## influence that dies off geometrically, so a character's territory has an edge.
const SOFTMIN := "softmin"

## Nearness: $w = 1 / (1 + (d/T)^2)$. The other shape measured -- the same length
## scale, but a tail that falls off polynomially, so a far crowd keeps a say.
const NEARNESS := "nearness"

## The two shapes measured, and the only two. See the stop condition on this
## work: if neither separated held ground from neutral ground the answer was to
## report both, not to invent a third rule section 6 does not describe.
const SHAPES := [SOFTMIN, NEARNESS]

## The shape the rule uses.
##
## Measured: softmin, because nearness has no working length scale. Over the
## shipped run's sampled grid, nearness holds 51.3% of the ground at T = 3, at
## T = 6 and at T = 12 -- the same figure to a tenth of a percent across a
## fourfold change in the one number that is supposed to be its length scale --
## and its median top score sits at 0.0515 at every temperature swept, which is
## to say half the grid is parked on the threshold with no structure in it. Its
## polynomial tail is why: an entity at ten times the scale still carries a
## hundredth of the weight of one standing on the point, so the far crowd never
## stops deciding and territory never gets an edge. Softmin over the same span
## moves held ground from 41.5% to 44.4% and its median top score from 0.0005 to
## 0.0279 -- a map with contrast in it, and a temperature that does something. A
## constant chosen by measurement needs a measurement that responds to it.
const PROXIMITY := SOFTMIN

## The softmin temperature $T$, in world units: how far a character's opinion
## carries.
##
## The criterion: the warmest temperature that does not dilute a claim where it
## is strongest -- the widest neighbourhood a point can average over while the
## ground somebody is actually standing on still scores what its neighbours
## actually feel. Measured on the shipped run, where the strongest sentiment
## between two characters both still standing is $+0.1525$ and the ground between
## the two of them scores:
##
##   | $T$ | 3 | 6 | 12 | 24 | 48 | 96 |
##   |-----|---|---|----|----|----|----|
##   | kept | 100.0% | 100.0% | 98.1% | 84.9% | 63.7% | 48.8% |
##
## Twelve is the warmest that keeps 95%. At 24 a sixth of a claim has already
## been averaged away by neighbours fifty units off; at 96 half of it has.
const TEMPERATURE := 12.0

## How far from the point an entity may stand and still have a say, in world
## units. Section 6's "large radius".
##
## The criterion: section 6 asks for an *average*, and an average over one
## opinion is not one. So the radius is the smallest at which most of the sampled
## ground hears two entities or more, rather than being decided by whichever
## single character happens to be nearest:
##
##   | $R$ | 20 | 40 | 60 | 90 | 120 | 180 |
##   |-----|----|----|----|----|-----|-----|
##   | hears nobody | 93.9% | 77.6% | 57.6% | 30.6% | 7.3% | 0.0% |
##   | hears one    | 4.2% | 14.2% | 23.6% | 26.5% | 15.5% | 0.0% |
##   | hears two or more | 1.9% | 8.2% | 18.9% | 43.0% | 77.2% | 100.0% |
##
## A hundred and twenty is the first radius over which the majority of ground is
## averaging rather than looking up its nearest neighbour, and it is the last one
## at which any ground is out of earshot at all: the shipped run is four
## characters spread over about a hundred units, and at 180 every point on the
## grid hears all four, which is a world without distance in it.
const RADIUS := 120.0

## The score a claimant must beat to own the ground.
##
## There is no valley in the data to put this in: the top scores over the sampled
## grid are a gradient and the widest gap between neighbouring ones is 0.0028,
## which is nothing. So it is pinned from both ends by two numbers the world
## itself hands over.
##
## From below, it is what a *single honoured exchange between two strangers*
## earns: `RelationshipGraph` moves familiarity by `MET` and trust by
## `TRADE_TRUST` on one trade, so the sentiment that comes of it is
## $0.25 \times 0.20 = 0.05$. Ground is yours when the neighbourhood, on
## balance, favours you by at least as much as one completed dealing -- which is
## the least anybody can have actually earned. `tests/test_ownership.gd` fails if
## the two numbers ever part, so retuning what a trade is worth cannot leave this
## defended by a sentence that has stopped being true.
##
## From above, the strongest claim the shipped run reaches anywhere is 0.1497, on
## the ground the two who traded are standing on. A threshold over that owns
## nothing, ever, on a world that plays the way this one does; 0.05 clears it
## threefold.
##
## What it comes to on the sampled grid: **62.5% of the ground is neutral** and
## 37.5% is held, by two claimants. The whole curve is in `./run_ownership.sh` --
## 42.8% neutral at 0.005, 54.6% at 0.02, 70.1% at 0.10, and everything neutral
## from 0.20 up.
const THRESHOLD := 0.05


## Who owns a point of ground.
##
## `cast` is everybody standing in the world -- the voters are found inside, and
## a character not in this list can neither vote nor be owed ground, which is how
## the fallen stop holding territory without this file knowing what falling is.
static func at(
	cast: Array[Combatant], graph: RelationshipGraph, at_x: float, at_z: float
) -> OwnershipClaim:
	return measured(cast, graph, at_x, at_z, PROXIMITY, TEMPERATURE, RADIUS, THRESHOLD)


## The same rule under stated constants, which is what the sweep that chose them
## calls. `at()` is this with the four settled values, and there is no second
## copy of the arithmetic anywhere.
static func measured(
	cast: Array[Combatant], graph: RelationshipGraph,
	at_x: float, at_z: float,
	shape: String, temperature: float, radius: float, threshold: float
) -> OwnershipClaim:
	var claim := OwnershipClaim.new()
	claim.at_x = at_x
	claim.at_z = at_z
	claim.radius = radius
	claim.threshold = threshold
	if graph == null:
		return claim

	# Who is near enough to have a say, and how loud a say it is. One pass, and
	# the weight of each is fixed here rather than re-derived per claimant.
	var voices := PackedInt32Array()
	var weights := PackedFloat64Array()
	for one in cast:
		claim.scanned += 1
		var sheet := sheet_of(one)
		if sheet == null:
			continue
		var away := one.distance_from(at_x, at_z)
		if away > radius:
			continue
		var weight := proximity(shape, away, temperature) * float(carry(sheet))
		if weight <= 0.0:
			continue
		voices.append(one.id)
		weights.append(weight)
	claim.considered = voices.size()
	if voices.is_empty():
		return claim

	# What every possible claimant scores. A claimant is anybody still standing
	# that at least one of those voices has met; somebody nobody near here has
	# heard of is not a claimant to this ground, which is not the same as
	# scoring zero on it.
	for other in cast:
		if sheet_of(other) == null:
			continue
		var total := 0.0
		var summed := 0.0
		var met := false
		for index in range(voices.size()):
			var speaker := voices[index]
			if speaker == other.id:
				continue
			total += weights[index]
			if not graph.knows(speaker, other.id):
				continue
			met = true
			summed += weights[index] * graph.sentiment(speaker, other.id)
		if met and total > 0.0:
			claim.consider(other.id, summed / total)
	claim.settle()
	return claim


## The proximity weight of one entity at one distance: section 6's "closer =
## higher", in the shape named.
##
## Both shapes are one over a length scale and nothing else. Neither can be
## negative and neither is zero at zero distance, so an entity standing on the
## point always has the greatest say of anybody there.
static func proximity(shape: String, away: float, temperature: float) -> float:
	var scale := maxf(temperature, 0.0001)
	var apart := maxf(away, 0.0)
	if shape == NEARNESS:
		var over := apart / scale
		return 1.0 / (1.0 + over * over)
	return exp(-apart / scale)


## What one character's opinion is worth: section 6's status and level, added.
##
## Read through `Character.status()` and never off the field behind it, so a
## character nobody has assigned a standing to carries its level twice -- which
## is section 2's "status = level" default and is why levelling up alone already
## moves ownership.
static func carry(sheet: Character) -> int:
	return maxi(sheet.status(), 0) + maxi(sheet.level, 0)


## The character sheet of somebody standing in the world, or null if there is
## none to read: a thing on the ground, or somebody no longer standing.
static func sheet_of(one: Combatant) -> Character:
	if one == null or not one.is_alive():
		return null
	var commander := one.piece as Commander
	return null if commander == null else commander.sheet
