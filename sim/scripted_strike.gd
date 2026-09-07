extends RefCounted
## The world's record of a blow, written down: what it carries, and that it
## carries the same thing whoever struck it.
##
##     ./run_strike.sh
##
## A blow is the one thing in this world that has to be *drawn* -- a swing is a
## motion, an arrow is a thing crossing the ground -- and until now the record of
## one said only who hit whom for how much. That is enough to work out what two
## people are to each other and not nearly enough to draw anything: a motion
## needs to know which motion and when it started, and a flight needs a cell to
## leave from and a cell to arrive at.
##
## So the record was widened, and this run is the evidence that it was widened
## once rather than twice. Two commanders stand on one board with the same spear:
##
##   * **Alder** is played by hand. Their turns are nobody's to take but the
##     person's -- `ActionScene.take_by_hand` -- and this file takes them the way
##     a person does, through `BoardTurn`: turn until the spear covers somebody,
##     use the weapon action, end the turn.
##   * **Briar** is played by its own decision function, which chooses
##     `Action.attack` and nothing else. `ControlLoop` services it, `ActionEngine`
##     answers it, and the blow lands on Briar's own turn.
##
## Two ways in, and neither of them writes a blow down. Both spend a weapon action
## through `CombatMatch.attack`, which is where a blow is recorded, and
## `ActionScene` takes the record off the board and writes it into its own
## `blows` -- so the two rows below are the same row with different numbers in it,
## and there is no second channel for either of them to have come down.
##
## ## The four sections
##
##   * **the fight** -- the whole run, tick by tick, so the two blows can be found
##     in it.
##   * **the same record from either hand** -- the first blow each of them struck,
##     field by field, side by side.
##   * **every blow in the run** -- one line each, with the driver that spent it.
##   * **what leaves the simulation** -- the same rows as the snapshot carries
##     them out, which is how they reach anything that draws.
class_name ScriptedStrike

## The seed and the ground: the same measured open meadow every other walkthrough
## is played on, so this run invents no coordinate.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE

## The seed the control loop's continue-bias draws are hashed from.
const LOOP_SEED := ScriptedLoop.LOOP_SEED

## Who is in it. Alder's turns are a person's to take; Briar's are its own
## decision function's.
const HAND := "Alder"
const MIND := "Briar"
const LEVEL := 3

## What both of them strike with. The same weapon on both sides, so the two
## records can be read against each other field by field.
const SPEAR := "common spear"

## Which of the spear's weapon actions the person spends. The first one, which is
## the one that comes round every turn.
const QUICK := 0

## How far apart the two stand when the board appears, and how long the run is
## watched for. Long enough for several whole turns on both sides.
const APART := ScriptedActions.DUEL_APART
const TICKS := 60

## How often the person spends a turn, in ticks.
##
## A person is not instant, and this run needs both sides of it to land a blow.
## Left to take every turn the moment one stands, the hand-played commander would
## spend one every tick and the fight would be over before a character deciding
## for itself had finished deciding once. Ten ticks is longer than the six an
## `attack` occupies and longer than the gap a blow leaves before it interrupts
## whatever the character it landed on had begun, so a character choosing for
## itself gets a whole action in between two of the person's turns.
const HAND_PACE := 10


# --- The scene ------------------------------------------------------------


## Two commanders on one board, each carrying a spear, with one of them handed
## over to be played by hand.
##
## Built on a `CombatantRoster` rather than a bare scene, because the last
## section reads the snapshot and the snapshot is the roster's. The roster adds
## no rule: it walks its members and calls `ActionScene.fight_step()`, and both
## of the two are seated on a board and do not walk.
static func stage(seed_value: int = SEED) -> CombatantRoster:
	var roster := CombatantRoster.new()
	roster.scene.terrain = TerrainQuery.for_seed(seed_value)
	var one := _put(roster, HAND, WHERE - Vector2(APART * 0.5, 0.0))
	var two := _put(roster, MIND, WHERE + Vector2(APART * 0.5, 0.0))
	(one.piece as Commander).wield(Weapon.held(Weapon.spear(), LEVEL))
	(two.piece as Commander).wield(Weapon.held(Weapon.spear(), LEVEL))
	var began := roster.scene.begin_fight(one.id)
	if began == null or began.refused:
		return roster
	roster.scene.take_by_hand(one.id)
	return roster


