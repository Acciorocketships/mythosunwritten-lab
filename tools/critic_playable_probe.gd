extends SceneTree
## Whether the character a person drives is one mind among many, tested against
## the mind that is hardest to be indistinguishable from: a language model.
##
## Written by the review of the playable layer (W-playable-review), not by the
## work under it. The earlier probe beside this one
## (`tools/critic_privilege_probe.gd`) put a person against a *program's rule*.
## That is the easy comparison: a rule answers the instant it is asked, so the
## only thing it can expose is whether the engine peeks at `decide`. A language
## model is the hard one, because it is the other mind in this project that
## cannot answer at once -- `ModelChannel.THINKS_FOR` ticks pass between the
## question and the reply -- and so it is the only comparison in which "a person
## is simply a slower mind" is a claim with content.
##
## Nothing here asserts. Every section prints what it tried and what came back,
## including the attacks that found nothing.
##
##   A -- one action of every kind, chosen by a person and by a model, through
##        the one driver, compared on the engine's answer and on the scene
##        fingerprint
##   B -- the ordinary world at one seed with its followed character driven by a
##        model, and then by a person choosing the model's own actions at the
##        ticks the model's answers were committed on: journals line for line,
##        and the world's own digest
##   C -- the same person pressing late, which must cost them ticks and must not
##        change the world
##   D -- what the two decision functions have in common, read off the objects
##        rather than off the prose: argument count, return, and what a null from
##        each does to the loop
##
## Run:  tools/critic_playable_probe.sh

const WORLD_SEED := 1234
const WORLD_TICKS := 90


func _initialize() -> void:
	_attempt_a()
	_attempt_b_and_c()
	_attempt_d()
	quit(0)


func _rule(title: String) -> void:
	print("")
	print("=== %s" % title)


func _say(label: String, verdict: String, detail: String) -> void:
	print("  [%s] %s -- %s" % [verdict, label, detail])


# --- A: one action of every kind, two minds, one engine --------------------


# For each row of the catalogue: stage the same scene twice, put the same
# choice on it once as a person's `LiveChoice` and once as a model's reply out
# of a channel, and drive one step with `DecisionSource.drive` -- the one driver
# both go through. Compare the engine's answer and the scene's fingerprint.
func _attempt_a() -> void:
	_rule("A -- one action of every kind, a person's hand and a model's reply, one driver")
	var differing := 0
	var unreadable := 0
	var tried := 0
	for chosen in _every_kind_of_choice():
		var written := _as_a_reply(chosen)
		var by_model := _drive_one("a model", chosen, written)
		var by_person := _drive_one("a person", chosen, "")
		tried += 1
		# The model's answer has to survive being written and read back before
		# the comparison means anything. Say so when it does not.
		if String(by_model["chose"]) != chosen.line():
			unreadable += 1
			_say(chosen.kind, "UNREADABLE",
				"written as '%s', read back as '%s'" % [written, by_model["chose"]])
			continue
		var same: bool = String(by_model["got"]) == String(by_person["got"]) \
			and String(by_model["print"]) == String(by_person["print"])
		if not same:
			differing += 1
			_say(chosen.kind, "FOUND", "%s | %s -- %s | %s" % [
				by_person["got"], by_model["got"],
				by_person["print"], by_model["print"]])
		else:
			_say(chosen.kind, "same", "%s | %s" % [by_person["got"], by_person["print"]])
	_say("actions tried", "%d" % tried,
		"engine answer and scene fingerprint compared, person against model")
	_say("actions the reply grammar could not carry", "%d" % unreadable,
		"not a privilege question: what a model cannot say it cannot choose")
	_say("actions whose outcome moved with the mind", "%d" % differing,
		"the driver and the engine are blind to which mind chose" if differing == 0
		else "the driver or the engine can tell the two apart")


# One step of `DecisionSource.drive` on a freshly staged scene, with the
# character's decision function built either way.
func _drive_one(which: String, chosen: Action, written: String) -> Dictionary:
	var scene := ScriptedActions.stage()
	var rook := scene.actors[0]
	var sheet := _sheet(rook)
	if which == "a person":
		var hand := LiveChoice.new()
		hand.choose(chosen)
		sheet.decide = DecisionSource.live(hand)
		# The person's character stands in the world for the same three ticks
		# the model's does while its call is outstanding. Without this the two
		# scenes are compared at different ticks and every fingerprint differs
		# for a reason that has nothing to do with who chose.
		sheet.decide.call(scene, rook)
		scene.advance(ModelChannel.THINKS_FOR)
	else:
		sheet.decide = DecisionSource.model(
			ModelMind.with_channel(_channel_saying([written])))
		# A model's answer is not there on the tick it is asked. Ask once to
		# open the exchange, let the channel's own thinking time pass, and then
		# drive -- which is the world going on turning, exactly as it does for a
		# person who has not pressed anything yet.
		sheet.decide.call(scene, rook)
		scene.advance(ModelChannel.THINKS_FOR)
	var taken := DecisionSource.drive(scene, rook, 1)
	if taken.is_empty():
		return {"chose": "<nothing>", "got": "<nothing>", "print": scene.fingerprint()}
	return {
		"chose": (taken[0]["chose"] as Action).line(),
		"got": (taken[0]["got"] as ActionOutcome).line(),
		"print": scene.fingerprint(),
	}


