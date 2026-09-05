extends RefCounted
## A `go_to` under way: where it is headed, how far it has got, and the one
## function in the project that carries a character toward somewhere.
##
## A walk is the one action whose effect is a *journey* rather than an instant.
## Everything else the catalogue lists happens at a point -- a blow lands, a word
## is said, an item changes hands -- so the span `ControlLoop` charges for it is
## time spent getting ready, and the world changes once at the end. A walk is not
## like that: eighteen units covered over twenty ticks is eighteen units of
## walking, and a character that stood still for nineteen ticks and arrived on
## the twentieth did not walk, it teleported. This is the object that lets the
## journey be lived through rather than jumped: the loop advances it one stride
## per tick while the span runs, and `ActionEngine._go_to` finishes whatever is
## left when the span runs out.
##
## ## One stride, in one place
##
## `stride()` is the whole of the movement. `ActionEngine._go_to` holds no step
## arithmetic of its own -- it aims a walk and then calls `stride()` until it
## stops returning true -- and neither does `ControlLoop`, which calls it once
## per tick. So a walk taken in installments and a walk taken all at once are the
## same walk taken in the same order, which is the whole of why spreading it
## changes where nobody ends up.
##
## The one other thing in the world that advances a character across the ground
## is `Combatant.walk`, which is a *drift* along a heading somebody set and knows
## nothing about a destination. The two are told apart mechanically rather than
## by reading: both add to a combatant's `x` and `z`, and everything else in the
## project that touches those two fields *sets* them, because putting somebody
## down somewhere is not moving them there. `tests/test_walk_motion.gd` scans
## every file in the project for the difference.
##
## ## Nothing here decides anything
##
## Where the walk is headed is worked out once, by `ActionEngine`, from the
## chosen action and where the character stood when it committed. This holds the
## answer and does not recompute it: a walk aimed at a place goes to that place,
## and a character that wants to go somewhere else says so through its decision
## function, which is an interruption and not a course correction.
class_name Walk

## Where it is headed, in world units.
var to := Vector2.ZERO

## How near it has to get to have arrived: `ActionEngine.ARRIVE` for a bare
## position, `ActionEngine.REACH` for a thing, because standing on somebody is
## not arriving at them.
var arrive := 0.0

## What it is walking to, in the words a refusal is phrased in.
var what := ""

## The action this walk belongs to, as `Action.line()`. A walk is kept between
## ticks under the character's id, so this is what says whether the walk found
## there is the one the character is actually doing.
var of_action := ""

## Why the destination could not be read at all, or "". A walk that was never
## aimed takes no strides and reports this when it is resolved.
var refusal := ""

## How far it has actually covered and how many strides that took. What the
## outcome reports, accumulated across every tick the walk was advanced on.
var walked := 0.0
var steps := 0

## Why it stopped short, if it did: ground nothing can stand on, or more strides
## than one action is allowed.
var blocked := false
var blocked_at := Vector2.ZERO
var overrun := false


## A walk aimed at a place.
static func toward(
	destination: Vector2, within: float, called: String, action_line: String
) -> Walk:
	var leg := Walk.new()
	leg.to = destination
	leg.arrive = within
	leg.what = called
	leg.of_action = action_line
	return leg


## A walk that cannot be taken, because there is nothing to aim it at.
static func refused(why: String, action_line: String) -> Walk:
	var leg := Walk.new()
	leg.refusal = why
	leg.of_action = action_line
	return leg


## Whether the walk has stopped for good, one way or another.
func is_over() -> bool:
	return blocked or overrun or refusal != ""


## Whether the character is near enough to have arrived.
func has_arrived(actor: Combatant) -> bool:
	return actor.distance_from(to.x, to.y) <= arrive


## Take one stride toward the destination, and say whether one was taken.
##
## The one place a character is carried toward somewhere. It settles onto
## whatever is under it after the step -- the same one-hop settle a combatant
## drifting the overworld uses, so walking into a floating island's rim carries
## you up onto it here exactly as it does there -- and it turns the character to
## face the way it is going, because a character walking north is facing north.
##
## False comes back when there was no stride to take: arrived, blocked, out of
## strides, or never aimed. The caller reads why off the fields.
func stride(
	actor: Combatant, terrain: TerrainQuery, length: float, most_steps: int
) -> bool:
	if is_over() or has_arrived(actor):
		return false
	if steps >= most_steps:
		overrun = true
		return false
	var here := Vector2(actor.x, actor.z)
	var gap := to - here
	var step := gap.normalized() * minf(length, gap.length())
	var next := here + step
	if terrain != null and not terrain.is_passable_at(next.x, next.y):
		blocked = true
		blocked_at = next
		return false
	walked += here.distance_to(next)
	actor.x += step.x
	actor.z += step.y
	actor.heading = fposmod(atan2(step.y, step.x), TAU)
	if terrain != null:
		actor.settle(terrain)
	steps += 1
	return true


## The tally an outcome reports: how far it went and how many strides it took.
func tally() -> Dictionary:
	return {"walked": snappedf(walked, 0.001), "steps": steps}
