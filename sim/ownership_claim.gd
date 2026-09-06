extends RefCounted
## What the ownership rule answered about one point of ground.
##
## One of these comes back from every call to `OwnershipField.at()`, and it
## carries the answer *and* what the answer was made of: the score every
## claimant got, how many entities were near enough to have a say, and how many
## the rule had to look at to find them. The reason it carries the workings is
## that the three constants the rule reads are chosen by measurement, and a
## measurement that could only see the verdict could not defend them.
##
## Neutral is a real answer and not a missing one. Ground nobody's neighbours
## feel strongly enough about is neutral, ground with nobody within the radius at
## all is neutral, and the two are told apart by `considered`.
class_name OwnershipClaim

## The owner of ground that has none. Zero, because combatant ids are handed out
## from one upwards, so no real claimant can collide with it.
const NOBODY := 0


## The point this was asked about, in world units.
var at_x: float = 0.0
var at_z: float = 0.0

## Who owns it, or `NOBODY`.
var owner_id: int = NOBODY

## The best score any claimant got, whether or not it passed the threshold, and
## whose it was. Kept even when the ground came out neutral: "neutral by a
## hair" and "neutral because nobody near here has met anybody" are different
## facts about the same point.
var best_id: int = NOBODY
var best: float = 0.0

## The second-best score and whose it was. What makes a point *contested*
## legible: two claimants at 0.30 and 0.29 is a border, one at 0.30 and nothing
## else is a heartland.
var second_id: int = NOBODY
var second: float = 0.0

## How many entities were near enough to have a say -- the size of the set the
## average was taken over.
var considered: int = 0

## How many entities the rule had to look at to find those. The cost of asking,
## as a number rather than an assumption.
var scanned: int = 0

## Which radius and threshold this answer was worked out under. Carried so that
## a sweep's rows say for themselves what they were measured at.
var radius: float = 0.0
var threshold: float = 0.0

## Every claimant's score, by id. Insertion order, which is the order the cast
## is held in, which is id order.
var scores: Dictionary = {}


## Whether the ground came out neutral.
func is_neutral() -> bool:
	return owner_id == NOBODY


## Whether anybody at all was near enough to have a say. Neutral ground with
## nobody on it is a different thing from neutral ground with a crowd that
## cannot agree, and this is what tells them apart.
func any_near() -> bool:
	return considered > 0


## How far ahead the winner is of the runner-up. Zero where there is no
## runner-up, which is the honest answer: nothing was beaten.
func margin() -> float:
	return best - second if second_id != NOBODY else best


## One claimant's score, or zero if nobody near here has met it.
func score_of(id: int) -> float:
	return float(scores.get(id, 0.0))


## Record one claimant's score, keeping the best two.
##
## Ties go to the lower id, because the cast is walked in id order and a strictly
## greater score is what displaces the standing best. A rule that broke ties any
## other way would need something outside the graph to break them with.
func consider(id: int, score: float) -> void:
	scores[id] = score
	if best_id == NOBODY or score > best:
		second_id = best_id
		second = best
		best_id = id
		best = score
	elif second_id == NOBODY or score > second:
		second_id = id
		second = score


## Settle the verdict: the best claimant owns the ground if its score passes the
## threshold, and otherwise the ground is neutral.
func settle() -> void:
	owner_id = best_id if best > threshold and best_id != NOBODY else NOBODY


## The answer in one line, for a report and a test.
func line() -> String:
	return "(%7.1f,%7.1f) owner=%s best=%s %+.4f second=%s %+.4f near=%d of %d" % [
		at_x, at_z,
		"none" if is_neutral() else "#%d" % owner_id,
		"none" if best_id == NOBODY else "#%d" % best_id, best,
		"none" if second_id == NOBODY else "#%d" % second_id, second,
		considered, scanned,
	]