# One choice of every kind the catalogue names, so nothing is checked by
# sampling. The same twelve the earlier probe builds, built the same way.
func _every_kind_of_choice() -> Array:
	var scene := ScriptedActions.stage()
	var rook := scene.actors[0]
	var wren := scene.actors[1]
	var pile := scene.objects[0]
	var chest := scene.objects[1]
	var made := {
		ActionCatalog.GO_TO: Action.go_to(pile.id),
		ActionCatalog.JUMP: Action.jump(Vector2(rook.x + 2.0, rook.z)),
		ActionCatalog.ATTACK: Action.attack(wren.id, ScriptedActions.LOCKPICK),
		ActionCatalog.SAY: Action.say("good morning", wren.id),
		ActionCatalog.TRADE_PROPOSE: Action.trade_propose(
			wren.id, PackedStringArray(), 5, PackedStringArray(), 0),
		ActionCatalog.TRADE_ACCEPT: Action.trade_accept(wren.id),
		ActionCatalog.TRADE_DENY: Action.trade_deny(wren.id),
		ActionCatalog.PICK_UP: Action.pick_up(ScriptedActions.HATCHET),
		ActionCatalog.DROP: Action.drop(ScriptedActions.LOCKPICK),
		ActionCatalog.EXAMINE: Action.examine(ScriptedActions.LOCKPICK),
		ActionCatalog.INTERACT: Action.interact(chest.id, ScriptedActions.LOCKPICK),
		ActionCatalog.WAIT: Action.wait(3),
		ActionCatalog.EQUIP: Action.equip(ScriptedActions.BOOTS),
		ActionCatalog.UNEQUIP: Action.unequip(ScriptedActions.LOCKPICK),
		ActionCatalog.USE: Action.use(ScriptedActions.LOCKPICK),
	}
	var every := []
	var missing := PackedStringArray()
	for named in ActionCatalog.names():
		if made.has(named):
			every.append(made[named])
		else:
			missing.append(named)
	if not missing.is_empty():
		_say("actions this probe could not build", "GAP", ", ".join(missing))
	return every


# An action written the way a model would have to say it: the transcript's own
# line with the brackets taken off.
func _as_a_reply(chosen: Action) -> String:
	var line := chosen.line()
	var opened := line.find("(")
	if opened < 0 or not line.ends_with(")"):
		return line
	var inside := line.substr(opened + 1, line.length() - opened - 2)
	return "%s %s" % [line.substr(0, opened), inside] if inside != "" \
		else line.substr(0, opened)


# A channel that answers with the given replies, in order. Position matching in
# `ModelChannel._row_for` hands the n-th question the n-th row when no recorded
# fingerprint matches, which is what a made-up exchange always is.
func _channel_saying(replies: Array) -> ModelChannel:
	var rows := []
	for said in replies:
		rows.append({"prompt": "", "reply": said, "ms": 0})
	return ModelChannel.replaying(
		{"rows": rows, "from": "written by the review", "model": "none"},
		"a channel the review wrote, so the model arm says exactly what the"
		+ " person arm chooses and the comparison is about nothing else")


# --- B and C: a running world, driven by a model and then by a person -------


func _attempt_b_and_c() -> void:
	_rule("B -- the ordinary world with its followed character driven by a model, then by a person")
	var by_model := _world_driven_by_a_model()
	var said: Array = by_model["said"]
	var began: Array = by_model["began"]
	_say("what the model answered", str(said), "read back out of the channel")
	_say("the ticks those answers were committed on", str(began),
		"which is the tick the person half has to have chosen by")

	if said.is_empty():
		_say("the model chose nothing", "GAP",
			"the rest of B cannot be run: nothing to hand the person")
		return

	# A person choosing the model's own actions, one tick before each of the
	# ticks the model's answers were committed on -- the same alignment the
	# earlier probe uses, and for the same reason: `ControlLoop` resolves and
	# asks again inside one tick, so the holder has to be full before it asks.
	var in_step := {}
	for at in began.size():
		in_step[maxi(0, int(began[at]) - 1)] = at
	var by_person := _world_driven_by_a_person(by_model["actions_chosen"], in_step)
	_compare("asked at the same tick", by_person, by_model)

	_rule("C -- the same person, pressing after the question instead of before")
	var late := {}
	for at in began.size():
		late[int(began[at])] = at
	var as_latecomer := _world_driven_by_a_person(by_model["actions_chosen"], late)
	_compare("the person pressing late", as_latecomer, by_model)


