extends RefCounted
## The ground beyond the streamed chunks, drawn at a coarser cell the further
## out it goes.
##
## The simulation streams the ground it has to *be* the ground: a disc of about
## forty units' radius around whoever is standing there, meshed at two-unit cells,
## because that is the ground a character walks on, collides with and fights on.
## The camera sees nine hundred. Everything between those two numbers used to be
## sky. This layer fills it, out to at least 1024 units, with the same ground --
## the same height function, sampled at a cell that doubles every level, so the
## count of things drawn grows with the *logarithm* of the radius instead of
## with its square.
##
## It lives in the render shell, and that is the whole of what makes level of
## detail a drawing choice rather than a generation rule. The world's height at a
## position is one function, `TerrainQuery.ground_height_at`, and it is the only
## thing this file asks. Nothing here is invented: every vertex is that function
## read at a lattice point. Nothing here is remembered by the world: the
## simulation has never heard of a level, so collision, the terrain query, the
## combat lattice and the world's own fingerprint are exactly what they were
## before this file existed -- and a headless process, which loads no file of
## this directory, meshes none of it at all.
##
## The write-up, with the radius derived from the playing camera and the cost
## measured, is reports/terrain-lod.md.
##
## How the levels fit together
## ---------------------------
## Level `l` tiles are `32 * 2^(l-1)` units square and always carry an 8x8 grid
## of cells, so the cell doubles with the level: 4, 8, 16, 32, 64 units. Every
## tile is a square of the *world* lattice, never of the observer, so its
## geometry is a pure function of (level, tile) and can be cached and re-shown
## unchanged however the observer moves -- which is what stops the distance from
## shimmering.
##
## Each level draws a square block of its own tiles centred on the tile the
## observer is standing in, minus whatever the finer levels already cover. The
## subtraction is exact rather than approximate, and that is why there is no
## overlap to z-fight and no gap to see through:
##
##   * A level-1 tile is exactly 2x2 simulation chunks, and a chunk is exactly
##     4x4 level-1 cells. So level 1 omits precisely the cells lying in chunks
##     the simulation has loaded -- whatever shape that set happens to be. The
##     coarse ground begins exactly where the streamed ground stops.
##   * A level-`l` block is a square whose edges fall on multiples of the
##     level-(l-1) tile, which is four level-`l` cells. So level `l` omits
##     precisely the cells inside the level-(l-1) block.
##
## What is left over at a boundary is a *crack*: two levels agree at the corners
## they share and disagree in between, because the coarse edge is a straight line
## across ground the fine edge follows. Every emitted cell that has no emitted
## neighbour therefore drops a skirt -- a vertical apron in the ground's own
## colour -- so a boundary can never be seen through. See SKIRT_FLOOR.
class_name DistantGround

## Cells along one side of a tile, at every level. Same as the simulation's
## mesher, so a tile is 128 triangles whatever it covers.
const CELLS := 8

## How many coarse levels there are. Five reaches at least 1024 units, which is
## where ground straight ahead crosses the camera's 900-unit far plane; see
## reports/terrain-lod.md for that arithmetic.
const LEVELS := 5

## World units along one side of a level-1 tile: two simulation chunks.
const BASE_TILE := TerrainChunkMesher.CHUNK_SIZE * 2.0

## How many tiles out from the observer's own each level draws, as a Chebyshev
## radius, so a level covers a (2r+1) square of its tiles.
##
## Level 1 reaches further than the rest because its block has to contain every
## chunk the simulation could have loaded -- the streamer drops at 56 units, so
## a loaded chunk can reach 72 units along an axis, and three level-1 tiles
## reach at least 96. If it did not contain them, a level-2 tile could land on
## top of a chunk that is already being drawn.
const NEAR_RING := 3
const FAR_RING := 2

