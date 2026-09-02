extends TestSuite
## The mountains are a place in the ground, and a character can walk up one.
##
## Five claims, and the fourth is the one the whole task turns on.
##
## 1. **The ridged fold is what it says it is.** `ValueNoise.ridged_sample` is
##    `1 - |value|` per layer, summed. Checked against the raw layer rather than
##    against a remembered number, so the claim is about the arithmetic and not
##    about a fixture.
## 2. **The uplift is exactly zero outside a range.** Not nearly zero:
##    `TerrainSurfaceField.height_at` returns the identical float it would have
##    returned with no mountain layer at all. That is what makes "the ground far
##    away carries the relief it carries today" checkable rather than arguable.
## 3. **The rocky axis drives it.** Highland ground stands far higher than
##    meadow ground -- the axis that used to reach only the palette now reaches
##    the height of the land.
## 4. **A summit can be climbed.** A breadth-first search over the *real* height
##    function, on the tactical lattice, under the tactical lattice's own step
##    limits, finds a route from the rim of a box to the highest ground inside
##    it. Nothing is asserted from an amplitude and nothing is read from a
##    stored path: the route is found here, in this process, and then every one
##    of its steps is re-checked against the limits.
## 5. **A road is never laid on ground nobody could walk up, and the carving
##    leaves it that way.** The path layer picks the flattest of a handful of
##    candidate lines, against the same step limit; this checks that the limit it
##    uses is that one, that no road anywhere near the origin is laid on land
##    that breaks it, and that no step of the finished roadway breaks it either.
##
## The wider survey -- relief over four square kilometres, every summit in a
## sample, what share of a mountain the limits refuse -- lives in
## tools/measure_mountains.gd, which is too slow for a suite. This checks the
## properties; that measures the world.
class_name TestMountains

const SEED := 1234
const OTHER_SEED := 7

## The lattice a route is searched on and the limits it must obey: the tactical
## layer's own, read off it rather than restated, so weakening one of them here
## would be weakening it for the board too.
const LATTICE := CombatBoard.CELL_SIZE
const STEP_UP := TerrainQuery.HOP_HEIGHT
const STEP_DOWN := TerrainQuery.DROP_REACH

## Half the side of the box the climb is searched in, in world units. Small
## enough to sample in a few seconds, wide enough that its rim is off the summit
## it surrounds.
const CLIMB_REACH := 168.0

## Where the box sits: on the tallest mountain seed 1234 puts near the origin,
## found by tools/measure_mountains.sh. The route is *not* taken from that tool;
## only the place to look is.
const CLIMB_CENTRE := Vector2(-28.0, 107.0)

const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _init() -> void:
	suite_name = "mountains"


func run() -> void:
	_ridged_sample_is_the_folded_field()
	_the_uplift_is_a_pure_function()
	_the_mask_is_exactly_zero_outside_a_range()
	_the_uplift_is_regional()
	_the_rocky_axis_drives_the_uplift()
	_a_summit_can_be_climbed()
	_a_road_is_never_laid_on_unwalkable_land()


## `ridged_sample` folds each layer through `1 - |value|` and sums. Checked
## against `sample` on a one-layer field, where the two are related by exactly
## that identity, and then bounded on the real four-layer field.
func _ridged_sample_is_the_folded_field() -> void:
	var single := ValueNoise.new(SEED, 1, 100.0, 1.0)
	for probe in [Vector2(0.0, 0.0), Vector2(37.5, -12.25), Vector2(-403.0, 88.0)]:
		var raw := single.sample(probe.x, probe.y)
		var folded := single.ridged_sample(probe.x, probe.y)
		check(absf(folded - (1.0 - absf(raw))) < 0.000001,
			"a one-layer ridged sample is not 1 - |value| at (%f, %f): %f against %f"
			% [probe.x, probe.y, folded, 1.0 - absf(raw)])

	var field := ValueNoise.new(
		SEED,
		MountainField.RIDGE_OCTAVES,
		MountainField.RIDGE_PERIOD,
		MountainField.RIDGE_AMPLITUDE,
		MountainField.RIDGE_LACUNARITY,
		MountainField.RIDGE_GAIN,
	)
	var ceiling := 0.0
	var layer := MountainField.RIDGE_AMPLITUDE
	for octave in MountainField.RIDGE_OCTAVES:
		ceiling += layer
		layer *= MountainField.RIDGE_GAIN
	for index in 400:
		var x := float(index) * 11.7 - 2000.0
		var z := float(index) * -7.3 + 800.0
		var value := field.ridged_sample(x, z)
		check(value >= 0.0 and value <= ceiling + 0.000001,
			"a ridged sample left [0, %f] at (%f, %f): %f" % [ceiling, x, z, value])


