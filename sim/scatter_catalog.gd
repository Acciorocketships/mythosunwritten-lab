extends RefCounted
## What may be scattered across the world, how much of it, how big, and where it
## is allowed to stand.
##
## This is a table, not a decision, in exactly the sense BiomeCatalog is one:
## which cell of the world gets something is DecorationScatter's job, and what
## the choice is made *from* is this file's. Keeping them apart means the mix of
## a biome can be retuned without touching the placement rule, and the placement
## rule can be rewritten without retuning the mix.
##
## Every row names an asset tag and nothing else. There is no model, no path and
## no pack anywhere in here -- what a `canopy_tree` looks like is the render
## layer's table's business, and the automated asset check fails the build if
## this file ever learns it.
##
## ## What a row says
##
## * **which lattice** it is drawn on. Two lattices exist: a fine one for flora
##   and small stones, and a coarse one for the things that would look absurd
##   packed shoulder to shoulder -- boulders, stone circles, fences, crates.
##   Every cell of a lattice makes one independent decision, so a lattice's cell
##   size *is* the closest two of its things can ever stand.
## * **which context** it needs: open ground, wet ground, open water, the verge
##   of a road, the yard beside a building, or a level clearing. This is what
##   makes a prop read as intentional rather than sprinkled -- a crate belongs
##   against a wall, a cattail belongs at the water's edge, and neither belongs
##   in the middle of a field.
## * **how likely it is per cell, per biome.** A weight is a probability, not a
##   ratio: 0.05 means "about one cell in twenty of this lattice, in this biome,
##   in this context". The weights of one lattice are summed and compared against
##   a single roll, so they can be read straight off as densities.
## * **how big it is, per biome**, as a range of world-unit heights. This is
##   where "deep forest reads as tall canopy, highland as big boulders" actually
##   lives: the same `fir` is five to seven and a half units under canopy and a
##   stunted two and a half up on the tops, and the same `boulder` is knee-high
##   in the woods and taller than a house on the moor.
## * **how it stands in the way**: walked through, or solid. A fern is one, a
##   trunk is the other, and the tactical board reads this row rather than
##   guessing from the tag. It is a fact about the thing, so it lives beside the
##   thing.
##
## The reasoning behind every number, and the measured result, are written up in
## reports/scatter.md.
class_name ScatterCatalog

# --- The two lattices ----------------------------------------------------

## Flora and the small stones between it. The cell is small, so this is what
## fills a view.
const LATTICE_FLORA := "flora"

## Boulders, stone circles, and the made things that dress a road or a yard. The
## cell is four times as wide, because these are large and are meant to be
## noticed one at a time.
const LATTICE_PROP := "prop"

const LATTICES := [LATTICE_FLORA, LATTICE_PROP]

# --- Contexts ------------------------------------------------------------
# What a row needs to be true of a cell before it may stand there. Every one of
# these is a question TerrainQuery already answers for some other layer; the
# scatter layer asks rather than recomputes, which is why a fern cannot disagree
# with the settlement layer about where a house is.

## Dry, walkable ground. The default.
const CONTEXT_GROUND := "ground"

## Wet ground: a bank, or water shallow enough to stand a stem in. Reeds,
## cattails and toadstools.
const CONTEXT_WET := "wet"

## Open water of a workable depth. Lily pads, which float rather than stand.
const CONTEXT_WATER := "water"

## The verge of a road: outside the cart track, within a few steps of it.
## Fences, lantern posts and the odd abandoned cart.
const CONTEXT_PATHSIDE := "pathside"

## The ground just outside a building's reserved footprint. Crates and barrels
## stacked against a wall.
const CONTEXT_YARD := "yard"

## Level open ground away from any road or village. Where a stone circle can
## stand and read as deliberate rather than as a rock that fell over.
const CONTEXT_CLEARING := "clearing"

# --- Kinds ---------------------------------------------------------------
# What a row *is*, for the things that reason about groups rather than tags: the
# report that measures the world, and the test that asserts a deep forest grows
# taller trees than a highland does.

const KIND_TREE := "tree"
const KIND_UNDERGROWTH := "undergrowth"
const KIND_WATERSIDE := "waterside"
const KIND_ROCK := "rock"
const KIND_PROP := "prop"

