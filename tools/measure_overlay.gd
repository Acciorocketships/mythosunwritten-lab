extends SceneTree
## What it costs to make a board square follow the ground, and how wrong it is
## if it does not.
##
##   ./tools/measure_overlay.sh                    # seed 1234
##   ./tools/measure_overlay.sh --seed 22 --at 42 84
##
## Four questions, and the subdivision and the height source are argued from
## them.
##
## *How wrong is one flat quad per cell?* Every cell is sampled on a fine grid
## and compared against the single height the cell used to be drawn at. That gap
## is the fault the user reported: half of it cuts into the hill and half of it
## floats off it.
##
## *How wrong is each subdivision?* For each n the tool builds the surface the
## overlay would draw and compares it, over the painted part of the cell, against
## the ground read on a much finer grid than any subdivision priced -- so the
## number is the error a pixel would see rather than an artefact of the probe.
##
## *What does each height source cost?* Two are priced. `exact` asks the terrain
## query for the surface at every sub-vertex, which is the same call the board
## builder makes per cell. `land` asks the water field for the carved land alone
## and hangs it off the cell height the builder already worked out, which skips
## the settlement pad and the road wear -- the two layers that cost almost all of
## the time -- and is the same simplification the distant ground already makes in
## its outer rings.
##
## *How often is a board rebuilt?* The overlay is rebuilt when the observer walks
## into a different cell, not every frame. This walks the simulation and counts,
## rather than assuming.
##
## Draws nothing, so it runs headless.

## Subdivisions to price. 1 is one quad per cell: the overlay before this work.
const LEVELS: Array[int] = [1, 2, 3, 4, 6, 8]

## How the drawn surface is compared against the real one.
const PROBE := 13

## The same shrink the overlay draws its squares at, so the error measured is the
## error over the part of the cell that is actually painted.
const FILL := 0.86

## Lifts to price the residual against: the share of the painted area the drawn
## ground would still stand above, and so poke through the square.
const LIFTS: Array[float] = [0.0, 0.02, 0.03, 0.045, 0.06, 0.09]

## How many ticks of walking to count board rebuilds over.
const WALK_TICKS := 400


func _initialize() -> void:
	var seed_value := 1234
	var sites: Array[Vector2] = []
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			seed_value = args[i + 1].to_int()
		if args[i] == "--at" and i + 2 < args.size():
			sites.append(Vector2(args[i + 1].to_float(), args[i + 2].to_float()))

	var terrain := TerrainQuery.for_seed(seed_value)
	var builder := CombatBoardBuilder.new(terrain)
	print("overlay-measure seed=%d cell=%.2f span=%.1f fill=%.2f ground_mesh_cell=%.2f" % [
		seed_value, CombatBoard.CELL_SIZE, CombatBoardBuilder.DEFAULT_SPAN, FILL,
		TerrainChunkMesher.CELL_SIZE,
	])

	if sites.is_empty():
		sites = _sites(terrain)
	for site in sites:
		_report_site(terrain, builder, site)

	# How often the overlay is rebuilt: once per cell the observer walks into.
	var sim := Simulation.new(seed_value)
	var cell := CombatBoard.cell_of(sim.world.observer_x, sim.world.observer_z)
	var changes := 0
	var walked := 0.0
	var was := Vector2(sim.world.observer_x, sim.world.observer_z)
	for _tick in WALK_TICKS:
		sim.step()
		var now := Vector2(sim.world.observer_x, sim.world.observer_z)
		walked += was.distance_to(now)
		was = now
		var here := CombatBoard.cell_of(now.x, now.y)
		if here != cell:
			cell = here
			changes += 1
	print("overlay-measure walk ticks=%d moved=%.1f rebuilds=%d every=%.1f_ticks=%.2f_s" % [
		WALK_TICKS, walked, changes,
		float(WALK_TICKS) / maxf(1.0, float(changes)),
		float(WALK_TICKS) / maxf(1.0, float(changes)) / 20.0,
	])
	quit()


