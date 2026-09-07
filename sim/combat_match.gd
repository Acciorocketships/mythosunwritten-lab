extends RefCounted
## The turn economy of section 3.6, for any number of commanders and no fixed
## sides.
##
## ## One round is one turn per commander
##
## Turn order is the commanders' ids, ascending, and a round is one pass down
## that list. Nothing anywhere counts to two, so nothing has to be changed to
## play three, or seven: the same loop that alternates two commanders rotates
## seven, and `round_number` advances when the pass wraps. Section 3.8's "no
## predefined teams" needs no support here because there is nothing here to
## support -- targeting and capture are decided one attacker against one target,
## by comparing two owner ids, and this class never groups an owner with another.
##
## ## What one turn buys
##
## Exactly three things, each once:
##
##   * **a move** for the commander, onto a cell its loadout reaches;
##   * **one weapon action**, which resolves against every piece in the pattern;
##   * **one minion**, for one move or one capture, and one minion only.
##
## Turning is free and is not one of the three: `face()` may be called any number
## of times and spends nothing, which is section 3.5's rule and is checkable here
## because the three flags below are the entire budget and `face()` touches none
## of them.
##
## Each of the three is a flag that is set when it is spent, and every entry
## point refuses when its flag is already set and changes nothing. "And no more"
## is therefore not a promise made in a comment: a second move returns false with
## the board untouched, and the suite asserts the board is untouched rather than
## just that false came back.
##
## An action that could not happen at all -- an attack still on its cooldown, a
## move to a cell the piece cannot reach -- does **not** spend its flag. Being
## refused is not the same as having acted.
##
## ## A cooldown is counted in rounds, because a turn *is* a round
##
## An attack's cooldown is in turns of the commander holding it, and this class
## carried a per-commander turn count to compare it against -- until the mutation
## check asked whether anything could tell that count apart from `round_number`.
## Nothing could, and nothing can: every living commander takes exactly one turn
## between two round increments, so the two numbers start equal at 1 and are
## incremented by the same passes forever. A three-turn cooldown is three of
## *your* turns and three rounds, and those are the same sentence.
##
## It would stop being the same sentence the moment a commander could join a
## match already in progress, or skip a turn, or take two. None of those exists,
## and when one does, the per-commander count comes back with a test that can see
## the difference. Keeping it now would be keeping a distinction the code does not
## make -- which is exactly what the piece layer's three movement modes turned out
## to be.
class_name CombatMatch

## The fight's own seed, which is the whole of what this class knows about the
## die settled in the items phase. `Damage.NO_DIE` plays the fight without one,
## which is what every exact-number check in the suite needs; a real fight is
## given a real seed by whoever begins it.
var fight_seed: int = Damage.NO_DIE

## The board the fight is on.
var board: CombatBoard = null

## Who is standing where.
var pieces: PieceMap = null

## Which round is being played. One round is one turn per living commander.
var round_number: int = 1

## The transcript. Every decision and every outcome, one line each, in the order
## they happened.
var lines := PackedStringArray()

## Which tick of the world outside the board this match is being played on.
##
## The board counts in turns and the world counts in ticks, and a blow struck on
## it has to be able to say which tick it began on -- a swing cannot be drawn
## without knowing when it started. Nothing in this class reads it: it is set by
## `ActionScene.advance`, the one place the world's clock moves, and by
## `ActionScene.begin_fight` for a board that appears part-way through a tick. A
## match nobody drives leaves it at zero, which is the honest answer for a fight
## that is not happening in any world.
var world_tick: int = 0

## Every blow struck in this match that nobody has taken away yet, oldest first.
##
## The one place the board says a blow happened, whoever asked for it: the same
## row is appended whether the turn was taken by a person through `BoardTurn`, by
## a character's own decision function through `ActionEngine`, or by the
## stand-in `CombatPolicy` plays for a commander nobody is driving. All three
## spend a weapon action through `attack()` below, so there is one record and not
## three.
##
## Ids in here are the board's -- piece ids -- because that is what this class
## counts in. `ActionScene` takes them away with `take_struck()`, puts them into
## the id space the world names people in, and writes them into its own `blows`.
## A match nobody drains simply keeps them.
var struck: Array[Dictionary] = []

