extends TestSuite
## Structured goals: several at once, and the world -- not the character --
## saying which of them are finished.
##
## Every check here runs with no key, no network and no model, for the same
## reason `tests/test_agent.gd` does: the comparison run replays a written-down
## exchange, and a suite that needed a credential would be evidence the layer is
## not built the way it says it is.
##
## Eight claims:
##
##   1. **A character carries goals, plural.** A sheet holds a `GoalSet`; several
##      goals sit in it at once, each with a horizon, each closable, replaceable
##      and reprioritisable, and the numbering survives all three.
##   2. **A sheet nobody set a goal for is unchanged.** It is after nothing, its
##      identity line says so, and the prompt it is written into says so -- so a
##      character a person drives is exactly the sheet it was before this step.
##   3. **The world answers, kind by kind.** Every kind the engine claims to
##      answer is staged both ways -- once where the world says it is finished
##      and once where it does not -- and the answer is read out of the scene.
##   4. **Every kind is accounted for.** `Goal.KINDS` is exactly the kinds the
##      world answers plus the one it does not, so a kind cannot be added without
##      somebody deciding which hand closes it.
##   5. **A character may not close what the world answers.** Through the same
##      `done` tool a model uses: on a goal in its own words it closes; on any
##      goal the world answers it is refused, and the refusal is recorded.
##   6. **A trade is written down by the engine.** The `traded` goal is answered
##      out of `ActionScene.trades`, which `ActionEngine` writes on the one path a
##      trade goes through -- a denied offer writes nothing.
##   7. **Goals reach the prompt and carry no rule and no route.** A real prompt
##      for a character with goals holds each of them, holds no rule word, and no
##      line of the goals block names an action out of the catalogue.
##   8. **Nothing hard-codes a story, and the goals change what is chosen.** The
##      only files under `sim/` that make a goal are the scripted scenarios; and
##      the comparison run puts one question in one moment four times, differing
##      only in what the character is after, and the answers differ.
class_name TestGoals

## The comparison run's transcript and the command that prints it.
const TRANSCRIPT := "res://reports/goal-evidence.txt"
const COMMAND := "res://run_goal.sh"

## The directory the structural check reads, all of it.
const SIM_DIR := "res://sim"

## How a line of code makes a goal. Matched against code with comments and string
## literals stripped, so a mention in prose does not count.
const MAKES_A_GOAL := ["Goal.of(", "Goal.unwritten("]

## The only files under `sim/` allowed to make one. Scenario setup, both of them:
## the shipped run's own character and the controlled comparison's four arms.
## The machinery -- `goal.gd`, `goal_set.gd`, `goal_check.gd`, the prompt and the
## mind -- makes none, which is what "no quest is scripted" means here.
const MAY_MAKE_A_GOAL := [
	"res://sim/scripted_agent.gd",
	"res://sim/scripted_goal.gd",
]

## The file that declares `Goal` itself, which the scan skips. Inside the type,
## `unwritten()` is one constructor calling the other -- a goal nobody has asked
## for yet, with no words in it -- and not a goal the simulation is carrying.
const GOAL_FILE := "res://sim/goal.gd"

## A line that would be a story hard-coded into the machinery, which the scan has
## to catch for the check above to be worth anything.
const BROKEN_STORY := "	sheet.goals.add(Goal.unwritten(\"avenge your father\"))"

## Where the two characters of the bare scene stand, and what the third one
## carries.
const ROOK_AT := Vector2(0.0, 0.0)
const WREN_AT := Vector2(2.0, 0.0)
const FAR_OFF := Vector2(60.0, 0.0)
const LANTERN := "brass lantern"
const ROOK_MONEY := 30


func _init() -> void:
	suite_name = "goals"


func run() -> void:
	_a_character_carries_several()
	_replaceable_and_reprioritisable()
	_a_sheet_with_no_goal_is_unchanged()
	_the_world_answers_kind_by_kind()
	_every_kind_is_accounted_for()
	_a_character_may_not_close_what_the_world_answers()
	_a_trade_is_written_down_by_the_engine()
	_goals_reach_the_prompt_and_carry_no_rule()
	_the_machinery_holds_no_goal_of_its_own()
	_a_goal_changes_what_is_chosen()
	_two_processes_agree()


# --- 1. Several at once, each with a horizon ------------------------------


