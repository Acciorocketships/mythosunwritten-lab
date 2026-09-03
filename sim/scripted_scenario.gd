extends RefCounted
## Five characters living one seeded run, written down: a market, a trade, a
## quarrel that snaps onto the tactical board, and real time again afterwards.
##
##     ./run_scenario.sh
##
## This is the end-to-end proof of the character layer, and it is a *scenario*
## rather than a mechanic. Nothing here resolves anything. The cast is a table of
## constants; every choice any of them makes is an `Action`; what each call does
## is `ActionEngine`'s answer; when it happens is `ControlLoop`'s; and what a
## blow does is the combat layer's. Two processes therefore print the same bytes,
## which is the same division `sim/scripted_actions.gd` keeps with the action
## surface and `sim/scripted_encounter.gd` keeps with the fight.
##
## ## Nobody in it is privileged
##
## All five are `Character`s on one sheet, in one scene, reached only through
## `ActionEngine.resolve`. The single difference between them is the `Callable`
## on `Character.decide`:
##
##   * **Wren** is driven by a recorded list of choices written down in advance
##     -- what a person's turns look like once they have been taken, and the only
##     shape a person can take in a headless run, because a screen is not a thing
##     a simulation can have. The human path is therefore *exercised by this run*
##     rather than asserted about somewhere. The list is handed over by
##     `DecisionSource.plan`, which reads it at the index of how many turns have
##     actually been carried out; `DecisionSource.recorded`, the queue-shaped
##     reading of the same list, cannot be used under a loop that asks more than
##     once, because being asked spends an entry.
##   * **Rook**, **Bram**, **Sable** and **Odo** are driven by
##     `DecisionSource.scripted` -- rules that read the world they are handed.
##
## Neither the loop nor the engine can tell which is which, and this file is the
## only one that knows, because it is the one that put them on the sheets.
##
## ## What the run exercises, in the order it happens
##
##   * **speech** -- Wren greets Rook by name, which interrupts Rook mid-wait
##     (section 2.2's "dialogue opens"), and Rook answers.
##   * **movement** -- Wren walks to the stall and back to Rook; Odo walks away
##     from everything and stays away.
##   * **a pick-up** -- Wren takes the lantern off the stall's pile.
##   * **a trade that moves both items and money** -- Wren offers coins for
##     Rook's cloak, Rook accepts, and the cloak and the coins change hands in
##     one exchange. Wren then examines the cloak it now carries.
##   * **a fight** -- Bram and Sable close on each other, the board appears under
##     them, the match is played out, and the survivors are handed back to real
##     time. The market is outside `Encounter.JOIN_RADIUS` and carries on trading
##     throughout; Odo is further out still.
##   * **real time again** -- Wren, who never left it, shouts after the noise.
##
## ## The fight is called, not re-implemented
##
## This file holds no rule of a fight and no copy of one. Every tick it services
## its characters through `ControlLoop` and then calls `ActionScene.fight_step()`
## once, which is where who fights, how near counts as near, the one-turn-per-tick
## cadence and the ordering inside the tick all live -- the same call the world's
## own `CombatantRoster` makes after its combatants have walked.
##
## An earlier version of this file wrote all four out by hand, because nothing
## under `sim/` drove a fight for a scene built on the atomic action surface.
## What is left of that here is one thing that is genuinely the scenario's: the
## two who trade are put in *one band*, because the engagement rule pits
## commanders of different bands against each other and the world knows nothing
## about intent, so a band is the only way to say "these two are not enemies".
##
## See reports/scenario.md for the two things this run found that the code cannot
## yet do -- a recorded list drained by being asked, and an atomic blow that costs
## more ticks than a fight leaves between blows -- both reported rather than
## worked around in `sim/`.
class_name ScriptedScenario

## The seed the scenario is written for, and the ground it is played on: the same
## measured open meadow the action walkthrough and the control-loop walkthrough
## use, so no new coordinate is invented here and no new claim is made about the
## world.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE

## The seed the control loop's continue-bias draws are hashed from. The bias is
## the only thing in the loop that draws a number at all.
const LOOP_SEED := ScriptedLoop.LOOP_SEED

