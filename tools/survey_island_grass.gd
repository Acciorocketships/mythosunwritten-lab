extends SceneTree
## The numbers behind the rules the island grass is written in, headless.
##
## tools/measure_island_grass.sh answers what the island grass *costs* on the
## drawn scene. This answers why it is shaped the way it is, off the fields and
## the geometry alone, so every figure in reports/islands.md has a command:
##
## * what each candidate slope gate keeps of an island's top, by plan area;
## * what the ground's clearing mask does to an island, in the world's frame and
##   in the island's own -- which is the measurement that decided an island gets
##   no clearing mask at all;
## * what one biome at full weight grows, against what the ground grows where
##   that same biome holds at least PURE_SHARE of the weight;
## * whether the parting-around-characters displacement reaches an island's
##   storey, and whether it reaches the ground below it.
##
##   ./tools/survey_island_grass.sh                              # seed 1234
##   ./tools/survey_island_grass.sh --seed 7 --at -406.0 -324.9
##
## `--at` is where the walker for the last section stands; it must be somewhere
## an observer ends up on an island for that section to say anything.

## How far out from the origin islands are surveyed, in world units.
const SPAN := 600.0

## Cosines of the steepest ground grass may stand on, swept. The first is the
## ground layer's own and the fifth is IslandCover.SLOPE_LIMIT converted.
const SLOPE_SWEEP := [0.72, 0.65, 0.60, 0.55, 0.518, 0.48, 0.45]

## How much of an island's lattice has to grow before it is not "mostly bare".
const BARE_UNDER := 0.15

## How far an island's own frame may be offset from the clearing field's origin,
## for the island-frame arm of the mask comparison. Without an offset every
## island reads the field at the same lattice corner.
const FRAME_SPREAD := 4096.0

## How much of the weight one biome has to hold for a position to count as that
## biome undiluted, and how finely the world is sampled looking for such places.
const PURE_SHARE := 0.95
const PURE_STEP := 7.0
const PURE_SIDE := 400


func _initialize() -> void:
	var world_seed := 1234
	var at_x := -406.0
	var at_z := -324.9
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size():
			world_seed = args[i + 1].to_int()
		if args[i] == "--at" and i + 2 < args.size():
			at_x = args[i + 1].to_float()
			at_z = args[i + 2].to_float()

	var world := SimWorld.new(world_seed)
	_slope_and_mask(world, world_seed)
	_one_biome_against_its_own_ground(world, world_seed)
	_does_the_parting_follow(world_seed, at_x, at_z)
	quit(0)


