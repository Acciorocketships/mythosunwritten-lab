extends TestSuite
## A fight you walk into, played to its end from the keyboard, and one you leave.
##
## `tests/test_player_combat.gd` plays a whole fight from key presses on the
## *battle* stage, where the scenario musters the two commanders next to each
## other and each is the only one on its side. That is not the fight a person
## actually meets. On the play stage a person walks east into a brawler and the
## trader they were haggling with a moment ago is standing near enough to be
## taken onto the board with them -- and a fight in that shape could not be
## brought to an end at all. This suite is that fight, and it exists so that the
## measured failure cannot come back quietly.
##
## Five claims:
##
##   1. **Two commanders of one band are one side on the board.** The world sorts
##      characters into bands and the engagement rule reads them; the board had no
##      word for a band and made every commander its own owner, so the trader who
##      came along arrived as somebody to kill. Seating now writes the band in
##      (`Encounter._seat`), and the claim is asked of the pieces themselves.
##   2. **A fight walked into ends from the keyboard, in a bounded number of
##      rounds**, with the board put away and the world back in real time -- and
##      the ally is still standing when it is, which is what says the fight was
##      not ended by killing them.
##   3. **A commander a rule is driving moves on the board.** Not a person: the
##      brawler, whose turns are `CombatPolicy`'s, is somewhere else at the end of
##      the fight than the snap put her. "The board decides where a fighter goes"
##      was never "a mind cannot move", and this is the difference written down.
##   4. **A fight can be left.** One press takes the person off the board, alive,
##      with what they carry, and back into real time -- and the fight they left
##      is not their fight any more.
##   5. **Leaving is refused when it is not yours to ask**, in the match's own
##      words, and changes nothing -- and the refusal is not mistaken for a
##      departure by whoever asked. A refusal writes a line into the fight's
##      transcript like anything else, so a caller reading "something was
##      written" as "it was done" reports a refused leave as a successful one.
class_name TestWalkInFight

## The stage and its seed: the play stage, which is the one a person is handed
## when they play at all.
const SEED := ScriptedPlay.SEED

## How many ticks the run gives the person to walk east into the brawler before
## it gives up waiting for a board. A walk key is one `go_to` of
## `PlayerControls.STEP`, which is four strides and costs the four ticks it takes
## to walk them (`ControlLoop.occupies`).
const CLOSING := 400

## How many ticks the fight is given once it has begun. `Encounter.MAX_ROUNDS` is
## the fight's own bound; this is generous against it, so a run that stops here
## has found something rather than run out of patience.
const PATIENCE := 900

## How many of the person's own turns the run will take before it stops taking
## them. Higher than any fight of this size needs, so that "bounded" is the
## fight's own bound and not this number.
const TURNS := 30

## Which weapon action the person leads with. The first, which is the one that
## comes round every turn.
const QUICK := 0


func _init() -> void:
	suite_name = "walk-in fight"


func run() -> void:
	var played := play()
	_a_band_is_one_side_on_the_board(played)
	_the_fight_ends_from_the_keyboard(played)
	_a_rule_driven_commander_moved(played)
	var left := leave()
	_a_fight_can_be_left(left)
	_leaving_is_refused_out_of_turn(left)


# --- The run that is fought to its end -------------------------------------


## Walk east into the brawler and play the fight out from key presses.
##
## Every board press goes through `render/board_controls.gd`, which is the file
## the shell feeds real presses through, and every real-time press through
## `render/player_controls.gd`. Nothing here calls the match or the board.
static func play() -> Dictionary:
	var run := _walk_into_a_fight()
	if not bool(run["ok"]):
		return run
	var sim: Simulation = run["sim"]
	var controls: BoardControls = run["controls"]
	var taken := 0
	for _tick in PATIENCE:
		if sim.world.combat.scene.fight == null:
			break
		var turn := sim.driven_turn()
		if turn == null or taken >= TURNS:
			sim.step()
			continue
		taken += 1
		_step_towards_the_enemy(sim, controls)
		_turn_until_something_is_covered(sim, controls)
		_press(sim, controls, BoardControls.SWING_KEYS[QUICK])
		_press(sim, controls, BoardControls.KEY_END_TURN)
	run["rounds"] = taken
	if sim.world.combat.scene.fight == null:
		run["left_at"] = sim.world.tick
	run["over_line"] = _the_line_it_ended_on(sim)
	run["enemy_cell_after"] = _cell_of(run, "enemy")
	run["ally_health_after"] = _health_of(run, "ally")
	run["enemy_alive_after"] = _alive(run, "enemy")
	run["me_alive_after"] = _alive(run, "me")
	return run


