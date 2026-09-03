extends TestSuite
## Segmented persistent memory: the two things a character remembers, where they
## come from, and what having them changes.
##
## Every check runs with no key, no network and no model, for the reason
## `tests/test_agent.gd` gives: a suite that needed a credential would be
## evidence that the layer is not built the way it says it is.
##
## Seven claims:
##
##   1. **Two segments, carried by the character, surviving decisions.** A
##      character's sheet holds one `CharacterMemory` with a first-person log and
##      a set of lessons, and what went into it before a decision is still in it
##      after several more.
##   2. **Nothing enters it that the character could not perceive**, shown twice
##      over: by reading the store's source off disk -- the only world type it
##      names is `Observation`, and every function that writes into either
##      segment takes one -- and by the world, where a line spoken to one
##      character does not appear in the memory of another standing beside them.
##      Both scans are then shown to have teeth.
##   3. **Recent memories reach the context directly.** The prompt carries the
##      last few lines of the log and every lesson, and does not carry the older
##      lines.
##   4. **Older ones are reachable by a query the agent makes, over the same
##      store.** `recall` is a tool a reply can name; the mind carries it out and
##      the next prompt holds what it found; and what it found is the very entry
##      out of the log, not a copy in some second place.
##   5. **A lesson changes what is chosen**, measured by the four-armed run in
##      which the moment, the character and the prompt outside its memory are all
##      identical.
##   6. **No engine rule moved into the store.** Only the files that are allowed
##      to name a memory name one, and what a memory puts in a prompt holds none
##      of the rule words the prompt is scanned for.
##   7. **Two processes agree** on the lesson run, and the checked-in transcript
##      is what the command prints.
class_name TestMemory

## The store, and the two things read off its source.
const STORE := "res://sim/character_memory.gd"

## The engine's own types, which naming is not reaching for the world. Anything
## else with a capital letter in this file would be.
const NOT_A_WORLD_TYPE := [
	"Array", "Dictionary", "PackedStringArray", "RefCounted", "String",
	"Variant", "CharacterMemory",
]

## The one world type the store is allowed to name, because it is the door.
const THE_DOOR := "Observation"

## What a line writing into a segment looks like. A function holding one of these
## must declare an `Observation` parameter, or something that is not an
## observation could get into the store.
const WRITES := ["events.append(", "lessons.append(", "checks.append("]

## Lines the source scans must catch.
const BROKEN_REACH := "	var pack := ActionScene.inventory_of(one)"
const BROKEN_WRITER := "func remember(text: String) -> void:\n	events.append({\"text\": text})"

## Every file under `sim/` allowed to name a character's memory. A rule that had
## moved into the store would have to be read from somewhere, and the somewhere
## would appear here.
const MAY_NAME_A_MEMORY := [
	"res://sim/character.gd",
	"res://sim/character_memory.gd",
	"res://sim/character_upkeep.gd",
	"res://sim/model_mind.gd",
	"res://sim/model_prompt.gd",
	"res://sim/scripted_agent.gd",
	"res://sim/scripted_check.gd",
	"res://sim/scripted_goal.gd",
	"res://sim/scripted_lesson.gd",
	"res://sim/check_desk.gd",
]

## The lesson run's transcript and the command that prints it.
const LESSON_TRANSCRIPT := "res://reports/lesson-evidence.txt"
const LESSON_COMMAND := "res://run_lesson.sh"

## Where the three characters of the private-word scene stand, and how far off
## the fourth one is -- past `Observation.NEARBY`, so it cannot be seen at all.
const ROOK_AT := Vector2(0.0, 0.0)
const WREN_AT := Vector2(2.0, 0.0)
const ODO_AT := Vector2(3.0, 0.0)
const FAR_OFF := Vector2(0.0, 300.0)

## The private word one character says to another while a third stands beside
## them.
const IN_YOUR_EAR := "a word in your ear"


func _init() -> void:
	suite_name = "memory"


func run() -> void:
	_two_segments_on_the_character()
	_the_store_names_only_the_door()
	_every_writer_takes_an_observation()
	_the_source_scans_would_notice()
	_a_word_meant_for_somebody_else_is_not_remembered()
	_recent_reaches_the_context_and_older_does_not()
	_a_query_reads_the_same_store()
	_the_agent_can_make_the_query_itself()
	_a_lesson_changes_what_is_chosen()
	_no_rule_moved_into_the_store()
	_two_processes_agree()


