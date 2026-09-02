extends RefCounted
## What happens in a cell something reached: the two layers of section 3.7, and
## the shove.
##
## The whole of section 3.7's matrix is four pairings, and they are three
## functions here because one of the four is a different kind of thing:
##
## | attacker -> target | what happens | reads a level? |
## |---|---|---|
## | minion -> minion | `capture()` -- the target dies, the attacker takes the cell | no |
## | minion -> player | `strike()` with the minion's level-scaled power | yes |
## | player -> minion | `strike()` with the weapon's damage | yes |
## | player -> player | `strike()` with the weapon's damage | yes |
##
## **`capture()` reads nothing.** Not a level, not a hit point, not a defence,
## not a die. It removes the target and moves the attacker onto its cell, and
## those two operations are its entire body. That is what makes the tactical
## layer never spongy however far the numeric one has scaled: a level-1 Toadstool
## takes a level-40 Ent, and a level-40 Ent takes a level-1 Toadstool, by the
## same two lines of code.
##
## **`strike()` goes through the seam.** Every one of the three numeric pairings
## computes its modifier the same way and hands power, modifier and defence to
## the one seam on `Damage`. The three differ only in where the power comes from -- a
## minion's level, or the number on a weapon -- and in nothing else.
##
## **The die rides along as a fight seed and nothing more.** Section 13's roll
## model is settled on `Damage` and only there; what this file gained for it is
## one integer parameter carried from the match down to the seam. Nothing here
## draws a random number, decides a distribution, or branches on a roll -- the
## only thing this file knows about the die is which fight it belongs to. That is
## why `capture()` below could not accidentally acquire one: it never touches the
## seam, so there is nowhere for a seed to enter it.
##
## **A shove is an attack that pushes.** It is resolved here rather than as its
## own action because it *is* the same action: the same pattern, the same
## rotation by the wielder's facing, the same clip to the board, the same
## cooldown. What is different is what it does when it lands, and that is one
## branch at the end of `strike()`.
class_name CombatResolution

## What an outcome was.
const NOTHING := "nothing"
const MOVE := "move"
const CAPTURE := "capture"
const STRIKE := "strike"


# --- The tactical layer ---------------------------------------------------


## Minion takes minion. Binary, and level-blind.
##
## The captured minion dies, the attacker survives and takes its cell. Nothing
## in this function reads a level, a hit point or a defence, and nothing in it
## can fail on a number -- which is why no level gap can make it come out any
## other way.
static func capture(pieces: PieceMap, attacker: Piece, target: Piece) -> Dictionary:
	var cell := target.cell
	var removed := pieces.remove(target.id)
	pieces.move_piece(attacker.id, cell)
	return {
		"kind": CAPTURE,
		"attacker": attacker.id,
		"target": target.id,
		"cell": cell,
		"removed": removed,
	}


# --- The numeric layer ----------------------------------------------------


## One blow landing on one target, through the one seam.
##
## `power` is where the three player-facing pairings differ and the only place
## they differ: a minion hands in what its level is worth, a commander hands in
## what the attack on its weapon is worth. An attack whose power is zero -- a
## shove -- never reaches the seam at all.
static func strike(
	board: CombatBoard,
	pieces: PieceMap,
	attacker: Piece,
	target: Piece,
	power: int,
	push: int = 0,
	fight_seed: int = Damage.NO_DIE,
) -> Dictionary:
	var relation := Damage.relation(target, attacker.cell)
	var high := Damage.is_high_ground(board, attacker.cell, target.cell)
	var multiplier := Damage.multiplier_for(board, attacker, target)
	var defence := target.defence()
	# Rolled before the blow lands, so it reads the health the target had when it
	# was struck rather than the health this very blow leaves it on.
	var swing := Damage.swing_for(fight_seed, attacker, target, power)

	var dealt := 0
	if power > 0:
		dealt = Damage.resolve(power, multiplier, defence, swing)
		target.wound(dealt)

	var outcome := {
		"kind": STRIKE,
		"attacker": attacker.id,
		"target": target.id,
		"power": power,
		"multiplier": multiplier,
		"swing": swing,
		"rolled": fight_seed != Damage.NO_DIE,
		"relation": Damage.relation_name(relation),
		"high_ground": high,
		"defence": defence,
		"dealt": dealt,
		"health": target.health,
		"max_health": target.max_health(),
		"killed": false,
		"fell": false,
		"pushed": false,
		"pushed_to": target.cell,
		"removed": PackedInt32Array(),
	}

	if not target.is_alive():
		outcome["killed"] = true
		outcome["removed"] = pieces.kill(target.id)
		return outcome
	if push > 0:
		_push(board, pieces, attacker, target, push, outcome)
	return outcome


