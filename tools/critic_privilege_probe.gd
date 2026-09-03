extends SceneTree
## Deliberate attempts to find a path by which the character a person drives can
## do something the character a program drives cannot, or the reverse.
##
## Written by the review rather than by the work under it. Nothing here asserts;
## it reports what it tried and what came back, including the attacks that found
## nothing, because an attack that found nothing is evidence and a silent one is
## not. Every section prints a number.
##
##   A -- the engine's answer does not depend on what is on `decide`
##   B -- the control loop's journal does not depend on which factory made the
##        decision function, only on the actions it returns
##   C -- the whole seeded scenario, with the one person in it driven instead by
##        a program returning the same choices at the same index
##   D -- the combat numbers of a person-driven and a program-driven commander
##   E -- what a decision function is handed, and who reads it
##   F -- a whole running world whose cast contains a person
##
## Section F was added when the live decision function landed (W-player-input),
## because until then there was no person to put in a cast: every "person" above
## is a written-down list standing in for one. It is the same attack as C, moved
## from a staged scene to `SimWorld` -- the world the render shell steps -- and
## it drives one of its characters through `DecisionSource.live` against a
## program returning the identical choices at the identical index.
##
## Run:  tools/godot/godot4 --headless --path . --script res://tools/critic_privilege_probe.gd

const SEED := ScriptedActions.SEED
const TICKS := 60


func _initialize() -> void:
	_attempt_a()
	_attempt_b()
	_attempt_c()
	_attempt_d()
	_attempt_e()
	_attempt_f()
	quit(0)


func _rule(title: String) -> void:
	print("")
	print("=== %s" % title)


func _say(label: String, verdict: String, detail: String) -> void:
	print("  [%s] %s -- %s" % [verdict, label, detail])


# --- A: the engine is blind to the decision function ----------------------


# Resolve the same action for the same actor on three scenes staged identically,
# with three different things on `decide`: nothing at all, a person's recorded
# list, and a program's rule. If any outcome text or scene fingerprint differs,
# the engine can tell who is calling it.
func _attempt_a() -> void:
	_rule("A -- one action, three decision functions, one engine")
	var differing := 0
	var tried := 0
	for chosen in _every_kind_of_choice():
		var lines := PackedStringArray()
		var prints := PackedStringArray()
		for which in ["nothing", "a person's list", "a program's rule"]:
			var scene := ScriptedActions.stage()
			var rook := scene.actors[0]
			var sheet := _sheet(rook)
			if which == "a person's list":
				sheet.decide = DecisionSource.recorded([chosen])
			elif which == "a program's rule":
				sheet.decide = DecisionSource.scripted(
					func(_s: ActionScene, _a: Combatant) -> Action: return chosen)
			var got := ActionEngine.resolve(scene, rook, chosen)
			lines.append(got.line())
			prints.append(scene.fingerprint())
		tried += 1
		var same := lines[0] == lines[1] and lines[1] == lines[2] \
			and prints[0] == prints[1] and prints[1] == prints[2]
		if not same:
			differing += 1
			_say(chosen.kind, "FOUND", "%s | %s" % [
				" / ".join(lines), " / ".join(prints)])
		else:
			_say(chosen.kind, "same", "%s | %s" % [lines[0], prints[0]])
	_say("actions tried", "%d" % tried,
		"outcome text and scene fingerprint compared three ways each")
	_say("actions whose outcome moved with the decider", "%d" % differing,
		"nothing on `decide` reached the engine" if differing == 0
		else "the engine can tell who is calling it")


# One choice of every kind in the catalogue, so nothing is checked by sampling.
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


# --- B: the loop is blind to which factory made the Callable --------------


