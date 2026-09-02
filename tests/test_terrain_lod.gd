extends TestSuite
## The ground drawn past the streamed chunks: that it covers the view exactly,
## that it is the same ground the world reports, and that it costs a logarithm
## rather than a square.
##
## The layer under test is render/distant_ground.gd. It is a render-layer file,
## deliberately, and these are the checks that say so from the outside: the
## world's fingerprint is the same with it and without it, and a headless
## process never loads it at all.


const SEED := 1234
const FIXED_FPS := 30
const FRAMES := 90


func _init() -> void:
	suite_name = "terrain_lod"


func run() -> void:
	_the_cell_coarsens_with_distance()
	_the_coarse_ground_covers_the_view_exactly()
	_level_one_contains_every_chunk_the_streamer_could_load()
	_the_radius_grows_without_the_count_growing_quadratically()
	_every_vertex_is_the_worlds_own_height()
	_the_world_reports_one_height_whichever_level_drew_it()
	_the_simplified_shape_stays_inside_its_stated_envelope()
	_two_tiles_of_a_level_meet_on_the_same_numbers()
	_a_tile_is_a_pure_function_of_its_key()
	_the_skirt_is_deeper_than_the_worst_seam()
	_a_tile_away_from_a_boundary_is_not_rebuilt_by_walking()
	_the_ground_never_opens_up_while_it_is_walked_across()
	_headless_meshes_no_distant_ground_at_all()
	_the_world_is_byte_identical_with_and_without_the_distant_ground()


## Which cell a position is drawn at grows with how far away it is, and the
## sizes are the doubling the layer says they are.
func _the_cell_coarsens_with_distance() -> void:
	var previous := TerrainChunkMesher.CELL_SIZE
	for level in range(1, DistantGround.LEVELS + 1):
		var cell := DistantGround.cell_size(level)
		equal(cell, previous * 2.0,
			"level %d should mesh at twice the cell of the level inside it" % level)
		previous = cell
	equal(DistantGround.cell_size(DistantGround.LEVELS), 64.0,
		"the coarsest level should mesh at 64-unit cells")
	equal(DistantGround.guaranteed_radius(), 1024.0,
		"the coarse ground should reach at least 1024 units in every direction")


## Every point out to the guaranteed radius is drawn once: by a chunk the
## simulation meshed, or by exactly one cell of exactly one coarse level.
##
## This is the check that there is neither a hole to see the sky through nor two
## surfaces fighting for the same pixels. It is asked of positions on a lattice
## that shares no divisor with any tile or cell size, so the answers are not all
## taken at boundaries.
func _the_coarse_ground_covers_the_view_exactly() -> void:
	for start in [Vector2(0.0, 0.0), Vector2(311.7, -204.3), Vector2(-1502.5, 883.1)]:
		var world := SimWorld.new(SEED)
		world.place_observer(start.x, start.y)
		var loaded := {}
		for key in world.terrain_streamer.loaded_keys():
			loaded[key] = true
		var lod := DistantGround.new(world.terrain)
		lod.update(world.observer_x, world.observer_z, loaded)

		var radius := DistantGround.guaranteed_radius()
		var misses := 0
		var doubles := 0
		var checked := 0
		var step := 7.3
		var along := -radius + 1.1
		while along <= radius:
			var across := -radius + 2.7
			while across <= radius:
				if Vector2(along, across).length() <= radius:
					checked += 1
					var cover := _covers(lod, loaded,
						world.observer_x + along, world.observer_z + across)
					if cover == 0:
						misses += 1
					elif cover > 1:
						doubles += 1
				across += step
			along += step
		check(checked > 50000,
			"only %d positions were sampled around %s" % [checked, start])
		equal(misses, 0,
			"%d of %d positions around %s are drawn by nothing: the view has a "
			% [misses, checked, start] + "hole in it")
		equal(doubles, 0,
			"%d of %d positions around %s are drawn twice: two surfaces are "
			% [doubles, checked, start] + "fighting for the same pixels")


