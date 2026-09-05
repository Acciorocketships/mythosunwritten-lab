extends TestSuite
## The difficulty-class agent: a check raised by the world, judged by a model,
## rolled by the engine, and remembered so it is not rolled twice.
##
## Every check in this file runs with no key, no network and no model, for the
## reason `tests/test_agent.gd` gives: the model layer is built so that a written
## reply stands in for a live call everywhere except the one command that makes
## the recording, and a suite that needed a credential would be evidence that it
## is not.
##
## Seven claims:
##
##   1. **Hook-triggered and one-off, not polled.** A check is raised in exactly
##      one place in the whole simulation -- `AbilityCheck.HOOK`, read off the
##      source -- and only for one situation there: an item the character carries
##      that is not what the thing plainly opens with. Bare hands and the right
##      item raise none. A world nobody attempts anything in raises none however
##      long it is stepped, and costs no call.
##   2. **The agent picks both, and the engine does the arithmetic.** The class
##      and the ability score come out of the reply; the score comes off the
##      character's own sheet, the die out of a seeded stream, and the verdict out
##      of `AbilityCheck.beats`. The same reply with a different roll seed gives a
##      different verdict, so the verdict is the engine's.
##   3. **A reply that claims the world changed changes nothing.** Prose in a
##      judging answer saying the chest flew open leaves it shut; only a passed
##      roll and a resolving operation open it.
##   4. **The second call is a different system prompt, and what it may change is
##      a table the engine owns.** The two prompts differ; only the resolving one
##      names the operations; every one of the four does what the table says and
##      refuses when it does not apply; a line that is not one of them changes
##      nothing; more than `CheckEffects.AT_MOST` of them has the rest refused.
##   5. **The context is stored and reused.** A second attempt of the same shape
##      is settled out of the character's memory: no call, no roll, and the
##      operations carried out again against the thing in front of it now. Shown
##      in the shipped run, whose four checks cost four calls and two rolls --
##      two judgements and the two resolutions they earned, with the other two
##      checks settled out of memory for nothing. How many calls that is depends
##      on how many of the rolls passed, which is a fact about the recorded draw
##      and moves when the recording is re-made.
##   6. **The model never resolves.** The die is drawn in one function, the
##      comparison made in one function, and the world written in one file --
##      read off the source of the whole layer, with the scans shown to have
##      teeth.
##   7. **Two processes agree**, and the checked-in transcript is what the command
##      prints.
class_name TestChecks

## The files that make up the difficulty-class layer.
const RECORD := "res://sim/ability_check.gd"
const EFFECTS := "res://sim/check_effects.gd"
const PROMPTS := "res://sim/check_prompt.gd"
const DESK := "res://sim/check_desk.gd"

## The three that handle a check once it is raised. `sim/scripted_check.gd` is
## deliberately not among them: it is the run that sets a world out, so it puts
## objects into a scene, and scanning it for that would be scanning the wrong
## thing.
const HANDLES_A_CHECK := [RECORD, PROMPTS, DESK]

## The one file allowed to raise a check, and the one allowed to declare how.
const RAISES := "res://sim/action_engine.gd"
const DECLARES_RAISING := "res://sim/action_scene.gd"

## How a line of code draws a die -- by hashing, which is what this layer does, or
## out of a stream, which the combat layer forbids anywhere that names a
## combatant and which is forbidden here for the same reason. Whole calls.
const DRAWS_A_DIE := [
	"hash_ints(", "hash_unit(", "next_int(", "next_u32(", "next_float(",
	"next_range(", "randi", "randf",
]

## How a line of code writes the world. Matched as plain substrings.
const WRITES_THE_WORLD := [
	".shut =", ".x =", ".z =", "add_object(", "remove_object(", "contents.release(",
]

## Lines the scans must catch.
const BROKEN_ROLL := "	var roll := rng.next_int(1, 20)"
const BROKEN_HASH := "	var roll := SimRng.hash_ints(seed_value, id, 0) % 20"
const BROKEN_COMPARE := "	if check.total >= check.difficulty:"
const BROKEN_WRITE := "	thing.shut = false"

