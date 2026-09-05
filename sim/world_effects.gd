extends RefCounted
## The operations the engine exposes to the world's dungeon master, and the only
## way it can change anything.
##
## Section 8 gives the orchestrator two duties: spawning characters, and
## "resolving world events via tools: add/remove objects, edit properties/states
## (move an object...)". This file is those tools. Seven operations, each of them
## a thing the engine does, each of them refusable. An answer is read into rows of
## this table and nothing else; a line naming anything not in the table is
## refused, named in the transcript, and changes nothing.
##
## The model therefore never edits state. It writes `place kind=crate
## at=(12.5, -4.0)`; this file checks the kind is one it knows, checks the ground
## there would carry it, and puts one there. Every sentence in the answer that is
## not one of these lines is inert.
##
## ## Three of its own, four borrowed
##
## `place`, `remove` and `spawn` are this file's, because nothing else in the
## project adds or takes away a thing in the world. `open`, `shut`, `move` and
## `spill` are `CheckEffects`', already written and already the only place those
## four edits happen, and a line naming one of them is read and carried out by
## that file rather than by a second copy here. Two tables that both set `shut`
## would be two answers to the same question, which is the mistake this project
## keeps not making.
##
## ## What is deliberately not here
##
## Nothing that reaches into a character's decision. There is no operation that
## sets a goal, chooses an action, writes a memory or moves a character, and the
## one thing this file writes onto a character sheet -- the persona, in `dress()`
## -- is written once, at the spawn it belongs to, and is prose and traits and
## nothing a control loop reads. The orchestrator changes the world; it never
## changes a mind.
##
## There is also no operation that tells a story. What the orchestrator may do is
## this list, and the list is object kinds and positions: no quest, no beat, no
## outcome anybody has written down in advance.
class_name WorldEffects

## The three operations this file carries out itself.
const PLACE := "place"
const REMOVE := "remove"
const SPAWN := "spawn"

## How many operations the engine carries out for one answer. An answer that
## names more has the rest refused with this as the reason: one look at the world
## is a nudge and not a rewrite of it.
const AT_MOST := 3

## How far from the nearest character a thing may be placed or a character
## spawned, in world units. The orchestrator edits the region that is being
## played in; a thing put down half a world away is refused rather than silently
## dropped into ground nobody will ever walk on.
const WITHIN := 40.0

## The word an answer uses when the world needs no change. Read as an answer and
## not as a failure to answer.
const NOTHING := "nothing"

## What `place` can put in the world. Four kinds, which are the two axes an
## object has: whether it holds anything, and whether it is shut. Nothing here is
## a prop catalogue -- what a chest looks like is the render layer's table's
## business, exactly as it is for everything else in `sim/`.
const KINDS := [
	{"kind": "chest", "holds": true, "shut": false},
	{"kind": "crate", "holds": true, "shut": true},
	{"kind": "door", "holds": false, "shut": true},
	{"kind": "stone", "holds": false, "shut": false},
]

## This file's own rows. `name`, the keys each takes, and what the engine does
## about it.
const ROWS := [
	{
		"name": PLACE, "keys": ["kind", "at"],
		"says": "a new thing stands there, on ground that carries it",
	},
	{
		"name": REMOVE, "keys": ["target"],
		"says": "a thing is taken out of the world",
	},
	{
		"name": SPAWN, "keys": ["role", "at"],
		"says": "a character is rolled for that ground and stands there",
	},
]

## Every key any operation in either table takes, so that a value can be read up
## to the next one of them.
const KEYS := ["kind", "at", "role", "target", "to"]

## How a borrowed row is marked once it has been read, so that `apply()` knows to
## hand it back to the file that owns it.
const BORROWED := "borrowed"


## The whole table as a model is shown it: this file's three, then the four it
## borrows, each on one line.
static func catalogue_lines() -> PackedStringArray:
	var written := PackedStringArray()
	for row in ROWS:
		var keys := PackedStringArray()
		for key in row["keys"]:
			keys.append("%s=%s" % [key, _example_of(String(key))])
		written.append("  %-6s %-30s -- %s" % [
			row["name"], " ".join(keys), row["says"],
		])
	written.append_array(CheckEffects.catalogue_lines())
	return written


## Every operation name on offer, this file's and the borrowed ones.
static func names() -> PackedStringArray:
	var found := PackedStringArray()
	for row in ROWS:
		found.append(String(row["name"]))
	found.append_array(CheckEffects.names())
	return found


## The kinds `place` knows, for a prompt and for a scan.
static func kinds() -> PackedStringArray:
	var found := PackedStringArray()
	for row in KINDS:
		found.append(String(row["kind"]))
	return found


static func kind_row(kind: String) -> Dictionary:
	for row in KINDS:
		if String(row["kind"]) == kind:
			return row
	return {}


