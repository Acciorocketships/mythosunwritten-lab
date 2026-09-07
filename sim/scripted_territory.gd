extends RefCounted
## Section 6's claim, measured end to end: winning battles and winning hearts
## both shift who owns the same ground.
##
## Section 6 says both paths matter: "winning battles (raising your level,
## removing rival owners) and winning hearts (raising sentiment) both shift
## ownership." The ownership rule is built (`OwnershipField`), the two ways
## goodwill is earned are built (`DeedDesk`, `CheckDesk`), and a fight that fells
## a commander is built (`ActionScene.fight_step`). What has not been shown is
## the sentence itself, on this implementation: that a fight moves ownership of a
## point of ground, that a friendship moves ownership of the same point, and by
## how much each. This run is that measurement and nothing else: no rule is
## changed in it and no constant of the ownership arithmetic is touched.
##
## ## The two runs, and the one way they differ
##
## One seed, one cast, one piece of ground. Five people: Wren, three neighbours
## -- Bram, Sable and Odo, the same three sheets `ScriptedGoodwill` measures on,
## wanting the same three things -- and Rook, a rival commander standing at a
## post north of the green.
##
## Both runs open identically. Rook walks its round: two small gifts to each
## neighbour, six honoured trades, then back to its post. That is the incumbent
## being built out of the engine's own record -- the transcript's edge lines
## show what each neighbour then feels toward Rook, trust 0.73 at familiarity
## 0.44 -- so that when the runs part there is a rival owner to remove or to
## out-earn. Wren waits on the green until tick `WREN_FROM`.
##
## From `WREN_FROM` the runs differ in exactly one thing, and nothing else: which
## written rule drives Wren.
##
##   * **fight** -- `_winning_fights`: walk to Rook's post and attack until Rook
##     falls. The blow that starts it snaps the world to a board
##     (`ActionEngine._open_the_fight`); the felling is the board's; the fallen
##     leave the cast and can neither vote nor hold ground.
##   * **friendship** -- `_winning_hearts`: walk to each neighbour and hand over
##     first the thing that neighbour actually wanted, then one small gift --
##     six honoured trades, the same number of exchanges Rook made. The wanted
##     thing closes a goal the world was watching, `DeedDesk` reads the deed off
##     the trade record and asks a model what it was worth, and the judged share
##     lands as trust on top of the trade's own.
##
## Everything else -- seed, cast, sheets, goals, inventories, Rook's rule, the
## neighbours' rule, the tick count, the machinery stepped each tick -- is
## byte-for-byte the same code in both runs, and the run prints both worlds'
## fingerprints at the divergence tick so "identical until they part" is a line
## in the transcript rather than a promise.
##
## ## One band, so the only fight is the one that is chosen
##
## Every commander here is put in one band. Two commanders of different bands
## within `ActionScene.ENGAGE_RADIUS` of each other start a fight by drifting
## together, and this run needs Rook to gift neighbours at arm's length and Wren
## to trade with them, in peace, in one arm -- so nobody is anybody's enemy by
## label. The fight in the fight run begins the other way a fight can begin:
## somebody chose to attack somebody (`_open_the_fight`). That choice is the one
## difference between the runs, which is exactly where it belongs.
##
## ## What is measured
##
## Ownership of six named points -- the green, the three neighbours' doors,
## Rook's post, and a far road out of everybody's earshot as the locality
## control -- read through `OwnershipField.at` (the shipped constants, no second
## copy of the arithmetic) at three moments: as staged, at the divergence tick,
## and at the end. Plus the same grid of ground `ScriptedGoodwill` samples, so
## "how much ground changed hands" is a count of points and not an impression.
##
## ## What the model answers here, said plainly
##
## The friendship run asks three deed questions. They are answered by replaying
## `ModelRecording.goodwill_exchange()` -- the recorded judgements of the
## goodwill run's deed questions, which are the same three neighbours being
## handed the same three wanted things. The prompts here differ from the
## recorded ones only in the world's tick stamps and cast ids, so no digest
## matches and the channel answers by position, saying so on each reply. The
## judged amounts are therefore a capable model's judgements of this very
## situation, not numbers chosen by this file; the fight run asks nothing.
class_name ScriptedTerritory

