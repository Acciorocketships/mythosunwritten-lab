extends TestSuite
## Every non-player character in the run deciding through a language model,
## tested without one.
##
## Every check in this file runs with no key, no network and no model. That is
## not a compromise forced by the test environment -- it is the claim: the model
## layer is built so that a recorded exchange stands in for a live call
## everywhere except in the one command that makes the recording, and a suite
## that needed a credential would be evidence that it is not.
##
## Nine claims:
##
##   1. **One `Callable`, four minds.** A recorded plan, a rule and a model are
##      built by three factories in one file that declare the identical inner
##      signature -- read off the source, not asserted -- and all three, called
##      with the same two arguments, answer with an action or with nothing.
##   2. **Nothing downstream knows a model exists, and nothing under `sim/`
##      calls anything.** The loop, the engine and the
##      scene are read off disk with comments and string literals stripped, and
##      no line of them names a model, a prompt, a channel or a recording. The
##      same scan is then run over lines that would name one, and must catch
##      them.
##   3. **The prompt holds no rule.** A real prompt for a real character is
##      generated and searched for the five words the acceptance names --
##      distance, reach, cost, damage, possibility -- and their neighbours. The
##      search is shown to have teeth on a sentence that would be a rule.
##   4. **The model chooses and the engine answers.** An impossible choice made
##      by a model is refused by the engine with exactly the sentence the same
##      choice made by a rule is refused with -- same actor, same world, same
##      words.
##   5. **The simulation never blocks, and several answers do not serialise.**
##      Across every wait in the shipped run the other five characters were
##      serviced for exactly as many ticks as the wait lasted and went on
##      resolving actions, while the waiting character resolved none. And the
##      length of a wait does not grow with how many other answers are
##      outstanding at the same time: the run has ticks with more than one
##      pending, and every span is the stated one. Measured off the loop's own
##      counters and a per-tick sample of who was waiting.
##   6. **The whole atomic action set can be chosen and nothing else can.** Every
##      one of the twelve reads back from a model's line into the action it
##      names, and a line naming something that is not an action reads back as no
##      choice at all.
##   7. **Two processes agree**, the checked-in transcript is what the command
##      prints, and the run names for each turn what was observed, what was
##      chosen and what the engine answered.
##   8. **The whole non-player cast decides through a model.** Every character in
##      the shipped run except the one driven by a person's written-down choices
##      has a `ModelMind` on its own sheet, reached through the same
##      `DecisionSource.model` `Callable`; and the human-driven one is handed the
##      same twelve actions and the same observation packet, so nothing an agent
##      has is anything a person does not.
##   9. **The run says what it cost.** Model calls per character and in total, the
##      rate that comes to, what an hour of play would be at the same rate, and
##      the ratio of mid-action re-evaluations to model calls -- all printed by
##      the command rather than worked out by hand afterwards.
class_name TestAgent

## The file the decision functions live in, and the five it declares.
const DECISION_SOURCE := "res://sim/decision_source.gd"
const FACTORIES := ["recorded", "plan", "scripted", "model", "deliberate"]

## The one signature all five inner functions are declared with, once parameter
## names that only differ by a leading underscore are made the same.
const ONE_SIGNATURE := "return func(scene: ActionScene, actor: Combatant) -> Action:"

## The files that drive characters and resolve what they choose. None of them may
## name the model layer.
const DOWNSTREAM := [
	"res://sim/control_loop.gd",
	"res://sim/action_engine.gd",
	"res://sim/action_scene.gd",
	"res://sim/action.gd",
	"res://sim/action_catalog.gd",
	"res://sim/character.gd",
]

## How a line of code under `sim/` would reach for the outside world: a
## connection, a thread, the environment, a clock. Whole words. The simulation
## counts ticks and calls nothing; the transport that does both lives in `net/`
## and reaches the channel as a `Callable`.
const REACHES_OUT := (
	"HTTPClient|HTTPRequest|TLSOptions|StreamPeer|StreamPeerTCP|StreamPeerTLS"
	+ "|PacketPeer|Thread|Mutex|Semaphore|OS|Time|Engine"
)

## How a line of code would name the model layer. Whole words.
const NAMES_A_MODEL := (
	"model|llm|prompt|oracle|mind|channel|recording|replay|exchange"
	+ "|openrouter|anthropic|http|token|api_key|observation"
)

## Lines the scan must catch, and lines it must not.
const BROKEN_MODEL_CONTROL := "	if sheet.decide == DecisionSource.model:"
const BROKEN_MODEL_WAIT := "	if mind.is_waiting():"
const HONEST_CONTROL := "	var chosen: Variant = sheet.decide.call(scene, one)"

## A sentence that would be a rule if it were in the prompt.
const BROKEN_PROMPT := "You cannot attack a target outside your weapon's reach."

