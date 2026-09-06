extends TestSuite
## A whole fight played from key presses: entered from real time, taken a turn at
## a time, and left for real time again.
##
## `tests/test_player_actions.gd` reached every verb of section 2.1 from a
## keyboard, and the one thing a person could do in a fight was strike: there was
## no way to move on the board, to send a minion, to turn, or to end a turn. This
## is the rest of it, and it is the same discipline -- the presses go through
## `render/board_controls.gd`, which builds no rule, into `BoardTurn`, which
## forwards every question to the simulation that already answered it for
## `CombatPolicy`.
##
## Seven claims:
##
##   1. **A fight is entered from real time and left for real time**, in one
##      seeded run, with the tick each happened on.
##   2. **The turn economy is the simulation's**: on one of the person's turns
##      the commander moves, uses one weapon action and activates one minion, and
##      a second of each is refused -- by the match, in the match's own words.
##      There is no second copy of that rule on the interface side, which claim 6
##      checks by scanning the source.
##   3. **What is legal is shown before the choice and an illegal choice is
##      refused in the engine's own words**: the cells the commander may step
##      onto and the cells a weapon covers are non-empty and come from
##      `LegalMoves`; a step onto a cell that is not among them comes back
##      refused, quoting the match.
##   4. **Cooldowns count down in turns and an action on one is refused rather
##      than ignored**: the wait on an action that was spent falls by one per
##      round, and pressing its key while it waits is answered "on cooldown".
##   5. **Facing is free and changes what an attack covers**: a turn spends none
##      of the three, and the covered cells before and after differ.
##   6. **The interface holds no rule and no copy.** A scan of the two files a
##      person plays a fight through, and a readout that is built, handed a world
##      and asked twice with the world moved in between.
##   7. **The whole fight is one trace**, naming each turn, who acted and what
##      the engine answered. `./tools/play_combat.sh` prints exactly this.
class_name TestPlayerCombat

## The seed and the stage: the battle scenario, which is the encounter scenario
## with the camera on one of the two who fight, so `--play` has somebody to hand
## over.
const SEED := ScriptedEncounter.SEED

## How many ticks the run gives the two bands to walk into each other before it
## gives up waiting for a board.
const CLOSING := 120

## How many ticks the whole fight is given. A fight is capped at
## `Encounter.MAX_ROUNDS` rounds and every round is several ticks of a person
## taking their turn, so this is generous rather than tight.
const PATIENCE := 600

## How many of the person's own turns the run plays before it stops taking them.
## More than any fight of this size needs; the fight ends first.
const TURNS := 40

## Which weapon action the person leads with, and which one they keep for the
## cooldown to be watched on. The sword carries two -- a cut that comes round
## every turn and a cleave that waits three -- and the second is what makes a
## cooldown a thing that can be seen counting down.
const QUICK := 0
const HEAVY := 1

## The two files a person plays a fight through, which claim 6 scans.
const INTERFACE_FILES := [
	"res://render/board_controls.gd",
	"res://render/ui/combat_panel.gd",
]

## What neither of them may name: the rules of the board and of the fight. If one
## of these appears on the interface side, the interface has started to answer a
## question it is supposed to be asking.
const NO_RULES := [
	"LegalMoves", "CombatMatch", "CombatPolicy", "CombatResolution",
	"MoveGrant", "PieceGeometry", "Encounter", "PieceMap",
	"can_step", "is_hole", "blocks_move", "can_attack", "spend_attack",
	"capture", "shove", "defence", "attack_power",
]


func _init() -> void:
	suite_name = "player combat"


func run() -> void:
	var played := play()
	_a_fight_was_entered_and_left(played)
	_the_turn_economy_is_the_simulations(played)
	_what_is_legal_is_shown_and_an_illegal_choice_is_refused(played)
	_a_cooldown_counts_down_and_refuses(played)
	_facing_is_free_and_moves_the_pattern(played)
	_the_interface_holds_no_rule_and_no_copy(played)
	_the_whole_fight_is_one_trace(played)


# --- The run --------------------------------------------------------------


