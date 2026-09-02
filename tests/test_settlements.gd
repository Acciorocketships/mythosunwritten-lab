extends TestSuite
## The settlement layer: villages, the ground under them, and the roads between.
##
## Five claims live here, and they are the five the layer is for.
##
## *A village is a fact about a cell and a seed.* The same cells are asked from a
## fresh field, in reversed order, through a world that has walked for a while,
## and through two worlds that arrived from opposite directions. Every route has
## to produce the same village -- including a village whose ground straddles a
## chunk border, which has to be the same village and the same geometry whichever
## of its chunks was built first.
##
## *The ground under a village is levelled and its buildings reserve their
## ground.* The relief under the levelled core has to collapse to nearly nothing,
## and asking "is there a building here" has to answer truthfully, because that
## is the contract the scatter layer will hold this layer to.
##
## *Buildings are placed by tag, turned to face the green, and never overlap.*
## Every tag has to be one the catalog knows; every pair of footprints has to be
## separable; and every building has to stand on the levelled part.
##
## *Roads join places, are carved, and are bridged.* A road has to be agreed on
## from both of its ends, has to leave a levelled dirt track in the ground and in
## its colour, and has to carry a bridge tag over every stretch of water it
## crosses. The track it leaves has to be walkable and level: no step of finished
## roadway may climb more than a character can step up, and nowhere may the
## roadway be further out of level across its own width than the depth it is worn
## into the land.
##
## *The layer never creates or destroys water.* It moves dry ground only, and it
## leaves the ground it moves above the water line -- so whether a position is
## water stays the water field's answer alone.
class_name TestSettlements

const SEED := 1234
const OTHER_SEED := 7

## How far the ground where two roads converge may be out of level across a
## track beyond the land it was worn into, in world units.
##
## Not a tolerance on the levelling: nothing levels that ground. It is the slack
## the trough itself needs, since the depth fades with each road's own share and
## the two verges need not carry the same share of it. Measured at 0.019 over the
## roads of seed 1234, against the 0.30 the road is worn in.
const CONVERGING_SLACK := 0.10

## How far from the origin the roadway is walked for the wall check, in world
## units. Wider than the square the villages are gathered from, because the
## ground where roads converge is at the landmarks as much as at the villages and
## the steepest of it is where a road meets a mountain shoulder.
const WALL_REACH := 800.0

## How far out, in settlement cells, the suite gathers villages to work from.
##
## Three is a seven-by-seven square of cells, about eighteen hundred units on a
## side. It used to be two, which was enough when the ground near this seed's
## origin was all gentle: five villages came out of the five-by-five square, and
## the claims here are about one village and about the rule that places it.
## The mountains changed the supply rather than the rule -- a pad is refused
## ground with more relief than it can level, and the range that now stands over
## this origin refuses most of the inner cells -- so the square was widened to
## keep enough villages to test with. None of the checks below were relaxed.
const CELL_REACH := 3

## Where the second square of the water invariant sits. The wettest 360-unit
## square within a kilometre of this seed's origin: since the mountains went in,
## the origin's own square stands forty units above the water table and holds no
## water at all, and a claim about what the settlement layer does to water needs
## some water in the sample.
const WATER_SAMPLE_CENTRE := Vector2(480.0, -480.0)

## The seeds and the reach, in island cells, of the overhang sweep at the end of
## the placement checks. It has to meet a configuration the world only makes
## some of the time -- a lower island wide enough for its upper storey to reach
## a long way past it -- so it looks across several seeds and a wide square, and
## counts what it met rather than assuming it met anything.
const OVERHANG_SEEDS := [1234, 7, 3, 19, 42, 101]
const OVERHANG_CELL_REACH := 5

## How many places along the overhang the sweep tries, walking in from its far
## edge. One point would land wherever it landed; a handful finds the stretch
## that is over the pad wherever on the overhang it happens to be.
const OVERHANG_STEPS := 12

## How far an upper storey reaches past its lower island's outline, as a
## multiple of the lower island's radius.
##
## The upper island stands off to one side of the lower one by up to
## (1 + UPPER_RADIUS_SHARE_MAX) x UPPER_OFFSET_SHARE_MAX = 1.683 of that radius
## and reaches UPPER_RADIUS_SHARE_MAX x OUTLINE_REACH_MAX = 0.929 further,
## against the lower island's own OUTLINE_REACH_MAX = 1.327 -- so it can hang
## about 1.28 lower radii out past the lower outline. The sweep uses this only
## to skip the lower islands too small for the configuration it is looking for.
const UPPER_OVERHANG_SHARE := 1.285


func _init() -> void:
	suite_name = "settlements"


func run() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var villages := _villages(terrain.settlement_field, CELL_REACH)
	check(villages.size() >= 4,
		"expected a handful of villages to test with, found %d" % villages.size())
	if villages.is_empty():
		return

	_a_village_is_a_pure_function_of_its_cell_and_the_seed(villages)
	_asking_the_cells_in_another_order_changes_nothing()
	_a_different_seed_puts_the_villages_somewhere_else(villages)
	_the_world_starts_within_a_walk_of_a_village(terrain)
	_villages_keep_out_of_the_marsh_and_out_of_the_water(terrain, villages)
	_a_share_of_villages_stand_on_a_shore()
	_nothing_hangs_over_a_village(terrain, villages)
	_an_upper_storey_can_no_longer_overhang_a_village()
	_no_two_buildings_overlap(villages)
	_every_building_stands_on_the_levelled_ground(villages)
	_everything_placed_names_a_catalog_tag(terrain, villages)
	_buildings_face_the_green(villages)
	_the_ground_under_a_village_is_levelled(terrain, villages)
	_a_building_reserves_the_ground_it_stands_on(terrain, villages)
	_a_village_straddling_a_chunk_border_is_the_same_either_way_round(terrain, villages)
	_two_worlds_arriving_from_opposite_sides_load_the_same_village(villages)
	_roads_are_agreed_on_from_both_ends(terrain, villages)
	_a_road_is_a_levelled_dirt_track(terrain, villages)
	_no_step_of_finished_roadway_is_a_wall(terrain)
	_a_bridge_stands_wherever_a_road_crosses_water(terrain)
	_the_layer_never_creates_or_destroys_water(terrain)
	_a_village_streams_and_reloads_identically()
	_two_processes_build_the_same_villages(villages)


# --- Gathering -----------------------------------------------------------

## Every village in a square of cells around the origin, in cell order. The suite
## works from these rather than from whatever a streamer happened to load, so
## what it is checking is the field and not the streaming.
func _villages(field: SettlementField, reach: int) -> Array[Settlement]:
	var found: Array[Settlement] = []
	for cell_x in range(-reach, reach + 1):
		for cell_z in range(-reach, reach + 1):
			var site := field.settlement_in_cell(Vector2i(cell_x, cell_z))
			if site != null:
				found.append(site)
	return found


