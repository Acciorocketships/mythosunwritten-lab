extends RefCounted
## The ground: this repo's discrete sim reading mythosunwritten's continuous
## fields, written against those fields directly.
##
## The base adoption (see ADOPTION.md) brought in a far richer terrain stack --
## a streamed, storey-quantised heightfield with river carving (HeightfieldPlan
## / TerrainSurfaceField), a hydrostatically filled water plan (WaterPlan /
## WaterFieldContext), and biome fields (Helper.biome_*) -- all pure functions
## of world position and seed. This file is the whole of the sim's ground
## reading: it owns the adopted plans for a seed and answers every question the
## layers above ask about a patch of land, in their terms. There is no second
## ground regime underneath it and nothing here translates between two: what a
## caller gets is the adopted stack's own answer, named the way this project's
## layers ask for it.
##
## It is written in the base's idiom. Positions go in as Vector2 world points
## and Vector3 world positions, heights come out of TerrainSurfaceField.surface_y
## over a HeightfieldRegion, wetness and level come off a WaterFieldContext, and
## the biome mix is Helper.biome_weights5 -- the base's own calls, on the base's
## own plans, reached through the base's own WorldFieldBlockCache. The only
## thing this file adds is the arithmetic the sim needs and the base does not
## have a name for: a dry column's two ordered surfaces, whether a dry position
## is a bank, and whether the water standing on a position is still or running.
##
## **The cell-to-patch mapping, stated once.** The sim's spatial unit is the
## combat cell: cell (i, j) is the fixed, world-anchored patch of heightfield
## [i*S, (i+1)*S) x [j*S, (j+1)*S) with S = CombatBoard.CELL_SIZE, and every
## per-cell answer -- elevation, water, biome, blockedness -- is the adopted
## field sampled at that patch's centre, CombatBoard.centre_of(cell), through
## TerrainQuery. Nothing else maps cells to ground anywhere in the sim.
##
## Determinism: every answer below is a pure function of (x, z) and the world
## seed. The adopted plans memoise aggressively (region caches, river traces),
## but those caches are performance-only -- they never change an answer -- and
## everything here runs synchronously in-process, so the sim never waits on
## rendering, streaming, or another thread. The first samples of a seed are
## expensive (the cold river trace and hydrostatic fill cost tens of seconds
## near the origin, measured in tools/adopted_ground_probe.gd); that is why
## one AdoptedGround is shared per seed per process.
class_name AdoptedGround

## How far the water surface sits below the bed on dry ground, so a dry
## column's two surfaces are unambiguously ordered. Matches the adopted
## stack's own dry-shore depth (WaterField.SHORE_DRY_DEPTH).
const DRY_DROP := 0.5

## How far out the standing-water probe looks, in world units. Standing water
## (a pond, a lake) is hydrostatically filled to one flat level; a river's
## level follows the ground downhill. One and a half fill-lattice cells
## (WaterField.FILL_STEP = 6.0) is far enough to see a river fall and near
## enough to stay inside a small pond's basin.
const STANDING_PROBE := 9.0

## How much the water surface may vary across the probe and still count as
## standing. A pond's fill level is exact; a river drops more than this over
## STANDING_PROBE except on a dead-flat reach, which reads as standing --
## an acceptable blur, since the distinction only steers village siting.
const STANDING_EPS := 0.01

## How far from dry land water has to be for that land to count as a bank, and
## how many directions the test looks in.
##
## Banks are where the scatter layer puts reeds, cattails and lily pads, and
## where a path meeting one becomes a bridge. The base has a shore *distance*
## (WaterFieldContext.shore_distance_at) but reaching it obliges every block
## cache to carry a shore-contour limit, which is a streaming cost paid on
## every block for an answer four layers want at a handful of positions. So
## this stays what it has always been in this project: dry here, wet within
## reach in one of eight directions. Eight is enough to catch a channel from
## any angle without making the query expensive.
const BANK_REACH := 2.0
const BANK_DIRECTIONS := 8

