extends SceneTree
## What one line the action catalogue cannot read costs a character, measured.
##
## `ActionCatalog.fault()` refuses a malformed choice -- an unknown action, a
## missing key, a name where an id is wanted -- and every mind in this project
## reads its own position out of `ActionScene.actions_of`: a plan is read at that
## index, a person's standing choice is taken back when it moves, and a
## `ModelMind` keeps its answer against it. So whether a refused choice moves
## that count decides whether an unreadable line costs one turn or the rest of
## the run.
##
## Three sections, each run rather than argued:
##
##   * **A** -- the shipped model run with one unreadable reply put into it, in
##     the place of the reply one character's first question was recorded with.
##     Everything else in the recording is the shipped reply. What is measured is
##     that character's turns, its questions, and how many times the same refused
##     sentence came back, against the other four.
##   * **B** -- the same line handed to three different minds: a written-down
##     plan, a person choosing while the world runs, and a model. Each is given a
##     faulted choice first and a well-formed one after it, and what is measured
##     is whether the second one is ever reached.
##   * **C** -- the four failures that are not the catalogue's -- there is no
##     world, the one acting is not in it, the thing acting is not a character,
##     the actor is down -- with the count printed either side of each.
##
## Nothing here calls a model or reads a clock: section A replays the checked-in
## recording with one reply substituted, and two runs print identical bytes.
##
## Run:  tools/fault_lock_probe.sh

## Whose first recorded reply is replaced, and with what.
##
## The line is the one `inception/mercury-2.5-preview` actually answered in the
## live pass of the previous cycle -- an `examine` with no `target=` key -- and it
## is the shape of every unreadable line: the reader builds the action the verb
## names and the catalogue then says what it is missing.
const WHO := "Sable"
const UNREADABLE := "examine #3"

## A second unreadable shape, for section B: a name where the catalogue wants an
## id. `examine` takes either, so a name is legal there; `say`, `go_to` and
## `attack` take an id alone, and a name in one of those is a fault.
const A_NAME_NOT_AN_ID := "Sable"

## How many ticks of the shipped run are enough to see every character's first
## question asked, which is all section A needs from its first pass.
const SCOUT_TICKS := 12

## How long section B's scenes live, in ticks.
const BENCH_TICKS := 60


func _initialize() -> void:
	print("")
	print("=== the fault lock -- what a line the catalogue cannot read costs")
	_the_shipped_run_with_one_unreadable_reply()
	_every_mind_handed_the_same_bad_line()
	_the_four_that_must_not_count()
	quit(0)


# --- A: the shipped run, with one reply replaced --------------------------


func _the_shipped_run_with_one_unreadable_reply() -> void:
	var read_back := ModelPrompt.action_of(UNREADABLE)
	print("")
	print("=== A -- ./run_agent.sh, seed %d, %d ticks, with one reply replaced"
		% [ScriptedAgent.SEED, ScriptedAgent.TICKS])
	print("  the line:      %s" % UNREADABLE)
	print("  reads back as: %s" % ("nothing" if read_back == null else read_back.line()))
	print("  the catalogue: %s" % ActionCatalog.fault(read_back))

	var digest := _first_question_of(WHO)
	print("  put in place of the reply recorded for %s's first question (%s);"
		% [WHO, digest])
	print("  every other reply in the recording is the shipped one.")

	var played := ScriptedAgent.played_with(
		ModelChannel.replaying(
			_with_one_reply_replaced(digest, UNREADABLE),
			"the shipped recording with one reply replaced by an unreadable line"),
		ScriptedAgent.TICKS, ScriptedAgent.SEED)
	var cast: ModelCast = played["cast"]
	var loop: ControlLoop = played["loop"]
	var scene: ActionScene = played["scene"]

	print("")
	print("  %-6s %6s %6s %8s %9s %8s  %s" % [
		"who", "turns", "asked", "resolved", "refusals", "no reply",
		"what the engine last answered it"])
	for who in cast.order:
		var mind: ModelMind = cast.mind_of(who)
		var one := _named(scene, who)
		var answers := _engine_answers(loop.journal, who)
		print("  %-6s %6d %6d %8d %9d %8d  %s" % [
			who, mind.turns.size(), mind.opened,
			0 if one == null else scene.actions_of(one.id),
			_refused(answers), _unanswered(played["channel"], who), _last(answers),
		])
	var locked := cast.mind_of(WHO)
	print("")
	print("  %s put %d question%s to the model in %d ticks and held one answer for %d of them."
		% [WHO, locked.opened, "" if locked.opened == 1 else "s",
			ScriptedAgent.TICKS, locked.held])
	var mine := _engine_answers(loop.journal, WHO)
	var sentence := "%s refused: %s" % [
		ActionCatalog.EXAMINE, ActionCatalog.fault(ModelPrompt.action_of(UNREADABLE))]
	print("  the one sentence `%s' came back %d time%s." % [
		sentence, _times(mine, sentence), "" if _times(mine, sentence) == 1 else "s"])
	print("  `no reply' is the other thing a locked character does to a replayed run: it stops")
	print("  moving, so what everybody else sees stops being what the recording was made")
	print("  against, and a question nothing recorded answers leaves its asker standing too.")