## How many ticks the run lives for. Long enough for the market, the quarrel and
## the quiet afterwards.
##
## It used to be 110, and grew when a commander's chosen blow started landing: a
## turn now lasts as long as the weapon action it spends, so a fight of the same
## eight turns takes about seven ticks a turn instead of one. The fight is the
## same fight -- four rounds, one survivor -- lived at the rate the characters
## in it actually act.
const TICKS := 160

## Who is in it. One name each, used to put them in the world, to find them again
## from a decision function, and to read the transcript.
const WREN := "Wren"
const ROOK := "Rook"
const BRAM := "Bram"
const SABLE := "Sable"
const ODO := "Odo"

## Which side each is on. Two characters sharing a side share a `Combatant.band`,
## and the engagement rule only pits commanders of *different* bands against each
## other -- so Wren and Rook can stand at arm's length to trade without the world
## reading it as a meeting of enemies.
const MARKET := "market"
const GREEN := "green"
const AMBER := "amber"
const ALONE := "alone"

## The cast, as one table. Every projection of it -- the scene the run is played
## on, and the standing the render shell is handed for a frame -- is read off
## this and not typed a second time.
##
## `at` is an offset from `WHERE` in world units. The market stands at the
## meeting place itself; the quarrel is far enough east that the whole of it is
## outside `Encounter.JOIN_RADIUS` of the market, so the traders cannot be pulled
## into a fight they are not in; Odo is further out again, along z.
const CAST := [
	{
		"name": WREN, "side": MARKET, "level": 2,
		"tag": AssetTags.MAGE, "at": Vector2(-6.0, -4.0),
	},
	{
		"name": ROOK, "side": MARKET, "level": 2,
		"tag": AssetTags.ROGUE, "at": Vector2(2.0, -4.0),
	},
	{
		"name": BRAM, "side": GREEN, "level": 3,
		"tag": AssetTags.KNIGHT, "at": Vector2(44.0, -13.0),
	},
	{
		"name": SABLE, "side": AMBER, "level": 3,
		"tag": AssetTags.BARBARIAN, "at": Vector2(56.0, -13.0),
	},
	{
		"name": ODO, "side": ALONE, "level": 1,
		"tag": AssetTags.RANGER, "at": Vector2(-4.0, 52.0),
	},
]

## What the ability scores of everybody in the cast are: all six of them, one
## roll shared by all five characters.
##
## The same roll for everybody, because nothing in this run turns on a score
## being different between them -- nobody here is checked against anybody else --
## and all six are written down rather than two, because an unrecorded score is
## not a zero and a character who walks out of this run into the world should
## carry the whole sheet rather than four dashes.
##
## Only two of the six are read by anything in the run: STR gates the two forged
## weapons and DEX gates the boots, the cloak and the lantern. Both are at or
## above the level of every item anybody here carries, so the gate reads each
## item in full -- exactly as an unrecorded score did -- and no number of the
## fight moves. CON, CHA, WIS and INT govern nothing that is in this scene.
const ROLL := {
	Ability.STR: 5,
	Ability.CON: 4,
	Ability.CHA: 3,
	Ability.DEX: 4,
	Ability.WIS: 3,
	Ability.INT: 2,
}

## Where the stall's pile lies, as an offset from `WHERE`, and what is on it.
const STALL_AT := Vector2(9.0, -4.0)
const LANTERN := "brass lantern"

## What Rook has to sell, what Wren pays for it, and what the two start with.
const CLOAK := "silk cloak"
const CLOAK_PRICE := 12
const WREN_MONEY := 30
const ROOK_MONEY := 8

## What the two quarrelling characters strike with, once their weapons are forged
## at their own level. Forged, not taken bare off the catalogue: a bare shape
## reads the catalogue's own damage, which no power budget paid for.
const BRAM_STRIKES := "common sword"
const SABLE_STRIKES := "common spear"

## The tick the quarrel starts on. Before it, Bram and Sable stand where they
## were put; from it they close on each other. It is late enough that the trade
## is done and early enough that Wren is still in the world to hear it.
const QUARREL_FROM := 55

## How long anybody with something to watch for waits before looking up again.
## Short, so that a character minding a stall notices an offer within a few ticks
## of its being made.
const WATCH := 4

## How long somebody with nothing left to watch for waits: a bystander who has
## arrived, and the survivor of a quarrel that is over.
const REST := 30

