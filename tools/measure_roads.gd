extends SceneTree
## Where roads run together, and whether the roadway they leave behind is
## something a character can walk.
##
##   ./tools/measure_roads.sh                 # six seeds
##   ./tools/measure_roads.sh --seed 1234
##   ./tools/measure_roads.sh --at -157.2 49.1 --within 1.85
##
## Four questions, all asked of the same fields the game builds the world from,
## so running this generates nothing and changes no world:
##
##   * **overlap** -- how many separate roads have their carving over one point.
##     One almost everywhere; more where the graph lays two roads along the same
##     line, which is the thing being measured.
##   * **steps** -- walking every road at the width of one cell of the tactical
##     lattice, how many steps of *finished* roadway climb more than a character
##     can step up. Zero is the property wanted; anything else is a wall in the
##     middle of a road.
##   * **cross-fall** -- how far out of level the roadway is across its own
##     width, measured at both verges, split by whether one road or several are
##     carving there. The bound that matters is the road's own depth: a step
##     bigger than the trough it lives in is a fault in the ground.
##   * **shape** -- villages, roads and which places are joined to which, so
##     that a change to the graph can be shown to have cost no connections.
##
## The step limit and the lattice are read off TerrainQuery and CombatBoard
## rather than restated, so this tool cannot drift from the limits the game
## enforces.

## The seeds measured when none is named: the six the settlement suite sweeps.
const SEEDS := [1234, 7, 3, 19, 42, 101]

## How far from the origin roads are gathered, in world units.
const REACH := 900.0

## The lattice a road is walked on, and the climb one step may make. The
## tactical lattice's own numbers.
const LATTICE := CombatBoard.CELL_SIZE
const STEP_UP := TerrainQuery.HOP_HEIGHT

## How far off the centreline the two verges are sampled, as a share of the
## roadway's half width. Inside the flat part of the track at both verges.
const VERGE_SHARE := 0.8


func _initialize() -> void:
	var seeds: Array = []
	var at := Vector2.INF
	var within := 1.85
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size():
			seeds.append(args[i + 1].to_int())
		elif args[i] == "--at" and i + 2 < args.size():
			at = Vector2(args[i + 1].to_float(), args[i + 2].to_float())
		elif args[i] == "--within" and i + 1 < args.size():
			within = args[i + 1].to_float()
	if seeds.is_empty():
		seeds = SEEDS
	print("roads within %.0f units of the origin, walked every %.1f units" % [REACH, LATTICE])
	print("step limit %.1f, road depth %.2f\n" % [STEP_UP, PathNetwork.PATH_DEPTH])
	var total_steps := 0
	var total_over := 0
	var worst_fall := 0.0
	for world_seed: int in seeds:
		var seed_result := _measure(world_seed, at, within)
		total_steps += int(seed_result["steps"])
		total_over += int(seed_result["over"])
		worst_fall = maxf(worst_fall, float(seed_result["worst_cross"]))
	print("\nall seeds: %d of %d steps of finished roadway over the %.1f limit"
		% [total_over, total_steps, STEP_UP])
	print("all seeds: worst cross-fall %.3f against the %.2f the road is worn in"
		% [worst_fall, PathNetwork.PATH_DEPTH])
	quit()


func _measure(world_seed: int, at: Vector2, within: float) -> Dictionary:
	var query := TerrainQuery.for_seed(world_seed)
	var network := query.path_network
	var places := network.places_near(0.0, 0.0, REACH)
	var roads := []
	var seen := {}
	for place in places:
		for edge in network.edges_from(place):
			if seen.has(String(edge["id"])):
				continue
			seen[String(edge["id"])] = true
			roads.append(edge)
	var villages := 0
	for place in places:
		if String(place["kind"]) == "settlement":
			villages += 1

	var steps := 0
	var over := 0
	var worst_step := 0.0
	var walls: Array[String] = []
	var worst_where := ""
	var worst_one_where := ""
	var worst_excess := -INF
	var checked := 0
	var overlap_points := 0
	var worst_one := 0.0
	var worst_many := 0.0
	for edge in roads:
		var walked := _walk_lattice(edge["points"])
		var last := query.ground_height_at(walked[0].x, walked[0].y)
		for index in range(1, walked.size()):
			var here := query.ground_height_at(walked[index].x, walked[index].y)
			steps += 1
			var climb := absf(here - last)
			worst_step = maxf(worst_step, climb)
			if climb > STEP_UP:
				over += 1
				walls.append("(%.1f, %.1f) climbs %.3f on %s, %d roads over it"
					% [walked[index].x, walked[index].y, climb, edge["id"],
					query.path_network.roads_over(walked[index].x, walked[index].y)])
			last = here
		for index in walked.size():
			var fall := _cross_fall(query, walked, index)
			if fall.is_empty():
				continue
			checked += 1
			if float(fall["levelled"]) < 0.999:
				overlap_points += 1
				worst_excess = maxf(
					worst_excess, float(fall["error"]) - float(fall["land"])
				)
				if float(fall["error"]) > worst_many:
					worst_many = float(fall["error"])
					worst_where = "(%.1f, %.1f) on %s, %d roads, land %.3f" % [
						walked[index].x, walked[index].y, edge["id"],
						int(fall["roads"]), float(fall["land"])]
			elif float(fall["error"]) > worst_one:
				worst_one = float(fall["error"])
				worst_one_where = "(%.1f, %.1f) on %s, %d roads" % [
					walked[index].x, walked[index].y, edge["id"],
					int(fall["roads"])]

	print("seed %d" % world_seed)
	print("  villages %d, places %d, roads %d" % [villages, places.size(), roads.size()])
	print("  %s" % _components(places, roads))
	print("  steps %d, over the %.1f limit %d, worst step %.3f"
		% [steps, STEP_UP, over, worst_step])
	print("  verge pairs %d, of which %d are not levelled to one road alone"
		% [checked, overlap_points])
	print("  worst cross-fall: levelled %.3f, converging %.3f (depth %.2f)"
		% [worst_one, worst_many, PathNetwork.PATH_DEPTH])
	if worst_excess > -INF:
		print("  worst converging cross-fall past the land's own: %.3f" % worst_excess)
	if worst_one_where != "":
		print("  worst single-road cross-fall at %s" % worst_one_where)
	if worst_where != "":
		print("  worst shared cross-fall at %s" % worst_where)
	for wall in walls:
		print("  wall: %s" % wall)
	if at != Vector2.INF:
		var near := []
		for edge in roads:
			if PathNetwork.distance_to_edge(edge, at.x, at.y) <= within:
				near.append("%s (%.2f)"
					% [edge["id"], PathNetwork.distance_to_edge(edge, at.x, at.y)])
		near.sort()
		print("  roads within %.2f of (%.1f, %.1f): %d -- %s"
			% [within, at.x, at.y, near.size(), ", ".join(near)])
		print("  roads_over there: %d" % network.roads_over(at.x, at.y))
	return {
		"steps": steps, "over": over,
		"worst_cross": maxf(worst_one, worst_many),
	}


