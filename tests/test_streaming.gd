extends TestSuite
## The ground follows whoever is standing on it.
##
## An observer is walked along a path, headless, and after every step the loaded
## set is checked against the rule it is supposed to follow: everything within
## the load radius of someone is built, nothing beyond the unload radius of
## everyone is still around. The final set is then compared with an expectation
## worked out here, from the path, rather than with whatever the streamer
## happened to produce.
##
## It also checks the part that matters for an infinite world: ground that is
## dropped and later walked back to comes back exactly as it was.
class_name TestStreaming

const SEED := 7
const STEP := 4.0
const FAR_AWAY := 400.0


func _init() -> void:
	suite_name = "streaming"


func run() -> void:
	_loads_around_a_standing_observer()
	_walking_a_path_gives_the_expected_set()
	_revisited_ground_comes_back_identical()
	_ground_stays_while_any_observer_is_near()
	_the_world_streams_as_the_observer_walks()


func _new_streamer() -> TerrainStreamer:
	return TerrainStreamer.new(TerrainChunkMesher.new(TerrainQuery.for_seed(SEED)))


func _loads_around_a_standing_observer() -> void:
	var streamer := _new_streamer()
	streamer.update(_observers([Vector2(0.0, 0.0)]))

	# What should be loaded, enumerated here from the rule rather than read back
	# out of the streamer.
	var expected: Array[Vector2i] = []
	var reach := 8
	for x in range(-reach, reach + 1):
		for z in range(-reach, reach + 1):
			var key := Vector2i(x, z)
			if TerrainChunkMesher.distance_to_chunk(key, 0.0, 0.0) <= TerrainStreamer.LOAD_RADIUS:
				expected.append(key)
	expected.sort()

	equal(streamer.loaded_keys(), expected,
		"a standing observer should have exactly the chunks within the load radius")
	check(expected.size() > 8,
		"expected a standing observer to load several chunks, expected %d" % expected.size())
	equal(streamer.chunks_built, expected.size(),
		"the streamer built more chunks than it kept")

	# Standing still asks for no more work.
	streamer.update(_observers([Vector2(0.0, 0.0)]))
	equal(streamer.chunks_built, expected.size(),
		"standing still rebuilt ground that was already loaded")

	# With nobody anywhere, nothing stays loaded.
	var nobody: Array[Vector2] = []
	streamer.update(nobody)
	equal(streamer.loaded_count(), 0,
		"chunks stayed loaded with no observer in the world")


func _walking_a_path_gives_the_expected_set() -> void:
	var streamer := _new_streamer()
	var path := _straight_path(Vector2(0.0, 0.0), Vector2(1.0, 0.35), 60)

	for point in path:
		streamer.update(_observers([point]))
		_check_invariants(streamer, [point], point)

	# The expected final set, worked out from the path: a chunk is loaded if it
	# came within the load radius at some point on the walk and has not since
	# fallen outside the unload radius. Nothing here consults the streamer.
	var final_point: Vector2 = path[path.size() - 1]
	var expected: Array[Vector2i] = []
	for key in _candidates_near(path):
		var was_reached := false
		for point in path:
			if TerrainChunkMesher.distance_to_chunk(key, point.x, point.y) <= TerrainStreamer.LOAD_RADIUS:
				was_reached = true
				break
		if not was_reached:
			continue
		var now := TerrainChunkMesher.distance_to_chunk(key, final_point.x, final_point.y)
		if now <= TerrainStreamer.UNLOAD_RADIUS:
			expected.append(key)
	expected.sort()

	equal(streamer.loaded_keys(), expected,
		"the chunks loaded after the walk are not the ones the rule calls for")
	check(streamer.chunks_built > streamer.loaded_count(),
		"the walk never dropped any ground: built %d, still loaded %d"
		% [streamer.chunks_built, streamer.loaded_count()])

	# The same walk again, on a second streamer, arrives at the same set.
	var twin := _new_streamer()
	for point in path:
		twin.update(_observers([point]))
	equal(twin.loaded_keys(), streamer.loaded_keys(),
		"walking the same path twice loaded different ground")


func _revisited_ground_comes_back_identical() -> void:
	var streamer := _new_streamer()
	var home := Vector2(0.0, 0.0)
	streamer.update(_observers([home]))

	var key := Vector2i(0, 0)
	check(streamer.is_loaded(key), "the chunk under the observer should be loaded")
	var before := streamer.geometry(key)
	var before_digest := before.digest()
	var before_vertices := before.vertices.duplicate()

	# Walk away far enough that home is dropped, then walk back.
	for point in _straight_path(home, Vector2(1.0, 0.0), int(FAR_AWAY / STEP)):
		streamer.update(_observers([point]))
	check(not streamer.is_loaded(key),
		"the chunk %v should have unloaded once the observer walked away" % key)
	var built_before_return := streamer.chunks_built

	for point in _straight_path(Vector2(FAR_AWAY, 0.0), Vector2(-1.0, 0.0), int(FAR_AWAY / STEP)):
		streamer.update(_observers([point]))
	check(streamer.is_loaded(key),
		"the chunk %v should have loaded again on returning" % key)
	check(streamer.chunks_built > built_before_return,
		"the return trip built no ground, so nothing was really reloaded")

	var after := streamer.geometry(key)
	equal(after.digest(), before_digest,
		"chunk %v came back different after being unloaded and reloaded" % key)
	equal(after.vertices, before_vertices,
		"chunk %v came back with different vertices after a reload" % key)