## The transcript checked in under reports/, and the command that prints it.
const TRANSCRIPT := "res://reports/agent-evidence.txt"
const COMMAND := "res://run_agent.sh"

## A jump nobody's dexterity reaches, used to make a model choose something the
## world will refuse.
const TOO_FAR := Vector2(400.0, 400.0)

## Where the two characters in the bare scene stand.
const ROOK_AT := Vector2(0.0, 0.0)
const WREN_AT := Vector2(2.0, 0.0)
const ROOK_DEX := 4

## Twelve replies, one per action, and what each must read back as. This is the
## claim "a model chooses from exactly the atomic action set" written out: if the
## catalogue grows a row, the table below stops covering it and the check fails.
const REPLIES := [
	["go_to target=#3", "go_to(target=3)"],
	["go_to target=(1.5, -2.5)", "go_to(target=(1.500, -2.500))"],
	["jump target=(3.0, 4.0)", "jump(target=(3.000, 4.000))"],
	["attack target=#2 item=common sword", "attack(target=2 item=common sword)"],
	["say text=good morning to you target=#2", "say(text=good morning to you target=2)"],
	["say text=hoy", "say(text=hoy)"],
	[
		"trade_propose target=#2 give=[silk cloak] give_money=3 want=[brass lantern] want_money=0",
		"trade_propose(target=2 give=[silk cloak] give_money=3 want=[brass lantern] want_money=0)",
	],
	["trade_accept target=#2", "trade_accept(target=2)"],
	["trade_deny target=#2", "trade_deny(target=2)"],
	["pick_up item=brass lantern target=#4", "pick_up(item=brass lantern target=4)"],
	["drop item=lockpick", "drop(item=lockpick)"],
	["examine target=silk cloak", "examine(target=silk cloak)"],
	["interact target=#5 item=lockpick", "interact(target=5 item=lockpick)"],
	["wait ticks=6", "wait(ticks=6)"],
]


func _init() -> void:
	suite_name = "agent"


func run() -> void:
	_one_callable_four_minds()
	_nothing_downstream_names_a_model()
	_nothing_under_sim_calls_anything()
	_the_model_scan_would_notice()
	_the_prompt_holds_no_rule()
	_the_rule_scan_would_notice()
	_the_model_chooses_and_the_engine_answers()
	_the_simulation_never_blocks()
	_every_action_can_be_chosen_by_a_model()
	_the_run_names_what_it_saw_chose_and_was_told()
	_the_whole_cast_decides_through_a_model()
	_the_run_says_what_it_cost()
	_two_processes_agree()


# --- 1. One Callable, four minds ------------------------------------------


## The three decision functions a character can be given are one shape, shown by
## reading the file that declares them.
func _one_callable_four_minds() -> void:
	var text := _read(DECISION_SOURCE)
	check(text != "", "the scan opened %s" % DECISION_SOURCE)
	var declared := PackedStringArray()
	var inner := PackedStringArray()
	for line in text.split("\n"):
		var code: String = AssetCheck.split_code_and_strings(line)["code"].strip_edges()
		for factory in FACTORIES:
			if code.begins_with("static func %s(" % factory):
				declared.append(factory)
		if code.begins_with("return func("):
			inner.append(code.replace("_scene", "scene").replace("_actor", "actor"))
	equal(declared, PackedStringArray(FACTORIES),
		"the five decision functions are declared in one file, in one order")
	equal(inner.size(), FACTORIES.size(),
		"every one of them returns a function")
	for line in inner:
		equal(line, ONE_SIGNATURE,
			"a decision function is declared with a signature of its own: %s" % line)

	# And they behave as one shape: the same two arguments in, an action or
	# nothing out, from each of the three a character can actually be given.
	var scene := _bare_scene()
	var actor: Combatant = scene.actors[0]
	var minds := {
		"a person": DecisionSource.plan([Action.wait(3)]),
		"a rule": DecisionSource.scripted(func(_s: ActionScene, _a: Combatant) -> Action:
			return Action.wait(3)),
		"a model": DecisionSource.model(_mind_saying("wait ticks=3")),
	}
	for who in minds:
		var decide: Callable = minds[who]
		equal(decide.get_argument_count(), 2,
			"%s's decision function takes two arguments" % who)
		var answer: Variant = decide.call(scene, actor)
		check(answer == null or answer is Action,
			"%s's decision function answered with something that is not an action" % who)

	# The model's is null on the tick it is asked -- the call is outstanding --
	# and the action it chose once the answer has come back.
	var waiting: Callable = minds["a model"]
	equal(waiting.call(scene, actor), null,
		"a model that has not answered yet chooses nothing")
	scene.advance(ModelChannel.THINKS_FOR)
	var chosen: Variant = waiting.call(scene, actor)
	check(chosen is Action and (chosen as Action).line() == "wait(ticks=3)",
		"and the action it chose once the answer arrived")


