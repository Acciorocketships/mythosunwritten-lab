extends TestSuite
## An ask that costs the world no time cannot be made forever.
##
## Twelve of the thirteen things a mind may answer with cost the character a span
## of ticks. The other three -- the `recall`, `learn` and `done` tools -- cost
## nothing, return on the tick they are asked and leave the world exactly as it
## was, so the next question is the same question. A cheap local model spent
## 4,711 of one run's 4,854 turns on `recall` and four of its five characters
## resolved no action at all.
##
## `ToolBudget` is the guard, and these are the five claims about it, all run
## with no key, no network and no model:
##
##   1. **The world does the arithmetic.** `ToolBudget.FREE` asks between the
##      turns a character spends are free; the next is refused in the world's own
##      words, counted as the turn it spent, and costs the character
##      `ToolBudget.costs()` ticks -- which is not a new number but what the
##      catalogue already charges for `examine`.
##   2. **One turn, and not the rest of the run.** Asking again while standing
##      that turn out is refused and charges nothing further; when the span runs
##      out the character chooses again and its free asks are back.
##   3. **It is a rule of the world and not of one mind.** Three characters of
##      three kinds -- a person's choices, a program's rule, a model's mind --
##      are refused at the same ask, charged the same turn, held for the same
##      span and asked again afterwards, under one `ControlLoop`.
##   4. **A refused tool is carried out on nothing, and the mind does not phrase
##      the refusal.** No lesson is written and no goal closed; the world's
##      sentence is what reaches the next prompt.
##   5. **A run that is refused nothing writes the prompt it always wrote.** The
##      refusal line appears in a prompt only when there was a refusal, so the
##      shipped recording still replays.
class_name TestToolBudget

## The directory the structural scan reads, all of it.
const SIM_DIR := "res://sim"

## Where the characters stand and what they are worth.
const LEVEL := 2
const APART := 40.0

## How long the three-minds scene is lived for.
const TICKS := 40

## What a look is asked about, and what a lesson would say.
const ABOUT := "road"
const LESSON := "the road bends north past the mill"


func _init() -> void:
	suite_name = "tool budget"


func run() -> void:
	_the_world_does_the_arithmetic()
	_one_turn_and_not_the_rest_of_the_run()
	_a_rule_of_the_world_and_not_of_one_mind()
	_a_refused_tool_is_carried_out_on_nothing()
	_refused_nothing_writes_the_prompt_it_always_wrote()


# --- 1. The arithmetic ----------------------------------------------------


func _the_world_does_the_arithmetic() -> void:
	var scene := _scene()
	var one := scene.actors[0]
	equal(ToolBudget.costs(), ActionCatalog.occupies_of(ActionCatalog.EXAMINE),
		"an ask past the budget costs something other than what a look costs")
	check(ToolBudget.FREE > 0, "no ask is free at all")

	for at in ToolBudget.FREE:
		var answer := ToolBudget.asked(scene, one)
		check(bool(answer["allowed"]),
			"ask %d of %d free was refused" % [at + 1, ToolBudget.FREE])
		equal(int(answer["taken"]), at + 1, "the world lost count of the asks")
		equal(String(answer["why"]), "", "an allowed ask came with a refusal")
	equal(scene.actions_of(one.id), 0, "a free ask cost the character a turn")
	equal(scene.asks_refused.size(), 0, "a free ask was written down as refused")

	var refused := ToolBudget.asked(scene, one)
	check(not bool(refused["allowed"]),
		"the ask past the budget was allowed after all")
	check(String(refused["why"]).begins_with(ActionScene.name_of(one)),
		"the refusal does not name the character it is addressed to")
	check(String(refused["why"]).contains("costs it a turn"),
		"the refusal does not say what it costs: %s" % refused["why"])
	equal(scene.actions_of(one.id), 1,
		"a refused ask cost the character something other than one turn")
	equal(scene.spent_until_of(one.id), scene.tick + ToolBudget.costs(),
		"the character stands for something other than what a look costs")
	equal(scene.asks_refused.size(), 1, "the world kept no record of the refusal")
	equal(String(scene.asks_refused[0]["why"]), String(refused["why"]),
		"the world wrote down a different sentence from the one it gave")
	check(not ToolBudget.free_to_choose(scene, one.id),
		"the character may still choose in the turn the ask cost it")


# --- 2. One turn -----------------------------------------------------------