## How long Wren waits for an answer to the offer, and how long it lingers
## afterwards before speaking again.
const WREN_WAITS := 8
const WREN_LINGERS := 24

## Where Odo walks to, as an offset from `WHERE`: further out along z, away from
## everything. It never comes back and never joins anything.
const ODO_WALKS_TO := Vector2(-4.0, 94.0)

## Which tick each rendered frame is taken at. A frame is a picture of this run
## at a stated tick and nothing else: `muster()` plays the run to the tick and
## stands the cast where the run left them.
const MARKET_FRAME := 66
const QUARREL_FRAME := 80


# --- The world the run is played in ---------------------------------------


## Set the scene out: five characters on the meadow, and a stall with a lantern
## on it.
##
## The order things are added in is the order they are given ids in, and the
## transcript is read by id, so it is fixed here and nowhere else: the cast in
## `CAST` order, then the stall.
static func stage() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var bands := {}
	for row in CAST:
		var one := scene.add_actor(Combatant.commander_at(
			WHERE.x + row["at"].x, WHERE.y + row["at"].y,
			0.0, 0.0, row["level"], row["tag"]))
		# Everybody on one side is one band. `ActionScene.add_actor` makes each
		# commander its own band as the roster does; sides are what this scenario
		# has to say on top of that, and the first of a side is the band the rest
		# of it joins.
		if bands.has(row["side"]):
			one.band = int(bands[row["side"]])
		else:
			bands[row["side"]] = one.id
		var sheet := Character.make(row["name"], row["level"])
		sheet.record_scores(ROLL)
		(one.piece as Commander).adopt(sheet)

	var wren := _named(scene, WREN)
	ActionScene.inventory_of(wren).gain(WREN_MONEY)

	var rook := _named(scene, ROOK)
	ActionScene.inventory_of(rook).carry(_wearable(CLOAK, Item.SLOT_CHESTPLATE))
	ActionScene.inventory_of(rook).gain(ROOK_MONEY)

	var bram := _named(scene, BRAM)
	bram.piece.equip(Armour.boots())
	(bram.piece as Commander).wield(Weapon.held(Weapon.sword(), _level_of(BRAM)))

	var sable := _named(scene, SABLE)
	sable.piece.equip(Armour.boots())
	(sable.piece as Commander).wield(Weapon.held(Weapon.spear(), _level_of(SABLE)))

	scene.add_object(WorldObject.loose(
		WHERE.x + STALL_AT.x, WHERE.y + STALL_AT.y,
		Inventory.ground([_tool(LANTERN)])))
	return scene


## Put a decision function on every character's sheet. The one difference
## between them, and the whole of it.
##
## The person among the five is driven by `DecisionSource.plan`, which reads how
## far its character has got out of the world itself, so nothing here has to be
## handed whatever is stepping the scene.
static func drive(scene: ActionScene) -> void:
	var wren := _named(scene, WREN)
	var rook := _named(scene, ROOK)
	_sheet(wren).decide = DecisionSource.plan(wren_choices(scene))
	_sheet(rook).decide = DecisionSource.scripted(ScriptedScenario._minding_the_stall)
	_sheet(_named(scene, BRAM)).decide = DecisionSource.scripted(
		_quarrel_with(SABLE, BRAM_STRIKES))
	_sheet(_named(scene, SABLE)).decide = DecisionSource.scripted(
		_quarrel_with(BRAM, SABLE_STRIKES))
	_sheet(_named(scene, ODO)).decide = DecisionSource.scripted(
		ScriptedScenario._walking_away)


# --- The one person in it -------------------------------------------------


## Wren's turns, written down in advance, in the order they were taken.
##
## This is a person's half of the run and it is a *list*, because that is what a
## person's choices are once made. `DecisionSource.plan` is what hands them over
## one at a time -- at the index of how many the character has actually had
## carried out, so that being asked again mid-walk offers the walk back rather
## than spending the next turn on the question. From the loop's side the result is
## a `Callable` like any other and there is nothing to tell it apart from a rule.
##
## Nothing in the list asks whether a choice will work. Two of them are answered
## by the world rather than by the list -- the trade needs Rook to accept, and
## the examine needs the cloak to have actually arrived -- and that is the point:
## a person chooses, and the engine answers.
static func wren_choices(scene: ActionScene) -> Array:
	var rook := _named(scene, ROOK)
	var stall := scene.objects[0]
	return [
		Action.say("good morning", rook.id),
		Action.go_to(stall.id),
		Action.pick_up(LANTERN),
		Action.go_to(rook.id),
		Action.trade_propose(
			rook.id, PackedStringArray(), CLOAK_PRICE,
			PackedStringArray([CLOAK]), 0),
		Action.wait(WREN_WAITS),
		Action.examine(CLOAK),
		Action.say("a fair bargain"),
		Action.wait(WREN_LINGERS),
		Action.say("what was that noise?"),
	]


