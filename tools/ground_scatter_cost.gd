extends SceneTree
## What a scattered sweep of the adopted ground costs, against the same sweep
## walked in block order.
##
## The adopted field cache (scripts/terrain/field/WorldFieldBlockCache.gd) holds
## whole 192-unit blocks and evicts the least recently used once it is full --
## sim/adopted_ground.gd gives it sixteen entries. A sweep that visits positions
## in a scattered order therefore pays a cold block build per position once the
## square it ranges over holds more blocks than the cache does, while the same
## positions visited in block order pay one build per block. This probe measures
## both on this machine so the difference is a number rather than an argument.
##
## Usage: godot4 --headless --path . -s res://tools/ground_scatter_cost.gd \
##   -- --seed 1234 --span 2000 --count 900 --sample 100

const DEFAULT_SEED := 1234
## Half-width of the sampled square, world units.
const DEFAULT_SPAN := 2000.0
## How many positions the sweep being modelled visits in full.
const DEFAULT_COUNT := 900
## How many of them to actually time, per order.
const DEFAULT_SAMPLE := 100


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var span := DEFAULT_SPAN
	var count := DEFAULT_COUNT
	var sample := DEFAULT_SAMPLE
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size() - 1:
		match arguments[index]:
			"--seed": seed_value = int(arguments[index + 1])
			"--span": span = float(arguments[index + 1])
			"--count": count = int(arguments[index + 1])
			"--sample": sample = int(arguments[index + 1])
		index += 1

	# The exact position sequence of the check that went quiet:
	# tests/test_terrain_lod.gd:302-305 as of bc994710^.
	var positions: Array[Vector2] = []
	for i in count:
		positions.append(Vector2(
			float((i * 977) % int(span * 2.0)) - span,
			float((i * 1861) % int(span * 2.0)) - span))

	var block_world: float = WorldFieldBlockCache.BLOCK_WORLD
	var blocks := {}
	for p in positions:
		blocks[Vector2i(int(floor(p.x / block_world)), int(floor(p.y / block_world)))] = true
	print("sweep: %d positions over a %.0f-unit square, touching %d distinct %.0f-unit blocks"
		% [count, span * 2.0, blocks.size(), block_world])
	print("cache: %d blocks (AdoptedGround.FIELD_BLOCKS)" % AdoptedGround.FIELD_BLOCKS)

	var scattered := positions.slice(0, sample)
	var ordered := scattered.duplicate()
	ordered.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var ka := Vector2i(int(floor(a.x / block_world)), int(floor(a.y / block_world)))
		var kb := Vector2i(int(floor(b.x / block_world)), int(floor(b.y / block_world)))
		if ka.x != kb.x:
			return ka.x < kb.x
		return ka.y < kb.y)

	# One query for both sweeps, so the terrain is identical and the only
	# difference is the order the positions are asked in. The block-ordered
	# sweep starts with the sixteen blocks the scattered one left warm, which
	# is a small head start against the hundreds it visits.
	var warm := Time.get_ticks_usec()
	var terrain := TerrainQuery.for_seed(seed_value)
	terrain.ground_height_at(0.0, 0.0)
	print("cold build: %.1f s" % [float(Time.get_ticks_usec() - warm) / 1e6])

	_time_sweep("scattered (the check's own order)", terrain, scattered, block_world)
	_time_sweep("block order (same positions)", terrain, ordered, block_world)
	quit()


## Time one sweep, printing as it goes so a slow one is still legible if it is
## cut short. The two calls are the ones the check made per position.
func _time_sweep(label: String, terrain: TerrainQuery, points: Array, block_world: float) -> void:

	var seen := {}
	var started := Time.get_ticks_usec()
	var worst := 0.0
	for i in points.size():
		var p: Vector2 = points[i]
		var one := Time.get_ticks_usec()
		var full := terrain.ground_height_at(p.x, p.y)
		var carved := terrain.ground.water_column(p.x, p.y).x
		var took := float(Time.get_ticks_usec() - one) / 1e6
		worst = maxf(worst, took)
		seen[Vector2i(int(floor(p.x / block_world)), int(floor(p.y / block_world)))] = true
		if i % 10 == 9:
			print("  %s: %d/%d positions, %.1f s elapsed, %.2f s each, worst %.2f s, %d blocks seen"
				% [label, i + 1, points.size(),
					float(Time.get_ticks_usec() - started) / 1e6,
					float(Time.get_ticks_usec() - started) / 1e6 / float(i + 1),
					worst, seen.size()])
	var total := float(Time.get_ticks_usec() - started) / 1e6
	print("%s: %d positions in %.1f s, %.3f s each, worst %.2f s, %d distinct blocks"
		% [label, points.size(), total, total / float(points.size()), worst, seen.size()])
