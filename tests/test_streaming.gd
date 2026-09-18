extends TestSuite
## What is scattered on the ground follows whoever is standing on it.
##
## This used to be the ground's own streamer. The ground on screen is the
## adopted base's now, streamed by `FieldTerrainStreamer` in the render layer on
## a lattice of its own; what this project still streams, on the 16-unit patch
## lattice `ScatterPatch` owns, is the dressing -- what grows and what stands on
## a patch of ground. The rule is the one the ground was streamed by, and it is
## the rule, not the layer, that this suite is about.
##
## An observer is walked along a path, headless, and after every step the loaded
## set is checked against the rule it is supposed to follow: everything within
## the load radius of someone is built, nothing beyond the unload radius of
## everyone is still around. The final set is then compared with an expectation
## worked out here, from the path, rather than with whatever the streamer
## happened to produce.
##
## It also checks the part that matters for an infinite world: a patch that is
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
	_revisited_patches_come_back_identical()
	_dressing_stays_while_any_observer_is_near()
	_the_world_streams_as_the_observer_walks()


func _new_streamer() -> ScatterStreamer:
	return ScatterStreamer.new(DecorationScatter.new(TerrainQuery.for_seed(SEED)))


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
			if ScatterPatch.distance_to_patch(key, 0.0, 0.0) <= ScatterPatch.LOAD_RADIUS:
				expected.append(key)
	expected.sort()

	equal(streamer.loaded_keys(), expected,
		"a standing observer should have exactly the patches within the load radius")
	check(expected.size() > 8,
		"expected a standing observer to load several patches, expected %d" % expected.size())
	equal(streamer.patches_built, expected.size(),
		"the streamer built more patches than it kept")

	# Standing still asks for no more work.
	streamer.update(_observers([Vector2(0.0, 0.0)]))
	equal(streamer.patches_built, expected.size(),
		"standing still rebuilt a patch that was already loaded")

	# With nobody anywhere, nothing stays loaded.
	var nobody: Array[Vector2] = []
	streamer.update(nobody)
	equal(streamer.loaded_count(), 0,
		"patches stayed loaded with no observer in the world")


func _walking_a_path_gives_the_expected_set() -> void:
	var streamer := _new_streamer()
	var path := _straight_path(Vector2(0.0, 0.0), Vector2(1.0, 0.35), 60)

	for point in path:
		streamer.update(_observers([point]))
		_check_invariants(streamer, [point], point)

	# The expected final set, worked out from the path: a patch is loaded if it
	# came within the load radius at some point on the walk and has not since
	# fallen outside the unload radius. Nothing here consults the streamer.
	var final_point: Vector2 = path[path.size() - 1]
	var expected: Array[Vector2i] = []
	for key in _candidates_near(path):
		var was_reached := false
		for point in path:
			if ScatterPatch.distance_to_patch(key, point.x, point.y) <= ScatterPatch.LOAD_RADIUS:
				was_reached = true
				break
		if not was_reached:
			continue
		var now := ScatterPatch.distance_to_patch(key, final_point.x, final_point.y)
		if now <= ScatterPatch.UNLOAD_RADIUS:
			expected.append(key)
	expected.sort()

	equal(streamer.loaded_keys(), expected,
		"the patches loaded after the walk are not the ones the rule calls for")
	check(streamer.patches_built > streamer.loaded_count(),
		"the walk never dropped any dressing: built %d, still loaded %d"
		% [streamer.patches_built, streamer.loaded_count()])

	# The same walk again, on a second streamer, arrives at the same set.
	var twin := _new_streamer()
	for point in path:
		twin.update(_observers([point]))
	equal(twin.loaded_keys(), streamer.loaded_keys(),
		"walking the same path twice loaded different patches")


func _revisited_patches_come_back_identical() -> void:
	var streamer := _new_streamer()
	var home := Vector2(0.0, 0.0)
	streamer.update(_observers([home]))

	var key := Vector2i(0, 0)
	check(streamer.is_loaded(key), "the patch under the observer should be loaded")
	var before := streamer.patch(key)
	var before_digest := before.digest()
	var before_count := before.count()

	# Walk away far enough that home is dropped, then walk back.
	for point in _straight_path(home, Vector2(1.0, 0.0), int(FAR_AWAY / STEP)):
		streamer.update(_observers([point]))
	check(not streamer.is_loaded(key),
		"the patch %v should have unloaded once the observer walked away" % key)
	var built_before_return := streamer.patches_built

	for point in _straight_path(Vector2(FAR_AWAY, 0.0), Vector2(-1.0, 0.0), int(FAR_AWAY / STEP)):
		streamer.update(_observers([point]))
	check(streamer.is_loaded(key),
		"the patch %v should have loaded again on returning" % key)
	check(streamer.patches_built > built_before_return,
		"the return trip built nothing, so nothing was really reloaded")

	var after := streamer.patch(key)
	equal(after.digest(), before_digest,
		"patch %v came back different after being unloaded and reloaded" % key)
	equal(after.count(), before_count,
		"patch %v came back holding a different number of things after a reload" % key)


