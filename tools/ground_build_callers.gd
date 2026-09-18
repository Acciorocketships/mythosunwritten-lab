extends SceneTree
## Where a fresh position's 192-unit water contexts actually go, one line per
## caller.
##
## tools/ground_block_cost.gd already says how many water contexts one fresh
## position builds. It does not say who asked for them, and the two answers
## point at different fixes: a query that needs twenty blocks of water to
## describe its own patch of ground is a floor, and a query that needs twenty
## because a layer over it swept a neighbourhood it could have ruled out on
## arithmetic is a bug.
##
## So this walks TerrainQuery.water_column_at's own composition by hand, in the
## order that function composes it, reading the adopted block cache's build
## counters (scripts/terrain/field/WorldFieldBlockCache.gd) between steps. Each
## line names the file and line of the call site that caused the builds on it.
## The settlement layer's pad-tile sweep is opened up cell by cell, and each
## cell split into the two halves of SettlementField._build, because that is
## where the answer was expected to be.
##
## The stack is built directly rather than through TerrainQuery.for_seed(), so
## every position starts with a cold block cache and the counts are that
## position's own.
##
## Usage: godot4 --headless --path . -s res://tools/ground_build_callers.gd \
##   -- --seed 1234 --positions 3

const DEFAULT_SEED := 1234
## How many positions of the scatter sweep's own sequence to open up.
const DEFAULT_POSITIONS := 3
## The sweep tools/ground_scatter_cost.gd times, so the positions opened up here
## are positions that sweep actually paid for.
const SPAN := 2000.0


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var positions := DEFAULT_POSITIONS
	var first := 1
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size() - 1:
		match arguments[index]:
			"--seed": seed_value = int(arguments[index + 1])
			"--positions": positions = int(arguments[index + 1])
			"--first": first = int(arguments[index + 1])
		index += 1

	print("seed %d, %d fresh positions of the scatter sweep's sequence"
		% [seed_value, positions])
	for step in positions:
		var i := first + step
		_open_up(seed_value, Vector2(
			float((i * 977) % int(SPAN * 2.0)) - SPAN,
			float((i * 1861) % int(SPAN * 2.0)) - SPAN), i)
	quit()


## One fresh stack, one fresh position, and a line per caller.
func _open_up(seed_value: int, at: Vector2, i: int) -> void:
	var ground := AdoptedGround.new(seed_value)
	var islands := IslandField.new(ground)
	var settlements := SettlementField.new(ground, islands)
	var paths := PathNetwork.new(settlements, ground)

	print("")
	print("position %d: (%.0f, %.0f) -- cold stack, nothing near it" % [i, at.x, at.y])
	var opened := _mark(ground)

	# sim/terrain_query.gd:136 -- the query's own patch of ground.
	var column := ground.water_column(at.x, at.y)
	_say("sim/terrain_query.gd:136  ground.water_column (the query's own)",
		ground, opened)

	# sim/terrain_query.gd:139 -- the settlement layer, opened up.
	var settlement_mark := _mark(ground)
	_open_pad_tile(ground, settlements, at)
	var delta := settlements.ground_delta_at(at.x, at.y, column.x)
	_say("sim/terrain_query.gd:139  settlement_field.ground_delta_at (total)",
		ground, settlement_mark)

	# sim/terrain_query.gd:140 -- the road layer, opened up.
	var path_mark := _mark(ground)
	_open_path_tile(ground, paths, at)
	var levelled := column.x + delta
	paths.ground_delta_at(at.x, at.y, levelled)
	_say("sim/terrain_query.gd:140  path_network.ground_delta_at (total)",
		ground, path_mark)

	# sim/terrain_query.gd:143 -- the aerial layer, asked only when the ground
	# below would otherwise move.
	var island_mark := _mark(ground)
	islands.walkable_island_over(at.x, at.y)
	_say("sim/terrain_query.gd:143  island_field.walkable_island_over",
		ground, island_mark)

	_say("== whole position", ground, opened)


