extends TestSuite
## The two stores the character sheet declares for everybody are maintained on a
## path every character passes.
##
## Section 1 says a character a person drives and a character a program drives
## differ in one thing: the decision function on the sheet. The sheet declares a
## memory and a goal set for *every* character, so a store filled on one driver's
## path and not on another's is that principle failing quietly -- and failing in
## the direction the design least expects, because it is the character with the
## richer driver that ends up with more.
##
## Five claims, all of them run with no key, no network and no model:
##
##   1. **The two calls live on the shared path.** `CharacterMemory.witness` and
##      `GoalCheck.settle` are called from `sim/character_upkeep.gd` and from the
##      two files that stage a scenario; no file of the model layer calls either,
##      and the scan that says so is shown to catch a planted call.
##   2. **Both drivers maintain both stores.** A character serviced by
##      `ControlLoop.step` and a character driven by `DecisionSource.drive` each
##      accrue a memory and each have their goals closed by the world -- shown
##      for a character whose decision function is a plan written down in advance
##      as well as for one whose decision function is a model.
##   3. **The cadence is one rule of the world.** A character is settled with
##      every servicing and takes in its surroundings once for every action the
##      world has carried out for it, whoever is deciding and however often it is
##      asked.
##   4. **Closing by hand is reachable by any driver.** `GoalCheck.close_by_hand`
##      is the whole of a character closing one of its own goals; the model
##      prompt's `done` tool is one caller of it, a plan-driven character's
##      closing leaves the same record, and each of the seven kinds the world
##      answers is refused with the world named as the reason.
##   5. **The shipped run shows it.** On the run `./run_agent.sh` prints, the
##      character driven by written-down choices holds a non-zero count of
##      remembered events, of the same order as the model-driven ones, and the
##      goal the world already answers true on it closes at its first servicing.
class_name TestUpkeep

## The directory the structural scan reads, all of it.
const SIM_DIR := "res://sim"

## How a line of code maintains one of the two stores. Matched against code with
## comments and string literals stripped, so a mention in prose does not count.
const WITNESSES := ".witness("
const SETTLES := "GoalCheck.settle("

## The shared path itself: the one file that is allowed to do both.
const THE_SHARED_PATH := "res://sim/character_upkeep.gd"

## The files allowed to witness besides the shared path. Both stage a moment for
## a controlled comparison -- a character that has been standing in the market
## for thirty ticks -- which is scenario setup in the same sense as the goals
## those files hand out, and neither of them is a driver.
const MAY_STAGE_A_WITNESS := [
	"res://sim/scripted_goal.gd",
	"res://sim/scripted_lesson.gd",
]

## What a planted call looks like: the line the model layer used to carry. The
## scan has to catch this for its silence about the real files to mean anything.
const PLANTED_WITNESS := "	remembered.witness(_seen)"
const PLANTED_SETTLE := "	for row in GoalCheck.settle(goals_of(actor), scene, actor):"

## The character the suite stages, and what it carries.
const ROOK_AT := Vector2(0.0, 0.0)
const WREN_AT := Vector2(3.0, 0.0)
const MONEY := 30

## What the packet calls a cell it could not read. A character standing where
## there is no ground must be told this and never that the ground is walkable.
const MEANS_UNREAD := "not read"

## How many ticks the loop is run for. Long enough for one action of five ticks
## to be carried out and for the character to be asked again afterwards.
const TICKS := 20


func _init() -> void:
	suite_name = "upkeep"


func run() -> void:
	_the_two_calls_live_on_the_shared_path()
	_both_drivers_maintain_both_stores()
	_the_cadence_is_one_rule_of_the_world()
	_closing_by_hand_is_reachable_by_any_driver()
	_the_shipped_run_shows_it()


# --- 1. Where the two calls are -------------------------------------------


