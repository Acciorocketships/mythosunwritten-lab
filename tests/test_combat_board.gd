extends TestSuite
## The tactical lattice: the generated ground read as a board.
##
## Six claims live here, and they are the six the layer is for.
##
## *The lattice belongs to the world, not to the board.* A cell's centre is a
## function of its coordinate and the cell size and of nothing else, so two
## boards asked for around different positions agree on every cell they share --
## cell by cell, field by field, not merely in outline.
##
## *A cell's contents are a function of the cell.* A board built after a hundred
## unrelated boards is the same board; a board built in a second world made from
## the same seed is the same board. Nothing here accumulates.
##
## *Every hole in the world is the terrain query's hole.* Water, the void off an
## island's rim and the pond in an island's basin all have to come back as holes
## through `is_void_at`, and the board's own answer has to agree with that call
## position for position. If it ever did not, a second rule about what a hole is
## would have been written, which is the thing this layer must not do.
##
## *The board is coarser than the ground it reads.* Its cell is bigger than the
## terrain-generation cell and does not divide the chunk, so the two lattices
## cannot quietly become one.
##
## *The climb is the walker's climb.* What a piece may step up is
## TerrainQuery.HOP_HEIGHT and what it may step down is TerrainQuery.DROP_REACH,
## taken from there rather than restated, and `can_step` obeys both -- including
## the asymmetry that makes a ledge one-way.
##
## *The world has storeys and the board says which.* A board reads as readily on
## an island's top as on the ground, and where an island laps over the ground in
## plan a cell says so.
class_name TestCombatBoard

## The world the whole suite reads. One seed, because what is being checked is
## the reading rather than the generation; the places below were found in it by
## searching rather than by being typed in, so the suite keeps working when the
## seed changes.
const SEED := 1234

## How far out the searches for a piece of water, a village and an island look,
## in world units, and how coarsely they step.
const SEARCH_REACH := 420.0

## Where the water checks search from, and the board the hole checks are read on.
##
## Not the origin any more. Since the mountains went in, the ground around this
## seed's origin stands tens of units above the water table and there is no lake
## within the search's reach of it; this is the middle of the wettest 360-unit
## square within a kilometre, and the position below is a lake inside it. A
## claim about water being a hole in the board needs water under the board.
const WATER_SAMPLE_CENTRE := Vector2(480.0, -480.0)
const WATER_SAMPLE_AT := Vector2(526.7, -526.7)
const SEARCH_STEP := 6.0

## A smaller board than the default, where a check only needs a board and not a
## fight-sized one. Twelve units either side is nine cells across.
const SMALL_SPAN := 12.0


func _init() -> void:
	suite_name = "combat board"


func run() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var builder := CombatBoardBuilder.new(terrain)

	_the_lattice_is_fixed_to_the_world()
	_the_cell_is_coarser_than_the_ground_it_reads()
	_the_climb_is_the_walkers_climb()
	_two_overlapping_boards_agree_on_every_shared_cell(builder)
	_a_board_does_not_depend_on_what_was_built_before_it(builder)
	_two_worlds_of_one_seed_read_the_same_board(builder)
	_every_cell_answers_all_six_questions(builder)
	_the_board_reads_its_holes_off_the_terrain_query(terrain, builder)
	_water_is_a_hole(terrain, builder)
	_a_village_blocks_movement_and_lines(terrain, builder)
	_a_cliff_edge_is_a_drop_of_more_than_a_step(builder)

	var island := _an_island_with_a_basin(terrain)
	check(island != null, "expected a walkable island with a pond within reach of the origin")
	if island != null:
		_a_board_reads_on_an_island_as_readily_as_on_the_ground(terrain, builder, island)
		_the_void_off_an_island_is_a_hole(terrain, builder, island)
		_an_islands_basin_pond_is_a_hole(terrain, builder, island)
		_a_ground_cell_under_an_island_says_an_island_is_over_it(terrain, builder, island)

	_a_copy_is_not_a_way_back_in(builder)


# --- The lattice ---------------------------------------------------------

