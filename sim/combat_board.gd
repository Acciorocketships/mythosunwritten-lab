extends RefCounted
## One rectangle of the world read as a board: plain numbers, no engine objects.
##
## This is the only spatial discretisation the simulation has. Combat snaps onto
## it, and the language-model layer's local view of a character's surroundings
## will later be a window onto the same lattice rather than a second structure
## built beside it.
##
## ## The lattice
##
## Cells are a fixed square of world units across, and their centres are fixed to
## the world origin -- cell (i, j) is centred at ((i + 0.5) * size, (j + 0.5) *
## size) and nowhere else, whoever asked for it and whatever else is loaded. Two
## boards built over overlapping ground therefore share their cells exactly, in
## the same way and for the same reason two overlapping windows of the water
## sheet share their corners. Nothing here is measured from the board's own
## corner or from the position it was asked about.
##
## The lattice is deliberately not the terrain-generation lattice. That one is
## 2 world units and exists to give the ground its facets; this one is coarser
## and exists to make a fork either cover two pieces or not. Its size does not
## divide the chunk size either, so a board's cells straddle chunk borders and
## neither grid can start standing in for the other. The size and the reasoning
## are in reports/combat-board.md.
##
## ## What a cell carries
##
## Every cell answers six things, and each is a fact about that cell alone:
##
##   * **standable** -- a piece may stand here.
##   * **height** -- the surface it would stand on, in world units.
##   * **hole** -- there is nothing to stand on at all: open water, the void off
##     a floating island's rim, or the pond in an island's own basin. Most
##     pieces cannot enter one, the Frog leaps them, and a piece on the lip of
##     one can be shoved in.
##   * **blocks movement** -- no piece may occupy it: a hole, or a building's
##     footprint.
##   * **blocks a line** -- neither a piece nor a line of sight passes through
##     it: a building, or a face of ground standing more than a piece can climb
##     above the lowest ground beside it. A hole does not block a line; you can
##     shoot across a chasm.
##   * **cliff edge** -- the ground falls away from it to a neighbour by more
##     than a step, so a piece standing here can be shoved off it.
##
## and two more that say where it is in the world's vertical stack:
##
##   * **storey** -- 0 for the ground, 1 for the first walkable floating island
##     over this position, 2 for the second. A hole belongs to no storey.
##   * **islands over** -- how many walkable islands lap over this position in
##     plan, whichever storey the cell itself resolved to.
##
## Movement between cells is not a per-cell fact, because a cliff stops movement
## in one direction and not the other: a piece walks off a ledge it cannot climb
## back up. That is `can_step()`, and it is stated in the terrain query's own
## walking constants rather than in numbers of its own.
class_name CombatBoard

## World units along one side of a cell. Coarser than the terrain-generation
## lattice's 2.0, and not a divisor of the 16.0 chunk, so the two grids cannot
## quietly become one. Chosen by measurement; see reports/combat-board.md.
const CELL_SIZE := 3.0

## How far up a piece may step onto a neighbouring cell, in world units, and how
## far down.
##
## Neither is a number of this layer's own. They are the terrain query's walking
## constants, so what a piece may step up is the same fact as what a walker may
## step up: an island's rim is placed within TerrainQuery.HOP_HEIGHT of what it
## overhangs precisely so that walking into it carries you up, and the board
## inherits that rather than restating it.
const STEP_UP := TerrainQuery.HOP_HEIGHT
const STEP_DOWN := TerrainQuery.DROP_REACH

## How far the ground must fall away to a neighbour for a cell to be a cliff
## edge, in world units.
##
## The same constant again, and for the same reason it exists there: a surface
## further down than TerrainQuery.DROP_REACH is a fall rather than a step. A cell
## you can be shoved off is exactly a cell whose neighbour is a fall.
const CLIFF_DROP := TerrainQuery.DROP_REACH

## The storey of the ground itself. Islands are 1 and up, lowest first.
const GROUND_STOREY := 0

## The storey of a hole: none.
const NO_STOREY := -1

# What a cell's flag word can carry.
const STANDABLE := 1
const HOLE := 2
const BLOCKS_MOVE := 4
const BLOCKS_LINE := 8
const CLIFF_EDGE := 16

## The four ways a piece walks off a cell. Diagonals are a piece's business --
## the Cat moves on them and the Toadstool captures on them -- but what the
## ground does is measured cardinally, because a diagonal step crosses a corner
## rather than an edge.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

## The seed the world this was read off descends from.
var world_seed: int = 0

## World units along one side of a cell, as this board was built.
var cell_size: float = CELL_SIZE

## The lattice coordinate of the board's lowest corner cell, and how many cells
## it spans each way. Lattice coordinates are world-fixed, so these locate the
## board in the world rather than describing a window of their own.
var min_cell := Vector2i.ZERO
var cells_across: int = 0
var cells_deep: int = 0

