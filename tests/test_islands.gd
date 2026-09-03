extends TestSuite
## The aerial layer: where islands are, that they are ground, and that they come
## and go without ever changing.
##
## Four separate claims live here, and they are the four the layer is for.
##
## *Placement is a fact about a position and a seed.* The same cells are asked
## from a fresh field, from a field that has already been asked hundreds of
## unrelated questions, in reversed order, through a world that has walked for a
## while, and out of a second process. Every route has to produce the same
## islands, because nothing about where an island is may depend on when anything
## was built.
##
## *Islands are ground.* The terrain query has to report a second surface over
## one, an observer put on one has to stay on it, and every island has to be
## within one hop of something below it -- which is the whole of how traversal
## reaches the aerial layer, and is a guarantee the placement rule makes rather
## than a hope.
##
## *Islands stream like chunks.* Loaded within the radius, dropped past it,
## byte-identical on return.
##
## *The void is answerable.* Off the edge of an island, at the island's own
## height, the terrain query has to say there is nothing there -- the hole the
## tactical layer will read -- and say how far the fall is.
##
## *An island handed out is not a way back in.* The copy a viewer is given may
## be written into as hard as anyone likes, including its two heightfields, and
## nothing the simulation reads may move -- while a write into the *loaded*
## island must be visible to the world's fingerprint, or the first check would
## pass for the wrong reason.
class_name TestIslands

const SEED := 11
const FAR_AWAY := 900.0

## The seeds the shape checks run over. More than one, because the shape is
## hashed per island and a claim about one world's islands is a claim about a
## few dozen shapes.
const RATIO_SEEDS := [11, 1234, 7, 4321]

## How many steps out along a ray the ratio check takes.
const RATIO_STEPS := 64

## The grid the candidate bound is checked on: this many steps each way, across
## this many world units, per seed. Wide enough to cross several cells of the
## aerial lattice in every direction.
const BOUND_STEPS := 11
const BOUND_SPAN := 700.0

## The grid the per-cell gate is checked on, per seed and per band. Denser than
## the band-level bound's grid because what it is comparing is a whole answer
## rather than a yes or no, and narrower because every position is scanned twice
## -- once with the gate and once with every cell in range built.
const GATE_STEPS := 15
const GATE_SPAN := 500.0

## The three worlds the handle-isolation checks run in, and in each the aerial
## cell whose island the cycle-34 review reshaped through the handle it was
## handed. Kept as the review left them so the numbers stay comparable -- except
## seed 99991, whose cell moved from (-4, -3) to (-4, -1) when the outline lever
## of cycle-56 pushed the blobs apart: a wider outline crowds more neighbours
## out, and (-4, -3) is one of the cells that stopped holding an island. What the
## case is checking is that a handed-out island cannot be written back into the
## world, which any island in any cell demonstrates equally.
const HANDLE_CASES := [
	{"seed": 1234, "cell": Vector2i(-4, -4)},
	{"seed": 7, "cell": Vector2i(-4, -2)},
	{"seed": 99991, "cell": Vector2i(-4, -1)},
]

## Where the screenshot in reports/islands.md is taken from, and a position on
## the upper island of the stacked pair it shows.
const STANDING_SEED := "1234"
const STANDING_X := "-345.8"
const STANDING_Z := "-288.2"


func _init() -> void:
	suite_name = "islands"


func run() -> void:
	var field := _new_field(SEED)
	var islands := _sample_islands(field, 6)
	check(islands.size() >= 8,
		"expected a decent handful of islands to test with, found %d" % islands.size())

	_placement_is_a_pure_function_of_cell_and_seed(islands)
	_placement_does_not_depend_on_the_order_cells_are_asked_in()
	_a_different_seed_puts_islands_somewhere_else(islands)
	_the_outline_answers_once_in_every_direction()
	_max_reach_bounds_the_outline()
	_an_island_is_found_from_outside_its_own_cell()
	_the_candidate_bound_never_hides_an_island()
	_the_cell_gate_never_changes_the_answer()
	_two_islands_of_one_band_never_overlap()
	_the_top_is_a_stepped_hill_standing_on_its_rim()
	_the_keel_hangs_by_different_amounts_in_different_directions()
	_islands_hang_clear_of_the_ground(islands)
	_every_island_is_within_one_hop_of_what_is_under_it(islands)
	_the_query_reports_island_ground_above_the_ground_plane(islands)
	_an_observer_placed_on_an_island_stands_on_it(islands)
	_walking_off_an_island_puts_the_observer_back_on_the_ground(islands)
	_the_void_off_an_island_is_a_hole(islands)
	_water_is_a_hole_the_same_way()
	_far_sky_islands_are_never_ground()
	_the_fingerprint_of_an_island_covers_its_heightfields()
	_a_write_into_a_loaded_island_is_visible_to_the_world_digest()
	_a_write_through_an_island_handle_cannot_reach_the_world()
	_islands_stream_and_reload_identically()
	_a_walking_world_keeps_its_islands_in_step()
	_two_processes_place_the_same_islands()


func _new_field(seed_value: int) -> IslandField:
	var surface := TerrainSurfaceField.new(seed_value)
	var biomes := BiomeField.new(seed_value)
	return IslandField.new(WaterField.new(surface, biomes), biomes)


## Every walkable island in a square of cells around the origin, in a fixed
## order. The suite works from these rather than from whatever a streamer
## happened to load, so what it is checking is the field and not the streaming.
func _sample_islands(field: IslandField, reach: int) -> Array[FloatingIsland]:
	var found: Array[FloatingIsland] = []
	for band in FloatingIsland.WALKABLE_BANDS:
		for cell_x in range(-reach, reach + 1):
			for cell_z in range(-reach, reach + 1):
				var island := field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island != null:
					found.append(island)
	return found


func _digests(islands: Array[FloatingIsland]) -> PackedStringArray:
	var out := PackedStringArray()
	for island in islands:
		out.append("%d,%d,%d:%s" % [
			island.cell.x, island.cell.y, island.band, island.digest(),
		])
	return out


