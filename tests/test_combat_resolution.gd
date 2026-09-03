extends TestSuite
## The turn economy, the two-layer damage matrix, the shove, and N commanders.
##
## Every number below is written out. Nothing is compared to a figure the code
## under test produced, and nothing is compared to a count of something the code
## chose. Where a rule has a premise that can be broken from outside -- a level, a
## piece of armour, a facing, the ground under a cell -- the check is paired with
## a second run in which that premise is broken and the same number is required to
## stop holding. The rules whose premise is the code itself are broken by
## `tools/resolution_mutations.sh`, which edits one line of `sim/` at a time and
## requires this suite to notice.
##
## The board:
##
## ```
##  y=0   . . . . . . . . . . . . .
##  y=1   . . . . . . ~ ~ . . . . .     a chasm at (6,1) and (7,1)
##  y=2   . . . . . . . . . . . . .
##  y=3   . . . . , . . . . . . . .     a step down at (4,3): -2, the high-ground pair
##  y=4   . . . . . . . . . . . . .
##  y=5   . . . . . . . . . . . . .
##  y=6   . . . . . . . . . . . . .
##  y=7   . . . . . . . . . . . . .
##  y=8   . . . . . . . . . v v . .     a pit floor eight units down
##  y=9   . . . . . . . . v v v . .
##  y=10  . . . . . . . . . . . . .
##  y=11  . . . . . . . . . . . . .
##  y=12  . . . . . . . . . . . . .
## ```
class_name TestCombatResolution

const MAP := [
	".............",
	"......~~.....",
	".............",
	"....,........",
	".............",
	".............",
	".............",
	".............",
	".........vv..",
	"........vvv..",
	".............",
	".............",
	".............",
]

## A second board, for the shove of more than one cell: one feature per column on
## row 2, with plain ground on row 1 beyond every one of them. The Ent of the
## fourth case is a piece standing on plain ground at (11,2), not a glyph.
const SHOVE_MAP := [
	".............",
	".............",
	".~...#...v...",
	".............",
	".............",
	".............",
]

## The middle of the board.
const MIDDLE := Vector2i(6, 6)

## The two ends of the level gap the stop condition is about.
const LOW := 1
const HIGH := 40


func _init() -> void:
	suite_name = "combat resolution"


func run() -> void:
	_the_fixture_means_what_it_says()
	_a_round_is_one_turn_per_commander()
	_a_turn_buys_a_move_an_action_and_one_minion()
	_turning_is_still_free()
	_minion_against_minion_is_binary_and_level_blind()
	_defence_is_what_a_loadout_spent_on_it()
	_a_weapon_deals_what_its_budget_bought()
	_the_trade_between_moving_and_taking_a_blow()
	_an_under_qualified_wearer_is_worth_less()
	_minion_against_player_is_level_against_defence()
	_player_against_minion_is_weapon_against_level_scaled_stats()
	_player_against_player_is_weapon_against_defence()
	_all_player_facing_damage_goes_through_one_seam()
	_high_ground_flanking_and_backstab()
	_the_die_is_on_how_hard_a_blow_lands_never_on_whether()
	_the_die_never_inverts_the_positional_ladder()
	_the_die_is_a_function_of_the_blow_and_of_the_fight_seed()
	_no_die_reaches_the_minion_layer()
	_a_shove_is_an_attack_that_pushes()
	_a_shove_of_many_cells_is_the_rule_applied_once_per_cell()
	_a_shove_stopped_part_way_reports_where_it_stopped()
	_a_shove_obeys_facing_and_pattern_and_cooldown()
	_commanders_have_no_fixed_sides()
	_a_three_commander_match_runs_to_a_conclusion()
	_the_scripted_match_plays_the_same_way_every_time()
	_two_processes_play_the_same_match()
	_no_level_gap_breaks_the_two_layers()


# --- The fixture ----------------------------------------------------------


## The board's own constants are what the map means. If one of them moved, the
## checks below would quietly stop testing what they say they do.
func _the_fixture_means_what_it_says() -> void:
	equal(CombatBoard.STEP_DOWN, 2.0, "the deepest legal step is 2 world units")
	equal(CombatBoard.CLIFF_DROP, 2.0, "and a fall deeper than that is a cliff")
	equal(BoardSketch.PIT_FLOOR, -8.0, "the pit floor is 8 units down")
	check(-BoardSketch.PIT_FLOOR > CombatBoard.CLIFF_DROP,
		"which has to be deeper than a cliff, or nothing could be shoved into it")
	equal(BoardSketch.STEP_DOWN_HEIGHT, -2.0,
		"the step down is exactly the deepest legal step")
	equal(Damage.HIGH_GROUND_RISE, 1.0, "high ground starts at a rise of 1 unit")
	check(-BoardSketch.STEP_DOWN_HEIGHT >= Damage.HIGH_GROUND_RISE,
		"so a piece on plain ground stands on high ground over one on the step")

	var board := _board()
	check(board.is_hole(Vector2i(6, 1)), "(6,1) is a chasm")
	check(not board.is_standable(Vector2i(6, 1)), "and nothing stands in it")
	check(board.is_standable(Vector2i(8, 9)), "the pit floor is standable")
	check(board.is_cliff_edge(Vector2i(8, 8)), "(8,8) is a lip over the pit")
	check(board.is_cliff_edge(Vector2i(6, 2)), "(6,2) is a lip over the chasm")
	check(not board.can_step(Vector2i(8, 8), Vector2i(8, 9)),
		"and nobody walks down into the pit, which is what makes it a shove")


# --- The turn economy -----------------------------------------------------


## One round is one turn per commander, for two, three and five of them.
##
## The order and the round number are written out in full for each. Nothing in
## the match counts to two, so the five-commander case is the same code path as
## the two-commander one -- which is the whole of section 3.8's "generalizes to N
## players" and is why it is checked by playing it rather than asserted.
func _a_round_is_one_turn_per_commander() -> void:
	for count in [2, 3, 5]:
		var pieces := PieceMap.new()
		var ids := PackedInt32Array()
		for index in count:
			ids.append(pieces.add(Commander.make(Vector2i(2 + index * 2, 6))))
		var played := CombatMatch.start(_board(), pieces)

		# Two whole rounds, written down as they must come out.
		var seen := PackedInt32Array()
		var rounds := PackedInt32Array()
		for _turn in count * 2:
			seen.append(played.active_id())
			rounds.append(played.round_number)
			played.end_turn()

		var wanted := PackedInt32Array()
		var wanted_rounds := PackedInt32Array()
		for pass_number in 2:
			for id in ids:
				wanted.append(id)
				wanted_rounds.append(pass_number + 1)
		equal(seen, wanted,
			"%d commanders should take one turn each per round, in id order" % count)
		equal(rounds, wanted_rounds,
			"and the round should advance exactly once per pass over %d" % count)
		equal(played.round_number, 3, "two rounds played leaves the third beginning")

		# A cooldown is counted in the same number: while every commander plays
		# every round, its own turn count and the round are one number.
		for id in ids:
			equal(played.turn_number(id), played.round_number,
				"a commander's turn number is the round, with %d playing" % count)


## A turn buys three things, each once. A second attempt at any of them is
## refused and changes nothing at all.
func _a_turn_buys_a_move_an_action_and_one_minion() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var mine := _commander(pieces, Vector2i(6, 6), 3, Weapon.sword(), [Armour.boots()])
	var theirs := _commander(pieces, Vector2i(2, 2), 3, Weapon.sword(), [Armour.boots()])
	var first := pieces.add(Minion.of_kind(Minion.TOADSTOOL, mine.id, Vector2i(8, 8), 3))
	var second := pieces.add(Minion.of_kind(Minion.TOADSTOOL, mine.id, Vector2i(8, 6), 3))
	var not_mine := pieces.add(
		Minion.of_kind(Minion.TOADSTOOL, theirs.id, Vector2i(3, 3), 3)
	)
	var played := CombatMatch.start(board, pieces)

	check(played.move_commander(Vector2i(6, 5)), "the commander moves once")
	equal(mine.cell, Vector2i(6, 5), "and is where it moved to")
	check(not played.move_commander(Vector2i(6, 4)), "a second move is refused")
	equal(mine.cell, Vector2i(6, 5), "and the commander has not moved again")

	# One weapon action. The sword's cut reaches nothing, and having swung at
	# nothing still spends the action -- which is the point of a pattern.
	var swung: Dictionary = played.attack(0)
	check(swung.get("ok", false), "the commander attacks once")
	equal((swung["hits"] as Array).size(), 0, "and its cut reaches nobody")
	var again: Dictionary = played.attack(1)
	check(not again.get("ok", false), "a second weapon action is refused")

	# One minion, and one only.
	var moved: Dictionary = played.activate_minion(first, Vector2i(8, 7))
	check(moved.get("ok", false), "one minion moves")
	equal(pieces.piece_of(first).cell, Vector2i(8, 7), "and it is where it moved to")
	var extra: Dictionary = played.activate_minion(second, Vector2i(8, 5))
	check(not extra.get("ok", false), "a second minion is refused")
	equal(pieces.piece_of(second).cell, Vector2i(8, 6),
		"and that second minion has not moved")

	# Somebody else's minion is not yours to activate, on your turn or any other.
	played.end_turn()
	played.end_turn()
	equal(played.active_id(), mine.id, "back round to the first commander")
	var stolen: Dictionary = played.activate_minion(not_mine, Vector2i(3, 4))
	check(not stolen.get("ok", false), "another commander's minion is refused")
	equal(pieces.piece_of(not_mine).cell, Vector2i(3, 3), "and has not moved")

	# Nor may a minion be sent somewhere its pattern does not reach. A Toadstool
	# walks one cardinal cell; four away is refused and nothing moves.
	var far: Dictionary = played.activate_minion(second, Vector2i(8, 2))
	check(not far.get("ok", false), "a minion may not be sent where it cannot go")
	equal(pieces.piece_of(second).cell, Vector2i(8, 6), "and has not moved")

	# Broken: with the same call made on the turn of the commander that owns it,
	# the refusal has to stop holding, or the check above proves nothing.
	played.end_turn()
	equal(played.active_id(), theirs.id, "it is now that commander's turn")
	var allowed: Dictionary = played.activate_minion(not_mine, Vector2i(3, 4))
	check(allowed.get("ok", false),
		"its owner may activate it -- the refusal above was about ownership")


