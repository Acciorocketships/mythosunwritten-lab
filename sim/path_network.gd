extends RefCounted
## The roads: which places are joined to which, where the road runs, and where
## it has to be bridged.
##
## This is the second half of the settlement layer. The settlement field says
## where the villages and the landmarks are; this file strings them together and
## carves the result into the ground. Like everything under sim/ it is a pure
## function of the world seed -- there is no global graph anywhere, and nothing
## is built in any order.
##
## ## A graph you can build without seeing the whole world
##
## The world is infinite, so "connect the settlements" cannot mean a spanning
## tree: there is no set to span. What is wanted is a rule that two places can
## apply *locally* and always agree on, so that the same road appears whichever
## end of it you happen to be standing at.
##
## The rule used here is the relative neighbourhood graph. Two places A and B a
## distance d apart are joined exactly when no third place is closer than d to
## both of them -- that is, when the lens-shaped region between them is empty.
## It is local because that lens sits inside the circle of radius d around A, so
## both A and B can check it by looking only at their own neighbourhood, and it
## is symmetric because they are checking the same region. It also produces the
## right-looking road network: it keeps the short hops, it drops the long edge of
## a triangle whose other two sides go via a place in the middle, and it never
## crosses itself the way a nearest-neighbour rule does.
##
## ## What a road does to the world
##
## A road is not a decal. Along its centreline the ground is levelled across the
## road's width and smoothed a little along it, then dropped by PATH_DEPTH so it
## reads as a worn trough rather than a stripe, and the ground colour is mixed
## towards dirt. Where the line crosses water the carving stops -- a road never
## drains a river -- and a bridge tag is placed over the crossing instead.
class_name PathNetwork

## How far apart two places may be and still be joined. Beyond this a road would
## be a line across country rather than a route between neighbours, and the
## graph would also stop being cheap to work out.
const LINK_RADIUS := 170.0

## World units across one tile of the lookup lattice. Asking "is there a road
## here" is asked once per terrain vertex, so the segments near a patch of world
## are worked out once per tile and remembered.
const TILE := 48.0

## How far outside a tile a road segment may be and still affect ground inside
## it: the tile's own half-diagonal plus the road's reach.
const TILE_MARGIN := TILE * 0.708 + 5.0

## Half the width of the levelled roadway, and how far past that the carving
## eases back into the land.
##
## The roadway is four and a half units across -- a cart and a verge, on a world whose
## chunks are sixteen units wide -- with a wide soft shoulder either side of it.
## Both numbers are set against the ground the road is drawn on rather than
## against a cart: the terrain is meshed on a two-unit grid and a road reaches it
## as a colour on those corners, so a track much narrower than this would fall
## between them and show as a dotted line, and a shoulder much narrower would
## turn every edge into a staircase of whole cells.
const PATH_HALF_WIDTH := 2.3
const PATH_FEATHER := 2.0

## How far the roadway sits below the ground it was levelled from. Slight on
## purpose: a road is worn into the land, not cut through it.
const PATH_DEPTH := 0.30

## How far apart the points of a road's polyline are, in world units.
const SEGMENT_STEP := 6.0

## How far a road bends away from the straight line between its ends, as a share
## of its length. Small: these are routes, not rambles.
const WOBBLE_SHARE := 0.075

## How far a road may bend when the easy line will not do, as a share of its
## length. Far wider than WOBBLE_SHARE, because this is not a wobble: it is the
## detour a road takes round the shoulder of a mountain rather than over it.
const DETOUR_SHARE := 0.30

## How many lines a road tries before it commits to one.
##
## The first is always the easy line above, so on ordinary ground -- where
## nothing on the line is too steep to walk -- the road is *exactly* the road it
## would have been before the mountains existed. The rest are wider detours,
## hashed out of the same road name, and one of them is taken only when the easy
## line climbs something a character could not.
const ROUTE_CANDIDATES := 6

## How fast a road may climb before the routing counts the line against itself,
## as rise over run.
##
## This is not a matter of taste. It is the terrain query's own step up (3.0
## world units) over the width of one cell of the tactical lattice (3.0), which
## is the steepest ground a character can actually walk up. A road steeper than
## that would be a road nobody can use -- a shelf cut into a mountain face with
## no way onto either end of it -- so the routing prefers any line that is not.
## The constant is written here rather than imported so that the path layer does
## not have to know that a combat lattice exists; the two are kept in step by
## tests/test_mountains.gd, which reads both.
const ROUTE_GRADE_LIMIT := 1.0