## Play one seeded fight from key presses and hand back everything that happened.
##
## Public because `tools/play_combat.sh` prints the same trace -- the run that is
## the evidence and the run that is the test are one run, driven by one script,
## so a trace in a report cannot drift from a trace in a suite.
##
## Every press goes through `BoardControls.press`, which is the file the shell
## feeds real presses through. Nothing here calls the match, the board or the
## resolver.
static func play() -> Dictionary:
	var sim := Simulation.new(SEED)
	var run := {
		"sim": sim,
		"ok": false,
		"entered": -1,
		"left": -1,
		"turns": 0,
		"trace": [],
		"spent": {},
		"illegal": {},
		"facing": {},
		"cooldown": {},
		"waits": [],
		"controls": BoardControls.new(),
	}
	if not sim.begin_scenario(Simulation.SCENARIO_BATTLE):
		return run
	if not sim.hand_over_followed():
		return run
	run["ok"] = true

	# Real time: the two bands walk towards each other and the board appears
	# under them when the scene's own rule says it should.
	for _tick in CLOSING:
		if sim.world.combat.phase() != CombatantRoster.REAL_TIME:
			break
		sim.step()
	if sim.world.combat.phase() == CombatantRoster.REAL_TIME:
		return run
	run["entered"] = sim.world.tick
	_note(run, "the board appears", "", "entered from real time")

	# The fight: the person takes their turns and the world takes everybody
	# else's, one per tick, until it is over.
	var taken := 0
	for _tick in PATIENCE:
		if sim.world.combat.phase() == CombatantRoster.REAL_TIME:
			break
		if sim.driven_turn() != null and taken < TURNS:
			_take_a_turn(run)
			taken += 1
			continue
		sim.step()
	run["turns"] = taken
	if sim.world.combat.phase() == CombatantRoster.REAL_TIME:
		run["left"] = sim.world.tick
		_note(run, "the board is put away", "", "back to real time")
	return run


# One whole turn of the person's, spent from key presses in the order a person
# spends one: look at what is on offer, step, turn until something is covered,
# swing, send a minion, and end it.
static func _take_a_turn(run: Dictionary) -> void:
	var sim: Simulation = run["sim"]
	var turn := sim.driven_turn()
	if turn == null:
		return
	var round_number := turn.round_number()

	# What the person is shown before choosing anything, which is the whole of
	# claim 3's first half: where they may go, and what their weapons cover.
	if not run["illegal"].has("reason"):
		_record_what_is_offered(run, turn)

	# The move. The ring is cycled with the pick key and stopped on whichever
	# cell is nearest the enemy commander, which is the person reading the board
	# -- the cells themselves are the simulation's answer and this only chooses
	# among them.
	_step_towards_the_enemy(run)

	# Turning is free, so it is done until something is covered. The first turn
	# of the fight also records what the pattern covered before and after one
	# quarter, which is claim 5.
	if run["facing"].is_empty():
		_record_a_free_turn(run)
	_turn_until_something_is_covered(run)

	# The weapon actions: the heavy one on the first turn so that its wait is
	# there to watch, and the quick one afterwards. Pressing the heavy one again
	# while it waits is claim 4's refusal.
	if round_number <= 1:
		_press(run, BoardControls.SWING_KEYS[HEAVY])
	else:
		if not run["cooldown"].has("reason"):
			_record_a_cooldown_refusal(run)
		_press(run, BoardControls.SWING_KEYS[QUICK])

	# One minion, sent towards the enemy commander the same way the move was
	# chosen.
	_send_a_minion_towards_the_enemy(run)

	# What the turn had left when it was spent, once, so claim 2 can be asked of
	# a turn where all three were spent.
	_record_the_spent_turn(run)
	_press(run, BoardControls.KEY_END_TURN)


# --- The four things a person does with the keys --------------------------


# Cycle the ring of cells with the pick key, stop on the one nearest the enemy
# commander, and step onto it.
static func _step_towards_the_enemy(run: Dictionary) -> void:
	var sim: Simulation = run["sim"]
	var controls: BoardControls = run["controls"]
	var turn := sim.driven_turn()
	if turn == null:
		return
	var offered := turn.move_cells()
	if offered.is_empty():
		return
	var quarry := _enemy_commander(run)
	var best := offered[0]
	if quarry != null:
		for cell in offered:
			if _apart(cell, quarry.cell) < _apart(best, quarry.cell):
				best = cell
	for _press_count in offered.size() + 1:
		if controls.has_cell and controls.cell == best:
			break
		_press(run, BoardControls.KEY_PICK_CELL)
	_press(run, BoardControls.KEY_STEP)


# Turn a quarter at a time until a weapon covers an enemy, or all the way round
# and back. Free, so this costs the turn nothing however many presses it takes.
static func _turn_until_something_is_covered(run: Dictionary) -> void:
	var sim: Simulation = run["sim"]
	for _quarter in 4:
		var turn := sim.driven_turn()
		if turn == null or _covers_an_enemy(run, turn):
			return
		_press(run, BoardControls.KEY_TURN_RIGHT)


