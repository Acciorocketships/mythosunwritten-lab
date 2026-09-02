extends RefCounted
## Which biome the world is, at a world position.
##
## Three continuous axes are sampled per position -- how wooded the land is, how
## rocky it is, and how wet it is -- plus a fourth, sparse field that carves out
## the twilight marsh pockets. The axes resolve into the named biomes of the
## design by soft nearest-prototype: every biome sits at a point in axis space,
## and its share of a position is a smooth kernel of the distance from that
## point, so a position is never wholly one biome and the shares slide
## continuously as you walk. Borders blend because nothing here thresholds.
##
## Like the height field, it is a pure function of (x, z) and the world seed. It
## stores nothing that sampling changes, it does not know that chunks exist, and
## it never looks at a clock -- so the biome under your feet is the same
## whichever chunk asked, in what order it was asked, and in which process.
##
## The full reasoning behind the numbers below -- why these prototypes, why this
## blend width, why the marsh is a separate field rather than a corner of the
## axis space -- is written down in reports/biome-resolution.md.
class_name BiomeField

## World units across the broadest feature of each axis. Each is a different
## width so the three do not line up into visible stripes, and all are far
## wider than a chunk so a biome is a region you walk through rather than a
## patch you step over.
const FOREST_PERIOD := 260.0
const ROCKY_PERIOD := 330.0
const MOISTURE_PERIOD := 205.0

## The marsh pocket field is finer: a pocket should be a hollow you come across,
## not a province.
const POCKET_PERIOD := 150.0

## Layers per axis. Three gives a region an irregular coastline without breaking
## it into noise.
const AXIS_OCTAVES := 3

## The pocket field is smoother still, so a pocket has one clear middle.
const POCKET_OCTAVES := 2

## Each biome's home in (forest, rocky, moisture) space, every axis in [0, 1].
const PROTOTYPES := {
	BiomeCatalog.MEADOW: Vector3(0.30, 0.28, 0.42),
	BiomeCatalog.DEEP_FOREST: Vector3(0.80, 0.34, 0.60),
	BiomeCatalog.HIGHLAND: Vector3(0.36, 0.78, 0.34),
	BiomeCatalog.BLOSSOM_GROVE: Vector3(0.58, 0.22, 0.84),
}

## How wide a border is, in axis units squared. A biome's share of a position is
## exp(-distance^2 / BLEND_TAU), so this sets how far from a prototype the biome
## still has a say. Larger means softer, wider borders and more mixing; smaller
## means the middle of every region is pure and the borders get sharp.
const BLEND_TAU := 0.085

## The pocket field values a marsh fades in and out across. Below the first
## value there is no marsh at all; above the second the pocket is fully marsh;
## between them the two mix, which is what makes the rim of a pocket a gradient.
const POCKET_LOW := 0.72
const POCKET_HIGH := 0.90

## Seed offsets, so the four fields are independent of each other and of the
## ground's height. Arbitrary large odd numbers -- their only job is to be
## different.
const FOREST_SEED_OFFSET := 0x1B873593
const ROCKY_SEED_OFFSET := 0x2545F491
const MOISTURE_SEED_OFFSET := 0x3C6EF372
const POCKET_SEED_OFFSET := 0x5BD1E995

## The seed this whole biome map descends from.
var world_seed: int = 0

var _forest: ValueNoise = null
var _rocky: ValueNoise = null
var _moisture: ValueNoise = null
var _pocket: ValueNoise = null


func _init(seed_value: int = 0) -> void:
	world_seed = seed_value
	_forest = ValueNoise.new(
		seed_value + FOREST_SEED_OFFSET, AXIS_OCTAVES, FOREST_PERIOD
	)
	_rocky = ValueNoise.new(
		seed_value + ROCKY_SEED_OFFSET, AXIS_OCTAVES, ROCKY_PERIOD
	)
	_moisture = ValueNoise.new(
		seed_value + MOISTURE_SEED_OFFSET, AXIS_OCTAVES, MOISTURE_PERIOD
	)
	_pocket = ValueNoise.new(
		seed_value + POCKET_SEED_OFFSET, POCKET_OCTAVES, POCKET_PERIOD
	)