## The ground at a position with the villages levelled but no road carved into
## it: the land a road was worn into.
func _before_roads(query: TerrainQuery, x: float, z: float) -> float:
	var bed := query.water_field.bed_height_at(x, z)
	return bed + query.settlement_field.ground_delta_at(x, z, bed)


## A road's polyline resampled at the lattice's own cell width.
func _walk_lattice(points: PackedVector2Array) -> PackedVector2Array:
	var walked := PackedVector2Array()
	for index in points.size() - 1:
		var span := points[index].distance_to(points[index + 1])
		var pieces := maxi(1, int(ceil(span / LATTICE)))
		for piece in pieces:
			walked.append(points[index].lerp(
				points[index + 1], float(piece) / float(pieces)
			))
	walked.append(points[points.size() - 1])
	return walked


## How far out of level the roadway is across its width at one point of a road,
## and how many roads are carving there -- or an empty dictionary where the two
## verges are not both roadway on dry, unbuilt, unshadowed ground.
func _cross_fall(
	query: TerrainQuery, walked: PackedVector2Array, index: int
) -> Dictionary:
	var point := walked[index]
	if query.is_water_at(point.x, point.y) or query.is_bank_at(point.x, point.y):
		return {}
	if query.settlement_at(point.x, point.y) != null:
		return {}
	if query.island_field.walkable_island_over(point.x, point.y) != null:
		return {}
	if query.path_strength_at(point.x, point.y) < 0.999:
		return {}
	# How much of the ground here is a roadway levelled to one road's centreline.
	# Before the fix there was no such notion and the carve's own strength was
	# the nearest thing to it, so the tool asks for it and falls back, which is
	# what lets the same tool measure the world either side of the change.
	var levelled: float = query.path_network.level_strength_at(point.x, point.y) \
		if query.path_network.has_method("level_strength_at") \
		else query.path_strength_at(point.x, point.y)
	var before := walked[maxi(0, index - 1)]
	var after := walked[mini(walked.size() - 1, index + 1)]
	var along := (after - before).normalized()
	if along.length_squared() < 0.5:
		return {}
	var across := Vector2(-along.y, along.x) * PathNetwork.PATH_HALF_WIDTH * VERGE_SHARE
	var left := point + across
	var right := point - across
	for side in [left, right]:
		if query.is_water_at(side.x, side.y) or query.is_bank_at(side.x, side.y):
			return {}
		if query.island_field.walkable_island_over(side.x, side.y) != null:
			return {}
	return {
		"error": absf(
			query.ground_height_at(left.x, left.y)
			- query.ground_height_at(right.x, right.y)
		),
		"land": absf(
			_before_roads(query, left.x, left.y) - _before_roads(query, right.x, right.y)
		),
		"levelled": levelled,
		"roads": maxi(
			query.path_network.roads_over(left.x, left.y),
			query.path_network.roads_over(right.x, right.y),
		),
	}


## Which places are joined to which, as one line: how many groups the roads
## leave the places in, how big they are, and a digest of the grouping itself so
## that two runs can be compared without reading the whole partition.
func _components(places: Array, roads: Array) -> String:
	var parent := {}
	for place in places:
		parent[String(place["id"])] = String(place["id"])
	for edge in roads:
		var a := String(edge["from_id"])
		var b := String(edge["to_id"])
		if not parent.has(a):
			parent[a] = a
		if not parent.has(b):
			parent[b] = b
		var ra := _root(parent, a)
		var rb := _root(parent, b)
		if ra != rb:
			parent[ra] = rb
	var groups := {}
	for id: String in parent:
		var root := _root(parent, id)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(id)
	var lines: Array[String] = []
	var sizes: Array[int] = []
	var alone := 0
	for root: String in groups:
		var members: Array = groups[root]
		members.sort()
		sizes.append(members.size())
		if members.size() == 1:
			alone += 1
		lines.append("|".join(members))
	lines.sort()
	sizes.sort()
	sizes.reverse()
	return "groups %d, sizes %s, alone %d, grouping %s" % [
		groups.size(), str(sizes), alone,
		String("\n".join(lines)).sha256_text().substr(0, 12),
	]


func _root(parent: Dictionary, id: String) -> String:
	var at := id
	while String(parent[at]) != at:
		at = String(parent[at])
	return at
