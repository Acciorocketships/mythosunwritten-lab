extends RefCounted
## One local fight: who joined it, the board it is on, the match being played,
## and the way back out.
##
## The design's world model is a real-time overworld that snaps to a tactical
## board the instant combat begins and returns to real time when it resolves.
## This is that snap, in both directions, and the thing that holds the fight
## while it is on.
##
## ## Local means a radius, and the radius is here
##
## A fight does not stop the world. It takes a rectangle of ground and the
## combatants standing in it, and everything else -- the terrain streaming, the
## other characters walking, the observer, the water, the islands -- carries on
## stepping around it. What joins is decided once, at the moment of the snap, by
## one number:
##
##   * every combatant within `JOIN_RADIUS` world units of the commander that
##     triggered the fight joins it;
##   * except that a minion joins only if its commander did, because a minion
##     without its commander on the board is a piece with no king, and the king
##     rule of section 3.3 would have nothing to remove it with.
##
## Everything else is untouched. Not paused, not slowed, not consulted -- it does
## not learn that a fight is happening.
##
## ## The board is anchored on the commander that started it, not on a midpoint
##
## A board has to be told which storey it is about, and it is told by a height.
## A midpoint between two combatants is a position nobody is standing at, so the
## height there names no storey reliably -- over a floating island, a midpoint's
## height would have to match that island's top *at the midpoint*, which it does
## not in general. The commander's own position and height always name a storey,
## because that is the surface it was put down on. So the board is built there,
## and `BOARD_SPAN` is wider than `JOIN_RADIUS` so that everyone who joined is
## inside it with cells to spare.
##
## That is what makes a fight on a floating island's top use that island's board:
## nothing here tests for islands at all. It hands the terrain query a position
## and a height and the board layer resolves the storey, exactly as it does when
## an observer walks.
##
## ## Turn-based inside real time
##
## The world ticks on. Each tick the fight takes one whole turn -- one commander
## closes, turns, swings and sends a minion -- and after that turn every piece's
## world position is set from the cell it now stands on. So the fight is a
## turn-based match and is also, from outside, a thing happening in the world at
## a rate the world sets.
class_name Encounter

## How near the triggering commander a combatant has to be standing to be in the
## fight, in world units. Eight lattice cells.
const JOIN_RADIUS := 24.0

## Half the width of the board a fight is held on, in world units. Wider than
## `JOIN_RADIUS` by two cells on every side, so nobody who joined can be outside
## the board and the placement search has somewhere to go.
const BOARD_SPAN := 30.0

## The most rounds a fight may run before it is called.
##
## The move rule is greedy, not a proof: two commanders separated by ground
## neither can cross would close and then stand. Rather than let that hold the
## world in a fight forever, the fight is stopped and *says* it was stopped --
## `hit_the_limit` is in the transcript and in the report, so a stalled fight
## cannot be mistaken for a decided one.
const MAX_ROUNDS := 40

## Why a fight ended.
const DECIDED := "decided"
const LIMIT := "limit"
const REFUSED := "refused"

## The board this fight is on. Read once, at the snap, and not re-read: the
## ground does not change during a fight, and a board rebuilt mid-fight would be
## a second reading that could disagree with the cells pieces are standing on.
var board: CombatBoard = null

## The match being played on it.
var match_state: CombatMatch = null

## The combatants in the fight, in roster id order.
var members: Array[Combatant] = []

## Which combatant each piece of the match is, by piece id.
var by_piece: Dictionary = {}

## The world this fight is in, which is the whole of what this class needs in
## order to give the match a die: a fight's seed is the world's, folded with
## where on the map the fight is standing (`Damage.fight_seed_for`). Two fights
## in one world therefore roll differently because they are in different places,
## and replaying one rolls the same numbers again.
var world_seed: int = 0

## The combatant whose approach began it, and where the board was anchored.
var anchor_id: int = 0
var anchor_x: float = 0.0
var anchor_z: float = 0.0
var anchor_height: float = 0.0

## The whole transcript: the snap in, every turn, and the snap out.
var lines := PackedStringArray()

## How many whole turns have been played, and whether the fight is over.
var turns_played: int = 0
var finished := false
var ending := ""

## Whether the fight was refused because somebody could not be seated on the
## board. No match was started and nobody was moved.
var refused := false

# How much of the match's own transcript has been copied into `lines` already.
#
# It is a cursor rather than a mark taken at the top of `advance()` because a
# turn is no longer written entirely inside one: a commander that chooses its own
# weapon action has it resolved by `ActionEngine`, which writes to the match
# between one call to `advance()` and the next. Reading from a cursor is what
# keeps those lines in the fight's transcript instead of dropping them.
var _copied: int = 0

# How much of this fight's own transcript the world has been handed already.
#
# A second cursor, because a turn is no longer always written inside one call. A
# turn taken by hand is spent across many ticks and writes as it goes, so "what
# this call produced" stopped being the same thing as "what has not been said
# yet", and only the second of those is what the world's trace wants.
var _reported: int = 0


