extends SceneTree
## How much relief the ground has, where it is, and whether a character can
## walk to the top of it.
##
##   ./tools/measure_mountains.sh                        # seed 1234, 2 km square
##   ./tools/measure_mountains.sh --seed 7
##   ./tools/measure_mountains.sh --trace reports/assets/climb-1234.txt
##
## Four questions, asked of the same fields the game builds the world from:
##
##   * **relief** -- the lowest and highest ground over a stated square, which
##     is the one number "the world has mountains now" has to move.
##   * **windows** -- the same question asked of each square of a tiling, so
##     that "mountains are a place" can be shown rather than asserted: a window
##     with no uplift under it prints the identical relief before and after.
##   * **climb** -- whether a route to a summit exists *under the terrain
##     query's own step limits*, found by breadth-first search over the real
##     height function on the tactical lattice. Nothing here is inferred from
##     an amplitude: a mountain is climbable when the search comes back with a
##     path, and not otherwise.
##   * **faces** -- how much of a mountain the same step limits refuse. A
##     mountain with no impassable ground is a hill; a mountain that is
##     impassable everywhere is a wall. This says which one was built.
##
## The lattice, the step up and the step down are read off CombatBoard and
## TerrainQuery rather than restated here, so this tool cannot drift away from
## the limits the game actually enforces.
##
## Nothing is generated and nothing is written except the optional trace file:
## every number comes out of TerrainQuery, so running this changes no world.

const DEFAULT_SEED := 1234

## Half the side of the measured square, in world units. The default makes a
## 2 km square around the origin -- the same square the world's relief has been
## quoted over since before there were mountains in it.
const DEFAULT_SPAN := 1000.0

## How finely the relief grid is sampled, in world units.
const RELIEF_STEP := 4.0

## The side of one window of the regional comparison, in world units.
const WINDOW := 400.0

## How finely the per-biome sweep is sampled, in world units. Coarser than the
## relief grid because resolving a biome costs four noise fields and a blend.
const BIOME_STEP := 8.0

## The lattice a route is searched on, and the step limits it must obey. These
## are the tactical lattice's own numbers: a route this search finds is a route
## the combat board would also allow, cell for cell.
const LATTICE := CombatBoard.CELL_SIZE
const STEP_UP := TerrainQuery.HOP_HEIGHT
const STEP_DOWN := TerrainQuery.DROP_REACH

## How large a block of lattice cells one summit may claim. A cell is a summit
## when it is the highest in its block and its block is higher than all eight
## blocks around it, so two summits are always at least this far apart.
const SUMMIT_BLOCK := 8

## How high ground has to stand to be called a summit at all, in world units.
## Above the +14.29 the base height field alone ever reached on seed 1234, so
## nothing the old world had could be mistaken for a mountain top.
const DEFAULT_SUMMIT_FLOOR := 24.0

## How many summits, tallest first, get a climb searched for them.
const SUMMIT_SAMPLE := 8

## Half the side of the box a climb is searched in, in world units. Wide enough
## that its rim is ordinary ground on either side of a period-600 massif.
const CLIMB_REACH := 390.0

## How far from a summit counts as its mountain, when measuring what the step
## limits refuse.
const FACE_REACH := 240.0

## The four cardinal neighbours, as offsets on the lattice. Cardinal only: a
## route made of diagonal steps would cross more ground per step than the limits
## were written for, so the strictest reading is the one measured.
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _initialize() -> void:
	var options := _parse_args()
	var seed_value: int = options["seed"]
	var span: float = options["span"]
	var query := TerrainQuery.for_seed(seed_value)

	print("mountain survey seed=%d span=%.0f (a %.0f-unit square) lattice=%.2f up=%.2f down=%.2f" % [
		seed_value, span, span * 2.0, LATTICE, STEP_UP, STEP_DOWN,
	])

	_report_relief(query, span)
	_report_uplift(query, span)
	_report_biomes(query, span)

	var grid := _lattice_grid(query, span)
	var summits := _summits(grid, options["summit_floor"])
	_report_summits(grid, summits, options["summit_floor"])
	_report_climbs(grid, summits, options["trace"])
	_report_faces(grid, summits)
	_report_boards(query, grid, summits)
	quit(0)


