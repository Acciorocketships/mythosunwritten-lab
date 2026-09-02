extends RefCounted
## Where the world's villages are, what stands in them, and how level their
## ground is: the settlement layer of the generation stack.
##
## It sits over the height, the biomes, the water and the floating islands, and
## like the islands it is a *sparse* field -- most of the world has no village
## anywhere near it. So it works on a lattice of cells, each of which holds at
## most one village, decided by a hash of the cell and the world seed. Nothing is
## drawn from a stream and nothing depends on what has been asked before, so a
## village is the same village whichever chunk asked about it, in what order, and
## in which process.
##
## A second, finer lattice holds *landmarks*: a stone circle, a roadside
## signpost, a campfire in a clearing. They are not settlements -- nothing is
## flattened and nothing is reserved -- but they are places worth walking to, and
## they are what the path graph strings the roads between when villages are far
## apart.
##
## ## The placement rule
##
## Section 13 of the design lists "settlement placement rule (density, biome
## gating, spacing from spawn)" as open. This file is the answer, and
## reports/settlements.md is the reasoning. In short:
##
## * **Density.** One candidate per SITE_CELL square, and SITE_CHANCE of those
##   cells want a village at all, before gating. That fixes the *most* villages
##   a stretch of world can hold at one per cell, so two villages can never grow
##   into one another, and it makes density a number rather than an accident.
## * **Biome gating.** The same roll is compared against a threshold that is
##   scaled by the biome under the candidate. A meadow takes almost every roll,
##   a highland few, and a twilight marsh none at all -- which is the design's
##   "eerie pocket you come across" rather than somewhere people live. Because
##   it is one roll with a moving threshold rather than a second roll, gating
##   thins the villages out instead of shuffling which cells hold them.
## * **Spacing from spawn.** The cell the world origin falls in always wants a
##   village, and its candidates are placed on a ring at SPAWN_RING_MIN to
##   SPAWN_RING_MAX from the origin rather than jittered anywhere in the cell.
##   So you never open your eyes inside the village and you are never more than a
##   short walk from it.
##
## Then the ground has to agree: a site is refused unless its whole pad is dry,
## flat enough to level without a visible shelf, and clear of anything overhead.
##
## ## What "flattened" means here
##
## The pad is levelled to the average ground height over its own footprint, in
## full out to `core_radius` and easing back to the untouched land by `radius`.
## Levelling to the average rather than to a chosen height is what keeps a
## village sitting *in* the land rather than on a plinth cut into it.
class_name SettlementField

# --- Where villages are --------------------------------------------------

## World units across one cell of the settlement lattice. One village at most
## per cell, so this and the chance below are the density.
##
## The lattice is centred on the world origin rather than cornered on it -- cell
## (0, 0) spans SITE_CELL/2 either side of the origin -- so that the starting
## village, which is the one village placed relative to the origin rather than to
## its cell, still falls inside the cell that owns it. That is what keeps "look
## in the cells near you" a complete answer to "what villages are near me".
const SITE_CELL := 260.0

## How many cells want a village, before the biome and the ground have their
## say. Many are then refused, so the density that survives is lower -- measured
## and written down in reports/settlements.md.
const SITE_CHANCE := 0.72

## How the biome scales that chance. A village is a warm-light social hub, and
## where people settle is a statement about the place: open meadow first,
## blossom groves nearly as often, forest clearings less, windswept highland
## rarely, and the twilight marsh never -- it is the design's eerie pocket, and
## putting a market square in one would spend the mood for nothing.
const BIOME_SHARE := {
	BiomeCatalog.MEADOW: 1.0,
	BiomeCatalog.BLOSSOM_GROVE: 0.85,
	BiomeCatalog.DEEP_FOREST: 0.45,
	BiomeCatalog.HIGHLAND: 0.28,
	BiomeCatalog.TWILIGHT_MARSH: 0.0,
}

## How many positions inside a cell are tried before the cell is given up on.
## A cell that wants a village usually has somewhere in it flat and dry enough;
## trying a handful of spots is what turns "this cell wants one" into "this cell
## has one" often enough for the density above to mean something.
const SITE_ATTEMPTS := 5

## How many the starting village gets. Far more, because there is exactly one of
## it in the whole world and a world that opened with no village near the origin
## would be missing the thing the first walk is for. The bearings are stepped by
## the golden angle so that twenty attempts really do go all the way round the
## ring rather than clustering.
const SPAWN_ATTEMPTS := 24

## How much the starting village shrinks on each further sweep of the ring when
## no site on it would take a village of the full size.
##
## The world always starting within a walk of a village is a property worth
## having outright rather than nine times in ten, and the only gate that ever
## refuses every bearing is the relief one -- which a smaller pad passes, because
## the ground rises and falls less across less of it. So the starting village is
## allowed to be a hamlet where the country is broken. Nothing else is relaxed:
## it still has to be dry, unroofed and out of the marsh.
const SPAWN_SHRINK := [1.0, 0.76, 0.58]

## The golden angle, in radians: the step that spreads a sequence of bearings
## most evenly without ever repeating one.
const GOLDEN_ANGLE := 2.39996323

## How far into its cell a candidate may be jittered, as a share of the cell.
## Kept off the cell edges so two villages in neighbouring cells stay at least
## half a cell apart, which is far more than either one is wide.
const JITTER_LOW := 0.25
const JITTER_HIGH := 0.75

## How far from the world origin the starting village stands. Near enough to
## find on the first walk, far enough that the world is discovered rather than
## handed over.
const SPAWN_RING_MIN := 62.0
const SPAWN_RING_MAX := 104.0

# --- How big a village is ------------------------------------------------

## How far a village's flattened ground reaches, in world units.
const PAD_RADIUS_MIN := 30.0
const PAD_RADIUS_MAX := 36.0

## How much of that radius is levelled exactly, the rest being the ramp back
## into the land. Everything built stands inside the levelled part, so a house
## never has one corner on a slope.
const PAD_CORE_SHARE := 0.74

## How much the ground may rise and fall under the *levelled* part of a
## candidate before the site is refused, in world units.
##
## Measured over the core rather than over the whole pad, because the core is
## what is cut level and the rest is a ramp that follows the land it is easing
## into. Levelling more relief than this would leave a cut bank on the uphill
## side and a plinth on the downhill one: half of it, spread over the ramp, is
## the steepest earthwork a village is allowed to stand on. Across a core of
## sixteen to nineteen units this refuses about two candidates in three, which is
## the largest single thinning in the placement rule.
const PAD_RELIEF_LIMIT := 5.6

## How the ground under a candidate is sampled. The coarse pass is what most
## candidates are refused by and is deliberately cheap; the fine pass runs only
## for the ones that survive it, and its outer rings carry more directions so
## that the rim -- where a river is most likely to clip a pad -- is sampled at a
## few units rather than at a few tens.
const PAD_COARSE_RINGS := [1, 8, 8]
const PAD_FINE_RINGS := [1, 8, 16, 24]

## How the ground between the levelled core and the pad's rim is checked for
## water. Only water is wanted out here -- the ramp follows whatever the land
## does -- so it is two rings rather than a filled disc.
const PAD_OUTER_RINGS := [24, 24]