## Turning is free, and the three flags are the whole budget, so it is checkable
## rather than merely asserted: a commander turns four times and still has all
## three of its actions.
func _turning_is_still_free() -> void:
	var pieces := PieceMap.new()
	var mine := _commander(pieces, MIDDLE, 3, Weapon.sword(), [Armour.boots()])
	pieces.add(Commander.make(Vector2i(2, 2)))
	var played := CombatMatch.start(_board(), pieces)

	for direction in [PieceGeometry.EAST, PieceGeometry.SOUTH, PieceGeometry.WEST,
			PieceGeometry.NORTH]:
		check(played.face(direction), "turning is always allowed")
	equal(mine.facing, PieceGeometry.NORTH, "four quarter turns is back where it started")
	check(played.move_commander(Vector2i(6, 5)), "and the move is still there")
	check(played.attack(0).get("ok", false), "and the weapon action is still there")


# --- The tactical layer ---------------------------------------------------


## Minion against minion is a capture, and neither level nor health touches it.
##
## The same two minions are run in both directions across a level gap of 39, and
## then again with the attacker at one hit point and the target at full. Four
## runs, one answer.
func _minion_against_minion_is_binary_and_level_blind() -> void:
	var gaps := [
		{"attacker": LOW, "target": HIGH, "as": "a level-1 Toadstool takes a level-40 Ent"},
		{"attacker": HIGH, "target": LOW, "as": "a level-40 Ent takes a level-1 Toadstool"},
	]
	for gap in gaps:
		var board := _board()
		var pieces := PieceMap.new()
		var attacker := pieces.add(
			Minion.of_kind(Minion.CAT, 101, Vector2i(6, 6), gap["attacker"])
		)
		var target := pieces.add(
			Minion.of_kind(Minion.ENT, 202, Vector2i(7, 7), gap["target"])
		)
		var attacking := pieces.piece_of(attacker)
		var before := attacking.health

		var outcome := CombatResolution.minion_action(
			board, pieces, attacking, Vector2i(7, 7)
		)
		equal(outcome["kind"], CombatResolution.CAPTURE, gap["as"])
		equal(pieces.piece_of(target), null, "the captured minion is gone")
		equal(pieces.piece_of(attacker).cell, Vector2i(7, 7), "the attacker takes the cell")
		equal(pieces.piece_of(attacker).health, before,
			"and the attacker is untouched -- a capture costs the taker nothing")
		equal(pieces.size(), 1, "one piece left on the board, whichever way round")

	# Health is not read either. A Cat with one hit point left takes a full-health
	# Ent forty levels above it, because the rule does not look.
	var board := _board()
	var pieces := PieceMap.new()
	var weak := pieces.add(Minion.of_kind(Minion.CAT, 101, Vector2i(6, 6), LOW))
	var strong := pieces.add(Minion.of_kind(Minion.ENT, 202, Vector2i(7, 7), HIGH))
	pieces.piece_of(weak).health = 1
	equal(pieces.piece_of(strong).health, Damage.minion_health(HIGH),
		"the level-40 Ent stands at %d hit points" % Damage.minion_health(HIGH))
	CombatResolution.minion_action(board, pieces, pieces.piece_of(weak), Vector2i(7, 7))
	equal(pieces.piece_of(strong), null, "and one hit point takes all %d of them"
		% Damage.minion_health(HIGH))
	equal(pieces.piece_of(weak).health, 1, "with the taker still on its last point")


# --- What the board reads off an item -------------------------------------


## A commander's defence is what the items it carries spent on defence, and
## nothing else. No tier, no per-piece constant, no level term.
##
## The heap of points is turned into reduction once, by `Armour.reduction`:
## sixteen points buy one, because a blow lands somewhere on a body rather than
## on the piece its owner would pick, and because a commander carries four worn
## items for the one in its hands.
func _defence_is_what_a_loadout_spent_on_it() -> void:
	var pieces := PieceMap.new()
	var bare := _commander(pieces, Vector2i(2, 2), 8, Weapon.sword(), [])
	equal(bare.defence(), 0, "a commander carrying nothing stops nothing")

	# The same four slots at four levels of common gear, each piece buying its
	# slot's capability first and putting the rest into taking blows.
	var table := PackedStringArray()
	for level in [1, 3, 8, 40]:
		var suit := _mobile_suit(level)
		var points := 0
		for piece in suit:
			points += (piece as Armour).defence_for((piece as Armour).item.level)
		var worn := _commander(pieces, Vector2i(2, 4 + level % 5), level,
			Weapon.sword(), suit)
		table.append("L%d: budget=%d points=%d def=%d" % [
			level, 4 * ItemBudget.total(ItemRarity.COMMON, level), points, worn.defence(),
		])
	equal(table, PackedStringArray([
		"L1: budget=16 points=12 def=0",
		"L3: budget=48 points=28 def=1",
		"L8: budget=128 points=100 def=6",
		"L40: budget=640 points=612 def=38",
	]), "defence rises with the budget of the gear and with nothing else")

	# What is in a commander's hands defends it too: a blow is stopped by what
	# you carry, and a buckler is carried. Thirty-two points of a held item's
	# defence axis are worth the same two as thirty-two on a worn one.
	var suited := _commander(pieces, Vector2i(4, 4), 8,
		Weapon.held(Weapon.shield(), 8, ItemRarity.COMMON, 0, 32), [])
	equal(suited.defence(), 2, "a level-8 shield spent entirely on defence stops 2")

	# Broken: the same four slots with nothing spent on moving keep every point,
	# and what they keep is exactly what the three grants would have cost.
	var still := _commander(pieces, Vector2i(10, 10), 8, Weapon.sword(), _armoured_suit())
	equal(still.defence(), 8, "spending nothing on moving is 128 points, which is 8")
	equal(still.move_grants().size(), 1, "and the base cardinal step is all it has")


## A weapon's damage and its cooldown come off the item behind it.
##
## The catalogue's numbers are the *shape* -- ten parts cut to sixteen parts
## cleave -- and the item's effects axis is how much of that shape a wielder
## gets. Its movement axis buys the wait down, one turn per cell of the pattern.
func _a_weapon_deals_what_its_budget_bought() -> void:
	var reference := Weapon.sword()
	equal(reference.damage_weights(), [10, 16] as Array[int],
		"the catalogue's damage numbers are the weapon's shape")
	equal(reference.reference_power(), 26,
		"and a sword with no item behind it reads at their sum")
	equal([reference.damage_of(0, 0), reference.damage_of(1, 0)], [10, 16],
		"which returns exactly the catalogue, whatever score reads it")

	var scaled := PackedStringArray()
	for level in [2, 4, 8, 20]:
		var sword := Weapon.held(Weapon.sword(), level)
		var score := sword.item.level
		scaled.append("L%d: P=%d cut=%d cleave=%d" % [
			level, sword.item.budget(),
			sword.damage_of(0, score), sword.damage_of(1, score),
		])
	equal(scaled, PackedStringArray([
		"L2: P=8 cut=3 cleave=5",
		"L4: P=16 cut=6 cleave=10",
		"L8: P=32 cut=12 cleave=20",
		"L20: P=80 cut=31 cleave=49",
	]), "the same shape at four budgets, and the cleave is always the heavier")

	# The wait is bought by the cell. A cleave covers six cells, so six points of
	# the item's movement axis take one turn off it and twelve take two -- and
	# nothing takes it below one, because a turn is the smallest thing there is.
	equal(Weapon.sword().attack_at(1).cell_count(), 6, "a cleave covers six cells")
	var waits := PackedStringArray()
	for spent in [0, 6, 12, 18]:
		var quick := Weapon.held(Weapon.sword(), 8, ItemRarity.COMMON, spent)
		waits.append("mov=%d cut=%d cleave=%d" % [
			spent, quick.cooldown_of(0, 8), quick.cooldown_of(1, 8),
		])
	equal(waits, PackedStringArray([
		"mov=0 cut=1 cleave=3",
		"mov=6 cut=1 cleave=2",
		"mov=12 cut=1 cleave=1",
		"mov=18 cut=1 cleave=1",
	]), "one turn off the wait per pattern-full of movement points")

	# Broken: the shield's shove has no damage to divide, so no budget gives it
	# one. A shield is a shield.
	var shield := Weapon.held(Weapon.shield(), 40, ItemRarity.ETERNAL)
	equal(shield.item.budget(), 1280, "an eternal level-40 shield is worth 1280")
	equal(shield.damage_of(0, 40), 0, "and its shove still deals nothing at all")
	equal(shield.attack_at(0).push, 1, "what it does is push, and that is all")


## The movement-against-defence trade, in play rather than in the item table.
##
## Two commanders of the same level carrying four items each off creatures of the
## same level -- the same sixty-four points of budget -- one of which bought every
## movement grant on offer and the other of which bought none. What each reaches,
## and what each survives, in cells and in blows.
func _the_trade_between_moving_and_taking_a_blow() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var quick := _commander(pieces, Vector2i(6, 6), 4, Weapon.sword(), _mobile_suit(4))
	var solid := _commander(pieces, Vector2i(2, 2), 4, Weapon.sword(), _armoured_suit(4))

	var spent := [0, 0]
	for piece in quick.armour:
		spent[0] += piece.item.budget()
	for piece in solid.armour:
		spent[1] += piece.item.budget()
	equal(spent, [64, 64], "the same sixty-four points of gear on both of them")

	equal(LegalMoves.destinations(board, pieces, quick).size(), 24,
		"the mobile one reaches twenty-four cells")
	equal(LegalMoves.destinations(board, pieces, solid).size(), 4,
		"the armoured one reaches four")
	equal([quick.defence(), solid.defence()], [2, 4],
		"and it is the armoured one that stops twice as much")

	# What each survives, against a sword off a creature of their own level.
	var sword := Weapon.held(Weapon.sword(), 4)
	var cut := sword.damage_of(0, 4)
	var cleave := sword.damage_of(1, 4)
	equal([cut, cleave], [6, 10], "a level-4 sword cuts for 6 and cleaves for 10")
	equal(quick.max_health(), 44, "both stand at 44 hit points")
	var blows := PackedStringArray()
	for one in [quick, solid]:
		var against := (one as Commander).defence()
		var by_cut := Damage.resolve(cut, Damage.NONE, against)
		var by_cleave := Damage.resolve(cleave, Damage.NONE, against)
		blows.append("def=%d cut=%d/%d cleave=%d/%d" % [
			against, by_cut, _blows_to_kill(one as Commander, by_cut),
			by_cleave, _blows_to_kill(one as Commander, by_cleave),
		])
	equal(blows, PackedStringArray([
		"def=2 cut=4/11 cleave=8/6",
		"def=4 cut=2/22 cleave=6/8",
	]), "the armoured one survives twice as many cuts; the mobile one reaches six"
		+ " times as far")


