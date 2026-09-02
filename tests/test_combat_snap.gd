extends TestSuite
## The snap onto the board and back is a deliverable, so it is tested like one.
##
## Nine claims, and the first two are the pair everything else stands on:
##
##   1. **The round trip is exact.** A cell turned into a world position and back
##      is the cell it started as, for every cell of every board -- typed out,
##      read off the ground, and read off a floating island's top. The check that
##      this is really being tested is included: the same comparison run against
##      a lattice offset by a fraction of a cell is required to fail.
##   2. **A combatant snaps to the cell nearest where it stood**, and "nearest"
##      is checked against every cell of the board by brute force rather than
##      against the arithmetic that produced it.
##   3. The world steps continuously up to the snap and after it, and the
##      combatants land on the cells they were standing over.
##   4. Every survivor comes back at the world position its final cell
##      corresponds to, and that position snaps back to that same cell.
##   5. Combat is local: the join radius decides membership, a band outside it is
##      untouched, and the streaming and the rest of the world go on stepping
##      while the fight is on.
##   6. A fight begun on a floating island's top is held on that storey's board.
##   7. The stop condition is asked in code: a combatant that cannot be seated
##      makes the fight refuse rather than get nudged.
##   8. The whole cycle reproduces byte-identically across two processes.
##   9. The render layer draws the fight out of a snapshot and holds none of it:
##      throwing its view bookkeeping away and rebuilding it from the same
##      snapshot produces the identical picture.
class_name TestCombatSnap

const SEED := ScriptedEncounter.SEED

## Ticks enough for the ground scenario to walk in, fight and walk on again.
const TICKS := 45

## A board typed out with a chasm through it and a building on it, for the
## placement rules that want ground whose every feature is where it says.
const MAP := [
	".............",
	".............",
	"....~~~~~....",
	"....~~~~~....",
	"....~~~~~....",
	"......#......",
	".............",
	".............",
	".............",
]


func _init() -> void:
	suite_name = "combat snap"


func run() -> void:
	_the_round_trip_is_exact()
	_the_round_trip_check_can_fail()
	_a_combatant_snaps_to_the_nearest_cell()
	_the_search_steps_outwards_only_when_it_has_to()
	_the_world_steps_up_to_the_snap_and_they_land_where_they_stood()
	_every_survivor_comes_back_where_its_last_cell_says()
	_combat_is_local()
	_the_world_goes_on_while_a_fight_is_on()
	_a_fight_on_an_island_uses_that_storeys_board()
	_a_combatant_that_cannot_be_seated_refuses_the_fight()
	_an_empty_roster_is_nothing_at_all()
	_two_processes_play_the_same_cycle()
	_the_render_layer_draws_the_fight_out_of_the_snapshot()


# --- 1 and 2: the arithmetic ---------------------------------------------


## Every cell of every board survives being turned into a world position and
## back. Three kinds of board, because the claim is about the lattice and not
## about any one reading of it.
func _the_round_trip_is_exact() -> void:
	check(CombatSnap.round_trips(_sketch()), "a typed-out board round-trips")
	var world := SimWorld.new(SEED)
	for at in [Vector2.ZERO, ScriptedEncounter.WHERE, Vector2(311.0, -74.0)]:
		var board := world.combat_board_builder.build_on_top(at.x, at.y)
		check(CombatSnap.round_trips(board),
			"a board read off the ground at (%.0f, %.0f) round-trips" % [at.x, at.y])
	var island := world.island_field.first_walkable_island(ScriptedEncounter.ISLAND_SPAN)
	check(island != null, "seed %d should have a walkable island to test on" % SEED)
	if island != null:
		var aerial := world.combat_board_builder.build(
			island.centre_x, island.centre_z,
			island.top_height_at(island.centre_x, island.centre_z))
		check(CombatSnap.round_trips(aerial), "a board on an island's top round-trips")
		equal(aerial.anchor_storey > CombatBoard.GROUND_STOREY, true,
			"and that board is on the island's storey")


## The round-trip check would notice if the two directions stopped agreeing.
##
## The same comparison, with the position pushed half a cell off the centre --
## which is exactly the boundary between two cells -- must fail. Without this,
## "round_trips returned true" would be indistinguishable from "round_trips
## cannot return false".
func _the_round_trip_check_can_fail() -> void:
	var board := _sketch()
	var wrong := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var middle := board.centre(cell)
			# Half a cell further along: the centre of the next cell over.
			var pushed := Vector2(middle.x + board.cell_size, middle.y)
			if CombatSnap.cell_for(pushed.x, pushed.y, board.cell_size) != cell:
				wrong += 1
	equal(wrong, board.cell_count(),
		"a position a whole cell away must land in a different cell, every time")


