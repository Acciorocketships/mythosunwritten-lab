extends RefCounted
## A second scenario on the atomic action surface: a patrol of two and one
## stranger who walks into them, and the fight that follows.
##
##     ./run_skirmish.sh
##
## This run exists to prove one thing about the code rather than one thing about
## the world: **a scene built on the atomic action surface reaches a fight without
## writing down a single rule of one.** Everything about who fights, how near
## counts as near, how fast a fight runs and where in a tick it happens is
## `ActionScene.fight_step()`'s, and this file's whole share of it is the one line
## that calls it.
##
## `sim/scripted_scenario.gd` -- the five-character run -- used to hold a copy of
## those four rules, because there was nowhere else for them to be. Had that copy
## still been there, this file would have needed a second one. Instead the two
## scenarios and the world's own `CombatantRoster` all reach the same cycle
## through the same call, and the fight this run holds is the fight the world
## would have held.
##
## ## Why a patrol and not another duel
##
## Three commanders in two bands, not two in two, so the run exercises the parts
## of the pairing rule a duel cannot show:
##
##   * the pair is chosen **in id order** -- Ash and Fen are the watch and are one
##     band, so the first pair the rule can accept is Ash and the stranger, and
##     the board is anchored on Ash;
##   * **a band is not a side of the board** -- Fen never triggers anything, but
##     is inside `Encounter.JOIN_RADIUS` of the anchor and so joins the fight it
##     did not start, two against one.
##
## Nothing here decides any of that. The run sets three characters down, gives
## each a decision function, and calls the same two things every tick.
class_name ScriptedSkirmish

## The seed and the ground: the same measured open meadow every other walkthrough
## is played on, so this run invents no coordinate and makes no new claim about
## the world.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE

## The seed the control loop's continue-bias draws are hashed from.
const LOOP_SEED := ScriptedLoop.LOOP_SEED

## How many ticks the run lives for: long enough for the stranger to arrive, for
## the fight to run out, and for the quiet afterwards to be on the record.
##
## It used to be 80, when the board's own stand-in chooser swung for everybody
## and the fight was decided in a few ticks. Now that a commander's own choice is
## its turn's weapon action, two things changed: a turn lasts as long as the blow
## it spends, and the watch will not strike a band-mate -- so once the stranger
## falls, the two who are left stand facing each other until `Encounter`'s round
## limit calls it. That ending is on the record rather than worked around: it is
## the first scripted run to reach the limit the fight layer has always carried.
const TICKS := 140

## Who is in it.
const ASH := "Ash"
const FEN := "Fen"
const CORVID := "Corvid"

## Which side each is on. Ash and Fen share a band, so the engagement rule --
## commanders of *different* bands -- never pits them against each other.
const WATCH := "watch"
const STRANGER := "stranger"

## What the two shapes of weapon in this run are called once forged. Forged, not
## taken bare off the catalogue: a bare shape reads the catalogue's own damage,
## which no power budget paid for, and `Weapon.held` names what it forges after
## the rarity and the shape.
const SPEAR := "common spear"
const SWORD := "common sword"

## The cast, as one table: a name, a side, a level, an appearance tag, a position
## as an offset from `WHERE` in world units, and what it strikes with.
##
## Ash and Fen stand a few units apart, well inside `Encounter.JOIN_RADIUS` of
## each other. Corvid starts east of both, outside `ActionScene.ENGAGE_RADIUS` of
## either, and walks in.
const CAST := [
	{
		"name": ASH, "side": WATCH, "level": 3,
		"tag": AssetTags.KNIGHT, "at": Vector2(0.0, 0.0), "strikes": SPEAR,
	},
	{
		"name": FEN, "side": WATCH, "level": 3,
		"tag": AssetTags.RANGER, "at": Vector2(-4.0, 3.0), "strikes": SWORD,
	},
	{
		"name": CORVID, "side": STRANGER, "level": 4,
		"tag": AssetTags.BARBARIAN, "at": Vector2(34.0, 2.0), "strikes": SWORD,
	},
]

## What everybody's ability scores are. One roll for all three: nothing in this
## run turns on a score differing between them, and an unrecorded score is not a
## zero.
const DEXTERITY := 4
const STRENGTH := 5

## How long somebody standing watch waits before looking up again, and how long
## somebody with nothing left to watch for rests.
const WATCHFUL := 4
const REST := 30


# --- The world the run is played in ---------------------------------------


## Set the scene out: three characters on the meadow, in `CAST` order, which is
## the order they are given ids in and the order the transcript reads them by.
static func stage(seed_value: int = SEED) -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(seed_value))
	var bands := {}
	for row in CAST:
		var one := scene.add_actor(Combatant.commander_at(
			WHERE.x + row["at"].x, WHERE.y + row["at"].y,
			0.0, 0.0, row["level"], row["tag"]))
		# Everybody on one side is one band. `ActionScene.add_actor` makes each
		# commander its own band; a side is what this scenario has to say on top
		# of that, and the first of a side is the band the rest of it joins.
		if bands.has(row["side"]):
			one.band = int(bands[row["side"]])
		else:
			bands[row["side"]] = one.id
		var sheet := Character.make(row["name"], int(row["level"]))
		sheet.record_scores({Ability.DEX: DEXTERITY, Ability.STR: STRENGTH})
		var chief := one.piece as Commander
		chief.adopt(sheet)
		one.piece.equip(Armour.boots())
		# Forged at the character's own level, never taken bare off the
		# catalogue: a bare shape reads the catalogue's own damage, which no
		# power budget paid for.
		if row["name"] == ASH:
			chief.wield(Weapon.held(Weapon.spear(), int(row["level"])))
		else:
			chief.wield(Weapon.held(Weapon.sword(), int(row["level"])))
	return scene