func _the_two_calls_live_on_the_shared_path() -> void:
	var sources := _files_under(SIM_DIR)
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())

	var witnesses := PackedStringArray()
	var settles := PackedStringArray()
	for path in sources:
		var code := _code_of(path)
		if code.contains(WITNESSES):
			witnesses.append(path)
		if code.contains(SETTLES):
			settles.append(path)

	var allowed_to_witness := PackedStringArray(MAY_STAGE_A_WITNESS)
	allowed_to_witness.append(THE_SHARED_PATH)
	allowed_to_witness.sort()
	equal(witnesses, allowed_to_witness,
		"a file under sim/ writes into a character's memory that is not the"
		+ " shared servicing path or a scenario staging one")
	equal(settles, PackedStringArray([THE_SHARED_PATH]),
		"a file under sim/ settles goals that is not the shared servicing path")

	# The claim the finding was about: nothing of the model layer maintains
	# either store. It is checked by name as well as by the lists above, so a
	# file added to the layer later is covered without anybody remembering to.
	var model_layer := PackedStringArray()
	for path in sources:
		if path.get_file().begins_with("model_"):
			model_layer.append(path)
	check(model_layer.size() >= 4,
		"the scan found %d files of the model layer" % model_layer.size())
	for path in model_layer:
		var code := _code_of(path)
		check(not code.contains(WITNESSES),
			"%s writes into a character's memory" % path)
		check(not code.contains(SETTLES), "%s settles a character's goals" % path)

	# And the scan has teeth: the two lines the model layer used to carry are
	# caught by the same detector that just found none.
	check(_code_line(PLANTED_WITNESS).contains(WITNESSES),
		"the scan would not notice a witness call planted in the model layer")
	check(_code_line(PLANTED_SETTLE).contains(SETTLES),
		"the scan would not notice a settle call planted in the model layer")

	# A mention in prose is not a call: the shared path's own note names both, and
	# so does the mind's, and neither of those is what the scan reads.
	check(not _code_of("res://sim/model_mind.gd").contains(WITNESSES),
		"the mind's prose about witnessing is read as a call")


# --- 2. Both drivers, both stores -----------------------------------------


func _both_drivers_maintain_both_stores() -> void:
	# Under the loop: one character driven by a plan written down in advance and
	# one driven by a model, serviced by the same `step()`.
	var scene := _bare_scene()
	var planned := scene.actors[0]
	var modelled := scene.actors[1]
	_plan_for(planned, [Action.wait(3), Action.say("good morning", modelled.id)])
	var mind := _mind_saying("wait ticks=3")
	_sheet(modelled).decide = DecisionSource.model(mind)
	for one in [planned, modelled]:
		_sheet(one).goals.add(Goal.of(Goal.MONEY, {"amount": 1}, "", Goal.SHORT))
	var loop := ControlLoop.on(scene, 5)
	loop.run(TICKS)

	for one in [planned, modelled]:
		var sheet := _sheet(one)
		var who := "the %s-driven character" % (
			"plan" if one == planned else "model")
		check(sheet.memory.events.size() > 0,
			"%s remembers nothing after %d ticks" % [who, TICKS])
		check(sheet.goals.goal_of(1).closed,
			"%s still holds a goal the world answered at tick 1" % who)
		equal(sheet.goals.goal_of(1).closed_at, 1,
			"%s did not have its goal closed at its first servicing" % who)
		equal(sheet.goals.goal_of(1).closed_by, "%d money in the pack" % MONEY,
			"%s's goal did not close in the world's own words" % who)
		equal(String(GoalCheck.closings_of(sheet.goals)[0]["by"]),
			GoalCheck.BY_THE_WORLD,
			"%s's goal was closed by something other than the world" % who)
	check(_sheet(planned).memory.events.size() > 0
			and _sheet(modelled).memory.events.size() > 0,
		"one of the two drivers filled a memory and the other did not")

	# And the mind fills neither: the memory it reads was written before it was
	# ever called, and it was written for the character beside it too.
	check(mind.turns.size() > 0, "the model character was never asked anything")

	# Under `drive()`: the same two stores, the same two drivers, one call one
	# resolution.
	var driven := _bare_scene()
	var by_plan := driven.actors[0]
	var by_model := driven.actors[1]
	_plan_for(by_plan, [Action.wait(2), Action.wait(2)])
	var second := _mind_saying("wait ticks=2")
	_sheet(by_model).decide = DecisionSource.model(second)
	for one in [by_plan, by_model]:
		_sheet(one).goals.add(Goal.of(Goal.MONEY, {"amount": 1}, "", Goal.SHORT))
	DecisionSource.drive(driven, by_plan, 2)
	for _at in ModelChannel.THINKS_FOR + 3:
		DecisionSource.drive(driven, by_model, 1)
		driven.advance(1)

	for one in [by_plan, by_model]:
		var sheet := _sheet(one)
		var who := "the %s-driven character under drive()" % (
			"plan" if one == by_plan else "model")
		check(sheet.memory.events.size() > 0, "%s remembers nothing" % who)
		check(sheet.goals.goal_of(1).closed, "%s's goal was never closed" % who)
		equal(String(GoalCheck.closings_of(sheet.goals)[0]["by"]),
			GoalCheck.BY_THE_WORLD,
			"%s's goal was closed by something other than the world" % who)


