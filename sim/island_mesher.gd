extends RefCounted
## Turns one floating island into geometry.
##
## The ground is meshed in square chunks because it is a field with no edges: it
## goes on forever and any square of it is as good a piece as any other. An
## island is the opposite -- a thing with a middle and a rim -- so it is meshed
## radially, in rings out from its centre, and the outermost ring lands exactly
## on the outline the island itself defines. That is what gives it a real cliff:
## the edge is a curve the island knows, not a contour anyone had to hunt for.
##
## What comes out is the same TerrainChunkGeometry the ground is made of, so an
## island streams, is fingerprinted, is handed out as a detached copy and is
## drawn through exactly the same machinery the ground already has. Its chunk
## coordinate is the island's lattice cell.
##
## Three surfaces are built, in one piece:
##
## * the **top**, from the island's own little heightfield -- the ground you walk
##   on, and the only part the terrain query knows about;
## * the **cliff** at the rim, a short vertical band in the biome's rock colour;
## * the **keel** underneath, tapering to a point, which is what makes the island
##   read as torn out of the world rather than sliced off it.
##
## It carries no memory between islands: meshing one reads nothing but that
## island, so the geometry is the same whether it was the first built or the
## thousandth, and an island that is dropped and later returned to comes back
## byte-identical.
class_name IslandMesher

## How many directions round the island each ring is divided into.
##
## Enough that the outline reads as a torn edge rather than as a polygon. It
## takes more than it used to: the outline is now the union of several blobs, so
## it has corners where two of them cross, and a coarse fan rounds a corner off
## into exactly the smooth curve the shape exists to avoid. Far-sky islands get
## more again, because they are several times wider.
##
## The count is set by the fastest thing the outline does, and that is the fine
## crenellation FloatingIsland.EDGE_FREQUENCIES runs at: nine cycles round the
## island. A fan of 24 samples a nine-cycle wave under three times a cycle, which
## is below the rate at which a wave can be sampled at all -- so at 24 the
## crenellation was in every answer the island gave about itself and in none of
## the geometry anybody saw. Raising the wobble at 24 sectors changed the picture
## by nothing, which is written up with the frame in reports/islands.md; it took
## effect the moment the fan could carry it. Forty samples a nine-cycle wave four
## and a half times and a five-cycle wave eight times, and the risers of the
## stepped rim come out as terraces rather than as a smooth skirt.
const AERIAL_SECTORS := 40
const FAR_SECTORS := 44

## Where the rings sit, as a share of the way out to the rim.
##
## Bunched towards the outside, because that is where the surface does the most:
## the outer 42% of an island is the stepped rim, three shelves with a short
## riser at the inner edge of each. A ring is needed at the top and the bottom of
## every riser, or the mesh ramps smoothly through a step that the terrain query
## says is a step -- the island someone walks on and the island they see would be
## different shapes. The four inner ratios carry the dome above the top shelf.
##
## FloatingIsland.terrace_at is where these numbers come from: with SHELF_BAND
## 0.42, SHELF_COUNT 3 and SHELF_RISER 0.34, each shelf is 0.14 of the way in
## wide and its riser is the inner 0.0476 of that, so the risers run from 0.9076
## to 0.86, from 0.7676 to 0.72 and from 0.6276 to 0.58, where the dome takes
## over. The outermost tread -- ratio 1.00 down to 0.9076 -- is the flat lip at
## rim height that the landing needs.
const RING_RATIOS := [
	0.0, 0.20, 0.38, 0.58,
	0.6276, 0.72, 0.7676, 0.86, 0.9076, 1.0,
]

## Where the extra rings go inside a basin, as shares of the way out to the
## bowl's lip.
##
## An island that holds a pond needs rings through the bowl for the same reason
## it needs them at the risers: the terrain query is exact, and a mesh that
## ramped straight across a hollow would draw a hill where a walker finds a
## lake. The bowl is a share of the way out to the outline, so its rings are a
## share of *that* and land correctly whatever size the basin is. Only a basin
## island pays for them.
const BASIN_RING_SHARES := [0.14, 0.28, 0.42, 0.56, 0.70, 0.84, 0.94]

## How many extra directions are cut across a spillway, on top of the two that
## land exactly on its edges.
##
## The channel is a wedge of directions rather than a corridor of some width in
## world units, which is what lets it land on mesh edges at all: put a sector
## boundary on each edge of the wedge and the notch the walker falls into is
## the notch the viewer sees, with no sector straddling the lip.
const SPILL_SECTORS := 3

