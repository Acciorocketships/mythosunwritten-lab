extends TestSuite
## A person is one of the minds: the live decision function, and what the
## overworld controls put into it.
##
## Before this the world had four ways for a character's next action to be
## chosen and every one of them was decided before the run started -- a written
## list, a rule, or a model's answer to a prompt. A person is none of those: they
## answer while the world is running, at a moment nobody can write down in
## advance. `DecisionSource.live` is that decision function and `LiveChoice` is
## where the answer is put when it arrives.
##
## Seven claims:
##
##   1. **The live one is one of the four, not a fifth kind of thing.** Same
##      `(scene, actor) -> Action` signature as `recorded`, `plan`, `scripted`
##      and `model`, and null while nothing has been chosen -- the same null a
##      model mind returns while its call is outstanding.
##   2. **It names no key, no device, no viewport and nothing under render/.**
##      Checked over the source of both files with the comments taken off, so
##      prose about a person pressing something is not read as code that knows
##      about keys.
##   3. **The world does not block on it.** A world whose followed character is
##      a person's, and nobody at the keys: it waits, everybody else acts, and
##      the ticks keep coming.
##   4. **A choice is taken once and being asked spends nothing.** The same
##      answer comes back for as long as the world has not resolved one, and it
##      is taken back the moment it has -- `plan`'s reading, over one entry.
##   5. **Every control goes through the action catalogue.** Everything
##      `PlayerControls` can build is a `go to` or a `jump` the catalogue
##      accepts, and there are no other verbs in it.
##   6. **A refusal comes back in the engine's own words.** A leap past what DEX
##      reaches is refused with `ActionEngine`'s own sentence, and the panel puts
##      that sentence on screen rather than one written for the interface.
##   7. **The person's character is drawn and animated like everybody else.** It
##      is a row of the same diorama, wearing a model, and the clip it plays
##      follows what the world says it is doing.
class_name TestPlayerInput

## The seed every claim here is played on: the world the headless run reports,
## and the one the shell is photographed on.
const SEED := 1234

## Long enough for the other two characters to choose a leg, walk it and be
## asked again -- a leg costs 20 ticks -- so "everybody else carried on" is
## measured over more than one action each.
const WAIT_TICKS := 60

## Long enough for one choice to be committed and carried out: a walk costs 20
## ticks and is committed on the tick after it is made.
const CARRY_TICKS := 30

## Long enough for a jump, which costs 4.
const JUMP_TICKS := 12

## What a live decision function and the file it reads may not name. Keys,
## devices, screens and the render layer: the whole vocabulary of how a choice
## arrives, none of which the simulation may hold.
const FORBIDDEN := [
	"KEY_", "Input", "InputEvent", "keycode", "keyboard", "mouse", "button",
	"Viewport", "get_viewport", "screen", "res://render", "render/",
]

## The two files that claim to hold none of it.
const LIVE_FILES := ["res://sim/decision_source.gd", "res://sim/live_choice.gd"]


func _init() -> void:
	suite_name = "player input"


func run() -> void:
	_the_live_one_has_the_same_shape_and_answers_null()
	_the_live_one_names_no_key_and_no_screen()
	_the_world_does_not_block_on_a_person()
	_a_choice_is_taken_once_and_asking_spends_nothing()
	_every_control_is_an_action_the_catalogue_already_offers()
	_a_refusal_comes_back_in_the_engines_own_words()
	_the_person_is_drawn_and_animated_like_everybody_else()


# --- 1: one of the four ---------------------------------------------------


func _the_live_one_has_the_same_shape_and_answers_null() -> void:
	var choice := LiveChoice.new()
	var live := DecisionSource.live(choice)
	var written := DecisionSource.plan([Action.wait(1)])
	var rule := DecisionSource.scripted(
		func(_s: ActionScene, _a: Combatant) -> Action: return Action.wait(1))
	equal(live.get_argument_count(), written.get_argument_count(),
		"the live decision function should take what a written-down plan takes")
	equal(live.get_argument_count(), rule.get_argument_count(),
		"the live decision function should take what a rule takes")

	var world := SimWorld.new(SEED)
	var driven := world.followed()
	check(driven != null, "the world should be looking through somebody")
	if driven == null:
		return
	equal(live.call(world.combat.scene, driven), null,
		"a person who has chosen nothing should answer nothing")

	# And handing a character over puts exactly this on its sheet, changing
	# nothing else about it.
	var was_name := _sheet_of(driven).character_name
	var was_level := driven.piece.level
	var handed := WorldCast.hand_over(world, world.follow_id)
	check(handed != null, "handing the followed character over should give a holder")
	equal(_sheet_of(driven).character_name, was_name,
		"handing a character over should not rename it")
	equal(driven.piece.level, was_level,
		"handing a character over should not change what it is")
	check(_sheet_of(driven).decide.is_valid(),
		"a character handed over should still have a decision function")
	equal(_sheet_of(driven).decide.call(world.combat.scene, driven), null,
		"a character handed over and not driven should answer nothing")


# --- 2: it names none of the ways a choice arrives ------------------------


