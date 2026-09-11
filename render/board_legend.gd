extends RefCounted
## What each colour the board paints on the ground means, and the table the
## board paints from.
##
## One table, read twice. `render/main.gd` asks it what colour a cell is and
## paints that; `render/ui/legend_panel.gd` asks it for the same rows and draws
## a swatch and a word for each. So the picture on the ground and the legend
## beside it cannot come to mean different things -- there is no second list of
## colours anywhere, and a colour added here appears in both places or in
## neither.
##
## It exists because a fight could be fought across a field of amber squares
## with nothing on screen saying that amber is a cliff edge, which is the one
## square that can cost a character its whole life.
##
## ## It decides nothing about the fight
##
## Every question this file asks is asked of the `CombatBoard` it is handed --
## `is_hole`, `blocks_move`, `is_cliff_edge`, `storey_at` -- and every answer is
## turned into a colour and into nothing else. There is no cliff rule here, no
## reach, no legality: the board is the simulation's and this is the palette it
## is drawn in. The board itself is a detached copy, which is the one combat
## handle the render layer is allowed (see `LayerCheck.FORBIDDEN_IN_RENDER`).
##
## ## The order is the rule
##
## A cell can be more than one of these at once -- a cliff edge one storey up is
## both -- so `LATTICE` is in the order a cell is tested and the first row that
## fits is the one it is painted in. That is also the order the legend is read
## in, so the legend reads top-down in the same order the painting decides.
class_name BoardLegend

## The five ways a piece of ground reads, and the four things offered to whoever
## is taking a turn, by the key each is known by here.
const HOLE := "hole"
const BUILT := "built"
const CLIFF := "cliff"
const AERIAL := "aerial"
const GROUND := "ground"

const MOVE := "move"
const REACH := "reach"
const MINION := "minion"
const PICKED := "picked"

## The lattice, in the order a cell is tested. Two close shades of blue for
## ground a piece may stand on, a paler cool tint one storey up, warm amber for a
## cliff edge it can be shoved off, dull red for something built on, and a dark
## plate at the anchor's own height for a hole -- water, or the void off an
## island's rim -- so a hole reads as a missing square rather than as nothing at
## all.
##
## `means` is short because it is drawn beside a swatch in a pixel font at
## fourteen pixels, and a legend that has to be scrolled is not a legend. What
## each one *costs* is the simulation's business and is not said here.
##
## ## Why one row carries two colours
##
## A row is *one meaning*. Ordinary ground is one meaning and is painted in two
## shades, because a field of squares all the same colour reads as one sheet
## however crisply its gutters are drawn -- which is what a board over a meadow
## looked like. `pair` is the second shade of a row that is checkered, chosen by
## the parity of the cell (`shade_of` below), and a row without one is painted in
## its own colour wherever it falls. So a cliff edge is amber on every cell it
## lands on and the checker cannot make one cell of a cliff read as another kind
## of ground: only the meaning decides the colour, and the parity decides no more
## than which of that meaning's two shades.
const LATTICE := [
	{"key": HOLE, "tint": Color(0.05, 0.07, 0.12, 0.44), "means": "no ground"},
	{"key": BUILT, "tint": Color(0.92, 0.36, 0.36, 0.5), "means": "built on"},
	{"key": CLIFF, "tint": Color(1.0, 0.66, 0.26, 0.52), "means": "a cliff edge"},
	{"key": AERIAL, "tint": Color(0.62, 0.92, 0.86, 0.34), "means": "one storey up"},
	{
		"key": GROUND,
		"tint": Color(0.70, 0.83, 1.0, 0.26),
		"pair": Color(0.34, 0.54, 0.94, 0.26),
		"means": "you may stand",
	},
]