# --- 3. The cadence -------------------------------------------------------


func _the_cadence_is_one_rule_of_the_world() -> void:
	var scene := _bare_scene()
	var one := scene.actors[0]
	var upkeep := CharacterUpkeep.new()
	equal(upkeep.witnessed_after(one.id), -1,
		"a character that has never been served is recorded as having looked")

	var first := upkeep.serve(scene, one)
	check(bool(first["witnessed"]),
		"a character was not shown its surroundings at its first servicing")
	check(int(first["wrote"]) > 0, "the first look wrote nothing down")
	equal(upkeep.witnessed_after(one.id), 0,
		"the look was not keyed to the world's count of what the character has done")

	# Asked again with nothing done in between -- which is what a mind polled
	# while its call is outstanding looks like -- there is no second look.
	for _at in 6:
		check(not bool(upkeep.serve(scene, one)["witnessed"]),
			"a character looked again without having done anything")
	equal(upkeep.witnesses, 1, "servicing a character six times cost six looks")

	# One action carried out by the world, one more look. The count is the
	# world's own, written by the engine on the one path every action takes.
	ActionEngine.resolve(scene, one, Action.wait(1))
	equal(scene.actions_of(one.id), 1, "the engine did not count the action")
	check(bool(upkeep.serve(scene, one)["witnessed"]),
		"a character did not look again after the world carried something out")
	equal(upkeep.witnesses, 2, "the second action did not cost exactly one look")

	# A character standing in a scene with no ground under it -- which is what a
	# bare scene staged for a test is -- is served like any other, and the look it
	# takes reports the ground as unread rather than failing. The shared path
	# takes an observation for every character now, so this is the case that used
	# not to arise.
	var groundless := ActionScene.on()
	var standing := groundless.add_actor(Combatant.commander_at(
		0.0, 0.0, 0.0, 0.0, 2, AssetTags.KNIGHT))
	(standing.piece as Commander).adopt(Character.make("Odo", 2))
	var bare := CharacterUpkeep.new().serve(groundless, standing)
	check(bool(bare["witnessed"]),
		"a character standing where there is no ground was not served at all")
	var read := Observation.of(groundless, standing)
	check(read.board != null, "an observation with no ground under it has no window")
	var window := read.ground_lines()
	check(window.size() > 3, "a window over no ground printed no rows at all")
	check(String(window[1]).contains(MEANS_UNREAD),
		"the window's legend does not say what an unread cell is")
	var walkable := 0
	var unread := 0
	for at in range(2, window.size()):
		for token in String(window[at]).split(" ", false):
			if String(token).begins_with(Observation.GLYPHS["stand"]):
				walkable += 1
			elif String(token).begins_with(Observation.GLYPHS["unknown"]):
				unread += 1
	equal(walkable, 0, "a window over no ground reports ground to walk on")
	check(unread > 0, "a window over no ground reads as something other than unread")

	# Settling is not on that cadence: it is a reading of the world and happens
	# with every servicing, which is why a goal the world already answers closes
	# at the first one rather than whenever somebody next thinks to ask.
	var sheet := _sheet(one)
	sheet.goals.add(Goal.of(Goal.MONEY, {"amount": 1}, "", Goal.SHORT))
	var served := upkeep.serve(scene, one)
	check(not bool(served["witnessed"]),
		"a goal being settled cost a look the cadence does not allow")
	equal((served["closed"] as Array).size(), 1,
		"the goal the world answers was not closed at the very next servicing")


# --- 4. Closing by hand, from any driver ----------------------------------


