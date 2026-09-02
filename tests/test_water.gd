extends TestSuite
## Whether a position is water is a fact about the position, and about nothing
## else.
##
## That is the claim the rest of the project will lean on. The prop layer will
## ask where the banks are, the path layer will ask where a bridge belongs, and
## the tactical layer will ask which cells are holes in its board -- and none of
## them can be right unless all of them get the same answer for the same place,
## whatever has been built, in whatever order, in whichever process. So the
## suite asks the same questions from fresh fields, from busy ones, from meshers
## that built the neighbourhood first, and from two separate runs of the headless
## command, and insists on one answer.
##
## The second half is about the sheet the water is drawn as: that it is one
## surface on a lattice fixed to the world rather than a tile per chunk, that
## two overlapping windows onto it agree exactly where they overlap -- which is
## the seamlessness, stated as arithmetic rather than as a look -- and that what
## a viewer is handed is a copy it cannot edit the world through.
class_name TestWater

const SEED := 20250825
const OTHER_SEED := 41

## A seed whose ground near the origin has a river running across it, found with
## the headless water report. The tests that need water in view rather than
## merely a consistent answer about its absence use this one.
const RIVER_SEED := 19


func _init() -> void:
	suite_name = "water"


func run() -> void:
	_being_water_is_a_pure_function_of_the_position()
	_water_ignores_chunk_build_order()
	_the_carving_reaches_the_ground()
	_banks_are_the_dry_edge_of_the_water()
	_water_is_impassable_ground()
	_the_sheet_is_one_world_lattice_not_a_tile_per_chunk()
	_the_sheet_handed_to_a_viewer_cannot_reach_the_world()
	_water_matches_across_processes()


func _being_water_is_a_pure_function_of_the_position() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var again := TerrainQuery.for_seed(SEED)
	var probes := _probe_positions()

	for probe in probes:
		equal(again.is_water_at(probe.x, probe.y), terrain.is_water_at(probe.x, probe.y),
			"two queries with the same seed disagree about water at (%f, %f)"
			% [probe.x, probe.y])
		equal(again.water_depth_at(probe.x, probe.y), terrain.water_depth_at(probe.x, probe.y),
			"two queries with the same seed disagree about depth at (%f, %f)"
			% [probe.x, probe.y])

	# The same questions in a different order, with a pile of unrelated samples
	# in between. A field drawing from a random stream would drift here.
	var first_pass: Array[bool] = []
	for probe in probes:
		first_pass.append(terrain.is_water_at(probe.x, probe.y))
	for i in 400:
		terrain.is_water_at(float(i) * 6.7, float(i) * -4.3)
		terrain.ground_height_at(float(i) * -2.1, float(i) * 9.9)
	for index in range(probes.size() - 1, -1, -1):
		var probe: Vector2 = probes[index]
		equal(terrain.is_water_at(probe.x, probe.y), first_pass[index],
			"the water changed its answer at (%f, %f) after other samples"
			% [probe.x, probe.y])

	# There is water to be wrong about, and dry land too, so the checks above
	# are not passing on a world that is uniformly one or the other.
	var wet := 0
	var samples := 0
	for row in 60:
		for column in 60:
			samples += 1
			if terrain.is_water_at(float(column) * 9.0 - 270.0, float(row) * 9.0 - 270.0):
				wet += 1
	check(wet > samples / 100, "seed %d has almost no water: %d of %d samples"
		% [SEED, wet, samples])
	check(wet < samples / 2, "seed %d is mostly water: %d of %d samples"
		% [SEED, wet, samples])

	# And the map depends on the seed, so agreeing is not the same as being
	# constant.
	var other := TerrainQuery.for_seed(OTHER_SEED)
	# Compared on the water surface, which is defined on dry land too: comparing
	# depth would compare zero with zero almost everywhere and pass for free.
	var differences := 0
	for i in 400:
		var x := float(i) * 13.0 - 2600.0
		if terrain.water_surface_at(x, 21.0) != other.water_surface_at(x, 21.0):
			differences += 1
	check(differences > 350,
		"two seeds produced nearly the same water: %d of 400 samples differed"
		% differences)