## A cell's centre is arithmetic on its coordinate, and a position lands in the
## cell whose centre is nearest it. Checked either side of the world origin,
## because truncating instead of flooring would make the two cells touching the
## origin twice as wide as the rest and only there.
func _the_lattice_is_fixed_to_the_world() -> void:
	var size := CombatBoard.CELL_SIZE
	for at in range(-40, 41):
		var cell := Vector2i(at, -at)
		var centre := CombatBoard.centre_of(cell, size)
		equal(centre.x, (float(at) + 0.5) * size,
			"cell %d's centre is its coordinate and the cell size, and nothing else" % at)
		equal(CombatBoard.cell_of(centre.x, centre.y, size), cell,
			"a cell's own centre falls back in that cell")
		# Just inside either edge of the cell, and nowhere else.
		var low := Vector2(float(cell.x) * size + 0.001, float(cell.y) * size + 0.001)
		var high := Vector2(
			float(cell.x + 1) * size - 0.001, float(cell.y + 1) * size - 0.001
		)
		equal(CombatBoard.cell_of(low.x, low.y, size), cell,
			"the low corner of cell %d belongs to it" % at)
		equal(CombatBoard.cell_of(high.x, high.y, size), cell,
			"the high corner of cell %d belongs to it" % at)
	equal(CombatBoard.cell_of(-0.001, -0.001, size), Vector2i(-1, -1),
		"the position just below the origin is in the cell below it, not in the cell above")


## The board's lattice is coarser than the lattice the ground is generated on,
## and is not a whole number of cells to a chunk -- so a board's cells straddle
## chunk borders and the two grids cannot start standing in for one another.
func _the_cell_is_coarser_than_the_ground_it_reads() -> void:
	check(CombatBoard.CELL_SIZE > TerrainChunkMesher.CELL_SIZE,
		"the board's cell (%.2f) must be coarser than the ground's (%.2f)" % [
			CombatBoard.CELL_SIZE, TerrainChunkMesher.CELL_SIZE,
		])
	var per_chunk := TerrainChunkMesher.CHUNK_SIZE / CombatBoard.CELL_SIZE
	check(absf(per_chunk - roundf(per_chunk)) > 0.01,
		"the board's cell must not divide the chunk, got %.4f cells per chunk" % per_chunk)


## The two thresholds a piece moves by are the terrain query's own walking
## constants, and `can_step` is asymmetric in exactly the way they are.
func _the_climb_is_the_walkers_climb() -> void:
	equal(CombatBoard.STEP_UP, TerrainQuery.HOP_HEIGHT,
		"what a piece steps up is what a walker hops up")
	equal(CombatBoard.STEP_DOWN, TerrainQuery.DROP_REACH,
		"what a piece steps down is what a walker drops")
	equal(CombatBoard.CLIFF_DROP, TerrainQuery.DROP_REACH,
		"a cliff edge is a neighbour further down than a walker can drop")
	check(CombatBoard.STEP_DOWN < CombatBoard.STEP_UP,
		"a ledge is only one-way if the drop allowed is the smaller of the two")


# --- A cell's contents are a function of the cell -------------------------

## Two boards asked for around positions a little apart share a wide band of
## cells, and every one of those cells has to come back identical -- every field,
## not just the height. The one thing they may not share is a storey: both are
## read on the ground here, which is what "overlapping the same ground" means.
func _two_overlapping_boards_agree_on_every_shared_cell(
	builder: CombatBoardBuilder
) -> void:
	var cases: Array[Array] = [
		[Vector2(0.0, 0.0), Vector2(17.0, -11.0)],
		[Vector2(-113.5, 62.25), Vector2(-95.0, 62.25)],
		[Vector2(240.0, -180.0), Vector2(233.0, -166.5)],
	]
	for case in cases:
		var here: Vector2 = case[0]
		var there: Vector2 = case[1]
		var first := builder.build_on_ground(here.x, here.y)
		var second := builder.build_on_ground(there.x, there.y)
		var shared := 0
		var disagreed := 0
		for row in first.cells_deep:
			for column in first.cells_across:
				var cell := first.min_cell + Vector2i(column, row)
				if not second.contains(cell):
					continue
				shared += 1
				if first.cell_line(cell) != second.cell_line(cell):
					disagreed += 1
		check(shared > 100,
			"boards at %s and %s should share a wide band, shared %d cells" % [
				here, there, shared,
			])
		equal(disagreed, 0,
			"boards at %s and %s disagreed on %d of %d shared cells" % [
				here, there, disagreed, shared,
			])


