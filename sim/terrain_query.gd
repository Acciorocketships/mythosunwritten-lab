extends RefCounted
## Everything the rest of the project asks about a patch of ground.
##
## The generation stack is a pile of fields -- height, biome, water, floating
## islands, and later settlements and scatter -- and almost nobody who wants an answer
## wants to know which field it came from. The mesher wants the height of the
## ground it is going to draw, which is the height field *after* the water has
## cut its channels into it. The tactical layer will want to know whether a cell
## is standable. The prop layer will want to know where the water's edge is. All
## three would otherwise have to know the stack's shape and recompute its
## arithmetic, and would drift apart the first time a layer changed.
##
## So this is the one place that composes them, and the one surface the rest of
## the project reads the ground through. It decides nothing: every answer here
## is a field's answer, forwarded or combined. It holds no state that sampling
## changes, so it inherits the purity of the fields under it -- an answer depends
## on the position and the world seed and on nothing else.
class_name TerrainQuery

## The seed the whole stack descends from.
var world_seed: int = 0

## The uncarved ground: the shape of the land before water is cut out of it.
var surface_field: TerrainSurfaceField = null

## Which biome the ground is, and what that biome looks like.
var biome_field: BiomeField = null

## Where the rivers, ponds and lakes are, and how deep.
var water_field: WaterField = null

## Where the floating islands are: the aerial layer over all of the above.
var island_field: IslandField = null

## Where the villages are, and what stands in them.
var settlement_field: SettlementField = null

## Which places the roads join, and where those roads run.
var path_network: PathNetwork = null

## How far up ordinary movement can carry someone in one go, in world units.
##
## This is the whole of how traversal reaches an island, and it is why an island
## is placed where it is: IslandField puts every aerial island's rim between
## AERIAL_LIFT_MIN and AERIAL_LIFT_MAX above the highest ground under its own
## footprint, and both of those are below this. So every island has at least one
## place along its rim where it is one hop up from the ground it overhangs, and
## walking into that place carries you onto it -- no jump check, no bridge, no
## lift. Everywhere else the island is out of reach overhead, which is what a
## floating island should feel like from underneath. The reasoning is written up
## in reports/islands.md.
const HOP_HEIGHT := 3.0

## How far *down* a surface can be and still be the thing you are standing on,
## in world units.
##
## Without this there would be no such thing as a hole: the ground twenty units
## below the edge of a floating island is a surface, and "the highest surface
## below you" would happily answer with it, so nowhere on the aerial layer would
## ever be empty. A surface further down than this is a fall rather than a step,
## and a position with nothing within reach either way is a hole. It is set well
## above anything the ground itself does over one step -- the steepest slope the
## height field makes is under a unit per unit walked, and the deepest a river
## cuts its bank is 2.4 over several -- so it never turns ordinary walking into
## falling.
const DROP_REACH := 2.0

## How far above the local water surface the settlement layer must leave dry
## ground, in world units.
##
## Levelling a village and carving a road both move dry ground downwards, and
## without a floor a road running along a bank could dip under the water line
## and put a puddle in the middle of itself. This is that floor, and it is what
## makes "settlements never create or destroy water" true rather than merely
## intended: is_water_at() reads the water field alone and never sees this
## layer, so the layer must not be able to contradict it.
const SHORE_FLOOR := 0.05


## The whole stack for one seed. This is how a world, a test or a tool that has
## nothing but a seed gets a query that agrees with every other one.
static func for_seed(seed_value: int) -> TerrainQuery:
	var biomes := BiomeField.new(seed_value)
	var surface := TerrainSurfaceField.new(seed_value, biomes)
	var water := WaterField.new(surface, biomes)
	var islands := IslandField.new(water, biomes)
	var settlements := SettlementField.new(water, biomes, islands)
	return TerrainQuery.new(
		surface, biomes, water, islands, settlements, PathNetwork.new(settlements, water)
	)


