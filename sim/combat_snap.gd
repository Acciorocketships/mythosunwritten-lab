extends RefCounted
## The two directions of the snap: a world position onto a lattice cell, and a
## lattice cell back to a world position.
##
## This is the whole of the arithmetic that lets a real-time overworld and a
## turn-based board be the same place. It is one file with two functions facing
## each other, so that the claim they make together can be read in one sitting
## and checked in one test.
##
## ## The round trip
##
## The board's lattice is fixed to the world origin: cell `(i, j)` is centred at
## `((i + 0.5) * s, (j + 0.5) * s)` and nowhere else, whoever asked for it. So
## the two directions compose to the identity on cells:
##
##     cell_of(centre_of(c)) == c   for every cell c
##
## That is exact rather than approximate. `centre_of` puts the position in the
## middle of the cell, half a cell from every edge, and `cell_of` floors --
## so the answer cannot fall on the boundary between two cells whatever the
## floating-point arithmetic does with a half. `round_trips()` asks it of every
## cell of a board, and the suite runs it on boards read off the generated world
## as well as on typed-out ones.
##
## The other direction does **not** compose to the identity, and cannot: a cell
## is three world units across and a position is a point, so `centre_of(cell_of(p))`
## is `p` moved to the middle of its cell. That is the snap, and the acceptance
## it has to meet is the one the design states -- a combatant occupies *the cell
## nearest the position it was standing at* -- not that it stands exactly where
## it stood.
##
## ## When the nearest cell will not do
##
## The cell a combatant is standing over may be a hole, may be built on, or may
## already hold somebody else. `place()` then searches outwards for the nearest
## cell that will take it, in rings of increasing distance and, inside a ring, by
## true distance from the position it was standing at with the lattice order
## breaking ties. Nothing is nudged: either a cell is found within
## `SEARCH_RINGS`, or the placement fails and says so, and the encounter that
## asked refuses to start rather than putting a piece somewhere that would not
## take it back.
class_name CombatSnap

## How far out the search for a free standable cell goes, in rings around the
## cell the combatant was standing over. Four rings is twelve world units, which
## is wider than any gap the join radius can leave; past that, a combatant is
## standing somewhere a fight cannot be held and the answer is to say so.
const SEARCH_RINGS := 4


## Which cell of the world-fixed lattice a world position falls in.
##
## The board's own arithmetic, forwarded rather than restated, so the cell a
## combatant snaps to and the cell the board built for that ground are the same
## cell by construction.
static func cell_for(x: float, z: float, size: float = CombatBoard.CELL_SIZE) -> Vector2i:
	return CombatBoard.cell_of(x, z, size)


## Where a cell puts a piece back in the world: the centre of the cell, at the
## height the board says that cell's surface is.
##
## The height is the board's rather than a fresh terrain lookup on purpose. The
## board was read on one storey, and a survivor of a fight on a floating island
## has to come back onto the island rather than onto the ground under it -- the
## cell already carries which of the two it is, and asking the terrain again
## would throw that away.
static func world_of(board: CombatBoard, cell: Vector2i) -> Vector3:
	var middle := board.centre(cell)
	return Vector3(middle.x, board.height_at(cell), middle.y)


## Whether every cell of a board survives the round trip through a world
## position. True by construction; asked anyway, because "by construction" is a
## claim about arithmetic and this is the arithmetic.
static func round_trips(board: CombatBoard) -> bool:
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var middle := board.centre(cell)
			if cell_for(middle.x, middle.y, board.cell_size) != cell:
				return false
	return true


## Put a list of combatants onto the board, nearest cell first.
##
## Combatants are placed in the order given, and the order is the roster's own id
## order, so which of two combatants contending for one cell gets it is decided
## the same way in every process. Returns
##
##     {"ok": bool, "placed": {combatant id -> cell}, "lines": PackedStringArray,
##      "unplaced": PackedInt32Array}
##
## and on failure places nobody: a fight that cannot seat everyone is not held.
## `lines` records, per combatant, the position it was standing at, the cell it
## went to, and how far the two are apart -- which is the evidence for "nearest",
## written down rather than asserted.
static func place(board: CombatBoard, combatants: Array[Combatant]) -> Dictionary:
	var taken := {}
	var placed := {}
	var lines := PackedStringArray()
	var unplaced := PackedInt32Array()
	for one in combatants:
		var found := nearest_free_cell(board, taken, one.x, one.z)
		if not bool(found["ok"]):
			unplaced.append(one.id)
			lines.append("snap-in #%d at (%.3f, %.3f) no free standable cell within %d rings"
				% [one.id, one.x, one.z, SEARCH_RINGS])
			continue
		var cell: Vector2i = found["cell"]
		taken[cell] = one.id
		placed[one.id] = cell
		var middle := board.centre(cell)
		# `rings` is how far the search had to go: 0 whenever the cell the
		# combatant was standing over would take it, which is the ordinary case.
		# Anything above 0 says that cell was water, or built on, or already
		# spoken for, and is the whole record of why the piece is not on it.
		lines.append(
			"snap-in #%d (%.3f, %.3f) -> cell (%d,%d) centre (%.3f, %.3f) moved %.3f rings=%d"
			% [
				one.id, one.x, one.z, cell.x, cell.y, middle.x, middle.y,
				Vector2(middle.x - one.x, middle.y - one.z).length(),
				int(found["rings"]),
			])
	return {
		"ok": unplaced.is_empty(),
		"placed": placed,
		"lines": lines,
		"unplaced": unplaced,
	}


## The nearest cell to a world position that a piece may stand on and nobody has
## taken, searched outwards in rings.
##
## `taken` is a set of cells already spoken for, keyed by cell. Returns
## `{"ok": bool, "cell": Vector2i, "rings": int}`; `rings` is how far out the
## search had to go, which is 0 whenever the obvious answer was available.
static func nearest_free_cell(
	board: CombatBoard, taken: Dictionary, x: float, z: float
) -> Dictionary:
	var home := cell_for(x, z, board.cell_size)
	for radius in SEARCH_RINGS + 1:
		var ring := _ring(home, radius)
		# Inside a ring, by true distance from where the combatant was standing,
		# with the lattice order breaking exact ties. Sorting rather than taking
		# the first acceptable cell is what makes "nearest" mean nearest and not
		# "first in the scan".
		ring.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
			var left_at := board.centre(left)
			var right_at := board.centre(right)
			var left_far := Vector2(left_at.x - x, left_at.y - z).length_squared()
			var right_far := Vector2(right_at.x - x, right_at.y - z).length_squared()
			if not is_equal_approx(left_far, right_far):
				return left_far < right_far
			if left.y != right.y:
				return left.y < right.y
			return left.x < right.x)
		for cell in ring:
			if taken.has(cell):
				continue
			if not board.is_standable(cell) or board.blocks_move(cell):
				continue
			return {"ok": true, "cell": cell, "rings": radius}
	return {"ok": false, "cell": home, "rings": SEARCH_RINGS}


## The cells exactly `radius` cells away from a centre in Chebyshev distance --
## the square ring around it. Radius 0 is the centre itself.
static func _ring(centre: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if radius == 0:
		cells.append(centre)
		return cells
	for offset in range(-radius, radius + 1):
		cells.append(centre + Vector2i(offset, -radius))
		cells.append(centre + Vector2i(offset, radius))
	for offset in range(-radius + 1, radius):
		cells.append(centre + Vector2i(-radius, offset))
		cells.append(centre + Vector2i(radius, offset))
	return cells