## Levels up to this one take the ground as the whole stack composes it, with
## the villages' levelled pads and the roads' worn dips in it. Past it the shape
## is the water-carved land alone -- the same fields, one layer short.
##
## This is the one place the distant ground is a simplification rather than a
## copy, and it is here for a measured reason. Reading the settlement and road
## layers costs 600-2500 microseconds a corner where corners are tens of units
## apart, against 25 for the land itself, because both are cached per cell and a
## coarse lattice misses every cache. What that buys is a difference of at most
## 1.576 units, at 4.3% of positions, measured over a 4000-unit sweep by
## tests/test_terrain_lod.gd -- and it is bought only past 384 units, where 1.576
## units of ground subtends a quarter of a degree.
##
## It changes nothing the world says. `TerrainQuery.ground_height_at` is the
## world's height at a position and no level touches it: collision, the terrain
## query and the combat lattice get the full answer everywhere, and this is a
## coarse mesh drawing a simplified surface, which is exactly what a coarse mesh
## is for.
const SHAPE_DETAIL_LEVEL := 3

## Levels up to this one take the full ground tint -- the biome blend with the
## roads worn into it and the village pads trodden over it. Past it the tint is
## the biome blend alone. Water takes the biome's water colour at every level,
## for a separate reason given at the sample.
##
## This is a colour decision and only a colour decision: the height is
## `ground_height_at` at every level, so a road's worn dip and a village's
## levelled pad are in the *shape* of the distant ground either way. What is
## dropped past level 2 is the brown of a track that is by then under two
## hundred units away and thinner than the cell it would be drawn in -- and
## reading it costs about four times what the rest of the corner costs.
const TINT_DETAIL_LEVEL := 2

## How deep a skirt hangs below the edge it is dropped from, in world units:
## this much at least, and this fraction of the cell above that.
##
## It has to exceed the worst disagreement between a coarse edge and the finer
## ground beside it, which grows with the cell because a longer straight line
## departs further from the surface it is cutting across.
## tests/test_terrain_lod.gd measures that disagreement over a wide sweep and
## fails if it ever comes within a third of the skirt.
const SKIRT_FLOOR := 3.0
const SKIRT_PER_CELL := 0.8

## How many corner samples are kept before the cache is thrown away and refilled.
## Walking re-uses almost every corner, so this only bounds a very long walk.
const CACHE_LIMIT := 240000

## The one thing this layer asks the world.
var terrain: TerrainQuery = null

## Diagnostics. Nothing in the picture depends on them; they are what the cost
## measurement and the tests read.
var tiles_built: int = 0
var corners_sampled: int = 0
var corners_cached: int = 0

# Vector3i(level, corner_x_index, corner_z_index) -> height / tint.
var _height := {}
var _tint := {}

# Vector3i(level, tile_x, tile_z) -> the signature of the cells it emits.
var _wanted := {}
# The same keys, nearest level first, so the ring fills in from the inside.
var _order: Array[Vector3i] = []

# Level -> the block of the level below it, as a Rect2 in world units. Level 1
# has none; its hole is the loaded chunk set instead.
var _hole := {}
# Chunk coordinate (Vector2i) -> true, as the simulation last reported it.
var _loaded := {}


func _init(query: TerrainQuery = null) -> void:
	terrain = query


## World units along one side of a tile at this level.
static func tile_size(level: int) -> float:
	return BASE_TILE * float(1 << (level - 1))


## World units along one side of a cell at this level.
static func cell_size(level: int) -> float:
	return tile_size(level) / float(CELLS)


## How many tiles out from its own this level draws.
static func ring_of(level: int) -> int:
	return NEAR_RING if level == 1 else FAR_RING


## The block of tiles a level draws, as a rectangle in world units.
static func block_of(level: int, x: float, z: float) -> Rect2:
	var side := tile_size(level)
	var reach := ring_of(level)
	var origin_x := float(floori(x / side) - reach) * side
	var origin_z := float(floori(z / side) - reach) * side
	var span := float(2 * reach + 1) * side
	return Rect2(origin_x, origin_z, span, span)