## How often a candidate line is sampled when it is scored, in world units.
##
## The width of one cell of that same lattice, and not SEGMENT_STEP: a limit
## about what one step can climb has to be measured over one step. Averaged over
## the six units between a road's own points, a face that rises four units in
## three and then levels off reads as a comfortable slope, and the road is laid
## straight up it.
const ROUTE_SAMPLE_STEP := 3.0

## How often the crossing test samples along a road, and the shortest run of
## water that is worth bridging. Anything shorter is a puddle the road goes
## round, and the carving's own clamp keeps it dry.
const CROSSING_STEP := 1.0
const BRIDGE_MIN_SPAN := 2.5

## How far past the water's edge a bridge's deck reaches, at each end.
const BRIDGE_ABUTMENT := 1.6

## How long one deck unit is, per bridge kind, in world units.
##
## A crossing wider than one unit is spanned by several laid end to end rather
## than by one stretched tag, because a bridge tag is a *thing* -- a span of
## planking, a stone arch -- and the pack that eventually answers for it will
## have been drawn at one size. The exact unit length is carried on each span so
## whoever draws it can close the last few centimetres.
const BRIDGE_UNIT := {
	AssetTags.BRIDGE_WOOD: 8.0,
	AssetTags.BRIDGE_STONE: 9.0,
}

## A crossing at least this wide gets the stone bridge rather than the wooden
## one. A long span in timber reads as a jetty.
const BRIDGE_STONE_SPAN := 9.0

## How high a bridge deck stands above the water it crosses.
const BRIDGE_RISE := 0.55

## How far out from a village a road is lit and signposted, and how far apart the
## lantern posts stand. Roads are lit near the warm-light hubs and dark between
## them, which is the art direction's cool-vs-warm contrast doing a job.
const LIT_LENGTH := 34.0
const LANTERN_SPACING := 11.0

## Where the signpost at a village's road head stands, as a distance along the
## road from where the road begins.
const SIGNPOST_AT := 4.0

## The least of the straight line between two places that is left as road after
## both ends have been trimmed back to their own edges, as a share.
const ROUTE_KEEP_MIN := 0.25

## Seed offset and salt stride for the per-road hashes.
const PATH_SEED_OFFSET := 0x1E4F2A9B
const SALT_STRIDE := 0x9E3779B1

## How many tiles and how many per-place edge lists are remembered at once.
const MEMO_LIMIT := 512

## The seed the road network descends from.
var world_seed: int = 0

## Where the places are.
var settlements: SettlementField = null

## The water a road may have to cross, and the ground it is carved into.
var water: WaterField = null

# Vector2i tile -> PackedVector2Array of segment endpoints, in pairs.
var _tiles := {}

# node id -> Array of edges owned by that node.
var _edges := {}


func _init(settlement_field: SettlementField = null, water_field: WaterField = null) -> void:
	settlements = settlement_field
	water = water_field if water_field != null else settlement_field.water
	world_seed = water.world_seed if water != null else 0


## Which tile of the lookup lattice a world position falls in.
static func tile_at(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / TILE), floori(z / TILE))


# --- The graph -----------------------------------------------------------