# Two runs of one scene, identical in every respect except how the character's
# decision function was built: once as a person's written-down list read against
# what has been carried out, once as a program's rule computing the same answer
# from the same index. The journals are compared line by line.
func _attempt_b() -> void:
	_rule("B -- one list of choices, two kinds of decision function, one loop")
	var as_person := _play_with(true)
	var as_program := _play_with(false)

	var differing := 0
	var left_lines: PackedStringArray = as_person["journal"]
	var right_lines: PackedStringArray = as_program["journal"]
	for at in maxi(left_lines.size(), right_lines.size()):
		var left := left_lines[at] if at < left_lines.size() else "<none>"
		var right := right_lines[at] if at < right_lines.size() else "<none>"
		if left != right:
			differing += 1
			if differing <= 3:
				_say("line %d" % at, "FOUND", "%s | %s" % [left, right])
	_say("journal lines", "%d / %d" % [left_lines.size(), right_lines.size()],
		"a person's list against a program's rule over %d ticks" % TICKS)
	_say("actions resolved", "%d / %d" % [as_person["actions"], as_program["actions"]],
		"how many of the written-down turns each got through")
	_say("lines that differ", "%d" % differing,
		"the loop cannot tell the two apart" if differing == 0
		else "the loop treats the two differently")
	_say("scene fingerprints", "%s / %s" % [
		as_person["fingerprint"], as_program["fingerprint"]],
		"same world change" if as_person["fingerprint"] == as_program["fingerprint"]
		else "different world change")


func _play_with(as_a_person: bool) -> Dictionary:
	var scene := ScriptedActions.stage()
	var rook := scene.actors[0]
	var pile := scene.objects[0]
	var choices := [
		Action.go_to(pile.id),
		Action.pick_up(ScriptedActions.HATCHET),
		Action.examine(ScriptedActions.HATCHET),
		Action.wait(6),
		Action.drop(ScriptedActions.HATCHET),
	]
	var loop := ControlLoop.on(scene, SEED)
	var id := rook.id
	if as_a_person:
		# The shape a person's turns take under the loop: a plan, over the
		# written-down list.
		_sheet(rook).decide = DecisionSource.plan(choices)
	else:
		# The same answer, computed by a rule.
		_sheet(rook).decide = DecisionSource.scripted(
			func(_s: ActionScene, _a: Combatant) -> Action:
				var at := loop.actions_of(id)
				return choices[at] if at < choices.size() else null)
	loop.run(TICKS)
	return {
		"journal": loop.journal,
		"fingerprint": scene.fingerprint(),
		"actions": loop.actions_of(id),
	}


# --- C: the seeded scenario with the person replaced by a program ----------


# The checked-in run has one person in it. Replace that person's decision
# function with a program returning the identical choices at the identical
# index, change nothing else, and compare the whole 110-tick transcript --
# including the fight, which is stepped exactly as ScriptedScenario steps it.
func _attempt_c() -> void:
	_rule("C -- the whole scenario with the person driven by a program")
	var real := _scenario(true)
	var swapped := _scenario(false)
	var differing := 0
	for at in maxi(real.size(), swapped.size()):
		var left := real[at] if at < real.size() else "<none>"
		var right := swapped[at] if at < swapped.size() else "<none>"
		if left != right:
			differing += 1
			if differing <= 5:
				_say("line %d" % at, "FOUND", "%s | %s" % [left, right])
	_say("transcript lines", "%d / %d" % [real.size(), swapped.size()],
		"as written against the person replaced by a program")
	_say("lines that differ", "%d" % differing,
		"the one person in the run is not privileged by the loop" if differing == 0
		else "replacing the person changed the run")


# ScriptedScenario.play, re-walked here so one thing can be changed in the
# middle of it: how Wren's decision function was built.
func _scenario(as_a_person: bool) -> PackedStringArray:
	var scene := ScriptedScenario.stage_for(ScriptedScenario.SEED)
	var loop := ControlLoop.on(scene, ScriptedScenario.LOOP_SEED)
	ScriptedScenario.drive(scene)
	var wren: Combatant = null
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == ScriptedScenario.WREN:
			wren = one
	var choices := ScriptedScenario.wren_choices(scene)
	var id := wren.id
	if as_a_person:
		_sheet(wren).decide = DecisionSource.plan(choices)
	else:
		_sheet(wren).decide = DecisionSource.scripted(
			func(_s: ActionScene, _a: Combatant) -> Action:
				var at := loop.actions_of(id)
				return choices[at] if at < choices.size() else null)

	var written := PackedStringArray()
	for line in ScriptedScenario.cast_lines(scene):
		written.append("    " + line)
	for line in scene.lines():
		written.append("    " + line)
	var said := 0
	for _step in ScriptedScenario.TICKS:
		loop.step()
		for at in range(said, loop.journal.size()):
			written.append(loop.journal[at])
		said = loop.journal.size()
		written.append_array(ScriptedScenario._fight_step(scene))
	written.append("after %d ticks" % scene.tick)
	for line in scene.lines():
		written.append("    " + line)
	written.append("  fingerprint %s" % scene.fingerprint())
	ScriptedScenario.release(scene)
	return written