# --- 1. Two segments, on the character, surviving decisions ---------------


## A sheet carries one memory with two segments, and what is in it stays in it
## across several decisions.
func _two_segments_on_the_character() -> void:
	var sheet := Character.make("Rook", 2)
	check(sheet.memory is CharacterMemory,
		"a character sheet does not carry a memory")
	equal(sheet.memory.events.size(), 0, "a new character remembers an event")
	equal(sheet.memory.lessons.size(), 0, "a new character has kept a lesson")

	# Two sheets do not share one memory: a memory is a fact about a character.
	var other := Character.make("Wren", 2)
	other.memory.learn("Wren's own", _some_observation())
	equal(sheet.memory.lessons.size(), 0,
		"one character's lesson landed in another character's memory")

	# And it survives decisions: the same memory object is on the sheet after the
	# character has had several actions resolved, with the earliest entries still
	# in it.
	var scene := _three_in_a_row()
	var actor := _at(scene, 0)
	var mind := _mind_answering([
		"learn text=I keep this one.", "wait ticks=1", "wait ticks=1", "wait ticks=1",
	])
	var remembered := _sheet(actor).memory
	var upkeep := CharacterUpkeep.new()
	var first := ""
	for _turn in 5:
		var chosen := _ask(mind, scene, actor, upkeep)
		if chosen != null:
			ActionEngine.resolve(scene, actor, chosen)
		if first == "" and not remembered.events.is_empty():
			first = String(remembered.events[0]["text"])
	check(mind.turns.size() >= 3,
		"the stub mind answered too few times to measure: %d" % mind.turns.size())
	check(_sheet(actor).memory == remembered,
		"the memory on the sheet was replaced between decisions")
	equal(remembered.lessons.size(), 1,
		"the lesson the character kept did not survive its later decisions")
	check(not remembered.events.is_empty() and String(remembered.events[0]["text"]) == first,
		"the first thing the character remembered was lost by the fourth decision")


# --- 2. Nothing enters that the character could not perceive --------------


## The store names one world type and it is the packet.
##
## This is the perception rule as a fact about the code rather than a promise in
## a comment: a line that reached past the observation for something the
## character was not shown would have to name a scene, a combatant, an engine or
## a board, and there is no such name in the file.
func _the_store_names_only_the_door() -> void:
	var named := _world_types_in(_read(STORE))
	equal(named, PackedStringArray([THE_DOOR]),
		"the store names a world type that is not the observation: %s"
			% " ".join(named))


## Every function that writes into a segment takes an observation.
func _every_writer_takes_an_observation() -> void:
	var faults := _writers_without_an_observation(_read(STORE))
	equal(faults, PackedStringArray(),
		"something writes into the store without being handed an observation: %s"
			% " ".join(faults))
	# And there really are writers, or the scan above passed by finding nothing.
	check(_writers_in(_read(STORE)).size() >= 2,
		"the scan found fewer than two writers, so it is checking nothing")


## Both scans have teeth.
func _the_source_scans_would_notice() -> void:
	var reaching := _world_types_in("var pack := ActionScene.inventory_of(one)")
	check(reaching.has("ActionScene"),
		"the scan does not catch the store reaching for a scene")
	check(_world_types_in(BROKEN_REACH).has("ActionScene"),
		"the scan does not catch a line reading the world")
	equal(_world_types_in("var seen := Observation.new()"), PackedStringArray([THE_DOOR]),
		"the scan fires on the one type the store is allowed to name")
	equal(_world_types_in("# ActionScene is named in a comment"), PackedStringArray(),
		"the scan reads a comment as code")
	equal(_world_types_in("var said := \"ActionScene\""), PackedStringArray(),
		"the scan reads a string literal as code")
	equal(_world_types_in("const SEEN_ONCE := 1"), PackedStringArray(),
		"the scan reads a constant's name as a type")

	var broken := _writers_without_an_observation(BROKEN_WRITER)
	check(broken.size() == 1 and broken[0].contains("remember"),
		"the scan does not catch a writer that takes no observation: %s"
			% " ".join(broken))
	equal(_writers_without_an_observation(
			"func witness(seen: Observation) -> void:\n	events.append({})"),
		PackedStringArray(),
		"the scan fires on a writer that does take an observation")