## How many block-cache entries each of the two field caches may hold. A block
## is 192 world units square and its entry is dominated by the water context,
## which costs on the order of a hundred megabytes to hold and about two
## seconds to rebuild (measured in the cycle-3726 memory probe) -- so this is
## a memory ceiling first and a performance knob second. Sixteen blocks cover
## every window the sim-layer suites sweep and any fight or walk's working
## set; a survey that ranges wider evicts and rebuilds, which costs seconds,
## not correctness: every answer is a pure function of seed and position.
const FIELD_BLOCKS := 16

## How many seeds' contexts are kept alive at once, oldest dropped first. One
## is the game (a process lives in one world); the second is for the suites,
## which routinely hold two queries side by side to check that different
## seeds differ. Beyond that a suite walking a seed list (eight in the
## settlement shore check) would otherwise accumulate every world it visited:
## the certification batch reached 19 GB and the kernel killed it. Dropping a
## seed loses only time -- a revisit pays the cold build again -- and each
## eviction also empties the adopted WaterField's static caches (see
## _purge_water_statics below), because those pin every visited seed whole.
const SHARED_SEEDS := 2

## One shared context per seed per process, most recently used last. The plans
## under a context memoise their expensive work (river traces, region builds)
## per instance, so two contexts for one seed would pay the cold cost twice
## for identical answers.
static var _shared: Dictionary = {}

## The seed the whole adopted stack descends from.
var world_seed: int = 0

## Their water plan: where rivers run and ponds stand, and what they carve.
var water_plan: WaterPlan = null

## Their heightfield with the water plan wired in: the carved, storey-quantised
## ground everything stands on.
var height_plan: HeightfieldPlan = null

## The same heightfield without the water wired: the uncarved ground, for the
## few callers reasoning about the carving itself.
var base_plan: HeightfieldPlan = null

## Block cache binding the carved plan to O(1) region and water lookups.
var fields: WorldFieldBlockCache = null

## Block cache for the uncarved plan. Its water() is never called; the water
## plan handed to it only satisfies the cache's constructor.
var base_fields: WorldFieldBlockCache = null


static func shared_for_seed(seed_value: int) -> AdoptedGround:
	if _shared.has(seed_value):
		# Re-append so the dictionary's insertion order stays the recency
		# order the eviction below reads.
		var kept: AdoptedGround = _shared[seed_value]
		_shared.erase(seed_value)
		_shared[seed_value] = kept
		return kept
	if _shared.size() >= SHARED_SEEDS:
		while _shared.size() >= SHARED_SEEDS:
			_shared.erase(_shared.keys()[0])
		_purge_water_statics()
	_shared[seed_value] = AdoptedGround.new(seed_value)
	return _shared[seed_value]


## Empty the adopted WaterField's static caches. Called only when a seed is
## evicted above, which a game process (one seed for its whole life) never
## does -- so the adopted stack's own behaviour is untouched in play.
##
## These statics are why eviction alone was not enough: their values hold
## regions, and a region holds its plan, so every seed a process ever visited
## stayed pinned whole. Measured in the cycle-3726 memory probe: three worlds
## of three seeds left 9362 MB allocated after every reference was dropped,
## and clearing these three dictionaries returned the process to 70 MB. They
## are pure caches -- rebuilt lazily, about two seconds per water block -- so
## the surviving seed loses warmth here, never an answer.
static func _purge_water_statics() -> void:
	WaterField._profiles_lock.lock()
	WaterField._profiles.clear()
	WaterField._trace_regions.clear()
	WaterField._profiles_lock.unlock()
	WaterField._basin_lock.lock()
	WaterField._basin_cache.clear()
	WaterField._basin_lock.unlock()


func _init(seed_value: int = 0) -> void:
	world_seed = seed_value
	water_plan = TerrainWorldTuning.make_water(seed_value)
	height_plan = TerrainWorldTuning.make_heightfield(seed_value, water_plan)
	base_plan = TerrainWorldTuning.make_heightfield(seed_value)
	fields = WorldFieldBlockCache.new(height_plan, water_plan, 0.0, 0.0, FIELD_BLOCKS)
	base_fields = WorldFieldBlockCache.new(base_plan, water_plan, 0.0, 0.0, FIELD_BLOCKS)


