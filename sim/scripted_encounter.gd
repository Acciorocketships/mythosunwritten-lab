extends RefCounted
## The whole cycle, written down: real time, the snap onto the board, a match
## played to its end, the snap back off, and real time again.
##
## Nothing here decides anything about the fight. It puts a fixed set of
## combatants at fixed world positions with fixed headings, stands the observer
## somewhere it can watch, and steps the world. The combatants walk in straight
## lines because a heading is a number this file set; they meet because those
## numbers point them at each other; the fight begins because
## `ActionScene.ENGAGE_RADIUS` says so; and every move in it is
## `CombatPolicy`'s. There is no policy, no search and no language model here.
##
## It is also the determinism witness for this layer, the way
## `sim/scripted_match.gd` is for the layer below. The seed is a constant, the
## positions are constants, and no layer under it reads a clock, a random number
## or an address -- so the transcript is a pure function of this file and the
## world's fields, and two processes must print the same bytes.
##
##     ./run_encounter.sh
##
## ## The three bands
##
## | band | where it starts | what it is |
## |---|---|---|
## | green | `WHERE` minus `APPROACH` along x, walking east | Alder, a level-2 commander with a sword and boots, a Cat and a Toadstool |
## | amber | `WHERE` plus `APPROACH` along x, walking west | Ember, a level-2 commander with a spear and boots, an Ent and a Frog |
## | distant | `WHERE` plus `BYSTANDER_AWAY` along z, walking away | Wisp, a level-1 commander with a dagger, and a Toadstool |
##
## Every one of those weapons is *forged* -- `Weapon.held(shape, BAND_LEVEL)` --
## and not a catalogue shape handed over bare. A bare shape reads the
## catalogue's own damage numbers, which no power budget paid for and which no
## ability score can gate; forging one at the band's own level is what puts this
## scenario, and so every screenshot and transcript of a fight in this project,
## on the budget section 4 describes. It costs the demo most of its damage --
## a level-2 common sword is worth 8 points where the shape reads 26 -- and that
## is the point: the numbers are now what the level is entitled to.
##
## The distant band is the locality check, and it is a band rather than a lone
## walker on purpose: it has a commander of its own, so nothing but the radius is
## keeping it out of the fight. It starts far enough away that it is outside
## `Encounter.JOIN_RADIUS` of the meeting, it walks further away throughout, and
## when the fight is over it is exactly where walking for that many ticks put it.
class_name ScriptedEncounter

## The seed the scenario is written for.
const SEED := 1234

## Where the two bands meet, in world units.
##
## Chosen by measurement rather than by taste. `./run_headless.sh --snap` scores
## 289 candidate places over the world on three stated numbers -- how much of the
## board can be stood on, how much height there is between its highest and lowest
## standable cell, and how much the scatter layer grew there -- and 25 of them
## pass. This is the one of those 25 with a real shoreline on the board: an open
## meadow with a lake along one edge, so the fight is held on ground that has
## something to say. See reports/combat-snap.md.
const WHERE := Vector2(-480.0, 420.0)

## How far either side of `WHERE` the two bands start, in world units. Far enough
## that the two are outside `ActionScene.ENGAGE_RADIUS` for a good many ticks
## of real time before anything snaps.
const APPROACH := 14.0

## How far the third band stands from the meeting, along z. Comfortably outside
## `Encounter.JOIN_RADIUS`, and it walks further out from there.
const BYSTANDER_AWAY := 70.0

## What each band's commander is called.
##
## A commander with no name is a character with a blank at the top of its sheet,
## and everything that reads a character out of the world afterwards -- a report,
## a failure message, the interface -- has nothing to call it by. Three names,
## one per band, echoing the band each stands for.
const GREEN_NAME := "Alder"
const AMBER_NAME := "Ember"
const DISTANT_NAME := "Wisp"

## What the ability scores of every commander here are: all six of them, one roll
## shared by all three.
##
## The same roll for everybody, because nothing in this scenario turns on a score
## being different between them -- the two who fight are meant to be evenly
## matched -- and all six are written down rather than none, because an
## unrecorded score is not a zero and a character standing in the world should
## carry the whole sheet.
##
## Only two of the six are read by anything here: STR gates the three forged
## weapons and DEX gates the boots. Both are above `BAND_LEVEL`, which is the
## level of every item in the scenario, so the gate reads each item in full --
## exactly as an unrecorded score did -- and not one number of the fight moves.
## CON, CHA, WIS and INT govern nothing anybody here carries.
const ROLL := {
	Ability.STR: 5,
	Ability.CON: 4,
	Ability.CHA: 3,
	Ability.DEX: 4,
	Ability.WIS: 3,
	Ability.INT: 2,
}