## How many surfaces are drawn over one position.
func _covers(lod: DistantGround, loaded: Dictionary, x: float, z: float) -> int:
	var cover := 0
	if loaded.has(TerrainChunkMesher.chunk_at(x, z)):
		cover += 1
	for level in range(1, DistantGround.LEVELS + 1):
		var side := DistantGround.tile_size(level)
		var cell := DistantGround.cell_size(level)
		var tile_x := floori(x / side)
		var tile_z := floori(z / side)
		var key := Vector3i(level, tile_x, tile_z)
		if not lod.wanted().has(key):
			continue
		if lod.emits(key,
				floori((x - float(tile_x) * side) / cell),
				floori((z - float(tile_z) * side) / cell)):
			cover += 1
	return cover


## The innermost coarse level's block has to contain every chunk the simulation
## could have loaded, or a level-2 tile could land on top of ground that is
## already being drawn at full resolution.
##
## Checked against the streamer's own rule rather than against one run of it:
## the unload radius is what bounds how far a loaded chunk can be.
func _level_one_contains_every_chunk_the_streamer_could_load() -> void:
	var reach := TerrainStreamer.UNLOAD_RADIUS + TerrainChunkMesher.CHUNK_SIZE
	var worst := INF
	for at in [Vector2(0.0, 0.0), Vector2(15.9, 31.9), Vector2(-7.3, 48.1), Vector2(602.4, -318.6)]:
		var block := DistantGround.block_of(1, at.x, at.y)
		worst = minf(worst, minf(
			minf(at.x - block.position.x, block.end.x - at.x),
			minf(at.y - block.position.y, block.end.y - at.y)))
	check(worst > reach,
		"the level-1 block only reaches %.1f units from the observer, and a "
		% worst + "loaded chunk can reach %.1f: a coarse tile could be drawn "
		% reach + "over ground the simulation is already drawing")


## The radius grows a great deal and the count of drawn pieces does not follow
## it squared.
##
## The comparison that matters is against the alternative: meshing the same
## radius at the streamer's own two-unit cell. That is what "without the chunk
## count growing quadratically" means, and it is a number rather than a claim.
func _the_radius_grows_without_the_count_growing_quadratically() -> void:
	var world := SimWorld.new(SEED)
	var loaded := {}
	for key in world.terrain_streamer.loaded_keys():
		loaded[key] = true
	var lod := DistantGround.new(world.terrain)
	lod.update(world.observer_x, world.observer_z, loaded)

	var radius := DistantGround.guaranteed_radius()
	var uniform := int(PI * radius * radius / (TerrainChunkMesher.CHUNK_SIZE * TerrainChunkMesher.CHUNK_SIZE))
	var drawn := loaded.size() + lod.wanted().size()
	check(drawn < uniform / 20,
		"the layer draws %d pieces where a uniform mesh of the same %d-unit "
		% [drawn, int(radius)] + "radius would need %d: that is not a saving "
		% uniform + "worth the machinery")
	check(lod.wanted().size() < 200,
		"the coarse layer wants %d tiles, which is more than the ring scheme "
		% lod.wanted().size() + "should ever produce")
	# And the count really is logarithmic: each level beyond the first draws
	# about the same number of tiles however far out it is.
	var per_level := {}
	for key in lod.wanted_keys():
		per_level[key.x] = int(per_level.get(key.x, 0)) + 1
	for level in range(2, DistantGround.LEVELS + 1):
		check(int(per_level.get(level, 0)) <= 25,
			"level %d wants %d tiles; a ring of %d tiles is all it should ever "
			% [level, int(per_level.get(level, 0)), 25] + "be")


## Every corner of every coarse tile is the world's own height at that position.
##
## Nothing here is invented and nothing is smoothed: the near levels are
## `TerrainQuery.ground_height_at` exactly, and the far ones are that same stack
## one layer short, which is checked separately against its stated envelope.
func _every_vertex_is_the_worlds_own_height() -> void:
	var world := SimWorld.new(SEED)
	var loaded := {}
	for key in world.terrain_streamer.loaded_keys():
		loaded[key] = true
	var lod := DistantGround.new(world.terrain)
	lod.update(world.observer_x, world.observer_z, loaded)

	var compared := 0
	var wrong := 0
	for key in lod.wanted_keys():
		if key.x > DistantGround.SHAPE_DETAIL_LEVEL:
			continue
		var geometry := lod.build(key)
		var depth := DistantGround.skirt_depth(key.x)
		for vertex in geometry.vertices:
			var height := world.terrain.ground_height_at(vertex.x, vertex.z)
			# Skirt vertices hang exactly one depth below the edge they drop
			# from; everything else is on the surface.
			if absf(vertex.y - height) < 0.0005:
				compared += 1
				continue
			if absf(vertex.y - (height - depth)) < 0.0005:
				compared += 1
				continue
			wrong += 1
	check(compared > 20000,
		"only %d vertices were compared against the world's height" % compared)
	equal(wrong, 0,
		"%d vertices of the coarse ground are not the world's own height at "
		% wrong + "their position: the distance is being invented rather than "
		+ "sampled")


