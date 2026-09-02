extends RefCounted
## Where the world's water is, and how deep, at a world position.
##
## This is the third layer of the generation stack, over the ground's height and
## the biomes. It answers two things about every position at once: how low the
## ground has been cut there, and how high the water standing on it reaches. The
## difference between the two is the depth, and a position is water exactly when
## that difference is positive -- so the shoreline is not a threshold anyone
## chose, it is the line where those two surfaces cross.
##
## Water comes from two sources that share one arithmetic:
##
## * **Rivers** are the ridge of a noise field -- the set of places where the
##   field is near zero, which in two dimensions is a long sinuous band rather
##   than a blob. Along that band the ground is cut into a channel, and the water
##   surface follows the ground downhill a little way below it, so a river reads
##   as a stream in a gully however the land tilts. The band's edge is where the
##   falling surface meets the rising bed, so a river tapers into its banks
##   instead of ending at a wall.
## * **Ponds and lakes** are wherever the ground has fallen below the local water
##   table -- a broad, slowly wandering level that rises in wet country and falls
##   in dry. Standing water is flat, because the table is what it is level with,
##   and a basin deepens its own bed so a pond is a pond rather than a puddle.
##
## Like the height and the biomes, it is a pure function of (x, z) and the world
## seed. It stores nothing that sampling changes, it does not know that chunks
## exist, and it never looks at a clock -- so whether you are standing in water
## is the same answer whichever chunk asked, in what order, and in which process.
class_name WaterField

## World units across the broadest bend of the river field. Wider than a biome
## is not wanted here: a river should cross a region, not define one.
const RIVER_PERIOD := 300.0

## Layers in the river field. Two: the first lays the course, the second gives
## it meanders. More would break the band into disconnected pools, because the
## ridge of a rough field is not a continuous line.
const RIVER_OCTAVES := 2

## How near the ridge of the river field the band begins, in [0, 1]. Larger
## means narrower rivers. The band is a smooth ramp from here up to the ridge
## itself, so nothing about a river's width is a step.
const RIVER_EDGE := 0.972

## How deep a full-strength river cuts its channel below the surrounding ground.
const RIVER_DEPTH := 2.4

## How far a river's surface sits below the uncarved ground beside it.
const RIVER_SINK := 0.25

## How much further the river's surface falls per unit of lost band strength.
## This is what closes a river off at its banks: towards the edge of the band
## the bed rises faster than nothing while the surface drops by this, and where
## they cross the water simply stops. With these numbers water reaches out to
## about six tenths of the band's strength.
const RIVER_EDGE_DROP := 3.0

## Rivers thin out as the land rises: full strength at or below the first
## height, gone at or above the second, so the highest ground stays dry and a
## stream tapers out towards its source rather than running over a summit.
const RIVER_DRY_LOW := 2.0
const RIVER_DRY_HIGH := 7.5

## World units across the broadest swell of the water table, and how many layers
## it has. Very wide and very smooth: a table that wobbled would put lakes on
## hillsides.
const TABLE_PERIOD := 520.0
const TABLE_OCTAVES := 2

## How far the table wanders above and below its resting level, in world units.
const TABLE_AMPLITUDE := 2.6

## Where the table sits when its own field and the moisture there are neutral.
## Well below the ground's average, because a table at the average would drown
## half the world.
const TABLE_BASE := -8.4

## How much higher the table stands in the wettest country than in the driest.
## This is the one place the biome layer reaches into the water: marshes and
## other wet ground get more standing water for the same terrain.
const MOISTURE_LIFT := 2.4

## How far the ground has to fall below the table before a basin counts as full
## strength, in world units. It is a ramp rather than a step so that the middle
## of a pond deepens smoothly out from its shore.
const LAKE_FEATHER := 1.2

## How much a full-strength basin deepens its own bed, in world units.
const LAKE_DEPTH := 1.6

## How far from dry land water has to be for that land to count as a bank.
const BANK_REACH := 2.0

## How many directions a bank test looks in. Eight is enough to catch a channel
## from any angle without making the query expensive.
const BANK_DIRECTIONS := 8

## Seed offsets, so the two water fields are independent of each other and of
## the height and biome fields. Arbitrary large odd numbers -- their only job is
## to be different from the offsets already in use.
const RIVER_SEED_OFFSET := 0x7F4A7C15
const TABLE_SEED_OFFSET := 0x6A09E667

## The seed this whole water map descends from.
var world_seed: int = 0

## The uncarved ground. Water is cut out of it, so it has to be asked first.
var surface: TerrainSurfaceField = null

