extends RefCounted
## What a key press means, as an action out of the catalogue.
##
## This is the render layer's half of a person being one of the minds. The
## simulation's half is `DecisionSource.live`, which reads a `LiveChoice` and
## names no key, no device and no screen; this is where the keys are, and it is
## the only place in the project that turns one into an intention.
##
## ## It builds choices and resolves nothing
##
## Every function here returns an `Action` made with one of `Action`'s own
## constructors -- `Action.go_to` and `Action.jump` -- and that is the whole of
## what it does. There is no walking here, no arrival test, no reach, no check
## that the ground can be stood on and no second opinion about how far a
## character can jump: all of that is `ActionEngine`'s, and a person's choice
## reaches it by exactly the path a wandering rule's choice does. So there is no
## movement path beside the one the world already has -- pressing a key puts an
## action in a holder, and the world's own control loop picks it up on its next
## tick like anybody else's.
##
## A key that means nothing here produces nothing, and the shell falls through to
## whatever else it binds.
##
## ## The keys
##
##   * **W A S D**, and the arrow keys -- walk one step in that direction. The
##     directions are the camera's: the view looks down the world's +z axis from
##     behind, so "up the screen" is -z. Which way the character is left facing
##     is remembered by the caller and is what a jump with no direction of its
##     own uses.
##   * **G** -- go to the nearest place the world has a name for, a village or a
##     landmark. The world says which (`SimWorld.place_near_observer`); this
##     turns its position into the same `go_to` a walk key makes.
##   * **J** -- hop. A short jump, inside what an ordinary character's DEX
##     reaches.
##   * **K** -- leap. A long jump, past what an ordinary character's DEX reaches,
##     so that the engine's refusal is a thing a person can actually provoke
##     rather than a sentence only a test ever sees. Nothing here decides whether
##     it is too far: `ActionEngine._jump` measures the gap against DEX and says.
class_name PlayerControls

## How far one press of a walk key carries, in world units.
##
## A fifth of `WorldCast.LEG`, which is how far the wandering rule sends a
## character on one `go_to`. A walk costs the same twenty ticks whatever its
## length -- that is `ActionCatalog`'s cost for the action, not a cost per unit
## -- so this is the trade between a press that goes somewhere and a press that
## overshoots what the person was aiming at.
const STEP := WorldCast.LEG / 5.0

## How far a hop goes, in world units. Inside the reach of an ordinary
## character: the cast is rolled at DEX 3, and `ActionEngine`'s reach at DEX 3 is
## 3.75 units.
const HOP := 3.0

## How far a leap goes. Outside that reach on purpose -- see the class note.
const LEAP := 12.0

## The walk keys, and which way across the ground each one means, in the world's
## (x, z) plane.
const WALK_KEYS := {
	KEY_W: Vector2(0.0, -1.0),
	KEY_UP: Vector2(0.0, -1.0),
	KEY_S: Vector2(0.0, 1.0),
	KEY_DOWN: Vector2(0.0, 1.0),
	KEY_A: Vector2(-1.0, 0.0),
	KEY_LEFT: Vector2(-1.0, 0.0),
	KEY_D: Vector2(1.0, 0.0),
	KEY_RIGHT: Vector2(1.0, 0.0),
}

## The three keys that are not a direction.
const KEY_PLACE := KEY_G
const KEY_HOP := KEY_J
const KEY_LEAP := KEY_K

## Which way a character is left facing before it has been walked anywhere: away
## from the camera, which is up the screen.
const FACING_AT_REST := Vector2(0.0, -1.0)


## Which way a key means, or `Vector2.ZERO` for a key that is not a walk key.
static func direction_of(keycode: int) -> Vector2:
	var way: Variant = WALK_KEYS.get(keycode, Vector2.ZERO)
	return way if way is Vector2 else Vector2.ZERO


## Walk one step from a position in a direction: the catalogue's `go to`, to the
## position a step away.
static func walk_from(here: Vector2, way: Vector2) -> Action:
	return Action.go_to(here + way.normalized() * STEP)


## Jump a stated distance from a position in a direction: the catalogue's
## `jump`, to the position that far away. Whether the character can actually
## reach it is the engine's to answer.
static func jump_from(here: Vector2, way: Vector2, far: float) -> Action:
	return Action.jump(here + way.normalized() * far)


## Go to a place the world named: the catalogue's `go to`, to where the world
## said the place is. The dictionary is `SimWorld.place_near_observer`'s, and
## nothing but its position is read.
static func go_to_place(place: Dictionary) -> Action:
	return Action.go_to(Vector2(float(place["x"]), float(place["z"])))


## What a person may press and what it does, one line each, for a run to print
## so that a person at the keyboard is not guessing.
static func bindings() -> PackedStringArray:
	return PackedStringArray([
		"WASD/arrows  walk one step (%.1f units)" % STEP,
		"G            go to the nearest named place",
		"J            hop (%.1f units)" % HOP,
		"K            leap (%.1f units, further than an ordinary DEX reaches)" % LEAP,
	])