func _digests(villages: Array[Settlement]) -> PackedStringArray:
	var out := PackedStringArray()
	for site in villages:
		out.append(site.digest())
	return out


# --- Placement is a fact about a cell and a seed --------------------------

func _a_village_is_a_pure_function_of_its_cell_and_the_seed(
	villages: Array[Settlement]
) -> void:
	var again := _villages(TerrainQuery.for_seed(SEED).settlement_field, CELL_REACH)
	equal(_digests(again), _digests(villages),
		"a fresh field for the same seed built different villages")


func _asking_the_cells_in_another_order_changes_nothing() -> void:
	var forwards := TerrainQuery.for_seed(SEED).settlement_field
	var backwards := TerrainQuery.for_seed(SEED).settlement_field
	var cells: Array[Vector2i] = []
	for cell_x in range(-CELL_REACH, CELL_REACH + 1):
		for cell_z in range(-CELL_REACH, CELL_REACH + 1):
			cells.append(Vector2i(cell_x, cell_z))

	var ahead := {}
	for cell in cells:
		var site := forwards.settlement_in_cell(cell)
		ahead[cell] = site.digest() if site != null else "none"
	# The same cells, from the far end, on a field that has also been asked a few
	# hundred unrelated questions first. Neither may change an answer.
	for i in 300:
		backwards.settlement_at(float(i) * 13.7 - 900.0, float(i) * -9.1 + 400.0)
	cells.reverse()
	for cell in cells:
		var site := backwards.settlement_in_cell(cell)
		var found := site.digest() if site != null else "none"
		equal(found, ahead[cell],
			"cell (%d, %d) came out differently when asked from the other end"
			% [cell.x, cell.y])


func _a_different_seed_puts_the_villages_somewhere_else(
	villages: Array[Settlement]
) -> void:
	var other := _villages(
		TerrainQuery.for_seed(OTHER_SEED).settlement_field, CELL_REACH
	)
	not_equal(_digests(other), _digests(villages),
		"two different seeds produced exactly the same villages")


func _the_world_starts_within_a_walk_of_a_village(terrain: TerrainQuery) -> void:
	var home := terrain.settlement_field.settlement_in_cell(
		SettlementField.cell_at(0.0, 0.0)
	)
	check(home != null, "the cell holding the world origin has no starting village")
	if home == null:
		return
	check(home.is_spawn, "the starting village does not know it is the starting village")
	var away := Vector2(home.centre_x, home.centre_z).length()
	check(away >= SettlementField.SPAWN_RING_MIN - 0.001
			and away <= SettlementField.SPAWN_RING_MAX + 0.001,
		"the starting village is %.1f from the origin, outside the %.0f..%.0f ring"
		% [away, SettlementField.SPAWN_RING_MIN, SettlementField.SPAWN_RING_MAX])
	# And the origin itself is outside the village, so the world is walked into
	# rather than handed over.
	check(away > home.radius,
		"the world starts inside the village: %.1f from its middle, radius %.1f"
		% [away, home.radius])


func _villages_keep_out_of_the_marsh_and_out_of_the_water(
	terrain: TerrainQuery, villages: Array[Settlement]
) -> void:
	for site in villages:
		not_equal(site.biome, BiomeCatalog.TWILIGHT_MARSH,
			"a village was placed in the twilight marsh at (%.1f, %.1f)"
			% [site.centre_x, site.centre_z])
		check(float(SettlementField.BIOME_SHARE.get(site.biome, 0.0)) > 0.0,
			"a village stands in %s, which the placement rule does not settle"
			% site.biome)
		# Nothing on the levelled ground is in the water.
		for direction in 16:
			var angle := TAU * float(direction) / 16.0
			var x := site.centre_x + cos(angle) * site.core_radius
			var z := site.centre_z + sin(angle) * site.core_radius
			check(not terrain.is_water_at(x, z),
				"the levelled ground of the village at (%.1f, %.1f) is under water"
				% [site.centre_x, site.centre_z])


# --- Villages on a shore -------------------------------------------------

## The seeds and reach the shore survey runs over. Wider than the rest of the
## suite, because a shore village is a minority of a minority: a cell has to
## want a shore, have standing water in it, and have somewhere beside that water
## flat enough to level.
const SHORE_SEEDS := [1234, 7, 3, 19, 42, 101, 5, 11]
const SHORE_CELL_REACH := 4

## The band the measured share of shore villages has to fall in, as a share of
## all villages. Stated here rather than derived, so that a change to the siting
## rule that quietly stops making shore villages -- or that turns every village
## into one -- fails rather than passes.
const SHORE_SHARE_LOW := 0.08
const SHORE_SHARE_HIGH := 0.30


## A stated share of villages stand on a shore, and every one of them obeys
## every rule the layer enforces on the rest.
##
## The share is the point of the rule and the rules are the price of it: a
## village that got its pond by building in it, or by skipping the levelling, or
## by standing under a floating island, would not be a village.
func _a_share_of_villages_stand_on_a_shore() -> void:
	var villages := 0
	var shores: Array[Dictionary] = []
	for world_seed: int in SHORE_SEEDS:
		var terrain := TerrainQuery.for_seed(world_seed)
		for site in _villages(terrain.settlement_field, SHORE_CELL_REACH):
			villages += 1
			if site.is_shore:
				shores.append({"site": site, "terrain": terrain})
	check(villages >= 100,
		"expected a wide sample of villages to measure the shore share on, found %d"
		% villages)
	if villages == 0:
		return

	var share := float(shores.size()) / float(villages)
	check(share >= SHORE_SHARE_LOW and share <= SHORE_SHARE_HIGH,
		"%d of %d villages (%.1f%%) were sited by the shore rule, outside the "
		% [shores.size(), villages, share * 100.0]
		+ "stated %.0f%%-%.0f%% band" % [SHORE_SHARE_LOW * 100.0, SHORE_SHARE_HIGH * 100.0])
	print("        settlements: %d of %d villages (%.1f%%) sited by the shore rule over %d seeds"
		% [shores.size(), villages, share * 100.0, SHORE_SEEDS.size()])

	for found in shores:
		var site: Settlement = found["site"]
		var terrain: TerrainQuery = found["terrain"]
		_the_shore_village_has_a_shore(site, terrain)
		_the_shore_village_keeps_its_ground(site, terrain)
	# The rules the whole layer is held to, run over the shore villages on their
	# own so that a failure names the shore rule rather than hiding in a sample
	# that is nine parts inland village.
	var only_shores: Array[Settlement] = []
	for found in shores:
		only_shores.append(found["site"])
	if only_shores.is_empty():
		return
	_no_two_buildings_overlap(only_shores)
	_every_building_stands_on_the_levelled_ground(only_shores)
	_buildings_face_the_green(only_shores)


