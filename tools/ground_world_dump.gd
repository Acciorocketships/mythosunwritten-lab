extends SceneTree
## A byte-for-byte description of a patch of world, for holding one build of the
## ground against another.
##
## Everything this project's layers compose -- the carved height, the water, the
## biome, the roads worn into it, and where the villages stand and what stands in
## them -- written out at full float precision, in a fixed order, from a fixed
## position list. Two runs of this over the same seed differ in no byte unless
## the world moved, so `sha256sum` on its output is the whole check.
##
## The positions are of three kinds, because the three parts of the composition
## fail differently. A dense grid near the origin covers the starting village and
## the roads out of it. A list of settlement cells covers where villages stand
## and how they are laid out, including cells nothing was ever asked about. And a
## handful of positions from the scattered sweep tools/ground_scatter_cost.gd
## times covers the far country, which is where a sweep that rules cells out on
## arithmetic could go wrong.
##
## Usage: godot4 --headless --path . -s res://tools/ground_world_dump.gd \
##   -- --seed 1234 > reports/ground-world-dump-before.txt

const DEFAULT_SEED := 1234
## The dense grid: half-width in world units, and the step across it.
const GRID_SPAN := 480.0
const GRID_STEP := 24.0
## How far out the enumerated settlement cells reach, in cells each way.
const CELL_REACH := 3
## The scattered sweep this project times, and how many of its positions to take.
const SCATTER_SPAN := 2000.0
const SCATTER_COUNT := 12


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size() - 1:
		match arguments[index]:
			"--seed": seed_value = int(arguments[index + 1])
		index += 1

	var terrain := TerrainQuery.for_seed(seed_value)
	print("world dump seed %d" % seed_value)

	# The villages first: building one is what every other answer here depends
	# on, and enumerating them cell by cell says where they stand whether or not
	# anything ever asks about the ground they stand on.
	print("-- villages, cell order")
	for cell_x in range(-CELL_REACH, CELL_REACH + 1):
		for cell_z in range(-CELL_REACH, CELL_REACH + 1):
			_say_village(terrain, Vector2i(cell_x, cell_z))

	print("-- dense grid")
	var grid: Array[Vector2] = []
	var steps := int(GRID_SPAN * 2.0 / GRID_STEP) + 1
	for row in steps:
		for column in steps:
			grid.append(Vector2(
				-GRID_SPAN + float(column) * GRID_STEP,
				-GRID_SPAN + float(row) * GRID_STEP))
	_say_positions(terrain, grid)

	print("-- scattered positions")
	var scattered: Array[Vector2] = []
	for i in SCATTER_COUNT:
		scattered.append(Vector2(
			float((i * 977) % int(SCATTER_SPAN * 2.0)) - SCATTER_SPAN,
			float((i * 1861) % int(SCATTER_SPAN * 2.0)) - SCATTER_SPAN))
	_say_positions(terrain, scattered)
	quit()


## One village, or the fact that its cell holds none, with everything standing
## in it. Printed in the cell's own order so the list does not depend on how it
## was walked.
func _say_village(terrain: TerrainQuery, cell: Vector2i) -> void:
	var site := terrain.settlement_field.settlement_in_cell(cell)
	if site == null:
		print("cell %d %d none" % [cell.x, cell.y])
		return
	print("cell %d %d at %.9f %.9f r %.9f core %.9f level %.9f %s spawn %s shore %s"
		% [cell.x, cell.y, site.centre_x, site.centre_z, site.radius,
			site.core_radius, site.pad_height, site.biome,
			site.is_spawn, site.is_shore])
	for building in site.buildings:
		print("  building %s %.9f %.9f yaw %.9f half %.9f %.9f"
			% [String(building["tag"]), float(building["x"]), float(building["z"]),
				float(building["yaw"]), float(building["half_width"]),
				float(building["half_depth"])])
	for prop in site.props:
		print("  prop %s %.9f %.9f yaw %.9f"
			% [String(prop["tag"]), float(prop["x"]), float(prop["z"]),
				float(prop["yaw"])])
	for glow in site.glows:
		print("  glow %s %.9f %.9f yaw %.9f building %d"
			% [String(glow["tag"]), float(glow["x"]), float(glow["z"]),
				float(glow["yaw"]), int(glow["building"])])


## The composed ground at each position, walked in block order so the sweep pays
## one cold block per block rather than one per position. The order the ground is
## asked in changes no answer -- every one is a pure function of seed and
## position -- so the output is still sorted into the fixed order below.
func _say_positions(terrain: TerrainQuery, points: Array[Vector2]) -> void:
	var block: float = WorldFieldBlockCache.BLOCK_WORLD
	var walked := points.duplicate()
	walked.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var ka := Vector2i(int(floor(a.x / block)), int(floor(a.y / block)))
		var kb := Vector2i(int(floor(b.x / block)), int(floor(b.y / block)))
		if ka.x != kb.x:
			return ka.x < kb.x
		if ka.y != kb.y:
			return ka.y < kb.y
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y)
	var lines := {}
	for p in walked:
		var column := terrain.water_column_at(p.x, p.y)
		var site := terrain.settlement_at(p.x, p.y)
		lines[p] = "%.1f %.1f h %.9f surf %.9f wet %s bank %s base %.9f %s path %.9f road %.9f village %s" % [
			p.x, p.y, column.x, column.y,
			terrain.is_water_at(p.x, p.y), terrain.is_bank_at(p.x, p.y),
			terrain.base_height_at(p.x, p.y), terrain.biome_at(p.x, p.y),
			terrain.path_strength_at(p.x, p.y), terrain.road_distance_at(p.x, p.y),
			"none" if site == null else site.id()]
	for p in points:
		print(lines[p])
