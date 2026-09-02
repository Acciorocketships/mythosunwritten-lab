extends RefCounted
## One way a piece may leave the cell it stands on.
##
## There are exactly two, and every piece in the game -- the four minions, a bare
## commander, a commander in a full suit of armour -- is some list of them.
## Keeping it to two is what lets armour grant movement without armour knowing
## anything about movement generation: a pair of boots hands over a grant, the
## generator already knows what to do with both kinds, and no new branch is
## written anywhere.
##
##   * **LAND** -- arrive on one of a fixed list of offsets. Only the landing is
##     read; the cells crossed to reach it never arise. A Toadstool's walk, a
##     commander's base cardinal step, a pair of boots' diagonal, a Frog's L, and
##     the knight-hop a pair of leggings grants.
##   * **SLIDE** -- ride out along a direction until something stops you: the
##     board's edge, ground you cannot climb, a hole, or a piece. A Cat's
##     diagonals, an Ent's cardinals, a chestplate's two-cell queen.
##
## **A step and a jump are the same rule.** That is worth saying plainly, because
## it was nearly written as two. A king's step and a knight's leap differ only in
## how long the offset is: neither reads anything between where it started and
## where it lands, and for a one-cell offset there is nothing between to read. So
## a chess knight "jumps over" pieces not because it has a power the king lacks,
## but because it is a landing pattern with an offset long enough for the
## question to arise. Writing that as two modes would have been a distinction the
## code does not make -- and a mutation of it would be a mutation nothing could
## catch, which is how this one was found.
##
## A landing still has to be somewhere a piece can be: it is checked by the
## board's own reach rule, the same one a slide checks every cell of its ray
## with (see LegalMoves).
class_name MoveGrant

## Arrive on a listed offset, reading only the landing.
const LAND := 0

## Ride out along a listed direction until something stops you.
const SLIDE := 1

## A slide with no reach of its own: it runs until the board or something on it
## stops it.
const UNBOUNDED := 0

## Which of the two this is.
var mode: int = LAND

## For a LAND, the offsets it arrives on. For a SLIDE, the directions it rides
## along. Canonical in both cases.
var offsets: Array[Vector2i] = []

## For a SLIDE, how many cells it may ride at most; UNBOUNDED for as far as the
## board allows. Ignored by a LAND, which is one arrival per offset.
var reach: int = UNBOUNDED

## What granted this, for a report line and for a failure message. Never read by
## the generator.
var source: String = ""


static func land(landings: Array[Vector2i], granted_by: String = "") -> MoveGrant:
	return _make(LAND, landings, UNBOUNDED, granted_by)


static func slide(
	directions: Array[Vector2i], cells: int = UNBOUNDED, granted_by: String = ""
) -> MoveGrant:
	return _make(SLIDE, directions, cells, granted_by)


static func _make(
	kind: int, listed: Array[Vector2i], cells: int, granted_by: String
) -> MoveGrant:
	var grant := MoveGrant.new()
	grant.mode = kind
	grant.offsets = PieceGeometry.canonical(listed)
	grant.reach = cells
	grant.source = granted_by
	return grant


## The two by name, for a report line and a failure message.
func mode_name() -> String:
	match mode:
		LAND:
			return "land"
		SLIDE:
			return "slide"
	return "unknown"


## One line describing the grant, in the form the reports and the tests compare.
func line() -> String:
	var span := "unbounded" if reach == UNBOUNDED else str(reach)
	return "%s %s reach=%s %s" % [
		source if source != "" else "-", mode_name(), span,
		PieceGeometry.pattern_text(offsets),
	]
