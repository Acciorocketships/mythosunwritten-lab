extends TestSuite
## What a character can see: section 10's local observation, checked against the
## seven things the task asks of it.
##
## The suite is built on a bare stage rather than on the shipped scenario
## wherever it can be, because a claim about visibility is easiest to believe
## when the thing being hidden was put behind the wall by the test itself. The
## last two groups do use the shipped run, because "the same seed gives the same
## observation" and "this is how big one comes to" are claims about the run.

## The seed the bare stages are played on: the measured open meadow every other
## character-layer suite uses, so no new ground is claimed here.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE


func _init() -> void:
	suite_name = "observation"


func run() -> void:
	_it_holds_what_section_ten_lists()
	_absent_fields_say_why()
	_a_name_is_known_or_it_is_not()
	_line_of_sight_comes_off_the_board()
	_the_ground_is_the_combat_lattice()
	_the_window_says_what_its_marks_mean()
	_what_was_heard_is_the_engines_answer()
	_nothing_global_is_in_it()
	_recent_changes_are_read_off_the_world()
	_it_is_the_same_for_the_same_surroundings()
	_the_shipped_run_is_measured()
	_no_model_and_no_new_dependency()


# --- What is in it --------------------------------------------------------


## Every field section 10 lists for an entity is there, and every field it lists
## for an object is there. Named rather than counted, so a field quietly dropped
## fails here.
func _it_holds_what_section_ten_lists() -> void:
	var scene := _stage()
	var wren := scene.actors[0]
	var seen := Observation.of(scene, wren)

	equal(seen.self_id, wren.id, "the observation says who is looking")
	check(seen.entities.size() >= 1, "and lists somebody nearby")
	var row: Dictionary = seen.entities[0]
	for field in [
		"id", "type", "name", "offset", "distance", "line_of_sight",
		"doing", "health", "equipment",
	]:
		check(row.has(field), "an entity row carries section 10's '%s'" % field)
	check(row["offset"] is Vector3, "the offset is relative, in three dimensions")
	check(float(row["distance"]) > 0.0, "and the distance is how far away it is")

	check(seen.objects.size() >= 1, "the observation lists the chest beside them")
	var thing: Dictionary = seen.objects[0]
	for field in ["id", "type", "offset", "distance", "line_of_sight", "state"]:
		check(thing.has(field), "an object row carries section 10's '%s'" % field)

	# An offset is from here to there and not a world position. Checked by
	# arithmetic rather than by reading it: the two must add up.
	var other := scene.actors[1]
	var offset: Vector3 = _row_for(seen.entities, other.id)["offset"]
	check(absf(wren.x + offset.x - other.x) < 0.001
		and absf(wren.z + offset.z - other.z) < 0.001,
		"an offset added to where the looker stands is where the other one stands")


## Every field that is not there says why it is not there. There is no blank.
func _absent_fields_say_why() -> void:
	var scene := _stage()
	var wren := scene.actors[0]
	# Nothing is driving this scene, so nobody's current action is observable --
	# and that is one of the reasons a field can be absent.
	var seen := Observation.of(scene, wren)
	var row := _row_for(seen.entities, scene.actors[1].id)
	equal(row["doing"], null, "with nothing driving the scene, nobody is doing anything")
	equal(row["doing_absent"], Observation.NOT_DRIVEN,
		"and the observation says that is why")

	var text := seen.text()
	check(not text.contains("doing  "),
		"the packet never prints a blank where a value would go")
	check(text.contains(Observation.NOT_DRIVEN),
		"it prints the reason a field is absent, in words")

	equal(seen.recent, PackedStringArray(),
		"an observation with nothing watching reports no recent changes")
	equal(seen.recent_absent, Observation.UNWATCHED,
		"and says that is because nothing was watching, not because nothing happened")


