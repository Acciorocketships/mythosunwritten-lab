extends RefCounted
## Section 2.2's control loop and section 12's non-blocking decision, written
## down: the walkthrough this layer is demonstrated by and the determinism
## witness for it.
##
##     ./run_loop.sh
##
## Nothing here decides anything. The scenes are lists of constants and the
## choices made in them are `Action`s written out below; what each one *does* is
## `ActionEngine`'s answer and *when* it happens is `ControlLoop`'s, exactly as
## `sim/scripted_actions.gd` keeps that division with the action surface. Two
## processes therefore print the same bytes.
##
## ## The four sections
##
##   * **the cadence** -- one character on one long walk, thinking again every
##     `ControlLoop.REVIEW_EVERY` ticks while it walks and again the instant the
##     walk is done.
##   * **the four events** -- section 2.2 names four things that make a character
##     re-evaluate at once, and each gets its own scene: an action finishing, the
##     character being attacked while acting, combat starting under it, and
##     somebody opening a conversation with it.
##   * **the bias** -- the same restless character run twice, once at
##     `ControlLoop.CONTINUE_BIAS` and once with the bias taken away, counting
##     how often it actually changed its mind. A number that changes nothing when
##     you remove it is not doing anything, and this is what says it is.
##   * **a slow decider** -- three characters, one of which will not answer for
##     forty ticks. Everybody's tick counts are printed for that run and for a
##     run where all three answer at once, and they are the same numbers.
class_name ScriptedLoop

## The seed the scenario is written for and the ground the scenes that need
## ground are played on: the same measured open meadow the action walkthrough
## uses, so no new coordinate is invented here.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE

## The seed the loop's own draws come from. The bias is the only thing in the
## loop that draws a number, so this seed is the whole of what changing it can
## change.
const LOOP_SEED := 7

## The bias with the bias taken out. Zero means "never keep going when something
## else is proposed", which is the loop with section 2.2's second clause deleted.
const BROKEN_BIAS := 0.0

## How long the bias is measured over. Long enough that a rate means something:
## a review lands about every `REVIEW_EVERY` ticks, so this is on the order of
## two hundred re-evaluations -- enough that a rate a few points either side of
## what the number says is sampling noise rather than a different number.
const MEASURE_TICKS := 1200

## How long the three-character world is lived for, and how long the slow
## character's decision function takes to answer. Forty ticks is two seconds at
## the rate the world is stepped -- an unremarkable wait for something that has
## to think, and far longer than any tick may take.
const WORLD_TICKS := 80
const THINKING_TICKS := 40

## The three characters of the slow-decider world, in the order they are put in
## it. The first is the one that is made slow.
const CROWD := ["Ash", "Bryn", "Cass"]

## How far apart the three of them stand, in world units: far enough that
## nothing one of them does can reach another, so the only thing the two runs
## have in common is the loop itself.
const APART := 40.0

## What the characters in these scenes are worth.
const ROOK_LEVEL := 3
const VEX_LEVEL := 2

## How far apart the two duellists stand, in world units: the same two cells the
## action walkthrough's duel is fought at.
const DUEL_APART := ScriptedActions.DUEL_APART

## What the spear is called once forged, and what the character carrying it
## strikes with.
const SPEAR := "common spear"

## The item the finishing case picks up, and the pile it is lying on.
const HATCHET := "worn hatchet"
const PILE_AT := Vector2(1.5, 0.0)

## Where the walker in the cadence and interruption scenes is walking to, as an
## offset from `WHERE`. Far enough that the walk is not over before the
## re-evaluations are.
const WALK_TO := Vector2(30.0, 0.0)

## How long the scene where somebody is struck part-way through a wait is
## watched for: past the striker's turn, which lasts as long as the blow it
## spends, plus the tick the turn before it took to pass.
const ATTACKED_TICKS := 10

## How long the cadence scene is watched for: past the end of one twenty-tick
## walk, so the re-evaluation that happens the moment it finishes is in the
## transcript too.
const CADENCE_TICKS := 25