const KINDS := [KIND_TREE, KIND_UNDERGROWTH, KIND_WATERSIDE, KIND_ROCK, KIND_PROP]

# --- How a thing stands in the way ---------------------------------------
# What a placed thing does to the square of ground it stands on, which is the
# one thing the tactical board needs to know about it. A row says which of two
# it is, and says it here rather than in the board, because whether you can walk
# through a fern is a fact about ferns.
#
# The board turns the two into its own three answers, and a row does not have to
# know how:
#
#   * a thing that is walked through changes nothing. A cell with a tuft of
#     grass on it is an empty cell.
#   * a solid thing takes the cell: no piece may be on it.
#   * a solid thing *taller than a piece can climb* takes the line as well.
#     That threshold is CombatBoard.STEP_UP, which is the board's own existing
#     rule for a face of earth -- earth you could scramble up is earth you can
#     see over -- and it is applied to the size the thing actually rolled rather
#     than to its tag. So a boulder in the woods (0.9 to 1.7 units) is cover you
#     shoot over and a boulder on the moor (2.2 to 4.4) is a wall, and the
#     highland's bigger stone finally means something other than a picture.
#
# Why each group is what it is:
#
#   * **trees** are solid. A trunk is in the way, and every tree in the table
#     rolls taller than a piece can climb, so a wood is a place with sight lines
#     in it rather than an open field with decoration.
#   * **undergrowth** and **waterside flora** are walked through. Bushes, ferns,
#     flowers, mushrooms, petals, a fallen log, reeds, cattails, toadstools,
#     lily pads and the marsh's orb are all things a person pushes past or steps
#     over; none of them would stop anybody.
#   * **stone** splits on size, which is what the two lattices already say about
#     it: a pebble or a patch of gravel on the fine lattice is walked over, and
#     a boulder, a spire or a stone circle on the coarse one is solid rock.
#   * **made things** are solid where somebody built them to be in the way -- a
#     fence, a cart, a crate, a barrel -- and walked past where they are a post:
#     a lantern on a pole is a thin thing in a three-unit square, and stopping a
#     piece with one would be stopping it with a signpost.

## Walked through, seen through, stood on. Grass, ferns, flowers, reeds, lily
## pads, pebbles -- everything a person pushes past without breaking stride, and
## everything low enough to stand a boot on. Most of the table.
const STANDS_THROUGH := "through"

## Occupies the ground it stands on: a trunk, a block of stone, a made thing
## somebody built to be in the way. Nobody stands in a boulder, so the cell it
## stands in is not a cell a piece may be on.
const STANDS_SOLID := "solid"

const STANDINGS := [STANDS_THROUGH, STANDS_SOLID]

## The most any one lattice's weights may add up to at a single position.
##
## The weights of a lattice are compared against one roll in [0, 1), so their sum
## is the chance that cell holds anything at all -- which means the sum has to
## stay below one or the tail of the table would be unreachable. It is checked
## rather than assumed: the suite adds up every row of every biome and fails if
## any lattice passes this.
const WEIGHT_CEILING := 1.0

## A cheap upper bound on the flora lattice's total, used to throw out most cells
## before anything is asked about the ground under them. It has to be at or above
## the real maximum or placements would be lost, and near it or it would throw
## away nothing; the suite checks both.
##
## The biome that sets it is the twilight marsh, whose waterside weights are the
## largest in the table -- so about three cells in eight are thrown out for a
## hash apiece, and the rest go on to ask the ground about themselves.
const FLORA_CEILING := 0.62

# Built once, handed out as the same arrays every time. Nothing writes to them.
static var _rows := {}

# Which tags are solid, as a set, built on first use from the rows above.
static var _solid := {}

# How far along each lattice's line anything solid reaches, worked out once.
static var _ceilings := {}


## Every row of one lattice, in a fixed order.
##
## The order is the order weights are summed in when a cell is decided, so it is
## part of the world: shuffling this file would re-roll the whole map. New rows
## therefore go at the end of their lattice rather than in the middle of it.
static func entries(lattice: String) -> Array:
	return _built().get(lattice, [])


## Every row, both lattices, flora first.
static func all_entries() -> Array:
	var found := []
	for lattice in LATTICES:
		found.append_array(entries(lattice))
	return found