## The ability-score gate reaches the numbers a fight is decided by.
##
## The same suit and the same sword, read by wearers of four different scores. An
## under-qualified wearer stops less and hits for less, off objects that are not
## changed by being read.
func _an_under_qualified_wearer_is_worth_less() -> void:
	var pieces := PieceMap.new()
	var suit := _armoured_suit()
	var sword := Weapon.held(Weapon.sword(), 8)
	var wearer := _commander(pieces, Vector2i(6, 6), 8, sword, suit)
	equal(sword.item.governing, Ability.STR, "the sword is read against STR")

	var read := PackedStringArray()
	for score in [8, 6, 4, 2]:
		for ability in Ability.ALL:
			wearer.set_score(ability, score)
		read.append("score %d: def=%d cut=%d cleave=%d" % [
			score, wearer.defence(), wearer.damage_of(0), wearer.damage_of(1),
		])
	equal(read, PackedStringArray([
		"score 8: def=8 cut=12 cleave=20",
		"score 6: def=6 cut=9 cleave=15",
		"score 4: def=4 cut=6 cleave=10",
		"score 2: def=2 cut=3 cleave=5",
	]), "a wearer who reaches three quarters of the gear gets three quarters of it")

	# Broken: the items never moved. A wearer who reaches all of them reads the
	# whole thing off the same objects.
	for ability in Ability.ALL:
		wearer.set_score(ability, 40)
	equal([wearer.defence(), wearer.damage_of(0)], [8, 12],
		"and a score above the item's level reads it in full, never more")
	equal((suit[0] as Armour).item.defence, 32,
		"the object itself is untouched by the reading")


# --- The numeric layer ----------------------------------------------------


## Minion against player: the minion's level, against the player's defence.
##
## Level 1 is worth 4 and level 8 is worth 18, both written out; a bare commander
## takes all of it and one wearing 8 points of armour takes the rest.
func _minion_against_player_is_level_against_defence() -> void:
	equal(Damage.minion_power(1), 4, "a level-1 minion's blow is worth 4")
	equal(Damage.minion_power(8), 18, "a level-8 minion's blow is worth 18")

	var board := _board()
	var pieces := PieceMap.new()
	var bare := _commander(pieces, Vector2i(6, 6), 5, Weapon.sword(), [])
	var armoured := _commander(pieces, Vector2i(2, 6), 5, Weapon.sword(),
		_armoured_suit())
	equal(bare.defence(), 0, "a bare commander has no defence at all")
	equal(armoured.defence(), 8,
		"a suit off level-8 creatures with nothing spent on moving is 8 points of it")
	equal(bare.max_health(), 50, "a level-5 commander stands at 50 hit points")

	# The Toadstool captures diagonally, and the commander is turned to face it,
	# so this is a plain front-on blow with no modifier in it.
	bare.face(PieceGeometry.SOUTH)
	var biter := pieces.add(Minion.of_kind(Minion.TOADSTOOL, 303, Vector2i(5, 7), 8))
	var hit := CombatResolution.minion_action(board, pieces, pieces.piece_of(biter),
		Vector2i(6, 6))
	equal(hit["kind"], CombatResolution.STRIKE, "a minion reaching a commander strikes it")
	equal(hit["dealt"], 18, "18 through no armour at all")
	equal(bare.health, 32, "leaving 32 of 50")
	equal(pieces.piece_of(biter).cell, Vector2i(5, 7),
		"and the minion stays where it is -- a commander's cell is not taken")

	# Not even when the blow kills. A capture takes the cell; a strike never
	# does, and the difference shows only once the cell is free to take.
	bare.health = 5
	var finisher := pieces.add(Minion.of_kind(Minion.CAT, 303, Vector2i(7, 5), 8))
	var killing := CombatResolution.minion_action(board, pieces,
		pieces.piece_of(finisher), Vector2i(6, 6))
	equal(killing["killed"], true, "18 through no armour finishes a commander on 5")
	equal(pieces.piece_of(bare.id), null, "and the commander is gone")
	equal(pieces.piece_of(finisher).cell, Vector2i(7, 5),
		"but the minion that killed it is still where it stood")
	equal(pieces.piece_at(Vector2i(6, 6)), null, "and the cell it emptied stays empty")

	# Broken: the same blow against 8 points of armour is 8 points smaller.
	armoured.face(PieceGeometry.SOUTH)
	var second := pieces.add(Minion.of_kind(Minion.TOADSTOOL, 303, Vector2i(1, 7), 8))
	var reduced := CombatResolution.minion_action(board, pieces, pieces.piece_of(second),
		Vector2i(2, 6))
	equal(reduced["dealt"], 10, "18 against 8 points of armour is 10")
	not_equal(reduced["dealt"], hit["dealt"],
		"if armour did nothing, the check above would prove nothing")
	equal(armoured.health, 40, "leaving 40 of 50")


## Player against minion: the weapon's number, against the minion's own
## level-scaled health and defence.
##
## And the constraint the design names in as many words: a cheap low-damage area
## attack cannot clear an army in one action. Nine minions stand in the fireball;
## nine minions are still standing afterwards.
func _player_against_minion_is_weapon_against_level_scaled_stats() -> void:
	equal(Damage.minion_health(1), 10, "a level-1 minion has 10 hit points")
	equal(Damage.minion_defence(1), 2, "and 2 points of defence")
	equal(Damage.minion_health(8), 38, "a level-8 minion has 38")
	equal(Damage.minion_defence(8), 9, "and 9")

	# The area attack, over nine minions at once.
	var board := _board()
	var pieces := PieceMap.new()
	var caster := _commander(pieces, Vector2i(6, 8), 5, Weapon.staff(), [])
	caster.face(PieceGeometry.NORTH)
	var army := PackedInt32Array()
	for row in range(3, 6):
		for column in range(5, 8):
			army.append(pieces.add(Minion.of_kind(Minion.TOADSTOOL, 303,
				Vector2i(column, row), 1)))
	equal(army.size(), 9, "nine minions, one for every cell of the fireball")

	var burst := CombatResolution.commander_attack(board, pieces, caster, 0, 1)
	equal(burst["cells"], 9, "the fireball covers nine cells")
	equal((burst["hits"] as Array).size(), 9, "and lands on all nine minions")
	for hit in burst["hits"]:
		equal(hit["dealt"], 2, "4 damage against 2 defence is 2")
		equal(hit["killed"], false, "and 2 of 10 hit points kills nothing")
	equal(pieces.minions_of(303).size(), 9,
		"a cheap area attack leaves the whole army standing")

	# Broken: the heavy single-target attack does clear one of them outright, so
	# the survival above is about the attack and not about the minions.
	var second := PieceMap.new()
	var swordsman := _commander(second, Vector2i(6, 6), 5, Weapon.sword(), [])
	swordsman.face(PieceGeometry.NORTH)
	var chaff := second.add(Minion.of_kind(Minion.TOADSTOOL, 303, Vector2i(6, 5), 1))
	var cleave := CombatResolution.commander_attack(board, second, swordsman, 1, 1)
	equal(cleave["hits"][0]["dealt"], 14, "16 damage against 2 defence is 14")
	equal(cleave["hits"][0]["killed"], true, "which is more than 10 hit points")
	equal(second.piece_of(chaff), null, "so that minion is gone")

	# And the same cleave against a level-8 minion is out-scaled, which is the
	# frontier the design describes: 16 against 9 is 7, of 38.
	var third := PieceMap.new()
	var same := _commander(third, Vector2i(6, 6), 5, Weapon.sword(), [])
	same.face(PieceGeometry.NORTH)
	var elite := third.add(Minion.of_kind(Minion.TOADSTOOL, 303, Vector2i(6, 5), 8))
	var against_elite := CombatResolution.commander_attack(board, third, same, 1, 1)
	equal(against_elite["hits"][0]["dealt"], 7, "16 against 9 defence is 7")
	equal(third.piece_of(elite).health, 31, "leaving 31 of 38")


## Player against player: the weapon's number against the armour's.
func _player_against_player_is_weapon_against_defence() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var attacker := _commander(pieces, Vector2i(6, 6), 3, Weapon.spear(), [])
	var target := _commander(pieces, Vector2i(6, 5), 3, Weapon.spear(),
		_armoured_suit())
	attacker.face(PieceGeometry.NORTH)
	target.face(PieceGeometry.NORTH)

	equal(target.max_health(), 38, "a level-3 commander stands at 38")
	equal(target.defence(), 8, "behind 8 points of armour")
	var thrust := CombatResolution.commander_attack(board, pieces, attacker, 0, 1)
	var hit: Dictionary = thrust["hits"][0]
	equal(hit["relation"], "back", "the spear is in its back")
	equal(hit["multiplier"], Damage.BACK, "which doubles it")
	equal(hit["dealt"], 8, "8 doubled is 16, less 8 of armour, is 8")
	equal(target.health, 30, "leaving 30 of 38")

	# Broken: take the armour off and the same blow is 8 points bigger.
	for slot in Armour.SLOTS:
		target.unequip(slot)
	equal(target.defence(), 0, "with the armour off there is no defence")
	var bare := CombatResolution.commander_attack(board, pieces, attacker, 0, 2)
	equal(bare["hits"][0]["dealt"], 16, "and the same blow is the full 16")
	not_equal(bare["hits"][0]["dealt"], hit["dealt"],
		"if armour did nothing, the check above would prove nothing")


