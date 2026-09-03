extends RefCounted
## The orchestrator run: a world with one character walking a written-down plan
## through it, and the world's dungeon master looking at that world every so
## often and changing it.
##
## What the run is for is the two duties of section 8, shown rather than argued:
##
##   1. **The world is changed through tools.** Every look the orchestrator takes
##      is answered with lines, and a line is either one of the operations the
##      engine exposes -- which the engine carries out -- or it is nothing at
##      all. The transcript prints both, with the engine's reason beside each.
##   2. **A spawn happens rolls first.** When a look names `spawn`, the sheet is
##      rolled from the role's bands and this region's own difficulty and the
##      character stands in the world with it *before* anybody is asked who that
##      is. The transcript prints the rolls, the tick they were rolled on, the
##      tick the persona came back on, and the six numbers again afterwards, so
##      that the order and the fact that the persona did not touch them are both
##      readable off the page.
##
## Rook's mind here is a written-down plan and not a model, on purpose, for the
## same reason the difficulty-class run's is: this run is about the orchestrator,
## and a character agent choosing its own way through would make what is being
## measured depend on what it chose. The only model calls in it are the
## orchestrator's.
##
## ## What is deliberately not in it
##
## No story. Rook's plan is a walk and a look and a wait; nothing in the world
## is a quest, nothing rewards anything, and the orchestrator is shown the world
## and a list of operations and nothing else. Whatever narrative the run happens
## to show is what came out of a world and a list of world operations meeting
## each other.
class_name ScriptedWorld

## The world this is played on, which is the one every other run is played on.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE
const LOOP_SEED := ScriptedLoop.LOOP_SEED

## How long the run is, and how often the orchestrator looks. Five looks, spaced
## far enough apart that a walk happens between them.
const TICKS := 150
const EVERY := Orchestrator.EVERY

## Who is already there, and what it carries.
const ROOK := "Rook"
const ROOK_LEVEL := 2
const LANTERN := "brass lantern"
const ROPE := "coil of rope"

## What is already lying about: a chest with something in it and a shut crate.
const THINGS := [
	{"name": "oak chest", "at": Vector2(6.0, 0.0), "shut": false, "coins": 9},
	{"name": "hazel crate", "at": Vector2(-5.0, 4.0), "shut": true, "coins": 0},
]

## Where Rook walks, and what it says on the way. A plan and not a plot: it goes
## somewhere, looks at something, says one thing out loud so the world has
## something in it that was said, and waits.
const WALK := [
	Vector2(6.0, 2.0), Vector2(-4.0, 4.0), Vector2(2.0, -6.0),
	Vector2(8.0, -2.0), Vector2(-2.0, -4.0),
]
const GREETING := "anyone about? I have rope and a lantern to trade"

## A line a model might answer with if it wanted to write a relationship itself.
## Nothing sends it; it is put through the engine's own reader and applier in
## `relationship_lines()` so that the refusal is shown rather than described.
const AN_EDGE_WRITING_ANSWER := "relate target=#2 trust=1.0 fear=0.0"


# --- The world -------------------------------------------------------------


## Set the run out.
static func stage(seed_value: int = SEED) -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(seed_value))
	var rook := scene.add_actor(Combatant.commander_at(
		WHERE.x, WHERE.y, 0.0, 0.0, ROOK_LEVEL, AssetTags.ROGUE))
	var sheet := Character.make(ROOK, ROOK_LEVEL)
	sheet.record_scores(ScriptedScenario.ROLL)
	(rook.piece as Commander).adopt(sheet)
	sheet.inventory.carry(_tool(LANTERN))
	sheet.inventory.carry(_tool(ROPE))
	rook.settle(scene.terrain)

	for row in THINGS:
		var at: Vector2 = row["at"]
		var thing := scene.add_object(WorldObject.chest(
			String(row["name"]), WHERE.x + at.x, WHERE.y + at.y,
			Inventory.of([], int(row["coins"]))))
		thing.shut = bool(row["shut"])
	return scene


## What Rook does, in order.
static func choices(scene: ActionScene) -> Array:
	var written := []
	written.append(Action.say(GREETING))
	for at in WALK.size():
		written.append(Action.go_to(Vector2(WHERE.x + WALK[at].x, WHERE.y + WALK[at].y)))
		if at < scene.objects.size():
			written.append(Action.examine(scene.objects[at].id))
		written.append(Action.wait(6))
	written.append(Action.wait(8))
	return written