## Walk east into the brawler and then press the one key that leaves a fight.
static func leave() -> Dictionary:
	var run := _walk_into_a_fight()
	if not bool(run["ok"]):
		return run
	var sim: Simulation = run["sim"]
	var controls: BoardControls = run["controls"]
	var me: Combatant = run["me"]
	# Somebody else's turn: leaving is not this person's to ask for, and the
	# match says so. Asked twice -- of the match, and of the whole way in a
	# person's press takes -- because a refusal that is written down is still a
	# refusal, and the fight must not report the line it wrote as a departure.
	var fight: Encounter = sim.world.combat.scene.fight
	var other: Combatant = fight.by_piece.get(_other_piece_id(sim, me), null)
	run["out_of_turn"] = fight.match_state.withdraw(_other_piece_id(sim, me))
	run["out_of_turn_reason"] = fight.match_state.last_refusal
	run["refused_wrote"] = fight.leave(other).size()
	run["refused_still_fighting"] = other != null and other.fighting
	run["refused_still_seated"] = fight.members.has(other)
	run["commanders_before"] = sim.world.combat.scene.fight.match_state.commander_count()
	for _tick in PATIENCE:
		var turn := sim.driven_turn()
		if turn != null:
			run["answer"] = controls.press(BoardControls.KEY_LEAVE, turn)
			break
		sim.step()
	run["left_at"] = sim.world.tick
	run["still_fighting"] = me.fighting
	run["carries"] = ActionScene.inventory_of(me).size()
	run["health"] = me.piece.health
	run["on_a_board"] = sim.driven_turn() != null
	# One more tick, so that whatever the fight does about somebody having walked
	# out of it has happened by the time the claim is asked.
	sim.step()
	run["fight_after"] = sim.world.combat.scene.fight != null
	return run


# The half both runs share: the play stage, the person handed one of its three,
# and as many walk keys east as it takes for the board to appear.
static func _walk_into_a_fight() -> Dictionary:
	var sim := Simulation.new(SEED)
	var run := {
		"sim": sim,
		"ok": false,
		"entered": -1,
		"left_at": -1,
		"rounds": 0,
		"controls": BoardControls.new(),
		"walking": PlayerControls.new(),
	}
	if not sim.begin_scenario(Simulation.SCENARIO_PLAY):
		return run
	if not sim.hand_over_followed():
		return run
	var scene: ActionScene = sim.world.combat.scene
	run["me"] = _named(scene, ScriptedPlay.FEN)
	run["ally"] = _named(scene, ScriptedPlay.HOB)
	run["enemy"] = _named(scene, ScriptedPlay.RILL)
	for _tick in CLOSING:
		if scene.fight != null:
			break
		if (sim.driven as LiveChoice).standing() == null:
			sim.drive(PlayerControls.walk(PlayerControls.direction_of(KEY_D)))
		sim.step()
	if scene.fight == null:
		return run
	run["ok"] = true
	run["entered"] = sim.world.tick
	run["seated"] = _seating(run)
	run["enemy_cell_at_the_snap"] = _cell_of(run, "enemy")
	return run


# --- The presses -----------------------------------------------------------


