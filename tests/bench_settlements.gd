extends SceneTree
## What the settlement layer costs to build, and how many villages it places.
##
## Two numbers, and both are about the same call: `_pad_ground`'s overhead test
## is where this layer's cost lives, because it is the one gate that asks the
## aerial layer above it a question, and an island cell costs far more to settle
## than a ground sample does.
##
##   * count -- villages found over the same seeds and the same square of
##     settlement cells that tests/test_window_glow.gd samples, which is the
##     sample the suite's size guard is written against, each printed with its
##     digest so two runs can be diffed village by village rather than only by
##     count.
##   * cost -- microseconds per settlement cell decided, warm and cold. Warm is
##     what a walk pays (one field, its island memo filling as it goes); cold is
##     what one cell costs on its own, out of a field that has never been asked
##     anything (a fresh TerrainQuery per cell), which is the number a change to
##     the overhead question moves most.
##
## Run it with:
##   ./run_tests.sh is not this; use
##   env -u DISPLAY -u WAYLAND_DISPLAY tools/godot/godot4 --headless --path . \
##       --script res://tests/bench_settlements.gd
##
## Pass `--ungated` to run the same numbers with `IslandField`'s per-cell gate
## turned off -- the shared cell scan then builds every cell in range, which is
## what the layer did before the gate went in. That is the "before" column: the
## same code, the same fields and the same positions, differing only in whether
## a cell whose candidate cannot reach is built before being discarded.
##
## Nothing here is part of the world or of the suite: it builds fields, counts,
## times them, and prints.

const SEEDS := [1234, 7, 3, 19, 42, 101]
const CELL_REACH := 2
## How many cells the cold timing uses, per seed. Fewer than the count sweep,
## because each one pays for a whole fresh field.
const COLD_CELLS := 9


## Whether the island layer's per-cell gate is on for this run. Off is not a
## different world -- it is the same answers, reached by building every cell in
## range and discarding the ones that turn out to be too far.
var gated := true


func _initialize() -> void:
	gated = not OS.get_cmdline_user_args().has("--ungated")
	print("bench settlements gate=%s" % ("on" if gated else "off"))
	var total := 0
	var warm_usec := 0
	for world_seed: int in SEEDS:
		var field := _fields(world_seed).settlement_field
		var placed: Array[Settlement] = []
		var started := Time.get_ticks_usec()
		for cell_x in range(-CELL_REACH, CELL_REACH + 1):
			for cell_z in range(-CELL_REACH, CELL_REACH + 1):
				var site := field.settlement_in_cell(Vector2i(cell_x, cell_z))
				if site != null:
					placed.append(site)
		warm_usec += Time.get_ticks_usec() - started
		total += placed.size()
		# Which villages, not just how many. A change that is only meant to cost
		# less has to leave every village exactly where it was, and a count on
		# its own cannot tell a village that moved from one that stayed. The
		# digest is the same text the determinism suite compares villages by, so
		# two runs of this bench diff placement by placement. It is taken after
		# the clock stops, because it is evidence and not part of what is timed.
		var marks := PackedStringArray()
		for site in placed:
			marks.append(site.digest())
		print("bench settlements seed=%d cells=%d villages=%d sites=%s" % [
			world_seed, (2 * CELL_REACH + 1) * (2 * CELL_REACH + 1),
			placed.size(), " ".join(marks),
		])
	var cells := SEEDS.size() * (2 * CELL_REACH + 1) * (2 * CELL_REACH + 1)
	print("bench settlements seeds=%d cells=%d villages=%d warm_usec_per_cell=%.0f" % [
		SEEDS.size(), cells, total, float(warm_usec) / float(cells),
	])

	var cold_usec := 0
	var cold_cells := 0
	var cold_villages := 0
	var reach := int(sqrt(float(COLD_CELLS))) / 2
	for world_seed: int in SEEDS:
		for cell_x in range(-reach, reach + 1):
			for cell_z in range(-reach, reach + 1):
				var field := _fields(world_seed).settlement_field
				var started := Time.get_ticks_usec()
				var site := field.settlement_in_cell(Vector2i(cell_x, cell_z))
				cold_usec += Time.get_ticks_usec() - started
				cold_cells += 1
				if site != null:
					cold_villages += 1
	print("bench settlements cold cells=%d villages=%d cold_usec_per_cell=%.0f" % [
		cold_cells, cold_villages, float(cold_usec) / float(cold_cells),
	])

	_time_the_overhead_question()
	quit(0)


## A whole terrain stack for a seed, with the island gate set as this run wants
## it. Everything the bench times goes through here, so `--ungated` reaches the
## settlement timings as well as the overhead one.
func _fields(world_seed: int) -> TerrainQuery:
	var query := TerrainQuery.for_seed(world_seed)
	query.island_field.gate_cells_by_candidate = gated
	return query


## What the overhead question itself costs.
##
## Three forms, on the same positions and out of equally cold fields:
##
##   * `padded-lower` -- the form before the veto was corrected: the lower storey
##     alone, with the radius widened by the widest island there is.
##   * `both-storeys` -- the corrected veto: each walkable storey asked directly
##     with the pad's own radius, and every cell of both bands built to answer.
##   * `both-storeys-gated` -- the same corrected veto, with `IslandField.could_reach`
##     asked of the hashes first so a band no island could reach is never built.
##     The answer is identical to `both-storeys`; only the price differs. This is
##     the band-level gate, which skips a whole storey or none of it; the
##     per-cell gate inside the scan is underneath all three forms and is what
##     `--ungated` turns off.
##
## Timing the question rather than the layer is the point: the corrected rule
## also places more villages, and a village that is placed pays for a layout the
## refused ones do not, so a per-cell number cannot separate the two.
func _time_the_overhead_question() -> void:
	var spots := PackedVector2Array()
	for i in 24:
		spots.append(Vector2(
			float((i * 173) % 601) - 300.0, float((i * 331) % 601) - 300.0
		))
	var radius := SettlementField.PAD_RADIUS_MAX

	for form in ["padded-lower", "both-storeys", "both-storeys-gated"]:
		var elapsed := 0
		var refused := 0
		var built := 0
		for world_seed: int in SEEDS:
			for spot in spots:
				var field := _fields(world_seed).island_field
				var started := Time.get_ticks_usec()
				var clear := true
				if form == "padded-lower":
					clear = field.islands_near(
						FloatingIsland.AERIAL, spot.x, spot.y,
						radius + IslandField.AERIAL_RADIUS_MAX
					).is_empty()
				elif form == "both-storeys":
					for band in FloatingIsland.WALKABLE_BANDS:
						if not field.islands_near(band, spot.x, spot.y, radius).is_empty():
							clear = false
							break
				else:
					for band in FloatingIsland.WALKABLE_BANDS:
						if not field.could_reach(band, spot.x, spot.y, radius):
							continue
						if not field.islands_near(band, spot.x, spot.y, radius).is_empty():
							clear = false
							break
				elapsed += Time.get_ticks_usec() - started
				# How many cells the field actually built to answer, which is
				# what the ask costs: everything else here is hashes. The field
				# is fresh per ask, so this is that ask's own count. Taken after
				# the clock stops -- it is evidence, not part of what is timed.
				built += field.builds
				if not clear:
					refused += 1
		var asked := SEEDS.size() * spots.size()
		print(("bench overhead form=%s asked=%d refused=%d usec_per_ask=%.0f "
			+ "builds_per_ask=%.2f") % [
			form, asked, refused, float(elapsed) / float(asked),
			float(built) / float(asked),
		])