func _water_ignores_chunk_build_order() -> void:
	# The point of the layer is that nothing about generation order reaches it.
	# A mesher that has built the whole neighbourhood must answer exactly as one
	# that has built nothing.
	var busy := TerrainQuery.for_seed(RIVER_SEED)
	var mesher := TerrainChunkMesher.new(busy)
	var fresh := TerrainQuery.for_seed(RIVER_SEED)
	var probes := _probe_positions()

	var before: Array[float] = []
	for probe in probes:
		before.append(busy.water_depth_at(probe.x, probe.y))

	for chunk_x in range(-4, 5):
		for chunk_z in range(4, -5, -1):
			mesher.build(chunk_x, chunk_z)

	for index in probes.size():
		var probe: Vector2 = probes[index]
		equal(busy.water_depth_at(probe.x, probe.y), before[index],
			"building forty chunks changed the water at (%f, %f)" % [probe.x, probe.y])
		equal(busy.water_depth_at(probe.x, probe.y), fresh.water_depth_at(probe.x, probe.y),
			"a query that had built chunks disagreed with a fresh one at (%f, %f)"
			% [probe.x, probe.y])

	# The same holds through a whole world, which builds chunks for its own
	# reasons and in its own order as the observer walks.
	var world := SimWorld.new(RIVER_SEED)
	for i in 30:
		world.step()
	for probe in probes:
		equal(world.terrain.is_water_at(probe.x, probe.y),
			fresh.is_water_at(probe.x, probe.y),
			"a world thirty ticks in disagreed with a bare query at (%f, %f)"
			% [probe.x, probe.y])


func _the_carving_reaches_the_ground() -> void:
	# Water is not painted on top of the landscape; it is cut into it. So the
	# ground the mesher builds has to be lower under water than the uncarved
	# height field is, and the water's surface has to be above that bed.
	var terrain := TerrainQuery.for_seed(RIVER_SEED)
	var carved := 0
	var checked := 0
	for row in 90:
		for column in 90:
			var x := float(column) * 3.0 - 135.0
			var z := float(row) * 3.0 - 135.0
			if not terrain.is_water_at(x, z):
				continue
			checked += 1
			if terrain.ground_height_at(x, z) < terrain.base_height_at(x, z) - 0.001:
				carved += 1
	check(checked > 50, "expected water in view of seed %d, found %d wet samples"
		% [RIVER_SEED, checked])
	equal(carved, checked,
		"%d of %d wet positions were not cut into the height field at all"
		% [checked - carved, checked])

	# Depth is the water surface above that bed, everywhere, wet or dry.
	for probe in _probe_positions():
		var expected := maxf(
			0.0, terrain.water_surface_at(probe.x, probe.y)
				- terrain.ground_height_at(probe.x, probe.y)
		)
		equal(terrain.water_depth_at(probe.x, probe.y), expected,
			"depth at (%f, %f) is not the surface above the bed" % [probe.x, probe.y])

	# On dry land the water surface is below the ground, which is the same
	# statement as there being no water there.
	var dry_checked := 0
	for row in 40:
		for column in 40:
			var x := float(column) * 7.0 - 140.0
			var z := float(row) * 7.0 - 140.0
			if terrain.is_water_at(x, z):
				continue
			dry_checked += 1
			check(terrain.water_surface_at(x, z) <= terrain.ground_height_at(x, z),
				"dry ground at (%f, %f) has its water surface above it" % [x, z])
	check(dry_checked > 100, "expected dry ground to check, found %d" % dry_checked)


func _banks_are_the_dry_edge_of_the_water() -> void:
	var terrain := TerrainQuery.for_seed(RIVER_SEED)
	var banks := 0
	for row in 90:
		for column in 90:
			var x := float(column) * 3.0 - 135.0
			var z := float(row) * 3.0 - 135.0
			if not terrain.is_bank_at(x, z):
				continue
			banks += 1
			# A bank is dry ground...
			check(not terrain.is_water_at(x, z),
				"(%f, %f) is reported as both water and a bank" % [x, z])
			# ...with water within reach of it.
			var near_water := false
			for direction in WaterField.BANK_DIRECTIONS:
				var angle := TAU * float(direction) / float(WaterField.BANK_DIRECTIONS)
				if terrain.is_water_at(
					x + cos(angle) * WaterField.BANK_REACH,
					z + sin(angle) * WaterField.BANK_REACH,
				):
					near_water = true
					break
			check(near_water, "(%f, %f) is reported as a bank with no water in reach"
				% [x, z])
	check(banks > 20, "expected banks around the water of seed %d, found %d"
		% [RIVER_SEED, banks])

	# A bank is an edge, not a synonym for dry: most dry ground is not one.
	var dry := 0
	var dry_banks := 0
	for row in 90:
		for column in 90:
			var x := float(column) * 3.0 - 135.0
			var z := float(row) * 3.0 - 135.0
			if terrain.is_water_at(x, z):
				continue
			dry += 1
			if terrain.is_bank_at(x, z):
				dry_banks += 1
	check(dry_banks * 4 < dry,
		"%d of %d dry positions were banks, which is not an edge" % [dry_banks, dry])


