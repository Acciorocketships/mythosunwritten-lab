extends RefCounted
## Turns the surface field into per-chunk geometry.
##
## A chunk is a fixed square of ground. The mesher walks that square's own grid
## of cells, asks the field how high the ground is at each corner, and emits two
## triangles per cell. It carries no memory between chunks: building chunk (3,
## -1) reads nothing but the field, so the result is the same whether it is the
## first chunk built or the thousandth, and whether or not its neighbours exist.
##
## Vertices are not shared between triangles. That costs memory and buys flat
## facets -- the faceted low-poly look this world is aiming at -- and it keeps
## every triangle's normal exactly its own.
##
## Each corner also carries the ground colour of the biome blend at that
## position, sampled the same way the height is. Because the blend is
## continuous, the colour across a biome border is a gradient in the geometry
## itself, with no seam at the chunk edge and nothing for the render shell to
## decide.
##
## Everything it asks for comes through one terrain query, so the ground it
## builds is the ground every other layer will be told about -- including the
## water's carving, which reaches the geometry as a dip in the height rather
## than as anything the mesher knows about.
class_name TerrainChunkMesher

## World units along one side of a chunk.
const CHUNK_SIZE := 16.0

## Cells along one side of a chunk. Each cell is two triangles, so a chunk is
## CELLS * CELLS * 2 triangles.
const CELLS := 8

## World units along one side of a cell.
const CELL_SIZE := CHUNK_SIZE / float(CELLS)

## Everything the mesher knows about the ground: its height, its colour, and
## the water cut into it. One query rather than a field each, so that a mesher
## built for a world and a mesher built from that world's seed alone cannot
## disagree about any layer of the stack.
var terrain: TerrainQuery = null


func _init(query: TerrainQuery = null) -> void:
	terrain = query


## Build the geometry for one chunk coordinate.
func build(chunk_x: int, chunk_z: int) -> TerrainChunkGeometry:
	var geometry := TerrainChunkGeometry.new(chunk_x, chunk_z)
	var origin_x := float(chunk_x) * CHUNK_SIZE
	var origin_z := float(chunk_z) * CHUNK_SIZE

	# Corner heights first, one row of corners more than there are cells. The
	# corner positions are computed from the world origin rather than by walking
	# from a neighbour, so the shared edge of two chunks lands on exactly the
	# same numbers in both of them.
	var corners: Array[Vector3] = []
	var tints: Array[Color] = []
	var lowest := INF
	var highest := -INF
	for row in CELLS + 1:
		for column in CELLS + 1:
			var x := origin_x + float(column) * CELL_SIZE
			var z := origin_z + float(row) * CELL_SIZE
			var y := terrain.ground_height_at(x, z)
			lowest = minf(lowest, y)
			highest = maxf(highest, y)
			corners.append(Vector3(x, y, z))
			tints.append(terrain.ground_tint_at(x, z))

	for row in CELLS:
		for column in CELLS:
			var top_left_at := row * (CELLS + 1) + column
			var top_right_at := top_left_at + 1
			var bottom_left_at := (row + 1) * (CELLS + 1) + column
			var bottom_right_at := bottom_left_at + 1
			# Wound so that the side facing the sky is the front side.
			_add_triangle(
				geometry, corners, tints, top_left_at, top_right_at, bottom_left_at
			)
			_add_triangle(
				geometry, corners, tints, top_right_at, bottom_right_at, bottom_left_at
			)

	geometry.lowest = lowest
	geometry.highest = highest
	return geometry


## Which chunk a world position falls in.
static func chunk_at(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CHUNK_SIZE), floori(z / CHUNK_SIZE))


## How far a world position is from the nearest ground inside a chunk. Zero when
## the position is over the chunk itself.
static func distance_to_chunk(key: Vector2i, x: float, z: float) -> float:
	var min_x := float(key.x) * CHUNK_SIZE
	var min_z := float(key.y) * CHUNK_SIZE
	var nearest_x := clampf(x, min_x, min_x + CHUNK_SIZE)
	var nearest_z := clampf(z, min_z, min_z + CHUNK_SIZE)
	return Vector2(x - nearest_x, z - nearest_z).length()


func _add_triangle(
	geometry: TerrainChunkGeometry,
	corners: Array[Vector3],
	tints: Array[Color],
	a: int,
	b: int,
	c: int,
) -> void:
	var normal := (corners[b] - corners[a]).cross(corners[c] - corners[a]).normalized()
	if normal.y < 0.0:
		normal = -normal
	var first_index := geometry.vertices.size()
	for at in [a, b, c]:
		geometry.vertices.append(corners[at])
		geometry.normals.append(normal)
		geometry.colors.append(tints[at])
	geometry.indices.append(first_index)
	geometry.indices.append(first_index + 1)
	geometry.indices.append(first_index + 2)
