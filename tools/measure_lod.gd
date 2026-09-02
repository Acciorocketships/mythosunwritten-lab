extends SceneTree
## What the coarse distant ground costs, level by level, and what it would cost
## to draw the same radius without it.
##
##   ./tools/measure_lod.sh              # seed 1234
##   ./tools/measure_lod.sh --seed 7
##
## Three questions.
##
## *How far does the ground reach, and how many pieces is that?* Before: the
## simulation's own disc of 16-unit chunks at a 2-unit cell. After: that disc,
## unchanged, plus five rings of coarser tiles. The third column is the one the
## whole scheme exists for -- what the same radius would cost meshed uniformly at
## the near cell, which is the quadratic the rings avoid.
##
## *What does a tile cost to build, and how much memory does it hold?* Cold, in
## a stretch of world nothing has asked about yet, because that is when a tile is
## actually built. Memory is counted off the arrays a tile carries.
##
## *How often does walking rebuild anything?* The rings only move when the
## observer crosses a tile of the level inside them, and a tile whose boundary
## has moved re-uses every corner it already sampled, so this reports both the
## rebuild rate and how much of it is re-sampling.
##
## Frame times are not here: nothing in this file draws. tools/measure_lod.sh
## runs the render shell twice for those, and they are software rasterisation.

## Bytes one vertex of chunk geometry holds: position, normal, colour, index.
const VERTEX_BYTES := 12 + 12 + 16 + 4


func _initialize() -> void:
	var seed_value := 1234
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			seed_value = args[i + 1].to_int()

	var world := SimWorld.new(seed_value)
	var loaded := {}
	for key in world.terrain_streamer.loaded_keys():
		loaded[key] = true
	print("lod-measure seed=%d observer=%.1f,%.1f" % [
		seed_value, world.observer_x, world.observer_z,
	])

	# What the simulation streams, which this layer does not touch.
	var chunk_times: Array[float] = []
	for at in 12:
		var began := Time.get_ticks_usec()
		world.chunk_mesher.build(400 + at, -700)
		chunk_times.append(float(Time.get_ticks_usec() - began) / 1000.0)
	var chunk_vertices := 0
	var chunk_triangles := 0
	for key in loaded:
		var geometry := world.terrain_streamer.live_geometry(key)
		chunk_vertices += geometry.vertices.size()
		chunk_triangles += geometry.triangle_count()
	print("lod-measure near radius=%.0f chunks=%d cell=%.1f tris=%d kib=%.1f build_ms %s" % [
		TerrainStreamer.LOAD_RADIUS, loaded.size(), TerrainChunkMesher.CELL_SIZE,
		chunk_triangles, float(chunk_vertices * VERTEX_BYTES) / 1024.0,
		_spread(chunk_times),
	])

	# And the rings, level by level, built cold.
	var lod := DistantGround.new(TerrainQuery.for_seed(seed_value))
	lod.update(world.observer_x, world.observer_z, loaded)
	var far_triangles := 0
	var far_vertices := 0
	var far_ms := 0.0
	for level in range(1, DistantGround.LEVELS + 1):
		var times: Array[float] = []
		var triangles := 0
		var vertices := 0
		for key in lod.wanted_keys():
			if key.x != level:
				continue
			var began := Time.get_ticks_usec()
			var geometry := lod.build(key)
			times.append(float(Time.get_ticks_usec() - began) / 1000.0)
			triangles += geometry.triangle_count()
			vertices += geometry.vertices.size()
		far_triangles += triangles
		far_vertices += vertices
		for at in times:
			far_ms += at
		print("lod-measure level=%d tile=%.0f cell=%.0f reach=%.0f tiles=%d tris=%d kib=%.1f build_ms %s" % [
			level, DistantGround.tile_size(level), DistantGround.cell_size(level),
			DistantGround.tile_size(level) * float(DistantGround.ring_of(level)),
			times.size(), triangles, float(vertices * VERTEX_BYTES) / 1024.0,
			_spread(times),
		])

	var radius := DistantGround.guaranteed_radius()
	var uniform_chunks := int(PI * radius * radius
		/ (TerrainChunkMesher.CHUNK_SIZE * TerrainChunkMesher.CHUNK_SIZE))
	var uniform_triangles := uniform_chunks * TerrainChunkMesher.CELLS * TerrainChunkMesher.CELLS * 2
	print("lod-measure after radius=%.0f pieces=%d tris=%d kib=%.1f fill_ms=%.0f" % [
		radius, loaded.size() + lod.wanted().size(),
		chunk_triangles + far_triangles,
		float((chunk_vertices + far_vertices) * VERTEX_BYTES) / 1024.0, far_ms,
	])
	print("lod-measure uniform radius=%.0f pieces=%d tris=%d kib=%.1f (what the same reach costs at the near cell)" % [
		radius, uniform_chunks, uniform_triangles,
		float(uniform_triangles * 3 * VERTEX_BYTES) / 1024.0,
	])

	# What walking costs. Every step, count the tiles whose emitted cells
	# changed, and how much of rebuilding them is new sampling rather than
	# re-use.
	var walked := DistantGround.new(world.terrain)
	var previous := {}
	var rebuilt := 0
	var arrived := 0
	var steps := 0
	var sampled_before := 0
	var walk_ms := 0.0
	for tick in 200:
		world.step()
		var here := {}
		for key in world.terrain_streamer.loaded_keys():
			here[key] = true
		walked.update(world.observer_x, world.observer_z, here)
		var wanted := walked.wanted()
		var began := Time.get_ticks_usec()
		for key in wanted:
			if not previous.has(key):
				arrived += 1
				walked.build(key)
			elif previous[key] != wanted[key]:
				rebuilt += 1
				walked.build(key)
		walk_ms += float(Time.get_ticks_usec() - began) / 1000.0
		if steps == 0:
			# The opening step builds the whole ring; it is the fill, not the walk.
			arrived = 0
			rebuilt = 0
			walk_ms = 0.0
			sampled_before = walked.corners_sampled
		steps += 1
		previous = wanted.duplicate()
	print("lod-measure walk steps=%d arrived=%.2f/step rebuilt=%.2f/step corners=%.1f/step ms=%.2f/step" % [
		steps, float(arrived) / float(steps), float(rebuilt) / float(steps),
		float(walked.corners_sampled - sampled_before) / float(steps),
		walk_ms / float(steps),
	])
	quit(0)


func _spread(values: Array[float]) -> String:
	if values.is_empty():
		return "(none)"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return "min=%.2f med=%.2f mean=%.2f max=%.2f" % [
		sorted[0], sorted[sorted.size() / 2], total / float(sorted.size()),
		sorted[sorted.size() - 1],
	]