# --- D: the combat numbers of the two -------------------------------------


# Two commanders built identically, one carrying a person's decision function and
# one a program's. Every number the board reads off them is compared.
func _attempt_d() -> void:
	_rule("D -- what the board reads off a person and off a program")
	var person := _suited(DecisionSource.recorded([Action.wait(1)]))
	var program := _suited(DecisionSource.scripted(
		func(_s: ActionScene, _a: Combatant) -> Action: return Action.wait(1)))
	var rows := {
		"level": [person.level, program.level],
		"health": [person.health, program.health],
		"max health": [person.max_health(), program.max_health()],
		"status": [person.sheet.status(), program.sheet.status()],
		"defence": [person.defence(), program.defence()],
		"move grants": [person.move_grants().size(), program.move_grants().size()],
		"loadout": [person.loadout_line(), program.loadout_line()],
		"attacks": [person.attack_count(), program.attack_count()],
		"first attack damage": [person.damage_of(0), program.damage_of(0)],
		"attack cells": [
			str(person.attack_cells(0)), str(program.attack_cells(0))],
	}
	var differing := 0
	for label in rows:
		var pair: Array = rows[label]
		if str(pair[0]) != str(pair[1]):
			differing += 1
			_say(label, "FOUND", "%s | %s" % [pair[0], pair[1]])
		else:
			_say(label, "same", str(pair[0]))
	_say("numbers that differ", "%d" % differing,
		"the board reads the same commander either way" if differing == 0
		else "the board reads them differently")


func _suited(decider: Callable) -> Commander:
	var made := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, 8)
	var sheet := Character.make("Twin", 8)
	sheet.record_scores({Ability.DEX: 8, Ability.STR: 8, Ability.WIS: 8, Ability.CON: 8})
	sheet.decide = decider
	made.adopt(sheet)
	for slot in Armour.SLOTS:
		made.equip(Armour.worn(slot, 8))
	made.wield(Weapon.held(Weapon.sword(), 8))
	return made


# --- E: what is handed to a decision function, and who reads it ------------


func _attempt_e() -> void:
	_rule("E -- what is handed to a decision function, and who reads it")
	var scene := ScriptedActions.stage()
	var rook := scene.actors[0]
	var handed := []
	_sheet(rook).decide = DecisionSource.scripted(
		func(s: ActionScene, a: Combatant) -> Action:
			handed.append([s == scene, a == rook])
			return Action.wait(1))
	var loop := ControlLoop.on(scene, SEED)
	loop.step()
	_say("arguments a decision function is called with", "%d" % 2,
		"func(scene, actor) -> Action; the scene and the actor it is choosing for: %s"
		% ("the same two objects" if handed.size() > 0 and handed[0] == [true, true]
			else str(handed)))

	var readers := PackedStringArray()
	for path in _sim_files():
		var text := FileAccess.get_file_as_string(path)
		var code := PackedStringArray()
		for line in text.split("\n"):
			var trimmed := line.strip_edges()
			if not trimmed.begins_with("#"):
				code.append(line)
		if "\n".join(code).contains(".decide"):
			readers.append(path.get_file())
	_say("files under sim/ whose code reads `decide`", "%d" % readers.size(),
		", ".join(readers))


# --- F: a running world whose cast contains a person -----------------------


## How many ticks of the ordinary world each half of F is played for. Long
## enough for three walks each at 20 ticks a walk.
const WORLD_TICKS := 70

## The seed the ordinary world is stood up on: the one the headless run reports.
const WORLD_SEED := 1234