# --- Living it -------------------------------------------------------------


## Play the run and return everything a transcript or a test wants out of it.
##
## The per-tick sampling is the measurement the run exists to make: on every tick
## it notes whether the orchestrator had a question outstanding and how many
## actions the world carried out for the character on that tick. A simulation
## that blocked on the orchestrator would show a run of ticks in which nothing
## happened, and a count of zero actions taken while it was thinking.
static func played_with(
	channel: ModelChannel, ticks: int = TICKS, seed_value: int = SEED,
	ticks_between: int = EVERY
) -> Dictionary:
	var scene := stage(seed_value)
	var rook := _named(scene, ROOK)
	_sheet(rook).decide = DecisionSource.plan(choices(scene))
	var loop := ControlLoop.on(scene, LOOP_SEED)
	var world := Orchestrator.with_channel(channel, seed_value, ticks_between)
	var opened := scene.lines()

	var waited := 0
	var longest := 0
	var running := 0
	var acted_while_waiting := 0
	var busy_while_waiting := 0
	var acted := 0
	for _step in maxi(0, ticks):
		var before := scene.actions_of(rook.id)
		loop.step()
		world.step(scene)
		var taken := scene.actions_of(rook.id) - before
		acted += taken
		if world.waiting() > 0:
			waited += 1
			running += 1
			longest = maxi(longest, running)
			acted_while_waiting += taken
			if loop.is_busy(rook.id):
				busy_while_waiting += 1
		else:
			running = 0
	return {
		"scene": scene, "loop": loop, "world": world, "rook": rook,
		"opened": opened, "channel": channel,
		"waited": waited, "longest": longest, "acted": acted,
		"acted_while_waiting": acted_while_waiting,
		"busy_while_waiting": busy_while_waiting, "ticks": maxi(0, ticks),
	}


## The run as a transcript.
static func play(
	channel: ModelChannel, ticks: int = TICKS, seed_value: int = SEED,
	ticks_between: int = EVERY
) -> PackedStringArray:
	var played := played_with(channel, ticks, seed_value, ticks_between)
	var scene: ActionScene = played["scene"]
	var world: Orchestrator = played["world"]

	var written := PackedStringArray()
	written.append_array(_opening(played, ticks, seed_value, ticks_between))
	written.append("")
	written.append_array(_two_prompts_lines())
	written.append("")
	written.append_array(bands_lines())
	written.append("")
	written.append_array(_what_the_character_did_lines(played["loop"]))
	written.append("")
	written.append_array(_what_happened_lines(world))
	written.append("")
	written.append_array(operation_lines(world))
	written.append("")
	written.append_array(relationship_lines(scene))
	written.append("")
	written.append_array(spawn_lines(world))
	written.append("")
	written.append_array(nothing_waited_lines(played))
	written.append("")
	written.append_array(cost_lines(world))
	written.append("")
	written.append("after %d ticks" % scene.tick)
	for line in scene.lines():
		written.append("  %s" % line)
	written.append("  fingerprint %s" % scene.fingerprint())
	written.append("")
	written.append_array(questions_lines(played))
	return written


# --- The head --------------------------------------------------------------


static func _opening(
	played: Dictionary, ticks: int, seed_value: int, ticks_between: int
) -> PackedStringArray:
	var channel: ModelChannel = played["channel"]
	var written := PackedStringArray()
	written.append("orchestrator run seed=%d ticks=%d every=%d where=(%.1f, %.1f)"
		% [seed_value, ticks, ticks_between, WHERE.x, WHERE.y])
	written.append("  polled     every %d ticks over the world, which is what makes"
		% ticks_between
		+ " this the third shape of call and not the other two")
	written.append("  channel    %s -- %s" % [channel.kind, channel.why])
	written.append("  recording  %s" % channel.recorded)
	written.append("  region     %.1f from the world origin, ring %d, difficulty %d"
		% [
			Vector2(WHERE.x, WHERE.y).length(),
			SpawnRoll.ring_at(WHERE.x, WHERE.y),
			SpawnRoll.difficulty_at(WHERE.x, WHERE.y),
		]
		+ " -- section 5's own gradient, out of ItemFrontier")
	written.append("  who        %s, carrying a %s and a %s" % [ROOK, LANTERN, ROPE])
	written.append("")
	written.append("the world at the start")
	for line in played["opened"]:
		written.append("  %s" % line)
	return written