## The directory the two structural checks below read. They read all of it: what
## they cover is found by opening this directory, never by a list typed out here.
const SIM_DIR := "res://sim"

## What a random source is called in this project, matched as plain text so that
## a mention inside a comment counts too.
const RANDOM_SOURCES := [
	"randi", "randf", "randomize", "RandomNumberGenerator", "Rng.",
]

## The board class, which is part of the combat vocabulary here even though
## `LayerCheck` deliberately leaves it out of its own list: the render shell is
## allowed to draw a board, and the file that builds one is squarely a combat file.
const BOARD_CLASS := "CombatBoard"

## The one file of the combat layer that may name a random source: the seam, and
## the whole of the die settled in the items phase.
##
## Before that decision this list was empty and the rule was "no file of the
## combat layer touches a random number". It is now "exactly one does, and it is
## the file the roll model lives in" -- which is a stronger statement, not a
## weaker one, because it is checked in both directions: the permitted file must
## *contain* a random source, or the scan below would be passing on a rule that
## no longer describes anything.
const DIE_ROOT := "res://sim/damage.gd"

## The other file of the combat vocabulary that may name a random source, and
## why it is not a widening of the rule.
##
## `sim/control_loop.gd` is swept into the scan below because every character is
## a `Combatant` and every commander a `Commander`, not because it runs any rule
## of a fight -- exactly the position `WORLD_ROOT` is in, and it is excused the
## same way and checked the same way: it must contain none of `RULE_CALLS`. What
## it draws is section 2.2's bias toward continuing, and it draws it by *hashing*
## the seed, the character and the tick, which is the discipline the die keeps
## and which the stream ban below applies to it unchanged.
const LOOP_ROOT := "res://sim/control_loop.gd"

## The third file of the combat vocabulary that may name a random source, and it
## is in exactly `LOOP_ROOT`'s position.
##
## `sim/world_cast.gd` is swept into the scan because the people who live in an
## ordinary world are `Commander`s standing as `Combatant`s, not because it runs
## any rule of a fight. What it draws is which way a wanderer turns at the end of
## a leg, and it draws it by *hashing* the seed, the character and the leg, which
## is the discipline the die keeps. It is excused the same way and checked the
## same way: it must contain none of `RULE_CALLS`.
const CAST_ROOT := "res://sim/world_cast.gd"

## Every file excused from the random-source scan. Three, and all three hash.
const HASH_ROOTS := [DIE_ROOT, LOOP_ROOT, CAST_ROOT]

## What a *stream* is called, as opposed to a stateless hash.
##
## Forbidden in every combat file including `DIE_ROOT`. A stream's numbers depend
## on how many were drawn before them, so a blow's roll would depend on how many
## other blows had been struck first and resolving the same blow in a different
## order would give a different answer. The die is hashed from the blow instead,
## which is the discipline `sim/item_drop.gd` already follows, and this is what
## stops anybody quietly swapping one for the other.
const STREAM_SOURCES := [
	"SimRng.new(", "next_u32(", "next_float(", "next_int(", "next_range(",
	"set_seed(", "set_state(", "fork(",
]

## The one file that names the combat layer without being part of a fight.
##
## `sim/world.gd` is the world a fight stands on: it holds a `CombatantRoster`,
## hands out a `CombatBoard` through `CombatBoardBuilder`, and seeds the terrain
## generator -- which is what generation is for, and is the only reason it names
## the project's `SimRng` at all. It runs no rule of a turn, and that is checked
## below rather than taken on trust.
const WORLD_ROOT := "res://sim/world.gd"

## Member accesses that appear only where a rule of a fight is being run. The
## excused file must contain none of them, so the excuse cannot become a place to
## park a turn rule outside the scan.
const RULE_CALLS := [
	"Damage.", "CombatResolution.", "CombatMatch.", "CombatPolicy.",
	"LegalMoves.", "MoveGrant.", "PieceGeometry.",
]


## All player-facing damage goes through one named function, and no file of the
## combat layer has a random source anywhere in it.
##
## Both are checked by reading the sources rather than by trusting the
## arrangement, and **the files to read are found by opening `sim/`**, not typed
## out here. A typed list is only as strong as the day it was written: this check
## used to read fourteen paths written into this file, nine combat files had
## joined `sim/` since, and a second call to the seam in one of them -- in
## `sim/combat_policy.gd` -- passed every suite.
##
## The two checks have different scopes, on purpose, and the report says so:
##
##   * the seam is required to be called from exactly **one file under `sim/`**,
##     exactly once within it. That is every file the scan found, with no
##     exceptions, and it is the sentence `reports/combat.md` prints.
##   * a random source is forbidden in **every file under `sim/` that names a
##     class of the combat layer's vocabulary** -- `LayerCheck`'s own list of what
##     the combat layer is called, plus `CombatBoard`. That is the right scope
##     because generation is seeded-random by design: terrain, biomes, islands,
##     settlements, paths and scatter all draw on `SimRng`, so forbidding it
##     across the whole of `sim/` would forbid the world rather than the fight.
func _all_player_facing_damage_goes_through_one_seam() -> void:
	var sources := _sim_sources()
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())
	# Four of the nine files the typed list had gone stale on, so that "the scan
	# found them" is a claim about named files and not about a number.
	for expected in ["res://sim/combat_policy.gd", "res://sim/combat_board.gd",
			"res://sim/combat_snap.gd", "res://sim/combatant_roster.gd"]:
		check(sources.has(expected), "the scan reaches %s" % expected)

	var callers := PackedStringArray()
	for path in sources:
		if _read(path).contains("Damage.resolve("):
			callers.append(path)
	equal(callers, PackedStringArray(["res://sim/combat_resolution.gd"]),
		"exactly one file under sim/ calls the resolution seam")
	equal(_read("res://sim/combat_resolution.gd").count("Damage.resolve("), 1,
		"and it calls it exactly once, so an attack roll would be one edit")

	var combat := _combat_sources()
	check(combat.size() >= 24,
		"the combat layer the second check covers is %d files" % combat.size())
	check(combat.size() < sources.size(),
		"and is a part of sim/ rather than all of it, because generation is seeded")
	var random := PackedStringArray()
	for path in combat:
		if HASH_ROOTS.has(path):
			continue
		var text := _read(path)
		for word in RANDOM_SOURCES:
			if text.contains(word):
				random.append("%s -> %s" % [path, word])
	equal(random, PackedStringArray(),
		"no file of the combat layer outside %s touches a random number" % ", ".join(
			PackedStringArray(HASH_ROOTS)))

	# Each permitted file has to be one the scan found, has to be in the combat
	# layer it is being excused from, and has to actually contain the thing it is
	# excused for -- otherwise an exception would be excusing nothing and the
	# check above would read as stronger than it is.
	var die_text := _read(DIE_ROOT)
	for path in HASH_ROOTS:
		check(combat.has(path), "%s is a combat file the scan found" % path)
		var text := _read(path)
		var named := PackedStringArray()
		for word in RANDOM_SOURCES:
			if text.contains(word):
				named.append(word)
		check(not named.is_empty(),
			"and %s names a random source, so its exception excuses something" % path)
		check(text.contains("SimRng.hash_"),
			"and reaches for it by hashing rather than by a stream")

	# And the two exceptions beside the die are excused for a reason that is
	# checked rather than stated: each names the combat vocabulary because every
	# character is a combatant, and each runs no rule of a turn -- the same test
	# `WORLD_ROOT` has to pass below.
	for excused in [LOOP_ROOT, CAST_ROOT]:
		var excused_text := _read(excused)
		var excused_rules := PackedStringArray()
		for call_name in RULE_CALLS:
			if excused_text.contains(call_name):
				excused_rules.append(call_name)
		equal(excused_rules, PackedStringArray(),
			"and %s runs no rule of a turn" % excused)

	# And what it names is a stateless hash, never a stream. This is the property
	# that makes a blow's roll a function of the blow rather than of how many
	# blows came before it, and it is required of the whole layer -- the permitted
	# file included.
	var streams := PackedStringArray()
	for path in combat:
		var text := _read(path)
		for word in STREAM_SOURCES:
			if text.contains(word):
				streams.append("%s -> %s" % [path, word])
	equal(streams, PackedStringArray(),
		"the die is hashed from the blow; no file of the combat layer holds a stream")
	check(die_text.contains("SimRng.hash_ints("),
		"and the one file that rolls it does so by hashing")

	# The die is rolled in exactly one place, for the same reason the seam is
	# called in exactly one place: a second roll site is a second model.
	var rollers := PackedStringArray()
	for path in sources:
		if _read(path).contains("Damage.swing_for("):
			rollers.append(path)
	equal(rollers, PackedStringArray(["res://sim/combat_resolution.gd"]),
		"exactly one file under sim/ rolls the die")
	equal(_read("res://sim/combat_resolution.gd").count("Damage.swing_for("), 1,
		"and it rolls it exactly once, on the one path that reaches the seam")

	# Broken: the same scan, for a string that is in every one of those files,
	# finds it. So the empty result above means "not there" and not "the scan
	# read nothing".
	var present := PackedStringArray()
	for path in combat:
		if _read(path).contains("func "):
			present.append(path)
	equal(present.size(), combat.size(),
		"the same scan over a string that is there finds it in every file")

	# The one file excused from the second scan is excused for a reason that is
	# itself checked: it hands out a board and a roster and runs no rule of a turn.
	check(sources.has(WORLD_ROOT), "the excused file is one the scan found")
	check(not combat.has(WORLD_ROOT), "and it is the only thing the scan drops")
	var world_text := _read(WORLD_ROOT)
	check(_names_combat_class(world_text),
		"it names the combat layer, which is why it has to be named here at all")
	for member in RULE_CALLS:
		check(not world_text.contains(member),
			"and runs no rule of a fight, so excusing it hides nothing (%s)" % member)

	# The capture path reads nothing numeric, and that is checkable from outside:
	# the whole function is four statements and none of them mentions Damage.
	var resolution := _read("res://sim/combat_resolution.gd")
	var capture_body := resolution.substr(resolution.find("static func capture("))
	capture_body = capture_body.substr(0, capture_body.find("\n\n"))
	check(not capture_body.contains("Damage"),
		"the capture rule does not reach the numeric layer at all")
	check(not capture_body.contains("health") and not capture_body.contains("level"),
		"and does not read a health or a level")
	check(not capture_body.contains("swing") and not capture_body.contains("seed"),
		"and no die reaches it: the minion layer is deterministic, permanently")


