extends RefCounted
## Something standing on a cell of the board.
##
## The two tiers of section 3.3 -- minions and commanders -- are both this, and
## the differences between them are answers to questions asked here rather than
## two unrelated kinds of thing. A piece has an identity, an owner, a cell and an
## appearance tag, and it answers four questions about how it moves:
##
##   * the grants it moves by,
##   * the grants it captures by (a Toadstool's differ from its move; a
##     commander's are empty, because a commander kills with a weapon rather
##     than by walking onto someone),
##   * whether it has a facing,
##   * and whether it is a commander, which is what makes its death take a whole
##     army with it.
##
## It also carries the three numbers the resolution step reads -- a level, the
## hit points it has left, and the defence it stands behind -- and answers what a
## blow of its own is worth. Where those numbers come from differs by tier and is
## the subclasses' business: a minion's are a function of its level, a
## commander's health is a function of its level and its defence is the sum of
## what it is wearing. Nothing here computes damage; that is Damage's one seam.
class_name Piece

## No owner. A piece that belongs to nobody -- a wandering monster, before there
## is anything to own it.
const NO_OWNER := 0

## Which piece this is. Assigned by the PieceMap it is put on, unique there.
var id: int = 0

## Whose it is. A minion carries the id of the commander it despawns with; a
## commander carries its own id, so "the pieces this commander owns" is one
## comparison and includes the commander itself.
var owner_id: int = NO_OWNER

## Where it stands.
var cell := Vector2i.ZERO

## Battle strength, section 2. Drives a minion's health, defence and blow, and a
## commander's health.
##
## Where the number is *kept* is the tier's business, which is why this is a
## property over a pair of accessors and not a field. A minion's level is its
## own, in `_level` below. A commander's level is its character sheet's, and
## `Commander` points the accessors at the sheet -- so a commander and its
## character cannot hold two different levels, because there is one number and
## the piece has no copy of it.
var level: int = 1:
	set(to): _write_level(to)
	get: return _read_level()

## Hit points left. Set from `max_health()` whenever the level is set, so a
## piece is never born wounded. Kept wherever the level is kept, for the same
## reason.
var health: int = 0:
	set(to): _write_health(to)
	get: return _read_health()

# Where a piece that keeps its own numbers keeps them. Reached only through the
# four accessors below, so that a tier can keep them somewhere else.
var _level: int = 1
var _health: int = 0

## What it looks like: an AssetTags tag, never a model. The render layer's table
## turns it into something on a screen; nothing here knows what.
var appearance: String = ""


## Set the level, and refill to the health that level gives.
##
## One function, so a level can never be changed without the health that follows
## from it -- the alternative is two assignments at every call site and a piece
## that is half converted between them.
func set_level(to: int) -> Piece:
	level = maxi(1, to)
	health = max_health()
	return self


## Where the level is read from and written to. Overridden by the tier whose
## level belongs to a character sheet rather than to the piece.
func _read_level() -> int:
	return _level


func _write_level(to: int) -> void:
	_level = to


## Where the hit points are read from and written to. Overridden with the level,
## and for the same reason.
func _read_health() -> int:
	return _health


func _write_health(to: int) -> void:
	_health = to


## The hit points this piece has at full. Overridden by both tiers.
func max_health() -> int:
	return 1


## What is subtracted from a blow landing on it. Overridden by both tiers.
func defence() -> int:
	return 0


## What one blow of its own is worth before the target's defence. Zero for a
## commander, whose blows come off the weapon in its hands rather than off it.
func attack_power() -> int:
	return 0


## Whether it is still standing.
func is_alive() -> bool:
	return health > 0


## Take a number off it, floored at nothing left. Returns the health remaining.
func wound(by: int) -> int:
	health = maxi(0, health - maxi(0, by))
	return health


## The ways it may move onto an empty cell.
func move_grants() -> Array[MoveGrant]:
	return []


## The ways it may capture. For every piece whose move and capture are the same,
## this returns the same list; the Toadstool is where they part.
func capture_grants() -> Array[MoveGrant]:
	return move_grants()


## Whether the piece is turned to face a direction. False for every minion, true
## for every commander -- section 3.5 keeps the minion board clean.
func has_facing() -> bool:
	return false


## Whether this is a commander: the king of section 3.3, whose death despawns
## everything it owns.
func is_commander() -> bool:
	return false


## What sort of piece this is, in one word, for a report line and a failure
## message.
func kind_name() -> String:
	return "piece"


## One line describing the piece, in the form the reports and the tests compare.
func line() -> String:
	return "#%d %s owner=%d at (%d,%d)%s" % [
		id, kind_name(), owner_id, cell.x, cell.y,
		"" if not has_facing() else " facing=%d" % _facing_for_line(),
	]


## The numbers, in one line, in the form the reports and the tests compare.
##
## Kept apart from `line()` on purpose: `line()` says what a piece *is* and where
## it stands, which is what the piece layer's tests compare, and this says what
## it is worth, which is what this layer's do.
func stat_line() -> String:
	return "#%d %s owner=%d level=%d hp=%d/%d def=%d power=%d" % [
		id, kind_name(), owner_id, level, health, max_health(),
		defence(), attack_power(),
	]


## What `line()` prints for a facing. Overridden by the piece that has one.
func _facing_for_line() -> int:
	return PieceGeometry.NORTH