## Every place within `reach` of a position, villages and landmarks alike, in a
## fixed order: villages in cell order first, then landmarks in cell order.
##
## A place is {id, x, z, kind, tag}. That is all the graph needs to know about
## one -- whether it is a village with twenty houses or a stone circle changes
## nothing about how the road to it is decided.
func places_near(x: float, z: float, reach: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for site in settlements.settlements_near(x, z, reach + SettlementField.site_reach()):
		if Vector2(site.centre_x - x, site.centre_z - z).length() > reach:
			continue
		found.append({
			"id": site.id(),
			"x": site.centre_x,
			"z": site.centre_z,
			"kind": "settlement",
			"tag": "",
			"radius": site.radius,
		})
	for mark in settlements.landmarks_near(x, z, reach):
		found.append({
			"id": String(mark["id"]),
			"x": float(mark["x"]),
			"z": float(mark["z"]),
			"kind": "landmark",
			"tag": String(mark["tag"]),
			"radius": 0.0,
		})
	return found


## The roads owned by one place: those joining it to a place with a larger id.
##
## Every road belongs to exactly one of its two ends -- the one whose id sorts
## first -- so gathering the roads near somewhere never produces the same road
## twice, and never depends on which end was looked at first.
func edges_from(place: Dictionary) -> Array:
	var id := String(place["id"])
	if _edges.has(id):
		return _edges[id]
	var built := _build_edges(place)
	if _edges.size() >= MEMO_LIMIT:
		_edges.clear()
	_edges[id] = built
	return built


## Every road with any part of it within `reach` of a position, in a fixed
## order. What the streamer builds its loaded set out of.
func edges_near(x: float, z: float, reach: float) -> Array:
	var found := []
	for place in places_near(x, z, LINK_RADIUS + reach):
		for edge in edges_from(place):
			if distance_to_edge(edge, x, z) <= reach:
				found.append(edge)
	return found


func _build_edges(place: Dictionary) -> Array:
	var id := String(place["id"])
	var here := Vector2(float(place["x"]), float(place["z"]))
	var candidates := places_near(here.x, here.y, LINK_RADIUS)
	var built := []
	for other in candidates:
		var other_id := String(other["id"])
		# The lower id owns the road, so it is only ever built once.
		if other_id <= id:
			continue
		var there := Vector2(float(other["x"]), float(other["z"]))
		var span := here.distance_to(there)
		if span > LINK_RADIUS or span < 1.0:
			continue
		# The relative-neighbourhood test: is the lens between the two empty?
		# Every place that could be in it is within `span` of here, so the
		# candidate list already covers it.
		var blocked := false
		for third in candidates:
			var third_id := String(third["id"])
			if third_id == id or third_id == other_id:
				continue
			var at := Vector2(float(third["x"]), float(third["z"]))
			if maxf(here.distance_to(at), there.distance_to(at)) < span - 0.001:
				blocked = true
				break
		if blocked:
			continue
		built.append(_make_edge(place, other))
	return built


## One road: its ends, the line it takes, the bridges on it and its dressing.
func _make_edge(from_place: Dictionary, to_place: Dictionary) -> Dictionary:
	var from := Vector2(float(from_place["x"]), float(from_place["z"]))
	var to := Vector2(float(to_place["x"]), float(to_place["z"]))
	var id := "%s>%s" % [from_place["id"], to_place["id"]]
	# A road runs between the two places' edges, not between their middles. A
	# village's own ground is already trodden flat and coloured for it, and a road
	# carved on through the green would cut a trench across the market square and
	# put the well at the bottom of it.
	var span := from.distance_to(to)
	var along := (to - from) / maxf(span, 0.0001)
	var head := float(from_place["radius"])
	var tail := float(to_place["radius"])
	var keep := span * ROUTE_KEEP_MIN
	if span - head - tail < keep:
		var over := (span - keep) / maxf(head + tail, 0.0001)
		head *= maxf(0.0, over)
		tail *= maxf(0.0, over)
	var edge := {
		"id": id,
		"from_id": String(from_place["id"]),
		"to_id": String(to_place["id"]),
		"points": _route(id, from + along * head, to - along * tail),
		"length": span,
	}
	edge["bridges"] = _bridges_on(edge)
	edge["props"] = _dressing_on(edge, from_place, to_place)
	return edge


## The line a road takes: the straight run between its ends with a single easy
## bend hashed out of the road's own name, pinned at both ends so the road really
## does arrive where it is going -- or, where that line climbs something nobody
## could walk up, the best of a handful of wider detours hashed out of the same
## name.
##
## Roads used to be laid without ever asking what was under them, which was fine
## in a world whose whole relief was thirty units. It is not fine in a world with
## mountains in it: a straight line between two villages either side of a
## shoulder would be carved straight up a fifty-degree face, and what that
## produces is not a road but a shelf with no way onto it.
##
## So the line is chosen rather than merely hashed. Every candidate is scored by
## how far it climbs past ROUTE_GRADE_LIMIT, squared and summed, and the cheapest
## wins; the easy line is candidate zero and wins every tie, so ground that has
## nothing too steep on it keeps the road it already had, point for point. The
## whole thing stays a pure function of the road's name and the seed -- the same
## candidates in the same order, scored against a height field that does not care
## who asks.
func _route(id: String, from: Vector2, to: Vector2) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_cost := INF
	for candidate in ROUTE_CANDIDATES:
		var line := _line(id, from, to, candidate)
		var cost := _route_cost(line)
		if cost < best_cost:
			best_cost = cost
			best = line
		if best_cost <= 0.0:
			# The easy line is already walkable everywhere along it. Nothing a
			# wider detour could do would improve on that, and stopping here is
			# what keeps a road on flat country from paying for five extra
			# lines' worth of height samples.
			break
	return best


## One candidate line. Candidate zero is the road as it has always been: the
## same rolls, the same narrow wobble. The rest are drawn from their own rolls
## and may swing DETOUR_SHARE of the span aside.
func _line(id: String, from: Vector2, to: Vector2, candidate: int) -> PackedVector2Array:
	var span := from.distance_to(to)
	var steps := maxi(2, int(ceil(span / SEGMENT_STEP)))
	var along := (to - from) / span
	var across := Vector2(-along.y, along.x)
	var salt := 1 if candidate == 0 else 40 + candidate * 3
	var reach := WOBBLE_SHARE if candidate == 0 else DETOUR_SHARE
	var bend := (_roll(id, salt) * 2.0 - 1.0) * span * reach
	var phase := _roll(id, salt + 1) * TAU
	var lean := 0.7 + _roll(id, salt + 2) * 1.1
	var points := PackedVector2Array()
	for step in steps + 1:
		var share := float(step) / float(steps)
		var offset := bend * sin(PI * share) * sin(phase + PI * share * lean)
		points.append(from + along * (span * share) + across * offset)
	return points


## How much of a line is too steep to be a road: the rise past what a character
## can walk, squared and summed over the line's own steps. Zero on any line with
## nothing steep on it, which is almost every line in a world without mountains.
##
## Measured on the carved bed rather than on the finished ground, because the
## finished ground is what the roads are about to do to it, and asking would be
## asking a question of an answer that does not exist yet.
func _route_cost(line: PackedVector2Array) -> float:
	var cost := 0.0
	var previous := water.bed_height_at(line[0].x, line[0].y)
	var at := line[0]
	for step in range(1, line.size()):
		var span := line[step - 1].distance_to(line[step])
		var substeps := maxi(1, int(ceil(span / ROUTE_SAMPLE_STEP)))
		for sub in range(1, substeps + 1):
			var next := line[step - 1].lerp(line[step], float(sub) / float(substeps))
			var height := water.bed_height_at(next.x, next.y)
			var allowed := ROUTE_GRADE_LIMIT * at.distance_to(next)
			var climbed := absf(height - previous) - allowed
			if climbed > 0.0:
				cost += climbed * climbed
			previous = height
			at = next
	return cost


# --- What a road does to the ground --------------------------------------

## The nearest point of any road to a position, or an empty dictionary when
## there is none within reach.
##
## Returns {distance, strength, at, along}: how far the road is, how much of its
## carving applies here, the point on the road itself, and the direction the road
## runs in there. Everything the ground and the render layer want to know about
## a road at a position is read off this.
func road_at(x: float, z: float) -> Dictionary:
	return _nearest_segment(x, z, road_edge())


## The nearest stretch of road within a cutoff, as {distance, strength, at,
## along}, or an empty dictionary when there is none. Both road_at() and the
## verge query above are this walk with different cutoffs.
func _nearest_segment(x: float, z: float, cutoff: float) -> Dictionary:
	var segments := _segments_near(x, z)
	if segments.is_empty():
		return {}
	var here := Vector2(x, z)
	var best := INF
	var best_at := Vector2.ZERO
	var best_along := Vector2.RIGHT
	var at := 0
	while at + 1 < segments.size():
		var point := _closest_on(segments[at], segments[at + 1], here)
		var away := here.distance_to(point)
		if away < best:
			best = away
			best_at = point
			var span := segments[at + 1] - segments[at]
			best_along = span.normalized() if span.length_squared() > 0.0 \
				else Vector2.RIGHT
		at += 2
	if best > cutoff:
		return {}
	return {
		"distance": best,
		"strength": 1.0 - smoothstep(PATH_HALF_WIDTH, road_edge(), best),
		"at": best_at,
		"along": best_along,
	}


## How far from a road's centreline its carving still reaches.
static func road_edge() -> float:
	return PATH_HALF_WIDTH + PATH_FEATHER


static func _closest_on(start: Vector2, finish: Vector2, point: Vector2) -> Vector2:
	var span := finish - start
	var length_squared := span.length_squared()
	if length_squared <= 0.0:
		return start
	return start + span * clampf(
		(point - start).dot(span) / length_squared, 0.0, 1.0
	)


## How far outside the carving's own reach a road can still be asked about.
##
## road_at() stops at the edge of the carving, because that is all the ground
## needs to know. The scatter layer needs a little more: a fence stands *beside*
## a road rather than on it, and "beside" is a couple of steps past where the
## carving stops. This is how far past, and it is not a free choice -- the
## segments a query walks are gathered per tile of the lookup lattice, and a
## tile only gathers what can reach this far into it. Asking further would get
## an answer that depended on which tile the position fell in.
const SIDE_REACH := TILE_MARGIN - TILE * 0.708


## The nearest stretch of road within SIDE_REACH, or an empty dictionary.
##
## The same walk over the same memoised segments road_at() does, with the cutoff
## moved out to the verge: {distance, at, along}. What the scatter layer lines a
## fence up with, and what it measures "near a path" against.
func road_beside(x: float, z: float) -> Dictionary:
	return _nearest_segment(x, z, SIDE_REACH)


## How far the nearest road is, or INF when there is none within SIDE_REACH.
func distance_to_road(x: float, z: float) -> float:
	var road := road_beside(x, z)
	return INF if road.is_empty() else float(road["distance"])


## How much of a road's carving applies at a position, in [0, 1]. Zero almost
## everywhere.
func strength_at(x: float, z: float) -> float:
	var road := road_at(x, z)
	if road.is_empty():
		return 0.0
	return float(road["strength"])


## How many roads have any of their carving over a position.
##
## One almost everywhere: a road is a thin thing, and the graph joins two places
## only when no third lies between them, so two roads reach the same ground only
## where they converge on a place they both end at. Where that happens the
## levelling stands off -- see level_strength_at() -- and the ground under the
## converging tracks is the land's own rather than a roadway levelled to one
## centreline or blended between two.
##
## It is the same walk the levelling does, over the same tile, so it answers for
## the carving rather than about it.
func roads_over(x: float, z: float) -> int:
	var tile := _tile_near(x, z)
	var segments: PackedVector2Array = tile["segments"]
	var owners: PackedInt32Array = tile["owners"]
	var here := Vector2(x, z)
	var reach := road_edge()
	var found := {}
	var at := 0
	while at + 1 < segments.size():
		var point := _closest_on(segments[at], segments[at + 1], here)
		if here.distance_to(point) <= reach:
			found[owners[at / 2]] = true
		at += 2
	return found.size()


## How far the ground has to move at a position for the roads to be carved into
## it, given the ground height `level` it is at with the villages already
## levelled but no road cut yet.
##
## Two separate things are done to the ground, and keeping them apart is what
## makes a road walkable.
##
## **The trough.** The ground is dropped by PATH_DEPTH wherever any road runs
## over it, faded out at the verge by that road's own share. This is the road as
## a worn thing, and it is applied whether one road is here or three.
##
## **The levelling.** The ground is moved to the height of the road's centreline
## rather than of the land it is standing on. That flattens *across* the road
## rather than along it: a cart track is level from verge to verge and still
## climbs the hill it is crossing, which is what a worn road does and what a road
## cut to a fixed grade does not.
##
## The levelling is a claim about *one* centreline, and it is applied only where
## one road is making it. The height comes from the nearest road and nothing
## else, and it is faded out by how much a second road's carving reaches the
## same ground, so that where two tracks converge the levelling is off and the
## ground is the land's own.
##
## That rule is the whole of why the finished roadway is walkable. On any road's
## own centreline the nearest road is that road at zero distance, so the height
## it levels to is the height it is already at: the roadway is the land under it,
## lowered by the depth of the trough, and it climbs exactly what the land
## climbs. The routing has already refused to lay a road up land steeper than a
## character can step, so nothing the carving does can put a wall in the middle
## of a road.
##
## What it replaces was a share-weighted *blend* of every centreline within
## reach. On a lone road the two are the same, because both verges have the same
## nearest point, and this function returns the same number it always did there.
## Where roads converge they are not the same: the blend levelled that ground to
## a mixture of two centrelines standing at two heights, which on flat country is
## invisible and on a mountain shoulder left the roadway out of level across its
## own width by up to 0.95 units against the 0.30 it is worn in, and put four
## steps of finished road on seed 1234 over the climb a character can make.
func ground_delta_at(x: float, z: float, level: float) -> float:
	# A road never touches water: the crossing is the bridge's job, and carving
	# here would cut a notch in a river bank or drain the river itself.
	if water.is_water_at(x, z):
		return 0.0
	var carving := _carving_at(x, z)
	if carving.is_empty():
		return 0.0
	var owned: float = carving["owned"]
	var at: Vector2 = carving["at"]
	var flattened := 0.0
	if owned > 0.0:
		flattened = (_ground_before_roads(at.x, at.y) - level) * owned
	return flattened - PATH_DEPTH * float(carving["strength"])


## The road that owns the ground at a position: {at, strength, owned}, or an
## empty dictionary where no road's carving reaches it.
##
## `at` is the nearest point of the nearest road, which is the one centreline
## the ground here is levelled to. `strength` is how much of that road's carving
## reaches -- the depth of the trough. `owned` is that share less the next
## road's, which is how much of the levelling applies: one where a single road
## runs over the ground, nought where two tracks converge and neither can claim
## to be the road the ground is level with.
##
## A road whose nearest point is in the water is not here at all. Its carving
## stopped at the bank and the bridge took over, so it neither levels this ground
## nor stops another road from levelling it.
func _carving_at(x: float, z: float) -> Dictionary:
	var tile := _tile_near(x, z)
	var segments: PackedVector2Array = tile["segments"]
	if segments.is_empty():
		return {}
	var owners: PackedInt32Array = tile["owners"]
	var here := Vector2(x, z)
	var reach := road_edge()

	# The nearest point of *each* road within reach, not of each segment. That
	# distinction is the whole of whether a roadway is level across itself. A
	# road is a polyline, and near a bend in it two of its own segments are both
	# within reach with their closest points several units apart along the
	# centreline; taking the nearer segment under the left verge and the further
	# one under the right would level the two verges to two places on the same
	# centreline, and on a mountain shoulder, where it climbs a unit every two
	# walked, that is a step down the middle of the track. Taking one point per
	# road removes it: both verges project to nearly the same place.
	var nearest := {}
	var at := 0
	while at + 1 < segments.size():
		var owner := owners[at / 2]
		var point := _closest_on(segments[at], segments[at + 1], here)
		at += 2
		var away := here.distance_to(point)
		if away > reach:
			continue
		if nearest.has(owner) and float(nearest[owner]["away"]) <= away:
			continue
		nearest[owner] = {"away": away, "at": point}

	var best := 0.0
	var second := 0.0
	var best_at := Vector2.ZERO
	for owner in nearest:
		var point: Vector2 = nearest[owner]["at"]
		if water.is_water_at(point.x, point.y):
			continue
		var share := 1.0 - smoothstep(
			PATH_HALF_WIDTH, reach, float(nearest[owner]["away"])
		)
		if share > best:
			second = best
			best = share
			best_at = point
		elif share > second:
			second = share
	if best <= 0.0:
		return {}
	return {"at": best_at, "strength": best, "owned": best - second}


## How much of the ground at a position is levelled by one road alone, in
## [0, 1]: the nearest road's share of the carving less the next road's.
##
## One over a road running on its own, which is almost everywhere a road runs.
## Nought where two tracks converge on a place they both end at, which is the
## only way two roads reach the same ground -- the graph joins two places only
## when no third lies between them, so roads meet at their ends and nowhere
## else. Between the two it is a fade, and over that fade the ground goes back to
## being the land's own rather than a roadway levelled to anybody's centreline.
##
## strength_at() answers how much road is over the ground, which is what its
## colour and the scatter want. This answers how much of the ground is a levelled
## roadway, which is what a claim about a road being level across its width has
## to be asked of.
func level_strength_at(x: float, z: float) -> float:
	if water.is_water_at(x, z):
		return 0.0
	var carving := _carving_at(x, z)
	return 0.0 if carving.is_empty() else float(carving["owned"])


## The ground a road is carved into: the carved bed with the villages levelled
## and nothing else. Asked rather than passed in, because the levelling along a
## road is measured at points other than the one being asked about.
func _ground_before_roads(x: float, z: float) -> float:
	var bed := water.bed_height_at(x, z)
	return bed + settlements.ground_delta_at(x, z, bed)


# --- Bridges -------------------------------------------------------------

## The bridges a road needs: one per run of water it crosses.
##
## The line is walked end to end and every stretch that is water becomes a
## crossing. A bridge is placed over the middle of it, turned to lie along the
## road, and reaching a little past each bank so that it lands on ground rather
## than on the waterline. Which bridge it is comes from how wide the crossing is
## -- a long span in timber reads as a jetty, so those get stone.
func _bridges_on(edge: Dictionary) -> Array:
	var points: PackedVector2Array = edge["points"]
	var walked := _walk(points, CROSSING_STEP)
	var bridges := []
	var run_start := -1
	for index in walked.size():
		var wet: bool = water.is_water_at(walked[index].x, walked[index].y)
		if wet and run_start < 0:
			run_start = index
		elif not wet and run_start >= 0:
			bridges.append_array(_bridge_over(walked, run_start, index - 1))
			run_start = -1
	if run_start >= 0:
		bridges.append_array(_bridge_over(walked, run_start, walked.size() - 1))
	return bridges


## The spans that carry a road over one run of water: a whole number of deck
## units laid end to end, each turned to lie along the crossing and each sitting
## at the same height above the water it crosses.
func _bridge_over(walked: PackedVector2Array, first: int, last: int) -> Array:
	var start := walked[first]
	var finish := walked[last]
	var crossing := start.distance_to(finish)
	if crossing < BRIDGE_MIN_SPAN:
		return []
	var middle := (start + finish) * 0.5
	var along := (finish - start).normalized() if crossing > 0.0 else Vector2.UP
	var deck := crossing + 2.0 * BRIDGE_ABUTMENT
	var tag: String = AssetTags.BRIDGE_STONE if deck >= BRIDGE_STONE_SPAN \
		else AssetTags.BRIDGE_WOOD
	var units := maxi(1, int(round(deck / float(BRIDGE_UNIT[tag]))))
	var unit := deck / float(units)
	var height := water.surface_level_at(middle.x, middle.y) + BRIDGE_RISE
	# A bridge is drawn lying along its own +Z, so the yaw that points +Z along
	# the crossing is the crossing's bearing measured the same way.
	var yaw := atan2(along.x, along.y)
	var spans := []
	for index in units:
		var offset := (float(index) - float(units - 1) * 0.5) * unit
		var at := middle + along * offset
		spans.append({
			"tag": tag,
			"x": at.x,
			"z": at.y,
			"yaw": yaw,
			"span": unit,
			"height": height,
		})
	return spans


# --- Dressing ------------------------------------------------------------

## What lines a road: a signpost where it leaves a village, and lantern posts
## along the lit stretch nearest one. Lanterns alternate sides, which is what
## keeps a road from looking like a runway.
func _dressing_on(edge: Dictionary, from_place: Dictionary, to_place: Dictionary) -> Array:
	var points: PackedVector2Array = edge["points"]
	var walked := _walk(points, 1.0)
	if walked.size() < 3:
		return []
	var props := []
	for end in [
		{"place": from_place, "from_start": true},
		{"place": to_place, "from_start": false},
	]:
		var place: Dictionary = end["place"]
		if String(place["kind"]) != "settlement":
			continue
		var from_start: bool = end["from_start"]
		var signpost := _point_along(walked, SIGNPOST_AT, from_start)
		if not signpost.is_empty():
			props.append({
				"tag": AssetTags.SIGNPOST,
				"x": float(signpost["x"]),
				"z": float(signpost["z"]),
				"yaw": float(signpost["yaw"]),
			})
		var lit := SIGNPOST_AT
		var side := 1.0
		while lit <= LIT_LENGTH:
			var lantern := _point_along(walked, lit, from_start)
			lit += LANTERN_SPACING
			side = -side
			if lantern.is_empty():
				continue
			var yaw := float(lantern["yaw"])
			var across := Vector2(cos(yaw), -sin(yaw)) * side * (PATH_HALF_WIDTH + 0.7)
			props.append({
				"tag": AssetTags.LANTERN_POST,
				"x": float(lantern["x"]) + across.x,
				"z": float(lantern["z"]) + across.y,
				"yaw": yaw,
			})
	return props


## A point a given distance along a road from one of its ends, or an empty
## dictionary when the road is not that long. Dry ground only: nothing is stood
## in a river.
func _point_along(walked: PackedVector2Array, distance: float, from_start: bool) -> Dictionary:
	var steps := int(round(distance))
	var index := steps if from_start else walked.size() - 1 - steps
	if index < 1 or index >= walked.size() - 1:
		return {}
	var here := walked[index]
	if water.is_water_at(here.x, here.y):
		return {}
	var along := (walked[index + 1] - walked[index - 1]).normalized()
	return {"x": here.x, "z": here.y, "yaw": atan2(along.x, along.y)}


# --- The lookup lattice --------------------------------------------------

## The road segments that can reach into a tile, as endpoint pairs. Worked out
## once per tile, because the ground asks about roads once per terrain vertex
## and rebuilding the graph each time would be absurd.
func _segments_near(x: float, z: float) -> PackedVector2Array:
	return _tile_near(x, z)["segments"]


## Everything a tile knows about the roads that reach into it: the segments as
## endpoint pairs, and which road each segment belongs to.
##
## The owner is a number local to the tile -- two tiles do not agree about which
## road is road 3, and nothing needs them to. All it has to do is say "these two
## segments are the same road as each other", which is what levelling a roadway
## across its own width needs and what a flat list of segments cannot say.
func _tile_near(x: float, z: float) -> Dictionary:
	var tile := tile_at(x, z)
	if _tiles.has(tile):
		return _tiles[tile]
	var built := _build_tile(tile)
	if _tiles.size() >= MEMO_LIMIT:
		_tiles.clear()
	_tiles[tile] = built
	return built


func _build_tile(tile: Vector2i) -> Dictionary:
	var centre := Vector2(
		(float(tile.x) + 0.5) * TILE, (float(tile.y) + 0.5) * TILE
	)
	var segments := PackedVector2Array()
	var owners := PackedInt32Array()
	var owner_of := {}
	for place in places_near(centre.x, centre.y, LINK_RADIUS + TILE_MARGIN):
		for edge in edges_from(place):
			var id := String(edge["id"])
			if not owner_of.has(id):
				owner_of[id] = owner_of.size()
			var points: PackedVector2Array = edge["points"]
			for at in points.size() - 1:
				if _segment_distance(points[at], points[at + 1], centre) > TILE_MARGIN:
					continue
				segments.append(points[at])
				segments.append(points[at + 1])
				owners.append(int(owner_of[id]))
	return {"segments": segments, "owners": owners}


## How far a position is from the nearest point of a road.
static func distance_to_edge(edge: Dictionary, x: float, z: float) -> float:
	var points: PackedVector2Array = edge["points"]
	var here := Vector2(x, z)
	var best := INF
	for at in points.size() - 1:
		best = minf(best, _segment_distance(points[at], points[at + 1], here))
	return best


static func _segment_distance(start: Vector2, finish: Vector2, point: Vector2) -> float:
	var span := finish - start
	var length_squared := span.length_squared()
	if length_squared <= 0.0:
		return point.distance_to(start)
	var share := clampf((point - start).dot(span) / length_squared, 0.0, 1.0)
	return point.distance_to(start + span * share)


## A polyline resampled at a fixed step, so that walking along a road is walking
## at a known speed rather than at whatever speed its corners happen to be at.
static func _walk(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var walked := PackedVector2Array()
	if points.size() < 2:
		return walked
	var carry := 0.0
	walked.append(points[0])
	for at in points.size() - 1:
		var start := points[at]
		var finish := points[at + 1]
		var span := start.distance_to(finish)
		if span <= 0.0:
			continue
		var along := (finish - start) / span
		var travelled := step - carry
		while travelled <= span:
			walked.append(start + along * travelled)
			travelled += step
		carry = span - (travelled - step)
	walked.append(points[points.size() - 1])
	return walked


func _roll(id: String, salt: int) -> float:
	var hashed := 0x811C9DC5
	for at in id.length():
		hashed = ((hashed ^ id.unicode_at(at)) * 0x01000193) & SimRng.MASK
	return SimRng.hash_unit(world_seed + PATH_SEED_OFFSET + salt * SALT_STRIDE, hashed, salt)
