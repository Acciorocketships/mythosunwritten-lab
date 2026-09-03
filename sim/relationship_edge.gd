extends RefCounted
## One relationship: a single record standing *between* two entities, and inside
## neither of them.
##
## Section 10 asks for exactly this and says why: "Relationships live on edges
## between entities, not inside any single NPC's memory -- a shared graph
## retrieved when interacting with that target." What that buys is one account of
## what two characters are to each other. A pair of per-sheet dictionaries would
## be two accounts of the same history, and two accounts of one thing drift: the
## character serviced first would write its half, the other's half would be
## written from a world that had already moved, and nothing anywhere would say
## which of the two was right. There is nothing to keep in step here, because
## there is only ever one of these per pair -- `RelationshipGraph` hands the same
## object back whichever end it is asked from.
##
## ## Two sides, because what happened did not happen to both alike
##
## The record is one; what it holds is two-sided. A blow has a striker and a
## struck, and a gift has a giver and a receiver: writing one set of numbers for
## both would say the person who swung the sword is as afraid as the person who
## was hit. So an edge carries section 10's four fields *once per end*, and
## `toward()` reads the end belonging to whoever is looking.
##
## The four, and what each one is:
##
##   * **trust** -- would this character rely on the other. Moved by trades
##     honoured and gifts received; taken away by being struck.
##   * **fear** -- would this character rather the other were not near. Moved by
##     being struck, in proportion to what the blow took.
##   * **respect** -- how much this character rates what the other can do. Moved
##     by being struck (capability shown, whatever else it was) and, a little, by
##     an exchange honoured.
##   * **familiarity** -- how much of the other this character has actually seen.
##     Moved by *every* happening between the two, words included, and by nothing
##     else.
##
## Every one of the four lies in $[0, 1]$, and no rule anywhere may put one
## outside it -- see `raise()` and `lower()`, which are the only two ways any of
## them ever moves.
##
## ## The summary is shared, and neutral, because it is the world's
##
## `notes` is section 10's "short summary of key interactions" and there is one
## of it for the pair rather than one per side. It is written in the world's
## voice -- "#1 gave #2 a brass lantern", not "I was robbed" -- because these are
## the world's record of what happened and not either character's reading of it.
## What a character makes of what happened is what the four numbers are for, and
## what it *remembers* of it is `CharacterMemory`'s, written out of what that
## character could see. Only the last few are kept: it is a summary, and a log
## that kept everything would be the memory store a second time.
class_name RelationshipEdge

## The four fields, in the order section 10 lists them. A report, a fingerprint
## and a test all walk this rather than naming the four by hand.
const FIELDS := ["trust", "fear", "respect", "familiarity"]

## How many lines of the shared summary are kept, newest last. Four: enough that
## a run can see what an edge is made of, few enough that this stays a summary.
const NOTES_KEPT := 4

## The bounds every one of the four lies between, always.
const FLOOR := 0.0
const CEILING := 1.0


## The two ends, always in this order, so that a pair has one key whichever way
## round it is named.
var low: int = 0
var high: int = 0

## The world's own short summary of what has passed between the two, oldest
## first, at most `NOTES_KEPT` of them.
var notes := PackedStringArray()

## How many happenings this edge has been made of, all told -- including the ones
## whose note has since fallen off the end of the summary.
var happenings: int = 0

# The four numbers at each end, by the id of the end they belong to.
var _sides: Dictionary = {}


## A fresh edge between two entities, with every field at nothing.
##
## Nothing is at zero because nobody has been assessed; zero is where two
## characters who have never met each other start, and the first thing that
## happens between them is what moves it.
static func between(a: int, b: int) -> RelationshipEdge:
	var edge := RelationshipEdge.new()
	edge.low = mini(a, b)
	edge.high = maxi(a, b)
	edge._sides = {edge.low: _nothing(), edge.high: _nothing()}
	return edge