## The two system prompts, named side by side, and the whole of what the
## orchestrator may do -- which is a list of world operations and not a list of
## narrative beats.
static func _two_prompts_lines() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("two prompts, two calls")
	written.append("  watching   %s" % OrchestratorPrompt.WATCHES)
	written.append("  peopling   %s" % OrchestratorPrompt.PEOPLES)
	written.append("  and the watching call may name only these, which the engine"
		+ " carries out:")
	for line in WorldEffects.catalogue_lines():
		written.append("  " + line)
	written.append("  that list is the whole of what it may do.")
	return written


## The bands every role is rolled from here: the role's own, lifted by this
## region's ring. What "ranges by unit role and local region difficulty" is, as
## numbers.
static func bands_lines(at: Vector2 = WHERE) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the bands a sheet is rolled from here (ring %d, lift %+d)" % [
		SpawnRoll.ring_at(at.x, at.y), SpawnRoll.lift_at(at.x, at.y),
	])
	var head := PackedStringArray()
	head.append("  %-8s %-6s" % ["role", "level"])
	for ability in Ability.ALL:
		head.append("%-8s" % ability)
	written.append(" ".join(head))
	for role in SpawnRoll.roles():
		var row := PackedStringArray()
		row.append("  %-8s %-6d" % [role, SpawnRoll.difficulty_at(at.x, at.y)])
		for ability in Ability.ALL:
			var band := SpawnRoll.band_for(role, ability, at.x, at.y)
			row.append("%-8s" % ("%d-%d" % [band.x, band.y]))
		written.append(" ".join(row))
	return written


static func _what_the_character_did_lines(loop: ControlLoop) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what the character did, which nothing here chose for it")
	for line in loop.journal:
		written.append("  %s" % line)
	return written


static func _what_happened_lines(world: Orchestrator) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what the orchestrator did, as it happened")
	for line in world.journal:
		written.append("  %s" % line)
	return written


# --- The tables ------------------------------------------------------------


## Every operation it named, and what the engine did about it.
static func operation_lines(world: Orchestrator) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the operations, every one of them the engine's")
	if world.operations.is_empty():
		written.append("  it named none")
		return written
	for row in world.operations:
		written.append("  %-9s %-42s %s" % [
			"did" if bool(row["ok"]) else "would not", row["line"], row["reason"],
		])
	return written


## What the world recorded between the characters in it, and what happens when an
## answer tries to write one of those records itself.
##
## Section 10's relationship edges are the world's record of what has passed
## between two characters -- a line heard, a trade honoured, a blow struck -- and
## the reason they are the world's rather than anybody's is exactly this: a
## character that could write its own record could be loved by everybody merely
## by saying so. So there is no operation in the table above that names a
## relationship, an answer naming one reads as no operation at all, and put
## through the engine anyway it is refused in the same words any unknown
## operation is refused in.
static func relationship_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	var graph := scene.relationships
	written.append("the relationships, which are the world's record and not a"
		+ " model's")
	if graph.size() == 0:
		written.append("  nothing passed between anybody, so there are no edges")
	for line in graph.lines():
		written.append("  " + line)
	var was := graph.fingerprint()
	var refused := WorldEffects.apply(scene, {
		"op": "relate", "line": AN_EDGE_WRITING_ANSWER,
	}, SEED)
	written.append("  and an answer that tried to write one:")
	written.append("    the line          %s" % AN_EDGE_WRITING_ANSWER)
	written.append("    read as           %d operation%s -- there is none of that"
		% [
			WorldEffects.read(AN_EDGE_WRITING_ANSWER).size(),
			"" if WorldEffects.read(AN_EDGE_WRITING_ANSWER).size() == 1 else "s",
		]
		+ " name in the table")
	written.append("    through the engine %s -- %s" % [
		"did" if bool(refused["ok"]) else "would not", String(refused["reason"]),
	])
	written.append("    and the graph     %s" % (
		"unmoved" if graph.fingerprint() == was else "MOVED, which it must not"))
	return written


