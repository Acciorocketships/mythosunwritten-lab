extends TestSuite
## What is on a floating island: the cover on its top, the pond in its basin,
## the waterfall over its rim and the roots under its keel.
##
## Five claims live here, and each is the reason a piece of this layer is built
## the way it is.
##
## *An island's cover belongs to the island.* It is hashed from the island's own
## cell, its band and a cell of the island's own lattice -- never from where the
## island happens to hang. The two aerial storeys overlap in plan, so world
## coordinates would grow the same tree twice, once on each plate, one directly
## above the other. The overlap test below is that failure written down.
##
## *Nothing hovers and nothing sinks.* Everything the layer places on a top
## stands exactly on the island's surface at its own position, inside the
## outline, off the water and off the faces too steep to stand on. Everything it
## hangs under a keel meets the underside exactly. Both are checked over a few
## hundred islands across four seeds, against the island's own shape functions
## rather than against whatever the placement code thought it was doing.
##
## *A basin is a hole in the board.* Where an island's pond covers its top, the
## terrain query reports no surface there at all -- the same answer it gives
## over a lake, through the same call -- so the tactical layer gets the aerial
## layer's holes for free.
##
## *The rim survives the basin.* The middle of an island may now dip below its
## own rim, which is what lets it hold water. The boundary may not: the rim is
## still the lowest the top surface gets anywhere along the outline, which is
## what keeps `landing_step` and the clearance rule meaning what they meant.
##
## *The world does not depend on the animation.* The simulation says where a
## waterfall is, how wide it is and how far it falls. That it moves is the
## viewer's business, exactly as the water's ripples and the far sky's drift
## already are.
class_name TestIslandCover

const SEED := 11

## The seeds the survey runs over. More than one, because everything here is
## hashed per island and a claim about one world is a claim about a few dozen
## shapes.
const SURVEY_SEEDS := [11, 1234, 7, 4321]

## How many cells either way the surveys scan for islands.
const SCAN_CELLS := 5

## How many cells either way the overlap check scans. Wider, because it needs
## pairs of storeys that lap over each other *and* things standing in the lap.
const OVERLAP_CELLS := 9

## How close two heights have to be to count as the same surface. Well under a
## millimetre on a world whose chunks are sixteen units across.
const TOUCHING := 0.0005

## How many directions the boundary is sampled in when the rim is checked.
const BOUNDARY_DIRECTIONS := 96

## Where the screenshots in reports/islands.md are taken from.
const DRESSED_SEED := "1234"


func _init() -> void:
	suite_name = "island cover"


func run() -> void:
	var field := _new_field(SEED)
	var islands := _walkable_islands(field)
	check(islands.size() >= 6,
		"expected a decent handful of islands to dress, found %d" % islands.size())

	_the_weights_can_never_outrun_one_roll()
	_cover_names_only_tags_its_own_biome_can_grow(islands)
	_an_island_wears_the_colours_of_its_own_biome(islands)
	_two_storeys_that_overlap_carry_different_cover()
	_cover_is_the_same_after_an_island_is_dropped_and_returned_to()
	_nothing_hovers_sinks_or_stands_where_it_should_not()
	_roots_hang_from_the_keel(islands)
	_the_rim_is_still_the_lowest_point_on_the_boundary()
	_a_basin_holds_water_that_is_a_hole_in_the_board()
	_the_pond_is_its_own_surface_not_the_world_sheet()
	_the_simulation_decides_where_the_waterfall_is()
	_two_processes_dress_the_same_islands()


# --- The table -----------------------------------------------------------

## One roll in [0, 1) is compared against the weights laid end to end, so their
## largest possible total has to stay under one or the tail of the table could
## never be reached. The rim band multiplies some of those weights, so the bound
## has to be checked with the multiplier in it -- which is exactly what
## `ceiling_of` works out.
func _the_weights_can_never_outrun_one_roll() -> void:
	for lattice in ScatterCatalog.LATTICES:
		var ceiling := IslandCover.ceiling_of(lattice)
		check(ceiling > 0.0,
			"the %s lattice can grow nothing at all on an island" % lattice)
		check(ceiling < 1.0,
			"the %s lattice's island weights reach %.3f, so its last rows are unreachable"
			% [lattice, ceiling])


# --- What is placed ------------------------------------------------------