## The row for a tag, or an empty dictionary. Tags are unique across lattices.
static func entry_for(tag: String) -> Dictionary:
	for entry in all_entries():
		if String(entry["tag"]) == tag:
			return entry
	return {}


## Every tag the scatter layer can name, in table order.
static func tags() -> PackedStringArray:
	var found := PackedStringArray()
	for entry in all_entries():
		found.append(String(entry["tag"]))
	return found


## How a tag stands in the way: STANDS_THROUGH or STANDS_SOLID. A tag this table
## does not name is walked through, which is what an unknown thing on the ground
## should be: the board does not invent an obstacle it cannot account for.
static func stands_of(tag: String) -> String:
	return STANDS_SOLID if stands_solid(tag) else STANDS_THROUGH


## How far along a lattice's line anything solid can reach, at any position.
##
## One roll in [0, 1) decides a cell, and the rows are laid end to end along it
## in table order, so a roll past the end of the *last solid row's* stretch can
## only ever land on something walked through -- whatever the biome, because a
## position's weights are a blend of its biomes' and a blend cannot exceed the
## largest of them, and because a context can only ever scale a weight down.
##
## That makes this a sound refusal rather than an estimate: a cell whose roll is
## at or past it cannot hold anything solid, and nothing about the ground under
## it needs to be asked. It is the same trick, for the same reason, as
## FLORA_CEILING -- and it is computed from the table rather than written down,
## so retuning a weight cannot leave it stale. On the flora lattice the trees are
## the first four rows and it comes to 0.128, so seven cells in eight are thrown
## out for one hash.
static func solid_ceiling(lattice: String) -> float:
	if not _ceilings.has(lattice):
		var rows := entries(lattice)
		var last := -1
		for at in rows.size():
			if String(rows[at]["stands"]) == STANDS_SOLID:
				last = at
		var most := 0.0
		for biome in BiomeCatalog.IDS:
			var total := 0.0
			for at in range(last + 1):
				total += float((rows[at]["weights"] as Dictionary).get(biome, 0.0))
			most = maxf(most, total)
		_ceilings[lattice] = most
	return float(_ceilings[lattice])


## Whether a thing with this tag occupies the ground it stands on.
##
## Asked once per placed thing by the tactical board, which is a few hundred
## times per board, so the answer is built once into a set rather than found by
## walking every row each time. The table is fixed after the first call, so this
## cannot fall out of step with it.
static func stands_solid(tag: String) -> bool:
	if _solid.is_empty():
		for entry in all_entries():
			_solid[String(entry["tag"])] = String(entry["stands"]) == STANDS_SOLID
	return bool(_solid.get(tag, false))


## How likely this row is at a position, given that position's biome shares.
##
## The blend is the same one the ground colour and the fog use: a position is
## some of each biome, and what it grows is that much of each biome's mix. So a
## forest thins out into a meadow over the width of the border rather than
## stopping at a line, and neither side has to know where the border is.
static func weight_of(entry: Dictionary, shares: Dictionary) -> float:
	var by_biome: Dictionary = entry["weights"]
	var weight := 0.0
	for id in BiomeCatalog.IDS:
		var share := float(shares.get(id, 0.0))
		if share <= 0.0:
			continue
		weight += share * float(by_biome.get(id, 0.0))
	return weight


## How big this row stands at a position, as a range of world-unit heights,
## blended across the biomes the position belongs to exactly as the weight is.
##
## A row that says nothing about a biome takes its base size there, so a table
## only has to name the biomes where the size is the point.
static func size_of(entry: Dictionary, shares: Dictionary) -> Vector2:
	var by_biome: Dictionary = entry["sizes"]
	var base: Vector2 = entry["base_size"]
	var total := 0.0
	var blended := Vector2.ZERO
	for id in BiomeCatalog.IDS:
		var share := float(shares.get(id, 0.0))
		if share <= 0.0:
			continue
		total += share
		blended += share * (by_biome.get(id, base) as Vector2)
	if total <= 0.0:
		return base
	return blended / total


## What every row of one biome adds up to on one lattice, ignoring context. The
## conservative bound the ceiling is checked against, and the number the report
## quotes as "how thickly this biome grows".
static func total_weight(lattice: String, biome: String) -> float:
	var total := 0.0
	for entry in entries(lattice):
		total += float((entry["weights"] as Dictionary).get(biome, 0.0))
	return total


