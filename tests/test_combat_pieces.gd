extends TestSuite
## The two-tier army: four minions, commanders with facing, movement as armour.
##
## Every pattern here is checked against a board typed out by hand in
## BoardFixture, against a cell list written out in full. Nothing is compared to
## a list the code under test produced, and nothing is compared to a count.
##
## And every one of those assertions is then **broken on purpose**. For each
## claim there is a second run in which the one thing the rule is about is
## changed -- the hole is filled in, the wall is taken away, the enemy becomes a
## friend, the armour comes off, the cooldown is asked about a turn too early --
## and the same expected list is checked to no longer hold. An assertion that
## passes whatever the world does is not an assertion, and the paired failure is
## how each of these is shown not to be one.
##
## The board the whole suite stands on:
##
## ```
##  y=0   . . . . . . . . . . . . .
##  y=1   ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~      a chasm, right across
##  y=2   . . . . . . . . . . . . .
##  y=3   . . . . . . . . . . . . .
##  y=4   . . . . # . . . ~ . . . .      a building at (4,4), a hole at (8,4)
##  y=5   . . . . . . . . . . . . .
##  y=6   . . . . . . . . . . . . .
##  y=7   . . . . . . . . . . . . .
##  y=8   . . . . ^ . . . , . . . .      earth too high at (4,8), a step at (8,8)
##  y=9   . . . . . . . . . . . . .
##  y=10  . . . . . . . . . . . . .
##  y=11  . . . . . . . . . . . . .
##  y=12  . . . . . . . . . . . . .
## ```
##
## The four features are placed on the four diagonals out of (6,6) on purpose, so
## that one Cat standing in the middle of the board meets all four of them at
## once: a building to the north-west, a hole to the north-east, a face it cannot
## climb to the south-west, and a step down it can take to the south-east.
class_name TestCombatPieces

## The board, as it is typed out above.
const MAP := [
	".............",
	"~~~~~~~~~~~~~",
	".............",
	".............",
	"....#...~....",
	".............",
	".............",
	".............",
	"....^...,....",
	".............",
	".............",
	".............",
	".............",
]

## The middle of the board, where most pieces stand.
const MIDDLE := Vector2i(6, 6)

## Two owners, so that "somebody else's piece" is a thing that exists before any
## commander does. Real owners are commander ids; these stand in where the claim
## being checked is about a minion and not about who commands it.
const MINE := 101
const THEIRS := 202

## A generated world to read one real board off, so that the layer is shown to
## work on the ground the game actually makes and not only on typed-out ground.
const SEED := 1234


func _init() -> void:
	suite_name = "combat pieces"


func run() -> void:
	_the_fixture_means_what_it_says()
	_the_toadstool_walks_cardinally_and_takes_diagonally()
	_the_cat_slides_diagonally_until_something_stops_it()
	_the_ent_slides_cardinally_until_something_stops_it()
	_the_frog_hops_over_everything_in_between()
	_nothing_climbs_more_than_the_boards_step()
	_a_minion_has_no_facing_and_no_state_of_its_own()
	_surrounded_only_the_frog_gets_out()
	_a_commander_moves_one_cardinal_step_before_any_armour()
	_each_piece_of_armour_adds_a_way_of_moving()
	_a_grant_is_bought_by_the_cell()
	_an_under_qualified_wearer_reaches_less()
	_the_full_loadout_is_a_piece_that_is_not_in_chess()
	_the_loadout_does_not_reach_the_whole_board()
	_an_attack_is_a_pattern_of_cells_and_a_cooldown()
	_the_five_examples_are_expressible_the_same_way()
	_an_attack_rotates_with_the_commander()
	_turning_costs_nothing()
	_a_cooldown_is_counted_in_turns()
	_a_commanders_death_takes_its_minions_with_it()
	_the_layer_is_deterministic()
	_the_pieces_stand_on_the_generated_world_too()


# --- The fixture ----------------------------------------------------------

## The fixture's two heights are chosen against the board's own constants, and
## only mean what the map says while those constants hold: -2 has to be the
## deepest legal step and +4 the shallowest illegal climb.
func _the_fixture_means_what_it_says() -> void:
	var board := _board()
	equal(board.cells_across, 13, "the fixture is thirteen cells across")
	equal(board.cells_deep, 13, "the fixture is thirteen cells deep")
	check(BoardFixture.STEP_DOWN_HEIGHT == -CombatBoard.STEP_DOWN,
		"the fixture's step down must be exactly the board's deepest legal step")
	check(BoardFixture.TOO_HIGH > CombatBoard.STEP_UP,
		"the fixture's wall of earth must be higher than a piece can climb")

	# 169 cells, less the thirteen of the chasm, the hole and the building.
	equal(board.standable_count(), 154, "the fixture has 154 cells a piece can stand on")
	equal(board.hole_count(), 14, "the fixture has fourteen holes")
	check(board.can_step(Vector2i(7, 7), Vector2i(8, 8)),
		"a step down of exactly the board's reach is a legal step")
	check(not board.can_step(Vector2i(5, 7), Vector2i(4, 8)),
		"a climb higher than the board's reach is not a legal step")
	check(not board.can_step(Vector2i(5, 5), Vector2i(4, 4)),
		"a building is not a cell to step onto")
	check(not board.can_step(Vector2i(7, 5), Vector2i(8, 4)),
		"a hole is not a cell to step onto")


# --- The four minions -----------------------------------------------------