## How opaque the pond gets, and the depth it takes to get there. The world's
## own water sheet's numbers, so a pond on an island and a pond on the ground
## fade out at their shores at the same rate.
const POND_OPAQUE_DEPTH := 1.2
const POND_MAX_OPACITY := 0.9

## How close two rings, or two directions, may be before the second is dropped.
## The extra ones a basin and a spillway add are arithmetic on the island's own
## numbers and can land on top of a fixed one; a ring with no width between it
## and its neighbour is triangles with no area.
const RING_APART := 0.004
const ANGLE_APART := 0.01

## How much darker the keel is than the cliff at the rim, at its lowest point.
## The underside of a floating thing is the one surface no light reaches, and a
## keel in flat rock colour reads as a mistake.
const KEEL_SHADING := 0.45

## How much darker the top surface gets towards the rim, so the edge of the
## island reads as an edge from above as well as from the side.
const RIM_SHADING := 0.12


## Build the geometry for one island.
func build(island: FloatingIsland) -> TerrainChunkGeometry:
	var geometry := TerrainChunkGeometry.new(island.cell.x, island.cell.y)
	var ratios := ring_ratios(island)
	var angles := sector_angles(island)
	var sectors := angles.size()

	var lowest := INF
	var highest := -INF

	# Every ring's corners, computed once and shared by the surfaces that meet
	# there. Ring 0 is the single point at the middle, so it holds one corner.
	var top_rings: Array = []
	var bottom_rings: Array = []
	for ratio in ratios:
		var top_ring := PackedVector3Array()
		var bottom_ring := PackedVector3Array()
		var directions := 1 if ratio <= 0.0 else sectors
		for direction in directions:
			var angle: float = angles[direction] if ratio > 0.0 else 0.0
			var reach: float = island.outline_radius(angle) * float(ratio)
			var x := island.centre_x + cos(angle) * reach
			var z := island.centre_z + sin(angle) * reach
			var top := island.top_height_at(x, z)
			var bottom := island.bottom_height_at(x, z)
			top_ring.append(Vector3(x, top, z))
			bottom_ring.append(Vector3(x, bottom, z))
			lowest = minf(lowest, bottom)
			highest = maxf(highest, top)
		top_rings.append(top_ring)
		bottom_rings.append(bottom_ring)

	_build_fan(geometry, island, ratios, top_rings, sectors, true)
	_build_cliff(geometry, island, top_rings, bottom_rings, sectors)
	_build_fan(geometry, island, ratios, bottom_rings, sectors, false)

	geometry.lowest = lowest
	geometry.highest = highest
	return geometry


## The island's own pond, as its own surface.
##
## A sheet of exactly the kind the world's water is made of, and drawn by the
## viewer through the same shader -- but it is *not* part of that sheet. The
## world's water lies on one lattice fixed to the world origin and is rebuilt
## around whoever is walking; an island's pond belongs to the island, hangs in
## the air with it, and is built once when the island is streamed in. Sharing a
## lattice with the world's water would mean the pond moved when the observer
## did, which is the one thing a body of water sitting on a plate must not do.
##
## Empty for an island with no basin, which is most of them.
##
## The corners are the same radial lattice the island's own surface is built on,
## so the pond's shore lands on the mesh edges of the ground under it and the
## two cannot disagree about where the water stops.
func build_water(island: FloatingIsland) -> WaterSheet:
	var sheet := WaterSheet.new()
	if not island.has_basin():
		return sheet
	var reach := island.max_reach()
	sheet.min_x = island.centre_x - reach
	sheet.max_x = island.centre_x + reach
	sheet.min_z = island.centre_z - reach
	sheet.max_z = island.centre_z + reach

	var ratios := ring_ratios(island)
	var angles := sector_angles(island)
	var sectors := angles.size()

	# Every corner once, and everything about it once: where it is, the height
	# the pond stands at there, and the colour that depth of water takes. Asked
	# once here rather than again per triangle, because a corner belongs to up to
	# six of them and each of these questions runs the outline solver.
	var rings: Array = []
	var tint_rings: Array = []
	var wet_rings: Array = []
	for ratio in ratios:
		var ring := PackedVector3Array()
		var tints := PackedColorArray()
		var wet := []
		var directions := 1 if ratio <= 0.0 else sectors
		for direction in directions:
			var angle: float = angles[direction] if ratio > 0.0 else 0.0
			var away: float = island.outline_radius(angle) * float(ratio)
			var x := island.centre_x + cos(angle) * away
			var z := island.centre_z + sin(angle) * away
			var top := island.top_height_at(x, z)
			var surface := island.pond_surface_at(x, z)
			var here_wet := surface != -INF
			sheet.cells_considered += 1
			if here_wet:
				sheet.wet_cells += 1
			else:
				# Dry corners are pinned to the ground so the sheet closes on
				# the shore instead of ending in mid-air, exactly as the world's
				# sheet meets its own bank.
				surface = top
			var tint := island.water_tint
			tint.a = POND_MAX_OPACITY * smoothstep(
				0.0, POND_OPAQUE_DEPTH, maxf(0.0, surface - top)
			)
			ring.append(Vector3(x, surface, z))
			tints.append(tint)
			wet.append(here_wet)
		rings.append(ring)
		tint_rings.append(tints)
		wet_rings.append(wet)

	for ring in range(1, ratios.size()):
		var inner: PackedVector3Array = rings[ring - 1]
		var outer: PackedVector3Array = rings[ring]
		var inner_tint: PackedColorArray = tint_rings[ring - 1]
		var outer_tint: PackedColorArray = tint_rings[ring]
		var inner_wet: Array = wet_rings[ring - 1]
		var outer_wet: Array = wet_rings[ring]
		for direction in sectors:
			var next := (direction + 1) % sectors
			if ring == 1:
				if not (inner_wet[0] or outer_wet[direction] or outer_wet[next]):
					continue
				_add_water_triangle(sheet,
					[inner[0], outer[direction], outer[next]],
					[inner_tint[0], outer_tint[direction], outer_tint[next]])
				continue
			if not (inner_wet[direction] or inner_wet[next]
					or outer_wet[direction] or outer_wet[next]):
				continue
			_add_water_triangle(sheet,
				[inner[direction], outer[direction], inner[next]],
				[inner_tint[direction], outer_tint[direction], inner_tint[next]])
			_add_water_triangle(sheet,
				[outer[direction], outer[next], inner[next]],
				[outer_tint[direction], outer_tint[next], inner_tint[next]])
	return sheet


