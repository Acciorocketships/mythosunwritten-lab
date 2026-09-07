extends TestSuite
## The two ways section 6 says sentiment goes up: a deed somebody wanted, and
## talk that got past a difficulty class.
##
## Every check in this file runs with no key, no network and no model, for the
## reason `tests/test_checks.gd` gives: the model layer is built so that a written
## reply stands in for a live call everywhere except the one command that makes
## the recording, and a suite that needed a credential would be evidence that it
## is not.
##
## Eight claims:
##
##   1. **Talk is hook-triggered, at one place, and only for a line addressed to
##      one character.** A shout raises none, a line to a thing that keeps no
##      sheet raises none, and a line to a character raises exactly one, whose
##      triggering context is that character and nothing else.
##   2. **The class is the engine's, out of the written formula.** It is
##      `TALK_FLOOR` plus the listener's wisdom plus the greater of its status and
##      its level, and it comes from `AbilityCheck.class_for_talk` rather than
##      from a reply -- so a failed persuasion costs no model call at all, and no
##      answer a model could give changes the class or the verdict.
##   3. **The model judges an amount and the engine applies it.** A reply that
##      says the two are now friends moves nothing; a number outside the range the
##      question asked for is refused and moves nothing; a number inside it is
##      bounded to what one thing may be worth and raises trust at one end of one
##      edge by exactly that.
##   4. **A repeat does not re-roll, and earns nothing further.** The second
##      attempt at the same person is settled out of that character's memory: no
##      call, no roll, and no second helping of goodwill. That holds while the
##      first is still in flight as well as after it has settled.
##   5. **A deed is read off the world's own records.** The trade that closed the
##      goal names the doer; a goal the character met by walking somewhere names
##      nobody; a dealing from before the world last said the goal was unmet names
##      nobody either.
##   6. **What one deed may be worth is what one blow costs.**
##   7. **Neither question carries a rule about how to answer**, and the scan that
##      says so is shown to have teeth.
##   8. **The layer rolls nothing and writes no world**, read off the source; and
##      the checked-in transcript is what the command prints.
class_name TestGoodwill

## The files that weigh an amount, which between them may not roll, compare
## against a class, or write anything in the world but one edge.
const AMOUNT := "res://sim/goodwill.gd"
const QUESTION := "res://sim/goodwill_prompt.gd"
const READING := "res://sim/deed.gd"
const WEIGHING := "res://sim/deed_desk.gd"
const WEIGHS_AN_AMOUNT := [AMOUNT, QUESTION, READING, WEIGHING]

## The one file allowed to raise a check, and the one allowed to declare how.
const RAISES := "res://sim/action_engine.gd"
const DECLARES_RAISING := "res://sim/action_scene.gd"

## How a line of code draws a die, and how it writes the world. The same shapes
## `tests/test_checks.gd` looks for, because they are the same two rules.
const DRAWS_A_DIE := [
	"hash_ints(", "hash_unit(", "next_int(", "next_u32(", "next_float(",
	"next_range(", "randi", "randf",
]
const WRITES_THE_WORLD := [
	".shut =", ".x =", ".z =", "add_object(", "remove_object(", "contents.release(",
	".health =", ".money =",
]

## Words that would be a rule about how to answer rather than a description of
## what happened. Neither question may hold one.
const A_RULE := [
	"rare", "seldom", "deliberately", "should be low", "should be small",
	"most attempts", "usually", "generous", "stingy", "less than", "more than",
	"do not give", "be sparing",
]

## A line planted in a prompt to show the scan above would notice one.
const PLANTED_RULE := "  Words are worth less than deeds, so be sparing."

## The ground the bare scenes are staged on, and where the two stand.
const WHERE := ScriptedActions.WHERE
const SEED := ScriptedActions.SEED

## What the two in the bare scene have. Written out here so the arithmetic in
## this file can be done by hand.
const SPEAKER_SCORES := {
	Ability.STR: 4, Ability.CON: 4, Ability.CHA: 12,
	Ability.DEX: 4, Ability.WIS: 4, Ability.INT: 4,
}
const LISTENER_SCORES := {
	Ability.STR: 4, Ability.CON: 4, Ability.CHA: 4,
	Ability.DEX: 4, Ability.WIS: 6, Ability.INT: 4,
}
const LISTENER_LEVEL := 3

