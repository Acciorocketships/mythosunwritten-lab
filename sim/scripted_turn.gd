extends RefCounted
## The seam between an action measured in ticks and a turn measured in turns,
## written down: how a commander's chosen weapon action becomes the weapon action
## of its own turn.
##
##     ./run_turn.sh
##
## Nothing here decides anything. Two commanders are stood on a board, each is
## given a decision function that chooses `attack` and nothing else, and the same
## two calls are made every tick that every other run on the action surface makes
## -- the control loop services everybody, and then `ActionScene.fight_step()`
## takes whatever of a turn is owed. What comes of that is the rule's, not this
## file's.
##
## ## What the rule is
##
## **A turn lasts as long as the weapon action that spends it.** While the
## commander whose turn it is is part-way through an `attack` it committed to,
## the board plays no turn at all; the tick that span runs out the blow is
## resolved -- still on its own turn -- and spends that turn's one weapon action.
## The turn is then played out and passes on. A commander chooses on its own turn
## and once on it, so nobody else's blow can land on it mid-swing, and the board's
## own stand-in chooser no longer swings for anybody who chooses for itself.
##
## Only an attack holds a turn, because only an attack is spent out of one. A
## commander that has committed nothing when its turn comes up -- one still
## deliberating -- holds nothing at all: the turn is played the tick it comes up
## and the commander has passed.
##
## ## The three sections
##
##   * **both blows land** -- two commanders whose decision functions both choose
##     `attack`, and the transcript of the fight that follows. Every chosen blow
##     is carried out on its own turn.
##   * **a turn nobody answered** -- the same duel with one of the two wrapped in
##     `DecisionSource.deliberate`, which will not answer for a stated number of
##     ticks. Its turns come up and pass; the other's blows go on landing; the
##     fight is never held up, and the slow one strikes as soon as it has an
##     answer.
##   * **what the board waits for** -- the same two runs counted rather than
##     read: how many ticks each turn took, and the longest any turn was held.
class_name ScriptedTurn

## The seed and the ground: the same measured open meadow every other walkthrough
## is played on, so this run invents no coordinate.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE

## The seed the control loop's continue-bias draws are hashed from.
const LOOP_SEED := ScriptedLoop.LOOP_SEED

## Who is in it, and what each is worth.
const HELD := "Hale"
const HELD_LEVEL := 3
const OTHER := "Odile"
const OTHER_LEVEL := 3

## What each strikes with, once forged.
const SPEAR := "common spear"

## How far apart the two stand when the board appears: the two cells the action
## walkthrough's duel is fought at.
const APART := ScriptedActions.DUEL_APART

## How long each run is watched for. Long enough for several whole turns on both
## sides, and for the slow one to answer at least once.
const TICKS := 60

## How long the slow decision function refuses to answer for, in ticks. Longer
## than a whole turn, so at least one of its turns comes up with nothing on it.
const THINKING_TICKS := 20


# --- The scene ------------------------------------------------------------


## Two commanders on one board, each carrying a spear, with no decision function
## on either yet.
##
## The fight is begun here rather than walked into: this run is about what
## happens *on* a board, and the walking-in is `sim/scripted_skirmish.gd`'s.
static func stage(seed_value: int = SEED) -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(seed_value))
	var one := _put(scene, HELD, HELD_LEVEL, WHERE - Vector2(APART * 0.5, 0.0))
	var two := _put(scene, OTHER, OTHER_LEVEL, WHERE + Vector2(APART * 0.5, 0.0))
	(one.piece as Commander).wield(Weapon.held(Weapon.spear(), HELD_LEVEL))
	(two.piece as Commander).wield(Weapon.held(Weapon.spear(), OTHER_LEVEL))
	var began := scene.begin_fight(one.id)
	if began == null or began.refused:
		return scene
	return scene