# --- 2. Nothing downstream names a model ----------------------------------


## The loop, the engine and the scene are read off disk, and no line of them
## names the model layer.
func _nothing_downstream_names_a_model() -> void:
	var naming := PackedStringArray()
	var read := 0
	for path in DOWNSTREAM:
		var text := _read(path)
		check(text != "", "the scan opened %s" % path)
		read += 1
		var lines := text.split("\n")
		for index in lines.size():
			if _names_a_model(lines[index]):
				naming.append("%s:%d  %s" % [path, index + 1, lines[index].strip_edges()])
	equal(read, DOWNSTREAM.size(), "the scan opened every file that drives or resolves")
	equal(naming, PackedStringArray(),
		"a line of the loop or the engine names the model layer")

	# The other half: what the loop calls is a Callable off the sheet, and a
	# Callable is a Callable.
	var loop := _code_of("res://sim/control_loop.gd")
	check(loop.contains("var chosen: Variant = sheet.decide.call(scene, one)"),
		"the loop calls whatever is on the sheet and asks nothing about it")


## No file under `sim/` opens a connection, starts a thread, reads the
## environment or reads a clock.
##
## The clock half of this is already a standing rule, checked over every file
## under `sim/` by `tests/test_control_loop.gd`. This is the other half, and the
## model layer is the first thing in the project that had to be built around it:
## a language model answers in seconds and over a socket, and both of those live
## in `net/model_call.gd`, outside the simulation, reaching `ModelChannel` as a
## `Callable` that is asked and polled.
func _nothing_under_sim_calls_anything() -> void:
	var reaching := PackedStringArray()
	var read := 0
	for path in _files_under("res://sim"):
		var text := _read(path)
		if text == "":
			continue
		read += 1
		var lines := text.split("\n")
		for index in lines.size():
			var hit := _reaches_out(lines[index])
			if hit != "":
				reaching.append("%s:%d reaches for %s" % [path, index + 1, hit])
	check(read > 40, "the scan opened %d files under sim/" % read)
	equal(reaching, PackedStringArray(),
		"a file under sim/ opens a connection, starts a thread or reads a clock")

	# The scan has teeth, and the file that really does all of it is outside sim/.
	check(_reaches_out("	var http := HTTPClient.new()") != "",
		"the scan does not catch a connection being opened")
	check(_reaches_out("	var worker := Thread.new()") != "",
		"the scan does not catch a thread being made")
	check(_reaches_out("	var began := Time.get_ticks_msec()") != "",
		"the scan does not catch a clock being read")
	equal(_reaches_out("	var chosen := sheet.decide.call(scene, one)"), "",
		"the scan fires on a line that reaches for nothing")
	check(_read("res://net/model_call.gd").contains("HTTPClient.new()"),
		"the transport that does open a connection is not where it is said to be")


## The scan has teeth.
func _the_model_scan_would_notice() -> void:
	check(_names_a_model(BROKEN_MODEL_CONTROL),
		"the scan does not catch a line branching on a model decision function")
	check(_names_a_model(BROKEN_MODEL_WAIT),
		"the scan does not catch a line asking a mind whether it is waiting")
	check(_names_a_model("	var reply := channel.reply_to(ticket, tick)"),
		"the scan does not catch a line reading a channel")
	check(not _names_a_model(HONEST_CONTROL),
		"the scan fires on the line the loop really has")
	check(not _names_a_model("	## a person, a rule or a language model may be on the sheet"),
		"the scan fires on a comment saying the words")
	check(not _names_a_model("	var remodelled := 1"),
		"the scan fires on a word that merely contains one it looks for")


# --- 3. The prompt holds no rule ------------------------------------------