## Put a decision function on every sheet. Three rules, no person: the human path
## is the five-character run's business and is proved there.
static func drive(scene: ActionScene) -> void:
	_sheet(_named(scene, ASH)).decide = DecisionSource.scripted(_holding_ground(ASH))
	_sheet(_named(scene, FEN)).decide = DecisionSource.scripted(_holding_ground(FEN))
	_sheet(_named(scene, CORVID)).decide = DecisionSource.scripted(_walking_in(CORVID))


# --- The three rules ------------------------------------------------------


## Standing watch: strike at whoever of another band is on the board with you,
## otherwise look up again in a few ticks. It never goes anywhere.
static func _holding_ground(who: String) -> Callable:
	return func(scene: ActionScene, actor: Combatant) -> Action:
		if scene.is_fighting(actor):
			var mark := _nearest_of_another_band(scene, actor)
			if mark != null:
				return Action.attack(mark.id, _strikes(who))
		return Action.wait(WATCHFUL)


## Walking in: go to the nearer of the watch until the board is under you, then
## strike at whoever of another band is on it. Once there is nobody of another
## band left, rest.
static func _walking_in(who: String) -> Callable:
	return func(scene: ActionScene, actor: Combatant) -> Action:
		var mark := _nearest_of_another_band(scene, actor)
		if mark == null:
			return Action.wait(REST)
		if scene.is_fighting(actor):
			return Action.attack(mark.id, _strikes(who))
		if actor.distance_to(mark) > ActionEngine.REACH:
			return Action.go_to(mark.id)
		return Action.wait(WATCHFUL)


# The nearest living commander of another band, by distance and then by id so
# that a tie is broken the same way in every process, or null.
static func _nearest_of_another_band(scene: ActionScene, actor: Combatant) -> Combatant:
	var found: Combatant = null
	var nearest := 0.0
	for one in scene.actors:
		if one == actor or not one.is_commander() or not one.is_alive():
			continue
		if one.band == actor.band:
			continue
		var gap := actor.distance_to(one)
		if found == null or gap < nearest:
			found = one
			nearest = gap
	return found


# --- Living the run -------------------------------------------------------


## Play the whole run and hand back the transcript.
##
## Two calls per tick, and the order of them is the ordering every driver keeps:
## the characters are serviced, and then whichever fight is on takes its turn. So
## a fight that begins on one tick is noticed as an interruption on the next.
##
## The second call is the whole of what this file knows about fighting. There is
## no radius here, no pairing loop, no cadence and no conclusion: `fight_step()`
## holds all four, once, and the world's own roster calls exactly the same thing.
static func play(ticks: int = TICKS, seed_value: int = SEED) -> PackedStringArray:
	var scene := stage(seed_value)
	var loop := ControlLoop.on(scene, LOOP_SEED)
	drive(scene)

	var written := PackedStringArray()
	written.append("skirmish seed=%d ticks=%d where=(%.1f, %.1f) engage=%.1f join=%.1f" % [
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
	written.append("after %d ticks" % scene.tick)
	written.append_array(_indent(scene.lines()))
	written.append("  fights begun=%d ended=%d boards=%d" % [
		scene.fights_begun, scene.fights_ended, scene.board_version,
	])
	written.append("  fingerprint %s" % scene.fingerprint())
	release(scene)
	return written


# One tick of whichever fight is on, or of the one that is about to begin.
#
# `ActionScene.fight_step()` is the whole of it; the two lines around it are this
# run's own transcript and say nothing about a rule.
static func _fight_step(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	var turn := scene.fight_step()
	if turn["began"] != null:
		written.append(_moment(scene, "%s meets somebody of another band" % (
			ActionScene.name_of(turn["began"]))))
	written.append_array(_indent(turn["lines"]))
	if turn["ended"]:
		written.append(_moment(scene, "the fight is over; real time again"))
		written.append_array(_indent(turn["over"]))
	return written


## Take the decision functions back off the sheets when a run is over, cutting
## the ring that otherwise keeps the scene, the sheets and the rules alive after
## nobody wants any of them.
static func release(scene: ActionScene) -> void:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null:
			sheet.decide = Callable()


# --- Reading the run ------------------------------------------------------


## One line per character: who they are, what side they are on, and what they are
## worth.
static func cast_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	for row in CAST:
		var one := _named(scene, String(row["name"]))
		if one == null:
			continue
		written.append("%-7s #%d %-9s band=%d %s" % [
			row["name"], one.id, row["side"], one.band, _sheet(one).sheet_line(),
		])
	return written


static func _strikes(who: String) -> String:
	for row in CAST:
		if row["name"] == who:
			return String(row["strikes"])
	return ""


# The character with a name, or null once it has fallen out of the world.
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


# A line in the journal's own shape, for the two moments the loop cannot see.
static func _moment(scene: ActionScene, what: String) -> String:
	return "t=%3d  --     %s" % [scene.tick, what]


static func _indent(lines: PackedStringArray) -> PackedStringArray:
	var written := PackedStringArray()
	for line in lines:
		written.append("    " + line)
	return written
