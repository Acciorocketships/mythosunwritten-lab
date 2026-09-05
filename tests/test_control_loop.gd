extends TestSuite
## The control loop, tested as section 2.2 states it and section 12 requires it.
##
## Seven claims:
##
##   1. **An action occupies ticks.** A committed action has not happened yet:
##      the world is unchanged for every tick of its span and changes on the tick
##      the span runs out. What each action costs is the catalogue's own column,
##      and the catalogue refuses a row that costs nothing.
##   2. **The cadence is one named constant.** The re-evaluations land exactly on
##      multiples of `ControlLoop.REVIEW_EVERY` -- computed from the constant
##      here, never typed -- and the constant is declared once under `sim/`, used
##      once where it is declared, and read by name everywhere else.
##   3. **Each of section 2.2's four events re-evaluates immediately**, each in
##      its own headless case: the action finishing, being attacked while acting,
##      combat starting, and a conversation opening. What an interrupted action
##      leaves behind is `tests/test_walk_motion.gd`'s: the abandoned action gets
##      no answer, and a walk given up on leaves the walker where its strides
##      actually carried it.
##   3b. **Being asked does not spend a written-down turn.** A plan on
##      `DecisionSource.plan` offers back the action already running when it is
##      re-evaluated part-way through; the queue-shaped reading of the same list
##      hands over the entry after it, and loses it.
##   4. **The bias is one number in one place, and it does something.** The
##      literal appears once under `sim/`; and the same restless character run at
##      it and at zero changes its mind at very different rates, both counted.
##   5. **A slow decision function does not stall the world.** With one character
##      deliberating for forty ticks, every other character's tick count, action
##      count and journal are what they were when nobody was slow.
##   6. **Nothing under `sim/` reads a wall clock.** Every file is scanned, and
##      the scan is then run over a line that does read one and must catch it.
##   7. **Two processes agree** on `./run_loop.sh`.
class_name TestControlLoop

## Where the constants live, and the one file allowed to state them rather than
## read them.
const LOOP_FILE := "res://sim/control_loop.gd"
const SIM_DIR := "res://sim"

## How a line of code would read a wall clock: whole words, so `Time` is not
## found inside `TimeQuery` and `OS` is not found inside `COST`.
const CLOCK_WORDS := [
	"Time", "OS", "Engine", "Performance", "RandomNumberGenerator",
	"get_ticks_msec", "get_ticks_usec", "get_unix_time_from_system",
	"get_datetime_dict_from_system", "get_system_time_msecs", "randomize",
]

## The lines that would break claim 6 if they were under `sim/`, and which the
## scan must catch to be worth anything.
const BROKEN_CLOCKS := [
	"	var started := Time.get_ticks_usec()",
	"	if OS.get_ticks_msec() - began > 500:",
]

## Lines that really are under `sim/` and which the scan must not catch.
const HONEST_CLOCKS := [
	"	scene.tick += 1",
	"	var elapsed := at_tick - began",
]

## The bias measured against, and what it is compared with: zero, which is the
## loop with the bias deleted.
const NO_BIAS := 0.0

## What the two characters in the bare scenes carry and where they stand. No
## terrain: a walk is then arithmetic, and nothing about the world's fields can
## move a number in the cases that do not need ground.
const HATCHET := "worn hatchet"
const ROOK_AT := Vector2(0.0, 0.0)
const WREN_AT := Vector2(2.0, 0.0)
const PILE_AT := Vector2(1.0, 0.0)
const WALK_TO := Vector2(30.0, 0.0)

## The seed the loop's draws come from in this suite. Any seed does; this one is
## fixed so a failure is the same failure twice.
const SEED := 7


func _init() -> void:
	suite_name = "control loop"


func run() -> void:
	_an_action_occupies_ticks()
	_every_action_costs_at_least_one_tick()
	_the_cadence_lands_on_the_constant()
	_the_cadence_is_one_constant_in_one_place()
	_finishing_re_evaluates_at_once()
	_being_attacked_re_evaluates_at_once()
	_combat_starting_re_evaluates_at_once()
	_a_conversation_opening_re_evaluates_at_once()
	_being_asked_again_does_not_spend_a_planned_turn()
	_the_bias_is_one_number_in_one_place()
	_the_bias_changes_how_often_a_mind_changes()
	_a_slow_decider_does_not_stall_the_world()
	_nothing_under_sim_reads_a_clock()
	_the_clock_scan_would_notice()
	_two_processes_agree()