## The slope sweep and the clearing mask, over every walkable island in a square
## SPAN either way of the origin.
func _slope_and_mask(world: SimWorld, world_seed: int) -> void:
	var mesher := IslandMesher.new()
	var cell := GrassLayer.CELL
	var kept := PackedFloat32Array()
	kept.resize(SLOPE_SWEEP.size())
	var islands := 0
	var world_means: Array[float] = []
	var local_means: Array[float] = []
	var world_bare := 0
	var local_bare := 0

	for band in FloatingIsland.WALKABLE_BANDS:
		var size := IslandField.cell_size(band)
		var cells := int(ceil(SPAN / size))
		for cell_x in range(-cells, cells + 1):
			for cell_z in range(-cells, cells + 1):
				var island := world.island_field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island == null or not island.walkable:
					continue
				if absf(island.centre_x) > SPAN or absf(island.centre_z) > SPAN:
					continue
				islands += 1

				# What each gate keeps of this island's up-facing surface, in
				# plan, off the geometry the mesher actually produces.
				var geometry := mesher.build(island)
				var top := 0.0
				var passed := PackedFloat32Array()
				passed.resize(SLOPE_SWEEP.size())
				for triangle in geometry.triangle_count():
					var base := triangle * 3
					var normal := geometry.normals[base]
					if normal.y <= 0.0:
						continue
					var a := geometry.vertices[base]
					var b := geometry.vertices[base + 1]
					var c := geometry.vertices[base + 2]
					var area := absf(
						(b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
					) * 0.5
					top += area
					for at in SLOPE_SWEEP.size():
						if normal.y >= float(SLOPE_SWEEP[at]):
							passed[at] += area
				if top > 0.0:
					for at in SLOPE_SWEEP.size():
						kept[at] += passed[at] / top

				# The clearing mask over this island's footprint, both ways.
				var cover := GrassLayer.coverage_for({island.biome: 1.0})
				var salt := world_seed ^ SimRng.hash_ints(
					island.cell.x, island.cell.y, island.band
				)
				var frame_x := SimRng.hash_unit(salt, island.cell.x, 0x1F) * FRAME_SPREAD
				var frame_z := SimRng.hash_unit(salt, island.cell.y, 0x2E) * FRAME_SPREAD
				var reach := island.max_reach()
				var steps := int(ceil(reach / cell))
				var world_total := 0.0
				var local_total := 0.0
				var counted := 0
				for step_x in range(-steps, steps + 1):
					for step_z in range(-steps, steps + 1):
						var x := island.centre_x + float(step_x) * cell
						var z := island.centre_z + float(step_z) * cell
						if island.ratio_at(x, z) > 1.0:
							continue
						counted += 1
						world_total += GrassLayer.grown_share(
							GrassLayer.clearing_at(x, z, world_seed), cover
						)
						local_total += GrassLayer.grown_share(GrassLayer.clearing_at(
							x - island.centre_x + frame_x,
							z - island.centre_z + frame_z, salt
						), cover)
				if counted == 0:
					continue
				world_means.append(world_total / float(counted))
				local_means.append(local_total / float(counted))
				if world_means[world_means.size() - 1] < BARE_UNDER:
					world_bare += 1
				if local_means[local_means.size() - 1] < BARE_UNDER:
					local_bare += 1

	print("seed %d: %d walkable islands in a %.0f-unit square" % [
		world_seed, islands, SPAN * 2.0,
	])
	print("")
	print("the slope gate, by plan area of an island's top")
	for at in SLOPE_SWEEP.size():
		var cosine := float(SLOPE_SWEEP[at])
		var label := ""
		if is_equal_approx(cosine, GrassLayer.SLOPE_COS):
			label = "  <- the ground's"
		if absf(cosine - GrassLayer.ISLAND_SLOPE_COS) < 0.001:
			label = "  <- the island's (IslandCover.SLOPE_LIMIT)"
		print("  cos %.3f (fall %.2f per unit) keeps %.3f%s" % [
			cosine, sqrt(1.0 - cosine * cosine) / cosine,
			kept[at] / float(maxi(1, islands)), label,
		])
	print("")
	print("the clearing mask on an island, as the share of its lattice grown")
	print("  read in the world's frame:  %s, under %.2f on %d of %d" % [
		_spread(world_means), BARE_UNDER, world_bare, world_means.size(),
	])
	print("  read in the island's frame: %s, under %.2f on %d of %d" % [
		_spread(local_means), BARE_UNDER, local_bare, local_means.size(),
	])


## What one biome at full weight grows, against what the ground grows where that
## biome really does hold the weight on its own.
func _one_biome_against_its_own_ground(world: SimWorld, world_seed: int) -> void:
	print("")
	print("one biome at full weight (an island), against the ground of the same name")
	var pure := {}
	for biome in BiomeCatalog.IDS:
		pure[biome] = [] as Array[float]
	var origin := -PURE_STEP * float(PURE_SIDE) * 0.5
	for row in PURE_SIDE:
		for column in PURE_SIDE:
			var x := origin + float(column) * PURE_STEP
			var z := origin + float(row) * PURE_STEP
			var weights := world.terrain.biome_field.weights_at(x, z)
			for biome in BiomeCatalog.IDS:
				if float(weights.get(biome, 0.0)) >= PURE_SHARE:
					(pure[biome] as Array[float]).append(GrassLayer.grown_share(
						GrassLayer.clearing_at(x, z, world_seed),
						GrassLayer.coverage_for(weights)
					))
	for biome in BiomeCatalog.IDS:
		var cover := GrassLayer.coverage_for({biome: 1.0})
		print("  %-15s coverage %.2f -> island %.3f, ground %s" % [
			biome, cover, GrassLayer.grown_share(1.0, cover), _spread(pure[biome]),
		])


## Whether a character standing on an island parts the grass on that island, and
## whether they reach the grass on the ground under it.
func _does_the_parting_follow(world_seed: int, at_x: float, at_z: float) -> void:
	var world := SimWorld.new(world_seed)
	world.place_observer(at_x, at_z)
	var layer := GrassLayer.new(world.terrain, world.world_seed)
	var mesher := IslandMesher.new()
	print("")
	print("a walker at (%.1f, %.1f) stands at height %.2f, on an island: %s" % [
		world.observer_x, world.observer_z, world.observer_y,
		world.observer_on_island(),
	])
	for key in world.island_streamer.loaded_keys():
		var island: FloatingIsland = world.island_streamer.island(key)
		if island == null or not island.walkable:
			continue
		var view := layer.build_island(mesher.build(island), island)
		if view == null:
			continue
		var counts := _reached(view, world)
		print("  island %s: %d patches, %d inside the walker's reach and band" % [
			key, view.multimesh.instance_count, counts.y,
		])
		view.free()
	var near := 0
	var parted := 0
	for key in world.terrain_streamer.loaded_keys():
		var view := layer.build(world.terrain_streamer.geometry(key))
		if view == null:
			continue
		var counts := _reached(view, world)
		near += counts.x
		parted += counts.y
		view.free()
	print("  the ground below: %d patches inside the walker's reach in plan, %d of them"
		% [near, parted] + " inside the band as well")


## How many of one drawable's patches are within the walker's reach in plan, and
## how many of those are also inside the vertical band the shader gates on.
func _reached(view: MultiMeshInstance3D, world: SimWorld) -> Vector2i:
	var buffer: PackedFloat32Array = view.multimesh.buffer
	var near := 0
	var both := 0
	for at in view.multimesh.instance_count:
		var away := Vector2(buffer[at * 20 + 3], buffer[at * 20 + 11]).distance_to(
			Vector2(world.observer_x, world.observer_z)
		)
		if away > GrassLayer.WALKER_REACH:
			continue
		near += 1
		if absf(buffer[at * 20 + 7] - world.observer_y) <= GrassLayer.WALKER_BAND:
			both += 1
	return Vector2i(near, both)


func _spread(values: Array) -> String:
	if values.is_empty():
		return "none"
	var sorted: Array[float] = []
	for one in values:
		sorted.append(float(one))
	sorted.sort()
	var total := 0.0
	for one in sorted:
		total += one
	return "min %.3f median %.3f mean %.3f max %.3f" % [
		sorted[0], sorted[sorted.size() / 2],
		total / float(sorted.size()), sorted[sorted.size() - 1],
	]
