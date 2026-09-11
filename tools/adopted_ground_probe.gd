extends SceneTree
## Samples the adopted (mythosunwritten) ground fields directly -- heightfield,
## hydrostatic water, biome -- headless, from nothing but a seed, and prints a
## digest of every answer so two processes can be compared byte for byte.
##
## This is the probe behind the terrain seam: it measures what sampling the
## adopted stack actually costs (cold river trace, region builds, warm lookups)
## and proves the answers are a pure function of seed and position before
## sim/terrain_query.gd is bound to them. Run it twice and diff the output.
##
## Usage: godot4 --headless --path . -s res://tools/adopted_ground_probe.gd \
##   -- --seed 1234 --span 96 --step 3

const DEFAULT_SEED := 1234
## Half-width of the sampled square around the origin, world units.
const DEFAULT_SPAN := 96.0
## Sampling stride, world units. 3.0 is the sim's combat cell.
const DEFAULT_STEP := 3.0


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var span := DEFAULT_SPAN
	var step := DEFAULT_STEP
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size() - 1:
		match arguments[index]:
			"--seed":
				seed_value = int(arguments[index + 1])
			"--span":
				span = float(arguments[index + 1])
			"--step":
				step = float(arguments[index + 1])
		index += 1

	var started := Time.get_ticks_usec()
	var water := TerrainWorldTuning.make_water(seed_value)
	var plan := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fields := WorldFieldBlockCache.new(plan, water, 0.0, 0.0, 128)
	print("construct_ms=%.1f" % ((Time.get_ticks_usec() - started) / 1000.0))

	started = Time.get_ticks_usec()
	fields.region(WorldFieldBlockCache.key_of(Vector2.ZERO))
	print("first_region_ms=%.1f" % ((Time.get_ticks_usec() - started) / 1000.0))
	started = Time.get_ticks_usec()
	fields.water(WorldFieldBlockCache.key_of(Vector2.ZERO))
	print("first_water_ms=%.1f" % ((Time.get_ticks_usec() - started) / 1000.0))

	started = Time.get_ticks_usec()
	var lines := PackedStringArray()
	var wet_count := 0
	var biomes := {}
	var lowest := INF
	var highest := -INF
	var x := -span
	while x <= span:
		var z := -span
		while z <= span:
			var point := Vector2(x, z)
			var region := fields.region_at(point)
			var context := fields.water_at(point)
			var ground := TerrainSurfaceField.surface_y(region, x, z)
			var wet := context.is_wet(point)
			var level := context.level_at(point)
			var biome := Helper.biome_at(Vector3(x, 0.0, z), seed_value)
			if wet:
				wet_count += 1
			biomes[biome] = int(biomes.get(biome, 0)) + 1
			lowest = minf(lowest, ground)
			highest = maxf(highest, ground)
			lines.append("%.1f,%.1f h=%.4f wet=%d lvl=%.4f b=%s" % [
				x, z, ground, 1 if wet else 0,
				level if wet else -999.0, biome,
			])
			z += step
		x += step
	var sweep_ms := (Time.get_ticks_usec() - started) / 1000.0

	var samples := lines.size()
	print("sweep_ms=%.1f samples=%d per_sample_us=%.1f" % [
		sweep_ms, samples, 1000.0 * sweep_ms / float(samples),
	])
	print("wet=%d/%d height=[%.2f, %.2f]" % [wet_count, samples, lowest, highest])
	var names := biomes.keys()
	names.sort()
	for name in names:
		print("biome %s=%d" % [name, biomes[name]])
	print("stats=%s" % str(fields.stats()))
	print("digest=%s" % "\n".join(lines).sha256_text().substr(0, 16))
	quit(0)