# --- 1. An action occupies ticks ------------------------------------------


## A committed action has not happened yet. The hatchet stays on the ground for
## every tick of the pick-up's span and is carried on the tick it runs out.
func _an_action_occupies_ticks() -> void:
	var costs := ActionCatalog.occupies_of(ActionCatalog.PICK_UP)
	equal(ControlLoop.occupies(Action.pick_up(HATCHET)), costs,
		"a pick up costs what its row says")
	equal(ControlLoop.occupies(Action.wait(9)), 9,
		"a wait costs the duration it names, because section 2.1 lets it name one")
	equal(ControlLoop.occupies(Action.wait(0)), ActionCatalog.occupies_of(ActionCatalog.WAIT),
		"and a wait that names nothing falls back to its row")

	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	_sheet(rook).decide = DecisionSource.recorded([Action.pick_up(HATCHET)])
	var loop := ControlLoop.on(scene, SEED)

	for tick in range(1, costs + 1):
		loop.step()
		check(not _carries(rook, HATCHET),
			"at tick %d of the %d it occupies, the hatchet is still on the ground" % [
				tick, costs])
		check(loop.is_busy(rook.id), "and the character is busy carrying the action out")
	loop.step()
	check(_carries(rook, HATCHET),
		"on the tick after the last of them the hatchet is carried")
	equal(loop.actions_of(rook.id), 1, "and exactly one action was resolved")


## Every row of the one list costs at least one tick, and the catalogue's own
## check says so -- run over the real table, which must be clean, and over a
## table with a free action in it, which it must catch.
func _every_action_costs_at_least_one_tick() -> void:
	for action_name in ActionCatalog.names():
		check(ActionCatalog.occupies_of(action_name) >= 1,
			"%s costs at least one tick" % action_name)

	var constructors := PackedStringArray(Action.constructors().keys())
	var resolvers := PackedStringArray(ActionEngine.resolvers().keys())
	equal(ActionCatalog.faults(ActionCatalog.ROWS, constructors, resolvers),
		PackedStringArray(), "the real table is clean")

	var free_action := ActionCatalog.ROWS.duplicate(true)
	free_action[0]["occupies"] = 0
	check(not ActionCatalog.faults(free_action, constructors, resolvers).is_empty(),
		"an action that costs no ticks is caught")


# --- 2. The cadence -------------------------------------------------------


## The re-evaluations land on multiples of the constant, and nowhere else.
##
## The expected ticks are computed from `ControlLoop.REVIEW_EVERY` rather than
## written down, so changing the constant changes what this test expects instead
## of breaking it.
func _the_cadence_lands_on_the_constant() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var to := ROOK_AT + WALK_TO
	_sheet(rook).decide = DecisionSource.scripted(
		func(_scene: ActionScene, _actor: Combatant) -> Action:
			return Action.go_to(to))

	var span := ActionCatalog.occupies_of(ActionCatalog.GO_TO)
	var loop := ControlLoop.on(scene, SEED)
	loop.run(span)

	var wanted := PackedInt32Array()
	var at := ControlLoop.REVIEW_EVERY
	while at < span:
		wanted.append(1 + at)
		at += ControlLoop.REVIEW_EVERY
	equal(_ticks_of_lines(loop.journal, "thought again"), wanted,
		"re-evaluated on every multiple of REVIEW_EVERY and on no other tick")
	equal(loop.counts()["reviews"], wanted.size(),
		"and the loop counted exactly that many")


## The cadence is declared once and read everywhere else.
##
## What "not scattered" means, made checkable: exactly one file under `sim/`
## declares `REVIEW_EVERY`, that file uses it once, and every other file that
## mentions it writes `ControlLoop.REVIEW_EVERY` -- a read of the one constant
## rather than a number of its own.
func _the_cadence_is_one_constant_in_one_place() -> void:
	_one_constant_in_one_place("REVIEW_EVERY")


# --- 3. Section 2.2's four events -----------------------------------------


## The action finishing. The span runs out, the engine answers, and the next
## action begins on the same tick -- which is what "re-evaluates immediately"
## means when the clock is a tick counter.
func _finishing_re_evaluates_at_once() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	_sheet(rook).decide = DecisionSource.recorded([
		Action.pick_up(HATCHET),
		Action.examine(HATCHET),
	])
	var loop := ControlLoop.on(scene, SEED)
	loop.run(ActionCatalog.occupies_of(ActionCatalog.PICK_UP) + 1)

	equal(loop.counts()[ControlLoop.FINISHED], 1, "the pick up finished")
	var finished := _ticks_of_lines(loop.journal, ControlLoop.FINISHED)
	var began := _ticks_of_lines(loop.journal, "began examine")
	equal(began, finished,
		"and the next action began on the very tick the last one finished")