## The cells offered to whoever is taking a turn, painted over the lattice, in
## the order they are painted: cool green for where the commander may step, warm
## rose for what its weapons cover from where it stands as it is facing, pale
## blue for where the picked minion may go, and a bright plate for whichever cell
## is picked right now. Painted last to first so the brighter, narrower answer is
## the one on top.
##
## Not one of the four is worked out here or in the file that paints them. Every
## cell in them comes back from `BoardControls.marks`, which asks the
## simulation's own turn; these are the colours those lists are painted in.
const OFFERS := [
	{"key": MOVE, "tint": Color(0.30, 1.0, 0.42, 0.62), "means": "you may step"},
	{"key": REACH, "tint": Color(1.0, 0.30, 0.40, 0.62), "means": "weapon covers"},
	{"key": MINION, "tint": Color(0.34, 0.68, 1.0, 0.62), "means": "minion may go"},
	{"key": PICKED, "tint": Color(1.0, 0.99, 0.70, 0.88), "means": "picked now"},
]

## How much stronger a square's outline is drawn than its fill, so a cliff edge
## reads as an edge and not only as a shade. Capped at opaque.
const EDGE_GAIN := 2.4


## Every colour the board paints on the ground, in the order it is painted:
## the lattice first, then what is offered over it. What the legend draws, and
## the only list of them there is.
static func rows() -> Array:
	var all := []
	all.append_array(LATTICE)
	all.append_array(OFFERS)
	return all


## Which of `LATTICE` a cell reads as, by the board's own answers. The last row
## is the one a cell that is none of the others falls to, which is ordinary
## ground.
static func lattice_key(board: CombatBoard, cell: Vector2i) -> String:
	for row in LATTICE:
		var key := String(row["key"])
		if _reads_as(key, board, cell):
			return key
	return String((LATTICE[LATTICE.size() - 1] as Dictionary)["key"])


## What colour a cell of the lattice is painted in: the colour of what it means,
## in whichever of that meaning's shades its own cell falls on.
static func tint_of(board: CombatBoard, cell: Vector2i) -> Color:
	return shade_of(lattice_key(board, cell), cell)


## Which shade of a meaning a particular cell is painted in.
##
## A row with no `pair` has one colour and every cell of it is painted that
## colour. A row with one is checkered: the parity of the cell's own coordinates
## picks the shade, so neighbours differ and a field of them reads as squares
## rather than as a sheet. The parity is of the cell and of nothing else -- not
## of where the board is, not of where the camera is -- so a square keeps its
## shade as the board is redrawn and as the observer walks across it.
static func shade_of(key: String, cell: Vector2i) -> Color:
	var row := row_for(key)
	if row.has("pair") and (cell.x + cell.y) % 2 != 0:
		return Color(row["pair"])
	return tint_for(key)


## The colour filed under a key, in either table, or transparent for a key that
## is in neither. One lookup, so a caller naming a colour names a row of the
## table rather than a `Color` of its own.
static func tint_for(key: String) -> Color:
	var row := row_for(key)
	if row.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(row["tint"])


## The row filed under a key, in either table, or an empty one for a key that is
## in neither.
static func row_for(key: String) -> Dictionary:
	for row in rows():
		if String((row as Dictionary)["key"]) == key:
			return row as Dictionary
	return {}


## Every shade a row is painted in, in the order they are the table's: one
## colour for a plain row and two for a checkered one. What the legend draws a
## swatch of, so a colour cannot be painted without being shown.
static func shades_of(row: Dictionary) -> Array[Color]:
	var shades: Array[Color] = [Color(row["tint"])]
	if row.has("pair"):
		shades.append(Color(row["pair"]))
	return shades


## The colour a square's outline is drawn in: its own fill, stronger.
static func edge_of(tint: Color) -> Color:
	return Color(tint.r, tint.g, tint.b, minf(1.0, tint.a * EDGE_GAIN))


# Whether a cell reads as one particular row, asked of the board and of nothing
# else. `GROUND` is the fall-through and is true of anything that got this far.
static func _reads_as(key: String, board: CombatBoard, cell: Vector2i) -> bool:
	match key:
		HOLE:
			return board.is_hole(cell)
		BUILT:
			return board.blocks_move(cell)
		CLIFF:
			return board.is_cliff_edge(cell)
		AERIAL:
			return board.storey_at(cell) > CombatBoard.GROUND_STOREY
		GROUND:
			return true
	return false
