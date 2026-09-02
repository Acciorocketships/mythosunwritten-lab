extends RefCounted
## Turns the combat part of a snapshot into things to draw, and holds nothing.
##
## Every value the shell needs to put a fight on screen -- where each piece
## stands, which way it is turned, which clip it should be playing, and which tag
## says what it looks like -- comes out of `placements()`, which is a pure
## function of one snapshot dictionary. It has no members, it remembers nothing
## between calls, and it never asks the simulation a question: the snapshot is
## the whole input.
##
## That is the point of the file existing at all. The render shell owns no piece
## of combat state -- no board, no match, no turn number, no hit points, no
## positions of its own -- so "the picture cannot affect the fight" is not a
## promise made in a comment. There is nothing here to affect it with.
##
## The one thing this decides is *presentation*: which way round a model has to
## be turned so that a piece facing north on the lattice looks north on screen.
## That is a fact about the models, which is this layer's business, and it is the
## same conversion `CharacterView.yaw_for_heading` already makes for a walker.
class_name CombatDiorama

## Which way a piece facing each of the lattice's four directions is walking, as
## the heading the rest of the render layer turns models by.
##
## The lattice's north is -z and a heading walks along `(cos h, sin h)` in
## `(x, z)`, so north is -pi/2 and each quarter turn clockwise adds a quarter of
## a circle: `(facing - 1) * pi/2`.
static func heading_for_facing(facing: int) -> float:
	return (float(((facing % 4) + 4) % 4) - 1.0) * (PI * 0.5)


## Whether a fight is on, according to the snapshot and nothing else.
static func is_fighting(snapshot: Dictionary) -> bool:
	return bool(_combat(snapshot).get("fighting", false))


## How many combatants the snapshot lists at all.
static func count(snapshot: Dictionary) -> int:
	return _rows(snapshot).size()


## Everything needed to draw the combatants, one row each, in the order the
## simulation listed them.
##
## Each row is
##
##     {"id", "tag", "kind", "commander", "fighting",
##      "position": Vector3, "heading": float, "state": Dictionary}
##
## `state` is in exactly the shape `CharacterView.clip_for` reads, so which clip
## a commander plays during a fight is decided by the same one rule that decides
## it for a walker -- there is no second animation rule for combat.
static func placements(snapshot: Dictionary) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	for row in _rows(snapshot):
		var fighting := bool(row.get("fighting", false))
		var commander := bool(row.get("commander", false))
		# A piece standing on a cell is turned by its facing; one walking the
		# world is turned by its heading. A minion has no facing at all, on the
		# board or off it, so it keeps the heading it walked in with.
		var heading := float(row.get("heading", 0.0))
		if fighting and commander:
			heading = heading_for_facing(int(row.get("facing", 0)))
		var health := int(row.get("health", 1))
		var most := maxi(1, int(row.get("max_health", 1)))
		made.append({
			"id": int(row.get("id", 0)),
			"tag": String(row.get("appearance", "")),
			"kind": String(row.get("kind", "")),
			"commander": commander,
			"fighting": fighting,
			"position": Vector3(
				float(row.get("x", 0.0)),
				float(row.get("y", 0.0)),
				float(row.get("z", 0.0)),
			),
			"heading": heading,
			"state": {
				# How fast the world says it is moving -- nothing while it
				# stands on a cell. Not worked out here from the phase: the
				# simulation already knows, so it says.
				"speed": float(row.get("speed", 0.0)),
				"rise": 0.0,
				"alive": health > 0,
				"hurt": health < most,
			},
		})
	return made


static func _rows(snapshot: Dictionary) -> Array:
	var rows: Variant = _combat(snapshot).get("pieces", [])
	return rows if rows is Array else []


static func _combat(snapshot: Dictionary) -> Dictionary:
	var combat: Variant = snapshot.get("combat", {})
	return combat if combat is Dictionary else {}
