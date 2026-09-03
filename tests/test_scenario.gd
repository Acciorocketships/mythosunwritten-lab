extends TestSuite
## The end-to-end run of the character layer, tested as the thing it claims to
## be: five characters, none of them privileged, living one seeded run.
##
## Ten claims:
##
##   1. **Five characters, and the only difference between them is a
##      `Callable`.** All five sheets are the same class; all five decision
##      functions have one signature, answer either an `Action` or nothing when
##      called with the same two arguments, and are read off the sheet by the
##      loop with nothing to tell them apart.
##   2. **A person's turns are exercised by the run.** Wren's recorded list is
##      carried out in the order it was written, one resolution per entry, and
##      every entry appears in the journal as a finished action.
##   3. **A plan is not drained by being asked.** The measurement behind
##      `DecisionSource.plan`: the same ten choices, counted both by what the loop
##      resolved and by what the source has left, add up to ten as a plan and to
##      four as a queue -- computed here rather than asserted.
##   4. **Every beat of the run happens**: movement, speech both ways, a
##      pick-up, and a trade that moves items and money in one exchange, with
##      both sides' inventories read.
##   5. **The fight snaps on and comes back off**: the board appears under the
##      two who met, the match is played to a decision, and the survivor is
##      handed back to real time at the world position of its own last cell.
##   6. **The fight is local**: the three characters outside `JOIN_RADIUS` are
##      never on the board and go on acting through the whole of it.
##   7. **An atomic attack chosen mid-fight lands, on the turn that spends it**,
##      and the arithmetic is computed from the catalogue and the transcript
##      rather than typed: a turn lasts as long as the weapon action it spends,
##      so a blow costing more ticks than a turn used to last is carried out
##      rather than abandoned.
##   8. **Two processes agree**, and the transcript checked in under reports/ is
##      what the command prints.
##   9. **A character put into the world carries the sheet it was played with.**
##      What `ScriptedScenario.muster` stands up in the world's roster is read
##      off *the roster* and compared, field by field, with what the same run
##      gave the same character: the name, the level, the status, the health it
##      was left on, the six ability scores, the money, what it carries and what
##      it has on.
##   10. **Nobody in a shipped scenario's world is nameless or unrolled.** Every
##      scenario `Simulation` will set out, asked of every character standing in
##      the world afterwards -- and the same two questions asked of a sheet
##      nobody has named or rolled, so the check is shown to have teeth.
class_name TestScenario

## How many characters the run has, and how many are driven by a person's
## recorded list. Both read off the table rather than typed, so a cast that grows
## does not need this file edited.
const CAST_SIZE := 5

## The file the run's transcript is kept in, and the command that writes it.
const TRANSCRIPT := "res://reports/scenario-evidence.txt"
const COMMAND := "res://run_scenario.sh"

## The two readings of one written-down list, named so the measurement below says
## which it is playing.
const AS_A_PLAN := "plan"
const AS_A_QUEUE := "queue"


func _init() -> void:
	suite_name = "scenario"


func run() -> void:
	_five_characters_differ_by_one_callable()
	_a_persons_turns_are_taken_in_order()
	_a_plan_is_not_drained_by_being_asked()
	_every_beat_of_the_run_happens()
	_the_fight_snaps_on_and_comes_back_off()
	_the_fight_is_local()
	_an_atomic_attack_in_a_fight_lands_on_its_own_turn()
	_two_processes_agree()
	_the_world_carries_the_sheet_the_run_played()
	_no_character_in_a_shipped_world_is_nameless()


# --- 1. Five characters, one difference -----------------------------------