## A real prompt for a real character carries the menu and the observation, and
## no rule about what any of it costs or whether it would work.
func _the_prompt_holds_no_rule() -> void:
	var scene := _bare_scene()
	var actor: Combatant = scene.actors[0]
	var seen := Observation.of(scene, actor)
	var prompt := ModelPrompt.written_for(seen)
	check(prompt.length() > 400, "the prompt is a real one: %d characters" % prompt.length())

	var hits := _rule_words_in(prompt)
	equal(hits, PackedStringArray(),
		"the prompt names a rule: %s" % " ".join(hits))

	# What it does hold: the twelve verbs of the one list, and the packet.
	for action_name in ActionCatalog.names():
		check(prompt.contains(action_name),
			"the prompt does not offer %s" % action_name)
	check(prompt.contains(seen.text()),
		"the prompt does not carry the observation packet itself")

	# The window of ground goes over with its key. A grid of punctuation nobody
	# has been told how to read is what the first run of this was handed, and it
	# never chose a position on it.
	check(prompt.contains(Observation.legend_line()),
		"the prompt carries the window of ground with no legend")
	for key in Observation.GLYPHS:
		check(prompt.contains("%s %s" % [
				Observation.GLYPHS[key], Observation.MEANS[key]]),
			"the prompt does not say what '%s' means" % Observation.GLYPHS[key])
	# And the legend is a key to a picture, not a rule: the same scan that is run
	# over the whole prompt is run over the legend on its own, so a meaning that
	# grew into a rule would fail here and name itself.
	var in_legend := _rule_words_in(Observation.legend_line())
	equal(in_legend, PackedStringArray(),
		"the legend states a rule: %s" % " ".join(in_legend))

	# And what was said goes over as well, filtered by the engine's own answer.
	# The prompt is the packet, so a line the character heard is in it verbatim.
	ActionEngine.resolve(scene, scene.actors[1],
		Action.say("a word in your ear", actor.id))
	var after := ModelPrompt.written_for(Observation.of(scene, actor))
	check(after.contains("a word in your ear"),
		"the prompt does not carry the speech the character heard")
	check(after.contains("said to you"),
		"and does not say that it was said to this character")
	equal(_rule_words_in(after), PackedStringArray(),
		"carrying speech put a rule in the prompt")
	equal(ModelPrompt.menu_lines().size(), ActionCatalog.ROWS.size(),
		"the menu has one line per row of the one list")

	# And it names no outcome this character was not given. The prompt now carries
	# what a character is after -- that is the goal layer, and `tests/test_goals.gd`
	# is where the block itself is checked. What must stay true here is that a
	# character nobody has set anything for is told nothing to want: the whole of
	# its goals block is the one line that says so.
	equal(ModelPrompt.goal_block_of(prompt), ModelPrompt.WANTS_NOTHING,
		"a character after nothing is told something to want")
	for word in ["quest", "should", "must", "try to", "your task", "reward"]:
		check(not prompt.to_lower().contains(word),
			"the prompt names an intended outcome: it contains '%s'" % word)
	# The word "goal" appears exactly once, as the key of the tool a character
	# closes one of its own with -- never as something it is told to have.
	equal(prompt.to_lower().count("goal"), 1,
		"the word goal appears in the prompt of a character that is after nothing")


func _the_rule_scan_would_notice() -> void:
	var caught := _rule_words_in(BROKEN_PROMPT)
	check(caught.size() >= 1,
		"the rule scan does not catch a sentence that is plainly a rule")
	check(_rule_words_in("Choose the one thing your character does next.").is_empty(),
		"the rule scan fires on a sentence that states no rule")


# --- 4. The model chooses and the engine answers --------------------------


## The same impossible choice, made by a model and by a rule, is refused in the
## same words by the same engine.
func _the_model_chooses_and_the_engine_answers() -> void:
	var scene := _bare_scene()
	var actor: Combatant = scene.actors[0]

	var by_model := DecisionSource.model(
		_mind_saying("jump target=(%.1f, %.1f)" % [TOO_FAR.x, TOO_FAR.y]))
	by_model.call(scene, actor)
	scene.advance(ModelChannel.THINKS_FOR)
	var chosen: Action = by_model.call(scene, actor)
	check(chosen != null, "the model chose nothing at all")
	if chosen == null:
		return

	var by_rule := DecisionSource.scripted(func(_s: ActionScene, _a: Combatant) -> Action:
		return Action.jump(TOO_FAR))
	var same: Action = by_rule.call(scene, actor)
	equal(chosen.line(), same.line(),
		"the two decision functions did not name the same choice")

	var refused_model := ActionEngine.resolve(scene, actor, chosen)
	var refused_rule := ActionEngine.resolve(scene, actor, same)
	check(not refused_model.ok, "the engine allowed an impossible jump")
	equal(refused_model.ok, refused_rule.ok,
		"the engine answered a model and a rule differently")
	equal(refused_model.reason, refused_rule.reason,
		"the engine gave a model a different reason than it gave a rule")
	check(refused_model.reason.contains("further than DEX"),
		"the refusal is the engine's own sentence: %s" % refused_model.reason)

	# And an action the world does allow goes through from a model exactly as it
	# would from anybody: the world changes.
	var speaking := DecisionSource.model(_mind_saying("say text=good morning"))
	speaking.call(scene, actor)
	scene.advance(ModelChannel.THINKS_FOR)
	var spoke: Action = speaking.call(scene, actor)
	var before := scene.said.size()
	var went := ActionEngine.resolve(scene, actor, spoke)
	check(went.ok, "the engine refused a plain shout from a model: %s" % went.reason)
	equal(scene.said.size(), before + 1, "and the world heard it")


# --- 5. The simulation never blocks ---------------------------------------


