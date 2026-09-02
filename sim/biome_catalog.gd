extends RefCounted
## The named biomes of the design, and the profile each one carries.
##
## This is a table, not a decision: which biome a world position falls in is
## BiomeField's job, and what that biome looks like is this file's. Keeping the
## two apart means the palette can be retuned without touching the fields, and
## the fields can be retuned without touching the palette.
##
## The palettes are placeholder colour, chosen to read at a glance and to sit in
## the project's cool-ambient / warm-key intent: bright warm green in the open,
## deep shaded green under canopy, cool grey-green up high, pastel pink in
## blossom, and teal-indigo gloom in the marsh. No asset pack is assumed, and
## none is needed to see a border shift the mood.
class_name BiomeCatalog

const MEADOW := "meadow"
const DEEP_FOREST := "deep_forest"
const HIGHLAND := "highland"
const BLOSSOM_GROVE := "blossom_grove"
const TWILIGHT_MARSH := "twilight_marsh"

## Every biome, in a fixed order. Blending walks this, so the order a blend adds
## its terms up in is the same everywhere and in every process.
const IDS := [MEADOW, DEEP_FOREST, HIGHLAND, BLOSSOM_GROVE, TWILIGHT_MARSH]

## The colour bare earth is, and how far a worn road goes towards it. This is
## the palette's answer to "what does a dirt track look like": the road is the
## biome's own ground colour mixed most of the way to earth, so a track through a
## marsh stays a marsh-coloured track and one across a meadow stays a bright one.
## Mixing rather than replacing is what keeps the roads from reading as a
## separate material laid over the world.
const PATH_DIRT := Color(0.44, 0.32, 0.21)
const PATH_TINT_MIX := 0.80

## The same, for the trodden ground of a village green: earth showing through
## grass rather than a bare track.
const TRODDEN_TINT_MIX := 0.34

## A biome contributes its prop tags to a blend once it holds at least this much
## of the mix. Below it the biome is a faint edge influence: its colours still
## bleed in proportionally, but a prop belonging to it would look misplaced.
const PROP_TAG_MIN_WEIGHT := 0.15

# id -> BiomeProfile. Built once, never handed out directly.
static var _catalog := {}


## The profile for one biome id, as a detached copy, or null for an unknown id.
static func profile(id: String) -> BiomeProfile:
	var found: BiomeProfile = _built().get(id, null)
	if found == null:
		return null
	return found.detached_copy()


## The ground colour of one biome, without building a whole profile around it.
## Color is a value, so handing it out shares nothing.
static func ground_tint_of(id: String) -> Color:
	var found: BiomeProfile = _built().get(id, null)
	if found == null:
		return Color(0.5, 0.5, 0.5)
	return found.ground_tint


## The water colour of one biome, the same way.
static func water_tint_of(id: String) -> Color:
	var found: BiomeProfile = _built().get(id, null)
	if found == null:
		return Color(0.30, 0.55, 0.70)
	return found.water_tint


## The rock colour of one biome, the same way. Cliffs and boulders take it --
## including the cliff round the rim of a floating island, which is a piece of
## the ground below it and is coloured like one.
static func rock_tint_of(id: String) -> Color:
	var found: BiomeProfile = _built().get(id, null)
	if found == null:
		return Color(0.5, 0.5, 0.5)
	return found.rock_tint


## The colour of a worn road over ground of a given colour.
##
## Takes the ground colour rather than a biome id, because the ground colour at
## a position is already a blend of every biome with a share of it, and a road
## crossing a border should shift with the land it is crossing.
static func path_tint_of(ground: Color) -> Color:
	return ground.lerp(PATH_DIRT, PATH_TINT_MIX)


## The colour of a village's trodden ground, the same way.
static func trodden_tint_of(ground: Color) -> Color:
	return ground.lerp(PATH_DIRT, TRODDEN_TINT_MIX)


## Whether a name is one of the named biomes.
static func has_biome(id: String) -> bool:
	return _built().has(id)