## How many directions the ring just outside the pad is checked for water in.
const PAD_RIM_DIRECTIONS := 20

## How far from the pad's rim water must stay for the site to be accepted. A
## village likes a river nearby; it does not like standing in one, and this is
## also the room a water wheel needs on the bank.
const PAD_DRY_MARGIN := 3.0

# --- Villages that want a shore ------------------------------------------
#
# Everything above sites a village on dry ground and then refuses it if water
# comes anywhere near. That is a sound rule and it is why every village in this
# world stood tens of units back from the nearest water: the dry ring outside
# the rim is checked in twenty directions, so a pad is pushed away from a pond
# until the whole of it and a margin is clear.
#
# The design's third reference beat is amber windows and hanging lanterns
# mirrored in still water, and nothing in a world sited that way can be its
# subject. So a share of villages look for a shore *first*, under a different
# reading of the same rules:
#
# * The **levelled core** -- which is the only ground a building may stand on --
#   must still be dry, and must have a ring of dry ground round it as well.
# * The **outer ramp**, between the core and the rim, may be wet. It is the part
#   of the pad that eases back into the land rather than the part that is cut
#   level, and TerrainQuery never moves ground that is under water, so a pond
#   lapping into it stays exactly the pond the water field put there.
# * And there has to *be* a pond: standing water, not a river, because a river
#   runs in a gully two units below its banks and reflects the sky rather than
#   the village.
#
# Every village looks, rather than a rolled share of them. A share was tried and
# is the wrong shape for the idea: half a share of villages sitting twenty to
# forty units back from their own pond does not read as "these people did not
# want to live by the water", it reads as the dry rule having shoved them off
# the shore, which is exactly what it does. So the preference is not rolled --
# it is the ground that decides, and it grants a shore to about one village in
# four. That measured share is in reports/settlements.md and is held to a band by
# tests/test_settlements.gd.
#
# And a cell whose ground refuses every shore falls through to the ordinary
# dry-ground rule unchanged, having already run it: the shore rule *re-sites* a
# village and never creates one, so the layer's density is exactly what it was.

## How much dry ground a shore village keeps outside its levelled core, in world
## units. This is what stands in for PAD_DRY_MARGIN on a shore site: the core is
## dry by the same scan every village gets, and this is the band beyond it that
## has to be dry too, so a house on the outermost slot still has ground round it.
const SHORE_DRY_MARGIN := 3.0

## How far past the levelled core the water the village was sited for stands, in
## world units. Bigger than the dry margin above, which is what leaves a band of
## bank between the last building and the water.
const SHORE_STANDOFF := 5.0

## How far past the pad's rim the search for water still counts, in world units.
const SHORE_WATER_REACH := 5.0

## How the band between the dry margin and that reach is checked for water, and
## how many standing-water probes it takes for the site to count as a shore. One
## probe is a puddle; three on rings this far apart is a pond with a shore.
const SHORE_RINGS := 3
const SHORE_DIRECTIONS := 16
const SHORE_WET_MIN := 3

## How many probes across a cell the search for water uses, per side. The cell
## is 260 units and this is the grid laid over it, so a pond narrower than about
## twenty units across can be missed -- which is the right way round to be wrong,
## because a pond that small would be hidden behind the houses anyway.
const SHORE_PROBES := 12

## How many separate stretches of water in a cell are followed up, and how far
## apart two of them have to be to count as separate.
const SHORE_LEADS := 2
const SHORE_LEAD_APART := 60.0

## How the search walks out of the water to find its edge: how far it looks
## along one heading before giving up, and how finely it steps, both in world
## units. The reach is wide enough to cross a lake; the step is a fraction of the
## dry band the site test then insists on, so where the edge is found to a step's
## precision cannot cost a building its dry ground.
const SHORE_EDGE_REACH := 120.0
const SHORE_EDGE_STEP := 2.0

## How many bearings round a stretch of water are tried. Stepped by the golden
## angle from a hashed start, the same way the starting village sweeps its ring.
##
## Many more than an inland cell's five attempts, because most of them are spent
## before anything is measured: a bearing that puts the pad outside the middle
## half of the cell is dropped on one subtraction, and about five in six are. The
## ones that survive that cost what an inland candidate costs.
const SHORE_BEARINGS := 24

## How much a shore village shrinks on each further sweep when no bearing takes
## one of the full size.
##
## This is the gate that decides how many shore villages there are, and it is the
## relief limit doing it: the ground beside a pond is the rim of a basin, and
## across a full-size levelled core -- forty-seven units of it -- it rises and
## falls more than a village is allowed to cut. Measured on seed 1234, a
## full-size shore candidate passes the relief test about one time in twelve. A
## smaller pad crosses less of the rim and passes far more often, so a shore
## village is allowed to be a hamlet the same way the starting village is.
## Nothing else is relaxed: it is still dry where it builds, still levelled,
## still unroofed and still out of the marsh.
const SHORE_SHRINK := [1.0, 0.84, 0.70, 0.58]

# --- What stands in a village --------------------------------------------

## The plaza in the middle: the well, the fire and the stalls, and no houses.
## As a share of the pad's core radius.
const PLAZA_SHARE := 0.26

## How far out the first ring of buildings stands from the plaza's edge, and how
## much clear ground is kept inside the levelled rim so that a building's far
## corner is still on level ground.
const RING_GAP := 3.4
const BUILDING_INSET := 5.9

## How many rings of buildings a village has at most, and how far apart two
## rings have to be able to stand before it is worth having two.
const RING_COUNT := 2
const RING_STEP := 7.5

## The arc one building slot takes on a ring, in world units. The number of
## slots on a ring is its circumference divided by this, so the outer ring holds
## more buildings than the inner one without anyone deciding a count.
const SLOT_ARC := 8.0

## How far a building may be shifted along its ring and in or out of it, in world
## units, so a village is not a wheel of evenly spaced houses.
##
## Measured in world units rather than in radians, because the same angle is a
## much bigger shove on the outer ring than on the inner one, and the thing that
## has to stay bounded is how far two neighbours can be pushed together.
const SLOT_TANGENT_JITTER := 1.2
const SLOT_RADIAL_JITTER := 0.9

## How many slots a village needs before it is big enough to have a tavern.
const TAVERN_MIN_SLOTS := 7

## How often a village has a tower.
const TOWER_CHANCE := 0.3

## Of the slots not spoken for, how many are the larger house rather than the
## small cottage.
const HOUSE_SHARE := 0.42

## How much clear ground is left between two buildings, in world units. This is
## the spacing rule: a candidate whose footprint, widened by this, touches an
## already-placed one is dropped and its slot stays empty.
const BUILDING_GAP := 1.5

## How far a building may face away from the middle of the village, in radians.
## The orientation rule is "face the green"; this is the slack that keeps the
## ring from looking surveyed.
const FACING_JITTER := 0.22

## How far along a face a lit window may sit, either side of the face's middle,
## as a share of that face's half-span. Kept well inside the corners, because a
## window in the corner of a wall reads as a mistake and because the whole of the
## pane has to stay on the wall however wide it is drawn.
const WINDOW_ALONG_SHARE := 0.45