# --- The four rules -------------------------------------------------------


## Rook minds the stall: answer whoever spoke to you, take whatever is offered,
## otherwise look up again in a few ticks.
##
## It reads the world it is handed -- the offers on the table, what has been said
## -- and nothing else, and it never asks whether it may: that is the engine's
## answer and a second one would be a second rule.
static func _minding_the_stall(scene: ActionScene, actor: Combatant) -> Action:
	for offer in scene.offers:
		if offer["to"] == actor.id:
			return Action.trade_accept(offer["from"])
	var owed := _who_is_owed_an_answer(scene, actor.id)
	if owed != ActionCatalog.NOBODY:
		return Action.say("what will it be?", owed)
	return Action.wait(WATCH)


## The quarrel: stand about until the appointed tick, then close on the other
## one, and once the board is under you strike at them with what you carry.
##
## The attack is chosen through the same atomic surface everything else goes
## through, and like everything else it may be refused -- a turn is a thing the
## board grants, not a thing a choice can take. What comes of it is in the
## transcript either way.
static func _quarrel_with(other_name: String, strikes_with: String) -> Callable:
	return func(scene: ActionScene, actor: Combatant) -> Action:
		var other := _named(scene, other_name)
		if other == null:
			return Action.wait(REST)
		if scene.is_fighting(actor):
			return Action.attack(other.id, strikes_with)
		if scene.tick < QUARREL_FROM:
			return Action.wait(WATCH)
		if actor.distance_to(other) > ActionEngine.REACH:
			return Action.go_to(other.id)
		return Action.wait(WATCH)


## Odo walks away from everything, and once it has arrived it stays there. The
## locality witness: it is never inside `Encounter.JOIN_RADIUS` of the quarrel,
## and the transcript says where it ended up.
static func _walking_away(_scene: ActionScene, actor: Combatant) -> Action:
	var to := WHERE + ODO_WALKS_TO
	if Vector2(actor.x, actor.z).distance_to(to) > ActionEngine.ARRIVE:
		return Action.go_to(to)
	return Action.wait(REST)


# --- Living the run -------------------------------------------------------


## Play the whole run and hand back the transcript.
##
## One tick at a time: the control loop services everybody, and then the fight
## -- whichever one is on, or the one that is about to begin -- takes its turn.
## That is the order `SimWorld.step` puts the two in, and it is why a fight that
## begins on one tick is noticed as an interruption on the next.
static func play(ticks: int = TICKS, seed_value: int = SEED) -> PackedStringArray:
	var scene := stage_for(seed_value)
	var loop := ControlLoop.on(scene, LOOP_SEED)
	drive(scene)

	var written := PackedStringArray()
	written.append("scenario seed=%d ticks=%d where=(%.1f, %.1f) engage=%.1f join=%.1f" % [
		seed_value, ticks, WHERE.x, WHERE.y,
		ActionScene.ENGAGE_RADIUS, Encounter.JOIN_RADIUS,
	])
	written.append_array(_indent(cast_lines(scene)))
	written.append_array(_indent(scene.lines()))
	written.append("")

	var said := 0
	for _step in maxi(0, ticks):
		loop.step()
		for at in range(said, loop.journal.size()):
			written.append(loop.journal[at])
		said = loop.journal.size()
		written.append_array(_fight_step(scene))

	written.append("")
	written.append_array(relationship_lines(scene))
	written.append("")
	written.append("after %d ticks" % scene.tick)
	written.append_array(_indent(scene.lines()))
	written.append("  " + _counts_line(loop))
	written.append("  fingerprint %s" % scene.fingerprint())
	release(scene)
	return written