func _the_live_one_names_no_key_and_no_screen() -> void:
	for path in LIVE_FILES:
		var code := _code_of(path)
		check(code != "", "could not read %s" % path)
		for word in FORBIDDEN:
			check(not code.contains(word),
				"%s names '%s', which is how a choice arrives and not what it is"
					% [path, word])


# --- 3: the world does not block ------------------------------------------


func _the_world_does_not_block_on_a_person() -> void:
	var world := SimWorld.new(SEED)
	var id := world.follow_id
	var choice := WorldCast.hand_over(world, id)
	check(choice != null, "there should have been somebody to hand over")
	for _step in WAIT_TICKS:
		world.step()

	equal(world.tick, WAIT_TICKS,
		"the world should keep ticking while nobody has chosen anything")
	equal(world.loop.actions_of(id), 0,
		"a character nobody has driven should have had nothing carried out")
	check(world.loop.is_thinking(id),
		"a character nobody has driven should read as still deciding")
	equal(choice.made, 0, "nobody chose anything, so nothing should be recorded")

	var elsewhere := 0
	for one in world.combat.members:
		if one.id != id:
			elsewhere += world.loop.actions_of(one.id)
	check(elsewhere > 0,
		"the rest of the cast should have acted while the person waited")

	# And the journal says both things, at ticks inside the wait: the person
	# waiting in the world, and somebody else beginning something.
	var waited := false
	var acted := false
	for line in world.loop.journal:
		if line.contains("has not decided yet, and waits in the world"):
			waited = true
		elif line.contains("began "):
			acted = true
	check(waited, "the journal should say the person waits in the world")
	check(acted, "the journal should say somebody else began something")


# --- 4: taken once, and asking spends nothing -----------------------------


func _a_choice_is_taken_once_and_asking_spends_nothing() -> void:
	var world := SimWorld.new(SEED)
	var id := world.follow_id
	var choice := WorldCast.hand_over(world, id)
	world.step()
	var driven := world.followed()
	var sheet := _sheet_of(driven)

	# Asked three times before anything is resolved: the same action back each
	# time, and still standing.
	var wanted := Action.go_to(Vector2(driven.x + 4.0, driven.z))
	choice.choose(wanted)
	var asked := []
	for _again in 3:
		asked.append(sheet.decide.call(world.combat.scene, driven))
	for answer in asked:
		equal(answer, wanted, "being asked again should give the same answer back")
	check(not choice.waiting(),
		"being asked should not have spent the choice")

	for _step in CARRY_TICKS:
		world.step()
	equal(world.loop.actions_of(id), 1,
		"one choice should have become one action carried out")
	equal(choice.carried_out, 1, "the holder should say the choice was had")
	check(choice.waiting(),
		"once the choice was carried out the person should be asked again")
	check(choice.offered > 1,
		"the choice should have been offered more than once and spent once")

	# And with nothing more chosen, the character goes back to waiting rather
	# than repeating what it last did.
	for _step in CARRY_TICKS:
		world.step()
	equal(world.loop.actions_of(id), 1,
		"a person who chose once should have acted once")


# --- 5: every control is a catalogue action -------------------------------


func _every_control_is_an_action_the_catalogue_already_offers() -> void:
	var here := Vector2(10.0, -4.0)
	var made := []
	for keycode in PlayerControls.WALK_KEYS:
		made.append(PlayerControls.walk_from(
			here, PlayerControls.direction_of(keycode)))
	made.append(PlayerControls.jump_from(
		here, PlayerControls.FACING_AT_REST, PlayerControls.HOP))
	made.append(PlayerControls.jump_from(
		here, PlayerControls.FACING_AT_REST, PlayerControls.LEAP))
	made.append(PlayerControls.go_to_place({"x": 40.0, "z": 12.0}))

	var allowed := [ActionCatalog.GO_TO, ActionCatalog.JUMP]
	for chosen in made:
		check(ActionCatalog.names().has(chosen.kind),
			"the controls built '%s', which the catalogue does not list" % chosen.kind)
		check(allowed.has(chosen.kind),
			"the controls built '%s', and this item is movement only" % chosen.kind)
		equal(ActionCatalog.fault(chosen), "",
			"the controls built an action the catalogue refuses: %s" % chosen.line())

	# A walk key carries exactly one step, and a hop exactly a hop.
	var north := PlayerControls.walk_from(here, PlayerControls.FACING_AT_REST)
	equal(snappedf(here.distance_to(north.target_position()), 0.001),
		snappedf(PlayerControls.STEP, 0.001),
		"a walk key should send the character one step")
	var hop := PlayerControls.jump_from(
		here, PlayerControls.FACING_AT_REST, PlayerControls.HOP)
	equal(snappedf(here.distance_to(hop.target_position()), 0.001),
		snappedf(PlayerControls.HOP, 0.001), "a hop should be a hop long")

	# And the two jumps sit either side of what an ordinary character reaches,
	# which is what makes the refusal something a person can provoke.
	var reach := ActionEngine.JUMP_BASE \
		+ ActionEngine.JUMP_PER_DEX * int(WorldCast.ROLL[Ability.DEX])
	check(PlayerControls.HOP <= reach,
		"a hop should be inside what the ordinary cast's DEX reaches")
	check(PlayerControls.LEAP > reach,
		"a leap should be outside it, so the engine's refusal can be shown")