# --- relief ---------------------------------------------------------------


## The lowest and the highest ground over the square, and the same question
## asked window by window.
##
## Both come out of one pass over one grid of samples, so the windows and the
## whole-square number can never disagree about a position.
##
## The windows are what shows a mountain to be a place rather than a tax. A
## window the uplift does not reach prints the identical numbers before and
## after the uplift exists -- identical rather than close, because the mask is
## exactly zero out there and multiplying by exactly zero changes no float.
func _report_relief(query: TerrainQuery, span: float) -> void:
	var across := int(round(2.0 * span / RELIEF_STEP)) + 1
	var heights := PackedFloat64Array()
	heights.resize(across * across)
	for row in across:
		var z := -span + float(row) * RELIEF_STEP
		for column in across:
			heights[row * across + column] = query.ground_height_at(
				-span + float(column) * RELIEF_STEP, z
			)

	var lowest := INF
	var highest := -INF
	var total := 0.0
	for height in heights:
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
		total += height
	print("relief samples=%d spacing=%.1f min=%.2f max=%.2f mean=%.2f relief=%.2f" % [
		heights.size(), RELIEF_STEP, lowest, highest,
		total / float(heights.size()), highest - lowest,
	])

	var windows := int(round(2.0 * span / WINDOW))
	var per_window := int(round(WINDOW / RELIEF_STEP))
	print("windows side=%.0f across=%d (each line is one square: its own relief)" % [
		WINDOW, windows,
	])
	for window_row in windows:
		for window_column in windows:
			var window_low := INF
			var window_high := -INF
			for row in range(window_row * per_window, mini(across, (window_row + 1) * per_window + 1)):
				for column in range(
					window_column * per_window,
					mini(across, (window_column + 1) * per_window + 1),
				):
					var height := heights[row * across + column]
					window_low = minf(window_low, height)
					window_high = maxf(window_high, height)
			print("window x=%.0f z=%.0f min=%.4f max=%.4f relief=%.4f" % [
				-span + (float(window_column) + 0.5) * WINDOW,
				-span + (float(window_row) + 0.5) * WINDOW,
				window_low, window_high, window_high - window_low,
			])


## How much of the world the uplift reaches, and how hard.
##
## This is the "mountains are a place" number stated directly rather than read
## off the windows: the share of the square the mask leaves completely alone,
## and the shares it lifts by more than a house, more than a cliff, and more
## than the whole world's old relief.
func _report_uplift(query: TerrainQuery, span: float) -> void:
	var bands := [1.0, 10.0, 30.0, 50.0]
	var counts := PackedInt32Array()
	counts.resize(bands.size())
	var count := 0
	var highest := 0.0
	var mask_total := 0.0
	var z := -span
	while z <= span + 0.0001:
		var x := -span
		while x <= span + 0.0001:
			var uplift := query.surface_field.uplift_at(x, z)
			highest = maxf(highest, uplift)
			mask_total += query.surface_field.uplift_mask_at(x, z)
			for band in bands.size():
				if uplift > float(bands[band]):
					counts[band] += 1
			count += 1
			x += RELIEF_STEP
		z += RELIEF_STEP
	var shares := []
	for band in bands.size():
		shares.append("over_%.0f=%.2f%%" % [
			float(bands[band]), 100.0 * float(counts[band]) / float(count),
		])
	print("uplift samples=%d highest=%.2f mean_mask=%.4f %s" % [
		count, highest, mask_total / float(count), " ".join(shares),
	])


