extends RefCounted
## What a key press means during a turn on the board.
##
## The board's half of `render/player_controls.gd`, and the same discipline. That
## file turns a key into an `Action` out of the catalogue and resolves nothing;
## this one turns a key into one call on the turn the simulation is holding open
## (`BoardTurn`) and resolves nothing either. There is no legality here, no reach,
## no cooldown, no capture and no damage: where a piece may go, what a weapon
## covers, whether an action is ready and what a blow does are all the
## simulation's answers, asked through the turn and never worked out again.
##
## ## Why there is a second controls file at all
##
## In real time a person chooses one thing and the world carries it out over the
## ticks it costs. On a board a person spends a *turn*, and section 3.6 says a
## turn buys three things -- a move, one weapon action, one minion activation --
## plus as much turning as they like, because turning is free. Three things and a
## free one do not fit through one `Action`, and `ControlLoop` deliberately lets a
## character choose once per turn. So the three are spent against the match, which
## is exactly where `CombatPolicy` spends them for a commander a rule is playing.
##
## ## The keys
##
## Picking, which changes nothing in the world:
##
##   * **`[`** -- pick the next cell you may step onto.
##   * **`;`** -- pick the next of your minions. **`'`** -- pick the next cell
##     that minion may go to, whether that is a step or a capture; the board does
##     not offer those separately and neither does this.
##
## Spending, which does:
##
##   * **`]`** -- step onto the picked cell.
##   * **`\`** -- send the picked minion to the cell picked for it.
##   * **`4` `5` `6` `7`** -- use the first, second, third or fourth weapon
##     action. Pressing one that is still on its cooldown is refused by the
##     match, in the match's own words, rather than doing nothing quietly.
##   * **`8` / `9`** -- turn a quarter to the left or the right. Free: it spends
##     none of the three, and the cells a weapon covers move with it.
##   * **`0`** -- end your turn and pass the board on.
##
## ## What is picked is kept by identity
##
## A picked cell is a cell and a picked minion is an id, not a place in a list.
## So a cell that stops being reachable -- because the commander moved, or
## somebody stood on it -- is not silently replaced by whatever slid into its
## position: the pick falls back to the first cell on offer, which is a fresh
## pick and not a stale one pointing somewhere else.
class_name BoardControls

## Pick the next cell you may step onto, and step onto it.
const KEY_PICK_CELL := KEY_BRACKETLEFT
const KEY_STEP := KEY_BRACKETRIGHT

## Pick a minion, pick where it goes, and send it.
const KEY_PICK_MINION := KEY_SEMICOLON
const KEY_PICK_MINION_CELL := KEY_APOSTROPHE
const KEY_SEND := KEY_BACKSLASH

## The weapon actions, in the weapon's own order. Four because no item in the
## catalogue carries more, which is the same number the readout draws.
const SWING_KEYS := [KEY_4, KEY_5, KEY_6, KEY_7]

## Turning, which is free, and ending the turn, which is what the fight is
## waiting for.
const KEY_TURN_LEFT := KEY_8
const KEY_TURN_RIGHT := KEY_9
const KEY_END_TURN := KEY_0

## What no cell is: a pick that has not been made. A real cell can be anything,
## including the origin, so "none" is a flag rather than a coordinate.
var has_cell := false

## The cell picked to step onto, meaningful only while `has_cell`.
var cell := Vector2i.ZERO

## Which minion is picked, by the id the board knows it by, or zero.
var minion_id := 0

## Where that minion is picked to go, and whether that pick has been made.
var has_minion_cell := false
var minion_cell := Vector2i.ZERO

## What the last press could not do, in the interface's own words, or "".
##
## Never a refusal, exactly as on `PlayerControls`: a refusal is the simulation's
## answer to something it was asked to do, and is quoted from the answer it gave.
## This is the interface saying that nothing has been picked yet, so there was
## nothing to ask.
var note := ""


## Whether a key is one this file has anything to do with. Asked before a press
## is offered, so that a key which means something in real time keeps meaning it.
static func binds(keycode: int) -> bool:
	if SWING_KEYS.has(keycode):
		return true
	return [
		KEY_PICK_CELL, KEY_STEP, KEY_PICK_MINION, KEY_PICK_MINION_CELL,
		KEY_SEND, KEY_TURN_LEFT, KEY_TURN_RIGHT, KEY_END_TURN,
	].has(keycode)