## Move one cardinal cell; capture one diagonal cell. The one piece in the game
## whose two patterns differ, and it differs without a facing -- all four
## cardinals, not a forward one.
func _the_toadstool_walks_cardinally_and_takes_diagonally() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var toadstool := _place(pieces, Minion.of_kind(Minion.TOADSTOOL, MINE, MIDDLE))

	_cells_are(board, pieces, toadstool, false,
		[Vector2i(6, 5), Vector2i(5, 6), Vector2i(7, 6), Vector2i(6, 7)],
		"a Toadstool walks onto the four cardinal cells")
	_cells_are(board, pieces, toadstool, true, [],
		"a Toadstool with nobody beside it captures nothing")

	# An enemy on each diagonal, and one on a cardinal cell.
	for at in [Vector2i(5, 5), Vector2i(7, 5), Vector2i(5, 7), Vector2i(7, 7)]:
		_place(pieces, Minion.of_kind(Minion.CAT, THEIRS, at))
	_place(pieces, Minion.of_kind(Minion.CAT, THEIRS, Vector2i(6, 5)))

	_cells_are(board, pieces, toadstool, true,
		[Vector2i(5, 5), Vector2i(7, 5), Vector2i(5, 7), Vector2i(7, 7)],
		"a Toadstool captures on the four diagonals and nowhere else")
	_cells_are(board, pieces, toadstool, false,
		[Vector2i(5, 6), Vector2i(7, 6), Vector2i(6, 7)],
		"a Toadstool cannot walk onto an occupied cardinal cell, nor capture on it")

	# Broken: the enemy in front becomes one of ours. The cell is still occupied,
	# so the move list is unchanged -- but it is no longer a capture, which is the
	# rule this pair is about.
	var friendly := _board()
	var same := PieceMap.new()
	var mine := _place(same, Minion.of_kind(Minion.TOADSTOOL, MINE, MIDDLE))
	for at in [Vector2i(5, 5), Vector2i(7, 5), Vector2i(5, 7), Vector2i(7, 7)]:
		_place(same, Minion.of_kind(Minion.CAT, MINE, at))
	_breaks(friendly, same, mine, true,
		[Vector2i(5, 5), Vector2i(7, 5), Vector2i(5, 7), Vector2i(7, 7)],
		"a Toadstool must not capture its own side")


## Diagonal lines until blocked, and the same pattern for moving and for taking.
## The one Cat below meets all four of the fixture's features at once.
func _the_cat_slides_diagonally_until_something_stops_it() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var cat := _place(pieces, Minion.of_kind(Minion.CAT, MINE, MIDDLE))

	var open_lines: Array[Vector2i] = [
		Vector2i(5, 5), Vector2i(7, 5),
		Vector2i(5, 7), Vector2i(7, 7),
		Vector2i(8, 8), Vector2i(9, 9), Vector2i(10, 10),
		Vector2i(11, 11), Vector2i(12, 12),
	]
	_cells_are(board, pieces, cat, false, open_lines,
		"a Cat rides its diagonals: stopped by the building north-west, by the hole"
		+ " north-east and by the unclimbable face south-west, and running to the"
		+ " board's corner south-east across the step at (8,8)")
	_cells_are(board, pieces, cat, true, [],
		"a Cat with nobody on its lines captures nothing")

	# An enemy out along the one open line: the ride ends on it, and the cells
	# beyond it are gone from both lists.
	var far := PieceMap.new()
	var blocked_cat := _place(far, Minion.of_kind(Minion.CAT, MINE, MIDDLE))
	_place(far, Minion.of_kind(Minion.ENT, THEIRS, Vector2i(9, 9)))
	_cells_are(board, far, blocked_cat, false,
		[Vector2i(5, 5), Vector2i(7, 5), Vector2i(5, 7), Vector2i(7, 7), Vector2i(8, 8)],
		"a Cat's ride ends before an enemy, not on it")
	_cells_are(board, far, blocked_cat, true, [Vector2i(9, 9)],
		"a Cat captures the piece its ride ended before, and nothing behind it")

	# Broken: fill in the hole to the north-east. The same expected move list must
	# no longer hold, because the line now carries on past (8,4).
	var filled := _board_with(Vector2i(8, 4), BoardFixture.PLAIN)
	_breaks(filled, pieces, cat, false, open_lines,
		"a Cat must be stopped by a hole")

	# Broken the other way: take the building away and the north-west line runs on.
	var cleared := _board_with(Vector2i(4, 4), BoardFixture.PLAIN)
	_breaks(cleared, pieces, cat, false, open_lines,
		"a Cat must be stopped by an obstacle")

	# Broken again: lower the face to a height a piece can climb.
	var lowered := _board_with(Vector2i(4, 8), BoardFixture.PLAIN)
	_breaks(lowered, pieces, cat, false, open_lines,
		"a Cat must be stopped by ground it cannot climb")


## Cardinal lines until blocked. Two Ents, because the fixture's obstacle and its
## hole are not on the same row.
func _the_ent_slides_cardinally_until_something_stops_it() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var ent := _place(pieces, Minion.of_kind(Minion.ENT, MINE, Vector2i(4, 6)))

	var lines: Array[Vector2i] = [
		Vector2i(4, 5),
		Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6),
		Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
		Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6),
		Vector2i(4, 7),
	]
	_cells_are(board, pieces, ent, false, lines,
		"an Ent rides its cardinals: one cell north to the building, one south to"
		+ " the face it cannot climb, and out to both edges east and west")

	var over_the_hole := PieceMap.new()
	var second := _place(over_the_hole, Minion.of_kind(Minion.ENT, MINE, Vector2i(8, 6)))
	_cells_are(board, over_the_hole, second, false, [
		Vector2i(8, 5),
		Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6),
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6),
		Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6),
		Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10),
		Vector2i(8, 11), Vector2i(8, 12),
	], "an Ent is stopped north by the hole and rides south across the step at (8,8)")

	# Broken: one of our own minions three cells west cuts the line short.
	var friend_in_the_way := PieceMap.new()
	var third := _place(friend_in_the_way, Minion.of_kind(Minion.ENT, MINE, Vector2i(4, 6)))
	_place(friend_in_the_way, Minion.of_kind(Minion.TOADSTOOL, MINE, Vector2i(1, 6)))
	_breaks(board, friend_in_the_way, third, false, lines,
		"an Ent must be stopped by a piece of its own side")