## How much reserved ground a building needs before it lights a second window,
## in square world units: half its width times half its depth. A cottage and a
## tower get one lit window, a house, a workshop and a tavern two, which is what
## makes a village read as a scatter of warm points rather than a ring of them.
const WINDOW_SECOND_AREA := 7.0

## How much ground each building type reserves, as half its width across its
## facing and half its depth along it, in world units.
##
## These are generation's numbers, not the art's: they say how much room a
## building of this kind takes up, and the render layer's model for the tag has
## to fit inside them. They are set a little larger than the placeholder models
## so that a swapped-in pack has somewhere to go.
const BUILDING_FOOTPRINTS := {
	AssetTags.COTTAGE: Vector2(2.0, 2.2),
	AssetTags.HOUSE: Vector2(2.6, 3.0),
	AssetTags.WORKSHOP: Vector2(2.9, 2.5),
	AssetTags.TAVERN: Vector2(3.6, 3.9),
	AssetTags.TOWER: Vector2(2.1, 2.1),
	AssetTags.WELL: Vector2(1.3, 1.1),
}

# --- Landmarks -----------------------------------------------------------

## World units across one cell of the landmark lattice, and how many of its
## cells hold one. Finer and commoner than villages, because a landmark is a
## waypoint rather than a destination: they are what keeps the road network
## joined up across the long stretches between villages.
const LANDMARK_CELL := 120.0
const LANDMARK_CHANCE := 0.58

## What a landmark is, per biome. Every one of these is a catalog tag; which
## model it resolves to is the render layer's business.
const LANDMARK_TAGS := {
	BiomeCatalog.MEADOW: AssetTags.SIGNPOST,
	BiomeCatalog.BLOSSOM_GROVE: AssetTags.SIGNPOST,
	BiomeCatalog.DEEP_FOREST: AssetTags.CAMPFIRE,
	BiomeCatalog.HIGHLAND: AssetTags.STONE_HENGE,
	BiomeCatalog.TWILIGHT_MARSH: AssetTags.GLOWING_ORB,
}

## How far a landmark keeps clear of a village's pad, in world units. Close
## enough and it is village dressing rather than a place of its own.
const LANDMARK_CLEAR := 24.0

# --- Bookkeeping ---------------------------------------------------------

## Seed offsets, so the two lattices are independent of each other and of every
## other field in the stack. Arbitrary large odd numbers.
const SITE_SEED_OFFSET := 0x68E31DA4
const LANDMARK_SEED_OFFSET := 0x3D4E5F17
const SALT_STRIDE := 0x9E3779B1

## How many cells of each lattice are remembered at once. Building a village
## samples the ground a few hundred times, and a walking observer asks about the
## same handful of cells every tick. Forgetting one changes no answer: it is
## rebuilt into exactly the same village, because building one reads nothing but
## its cell and the seed.
const MEMO_LIMIT := 1024

## The seed the whole settlement layer descends from.
var world_seed: int = 0

## The ground a village is levelled out of: the carved bed, the same ground
## anything walks on before this layer touches it.
var water: WaterField = null

## Which biome a candidate stands in, which gates it and tints it.
var biomes: BiomeField = null

## The aerial layer. A village is refused under a floating island: the plate
## would sit on the rooftops, and it also keeps this layer from ever changing
## the ground an island measured its own landing against.
var islands: IslandField = null

# Vector2i cell -> Settlement, or null for "no village in this cell".
var _sites := {}

# Vector2i cell -> Dictionary landmark, or an empty dictionary for none.
var _landmarks := {}

# Vector2i tile -> Array[Settlement] whose pads reach into it.
var _pad_tiles := {}


func _init(
	water_field: WaterField = null,
	biome_field: BiomeField = null,
	island_field: IslandField = null,
) -> void:
	water = water_field
	world_seed = water_field.world_seed if water_field != null else 0
	biomes = biome_field if biome_field != null else BiomeField.new(world_seed)
	islands = island_field if island_field != null else IslandField.new(water, biomes)


## The furthest anything belonging to a village can be from its cell position.
static func site_reach() -> float:
	return PAD_RADIUS_MAX + RING_STEP


## World units across one tile of the pad lookup lattice. Which villages reach a
## patch of world is asked once per terrain vertex, so it is worked out once per
## tile and remembered -- the same trick, and for the same reason, as the road
## network's segment tiles.
const PAD_TILE := 32.0

## How far outside a tile a village's pad may be and still reach into it.
const PAD_TILE_MARGIN := PAD_TILE * 0.708 + PAD_RADIUS_MAX


## Which cell of the settlement lattice a world position falls in.
static func cell_at(x: float, z: float) -> Vector2i:
	return Vector2i(
		floori(x / SITE_CELL + 0.5), floori(z / SITE_CELL + 0.5)
	)


## Where the middle of a cell of the settlement lattice is.
static func cell_centre(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * SITE_CELL, float(cell.y) * SITE_CELL)


## Which tile of the pad lookup lattice a world position falls in.
static func pad_tile_at(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / PAD_TILE), floori(z / PAD_TILE))


## Which cell of the landmark lattice a world position falls in.
static func landmark_cell_at(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / LANDMARK_CELL), floori(z / LANDMARK_CELL))


# --- Villages ------------------------------------------------------------

## The village in one cell, or null if that cell holds none.
##
## This is the whole of the sparse field: everything else here is a way of
## deciding which cells to ask it about. It is a pure function of (cell, seed).
func settlement_in_cell(cell: Vector2i) -> Settlement:
	if _sites.has(cell):
		return _sites[cell]
	var built := _build(cell)
	if _sites.size() >= MEMO_LIMIT:
		_sites.clear()
	_sites[cell] = built
	return built


## Every village whose pad comes within `distance` of a position, in cell order
## rather than discovery order, so what comes back does not depend on where the
## scan started.
func settlements_near(x: float, z: float, distance: float) -> Array[Settlement]:
	# A village stands inside its own cell, so a village covering a position
	# within `distance` has its cell within that distance plus its own radius --
	# no slack ring of cells is needed, and each one saved is a site the field
	# never has to work out.
	var reach := int(ceil((distance + PAD_RADIUS_MAX) / SITE_CELL))
	var centre := cell_at(x, z)
	var found: Array[Settlement] = []
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var site := settlement_in_cell(Vector2i(centre.x + offset_x, centre.y + offset_z))
			if site == null:
				continue
			if site.distance_to(x, z) <= distance:
				found.append(site)
	return found


## The villages whose pads can reach into the tile a position falls in.
##
## Almost always empty, which is the point: the ground asks this once per vertex
## it meshes, and this turns that into a dictionary lookup plus at most a couple
## of distance tests instead of a scan of the lattice.
func pads_near(x: float, z: float) -> Array[Settlement]:
	var tile := pad_tile_at(x, z)
	if _pad_tiles.has(tile):
		return _pad_tiles[tile]
	var built := _build_pad_tile(tile)
	if _pad_tiles.size() >= MEMO_LIMIT:
		_pad_tiles.clear()
	_pad_tiles[tile] = built
	return built