func _placement_is_a_pure_function_of_cell_and_seed(
	islands: Array[FloatingIsland]
) -> void:
	var expected := _digests(islands)

	# A fresh field, asked the same cells, agrees.
	equal(_digests(_sample_islands(_new_field(SEED), 6)), expected,
		"a fresh island field placed different islands than the first one")

	# A field that has already been asked hundreds of unrelated questions --
	# other cells, other bands, positions all over the world -- still agrees.
	var busy := _new_field(SEED)
	for i in 400:
		var x := float(i * 37 % 900) - 450.0
		var z := float(i * 53 % 900) - 450.0
		busy.walkable_islands_over(x, z)
		busy.islands_near(FloatingIsland.FAR_SKY, x, z, 200.0)
	equal(_digests(_sample_islands(busy, 6)), expected,
		"islands moved once the field had been used for something else")

	# And the memo the field keeps cannot be the reason: it is smaller than the
	# number of cells this walks, so most of these were rebuilt from scratch.
	check(400 * 2 > IslandField.MEMO_LIMIT,
		"this check needs to ask for more islands than the field remembers")


func _placement_does_not_depend_on_the_order_cells_are_asked_in() -> void:
	var forwards := _new_field(SEED)
	var backwards := _new_field(SEED)
	var cells: Array[Vector2i] = []
	for cell_x in range(-5, 6):
		for cell_z in range(-5, 6):
			cells.append(Vector2i(cell_x, cell_z))

	var one := {}
	for cell in cells:
		for band in FloatingIsland.WALKABLE_BANDS:
			var island := forwards.island_in_cell(band, cell)
			one["%d,%d,%d" % [cell.x, cell.y, band]] = \
				island.digest() if island != null else "none"

	var other := {}
	cells.reverse()
	for cell in cells:
		# The bands are asked in the other order too, which matters: the upper
		# storey is built on top of the lower one, so asking for it first is the
		# case where a dependence on order could hide.
		for band in [FloatingIsland.AERIAL_UPPER, FloatingIsland.AERIAL]:
			var island := backwards.island_in_cell(band, cell)
			other["%d,%d,%d" % [cell.x, cell.y, band]] = \
				island.digest() if island != null else "none"

	equal(other, one,
		"asking for the cells in the other order produced different islands")


func _a_different_seed_puts_islands_somewhere_else(
	islands: Array[FloatingIsland]
) -> void:
	not_equal(_digests(_sample_islands(_new_field(SEED + 1), 6)), _digests(islands),
		"a different seed produced exactly the same islands")


## `ratio_at` has one answer per position, and the boundary it describes is
## crossed exactly once along any ray out of the island's middle.
##
## This is the property every caller of the shape leans on and the one the union
## of blobs could have taken away. `covers` is `ratio_at <= 1`, the mesher walks
## rings at fixed ratios, the placement rule bounds the keel by ratio, and all
## three assume that going outwards means going further out -- that the outline
## does not double back and leave a direction with two edges in it. A radius
## that is a *max* over blobs cannot double back; this checks that rather than
## trusting it, densely, over every island of several seeds.
func _the_outline_answers_once_in_every_direction() -> void:
	var checked := 0
	var worst_drop := 0.0
	var worst := ""
	for world_seed in RATIO_SEEDS:
		for island in _sample_islands(_new_field(world_seed), 3):
			checked += 1
			for direction in 48:
				var angle := TAU * float(direction) / 48.0
				var reach := island.outline_radius(angle)
				check(reach > 0.0,
					"the outline reaches nowhere at angle %.3f of island %v"
					% [angle, island.key()])
				# Along this ray, the ratio has to rise the whole way out. If the
				# boundary doubled back anywhere it would fall somewhere.
				var previous := -1.0
				var crossings := 0
				var inside := true
				for step in RATIO_STEPS + 1:
					var out := island.max_reach() * 1.4 * float(step) / float(RATIO_STEPS)
					var x := island.centre_x + cos(angle) * out
					var z := island.centre_z + sin(angle) * out
					var ratio := island.ratio_at(x, z)
					if ratio < previous:
						var drop := previous - ratio
						if drop > worst_drop:
							worst_drop = drop
							worst = "island %v at angle %.3f" % [island.key(), angle]
					previous = ratio
					var now_inside := island.covers(x, z)
					if now_inside != inside:
						crossings += 1
						inside = now_inside
				equal(crossings, 1,
					"a ray out of island %v at angle %.3f crossed its outline %d times"
					% [island.key(), angle, crossings])
	check(checked >= 60,
		"only %d islands were sampled for the ratio check" % checked)
	check(worst_drop <= 0.0,
		"ratio_at fell going outwards by %f: %s" % [worst_drop, worst])


## `max_reach()` really is the furthest the outline goes, and the field's static
## bound really is the furthest any island of a band goes.
##
## Both matter for the same reason: the cell scan and the streamer decide which
## cells to look at from these numbers alone. If either understated the outline
## an island would be missed by a scan that started far enough away, and would
## pop into existence as the observer walked closer.
func _max_reach_bounds_the_outline() -> void:
	var checked := 0
	for world_seed in RATIO_SEEDS:
		var field := _new_field(world_seed)
		var islands: Array[FloatingIsland] = _sample_islands(field, 3)
		for cell_x in range(-3, 4):
			for cell_z in range(-3, 4):
				var far := field.island_in_cell(
					FloatingIsland.FAR_SKY, Vector2i(cell_x, cell_z)
				)
				if far != null:
					islands.append(far)
		for island in islands:
			checked += 1
			var reach := island.max_reach()
			for direction in 180:
				var angle := TAU * float(direction) / 180.0
				check(island.outline_radius(angle) <= reach + 0.0001,
					"island %v reaches %f at angle %.3f, past its own bound of %f"
					% [island.key(), island.outline_radius(angle), angle, reach])
			check(reach <= island.radius * IslandField.OUTLINE_REACH_MAX + 0.0001,
				"island %v reaches %f, past the band's bound of %f"
				% [island.key(), reach, island.radius * IslandField.OUTLINE_REACH_MAX])
			check(reach <= IslandField.band_reach(island.band) + 0.0001,
				"island %v reaches %f, past band_reach of %f"
				% [island.key(), reach, IslandField.band_reach(island.band)])
	check(checked >= 80, "only %d islands were checked for reach" % checked)


