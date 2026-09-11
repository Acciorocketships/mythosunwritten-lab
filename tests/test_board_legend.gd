extends TestSuite
## The board says what its colours mean, and it says it off the table it paints
## from.
##
## Some squares of the overlay are drawn amber. Amber is a cliff edge -- the one
## square a shove off can cost a character its whole life -- and until the legend
## existed nothing on screen said so. The obvious fix, a hand-written list of
## colours beside a hand-written list of meanings, is a fix that goes stale the
## first time a colour changes and says nothing when it does. So there is one
## table, `render/board_legend.gd`: the shell paints from it and the legend panel
## is generated from it.
##
## What this suite pins is that single source, from four sides:
##
##   1. **the table is a legend**: every colour on it has a meaning, no two
##      colours are the same, and no meaning is blank;
##   2. **the table is what the ground is painted from**: on a board with all
##      five kinds of cell in it, the colour a cell is painted is a colour filed
##      under the row that cell reads as, and all five rows are reached. Ordinary
##      ground is painted in two close shades of blue by the parity of the cell,
##      so a field of it reads as squares rather than as one sheet, and the same
##      pass pins what that checker must not cost: every other meaning is painted
##      its own one colour on either parity;
##   3. **the panel is generated**: it draws one entry per row of the table, in
##      the table's order, with the table's colour and the table's words -- so a
##      colour cannot be painted without appearing on screen;
##   4. **nothing else names a board colour**: no file under `render/` but the
##      table itself writes one of these colours down, which is what makes "the
##      two cannot disagree" a fact about the tree rather than a hope.
##
## The offered cells are checked the same way, and against the keys
## `BoardControls.marks` actually answers with, so the four colours painted over
## the lattice are four things the simulation was asked for.
class_name TestBoardLegend

## A board with one of everything on it, in `BoardSketch`'s glyphs: plain ground,
## a step, a wall of earth too high to climb, the floor of a pit -- whose rim
## comes out flagged as a cliff edge by the board's own drop comparison -- a hole
## where there is no ground at all, and a building.
##
## The one kind of cell no picture of ground can hold is a cell a storey up,
## which is a floating island over the ground rather than a shape of it; `LIFTED`
## is put on afterwards, in the board's own words.
const ROWS := [
	"......",
	".^..#.",
	"..vv..",
	"..vv..",
	".~~,..",
	"......",
]

## Where the cell a storey up is put, and how high it stands. Its own `put` on
## the board the sketch made, with `GROUND_STOREY + 1` for its storey: a cell of
## a floating island over the same ground, which is what a second storey is.
const LIFTED := Vector2i(5, 0)
const LIFTED_HEIGHT := 9.0

## Which of the render layer's files may write a board colour down.
const TABLE := "res://render/board_legend.gd"


func _init() -> void:
	suite_name = "board legend"


func run() -> void:
	_every_colour_has_a_meaning_and_no_two_are_alike()
	_the_ground_is_painted_the_colour_the_table_files_under_it()
	_the_panel_is_one_entry_per_row_of_the_table()
	_no_other_file_in_the_render_layer_names_a_board_colour()
	_the_offered_colours_are_the_marks_the_simulation_answers_with()


# --- 1: the table is a legend ----------------------------------------------


func _every_colour_has_a_meaning_and_no_two_are_alike() -> void:
	var rows := BoardLegend.rows()
	equal(rows.size(), BoardLegend.LATTICE.size() + BoardLegend.OFFERS.size(),
		"every colour the board paints should be one row of the legend")
	var keys := {}
	var tints := {}
	for row in rows:
		var entry := row as Dictionary
		var key := String(entry["key"])
		not_equal(key, "", "every row of the legend should be filed under a key")
		check(not keys.has(key), "no two rows of the legend should share a key: %s" % key)
		keys[key] = true
		not_equal(String(entry["means"]), "",
			"the colour filed under %s should say what it means" % key)
		var tint := Color(entry["tint"])
		var spelt := "%s" % tint
		check(not tints.has(spelt),
			"no two rows of the legend should be the same colour: %s and %s" % [
				key, tints.get(spelt, ""),
			])
		tints[spelt] = key
		check(tint.a > 0.0, "a colour nobody can see is not a colour: %s" % key)
		# And the colour a caller gets by naming the key is the row's own, so
		# there is one lookup and not a second table inside it.
		equal(BoardLegend.tint_for(key), tint,
			"the colour filed under %s should be the one the table holds" % key)
		# A checkered row -- one meaning painted in two shades by the parity of
		# the cell -- has a second colour, and it is a colour like any other:
		# nobody else's, visible, and the first of the row's two shades is the
		# row's own tint.
		var shades := BoardLegend.shades_of(entry)
		equal(shades[0], tint,
			"the first shade of %s should be the colour the table files it under" % key)
		equal(shades.size(), 2 if entry.has("pair") else 1,
			"a row should be painted in one shade, or in two if it is checkered: %s" % key)
		for extra in range(1, shades.size()):
			var other := shades[extra]
			var also := "%s" % other
			check(not tints.has(also),
				"no two shades the board paints should be the same colour: %s and %s" % [
					key, tints.get(also, ""),
				])
			tints[also] = key
			check(other.a > 0.0, "a colour nobody can see is not a colour: %s" % key)