func _dressing_stays_while_any_observer_is_near() -> void:
	var streamer := _new_streamer()
	var one := Vector2(0.0, 0.0)
	var two := Vector2(8.0, 8.0)
	streamer.update(_observers([one, two]))
	var key := Vector2i(0, 0)
	check(streamer.is_loaded(key), "the patch both observers stand on should be loaded")

	# The first observer leaves; the second is still standing on it.
	streamer.update(_observers([Vector2(FAR_AWAY, 0.0), two]))
	check(streamer.is_loaded(key),
		"a patch unloaded while an observer was still standing on it")

	# Now both are gone.
	streamer.update(_observers([Vector2(FAR_AWAY, 0.0), Vector2(0.0, FAR_AWAY)]))
	check(not streamer.is_loaded(key),
		"a patch stayed loaded with no observer near it")


## The streaming the world actually does, as opposed to a scripted path: run the
## simulation and check the same invariants against its own observer.
func _the_world_streams_as_the_observer_walks() -> void:
	var sim := Simulation.new(SEED)
	var starting_keys := sim.world.scatter_streamer.loaded_keys()
	check(starting_keys.size() > 0, "a fresh world should have dressing around its observer")

	for i in 200:
		sim.step()
		if i % 25 == 0:
			_check_invariants(
				sim.world.scatter_streamer,
				[Vector2(sim.world.observer_x, sim.world.observer_z)],
				Vector2(sim.world.observer_x, sim.world.observer_z),
			)

	var distance := Vector2(sim.world.observer_x, sim.world.observer_z).length()
	check(distance > ScatterPatch.UNLOAD_RADIUS,
		"the observer only travelled %f world units, too little to stream anything out"
		% distance)
	check(sim.world.scatter_streamer.patches_built > sim.world.scatter_streamer.loaded_count(),
		"the walk never dropped any dressing")


## Everything within the load radius of someone is built; nothing beyond the
## unload radius of everyone is still there.
func _check_invariants(
	streamer: ScatterStreamer, observers: Array, at: Vector2
) -> void:
	for key in streamer.loaded_keys():
		var nearest := INF
		for observer in observers:
			nearest = minf(nearest, ScatterPatch.distance_to_patch(key, observer.x, observer.y))
		check(nearest <= ScatterPatch.UNLOAD_RADIUS,
			"patch %v is %f from the nearest observer at %v, past the unload radius"
			% [key, nearest, at])

	var reach := int(ceil(ScatterPatch.LOAD_RADIUS / ScatterPatch.PATCH_SIZE)) + 1
	for observer in observers:
		var centre := ScatterPatch.patch_at(observer.x, observer.y)
		for offset_x in range(-reach, reach + 1):
			for offset_z in range(-reach, reach + 1):
				var key := Vector2i(centre.x + offset_x, centre.y + offset_z)
				if ScatterPatch.distance_to_patch(key, observer.x, observer.y) > ScatterPatch.LOAD_RADIUS:
					continue
				check(streamer.is_loaded(key),
					"patch %v is within the load radius of %v but is not loaded"
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


## Every patch coordinate close enough to any point on a path to be worth
## considering, so the expectation above does not have to scan the plane.
func _candidates_near(path: Array[Vector2]) -> Array[Vector2i]:
	var seen := {}
	var reach := int(ceil(ScatterPatch.UNLOAD_RADIUS / ScatterPatch.PATCH_SIZE)) + 1
	for point in path:
		var centre := ScatterPatch.patch_at(point.x, point.y)
		for offset_x in range(-reach, reach + 1):
			for offset_z in range(-reach, reach + 1):
				seen[Vector2i(centre.x + offset_x, centre.y + offset_z)] = true
	var keys: Array[Vector2i] = []
	for key in seen:
		keys.append(key)
	return keys