## Push a target away from its attacker, and see what it lands in.
##
## The direction is the sign of the offset from the attacker to the target, so a
## push is always directly away from whoever threw it whatever pattern the attack
## used -- there is no separate aiming step and nothing for a shove to target that
## an ordinary attack could not.
##
## Four things can be in the way, and they are checked in the order they matter:
## a hole swallows the target, a fall further than a piece can climb down kills
## it, anything solid or occupied stops the push dead, and otherwise it moves.
##
## **A push of `n` cells is those four checks applied `n` times, not once at the
## far end.** The target is walked one cell at a time and stops or dies at the
## first cell that stops or kills it, so nothing is carried over a chasm, a
## building, a pit or another piece by having been shoved harder. The cell the
## outcome names is therefore the cell the target actually ended in -- the last
## one it legally reached, or the one it died in -- and not the cell the push was
## aimed at.
static func _push(
	board: CombatBoard,
	pieces: PieceMap,
	attacker: Piece,
	target: Piece,
	distance: int,
	outcome: Dictionary,
) -> void:
	var away := target.cell - attacker.cell
	var direction := Vector2i(signi(away.x), signi(away.y))
	if direction == Vector2i.ZERO:
		return

	for _step in distance:
		var from: Vector2i = target.cell
		var to := from + direction
		# Off the board: there is no cell to ask about, so the push stops here.
		if not board.contains(to):
			return

		# Into a hole: water, a chasm, the void off an island's rim. Instant.
		if board.is_hole(to):
			outcome["killed"] = true
			outcome["fell"] = true
			outcome["pushed_to"] = to
			outcome["removed"] = pieces.kill(target.id)
			return
		# Into something solid, or into somebody: the push stops and nothing
		# further happens -- including the rest of the distance.
		if not board.is_standable(to) or pieces.is_occupied(to):
			return
		# Off a ledge deeper than a piece can climb down. The same comparison the
		# board flags a cliff edge with, asked in the one direction being pushed.
		if board.height_at(from) - board.height_at(to) > CombatBoard.STEP_DOWN:
			outcome["killed"] = true
			outcome["fell"] = true
			outcome["pushed_to"] = to
			outcome["removed"] = pieces.kill(target.id)
			return

		pieces.move_piece(target.id, to)
		outcome["pushed"] = true
		outcome["pushed_to"] = to


# --- The two actions a piece takes ----------------------------------------


## A minion's single action: step onto a cell, take what is on it, or hit what
## is on it.
##
## Which of the three happens is decided by *what is standing there* and by
## nothing else. An empty cell is a move; another commander's minion is a
## capture; another commander is a strike, and the minion stays where it is
## because a commander is not a piece you take a cell from.
static func minion_action(
	board: CombatBoard,
	pieces: PieceMap,
	minion: Piece,
	to: Vector2i,
	fight_seed: int = Damage.NO_DIE,
) -> Dictionary:
	var target := pieces.piece_at(to)
	if target == null:
		var from := minion.cell
		pieces.move_piece(minion.id, to)
		return {"kind": MOVE, "attacker": minion.id, "from": from, "cell": to}
	if target.is_commander():
		return strike(
			board, pieces, minion, target, minion.attack_power(), 0, fight_seed
		)
	# The seed is not passed on, because there is nothing here to pass it to: a
	# capture takes no power, no defence and no die.
	return capture(pieces, minion, target)


