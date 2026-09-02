extends RefCounted
## What grows and what stands on a floating island.
##
## The ground's dressing is DecorationScatter's; this is the same idea applied
## to the aerial layer, and it exists as its own file for one reason: **an
## island's cover cannot be hashed from where it is in the world.** The two
## aerial storeys overlap in plan -- an upper island laps over the rim of the
## lower one it stands on, which is the whole of how you walk from one to the
## other -- so a cell of the ground lattice can have two islands over it. Hashed
## from world x and z, both storeys would grow the same tree in the same place,
## one directly above the other, and every overlapping pair in the world would
## be a visible mistake. So the lattice here is the island's own: a cell is
## counted out from the island's middle, and the hash takes the island's cell,
## its band and that local cell.
##
## Everything else is deliberately the ground layer's:
##
## * the same two lattices, at the same two cell sizes, each cell making one
##   independent decision;
## * the same catalog, so what may grow on an island in a deep forest is what
##   grows on the ground in a deep forest, at the same per-cell densities and
##   the same world-unit sizes;
## * one roll compared against the weights laid end to end, so adding a row
##   cannot move the rows before it and most cells cost a hash and nothing else;
## * the same ScatterPatch coming out, so the streamer, the fingerprint and the
##   render shell all handle an island's cover with the machinery they already
##   have for a chunk's.
##
## ## What an island asks that the ground does not
##
## Three things, and each is a fact about the island rather than about the
## world under it.
##
## * **Its biome is one biome.** The ground blends across a border; an island is
##   a single chunk of land that broke off one place, and it already carries that
##   place's name and colours. So the shares handed to the catalog are that one
##   biome at full weight, and the cover matches the plate it stands on.
## * **Its rim is stone.** The outer band of an island is the broken edge of a
##   torn-off piece of land, so out there the catalog's stone rows are made
##   several times likelier and everything else is thinned. Nothing new is
##   named for it: a rim rock is a `boulder` or a `pebble`, the same rows the
##   moor grows, weighted differently because of where they are.
## * **It may hold water.** A basin with a pond in it is a hole in the island's
##   surface, and nothing is placed in one -- for exactly the reason nothing is
##   placed in a lake.
##
## And one thing the ground has no use for at all: **roots**. A handful hang
## from the keel of every island, anchored on the underside and hanging into the
## air below it, which is what says the island was torn out of the ground rather
## than cast in one piece.
class_name IslandCover

## How far out the stony rim band starts, as a share of the way to the outline.
## Outside this the island is the broken edge rather than the meadow on top.
const RIM_BAND := 0.82

## How much likelier the catalog's stone rows are out on that band, and how much
## of its usual weight everything else keeps there.
##
## Neither number invents anything: the rows are the rows the ground already
## grows, and the sizes are the sizes the biome already gives them. What the
## band changes is the mix, so the outer ring of an island reads as rubble and
## scree with a few stunted things in it, and the middle reads as country.
const RIM_ROCK_GAIN := 2.2
const RIM_THINNING := 0.45

## How close to the outline anything may stand. The last stretch of an island is
## the lip of a cliff, and a tree half over it would hang in the air.
const EDGE_KEEP := 0.965

## How steep the island's top may be under something, as the fall in world units
## per unit walked, and how far that fall is measured over.
##
## Both numbers are looser than the ground layer's, and both for the same reason:
## an island is not a hillside. Its relief is half to three quarters of its
## radius -- the ground's is a fraction of that -- and the finer of its two noise
## octaves runs at about a sixth of its width, so the top of one is genuinely
## lumpy at the scale of a stride. Measured the ground's way, over a single unit
## against a limit of 0.75, almost every cell of an island would be refused and
## an island would come out nearly bare.
##
## So the step is longer, which measures the hillside rather than the lumps on
## it, and the limit is higher. It is still well inside what the world calls
## walkable: TerrainQuery.HOP_HEIGHT is 3.0, so a fall of 1.65 over 1.6 units --
## 2.64 units of it -- is something someone walks up in one go.
##
## The limit is what it is because the relief share is what it is. It was 1.10
## when an island stood a third to a half of its radius above its rim; the
## camera the game is played from needed half to three quarters, which is the
## same hillside about half again as steep, and a gate left at 1.10 answered that
## by stripping the tops bare -- 28.1 things on an island against the ground's
## own 53.7 per thousand square units. The two numbers move together or the
## island stops being dressed like the country it broke off.
const SLOPE_LIMIT := 1.65
const SLOPE_STEP := 1.6