# Commander ids in turn order, and the slot the active one sits in.
var _order := PackedInt32Array()
var _slot: int = 0
var _active: int = 0

# The whole of one turn's budget.
var _moved := false
var _acted := false
var _minion_spent := false

# Whether the conclusion has been written. A match reaches its end once.
var _concluded := false

## Why the last thing asked of this turn was refused, in the words the match
## wrote it down in, or "" when the last thing asked of it was allowed.
##
## The transcript already carries every refusal, and a caller reading the
## transcript to find out what just happened would be parsing prose. This is the
## same sentence, kept where the one who asked can read it back -- which is what
## a person choosing at a keyboard needs and what a rule choosing in a loop does
## not, since a rule is refused only when it has got something wrong.
var last_refusal := ""


## Begin a match on a board, with the pieces already placed.
static func start(
	on_board: CombatBoard, with_pieces: PieceMap, seed_value: int = Damage.NO_DIE
) -> CombatMatch:
	var match_state := CombatMatch.new()
	match_state.board = on_board
	match_state.pieces = with_pieces
	match_state.fight_seed = seed_value
	for id in with_pieces.ids():
		var piece := with_pieces.piece_of(id)
		if piece != null and piece.is_commander():
			match_state._order.append(id)
	match_state._slot = 0
	match_state._active = 0 if match_state._order.is_empty() else match_state._order[0]
	match_state._write_roster()
	match_state._write_turn_header()
	return match_state


# --- Who is playing -------------------------------------------------------


## Every commander still in the match, in turn order.
func commanders() -> PackedInt32Array:
	return _order.duplicate()


## How many commanders are still in.
func commander_count() -> int:
	return _order.size()


## Whose turn it is.
func active_id() -> int:
	return _active


## Whose turn it is, as a commander, or null when the match is over.
func active_commander() -> Commander:
	var piece := pieces.piece_of(_active)
	return piece as Commander if piece != null and piece.is_commander() else null


## Which turn a commander is on. The round, for the reason set out above: while
## every commander plays every round, one commander's turn count and the round
## number are the same number counted twice.
func turn_number(_id: int) -> int:
	return round_number


## Whether the match has reached a conclusion: one commander left, or none.
func is_over() -> bool:
	return _order.size() <= 1


## The last commander standing, or 0 while more than one is left.
func winner() -> int:
	return _order[0] if _order.size() == 1 else 0


# --- The three things a turn buys -----------------------------------------


## Turn to face a direction. Free -- not one of the three, and it spends none of
## them.
func face(direction: int) -> bool:
	var me := active_commander()
	if me == null:
		return false
	me.face(direction)
	_write("  face #%d %s" % [me.id, facing_name(me.facing)])
	return true


## Move the commander, once. False, and nothing changed, if it has already moved
## or cannot reach the cell.
func move_commander(to: Vector2i) -> bool:
	var me := active_commander()
	if me == null or _moved:
		var why := "no commander" if me == null else "already moved"
		_refused("move", _active, why)
		return false
	if not LegalMoves.moves_for(board, pieces, me).has(to):
		_refused("move", me.id, "(%d,%d) is not reachable" % [to.x, to.y])
		return false
	var from := me.cell
	pieces.move_piece(me.id, to)
	_moved = true
	last_refusal = ""
	_write("  move #%d (%d,%d)->(%d,%d)" % [me.id, from.x, from.y, to.x, to.y])
	return true


