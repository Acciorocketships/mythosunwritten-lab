extends RefCounted
## Something in the world that is not a character: a pile of loot on the ground,
## a chest, a door.
##
## Section 2.1's actions reach three sorts of thing -- positions, characters and
## objects -- and this is the third. It is deliberately thin. An object has a
## place, a name, possibly something inside it, and possibly a way of being
## opened; it has no behaviour, because everything that happens to it happens in
## `ActionEngine`, and it has no appearance, because what a chest looks like is
## the render layer's table's business and this layer has never heard of it.
##
## ## A pile and a chest are one class
##
## What is inside an object is an `Inventory` -- the same class a character
## carries, which is already the class a pile on the ground is (see
## sim/inventory.gd). So picking something out of a chest and picking it up off
## the ground are one `Inventory.transfer()` between two inventories, and neither
## the engine nor this file has a second path for the second case. The one
## difference the engine reads is `pile`: a pile is nobody's, so dropping
## something at your feet may add to one, while a chest is a place and never
## merges with anything.
##
## ## Shut, and what opens it
##
## `needs` is the name of the item an `interact` must be made with -- section
## 2.1's lockpick, generically. `shut` is whether it is closed against reaching
## inside: while it is, `pick_up` and `drop` through it are refused, and an
## `examine` sees that it is shut and not what is in it. Nothing here is a lock
## *mechanic*; it is the smallest state an interaction can move, and what a
## particular object requires is set by whoever puts it in the world.
class_name WorldObject

## Which object this is, in the scene's one id space -- the same space the
## characters are numbered in, so a target is a thing and not a thing-of-a-sort.
var id: int = 0

## What it is called. How an action names it in a reason and how a report prints
## it; nothing branches on it.
var object_name: String = ""

## Where it stands, in world units.
var x: float = 0.0
var z: float = 0.0
var y: float = 0.0

## What is inside it, or null when it is not the sort of thing that holds
## anything.
var contents: Inventory = null

## Whether it is a nobody's pile on the ground rather than a placed object.
var pile: bool = false

## Whether it is closed against reaching inside.
var shut: bool = false

## The name of the item an interaction with it must be made with, or "" when it
## takes none.
var needs: String = ""


## A pile of loot lying on the ground.
static func loose(at_x: float, at_z: float, holding: Inventory = null) -> WorldObject:
	var made := WorldObject.new()
	made.object_name = "pile"
	made.x = at_x
	made.z = at_z
	made.pile = true
	made.contents = Inventory.new() if holding == null else holding
	return made


## A chest: a placed thing that holds things, and may be shut against an item.
static func chest(
	called: String,
	at_x: float,
	at_z: float,
	holding: Inventory = null,
	opened_by: String = "",
) -> WorldObject:
	var made := WorldObject.new()
	made.object_name = called
	made.x = at_x
	made.z = at_z
	made.contents = Inventory.new() if holding == null else holding
	made.needs = opened_by
	made.shut = opened_by != ""
	return made


## A door, a lever, a pressure plate: a placed thing that holds nothing and is
## only ever interacted with.
static func fixture(
	called: String, at_x: float, at_z: float, opened_by: String = ""
) -> WorldObject:
	var made := WorldObject.new()
	made.object_name = called
	made.x = at_x
	made.z = at_z
	made.needs = opened_by
	made.shut = opened_by != ""
	return made


## Whether anything can be taken out of it or put into it at all.
func holds_things() -> bool:
	return contents != null


## Whether it can be reached inside right now.
func is_open() -> bool:
	return not shut


## How far away a world position is across the ground -- the same measure
## `Combatant` uses, so a reach is one number whichever pair it is between.
func distance_from(at_x: float, at_z: float) -> float:
	return Vector2(x - at_x, z - at_z).length()


## Put it down on whatever is under it. An object placed with no terrain to hand
## keeps the height it was given.
func settle(terrain: TerrainQuery) -> void:
	if terrain == null:
		return
	var support := terrain.support_at(x, z, y)
	y = terrain.wading_height_at(x, z, y) if support == -INF else support


## What can be seen of it from outside: what it is, whether it is shut, and --
## only when it is not -- what is in it.
func observed() -> Dictionary:
	var seen := {
		"id": id,
		"name": object_name,
		"kind": "pile" if pile else "object",
		"shut": shut,
	}
	if needs != "":
		seen["needs"] = needs
	if holds_things() and is_open():
		seen["holds"] = contents.size()
		seen["money"] = contents.money
	return seen


## The names of what is lying in it, for anyone who can see inside.
##
## `observed()` above says how many things are in an open container and how much
## money, which is what a glance gives; this is the same glance carried one step
## further, to what those things are called. It is here rather than beside
## whoever is looking for the reason `observed()` is here: what can be seen of an
## object is the object's own answer, and a second reading of it somewhere else
## would be a second answer.
##
## Nothing comes back from a shut thing and nothing from a thing that holds
## nothing, so the rule that a shut chest keeps its contents to itself is this
## one line and not a check made by every caller.
func contents_seen() -> PackedStringArray:
	var named := PackedStringArray()
	if not holds_things() or shut:
		return named
	for entry in contents.carried:
		var item := Inventory.item_of(entry)
		named.append("?" if item == null else item.item_name)
	return named


## One line, in the form the transcripts and the tests compare.
func line() -> String:
	return "#%d %s at (%.3f, %.3f, %.3f) %s%s" % [
		id, object_name, x, y, z,
		"shut" if shut else "open",
		"" if contents == null else " [%s]" % contents.line(),
	]


## A short, stable string of everything about it that an action can move.
func fingerprint() -> String:
	return "#%d %s (%.3f, %.3f, %.3f) %s needs=%s %s" % [
		id, object_name, x, y, z, "shut" if shut else "open", needs,
		"-" if contents == null else contents.fingerprint(),
	]
