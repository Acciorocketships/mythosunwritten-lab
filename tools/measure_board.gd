extends SceneTree
## What a board costs to read, and how many cells the places a fight happens in
## come out as.
##
##   ./tools/measure_board.sh              # seed 1234
##   ./tools/measure_board.sh --seed 7
##
## Two questions, and both of them are questions the cell size is argued from.
##
## *What does reading a board cost?* A board is not streamed and not kept: it is
## read when a fight starts, once, off the terrain query. So what matters is the
## one-off cost of a rectangle, and it is reported both cold -- the first board
## in a part of the world nothing has asked about yet, which pays for the islands
## and the villages under it -- and warm, which is what a second fight nearby
## costs.
##
## *How big are the places a fight happens?* A village green, an island's top and
## a fight's default rectangle, each in cells. This is the legibility half of the
## trade: a board of eight cells is not a chess board and a board of fifty is not
## legible.
##
## Times on a machine with no GPU are still honest here -- none of this draws
## anything.

const MEASURED_BOARDS := 12


func _initialize() -> void:
	var seed_value := 1234
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			seed_value = args[i + 1].to_int()

	var terrain := TerrainQuery.for_seed(seed_value)
	var builder := CombatBoardBuilder.new(terrain)
	print("board-measure seed=%d cell=%.2f span=%.1f" % [
		seed_value, CombatBoard.CELL_SIZE, CombatBoardBuilder.DEFAULT_SPAN,
	])

	# Cold: each board in a stretch of world nothing has been asked about yet.
	var cold: Array[float] = []
	for at in MEASURED_BOARDS:
		var x := 4000.0 + float(at) * 900.0
		var began := Time.get_ticks_usec()
		var board := builder.build_on_ground(x, -x)
		cold.append(float(Time.get_ticks_usec() - began) / 1000.0)
		if at == 0:
			print("board-measure cells=%d across=%d deep=%d" % [
				board.cell_count(), board.cells_across, board.cells_deep,
			])
	# Warm: boards a few cells apart, over ground the fields have already been
	# asked about -- a second fight in the same clearing.
	var warm: Array[float] = []
	builder.build_on_ground(0.0, 0.0)
	for at in MEASURED_BOARDS:
		var x := float(at) * 6.0
		var began := Time.get_ticks_usec()
		builder.build_on_ground(x, 0.0)
		warm.append(float(Time.get_ticks_usec() - began) / 1000.0)
	print("board-measure cold_ms %s" % _spread(cold))
	print("board-measure warm_ms %s" % _spread(warm))

	# How wide the places a fight happens are, in cells.
	var cell := CombatBoard.CELL_SIZE
	print("board-measure arena fight=%d village_green=%d..%d road=%.1f building=%.1f..%.1f" % [
		int(round(2.0 * CombatBoardBuilder.DEFAULT_SPAN / cell)),
		int(round(2.0 * SettlementField.PAD_RADIUS_MIN / cell)),
		int(round(2.0 * SettlementField.PAD_RADIUS_MAX / cell)),
		2.0 * PathNetwork.PATH_HALF_WIDTH / cell,
		2.0 * 1.3 / cell, 2.0 * 3.9 / cell,
	])

	# And the island tops, measured rather than taken off the radius constants,
	# because an island's outline is torn and its top is not its whole footprint.
	var spans: Array[float] = []
	var standable: Array[float] = []
	for band in FloatingIsland.WALKABLE_BANDS:
		var size := IslandField.cell_size(band)
		var reach := int(ceil(600.0 / size))
		for cell_x in range(-reach, reach + 1):
			for cell_z in range(-reach, reach + 1):
				var island := terrain.island_field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island == null or not island.walkable:
					continue
				spans.append(2.0 * island.max_reach() / cell)
				var top := island.top_height_at(island.centre_x, island.centre_z)
				var board := builder.build(
					island.centre_x, island.centre_z, top, island.max_reach() + cell
				)
				standable.append(float(board.standable_count()))
	print("board-measure islands count=%d across_cells %s standable_cells %s" % [
		spans.size(), _spread(spans), _spread(standable),
	])
	quit(0)


## min / median / max of a set of measurements, as one field.
func _spread(values: Array[float]) -> String:
	if values.is_empty():
		return "none"
	var sorted := values.duplicate()
	sorted.sort()
	return "min=%.2f median=%.2f max=%.2f" % [
		sorted[0], sorted[sorted.size() / 2], sorted[sorted.size() - 1],
	]