func _a_character_carries_several() -> void:
	var sheet := Character.make("Rook", 2)
	check(sheet.goals is GoalSet, "a character sheet does not carry a goal set")
	equal(sheet.goals.size(), 0, "a new character is already after something")

	var near := sheet.goals.add(Goal.of(
		Goal.BE_AT, {"target": Vector2(4.0, 1.0)}, "", Goal.SHORT, 0))
	var rich := sheet.goals.add(Goal.of(Goal.MONEY, {"amount": 50}, "", Goal.LONG, 2))
	var liked := sheet.goals.add(Goal.unwritten("be thought well of here", Goal.LONG, 1))

	equal(sheet.goals.size(), 3, "three goals did not all land on the sheet")
	equal(sheet.goals.open().size(), 3, "a goal was not open the moment it landed")
	equal([near.id, rich.id, liked.id], [1, 2, 3],
		"goals were not numbered from one in the order they were added")
	equal(near.horizon, Goal.SHORT, "a short goal did not come back short")
	equal(rich.horizon, Goal.LONG, "a long goal did not come back long")
	equal(sheet.goals.open_over(Goal.LONG).size(), 2,
		"the two long goals were not both found over that horizon")

	# Most pressing first, and within one priority in the order they were added.
	equal(_numbers(sheet.goals.open()), [1, 3, 2],
		"open goals did not come back most pressing first")

	# Completable: it closes, it stays in the set, and it says how it closed.
	check(sheet.goals.close(1, "0.2 from (4.0, 1.0)", 40), "a goal would not close")
	check(not sheet.goals.close(1, "again", 41), "a closed goal closed twice")
	equal(sheet.goals.open().size(), 2, "a closed goal is still open")
	equal(sheet.goals.size(), 3, "a closed goal fell out of the set")
	equal(sheet.goals.goal_of(1).closed_by, "0.2 from (4.0, 1.0)",
		"a closed goal does not carry how it closed")
	equal(sheet.goals.goal_of(1).closed_at, 40,
		"a closed goal does not carry when it closed")
	equal(_numbers(sheet.goals.done()), [1], "the finished goal is not the finished one")


func _replaceable_and_reprioritisable() -> void:
	var goals := GoalSet.of([
		Goal.of(Goal.MONEY, {"amount": 20}, "", Goal.LONG, 0),
		Goal.unwritten("see the far bank", Goal.LONG, 1),
	])

	# Replaceable: the new goal takes the old one's number and its place in the
	# order, and the old one is gone rather than recorded as finished.
	var put := goals.replace(1, Goal.of(Goal.HOLD, {"item": LANTERN}, "", Goal.SHORT))
	check(put != null, "a goal would not be replaced")
	equal(put.id, 1, "a replacing goal did not take the number it replaced")
	equal(goals.size(), 2, "replacing a goal grew the set")
	equal(goals.goal_of(1).kind, Goal.HOLD, "the replacement is not in the set")
	equal(goals.done().size(), 0,
		"a replaced goal was recorded as finished, which it never was")
	check(goals.replace(9, Goal.unwritten("nowhere")) == null,
		"a goal that is not in the set was replaced anyway")

	# Reprioritisable: the order the set hands them back in changes with it.
	equal(_numbers(goals.open()), [1, 2], "the goals did not start in that order")
	check(goals.reprioritise(2, -1), "a goal would not be reprioritised")
	equal(_numbers(goals.open()), [2, 1], "reprioritising did not change the order")
	check(not goals.reprioritise(9, 0), "a goal that is not in the set was reordered")


# --- 2. A sheet nobody set a goal for -------------------------------------


func _a_sheet_with_no_goal_is_unchanged() -> void:
	var sheet := Character.make("Wren", 3)
	sheet.backstory = "a marsh lantern-keeper's daughter"
	sheet.traits = PackedStringArray(["curious"])
	check(sheet.goals.is_empty(), "a sheet nobody set a goal for is after something")
	equal(sheet.goals_line(), "-", "a sheet after nothing does not print a dash")
	check(sheet.identity_line().contains("goals: -"),
		"the identity line of a sheet after nothing does not say so")
	check(sheet.identity_line().contains("marsh lantern-keeper"),
		"the identity line stopped carrying the backstory")

	# And the prompt written for it says the same thing rather than inventing one.
	var written := ModelPrompt.goal_lines(sheet.goals)
	equal(written.size(), 1, "a character after nothing got more than one line about it")
	equal(written[0], ModelPrompt.WANTS_NOTHING,
		"a character after nothing is not told so")
	equal(ModelPrompt.goal_lines(null)[0], ModelPrompt.WANTS_NOTHING,
		"a character with no goal set at all is not told so either")