## A board is the same board however many others were built first, and however
## much of the world has been asked about in between.
func _a_board_does_not_depend_on_what_was_built_before_it(
	builder: CombatBoardBuilder
) -> void:
	var fresh := builder.build_on_ground(41.0, -73.0)
	for at in 12:
		var away := float(at) * 137.0 - 800.0
		builder.build_on_ground(away, -away, SMALL_SPAN)
		builder.build_on_top(away * 0.5, away, SMALL_SPAN)
	var later := builder.build_on_ground(41.0, -73.0)
	equal(later.digest(), fresh.digest(),
		"a board built after forty unrelated boards is not the board built fresh")


## A second world made from the same seed reads the same board. This is the
## in-process half of the cross-process claim; the other half is a headless run
## compared byte for byte, in tests/test_determinism.gd and in the report.
func _two_worlds_of_one_seed_read_the_same_board(builder: CombatBoardBuilder) -> void:
	var elsewhere := CombatBoardBuilder.new(TerrainQuery.for_seed(SEED))
	for at in 4:
		var x := float(at) * 96.0 - 240.0
		var z := 180.0 - float(at) * 71.0
		equal(elsewhere.build_on_top(x, z).digest(), builder.build_on_top(x, z).digest(),
			"two worlds of seed %d read a different board at (%.1f, %.1f)" % [SEED, x, z])
	var other := CombatBoardBuilder.new(TerrainQuery.for_seed(SEED + 1))
	not_equal(other.build_on_top(0.0, 0.0).digest(), builder.build_on_top(0.0, 0.0).digest(),
		"a different seed should read a different board at the origin")


## Every cell has all six answers and they are consistent with one another: a
## hole is never standable, a hole has no height and no storey, a standable cell
## has both, and nothing blocks movement without a reason.
func _every_cell_answers_all_six_questions(builder: CombatBoardBuilder) -> void:
	var boards: Array[CombatBoard] = [
		builder.build_on_ground(0.0, 0.0),
		builder.build_on_ground(-160.0, 40.0),
		builder.build_on_ground(300.0, -300.0),
		# One of the four is laid on a lake, so that the sample holds holes as
		# well as ground. It used to be enough to take three places near the
		# origin and trust that one of them would meet water; on this seed a
		# mountain stands over the origin now and none of them does.
		builder.build_on_ground(WATER_SAMPLE_AT.x, WATER_SAMPLE_AT.y),
	]
	var holes := 0
	var standable := 0
	for board in boards:
		for row in board.cells_deep:
			for column in board.cells_across:
				var cell := board.min_cell + Vector2i(column, row)
				var is_hole := board.is_hole(cell)
				var can_stand := board.is_standable(cell)
				check(not (is_hole and can_stand),
					"cell %s is a hole and standable at once" % cell)
				if is_hole:
					holes += 1
					equal(board.height_at(cell), -INF,
						"a hole at %s should have no surface height" % cell)
					equal(board.storey_at(cell), CombatBoard.NO_STOREY,
						"a hole at %s belongs to no storey" % cell)
					check(board.blocks_move(cell), "a hole at %s must block movement" % cell)
					check(not board.blocks_line(cell),
						"a hole at %s must not block a line -- a chasm is not a wall" % cell)
					check(not board.is_cliff_edge(cell),
						"a hole at %s is what you are shoved into, not shoved off" % cell)
				if can_stand:
					standable += 1
					check(board.height_at(cell) > -INF,
						"a standable cell at %s must have a surface height" % cell)
					check(board.storey_at(cell) >= CombatBoard.GROUND_STOREY,
						"a standable cell at %s must belong to a storey" % cell)
					check(not board.blocks_move(cell),
						"a standable cell at %s must not block movement" % cell)
				equal(board.blocks_move(cell), not can_stand,
					"blocking movement and being unstandable are the same cell at %s" % cell)
	check(holes > 0 and standable > 0,
		"the four sample boards should hold both holes and ground, got %d and %d" % [
			holes, standable,
		])


## The board's hole is the terrain query's hole, position for position.
##
## Checked against `is_passable_at`, which is `is_void_at` asked from the ground,
## so what is compared is the board's answer against the very call the overworld
## uses. Nothing here re-derives what water is or where an island ends.
func _the_board_reads_its_holes_off_the_terrain_query(
	terrain: TerrainQuery, builder: CombatBoardBuilder
) -> void:
	var compared := 0
	for at in 5:
		var x := float(at) * 88.0 - 176.0
		var z := float(at) * -63.0 + 126.0
		var board := builder.build_on_ground(x, z)
		for row in board.cells_deep:
			for column in board.cells_across:
				var cell := board.min_cell + Vector2i(column, row)
				var centre := board.centre(cell)
				compared += 1
				equal(board.is_hole(cell), not terrain.is_passable_at(centre.x, centre.y),
					"cell %s disagrees with the terrain query about being a hole" % cell)
	check(compared > 2000, "expected a few thousand cells compared, got %d" % compared)