## Begin a fight around a commander.
##
## `candidates` is everyone in the world who could join, in roster id order.
## The encounter always comes back so that its transcript can be read; when
## nobody could be seated it comes back with `refused` set, no match started and
## nobody moved. That is the stop condition of the task that built this: the case
## is reported rather than worked around by nudging anyone.
static func begin(
	terrain: TerrainQuery,
	candidates: Array[Combatant],
	anchor: Combatant,
	radius: float = JOIN_RADIUS,
	span: float = BOARD_SPAN,
) -> Encounter:
	var fight := Encounter.new()
	fight.world_seed = terrain.world_seed
	fight.anchor_id = anchor.id
	fight.anchor_x = anchor.x
	fight.anchor_z = anchor.z
	fight.anchor_height = anchor.y
	fight.members = joiners(candidates, anchor, radius)

	var builder := CombatBoardBuilder.new(terrain)
	fight.board = builder.build(anchor.x, anchor.z, anchor.y, span)
	fight.lines.append(
		"snap-in around #%d at (%.3f, %.3f, %.3f) radius=%.1f span=%.1f storey=%d joined=%d"
		% [
			anchor.id, anchor.x, anchor.y, anchor.z, radius, span,
			fight.board.anchor_storey, fight.members.size(),
		])
	fight.lines.append("snap-in board %s cells=%d standable=%d holes=%d cliffs=%d" % [
		fight.board.digest(), fight.board.cell_count(),
		fight.board.standable_count(), fight.board.hole_count(),
		fight.board.cliff_edge_count(),
	])

	var seating := CombatSnap.place(fight.board, fight.members)
	fight.lines.append_array(seating["lines"])
	if not bool(seating["ok"]):
		# Nobody is moved and no fight is held. Reporting the case is the whole
		# of what this branch does, on purpose.
		fight.lines.append("snap-in refused: %d combatant(s) could not be seated"
			% (seating["unplaced"] as PackedInt32Array).size())
		fight.finished = true
		fight.refused = true
		fight.ending = REFUSED
		return fight

	fight._seat(seating["placed"])
	return fight


## Who joins a fight around a commander: the radius, and the one exception to it.
static func joiners(
	candidates: Array[Combatant], anchor: Combatant, radius: float = JOIN_RADIUS
) -> Array[Combatant]:
	var bands := {}
	var near: Array[Combatant] = []
	for one in candidates:
		if not one.is_alive() or one.fighting:
			continue
		if one.distance_to(anchor) > radius:
			continue
		near.append(one)
		if one.is_commander():
			bands[one.band] = true
	var joined: Array[Combatant] = []
	for one in near:
		# A minion whose commander is out of the radius stays out with it: a
		# piece with no king on the board is one the king rule cannot remove.
		if one.is_commander() or bands.has(one.band):
			joined.append(one)
	return joined


# --- While the fight is on ------------------------------------------------


## Play one whole turn, then put every surviving piece back at the world
## position of the cell it now stands on.
##
## Returns the lines this turn added, so a caller stepping the world can
## interleave them with its own trace.
func advance() -> PackedStringArray:
	if finished:
		return PackedStringArray()
	CombatPolicy.take_turn(match_state)
	_turn_is_over()
	return unreported()


## End a turn somebody took for themselves, and wrap it up exactly as a turn the
## rule played is wrapped up.
##
## The other way a turn ends. `advance()` above hands the whole turn to
## `CombatPolicy` and the last thing that rule does is end it; a turn taken by
## hand is spent one call at a time -- a move, a swing, a minion, any number of
## free turns to face -- and ends when whoever is taking it says so. Both go
## through the same tail below, so a hand-played turn counts, carries and
## concludes on exactly the terms a played one does.
func hand_turn_over() -> PackedStringArray:
	if finished or match_state == null:
		return PackedStringArray()
	match_state.end_turn()
	return _turn_is_over()


## Mark everything written so far as already handed to the world.
##
## Called by whoever took a fight's opening lines out of `lines` directly --
## `ActionScene.begin_fight` does, because the snap-in has to reach the world's
## trace at the tick the fight began on, which may be between two of the ticks
## `unreported()` is asked on. Without it the snap-in would come back a second
## time the first time the world asked.
func mark_reported() -> void:
	_reported = lines.size()


## Everything this fight has written down that the world has not been handed yet,
## taken rather than read.
##
## The one seam between a fight's transcript and the world's trace. Whoever is
## stepping the world asks this once a tick, and gets what was written since the
## last time it asked -- whether that was written by the rule playing a turn, by
## a person spending one over several ticks, or by an attack the engine resolved
## between two of them. Reporting twice is what the cursor prevents.
func unreported() -> PackedStringArray:
	settle()
	var found := PackedStringArray()
	for at in range(_reported, lines.size()):
		found.append(lines[at])
	_reported = lines.size()
	return found


## Put every piece back where its cell says and hand over whatever the match has
## written since anyone last looked.
##
## What a fight that is waiting on somebody is stepped with. A turn taken by hand
## is spent across many ticks, and each thing spent in it moves pieces and writes
## lines; this is how those reach the world on the tick they happened on rather
## than all at once when the turn ends.
func settle() -> PackedStringArray:
	if match_state == null:
		return PackedStringArray()
	_carry_positions()
	var added := _uncopied()
	lines.append_array(added)
	return added