# --- 3. The world answers, kind by kind -----------------------------------


func _the_world_answers_kind_by_kind() -> void:
	var scene := _bare_scene()
	var rook := scene.actors[0]
	var wren := scene.actors[1]
	var far := scene.actors[2]
	var pile := scene.objects[0]

	# Being at a position: the engine's own arrival gap, and nothing invented.
	_answers(scene, rook, Goal.of(Goal.BE_AT, {"target": Vector2(rook.x, rook.z)}),
		true, "standing on the position it is after")
	_answers(scene, rook, Goal.of(Goal.BE_AT, {"target": Vector2(rook.x + 40.0, rook.z)}),
		false, "forty units off the position it is after")

	# Being beside a character or a thing: the engine's own reach.
	_answers(scene, rook, Goal.of(Goal.BE_AT, {"target": wren.id}), true,
		"two units from the character it is after")
	_answers(scene, rook, Goal.of(Goal.BE_AT, {"target": far.id}), false,
		"sixty units from the character it is after")
	_answers(scene, rook, Goal.of(Goal.BE_AT, {"target": pile.id}), true,
		"beside the pile it is after")

	# Carrying a named thing, looked for in the pack the engine moves things in.
	_answers(scene, rook, Goal.of(Goal.HOLD, {"item": LANTERN}), false,
		"not carrying the thing it is after")
	ActionScene.inventory_of(rook).carry(_tool(LANTERN))
	_answers(scene, rook, Goal.of(Goal.HOLD, {"item": LANTERN}), true,
		"carrying the thing it is after")

	# Money, standing, and being clear of somebody.
	_answers(scene, rook, Goal.of(Goal.MONEY, {"amount": ROOK_MONEY}), true,
		"carrying exactly the money it is after")
	_answers(scene, rook, Goal.of(Goal.MONEY, {"amount": ROOK_MONEY + 1}), false,
		"one short of the money it is after")
	_answers(scene, rook, Goal.of(Goal.STANDING, {"amount": 3}), true,
		"at the standing it is after")
	_answers(scene, rook, Goal.of(Goal.STANDING, {"amount": 9}), false,
		"below the standing it is after")
	_answers(scene, rook, Goal.of(Goal.APART_FROM, {"target": far.id, "span": 20}), true,
		"sixty units clear of the character it wants to be clear of")
	_answers(scene, rook, Goal.of(Goal.APART_FROM, {"target": wren.id, "span": 20}), false,
		"two units from the character it wants to be clear of")

	# Somebody out of the world: it is not, then it is.
	_answers(scene, rook, Goal.of(Goal.FELLED, {"target": wren.id}), false,
		"the character it is after is standing")
	scene.actors.remove_at(1)
	_answers(scene, rook, Goal.of(Goal.FELLED, {"target": wren.id}), true,
		"the character it is after is out of the world")

	# And `settle` closes exactly the ones the world says are finished, out of the
	# scene, without anybody being asked.
	var goals := GoalSet.of([
		Goal.of(Goal.MONEY, {"amount": ROOK_MONEY}),
		Goal.of(Goal.MONEY, {"amount": ROOK_MONEY + 100}),
		Goal.unwritten("be thought well of here"),
	])
	scene.advance(77)
	var closed := GoalCheck.settle(goals, scene, rook)
	equal(closed.size(), 1, "settling closed something other than the one met goal")
	equal(_numbers(goals.done()), [1], "the goal the world met is not the closed one")
	equal(goals.goal_of(1).closed_at, scene.tick,
		"a goal did not close at the tick the world was asked on")
	equal(_numbers(goals.open()), [2, 3], "settling closed a goal it should not have")
	check(GoalCheck.settle(goals, scene, rook).is_empty(),
		"settling twice closed the same goal twice")

	# A goal the world does not answer is never closed by settling, however long
	# it is left: that is the honest answer and not a failure.
	equal(GoalCheck.met(goals.goal_of(3), scene, rook)["met"], false,
		"the world claimed to answer a goal it holds no state for")
	check(not GoalCheck.answers(goals.goal_of(3)),
		"the world claims it can answer a goal in the character's own words")