## Spend one press out of a turn.
##
## Returns the simulation's own answer -- `{"ok", "reason", ...}` -- for a key
## that asked the turn for something, or an empty dictionary for one that only
## picked something or meant nothing here. A key that could not be asked because
## nothing is picked leaves `note` saying so and asks nothing.
func press(keycode: int, turn: BoardTurn) -> Dictionary:
	note = ""
	if turn == null:
		return {}
	var at := SWING_KEYS.find(keycode)
	if at >= 0:
		return turn.swing(at)
	match keycode:
		KEY_PICK_CELL:
			_pick_next_cell(turn)
			return {}
		KEY_PICK_MINION:
			_pick_next_minion(turn)
			return {}
		KEY_PICK_MINION_CELL:
			_pick_next_minion_cell(turn)
			return {}
		KEY_STEP:
			if not _keep_the_cell(turn):
				note = "no cell to step onto is picked"
				return {}
			return turn.step_to(cell)
		KEY_SEND:
			if minion_id == 0 or not _keep_the_minion_cell(turn):
				note = "no minion and cell are picked"
				return {}
			return turn.send(minion_id, minion_cell)
		KEY_TURN_LEFT:
			return turn.turn_left()
		KEY_TURN_RIGHT:
			return turn.turn_right()
		KEY_END_TURN:
			return turn.finish()
	return {}


# --- The three rings ------------------------------------------------------


func _pick_next_cell(turn: BoardTurn) -> void:
	var offered := turn.move_cells()
	if offered.is_empty():
		has_cell = false
		note = "there is nowhere to step onto"
		return
	var at := offered.find(cell) if has_cell else -1
	cell = offered[(at + 1) % offered.size()]
	has_cell = true


func _pick_next_minion(turn: BoardTurn) -> void:
	var mine := turn.minions()
	if mine.is_empty():
		minion_id = 0
		has_minion_cell = false
		note = "you have no minions on the board"
		return
	var at := -1
	for index in mine.size():
		if int((mine[index] as Dictionary)["id"]) == minion_id:
			at = index
			break
	minion_id = int((mine[(at + 1) % mine.size()] as Dictionary)["id"])
	has_minion_cell = false
	_pick_next_minion_cell(turn)


func _pick_next_minion_cell(turn: BoardTurn) -> void:
	if minion_id == 0:
		note = "no minion is picked"
		return
	var offered := turn.minion_cells(minion_id)
	if offered.is_empty():
		has_minion_cell = false
		note = "that minion has nowhere to go"
		return
	var at := offered.find(minion_cell) if has_minion_cell else -1
	minion_cell = offered[(at + 1) % offered.size()]
	has_minion_cell = true


# Whether the picked cell is still one of the cells on offer, picking the first
# on offer when it is not. A pick that has gone stale becomes a fresh pick rather
# than a coordinate nobody chose.
func _keep_the_cell(turn: BoardTurn) -> bool:
	var offered := turn.move_cells()
	if offered.is_empty():
		has_cell = false
		return false
	if not has_cell or not offered.has(cell):
		cell = offered[0]
		has_cell = true
	return true


func _keep_the_minion_cell(turn: BoardTurn) -> bool:
	var offered := turn.minion_cells(minion_id)
	if offered.is_empty():
		has_minion_cell = false
		return false
	if not has_minion_cell or not offered.has(minion_cell):
		minion_cell = offered[0]
		has_minion_cell = true
	return true


# --- What is on offer, for whoever is drawing it ---------------------------


## Every cell the interface should mark, keyed by what it means.
##
## Four lists, all of them the simulation's own answers: `"move"` is where the
## commander may step, `"reach"` is every cell its weapon actions cover from
## where it stands as it is facing, `"minion"` is where the picked minion may go,
## and `"picked"` is the one or two cells that are picked right now. Empty when
## there is no turn to draw.
static func marks(turn: BoardTurn, picked: BoardControls) -> Dictionary:
	var none: Array[Vector2i] = []
	if turn == null:
		return {"move": none, "reach": none, "minion": none, "picked": none}
	var reach: Array[Vector2i] = []
	for index in turn.attacks().size():
		reach.append_array(turn.attack_cells(index))
	var chosen: Array[Vector2i] = []
	if picked != null and picked.has_cell:
		chosen.append(picked.cell)
	if picked != null and picked.has_minion_cell:
		chosen.append(picked.minion_cell)
	return {
		"move": turn.move_cells(),
		"reach": reach,
		"minion": none if picked == null or picked.minion_id == 0 \
			else turn.minion_cells(picked.minion_id),
		"picked": chosen,
	}


## What is picked, in one line, for a readout and for a trace: the cell the next
## step would go to, and which minion would be sent where.
func picked_line() -> String:
	return "step %s %s to %s" % [
		_cell_line(has_cell, cell),
		"no unit" if minion_id == 0 else "#%d" % minion_id,
		_cell_line(has_minion_cell, minion_cell),
	]


static func _cell_line(picked: bool, at: Vector2i) -> String:
	return "none" if not picked else "(%d,%d)" % [at.x, at.y]


## What a person may press on the board and what it does, one line each, printed
## beside the real-time bindings so that whoever is at the keyboard is not
## guessing.
static func bindings() -> PackedStringArray:
	return PackedStringArray([
		"[            pick the next cell you may step onto",
		"]            step onto it",
		";            pick the next of your minions",
		"'            pick the next cell that minion may go to",
		"\\            send it there",
		"4 5 6 7      use the first, second, third or fourth weapon action",
		"8 / 9        turn a quarter left or right (free)",
		"0            end your turn",
	])