# --- 6: the engine's own words --------------------------------------------


func _a_refusal_comes_back_in_the_engines_own_words() -> void:
	var world := SimWorld.new(SEED)
	var id := world.follow_id
	var choice := WorldCast.hand_over(world, id)
	world.step()
	var driven := world.followed()
	var here := Vector2(driven.x, driven.z)
	choice.choose(PlayerControls.jump_from(
		here, PlayerControls.FACING_AT_REST, PlayerControls.LEAP))
	for _step in JUMP_TICKS:
		world.step()

	var answer := world.loop.answer_of(id)
	check(not answer.is_empty(), "the engine should have answered the leap")
	if answer.is_empty():
		return
	check(not bool(answer["ok"]), "a leap past DEX should have been refused")

	# The sentence, rebuilt here out of the engine's own constants and its own
	# format: what the loop wrote down is the resolver's wording and not a second
	# sentence about the same thing.
	var dex := _sheet_of(driven).score(Ability.DEX, 0)
	var reach := ActionEngine.JUMP_BASE + ActionEngine.JUMP_PER_DEX * dex
	equal(String(answer["reason"]),
		"%.2f is further than DEX %d jumps (%.2f)" % [PlayerControls.LEAP, dex, reach],
		"the refusal should be the engine's own sentence")

	# And what goes on screen is that sentence, carried through unchanged.
	if not SproutPack.is_installed():
		return
	var panel := AnswerPanel.new()
	panel.watch(world, id, choice)
	panel.refresh()
	equal(panel._answer_label.text, String(answer["line"]),
		"the panel should quote the engine rather than phrase its own refusal")
	check(panel._answer_label.text.contains(String(answer["reason"])),
		"the reason should reach the screen whole")


# --- 7: drawn and animated like everybody else ----------------------------


func _the_person_is_drawn_and_animated_like_everybody_else() -> void:
	var world := SimWorld.new(SEED)
	var id := world.follow_id
	var choice := WorldCast.hand_over(world, id)
	world.step()

	# Waiting: a row of the same diorama, wearing a model, standing still.
	var resting := _row_for(world, id)
	check(not resting.is_empty(), "the person's character should be drawn")
	if resting.is_empty():
		return
	check(bool(resting["commander"]), "it should be drawn as a commander")
	not_equal(String(resting["tag"]), "", "it should be wearing a model")
	equal(CharacterView.clip_for(resting["state"]), CharacterView.CLIP_IDLE,
		"a character waiting for its person should be standing still")

	# The same row every other character gets: same keys, same shape.
	var others := 0
	for row in CombatDiorama.placements(world.snapshot()):
		if int(row["id"]) == id:
			continue
		others += 1
		equal((row["state"] as Dictionary).keys(),
			(resting["state"] as Dictionary).keys(),
			"the person's character should be described exactly as the rest are")
	check(others > 0, "there should be somebody else in the world to compare with")

	# Walking: the tick the walk is carried out, the clip is a walk or a run.
	var driven := world.followed()
	choice.choose(Action.go_to(Vector2(driven.x + 6.0, driven.z)))
	var moving := ""
	for _step in CARRY_TICKS:
		world.step()
		var row := _row_for(world, id)
		if float((row["state"] as Dictionary)["speed"]) > CharacterView.WALK_SPEED:
			moving = CharacterView.clip_for(row["state"])
			break
	check(moving == CharacterView.CLIP_WALK or moving == CharacterView.CLIP_RUN,
		"a character the world moved should not be standing still, got '%s'" % moving)

	# Jumping: the tick a jump is carried out, the clip is the jump.
	var leapt := false
	for way in [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)]:
		var standing := world.followed()
		choice.choose(PlayerControls.jump_from(
			Vector2(standing.x, standing.z), way, PlayerControls.HOP))
		for _step in JUMP_TICKS:
			world.step()
			var row := _row_for(world, id)
			if bool((row["state"] as Dictionary)["jumped"]):
				leapt = true
				equal(CharacterView.clip_for(row["state"]), CharacterView.CLIP_JUMP,
					"a character the world jumped should be playing the jump")
				break
		if leapt:
			break
	check(leapt, "none of the four hops was allowed, so the jump was never drawn")


# --- The furniture --------------------------------------------------------


func _row_for(world: SimWorld, id: int) -> Dictionary:
	for row in CombatDiorama.placements(world.snapshot()):
		if int(row["id"]) == id:
			return row
	return {}


func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


## A file's source with the comments taken off, so that prose discussing a key
## is not read as code naming one. String literals are kept, for the reason
## `LayerCheck` keeps them: a name smuggled into a string is still a name.
func _code_of(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return ""
	var kept := PackedStringArray()
	for line in text.split("\n"):
		var at := line.find("#")
		kept.append(line if at < 0 else line.substr(0, at))
	return "\n".join(kept)