func _every_kind_is_accounted_for() -> void:
	var accounted := GoalCheck.ANSWERED.duplicate()
	accounted.append(Goal.UNWRITTEN)
	accounted.sort()
	var all_kinds := Goal.KINDS.duplicate()
	all_kinds.sort()
	equal(all_kinds, accounted,
		"a goal kind exists that nobody has decided which hand closes")
	for kind in GoalCheck.ANSWERED:
		check(GoalCheck.answers(Goal.of(kind)),
			"%s is listed as answered by the world and is not" % kind)
	check(not GoalCheck.answers(Goal.unwritten("anything")),
		"a goal in the character's own words is claimed by the world")
	check(not GoalCheck.answers(null), "a goal that is not there is answered")


# --- 5. Whose hand closes a goal ------------------------------------------


func _a_character_may_not_close_what_the_world_answers() -> void:
	var scene := _bare_scene()
	var rook := scene.actors[0]
	var sheet := (rook.piece as Commander).sheet
	sheet.goals.add(Goal.of(Goal.MONEY, {"amount": 900}, "", Goal.LONG))
	sheet.goals.add(Goal.unwritten("be thought well of here", Goal.LONG))

	# The character says the first is done. The world answers that one, so it is
	# refused with the world named as the reason and the goal stays open. Both the
	# refusal and, below, the closing are kept on the character's own goal set,
	# written by `GoalCheck.close_by_hand` -- the one closing every driver reaches
	# and `tests/test_upkeep.gd` exercises from the other side.
	var mind := _mind_saying("done goal=1")
	_ask(mind, scene, rook)
	check(not sheet.goals.goal_of(1).closed,
		"a character closed a goal the world answers")
	equal(sheet.goals.refusals.size(), 1, "the refusal was not written down")
	equal(String(sheet.goals.refusals[0]["why"]), GoalCheck.NOT_YOURS_TO_CLOSE,
		"the refusal does not name the world as the reason")
	equal(String(mind.turns[0]["refused"]), GoalCheck.NOT_YOURS_TO_CLOSE,
		"the model was not told why its closing was refused")
	equal(GoalCheck.closings_of(sheet.goals).size(), 0,
		"a refused closing was counted as a closing")

	# The second names nothing the world holds, so the character closes it and the
	# run can say by whose hand.
	var second := _mind_saying("done goal=2")
	_ask(second, scene, rook)
	check(sheet.goals.goal_of(2).closed,
		"a character could not close a goal only it can answer")
	equal(sheet.goals.goal_of(2).closed_by, GoalCheck.CLOSED_BY_HAND,
		"a goal the character closed does not say so")
	var closings := GoalCheck.closings_of(sheet.goals)
	equal(closings.size(), 1, "the closing was not written down")
	equal(String(closings[0]["by"]), GoalCheck.BY_THE_CHARACTER,
		"a closing by the character is recorded as somebody else's")
	equal(sheet.goals.refusals.size(), 1, "an allowed closing was recorded as refused")

	# A number that is not a goal closes nothing and breaks nothing.
	var third := _mind_saying("done goal=9")
	_ask(third, scene, rook)
	equal(GoalCheck.closings_of(sheet.goals).size(), 1,
		"closing a goal that is not there closed something")
	equal(String(sheet.goals.refusals[1]["why"]), GoalCheck.NO_SUCH_GOAL,
		"closing a goal that is not there was refused for some other reason")

	# And the world's own closings are recorded as the world's, out of the shared
	# servicing path rather than out of any driver.
	sheet.goals.add(Goal.of(Goal.MONEY, {"amount": 1}, "", Goal.SHORT))
	CharacterUpkeep.new().serve(scene, rook)
	check(sheet.goals.goal_of(3).closed, "the world did not close the goal it answers")
	equal(String(GoalCheck.closings_of(sheet.goals)[1]["by"]), GoalCheck.BY_THE_WORLD,
		"a closing by the world is recorded as somebody else's")


# --- 6. A trade the engine wrote down -------------------------------------