## Everything on an island is named by an asset tag, and by a tag the catalog
## gives that island's *own* biome a weight for. An island over a highland grows
## what a highland grows.
func _cover_names_only_tags_its_own_biome_can_grow(
	islands: Array[FloatingIsland]
) -> void:
	var cover := IslandCover.new(SEED)
	var tops := 0
	for island in islands:
		var shares := {island.biome: 1.0}
		for item in cover.build(island).items:
			var tag := String(item["tag"])
			check(AssetTags.is_tag(tag),
				"an island grew '%s', which is not in the tag catalog" % tag)
			if String(item["context"]) == IslandCover.CONTEXT_KEEL:
				equal(tag, AssetTags.HANGING_ROOT,
					"only roots hang off a keel, and this was a '%s'" % tag)
				continue
			tops += 1
			var entry := ScatterCatalog.entry_for(tag)
			check(not entry.is_empty(),
				"an island grew '%s', which the scatter catalog has no row for" % tag)
			if entry.is_empty():
				continue
			equal(String(entry["context"]), ScatterCatalog.CONTEXT_GROUND,
				"'%s' needs a %s to stand by, which an island has none of"
				% [tag, entry["context"]])
			check(ScatterCatalog.weight_of(entry, shares) > 0.0,
				"an island in the %s grew '%s', which does not grow there"
				% [island.biome, tag])
	check(tops > 40,
		"the islands of seed %d grew only %d things between them" % [SEED, tops])


## The island already carries the ground, rock and water colours of the country
## it broke off from, and the cover and the cliff are drawn in those.
##
## Those colours are the *blend* at the island's centre rather than the named
## biome's own values, which is the right thing and worth saying: the biome
## fields blend across a border, so a chunk of land torn out near one takes the
## colours of the ground it actually left, not of the label that ground happens
## to resolve to. What is checked here is that the island's three tints are the
## ground's own at its centre and nothing else -- so the cover on top of it, the
## cliff round it and the pond in it all match the plate.
func _an_island_wears_the_colours_of_its_own_biome(
	islands: Array[FloatingIsland]
) -> void:
	var biomes := BiomeField.new(SEED)
	for island in islands:
		check(BiomeCatalog.has_biome(island.biome),
			"an island claims the biome '%s', which is not one" % island.biome)
		equal(island.biome, biomes.biome_at(island.centre_x, island.centre_z),
			"an island's biome is not the biome of the ground under its centre")
		check(island.ground_tint.is_equal_approx(
			biomes.ground_tint_at(island.centre_x, island.centre_z)),
			"an island is not the ground colour of the country it broke off")
		check(island.rock_tint.is_equal_approx(
			biomes.rock_tint_at(island.centre_x, island.centre_z)),
			"an island is not the rock colour of the country it broke off")
		check(island.water_tint.is_equal_approx(
			biomes.water_tint_at(island.centre_x, island.centre_z)),
			"an island does not hold the water colour of the country it broke off")
		# And the blended profile at the island's centre -- which is what the
		# render layer dresses an island's cover with -- carries those same two
		# colours, so a boulder on an island is the colour of the cliff it
		# stands beside rather than of whatever is far below.
		var profile := biomes.profile_at(island.centre_x, island.centre_z)
		check(profile.ground_tint.is_equal_approx(island.ground_tint),
			"the profile at an island's centre is not the island's ground colour")
		check(profile.rock_tint.is_equal_approx(island.rock_tint),
			"the profile at an island's centre is not the island's rock colour")