## The key a pair of ids has in the graph, whichever order they are given in.
static func key_for(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


## This edge's own key.
func key() -> String:
	return key_for(low, high)


## Whether this edge is one of a character's own.
func joins(id: int) -> bool:
	return id == low or id == high


## The other end. Handed the id of somebody who is not on this edge it answers
## with `low`, which is what any reading of an edge that is not yours deserves --
## but nothing asks that, because the graph only ever hands a character its own.
func other_than(id: int) -> int:
	return high if id == low else low


## The four numbers as one end of this edge holds them: how *this* character
## feels about the one at the other end.
##
## A copy, deliberately. Reading a relationship is never a way of writing one,
## and the only writers are `raise()` and `lower()` below.
func toward(viewer: int) -> Dictionary:
	var side: Dictionary = _sides.get(viewer, _nothing())
	return side.duplicate()


## One named field at one end.
func field(viewer: int, named: String) -> float:
	return float(toward(viewer).get(named, 0.0))


## Move a field up, by closing `share` of the distance left to the ceiling.
##
## Every rule that raises anything is this shape, and it is this shape for two
## reasons. It cannot leave the range, whatever it is handed and however many
## times it is applied. And it is worth most the first time: the first exchange
## with a stranger tells you far more than the fortieth, which is the shape
## trust, fear, respect and familiarity all actually have.
func raise(viewer: int, named: String, share: float) -> float:
	return _write(viewer, named, share)


## Move a field down, by giving up `share` of what is there.
##
## The mirror of `raise()`, and it cannot go below the floor for the same reason
## the other cannot go above the ceiling.
func lower(viewer: int, named: String, share: float) -> float:
	if not _sides.has(viewer) or not FIELDS.has(named):
		return 0.0
	var was := float(_sides[viewer][named])
	var now := clampf(was - was * clampf(share, 0.0, 1.0), FLOOR, CEILING)
	_sides[viewer][named] = now
	return now


## Write one line of the shared summary, and count the happening it came out of.
func note(said: String) -> void:
	happenings += 1
	if said == "":
		return
	notes.append(said)
	while notes.size() > NOTES_KEPT:
		notes.remove_at(0)


## The one number section 6's ownership maths reads: this character's raw
## sentiment toward the one at the other end.
##
## $$s = \mathrm{familiarity} \times (\mathrm{trust} - \mathrm{fear})$$
##
## in $[-1, 1]$. The whole reasoning is at the head of
## `sim/relationship_graph.gd`, in one place, because a composite defined in two
## places is two composites.
func sentiment_of(viewer: int) -> float:
	var side := toward(viewer)
	return float(side["familiarity"]) * (float(side["trust"]) - float(side["fear"]))


## What one end of this edge holds, in one line, for a report and a test.
func line_toward(viewer: int) -> String:
	var side := toward(viewer)
	return "#%d -> #%d trust %.2f fear %.2f respect %.2f familiarity %.2f sentiment %+.2f" % [
		viewer, other_than(viewer),
		side["trust"], side["fear"], side["respect"], side["familiarity"],
		sentiment_of(viewer),
	]


## The whole edge, both ends and the shared summary, in one line.
func line() -> String:
	return "#%d <-> #%d %s | %s | %s" % [
		low, high, "%d happening%s" % [happenings, "" if happenings == 1 else "s"],
		_half(low), _half(high),
	]


## A short, stable rendering of everything on this edge, for the world's own
## fingerprint. Both ends and the summary, so two runs that agree on an edge
## agree on all of it.
func fingerprint() -> String:
	var parts := PackedStringArray()
	parts.append("%d-%d n=%d" % [low, high, happenings])
	for end in [low, high]:
		var side: Dictionary = _sides[end]
		var numbers := PackedStringArray()
		for named in FIELDS:
			numbers.append("%s=%.4f" % [named, float(side[named])])
		parts.append("%d %s" % [end, " ".join(numbers)])
	parts.append_array(notes)
	return " ".join(parts)


func _half(end: int) -> String:
	var side: Dictionary = _sides[end]
	var numbers := PackedStringArray()
	for named in FIELDS:
		numbers.append("%s %.2f" % [named, float(side[named])])
	return "#%d %s" % [end, " ".join(numbers)]


func _write(viewer: int, named: String, share: float) -> float:
	if not _sides.has(viewer) or not FIELDS.has(named):
		return 0.0
	var was := float(_sides[viewer][named])
	var now := clampf(was + (CEILING - was) * clampf(share, 0.0, 1.0), FLOOR, CEILING)
	_sides[viewer][named] = now
	return now


static func _nothing() -> Dictionary:
	return {"trust": 0.0, "fear": 0.0, "respect": 0.0, "familiarity": 0.0}