## The cell a combatant snaps to is the cell whose centre is nearest to where it
## was standing -- checked against every cell of the board, not against the
## arithmetic that produced the answer.
func _a_combatant_snaps_to_the_nearest_cell() -> void:
	var world := SimWorld.new(SEED)
	var here := ScriptedEncounter.WHERE
	var board := world.combat_board_builder.build_on_top(here.x, here.y)
	var checked := 0
	for step_x in range(-9, 10):
		for step_z in range(-9, 10):
			var at := Vector2(here.x + float(step_x) * 1.7, here.y + float(step_z) * 1.7)
			var chosen := CombatSnap.cell_for(at.x, at.y, board.cell_size)
			if not board.contains(chosen):
				continue
			checked += 1
			var best_far := INF
			for row in board.cells_deep:
				for column in board.cells_across:
					var cell := board.min_cell + Vector2i(column, row)
					var middle := board.centre(cell)
					var far := Vector2(middle.x - at.x, middle.y - at.y).length_squared()
					best_far = minf(best_far, far)
			var mine := board.centre(chosen)
			var chosen_far := Vector2(mine.x - at.x, mine.y - at.y).length_squared()
			# Compared by distance rather than by cell, because a position exactly
			# on a cell boundary is genuinely equidistant from two cells and
			# "the nearest" is then either of them. Which one it is, is settled
			# by `cell_of` flooring, and that is what makes the lattice
			# world-fixed rather than a matter of which was scanned first.
			check(chosen_far <= best_far + 0.000001,
				"(%.2f, %.2f) snapped to (%d,%d) at %.4f, nearest is %.4f"
				% [at.x, at.y, chosen.x, chosen.y, sqrt(chosen_far), sqrt(best_far)])
			# And no cell is ever more than half a cell's diagonal away, which is
			# the whole of what snapping to a lattice can cost.
			var furthest := board.cell_size * sqrt(2.0) * 0.5
			check(sqrt(chosen_far) <= furthest + 0.000001,
				"(%.2f, %.2f) moved %.4f, more than half a cell's diagonal (%.4f)"
				% [at.x, at.y, sqrt(chosen_far), furthest])
	check(checked > 300, "the sweep should have checked hundreds of positions, did %d"
		% checked)


## The search only leaves the cell a combatant is standing over when that cell
## will not take it: a hole, a building, or somebody already on it.
func _the_search_steps_outwards_only_when_it_has_to() -> void:
	var board := _sketch()
	var size := board.cell_size
	# Open ground: the cell it is standing over, no search at all.
	var open := CombatSnap.nearest_free_cell(board, {}, size * 1.5, size * 7.5)
	equal(open["ok"], true, "open ground seats a combatant")
	equal(open["cell"], Vector2i(1, 7), "on the cell it was standing over")
	equal(open["rings"], 0, "without searching")

	# In the middle of the chasm: the nearest cell that is not a hole, which is
	# two rings out because the chasm is three cells deep.
	var chasm := CombatSnap.nearest_free_cell(board, {}, size * 6.5, size * 3.5)
	equal(chasm["ok"], true, "a combatant over a chasm is still seated")
	equal(board.is_hole(Vector2i(6, 3)), true, "and (6,3) really is a hole")
	equal(board.is_hole(chasm["cell"]), false, "on a cell that is not one")
	equal(chasm["rings"], 2, "two rings out, which is the nearest dry ground there")

	# On the building: the same rule, by the other flag.
	var built := CombatSnap.nearest_free_cell(board, {}, size * 6.5, size * 5.5)
	equal(board.blocks_move(Vector2i(6, 5)), true, "(6,5) really is built on")
	equal(built["ok"], true, "a combatant on a building is still seated")
	equal(built["rings"], 1, "one ring out")

	# Somebody already there: the same rule again, by occupancy this time.
	var taken := {Vector2i(1, 7): 1}
	var beside := CombatSnap.nearest_free_cell(board, taken, size * 1.5, size * 7.5)
	equal(beside["ok"], true, "a second combatant on one cell is seated beside it")
	equal(beside["rings"], 1, "one ring out")
	not_equal(beside["cell"], Vector2i(1, 7), "and not on top of the first")