## The world reports one height at a position whichever level happens to be
## drawing it.
##
## The sweep deliberately straddles the boundaries: every level's block edge is
## walked, and positions a hair either side of it are asked twice -- once with
## the observer placed so the position falls in the finer level, once so it
## falls in the coarser one.
func _the_world_reports_one_height_whichever_level_drew_it() -> void:
	var world := SimWorld.new(SEED)
	var terrain := world.terrain
	var lod := DistantGround.new(terrain)

	var probes: Array[Vector2] = []
	# A wide sweep, and then the boundaries themselves.
	for i in 240:
		probes.append(Vector2(
			float((i * 137) % 1900) - 950.0, float((i * 291) % 1900) - 950.0))
	for level in range(1, DistantGround.LEVELS + 1):
		var block := DistantGround.block_of(level, 0.0, 0.0)
		for offset in [-0.01, 0.0, 0.01]:
			probes.append(Vector2(block.position.x + offset, 40.5))
			probes.append(Vector2(block.end.x + offset, -71.5))
			probes.append(Vector2(19.5, block.position.y + offset))
			probes.append(Vector2(-63.5, block.end.y + offset))

	var first := {}
	var levels_seen := {}
	var disagreed := 0
	var moved := 0
	for observer in [Vector2(0.0, 0.0), Vector2(412.0, -333.0), Vector2(-870.0, 640.0)]:
		var loaded := {}
		world.place_observer(observer.x, observer.y)
		for key in world.terrain_streamer.loaded_keys():
			loaded[key] = true
		lod.update(observer.x, observer.y, loaded)
		for probe in probes:
			var height := terrain.ground_height_at(probe.x, probe.y)
			if first.has(probe):
				if absf(float(first[probe]) - height) > 0.0:
					disagreed += 1
			else:
				first[probe] = height
			var level := _level_drawing(lod, loaded, probe.x, probe.y)
			if levels_seen.has(probe):
				if int(levels_seen[probe]) != level:
					moved += 1
			else:
				levels_seen[probe] = level
	equal(disagreed, 0,
		"%d positions gave a different ground height once a different level "
		% disagreed + "was drawing them: level of detail has leaked into the "
		+ "world's own answer")
	check(moved > 100,
		"only %d of the probed positions ever changed level, so the comparison "
		% moved + "above is not comparing two levels at all")


## Which level is drawing a position: 0 for the simulation's own chunks, -1 for
## nothing at all.
func _level_drawing(lod: DistantGround, loaded: Dictionary, x: float, z: float) -> int:
	if loaded.has(TerrainChunkMesher.chunk_at(x, z)):
		return 0
	for level in range(1, DistantGround.LEVELS + 1):
		var side := DistantGround.tile_size(level)
		var cell := DistantGround.cell_size(level)
		var tile_x := floori(x / side)
		var tile_z := floori(z / side)
		var key := Vector3i(level, tile_x, tile_z)
		if not lod.wanted().has(key):
			continue
		if lod.emits(key,
				floori((x - float(tile_x) * side) / cell),
				floori((z - float(tile_z) * side) / cell)):
			return level
	return -1


## The one simplification the far levels make, held to the number the file
## states: the villages' pads and the roads' wear, left out past level 3.
func _the_simplified_shape_stays_inside_its_stated_envelope() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var worst := 0.0
	var differed := 0
	var total := 0
	for i in 900:
		var x := float((i * 977) % 4000) - 2000.0
		var z := float((i * 1861) % 4000) - 2000.0
		var full := terrain.ground_height_at(x, z)
		var carved := terrain.water_field.sample_column(x, z).x
		total += 1
		if absf(full - carved) > 0.0005:
			differed += 1
		worst = maxf(worst, absf(full - carved))
	check(differed > 0,
		"the two surfaces never differed over %d positions, so this check is "
		% total + "not measuring anything")
	check(worst < 2.0,
		"the far levels' simplified shape departs from the world's own ground "
		+ "by %.3f units, past the 2.0 the layer claims" % worst)
	# And it is only ever used far enough out for that to be nothing on screen.
	check(DistantGround.tile_size(DistantGround.SHAPE_DETAIL_LEVEL)
			* float(DistantGround.ring_of(DistantGround.SHAPE_DETAIL_LEVEL)) >= 256.0,
		"the simplification starts closer than 256 units from the observer")