## What is given in the deed scene, and what is asked for.
const CAP := "wool cap"
const BREAD := "barley loaf"

## The transcript checked in under reports/, and the command that prints it.
const TRANSCRIPT := "res://reports/goodwill-evidence.txt"
const COMMAND := "res://run_goodwill.sh"


func _init() -> void:
	suite_name = "goodwill"


func run() -> void:
	_one_talk_hook_and_one_situation()
	_the_class_is_the_engines()
	_a_failed_persuasion_costs_no_call()
	_the_model_judges_and_the_engine_applies()
	_a_repeat_does_not_re_roll()
	_a_repeat_in_flight_does_not_re_roll()
	_a_deed_is_read_off_the_world()
	_walking_there_names_nobody()
	_an_old_dealing_names_nobody()
	_one_deed_is_worth_one_blow()
	_neither_question_carries_a_rule()
	_the_layer_rolls_nothing_and_writes_nothing()
	_the_run_matches_what_it_predicts()
	_two_processes_agree()


# --- 1. One hook, one situation -------------------------------------------


func _one_talk_hook_and_one_situation() -> void:
	var raising := PackedStringArray()
	for path in _files_under("res://sim"):
		if path == DECLARES_RAISING:
			continue
		if _read(path).contains("raise_talk_check("):
			raising.append(path)
	equal(raising, PackedStringArray([RAISES]),
		"a talk check is raised in more than one place: %s" % " ".join(raising))
	check(AbilityCheck.TALK_HOOK.begins_with("ActionEngine."),
		"the named talk hook is not in the engine: %s" % AbilityCheck.TALK_HOOK)
	var named := AbilityCheck.TALK_HOOK.substr("ActionEngine.".length())
	check(_read(RAISES).contains("static func %s(" % named),
		"%s names a function %s does not declare" % [AbilityCheck.TALK_HOOK, RAISES])

	var world := _talkers()
	var scene: ActionScene = world["scene"]
	var speaker: Combatant = world["speaker"]
	var listener: Combatant = world["listener"]

	var shouted := ActionEngine.resolve(scene, speaker, Action.say("hello there"))
	check(shouted.ok, "a shout was refused: %s" % shouted.reason)
	equal(scene.raised.size(), 0, "a shout raised a check")

	var told := ActionEngine.resolve(scene, speaker, Action.say("well met", listener.id))
	check(told.ok, "a line to one character was refused: %s" % told.reason)
	equal(scene.raised.size(), 1, "a line to one character raised no check")
	var raised: AbilityCheck = scene.raised[0]
	equal(raised.context, "persuade:#%d" % listener.id,
		"the context of a talk check is not the person alone")
	equal(raised.sort, AbilityCheck.AT_A_PERSON, "a talk check is not at a person")
	equal(int(told.got("check", 0)), raised.id,
		"the outcome does not say which check the words raised")

	# And a second line, worded differently, is the same shape.
	ActionEngine.resolve(scene, speaker, Action.say("a fine road", listener.id))
	equal(scene.raised.size(), 2, "the second line raised no check of its own")
	equal((scene.raised[1] as AbilityCheck).context, raised.context,
		"two lines to the same person are not the same shape")


# --- 2. The class is the engine's -----------------------------------------