## Across every wait in the shipped run, everybody else went on being serviced --
## and a wait did not get longer because other answers were outstanding with it.
func _the_simulation_never_blocks() -> void:
	var played := ScriptedAgent.played_with(_shipped_channel())
	var cast: ModelCast = played["cast"]
	var serviced: Array[Dictionary] = played["serviced"]
	var pending: Array[Dictionary] = played["pending"]
	var rows := cast.turns()
	check(rows.size() >= 3,
		"the run gave the cast too few turns to measure: %d" % rows.size())

	var waits := 0
	var alongside := 0
	for turn in rows:
		var who := String(turn["who"])
		var answered := int(turn["tick"])
		var asked := answered - int(turn["waited"])
		check(int(turn["waited"]) >= ModelChannel.THINKS_FOR,
			"a turn was answered sooner than the stated span: %d" % int(turn["waited"]))
		waits += 1
		var moved := 0
		var carried_on := 0
		for other in _others_than(serviced, who):
			if not _present(serviced, other, asked) \
					or not _present(serviced, other, answered):
				continue
			var ticks := _gap(serviced, other, "ticks", asked, answered)
			equal(ticks, answered - asked,
				"%s was serviced for %d ticks across a wait of %d" % [
					other, ticks, answered - asked,
				])
			carried_on += 1
			moved += _gap(serviced, other, "actions", asked, answered)
		check(carried_on >= 4,
			"only %d other characters were still in the world across a wait" % carried_on)
		equal(_gap(serviced, who, "actions", asked, answered), 0,
			"the waiting character resolved an action while it was still waiting")
		check(moved >= 0, "the others resolved %d actions across the wait" % moved)
		if _pending_besides(pending, who, asked, answered) > 0:
			alongside += 1
	check(waits >= 3, "too few waits to measure: %d" % waits)

	# Somebody else got something done across the run's waits, or the claim is
	# about a world in which nothing was happening anyway.
	var busy := 0
	for turn in rows:
		var answered := int(turn["tick"])
		var asked := answered - int(turn["waited"])
		for other in _others_than(serviced, String(turn["who"])):
			busy += _gap(serviced, other, "actions", asked, answered)
	check(busy > 0,
		"nobody else resolved anything across any of the waits, so the measurement says nothing")

	# And the run really did have more than one answer outstanding at a time. A
	# run in which the questions never overlapped could not tell a concurrent
	# layer from a queue, so the overlap is checked rather than assumed.
	var overlapping := 0
	var most := 0
	for row in pending:
		var many := (row["waiting"] as PackedStringArray).size()
		most = maxi(most, many)
		if many > 1:
			overlapping += 1
	check(overlapping > 0,
		"no tick of the run had more than one answer outstanding, so nothing was measured")
	check(most >= 3,
		"the most answers outstanding at once was %d, too few to say they do not queue" % most)
	check(alongside > 0,
		"no wait overlapped another, so the spans say nothing about serialising")

	# The one that would break if the channel served the questions in turn: a span
	# does not grow with how many other answers are outstanding across it. A queue
	# would make a question put while k others were pending take about (k+1) times
	# the stated span; here every span is under twice it, whatever k was.
	#
	# A span longer than the stated one at all is a character that was not
	# serviced on the tick its answer was ready -- a commander waiting for its
	# turn on the board -- so the bound is on the loop's cadence and not on the
	# channel's.
	var longest := {}
	for turn in rows:
		var answered := int(turn["tick"])
		var waited := int(turn["waited"])
		var others := _pending_besides(
			pending, String(turn["who"]), answered - waited, answered)
		check(waited < 2 * ModelChannel.THINKS_FOR,
			"a wait with %d other answers outstanding took %d ticks, twice the stated %d" % [
				others, waited, ModelChannel.THINKS_FOR,
			])
		longest[others] = maxi(int(longest.get(others, 0)), waited)
	check(longest.has(0), "no question was put with nothing else outstanding")
	var alone := int(longest[0])
	for others in longest:
		check(int(longest[others]) - alone < ModelChannel.THINKS_FOR,
			"the longest wait with %d others outstanding was %d ticks against %d with none"
				% [others, int(longest[others]), alone])


# --- 6. The whole action set, and nothing else ----------------------------