## An L-hop, with everything in between ignored -- blockers, holes and pieces
## alike -- and a landing that must still be somewhere a piece can stand.
func _the_frog_hops_over_everything_in_between() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var frog := _place(pieces, Minion.of_kind(Minion.FROG, MINE, MIDDLE))

	_cells_are(board, pieces, frog, false, [
		Vector2i(5, 4), Vector2i(7, 4),
		Vector2i(4, 5), Vector2i(8, 5),
		Vector2i(4, 7), Vector2i(8, 7),
		Vector2i(5, 8), Vector2i(7, 8),
	], "a Frog in the open reaches all eight of its L-hops")

	# The chasm runs right across row 1, so nothing that walks or rides can reach
	# row 0 from row 2. Three minions on the same cell say so, and the Frog is
	# over it: two of its landings are on the far side.
	var across := PieceMap.new()
	var leaper := _place(across, Minion.of_kind(Minion.FROG, MINE, Vector2i(5, 2)))
	_cells_are(board, across, leaper, false, [
		Vector2i(4, 0), Vector2i(6, 0),
		Vector2i(3, 3), Vector2i(7, 3),
		Vector2i(6, 4),
	], "a Frog crosses the chasm and the building alike, and does not land in either")

	for kind in [Minion.CAT, Minion.ENT, Minion.TOADSTOOL]:
		var grounded := PieceMap.new()
		var walker := _place(grounded, Minion.of_kind(kind, MINE, Vector2i(5, 2)))
		var beyond := 0
		for cell in LegalMoves.destinations(board, grounded, walker):
			if cell.y < 1:
				beyond += 1
		equal(beyond, 0, "a %s cannot cross the chasm at all" % kind)

	# Broken: fill the two cells the Frog was landing on beyond the chasm with
	# holes. It crosses what is in between, but it still has to land.
	var no_landing := _board_patched({
		Vector2i(4, 0): BoardFixture.CHASM, Vector2i(6, 0): BoardFixture.CHASM,
	})
	_breaks(no_landing, across, leaper, false, [
		Vector2i(4, 0), Vector2i(6, 0),
		Vector2i(3, 3), Vector2i(7, 3),
		Vector2i(6, 4),
	], "a Frog must still land somewhere a piece can stand")


## The ground at (4,8) stands four units above everything beside it, and the
## board lets a piece climb three. So nothing reaches it: not the Toadstool
## standing against it, not the Frog whose L-hop lands on it, and not the
## commander beside it -- and the piece standing *on* it cannot get down either,
## because the way down is a fall of four and a piece may drop two.
##
## The reach rule is the terrain query's own walking constants, so this is the
## same fact as "a walker cannot climb that", checked on pieces.
func _nothing_climbs_more_than_the_boards_step() -> void:
	var board := _board()
	var wall := Vector2i(4, 8)
	check(board.is_standable(wall), "there is ground on top of the wall of earth")

	var beside := PieceMap.new()
	var toadstool := _place(beside, Minion.of_kind(Minion.TOADSTOOL, MINE, Vector2i(4, 7)))
	_cells_are(board, beside, toadstool, false,
		[Vector2i(4, 6), Vector2i(3, 7), Vector2i(5, 7)],
		"a Toadstool against the wall of earth walks the other three ways and not up it")

	var leaping := PieceMap.new()
	var frog := _place(leaping, Minion.of_kind(Minion.FROG, MINE, Vector2i(6, 7)))
	_cells_are(board, leaping, frog, false, [
		Vector2i(5, 5), Vector2i(7, 5), Vector2i(4, 6), Vector2i(8, 6),
		Vector2i(8, 8), Vector2i(5, 9), Vector2i(7, 9),
	], "a Frog reaches seven of its eight L-hops from (6,7): the eighth lands on"
		+ " top of the wall of earth, which it cannot climb even by leaping")

	var gear := PieceMap.new()
	var commander := _stand(gear, _fully_armoured(Vector2i(4, 7)))
	for cell in LegalMoves.destinations(board, gear, commander):
		not_equal(cell, wall,
			"no grant a commander wears reaches ground it cannot climb")

	var above := PieceMap.new()
	var stranded := _place(above, Minion.of_kind(Minion.TOADSTOOL, MINE, wall))
	_cells_are(board, above, stranded, false, [],
		"and a piece on top of the wall of earth cannot get down: the drop is four"
		+ " and a piece may fall two")

	# Broken: level the ground, and every one of those lists changes at once.
	var levelled := _board_with(wall, BoardFixture.PLAIN)
	_breaks(levelled, beside, toadstool, false,
		[Vector2i(4, 6), Vector2i(3, 7), Vector2i(5, 7)],
		"a piece must be stopped by ground higher than the board's step")
	_breaks(levelled, above, stranded, false, [],
		"a piece must be stopped by a drop deeper than the board's reach")


## Nothing a minion carries takes part in working out its moves. It has no
## facing, and two minions of a kind on a cell with the same board and the same
## neighbours have the same answer whoever owns them.
func _a_minion_has_no_facing_and_no_state_of_its_own() -> void:
	var board := _board()
	for kind in Minion.KINDS:
		var minion := Minion.of_kind(kind, MINE, MIDDLE)
		check(not minion.has_facing(), "a %s has no facing" % kind)
		check(not minion.is_commander(), "a %s is not a commander" % kind)
		var named := PackedStringArray()
		for property in minion.get_property_list():
			named.append(property["name"])
		check(not named.has("facing"),
			"a %s must not carry a facing at all, not even an unused one" % kind)

		var ours := PieceMap.new()
		var theirs := PieceMap.new()
		var one := _place(ours, Minion.of_kind(kind, MINE, MIDDLE))
		var other := _place(theirs, Minion.of_kind(kind, THEIRS, MIDDLE))
		equal(LegalMoves.moves_for(board, ours, one),
			LegalMoves.moves_for(board, theirs, other),
			"a %s's moves depend on the board and not on whose it is" % kind)