## What the restless character used by the bias measurement proposes: a walk to a
## point on this many-position ring, one step round it per question asked. It
## never proposes twice in a row what it proposed last, which is what makes every
## re-evaluation a real disagreement with what is already running.
const RESTLESS_STOPS := 17
const RESTLESS_SPACING := 1.5


# --- The cadence ----------------------------------------------------------


## One character, one long walk, and nothing in the world to interrupt it.
##
## What this shows is the first half of section 2.2 on its own: the walk costs
## the ticks the catalogue says it costs, the character is asked again every
## `ControlLoop.REVIEW_EVERY` ticks while it is walking, and it is asked again
## the moment the walk finishes -- which is why the finishing line and the next
## beginning line carry the same tick number.
static func cadence() -> PackedStringArray:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var rook := _put(scene, "Rook", ROOK_LEVEL, WHERE, AssetTags.KNIGHT)
	var to := WHERE + WALK_TO
	_sheet(rook).decide = DecisionSource.scripted(
		func(_scene: ActionScene, _actor: Combatant) -> Action:
			return Action.go_to(to))

	var loop := ControlLoop.on(scene, LOOP_SEED)
	loop.run(CADENCE_TICKS)

	var written := PackedStringArray()
	written.append("cadence: one walk, %d ticks watched" % CADENCE_TICKS)
	written.append("  a go_to costs %d ticks; re-evaluated every %d" % [
		ActionCatalog.occupies_of(ActionCatalog.GO_TO), ControlLoop.REVIEW_EVERY,
	])
	written.append_array(_indent(loop.journal))
	written.append("  " + _counts_line(loop))
	return written


# --- The four events section 2.2 names ------------------------------------


## An action finishing. The first of the four, and the one that needs no
## interference: the span runs out, the engine resolves the action, and the
## character is asked again in the same tick -- which the transcript shows as a
## `finished` line and a `began` line sharing a tick number.
static func finishing() -> PackedStringArray:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var rook := _put(scene, "Rook", ROOK_LEVEL, WHERE, AssetTags.KNIGHT)
	scene.add_object(WorldObject.loose(
		WHERE.x + PILE_AT.x, WHERE.y + PILE_AT.y,
		Inventory.ground([_tool(HATCHET)])))
	_sheet(rook).decide = DecisionSource.recorded([
		Action.pick_up(HATCHET),
		Action.examine(HATCHET),
	])

	var loop := ControlLoop.on(scene, LOOP_SEED)
	loop.run(9)
	var written := PackedStringArray()
	written.append("an action finishing")
	written.append_array(_indent(loop.journal))
	written.append("  " + _counts_line(loop))
	return written


## Being attacked while acting. One character settles in to wait out twenty
## ticks; the other spends its own turn on a spear. The blow lands part-way
## through the wait, and the wait is abandoned rather than served out -- nobody
## reported the interruption, the loop read it off a health score that fell.
##
## The fight is *played* here, one turn at a time through `fight_step()`, which
## is what makes the two halves of the scene fall in the order they do. A wait is
## not spent out of a turn, so the character that waits does not hold the board
## up: its turn is played the tick it commits and passes on. An attack is spent
## out of a turn, so the striker's turn lasts as long as the blow does -- and the
## blow therefore lands on the striker's own turn, into a wait that is still
## running.
static func attacked_while_acting() -> PackedStringArray:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var rook := _put(scene, "Rook", ROOK_LEVEL,
		WHERE - Vector2(DUEL_APART * 0.5, 0.0), AssetTags.KNIGHT)
	(rook.piece as Commander).wield(Weapon.held(Weapon.spear(), ROOK_LEVEL))
	var vex := _put(scene, "Vex", VEX_LEVEL,
		WHERE + Vector2(DUEL_APART * 0.5, 0.0), AssetTags.BARBARIAN)
	(vex.piece as Commander).wield(Weapon.held(Weapon.spear(), VEX_LEVEL))

	var written := PackedStringArray()
	var began := scene.begin_fight(rook.id)
	if began == null or began.refused:
		written.append("being attacked while acting: the fight was refused")
		return written

	# The one whose turn it is settles in to wait, so that the turn passes to the
	# other and the blow lands while the wait is still running.
	var struck := _whose_turn(scene)
	var striker := vex if struck == rook else rook
	_sheet(striker).decide = DecisionSource.recorded([Action.attack(struck.id, SPEAR)])
	_sheet(struck).decide = DecisionSource.recorded([Action.wait(20)])

	written.append("being attacked while acting")
	written.append("  %s waits out its turn; %s spends its own on a spear. %s starts on %d health" % [
		ActionScene.name_of(struck), ActionScene.name_of(striker),
		ActionScene.name_of(struck), struck.piece.health,
	])
	var loop := ControlLoop.on(scene, LOOP_SEED)
	for _step in ATTACKED_TICKS:
		loop.step()
		scene.fight_step()
	written.append_array(_indent(loop.journal))
	written.append("  %s ends on %d health" % [
		ActionScene.name_of(struck), struck.piece.health,
	])
	written.append("  " + _counts_line(loop))
	_release(scene)
	return written