func _water_is_impassable_ground() -> void:
	# The tactical layer will read this as a hole in its board, so the two must
	# be the same answer rather than two answers that usually agree.
	var terrain := TerrainQuery.for_seed(RIVER_SEED)
	var wet := 0
	for row in 60:
		for column in 60:
			var x := float(column) * 4.0 - 120.0
			var z := float(row) * 4.0 - 120.0
			var is_water := terrain.is_water_at(x, z)
			if is_water:
				wet += 1
			equal(terrain.is_passable_at(x, z), not is_water,
				"passability at (%f, %f) does not follow the water" % [x, z])
	check(wet > 20, "expected water to check passability against, found %d" % wet)

	# And the composed answer agrees with the separate ones, so a caller may use
	# either without them drifting apart.
	for probe in _probe_positions():
		var ground := terrain.ground_at(probe.x, probe.y)
		equal(ground["water"], terrain.is_water_at(probe.x, probe.y),
			"ground_at disagrees about water at (%f, %f)" % [probe.x, probe.y])
		equal(ground["bank"], terrain.is_bank_at(probe.x, probe.y),
			"ground_at disagrees about the bank at (%f, %f)" % [probe.x, probe.y])
		equal(ground["passable"], terrain.is_passable_at(probe.x, probe.y),
			"ground_at disagrees about passability at (%f, %f)" % [probe.x, probe.y])
		equal(ground["height"], terrain.ground_height_at(probe.x, probe.y),
			"ground_at disagrees about the ground height at (%f, %f)"
			% [probe.x, probe.y])


func _the_sheet_is_one_world_lattice_not_a_tile_per_chunk() -> void:
	var terrain := TerrainQuery.for_seed(RIVER_SEED)
	var builder := WaterSheetBuilder.new(terrain)

	# One sheet spans many chunks. If the water were tiled per chunk this could
	# not be true of a single build.
	var sheet := builder.build(Vector2.ZERO)
	var span_in_chunks := (sheet.max_x - sheet.min_x) / TerrainChunkMesher.CHUNK_SIZE
	check(span_in_chunks >= 4.0,
		"one sheet spans %f chunks, which is not enough to be a sheet" % span_in_chunks)
	check(sheet.wet_cells > 0,
		"expected water in the sheet at the origin of seed %d" % RIVER_SEED)

	# Two windows that overlap agree exactly about every corner in the overlap.
	# This is the seam: if the sheet's corners were placed relative to the
	# window, or its heights derived from anything the window knows, a corner in
	# both would land in two places, and where two such sheets met there would
	# be a visible crease. They are placed on a lattice fixed to the world
	# instead, so the same world position is the same vertex in both.
	var moved := builder.build(Vector2(WaterSheetBuilder.WINDOW_STEP * 2.0, 0.0))
	var shared := _shared_vertices(sheet, moved)
	check(shared.size() > 200,
		"the two windows only shared %d vertices, so the comparison is weak"
		% shared.size())
	for entry in shared:
		equal(entry["b"], entry["a"],
			"two windows placed the corner at %s at different heights"
			% entry["at"])

	# The corners sit on the world's lattice, not on a chunk's grid.
	for vertex in sheet.vertices:
		var on_lattice_x := absf(fmod(vertex.x, WaterSheetBuilder.CELL_SIZE)) < 0.0001
		var on_lattice_z := absf(fmod(vertex.z, WaterSheetBuilder.CELL_SIZE)) < 0.0001
		check(on_lattice_x and on_lattice_z,
			"a sheet corner at (%f, %f) is off the world lattice" % [vertex.x, vertex.z])
		break

	# Rebuilding the same window is the same sheet, in either order.
	equal(builder.build(Vector2.ZERO).digest(), sheet.digest(),
		"rebuilding the sheet for the same window produced different water")
	var other_builder := WaterSheetBuilder.new(TerrainQuery.for_seed(RIVER_SEED))
	equal(other_builder.build(Vector2.ZERO).digest(), sheet.digest(),
		"a fresh builder for the same seed produced different water")

	# Every wet corner's height really is the water surface there, so the sheet
	# is a picture of the field rather than a second opinion about it.
	for i in mini(sheet.vertices.size(), 400):
		var vertex := sheet.vertices[i]
		var expected := maxf(
			terrain.water_surface_at(vertex.x, vertex.z),
			terrain.ground_height_at(vertex.x, vertex.z),
		)
		check(absf(vertex.y - expected) < 0.0005,
			"a sheet corner at (%f, %f) sits at %f, not at the water's %f"
			% [vertex.x, vertex.z, vertex.y, expected])


