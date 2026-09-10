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
## Three things are decided here, and all three are *presentation*. Which way
## round a model has to be turned so that a piece facing north on the lattice
## looks north on screen -- a fact about the models, and the same conversion
## `CharacterView.yaw_for_heading` already makes for a walker. Whether a blow the
## record says was struck on some tick is still being struck now. And whether a
## blow the record says landed on some tick is still landing now. The last two
## are one question asked twice, and it is a question about how long the clip
## drawing it lasts: the simulation says which motion, on whom and when,
## `CharacterRig` says how long, and the subtraction is here.
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
		var swinging := striking(snapshot, int(row.get("id", 0)))
		var motion := String(swinging[0])
		var began := int(swinging[1])
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
				# And how far it went up: the simulation says, for the same
				# reason it says how fast.
				"rise": float(row.get("rise", 0.0)),
				# And whether what moved it was a jump. A jump across level
				# ground rises by nothing, so it cannot be read off the rise;
				# the world knows which action it resolved and says.
				"jumped": bool(row.get("jumped", false)),
				# Whether it is still standing: the simulation's own answer,
				# read out of the row like everything else here. Not
				# "its health is above zero" -- that was this file deciding
				# for itself what a health of nothing means, which is the one
				# rule of the fight it had kept a copy of. What being beaten
				# is is `Piece.is_alive`'s answer, and the snapshot carries it.
				"alive": bool(row.get("alive", true)),
				# And whether a blow is landing on it right now, out of the same
				# record the swing above comes out of. Not "it has less health
				# than it started with": that is a wound already taken, and it
				# stays true for the rest of the fight, so a commander scratched
				# once would flinch on every tick it was doing nothing else.
				"hurt": struck(snapshot, int(row.get("id", 0))) >= 0,
				# And whether it is in the middle of striking a blow, out of the
				# snapshot's own record of the blows struck: the motion tag the
				# attack carried, and the tick the record says it began on.
				"attack": motion,
				"attack_tick": began,
				# And what it has on, by slot, as the catalog names the
				# simulation already carries. Passed through untouched: which
				# hand a thing hangs in is CharacterView's decision.
				"equipped": row.get("equipped", {}),
			},
		})
	return made


## The motion a piece is in the middle of striking, out of the snapshot's record
## of blows, and the tick that blow began on -- `["", -1]` for a piece that is
## not striking one.
##
## Everything here is read out of the dictionary handed in. The blow already says
## who struck it, which fight it belongs to, which motion it is and which tick it
## began on -- `ActionScene.blows`, carried out by `CombatantRoster.blow_rows` --
## and the one thing added is the comparison: a blow is still being struck while
## fewer ticks have passed than the motion lasts. How long a motion lasts is the
## render layer's own answer and lives in `CharacterRig.MOTION_CLIPS`, beside the
## clip that plays it, because it *is* that clip's length.
##
## Only the striker's most recent blow is considered. A blow that has finished
## does not fall back to the one before it: the character has stopped swinging,
## not gone back to an older swing.
static func striking(snapshot: Dictionary, id: int) -> Array:
	var combat := _combat(snapshot)
	var struck: Variant = combat.get("blows", [])
	if not (struck is Array):
		return [CharacterView.NO_MOTION, -1]
	var tick_now := int(combat.get("tick", 0))
	var here := int(combat.get("fights_begun", 0))
	var rows: Array = struck
	for at in range(rows.size() - 1, -1, -1):
		var blow: Dictionary = rows[at]
		if int(blow.get("from", 0)) != id:
			continue
		if int(blow.get("fight", 0)) != here:
			continue
		var motion := String(blow.get("animation", CharacterView.NO_MOTION))
		var began := int(blow.get("tick", 0))
		var since := tick_now - began
		if since < 0 or since >= CharacterRig.motion_ticks(motion):
			return [CharacterView.NO_MOTION, -1]
		return [motion, began]
	return [CharacterView.NO_MOTION, -1]


## The tick a blow landed on a piece, while the flinch that draws it is still
## running -- `-1` for a piece nothing is hitting right now.
##
## The same shape as `striking` above and for the same reason: the record says
## who was hit and on which tick (`ActionScene.note_blow`'s `to` and `tick`), and
## the one thing added here is the comparison against how long the flinch lasts,
## which is `CharacterRig.HIT_TICKS` and is this layer's own answer because it is
## a clip's length.
##
## Only a blow that actually took something off counts. A swing that reached and
## did no damage happened, and the one it was aimed at has nothing to flinch
## from -- `dealt` is the world's own word for how much it took, and this reads
## it rather than working it out from two health figures.
##
## Only the most recent such blow is considered, as with a swing: a character is
## flinching from the blow that just landed, not from the one before it.
static func struck(snapshot: Dictionary, id: int) -> int:
	var combat := _combat(snapshot)
	var blows: Variant = combat.get("blows", [])
	if not (blows is Array):
		return -1
	var tick_now := int(combat.get("tick", 0))
	var here := int(combat.get("fights_begun", 0))
	var rows: Array = blows
	for at in range(rows.size() - 1, -1, -1):
		var blow: Dictionary = rows[at]
		if int(blow.get("to", 0)) != id or int(blow.get("dealt", 0)) <= 0:
			continue
		if int(blow.get("fight", 0)) != here:
			continue
		var landed := int(blow.get("tick", 0))
		var since := tick_now - landed
		return -1 if since < 0 or since >= CharacterRig.HIT_TICKS else landed
	return -1


static func _rows(snapshot: Dictionary) -> Array:
	var rows: Variant = _combat(snapshot).get("pieces", [])
	return rows if rows is Array else []


static func _combat(snapshot: Dictionary) -> Dictionary:
	var combat: Variant = snapshot.get("combat", {})
	return combat if combat is Dictionary else {}