## Two tiles of the same level that touch agree on the numbers along their
## shared edge, exactly -- so there is nothing between them to crack.
func _two_tiles_of_a_level_meet_on_the_same_numbers() -> void:
	var world := SimWorld.new(SEED)
	var loaded := {}
	for key in world.terrain_streamer.loaded_keys():
		loaded[key] = true
	var lod := DistantGround.new(world.terrain)
	lod.update(world.observer_x, world.observer_z, loaded)

	var pairs := 0
	var gaps := 0
	for key in lod.wanted_keys():
		var beside := Vector3i(key.x, key.y + 1, key.z)
		if not lod.wanted().has(beside):
			continue
		if lod.signature_of(key) != "h0" or lod.signature_of(beside) != "h0":
			continue
		var side := DistantGround.tile_size(key.x)
		var cell := DistantGround.cell_size(key.x)
		var shared_x := float(beside.y) * side
		var left := lod.build(key)
		var right := lod.build(beside)
		for step in DistantGround.CELLS + 1:
			var z := float(key.z) * side + float(step) * cell
			var here: Variant = _height_in(left, shared_x, z)
			var there: Variant = _height_in(right, shared_x, z)
			pairs += 1
			if here == null or there == null or absf(float(here) - float(there)) > 0.0:
				gaps += 1
	check(pairs > 100, "only %d shared corners were compared" % pairs)
	equal(gaps, 0,
		"%d shared corners of neighbouring tiles disagree, so the two tiles do "
		% gaps + "not meet")


## The height a built tile carries at a corner position, or null.
func _height_in(geometry: TerrainChunkGeometry, x: float, z: float) -> Variant:
	for vertex in geometry.vertices:
		if absf(vertex.x - x) < 0.001 and absf(vertex.z - z) < 0.001:
			return vertex.y
	return null


## A tile is the same geometry however it was arrived at: same key, same seed,
## same numbers, whatever else has been built first and whatever else the
## observer has done.
func _a_tile_is_a_pure_function_of_its_key() -> void:
	var world := SimWorld.new(SEED)
	var loaded := {}
	for key in world.terrain_streamer.loaded_keys():
		loaded[key] = true

	var straight := DistantGround.new(world.terrain)
	straight.update(0.0, 0.0, loaded)
	var subject := Vector3i(3, straight.wanted_keys()[0].y, straight.wanted_keys()[0].z)
	# A tile of level 3 far enough out to be wanted from either standpoint.
	var candidates: Array[Vector3i] = []
	for key in straight.wanted_keys():
		if key.x == 3 and straight.signature_of(key) == "h0":
			candidates.append(key)
	check(not candidates.is_empty(), "no unholed level-3 tile to compare")
	if candidates.is_empty():
		return
	subject = candidates[0]
	var expected := straight.build(subject).digest()

	# The same tile, from a layer that has built a hundred other things first.
	var busy := DistantGround.new(world.terrain)
	busy.update(0.0, 0.0, loaded)
	var built := 0
	for key in busy.wanted_keys():
		if key == subject:
			continue
		busy.build(key)
		built += 1
		if built > 60:
			break
	equal(busy.build(subject).digest(), expected,
		"a tile came out differently once other tiles had been built first")

	# And from a fresh layer in the same process with no cache at all.
	var fresh := DistantGround.new(TerrainQuery.for_seed(SEED))
	fresh.update(0.0, 0.0, loaded)
	equal(fresh.build(subject).digest(), expected,
		"a tile came out differently from a layer built from the seed alone")