## An island is found from a long way outside its own cell, and it is the same
## island that is found from inside it.
##
## The cell scan is what decides whether an island exists as far as any caller is
## concerned, and it is written in terms of `band_reach`. Growing the radius is
## exactly the change that could leave that number too small, and the symptom
## would be an island that is there when you stand on it and gone when you look
## at it from the next hill -- so the scan is asked from every direction, out
## past the reach of a whole cell.
func _an_island_is_found_from_outside_its_own_cell() -> void:
	var field := _new_field(SEED)
	var checked := 0
	for island in _sample_islands(field, 5):
		checked += 1
		var here := field.walkable_islands_over(island.centre_x, island.centre_z)
		var found_inside := false
		for other in here:
			if other.key() == island.key():
				found_inside = true
		check(found_inside,
			"island %v is not found by a query at its own middle" % island.key())

		for direction in 16:
			var angle := TAU * float(direction) / 16.0
			var away := IslandField.cell_size(island.band) * 2.5
			var x := island.centre_x + cos(angle) * away
			var z := island.centre_z + sin(angle) * away
			var seen: FloatingIsland = null
			for other in field.islands_near(island.band, x, z, away + island.max_reach()):
				if other.key() == island.key():
					seen = other
			check(seen != null,
				"island %v is invisible to a scan from %f units away at angle %.3f"
				% [island.key(), away, angle])
			if seen != null:
				equal(seen.digest(), island.digest(),
					"island %v came back different when scanned from outside its cell"
					% island.key())
	check(checked >= 20, "only %d islands were checked for the cell scan" % checked)


## `could_reach` never says no where there is an island.
##
## The bound is the cheap half of the sparse layer's bargain: it walks the same
## cells the real scan would but asks each one only for its hashed candidate, so
## it builds nothing and reads no ground. Callers are allowed to skip the real
## scan entirely where it says no -- the settlement layer's overhead veto does
## exactly that -- so a single false "no" would be an island that hangs over a
## village without the village ever hearing about it.
##
## It is checked the only way a bound can be: on a grid of positions across
## several seeds and both walkable bands, the real scan is run as well and the
## two are required to agree in the one direction that matters. The reverse
## direction is not an error and is counted rather than checked -- a "maybe" over
## ground that refuses to hang an island is the bound doing its job.
func _the_candidate_bound_never_hides_an_island() -> void:
	var distance := SettlementField.PAD_RADIUS_MAX
	var asked := 0
	var ruled_out := 0
	var really_there := 0
	for world_seed in RATIO_SEEDS:
		var field := _new_field(world_seed)
		for step_x in BOUND_STEPS:
			for step_z in BOUND_STEPS:
				var x := (float(step_x) / float(BOUND_STEPS - 1) - 0.5) * BOUND_SPAN
				var z := (float(step_z) / float(BOUND_STEPS - 1) - 0.5) * BOUND_SPAN
				for band: int in FloatingIsland.WALKABLE_BANDS:
					var bound := field.could_reach(band, x, z, distance)
					var near := field.islands_near(band, x, z, distance)
					asked += 1
					if not bound:
						ruled_out += 1
					if not near.is_empty():
						really_there += 1
					check(bound or near.is_empty(),
						("could_reach says nothing of band %d is within %.1f of "
						+ "(%.1f, %.1f) on seed %d, but the scan found %d")
						% [band, distance, x, z, world_seed, near.size()])
	check(really_there >= 10,
		"only %d of %d asks had an island to hide, too few to be checking anything"
		% [really_there, asked])
	check(ruled_out * 2 >= asked,
		"the bound ruled out only %d of %d asks, so it is not buying much"
		% [ruled_out, asked])
	print("        islands: candidate bound ruled out %d of %d asks, %d had an island"
		% [ruled_out, asked, really_there])


## The same bound, asked once per cell inside the shared scan, hands back the
## same islands as a scan that builds every cell in range.
##
## This is the claim the whole saving rests on, and it is a claim about equality
## rather than about cost: `IslandField._cells_around` now refuses to build a
## cell whose candidate cannot come within the distance asked for, and every
## island query in the game goes through that scan -- the streamer's loaded set,
## the terrain query's "what am I standing on", the mesher's per-position
## cover. So the two answers are compared island for island, digest for digest,
## over a wide grid of positions in four worlds, in all three bands, and at the
## distances the real callers use: zero (which is what `islands_over` asks, and
## through it the terrain query), the streamer's load radius, and a village
## pad's radius.
##
## Two guards keep it honest. A gate that ruled nothing out would pass the
## equality trivially, so the gated field is also required to build far fewer
## cells than the ungated one; and there have to be islands in the sweep at all,
## or equality is only two empty lists agreeing.
func _the_cell_gate_never_changes_the_answer() -> void:
	var compared := 0
	var with_island := 0
	var gated_builds := 0
	var ungated_builds := 0
	for world_seed in RATIO_SEEDS:
		for band: int in [
			FloatingIsland.AERIAL, FloatingIsland.AERIAL_UPPER, FloatingIsland.FAR_SKY,
		]:
			var distances: Array[float] = [
				0.0,
				IslandStreamer.load_radius(band),
				SettlementField.PAD_RADIUS_MAX,
			]
			# Two fields of the same world, alike but for the gate. Fresh ones
			# per band, so neither is answering out of a memo the other filled
			# and the build counts are the counts of that band's own scans.
			var gated := _new_field(world_seed)
			var ungated := _new_field(world_seed)
			ungated.gate_cells_by_candidate = false
			for step_x in GATE_STEPS:
				for step_z in GATE_STEPS:
					var x := (float(step_x) / float(GATE_STEPS - 1) - 0.5) * GATE_SPAN
					var z := (float(step_z) / float(GATE_STEPS - 1) - 0.5) * GATE_SPAN
					var over := _digests(gated.islands_over(band, x, z))
					compared += 1
					if not over.is_empty():
						with_island += 1
					check(over == _digests(ungated.islands_over(band, x, z)),
						("the cell gate changed what covers (%.1f, %.1f) of band %d "
						+ "on seed %d: gated %s, ungated %s")
						% [x, z, band, world_seed, over,
							_digests(ungated.islands_over(band, x, z))])
					for distance in distances:
						var near := _digests(gated.islands_near(band, x, z, distance))
						compared += 1
						if not near.is_empty():
							with_island += 1
						check(near == _digests(
								ungated.islands_near(band, x, z, distance)),
							("the cell gate changed what is within %.1f of "
							+ "(%.1f, %.1f) of band %d on seed %d: gated %s, "
							+ "ungated %s")
							% [distance, x, z, band, world_seed, near,
								_digests(ungated.islands_near(
									band, x, z, distance))])
			gated_builds += gated.builds
			ungated_builds += ungated.builds
	check(with_island >= 100,
		"only %d of %d asks found an island, too few for equality to mean much"
		% [with_island, compared])
	check(gated_builds * 4 <= ungated_builds,
		("the gated scan built %d cells against the ungated %d, which is not the "
		+ "saving the gate is for") % [gated_builds, ungated_builds])
	print(("        islands: cell gate matched the ungated scan on %d asks, %d with "
		+ "an island, building %d cells against %d")
		% [compared, with_island, gated_builds, ungated_builds])


