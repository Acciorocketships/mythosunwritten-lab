extends TestSuite
## The orchestrator: the world's dungeon master, polled over a world, spawning
## characters rolls first and changing the world only through the operations the
## engine exposes.
##
## Every check in this file runs with no key, no network and no model, for the
## reason `tests/test_agent.gd` gives: the model layer is built so that a written
## reply stands in for a live call everywhere except the one command that makes
## the recording, and a suite that needed a credential would be evidence that it
## is not.
##
## Seven claims:
##
##   1. **A spawn happens in section 8's order.** The sheet is rolled first --
##      from the role's bands and the region's own difficulty -- and the
##      character is standing in the world with those six numbers before anybody
##      has been asked who it is. The persona question carries those exact
##      numbers, and the answer to it cannot move one of them: a reply that says
##      the scores are something else leaves them as rolled.
##   2. **The bands are the role's and section 5's, read from the world.** The
##      level a spawn is given is `ItemFrontier.level_at` of its distance from
##      spawn, to the number; the bands are the role's own, lifted by the ring;
##      and the same role rolled in two rings gives two different sheets.
##   3. **Everything it does to the world is one of seven operations.** Each does
##      what the table says and refuses when it does not apply; a line that is
##      not one of them changes nothing; more than `WorldEffects.AT_MOST` has the
##      rest refused; and `nothing` is read as a decision rather than as a
##      failure to answer.
##   4. **The model never edits state**, read off the source: no file in the
##      layer except the operations table writes the world, the scan is shown to
##      have teeth, and the file that rolls a sheet never sees a reply at all.
##   5. **No hard-coded story and no reach into a mind.** What the orchestrator
##      may do is the operations list and nothing else; the layer names no quest,
##      plot or ending anywhere; and no operation sets a decision function, a
##      goal, a memory or a relationship edge.
##   6. **Nothing waits for it.** A channel that never answers leaves the world
##      turning and the character acting, measured on a run; and the shipped run
##      acts on ticks the orchestrator is thinking.
##   7. **Two processes agree**, and the checked-in transcript is what the
##      command prints.
class_name TestOrchestrator

## The files that make up the orchestrator layer.
const ORCHESTRATOR := "res://sim/orchestrator.gd"
const PROMPTS := "res://sim/orchestrator_prompt.gd"
const ROLLS := "res://sim/spawn_roll.gd"
const EFFECTS := "res://sim/world_effects.gd"

## The three that see an answer or roll a sheet. `sim/world_effects.gd` is
## deliberately not among them -- it is the table, and the whole point is that it
## is the one thing that writes. `sim/scripted_world.gd` is not either: it is the
## run that sets a world out, so it puts objects into a scene, and scanning it
## for that would be scanning the wrong thing.
const HANDLES_THE_WORLD := [ORCHESTRATOR, PROMPTS, ROLLS]

## How a line of code writes the world. Matched as plain substrings, against a
## line whose `==` has been taken out first: a comparison is not a write, and
## `sheet.backstory == ""` would otherwise read as one.
const WRITES_THE_WORLD := [
	"add_object(", "remove_object(", "add_actor(", ".shut =", ".x =", ".z =",
	"contents.release(", ".backstory =", ".character_name =", ".traits =",
	".tendencies =",
]

## How a line of code would reach into a mind rather than into the world.
const TOUCHES_A_MIND := [
	".decide =", ".goals", ".memory", "relationships", "RelationshipGraph",
	"Action.", "ActionEngine.", "GoalCheck", "DecisionSource",
]

## Words that would mean a narrative beat had been written down somewhere in the
## layer. Matched as whole words, so `backstory` is not read as `story`.
const STORY_WORDS := [
	"quest", "quests", "story", "stories", "plot", "narrative", "chapter",
	"ending", "villain", "hero", "twist", "adventure",
]

## Lines the scans must catch.
const BROKEN_WRITE := "	thing.shut = false"
const BROKEN_MIND := "	sheet.decide = DecisionSource.plan(written)"
const BROKEN_STORY := "	var quest := \"fetch the lantern\""

## A persona answer the suite writes, for the spawns it does not want to leave
## standing anonymous.
const A_PERSONA := (
	"name=Someone\ntraits=quick, loud\ntendencies=forward\n"
	+ "backstory=Written by the suite so a spawn has an explanation.")