## A name appears only when this character knows it, and there are exactly two
## ways to know it.
func _a_name_is_known_or_it_is_not() -> void:
	var scene := _stage()
	var wren := scene.actors[0]
	var rook := scene.actors[1]
	var stranger := scene.actors[2]

	var seen := Observation.of(scene, wren)
	var known := _row_for(seen.entities, rook.id)
	equal(known["name"], "Rook", "a character of the same band is known by name")
	check(not known.has("name_absent"), "so nothing is absent about its name")

	var unknown := _row_for(seen.entities, stranger.id)
	equal(unknown["name"], null, "a character of another band is not")
	equal(unknown["name_absent"], Observation.UNMET,
		"and the observation says this character has not met it")

	# The other way of knowing: the world's own record says something has passed
	# between the two. That is `RelationshipGraph`, which holds one edge between
	# a pair rather than a dictionary on either sheet -- so unlike the retired
	# per-sheet map it *is* mutual, because having met somebody is not a fact one
	# of the two can hold on its own.
	scene.relationships.heard(stranger.id, wren.id, "well met", false)
	var after := Observation.of(scene, wren)
	equal(_row_for(after.entities, stranger.id)["name"], "Mott",
		"a character the world says this one has met is known by name")
	var theirs := Observation.of(scene, stranger)
	equal(_row_for(theirs.entities, wren.id)["name"], "Wren",
		"and the same edge is read from the other end")


# --- Seeing -------------------------------------------------------------


## Line of sight is traced across the combat lattice, and it is what gates the
## fields section 10 says are gated by it.
func _line_of_sight_comes_off_the_board() -> void:
	var scene := _stage()
	var wren := scene.actors[0]
	var seen := Observation.of(scene, wren)
	var row := _row_for(seen.entities, scene.actors[1].id)
	equal(row["line_of_sight"], true, "on open ground everybody is in sight")
	check(row["health"] != null, "so how hurt they look is filled in")
	check(row["equipment"] != null, "and so is what they have on")

	# The same question, asked of a board with a wall built into it rather than
	# of the meadow: a sketch is a board whose cells were written by hand, so
	# what is being tested is the tracing and not the terrain.
	var board := BoardSketch.from_rows(PackedStringArray([
		".....",
		".....",
		".###.",
		".....",
		".....",
	]))
	var below := Vector2i(2, 0)
	var above := Vector2i(2, 4)
	check(not Observation.sees(board, below, above),
		"a line through a building of the lattice is stopped by it")
	check(Observation.sees(board, Vector2i(0, 0), Vector2i(0, 4)),
		"and a line beside it is not")
	check(Observation.sees(board, below, below),
		"a cell always sees itself")
	check(not Observation.sees(board, below, Vector2i(99, 99)),
		"and nothing off the board can be seen at all")

	# A piece can stand on a cell that stops a line -- the top of a bluff is
	# standable and its face is what blocks -- so the two ends are never what
	# blocks the trace, or anybody on high ground would be invisible.
	var bluff := BoardSketch.from_rows(PackedStringArray([
		".....",
		".^.^.",
		".....",
	]))
	check(Observation.sees(bluff, Vector2i(1, 1), Vector2i(3, 1)),
		"two cells that both stop lines still see each other across clear ground")


## The ground in the observation is the combat lattice, reached through the type
## the fight is played on, and not a second grid.
func _the_ground_is_the_combat_lattice() -> void:
	var scene := _stage()
	var wren := scene.actors[0]
	var seen := Observation.of(scene, wren)

	check(seen.board is CombatBoard,
		"the terrain in an observation is a CombatBoard: the fight's own type")
	equal(seen.board.cell_size, CombatBoard.CELL_SIZE,
		"on the lattice's own cell size, not a size of the observer's")
	equal(seen.here, CombatBoard.cell_of(wren.x, wren.z, CombatBoard.CELL_SIZE),
		"and the looker stands on the cell the world-fixed lattice puts it in")

	# The load-bearing claim: a board built for a fight at the same place agrees
	# with the observation's, cell for cell. If these two could differ there
	# would be two representations, which is what section 13 forbids.
	var fight_board := CombatBoardBuilder.new(scene.terrain).build(
		wren.x, wren.z, wren.y, Observation.NEARBY)
	equal(fight_board.digest(), seen.board.digest(),
		"a board built for a fight at the same place is the same board")

	var ground := seen.ground_lines()
	equal(ground.size(), Observation.WINDOW + 2,
		"the packet prints a window of %d rows, a heading and a legend" % (
			Observation.WINDOW))
	check("\n".join(ground).contains(Observation.GLYPHS["here"]),
		"and the looker's own cell is marked in it")