## What level the two fighting bands are, and what level the distant one is.
##
## Named rather than written five times over, because a band's level is now two
## things at once: how much health and defence its commander and minions have,
## and -- since every weapon here is forged rather than taken bare off the
## catalogue -- how large the power budget behind its commander's weapon is. One
## constant is what keeps those from drifting apart.
const BAND_LEVEL := 2
const BYSTANDER_LEVEL := 1

## World units a combatant covers in one tick. Slower than the observer, so the
## approach takes tens of ticks and the world is unmistakably running in real
## time before anything snaps.
const WALK := 0.6

## Which way each band walks: east, west, and away.
const EAST := 0.0
const WEST := PI
const AWAY := PI * 0.5

## How many ticks the scenario runs for. Long enough to walk in, fight to a
## conclusion and walk on afterwards.
const TICKS := 60

## Where the observer stands to watch. Beside the meeting, standing still, so a
## camera following it stays pointed at the fight. It takes no part in anything.
const WATCH_FROM := Vector2(-2.0, -1.0)

## How far either side of a floating island's centre the two bands start, in
## world units, for the aerial version of the scenario.
##
## Much shorter than `APPROACH`, because an island's top is tens of units across
## and two bands twenty-two units apart would start off the edge of it. They meet
## after a handful of ticks instead of thirty.
const ISLAND_APPROACH := 7.0

## How far out from the world origin the aerial scenario looks for an island to
## fight on. The island is chosen by the world, not by a coordinate typed here,
## so the scenario keeps working when the seed changes.
const ISLAND_SPAN := 400.0


## Put the scenario's combatants into a world and stand the observer where it
## can watch. Nothing steps; the caller does that.
static func muster(world: SimWorld) -> void:
	world.place_observer(WHERE.x + WATCH_FROM.x, WHERE.y + WATCH_FROM.y)
	world.observer_walks = false
	var roster := world.combat

	var green := roster.add(Combatant.commander_at(
		WHERE.x - APPROACH, WHERE.y, EAST, WALK, BAND_LEVEL, AssetTags.KNIGHT))
	green.piece.equip(Armour.boots())
	_as_character(green, GREEN_NAME).wield(Weapon.held(Weapon.sword(), BAND_LEVEL))
	roster.add(Combatant.minion_at(
		Minion.CAT, green.id,
		WHERE.x - APPROACH - 4.0, WHERE.y - 5.0, EAST, WALK, BAND_LEVEL))
	roster.add(Combatant.minion_at(
		Minion.TOADSTOOL, green.id,
		WHERE.x - APPROACH - 4.0, WHERE.y + 5.0, EAST, WALK, BAND_LEVEL))

	var amber := roster.add(Combatant.commander_at(
		WHERE.x + APPROACH, WHERE.y, WEST, WALK, BAND_LEVEL, AssetTags.BARBARIAN))
	amber.piece.equip(Armour.boots())
	_as_character(amber, AMBER_NAME).wield(Weapon.held(Weapon.spear(), BAND_LEVEL))
	roster.add(Combatant.minion_at(
		Minion.ENT, amber.id,
		WHERE.x + APPROACH + 4.0, WHERE.y - 5.0, WEST, WALK, BAND_LEVEL))
	roster.add(Combatant.minion_at(
		Minion.FROG, amber.id,
		WHERE.x + APPROACH + 4.0, WHERE.y + 5.0, WEST, WALK, BAND_LEVEL))

	var distant := roster.add(Combatant.commander_at(
		WHERE.x, WHERE.y + BYSTANDER_AWAY, AWAY, WALK, BYSTANDER_LEVEL, AssetTags.MAGE))
	distant.piece.equip(Armour.boots())
	_as_character(distant, DISTANT_NAME).wield(
		Weapon.held(Weapon.dagger(), BYSTANDER_LEVEL))
	roster.add(Combatant.minion_at(
		Minion.TOADSTOOL, distant.id,
		WHERE.x + 4.0, WHERE.y + BYSTANDER_AWAY, AWAY, WALK, BYSTANDER_LEVEL))

	# Put everyone down on the surface they are standing over, so that nobody
	# starts the scenario floating at height zero.
	for one in roster.members:
		one.settle(world.terrain)


