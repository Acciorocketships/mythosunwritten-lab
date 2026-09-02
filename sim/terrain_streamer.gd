extends RefCounted
## Keeps the ground near the observers built, and forgets the rest.
##
## The world is infinite, so only the part someone is standing near exists as
## geometry at any moment. This holds the chunks that are currently built,
## builds ones that come within the load radius of any observer, and drops ones
## that are further than the unload radius from every observer.
##
## The two radii differ on purpose: with a single radius, an observer walking
## back and forth across the boundary would rebuild the same chunk every step.
##
## Nothing here needs the chunks to be built in any particular order. What is
## loaded is a set keyed by chunk coordinate, and what any chunk contains is a
## pure function of that coordinate and the seed, so the set after a given path
## is the same however the loads were interleaved -- and a chunk that is dropped
## and later reloaded comes back byte-identical.
class_name TerrainStreamer

## A chunk within this distance of an observer gets built.
const LOAD_RADIUS := 40.0

## A chunk further than this from every observer gets dropped. Must be larger
## than LOAD_RADIUS.
const UNLOAD_RADIUS := 56.0

var mesher: TerrainChunkMesher = null

## How many chunks have ever been built, including rebuilds. Diagnostic only --
## nothing in the world's state depends on it.
var chunks_built: int = 0

## How many detached copies geometry() has ever handed out. Diagnostic only --
## it is what a test uses to show that the copying happens once per chunk rather
## than once per frame.
var handles_handed_out: int = 0

# Chunk coordinate (Vector2i) -> TerrainChunkGeometry.
var _loaded := {}


func _init(chunk_mesher: TerrainChunkMesher = null) -> void:
	mesher = chunk_mesher


## Bring the loaded set in line with where the observers are now.
##
## Observers are world positions on the ground plane: x in Vector2.x, z in
## Vector2.y. With no observers at all, everything unloads.
func update(observers: Array[Vector2]) -> void:
	for observer in observers:
		_load_around(observer)
	_unload_far_from(observers)


## The loaded chunk coordinates, in a fixed order regardless of load order, so
## that two runs that loaded the same chunks report them the same way.
func loaded_keys() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for key in _loaded:
		keys.append(key)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y)
	return keys


func loaded_count() -> int:
	return _loaded.size()


func is_loaded(key: Vector2i) -> bool:
	return _loaded.has(key)


## The geometry of a loaded chunk as anyone outside the simulation gets it: a
## detached copy, or null if the chunk is not loaded.
##
## This is the accessor a viewer uses. Handing out a copy is what makes the
## one-way traffic between the layers a property of the code rather than of the
## viewer's good manners: whatever is done to the returned geometry, the loaded
## chunk is unchanged, so a viewer cannot edit the world it is drawing.
##
## The copy costs about a microsecond and is paid once per chunk handed out, not
## once per frame -- a viewer turns a chunk into a drawable once and keeps it for
## as long as the chunk stays loaded.
func geometry(key: Vector2i) -> TerrainChunkGeometry:
	var loaded: TerrainChunkGeometry = _loaded.get(key, null)
	if loaded == null:
		return null
	handles_handed_out += 1
	return loaded.detached_copy()


## The loaded chunk itself, or null if it is not loaded.
##
## Only the simulation may use this. Writing into what it returns changes the
## world, which is why the world's fingerprint reads the ground through here:
## it has to answer for the ground that actually exists, not for a copy of it.
func live_geometry(key: Vector2i) -> TerrainChunkGeometry:
	return _loaded.get(key, null)


func _load_around(observer: Vector2) -> void:
	var reach := int(ceil(LOAD_RADIUS / TerrainChunkMesher.CHUNK_SIZE)) + 1
	var centre := TerrainChunkMesher.chunk_at(observer.x, observer.y)
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var key := Vector2i(centre.x + offset_x, centre.y + offset_z)
			if _loaded.has(key):
				continue
			if TerrainChunkMesher.distance_to_chunk(key, observer.x, observer.y) > LOAD_RADIUS:
				continue
			_loaded[key] = mesher.build(key.x, key.y)
			chunks_built += 1


func _unload_far_from(observers: Array[Vector2]) -> void:
	var dropped: Array[Vector2i] = []
	for key in _loaded:
		var nearest := INF
		for observer in observers:
			nearest = minf(nearest, TerrainChunkMesher.distance_to_chunk(key, observer.x, observer.y))
		if nearest > UNLOAD_RADIUS:
			dropped.append(key)
	for key in dropped:
		_loaded.erase(key)