## A persona answer that tries to be a character sheet.
const CLAIMS_THE_NUMBERS := (
	"name=Bellwether\n"
	+ "str=18 con=18 cha=18 dex=18 wis=18 int=18\n"
	+ "traits=loud, certain\n"
	+ "tendencies=boastful\n"
	+ "backstory=Every score is an eighteen because I say so."
)

## The ground the bare scene is staged on, and where the things in it stand.
const WHERE := ScriptedActions.WHERE
const SEED := ScriptedActions.SEED
const CHEST_AT := Vector2(2.0, 0.0)
const SPAWN_AT := Vector2(3.0, 1.0)

## A cadence long enough that a check gets exactly one look at the world, so
## that what is being counted is one answer and not a series of them.
const ONE_LOOK := 500

## Two positions in two different rings of the section 5 gradient, for the check
## that the gradient is being read rather than invented.
const NEAR_SPAWN := Vector2(8.0, 0.0)
const FAR_OUT := Vector2(600.0, 600.0)

## The transcript checked in under reports/, and the command that prints it.
const TRANSCRIPT := "res://reports/world-evidence.txt"
const COMMAND := "res://run_world.sh"

var _words := RegEx.create_from_string("[A-Z]+(?![a-z])|[A-Z][a-z]*|[a-z]+")


func _init() -> void:
	suite_name = "orchestrator"


func run() -> void:
	_the_sheet_is_rolled_before_anybody_is_asked()
	_the_persona_question_carries_the_rolls()
	_a_persona_cannot_move_a_score()
	_a_persona_is_written_once_and_onto_its_own_spawn()
	_the_level_is_section_fives_own_number()
	_the_bands_are_the_roles_lifted_by_the_ring()
	_two_rings_are_two_sheets()
	_every_operation_and_only_those()
	_more_than_the_engine_carries_out()
	_nothing_is_an_answer()
	_the_world_is_written_in_one_place()
	_the_file_that_rolls_never_sees_a_reply()
	_no_story_and_no_reach_into_a_mind()
	_the_source_scans_would_notice()
	_the_world_turns_while_it_thinks()
	_the_shipped_run_acts_while_it_thinks()
	_two_processes_agree()


# --- 1. Rolls first, persona afterwards -----------------------------------


## The character is standing in the world with its six numbers, and no persona,
## before anything has been answered. This is the order itself: the run is
## stepped only far enough for the spawn to have happened, and the world is read
## at that moment.
func _the_sheet_is_rolled_before_anybody_is_asked() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var dm := Orchestrator.with_channel(
		_channel([_spawn_line(scene), A_PERSONA]), SEED, ONE_LOOK)

	# Far enough for the look to be answered and the spawn carried out, and not
	# far enough for the persona question to have come back.
	_step(scene, dm, ModelChannel.THINKS_FOR + 1)
	equal(dm.spawns.size(), 1, "the look did not spawn anybody")
	var row: Dictionary = dm.spawns[0]
	var one := scene.actor_of(int(row["id"]))
	check(one != null, "the spawned character is not standing in the world")
	var sheet := (one.piece as Commander).sheet
	for ability in Ability.ALL:
		check(sheet.has_score(ability),
			"a spawned character has no %s before the persona lands" % ability)
	equal(sheet.backstory, "",
		"the persona was written before it could have been answered: %s"
			% sheet.backstory)
	equal(int(row["written_at"]), -1, "the run says a persona is already back")
	equal(dm.calls, 2, "a spawn is one look and one persona call: %d" % dm.calls)

	# And then it lands, and the character is somebody.
	_step(scene, dm, ModelChannel.THINKS_FOR + 2)
	not_equal(sheet.backstory, "", "the persona never landed")
	check(int(row["written_at"]) > int(row["rolled_at"]),
		"the persona is not written after the roll: rolled %d, written %d" % [
			row["rolled_at"], row["written_at"],
		])
	equal(String(row["rolls_after"]), String(row["rolls"]),
		"the persona moved the numbers it was meant to explain")


