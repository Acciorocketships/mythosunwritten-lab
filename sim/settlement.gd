extends RefCounted
## One village: where it stands, how level its ground is, and what is on it.
##
## This is plain data, in the same spirit as FloatingIsland. The settlement
## field decides all of it; this class only holds it and answers the two
## questions everyone else asks -- "is this position inside the village" and "is
## this position inside a building". It names asset tags and never a model: what
## a `house` looks like is the render layer's table's business.
##
## ## Buildings are whole placed units
##
## A building is a rectangle of reserved ground with a facing, and nothing else.
## There is no interior, no wall list and no procedural footprint: the layout
## picks a spot, turns the building to face the green, and reserves the ground
## it stands on. That reservation is the contract with the scatter layer that
## comes next -- it asks `building_at()` before it puts a fern somewhere, and a
## fern never grows through a floor.
##
## The rectangle is oriented, not axis-aligned, because the buildings are turned
## to face the middle of the village and an axis-aligned box around a turned
## house reserves the corners of a garden nobody built on. Two oriented
## rectangles are compared with the separating-axis test below, which is exact:
## either there is a line with all of one rectangle on one side and all of the
## other on the other, or the two overlap.
class_name Settlement

## Which lattice cell of the settlement field this village came out of. Its
## identity: there is at most one village per cell.
var cell := Vector2i.ZERO

## Where the middle of the village is, in world units, and how far its flattened
## ground reaches.
var centre_x := 0.0
var centre_z := 0.0
var radius := 0.0

## How far out the ground is flattened *exactly*. Between here and `radius` the
## pad eases back into the land it sits in, so a village has no shelf around it.
var core_radius := 0.0

## The height the flattened ground is levelled to, in world units.
var pad_height := 0.0

## Which biome the village stands in, and how many buildings it ended up with.
## The biome is what the render layer tints its placeholders from.
var biome := ""

## Whether this is the village the world starts you next to.
var is_spawn := false

## Whether this village was sited by the shore rule: it stands with standing
## water -- a pond or a lake -- reaching its pad, rather than on dry ground with
## the nearest water wherever the land happened to put it.
##
## It changes nothing about how the village is built. Every rule the layer
## enforces is enforced the same way on a shore village: the ground under it is
## levelled, its buildings reserve their footprints, none of them stands in
## water, and nothing hangs over it. This is here so that a survey can count
## them and a test can name one.
var is_shore := false

## The buildings, in placement order. Each is a dictionary:
##   tag         -- an AssetTags buildings tag
##   x, z        -- where its middle stands, in world units
##   yaw         -- which way it faces, in radians; 0 faces +Z
##   half_width  -- half its reserved ground across its own facing (local X)
##   half_depth  -- half its reserved ground along its own facing (local Z)
var buildings: Array[Dictionary] = []

## The dressing: fences, lantern posts, carts, stalls. Each is a dictionary of
## tag, x, z and yaw. Props reserve nothing -- they are small, and a tuft of
## grass beside a barrel is the look rather than a mistake.
var props: Array[Dictionary] = []

## The lit windows: one or two per building, on its facade. Each is a dictionary
##   tag       -- always the catalog's window_glow
##   x, z      -- the facade point, in world units
##   yaw       -- which way the window looks, in radians; the outward normal of
##                the face it is on, in the same convention as a building's
##   building  -- the index into `buildings` of the one it belongs to
##
## They are their own list rather than props because a glow is not dressing: it
## belongs to a building, it is placed from that building's own footprint and
## facing, and the index says which one -- which is what lets whoever draws it
## fit the point onto the wall of the model that actually stands there. Like a
## prop it reserves nothing.
var glows: Array[Dictionary] = []


## A stable name for this village, used as a node id in the path graph.
func id() -> String:
	return "s%d,%d" % [cell.x, cell.y]


## Whether a position is inside the village's flattened ground.
func covers(x: float, z: float) -> bool:
	return Vector2(x - centre_x, z - centre_z).length() <= radius


## How far a position is from the village's pad, zero when it is on it.
func distance_to(x: float, z: float) -> float:
	return maxf(0.0, Vector2(x - centre_x, z - centre_z).length() - radius)


## How much of the pad's flattening applies at a position, in [0, 1]: all of it
## inside the core, none of it beyond the rim, and a smooth ramp between.
func pad_weight(x: float, z: float) -> float:
	var away := Vector2(x - centre_x, z - centre_z).length()
	if away <= core_radius:
		return 1.0
	if away >= radius:
		return 0.0
	return 1.0 - smoothstep(core_radius, radius, away)


## The building whose reserved ground contains a position, or an empty
## dictionary. `margin` widens every footprint, which is how a caller asks for
## "inside a building or right up against one".
##
## This is the question the scatter layer asks, and the reason footprints are
## reserved at all.
func building_at(x: float, z: float, margin: float = 0.0) -> Dictionary:
	for building in buildings:
		if footprint_contains(building, x, z, margin):
			return building
	return {}


## Whether any building's reserved ground contains a position.
func is_reserved_at(x: float, z: float, margin: float = 0.0) -> bool:
	return not building_at(x, z, margin).is_empty()


## Whether a footprint contains a position, in the footprint's own frame.
static func footprint_contains(
	building: Dictionary, x: float, z: float, margin: float = 0.0
) -> bool:
	var local := footprint_local(building, x, z)
	return absf(local.x) <= float(building["half_width"]) + margin \
		and absf(local.y) <= float(building["half_depth"]) + margin