## Every character in the run is the same sort of thing, and the decision
## functions on them are the same sort of thing too.
##
## The five are called directly here, with the same two arguments, outside the
## loop entirely: what comes back is an `Action` or nothing, from all five, so
## there is no shape a person's answer has that a program's does not.
func _five_characters_differ_by_one_callable() -> void:
	equal(ScriptedScenario.CAST.size(), CAST_SIZE,
		"the run has %d characters" % CAST_SIZE)

	var scene := ScriptedScenario.stage()
	var loop := ControlLoop.on(scene, ScriptedScenario.LOOP_SEED)
	ScriptedScenario.drive(scene)
	equal(scene.actors.size(), CAST_SIZE, "and all of them are in one scene")

	var sheets := 0
	var answers := PackedStringArray()
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet == null:
			continue
		sheets += 1
		check(sheet.decide.is_valid(), "%s has a decision function" % sheet.character_name)
		var said: Variant = sheet.decide.call(scene, one)
		check(said == null or said is Action,
			"%s answers with an action or with nothing" % sheet.character_name)
		answers.append("%s" % ("-" if said == null else (said as Action).kind))
	equal(sheets, CAST_SIZE, "every one of them carries the same sort of sheet")
	equal(answers.size(), CAST_SIZE, "and every one of them answered")

	# The loop reads the function off the sheet and has nothing to branch on: the
	# five are one type, and swapping any two of them is assignment.
	var wren := _named(scene, ScriptedScenario.WREN)
	var odo := _named(scene, ScriptedScenario.ODO)
	var person := _sheet(wren).decide
	var program := _sheet(odo).decide
	_sheet(wren).decide = program
	_sheet(odo).decide = person
	check(_sheet(wren).decide.is_valid() and _sheet(odo).decide.is_valid(),
		"a person's function and a program's are interchangeable by assignment")
	ScriptedScenario.release(scene)


# --- 2. A person's turns --------------------------------------------------


## Wren's written-down list is carried out in the order it was written, and every
## entry of it is in the journal as an action that finished.
func _a_persons_turns_are_taken_in_order() -> void:
	var scene := ScriptedScenario.stage()
	var loop := ControlLoop.on(scene, ScriptedScenario.LOOP_SEED)
	var wanted := ScriptedScenario.wren_choices(scene)
	ScriptedScenario.drive(scene)
	var wren := _named(scene, ScriptedScenario.WREN)
	_play(scene, loop, ScriptedScenario.TICKS)

	equal(loop.actions_of(wren.id), wanted.size(),
		"every one of the person's %d written-down turns was resolved" % wanted.size())

	var taken := _finished_lines(loop.journal, ScriptedScenario.WREN)
	equal(taken.size(), wanted.size(), "and the journal holds one finished line each")
	var out_of_order := PackedStringArray()
	for index in mini(taken.size(), wanted.size()):
		var chosen: Action = wanted[index]
		if not taken[index].contains(chosen.line()):
			out_of_order.append("%d: wanted %s, got %s" % [
				index, chosen.line(), taken[index]])
	equal(out_of_order, PackedStringArray(),
		"and they were taken in the order they were written down")
	ScriptedScenario.release(scene)


# --- 3. A plan survives being asked, a queue does not ---------------------