## The same, for one kind of thing only -- how much of a biome's mix is trees,
## or waterside flora, or stone.
static func kind_weight(lattice: String, biome: String, kind: String) -> float:
	var total := 0.0
	for entry in entries(lattice):
		if String(entry["kind"]) != kind:
			continue
		total += float((entry["weights"] as Dictionary).get(biome, 0.0))
	return total


static func _entry(
	tag: String,
	kind: String,
	context: String,
	weights: Dictionary,
	base_size: Vector2,
	sizes: Dictionary = {},
	hover: float = 0.0,
	stands: String = STANDS_THROUGH,
) -> Dictionary:
	return {
		"tag": tag,
		"kind": kind,
		"context": context,
		"weights": weights,
		"base_size": base_size,
		"sizes": sizes,
		# How far above the surface the thing floats. Zero for everything that
		# stands on the ground, which is everything but a drifting orb.
		"hover": hover,
		# Whether the square of ground it stands on is still a square a person
		# can walk into. Walked through unless the row says otherwise, because
		# most of what grows is grass.
		"stands": stands,
	}


static func _built() -> Dictionary:
	if not _rows.is_empty():
		return _rows

	var meadow := BiomeCatalog.MEADOW
	var forest := BiomeCatalog.DEEP_FOREST
	var highland := BiomeCatalog.HIGHLAND
	var blossom := BiomeCatalog.BLOSSOM_GROVE
	var marsh := BiomeCatalog.TWILIGHT_MARSH

	# --- The flora lattice ------------------------------------------------
	#
	# Two-unit cells, so sixty-four decisions per chunk. The trees come first
	# because they are what a biome reads as from a distance, then the
	# undergrowth under them, then the waterside flora, then the loose stone.

	var flora := [
		# The cone-firs of the reference art: everywhere, tallest under canopy,
		# stunted and windswept on the tops.
		_entry(AssetTags.FIR, KIND_TREE, CONTEXT_GROUND,
			{meadow: 0.028, forest: 0.050, highland: 0.010, blossom: 0.008, marsh: 0.004},
			Vector2(3.6, 5.4),
			{
				forest: Vector2(5.2, 7.6),
				highland: Vector2(2.4, 3.4),
				blossom: Vector2(3.4, 5.0),
				marsh: Vector2(3.0, 4.4),
			}, 0.0, STANDS_SOLID),
		# The canopy itself. Deep forest is where it grows and where it is tall;
		# it does not grow on the tops at all.
		_entry(AssetTags.CANOPY_TREE, KIND_TREE, CONTEXT_GROUND,
			{meadow: 0.004, forest: 0.072, highland: 0.000, blossom: 0.006, marsh: 0.005},
			Vector2(6.5, 8.5),
			{
				forest: Vector2(8.5, 12.5),
				highland: Vector2(5.0, 6.5),
				blossom: Vector2(7.0, 9.0),
				marsh: Vector2(6.0, 8.0),
			}, 0.0, STANDS_SOLID),
		_entry(AssetTags.BLOSSOM_TREE, KIND_TREE, CONTEXT_GROUND,
			{meadow: 0.003, forest: 0.002, highland: 0.000, blossom: 0.062, marsh: 0.000},
			Vector2(3.6, 5.0),
			{blossom: Vector2(4.5, 6.5)}, 0.0, STANDS_SOLID),
		_entry(AssetTags.DEAD_TREE, KIND_TREE, CONTEXT_GROUND,
			{meadow: 0.000, forest: 0.004, highland: 0.002, blossom: 0.000, marsh: 0.026},
			Vector2(2.8, 3.8),
			{marsh: Vector2(3.2, 4.6)}, 0.0, STANDS_SOLID),

		_entry(AssetTags.BUSH, KIND_UNDERGROWTH, CONTEXT_GROUND,
			{meadow: 0.038, forest: 0.066, highland: 0.006, blossom: 0.050, marsh: 0.018},
			Vector2(0.7, 1.2),
			{forest: Vector2(1.0, 1.7), highland: Vector2(0.5, 0.8)}),
		_entry(AssetTags.FERN, KIND_UNDERGROWTH, CONTEXT_GROUND,
			{meadow: 0.010, forest: 0.085, highland: 0.000, blossom: 0.018, marsh: 0.026},
			Vector2(0.5, 0.95),
			{forest: Vector2(0.6, 1.1)}),
		_entry(AssetTags.HARDY_SHRUB, KIND_UNDERGROWTH, CONTEXT_GROUND,
			{meadow: 0.006, forest: 0.000, highland: 0.062, blossom: 0.000, marsh: 0.005},
			Vector2(0.35, 0.65)),
		_entry(AssetTags.FLOWER, KIND_UNDERGROWTH, CONTEXT_GROUND,
			{meadow: 0.070, forest: 0.010, highland: 0.008, blossom: 0.080, marsh: 0.005},
			Vector2(0.35, 0.55)),
		_entry(AssetTags.MUSHROOM, KIND_UNDERGROWTH, CONTEXT_GROUND,
			{meadow: 0.004, forest: 0.046, highland: 0.000, blossom: 0.006, marsh: 0.018},
			Vector2(0.30, 0.60),
			{forest: Vector2(0.40, 0.80)}),
		_entry(AssetTags.PETAL_DRIFT, KIND_UNDERGROWTH, CONTEXT_GROUND,
			{blossom: 0.055},
			Vector2(0.015, 0.030)),
		_entry(AssetTags.FALLEN_LOG, KIND_UNDERGROWTH, CONTEXT_GROUND,
			{meadow: 0.002, forest: 0.018, highland: 0.002, blossom: 0.004, marsh: 0.008},
			Vector2(1.3, 2.2)),

		# Wet ground. The marsh is where these belong, but a river bank in a
		# meadow is a river bank, so every biome grows some.
		#
		# These weights are much larger than the dry ones above and mean
		# something different by it. A bank is a thin ring of cells rather than
		# a stretch of country, so a weight that reads as thick cover on dry
		# ground would put one reed on a whole lake shore. Two in five bank
		# cells of a marsh hold something, and one in five of a forest's, which
		# is what makes a shoreline read as a shoreline.
		_entry(AssetTags.REED, KIND_WATERSIDE, CONTEXT_WET,
			{meadow: 0.090, forest: 0.080, highland: 0.050, blossom: 0.080, marsh: 0.160},
			Vector2(1.1, 1.8),
			{marsh: Vector2(1.3, 2.1)}),
		_entry(AssetTags.CATTAIL, KIND_WATERSIDE, CONTEXT_WET,
			{meadow: 0.060, forest: 0.040, highland: 0.020, blossom: 0.040, marsh: 0.110},
			Vector2(1.3, 1.9)),
		_entry(AssetTags.TOADSTOOL, KIND_WATERSIDE, CONTEXT_WET,
			{meadow: 0.010, forest: 0.050, highland: 0.005, blossom: 0.010, marsh: 0.080},
			Vector2(0.40, 0.80),
			{marsh: Vector2(0.50, 1.00)}),
		_entry(AssetTags.LILY_PAD, KIND_WATERSIDE, CONTEXT_WATER,
			{meadow: 0.050, forest: 0.050, highland: 0.030, blossom: 0.050, marsh: 0.070},
			Vector2(0.045, 0.075)),
		# The marsh's own light source, hanging over the wet ground where there
		# is nobody to hang a lantern.
		#
		# It sits with the waterside flora rather than with the props, and that
		# is a correction. On the prop lattice -- four times the cell, for large
		# things meant to be noticed one at a time -- a row that also demands wet
		# ground almost never fires: a survey of thirty-one twilight-marsh views
		# over two seeds found one orb in total. An orb is the size of a cattail,
		# grows where a cattail grows, and the design asks for a scattering of
		# them rather than a landmark, so this is where it belongs. Rarer than
		# the cattails and the toadstools it stands among, because it is the one
		# thing in the pocket that gives off light.
		#
		# The weight is also capped from above by something outside this row: the
		# biome catalog advertises a foliage density per biome, and the flora of
		# the marsh (0.70) has to add up to less than the flora of the deep
		# forest (0.95) or the two catalogs are telling different stories.
		# tests/test_scatter.gd checks exactly that, and 0.030 is what fits under
		# the deep forest's total without moving any other row.
		_entry(AssetTags.GLOWING_ORB, KIND_WATERSIDE, CONTEXT_WET,
			{forest: 0.006, marsh: 0.030},
			Vector2(1.1, 1.8),
			{},
			1.2),

		# Loose stone: what the ground is made of, showing through.
		_entry(AssetTags.PEBBLE, KIND_ROCK, CONTEXT_GROUND,
			{meadow: 0.028, forest: 0.026, highland: 0.060, blossom: 0.018, marsh: 0.016},
			Vector2(0.22, 0.45),
			{highland: Vector2(0.40, 0.75)}),
		_entry(AssetTags.GRAVEL, KIND_ROCK, CONTEXT_GROUND,
			{meadow: 0.008, forest: 0.005, highland: 0.050, blossom: 0.005, marsh: 0.005},
			Vector2(0.12, 0.22)),
	]

	# --- The prop lattice -------------------------------------------------
	#
	# Eight-unit cells, so four decisions per chunk. Everything here is either
	# large enough to be a landmark of its own or made by somebody, and both
	# want space around them.

	var props := [
		# The highland's signature, and the reason "big boulders" is a size
		# distribution rather than a different tag.
		_entry(AssetTags.BOULDER, KIND_ROCK, CONTEXT_GROUND,
			{meadow: 0.050, forest: 0.045, highland: 0.240, blossom: 0.030, marsh: 0.030},
			Vector2(1.0, 1.9),
			{
				forest: Vector2(0.9, 1.7),
				highland: Vector2(2.2, 4.4),
				blossom: Vector2(0.9, 1.5),
				marsh: Vector2(0.9, 1.6),
			}, 0.0, STANDS_SOLID),
		_entry(AssetTags.ROCK_SPIRE, KIND_ROCK, CONTEXT_GROUND,
			{meadow: 0.006, forest: 0.004, highland: 0.070, blossom: 0.002, marsh: 0.004},
			Vector2(2.4, 3.6),
			{highland: Vector2(3.2, 5.5)}, 0.0, STANDS_SOLID),
		# Standing stones, and the one row in the table that needs a clearing:
		# a stone circle in a thicket would read as scenery that fell over.
		_entry(AssetTags.STONE_HENGE, KIND_ROCK, CONTEXT_CLEARING,
			{meadow: 0.006, highland: 0.050},
			Vector2(3.2, 4.2),
			{highland: Vector2(3.6, 5.0)}, 0.0, STANDS_SOLID),

		# The roadside. The path layer already puts a signpost where a road
		# leaves a village and lanterns along the lit stretch nearest it; these
		# are what the rest of the route gets.
		_entry(AssetTags.FENCE, KIND_PROP, CONTEXT_PATHSIDE,
			{meadow: 0.280, forest: 0.220, highland: 0.240, blossom: 0.260, marsh: 0.100},
			Vector2(1.0, 1.2), {}, 0.0, STANDS_SOLID),
		_entry(AssetTags.LANTERN_POST, KIND_PROP, CONTEXT_PATHSIDE,
			{meadow: 0.040, forest: 0.040, highland: 0.030, blossom: 0.040, marsh: 0.060},
			Vector2(2.6, 3.0)),
		_entry(AssetTags.CART, KIND_PROP, CONTEXT_PATHSIDE,
			{meadow: 0.030, forest: 0.025, highland: 0.020, blossom: 0.030, marsh: 0.010},
			Vector2(1.0, 1.15), {}, 0.0, STANDS_SOLID),

		# The yard. What is stacked against the wall of a building, in the
		# village the settlement layer laid out.
		_entry(AssetTags.CRATE, KIND_PROP, CONTEXT_YARD,
			{meadow: 0.140, forest: 0.140, highland: 0.140, blossom: 0.140, marsh: 0.140},
			Vector2(0.7, 0.95), {}, 0.0, STANDS_SOLID),
		_entry(AssetTags.BARREL, KIND_PROP, CONTEXT_YARD,
			{meadow: 0.110, forest: 0.110, highland: 0.110, blossom: 0.110, marsh: 0.110},
			Vector2(0.9, 1.1), {}, 0.0, STANDS_SOLID),
	]

	_rows = {LATTICE_FLORA: flora, LATTICE_PROP: props}
	return _rows