## The radius the coarse ground is guaranteed to reach from the observer, in
## every direction. The outermost block is (2r+1) tiles across and the observer
## stands somewhere in the middle tile, so the nearest edge is r tiles away.
static func guaranteed_radius() -> float:
	return tile_size(LEVELS) * float(ring_of(LEVELS))


## Work out which tiles should be on screen, given where the observer is and
## which chunks the simulation has meshed for itself.
##
## `loaded_chunks` is a set of Vector2i chunk coordinates -- the streamer's own
## loaded keys. Cells inside those chunks are left out of level 1, because the
## simulation is already drawing them at full resolution.
func update(x: float, z: float, loaded_chunks: Dictionary) -> void:
	_loaded = loaded_chunks
	_wanted.clear()
	_order.clear()
	_hole.clear()
	for level in range(1, LEVELS + 1):
		if level > 1:
			_hole[level] = block_of(level - 1, x, z)
		var side := tile_size(level)
		var reach := ring_of(level)
		var centre_x := floori(x / side)
		var centre_z := floori(z / side)
		for offset_x in range(-reach, reach + 1):
			for offset_z in range(-reach, reach + 1):
				var key := Vector3i(level, centre_x + offset_x, centre_z + offset_z)
				var signature := signature_of(key)
				if signature == "":
					continue
				_wanted[key] = signature
				_order.append(key)


## The tiles that should be on screen, as key -> signature. A signature changes
## exactly when the cells the tile emits change, which is the only reason a tile
## ever has to be rebuilt.
func wanted() -> Dictionary:
	return _wanted


## The same keys, coarsest last, so a caller filling in over several frames
## finishes the near ground first.
func wanted_keys() -> Array[Vector3i]:
	return _order


## How a tile's emitted cells are described, or "" when the tile is entirely
## covered by finer levels and should not be drawn at all.
func signature_of(key: Vector3i) -> String:
	var level := key.x
	if level == 1:
		# A level-1 tile is 2x2 chunks. Four bits say which of them the
		# simulation is drawing itself.
		var mask := ""
		var covered := 0
		for chunk_z in 2:
			for chunk_x in 2:
				var loaded := _loaded.has(Vector2i(key.y * 2 + chunk_x, key.z * 2 + chunk_z))
				covered += 1 if loaded else 0
				mask += "1" if loaded else "0"
		return "" if covered == 4 else "c" + mask
	# Every coarser level is cut against the block below it, whose edges always
	# fall on this level's cell boundaries.
	var hole: Rect2 = _hole[level]
	var side := tile_size(level)
	var cell := cell_size(level)
	var origin_x := float(key.y) * side
	var origin_z := float(key.z) * side
	# The hole as a half-open range of cell indices inside this tile.
	var first_x := clampi(ceili((hole.position.x - origin_x) / cell), 0, CELLS)
	var first_z := clampi(ceili((hole.position.y - origin_z) / cell), 0, CELLS)
	var last_x := clampi(floori((hole.end.x - origin_x) / cell), 0, CELLS)
	var last_z := clampi(floori((hole.end.y - origin_z) / cell), 0, CELLS)
	if first_x >= last_x or first_z >= last_z:
		return "h0"
	if first_x == 0 and first_z == 0 and last_x == CELLS and last_z == CELLS:
		return ""
	return "h%d,%d,%d,%d" % [first_x, first_z, last_x, last_z]


## Whether one cell of a tile is drawn by this level, or left to a finer one.
func emits(key: Vector3i, column: int, row: int) -> bool:
	if key.x == 1:
		return not _loaded.has(Vector2i(
			key.y * 2 + (column * 2) / CELLS, key.z * 2 + (row * 2) / CELLS
		))
	var hole: Rect2 = _hole[key.x]
	var side := tile_size(key.x)
	var cell := cell_size(key.x)
	var centre_x := float(key.y) * side + (float(column) + 0.5) * cell
	var centre_z := float(key.z) * side + (float(row) + 0.5) * cell
	return not hole.has_point(Vector2(centre_x, centre_z))