## What each biome's ground now does, so that "the rocky axis drives the uplift"
## can be read off the world rather than off the code. Until this layer existed
## the rocky axis reached the palette, the fog and the boulder scatter and never
## reached the height of anything, so every biome's mean height was the same
## number within noise. The line to look at is highland's.
func _report_biomes(query: TerrainQuery, span: float) -> void:
	var counts := {}
	var uplift_total := {}
	var height_total := {}
	var height_max := {}
	for id in BiomeCatalog.IDS:
		counts[id] = 0
		uplift_total[id] = 0.0
		height_total[id] = 0.0
		height_max[id] = -INF
	var z := -span
	while z <= span + 0.0001:
		var x := -span
		while x <= span + 0.0001:
			var id := query.biome_at(x, z)
			counts[id] += 1
			uplift_total[id] += query.surface_field.uplift_at(x, z)
			var height := query.ground_height_at(x, z)
			height_total[id] += height
			height_max[id] = maxf(height_max[id], height)
			x += BIOME_STEP
		z += BIOME_STEP
	var total := 0
	for id in BiomeCatalog.IDS:
		total += int(counts[id])
	print("biomes samples=%d spacing=%.1f" % [total, BIOME_STEP])
	for id in BiomeCatalog.IDS:
		var here: int = counts[id]
		if here == 0:
			print("biome %-14s share=0.00%% (none in the square)" % id)
			continue
		print("biome %-14s share=%5.2f%% mean_uplift=%6.2f mean_height=%6.2f max_height=%6.2f" % [
			id, 100.0 * float(here) / float(total),
			float(uplift_total[id]) / float(here),
			float(height_total[id]) / float(here),
			float(height_max[id]),
		])


# --- the lattice the route is searched on ---------------------------------


## The ground height and whether it can be stood on, at every cell of the
## tactical lattice across the square. Sampled once and read many times: the
## climb searches and the face measurements all index into this one grid, so no
## position is ever asked about twice and every one of them agrees.
func _lattice_grid(query: TerrainQuery, span: float) -> Dictionary:
	var across := int(floor(2.0 * span / LATTICE)) + 1
	var heights := PackedFloat64Array()
	heights.resize(across * across)
	var solid := PackedByteArray()
	solid.resize(across * across)
	for row in across:
		var z := -span + float(row) * LATTICE
		for column in across:
			var x := -span + float(column) * LATTICE
			var index := row * across + column
			heights[index] = query.ground_height_at(x, z)
			solid[index] = 1 if query.is_passable_at(x, z) else 0
	print("lattice cells=%d across=%d spacing=%.2f solid=%d" % [
		across * across, across, LATTICE, _count_solid(solid),
	])
	return {"across": across, "span": span, "heights": heights, "solid": solid}


func _count_solid(solid: PackedByteArray) -> int:
	var total := 0
	for value in solid:
		if value == 1:
			total += 1
	return total


func _cell_position(grid: Dictionary, column: int, row: int) -> Vector2:
	var span: float = grid["span"]
	return Vector2(-span + float(column) * LATTICE, -span + float(row) * LATTICE)


# --- summits --------------------------------------------------------------


## Every summit in the square: the highest cell of a block that is higher than
## all eight blocks around it. Blocked rather than windowed so that a long
## ridge yields the tops along it instead of one point per pixel of noise, and
## so that no two summits are within SUMMIT_BLOCK cells of each other.
func _summits(grid: Dictionary, floor_height: float) -> Array:
	var across: int = grid["across"]
	var heights: PackedFloat64Array = grid["heights"]
	var blocks := int(floor(float(across) / float(SUMMIT_BLOCK)))
	var block_max := PackedFloat64Array()
	block_max.resize(blocks * blocks)
	var block_at := PackedInt32Array()
	block_at.resize(blocks * blocks)
	for block_row in blocks:
		for block_column in blocks:
			var best := -INF
			var best_index := -1
			for row in SUMMIT_BLOCK:
				for column in SUMMIT_BLOCK:
					var index := (block_row * SUMMIT_BLOCK + row) * across \
						+ block_column * SUMMIT_BLOCK + column
					if heights[index] > best:
						best = heights[index]
						best_index = index
			block_max[block_row * blocks + block_column] = best
			block_at[block_row * blocks + block_column] = best_index

	var found := []
	for block_row in blocks:
		for block_column in blocks:
			var here := block_max[block_row * blocks + block_column]
			if here < floor_height:
				continue
			var top := true
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					if dr == 0 and dc == 0:
						continue
					var nr: int = block_row + dr
					var nc: int = block_column + dc
					if nr < 0 or nc < 0 or nr >= blocks or nc >= blocks:
						continue
					if block_max[nr * blocks + nc] > here:
						top = false
			if not top:
				continue
			var index: int = block_at[block_row * blocks + block_column]
			found.append({
				"column": index % across,
				"row": index / across,
				"height": here,
			})
	found.sort_custom(func(a, b): return float(a["height"]) > float(b["height"]))
	return found