## The persona question is written out of the sheet that was rolled: the six
## numbers in it are the six numbers the character has.
func _the_persona_question_carries_the_rolls() -> void:
	var at := Vector2(WHERE.x + SPAWN_AT.x, WHERE.y + SPAWN_AT.y)
	var sheet := SpawnRoll.sheet_at(SEED, 1, SpawnRoll.HERALD, at.x, at.y)
	var prompt := OrchestratorPrompt.peopling_for(sheet, SpawnRoll.HERALD, at, 7)
	check(prompt.begins_with(OrchestratorPrompt.PEOPLING_TITLE),
		"the persona prompt opens wrong")
	check(prompt.contains(OrchestratorPrompt.PEOPLES),
		"the persona prompt does not say what its call is for")
	check(not prompt.contains(OrchestratorPrompt.WATCHES),
		"the persona prompt says what the other call is for")
	not_equal(OrchestratorPrompt.WATCHES, OrchestratorPrompt.PEOPLES,
		"the two calls open with the same line")
	check(prompt.contains(sheet.scores_line()),
		"the persona question does not carry the rolled scores: %s"
			% sheet.scores_line())
	check(prompt.contains("level %d" % sheet.level),
		"the persona question does not carry the rolled level")
	var spread := SpawnRoll.spread_of(sheet)
	check(int(spread["spread"]) >= 8,
		"a %s is not rolled extreme enough to explain: %d apart" % [
			SpawnRoll.HERALD, spread["spread"],
		])
	equal(String(spread["high"]), Ability.CHA,
		"a %s is not rolled highest on %s" % [SpawnRoll.HERALD, Ability.CHA])
	equal(String(spread["low"]), Ability.WIS,
		"a %s is not rolled lowest on %s" % [SpawnRoll.HERALD, Ability.WIS])
	check(prompt.contains("highest: %s" % spread["high"]),
		"the persona question does not say which score is highest")

	# And it offers nothing to change them with: not one line of operation
	# syntax is in it, so there is nothing in the answer the engine would read.
	for named in WorldEffects.names():
		for key in WorldEffects.KEYS:
			check(not prompt.contains("%s %s=" % [named, key]),
				"the persona question offers %s, which is not its call's business"
					% named)
	equal(WorldEffects.read(prompt).size(), 0,
		"the persona question is itself readable as an operation")


## A persona answer that says what the scores are changes none of them.
func _a_persona_cannot_move_a_score() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var dm := Orchestrator.with_channel(
		_channel([_spawn_line(scene), CLAIMS_THE_NUMBERS]), SEED, ONE_LOOK)
	_step(scene, dm, 3 * (ModelChannel.THINKS_FOR + 2))
	equal(dm.spawns.size(), 1, "no spawn to test")
	var row: Dictionary = dm.spawns[0]
	var sheet := (scene.actor_of(int(row["id"])).piece as Commander).sheet
	equal(sheet.scores_line(), String(row["rolls"]),
		"prose in a persona reply moved the rolled scores")
	for ability in Ability.ALL:
		not_equal(sheet.score(ability), 18,
			"a persona reply set %s to the number it named" % ability)
	equal(sheet.character_name, "Bellwether",
		"the persona did not name the character it explains")
	not_equal(sheet.backstory, "", "the persona wrote no backstory")


## A persona is written at the spawn it belongs to, once, and never onto anybody
## the orchestrator did not spawn.
func _a_persona_is_written_once_and_onto_its_own_spawn() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var rook: Combatant = world["rook"]
	var persona := OrchestratorPrompt.persona_of(
		"name=Someone\ntraits=a, b\ntendencies=c\nbackstory=Written by nobody.")
	check(bool(persona["read"]), "the persona could not be read")

	var dm := Orchestrator.with_channel(
		_channel([_spawn_line(scene), A_PERSONA]), SEED, ONE_LOOK)
	_step(scene, dm, 3 * (ModelChannel.THINKS_FOR + 2))
	var id := int((dm.spawns[0] as Dictionary)["id"])
	check(dm.mine(id), "the orchestrator does not own the character it spawned")
	check(not dm.mine(rook.id),
		"the orchestrator claims a character that was there before it")
	equal(dm.spawned.size(), 1,
		"the orchestrator owns %d characters after one spawn" % dm.spawned.size())

	# Written once: the engine refuses to write over a persona that is there.
	var again := WorldEffects.dress(scene, id, persona)
	check(not bool(again["ok"]),
		"a second persona was written over the first: %s" % again["reason"])
	# And the character that was there before it was never written into at all.
	equal((scene.actor_of(rook.id).piece as Commander).sheet.backstory, "",
		"a character the orchestrator did not spawn was written into")
	equal((scene.actor_of(rook.id).piece as Commander).sheet.character_name, "Rook",
		"a character the orchestrator did not spawn was renamed")