## High ground, flanking and backstab, each with the number it applies.
##
## | rule | when | multiplier |
## |---|---|---|
## | high ground | the attacker's cell is 1 unit or more above the target's | x1.5 |
## | flank | the attacker is off the target's side | x1.5 |
## | backstab | the attacker is behind the target | x2 |
##
## They multiply: a backstab from high ground is x3, not x2.5.
func _high_ground_flanking_and_backstab() -> void:
	equal(Damage.HIGH_GROUND, 150, "high ground is half again")
	equal(Damage.FLANK, 150, "a flank is half again")
	equal(Damage.BACK, 200, "a backstab is double")

	var board := _board()
	# Four attackers around one target, all on level ground, all with the same
	# spear. The only thing that differs is where they stand.
	var around := {
		Vector2i(6, 5): ["front", Damage.NONE, 8],
		Vector2i(7, 6): ["flank", Damage.FLANK, 12],
		Vector2i(6, 7): ["back", Damage.BACK, 16],
		Vector2i(5, 6): ["flank", Damage.FLANK, 12],
	}
	for from in around:
		var wanted: Array = around[from]
		var pieces := PieceMap.new()
		var target := _commander(pieces, MIDDLE, 3, Weapon.spear(), [])
		target.face(PieceGeometry.NORTH)
		var attacker := _commander(pieces, from, 3, Weapon.spear(), [])
		var hit := CombatResolution.strike(board, pieces, attacker, target, 8)
		equal(hit["relation"], wanted[0],
			"from (%d,%d) the attacker is at the target's %s" % [from.x, from.y, wanted[0]])
		equal(hit["multiplier"], wanted[1], "which is x%d" % wanted[1])
		equal(hit["dealt"], wanted[2], "so 8 becomes %d" % wanted[2])

		# Broken: turn the target to face the attacker and the same blow is a
		# front-on 8 again.
		target.set_level(3)
		target.face(_facing_towards(from - MIDDLE))
		var facing_it := CombatResolution.strike(board, pieces, attacker, target, 8)
		equal(facing_it["relation"], "front",
			"turned to face it, the same attacker is at the front")
		equal(facing_it["dealt"], 8, "and the same blow is 8 again")
		if wanted[1] != Damage.NONE:
			not_equal(facing_it["dealt"], wanted[2],
				"so the %s number above was about where it stood" % wanted[0])

	# High ground: the target stands in the dip at (4,3), the attacker beside it.
	var pieces := PieceMap.new()
	var below := _commander(pieces, Vector2i(4, 3), 3, Weapon.spear(), [])
	below.face(PieceGeometry.NORTH)
	var above := _commander(pieces, Vector2i(4, 4), 3, Weapon.spear(), [])
	equal(board.height_at(Vector2i(4, 4)) - board.height_at(Vector2i(4, 3)), 2.0,
		"the attacker stands 2 units over the target")
	var downhill := CombatResolution.strike(board, pieces, above, below, 8)
	equal(downhill["high_ground"], true, "which is high ground")
	equal(downhill["relation"], "back", "and it is behind the target as well")
	equal(downhill["multiplier"], 300, "x1.5 and x2 multiply to x3, not add to x2.5")
	equal(downhill["dealt"], 24, "so 8 becomes 24")

	# Broken: the same pair on level ground is the backstab alone.
	var flat := PieceMap.new()
	var level_target := _commander(flat, MIDDLE, 3, Weapon.spear(), [])
	level_target.face(PieceGeometry.NORTH)
	var level_attacker := _commander(flat, Vector2i(6, 7), 3, Weapon.spear(), [])
	var same_relation := CombatResolution.strike(board, flat, level_attacker,
		level_target, 8)
	equal(same_relation["high_ground"], false, "on level ground there is no high ground")
	equal(same_relation["multiplier"], 200, "leaving the backstab alone")
	equal(same_relation["dealt"], 16, "so 8 becomes 16 rather than 24")


# --- The shove ------------------------------------------------------------


# --- The die (section 13's first open decision, settled here) --------------


## Every attack lands. The die says how hard, and it is centred on the number
## the deterministic model gave.
##
## This is option (b) of the three the design lists -- armour as damage
## reduction, attacks always land -- with the roll moved off "whether" and onto
## "how much". The two properties that make it worth having are checked here:
## the blow never comes to nothing, and the die costs nothing on average.
func _the_die_is_on_how_hard_a_blow_lands_never_on_whether() -> void:
	equal(Damage.STEADY, Damage.NONE, "the die switched off is a multiplier of one")
	equal(Damage.SWING_LOW, 92, "the unluckiest blow is 92 hundredths of the plain one")
	equal(Damage.SWING_HIGH, 108, "and the luckiest is 108")
	equal(Damage.SWING_FACES, 9, "each of the two dice has 9 faces")

	# Switched off, the seam is digit for digit the function the combat phase
	# shipped: every table in reports/combat.md is still this arithmetic.
	for power in [1, 3, 8, 16, 40]:
		for multiplier in [Damage.NONE, Damage.FLANK, Damage.BACK, 300]:
			for defence in [0, 2, 8, 100]:
				equal(Damage.resolve(power, multiplier, defence, Damage.STEADY),
					Damage.resolve(power, multiplier, defence),
					"a steady %d x%d against %d is the deterministic number"
					% [power, multiplier, defence])

	# The blow always lands. Every roll of the die, against the heaviest armour
	# in the fixture, still takes the floor off -- there is no roll anywhere in
	# the band that returns nothing, because there is no branch that could.
	var landed_at_every_roll := true
	for swing in range(Damage.SWING_LOW, Damage.SWING_HIGH + 1):
		if Damage.resolve(3, Damage.NONE, 100, swing) < Damage.MINIMUM:
			landed_at_every_roll = false
	check(landed_at_every_roll,
		"no roll of the die makes a blow come to nothing: a plan can be off by "
		+ "how much, never by whether")

	# Rolled over many fights, the die is centred: the mean lands on the
	# deterministic number, a little under it because the division floors.
	var pieces := PieceMap.new()
	var target := _commander(pieces, MIDDLE, 8, Weapon.spear(), _armoured_suit())
	target.face(PieceGeometry.NORTH)
	var attacker := _commander(pieces, Vector2i(6, 5), 8, Weapon.sword(), [])

	var rolls := PackedInt32Array()
	var low := Damage.SWING_HIGH
	var high := Damage.SWING_LOW
	var total := 0
	var trials := 20000
	for seed_value in range(1, trials + 1):
		var swing := Damage.swing_for(seed_value, attacker, target, 16)
		rolls.append(swing)
		low = mini(low, swing)
		high = maxi(high, swing)
		total += swing
	equal(low, Damage.SWING_LOW, "over %d fights the die reached its low end" % trials)
	equal(high, Damage.SWING_HIGH, "and its high end")
	var mean := float(total) / float(trials)
	check(absf(mean - float(Damage.NONE)) < 0.2,
		"and averaged %.3f, which is the plain number to within a fifth of a "
		% mean + "hundredth -- the die costs nothing on average")

	# The die is a fraction of the blow, not of what got past the armour.
	#
	# Those are the same number until armour is a large share of the blow, and
	# then they part: a 40-point blow against 30 points of armour deals 10 with
	# the die switched off, and 7 to 13 with it. Applying the die to the 10 that
	# got through would give 9 to 11 instead -- armour damping the die. The
	# multiplier already works this way, and for the same reason: a modifier is a
	# fact about the attack, not about what survived the armour.
	equal(Damage.resolve(40, Damage.NONE, 30), 10,
		"a 40-point blow against 30 armour is 10 with the die switched off")
	equal(Damage.resolve(40, Damage.NONE, 30, Damage.SWING_LOW), 7,
		"the unluckiest roll of it is 7, being 92 hundredths of the *blow*")
	equal(Damage.resolve(40, Damage.NONE, 30, Damage.SWING_HIGH), 13,
		"and the luckiest is 13, so armour does not damp the die")
	check(Damage.resolve(40, Damage.NONE, 30, Damage.SWING_LOW) < 9
			and Damage.resolve(40, Damage.NONE, 30, Damage.SWING_HIGH) > 11,
		"a die applied to what got through would have given 9 to 11 instead")

	# Two dice, not one: the middle of the band is far more likely than an end,
	# which is what makes a plan wrong by a little far more often than by a lot.
	var middle := 0
	var edges := 0
	for swing in rolls:
		if absi(swing - Damage.NONE) <= 2:
			middle += 1
		if absi(swing - Damage.NONE) >= 8:
			edges += 1
	check(middle > 4 * edges,
		"the middle of the band came up %d times to the edges' %d, so the two "
		% [middle, edges] + "dice are summed and not one flat die")