## There really is standing water beside it: what the rule was for.
func _the_shore_village_has_a_shore(site: Settlement, terrain: TerrainQuery) -> void:
	var wet := 0
	var far := site.radius + SettlementField.SHORE_WATER_REACH
	for ring in SettlementField.SHORE_RINGS:
		var share := (float(ring) + 1.0) / float(SettlementField.SHORE_RINGS)
		var near := site.core_radius + SettlementField.SHORE_DRY_MARGIN
		var reach := near + (far - near) * share
		for direction in SettlementField.SHORE_DIRECTIONS:
			var angle := TAU * float(direction) / float(SettlementField.SHORE_DIRECTIONS)
			var x := site.centre_x + cos(angle) * reach
			var z := site.centre_z + sin(angle) * reach
			if not terrain.is_water_at(x, z):
				continue
			# Standing water, not a river: the surface is the table's rather than
			# a level following the ground downhill.
			if absf(terrain.water_field.surface_level_at(x, z)
					- terrain.water_field.table_level_at(x, z)) < 0.0001:
				wet += 1
	check(wet >= SettlementField.SHORE_WET_MIN,
		"the shore village at (%.1f, %.1f) has %d standing-water probes beside it, "
		% [site.centre_x, site.centre_z, wet]
		+ "fewer than the %d the rule requires" % SettlementField.SHORE_WET_MIN)


## And it pays for it in nothing: dry where it builds, level, unroofed, and with
## every footprint on ground the layer reserved.
func _the_shore_village_keeps_its_ground(site: Settlement, terrain: TerrainQuery) -> void:
	# No building stands in water -- tested on the rectangles themselves rather
	# than on a ring, because the rectangles are what is reserved.
	for building in site.buildings:
		check(not terrain.is_water_at(float(building["x"]), float(building["z"])),
			"a %s in the shore village at (%.1f, %.1f) stands in water"
			% [building["tag"], site.centre_x, site.centre_z])
		for corner in Settlement.footprint_corners(building):
			check(not terrain.is_water_at(corner.x, corner.y),
				"a corner of a %s in the shore village at (%.1f, %.1f) is in water"
				% [building["tag"], site.centre_x, site.centre_z])
		check(terrain.is_reserved_at(float(building["x"]), float(building["z"])),
			"a %s in a shore village does not reserve the ground it stands on"
			% building["tag"])
	# The band of dry ground the shore rule keeps outside the levelled core.
	for direction in SettlementField.PAD_RIM_DIRECTIONS:
		var angle := TAU * float(direction) / float(SettlementField.PAD_RIM_DIRECTIONS)
		var out := site.core_radius + SettlementField.SHORE_DRY_MARGIN
		check(not terrain.is_water_at(
				site.centre_x + cos(angle) * out, site.centre_z + sin(angle) * out),
			"the dry band round the shore village at (%.1f, %.1f) is under water"
			% [site.centre_x, site.centre_z])
	# Levelled, and to the height it says.
	check(_relief(site, terrain, false) < 0.35,
		"the levelled ground of the shore village at (%.1f, %.1f) still rises and falls"
		% [site.centre_x, site.centre_z])
	check(absf(terrain.ground_height_at(site.centre_x, site.centre_z) - site.pad_height)
			< 0.02,
		"the middle of a shore village is not at its own pad height")
	# The overhead veto, which the shore rule does not relax.
	for band in FloatingIsland.WALKABLE_BANDS:
		check(terrain.island_field.islands_near(
				band, site.centre_x, site.centre_z, site.radius).is_empty(),
			"an island of storey %d hangs over the shore village at (%.1f, %.1f)"
			% [band, site.centre_x, site.centre_z])
	# And the starting village is never one of these: its ring rule owns it.
	check(not site.is_spawn, "the starting village was sited by the shore rule")


# --- Nothing hangs over a village ----------------------------------------

## No island of either walkable storey comes within a village's pad.
##
## This is the whole of what the overhead gate is for: a village with a plate
## overhead has a house standing on ground the composed world refuses to level,
## and a plate resting on its rooftops. Both storeys are asked, because both are
## land somebody walks on and either can be the thing overhead.
func _nothing_hangs_over_a_village(
	terrain: TerrainQuery, villages: Array[Settlement]
) -> void:
	for site in villages:
		for band in FloatingIsland.WALKABLE_BANDS:
			var over := terrain.island_field.islands_near(
				band, site.centre_x, site.centre_z, site.radius
			)
			check(over.is_empty(),
				"an island of storey %d hangs within the pad of the village at (%.1f, %.1f)"
				% [band, site.centre_x, site.centre_z])


## The gap the old overhead rule left, closed.
##
## The gate used to ask the lower storey alone, with the pad's radius widened by
## the widest island there is (IslandField.AERIAL_RADIUS_MAX), as a stand-in for
## "an upper storey might be standing beside this one". But an upper storey
## reaches about UPPER_OVERHANG_SHARE of its lower island's radius past that
## island's outline, so above any lower island wider than
## AERIAL_RADIUS_MAX / UPPER_OVERHANG_SHARE -- about nineteen units, which the
## aerial layer places routinely -- the upper plate outreached the padding: it
## could hang over the outer stretch of a village pad while the padded question
## about the lower band came back clear sky.
##
## So the sweep looks for exactly that: a spot where an upper island is within a
## pad's radius and the old padded question was empty. Every one it finds has to
## be refused now -- and it has to find some, or it is a check about nothing.
func _an_upper_storey_can_no_longer_overhang_a_village() -> void:
	var pad := SettlementField.PAD_RADIUS_MAX
	var padded := pad + IslandField.AERIAL_RADIUS_MAX
	var wide_enough := IslandField.AERIAL_RADIUS_MAX / UPPER_OVERHANG_SHARE
	var uppers := 0
	var gaps := 0
	for world_seed: int in OVERHANG_SEEDS:
		var settlements := TerrainQuery.for_seed(world_seed).settlement_field
		var field := settlements.islands
		for cell_x in range(-OVERHANG_CELL_REACH, OVERHANG_CELL_REACH + 1):
			for cell_z in range(-OVERHANG_CELL_REACH, OVERHANG_CELL_REACH + 1):
				var cell := Vector2i(cell_x, cell_z)
				# Only a lower island wide enough for its upper storey to
				# outreach the old padding can open the gap, and building an
				# upper storey is not cheap, so the rest are passed over.
				var low := field.island_in_cell(FloatingIsland.AERIAL, cell)
				if low == null or low.radius <= wide_enough:
					continue
				var up := field.island_in_cell(FloatingIsland.AERIAL_UPPER, cell)
				if up == null:
					continue
				uppers += 1
				# Walk in from the far edge of the upper island along the line
				# away from the lower one it stands beside, which is where its
				# overhang reaches furthest past the lower island's outline.
				var away := Vector2(up.centre_x - low.centre_x, up.centre_z - low.centre_z)
				if away.length() < 0.001:
					continue
				away = away.normalized()
				for step in OVERHANG_STEPS:
					var out := up.max_reach() \
						+ pad * (1.0 - float(step) / float(OVERHANG_STEPS))
					var x := up.centre_x + away.x * out
					var z := up.centre_z + away.y * out
					var overhead := not field.islands_near(
						FloatingIsland.AERIAL_UPPER, x, z, pad
					).is_empty()
					var old_rule_saw_nothing := field.islands_near(
						FloatingIsland.AERIAL, x, z, padded
					).is_empty()
					if not overhead or not old_rule_saw_nothing:
						continue
					gaps += 1
					check(not settlements._clear_overhead(x, z, pad),
						("an upper storey hangs within a pad's radius of "
						+ "(%.1f, %.1f) on seed %d, and the settlement layer "
						+ "calls that sky clear") % [x, z, world_seed])
					break
	check(uppers >= 10,
		"the sweep met only %d upper storeys wide enough to open the gap" % uppers)
	check(gaps >= 2,
		"the sweep found %d spots the old padded rule let through, too few to be checking anything"
		% gaps)
	print("        settlements: %d wide upper storeys swept, %d spots the old padded rule let through"
		% [uppers, gaps])


