extends SceneTree
## What the grass on the floating islands costs, measured the way the ground's
## grass was measured.
##
## The same three counts and the same warning as tools/measure_grass.gd: the
## instanced unit is a patch of several tufts, so instances, tufts and blades are
## not interchangeable, and only the last is a coverage number. Frame times on a
## machine with no GPU are software rasterisation and are not the game's frame
## rate; what carries across is the instance count, the triangle count, the draw
## calls, the build time and the ratio between the two passes.
##
##   ./tools/measure_island_grass.sh                        # seed 1234
##   ./tools/measure_island_grass.sh --seed 7 --start 12 -8
##
## Runs the render shell itself, settles the world, holds it still, samples
## frames with the islands' grass in place, then deletes exactly those drawables
## -- the ground keeps its own -- and samples the same frames again. So the two
## passes differ by the island grass and by nothing else.
##
## It then grows every loaded island's grass again from a layer that has never
## seen any of it and times that, against what meshing the island itself costs,
## and reports both densities per square unit of *top surface* so that an
## island's grass and the ground's can be compared per square metre rather than
## per drawable.

const WARM_FRAMES := 150
const SAMPLE_FRAMES := 120
const REBUILD_PASSES := 3

var _shell: Node = null
var _frames := 0
var _phase := 0
var _last_usec := 0
var _times: Array[float] = []
var _draws: Array[float] = []
var _primitives: Array[float] = []
var _with := {}
var _without := {}
var _built := {}


func _initialize() -> void:
	_shell = load("res://render/main.tscn").instantiate()
	root.add_child(_shell)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	_frames += 1
	if _frames == 1:
		# Held still for the whole measurement, so the two passes are the same
		# view of the same place. It has to happen here rather than at startup:
		# the shell reads its own arguments in _ready(), which does not run until
		# the tree's first frame.
		_shell.set("_paused", true)

	match _phase:
		0:
			if _frames >= WARM_FRAMES:
				_phase = 1
				_frames = 0
				_reset()
		1:
			_sample(frame_ms)
			if _frames >= SAMPLE_FRAMES:
				_with = _summary()
				_built = _time_the_build()
				_strip_island_grass()
				_phase = 2
				_frames = 0
		2:
			if _frames >= 30:
				_phase = 3
				_frames = 0
				_reset()
		3:
			_sample(frame_ms)
			if _frames >= SAMPLE_FRAMES:
				_without = _summary()
				_report()
				return true
	return false


func _reset() -> void:
	_times = []
	_draws = []
	_primitives = []


func _sample(frame_ms: float) -> void:
	_times.append(frame_ms)
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_primitives.append(
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	)


func _summary() -> Dictionary:
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for one in sorted:
		total += one
	var loaded := 0
	var drawn := 0
	var plates := 0
	for view in _island_grass_views():
		var multimesh: MultiMesh = view.multimesh
		if multimesh == null:
			continue
		plates += 1
		loaded += multimesh.instance_count
		var shown := multimesh.visible_instance_count
		drawn += multimesh.instance_count if shown < 0 else shown
	return {
		"mean": total / float(sorted.size()),
		"median": sorted[sorted.size() / 2],
		"p95": sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))],
		"plates": plates,
		"loaded": loaded,
		"drawn": drawn,
		"draws": _mean(_draws),
		"primitives": _mean(_primitives),
	}


## Grow every loaded island's grass again, from a layer that has never seen any
## of it, and time it against what the island's own geometry costs to mesh.
func _time_the_build() -> Dictionary:
	var world = _shell.get("_sim").world
	var islands: Array = []
	var geometries: Array = []
	for key in world.island_streamer.loaded_keys():
		var island: FloatingIsland = world.island_streamer.island(key)
		if island == null or not island.walkable:
			continue
		islands.append(island)
		geometries.append(world.island_streamer.geometry(key))

	var best := INF
	var instances := 0
	var top := 0.0
	for _pass in REBUILD_PASSES:
		var layer := GrassLayer.new(world.terrain, world.world_seed)
		var started := Time.get_ticks_usec()
		var grown := 0
		var built: Array = []
		for at in islands.size():
			var view := layer.build_island(
				geometries[at] as TerrainChunkGeometry, islands[at] as FloatingIsland
			)
			if view != null:
				grown += view.multimesh.instance_count
				built.append(view)
		var spent := float(Time.get_ticks_usec() - started)
		for view in built:
			view.free()
		instances = grown
		best = minf(best, spent)

	# The islands' own geometry, meshed again from scratch, so the grass's build
	# cost has something to be a fraction of.
	var mesher := IslandMesher.new()
	var ground := INF
	for _pass in REBUILD_PASSES:
		var started := Time.get_ticks_usec()
		for island in islands:
			mesher.build(island as FloatingIsland)
		ground = minf(ground, float(Time.get_ticks_usec() - started))

	# How much top surface all that grass stands over, in plan: the same
	# denominator the ground's measurement uses, which is the whole surface
	# including the parts too steep or too wet to grow anything.
	for geometry in geometries:
		top += _top_area(geometry as TerrainChunkGeometry)

	return {
		"islands": islands.size(),
		"instances": instances,
		"top": top,
		"usec": best,
		"per_island": best / maxf(1.0, float(islands.size())),
		"mesh_per_island": ground / maxf(1.0, float(islands.size())),
	}


## The plan area of an island's up-facing surface, in square units.
func _top_area(geometry: TerrainChunkGeometry) -> float:
	var total := 0.0
	for triangle in geometry.triangle_count():
		var base := triangle * 3
		if geometry.normals[base].y <= 0.0:
			continue
		var a := geometry.vertices[base]
		var b := geometry.vertices[base + 1]
		var c := geometry.vertices[base + 2]
		total += absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) * 0.5
	return total


