extends RefCounted
## Keeps the villages and roads near the observers loaded, and forgets the rest.
##
## The same rule the ground and the islands follow, for the same reason: the
## world is infinite, so only the part someone is standing near exists as
## something to look at. A village comes within the load radius and is built, and
## goes past the unload radius and is dropped; the two radii differ so that
## walking back and forth across the boundary does not rebuild it every step.
##
## Nothing here needs anything to be built in any particular order. What is
## loaded is a set keyed by lattice cell or by road name, and what either
## contains is a pure function of that key and the seed -- so the set after a
## given walk is the same however the loads were interleaved, and a village that
## is dropped and later reloaded comes back identical. That is what the
## straddling-a-chunk-border test is really checking.
class_name SettlementStreamer

## A village whose pad comes within this distance of an observer is loaded, and
## one further than the second from every observer is dropped. Wider than the
## ground streamer's radii because a village is a landmark: it should be on
## screen before you are standing in it.
const LOAD_RADIUS := 90.0
const UNLOAD_RADIUS := 120.0

## The same for roads, which are streamed by segment proximity rather than by
## where their ends are -- a road between two villages is far longer than either
## radius, and what matters is whether the stretch of it near you is drawn.
const ROAD_LOAD_RADIUS := 70.0
const ROAD_UNLOAD_RADIUS := 96.0

## Where the villages and the roads come from.
var settlements: SettlementField = null
var paths: PathNetwork = null

## How many villages and roads have ever been loaded, including reloads.
## Diagnostic only -- nothing in the world's state depends on either.
var settlements_loaded := 0
var roads_loaded := 0

## How many detached copies have been handed out, the same diagnostic the ground
## streamer keeps.
var handles_handed_out := 0

# Vector2i cell -> Settlement.
var _villages := {}

# Road name -> the road, as the path network built it.
var _roads := {}


func _init(settlement_field: SettlementField = null, path_network: PathNetwork = null) -> void:
	settlements = settlement_field
	paths = path_network


## Bring the loaded sets in line with where the observers are now.
func update(observers: Array[Vector2]) -> void:
	for observer in observers:
		for site in settlements.settlements_near(observer.x, observer.y, LOAD_RADIUS):
			if _villages.has(site.cell):
				continue
			_villages[site.cell] = site
			settlements_loaded += 1
		for road in paths.edges_near(observer.x, observer.y, ROAD_LOAD_RADIUS):
			var name_of: String = road["id"]
			if _roads.has(name_of):
				continue
			_roads[name_of] = road
			roads_loaded += 1
	_unload_far_from(observers)


## The loaded village cells, in a fixed order regardless of load order.
func loaded_keys() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for key in _villages:
		keys.append(key)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y)
	return keys


## The loaded road names, sorted, for the same reason.
func loaded_roads() -> PackedStringArray:
	var names := PackedStringArray()
	for key in _roads:
		names.append(key)
	names.sort()
	return names


func loaded_count() -> int:
	return _villages.size()


func road_count() -> int:
	return _roads.size()


func is_loaded(key: Vector2i) -> bool:
	return _villages.has(key)


## A loaded village as anyone outside the simulation gets it: a detached copy,
## or null if it is not loaded. Handing over a copy is what keeps a viewer from
## editing the village it is drawing, exactly as for chunk geometry.
func settlement(key: Vector2i) -> Settlement:
	var found: Settlement = _villages.get(key, null)
	if found == null:
		return null
	handles_handed_out += 1
	return found.detached_copy()


## The loaded village itself. Only the simulation may use this -- the world's
## fingerprint reads through here, because it has to answer for the village that
## actually exists rather than for a copy of it.
func live_settlement(key: Vector2i) -> Settlement:
	return _villages.get(key, null)


## A loaded road, as a fresh dictionary of plain values. Roads are already plain
## data, so a copy is a duplicate of the dictionary and of the two lists inside
## it that a viewer might otherwise write into.
func road(name_of: String) -> Dictionary:
	var found: Dictionary = _roads.get(name_of, {})
	if found.is_empty():
		return {}
	handles_handed_out += 1
	var copy := found.duplicate()
	copy["points"] = (found["points"] as PackedVector2Array).duplicate()
	copy["bridges"] = _copied(found["bridges"])
	copy["props"] = _copied(found["props"])
	return copy


## The loaded road itself, for the simulation's own use.
func live_road(name_of: String) -> Dictionary:
	return _roads.get(name_of, {})


## A short, stable fingerprint of one loaded road: where it runs, what it
## crosses and what lines it. The world folds this into its own digest, so two
## processes that loaded the same roads can be compared road by road.
static func road_digest(road_data: Dictionary) -> String:
	var parts := PackedStringArray()
	parts.append(String(road_data["id"]))
	for point in road_data["points"] as PackedVector2Array:
		parts.append("%.4f,%.4f" % [point.x, point.y])
	for bridge in road_data["bridges"] as Array:
		parts.append("b:%s,%.4f,%.4f,%.4f,%.3f,%.4f" % [
			bridge["tag"], bridge["x"], bridge["z"], bridge["yaw"],
			bridge["span"], bridge["height"],
		])
	for prop in road_data["props"] as Array:
		parts.append("p:%s,%.4f,%.4f,%.4f" % [
			prop["tag"], prop["x"], prop["z"], prop["yaw"],
		])
	return "|".join(parts).sha256_text().substr(0, 16)


static func _copied(entries: Array) -> Array:
	var copy := []
	for entry in entries:
		copy.append((entry as Dictionary).duplicate())
	return copy


func _unload_far_from(observers: Array[Vector2]) -> void:
	var dropped: Array[Vector2i] = []
	for key in _villages:
		var site: Settlement = _villages[key]
		var nearest := INF
		for observer in observers:
			nearest = minf(nearest, site.distance_to(observer.x, observer.y))
		if nearest > UNLOAD_RADIUS:
			dropped.append(key)
	for key in dropped:
		_villages.erase(key)

	var dropped_roads := PackedStringArray()
	for key in _roads:
		var nearest := INF
		for observer in observers:
			nearest = minf(nearest, PathNetwork.distance_to_edge(
				_roads[key], observer.x, observer.y
			))
		if nearest > ROAD_UNLOAD_RADIUS:
			dropped_roads.append(key)
	for key in dropped_roads:
		_roads.erase(key)