## Water is a hole, and the shore beside it is a cliff edge: there is nothing to
## land on in a lake, so the fall into one is unbounded.
func _water_is_a_hole(terrain: TerrainQuery, builder: CombatBoardBuilder) -> void:
	var wet := _a_position_where(terrain, func(x: float, z: float) -> bool:
		return terrain.is_water_at(x, z)
	, WATER_SAMPLE_CENTRE)
	check(wet != Vector2.INF, "expected water within reach of the wet sample")
	if wet == Vector2.INF:
		return
	var board := builder.build_on_ground(wet.x, wet.y)
	var cell := CombatBoard.cell_of(wet.x, wet.y, board.cell_size)
	check(board.is_hole(cell), "the cell over water at %s is not a hole" % wet)
	var shores := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var at := board.min_cell + Vector2i(column, row)
			if not board.is_standable(at):
				continue
			var beside_a_hole := false
			for step in CombatBoard.NEIGHBOURS:
				if board.contains(at + step) and board.is_hole(at + step):
					beside_a_hole = true
			if not beside_a_hole:
				continue
			shores += 1
			equal(board.drop_at(at), INF,
				"the fall from %s into the water beside it should be unbounded" % at)
			check(board.is_cliff_edge(at),
				"a cell on the shore at %s should be a cliff edge to be shoved off" % at)
	check(shores > 0, "a board over water at %s should have a shoreline on it" % wet)


## A building's footprint stops both a piece and a line, and is not a hole --
## there is ground under a house.
##
## The claim is about the cells the board flags, not about a particular position:
## a building is between 2.6 and 7.8 world units across and a cell is 3.0, so a
## small one can fall between the cell centres and not be on the board at all.
## That is the cost of the cell size, it is measured in reports/combat-board.md,
## and it is why this checks that every blocking cell really has a building on it
## rather than that every building has a blocking cell.
func _a_village_blocks_movement_and_lines(
	terrain: TerrainQuery, builder: CombatBoardBuilder
) -> void:
	var built := _a_position_where(terrain, func(x: float, z: float) -> bool:
		return terrain.is_reserved_at(x, z)
	)
	check(built != Vector2.INF, "expected a village within reach of the origin")
	if built == Vector2.INF:
		return
	var board := builder.build_on_ground(built.x, built.y)
	check(board.blocking_count() > 0 and board.standable_count() > 0,
		"a board over a village at %s should be part houses and part green, got %d of %d"
			% [built, board.blocking_count(), board.cell_count()])
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			if not board.blocks_line(cell) or board.is_hole(cell):
				continue
			var centre := board.centre(cell)
			if not terrain.is_reserved_at(centre.x, centre.y):
				# The other way a cell blocks a line: a face of ground taller
				# than a piece can climb. Then it is standable ground rather
				# than a building, and the face has to really be there.
				var tallest := 0.0
				for step in CombatBoard.NEIGHBOURS:
					if not board.contains(cell + step) or board.is_hole(cell + step):
						continue
					tallest = maxf(tallest, board.height_at(cell) - board.height_at(cell + step))
				check(tallest > CombatBoard.STEP_UP,
					"cell %s blocks a line with neither a building nor a face on it" % cell)
				continue
			check(board.blocks_move(cell), "a cell inside a building at %s must block movement" % cell)
			check(not board.is_standable(cell), "no piece stands inside a building at %s" % cell)