## What the world recorded between these five, out of what they actually did to
## each other.
##
## The market is where a trade is *honoured*, so this is where the trust and
## respect an exchange moves can be read as numbers rather than described: the
## two who traded carry them and the three who only spoke do not. Every edge here
## was folded in by `CharacterUpkeep`, on the path all five pass, out of the
## engine's own record of what happened -- see `sim/relationship_graph.gd` for
## which happening moves which field.
static func relationship_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	var graph := scene.relationships
	written.append("what the world recorded between them (%d edge%s, %d happening%s)"
		% [
			graph.size(), "" if graph.size() == 1 else "s",
			graph.happenings(), "" if graph.happenings() == 1 else "s",
		])
	written.append("  sentiment is familiarity x (trust - fear), the one number"
		+ " section 6 reads")
	for one in scene.actors:
		for edge in graph.edges_of(one.id):
			written.append("  " + edge.line_toward(one.id))
	for line in graph.lines():
		written.append("    " + line)
	return written


## The scene the run is played on, for a stated seed.
static func stage_for(seed_value: int) -> ActionScene:
	if seed_value == SEED:
		return stage()
	var scene := stage()
	scene.terrain = TerrainQuery.for_seed(seed_value)
	for one in scene.actors:
		one.settle(scene.terrain)
	for thing in scene.objects:
		thing.settle(scene.terrain)
	return scene


## Play the run to a tick and hand back the scene, so a picture of it can be
## taken. Nothing is different about the run: it is the same call `play` makes,
## stopped early.
##
## `watching` is handed the scene at the end of every tick, and is how something
## that wants to see the run go past rather than only its end gets a look --
## `ScriptedObservation` keeps its trail of what changed that way. It decides
## nothing and is given no way to: a watcher that writes into the scene is
## writing into the run, and no watcher in this project does.
static func played_to(
	at_tick: int, seed_value: int = SEED, watching: Callable = Callable()
) -> ActionScene:
	var scene := stage_for(seed_value)
	var loop := ControlLoop.on(scene, LOOP_SEED)
	drive(scene)
	for _step in maxi(0, at_tick):
		loop.step()
		_fight_step(scene)
		if watching.is_valid():
			watching.call(scene)
	release(scene)
	return scene


