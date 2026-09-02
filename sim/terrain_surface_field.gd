extends RefCounted
## The ground's height, as a function of where you are standing.
##
## This is the base layer of the generation stack: one continuous surface,
## sampled per world position. It is a pure function of (x, z) and the world
## seed -- it holds no state that sampling changes, it does not know that chunks
## exist, and it never looks at a clock. Two samples of the same position agree
## no matter which chunk asked, in what order, or in which process.
##
## The shape is two fields added together.
##
## The first is fractal value noise (ValueNoise): a few layers of smoothly
## interpolated random values, each layer half as tall and twice as fine as the
## one before, which is what gives broad hills with smaller bumps riding on
## them. The biome fields are the same arithmetic with other seeds and periods,
## which is why the noise itself lives in its own class. On its own it gives the
## whole world about thirty units of relief, top to bottom, over kilometres.
##
## The second is MountainField: a far broader ridged field, masked so that it is
## exactly zero over most of the world and reaches sixty-odd units where it is
## not. It is added here rather than composed further up the stack because every
## layer above wants it to be simply *the ground* -- the water carves its
## channels into the mountains it does not reach, a village refuses a slope it
## cannot level, a road goes round, and the mesher draws the sum without knowing
## there were two fields. `height_at` remains a pure function of position and
## seed, and outside a range it answers the same float it answered before the
## mountains existed.
class_name TerrainSurfaceField

## How many layers of noise are summed. More layers means finer detail and more
## work per sample.
const OCTAVES := 4

## World units across one lattice cell of the coarsest layer -- roughly the
## width of the broadest hills.
const BASE_PERIOD := 96.0

## Peak height of the coarsest layer, in world units.
const BASE_AMPLITUDE := 9.0

## Each layer after the first is this much finer...
const LACUNARITY := 2.0

## ...and this much shorter.
const GAIN := 0.5

## The seed this whole surface descends from.
var world_seed: int = 0

## The mountains laid over the hills: where they are and how high they stand.
var mountain_field: MountainField = null

var _noise: ValueNoise = null


## The biome map is taken rather than built where the caller already has one,
## because the mountain layer reads the rocky axis off it and two BiomeFields for
## one seed would be two copies of the same answers. Left out, one is built --
## a field for a seed is the same field however it was reached.
func _init(seed_value: int = 0, biome_field: BiomeField = null) -> void:
	world_seed = seed_value
	_noise = ValueNoise.new(
		seed_value, OCTAVES, BASE_PERIOD, BASE_AMPLITUDE, LACUNARITY, GAIN
	)
	mountain_field = MountainField.new(seed_value, biome_field)


## The ground height at a world position, in world units.
##
## This is the land before water is cut out of it. What anything else means by
## "the ground" is TerrainQuery.ground_height_at(), which is this with the
## rivers and lake basins carved in.
func height_at(x: float, z: float) -> float:
	return _noise.sample(x, z) + mountain_field.uplift_at(x, z)


## Just the hills: the height field as it was before there were mountains in the
## world. Wanted only by anything reasoning about the uplift itself -- what a
## range added here, and what the ground would have been without it.
func hill_height_at(x: float, z: float) -> float:
	return _noise.sample(x, z)


## How much the mountain layer adds here, in world units. Exactly zero over most
## of the world.
func uplift_at(x: float, z: float) -> float:
	return mountain_field.uplift_at(x, z)


## How open the mountain mask is here, in [0, 1]. Zero over most of the world;
## one where a range and rocky country coincide. Wanted by anything asking where
## the mountains are rather than how high they stand.
func uplift_mask_at(x: float, z: float) -> float:
	return mountain_field.mask_at(x, z)