## Ringed by enemies, the three that walk and ride are stuck and can only take
## what is beside them; the Frog steps over the ring untouched. One occupancy,
## four exact answers.
func _surrounded_only_the_frog_gets_out() -> void:
	var board := _board()
	var ring: Array[Vector2i] = [
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(5, 6), Vector2i(7, 6),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
	]
	var expected_moves := {
		Minion.TOADSTOOL: [],
		Minion.CAT: [],
		Minion.ENT: [],
		Minion.FROG: [
			Vector2i(5, 4), Vector2i(7, 4), Vector2i(4, 5), Vector2i(8, 5),
			Vector2i(4, 7), Vector2i(8, 7), Vector2i(5, 8), Vector2i(7, 8),
		],
	}
	var expected_captures := {
		Minion.TOADSTOOL: [Vector2i(5, 5), Vector2i(7, 5), Vector2i(5, 7), Vector2i(7, 7)],
		Minion.CAT: [Vector2i(5, 5), Vector2i(7, 5), Vector2i(5, 7), Vector2i(7, 7)],
		Minion.ENT: [Vector2i(6, 5), Vector2i(5, 6), Vector2i(7, 6), Vector2i(6, 7)],
		Minion.FROG: [],
	}
	for kind in Minion.KINDS:
		var pieces := PieceMap.new()
		var minion := _place(pieces, Minion.of_kind(kind, MINE, MIDDLE))
		for at in ring:
			_place(pieces, Minion.of_kind(Minion.TOADSTOOL, THEIRS, at))
		var wanted_moves: Array = expected_moves[kind]
		var wanted_captures: Array = expected_captures[kind]
		_cells_are(board, pieces, minion, false, wanted_moves,
			"ringed by enemies, a %s moves exactly here" % kind)
		_cells_are(board, pieces, minion, true, wanted_captures,
			"ringed by enemies, a %s captures exactly here" % kind)


# --- The commander --------------------------------------------------------

## Before any armour, a commander is one cardinal step -- and it captures by
## nothing at all, because a commander kills with a weapon.
func _a_commander_moves_one_cardinal_step_before_any_armour() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var commander := _place(pieces, Commander.make(MIDDLE))

	_cells_are(board, pieces, commander, false,
		[Vector2i(6, 5), Vector2i(5, 6), Vector2i(7, 6), Vector2i(6, 7)],
		"a bare commander moves one cardinal step")
	_cells_are(board, pieces, commander, true, [],
		"a commander never captures by moving onto a piece")
	check(commander.has_facing(), "a commander has a facing")
	check(commander.is_commander(), "a commander is a commander")


## Each piece of armour adds one movement capability, and the commander's
## pattern is the union. Written out slot by slot, and each one taken off again.
func _each_piece_of_armour_adds_a_way_of_moving() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var commander := _stand(pieces, Commander.make(MIDDLE))
	var bare: Array[Vector2i] = [
		Vector2i(6, 5), Vector2i(5, 6), Vector2i(7, 6), Vector2i(6, 7),
	]

	commander.equip(Armour.boots())
	_cells_are(board, pieces, commander, false, [
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(5, 6), Vector2i(7, 6),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
	], "boots add the diagonal, so base and boots is a king")

	# Broken: take the boots off, and the king's pattern must stop holding.
	commander.unequip(Armour.BOOTS)
	_cells_are(board, pieces, commander, false, bare,
		"with the boots off, the commander is one cardinal step again")

	commander.equip(Armour.leggings())
	_cells_are(board, pieces, commander, false, [
		Vector2i(5, 4), Vector2i(7, 4),
		Vector2i(4, 5), Vector2i(6, 5), Vector2i(8, 5),
		Vector2i(5, 6), Vector2i(7, 6),
		Vector2i(4, 7), Vector2i(6, 7), Vector2i(8, 7),
		Vector2i(5, 8), Vector2i(7, 8),
	], "leggings add the knight's hop")
	commander.unequip(Armour.LEGGINGS)

	# A chestplate whose movement axis pays for two cells is a queen of two, and
	# it is stopped by the same three things a Cat and an Ent are stopped by.
	commander.equip(Armour.chestplate())
	_cells_are(board, pieces, commander, false, [
		Vector2i(6, 4),
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(7, 6), Vector2i(8, 6),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
		Vector2i(6, 8), Vector2i(8, 8),
	], "a high-tier chestplate is a queen of two cells, stopped by the building,"
		+ " the hole and the face it cannot climb")

	# Broken: a chestplate off a level-1 creature has four points to its whole
	# name and one cell of queen costs eight, so it grants nothing at all.
	var poor := Armour.chestplate(1)
	commander.equip(poor)
	_cells_are(board, pieces, commander, false, bare,
		"a chestplate that cannot pay for a cell grants no movement")
	equal(poor.item.budget(), 4, "because its whole budget is four points")
	equal(poor.grant_for(poor.item.level), null,
		"so it carries no movement grant to give")
	equal(poor.defence_for(poor.item.level), 4,
		"and every one of those points went to taking blows instead")

	# And a slot that never grants movement leaves the pattern alone.
	commander.equip(Armour.helmet())
	_cells_are(board, pieces, commander, false, bare,
		"a helmet adds no movement")
	equal(commander.armour.size(), 2, "the commander is wearing two things")