func _summit_name(rank: int) -> String:
	return "summit-%d" % (rank + 1)


func _report_summits(grid: Dictionary, summits: Array, floor_height: float) -> void:
	print("summits floor=%.1f found=%d (a block top higher than all eight blocks round it)" % [
		floor_height, summits.size(),
	])
	for rank in summits.size():
		var summit: Dictionary = summits[rank]
		var at := _cell_position(grid, int(summit["column"]), int(summit["row"]))
		print("summit %s x=%.1f z=%.1f height=%.2f" % [
			_summit_name(rank), at.x, at.y, float(summit["height"]),
		])


# --- the climb ------------------------------------------------------------


## For each of the tallest summits, whether a route to it exists from the
## ordinary ground around the mountain, obeying the step limits at every step.
##
## The search is breadth-first from every solid cell on the rim of a box round
## the summit, forwards, so a step is tested in the direction it is taken --
## which matters, because a step up may be 3.0 and a step down only 2.0.
func _report_climbs(grid: Dictionary, summits: Array, trace_path: String) -> void:
	var sample := mini(SUMMIT_SAMPLE, summits.size())
	print("climbs sample=%d reach=%.0f (breadth-first over the real height function)" % [
		sample, CLIMB_REACH,
	])
	var walkable := 0
	for rank in sample:
		var summit: Dictionary = summits[rank]
		var route := _climb(grid, int(summit["column"]), int(summit["row"]))
		var at := _cell_position(grid, int(summit["column"]), int(summit["row"]))
		if not bool(route["reached"]):
			print("climb %s x=%.1f z=%.1f height=%.2f reached=no rim_solid=%d visited=%d" % [
				_summit_name(rank), at.x, at.y, float(summit["height"]),
				int(route["rim"]), int(route["visited"]),
			])
			continue
		walkable += 1
		var path: Array = route["path"]
		var start: Vector2 = path[0]["at"]
		print(
			"climb %s x=%.1f z=%.1f height=%.2f reached=yes steps=%d"
			% [_summit_name(rank), at.x, at.y, float(summit["height"]), path.size() - 1]
			+ " from=(%.1f, %.1f) foot=%.2f ascent=%.2f worst_rise=%.2f worst_fall=%.2f" % [
				start.x, start.y, float(path[0]["height"]),
				float(summit["height"]) - float(path[0]["height"]),
				float(route["worst_rise"]), float(route["worst_fall"]),
			]
		)
		if rank == 0 and trace_path != "":
			_write_trace(trace_path, path)
	print("climbs walkable=%d of %d" % [walkable, sample])