## Two storeys that lap over each other in plan carry different cover.
##
## This is the whole reason the lattice is the island's own. Hashed from world x
## and z, both plates would decide the same cell of the same lattice the same
## way, so wherever they overlap the upper island would grow exactly what the
## lower one grew, at exactly the same offset inside the cell -- a tree directly
## above a tree, over every overlapping pair in the world. So the check is not
## "the two covers differ somewhere" but the sharper one: **not one thing on the
## upper plate stands at the same place, with the same tag, as a thing on the
## lower plate**, which is precisely what world hashing would produce for all of
## them.
func _two_storeys_that_overlap_carry_different_cover() -> void:
	var pairs := 0
	var coincidences := 0
	var compared := 0
	for seed_value in SURVEY_SEEDS:
		var field := _new_field(seed_value)
		var cover := IslandCover.new(seed_value)
		# A wider scan than the rest of the suite uses. An upper storey laps
		# over the lower one's rim by design -- that lap is the staircase -- so
		# the overlap is a thin lens on the stoniest, most thinned-out part of
		# both plates, and it takes a good many pairs to gather enough standing
		# in one to conclude anything.
		for cell_x in range(-OVERLAP_CELLS, OVERLAP_CELLS + 1):
			for cell_z in range(-OVERLAP_CELLS, OVERLAP_CELLS + 1):
				var cell := Vector2i(cell_x, cell_z)
				var lower := field.island_in_cell(FloatingIsland.AERIAL, cell)
				var upper := field.island_in_cell(FloatingIsland.AERIAL_UPPER, cell)
				if lower == null or upper == null:
					continue
				var overlap_lower := _items_over_both(cover, lower, upper)
				var overlap_upper := _items_over_both(cover, upper, lower)
				if overlap_lower.is_empty() or overlap_upper.is_empty():
					continue
				pairs += 1
				compared += overlap_upper.size()
				for above in overlap_upper:
					for below in overlap_lower:
						if String(above["tag"]) != String(below["tag"]):
							continue
						if absf(float(above["x"]) - float(below["x"])) < 0.02 \
								and absf(float(above["z"]) - float(below["z"])) < 0.02:
							coincidences += 1
	check(pairs >= 6,
		"found only %d overlapping pairs to compare cover on" % pairs)
	check(compared >= 25,
		"only %d things stand in the overlaps, which is too few to conclude from"
		% compared)
	equal(coincidences, 0,
		("%d of %d things on an upper storey stand exactly where the same thing"
		+ " stands on the plate below -- cover is being hashed from world"
		+ " position") % [coincidences, compared])
	print("        island cover: %d overlapping storey pairs, %d things in the laps, %d coincidences"
		% [pairs, compared, coincidences])


## What one island grows in the part of its top that another island's plan also
## covers.
func _items_over_both(
	cover: IslandCover, island: FloatingIsland, other: FloatingIsland
) -> Array:
	var found := []
	for item in cover.build(island).items:
		if String(item["context"]) != IslandCover.CONTEXT_TOP:
			continue
		if other.covers(float(item["x"]), float(item["z"])):
			found.append(item)
	return found


## An island dropped and later returned to comes back dressed exactly as it was.
##
## Through the streamer, which is where the claim actually has to hold: an
## observer walks away until the island is unloaded, walks back, and the cover's
## fingerprint has to be the one it had before.
func _cover_is_the_same_after_an_island_is_dropped_and_returned_to() -> void:
	var world := SimWorld.new(SEED)
	# Stand next to an island, so that the streamer has one to hand. The origin
	# need not have one near it, and this test is about reloading rather than
	# about where islands are.
	var target := _walkable_islands(world.island_field)[0]
	world.place_observer(target.centre_x, target.centre_z)
	var found := Vector3i.ZERO
	var before := ""
	for key in world.island_streamer.loaded_keys():
		if key.z == FloatingIsland.FAR_SKY:
			continue
		var patch := world.island_streamer.live_cover(key)
		if patch == null or patch.count() == 0:
			continue
		found = key
		before = patch.digest()
		break
	check(before != "", "no dressed island was loaded to test reloading with")
	if before == "":
		return

	world.place_observer(target.centre_x + 4000.0, target.centre_z + 4000.0)
	check(not world.island_streamer.is_loaded(found),
		"walking four thousand units away did not unload the island")
	world.place_observer(target.centre_x, target.centre_z)
	check(world.island_streamer.is_loaded(found),
		"walking back did not reload the island")
	var after := world.island_streamer.live_cover(found)
	check(after != null, "the reloaded island came back with no cover at all")
	if after != null:
		equal(after.digest(), before,
			"an island came back from an unload dressed differently")


