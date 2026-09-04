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
## constructors, and that is the whole of what it does. There is no walking here,
## no arrival test, no reach, no earshot, no cooldown, no check that a chest can
## be opened and no second opinion about how far a character can jump: all of
## that is `ActionEngine`'s, and a person's choice reaches it by exactly the path
## a wandering rule's choice does. So there is no movement path beside the one
## the world already has and no second answer to what is possible -- pressing a
## key puts an action in a holder, and the world's own control loop picks it up
## on its next tick like anybody else's.
##
## A key that means nothing here produces nothing, and the shell falls through to
## whatever else it binds.
##
## ## Aiming: the person picks a target, and the world says what there is to pick
##
## Nine of the twelve actions need something to be aimed at, and what may be
## aimed at is not this file's to decide. `Surroundings` is the world's answer --
## it is `Observation`, the same packet a language-model mind is handed, turned
## into plain rows -- and everything here does is walk along that list. So the
## person can aim at what their character can actually make out and at nothing
## else, and the rule that decides which is that is in the simulation, where the
## same rule already answered the same question for everybody else.
##
## Three things are picked and remembered between presses, and they are kept by
## *identity* rather than by position in a list, so a thing that walks out of
## sight stops being aimed at rather than the aim sliding onto whatever took its
## place:
##
##   * what is aimed at -- a character, a pile or a placed object;
##   * what is held -- something carried, by name, or nothing, which is bare
##     hands and is a real choice: an interaction with no item in it is refused
##     differently from one with the wrong item in it;
##   * what is being taken -- one of the things that can be seen inside whatever
##     is aimed at.
##
## Two more are dialled rather than picked: which of a few things to say, and how
## many coins are in the next offer -- negative for coins given, positive for
## coins asked. Typing a line of speech needs a text field the interface does not
## have yet; until it does, a person picks a line rather than writing one, and
## that is a limit of this file and not of `say`, which takes any text at all.
##
## ## The keys
##
## Moving, which needs no target because a position is one:
##
##   * **W A S D**, and the arrow keys -- walk one step in that direction. The
##     directions are the camera's: the view looks down the world's +z axis from
##     behind, so "up the screen" is -z. Which way the character is left facing
##     is remembered, and is what a jump with no direction of its own uses.
##   * **G** -- go to the nearest place the world has a name for. The world says
##     which (`SimWorld.place_near_observer`).
##   * **J** -- hop, inside what an ordinary character's DEX reaches. **K** --
##     leap, past it, so that the engine's refusal is a thing a person can
##     provoke rather than a sentence only a test ever sees. Nothing here decides
##     which: `ActionEngine._jump` measures the gap against DEX and says.
##
## Picking:
##
##   * **Tab** -- aim at the next thing in sight. **F** -- hold the next thing
##     you carry, or nothing. **C** -- pick the next thing you can see inside
##     what you have aimed at. **B** -- pick the next thing to say. **-** and
##     **=** -- the coins in your next offer.
##
## Doing, all of it at what is aimed at:
##
##   * **P** go to it · **E** examine it · **L** look at what you are holding ·
##     **Q** take the chosen thing out of it · **X** drop what you are holding ·
##     **V** put what you are holding into it · **T** say the chosen line to it ·
##     **Y** shout the chosen line · **O** offer it a trade · **U** accept the
##     offer standing from it · **I** deny that offer · **H** interact with it,
##     using what you are holding · **N** attack it with what you are holding ·
##     **M** wait.
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

## How many ticks one press of the wait key asks for. Section 2.1 spells the
## action "wait (duration)", so a duration has to come from somewhere; this is
## the interface's answer to "how long", and the person presses it again for
## longer.
const WAITS := 5

## What the coin dial steps by and how far it goes either way. Negative is coins
## given, positive is coins asked.
const COIN_STEP := 1
const COIN_MOST := 20

## The things a person can say until there is somewhere to type.
##
## Interface furniture, and the one place in the whole control surface where the
## shell puts words in a character's mouth. `say` takes any text; these are what
## is reachable from a keyboard with no text field on it yet.
const LINES := [
	"well met",
	"what will you take for it?",
	"that is no bargain",
	"stand back",
]

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

## The keys that are not a direction: three for moving, five for picking, and
## one per verb.
const KEY_PLACE := KEY_G
const KEY_HOP := KEY_J
const KEY_LEAP := KEY_K

const KEY_AIM := KEY_TAB
const KEY_HOLD := KEY_F
const KEY_INSIDE := KEY_C
const KEY_LINE := KEY_B
const KEY_FEWER_COINS := KEY_MINUS
const KEY_MORE_COINS := KEY_EQUAL

