extends RefCounted
## Who is standing where, and what happens when one of them dies.
##
## A board says what the ground is; this says who is on it. The two are kept
## apart because a board is a reading of the world that two overlapping boards
## must agree on, while occupancy changes every turn -- folding pieces into the
## board would make a cell's contents depend on the fight rather than on the
## ground.
##
## ## Owners, and the king rule
##
## Every piece carries an owner. A commander owns itself: when it is added its
## owner is set to its own id, so "everything this commander owns" is one
## comparison and the commander is inside it. A minion carries the id of the
## commander it was summoned by.
##
## That is what makes section 3.3's king rule a single operation. `kill()` on a
## commander removes the commander and every piece owned by it, and returns all
## of them together -- there is no second pass over the board afterwards, and no
## moment in between in which the minions of a dead commander are still standing.
## Killing a minion removes that minion and nothing else, which is the same
## function taking the same path with a different answer to one question.
class_name PieceMap

## The id nothing has. Zero, so an unset owner and an unset id are the same
## absence.
const NO_PIECE := 0

# id -> Piece, and cell -> id. The second is derived from the first and is kept
# beside it rather than searched for, because legal-move generation asks "who is
# on this cell" once per cell of every ray.
var _pieces: Dictionary = {}
var _at: Dictionary = {}
var _next_id: int = 1


## Put a piece on the map, giving it an id. A commander is made its own owner.
## Returns the id, or NO_PIECE if the cell was already taken.
func add(piece: Piece) -> int:
	if _at.has(piece.cell):
		return NO_PIECE
	piece.id = _next_id
	_next_id += 1
	if piece.is_commander():
		piece.owner_id = piece.id
	_pieces[piece.id] = piece
	_at[piece.cell] = piece.id
	return piece.id


## The piece with an id, or null.
func piece_of(id: int) -> Piece:
	return _pieces.get(id, null)


## The piece standing on a cell, or null.
func piece_at(cell: Vector2i) -> Piece:
	var id: int = _at.get(cell, NO_PIECE)
	return null if id == NO_PIECE else _pieces[id]


## Whether anything stands on a cell.
func is_occupied(cell: Vector2i) -> bool:
	return _at.has(cell)


## Who owns whatever stands on a cell, or NO_PIECE for an empty one.
func owner_at(cell: Vector2i) -> int:
	var piece := piece_at(cell)
	return Piece.NO_OWNER if piece == null else piece.owner_id


## How many pieces are on the map.
func size() -> int:
	return _pieces.size()


## Every id, in ascending order, so anything walking the map walks it the same
## way in every process.
func ids() -> PackedInt32Array:
	var found := PackedInt32Array()
	for id in _pieces:
		found.append(id)
	found.sort()
	return found


## Every piece an owner owns, in id order. Includes the commander itself.
func owned_by(owner_id: int) -> Array[Piece]:
	var found: Array[Piece] = []
	for id in ids():
		var piece: Piece = _pieces[id]
		if piece.owner_id == owner_id:
			found.append(piece)
	return found


## Every minion an owner owns, in id order.
func minions_of(owner_id: int) -> Array[Piece]:
	var found: Array[Piece] = []
	for piece in owned_by(owner_id):
		if not piece.is_commander():
			found.append(piece)
	return found


## Move a piece to a cell. Returns false, and changes nothing, if the piece is
## unknown or the cell is taken by somebody else.
func move_piece(id: int, to: Vector2i) -> bool:
	var piece: Piece = _pieces.get(id, null)
	if piece == null:
		return false
	var sitting: int = _at.get(to, NO_PIECE)
	if sitting != NO_PIECE and sitting != id:
		return false
	_at.erase(piece.cell)
	piece.cell = to
	_at[to] = id
	return true


## Remove a piece and nothing else. Returns the ids removed -- one, or none.
func remove(id: int) -> PackedInt32Array:
	var removed := PackedInt32Array()
	var piece: Piece = _pieces.get(id, null)
	if piece == null:
		return removed
	_at.erase(piece.cell)
	_pieces.erase(id)
	removed.append(id)
	return removed


## Kill a piece, and with a commander everything that commander owns.
##
## Section 3.3's king rule, and it is one operation on purpose: the commander and
## its minions leave together, in the returned list, and there is no state in
## between in which some of them have gone and some have not.
func kill(id: int) -> PackedInt32Array:
	var piece: Piece = _pieces.get(id, null)
	if piece == null:
		return PackedInt32Array()
	if not piece.is_commander():
		return remove(id)
	var doomed := PackedInt32Array()
	for owned in owned_by(piece.owner_id):
		doomed.append(owned.id)
	if not doomed.has(id):
		doomed.append(id)
	doomed.sort()
	var removed := PackedInt32Array()
	for doomed_id in doomed:
		removed.append_array(remove(doomed_id))
	return removed


## Every piece written out, one line each, in id order. What a report prints and
## what a test compares.
func lines() -> PackedStringArray:
	var written := PackedStringArray()
	for id in ids():
		written.append((_pieces[id] as Piece).line())
	return written