## No two islands of the same band overlap.
##
## Two plates through each other would leave a stretch of world where "what am I
## standing on" has two answers at once, neither of which is the surface anyone
## can see. At the old radius the lattice made this impossible by arithmetic --
## two cells are at least 38.7 units apart and no island reached half of that.
## At the new radius it is a rule instead, so it is checked.
func _two_islands_of_one_band_never_overlap() -> void:
	for world_seed in RATIO_SEEDS:
		var field := _new_field(world_seed)
		for band in FloatingIsland.WALKABLE_BANDS:
			var islands: Array[FloatingIsland] = []
			for cell_x in range(-4, 5):
				for cell_z in range(-4, 5):
					var island := field.island_in_cell(band, Vector2i(cell_x, cell_z))
					if island != null:
						islands.append(island)
			for first in islands.size():
				for second in range(first + 1, islands.size()):
					var one := islands[first]
					var other := islands[second]
					var apart := Vector2(
						one.centre_x - other.centre_x, one.centre_z - other.centre_z
					).length()
					check(apart >= one.max_reach() + other.max_reach(),
						"islands %v and %v of band %d are %f apart but reach %f and %f"
						% [one.key(), other.key(), band, apart,
							one.max_reach(), other.max_reach()])


## The top of an island is a hill with terraces round its edge, standing on the
## rim: never below it, exactly on it at the outline, and well above it inside.
##
## Three separate claims, and each is load-bearing. That the rim is the floor is
## what makes "this island is this far above the ground" one number rather than a
## range, and is what the whole reachability rule is stated in. That the relief
## is a real share of the radius is what stops the top reading as a lid. That the
## outer band climbs in steps is what makes the edge read as broken ground; every
## step also has to be small enough to walk up, or the middle of an island would
## be unreachable from its own rim.
func _the_top_is_a_stepped_hill_standing_on_its_rim() -> void:
	var lifted := 0
	var checked := 0
	for island in _sample_islands(_new_field(SEED), 4):
		checked += 1
		check(island.relief >= island.radius * IslandField.AERIAL_RELIEF_SHARE_MIN - 0.0001,
			"island %v has relief %f against a radius of %f"
			% [island.key(), island.relief, island.radius])

		for direction in 24:
			var angle := TAU * float(direction) / 24.0
			var reach := island.outline_radius(angle)
			var edge_x := island.centre_x + cos(angle) * reach
			var edge_z := island.centre_z + sin(angle) * reach
			check(absf(island.top_height_at(edge_x, edge_z) - island.rim_height) < 0.0001,
				"island %v is %f off its own rim height at the outline"
				% [island.key(), island.top_height_at(edge_x, edge_z) - island.rim_height])
			var previous := island.rim_height
			for step in 40:
				var out := reach * (1.0 - float(step) / 40.0)
				var x := island.centre_x + cos(angle) * out
				var z := island.centre_z + sin(angle) * out
				# The hill the island would be with no basin cut out of it. The
				# basin is allowed to take the *middle* under the rim -- that is
				# what lets it hold water -- but nothing else may, and the
				# boundary check above is what pins that down.
				var top := island.base_top_height_at(x, z)
				check(top >= island.rim_height - 0.0001,
					"island %v dips %f below its own rim"
					% [island.key(), island.rim_height - top])
				check(top - previous < TerrainQuery.HOP_HEIGHT,
					"island %v climbs %f in one step of its own terraces"
					% [island.key(), top - previous])
				previous = top
		if island.base_top_height_at(island.centre_x, island.centre_z) \
				> island.rim_height + island.relief * 0.25:
			lifted += 1
	check(checked >= 20, "only %d islands were checked for relief" % checked)
	check(float(lifted) / float(checked) > 0.5,
		"only %d of %d islands stand a quarter of their relief above their own rim"
		% [lifted, checked])

	# The terrace profile itself: flat at the outline, a full share at the
	# middle, and rising in the steps the mesher puts rings at.
	var island := _sample_islands(_new_field(SEED), 2)[0]
	equal(island.terrace_at(1.0), 0.0, "the terrace profile is not zero at the outline")
	equal(island.terrace_at(0.0), 1.0, "the terrace profile is not one at the middle")
	var treads := {}
	for step in 200:
		var ratio := 1.0 - float(step) / 200.0 * FloatingIsland.SHELF_BAND
		treads[snappedf(island.terrace_at(ratio), 0.001)] = true
	check(treads.size() >= FloatingIsland.SHELF_COUNT + 1,
		"the rim band holds only %d distinct heights, so it is not stepped"
		% treads.size())