## Put a decision function on both sheets: strike at the other one, always.
##
## `slow` names the character whose function is wrapped in
## `DecisionSource.deliberate`, or "" for neither. The wrapper is the only
## difference between the two runs -- the choice underneath it is the same rule.
static func drive(scene: ActionScene, slow: String = "") -> void:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet == null:
			continue
		var rule := DecisionSource.scripted(_striking_at(sheet.character_name))
		sheet.decide = (
			DecisionSource.deliberate(rule, THINKING_TICKS)
			if sheet.character_name == slow else rule
		)


## Strike at whoever else is on the board, with the spear. The whole rule.
static func _striking_at(_who: String) -> Callable:
	return func(scene: ActionScene, actor: Combatant) -> Action:
		for one in scene.actors:
			if one == actor or not one.is_alive() or not one.fighting:
				continue
			return Action.attack(one.id, SPEAR)
		return null


# --- Living a run ---------------------------------------------------------


## Play one run and hand back everything read off it: the transcript, and the
## numbers the last section counts.
##
## Two calls per tick, and the order of them is the ordering every driver on the
## action surface keeps: the characters are serviced, and then whichever fight is
## on takes whatever of a turn it is owed.
static func played(slow: String = "", ticks: int = TICKS) -> Dictionary:
	var scene := stage()
	var loop := ControlLoop.on(scene, LOOP_SEED)
	drive(scene, slow)

	var written := PackedStringArray()
	var said := 0
	var turn_at := PackedInt32Array()
	for _step in maxi(0, ticks):
		loop.step()
		for at in range(said, loop.journal.size()):
			written.append(loop.journal[at])
		said = loop.journal.size()
		var turn := scene.fight_step()
		if not (turn["lines"] as PackedStringArray).is_empty():
			turn_at.append(scene.tick)
		written.append_array(_indent(turn["lines"]))
		if bool(turn["ended"]):
			written.append("t=%3d  --     the fight is over; real time again" % scene.tick)
			written.append_array(_indent(turn["over"]))

	var landed := 0
	var refused := 0
	for line in loop.journal:
		if line.contains("finished attack("):
			if line.contains("-> attack ok"):
				landed += 1
			else:
				refused += 1
	release(scene)
	return {
		"lines": written,
		"landed": landed,
		"refused": refused,
		"turns": turn_at,
		"gaps": _gaps(turn_at),
		"scene": scene,
	}


# --- The three sections ---------------------------------------------------


## Both blows land: two commanders, both choosing `attack`, and every chosen blow
## carried out on its own turn.
static func both_blows_land() -> PackedStringArray:
	var run := played()
	var written := PackedStringArray()
	written.append("both blows land: %s and %s, both choosing attack" % [HELD, OTHER])
	written.append("  an attack occupies %d ticks; a turn waits for it" % (
		ActionCatalog.occupies_of(ActionCatalog.ATTACK)))
	written.append_array(_indent(run["lines"]))
	written.append("  blows chosen through the action surface that landed: %d" % run["landed"])
	written.append("  blows chosen that were refused: %d" % run["refused"])
	return written


## What the blows made of what the two of them are to each other.
##
## This is where the fear a blow causes can be read as a number on a shipped run.
## The run above is two commanders both choosing `attack`; every blow that lands
## is written into the world's own record by the engine, and `CharacterUpkeep`
## folds it into the relationship graph on the path both of them pass. Fear rises
## by the share of full health the blow took, trust falls by half of what was
## there, and respect rises -- a blow shows what somebody can do, whatever else
## it does.
static func relationship_lines() -> PackedStringArray:
	var run := played()
	var scene: ActionScene = run["scene"]
	var graph := scene.relationships
	var written := PackedStringArray()
	written.append("what the blows made of them (%d blow%s landed, %d edge%s)" % [
		scene.blows.size(), "" if scene.blows.size() == 1 else "s",
		graph.size(), "" if graph.size() == 1 else "s",
	])
	for blow in scene.blows:
		written.append("  #%d struck #%d for %d of %d on tick %d" % [
			blow["from"], blow["to"], blow["dealt"], blow["out_of"], blow["tick"],
		])
	# Both ends of every edge, whether or not the character is still standing:
	# the graph is the world's record of what happened and a character falling
	# does not unmake it.
	for edge in graph.all():
		written.append("  " + edge.line_toward(edge.low))
		written.append("  " + edge.line_toward(edge.high))
	return written