## The uplift depends on the position and the seed and on nothing else -- not on
## what was sampled before it, and not on which object was asked.
func _the_uplift_is_a_pure_function() -> void:
	var field := MountainField.new(SEED)
	var again := MountainField.new(SEED)
	var other := MountainField.new(OTHER_SEED)
	var probes := [
		Vector2(0.0, 0.0), Vector2(-28.0, 107.0), Vector2(613.25, -1204.5),
		Vector2(-3000.0, 2500.0),
	]

	var first_pass: Array[float] = []
	for probe in probes:
		first_pass.append(field.uplift_at(probe.x, probe.y))
	for index in 300:
		field.uplift_at(float(index) * 13.1, float(index) * -5.7)
	for index in range(probes.size() - 1, -1, -1):
		var probe: Vector2 = probes[index]
		equal(field.uplift_at(probe.x, probe.y), first_pass[index],
			"the uplift changed its answer at (%f, %f) after other samples"
			% [probe.x, probe.y])
		equal(again.uplift_at(probe.x, probe.y), first_pass[index],
			"two fields with the same seed disagree at (%f, %f)" % [probe.x, probe.y])

	var differ := false
	for probe in probes:
		if other.uplift_at(probe.x, probe.y) != field.uplift_at(probe.x, probe.y):
			differ = true
	check(differ, "two seeds put their mountains in exactly the same places")

	# And the whole surface inherits it: a surface handed the biome map and one
	# left to build its own answer the same, because a biome field for a seed is
	# the same field however it was reached.
	var shared := TerrainSurfaceField.new(SEED, BiomeField.new(SEED))
	var alone := TerrainSurfaceField.new(SEED)
	for probe in probes:
		equal(shared.height_at(probe.x, probe.y), alone.height_at(probe.x, probe.y),
			"a surface given a biome field disagrees with one that built its own"
			+ " at (%f, %f)" % [probe.x, probe.y])


## Where the mask is shut it is shut *exactly*, so the ground is the identical
## float it was before this layer existed. Multiplying by 0.0 leaves a float
## alone; multiplying by 0.0001 does not, and "the far ground is unchanged"
## would then be a claim about rounding.
func _the_mask_is_exactly_zero_outside_a_range() -> void:
	var field := TerrainSurfaceField.new(SEED)
	var shut := 0
	var open := 0
	for index in 2000:
		# A long stride across the world, so the walk crosses several ranges
		# without landing on a lattice of any field it is sampling.
		var x := float(index) * 37.3 - 20000.0
		var z := float(index) * -23.9 + 9000.0
		var mask := field.uplift_mask_at(x, z)
		if mask > 0.0:
			open += 1
			continue
		shut += 1
		equal(field.uplift_at(x, z), 0.0,
			"the uplift is not exactly zero where the mask is shut, at (%f, %f)"
			% [x, z])
		equal(field.height_at(x, z), field.hill_height_at(x, z),
			"the ground moved where the mask is shut, at (%f, %f)" % [x, z])
	check(shut > 0 and open > 0,
		"the walk found only one kind of ground: %d shut, %d open" % [shut, open])


## Mountains are a region you walk into, not a tax on every hill. Over a square
## of world, most of the ground has to be exactly as tall as it was.
func _the_uplift_is_regional() -> void:
	for seed_value in [SEED, OTHER_SEED, 42]:
		var field := TerrainSurfaceField.new(seed_value)
		var lifted := 0
		var samples := 0
		for row in 61:
			for column in 61:
				var x := -900.0 + float(column) * 30.0
				var z := -900.0 + float(row) * 30.0
				samples += 1
				if field.uplift_at(x, z) > 1.0:
					lifted += 1
		var share := float(lifted) / float(samples)
		check(share < 0.5,
			"seed %d lifts %.1f%% of an 1800-unit square by more than a unit;"
			% [seed_value, 100.0 * share]
			+ " mountains would be the ground rather than a place in it")
		check(lifted > 0, "seed %d has no mountains at all near the origin" % seed_value)


