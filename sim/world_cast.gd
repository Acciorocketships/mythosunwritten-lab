extends RefCounted
## Who is in an ordinary world, and what they do with themselves.
##
## Every world has people in it. This is the three of them the world stands up
## when nothing else has been asked for -- the ordinary cast, as opposed to the
## cast a named scenario sets out -- and the one rule that drives them.
##
## ## Nothing here is privileged, including the one the camera watches
##
## All three are `Character`s on one sheet, added to the world's own roster,
## serviced by the world's own `ControlLoop`, and reached only through
## `ActionEngine.resolve`. `SimWorld.follow_id` names one of them, and being
## named by it is the *whole* of what that character gets: it is asked the same
## question on the same tick as the other two, its answer goes to the same
## engine, and the world would keep turning identically if the camera were
## pointed somewhere else. What follows from being followed is that the terrain
## streams around it, which is a fact about the streamer and not about the
## character.
##
## ## One band, on purpose
##
## The engagement rule pits commanders of *different* bands against each other
## (`ActionScene.ENGAGE_RADIUS`), so three wanderers of three bands would fall
## into a fight the moment two of them drifted together, and an ordinary world
## would be a brawl. They are one band -- meadow folk, who know each other --
## because who fights whom in the open world is the next question and not this
## one. Enemies arrive with their own bands when something spawns them.
##
## ## The rule: walk a leg, then choose another
##
## `wandering()` is a `DecisionSource.scripted` rule like any other. It returns
## one `Action.go_to` at a time, to a position one leg away along a heading that
## turns a little at each leg. Two things make it safe under `ControlLoop`, which
## asks again every `ControlLoop.REVIEW_EVERY` ticks while a walk is running:
##
##   * the leg is keyed to `ActionScene.actions_of` -- the world's own count of
##     what it has actually carried out for that character -- so being *asked*
##     never advances it, and the same destination comes back until the walk is
##     resolved. The loop reads that as "wanted the same thing" and the walk runs
##     on;
##   * the turn is hashed from the seed, the character and the leg number rather
##     than drawn off a stream, so what one character does cannot depend on how
##     often anybody else has been asked. That is the discipline `ControlLoop`
##     already keeps with its own one number.
##
## A leg that the world refuses -- walked into water, blocked by a cliff -- still
## counts as an action carried out, so the next question is asked with a new
## heading and the walker turns away from what stopped it.
##
## ## And when somebody swings at them, they swing back
##
## A wanderer caught in a fight has one useful answer and the walk is not it: a
## `go_to` from somebody on a board is refused, so a character that kept choosing
## one would spend every turn of its own fight on a refusal. So the rule opens
## with the same branch `EnemyMind` opens with -- strike at whoever of another
## band is on the board with you -- reached through the same engine call. That is
## the whole of what "the meadow folk defend themselves" amounts to; there is no
## tactic in it and none is claimed.
class_name WorldCast

## How far one leg of a wander covers, in world units.
##
## Chosen against `ActionCatalog`'s own cost of a `go_to`, which is 20 ticks:
## eighteen units over twenty ticks is 0.9 units a tick, which is exactly the
## rate the placeholder observer used to walk at. So the ordinary world moves
## across the ground at the speed it always did -- the difference is that it now
## moves because somebody chose to walk, and the streaming figures a run reports
## stay comparable with every run taken before this one.
const LEG := 18.0

## The most a wanderer's heading turns between one leg and the next, in radians.
## Small, so a walk goes somewhere rather than milling about: the old observer
## turned by up to 0.06 radians on each of the twenty ticks a leg now takes.
const TURN := 0.25

## How far a wanderer turns instead when the last leg got it nowhere -- it walked
## at water, or at a cliff, and the world refused. Anywhere in the back half,
## hashed like every other turn.
##
## A quarter of a radian cannot get out of a cul-de-sac: a character standing on
## a river bank aims across the water, is refused, turns a fraction and aims
## across it again, and stands there for the whole run. A fixed about-face would
## oscillate against the same wall instead, so the turn is drawn across the half
## of the circle that faces away from whatever stopped it.
const BLOCKED_TURN_LOW := PI * 0.5
const BLOCKED_TURN_HIGH := PI * 1.5

## How near a leg's destination counts as having got there. `ActionEngine`'s own
## arrival distance for a bare position, read from it rather than typed again, so
## "the walk was refused" here means what "the walk arrived" means there.
const ARRIVED := ActionEngine.ARRIVE