func _report_site(terrain: TerrainQuery, builder: CombatBoardBuilder, site: Vector2) -> void:
	var board := builder.build_on_ground(site.x, site.y)
	print("")
	print("overlay-measure site=(%.1f, %.1f) biome=%s village=%s cells=%d relief=%.2f" % [
		site.x, site.y, terrain.biome_at(site.x, site.y),
		"yes" if terrain.settlement_at(site.x, site.y) != null else "no",
		board.cell_count(), _relief(board),
	])
	# The ground the drawn surface is judged against, read once per probe point
	# and kept, so every level below is judged against the same truth and the
	# probe's own cost is paid once rather than once per level.
	var truth := _truth(board, terrain)
	var flat := _run(board, terrain, 0, truth, true)
	print("overlay-measure  flat (one height per cell, as it was drawn before):"
		+ " vertices=%d samples=0 worst=%.3f mean=%.3f" % [
			6 * board.cell_count(), flat["worst"], flat["mean"],
		])
	print("overlay-measure  n | vertices | samples |"
		+ " exact: cold_ms step_ms worst mean |"
		+ " land: cold_ms step_ms worst mean")
	for n in LEVELS:
		var exact := _run(board, terrain, n, truth, true)
		var land := _run(board, terrain, n, truth, false)
		print("overlay-measure  %d | %8d | %7d | %8.0f %7.1f %6.3f %6.4f | %8.0f %7.1f %6.3f %6.4f" % [
			n, 6 * n * n * board.cell_count() + 8 * n * board.cell_count(),
			int(exact["samples"]),
			exact["cold_ms"], exact["step_ms"], exact["worst"], exact["mean"],
			land["cold_ms"], land["step_ms"], land["worst"], land["mean"],
		])
	var sag := _mesh_above_field(board, terrain)
	print("overlay-measure  ground mesh above the sampled field: worst=%.4f mean=%.4f"
		% [sag["worst"], sag["mean"]]
		+ " -- what the lift has to clear")
	var shares := PackedStringArray()
	for candidate in LIFTS:
		shares.append("%.2f:%.3f%%" % [candidate, 100.0 * float(sag[candidate])])
	print("overlay-measure  painted area the ground would still poke through, by lift: "
		+ " ".join(shares))
	print("overlay-measure  (cold_ms builds every cell; step_ms is the %d cells one"
		% board.cells_across
		+ " step of walking exposes, which is all a cached board rebuilds)")


## Three sites worth judging on: the steepest grassy ground within reach of the
## origin, a village (where the pad and the road are what the cheap height source
## leaves out), and the origin itself.
func _sites(terrain: TerrainQuery) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var best := Vector2.ZERO
	var best_fall := -1.0
	var village := Vector2.ZERO
	var step := CombatBoard.CELL_SIZE * 2.0
	for row in range(-40, 41):
		for column in range(-40, 41):
			var x := float(column) * step
			var z := float(row) * step
			if terrain.is_water_at(x, z) or terrain.is_over_island_at(x, z):
				continue
			if terrain.settlement_at(x, z) != null and village == Vector2.ZERO:
				village = Vector2(x, z)
			var biome := terrain.biome_at(x, z)
			if biome != "meadow" and biome != "blossom_grove":
				continue
			if terrain.is_reserved_at(x, z, 4.0):
				continue
			var here := terrain.ground_height_at(x, z)
			var fall := 0.0
			var wet := false
			for offset in [
				Vector2(-6.0, 0.0), Vector2(6.0, 0.0),
				Vector2(0.0, -6.0), Vector2(0.0, 6.0),
			]:
				if terrain.is_water_at(x + offset.x, z + offset.y):
					wet = true
					break
				fall = maxf(fall, absf(
					terrain.ground_height_at(x + offset.x, z + offset.y) - here
				))
			if wet:
				continue
			# A slope a square can lie on, not a cliff a square cannot: the
			# fault reported is a square on a hillside, and a vertical face is
			# not a thing any subdivision draws.
			if fall > best_fall and fall < CombatBoard.CELL_SIZE:
				best_fall = fall
				best = Vector2(x, z)
	found.append(best)
	if village != Vector2.ZERO:
		found.append(village)
	return found


## The height between the highest and the lowest cell of a board.
func _relief(board: CombatBoard) -> float:
	var low := INF
	var high := -INF
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			if board.is_hole(cell):
				continue
			var height := board.height_at(cell)
			low = minf(low, height)
			high = maxf(high, height)
	return 0.0 if low > high else high - low


## The real surface under every probe point of every painted cell, read once.
func _truth(board: CombatBoard, terrain: TerrainQuery) -> Dictionary:
	var out := {}
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			if board.is_hole(cell):
				continue
			var middle := board.centre(cell)
			var height := board.height_at(cell)
			var half := board.cell_size * FILL * 0.5
			var probes := PackedFloat64Array()
			probes.resize(PROBE * PROBE)
			for down in PROBE:
				for across in PROBE:
					var x := middle.x - half + 2.0 * half * float(across) / float(PROBE - 1)
					var z := middle.y - half + 2.0 * half * float(down) / float(PROBE - 1)
					var found := terrain.support_at(x, z, height)
					probes[down * PROBE + across] = height if found == -INF else found
			out[cell] = probes
	return out


