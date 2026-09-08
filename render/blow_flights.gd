extends RefCounted
## Turns the snapshot's blow record into flights to draw, and holds nothing.
##
## The seam the flying arrow hangs off is the same one the swing animation
## hangs off: `CombatantRoster.snapshot()` carries the world's own record of
## the most recent blows, and each row already says everything a flight needs
## -- the cell the attack began in (`from_cell`), the cell the record says it
## landed on (`to_cell`), which art says what it is (`sprite`), which motion
## says it happened (`animation`), whether it crossed the ground to get there
## (`movement`), and the tick it began on (`tick`). `flights()` is a pure
## function of one snapshot dictionary: it has no members, remembers nothing
## between calls, and never asks the simulation a question. Fired from the
## record, not from the fight.
##
## Three rules, all of them the record's own word honoured rather than a second
## guess at it:
##
##   * **An instant attack launches nothing.** The record's `movement` says
##     whether the effect crossed the ground; only the one value that means it
##     did makes a flight. A swing, a thrust and an area spell land where they
##     are aimed, and nothing flies.
##   * **The endpoints are the record's, verbatim.** Where an attack split or
##     homed, the resolution step already decided where it landed and wrote
##     `to_cell` down; this file copies the two cells and recomputes neither.
##     There is no shape, no rotation and no homing arithmetic here to disagree
##     with the simulation's.
##   * **The span is the motion's, by the same one rule the swing uses.** The
##     record says which tick a blow began on and which motion draws it; how
##     long that motion lasts is the render layer's own answer and lives in
##     `CharacterRig.MOTION_CLIPS`, which is exactly where `CombatDiorama`
##     reads the swing's length from. So the arrow leaves when the bow's
##     release starts and lands when it ends, and there is no second clock.
##
## One caveat, shared with the swing: the snapshot carries only the last few
## blows of the whole world, so in a very crowded fight a blow's row can leave
## the record while its flight is midway. The flight ends with the row, exactly
## as the swing does -- the picture does not keep a copy of the fight to finish
## the crossing from.
class_name BlowFlights

## The one value of the record's movement vocabulary that means the effect
## crossed the ground on its way -- `Attack.PROJECTILE`'s own spelling, read
## off the record rather than off the class, because the class is the
## simulation's. Every other movement launches nothing.
const TRAVELS := "projectile"


## Everything flying right now, one row each, oldest blow first.
##
## Each row is
##
##     {"key": String, "sprite": String, "animation": String,
##      "from_cell": Vector2i, "to_cell": Vector2i, "phase": float,
##      "from_height": float, "to_height": float}
##
## `key` names the blow the flight belongs to, unique within the run, so a
## caller keeping view nodes can tell a flight still crossing from a new one.
## `phase` is how far across it is, 0 leaving and 1 landed on the last tick the
## motion is still being drawn. The two heights are the ground the record's two
## cells carry pieces at, read off the snapshot's own piece rows -- the
## striker's for the start, the struck one's for the end when somebody is
## standing there, and the striker's again when nobody is.
static func flights(snapshot: Dictionary) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	var combat := _combat(snapshot)
	var struck: Variant = combat.get("blows", [])
	if not (struck is Array):
		return made
	var tick_now := int(combat.get("tick", 0))
	var here := int(combat.get("fights_begun", 0))
	for blow_row in (struck as Array):
		if not (blow_row is Dictionary):
			continue
		var blow: Dictionary = blow_row
		if String(blow.get("movement", "")) != TRAVELS:
			continue
		if int(blow.get("fight", 0)) != here:
			continue
		var animation := String(blow.get("animation", ""))
		var began := int(blow.get("tick", 0))
		var span := CharacterRig.motion_ticks(animation)
		var since := tick_now - began
		if since < 0 or since >= span:
			continue
		var from_cell := blow.get("from_cell", Vector2i.ZERO) as Vector2i
		var to_cell := blow.get("to_cell", Vector2i.ZERO) as Vector2i
		# The striker's own height anchors both ends: whoever is standing on a
		# cell says how high it is, and when nobody is, the striker's ground is
		# the nearest honest answer the snapshot holds.
		var struck_from := _height_of(combat, int(blow.get("from", 0)), 0.0)
		var from_height := _height_at(combat, from_cell, struck_from)
		made.append({
			"key": "%d:%d:%d" % [here, int(blow.get("from", 0)), began],
			"sprite": String(blow.get("sprite", "")),
			"animation": animation,
			"from_cell": from_cell,
			"to_cell": to_cell,
			# 0 on the tick the record says the blow began, 1 on the last tick
			# its motion is still drawn -- so the arrival is the swing's own
			# end, not a second reading of it.
			"phase": 1.0 if span <= 1 else float(since) / float(span - 1),
			"from_height": from_height,
			"to_height": _height_at(combat, to_cell, from_height),
		})
	return made


# The height the piece with an id stands at, or `fallback` for an id the
# snapshot no longer lists -- a striker can fall to a later blow while its own
# arrow is still crossing.
static func _height_of(combat: Dictionary, id: int, fallback: float) -> float:
	var rows: Variant = combat.get("pieces", [])
	if not (rows is Array):
		return fallback
	for piece_row in (rows as Array):
		if piece_row is Dictionary and int((piece_row as Dictionary).get("id", -1)) == id:
			return float((piece_row as Dictionary).get("y", fallback))
	return fallback


# The height a piece standing on a cell carries, or `fallback` when the cell is
# empty. Read off the snapshot's own piece rows and nothing else: the ground
# under a fight is wherever the simulation put the people on it.
static func _height_at(combat: Dictionary, cell: Vector2i, fallback: float) -> float:
	var rows: Variant = combat.get("pieces", [])
	if not (rows is Array):
		return fallback
	for piece_row in (rows as Array):
		if not (piece_row is Dictionary):
			continue
		var piece: Dictionary = piece_row
		if int(piece.get("cell_x", 2147483647)) != cell.x:
			continue
		if int(piece.get("cell_y", 2147483647)) != cell.y:
			continue
		if not bool(piece.get("fighting", false)):
			continue
		return float(piece.get("y", fallback))
	return fallback


static func _combat(snapshot: Dictionary) -> Dictionary:
	var combat: Variant = snapshot.get("combat", {})
	return combat if combat is Dictionary else {}