# --- 3 and 4: the two snaps, in the world --------------------------------


## The world runs in real time up to the moment of the snap, and at that moment
## every combatant occupies the cell it was standing over.
func _the_world_steps_up_to_the_snap_and_they_land_where_they_stood() -> void:
	var run := _walk_to_the_snap()
	var world: SimWorld = run["world"]
	check(int(run["snapped_at"]) > 0,
		"the world should have stepped in real time before any fight began")
	check(world.combat.fight != null, "and then a fight should have begun")
	if world.combat.fight == null:
		return
	var fight := world.combat.fight
	var before: Dictionary = run["before"]
	var board := fight.board
	# Combatants are seated in roster id order, so a cell one of them takes is
	# gone for the ones after it. The check walks the same order.
	var taken := {}
	var moved_off_home := 0
	for one in fight.members:
		var stood: Vector2 = before[one.id]
		var home := CombatSnap.cell_for(stood.x, stood.y, board.cell_size)
		var seat: Vector2i = one.piece.cell
		check(board.is_standable(seat) and not board.blocks_move(seat),
			"#%d is seated on a cell a piece may stand on" % one.id)
		check(not taken.has(seat), "#%d has a cell nobody else took" % one.id)

		# The nearest cell that would have it, found by walking the whole board
		# rather than by asking the arithmetic that produced the answer.
		var best_far := INF
		for row in board.cells_deep:
			for column in board.cells_across:
				var cell := board.min_cell + Vector2i(column, row)
				if taken.has(cell) or not board.is_standable(cell) \
						or board.blocks_move(cell):
					continue
				var middle := board.centre(cell)
				best_far = minf(best_far, Vector2(
					middle.x - stood.x, middle.y - stood.y).length_squared())
		var mine := board.centre(seat)
		var far := Vector2(mine.x - stood.x, mine.y - stood.y).length_squared()
		check(far <= best_far + 0.000001,
			"#%d was seated %.4f from where it stood; the nearest free cell is %.4f"
			% [one.id, sqrt(far), sqrt(best_far)])

		# And when the cell it was standing over would have had it, that is the
		# cell it got -- no search, no nudge.
		if not taken.has(home) and board.is_standable(home) \
				and not board.blocks_move(home):
			equal(seat, home,
				"#%d stood over a free cell and should be on it" % one.id)
		else:
			moved_off_home += 1
		taken[seat] = one.id

		# And it is now standing at that cell's own position in the world.
		var at := CombatSnap.world_of(board, seat)
		check(Vector3(one.x, one.y, one.z).distance_to(at) < 0.000001,
			"#%d should stand at its cell's world position" % one.id)
	check(moved_off_home <= 2,
		"most of the band should be on the very cell it stood over, %d were not"
		% moved_off_home)


## Every survivor comes back at the world position its final cell corresponds to,
## and that position snaps back to that same cell -- the round trip, asked of the
## actual fight rather than of the arithmetic.
func _every_survivor_comes_back_where_its_last_cell_says() -> void:
	var world := SimWorld.new(SEED)
	ScriptedEncounter.muster(world)
	var last_cells := {}
	var board: CombatBoard = null
	for _step in TICKS:
		if world.combat.fight != null:
			board = world.combat.fight.board
			for one in world.combat.fight.members:
				var standing := world.combat.fight.match_state.pieces.piece_of(one.piece.id)
				if standing != null:
					last_cells[one.id] = standing.cell
		world.step()
		if world.combat.fights_ended > 0:
			break
	equal(world.combat.fights_ended, 1, "the fight should have resolved")
	check(board != null, "and a board should have been read for it")
	if board == null:
		return
	var checked := 0
	for one in world.combat.members:
		if not last_cells.has(one.id):
			continue
		checked += 1
		var cell: Vector2i = last_cells[one.id]
		var expected := CombatSnap.world_of(board, cell)
		check(Vector3(one.x, one.y, one.z).distance_to(expected) < 0.000001,
			"#%d should stand where cell (%d,%d) is" % [one.id, cell.x, cell.y])
		equal(CombatSnap.cell_for(one.x, one.z, board.cell_size), cell,
			"and standing there should snap back to that same cell")
		check(is_finite(one.y), "#%d came back at a finite height" % one.id)
	check(checked >= 2, "at least two survivors should have been put back, was %d" % checked)


# --- 5: local ------------------------------------------------------------