## A judging answer whose prose says the world has already changed.
const CLAIMS_IT_WORKED := (
	"dc=24 ability=str\n"
	+ "The bar bites, the lid splinters and the chest flies open, coins everywhere."
)

## The ground the bare scene is staged on, and where the things in it stand --
## each within `ActionEngine.REACH` of the character, so an interaction is not
## refused for distance. It is real terrain rather than a bare stage because an
## observation is assembled over the ground, and the settled check goes into the
## character's memory through a door that takes one.
const WHERE := ScriptedActions.WHERE
const SEED := ScriptedActions.SEED
const ROOK_AT := Vector2(0.0, 0.0)
const THINGS_AT := [Vector2(1.5, 0.0), Vector2(0.0, 1.5)]

## What Rook carries, and what the chest actually opens with.
const BAR := "iron pry bar"
const KEY := "brass key"

## Rook's scores in the bare scene, so the arithmetic in this file is by hand.
const SCORES := {
	Ability.STR: 5, Ability.CON: 4, Ability.CHA: 3,
	Ability.DEX: 4, Ability.WIS: 3, Ability.INT: 2,
}

## The transcript checked in under reports/, and the command that prints it.
const TRANSCRIPT := "res://reports/check-evidence.txt"
const COMMAND := "res://run_check.sh"


func _init() -> void:
	suite_name = "checks"


func run() -> void:
	_one_hook_and_one_situation()
	_a_quiet_world_raises_none()
	_the_agent_picks_both_and_the_engine_rolls()
	_the_die_and_not_the_words_decide()
	_a_claim_of_success_changes_nothing()
	_two_prompts_not_one()
	_every_operation_and_only_those()
	_more_than_the_engine_carries_out()
	_the_context_is_stored_and_reused()
	_the_shipped_run_pays_for_two_of_four()
	_the_die_is_drawn_in_one_place()
	_the_comparison_is_made_in_one_place()
	_the_world_is_written_in_one_place()
	_the_source_scans_would_notice()
	_two_processes_agree()


# --- 1. One hook, one situation ------------------------------------------


## A check is raised in one place in the simulation, and that place is the one
## `AbilityCheck.HOOK` names.
func _one_hook_and_one_situation() -> void:
	var raising := PackedStringArray()
	for path in _files_under("res://sim"):
		if path == DECLARES_RAISING:
			continue
		if _read(path).contains("raise_check("):
			raising.append(path)
	equal(raising, PackedStringArray([RAISES]),
		"a check is raised in more than one place: %s" % " ".join(raising))
	check(AbilityCheck.HOOK.begins_with("ActionEngine."),
		"the named hook is not in the engine: %s" % AbilityCheck.HOOK)
	var named := AbilityCheck.HOOK.substr("ActionEngine.".length())
	check(_read(RAISES).contains("static func %s(" % named),
		"%s names a function %s does not declare" % [AbilityCheck.HOOK, RAISES])

	# And only for one of the three ways an interaction with a shut thing can go.
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var rook: Combatant = world["rook"]
	var chest: WorldObject = world["chest"]
	var bare := ActionEngine.resolve(scene, rook, Action.interact(chest.id))
	check(not bare.ok, "bare hands opened a chest that needs a key")
	equal(scene.raised.size(), 0, "bare hands raised a check")

	var wrong := ActionEngine.resolve(scene, rook, Action.interact(chest.id, BAR))
	check(not wrong.ok, "an item the world has no rule for opened the chest itself")
	equal(scene.raised.size(), 1, "an item the world has no rule for raised no check")
	equal(scene.raised[0].context, "interact:%s:%s" % [chest.object_name, BAR],
		"the raised check does not name the shape of the attempt")
	equal(int(wrong.got("check", 0)), scene.raised[0].id,
		"the refusal does not say which check it raised")

	ActionScene.inventory_of(rook).carry(_tool(KEY))
	var right := ActionEngine.resolve(scene, rook, Action.interact(chest.id, KEY))
	check(right.ok and chest.is_open(), "the right item did not just work: %s" % right.reason)
	equal(scene.raised.size(), 1, "the right item raised a check")