func _build_pad_tile(tile: Vector2i) -> Array[Settlement]:
	var centre := Vector2(
		(float(tile.x) + 0.5) * PAD_TILE, (float(tile.y) + 0.5) * PAD_TILE
	)
	var reach := int(ceil((PAD_TILE_MARGIN + PAD_RADIUS_MAX) / SITE_CELL))
	var home := cell_at(centre.x, centre.y)
	var found: Array[Settlement] = []
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var site := settlement_in_cell(Vector2i(home.x + offset_x, home.y + offset_z))
			if site == null:
				continue
			if site.distance_to(centre.x, centre.y) <= PAD_TILE_MARGIN:
				found.append(site)
	return found


## The village whose pad covers a position, or null.
func settlement_at(x: float, z: float) -> Settlement:
	for site in pads_near(x, z):
		if site.covers(x, z):
			return site
	return null


## The building whose ground is reserved at a position, or an empty dictionary.
##
## This is the question the scatter layer that comes next asks before it puts
## anything down, and the whole reason footprints are reserved.
func building_at(x: float, z: float, margin: float = 0.0) -> Dictionary:
	var site := settlement_at(x, z)
	if site == null:
		return {}
	return site.building_at(x, z, margin)


## Whether a building stands on this position.
func is_reserved_at(x: float, z: float, margin: float = 0.0) -> bool:
	return not building_at(x, z, margin).is_empty()


## How far the ground at a position has to move for the villages to be level,
## given the ground height `level` it is at before this layer touches it.
##
## Zero almost everywhere: this is the sparse layer's contribution to the
## composed ground, and it is added by TerrainQuery rather than applied here, so
## that whoever wants the untouched land can still have it.
func ground_delta_at(x: float, z: float, level: float) -> float:
	for site in pads_near(x, z):
		var weight := site.pad_weight(x, z)
		if weight <= 0.0:
			continue
		return (site.pad_height - level) * weight
	return 0.0


# --- Landmarks -----------------------------------------------------------

## The landmark in one cell of the landmark lattice, or an empty dictionary.
##
## A landmark is {id, x, z, tag, biome}: a place, a name for it, and what stands
## there. Nothing is flattened and nothing is reserved.
func landmark_in_cell(cell: Vector2i) -> Dictionary:
	if _landmarks.has(cell):
		return _landmarks[cell]
	var built := _build_landmark(cell)
	if _landmarks.size() >= MEMO_LIMIT:
		_landmarks.clear()
	_landmarks[cell] = built
	return built


## Every landmark within `distance` of a position, in cell order.
func landmarks_near(x: float, z: float, distance: float) -> Array[Dictionary]:
	var reach := int(ceil(distance / LANDMARK_CELL))
	var centre := landmark_cell_at(x, z)
	var found: Array[Dictionary] = []
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var mark := landmark_in_cell(Vector2i(centre.x + offset_x, centre.y + offset_z))
			if mark.is_empty():
				continue
			if Vector2(float(mark["x"]) - x, float(mark["z"]) - z).length() <= distance:
				found.append(mark)
	return found


# --- Building the field --------------------------------------------------

## Hash one number out of a cell, in [0, 1). The salt keeps a village's size
## independent of its position and of whether it exists at all, so retuning one
## does not shuffle the others.
func _roll(cell: Vector2i, salt: int) -> float:
	return SimRng.hash_unit(
		world_seed + SITE_SEED_OFFSET + salt * SALT_STRIDE, cell.x, cell.y
	)


func _roll_range(cell: Vector2i, salt: int, low: float, high: float) -> float:
	return low + (high - low) * _roll(cell, salt)


func _build(cell: Vector2i) -> Settlement:
	var wants := _roll(cell, 1)
	var is_spawn := cell == cell_at(0.0, 0.0)
	if not is_spawn and wants >= SITE_CHANCE:
		return null

	var radius := _roll_range(cell, 2, PAD_RADIUS_MIN, PAD_RADIUS_MAX)
	var inland := _build_inland(cell, wants, radius, is_spawn)
	if inland == null:
		return null

	# The shore rule *re-sites* a village; it never creates one. A cell with a
	# pond in it but no dry, level, unroofed ground anywhere had no village
	# before this rule and has none after it, so the density the placement rule
	# states is untouched and the only thing this rule can do to a world is move
	# a village that was already in it to the water's edge.
	#
	# The starting village is left out of it. It is the one village in the world
	# placed relative to the origin rather than to its cell, and what its ring
	# rule is for -- never underfoot, never more than a short walk -- is a
	# different promise from this one. Letting the two rules argue over the same
	# village would weaken both.
	var site := inland
	if not is_spawn:
		var shore := _build_shore(cell, wants, radius)
		if shore != null:
			site = shore
	# The layout runs once, on whichever site was kept. Which is also why the two
	# passes above stop at a site rather than at a village: laying out a village
	# is the expensive half, and an inland site the shore rule then replaces
	# would have paid for it twice.
	_lay_out(site)
	return site


## A village on dry ground: the rule this layer had before it learned to like a
## shore, unchanged, and still the one every village that is not on a shore is
## placed by.
func _build_inland(
	cell: Vector2i, wants: float, radius: float, is_spawn: bool
) -> Settlement:
	var attempts := SPAWN_ATTEMPTS if is_spawn else SITE_ATTEMPTS
	var sweeps: Array = SPAWN_SHRINK if is_spawn else [1.0]
	for sweep: float in sweeps:
		var size := radius * sweep
		for attempt in attempts:
			var at := _candidate_at(cell, attempt, is_spawn)
			var biome := biomes.biome_at(at.x, at.y)
			# The biome gate, as a threshold on the roll the cell already made.
			var share := float(BIOME_SHARE.get(biome, 0.0))
			if share <= 0.0:
				continue
			if not is_spawn and wants >= SITE_CHANCE * share:
				continue
			var ground := _pad_ground(at.x, at.y, size)
			if not bool(ground["ok"]):
				continue
			var site := Settlement.new()
			site.cell = cell
			site.centre_x = at.x
			site.centre_z = at.y
			site.radius = size
			site.core_radius = size * PAD_CORE_SHARE
			site.pad_height = float(ground["level"])
			site.biome = biome
			site.is_spawn = is_spawn
			return site
	return null