## Build one tile's geometry: the same plain arrays of numbers a chunk of the
## simulation's own ground arrives as, so it becomes a drawable through exactly
## the same code.
func build(key: Vector3i) -> TerrainChunkGeometry:
	var level := key.x
	var side := tile_size(level)
	var cell := cell_size(level)
	var origin_x := float(key.y) * side
	var origin_z := float(key.z) * side
	var geometry := TerrainChunkGeometry.new(key.y, key.z)

	var corners: Array[Vector3] = []
	var tints: Array[Color] = []
	var lowest := INF
	var highest := -INF
	for row in CELLS + 1:
		for column in CELLS + 1:
			var index_x := key.y * CELLS + column
			var index_z := key.z * CELLS + row
			var sample := _corner(level, index_x, index_z, origin_x + float(column) * cell,
				origin_z + float(row) * cell)
			var y: float = sample[0]
			lowest = minf(lowest, y)
			highest = maxf(highest, y)
			corners.append(Vector3(origin_x + float(column) * cell, y, origin_z + float(row) * cell))
			tints.append(sample[1])

	var emitted := []
	emitted.resize(CELLS * CELLS)
	for row in CELLS:
		for column in CELLS:
			emitted[row * CELLS + column] = emits(key, column, row)

	for row in CELLS:
		for column in CELLS:
			if not emitted[row * CELLS + column]:
				continue
			var top_left := row * (CELLS + 1) + column
			var top_right := top_left + 1
			var bottom_left := (row + 1) * (CELLS + 1) + column
			var bottom_right := bottom_left + 1
			# The same winding the simulation's mesher uses, so the side facing
			# the sky is the front side here too.
			_add_triangle(geometry, corners, tints, top_left, top_right, bottom_left)
			_add_triangle(geometry, corners, tints, top_right, bottom_right, bottom_left)

	_add_skirts(geometry, key, corners, tints, emitted, cell)

	geometry.lowest = lowest
	geometry.highest = highest
	tiles_built += 1
	return geometry


## How deep a skirt hangs at this level.
static func skirt_depth(level: int) -> float:
	return maxf(SKIRT_FLOOR, SKIRT_PER_CELL * cell_size(level))


## How many corner samples are being held.
func cached_corners() -> int:
	return _height.size()


func _corner(level: int, index_x: int, index_z: int, x: float, z: float) -> Array:
	var key := Vector3i(level, index_x, index_z)
	if _height.has(key):
		corners_cached += 1
		return [_height[key], _tint[key]]
	if _height.size() > CACHE_LIMIT:
		_height.clear()
		_tint.clear()
	# One call for both the ground and whether water stands on it: the column is
	# the world's own composition of the stack, and asking for it twice would
	# pay for the whole stack twice.
	var column: Vector2
	if level <= SHAPE_DETAIL_LEVEL:
		column = terrain.water_column_at(x, z)
	else:
		column = terrain.water_field.sample_column(x, z)
	var tint: Color
	if column.y > column.x:
		# Water, at every coarse level. The world's one sheet of water only
		# reaches 56 units, so past that there is nothing drawing a lake but the
		# ground under it -- and a lake drawn in the colour of grass reads as a
		# hole in the picture. The colour is the water field's own, sampled the
		# same way everything else here is; the vertex stays at the bed, under
		# where the sheet would be, so the two never fight for a pixel in the
		# stretch where both are drawn.
		tint = terrain.biome_field.water_tint_at(x, z)
	elif level <= TINT_DETAIL_LEVEL:
		tint = terrain.ground_tint_at(x, z)
	else:
		tint = terrain.biome_field.ground_tint_at(x, z)
	_height[key] = column.x
	_tint[key] = tint
	corners_sampled += 1
	return [column.x, tint]