## A movement grant is bought by the cell, out of the item's movement axis.
##
## One point buys one cell a grant may reach, so the diagonal step costs four
## (four offsets, one cell each), the knight's hop costs eight, and a queen-like
## slide costs eight per cell of reach. There is no tier anywhere: what decides
## whether a chestplate slides is whether its budget covered the bill.
func _a_grant_is_bought_by_the_cell() -> void:
	var board := _board()
	equal([
		Armour.price(PieceGeometry.DIAGONALS.size(), 1),
		Armour.price(PieceGeometry.KNIGHT_HOPS.size(), 1),
		Armour.price(PieceGeometry.ALL_DIRECTIONS.size(), 2),
	], [4, 8, 16], "the three prices are the cells each grant reaches")

	# The chestplate ladder, written out. A common item is worth four points per
	# level of the creature it came off, so these are levels 1, 2, 4 and 8.
	var ladder := PackedStringArray()
	for level in [1, 2, 4, 8]:
		var piece := Armour.chestplate(level)
		var score := piece.item.level
		ladder.append("P=%d mov=%d def=%d reach=%d" % [
			piece.item.budget(), piece.movement_for(score),
			piece.defence_for(score), piece.reach_for(score),
		])
	equal(ladder, PackedStringArray([
		"P=4 mov=0 def=4 reach=0",
		"P=8 mov=8 def=0 reach=1",
		"P=16 mov=16 def=0 reach=2",
		"P=32 mov=16 def=16 reach=2",
	]), "a chestplate slides one cell per eight points, and never past two")

	# Nothing is spent on a capability the budget cannot buy outright. Leggings
	# off a level-1 creature have four points and the hop costs eight, so they
	# keep all four and are armour.
	var short := Armour.leggings(1)
	equal([short.movement_for(1), short.defence_for(1)], [0, 4],
		"leggings that cannot afford the hop spend nothing on trying")
	equal(short.grant_for(1), null, "and grant nothing")
	var bought := Armour.leggings(2)
	equal([bought.movement_for(2), bought.defence_for(2)], [8, 0],
		"twice the budget pays the whole eight, and there is nothing left over")
	check(bought.grant_for(2) != null, "and that is the hop")

	# And the reach is cells on a board, not a number in a table. The same
	# commander, wearing the level-2 and then the level-4 chestplate.
	var pieces := PieceMap.new()
	var commander := _stand(pieces, Commander.make(MIDDLE))
	commander.equip(Armour.chestplate(2))
	_cells_are(board, pieces, commander, false, [
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(5, 6), Vector2i(7, 6),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
	], "eight points of movement is a king-like slide of one cell")

	# Broken: eight more points, and the same slide reaches a second cell.
	commander.equip(Armour.chestplate(4))
	_cells_are(board, pieces, commander, false, [
		Vector2i(6, 4),
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(7, 6), Vector2i(8, 6),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
		Vector2i(6, 8), Vector2i(8, 8),
	], "sixteen points is the two-cell queen, stopped by the building, the hole"
		+ " and the face it cannot climb")

	# The trade the budget makes, at one budget and one level: the same thirty-two
	# points either buy the queen or buy defence, and never both.
	var mobile := Armour.worn(Armour.CHESTPLATE, 8, ItemRarity.COMMON, 32)
	var solid := Armour.worn(Armour.CHESTPLATE, 8, ItemRarity.COMMON, 0)
	equal([mobile.item.budget(), solid.item.budget()], [32, 32],
		"two chestplates off the same level-8 creature, both worth thirty-two")
	equal([mobile.reach_for(8), mobile.defence_for(8)], [2, 0],
		"all of it on moving is two cells of queen and nothing that stops a blow")
	equal([solid.reach_for(8), solid.defence_for(8)], [0, 32],
		"none of it on moving is thirty-two points of armour and no slide at all")


## The ability-score gate reaches what a commander may do, not only what an item
## table says it is worth.
##
## One object, three wearers. A chestplate off a level-8 creature with sixteen
## points on its movement axis is a two-cell queen to somebody with CON 8, a
## one-cell king-slide to somebody with CON 6, and armour that grants nothing to
## somebody with CON 3 -- and the item is not changed by being read.
func _an_under_qualified_wearer_reaches_less() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var commander := _stand(pieces, Commander.make(MIDDLE))
	var plate := Armour.chestplate(8)
	commander.equip(plate)
	equal([plate.item.level, plate.item.governing], [8, Ability.CON],
		"the chestplate is a level-8 item read against CON")

	var read := PackedStringArray()
	for score in [8, 6, 3, 0]:
		commander.set_score(Ability.CON, score)
		read.append("CON %d: mov=%d reach=%d cells=%d" % [
			score, plate.movement_for(score), plate.reach_for(score),
			LegalMoves.destinations(board, pieces, commander).size(),
		])
	equal(read, PackedStringArray([
		"CON 8: mov=16 reach=2 cells=13",
		"CON 6: mov=12 reach=1 cells=8",
		"CON 3: mov=6 reach=0 cells=4",
		"CON 0: mov=0 reach=0 cells=4",
	]), "the same chestplate is a queen, a king and nothing, by who is wearing it")

	# Broken: the item itself never moved. Read it in full again and the two-cell
	# queen is back, off the same object.
	commander.set_score(Ability.CON, 8)
	equal(LegalMoves.destinations(board, pieces, commander).size(), 13,
		"and the object is unchanged by having been read short")
	equal(plate.item.movement, 16, "its movement axis is the sixteen it always was")


## Everything on at once: a king, a knight and a two-cell queen unioned into one
## piece. Twenty-one cells, in a shape chess has no name for.
func _the_full_loadout_is_a_piece_that_is_not_in_chess() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var commander := _stand(pieces, _fully_armoured(MIDDLE))

	_cells_are(board, pieces, commander, false, [
		Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
		Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(7, 6), Vector2i(8, 6),
		Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7),
		Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8),
	], "boots, leggings and a high-tier chestplate union into a twenty-one cell piece")

	equal(commander.move_grants().size(), 4,
		"the union is the base step and one grant from each of the three")
	var by_source := PackedStringArray()
	for grant in commander.move_grants():
		by_source.append("%s:%s" % [grant.source, grant.mode_name()])
	equal(by_source, PackedStringArray([
		"base:land", "boots:land", "chestplate:slide", "leggings:land",
	]), "one grant per source, and both kinds of grant are in use")