## A commander's one weapon action: every piece standing in the attack's cells
## takes a blow, and the attack goes on its cooldown.
##
## There is no owner check. An area attack burns the attacker's own minions along
## with everybody else's, which is one rule fewer and is what stops a wide cheap
## pattern from being free. The attacker itself is the one exception, and only
## because a pattern that covered its own cell would otherwise be self-harm by
## arithmetic accident.
##
## Targets are taken as a list of ids *before* any of them is resolved, so a
## piece shoved into a cell later in the pattern is not hit twice, and a minion
## despawned by its commander's death partway through is simply gone when its
## turn in the list comes.
static func commander_attack(
	board: CombatBoard,
	pieces: PieceMap,
	commander: Commander,
	index: int,
	turn: int,
	fight_seed: int = Damage.NO_DIE,
) -> Dictionary:
	var attack := commander.attack_at(index)
	if attack == null:
		return {"ok": false, "reason": "no such attack"}
	if not commander.can_attack(index, turn):
		return {"ok": false, "reason": "on cooldown"}

	var cells := LegalMoves.attack_cells_on(board, commander, index, turn)
	var targets := PackedInt32Array()
	for cell in cells:
		var standing := pieces.piece_at(cell)
		if standing != null and standing.id != commander.id:
			targets.append(standing.id)

	commander.spend_attack(index, turn)

	var hits: Array[Dictionary] = []
	for id in targets:
		var target := pieces.piece_of(id)
		if target == null:
			continue
		hits.append(strike(
			board, pieces, commander, target, commander.damage_of(index),
			attack.push, fight_seed
		))
	return {
		"ok": true,
		"kind": STRIKE,
		"attacker": commander.id,
		"attack": attack.attack_name,
		"cells": cells.size(),
		"hits": hits,
	}


# --- Writing an outcome down ----------------------------------------------


## One outcome as one line, in the form the transcript and the tests compare.
static func describe(outcome: Dictionary) -> String:
	match str(outcome.get("kind", NOTHING)):
		MOVE:
			var from: Vector2i = outcome["from"]
			var to: Vector2i = outcome["cell"]
			return "move #%d (%d,%d)->(%d,%d)" % [
				outcome["attacker"], from.x, from.y, to.x, to.y,
			]
		CAPTURE:
			var at: Vector2i = outcome["cell"]
			return "capture #%d takes #%d at (%d,%d)" % [
				outcome["attacker"], outcome["target"], at.x, at.y,
			]
		STRIKE:
			return describe_strike(outcome)
	return "nothing"


## One blow written out with every number that produced it, so that a transcript
## can be read as an argument rather than as a result.
static func describe_strike(hit: Dictionary) -> String:
	var swing := " swing=%d" % hit["swing"] if hit["rolled"] else ""
	var line := "hit #%d->#%d power=%d x%d%s %s%s def=%d dealt=%d hp=%d/%d" % [
		hit["attacker"], hit["target"], hit["power"], hit["multiplier"], swing,
		hit["relation"], " high" if hit["high_ground"] else "",
		hit["defence"], hit["dealt"], hit["health"], hit["max_health"],
	]
	if hit["fell"]:
		var into: Vector2i = hit["pushed_to"]
		line += " shoved into (%d,%d) removed=%d" % [
			into.x, into.y, (hit["removed"] as PackedInt32Array).size(),
		]
	elif hit["killed"]:
		line += " dead removed=%d" % (hit["removed"] as PackedInt32Array).size()
	elif hit["pushed"]:
		var to: Vector2i = hit["pushed_to"]
		line += " pushed to (%d,%d)" % [to.x, to.y]
	return line