## Every one of the twelve can be named by a model and read back as itself.
func _every_action_can_be_chosen_by_a_model() -> void:
	var covered := {}
	for row in REPLIES:
		var chosen := ModelPrompt.action_of(String(row[0]))
		check(chosen != null, "a model's line read back as no action: %s" % row[0])
		if chosen == null:
			continue
		equal(chosen.line(), String(row[1]), "a model's line read back as the wrong action")
		equal(ActionCatalog.fault(chosen), "",
			"a model's line read back as an action the catalogue refuses: %s" % row[0])
		covered[chosen.kind] = true
	equal(covered.size(), ActionCatalog.ROWS.size(),
		"a row of the one list has no reply exercising it")

	# A line naming something that is not an action is no choice at all, and a
	# decision function with no choice is a character that waits.
	equal(ModelPrompt.action_of("fly target=#2"), null,
		"a model naming something that is not an action chose something")
	equal(ModelPrompt.action_of("I think I shall wander north for a while."), null,
		"a model that only talked chose something")

	# A choice with a parameter of the wrong sort is not fixed up here: it
	# reaches the catalogue and is refused there, in the catalogue's words.
	var wrong := ModelPrompt.action_of("jump target=#3")
	check(wrong != null, "a wrongly-typed parameter lost the action altogether")
	if wrong != null:
		equal(ActionCatalog.fault(wrong), "jump's target must be a position",
			"the catalogue refuses a wrongly-typed parameter in its own words")

	# What a model says around its choice is ignored rather than refused.
	var padded := ModelPrompt.action_of(
		"Looking around, the lantern seems worth having.\ngo_to target=#3")
	check(padded != null and padded.line() == "go_to(target=3)",
		"a choice with a sentence in front of it was lost")

	# And an answer with nothing in it at all -- a provider that declined the
	# question -- is a question that has been answered, not one still outstanding.
	# The turn is recorded with the reason on it and the character is asked again;
	# a mind that could not tell the two apart would wait on that ticket for the
	# rest of the run.
	var declined := ModelMind.with_channel(ModelChannel.replaying(
		{
			"rows": [
				{"prompt": "", "reply": "", "ms": 0},
				{"prompt": "", "reply": "wait ticks=2", "ms": 0},
			],
			"from": "written down by the suite", "model": "none",
		},
		"written down by the suite"))
	var scene := _bare_scene()
	var actor := scene.actors[0]
	declined.answer_for(scene, actor)
	scene.advance(ModelChannel.THINKS_FOR)
	equal(declined.answer_for(scene, actor), null,
		"an answer with nothing in it was read as a choice")
	equal(declined.turns.size(), 1,
		"a declined answer was not recorded as a turn")
	check(not declined.is_waiting(),
		"a declined answer left the character waiting on a ticket nothing will answer")
	declined.answer_for(scene, actor)
	scene.advance(ModelChannel.THINKS_FOR)
	var after: Action = declined.answer_for(scene, actor)
	check(after != null and after.line() == "wait(ticks=2)",
		"the question was not put again after an answer with nothing in it")


# --- 7. The run, the transcript, and two processes ------------------------


## The transcript names, for every turn, what was observed, what was chosen and
## what the engine answered.
func _the_run_names_what_it_saw_chose_and_was_told() -> void:
	var printed := ScriptedAgent.play(_shipped_channel())
	var text := "\n".join(printed)
	var played := ScriptedAgent.played_with(_shipped_channel())
	var cast: ModelCast = played["cast"]

	check(text.contains("driven by a model"),
		"the cast table does not say which character a model drives")
	check(text.contains("the model cast's turns"),
		"the transcript has no turn table")
	check(text.contains("nobody waits on anybody"),
		"the transcript has no waiting table")
	check(text.contains("what the first run of this file measured, measured again"),
		"the transcript does not re-measure what the first run measured")
	for measured in [
		"lines of speech chosen", "the most-repeated line",
		"turns that chose a position",
	]:
		check(text.contains(measured),
			"the transcript does not report '%s'" % measured)
	for turn in cast.turns():
		check(text.contains(String(turn["observed"])),
			"the transcript does not name what was observed on one turn")
		var chose: Action = turn["chose"]
		if chose != null:
			check(text.contains(chose.line()),
				"the transcript does not name what was chosen on one turn")

	# The engine's answer to every turn is in it, in the engine's words: every
	# action a model character had resolved appears as a finished line, and every
	# one of the five had at least one.
	var loop: ControlLoop = played["loop"]
	for who in cast.order:
		var finished := 0
		for line in loop.journal:
			if line.contains(who) and line.contains("finished "):
				finished += 1
		check(finished >= 1,
			"%s never had an action resolved, so there is nothing to answer" % who)

	# And nothing was needed to produce it: the shipped run replays, whatever the
	# environment holds.
	equal(ModelChannel.for_run(ModelRecording.exchange()).kind, ModelChannel.REPLAY,
		"the shipped run does not replay when it is handed no way to call a model")
	check(ModelRecording.size() > 0,
		"the recording is empty, so the shipped run has nothing to replay")
	equal(cast.waiting_notes(), PackedStringArray(),
		"the run ran out of recorded replies: %s" % " | ".join(cast.waiting_notes()))


## The documented command run twice, in two processes, printing the same bytes --
## and the transcript checked in under reports/ being those bytes.
func _two_processes_agree() -> void:
	var first := _run_agent()
	var second := _run_agent()
	equal(first["code"], 0, "./run_agent.sh exits 0")
	equal(second["code"], 0, "and again")
	equal(first["text"], second["text"],
		"two runs of ./run_agent.sh printed different bytes")

	var kept := FileAccess.get_file_as_string(TRANSCRIPT)
	check(kept != "", "the transcript is checked in at %s" % TRANSCRIPT)
	equal(kept.strip_edges(), String(first["text"]).strip_edges(),
		"the checked-in transcript is not what the command prints")