# ---------------------------------------------------------------------------
# The land
# ---------------------------------------------------------------------------

## The carved ground height: what you stand on, rivers and basins already cut.
##
## This is the height the terrain is meshed at, so a river bed is a real dip in
## the geometry rather than a texture on a flat plain.
func ground_height(x: float, z: float) -> float:
	return TerrainSurfaceField.surface_y(fields.region_at(Vector2(x, z)), x, z)


## The uncarved ground height: the land before water was cut out of it.
##
## Wanted only by things reasoning about the carving itself. Everything that
## means "the ground" wants ground_height().
func base_height(x: float, z: float) -> float:
	return TerrainSurfaceField.surface_y(base_fields.region_at(Vector2(x, z)), x, z)


# ---------------------------------------------------------------------------
# The water
# ---------------------------------------------------------------------------

## The two surfaces of the water column here: x = the bed you would stand on,
## y = the water surface, below the bed on dry ground. This is the adopted
## stack's hydrostatic answer in the sim's own column convention: wet exactly
## when y > x, which their fill guarantees by its own wetness epsilon.
func water_column(x: float, z: float) -> Vector2:
	var point := Vector2(x, z)
	var bed := ground_height(x, z)
	var context := fields.water_at(point)
	if context.is_wet(point):
		return Vector2(bed, context.level_at(point))
	return Vector2(bed, bed - DRY_DROP)


## Whether the adopted water plan says this position is under water.
func is_wet(x: float, z: float) -> bool:
	var point := Vector2(x, z)
	return fields.water_at(point).is_wet(point)


## How deep the water is here, in world units. Zero on dry land.
func water_depth(x: float, z: float) -> float:
	var column := water_column(x, z)
	return maxf(0.0, column.y - column.x)


## How high the water surface reaches here. Below the bed on dry land, which is
## the same thing as saying there is no water.
func water_surface(x: float, z: float) -> float:
	return water_column(x, z).y


## Whether this position is a bank: dry ground with water within reach.
##
## Asking for it here rather than working it out again in each of the layers
## that want it is what keeps them all agreeing about where the water's edge
## is.
func is_bank(x: float, z: float, reach: float = BANK_REACH) -> bool:
	if is_wet(x, z):
		return false
	for direction in BANK_DIRECTIONS:
		var angle := TAU * float(direction) / float(BANK_DIRECTIONS)
		if is_wet(x + cos(angle) * reach, z + sin(angle) * reach):
			return true
	return false


## The level standing water is filled to here, or the dry column's sunken
## surface. Standing water -- a pond or lake, filled to one flat level -- is
## told from a river by probing the level a little way out: a pond's level
## holds, a river's falls with the ground.
##
## The village layer is the only caller: a site is refused a running-water
## shore, and accepted on a still one. The adopted stack has no water table to
## compare against, so "still" is measured rather than looked up.
func standing_level(x: float, z: float) -> float:
	var column := water_column(x, z)
	if column.y <= column.x:
		return column.y
	for direction in 4:
		var angle := TAU * float(direction) / 4.0
		var probe := Vector2(x + cos(angle) * STANDING_PROBE, z + sin(angle) * STANDING_PROBE)
		var context := fields.water_at(probe)
		if not context.is_wet(probe):
			continue
		if absf(context.level_at(probe) - column.y) > STANDING_EPS:
			return column.y - 1.0
	return column.y


# ---------------------------------------------------------------------------
# The biomes
# ---------------------------------------------------------------------------