# --- 2: the table is what the ground is painted from -----------------------


func _the_ground_is_painted_the_colour_the_table_files_under_it() -> void:
	var board := _board()
	var reached := {}
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var key := BoardLegend.lattice_key(board, cell)
			reached[key] = true
			equal(BoardLegend.tint_of(board, cell), BoardLegend.shade_of(key, cell),
				"a cell reading as %s should be painted a shade filed under it" % key)
			# And that shade is one of the row's own, whichever way the parity
			# fell: the checker picks between a meaning's shades and never
			# between meanings, so a cliff edge is a cliff edge on either parity.
			check(BoardLegend.shades_of(BoardLegend.row_for(key)).has(
					BoardLegend.tint_of(board, cell)),
				"the cell at %s reads as %s and should be painted in one of that"
					% [cell, key] + " meaning's own shades")
			# And the key is the board's own answer, asked again here rather than
			# taken from the table: the order the five are tested in is the
			# table's, and the first that fits is the one that stops you.
			equal(key, _expected_key(board, cell),
				"the cell at %s should read as %s" % [cell, _expected_key(board, cell)])
	for row in BoardLegend.LATTICE:
		var key := String((row as Dictionary)["key"])
		check(reached.has(key),
			"the sketch should reach every kind of cell the legend explains: %s" % key)
	_the_ground_is_checkered_and_nothing_else_is(board)


# Ordinary ground alternates between the two shades the table holds for it, by
# the parity of the cell, and no other meaning alternates at all.
#
# Both halves matter. The first is the checker: a board of squares all one
# colour reads as a single sheet, which is the fault this answers. The second is
# what the checker must not cost: a cliff edge, a hole, a built cell and a cell
# a storey up are painted the one colour their meaning is filed under wherever
# they fall, so parity cannot make one cell of a kind read as another kind.
func _the_ground_is_checkered_and_nothing_else_is(board: CombatBoard) -> void:
	var ground := BoardLegend.row_for(BoardLegend.GROUND)
	check(ground.has("pair"), "ordinary ground should be painted in two shades")
	var shades := BoardLegend.shades_of(ground)
	not_equal(shades[0], shades[1], "the two shades of ground should be two colours")
	# Close rather than opposite: the ask was a checkerboard a person reads
	# without being shouted at, so the two shades stay within a quarter of the
	# range of one another on every channel and are the same see-through weight.
	for channel in [
		[shades[0].r, shades[1].r], [shades[0].g, shades[1].g], [shades[0].b, shades[1].b],
	]:
		check(absf(channel[0] - channel[1]) <= 0.40,
			"the two shades of ground should be close: %.2f against %.2f" % [
				channel[0], channel[1],
			])
	equal(shades[0].a, shades[1].a, "both shades of ground should be equally see-through")

	# On the board itself: every cell that reads as ground is painted the shade
	# its own parity picks, and the two parities are two different colours, so a
	# square and the square beside it never come out the same.
	var seen := {}
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var key := BoardLegend.lattice_key(board, cell)
			var odd := (cell.x + cell.y) % 2 != 0
			if key == BoardLegend.GROUND:
				equal(BoardLegend.tint_of(board, cell), shades[1 if odd else 0],
					"the ground at %s should be painted its parity's shade" % cell)
				seen[odd] = true
			else:
				# Every other meaning: one colour, and the same colour on both
				# parities, which is what "the checker overwrites nothing" means.
				equal(BoardLegend.tint_of(board, cell), BoardLegend.tint_for(key),
					"a cell reading as %s should be painted that meaning's own colour" % key)
				equal(BoardLegend.shade_of(key, cell + Vector2i(1, 0)),
					BoardLegend.shade_of(key, cell),
					"%s should be the same colour on either parity" % key)
	check(seen.has(true) and seen.has(false),
		"the sketch should hold ground cells of both parities")


# The sketch, with one cell lifted a storey. Nothing else is touched: the drop
# the sketch worked out for its neighbours stands, so the lifted cell is a cell
# of higher ground and not a rewritten board.
func _board() -> CombatBoard:
	var board := BoardSketch.from_rows(PackedStringArray(ROWS))
	board.put(
		LIFTED, CombatBoard.STANDABLE, LIFTED_HEIGHT,
		CombatBoard.GROUND_STOREY + 1, 1, 0.0)
	return board


