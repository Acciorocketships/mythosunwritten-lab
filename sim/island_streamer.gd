extends RefCounted
## Keeps the islands near the observers built, and forgets the rest.
##
## This is the ground streamer's rule applied to a different unit. Ground is
## streamed in square chunks because it is everywhere; islands are streamed one
## island at a time, because an island *is* the natural piece -- it has an edge,
## it is a few tens of units across, and cutting it into squares would put a seam
## down the middle of a cliff for no gain.
##
## Everything else is the same, deliberately: two radii rather than one, so that
## walking back and forth across the boundary does not rebuild the same island
## every step; a loaded set keyed by identity rather than a list, so load order
## cannot matter; and geometry that is a pure function of that identity and the
## seed, so an island dropped and later returned to comes back byte-identical.
##
## The bands are streamed at very different distances. Aerial islands are
## walkable ground, so they are loaded exactly as far out as the ground is: an
## island hanging over terrain that has not been built would be a plate floating
## over nothing. Far-sky islands are scenery on the horizon and are meant to be
## seen from a long way off, so they reach much further -- there is nothing under
## them to be missing.
class_name IslandStreamer

## Aerial islands are loaded and dropped at exactly the ground's distances, so
## an island never appears over ground that does not exist.
const AERIAL_LOAD_RADIUS := TerrainStreamer.LOAD_RADIUS
const AERIAL_UNLOAD_RADIUS := TerrainStreamer.UNLOAD_RADIUS

## Far-sky islands are the horizon, so they reach as far as the camera can see.
const FAR_LOAD_RADIUS := 520.0
const FAR_UNLOAD_RADIUS := 600.0

var field: IslandField = null
var mesher: IslandMesher = null

## What grows on the islands. Built alongside the geometry, from the island
## rather than from the world under it, and dropped with it.
var cover: IslandCover = null

## How many islands have ever been built, including rebuilds. Diagnostic only.
var islands_built: int = 0

## How many detached copies geometry() has ever handed out. Diagnostic only, and
## the same diagnostic the ground streamer keeps.
var handles_handed_out: int = 0

# Vector3i(cell x, cell z, band) -> {"island": FloatingIsland, "geometry": ...}.
var _loaded := {}


func _init(
	island_field: IslandField = null,
	island_mesher: IslandMesher = null,
	island_cover: IslandCover = null,
) -> void:
	field = island_field
	mesher = island_mesher if island_mesher != null else IslandMesher.new()
	cover = island_cover if island_cover != null \
		else IslandCover.new(island_field.world_seed if island_field != null else 0)


## How far out a band is loaded and dropped.
static func load_radius(band: int) -> float:
	return FAR_LOAD_RADIUS if band == FloatingIsland.FAR_SKY else AERIAL_LOAD_RADIUS


static func unload_radius(band: int) -> float:
	return FAR_UNLOAD_RADIUS if band == FloatingIsland.FAR_SKY else AERIAL_UNLOAD_RADIUS


## Bring the loaded set in line with where the observers are now. Observers are
## world positions on the ground plane, as they are for the ground streamer.
## With no observers at all, everything unloads.
func update(observers: Array[Vector2]) -> void:
	for band in [
		FloatingIsland.AERIAL, FloatingIsland.AERIAL_UPPER, FloatingIsland.FAR_SKY,
	]:
		for observer in observers:
			for island in field.islands_near(band, observer.x, observer.y, load_radius(band)):
				var key := island.key()
				if _loaded.has(key):
					continue
				_loaded[key] = {
					"island": island,
					"geometry": mesher.build(island),
					"cover": cover.build(island),
					"water": mesher.build_water(island),
				}
				islands_built += 1
	_unload_far_from(observers)


## The loaded islands' keys, in a fixed order regardless of load order, so that
## two runs that loaded the same islands report them the same way.
func loaded_keys() -> Array[Vector3i]:
	var keys: Array[Vector3i] = []
	for key in _loaded:
		keys.append(key)
	keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z:
			return a.z < b.z
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y)
	return keys


func loaded_count() -> int:
	return _loaded.size()


func is_loaded(key: Vector3i) -> bool:
	return _loaded.has(key)


## How many of the loaded islands are walkable ground rather than scenery.
func walkable_count() -> int:
	var walkable := 0
	for key in _loaded:
		if key.z != FloatingIsland.FAR_SKY:
			walkable += 1
	return walkable


## The island itself, as anyone outside the simulation gets it: a detached copy,
## or null if it is not loaded. This is where a viewer reads an island's drift
## from, and it cannot write back through it.
func island(key: Vector3i) -> FloatingIsland:
	if not _loaded.has(key):
		return null
	return (_loaded[key]["island"] as FloatingIsland).detached_copy()


## The geometry of a loaded island as anyone outside the simulation gets it: a
## detached copy, or null if it is not loaded. The ground streamer's geometry()
## in every respect, including that the copy is what keeps a viewer from editing
## the world it is drawing.
func geometry(key: Vector3i) -> TerrainChunkGeometry:
	if not _loaded.has(key):
		return null
	handles_handed_out += 1
	return (_loaded[key]["geometry"] as TerrainChunkGeometry).detached_copy()


## The loaded geometry itself. Only the simulation may use this -- writing into
## what it returns changes the world, which is why the world's fingerprint reads
## the islands through here rather than through a copy of them.
func live_geometry(key: Vector3i) -> TerrainChunkGeometry:
	if not _loaded.has(key):
		return null
	return _loaded[key]["geometry"]


## The live island itself, for the same reason.
func live_island(key: Vector3i) -> FloatingIsland:
	if not _loaded.has(key):
		return null
	return _loaded[key]["island"]


## What is growing on a loaded island, as anyone outside the simulation gets it:
## a detached copy, or null if it is not loaded. The same contract, for the same
## reason, as the geometry next door.
func cover_of(key: Vector3i) -> ScatterPatch:
	if not _loaded.has(key):
		return null
	handles_handed_out += 1
	return (_loaded[key]["cover"] as ScatterPatch).detached_copy()


## The loaded cover itself. Only the simulation may use this; the world's
## fingerprint reads through here because it has to answer for the cover that
## actually exists rather than for a copy of it.
func live_cover(key: Vector3i) -> ScatterPatch:
	if not _loaded.has(key):
		return null
	return _loaded[key]["cover"]


## The pond standing on a loaded island, as a detached copy, or null if it is
## not loaded. An island with no basin has one of these with no triangles in it.
func water_of(key: Vector3i) -> WaterSheet:
	if not _loaded.has(key):
		return null
	handles_handed_out += 1
	return (_loaded[key]["water"] as WaterSheet).detached_copy()


## The live pond, for the same reason again.
func live_water(key: Vector3i) -> WaterSheet:
	if not _loaded.has(key):
		return null
	return _loaded[key]["water"]


## How many things the loaded islands are dressed with altogether. What the
## trace line reports, so two runs can be compared on the aerial layer's cover
## as well as on its shape.
func cover_count() -> int:
	var total := 0
	for key in _loaded:
		total += (_loaded[key]["cover"] as ScatterPatch).count()
	return total


func _unload_far_from(observers: Array[Vector2]) -> void:
	var dropped: Array[Vector3i] = []
	for key in _loaded:
		var island: FloatingIsland = _loaded[key]["island"]
		var nearest := INF
		for observer in observers:
			nearest = minf(nearest, IslandField.distance_to(island, observer.x, observer.y))
		if nearest > unload_radius(island.band):
			dropped.append(key)
	for key in dropped:
		_loaded.erase(key)