## A world position in a footprint's own frame: x across its facing, y along it.
static func footprint_local(building: Dictionary, x: float, z: float) -> Vector2:
	var yaw := float(building["yaw"])
	var away := Vector2(x - float(building["x"]), z - float(building["z"]))
	# The axes a yaw of `yaw` turns the local ones onto. Local +Z is the way the
	# building faces, which is the convention the render layer's placeholders
	# are drawn in -- a bridge is laid along +Z and a house's door is on +Z.
	var across := Vector2(cos(yaw), -sin(yaw))
	var along := Vector2(sin(yaw), cos(yaw))
	return Vector2(away.dot(across), away.dot(along))


## The four corners of a footprint, in world units.
static func footprint_corners(
	building: Dictionary, margin: float = 0.0
) -> PackedVector2Array:
	var yaw := float(building["yaw"])
	var centre := Vector2(float(building["x"]), float(building["z"]))
	var across := Vector2(cos(yaw), -sin(yaw)) * (float(building["half_width"]) + margin)
	var along := Vector2(sin(yaw), cos(yaw)) * (float(building["half_depth"]) + margin)
	var corners := PackedVector2Array()
	corners.append(centre - across - along)
	corners.append(centre + across - along)
	corners.append(centre + across + along)
	corners.append(centre - across + along)
	return corners


## Whether two footprints overlap, widened by `margin` each.
##
## The separating-axis test, which for two rectangles is four axes: each one's
## two edge directions. If the two projections are disjoint on any of them there
## is a line between the rectangles and they do not touch; if none separates
## them, they overlap. This is exact rather than a circle approximation, which
## matters because the layout packs buildings shoulder to shoulder around a
## green and a circle around a long house would refuse most of the ring.
static func footprints_overlap(
	first: Dictionary, second: Dictionary, margin: float = 0.0
) -> bool:
	var a := footprint_corners(first, margin * 0.5)
	var b := footprint_corners(second, margin * 0.5)
	for pair in [[a, b], [b, a]]:
		var shape: PackedVector2Array = pair[0]
		var other: PackedVector2Array = pair[1]
		for edge in 2:
			var axis := (shape[edge + 1] - shape[edge]).normalized()
			if _separated_on(axis, shape, other):
				# A line with one rectangle wholly on each side: they do not
				# touch, and no other axis can change that.
				return false
	return true


static func _separated_on(
	axis: Vector2, first: PackedVector2Array, second: PackedVector2Array
) -> bool:
	var first_low := INF
	var first_high := -INF
	for corner in first:
		var at := axis.dot(corner)
		first_low = minf(first_low, at)
		first_high = maxf(first_high, at)
	var second_low := INF
	var second_high := -INF
	for corner in second:
		var at := axis.dot(corner)
		second_low = minf(second_low, at)
		second_high = maxf(second_high, at)
	return second_low > first_high or first_low > second_high


## The largest distance from the middle of the village to anything belonging to
## it: the pad, or a building that sticks out past it.
func max_reach() -> float:
	var reach := radius
	for building in buildings:
		var away := Vector2(
			float(building["x"]) - centre_x, float(building["z"]) - centre_z
		).length()
		reach = maxf(reach, away + Vector2(
			float(building["half_width"]), float(building["half_depth"])
		).length())
	return reach


## A detached copy: same values, no shared storage. The same reason chunk
## geometry has one -- a viewer is handed one of these and must not be able to
## edit the village the world is standing in.
func detached_copy() -> Settlement:
	var copy := Settlement.new()
	copy.cell = cell
	copy.centre_x = centre_x
	copy.centre_z = centre_z
	copy.radius = radius
	copy.core_radius = core_radius
	copy.pad_height = pad_height
	copy.biome = biome
	copy.is_spawn = is_spawn
	copy.is_shore = is_shore
	for building in buildings:
		copy.buildings.append(building.duplicate())
	for prop in props:
		copy.props.append(prop.duplicate())
	for glow in glows:
		copy.glows.append(glow.duplicate())
	return copy


## A short, stable fingerprint of this village.
##
## Everything that decides where a thing stands is in here, at fixed precision,
## in placement order. Two villages with the same fingerprint are the same
## village for every purpose the determinism tests care about -- which is how a
## test shows that a village straddling a chunk border is the same village
## whichever of its chunks was built first.
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("cell=%d,%d" % [cell.x, cell.y])
	parts.append("at=%.4f,%.4f,%.4f,%.4f,%.4f" % [
		centre_x, centre_z, radius, core_radius, pad_height,
	])
	parts.append("biome=%s spawn=%d shore=%d" % [
		biome, 1 if is_spawn else 0, 1 if is_shore else 0,
	])
	for building in buildings:
		parts.append("b:%s,%.4f,%.4f,%.4f,%.3f,%.3f" % [
			building["tag"], building["x"], building["z"], building["yaw"],
			building["half_width"], building["half_depth"],
		])
	for prop in props:
		parts.append("p:%s,%.4f,%.4f,%.4f" % [
			prop["tag"], prop["x"], prop["z"], prop["yaw"],
		])
	for glow in glows:
		parts.append("g:%s,%.4f,%.4f,%.4f,%d" % [
			glow["tag"], glow["x"], glow["z"], glow["yaw"], glow["building"],
		])
	return "|".join(parts).sha256_text().substr(0, 16)