## A line said to one character is not in the memory of another standing beside
## them, and something too far off to see is in nobody's.
##
## The engine already decides who heard what -- `ActionEngine._say` writes the
## `heard_by` -- and the packet filters by it, so this is that rule reaching the
## memory unchanged. Nothing in the store measures a position, and this is what
## that buys.
func _a_word_meant_for_somebody_else_is_not_remembered() -> void:
	var scene := _three_in_a_row()
	var rook := _at(scene, 0)
	var wren := _at(scene, 1)
	var odo := _at(scene, 2)
	var stranger := _at(scene, 3)

	var spoke := ActionEngine.resolve(scene, rook, Action.say(IN_YOUR_EAR, wren.id))
	check(spoke.ok, "the engine refused a plain word: %s" % spoke.reason)

	var heard := _witnessed(scene, wren)
	var beside := _witnessed(scene, odo)
	check(_holds(heard, IN_YOUR_EAR),
		"the character the word was said to does not remember it")
	check(not _holds(beside, IN_YOUR_EAR),
		"a character standing beside them remembers a word said to somebody else")

	# The one who said it remembers saying it, in the first person.
	var said := _witnessed(scene, rook)
	check(_holds(said, "I said: \"%s\"" % IN_YOUR_EAR),
		"the character who spoke does not remember speaking")

	# And nobody remembers the character standing three hundred units away.
	for remembered in [heard, beside, said]:
		check(not _holds(remembered, "#%d" % stranger.id),
			"a character too far off to be seen is in somebody's memory")
	# Which is a real check only if the stranger is really in the world.
	check(rook.distance_to(stranger) > Observation.NEARBY,
		"the stranger is near enough to see, so the check says nothing")


# --- 3 and 4. Recent goes in; older is asked for --------------------------


## The prompt carries every lesson and the most recent few lines of the log, and
## does not carry the older lines.
func _recent_reaches_the_context_and_older_does_not() -> void:
	var remembered := _a_full_memory()
	check(remembered.events.size() > CharacterMemory.RECENT,
		"the run left too little in the memory to tell recent from older: %d"
			% remembered.events.size())
	remembered.learn("A lesson I keep.", _some_observation())

	var prompt := ModelPrompt.written_for(_some_observation(), remembered)
	var lately := remembered.recent()
	equal(lately.size(), CharacterMemory.RECENT,
		"the context carries something other than the stated number of recent lines")
	for line in lately:
		check(prompt.contains(line),
			"the prompt does not carry a recent memory: %s" % line)
	check(prompt.contains("A lesson I keep."),
		"the prompt does not carry a lesson the character kept")

	var older := _an_older_entry(remembered)
	check(older != "", "every entry is a recent one, so there is nothing to hide")
	check(not prompt.contains(older),
		"the prompt carries an older memory it should have left for the query: %s"
			% older)


## The query reads the same store the context is written out of.
func _a_query_reads_the_same_store() -> void:
	var remembered := _a_full_memory()
	var older := _an_older_entry(remembered)
	check(older != "", "there is no older entry to look for")
	if older == "":
		return
	var found := remembered.recall(_a_word_of(older))
	check(_holds(found, older),
		"looking back did not find an entry that is in the log: %s" % older)

	# It is the same entry and not a copy kept somewhere else: the line handed
	# back is a line of `events`, and nothing was added by looking.
	var before := remembered.entry_count()
	var again := remembered.recall(_a_word_of(older))
	equal(again, found, "looking back twice gave two different answers")
	equal(remembered.entry_count(), before,
		"looking back changed what the character remembers")
	var in_the_log := false
	for one in remembered.events:
		if String(one["text"]) == older:
			in_the_log = true
	check(in_the_log, "what was recalled is not in the log it claims to read")

	# A query about nothing in particular finds nothing rather than everything.
	equal(remembered.recall("").size(), 0, "an empty query recalled something")
	equal(remembered.recall("zarquon").size(), 0,
		"a query about something never seen recalled something")