## A world nobody attempts anything in raises no check and costs no call, however
## long it is stepped. This is the difference between a hook and a poll.
func _a_quiet_world_raises_none() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var desk := CheckDesk.with_channel(_channel(["dc=10 ability=str"]), 1)
	for _tick in 200:
		scene.advance(1)
		desk.step(scene)
	equal(scene.raised.size(), 0, "a world nobody touched raised a check")
	equal(desk.calls, 0, "a desk with nothing to do put a question anyway")
	equal(desk.rolls, 0, "a desk with nothing to do rolled anyway")


# --- 2. The agent picks both, the engine does the arithmetic --------------


func _the_agent_picks_both_and_the_engine_rolls() -> void:
	var settled := _one_check(["dc=17 ability=wis", "open target=%d"], 1)
	var check_row: AbilityCheck = settled["check"]
	equal(check_row.said_class, 17, "the class did not come out of the reply")
	equal(check_row.difficulty, 17, "the class the engine used is not the one said")
	equal(check_row.ability, Ability.WIS, "the ability did not come out of the reply")
	equal(check_row.score, int(SCORES[Ability.WIS]),
		"the score did not come off the character's own sheet")
	check(check_row.roll >= 1 and check_row.roll <= AbilityCheck.DIE,
		"the roll is outside 1..%d: %d" % [AbilityCheck.DIE, check_row.roll])
	equal(check_row.total, check_row.score + check_row.roll,
		"the total is not the score plus the roll")
	equal(check_row.passed, check_row.total >= check_row.difficulty,
		"the verdict is not the total against the class")
	equal(check_row.state, AbilityCheck.SETTLED, "the check did not settle")

	# And the engine bounds what it will accept, rather than taking any number.
	var absurd := _one_check(["dc=9999 ability=str", "open target=%d"], 1)
	equal((absurd["check"] as AbilityCheck).said_class, 9999,
		"the record forgot what the model actually said")
	equal((absurd["check"] as AbilityCheck).difficulty, AbilityCheck.DC_HIGHEST,
		"the engine did not bound an absurd class")


## The same reply, two roll seeds, two verdicts. What decides is the die.
func _the_die_and_not_the_words_decide() -> void:
	var replies := ["dc=12 ability=str", "open target=%d"]
	var verdicts := {}
	var rolls := {}
	for seed_value in 12:
		var settled := _one_check(replies, seed_value)
		var one: AbilityCheck = settled["check"]
		verdicts[one.passed] = true
		rolls[one.roll] = true
	check(verdicts.size() == 2,
		"the same reply gave the same verdict at every seed, so the die decides nothing")
	check(rolls.size() > 1, "the die gave the same number at every seed")


# --- 3. Words are not a resolution ----------------------------------------


## A judging reply that says the chest is already open leaves it shut, and what
## opens it is a passed roll and an operation.
func _a_claim_of_success_changes_nothing() -> void:
	# A seed at which this class fails, found by asking rather than assumed.
	var failing := -1
	for seed_value in 30:
		var tried := _one_check([CLAIMS_IT_WORKED, "open target=%d"], seed_value)
		if not (tried["check"] as AbilityCheck).passed:
			failing = seed_value
			break
	check(failing >= 0, "no seed in thirty failed this class, so the check below is empty")
	var settled := _one_check([CLAIMS_IT_WORKED, "open target=%d"], failing)
	var chest: WorldObject = settled["chest"]
	var one: AbilityCheck = settled["check"]
	check(not one.passed, "the roll passed, so this proves nothing")
	check(chest.shut, "prose in a reply opened the chest")
	equal(one.operations.size(), 0,
		"a failed check resolved operations anyway: %d" % one.operations.size())
	equal((settled["desk"] as CheckDesk).calls, 1,
		"a failed check made the second call anyway")


# --- 4. Two prompts, and a table the engine owns --------------------------