## Every cell flagged a cliff edge really does have a neighbour more than a step
## below it, and no cell with such a neighbour is left unflagged.
func _a_cliff_edge_is_a_drop_of_more_than_a_step(builder: CombatBoardBuilder) -> void:
	var edges := 0
	for at in 6:
		var x := float(at) * 74.0 - 222.0
		var z := float(at) * 58.0 - 174.0
		var board := builder.build_on_ground(x, z)
		for row in board.cells_deep:
			for column in board.cells_across:
				var cell := board.min_cell + Vector2i(column, row)
				if not board.is_standable(cell):
					continue
				var deepest := 0.0
				for step in CombatBoard.NEIGHBOURS:
					var beside := cell + step
					if not board.contains(beside):
						deepest = maxf(deepest, board.drop_at(cell))
						continue
					if board.is_hole(beside):
						deepest = INF
					else:
						deepest = maxf(deepest, board.height_at(cell) - board.height_at(beside))
				equal(board.is_cliff_edge(cell), deepest > CombatBoard.CLIFF_DROP,
					"cell %s: deepest fall %s against the cliff flag" % [
						cell, CombatBoard.number_text(deepest),
					])
				if board.is_cliff_edge(cell):
					edges += 1
				# Walking is the walking constants and nothing else, and it is
				# one-way down a ledge: a piece may drop STEP_DOWN and climb
				# STEP_UP, and the two are different numbers.
				for step in CombatBoard.NEIGHBOURS:
					var beside := cell + step
					if not board.contains(beside):
						continue
					var expected := board.is_standable(beside) \
						and board.height_at(beside) - board.height_at(cell) <= CombatBoard.STEP_UP \
						and board.height_at(cell) - board.height_at(beside) <= CombatBoard.STEP_DOWN
					equal(board.can_step(cell, beside), expected,
						"stepping from %s to %s is not what the walking constants say" % [
							cell, beside,
						])
	check(edges > 0, "expected some cliff edges over six boards, found none")


# --- Storeys -------------------------------------------------------------

## A board asked for on an island's top is read on the island: its anchor is a
## storey above the ground, and a good share of its cells stand on the island.
func _a_board_reads_on_an_island_as_readily_as_on_the_ground(
	terrain: TerrainQuery, builder: CombatBoardBuilder, island: FloatingIsland
) -> void:
	var top := island.top_height_at(island.centre_x, island.centre_z)
	var board := builder.build(island.centre_x, island.centre_z, top)
	check(board.anchor_storey > CombatBoard.GROUND_STOREY,
		"a board on an island should be anchored above the ground, got storey %d"
			% board.anchor_storey)
	check(board.aerial_count() > 20,
		"a board on an island should stand mostly on it, got %d aerial cells of %d" % [
			board.aerial_count(), board.cell_count(),
		])
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			if board.storey_at(cell) <= CombatBoard.GROUND_STOREY:
				continue
			var centre := board.centre(cell)
			check(board.islands_over(cell) > 0,
				"cell %s is on a storey above the ground but reports no island over it" % cell)
			check(board.height_at(cell) > terrain.ground_height_at(centre.x, centre.y),
				"an aerial cell at %s should stand above the ground plane" % cell)
	# The same position asked for on the ground is read on the ground instead.
	var below := builder.build_on_ground(island.centre_x, island.centre_z)
	equal(below.anchor_storey, CombatBoard.GROUND_STOREY,
		"a board asked for on the ground under an island should stay on the ground")
	not_equal(below.digest(), board.digest(),
		"the two storeys over one position must not read as the same board")


## Off the island's rim, at the island's own height, there is nothing to stand
## on -- and the board says so through the same call the terrain query answers
## with.
func _the_void_off_an_island_is_a_hole(
	terrain: TerrainQuery, builder: CombatBoardBuilder, island: FloatingIsland
) -> void:
	var top := island.top_height_at(island.centre_x, island.centre_z)
	var span := island.max_reach() + 3.0 * CombatBoard.CELL_SIZE
	var board := builder.build(island.centre_x, island.centre_z, top, span)
	var voids := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var centre := board.centre(cell)
			if island.covers(centre.x, centre.y):
				continue
			if not board.is_hole(cell):
				continue
			voids += 1
			check(terrain.is_void_at(
					centre.x, centre.y, island.top_height_at(centre.x, centre.y)),
				"the board calls %s a hole where the terrain query does not" % cell)
	check(voids > 0,
		"a board wider than the island should find the void off its rim, found none")