## The query is one the agent makes: a reply naming it is read as the tool, the
## mind carries it out, and the next prompt holds what came back.
func _the_agent_can_make_the_query_itself() -> void:
	var read := ModelPrompt.tool_of("recall about=lantern")
	equal(String(read.get("tool", "")), ModelPrompt.RECALL,
		"a reply naming the query does not read back as it")
	equal(String(read.get("text", "")), "lantern",
		"the query read back asking about the wrong thing")
	equal(ModelPrompt.action_of("recall about=lantern"), null,
		"the query read back as an atomic action")
	equal(ModelPrompt.tool_of("go_to target=#3"), {},
		"an action read back as a tool")
	equal(String(ModelPrompt.tool_of("learn text=Fire works on trolls.")
			.get("tool", "")), ModelPrompt.LEARN,
		"a reply keeping a lesson does not read back as the tool that keeps one")

	# And the tools are offered: the prompt says both of them.
	var offered := ModelPrompt.written_for(_some_observation(), CharacterMemory.new())
	for tool in ModelPrompt.TOOLS:
		check(offered.contains(String(tool["name"])),
			"the prompt does not offer %s" % tool["name"])

	# The mind carries one out against the character's own memory, and asks again.
	var scene := _three_in_a_row()
	var actor := _at(scene, 0)
	var remembered := _sheet(actor).memory
	ActionEngine.resolve(scene, _at(scene, 1), Action.say("the brass lantern is mine", actor.id))
	var mind := _mind_answering([
		"recall about=lantern", "learn text=Lanterns are spoken for.", "wait ticks=1",
	])
	equal(_ask(mind, scene, actor), null, "the query was read back as a choice")
	equal(mind.recalls, 1, "the mind did not carry the query out")
	check(int(mind.turns[0]["found"]) >= 1,
		"the query found nothing in a memory that holds the word it asked about")
	equal(_ask(mind, scene, actor), null, "keeping a lesson was read back as a choice")
	equal(mind.lessons_written, 1, "the mind did not keep the lesson")
	equal(remembered.lessons.size(), 1,
		"the lesson was not written into the character's own memory")
	var chosen := _ask(mind, scene, actor)
	check(chosen != null and chosen.kind == ActionCatalog.WAIT,
		"the mind never got back to choosing an action after two tool calls")


# --- 5. A lesson changes what is chosen -----------------------------------


## The four-armed comparison: one moment, four memories, and what came back.
func _a_lesson_changes_what_is_chosen() -> void:
	var channel := ModelChannel.for_run(ModelRecording.lesson_exchange())
	var played := ScriptedLesson.played_with(channel)
	var arms: Array[Dictionary] = played["arms"]
	equal(arms.size(), ScriptedLesson.ARMS.size(), "an arm of the comparison was not played")
	check(bool(played["same_situation"]),
		"the four arms were not asked about the same moment")
	check(bool(played["same_outside_memory"]),
		"the four arms' prompts differ somewhere other than what is remembered")

	# The arms really do differ in what is remembered, or the comparison compares
	# a thing with itself.
	var digests := {}
	for arm in arms:
		digests[String(arm["digest"])] = true
	equal(digests.size(), arms.size(),
		"two arms were handed the same prompt, so a lesson changed nothing in it")

	var baseline := String(arms[0]["line"])
	var differed := 0
	for at in range(1, arms.size()):
		if String(arms[at]["line"]) != baseline:
			differed += 1
	check(differed >= 1,
		"no lesson changed what was chosen: every arm chose %s" % baseline)

	# Every arm's prompt is still free of the rule words the prompt is scanned
	# for -- a lesson is the character's own sentence and not a borrowed rule.
	for arm in arms:
		var hits := _rule_words_in(String(arm["prompt"]))
		equal(hits, PackedStringArray(),
			"the %s arm's prompt names a rule: %s" % [arm["name"], " ".join(hits)])


# --- 6. No rule moved into the store --------------------------------------