## Combat starting. Two characters walking about; the fight begins under them
## between one tick and the next, and both abandon their walks the tick after,
## because being on a board is not a thing you walk across.
static func combat_starting() -> PackedStringArray:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var rook := _put(scene, "Rook", ROOK_LEVEL,
		WHERE - Vector2(DUEL_APART * 0.5, 0.0), AssetTags.KNIGHT)
	var vex := _put(scene, "Vex", VEX_LEVEL,
		WHERE + Vector2(DUEL_APART * 0.5, 0.0), AssetTags.BARBARIAN)
	for one: Combatant in [rook, vex]:
		var to := Vector2(one.x, one.z) + WALK_TO
		_sheet(one).decide = DecisionSource.scripted(
			func(_scene: ActionScene, _actor: Combatant) -> Action:
				return Action.go_to(to))

	var written := PackedStringArray()
	var loop := ControlLoop.on(scene, LOOP_SEED)
	loop.run(4)
	var began := scene.begin_fight(rook.id)
	if began == null or began.refused:
		written.append("combat starting: the fight was refused")
		return written
	written.append("combat starting (the fight begins between tick 4 and tick 5)")
	loop.run(2)
	written.append_array(_indent(loop.journal))
	written.append("  " + _counts_line(loop))
	return written


## A conversation opening. One character walks; the other waits two ticks and
## then says something to it by name. Being shouted at would not do -- a shout is
## the one kind of speech nobody has to answer -- so the word is addressed, and
## the walker drops the walk to attend to it.
static func conversation_opening() -> PackedStringArray:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var rook := _put(scene, "Rook", ROOK_LEVEL, WHERE, AssetTags.KNIGHT)
	var wren := _put(scene, "Wren", VEX_LEVEL,
		WHERE + Vector2(2.0, 0.0), AssetTags.MAGE)
	var to := WHERE + WALK_TO
	_sheet(rook).decide = DecisionSource.scripted(
		func(_scene: ActionScene, _actor: Combatant) -> Action:
			return Action.go_to(to))
	_sheet(wren).decide = DecisionSource.recorded([
		Action.wait(2),
		Action.say("a word with you", rook.id),
	])

	var loop := ControlLoop.on(scene, LOOP_SEED)
	loop.run(9)
	var written := PackedStringArray()
	written.append("a conversation opening")
	written.append_array(_indent(loop.journal))
	written.append("  %s never arrived: still at (%.3f, %.3f)" % [
		ActionScene.name_of(rook), rook.x, rook.z,
	])
	written.append("  " + _counts_line(loop))
	return written


# --- The bias -------------------------------------------------------------