# Cycle the ring of cells the board is offering, stop on the one nearest the
# enemy commander, and step onto it. Which cells are on offer is the
# simulation's answer; this only chooses among them, which is the person reading
# the board.
static func _step_towards_the_enemy(sim: Simulation, controls: BoardControls) -> void:
	var turn := sim.driven_turn()
	if turn == null:
		return
	var offered := turn.move_cells()
	var quarry := _quarry(turn)
	if offered.is_empty() or quarry == null:
		return
	var best := offered[0]
	for cell in offered:
		if _apart(cell, quarry.cell) < _apart(best, quarry.cell):
			best = cell
	for _press_count in offered.size() + 1:
		if controls.has_cell and controls.cell == best:
			break
		controls.press(BoardControls.KEY_PICK_CELL, sim.driven_turn())
	_press(sim, controls, BoardControls.KEY_STEP)


# Turn a quarter at a time until a weapon covers somebody on the other side, or
# all the way round and back. Free, so it costs the turn nothing.
static func _turn_until_something_is_covered(
	sim: Simulation, controls: BoardControls
) -> void:
	for _quarter in 4:
		var turn := sim.driven_turn()
		if turn == null or _covers_an_enemy(turn):
			return
		controls.press(BoardControls.KEY_TURN_RIGHT, turn)


static func _press(sim: Simulation, controls: BoardControls, keycode: int) -> Dictionary:
	var turn := sim.driven_turn()
	return {} if turn == null else controls.press(keycode, turn)


# --- The claims -------------------------------------------------------------


func _a_band_is_one_side_on_the_board(run: Dictionary) -> void:
	check(bool(run["ok"]), "the play stage walked into a fight")
	if not bool(run["ok"]):
		return
	var seated: Dictionary = run["seated"]
	equal(seated["commanders"], 3,
		"all three of the play stage's characters are seated as commanders")
	equal(seated["sides"], 2, "three commanders in two bands are two sides")
	check(seated["me_side"] == seated["ally_side"],
		"the person and the trader they came with are on one side")
	check(seated["me_side"] != seated["enemy_side"],
		"the brawler is on the other")
	check(seated["me_owner"] != seated["ally_owner"],
		"and they are still two owners, so a minion still knows whose it is")


func _the_fight_ends_from_the_keyboard(run: Dictionary) -> void:
	if not bool(run["ok"]):
		return
	check(int(run["left_at"]) > 0,
		"the board is put away and the world is back in real time")
	check(int(run["rounds"]) > 0 and int(run["rounds"]) <= Encounter.MAX_ROUNDS,
		"the fight took %d rounds, inside the fight's own bound of %d" % [
			int(run["rounds"]), Encounter.MAX_ROUNDS])
	check(int(run["left_at"]) > int(run["entered"]),
		"it was put away after it appeared: t=%d to t=%d" % [
			int(run["entered"]), int(run["left_at"])])
	check(String(run["over_line"]).contains("ending=%s" % Encounter.DECIDED),
		"it was decided rather than called at the round limit: %s"
		% String(run["over_line"]))
	check(not bool(run["enemy_alive_after"]),
		"the fight ended because the brawler went down")
	check(bool(run["me_alive_after"]),
		"the person who walked into it is still standing")
	equal(run["ally_health_after"], (run["ally"] as Combatant).piece.max_health(),
		"and the trader who came along is untouched at the end of it")


func _a_rule_driven_commander_moved(run: Dictionary) -> void:
	if not bool(run["ok"]):
		return
	# The brawler has a decision function of her own -- she is one of the minds
	# the world drives -- and her board turns are `CombatPolicy`'s. This is the
	# claim that such a commander is not frozen where the snap put it.
	check((run["enemy"] as Combatant).piece.sheet != null
			and (run["enemy"] as Combatant).piece.sheet.decide.is_valid(),
		"the brawler carries a decision function, so she is a mind and not furniture")
	not_equal(run["enemy_cell_after"], run["enemy_cell_at_the_snap"],
		"a commander a rule is driving moved on the board rather than standing "
		+ "where the snap put it")


func _a_fight_can_be_left(run: Dictionary) -> void:
	check(bool(run["ok"]), "the second run walked into a fight too")
	if not bool(run["ok"]):
		return
	var answer: Dictionary = run.get("answer", {})
	check(bool(answer.get("ok", false)),
		"one press leaves the fight: %s" % str(answer.get("reason", "no answer")))
	check(not bool(run["still_fighting"]),
		"the person is no longer in a fight")
	check(not bool(run["on_a_board"]),
		"and has no turn standing on any board")
	check(int(run["health"]) > 0, "they left alive")
	check(int(run["carries"]) > 0,
		"and with what they carry: leaving is not falling, so nothing is spilled")