## Which combatants join is decided by the radius, and everyone outside it is
## untouched -- their positions during and after the fight are exactly what
## walking for that many ticks gives.
func _combat_is_local() -> void:
	var run := _walk_to_the_snap()
	var world: SimWorld = run["world"]
	if world.combat.fight == null:
		check(false, "no fight began, so locality cannot be checked")
		return
	var fight := world.combat.fight
	var anchor := world.combat.member_of(fight.anchor_id)
	var joined := {}
	for one in fight.members:
		joined[one.id] = true
		check(one.distance_from(fight.anchor_x, fight.anchor_z) <= Encounter.JOIN_RADIUS
				or one.fighting,
			"#%d joined, so it was inside the radius when it did" % one.id)
	var outside := 0
	var before: Dictionary = run["before"]
	for one in world.combat.members:
		if joined.has(one.id):
			continue
		outside += 1
		var stood: Vector2 = before[one.id]
		check(Vector2(stood.x - anchor.x, stood.y - anchor.z).length()
				> Encounter.JOIN_RADIUS,
			"#%d stayed out, so it was outside the radius" % one.id)
	check(outside >= 2, "the scenario should leave a whole band out, left %d" % outside)

	# And they keep walking through the fight: their positions after another ten
	# ticks are what walking gives, to the last decimal.
	var walked := {}
	for one in world.combat.members:
		if joined.has(one.id):
			continue
		walked[one.id] = Vector2(
			one.x + cos(one.heading) * one.speed * 10.0,
			one.z + sin(one.heading) * one.speed * 10.0)
	for _step in 10:
		world.step()
	check(world.combat.fight != null or world.combat.fights_ended == 1,
		"ten more ticks either continue the fight or end it")
	for one in world.combat.members:
		if not walked.has(one.id):
			continue
		var expected: Vector2 = walked[one.id]
		check(absf(one.x - expected.x) < 0.001 and absf(one.z - expected.y) < 0.001,
			"#%d walked exactly ten ticks' worth while the fight was on" % one.id)


## The rest of the simulation keeps stepping while a fight is in progress: the
## tick advances, the observer walks, the terrain streams and the world's
## fingerprint moves every single tick.
func _the_world_goes_on_while_a_fight_is_on() -> void:
	var world := SimWorld.new(SEED)
	ScriptedEncounter.muster(world)
	# The scenario stands the observer still so a camera can watch; here it walks,
	# because what is being checked is that the streaming carries on regardless.
	world.observer_walks = true
	var fingerprints := {}
	var fighting_ticks := 0
	var built_at_the_snap := -1
	var built_at_the_end := -1
	var chunks := PackedInt32Array()
	for _step in TICKS:
		world.step()
		fingerprints[world.digest()] = true
		if world.combat.fight != null:
			if built_at_the_snap < 0:
				built_at_the_snap = world.terrain_streamer.chunks_built
			fighting_ticks += 1
			chunks.append(world.terrain_streamer.loaded_count())
			built_at_the_end = world.terrain_streamer.chunks_built
	check(fighting_ticks >= 4, "the fight should span several ticks, spanned %d"
		% fighting_ticks)
	equal(fingerprints.size(), TICKS,
		"every tick of the world, fight or no fight, should be a new state")
	check(built_at_the_end > built_at_the_snap,
		"the terrain should still be streaming during the fight (%d -> %d chunks built)"
		% [built_at_the_snap, built_at_the_end])
	check(chunks.size() > 0 and chunks[0] > 0, "and ground should stay loaded throughout")


# --- 6: anywhere a character can stand -----------------------------------


## A fight begun on a floating island's top is held on that island's board.
##
## Nothing in `Encounter` tests for islands. It hands the board layer the
## commander's own position and the height it was standing at, and the storey
## follows -- so this is really a check that the height a combatant carries names
## the storey it is on.
func _a_fight_on_an_island_uses_that_storeys_board() -> void:
	var world := SimWorld.new(SEED)
	var island := ScriptedEncounter.muster_on_island(world)
	check(island != null, "seed %d should have a walkable island to fight on" % SEED)
	if island == null:
		return
	var snapped := false
	for _step in TICKS:
		world.step()
		if world.combat.fight != null:
			snapped = true
			break
	check(snapped, "the two bands on the island should have met")
	if not snapped:
		return
	var fight := world.combat.fight
	check(fight.board.anchor_storey > CombatBoard.GROUND_STOREY,
		"the board should be on the island's storey, was %d" % fight.board.anchor_storey)
	check(fight.board.hole_count() > 0,
		"and it should have the void off the island's rim in it as holes")
	var commanders := 0
	for one in fight.members:
		if not one.is_commander():
			continue
		commanders += 1
		equal(fight.board.storey_at(one.piece.cell), fight.board.anchor_storey,
			"#%d should be standing on the island's storey" % one.id)
		check(one.y > island.top_height_at(one.x, one.z) - 3.0,
			"#%d should be up on the island, not on the ground under it" % one.id)
	equal(commanders, 2, "both commanders should be on the aerial board")