const KEY_APPROACH := KEY_P
const KEY_EXAMINE := KEY_E
const KEY_LOOK := KEY_L
const KEY_TAKE := KEY_Q
const KEY_DROP := KEY_X
const KEY_PUT := KEY_V
const KEY_SAY := KEY_T
const KEY_SHOUT := KEY_Y
const KEY_OFFER := KEY_O
const KEY_ACCEPT := KEY_U
const KEY_DENY := KEY_I
const KEY_INTERACT := KEY_H
const KEY_ATTACK := KEY_N
const KEY_WAIT := KEY_M

## Which way a character is left facing before it has been walked anywhere: away
## from the camera, which is up the screen.
const FACING_AT_REST := Vector2(0.0, -1.0)

## What is held when nothing is: bare hands, which `interact` takes and which is
## a different thing from holding something the world has no use for.
const EMPTY_HANDS := ""

## What is aimed at, by the id the world knows it by, or zero for nothing.
var aimed_id := 0

## What is held, by name, or `EMPTY_HANDS`.
var holding := EMPTY_HANDS

## Which thing inside what is aimed at is being taken, by name, or "".
var taking := ""

## Which line is picked, as an index into `LINES`.
var line_at := 0

## The coins in the next offer: negative given, positive asked.
var coins := 0

## Which way the character was last sent, which is what a jump uses.
var facing := FACING_AT_REST

## What the last press could not do, in the interface's own words, or "".
##
## This is never a refusal. A refusal is the engine's answer to an action it was
## asked to resolve, and is quoted on the answer panel; this is the interface
## saying that the person has not yet picked what the action needs -- nothing was
## aimed at, nothing is being held -- so no action was built at all.
var note := ""


## Turn one key press into what the person wants their character to do next.
##
## The whole of the input surface. Returns the `Action` to put in the holder, or
## null for a key that picked something, dialled something or meant nothing --
## in which case `note` may say what was missing.
func press(keycode: int, view: Surroundings) -> Action:
	note = ""
	var way := direction_of(keycode)
	if way != Vector2.ZERO:
		facing = way
		return walk(way)
	match keycode:
		KEY_HOP:
			return jump_from(view.here, facing, HOP)
		KEY_LEAP:
			return jump_from(view.here, facing, LEAP)
		KEY_PLACE:
			if view.place.is_empty():
				note = "nowhere named is within reach"
				return null
			return go_to_place(view.place)
		KEY_AIM:
			_aim_next(view)
			return null
		KEY_HOLD:
			_hold_next(view)
			return null
		KEY_INSIDE:
			_take_next(view)
			return null
		KEY_LINE:
			line_at = (line_at + 1) % LINES.size()
			return null
		KEY_FEWER_COINS:
			coins = maxi(coins - COIN_STEP, -COIN_MOST)
			return null
		KEY_MORE_COINS:
			coins = mini(coins + COIN_STEP, COIN_MOST)
			return null
		KEY_WAIT:
			return Action.wait(WAITS)
		KEY_LOOK:
			if holding == EMPTY_HANDS:
				note = "you are holding nothing to look at"
				return null
			return Action.examine(holding)
		KEY_DROP:
			if holding == EMPTY_HANDS:
				note = "you are holding nothing to drop"
				return null
			return Action.drop(holding)
	return _at_what_is_aimed(keycode, view)


# The nine verbs that need something aimed at, and the one thing they share:
# without a target there is no action to build, and saying so is not a refusal.
func _at_what_is_aimed(keycode: int, view: Surroundings) -> Action:
	if not _needs_a_target(keycode):
		return null
	if aimed_id == 0 or view.aim_of(aimed_id).is_empty():
		note = "nothing is aimed at"
		return null
	match keycode:
		KEY_APPROACH:
			return Action.go_to(aimed_id)
		KEY_EXAMINE:
			return Action.examine(aimed_id)
		KEY_TAKE:
			if taking == "":
				note = "nothing is picked out of what you have aimed at"
				return null
			return Action.pick_up(taking, aimed_id)
		KEY_PUT:
			if holding == EMPTY_HANDS:
				note = "you are holding nothing to put in"
				return null
			return Action.drop(holding, aimed_id)
		KEY_SAY:
			return Action.say(LINES[line_at], aimed_id)
		KEY_SHOUT:
			return Action.say(LINES[line_at])
		KEY_OFFER:
			var given := PackedStringArray()
			if holding != EMPTY_HANDS:
				given.append(holding)
			return Action.trade_propose(
				aimed_id, given, maxi(0, -coins),
				PackedStringArray(), maxi(0, coins))
		KEY_ACCEPT:
			return Action.trade_accept(aimed_id)
		KEY_DENY:
			return Action.trade_deny(aimed_id)
		KEY_INTERACT:
			return Action.interact(aimed_id, holding)
		KEY_ATTACK:
			if holding == EMPTY_HANDS:
				note = "you are holding nothing to attack with"
				return null
			return Action.attack(aimed_id, holding)
	return null