## How far a thing may stand from the pond's edge. The shore of a basin is soft
## ground and the catalog has nothing that wants to stand in it, so the simplest
## honest rule is that the pond and a hand's breadth around it stay clear.
const POND_CLEAR := 0.6

## Where in its cell a thing stands, as a fraction of the cell. The ground
## layer's jitter, and the same reason for it: off the edges so two things in
## neighbouring cells cannot touch, wide enough that the lattice does not read
## as a grid.
const JITTER_LOW := 0.18
const JITTER_HIGH := 0.82

## How many roots hang from one island's keel.
const ROOT_COUNT_MIN := 4
const ROOT_COUNT_MAX := 9

## Where a root is anchored, as a share of the way out from the island's middle
## to its outline. Out on the shoulders of the keel rather than at its tip: a
## root hanging off the lowest point of the spur would read as a stalactite.
const ROOT_REACH_MIN := 0.42
const ROOT_REACH_MAX := 0.92

## How long a root is, as a share of the island's keel depth, and the world-unit
## bounds that share is clamped into.
const ROOT_LENGTH_MIN := 0.22
const ROOT_LENGTH_MAX := 0.55
const ROOT_SHORTEST := 0.8
const ROOT_LONGEST := 4.5

## What a root is placed as, in the `context` field of the item. Everything else
## the layer places stands on the island's top; this is the one thing that hangs
## off its underside, and a reader of a patch has to be able to tell.
const CONTEXT_TOP := "island_top"
const CONTEXT_KEEL := "island_keel"

## This layer's own corner of the seed space, and the strides that keep its
## several rolls from ever being the same roll.
const SEED_OFFSET := 0x6B7A2D19
const SALT_STRIDE := 0x9E3779B1
const LATTICE_STRIDE := 0x27D4EB2F
const BAND_STRIDE := 0x165667B1

# Which roll is which, on the cell lattices.
const SALT_PICK := 1
const SALT_JITTER_X := 2
const SALT_JITTER_Z := 3
const SALT_SIZE := 4
const SALT_YAW := 5

# And on the roots, which are counted out per island rather than per cell.
const SALT_ROOT_COUNT := 11
const SALT_ROOT_ANGLE := 12
const SALT_ROOT_REACH := 13
const SALT_ROOT_LENGTH := 14
const SALT_ROOT_YAW := 15

## The seed the whole layer descends from.
var world_seed: int = 0

# The largest total the weights of one lattice can reach here, per lattice.
# Worked out from the catalog rather than written down, so retuning the table
# cannot leave a stale bound behind that silently drops the tail of it.
static var _ceilings := {}


func _init(seed_value: int = 0) -> void:
	world_seed = seed_value


## Everything this layer puts on one island, as the same kind of patch the
## ground layer produces for a chunk.
##
## The patch's chunk coordinate is the island's lattice cell, which is what the
## island's geometry already keys on. Both lattices are walked in a fixed order,
## then the roots, so a patch's contents are in the same order in every process.
func build(island: FloatingIsland) -> ScatterPatch:
	var patch := ScatterPatch.new(island.cell)
	if not island.walkable:
		# A far-sky island is a silhouette hundreds of units off. Nothing on it
		# would ever be seen, and it is not ground, so nothing grows there.
		return patch
	var reach := island.max_reach()
	for lattice in ScatterCatalog.LATTICES:
		var size := DecorationScatter.cell_size(lattice)
		var span := int(ceil(reach / size)) + 1
		for step_x in range(-span, span + 1):
			for step_z in range(-span, span + 1):
				var item := item_in_cell(island, lattice, Vector2i(step_x, step_z))
				if not item.is_empty():
					patch.items.append(item)
	patch.items.append_array(roots_of(island))
	return patch


