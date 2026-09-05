extends RefCounted
## What the world charges for an ask that costs it no time, put to one mind of
## each kind at once.
##
##     ./run_asks.sh
##
## Three characters stand far enough apart that nothing one of them does can
## reach another, and each of them reaches for the same thing four times before
## it does anything at all. What decides for them is the only difference between
## them:
##
##   * **Ash** is a person -- `DecisionSource.live`, whose answer is whatever the
##     person driving has put into a `LiveChoice` while the world runs. The
##     presses below are that person's hand: they are made from outside the loop,
##     between ticks, the way a person's are.
##   * **Bryn** is a program -- `DecisionSource.scripted`, a rule that works its
##     answer out from the world it is handed.
##   * **Cass** is a language model -- `DecisionSource.model`, a `ModelMind`
##     reading replies out of a channel.
##
## All three go through `ToolBudget.asked()`, which is the world's door and the
## only one there is. What this run prints is what each of them was told, tick by
## tick, so that the claim "the guard is a rule of the world and not of one mind"
## is something read off three transcripts rather than off the source.
##
## What it should show, and what the run asserts nowhere and prints everywhere:
## two asks apiece are free; the third is refused in the same sentence for all
## three, with only the character's own name different; each of them is charged
## exactly one turn for it and stands `ToolBudget.costs()` ticks; asking again
## while standing costs nothing further; and each of them is asked for a choice
## again the moment the span runs out, and acts.
##
## Nothing here decides anything about the world. The scene is constants, the
## choices are `Action`s written out below, and what an ask costs is
## `ToolBudget`'s answer -- so two processes print the same bytes.
class_name ScriptedAsks

## The seed the scenario is written for and the ground it is played on: the same
## measured open meadow the action walkthrough uses, so no new coordinate is
## invented here.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE

## The seed the loop's own draws come from.
const LOOP_SEED := 7

## How far apart the three of them stand, in world units: far enough that
## nothing one does can reach another, so the only thing the three arms have in
## common is the world's own rule.
const APART := 40.0

## How long the world is lived for. Long enough that the slowest of the three --
## the model, whose replies take `ModelChannel.THINKS_FOR` ticks to come back --
## has made all four of its asks, been charged, stood its turn out and acted.
const TICKS := 40

## How many times each mind reaches for the tool. Two more than `ToolBudget.FREE`
## so that both refusals are on the record: the one that costs a turn, and the
## one made while standing that turn out, which costs nothing.
const ASKS := 4

## What each of them looks back for. One word, so the answer is the same shape
## for all three and the run is about what it cost rather than what it found.
const ABOUT := "road"

## What each of them does once it has finished looking: the cheapest turn in the
## catalogue, so what is printed after the guard is the guard and not a walk.
const THEN := 1

## The three, in the order they are put into the world.
const ASH := "Ash"
const BRYN := "Bryn"
const CASS := "Cass"

## What they are worth. One level for all three: nothing here is about strength.
const LEVEL := 2


## The whole run: three minds, one door.
##
## The channel is the model arm's and is handed in, because a file under `sim/`
## may not name the recording -- see `sim/model_channel.gd`.
static func play(channel: ModelChannel) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("three minds, one door: what an ask that costs the world no"
		+ " time costs a character")
	written.append("  the rule: %d free asks between the actions a character"
		% ToolBudget.FREE
		+ " takes; one past that is refused and costs it a turn, and the free"
		+ " ones come back when it acts and not when it pays")
	written.append("  a turn here is %d ticks, which is what the catalogue"
		% ToolBudget.costs()
		+ " charges for %s -- the action that is looking at something"
		% ActionCatalog.EXAMINE)
	written.append("")
	written.append_array(_run(channel))
	return written


# --- The world the three stand in -----------------------------------------


static func _run(channel: ModelChannel) -> PackedStringArray:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var ash := _put(scene, ASH, WHERE)
	var bryn := _put(scene, BRYN, WHERE + Vector2(APART, 0.0))
	var cass := _put(scene, CASS, WHERE + Vector2(0.0, APART))

	# The person's hand, and what it was told. Nothing about it is in the loop:
	# the presses happen between ticks, from outside.
	var pressed := PackedStringArray()
	var presses := [0]
	var hand := LiveChoice.new()
	_sheet(ash).decide = DecisionSource.live(hand)

	# The program's rule: it reaches for the same thing, and answers nothing at
	# all until it has stopped reaching.
	var reached := PackedStringArray()
	var reaches := [0, 0]
	_sheet(bryn).decide = DecisionSource.scripted(
		func(world: ActionScene, actor: Combatant) -> Action:
			if reaches[0] >= ASKS:
				if reaches[1] > 0:
					return null
				reaches[1] += 1
				return Action.wait(THEN)
			reaches[0] += 1
			reached.append(_told(world, actor, ToolBudget.asked(world, actor)))
			return null)

	# The model's mind, answering out of the channel it was handed.
	var mind := ModelMind.with_channel(channel)
	_sheet(cass).decide = DecisionSource.model(mind)

	var loop := ControlLoop.on(scene, LOOP_SEED)
	for _tick in TICKS:
		loop.step()
		if presses[0] < ASKS:
			presses[0] += 1
			pressed.append(_told(scene, ash, ToolBudget.asked(scene, ash)))
			if presses[0] == ASKS:
				hand.choose(Action.wait(THEN))

	var written := PackedStringArray()
	written.append_array(_arm("Ash, a person", scene, ash, pressed, loop))
	written.append("")
	written.append_array(_arm("Bryn, a program", scene, bryn, reached, loop))
	written.append("")
	written.append_array(_arm("Cass, a language model", scene, cass,
		_model_lines(mind), loop))
	written.append("")
	written.append_array(_together(scene, loop))
	_release(scene)
	return written