## Being attacked while acting. The one whose turn it is settles in to wait out
## twenty ticks -- a wait is not spent out of a turn, so the turn passes at once
## -- and the other spends its own turn on a spear. Nobody reports the
## interruption; the loop reads it off a health score that fell.
func _being_attacked_re_evaluates_at_once() -> void:
	var scene := _fight_scene()
	if scene == null:
		check(false, "the fight could not be seated, so this case did not run")
		return
	var struck := _whose_turn(scene)
	var striker: Combatant = scene.actors[1] if struck == scene.actors[0] else scene.actors[0]
	_sheet(striker).decide = DecisionSource.recorded([
		Action.attack(struck.id, ScriptedLoop.SPEAR)])
	_sheet(struck).decide = DecisionSource.recorded([Action.wait(20)])

	var was := struck.piece.health
	var loop := ControlLoop.on(scene, SEED)
	# One tick for the waiting turn to pass, then the striker's whole turn.
	for _step in ActionCatalog.occupies_of(ActionCatalog.ATTACK) + 2:
		loop.step()
		scene.fight_step()

	check(struck.piece.health < was, "the blow landed (%d -> %d)" % [
		was, struck.piece.health])
	equal(loop.counts()[ControlLoop.ATTACKED], 1,
		"and the one it landed on was interrupted by it")
	check(not loop.is_busy(struck.id),
		"and abandoned the wait rather than serving it out")
	equal(loop.actions_of(struck.id), 0,
		"and the abandoned action never reached the engine")


## Combat starting. Two characters walking; the fight begins under them between
## one tick and the next, and neither walk survives it.
func _combat_starting_re_evaluates_at_once() -> void:
	var scene := _duel_scene()
	for one: Combatant in scene.actors:
		var to := Vector2(one.x, one.z) + WALK_TO
		_sheet(one).decide = DecisionSource.scripted(
			func(_scene: ActionScene, _actor: Combatant) -> Action:
				return Action.go_to(to))

	var loop := ControlLoop.on(scene, SEED)
	loop.run(2)
	equal(loop.counts()[ControlLoop.COMBAT_BEGAN], 0, "nobody is interrupted before the fight")
	var began := scene.begin_fight(scene.actors[0].id)
	check(began != null and not began.refused, "the fight was seated")
	loop.run(1)
	equal(loop.counts()[ControlLoop.COMBAT_BEGAN], scene.actors.size(),
		"everybody on the board dropped what they were doing when it began")


## A conversation opening. Being addressed by name interrupts; being shouted at
## does not, because a shout is the one kind of speech nobody has to answer.
func _a_conversation_opening_re_evaluates_at_once() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var wren: Combatant = scene.actors[1]
	var to := ROOK_AT + WALK_TO
	_sheet(rook).decide = DecisionSource.scripted(
		func(_scene: ActionScene, _actor: Combatant) -> Action:
			return Action.go_to(to))
	_sheet(wren).decide = DecisionSource.recorded([
		Action.say("anyone about?"),
		Action.say("a word with you", rook.id),
	])

	var say_span := ActionCatalog.occupies_of(ActionCatalog.SAY)
	var loop := ControlLoop.on(scene, SEED)
	loop.run(say_span + 1)
	equal(loop.counts()[ControlLoop.SPOKEN_TO], 0,
		"a shout heard by everybody interrupted nobody")
	check(loop.is_busy(rook.id), "and the walker is still walking")

	loop.run(say_span)
	equal(loop.counts()[ControlLoop.SPOKEN_TO], 1,
		"a word addressed by name interrupted the walker")
	equal(loop.actions_of(rook.id), 0,
		"and the walk it abandoned never reached the engine")
	# It is standing where the strides it took actually carried it, which is not
	# where it started and not where it was going: a walk given up on part-way is
	# a walk half taken, not a walk undone. `tests/test_walk_motion.gd` counts
	# the strides; here it is enough that the abandoned walk got no answer.
	check(rook.x > ROOK_AT.x and rook.x < ROOK_AT.x + WALK_TO.x,
		"so the walker is part-way to where it was going (%.3f)" % rook.x)


