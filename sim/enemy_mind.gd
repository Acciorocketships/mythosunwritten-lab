extends RefCounted
## What an enemy does with itself: notice somebody, walk over, swing.
##
## This is a decision function and nothing else. It is built by
## `DecisionSource.scripted` like the ordinary cast's wander rule, it has the
## signature every decision function in the project has --
##
##     func(scene: ActionScene, actor: Combatant) -> Action
##
## -- and everything it returns is one of `Action`'s own constructors, handed to
## `ActionEngine.resolve` by whatever is driving. **There is nothing here a
## driver could tell apart from the rest of the cast.** An enemy is not a special
## kind of thing in this simulation; it is a character whose sheet has this
## `Callable` on it instead of the wander rule, in the same roster, serviced by
## the same `ControlLoop`, refused by the same engine in the same sentences.
## Section 1's "no preferential treatment" is not weakened by there being a
## hostile in the world: it is what makes one possible without a second code
## path.
##
## ## The rule, in four lines
##
##   1. **On a board** -- swing at the nearest character of another band. The
##      loop only asks on this character's own turn (`ControlLoop._may_choose`),
##      so a blow chosen here is a blow spent out of its own turn, exactly as a
##      person's is. Everything else about the turn -- closing, facing, sending a
##      minion -- is `CombatPolicy`'s, in the running game.
##   2. **Somebody of another band within `STRIKE`** -- attack them. In real time
##      that blow is what *starts* the fight: see `ActionEngine._attack`, which
##      snaps the board in around the attacker. A fight in this world therefore
##      begins because a character chose to begin one.
##   3. **Somebody of another band within `HOLD`** -- watch them: a short `wait`,
##      taken again and again, until they are close enough to strike.
##   4. **Somebody of another band within `NOTICE`** -- walk to `STANDOFF` of
##      them. One `Action.go_to` at a position, which is the same action a
##      person's `P` key sends.
##   5. **Nobody worth noticing** -- wander, on the ordinary cast's own rule.
##      An enemy with nothing to hunt is a character walking about the world.
##
## ## Why the bands sit where they do
##
## `ActionScene.fight_step()` also starts a fight when two commanders of
## different bands drift within `ActionScene.ENGAGE_RADIUS` of each other, and
## that rule is untouched -- two people walking into one another is a meeting and
## the world is entitled to say so. The bands here are chosen so that a hunter
## that has *decided* to attack gets its blow in first, because that is the
## interesting case and the one worth being able to read in a trace: it stops
## walking at `HOLD`, watches in two-tick beats, and swings at `STRIKE`, which is
## far enough outside the engagement radius that six ticks of the mark walking
## straight at it still cannot close the gap before the blow lands, and far
## enough inside `Encounter.JOIN_RADIUS` that six ticks of the mark walking away
## still leaves it on the board the blow calls up.
##
## What is deliberately not claimed: that a fight can no longer start by two
## people meeting. Somebody who walks head-on into an enemy over a whole approach
## still meets it, and that is what meeting means.
class_name EnemyMind

## How far off an enemy picks somebody out, in world units. Well past a walk's
## leg, so an enemy notices before it has to be walked into.
const NOTICE := 40.0

## How near it stops walking and starts watching, in world units. Between this
## and `NOTICE` it closes; inside it, it holds still and looks again every
## `WATCHFUL` ticks until the mark is close enough to strike.
##
## Holding rather than walking is what makes the blow the opener. A walk is a
## twenty-tick commitment (`ActionCatalog`'s cost of a `go_to`) and section 2.2's
## control loop is biased towards continuing one, so a hunter still walking when
## its mark came into range would keep walking until the two of them were close
## enough for `ActionScene.fight_step`'s engagement rule to start the fight
## underneath it. Standing still costs two ticks at a time, so it can act on what
## it sees.
const HOLD := 21.0