## One climb: breadth-first from the rim of the box inwards, keeping the cell
## each cell was first reached from so the route can be walked back out.
func _climb(grid: Dictionary, summit_column: int, summit_row: int) -> Dictionary:
	var across: int = grid["across"]
	var heights: PackedFloat64Array = grid["heights"]
	var solid: PackedByteArray = grid["solid"]
	var reach := int(CLIMB_REACH / LATTICE)
	var low_column := maxi(0, summit_column - reach)
	var high_column := mini(across - 1, summit_column + reach)
	var low_row := maxi(0, summit_row - reach)
	var high_row := mini(across - 1, summit_row + reach)

	var came_from := PackedInt32Array()
	came_from.resize(across * across)
	came_from.fill(-1)
	var seen := PackedByteArray()
	seen.resize(across * across)

	var queue := PackedInt32Array()
	var rim := 0
	for row in range(low_row, high_row + 1):
		for column in range(low_column, high_column + 1):
			var on_rim := row == low_row or row == high_row \
				or column == low_column or column == high_column
			if not on_rim:
				continue
			var index := row * across + column
			if solid[index] == 0:
				continue
			rim += 1
			seen[index] = 1
			came_from[index] = index
			queue.append(index)

	var target := summit_row * across + summit_column
	var head := 0
	var visited := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		visited += 1
		if index == target:
			break
		var column := index % across
		var row := index / across
		var height := heights[index]
		for offset in NEIGHBOURS:
			var next_column: int = column + offset.x
			var next_row: int = row + offset.y
			if next_column < low_column or next_column > high_column:
				continue
			if next_row < low_row or next_row > high_row:
				continue
			var next := next_row * across + next_column
			if seen[next] == 1 or solid[next] == 0:
				continue
			var rise := heights[next] - height
			if rise > STEP_UP or -rise > STEP_DOWN:
				continue
			seen[next] = 1
			came_from[next] = index
			queue.append(next)

	if seen[target] == 0:
		return {"reached": false, "rim": rim, "visited": visited}

	var path := []
	var walk := target
	while true:
		var column := walk % across
		var row := walk / across
		path.append({"at": _cell_position(grid, column, row), "height": heights[walk]})
		if came_from[walk] == walk:
			break
		walk = came_from[walk]
	path.reverse()

	# Walk the route again and check every step against the limits from
	# scratch, so the answer does not rest on the search having been written
	# correctly.
	var worst_rise := 0.0
	var worst_fall := 0.0
	for step in range(1, path.size()):
		var change: float = float(path[step]["height"]) - float(path[step - 1]["height"])
		worst_rise = maxf(worst_rise, change)
		worst_fall = maxf(worst_fall, -change)
		var moved: float = (path[step]["at"] as Vector2).distance_to(path[step - 1]["at"])
		assert(absf(moved - LATTICE) < 0.001, "a step left the lattice")
	assert(worst_rise <= STEP_UP + 0.000001, "a step up broke the limit")
	assert(worst_fall <= STEP_DOWN + 0.000001, "a step down broke the limit")
	return {
		"reached": true, "rim": rim, "visited": visited, "path": path,
		"worst_rise": worst_rise, "worst_fall": worst_fall,
	}


## The route, as one "x z height" line per cell, for a capture to draw.
func _write_trace(path_name: String, path: Array) -> void:
	var file := FileAccess.open(path_name, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % path_name)
		return
	for point in path:
		var at: Vector2 = point["at"]
		file.store_line("%.4f %.4f %.4f" % [at.x, at.y, float(point["height"])])
	file.close()
	print("climb trace %s points=%d" % [path_name, path.size()])


# --- the faces ------------------------------------------------------------


## How much of a mountain the step limits refuse.
##
## Two shares, because they say different things. *Steps refused* is the share
## of moves between neighbouring solid cells that the limits will not allow --
## how broken the surface is. *Cells cut off* is the share of solid cells the
## climb search never reached from the rim -- how much of the mountain is
## behind a wall. A mountain wants the first to be large and the second small:
## steep faces everywhere, and a way round them.
func _report_faces(grid: Dictionary, summits: Array) -> void:
	var sample := mini(SUMMIT_SAMPLE, summits.size())
	print("faces sample=%d reach=%.0f" % [sample, FACE_REACH])
	for rank in sample:
		var summit: Dictionary = summits[rank]
		print("face %s %s" % [
			_summit_name(rank), _face_shares(grid, int(summit["column"]), int(summit["row"])),
		])