func _init(
	surface: TerrainSurfaceField = null,
	biomes: BiomeField = null,
	water: WaterField = null,
	islands: IslandField = null,
	settlements: SettlementField = null,
	paths: PathNetwork = null,
) -> void:
	surface_field = surface
	world_seed = surface.world_seed if surface != null else 0
	biome_field = biomes if biomes != null else BiomeField.new(world_seed)
	water_field = water if water != null else WaterField.new(surface_field, biome_field)
	island_field = islands if islands != null else IslandField.new(water_field, biome_field)
	settlement_field = settlements if settlements != null \
		else SettlementField.new(water_field, biome_field, island_field)
	path_network = paths if paths != null \
		else PathNetwork.new(settlement_field, water_field)


## How high the ground is here: the height you would stand on, with the water's
## channels and basins already cut into it.
##
## This is the height the terrain is meshed at, so a river bed is a real dip in
## the geometry rather than a texture on a flat plain.
func ground_height_at(x: float, z: float) -> float:
	return water_column_at(x, z).x


## The water at a position with the settlement layer's shaping already in it:
## x = the height of the bed you would stand on, y = the height of the water
## surface.
##
## This is where the stack is actually composed, and the order is the order the
## layers were cut: the water carves the land, the villages level what they
## stand on, and the roads are worn into that. Two things it deliberately will
## not do. It never touches water -- a village is refused a wet site and a road
## stops at the bank -- so whether a position is water is the water field's
## answer alone and this layer cannot contradict it. And it never moves ground
## under a floating island, because an island's landing step was measured
## against the ground below its rim and moving that ground afterwards could put
## the island out of reach; a village is refused such a site anyway, so this only
## catches a road passing underneath one.
func water_column_at(x: float, z: float) -> Vector2:
	var column := water_field.sample_column(x, z)
	if column.y > column.x:
		return column
	var levelled := column.x + settlement_field.ground_delta_at(x, z, column.x)
	var shaped := levelled + path_network.ground_delta_at(x, z, levelled)
	if absf(shaped - column.x) < 0.00001:
		return column
	if island_field.walkable_island_over(x, z) != null:
		return column
	return Vector2(maxf(shaped, column.y + SHORE_FLOOR), column.y)


## How much of a road runs over a position, in [0, 1]. Zero almost everywhere.
## What the ground's colour is mixed by, and what the scatter layer will read to
## keep a fern out of a cart track.
func path_strength_at(x: float, z: float) -> float:
	if water_field.is_water_at(x, z):
		return 0.0
	return path_network.strength_at(x, z)


## The nearest stretch of road within reach of the verge, or an empty
## dictionary: {distance, strength, at, along}.
##
## path_strength_at() answers "how much road is under me", which is what the
## ground wants. This answers "where is the road from here", which is what the
## scatter layer wants -- a fence stands beside a road and lines up with it, and
## neither of those is a question about the ground it is standing on.
func road_beside(x: float, z: float) -> Dictionary:
	if water_field.is_water_at(x, z):
		return {}
	return path_network.road_beside(x, z)


## How far the nearest road is, or INF when there is none within the verge's
## reach. Zero almost nowhere, INF almost everywhere.
func road_distance_at(x: float, z: float) -> float:
	var road := road_beside(x, z)
	return INF if road.is_empty() else float(road["distance"])


## The village whose pad covers a position, or null.
func settlement_at(x: float, z: float) -> Settlement:
	return settlement_field.settlement_at(x, z)


## The building standing on a position, or an empty dictionary.
##
## The reservation the scatter layer asks about before it puts anything down.
func building_at(x: float, z: float, margin: float = 0.0) -> Dictionary:
	return settlement_field.building_at(x, z, margin)


## Whether a building stands on this position.
func is_reserved_at(x: float, z: float, margin: float = 0.0) -> bool:
	return settlement_field.is_reserved_at(x, z, margin)


## The uncarved height, before water. Wanted only by things reasoning about the
## carving itself; everything that wants "the ground" wants ground_height_at().
func base_height_at(x: float, z: float) -> float:
	return surface_field.height_at(x, z)