## The keel hangs by different amounts in different directions, and never below
## the depth the placement rule allowed it.
func _the_keel_hangs_by_different_amounts_in_different_directions() -> void:
	var uneven := 0
	var checked := 0
	for island in _sample_islands(_new_field(SEED), 4):
		checked += 1
		var shallowest := INF
		var deepest := 0.0
		for direction in 32:
			var angle := TAU * float(direction) / 32.0
			var reach := island.outline_radius(angle)
			var edge_x := island.centre_x + cos(angle) * reach
			var edge_z := island.centre_z + sin(angle) * reach
			check(absf(island.bottom_height_at(edge_x, edge_z)
					- (island.rim_height - island.rim_thickness)) < 0.0001,
				"island %v does not meet its own rim lip at the outline" % island.key())
			# A little way in from the rim, where the spurs have started to hang.
			var x := island.centre_x + cos(angle) * reach * 0.3
			var z := island.centre_z + sin(angle) * reach * 0.3
			var hang := island.rim_height - island.rim_thickness \
				- island.bottom_height_at(x, z)
			shallowest = minf(shallowest, hang)
			deepest = maxf(deepest, hang)
		check(deepest <= island.keel_depth + 0.0001,
			"island %v hangs %f below a keel of %f" % [island.key(), deepest, island.keel_depth])
		if shallowest < deepest * 0.75:
			uneven += 1
	check(checked >= 20, "only %d islands were checked for keel spurs" % checked)
	check(float(uneven) / float(checked) > 0.7,
		"only %d of %d islands have a keel that varies by more than a quarter "
		% [uneven, checked] + "between directions")


## Every island's underside stays above whatever is under it. This is the
## placement rule stated back as arithmetic, and it is checked on a dense grid
## the field itself never sampled, so it is not merely repeating the field's own
## working.
func _islands_hang_clear_of_the_ground(islands: Array[FloatingIsland]) -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var worst := INF
	var worst_island := ""
	for island in islands:
		for grid_x in range(-11, 12):
			for grid_z in range(-11, 12):
				var x := island.centre_x + float(grid_x) / 11.0 * island.max_reach()
				var z := island.centre_z + float(grid_z) / 11.0 * island.max_reach()
				if not island.covers(x, z):
					continue
				var gap := island.bottom_height_at(x, z) \
					- _support_under(terrain, island, x, z)
				if gap < worst:
					worst = gap
					worst_island = "%d,%d band %d" % [island.cell.x, island.cell.y, island.band]
	check(worst > 0.0,
		"an island's underside reaches below what is beneath it: %s, by %f"
		% [worst_island, -worst])


## Every island can be walked onto: somewhere along its rim there is a surface
## below it within one hop.
##
## This is the traversal decision, checked rather than asserted. It is what
## makes the aerial layer routine -- no jump check, no bridge, no lift -- and it
## holds because of where islands are placed, not because anything was added to
## movement.
func _every_island_is_within_one_hop_of_what_is_under_it(
	islands: Array[FloatingIsland]
) -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var unreachable := 0
	var worst := 0.0
	for island in islands:
		var best_gap := INF
		for direction in 64:
			var angle := TAU * float(direction) / 64.0
			# On the rim itself, which is where the island's own surface is at its
			# lowest and the only place anyone can arrive at it.
			var reach := island.outline_radius(angle)
			var x := island.centre_x + cos(angle) * reach
			var z := island.centre_z + sin(angle) * reach
			best_gap = minf(
				best_gap,
				island.top_height_at(x, z) - _support_under(terrain, island, x, z),
			)
		if best_gap > TerrainQuery.HOP_HEIGHT:
			unreachable += 1
			worst = maxf(worst, best_gap)
	equal(unreachable, 0,
		"%d island(s) have no point on their rim within one hop (%.2f) of "
		% [unreachable, TerrainQuery.HOP_HEIGHT]
		+ "anything below; the worst needed %.2f" % worst)


## The highest walkable surface below an island at a position: the ground, or a
## lower island where there is one under this one.
func _support_under(
	terrain: TerrainQuery, island: FloatingIsland, x: float, z: float
) -> float:
	var best := terrain.ground_height_at(x, z)
	for other in terrain.islands_at(x, z):
		if other.band >= island.band:
			continue
		best = maxf(best, other.top_height_at(x, z))
	return best


func _the_query_reports_island_ground_above_the_ground_plane(
	islands: Array[FloatingIsland]
) -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var island := islands[0]
	var dry := _dry_middle(island)
	var x := dry.x
	var z := dry.y

	var surfaces := terrain.surfaces_at(x, z)
	check(surfaces.size() >= 1,
		"the middle of an island reported no walkable surface at all")
	check(terrain.is_over_island_at(x, z),
		"the terrain query does not think there is an island over its own middle")
	check(terrain.island_height_at(x, z) > terrain.ground_height_at(x, z),
		"the island's ground (%f) is not above the ground plane (%f)"
		% [terrain.island_height_at(x, z), terrain.ground_height_at(x, z)])
	equal(terrain.surface_height_at(x, z), terrain.island_height_at(x, z),
		"the topmost surface over an island should be the island")

	# The surfaces come back lowest first, which is what lets support_at() pick
	# by looking for the highest one at or below where you are.
	for at in range(1, surfaces.size()):
		check(surfaces[at] > surfaces[at - 1],
			"surfaces_at() came back out of order: %f then %f"
			% [surfaces[at - 1], surfaces[at]])

	# Everything the composed answer says, said again the long way round.
	var ground := terrain.ground_at(x, z)
	equal(ground["island"], true, "ground_at() did not report the island")
	equal(ground["surface_height"], terrain.island_height_at(x, z),
		"ground_at() disagreed with island_height_at() about the surface")
	check(float(ground["void_below_island"]) > 0.0,
		"ground_at() reported no void under an island")


func _an_observer_placed_on_an_island_stands_on_it(
	islands: Array[FloatingIsland]
) -> void:
	var island := _widest_dry(islands)
	var world := SimWorld.new(SEED)
	world.place_observer(island.centre_x, island.centre_z)

	check(world.observer_on_island(),
		"an observer put on an island is not standing on it")
	var top := island.top_height_at(island.centre_x, island.centre_z)
	equal(snappedf(world.observer_surface_height(), 0.0001), snappedf(top, 0.0001),
		"the observer is not at the island's surface height")
	check(world.observer_surface_height() > world.observer_ground_height() + 1.0,
		"the observer on an island is not above the ground plane: %f vs %f"
		% [world.observer_surface_height(), world.observer_ground_height()])

	# And it stays there. Walking for a while inside the island must not drop it
	# through the surface, which is what "walkable" means when there is nothing
	# under your feet but a lookup.
	var stayed := 0
	var steps := 0
	for i in 12:
		world.step()
		steps += 1
		if island.covers(world.observer_x, world.observer_z):
			stayed += 1
			check(world.observer_on_island(),
				"the observer fell through the island at (%f, %f)"
				% [world.observer_x, world.observer_z])
	check(stayed > 0,
		"the observer left the island immediately, so nothing was really checked")