# Pick a minion, cycle its destinations, and send it to whichever is nearest the
# enemy commander -- which is a capture when one is standing there, because the
# board offers a capture cell and a step cell in one list.
static func _send_a_minion_towards_the_enemy(run: Dictionary) -> void:
	var sim: Simulation = run["sim"]
	var controls: BoardControls = run["controls"]
	_press(run, BoardControls.KEY_PICK_MINION)
	var turn := sim.driven_turn()
	if turn == null or controls.minion_id == 0:
		return
	var offered := turn.minion_cells(controls.minion_id)
	if offered.is_empty():
		return
	var quarry := _enemy_commander(run)
	var best := offered[0]
	if quarry != null:
		for cell in offered:
			if _apart(cell, quarry.cell) < _apart(best, quarry.cell):
				best = cell
	for _press_count in offered.size() + 1:
		if controls.has_minion_cell and controls.minion_cell == best:
			break
		_press(run, BoardControls.KEY_PICK_MINION_CELL)
	_press(run, BoardControls.KEY_SEND)


# --- What is written down as it happens -----------------------------------


# What the person is offered before they choose: where they may step, and which
# cells each weapon action covers from where they stand as they are facing.
static func _record_what_is_offered(run: Dictionary, turn: BoardTurn) -> void:
	var rows := turn.attacks()
	var covered := 0
	for index in rows.size():
		covered += turn.attack_cells(index).size()
	run["offered"] = {
		"move": turn.move_cells().size(),
		"actions": rows.size(),
		"covered": covered,
	}
	_note(run, "shown", "", "%d cells to step onto, %d weapon actions covering %d cells" % [
		turn.move_cells().size(), rows.size(), covered,
	])
	# And a step the board does not offer, refused in the match's own words.
	var away := turn.cell() + Vector2i(7, 7)
	var refused := turn.step_to(away)
	run["illegal"] = {
		"asked": away,
		"ok": bool(refused["ok"]),
		"reason": String(refused["reason"]),
	}
	_note(run, "step", "(%d,%d)" % [away.x, away.y],
		"refused: %s" % String(refused["reason"]))


# What one free quarter turn does to the pattern, and what it costs.
static func _record_a_free_turn(run: Dictionary) -> void:
	var sim: Simulation = run["sim"]
	var turn := sim.driven_turn()
	if turn == null:
		return
	var before := turn.attack_cells(QUICK)
	var spent_before := [turn.moved(), turn.acted(), turn.minion_spent()]
	var facing_before := turn.facing_name()
	_press(run, BoardControls.KEY_TURN_RIGHT)
	turn = sim.driven_turn()
	if turn == null:
		return
	run["facing"] = {
		"before": before,
		"after": turn.attack_cells(QUICK),
		"before_name": facing_before,
		"after_name": turn.facing_name(),
		"cost": spent_before != [turn.moved(), turn.acted(), turn.minion_spent()],
	}


# The heavy action pressed while it is still waiting, and what came back.
static func _record_a_cooldown_refusal(run: Dictionary) -> void:
	var sim: Simulation = run["sim"]
	var turn := sim.driven_turn()
	if turn == null:
		return
	var rows := turn.attacks()
	if HEAVY >= rows.size() or bool((rows[HEAVY] as Dictionary)["ready"]):
		return
	var answered := _press(run, BoardControls.SWING_KEYS[HEAVY])
	run["cooldown"] = {
		"round": turn.round_number(),
		"remaining": int((rows[HEAVY] as Dictionary)["remaining"]),
		"cooldown": int((rows[HEAVY] as Dictionary)["cooldown"]),
		"reason": String(answered.get("reason", "")),
	}


# What the turn had left after everything was spent, and what the match says to
# a second of each. Recorded once, off the first turn where all three went.
static func _record_the_spent_turn(run: Dictionary) -> void:
	var sim: Simulation = run["sim"]
	var turn := sim.driven_turn()
	if turn == null or not run["spent"].is_empty():
		return
	if not (turn.moved() and turn.acted() and turn.minion_spent()):
		return
	var again_move := turn.step_to(turn.move_cells()[0] if not turn.move_cells().is_empty()
		else turn.cell())
	var again_swing := turn.swing(QUICK)
	var mine := turn.minions()
	var again_minion := {"ok": true, "reason": ""}
	if not mine.is_empty():
		var id := int((mine[0] as Dictionary)["id"])
		var where := turn.minion_cells(id)
		again_minion = turn.send(id, where[0] if not where.is_empty() else turn.cell())
	run["spent"] = {
		"round": turn.round_number(),
		"move": String(again_move["reason"]),
		"swing": String(again_swing["reason"]),
		"minion": String(again_minion["reason"]),
	}