func _face_shares(grid: Dictionary, summit_column: int, summit_row: int) -> String:
	var across: int = grid["across"]
	var heights: PackedFloat64Array = grid["heights"]
	var solid: PackedByteArray = grid["solid"]
	var reach := int(FACE_REACH / LATTICE)
	var reach_squared := reach * reach
	var route := _climb(grid, summit_column, summit_row)
	var reached := PackedByteArray()
	reached.resize(across * across)
	if bool(route["reached"]):
		# Re-run the flood from the rim without stopping at the summit, so the
		# cut-off share is measured against everything the rim can get to.
		reached = _reachable(grid, summit_column, summit_row)

	var steps := 0
	var refused := 0
	var cells := 0
	var cut_off := 0
	for row in range(maxi(0, summit_row - reach), mini(across, summit_row + reach + 1)):
		for column in range(maxi(0, summit_column - reach), mini(across, summit_column + reach + 1)):
			var dr := row - summit_row
			var dc := column - summit_column
			if dr * dr + dc * dc > reach_squared:
				continue
			var index := row * across + column
			if solid[index] == 0:
				continue
			cells += 1
			if reached[index] == 0:
				cut_off += 1
			for offset in NEIGHBOURS:
				var next_column: int = column + offset.x
				var next_row: int = row + offset.y
				if next_column < 0 or next_row < 0 or next_column >= across or next_row >= across:
					continue
				var next := next_row * across + next_column
				if solid[next] == 0:
					continue
				steps += 1
				var change := heights[next] - heights[index]
				if change > STEP_UP or -change > STEP_DOWN:
					refused += 1
	var step_share := 0.0 if steps == 0 else 100.0 * float(refused) / float(steps)
	var cut_share := 0.0 if cells == 0 else 100.0 * float(cut_off) / float(cells)
	return "cells=%d steps=%d refused=%d (%.1f%%) cut_off=%d (%.1f%%)" % [
		cells, steps, refused, step_share, cut_off, cut_share,
	]


## Everything the rim of the box can walk to, under the same limits. The climb
## search stops when it finds the summit; this one does not stop.
func _reachable(grid: Dictionary, summit_column: int, summit_row: int) -> PackedByteArray:
	var across: int = grid["across"]
	var heights: PackedFloat64Array = grid["heights"]
	var solid: PackedByteArray = grid["solid"]
	var reach := int(CLIMB_REACH / LATTICE)
	var low_column := maxi(0, summit_column - reach)
	var high_column := mini(across - 1, summit_column + reach)
	var low_row := maxi(0, summit_row - reach)
	var high_row := mini(across - 1, summit_row + reach)

	var seen := PackedByteArray()
	seen.resize(across * across)
	var queue := PackedInt32Array()
	for row in range(low_row, high_row + 1):
		for column in range(low_column, high_column + 1):
			var on_rim := row == low_row or row == high_row \
				or column == low_column or column == high_column
			if not on_rim:
				continue
			var index := row * across + column
			if solid[index] == 0:
				continue
			seen[index] = 1
			queue.append(index)

	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var column := index % across
		var row := index / across
		var height := heights[index]
		for offset in NEIGHBOURS:
			var next_column: int = column + offset.x
			var next_row: int = row + offset.y
			if next_column < low_column or next_column > high_column:
				continue
			if next_row < low_row or next_row > high_row:
				continue
			var next := next_row * across + next_column
			if seen[next] == 1 or solid[next] == 0:
				continue
			var rise := heights[next] - height
			if rise > STEP_UP or -rise > STEP_DOWN:
				continue
			seen[next] = 1
			queue.append(next)
	return seen


# --- arguments ------------------------------------------------------------


func _parse_args() -> Dictionary:
	var options := {
		"seed": DEFAULT_SEED,
		"span": DEFAULT_SPAN,
		"summit_floor": DEFAULT_SUMMIT_FLOOR,
		"trace": "",
	}
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var has_value := i + 1 < args.size()
		match args[i]:
			"--seed":
				if has_value and args[i + 1].is_valid_int():
					options["seed"] = args[i + 1].to_int()
			"--span":
				if has_value and args[i + 1].is_valid_float():
					options["span"] = args[i + 1].to_float()
			"--summit-floor":
				if has_value and args[i + 1].is_valid_float():
					options["summit_floor"] = args[i + 1].to_float()
			"--trace":
				if has_value:
					options["trace"] = args[i + 1]
	return options