## How near it gets before it swings, in world units.
##
## Chosen against the two radii on either side of it, and the six ticks an attack
## takes to carry out. A mark walks at most `ActionEngine.STEP` a tick, so over
## those six ticks the gap can change by at most 5.4 units while the striker
## stands still: from 18 that is at worst 23.4 when the blow lands, which is
## inside `Encounter.JOIN_RADIUS` and so still a fight the mark is on the board
## for, and at best 12.6, which is outside `ActionScene.ENGAGE_RADIUS` and so
## still a fight nothing else has started first.
const STRIKE := 18.0

## Where an approach is aimed, in world units from the mark. Inside `HOLD`, so an
## approach that arrives is one that has arrived at watching distance.
const STANDOFF := 20.0

## How long an enemy waits before looking up again, in ticks. Short, because the
## whole point of holding rather than walking is to be able to act on what it
## sees.
const WATCHFUL := 2


## The decision function an enemy is given when it is stood up.
##
## `wander` is what it falls back to with nobody in sight -- one `Callable` per
## character, because the leg it is part-way through is that character's own.
## `EnemyStreamer` hands it `WorldCast.wandering(seed)`, which is the rule the
## ordinary cast walks by: an enemy with nothing to hunt walks the world exactly
## as anybody else does.
static func hunting(wander: Callable) -> Callable:
	# Where the approach is aimed, and which leg of this character's own history
	# it was aimed on. Kept beside the rule for the reason `WorldCast.wandering`
	# keeps its leg beside its own: the destination has to hold still while the
	# walk runs, or every review would propose a slightly different point and the
	# walk would be a decision the character keeps re-taking instead of a journey.
	var closing := {"leg": -1, "to": Vector2.ZERO}
	return DecisionSource.scripted(
		func(scene: ActionScene, actor: Combatant) -> Action:
			if scene == null or actor == null:
				return null
			var mark := scene.nearest_of_another_band(actor)
			var strikes := strikes_with(actor)
			if scene.is_fighting(actor):
				if mark == null or strikes == "":
					return Action.wait(WATCHFUL)
				return Action.attack(mark.id, strikes)
			if mark == null or actor.distance_to(mark) > NOTICE:
				if wander.is_valid():
					var next: Variant = wander.call(scene, actor)
					if next is Action:
						return next
				return Action.wait(WATCHFUL)
			var gap := actor.distance_to(mark)
			if gap <= STRIKE and strikes != "":
				return Action.attack(mark.id, strikes)
			if gap <= HOLD:
				# Near enough to watch, not near enough to swing. It holds.
				return Action.wait(WATCHFUL)
			var leg := scene.actions_of(actor.id)
			if int(closing["leg"]) != leg:
				closing["leg"] = leg
				closing["to"] = standoff_between(actor, mark)
			return Action.go_to(closing["to"] as Vector2)
	)


## Where an enemy walks to when it has picked somebody out: not onto them, but
## `STANDOFF` short of where they are standing.
##
## Walking *to* a character arrives at `ActionEngine.REACH` of them, which is
## well inside `ActionScene.ENGAGE_RADIUS` -- so a hunter that walked all the way
## in would have the fight begin under it because the two of them ended a tick
## close together, and the blow it meant to strike would never be the reason. It
## stops at arm's length instead and swings from there.
static func standoff_between(actor: Combatant, mark: Combatant) -> Vector2:
	var here := Vector2(actor.x, actor.z)
	var there := Vector2(mark.x, mark.z)
	var away := here - there
	if away.length() < 0.0001:
		return here
	return there + away.normalized() * STANDOFF


## What a character strikes with: `Inventory.weapon_name`, which every mind in
## the project asks and which lives there rather than here for the reason
## `ActionScene.nearest_of_another_band` lives there -- two minds asking it two
## ways would be two answers to one question. Kept as a name on this class so the
## rule above reads as one rule rather than as a rule with a lookup in it.
static func strikes_with(actor: Combatant) -> String:
	var pack := ActionScene.inventory_of(actor)
	return "" if pack == null else pack.weapon_name()