## The one weapon action. Resolves against every piece in the attack's pattern.
##
## An attack still on its cooldown is refused and does not spend the action --
## being unable to swing is not the same as having swung.
func attack(index: int) -> Dictionary:
	var me := active_commander()
	if me == null:
		return {"ok": false, "reason": "no commander"}
	if _acted:
		_refused("attack", me.id, "already acted this turn")
		return {"ok": false, "reason": "already acted"}
	var outcome := CombatResolution.commander_attack(
		board, pieces, me, index, turn_number(me.id), fight_seed
	)
	if not outcome.get("ok", false):
		_refused("attack", me.id, str(outcome.get("reason", "?")))
		return outcome
	_acted = true
	last_refusal = ""
	_write("  attack #%d %s cells=%d hits=%d" % [
		me.id, outcome["attack"], outcome["cells"], (outcome["hits"] as Array).size(),
	])
	for hit in outcome["hits"]:
		_write("    " + CombatResolution.describe_strike(hit))
	struck.append(_blow_of(me, index, outcome))
	_reap()
	return outcome


## Take every blow struck since the last time they were taken, leaving none.
##
## Taken rather than read, for the same reason `Encounter.unreported` takes its
## lines: a blow reported twice is two blows in whatever reads them.
func take_struck() -> Array[Dictionary]:
	var taken := struck
	struck = []
	return taken


# One blow, written down with everything the world outside the board needs to say
# it happened and everything a render layer needs to draw it.
#
# Nothing here is worked out: the cells are the ones the resolution step already
# covered, the facing and the cell are the commander's own, and the three tags --
# what the effect looks like, what it looks like happening, and whether it lands
# where it is aimed or crosses the ground to get there -- are the attack's own,
# out of `AssetTags`' vocabulary. This class invents no fact about a blow.
#
# The target is the first piece the pattern found, in the lattice's own order, and
# `hits` says how many it found in all. A swing that found nobody is still a blow:
# something happened, it is drawn, and it names no target.
func _blow_of(me: Commander, index: int, outcome: Dictionary) -> Dictionary:
	var attack := me.attack_at(index)
	var hits: Array = outcome["hits"]
	var dealt := 0
	for hit in hits:
		dealt += int(hit.get("dealt", 0))
	var first: Dictionary = hits[0] if not hits.is_empty() else {}
	return {
		"attacker": me.id,
		"target": int(first.get("target", PieceMap.NO_PIECE)),
		"attack": String(attack.attack_name),
		"dealt": dealt,
		"out_of": int(first.get("max_health", 0)),
		"hits": hits.size(),
		"facing": me.facing,
		"from_cell": me.cell,
		"to_cell": first.get("cell", me.cell),
		"cells": (outcome["covered"] as Array[Vector2i]).duplicate(),
		"sprite": String(attack.sprite_tag),
		"animation": String(attack.animation_tag),
		"movement": String(attack.movement),
		"cooldown": attack.cooldown,
		"round": turn_number(me.id),
		"tick": world_tick,
	}


## The one minion activation: one of this commander's minions, for one move or
## one capture. A second call in the same turn is refused and changes nothing.
func activate_minion(id: int, to: Vector2i) -> Dictionary:
	if _minion_spent:
		_refused("minion", id, "a minion has already acted this turn")
		return {"ok": false, "reason": "a minion has already acted"}
	var minion := pieces.piece_of(id)
	if minion == null or minion.is_commander():
		_refused("minion", id, "not a minion")
		return {"ok": false, "reason": "not a minion"}
	if minion.owner_id != _active:
		_refused("minion", id, "not commanded by #%d" % _active)
		return {"ok": false, "reason": "not yours"}
	if not LegalMoves.destinations(board, pieces, minion).has(to):
		_refused("minion", id, "(%d,%d) is not reachable" % [to.x, to.y])
		return {"ok": false, "reason": "unreachable"}

	_minion_spent = true
	last_refusal = ""
	var outcome := CombatResolution.minion_action(
		board, pieces, minion, to, fight_seed
	)
	outcome["ok"] = true
	_write("  minion " + CombatResolution.describe(outcome))
	_reap()
	return outcome


