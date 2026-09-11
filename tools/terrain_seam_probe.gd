extends SceneTree
## Every sim answer about a lattice of cells, printed so two processes can be
## diffed byte for byte.
##
## This is the terrain seam's determinism proof: for each combat cell in a
## square around a centre, it prints the cell's elevation, water, biome and
## blockedness exactly as the sim reads them -- the adopted fields sampled at
## the cell's centre through TerrainQuery, the same call chain the combat
## board builder uses. Run it twice with the same seed and compare the whole
## output; any drift between processes is a broken seam.
##
## Usage: godot4 --headless --path . -s res://tools/terrain_seam_probe.gd \
##   -- --seed 1234 --centre-x 0 --centre-z 0 --cells 24

const DEFAULT_SEED := 1234
const DEFAULT_CELLS := 24


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var cells := DEFAULT_CELLS
	var centre_x := 0.0
	var centre_z := 0.0
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size() - 1:
		match arguments[index]:
			"--seed":
				seed_value = int(arguments[index + 1])
			"--cells":
				cells = int(arguments[index + 1])
			"--centre-x":
				centre_x = float(arguments[index + 1])
			"--centre-z":
				centre_z = float(arguments[index + 1])
		index += 1

	var query := TerrainQuery.for_seed(seed_value)
	var centre_cell := CombatBoard.cell_of(centre_x, centre_z)
	var lines := PackedStringArray()
	for row in cells:
		for column in cells:
			var cell := centre_cell + Vector2i(column - cells / 2, row - cells / 2)
			var at := CombatBoard.centre_of(cell)
			var ground := query.ground_height_at(at.x, at.y)
			var support := query.support_at(at.x, at.y, ground)
			lines.append(
				"cell=%d,%d ground=%.6f support=%.6f void=%d water=%d depth=%.6f bank=%d biome=%s passable=%d"
				% [
					cell.x, cell.y, ground, support,
					1 if query.is_void_at(at.x, at.y, ground) else 0,
					1 if query.is_water_at(at.x, at.y) else 0,
					query.water_depth_at(at.x, at.y),
					1 if query.is_bank_at(at.x, at.y) else 0,
					query.biome_at(at.x, at.y),
					1 if query.is_passable_at(at.x, at.y) else 0,
				]
			)
	for line in lines:
		print(line)
	print("cells=%d digest=%s" % [
		lines.size(), "\n".join(lines).sha256_text().substr(0, 16),
	])
	quit(0)