func _closing_by_hand_is_reachable_by_any_driver() -> void:
	var scene := _bare_scene()
	var one := scene.actors[0]
	var sheet := _sheet(one)
	sheet.decide = DecisionSource.plan([])
	sheet.goals.add(Goal.of(Goal.MONEY, {"amount": 900}, "", Goal.LONG))
	sheet.goals.add(Goal.unwritten("be thought well of here", Goal.LONG))
	scene.advance(7)

	# The character a person drives closes the goal in its own words, through the
	# one shared closing, and the record says by whose hand.
	var closed := GoalCheck.close_by_hand(sheet.goals, 2, scene.tick)
	check(bool(closed["closed"]), "the shared closing refused a goal it should close")
	equal(sheet.goals.goal_of(2).closed_by, GoalCheck.CLOSED_BY_HAND,
		"a goal the character closed does not say so")
	equal(sheet.goals.goal_of(2).closed_at, scene.tick,
		"the closing was not stamped with the tick it happened on")
	var rows := GoalCheck.closings_of(sheet.goals)
	equal(rows.size(), 1, "the closing was not written down")
	equal(String(rows[0]["by"]), GoalCheck.BY_THE_CHARACTER,
		"a closing by the character is recorded as somebody else's")
	equal(sheet.goals.refusals.size(), 0,
		"an allowed closing was recorded as a refusal")

	# The one the world answers is refused, with the world named as the reason,
	# and the refusal is kept on the character's own set.
	var refused := GoalCheck.close_by_hand(sheet.goals, 1, scene.tick)
	check(not bool(refused["closed"]), "a character closed a goal the world answers")
	equal(String(refused["why"]), GoalCheck.NOT_YOURS_TO_CLOSE,
		"the refusal does not name the world as the reason")
	check(not sheet.goals.goal_of(1).closed, "a refused goal closed anyway")
	equal(sheet.goals.refusals.size(), 1, "the refusal was not written down")
	equal(String(sheet.goals.refusals[0]["why"]), GoalCheck.NOT_YOURS_TO_CLOSE,
		"the refusal was written down with some other reason")

	# Every one of the seven kinds the world answers is refused, so the boundary
	# is the list and not one example of it.
	for kind in GoalCheck.ANSWERED:
		var theirs := GoalSet.of([Goal.of(kind, {"amount": 1, "span": 1})])
		var answer := GoalCheck.close_by_hand(theirs, 1, 0)
		check(not bool(answer["closed"]),
			"a character closed a %s goal, which the world answers" % kind)
		equal(String(answer["why"]), GoalCheck.NOT_YOURS_TO_CLOSE,
			"closing a %s goal was refused for some other reason" % kind)

	# A number that names nothing open closes nothing and breaks nothing.
	var missing := GoalCheck.close_by_hand(sheet.goals, 9, scene.tick)
	check(not bool(missing["closed"]), "closing a goal that is not there closed something")
	equal(String(missing["why"]), GoalCheck.NO_SUCH_GOAL,
		"closing a goal that is not there was refused for some other reason")

	# And a model's `done` tool is one caller of that same closing: the record it
	# leaves is the record a plan-driven character's closing left, to the line.
	var theirs_scene := _bare_scene()
	var modelled := theirs_scene.actors[0]
	var mine := _sheet(modelled)
	mine.goals.add(Goal.of(Goal.MONEY, {"amount": 900}, "", Goal.LONG))
	mine.goals.add(Goal.unwritten("be thought well of here", Goal.LONG))
	theirs_scene.advance(7)
	var mind := _mind_saying("done goal=2")
	_ask(mind, theirs_scene, modelled)
	equal(_closing_lines(mine.goals), _closing_lines(sheet.goals),
		"the same closing made by two drivers is recorded differently")
	check(mine.goals.goal_of(2).closed_at > 0,
		"the model's closing was not stamped with the tick it happened on")

	# The refusal reaches the model's turn as well, in the world's own words.
	var refuser := _mind_saying("done goal=1")
	_ask(refuser, theirs_scene, modelled)
	equal(String(refuser.turns[0]["refused"]), GoalCheck.NOT_YOURS_TO_CLOSE,
		"the model was not told why its closing was refused")
	equal(mine.goals.refusals.size(), 1,
		"the model's refused closing was not written down on the character")