## The die is narrower than the narrowest rung of the positional ladder, so no
## roll makes a worse position pay better than a better one.
##
## This is the whole of why a die was affordable at all. Section 3.1 makes
## out-positioning the only scalable way past a stronger opponent; a die that
## could sometimes reverse a flank or a backstab would make that unreliable
## exactly when it mattered. The rungs are 100, 150, 200 and 300, and the
## requirement is that the *worst* roll on any rung beats the *best* roll on the
## one below it.
func _the_die_never_inverts_the_positional_ladder() -> void:
	var ladder := [
		[Damage.NONE, "front-on"],
		[Damage.FLANK, "a flank, or high ground"],
		[Damage.BACK, "a backstab"],
		[Damage.BACK * Damage.HIGH_GROUND / Damage.NONE, "a backstab from high ground"],
	]
	# Two statements, because integer arithmetic makes them different. Wherever a
	# blow is three points or more and gets through the armour at all, the better
	# rung is *strictly* better at every roll. Where it is not -- a one- or
	# two-point blow, or one smaller than the armour, which `MINIMUM` floors -- the
	# rungs can tie, and the requirement is only that they are never the wrong
	# way round. Those ties are the floor's and the rounding's doing rather than
	# the die's: the deterministic model ties there as well.
	var strict := 0
	var tied := 0
	for defence in [0, 2, 8]:
		for power in range(1, 41):
			for rung in range(1, ladder.size()):
				var worse: int = ladder[rung - 1][0]
				var better: int = ladder[rung][0]
				var best_of_worse := Damage.resolve(
					power, worse, defence, Damage.SWING_HIGH
				)
				var worst_of_better := Damage.resolve(
					power, better, defence, Damage.SWING_LOW
				)
				check(worst_of_better >= best_of_worse,
					"a %d-point blow against %d armour: the unluckiest %s (%d) is "
					% [power, defence, ladder[rung][1], worst_of_better]
					+ "never worse than the luckiest %s (%d)"
					% [ladder[rung - 1][1], best_of_worse])
				if power < 3 or Damage.resolve(power, worse, defence) <= Damage.MINIMUM:
					# No room in the arithmetic for a die to say anything: either
					# the blow is one or two points, or it is smaller than the
					# armour and `MINIMUM` is what both rungs return. The
					# deterministic model is at the floor here too, so this is
					# the floor's doing and not the die's.
					tied += 1
					continue
				check(worst_of_better > best_of_worse,
					"a %d-point blow against %d armour: the unluckiest %s (%d) "
					% [power, defence, ladder[rung][1], worst_of_better]
					+ "strictly beats the luckiest %s (%d)"
					% [ladder[rung - 1][1], best_of_worse])
				strict += 1
	check(strict > 3 * tied,
		"%d of the %d rung comparisons had room for the die to speak and were "
		% [strict, strict + tied]
		+ "strictly ordered; the other %d were at the floor or under 3 points"
		% tied)

	# Broken: a die one step wider than the bound the ladder can carry does
	# invert it, which is why SWING is derived rather than picked.
	var too_wide_low := Damage.NONE - 2 * 8
	var too_wide_high := Damage.NONE + 2 * 8
	check(Damage.resolve(128, Damage.BACK, 0, too_wide_low)
			< Damage.resolve(128, Damage.FLANK, 0, too_wide_high),
		"a die of 8 does invert the 150-to-200 rung, so the bound is real")
	check(Damage.SWING < 8,
		"and the die shipped is inside it: SWING=%d" % Damage.SWING)


## The roll is a function of the fight and of the blow, and of nothing else.
##
## Not of how many blows came before it, which is what a stream would have made
## it. That is what lets two processes agree without having executed the same
## history, and it is the same discipline sim/item_drop.gd already follows.
func _the_die_is_a_function_of_the_blow_and_of_the_fight_seed() -> void:
	var pieces := PieceMap.new()
	var target := _commander(pieces, MIDDLE, 8, Weapon.spear(), _armoured_suit())
	var attacker := _commander(pieces, Vector2i(6, 5), 8, Weapon.sword(), [])

	equal(Damage.swing_for(77, attacker, target, 16),
		Damage.swing_for(77, attacker, target, 16),
		"the same blow in the same fight rolls the same number")

	# Each ingredient of the blow's identity changes it. Counted over a hundred
	# fights rather than asserted once, because any two rolls agree about one
	# time in eleven by chance.
	var changed := {"seed": 0, "health": 0, "cell": 0, "power": 0}
	for seed_value in range(1, 101):
		var base := Damage.swing_for(seed_value, attacker, target, 16)
		if Damage.swing_for(seed_value + 1000, attacker, target, 16) != base:
			changed["seed"] += 1
		if base != _swing_at_health(seed_value, attacker, target, 16, target.health - 1):
			changed["health"] += 1
		attacker.cell = Vector2i(6, 4)
		if Damage.swing_for(seed_value, attacker, target, 16) != base:
			changed["cell"] += 1
		attacker.cell = Vector2i(6, 5)
		if Damage.swing_for(seed_value, attacker, target, 15) != base:
			changed["power"] += 1
	for ingredient in changed:
		check(int(changed[ingredient]) > 80,
			"changing the %s changed the roll in %d of 100 fights"
			% [ingredient, changed[ingredient]])

	# And a fight with no seed has no die at all: that is what every exact number
	# in this suite and in reports/combat.md is.
	equal(Damage.swing_for(Damage.NO_DIE, attacker, target, 16), Damage.STEADY,
		"a fight seeded NO_DIE rolls STEADY, which is the deterministic model")
	var board := _board()
	var unseeded := CombatResolution.strike(board, pieces, attacker, target, 16)
	equal(unseeded["rolled"], false, "and a strike with no seed says so")
	equal(unseeded["swing"], Damage.STEADY, "with the die switched off")
	check(not CombatResolution.describe_strike(unseeded).contains("swing="),
		"so its transcript line carries no swing to read")

	# A fight's seed is the world's, folded with where on the map it is. Two
	# places in one world are two different fights; the same place twice is one.
	equal(Damage.fight_seed_for(1234, 40.0, -12.0),
		Damage.fight_seed_for(1234, 40.0, -12.0),
		"the same fight in the same world has the same seed")
	not_equal(Damage.fight_seed_for(1234, 40.0, -12.0),
		Damage.fight_seed_for(1234, 400.0, -12.0),
		"a fight elsewhere in the same world does not")
	not_equal(Damage.fight_seed_for(1235, 40.0, -12.0),
		Damage.fight_seed_for(1234, 40.0, -12.0),
		"and neither does the same place in another world")
	var never_off := true
	for world_seed in range(0, 500):
		if Damage.fight_seed_for(world_seed, 0.0, 0.0) == Damage.NO_DIE:
			never_off = false
	check(never_off, "and no world seed produces a fight with the die switched off")


## Whatever the die does, minion against minion is untouched.
##
## The task's standing boundary. It is structurally true -- `capture()` never
## reaches the seam, which the source scan checks by reading the function's body
## -- and it is checked here by playing the same capture under two hundred
## different fight seeds and requiring one answer.
func _no_die_reaches_the_minion_layer() -> void:
	var board := _board()
	var outcomes := {}
	for seed_value in range(1, 201):
		var pieces := PieceMap.new()
		var weak := pieces.add(Minion.of_kind(Minion.CAT, 101, Vector2i(6, 6), LOW))
		var strong := pieces.add(Minion.of_kind(Minion.ENT, 202, Vector2i(7, 7), HIGH))
		pieces.piece_of(weak).health = 1
		var outcome := CombatResolution.minion_action(
			board, pieces, pieces.piece_of(weak), Vector2i(7, 7), seed_value
		)
		outcomes[CombatResolution.describe(outcome)] = true
		check(not outcome.has("swing"), "a capture has no roll to report")
		equal(pieces.piece_of(strong), null,
			"seed %d: a level-1 Cat on one hit point still takes a level-40 Ent"
			% seed_value)
		equal(pieces.piece_of(weak).health, 1, "and is still on its last point")
	equal(outcomes.size(), 1,
		"200 fight seeds produced one capture, written the same way every time")


## A unit on a cliff edge or beside a hole is shoved into it and removed at once.
##
## Both kinds of hole, and both of the two branches that kill: a cell with
## nothing to stand on, and a cell whose floor is further down than a piece can
## climb. And the third case, which is the one that shows the first two are about
## the ground: shoved onto plain ground, the target simply takes a step.
func _a_shove_is_an_attack_that_pushes() -> void:
	var cases := [
		{"target": Vector2i(6, 2), "attacker": Vector2i(6, 3), "into": Vector2i(6, 1),
			"as": "into the chasm"},
		{"target": Vector2i(8, 8), "attacker": Vector2i(8, 7), "into": Vector2i(8, 9),
			"as": "over the lip of the pit"},
	]
	for one in cases:
		var board := _board()
		var pieces := PieceMap.new()
		var pusher := _commander(pieces, one["attacker"], 3, Weapon.shield(), [])
		pusher.face(_facing_towards(one["target"] - one["attacker"]))
		var victim := _commander(pieces, one["target"], 8, Weapon.sword(),
			[Armour.chestplate()])
		var doomed := victim.id
		var minion := pieces.add(Minion.of_kind(Minion.CAT, doomed, Vector2i(11, 11), 8))
		equal(victim.health, 68, "the victim is a level-8 commander at 68 hit points")

		var shove := CombatResolution.commander_attack(board, pieces, pusher, 0, 1)
		var hit: Dictionary = shove["hits"][0]
		equal(hit["dealt"], 0, "a shove deals no damage at all %s" % one["as"])
		equal(hit["fell"], true, "the target goes over %s" % one["as"])
		equal(hit["pushed_to"], one["into"], "into the cell beyond it")
		equal(pieces.piece_of(doomed), null,
			"and is removed instantly, at 68 hit points and level 8")
		equal(pieces.piece_of(minion), null,
			"taking its minions with it, by the same king rule as any other death")

	# Broken: the same shove with plain ground beyond it moves the target one
	# cell and does nothing else.
	var board := _board()
	var pieces := PieceMap.new()
	var pusher := _commander(pieces, Vector2i(2, 7), 3, Weapon.shield(), [])
	pusher.face(PieceGeometry.NORTH)
	var victim := _commander(pieces, Vector2i(2, 6), 8, Weapon.sword(), [])
	var shove := CombatResolution.commander_attack(board, pieces, pusher, 0, 1)
	var hit: Dictionary = shove["hits"][0]
	equal(hit["fell"], false, "over plain ground nobody falls")
	equal(hit["pushed"], true, "the target is pushed")
	equal(victim.cell, Vector2i(2, 5), "one cell further from its attacker")
	equal(victim.health, victim.max_health(), "and is otherwise untouched")


