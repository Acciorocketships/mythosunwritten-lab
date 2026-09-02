extends TestSuite
## The ground is a function of where you are, and nothing else.
##
## Two claims are checked here. First, that the surface field is pure: the
## height at a world position depends only on that position and the seed -- not
## on which chunk asked, in what order, or in which process. Second, that the
## chunk mesher inherits that purity: the geometry for a chunk coordinate is the
## same whether it was the first chunk built or the last, and the same in a
## fresh process as in this one.
class_name TestTerrain

const SEED := 20250824
const OTHER_SEED := 99


func _init() -> void:
	suite_name = "terrain"


func run() -> void:
	_field_is_a_pure_function()
	_field_depends_on_the_seed()
	_mesher_ignores_build_order()
	_a_chunk_fingerprint_follows_its_contents()
	_chunks_agree_along_their_shared_edge()
	_chunks_match_across_processes()


func _field_is_a_pure_function() -> void:
	var field := TerrainSurfaceField.new(SEED)
	var probes := [
		Vector2(0.0, 0.0), Vector2(13.5, -207.25), Vector2(-1024.0, 512.0),
		Vector2(3.125, 3.125), Vector2(-0.5, -0.5),
	]

	# Same question, asked twice, from two separate field objects.
	var again := TerrainSurfaceField.new(SEED)
	for probe in probes:
		equal(field.height_at(probe.x, probe.y), again.height_at(probe.x, probe.y),
			"two fields with the same seed disagree at (%f, %f)" % [probe.x, probe.y])

	# Same questions, asked in a different order, with unrelated samples in
	# between: a field drawing from a stream would drift here, a hashed one
	# cannot.
	var first_pass: Array[float] = []
	for probe in probes:
		first_pass.append(field.height_at(probe.x, probe.y))
	for i in 500:
		field.height_at(float(i) * 7.3, float(i) * -3.1)
	for index in range(probes.size() - 1, -1, -1):
		var probe: Vector2 = probes[index]
		equal(field.height_at(probe.x, probe.y), first_pass[index],
			"the field changed its answer at (%f, %f) after other samples"
			% [probe.x, probe.y])

	# The surface is continuous: a tiny step sideways is a tiny step in height.
	var here := field.height_at(40.0, -18.0)
	var nearby := field.height_at(40.001, -18.0)
	check(absf(here - nearby) < 0.05,
		"the surface jumped %f over a millimetre" % absf(here - nearby))

	# And it is not flat, or there would be nothing to look at.
	var lowest := INF
	var highest := -INF
	for i in 400:
		var height := field.height_at(float(i) * 5.0, float(i % 20) * 11.0)
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
	check(highest - lowest > 2.0,
		"the surface is nearly flat: range %f world units" % (highest - lowest))


func _field_depends_on_the_seed() -> void:
	var field := TerrainSurfaceField.new(SEED)
	var other := TerrainSurfaceField.new(OTHER_SEED)
	var differences := 0
	for i in 50:
		var x := float(i) * 9.0
		if absf(field.height_at(x, 4.0) - other.height_at(x, 4.0)) > 0.001:
			differences += 1
	check(differences > 40,
		"two seeds produced nearly the same ground: %d of 50 samples differed"
		% differences)


func _mesher_ignores_build_order() -> void:
	var subject := Vector2i(3, -2)
	var neighbours: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(-5, 7), Vector2i(3, -1), Vector2i(120, -400),
		Vector2i(2, -2), Vector2i(4, -2),
	]

	# A mesher that has never built anything.
	var fresh := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	var reference := fresh.build(subject.x, subject.y)

	# A mesher that has built a pile of other chunks first, in one order...
	var busy := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	for key in neighbours:
		busy.build(key.x, key.y)
	var after_others := busy.build(subject.x, subject.y)

	# ...and another that built the same chunks in the opposite order.
	var reversed := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	for index in range(neighbours.size() - 1, -1, -1):
		var key: Vector2i = neighbours[index]
		reversed.build(key.x, key.y)
	var after_reverse := reversed.build(subject.x, subject.y)

	equal(after_others.digest(), reference.digest(),
		"building other chunks first changed chunk (3, -2)")
	equal(after_reverse.digest(), reference.digest(),
		"the order chunks were built in changed chunk (3, -2)")
	equal(after_others.vertices, reference.vertices,
		"chunk (3, -2) came out with different vertices depending on build order")
	equal(after_others.normals, reference.normals,
		"chunk (3, -2) came out with different normals depending on build order")

	# The same chunk built twice from the same mesher is the same chunk, which is
	# what a reload after an unload depends on.
	equal(fresh.build(subject.x, subject.y).digest(), reference.digest(),
		"rebuilding chunk (3, -2) produced different geometry")

	# Sanity: different chunks are genuinely different geometry, so the check
	# above is not passing because every chunk looks alike.
	not_equal(fresh.build(0, 0).digest(), reference.digest(),
		"two different chunk coordinates produced identical geometry")

	var expected_triangles := TerrainChunkMesher.CELLS * TerrainChunkMesher.CELLS * 2
	equal(reference.triangle_count(), expected_triangles,
		"a chunk should be %d triangles" % expected_triangles)