## The pond in an island's own basin is a hole in the aerial storey, for the same
## reason a lake is a hole in the ground: water is not a surface.
func _an_islands_basin_pond_is_a_hole(
	terrain: TerrainQuery, builder: CombatBoardBuilder, island: FloatingIsland
) -> void:
	var top := island.top_height_at(island.centre_x, island.centre_z)
	var board := builder.build(island.centre_x, island.centre_z, top)
	var ponded := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var centre := board.centre(cell)
			if not island.holds_water_at(centre.x, centre.y):
				continue
			ponded += 1
			check(board.is_hole(cell),
				"the pond on the island at %s should be a hole in the board" % cell)
			check(terrain.is_water_at(centre.x, centre.y, top),
				"the terrain query should call %s water on the island's storey" % cell)
	check(ponded > 0, "the chosen island was supposed to hold a pond, found no wet cell")


## Where an island laps over the ground in plan, a ground cell says an island is
## over it -- and where the rim comes within a hop, the cell is the island's.
func _a_ground_cell_under_an_island_says_an_island_is_over_it(
	terrain: TerrainQuery, builder: CombatBoardBuilder, island: FloatingIsland
) -> void:
	# Wide enough to reach the island's rim, which a fight-sized board no longer
	# is: an island's outline can reach past thirty units from its middle, and
	# the landing -- the one stretch of rim within a hop of the ground -- is out
	# there on the boundary.
	var board := builder.build_on_ground(
		island.centre_x, island.centre_z,
		maxf(CombatBoardBuilder.DEFAULT_SPAN, island.max_reach() + CombatBoard.CELL_SIZE),
	)
	var overlapped := 0
	var lifted := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var centre := board.centre(cell)
			if terrain.islands_at(centre.x, centre.y).is_empty():
				equal(board.islands_over(cell), 0,
					"cell %s reports an island over it where the query finds none" % cell)
				continue
			overlapped += 1
			check(board.islands_over(cell) > 0,
				"cell %s is under an island and should say so" % cell)
			if board.storey_at(cell) > CombatBoard.GROUND_STOREY:
				lifted += 1
	check(overlapped > 0,
		"a board centred on an island should have cells with the island over them")
	check(lifted > 0,
		"somewhere under the rim the island is within a hop, so some cell should be its")


# --- A copy is a copy ----------------------------------------------------

## The copy a caller is handed shares no storage with the board it came from:
## writing every cell of the copy leaves the original untouched.
func _a_copy_is_not_a_way_back_in(builder: CombatBoardBuilder) -> void:
	var board := builder.build_on_ground(12.0, -34.0, SMALL_SPAN)
	var before := board.digest()
	var copy := board.detached_copy()
	equal(copy.digest(), before, "a fresh copy should be the same board")
	for row in copy.cells_deep:
		for column in copy.cells_across:
			copy.put(
				copy.min_cell + Vector2i(column, row),
				CombatBoard.HOLE, -INF, CombatBoard.NO_STOREY, 9, INF,
			)
	not_equal(copy.digest(), before, "writing over every cell of the copy should change it")
	equal(board.digest(), before, "writing into a copy must not reach the board it came from")


# --- Finding places to test on ------------------------------------------

## The first position on a fixed outward lattice where a test holds, or
## Vector2.INF. Searched rather than typed in, so the suite keeps finding a lake
## and a village when the seed changes.
func _a_position_where(
	_terrain: TerrainQuery, holds: Callable, middle: Vector2 = Vector2.ZERO
) -> Vector2:
	var steps := int(SEARCH_REACH / SEARCH_STEP)
	for ring in range(1, steps + 1):
		for at in range(-ring, ring + 1):
			var corners: Array[Vector2] = [
				Vector2(float(at), float(-ring)), Vector2(float(at), float(ring)),
				Vector2(float(-ring), float(at)), Vector2(float(ring), float(at)),
			]
			for corner in corners:
				var x := middle.x + corner.x * SEARCH_STEP
				var z := middle.y + corner.y * SEARCH_STEP
				if holds.call(x, z):
					return Vector2(x, z)
	return Vector2.INF


## The first walkable island near the origin that holds a pond, in cell order.
func _an_island_with_a_basin(terrain: TerrainQuery) -> FloatingIsland:
	var fallback: FloatingIsland = null
	for band in FloatingIsland.WALKABLE_BANDS:
		var size := IslandField.cell_size(band)
		var reach := int(ceil(SEARCH_REACH / size))
		for cell_x in range(-reach, reach + 1):
			for cell_z in range(-reach, reach + 1):
				var island := terrain.island_field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island == null or not island.walkable:
					continue
				if fallback == null:
					fallback = island
				if island.has_basin() \
						and island.holds_water_at(island.centre_x, island.centre_z):
					return island
	return fallback