## Which way the ground faces here, taken from the carved ground by sampling a
## short step either side rather than from any particular triangle, so that
## neighbouring chunks agree along their shared edge -- and so that the sides of
## a river channel are as much a slope as the sides of a hill.
func normal_at(x: float, z: float, step: float = 0.5) -> Vector3:
	var dx := ground_height_at(x + step, z) - ground_height_at(x - step, z)
	var dz := ground_height_at(x, z + step) - ground_height_at(x, z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()


## Whether this position is water.
##
## With no height given, this is the ground's answer and nothing else: the water
## field's own, exactly as it always was.
##
## With a height given, it is the answer for **the storey you are standing on**.
## The world has more than one surface over a position now, and an island can
## carry a pond in a basin of its own, so "is there water here" needs to know
## which of them is meant. Standing on the ground under an island, the lake at
## your feet is the world's; standing on the island, it is the island's. Both
## come back through this one call, because both are the same fact -- there is
## no ground here, there is water -- and the tactical layer reads a hole in the
## board off `is_void_at`, which is written in terms of the same storeys.
func is_water_at(x: float, z: float, from_height: float = -INF) -> bool:
	if from_height != -INF:
		var island := _storey_at(x, z, from_height)
		if island != null:
			return island.holds_water_at(x, z)
	return water_field.is_water_at(x, z)


## How deep the water is on the storey reached from `from_height`, in world
## units. The ground's depth with no height given.
func water_depth_at_height(x: float, z: float, from_height: float) -> float:
	var island := _storey_at(x, z, from_height)
	if island != null:
		return island.pond_depth_at(x, z)
	return water_field.depth_at(x, z)


## The surface someone at `from_height` would come to rest on here even where
## there is nothing to stand on: the bed under the water rather than the water.
##
## `support_at` answers -INF over water, which is the right answer to "what am I
## standing on" and the wrong one to "where does something that is not stopped by
## water end up". On the ground that is the river bed; on an island with a pond
## it is the floor of the basin -- the island's own top, which is exactly the
## same statement one storey up. Reading it through the storey is what keeps the
## two the same rule: without it, wading into a pond forty units in the air would
## drop straight to the ground plane.
func wading_height_at(x: float, z: float, from_height: float) -> float:
	var island := _storey_at(x, z, from_height)
	if island != null:
		return island.top_height_at(x, z)
	return ground_height_at(x, z)


## The island whose top surface is the storey someone at `from_height` is on, or
## null when that is the ground.
##
## The island's top is what is compared against, whether or not it is under the
## island's own water: a pond is a hole in that storey, not a reason to fall
## through to the one below. That is the same rule the ground follows, where a
## lake is a hole in the ground rather than a way down to something else.
func _storey_at(
	x: float,
	z: float,
	from_height: float,
	hop: float = HOP_HEIGHT,
	drop: float = DROP_REACH,
) -> FloatingIsland:
	var ceiling := from_height + hop
	var floor_height := from_height - drop
	var best: FloatingIsland = null
	var best_height := water_column_at(x, z).x
	if best_height > ceiling or best_height < floor_height:
		best_height = -INF
	for island in island_field.walkable_islands_over(x, z):
		var top := island.top_height_at(x, z)
		if top <= ceiling and top >= floor_height and top >= best_height:
			best_height = top
			best = island
	return best


## Whether this position is a bank: dry ground with water within reach. Where
## the later layers put reeds and lily pads, and where a path that meets one
## becomes a bridge.
func is_bank_at(x: float, z: float) -> bool:
	return water_field.is_bank_at(x, z)


## How deep the water is here, in world units. Zero on dry land.
func water_depth_at(x: float, z: float) -> float:
	return water_field.depth_at(x, z)


## How high the water surface reaches here. Below the ground on dry land.
func water_surface_at(x: float, z: float) -> float:
	return water_field.surface_level_at(x, z)


## Every surface anyone could stand on above this position, lowest first.
##
## Usually one -- the ground -- and sometimes none, because water is not a
## surface. Over an aerial island there is a second one, the island's own top.
## This is the primitive the three answers below are read off, and it is what
## makes "the world is solid here" a single question with one answer whether the
## reason is water, a floating island, or both at once.
##
## The heights are full-width floats, not the narrower kind: a surface here is
## compared against a height someone is standing at, and rounding one of the two
## would turn standing on an island into hovering a fraction above it.
func surfaces_at(x: float, z: float) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	var column := water_column_at(x, z)
	if column.y <= column.x:
		found.append(column.x)
	# Every walkable storey over this position, already lowest first. Each is
	# above whatever it was placed over, because an island is only placed where
	# its underside clears what is below it -- so appending them keeps this list
	# in order.
	#
	# An island's own pond is left out for exactly the reason the world's water
	# is: water is not a surface. A basin with water in it is therefore a hole
	# in the aerial storey, answered by the same call that makes a lake a hole in
	# the ground, and read by the tactical layer through is_void_at() without
	# that layer ever having to hear the word "island".
	for island in island_field.walkable_islands_over(x, z):
		if island.holds_water_at(x, z):
			continue
		found.append(island.top_height_at(x, z))
	return found


## What you would be standing on at this position, coming from `from_height`:
## the highest surface within reach of it -- a hop up, or a step down.
##
## Returns -INF when there is nothing within reach: over open water, or off the
## edge of a floating island with the ground far below. That is the "hole"
## answer, and the wrappers below are only more readable names for it.
func support_at(
	x: float,
	z: float,
	from_height: float,
	hop: float = HOP_HEIGHT,
	drop: float = DROP_REACH,
) -> float:
	var ceiling := from_height + hop
	var floor_height := from_height - drop
	var best := -INF
	for surface in surfaces_at(x, z):
		if surface <= ceiling and surface >= floor_height and surface > best:
			best = surface
	return best


## Whether there is nothing to stand on here, coming from `from_height`.
##
## This is the hole in the tactical layer's board, and both of the design's
## holes answer through it. Standing on the ground beside a lake, the lake is a
## hole because water is not a surface. Standing on a floating island, the air
## off its edge is a hole because the ground is twenty units down and out of
## reach -- the void beneath the island, asked about from the island. Most
## pieces cannot enter either; the Frog leaps both; a unit on the lip of either
## can be shoved in.
func is_void_at(
	x: float,
	z: float,
	from_height: float,
	hop: float = HOP_HEIGHT,
	drop: float = DROP_REACH,
) -> bool:
	return support_at(x, z, from_height, hop, drop) == -INF


## How far you would fall from `from_height` here: the gap down to the surface
## you would land on, or INF over a hole -- nothing within reach at all.
##
## What a shove off a cliff edge or an island rim will be resolved against.
func drop_from(
	x: float,
	z: float,
	from_height: float,
	hop: float = HOP_HEIGHT,
	drop: float = DROP_REACH,
) -> float:
	var support := support_at(x, z, from_height, hop, drop)
	if support == -INF:
		return INF
	return maxf(0.0, from_height - support)


## Whether ordinary ground movement can cross this position, at ground level.
##
## Water is impassable: you do not walk into a lake. This is is_void_at() asked
## from the ground, so the overworld and the board cannot drift apart about
## where the world is solid, and so the void under a floating island reaches it
## for free -- a board laid on an island asks the same question from the
## island's height and gets a hole off its edge.
func is_passable_at(x: float, z: float) -> bool:
	return not is_void_at(x, z, ground_height_at(x, z))


## Every walkable island over this position, lowest first. Usually none;
## sometimes one; two where the aerial band's upper storey sits over its lower
## one. Far-sky islands are never returned: they are scenery, and nobody stands
## on scenery.
func islands_at(x: float, z: float) -> Array[FloatingIsland]:
	return island_field.walkable_islands_over(x, z)


## The highest walkable island over this position, or null.
func island_at(x: float, z: float) -> FloatingIsland:
	return island_field.walkable_island_over(x, z)


## Whether there is a walkable island overhead -- whether the world has a second
## storey here.
func is_over_island_at(x: float, z: float) -> bool:
	return island_field.walkable_island_over(x, z) != null


## How high the island's ground is here, or -INF where there is no island. This
## is the height above the ground plane the aerial layer adds.
func island_height_at(x: float, z: float) -> float:
	var island := island_field.walkable_island_over(x, z)
	if island == null:
		return -INF
	return island.top_height_at(x, z)


## The topmost walkable surface here: the island's if there is one, otherwise the
## ground's. What a camera follows and what a map draws.
func surface_height_at(x: float, z: float) -> float:
	var top := island_height_at(x, z)
	if top == -INF:
		return ground_height_at(x, z)
	return top


## Which biome this position resolves to.
func biome_at(x: float, z: float) -> String:
	return biome_field.biome_at(x, z)


## The blended look of this position, as plain data.
func profile_at(x: float, z: float) -> BiomeProfile:
	return biome_field.profile_at(x, z)


## The ground colour here, blended across whichever biomes have a share of it.
## The ground colour here, blended across whichever biomes have a share of it,
## and then mixed towards bare earth where a village has trodden it flat or a
## road has worn through it.
##
## The dirt is generated rather than decorated on: the mesher writes this into
## the chunk's vertex colours, so a road is part of the world's own description
## of itself and reproduces across processes like everything else. What shade of
## earth it is comes out of the biome catalog, so a track through a marsh is a
## darker track than one across a meadow.
func ground_tint_at(x: float, z: float) -> Color:
	var tint := biome_field.ground_tint_at(x, z)
	if water_field.is_water_at(x, z):
		return tint
	var road := path_network.strength_at(x, z)
	if road > 0.0:
		tint = tint.lerp(BiomeCatalog.path_tint_of(tint), road)
	var site := settlement_field.settlement_at(x, z)
	if site != null:
		tint = tint.lerp(
			BiomeCatalog.trodden_tint_of(tint), site.pad_weight(x, z)
		)
	return tint


## The colour water takes here, blended the same way -- bright in the meadow,
## dark and green under a canopy, near-black teal in a marsh.
func water_tint_at(x: float, z: float) -> Color:
	return biome_field.water_tint_at(x, z)


## Everything at once, for a caller that wants several of the answers above and
## would otherwise pay for the fields several times over.
##
## What comes back is a fresh dictionary of plain values, so a caller may keep
## it, edit it, or throw it away without any of that reaching the world.
func ground_at(x: float, z: float) -> Dictionary:
	var column := water_column_at(x, z)
	var is_water := column.y > column.x
	var island := island_field.walkable_island_over(x, z)
	var island_top := island.top_height_at(x, z) if island != null else -INF
	return {
		"x": x,
		"z": z,
		"height": column.x,
		"base_height": surface_field.height_at(x, z),
		"water": is_water,
		"water_surface": column.y,
		"water_depth": maxf(0.0, column.y - column.x),
		"bank": water_field.is_bank_at(x, z),
		"passable": not is_water,
		"biome": biome_field.biome_at(x, z),
		"path": path_strength_at(x, z),
		"reserved": is_reserved_at(x, z),
		"island": island != null,
		"island_height": island_top,
		"island_biome": island.biome if island != null else "",
		# Whether the island itself is under water here, and how deep. A basin
		# with a pond in it is the aerial layer's own hole in the board.
		"island_water": island != null and island.holds_water_at(x, z),
		"island_water_depth": island.pond_depth_at(x, z) if island != null else 0.0,
		"surface_height": island_top if island != null else column.x,
		# How far it is from the island's ground down to whatever is under it:
		# the depth of the void the tactical layer will read off its edge.
		"void_below_island": maxf(0.0, island_top - column.x) if island != null else 0.0,
	}