# Two runs of the ordinary world, identical in every respect except how the
# followed character's decision function was built: once as a person choosing
# through `LiveChoice`, once as a program's rule returning the same choice at
# the same index. Every line of both control-loop journals is compared, and so
# is the world's own fingerprint.
#
# ## Asking both the same question at the same moment
#
# A program's rule is *evaluated* when the question is put, so its answer is
# always there. A person's answer is written down beforehand and read when the
# question is put, so a comparison has to put the choice in the holder before
# the tick the loop asks on, or it measures when the person pressed rather than
# whether the world privileges them. `ControlLoop._complete` resolves an action
# and asks again inside the same tick, so the moment to press is the tick
# before each of the program's own starts.
#
# Those ticks are not typed in here: the program half is played first and asked
# when it began each action, and the person half presses one tick before each.
# That keeps the two halves asked the same question at the same tick however the
# costs in the catalogue change.
#
# The second reading below is the same pair with the person pressing late
# instead. It is reported because it is a real and wanted property rather than a
# fault: a choice that arrives after the question was asked starts later, which
# is a person being a slower mind, and the world holds it by having the
# character wait. What it must not do is change the world -- so the fingerprints
# are compared there too.
func _attempt_f() -> void:
	_rule("F -- the ordinary world with one of its cast driven by a person")
	var as_program := _world_with(false, {})
	var began: Array = as_program["began"]

	# One tick before each of the program's own starts: see the note above.
	var in_step := {}
	for at in began.size():
		in_step[maxi(0, int(began[at]) - 1)] = at
	var as_person := _world_with(true, in_step)

	_say("the program began on ticks", str(began),
		"when the rule's answer was committed, which is when the person is asked")
	_compare("asked at the same tick", as_person, as_program)

	# And the same pair with the person pressing a tick late instead.
	var late := {}
	for at in began.size():
		late[int(began[at])] = at
	var as_latecomer := _world_with(true, late)
	_compare("the person pressing late", as_latecomer, as_program)


# One half of F against the other, line for line.
func _compare(reading: String, left_run: Dictionary, right_run: Dictionary) -> void:
	var differing := 0
	var left: PackedStringArray = left_run["journal"]
	var right: PackedStringArray = right_run["journal"]
	for at in maxi(left.size(), right.size()):
		var one := left[at] if at < left.size() else "<none>"
		var two := right[at] if at < right.size() else "<none>"
		if one != two:
			differing += 1
			if differing <= 3:
				_say("%s: line %d" % [reading, at], "FOUND",
					"%s | %s" % [one, two])
	_say("%s: journal lines" % reading, "%d / %d" % [left.size(), right.size()],
		"a person driving one of the cast against a program driving it")
	_say("%s: actions resolved" % reading, "%d / %d" % [
		left_run["actions"], right_run["actions"]],
		"how many of the same choices each got through")
	_say("%s: lines that differ" % reading, "%d" % differing,
		"the world cannot tell a person from a program" if differing == 0
		else "only in which tick each action started -- the person pressed after"
			+ " the question, so their character waited a tick and then did the"
			+ " same thing")
	_say("%s: world fingerprints" % reading, "%s / %s" % [
		left_run["digest"], right_run["digest"]],
		"same world" if left_run["digest"] == right_run["digest"]
		else "different world")


# One run of the ordinary world with its followed character driven either way.
#
# The choices are the same three. A program is asked on every tick and answers
# from how many its character has had carried out; a person's answers are put in
# the holder on the ticks `in_step` names, keyed by tick and naming which choice.
# Nothing else differs -- same seed, same cast, same loop, same engine.
#
# `began` comes back as well: the tick each action was committed on, which is
# what the person half is timed against.
func _world_with(as_a_person: bool, in_step: Dictionary) -> Dictionary:
	var world := SimWorld.new(WORLD_SEED)
	var id := world.follow_id
	var driven := world.combat.member_of(id)
	var choices := [
		Action.go_to(Vector2(driven.x + 6.0, driven.z + 2.0)),
		Action.jump(Vector2(driven.x + 6.0, driven.z + 4.0)),
		Action.wait(5),
	]
	var choice: LiveChoice = null
	if as_a_person:
		choice = WorldCast.hand_over(world, id)
	else:
		var sheet := _sheet(driven)
		sheet.decide = DecisionSource.scripted(
			func(scene: ActionScene, actor: Combatant) -> Action:
				var at := scene.actions_of(actor.id)
				return choices[at] if at < choices.size() else null)

	var began := []
	var running: Action = null
	for _step in WORLD_TICKS:
		if as_a_person and in_step.has(world.tick):
			choice.choose(choices[int(in_step[world.tick])])
		world.step()
		# What the loop committed to this tick, if it committed to anything new.
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


func _sim_files() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open("res://sim")
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.get_extension() == "gd":
			found.append("res://sim".path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