func _one_turn_and_not_the_rest_of_the_run() -> void:
	var scene := _scene()
	var one := scene.actors[0]
	for _at in ToolBudget.FREE + 1:
		ToolBudget.asked(scene, one)
	var spent := scene.actions_of(one.id)
	var until := scene.spent_until_of(one.id)

	for _again in 5:
		var answer := ToolBudget.asked(scene, one)
		check(not bool(answer["allowed"]), "asking while standing was allowed")
		check(String(answer["why"]).contains("standing out the turn"),
			"the world gave the wrong reason to a character already standing")
	equal(scene.actions_of(one.id), spent,
		"hammering the door cost the character more than one turn")
	equal(scene.spent_until_of(one.id), until,
		"hammering the door made the character stand longer")

	scene.advance(ToolBudget.costs())
	check(ToolBudget.free_to_choose(scene, one.id),
		"the character is still shut out after the turn it paid for")

	# Asking again is charged again, and charged the same: the free ones do not
	# come back for a look, so a mind that has stopped acting pays a turn for
	# every question it asks. That is the bound.
	var again := ToolBudget.asked(scene, one)
	check(not bool(again["allowed"]), "the free asks came back for a look")
	equal(scene.actions_of(one.id), spent + 1,
		"asking again cost the character something other than one more turn")
	equal(scene.spent_until_of(one.id), scene.tick + ToolBudget.costs(),
		"the second charge stood the character a different length of time")

	# And they come back the moment the world carries an action out for it.
	scene.advance(ToolBudget.costs())
	ActionEngine.resolve(scene, one, Action.wait(1))
	var acted := ToolBudget.asked(scene, one)
	check(bool(acted["allowed"]), "the free asks did not come back after an action")
	equal(int(acted["taken"]), 1, "the world did not forget the spent asks")


# --- 3. Every mind alike ---------------------------------------------------


func _a_rule_of_the_world_and_not_of_one_mind() -> void:
	var scene := _scene(3)
	var person := scene.actors[0]
	var program := scene.actors[1]
	var model := scene.actors[2]

	# A person: their hand is outside the loop, between ticks, and what they
	# press is a choice put into a `LiveChoice`.
	var hand := LiveChoice.new()
	var pressed := [0]
	_sheet(person).decide = DecisionSource.live(hand)

	# A program: a rule that reaches for the same thing and answers nothing at
	# all while it is reaching.
	var reaches := [0]
	_sheet(program).decide = DecisionSource.scripted(
		func(world: ActionScene, actor: Combatant) -> Action:
			if reaches[0] >= ToolBudget.FREE + 1:
				return Action.wait(1)
			reaches[0] += 1
			ToolBudget.asked(world, actor)
			return null)

	# A model: a mind reading replies that name the tool.
	var replies := []
	for _at in ToolBudget.FREE + 1:
		replies.append({"prompt": "", "reply": "%s about=%s" % [ModelPrompt.RECALL, ABOUT], "ms": 0})
	replies.append({"prompt": "", "reply": "%s ticks=1" % ActionCatalog.WAIT, "ms": 0})
	var mind := ModelMind.with_channel(ModelChannel.replaying(
		{"rows": replies, "from": "written here", "model": "none"}, "a test"))
	_sheet(model).decide = DecisionSource.model(mind)

	var loop := ControlLoop.on(scene, 7)
	for _tick in TICKS:
		loop.step()
		if pressed[0] < ToolBudget.FREE + 1 and ToolBudget.free_to_choose(scene, person.id):
			pressed[0] += 1
			ToolBudget.asked(scene, person)
			if pressed[0] == ToolBudget.FREE + 1:
				hand.choose(Action.wait(1))

	for one in [person, program, model]:
		var charged := _charges(scene, one.id)
		equal(charged.size(), 1, "%s was charged %d times, not once" % [
			ActionScene.name_of(one), charged.size(),
		])
		check(String(charged[0]["why"]).contains("costs it a turn"),
			"%s was given a different rule from the others" % ActionScene.name_of(one))
	# The same sentence for all three, once each name is taken off the front.
	var sentences := {}
	for row in scene.asks_refused:
		sentences[String(row["why"]).split(" ", true, 1)[1]] = true
	equal(sentences.size(), 1,
		"the world said %d different things to three minds" % sentences.size())

	# And none of them was shut out: each was asked again and acted.
	for one in [person, program, model]:
		check(loop.actions_of(one.id) > 0,
			"%s never acted after the turn its ask cost it" % ActionScene.name_of(one))
	_release(scene)


