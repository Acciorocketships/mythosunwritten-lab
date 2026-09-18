extends SceneTree
## What one cold block of the adopted ground costs, split into its two halves.
##
## scripts/terrain/field/WorldFieldBlockCache.gd builds two things per 192-unit
## block: a heightfield region, and a water context. It counts the microseconds
## each took, so asking it after a sweep says which half the time went to. The
## sweep below walks out from the origin so near blocks and far ones are timed
## separately -- the suites that sample close in and the one that sampled out to
## 2000 units cost different amounts, and this says whether distance is why.
##
## Usage: godot4 --headless --path . -s res://tools/ground_block_cost.gd \
##   -- --seed 1234 --blocks 6

const DEFAULT_SEED := 1234
## How many blocks to time at each distance band.
const DEFAULT_BLOCKS := 6


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var blocks := DEFAULT_BLOCKS
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size() - 1:
		match arguments[index]:
			"--seed": seed_value = int(arguments[index + 1])
			"--blocks": blocks = int(arguments[index + 1])
		index += 1

	var cold := Time.get_ticks_usec()
	var terrain := TerrainQuery.for_seed(seed_value)
	print("cold seed build (plans only): %.1f s"
		% [float(Time.get_ticks_usec() - cold) / 1e6])

	for band: float in [96.0, 950.0, 2000.0]:
		_time_band(terrain, band, blocks)
	quit()


## Time `blocks` fresh blocks on a circle of radius `band`, reading the cache's
## own build counters so the region half and the water half are separate.
func _time_band(terrain: TerrainQuery, band: float, blocks: int) -> void:
	var before: Dictionary = terrain.ground.fields.stats()
	var started := Time.get_ticks_usec()
	for i in blocks:
		var heading := float(i) * TAU / float(blocks) + 0.37
		terrain.ground_height_at(cos(heading) * band, sin(heading) * band)
	var wall := float(Time.get_ticks_usec() - started) / 1e6
	var after: Dictionary = terrain.ground.fields.stats()
	var region_builds: int = int(after["region_builds"]) - int(before["region_builds"])
	var water_builds: int = int(after["water_builds"]) - int(before["water_builds"])
	var region_s := float(int(after["region_build_usec"]) - int(before["region_build_usec"])) / 1e6
	var water_s := float(int(after["water_build_usec"]) - int(before["water_build_usec"])) / 1e6
	print("%.0f units out: %d positions in %.1f s (%.2f s each) -- %d region builds %.1f s, %d water builds %.1f s, %d evictions"
		% [band, blocks, wall, wall / float(blocks), region_builds, region_s,
			water_builds, water_s,
			int(after["evictions"]) - int(before["evictions"])])
