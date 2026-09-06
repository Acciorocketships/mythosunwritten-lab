extends RefCounted
## The turn a person takes on the board: what is left of it, what is legal, and
## the five things that spend it.
##
## `sim/live_choice.gd` is where a person's choice goes in real time; this is the
## same seam for the other half of the world, where the unit of choice is a turn
## rather than a tick. It exists because the turn economy of section 3.6 does not
## fit through one `Action`: a turn buys a move, one weapon action and one minion
## activation, and `ControlLoop` lets a character choose once per turn, on
## purpose, because one that could choose twice would be spending a turn twice.
## So the three things a turn buys are spent here, against the match itself,
## exactly as `CombatPolicy` spends them for a commander a rule is playing.
##
## ## It holds no rule and answers no question of its own
##
## Every question below is forwarded and every answer is somebody else's:
##
##   * where the commander may step -- `LegalMoves.moves_for`;
##   * what an attack covers -- `LegalMoves.attack_cells_on`, from where the
##     commander stands, as it is facing, on the turn being played;
##   * whether an attack may be used yet and how long until it may be --
##     `Commander.can_attack` and `Commander.turns_until_ready`;
##   * where a minion may go -- `LegalMoves.destinations`, which is its move
##     cells and its capture cells together;
##   * what is left of the turn -- `CombatMatch.has_moved`, `has_acted` and
##     `has_spent_minion`, which are the flags the match refuses out of.
##
## Nothing is worked out twice and nothing is cached. A `BoardTurn` is made when
## somebody asks for one and dropped when they have used it, so it cannot go
## stale; ask again on the next frame and the answers are the fight's own on that
## frame.
##
## ## Every refusal is the match's own sentence
##
## The five doers hand back `{"ok": bool, "reason": String}`, and `reason` is
## `CombatMatch.last_refusal` -- the same words the match wrote into the fight's
## transcript. Nothing here decides that a move is illegal, that an attack is on
## cooldown or that a minion is not yours; it asks and repeats the answer.
##
## ## Turning is free, and this is where that is visible
##
## `turn_to()` goes to `CombatMatch.face`, which touches none of the three flags.
## So a person may turn as often as they like, before or after moving, and the
## cells an attack covers change under them -- section 3.5's facing, usable.
class_name BoardTurn

## The fight this turn is in.
var fight: Encounter = null

## The match being played in it.
var match_state: CombatMatch = null

## The combatant whose turn it is, as the world knows them.
var member: Combatant = null

## The same one as the piece standing on the board.
var me: Commander = null


## The turn standing right now for one character, or null.
##
## Null for every reason a person cannot act on a board: there is no fight, they
## are not in it, the fight has ended, or it is somebody else's turn. Asking is
## how the interface finds out whether there is a turn to draw controls for, so
## the four are one answer rather than four flags to be read in the right order.
static func of(scene: ActionScene, actor_id: int) -> BoardTurn:
	if scene == null or scene.fight == null or scene.fight.finished:
		return null
	var on := scene.fight
	if on.match_state == null:
		return null
	var acting := on.active_member()
	if acting == null or acting.id != actor_id or not acting.fighting:
		return null
	var standing := on.match_state.active_commander()
	if standing == null:
		return null
	var turn := BoardTurn.new()
	turn.fight = on
	turn.match_state = on.match_state
	turn.member = acting
	turn.me = standing
	return turn


# --- What is left of the turn ---------------------------------------------


## Which round is being played, which is also which turn of this commander's it
## is and what a cooldown is counted in.
func round_number() -> int:
	return match_state.round_number


## Whether the move has been spent.
func moved() -> bool:
	return match_state.has_moved()


## Whether the one weapon action has been spent.
func acted() -> bool:
	return match_state.has_acted()


## Whether the one minion activation has been spent.
func minion_spent() -> bool:
	return match_state.has_spent_minion()


## Where the commander is standing.
func cell() -> Vector2i:
	return me.cell


## Which way it is turned, as one of `PieceGeometry`'s four quarter turns.
func facing() -> int:
	return me.facing


## What that is called, in the word the transcript uses.
func facing_name() -> String:
	return CombatMatch.facing_name(me.facing)


# --- What is legal ---------------------------------------------------------