## The measurement `DecisionSource.plan` exists because of, and the number that
## says it is closed.
##
## Ten choices are written down. Under `ControlLoop` a decision function is asked
## again every `ControlLoop.REVIEW_EVERY` ticks to find out whether the character
## has changed its mind, and that is where the two readings of one list part
## company: a queue answers the question with its next entry and the entry is
## gone, while a plan is read at the index of how many turns the character has
## actually had carried out and cannot be spent by a question.
##
## Both runs are played here and each is counted two ways -- what the loop
## resolved, and what the source will still hand over once the run is done. Ten
## were written down, so for a list that survives being asked the two add up to
## ten.
func _a_plan_is_not_drained_by_being_asked() -> void:
	var as_a_plan := _the_ten_choices_read(AS_A_PLAN)
	var as_a_queue := _the_ten_choices_read(AS_A_QUEUE)
	var written_down := int(as_a_plan["written"])
	equal(written_down, int(as_a_queue["written"]), "the same list is read both ways")

	equal(int(as_a_plan["resolved"]), written_down,
		"as a plan, all %d written-down turns are resolved" % written_down)
	equal(int(as_a_plan["resolved"]) + int(as_a_plan["left"]), written_down,
		"and the two readings agree: %d resolved + %d still in the source = %d written down"
		% [int(as_a_plan["resolved"]), int(as_a_plan["left"]), written_down])
	equal(int(as_a_plan["by_the_world"]), int(as_a_plan["resolved"]),
		"and the world's count of what it carried out is the loop's count of it")

	check(int(as_a_queue["resolved"]) < written_down,
		"as a queue, only %d of the %d are, because the rest were spent answering"
		% [int(as_a_queue["resolved"]), written_down] + " re-evaluations")
	check(int(as_a_queue["resolved"]) + int(as_a_queue["left"]) < written_down,
		"and the two readings do not agree: %d resolved + %d still in the source = %d, not %d"
		% [int(as_a_queue["resolved"]), int(as_a_queue["left"]),
			int(as_a_queue["resolved"]) + int(as_a_queue["left"]), written_down])
	for how in [as_a_plan, as_a_queue]:
		check(int(how["reviews"]) > 0,
			"and the run really does re-evaluate: %d times" % int(how["reviews"]))


# One whole run with Wren's ten choices on one shape of decision function, read
# both ways afterwards: how many turns the loop resolved, and how many entries
# the source will still hand over. Draining is capped at the number written down,
# because a plan that still had entries in it would offer the same one for ever.
func _the_ten_choices_read(shape: String) -> Dictionary:
	var scene := ScriptedScenario.stage()
	var loop := ControlLoop.on(scene, ScriptedScenario.LOOP_SEED)
	ScriptedScenario.drive(scene)
	var wren := _named(scene, ScriptedScenario.WREN)
	var choices := ScriptedScenario.wren_choices(scene)
	if shape == AS_A_QUEUE:
		_sheet(wren).decide = DecisionSource.recorded(choices)
	_play(scene, loop, ScriptedScenario.TICKS)

	var source: Callable = _sheet(wren).decide
	var left := 0
	while left <= choices.size() and source.call(scene, wren) != null:
		left += 1
	var read := {
		"written": choices.size(),
		"resolved": loop.actions_of(wren.id),
		"by_the_world": scene.actions_of(wren.id),
		"left": left,
		"reviews": int(loop.counts()["reviews"]),
	}
	ScriptedScenario.release(scene)
	return read


# --- 4. The beats ---------------------------------------------------------


## Movement, speech, a pick-up and a trade, each read off the run rather than off
## the story: the journal for what was done, and the two inventories for what the
## trade moved.
func _every_beat_of_the_run_happens() -> void:
	var run := _one_run()
	var scene: ActionScene = run["scene"]
	var journal: PackedStringArray = run["loop"].journal

	check(_finished_ok(journal, "go_to(") >= 3,
		"somebody walked somewhere, %d times" % _finished_ok(journal, "go_to("))
	check(_finished_ok(journal, "say(text=good morning target=") == 1,
		"a word was spoken to somebody by name")
	check(_finished_ok(journal, "say(text=what will it be?") == 1,
		"and answered")
	equal(_count(journal, "interrupted (spoken to)"), 2,
		"and each of the two opened a conversation, which the other broke off for")
	check(_finished_ok(journal, "shout=true") >= 1,
		"something was shouted to everyone in earshot")
	equal(_finished_ok(journal, "pick_up(item=%s)" % ScriptedScenario.LANTERN), 1,
		"the lantern was picked up off the stall")

	var wren := _named(scene, ScriptedScenario.WREN)
	var rook := _named(scene, ScriptedScenario.ROOK)
	var wren_pack := ActionScene.inventory_of(wren)
	var rook_pack := ActionScene.inventory_of(rook)
	equal(_finished_ok(journal, "trade_accept("), 1, "and the offer was accepted once")
	equal(wren_pack.money, ScriptedScenario.WREN_MONEY - ScriptedScenario.CLOAK_PRICE,
		"the buyer paid %d of its %d" % [
			ScriptedScenario.CLOAK_PRICE, ScriptedScenario.WREN_MONEY])
	equal(rook_pack.money, ScriptedScenario.ROOK_MONEY + ScriptedScenario.CLOAK_PRICE,
		"and the seller was paid it, so the money moved and did not appear")
	check(_carries(wren_pack, ScriptedScenario.CLOAK),
		"the buyer carries the cloak")
	check(not _carries(rook_pack, ScriptedScenario.CLOAK),
		"and the seller does not, so the item moved in the same exchange")
	check(_carries(wren_pack, ScriptedScenario.LANTERN),
		"and the buyer still carries what it picked up")
	ScriptedScenario.release(scene)