# How many of a named character's questions the recording had nothing to answer
# with. Read off the channel, which keeps the note it wrote for every question.
func _unanswered(channel: ModelChannel, who: String) -> int:
	var found := 0
	for asking in channel.questions():
		if not String(asking["prompt"]).begins_with("You are %s," % who):
			continue
		if String(asking["note"]).contains("nothing to answer with"):
			found += 1
	return found


# The digest of the first question a named character puts, taken off a short
# pass of the same run: the questions of tick one are the questions of tick one
# whatever the run does afterwards.
func _first_question_of(who: String) -> String:
	var channel := ModelChannel.replaying(
		ModelRecording.exchange(), "a short pass, to see which row answers whom")
	ScriptedAgent.played_with(channel, SCOUT_TICKS, ScriptedAgent.SEED)
	for asking in channel.questions():
		if String(asking["prompt"]).begins_with("You are %s," % who):
			return String(asking["digest"])
	return ""


# The shipped recording with the reply of one row -- the row recorded for a
# named question -- replaced. Every other row is the shipped row.
func _with_one_reply_replaced(digest: String, reply: String) -> Dictionary:
	var shipped := ModelRecording.exchange()
	var rows := []
	for row in shipped["rows"]:
		var kept: Dictionary = (row as Dictionary).duplicate()
		if String(kept.get("prompt", "")) == digest:
			kept["reply"] = reply
		rows.append(kept)
	return {"rows": rows, "from": shipped["from"], "model": shipped["model"]}


# --- B: the same line, three minds ----------------------------------------


func _every_mind_handed_the_same_bad_line() -> void:
	print("")
	print("=== B -- one faulted choice and one good one, handed to three minds")
	var faulted := Action.of(
		ActionCatalog.SAY, {"text": "well met", "target": A_NAME_NOT_AN_ID})
	print("  the faulted choice: %s -- %s" % [
		faulted.line(), ActionCatalog.fault(faulted)])
	print("  the good one after it: %s" % Action.wait(2).line())
	print("")
	print("  %-28s %8s %9s %8s %s" % [
		"the mind", "resolved", "refusals", "reached", "what it did with the second choice"])
	_bench("a written-down plan", func(_c: LiveChoice) -> Callable:
		return DecisionSource.plan([faulted, Action.wait(2)]))
	_bench("a person at a keyboard", func(chosen: LiveChoice) -> Callable:
		chosen.choose(faulted)
		return DecisionSource.live(chosen))
	_bench_a_model(faulted)


# One scene, one character, one mind, run for BENCH_TICKS.
#
# The person is a person: nothing is written down in advance, and the second
# choice is made only once the world has taken the first one back, which is what
# `LiveChoice.withdraw()` does and what somebody watching their character would
# see happen.
func _bench(called: String, make: Callable) -> void:
	var scene := _one_character_scene()
	var one: Combatant = scene.actors[0]
	var chosen := LiveChoice.new()
	var sheet := _sheet_of(one)
	sheet.decide = make.call(chosen)
	var loop := ControlLoop.on(scene, 7)
	for _tick in BENCH_TICKS:
		loop.step()
		if chosen.made > 0 and chosen.waiting() and chosen.made < 2:
			chosen.choose(Action.wait(2))
	_bench_line(called, scene, loop, one)


# The same bench with a model for a mind: two recorded replies, the first
# unreadable and the second an action, replayed with no model and no network.
func _bench_a_model(_faulted: Action) -> void:
	var scene := _one_character_scene()
	var one: Combatant = scene.actors[0]
	var channel := ModelChannel.replaying({
		"rows": [
			{"prompt": "", "reply": "say text=well met target=#%s" % A_NAME_NOT_AN_ID, "ms": 0},
			{"prompt": "", "reply": "wait ticks=2", "ms": 0},
		],
		"from": "written here, not recorded: two replies to make the point",
		"model": "none",
	}, "two replies handed in, the first of them unreadable")
	var mind := ModelMind.with_channel(channel)
	_sheet_of(one).decide = DecisionSource.model(mind)
	var loop := ControlLoop.on(scene, 7)
	for _tick in BENCH_TICKS:
		loop.step()
	_bench_line("a model", scene, loop, one, mind)