# --- 8. The whole non-player cast decides through a model ------------------


## Every character in the shipped run but one decides through a model, and the
## one that does not is handed exactly what the others are.
##
## The first half is a count off the staged scene rather than a list read back:
## the scene holds N characters, the cast holds N-1 minds, and the one name left
## over is the human-driven one. The second half is the no-privileges claim, done
## the only way it can be done -- by building the same things for the person that
## a model is built for and finding them the same.
func _the_whole_cast_decides_through_a_model() -> void:
	var played := ScriptedAgent.played_with(_shipped_channel())
	var scene: ActionScene = played["scene"]
	var cast: ModelCast = played["cast"]

	var everybody := PackedStringArray()
	for one in scene.actors:
		var sheet := _sheet_of(one)
		if sheet != null:
			everybody.append(sheet.character_name)
	check(everybody.size() >= 6,
		"the run staged %d characters, too few to make the claim" % everybody.size())
	equal(cast.order.size(), everybody.size() - 1,
		"%d of %d characters decide through a model" % [
			cast.order.size(), everybody.size(),
		])
	for who in everybody:
		check(cast.drives(who) or who == ScriptedAgent.PERSON,
			"%s decides through neither a model nor a person's written-down choices" % who)
	check(not cast.drives(ScriptedAgent.PERSON),
		"the human-driven character was given a model mind")

	# Every one of them was actually asked something, so "decides through a
	# model" is what happened and not what was arranged.
	for who in cast.order:
		check(cast.mind_of(who).opened > 0,
			"%s was given a model mind and never put a question to it" % who)
		check(cast.mind_of(who).turns.size() > 0,
			"%s put questions and never got an answer it could read" % who)

	# And the person is handed what the models are handed: the same twelve
	# actions, and an observation packet of the same shape built by the same call.
	var person := _named(scene, ScriptedAgent.PERSON)
	var agent := _named(scene, cast.order[0])
	check(person != null and agent != null, "the run is missing one of the two")
	if person == null or agent == null:
		return
	var theirs := Observation.of(scene, person, null)
	var its := Observation.of(scene, agent, null)
	equal(theirs.digest().length(), its.digest().length(),
		"the two observations are not the same sort of thing")
	var for_them := ModelPrompt.written_for(theirs, null, {}, null)
	var for_it := ModelPrompt.written_for(its, null, {}, null)
	for row in ActionCatalog.ROWS:
		var named := String(row["name"])
		check(for_them.contains(named),
			"the human-driven character is not offered %s" % named)
		check(for_it.contains(named),
			"a model-driven character is not offered %s" % named)


# --- 9. The run says what it cost -----------------------------------------


## The volume and the bias are printed as numbers by the command itself.
func _the_run_says_what_it_cost() -> void:
	var played := ScriptedAgent.played_with(_shipped_channel())
	var cast: ModelCast = played["cast"]
	var scene: ActionScene = played["scene"]
	var loop: ControlLoop = played["loop"]

	# Every ask of a mind is exactly one of three things, and the three sum.
	for who in cast.order:
		var mind := cast.mind_of(who)
		equal(mind.consulted, mind.opened + mind.held + mind.polled,
			"%s was asked %d times, which is not %d calls + %d held + %d polled" % [
				who, mind.consulted, mind.opened, mind.held, mind.polled,
			])
		check(mind.consulted > mind.opened,
			"%s put a question every time it was asked, so nothing was saved" % who)

	var volume := "\n".join(ScriptedAgent.volume_lines(cast, scene, loop))
	check(volume.contains("%d calls" % cast.calls()),
		"the volume table does not print the run's call count")
	check(volume.contains("an hour of play"),
		"the volume table does not carry the rate out to an hour of play")
	check(volume.contains("%d ticks an hour" % ModelCast.TICKS_AN_HOUR),
		"the volume table does not say how many ticks an hour is")
	for who in cast.order:
		check(volume.contains(who),
			"the volume table has no row for %s" % who)

	var bias := "\n".join(ScriptedAgent.bias_lines(cast, loop))
	check(bias.contains("re-evaluations to model calls"),
		"the bias table does not print the ratio the milestone asks for")
	check(bias.contains("asks that cost a call"),
		"the bias table does not say what share of asks cost a call")
	check(cast.consulted() > cast.calls(),
		"the cast put a question every time it was asked: %d asks, %d calls" % [
			cast.consulted(), cast.calls(),
		])

	# Both tables are in what the command prints, not only reachable from a test.
	var text := "\n".join(ScriptedAgent.play(_shipped_channel()))
	check(text.contains("what the run cost in model calls"),
		"the transcript has no volume table")
	check(text.contains("being asked again is not a new call"),
		"the transcript has no bias table")