## How often a character changes its mind mid-action, at the bias and without it.
##
## The character is deliberately restless: every time it is asked it wants
## somewhere else, so every re-evaluation is a real disagreement with what it is
## already doing and the bias is consulted every single time. Run at
## `ControlLoop.CONTINUE_BIAS` it keeps going through most of them; run at zero
## -- the loop with section 2.2's "biased toward continuing" deleted -- it
## abandons every one. The two rows are the measurement.
static func bias_measurement() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the bias, measured over %d ticks of a restless character" % MEASURE_TICKS)
	written.append("  %-22s %8s %8s %9s" % ["continue bias", "reviews", "changes", "changed"])
	for bias in [ControlLoop.CONTINUE_BIAS, BROKEN_BIAS]:
		var loop := _measure_at(bias)
		var counts := loop.counts()
		written.append("  %-22s %8d %8d %8.1f%%" % [
			"%.2f%s" % [bias, "" if bias == ControlLoop.CONTINUE_BIAS else " (broken)"],
			counts["reviews"], counts["changes"], 100.0 * loop.change_rate(),
		])
	return written


## One measured run at one bias.
static func _measure_at(bias: float) -> ControlLoop:
	var scene := ActionScene.on()
	var ada := _put(scene, "Ada", 1, Vector2.ZERO, AssetTags.MAGE)
	_sheet(ada).decide = DecisionSource.scripted(_restless(Vector2.ZERO))
	var loop := ControlLoop.on(scene, LOOP_SEED)
	loop.continue_bias = bias
	loop.run(MEASURE_TICKS)
	return loop


# --- A decision that takes arbitrarily long -------------------------------


## Three characters live the same world twice: once where all three answer at
## once, and once where one of them will not answer for forty ticks.
##
## What is compared is every character's tick count. The slow one waits in the
## world -- it stands where it stood, with nothing committed, and the transcript
## says so -- while the other two are serviced on exactly the same ticks and
## resolve exactly the same actions as they did when nobody was slow. That is
## section 12's requirement in the only form it can take without a model: the
## world does not wait for a decision, the character does.
static func slow_decider() -> PackedStringArray:
	var quick := _crowd(false)
	var slow := _crowd(true)

	var written := PackedStringArray()
	written.append("a slow decision function, over %d ticks" % WORLD_TICKS)
	written.append("  %-30s%s" % ["run", _crowd_heading()])
	written.append("  %-30s%s" % ["everybody answers at once", _crowd_row(quick)])
	written.append("  %-30s%s" % [
		"%s takes %d ticks to think" % [CROWD[0], THINKING_TICKS], _crowd_row(slow)])
	written.append("  while %s deliberated it stood at (%.3f, %.3f), committed to nothing" % [
		CROWD[0], slow["stood"].x, slow["stood"].y,
	])
	var others_match := true
	for who in [CROWD[1], CROWD[2]]:
		written.append("  %s was serviced for %d ticks with a fast %s, %d with a slow one" % [
			who, quick["ticks"][who], CROWD[0], slow["ticks"][who],
		])
		if quick["actions"][who] != slow["actions"][who]:
			others_match = false
	written.append("  and each of them resolved %s actions either way" % (
		"the same number of" if others_match else "a different number of"))
	written.append("  everything the other two did, tick by tick, is %s in both runs (%d lines)" % [
		"the same" if quick["others"] == slow["others"] else "different",
		slow["others"].size(),
	])
	written.append_array(_indent(slow["journal"]))
	return written


# One run of the three-character world, with Ash quick or slow.
static func _crowd(ash_is_slow: bool) -> Dictionary:
	var scene := ActionScene.on()
	var made := {}
	var spread := 0.0
	for who in CROWD:
		var stands := Vector2(spread, 0.0)
		var one := _put(scene, who, 1, stands, AssetTags.RANGER)
		_sheet(one).decide = DecisionSource.scripted(_restless(stands))
		made[who] = one
		spread += APART
	var ash: Combatant = made[CROWD[0]]
	if ash_is_slow:
		_sheet(ash).decide = DecisionSource.deliberate(
			DecisionSource.scripted(_restless(Vector2.ZERO)), THINKING_TICKS)

	var loop := ControlLoop.on(scene, LOOP_SEED)
	loop.run(THINKING_TICKS)
	var stood := Vector2(ash.x, ash.z)
	loop.run(WORLD_TICKS - THINKING_TICKS)

	var ticks := {}
	var actions := {}
	for who in CROWD:
		var one: Combatant = made[who]
		ticks[who] = loop.ticks_of(one.id)
		actions[who] = loop.actions_of(one.id)
	return {
		"ticks": ticks, "actions": actions, "stood": stood,
		"journal": _only(loop.journal, CROWD[0]),
		"others": _without(loop.journal, CROWD[0]),
	}