## The world this is played on: the ground, seed and meeting place every other
## scripted run uses.
const SEED := ScriptedGoodwill.SEED
const WHERE := ScriptedGoodwill.WHERE
const LOOP_SEED := ScriptedGoodwill.LOOP_SEED

## How long a run is: Rook's round, then Wren's arm, then time for every answer
## and every walk to land.
const TICKS := 340

## The tick the two runs part: Wren's rule does nothing but wait before this,
## and Rook's round is comfortably over by it.
const WREN_FROM := 170

## The two runs, named.
const FIGHT := "fight"
const FRIENDSHIP := "friendship"
const ARMS := [FIGHT, FRIENDSHIP]

## Who does the doing: the same talker `ScriptedGoodwill` plays, here doing no
## talking at all.
const WREN := "Wren"
const WREN_LEVEL := ScriptedGoodwill.WREN_LEVEL
const WREN_SCORES := ScriptedGoodwill.WREN_SCORES

## The three neighbours: the same names, sheets, places and wants the goodwill
## run measures on, referenced rather than copied so the two runs cannot drift
## apart.
const NEIGHBOURS := ScriptedGoodwill.NEIGHBOURS

## The rival: an ordinary commander of Wren's own level, standing apart.
const ROOK := "Rook"
const ROOK_LEVEL := 2
const ROOK_SCORES := {
	Ability.STR: 8, Ability.CON: 8, Ability.CHA: 5,
	Ability.DEX: 6, Ability.WIS: 6, Ability.INT: 5,
}

## Where Rook stands, relative to the green: further than `Encounter.JOIN_RADIUS`
## from every neighbour, so the fight at the post is Wren and Rook alone on the
## board and ends when one of them falls; well inside `OwnershipField.RADIUS` of
## all of them, so the post is ground the neighbours have a say over.
##
## Negative z, because a river crosses the ground south-east of the green at
## this seed and a walk here is a straight line over `is_passable_at`:
## `tools/territory_ground_probe.gd` prints the map this was placed against,
## and every walk either run takes stays on the passable side of it.
const POST := Vector2(0.0, -34.0)

## What Rook gives on its round: two small things to each neighbour, in the
## order the neighbours are listed. None of them is a thing anybody wants by
## goal, so no deed is read into them: six plain honoured trades, and the
## incumbent's claim is exactly what trading earns.
const ROUND := [
	["tin whistle", "clay bead"],
	["reed flute", "wax candle"],
	["birch spoon", "tallow lamp"],
]

## The small gift Wren adds after the wanted thing, one per neighbour: the same
## six-exchange effort Rook spent, three of them deeds.
const EXTRA := ["pressed flower", "river pearl", "carved whistle"]

## What Wren fights with, when it fights: a common sword forged at Wren's level.
## Carried in both runs; drawn in one.
const SWORD := "common sword"

## The six named points ownership is read at, as offsets from the green. The far
## road is further from everybody than `OwnershipField.RADIUS`: it hears nobody,
## and it is in the table so the locality of both effects is shown rather than
## asserted.
const POINTS := [
	{"named": "the green", "at": Vector2(0.0, 0.0)},
	{"named": "Bram's door", "at": Vector2(7.0, 0.0)},
	{"named": "Sable's door", "at": Vector2(5.0, 5.0)},
	{"named": "Odo's door", "at": Vector2(-4.0, -7.0)},
	{"named": "Rook's post", "at": POST},
	{"named": "the far road", "at": Vector2(200.0, 0.0)},
]

## The grid of ground sampled for the changed-hands counts: the same square the
## goodwill run samples, stated again here. 31 x 31 = 961 points over 300 x 300
## world units, wider than `OwnershipField.RADIUS` so the edge of the territory
## is inside it.
const GRID_REACH := 150.0
const GRID_STEP := 10.0

## How long anybody with something to watch for waits before looking up again,
## and how long somebody with nothing left to do waits.
const WATCH := 4
const REST := 30

## The roll seed handed to the check desk. No line is ever spoken in either run,
## so no check is raised and no die of this stream is ever drawn; the desk is
## stepped anyway so that "0 checks raised" is measured rather than assumed.
const ROLL_SEED := 1


# --- The world -------------------------------------------------------------