# Whether a key is one of the ones aimed at something. A shout is on the list
# because it is the same key row as the rest of speech and because a person who
# has aimed at nobody is more likely to have meant to aim than to have meant to
# shout.
static func _needs_a_target(keycode: int) -> bool:
	return [
		KEY_APPROACH, KEY_EXAMINE, KEY_TAKE, KEY_PUT, KEY_SAY, KEY_SHOUT,
		KEY_OFFER, KEY_ACCEPT, KEY_DENY, KEY_INTERACT, KEY_ATTACK,
	].has(keycode)


# --- The three rings ------------------------------------------------------


# Aim at the next thing the world says is in sight, wrapping round. What is
# being taken is forgotten with it: it named something inside the last thing.
func _aim_next(view: Surroundings) -> void:
	if view.aims.is_empty():
		aimed_id = 0
		taking = ""
		note = "there is nothing in sight to aim at"
		return
	var at := -1
	for index in view.aims.size():
		if int((view.aims[index] as Dictionary)["id"]) == aimed_id:
			at = index
			break
	aimed_id = int((view.aims[(at + 1) % view.aims.size()] as Dictionary)["id"])
	taking = ""
	_take_next(view)


# Hold the next thing carried, or nothing. Nothing is one of the places on the
# ring rather than a key of its own, because bare hands are a choice.
func _hold_next(view: Surroundings) -> void:
	var ring := PackedStringArray([EMPTY_HANDS])
	ring.append_array(view.carrying)
	var at := ring.find(holding)
	holding = ring[(at + 1) % ring.size()] if at >= 0 else ring[0]


# Pick the next thing that can be seen inside whatever is aimed at.
func _take_next(view: Surroundings) -> void:
	var inside := inside_of(view, aimed_id)
	if inside.is_empty():
		taking = ""
		return
	var at := inside.find(taking)
	taking = inside[(at + 1) % inside.size()] if at >= 0 else inside[0]


## What can be seen inside a thing, by the world's account of it. Empty for a
## character, for a shut chest, and for anything holding nothing.
static func inside_of(view: Surroundings, id: int) -> PackedStringArray:
	var row := view.aim_of(id)
	return PackedStringArray() if row.is_empty() else PackedStringArray(row["inside"])


## What is aimed at, in one line, for a readout: what it is called, what sort of
## thing it is and how far off. "nothing aimed" when nothing is.
func aim_line(view: Surroundings) -> String:
	var row := view.aim_of(aimed_id)
	if row.is_empty():
		return "nothing aimed"
	# A thing this character has never met has no name, and what the world hands
	# back for it is the id it is known by -- so the id is not written twice.
	var label := String(row["label"])
	var named := label if label.begins_with("#") else "#%d %s" % [
		int(row["id"]), label,
	]
	return "%s (%s) %.1f away" % [named, String(row["kind"]), float(row["distance"])]


## What is held, what is being taken and what is on the coin dial, in one line.
func holding_line() -> String:
	return "holding %s / taking %s / coins %s / saying \"%s\"" % [
		"nothing" if holding == EMPTY_HANDS else holding,
		"nothing" if taking == "" else taking,
		coin_line(), LINES[line_at],
	]


## The coin dial in words: which way the coins go and how many.
func coin_line() -> String:
	if coins == 0:
		return "none"
	return "you ask %d" % coins if coins > 0 else "you give %d" % -coins


# --- The pure builders ----------------------------------------------------


## Which way a key means, or `Vector2.ZERO` for a key that is not a walk key.
static func direction_of(keycode: int) -> Vector2:
	var way: Variant = WALK_KEYS.get(keycode, Vector2.ZERO)
	return way if way is Vector2 else Vector2.ZERO


## Walk one step in a direction: the catalogue's `go to`, written as the step
## itself rather than as the place it ends at.
##
## A key press is a direction and a length and never a place, so this is the
## shape of the row that fits it -- the same `go_to` a model chooses, given its
## offset instead of its target. It reads nothing about where the character is:
## a person pressing W means "one step north from wherever I am", and where that
## is is the engine's to know when the step is actually taken.
static func walk(way: Vector2) -> Action:
	return Action.go_to_offset(way.normalized() * STEP)


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
		"Tab          aim at the next thing in sight",
		"F            hold the next thing you carry, or nothing",
		"C            pick the next thing inside what you have aimed at",
		"B            pick the next thing to say",
		"- / =        the coins in your next offer (given / asked)",
		"P            go to what you have aimed at",
		"E            examine what you have aimed at",
		"L            look at what you are holding",
		"Q            take the picked thing out of what you have aimed at",
		"X            drop what you are holding",
		"V            put what you are holding into what you have aimed at",
		"T            say the picked line to what you have aimed at",
		"Y            shout the picked line",
		"O            offer a trade to what you have aimed at",
		"U            accept the offer standing from it",
		"I            deny the offer standing from it",
		"H            interact with it, using what you are holding",
		"N            attack it with what you are holding",
		"M            wait (%d ticks)" % WAITS,
	])