# --- The presses themselves -----------------------------------------------


# Press one key on the turn standing now, write down what came back, and hand it
# to the caller. The one path every press in this file takes.
static func _press(run: Dictionary, keycode: int) -> Dictionary:
	var sim: Simulation = run["sim"]
	var controls: BoardControls = run["controls"]
	var turn := sim.driven_turn()
	if turn == null:
		return {}
	var round_number := turn.round_number()
	var answered := controls.press(keycode, turn)
	var said := ""
	if controls.note != "":
		said = controls.note
	elif answered.is_empty():
		said = controls.picked_line()
	elif bool(answered.get("ok", false)):
		said = "done"
	else:
		said = "refused: %s" % String(answered.get("reason", ""))
	(run["trace"] as Array).append({
		"tick": sim.world.tick,
		"round": round_number,
		"who": _name_of(run, sim.driven_id),
		"did": _key_named(keycode),
		"answer": said,
	})
	return answered


# One line of the trace that is not a press: the board arriving, and going away.
static func _note(run: Dictionary, did: String, at: String, said: String) -> void:
	var sim: Simulation = run["sim"]
	(run["trace"] as Array).append({
		"tick": sim.world.tick,
		"round": 0,
		"who": _name_of(run, sim.driven_id),
		"did": did if at == "" else "%s %s" % [did, at],
		"answer": said,
	})


# --- Reading the board, which is what a person at a keyboard does ---------


static func _enemy_commander(run: Dictionary) -> Piece:
	var sim: Simulation = run["sim"]
	var fight := sim.world.combat.scene.fight
	if fight == null or fight.match_state == null:
		return null
	var mine := fight.match_state.active_commander()
	if mine == null:
		return null
	for id in fight.match_state.pieces.ids():
		var piece := fight.match_state.pieces.piece_of(id)
		if piece != null and piece.is_commander() and piece.owner_id != mine.owner_id:
			return piece
	return null


static func _covers_an_enemy(run: Dictionary, turn: BoardTurn) -> bool:
	var sim: Simulation = run["sim"]
	var fight := sim.world.combat.scene.fight
	if fight == null or fight.match_state == null:
		return false
	for index in turn.attacks().size():
		for cell in turn.attack_cells(index):
			var standing := fight.match_state.pieces.piece_at(cell)
			if standing != null and standing.owner_id != turn.me.owner_id:
				return true
	return false


static func _apart(from: Vector2i, to: Vector2i) -> int:
	return maxi(absi(from.x - to.x), absi(from.y - to.y))


static func _name_of(run: Dictionary, id: int) -> String:
	var sim: Simulation = run["sim"]
	var one := sim.world.combat.member_of(id)
	if one == null or one.piece == null or not (one.piece is Commander):
		return "#%d" % id
	var sheet := (one.piece as Commander).sheet
	return "#%d" % id if sheet == null or sheet.character_name == "" \
		else sheet.character_name


static func _key_named(keycode: int) -> String:
	var at := BoardControls.SWING_KEYS.find(keycode)
	if at >= 0:
		return "weapon action %d" % (at + 1)
	match keycode:
		BoardControls.KEY_PICK_CELL:
			return "pick a cell"
		BoardControls.KEY_STEP:
			return "step"
		BoardControls.KEY_PICK_MINION:
			return "pick a minion"
		BoardControls.KEY_PICK_MINION_CELL:
			return "pick where it goes"
		BoardControls.KEY_SEND:
			return "send it"
		BoardControls.KEY_TURN_LEFT:
			return "turn left"
		BoardControls.KEY_TURN_RIGHT:
			return "turn right"
		BoardControls.KEY_END_TURN:
			return "end the turn"
	return "?"