func _a_chunk_fingerprint_follows_its_contents() -> void:
	# A chunk's fingerprint has to answer for what the chunk holds now, not for
	# what it held when it was built. Anything that caches the answer at build
	# time makes every later change invisible to every check that compares
	# fingerprints -- which is the one thing those checks exist to catch.
	var mesher := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	var geometry := mesher.build(3, -2)

	var before := geometry.digest()
	check(not before.is_empty(), "a built chunk should have a fingerprint")
	equal(geometry.digest(), before,
		"a chunk left alone changed its own fingerprint between two calls")

	# Move one corner of one triangle by a millimetre.
	var original: Vector3 = geometry.vertices[0]
	geometry.vertices[0] = original + Vector3(0.0, 0.001, 0.0)
	not_equal(geometry.digest(), before,
		"writing into a built chunk did not change its fingerprint")

	# ...and putting it back puts the fingerprint back, so the check above is
	# reacting to the contents rather than to having been called twice.
	geometry.vertices[0] = original
	equal(geometry.digest(), before,
		"undoing the write did not restore the chunk's fingerprint")

	# The same holds for a normal, which is the other half of what is hashed.
	var original_normal: Vector3 = geometry.normals[0]
	geometry.normals[0] = -original_normal
	not_equal(geometry.digest(), before,
		"changing a chunk's normals did not change its fingerprint")
	geometry.normals[0] = original_normal
	equal(geometry.digest(), before,
		"restoring the normal did not restore the chunk's fingerprint")


func _chunks_agree_along_their_shared_edge() -> void:
	# Neighbouring chunks are built independently, so their shared edge only
	# lines up if both derived it from world position rather than from each
	# other. Compare the vertices they each placed on the boundary.
	var mesher := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	var left := mesher.build(0, 0)
	var right := mesher.build(1, 0)
	var boundary_x := TerrainChunkMesher.CHUNK_SIZE

	var from_left := _heights_on_edge(left, boundary_x)
	var from_right := _heights_on_edge(right, boundary_x)
	check(from_left.size() >= TerrainChunkMesher.CELLS,
		"expected vertices along the chunk boundary, found %d" % from_left.size())
	equal(from_left, from_right,
		"neighbouring chunks disagree about the ground along their shared edge")


func _chunks_match_across_processes() -> void:
	# The claim is about separate runs, so this really runs the headless command
	# twice, in two fresh processes, and asks each for its chunk fingerprints.
	var first := _run_headless_chunks(1234)
	var second := _run_headless_chunks(1234)
	equal(first["exit_code"], 0,
		"headless run should exit 0 (output: %s)" % first["output"])
	var chunk_lines: PackedStringArray = first["chunks"]
	check(chunk_lines.size() > 10,
		"expected the headless run to report its loaded chunks, got %d line(s)"
		% chunk_lines.size())
	equal(first["chunks"], second["chunks"],
		"two separate runs of seed 1234 produced different chunk geometry")

	# And the same chunks, built here in this process, come out identical again.
	var mesher := TerrainChunkMesher.new(TerrainQuery.for_seed(1234))
	var reported: PackedStringArray = first["chunks"]
	var rebuilt := PackedStringArray()
	for line in reported:
		var parts := line.split(" ")
		var geometry := mesher.build(int(parts[1]), int(parts[2]))
		rebuilt.append("chunk %s %s %s" % [parts[1], parts[2], geometry.digest()])
	equal(rebuilt, first["chunks"],
		"rebuilding the chunks of seed 1234 in this process gave different geometry")


## The heights of every vertex a chunk placed on a given x, in the order the
## mesher emitted them.
func _heights_on_edge(geometry: TerrainChunkGeometry, x: float) -> PackedStringArray:
	var found := PackedStringArray()
	var seen := {}
	for vertex in geometry.vertices:
		if not is_equal_approx(vertex.x, x):
			continue
		var entry := "%.6f:%.6f" % [vertex.z, vertex.y]
		if seen.has(entry):
			continue
		seen[entry] = true
		found.append(entry)
	found.sort()
	return found


func _run_headless_chunks(seed_value: int) -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(seed_value),
		"--ticks", "20",
		"--chunks",
	], output, true)
	var chunks := PackedStringArray()
	for line in "\n".join(output).split("\n"):
		if line.begins_with("chunk "):
			chunks.append(line.strip_edges())
	return {"exit_code": exit_code, "output": "\n".join(output), "chunks": chunks}
