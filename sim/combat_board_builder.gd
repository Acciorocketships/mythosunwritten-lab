extends RefCounted
## Reads a rectangle of the generated world as a board.
##
## It adds nothing to the world. Every answer it writes into a cell comes out of
## one terrain query call or another -- `support_at` for the surface, `is_void_at`
## for the hole, `islands_at` for the storey, `is_reserved_at` for the buildings
## -- and the two thresholds it compares against are the query's own walking
## constants. There is no second rule here about what a hole is, and there is no
## number here that the ground does not already live by.
##
## ## How a storey is chosen, and why every cell is read on its own
##
## The world has more than one surface over a position: an island's top and the
## ground beneath it are the same x and z. A board therefore has to be told which
## of them it is about, and it is told by the height it is built from -- the same
## way an observer knows which storey it is walking on.
##
## What that height then does is the load-bearing decision here. It is **not**
## used as a plane for the whole board: a board forty units across laid over a
## hill would have its far cells out of reach of a single plane and would read
## them as holes. Nor is the storey walked outwards from the anchor cell,
## because then a cell's answer would depend on the path taken to it, and two
## boards over the same ground could disagree about a cell they share.
##
## Instead the anchored storey supplies a **reference surface**, sampled afresh
## under every cell:
##
##   * a board on the ground references the ground's own height there;
##   * a board on island K references K's top there -- and K's top function
##     returns the rim height outside K's outline, so the reference carries on
##     past the rim at the level of the edge you would walk off.
##
## Each cell then asks `support_at` from its own reference and gets the surface
## within a hop up or a step down of it. Nothing is carried from cell to cell, so
## a cell's contents depend on the cell, the seed, and the anchored storey and on
## nothing else -- which is exactly what makes two overlapping boards agree, and
## what makes a board built after a hundred others identical to one built fresh.
##
## Two things fall out of that for free, both of them right:
##
##   * A ground cell under the lip of an island resolves to the **island**, not
##     to the ground, because the rim is within a hop above it. That is not a
##     special case; it is the same rule that says walking into that stretch of
##     rim carries you up onto it.
##   * An island cell past the rim resolves to the ground where the rim is a
##     step above it and to a **hole** where it is a fall. The island's edge is
##     therefore a cliff edge exactly where it is too high to climb down, which
##     is where a shove off it should mean something.
class_name CombatBoardBuilder

## Half the width of the rectangle a board covers by default, in world units.
##
## Sixty units square is what a fight is: about twenty cells on a side, which is
## a chess board and a half, and about the size of a village green. The
## measurements behind it are in reports/combat-board.md.
const DEFAULT_SPAN := 30.0

## How close two heights have to be to be the same surface. The heights compared
## are both produced by the same field arithmetic, so this only has to survive
## being copied about, not being recomputed a different way.
const SAME_SURFACE := 0.000001

## Everything the board knows about the ground. One query, so a board and the
## geometry a mesher builds cannot disagree about any layer of the stack.
var terrain: TerrainQuery = null


func _init(query: TerrainQuery = null) -> void:
	terrain = query