# What one arm came to: what it was told each time it asked, what the world
# charged it, and what it did afterwards.
static func _arm(
	who: String, scene: ActionScene, one: Combatant,
	told: PackedStringArray, loop: ControlLoop
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("%s (#%d)" % [who, one.id])
	for line in told:
		written.append("  %s" % line)
	written.append("  the world charged it %d turn%s and %s" % [
		_charges(scene, one.id).size(),
		"" if _charges(scene, one.id).size() == 1 else "s",
		"stood it until tick %d" % scene.spent_until_of(one.id),
	])
	for line in loop.journal:
		if line.contains(" %s " % ActionScene.name_of(one)):
			written.append("  %s" % line)
	return written


# The three arms side by side: the same sentence, the same price, and each of
# them asked again afterwards rather than shut out.
static func _together(scene: ActionScene, loop: ControlLoop) -> PackedStringArray:
	var written := PackedStringArray()
	var sentences := {}
	for row in scene.asks_refused:
		sentences[String(row["why"]).split(" ", true, 1)[1]] = true
	written.append("the three side by side")
	written.append("  %d sentence%s over %d refusals across %d characters,"
		% [sentences.size(), "" if sentences.size() == 1 else "s",
			scene.asks_refused.size(), scene.actors.size()]
		+ " with the names taken off the front:")
	for sentence in sentences:
		written.append("    \"... %s\"" % sentence)
	for one in scene.actors:
		written.append("  %-6s charged %d turn%s, %d ticks apiece, and resolved"
			% [ActionScene.name_of(one), _charges(scene, one.id).size(),
				"" if _charges(scene, one.id).size() == 1 else "s",
				ToolBudget.costs()]
			+ " %d action%s afterwards" % [
				loop.actions_of(one.id),
				"" if loop.actions_of(one.id) == 1 else "s",
			])
	return written


# Every ask the world charged one character a turn for.
static func _charges(scene: ActionScene, id: int) -> Array:
	var found := []
	for row in scene.asks_refused:
		if int(row["id"]) == id:
			found.append(row)
	return found


# One line saying what a character was told when it asked, in the world's words.
static func _told(scene: ActionScene, one: Combatant, answer: Dictionary) -> String:
	if bool(answer["allowed"]):
		return "tick %d  asked, and may: %d of %d free" % [
			scene.tick, answer["taken"], answer["free"],
		]
	return "tick %d  asked, and may not: %s" % [scene.tick, answer["why"]]


# The model arm's asks, read off the turns its mind kept. Every reply that named
# a tool is one ask; what the world said about it is on the turn.
static func _model_lines(mind: ModelMind) -> PackedStringArray:
	var written := PackedStringArray()
	for turn in mind.turns:
		if String(turn["tool"]) == "":
			written.append("tick %d  answered %s, which is an action" % [
				turn["tick"], turn["said"],
			])
			continue
		if String(turn["refused"]) == "":
			written.append("tick %d  asked %s about \"%s\", and may: %d back" % [
				turn["tick"], turn["tool"], turn["asked_for"], turn["found"],
			])
			continue
		written.append("tick %d  asked %s about \"%s\", and may not: %s" % [
			turn["tick"], turn["tool"], turn["asked_for"], turn["refused"],
		])
	return written


# --- The furniture --------------------------------------------------------


static func _put(scene: ActionScene, called: String, at: Vector2) -> Combatant:
	var one := scene.add_actor(Combatant.commander_at(
		at.x, at.y, 0.0, 0.0, LEVEL, AssetTags.KNIGHT))
	(one.piece as Commander).adopt(Character.make(called, LEVEL))
	return one


static func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet


# Take the decision functions back off the sheets when the scene is done with,
# cutting the ring that otherwise keeps the scene and the rules alive.
static func _release(scene: ActionScene) -> void:
	for one in scene.actors:
		if one.piece is Commander:
			(one.piece as Commander).sheet.decide = Callable()