func _two_prompts_not_one() -> void:
	not_equal(CheckPrompt.JUDGES, CheckPrompt.RESOLVES,
		"the two calls open with the same line")
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var rook: Combatant = world["rook"]
	var chest: WorldObject = world["chest"]
	ActionEngine.resolve(scene, rook, Action.interact(chest.id, BAR))
	var raised: AbilityCheck = scene.raised[0]
	var sheet := (rook.piece as Commander).sheet
	var judging := CheckPrompt.judging_for(raised, sheet)
	var resolving := CheckPrompt.resolving_for(raised, sheet, scene)
	not_equal(CheckPrompt.digest_of(judging), CheckPrompt.digest_of(resolving),
		"the two calls are the same prompt")
	check(judging.begins_with(CheckPrompt.JUDGES), "the judging prompt opens wrong")
	check(resolving.begins_with(CheckPrompt.RESOLVES), "the resolving prompt opens wrong")
	for named in CheckEffects.names():
		check(resolving.contains(named),
			"the resolving prompt does not offer %s" % named)
		check(not judging.contains("%s target=" % named),
			"the judging prompt offers %s, which is not its call's business" % named)
	check(not judging.contains("roll") and not resolving.contains("roll"),
		"a prompt mentions the roll, which is not the model's to know about")


## Each of the four operations does what the table says, and refuses when it does
## not apply. The one door is `CheckEffects.apply`, so this exercises it directly.
func _every_operation_and_only_those() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var chest: WorldObject = world["chest"]
	var exercised := {}

	var opened := _apply(scene, "open target=#%d" % chest.id)
	check(bool(opened["ok"]) and chest.is_open(), "open did not open: %s" % opened["reason"])
	exercised[CheckEffects.OPEN] = true
	var again := _apply(scene, "open target=#%d" % chest.id)
	check(not bool(again["ok"]), "open opened something already open")

	var spilled := _apply(scene, "spill target=#%d" % chest.id)
	check(bool(spilled["ok"]), "spill did not spill: %s" % spilled["reason"])
	equal(chest.contents.size(), 0, "spill left things in the chest")
	equal(chest.contents.money, 0, "spill left coins in the chest")
	equal(scene.objects.size(), 2, "spill did not leave a pile behind")
	exercised[CheckEffects.SPILL] = true
	var nothing_left := _apply(scene, "spill target=#%d" % chest.id)
	check(not bool(nothing_left["ok"]), "spill spilled an empty chest")

	var closed := _apply(scene, "shut target=#%d" % chest.id)
	check(bool(closed["ok"]) and chest.shut, "shut did not shut: %s" % closed["reason"])
	exercised[CheckEffects.SHUT] = true

	var was := Vector2(chest.x, chest.z)
	var shoved := _apply(scene, "move target=#%d to=(%.3f, %.3f)" % [
		chest.id, was.x + 1.0, was.y,
	])
	check(bool(shoved["ok"]), "move did not move: %s" % shoved["reason"])
	equal(snappedf(chest.x, 0.001), snappedf(was.x + 1.0, 0.001), "move landed elsewhere")
	exercised[CheckEffects.MOVE] = true
	var too_far := _apply(scene, "move target=#%d to=(%.3f, %.3f)" % [
		chest.id, chest.x + CheckEffects.NUDGE + 1.0, chest.z,
	])
	check(not bool(too_far["ok"]), "move carried a thing further than a shove")

	equal(exercised.keys().size(), CheckEffects.ROWS.size(),
		"the suite exercised %d of the %d operations" % [
			exercised.keys().size(), CheckEffects.ROWS.size(),
		])

	# And a line that is not one of them is not an operation at all.
	for line in [
		"delete target=#%d" % chest.id, "chest.shut = false",
		"The chest opens and a trap springs.", "open the chest", "open target=nothing",
	]:
		equal(CheckEffects.read(line).size(), 0,
			"a line the engine exposes nothing for was read as an operation: %s" % line)


## More operations than the engine carries out has the rest refused, and the
## world shows it.
func _more_than_the_engine_carries_out() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var rook: Combatant = world["rook"]
	var chest: WorldObject = world["chest"]
	var too_many := PackedStringArray()
	for _at in CheckEffects.AT_MOST + 2:
		too_many.append("open target=#%d" % chest.id)
	var desk := _settled(scene, rook, chest, _channel([
		"dc=2 ability=str", "\n".join(too_many),
	]), 1)
	var one: AbilityCheck = desk.seen[0]
	check(one.passed, "this check was meant to pass")
	equal(one.operations.size(), too_many.size(),
		"every named operation should be recorded, carried out or not")
	var refused_for_count := 0
	for at in range(CheckEffects.AT_MOST, one.operations.size()):
		if String(one.operations[at]["reason"]).contains("at most"):
			refused_for_count += 1
	equal(refused_for_count, too_many.size() - CheckEffects.AT_MOST,
		"the engine did not stop at %d operations" % CheckEffects.AT_MOST)