## What the turns are hashed from, together with the character and the leg. The
## turn is the only number this rule draws at all.
const WANDER_SEED := 0x57414c4b

## How long somebody with nothing useful to do on a board waits before looking
## again, in ticks. Short, because a turn spent waiting is a turn.
const WATCHFUL := 2

## Who is in an ordinary world: a name, a level, what they look like, where they
## start relative to the world origin, and which way they set off.
##
## The first of them is the one the world follows. They start a few units apart
## so that three characters are visibly three characters in the first frame.
const CAST := [
	{
		"name": "Pip", "level": 1, "tag": AssetTags.RANGER,
		"at": Vector2(0.0, 0.0), "looking": 0.0,
	},
	{
		"name": "Nettle", "level": 1, "tag": AssetTags.MAGE,
		"at": Vector2(-7.0, 4.0), "looking": PI * 0.75,
	},
	{
		"name": "Corin", "level": 1, "tag": AssetTags.ROGUE,
		"at": Vector2(6.0, -5.0), "looking": PI * 1.4,
	},
]

## How far out to look for ground a character can be stood on, and how far apart
## to look, both in world units.
##
## The spots in `CAST` are written relative to the world origin, and the origin of
## a seed is whatever the fields make of it -- at seed 19 it is the middle of a
## river. A character put down in water is refused every walk it ever chooses,
## whichever way it faces, so it stands there for the whole run and the world it
## is the view on never moves. The search is a fixed lattice of rings, so two
## processes put the same character in the same place.
const LANDING_REACH := 60.0
const LANDING_STEP := 3.0

## The six ability scores everybody in the ordinary cast is rolled at.
##
## One roll shared by all three, for the reason the scenario's cast shares one:
## nothing in an ordinary world is checked against anybody else, and all six are
## written down rather than the two that are read, because an unrecorded score is
## not a zero and a character walking about the world should carry a whole sheet.
const ROLL := {
	Ability.STR: 3,
	Ability.CON: 3,
	Ability.CHA: 3,
	Ability.DEX: 3,
	Ability.WIS: 3,
	Ability.INT: 3,
}


## Stand the ordinary cast up in a world and hand back the id of the one the
## world follows, or 0 if there was nobody to stand up.
##
## Everybody is added to the world's own roster -- which is the world's own
## action scene -- so they are stepped by `SimWorld.step` like anything else in
## it. Nothing here starts a fight, holds a rule of one, or knows there is such a
## thing.
static func muster(world: SimWorld) -> int:
	var first := 0
	for row in CAST:
		var stands := _standable_near(world.terrain, row["at"] as Vector2)
		var one := world.combat.add(Combatant.commander_at(
			stands.x, stands.y,
			float(row["looking"]), 0.0,
			int(row["level"]), String(row["tag"])))
		# One band for all of them: the first stood up is the band the rest join,
		# exactly as a scenario's sides are made.
		one.band = first if first > 0 else one.id
		var sheet := Character.make(String(row["name"]), int(row["level"]))
		sheet.record_scores(ROLL)
		# What they carry and what they have on. Forged by the frontier at their
		# own level, exactly as an enemy's is, and put on by the one call that
		# dresses anybody: somebody who lives in a world with enemies in it and
		# has nothing to hold is not a character, it is food.
		sheet.inventory.carry_all(ItemFrontier.carried_at_level(
			world.world_seed, "cast/%s" % String(row["name"]), int(row["level"])))
		sheet.inventory.dress()
		sheet.decide = wandering(world.world_seed)
		(one.piece as Commander).adopt(sheet)
		one.settle(world.terrain)
		if first == 0:
			first = one.id
	return first