## Every spawn, in the order section 8 states: the rolls, then the persona.
static func spawn_lines(world: Orchestrator) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the spawns, rolls first")
	if world.spawns.is_empty():
		written.append("  it spawned nobody")
		return written
	for row in world.spawns:
		var at: Vector2 = row["at"]
		var spread: Dictionary = row["spread"]
		var persona: Dictionary = row["persona"]
		written.append("  #%d  a %s at (%.1f, %.1f)" % [
			row["id"], row["role"], at.x, at.y,
		])
		written.append("      1. rolled on tick %d, level %d for this region" % [
			row["rolled_at"], row["level"],
		])
		written.append("         %s" % row["rolls"])
		written.append("         highest %s, lowest %s, %d apart" % [
			spread["high"], spread["low"], spread["spread"],
		])
		written.append("         and it stood in the world as \"%s\", with nobody"
			% row["called_when_rolled"] + " written into it")
		if int(row["written_at"]) < 0:
			written.append("      2. no persona: %s" % row["note"])
			continue
		written.append("      2. asked who that is, answered on tick %d" % row["written_at"])
		written.append("         name        %s" % persona.get("name", "-"))
		written.append("         traits      %s" % _joined(persona.get("traits", [])))
		written.append("         tendencies  %s" % _joined(persona.get("tendencies", [])))
		for line in _wrapped(String(persona.get("backstory", "")), 62):
			written.append("         %s" % line)
		written.append("      3. %s" % row["note"])
		written.append("         %s" % row["rolls_after"])
		written.append("         %s" % (
			"which is the line rolled in step 1, unchanged"
			if String(row["rolls_after"]) == String(row["rolls"])
			else "WHICH IS NOT THE LINE ROLLED IN STEP 1"))
	return written


## The measurement, taken on the run: how much of it the orchestrator spent
## thinking, and what the world did meanwhile.
static func nothing_waited_lines(played: Dictionary) -> PackedStringArray:
	var world: Orchestrator = played["world"]
	var scene: ActionScene = played["scene"]
	var written := PackedStringArray()
	written.append("nothing waited for it")
	written.append("  ticks      %d asked for, %d advanced" % [
		played["ticks"], scene.tick,
	])
	written.append("  thinking   %d of those ticks had a question outstanding,"
		% played["waited"]
		+ " the longest run of them %d ticks" % played["longest"])
	written.append("  meanwhile  the character was part-way through an action on %d"
		% played["busy_while_waiting"]
		+ " of those %d ticks and stood idle on none of them" % played["waited"])
	written.append("  and it     carried out %d action%s over the run, %d of them"
		% [played["acted"], "" if int(played["acted"]) == 1 else "s",
			played["acted_while_waiting"]]
		+ " landing on a tick the orchestrator was thinking")
	written.append("  left over  %d question%s outstanding when the run ended" % [
		world.waiting(), "" if world.waiting() == 1 else "s",
	])
	return written


## What the run cost.
static func cost_lines(world: Orchestrator) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what it cost")
	written.append("  looks      %d taken, %d of which left the world alone" % [
		world.looks, world.quiet,
	])
	written.append("  calls      %d put to a model" % world.calls)
	written.append("  operations %d named, %d carried out by the engine" % [
		world.operations.size(), world.carried_out(),
	])
	written.append("  spawns     %d, each of them one roll and one call" % world.spawns.size())
	return written


## The two questions in full, so the difference between them can be read.
static func questions_lines(played: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()
	var channel: ModelChannel = played["channel"]
	var world: Orchestrator = played["world"]
	var asked := channel.questions()
	if asked.is_empty():
		written.append("the run asked nothing")
		return written
	written.append("the questions in full")
	var shown := [0]
	if not world.spawns.is_empty():
		for at in asked.size():
			if String(asked[at]["prompt"]).begins_with(OrchestratorPrompt.PEOPLES):
				shown.append(at)
				break
	for at in shown:
		written.append("")
		written.append("  --- question %d, %d characters, digest %s ---" % [
			at + 1, String(asked[at]["prompt"]).length(), asked[at]["digest"],
		])
		for line in String(asked[at]["prompt"]).split("\n"):
			written.append("  %s" % line)
	return written


# --- The furniture ---------------------------------------------------------


static func _joined(parts: Variant) -> String:
	var listed := PackedStringArray(parts)
	return "-" if listed.is_empty() else ", ".join(listed)


static func _wrapped(text: String, width: int) -> PackedStringArray:
	var written := PackedStringArray()
	if text.strip_edges() == "":
		written.append("backstory   -")
		return written
	var line := "backstory   "
	for word in text.split(" "):
		if line.length() + String(word).length() + 1 > width and line.strip_edges() != "":
			written.append(line)
			line = "            "
		line += "%s " % word
	if line.strip_edges() != "":
		written.append(line.rstrip(" "))
	return written


static func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


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