func _add_triangle(
	geometry: TerrainChunkGeometry,
	corners: Array[Vector3],
	tints: Array[Color],
	a: int, b: int, c: int,
) -> void:
	var normal := (corners[b] - corners[a]).cross(corners[c] - corners[a]).normalized()
	if normal.y < 0.0:
		normal = -normal
	var first := geometry.vertices.size()
	for at in [a, b, c]:
		geometry.vertices.append(corners[at])
		geometry.normals.append(normal)
		geometry.colors.append(tints[at])
		geometry.indices.append(first)
		first += 1


## Drop an apron from every emitted edge that has nothing beside it.
##
## Two levels meeting share their corner samples exactly -- both read the same
## height function at the same world position -- and disagree only in between,
## where the coarse side draws a straight line across ground the fine side
## follows. That disagreement is a crack you can see the sky through. The apron
## fills it: a vertical strip in the ground's own colour, hanging deeper than
## the worst disagreement can be.
##
## An edge gets one only where it needs one. Cells inside a tile that face a
## cell left to a finer level always get one. Cells on a tile's rim get one only
## when the tile next door is not being drawn at all -- when it is, the two tiles
## are the same level and meet exactly.
func _add_skirts(
	geometry: TerrainChunkGeometry,
	key: Vector3i,
	corners: Array[Vector3],
	tints: Array[Color],
	emitted: Array,
	cell: float,
) -> void:
	var depth := skirt_depth(key.x)
	var steps := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for row in CELLS:
		for column in CELLS:
			if not emitted[row * CELLS + column]:
				continue
			for step in steps:
				var next_column: int = column + step.x
				var next_row: int = row + step.y
				var inside := next_column >= 0 and next_column < CELLS \
					and next_row >= 0 and next_row < CELLS
				if inside:
					if emitted[next_row * CELLS + next_column]:
						continue
				elif _wanted.has(Vector3i(
					key.x,
					key.y + (1 if next_column >= CELLS else (-1 if next_column < 0 else 0)),
					key.z + (1 if next_row >= CELLS else (-1 if next_row < 0 else 0)),
				)):
					continue
				# The two corners of the edge that faces the missing neighbour.
				var edge_column := column + (1 if step.x > 0 else 0)
				var edge_row := row + (1 if step.y > 0 else 0)
				var first: int
				var second: int
				if step.x != 0:
					first = edge_row * (CELLS + 1) + edge_column
					second = (edge_row + 1) * (CELLS + 1) + edge_column
				else:
					first = edge_row * (CELLS + 1) + edge_column
					second = edge_row * (CELLS + 1) + edge_column + 1
				_add_apron(
					geometry, corners[first], corners[second],
					tints[first], tints[second], depth,
					Vector3(float(step.x), 0.0, float(step.y)),
				)


func _add_apron(
	geometry: TerrainChunkGeometry,
	top_a: Vector3, top_b: Vector3,
	tint_a: Color, tint_b: Color,
	depth: float, outward: Vector3,
) -> void:
	var low_a := top_a - Vector3(0.0, depth, 0.0)
	var low_b := top_b - Vector3(0.0, depth, 0.0)
	_add_apron_face(geometry, top_a, low_a, low_b, tint_a, tint_a, tint_b, outward)
	_add_apron_face(geometry, top_a, low_b, top_b, tint_a, tint_b, tint_b, outward)


func _add_apron_face(
	geometry: TerrainChunkGeometry,
	a: Vector3, b: Vector3, c: Vector3,
	tint_a: Color, tint_b: Color, tint_c: Color,
	outward: Vector3,
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var points := [a, b, c]
	var colours := [tint_a, tint_b, tint_c]
	if normal.dot(outward) < 0.0:
		normal = -normal
		points = [a, c, b]
		colours = [tint_a, tint_c, tint_b]
	var first := geometry.vertices.size()
	for at in 3:
		geometry.vertices.append(points[at])
		geometry.normals.append(normal)
		geometry.colors.append(colours[at])
		geometry.indices.append(first + at)