## The task's stop condition, asked rather than assumed: does the biggest loadout
## in the game reach everywhere a piece can stand?
func _the_loadout_does_not_reach_the_whole_board() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var commander := _stand(pieces, _fully_armoured(MIDDLE))
	var reach := LegalMoves.destinations(board, pieces, commander).size()
	equal(reach, 21, "the fullest loadout reaches twenty-one cells")
	check(not LegalMoves.reaches_every_standable_cell(board, pieces, commander),
		"the fullest loadout must not reach every standable cell: %d of %d" % [
			reach, board.standable_count(),
		])


# --- Weapons, attacks and facing ------------------------------------------

## An attack is a pattern of cells and a number of turns, and the cells are laid
## out from wherever the attacker stands.
func _an_attack_is_a_pattern_of_cells_and_a_cooldown() -> void:
	var board := _board()
	var commander := Commander.make(MIDDLE, PieceGeometry.NORTH)
	commander.wield(Weapon.spear())

	equal(commander.attack_count(), 1, "a spear carries one attack")
	equal(commander.attack_at(0).attack_name, "thrust", "and it is the thrust")
	equal(commander.attack_at(0).cooldown, 1, "which is usable every turn")
	equal(commander.attack_cells(0), [Vector2i(6, 4), Vector2i(6, 5)] as Array[Vector2i],
		"a spear reaches the two cells straight ahead")
	equal(LegalMoves.attack_cells_on(board, commander, 0),
		[Vector2i(6, 4), Vector2i(6, 5)] as Array[Vector2i],
		"and both of them are on the board")

	# A weapon may carry more than one attack, and the heavier one waits longer.
	commander.wield(Weapon.sword())
	equal(commander.attack_count(), 2, "a sword carries two attacks")
	equal(commander.attack_cells(0),
		[Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)] as Array[Vector2i],
		"the sword's cut is the front and the two cells beside it")
	equal(commander.attack_cells(1), [
		Vector2i(4, 4), Vector2i(6, 4), Vector2i(8, 4),
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
	] as Array[Vector2i], "the sword's cleave is the same arc, two cells out")
	check(commander.attack_at(1).cooldown > commander.attack_at(0).cooldown,
		"the wider attack of a weapon waits longer than the narrower one")

	# The pattern is not filtered by what is standing there or what the ground
	# is: (4,4) is a building and (8,4) is a hole, and both are in the cleave.
	check(not board.is_standable(Vector2i(4, 4)) and not board.is_standable(Vector2i(8, 4)),
		"the cleave covers a building and a hole, because an attack is a pattern of"
		+ " cells and not a list of places to stand")


## Every one of the design's examples is the same three generators and a number.
## No branch anywhere in the layer asks which weapon it is holding.
func _the_five_examples_are_expressible_the_same_way() -> void:
	var board := _board()
	var commander := Commander.make(MIDDLE, PieceGeometry.NORTH)

	commander.wield(Weapon.dagger())
	equal(commander.attack_cells(0), [Vector2i(5, 5), Vector2i(7, 5)] as Array[Vector2i],
		"a dagger reaches the two cells off the front corners")

	commander.wield(Weapon.bow())
	equal(commander.attack_at(0).cell_count(), 248,
		"a bow's ring at five to ten cells covers 248 cells")
	equal(LegalMoves.attack_cells_on(board, commander, 0).size(), 100,
		"100 of them are on this board from the middle of it")
	var ring := commander.attack_cells(0)
	check(ring.has(Vector2i(6, 1)), "the ring reaches five cells ahead")
	check(not ring.has(Vector2i(6, 2)), "and not four, which is inside it")
	check(ring.has(Vector2i(6, 11)), "and five cells behind, because a ring has no front")

	commander.wield(Weapon.staff())
	equal(commander.attack_cells(0), [
		Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1),
		Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2),
		Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
	] as Array[Vector2i], "an area attack is a three-by-three block four cells ahead")
	equal(commander.attack_at(0).cooldown, 5,
		"and the widest attack in the catalogue waits the longest")

	commander.wield(Weapon.flail())
	equal(commander.attack_cells(0), [
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(5, 6), Vector2i(7, 6),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
	] as Array[Vector2i], "a flail reaches every cell touching its wielder")

	# Two of the six have a front and four do not, and that is a fact about the
	# pattern rather than a flag anybody set.
	var fronted := PackedStringArray()
	for weapon in Weapon.catalogue():
		for attack in weapon.attacks:
			if not attack.is_symmetric():
				fronted.append("%s/%s" % [weapon.weapon_name, attack.attack_name])
	equal(fronted, PackedStringArray([
		"spear/thrust", "dagger/stab", "sword/cut", "sword/cleave", "staff/fireball",
		"shield/shove",
	]), "the bow and the flail are the symmetric ones; everything else has a front")


## The pattern turns with the commander. An attack aimed at the front is not
## available to the back without turning, and a symmetric one does not care.
func _an_attack_rotates_with_the_commander() -> void:
	var commander := Commander.make(MIDDLE, PieceGeometry.NORTH)
	commander.wield(Weapon.spear())
	var ahead: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 5)]
	var behind: Array[Vector2i] = [Vector2i(6, 7), Vector2i(6, 8)]

	equal(commander.attack_cells(0), ahead, "facing north, the spear reaches north")
	for cell in behind:
		check(not commander.attack_cells(0).has(cell),
			"facing north, the spear reaches nothing behind at (%d,%d)" % [cell.x, cell.y])

	commander.face(PieceGeometry.EAST)
	equal(commander.attack_cells(0),
		[Vector2i(7, 6), Vector2i(8, 6)] as Array[Vector2i],
		"turned east, the spear reaches east")
	commander.face(PieceGeometry.SOUTH)
	equal(commander.attack_cells(0), behind, "turned about, the spear reaches behind")
	commander.face(PieceGeometry.WEST)
	equal(commander.attack_cells(0),
		[Vector2i(4, 6), Vector2i(5, 6)] as Array[Vector2i],
		"turned west, the spear reaches west")

	# Broken: without turning, the rearward cells are simply not in the pattern.
	commander.face(PieceGeometry.NORTH)
	not_equal(commander.attack_cells(0), behind,
		"an attack aimed at the front must not be available to the back without turning")

	# A ring rotates onto itself, by the same rotation and with no case of its own.
	commander.wield(Weapon.bow())
	var north := commander.attack_cells(0)
	for direction in [PieceGeometry.EAST, PieceGeometry.SOUTH, PieceGeometry.WEST]:
		commander.face(direction)
		equal(commander.attack_cells(0), north,
			"a bow's ring covers the same cells whichever way its wielder looks")


