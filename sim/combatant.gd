extends RefCounted
## A piece with a place in the continuous world.
##
## The board layer knows cells and nothing else: a `Piece` has a `cell`, and that
## is the whole of where it is. The overworld runs in real time on floating-point
## positions. This is the one object that is both -- a piece, and the world
## position that piece is standing at -- and it exists so that neither of the two
## layers has to learn the other's coordinates.
##
## Nothing here converts between the two. That arithmetic is `CombatSnap`'s, in
## one file, in two functions, so that "the snap onto the lattice" and "the snap
## back off it" are a pair that can be read together and checked against each
## other rather than two conversions written in two places.
##
## ## Real-time movement
##
## A combatant walks by a heading and a speed, once per tick, and is then put
## down on whatever surface is under it -- the same one-hop settle the observer
## uses, so a combatant walking into a floating island's rim is carried up onto
## it exactly as a walker is. There is no pursuit here, no fleeing and no
## steering: a heading is a number somebody set, and this only turns it into
## motion. What sets it is the scenario.
class_name Combatant

## A combatant that belongs to no band. Zero, so an unset band and an unset id
## are the same absence.
const NO_BAND := 0

## Which combatant this is, in the world. Assigned by the roster it is added to
## and stable for the combatant's whole life -- unlike the piece id, which is
## handed out afresh by the `PieceMap` of each fight and means nothing outside
## it. The two id spaces are separate on purpose: a fight is local, so the
## numbering inside one is local too.
var id: int = 0

## Which band it fights for: the world id of its commander, and its own id when
## it is a commander. This is what survives a fight -- the piece's `owner_id` is
## a piece id and is therefore only meaningful while a particular fight is on.
var band: int = NO_BAND

## What it is on a board. A `Commander` or a `Minion`, made once and carried for
## the combatant's whole life, so hit points taken off in one fight are still
## missing after it.
var piece: Piece = null

## Where it stands, in world units. The height is state rather than a lookup for
## the same reason the observer's is: there is more than one surface over a
## position, and what decides which one you are on is where you came from.
var x: float = 0.0
var z: float = 0.0
var y: float = 0.0

## Which way it walks, in radians, and how far it covers in one tick. Both are
## set by whoever put it in the world; nothing here changes either.
var heading: float = 0.0
var speed: float = 0.0

## Which cell it stands on while a fight is on, and whether it is in one at all.
## Outside a fight the cell means nothing and `fighting` says so.
var fighting: bool = false


## A commander standing in the world.
static func commander_at(
	at_x: float, at_z: float, looking: float, walking: float,
	level: int = 1, looks_like: String = AssetTags.KNIGHT,
) -> Combatant:
	var made := Combatant.new()
	made.piece = Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, looks_like, level)
	made.x = at_x
	made.z = at_z
	made.heading = looking
	made.speed = walking
	return made


## A minion standing in the world, fighting for a band.
static func minion_at(
	of_kind: String, for_band: int,
	at_x: float, at_z: float, looking: float, walking: float, level: int = 1,
) -> Combatant:
	var made := Combatant.new()
	made.piece = Minion.of_kind(of_kind, Piece.NO_OWNER, Vector2i.ZERO, level)
	made.band = for_band
	made.x = at_x
	made.z = at_z
	made.heading = looking
	made.speed = walking
	return made


## Whether this is a commander -- the piece's own answer, forwarded, so there is
## no second place that could come to disagree about it.
func is_commander() -> bool:
	return piece != null and piece.is_commander()


## Whether it is still standing.
func is_alive() -> bool:
	return piece != null and piece.is_alive()


## Walk one tick along the heading and settle onto whatever is under it.
##
## A combatant in a fight does not walk: it is standing on a lattice cell and the
## match decides where it goes. That is one comparison here rather than a caller's
## responsibility, so no caller can forget it.
func walk(terrain: TerrainQuery) -> void:
	if fighting or speed == 0.0:
		return
	x += cos(heading) * speed
	z += sin(heading) * speed
	settle(terrain)


## Put it down on whatever is under it, allowing one hop up.
##
## The observer's rule, deliberately: an island's rim is placed within
## `TerrainQuery.HOP_HEIGHT` of the highest ground beneath it, so walking into
## that stretch carries you up onto it, and walking off the edge drops you back.
## Nothing here is physics -- the surface is looked up, not collided with.
func settle(terrain: TerrainQuery) -> void:
	var support := terrain.support_at(x, z, y)
	if support == -INF:
		y = terrain.wading_height_at(x, z, y)
		return
	y = support


## How far away another combatant is across the ground, ignoring height. What the
## engagement rule and the join radius are both measured in.
func distance_to(other: Combatant) -> float:
	return Vector2(x - other.x, z - other.z).length()


## How far away a world position is across the ground.
func distance_from(at_x: float, at_z: float) -> float:
	return Vector2(x - at_x, z - at_z).length()


## One line describing it, in the form the reports and the tests compare.
##
## Positions are rendered at fixed precision so that a transcript does not
## depend on how floats happen to print.
func line() -> String:
	return "#%d %s band=%d at (%.3f, %.3f, %.3f) hp=%d/%d %s" % [
		id, piece.kind_name(), band, x, y, z,
		piece.health, piece.max_health(),
		"cell (%d,%d)" % [piece.cell.x, piece.cell.y] if fighting else "walking",
	]