## What one cell of one of the island's own lattices holds: a placed thing, or
## an empty dictionary.
##
## The cell is counted out from the island's middle, so it is a fact about the
## island rather than about where the island happens to hang. That is the whole
## difference between this and the ground layer's decision, and it is why two
## storeys that overlap in plan carry different cover.
func item_in_cell(
	island: FloatingIsland, lattice: String, cell: Vector2i
) -> Dictionary:
	var pick := _roll(island, lattice, cell, SALT_PICK)
	# The cheap way out, the ground layer's own: no weight anywhere can reach
	# this far along the line, so nothing here can be placed and nothing about
	# the island here needs to be asked.
	if pick >= ceiling_of(lattice):
		return {}

	var size := DecorationScatter.cell_size(lattice)
	var x := island.centre_x + (float(cell.x) + lerpf(
		JITTER_LOW, JITTER_HIGH, _roll(island, lattice, cell, SALT_JITTER_X)
	)) * size
	var z := island.centre_z + (float(cell.y) + lerpf(
		JITTER_LOW, JITTER_HIGH, _roll(island, lattice, cell, SALT_JITTER_Z)
	)) * size

	# The cheap half of "is this on the island": anything further out than the
	# outline can possibly reach is off it, and saying so costs a subtraction
	# rather than a run of the outline solver. About one cell in three of the
	# square the lattice covers is thrown out here.
	var away_x := x - island.centre_x
	var away_z := z - island.centre_z
	var reach := island.max_reach()
	if away_x * away_x + away_z * away_z > reach * reach:
		return {}
	var ratio := island.ratio_at(x, z)
	if ratio > EDGE_KEEP:
		return {}
	if _wet(island, x, z):
		return {}
	if _too_steep(island, x, z):
		return {}

	var shares := {island.biome: 1.0}
	var on_rim := ratio >= RIM_BAND
	var running := 0.0
	for entry in ScatterCatalog.entries(lattice):
		if String(entry["context"]) != ScatterCatalog.CONTEXT_GROUND:
			# Everything else in the catalog needs a road, a building, a bank or
			# open water to stand by, and an island has none of those. Asking
			# the row rather than listing the rows keeps this layer from having
			# an opinion about what the table contains.
			continue
		var weight := ScatterCatalog.weight_of(entry, shares)
		if weight <= 0.0:
			continue
		if on_rim:
			weight *= RIM_ROCK_GAIN if String(entry["kind"]) == ScatterCatalog.KIND_ROCK \
				else RIM_THINNING
		running += weight
		if pick < running:
			return _placed(island, entry, lattice, cell, x, z)
	return {}


## The roots hanging from one island's keel.
##
## Counted out per island rather than per cell, because there are only a handful
## and they belong to the island as a whole rather than to any patch of it. Each
## is anchored on the underside at its own direction and distance out, and hangs
## straight down from there.
##
## The item's height is the *bottom* of the root, and its size is its length, so
## that the render layer's one rule -- a tag stands `size` tall from the height
## it was given -- puts the top of the root exactly on the keel it hangs from.
func roots_of(island: FloatingIsland) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not island.walkable:
		return found
	var count := ROOT_COUNT_MIN + int(
		_island_roll(island, SALT_ROOT_COUNT) * float(ROOT_COUNT_MAX - ROOT_COUNT_MIN + 1)
	)
	count = clampi(count, ROOT_COUNT_MIN, ROOT_COUNT_MAX)
	for at in count:
		var angle := _island_roll(island, SALT_ROOT_ANGLE + at * 7) * TAU
		var reach := lerpf(
			ROOT_REACH_MIN, ROOT_REACH_MAX,
			_island_roll(island, SALT_ROOT_REACH + at * 7),
		)
		var away := island.outline_radius(angle) * reach
		var x := island.centre_x + cos(angle) * away
		var z := island.centre_z + sin(angle) * away
		var length := clampf(
			island.keel_depth * lerpf(
				ROOT_LENGTH_MIN, ROOT_LENGTH_MAX,
				_island_roll(island, SALT_ROOT_LENGTH + at * 7),
			),
			ROOT_SHORTEST, ROOT_LONGEST,
		)
		var keel := island.bottom_height_at(x, z)
		found.append({
			"tag": AssetTags.HANGING_ROOT,
			"x": x,
			"z": z,
			"y": keel - length,
			"yaw": _island_roll(island, SALT_ROOT_YAW + at * 7) * TAU,
			"size": length,
			"kind": ScatterCatalog.KIND_UNDERGROWTH,
			"context": CONTEXT_KEEL,
		})
	return found