func _walking_off_an_island_puts_the_observer_back_on_the_ground(
	islands: Array[FloatingIsland]
) -> void:
	var island := _widest_dry(islands)
	var world := SimWorld.new(SEED)
	# The thing that walks off an island is a character: the observer is the
	# world's view on one, and the one-hop settle that carries a walker up onto a
	# rim and drops it back off is `Combatant.settle`. So the character the world
	# looks through is stood on the island, and the view follows it there.
	var walker := world.followed()
	check(walker != null, "the world should be looking through somebody")
	if walker == null:
		return
	walker.x = island.centre_x
	walker.z = island.centre_z
	walker.y = island.top_height_at(island.centre_x, island.centre_z)
	world.follow(walker.id)
	check(world.observer_on_island(), "the observer should start on the island")

	# Step off the edge by hand, well past the outline, and let the world's own
	# settle rule say where that lands.
	walker.x = island.centre_x + island.max_reach() * 2.5
	walker.z = island.centre_z
	walker.settle(world.terrain)
	world.follow(walker.id)
	check(not world.observer_on_island(),
		"the observer is still on an island after stepping off the edge")
	check(absf(world.observer_surface_height() - world.observer_ground_height()) < 0.5,
		"the observer did not come down to the ground after leaving the island: "
		+ "%f against ground %f"
		% [world.observer_surface_height(), world.observer_ground_height()])


## The void beneath an island, asked for from the island.
##
## This is the answer the tactical layer will read as a hole in its board: a cell
## just past the rim, at the height the fight is happening at, with nothing under
## it within reach. The same question asked on the island itself has to say the
## opposite, or the answer would mean nothing.
func _the_void_off_an_island_is_a_hole(islands: Array[FloatingIsland]) -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var island := _widest_dry(islands)
	var dry := _dry_middle(island)
	var on_x := dry.x
	var on_z := dry.y
	var height := island.top_height_at(on_x, on_z)

	check(not terrain.is_void_at(on_x, on_z, height),
		"the middle of an island is being reported as a hole")
	check(terrain.drop_from(on_x, on_z, height) < 0.0001,
		"standing on an island is reported as a drop of %f"
		% terrain.drop_from(on_x, on_z, height))

	var holes := 0
	var falls := 0
	for direction in 32:
		var angle := TAU * float(direction) / 32.0
		var reach := island.outline_radius(angle) + 3.0
		var x := island.centre_x + cos(angle) * reach
		var z := island.centre_z + sin(angle) * reach
		if terrain.is_over_island_at(x, z):
			continue  # a neighbouring island happens to reach here
		if terrain.is_void_at(x, z, height):
			holes += 1
			if terrain.drop_from(x, z, height) > TerrainQuery.HOP_HEIGHT:
				falls += 1
	check(holes > 16,
		"only %d of 32 directions off the island's rim are a hole at island height"
		% holes)
	equal(falls, holes,
		"a hole off the island's rim reported nothing to fall to")


## Water answers through the very same question, which is the point of putting
## it there: the overworld and the board cannot drift apart about where the world
## is solid.
func _water_is_a_hole_the_same_way() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var found := 0
	for step_x in range(-40, 41):
		for step_z in range(-40, 41):
			var x := float(step_x) * 4.0
			var z := float(step_z) * 4.0
			if not terrain.is_water_at(x, z):
				continue
			found += 1
			if found > 40:
				break
			check(terrain.is_void_at(x, z, terrain.ground_height_at(x, z)),
				"water at (%f, %f) is not a hole" % [x, z])
			check(not terrain.is_passable_at(x, z),
				"water at (%f, %f) is passable" % [x, z])
	check(found > 0, "found no water at all to check, so nothing was checked")


func _far_sky_islands_are_never_ground() -> void:
	var field := _new_field(SEED)
	var terrain := TerrainQuery.for_seed(SEED)
	var checked := 0
	for cell_x in range(-3, 4):
		for cell_z in range(-3, 4):
			var island := field.island_in_cell(FloatingIsland.FAR_SKY, Vector2i(cell_x, cell_z))
			if island == null:
				continue
			checked += 1
			check(not island.walkable, "a far-sky island claims to be walkable")
			check(island.drift_radius > 0.0, "a far-sky island does not drift")
			check(island.rim_height >= IslandField.FAR_ALTITUDE_MIN,
				"a far-sky island is below its own altitude band")
			var x := island.centre_x
			var z := island.centre_z
			check(not terrain.is_over_island_at(x, z) \
					or terrain.island_height_at(x, z) < island.rim_height,
				"the terrain query treats a far-sky island as ground")
			for surface in terrain.surfaces_at(x, z):
				check(absf(surface - island.top_height_at(x, z)) > 0.001,
					"a far-sky island turned up in the list of walkable surfaces")
	check(checked > 2, "found only %d far-sky islands to check" % checked)


## Two islands whose heightfields are tuned differently are different islands,
## and their fingerprints have to say so.
##
## The relief on top of an island is as much its shape as its outline is -- it
## is what decides the height a character stands on anywhere but the very rim.
## A fingerprint that folded in the outline and not the fields would call an
## island and a retuned copy of it the same island, so nothing that compares
## fingerprints could notice a field being retuned.
func _the_fingerprint_of_an_island_covers_its_heightfields() -> void:
	var field := _new_field(SEED)
	var island := _widest(_sample_islands(field, 6))
	var same := island.detached_copy()
	equal(same.digest(), island.digest(),
		"a copy of an island, untouched, does not fingerprint as that island")

	# One parameter at a time, so a pass cannot come from folding in only one of
	# the six numbers or only one of the two fields.
	for retune in [
		"relief.amplitude", "relief.period", "relief.octaves",
		"relief.lacunarity", "relief.gain", "relief.seed",
		"detail.amplitude", "detail.period",
	]:
		var edited := island.detached_copy()
		var noise: ValueNoise = edited._relief_noise if retune.begins_with("relief") \
			else edited._detail_noise
		match retune.split(".")[1]:
			"amplitude": noise.amplitude *= 4.0
			"period": noise.period *= 0.25
			"octaves": noise.octaves += 1
			"lacunarity": noise.lacunarity += 0.5
			"gain": noise.gain *= 0.5
			"seed": noise.field_seed += 1
		not_equal(edited.digest(), island.digest(),
			"an island whose heightfield %s was retuned fingerprints the same as "
			% retune + "the island it came from: digest() does not cover the fields")