# --- 2. The gradient, read from the world ---------------------------------


## A spawn's level is section 5's own number for the ground it stands on, out of
## section 5's own file, and not something invented here.
func _the_level_is_section_fives_own_number() -> void:
	for at in [NEAR_SPAWN, FAR_OUT, WHERE]:
		var distance := Vector2(at.x, at.y).length()
		equal(SpawnRoll.difficulty_at(at.x, at.y), ItemFrontier.level_at(distance),
			"the difficulty at (%.1f, %.1f) is not the frontier's level" % [at.x, at.y])
		equal(SpawnRoll.ring_at(at.x, at.y), ItemFrontier.ring_at(distance),
			"the ring at (%.1f, %.1f) is not the frontier's ring" % [at.x, at.y])
		var sheet := SpawnRoll.sheet_at(SEED, 1, SpawnRoll.GUARD, at.x, at.y)
		equal(sheet.level, ItemFrontier.level_at(distance),
			"a character spawned at (%.1f, %.1f) is not the level the region says"
				% [at.x, at.y])
	check(ItemFrontier.level_at(Vector2(FAR_OUT.x, FAR_OUT.y).length())
			> ItemFrontier.level_at(Vector2(NEAR_SPAWN.x, NEAR_SPAWN.y).length()),
		"the gradient does not rise with distance, so this proves nothing")


## Every band is the role's own band lifted by the ring, and the four roles are
## really four different shapes.
func _the_bands_are_the_roles_lifted_by_the_ring() -> void:
	equal(SpawnRoll.roles().size(), SpawnRoll.ROLES.size(), "a role went missing")
	for row in SpawnRoll.ROLES:
		equal((row["bands"] as Array).size(), Ability.ALL.size(),
			"the %s has %d bands for %d scores" % [
				row["role"], (row["bands"] as Array).size(), Ability.ALL.size(),
			])
	for role in SpawnRoll.roles():
		for at in [NEAR_SPAWN, FAR_OUT]:
			var lift := SpawnRoll.ring_at(at.x, at.y) / SpawnRoll.RINGS_A_POINT
			equal(SpawnRoll.lift_at(at.x, at.y), lift,
				"the lift at (%.1f, %.1f) is not the ring over %d" % [
					at.x, at.y, SpawnRoll.RINGS_A_POINT,
				])
			for ability in Ability.ALL:
				var band := SpawnRoll.band_for(role, ability, at.x, at.y)
				var own: Array = (SpawnRoll.row_of(role)["bands"] as Array)[
					Ability.rank(ability)]
				equal(band, Vector2i(int(own[0]) + lift, int(own[1]) + lift),
					"the %s's %s band at (%.1f, %.1f) is not its own lifted" % [
						role, ability, at.x, at.y,
					])
			# And every roll lands inside the band it was drawn from.
			var sheet := SpawnRoll.sheet_at(SEED, 3, role, at.x, at.y)
			for ability in Ability.ALL:
				var band := SpawnRoll.band_for(role, ability, at.x, at.y)
				check(sheet.score(ability) >= band.x and sheet.score(ability) <= band.y,
					"a %s rolled %s %d, outside %d..%d" % [
						role, ability, sheet.score(ability), band.x, band.y,
					])

	# The four roles are far enough apart to be recognisable.
	var highest := {}
	for role in SpawnRoll.roles():
		var sheet := SpawnRoll.sheet_at(SEED, 1, role, NEAR_SPAWN.x, NEAR_SPAWN.y)
		highest[String(SpawnRoll.spread_of(sheet)["high"])] = true
	check(highest.size() >= 3,
		"the four roles roll highest on only %d different scores" % highest.size())


## The same role, the same spawn number, two rings: two sheets, and the far one
## is the higher level.
func _two_rings_are_two_sheets() -> void:
	var near := SpawnRoll.sheet_at(SEED, 1, SpawnRoll.SCOUT, NEAR_SPAWN.x, NEAR_SPAWN.y)
	var far := SpawnRoll.sheet_at(SEED, 1, SpawnRoll.SCOUT, FAR_OUT.x, FAR_OUT.y)
	check(far.level > near.level,
		"the far sheet is not the higher level: %d against %d" % [
			far.level, near.level,
		])
	not_equal(far.scores_line(), near.scores_line(),
		"two rings rolled the same six numbers")
	# And the same roll asked twice is the same roll.
	equal(SpawnRoll.sheet_at(SEED, 1, SpawnRoll.SCOUT, FAR_OUT.x, FAR_OUT.y).scores_line(),
		far.scores_line(), "the same spawn rolled differently the second time")
	not_equal(
		SpawnRoll.sheet_at(SEED, 2, SpawnRoll.SCOUT, FAR_OUT.x, FAR_OUT.y).scores_line(),
		far.scores_line(), "two spawns in one run rolled identically")