## Nothing the layer places is anywhere but exactly on the surface it belongs
## to, and nothing is placed where nothing should be.
##
## Checked against the island's own shape functions over every walkable island
## in four seeds, which is a few hundred of them: the height has to be the
## island's top surface at that position to within half a millimetre, the
## position has to be inside the outline and off its lip, the island's own pond
## must not cover it, and the ground under it must not be a face.
func _nothing_hovers_sinks_or_stands_where_it_should_not() -> void:
	var checked := 0
	var hovering := 0
	var outside := 0
	var wet := 0
	var steep := 0
	for seed_value in SURVEY_SEEDS:
		var field := _new_field(seed_value)
		var cover := IslandCover.new(seed_value)
		for island in _walkable_islands(field):
			for item in cover.build(island).items:
				if String(item["context"]) != IslandCover.CONTEXT_TOP:
					continue
				checked += 1
				var x := float(item["x"])
				var z := float(item["z"])
				if absf(float(item["y"]) - island.top_height_at(x, z)) > TOUCHING:
					hovering += 1
				if island.ratio_at(x, z) > IslandCover.EDGE_KEEP + 0.0001:
					outside += 1
				if island.holds_water_at(x, z):
					wet += 1
				var here := island.top_height_at(x, z)
				var fall := maxf(
					absf(island.top_height_at(x + IslandCover.SLOPE_STEP, z) - here),
					absf(island.top_height_at(x, z + IslandCover.SLOPE_STEP) - here),
				)
				if fall / IslandCover.SLOPE_STEP > IslandCover.SLOPE_LIMIT + 0.0001:
					steep += 1
	check(checked > 2000,
		"only %d things were placed across four seeds, too few to conclude from"
		% checked)
	equal(hovering, 0,
		"%d of %d things on an island top were not standing on it" % [hovering, checked])
	equal(outside, 0,
		"%d of %d things stood past the lip of an island" % [outside, checked])
	equal(wet, 0,
		"%d of %d things stood in an island's own pond" % [wet, checked])
	equal(steep, 0,
		"%d of %d things stood on a face too steep to stand on" % [steep, checked])
	print(("        island cover: %d placements over %d seeds -- %d hovering,"
		+ " %d past the lip, %d in water, %d on a face") % [
		checked, SURVEY_SEEDS.size(), hovering, outside, wet, steep,
	])


## Every island has roots hanging off its keel, and each meets the underside
## exactly: the top of the root is the island's bottom surface at that position.
func _roots_hang_from_the_keel(islands: Array[FloatingIsland]) -> void:
	var cover := IslandCover.new(SEED)
	for island in islands:
		var roots := cover.roots_of(island)
		check(roots.size() >= IslandCover.ROOT_COUNT_MIN,
			"an island hangs only %d roots off its keel" % roots.size())
		for root in roots:
			var x := float(root["x"])
			var z := float(root["z"])
			equal(String(root["tag"]), AssetTags.HANGING_ROOT,
				"a keel is hung with '%s'" % root["tag"])
			check(island.covers(x, z),
				"a root hangs off the side of the island rather than under it")
			check(absf(
				float(root["y"]) + float(root["size"]) - island.bottom_height_at(x, z)
			) < TOUCHING,
				"a root does not meet the keel it hangs from")
			check(float(root["size"]) >= IslandCover.ROOT_SHORTEST - TOUCHING,
				"a root is %.3f units long, shorter than any should be"
				% float(root["size"]))


# --- The basin -----------------------------------------------------------

## The rim is still the lowest the top surface gets anywhere on the boundary,
## whether or not the island's middle dips below it.
##
## This is the guarantee everything about reachability rests on. `landing_step`
## is measured from the rim, and so is the room the keel hangs into, so the
## basin is allowed to take the middle under the rim only for as long as it
## cannot take the boundary with it.
func _the_rim_is_still_the_lowest_point_on_the_boundary() -> void:
	var basins := 0
	var spills := 0
	var checked := 0
	var below := 0
	var dipped := 0
	for seed_value in SURVEY_SEEDS:
		for island in _walkable_islands(_new_field(seed_value)):
			checked += 1
			if island.has_basin():
				basins += 1
			if island.has_spill():
				spills += 1
			var lowest := INF
			for step in BOUNDARY_DIRECTIONS:
				var angle := TAU * float(step) / float(BOUNDARY_DIRECTIONS)
				var away := island.outline_radius(angle)
				var top := island.top_height_at(
					island.centre_x + cos(angle) * away,
					island.centre_z + sin(angle) * away,
				)
				lowest = minf(lowest, top)
				if top < island.rim_height - TOUCHING:
					below += 1
			if absf(lowest - island.rim_height) > TOUCHING:
				below += 1
			if island.has_basin() \
					and island.top_height_at(island.centre_x, island.centre_z) \
						< island.rim_height:
				dipped += 1
			check(island.landing_step < TerrainQuery.HOP_HEIGHT,
				"an island's step up is %.3f, which is not a hop" % island.landing_step)
	equal(below, 0,
		"the top surface dropped below the rim on the boundary of an island %d times"
		% below)
	check(basins >= 8,
		"only %d of %d islands hold a basin, which is too few to be a feature"
		% [basins, checked])
	check(spills >= 3,
		"only %d islands overflow their rim across four seeds" % spills)
	check(dipped >= 1,
		"no island's middle actually dips below its own rim, so no basin holds"
		+ " anything the rim is not already holding")
	print(("        island cover: %d islands over %d seeds -- %d with a basin,"
		+ " %d overflowing, %d dipping below their own rim, %d boundary samples below it") % [
		checked, SURVEY_SEEDS.size(), basins, spills, dipped, below,
	])