## Set the run out. Identical in both arms, down to the goals and the sword.
##
## Wren first and the neighbours next, in the goodwill run's order, then Rook --
## so the neighbour ids match that run's and a reader can put the two
## transcripts side by side. Everybody is then put in one band; see the note at
## the head of this file.
static func stage(seed_value: int = SEED) -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(seed_value))
	var wren := scene.add_actor(Combatant.commander_at(
		WHERE.x, WHERE.y, 0.0, 0.0, WREN_LEVEL, AssetTags.ROGUE))
	var sheet := Character.make(WREN, WREN_LEVEL)
	sheet.record_scores(WREN_SCORES)
	(wren.piece as Commander).adopt(sheet)
	wren.settle(scene.terrain)

	for row in NEIGHBOURS:
		var at: Vector2 = row["at"]
		var one := scene.add_actor(Combatant.commander_at(
			WHERE.x + at.x, WHERE.y + at.y, 0.0, 0.0, int(row["level"]),
			AssetTags.KNIGHT))
		var theirs := Character.make(String(row["name"]), int(row["level"]))
		theirs.record_scores(row["scores"])
		(one.piece as Commander).adopt(theirs)
		one.settle(scene.terrain)
		# Scenario setup, exactly as the goodwill run writes it: a wanted state
		# on the wanting character's own sheet, told to nobody.
		theirs.goals.add(Goal.of(
			Goal.HOLD, {"item": String(row["wants"])}, "", Goal.SHORT))
		sheet.inventory.carry(_wearable(String(row["wants"])))

	var rook := scene.add_actor(Combatant.commander_at(
		WHERE.x + POST.x, WHERE.y + POST.y, 0.0, 0.0, ROOK_LEVEL,
		AssetTags.KNIGHT))
	var rooks := Character.make(ROOK, ROOK_LEVEL)
	rooks.record_scores(ROOK_SCORES)
	(rook.piece as Commander).adopt(rooks)
	rook.settle(scene.terrain)
	for gifts in ROUND:
		for gift in gifts:
			rooks.inventory.carry(_trinket(String(gift)))

	(wren.piece as Commander).wield(Weapon.held(Weapon.sword(), WREN_LEVEL))
	for gift in EXTRA:
		sheet.inventory.carry(_trinket(String(gift)))

	# One band for everybody, so no fight begins because two people drifted
	# within `ENGAGE_RADIUS` of each other on a gifting round. The only way a
	# fight can start in this world is that somebody chooses to attack.
	for one in scene.actors:
		one.band = wren.id
	return scene


## Put a decision function on every sheet. `arm` decides Wren's and nothing
## else's: this call is the whole of the difference between the two runs.
static func drive(scene: ActionScene, arm: String) -> void:
	_sheet(_named(scene, WREN)).decide = DecisionSource.scripted(
		ScriptedTerritory._winning_fights if arm == FIGHT
		else ScriptedTerritory._winning_hearts)
	_sheet(_named(scene, ROOK)).decide = DecisionSource.scripted(
		ScriptedTerritory._giving_the_round)
	for row in NEIGHBOURS:
		_sheet(_named(scene, String(row["name"]))).decide = DecisionSource.scripted(
			ScriptedTerritory._standing_by)


# --- The four rules --------------------------------------------------------


## Rook's round, and the whole of Rook: give each neighbour its two things, go
## back to the post, stand there. If a fight finds Rook, Rook stands in it --
## the rival does not fight back, which the report names as a thing this
## comparison does not isolate.
static func _giving_the_round(scene: ActionScene, actor: Combatant) -> Action:
	if scene.is_fighting(actor):
		return Action.wait(WATCH)
	var pack := ActionScene.inventory_of(actor)
	for at in NEIGHBOURS.size():
		var one := _named(scene, String(NEIGHBOURS[at]["name"]))
		if one == null:
			continue
		for gift in ROUND[at]:
			if not _carries(pack, String(gift)):
				continue
			if _offer_pending(scene, actor.id, one.id):
				return Action.wait(WATCH)
			if actor.distance_to(one) > ActionEngine.REACH:
				return Action.go_to(one.id)
			return Action.trade_propose(one.id, PackedStringArray([String(gift)]))
	var post := WHERE + POST
	if Vector2(actor.x, actor.z).distance_to(post) > ActionEngine.ARRIVE:
		return Action.go_to(post)
	return Action.wait(REST)