static func _crowd_heading() -> String:
	var written := PackedStringArray()
	for who in CROWD:
		written.append("%-19s" % ("%s ticks/actions" % who))
	return "".join(written)


static func _crowd_row(run: Dictionary) -> String:
	var written := PackedStringArray()
	for who in CROWD:
		written.append("%-19s" % ("%d / %d" % [run["ticks"][who], run["actions"][who]]))
	return "".join(written)


# --- The whole transcript -------------------------------------------------


## Everything above, in order. What `./run_loop.sh` prints.
static func report() -> PackedStringArray:
	var written := PackedStringArray()
	written.append_array(cadence())
	written.append("")
	written.append_array(finishing())
	written.append("")
	written.append_array(attacked_while_acting())
	written.append("")
	written.append_array(combat_starting())
	written.append("")
	written.append_array(conversation_opening())
	written.append("")
	written.append_array(bias_measurement())
	written.append("")
	written.append_array(slow_decider())
	return written


# --- The scenes' furniture ------------------------------------------------


## A rule that wants somewhere new every time it is asked.
##
## It walks a ring of `RESTLESS_STOPS` positions, one stop per question, so two
## questions asked within one twenty-tick walk can never land on the same answer
## and every re-evaluation therefore proposes something the character is not
## already doing. Nothing about the world is read: this is a stand-in for a mind
## that keeps changing, and its only job is to disagree.
static func _restless(around: Vector2) -> Callable:
	var asked := [0]
	return func(_scene: ActionScene, _actor: Combatant) -> Action:
		var stop: int = asked[0] % RESTLESS_STOPS
		asked[0] += 1
		return Action.go_to(around + Vector2(float(stop + 1) * RESTLESS_SPACING, 0.0))


## Put a character in a scene with a sheet on it, at a position.
static func _put(
	scene: ActionScene, called: String, level: int, at: Vector2, looks_like: String
) -> Combatant:
	var one := scene.add_actor(Combatant.commander_at(
		at.x, at.y, 0.0, 0.0, level, looks_like))
	var sheet := Character.make(called, level)
	sheet.record_scores({Ability.DEX: 4, Ability.STR: 5})
	(one.piece as Commander).adopt(sheet)
	return one


# A hand-held item at level 1, forged exactly as the action walkthrough forges
# one: everything it is worth goes to its effects axis.
static func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


# Only the lines of a journal about one character.
static func _only(journal: PackedStringArray, who: String) -> PackedStringArray:
	var written := PackedStringArray()
	for line in journal:
		if line.contains(" %s " % who):
			written.append(line)
	return written


# Every line of a journal that is not about one character.
static func _without(journal: PackedStringArray, who: String) -> PackedStringArray:
	var written := PackedStringArray()
	for line in journal:
		if not line.contains(" %s " % who):
			written.append(line)
	return written


static func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet


# Take the decision functions back off the sheets when a scene is done with,
# cutting the ring that otherwise keeps the scene and the rules alive.
static func _release(scene: ActionScene) -> void:
	for one in scene.actors:
		if one.piece is Commander:
			(one.piece as Commander).sheet.decide = Callable()


# Whose turn it is in the fight, as the character standing in the world.
static func _whose_turn(scene: ActionScene) -> Combatant:
	for one in scene.actors:
		if one.piece.id == scene.fight.match_state.active_id():
			return one
	return scene.actors[0]


# What a loop counted, in one line.
static func _counts_line(loop: ControlLoop) -> String:
	var counts := loop.counts()
	var written := PackedStringArray()
	for key in counts:
		written.append("%s=%s" % [key, counts[key]])
	return " ".join(written)


static func _indent(lines: PackedStringArray) -> PackedStringArray:
	var written := PackedStringArray()
	for line in lines:
		written.append("  " + line)
	return written
