extends RefCounted
## A board typed out as a picture, one character per cell.
##
## The board layer reads the generated world, and that is what it is tested
## against. A scripted fight needs something else: ground whose every feature is
## where the scenario says it is, so that an expected number can be written down
## rather than hunted for. That is what this is -- the same CombatBoard the
## builder produces, filled in from rows of glyphs by the same comparisons
## against the same constants.
##
## | glyph | height | the cell |
## |---|---|---|
## | `.` | 0 | plain ground |
## | `,` | -2 | a step down, and back up: exactly CombatBoard.STEP_DOWN |
## | `^` | +4 | ground too high to climb, and a face that stops a line |
## | `v` | -8 | the floor of a pit: standable, but a fall to get into |
## | `~` | none | a hole -- water, or the void off an island |
## | `#` | 0 | a building: no piece in it, no line through it |
##
## The two shallow heights are chosen against the board's own constants rather
## than picked: -2 is exactly `CombatBoard.STEP_DOWN`, the deepest legal step,
## and +4 is above `CombatBoard.STEP_UP`, the shallowest illegal climb. The pit
## floor is deeper than `CombatBoard.CLIFF_DROP` so that the cells around it come
## out flagged as cliff edges -- by the drop comparison, not by the glyph.
##
## It lives under `sim/` rather than under `tests/` because the scripted match
## the headless command plays stands on one, and `sim/` may not read `tests/`.
class_name BoardSketch

const GROUND_HEIGHT := 0.0
const STEP_DOWN_HEIGHT := -2.0
const TOO_HIGH := 4.0
const PIT_FLOOR := -8.0

const PLAIN := "."
const STEP := ","
const WALL_OF_EARTH := "^"
const PIT := "v"
const CHASM := "~"
const BUILDING := "#"


## A board from a picture of one. Row 0 is the first string, and cell (x, y) is
## character x of row y, so the map reads the way it is written.
static func from_rows(rows: PackedStringArray, seed_value: int = 0) -> CombatBoard:
	var deep := rows.size()
	var across := 0 if deep == 0 else rows[0].length()
	var board := CombatBoard.new()
	board.world_seed = seed_value
	board.shape(Vector2i.ZERO, across, deep, CombatBoard.CELL_SIZE)
	board.anchor_cell = Vector2i(across / 2, deep / 2)
	board.anchor_height = GROUND_HEIGHT
	board.anchor_storey = CombatBoard.GROUND_STOREY

	for y in deep:
		for x in across:
			var cell := Vector2i(x, y)
			var glyph := rows[y].substr(x, 1)
			var flags := flags_of(glyph)
			var drop := drop_at(rows, cell)
			# A cell whose ground falls away by more than a step is one a piece
			# can be shoved off, by the same comparison the real builder makes.
			if (flags & CombatBoard.STANDABLE) != 0 and drop > CombatBoard.CLIFF_DROP:
				flags |= CombatBoard.CLIFF_EDGE
			board.put(
				cell, flags, height_of(glyph), storey_of(glyph), 0, drop,
			)
	return board


## What a glyph is, in the board's own flag words.
static func flags_of(glyph: String) -> int:
	match glyph:
		PLAIN, STEP, PIT:
			return CombatBoard.STANDABLE
		WALL_OF_EARTH:
			# Standable in itself -- there is ground up there -- but a face this
			# much taller than what is beside it stops a line, exactly as the
			# builder marks one read off the generated world.
			return CombatBoard.STANDABLE | CombatBoard.BLOCKS_LINE
		CHASM:
			return CombatBoard.HOLE | CombatBoard.BLOCKS_MOVE
		BUILDING:
			return CombatBoard.BLOCKS_MOVE | CombatBoard.BLOCKS_LINE
	return 0


static func height_of(glyph: String) -> float:
	match glyph:
		STEP:
			return STEP_DOWN_HEIGHT
		WALL_OF_EARTH:
			return TOO_HIGH
		PIT:
			return PIT_FLOOR
		CHASM:
			return -INF
	return GROUND_HEIGHT


static func storey_of(glyph: String) -> int:
	return CombatBoard.NO_STOREY if glyph == CHASM else CombatBoard.GROUND_STOREY


## The deepest fall from a cell to one of its four neighbours, by the same rule
## the real builder uses: infinite beside a hole, and nothing at all from a hole.
static func drop_at(rows: PackedStringArray, cell: Vector2i) -> float:
	var here := height_of(glyph_at(rows, cell))
	if here == -INF:
		return 0.0
	var deepest := 0.0
	for step in CombatBoard.NEIGHBOURS:
		var beside := cell + step
		if not inside(rows, beside):
			continue
		var neighbour := height_of(glyph_at(rows, beside))
		if neighbour == -INF:
			return INF
		deepest = maxf(deepest, here - neighbour)
	return deepest


static func glyph_at(rows: PackedStringArray, cell: Vector2i) -> String:
	return rows[cell.y].substr(cell.x, 1)


static func inside(rows: PackedStringArray, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= rows.size():
		return false
	return cell.x >= 0 and cell.x < rows[cell.y].length()