## The world's fingerprint has to cover the islands the world is holding.
##
## live_island() is the simulation's own way in to a loaded island -- the way the
## world's own fingerprint reads it. Retuning its heightfield is a real change to
## the world: it moves the ground on top of the island. The fingerprint has to
## say so, or the isolation check below would pass for the wrong reason.
func _a_write_into_a_loaded_island_is_visible_to_the_world_digest() -> void:
	var case: Dictionary = HANDLE_CASES[0]
	var world := SimWorld.new(int(case["seed"]))
	var placed := world.island_field.island_in_cell(FloatingIsland.AERIAL, case["cell"])
	check(placed != null, "seed %d has no aerial island in cell %v"
		% [int(case["seed"]), case["cell"]])
	if placed == null:
		return
	world.place_observer(placed.centre_x, placed.centre_z)
	var live := world.island_streamer.live_island(placed.key())
	check(live != null, "the island under the observer is not loaded")
	if live == null:
		return

	var before := world.digest()
	var was: float = live._relief_noise.amplitude
	live._relief_noise.amplitude *= 4.0
	not_equal(world.digest(), before,
		"retuning the heightfield of a loaded island left the world digest "
		+ "unchanged: the simulation cannot detect its islands being reshaped")

	live._relief_noise.amplitude = was
	equal(world.digest(), before,
		"undoing the write did not restore the world digest")


## The island a viewer is handed is not a way in.
##
## island() is the accessor the render layer reads an island's drift and tints
## through. The exact write the check above proved is detectable is made here
## through that accessor instead -- into the two heightfields, which an earlier
## version of detached_copy() shared on the false ground that a ValueNoise is
## immutable -- and this time nothing about the world may move: not the height a
## character stands on, not the island's own fingerprint, not the world's.
func _a_write_through_an_island_handle_cannot_reach_the_world() -> void:
	for case in HANDLE_CASES:
		_one_island_handle_is_detached(int(case["seed"]), case["cell"])


func _one_island_handle_is_detached(seed_value: int, cell: Vector2i) -> void:
	var world := SimWorld.new(seed_value)
	var placed := world.island_field.island_in_cell(FloatingIsland.AERIAL, cell)
	check(placed != null, "seed %d has no aerial island in cell %v" % [seed_value, cell])
	if placed == null:
		return
	world.place_observer(placed.centre_x, placed.centre_z)
	var key := placed.key()
	var live := world.island_streamer.live_island(key)
	check(live != null, "seed %d: island %v is not loaded" % [seed_value, key])
	if live == null:
		return

	# A position on the island's top, off its middle: what a character standing
	# there is standing on.
	var probe_x := placed.centre_x + 0.3 * placed.radius
	var probe_z := placed.centre_z + 0.15 * placed.radius
	var height_before := world.terrain.surface_height_at(probe_x, probe_z)
	var island_before := live.digest()
	var world_before := world.digest()

	var handle := world.island_streamer.island(key)
	check(handle != null, "seed %d: island_streamer.island(%v) handed back nothing"
		% [seed_value, key])
	if handle == null:
		return

	# It is the same island: what a viewer draws has to be what the world holds,
	# or isolation would have been bought by handing over something else.
	equal(handle.digest(), island_before,
		"seed %d: the island handed to a viewer is not island %v" % [seed_value, key])
	check(handle != live,
		"seed %d: island_streamer.island(%v) handed back the loaded island itself"
		% [seed_value, key])
	check(handle._relief_noise != live._relief_noise,
		"seed %d: the handed-out island shares the loaded island's relief field"
		% seed_value)
	check(handle._detail_noise != live._detail_noise,
		"seed %d: the handed-out island shares the loaded island's detail field"
		% seed_value)

	# The write the review made, into both fields this time.
	handle._relief_noise.amplitude *= 4.0
	handle._relief_noise.period *= 0.25
	handle._detail_noise.amplitude *= 4.0
	handle.rim_height += 5.0

	equal(world.terrain.surface_height_at(probe_x, probe_z), height_before,
		"seed %d: a write through island_streamer.island(%v) moved the surface at "
		% [seed_value, key] + "(%.4f, %.4f): the height a character stands on changed"
		% [probe_x, probe_z])
	equal(live.digest(), island_before,
		"seed %d: the loaded island %v changed when a viewer wrote into its copy"
		% [seed_value, key])
	equal(world.digest(), world_before,
		"seed %d: a write through island_streamer.island(%v) changed the world: "
		% [seed_value, key] + "the render layer can reshape the world it is drawing")

	# The writes did land -- on the copy. Without this, the checks above would
	# pass for a handle that ignored writes, or for one with no fields at all.
	not_equal(handle._relief_noise.amplitude, live._relief_noise.amplitude,
		"seed %d: writing into the handed-over relief field changed nothing at "
		% seed_value + "all, so the check that the world stayed put proves nothing")
	not_equal(handle._detail_noise.period + handle._detail_noise.amplitude,
		live._detail_noise.period + live._detail_noise.amplitude,
		"seed %d: writing into the handed-over detail field changed nothing at all"
		% seed_value)
	not_equal(handle.digest(), island_before,
		"seed %d: the retuned handle fingerprints as the island it came from"
		% seed_value)