# One tick of whichever fight is on, or of the one that is about to begin.
#
# `ActionScene.fight_step()` is the whole of it. What this function adds is two
# sentences of transcript that are the scenario's own -- the moment two people
# met, and the moment it was over -- written in the journal's shape and placed
# around what the fight itself wrote.
static func _fight_step(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	var turn := scene.fight_step()
	if turn["began"] != null:
		written.append(_moment(scene, "%s and somebody of another band have met" % (
			ActionScene.name_of(turn["began"]))))
	written.append_array(_indent(turn["lines"]))
	if turn["ended"]:
		written.append(_moment(scene, "the fight is over; real time again"))
		written.append_array(_indent(turn["over"]))
	return written


# --- A frame of it --------------------------------------------------------


## Stand the cast in a world at the position this run had them at a stated tick,
## so the render shell can take a picture of it.
##
## The picture is of the run: the scenario is played headless on the same seed to
## `at_tick`, and whoever is still standing is put into the world's roster where
## the run left them, carrying the sheet the run played them with -- name, six
## ability scores, level, status, the health it was left on, its money, what it
## carries and what it has on -- and their own appearance tag. Nobody walks --
## the roster is handed people who have already arrived -- and the observer is
## stood where it can see them.
##
## Returns how many of the cast were placed.
static func muster(world: SimWorld, at_tick: int, watch_from: Vector2) -> int:
	var scene := played_to(at_tick, world.world_seed)
	var bands := {}
	var placed := 0
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet == null:
			continue
		var stood := world.combat.add(Combatant.commander_at(
			one.x, one.z, one.heading, 0.0, sheet.level, one.piece.appearance))
		var side := _side_of(sheet.character_name)
		if bands.has(side):
			stood.band = int(bands[side])
		else:
			bands[side] = stood.id
		# The sheet itself, and not a new one wearing its name. `adopt` takes a
		# character that already exists, so what stands in the world *is* the
		# character the run played: its name, its six scores, its level, its
		# status, the health the run left it on, the money in its purse, what it
		# picked up and bought, and what it has on. Nothing is copied across
		# here, so there is nothing that can be copied wrongly.
		#
		# This used to hand over `Character.make(name, level)` -- a fresh sheet
		# with the same two numbers on it -- and put a pair of boots on the
		# commander first, which the adoption then threw away along with
		# everything else the run had given it. The boots are gone with it: a
		# character arrives wearing what the run had it wearing, and this file
		# has no business inventing gear the run never gave anybody.
		(stood.piece as Commander).adopt(sheet)
		stood.settle(world.terrain)
		placed += 1
	world.place_observer(watch_from.x, watch_from.y)
	world.observer_walks = false
	return placed


## Where the camera stands for the market frame and for the quarrel frame: beside
## the cast, so a camera following the observer is pointed at them.
static func watch_market() -> Vector2:
	return WHERE + Vector2(6.5, -1.5)


static func watch_quarrel() -> Vector2:
	return WHERE + Vector2(49.0, -6.5)


## Take the decision functions back off the sheets when a run is over.
##
## Housekeeping. A finished run has no further use for deciding, and a scene that
## outlives it should not still be able to act. Everything a report or a test
## reads off a finished run -- positions, inventories, the fingerprint -- is still
## there afterwards; only the deciding is gone.
##
## It used to have a sharper reason: a person's list was read against the loop
## that drove it, so the loop held the scene, the scene held the sheet, the sheet
## held the list and the list held the loop, and that ring kept all four alive
## after nobody wanted any of them. `DecisionSource.plan` reads how far a
## character has got out of the world instead of out of the loop, so there is no
## ring left to cut.
static func release(scene: ActionScene) -> void:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null:
			sheet.decide = Callable()


# --- Reading the run ------------------------------------------------------


## One line per character: who they are, what drives them, what side they are on
## and what they are worth. The transcript's answer to "none of them is
## privileged" -- five rows of one shape, differing in one column.
static func cast_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	for row in CAST:
		var one := _named(scene, row["name"])
		if one == null:
			continue
		written.append("%-6s #%d %-8s driven by %-8s %s" % [
			row["name"], one.id, row["side"], _driver_of(row["name"]),
			_sheet(one).sheet_line(),
		])
	return written


# Which sort of decision function a character was given. Said here, in the file
# that gave it to them, and nowhere else: no other file in the run can tell, and
# there is nothing anywhere else to tell it by.
static func _driver_of(who: String) -> String:
	return "a person" if who == WREN else "a rule"


static func _side_of(who: String) -> String:
	for row in CAST:
		if row["name"] == who:
			return row["side"]
	return ALONE


static func _level_of(who: String) -> int:
	for row in CAST:
		if row["name"] == who:
			return int(row["level"])
	return 1


# The character with a name, or null once it has fallen out of the world.
static func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == who:
			return one
	return null


# Who spoke to a character and has not been answered since, or `NOBODY`.
static func _who_is_owed_an_answer(scene: ActionScene, id: int) -> int:
	var owed := ActionCatalog.NOBODY
	for spoken in scene.said:
		if spoken["to"] == id:
			owed = int(spoken["speaker"])
		elif spoken["speaker"] == id:
			owed = ActionCatalog.NOBODY
	return owed


static func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


# A hand-held item at level 1, forged exactly as the other walkthroughs forge
# one: everything it is worth goes to its effects axis.
static func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


# A worn item at level 2, half defence and half movement.
static func _wearable(called: String, slot: String) -> Item:
	return Item.armour(
		called, slot, 2, ItemRarity.COMMON, Ability.DEX, [1, 1, 0] as Array[int])


# A line in the journal's own shape, for the two moments the loop cannot see:
# the fight beginning and the fight ending.
static func _moment(scene: ActionScene, what: String) -> String:
	return "t=%3d  --     %s" % [scene.tick, what]


# What the loop counted, in one line.
static func _counts_line(loop: ControlLoop) -> String:
	var counts := loop.counts()
	var written := PackedStringArray()
	for key in counts:
		written.append("%s=%s" % [key, counts[key]])
	return " ".join(written)


static func _indent(lines: PackedStringArray) -> PackedStringArray:
	var written := PackedStringArray()
	for line in lines:
		written.append("    " + line)
	return written