func _compare(reading: String, left_run: Dictionary, right_run: Dictionary) -> void:
	var differing := 0
	var left: PackedStringArray = left_run["journal"]
	var right: PackedStringArray = right_run["journal"]
	for at in maxi(left.size(), right.size()):
		var one := left[at] if at < left.size() else "<none>"
		var two := right[at] if at < right.size() else "<none>"
		if one != two:
			differing += 1
			if differing <= 5:
				_say("%s: line %d" % [reading, at], "FOUND",
					"person: %s | model: %s" % [one, two])
	_say("%s: journal lines" % reading, "%d / %d" % [left.size(), right.size()],
		"a person driving the followed character against a model driving it")
	_say("%s: actions resolved" % reading, "%d / %d" % [
		left_run["actions"], right_run["actions"]],
		"how many of the same choices each got through")
	_say("%s: lines that differ" % reading, "%d" % differing,
		"the world cannot tell a person from a model" if differing == 0
		else "where they differ is printed above")
	_say("%s: world digests" % reading, "%s / %s" % [
		left_run["digest"], right_run["digest"]],
		"same world" if left_run["digest"] == right_run["digest"]
		else "different world")


# The world with its followed character's mind a language model, answering out
# of a channel the review wrote. What comes back includes the actions the model
# actually chose, so the person half can choose those same actions rather than
# ones this file typed in.
func _world_driven_by_a_model() -> Dictionary:
	var world := SimWorld.new(WORLD_SEED)
	var id := world.follow_id
	var driven := world.combat.member_of(id)
	var channel := _channel_saying([
		"go_to offset=(6.000, 2.000)",
		"jump target=(%.3f, %.3f)" % [driven.x + 2.0, driven.z + 1.0],
		"wait ticks=5",
	])
	var mind := ModelMind.with_channel(channel)
	var by_model := DecisionSource.model(mind)
	var said := []
	var chosen_actions := []
	var sheet := _sheet(driven)
	# A pass-through wrapper, so the actions the model chose can be handed to
	# the person half unchanged. It adds nothing and decides nothing.
	sheet.decide = func(scene: ActionScene, actor: Combatant) -> Action:
		var answer: Action = by_model.call(scene, actor)
		if answer != null and (chosen_actions.is_empty() or chosen_actions[-1] != answer):
			chosen_actions.append(answer)
			said.append(answer.line())
		return answer
	var run := _live_out(world, id, Callable())
	run["said"] = said
	run["actions_chosen"] = chosen_actions
	return run


# The same world with the same character driven by a person, choosing the given
# actions on the ticks `in_step` names.
func _world_driven_by_a_person(actions: Array, in_step: Dictionary) -> Dictionary:
	var world := SimWorld.new(WORLD_SEED)
	var id := world.follow_id
	var hand := WorldCast.hand_over(world, id)
	return _live_out(world, id, func(at: int) -> void:
		if in_step.has(at) and int(in_step[at]) < actions.size():
			hand.choose(actions[int(in_step[at])]))


# One run of the world, with an optional hand pressing between ticks.
func _live_out(world: SimWorld, id: int, pressing: Callable) -> Dictionary:
	var began := []
	var running: Action = null
	for _step in WORLD_TICKS:
		if pressing.is_valid():
			pressing.call(world.tick)
		world.step()
		var now: Action = world.combat.scene.in_progress.call(id)
		if now != null and now != running:
			began.append(world.tick)
		running = now
	return {
		"journal": world.loop.journal,
		"digest": world.digest(),
		"actions": world.loop.actions_of(id),
		"began": began,
	}


# --- D: what the two functions have in common, read off the objects ---------


