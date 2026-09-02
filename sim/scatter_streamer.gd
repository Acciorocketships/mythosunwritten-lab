extends RefCounted
## Keeps the dressing of the chunks near the observers built, and forgets the
## rest.
##
## The same rule, on the same lattice and with the same two radii, as the ground
## streamer next door: what is near somebody exists, what is far from everybody
## does not, and the radii differ so walking back and forth across the boundary
## does not rebuild anything. It is a streamer of its own rather than a field on
## the terrain streamer because a chunk's ground and a chunk's dressing are
## separate pieces of work -- the ground is meshed, the dressing is a list of
## placed things -- and the render layer draws them through different machinery.
##
## Nothing here needs anything to be built in any particular order, because a
## patch is a pure function of its chunk coordinate and the seed. A patch dropped
## and later returned to comes back byte-identical, which is exactly what the
## reload test asserts.
class_name ScatterStreamer

## Dressing is loaded and dropped with the ground it stands on, so both radii are
## the ground streamer's. A chunk with grass but no ferns, or ferns hanging in
## the air where the ground has been dropped, would both be visible mistakes.
const LOAD_RADIUS := TerrainStreamer.LOAD_RADIUS
const UNLOAD_RADIUS := TerrainStreamer.UNLOAD_RADIUS

## Where the dressing comes from.
var scatter: DecorationScatter = null

## How many patches have ever been built, including rebuilds after an unload.
## Diagnostic only -- nothing in the world's state depends on it.
var patches_built: int = 0

## How many detached copies have been handed out, the same diagnostic the ground
## streamer keeps for chunks.
var handles_handed_out: int = 0

# Vector2i chunk -> ScatterPatch.
var _loaded := {}


func _init(decoration_scatter: DecorationScatter = null) -> void:
	scatter = decoration_scatter


## Bring the loaded set in line with where the observers are now.
func update(observers: Array[Vector2]) -> void:
	for observer in observers:
		_load_around(observer)
	_unload_far_from(observers)


## The loaded chunk keys, in a fixed order regardless of load order.
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


## How many things are standing in the loaded world altogether. What the trace
## line reports, so that two runs can be compared on the dressing as well as on
## the ground.
func item_count() -> int:
	var total := 0
	for key in _loaded:
		total += (_loaded[key] as ScatterPatch).count()
	return total


## A loaded patch as anyone outside the simulation gets it: a detached copy, or
## null if it is not loaded. Handing over a copy is what keeps a viewer from
## editing the world it is drawing.
func patch(key: Vector2i) -> ScatterPatch:
	var found: ScatterPatch = _loaded.get(key, null)
	if found == null:
		return null
	handles_handed_out += 1
	return found.detached_copy()


## The loaded patch itself. Only the simulation may use this -- the world's
## fingerprint reads through here, because it has to answer for the dressing that
## actually exists rather than for a copy of it.
func live_patch(key: Vector2i) -> ScatterPatch:
	return _loaded.get(key, null)


func _load_around(observer: Vector2) -> void:
	var reach := int(ceil(LOAD_RADIUS / TerrainChunkMesher.CHUNK_SIZE)) + 1
	var here := TerrainChunkMesher.chunk_at(observer.x, observer.y)
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var key := Vector2i(here.x + offset_x, here.y + offset_z)
			if _loaded.has(key):
				continue
			if TerrainChunkMesher.distance_to_chunk(key, observer.x, observer.y) > LOAD_RADIUS:
				continue
			_loaded[key] = scatter.build(key.x, key.y)
			patches_built += 1


func _unload_far_from(observers: Array[Vector2]) -> void:
	var dropped: Array[Vector2i] = []
	for key in _loaded:
		var nearest := INF
		for observer in observers:
			nearest = minf(nearest, TerrainChunkMesher.distance_to_chunk(
				key, observer.x, observer.y
			))
		if nearest > UNLOAD_RADIUS:
			dropped.append(key)
	for key in dropped:
		_loaded.erase(key)
