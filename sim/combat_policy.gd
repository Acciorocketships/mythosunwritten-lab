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
##   1. **Close.** Move to a cell it could swing at the nearest enemy commander
##      from, and failing that to the reachable cell nearest to it -- and only if
##      that is strictly nearer than standing still. Standing still is right only
##      when it can already strike from where it is: a commander that stopped as
##      soon as it was *adjacent* would stop diagonally opposite somebody it can
##      only strike in front of, and the fight would run to the round limit with
##      neither of them able to reach.
##   2. **Turn.** Face the nearest enemy piece. Turning is free, so this costs
##      nothing and is done every turn.
##   3. **Swing.** Of the held weapon's attacks that are off cooldown, use the
##      one covering the most enemy pieces, and only if that is at least one --
##      and only for a commander that has no decision function of its own, since
##      one that has already spent this turn's weapon action, or chose not to.
##   4. **Send one minion.** Prefer a capture or a strike, commanders first;
##      failing that, step the minion that can get nearest an enemy commander.
##
## Distance is read as a pair -- king steps first, then city blocks (`_nearness`)
## -- because the two halves of the board move in two different metrics: a
## commander with a diagonal granted moves like a king, and one with nothing
## granted moves one cardinal step, which can never cut a king distance to
## somebody standing diagonally away. Reading only the first of the two is what
## used to leave a bare commander standing still for a whole fight.
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
	# Already able to strike from where it stands: it does not shuffle.
	if _reaches_from(me, me.cell, quarry.cell):
		return
	var best := me.cell
	var best_near := _nearness(me.cell, quarry.cell)
	var best_reaches := false
	for cell in LegalMoves.moves_for(played.board, played.pieces, me):
		var near := _nearness(cell, quarry.cell)
		var reaches := _reaches_from(me, cell, quarry.cell)
		if reaches and not best_reaches:
			# The first cell it could actually swing from beats any amount of
			# merely being nearer.
			best_reaches = true
			best_near = near
			best = cell
			continue
		if reaches == best_reaches and _closer(near, best_near):
			best_near = near
			best = cell
	if best != me.cell:
		played.move_commander(best)


## How near one cell is to another, as the pair of distances a chooser has to
## read together: king steps first, then city blocks.
##
## Chebyshev alone is the wrong metric for half the pieces on the board. It is
## the number of *king* steps, and a commander only moves like a king once armour
## has granted it a diagonal (section 3.4); with nothing granted it moves one
## cardinal step, and no single cardinal step reduces the Chebyshev distance to
## something standing diagonally away. A chooser reading only Chebyshev therefore
## finds no move that is "strictly nearer", stands still, and the fight runs to
## `Encounter`'s round limit with neither commander ever in reach -- which is
## exactly what an ordinary world's first fight did on three seeds in ten.
##
## Reading the two together fixes it without changing what a king does: a
## diagonal step still wins outright when it cuts the king distance, and a
## cardinal step is taken when it cuts the walking distance at equal king
## distance. Both fall to zero only at the target, so closing terminates.
static func _nearness(from: Vector2i, to: Vector2i) -> Vector2i:
	return Vector2i(_chebyshev(from, to), _manhattan(from, to))


## Whether one nearness beats another: fewer king steps, then fewer city blocks.
static func _closer(near: Vector2i, than: Vector2i) -> bool:
	if near.x != than.x:
		return near.x < than.x
	return near.y < than.y


## How many cardinal steps apart two cells are.
static func _manhattan(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)


## Whether a commander standing on a cell could strike another cell with
## something it is holding, at some facing.
##
## Cooldowns are deliberately not read: this decides where to *stand*, and a
## pattern that is waiting a turn is still the pattern that will reach from
## there. Every facing is tried because section 3.5 makes rotating free, which is
## the same reading `ActionEngine._attack` takes when it derives which attack a
## blow uses.
static func _reaches_from(me: Commander, from: Vector2i, to: Vector2i) -> bool:
	for index in me.attack_count():
		var attack := me.attack_at(index)
		if attack == null:
			continue
		for facing in 4:
			if attack.cells_from(from, facing).has(to):
				return true
	return false


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