## The three style axes at a world position, each in [0, 1]:
## x = how wooded, y = how rocky, z = how wet.
func axes_at(x: float, z: float) -> Vector3:
	return Vector3(
		_forest.unit_sample(x, z),
		_rocky.unit_sample(x, z),
		_moisture.unit_sample(x, z),
	)


## How wet the land is here, in [0, 1]: the moisture axis on its own.
##
## The water layer reads this and nothing else of the biome map, to decide how
## high the local water table stands, so wet country gets more standing water
## than dry country does for the same terrain. Exposing the one axis keeps that
## from costing the other three.
func moisture_at(x: float, z: float) -> float:
	return _moisture.unit_sample(x, z)


## How much of a marsh pocket there is here, in [0, 1].
##
## This is its own field rather than a corner of the axis space, because the
## design asks for the marsh to turn up anywhere as an isolated eerie hollow --
## including in the middle of a bright meadow. It depends on position and seed
## only: there is no distance-from-spawn term anywhere in this file, so a pocket
## is exactly as likely at the frontier as at the doorstep.
func marsh_strength_at(x: float, z: float) -> float:
	return smoothstep(POCKET_LOW, POCKET_HIGH, _pocket.unit_sample(x, z))


## Every biome's share of a world position: {biome id -> weight}, summing to 1.
##
## The four distributed biomes divide up whatever the marsh does not claim, in
## proportion to a smooth kernel of their distance from the position in axis
## space. The marsh is laid over the top rather than competing on the axes,
## which is what lets a pocket sit anywhere without disturbing the map around
## it -- and its rim is a gradient because its strength is one too.
func weights_at(x: float, z: float) -> Dictionary:
	var axes := axes_at(x, z)
	var marsh := marsh_strength_at(x, z)

	var kernels := {}
	var total := 0.0
	for id in PROTOTYPES:
		var home: Vector3 = PROTOTYPES[id]
		var weight := exp(-axes.distance_squared_to(home) / BLEND_TAU)
		kernels[id] = weight
		total += weight

	var weights := {}
	for id in BiomeCatalog.IDS:
		weights[id] = 0.0
	if total > 0.0:
		for id in PROTOTYPES:
			weights[id] = (1.0 - marsh) * float(kernels[id]) / total
	weights[BiomeCatalog.TWILIGHT_MARSH] = marsh
	return weights


## The name of the biome with the largest share here.
##
## Ties are broken by the catalog's fixed order rather than by whichever was
## looked at first, so the answer does not depend on how a dictionary happened
## to be walked.
func biome_at(x: float, z: float) -> String:
	var weights := weights_at(x, z)
	var best := BiomeCatalog.IDS[0]
	var best_weight := -1.0
	for id in BiomeCatalog.IDS:
		var weight := float(weights[id])
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
func profile_at(x: float, z: float) -> BiomeProfile:
	return BiomeCatalog.blend(weights_at(x, z))


## Just the ground colour here. The mesher wants this per corner and nothing
## else, and going through it avoids building a whole profile per corner.
func ground_tint_at(x: float, z: float) -> Color:
	return _blended_tint(x, z, BiomeCatalog.ground_tint_of)


## Just the water colour here, wanted per vertex of the water sheet the same way
## the ground colour is wanted per corner of a chunk.
func water_tint_at(x: float, z: float) -> Color:
	return _blended_tint(x, z, BiomeCatalog.water_tint_of)


## Just the rock colour here, wanted per vertex of a cliff the same way. The
## rim of a floating island is the one that asks for it so far.
func rock_tint_at(x: float, z: float) -> Color:
	return _blended_tint(x, z, BiomeCatalog.rock_tint_of)


## One of the catalog's colours, averaged over whichever biomes have a share of
## this position. Which colour is the caller's business; the weighting is the
## same for all of them, and is the same weighting a whole profile would use.
func _blended_tint(x: float, z: float, colour_of: Callable) -> Color:
	var weights := weights_at(x, z)
	var tint := Color(0, 0, 0)
	for id in BiomeCatalog.IDS:
		var share := float(weights[id])
		if share > 0.0:
			tint += (colour_of.call(id) as Color) * share
	return tint