func _attempt_d() -> void:
	_rule("D -- the two decision functions, compared as objects rather than as prose")
	var hand := LiveChoice.new()
	var as_person := DecisionSource.live(hand)
	var as_model := DecisionSource.model(
		ModelMind.with_channel(_channel_saying(["wait ticks=3"])))
	_say("argument count", "%d / %d" % [
		as_person.get_argument_count(), as_model.get_argument_count()],
		"same shape" if as_person.get_argument_count() == as_model.get_argument_count()
		else "different shape")

	var scene := ScriptedActions.stage()
	var rook := scene.actors[0]
	# Neither has anything to say on the tick it is first asked: the person has
	# not pressed and the model's call is outstanding.
	var person_first: Variant = as_person.call(scene, rook)
	var model_first: Variant = as_model.call(scene, rook)
	_say("answer on the tick each is first asked", "%s / %s" % [
		"null" if person_first == null else "an action",
		"null" if model_first == null else "an action"],
		"both say nothing yet, which every driver reads as 'waits in the world'"
		if person_first == null and model_first == null
		else "one of them answered at once and the other did not")

	# And both answer once what they were waiting for arrives.
	hand.choose(Action.wait(3))
	scene.advance(ModelChannel.THINKS_FOR)
	var person_then: Variant = as_person.call(scene, rook)
	var model_then: Variant = as_model.call(scene, rook)
	_say("answer once each has something", "%s / %s" % [
		"null" if person_then == null else (person_then as Action).line(),
		"null" if model_then == null else (model_then as Action).line()],
		"the same action from both" if person_then != null and model_then != null
			and (person_then as Action).line() == (model_then as Action).line()
		else "they answered differently")

	# Nothing in the simulation or the render layer may branch on which factory
	# built the function on the sheet. This is the source side of the same
	# question: the names, counted where they are used.
	# Naming a factory is how a scenario says what a cast's minds are; that is
	# not a branch. A branch is a line that *tests* which one is on the sheet,
	# and the place one would have to be written is the driver path.
	var branching := _lines_branching_on_a_factory()
	_say("lines anywhere under sim/ or render/ that test which factory is on a sheet",
		"%d" % branching.size(), "\n        ".join(branching)
		if not branching.is_empty() else "none: every mention is an assignment")
	var on_the_path := _driver_path_naming_a_factory()
	_say("files on the driver path naming any factory", "%d" % on_the_path.size(),
		", ".join(on_the_path) if not on_the_path.is_empty()
		else "none of action_engine, control_loop, character_upkeep, action_scene,"
			+ " combat_match or combat_resolution names one")


const FACTORIES := [
	"DecisionSource.live", "DecisionSource.model", "DecisionSource.recorded",
	"DecisionSource.plan", "DecisionSource.scripted",
]

## The files a choice actually travels through between being made and being
## resolved. If a privilege were written anywhere, it would have to be here.
const DRIVER_PATH := [
	"res://sim/action_engine.gd", "res://sim/control_loop.gd",
	"res://sim/character_upkeep.gd", "res://sim/action_scene.gd",
	"res://sim/combat_match.gd", "res://sim/combat_resolution.gd",
	"res://sim/board_turn.gd", "res://sim/action_catalog.gd",
]


# Every line under sim/ or render/ whose code -- not its comments -- both names a
# factory and tests something, which is the shape a branch on who is driving
# would have to take.
func _lines_branching_on_a_factory() -> PackedStringArray:
	var found := PackedStringArray()
	for path in _files_under(["res://sim", "res://render", "res://render/ui"]):
		if path == "res://sim/decision_source.gd":
			continue
		var handle := FileAccess.open(path, FileAccess.READ)
		if handle == null:
			continue
		var number := 0
		while not handle.eof_reached():
			var line := handle.get_line()
			number += 1
			var code := line.split("#")[0]
			var names := false
			for one in FACTORIES:
				if code.contains(String(one)):
					names = true
			if not names:
				continue
			if code.contains("==") or code.contains("!=") \
				or code.contains("if ") or code.contains("elif ") \
				or code.contains("match "):
				found.append("%s:%d %s" % [path, number, code.strip_edges()])
	return found


# Whether any file on the driver path names a factory at all.
func _driver_path_naming_a_factory() -> PackedStringArray:
	var found := PackedStringArray()
	for path in DRIVER_PATH:
		var handle := FileAccess.open(String(path), FileAccess.READ)
		if handle == null:
			found.append("%s (missing)" % path)
			continue
		var hits := 0
		while not handle.eof_reached():
			var code := handle.get_line().split("#")[0]
			for one in FACTORIES:
				if code.contains(String(one)):
					hits += 1
		if hits > 0:
			found.append("%s (%d)" % [path, hits])
	return found


func _files_under(dirs: Array) -> PackedStringArray:
	var found := PackedStringArray()
	for where in dirs:
		var dir := DirAccess.open(String(where))
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if entry.get_extension() == "gd":
				found.append(String(where).path_join(entry))
			entry = dir.get_next()
		dir.list_dir_end()
	return found


func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