# The tail both ways of ending a turn share: one more turn played, everyone put
# back where their cells say, the match's own lines taken up, and the two
# conditions that end a fight asked.
func _turn_is_over() -> PackedStringArray:
	turns_played += 1
	var added := settle()
	if match_state.is_over():
		finished = true
		ending = DECIDED
	elif match_state.round_number > MAX_ROUNDS:
		finished = true
		ending = LIMIT
	return added


## Whose turn it is, as the combatant standing in the world, or null.
##
## `CombatMatch` counts turns in piece ids because that is what it has; a driver
## outside the fight knows people by their combatant ids. This is the one place
## the two are put together, and it reads the map the seating already built
## rather than searching for the piece again.
func active_member() -> Combatant:
	if match_state == null:
		return null
	return by_piece.get(match_state.active_id(), null)


## Who is still standing, in roster id order.
func survivors() -> Array[Combatant]:
	var standing: Array[Combatant] = []
	for one in members:
		if match_state.pieces.piece_of(one.piece.id) != null:
			standing.append(one)
	return standing


## Who fell, in roster id order.
func fallen() -> Array[Combatant]:
	var down: Array[Combatant] = []
	for one in members:
		if match_state.pieces.piece_of(one.piece.id) == null:
			down.append(one)
	return down


# --- The snap back out ----------------------------------------------------


## End the fight and hand the survivors back to the world.
##
## Every survivor is put at the world position its final cell corresponds to --
## the centre of that cell, at the height the board said that cell's surface is
## -- and is no longer on a lattice. Nothing is nudged and nothing is smoothed:
## the position a survivor stands at is `CombatSnap.world_of` of its own last
## cell, which is the exact position that would snap back to that same cell.
func conclude() -> PackedStringArray:
	lines.append_array(_uncopied())
	lines.append("over turns=%d rounds=%d ending=%s survivors=%d fallen=%d" % [
		turns_played, match_state.round_number, ending,
		survivors().size(), fallen().size(),
	])
	for one in members:
		var standing := match_state.pieces.piece_of(one.piece.id)
		one.fighting = false
		if standing == null:
			lines.append("snap-out #%d fell" % one.id)
			continue
		var back := CombatSnap.world_of(board, standing.cell)
		one.x = back.x
		one.y = back.y
		one.z = back.z
		lines.append(
			"snap-out #%d cell (%d,%d) -> (%.3f, %.3f, %.3f) back to cell (%d,%d) hp=%d/%d"
			% [
				one.id, standing.cell.x, standing.cell.y, back.x, back.y, back.z,
				CombatSnap.cell_for(back.x, back.z, board.cell_size).x,
				CombatSnap.cell_for(back.x, back.z, board.cell_size).y,
				standing.health, standing.max_health(),
			])
	return unreported()


# --- Setting the board out ------------------------------------------------


## Put the seated combatants onto a fresh piece map and start the match.
##
## Commanders go on first, in roster id order, because a `PieceMap` makes a
## commander its own owner as it is added -- so a minion's `owner_id` can only be
## filled in once its commander has an id. That ordering is the whole reason
## there are two passes here.
func _seat(placed: Dictionary) -> void:
	var pieces := PieceMap.new()
	var band_owner := {}
	for one in members:
		if not one.is_commander():
			continue
		one.piece.cell = placed[one.id]
		pieces.add(one.piece)
		band_owner[one.band] = one.piece.id
		by_piece[one.piece.id] = one
	for one in members:
		if one.is_commander():
			continue
		one.piece.cell = placed[one.id]
		one.piece.owner_id = int(band_owner.get(one.band, Piece.NO_OWNER))
		pieces.add(one.piece)
		by_piece[one.piece.id] = one
	match_state = CombatMatch.start(
		board, pieces, Damage.fight_seed_for(world_seed, anchor_x, anchor_z)
	)
	lines.append_array(_uncopied())
	for one in members:
		one.fighting = true
	_carry_positions()


# Everything the match has written since this was last asked, and nothing twice.
func _uncopied() -> PackedStringArray:
	var found := PackedStringArray()
	if match_state == null:
		return found
	for at in range(_copied, match_state.lines.size()):
		found.append(match_state.lines[at])
	_copied = match_state.lines.size()
	return found


## Put every piece still on the board at the world position of its cell.
##
## Called at the snap and after every turn, so a viewer reading the world sees
## the pieces standing on the lattice rather than where they were walking when
## the fight started. This is the same conversion the snap out uses; there is not
## a second one.
func _carry_positions() -> void:
	for one in members:
		var standing := match_state.pieces.piece_of(one.piece.id)
		if standing == null:
			# Fallen. Its cell is gone, so there is no position to carry; the
			# roster drops it when the fight concludes.
			continue
		var at := CombatSnap.world_of(board, standing.cell)
		one.x = at.x
		one.y = at.y
		one.z = at.z