## The apron under an edge is deeper than the worst the two sides can disagree
## by, so a boundary between levels can never be seen through.
##
## The disagreement is arithmetic, not a guess: two levels share the corners
## they both sample, and the coarse side draws a straight line between them
## while the fine side follows the ground. The worst case is therefore the
## midpoint of a coarse cell edge, and this measures exactly that, over a wide
## sweep, for every boundary the scheme has.
func _the_skirt_is_deeper_than_the_worst_seam() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	for level in range(1, DistantGround.LEVELS + 1):
		var cell := DistantGround.cell_size(level)
		var coarse := level > DistantGround.SHAPE_DETAIL_LEVEL
		var worst := 0.0
		for i in 260:
			var x := float((i * 733) % 3000) - 1500.0
			var z := float((i * 1327) % 3000) - 1500.0
			# Along an edge running in z, then one running in x.
			for direction: Vector2 in [Vector2(0.0, 1.0), Vector2(1.0, 0.0)]:
				var a := Vector2(x, z)
				var b: Vector2 = a + direction * cell
				var middle: Vector2 = a + direction * (cell * 0.5)
				var chord := (_drawn_height(terrain, coarse, a)
					+ _drawn_height(terrain, coarse, b)) * 0.5
				worst = maxf(worst, absf(chord - _drawn_height(terrain, coarse, middle)))
		var depth := DistantGround.skirt_depth(level)
		check(depth > worst * 3.0,
			"level %d hangs a %.1f-unit apron under a seam that can open %.2f "
			% [level, depth, worst] + "units: too little margin to be sure a "
			+ "boundary never shows")


func _drawn_height(terrain: TerrainQuery, carved_only: bool, at: Vector2) -> float:
	if carved_only:
		return terrain.water_field.sample_column(at.x, at.y).x
	return terrain.ground_height_at(at.x, at.y)


## Walking does not churn the distance. A tile is rebuilt only when the cells it
## draws change, which is a thing that happens at a boundary and nowhere else.
func _a_tile_away_from_a_boundary_is_not_rebuilt_by_walking() -> void:
	var world := SimWorld.new(SEED)
	var lod := DistantGround.new(world.terrain)
	var previous := {}
	var steps := 0
	var changed := 0
	var kept := 0
	for tick in 60:
		world.step()
		var loaded := {}
		for key in world.terrain_streamer.loaded_keys():
			loaded[key] = true
		lod.update(world.observer_x, world.observer_z, loaded)
		var wanted := lod.wanted()
		if not previous.is_empty():
			steps += 1
			for key in wanted:
				if not previous.has(key):
					continue
				if previous[key] == wanted[key]:
					kept += 1
				else:
					changed += 1
		previous = wanted.duplicate()
	check(steps > 50, "only %d steps were compared" % steps)
	check(kept > 0 and changed * 20 < kept,
		"%d of %d surviving tiles changed shape per step of walking: the "
		% [changed, kept + changed] + "distance is being rebuilt rather than "
		+ "kept")


## And it never opens up while it is being walked across.
##
## The coverage check above is asked of one standing observer. This asks it
## again after every step of a walk long enough for every ring but the outermost
## to have moved, which is the moment a boundary sweeps over a piece of ground
## and the moment a crack would appear if there were one to appear.
func _the_ground_never_opens_up_while_it_is_walked_across() -> void:
	var world := SimWorld.new(SEED)
	var lod := DistantGround.new(world.terrain)
	var misses := 0
	var doubles := 0
	var checked := 0
	var boundaries_moved := 0
	var previous := {}
	for tick in 200:
		world.step()
		var loaded := {}
		for key in world.terrain_streamer.loaded_keys():
			loaded[key] = true
		lod.update(world.observer_x, world.observer_z, loaded)
		for level in range(1, DistantGround.LEVELS + 1):
			var block := DistantGround.block_of(level, world.observer_x, world.observer_z)
			if previous.has(level) and previous[level] != block:
				boundaries_moved += 1
			previous[level] = block
		# A ring of samples through every level, at an angle that shares no
		# divisor with any tile or cell size.
		for spoke in 24:
			var heading := float(spoke) * TAU / 24.0 + 0.37
			for reach in [17.3, 53.7, 88.1, 131.9, 217.3, 305.7, 449.1, 601.3, 811.7, 1013.9]:
				var x: float = world.observer_x + cos(heading) * reach
				var z: float = world.observer_z + sin(heading) * reach
				checked += 1
				var cover := _covers(lod, loaded, x, z)
				if cover == 0:
					misses += 1
				elif cover > 1:
					doubles += 1
	check(boundaries_moved > 8,
		"only %d boundary moves happened over the walk, so the check below "
		% boundaries_moved + "never saw a boundary sweep across anything")
	equal(misses, 0,
		"%d of %d positions opened up during the walk" % [misses, checked])
	equal(doubles, 0,
		"%d of %d positions were drawn twice during the walk" % [doubles, checked])