## A village on a shore, or null when this cell has no shore to put one on.
##
## Three steps, and each is a place the cell can give up. Find standing water in
## the cell at all; stand a pad back from it far enough that its levelled core
## clears the bank; check that pad by every rule an inland pad is checked by
## except the one that would refuse it for being near water at all.
func _build_shore(cell: Vector2i, wants: float, radius: float) -> Settlement:
	var leads := _shore_leads(cell)
	if leads.is_empty():
		return null
	var start := _roll(cell, 9) * TAU
	for sweep: float in SHORE_SHRINK:
		var size := radius * sweep
		var core := size * PAD_CORE_SHARE
		for lead_index in leads.size():
			var lead: Vector2 = leads[lead_index]
			for bearing in SHORE_BEARINGS:
				var angle := start + float(lead_index * SHORE_BEARINGS + bearing) \
					* GOLDEN_ANGLE
				var heading := Vector2(cos(angle), sin(angle))
				# Walk out of the water first. The lead is wherever the grid
				# happened to find the pond, which on a lake is somewhere in the
				# middle of it; what the village stands back from is the *edge*,
				# so the edge is found before anything is measured. Without this
				# a wide lake refuses every bearing, because a pad a core's width
				# from the middle of it is still in it.
				var edge := _water_edge(lead, heading)
				if edge == INF:
					continue
				var at := lead + heading * (edge + core + SHORE_STANDOFF)
				# A shore village stays in the middle half of its own cell, the
				# same band an ordinary candidate is jittered into. That band is
				# what keeps two villages in neighbouring cells half a cell
				# apart, and it is not this rule's to spend.
				if not _inside_jitter_band(cell, at):
					continue
				var biome := biomes.biome_at(at.x, at.y)
				var share := float(BIOME_SHARE.get(biome, 0.0))
				if share <= 0.0 or wants >= SITE_CHANCE * share:
					continue
				var ground := _shore_ground(at.x, at.y, size)
				if not bool(ground["ok"]):
					continue
				var site := Settlement.new()
				site.cell = cell
				site.centre_x = at.x
				site.centre_z = at.y
				site.radius = size
				site.core_radius = core
				site.pad_height = float(ground["level"])
				site.biome = biome
				site.is_spawn = false
				site.is_shore = true
				return site
	return null


## How far along a heading the water's edge is, starting inside the water, or
## INF when the water does not end within reach.
##
## Stepped rather than solved, because the shoreline is where two noise surfaces
## cross and there is nothing to solve. The step is what fixes how precisely the
## village stands back from the edge, and it is well inside the band of dry
## ground the site test then insists on, so a step's worth of error cannot put a
## building in the water.
func _water_edge(from: Vector2, heading: Vector2) -> float:
	var steps := int(SHORE_EDGE_REACH / SHORE_EDGE_STEP)
	for step in range(1, steps + 1):
		var reach := float(step) * SHORE_EDGE_STEP
		var at := from + heading * reach
		if not water.is_water_at(at.x, at.y):
			return reach
	return INF


## Whether a position is in the middle half of a cell: the band an ordinary
## candidate is jittered into, and the band a shore candidate has to land in.
func _inside_jitter_band(cell: Vector2i, at: Vector2) -> bool:
	var corner := cell_centre(cell) - Vector2(SITE_CELL, SITE_CELL) * 0.5
	var share := (at - corner) / SITE_CELL
	return share.x >= JITTER_LOW and share.x <= JITTER_HIGH \
		and share.y >= JITTER_LOW and share.y <= JITTER_HIGH


## The stretches of standing water in a cell that are worth standing a village
## beside, in scan order and at most SHORE_LEADS of them.
##
## A grid over the whole cell rather than over the jitter band, because the pond
## may lie outside the band the village itself has to stand in -- what has to be
## in the band is the pad, not the water. Two probes in the same pond would send
## every bearing round the same piece of shore, so a lead has to be a stated
## distance from the ones already taken to count as a second stretch.
func _shore_leads(cell: Vector2i) -> Array[Vector2]:
	var corner := cell_centre(cell) - Vector2(SITE_CELL, SITE_CELL) * 0.5
	var step := SITE_CELL / float(SHORE_PROBES)
	var found: Array[Vector2] = []
	for row in SHORE_PROBES:
		for column in SHORE_PROBES:
			var at := corner + Vector2(
				(float(column) + 0.5) * step, (float(row) + 0.5) * step
			)
			if not _is_standing_water(at.x, at.y):
				continue
			var apart := true
			for taken in found:
				if (taken - at).length() < SHORE_LEAD_APART:
					apart = false
					break
			if not apart:
				continue
			found.append(at)
			if found.size() >= SHORE_LEADS:
				return found
	return found


## Whether a position is standing water: a pond or a lake, level with the water
## table, rather than a river following the ground downhill.
##
## The two are one arithmetic in the water field -- the surface is whichever of
## the table and the river's falling level stands higher -- so which one it is
## here is which of the two won, and that is what this reads.
func _is_standing_water(x: float, z: float) -> bool:
	var column := water.sample_column(x, z)
	if column.y <= column.x:
		return false
	return absf(column.y - water.table_level_at(x, z)) < 0.0001


## What the ground under a shore candidate is like.
##
## The same three refusals an inland pad answers -- wet ground where a building
## would stand, more relief than can be levelled, anything overhead -- with the
## dry test moved in from the rim to a ring outside the levelled core, and one
## added: there has to be a pond. The gates are ordered cheapest first, because
## most candidates are refused and the island scan at the end is the dearest
## question in the file.
func _shore_ground(x: float, z: float, radius: float) -> Dictionary:
	var core := radius * PAD_CORE_SHARE
	var coarse := _pad_scan(x, z, core, PAD_COARSE_RINGS)
	if not bool(coarse["ok"]) or float(coarse["relief"]) > PAD_RELIEF_LIMIT:
		return {"ok": false, "level": 0.0}
	# The band of dry ground outside the core, in place of the inland rule's dry
	# rim. Everything a village builds stands inside the core, so this is the
	# clear ground round the outermost house.
	for direction in PAD_RIM_DIRECTIONS:
		var angle := TAU * float(direction) / float(PAD_RIM_DIRECTIONS)
		var out := core + SHORE_DRY_MARGIN
		if water.is_water_at(x + cos(angle) * out, z + sin(angle) * out):
			return {"ok": false, "level": 0.0}
	if not _has_shore(x, z, core, radius):
		return {"ok": false, "level": 0.0}
	var fine := _pad_scan(x, z, core, PAD_FINE_RINGS)
	if not bool(fine["ok"]) or float(fine["relief"]) > PAD_RELIEF_LIMIT:
		return {"ok": false, "level": 0.0}
	if not _clear_overhead(x, z, radius):
		return {"ok": false, "level": 0.0}
	return fine


## Whether there is enough standing water in the band between the dry ring and a
## little past the pad's rim for this to be a shore rather than a wet patch.
func _has_shore(x: float, z: float, core: float, radius: float) -> bool:
	var near := core + SHORE_DRY_MARGIN
	var far := radius + SHORE_WATER_REACH
	var wet := 0
	for ring in SHORE_RINGS:
		var share := (float(ring) + 1.0) / float(SHORE_RINGS)
		var reach := near + (far - near) * share
		for direction in SHORE_DIRECTIONS:
			var angle := TAU * float(direction) / float(SHORE_DIRECTIONS)
			if _is_standing_water(x + cos(angle) * reach, z + sin(angle) * reach):
				wet += 1
				if wet >= SHORE_WET_MIN:
					return true
	return false


## Where the `attempt`-th candidate for a cell stands.
##
## Ordinary cells jitter inside themselves. The cell holding the world origin
## puts its candidates on a ring around the origin instead, which is the whole
## of the spacing-from-spawn rule: the starting village is a short walk away in
## a hashed direction, never underfoot.
func _candidate_at(cell: Vector2i, attempt: int, is_spawn: bool) -> Vector2:
	if is_spawn:
		var bearing := _roll(cell, 40) * TAU + float(attempt) * GOLDEN_ANGLE
		var away := _roll_range(cell, 60 + attempt, SPAWN_RING_MIN, SPAWN_RING_MAX)
		return Vector2(cos(bearing) * away, sin(bearing) * away)
	var corner := cell_centre(cell) - Vector2(SITE_CELL, SITE_CELL) * 0.5
	return corner + Vector2(
		_roll_range(cell, 10 + attempt, JITTER_LOW, JITTER_HIGH) * SITE_CELL,
		_roll_range(cell, 25 + attempt, JITTER_LOW, JITTER_HIGH) * SITE_CELL,
	)