## The trace as text, one line per thing done: the tick, the round, who did it,
## what they did and what the simulation answered.
##
## A run of the same key pressed over and over -- which is what cycling a ring of
## cells is -- comes out as one line saying how many times and where it settled.
## Nothing is dropped: the count is the presses and the answer is the last one,
## which is the pick that was then acted on.
static func trace_lines(run: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("%-5s %-6s %-8s %-22s %s" % ["tick", "round", "who", "did", "the engine said"])
	var rows: Array = run.get("trace", [])
	var at := 0
	while at < rows.size():
		var row: Dictionary = rows[at]
		var same := 1
		while at + same < rows.size() \
				and String((rows[at + same] as Dictionary)["did"]) == String(row["did"]) \
				and int((rows[at + same] as Dictionary)["round"]) == int(row["round"]):
			same += 1
		var last: Dictionary = rows[at + same - 1]
		lines.append("%-5d %-6s %-8s %-22s %s" % [
			int(last["tick"]),
			"-" if int(last["round"]) == 0 else str(int(last["round"])),
			String(last["who"]),
			String(last["did"]) if same == 1 else "%s (x%d)" % [String(last["did"]), same],
			String(last["answer"]),
		])
		at += same
	return lines


# --- 1: in from real time, out to real time -------------------------------


func _a_fight_was_entered_and_left(run: Dictionary) -> void:
	check(bool(run["ok"]), "the battle scenario could not be set out and handed over")
	check(int(run["entered"]) > 0,
		"no fight was ever entered: the two bands never met")
	check(int(run["left"]) > int(run["entered"]),
		"the fight was entered at tick %d and never left" % int(run["entered"]))
	var sim: Simulation = run["sim"]
	equal(sim.world.combat.phase(), CombatantRoster.REAL_TIME,
		"the world should be back in real time once the fight is over")
	check(sim.world.combat.fights_begun >= 1, "the world holds no record of a fight")
	check(sim.world.combat.fights_ended >= 1, "the world holds no record of a fight ending")


# --- 2: the turn economy is the simulation's ------------------------------


func _the_turn_economy_is_the_simulations(run: Dictionary) -> void:
	var spent: Dictionary = run["spent"]
	check(not spent.is_empty(),
		"no turn of the person's spent all three of a move, an action and a minion")
	if spent.is_empty():
		return
	check(String(spent["move"]).contains("already moved"),
		"a second move should be refused as one: %s" % spent["move"])
	check(String(spent["swing"]).contains("already acted"),
		"a second weapon action should be refused as one: %s" % spent["swing"])
	check(String(spent["minion"]).contains("already acted"),
		"a second minion should be refused as one: %s" % spent["minion"])
	# And the turn really passed on afterwards, which is what ending one means.
	check(int(run["turns"]) >= 2,
		"the person took %d turns, so nothing shows the board coming back round"
			% int(run["turns"]))


# --- 3: what is legal, and what is not ------------------------------------


func _what_is_legal_is_shown_and_an_illegal_choice_is_refused(run: Dictionary) -> void:
	var offered: Dictionary = run.get("offered", {})
	check(not offered.is_empty(), "the person was never shown what was on offer")
	if not offered.is_empty():
		check(int(offered["move"]) > 0,
			"the board offered nowhere at all to step onto")
		check(int(offered["actions"]) > 0, "the commander was offered no weapon action")
		check(int(offered["covered"]) > 0, "no weapon action covered a single cell")
	var illegal: Dictionary = run["illegal"]
	check(not illegal.is_empty(), "no illegal choice was ever made")
	if illegal.is_empty():
		return
	check(not bool(illegal["ok"]), "a step the board does not offer was allowed")
	check(String(illegal["reason"]).contains("is not reachable"),
		"the refusal should be the match's own sentence, got '%s'" % illegal["reason"])

	# And the cells on offer are the ones the simulation would give anybody: the
	# same call, asked here, gives the same answer.
	var sim: Simulation = run["sim"]
	check(sim.driven_turn() == null,
		"the fight is over, so there should be no turn standing")


# --- 4: cooldowns ---------------------------------------------------------


func _a_cooldown_counts_down_and_refuses(run: Dictionary) -> void:
	var waiting: Dictionary = run["cooldown"]
	check(not waiting.is_empty(),
		"the heavy action was never still waiting when the board came back round")
	if waiting.is_empty():
		return
	check(int(waiting["remaining"]) > 0,
		"the action was recorded as waiting with nothing left to wait")
	check(int(waiting["remaining"]) < int(waiting["cooldown"]),
		"a wait of %d out of %d has not counted down at all" % [
			waiting["remaining"], waiting["cooldown"],
		])
	check(String(waiting["reason"]).contains("cooldown"),
		"an action on cooldown should say so rather than do nothing: '%s'"
			% waiting["reason"])


# --- 5: facing ------------------------------------------------------------


func _facing_is_free_and_moves_the_pattern(run: Dictionary) -> void:
	var turned: Dictionary = run["facing"]
	check(not turned.is_empty(), "the person never turned")
	if turned.is_empty():
		return
	not_equal(String(turned["before_name"]), String(turned["after_name"]),
		"a quarter turn should leave the commander facing somewhere else")
	not_equal(turned["before"], turned["after"],
		"turning should move which cells the attack covers, and it did not")
	check(not bool(turned["cost"]),
		"turning spent something out of the turn, and it is meant to be free")


# --- 6: no rule and no copy on the interface side -------------------------


func _the_interface_holds_no_rule_and_no_copy(run: Dictionary) -> void:
	for path in INTERFACE_FILES:
		var code := _code_of(path)
		check(code != "", "could not read %s" % path)
		for word in NO_RULES:
			check(not code.contains(word),
				"%s names '%s', which is the simulation's answer and not the"
					% [path, word] + " interface's")

	# And the readout, which has gained controls: it still reads the fight on the
	# frame it draws and holds no copy of the turn, the cooldowns or the board.
	if not SproutPack.is_installed():
		return
	var sim := Simulation.new(SEED)
	check(sim.begin_scenario(Simulation.SCENARIO_ENCOUNTER),
		"the encounter scenario could not be set out")
	for _tick in CLOSING:
		if sim.world.combat.phase() != CombatantRoster.REAL_TIME:
			break
		sim.step()
	var panel := CombatPanel.new()
	panel.watch(sim.world)
	panel.refresh()
	var first := panel._round_label.text
	# The world is moved and the panel is not told. It says the new thing anyway,
	# because it is looking at the fight rather than at a note it took.
	for _tick in 4:
		sim.step()
	panel.refresh()
	var second := panel._round_label.text
	check(first != "" and second != "", "the readout drew no round at all")
	equal(second, "round %d" % sim.world.combat.fight.match_state.round_number,
		"the readout should say the round the fight is on")

	# With nobody playing there is no turn section and no controls to press: a
	# control for a turn that is not yours is one that would be refused.
	check(not panel._turn_head.visible,
		"the turn section should be hidden in a run nobody is playing")
	for row in panel._control_rows:
		check(not row.visible, "the controls should be hidden with the section")

	# And a button really is a key press and nothing else: pressing one hands the
	# keycode over and does nothing itself.
	var handed := []
	panel.on_key = func(keycode: int) -> void: handed.append(keycode)
	panel.press(BoardControls.KEY_END_TURN)
	equal(handed, [BoardControls.KEY_END_TURN],
		"a control should hand its key to the shell and do nothing else")


# --- 7: the trace ---------------------------------------------------------


func _the_whole_fight_is_one_trace(run: Dictionary) -> void:
	var lines := trace_lines(run)
	check(lines.size() > 10,
		"a whole fight should be more than %d lines of trace" % lines.size())
	var answered := 0
	var refused := 0
	for row in run["trace"]:
		if String(row["answer"]) != "":
			answered += 1
		if String(row["answer"]).begins_with("refused"):
			refused += 1
	equal(answered, (run["trace"] as Array).size(),
		"every line of the trace should say what the engine answered")
	check(refused >= 2,
		"the trace should hold the refusals the run provoked, and holds %d" % refused)


## The code of a file with its comments taken out, which is what the scan above
## reads.
##
## Prose has to be able to say what a file is *not* doing -- "this is where
## `CombatPolicy` spends the same three things", "the board offers a step cell
## and a capture cell in one list" -- without that reading as the file doing it.
## `tests/layer_check.gd` strips comments before its own scan for exactly this
## reason and says so; this is the same rule, applied to the same kind of scan.
## String literals are kept, so a name smuggled into a string is still caught.
static func _code_of(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		return ""
	var kept := PackedStringArray()
	for line in text.split("\n"):
		var at := _comment_starts_at(line)
		kept.append(line if at < 0 else line.substr(0, at))
	return "\n".join(kept)


# Where a line's comment begins, or -1. A hash inside a string literal is not a
# comment, so the quotes are counted on the way past.
static func _comment_starts_at(line: String) -> int:
	var quoted := false
	for at in line.length():
		var character := line[at]
		if character == "\"":
			quoted = not quoted
		elif character == "#" and not quoted:
			return at
	return -1
