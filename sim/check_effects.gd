extends RefCounted
## The operations the engine exposes to a resolving call, and the only way one
## can change anything.
##
## Section 7 says a successful check is resolved by a second call acting as a
## scoped orchestrator, and section 8 says the orchestrator resolves world events
## *through tools*. This file is that scope: four operations, each of them a thing
## the engine does, each of them refusable. A resolving reply is read into rows of
## this table and nothing else; a line naming anything not in the table is
## refused, named in the transcript, and changes nothing.
##
## The model therefore never edits state. It writes `open target=#8`; this file
## finds object 8, checks it is a shut thing in the scene, and sets it open. Every
## sentence in the reply that is not one of these four lines is inert.
##
## ## Why these four
##
## They are the smallest set that covers what a forced lock, a sprung catch or a
## shoved fixture actually does to a world of characters and objects: a state
## edit either way, a move, and a spill. All four are edits to objects, because
## the hook a check is raised from -- `AbilityCheck.HOOK` -- is an interaction
## with an object. Nothing here can touch a character, and nothing here can make
## an item out of nothing.
class_name CheckEffects

const OPEN := "open"
const SHUT := "shut"
const MOVE := "move"
const SPILL := "spill"

## How far `move` may carry a thing, in world units. A shove, not a delivery.
const NUDGE := 4.0

## How many operations the engine carries out for one success. A resolving call
## that writes more has the rest refused with this as the reason -- one success
## is one consequence and a little, not a rewrite of the neighbourhood.
const AT_MOST := 3

## The table. `name`, the keys each takes, and what the engine does about it.
const ROWS := [
	{
		"name": OPEN, "keys": ["target"],
		"says": "a shut thing comes open",
	},
	{
		"name": SHUT, "keys": ["target"],
		"says": "an open thing falls shut",
	},
	{
		"name": MOVE, "keys": ["target", "to"],
		"says": "a thing is shoved, at most %.1f units, onto ground that carries it" % NUDGE,
	},
	{
		"name": SPILL, "keys": ["target"],
		"says": "everything inside an open thing ends up on the ground beside it",
	},
]


## The table as a model is shown it.
static func catalogue_lines() -> PackedStringArray:
	var written := PackedStringArray()
	for row in ROWS:
		var keys := PackedStringArray()
		for key in row["keys"]:
			# In angle brackets and never a specimen, the same way the other two
			# prompts write a value. See `ModelPrompt.SORT_FORMS`: a placeholder
			# that reads back as a legal value is one a model hands back.
			keys.append("%s=%s" % [key, "(<x>, <z>)" if key == "to" else "#<id>"])
		written.append("  %-6s %-22s -- %s" % [row["name"], " ".join(keys), row["says"]])
	return written


## The operation names, for a scan that wants to know what is on offer.
static func names() -> PackedStringArray:
	var found := PackedStringArray()
	for row in ROWS:
		found.append(String(row["name"]))
	return found


# --- Reading a reply ------------------------------------------------------