## What a neighbour does: take whatever is held out, and otherwise stand about.
## The same rule the goodwill run gives them, word for word.
static func _standing_by(scene: ActionScene, actor: Combatant) -> Action:
	for offer in scene.offers:
		if int(offer["to"]) == actor.id:
			return Action.trade_accept(int(offer["from"]))
	return Action.wait(WATCH)


## Wren in the fight run: wait out the round, then walk to Rook and attack until
## Rook is no longer standing. The first blow chosen out of real time is what
## snaps the world to a board; every one after it is a turn on that board.
static func _winning_fights(scene: ActionScene, actor: Combatant) -> Action:
	if scene.tick < WREN_FROM:
		return Action.wait(WATCH)
	var rook := _named(scene, ROOK)
	if rook == null or not rook.is_alive():
		return Action.wait(REST)
	if scene.is_fighting(actor):
		return Action.attack(rook.id, SWORD)
	if actor.distance_to(rook) > ActionEngine.REACH:
		return Action.go_to(rook.id)
	return Action.attack(rook.id, SWORD)


## Wren in the friendship run: wait out the round, then walk to each neighbour
## and hand over first the thing it wanted, then one small gift. Not a word is
## spoken in it: every point of sentiment this rule earns is a deed's or a
## trade's, so the talk gate is not in this comparison at all.
static func _winning_hearts(scene: ActionScene, actor: Combatant) -> Action:
	if scene.tick < WREN_FROM:
		return Action.wait(WATCH)
	var pack := ActionScene.inventory_of(actor)
	for at in NEIGHBOURS.size():
		var one := _named(scene, String(NEIGHBOURS[at]["name"]))
		if one == null:
			continue
		for gift in [String(NEIGHBOURS[at]["wants"]), String(EXTRA[at])]:
			if not _carries(pack, gift):
				continue
			if _offer_pending(scene, actor.id, one.id):
				return Action.wait(WATCH)
			if actor.distance_to(one) > ActionEngine.REACH:
				return Action.go_to(one.id)
			return Action.trade_propose(one.id, PackedStringArray([gift]))
	return Action.wait(REST)


# --- Living one run --------------------------------------------------------


## Play one run and hand back everything the tables are made of: the scene, the
## desks, and the survey of the ground at the three stated moments.
static func played_with(
	channel: ModelChannel, arm: String, ticks: int = TICKS,
	seed_value: int = SEED
) -> Dictionary:
	var scene := stage(seed_value)
	drive(scene, arm)
	var loop := ControlLoop.on(scene, LOOP_SEED)
	var desk := CheckDesk.with_channel(channel, ROLL_SEED)
	var deeds := DeedDesk.with_channel(channel)
	var asked_before := channel.exchanges.size()
	var staged := survey(scene)
	var parted := {}
	var fight_lines := PackedStringArray()
	for _step in maxi(0, ticks):
		if scene.tick == WREN_FROM:
			# The moment the runs part, surveyed before this tick is lived, so
			# both arms answer from the same world if they really are the same.
			parted = survey(scene)
		loop.step()
		var turn := scene.fight_step()
		if turn["began"] != null:
			fight_lines.append("t=%3d  the fight begins around %s" % [
				scene.tick, ActionScene.name_of(turn["began"]),
			])
		fight_lines.append_array(turn["lines"])
		if turn["ended"]:
			fight_lines.append("t=%3d  the fight is over; real time again" % scene.tick)
			fight_lines.append_array(turn["over"])
		desk.step(scene)
		deeds.step(scene)
	return {
		"arm": arm, "scene": scene, "loop": loop, "desk": desk, "deeds": deeds,
		"fight": fight_lines, "staged": staged, "parted": parted,
		"ended": survey(scene),
		"replies": channel.exchanges.slice(asked_before),
	}