# --- 5. Stored, and reused ------------------------------------------------


## A second attempt of the same shape settles out of the character's memory: no
## call, no roll, and the operation carried out again against the thing in front
## of it now.
func _the_context_is_stored_and_reused() -> void:
	var world := _bare(2)
	var scene: ActionScene = world["scene"]
	var rook: Combatant = world["rook"]
	var chest: WorldObject = world["chest"]
	var second: WorldObject = world["second"]
	var channel := _channel(["dc=2 ability=str", "open target=#%d" % chest.id])
	var desk := CheckDesk.with_channel(channel, 1)

	_attempt(scene, rook, chest, desk, BAR)
	var first: AbilityCheck = desk.seen[0]
	check(first.passed and chest.is_open(), "the first attempt was meant to pass")
	equal(desk.calls, 2, "a fresh check should cost two calls: %d" % desk.calls)
	equal(desk.rolls, 1, "a fresh check should cost one roll: %d" % desk.rolls)

	var remembered := (rook.piece as Commander).sheet.memory
	equal(remembered.checks.size(), 1, "the triggering context was not stored")
	equal(String(remembered.checks[0]["context"]), first.context,
		"what was stored is not the triggering context")
	check(not remembered.check_for(first.context).is_empty(),
		"the stored context cannot be found again")

	_attempt(scene, rook, second, desk, BAR)
	var later: AbilityCheck = desk.seen[1]
	equal(later.context, first.context, "the second attempt is not the same shape")
	equal(later.how, AbilityCheck.BY_MEMORY, "the second attempt was not remembered")
	equal(desk.calls, 2, "the second attempt cost a call: %d" % desk.calls)
	equal(desk.rolls, 1, "the second attempt cost a roll: %d" % desk.rolls)
	equal(later.roll, first.roll, "the second attempt did not reuse the stored roll")
	equal(later.passed, first.passed, "the second attempt reached a different verdict")
	check(second.is_open(),
		"the remembered success did nothing to the thing actually attempted")
	equal(remembered.checks.size(), 1,
		"one shape should be one row: %d" % remembered.checks.size())

	# A different shape is not the same context, and is judged on its own.
	ActionScene.inventory_of(rook).carry(_tool("bone awl"))
	channel = _channel(["dc=2 ability=str", "open target=#%d" % chest.id,
		"dc=30 ability=int"])
	_attempt(scene, rook, chest, desk, "bone awl")
	var different: AbilityCheck = desk.seen[2]
	not_equal(different.context, first.context,
		"a different item is being treated as the same attempt")
	equal(different.how, AbilityCheck.BY_A_ROLL,
		"a shape never attempted before was answered out of memory")


## The shipped run: four checks, four calls, two rolls, two remembered.
##
## The counts that are structural -- four raised, four settled, two reused, two
## rolled, two rows kept -- hold for any draw. The two that are not, `calls` and
## how many passed, are read off whichever recording is checked in: a passed roll
## asks a second question and a failed one does not, so a re-record that turns a
## pass into a failure moves both. On the draw before this one the crate check
## came back `dc=12`, failed on a roll of 10, and the run cost three calls with
## two passes.
func _the_shipped_run_pays_for_two_of_four() -> void:
	var played := ScriptedCheck.played_with(
		ModelChannel.for_run(ModelRecording.check_exchange()))
	var desk: CheckDesk = played["desk"]
	equal(desk.seen.size(), 4, "the shipped run raises four checks")
	equal(desk.settled(), 4, "every one of them settles")
	equal(desk.reused, 2, "two of the four are settled out of memory")
	equal(desk.rolls, 2, "so only two of the four are rolled for")
	equal(desk.calls, 4,
		"and they cost four calls: two to judge, two to resolve")
	var remembered: CharacterMemory = played["memory"]
	equal(remembered.checks.size(), 2,
		"four attempts of two shapes should leave two rows")
	var passed := 0
	for one in desk.seen:
		if one.passed:
			passed += 1
	equal(passed, 4, "on this draw all four checks passed")


