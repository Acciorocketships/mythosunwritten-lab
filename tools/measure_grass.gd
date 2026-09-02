extends SceneTree
## What the grass costs: how much ground it covers, what it costs to build, and
## what drawing it adds to a frame.
##
## The instanced unit is a patch of several tufts, so there are three counts and
## they are not interchangeable: instances (rows of the multimesh, one draw's
## worth of transform each), tufts (copies of the asset row inside them) and
## blades (separate pieces of art -- the connected components of the mesh). Only
## the last is a coverage number, so it is the one reported per square metre.
##
##   ./tools/measure_grass.sh                      # seed 1234 at the origin
##   ./tools/measure_grass.sh --seed 7 --start 228 -60
##
## Runs the render shell itself rather than a stand-in, so what is counted is the
## scene the game actually draws. It settles the world, samples frames with the
## grass in place, then deletes every grass drawable and stops the layer being
## rebuilt and samples the same frames again -- so the two numbers differ by
## exactly the grass and by nothing else.
##
## It then rebuilds every one of those chunks from scratch with a fresh layer and
## times it, which is the CPU half of the cost: what a chunk of grass costs to
## grow, against what the chunk of ground under it cost to mesh.
##
## Frame times on a machine with no GPU are software rasterisation and are not
## the game's frame rate. What carries across is the instance count, the triangle
## count, the draw calls, the build time and the ratio between the two passes.

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
		# view of the same place and differ by the grass alone rather than by the
		# grass and by wherever the observer had walked to in between. It has to
		# happen here rather than at startup: the shell reads its own arguments
		# in _ready(), which does not run until the tree's first frame, and would
		# overwrite anything set before it.
		_shell.set("_paused", true)

	match _phase:
		0:
			if _frames >= WARM_FRAMES:
				_phase = 1
				_frames = 0
				_times = []
				_draws = []
				_primitives = []
		1:
			_sample(frame_ms)
			if _frames >= SAMPLE_FRAMES:
				_with = _summary()
				_built = _time_the_build()
				_strip_grass()
				_phase = 2
				_frames = 0
		2:
			if _frames >= 30:
				_phase = 3
				_frames = 0
				_times = []
				_draws = []
				_primitives = []
		3:
			_sample(frame_ms)
			if _frames >= SAMPLE_FRAMES:
				_without = _summary()
				_report()
				return true
	return false


## One frame's cost. The renderer's own counters are read every sampled frame
## and averaged rather than read once, because a single frame's count is
## whatever happened to be in the frustum that frame.
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
	var patches := 0
	for view in _grass_views():
		var multimesh: MultiMesh = view.multimesh
		if multimesh == null:
			continue
		patches += 1
		loaded += multimesh.instance_count
		var shown := multimesh.visible_instance_count
		drawn += multimesh.instance_count if shown < 0 else shown
	return {
		"mean": total / float(sorted.size()),
		"median": sorted[sorted.size() / 2],
		"p95": sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))],
		"patches": patches,
		"loaded": loaded,
		"drawn": drawn,
		"draws": _mean(_draws),
		"primitives": _mean(_primitives),
	}


## Build every chunk's grass again, from a layer that has never seen any of it,
## and time it. Several passes, taking the fastest, because this is a cost per
## chunk and the slowest pass is measuring the machine rather than the layer.
func _time_the_build() -> Dictionary:
	var world = _shell.get("_sim").world
	var keys: Array = world.terrain_streamer.loaded_keys()
	var observer := Vector2(world.observer_x, world.observer_z)
	var wanted: Array = []
	for key in keys:
		if GrassLayer.wanted_at(TerrainChunkMesher.distance_to_chunk(key, observer.x, observer.y)):
			wanted.append(key)

	var best := INF
	var instances := 0
	var geometries: Array = []
	for key in wanted:
		geometries.append(world.terrain_streamer.geometry(key))
	for _pass in REBUILD_PASSES:
		var layer := GrassLayer.new(world.terrain, world.world_seed)
		var started := Time.get_ticks_usec()
		var grown := 0
		var built: Array = []
		for geometry in geometries:
			var view := layer.build(geometry)
			if view != null:
				grown += view.multimesh.instance_count
				built.append(view)
		var spent := float(Time.get_ticks_usec() - started)
		for view in built:
			view.free()
		instances = grown
		best = minf(best, spent)
	# The same chunks' *ground*, meshed again from scratch, so the grass's build
	# cost has something to be a fraction of rather than being a bare number.
	var ground := INF
	for _pass in REBUILD_PASSES:
		var started := Time.get_ticks_usec()
		for key in wanted:
			world.chunk_mesher.build(key.x, key.y)
		ground = minf(ground, float(Time.get_ticks_usec() - started))

	return {
		"chunks": wanted.size(),
		"instances": instances,
		"usec": best,
		"per_chunk": best / maxf(1.0, float(wanted.size())),
		"ground_per_chunk": ground / maxf(1.0, float(wanted.size())),
	}