## The board around a position, read on the storey reached from `from_height`.
##
## The rectangle is the square of `span` world units either side of the position,
## grown outwards to whole cells of the world-fixed lattice. Growing outwards
## rather than centring cells on the position is what keeps the lattice fixed:
## where the board's edge falls depends on the position, but where its cells fall
## never does.
func build(
	x: float,
	z: float,
	from_height: float,
	span: float = DEFAULT_SPAN,
	size: float = CombatBoard.CELL_SIZE,
) -> CombatBoard:
	var lowest := CombatBoard.cell_of(x - span, z - span, size)
	var highest := CombatBoard.cell_of(x + span, z + span, size)
	var across := highest.x - lowest.x + 1
	var deep := highest.y - lowest.y + 1

	var board := CombatBoard.new()
	board.shape(lowest, across, deep, size)
	board.anchor_cell = CombatBoard.cell_of(x, z, size)
	# A builder with no terrain hands back the window with nothing read in it:
	# the cells are there and every one of them is unknown. A scene staged
	# without ground under it -- which is what a bare test scene is -- has no
	# ground to report, and saying so is the same answer the packet already gives
	# for a cell it could not read.
	if terrain == null:
		return board
	board.world_seed = terrain.world_seed
	# Which storey the height names, taken as given rather than settled first.
	# Settling would consult `support_at`, and `support_at` carries you up onto
	# anything within a hop -- so a board asked for on the ground under an
	# island's lip would come back as the island's board. The height names a
	# storey; the storey names a reference surface; the cells do the rest.
	var storey_island := _island_of_storey(x, z, from_height)
	board.anchor_height = _reference_at(x, z, storey_island)
	board.anchor_storey = _storey_of(x, z, board.anchor_height)

	# One row of cells beyond the board on every side. A cell's cliff edge and
	# its blocking face are read off its four neighbours, so the cells on the
	# board's own border need neighbours that are not on it -- otherwise a border
	# cell would answer differently from the same cell in the middle of a wider
	# board, and two overlapping boards would stop agreeing.
	var apron_across := across + 2
	var apron_deep := deep + 2
	var apron_lowest := lowest - Vector2i.ONE
	var height := PackedFloat64Array()
	var storey := PackedInt32Array()
	var over := PackedInt32Array()
	var built := PackedInt32Array()
	height.resize(apron_across * apron_deep)
	storey.resize(apron_across * apron_deep)
	over.resize(apron_across * apron_deep)
	built.resize(apron_across * apron_deep)

	for row in apron_deep:
		for column in apron_across:
			var cell := apron_lowest + Vector2i(column, row)
			var at := row * apron_across + column
			var centre := CombatBoard.centre_of(cell, size)
			var reference := _reference_at(centre.x, centre.y, storey_island)
			var surface := terrain.support_at(centre.x, centre.y, reference)
			var on := _storey_of(centre.x, centre.y, surface)
			height[at] = surface
			storey[at] = on
			over[at] = terrain.islands_at(centre.x, centre.y).size()
			# A building stands on the ground, so it only occupies a cell that
			# resolved to the ground. A board on an island passing over a village
			# far below is not standing in its houses.
			built[at] = 1 if (
				on == CombatBoard.GROUND_STOREY
				and terrain.is_reserved_at(centre.x, centre.y)
			) else 0

	for row in deep:
		for column in across:
			var cell := lowest + Vector2i(column, row)
			var at := (row + 1) * apron_across + (column + 1)
			var surface: float = height[at]
			var is_hole := surface == -INF
			var occupied := built[at] == 1
			var standable := not is_hole and not occupied

			# What the four neighbours do to this cell: the deepest fall away
			# from it, and the lowest ground beside it. A hole beside a cell is
			# an unbounded fall -- there is no floor to land on within reach --
			# and it is not ground, so it does not lower the face.
			var deepest_fall := 0.0
			var lowest_beside := INF
			for step in CombatBoard.NEIGHBOURS:
				var beside := at + step.y * apron_across + step.x
				var neighbour: float = height[beside]
				if neighbour == -INF:
					deepest_fall = INF
					continue
				lowest_beside = minf(lowest_beside, neighbour)
				if not is_hole:
					deepest_fall = maxf(deepest_fall, surface - neighbour)

			var flags := 0
			if standable:
				flags |= CombatBoard.STANDABLE
			if is_hole:
				flags |= CombatBoard.HOLE
			if is_hole or occupied:
				flags |= CombatBoard.BLOCKS_MOVE
			# A face of ground taller than a piece can climb stops a line the
			# same way a wall does: the earth is in the way. A hole does not --
			# you can shoot over a chasm, and the design says a chasm is a
			# highway to the Frog rather than a wall.
			if occupied or (
				not is_hole
				and lowest_beside != INF
				and surface - lowest_beside > CombatBoard.STEP_UP
			):
				flags |= CombatBoard.BLOCKS_LINE
			if standable and deepest_fall > CombatBoard.CLIFF_DROP:
				flags |= CombatBoard.CLIFF_EDGE

			board.put(
				cell, flags, surface, storey[at], over[at],
				0.0 if is_hole else deepest_fall,
			)
	return board


## The board around a position, read on whatever is on top there: an island if
## one covers the position, the ground if not.
##
## What anything arriving from outside wants, and what a test or a report that
## has a position and no height uses. It is the same resolution SimWorld uses to
## put an observer down.
func build_on_top(
	x: float,
	z: float,
	span: float = DEFAULT_SPAN,
	size: float = CombatBoard.CELL_SIZE,
) -> CombatBoard:
	return build(x, z, terrain.surface_height_at(x, z), span, size)


## The board around a position read on the ground, whatever floats over it.
func build_on_ground(
	x: float,
	z: float,
	span: float = DEFAULT_SPAN,
	size: float = CombatBoard.CELL_SIZE,
) -> CombatBoard:
	return build(x, z, terrain.ground_height_at(x, z), span, size)


## The height the anchored storey has under a position: the ground's own, or the
## island's top.
##
## Outside the island's outline its top function returns the rim height, which is
## what makes this a reference that carries on past the edge instead of falling
## off it -- and therefore what lets the cells beyond the rim answer "a step down
## to the ground" or "a fall" rather than having no question asked of them at
## all.
func _reference_at(x: float, z: float, storey_island: FloatingIsland) -> float:
	if storey_island == null:
		return terrain.ground_height_at(x, z)
	return storey_island.top_height_at(x, z)


## Which storey a surface height at a position is: 0 the ground, 1 and up the
## walkable islands over it lowest first.
##
## The heights compared are the very ones `surfaces_at` collected, so this is
## matching a number against itself rather than recomputing it a second way.
func _storey_of(x: float, z: float, surface: float) -> int:
	if surface == -INF:
		return CombatBoard.NO_STOREY
	if absf(surface - terrain.ground_height_at(x, z)) < SAME_SURFACE:
		return CombatBoard.GROUND_STOREY
	var storey := 0
	for island in terrain.islands_at(x, z):
		storey += 1
		if absf(island.top_height_at(x, z) - surface) < SAME_SURFACE:
			return storey
	return CombatBoard.NO_STOREY


## The island whose top is the storey at a height here, or null for the ground.
func _island_of_storey(x: float, z: float, from_height: float) -> FloatingIsland:
	for island in terrain.islands_at(x, z):
		if absf(island.top_height_at(x, z) - from_height) < SAME_SURFACE:
			return island
	return null