## What the ground under a candidate is like: whether it can hold a village at
## all, and what height it would be levelled to.
##
## Three refusals, and each is a thing you can see when it is ignored. Water on
## the pad would put a house in a river. Too much relief would leave a cut bank
## on one side and a plinth on the other. A floating island overhead would rest
## its plate on the rooftops -- and refusing it here is also what keeps this
## layer from ever moving ground that an island measured its own landing step
## against.
func _pad_ground(x: float, z: float, radius: float) -> Dictionary:
	var core := radius * PAD_CORE_SHARE
	# The cheap reject first: most candidates are refused for being wet or for
	# having too much relief to level, and both show up on a handful of samples.
	var coarse := _pad_scan(x, z, core, PAD_COARSE_RINGS)
	if not bool(coarse["ok"]) or float(coarse["relief"]) > PAD_RELIEF_LIMIT:
		return {"ok": false, "level": 0.0}
	# The whole pad has to be dry, not just the part that gets levelled.
	if not _outer_is_dry(x, z, core, radius):
		return {"ok": false, "level": 0.0}
	# And the level itself is the average over the core, on the fine grid.
	var fine := _pad_scan(x, z, core, PAD_FINE_RINGS)
	if not bool(fine["ok"]) or float(fine["relief"]) > PAD_RELIEF_LIMIT:
		return {"ok": false, "level": 0.0}
	# The rim has to stay out of the water too, or a levelled pad would meet the
	# shore as a step -- and a wheel needs bank to stand on just beyond it.
	for direction in PAD_RIM_DIRECTIONS:
		var angle := TAU * float(direction) / float(PAD_RIM_DIRECTIONS)
		var out := radius + PAD_DRY_MARGIN
		if water.is_water_at(x + cos(angle) * out, z + sin(angle) * out):
			return {"ok": false, "level": 0.0}
	if not _clear_overhead(x, z, radius):
		return {"ok": false, "level": 0.0}
	return fine


## Whether the ramp between the levelled core and the pad's rim is dry.
func _outer_is_dry(x: float, z: float, core: float, radius: float) -> bool:
	for ring in PAD_OUTER_RINGS.size():
		var share := (float(ring) + 1.0) / float(PAD_OUTER_RINGS.size())
		var reach := core + (radius - core) * share
		var directions: int = PAD_OUTER_RINGS[ring]
		for direction in directions:
			var angle := TAU * float(direction) / float(directions)
			if water.is_water_at(x + cos(angle) * reach, z + sin(angle) * reach):
				return false
	return true


## Whether the sky over a candidate is empty.
##
## Asked of the aerial layer once per storey, as "is any island of this band
## within a pad's radius of here", rather than probe by probe over the footprint.
## The two answer the same question; this one costs one scan of the island
## lattice per storey instead of one per probe, and building the settlement field
## is otherwise dominated by asking the layer above it what it is doing.
##
## The refusal is a matter of composition rather than of correctness -- the
## composed ground refuses to move anything under an island in any case -- but
## without it a village could have a plate resting on two of its rooftops and a
## pair of houses standing on unlevelled ground.
func _clear_overhead(x: float, z: float, radius: float) -> bool:
	# Both walkable storeys are asked directly, each with the pad's own radius,
	# because the pad's radius is the whole of the question: does anything hang
	# over this village.
	#
	# The lower storey used to be asked on its own, with the radius widened by
	# the widest island there is, on the grounds that an upper storey stands
	# beside a lower one rather than anywhere -- so a wide enough question about
	# the lower band would catch the pairs for the price of one scan. It is a
	# proxy, and it is wrong in both directions at once. Too coarse: a
	# ten-unit island widened the question by twenty-four, refusing sites with
	# nothing within sight of them. Too short: an upper storey reaches about
	# 1.28 times its lower island's radius past that island's outline, which is
	# thirty-one units for the widest lower island against the twenty-four the
	# padding allowed, so a plate could still overhang the outer stretch of a
	# pad. Asking the upper band itself has no shortfall to bound and no slack
	# to pay for.
	#
	# Each band is asked of the hashes before it is asked of the islands.
	# `could_reach` walks the same cells `islands_near` would, but asks each one
	# only where its island *would* stand and how far its outline *could* reach
	# -- both of which fall out of the cell and the seed -- so it builds nothing.
	# When it says no, nothing of that band is within a pad's radius and the scan
	# that would have built the band's islands to find that out is skipped
	# outright. When it cannot say no, the real question is asked as before, and
	# the answer is the same answer: the bound is an upper bound on the outline,
	# so it can only ever say "maybe" where the truth is "no", never the reverse.
	#
	# This is what pays for the second storey. The upper band is the expensive
	# one -- building an upper island builds the lower one under it first -- and
	# it is also the one the hashes rule out most often, because an upper storey
	# is narrower than the plate it stands beside. Over the 484 positions per band
	# that `tests/test_islands.gd` sweeps, the bound rules the upper storey out on
	# 65% of them and the lower storey on 43%.
	for band in FloatingIsland.WALKABLE_BANDS:
		if not islands.could_reach(band, x, z, radius):
			continue
		if not islands.islands_near(band, x, z, radius).is_empty():
			return false
	return true


## One pass of the pad scan: rings out to the rim, with the given number of
## directions on each ring.
func _pad_scan(x: float, z: float, radius: float, rings: Array) -> Dictionary:
	var total := 0.0
	var samples := 0
	var lowest := INF
	var highest := -INF
	for ring in rings.size():
		var ratio := float(ring) / float(rings.size() - 1)
		var directions: int = rings[ring]
		for direction in directions:
			var angle := TAU * float(direction) / float(directions)
			var reach := radius * ratio
			var at_x := x + cos(angle) * reach
			var at_z := z + sin(angle) * reach
			var column := water.sample_column(at_x, at_z)
			if column.y > column.x:
				return {"ok": false, "level": 0.0}
			total += column.x
			samples += 1
			lowest = minf(lowest, column.x)
			highest = maxf(highest, column.x)
	return {"ok": true, "level": total / float(samples), "relief": highest - lowest}


# --- Layout --------------------------------------------------------------