## Put the decision function on Briar's sheet, and on nobody else's: strike at
## whoever else is on the board, always. Alder has none, because a character
## somebody is playing does not decide for itself.
static func drive(roster: CombatantRoster) -> void:
	for one in roster.members:
		var sheet := _sheet(one)
		if sheet == null or sheet.character_name != MIND:
			continue
		sheet.decide = DecisionSource.scripted(
			func(scene: ActionScene, actor: Combatant) -> Action:
				for other in scene.actors:
					if other == actor or not other.is_alive() or not other.fighting:
						continue
					return Action.attack(other.id, SPEAR)
				return null
		)


# --- Living a run ---------------------------------------------------------


## Play one run and hand back what came of it: the transcript, the roster it was
## played on, the ids the two of them go under, and a snapshot taken while the
## fight was still on.
##
## Three calls per tick, and the order is the ordering every driver keeps with the
## person put in front of it: the person spends a turn if one is standing for
## them and they are due one, the characters are serviced, and then the roster
## steps -- which walks everybody and takes whatever of a turn the board is owed.
## A turn that is Alder's is not played by the board at all; it stands until
## `BoardTurn.finish` hands it over, which is what `ActionScene.hands` is.
##
## The person goes first for the same reason a person goes first anywhere: they
## are not part of the tick, they are the thing the tick is happening around. A
## blow struck by hand is therefore struck *outside* both the loop's call and the
## board's, and is taken off the board on the next one of those. It still says the
## tick it began on, because the board is told where the world's clock is every
## time the clock moves.
static func played(ticks: int = TICKS) -> Dictionary:
	var roster := stage()
	var scene := roster.scene
	var loop := ControlLoop.on(scene, LOOP_SEED)
	drive(roster)
	var hand_id := _id_of(roster, HAND)
	var mind_id := _id_of(roster, MIND)

	var written := PackedStringArray()
	var said := 0
	var seen := {}
	var ending := false
	for _step in maxi(0, ticks):
		if ending:
			written.append_array(_indent(_end_the_turn(scene, hand_id)))
			ending = false
		elif scene.tick > 0 and scene.tick % HAND_PACE == 0:
			written.append_array(_indent(_take_a_turn_by_hand(scene, hand_id)))
			ending = BoardTurn.of(scene, hand_id) != null
		loop.step()
		for at in range(said, loop.journal.size()):
			written.append(loop.journal[at])
		said = loop.journal.size()
		written.append_array(_indent(roster.step(scene.terrain)))
		# What anything drawing this world would be holding, taken while there is
		# still a fight to draw. A snapshot taken after the board is put away is a
		# true snapshot of a world with no fight in it, and no use as evidence
		# about one.
		if roster.fight != null:
			seen = roster.snapshot()

	var run := {
		"lines": written,
		"roster": roster,
		"hand_id": hand_id,
		"mind_id": mind_id,
		"blows": scene.blows.duplicate(),
		"snapshot": seen,
	}
	release(scene)
	return run


# The spending half of the person's turn, if one is standing for them: turn until
# the spear covers somebody, and use the weapon action. Nothing else in this file
# touches the board.
#
# Every call here is `BoardTurn`'s, which forwards every question to the
# simulation that already answered it for everybody else. Turning is free, so the
# quarters cost the turn nothing however many of them it takes.
static func _take_a_turn_by_hand(scene: ActionScene, id: int) -> PackedStringArray:
	var written := PackedStringArray()
	var turn := BoardTurn.of(scene, id)
	if turn == null:
		return written
	for _quarter in PieceGeometry.FACINGS.size():
		if _covers_somebody(scene, turn):
			break
		turn.turn_right()
	var swung := turn.swing(QUICK)
	written.append("by hand: %s %s facing=%s%s" % [
		ActionScene.name_of(turn.member),
		"swung" if bool(swung.get("ok", false)) else "could not swing",
		turn.facing_name(),
		"" if bool(swung.get("ok", false)) else " (%s)" % str(swung.get("reason", "")),
	])
	return written