func _islands_stream_and_reload_identically() -> void:
	var field := _new_field(SEED)
	var streamer := IslandStreamer.new(field, IslandMesher.new())
	var island := _widest(_sample_islands(field, 6))
	var home := Vector2(island.centre_x, island.centre_z)

	streamer.update([home])
	var key := island.key()
	check(streamer.is_loaded(key),
		"the island the observer is standing on is not loaded")
	_check_invariants(streamer, field, home)

	var before := streamer.geometry(key)
	check(before != null and before.triangle_count() > 0,
		"the loaded island has no geometry")
	var before_digest := before.digest()
	var before_vertices := before.vertices.duplicate()
	var built_before := streamer.islands_built

	# Walk away far enough that it is dropped, then walk back.
	for i in 60:
		streamer.update([home + Vector2(1.0, 0.0) * (float(i + 1) * 20.0)])
	check(not streamer.is_loaded(key),
		"the island should have unloaded once the observer walked away")
	check(streamer.loaded_count() < streamer.islands_built,
		"the walk never dropped any islands")

	for i in 60:
		streamer.update([home + Vector2(1.0, 0.0) * (1200.0 - float(i + 1) * 20.0)])
	streamer.update([home])
	check(streamer.is_loaded(key), "the island did not come back on returning")
	check(streamer.islands_built > built_before,
		"the return trip built no islands, so nothing was really reloaded")

	var after := streamer.geometry(key)
	equal(after.digest(), before_digest,
		"the island came back different after being unloaded and reloaded")
	equal(after.vertices, before_vertices,
		"the island came back with different vertices after a reload")

	# With nobody anywhere, nothing stays loaded.
	var nobody: Array[Vector2] = []
	streamer.update(nobody)
	equal(streamer.loaded_count(), 0,
		"islands stayed loaded with no observer in the world")


## Everything within the load radius of the observer is built; nothing beyond the
## unload radius is still there. The rule the ground streamer follows, checked
## the same way, against the field rather than against the streamer.
func _check_invariants(
	streamer: IslandStreamer, field: IslandField, at: Vector2
) -> void:
	for key in streamer.loaded_keys():
		var island := streamer.live_island(key)
		check(IslandField.distance_to(island, at.x, at.y)
				<= IslandStreamer.unload_radius(island.band),
			"island %v is past the unload radius of the observer at %v" % [key, at])

	for band in [
		FloatingIsland.AERIAL, FloatingIsland.AERIAL_UPPER, FloatingIsland.FAR_SKY,
	]:
		for island in field.islands_near(band, at.x, at.y, IslandStreamer.load_radius(band)):
			check(streamer.is_loaded(island.key()),
				"island %v is within the load radius of %v but is not loaded"
				% [island.key(), at])


func _a_walking_world_keeps_its_islands_in_step() -> void:
	var world := SimWorld.new(SEED)
	check(world.island_streamer.loaded_count() > 0,
		"a fresh world loaded no islands at all around its observer")
	for i in 150:
		world.step()
		if i % 30 == 0:
			_check_invariants(
				world.island_streamer,
				world.island_field,
				Vector2(world.observer_x, world.observer_z),
			)
	check(world.island_streamer.islands_built > world.island_streamer.loaded_count(),
		"the walk never dropped an island: built %d, still loaded %d"
		% [world.island_streamer.islands_built, world.island_streamer.loaded_count()])

	# The world it walked to is the world a second run of the same seed walks to,
	# islands included -- the digest folds them in.
	var twin := SimWorld.new(SEED)
	for i in 150:
		twin.step()
	equal(twin.digest(), world.digest(),
		"two identical walks reached different worlds")


## The island map itself, out of two separate processes.
##
## Every other check here runs in one process, where a shared field, a shared
## catalog or a stale bit of state could make two answers agree for the wrong
## reason. This runs the documented headless command twice as a real subprocess
## and compares what each printed: the placement of every island in a fixed
## square of the world, measured against the ground under it. Two runs of a seed
## must agree exactly, and two seeds must not.
##
## The third run puts an observer on a known island and checks that the world it
## reports is one where the observer is standing on an island -- the same claim
## the in-process check makes, made again in a process that was told nothing
## except a position.
func _two_processes_place_the_same_islands() -> void:
	var same_a := _run_headless(["--seed", "1234", "--ticks", "0", "--islands"])
	var same_b := _run_headless(["--seed", "1234", "--ticks", "0", "--islands"])
	var different := _run_headless(["--seed", "4321", "--ticks", "0", "--islands"])

	equal(same_a["exit_code"], 0,
		"the island report should exit 0 (stdout: %s)" % same_a["output"])
	check(same_a["output"].contains("island-summary"),
		"the island report printed no summary line")
	check(same_a["output"].split("\n").size() > 40,
		"the island report found almost nothing to report")
	equal(same_a["output"], same_b["output"],
		"two processes reported different islands for the same seed")
	not_equal(different["output"], same_a["output"],
		"two seeds reported the same islands")

	# The island the screenshot in reports/islands.md is taken on, asked for by
	# position in a process that knows nothing else about it.
	var standing := _run_headless([
		"--seed", STANDING_SEED, "--ticks", "4",
		"--start", STANDING_X, STANDING_Z,
	])
	equal(standing["exit_code"], 0, "the placed run should exit 0")
	check(standing["output"].contains("on_island=1"),
		"an observer placed on an island did not report standing on one:\n%s"
		% standing["output"])


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


## Somewhere on an island that its own pond does not cover: its middle, unless
## a basin has been cut there, in which case a point out on its shoulder.
##
## The tests below that stand on an island have to stand on the *ground* of it,
## and the middle of an island with a basin is now water -- which is a hole, and
## deliberately so. Choosing a dry spot is what keeps those tests about what
## they were about.
func _dry_middle(island: FloatingIsland) -> Vector2:
	if not island.holds_water_at(island.centre_x, island.centre_z):
		return Vector2(island.centre_x, island.centre_z)
	for step in 24:
		var angle := TAU * float(step) / 24.0
		var away := island.outline_radius(angle) * 0.75
		var x := island.centre_x + cos(angle) * away
		var z := island.centre_z + sin(angle) * away
		if not island.holds_water_at(x, z):
			return Vector2(x, z)
	return Vector2(island.centre_x, island.centre_z)


## The widest island with no pond in the middle of it, so that "stand on this
## island" means standing on ground.
func _widest_dry(islands: Array[FloatingIsland]) -> FloatingIsland:
	var best: FloatingIsland = null
	for island in islands:
		if island.holds_water_at(island.centre_x, island.centre_z):
			continue
		if best == null or island.radius > best.radius:
			best = island
	return best if best != null else _widest(islands)


func _widest(islands: Array[FloatingIsland]) -> FloatingIsland:
	var best: FloatingIsland = islands[0]
	for island in islands:
		if island.radius > best.radius:
			best = island
	return best