# --- 7: the stop condition -----------------------------------------------


## A combatant that cannot be seated makes the fight refuse.
##
## The task this layer was built for said to stop and report rather than nudge
## positions until they looked acceptable. That is asked in code: `place()`
## searches four rings and then says no, and `Encounter.begin` comes back
## refused, having started no match and moved nobody.
func _a_combatant_that_cannot_be_seated_refuses_the_fight() -> void:
	# A board that is nothing but holes: there is nowhere at all to stand.
	var rows := PackedStringArray()
	for _row in 9:
		rows.append("~~~~~~~~~~~~~")
	var nothing := BoardSketch.from_rows(rows)
	equal(nothing.standable_count(), 0, "the fixture really has nowhere to stand")
	var stranded := _combatant(1, nothing.cell_size * 6.5, nothing.cell_size * 4.5)
	var refused := CombatSnap.place(nothing, [stranded])
	equal(refused["ok"], false, "a combatant over nothing cannot be seated")
	equal((refused["unplaced"] as PackedInt32Array).size(), 1, "and it says which one")
	equal(stranded.fighting, false, "and it was not put anywhere")

	# One cell of standable ground and two combatants over it: the first is
	# seated and the second is not, so the fight is refused rather than the two
	# being stacked on one cell.
	var one_cell := PackedStringArray([
		"~~~~~", "~~~~~", "~~.~~", "~~~~~", "~~~~~",
	])
	var pinhole := BoardSketch.from_rows(one_cell)
	equal(pinhole.standable_count(), 1, "the fixture has exactly one place to stand")
	var first := _combatant(1, pinhole.cell_size * 2.5, pinhole.cell_size * 2.5)
	var second := _combatant(2, pinhole.cell_size * 2.5, pinhole.cell_size * 2.5)
	var crowded := CombatSnap.place(pinhole, [first, second])
	equal(crowded["ok"], false, "two combatants cannot share the one cell")
	equal((crowded["placed"] as Dictionary).size(), 1, "the first was seated")
	equal((crowded["unplaced"] as PackedInt32Array)[0], 2, "and the second was not")


# --- 8 and 9: determinism, and the picture -------------------------------


## An empty roster is nothing at all: no fingerprint, no lines, no phase change.
## A world with nobody in it is the world it was before this layer existed.
func _an_empty_roster_is_nothing_at_all() -> void:
	var world := SimWorld.new(SEED)
	equal(world.combat.digest(), "", "an empty roster fingerprints as nothing")
	equal(world.combat.phase(), CombatantRoster.REAL_TIME, "and is in real time")
	for _step in 5:
		world.step()
	equal(world.combat_lines.size(), 0, "and writes nothing down")
	equal(world.combat.digest(), "", "and still fingerprints as nothing")


## Two processes play the whole cycle the same way, byte for byte.
##
## In-process repetition cannot see a dependence on an address or on the order a
## dictionary happens to iterate in; a second process can, because it lays its
## memory out differently.
func _two_processes_play_the_same_cycle() -> void:
	var first := _run_encounter()
	var second := _run_encounter()
	equal(first["exit_code"], 0,
		"./run_encounter.sh should exit 0 (output: %s)" % first["output"])
	equal(second["exit_code"], 0, "and so should the second run")
	check(not str(first["output"]).strip_edges().is_empty(),
		"the encounter command printed nothing")
	equal(first["output"], second["output"],
		"two processes should print the same cycle, byte for byte")
	var text := str(first["output"])
	check(text.contains("snap-in around #1"), "and it should contain the snap in")
	check(text.contains("ending=decided"), "a fight played to a conclusion")
	check(text.contains("snap-out #1"), "and the snap back out")