# --- 3b. Being asked does not spend a planned turn ------------------------


## A re-evaluation is a question, and a question is not a turn.
##
## One character, one list of two choices, and one action long enough to be
## re-evaluated part-way through -- so the loop asks again while it is still
## running. The plan offers the action already under way back, which is what
## somebody who has not changed their mind says, and both its entries are
## carried out. The same list read as a queue answers the question with the
## entry after it, and that entry is then gone.
func _being_asked_again_does_not_spend_a_planned_turn() -> void:
	var long_enough := ControlLoop.REVIEW_EVERY * 2 + 2
	var written_down := [Action.wait(long_enough), Action.say("hoy")]

	var planned := _bare_scene()
	var by_plan: Combatant = planned.actors[0]
	_sheet(by_plan).decide = DecisionSource.plan(written_down)
	var plan_loop := ControlLoop.on(planned, SEED)
	plan_loop.run(ControlLoop.REVIEW_EVERY + 1)
	check(plan_loop.is_busy(by_plan.id), "the wait is still running when it is asked again")
	var offered: Action = _sheet(by_plan).decide.call(planned, by_plan)
	equal(offered.line(), written_down[0].line(),
		"asked part-way through, the plan offers the action already running")
	equal(_count(plan_loop.journal, "wanted the same thing"),
		int(plan_loop.counts()["reviews"]),
		"so every re-evaluation so far read as wanting the same thing")

	var queued := _bare_scene()
	var by_queue: Combatant = queued.actors[0]
	_sheet(by_queue).decide = DecisionSource.recorded(
		[Action.wait(long_enough), Action.say("hoy")])
	var queue_loop := ControlLoop.on(queued, SEED)
	queue_loop.run(ControlLoop.REVIEW_EVERY + 1)
	var taken_by_the_question: Action = _sheet(by_queue).decide.call(queued, by_queue)
	check(taken_by_the_question == null
			or taken_by_the_question.line() != written_down[0].line(),
		"asked part-way through, the queue hands over something other than what is running")

	# Played out: the plan has both turns carried out, the queue has lost one to
	# having been asked.
	plan_loop.run(long_enough * 2)
	queue_loop.run(long_enough * 2)
	equal(plan_loop.actions_of(by_plan.id), written_down.size(),
		"both planned turns were carried out")
	check(queue_loop.actions_of(by_queue.id) < written_down.size(),
		"where the queue got %d of the %d taken" % [
			queue_loop.actions_of(by_queue.id), written_down.size()])
	equal(planned.actions_of(by_plan.id), plan_loop.actions_of(by_plan.id),
		"and the world counted what it carried out, as the loop did")


# --- 4. The bias ----------------------------------------------------------


## The bias is written down once.
func _the_bias_is_one_number_in_one_place() -> void:
	_one_constant_in_one_place("CONTINUE_BIAS")

	# And it is consulted in exactly one line of the whole simulation: a bias
	# read in two places is two biases the day one of them is edited.
	var consulted := PackedStringArray()
	for path in _files_under(SIM_DIR):
		var numbered := 0
		for line in _code_lines(path):
			numbered += 1
			if not AssetCheck._contains_word(line, "continue_bias"):
				continue
			if line.contains("<") or line.contains(">"):
				consulted.append("%s:%d %s" % [path, numbered, line.strip_edges()])
	equal(consulted.size(), 1,
		"the bias decides something in exactly one line under sim/: %s" % ", ".join(consulted))
	check(consulted.size() == 1 and consulted[0].begins_with(LOOP_FILE),
		"and that line is in the control loop")


## The bias does something, measured rather than asserted.
##
## The character is restless on purpose -- it wants somewhere else every time it
## is asked -- so the bias is consulted at every re-evaluation. At zero it
## abandons all of them; at `ControlLoop.CONTINUE_BIAS` it abandons a small
## fraction, and both counts are read off the same runs the transcript prints.
func _the_bias_changes_how_often_a_mind_changes() -> void:
	var biased := _measure_at(ControlLoop.CONTINUE_BIAS)
	var broken := _measure_at(NO_BIAS)

	check(biased.counts()["reviews"] > 20,
		"the measurement is over a real number of re-evaluations (%d)" % biased.counts()["reviews"])
	equal(broken.change_rate(), 1.0,
		"with the bias taken away, every re-evaluation changed the decision")
	check(biased.change_rate() < broken.change_rate(),
		"with the bias in force fewer of them did: %.1f%% against %.1f%%" % [
			100.0 * biased.change_rate(), 100.0 * broken.change_rate()])
	check(biased.change_rate() > 0.0,
		"but not none of them: the bias is a bias and not a lock")
	check(biased.change_rate() < 1.0 - ControlLoop.CONTINUE_BIAS + 0.15,
		"and the rate is near what the number says it should be (%.1f%% against %.1f%%)" % [
			100.0 * biased.change_rate(), 100.0 * (1.0 - ControlLoop.CONTINUE_BIAS)])