## Where the rings of one island's fan sit, as shares of the way out to its rim.
##
## The fixed set for an island with no basin; the fixed set plus a run of rings
## through the bowl for one that has. Sorted, so the fan walks outwards.
func ring_ratios(island: FloatingIsland) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	for ratio in RING_RATIOS:
		found.append(float(ratio))
	if island.has_basin():
		for share in BASIN_RING_SHARES:
			found.append(island.basin_ratio * float(share))
		# One just outside the lip as well, so the shore of the pond is a mesh
		# edge rather than something halfway along a triangle.
		found.append(minf(island.basin_ratio * 1.06, 1.0))
	found.sort()
	return _spaced(found, RING_APART)


## Which directions one island's fan is divided into.
##
## The uniform fan, plus -- for an island whose pond overflows -- extra
## directions on and inside the edges of the spillway. That is what makes the
## channel meshable at all: the wedge lands exactly on sector boundaries, so no
## triangle straddles its lip and the notch someone walks down is the notch that
## was drawn.
func sector_angles(island: FloatingIsland) -> PackedFloat32Array:
	var sectors := FAR_SECTORS if island.band == FloatingIsland.FAR_SKY else AERIAL_SECTORS
	var found := PackedFloat32Array()
	for direction in sectors:
		found.append(TAU * float(direction) / float(sectors))
	if island.has_spill():
		for step in SPILL_SECTORS + 2:
			var across := -1.0 + 2.0 * float(step) / float(SPILL_SECTORS + 1)
			found.append(fposmod(
				island.spill_angle + across * island.spill_half_angle, TAU
			))
	found.sort()
	return _spaced(found, ANGLE_APART)


## The same list with anything closer together than `apart` dropped, keeping the
## first of each cluster.
##
## Two rings or two directions at almost the same place would leave a band of
## triangles with no area in it. Nothing downstream would break -- a degenerate
## triangle draws nothing -- but it would be geometry the streamer paid for and
## the fingerprint carried, and the extra rings and directions are added by
## arithmetic that can land on top of a fixed one.
static func _spaced(values: PackedFloat32Array, apart: float) -> PackedFloat32Array:
	var kept := PackedFloat32Array()
	for value in values:
		if kept.is_empty() or value - kept[kept.size() - 1] > apart:
			kept.append(value)
	return kept