## The blended profile for a set of weights: {biome id -> weight}.
##
## Every value is the weighted average of the contributing biomes' values, which
## is what makes a border a gradient rather than a step -- walk across one and
## the ground tint, the fog and the light all slide from one biome's numbers to
## the other's over the width of the blend, instead of switching on a threshold.
##
## The prop tag set cannot be averaged, so it is a union instead: every biome
## holding at least PROP_TAG_MIN_WEIGHT of the mix contributes its tags. On a
## border that means both biomes' props are allowed, which is what a border
## should look like.
##
## The id and display name are the strongest contributor's, so a blend still
## answers "where am I" with a single name.
static func blend(weights: Dictionary) -> BiomeProfile:
	var total := 0.0
	for id in IDS:
		total += maxf(0.0, float(weights.get(id, 0.0)))
	if total <= 0.0:
		return profile(MEADOW)

	var blended := BiomeProfile.new()
	var ground := Color(0, 0, 0)
	var tree := Color(0, 0, 0)
	var rock := Color(0, 0, 0)
	var water := Color(0, 0, 0)
	var fog := Color(0, 0, 0)
	var top := Color(0, 0, 0)
	var horizon := Color(0, 0, 0)
	var ambient := Color(0, 0, 0)
	var fog_density := 0.0
	var foliage := 0.0
	var tags := PackedStringArray()
	var strongest := 0.0
	var strongest_id := MEADOW

	for id in IDS:
		var share := maxf(0.0, float(weights.get(id, 0.0))) / total
		if share <= 0.0:
			continue
		var source: BiomeProfile = _built()[id]
		ground += source.ground_tint * share
		tree += source.tree_tint * share
		rock += source.rock_tint * share
		water += source.water_tint * share
		fog += source.fog_color * share
		top += source.sky_top * share
		horizon += source.sky_horizon * share
		ambient += source.ambient_color * share
		fog_density += source.fog_density * share
		foliage += source.foliage_density * share
		if share >= PROP_TAG_MIN_WEIGHT:
			for tag in source.prop_tags:
				if not tags.has(tag):
					tags.append(tag)
		if share > strongest:
			strongest = share
			strongest_id = id

	var lead: BiomeProfile = _built()[strongest_id]
	blended.id = lead.id
	blended.display_name = lead.display_name
	blended.ground_tint = ground
	blended.tree_tint = tree
	blended.rock_tint = rock
	blended.water_tint = water
	blended.fog_color = fog
	blended.sky_top = top
	blended.sky_horizon = horizon
	blended.ambient_color = ambient
	blended.fog_density = fog_density
	blended.foliage_density = foliage
	blended.prop_tags = tags
	return blended


