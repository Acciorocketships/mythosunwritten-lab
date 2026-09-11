extends RefCounted
## The adopted ground: this repo's discrete sim reading mythosunwritten's
## continuous fields.
##
## The base adoption (see ADOPTION.md) brought in a far richer terrain stack --
## a streamed, storey-quantised heightfield with river carving (HeightfieldPlan
## / TerrainSurfaceField), a hydrostatically filled water plan (WaterPlan /
## WaterFieldContext), and biome fields (Helper.biome_*) -- all pure functions
## of world position and seed. This file is the whole of the seam between that
## stack and this repo's sim: it owns the adopted plans for a seed, and its
## three inner classes stand in for the retired from-scratch ground fields by
## extending them and overriding every sampling primitive, so everything layered
## above (TerrainQuery, IslandField, SettlementField, PathNetwork, the combat
## board, the walk) keeps its one read surface and now reads their ground.
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

## One shared context per seed per process. The plans under it memoise their
## expensive work (river traces, region builds) per instance, so two contexts
## for one seed would pay the cold cost twice for identical answers -- and the
## adopted WaterField keys some static caches by plan instance id, so keeping
## one instance alive per seed also keeps those keys stable.
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
	if not _shared.has(seed_value):
		_shared[seed_value] = AdoptedGround.new(seed_value)
	return _shared[seed_value]


func _init(seed_value: int = 0) -> void:
	world_seed = seed_value
	water_plan = TerrainWorldTuning.make_water(seed_value)
	height_plan = TerrainWorldTuning.make_heightfield(seed_value, water_plan)
	base_plan = TerrainWorldTuning.make_heightfield(seed_value)
	fields = WorldFieldBlockCache.new(height_plan, water_plan, 0.0, 0.0, 128)
	base_fields = WorldFieldBlockCache.new(base_plan, water_plan, 0.0, 0.0, 128)


## The carved ground height: what you stand on, rivers and basins already cut.
func ground_height(x: float, z: float) -> float:
	return TerrainSurfaceField.surface_y(fields.region_at(Vector2(x, z)), x, z)


## The uncarved ground height: the land before water was cut out of it.
func base_height(x: float, z: float) -> float:
	return TerrainSurfaceField.surface_y(base_fields.region_at(Vector2(x, z)), x, z)


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


## The level standing water is filled to here, or the dry column's sunken
## surface. Standing water -- a pond or lake, filled to one flat level -- is
## told from a river by probing the level a little way out: a pond's level
## holds, a river's falls with the ground.
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


## Their seven biome weights folded onto this repo's five named biomes.
##
## Five of their names are this project's own roster, kept one for one. The
## two extras fold into meadow: amber_heath is open warm ground and
## jade_wetlands common lush lowland, and folding both into the open-grass
## baseline keeps highland genuinely rocky and the twilight marsh the rare
## eerie pocket the design asks for. The render seam may later adopt their
## full profile set; this mapping is the sim's until it does.
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


## The adopted style axes in the old field's convention:
## x = how wooded, y = how rocky, z = how wet.
func axes(x: float, z: float) -> Vector3:
	var pos := Vector3(x, 0.0, z)
	return Vector3(
		Helper.biome_forest01(pos, world_seed),
		Helper.biome_rocky01(pos, world_seed),
		Helper.biome_moisture01(pos, world_seed),
	)


## The old BiomeField, answering from the adopted biome fields. Only the
## sampling primitives are overridden; every derived answer (biome_at,
## profile_at, the tints) is inherited and routes through weights_at.
class Biomes extends BiomeField:
	var ground: AdoptedGround = null

	func _init(adopted: AdoptedGround) -> void:
		super(adopted.world_seed)
		ground = adopted

	func axes_at(x: float, z: float) -> Vector3:
		return ground.axes(x, z)

	func moisture_at(x: float, z: float) -> float:
		return ground.axes(x, z).z

	func marsh_strength_at(x: float, z: float) -> float:
		return float(ground.weights(x, z)[BiomeCatalog.TWILIGHT_MARSH])

	func weights_at(x: float, z: float) -> Dictionary:
		return ground.weights(x, z)


## The old uncarved-surface field, answering from the adopted heightfield.
## There is no separate mountain layer any more -- the adopted field's ridged
## spine is simply part of the ground -- so the uplift decomposition answers
## zero and the hills are the whole surface.
class Surface extends SimTerrainSurfaceField:
	var ground: AdoptedGround = null

	func _init(adopted: AdoptedGround, biome_field: BiomeField) -> void:
		super(adopted.world_seed, biome_field)
		ground = adopted

	func height_at(x: float, z: float) -> float:
		return ground.base_height(x, z)

	func hill_height_at(x: float, z: float) -> float:
		return ground.base_height(x, z)

	func uplift_at(_x: float, _z: float) -> float:
		return 0.0

	func uplift_mask_at(_x: float, _z: float) -> float:
		return 0.0


## The old water field, answering from the adopted water plan. sample_column
## is the primitive every inherited answer (depth_at, is_water_at, is_bank_at,
## surface_level_at, bed_height_at) reads through, so overriding it and the
## two callers that want more than the column is the whole rebind.
class Water extends SimWaterField:
	var ground: AdoptedGround = null

	func _init(
		adopted: AdoptedGround, surface_field: SimTerrainSurfaceField, biome_field: BiomeField
	) -> void:
		super(surface_field, biome_field)
		ground = adopted

	func sample_column(x: float, z: float) -> Vector2:
		return ground.water_column(x, z)

	func is_water_at(x: float, z: float) -> bool:
		return ground.is_wet(x, z)

	## The old table was how standing water was told from running water: a
	## pond's surface equals it, a river's does not. The adopted stack has no
	## table; what it has is hydrostatic fill, flat over standing water, so
	## this answers the column's own level exactly where that level stands
	## still and something strictly below it where the water is running.
	func table_level_at(x: float, z: float) -> float:
		return ground.standing_level(x, z)
