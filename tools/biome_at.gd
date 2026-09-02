extends SceneTree
## Which biome a position is in, and what the ground does there.
##
##   ./tools/biome_at.sh -28 107 -28 420
##   ./tools/biome_at.sh --seed 7 0 0
##
## One line per position, so a screenshot's caption can name the biome it was
## taken in rather than guess it from the colour. Every number comes out of
## TerrainQuery, nothing is generated, and running this changes no world.

const DEFAULT_SEED := 1234


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var positions: Array[Vector2] = []
	var numbers := PackedFloat64Array()
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		var argument := String(arguments[index])
		if argument == "--seed" and index + 1 < arguments.size():
			seed_value = int(arguments[index + 1])
			index += 2
			continue
		numbers.append(float(argument))
		index += 1
	var pair := 0
	while pair + 1 < numbers.size():
		positions.append(Vector2(numbers[pair], numbers[pair + 1]))
		pair += 2

	var query := TerrainQuery.for_seed(seed_value)
	print("biome probe seed=%d positions=%d" % [seed_value, positions.size()])
	for position in positions:
		print("at x=%.1f z=%.1f biome=%-14s ground=%7.2f water=%s" % [
			position.x, position.y,
			query.biome_at(position.x, position.y),
			query.ground_height_at(position.x, position.y),
			"yes" if query.is_water_at(position.x, position.y) else "no",
		])
	quit(0)