func _a_trade_is_written_down_by_the_engine() -> void:
	var scene := _bare_scene()
	var rook := scene.actors[0]
	var wren := scene.actors[1]
	ActionScene.inventory_of(wren).carry(_tool(LANTERN))
	var wanted := Goal.of(Goal.TRADED, {"target": wren.id})
	equal(GoalCheck.met(wanted, scene, rook)["met"], false,
		"a trade that has not happened is answered as having happened")

	# A denied offer writes nothing down: the engine records the trades it
	# honoured and not the ones it was asked for.
	ActionEngine.resolve(scene, wren, Action.trade_propose(
		rook.id, PackedStringArray([LANTERN]), 0, PackedStringArray(), 5))
	ActionEngine.resolve(scene, rook, Action.trade_deny(wren.id))
	equal(scene.trades.size(), 0, "a denied offer was written down as a trade")
	equal(GoalCheck.met(wanted, scene, rook)["met"], false,
		"a denied offer answered a trade goal")

	# An honoured one is.
	scene.advance(12)
	ActionEngine.resolve(scene, wren, Action.trade_propose(
		rook.id, PackedStringArray([LANTERN]), 0, PackedStringArray(), 5))
	var outcome := ActionEngine.resolve(scene, rook, Action.trade_accept(wren.id))
	check(outcome.ok, "the trade was refused: %s" % outcome.line())
	equal(scene.trades.size(), 1, "an honoured trade was not written down")
	equal(int(scene.trades[0]["tick"]), scene.tick,
		"the trade was not written down at the tick it happened")
	check(bool(GoalCheck.met(wanted, scene, rook)["met"]),
		"an honoured trade did not answer the trade goal")
	check(bool(GoalCheck.met(Goal.of(Goal.TRADED), scene, rook)["met"]),
		"an honoured trade did not answer a trade goal naming nobody in particular")
	check(not bool(GoalCheck.met(
		Goal.of(Goal.TRADED, {"target": 999}), scene, rook)["met"]),
		"a trade with one character answered a goal about another")


# --- 7. In the prompt, with no rule and no route --------------------------


func _goals_reach_the_prompt_and_carry_no_rule() -> void:
	var scene := _bare_scene()
	var rook := scene.actors[0]
	var sheet := (rook.piece as Commander).sheet
	sheet.goals.add(Goal.of(Goal.BE_AT, {"target": scene.actors[1].id}, "", Goal.SHORT))
	sheet.goals.add(Goal.of(Goal.HOLD, {"item": LANTERN}, "", Goal.SHORT, 1))
	sheet.goals.add(Goal.unwritten("be thought well of here", Goal.LONG, 2))
	sheet.goals.add(Goal.of(Goal.MONEY, {"amount": 1}, "", Goal.LONG, 3))
	check(sheet.goals.close(4, "30 money in the pack", 3), "a goal would not close")

	var prompt := ModelPrompt.written_for(
		Observation.of(scene, rook), sheet.memory, {}, sheet.goals)
	var block := ModelPrompt.goal_block_of(prompt)
	check(block != "", "the prompt carries no goals block at all")
	for goal in sheet.goals.held:
		check(block.contains(goal.said()),
			"the prompt does not carry the goal \"%s\"" % goal.said())
	check(block.contains(ModelPrompt.WORLD_ANSWERS),
		"the prompt does not say which goals the world answers")
	check(block.contains(ModelPrompt.DONE),
		"the prompt does not say how a character closes its own goal")
	check(block.contains("30 money in the pack"),
		"the prompt does not carry how a finished goal finished")

	# No rule, in the goals block or anywhere else in the prompt.
	equal(_rule_words_in(block), PackedStringArray(),
		"the goals block carries a rule word")
	equal(_rule_words_in(prompt), PackedStringArray(),
		"the prompt carries a rule word")
	check(_rule_words_in(TestAgent.BROKEN_PROMPT).size() > 0,
		"the rule scan does not fire on a sentence that is a rule")

	# And no route: no line of the block names an action out of the catalogue, so
	# a goal cannot be read as an instruction to do a particular thing.
	var named := PackedStringArray()
	for line in ModelPrompt.goal_lines(sheet.goals):
		for row in ActionCatalog.ROWS:
			if _names_whole_word(line, String(row["name"])):
				named.append("%s -> %s" % [line, row["name"]])
	equal(named, PackedStringArray(),
		"a line of the goals block names an action, which makes it an instruction")


# --- 8. No story in the machinery, and a goal that bends a choice ---------


func _the_machinery_holds_no_goal_of_its_own() -> void:
	var sources := _files_under(SIM_DIR)
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())
	var makers := PackedStringArray()
	for path in sources:
		if path != GOAL_FILE and _makes_a_goal(_code_of(path)):
			makers.append(path)
	equal(makers, PackedStringArray(MAY_MAKE_A_GOAL),
		"a file under sim/ makes a goal that is not scenario setup")

	# The scan has teeth: a goal written into the machinery is caught by the same
	# detector that just found none.
	check(_makes_a_goal(BROKEN_STORY),
		"the scan would not notice a goal hard-coded into the machinery")
	check(not _makes_a_goal(_code_of("res://sim/goal_check.gd")),
		"the file that answers goals turns out to make one")