# How one key's value is written, as the orchestrator prompt shows it.
#
# A key holding a position or an id is shown in angle brackets naming what goes
# there, and never a specimen of one, for the reason `ModelPrompt.SORT_FORMS`
# states at length and measured: over a full recording pass three of four local
# arms answered every one of this run's five looks with `spawn role=... at=`
# followed by the coordinate this function used to print, and the world refused
# all fifteen because that ground is 650 units from anybody. `kind` and `role`
# stay as they are: those are not placeholders but the engine's own two lists,
# and a value copied out of either is a value that works.
static func _example_of(key: String) -> String:
	match key:
		"at", "to":
			return "(<x>, <z>)"
		"kind":
			return "one of %s" % "/".join(kinds())
		"role":
			return "one of %s" % "/".join(SpawnRoll.roles())
	return "#<id>"


# --- Reading an answer -----------------------------------------------------


## Read an answer into operations.
##
## Line by line: a line beginning with an operation name and carrying its keys is
## an operation; every other line -- prose, a preamble, a claim that something
## happened -- is not, and is dropped here. A line naming one of the borrowed
## operations is read by the file that owns it and marked, so that nothing is
## parsed twice or parsed two ways.
static func read(reply: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line in reply.split("\n"):
		var one := _read_line(String(line))
		if not one.is_empty():
			found.append(one)
	return found


## Whether an answer said, in so many words, that nothing should change. An
## answer that names no operation and does not say this is a misread answer; one
## that says it is a decision, and the difference belongs in a transcript.
static func says_nothing(reply: String) -> bool:
	for line in reply.split("\n"):
		if _bared(String(line)).to_lower() == NOTHING:
			return true
	return false


static func _read_line(line: String) -> Dictionary:
	var text := _bared(line)
	for row in ROWS:
		var named: String = row["name"]
		if text != named and not text.begins_with(named + " "):
			continue
		return _read_keys(text, text.substr(named.length()).strip_edges(), row)
	var borrowed := CheckEffects.read(text)
	if borrowed.is_empty():
		return {}
	var one: Dictionary = borrowed[0]
	one[BORROWED] = true
	return one


static func _read_keys(text: String, rest: String, row: Dictionary) -> Dictionary:
	var op := {"op": String(row["name"]), "line": text}
	for key in row["keys"]:
		var said := _value_of(rest, String(key))
		if said == "":
			return {}
		match String(key):
			"at":
				var at: Variant = _position_of(said)
				if at == null:
					return {}
				op["at"] = at
			"target":
				var id := _id_of(said)
				if id <= 0:
					return {}
				op["target"] = id
			_:
				op[String(key)] = said.to_lower()
	return op


# Everything after `key=` up to the next key of the shared vocabulary.
static func _value_of(rest: String, key: String) -> String:
	var at := rest.find("%s=" % key)
	if at < 0:
		return ""
	if at > 0 and not " \t".contains(rest.substr(at - 1, 1)):
		return ""
	var said := rest.substr(at + key.length() + 1)
	for other in KEYS:
		if other == key:
			continue
		var ends := said.find(" %s=" % other)
		if ends >= 0:
			said = said.substr(0, ends)
	return said.strip_edges()


static func _bared(line: String) -> String:
	return line.strip_edges().lstrip("-*# \t").strip_edges()


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
## The one door. Returns `{"ok", "reason", "line", "target"}`, and for a spawn
## also `"spawned"` -- the id of the character now standing in the world with a
## rolled sheet and nobody written into it yet. Who that is comes next, and comes
## from somewhere else.
##
## `nth` is which spawn of the run this would be, which is what the sheet is
## rolled against. It is not read by any other operation.
static func apply(
	scene: ActionScene, op: Dictionary, world_seed: int, nth: int = 1
) -> Dictionary:
	var line := String(op.get("line", ""))
	if scene == null:
		return _no(line, 0, "there is no world to change")
	if bool(op.get(BORROWED, false)):
		return CheckEffects.apply(scene, op)
	match String(op.get("op", "")):
		PLACE:
			return _place(scene, op, line)
		REMOVE:
			return _remove(scene, op, line)
		SPAWN:
			return _spawn(scene, op, line, world_seed, nth)
	return _no(line, 0, "there is no such operation")


static func _place(scene: ActionScene, op: Dictionary, line: String) -> Dictionary:
	var kind := String(op.get("kind", ""))
	var row := kind_row(kind)
	if row.is_empty():
		return _no(line, 0, "there is no kind of thing called '%s' to place" % kind)
	var at: Vector2 = op.get("at", Vector2.ZERO)
	var refused := _out_of_reach(scene, at)
	if refused != "":
		return _no(line, 0, refused)
	var made := WorldObject.chest(kind, at.x, at.y) if bool(row["holds"]) \
		else WorldObject.fixture(kind, at.x, at.y)
	made.shut = bool(row["shut"])
	var put := scene.add_object(made)
	return _yes(line, put.id, "a %s now stands at (%.3f, %.3f) as #%d" % [
		kind, at.x, at.y, put.id,
	])


static func _remove(scene: ActionScene, op: Dictionary, line: String) -> Dictionary:
	var target := int(op.get("target", 0))
	if scene.actor_of(target) != null:
		return _no(line, target,
			"#%d is a character, and this changes the world and not who is in it"
				% target)
	var thing := scene.object_of(target)
	if thing == null:
		return _no(line, target, "there is nothing with id %d to take away" % target)
	scene.remove_object(thing)
	return _yes(line, target, "the %s is gone" % thing.object_name)


static func _spawn(
	scene: ActionScene, op: Dictionary, line: String, world_seed: int, nth: int
) -> Dictionary:
	var role := String(op.get("role", ""))
	if not SpawnRoll.is_role(role):
		return _no(line, 0, "there is no role called '%s' to roll" % role)
	var at: Vector2 = op.get("at", Vector2.ZERO)
	var refused := _out_of_reach(scene, at)
	if refused != "":
		return _no(line, 0, refused)

	# The order section 8 states, and the reason this operation exists here at
	# all: the sheet is rolled from the role's bands and the region's own
	# difficulty, and the character stands in the world with it, before anybody
	# has been asked who that makes them.
	var sheet := SpawnRoll.sheet_at(world_seed, nth, role, at.x, at.y)
	var one := Combatant.commander_at(
		at.x, at.y, 0.0, 0.0, sheet.level, SpawnRoll.looks_of(role))
	(one.piece as Commander).adopt(sheet)
	var stood := scene.add_actor(one)
	sheet.character_name = "%s #%d" % [role, stood.id]
	return {
		"ok": true, "line": line, "target": stood.id, "spawned": stood.id,
		"role": role,
		"reason": "a %s was rolled for ground of difficulty %d and stands at"
			% [role, sheet.level]
			+ " (%.3f, %.3f) as #%d, with no one written into it yet" % [
				at.x, at.y, stood.id,
			],
	}


# --- The persona, written once, onto the spawn it belongs to --------------


## Write who a spawned character is: the second half of section 8's sentence,
## carried out by the engine out of what came back.
##
## It is here rather than in the file that made the call for the same reason
## every other write is: so that the whole of what an answer can do to the world
## is one file. It refuses a character that is not there, and one that has
## already been written into -- a persona is written at a spawn, once.
static func dress(scene: ActionScene, id: int, persona: Dictionary) -> Dictionary:
	var line := "persona for #%d" % id
	if scene == null:
		return _no(line, id, "there is no world to write into")
	var one := scene.actor_of(id)
	if one == null or one.piece == null or not (one.piece is Commander):
		return _no(line, id, "there is no character with id %d" % id)
	var sheet := (one.piece as Commander).sheet
	if sheet == null:
		return _no(line, id, "#%d has no sheet to write on" % id)
	if sheet.backstory != "":
		return _no(line, id, "#%d has already been written into" % id)
	if not bool(persona.get("read", false)):
		return _no(line, id, "nothing readable came back: %s" % persona.get("why", ""))

	var called := String(persona.get("name", "")).strip_edges()
	if called != "":
		sheet.character_name = called
	sheet.backstory = String(persona.get("backstory", ""))
	sheet.traits = persona.get("traits", PackedStringArray())
	sheet.tendencies = persona.get("tendencies", PackedStringArray())
	return _yes(line, id, "#%d is %s, and the six numbers it was rolled with are"
		% [id, sheet.character_name] + " untouched")


# --- The furniture ---------------------------------------------------------


# Whether a position is near enough to anybody to be part of the region in play.
static func _out_of_reach(scene: ActionScene, at: Vector2) -> String:
	if scene.terrain != null and not scene.terrain.is_passable_at(at.x, at.y):
		return "nothing at (%.3f, %.3f) would carry it" % [at.x, at.y]
	var nearest := INF
	for one in scene.actors:
		nearest = minf(nearest, Vector2(one.x - at.x, one.z - at.y).length())
	if nearest == INF:
		return "there is nobody in the world for that to be near"
	if nearest > WITHIN:
		return "(%.3f, %.3f) is %.1f from the nearest character, and the world is" % [
			at.x, at.y, nearest,
		] + " changed within %.1f of somebody" % WITHIN
	return ""


static func _yes(line: String, target: int, why: String) -> Dictionary:
	return {"ok": true, "reason": why, "line": line, "target": target}


static func _no(line: String, target: int, why: String) -> Dictionary:
	return {"ok": false, "reason": why, "line": line, "target": target}