# --- 5. The shipped run ---------------------------------------------------


func _the_shipped_run_shows_it() -> void:
	var played := ScriptedAgent.played_with(
		ModelChannel.for_run(ModelRecording.exchange()))
	var scene: ActionScene = played["scene"]
	var person := _named(scene, ScriptedAgent.PERSON)
	var sheet := _sheet(person)
	check(sheet != null, "the run has no character driven by written-down choices")

	var events := sheet.memory.events.size()
	check(events > 0,
		"the character a person drives remembers nothing after the whole run")

	# Of the same order as the model-driven ones: within a factor of four of the
	# smallest of them, which is the loosest reading of "the same order" that says
	# anything at all.
	var least := -1
	for who in ScriptedAgent.MODEL_CAST:
		var theirs := _sheet(_named(scene, String(who)))
		if theirs == null:
			continue
		var held := theirs.memory.events.size()
		if least < 0 or held < least:
			least = held
	check(least > 0, "no model-driven character remembered anything either")
	check(events * 4 >= least,
		"the person-driven character remembers %d events against %d for the"
			% [events, least] + " thinnest model-driven one")

	# And the goal the world already answers true on that character closes at its
	# first servicing, in the world's own words, rather than staying open.
	var goals := sheet.goals
	check(goals.size() > 0, "the character a person drives was set out after nothing")
	var goal := goals.goal_of(1)
	check(goal.closed, "a goal the world answered at tick 0 is still open at the end")
	equal(goal.closed_at, 1, "the goal did not close at the character's first servicing")
	check(String(goal.closed_by).ends_with("money in the pack"),
		"the goal did not close in the world's own words: %s" % goal.closed_by)
	equal(String(GoalCheck.closings_of(goals)[0]["by"]), GoalCheck.BY_THE_WORLD,
		"the world's closing is recorded as somebody else's")


# --- The furniture --------------------------------------------------------


# Two characters standing three units apart, both carrying money.
func _bare_scene() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(ScriptedScenario.SEED))
	var at := ScriptedScenario.WHERE
	for row in [["Rook", ROOK_AT], ["Wren", WREN_AT]]:
		var where: Vector2 = at + (row[1] as Vector2)
		var one := scene.add_actor(Combatant.commander_at(
			where.x, where.y, 0.0, 0.0, 2, AssetTags.KNIGHT))
		(one.piece as Commander).adopt(Character.make(String(row[0]), 2))
		ActionScene.inventory_of(one).gain(MONEY)
		one.settle(scene.terrain)
	return scene


func _plan_for(one: Combatant, choices: Array) -> void:
	_sheet(one).decide = DecisionSource.plan(choices)


static func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


static func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == who:
			return one
	return null


# Every closing of a set as one line each, without the tick it happened on, so
# that two closings made in two runs of the world can be compared for everything
# except when they happened.
static func _closing_lines(goals: GoalSet) -> PackedStringArray:
	var written := PackedStringArray()
	for row in GoalCheck.closings_of(goals):
		var goal: Goal = row["goal"]
		written.append("%s closed by %s: %s" % [goal.said(), row["by"], row["how"]])
	return written


# A mind whose channel answers every question with one stated line.
func _mind_saying(reply: String) -> ModelMind:
	var rows := []
	for _at in 8:
		rows.append({"prompt": "", "reply": reply, "ms": 0})
	return ModelMind.with_channel(ModelChannel.replaying(
		{"rows": rows, "from": "written down by the suite", "model": "none"},
		"written down by the suite"))


# Ask a mind until its channel has answered, which takes `THINKS_FOR` ticks.
func _ask(mind: ModelMind, scene: ActionScene, actor: Combatant) -> void:
	for _at in ModelChannel.THINKS_FOR + 2:
		mind.answer_for(scene, actor)
		scene.advance(1)


func _files_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			found.append("%s/%s" % [directory, name])
	found.sort()
	return found


# One file's code, with comments and string literals stripped, so that prose
# about a call is not read as one.
func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in _read(path).split("\n"):
		kept.append(_code_line(String(line)))
	return " ".join(kept)


func _code_line(line: String) -> String:
	return String(AssetCheck.split_code_and_strings(line)["code"]).strip_edges()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