## Ownership of the six named points and of the whole sampled grid, at one
## moment, through the shipped rule and nothing else. Reading it changes
## nothing, so the run is the same run however often it is asked.
static func survey(scene: ActionScene) -> Dictionary:
	var wren_id := _id_of(scene, WREN)
	var rook_id := _id_of(scene, ROOK)
	var points := []
	for row in POINTS:
		var at: Vector2 = WHERE + (row["at"] as Vector2)
		var claim := OwnershipField.at(scene.actors, scene.relationships, at.x, at.y)
		points.append({
			"named": String(row["named"]), "owner": claim.owner_id,
			"wren": claim.score_of(wren_id), "rook": claim.score_of(rook_id),
		})
	var cells := {}
	var owners := PackedInt32Array()
	for at in grid():
		var claim := OwnershipField.at(scene.actors, scene.relationships, at.x, at.y)
		owners.append(claim.owner_id)
		if not claim.is_neutral():
			cells[claim.owner_id] = int(cells.get(claim.owner_id, 0)) + 1
	return {
		"tick": scene.tick, "fingerprint": scene.fingerprint(),
		"points": points, "cells": cells, "owners": owners,
	}


## The grid of ground sampled, in world units.
static func grid() -> Array[Vector2]:
	var found: Array[Vector2] = []
	var across := int(round(GRID_REACH * 2.0 / GRID_STEP)) + 1
	for row in across:
		for column in across:
			found.append(Vector2(
				WHERE.x - GRID_REACH + float(column) * GRID_STEP,
				WHERE.y - GRID_REACH + float(row) * GRID_STEP))
	return found


# --- The run ---------------------------------------------------------------