func _the_class_is_the_engines() -> void:
	var listener := Character.make("Listener", LISTENER_LEVEL)
	listener.record_scores(LISTENER_SCORES)
	equal(AbilityCheck.class_for_talk(listener),
		AbilityCheck.TALK_FLOOR + int(LISTENER_SCORES[Ability.WIS])
			+ maxi(listener.status(), listener.level),
		"the class is not the written formula")

	# The greater of status and level, not the sum and not either alone.
	listener.assigned_status = LISTENER_LEVEL + 4
	equal(AbilityCheck.class_for_talk(listener),
		AbilityCheck.TALK_FLOOR + int(LISTENER_SCORES[Ability.WIS]) + LISTENER_LEVEL + 4,
		"an assigned standing above the level did not decide the class")
	listener.assigned_status = 0
	equal(AbilityCheck.class_for_talk(listener),
		AbilityCheck.TALK_FLOOR + int(LISTENER_SCORES[Ability.WIS]) + LISTENER_LEVEL,
		"a standing below the level did not leave the level deciding")

	# The floor is what the criterion written beside it says it is: a speaker
	# whose charm equals the listener's wisdom, against the least standing there
	# is, succeeds on a quarter of the faces.
	var matched := Character.make("Matched", 1)
	matched.record_scores({
		Ability.STR: 1, Ability.CON: 1, Ability.CHA: 1,
		Ability.DEX: 1, Ability.WIS: 10, Ability.INT: 1,
	})
	var faces := 0
	for roll in range(1, AbilityCheck.DIE + 1):
		if AbilityCheck.beats(10, roll, AbilityCheck.bounded(
				AbilityCheck.class_for_talk(matched))):
			faces += 1
	equal(faces, AbilityCheck.DIE / 4,
		"an evenly matched attempt does not land on a quarter of the faces")

	# And the engine bounds it like any other class.
	var grand := Character.make("Grand", 20)
	grand.record_scores({
		Ability.STR: 1, Ability.CON: 1, Ability.CHA: 1,
		Ability.DEX: 1, Ability.WIS: 20, Ability.INT: 1,
	})
	check(AbilityCheck.class_for_talk(grand) > AbilityCheck.DC_HIGHEST,
		"the formula never runs past the range, so the bound proves nothing")
	equal(AbilityCheck.bounded(AbilityCheck.class_for_talk(grand)),
		AbilityCheck.DC_HIGHEST, "the engine did not bound a class of its own")


## A persuasion that fails puts no question at all: the class was not asked for
## and the resolving question is only ever written on the success branch.
func _a_failed_persuasion_costs_no_call() -> void:
	var settled := _persuasion([], _seed_where(false))
	var one: AbilityCheck = settled["check"]
	check(not one.passed, "the seed chosen for a failure passed")
	equal((settled["desk"] as CheckDesk).calls, 0,
		"a failed persuasion put a question anyway")
	equal((settled["desk"] as CheckDesk).rolls, 1, "a persuasion was not rolled for")
	equal(one.ability, AbilityCheck.TALK_ABILITY,
		"a persuasion was tested against something other than charm")
	equal(one.score, int(SPEAKER_SCORES[AbilityCheck.TALK_ABILITY]),
		"the score did not come off the speaker's own sheet")
	equal(one.total, one.score + one.roll, "the total is not the score plus the roll")
	equal(one.passed, one.total >= one.difficulty,
		"the verdict is not the total against the class")
	equal(_sentiment(settled), 0.0, "a failed persuasion moved sentiment")


# --- 3. The model judges, the engine applies ------------------------------


func _the_model_judges_and_the_engine_applies() -> void:
	var landing := _seed_where(true)

	# Prose that says it worked, with no number in it, moves nothing.
	var claimed := _persuasion(
		["They are the firmest of friends now and trust each other completely."],
		landing)
	check((claimed["check"] as AbilityCheck).passed, "the seed chosen for a pass failed")
	equal(_trust(claimed), 0.0, "prose in a reply raised trust")
	equal((claimed["desk"] as CheckDesk).favoured, 0, "prose moved an edge")

	# A number outside what the question asked for is refused, not clamped.
	var absurd := _persuasion(["goodwill=7"], landing)
	equal(_trust(absurd), 0.0, "a share outside the range moved an edge")
	equal((absurd["desk"] as CheckDesk).favoured, 0,
		"a share outside the range was taken anyway")
	var below := _persuasion(["goodwill=-0.4"], landing)
	equal(_trust(below), 0.0, "a share below the range moved an edge")

	# A share inside it is applied as a share of what one thing may be worth.
	var judged := _persuasion(["goodwill=0.25"], landing)
	equal(_trust(judged), 0.25 * Goodwill.MOST,
		"the judged share was not what the edge moved by")
	equal((judged["check"] as AbilityCheck).said_share, 0.25,
		"the record forgot what the model said")
	equal((judged["check"] as AbilityCheck).share, 0.25 * Goodwill.MOST,
		"the record forgot what the engine used")
	equal((judged["desk"] as CheckDesk).favoured, 1, "an accepted share moved no edge")

	# The largest a reply may ask for is the most one thing may be worth, and no
	# more.
	var greedy := _persuasion(["goodwill=1"], landing)
	equal((greedy["check"] as AbilityCheck).said_share, 1.0,
		"the record forgot what the model asked for")
	equal((greedy["check"] as AbilityCheck).share, Goodwill.MOST,
		"the largest share asked for is not the most one thing may be worth")
	equal(_trust(greedy), Goodwill.MOST, "the edge moved by more than the bound")

	# And bounding scales rather than clips, so two different judgements are two
	# different moves. Clipping would make these the same number.
	var half := _persuasion(["goodwill=0.5"], landing)
	var most := _persuasion(["goodwill=0.7"], landing)
	not_equal(_trust(half), _trust(most),
		"two judgements above the range the engine moves by came out the same, so"
		+ " the amount is the engine's rather than the model's")
	check(_trust(most) > _trust(half),
		"the larger judgement did not move the edge further")

	# The store refuses it too, so the bound is not only the caller's.
	var graph := RelationshipGraph.new()
	check(graph.favoured(1, 2, Goodwill.MOST + 0.1, "too much") == null,
		"the graph moved an edge by more than it accepts")
	check(graph.favoured(1, 2, -0.1, "below") == null,
		"the graph moved an edge by a share below what it accepts")
	check(graph.favoured(1, 1, Goodwill.MOST, "itself") == null,
		"the graph let somebody do itself a favour")
	check(graph.favoured(1, 2, Goodwill.MOST, "a deed") != null,
		"the graph refused a share it accepts")
	equal(graph.between(1, 2).field(2, "trust"), Goodwill.MOST,
		"the graph raised the wrong end or the wrong field")
	equal(graph.between(1, 2).field(1, "trust"), 0.0,
		"doing somebody a good turn moved the doer's own opinion")