## The most the weights of one lattice can add up to here, for any biome and
## anywhere on the island.
##
## Worked out from the catalog and the rim band's own multipliers rather than
## written down as a number, so that retuning the table cannot leave a stale
## bound behind -- a bound that was too low would silently drop the tail of the
## table, which is the sort of bug nothing would ever notice.
static func ceiling_of(lattice: String) -> float:
	if _ceilings.has(lattice):
		return float(_ceilings[lattice])
	var highest := 0.0
	for biome in BiomeCatalog.IDS:
		var shares := {biome: 1.0}
		var open_ground := 0.0
		var on_rim := 0.0
		for entry in ScatterCatalog.entries(lattice):
			if String(entry["context"]) != ScatterCatalog.CONTEXT_GROUND:
				continue
			var weight := ScatterCatalog.weight_of(entry, shares)
			open_ground += weight
			on_rim += weight * (
				RIM_ROCK_GAIN if String(entry["kind"]) == ScatterCatalog.KIND_ROCK
				else RIM_THINNING
			)
		highest = maxf(highest, maxf(open_ground, on_rim))
	_ceilings[lattice] = highest
	return highest


## The placed thing itself: where it stands on the island's own surface, which
## way it faces, and how big it is.
##
## The height is the island's top surface at that position and nothing else --
## no hover, no water line -- because everything this layer places stands on the
## island's ground. That is what a test can check to a fraction of a unit.
func _placed(
	island: FloatingIsland,
	entry: Dictionary,
	lattice: String,
	cell: Vector2i,
	x: float,
	z: float,
) -> Dictionary:
	var shares := {island.biome: 1.0}
	var range_of := ScatterCatalog.size_of(entry, shares)
	return {
		"tag": String(entry["tag"]),
		"x": x,
		"z": z,
		"y": island.top_height_at(x, z),
		"yaw": _roll(island, lattice, cell, SALT_YAW) * TAU,
		"size": lerpf(range_of.x, range_of.y, _roll(island, lattice, cell, SALT_SIZE)),
		"kind": String(entry["kind"]),
		"context": CONTEXT_TOP,
	}


## Whether the island's own water covers this position, or comes close enough to
## it that something standing here would have its feet in the pond.
func _wet(island: FloatingIsland, x: float, z: float) -> bool:
	if not island.has_basin():
		return false
	if island.holds_water_at(x, z):
		return true
	for step in 4:
		var angle := TAU * float(step) / 4.0
		if island.holds_water_at(
			x + cos(angle) * POND_CLEAR, z + sin(angle) * POND_CLEAR
		):
			return true
	return false


## Whether the island's top falls away faster here than anything should stand
## on. Measured on the top surface itself, one step either side, exactly as the
## ground layer measures the bed.
func _too_steep(island: FloatingIsland, x: float, z: float) -> bool:
	var here := island.top_height_at(x, z)
	var across := absf(island.top_height_at(x + SLOPE_STEP, z) - here)
	var along := absf(island.top_height_at(x, z + SLOPE_STEP) - here)
	return maxf(across, along) / SLOPE_STEP > SLOPE_LIMIT


## One value in [0, 1) for a cell of one of an island's lattices.
##
## The island's cell and band go into the seed and the *local* cell into the
## coordinates. That is the whole point of this file: what an island grows is a
## fact about the island, so two islands that overlap in plan -- which the two
## aerial storeys always do -- grow different things.
func _roll(
	island: FloatingIsland, lattice: String, cell: Vector2i, salt: int
) -> float:
	var lattice_index := ScatterCatalog.LATTICES.find(lattice)
	return SimRng.hash_unit(
		world_seed + SEED_OFFSET
			+ island.band * BAND_STRIDE
			+ lattice_index * LATTICE_STRIDE
			+ salt * SALT_STRIDE
			+ SimRng.hash_ints(island.cell.x, island.cell.y, island.band),
		cell.x,
		cell.y,
	)


## One value in [0, 1) for the island as a whole, for the things that are
## counted out per island rather than per cell.
func _island_roll(island: FloatingIsland, salt: int) -> float:
	return SimRng.hash_unit(
		world_seed + SEED_OFFSET + island.band * BAND_STRIDE + salt * SALT_STRIDE,
		island.cell.x,
		island.cell.y,
	)