## The rocky axis reaches the height of the land now, not only its colour.
## Highland ground stands well above meadow ground on the same seed.
func _the_rocky_axis_drives_the_uplift() -> void:
	var query := TerrainQuery.for_seed(SEED)
	var highland_total := 0.0
	var highland_count := 0
	var meadow_total := 0.0
	var meadow_count := 0
	for row in 81:
		for column in 81:
			var x := -1200.0 + float(column) * 30.0
			var z := -1200.0 + float(row) * 30.0
			var uplift := query.surface_field.uplift_at(x, z)
			match query.biome_at(x, z):
				BiomeCatalog.HIGHLAND:
					highland_total += uplift
					highland_count += 1
				BiomeCatalog.MEADOW:
					meadow_total += uplift
					meadow_count += 1
	check(highland_count > 100 and meadow_count > 100,
		"too little of either biome to compare: %d highland, %d meadow"
		% [highland_count, meadow_count])
	var highland := highland_total / maxf(1.0, float(highland_count))
	var meadow := meadow_total / maxf(1.0, float(meadow_count))
	check(highland > 4.0 * maxf(0.5, meadow),
		"highland does not stand high: it averages %.2f units of uplift"
		% highland + " against the meadow's %.2f" % meadow)


## The claim the user's word "climbable" makes: a route to the top exists that a
## character could actually walk, under the same step limits the tactical layer
## enforces.
##
## Searched forwards from the rim of the box inwards, so every step is tested in
## the direction it is taken -- which matters, because three units up is allowed
## and three units down is not. The route is then walked again from scratch and
## every step re-checked, so a bug in the search cannot pass this.
func _a_summit_can_be_climbed() -> void:
	var query := TerrainQuery.for_seed(SEED)
	var across := int(2.0 * CLIMB_REACH / LATTICE) + 1
	var heights := PackedFloat64Array()
	heights.resize(across * across)
	var solid := PackedByteArray()
	solid.resize(across * across)
	var summit := -1
	for row in across:
		var z := CLIMB_CENTRE.y - CLIMB_REACH + float(row) * LATTICE
		for column in across:
			var x := CLIMB_CENTRE.x - CLIMB_REACH + float(column) * LATTICE
			var index := row * across + column
			heights[index] = query.ground_height_at(x, z)
			solid[index] = 1 if query.is_passable_at(x, z) else 0
			if solid[index] == 1 and (summit < 0 or heights[index] > heights[summit]):
				summit = index

	check(heights[summit] > 40.0,
		"the highest ground in the box is only %.2f units up; there is no mountain here"
		% heights[summit])

	var came_from := PackedInt32Array()
	came_from.resize(across * across)
	came_from.fill(-1)
	var queue := PackedInt32Array()
	var foot := INF
	for row in across:
		for column in across:
			if row != 0 and row != across - 1 and column != 0 and column != across - 1:
				continue
			var index := row * across + column
			if solid[index] == 0:
				continue
			came_from[index] = index
			queue.append(index)
			foot = minf(foot, heights[index])

	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var column := index % across
		var row := index / across
		for offset in NEIGHBOURS:
			var next_column: int = column + offset.x
			var next_row: int = row + offset.y
			if next_column < 0 or next_row < 0 or next_column >= across or next_row >= across:
				continue
			var next := next_row * across + next_column
			if came_from[next] >= 0 or solid[next] == 0:
				continue
			var rise := heights[next] - heights[index]
			if rise > STEP_UP or -rise > STEP_DOWN:
				continue
			came_from[next] = index
			queue.append(next)

	check(came_from[summit] >= 0,
		"no route to the top: the search reached %d of %d cells and never the summit"
		% [queue.size(), across * across])
	if came_from[summit] < 0:
		return

	# Walk the route back out and check every step again, from the heights the
	# query answers now rather than from the ones the search cached.
	var steps := 0
	var worst_rise := 0.0
	var worst_fall := 0.0
	var walk := summit
	while came_from[walk] != walk:
		var previous := came_from[walk]
		var here := query.ground_height_at(
			CLIMB_CENTRE.x - CLIMB_REACH + float(walk % across) * LATTICE,
			CLIMB_CENTRE.y - CLIMB_REACH + float(walk / across) * LATTICE,
		)
		var before := query.ground_height_at(
			CLIMB_CENTRE.x - CLIMB_REACH + float(previous % across) * LATTICE,
			CLIMB_CENTRE.y - CLIMB_REACH + float(previous / across) * LATTICE,
		)
		worst_rise = maxf(worst_rise, here - before)
		worst_fall = maxf(worst_fall, before - here)
		steps += 1
		walk = previous
	check(steps > 20, "the route to the top is only %d steps long" % steps)
	check(worst_rise <= STEP_UP,
		"a step on the route climbs %.4f, past the %.2f limit" % [worst_rise, STEP_UP])
	check(worst_fall <= STEP_DOWN,
		"a step on the route drops %.4f, past the %.2f limit" % [worst_fall, STEP_DOWN])
	check(heights[summit] - foot > 25.0,
		"the route only climbed %.2f units" % (heights[summit] - foot))