## Only the files that are meant to name a memory do, and what a memory puts in a
## prompt states no rule.
func _no_rule_moved_into_the_store() -> void:
	var naming := PackedStringArray()
	var read := 0
	for path in _files_under("res://sim"):
		var text := _read(path)
		if text == "":
			continue
		read += 1
		if MAY_NAME_A_MEMORY.has(path):
			continue
		for line in text.split("\n"):
			var code: String = AssetCheck.split_code_and_strings(line)["code"]
			if _has_word(code, "memory") or _has_word(code, "CharacterMemory"):
				naming.append("%s  %s" % [path, line.strip_edges()])
	check(read > 40, "the scan opened %d files under sim/" % read)
	equal(naming, PackedStringArray(),
		"a file that resolves the world names a character's memory: %s"
			% " ".join(naming))
	for path in MAY_NAME_A_MEMORY:
		check(_read(path) != "", "the scan could not open %s" % path)

	# What a memory puts in a prompt is scanned the way the whole prompt is.
	var remembered := CharacterMemory.new()
	remembered.witness(_some_observation())
	remembered.learn("I do better greeting somebody before I ask them anything.",
		_some_observation())
	var written := "\n".join(ModelPrompt.memory_lines(remembered))
	var hits := _rule_words_in(written)
	equal(hits, PackedStringArray(),
		"what a memory puts in a prompt states a rule: %s" % " ".join(hits))
	equal(_rule_words_in("\n".join(ModelPrompt.tool_lines())), PackedStringArray(),
		"the two tools are described with a rule")
	check(written.contains("greeting somebody"),
		"the memory section does not carry the lesson it holds")

	# And the volume is measured rather than guessed: the run says how much.
	var transcript := "\n".join(ScriptedAgent.play(
		ModelChannel.for_run(ModelRecording.exchange())))
	for measured in [
		"entries", "characters held", "characters a packet carries",
	]:
		check(transcript.contains(measured),
			"the run does not report '%s'" % measured)


# --- 7. Two processes agree -----------------------------------------------


## The lesson run, run twice, in two processes, printing the same bytes -- and
## the transcript checked in under reports/ being those bytes.
func _two_processes_agree() -> void:
	var first := _run(LESSON_COMMAND)
	var second := _run(LESSON_COMMAND)
	equal(first["code"], 0, "./run_lesson.sh exits 0")
	equal(second["code"], 0, "and again")
	equal(first["text"], second["text"],
		"two runs of ./run_lesson.sh printed different bytes")
	var kept := FileAccess.get_file_as_string(LESSON_TRANSCRIPT)
	check(kept != "", "the transcript is checked in at %s" % LESSON_TRANSCRIPT)
	equal(kept.strip_edges(), String(first["text"]).strip_edges(),
		"the checked-in transcript is not what the command prints")


# --- The two source scans -------------------------------------------------