## The whole comparison as a transcript.
static func play(
	channel: ModelChannel, ticks: int = TICKS, seed_value: int = SEED,
	arms: Array = ARMS
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append_array(_opening(channel, ticks, seed_value))

	var played := {}
	for arm in arms:
		played[arm] = played_with(channel, String(arm), ticks, seed_value)
		written.append("")
		written.append_array(_arm_lines(played[arm]))

	if played.has(FIGHT) and played.has(FRIENDSHIP):
		written.append("")
		written.append_array(_the_table(played))
		written.append("")
		written.append_array(_the_numbers(played))
		written.append("")
		written.append_array(_not_isolated())
	return written


# --- The head --------------------------------------------------------------


static func _opening(
	channel: ModelChannel, ticks: int, seed_value: int
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("territory run seed=%d ticks=%d where=(%.1f, %.1f)" % [
		seed_value, ticks, WHERE.x, WHERE.y,
	])
	written.append("  channel    %s -- %s" % [channel.kind, channel.why])
	written.append("  recording  %s" % channel.recorded)
	written.append("  the rule   ownership per point by OwnershipField.at: %s T=%.1f"
		% [OwnershipField.PROXIMITY, OwnershipField.TEMPERATURE]
		+ " R=%.1f threshold=%.4f, untouched" % [
			OwnershipField.RADIUS, OwnershipField.THRESHOLD,
		])
	written.append("  who        %s, level %d, carrying a %s, the three wanted things"
		% [WREN, WREN_LEVEL, SWORD] + " and three small gifts")
	written.append("  the rival  %s, level %d, at the post (%.1f, %.1f), carrying six"
		% [ROOK, ROOK_LEVEL, (WHERE + POST).x, (WHERE + POST).y] + " small gifts")
	written.append("  and        %d neighbours, each wanting one thing:" % NEIGHBOURS.size())
	for row in NEIGHBOURS:
		written.append("    %-6s level %d -- wants %s" % [
			row["name"], int(row["level"]), row["wants"],
		])
	written.append("  both runs open the same way: %s gives each neighbour two small"
		% ROOK + " things and returns to the post; %s waits on the green." % WREN)
	written.append("  from tick %d the runs differ in exactly one thing: which written"
		% WREN_FROM)
	written.append("  rule drives %s -- _winning_fights walks to %s and attacks until"
		% [WREN, ROOK] + " the rival")
	written.append("  falls; _winning_hearts hands each neighbour the thing it wanted"
		+ " and one gift.")
	written.append("  each is reproduced by ./run_territory.sh --arm %s | --arm %s"
		% [FIGHT, FRIENDSHIP])
	return written


# --- One run's section ------------------------------------------------------


static func _arm_lines(played: Dictionary) -> PackedStringArray:
	var scene: ActionScene = played["scene"]
	var desk: CheckDesk = played["desk"]
	var deeds: DeedDesk = played["deeds"]
	var written := PackedStringArray()
	written.append("--- the %s run ---" % played["arm"])
	written.append("")
	written.append("what %s did (idle watch-waits elided; the run opens with %d ticks"
		% [WREN, WREN_FROM] + " of them)")
	for line in (played["loop"] as ControlLoop).journal:
		if line.contains(WREN) and not line.contains("wait(ticks=%d)" % WATCH):
			written.append("  %s" % line)
	if not (played["fight"] as PackedStringArray).is_empty():
		written.append("")
		written.append("the fight, turn by turn")
		for line in played["fight"]:
			written.append("  %s" % line)
	written.append("")
	written.append("what the world made of it")
	for line in desk.journal:
		written.append("  %s" % line)
	for line in deeds.journal:
		written.append("  %s" % line)
	if desk.journal.is_empty() and deeds.journal.is_empty():
		written.append("  nothing was raised and nothing closed")
	written.append("  checks     %d raised, %d rolled -- no word is spoken in either run"
		% [desk.seen.size(), desk.rolls])
	written.append("  deeds      %d goals closed and looked at, %d with somebody else"
		% [deeds.seen.size(), deeds.deeds().size()] + " behind them")
	written.append("  calls      %d put to a model, %s earned over %d edges" % [
		desk.calls + deeds.calls, Goodwill.said_as(deeds.earned), deeds.favoured,
	])
	if not (played["replies"] as Array).is_empty():
		written.append("")
		written.append("the replies, and where each came from")
		for row in played["replies"]:
			written.append("  question %s answered \"%s\"" % [
				row["prompt"], row["reply"],
			])
			if String(row.get("note", "")) != "":
				written.append("    %s" % row["note"])
	written.append("")
	written.append("the edges afterwards")
	for line in scene.relationships.lines():
		written.append("  %s" % line)
	written.append("")
	written.append("at the parting, tick %d, fingerprint %s" % [
		int((played["parted"] as Dictionary)["tick"]),
		(played["parted"] as Dictionary)["fingerprint"],
	])
	written.append("after %d ticks" % scene.tick)
	for line in scene.lines():
		written.append("  %s" % line)
	written.append("  fingerprint %s" % scene.fingerprint())
	return written


# --- The one compact table --------------------------------------------------


static func _the_table(played: Dictionary) -> PackedStringArray:
	var fought: Dictionary = played[FIGHT]
	var loved: Dictionary = played[FRIENDSHIP]
	var written := PackedStringArray()
	written.append("--- ownership of the named points, before and after both runs ---")
	written.append("")
	written.append("  as staged, tick 0, every point: no owner and every score 0.0000 --")
	written.append("  nobody has met anybody, and both runs print that world identically.")
	written.append("  'before' is the shared world at the parting tick %d; each run's"
		% WREN_FROM)
	written.append("  survey of it is printed from its own process, so equality is"
		+ " evidence.")
	written.append("")
	written.append("  the parting surveys agree: %s" % (
		"yes" if _surveys_agree(fought["parted"], loved["parted"])
		else "NO -- the runs were not identical when they parted"))
	written.append("")
	written.append("  score is OwnershipField's, in [-1, 1]; owner needs > %.4f."
		% OwnershipField.THRESHOLD)
	written.append("")
	written.append("  %-12s | %-26s | %-26s | %-26s" % [
		"point", "before (both runs)", "after the fight", "after the friendship",
	])
	written.append("  %-12s | %-26s | %-26s | %-26s" % [
		"", "owner  Wren    Rook", "owner  Wren    Rook", "owner  Wren    Rook",
	])
	var before: Array = (fought["parted"] as Dictionary)["points"]
	var after_fight: Array = (fought["ended"] as Dictionary)["points"]
	var after_love: Array = (loved["ended"] as Dictionary)["points"]
	for at in POINTS.size():
		written.append("  %-12s | %s | %s | %s" % [
			String((POINTS[at] as Dictionary)["named"]),
			_cell(before[at], fought["scene"]),
			_cell(after_fight[at], fought["scene"]),
			_cell(after_love[at], loved["scene"]),
		])
	return written


static func _cell(point: Dictionary, scene: ActionScene) -> String:
	return "%-6s %+.4f %+.4f" % [
		_owner_name(int(point["owner"]), scene),
		float(point["wren"]), float(point["rook"]),
	]


# --- The effect, as numbers -------------------------------------------------


static func _the_numbers(played: Dictionary) -> PackedStringArray:
	var fought: Dictionary = played[FIGHT]
	var loved: Dictionary = played[FRIENDSHIP]
	var written := PackedStringArray()
	written.append("--- how the two paths compare, in numbers ---")
	written.append("")
	written.append("  over the %d sampled points (reach %.0f, step %.0f):" % [
		grid().size(), GRID_REACH, GRID_STEP,
	])
	written.append("    %-22s %s" % ["at the parting", _cells_line(
		(fought["parted"] as Dictionary)["cells"], fought["scene"])])
	written.append("    %-22s %s" % ["after the fight", _cells_line(
		(fought["ended"] as Dictionary)["cells"], fought["scene"])])
	written.append("    %-22s %s" % ["after the friendship", _cells_line(
		(loved["ended"] as Dictionary)["cells"], loved["scene"])])
	var fight_moved := _changed_hands(fought)
	var love_moved := _changed_hands(loved)
	written.append("")
	written.append("  ground that changed hands between the parting and the end:")
	written.append("    the fight moved %d points; the friendship moved %d." % [
		fight_moved, love_moved,
	])
	if fight_moved > 0:
		written.append("    that is %.2f points moved by the friendship for every one"
			% (float(love_moved) / float(fight_moved)) + " the fight moved.")
	var rook_held := _held_by(fought, ROOK)
	if fight_moved > rook_held:
		written.append("    the fight moved more ground than the rival himself held"
			+ " (%d): claims" % rook_held)
		written.append("    by others that rested on the fallen one's opinions fell"
			+ " with him.")
	written.append("")
	written.append("  named points that changed owner, parting -> end:")
	written.append("    under the fight:      %s" % _flips(fought))
	written.append("    under the friendship: %s" % _flips(loved))
	var before_green: Dictionary = (fought["parted"] as Dictionary)["points"][0]
	var fight_green: Dictionary = (fought["ended"] as Dictionary)["points"][0]
	var love_green: Dictionary = (loved["ended"] as Dictionary)["points"][0]
	written.append("")
	written.append("  at the green itself: %s's claim went %+.4f -> %+.4f under the"
		% [ROOK, float(before_green["rook"]), float(fight_green["rook"])]
		+ " fight and")
	written.append("  %+.4f -> %+.4f under the friendship; %s's went %+.4f -> %+.4f"
		% [
			float(before_green["rook"]), float(love_green["rook"]), WREN,
			float(before_green["wren"]), float(love_green["wren"]),
		] + " by friendship")
	written.append("  and %+.4f -> %+.4f by fighting." % [
		float(before_green["wren"]), float(fight_green["wren"]),
	])
	written.append("")
	written.append("  the two paths shift ownership differently in kind: the fight"
		+ " vacates --")
	written.append("  everything resting on the fallen rival's goodwill, his claims"
		+ " and his")
	written.append("  opinions alike, goes neutral -- while the friendship captures:"
		+ " ground")
	written.append("  changes owner where the deeds out-earn the incumbent, and stays"
		+ " his where")
	written.append("  his own voice is still the nearest. The named-point flips above"
		+ " are the")
	written.append("  two kinds, point by point.")
	return written


## How many sampled points one name held at the parting, in one run.
static func _held_by(played: Dictionary, who: String) -> int:
	var cells: Dictionary = (played["parted"] as Dictionary)["cells"]
	var scene: ActionScene = played["scene"]
	for id in cells:
		if _owner_name(int(id), scene) == who:
			return int(cells[id])
	return 0


## The named points whose owner differs between the parting and the end of one
## run, each written "point: was -> is", or the plain fact that none did.
static func _flips(played: Dictionary) -> String:
	var scene: ActionScene = played["scene"]
	var before: Array = (played["parted"] as Dictionary)["points"]
	var after: Array = (played["ended"] as Dictionary)["points"]
	var parts := PackedStringArray()
	for at in POINTS.size():
		var was := int((before[at] as Dictionary)["owner"])
		var is_now := int((after[at] as Dictionary)["owner"])
		if was == is_now:
			continue
		parts.append("%s: %s -> %s" % [
			String((POINTS[at] as Dictionary)["named"]),
			_owner_name(was, scene), _owner_name(is_now, scene),
		])
	return "none" if parts.is_empty() else "; ".join(parts)


## How many sampled points answer with a different owner at the end than at the
## parting, in one run. Both owner maps are carried in the surveys, because the
## parting world cannot be re-asked once the run has moved past it.
static func _changed_hands(played: Dictionary) -> int:
	var before: PackedInt32Array = (played["parted"] as Dictionary)["owners"]
	var after: PackedInt32Array = (played["ended"] as Dictionary)["owners"]
	var moved := 0
	for at in mini(before.size(), after.size()):
		if before[at] != after[at]:
			moved += 1
	return moved


# --- What this run does not isolate -----------------------------------------


static func _not_isolated() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("--- what this comparison does not isolate, named plainly ---")
	written.append("")
	written.append("  * the rival does not fight back. %s is unarmed by scenario"
		% ROOK)
	written.append("    choice, so 'winning the fight' is measured with no risk to the"
		+ " winner;")
	written.append("    a fight against resistance costs health this run never charges.")
	written.append("  * the judged amounts replay the goodwill run's recording by"
		+ " position;")
	written.append("    the prompts differ from the recorded ones in tick stamps and"
		+ " cast ids,")
	written.append("    and every reply says so above. A live model could judge"
		+ " differently.")
	written.append("  * effort is equalised against the incumbent, not between the"
		+ " paths: six")
	written.append("    exchanges answer six exchanges, while the fight spends one walk"
		+ " and a")
	written.append("    few blows. The paths differ in cost as well as in kind, and this")
	written.append("    run measures effect, not price.")
	written.append("  * section 6's battle path is 'raising your level, removing rival"
		+ " owners';")
	written.append("    only the removing is exercised. No rule raises a level on a"
		+ " kill yet,")
	written.append("    so the level half of that sentence is not in this measurement.")
	written.append("  * the incumbent's claim is built by the same trade machinery the")
	written.append("    friendship uses, so 'before' is not independent of the hearts"
		+ " path;")
	written.append("    it is the engine's only way to make anybody own anything.")
	return written


# --- The furniture ---------------------------------------------------------


static func _cells_line(cells: Dictionary, scene: ActionScene) -> String:
	if cells.is_empty():
		return "nobody holds any of it"
	var parts := PackedStringArray()
	for id in cells:
		parts.append("%s holds %d" % [_owner_name(int(id), scene), int(cells[id])])
	return ", ".join(parts)


static func _owner_name(id: int, scene: ActionScene) -> String:
	if id == OwnershipField.NOBODY:
		return "nobody"
	var one := scene.actor_of(id)
	var sheet := _sheet(one)
	if sheet != null:
		return sheet.character_name
	# The fallen are out of the cast; the staged order still names them.
	if id == 1:
		return WREN
	if id >= 2 and id <= 1 + NEIGHBOURS.size():
		return String(NEIGHBOURS[id - 2]["name"])
	if id == 2 + NEIGHBOURS.size():
		return ROOK
	return "#%d" % id


static func _surveys_agree(one: Dictionary, other: Dictionary) -> bool:
	return String(one.get("fingerprint", "?")) == String(other.get("fingerprint", "!"))


static func _carries(pack: Inventory, called: String) -> bool:
	for item in pack.items():
		if item != null and item.item_name == called:
			return true
	return false


static func _offer_pending(scene: ActionScene, from_id: int, to_id: int) -> bool:
	for offer in scene.offers:
		if int(offer["from"]) == from_id and int(offer["to"]) == to_id:
			return true
	return false


static func _wearable(called: String) -> Item:
	return Item.armour(
		called, Item.SLOT_HELMET, 1, ItemRarity.COMMON, Ability.DEX,
		[1, 1, 0] as Array[int])


static func _trinket(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX,
		[0, 0, 1] as Array[int])


static func _id_of(scene: ActionScene, who: String) -> int:
	var one := _named(scene, who)
	return OwnershipClaim.NOBODY if one == null else one.id


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