# --- 4. A repeat does not re-roll ------------------------------------------


func _a_repeat_does_not_re_roll() -> void:
	var landing := _seed_where(true)
	var world := _talkers()
	var scene: ActionScene = world["scene"]
	var speaker: Combatant = world["speaker"]
	var listener: Combatant = world["listener"]
	var desk := CheckDesk.with_channel(_channel(["goodwill=0.3"]), landing)

	_say_and_settle(scene, speaker, listener, desk, "well met")
	equal(desk.rolls, 1, "the first attempt was not rolled for")
	equal(desk.calls, 1, "the first attempt did not put its one question")
	var after_one := _trust_between(scene, listener, speaker)
	equal(after_one, Goodwill.bounded(0.3),
		"the first attempt did not earn what was judged")

	_say_and_settle(scene, speaker, listener, desk, "and a fine road it is")
	equal(desk.seen.size(), 2, "the second attempt raised no check")
	equal(desk.rolls, 1, "the second attempt was rolled for again")
	equal(desk.calls, 1, "the second attempt cost a model call")
	equal(desk.reused, 1, "the second attempt was not settled out of memory")
	equal(_trust_between(scene, listener, speaker), after_one,
		"the second attempt earned goodwill a second time")
	equal((desk.seen[1] as AbilityCheck).how, AbilityCheck.BY_MEMORY,
		"the second attempt was not settled by memory")

	# And it is in the character's own memory, under the one context.
	var remembered := _sheet(speaker).memory
	equal(remembered.checks.size(), 1,
		"the settled persuasion is not one row of the memory's check segment")
	equal(String(remembered.checks[0]["context"]), "persuade:#%d" % listener.id,
		"the stored context is not the person")


## The same thing, but with the second attempt made while the first is still
## waiting on its answer. Without the in-flight branch this rolls twice.
func _a_repeat_in_flight_does_not_re_roll() -> void:
	var world := _talkers()
	var scene: ActionScene = world["scene"]
	var speaker: Combatant = world["speaker"]
	var listener: Combatant = world["listener"]
	var desk := CheckDesk.with_channel(_channel(["goodwill=0.3"]), _seed_where(true))

	ActionEngine.resolve(scene, speaker, Action.say("well met", listener.id))
	scene.advance(1)
	desk.step(scene)
	ActionEngine.resolve(scene, speaker, Action.say("and again", listener.id))
	var upkeep := CharacterUpkeep.new()
	for _tick in 6 * (ModelChannel.THINKS_FOR + 1):
		scene.advance(1)
		desk.step(scene)
		upkeep.fold(scene)
	equal(scene.raised.size(), 2, "the two lines did not raise two checks")
	equal(desk.rolls, 1, "an attempt made while the first was in flight rolled again")
	equal(desk.calls, 1, "an attempt made while the first was in flight cost a call")
	equal(desk.reused, 1, "the second attempt was not settled out of memory")