func _leaving_is_refused_out_of_turn(run: Dictionary) -> void:
	if not bool(run["ok"]):
		return
	check(not bool(run["out_of_turn"]),
		"a commander whose turn it is not may not walk out of the fight")
	check(String(run["out_of_turn_reason"]).contains("turn"),
		"and is refused in the match's own words: %s" % String(run["out_of_turn_reason"]))
	# A refusal writes a line of its own, and the fight used to hand that line
	# back as this call's writing -- so whoever read "something was written" as
	# "it was done" was told a refused leave had succeeded.
	equal(run["refused_wrote"], 0,
		"a refused leave writes nothing of its own, so it cannot be read as a departure")
	check(bool(run["refused_still_fighting"]),
		"and the one who could not leave is still in the fight")
	check(bool(run["refused_still_seated"]),
		"and still seated in it")


# --- Reading the world ------------------------------------------------------


static func _seating(run: Dictionary) -> Dictionary:
	var sim: Simulation = run["sim"]
	var pieces: PieceMap = sim.world.combat.scene.fight.match_state.pieces
	var commanders := 0
	var sides := {}
	for id in pieces.ids():
		var piece := pieces.piece_of(id)
		if piece == null or not piece.is_commander():
			continue
		commanders += 1
		sides[piece.side()] = true
	return {
		"commanders": commanders,
		"sides": sides.size(),
		"me_side": (run["me"] as Combatant).piece.side(),
		"ally_side": (run["ally"] as Combatant).piece.side(),
		"enemy_side": (run["enemy"] as Combatant).piece.side(),
		"me_owner": (run["me"] as Combatant).piece.owner_id,
		"ally_owner": (run["ally"] as Combatant).piece.owner_id,
	}


static func _cell_of(run: Dictionary, who: String) -> Vector2i:
	return (run[who] as Combatant).piece.cell


static func _health_of(run: Dictionary, who: String) -> int:
	return (run[who] as Combatant).piece.health


static func _alive(run: Dictionary, who: String) -> bool:
	return (run[who] as Combatant).is_alive()


# The piece id of some commander in the fight that is not this one's, so that
# leaving can be asked out of turn.
static func _other_piece_id(sim: Simulation, me: Combatant) -> int:
	var pieces: PieceMap = sim.world.combat.scene.fight.match_state.pieces
	for id in pieces.ids():
		var piece := pieces.piece_of(id)
		if piece != null and piece.is_commander() and piece.id != me.piece.id:
			return piece.id
	return 0


static func _quarry(turn: BoardTurn) -> Piece:
	var found: Piece = null
	var best := 0
	for id in turn.match_state.pieces.ids():
		var piece := turn.match_state.pieces.piece_of(id)
		if piece == null or not piece.is_commander() or not piece.opposes(turn.me):
			continue
		var far := _apart(turn.cell(), piece.cell)
		if found == null or far < best:
			found = piece
			best = far
	return found


static func _covers_an_enemy(turn: BoardTurn) -> bool:
	for index in turn.attacks().size():
		for cell in turn.attack_cells(index):
			var standing := turn.match_state.pieces.piece_at(cell)
			if standing != null and standing.opposes(turn.me):
				return true
	return false


# The one line a fight writes when it stops, out of the world's own transcript of
# the fights it has held. It says how it ended, which is the difference between a
# fight that was settled and one that was called at the round limit.
static func _the_line_it_ended_on(sim: Simulation) -> String:
	for line in sim.world.combat.scene.fight_lines:
		if line.begins_with("over ") and line.contains("ending="):
			return line
	return ""


static func _apart(from: Vector2i, to: Vector2i) -> int:
	return maxi(absi(from.x - to.x), absi(from.y - to.y))


static func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		if not (one.piece is Commander):
			continue
		var sheet := (one.piece as Commander).sheet
		if sheet != null and sheet.character_name == who:
			return one
	return null