# --- 3. Seven operations, and nothing else --------------------------------


## Each operation does what the table says and refuses when it does not apply.
func _every_operation_and_only_those() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var chest: WorldObject = world["chest"]
	var exercised := {}
	var here := Vector2(WHERE.x + SPAWN_AT.x, WHERE.y + SPAWN_AT.y)

	var placed := _apply(scene, "place kind=crate at=(%.3f, %.3f)" % [here.x, here.y], SEED)
	check(bool(placed["ok"]), "place did not place: %s" % placed["reason"])
	var made := scene.object_of(int(placed["target"]))
	check(made != null and made.shut, "the placed crate is not there and shut")
	exercised[WorldEffects.PLACE] = true
	var nonsense := _apply(scene, "place kind=castle at=(%.3f, %.3f)" % [here.x, here.y], SEED)
	check(not bool(nonsense["ok"]), "place put down a kind the engine has never heard of")
	var miles := _apply(scene, "place kind=chest at=(%.3f, %.3f)" % [
		WHERE.x + WorldEffects.WITHIN + 50.0, WHERE.y,
	], SEED)
	check(not bool(miles["ok"]), "place put a thing down where nobody will ever be")

	var opened := _apply(scene, "open target=#%d" % made.id, SEED)
	check(bool(opened["ok"]) and made.is_open(), "open did not open: %s" % opened["reason"])
	exercised[CheckEffects.OPEN] = true
	var closed := _apply(scene, "shut target=#%d" % made.id, SEED)
	check(bool(closed["ok"]) and made.shut, "shut did not shut: %s" % closed["reason"])
	exercised[CheckEffects.SHUT] = true

	var spilled := _apply(scene, "spill target=#%d" % chest.id, SEED)
	check(bool(spilled["ok"]), "spill did not spill: %s" % spilled["reason"])
	equal(chest.contents.money, 0, "spill left coins in the chest")
	exercised[CheckEffects.SPILL] = true

	var was := Vector2(chest.x, chest.z)
	var shoved := _apply(scene, "move target=#%d to=(%.3f, %.3f)" % [
		chest.id, was.x + 1.0, was.y,
	], SEED)
	check(bool(shoved["ok"]), "move did not move: %s" % shoved["reason"])
	exercised[CheckEffects.MOVE] = true

	var gone := _apply(scene, "remove target=#%d" % made.id, SEED)
	check(bool(gone["ok"]) and scene.object_of(made.id) == null,
		"remove did not remove: %s" % gone["reason"])
	exercised[WorldEffects.REMOVE] = true
	var nobody := _apply(scene, "remove target=#%d" % (world["rook"] as Combatant).id, SEED)
	check(not bool(nobody["ok"]), "remove took a character out of the world")

	var spawned := _apply(scene, "spawn role=%s at=(%.3f, %.3f)" % [
		SpawnRoll.SCHOLAR, here.x, here.y,
	], SEED)
	check(bool(spawned["ok"]) and spawned.has("spawned"),
		"spawn did not spawn: %s" % spawned["reason"])
	exercised[WorldEffects.SPAWN] = true
	var no_such := _apply(scene, "spawn role=dragon at=(%.3f, %.3f)" % [here.x, here.y], SEED)
	check(not bool(no_such["ok"]), "spawn rolled a role the engine has never heard of")

	equal(exercised.keys().size(), WorldEffects.names().size(),
		"the suite exercised %d of the %d operations" % [
			exercised.keys().size(), WorldEffects.names().size(),
		])
	equal(WorldEffects.catalogue_lines().size(), WorldEffects.names().size(),
		"the catalogue shown to a model is not the operations on offer")

	# And a line that is not one of them is not an operation at all.
	for line in [
		"delete target=#%d" % chest.id, "thing.shut = false",
		"A wandering merchant arrives and offers a bargain.",
		"spawn a guard by the chest", "place kind=chest",
	]:
		equal(WorldEffects.read(line).size(), 0,
			"a line the engine exposes nothing for was read as an operation: %s" % line)