func _ground_stays_while_any_observer_is_near() -> void:
	var streamer := _new_streamer()
	var one := Vector2(0.0, 0.0)
	var two := Vector2(8.0, 8.0)
	streamer.update(_observers([one, two]))
	var key := Vector2i(0, 0)
	check(streamer.is_loaded(key), "the chunk both observers stand on should be loaded")

	# The first observer leaves; the second is still standing on it.
	streamer.update(_observers([Vector2(FAR_AWAY, 0.0), two]))
	check(streamer.is_loaded(key),
		"ground unloaded while an observer was still standing on it")

	# Now both are gone.
	streamer.update(_observers([Vector2(FAR_AWAY, 0.0), Vector2(0.0, FAR_AWAY)]))
	check(not streamer.is_loaded(key),
		"ground stayed loaded with no observer near it")


## The streaming the world actually does, as opposed to a scripted path: run the
## simulation and check the same invariants against its own observer.
func _the_world_streams_as_the_observer_walks() -> void:
	var sim := Simulation.new(SEED)
	var starting_keys := sim.world.terrain_streamer.loaded_keys()
	check(starting_keys.size() > 0, "a fresh world should have ground under its observer")

	for i in 200:
		sim.step()
		if i % 25 == 0:
			_check_invariants(
				sim.world.terrain_streamer,
				[Vector2(sim.world.observer_x, sim.world.observer_z)],
				Vector2(sim.world.observer_x, sim.world.observer_z),
			)

	var distance := Vector2(sim.world.observer_x, sim.world.observer_z).length()
	check(distance > TerrainStreamer.UNLOAD_RADIUS,
		"the observer only travelled %f world units, too little to stream anything out"
		% distance)
	check(sim.world.terrain_streamer.chunks_built > sim.world.terrain_streamer.loaded_count(),
		"the walk never dropped any ground")


## Everything within the load radius of someone is built; nothing beyond the
## unload radius of everyone is still there.
func _check_invariants(
	streamer: TerrainStreamer, observers: Array, at: Vector2
) -> void:
	for key in streamer.loaded_keys():
		var nearest := INF
		for observer in observers:
			nearest = minf(nearest, TerrainChunkMesher.distance_to_chunk(key, observer.x, observer.y))
		check(nearest <= TerrainStreamer.UNLOAD_RADIUS,
			"chunk %v is %f from the nearest observer at %v, past the unload radius"
			% [key, nearest, at])

	var reach := int(ceil(TerrainStreamer.LOAD_RADIUS / TerrainChunkMesher.CHUNK_SIZE)) + 1
	for observer in observers:
		var centre := TerrainChunkMesher.chunk_at(observer.x, observer.y)
		for offset_x in range(-reach, reach + 1):
			for offset_z in range(-reach, reach + 1):
				var key := Vector2i(centre.x + offset_x, centre.y + offset_z)
				if TerrainChunkMesher.distance_to_chunk(key, observer.x, observer.y) > TerrainStreamer.LOAD_RADIUS:
					continue
				check(streamer.is_loaded(key),
					"chunk %v is within the load radius of %v but is not loaded"
					% [key, observer])


func _observers(points: Array) -> Array[Vector2]:
	var typed: Array[Vector2] = []
	for point in points:
		typed.append(point)
	return typed


func _straight_path(start: Vector2, direction: Vector2, steps: int) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var unit := direction.normalized()
	for i in steps:
		path.append(start + unit * (float(i + 1) * STEP))
	return path


## Every chunk coordinate close enough to any point on a path to be worth
## considering, so the expectation above does not have to scan the plane.
func _candidates_near(path: Array[Vector2]) -> Array[Vector2i]:
	var seen := {}
	var reach := int(ceil(TerrainStreamer.UNLOAD_RADIUS / TerrainChunkMesher.CHUNK_SIZE)) + 1
	for point in path:
		var centre := TerrainChunkMesher.chunk_at(point.x, point.y)
		for offset_x in range(-reach, reach + 1):
			for offset_z in range(-reach, reach + 1):
				seen[Vector2i(centre.x + offset_x, centre.y + offset_z)] = true
	var keys: Array[Vector2i] = []
	for key in seen:
		keys.append(key)
	return keys