func _report() -> void:
	var baked := AssetLibrary.instanced_mesh(
		AssetTags.GRASS, GrassLayer.PATCH_COPIES, GrassLayer.PATCH_SPAN
	)
	var world = _shell.get("_sim").world
	var profile: BiomeProfile = world.terrain.profile_at(world.observer_x, world.observer_z)
	var weights: Dictionary = world.terrain.biome_field.weights_at(
		world.observer_x, world.observer_z
	)
	var cover := GrassLayer.coverage_for(weights)
	var mask: float = GrassLayer.clearing_at(
		world.observer_x, world.observer_z, world.world_seed
	)
	print("measured at         (%.1f, %.1f) in %s" % [
		world.observer_x, world.observer_z, profile.display_name,
	])
	# Two different numbers that used to be one. The first is what the biome asks
	# the *scatter* for and is no longer what grass reads; the second is the grass
	# layer's own, and the third and fourth are what the clearing mask and the
	# curve make of it right where the observer is standing.
	print("scatter density     %.3f (what the trees and ferns grow from)" % [
		profile.foliage_density,
	])
	print("grass coverage      %.3f blended, mask %.3f here, so %.3f of the lattice" % [
		cover, mask, GrassLayer.grown_share(mask, cover),
	])
	var loaded: int = _with["loaded"]
	var drawn: int = _with["drawn"]
	var copies: int = int(baked["copies"])
	var blades: int = int(baked["blades"])
	print("one instance        a patch of %d tufts, %d blades, %d vertices, %d triangles" % [
		copies, blades, baked["vertices"], baked["triangles"],
	])
	print("                    %.3f units tall, reaching %.2f units from its middle" % [
		baked["height"], baked["reach"],
	])
	print("build radius        %.0f units (ground streams to %.0f)" % [
		GrassLayer.BUILD_RADIUS, TerrainStreamer.LOAD_RADIUS,
	])
	# The ground the loaded grass stands over: every chunk that grew any, whole.
	# Water, roads and village floors inside those chunks are ground that grew
	# none, and are deliberately counted, because the question the coverage
	# number answers is how thick the grass is over a meadow rather than how
	# thick it is over the parts of a meadow that grow grass.
	var ground := float(_with["patches"]) * TerrainChunkMesher.CHUNK_SIZE \
		* TerrainChunkMesher.CHUNK_SIZE
	print("ground with grass   %.0f square units over %d chunks" % [
		ground, _with["patches"],
	])
	print("coverage            %.2f instances, %.1f tufts, %.1f blades per square unit" % [
		float(loaded) / maxf(1.0, ground),
		float(loaded * copies) / maxf(1.0, ground),
		float(loaded * blades) / maxf(1.0, ground),
	])
	# How much of the candidate lattice actually grew, over the chunks that grew
	# anything, and how many chunks in the build radius grew nothing at all. The
	# second is the number that says "in patches": before the clearing mask it
	# was zero everywhere except over water and cliff.
	var candidates := float(_with["patches"]) * float(GrassLayer.LATTICE * GrassLayer.LATTICE)
	print("lattice grown       %.3f of candidates over the chunks that grew any" % [
		float(loaded) / maxf(1.0, candidates),
	])
	print("chunks left bare    %d of %d inside the build radius" % [
		int(_built["chunks"]) - int(_with["patches"]), _built["chunks"],
	])
	print("")
	print("                          with grass       without")
	print("chunks with grass     %12d  %12d" % [_with["patches"], _without["patches"]])
	print("instances loaded      %12d  %12d" % [loaded, _without["loaded"]])
	print("instances drawn       %12d  %12d" % [drawn, _without["drawn"]])
	print("tufts drawn           %12d  %12d" % [drawn * copies, 0])
	print("blades drawn          %12d  %12d" % [drawn * blades, 0])
	print("triangles drawn       %12d  %12d" % [
		drawn * int(baked["triangles"]), 0,
	])
	print("draw calls per frame  %12.0f  %12.0f" % [_with["draws"], _without["draws"]])
	print("primitives per frame  %12.0f  %12.0f" % [
		_with["primitives"], _without["primitives"],
	])
	print("frame ms mean         %12.2f  %12.2f" % [_with["mean"], _without["mean"]])
	print("frame ms median       %12.2f  %12.2f" % [_with["median"], _without["median"]])
	print("frame ms 95th         %12.2f  %12.2f" % [_with["p95"], _without["p95"]])
	print("")
	var added: float = float(_with["median"]) - float(_without["median"])
	print("added by the grass: %.2f ms per frame at the median (%d blades drawn)" % [
		added, drawn * blades,
	])
	print("build: %d chunks, %d instances, %.0f us total, %.0f us per chunk" % [
		_built["chunks"], _built["instances"], _built["usec"], _built["per_chunk"],
	])
	print("       the ground under them costs %.0f us per chunk to mesh (%.0f%% as much)" % [
		_built["ground_per_chunk"],
		100.0 * float(_built["per_chunk"]) / maxf(1.0, float(_built["ground_per_chunk"])),
	])
	print("(software rasterisation: the frame times are an upper bound, not a frame rate)")


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for one in values:
		total += one
	return total / float(values.size())


func _grass_views() -> Array[Node]:
	var found: Array[Node] = []
	for child in _shell.get_children():
		if String(child.name).begins_with("grass_") and child is MultiMeshInstance3D:
			found.append(child)
	return found


## Take the grass off the scene and stop the shell putting it back.
func _strip_grass() -> void:
	_shell.set("_grass", null)
	for view in _grass_views():
		_shell.remove_child(view)
		view.queue_free()
	(_shell.get("_grass_views") as Dictionary).clear()
