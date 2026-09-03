extends RefCounted
## What a character can pick out around it, as plain data.
##
## A person choosing an action has to name what they are choosing it *at*: a
## character to speak to, a pile to take something out of, a chest to unlock,
## something they are carrying to attack with. The choices themselves are
## `Action`s out of the catalogue and always were; what was missing is the list
## of things a person can put in one, and that list is not the interface's to
## invent -- section 10 already says what a character can make out around it, and
## this is that answer read once more.
##
## ## It is the observation, projected
##
## Everything in `aims` comes out of `Observation.of()`, which is the same packet
## a language-model mind is handed and is where "what is near enough", "what is
## in line of sight" and "what has this character met" are all decided. Nothing
## here widens it: a thing this character cannot make out is not in the list, so
## an interface cycling through the list cannot aim at the whole world. Nothing
## here narrows it either -- every row the observation holds is offered, and what
## is possible from there is `ActionEngine`'s to answer, as it is for everybody.
##
## ## It decides nothing
##
## There is no rule here about reach, earshot, cost or possibility, and no
## opinion about what a good choice would be -- the discipline `sim/live_choice.gd`
## and `sim/decision_source.gd` keep, for the same reason. A pile forty units
## away is in the list and picking something out of it is refused by the engine
## in the engine's own words; the list is what can be *named*, not what will
## work.
##
## ## Nothing in it is a handle
##
## Every row is a dictionary of numbers and strings. The interface reads this and
## never the scene, so there is nothing on the render side to keep in step and
## nothing there that can be written back through.
class_name Surroundings

## What a row of `aims` calls something the character has not met: the id it
## knows it by, which is also what an action takes.
const ANONYMOUS := "#%d"

## What the three sorts of row are called. A character, a nobody's pile on the
## ground, and a placed object -- the observation's own words for them, carried
## through rather than re-decided.
const CHARACTER := "character"
const PILE := "pile"
const OBJECT := "object"

## Which character this is the view of.
var driven_id: int = 0

## Where that character is standing, in world x and z. What a walk key steps
## away from.
var here := Vector2.ZERO

## Everything that can be named as a target, nearest first: one row of
## `{"id": int, "kind": String, "label": String, "distance": float,
## "in_sight": bool, "inside": PackedStringArray}`.
##
## `inside` is what can be seen lying in the thing -- empty for a character, for
## a shut chest and for anything that holds nothing.
var aims: Array[Dictionary] = []

## What this character is carrying, by name, in the observation's own order.
var carrying := PackedStringArray()

## Every trade offered to or by this character, oldest first:
## `{"mine": bool, "from": String, "to": String, "other": int,
## "give": PackedStringArray, "give_money": int,
## "want": PackedStringArray, "want_money": int}`.
##
## `give` and `want` are always the *proposer's* halves, whichever side this
## character is on, because that is how the offer was made and how the engine
## will honour it.
var offers: Array[Dictionary] = []

## The last few lines this character could hear, oldest last:
## `{"speaker": String, "yours": bool, "text": String, "shout": bool,
## "to_you": bool, "to": String}`.
##
## Which of them it could hear at all is `Observation`'s answer, which is the
## engine's: a line is heard when `ActionEngine` put this character in its
## `heard_by`.
var heard: Array[Dictionary] = []

## The nearest place the world has a name for, or an empty dictionary. Filled in
## by `SimWorld.surroundings_of`, which is the only thing that knows the world has places
## in it at all.
var place := {}


## The view one character has of the scene it is standing in.
##
## A pure function of the two, like the observation it is built out of: two calls
## with the same scene and the same character produce the same rows.
static func of(scene: ActionScene, id: int) -> Surroundings:
	var view := Surroundings.new()
	view.driven_id = id
	if scene == null:
		return view
	var actor := scene.actor_of(id)
	if actor == null:
		return view
	view.here = Vector2(actor.x, actor.z)
	var seen := Observation.of(scene, actor)
	view.carrying = seen.self_carrying
	var labels := {id: "you"}
	for row in seen.entities:
		var label := _label_of(row)
		labels[int(row["id"])] = label
		view.aims.append({
			"id": int(row["id"]),
			"kind": CHARACTER,
			"label": label,
			"distance": float(row["distance"]),
			"in_sight": bool(row["line_of_sight"]),
			"inside": PackedStringArray(),
		})
	for row in seen.objects:
		var thing := scene.object_of(int(row["id"]))
		view.aims.append({
			"id": int(row["id"]),
			"kind": PILE if String(row["type"]) == PILE else OBJECT,
			"label": String(row["name"]),
			"distance": float(row["distance"]),
			"in_sight": bool(row["line_of_sight"]),
			# What is in it is the object's own answer, and only for one that can
			# be seen at all: a thing out of sight is a shape, not an inventory.
			"inside": PackedStringArray() if thing == null or not row["line_of_sight"] \
				else thing.contents_seen(),
		})
	view._read_offers(scene, labels)
	view._read_heard(seen)
	return view


# Every offer this character is on one side of, in the order they were made.
func _read_offers(scene: ActionScene, labels: Dictionary) -> void:
	for offer in scene.offers:
		var from_id := int(offer["from"])
		var to_id := int(offer["to"])
		if from_id != driven_id and to_id != driven_id:
			continue
		var mine := from_id == driven_id
		offers.append({
			"mine": mine,
			"other": to_id if mine else from_id,
			"from": String(labels.get(from_id, ANONYMOUS % from_id)),
			"to": String(labels.get(to_id, ANONYMOUS % to_id)),
			"give": PackedStringArray(offer["give"]),
			"give_money": int(offer["give_money"]),
			"want": PackedStringArray(offer["want"]),
			"want_money": int(offer["want_money"]),
		})


# What was heard, with the two ids turned into what this character calls them.
func _read_heard(seen: Observation) -> void:
	for row in seen.heard:
		heard.append({
			"speaker": "you" if bool(row["yours"]) else _label_of(row),
			"yours": bool(row["yours"]),
			"text": String(row["text"]),
			"shout": bool(row["shout"]),
			"to_you": bool(row["to_you"]),
			"to": "you" if bool(row["to_you"]) else (
				"" if bool(row["shout"]) else ANONYMOUS % int(row["to"])),
		})


## The row for an id, or an empty dictionary. What an interface holding an id
## from one frame asks on the next, so that a thing which has walked out of sight
## stops being aimed at rather than being aimed at from memory.
func aim_of(id: int) -> Dictionary:
	for row in aims:
		if int(row["id"]) == id:
			return row
	return {}


## What the character is standing on the edge of doing to somebody: the offer
## standing between this character and another, either way round, or an empty
## dictionary.
func offer_with(id: int) -> Dictionary:
	for row in offers:
		if int(row["other"]) == id:
			return row
	return {}


# What a packet row is called, or the id it is known by. A name is knowledge --
# `Observation` decides whether this character has any -- and an id is what is
# left when it has none, which is also what an action takes.
static func _label_of(row: Dictionary) -> String:
	var named: Variant = row.get("name", null)
	if named is String and String(named) != "":
		return String(named)
	return ANONYMOUS % int(row.get("speaker", row.get("id", 0)))