## A road is never laid up ground a character could not walk.
##
## The path layer used to lay its lines without ever asking what was under them,
## which was fine in a world whose whole relief was thirty units. It is not fine
## now, so a road picks the flattest of a handful of candidate lines, scored by
## how far it climbs past the terrain query's own step up over one cell of the
## tactical lattice.
##
## Two things are checked, on the same walk. The land under every road is
## walkable: over every road within nine hundred units of the origin, walked at
## the lattice's own cell width, no step on the *carved bed* rises more than a
## character can climb. And the finished ground is too -- carving a road moves
## the ground, so the routing's guarantee is only worth what the carve leaves of
## it. The carve levels each stretch of ground to one road's centreline and to no
## blend of two, so on a road's own centreline it takes the height of the land
## under it less the depth of the trough, and the finished roadway climbs exactly
## what the land climbs. Both counts are zero; the second used to be four, and
## why is in reports/mountains.md.
func _a_road_is_never_laid_on_unwalkable_land() -> void:
	# The routing's limit really is the tactical layer's, restated rather than
	# imported so the path layer need not know a combat lattice exists.
	check(absf(PathNetwork.ROUTE_GRADE_LIMIT - STEP_UP / LATTICE) < 0.000001,
		"the routing's grade limit (%.4f) is no longer the step up over one cell"
		% PathNetwork.ROUTE_GRADE_LIMIT)
	check(absf(PathNetwork.ROUTE_SAMPLE_STEP - LATTICE) < 0.000001,
		"the routing samples every %.2f units, not every cell"
		% PathNetwork.ROUTE_SAMPLE_STEP)

	var query := TerrainQuery.for_seed(SEED)
	var network := query.path_network
	var steps := 0
	var bed_over := 0
	var carved_over := 0
	var worst_bed := 0.0
	for place in network.places_near(0.0, 0.0, 900.0):
		for edge in network.edges_from(place):
			var points: PackedVector2Array = edge["points"]
			var walked := PackedVector2Array()
			for index in points.size() - 1:
				var span := points[index].distance_to(points[index + 1])
				var pieces := maxi(1, int(ceil(span / LATTICE)))
				for piece in pieces:
					walked.append(points[index].lerp(
						points[index + 1], float(piece) / float(pieces)
					))
			walked.append(points[points.size() - 1])
			var last_bed := query.water_field.bed_height_at(walked[0].x, walked[0].y)
			var last_ground := query.ground_height_at(walked[0].x, walked[0].y)
			for index in range(1, walked.size()):
				var bed := query.water_field.bed_height_at(walked[index].x, walked[index].y)
				var ground := query.ground_height_at(walked[index].x, walked[index].y)
				steps += 1
				worst_bed = maxf(worst_bed, absf(bed - last_bed))
				if absf(bed - last_bed) > STEP_UP:
					bed_over += 1
				if absf(ground - last_ground) > STEP_UP:
					carved_over += 1
				last_bed = bed
				last_ground = ground
	check(steps > 3000, "only %d steps of road were walked" % steps)
	equal(bed_over, 0,
		"%d steps of road are laid on land that climbs more than %.1f in one cell;"
		% [bed_over, STEP_UP] + " the worst is %.3f" % worst_bed)
	equal(carved_over, 0,
		"%d of %d steps of finished roadway climb more than %.1f in one cell,"
		% [carved_over, steps, STEP_UP]
		+ " so the carving has put a wall in the middle of a road")