# --- 5. A deed is read off the world's own records -------------------------


func _a_deed_is_read_off_the_world() -> void:
	var world := _deed_world()
	var scene: ActionScene = world["scene"]
	var giver: Combatant = world["giver"]
	var wanter: Combatant = world["wanter"]
	var goal: Goal = world["goal"]

	check(goal.closed, "the goal did not close when the thing arrived")
	check(goal.open_at >= 0, "the world never stamped when it last said not yet")
	var done := Deed.done_for(goal, scene, wanter)
	equal(int(done["who"]), giver.id, "the world did not name the giver as the doer")
	check(String(done["what"]).contains("#%d" % giver.id),
		"what happened does not name who did it: %s" % done["what"])

	# And the desk turns that into one call and one moved edge.
	var desk := DeedDesk.with_channel(_channel(["goodwill=0.4"]))
	var upkeep := CharacterUpkeep.new()
	for _tick in 4 * (ModelChannel.THINKS_FOR + 1):
		scene.advance(1)
		desk.step(scene)
		upkeep.fold(scene)
	equal(desk.calls, 1, "the deed did not put exactly one question")
	equal(desk.favoured, 1, "the deed moved no edge")
	equal(desk.deeds().size(), 1, "the desk did not count one deed")
	var edge := scene.relationships.between(wanter.id, giver.id)
	# The gift itself already moved trust through the graph's own rules; what the
	# deed adds is a share of what was left after that.
	var before := RelationshipGraph.TRADE_TRUST \
		+ (1.0 - RelationshipGraph.TRADE_TRUST) * RelationshipGraph.GIFT_TRUST
	equal(edge.field(wanter.id, "trust"),
		before + (1.0 - before) * Goodwill.bounded(0.4),
		"the deed did not raise trust by the judged share of what was left")

	# Taken up once: stepping on changes nothing and costs nothing.
	desk.step(scene)
	equal(desk.calls, 1, "the same closed goal was taken up twice")


func _walking_there_names_nobody() -> void:
	var world := _talkers()
	var scene: ActionScene = world["scene"]
	var speaker: Combatant = world["speaker"]
	var goals := _sheet(speaker).goals
	var goal := goals.add(Goal.of(
		Goal.BE_AT, {"target": Vector2(speaker.x, speaker.z)}, "", Goal.SHORT))
	GoalCheck.settle(goals, scene, speaker)
	check(goal.closed, "standing where it wanted to be did not close the goal")
	var done := Deed.done_for(goal, scene, speaker)
	equal(int(done["who"]), Deed.NOBODY, "somebody was credited for a character's own walk")
	check(String(done["why"]) != "", "no reason was given for there being no doer")

	# And the eighth kind, which the character closes itself, credits nobody
	# whatever the world's records hold.
	var said := goals.add(Goal.unwritten("be thought well of here"))
	GoalCheck.close_by_hand(goals, said.id, scene.tick)
	check(said.closed, "the character could not close its own goal")
	equal(int(Deed.done_for(said, scene, speaker)["who"]), Deed.NOBODY,
		"a goal the character closed itself credited somebody")


## A dealing from before the world last said the goal was unmet is not what
## closed it. This is the window, and it is why no number of ticks is invented.
func _an_old_dealing_names_nobody() -> void:
	var world := _deed_world(true)
	var scene: ActionScene = world["scene"]
	var wanter: Combatant = world["wanter"]
	var goal: Goal = world["goal"]
	check(goal.closed, "the goal did not close when the thing was picked up")
	check(scene.trades.size() > 0, "there was no earlier dealing to mistake it for")
	var done := Deed.done_for(goal, scene, wanter)
	equal(int(done["who"]), Deed.NOBODY,
		"a dealing from before the world last said not yet was credited")


# --- 6, 7 and 8 ------------------------------------------------------------