## The cell the board was asked about, the height it was asked from, and the
## storey that resolved to. Every cell of the board is read on that storey.
var anchor_cell := Vector2i.ZERO
var anchor_height: float = 0.0
var anchor_storey: int = GROUND_STOREY

# One entry per cell, row-major with z as the row. Holes carry -INF for their
# height and NO_STOREY for their storey; a cell with no neighbour to fall to
# carries a drop of 0.0 and one beside a hole carries INF.
var _flags := PackedInt32Array()
var _height := PackedFloat64Array()
var _storey := PackedInt32Array()
var _islands_over := PackedInt32Array()
var _drop := PackedFloat64Array()


## Which cell of the world-fixed lattice a world position falls in.
##
## Floor division, not truncation: without it every cell either side of the world
## origin would be twice as wide as the rest, and two boards on opposite sides of
## it would disagree about where the cells are.
static func cell_of(x: float, z: float, size: float = CELL_SIZE) -> Vector2i:
	return Vector2i(int(floorf(x / size)), int(floorf(z / size)))


## Where a cell's centre is in the world. The one place a cell turns back into a
## position, so that everything sampling the board samples the same points.
static func centre_of(cell: Vector2i, size: float = CELL_SIZE) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * size, (float(cell.y) + 0.5) * size)


## Set up the storage for a rectangle of the lattice. Called by the builder;
## everything after it is read-only from outside.
func shape(lowest: Vector2i, across: int, deep: int, size: float) -> void:
	min_cell = lowest
	cells_across = across
	cells_deep = deep
	cell_size = size
	var count := across * deep
	_flags.resize(count)
	_height.resize(count)
	_storey.resize(count)
	_islands_over.resize(count)
	_drop.resize(count)


## Write one cell. The builder's only way in.
func put(
	cell: Vector2i,
	flags: int,
	height: float,
	storey: int,
	islands_over: int,
	drop: float,
) -> void:
	var at := index_of(cell)
	if at < 0:
		return
	_flags[at] = flags
	_height[at] = height
	_storey[at] = storey
	_islands_over[at] = islands_over
	_drop[at] = drop


## Whether a lattice coordinate is inside this board's rectangle.
func contains(cell: Vector2i) -> bool:
	var local := cell - min_cell
	return local.x >= 0 and local.y >= 0 \
		and local.x < cells_across and local.y < cells_deep


## Where a cell's data sits, or -1 for a cell this board does not cover.
func index_of(cell: Vector2i) -> int:
	if not contains(cell):
		return -1
	var local := cell - min_cell
	return local.y * cells_across + local.x


## How many cells this board holds.
func cell_count() -> int:
	return cells_across * cells_deep


## Where a cell's centre is in the world, on this board's lattice.
func centre(cell: Vector2i) -> Vector2:
	return centre_of(cell, cell_size)


## The stretch of world this board covers, as (min_x, min_z, max_x, max_z) --
## the outer edges of its corner cells, not their centres.
func extent() -> Array:
	var high := min_cell + Vector2i(cells_across, cells_deep)
	return [
		float(min_cell.x) * cell_size, float(min_cell.y) * cell_size,
		float(high.x) * cell_size, float(high.y) * cell_size,
	]


func flags_at(cell: Vector2i) -> int:
	var at := index_of(cell)
	return 0 if at < 0 else _flags[at]


## Whether a piece may stand here: there is a surface within reach and nothing
## is built on it.
func is_standable(cell: Vector2i) -> bool:
	return (flags_at(cell) & STANDABLE) != 0


## Whether there is nothing to stand on here at all. Water, the void off an
## island's rim, and the pond in an island's basin all answer yes, through the
## terrain query's own `is_void_at` and nothing this layer adds.
func is_hole(cell: Vector2i) -> bool:
	return (flags_at(cell) & HOLE) != 0


## Whether no piece may occupy this cell.
func blocks_move(cell: Vector2i) -> bool:
	return (flags_at(cell) & BLOCKS_MOVE) != 0


## Whether a line through this cell is stopped by what stands in it.
func blocks_line(cell: Vector2i) -> bool:
	return (flags_at(cell) & BLOCKS_LINE) != 0


## Whether the ground falls away from this cell by more than a step, so a piece
## standing on it can be shoved off.
func is_cliff_edge(cell: Vector2i) -> bool:
	return (flags_at(cell) & CLIFF_EDGE) != 0


## The surface a piece here would stand on, or -INF over a hole.
func height_at(cell: Vector2i) -> float:
	var at := index_of(cell)
	return -INF if at < 0 else _height[at]