## More operations than the engine carries out has the rest refused.
func _more_than_the_engine_carries_out() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var here := Vector2(WHERE.x + SPAWN_AT.x, WHERE.y + SPAWN_AT.y)
	var too_many := PackedStringArray()
	for _at in WorldEffects.AT_MOST + 2:
		too_many.append("place kind=stone at=(%.3f, %.3f)" % [here.x, here.y])
	var before := scene.objects.size()
	var dm := Orchestrator.with_channel(_channel(["\n".join(too_many)]), SEED, ONE_LOOK)
	_step(scene, dm, 2 * (ModelChannel.THINKS_FOR + 2))
	equal(dm.operations.size(), too_many.size(),
		"every named operation should be recorded, carried out or not")
	equal(dm.carried_out(), WorldEffects.AT_MOST,
		"the engine did not stop at %d operations" % WorldEffects.AT_MOST)
	equal(scene.objects.size(), before + WorldEffects.AT_MOST,
		"the world took more than %d changes from one look" % WorldEffects.AT_MOST)


## `nothing` is an answer, and an answer that names no operation and does not say
## it is a misread answer. The difference belongs in the transcript.
func _nothing_is_an_answer() -> void:
	var world := _bare()
	var scene: ActionScene = world["scene"]
	var dm := Orchestrator.with_channel(_channel([WorldEffects.NOTHING]), SEED, ONE_LOOK)
	var before := _what_is_in(scene)
	_step(scene, dm, 2 * (ModelChannel.THINKS_FOR + 2))
	equal(dm.quiet, 1, "an answer of `%s` was not read as one" % WorldEffects.NOTHING)
	equal(dm.operations.size(), 0, "an answer of `%s` named an operation anyway"
		% WorldEffects.NOTHING)
	equal(_what_is_in(scene), before, "an answer of `%s` changed the world"
		% WorldEffects.NOTHING)

	var muddled := _bare()
	var second := Orchestrator.with_channel(
		_channel(["The village feels tense tonight."]), SEED, ONE_LOOK)
	_step(muddled["scene"], second, 2 * (ModelChannel.THINKS_FOR + 2))
	equal(second.quiet, 0, "prose was read as a decision to change nothing")
	equal(second.operations.size(), 1, "prose was not recorded as refused")
	check(not bool((second.operations[0] as Dictionary)["ok"]),
		"prose was carried out")


# --- 4. The model never edits state ---------------------------------------


## The world is written in exactly one file, and it is the table of operations.
func _the_world_is_written_in_one_place() -> void:
	var writing := PackedStringArray()
	for path in HANDLES_THE_WORLD:
		for line in _code_lines(path):
			for shape in WRITES_THE_WORLD:
				if _compared_out(line).contains(shape):
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
			if _compared_out(line).contains(shape):
				written += 1
				break
	check(written >= 5, "the operations table writes the world in %d places" % written)


## The file that rolls a sheet never sees an answer at all, which is the strongest
## form of "the numbers are not the model's": there is nothing in it to read one
## out of.
func _the_file_that_rolls_never_sees_a_reply() -> void:
	var source := "\n".join(_code_lines(ROLLS))
	for named in ["reply", "channel", "ModelChannel", "prompt", "ask("]:
		check(not source.contains(named),
			"%s names %s, so a rolled sheet could depend on an answer" % [
				ROLLS, named,
			])


# --- 5. No story, no reach into a mind ------------------------------------