## The window arrives with a key. A reader who has never seen this world is
## given, inside the packet, what each of its marks means -- which is what the
## first model-driven run was not given, and it never chose a position.
func _the_window_says_what_its_marks_mean() -> void:
	var scene := _stage()
	var seen := Observation.of(scene, scene.actors[0])
	var packet := seen.text()

	equal(Observation.MEANS.keys(), Observation.GLYPHS.keys(),
		"every mark the window can hold is named in the legend, and no other")
	for key in Observation.GLYPHS:
		check(String(Observation.MEANS[key]).length() > 3,
			"the legend says what '%s' means in words" % Observation.GLYPHS[key])
		check(packet.contains("%s %s" % [
				Observation.GLYPHS[key], Observation.MEANS[key]]),
			"the packet itself carries '%s' and what it means" % (
				Observation.GLYPHS[key]))

	# The four the task names, told apart by their meanings rather than by their
	# marks: ground to walk on, a hole, an obstacle, and a face too tall to climb.
	var told_apart := {}
	for key in ["stand", "hole", "built", "wall"]:
		var means := String(Observation.MEANS[key])
		check(not told_apart.has(means), "each of the four means something of its own")
		told_apart[means] = key
	check(String(Observation.MEANS["hole"]).contains("hole"),
		"a hole is named as a hole")
	check(String(Observation.MEANS["wall"]).contains("climb"),
		"and a face too tall to climb says so")


# --- What was heard -------------------------------------------------------


## Speech is in the packet, it is the engine's own account of who heard it, and
## nothing a character could not hear is in it.
func _what_was_heard_is_the_engines_answer() -> void:
	var scene := _stage()
	var wren := scene.actors[0]
	var rook := scene.actors[1]
	var mott := scene.actors[2]

	equal(Observation.of(scene, wren).heard.size(), 0,
		"before anybody speaks, nobody has heard anything")

	# One line aimed at Rook, and one shouted. Both go through the engine, which
	# is the only thing in the project that decides who hears what.
	ActionEngine.resolve(scene, wren, Action.say("good morning", rook.id))
	ActionEngine.resolve(scene, rook, Action.say("a fair morning to you", wren.id))
	ActionEngine.resolve(scene, wren, Action.say("wares for sale"))

	var heard_by_wren := Observation.of(scene, wren).heard
	equal(heard_by_wren.size(), 3,
		"the speaker's own words and the answer to them are both in its packet")
	equal(heard_by_wren[0]["text"], "good morning", "oldest first")
	equal(heard_by_wren[2]["text"], "wares for sale", "and newest last")
	check(bool(heard_by_wren[0]["yours"]), "a character knows what it itself said")
	equal(heard_by_wren[0]["speaker"], wren.id, "and who said it")
	check(bool(heard_by_wren[1]["to_you"]),
		"a line aimed at this character says it was aimed at this character")
	check(not bool(heard_by_wren[1]["shout"]), "and that it was not shouted")
	check(bool(heard_by_wren[2]["shout"]), "a shout says it was shouted")
	equal(heard_by_wren[1]["name"], "Rook", "the speaker is named where it is known")

	# Mott stands apart and is of nobody's band. It hears the shout, because the
	# engine said so, and neither of the two lines that were aimed at somebody.
	var heard_by_mott := Observation.of(scene, mott).heard
	equal(heard_by_mott.size(), 1, "a bystander hears the shout and nothing else")
	equal(heard_by_mott[0]["text"], "wares for sale", "and it is the shout")
	equal(heard_by_mott[0]["name"], null, "a stranger's name is not known")
	equal(heard_by_mott[0]["name_absent"], Observation.UNMET,
		"and the packet says why")

	# The filter is the engine's list and not a second reading of the world:
	# every line in a packet is one whose heard_by holds the looker, or one the
	# looker said.
	for spoken in scene.said:
		var by := int(spoken["speaker"])
		var ears := PackedInt32Array(spoken["heard_by"])
		for one in [wren, rook, mott]:
			var carried := _heard_text(Observation.of(scene, one), String(spoken["text"]))
			equal(carried, by == one.id or ears.has(one.id),
				"who heard \"%s\" is the engine's answer" % spoken["text"])

	# Out of earshot is the engine's answer too: it refuses the line, so there is
	# nothing said and nothing heard.
	var far := scene.add_actor(Combatant.commander_at(
		WHERE.x + ActionEngine.VOICE + 10.0, WHERE.y, 0.0, 0.0, 2))
	_name_it(far, "Yon")
	var said_so_far := scene.said.size()
	var refused := ActionEngine.resolve(scene, wren, Action.say("hello there", far.id))
	check(not refused.ok, "the engine refuses a line nobody could hear")
	equal(scene.said.size(), said_so_far, "so nothing was said")
	equal(Observation.of(scene, far).heard.size(), 0, "and nothing was heard")

	# Only the last few, so a long conversation does not turn the packet into a
	# transcript.
	for at in Observation.HEARD + 3:
		ActionEngine.resolve(scene, rook, Action.say("line %d" % at, wren.id))
	var later := Observation.of(scene, wren).heard
	equal(later.size(), Observation.HEARD,
		"the packet carries the last %d lines" % Observation.HEARD)
	equal(later[later.size() - 1]["text"], "line %d" % (Observation.HEARD + 2),
		"and the last of them is the newest")

	# And it reads as words, in the packet a model is handed.
	var packet := Observation.of(scene, wren).text()
	check(packet.contains("said to you \"line %d\"" % (Observation.HEARD + 2)),
		"the readable packet says who a line was said to, and what it said")