# --- Buildings ------------------------------------------------------------

func _no_two_buildings_overlap(villages: Array[Settlement]) -> void:
	var pairs := 0
	var overlapping := 0
	var worst := ""
	for site in villages:
		for first in site.buildings.size():
			for second in range(first + 1, site.buildings.size()):
				pairs += 1
				if Settlement.footprints_overlap(
					site.buildings[first], site.buildings[second]
				):
					overlapping += 1
					worst = "%s at (%.1f, %.1f) and %s at (%.1f, %.1f)" % [
						site.buildings[first]["tag"],
						site.buildings[first]["x"], site.buildings[first]["z"],
						site.buildings[second]["tag"],
						site.buildings[second]["x"], site.buildings[second]["z"],
					]
	check(pairs > 60,
		"only %d pairs of buildings to compare, which is too few to mean much"
		% pairs)
	equal(overlapping, 0,
		"%d of %d pairs of buildings overlap; one of them is %s"
		% [overlapping, pairs, worst])

	# And the spacing rule is more than "not overlapping": there is clear ground
	# between every pair, which is what keeps a village from reading as terraced.
	var crowded := 0
	for site in villages:
		for first in site.buildings.size():
			for second in range(first + 1, site.buildings.size()):
				if Settlement.footprints_overlap(
					site.buildings[first], site.buildings[second],
					SettlementField.BUILDING_GAP,
				):
					crowded += 1
	equal(crowded, 0,
		"%d pairs of buildings are closer than the %.1f-unit spacing rule allows"
		% [crowded, SettlementField.BUILDING_GAP])


func _every_building_stands_on_the_levelled_ground(
	villages: Array[Settlement]
) -> void:
	for site in villages:
		for building in site.buildings:
			var corners := Settlement.footprint_corners(building)
			for corner in corners:
				var away := Vector2(
					corner.x - site.centre_x, corner.y - site.centre_z
				).length()
				check(away <= site.core_radius + 0.001,
					"a %s corner is %.2f from the middle of a village whose "
					% [building["tag"], away]
					+ "levelled ground stops at %.2f" % site.core_radius)


func _everything_placed_names_a_catalog_tag(
	terrain: TerrainQuery, villages: Array[Settlement]
) -> void:
	for site in villages:
		for building in site.buildings:
			var tag := String(building["tag"])
			check(AssetTags.is_tag(tag), "'%s' is not a catalog tag" % tag)
			equal(AssetTags.category_of(tag), AssetTags.BUILDINGS,
				"'%s' is placed as a building but is not in the buildings category"
				% tag)
		for prop in site.props:
			var tag := String(prop["tag"])
			check(AssetTags.is_tag(tag), "'%s' is not a catalog tag" % tag)
	# The roads name tags too, and their bridges have to be bridges.
	for road in _roads_near(terrain, villages):
		for bridge in road["bridges"]:
			equal(AssetTags.category_of(String(bridge["tag"])), AssetTags.BRIDGES,
				"'%s' is placed as a bridge but is not in the bridges category"
				% bridge["tag"])
		for prop in road["props"]:
			check(AssetTags.is_tag(String(prop["tag"])),
				"'%s' is not a catalog tag" % prop["tag"])


func _buildings_face_the_green(villages: Array[Settlement]) -> void:
	for site in villages:
		for building in site.buildings:
			if building["tag"] == AssetTags.WELL:
				continue
			# A building's local +Z is its front, so the point one step in front
			# of it has to be nearer the middle of the village than it is.
			var yaw := float(building["yaw"])
			var here := Vector2(float(building["x"]), float(building["z"]))
			var middle := Vector2(site.centre_x, site.centre_z)
			var ahead := here + Vector2(sin(yaw), cos(yaw))
			check(ahead.distance_to(middle) < here.distance_to(middle),
				"a %s at (%.1f, %.1f) is not facing the green"
				% [building["tag"], here.x, here.y])


# --- The ground under a village -------------------------------------------

func _the_ground_under_a_village_is_levelled(
	terrain: TerrainQuery, villages: Array[Settlement]
) -> void:
	var flattened := 0
	for site in villages:
		var before := _relief(site, terrain, true)
		var after := _relief(site, terrain, false)
		check(after < 0.35,
			"the levelled ground of the village at (%.1f, %.1f) still rises and "
			% [site.centre_x, site.centre_z]
			+ "falls by %.2f" % after)
		check(after < before,
			"levelling the village at (%.1f, %.1f) did not flatten anything: "
			% [site.centre_x, site.centre_z]
			+ "%.2f before, %.2f after" % [before, after])
		if before - after > 0.5:
			flattened += 1
		# And it is levelled to the height the village says it is.
		var middle := terrain.ground_height_at(site.centre_x, site.centre_z)
		check(absf(middle - site.pad_height) < 0.02,
			"the middle of the village sits at %.3f, not at its pad height %.3f"
			% [middle, site.pad_height])
	check(flattened >= villages.size() / 2,
		"only %d of %d villages had any meaningful relief taken out of them"
		% [flattened, villages.size()])

	# Outside the pad the land is untouched, so a village is set into the world
	# rather than standing on a shelf cut out of it.
	for site in villages:
		for direction in 8:
			var angle := TAU * float(direction) / 8.0
			var out := site.radius + 6.0
			var x := site.centre_x + cos(angle) * out
			var z := site.centre_z + sin(angle) * out
			if terrain.path_strength_at(x, z) > 0.0 or terrain.is_water_at(x, z):
				continue
			check(absf(
				terrain.ground_height_at(x, z) - terrain.water_field.bed_height_at(x, z)
			) < 0.001, "the ground %.0f units outside a village has been moved" % out)