# --- The furniture --------------------------------------------------------


# The channel a shipped run uses: the recording, and no way to call anything.
func _shipped_channel() -> ModelChannel:
	return ModelChannel.for_run(ModelRecording.exchange())


# A mind whose channel answers every question with one stated line. The whole of
# what a test needs to stand in for a model, and it exercises the same
# `ModelChannel` the shipped run uses -- a replay of a written-down exchange.
func _mind_saying(reply: String) -> ModelMind:
	var rows := []
	for _at in 8:
		rows.append({"prompt": "", "reply": reply, "ms": 0})
	return ModelMind.with_channel(ModelChannel.replaying(
		{"rows": rows, "from": "written down by the suite", "model": "none"},
		"written down by the suite"))


# Which outside-the-world thing a line reaches for, or "".
func _reaches_out(line: String) -> String:
	var code: String = AssetCheck.split_code_and_strings(line)["code"]
	var finder := RegEx.new()
	finder.compile("\\b(%s)\\b" % REACHES_OUT)
	var hit := finder.search(code)
	return "" if hit == null else hit.get_string()


# Every script under a directory, in name order.
func _files_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			found.append("%s/%s" % [directory, name])
	found.sort()
	return found


func _names_a_model(line: String) -> bool:
	var code: String = AssetCheck.split_code_and_strings(line)["code"]
	var finder := RegEx.new()
	finder.compile("\\b(%s)\\b" % NAMES_A_MODEL)
	return finder.search(code) != null


func _rule_words_in(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	var finder := RegEx.new()
	finder.compile("(?i)\\b(%s)\\b" % ModelPrompt.RULE_WORDS)
	for hit in finder.search_all(text):
		if not found.has(hit.get_string()):
			found.append(hit.get_string())
	return found


static func _others_than(
	serviced: Array[Dictionary], than: String
) -> PackedStringArray:
	var found := PackedStringArray()
	for row in serviced:
		for who in row["ticks"]:
			if who != than and not found.has(who):
				found.append(who)
	return found


# How many characters other than one had a question outstanding at some point
# inside a span. Read off the per-tick sample the run takes.
static func _pending_besides(
	pending: Array[Dictionary], who: String, from_tick: int, to_tick: int
) -> int:
	var found := {}
	for row in pending:
		var at := int(row["tick"])
		if at < from_tick or at > to_tick:
			continue
		for other in (row["waiting"] as PackedStringArray):
			if other != who:
				found[other] = true
	return found.size()


# Whether a character was still in the world at a tick: the run records a count
# for everybody it serviced, and nobody else.
static func _present(serviced: Array[Dictionary], who: String, at_tick: int) -> bool:
	for row in serviced:
		if int(row["tick"]) == at_tick:
			return row["ticks"].has(who)
	return false


static func _gap(
	serviced: Array[Dictionary], who: String, what: String, from_tick: int, to_tick: int
) -> int:
	return _at(serviced, who, what, to_tick) - _at(serviced, who, what, from_tick)


static func _at(
	serviced: Array[Dictionary], who: String, what: String, at_tick: int
) -> int:
	var found := 0
	for row in serviced:
		if int(row["tick"]) > at_tick:
			break
		found = int(row[what].get(who, found))
	return found


# Two characters standing on the measured meadow the other walkthroughs use.
#
# Real ground rather than a bare stage, because an observation is read off the
# tactical lattice and a lattice is built out of terrain: a scene with no ground
# under it has nothing for a character to look at.
func _bare_scene() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(ScriptedScenario.SEED))
	var rook := scene.add_actor(Combatant.commander_at(
		ScriptedScenario.WHERE.x + ROOK_AT.x, ScriptedScenario.WHERE.y + ROOK_AT.y,
		0.0, 0.0, 3, AssetTags.KNIGHT))
	var rook_sheet := Character.make("Rook", 3)
	rook_sheet.record_scores({Ability.DEX: ROOK_DEX})
	(rook.piece as Commander).adopt(rook_sheet)
	rook.settle(scene.terrain)
	var wren := scene.add_actor(Combatant.commander_at(
		ScriptedScenario.WHERE.x + WREN_AT.x, ScriptedScenario.WHERE.y + WREN_AT.y,
		0.0, 0.0, 2, AssetTags.MAGE))
	(wren.piece as Commander).adopt(Character.make("Wren", 2))
	wren.settle(scene.terrain)
	return scene


func _run_agent() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path(COMMAND), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in _read(path).split("\n"):
		kept.append(AssetCheck.split_code_and_strings(line)["code"].strip_edges())
	var joined := " ".join(kept)
	while joined.contains("  "):
		joined = joined.replace("  ", " ")
	return joined


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


static func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		var sheet := _sheet_of(one)
		if sheet != null and sheet.character_name == who:
			return one
	return null


static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