# --- Locality -------------------------------------------------------------


## Nothing in the packet is anything a character standing there could not
## perceive. Checked as text, because the packet is what will be handed over.
func _nothing_global_is_in_it() -> void:
	var scene := _stage()
	scene.advance(37)
	var seen := Observation.of(scene, scene.actors[0])
	var text := seen.text()
	for global in ["tick", "seed", "weather", "season", "clock", "region"]:
		check(not text.to_lower().contains(global),
			"the packet says nothing about the world's %s" % global)
	# Everybody outside `NEARBY` is outside the packet, whatever else is true of
	# them. The far one is put beyond it here and looked for by id.
	var far := scene.add_actor(Combatant.commander_at(
		WHERE.x + Observation.NEARBY + 20.0, WHERE.y, 0.0, 0.0, 1))
	_name_it(far, "Distant")
	var after := Observation.of(scene, scene.actors[0])
	check(_has_row(after.entities, far.id) == false,
		"somebody further away than %.1f is not in the observation at all" % (
			Observation.NEARBY))
	check(after.entities.size() < scene.actors.size(),
		"so the entity list is not a list of everybody in the world")


## The recent changes are a diff of the world, not a report anybody filed, and
## they are the looker's own.
func _recent_changes_are_read_off_the_world() -> void:
	var scene := _stage()
	var wren := scene.actors[0]
	var trail := ObservationTrail.new()
	trail.note(scene)

	equal(trail.recent_of(wren.id), PackedStringArray(),
		"the first look at a character writes nothing down")

	wren.z -= 4.0
	wren.piece.wound(3)
	trail.note(scene)
	var changed := trail.recent_of(wren.id)
	check(changed.size() == 2, "a walk and a wound are two changes")
	check(changed[0].begins_with("moved 4.0m north"),
		"the move is said in metres and a compass direction: %s" % changed[0])
	check(changed[1] == "lost 3 hit points",
		"and the wound in hit points: %s" % changed[1])

	var pack := ActionScene.inventory_of(wren)
	pack.carry(_thing("iron spear"))
	pack.gain(5)
	trail.note(scene)
	changed = trail.recent_of(wren.id)
	check(changed[changed.size() - 2] == "gained iron spear",
		"something arriving in the pack is a change, named by the item's own name")
	check(changed[changed.size() - 1] == "gained 5 coins", "and so is money")

	# It is capped, and it is first-person.
	for _more in 20:
		wren.x += 1.0
		trail.note(scene)
	equal(trail.recent_of(wren.id).size(), ObservationTrail.KEEP,
		"only the last %d changes are kept" % ObservationTrail.KEEP)
	var seen := Observation.of(scene, wren, trail)
	equal(seen.recent, trail.recent_of(wren.id),
		"and an observation reports the looker's own changes")
	equal(seen.recent_absent, "", "with no reason to give, because they are there")
	var theirs := Observation.of(scene, scene.actors[1], trail)
	not_equal(theirs.recent, seen.recent,
		"somebody else's observation reports somebody else's changes")

	# An observation is a reading taken at a moment: what the trail does
	# afterwards is not allowed to appear in one that was already assembled.
	var taken := Observation.of(scene, wren, trail)
	var was := taken.recent.duplicate()
	wren.x += 9.0
	wren.piece.wound(4)
	trail.note(scene)
	equal(taken.recent, was,
		"an observation taken before a change does not fill in with it afterwards")
	not_equal(trail.recent_of(wren.id), was,
		"though the trail itself has moved on")

	equal(ObservationTrail.compass_of(0.0, -1.0), "north",
		"north is -z, which is what the whole project reads its map by")
	equal(ObservationTrail.compass_of(1.0, 0.0), "east", "and east is +x")
	equal(ObservationTrail.compass_of(1.0, -1.0), "north-east", "with eight in between")