## How much the ground rises and falls over a village's levelled core, either
## before this layer touches it (the water field's own bed) or after (the
## composed ground everything actually walks on).
func _relief(site: Settlement, terrain: TerrainQuery, before: bool) -> float:
	var lowest := INF
	var highest := -INF
	for ring in 4:
		var ratio := float(ring) / 3.0
		var directions := 1 if ring == 0 else 12
		for direction in directions:
			var angle := TAU * float(direction) / float(directions)
			var x := site.centre_x + cos(angle) * site.core_radius * ratio
			var z := site.centre_z + sin(angle) * site.core_radius * ratio
			var height := terrain.water_field.bed_height_at(x, z) if before \
				else terrain.ground_height_at(x, z)
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	return highest - lowest


func _a_building_reserves_the_ground_it_stands_on(
	terrain: TerrainQuery, villages: Array[Settlement]
) -> void:
	var inside := 0
	for site in villages:
		for building in site.buildings:
			# The middle of a building, and a point well inside each quadrant of
			# its footprint, are all reserved.
			for corner: Vector2 in [Vector2(0.6, 0.6), Vector2(-0.6, 0.6),
					Vector2(0.6, -0.6), Vector2(-0.6, -0.6), Vector2.ZERO]:
				var yaw := float(building["yaw"])
				var across := Vector2(cos(yaw), -sin(yaw)) \
					* corner.x * float(building["half_width"])
				var along := Vector2(sin(yaw), cos(yaw)) \
					* corner.y * float(building["half_depth"])
				var x := float(building["x"]) + across.x + along.x
				var z := float(building["z"]) + across.y + along.y
				inside += 1
				check(terrain.is_reserved_at(x, z),
					"a point inside a %s at (%.2f, %.2f) is not reserved"
					% [building["tag"], x, z])
				equal(terrain.building_at(x, z)["tag"], building["tag"],
					"the reservation at (%.2f, %.2f) names the wrong building"
					% [x, z])
	check(inside > 100, "only %d points inside buildings were checked" % inside)

	# Well clear of every building, the ground is free -- which is what makes the
	# reservation worth asking about rather than a village-shaped no-go area.
	var free := 0
	for site in villages:
		for direction in 24:
			var angle := TAU * float(direction) / 24.0
			var x := site.centre_x + cos(angle) * site.core_radius * 0.98
			var z := site.centre_z + sin(angle) * site.core_radius * 0.98
			if terrain.is_reserved_at(x, z):
				continue
			free += 1
	check(free > villages.size() * 4,
		"only %d points on the village greens were free of buildings" % free)

	# And outside a village nothing is reserved at all.
	for site in villages:
		check(not terrain.is_reserved_at(
			site.centre_x + site.radius + 12.0, site.centre_z
		), "ground outside a village is reserved")


# --- Streaming order ------------------------------------------------------

## The claim the acceptance line makes: a village whose ground crosses a chunk
## border is the same village, and the same geometry, whichever of its chunks was
## built first.
##
## Both halves matter. The village itself must not depend on load order, and
## neither must the ground the mesher builds out of it -- a village that was
## identical but whose levelling reached one chunk and not the other would still
## show as a step along the chunk seam.
func _a_village_straddling_a_chunk_border_is_the_same_either_way_round(
	terrain: TerrainQuery, villages: Array[Settlement]
) -> void:
	var straddling := _straddling_village(villages)
	check(not straddling.is_empty(),
		"no village in range straddles a chunk border, so the claim is untested")
	if straddling.is_empty():
		return
	var site: Settlement = straddling["site"]
	var first: Vector2i = straddling["first"]
	var second: Vector2i = straddling["second"]

	# Two independent stacks for the same seed, each meshing the two chunks in
	# the opposite order to the other.
	var ahead := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	var ahead_first := ahead.build(first.x, first.y)
	var ahead_second := ahead.build(second.x, second.y)
	var behind := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	var behind_second := behind.build(second.x, second.y)
	var behind_first := behind.build(first.x, first.y)

	equal(behind_first.digest(), ahead_first.digest(),
		"chunk (%d, %d) under the village at (%.1f, %.1f) came out differently "
		% [first.x, first.y, site.centre_x, site.centre_z]
		+ "when its neighbour was built first")
	equal(behind_second.digest(), ahead_second.digest(),
		"chunk (%d, %d) under the same village came out differently when it was "
		% [second.x, second.y]
		+ "built first")

	# And the village behind both of them is the same village either way.
	equal(
		behind.terrain.settlement_field.settlement_in_cell(site.cell).digest(),
		ahead.terrain.settlement_field.settlement_in_cell(site.cell).digest(),
		"the village straddling the border is not the same village either way round")

	# The two chunks really do share the village: it reaches into both.
	check(_village_reaches_chunk(site, first) and _village_reaches_chunk(site, second),
		"the two chunks chosen do not both hold part of the village")


## A village whose levelled ground reaches into two neighbouring chunks, with
## those two chunks. Empty when there is none, which the caller reports.
func _straddling_village(villages: Array[Settlement]) -> Dictionary:
	for site in villages:
		var here := TerrainChunkMesher.chunk_at(site.centre_x, site.centre_z)
		var west := Vector2i(here.x - 1, here.y)
		if _village_reaches_chunk(site, here) and _village_reaches_chunk(site, west):
			return {"site": site, "first": here, "second": west}
	return {}


## Whether any of a village's levelled ground falls inside a chunk.
func _village_reaches_chunk(site: Settlement, key: Vector2i) -> bool:
	return TerrainChunkMesher.distance_to_chunk(key, site.centre_x, site.centre_z) \
		< site.core_radius


func _two_worlds_arriving_from_opposite_sides_load_the_same_village(
	villages: Array[Settlement]
) -> void:
	var site: Settlement = villages[villages.size() / 2]
	var from_east := SimWorld.new(SEED)
	var from_west := SimWorld.new(SEED)
	# Two worlds walked to the same village from opposite directions, so the
	# chunks under it, the roads into it and the village itself are all streamed
	# in the opposite order in one from the other.
	for step in 6:
		var share := float(step + 1) / 6.0
		from_east.place_observer(
			site.centre_x + (1.0 - share) * 120.0, site.centre_z
		)
		from_west.place_observer(
			site.centre_x - (1.0 - share) * 120.0, site.centre_z
		)
	equal(from_west.settlement_streamer.live_settlement(site.cell).digest(),
		from_east.settlement_streamer.live_settlement(site.cell).digest(),
		"two worlds that walked into the village from opposite sides disagree "
		+ "about what is in it")
	equal(from_west.terrain.ground_height_at(site.centre_x, site.centre_z),
		from_east.terrain.ground_height_at(site.centre_x, site.centre_z),
		"the two worlds disagree about how high the village's ground is")