# --- 5. On the board and off it -------------------------------------------


## The fight begins under the two who met, is played to a decision, and gives the
## survivor back to the world at the position of its own last cell.
func _the_fight_snaps_on_and_comes_back_off() -> void:
	var run := _one_run()
	var scene: ActionScene = run["scene"]
	var phases: Array = run["phases"]

	var fighting_from := -1
	var quiet_after := -1
	for row in phases:
		if fighting_from < 0 and bool(row["fighting"]):
			fighting_from = int(row["tick"])
		elif fighting_from >= 0 and quiet_after < 0 and not bool(row["fighting"]):
			quiet_after = int(row["tick"])
	check(fighting_from > 0, "the world falls into a fight, at tick %d" % fighting_from)
	check(quiet_after > fighting_from,
		"and is back in real time afterwards, at tick %d" % quiet_after)

	var written: PackedStringArray = run["fight"]
	check(_count(written, "snap-in around") == 1, "the board appeared once")
	check(_count(written, "ending=decided") == 1,
		"the match was played to a decision rather than stopped at the round limit")
	check(_count(written, "snap-out") == 2, "and both who joined were answered for")

	# Whoever is left is standing in the world, not on a lattice, and is standing
	# at the position its own last cell converts to.
	var standing := 0
	for one in scene.actors:
		check(not one.fighting, "%s is not on a board afterwards" % ActionScene.name_of(one))
		standing += 1
	equal(standing, ScriptedScenario.CAST.size() - 1,
		"one of the five fell, and the other four are still in the world")
	ScriptedScenario.release(scene)


# --- 6. Locality ----------------------------------------------------------


## The three who were not near the quarrel never joined it, and never stopped
## acting while it was on.
func _the_fight_is_local() -> void:
	var run := _one_run()
	var scene: ActionScene = run["scene"]
	var loop: ControlLoop = run["loop"]
	var phases: Array = run["phases"]
	equal(_count(run["fight"], "joined=2"), 1, "two of the five joined the fight")

	var fighting_ticks := PackedInt32Array()
	for row in phases:
		if bool(row["fighting"]):
			fighting_ticks.append(int(row["tick"]))
	check(fighting_ticks.size() >= 4,
		"the fight was on for %d ticks" % fighting_ticks.size())

	for who in [ScriptedScenario.WREN, ScriptedScenario.ROOK, ScriptedScenario.ODO]:
		var one := _named(scene, who)
		check(one != null, "%s came through the run" % who)
		check(not bool(run["ever_fought"].get(who, false)),
			"%s was never on the board" % who)
		check(loop.ticks_of(one.id) == scene.tick,
			"and was serviced on every one of the %d ticks, fight or no fight"
			% scene.tick)

	# The market's own beats land while the fight is on, which is the whole of
	# "the world does not stop for a fight" said as a number.
	var during := 0
	for line in loop.journal:
		var at := int(line.substr(2, 3).strip_edges())
		if fighting_ticks.has(at) and not line.contains("Bram") and not line.contains("Sable"):
			during += 1
	check(during > 0,
		"%d things happened elsewhere in the world while the fight was on" % during)
	ScriptedScenario.release(scene)