## A push of two obeys the same four checks a push of one does, at every cell it
## crosses rather than only at the far end.
##
## The board below puts one feature on the row between the victim and where a
## push of two would land it, and the same push is run at every distance from
## zero to two. At distance one the feature is adjacent and the answer is the one
## the shove has always given; at distance two the far cell is plain ground in
## every column, so a push that read only where it lands would set the victim
## down there unharmed in all four cases.
##
## ```
##  y=0   . . . . . . . . . . . . .
##  y=1   . . . . . . . . . . . . .     where a push of two aims: plain, always
##  y=2   . ~ . . . # . . . v . E .     a chasm, a building, the pit, an Ent
##  y=3   . . . . . . . . . . . . .     the victim's row
##  y=4   . . . . . . . . . . . . .     the pusher's row
##  y=5   . . . . . . . . . . . . .
## ```
func _a_shove_of_many_cells_is_the_rule_applied_once_per_cell() -> void:
	var rows := PackedStringArray(SHOVE_MAP)
	var ent_at := Vector2i(11, 2)

	# Column 3 is plain the whole way: the distance is read, and read as cells.
	for distance in [0, 1, 2]:
		var open := _shove(rows, Vector2i(3, 3), distance)
		var walked: Commander = open["victim"]
		equal(walked.cell, Vector2i(3, 3 - distance),
			"over plain ground a push of %d moves the victim %d cells" % [
				distance, distance,
			])
		equal(open["hit"]["pushed"], distance > 0,
			"and a push of %d pushes exactly when it is more than zero" % distance)
		equal(open["hit"]["pushed_to"], Vector2i(3, 3 - distance),
			"naming the cell it ended in")
		equal(walked.health, walked.max_health(), "and never touches its health")

	# The four features, each on the cell a push of two crosses.
	var cases := [
		{"x": 1, "what": "a chasm", "kills": true, "ent": false},
		{"x": 5, "what": "a building footprint", "kills": false, "ent": false},
		{"x": 9, "what": "an eight-unit pit", "kills": true, "ent": false},
		{"x": 11, "what": "an Ent", "kills": false, "ent": true},
	]
	for one in cases:
		var column: int = one["x"]
		var feature := Vector2i(column, 2)
		var bystander := ent_at if one["ent"] else Vector2i(-1, -1)
		var kills: bool = one["kills"]

		# Nothing at all at a push of zero -- the same as any attack that is not
		# a shove.
		var still := _shove(rows, Vector2i(column, 3), 0, bystander)
		equal(still["hit"]["pushed"], false, "a push of 0 pushes nobody, past %s" % one["what"])
		equal(still["hit"]["fell"], false, "and nobody falls")
		equal((still["victim"] as Commander).cell, Vector2i(column, 3),
			"the victim has not moved")

		# A push of one, into the feature: what the shove has always done.
		var near := _shove(rows, Vector2i(column, 3), 1, bystander)
		equal(near["hit"]["fell"], kills,
			"a push of 1 into %s %s" % [one["what"], "kills" if kills else "does not kill"])
		equal(near["hit"]["pushed"], false,
			"and never moves the victim onto %s" % one["what"])
		if kills:
			equal(near["hit"]["pushed_to"], feature, "it dies in the cell it was pushed into")
			equal((near["pieces"] as PieceMap).piece_of(
				(near["victim"] as Commander).id), null, "and is removed")
		else:
			equal(near["hit"]["pushed_to"], Vector2i(column, 3),
				"the push stops and the outcome names the cell it never left")
			equal((near["victim"] as Commander).cell, Vector2i(column, 3),
				"where the victim is still standing")

		# A push of two, over the same feature: the second cell is never reached,
		# because the first one stops or kills.
		var far := _shove(rows, Vector2i(column, 3), 2, bystander)
		equal(far["hit"]["fell"], kills,
			"a push of 2 over %s comes out the same way as a push of 1" % one["what"])
		var ended: Vector2i = feature if kills else Vector2i(column, 3)
		equal(far["hit"]["pushed_to"], ended,
			"stopping or dying at (%d,%d), not crossing to (%d,1)" % [
				ended.x, ended.y, column,
			])
		if kills:
			equal((far["pieces"] as PieceMap).piece_of(
				(far["victim"] as Commander).id), null,
				"the victim is removed at %s rather than carried over it" % one["what"])
		else:
			equal((far["victim"] as Commander).cell, Vector2i(column, 3),
				"the victim is stopped by %s rather than carried over it" % one["what"])
			equal((far["victim"] as Commander).health,
				(far["victim"] as Commander).max_health(), "at full health")
		if one["ent"]:
			var standing := (far["pieces"] as PieceMap).piece_at(ent_at)
			check(standing != null, "and the Ent is still standing where it was")
			equal(standing.kind, Minion.ENT, "still an Ent, unshoved and uncaptured")


## A push stopped or killed part-way names the cell it reached, not the one it
## was aimed at -- and every cell before that one was walked.
func _a_shove_stopped_part_way_reports_where_it_stopped() -> void:
	var rows := PackedStringArray(SHOVE_MAP)

	# Aimed at (5,1) from (5,4): one plain cell, then the building.
	var blocked := _shove(rows, Vector2i(5, 4), 3)
	equal(blocked["hit"]["pushed"], true, "the first cell of the push is taken")
	equal(blocked["hit"]["fell"], false, "a building is not a fall")
	equal(blocked["hit"]["pushed_to"], Vector2i(5, 3),
		"and the outcome names (5,3), the last cell reached, not the aimed (5,1)")
	equal((blocked["victim"] as Commander).cell, Vector2i(5, 3),
		"where the victim is left standing")

	# Aimed at (1,1) from (1,4): one plain cell, then the chasm.
	var doomed := _shove(rows, Vector2i(1, 4), 3)
	equal(doomed["hit"]["fell"], true, "the second cell of the push is the chasm")
	equal(doomed["hit"]["pushed_to"], Vector2i(1, 2),
		"and the outcome names the cell it died in, not the aimed (1,1)")
	equal((doomed["pieces"] as PieceMap).piece_of(
		(doomed["victim"] as Commander).id), null, "the victim is gone")

	# Aimed at (7,-2) from (7,1): the board's edge stops the walk at (7,0).
	var edge := _shove(rows, Vector2i(7, 1), 3)
	equal(edge["hit"]["fell"], false, "the edge of the board is not a hole")
	equal(edge["hit"]["pushed"], true, "the one cell there was room for was taken")
	equal(edge["hit"]["pushed_to"], Vector2i(7, 0), "and the push stops on the last row")
	equal((edge["victim"] as Commander).cell, Vector2i(7, 0),
		"with the victim standing on it")


## The shove is an attack, so it obeys everything an attack obeys: the pattern,
## the facing that rotates it, and the cooldown.
func _a_shove_obeys_facing_and_pattern_and_cooldown() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var pusher := _commander(pieces, Vector2i(6, 3), 3, Weapon.shield(), [])
	var victim := _commander(pieces, Vector2i(6, 2), 8, Weapon.sword(), [])
	var shove := pusher.attack_at(0)
	equal(shove.attack_name, "shove", "the shield carries one attack, the shove")
	equal(shove.damage, 0, "worth no damage")
	equal(shove.push, 1, "and a push of one cell")
	equal(shove.cooldown, 2, "on a two-turn cooldown")

	# Facing: looking away, the pattern does not cover the target at all.
	pusher.face(PieceGeometry.SOUTH)
	equal(LegalMoves.attack_cells_on(board, pusher, 0),
		[Vector2i(6, 4)] as Array[Vector2i],
		"facing south the shove reaches the cell behind, not the one ahead")
	var missed := CombatResolution.commander_attack(board, pieces, pusher, 0, 1)
	equal((missed["hits"] as Array).size(), 0, "so it lands on nobody")
	equal(pieces.piece_of(victim.id).cell, Vector2i(6, 2), "and the target has not moved")

	# Turned back, the same call reaches it -- and turning cost nothing.
	pusher.face(PieceGeometry.NORTH)
	equal(LegalMoves.attack_cells_on(board, pusher, 0),
		[Vector2i(6, 2)] as Array[Vector2i], "turned back, it reaches the target")

	# Cooldown: the miss above spent it on turn 1, so turn 2 is refused.
	check(not pusher.can_attack(0, 2), "a two-turn cooldown is not up one turn later")
	var early := CombatResolution.commander_attack(board, pieces, pusher, 0, 2)
	equal(early.get("ok", true), false, "so the shove is refused on turn 2")
	equal(early.get("reason", ""), "on cooldown", "for that reason and no other")
	check(pieces.piece_of(victim.id) != null, "and the target is still standing")
	check(pusher.can_attack(0, 3), "and on turn 3 it is ready")
	var landed := CombatResolution.commander_attack(board, pieces, pusher, 0, 3)
	equal(landed["hits"][0]["fell"], true, "and this time the target goes into the chasm")


# --- N commanders, no fixed sides -----------------------------------------


## Capture and targeting are pairwise. Any commander may target any other, and
## nothing anywhere groups two owners together.
func _commanders_have_no_fixed_sides() -> void:
	var board := _board()
	var pieces := PieceMap.new()
	var one := _commander(pieces, Vector2i(2, 2), 3, Weapon.sword(), [])
	var two := _commander(pieces, Vector2i(6, 6), 3, Weapon.sword(), [])
	var three := _commander(pieces, Vector2i(10, 10), 3, Weapon.sword(), [])

	# Every commander's minion may take every other commander's minion, in every
	# one of the six ordered pairs.
	var owners := [one.id, two.id, three.id]
	for attacker_owner in owners:
		for target_owner in owners:
			if attacker_owner == target_owner:
				continue
			var board_pieces := PieceMap.new()
			var attacker := board_pieces.add(
				Minion.of_kind(Minion.CAT, attacker_owner, Vector2i(6, 6), 3)
			)
			var target := board_pieces.add(
				Minion.of_kind(Minion.ENT, target_owner, Vector2i(7, 7), 3)
			)
			check(LegalMoves.captures_for(board, board_pieces,
					board_pieces.piece_of(attacker)).has(Vector2i(7, 7)),
				"#%d's minion may take #%d's" % [attacker_owner, target_owner])
			CombatResolution.minion_action(board, board_pieces,
				board_pieces.piece_of(attacker), Vector2i(7, 7))
			equal(board_pieces.piece_of(target), null,
				"and does, with nobody on anybody's side")

	# And a minion may not take its own commander's minion, which is the one
	# comparison that exists -- owner against owner, never side against side.
	var friendly := PieceMap.new()
	var mine := friendly.add(Minion.of_kind(Minion.CAT, one.id, Vector2i(6, 6), 3))
	friendly.add(Minion.of_kind(Minion.ENT, one.id, Vector2i(7, 7), 3))
	check(not LegalMoves.captures_for(board, friendly,
			friendly.piece_of(mine)).has(Vector2i(7, 7)),
		"and may not take one of its own")
	equal(three.id, 3, "three commanders, and no two of them on a side")


