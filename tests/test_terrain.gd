extends TestSuite
## The ground is a function of where you are, and nothing else.
##
## One claim is checked here: the ground is pure -- the height at a world
## position depends only on that position and the seed, not on what has been
## asked before, in what order, or in which process. Since the base adoption the
## field asked is the adopted heightfield itself, through AdoptedGround.
##
## There used to be a second half, about a chunk mesher of this project's own
## inheriting that purity. There is no such mesher any more: the ground on the
## screen is meshed by the adopted base's own `TerrainChunkMesher` inside its
## own streamer, in the render layer, and the base's suite
## (`tests/test_terrain_chunk_mesher.gd`) is what answers for it. What this
## suite keeps is the claim every layer above leans on, which was always about
## the field and never about the mesh.
class_name TestTerrain

const SEED := 20250824
const OTHER_SEED := 99

## How far the adopted base's flat spawn clearing reaches, in world units:
## HeightfieldPlan.height01's falloff is exactly zero inside this radius.
const SPAWN_CLEARING := 60.0

## Where the two-seeds line starts, in world units. Past 60 + 180 = 240, where
## the clearing's falloff has fully faded back in, so every sample on the line
## is ground the seed actually chose.
const SEED_LINE_START := 300.0


func _init() -> void:
	suite_name = "terrain"


func run() -> void:
	_field_is_a_pure_function()
	_field_depends_on_the_seed()


func _field_is_a_pure_function() -> void:
	var field := AdoptedGround.shared_for_seed(SEED)
	var probes := [
		Vector2(0.0, 0.0), Vector2(13.5, -207.25), Vector2(-1024.0, 512.0),
		Vector2(3.125, 3.125), Vector2(-0.5, -0.5),
	]

	# Same question, asked twice, from two separate field objects. The second
	# is built rather than shared, because "two fields with the same seed
	# agree" is only a claim if there really are two stacks of plans.
	var again := AdoptedGround.new(SEED)
	for probe in probes:
		equal(field.base_height(probe.x, probe.y), again.base_height(probe.x, probe.y),
			"two fields with the same seed disagree at (%f, %f)" % [probe.x, probe.y])

	# Same questions, asked in a different order, with unrelated samples in
	# between: a field drawing from a stream would drift here, a hashed one
	# cannot.
	var first_pass: Array[float] = []
	for probe in probes:
		first_pass.append(field.base_height(probe.x, probe.y))
	for i in 500:
		field.base_height(float(i) * 7.3, float(i) * -3.1)
	for index in range(probes.size() - 1, -1, -1):
		var probe: Vector2 = probes[index]
		equal(field.base_height(probe.x, probe.y), first_pass[index],
			"the field changed its answer at (%f, %f) after other samples"
			% [probe.x, probe.y])

	# The surface is continuous: a tiny step sideways is a tiny step in height.
	var here := field.base_height(40.0, -18.0)
	var nearby := field.base_height(40.001, -18.0)
	check(absf(here - nearby) < 0.05,
		"the surface jumped %f over a millimetre" % absf(here - nearby))

	# And it is not flat, or there would be nothing to look at.
	var lowest := INF
	var highest := -INF
	for i in 400:
		var height := field.base_height(float(i) * 5.0, float(i % 20) * 11.0)
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
	check(highest - lowest > 2.0,
		"the surface is nearly flat: range %f world units" % (highest - lowest))


## Two seeds are two worlds -- outside the spawn clearing, which is the same
## flat ground in every one of them.
##
## The clearing is the adopted base's own doing and is deliberate:
## HeightfieldPlan.height01 multiplies the whole layered field by
## smootherstep((|pos| - 60) / 180) clamped to [0, 1], so within sixty units of
## the origin the height is exactly 0.0 whatever the seed is, and it fades back
## in over the next hundred and eighty. Asking "do two seeds differ" along a
## line that starts at the origin therefore spends its first thirteen samples
## inside a clearing neither seed chose, which is what the 37-of-50 reading
## that first failed this check was measuring. So the clearing is asserted
## here in its own right, and the difference is asked of ground outside it.
##
## The count below is the bar this check has always used, unchanged: more than
## forty of fifty samples must differ. It currently reads forty-one, which is a
## thin margin -- nine samples agree even out there, on flat cells where both
## seeds happen to sit on the same storey.
func _field_depends_on_the_seed() -> void:
	var field := AdoptedGround.shared_for_seed(SEED)
	var other := AdoptedGround.shared_for_seed(OTHER_SEED)

	# The clearing: exactly zero, exactly the same, on both seeds. Exactly
	# rather than nearly, because the falloff multiplies by exactly 0.0 in
	# there and multiplying by exactly zero changes no float.
	for index in 20:
		var angle := TAU * float(index) / 20.0
		var x := cos(angle) * SPAWN_CLEARING * 0.667
		var z := sin(angle) * SPAWN_CLEARING * 0.667
		equal(field.base_height(x, z), 0.0,
			"the spawn clearing is not flat at (%f, %f)" % [x, z])
		equal(other.base_height(x, z), field.base_height(x, z),
			"two seeds disagree inside the spawn clearing at (%f, %f)" % [x, z])

	# And outside it, the two worlds are different ground.
	var differences := 0
	for i in 50:
		var x := SEED_LINE_START + float(i) * 9.0
		if absf(field.base_height(x, 4.0) - other.base_height(x, 4.0)) > 0.001:
			differences += 1
	check(differences > 40,
		"two seeds produced nearly the same ground: %d of 50 samples differed"
		% differences)