# --- 7. The atomic attack and the turn economy -----------------------------


## An `attack` chosen through the atomic surface during this fight is carried
## out, and it is carried out on the turn that spends it.
##
## An attack occupies `ActionCatalog.occupies_of(ATTACK)` ticks and a turn used
## to last one, so every blow either of these two chose was abandoned before it
## landed and `CombatPolicy` fought the whole quarrel by itself. A turn now lasts
## as long as the weapon action that spends it, so the span runs to its end on
## its own turn and the blow lands. Both numbers are read rather than typed --
## the cost off the catalogue, what happened off the transcript.
##
## The strongest half of this is the last check: every weapon action the match
## resolved was one somebody chose. On the behaviour this replaces those two
## counts were many and zero.
func _an_atomic_attack_in_a_fight_lands_on_its_own_turn() -> void:
	var run := _one_run()
	var journal: PackedStringArray = run["loop"].journal
	var costs := ActionCatalog.occupies_of(ActionCatalog.ATTACK)
	check(costs > 1, "an attack occupies %d ticks" % costs)

	var begun := _count(journal, "began attack(")
	check(begun >= 4, "the two who fought chose to strike %d times" % begun)
	equal(_count(journal, "interrupted (attacked), abandoned attack("), 0,
		"and none of those was abandoned because the next blow landed on it")

	var landed := 0
	var struck_by := {}
	for line in journal:
		if line.contains("finished attack(") and line.contains("-> attack ok"):
			landed += 1
			for who in [ScriptedScenario.BRAM, ScriptedScenario.SABLE]:
				if line.contains(" %s " % who):
					struck_by[who] = int(struck_by.get(who, 0)) + 1
	check(landed >= 4,
		"%d blows chosen through the action surface were carried out" % landed)
	equal(struck_by.size(), 2, "and both of the two who fought landed one")

	# Every weapon action the match resolved was a blow somebody chose. The match
	# writes one `attack #N` line per weapon action, whoever asked for it.
	var resolved := 0
	for line in run["fight"]:
		if line.strip_edges().begins_with("attack #"):
			resolved += 1
	equal(resolved, landed,
		"and the match resolved %d weapon actions, all of them chosen" % resolved)

	var blows := PackedInt32Array()
	for line in run["fight"]:
		if line.contains("hit #"):
			blows.append(blows.size())
	check(blows.size() >= 4, "%d blows landed in the fight" % blows.size())
	ScriptedScenario.release(run["scene"])


# --- 8. Two processes, and the transcript on disk --------------------------


## The documented command run twice, in two processes, printing the same bytes --
## and the transcript checked in under reports/ being those bytes.
func _two_processes_agree() -> void:
	var first := _run_scenario()
	var second := _run_scenario()
	equal(first["code"], 0, "./run_scenario.sh exits 0")
	equal(second["code"], 0, "and again")
	equal(first["text"], second["text"],
		"two runs of ./run_scenario.sh printed different bytes")
	check(first["text"].contains("the fight is over; real time again"),
		"and the transcript is the scenario's")

	var kept := FileAccess.get_file_as_string(TRANSCRIPT)
	check(kept != "", "the transcript is checked in at %s" % TRANSCRIPT)
	equal(kept.strip_edges(), String(first["text"]).strip_edges(),
		"and the checked-in transcript is what the command prints")


# --- 9. The sheet crosses into the world ----------------------------------


