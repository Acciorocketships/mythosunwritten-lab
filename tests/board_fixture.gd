extends RefCounted
## The piece suite's board, typed out one character per cell.
##
## The picture itself, and every rule for reading one, are BoardSketch's under
## `sim/` -- the scripted match the headless command plays stands on a sketch too,
## and one board-from-a-picture that both use is better than two that could drift
## apart. What is left here is the name the piece suite already calls it by and
## the glyphs that suite writes its map in.
##
## | glyph | height | the cell | what it tests |
## |---|---|---|---|
## | `.` | 0 | plain ground | everything |
## | `,` | -2 | a step down, and back up | a slider crossing a legal change of height |
## | `^` | +4 | ground too high to climb | a slider stopped by the board's step limit |
## | `~` | none | a hole | a slider stopped by a hole, a Frog crossing one |
## | `#` | 0 | a building | a slider stopped by an obstacle, a Frog crossing one |
##
## The two heights are chosen against the board's own constants rather than
## picked: -2 is exactly CombatBoard.STEP_DOWN, so it is the deepest legal step,
## and +4 is above CombatBoard.STEP_UP, so it is the shallowest illegal climb.
## If either constant moves, this fixture stops testing what it says it does, so
## the suite checks them.
class_name BoardFixture

const GROUND_HEIGHT := BoardSketch.GROUND_HEIGHT
const STEP_DOWN_HEIGHT := BoardSketch.STEP_DOWN_HEIGHT
const TOO_HIGH := BoardSketch.TOO_HIGH

const PLAIN := BoardSketch.PLAIN
const STEP := BoardSketch.STEP
const WALL_OF_EARTH := BoardSketch.WALL_OF_EARTH
const CHASM := BoardSketch.CHASM
const BUILDING := BoardSketch.BUILDING


## A board from a picture of one. Row 0 is the first string, and cell (x, y) is
## character x of row y, so the map reads the way it is written.
static func from_rows(rows: PackedStringArray, seed_value: int = 0) -> CombatBoard:
	return BoardSketch.from_rows(rows, seed_value)