## Put the buildings and the dressing on a village whose site is already fixed.
##
## The layout is a green with rings of buildings round it. Every building faces
## the green, give or take a little slack, which is the orientation rule; a
## candidate whose footprint touches one already placed is dropped, which is the
## spacing rule. Slots are walked in a fixed order and each is decided from a
## hash of its own index, so the same village comes out of the same seed however
## many times it is built.
func _lay_out(site: Settlement) -> void:
	var plaza := site.core_radius * PLAZA_SHARE
	_place_well(site, plaza)

	var slots := _slots_for(site, plaza)
	var wish := _wish_list(site, slots.size())
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var tag: String = wish[index] if index < wish.size() else _filler_tag(site, index)
		var footprint: Vector2 = BUILDING_FOOTPRINTS[tag]
		# Face the middle of the village. A building's local +Z is its front, so
		# the yaw that points +Z at the centre is the bearing from the building
		# to the centre, measured the way the render layer turns things.
		var to_centre := Vector2(site.centre_x - slot["x"], site.centre_z - slot["z"])
		var yaw := atan2(to_centre.x, to_centre.y) + _site_roll(site, 300 + index) \
			* 2.0 * FACING_JITTER - FACING_JITTER
		var building := {
			"tag": tag,
			"x": float(slot["x"]),
			"z": float(slot["z"]),
			"yaw": yaw,
			"half_width": footprint.x,
			"half_depth": footprint.y,
		}
		if _collides(site, building):
			continue
		# The spacing rule keeps buildings off each other; this keeps them on the
		# level ground, which is the other half of "the ground is flattened under
		# a settlement" meaning anything.
		if Vector2(building["x"] - site.centre_x, building["z"] - site.centre_z).length() \
				+ footprint.length() > site.core_radius:
			continue
		# And this keeps it out of the water, footprint by footprint rather than
		# by trusting the rings the site was scanned on. The pad scan samples the
		# core on rings a few units apart, which is enough to refuse a site with
		# water in it and not enough to promise that no corner of any rectangle
		# is wet -- so the promise is made here, where the rectangle is known.
		# It refuses nothing on the dry sites the layer used to place; it is what
		# makes "no building stands in water" true of a shore village by
		# construction rather than by sampling luck.
		if _footprint_is_wet(building):
			continue
		site.buildings.append(building)
	_place_windows(site)
	_dress(site, plaza)


## Whether any of a building's reserved ground is under water: its middle and
## its four corners, which for a rectangle whose sides are a couple of units
## long is the whole of it at the scale water bodies change on.
func _footprint_is_wet(building: Dictionary) -> bool:
	if water.is_water_at(float(building["x"]), float(building["z"])):
		return true
	for corner in Settlement.footprint_corners(building):
		if water.is_water_at(corner.x, corner.y):
			return true
	return false


## The lit windows: one on the front of every building, a second on the side of
## the bigger ones.
##
## This is the settlement layer's whole part in the art direction's warm-pinpoint
## signature. Where a window is comes from the building's own footprint and its
## own facing and from nothing else -- this file has never heard of a model, and
## the reserved rectangle plus the way it is turned is all it has to go on. That
## is enough to say *which wall* and *where along it*: the front face is the one
## that looks at the green, and the share along it is a roll off the village's
## own seed, so the same village lights the same windows in every process.
##
## The well is skipped. A village lights its houses, not its water.
func _place_windows(site: Settlement) -> void:
	for index in site.buildings.size():
		var building: Dictionary = site.buildings[index]
		if building["tag"] == AssetTags.WELL:
			continue
		# The front: local +Z, the face the layout already turned towards the
		# green, so a village seen from its middle is all lit windows.
		_add_window(site, index, building, 0.0,
			(_site_roll(site, 1100 + index) * 2.0 - 1.0) * WINDOW_ALONG_SHARE)
		if float(building["half_width"]) * float(building["half_depth"]) \
				< WINDOW_SECOND_AREA:
			continue
		# And one gable end, so a big building is lit from more than one angle.
		var side := 1.0 if _site_roll(site, 1200 + index) < 0.5 else -1.0
		_add_window(site, index, building, side * PI * 0.5,
			(_site_roll(site, 1300 + index) * 2.0 - 1.0) * WINDOW_ALONG_SHARE)


## One window on one face of one building.
##
## `turn` is which face, as a quarter turn off the building's own facing: zero
## is the front, plus or minus a right angle is a side. `along` is where on that
## face it sits, as a share of the face's half-span. The window's own yaw is the
## outward normal of the face, in the same convention everything else here uses
## -- local +Z is the way a thing looks -- so whoever draws it knows which way
## the pane faces without being told separately.
func _add_window(
	site: Settlement, index: int, building: Dictionary, turn: float, along: float
) -> void:
	var half_width := float(building["half_width"])
	var half_depth := float(building["half_depth"])
	# How far out the face is, and how wide it is, both read off the same
	# rectangle: the front and back faces are half_depth out and half_width
	# wide, the two sides the other way round.
	var out_reach := absf(cos(turn)) * half_depth + absf(sin(turn)) * half_width
	var span := absf(cos(turn)) * half_width + absf(sin(turn)) * half_depth
	var yaw := float(building["yaw"]) + turn
	var forward := Vector2(sin(yaw), cos(yaw))
	var across := Vector2(cos(yaw), -sin(yaw))
	var at := Vector2(float(building["x"]), float(building["z"])) \
		+ forward * out_reach + across * (along * span)
	site.glows.append({
		"tag": AssetTags.WINDOW_GLOW,
		"x": at.x,
		"z": at.y,
		"yaw": yaw,
		"building": index,
	})


## The well and the fire in the middle of the green. The well is a building
## rather than a prop because it reserves ground: nothing else may stand on it,
## and the scatter layer has to know that too.
func _place_well(site: Settlement, plaza: float) -> void:
	var footprint: Vector2 = BUILDING_FOOTPRINTS[AssetTags.WELL]
	site.buildings.append({
		"tag": AssetTags.WELL,
		"x": site.centre_x,
		"z": site.centre_z,
		"yaw": _site_roll(site, 2) * TAU,
		"half_width": footprint.x,
		"half_depth": footprint.y,
	})
	var fire_angle := _site_roll(site, 3) * TAU
	site.props.append({
		"tag": AssetTags.CAMPFIRE,
		"x": site.centre_x + cos(fire_angle) * plaza * 0.7,
		"z": site.centre_z + sin(fire_angle) * plaza * 0.7,
		"yaw": 0.0,
	})


## Every slot a building could stand in, ring by ring and slot by slot: a fixed
## order, so which slot gets which building does not depend on anything but the
## seed.
func _slots_for(site: Settlement, plaza: float) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	# The rings are placed between the plaza and the inside of the levelled rim
	# rather than at fixed distances, so a small village is a tight cluster and a
	# large one has room for a second row, and neither puts a wall off the pad.
	var inner := plaza + RING_GAP
	var outer := site.core_radius - BUILDING_INSET
	var rings := RING_COUNT if outer - inner >= RING_STEP else 1
	for ring in rings:
		# One ring goes halfway between the plaza and the rim rather than hard
		# against the plaza: a single ring is the whole village, so it belongs in
		# the middle of the ground it has.
		var share := 0.5 if rings == 1 else float(ring) / float(rings - 1)
		var ring_radius := inner + (outer - inner) * share
		var count := maxi(3, int(round(TAU * ring_radius / SLOT_ARC)))
		for slot in count:
			var index := slots.size()
			var angle := TAU * float(slot) / float(count) \
				+ (_site_roll(site, 100 + index) * 2.0 - 1.0) \
				* SLOT_TANGENT_JITTER / ring_radius
			var reach := ring_radius \
				+ (_site_roll(site, 200 + index) * 2.0 - 1.0) * SLOT_RADIAL_JITTER
			slots.append({
				"x": site.centre_x + cos(angle) * reach,
				"z": site.centre_z + sin(angle) * reach,
				"angle": angle,
				"ring": ring,
			})
	return slots