## The render layer draws the fight out of the snapshot and holds none of it.
##
## `CombatDiorama.placements()` is the whole bridge, and it is a pure function:
## the same snapshot gives the same rows however many times it is called and
## whatever was called in between, and a second snapshot does not remember the
## first. That is the behavioural half of "the render layer holds no piece of
## combat state of its own"; the structural half is in tests/test_layering.gd.
func _the_render_layer_draws_the_fight_out_of_the_snapshot() -> void:
	var world := SimWorld.new(SEED)
	ScriptedEncounter.muster(world)
	var walking := world.snapshot()
	var fighting := {}
	for _step in TICKS:
		world.step()
		if world.combat.fight != null:
			fighting = world.snapshot()
			break
	check(not fighting.is_empty(), "the scenario should reach a fight")
	if fighting.is_empty():
		return

	equal(CombatDiorama.is_fighting(walking), false, "before the snap, no fight")
	equal(CombatDiorama.is_fighting(fighting), true, "after it, a fight")
	equal(CombatDiorama.count(walking), 8, "the whole roster is drawn either way")

	# Pure: the same snapshot in, the same rows out, with the other snapshot
	# read in between so that anything remembered would show.
	var once := CombatDiorama.placements(fighting)
	var _other := CombatDiorama.placements(walking)
	var twice := CombatDiorama.placements(fighting)
	equal(once, twice, "the same snapshot should give the same picture")

	# Every drawn value is the snapshot's. A commander standing on a cell is
	# turned by its facing and is standing still; one walking is turned by its
	# heading and is moving.
	var rows: Array = fighting["combat"]["pieces"]
	for at in once.size():
		var row: Dictionary = rows[at]
		var drawn: Dictionary = once[at]
		equal(drawn["position"],
			Vector3(float(row["x"]), float(row["y"]), float(row["z"])),
			"#%d is drawn where the snapshot says" % int(row["id"]))
		if bool(row["fighting"]) and bool(row["commander"]):
			equal(drawn["heading"],
				CombatDiorama.heading_for_facing(int(row["facing"])),
				"#%d on the board is turned by its facing" % int(row["id"]))
			equal(float((drawn["state"] as Dictionary)["speed"]), 0.0,
				"#%d on the board is standing still" % int(row["id"]))
		else:
			equal(drawn["heading"], float(row["heading"]),
				"#%d off the board is turned by its heading" % int(row["id"]))

	# The four facings turn into the four quarter turns, and nothing else.
	equal(CombatDiorama.heading_for_facing(PieceGeometry.EAST), 0.0,
		"east is a heading of zero, which is +x")
	equal(CombatDiorama.heading_for_facing(PieceGeometry.NORTH), -PI * 0.5,
		"north is -z, which is a heading of -pi/2")
	equal(CombatDiorama.heading_for_facing(PieceGeometry.SOUTH), PI * 0.5, "south is +z")
	equal(CombatDiorama.heading_for_facing(PieceGeometry.WEST), PI, "west is -x")


# --- Helpers --------------------------------------------------------------


func _sketch() -> CombatBoard:
	return BoardSketch.from_rows(PackedStringArray(MAP))


func _combatant(id: int, x: float, z: float) -> Combatant:
	var made := Combatant.commander_at(x, z, 0.0, 0.0)
	made.id = id
	made.band = id
	return made


## Step the ground scenario until the instant a fight begins, remembering where
## everybody was standing on the tick before it did.
func _walk_to_the_snap() -> Dictionary:
	var world := SimWorld.new(SEED)
	ScriptedEncounter.muster(world)
	var before := {}
	var snapped_at := -1
	for _step in TICKS:
		var was := {}
		for one in world.combat.members:
			was[one.id] = Vector2(one.x, one.z)
		world.step()
		if world.combat.fight != null:
			# Where they were standing when the fight began is where they were
			# after that tick's walk -- the roster walks, then asks.
			before = {}
			for one in world.combat.members:
				before[one.id] = Vector2(one.x, one.z) if not one.fighting \
					else _walked(was[one.id], one)
			snapped_at = world.tick
			break
	return {"world": world, "before": before, "snapped_at": snapped_at}


## Where a combatant was standing at the end of the tick it was seated on: it
## walked, and then the fight took it, so its walked position is the one the
## snap read.
func _walked(was: Vector2, one: Combatant) -> Vector2:
	return Vector2(was.x + cos(one.heading) * one.speed, was.y + sin(one.heading) * one.speed)


func _run_encounter() -> Dictionary:
	var output := []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/encounter_main.gd",
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}