## A character read out of the world after `ScriptedScenario.muster` carries what
## its scene character carried.
##
## Read off the *world's roster* and compared with a separate playing of the same
## run: two different objects on two sides of the copy, so agreeing on every
## field is a real comparison and not a handle being read twice. What is carried
## and what is worn go through `Inventory.fingerprint()`, which sorts what is
## carried and lists the worn slots in slot order, so "the same things and the
## same money" is one string on both sides.
##
## Before this, `muster` put a fresh `Character.make(name, level)` on the
## commander, and the name and the level were the only two things that survived
## the crossing.
func _the_world_carries_the_sheet_the_run_played() -> void:
	var played := ScriptedScenario.played_to(
		ScriptedScenario.MARKET_FRAME, ScriptedScenario.SEED)
	var sim := Simulation.new(ScriptedScenario.SEED)
	# The frozen frame, by name: it is the muster that plays the run headless and
	# adopts the sheets that run finished with, and so it is the one this claim
	# is about. Set out live, the same cast starts where the run starts and has
	# not traded anything yet.
	check(sim.begin_scenario(Simulation.SCENARIO_MARKET, true),
		"the market scenario could not be photographed")

	var stood := _sheets_in(sim.world)
	equal(stood.size(), played.actors.size(),
		"the world holds a different number of characters than the run left standing")

	var compared := 0
	for one in played.actors:
		var was := _sheet(one)
		if was == null:
			continue
		var now := _sheet_called(stood, was.character_name)
		check(now != null,
			"%s is in the run but not in the world after the muster" % was.character_name)
		if now == null:
			continue
		compared += 1
		check(now != was,
			"the world and the run are holding one object, so nothing was compared")
		not_equal(now.character_name, "",
			"%s stands in the world with no name" % was.character_name)
		equal(now.level, was.level,
			"%s arrived in the world at another level" % was.character_name)
		equal(now.status(), was.status(),
			"%s arrived with another standing" % was.character_name)
		equal(now.health, was.health,
			"%s arrived on other hit points than the run left it on" % was.character_name)
		equal(now.scores_line(), was.scores_line(),
			"%s arrived with other ability scores" % was.character_name)
		equal(now.inventory.money, was.inventory.money,
			"%s arrived with other money" % was.character_name)
		equal(now.inventory.size(), was.inventory.size(),
			"%s arrived carrying a different number of things" % was.character_name)
		equal(_equipment_line(now), _equipment_line(was),
			"%s arrived wearing something else" % was.character_name)
		equal(now.inventory.fingerprint(), was.inventory.fingerprint(),
			"%s arrived with another inventory" % was.character_name)
	equal(compared, CAST_SIZE,
		"only %d of the %d characters were compared" % [compared, CAST_SIZE])

	# The four things the crossing used to drop, named one at a time off the
	# world's roster, so the claim is about this run and not about any two sheets
	# that happen to match: the money Wren has left after buying the cloak, the
	# lantern taken off the stall, the cloak itself, and Bram's sword in its hand.
	var wren := _sheet_called(stood, ScriptedScenario.WREN)
	check(wren != null and wren.inventory.money > 0,
		"Wren stands in the world with no money")
	check(wren != null and _carries(wren.inventory, ScriptedScenario.LANTERN),
		"the lantern Wren picked up did not cross into the world")
	check(wren != null and _carries(wren.inventory, ScriptedScenario.CLOAK),
		"the cloak Wren bought did not cross into the world")
	var bram := _sheet_called(stood, ScriptedScenario.BRAM)
	check(bram != null and not bram.equipment.is_empty(),
		"Bram stands in the world wearing and holding nothing")


# --- 10. Nobody in a shipped world is nameless ----------------------------


