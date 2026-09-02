extends RefCounted
## The shapes a piece is made of: directions, quarter turns, and the three
## generators every pattern in the layer is built from.
##
## Nothing here knows about a board, a piece or an item. It is arithmetic on
## lattice offsets, kept in one place so that a minion's move pattern, a suit of
## armour's movement grant and a weapon's attack pattern are all the same kind of
## thing -- a list of offsets -- rather than three vocabularies that happen to
## look alike.
##
## ## Offsets are relative, and canonical
##
## Every list this file produces comes back through `canonical()`: sorted by row
## then column, with duplicates removed. That is not tidiness. A pattern is
## compared against an expected list in the tests, unioned with other patterns
## when armour stacks, and fingerprinted; all three want two equal patterns to be
## the same array, whichever generator or whichever order produced them.
##
## ## Which way is front
##
## A facing is one of four quarter turns, and patterns are authored for a piece
## facing NORTH -- towards decreasing z, which is `Vector2i(0, -1)`. Rotating
## clockwise seen from above sends north to east: (x, z) becomes (-z, x). A
## pattern with a front to it therefore stops covering the cells behind the piece
## the moment it turns, and a pattern that is symmetric about the piece -- a ring,
## an all-round flail -- rotates onto itself and does not care. Both of those are
## consequences of one rotation, not two cases.
class_name PieceGeometry

## The four quarter turns, as indices into FACINGS. A facing is stored as one of
## these rather than as a vector so that "turn to face east" is one assignment
## and rotating a pattern is one number.
const NORTH := 0
const EAST := 1
const SOUTH := 2
const WEST := 3

## What each facing points at, north first, clockwise. North is -z because the
## rest of the project's yaw of 0 faces +z, so north is the far side.
const FACINGS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

## The four cardinal steps. A commander's base movement, an Ent's lines, and the
## cells a Toadstool walks onto.
const CARDINALS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

## The four diagonal steps. A Cat's lines, the cells a Toadstool captures on, and
## what a pair of boots adds to a commander.
const DIAGONALS: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## All eight directions: the queen's lines, and what a high-tier chestplate
## grants two cells of.
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## The eight L-shaped hops: two cells one way and one the other. The Frog's whole
## pattern, and what a pair of leggings adds to a commander.
const KNIGHT_HOPS: Array[Vector2i] = [
	Vector2i(1, -2), Vector2i(2, -1), Vector2i(2, 1), Vector2i(1, 2),
	Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(-1, -2),
]


## One offset turned by whole quarter turns clockwise, seen from above.
##
## Negative and large turns are folded into the four, so a facing index can be
## handed straight in and a piece that turns five times is a piece that turned
## once.
static func rotate(offset: Vector2i, quarter_turns: int) -> Vector2i:
	var turns := ((quarter_turns % 4) + 4) % 4
	var turned := offset
	for _each in turns:
		turned = Vector2i(-turned.y, turned.x)
	return turned


## A whole pattern turned, and returned canonical.
static func rotate_all(offsets: Array[Vector2i], quarter_turns: int) -> Array[Vector2i]:
	var turned: Array[Vector2i] = []
	for offset in offsets:
		turned.append(rotate(offset, quarter_turns))
	return canonical(turned)


## Every offset a step away in the given directions, out to `reach` cells.
##
## The straight-line generator. `line(CARDINALS, 1, 1)` is a king's cardinal
## step and `line(ALL_DIRECTIONS, 1, 2)` is the two-cell queen a chestplate
## grants -- the same call, different numbers.
static func line(
	directions: Array[Vector2i], nearest: int = 1, furthest: int = 1
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for direction in directions:
		for distance in range(nearest, furthest + 1):
			cells.append(direction * distance)
	return canonical(cells)


## Every offset whose straight-line distance from the piece falls between two
## radii, the origin never among them.
##
## What a bow's ring at five to ten cells is, and what a flail's all-round sweep
## at one cell is. Distance is measured across the lattice rather than along it,
## so a ring is round rather than square.
static func ring(nearest: float, furthest: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var bound := int(ceilf(furthest))
	for row in range(-bound, bound + 1):
		for column in range(-bound, bound + 1):
			if row == 0 and column == 0:
				continue
			var span := Vector2(float(column), float(row)).length()
			if span >= nearest and span <= furthest:
				cells.append(Vector2i(column, row))
	return canonical(cells)


## A filled square of cells `half` either side of a centre offset.
##
## What an area attack is: `block(Vector2i(0, -4), 1)` is the three-by-three the
## design's fireball lands four cells ahead.
static func block(centre: Vector2i, half: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in range(-half, half + 1):
		for column in range(-half, half + 1):
			cells.append(centre + Vector2i(column, row))
	return canonical(cells)


## The union of several patterns, canonical. What stacking armour does.
static func union(patterns: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pattern in patterns:
		for offset in pattern:
			cells.append(offset)
	return canonical(cells)


## A pattern in the one order the whole layer compares patterns in: by row, then
## by column, with duplicates dropped.
static func canonical(cells: Array[Vector2i]) -> Array[Vector2i]:
	var sorted: Array[Vector2i] = cells.duplicate()
	sorted.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		if left.y != right.y:
			return left.y < right.y
		return left.x < right.x)
	var unique: Array[Vector2i] = []
	for cell in sorted:
		if unique.is_empty() or unique[unique.size() - 1] != cell:
			unique.append(cell)
	return unique


## A pattern written out, for a report line or a failure message.
static func pattern_text(cells: Array[Vector2i]) -> String:
	var parts := PackedStringArray()
	for cell in cells:
		parts.append("(%d,%d)" % [cell.x, cell.y])
	return " ".join(parts)