## Where an island's pond covers its top, the terrain query says there is no
## surface there -- a hole in the board -- and says it is water, through the
## same calls that answer for a lake on the ground.
func _a_basin_holds_water_that_is_a_hole_in_the_board() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var island := _first_basin(terrain.island_field)
	check(island != null, "no island in seed %d holds a pond" % SEED)
	if island == null:
		return

	var wet := Vector2(island.centre_x, island.centre_z)
	check(island.holds_water_at(wet.x, wet.y),
		"the middle of a basin is not under the pond that fills it")
	check(island.pond_depth_at(wet.x, wet.y) > 0.0,
		"the pond in a basin has no depth at its middle")

	var top := island.top_height_at(wet.x, wet.y)
	for surface in terrain.surfaces_at(wet.x, wet.y):
		check(absf(surface - top) > TOUCHING,
			"the terrain query offers the floor of a pond as somewhere to stand")
	check(terrain.is_void_at(wet.x, wet.y, island.rim_height),
		"standing on the rim, the pond in the middle is not a hole")
	check(terrain.is_water_at(wet.x, wet.y, island.rim_height),
		"standing on the island, its own pond does not report as water")
	check(terrain.water_depth_at_height(wet.x, wet.y, island.rim_height) > 0.0,
		"the island's own water has no depth when asked from the island")

	# And the same call, with no height, still answers for the ground far below,
	# which is what everything that walks the ground plane depends on.
	equal(terrain.is_water_at(wet.x, wet.y),
		terrain.water_field.is_water_at(wet.x, wet.y),
		"asking about the ground under an island stopped answering for the ground")

	# Dry ground on the same island is still ground.
	var dry := _dry_spot(island)
	check(dry != Vector2.INF,
		"an island with a pond has nowhere dry left on it")
	if dry != Vector2.INF:
		check(not terrain.is_void_at(dry.x, dry.y, island.top_height_at(dry.x, dry.y)),
			"the dry part of an island with a pond is a hole too")

	var found := terrain.ground_at(wet.x, wet.y)
	check(bool(found["island_water"]),
		"the gathered answer does not report the island's own water")


## The pond is its own surface: built per island, hanging with it, and never
## part of the one world-space sheet the rivers and lakes are drawn on.
func _the_pond_is_its_own_surface_not_the_world_sheet() -> void:
	var world := SimWorld.new(SEED)
	var island := _first_basin(world.island_field)
	check(island != null, "no island in seed %d holds a pond" % SEED)
	if island == null:
		return
	var pond := IslandMesher.new().build_water(island)
	check(pond.triangle_count() > 0,
		"an island with a basin has no pond geometry in it")
	check(pond.wet_cells > 0, "an island's pond covers no corner of it")

	# Every corner of the pond stands at the island's own water level or on its
	# shore, which is tens of units above whatever the world's water is doing
	# under it -- so nothing here could have come off the world's sheet.
	var world_surface := world.terrain.water_surface_at(island.centre_x, island.centre_z)
	var above := 0
	for vertex in pond.vertices:
		if vertex.y > world_surface + 1.0:
			above += 1
	equal(above, pond.vertices.size(),
		"%d of %d pond corners are not clear of the world's water surface"
		% [pond.vertices.size() - above, pond.vertices.size()])

	# An island with no basin has a sheet with nothing in it, rather than no
	# sheet: the streamer stores one either way, so the fingerprint is uniform.
	var bare := _first_without_basin(world.island_field)
	if bare != null:
		equal(IslandMesher.new().build_water(bare).triangle_count(), 0,
			"an island with no basin was given a pond anyway")


