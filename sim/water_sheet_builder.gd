extends RefCounted
## Builds the one sheet of water around a viewer.
##
## The ground is built in chunks because it is everywhere and there is a lot of
## it. Water is not: most of the world is dry, and the parts that are not want
## to be one continuous surface, because a river drawn as a row of tiles shows
## its tiling -- the tiles meet at slightly different heights, their animation
## starts at a different phase in each, and the joins read as creases running
## across the water.
##
## So this builds a single sheet over a window of the world, on a lattice fixed
## to the world origin rather than to the window or to any chunk. A corner at a
## given world position always lands at the same place and the same height, so
## the window can slide without the water moving under it, and no boundary of
## anything is inside the sheet for a seam to appear on. Cells with no water in
## them are skipped entirely, which is why a sheet spanning a hundred metres of
## mostly dry country costs almost nothing to hold.
##
## The window has to end somewhere, and where it ends the water fades out rather
## than stopping on a line -- because past the far edge of the window is ground
## that may not be built yet, and a straight edge of water lying over the end of
## the world is the one thing that would look worse than water stopping short.
class_name WaterSheetBuilder

## World units across one cell of the water lattice. Coarser than the ground's
## cells, because a water surface is smooth: the shape worth resolving is the
## shoreline, and the depth fade at the edge softens that anyway.
const CELL_SIZE := 2.0

## How far from the middle of the window the sheet reaches, in world units: the
## streamer's unload radius, which is as far as built ground ever goes.
const REACH := TerrainStreamer.UNLOAD_RADIUS

## How much of that outer edge the water fades away over, in world units. It
## starts fading at the load radius -- the distance out to which there is
## certainly ground -- and is gone by the unload radius, beyond which there
## certainly is not.
const EDGE_FADE := REACH - TerrainStreamer.LOAD_RADIUS

## World units the window's middle is snapped to. The window only moves in these
## steps, so the sheet is rebuilt once every seventeen-or-so ticks of walking
## rather than every tick -- and because the lattice is fixed to the world and
## not to the window, a move does not disturb the water already drawn.
const WINDOW_STEP := 16.0

## The depth at which water reaches its full opacity, in world units. Shallower
## than this it ramps down to fully clear, which is what makes a shore a fade
## rather than a line. This is the whole of the sheet's transparency -- how it
## is then blended is the viewer's business.
const OPAQUE_DEPTH := 1.8

## The most opaque water gets. Left short of one so that the bed stays faintly
## visible through a lake, which is what stops deep water reading as tarmac.
const MAX_OPACITY := 0.9

var terrain: TerrainQuery = null


func _init(query: TerrainQuery = null) -> void:
	terrain = query


## The middle of the window that a viewer at this position gets, snapped so that
## small movements do not move the window at all.
static func window_centre_for(x: float, z: float) -> Vector2:
	return Vector2(
		roundf(x / WINDOW_STEP) * WINDOW_STEP,
		roundf(z / WINDOW_STEP) * WINDOW_STEP,
	)