## What the village wants, in the order it wants it. The named buildings go in
## the first slots; everything after them is houses and cottages.
func _wish_list(site: Settlement, slots: int) -> PackedStringArray:
	var wish := PackedStringArray()
	if slots >= TAVERN_MIN_SLOTS:
		wish.append(AssetTags.TAVERN)
	wish.append(AssetTags.WORKSHOP)
	if _site_roll(site, 4) < TOWER_CHANCE:
		wish.append(AssetTags.TOWER)
	return wish


func _filler_tag(site: Settlement, index: int) -> String:
	return AssetTags.HOUSE if _site_roll(site, 400 + index) < HOUSE_SHARE \
		else AssetTags.COTTAGE


## Whether a candidate building touches one already placed, with the spacing
## rule's clear ground allowed for. This is the whole of "no two buildings
## overlap", and it is exact rather than a circle test.
func _collides(site: Settlement, candidate: Dictionary) -> bool:
	for building in site.buildings:
		if Settlement.footprints_overlap(building, candidate, BUILDING_GAP):
			return true
	return false


## The dressing: lanterns round the green, fences along the gaps in the outer
## ring, working clutter beside the buildings, a stall or two on the green, and
## a water wheel where the village has a river to put one on.
##
## Every one of these is a tag. What a lantern post is made of is the render
## layer's business, and no line in this file knows.
func _dress(site: Settlement, plaza: float) -> void:
	var lanterns := 4 + int(_site_roll(site, 5) * 3.0)
	for at in lanterns:
		var angle := TAU * float(at) / float(lanterns) + _site_roll(site, 500 + at) * 0.4
		site.props.append({
			"tag": AssetTags.LANTERN_POST,
			"x": site.centre_x + cos(angle) * (plaza + 1.6),
			"z": site.centre_z + sin(angle) * (plaza + 1.6),
			"yaw": angle,
		})

	var stalls := 1 + int(_site_roll(site, 6) * 2.0)
	for at in stalls:
		var angle := _site_roll(site, 600 + at) * TAU
		site.props.append({
			"tag": AssetTags.MARKET_STALL,
			"x": site.centre_x + cos(angle) * plaza * 0.55,
			"z": site.centre_z + sin(angle) * plaza * 0.55,
			"yaw": atan2(-cos(angle), -sin(angle)),
		})

	# Working clutter, tucked against the side of a building rather than
	# scattered: a barrel reads as belonging to the workshop it leans on.
	var clutter := [AssetTags.BARREL, AssetTags.CRATE, AssetTags.CART]
	for index in site.buildings.size():
		var building: Dictionary = site.buildings[index]
		if building["tag"] == AssetTags.WELL:
			continue
		if _site_roll(site, 700 + index) > 0.55:
			continue
		var tag: String = clutter[int(_site_roll(site, 800 + index) * float(clutter.size())) \
			% clutter.size()]
		var side := 1.0 if _site_roll(site, 900 + index) < 0.5 else -1.0
		var yaw := float(building["yaw"])
		var across := Vector2(cos(yaw), -sin(yaw))
		var offset := across * side * (float(building["half_width"]) + 0.9)
		site.props.append({
			"tag": tag,
			"x": float(building["x"]) + offset.x,
			"z": float(building["z"]) + offset.y,
			"yaw": yaw,
		})

	# Fences between the outer buildings, at the midpoint of each gap, turned
	# tangentially so they close the ring rather than pointing out of it.
	var outer: Array[Dictionary] = []
	for building in site.buildings:
		if building["tag"] == AssetTags.WELL:
			continue
		outer.append(building)
	for index in outer.size():
		if _site_roll(site, 1000 + index) > 0.5:
			continue
		var here: Dictionary = outer[index]
		var next: Dictionary = outer[(index + 1) % outer.size()]
		var mid_x := (float(here["x"]) + float(next["x"])) * 0.5
		var mid_z := (float(here["z"]) + float(next["z"])) * 0.5
		var away := Vector2(mid_x - site.centre_x, mid_z - site.centre_z)
		if away.length() < plaza + RING_GAP:
			continue
		site.props.append({
			"tag": AssetTags.FENCE,
			"x": mid_x,
			"z": mid_z,
			"yaw": atan2(away.x, away.y),
		})

	_place_water_wheel(site)


## A water wheel on the bank, if the village has a bank to put one on. Looked
## for on a ring outside the pad, because the pad itself is dry by construction.
func _place_water_wheel(site: Settlement) -> void:
	var steps := 24
	for step in steps:
		var angle := TAU * float(step) / float(steps) + _site_roll(site, 7) * TAU
		var out := site.radius + PAD_DRY_MARGIN + 2.0
		var x := site.centre_x + cos(angle) * out
		var z := site.centre_z + sin(angle) * out
		if not water.is_bank_at(x, z):
			continue
		site.props.append({
			"tag": AssetTags.WATER_WHEEL,
			"x": x,
			"z": z,
			"yaw": atan2(-cos(angle), -sin(angle)),
		})
		return


## A number hashed from a village's identity rather than from its cell, so that
## the layout rolls are independent of the placement rolls.
func _site_roll(site: Settlement, salt: int) -> float:
	return SimRng.hash_unit(
		world_seed + SITE_SEED_OFFSET + (salt + 7717) * SALT_STRIDE,
		site.cell.x * 131 + salt,
		site.cell.y * 977 - salt,
	)


# --- Landmarks -----------------------------------------------------------

func _landmark_roll(cell: Vector2i, salt: int) -> float:
	return SimRng.hash_unit(
		world_seed + LANDMARK_SEED_OFFSET + salt * SALT_STRIDE, cell.x, cell.y
	)


func _build_landmark(cell: Vector2i) -> Dictionary:
	if _landmark_roll(cell, 1) >= LANDMARK_CHANCE:
		return {}
	var x := (float(cell.x) + _landmark_roll(cell, 2) * 0.6 + 0.2) * LANDMARK_CELL
	var z := (float(cell.y) + _landmark_roll(cell, 3) * 0.6 + 0.2) * LANDMARK_CELL
	# A landmark stands on dry ground and out of a village's way. It is not
	# levelled and it reserves nothing -- it is a place, not a settlement -- so
	# it has no opinion about what is in the sky above it. The two tests are in
	# this order because the water is one field sample and the villages are a
	# scan of the settlement lattice, and most candidates that fail, fail here.
	if water.is_water_at(x, z) or water.is_bank_at(x, z):
		return {}
	if not settlements_near(x, z, LANDMARK_CLEAR).is_empty():
		return {}
	var biome := biomes.biome_at(x, z)
	return {
		"id": "l%d,%d" % [cell.x, cell.y],
		"cell": cell,
		"x": x,
		"z": z,
		"tag": String(LANDMARK_TAGS.get(biome, AssetTags.SIGNPOST)),
		"biome": biome,
	}