func _one_deed_is_worth_one_blow() -> void:
	equal(Goodwill.MOST, RelationshipGraph.STRUCK_TRUST,
		"what one deed may be worth is no longer what one blow costs, so the"
		+ " reason written on Goodwill.MOST has stopped being true")
	equal(Goodwill.bounded(Goodwill.SAID_MOST), Goodwill.MOST,
		"the largest share asked for is not bounded to the largest allowed")
	equal(Goodwill.bounded(Goodwill.SAID_LEAST), Goodwill.LEAST,
		"nothing at all was not bounded to nothing at all")
	equal(Goodwill.bounded(Goodwill.SAID_MOST / 2.0), Goodwill.MOST / 2.0,
		"bounding does not keep the shape of what was judged")
	check(not bool(Goodwill.read("nothing to see")["read"]),
		"a reply with no share in it was read as one")
	check(bool(Goodwill.read("goodwill=0.5")["read"]), "a plain share was not read")


func _neither_question_carries_a_rule() -> void:
	var sheet := Character.make("Listener", LISTENER_LEVEL)
	sheet.record_scores(LISTENER_SCORES)
	var asked := [
		GoodwillPrompt.for_a_deed(
			"be carrying a wool cap", "#2 handed over 1 thing and took nothing back",
			"Wanter", "Giver", sheet),
		GoodwillPrompt.for_a_persuasion(
			"Speaker tries to win Listener round", "Listener", "Speaker", sheet),
	]
	for prompt in asked:
		for rule in A_RULE:
			check(not String(prompt).to_lower().contains(rule),
				"a question tells the model how to answer: it holds \"%s\"" % rule)
	# Both end in the one line the engine reads, and neither carries a die.
	for prompt in asked:
		check(String(prompt).contains("%s=" % Goodwill.KEY),
			"a question does not say what to answer with")
		check(not String(prompt).to_lower().contains("roll")
				and not String(prompt).to_lower().contains("d20"),
			"a question carries the die")
	# The scan has teeth.
	var planted := String(asked[0]) + "\n" + PLANTED_RULE
	var caught := false
	for rule in A_RULE:
		if planted.to_lower().contains(rule):
			caught = true
	check(caught, "the scan for a rule in a prompt would not notice one")


func _the_layer_rolls_nothing_and_writes_nothing() -> void:
	var rolling := _lines_holding(WEIGHS_AN_AMOUNT, DRAWS_A_DIE)
	equal(rolling, PackedStringArray(),
		"the layer that weighs an amount draws a die: %s" % " | ".join(rolling))
	var writing := _lines_holding(WEIGHS_AN_AMOUNT, WRITES_THE_WORLD)
	equal(writing, PackedStringArray(),
		"the layer that weighs an amount writes the world: %s" % " | ".join(writing))
	# And the scans would notice.
	check(_holds(PackedStringArray([
			"	var roll := SimRng.hash_ints(1, 2, 3)"]), DRAWS_A_DIE),
		"the die scan would not notice a die")
	check(_holds(PackedStringArray(["	thing.shut = false"]), WRITES_THE_WORLD),
		"the world scan would not notice a write")


# --- The shipped run -------------------------------------------------------


## What the run says the dice will do is what the run's own checks did, and the
## seed it ships is the one its own rule picks.
func _the_run_matches_what_it_predicts() -> void:
	equal(ScriptedGoodwill.ROLL_SEED, ScriptedGoodwill.roll_seed_for(1),
		"the shipped roll seed is not the lowest at which exactly one lands")
	var channel := _channel(["goodwill=0.2", "goodwill=0.4", "goodwill=0.4", "goodwill=0.4"])
	var talked := ScriptedGoodwill.played_with(channel, ScriptedGoodwill.TALK)
	var desk: CheckDesk = talked["desk"]
	var landed := 0
	for one in desk.seen:
		if one.how == AbilityCheck.BY_A_ROLL and one.passed:
			landed += 1
	equal(landed, ScriptedGoodwill.lands_at(ScriptedGoodwill.ROLL_SEED),
		"the run's own prediction of how many attempts land is not what landed")
	equal(desk.seen.size(), ScriptedGoodwill.LINES_EACH * ScriptedGoodwill.ATTEMPTS,
		"the talk arm did not raise one check per line spoken")
	equal(desk.rolls, ScriptedGoodwill.ATTEMPTS,
		"the talk arm rolled for more than one attempt per person")

	# And the arm that does something moves the ground further than the arm that
	# talks, which is the whole comparison.
	var did := ScriptedGoodwill.played_with(
		_channel(["goodwill=0.4", "goodwill=0.4", "goodwill=0.4"]),
		ScriptedGoodwill.DEEDS)
	var by_talking := ScriptedGoodwill.ownership_of(talked["scene"])
	var by_doing := ScriptedGoodwill.ownership_of(did["scene"])
	check(float(by_doing["here"]) > float(by_talking["here"]),
		"talking moved the ground at least as far as doing something: %.4f against %.4f"
			% [float(by_talking["here"]), float(by_doing["here"])])
	equal((did["deeds"] as DeedDesk).deeds().size(), ScriptedGoodwill.NEIGHBOURS.size(),
		"the deeds arm did not do one deed for each neighbour")
	equal((did["desk"] as CheckDesk).seen.size(), 0,
		"the deeds arm raised a check, so it is not words-free")


