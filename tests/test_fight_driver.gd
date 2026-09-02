extends TestSuite
## One driver for a fight, and it is reachable from the atomic action surface.
##
## Before this, `CombatantRoster.step` was the only begin -> advance -> conclude
## driver in the project, and a scene built on the action surface could begin a
## fight and end one but nothing under `sim/` ran the cycle between. The five
## character run therefore wrote the roster's four rules out again by hand, and a
## second such run would have had to write them a third time.
##
## This suite is what stops that coming back. It checks three things:
##
##   1. **each of the four rules is in exactly one file under `sim/`**, by opening
##      `sim/` and reading every file rather than by naming the files here -- the
##      same discipline `tests/test_combat_resolution.gd` keeps with the damage
##      seam, and for the same reason: a typed list is only as strong as the day
##      it was written.
##   2. **no scenario re-implements any of them** -- the two runs built on the
##      action surface, and the world's roster, all reach the cycle through
##      `fight_step()` and hold none of its parts.
##   3. **a second scenario actually reaches a fight through it** -- the skirmish
##      is played, twice, and is required to have begun a fight, ended it, and
##      printed the same bytes both times.
class_name TestFightDriver

const SIM_DIR := "res://sim"

## The one file the four rules are expected to be in. Nothing below assumes this
## -- the scan finds whichever file each rule is in and the checks compare
## against this afterwards, so a rule that moved somewhere else would fail here
## with the place it moved to rather than silently pass.
const DRIVER := "res://sim/action_scene.gd"

## The four rules, each as the exact text the file that owns it must contain.
##
## They are strings rather than descriptions because the check has to be
## mechanical: a description of a rule cannot be counted, and a rule that is
## described in two files and written in one is not the problem this suite is
## about.
const FOUR_RULES := {
	"the pairing rule": "func _two_who_have_met(",
	"the engage radius": "const ENGAGE_RADIUS :=",
	"the per-tick cadence": "fight.advance()",
	"the ordering inside a tick": "func fight_step(",
}

## Every file that drives a fight, and what it must contain to be one: the call,
## and nothing of what the call holds.
const DRIVERS := [
	"res://sim/combatant_roster.gd",
	"res://sim/scripted_loop.gd",
	"res://sim/scripted_scenario.gd",
	"res://sim/scripted_skirmish.gd",
	"res://sim/scripted_turn.gd",
]


func _init() -> void:
	suite_name = "fight driver"


func run() -> void:
	_each_of_the_four_rules_is_in_exactly_one_file()
	_every_driver_calls_the_cycle_and_holds_none_of_it()
	_a_second_action_surface_scenario_reaches_a_fight()
	_the_world_and_the_action_surface_share_one_scene()


## Open `sim/`, read every file, and require each of the four rules to appear in
## exactly one of them -- and, having found where, require that one to be the
## same file for all four.
func _each_of_the_four_rules_is_in_exactly_one_file() -> void:
	var sources := _sim_sources()
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())
	check(sources.has(DRIVER), "the scan reaches %s" % DRIVER)

	for rule in FOUR_RULES:
		var text: String = FOUR_RULES[rule]
		var holders := PackedStringArray()
		for path in sources:
			if _read(path).contains(text):
				holders.append(path)
		equal(holders, PackedStringArray([DRIVER]),
			"%s ('%s') is in exactly one file under sim/" % [rule, text])

	# Broken in the other direction: the same scan, for a string that is in every
	# file, finds it everywhere. So a one-element answer above means "only there"
	# and not "the scan read nothing".
	var present := PackedStringArray()
	for path in sources:
		if _read(path).contains("func "):
			present.append(path)
	equal(present.size(), sources.size(),
		"the same scan over a string that is everywhere finds it in every file")


## Every file that drives a fight calls `fight_step()` and contains no part of
## what `fight_step()` decides.
func _every_driver_calls_the_cycle_and_holds_none_of_it() -> void:
	for path in DRIVERS:
		var text := _read(path)
		check(text != "", "%s is there to read" % path)
		check(text.contains("fight_step()"),
			"%s reaches the fight through fight_step()" % path)
		for rule in FOUR_RULES:
			var owned: String = FOUR_RULES[rule]
			if path == DRIVER:
				continue
			check(not text.contains(owned),
				"%s does not re-implement %s" % [path, rule])


## The skirmish -- a second scenario built on the action surface, which was
## written after the cycle moved and never contained a copy of it -- reaches a
## fight, resolves it, and prints the same bytes twice.
func _a_second_action_surface_scenario_reaches_a_fight() -> void:
	var once := ScriptedSkirmish.play()
	var twice := ScriptedSkirmish.play()
	equal(twice, once, "two plays of the skirmish print identical transcripts")

	var scene := ScriptedSkirmish.stage()
	var loop := ControlLoop.on(scene, ScriptedSkirmish.LOOP_SEED)
	ScriptedSkirmish.drive(scene)
	var joined := 0
	for _step in ScriptedSkirmish.TICKS:
		loop.step()
		var turn := scene.fight_step()
		if turn["began"] != null:
			joined = scene.fight.members.size()
	ScriptedSkirmish.release(scene)

	equal(scene.fights_begun, 1, "the skirmish begins exactly one fight")
	equal(scene.fights_ended, 1, "and it is over before the run is")
	equal(scene.fight, null, "and the scene is back in real time")
	equal(joined, 3, "all three commanders were on the board, two bands against one")
	check(scene.actors.size() < 3, "and somebody fell, so the fight was fought")


## The world's roster and a scene on the action surface are not two worlds. The
## roster holds an `ActionScene` and its combatants are that scene's actors, so
## the fight the world holds is the fight the action surface holds.
func _the_world_and_the_action_surface_share_one_scene() -> void:
	var roster := CombatantRoster.new()
	check(roster.scene != null, "a roster has a scene")
	var one := roster.add(Combatant.commander_at(0.0, 0.0, 0.0, 0.0, 1, AssetTags.KNIGHT))
	equal(one.id, 1, "the first combatant added is #1, as it always was")
	equal(roster.members.size(), 1, "the roster's members are the scene's actors")
	equal(roster.scene.actors.size(), 1, "read from either end")
	equal(roster.member_of(1), one, "and are found by id from either end")
	equal(roster.phase(), CombatantRoster.REAL_TIME, "with no fight on")
	equal(roster.fights_begun, 0, "and nothing begun")
	equal(roster.board_version, 0, "and no board built")


func _sim_sources() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(SIM_DIR)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.get_extension() == "gd":
			found.append(SIM_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