## Put a smaller version of the same scenario on a floating island's top.
##
## Two bands, no bystander -- an island's top is not wide enough for one to stand
## outside the join radius, and locality is already answered on the ground. What
## this exists to answer is the other question: a fight that starts up here has
## to use *this storey's* board, and nothing in `Encounter` tests for islands to
## make that happen. It hands the board layer a position and the height the
## combatants were put down at, and the storey follows.
##
## Returns the island it chose, or null if the seed has no walkable island within
## `ISLAND_SPAN` of the origin -- in which case there is nothing to test and the
## caller says so rather than pretending.
static func muster_on_island(world: SimWorld) -> FloatingIsland:
	var island := world.island_field.first_walkable_island(ISLAND_SPAN)
	if island == null:
		return null
	var middle_x := island.centre_x
	var middle_z := island.centre_z
	world.place_observer(middle_x, middle_z + WATCH_FROM.y)
	world.observer_walks = false
	var roster := world.combat

	var green := roster.add(Combatant.commander_at(
		middle_x - ISLAND_APPROACH, middle_z, EAST, WALK, BAND_LEVEL, AssetTags.KNIGHT))
	green.piece.equip(Armour.boots())
	_as_character(green, GREEN_NAME).wield(Weapon.held(Weapon.sword(), BAND_LEVEL))
	roster.add(Combatant.minion_at(
		Minion.CAT, green.id,
		middle_x - ISLAND_APPROACH, middle_z - 4.0, EAST, WALK, BAND_LEVEL))

	var amber := roster.add(Combatant.commander_at(
		middle_x + ISLAND_APPROACH, middle_z, WEST, WALK, BAND_LEVEL, AssetTags.BARBARIAN))
	amber.piece.equip(Armour.boots())
	_as_character(amber, AMBER_NAME).wield(Weapon.held(Weapon.spear(), BAND_LEVEL))
	roster.add(Combatant.minion_at(
		Minion.FROG, amber.id,
		middle_x + ISLAND_APPROACH, middle_z - 4.0, WEST, WALK, BAND_LEVEL))

	# Put everyone down on the top surface over their position, which is the
	# island's, so the height they carry names the island's storey.
	for one in roster.members:
		one.y = world.terrain.surface_height_at(one.x, one.z)
		one.settle(world.terrain)
	return island


# The character behind a commander this scenario stood up: named, and with its
# six ability scores rolled.
#
# Both are on the sheet the commander was made with, so there is nothing to
# adopt and nothing to copy -- `Combatant.commander_at` reaches `Commander.make`,
# which starts a `Character`, and this writes the two things that file has no way
# to know. It hands the commander back so the caller can go straight on to arming
# it, which is what every call site does.
static func _as_character(one: Combatant, called: String) -> Commander:
	var commander := one.piece as Commander
	commander.sheet.character_name = called
	commander.sheet.record_scores(ROLL)
	return commander


## Run the whole cycle and hand back the transcript.
##
## One line per tick, in one shape, whether or not a fight is on: the tick
## number, what the roster is doing, how much of the world is loaded, and the
## world's fingerprint. Whatever the fight wrote that tick follows, indented.
## That interleaving is the evidence for "the world keeps stepping while a fight
## is in progress" -- the chunk count and the fingerprint are on every line,
## including the ones inside the fight.
static func play(
	ticks: int = TICKS, seed_value: int = SEED, on_an_island: bool = false
) -> PackedStringArray:
	var world := SimWorld.new(seed_value)
	var where := WHERE
	if on_an_island:
		var island := muster_on_island(world)
		if island == null:
			return PackedStringArray([
				"encounter seed=%d no walkable island within %.0f of the origin"
				% [seed_value, ISLAND_SPAN],
			])
		where = Vector2(island.centre_x, island.centre_z)
	else:
		muster(world)
	var written := PackedStringArray()
	written.append("encounter seed=%d ticks=%d where=(%.1f, %.1f) engage=%.1f join=%.1f%s" % [
		seed_value, ticks, where.x, where.y,
		ActionScene.ENGAGE_RADIUS, Encounter.JOIN_RADIUS,
		" island" if on_an_island else "",
	])
	for one in world.combat.members:
		written.append("  " + one.line())
	written.append(tick_line(world))
	for _step in ticks:
		var said_before := world.combat_lines.size()
		world.step()
		written.append(tick_line(world))
		for at in range(said_before, world.combat_lines.size()):
			written.append("    " + world.combat_lines[at])
	written.append("done ticks=%d begun=%d ended=%d standing=%d final=%s" % [
		world.tick, world.combat.fights_begun, world.combat.fights_ended,
		world.combat.size(), world.digest(),
	])
	for one in world.combat.members:
		written.append("  " + one.line())
	return written


## One line for one tick of the world, in the same shape whether a fight is on
## or not.
static func tick_line(world: SimWorld) -> String:
	var roster := world.combat
	return "tick %d %s chunks=%d islands=%d props=%d begun=%d ended=%d standing=%d %s" % [
		world.tick, roster.phase(),
		world.terrain_streamer.loaded_count(),
		world.island_streamer.loaded_count(),
		world.scatter_streamer.item_count(),
		roster.fights_begun, roster.fights_ended, roster.size(),
		world.digest(),
	]