## Turning is free: it takes no turn and no action, and it cannot, because it
## touches nothing a turn or an action is counted in.
func _turning_costs_nothing() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var commander := _stand(pieces, Commander.make(MIDDLE))
	commander.wield(Weapon.sword())
	commander.equip(Armour.boots())

	var turn := Commander.FIRST_TURN
	check(commander.spend_attack(1, turn), "the cleave is used on turn 1")
	var before := commander.readiness_line(turn)
	var moves_before := LegalMoves.moves_for(board, pieces, commander)
	var where := commander.cell

	for direction in [PieceGeometry.EAST, PieceGeometry.SOUTH, PieceGeometry.WEST,
			PieceGeometry.NORTH, PieceGeometry.EAST]:
		commander.face(direction)
	commander.turn_by(3)

	equal(commander.readiness_line(turn), before,
		"turning six times changes no cooldown")
	equal(commander.readiness_line(turn), "cut:0 cleave:3",
		"and the cleave is still three turns from ready, as it was before")
	equal(commander.cell, where, "turning does not move the commander")
	equal(LegalMoves.moves_for(board, pieces, commander), moves_before,
		"a commander's movement does not turn with it -- armour is not aimed")
	check(commander.can_attack(0, turn),
		"and an attack that was ready before the turning is ready after it")


## A cooldown is counted in turns, and it is asked about rather than ticked.
func _a_cooldown_is_counted_in_turns() -> void:
	var commander := Commander.make(MIDDLE)
	commander.wield(Weapon.sword())
	var turn := Commander.FIRST_TURN

	check(commander.can_attack(0, turn), "the cut is ready on the first turn")
	check(commander.can_attack(1, turn), "so is the cleave")
	check(commander.spend_attack(1, turn), "the cleave is used")

	equal(commander.turns_until_ready(1, turn), 3, "and is three turns from ready")
	check(not commander.can_attack(1, turn), "so it is not available again this turn")
	check(not commander.spend_attack(1, turn), "and using it again does nothing")
	check(commander.can_attack(0, turn),
		"the cut is on its own cooldown and is still available")
	equal(commander.attack_cells(1, turn), [] as Array[Vector2i],
		"an attack on cooldown covers no cells on the turn it is asked about")

	# Broken: one turn short, it is still not ready. The pair to the line below.
	check(not commander.can_attack(1, turn + 2),
		"a three-turn cooldown is not up two turns later")
	equal(commander.turns_until_ready(1, turn + 2), 1, "one turn is still to run")
	check(commander.can_attack(1, turn + 3), "and on the third turn it is ready")
	equal(commander.turns_until_ready(1, turn + 3), 0, "with nothing left to run")

	# The stronger attack waits longer, inside every weapon that has more than one.
	for weapon in Weapon.catalogue():
		for index in range(1, weapon.attack_count()):
			var wider := weapon.attack_at(index).cell_count() \
				> weapon.attack_at(index - 1).cell_count()
			if wider:
				check(weapon.attack_at(index).cooldown
						> weapon.attack_at(index - 1).cooldown,
					"%s's wider attack must wait longer" % weapon.weapon_name)


# --- The king rule --------------------------------------------------------

## A commander's death despawns every minion it owns, in the same step, and
## leaves everybody else's alone.
func _a_commanders_death_takes_its_minions_with_it() -> void:
	var pieces := PieceMap.new()
	var mine := _stand(pieces, Commander.make(Vector2i(2, 2)))
	var theirs := _stand(pieces, Commander.make(Vector2i(10, 10)))
	var ours: Array[int] = []
	for at in [Vector2i(2, 3), Vector2i(3, 2), Vector2i(2, 4)]:
		ours.append(_place(pieces, Minion.of_kind(Minion.CAT, mine.id, at)).id)
	var others: Array[int] = []
	for at in [Vector2i(10, 9), Vector2i(9, 10)]:
		others.append(_place(pieces, Minion.of_kind(Minion.ENT, theirs.id, at)).id)

	equal(pieces.size(), 7, "seven pieces before anybody dies")
	equal(pieces.minions_of(mine.id).size(), 3, "three of them are this commander's minions")

	var removed := pieces.kill(mine.id)
	var expected := PackedInt32Array()
	expected.append(mine.id)
	for id in ours:
		expected.append(id)
	expected.sort()
	equal(removed, expected,
		"the commander and all three of its minions are removed by the one call")

	equal(pieces.size(), 3, "and only the other side is left standing")
	for id in ours:
		equal(pieces.piece_of(id), null, "minion #%d is gone" % id)
	for at in [Vector2i(2, 3), Vector2i(3, 2), Vector2i(2, 4)]:
		equal(pieces.piece_at(at), null,
			"and its cell (%d,%d) is empty in the same step" % [at.x, at.y])
	for id in others:
		check(pieces.piece_of(id) != null, "the other commander's minion #%d still stands" % id)

	# Broken: kill a minion instead, and the rest of the army must not fall over.
	var one_of_theirs: int = others[0]
	equal(pieces.kill(one_of_theirs), PackedInt32Array([one_of_theirs]),
		"killing a minion removes that minion and nothing else")
	equal(pieces.size(), 2, "the other commander and its second minion are still there")
	check(pieces.piece_of(theirs.id) != null, "a minion's death is not its commander's")