## The settlement layer's pad-tile sweep, cell by cell. Each cell is built the
## way SettlementField._build builds it, so the inland pass and the shore pass
## are two lines rather than one, and the built village is then handed to the
## field's own memo so its pads_near() below finds exactly what it would have.
func _open_pad_tile(
	ground: AdoptedGround, settlements: SettlementField, at: Vector2
) -> void:
	var tile := SettlementField.pad_tile_at(at.x, at.y)
	var centre := Vector2(
		(float(tile.x) + 0.5) * SettlementField.PAD_TILE,
		(float(tile.y) + 0.5) * SettlementField.PAD_TILE)
	var reach := int(ceil(
		(SettlementField.PAD_TILE_MARGIN + SettlementField.PAD_RADIUS_MAX)
		/ SettlementField.SITE_CELL))
	var home := SettlementField.cell_at(centre.x, centre.y)
	var within: float = SettlementField.PAD_TILE_MARGIN + SettlementField.PAD_RADIUS_MAX
	print("  sim/settlement_field.gd:504  _build_pad_tile walks %d cells"
		% [(2 * reach + 1) * (2 * reach + 1)])
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var cell := Vector2i(home.x + offset_x, home.y + offset_z)
			# The field's own refusal, asked here so this breakdown is of what
			# the field actually does rather than of what it once did.
			if not SettlementField.cell_could_reach(cell, centre.x, centre.y, within):
				print("    cell %s (%.0f units from the tile): ruled out by cell_could_reach, nothing built"
					% [cell, (SettlementField.cell_centre(cell) - centre).length()])
				continue
			_open_cell(ground, settlements, cell, centre)
	var tile_mark := _mark(ground)
	settlements.pads_near(at.x, at.y)
	_say("  sim/settlement_field.gd:493  pads_near, cells already built",
		ground, tile_mark)


## One settlement cell, built the way SettlementField._build builds it.
func _open_cell(
	ground: AdoptedGround,
	settlements: SettlementField,
	cell: Vector2i,
	tile_centre: Vector2,
) -> void:
	if settlements._sites.has(cell):
		return
	var away := (SettlementField.cell_centre(cell) - tile_centre).length()
	var wants: float = settlements._roll(cell, 1)
	var is_spawn: bool = cell == SettlementField.cell_at(0.0, 0.0)
	if not is_spawn and wants >= SettlementField.SITE_CHANCE:
		settlements._sites[cell] = null
		print("    cell %s (%.0f units from the tile): no village, nothing built"
			% [cell, away])
		return
	var radius: float = settlements._roll_range(
		cell, 2, SettlementField.PAD_RADIUS_MIN, SettlementField.PAD_RADIUS_MAX)

	var inland_mark := _mark(ground)
	var inland: Settlement = settlements._build_inland(cell, wants, radius, is_spawn)
	_say("    cell %s (%.0f units from the tile) sim/settlement_field.gd:628 _build_inland"
		% [cell, away], ground, inland_mark)
	if inland == null:
		settlements._sites[cell] = null
		return

	var site := inland
	if not is_spawn:
		var shore_mark := _mark(ground)
		var shore: Settlement = settlements._build_shore(cell, wants, radius)
		_say("    cell %s sim/settlement_field.gd:677 _build_shore" % [cell],
			ground, shore_mark)
		if shore != null:
			site = shore
	var layout_mark := _mark(ground)
	settlements._lay_out(site)
	_say("    cell %s sim/settlement_field.gd:632 _lay_out" % [cell],
		ground, layout_mark)
	settlements._sites[cell] = site


## The road layer's tile, opened into the graph work under it.
func _open_path_tile(
	ground: AdoptedGround, paths: PathNetwork, at: Vector2
) -> void:
	var wet_mark := _mark(ground)
	ground.is_wet(at.x, at.y)
	_say("  sim/path_network.gd:558  ground.is_wet", ground, wet_mark)
	var tile := PathNetwork.tile_at(at.x, at.y)
	var centre := Vector2(
		(float(tile.x) + 0.5) * PathNetwork.TILE,
		(float(tile.y) + 0.5) * PathNetwork.TILE)
	var places_mark := _mark(ground)
	var places := paths.places_near(
		centre.x, centre.y, PathNetwork.LINK_RADIUS + PathNetwork.TILE_MARGIN)
	_say("  sim/path_network.gd:818  _build_tile -> places_near (%d places)"
		% [places.size()], ground, places_mark)
	for place in places:
		var edge_mark := _mark(ground)
		paths.edges_from(place)
		_say("    sim/path_network.gd:820  edges_from %s" % [place["id"]],
			ground, edge_mark)


func _mark(ground: AdoptedGround) -> Dictionary:
	var stats: Dictionary = ground.fields.stats()
	return {
		"water": int(stats["water_builds"]),
		"region": int(stats["region_builds"]),
		"usec": int(stats["water_build_usec"]),
	}


func _say(label: String, ground: AdoptedGround, mark: Dictionary) -> void:
	var stats: Dictionary = ground.fields.stats()
	var water: int = int(stats["water_builds"]) - int(mark["water"])
	var region: int = int(stats["region_builds"]) - int(mark["region"])
	var took := float(int(stats["water_build_usec"]) - int(mark["usec"])) / 1e6
	print("%s: %d water contexts (%.1f s), %d regions" % [label, water, took, region])