## Every cell the commander may step onto this turn, in the lattice's own order.
##
## What the loadout reaches, against this board and who is on it. Section 3.4's
## movement-as-armour is entirely in the answer: a commander in boots is offered
## the diagonals and one without is not, and this file cannot tell the difference.
func move_cells() -> Array[Vector2i]:
	return LegalMoves.moves_for(match_state.board, match_state.pieces, me)


## Every weapon action the commander holds, in the weapon's own order.
##
## One row each: `{"name", "ready", "remaining", "cooldown"}` -- what it is
## called, whether it may be used on this turn, how many turns until it may be,
## and how long its wait is in these hands. Read afresh; nothing is kept.
func attacks() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var turn := match_state.turn_number(me.id)
	for index in me.attack_count():
		var one := me.attack_at(index)
		if one == null:
			continue
		rows.append({
			"name": one.attack_name,
			"ready": me.can_attack(index, turn),
			"remaining": me.turns_until_ready(index, turn),
			"cooldown": me.cooldown_of(index),
		})
	return rows


## The cells one weapon action covers from where the commander stands, as it is
## facing. Empty for an index the commander does not have.
##
## Not filtered by what is standing in them: what a blow does to what it finds is
## `CombatResolution`'s, and showing a person the pattern before they choose is
## showing them the pattern.
func attack_cells(index: int) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if index < 0 or index >= me.attack_count():
		return none
	return LegalMoves.attack_cells_on(
		match_state.board, me, index, match_state.turn_number(me.id))


## This commander's minions still on the board, in the map's own id order.
##
## One row each: `{"id", "kind", "cell"}`.
func minions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for minion in match_state.pieces.minions_of(me.id):
		rows.append({
			"id": minion.id,
			"kind": minion.kind_name(),
			"cell": minion.cell,
		})
	return rows


## Everywhere one of them may end up this turn -- stepping or taking, which is
## one list because a minion activation is one or the other. Empty for a piece
## that is not one of this commander's minions.
func minion_cells(id: int) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	var minion := match_state.pieces.piece_of(id)
	if minion == null or minion.is_commander() or minion.owner_id != me.id:
		return none
	return LegalMoves.destinations(match_state.board, match_state.pieces, minion)


# --- The five things that spend it -----------------------------------------


## Step onto a cell. Spends the turn's move.
func step_to(to: Vector2i) -> Dictionary:
	return _answer(match_state.move_commander(to))


## Turn to face a direction. Spends nothing -- see the head of this file.
func turn_to(direction: int) -> Dictionary:
	return _answer(match_state.face(direction))


## Turn a quarter to the left, and to the right. Free, as `turn_to` is.
##
## Which four directions there are, and which one is a quarter to the left of
## which, is `PieceGeometry`'s and is asked here rather than counted again by
## whoever is pressing the key.
func turn_left() -> Dictionary:
	return turn_to(posmod(me.facing - 1, PieceGeometry.FACINGS.size()))


func turn_right() -> Dictionary:
	return turn_to(posmod(me.facing + 1, PieceGeometry.FACINGS.size()))


## Use one weapon action. Spends the turn's one action, unless it is refused.
func swing(index: int) -> Dictionary:
	var swung := match_state.attack(index)
	return _answer(bool(swung.get("ok", false)), swung)


## Send one minion to a cell, to step onto it or to take what is on it. Spends
## the turn's one minion activation.
func send(id: int, to: Vector2i) -> Dictionary:
	var sent := match_state.activate_minion(id, to)
	return _answer(bool(sent.get("ok", false)), sent)


## End the turn and pass the board on.
##
## The fight is waiting on this and on nothing else: `ActionScene.fight_step`
## plays no turn while one is a hand's, so until this is called the world goes on
## around a board that is standing still.
func finish() -> Dictionary:
	fight.hand_turn_over()
	return {"ok": true, "reason": ""}


# What the match said about what was just asked of it: whether it happened, and
# if not, the match's own sentence for why not.
func _answer(ok: bool, outcome: Dictionary = {}) -> Dictionary:
	var answer := outcome.duplicate()
	answer["ok"] = ok
	answer["reason"] = "" if ok else match_state.last_refusal
	return answer