# --- Determinism, and the real world --------------------------------------

## Nothing here accumulates and nothing here is ordered by chance: the same
## board and the same occupancy give the same lists, whatever order the pieces
## were put down in and however many times they are asked.
func _the_layer_is_deterministic() -> void:
	var board := _board()
	var placings: Array[Vector2i] = [
		Vector2i(6, 6), Vector2i(3, 3), Vector2i(9, 9), Vector2i(2, 6), Vector2i(10, 6),
	]
	var forwards := PieceMap.new()
	var backwards := PieceMap.new()
	for at in placings:
		_place(forwards, Minion.of_kind(Minion.CAT, MINE, at))
	var reversed := placings.duplicate()
	reversed.reverse()
	for at in reversed:
		_place(backwards, Minion.of_kind(Minion.CAT, MINE, at))

	for at in placings:
		var one := forwards.piece_at(at)
		var other := backwards.piece_at(at)
		var first := LegalMoves.destinations(board, forwards, one)
		equal(first, LegalMoves.destinations(board, forwards, one),
			"asking twice gives the same answer at (%d,%d)" % [at.x, at.y])
		equal(first, LegalMoves.destinations(board, backwards, other),
			"the order the pieces were put down in does not change the answer at (%d,%d)"
				% [at.x, at.y])

	# The same board built twice is the same board, character for character.
	equal(_board().digest(), _board().digest(), "the fixture is the same board every time")


## The layer is checked on typed-out ground because that is where an exact list
## can be written down. It has to work on the ground the game generates too, so
## one board is read off the real world and walked over.
func _the_pieces_stand_on_the_generated_world_too() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var builder := CombatBoardBuilder.new(terrain)
	var board := builder.build_on_top(0.0, 0.0)
	var found := _somewhere_standable(board)
	check(not found.is_empty(),
		"expected somewhere to stand on a board read off seed %d" % SEED)
	if found.is_empty():
		return

	var at := found[0]
	for kind in Minion.KINDS:
		var pieces := PieceMap.new()
		var minion := _place(pieces, Minion.of_kind(kind, MINE, at))
		for cell in LegalMoves.destinations(board, pieces, minion):
			check(board.contains(cell),
				"a %s on the generated world stays on the board" % kind)
			check(board.is_standable(cell),
				"a %s on the generated world only moves onto standable ground" % kind)
			check(not board.is_hole(cell), "a %s never moves into a hole" % kind)

	var army := PieceMap.new()
	var commander := _stand(army, _fully_armoured(at))
	for cell in LegalMoves.destinations(board, army, commander):
		check(board.is_standable(cell),
			"a fully armoured commander on the generated world stays on solid ground")
	check(not LegalMoves.reaches_every_standable_cell(board, army, commander),
		"the fullest loadout does not reach the whole of a generated board either")


# --- Helpers --------------------------------------------------------------


func _board() -> CombatBoard:
	return BoardFixture.from_rows(PackedStringArray(MAP))


## The fixture with one cell changed. How a rule is broken: the map is edited,
## not the code, and the expected list is then checked to no longer hold.
func _board_with(cell: Vector2i, glyph: String) -> CombatBoard:
	return _board_patched({cell: glyph})


func _board_patched(edits: Dictionary) -> CombatBoard:
	var rows := PackedStringArray(MAP)
	for at in edits:
		var row: String = rows[at.y]
		rows[at.y] = row.substr(0, at.x) + str(edits[at]) + row.substr(at.x + 1)
	return BoardFixture.from_rows(rows)


func _place(pieces: PieceMap, piece: Piece) -> Piece:
	pieces.add(piece)
	return piece


## The same, for a commander, keeping its own type so that the checks below can
## ask it the things only a commander answers.
func _stand(pieces: PieceMap, commander: Commander) -> Commander:
	pieces.add(commander)
	return commander


func _fully_armoured(at: Vector2i) -> Commander:
	var commander := Commander.make(at)
	commander.equip(Armour.boots())
	commander.equip(Armour.leggings())
	commander.equip(Armour.chestplate())
	commander.wield(Weapon.sword())
	return commander


## An exact cell list, written out, compared in the one canonical order.
func _cells_are(
	board: CombatBoard, pieces: PieceMap, piece: Piece, taking: bool,
	expected: Array, message: String
) -> void:
	var typed: Array[Vector2i] = []
	for cell in expected:
		typed.append(cell)
	var wanted := PieceGeometry.canonical(typed)
	var got := LegalMoves.captures_for(board, pieces, piece) if taking \
		else LegalMoves.moves_for(board, pieces, piece)
	equal(PieceGeometry.pattern_text(got), PieceGeometry.pattern_text(wanted), message)


## The other half of every assertion above: with the rule's own premise broken,
## the same expected list must stop holding.
func _breaks(
	board: CombatBoard, pieces: PieceMap, piece: Piece, taking: bool,
	expected: Array, message: String
) -> void:
	var typed: Array[Vector2i] = []
	for cell in expected:
		typed.append(cell)
	var wanted := PieceGeometry.canonical(typed)
	var got := LegalMoves.captures_for(board, pieces, piece) if taking \
		else LegalMoves.moves_for(board, pieces, piece)
	not_equal(PieceGeometry.pattern_text(got), PieceGeometry.pattern_text(wanted),
		"%s -- the check would have passed with the rule broken" % message)


## Somewhere on a generated board with room around it: a standable cell with
## every one of its neighbours standable too, so the checks above are about the
## pieces rather than about a corner.
func _somewhere_standable(board: CombatBoard) -> Array[Vector2i]:
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			if not board.is_standable(cell):
				continue
			var clear := true
			for step in CombatBoard.NEIGHBOURS:
				if not board.can_step(cell, cell + step):
					clear = false
					break
			if clear:
				return [cell] as Array[Vector2i]
	return [] as Array[Vector2i]