# --- the board ------------------------------------------------------------


## What a tactical board reads on mountain ground.
##
## The board is laid on the same lattice this file searches routes on, and it
## enforces the same two numbers between neighbouring cells, so a steep face
## reaches the fight as *refused steps* rather than as holes. That distinction is
## worth stating with numbers rather than guessing at: a hole is somewhere with
## nothing to stand on, which on the ground still means water and nothing else,
## while a face is somewhere you can stand and cannot be stepped onto. A cliff
## edge is a third thing again -- a cell you can be shoved off.
##
## Two boards per summit: one laid on the summit itself and one on the steepest
## cell of its flank, so the numbers say what the fight is like both on the top
## and on the side.
func _report_boards(query: TerrainQuery, grid: Dictionary, summits: Array) -> void:
	var builder := CombatBoardBuilder.new(query)
	var sample := mini(SUMMIT_SAMPLE, summits.size())
	print("boards sample=%d (cell=%.2f, step up %.2f, step down %.2f)" % [
		sample, CombatBoard.CELL_SIZE, CombatBoard.STEP_UP, CombatBoard.STEP_DOWN,
	])
	for rank in sample:
		var summit: Dictionary = summits[rank]
		var top := _cell_position(grid, int(summit["column"]), int(summit["row"]))
		print("board %s top %s" % [_summit_name(rank), _board_line(builder, top)])
		var flank := _steepest_near(grid, int(summit["column"]), int(summit["row"]))
		print("board %s flank at (%.1f, %.1f) %s" % [
			_summit_name(rank), flank.x, flank.y, _board_line(builder, flank),
		])


## One board, as counts: how many cells, how many are holes, how many are cliff
## edges a unit can be shoved off, and how many steps between neighbouring cells
## the lattice refuses.
func _board_line(builder: CombatBoardBuilder, at: Vector2) -> String:
	var board := builder.build_on_ground(at.x, at.y)
	var cells := 0
	var holes := 0
	var cliffs := 0
	var steps := 0
	var refused := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			cells += 1
			if board.is_hole(cell):
				holes += 1
				continue
			if board.is_cliff_edge(cell):
				cliffs += 1
			for offset in NEIGHBOURS:
				var next: Vector2i = cell + offset
				if not board.contains(next) or board.is_hole(next):
					continue
				steps += 1
				var change := board.height_at(next) - board.height_at(cell)
				if change > CombatBoard.STEP_UP or -change > CombatBoard.STEP_DOWN:
					refused += 1
	var share := 0.0 if steps == 0 else 100.0 * float(refused) / float(steps)
	return "cells=%d holes=%d cliff_edges=%d steps=%d refused=%d (%.1f%%)" % [
		cells, holes, cliffs, steps, refused, share,
	]


## The steepest cell within a short walk of a summit: where the flank is.
func _steepest_near(grid: Dictionary, summit_column: int, summit_row: int) -> Vector2:
	var across: int = grid["across"]
	var heights: PackedFloat64Array = grid["heights"]
	var reach := int(FACE_REACH / LATTICE)
	var best := -INF
	var best_at := _cell_position(grid, summit_column, summit_row)
	for row in range(maxi(1, summit_row - reach), mini(across - 1, summit_row + reach + 1)):
		for column in range(maxi(1, summit_column - reach), mini(across - 1, summit_column + reach + 1)):
			var index := row * across + column
			var fall := maxf(
				absf(heights[index + 1] - heights[index - 1]),
				absf(heights[index + across] - heights[index - across]),
			)
			if fall > best:
				best = fall
				best_at = _cell_position(grid, column, row)
	return best_at