# --- The same world gives the same observation ----------------------------


## Two lookers with the same surroundings get the same observation, and one
## looker asked twice gets the same answer.
func _it_is_the_same_for_the_same_surroundings() -> void:
	var first := _stage()
	var second := _stage()
	equal(
		Observation.of(first, first.actors[0]).digest(),
		Observation.of(second, second.actors[0]).digest(),
		"two identically staged worlds give one character one observation")
	equal(
		Observation.of(first, first.actors[0]).digest(),
		Observation.of(first, first.actors[0]).digest(),
		"and asking twice changes nothing: it is a reading, not an event")

	# The mirrored pair: two characters standing the same distance either side of
	# the same thing see the same number of entities and objects. Not the same
	# packet -- their offsets have opposite signs -- but the same shape.
	var seen := Observation.of(first, first.actors[0])
	var theirs := Observation.of(first, first.actors[1])
	equal(seen.objects.size(), theirs.objects.size(),
		"two characters at one market see the same objects")

	equal(ScriptedObservation.digest(), ScriptedObservation.digest(),
		"and the shipped run's observations fingerprint the same twice over")


## The measurement the task asks for, as a check rather than a hope: the shipped
## run's observations exist, are bounded, and are not empty.
func _the_shipped_run_is_measured() -> void:
	var taken := ScriptedObservation.taken_at()
	equal(taken.size(), 5 * ScriptedObservation.AT_TICKS.size(),
		"the walkthrough takes five characters' observations at each of its ticks")

	# The opening tick is the one with something lying about in it, so the object
	# half of section 10's list is exercised by the run and not only by this suite.
	var with_objects := 0
	for row in taken:
		if (row["seen"] as Observation).objects.size() > 0:
			with_objects += 1
	check(with_objects > 0, "and at least one of them has an object in it")

	# And at least one of them has speech in it, so the heard half of the packet
	# is exercised by the run and not only by this suite.
	var with_speech := 0
	for row in taken:
		if (row["seen"] as Observation).heard.size() > 0:
			with_speech += 1
	check(with_speech > 0, "and at least one of them has heard something said")
	for row in taken:
		var seen: Observation = row["seen"]
		check(seen.text_length() > 0, "every observation has a readable packet")
		check(seen.text_length() < 8000,
			"and it is small enough to be handed to a model: %d characters" % (
				seen.text_length()))
		equal(seen.entry_count(),
			seen.entities.size() + seen.objects.size()
				+ Observation.WINDOW * Observation.WINDOW
				+ seen.heard.size() + seen.recent.size(),
			"the entry count is what is actually in it")
	# The quarrel is on at the second tick, and one of the two is on the board:
	# the observation says so out of the world rather than out of a flag anybody
	# set for it.
	var on_board := 0
	for row in taken:
		if int(row["tick"]) == ScriptedScenario.QUARREL_FRAME \
				and (row["seen"] as Observation).self_on_board:
			on_board += 1
	check(on_board > 0, "somebody is standing on the tactical board at tick %d" % (
		ScriptedScenario.QUARREL_FRAME))