## Build the surface the overlay would draw at subdivision n, from one of the two
## height sources, and say what it cost and how far it is from the ground.
func _run(
	board: CombatBoard,
	terrain: TerrainQuery,
	n: int,
	truth: Dictionary,
	sample_exactly: bool,
) -> Dictionary:
	var samples := 0
	var worst := 0.0
	var total := 0.0
	var counted := 0
	var micros := 0
	var step_micros := 0
	var step_cells := board.cells_across
	var done_cells := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var middle := board.centre(cell)
			var height := board.height_at(cell)
			var half := board.cell_size * FILL * 0.5
			var hole := board.is_hole(cell)
			var corner := PackedFloat64Array()
			corner.resize((n + 1) * (n + 1))
			var began := Time.get_ticks_usec()
			var anchor := 0.0
			if not sample_exactly and not hole:
				anchor = terrain.water_field.sample_column(middle.x, middle.y).x
				samples += 1
			var span := float(maxi(n, 1))
			for down in n + 1:
				for across in n + 1:
					var x := middle.x - half + 2.0 * half * float(across) / span
					var z := middle.y - half + 2.0 * half * float(down) / span
					var y := height
					if not hole and n > 0:
						if sample_exactly:
							var found := terrain.support_at(x, z, height)
							if found > -INF:
								y = found
						else:
							y = height + (
								terrain.water_field.sample_column(x, z).x - anchor
							)
						samples += 1
					corner[down * (n + 1) + across] = y
			micros += Time.get_ticks_usec() - began
			done_cells += 1
			if done_cells <= step_cells:
				step_micros = micros
			if hole:
				continue
			var probes: PackedFloat64Array = truth[cell]
			for down in PROBE:
				for across in PROBE:
					var u := float(across) / float(PROBE - 1)
					var v := float(down) / float(PROBE - 1)
					var gap := absf(
						_lerp_patch(corner, n, u, v) - probes[down * PROBE + across]
					)
					worst = maxf(worst, gap)
					total += gap
					counted += 1
	return {
		"samples": samples,
		"cold_ms": float(micros) / 1000.0,
		"step_ms": float(step_micros) / 1000.0,
		"worst": worst,
		"mean": 0.0 if counted == 0 else total / float(counted),
	}


## How far the drawn ground stands above the field the overlay samples.
##
## The overlay samples the terrain's own height function; the ground it lies on
## is that function read on a 2-unit lattice and joined by flat triangles. Where
## the ground is convex the triangle cuts the corner and stands *above* the
## function, and a square drawn at the function would sink into it. This is the
## number the lift has to clear, and it is why the lift cannot simply be zero.
func _mesh_above_field(board: CombatBoard, terrain: TerrainQuery) -> Dictionary:
	var worst := 0.0
	var total := 0.0
	var counted := 0
	var over := {}
	for candidate in LIFTS:
		over[candidate] = 0
	var mesh_cell := TerrainChunkMesher.CELL_SIZE
	var lattice := {}
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			if board.is_hole(cell) or board.storey_at(cell) != CombatBoard.GROUND_STOREY:
				continue
			var middle := board.centre(cell)
			var half := board.cell_size * FILL * 0.5
			for down in 5:
				for across in 5:
					var x := middle.x - half + 2.0 * half * float(across) / 4.0
					var z := middle.y - half + 2.0 * half * float(down) / 4.0
					var at := Vector2i(floori(x / mesh_cell), floori(z / mesh_cell))
					var u := x / mesh_cell - float(at.x)
					var v := z / mesh_cell - float(at.y)
					var tl := _lattice_height(lattice, terrain, at, mesh_cell)
					var tr := _lattice_height(lattice, terrain, at + Vector2i(1, 0), mesh_cell)
					var bl := _lattice_height(lattice, terrain, at + Vector2i(0, 1), mesh_cell)
					var br := _lattice_height(lattice, terrain, at + Vector2i(1, 1), mesh_cell)
					# The mesher writes (TL, TR, BL) and (TR, BR, BL).
					var drawn := 0.0
					if u + v <= 1.0:
						drawn = tl + (tr - tl) * u + (bl - tl) * v
					else:
						drawn = br + (bl - br) * (1.0 - u) + (tr - br) * (1.0 - v)
					var gap := drawn - terrain.ground_height_at(x, z)
					worst = maxf(worst, gap)
					total += maxf(0.0, gap)
					counted += 1
					for candidate in LIFTS:
						if gap > candidate:
							over[candidate] = int(over[candidate]) + 1
	var out := {
		"worst": worst,
		"mean": 0.0 if counted == 0 else total / float(counted),
	}
	for candidate in LIFTS:
		out[candidate] = 0.0 if counted == 0 else float(over[candidate]) / float(counted)
	return out


func _lattice_height(
	lattice: Dictionary, terrain: TerrainQuery, at: Vector2i, mesh_cell: float
) -> float:
	if not lattice.has(at):
		lattice[at] = terrain.ground_height_at(float(at.x) * mesh_cell, float(at.y) * mesh_cell)
	return float(lattice[at])


## The height of the drawn patch at (u, v) inside a cell: the quad that point
## falls in, read across the two triangles it is drawn as.
func _lerp_patch(corner: PackedFloat64Array, n: int, u: float, v: float) -> float:
	if n == 0:
		return corner[0]
	var across := mini(int(u * float(n)), n - 1)
	var down := mini(int(v * float(n)), n - 1)
	var fu := u * float(n) - float(across)
	var fv := v * float(n) - float(down)
	var wide := n + 1
	var a: float = corner[down * wide + across]
	var b: float = corner[down * wide + across + 1]
	var c: float = corner[(down + 1) * wide + across + 1]
	var d: float = corner[(down + 1) * wide + across]
	if fu + fv <= 1.0:
		return a + (b - a) * fu + (d - a) * fv
	return c + (d - c) * (1.0 - fu) + (b - c) * (1.0 - fv)