func _the_sheet_handed_to_a_viewer_cannot_reach_the_world() -> void:
	var world := SimWorld.new(RIVER_SEED)
	var before := world.digest()
	var live := world.live_water_sheet()
	check(live != null, "a fresh world should have its water built")
	if live == null:
		return

	# First: a write into the water the world is holding must show up in its
	# fingerprint. Without this, the check that follows would pass for the wrong
	# reason -- "the digest did not move" would be indistinguishable from "the
	# digest never notices water at all".
	check(live.vertices.size() > 0,
		"expected water at the origin of seed %d for this check" % RIVER_SEED)
	if live.vertices.size() == 0:
		return
	var original: Vector3 = live.vertices[0]
	live.vertices[0] = original + Vector3(0.0, 0.001, 0.0)
	not_equal(world.digest(), before,
		"a write into the world's own water left its fingerprint unchanged")
	live.vertices[0] = original
	equal(world.digest(), before, "undoing the write did not restore the fingerprint")

	# Then: what a viewer is handed is a copy, so the same write through it
	# reaches nothing.
	var handle := world.water_sheet()
	equal(handle.digest(), live.digest(),
		"the handed-out sheet is not the same water as the world's")
	handle.vertices[0] = original + Vector3(0.0, 5.0, 0.0)
	handle.colors[0] = Color(1.0, 0.0, 1.0, 1.0)
	equal(world.digest(), before,
		"writing into the handed-out water sheet changed the world")
	equal(world.live_water_sheet().digest(), live.digest(),
		"writing into the handed-out water sheet changed the world's own sheet")

	# And the fingerprint reads the world's water rather than a copy of it,
	# which is what the counter is for.
	var handed_before := world.water_sheets_handed_out
	world.digest()
	equal(world.water_sheets_handed_out, handed_before,
		"fingerprinting the world copied the water sheet")

	# The sheet is rebuilt when the window moves and not before, so a viewer
	# that watches the version number is not copying it every tick.
	var version := world.water_sheet_version
	world.step()
	equal(world.water_sheet_version, version,
		"one tick of walking rebuilt the water sheet")
	for i in 200:
		world.step()
	check(world.water_sheet_version > version,
		"two hundred ticks of walking never rebuilt the water sheet")


func _water_matches_across_processes() -> void:
	# The claim is about separate runs, so this really runs the headless command
	# twice, in two fresh processes, and asks each for its water map.
	var first := _run_headless_water(RIVER_SEED)
	var second := _run_headless_water(RIVER_SEED)
	equal(first["exit_code"], 0,
		"headless run should exit 0 (output: %s)" % first["output"])
	var lines: PackedStringArray = first["water"]
	check(lines.size() > 100,
		"expected the headless run to report its water map, got %d line(s)"
		% lines.size())
	equal(first["water"], second["water"],
		"two separate runs of seed %d produced different water" % RIVER_SEED)

	# And the same positions, answered here in this process, come out identical:
	# the map belongs to the seed, not to the run.
	var terrain := TerrainQuery.for_seed(RIVER_SEED)
	var rebuilt := PackedStringArray()
	var wet := 0
	for line in lines:
		var parts := line.split(" ")
		var x := float(parts[1])
		var z := float(parts[2])
		var ground := terrain.ground_at(x, z)
		if bool(ground["water"]):
			wet += 1
		rebuilt.append("water %.1f %.1f %d %d %.4f %.4f" % [
			x, z,
			1 if bool(ground["water"]) else 0,
			1 if bool(ground["bank"]) else 0,
			float(ground["water_depth"]),
			float(ground["height"]),
		])
	equal(rebuilt, lines,
		"answering seed %d's water in this process gave a different map" % RIVER_SEED)
	check(wet > 0,
		"the reported lattice found no water at all, so the comparison is weak")


## Positions to ask about: a spread of scales and signs, including exact
## integers, exact lattice corners and points between them.
func _probe_positions() -> Array[Vector2]:
	return [
		Vector2(0.0, 0.0), Vector2(2.0, -4.0), Vector2(13.5, -207.25),
		Vector2(-1024.0, 512.0), Vector2(3.125, 3.125), Vector2(-0.5, -0.5),
		Vector2(16.0, 16.0), Vector2(-33.0, 47.0), Vector2(101.75, -88.5),
	]


## Every vertex position two sheets both carry, with each sheet's height for it.
func _shared_vertices(a: WaterSheet, b: WaterSheet) -> Array[Dictionary]:
	var from_a := {}
	for vertex in a.vertices:
		from_a["%.3f,%.3f" % [vertex.x, vertex.z]] = vertex.y
	var shared: Array[Dictionary] = []
	var seen := {}
	for vertex in b.vertices:
		var at := "%.3f,%.3f" % [vertex.x, vertex.z]
		if not from_a.has(at) or seen.has(at):
			continue
		seen[at] = true
		shared.append({"at": at, "a": from_a[at], "b": vertex.y})
	return shared


func _run_headless_water(seed_value: int) -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(seed_value),
		"--ticks", "5",
		"--water",
	], output, true)
	var water := PackedStringArray()
	for line in "\n".join(output).split("\n"):
		if line.begins_with("water "):
			water.append(line.strip_edges())
	return {"exit_code": exit_code, "output": "\n".join(output), "water": water}