func _no_story_and_no_reach_into_a_mind() -> void:
	var telling := PackedStringArray()
	for path in HANDLES_THE_WORLD + [EFFECTS]:
		for line in _written_lines(path):
			for word in _words_in(line):
				if STORY_WORDS.has(word.to_lower()):
					telling.append("%s: %s" % [path, line])
					break
	equal(telling, PackedStringArray(),
		"the orchestrator layer writes down a story: %s" % " | ".join(telling))

	var reaching := PackedStringArray()
	for path in HANDLES_THE_WORLD + [EFFECTS]:
		for line in _code_lines(path):
			for shape in TOUCHES_A_MIND:
				if line.contains(shape):
					reaching.append("%s: %s" % [path, line])
					break
	equal(reaching, PackedStringArray(),
		"the orchestrator reaches into a mind: %s" % " | ".join(reaching))

	# What it may do is the operations list, and the watching prompt offers that
	# list and nothing beyond it.
	var world := _bare()
	var prompt := OrchestratorPrompt.watching_for(world["scene"], SEED)
	check(prompt.begins_with(OrchestratorPrompt.WATCHING_TITLE),
		"the watching prompt opens wrong")
	check(prompt.contains(OrchestratorPrompt.WATCHES),
		"the watching prompt does not say what its call is for")
	check(not prompt.contains(OrchestratorPrompt.PEOPLES),
		"the watching prompt says what the other call is for")
	for named in WorldEffects.names():
		check(prompt.contains(named), "the watching prompt does not offer %s" % named)
	for word in STORY_WORDS:
		check(not _words_in(prompt).has(word),
			"the watching prompt says '%s' to the model" % word)


## All three scans are shown to catch the lines they are for.
func _the_source_scans_would_notice() -> void:
	var writes := false
	for shape in WRITES_THE_WORLD:
		if _compared_out(BROKEN_WRITE).contains(shape):
			writes = true
	check(writes, "the world-writing scan would not catch %s" % BROKEN_WRITE)
	var compared := false
	for shape in WRITES_THE_WORLD:
		if _compared_out("\tif sheet.backstory == \"\":").contains(shape):
			compared = true
	check(not compared, "the world-writing scan reads a comparison as a write")
	var minds := false
	for shape in TOUCHES_A_MIND:
		if BROKEN_MIND.contains(shape):
			minds = true
	check(minds, "the mind scan would not catch %s" % BROKEN_MIND)
	var telling := false
	for word in _words_in(BROKEN_STORY):
		if STORY_WORDS.has(word.to_lower()):
			telling = true
	check(telling, "the story scan would not catch %s" % BROKEN_STORY)
	check(not _words_in("\tsheet.backstory = String(said)").has("story"),
		"the story scan reads `backstory` as `story`")


# --- 6. Nothing waits for it ----------------------------------------------


## A channel that never answers leaves the world turning and the character
## acting. This is the whole of the asynchronous claim, made against the worst
## case there is.
func _the_world_turns_while_it_thinks() -> void:
	var scene := ScriptedWorld.stage(SEED)
	var rook := _named(scene, ScriptedWorld.ROOK)
	(rook.piece as Commander).sheet.decide = DecisionSource.plan(
		ScriptedWorld.choices(scene))
	var loop := ControlLoop.on(scene, ScriptedWorld.LOOP_SEED)
	var dm := Orchestrator.with_channel(_channel([]), SEED, ONE_LOOK)
	var ticks := 60
	for _step_of in ticks:
		loop.step()
		dm.step(scene)
	equal(scene.tick, ticks, "the world stopped advancing: %d of %d" % [
		scene.tick, ticks,
	])
	check(dm.waiting() > 0, "the orchestrator is not actually waiting")
	check(scene.actions_of(rook.id) > 0,
		"the character carried out nothing while the orchestrator waited")
	equal(dm.calls, 1,
		"an unanswered look was asked again: %d calls" % dm.calls)


## And the shipped run, which is answered, acts on ticks the orchestrator is
## thinking.
func _the_shipped_run_acts_while_it_thinks() -> void:
	var played := ScriptedWorld.played_with(
		ModelChannel.for_run(ModelRecording.world_exchange()))
	var world: Orchestrator = played["world"]
	equal(int(played["ticks"]), (played["scene"] as ActionScene).tick,
		"the run did not advance every tick it was asked for")
	check(int(played["waited"]) > 0,
		"the shipped run never waited on an answer, so this measures nothing")
	equal(int(played["busy_while_waiting"]), int(played["waited"]),
		"the character stood idle on %d of the %d ticks the orchestrator was thinking"
			% [int(played["waited"]) - int(played["busy_while_waiting"]),
				played["waited"]])
	check(int(played["acted_while_waiting"]) > 0,
		"no action landed on a tick the orchestrator was thinking")
	check(world.looks > 1, "the orchestrator looked at the world %d times" % world.looks)
	check(world.calls >= world.looks,
		"a look is at least one call: %d looks, %d calls" % [world.looks, world.calls])


# --- 7. Two processes agree -----------------------------------------------