## One side of the island -- the top surface or the keel -- as rings of quads
## with a fan at the middle.
func _build_fan(
	geometry: TerrainChunkGeometry,
	island: FloatingIsland,
	ratios: PackedFloat32Array,
	rings: Array,
	sectors: int,
	upward: bool,
) -> void:
	var facing := Vector3.UP if upward else Vector3.DOWN
	var middle: PackedVector3Array = rings[0]
	for ring in range(1, ratios.size()):
		var inner: PackedVector3Array = rings[ring - 1]
		var outer: PackedVector3Array = rings[ring]
		var inner_ratio: float = ratios[ring - 1]
		var outer_ratio: float = ratios[ring]
		for direction in sectors:
			var next := (direction + 1) % sectors
			var outer_here := outer[direction]
			var outer_next := outer[next]
			if ring == 1:
				_add_triangle(geometry, middle[0], outer_here, outer_next, [
					_surface_tint(island, 0.0, upward),
					_surface_tint(island, outer_ratio, upward),
					_surface_tint(island, outer_ratio, upward),
				], facing)
				continue
			var inner_here := inner[direction]
			var inner_next := inner[next]
			var inner_tint := _surface_tint(island, inner_ratio, upward)
			var outer_tint := _surface_tint(island, outer_ratio, upward)
			_add_triangle(geometry, inner_here, outer_here, inner_next,
				[inner_tint, outer_tint, inner_tint], facing)
			_add_triangle(geometry, outer_here, outer_next, inner_next,
				[outer_tint, outer_tint, inner_tint], facing)


## The cliff at the rim: the band between the top surface's edge and the
## underside's lip, facing outwards all the way round.
func _build_cliff(
	geometry: TerrainChunkGeometry,
	island: FloatingIsland,
	top_rings: Array,
	bottom_rings: Array,
	sectors: int,
) -> void:
	var top: PackedVector3Array = top_rings[top_rings.size() - 1]
	var bottom: PackedVector3Array = bottom_rings[bottom_rings.size() - 1]
	var tint := island.rock_tint
	for direction in sectors:
		var next := (direction + 1) % sectors
		var here_top := top[direction]
		var next_top := top[next]
		var here_bottom := bottom[direction]
		var next_bottom := bottom[next]
		# Outwards from the island's middle, along the ground plane: the side of
		# the cliff a viewer standing off the island sees.
		var outward := Vector3(
			(here_top.x + next_top.x) * 0.5 - island.centre_x,
			0.0,
			(here_top.z + next_top.z) * 0.5 - island.centre_z,
		).normalized()
		if outward == Vector3.ZERO:
			outward = Vector3.RIGHT
		_add_triangle(geometry, here_top, next_top, here_bottom,
			[tint, tint, tint], outward)
		_add_triangle(geometry, next_top, next_bottom, here_bottom,
			[tint, tint, tint], outward)


## The colour of one surface at one distance out from the middle: the biome's
## ground colour on top, darkening towards the rim, and its rock colour below,
## darkening towards the keel.
func _surface_tint(island: FloatingIsland, ratio: float, upward: bool) -> Color:
	if upward:
		return island.ground_tint.darkened(RIM_SHADING * ratio)
	return island.rock_tint.darkened(KEEL_SHADING * (1.0 - ratio))


## One flat-shaded triangle, wound so that the side facing `facing` is its front.
##
## Vertices are not shared between triangles, exactly as in the ground's mesher
## and for the same reason: it is what makes every triangle's normal its own and
## gives the faceted low-poly look. The winding is checked rather than assumed,
## because a radial mesh runs in both directions round the island and a fixed
## order would leave half of every surface inside out.
func _add_triangle(
	geometry: TerrainChunkGeometry,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	tints: Array,
	facing: Vector3,
) -> void:
	var corners := [a, b, c]
	var order := [0, 1, 2]
	var raw := (b - a).cross(c - a)
	if raw.dot(facing) > 0.0:
		order = [0, 2, 1]
		raw = -raw
	var normal := -raw.normalized()
	if normal == Vector3.ZERO:
		normal = facing
	var first_index := geometry.vertices.size()
	for at in order:
		geometry.vertices.append(corners[at])
		geometry.normals.append(normal)
		geometry.colors.append(tints[at])
	geometry.indices.append(first_index)
	geometry.indices.append(first_index + 1)
	geometry.indices.append(first_index + 2)


## One triangle of an island's pond, in the water colour of the island's own
## biome with the depth already ramped into each corner's alpha -- the world
## sheet's rule, applied to a body of water that happens to be forty units in
## the air, so a shore fades out rather than ending on a line.
func _add_water_triangle(
	sheet: WaterSheet, corners: Array, tints: Array
) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var normal := (b - a).cross(c - a).normalized()
	if normal == Vector3.ZERO:
		normal = Vector3.UP
	elif normal.y < 0.0:
		normal = -normal
	var first_index := sheet.vertices.size()
	for at in 3:
		sheet.vertices.append(corners[at])
		sheet.normals.append(normal)
		sheet.colors.append(tints[at])
	sheet.indices.append(first_index)
	sheet.indices.append(first_index + 1)
	sheet.indices.append(first_index + 2)