## Build the sheet for a window centre.
##
## Nothing here depends on which chunks are loaded, on what has been built
## before, or on the order anything happened in: the window comes from the
## centre, the lattice from the world origin, and every corner's height and
## colour from that corner's world position and the seed. Two builds of the same
## centre are the same sheet, in any process.
func build(centre: Vector2) -> WaterSheet:
	var sheet := WaterSheet.new()

	# Lattice indices, not world units: corners sit at index * CELL_SIZE, so
	# they are the world's corners rather than the window's.
	var first_column := floori((centre.x - REACH) / CELL_SIZE)
	var last_column := ceili((centre.x + REACH) / CELL_SIZE)
	var first_row := floori((centre.y - REACH) / CELL_SIZE)
	var last_row := ceili((centre.y + REACH) / CELL_SIZE)
	var columns := last_column - first_column + 1
	var rows := last_row - first_row + 1

	sheet.min_x = float(first_column) * CELL_SIZE
	sheet.max_x = float(last_column) * CELL_SIZE
	sheet.min_z = float(first_row) * CELL_SIZE
	sheet.max_z = float(last_row) * CELL_SIZE
	sheet.cells_considered = (columns - 1) * (rows - 1)

	# Every corner of the window, sampled once. A corner is shared by up to four
	# cells and lands in up to six triangles, and sampling the water field is by
	# far the expensive part of this, so it is asked exactly once.
	var beds := PackedFloat32Array()
	var levels := PackedFloat32Array()
	beds.resize(columns * rows)
	levels.resize(columns * rows)
	var any_water := false
	for row in rows:
		var z := float(first_row + row) * CELL_SIZE
		for column in columns:
			# Asked through the query rather than off the water field, so the
			# bed the shore fade is measured against is the ground the mesher
			# actually builds -- villages levelled and roads carved -- and the
			# two cannot disagree at a shoreline a road runs along.
			var water := terrain.water_column_at(
				float(first_column + column) * CELL_SIZE, z
			)
			var at := row * columns + column
			beds[at] = water.x
			levels[at] = water.y
			if water.y > water.x:
				any_water = true
	if not any_water:
		return sheet

	# Which cells carry water, and so which corners are wanted at all. Working
	# that out first is what keeps the rest cheap: a corner's colour costs a
	# biome blend, and only the corners that end up in the geometry get one.
	var wanted := {}
	var wet_cells: Array[int] = []
	for row in rows - 1:
		for column in columns - 1:
			var top_left := row * columns + column
			var wet := false
			for at in [top_left, top_left + 1, top_left + columns, top_left + columns + 1]:
				if levels[at] > beds[at]:
					wet = true
					break
			if not wet:
				continue
			wet_cells.append(top_left)
			for at in [top_left, top_left + 1, top_left + columns, top_left + columns + 1]:
				wanted[at] = true
	sheet.wet_cells = wet_cells.size()

	var placed := {}
	var tinted := {}
	for key in wanted:
		var at := int(key)
		var x := float(first_column + at % columns) * CELL_SIZE
		var z := float(first_row + at / columns) * CELL_SIZE
		# A corner sits at the water surface, or at the bed where the water has
		# run out -- so at the shoreline the sheet lies exactly on the ground
		# rather than cutting into it or floating over it, and the shore is
		# where the two surfaces cross rather than a line anyone drew.
		placed[at] = Vector3(x, maxf(levels[at], beds[at]), z)
		tinted[at] = _tint_at(x, z, levels[at] - beds[at], centre)

	for top_left in wet_cells:
		# Wound so the side facing the sky is the front side, matching the
		# ground under it.
		_add_triangle(sheet, placed, tinted, [
			top_left, top_left + 1, top_left + columns,
		])
		_add_triangle(sheet, placed, tinted, [
			top_left + 1, top_left + columns + 1, top_left + columns,
		])

	return sheet


## The colour of one corner: the biome's water colour there, with the depth
## ramped into the alpha so a shallow edge fades out, and the distance to the
## window's own edge ramped in as well, so the sheet ends by disappearing rather
## than by stopping.
func _tint_at(x: float, z: float, depth: float, centre: Vector2) -> Color:
	var tint := terrain.water_tint_at(x, z)
	var from_centre := maxf(absf(x - centre.x), absf(z - centre.y))
	tint.a = MAX_OPACITY \
		* smoothstep(0.0, OPAQUE_DEPTH, maxf(0.0, depth)) \
		* (1.0 - smoothstep(REACH - EDGE_FADE, REACH, from_centre))
	return tint


func _add_triangle(
	sheet: WaterSheet, placed: Dictionary, tinted: Dictionary, at: Array
) -> void:
	var a: Vector3 = placed[at[0]]
	var b: Vector3 = placed[at[1]]
	var c: Vector3 = placed[at[2]]
	var normal := (b - a).cross(c - a).normalized()
	if normal == Vector3.ZERO:
		normal = Vector3.UP
	elif normal.y < 0.0:
		normal = -normal

	var first_index := sheet.vertices.size()
	for index in at:
		sheet.vertices.append(placed[index])
		sheet.normals.append(normal)
		sheet.colors.append(tinted[index])
	sheet.indices.append(first_index)
	sheet.indices.append(first_index + 1)
	sheet.indices.append(first_index + 2)
