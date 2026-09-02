extends RefCounted
## What a piece may legally do, worked out against the board and who is on it.
##
## One resolver for every piece in the game. It is handed a board, an occupancy
## map and a piece; it asks the piece for its grants and turns each of them into
## cells. There is no branch here that asks which minion it is holding or which
## weapon a commander wields -- a Cat is a slide along the diagonals, a Frog is a
## landing pattern over the L, a chestplate is a slide of two cells in eight
## directions, and all three go through the same two cases.
##
## ## The three rules, and where each one comes from
##
## **A landing must be reachable.** Every landing, of every kind of grant, is
## checked with `CombatBoard.can_step(from, to)` -- which is the terrain query's
## own walking constants: at most HOP_HEIGHT up, at most DROP_REACH down, and
## both cells standable. So a piece cannot climb more than the board's step, and
## what it may climb is the same fact as what a walker may climb rather than a
## second number kept here.
##
## **A slide is stopped by everything.** It walks out one cell at a time and
## stops at the board's edge, at ground it cannot climb onto, at a hole (which is
## not standable, so it is the same check), and at a piece -- taking that piece
## if it may be captured, and then still stopping. This is what makes the Cat and
## the Ent blockable, and blockable is what makes discovered attacks and choke
## control exist at all.
##
## **A landing consults nothing in between.** It checks where it arrives with
## exactly the same reach rule and never looks at the cells crossed. A wall, a
## village, a chasm and a wall of enemy minions are all equally irrelevant to it.
## That is one absence of a loop, not a special case: the Frog is the piece whose
## offsets are long enough for the absence to show. A king's step never reads the
## cells between either -- there are none.
##
## The reach rule applies to a landing however far away it is, and that is a
## decision rather than an oversight. The board is read on one storey, so a large
## drop across it is a cliff face; a Frog that ignored the reach rule could leap
## from the ground onto an island's top and out of the storey the board was read
## on.
## It crosses what is *between* -- gaps, walls, pieces, which is the niche the
## design gives it -- and still has to land somewhere a piece could stand.
class_name LegalMoves

## Where a slide stops if nothing else stops it first. A board is tens of cells
## across, so this is never the thing that ends a ray; it is here so an unbounded
## slide is a loop with a bound rather than a loop with a promise.
const MAX_SLIDE := 4096


## The cells a piece may move onto: empty cells, reachable by one of its move
## grants. Canonical.
static func moves_for(board: CombatBoard, pieces: PieceMap, piece: Piece) -> Array[Vector2i]:
	return _resolve(board, pieces, piece, piece.move_grants(), false)


## The cells a piece may capture on: cells holding a piece of another owner,
## reachable by one of its capture grants. Canonical.
static func captures_for(board: CombatBoard, pieces: PieceMap, piece: Piece) -> Array[Vector2i]:
	return _resolve(board, pieces, piece, piece.capture_grants(), true)


## Everywhere a piece may end up this move, whether by stepping or by taking.
static func destinations(board: CombatBoard, pieces: PieceMap, piece: Piece) -> Array[Vector2i]:
	return PieceGeometry.union([
		moves_for(board, pieces, piece), captures_for(board, pieces, piece),
	])


## The cells one of a commander's attacks covers, clipped to the board.
##
## Not filtered by anything else: what is standing in those cells, and what
## happens to it, is the resolution step's business. What this answers is the
## question this layer is for -- which cells the pattern reaches from where the
## commander stands, as it is facing.
static func attack_cells_on(
	board: CombatBoard, commander: Commander, index: int, turn: int = -1
) -> Array[Vector2i]:
	var on_board: Array[Vector2i] = []
	for cell in commander.attack_cells(index, turn):
		if board.contains(cell):
			on_board.append(cell)
	return PieceGeometry.canonical(on_board)


## Whether a piece could reach every cell of the board it stands on that anything
## could stand on.
##
## The stop condition of the task that built this layer: armour grants are a
## union with no cap, and if some loadout unions into "anywhere", the balancing
## lever is the item power budget rather than a quiet limit here -- so this is
## asked and reported rather than prevented.
static func reaches_every_standable_cell(
	board: CombatBoard, pieces: PieceMap, piece: Piece
) -> bool:
	var reachable := destinations(board, pieces, piece).size()
	# The cell the piece is standing on is standable and is not a destination.
	return reachable >= board.standable_count() - 1


static func _resolve(
	board: CombatBoard,
	pieces: PieceMap,
	piece: Piece,
	grants: Array[MoveGrant],
	taking: bool,
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for grant in grants:
		match grant.mode:
			MoveGrant.LAND:
				cells.append_array(_landings(board, pieces, piece, grant, taking))
			MoveGrant.SLIDE:
				cells.append_array(_rays(board, pieces, piece, grant, taking))
	return PieceGeometry.canonical(cells)


## Check where it arrives, and read nothing else. A king's step and a knight's
## leap both come through here, because the only difference between them is how
## long the offset is.
static func _landings(
	board: CombatBoard,
	pieces: PieceMap,
	piece: Piece,
	grant: MoveGrant,
	taking: bool,
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in grant.offsets:
		var to := piece.cell + offset
		if not board.can_step(piece.cell, to):
			continue
		if _admits(pieces, piece, to, taking):
			cells.append(to)
	return cells


static func _rays(
	board: CombatBoard,
	pieces: PieceMap,
	piece: Piece,
	grant: MoveGrant,
	taking: bool,
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var limit := MAX_SLIDE if grant.reach == MoveGrant.UNBOUNDED else grant.reach
	for direction in grant.offsets:
		var from := piece.cell
		for _step in limit:
			var to := from + direction
			if not board.can_step(from, to):
				break
			var standing := pieces.piece_at(to)
			if standing != null:
				# A piece ends the ray whether or not it can be taken. That is
				# the whole of what "blockable" means for a Cat and an Ent.
				if taking and standing.owner_id != piece.owner_id:
					cells.append(to)
				break
			if not taking:
				cells.append(to)
			from = to
	return cells


## Whether a destination cell admits this piece: empty when it is moving, held by
## somebody else's piece when it is taking.
static func _admits(pieces: PieceMap, piece: Piece, to: Vector2i, taking: bool) -> bool:
	var standing := pieces.piece_at(to)
	if taking:
		return standing != null and standing.owner_id != piece.owner_id
	return standing == null
