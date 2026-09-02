extends SceneTree
## What the island layer costs, in microseconds per call.
##
## Two numbers, because they are the two the layer is asked for at very
## different rates. Building an island runs the placement rule, which samples
## the shape functions about a hundred and fifty times; a terrain query runs the
## cell scan and the outline test, and something asks for one of those per
## position. The shape functions live on the hot path of both, so a change to
## them has to be measured rather than assumed.
##
## Run it with:  ./run_bench.sh [--seed N]
##
## Nothing here is part of the world: it builds a field, times it, and prints.

const DEFAULT_SEED := 1234

## How many islands are built for the build timing, and how many positions are
## sampled for the query timing. Large enough that the numbers repeat to about a
## percent between runs.
const BUILD_CELLS := 8
const QUERY_SAMPLES := 1500


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size():
			seed_value = args[i + 1].to_int()

	print("bench seed=%d" % seed_value)
	_time_builds(seed_value)
	_time_queries(seed_value)
	_time_dressing(seed_value)
	quit(0)


## How long one island costs to build, footprint scan and all. Each cell is
## built in a *fresh* field, so the memo cannot answer any of them and every
## timed build is a real one.
func _time_builds(seed_value: int) -> void:
	var cells: Array[Vector2i] = []
	for cell_x in range(-BUILD_CELLS / 2, BUILD_CELLS / 2):
		for cell_z in range(-BUILD_CELLS / 2, BUILD_CELLS / 2):
			cells.append(Vector2i(cell_x, cell_z))

	for band in [FloatingIsland.AERIAL, FloatingIsland.AERIAL_UPPER]:
		var built := 0
		var refused := 0
		var elapsed := 0
		for cell in cells:
			var field := _new_field(seed_value)
			if band == FloatingIsland.AERIAL_UPPER:
				# The lower storey is a prerequisite, not part of what is timed.
				field.island_in_cell(FloatingIsland.AERIAL, cell)
			var started := Time.get_ticks_usec()
			var island := field.island_in_cell(band, cell)
			elapsed += Time.get_ticks_usec() - started
			if island == null:
				refused += 1
			else:
				built += 1
		print("bench build band=%d cells=%d placed=%d refused=%d usec_per_cell=%.1f" % [
			band, cells.size(), built, refused,
			float(elapsed) / float(cells.size()),
		])


## How long one terrain query costs at a position.
##
## Two of them. The island lookup is the cell scan plus the outline test plus
## the height where there is an island -- the part this layer owns. surfaces_at
## is the whole composed answer, and is dominated by the settlement and path
## layers underneath it rather than by anything here; it is printed so that the
## island layer's share of a real query can be seen to be small.
##
## Positions are spread over a square a few lattice cells across -- wide enough
## that the mixture of "island here" and "nothing here" is the mixture the world
## has, and narrow enough that the field's memo holds every island in it, so
## what is timed is the query rather than a rebuild.
func _time_queries(seed_value: int) -> void:
	var terrain := TerrainQuery.for_seed(seed_value)
	var field := terrain.island_field
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for i in QUERY_SAMPLES:
		xs.append(float((i * 37) % 401) - 200.0)
		zs.append(float((i * 91) % 401) - 200.0)

	# Warm the memo the way a walking observer does, so what is timed is the
	# query rather than the first build of every island in the world.
	for i in QUERY_SAMPLES:
		field.walkable_island_over(xs[i], zs[i])

	var over := 0
	var started := Time.get_ticks_usec()
	for i in QUERY_SAMPLES:
		if field.walkable_island_over(xs[i], zs[i]) != null:
			over += 1
	var island_usec := Time.get_ticks_usec() - started

	started = Time.get_ticks_usec()
	for i in QUERY_SAMPLES:
		terrain.surfaces_at(xs[i], zs[i])
	var surfaces_usec := Time.get_ticks_usec() - started

	print("bench query samples=%d over_island=%d usec_per_island_lookup=%.3f usec_per_surfaces_at=%.3f" % [
		QUERY_SAMPLES, over,
		float(island_usec) / float(QUERY_SAMPLES),
		float(surfaces_usec) / float(QUERY_SAMPLES),
	])


func _new_field(seed_value: int) -> IslandField:
	var surface := TerrainSurfaceField.new(seed_value)
	var biomes := BiomeField.new(seed_value)
	return IslandField.new(WaterField.new(surface, biomes), biomes)


## What dressing an island costs, and what that comes to per streamed chunk.
##
## Three numbers, because the aerial layer streams on the ground streamer's rule
## and the honest question is what a walk pays rather than what one island costs.
##
##   * per island: the cover -- every cell of the island's own two lattices --
##     and the pond surface, which most islands do not have.
##   * per chunk: the same total spread over the chunks the ground streamer keeps
##     loaded at the same time, since that is the unit the ground's own dressing
##     is measured in and the two are loaded together.
##
## Each island is dressed in a *fresh* cover, and out of a field that already
## holds the island, so what is timed is the dressing rather than the placement.
func _time_dressing(seed_value: int) -> void:
	var field := _new_field(seed_value)
	var mesher := IslandMesher.new()
	var islands: Array[FloatingIsland] = []
	for band in FloatingIsland.WALKABLE_BANDS:
		for cell_x in range(-BUILD_CELLS / 2, BUILD_CELLS / 2):
			for cell_z in range(-BUILD_CELLS / 2, BUILD_CELLS / 2):
				var island := field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island != null:
					islands.append(island)
	if islands.is_empty():
		print("bench cover islands=0")
		return

	var placed := 0
	var basins := 0
	var triangles := 0
	var cover_usec := 0
	var pond_usec := 0
	for island in islands:
		var cover := IslandCover.new(seed_value)
		var started := Time.get_ticks_usec()
		var patch := cover.build(island)
		cover_usec += Time.get_ticks_usec() - started
		placed += patch.count()

		started = Time.get_ticks_usec()
		var pond := mesher.build_water(island)
		pond_usec += Time.get_ticks_usec() - started
		triangles += pond.triangle_count()
		if island.has_basin():
			basins += 1

	var cover_each := float(cover_usec) / float(islands.size())
	var pond_each := float(pond_usec) / float(islands.size())
	var pond_per_basin := float(pond_usec) / float(maxi(1, basins))

	print(("bench cover islands=%d placed=%d per_island=%.1f basins=%d pond_tris=%d "
		+ "usec_per_island_cover=%.1f usec_per_island_pond=%.1f usec_per_basin_pond=%.1f") % [
		islands.size(), placed, float(placed) / float(islands.size()),
		basins, triangles, cover_each, pond_each, pond_per_basin,
	])

	# What a streamed walk actually pays. The aerial layer streams on the ground
	# streamer's rule, so the unit that matters is the chunk, and the honest
	# conversion is the layer's own density rather than however many islands
	# happen to be loaded at one moment: the square these islands were scanned
	# out of holds a known number of chunks, and the dressing of everything in
	# it is spread over them.
	var span := float(BUILD_CELLS) * IslandField.AERIAL_CELL
	var chunk_size := TerrainChunkMesher.CHUNK_SIZE
	var chunks := (span * span) / (chunk_size * chunk_size)
	print(("bench cover-streamed span=%.0f chunks=%.0f islands_per_chunk=%.4f "
		+ "usec_per_chunk=%.2f") % [
		span, chunks, float(islands.size()) / chunks,
		(cover_each + pond_each) * float(islands.size()) / chunks,
	])