func _two_processes_agree() -> void:
	var channel := ModelChannel.for_run(ModelRecording.world_exchange())
	equal(channel.kind, ModelChannel.REPLAY,
		"the suite reached for a live channel, which would need a key")
	var first := _run_world()
	var second := _run_world()
	equal(int(first["code"]), 0, "%s exits 0" % COMMAND)
	equal(int(second["code"]), 0, "and again")
	equal(first["text"], second["text"],
		"two runs of %s printed different bytes" % COMMAND)

	var checked_in := _read(TRANSCRIPT)
	check(checked_in != "", "the transcript %s is not checked in" % TRANSCRIPT)
	equal(checked_in.strip_edges(), String(first["text"]).strip_edges(),
		"%s is not what %s prints" % [TRANSCRIPT, COMMAND])


# --- The furniture ---------------------------------------------------------


# A bare stage: Rook, and one chest with coins in it.
func _bare() -> Dictionary:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var rook := scene.add_actor(Combatant.commander_at(
		WHERE.x, WHERE.y, 0.0, 0.0, 2, AssetTags.ROGUE))
	var sheet := Character.make("Rook", 2)
	sheet.record_scores(ScriptedScenario.ROLL)
	(rook.piece as Commander).adopt(sheet)
	rook.settle(scene.terrain)
	var chest := scene.add_object(WorldObject.chest(
		"oak chest", WHERE.x + CHEST_AT.x, WHERE.y + CHEST_AT.y,
		Inventory.of([], 9)))
	return {"scene": scene, "rook": rook, "chest": chest}


# A `spawn` line the bare stage will accept.
func _spawn_line(_scene: ActionScene) -> String:
	return "spawn role=%s at=(%.3f, %.3f)" % [
		SpawnRoll.HERALD, WHERE.x + SPAWN_AT.x, WHERE.y + SPAWN_AT.y,
	]


# A channel that answers in order out of replies written here. Rows carry no
# digest, so the channel falls back to answering the n-th question with the n-th
# row, which is what a suite wants. An empty list never answers anything.
func _channel(replies: Array) -> ModelChannel:
	var rows := []
	for reply in replies:
		rows.append({"prompt": "", "reply": String(reply), "ms": 0})
	return ModelChannel.replaying(
		{"rows": rows, "from": "written in this suite", "model": "none"},
		"the suite answers its own questions")


func _step(scene: ActionScene, dm: Orchestrator, ticks: int) -> void:
	for _tick in ticks:
		scene.advance(1)
		dm.step(scene)


# One operation read out of a line and carried out, as the orchestrator would.
func _apply(scene: ActionScene, line: String, seed_value: int) -> Dictionary:
	var named := WorldEffects.read(line)
	if named.is_empty():
		return {"ok": false, "reason": "not an operation", "line": line, "target": 0}
	return WorldEffects.apply(scene, named[0], seed_value, 1)


# The command run as its own process, which is what "two processes agree" means.
func _run_world() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path(COMMAND), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


# Everything in a world that an operation could have changed, and not the clock:
# a tick goes by whatever anybody answered.
func _what_is_in(scene: ActionScene) -> String:
	var parts := PackedStringArray()
	for one in scene.actors:
		parts.append("#%d %s" % [one.id, ActionScene.name_of(one)])
	for thing in scene.objects:
		parts.append(thing.fingerprint())
	return " | ".join(parts)


# A line with its comparisons taken out, so that `==` cannot be read as `=`.
func _compared_out(line: String) -> String:
	return line.replace("==", " is ")


func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		if one.piece is Commander and (one.piece as Commander).sheet.character_name == who:
			return one
	return null


func _words_in(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	for hit in _words.search_all(text):
		found.append(hit.get_string().to_lower())
	return found


# Every code line of a file with its string literals kept beside it, comments
# taken off. What a scan uses when a string would be as damning as a branch --
# a quest written into a prompt is a quest.
func _written_lines(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for line in _read(path).split("\n"):
		var split := AssetCheck.split_code_and_strings(line)
		var text: String = "%s %s" % [
			split["code"], " ".join(PackedStringArray(split["strings"])),
		]
		if text.strip_edges() != "":
			found.append(text.strip_edges())
	return found


# Every code line of a file, comments and string literals taken off, so that
# prose about a story is not read as one.
func _code_lines(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for line in _read(path).split("\n"):
		var code: String = AssetCheck.split_code_and_strings(line)["code"].strip_edges()
		if code != "":
			found.append(code)
	return found


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