## Which biome the ground is. Only the moisture axis is read, and only to decide
## how high the water table stands.
var biomes: BiomeField = null

var _river: ValueNoise = null
var _table: ValueNoise = null


func _init(surface_field: TerrainSurfaceField = null, biome_field: BiomeField = null) -> void:
	surface = surface_field
	world_seed = surface_field.world_seed if surface_field != null else 0
	biomes = biome_field if biome_field != null else BiomeField.new(world_seed)
	_river = ValueNoise.new(world_seed + RIVER_SEED_OFFSET, RIVER_OCTAVES, RIVER_PERIOD)
	_table = ValueNoise.new(
		world_seed + TABLE_SEED_OFFSET, TABLE_OCTAVES, TABLE_PERIOD, TABLE_AMPLITUDE
	)


## The water at one position, as the two surfaces that define it:
## x = the height of the bed, the carved ground you would stand on,
## y = the height of the water surface.
##
## Everything else this file answers is read off those two. Depth is the surface
## above the bed, and being water is having any -- so the two can never drift
## apart into a position that is water but has no depth, or has depth but is dry.
##
## They are computed together because they share their inputs: the uncarved
## height, the table and the river band are each wanted by both, and sampling a
## noise field is the expensive part.
func sample_column(x: float, z: float) -> Vector2:
	var base := surface.height_at(x, z)
	var table := table_level_at(x, z)

	# How much of a basin this is: nothing at the shoreline, full a little way
	# below it.
	var lake := smoothstep(0.0, LAKE_FEATHER, table - base)
	# How much of a river channel this is, thinning out as the land rises.
	var river := river_band_at(x, z) * (1.0 - smoothstep(RIVER_DRY_LOW, RIVER_DRY_HIGH, base))

	# The bed is the uncarved ground with both channels cut into it. This is the
	# carving the rest of the project sees: it is the height the terrain is
	# meshed at, not a separate hole punched afterwards.
	var bed := base - LAKE_DEPTH * lake - RIVER_DEPTH * river

	# The surface is whichever of the two waters stands higher here. Standing
	# water is level with the table; running water follows the ground down, and
	# falls away sharply as the river band weakens, which is what ends a river
	# at its banks rather than at a cliff of water.
	var level := maxf(table, base - RIVER_SINK - (1.0 - river) * RIVER_EDGE_DROP)

	return Vector2(bed, level)


## The ground you would stand on: the height field with the water's channels and
## basins cut into it.
func bed_height_at(x: float, z: float) -> float:
	return sample_column(x, z).x


## How high the water surface reaches here. Below the bed on dry land, which is
## the same thing as saying there is no water.
func surface_level_at(x: float, z: float) -> float:
	return sample_column(x, z).y


## How deep the water is here, in world units. Zero on dry land.
func depth_at(x: float, z: float) -> float:
	var column := sample_column(x, z)
	return maxf(0.0, column.y - column.x)


## Whether this position is water: whether the water surface is above the bed.
func is_water_at(x: float, z: float) -> bool:
	var column := sample_column(x, z)
	return column.y > column.x


## Whether this position is a bank: dry ground with water within reach.
##
## Banks are where the later layers put reeds, cattails and lily pads, and where
## a path meeting one becomes a bridge. Asking for it here rather than working
## it out again in each of those layers is what keeps them all agreeing about
## where the water's edge is.
func is_bank_at(x: float, z: float, reach: float = BANK_REACH) -> bool:
	if is_water_at(x, z):
		return false
	for direction in BANK_DIRECTIONS:
		var angle := TAU * float(direction) / float(BANK_DIRECTIONS)
		if is_water_at(x + cos(angle) * reach, z + sin(angle) * reach):
			return true
	return false


## How high standing water stands here: the local water table.
##
## Broad and slow, lifted where the ground is wet. It is defined everywhere, dry
## land included, where it simply sits below the ground.
func table_level_at(x: float, z: float) -> float:
	return TABLE_BASE + _table.sample(x, z) \
		+ MOISTURE_LIFT * (biomes.moisture_at(x, z) - 0.5)


## How much of a river band there is here, in [0, 1], before the land's height
## is taken into account.
##
## The band is the ridge of a noise field: one minus how far the field is from
## its middle. The set of positions where a smooth field sits near one value is
## a curve, which is why this makes a river rather than a patch.
func river_band_at(x: float, z: float) -> float:
	var ridge := 1.0 - absf(2.0 * _river.unit_sample(x, z) - 1.0)
	return smoothstep(RIVER_EDGE, 1.0, ridge)