func _two_processes_agree() -> void:
	var checked_in := _read(TRANSCRIPT)
	check(checked_in != "", "%s is missing" % TRANSCRIPT)
	var ran := _run_goodwill()
	equal(int(ran["code"]), 0, "%s exited %d" % [COMMAND, int(ran["code"])])
	equal(String(ran["text"]).strip_edges(), checked_in.strip_edges(),
		"%s is not what %s prints" % [TRANSCRIPT, COMMAND])


# --- The furniture ---------------------------------------------------------


# Two characters standing within earshot of each other, and nothing else.
func _talkers() -> Dictionary:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var speaker := _stand(scene, "Speaker", 2, SPEAKER_SCORES, Vector2(0.0, 0.0))
	var listener := _stand(scene, "Listener", LISTENER_LEVEL, LISTENER_SCORES,
		Vector2(1.5, 0.0))
	return {"scene": scene, "speaker": speaker, "listener": listener}


func _stand(
	scene: ActionScene, called: String, level: int, scores: Dictionary, at: Vector2
) -> Combatant:
	var one := scene.add_actor(Combatant.commander_at(
		WHERE.x + at.x, WHERE.y + at.y, 0.0, 0.0, level, AssetTags.ROGUE))
	var sheet := Character.make(called, level)
	sheet.record_scores(scores)
	(one.piece as Commander).adopt(sheet)
	one.settle(scene.terrain)
	return one


# One persuasion, from the words to a settled check, answered by the replies
# given.
func _persuasion(replies: Array, roll_seed: int) -> Dictionary:
	var world := _talkers()
	var desk := CheckDesk.with_channel(_channel(replies), roll_seed)
	_say_and_settle(world["scene"], world["speaker"], world["listener"], desk, "well met")
	return {
		"scene": world["scene"], "speaker": world["speaker"],
		"listener": world["listener"], "desk": desk, "check": desk.seen[0],
	}


func _say_and_settle(
	scene: ActionScene, speaker: Combatant, listener: Combatant, desk: CheckDesk,
	words: String
) -> void:
	ActionEngine.resolve(scene, speaker, Action.say(words, listener.id))
	var upkeep := CharacterUpkeep.new()
	for _tick in 6 * (ModelChannel.THINKS_FOR + 1):
		scene.advance(1)
		desk.step(scene)
		# What a running world does every tick: the desk writes down what was
		# earned and the upkeep folds it into the graph, exactly as it folds a
		# blow. Nothing here reaches the graph any other way, because nothing in
		# the layer being tested can.
		upkeep.fold(scene)


# The lowest roll seed at which the bare scene's one attempt lands, or does not.
# Found by asking rather than assumed, so that a change to the formula moves the
# seed rather than breaking the claim.
func _seed_where(lands: bool) -> int:
	var listener := Character.make("Listener", LISTENER_LEVEL)
	listener.record_scores(LISTENER_SCORES)
	var difficulty := AbilityCheck.bounded(AbilityCheck.class_for_talk(listener))
	for roll_seed in range(1, 200):
		var roll := AbilityCheck.rolled(roll_seed, 1, "persuade:#2")
		if AbilityCheck.beats(
				int(SPEAKER_SCORES[AbilityCheck.TALK_ABILITY]), roll, difficulty) == lands:
			return roll_seed
	return -1