func _a_village_streams_and_reloads_identically() -> void:
	var world := SimWorld.new(SEED)
	var site := world.settlement_field.settlement_in_cell(
		SettlementField.cell_at(0.0, 0.0)
	)
	check(site != null, "expected a starting village to stream")
	if site == null:
		return
	world.place_observer(site.centre_x, site.centre_z)
	check(world.settlement_streamer.is_loaded(site.cell),
		"standing in the village did not load it")
	var loaded := world.settlement_streamer.live_settlement(site.cell).digest()

	# Walk far enough away for it to be dropped, then come back.
	world.place_observer(site.centre_x + 4000.0, site.centre_z + 4000.0)
	check(not world.settlement_streamer.is_loaded(site.cell),
		"the village was still loaded from four thousand units away")
	world.place_observer(site.centre_x, site.centre_z)
	equal(world.settlement_streamer.live_settlement(site.cell).digest(), loaded,
		"the village came back different after being dropped and reloaded")

	# What a viewer is handed is a copy: writing into it cannot reach the world.
	var handed := world.settlement_streamer.settlement(site.cell)
	handed.buildings.clear()
	handed.centre_x = 999.0
	equal(world.settlement_streamer.live_settlement(site.cell).digest(), loaded,
		"editing the copy handed to a viewer changed the village in the world")


func _two_processes_build_the_same_villages(villages: Array[Settlement]) -> void:
	# Not literally two processes -- that is what the headless fingerprint check
	# in the report does -- but two independently constructed stacks that share
	# nothing but the seed, which is the same claim inside one process.
	var world := SimWorld.new(SEED)
	for site in villages:
		var again := world.settlement_field.settlement_in_cell(site.cell)
		check(again != null, "a village vanished when asked through a world")
		if again != null:
			equal(again.digest(), site.digest(),
				"the village in cell (%d, %d) differs between two stacks"
				% [site.cell.x, site.cell.y])


# --- Roads ----------------------------------------------------------------

## Every road with a village at one end, gathered by proximity so that roads
## owned by a landmark are found too.
func _roads_near(terrain: TerrainQuery, villages: Array[Settlement]) -> Array:
	var found := []
	var seen := {}
	for site in villages:
		for road in terrain.path_network.edges_near(
			site.centre_x, site.centre_z, site.radius + 30.0
		):
			if seen.has(road["id"]):
				continue
			seen[road["id"]] = true
			found.append(road)
	return found


func _roads_are_agreed_on_from_both_ends(
	terrain: TerrainQuery, villages: Array[Settlement]
) -> void:
	var roads := _roads_near(terrain, villages)
	check(roads.size() >= 6,
		"expected the villages to be joined to something, found %d roads"
		% roads.size())
	if roads.is_empty():
		return

	var network := terrain.path_network
	for road in roads:
		# Every road runs between two real places, and it is the same road when
		# it is looked for from the far end of itself as from the near end.
		var points: PackedVector2Array = road["points"]
		var far := points[points.size() - 1]
		var from_far := network.edges_near(far.x, far.y, 2.0)
		var found := false
		for other in from_far:
			if other["id"] == road["id"]:
				found = true
				equal(SettlementStreamer.road_digest(other),
					SettlementStreamer.road_digest(road),
					"the road %s is a different road seen from its far end"
					% road["id"])
		check(found, "the road %s is not there when looked for from its far end"
			% road["id"])
		check(float(road["length"]) <= PathNetwork.LINK_RADIUS + 0.001,
			"the road %s is %.1f long, past the %.0f linking radius"
			% [road["id"], road["length"], PathNetwork.LINK_RADIUS])

	# And a second, independent network for the same seed builds the same roads.
	var again := TerrainQuery.for_seed(SEED)
	for road in roads:
		var matched := false
		var points: PackedVector2Array = road["points"]
		for other in again.path_network.edges_near(points[0].x, points[0].y, 2.0):
			if other["id"] != road["id"]:
				continue
			matched = true
			equal(SettlementStreamer.road_digest(other),
				SettlementStreamer.road_digest(road),
				"a fresh network for the same seed built the road %s differently"
				% road["id"])
		check(matched, "a fresh network for the same seed has no road %s" % road["id"])


