extends SceneTree
## What the adopted ground's block cache costs at a given size: time for a
## scattered sweep, and the memory the process ends up holding.
##
## sim/adopted_ground.gd sizes that cache at FIELD_BLOCKS. One
## TerrainQuery.ground_height_at() call reaches further than the position it is
## asked about -- the settlement and path layers sample around it -- so if the
## cache is smaller than one call's own footprint, every build inside a single
## call evicts a build the same call is about to want again. This probe runs the
## same sweep at a chosen size so the cost and the memory can be read off
## against each other.
##
## Usage: godot4 --headless --path . -s res://tools/ground_cache_size.gd \
##   -- --seed 1234 --cache 64 --sample 20 --span 2000

const DEFAULT_SEED := 1234
const DEFAULT_CACHE := 16
const DEFAULT_SAMPLE := 20
const DEFAULT_SPAN := 2000.0


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var cache := DEFAULT_CACHE
	var sample := DEFAULT_SAMPLE
	var span := DEFAULT_SPAN
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size() - 1:
		match arguments[index]:
			"--seed": seed_value = int(arguments[index + 1])
			"--cache": cache = int(arguments[index + 1])
			"--sample": sample = int(arguments[index + 1])
			"--span": span = float(arguments[index + 1])
		index += 1

	var terrain := TerrainQuery.for_seed(seed_value)
	var ground := terrain.ground
	# Same plans, a cache of the chosen size in front of them.
	ground.fields = WorldFieldBlockCache.new(
		ground.height_plan, ground.water_plan, 0.0, 0.0, cache)
	ground.base_fields = WorldFieldBlockCache.new(
		ground.base_plan, ground.water_plan, 0.0, 0.0, cache)

	var started := Time.get_ticks_usec()
	for i in sample:
		var x := float((i * 977) % int(span * 2.0)) - span
		var z := float((i * 1861) % int(span * 2.0)) - span
		terrain.ground_height_at(x, z)
		terrain.ground.water_column(x, z)
	var wall := float(Time.get_ticks_usec() - started) / 1e6
	var stats: Dictionary = ground.fields.stats()
	print("cache %d blocks: %d positions in %.1f s (%.2f s each) -- %d region builds, %d water builds %.1f s, %d evictions, %d entries held"
		% [cache, sample, wall, wall / float(sample),
			int(stats["region_builds"]), int(stats["water_builds"]),
			float(int(stats["water_build_usec"])) / 1e6,
			int(stats["evictions"]), int(stats["entries"])])
	quit()