# And the other half, a tick later: the turn is handed over.
#
# A person does not swing and pass the board on in the same instant, and it
# matters here that they do not. A character that is struck gives up whatever it
# had begun -- section 2.2's "attacked while moving" -- so a blow landing in the
# very tick the board passes to the person's opponent would take that opponent's
# turn away from it before it could commit to anything, every round, forever. A
# tick between the two is all it takes, and it is what a person would do anyway.
static func _end_the_turn(scene: ActionScene, id: int) -> PackedStringArray:
	var written := PackedStringArray()
	var turn := BoardTurn.of(scene, id)
	if turn == null:
		return written
	turn.finish()
	written.append("by hand: %s ended the turn" % ActionScene.name_of(turn.member))
	return written


# Whether the weapon action the person spends covers anybody else standing on the
# board. The cells are the simulation's answer; this only reads them.
static func _covers_somebody(scene: ActionScene, turn: BoardTurn) -> bool:
	var covered := turn.attack_cells(QUICK)
	for one in scene.actors:
		if one == turn.member or not one.is_alive() or not one.fighting:
			continue
		if covered.has(one.piece.cell):
			return true
	return false


# --- The four sections ----------------------------------------------------


## The fight itself, tick by tick.
static func the_fight() -> PackedStringArray:
	var run := played()
	var written := PackedStringArray()
	written.append("the fight: %s played by hand, %s by its own decision function" % [
		HAND, MIND,
	])
	written.append_array(_indent(run["lines"]))
	return written


## The first blow each of them struck, field by field, side by side.
##
## The claim is the whole of this item: the two rows have the same fields and
## every one of them is filled, whoever spent the weapon action. If the two ways
## into a blow had grown two records, this table would have holes down one column.
static func side_by_side() -> PackedStringArray:
	var run := played()
	var written := PackedStringArray()
	var first := _first_blow_of(run, int(run["hand_id"]))
	var second := _first_blow_of(run, int(run["mind_id"]))
	written.append("the same record from either hand")
	written.append("  %-12s %-28s %-28s" % [
		"field", "%s (a person)" % HAND, "%s (its own choice)" % MIND,
	])
	if first.is_empty() or second.is_empty():
		written.append("  one of the two struck no blow in %d ticks" % TICKS)
		return written
	for field in FIELDS:
		written.append("  %-12s %-28s %-28s" % [
			field, _worth(first.get(field)), _worth(second.get(field)),
		])
	written.append("  same fields: %s" % (
		"yes" if first.keys() == second.keys() else "no"))
	return written


## Every blow the run landed, one line each, with the driver that spent it.
static func every_blow() -> PackedStringArray:
	var run := played()
	var written := PackedStringArray()
	var blows: Array = run["blows"]
	written.append("every blow in the run (%d)" % blows.size())
	written.append("  %5s %6s %-8s %-10s %-6s %-8s %-10s %s" % [
		"tick", "round", "struck by", "attack", "dealt", "sprite", "animation",
		"movement",
	])
	for blow in blows:
		written.append("  %5d %6d %-8s %-10s %6s %-8s %-10s %s" % [
			int(blow["tick"]), int(blow["round"]), String(blow["by"]),
			String(blow["attack"]),
			"%d/%d" % [int(blow["dealt"]), int(blow["out_of"])],
			String(blow["sprite"]), String(blow["animation"]),
			String(blow["movement"]),
		])
	return written