## The rule the ordinary cast is driven by: walk a leg, then choose another.
##
## One `Callable` per character, because the leg it is part-way through is that
## character's own. Everything the rule reads is the world it is handed and the
## character it is choosing for; everything it draws is hashed from the seed, the
## character and the leg.
static func wandering(seed_value: int) -> Callable:
	# Where this character is in its wander: which leg it is on, which way it is
	# facing, and where the leg is going. Kept beside the rule rather than on the
	# sheet, because it is how this rule happens to work and not something the
	# world needs to know about a character.
	var walking := {"leg": -1, "heading": 0.0, "to": Vector2.ZERO}
	return DecisionSource.scripted(
		func(scene: ActionScene, actor: Combatant) -> Action:
			if scene == null or actor == null:
				return null
			if scene.is_fighting(actor):
				# On a board, a walk is refused -- the board decides where a
				# fighter goes -- and a character that answered with one anyway
				# would spend its turn on a refusal. So it strikes at whoever of
				# another band is on the board with it, which is the same branch
				# `EnemyMind` opens with and reaches the engine the same way.
				var mark := scene.nearest_of_another_band(actor)
				var strikes := ActionScene.inventory_of(actor).weapon_name()
				if mark == null or strikes == "":
					return Action.wait(WATCHFUL)
				return Action.attack(mark.id, strikes)
			var leg := scene.actions_of(actor.id)
			if int(walking["leg"]) != leg:
				# A new leg: turn, and set off from wherever the last one left
				# us. Asked again part-way through, none of this runs and the
				# same destination comes back.
				#
				# How far to turn is read off the world rather than reported by
				# it: a leg that ended somewhere other than where it was aimed
				# was refused -- the water, or a cliff -- so the next one aims
				# away instead of a fraction to one side.
				var here := Vector2(actor.x, actor.z)
				var blocked := leg > 0 and here.distance_to(
					walking["to"] as Vector2) > ARRIVED
				walking["leg"] = leg
				walking["heading"] = _turned(
					float(walking["heading"]) if leg > 0 else actor.heading,
					seed_value, actor.id, leg, blocked)
				var heading := float(walking["heading"])
				walking["to"] = Vector2(actor.x, actor.z) + Vector2(
					cos(heading), sin(heading)) * LEG
			var to: Vector2 = walking["to"]
			return Action.go_to(to)
	)


## Hand a character in a world over to whoever is driving, and give back the
## place their choices go.
##
## This is the whole of what it takes for one of the cast to be a person's. Its
## decision function is replaced -- `DecisionSource.live` in place of whatever
## was there -- and nothing else about it changes: the same sheet, the same
## roll, the same band, the same place in the same roster, serviced by the same
## `ControlLoop` on the same tick as everybody else, and reached only through
## `ActionEngine.resolve`. Section 1's "no preferential treatment" principle is
## the one line of this function.
##
## What comes back is the `LiveChoice` the new decision function reads. Whoever
## is driving writes an `Action` into it and the character does that next; on
## every tick they have not, the character waits in the world and everybody else
## carries on. Null comes back when the world has nobody with that id, which is
## what asking to drive a character that is not there should say.
static func hand_over(world: SimWorld, id: int) -> LiveChoice:
	if world == null or world.combat == null:
		return null
	var one := world.combat.member_of(id)
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	var sheet := (one.piece as Commander).sheet
	if sheet == null:
		return null
	var choice := LiveChoice.new()
	sheet.decide = DecisionSource.live(choice)
	return choice


## The nearest position to a written-down spot that a character can actually be
## stood on, or the spot itself if there is nothing standable within
## `LANDING_REACH`.
##
## Rings outward at a fixed spacing, with the same number of samples on a ring
## whichever process asks, so where a character ends up is a function of the seed
## and of nothing else. Nothing here is seeded-random: it is a search over the
## ground, and the ground is a pure function of the position.
static func _standable_near(terrain: TerrainQuery, at: Vector2) -> Vector2:
	if terrain == null or terrain.is_passable_at(at.x, at.y):
		return at
	var rings := int(LANDING_REACH / LANDING_STEP)
	for ring in range(1, rings + 1):
		var radius := float(ring) * LANDING_STEP
		var around := ring * 8
		for step in around:
			var angle := float(step) * TAU / float(around)
			var here := at + Vector2(cos(angle), sin(angle)) * radius
			if terrain.is_passable_at(here.x, here.y):
				return here
	return at


## A heading turned by up to `TURN` either way, or into the back half when the
## last leg was refused. Hashed from the seed, the character and the leg rather
## than drawn off a stream, so what one character does cannot depend on how often
## anybody else has been asked.
static func _turned(
	heading: float, seed_value: int, id: int, leg: int, blocked: bool
) -> float:
	var drawn := SimRng.hash_unit(seed_value + WANDER_SEED, id, leg)
	if blocked:
		return fposmod(
			heading + BLOCKED_TURN_LOW + drawn * (BLOCKED_TURN_HIGH - BLOCKED_TURN_LOW),
			TAU)
	return fposmod(heading + (drawn * 2.0 - 1.0) * TURN, TAU)