# --- 6. The model never resolves ------------------------------------------


## The die is drawn in exactly one function, in `AbilityCheck`.
func _the_die_is_drawn_in_one_place() -> void:
	var drawn := _lines_holding(HANDLES_A_CHECK, DRAWS_A_DIE)
	equal(drawn.size(), 1, "the die is drawn in %d places: %s" % [
		drawn.size(), " | ".join(drawn),
	])
	check(String(drawn[0]).begins_with(RECORD),
		"the die is drawn outside the record: %s" % drawn[0])
	check(_body_of(RECORD, "rolled").contains("hash_ints("),
		"AbilityCheck.rolled does not draw the die")
	# And it draws it by hashing rather than out of a stream, which is the
	# discipline `tests/test_combat_resolution.gd` requires of everything that
	# names a combatant: a roll is a fact about the check, not about how many
	# checks were settled before it.
	for streamed in ["SimRng.new(", "next_int(", "fork(", "set_state("]:
		for path in HANDLES_A_CHECK:
			check(not _read(path).contains(streamed),
				"%s holds a stream (%s), so a roll depends on what came before it"
					% [path, streamed])


## The comparison of a total against a class is made in exactly one function.
func _the_comparison_is_made_in_one_place() -> void:
	var compared := PackedStringArray()
	for path in HANDLES_A_CHECK:
		for line in _code_lines(path):
			if _compares_a_class(line):
				compared.append("%s: %s" % [path, line])
	equal(compared.size(), 1, "a class is compared in %d places: %s" % [
		compared.size(), " | ".join(compared),
	])
	check(String(compared[0]).begins_with(RECORD),
		"a class is compared outside the record: %s" % compared[0])
	check(_body_of(RECORD, "beats").contains("difficulty"),
		"AbilityCheck.beats does not compare against the class")


## The world is written in exactly one file, and it is the table of operations.
func _the_world_is_written_in_one_place() -> void:
	var writing := PackedStringArray()
	for path in HANDLES_A_CHECK:
		for line in _code_lines(path):
			for shape in WRITES_THE_WORLD:
				if line.contains(shape):
					writing.append("%s: %s" % [path, line])
					break
	equal(writing, PackedStringArray(),
		"something outside the operations table writes the world: %s"
			% " | ".join(writing))
	# And the operations table really does write it, or the scan above found
	# nothing because there was nothing to find.
	var written := 0
	for line in _code_lines(EFFECTS):
		for shape in WRITES_THE_WORLD:
			if line.contains(shape):
				written += 1
				break
	check(written >= 3, "the operations table writes the world in %d places" % written)


## All three scans are shown to catch the lines they are for.
func _the_source_scans_would_notice() -> void:
	for broken in [BROKEN_ROLL, BROKEN_HASH]:
		var rolls := false
		for shape in DRAWS_A_DIE:
			if String(broken).contains(shape):
				rolls = true
		check(rolls, "the die scan would not catch %s" % broken)
	check(_compares_a_class(BROKEN_COMPARE),
		"the comparison scan would not catch %s" % BROKEN_COMPARE)
	var writes := false
	for shape in WRITES_THE_WORLD:
		if BROKEN_WRITE.contains(shape):
			writes = true
	check(writes, "the world-writing scan would not catch %s" % BROKEN_WRITE)
	check(not _compares_a_class("	if check.difficulty != check.said_class:"),
		"the comparison scan catches a line that only notices a class was bounded")


# --- 7. Two processes agree -----------------------------------------------


## The run is a fact about the seed: played twice in this process it prints the
## same bytes, and the transcript checked in under reports/ is what the command
## prints.
func _two_processes_agree() -> void:
	var channel := ModelChannel.for_run(ModelRecording.check_exchange())
	equal(channel.kind, ModelChannel.REPLAY,
		"the suite reached for a live channel, which would need a key")
	var first := _run_check()
	var second := _run_check()
	equal(int(first["code"]), 0, "%s exits 0" % COMMAND)
	equal(int(second["code"]), 0, "and again")
	equal(first["text"], second["text"],
		"two runs of %s printed different bytes" % COMMAND)

	var checked_in := _read(TRANSCRIPT)
	check(checked_in != "", "the transcript %s is not checked in" % TRANSCRIPT)
	equal(checked_in.strip_edges(), String(first["text"]).strip_edges(),
		"%s is not what %s prints" % [TRANSCRIPT, COMMAND])


