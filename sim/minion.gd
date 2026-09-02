extends Piece
## A chess-piece unit: the clean, readable substrate of section 3.3.
##
## Four kinds, no facing, and no state beyond where it stands. A minion's legal
## moves are a function of the board and of who occupies it -- there is nothing
## else here for them to depend on, which is the point. The board's geometry and
## the occupancy of a handful of cells are the whole input, so a minion on a
## given board with a given occupancy has one answer whoever asks, in whatever
## order, however many times.
##
## | minion | analog | moves | captures |
## |---|---|---|---|
## | Toadstool | pawn | one cardinal cell | one diagonal cell |
## | Cat | bishop | diagonal lines until blocked | the same |
## | Ent | rook | cardinal lines until blocked | the same |
## | Frog | knight | an L-hop over anything | the same |
##
## The Toadstool is the one whose two patterns differ, and it differs without a
## facing: a chess pawn walks forwards because it has a front, and this one walks
## on all four cardinals because it does not. That is the whole of what removing
## facing from the minion tier costs and buys.
##
## The Frog is the piece the terrain reads differently for. Its hop consults
## nothing between launch and landing, so a wall, a village, a chasm and a wall
## of enemy minions are all the same to it -- which is what makes an enemy Frog
## the assassin the design says commanders cannot ignore.
class_name Minion

## The four, by name. These are what a minion *is*; the AssetTags tag of the same
## name is what it looks like, and the two are deliberately separate strings.
const TOADSTOOL := "toadstool"
const CAT := "cat"
const ENT := "ent"
const FROG := "frog"

## The four in a fixed order, for a report line and for a test that walks them.
const KINDS: Array[String] = [TOADSTOOL, CAT, ENT, FROG]

## Which of the four this is.
var kind: String = TOADSTOOL


## A minion of a kind, owned by a commander, standing on a cell, at a level.
##
## The level is the only number a minion has, and everything else -- what it can
## take, what it stands behind, what its blow is worth against a player -- is a
## function of it. Against another minion none of the three is read at all.
static func of_kind(of: String, owned_by: int, at: Vector2i, at_level: int = 1) -> Minion:
	var minion := Minion.new()
	minion.kind = of
	minion.owner_id = owned_by
	minion.cell = at
	minion.appearance = appearance_of(of)
	minion.set_level(at_level)
	return minion


## Level-scaled hit points. Read by a player's weapon and by nothing else: a
## capturing minion never asks.
func max_health() -> int:
	return Damage.minion_health(level)


## Level-scaled defence, read on the same one pairing as the health above.
func defence() -> int:
	return Damage.minion_defence(level)


## What this minion's blow is worth against a player, before that player's
## defence. Section 3.7's unbounded scaling axis.
func attack_power() -> int:
	return Damage.minion_power(level)


## The asset tag a kind wears. A tag, not a model: the render layer's one table
## decides what a Toadstool looks like, and this layer never learns.
static func appearance_of(of: String) -> String:
	match of:
		TOADSTOOL:
			return AssetTags.MINION_TOADSTOOL
		CAT:
			return AssetTags.MINION_CAT
		ENT:
			return AssetTags.MINION_ENT
		FROG:
			return AssetTags.MINION_FROG
	return ""


## The grants a kind moves by. Static, because it is a property of the kind and
## not of any minion standing anywhere.
static func move_grants_of(of: String) -> Array[MoveGrant]:
	match of:
		TOADSTOOL:
			return [MoveGrant.land(PieceGeometry.CARDINALS, TOADSTOOL)]
		CAT:
			return [MoveGrant.slide(PieceGeometry.DIAGONALS, MoveGrant.UNBOUNDED, CAT)]
		ENT:
			return [MoveGrant.slide(PieceGeometry.CARDINALS, MoveGrant.UNBOUNDED, ENT)]
		FROG:
			return [MoveGrant.land(PieceGeometry.KNIGHT_HOPS, FROG)]
	return []


## The grants a kind captures by. The same as its move for three of the four; the
## Toadstool's diagonal for the fourth.
static func capture_grants_of(of: String) -> Array[MoveGrant]:
	if of == TOADSTOOL:
		return [MoveGrant.land(PieceGeometry.DIAGONALS, TOADSTOOL)]
	return move_grants_of(of)


func move_grants() -> Array[MoveGrant]:
	return move_grants_of(kind)


func capture_grants() -> Array[MoveGrant]:
	return capture_grants_of(kind)


## No minion has a facing. Section 3.5, and the reason a minion's legal moves
## depend on the board and the occupancy and on nothing carried by the piece.
func has_facing() -> bool:
	return false


func kind_name() -> String:
	return kind