## Read a resolving reply into operations.
##
## Line by line: a line beginning with an operation name and carrying its keys is
## an operation; every other line -- prose, a preamble, a claim that something
## happened -- is not, and is dropped here. What comes back is what the engine
## will consider, in the order the reply wrote it.
static func read(reply: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line in reply.split("\n"):
		var one := _read_line(String(line))
		if not one.is_empty():
			found.append(one)
	return found


static func _read_line(line: String) -> Dictionary:
	var text := line.strip_edges().lstrip("-*# \t").strip_edges()
	for row in ROWS:
		var named: String = row["name"]
		if text != named and not text.begins_with(named + " "):
			continue
		var rest := text.substr(named.length()).strip_edges()
		var op := {"op": named, "line": text}
		for key in row["keys"]:
			var said := _value_of(rest, String(key))
			if said == "":
				return {}
			if key == "to":
				var at: Variant = _position_of(said)
				if at == null:
					return {}
				op["to"] = at
			else:
				op["target"] = _id_of(said)
		return op if int(op.get("target", 0)) > 0 else {}
	return {}


# Everything after `key=` up to the next ` key=` of this table's vocabulary.
static func _value_of(rest: String, key: String) -> String:
	var at := rest.find("%s=" % key)
	if at < 0:
		return ""
	if at > 0 and not " \t".contains(rest.substr(at - 1, 1)):
		return ""
	var said := rest.substr(at + key.length() + 1)
	for other in ["target", "to"]:
		if other == key:
			continue
		var ends := said.find(" %s=" % other)
		if ends >= 0:
			said = said.substr(0, ends)
	return said.strip_edges()


static func _id_of(said: String) -> int:
	var bare := said.strip_edges().lstrip("#").strip_edges()
	var digits := ""
	for at in bare.length():
		if not bare.substr(at, 1).is_valid_int():
			break
		digits += bare.substr(at, 1)
	return 0 if digits == "" else digits.to_int()


static func _position_of(said: String) -> Variant:
	var bare := said.strip_edges().lstrip("(").rstrip(")")
	var parts := bare.split(",")
	if parts.size() != 2:
		return null
	var x := String(parts[0]).strip_edges()
	var z := String(parts[1]).strip_edges()
	if not x.is_valid_float() or not z.is_valid_float():
		return null
	return Vector2(x.to_float(), z.to_float())


# --- Carrying one out -----------------------------------------------------


## Carry out one operation against the world, or say why not.
##
## The one door. Every branch finds the object by id in the scene it was handed,
## refuses anything that is not there or not in a state the operation applies to,
## and otherwise makes exactly the edit the table says. Returns
## `{"ok", "reason", "line", "target"}`.
static func apply(scene: ActionScene, op: Dictionary) -> Dictionary:
	var line := String(op.get("line", ""))
	var target := int(op.get("target", 0))
	if scene == null:
		return _no(line, target, "there is no world to change")
	var thing := scene.object_of(target)
	if thing == null:
		return _no(line, target, "there is nothing with id %d to change" % target)
	match String(op.get("op", "")):
		OPEN:
			if thing.is_open():
				return _no(line, target, "the %s is already open" % thing.object_name)
			thing.shut = false
			return _yes(line, target, "the %s came open" % thing.object_name)
		SHUT:
			if not thing.is_open():
				return _no(line, target, "the %s is already shut" % thing.object_name)
			thing.shut = true
			return _yes(line, target, "the %s fell shut" % thing.object_name)
		MOVE:
			return _move(scene, thing, op, line, target)
		SPILL:
			return _spill(scene, thing, line, target)
	return _no(line, target, "there is no such operation")


static func _move(
	scene: ActionScene, thing: WorldObject, op: Dictionary, line: String, target: int
) -> Dictionary:
	var to: Vector2 = op.get("to", Vector2.ZERO)
	var gap := thing.distance_from(to.x, to.y)
	if gap > NUDGE:
		return _no(line, target, "%.2f is further than a shove carries (%.2f)" % [gap, NUDGE])
	if scene.terrain != null and not scene.terrain.is_passable_at(to.x, to.y):
		return _no(line, target, "nothing there would hold the %s" % thing.object_name)
	thing.x = to.x
	thing.z = to.y
	thing.settle(scene.terrain)
	return _yes(line, target, "the %s was shoved %.2f to (%.3f, %.3f)" % [
		thing.object_name, gap, to.x, to.y,
	])


static func _spill(
	scene: ActionScene, thing: WorldObject, line: String, target: int
) -> Dictionary:
	if not thing.holds_things():
		return _no(line, target, "a %s holds nothing to spill" % thing.object_name)
	if not thing.is_open():
		return _no(line, target, "the %s is shut" % thing.object_name)
	if thing.contents.size() == 0 and thing.contents.money == 0:
		return _no(line, target, "the %s is empty" % thing.object_name)
	var fell := Inventory.ground()
	for entry in thing.contents.items().duplicate():
		if thing.contents.release(entry):
			fell.carry(entry)
	var coins := thing.contents.money
	if coins > 0 and thing.contents.pay(coins):
		fell.gain(coins)
	var pile := scene.add_object(WorldObject.loose(thing.x, thing.z, fell))
	return _yes(line, target, "%d thing%s and %d coins out of the %s onto pile #%d" % [
		fell.size(), "" if fell.size() == 1 else "s", coins, thing.object_name, pile.id,
	])


static func _yes(line: String, target: int, why: String) -> Dictionary:
	return {"ok": true, "reason": why, "line": line, "target": target}


static func _no(line: String, target: int, why: String) -> Dictionary:
	return {"ok": false, "reason": why, "line": line, "target": target}