# The same five questions, in the order the table puts them in, asked straight of
# the board. If this and `BoardLegend.lattice_key` ever disagree, one of the two
# has started deciding something.
func _expected_key(board: CombatBoard, cell: Vector2i) -> String:
	if board.is_hole(cell):
		return BoardLegend.HOLE
	if board.blocks_move(cell):
		return BoardLegend.BUILT
	if board.is_cliff_edge(cell):
		return BoardLegend.CLIFF
	if board.storey_at(cell) > CombatBoard.GROUND_STOREY:
		return BoardLegend.AERIAL
	return BoardLegend.GROUND


# --- 3: the panel is generated ---------------------------------------------


func _the_panel_is_one_entry_per_row_of_the_table() -> void:
	var rows := BoardLegend.rows()
	var said := LegendPanel.lines()
	equal(said.size(), rows.size(),
		"the legend should say one line per colour the board paints")
	for at in rows.size():
		equal(said[at], String((rows[at] as Dictionary)["means"]),
			"line %d of the legend should be the table's own words" % at)

	# And the panel really draws them: one swatch per row, in the table's order
	# and in the table's colour. Built with no window anywhere, as every panel
	# here can be.
	var panel := LegendPanel.new()
	var swatches := _swatches_of(panel)
	# Every shade of every row, in the table's order: a plain row is one patch
	# and a checkered one is both of its shades side by side, so a colour cannot
	# be painted on the ground without being shown here.
	var painted: Array[Color] = []
	for row in rows:
		painted.append_array(BoardLegend.shades_of(row as Dictionary))
	equal(swatches.size(), painted.size(),
		"the panel should draw one patch per shade the board paints")
	for at in mini(swatches.size(), painted.size()):
		equal(swatches[at], painted[at],
			"patch %d should be the colour the table holds" % at)
	panel.free()


# Every swatch the panel built, in the order it built them. The backing is an
# opaque plate and the tint is the one child over it -- see `LegendPanel.UNDER`
# -- so the colour wanted is the child's.
func _swatches_of(panel: LegendPanel) -> Array[Color]:
	var found: Array[Color] = []
	_collect_swatches(panel, found)
	return found


func _collect_swatches(node: Node, into: Array[Color]) -> void:
	for child in node.get_children():
		if child is ColorRect and (child as ColorRect).color == LegendPanel.UNDER:
			for over in (child as ColorRect).get_children():
				if over is ColorRect:
					into.append((over as ColorRect).color)
			continue
		_collect_swatches(child, into)


# --- 4: one table and no other -----------------------------------------------


func _no_other_file_in_the_render_layer_names_a_board_colour() -> void:
	var wanted: Array[Color] = []
	for row in BoardLegend.rows():
		wanted.append_array(BoardLegend.shades_of(row as Dictionary))
	# Every colour written down anywhere under render/, read out of the source
	# as four numbers rather than as a spelling, so that a second copy written
	# `Color(1.0,0.66,0.26,0.52)` is caught as readily as one written with
	# spaces in it.
	var literal := RegEx.new()
	literal.compile(COLOUR_LITERAL)
	for path in LayerCheck._files_under(LayerCheck.RENDER_DIR):
		if path == TABLE:
			continue
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		for found in literal.search_all(text):
			var written := Color(
				float(found.get_string(1)), float(found.get_string(2)),
				float(found.get_string(3)), float(found.get_string(4)))
			for tint in wanted:
				check(not _same_colour(written, tint),
					"%s writes the board colour %s down; the legend's table is the"
						% [path, tint] + " only place for one")


## A colour literal with all four components spelled out, as source writes one.
## Three-component literals cannot be one of these: every board colour is
## see-through, and a `Color` with no alpha in it is opaque.
const COLOUR_LITERAL := \
	"Color\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)"


func _same_colour(one: Color, other: Color) -> bool:
	return is_equal_approx(one.r, other.r) and is_equal_approx(one.g, other.g) \
		and is_equal_approx(one.b, other.b) and is_equal_approx(one.a, other.a)


# --- 5: the offered colours are answers ------------------------------------


func _the_offered_colours_are_the_marks_the_simulation_answers_with() -> void:
	# With no turn to ask, `marks` still says which four questions it answers,
	# which is the whole list the offer colours are painted from.
	var marks := BoardControls.marks(null, null)
	equal(marks.size(), BoardLegend.OFFERS.size(),
		"there should be one offer colour per list of cells the board answers with")
	for row in BoardLegend.OFFERS:
		var key := String((row as Dictionary)["key"])
		check(marks.has(key),
			"the offer colour %s should be a list of cells the board answers with" % key)