static func _built() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog

	var meadow := BiomeProfile.new(MEADOW, "Meadow")
	meadow.ground_tint = Color(0.48, 0.72, 0.34)
	meadow.tree_tint = Color(0.30, 0.55, 0.30)
	meadow.rock_tint = Color(0.62, 0.60, 0.55)
	meadow.water_tint = Color(0.20, 0.46, 0.62)
	meadow.fog_color = Color(0.80, 0.87, 0.80)
	meadow.fog_density = 0.0012
	meadow.sky_top = Color(0.35, 0.60, 0.92)
	meadow.sky_horizon = Color(0.86, 0.92, 0.98)
	meadow.ambient_color = Color(0.72, 0.74, 0.70)
	meadow.foliage_density = 0.45
	meadow.prop_tags = PackedStringArray([
		AssetTags.GRASS, AssetTags.FLOWER, AssetTags.FIR, AssetTags.PEBBLE,
		AssetTags.FENCE, AssetTags.LANTERN_POST, AssetTags.CART, AssetTags.SIGNPOST,
	])

	var deep_forest := BiomeProfile.new(DEEP_FOREST, "Deep forest")
	deep_forest.ground_tint = Color(0.20, 0.38, 0.22)
	deep_forest.tree_tint = Color(0.13, 0.30, 0.18)
	deep_forest.rock_tint = Color(0.40, 0.42, 0.38)
	deep_forest.water_tint = Color(0.09, 0.25, 0.25)
	deep_forest.fog_color = Color(0.20, 0.32, 0.28)
	deep_forest.fog_density = 0.0042
	deep_forest.sky_top = Color(0.14, 0.26, 0.30)
	deep_forest.sky_horizon = Color(0.34, 0.46, 0.40)
	deep_forest.ambient_color = Color(0.42, 0.50, 0.44)
	deep_forest.foliage_density = 0.95
	deep_forest.prop_tags = PackedStringArray([
		AssetTags.CANOPY_TREE, AssetTags.BUSH, AssetTags.MUSHROOM,
		AssetTags.FALLEN_LOG, AssetTags.FERN, AssetTags.PEBBLE,
	])

	var highland := BiomeProfile.new(HIGHLAND, "Highland")
	highland.ground_tint = Color(0.52, 0.56, 0.46)
	highland.tree_tint = Color(0.34, 0.44, 0.36)
	highland.rock_tint = Color(0.60, 0.62, 0.64)
	highland.water_tint = Color(0.22, 0.40, 0.54)
	highland.fog_color = Color(0.62, 0.68, 0.74)
	highland.fog_density = 0.0020
	highland.sky_top = Color(0.30, 0.48, 0.72)
	highland.sky_horizon = Color(0.72, 0.80, 0.86)
	highland.ambient_color = Color(0.62, 0.66, 0.70)
	highland.foliage_density = 0.18
	highland.prop_tags = PackedStringArray([
		AssetTags.BOULDER, AssetTags.ROCK_SPIRE, AssetTags.HARDY_SHRUB,
		AssetTags.STONE_HENGE, AssetTags.GRAVEL,
	])

	var blossom := BiomeProfile.new(BLOSSOM_GROVE, "Blossom grove")
	blossom.ground_tint = Color(0.62, 0.74, 0.46)
	blossom.tree_tint = Color(0.92, 0.66, 0.78)
	blossom.rock_tint = Color(0.72, 0.66, 0.66)
	blossom.water_tint = Color(0.36, 0.52, 0.72)
	blossom.fog_color = Color(0.95, 0.84, 0.88)
	blossom.fog_density = 0.0025
	blossom.sky_top = Color(0.62, 0.66, 0.92)
	blossom.sky_horizon = Color(0.98, 0.88, 0.90)
	blossom.ambient_color = Color(0.82, 0.74, 0.78)
	blossom.foliage_density = 0.60
	blossom.prop_tags = PackedStringArray([
		AssetTags.BLOSSOM_TREE, AssetTags.PETAL_DRIFT, AssetTags.FLOWER,
		AssetTags.BUSH, AssetTags.GRASS,
	])

	var marsh := BiomeProfile.new(TWILIGHT_MARSH, "Twilight marsh")
	marsh.ground_tint = Color(0.18, 0.30, 0.34)
	marsh.tree_tint = Color(0.12, 0.22, 0.28)
	marsh.rock_tint = Color(0.24, 0.30, 0.34)
	marsh.water_tint = Color(0.05, 0.15, 0.19)
	marsh.fog_color = Color(0.10, 0.26, 0.32)
	marsh.fog_density = 0.0090
	marsh.sky_top = Color(0.06, 0.10, 0.20)
	marsh.sky_horizon = Color(0.14, 0.30, 0.36)
	marsh.ambient_color = Color(0.28, 0.38, 0.46)
	marsh.foliage_density = 0.70
	marsh.prop_tags = PackedStringArray([
		AssetTags.CATTAIL, AssetTags.LILY_PAD, AssetTags.TOADSTOOL,
		AssetTags.GLOWING_ORB, AssetTags.REED, AssetTags.DEAD_TREE,
	])

	_catalog = {
		MEADOW: meadow,
		DEEP_FOREST: deep_forest,
		HIGHLAND: highland,
		BLOSSOM_GROVE: blossom,
		TWILIGHT_MARSH: marsh,
	}
	return _catalog