# A world in which one character wanted a thing and another gave it. With
# `stale` the giving happens *before* the world has ever looked at the goal and
# an unrelated dealing follows, so that what closes the goal is a pick-up off the
# ground and the earlier dealing is outside the window.
func _deed_world(stale: bool = false) -> Dictionary:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var giver := _stand(scene, "Giver", 2, SPEAKER_SCORES, Vector2(0.0, 0.0))
	var wanter := _stand(scene, "Wanter", 2, LISTENER_SCORES, Vector2(1.5, 0.0))
	var goals := _sheet(wanter).goals
	var goal := goals.add(Goal.of(Goal.HOLD, {"item": CAP}, "", Goal.SHORT))

	if not stale:
		_sheet(giver).inventory.carry(_wearable(CAP))
		GoalCheck.settle(goals, scene, wanter)
		scene.advance(1)
		_hand_over(scene, giver, wanter, CAP)
		GoalCheck.settle(goals, scene, wanter)
		return {"scene": scene, "giver": giver, "wanter": wanter, "goal": goal}

	# An unrelated dealing first, then the world looks and says not yet, and only
	# then does the wanted thing arrive out of the ground.
	_sheet(giver).inventory.carry(_wearable(BREAD))
	_hand_over(scene, giver, wanter, BREAD)
	scene.advance(1)
	GoalCheck.settle(goals, scene, wanter)
	scene.advance(1)
	_sheet(wanter).inventory.carry(_wearable(CAP))
	GoalCheck.settle(goals, scene, wanter)
	return {"scene": scene, "giver": giver, "wanter": wanter, "goal": goal}


func _hand_over(
	scene: ActionScene, giver: Combatant, taker: Combatant, what: String
) -> void:
	ActionEngine.resolve(scene, giver, Action.trade_propose(
		taker.id, PackedStringArray([what])))
	ActionEngine.resolve(scene, taker, Action.trade_accept(giver.id))
	# What a running world does on the next servicing: the trade the engine
	# honoured is folded into the graph by its own rules, so that what the deed
	# adds afterwards is a share of what those rules left.
	CharacterUpkeep.new().fold(scene)


func _sentiment(settled: Dictionary) -> float:
	var scene: ActionScene = settled["scene"]
	return scene.relationships.sentiment(
		(settled["listener"] as Combatant).id, (settled["speaker"] as Combatant).id)


func _trust(settled: Dictionary) -> float:
	return _trust_between(
		settled["scene"], settled["listener"], settled["speaker"])


func _trust_between(
	scene: ActionScene, viewer: Combatant, toward: Combatant
) -> float:
	var edge := scene.relationships.between(viewer.id, toward.id)
	return 0.0 if edge == null else edge.field(viewer.id, "trust")


# A channel that answers in order out of replies written here.
func _channel(replies: Array) -> ModelChannel:
	var rows := []
	for reply in replies:
		rows.append({"prompt": "", "reply": String(reply), "ms": 0})
	return ModelChannel.replaying(
		{"rows": rows, "from": "written in this suite", "model": "none"},
		"the suite answers its own questions")


func _wearable(called: String) -> Item:
	return Item.armour(
		called, Item.SLOT_HELMET, 1, ItemRarity.COMMON, Ability.DEX,
		[1, 1, 0] as Array[int])


func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


func _run_goodwill() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path(COMMAND), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


# Every code line of a file, comments and string literals taken off, so that
# prose about a die is not read as one.
func _code_lines(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for line in _read(path).split("\n"):
		var code: String = AssetCheck.split_code_and_strings(line)["code"].strip_edges()
		if code != "":
			found.append(code)
	return found


func _lines_holding(paths: Array, shapes: Array) -> PackedStringArray:
	var found := PackedStringArray()
	for path in paths:
		for line in _code_lines(path):
			for shape in shapes:
				if line.contains(shape):
					found.append("%s: %s" % [path, line])
					break
	return found


func _holds(lines: PackedStringArray, shapes: Array) -> bool:
	for line in lines:
		for shape in shapes:
			if line.contains(shape):
				return true
	return false


func _files_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	var listing := DirAccess.open(directory)
	if listing == null:
		return found
	for name_of in listing.get_files():
		if name_of.ends_with(".gd"):
			found.append("%s/%s" % [directory, name_of])
	found.sort()
	return found


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