func _bench_line(
	called: String, scene: ActionScene, loop: ControlLoop, one: Combatant,
	mind: ModelMind = null
) -> void:
	var answers := _engine_answers(loop.journal, ActionScene.name_of(one))
	var reached := ""
	for row in answers:
		if String(row["said"]).begins_with("wait"):
			reached = String(row["said"])
			break
	print("  %-28s %8d %9d %8s %s" % [
		called, scene.actions_of(one.id), _refused(answers),
		"yes" if reached != "" else "no",
		reached if reached != "" else "never reached -- %s" % _first_line(answers),
	])
	if mind != null:
		print("  %-28s   questions put: %d, answers held: %d" % [
			"", mind.opened, mind.held])


# --- C: the four that must not count --------------------------------------


func _the_four_that_must_not_count() -> void:
	print("")
	print("=== C -- the four refusals that are not the catalogue's")
	var scene := _one_character_scene()
	var one: Combatant = scene.actors[0]
	var outsider := Combatant.commander_at(0.0, 0.0, 0.0, 0.0, 1, AssetTags.KNIGHT)
	(outsider.piece as Commander).adopt(Character.make("Nobody", 1))
	var minion := scene.add_actor(Combatant.minion_at(Minion.TOADSTOOL, 9, 1.0, 0.0, 0.0, 0.0))
	var downed := scene.add_actor(Combatant.commander_at(
		2.0, 0.0, 0.0, 0.0, 1, AssetTags.KNIGHT))
	(downed.piece as Commander).adopt(Character.make("Fallen", 1))
	downed.piece.health = 0

	var good := Action.wait(1)
	print("  %-34s %-44s %s" % ["the refusal", "what it says", "counted"])
	_no_count("there is no world to act in", null, one, good, scene, one.id)
	_no_count("the one acting is not in the world", scene, outsider, good, scene, one.id)
	_no_count("only a character acts", scene, minion, good, scene, minion.id)
	_no_count("the actor is down", scene, downed, good, scene, downed.id)


func _no_count(
	called: String, at: ActionScene, actor: Combatant, action: Action,
	counting: ActionScene, id: int
) -> void:
	var before := counting.actions_of(id)
	var outcome := ActionEngine.resolve(at, actor, action)
	var after := counting.actions_of(id)
	print("  %-34s %-44s %s" % [
		called, outcome.reason,
		"no (%d -> %d)" % [before, after] if before == after else "YES (%d -> %d)" % [
			before, after],
	])


# --- The scenes and the reading ------------------------------------------


func _one_character_scene() -> ActionScene:
	var scene := ActionScene.on()
	var one := scene.add_actor(Combatant.commander_at(
		0.0, 0.0, 0.0, 0.0, 2, AssetTags.KNIGHT))
	var sheet := Character.make("Rook", 2)
	(one.piece as Commander).adopt(sheet)
	return scene


# What the engine answered a named character, read out of the loop's journal.
#
# A journal line is `t=%3d  <name> <what>`, and the ones this reads are the
# `finished <choice> -> <answer>` lines, which is where an action that reached
# the engine and what came back of it are both written down.
func _engine_answers(journal: PackedStringArray, who: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line in journal:
		var at := line.find("  %-6s finished " % who)
		if at < 0:
			continue
		var rest := line.substr(at + 2 + maxi(6, who.length()) + 10)
		var arrow := rest.find(" -> ")
		if arrow < 0:
			continue
		found.append({
			"chose": rest.substr(0, arrow).strip_edges(),
			"said": rest.substr(arrow + 4).strip_edges(),
		})
	return found


func _times(answers: Array[Dictionary], sentence: String) -> int:
	var found := 0
	for row in answers:
		if String(row["said"]) == sentence:
			found += 1
	return found


func _refused(answers: Array[Dictionary]) -> int:
	var found := 0
	for row in answers:
		if String(row["said"]).contains("refused:"):
			found += 1
	return found


func _last(answers: Array[Dictionary]) -> String:
	return "--" if answers.is_empty() else String(answers[answers.size() - 1]["said"])


func _first_line(answers: Array[Dictionary]) -> String:
	return "--" if answers.is_empty() else String(answers[0]["said"])


func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		if ActionScene.name_of(one) == who:
			return one
	return null


func _sheet_of(one: Combatant) -> Character:
	return (one.piece as Commander).sheet