## A turn nobody answered: the same duel, with one of the two unable to answer
## for `THINKING_TICKS` ticks. Its turns come up and pass, and the fight carries
## on without it.
static func a_turn_nobody_answered() -> PackedStringArray:
	var run := played(HELD)
	var written := PackedStringArray()
	written.append("a turn nobody answered: %s deliberates for %d ticks at a time" % [
		HELD, THINKING_TICKS,
	])
	written.append_array(_indent(run["lines"]))
	written.append("  blows that landed: %d" % run["landed"])
	return written


## What the board waited for, in both runs: how many turns were played, how many
## ticks apart they were, and the longest any one turn was held.
##
## The claim the numbers are here to settle is that the wait is bounded by the
## cost of one action and by nothing else -- a decision that never comes cannot
## make the board wait at all.
static func what_the_board_waits_for() -> PackedStringArray:
	var costs := ActionCatalog.occupies_of(ActionCatalog.ATTACK)
	var written := PackedStringArray()
	written.append("what the board waits for (an attack occupies %d ticks)" % costs)
	written.append("  %-24s %8s %8s %8s %8s" % [
		"run", "turns", "landed", "longest", "bound",
	])
	for row in [
		{"name": "both choosing", "slow": ""},
		{"name": "one deliberating", "slow": HELD},
	]:
		var run := played(String(row["slow"]))
		var gaps: PackedInt32Array = run["gaps"]
		var longest := 0
		for gap in gaps:
			longest = maxi(longest, gap)
		written.append("  %-24s %8d %8d %8d %8d" % [
			row["name"], (run["turns"] as PackedInt32Array).size(),
			run["landed"], longest, costs + 1,
		])
	written.append("  a turn is held for at most one attack's span, and never for a")
	written.append("  decision that has not been made.")
	return written


## Everything above, in order. What `./run_turn.sh` prints.
static func play() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("turn/action seam seed=%d ticks=%d" % [SEED, TICKS])
	written.append("")
	written.append_array(both_blows_land())
	written.append("")
	written.append_array(relationship_lines())
	written.append("")
	written.append_array(a_turn_nobody_answered())
	written.append("")
	written.append_array(what_the_board_waits_for())
	return written


# --- The furniture --------------------------------------------------------


## Take the decision functions back off the sheets when a run is over, cutting
## the ring that otherwise keeps the scene, the sheets and the rules alive.
static func release(scene: ActionScene) -> void:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null:
			sheet.decide = Callable()


static func _put(
	scene: ActionScene, called: String, level: int, at: Vector2
) -> Combatant:
	var one := scene.add_actor(Combatant.commander_at(
		at.x, at.y, 0.0, 0.0, level, AssetTags.KNIGHT))
	var sheet := Character.make(called, level)
	sheet.record_scores({Ability.DEX: 4, Ability.STR: 5})
	(one.piece as Commander).adopt(sheet)
	one.settle(scene.terrain)
	return one


static func _sheet(one: Combatant) -> Character:
	if one == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


# The distances between consecutive entries of a list of ticks.
static func _gaps(at: PackedInt32Array) -> PackedInt32Array:
	var found := PackedInt32Array()
	for index in range(1, at.size()):
		found.append(at[index] - at[index - 1])
	return found


static func _indent(lines: PackedStringArray) -> PackedStringArray:
	var written := PackedStringArray()
	for line in lines:
		written.append("  " + line)
	return written