## The simulation decides everything about the waterfall except that it moves.
func _the_simulation_decides_where_the_waterfall_is() -> void:
	var field := _new_field(SEED)
	var island := _first_spill(field)
	if island == null:
		for seed_value in SURVEY_SEEDS:
			island = _first_spill(_new_field(seed_value))
			if island != null:
				break
	check(island != null, "no island anywhere overflows its rim")
	if island == null:
		return

	# The fall leaves the island exactly on its outline.
	var ratio := island.ratio_at(island.spill_x, island.spill_z)
	check(absf(ratio - 1.0) < 0.001,
		"the waterfall leaves the island at ratio %.4f rather than at its rim" % ratio)
	check(island.spill_width > 0.0, "the waterfall has no width")
	check(island.spill_fall > island.rim_thickness,
		"the waterfall stops before it has cleared the rim it falls off")

	# The water reaches the rim: just inside the outline, in the spill's own
	# direction, the island is under its own water.
	var inward := 0.97
	var away := island.outline_radius(island.spill_angle) * inward
	var lip_x := island.centre_x + cos(island.spill_angle) * away
	var lip_z := island.centre_z + sin(island.spill_angle) * away
	check(island.holds_water_at(lip_x, lip_z),
		"the spillway is dry where it reaches the rim it is supposed to pour over")

	# And the channel's floor stays above the rim, which is the condition that
	# lets the wedge be cut at all without taking the boundary down with it.
	check(island.spill_floor > island.rim_height,
		"the spillway's floor is cut below the rim, which would break the landing")

	# Nothing about the fall depends on when it is asked about: the island is
	# the same island however many times it is read, and there is no clock in
	# any of it.
	var again := island.detached_copy()
	equal(again.digest(), island.digest(),
		"an island's own copy of itself describes a different waterfall")


# --- Across processes ----------------------------------------------------

## Two separate processes dress the same islands the same way, byte for byte.
##
## The island report now carries a line per island for what is on it, what the
## basin holds and where the fall is, so this is the same comparison the
## placement already gets, extended to the dressing.
func _two_processes_dress_the_same_islands() -> void:
	var first := _run_headless(["--seed", DRESSED_SEED, "--ticks", "0", "--islands"])
	var second := _run_headless(["--seed", DRESSED_SEED, "--ticks", "0", "--islands"])
	equal(first["exit_code"], 0, "the island report should exit 0")
	check(first["output"].contains("island-cover-summary"),
		"the island report printed no cover summary")
	check(first["output"].contains("island-cover-tag hanging_root"),
		"the island report found no roots on any island")
	equal(first["output"], second["output"],
		"two processes dressed the same islands differently")


# --- Helpers -------------------------------------------------------------

func _new_field(seed_value: int) -> IslandField:
	var surface := TerrainSurfaceField.new(seed_value)
	var biomes := BiomeField.new(seed_value)
	return IslandField.new(WaterField.new(surface, biomes), biomes)


func _walkable_islands(field: IslandField) -> Array[FloatingIsland]:
	var found: Array[FloatingIsland] = []
	for band in FloatingIsland.WALKABLE_BANDS:
		for cell_x in range(-SCAN_CELLS, SCAN_CELLS + 1):
			for cell_z in range(-SCAN_CELLS, SCAN_CELLS + 1):
				var island := field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island != null:
					found.append(island)
	return found


func _first_basin(field: IslandField) -> FloatingIsland:
	for island in _walkable_islands(field):
		if island.has_basin():
			return island
	return null


func _first_without_basin(field: IslandField) -> FloatingIsland:
	for island in _walkable_islands(field):
		if not island.has_basin():
			return island
	return null


func _first_spill(field: IslandField) -> FloatingIsland:
	for island in _walkable_islands(field):
		if island.has_spill():
			return island
	return null


## Somewhere on an island that its pond does not cover, or Vector2.INF.
func _dry_spot(island: FloatingIsland) -> Vector2:
	for step in 16:
		var angle := TAU * float(step) / 16.0
		var away := island.outline_radius(angle) * 0.8
		var x := island.centre_x + cos(angle) * away
		var z := island.centre_z + sin(angle) * away
		if not island.holds_water_at(x, z):
			return Vector2(x, z)
	return Vector2.INF


## Run the documented headless command and capture what it printed.
func _run_headless(arguments: Array) -> Dictionary:
	var command: Array = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
	]
	command.append_array(arguments)
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), command, output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}