## Which storey this cell belongs to: 0 the ground, 1 and up the walkable
## islands over it lowest first, NO_STOREY for a hole.
func storey_at(cell: Vector2i) -> int:
	var at := index_of(cell)
	return NO_STOREY if at < 0 else _storey[at]


## How many walkable floating islands lap over this cell in plan, whichever
## storey the cell itself resolved to. Zero almost everywhere.
func islands_over(cell: Vector2i) -> int:
	var at := index_of(cell)
	return 0 if at < 0 else _islands_over[at]


## The deepest fall from this cell to one of its four neighbours, in world
## units: 0 where the ground does not fall away, INF beside a hole. What a shove
## is resolved against.
func drop_at(cell: Vector2i) -> float:
	var at := index_of(cell)
	return 0.0 if at < 0 else _drop[at]


## Whether ordinary walking carries a piece from one cell to a neighbouring one.
##
## Asymmetric on purpose, and that asymmetry is the whole of what a cliff is on
## this board: STEP_UP is how far a walker climbs and STEP_DOWN is how far one
## drops, and the second is the smaller, so a ledge you walked off is a ledge you
## cannot walk back up. Both come from the terrain query, so a piece and a walker
## cannot come to disagree about what a step is.
func can_step(from: Vector2i, to: Vector2i) -> bool:
	if not is_standable(from) or not is_standable(to):
		return false
	var rise := height_at(to) - height_at(from)
	return rise <= STEP_UP and -rise <= STEP_DOWN


## How many cells a piece may stand on.
func standable_count() -> int:
	return _count_with(STANDABLE)


## How many cells are holes.
func hole_count() -> int:
	return _count_with(HOLE)


## How many cells stop a line.
func blocking_count() -> int:
	return _count_with(BLOCKS_LINE)


## How many cells a piece could be shoved off.
func cliff_edge_count() -> int:
	return _count_with(CLIFF_EDGE)


## How many cells sit on a storey above the ground.
func aerial_count() -> int:
	var found := 0
	for at in _storey.size():
		if _storey[at] > GROUND_STOREY:
			found += 1
	return found


func _count_with(flag: int) -> int:
	var found := 0
	for at in _flags.size():
		if (_flags[at] & flag) != 0:
			found += 1
	return found


## A detached copy: same numbers, no shared storage.
##
## How a board reaches anything outside the simulation, for the same reason chunk
## geometry and the water sheet are copied -- this engine's packed arrays share
## their storage when assigned, so handing one over would hand over write access
## to the original.
func detached_copy() -> CombatBoard:
	var copy := CombatBoard.new()
	copy.world_seed = world_seed
	copy.cell_size = cell_size
	copy.min_cell = min_cell
	copy.cells_across = cells_across
	copy.cells_deep = cells_deep
	copy.anchor_cell = anchor_cell
	copy.anchor_height = anchor_height
	copy.anchor_storey = anchor_storey
	copy._flags = _flags.duplicate()
	copy._height = _height.duplicate()
	copy._storey = _storey.duplicate()
	copy._islands_over = _islands_over.duplicate()
	copy._drop = _drop.duplicate()
	return copy


## One line describing a single cell, in the form the reports and the tests
## compare. Heights are rendered at fixed precision, and a hole says so in words
## rather than printing an infinity whose spelling is the engine's business.
func cell_line(cell: Vector2i) -> String:
	return "%d %d %s %s %d %d %s %s %s %s %s" % [
		cell.x, cell.y,
		number_text(height_at(cell)), number_text(drop_at(cell)),
		storey_at(cell), islands_over(cell),
		"stand" if is_standable(cell) else "-----",
		"hole" if is_hole(cell) else "----",
		"move" if blocks_move(cell) else "----",
		"line" if blocks_line(cell) else "----",
		"cliff" if is_cliff_edge(cell) else "-----",
	]


## A short, stable fingerprint of the whole board.
##
## Recomputed on every call rather than kept from build time, for the reason
## every other fingerprint in the project is: one cached at build time would
## answer for the board as it was built rather than for the board as it is.
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("seed=%d" % world_seed)
	parts.append("cell=%.4f" % cell_size)
	parts.append("at=%d,%d+%dx%d" % [
		min_cell.x, min_cell.y, cells_across, cells_deep,
	])
	parts.append("anchor=%d,%d/%s/%d" % [
		anchor_cell.x, anchor_cell.y, number_text(anchor_height), anchor_storey,
	])
	for row in cells_deep:
		for column in cells_across:
			var cell := min_cell + Vector2i(column, row)
			parts.append(cell_line(cell))
	return "|".join(parts).sha256_text().substr(0, 16)


## A height or a drop as text: fixed precision, and words for the two infinities
## so that a fingerprint does not depend on how the engine spells them.
static func number_text(value: float) -> String:
	if value == INF:
		return "far"
	if value == -INF:
		return "none"
	return "%.4f" % value