func _a_road_is_a_levelled_dirt_track(
	terrain: TerrainQuery, villages: Array[Settlement]
) -> void:
	var roads := _roads_near(terrain, villages)
	var shared := 0
	var on_road := 0
	var carved := 0
	var browner := 0
	var across_checked := 0
	var beside_checked := 0
	var dropped := 0.0
	var levelled := 0.0
	var untouched := 0.0
	for road in roads:
		var points: PackedVector2Array = road["points"]
		for at in points.size():
			var point := points[at]
			if terrain.is_water_at(point.x, point.y):
				continue
			if terrain.settlement_at(point.x, point.y) != null:
				continue
			if terrain.island_field.walkable_island_over(point.x, point.y) != null:
				continue
			var strength := terrain.path_strength_at(point.x, point.y)
			if strength < 0.999:
				continue
			on_road += 1

			# It reads as dirt: its ground colour is at least halfway from the
			# biome's own ground colour to bare earth.
			var tint := terrain.ground_tint_at(point.x, point.y)
			var plain := terrain.biome_field.ground_tint_at(point.x, point.y)
			if _from_dirt(tint) <= _from_dirt(plain) * 0.5 + 0.0001:
				browner += 1

			# It is worn into the land: the ground on the road is below the
			# ground that was there before the road was carved into it.
			var here := terrain.ground_height_at(point.x, point.y)
			var before := _ground_before_roads(terrain, point.x, point.y)
			beside_checked += 1
			if here < before - 0.05:
				carved += 1
			dropped += before - here

			# And it is levelled across its width: two points either side of the
			# centreline, both still on the roadway, sit at the same height.
			# Skipped at the water's edge, where the road stops and the bridge
			# takes over, so the two sides are not both roadway, and under a
			# floating island, where the layer deliberately does not move the
			# ground at all.
			var along := _road_direction(points, at)
			var across := Vector2(-along.y, along.x) * PathNetwork.PATH_HALF_WIDTH * 0.8
			if terrain.is_bank_at(point.x, point.y):
				continue
			var left_x := point.x + across.x
			var left_z := point.y + across.y
			var right_x := point.x - across.x
			var right_z := point.y - across.y
			if terrain.is_water_at(left_x, left_z) or terrain.is_water_at(right_x, right_z):
				continue
			if terrain.island_field.walkable_island_over(left_x, left_z) != null \
					or terrain.island_field.walkable_island_over(right_x, right_z) != null:
				continue
			# A verge the shore floor is holding up is not the carving's
			# doing: the layer promises never to put ground below the water
			# line, and where a road runs along a bank that promise, not the
			# levelling, decides the height. Skipped for the same reason the
			# centreline at a bank is.
			if terrain.is_bank_at(left_x, left_z) or terrain.is_bank_at(right_x, right_z):
				continue
			var left := terrain.ground_height_at(left_x, left_z)
			var right := terrain.ground_height_at(right_x, right_z)
			var bare_left := terrain.water_field.bed_height_at(left_x, left_z)
			var bare_right := terrain.water_field.bed_height_at(right_x, right_z)
			levelled += absf(left - right)
			untouched += absf(bare_left - bare_right)
			across_checked += 1
			# Where one road levels this ground, the roadway is level across
			# itself. The bound is the depth of the road itself -- a step larger
			# than the trough it lives in would be a fault in the ground rather
			# than the shape of a road. Both verges project to the same place on
			# the same centreline and level to the same height, so this holds
			# however steep the land it crosses.
			if terrain.path_network.level_strength_at(point.x, point.y) >= 0.999:
				shared += 1
				check(absf(left - right) < PathNetwork.PATH_DEPTH,
					"the roadway at (%.1f, %.1f) is %.3f out of level across"
					% [point.x, point.y, absf(left - right)]
					+ " itself, with one road levelling it")
				continue

			# Where two roads converge on a place they both end at, no single
			# centreline is the one this ground is level with -- the ground under
			# a fork is under both tracks at once, and levelling it across one of
			# them tilts it across the other. So the levelling stands off, and
			# what is asserted is that standing off is all it does: the ground
			# there is the land's own, carrying the trough and nothing else.
			#
			# The carve used to level that ground to a share-weighted blend of
			# both centrelines instead. On flat country the two stand at the same
			# height and the blend is invisible; on a mountain shoulder it left
			# the roadway out of level by up to 0.95 against the 0.30 it is worn
			# in, and put four steps of finished road on this seed past the climb
			# a character can make.
			var land := absf(
				_ground_before_roads(terrain, left_x, left_z)
				- _ground_before_roads(terrain, right_x, right_z)
			)
			check(absf(left - right) <= land + CONVERGING_SLACK,
				"the ground where roads converge at (%.1f, %.1f) is %.3f out of"
				% [point.x, point.y, absf(left - right)]
				+ " level across the track, past the %.3f of the land it is" % land
				+ " worn into")

	check(on_road > 40,
		"only %d points were squarely on a road, which is too few to mean much"
		% on_road)
	check(shared * 10 > across_checked * 8,
		"only %d of %d roadway points are levelled to one road's centreline;"
		% [shared, across_checked]
		+ " the ground the levelling stands off is meant to be the exception")
	check(_share(carved, beside_checked) > 0.9,
		"only %d of %d points on a road sit below the ground the road replaced"
		% [carved, beside_checked])
	var mean_drop := _share_of(dropped, beside_checked)
	check(mean_drop > PathNetwork.PATH_DEPTH * 0.5
			and mean_drop < PathNetwork.PATH_DEPTH * 1.5,
		"a road is worn %.3f into the land on average, against the %.2f it is "
		% [mean_drop, PathNetwork.PATH_DEPTH] + "meant to be")
	equal(browner, on_road,
		"%d of %d points on a road were not tinted towards dirt"
		% [on_road - browner, on_road])
	# And the levelling is not an accident of already-level ground: across the
	# roadway the land tilts markedly less than it does untouched.
	check(across_checked > 30,
		"only %d points had both sides of the roadway on dry land" % across_checked)
	check(levelled < untouched * 0.35,
		"the roadway tilts %.3f across itself on average against %.3f for the "
		% [_share_of(levelled, across_checked), _share_of(untouched, across_checked)]
		+ "untouched land, which is not flattening")


## No step of finished roadway is a wall a character cannot walk up.
##
## The routing already refuses to lay a road up land steeper than that, scoring
## its candidate lines against its own grade limit. But the routing scores the
## *land*, and carving a road moves the ground after the line has been chosen, so
## the guarantee is worth exactly what the carving leaves of it. This asks the
## finished ground the same question, over every road near the origin rather than
## only the roads at the villages, walked at the step the routing scored at.
##
## It is the carve levelling each stretch of ground to one road's centreline and
## to no blend of two that makes the answer come out: on a road's own centreline
## the nearest road is that road at no distance at all, so the roadway takes the
## height of the land under it less the depth of the trough, and climbs exactly
## what the land climbs. Levelling to a blend of two centrelines put four steps
## of this seed's roads past the limit; see reports/roads.md.
func _no_step_of_finished_roadway_is_a_wall(terrain: TerrainQuery) -> void:
	var climb_limit := PathNetwork.ROUTE_GRADE_LIMIT * PathNetwork.ROUTE_SAMPLE_STEP
	var walls := 0
	var steps := 0
	var worst := 0.0
	var seen := {}
	for place in terrain.path_network.places_near(0.0, 0.0, WALL_REACH):
		for road in terrain.path_network.edges_from(place):
			if seen.has(road["id"]):
				continue
			seen[road["id"]] = true
			var points: PackedVector2Array = road["points"]
			var stepped := PackedVector2Array()
			for index in points.size() - 1:
				var pieces := maxi(1, int(ceil(
					points[index].distance_to(points[index + 1])
					/ PathNetwork.ROUTE_SAMPLE_STEP
				)))
				for piece in pieces:
					stepped.append(points[index].lerp(
						points[index + 1], float(piece) / float(pieces)
					))
			stepped.append(points[points.size() - 1])
			var last := terrain.ground_height_at(stepped[0].x, stepped[0].y)
			for index in range(1, stepped.size()):
				var height := terrain.ground_height_at(
					stepped[index].x, stepped[index].y
				)
				var climb := absf(height - last)
				last = height
				steps += 1
				worst = maxf(worst, climb)
				if climb > climb_limit:
					walls += 1
					if walls <= 4:
						check(false,
							"the roadway on %s climbs %.3f over one %.1f-unit"
							% [road["id"], climb, PathNetwork.ROUTE_SAMPLE_STEP]
							+ " step at (%.1f, %.1f), past the %.1f a character"
							% [stepped[index].x, stepped[index].y, climb_limit]
							+ " can walk up")
	check(steps > 3000, "only %d steps of roadway were walked" % steps)
	equal(walls, 0,
		"%d of %d steps of finished roadway are a wall; the worst climbs %.3f"
		% [walls, steps, worst])


## The share of a count, guarding the empty case.
func _share(part: int, whole: int) -> float:
	return 0.0 if whole <= 0 else float(part) / float(whole)