# --- 5. A decision that takes arbitrarily long ----------------------------


## One character deliberates for forty ticks and nobody else notices.
##
## The same world is lived twice, differing only in how long one character's
## decision function takes to answer. What is compared is every other
## character's tick count, action count and journal: all three are identical, so
## the slow one waited and the world did not.
func _a_slow_decider_does_not_stall_the_world() -> void:
	var quick := ScriptedLoop._crowd(false)
	var slow := ScriptedLoop._crowd(true)
	var slow_one: String = ScriptedLoop.CROWD[0]

	for who in [ScriptedLoop.CROWD[1], ScriptedLoop.CROWD[2]]:
		equal(slow["ticks"][who], quick["ticks"][who],
			"%s was serviced for the same number of ticks either way" % who)
		equal(slow["ticks"][who], ScriptedLoop.WORLD_TICKS,
			"and that number is every tick of the run")
		equal(slow["actions"][who], quick["actions"][who],
			"%s resolved the same number of actions either way" % who)
	equal(slow["others"], quick["others"],
		"and everything the other two did, tick by tick, is the same in both runs")

	check(slow["actions"][slow_one] < quick["actions"][slow_one],
		"the slow one got less done (%d against %d)" % [
			slow["actions"][slow_one], quick["actions"][slow_one]])
	equal(slow["stood"], Vector2.ZERO,
		"and stood where it started for the whole time it was thinking")


# --- 6. No wall clock under sim/ ------------------------------------------


## Nothing under `sim/` reads a wall clock. Comments are stripped first, so prose
## about time does not read as code about time.
func _nothing_under_sim_reads_a_clock() -> void:
	var found := PackedStringArray()
	for path in _files_under(SIM_DIR):
		var numbered := 0
		for line in _code_lines(path):
			numbered += 1
			var hit := _first_clock_word(line)
			if hit != "":
				found.append("%s:%d reads '%s'" % [path, numbered, hit])
	equal(found, PackedStringArray(),
		"no file under sim/ reads a clock")


## And the scan has teeth: two lines that do read a clock are caught, and two
## that really are under `sim/` are not.
func _the_clock_scan_would_notice() -> void:
	for line in BROKEN_CLOCKS:
		check(_first_clock_word(line) != "",
			"the scan catches: %s" % line.strip_edges())
	for line in HONEST_CLOCKS:
		equal(_first_clock_word(line), "",
			"and does not catch: %s" % line.strip_edges())
	equal(_first_clock_word("	var elapsed_time := ticks_taken"), "",
		"nor a word that merely contains one it looks for")


# --- 7. Two processes agree -----------------------------------------------


## `./run_loop.sh` prints the same bytes twice, so nothing in the loop reads a
## clock, a random number the seed does not fix, or an address.
func _two_processes_agree() -> void:
	var first := _run_loop()
	var second := _run_loop()
	equal(first["code"], 0, "./run_loop.sh exits 0")
	equal(second["code"], 0, "and again")
	equal(first["text"], second["text"],
		"two runs of ./run_loop.sh printed different bytes")
	check(first["text"].contains("interrupted"),
		"and the transcript is the control loop's")


func _run_loop() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path("res://run_loop.sh"), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


# --- The scenes -----------------------------------------------------------


# Two characters, a hatchet on the ground, and no terrain.
func _bare_scene() -> ActionScene:
	var scene := ActionScene.on()
	_put(scene, "Rook", 3, ROOK_AT)
	_put(scene, "Wren", 2, WREN_AT)
	scene.add_object(WorldObject.loose(
		PILE_AT.x, PILE_AT.y,
		Inventory.ground([Item.weapon(
			HATCHET, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])])))
	return scene


