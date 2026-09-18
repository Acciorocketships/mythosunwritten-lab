extends SceneTree
## Where test_settlements' memory goes, measured rather than inferred.
##
## The certifying run adopt-full-suite-3765 watched this suite's engine grow to
## 24.29 GiB and get killed; the diagnostic run of cycle 3886 reproduced it at
## 20.89 GiB with the same shape. This probe takes the suite's two heaviest
## shapes apart and prints, after each step, three numbers that say which of the
## three candidate holders has the memory:
##
##   rss      -- the kernel's own resident set for this process, field two of
##               /proc/self/statm. What the sampler and the kernel's killer read.
##   engine   -- Performance.MEMORY_STATIC: bytes the engine believes are
##               allocated. This falls when something is genuinely freed even
##               where the allocator keeps the pages, so rss-without-engine is
##               heap the process is holding but no longer using.
##   profiles / traces / basins
##            -- the sizes of WaterField's three static caches, which are
##               unbounded and outlive every reference to the seed they were
##               built for (see sim/adopted_ground.gd's _purge_water_statics).
##
## Usage:
##   godot4 --headless --path . -s res://tools/settlements_memory_probe.gd \
##     -- --shape gather        # one seed, the square the suite gathers from
##   ... -- --shape shore --seeds 3   # the shore loop's shape, retaining as it does
##   ... -- --shape shore --seeds 3 --release   # the same, releasing each seed

const SEED := 1234
const CELL_REACH := 3
const SHORE_SEEDS := [1234, 7, 3, 19, 42, 101, 5, 11]
const SHORE_CELL_REACH := 4


func _initialize() -> void:
	var shape := "gather"
	var seeds := 3
	var release := false
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size():
		match arguments[index]:
			"--shape":
				shape = arguments[index + 1]
			"--seeds":
				seeds = int(arguments[index + 1])
			"--release":
				release = true
		index += 1

	_say("start")
	match shape:
		"gather":
			_gather_shape()
		"shore":
			_shore_shape(seeds, release)
		_:
			print("unknown shape %s" % shape)
	quit()


## One seed, the square the suite's first phase gathers villages from, then the
## three ways the memory could be given back, tried one at a time.
func _gather_shape() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	_say("stack built for seed %d" % SEED)
	var villages := _villages(terrain.settlement_field, CELL_REACH)
	_say("%d villages gathered over %d cells" % [
		villages.size(), (2 * CELL_REACH + 1) * (2 * CELL_REACH + 1)])

	AdoptedGround._purge_water_statics()
	_say("water statics purged, stack still held")

	terrain = null
	_say("stack reference dropped")

	AdoptedGround._shared.clear()
	AdoptedGround._purge_water_statics()
	_say("shared seed dropped and statics purged")


## The shore loop's shape: several seeds, each gathered from a wider square.
## With --release the seed's stack is dropped before the next one is built,
## which is the only difference between the two runs.
func _shore_shape(seeds: int, release: bool) -> void:
	var held: Array = []
	var count := 0
	for world_seed: int in SHORE_SEEDS:
		if count >= seeds:
			break
		count += 1
		var terrain := TerrainQuery.for_seed(world_seed)
		var found := _villages(terrain.settlement_field, SHORE_CELL_REACH)
		if not release:
			for site in found:
				held.append({"site": site, "terrain": terrain})
		_say("seed %d: %d villages, %d held%s" % [
			world_seed, found.size(), held.size(),
			" (released)" if release else "",
		])


func _villages(field: SettlementField, reach: int) -> Array[Settlement]:
	var found: Array[Settlement] = []
	for cell_x in range(-reach, reach + 1):
		for cell_z in range(-reach, reach + 1):
			var site := field.settlement_in_cell(Vector2i(cell_x, cell_z))
			if site != null:
				found.append(site)
	return found


func _say(what: String) -> void:
	print("%7.2f s  rss %6.2f GiB  engine %6.2f GiB  profiles %5d  traces %5d  basins %5d  | %s" % [
		Time.get_ticks_msec() / 1000.0,
		_resident_gib(),
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / float(1 << 30),
		WaterField._profiles.size(),
		WaterField._trace_regions.size(),
		WaterField._basin_cache.size(),
		what,
	])


## Field two of /proc/self/statm, in pages of 4096 bytes on this platform.
func _resident_gib() -> float:
	var statm := FileAccess.open("/proc/self/statm", FileAccess.READ)
	if statm == null:
		return 0.0
	var fields := statm.get_line().split(" ", false)
	if fields.size() < 2:
		return 0.0
	return float(fields[1].to_int()) * 4096.0 / float(1 << 30)
