extends TestSuite
## The board overlay lies on the ground, and the grass over it gives way.
##
## Two claims, and both of them are claims about the render layer only -- the
## board itself, its cell size and every answer it gives are the simulation's,
## and nothing here touches them.
##
## The first claim is that a square follows the surface. A cell used to be four
## corners at one height, so on any slope it cut into the hill uphill and floated
## downhill; now it is a patch of quads whose every corner is the height the
## terrain query gives at that corner. The checks are the three parts of that: a
## square is still bounded in x and z by exactly the same rectangle, its heights
## are the terrain's own answers rather than one repeated number, and the outline
## is built from those same heights so no edge floats free of the fill it bounds.
## A hole is the stated exception -- there is no surface under water or under the
## void off an island's rim, so its plate stays flat at the anchor height.
##
## The second claim is that the grass hears about the board through the same
## per-frame uniforms the walkers who part the grass already go through, and that
## turning the board off puts the grass back up.
class_name TestBoardOverlay

const SEED := 1234
## A hillside: the site tools/measure_overlay.sh picks out of this seed as the
## steepest grassy ground within reach of the origin.
const SLOPE := Vector2(198.0, -102.0)
## A shore, so the board has holes in it: water is not a surface.
const SHORE := Vector2(196.0, 182.0)

const RenderShell := preload("res://render/main.gd")

## Every shell built here, so the ones the checks are done with can be freed:
## they are never added to a scene tree, so nobody else would.
var _shells: Array[Node] = []


func _init() -> void:
	suite_name = "board overlay"


func run() -> void:
	_a_square_is_bounded_by_its_cell_and_follows_the_surface()
	_a_hole_stays_flat_at_the_anchor_height()
	_the_outline_stands_on_the_same_heights_as_the_fill()
	_following_the_surface_beats_one_height_per_cell()
	_a_sampled_cell_is_sampled_once_however_often_the_board_is_rebuilt()
	_the_grass_hears_about_the_board_through_the_walkers_own_uniforms()
	# The shells were never added to a scene tree, so nothing else will free
	# them.
	for shell in _shells:
		(shell as Node).free()
	_shells.clear()


## Every corner of every square is at the height the terrain has there, and the
## square still covers exactly the rectangle it used to.
func _a_square_is_bounded_by_its_cell_and_follows_the_surface() -> void:
	var shell := _shell(SLOPE)
	var board: CombatBoard = shell._sim.world.board_here()
	var terrain: TerrainQuery = shell._sim.world.terrain
	var cuts: int = RenderShell.BOARD_CUTS
	var wide := cuts + 1
	var half: float = board.cell_size * RenderShell.BOARD_FILL * 0.5
	var varied := 0
	var checked := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell: Vector2i = board.min_cell + Vector2i(column, row)
			if board.is_hole(cell):
				continue
			checked += 1
			var middle: Vector2 = board.centre(cell)
			var surface: PackedFloat64Array = shell._cell_surface(board, cell, {})
			var lowest := INF
			var highest := -INF
			for down in wide:
				for across in wide:
					var x: float = middle.x - half + 2.0 * half * float(across) / float(cuts)
					var z: float = middle.y - half + 2.0 * half * float(down) / float(cuts)
					var height: float = surface[down * wide + across]
					var wanted := terrain.support_at(x, z, board.height_at(cell))
					if wanted == -INF:
						wanted = board.height_at(cell)
					if absf(height - wanted) > 0.000001:
						failures.append(
							"a sub-vertex of cell %s is at %.4f, not the %.4f the"
							% [str(cell), height, wanted]
							+ " terrain has at (%.2f, %.2f)" % [x, z]
						)
						return
					lowest = minf(lowest, height)
					highest = maxf(highest, height)
					# Bounded in x and z by the cell, exactly as one flat quad
					# was: no sub-vertex may leave the painted rectangle.
					if absf(x - middle.x) > half + 0.000001 \
							or absf(z - middle.y) > half + 0.000001:
						failures.append(
							"a sub-vertex of cell %s left its cell" % str(cell)
						)
						return
			if highest - lowest > 0.001:
				varied += 1
	checks += 1
	check(checked > 100, "the hillside board has cells to check: %d" % checked)
	# The point of the whole exercise: on a hillside most squares are not flat.
	check(
		varied > checked / 2,
		"most squares on a hillside follow a surface that varies across them:"
		+ " %d of %d do" % [varied, checked]
	)


## A hole has no surface under it, so its plate stays where it always was.
func _a_hole_stays_flat_at_the_anchor_height() -> void:
	var shell := _shell(SHORE)
	var board: CombatBoard = shell._sim.world.board_here()
	var holes := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell: Vector2i = board.min_cell + Vector2i(column, row)
			if not board.is_hole(cell):
				continue
			holes += 1
			var surface: PackedFloat64Array = shell._cell_surface(board, cell, {})
			for height in surface:
				if absf(height - board.anchor_height) > 0.000001:
					failures.append(
						"a hole at %s is drawn at %.4f, not the anchor height %.4f"
						% [str(cell), height, board.anchor_height]
					)
					return
	check(holes > 0, "the shore board has holes in it: %d" % holes)


## Every point the outline is drawn through is a point the fill is drawn through,
## so an edge cannot float off the square it bounds.
func _the_outline_stands_on_the_same_heights_as_the_fill() -> void:
	var built := _drawn(SLOPE)
	var mesh: ArrayMesh = built["mesh"]
	equal(mesh.get_surface_count(), 2, "the overlay is a fill and an outline")
	var fill: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lines: PackedVector3Array = mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
	var standing := {}
	for point in fill:
		standing[point] = true
	var adrift := 0
	for point in lines:
		if not standing.has(point):
			adrift += 1
	equal(adrift, 0, "no point of the outline floats free of the fill it bounds")
	check(lines.size() > 0, "there is an outline at all: %d points" % lines.size())