# --- The furniture ---------------------------------------------------------


# A bare stage: Rook with a pry bar, and one or two shut things needing a key.
func _bare(how_many: int = 1) -> Dictionary:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var rook := scene.add_actor(Combatant.commander_at(
		WHERE.x + ROOK_AT.x, WHERE.y + ROOK_AT.y, 0.0, 0.0, 2, AssetTags.ROGUE))
	var sheet := Character.make("Rook", 2)
	sheet.record_scores(SCORES)
	(rook.piece as Commander).adopt(sheet)
	sheet.inventory.carry(_tool(BAR))
	rook.settle(scene.terrain)
	var made := {"scene": scene, "rook": rook}
	for at in how_many:
		var offset: Vector2 = THINGS_AT[at]
		var thing := scene.add_object(WorldObject.chest(
			"oak chest", WHERE.x + offset.x, WHERE.y + offset.y,
			Inventory.of([_tool("linen hood")], 7), KEY))
		made["chest" if at == 0 else "second"] = thing
	return made


# A channel that answers in order out of replies written here. Rows carry no
# digest, so the channel falls back to answering the n-th question with the n-th
# row, which is what a suite wants.
func _channel(replies: Array) -> ModelChannel:
	var rows := []
	for reply in replies:
		rows.append({"prompt": "", "reply": String(reply), "ms": 0})
	return ModelChannel.replaying(
		{"rows": rows, "from": "written in this suite", "model": "none"},
		"the suite answers its own questions")


# One attempt, raised and then stepped until the desk has nothing outstanding.
func _attempt(
	scene: ActionScene, rook: Combatant, thing: WorldObject, desk: CheckDesk,
	item: String
) -> void:
	ActionEngine.resolve(scene, rook, Action.interact(thing.id, item))
	for _tick in 4 * (ModelChannel.THINKS_FOR + 1):
		scene.advance(1)
		desk.step(scene)


# One whole check, from raising to settled, answered by the replies given. A
# reply holding `%d` is filled in with the thing's id.
func _one_check(replies: Array, roll_seed: int) -> Dictionary:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var rook: Combatant = world["rook"]
	var chest: WorldObject = world["chest"]
	var filled := []
	for reply in replies:
		filled.append(String(reply) % chest.id if String(reply).contains("%d")
			else String(reply))
	var desk := _settled(scene, rook, chest, _channel(filled), roll_seed)
	return {
		"scene": scene, "rook": rook, "chest": chest, "desk": desk,
		"check": desk.seen[0],
	}


func _settled(
	scene: ActionScene, rook: Combatant, thing: WorldObject, channel: ModelChannel,
	roll_seed: int
) -> CheckDesk:
	var desk := CheckDesk.with_channel(channel, roll_seed)
	_attempt(scene, rook, thing, desk, BAR)
	return desk


# One operation read out of a line and carried out, as the desk would.
func _apply(scene: ActionScene, line: String) -> Dictionary:
	var named := CheckEffects.read(line)
	if named.is_empty():
		return {"ok": false, "reason": "not an operation", "line": line}
	return CheckEffects.apply(scene, named[0])


# The command run as its own process, which is what "two processes agree" means.
func _run_check() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path(COMMAND), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


# Whether a line compares something against a difficulty class by magnitude. A
# line that only notices a class was bounded -- `!=` -- is not one.
func _compares_a_class(line: String) -> bool:
	if not line.contains("difficulty"):
		return false
	for shape in [">=", "<=", " > ", " < "]:
		if line.contains(shape):
			return true
	return false


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


# The body of one function, as code lines joined.
func _body_of(path: String, named: String) -> String:
	var inside := false
	var body := PackedStringArray()
	for line in _read(path).split("\n"):
		if line.begins_with("static func %s(" % named) or line.begins_with("func %s(" % named):
			inside = true
			continue
		if inside and (line.begins_with("func ") or line.begins_with("static func ")):
			break
		if inside:
			body.append(line)
	return "\n".join(body)


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