## Their seven biome weights folded onto this project's five named biomes.
##
## Five of their names are this project's own roster, kept one for one. The
## two extras fold into meadow, and that fold is a recorded decision
## (M-biome-roster-stays-five-for-now), not a default: amber_heath is open
## warm ground and jade_wetlands common lush lowland, and both are open,
## walkable, unremarkable country -- which is what meadow is here. Folding
## jade_wetlands into twilight_marsh instead was considered and rejected: the
## marsh is a rare eerie pocket in this design and jade_wetlands is not rare,
## so that fold would have put marsh fog over a fifth of the world. Adopting
## all seven names reaches the palette, the prop tags, the scatter catalog and
## the item drops, which is its own item rather than this one.
func weights(x: float, z: float) -> Dictionary:
	var theirs := Helper.biome_weights5(Vector3(x, 0.0, z), world_seed)
	return {
		BiomeCatalog.MEADOW: float(theirs[&"meadow"])
			+ float(theirs[&"amber_heath"]) + float(theirs[&"jade_wetlands"]),
		BiomeCatalog.DEEP_FOREST: float(theirs[&"deep_forest"]),
		BiomeCatalog.HIGHLAND: float(theirs[&"highland"]),
		BiomeCatalog.BLOSSOM_GROVE: float(theirs[&"blossom_grove"]),
		BiomeCatalog.TWILIGHT_MARSH: float(theirs[&"twilight_marsh"]),
	}


## The name of the biome with the largest share here.
##
## Ties are broken by the catalog's fixed order rather than by whichever was
## looked at first, so the answer does not depend on how a dictionary happened
## to be walked.
func biome(x: float, z: float) -> String:
	var mix := weights(x, z)
	var best := BiomeCatalog.IDS[0]
	var best_weight := -1.0
	for id in BiomeCatalog.IDS:
		var weight := float(mix[id])
		if weight > best_weight:
			best_weight = weight
			best = id
	return best


## The blended profile here: the look of this position, as plain data.
##
## What comes back is built fresh from the catalog on every call, so it is a
## detached value that no one else holds a reference to. Colours, fog, ambient
## light and foliage density are all weighted averages, which is why walking
## across a border shifts the mood gradually instead of switching it.
func profile(x: float, z: float) -> SimBiomeProfile:
	return BiomeCatalog.blend(weights(x, z))


## The adopted style axes in this project's convention:
## x = how wooded, y = how rocky, z = how wet.
func axes(x: float, z: float) -> Vector3:
	var pos := Vector3(x, 0.0, z)
	return Vector3(
		Helper.biome_forest01(pos, world_seed),
		Helper.biome_rocky01(pos, world_seed),
		Helper.biome_moisture01(pos, world_seed),
	)


## How wet the land is here, in [0, 1]: the moisture axis on its own.
func moisture(x: float, z: float) -> float:
	return Helper.biome_moisture01(Vector3(x, 0.0, z), world_seed)


## How much of a marsh pocket there is here, in [0, 1].
func marsh_strength(x: float, z: float) -> float:
	return Helper.biome_marsh_pocket01(Vector3(x, 0.0, z), world_seed)


## Just the ground colour here. The mesher wants this per corner and nothing
## else, and going through it avoids building a whole profile per corner.
func ground_tint(x: float, z: float) -> Color:
	return _blended_tint(x, z, BiomeCatalog.ground_tint_of)


## Just the water colour here, wanted per vertex of the water sheet the same
## way the ground colour is wanted per corner of a chunk.
func water_tint(x: float, z: float) -> Color:
	return _blended_tint(x, z, BiomeCatalog.water_tint_of)


## Just the rock colour here, wanted per vertex of a cliff the same way. The
## rim of a floating island is the one that asks for it so far.
func rock_tint(x: float, z: float) -> Color:
	return _blended_tint(x, z, BiomeCatalog.rock_tint_of)


## One of the catalog's colours, averaged over whichever biomes have a share of
## this position. Which colour is the caller's business; the weighting is the
## same for all of them, and is the same weighting a whole profile would use.
func _blended_tint(x: float, z: float, colour_of: Callable) -> Color:
	var mix := weights(x, z)
	var tint := Color(0, 0, 0)
	for id in BiomeCatalog.IDS:
		var share := float(mix[id])
		if share > 0.0:
			tint += (colour_of.call(id) as Color) * share
	return tint