## A headless process meshes no distant ground, because it never loads the file
## that makes any.
##
## Asked from outside the render layer, of the engine's own resource cache, for
## the same reason the grass suite asks it that way: a counter inside the layer
## could only be read by loading the layer.
func _headless_meshes_no_distant_ground_at_all() -> void:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(SEED), "--ticks", "40", "--assets",
	], output, true)
	var text := "\n".join(output)
	equal(exit_code, 0, "headless run should exit 0 (output: %s)" % text)

	var render_scripts := _asset_line(text, "render-scripts")
	check(not render_scripts.is_empty(),
		"the headless run reported no render-scripts line: %s" % text)
	if render_scripts.is_empty():
		return
	equal(render_scripts["loaded"], 0,
		"a headless run loaded %d file(s) of the render layer, which is where "
		% render_scripts["loaded"] + "the level-of-detail scheme lives")
	check(FileAccess.file_exists("res://render/distant_ground.gd"),
		"render/distant_ground.gd is missing, so the check above covers nothing")
	check(render_scripts["found"] >= 6,
		"only %d render scripts were counted; the distant ground is not among "
		% render_scripts["found"] + "them")


## The world the shell reaches is byte-identical with the coarse ground and
## without it -- and the two runs really did draw different amounts of it, or
## the matching fingerprints would be a statement about two identical runs.
func _the_world_is_byte_identical_with_and_without_the_distant_ground() -> void:
	var far := _run_render_shell([])
	var near := _run_render_shell(["--no-distant-ground"])
	equal(far["exit_code"], 0, "render shell should exit 0 (output: %s)" % far["output"])
	equal(near["exit_code"], 0, "render shell should exit 0 (output: %s)" % near["output"])

	var far_counts := _counts_from(far["output"])
	var near_counts := _counts_from(near["output"])
	check(int(far_counts.get("far", 0)) > 50,
		"the ordinary run drew only %d coarse tiles" % int(far_counts.get("far", 0)))
	equal(int(near_counts.get("far", -1)), 0,
		"--no-distant-ground still drew %d coarse tiles" % int(near_counts.get("far", -1)))
	equal(int(near_counts.get("fartris", -1)), 0,
		"--no-distant-ground still drew %d coarse triangles"
		% int(near_counts.get("fartris", -1)))

	var bare := SimWorld.new(SEED)
	for tick in int(far_counts.get("tick", 0)):
		bare.step()

	var far_digest := _digest_from(far["output"])
	var near_digest := _digest_from(near["output"])
	check(far_digest != "", "no fingerprint on the ordinary run's stop line")
	equal(near_digest, far_digest,
		"the world came out different with the coarse ground and without it")
	equal(bare.digest(), far_digest,
		"the world the shell reached is not the world a bare simulation reaches")
	# The chunks the simulation streams are untouched: same count, same handles.
	equal(near_counts.get("views", -1), far_counts.get("views", -2),
		"the coarse ground changed how many chunks the simulation streamed")


func _run_render_shell(extra: Array) -> Dictionary:
	var output: Array[String] = []
	var args: Array = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", str(FIXED_FPS),
		"--quit-after", str(FRAMES),
		"--",
		"--seed", str(SEED),
	]
	args.append_array(extra)
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _digest_from(output: String) -> String:
	for line in output.split("\n"):
		if not line.contains("render-shell stop tick="):
			continue
		var at := line.find("digest=")
		if at == -1:
			continue
		return line.substr(at + "digest=".length()).strip_edges()
	return ""


func _counts_from(output: String) -> Dictionary:
	for line in output.split("\n"):
		if not line.contains("render-shell stop tick="):
			continue
		var counts := {}
		for field in line.strip_edges().split(" "):
			var parts := field.split("=")
			if parts.size() == 2 and parts[1].is_valid_int():
				counts[parts[0]] = parts[1].to_int()
		return counts
	return {}


func _asset_line(text: String, label: String) -> Dictionary:
	for line in text.split("\n"):
		if not line.contains("assets %s " % label):
			continue
		var found := {}
		for field in line.strip_edges().split(" "):
			var parts := field.split("=")
			if parts.size() == 2 and parts[1].is_valid_int():
				found[parts[0]] = parts[1].to_int()
		return found
	return {}