## A three-commander match, scripted, played to one survivor.
func _a_three_commander_match_runs_to_a_conclusion() -> void:
	var transcript := ScriptedMatch.play()
	check(transcript.size() > 30, "the transcript is a whole match, not a stub")
	equal(transcript[1], "dice seed=%d swing=%d..%d" % [
		ScriptedMatch.SEED, Damage.SWING_LOW, Damage.SWING_HIGH,
	], "the transcript says what die was in play before any blow is struck")
	equal(transcript[2], "commanders 3", "three commanders start it")

	var conclusion := transcript[transcript.size() - 1]
	equal(conclusion, "over rounds=6 survivors=1 winner=#1",
		"and it ends in round 6 with one of them left")

	# The three things the transcript has to contain, written out exactly.
	var joined := "\n".join(transcript)
	check(joined.contains(
		"hit #1->#2 power=0 x150 swing=99 flank def=0 dealt=0 hp=32/32"
		+ " shoved into (6,1) removed=2"),
		"#1 shoves #2 into the chasm at full health, taking a surviving minion with it")
	check(joined.contains(
		"hit #1->#3 power=0 x100 swing=96 front def=0 dealt=0 hp=26/26"
		+ " shoved into (8,9) removed=3"),
		"#1 shoves #3 into the pit, taking both its minions with it")
	check(joined.contains(
		"hit #3->#1 power=4 x200 swing=101 back def=1 dealt=7 hp=31/38"),
		"#3 backstabs #1 for 7 in round 3, off a level-1 spear against one point of"
		+ " armour bought by a level-3 loadout, the die rolling 101 of a possible"
		+ " %d..%d" % [Damage.SWING_LOW, Damage.SWING_HIGH])
	check(joined.contains("refused attack #1: on cooldown"),
		"and #1's shove is refused while it is on its cooldown")
	check(joined.contains("capture #11 takes #8"),
		"#3's level-1 Frog takes #2's level-2 Ent, allied with nobody")


## Two plays of the scripted match are the same match.
func _the_scripted_match_plays_the_same_way_every_time() -> void:
	equal(ScriptedMatch.play(), ScriptedMatch.play(),
		"the same decisions on the same board play out the same way")


## And two *processes* playing it print the same bytes.
##
## In-process repetition cannot see a dependence on an address or on the order a
## dictionary happens to iterate in; a second process can, because it lays its
## memory out differently.
func _two_processes_play_the_same_match() -> void:
	var first := _run_match()
	var second := _run_match()
	equal(first["exit_code"], 0,
		"./run_match.sh should exit 0 (output: %s)" % first["output"])
	equal(second["exit_code"], 0, "and so should the second run")
	check(not str(first["output"]).strip_edges().is_empty(),
		"the match command printed nothing")
	equal(first["output"], second["output"],
		"two processes should print the same match, byte for byte")
	check(str(first["output"]).contains("over rounds=6 survivors=1 winner=#1"),
		"and it should be the match that concludes")


# --- The stop condition ---------------------------------------------------


## The binary capture rule and the numeric layer coexist across the whole level
## range: no configuration makes a commander unkillable, and none makes one
## trivially killable.
##
## The two ends are what the task asked to be checked and reported. A blow always
## lands for at least one point, so every fight is finite; and a commander's
## health grows with its level, so no fight is over in one blow that should not
## be. The numbers themselves are in reports/combat.md.
func _no_level_gap_breaks_the_two_layers() -> void:
	var board := _board()
	# The worst case for the attacker: the weakest weapon in the catalogue, no
	# positioning at all, against the heaviest armour there is.
	var worst := Damage.resolve(Weapon.dagger().attack_at(0).damage, Damage.NONE, 100)
	equal(worst, Damage.MINIMUM, "a hopeless blow still lands for exactly 1")
	check(worst > 0, "so no amount of armour makes a commander unkillable")

	# The best case for the attacker against the toughest commander at level 40:
	# the fight is still several blows long, so nobody is trivially killable.
	var toughest := Damage.commander_health(HIGH)
	equal(toughest, 260, "a level-40 commander stands at 260 hit points")
	var heaviest := Damage.resolve(
		Weapon.sword().attack_at(1).damage, Damage.BACK * Damage.HIGH_GROUND / 100, 8
	)
	equal(heaviest, 40, "a cleave, backstabbing from high ground, is 40")
	equal(int(ceil(float(toughest) / float(heaviest))), 7,
		"so the very best blow in the catalogue needs 7 landings")

	# And the tactical layer is untouched by all of it, at both ends.
	var pieces := PieceMap.new()
	var taker := pieces.add(Minion.of_kind(Minion.FROG, 101, Vector2i(6, 6), LOW))
	pieces.add(Minion.of_kind(Minion.ENT, 202, Vector2i(7, 8), HIGH))
	CombatResolution.minion_action(board, pieces, pieces.piece_of(taker), Vector2i(7, 8))
	equal(pieces.size(), 1,
		"a level-1 Frog still takes a level-40 Ent, whatever the numbers did")


# --- Helpers --------------------------------------------------------------


func _board() -> CombatBoard:
	return BoardSketch.from_rows(PackedStringArray(MAP))


func _commander(
	pieces: PieceMap, at: Vector2i, at_level: int, held: Weapon, worn: Array
) -> Commander:
	var commander := Commander.make(at, PieceGeometry.NORTH, AssetTags.KNIGHT, at_level)
	for piece in worn:
		commander.equip(piece)
	commander.wield(held)
	pieces.add(commander)
	return commander


## One shove, set up from nothing: a pusher standing one cell south of the victim
## and facing it, carrying a weapon whose only attack is a shove of the given
## distance. The weapon is built here rather than taken from the catalogue,
## because the catalogue's one shove pushes one cell and this is about the rest.
##
## `bystander_at` puts an Ent of nobody's on a cell, for the case where what
## stops the push is a piece rather than the ground.
func _shove(
	rows: PackedStringArray,
	victim_at: Vector2i,
	distance: int,
	bystander_at: Vector2i = Vector2i(-1, -1),
) -> Dictionary:
	var board := BoardSketch.from_rows(rows)
	var pieces := PieceMap.new()
	var ahead: Array[Vector2i] = [Vector2i(0, -1)]
	var heave: Array[Attack] = [Attack.make("heave", ahead, 1, 0, distance)]
	var pusher := _commander(
		pieces, victim_at + Vector2i(0, 1), 3, Weapon.make("pole", heave), []
	)
	pusher.face(PieceGeometry.NORTH)
	var victim := _commander(pieces, victim_at, 8, Weapon.sword(),
		[Armour.chestplate()])
	if bystander_at.x >= 0:
		pieces.add(Minion.of_kind(Minion.ENT, 99, bystander_at, 8))
	var swung := CombatResolution.commander_attack(board, pieces, pusher, 0, 1)
	return {"hit": swung["hits"][0], "victim": victim, "pieces": pieces}


## A full suit off creatures of one level, each piece buying its slot's movement
## capability first and putting everything left into taking blows.
func _mobile_suit(at_level: int = 8) -> Array:
	var worn: Array = []
	for slot in Armour.SLOTS:
		worn.append(Armour.worn(slot, at_level))
	return worn


## The same four slots at the same level, with nothing spent on moving at all.
## At level 8 that is four times thirty-two points, which is eight of reduction.
func _armoured_suit(at_level: int = 8) -> Array:
	var worn: Array = []
	for slot in Armour.SLOTS:
		worn.append(Armour.worn(slot, at_level, ItemRarity.COMMON, 0))
	return worn


## How many blows of a given size a commander at full health survives.
func _blows_to_kill(commander: Commander, dealt: int) -> int:
	return int(ceil(float(commander.max_health()) / float(maxi(1, dealt))))


## The swing a blow would roll against a target on a given health, without
## leaving the target on it.
func _swing_at_health(
	fight_seed: int, attacker: Piece, target: Piece, power: int, health: int
) -> int:
	var was := target.health
	target.health = health
	var swing := Damage.swing_for(fight_seed, attacker, target, power)
	target.health = was
	return swing


## Which way to look to see a cell in a given direction.
static func _facing_towards(offset: Vector2i) -> int:
	if absi(offset.x) > absi(offset.y):
		return PieceGeometry.EAST if offset.x > 0 else PieceGeometry.WEST
	return PieceGeometry.SOUTH if offset.y > 0 else PieceGeometry.NORTH


## Every script of the combat layer, for the seam check to read.
## Every GDScript file under sim/, found by reading the directory.
##
## Discovered rather than listed so that a file added tomorrow is covered by the
## checks above without anybody remembering to come back here.
func _sim_sources() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(SIM_DIR)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.get_extension() == "gd":
			found.append(SIM_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


## The files of the combat layer: every file the scan found that names one of the
## layer's own class names, less the world root, which is excused above.
func _combat_sources() -> PackedStringArray:
	var found := PackedStringArray()
	for path in _sim_sources():
		if path == WORLD_ROOT:
			continue
		if _names_combat_class(_read(path)):
			found.append(path)
	return found


## Whether a source names any class of the combat layer, whole words only.
##
## The vocabulary is `LayerCheck`'s, so there is one written-down answer to what
## the combat layer is called and both structural checks read it: that check
## forbids the render layer to name any of them, this one requires every file
## that does name one to stay free of a random source.
func _names_combat_class(text: String) -> bool:
	return LayerCheck.first_combat_match(text) != "" \
		or LayerCheck._contains_word(text, BOARD_CLASS)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


## Run the documented command in its own process, and capture what it printed.
func _run_match() -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/match_main.gd",
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}