## No character reachable from a shipped scenario's world has an empty name, and
## none of them has an unrecorded ability score.
##
## Every scenario `Simulation` will set out, not just the two this file is
## about -- the encounter musters characters of its own, and a nameless commander
## there is the same blank on the same sheet.
func _no_character_in_a_shipped_world_is_nameless() -> void:
	var found := 0
	var nameless := 0
	var unrolled := 0
	for named in Simulation.SCENARIOS:
		var sim := Simulation.new(ScriptedScenario.SEED)
		check(sim.begin_scenario(named),
			"the %s scenario could not be set out" % named)
		var sheets := _sheets_in(sim.world)
		check(sheets.size() > 0,
			"the %s scenario put no character in the world" % named)
		for sheet in sheets:
			found += 1
			if sheet.character_name == "":
				nameless += 1
			for ability in Ability.ALL:
				if not sheet.has_score(ability):
					unrolled += 1
	check(found > 0, "no shipped scenario put a character into a world at all")
	equal(nameless, 0,
		"characters stand in a shipped scenario's world with no name")
	equal(unrolled, 0,
		"ability scores stand unrecorded on a shipped scenario's characters")

	# And the two questions have teeth: asked of a sheet nobody has named or
	# rolled, both answer the other way.
	var bare := Character.make("", 1)
	equal(bare.character_name, "",
		"a fresh sheet has a name, so the name check above tests nothing")
	var missing := 0
	for ability in Ability.ALL:
		if not bare.has_score(ability):
			missing += 1
	equal(missing, Ability.ALL.size(),
		"a fresh sheet is rolled, so the score check above tests nothing")


# --- The run, and reading it ----------------------------------------------


# One whole run, played here rather than in a subprocess, with the three things
# the checks read off it: the scene at the end, the loop, and one row per tick
# saying whether a fight was on.
func _one_run() -> Dictionary:
	var scene := ScriptedScenario.stage()
	var loop := ControlLoop.on(scene, ScriptedScenario.LOOP_SEED)
	ScriptedScenario.drive(scene)
	var phases := []
	var fight := PackedStringArray()
	var ever_fought := {}
	for _step in ScriptedScenario.TICKS:
		loop.step()
		fight.append_array(ScriptedScenario._fight_step(scene))
		for one in scene.actors:
			if one.fighting:
				ever_fought[ActionScene.name_of(one)] = true
		phases.append({"tick": scene.tick, "fighting": scene.fight != null})
	return {
		"scene": scene, "loop": loop, "phases": phases,
		"fight": fight, "ever_fought": ever_fought,
	}


# Play a scene that has already been staged and driven.
func _play(scene: ActionScene, loop: ControlLoop, ticks: int) -> void:
	for _step in ticks:
		loop.step()
		ScriptedScenario._fight_step(scene)


func _run_scenario() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path(COMMAND), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


# --- Reading a journal ----------------------------------------------------


static func _count(lines: PackedStringArray, phrase: String) -> int:
	var found := 0
	for line in lines:
		if line.contains(phrase):
			found += 1
	return found


# How many actions of a shape finished without being refused.
static func _finished_ok(journal: PackedStringArray, phrase: String) -> int:
	var found := 0
	for line in journal:
		if line.contains("finished ") and line.contains(phrase) \
				and not line.contains("refused"):
			found += 1
	return found


# Every finished line about one character, in order.
static func _finished_lines(journal: PackedStringArray, who: String) -> PackedStringArray:
	var found := PackedStringArray()
	for line in journal:
		if line.contains(" %s " % who) and line.contains("finished "):
			found.append(line)
	return found


static func _carries(pack: Inventory, called: String) -> bool:
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == called:
			return true
	return false


# Every character sheet a world is holding, read off the roster: the commanders
# among its members, and the `Character` each of them is.
static func _sheets_in(world: SimWorld) -> Array[Character]:
	var found: Array[Character] = []
	for one in world.combat.members:
		if one.piece is Commander:
			found.append((one.piece as Commander).sheet)
	return found


static func _sheet_called(sheets: Array[Character], who: String) -> Character:
	for sheet in sheets:
		if sheet.character_name == who:
			return sheet
	return null


# What a sheet has on, in slot order, as one comparable string.
static func _equipment_line(sheet: Character) -> String:
	var slots := PackedStringArray()
	for slot in Inventory.SLOT_ORDER:
		if sheet.equipment.has(slot):
			slots.append("%s=%s" % [
				slot, Inventory.entry_line(sheet.equipment[slot]),
			])
	return " ".join(slots)


static func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == who:
			return one
	return null


static func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