## The mean of a running total, guarding the empty case.
func _share_of(total: float, count: int) -> float:
	return 0.0 if count <= 0 else total / float(count)


## The ground at a position with the villages levelled but no road carved into
## it: what the road was worn into. The composed query has no way to hand this
## back -- it is a step in the middle of its own arithmetic -- so it is put back
## together here out of the two layers underneath.
func _ground_before_roads(terrain: TerrainQuery, x: float, z: float) -> float:
	var bed := terrain.water_field.bed_height_at(x, z)
	return bed + terrain.settlement_field.ground_delta_at(x, z, bed)


func _road_direction(points: PackedVector2Array, at: int) -> Vector2:
	var before := points[maxi(0, at - 1)]
	var after := points[mini(points.size() - 1, at + 1)]
	if before.is_equal_approx(after):
		return Vector2.RIGHT
	return (after - before).normalized()


## How far a colour is from bare earth. Zero is the earth itself. A road's
## colour has to be at least halfway from the biome's own ground colour to this,
## which is a claim that holds however close to earth the biome already was.
func _from_dirt(tint: Color) -> float:
	var earth := BiomeCatalog.PATH_DIRT
	return Vector3(
		tint.r - earth.r, tint.g - earth.g, tint.b - earth.b
	).length()


func _a_bridge_stands_wherever_a_road_crosses_water(terrain: TerrainQuery) -> void:
	# Looked for over a wide square rather than only near the sampled villages,
	# because whether a road happens to cross water is a matter of where the
	# rivers are.
	var crossings := 0
	var bridged := 0
	var checked := 0
	var seen := {}
	var span := 620.0
	var step := 110.0
	var at := -span
	while at <= span:
		var across := -span
		while across <= span:
			for road in terrain.path_network.edges_near(at, across, 90.0):
				if seen.has(road["id"]):
					continue
				seen[road["id"]] = true
				var bridges: Array = road["bridges"]
				# Only a stretch of water clearly wider than the shortest span
				# worth bridging is counted, so that the two sides of this claim
				# cannot disagree over a puddle a metre across. Every bridge is
				# then checked individually below, which is the other direction
				# of the same claim.
				if _crosses_water(terrain, road):
					crossings += 1
					if not bridges.is_empty():
						bridged += 1
				for bridge in bridges:
					checked += 1
					# A bridge stands over water...
					check(terrain.is_water_at(
						float(bridge["x"]), float(bridge["z"])
					), "a bridge at (%.1f, %.1f) does not stand over water"
						% [bridge["x"], bridge["z"]])
					# ...with its deck above the water's surface...
					check(float(bridge["height"]) > terrain.water_surface_at(
						float(bridge["x"]), float(bridge["z"])
					), "a bridge deck is at or below the water it crosses")
					# ...and the road is not carved out from under it.
					equal(terrain.ground_height_at(
							float(bridge["x"]), float(bridge["z"])),
						terrain.water_field.bed_height_at(
							float(bridge["x"]), float(bridge["z"])),
						"the river bed under a bridge has been carved by the road")
			across += step
		at += step
	check(crossings > 0,
		"no road in a %.0f-unit square crosses water, so bridging is untested"
		% (2.0 * span))
	equal(bridged, crossings,
		"%d of %d roads that cross water carry no bridge"
		% [crossings - bridged, crossings])
	check(checked > 0, "no bridges were examined")


## Whether a road has any water under it, sampled finely enough that it agrees
## with the bridge placement.
func _crosses_water(terrain: TerrainQuery, road: Dictionary) -> bool:
	var points: PackedVector2Array = road["points"]
	var run := 0.0
	for at in points.size() - 1:
		var start := points[at]
		var finish := points[at + 1]
		var span := start.distance_to(finish)
		var steps := maxi(1, int(span))
		for step in steps:
			var share := float(step) / float(steps)
			var here := start.lerp(finish, share)
			if terrain.is_water_at(here.x, here.y):
				run += span / float(steps)
				if run >= PathNetwork.BRIDGE_MIN_SPAN + 2.0:
					return true
			else:
				run = 0.0
	return false


# --- The water invariant --------------------------------------------------

func _the_layer_never_creates_or_destroys_water(terrain: TerrainQuery) -> void:
	var bare := WaterField.new(
		TerrainSurfaceField.new(SEED), BiomeField.new(SEED)
	)
	# Two squares, because one cannot answer both halves of the claim any more.
	# The square on the origin is where the villages and the roads are, so it is
	# what shows the layer running at all; on this seed the range that now stands
	# over that origin has lifted the land far above the water table, and there
	# is no water left in it to check. The second square is the wettest
	# 360-unit square within a kilometre of the origin, found by sweeping the
	# water field with tools/measure_mountains.sh's sibling probe, and it is what
	# shows the layer leaving water alone.
	var dry := 0
	var wet := 0
	var moved := 0
	for middle: Vector2 in [Vector2(0.0, 0.0), WATER_SAMPLE_CENTRE]:
		var counts := _water_invariant_over(terrain, bare, middle)
		dry += int(counts["dry"])
		wet += int(counts["wet"])
		moved += int(counts["moved"])
	check(wet > 80, "only %d wet samples, which is too few to mean much" % wet)
	check(dry > 1000, "only %d dry samples" % dry)
	check(moved > 50,
		"only %d samples had their ground moved by this layer, so the check "
		% moved + "hardly proves the layer is running")


## One 360-unit square of the water invariant, as {dry, wet, moved}.
func _water_invariant_over(
	terrain: TerrainQuery, bare: WaterField, middle: Vector2
) -> Dictionary:
	var dry := 0
	var wet := 0
	var moved := 0
	for row in 60:
		for column in 60:
			var x := middle.x + float(column) * 6.0 - 180.0
			var z := middle.y + float(row) * 6.0 - 180.0
			# Being water is the water field's answer, and this layer cannot
			# change it: the composed query and the bare field agree everywhere.
			equal(terrain.is_water_at(x, z), bare.is_water_at(x, z),
				"the settlement layer changed whether (%.1f, %.1f) is water"
				% [x, z])
			if bare.is_water_at(x, z):
				wet += 1
				# Water is never shaped: the bed under it is the water field's.
				equal(terrain.ground_height_at(x, z), bare.bed_height_at(x, z),
					"the bed under water at (%.1f, %.1f) was moved" % [x, z])
				continue
			dry += 1
			# And dry ground that was moved stays above the water line.
			check(terrain.water_surface_at(x, z) <= terrain.ground_height_at(x, z),
				"dry ground at (%.1f, %.1f) was carved below the water line"
				% [x, z])
			if absf(terrain.ground_height_at(x, z) - bare.bed_height_at(x, z)) > 0.001:
				moved += 1
	return {"dry": dry, "wet": wet, "moved": moved}