## No language model, no prompt, no network and no new dependency anywhere in
## the two files this layer is.
func _no_model_and_no_new_dependency() -> void:
	for path in [
		"res://sim/observation.gd", "res://sim/observation_trail.gd",
		"res://sim/scripted_observation.gd",
	]:
		var text := _read(path)
		check(text != "", "the scan opened %s" % path)
		# Nothing that reaches off this machine, anywhere in the file at all --
		# a URL in a comment is still a URL.
		for forbidden in [
			"HTTPRequest", "HTTPClient", "HTTPServer", "WebSocket", "TCPServer",
			"StreamPeer", "http://", "https://", "api_key", "OpenAI", "Anthropic",
		]:
			check(not text.contains(forbidden),
				"%s names no %s" % [path.get_file(), forbidden])
		# And nothing that reaches a model, in the code itself. Comments and
		# strings are taken off first, so that a file may *say* it holds no
		# prompt, and may print the sentence, without the words tripping this.
		var code := _code_of(text)
		for forbidden in ["prompt", "completion", "load("]:
			check(not code.contains(forbidden),
				"%s calls no %s" % [path.get_file(), forbidden])


# --- The stage ------------------------------------------------------------


# Three characters and a chest on the measured meadow. Wren and Rook are of one
# band -- so they know each other -- and Mott is of its own, so it is a stranger
# to both. Nothing drives them: this suite is about what can be seen, and being
# driven is a different question with its own suite.
func _stage() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var wren := scene.add_actor(Combatant.commander_at(
		WHERE.x - 4.0, WHERE.y, 0.0, 0.0, 2))
	_name_it(wren, "Wren")
	var rook := scene.add_actor(Combatant.commander_at(
		WHERE.x + 4.0, WHERE.y, 0.0, 0.0, 2))
	_name_it(rook, "Rook")
	rook.band = wren.band
	var mott := scene.add_actor(Combatant.commander_at(
		WHERE.x, WHERE.y + 8.0, 0.0, 0.0, 2))
	_name_it(mott, "Mott")
	scene.add_object(WorldObject.chest(
		"oak chest", WHERE.x, WHERE.y - 3.0, Inventory.ground([_thing("candle")])))
	return scene


func _name_it(one: Combatant, called: String) -> void:
	(one.piece as Commander).sheet.character_name = called


func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet


# Something to carry, forged the way every other walkthrough forges one: at
# level 1, with everything it is worth on its effects axis.
func _thing(called: String) -> Variant:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


# Whether one observation carries a line with this text in it.
func _heard_text(seen: Observation, text: String) -> bool:
	for row in seen.heard:
		if String(row["text"]) == text:
			return true
	return false


func _row_for(rows: Array[Dictionary], id: int) -> Dictionary:
	for row in rows:
		if int(row["id"]) == id:
			return row
	return {}


func _has_row(rows: Array[Dictionary], id: int) -> bool:
	return not _row_for(rows, id).is_empty()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


# A source with its strings and its comments taken off: what the file actually
# does, rather than what it says about itself or prints for a reader. The
# strings go first, so that a `#` inside one cannot be mistaken for a comment.
func _code_of(text: String) -> String:
	var bare := ""
	var inside := false
	for at in text.length():
		var character := text[at]
		if character == "\"":
			inside = not inside
			continue
		if not inside:
			bare += character
	var written := PackedStringArray()
	for line in bare.split("\n"):
		written.append(LayerCheck._strip_comment(line))
	return "\n".join(written)