## The whole reason for the change, as arithmetic: over a hillside board the
## drawn surface is far closer to the ground than one height per cell was.
func _following_the_surface_beats_one_height_per_cell() -> void:
	var shell := _shell(SLOPE)
	var board: CombatBoard = shell._sim.world.board_here()
	var terrain: TerrainQuery = shell._sim.world.terrain
	var cuts: int = RenderShell.BOARD_CUTS
	var wide := cuts + 1
	var half: float = board.cell_size * RenderShell.BOARD_FILL * 0.5
	var flat_gap := 0.0
	var followed_gap := 0.0
	var counted := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell: Vector2i = board.min_cell + Vector2i(column, row)
			if board.is_hole(cell):
				continue
			var middle: Vector2 = board.centre(cell)
			var height: float = board.height_at(cell)
			var surface: PackedFloat64Array = shell._cell_surface(board, cell, {})
			# The corners themselves are the fair comparison: the drawn surface
			# passes through them exactly, and the flat one does not.
			for down in wide:
				for across in wide:
					var x: float = middle.x - half + 2.0 * half * float(across) / float(cuts)
					var z: float = middle.y - half + 2.0 * half * float(down) / float(cuts)
					var real := terrain.support_at(x, z, height)
					if real == -INF:
						continue
					flat_gap += absf(height - real)
					followed_gap += absf(surface[down * wide + across] - real)
					counted += 1
	check(counted > 0, "there were corners to compare: %d" % counted)
	var flat_mean := flat_gap / maxf(1.0, float(counted))
	check(
		followed_gap < flat_gap * 0.01,
		"the drawn square lies on the ground: the mean gap is %.4f, against"
		% (followed_gap / maxf(1.0, float(counted)))
		+ " %.4f for one height per cell" % flat_mean
	)
	check(
		flat_mean > 0.05,
		"one height per cell really was off the ground here, by %.4f on average"
		% flat_mean
	)


## Walking one cell along re-samples one new column, not the whole board: a cell
## already read is handed back as the same object rather than read again.
func _a_sampled_cell_is_sampled_once_however_often_the_board_is_rebuilt() -> void:
	var shell := _shell(SLOPE)
	var board: CombatBoard = shell._sim.world.board_here()
	var cell: Vector2i = board.anchor_cell
	var kept := {}
	var first: PackedFloat64Array = shell._cell_surface(board, cell, kept)
	# What the last rebuild kept is what the next one starts from.
	shell._board_surface = kept
	var again: PackedFloat64Array = shell._cell_surface(board, cell, {})
	check(
		is_same(first, again),
		"a cell already sampled is handed back rather than sampled again"
	)
	var absent := {}
	var elsewhere: PackedFloat64Array = shell._cell_surface(
		board, cell + Vector2i(1, 0), absent
	)
	check(
		not is_same(first, elsewhere),
		"a different cell is a different surface"
	)


## The grass is told about the board through the material every chunk shares, so
## one write covers the whole world -- the same path and cost as the walkers.
func _the_grass_hears_about_the_board_through_the_walkers_own_uniforms() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var grass := GrassLayer.new(terrain, SEED)
	var material := grass.material()
	# Nothing is drawn until a board says so.
	grass.stand_clear()
	var clear: Plane = material.get_shader_parameter("board_rect")
	equal(clear.d, 0.0, "with no board the grass is told the board reaches nowhere")
	grass.stand_over_board(Vector2(12.0, -8.0), Vector2(31.5, 31.5), 4.0, 6.0, 3.0, 0.86)
	var reach: Plane = material.get_shader_parameter("board_rect")
	equal(Vector2(reach.x, reach.y), Vector2(12.0, -8.0), "the board's middle reaches the shader")
	equal(Vector2(reach.z, reach.d), Vector2(31.5, 31.5), "so does how far it reaches")
	var level: Vector2 = material.get_shader_parameter("board_level")
	equal(level.x, 4.0, "so does the height the board's middle sits at")
	check(level.y >= 3.0, "the band covers the board's own relief: %.2f" % level.y)
	equal(material.get_shader_parameter("board_cell"), 3.0, "so does the cell size")
	# And the blades give way by being shortened, on the same number the walkers
	# shorten them by, rather than by being made transparent.
	equal(
		material.get_shader_parameter("board_thin"), GrassLayer.BOARD_THIN,
		"the grass over a square stands shorter"
	)
	equal(
		material.get_shader_parameter("board_fade"), GrassLayer.BOARD_FADE,
		"and is not faded, because shortening read better"
	)
	grass.stand_clear()
	var gone: Plane = material.get_shader_parameter("board_rect")
	equal(gone.z, 0.0, "switching the board off stands the grass back up")


## A render shell with a world under it, standing where it is told to stand. It
## is never added to a scene tree, so nothing here needs a screen.
func _shell(at: Vector2) -> Node:
	var shell := RenderShell.new()
	shell._sim = Simulation.new(SEED)
	shell._sim.world.place_observer(at.x, at.y)
	_shells.append(shell)
	return shell


## The mesh the overlay actually builds, for a board at a place.
func _drawn(at: Vector2) -> Dictionary:
	var shell := _shell(at)
	shell._board_view = MeshInstance3D.new()
	shell._sync_board(shell._sim.world.snapshot())
	var mesh: ArrayMesh = shell._board_view.mesh
	shell._board_view.free()
	return {"mesh": mesh}