func _report() -> void:
	var baked := AssetLibrary.instanced_mesh(
		AssetTags.GRASS, GrassLayer.PATCH_COPIES, GrassLayer.PATCH_SPAN
	)
	var world = _shell.get("_sim").world
	var copies := int(baked["copies"])
	var blades := int(baked["blades"])
	var triangles := int(baked["triangles"])
	var loaded: int = _with["loaded"]
	var drawn: int = _with["drawn"]
	var top: float = _built["top"]

	# The ground's own numbers from the same frame, so the two densities are
	# measured on one world at one moment rather than across two runs.
	var chunk_loaded := 0
	var chunk_drawn := 0
	var chunks := 0
	for view in _chunk_grass_views():
		var multimesh: MultiMesh = view.multimesh
		if multimesh == null:
			continue
		chunks += 1
		chunk_loaded += multimesh.instance_count
		var shown := multimesh.visible_instance_count
		chunk_drawn += multimesh.instance_count if shown < 0 else shown
	var chunk_area := float(chunks) * TerrainChunkMesher.CHUNK_SIZE \
		* TerrainChunkMesher.CHUNK_SIZE

	print("measured at         (%.1f, %.1f), seed %d" % [
		world.observer_x, world.observer_z, world.world_seed,
	])
	print("islands with grass  %d of %d loaded, over %.0f square units of top surface" % [
		_with["plates"], _built["islands"], top,
	])
	print("slope gate          island %.3f (fall %.2f per unit), ground %.3f (fall %.2f)" % [
		GrassLayer.ISLAND_SLOPE_COS,
		sqrt(1.0 - GrassLayer.ISLAND_SLOPE_COS * GrassLayer.ISLAND_SLOPE_COS)
			/ GrassLayer.ISLAND_SLOPE_COS,
		GrassLayer.SLOPE_COS,
		sqrt(1.0 - GrassLayer.SLOPE_COS * GrassLayer.SLOPE_COS) / GrassLayer.SLOPE_COS,
	])
	print("")
	print("                        island top          ground")
	print("drawables             %12d  %12d" % [_with["plates"], chunks])
	print("square units          %12.0f  %12.0f" % [top, chunk_area])
	print("instances loaded      %12d  %12d" % [loaded, chunk_loaded])
	print("instances drawn       %12d  %12d" % [drawn, chunk_drawn])
	print("instances per unit²   %12.3f  %12.3f" % [
		float(loaded) / maxf(1.0, top), float(chunk_loaded) / maxf(1.0, chunk_area),
	])
	print("tufts per unit²       %12.2f  %12.2f" % [
		float(loaded * copies) / maxf(1.0, top),
		float(chunk_loaded * copies) / maxf(1.0, chunk_area),
	])
	print("blades per unit²      %12.2f  %12.2f" % [
		float(loaded * blades) / maxf(1.0, top),
		float(chunk_loaded * blades) / maxf(1.0, chunk_area),
	])
	print("")
	print("                       with island grass    without")
	print("instances drawn       %12d  %12d" % [drawn, _without["drawn"]])
	print("blades drawn          %12d  %12d" % [drawn * blades, 0])
	print("triangles drawn       %12d  %12d" % [drawn * triangles, 0])
	print("draw calls per frame  %12.0f  %12.0f" % [_with["draws"], _without["draws"]])
	print("primitives per frame  %12.0f  %12.0f" % [
		_with["primitives"], _without["primitives"],
	])
	print("frame ms mean         %12.2f  %12.2f" % [_with["mean"], _without["mean"]])
	print("frame ms median       %12.2f  %12.2f" % [_with["median"], _without["median"]])
	print("frame ms 95th         %12.2f  %12.2f" % [_with["p95"], _without["p95"]])
	print("")
	print("added by the islands' grass: %.2f ms per frame at the median (%d blades drawn)" % [
		float(_with["median"]) - float(_without["median"]), drawn * blades,
	])
	print("build: %d islands, %d instances, %.0f us total, %.0f us per island" % [
		_built["islands"], _built["instances"], _built["usec"], _built["per_island"],
	])
	print("       meshing the island under it costs %.0f us (%.0f%% as much)" % [
		_built["mesh_per_island"],
		100.0 * float(_built["per_island"]) / maxf(1.0, float(_built["mesh_per_island"])),
	])
	print("(software rasterisation: the frame times are an upper bound, not a frame rate)")


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for one in values:
		total += one
	return total / float(values.size())


## The islands' grass drawables, found where they live: one child named "grass"
## under each island's own node.
func _island_grass_views() -> Array[Node]:
	var found: Array[Node] = []
	for entry in (_shell.get("_island_grass") as Dictionary).values():
		var view = entry["view"]
		if view is MultiMeshInstance3D and is_instance_valid(view):
			found.append(view)
	return found


func _chunk_grass_views() -> Array[Node]:
	var found: Array[Node] = []
	for child in _shell.get_children():
		if String(child.name).begins_with("grass_") and child is MultiMeshInstance3D:
			found.append(child)
	return found


## Take the islands' grass off the scene, leaving the ground's alone. The world
## is held still, so no island streams in to put any back.
func _strip_island_grass() -> void:
	for view in _island_grass_views():
		(view as Node).get_parent().remove_child(view)
		(view as Node).queue_free()
	(_shell.get("_island_grass") as Dictionary).clear()
