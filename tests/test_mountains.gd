extends TestSuite
## The mountains are a place in the ground, and a character can walk up one.
##
## Three claims, and the second is the one the whole task turns on.
##
## 1. **Rocky country stands high.** Highland ground stands far above meadow
##    ground on the same seed -- the axis that used to reach only the palette
##    reaches the height of the land.
## 2. **A summit can be climbed.** A breadth-first search over the *real* height
##    function, on the tactical lattice, under the tactical lattice's own step
##    limits, finds a route from the rim of a box to the highest ground inside
##    it. Nothing is asserted from an amplitude and nothing is read from a
##    stored path: the route is found here, in this process, and then every one
##    of its steps is re-checked against the limits.
## 3. **A road is never laid on ground nobody could walk up, and the carving
##    leaves it that way.** The path layer picks the flattest of a handful of
##    candidate lines, against the same step limit; this checks that the limit it
##    uses is that one, that no road anywhere near the origin is laid on land
##    that breaks it, and that no step of the finished roadway breaks it either.
##
## Four further claims stood here until the ground was rebuilt on the adopted
## base (W-ground-rebuild): that `ValueNoise.ridged_sample` is the folded field,
## that the uplift is a pure function, that the mountain mask is exactly zero
## outside a range, and that the uplift is regional. All four were about the
## retired MountainField and about SimTerrainSurfaceField's decomposition of its
## own height into hills plus uplift. The adopted heightfield has no such
## decomposition -- its ridged relief *is* the ground -- so those four checks
## had nothing left to be about and went with the layer they documented. What
## they were guarding is not lost: the ground's purity is TestTerrain's first
## claim, and "a mountain is a place you walk into" is what claims 1 and 2 below
## say in terms of the world rather than of a mask.
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
## only the place to look is. The figure was found on the retired height field
## and has not been re-derived on the adopted one, which is why the summit check
## below is currently red -- re-finding the adopted ground's tall places belongs
## to W-adopt-suites, and moving the box here to make the check pass would be
## choosing the answer.
const CLIMB_CENTRE := Vector2(-28.0, 107.0)

const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _init() -> void:
	suite_name = "mountains"


func run() -> void:
	_rocky_country_stands_high()
	_a_summit_can_be_climbed()
	_a_road_is_never_laid_on_unwalkable_land()


## The rocky axis reaches the height of the land, not only its colour.
## Highland ground stands well above meadow ground on the same seed.
##
## It used to be asked of the uplift the retired mountain layer added. The
## adopted heightfield adds nothing to anything -- it is one carved surface --
## so the same claim is now asked of the ground's own uncarved height, which is
## the quantity the old uplift was a part of. The comparison is against the
## meadow's mean rather than against zero, because a height has a datum and an
## uplift did not.
func _rocky_country_stands_high() -> void:
	var query := TerrainQuery.for_seed(SEED)
	var highland_total := 0.0
	var highland_count := 0
	var meadow_total := 0.0
	var meadow_count := 0
	for row in 81:
		for column in 81:
			var x := -1200.0 + float(column) * 30.0
			var z := -1200.0 + float(row) * 30.0
			var height := query.ground.base_height(x, z)
			match query.biome_at(x, z):
				BiomeCatalog.HIGHLAND:
					highland_total += height
					highland_count += 1
				BiomeCatalog.MEADOW:
					meadow_total += height
					meadow_count += 1
	check(highland_count > 100 and meadow_count > 100,
		"too little of either biome to compare: %d highland, %d meadow"
		% [highland_count, meadow_count])
	var highland := highland_total / maxf(1.0, float(highland_count))
	var meadow := meadow_total / maxf(1.0, float(meadow_count))
	check(highland - meadow > 4.0,
		"highland does not stand high: it averages %.2f units"
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
			var last_bed := query.ground.ground_height(walked[0].x, walked[0].y)
			var last_ground := query.ground_height_at(walked[0].x, walked[0].y)
			for index in range(1, walked.size()):
				var bed := query.ground.ground_height(walked[index].x, walked[index].y)
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