# Every world type a piece of source names, in the order first seen. Comments and
# string literals are taken off first, and the engine's own container types are
# not world types.
func _world_types_in(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	var finder := RegEx.new()
	finder.compile("\\b[A-Z][a-z][A-Za-z0-9_]*\\b")
	for line in text.split("\n"):
		var code: String = AssetCheck.split_code_and_strings(line)["code"]
		for hit in finder.search_all(code):
			var named := hit.get_string()
			if NOT_A_WORLD_TYPE.has(named) or found.has(named):
				continue
			found.append(named)
	return found


# Every function in a piece of source that writes into a segment, by name.
func _writers_in(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	for row in _functions_of(text):
		if bool(row["writes"]) and not found.has(String(row["name"])):
			found.append(String(row["name"]))
	return found


# Every writer that is not handed an observation. Empty is the claim.
func _writers_without_an_observation(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	for row in _functions_of(text):
		if bool(row["writes"]) and not bool(row["takes_one"]):
			found.append(String(row["name"]))
	return found


# The functions of a piece of source, each with whether it writes into a segment
# and whether its signature declares an observation.
func _functions_of(text: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var current := {}
	for line in text.split("\n"):
		var code: String = AssetCheck.split_code_and_strings(line)["code"]
		var bared := code.strip_edges()
		if bared.begins_with("func ") or bared.begins_with("static func "):
			var at := bared.find("(")
			current = {
				"name": bared.substr(0, at if at > 0 else bared.length()),
				"takes_one": code.contains(": %s" % THE_DOOR),
				"writes": false,
			}
			found.append(current)
			continue
		if current.is_empty():
			continue
		for writing in WRITES:
			if code.contains(writing):
				current["writes"] = true
	return found


# --- The furniture --------------------------------------------------------


# Three characters standing within a couple of units of each other on the
# measured meadow, and a fourth three hundred units away.
func _three_in_a_row() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(ScriptedScenario.SEED))
	for row in [
		{"who": "Rook", "at": ROOK_AT}, {"who": "Wren", "at": WREN_AT},
		{"who": "Odo", "at": ODO_AT}, {"who": "Far", "at": FAR_OFF},
	]:
		var where: Vector2 = row["at"]
		var one := scene.add_actor(Combatant.commander_at(
			ScriptedScenario.WHERE.x + where.x, ScriptedScenario.WHERE.y + where.y,
			0.0, 0.0, 2, AssetTags.KNIGHT))
		(one.piece as Commander).adopt(Character.make(String(row["who"]), 2))
		one.settle(scene.terrain)
	return scene


# One character's memory, having witnessed the world once.
func _witnessed(scene: ActionScene, actor: Combatant) -> CharacterMemory:
	var remembered := _sheet(actor).memory
	remembered.witness(Observation.of(scene, actor))
	return remembered


# An observation of a real character on real ground, for the prompt-writing and
# lesson-keeping checks that need one and do not care what is in it.
func _some_observation() -> Observation:
	var scene := _three_in_a_row()
	return Observation.of(scene, _at(scene, 0))


# The model character's memory at the end of the shipped run: a real log of a
# real run, which is what the recent-versus-older checks want rather than a
# hand-built one.
func _a_full_memory() -> CharacterMemory:
	var played := ScriptedAgent.played_with(
		ModelChannel.for_run(ModelRecording.exchange()))
	var scene: ActionScene = played["scene"]
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == ScriptedAgent.PELL:
			return sheet.memory
	return CharacterMemory.new()


# An entry of the log that the context does not carry, or "" when every entry is
# a recent one.
static func _an_older_entry(remembered: CharacterMemory) -> String:
	var lately := remembered.recent()
	for one in remembered.events:
		var text := String(one["text"])
		if not lately.has(text):
			return text
	return ""


# A word of an entry worth asking about: the longest one in it, so the query is
# not "the".
static func _a_word_of(text: String) -> String:
	var longest := ""
	for word in text.split(" ", false):
		var one := String(word).strip_edges().lstrip("\"'#(").rstrip("\"'?.,!)")
		if one.length() > longest.length():
			longest = one
	return longest


# Whether any line holds a piece of text.
static func _holds(lines: Variant, text: String) -> bool:
	var written: PackedStringArray = lines.lines() if lines is CharacterMemory else lines
	for line in written:
		if String(line).contains(text):
			return true
	return false


# A mind whose channel answers the n-th question with the n-th stated line.
func _mind_answering(replies: Array) -> ModelMind:
	var rows := []
	for reply in replies:
		rows.append({"prompt": "", "reply": String(reply), "ms": 0})
	return ModelMind.with_channel(ModelChannel.replaying(
		{"rows": rows, "from": "written down by the suite", "model": "none"},
		"written down by the suite"))


# Ask a mind once, all the way through: it opens the question, the world turns
# for as long as an answer takes, and the answer comes back.
# Ask a mind for one answer, servicing the character first exactly as a driver
# does. The servicing is what writes into the log -- the mind reads that store
# and does not fill it -- so a mind asked without it would be a mind asked by
# nothing, which is not a thing that happens in the world.
func _ask(
	mind: ModelMind, scene: ActionScene, actor: Combatant,
	upkeep: CharacterUpkeep = null
) -> Action:
	var serving := CharacterUpkeep.new() if upkeep == null else upkeep
	serving.serve(scene, actor)
	mind.answer_for(scene, actor)
	scene.advance(ModelChannel.THINKS_FOR)
	serving.serve(scene, actor)
	return mind.answer_for(scene, actor)


func _rule_words_in(text: String) -> PackedStringArray:
	var found := PackedStringArray()
	var finder := RegEx.new()
	finder.compile("(?i)\\b(%s)\\b" % ModelPrompt.RULE_WORDS)
	for hit in finder.search_all(text):
		if not found.has(hit.get_string()):
			found.append(hit.get_string())
	return found


func _has_word(code: String, word: String) -> bool:
	var finder := RegEx.new()
	finder.compile("\\b%s\\b" % word)
	return finder.search(code) != null


func _files_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			found.append("%s/%s" % [directory, name])
	found.sort()
	return found


static func _at(scene: ActionScene, index: int) -> Combatant:
	return scene.actors[index]


static func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


func _run(command: String) -> Dictionary:
	var output := []
	var code := OS.execute(ProjectSettings.globalize_path(command), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