# --- 4. What a refused tool does ------------------------------------------


func _a_refused_tool_is_carried_out_on_nothing() -> void:
	var scene := _scene()
	var one := scene.actors[0]
	var sheet := _sheet(one)
	var replies := []
	for _at in ToolBudget.FREE:
		replies.append({"prompt": "", "reply": "%s about=%s" % [ModelPrompt.RECALL, ABOUT], "ms": 0})
	replies.append({"prompt": "", "reply": "%s text=%s" % [ModelPrompt.LEARN, LESSON], "ms": 0})
	var mind := ModelMind.with_channel(ModelChannel.replaying(
		{"rows": replies, "from": "written here", "model": "none"}, "a test"))
	sheet.decide = DecisionSource.model(mind)

	var loop := ControlLoop.on(scene, 7)
	loop.run(4 * ModelChannel.THINKS_FOR + 4)
	equal(mind.refused_asks, 1, "the world refused %d asks, not one" % mind.refused_asks)
	equal(sheet.memory.lessons.size(), 0,
		"a refused learn was carried out on the character's memory anyway")
	equal(mind.lessons_written, 0, "a refused learn was counted as written")

	var refused := PackedStringArray()
	for turn in mind.turns:
		if String(turn["refused"]) != "":
			refused.append(String(turn["refused"]))
	equal(refused.size(), 1, "the turn does not carry what the world said")
	equal(refused[0], String(scene.asks_refused[0]["why"]),
		"the mind wrote its own sentence instead of the world's")

	# And the mind does not phrase it: the words are the world's file's alone,
	# read off the two files whole, prose and strings and all.
	check(not _read("res://sim/model_mind.gd").contains("costs it a turn"),
		"the mind phrases the world's refusal itself")
	check(_read("res://sim/tool_budget.gd").contains("costs it a turn"),
		"the world's file does not carry the world's sentence")
	_release(scene)


# --- 5. A prompt nobody was refused anything in ---------------------------


func _refused_nothing_writes_the_prompt_it_always_wrote() -> void:
	var scene := _scene()
	var one := scene.actors[0]
	var seen := Observation.of(scene, one)
	var remembered := _sheet(one).memory
	remembered.witness(seen)

	var plain := ModelPrompt.written_for(seen, remembered, {}, null)
	var looked := ModelPrompt.written_for(
		seen, remembered, {"about": ABOUT, "lines": PackedStringArray()}, null)
	var told := ModelPrompt.written_for(seen, remembered, {
		"tool": ModelPrompt.RECALL, "about": ABOUT, "refused": "a sentence",
	}, null)

	check(not plain.contains("the world refused"),
		"a prompt nobody was refused anything in carries a refusal line")
	check(not looked.contains("the world refused"),
		"a prompt whose look was allowed carries a refusal line")
	check(told.contains("the world refused your %s: a sentence" % ModelPrompt.RECALL),
		"the world's sentence does not reach the character that was refused")
	check(ModelPrompt.digest_of(plain) != ModelPrompt.digest_of(told),
		"being refused changes nothing about what the character is shown")

	# The whole difference is that one line: take it out and the two prompts are
	# the same bytes, which is why a run with no refusal in it still replays.
	equal(told.replace("  the world refused your %s: a sentence\n"
		% ModelPrompt.RECALL, ""), plain,
		"a refusal changes more of the prompt than the sentence it is")


# --- The furniture --------------------------------------------------------


func _scene(how_many: int = 1) -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(ScriptedScenario.SEED))
	for at in how_many:
		var where: Vector2 = ScriptedScenario.WHERE + Vector2(APART * at, 0.0)
		var one := scene.add_actor(Combatant.commander_at(
			where.x, where.y, 0.0, 0.0, LEVEL, AssetTags.KNIGHT))
		(one.piece as Commander).adopt(Character.make("Ash%d" % (at + 1), LEVEL))
		one.settle(scene.terrain)
	return scene


func _charges(scene: ActionScene, id: int) -> Array:
	var found := []
	for row in scene.asks_refused:
		if int(row["id"]) == id:
			found.append(row)
	return found


static func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet


static func _release(scene: ActionScene) -> void:
	for one in scene.actors:
		if one.piece is Commander:
			(one.piece as Commander).sheet.decide = Callable()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
