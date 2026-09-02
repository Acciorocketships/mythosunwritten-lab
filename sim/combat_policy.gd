extends RefCounted
## The smallest written-down rule that plays a turn, so that a fight started in
## the world reaches an end.
##
## This is not the minion AI of section 3.9, and it is not a decision interface
## for a player -- both of those are later work. It exists because a fight that
## begins in the overworld has to *finish* before the world can go back to real
## time, and something has to choose the moves. So it is deliberately the
## dullest possible chooser: four greedy steps in a fixed order, every tie broken
## by a stated ordering, nothing remembered between turns, and no random input
## anywhere. Two processes handed the same board play the same fight.
##
## ## The four steps of a turn, in order
##
##   1. **Close.** Move to the reachable cell that is nearest the nearest enemy
##      commander, and only if that is strictly nearer than standing still.
##   2. **Turn.** Face the nearest enemy piece. Turning is free, so this costs
##      nothing and is done every turn.
##   3. **Swing.** Of the held weapon's attacks that are off cooldown, use the
##      one covering the most enemy pieces, and only if that is at least one --
##      and only for a commander that has no decision function of its own, since
##      one that has already spent this turn's weapon action, or chose not to.
##   4. **Send one minion.** Prefer a capture or a strike, commanders first;
##      failing that, step the minion that can get nearest an enemy commander.
##
## Distance is Chebyshev on the lattice -- the number of king steps -- because
## that is the metric a commander with boots actually moves in, and a chooser
## measuring in a metric it cannot move in would walk into walls.
##
## ## Why it terminates
##
## Two commanders close until one is inside the other's attack pattern, and every
## landed blow takes at least `Damage.MINIMUM` off, so hit points fall
## monotonically once contact is made. It is still a greedy rule and not a proof:
## commanders separated by ground neither can cross would close and stop. That is
## why `Encounter` carries a stated round limit and reports having hit it, rather
## than this file promising something it cannot.
class_name CombatPolicy

## The distance beyond which "closer" stops being worth a move. A commander
## already in contact does not shuffle: it stands and swings.
const CONTACT := 1


## Play one whole turn of the active commander and end it.
##
## Everything it does goes through `CombatMatch`, so the turn budget is enforced
## by the match rather than trusted here -- a step this file gets wrong is
## refused and written into the transcript, not silently taken.
static func take_turn(played: CombatMatch) -> void:
	var me := played.active_commander()
	if me == null:
		played.end_turn()
		return
	_close(played, me)
	_turn_to_face(played, me)
	_swing(played, me)
	_send_a_minion(played, me)
	played.end_turn()


# --- The four steps -------------------------------------------------------


static func _close(played: CombatMatch, me: Commander) -> void:
	var quarry := _nearest_enemy_commander(played, me)
	if quarry == null:
		return
	var here := _chebyshev(me.cell, quarry.cell)
	if here <= CONTACT:
		return
	var best := me.cell
	var best_far := here
	for cell in LegalMoves.moves_for(played.board, played.pieces, me):
		var far := _chebyshev(cell, quarry.cell)
		if far < best_far:
			best_far = far
			best = cell
	if best != me.cell:
		played.move_commander(best)


static func _turn_to_face(played: CombatMatch, me: Commander) -> void:
	var target := _nearest_enemy_piece(played, me, me.cell)
	if target == null:
		return
	played.face(facing_towards(target.cell - me.cell))


static func _swing(played: CombatMatch, me: Commander) -> void:
	# A commander that chooses for itself has already had this turn to strike in:
	# the turn waited for its weapon action, and whether it swung, did something
	# else or never answered, the answer was its own. Swinging for it here would
	# be this file playing the fight over the top of the character, which is
	# exactly what it did before a chosen blow could land.
	if me.chooses_for_itself():
		return
	var turn := played.turn_number(me.id)
	var best_index := -1
	var best_covered := 0
	for index in me.attack_count():
		if not me.can_attack(index, turn):
			continue
		var covered := 0
		for cell in LegalMoves.attack_cells_on(played.board, me, index, turn):
			var standing := played.pieces.piece_at(cell)
			if standing != null and standing.owner_id != me.owner_id:
				covered += 1
		if covered > best_covered:
			best_covered = covered
			best_index = index
	if best_index >= 0:
		played.attack(best_index)


static func _send_a_minion(played: CombatMatch, me: Commander) -> void:
	var quarry := _nearest_enemy_commander(played, me)
	var best_id := PieceMap.NO_PIECE
	var best_cell := Vector2i.ZERO
	var best_score := -1
	var best_far := 0
	# Minions in id order, destinations in the lattice's own order, so two
	# equally good sends are decided the same way in every process.
	for minion in played.pieces.minions_of(me.owner_id):
		for cell in LegalMoves.destinations(played.board, played.pieces, minion):
			var standing := played.pieces.piece_at(cell)
			var score := 0
			if standing != null and standing.owner_id != me.owner_id:
				score = 2 if standing.is_commander() else 1
			var far := 0 if quarry == null else -_chebyshev(cell, quarry.cell)
			if score > best_score or (score == best_score and far > best_far):
				best_score = score
				best_far = far
				best_id = minion.id
				best_cell = cell
	# Nothing to take and no commander to close on: the minion stands. Without
	# this the greedy rule would still pick a destination -- the first in the
	# lattice's order -- and a fight already decided would end with a minion
	# having wandered to the far corner of the board for no reason.
	if best_id != PieceMap.NO_PIECE and (best_score > 0 or quarry != null):
		played.activate_minion(best_id, best_cell)


# --- Reading the board ----------------------------------------------------


## The facing that best matches an offset. Ties -- an exact diagonal -- go to the
## axis with the larger step, and then to north/south, which is a stated rule
## rather than whichever comparison happened to come first.
static func facing_towards(offset: Vector2i) -> int:
	if absi(offset.x) > absi(offset.y):
		return PieceGeometry.EAST if offset.x > 0 else PieceGeometry.WEST
	if offset.y == 0:
		return PieceGeometry.NORTH
	return PieceGeometry.SOUTH if offset.y > 0 else PieceGeometry.NORTH


## How many king steps apart two cells are.
static func _chebyshev(from: Vector2i, to: Vector2i) -> int:
	return maxi(absi(from.x - to.x), absi(from.y - to.y))


static func _nearest_enemy_commander(played: CombatMatch, me: Commander) -> Piece:
	return _nearest(played, me, me.cell, true)


static func _nearest_enemy_piece(played: CombatMatch, me: Commander, from: Vector2i) -> Piece:
	return _nearest(played, me, from, false)


## The nearest piece not owned by `me`, walking the map in id order so an exact
## tie goes to the lower id.
static func _nearest(
	played: CombatMatch, me: Commander, from: Vector2i, commanders_only: bool
) -> Piece:
	var found: Piece = null
	var best := 0
	for id in played.pieces.ids():
		var piece := played.pieces.piece_of(id)
		if piece == null or piece.owner_id == me.owner_id:
			continue
		if commanders_only and not piece.is_commander():
			continue
		var far := _chebyshev(from, piece.cell)
		if found == null or far < best:
			found = piece
			best = far
	return found