## End the turn and pass to the next commander, wrapping into the next round.
##
## A match that has reached its conclusion does not advance: the round the last
## commander fell in is the round the match ended in, and calling this again
## after that changes nothing and says nothing twice.
func end_turn() -> void:
	if is_over():
		if not _concluded:
			_concluded = true
			_write_conclusion()
		return
	var ending := _active
	_advance(ending)
	_moved = false
	_acted = false
	_minion_spent = false
	last_refusal = ""
	_write_turn_header()


# --- What is left of the turn ---------------------------------------------
#
# The three flags above are the whole budget, and these are the whole of the
# reading of them. They exist so that whoever is spending a turn -- a rule, or a
# person at a keyboard -- can be shown what is left of it without keeping a
# count of its own: a second copy of "have I moved yet" is a second copy that
# can be wrong.


## Whether this turn's move has been spent.
func has_moved() -> bool:
	return _moved


## Whether this turn's one weapon action has been spent.
func has_acted() -> bool:
	return _acted


## Whether this turn's one minion activation has been spent.
func has_spent_minion() -> bool:
	return _minion_spent


# --- Bookkeeping ----------------------------------------------------------


# Write a refusal into the transcript and keep its reason where the one who
# asked can read it back. One function so that the sentence in the transcript
# and the sentence handed back are the same sentence.
func _refused(what: String, id: int, why: String) -> void:
	last_refusal = why
	_write("  refused %s #%d: %s" % [what, id, why])


## Drop every commander that is no longer on the board, keeping the slot of the
## active one pointing at whoever comes next.
func _reap() -> void:
	for id in _order.duplicate():
		if pieces.piece_of(id) != null:
			continue
		var at := _order.find(id)
		if at < 0:
			continue
		# A commander removed from before the active one shifts it down a slot;
		# one removed *at* the active slot leaves that slot holding the next
		# commander, which is exactly where the turn after this one resumes.
		if at < _slot:
			_slot -= 1
		_order.remove_at(at)
		_write("  commander #%d is out" % id)


func _advance(ending: int) -> void:
	if _order.is_empty():
		_active = 0
		return
	var at := _order.find(ending)
	var next_slot := _slot if at < 0 else at + 1
	if next_slot >= _order.size():
		next_slot = 0
		round_number += 1
	_slot = next_slot
	_active = _order[_slot]


# --- The transcript -------------------------------------------------------


func _write(line: String) -> void:
	lines.append(line)


func _write_roster() -> void:
	_write("board %s cells=%d standable=%d holes=%d cliffs=%d" % [
		board.digest(), board.cell_count(), board.standable_count(),
		board.hole_count(), board.cliff_edge_count(),
	])
	_write("dice %s" % _dice_line())
	_write("commanders %d" % _order.size())
	for id in pieces.ids():
		_write("  " + pieces.piece_of(id).stat_line())


func _write_turn_header() -> void:
	var me := active_commander()
	if me == null:
		return
	_write("round %d turn #%d at (%d,%d) facing=%s hp=%d/%d def=%d %s" % [
		round_number, me.id, me.cell.x, me.cell.y,
		facing_name(me.facing), me.health, me.max_health(), me.defence(),
		me.loadout_line(),
	])


func _write_conclusion() -> void:
	_write("over rounds=%d survivors=%d winner=#%d" % [
		round_number, _order.size(), winner(),
	])


## What the fight's die is, in one line at the head of the transcript, so that
## every `swing=` below it -- or the absence of one -- can be read against a
## statement of whether there was a die at all.
func _dice_line() -> String:
	if fight_seed == Damage.NO_DIE:
		return "none"
	return "seed=%d swing=%d..%d" % [
		fight_seed, Damage.SWING_LOW, Damage.SWING_HIGH,
	]


## What a facing is called, in the word the transcript uses.
static func facing_name(facing: int) -> String:
	match facing:
		PieceGeometry.EAST:
			return "east"
		PieceGeometry.SOUTH:
			return "south"
		PieceGeometry.WEST:
			return "west"
	return "north"