# Two armed commanders standing apart on the measured meadow. Terrain is needed
# here and only here: a board is read off the ground under the people standing
# on it.
func _duel_scene() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(ScriptedLoop.SEED))
	var apart := ScriptedLoop.DUEL_APART * 0.5
	var rook := _put(scene, "Rook", 3, ScriptedLoop.WHERE - Vector2(apart, 0.0))
	(rook.piece as Commander).wield(Weapon.held(Weapon.spear(), 3))
	var vex := _put(scene, "Vex", 2, ScriptedLoop.WHERE + Vector2(apart, 0.0))
	(vex.piece as Commander).wield(Weapon.held(Weapon.spear(), 2))
	return scene


# The same two, with the fight already seated, or null if it could not be.
func _fight_scene() -> ActionScene:
	var scene := _duel_scene()
	var began := scene.begin_fight(scene.actors[0].id)
	return null if began == null or began.refused else scene


func _put(scene: ActionScene, called: String, level: int, at: Vector2) -> Combatant:
	var one := scene.add_actor(Combatant.commander_at(
		at.x, at.y, 0.0, 0.0, level, AssetTags.KNIGHT))
	var sheet := Character.make(called, level)
	sheet.record_scores({Ability.DEX: 4, Ability.STR: 5})
	(one.piece as Commander).adopt(sheet)
	return one


func _measure_at(bias: float) -> ControlLoop:
	var scene := ActionScene.on()
	var ada := _put(scene, "Ada", 1, Vector2.ZERO)
	_sheet(ada).decide = DecisionSource.scripted(ScriptedLoop._restless(Vector2.ZERO))
	var loop := ControlLoop.on(scene, SEED)
	loop.continue_bias = bias
	loop.run(ScriptedLoop.MEASURE_TICKS)
	return loop


static func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet


static func _carries(one: Combatant, item_name: String) -> bool:
	var pack := ActionScene.inventory_of(one)
	if pack == null:
		return false
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == item_name:
			return true
	return false


func _whose_turn(scene: ActionScene) -> Combatant:
	for one in scene.actors:
		if one.piece.id == scene.fight.match_state.active_id():
			return one
	return scene.actors[0]


# --- Reading source and journals ------------------------------------------


# How many journal lines contain a phrase.
static func _count(journal: PackedStringArray, phrase: String) -> int:
	var found := 0
	for line in journal:
		if line.contains(phrase):
			found += 1
	return found


# The ticks of every journal line containing a phrase, in order.
static func _ticks_of_lines(journal: PackedStringArray, phrase: String) -> PackedInt32Array:
	var found := PackedInt32Array()
	for line in journal:
		if line.contains(phrase):
			found.append(int(line.substr(2, 3).strip_edges()))
	return found


# One constant, declared once under sim/ and read by name everywhere else.
func _one_constant_in_one_place(named: String) -> void:
	var declared := PackedStringArray()
	var loose := PackedStringArray()
	for path in _files_under(SIM_DIR):
		var numbered := 0
		for line in _code_lines(path):
			numbered += 1
			if not AssetCheck._contains_word(line, named):
				continue
			if line.strip_edges().begins_with("const %s" % named):
				declared.append(path)
			elif not line.contains("ControlLoop.%s" % named) and path != LOOP_FILE:
				loose.append("%s:%d %s" % [path, numbered, line.strip_edges()])
	equal(declared, PackedStringArray([LOOP_FILE]),
		"%s is declared in exactly one file under sim/" % named)
	equal(loose, PackedStringArray(),
		"and every other file reads it by name rather than restating it")


# The first wall-clock word a line of code uses, or "".
static func _first_clock_word(line: String) -> String:
	var code: String = AssetCheck.split_code_and_strings(line)["code"]
	for word in CLOCK_WORDS:
		if AssetCheck._contains_word(code, word):
			return word
	return ""


# Every line of a file with its comments taken off. String literals are kept, so
# a clock reached for through a string is still there to be found.
static func _code_lines(path: String) -> PackedStringArray:
	var kept := PackedStringArray()
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		kept.append(AssetCheck.split_code_and_strings(line)["code"])
	return kept


static func _files_under(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var listing := DirAccess.open(dir_path)
	if listing == null:
		return found
	listing.list_dir_begin()
	var entry := listing.get_next()
	while entry != "":
		if not listing.current_is_dir() and entry.ends_with(".gd"):
			found.append("%s/%s" % [dir_path, entry])
		entry = listing.get_next()
	listing.list_dir_end()
	found.sort()
	return found