## The same rows as they leave the simulation.
##
## `CombatantRoster.snapshot()` is what anything drawing this world already
## receives, and the blows ride out in it beside the pieces and the ground. So a
## render layer reads a swing out of a dictionary it already has rather than
## reaching into the fight for it -- which is the one thing this item had to make
## true before a hand, a clip or an arrow could be hung off it.
static func what_leaves_the_simulation() -> PackedStringArray:
	var run := played()
	var snapshot: Dictionary = run["snapshot"]
	var rows: Array = snapshot.get("blows", [])
	var written := PackedStringArray()
	written.append("what leaves the simulation, in the snapshot")
	written.append("  tick=%d round=%d fighting=%s fights_begun=%d blows=%d" % [
		int(snapshot.get("tick", 0)), int(snapshot.get("round", 0)),
		"yes" if bool(snapshot.get("fighting", false)) else "no",
		int(snapshot.get("fights_begun", 0)), rows.size(),
	])
	for row in rows:
		written.append("  #%d -> #%d %s from %s to %s over %d cell%s, %s at tick %d" % [
			int(row["from"]), int(row["to"]), String(row["attack"]),
			_worth(row["from_cell"]), _worth(row["to_cell"]),
			(row["cells"] as Array).size(),
			"" if (row["cells"] as Array).size() == 1 else "s",
			String(row["animation"]), int(row["tick"]),
		])
	return written


## Everything above, in order. What `./run_strike.sh` prints.
static func play() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the record of a blow seed=%d ticks=%d" % [SEED, TICKS])
	written.append("")
	written.append_array(the_fight())
	written.append("")
	written.append_array(side_by_side())
	written.append("")
	written.append_array(every_blow())
	written.append("")
	written.append_array(what_leaves_the_simulation())
	return written


# --- The furniture --------------------------------------------------------

## Every field of a blow, in the order the table prints them. The record's own
## keys, named here so that a field quietly going missing shows up as a blank
## column rather than as nothing at all.
const FIELDS := [
	"from", "by", "to", "tick", "round", "fight", "dealt", "out_of", "hits",
	"attack", "facing", "from_cell", "to_cell", "cells", "sprite", "animation",
	"movement", "cooldown",
]


## The first blow one of them struck, or an empty dictionary if they struck none.
static func _first_blow_of(run: Dictionary, id: int) -> Dictionary:
	for blow in run["blows"]:
		if int(blow["from"]) == id:
			return blow
	return {}


## Take the decision function back off the sheets when a run is over, cutting the
## ring that otherwise keeps the scene, the sheets and the rules alive.
static func release(scene: ActionScene) -> void:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null:
			sheet.decide = Callable()


static func _put(roster: CombatantRoster, called: String, at: Vector2) -> Combatant:
	var one := roster.add(Combatant.commander_at(
		at.x, at.y, 0.0, 0.0, LEVEL, AssetTags.KNIGHT))
	var sheet := Character.make(called, LEVEL)
	sheet.record_scores({Ability.DEX: 4, Ability.STR: 5})
	(one.piece as Commander).adopt(sheet)
	one.settle(roster.scene.terrain)
	return one


static func _sheet(one: Combatant) -> Character:
	if one == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


static func _id_of(roster: CombatantRoster, called: String) -> int:
	for one in roster.members:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == called:
			return one.id
	return ActionScene.NOBODY


# One field of a record as one word, whatever sort of value it is.
static func _worth(value: Variant) -> String:
	if value is Vector2i:
		return "(%d,%d)" % [value.x, value.y]
	if value is Array:
		var parts := PackedStringArray()
		for cell in value:
			parts.append(_worth(cell))
		return " ".join(parts) if not parts.is_empty() else "-"
	var written := str(value)
	return written if written != "" else "-"


static func _indent(lines: PackedStringArray) -> PackedStringArray:
	var written := PackedStringArray()
	for line in lines:
		written.append("  " + line)
	return written
