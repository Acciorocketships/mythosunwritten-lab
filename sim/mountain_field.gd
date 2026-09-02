extends RefCounted
## Where the mountains are, and how high they stand: the uplift laid over the
## base height field.
##
## The base field is one continuous surface of value noise -- broad hills with
## smaller bumps riding on them, nine units of amplitude, and nothing anywhere
## in the world taller than a house. This is the second, much broader field over
## it, and it is what makes some of the world *mountain*.
##
## Three ideas, and each of them is load-bearing.
##
## ## 1. Ridged, not smooth
##
## Ordinary value noise makes rounded swells: every direction off a summit is
## the same, and the whole thing reads as a hill however tall you make it.
## Folding each layer through `1 - |value|` instead puts the layer's maximum
## along the *curve* where the raw field crosses zero, which is a line rather
## than a point. So the field's tops are ridges, and its sides are the flanks
## between them.
##
## That is not only how a mountain looks; it is how one is climbed. A ridge
## crest runs nearly level along its own length while falling away steeply on
## both sides, so the crest is a route and the flank is a wall -- which is what
## the acceptance means by steepness being a deliberate face rather than an
## accident. Nothing in this file searches for a route or knows what one is; the
## routes are a consequence of the shape, and tools/measure_mountains.gd goes
## and finds them by walking the real height function.
##
## ## 2. Masked, so a mountain is a place
##
## The uplift is multiplied by a mask in [0, 1] that is *exactly* zero over most
## of the world -- exactly, because `smoothstep` below its low edge returns 0.0
## and multiplying by 0.0 leaves a float alone. So the ground far from a range
## is not "almost the same" as it was before this field existed; it is the same
## number, bit for bit. That is what makes "mountains are regional" a thing that
## can be shown by diffing two runs rather than argued about.
##
## ## 3. Driven by the rocky axis, so highland means highland
##
## The mask is the product of two gates. One is the biome map's own rocky axis:
## the axis that until now reached the palette, the fog and the boulder scatter
## and never reached the height of anything. The other is a very broad field of
## this layer's own, which breaks the rocky country up into separate ranges
## instead of lifting every rocky region at once, and whose long period is what
## gives a massif a skirt hundreds of units wide to walk up.
##
## Both gates have to open. Rocky country outside a range is the windswept
## grey-green highland it always was; a range that falls on soft country never
## rises. Where they meet, the highland stands high.
##
## Like every other field in the stack it is a pure function of (x, z) and the
## world seed: no state that sampling changes, no notion of chunks, no clock.
class_name MountainField

# --- the ridges -----------------------------------------------------------

## World units across one lattice cell of the coarsest ridge layer: roughly how
## far apart two neighbouring ridge lines are. Several hundred, so a range is a
## thing you see across the valley rather than a bump you step over -- and small
## enough that a three-ridge range fits inside the thousand units of ground the
## distant-ground rings draw.
const RIDGE_PERIOD := 600.0

## Peak height of the coarsest ridge layer, in world units. With the two finer
## layers riding on it the uplift reaches RIDGE_AMPLITUDE * (1 + 1/2 + 1/4) --
## about 59 units -- where the mask is fully open.
const RIDGE_AMPLITUDE := 44.0

## How many ridge layers are summed. Three: enough that a flank has spurs and
## gullies rather than being a single plane, few enough that the crest lines of
## the coarsest layer still run unbroken for hundreds of units, which is what a
## route up follows.
const RIDGE_OCTAVES := 4

## Each ridge layer after the first is this much finer and this much shorter.
## Halving the height while doubling the frequency keeps every layer's steepest
## slope the same, so the finer layers add texture to a flank without making it
## a cliff.
const RIDGE_LACUNARITY := 2.0
const RIDGE_GAIN := 0.5

# --- where the ranges are -------------------------------------------------

## World units across one lattice cell of the range field. Far broader than the
## ridges themselves: a range is a region of the world, and the width of this
## field is what sets how long the walk from the plain to the foot of the
## mountain is.
const RANGE_PERIOD := 1500.0

## Layers of the range field. Two -- one to place the ranges, one to make their
## outlines irregular. More would put fine detail into the mask, and fine detail
## in the mask is a cliff at the foot of the mountain rather than a slope.
const RANGE_OCTAVES := 2

## The range field values the mask opens across. Below the first there is no
## uplift at all anywhere; above the second the range gate is fully open.
const RANGE_LOW := 0.46
const RANGE_HIGH := 0.78

## The rocky-axis values the mask opens across. The band is deliberately wide:
## the rocky axis is a far finer field than the range field (its broadest layer
## is 330 units against 1500), so a narrow band here would turn its own wobbles
## into a ring of cliffs around every mountain. Spread over most of the axis, it
## instead makes rockiness a gradient of how much the land is lifted.
const ROCKY_LOW := 0.34
const ROCKY_HIGH := 0.86

## Seed offsets, so this layer's two fields are independent of each other and of
## every other field in the stack. Arbitrary large odd numbers whose only job is
## to differ from the ones already in use.
const RANGE_SEED_OFFSET := 0x27D4EB2F
const RIDGE_SEED_OFFSET := 0x165667B1

## The seed this whole uplift descends from.
var world_seed: int = 0

## The biome map the rocky axis is read off. The same one the rest of the stack
## uses, so "this ground is highland" and "this ground is lifted" are two
## readings of one field rather than two fields that happen to agree.
var biomes: BiomeField = null

var _ridge: ValueNoise = null
var _range: ValueNoise = null


func _init(seed_value: int = 0, biome_field: BiomeField = null) -> void:
	world_seed = seed_value
	biomes = biome_field if biome_field != null else BiomeField.new(seed_value)
	_ridge = ValueNoise.new(
		seed_value + RIDGE_SEED_OFFSET,
		RIDGE_OCTAVES,
		RIDGE_PERIOD,
		RIDGE_AMPLITUDE,
		RIDGE_LACUNARITY,
		RIDGE_GAIN,
	)
	_range = ValueNoise.new(seed_value + RANGE_SEED_OFFSET, RANGE_OCTAVES, RANGE_PERIOD)


## How much this layer adds to the ground here, in world units. Zero -- exactly
## zero -- over most of the world.
func uplift_at(x: float, z: float) -> float:
	var mask := mask_at(x, z)
	if mask <= 0.0:
		return 0.0
	return mask * _ridge.ridged_sample(x, z)


## How open the mask is here, in [0, 1]: how much of this layer's full height
## this position is allowed. Both gates have to open, so this is their product.
func mask_at(x: float, z: float) -> float:
	var range_gate := smoothstep(RANGE_LOW, RANGE_HIGH, _range.unit_sample(x, z))
	if range_gate <= 0.0:
		return 0.0
	var rocky_gate := smoothstep(ROCKY_LOW, ROCKY_HIGH, biomes.axes_at(x, z).y)
	return range_gate * rocky_gate


## The unmasked ridges, in world units: what the uplift would be if the mask
## were fully open here. Wanted only by anything reasoning about the layer
## itself -- everything that wants the ground wants uplift_at().
func ridge_at(x: float, z: float) -> float:
	return _ridge.ridged_sample(x, z)