func _a_goal_changes_what_is_chosen() -> void:
	var played := ScriptedGoal.played_with(
		ModelChannel.for_run(ModelRecording.goal_exchange()))
	var arms: Array[Dictionary] = played["arms"]
	equal(arms.size(), ScriptedGoal.ARMS.size(), "an arm did not run")
	check(bool(played["same_situation"]),
		"the four arms were not asked about the same moment")
	check(bool(played["same_memory"]),
		"the four arms did not remember the same things")
	check(bool(played["same_outside_goals"]),
		"the four prompts differ somewhere other than in what the character is after")

	# The claim: with everything else held still, being after something changed
	# what came back. At least one arm chose differently from the arm that was
	# after nothing.
	var baseline: Dictionary = arms[0]
	equal(String(baseline["name"]), "no goal", "the baseline arm is not the bare one")
	var differed := 0
	for at in range(1, arms.size()):
		if String(arms[at]["line"]) != String(baseline["line"]):
			differed += 1
	check(differed > 0,
		"no goal changed what was chosen: every arm chose %s" % baseline["line"])

	# And each arm's block says which hand closes its goal.
	for at in range(1, arms.size()):
		var goals: GoalSet = arms[at]["goals"]
		equal(goals.size(), 1, "an arm carried other than one goal")


func _two_processes_agree() -> void:
	var first := _run_goal()
	equal(int(first["code"]), 0, "the goal run exited non-zero")
	var second := _run_goal()
	equal(String(second["text"]), String(first["text"]),
		"two runs of the goal comparison printed different bytes")
	equal(_read(TRANSCRIPT).strip_edges(), String(first["text"]).strip_edges(),
		"the checked-in transcript is not what the command prints")


# --- The furniture --------------------------------------------------------


# One goal answered against a staged world, both ways round.
func _answers(
	scene: ActionScene, actor: Combatant, goal: Goal, expected: bool, why: String
) -> void:
	var answer := GoalCheck.met(goal, scene, actor)
	equal(bool(answer["met"]), expected,
		"%s: the world answered \"%s\"" % [why, answer["how"]])
	check(String(answer["how"]) != "", "the world answered %s with no words" % goal.kind)


# Three characters and a pile: Rook, Wren two units off, one far away, and
# something lying where Rook is standing.
func _bare_scene() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(ScriptedScenario.SEED))
	var at := ScriptedScenario.WHERE
	var rook := _stand(scene, "Rook", 3, at + ROOK_AT)
	ActionScene.inventory_of(rook).gain(ROOK_MONEY)
	_stand(scene, "Wren", 2, at + WREN_AT)
	_stand(scene, "Odo", 2, at + FAR_OFF)
	scene.add_object(WorldObject.loose(
		at.x + ROOK_AT.x, at.y + ROOK_AT.y, Inventory.ground([])))
	return scene


func _stand(scene: ActionScene, called: String, at_level: int, where: Vector2) -> Combatant:
	var one := scene.add_actor(Combatant.commander_at(
		where.x, where.y, 0.0, 0.0, at_level, AssetTags.KNIGHT))
	(one.piece as Commander).adopt(Character.make(called, at_level))
	one.settle(scene.terrain)
	return one


# A mind whose channel answers every question with one stated line, driven until
# it has taken the answer. The same `ModelChannel` a shipped run uses.
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


# A hand-held item at level 1, forged exactly as the scenario forges one.
func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


func _numbers(goals: Array[Goal]) -> Array:
	var found := []
	for goal in goals:
		found.append(goal.id)
	return found


# Whether a line of code makes a goal, with comments and string literals stripped
# so that prose about goals is not mistaken for one.
func _makes_a_goal(source: String) -> bool:
	var code: String = AssetCheck.split_code_and_strings(source)["code"]
	for how in MAKES_A_GOAL:
		if code.contains(how):
			return true
	return false


func _names_whole_word(text: String, word: String) -> bool:
	var finder := RegEx.new()
	finder.compile("\\b%s\\b" % word)
	return finder.search(text) != null


func _rule_words_in(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	var finder := RegEx.new()
	finder.compile("(?i)\\b(%s)\\b" % ModelPrompt.RULE_WORDS)
	for hit in finder.search_all(text):
		if not found.has(hit.get_string()):
			found.append(hit.get_string())
	return found


func _files_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			found.append("%s/%s" % [directory, name])
	found.sort()
	return found


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in _read(path).split("\n"):
		kept.append(AssetCheck.split_code_and_strings(line)["code"].strip_edges())
	return " ".join(kept)


func _run_goal() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path(COMMAND), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
