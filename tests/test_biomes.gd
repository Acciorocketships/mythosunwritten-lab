extends TestSuite
## The biome map: a pure function of position and seed, resolving into named
## biomes whose borders blend rather than snap.
##
## Four claims are checked here. That the biome at a position depends on that
## position and the seed and nothing else -- not on the order positions are
## sampled in, not on the order chunks are built in, not on the process. That
## all five named biomes actually occur, and that the twilight marsh occurs as a
## scattered pocket whose frequency does not depend on how far from spawn you
## are. That every named biome carries a full profile of plain data. And that
## walking across a border changes that profile gradually -- checked against
## what the same transect would look like if the profile snapped to whichever
## biome was strongest, which is the thing being ruled out.
class_name TestBiomes

const SEED := 20250824
const OTHER_SEED := 99

## How far from the origin the "far from spawn" census is taken. Far enough that
## no feature of the near census reaches it.
const FAR_FROM_SPAWN := Vector2(120000.0, -85000.0)


func _init() -> void:
	suite_name = "biomes"


func run() -> void:
	_the_biome_is_a_pure_function()
	_the_biome_depends_on_the_seed()
	_chunk_colours_ignore_build_order()
	_all_five_named_biomes_are_resolvable()
	_the_marsh_is_a_scattered_pocket()
	_every_named_biome_carries_a_full_profile()
	_borders_blend_rather_than_snap()
	_a_handed_out_profile_is_detached()
	_biomes_match_across_processes()


func _the_biome_is_a_pure_function() -> void:
	var field := BiomeField.new(SEED)
	var again := BiomeField.new(SEED)
	var probes := [
		Vector2(0.0, 0.0), Vector2(37.5, -412.25), Vector2(-2048.0, 1024.0),
		Vector2(6.25, 6.25), Vector2(-0.5, -0.5), Vector2(9000.0, 9000.0),
	]

	# Two field objects with the same seed answer identically.
	for probe in probes:
		equal(again.biome_at(probe.x, probe.y), field.biome_at(probe.x, probe.y),
			"two biome fields with the same seed disagree at (%f, %f)"
			% [probe.x, probe.y])
		equal(again.profile_at(probe.x, probe.y).digest(),
			field.profile_at(probe.x, probe.y).digest(),
			"two biome fields with the same seed blend differently at (%f, %f)"
			% [probe.x, probe.y])

	# The same questions asked in a different order, with hundreds of unrelated
	# samples in between: a field drawing from a stream would drift here.
	var first_pass: Array[String] = []
	for probe in probes:
		first_pass.append("%s/%s" % [
			field.biome_at(probe.x, probe.y), field.profile_at(probe.x, probe.y).digest(),
		])
	for i in 500:
		field.profile_at(float(i) * 7.3, float(i) * -3.1)
	for index in range(probes.size() - 1, -1, -1):
		var probe: Vector2 = probes[index]
		equal("%s/%s" % [
				field.biome_at(probe.x, probe.y),
				field.profile_at(probe.x, probe.y).digest(),
			], first_pass[index],
			"the biome field changed its answer at (%f, %f) after other samples"
			% [probe.x, probe.y])

	# The axes are continuous, so a step of a millimetre is a step of nothing.
	var here := field.axes_at(120.0, -64.0)
	var nearby := field.axes_at(120.001, -64.0)
	check(here.distance_to(nearby) < 0.001,
		"the biome axes jumped %f over a millimetre" % here.distance_to(nearby))

	# Every weight set is a share of one whole position.
	for probe in probes:
		var total := 0.0
		for id in BiomeCatalog.IDS:
			var weight := float(field.weights_at(probe.x, probe.y)[id])
			check(weight >= 0.0 and weight <= 1.0,
				"weight for %s at (%f, %f) is %f, outside [0, 1]"
				% [id, probe.x, probe.y, weight])
			total += weight
		check(absf(total - 1.0) < 0.0001,
			"the biome weights at (%f, %f) sum to %f, not 1"
			% [probe.x, probe.y, total])


func _the_biome_depends_on_the_seed() -> void:
	var field := BiomeField.new(SEED)
	var other := BiomeField.new(OTHER_SEED)
	var differences := 0
	for i in 60:
		var x := float(i) * 37.0
		if field.biome_at(x, 12.0) != other.biome_at(x, 12.0):
			differences += 1
	check(differences > 20,
		"two seeds produced nearly the same biome map: %d of 60 samples differed"
		% differences)


func _chunk_colours_ignore_build_order() -> void:
	# The ground's colour is part of the chunk the mesher builds, so the claim
	# that build order cannot change the biome is the same claim as the terrain
	# suite's, extended to the colours.
	var subject := Vector2i(5, -3)
	var neighbours: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(-9, 4), Vector2i(5, -2), Vector2i(300, -700),
		Vector2i(4, -3), Vector2i(6, -3),
	]

	var fresh := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	var reference := fresh.build(subject.x, subject.y)
	check(reference.colors.size() == reference.vertices.size(),
		"a built chunk should carry one ground colour per vertex, got %d for %d"
		% [reference.colors.size(), reference.vertices.size()])

	var busy := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	for key in neighbours:
		busy.build(key.x, key.y)
	var after_others := busy.build(subject.x, subject.y)

	var reversed := TerrainChunkMesher.new(TerrainQuery.for_seed(SEED))
	for index in range(neighbours.size() - 1, -1, -1):
		var key: Vector2i = neighbours[index]
		reversed.build(key.x, key.y)
	var after_reverse := reversed.build(subject.x, subject.y)

	equal(after_others.colors, reference.colors,
		"building other chunks first changed the ground colours of chunk (5, -3)")
	equal(after_reverse.colors, reference.colors,
		"the order chunks were built in changed the ground colours of chunk (5, -3)")

	# The colours are inside the chunk's fingerprint, so a change to them cannot
	# slip past the determinism checks that compare fingerprints.
	var before := reference.digest()
	var original: Color = reference.colors[0]
	reference.colors[0] = Color(original.r + 0.25, original.g, original.b)
	not_equal(reference.digest(), before,
		"repainting a chunk's ground did not change its fingerprint")
	reference.colors[0] = original
	equal(reference.digest(), before,
		"undoing the repaint did not restore the chunk's fingerprint")

	# A chunk built for a world and a chunk built from that world's seed alone
	# are coloured the same, so a test may build either.
	var world := SimWorld.new(SEED)
	var from_world := world.chunk_mesher.build(subject.x, subject.y)
	equal(from_world.colors, after_others.colors,
		"the world and a bare mesher of the same seed coloured chunk (5, -3) differently")


func _all_five_named_biomes_are_resolvable() -> void:
	var counts := _census(BiomeField.new(SEED), Vector2.ZERO, 90, 18.0)
	var total := 0
	for id in BiomeCatalog.IDS:
		total += int(counts[id])
	for id in BiomeCatalog.IDS:
		var share := 100.0 * float(counts[id]) / float(total)
		check(int(counts[id]) > 0,
			"the biome %s never occurs in a %d-sample region" % [id, total])
		check(share < 60.0,
			"the biome %s covers %.1f%% of the region -- it has swallowed the map"
			% [id, share])


func _the_marsh_is_a_scattered_pocket() -> void:
	# The design asks for the twilight marsh to turn up anywhere as an isolated
	# hollow, at the doorstep as readily as at the frontier. Census two regions
	# far apart and compare how much of each it takes.
	var field := BiomeField.new(SEED)
	var near := _census(field, Vector2.ZERO, 90, 18.0)
	var far := _census(field, FAR_FROM_SPAWN, 90, 18.0)
	var samples := 181 * 181

	var near_share := float(near[BiomeCatalog.TWILIGHT_MARSH]) / float(samples)
	var far_share := float(far[BiomeCatalog.TWILIGHT_MARSH]) / float(samples)

	check(near_share > 0.02 and far_share > 0.02,
		"the marsh should occur in both regions: %.1f%% near spawn, %.1f%% far away"
		% [near_share * 100.0, far_share * 100.0])
	check(near_share < 0.30 and far_share < 0.30,
		"the marsh should be a pocket, not a province: %.1f%% near spawn, %.1f%% far away"
		% [near_share * 100.0, far_share * 100.0])
	var ratio := maxf(near_share, far_share) / maxf(0.0001, minf(near_share, far_share))
	check(ratio < 3.0,
		"the marsh is %.1fx more common in one region than the other, so it is not"
		% ratio + " independent of distance from spawn"
		+ " (%.1f%% near, %.1f%% far)" % [near_share * 100.0, far_share * 100.0])

	# Scattered, not one blob: count how many separate blocks of the near region
	# contain marsh at all.
	var blocks_with_marsh := 0
	for block_row in 6:
		for block_column in 6:
			var found := false
			for row in 12:
				for column in 12:
					var x := float(block_column * 12 + column - 36) * 18.0
					var z := float(block_row * 12 + row - 36) * 18.0
					if field.biome_at(x, z) == BiomeCatalog.TWILIGHT_MARSH:
						found = true
						break
				if found:
					break
			if found:
				blocks_with_marsh += 1
	check(blocks_with_marsh >= 4,
		"the marsh turned up in only %d of 36 blocks, so it is one blob rather than"
		% blocks_with_marsh + " scattered pockets")


func _every_named_biome_carries_a_full_profile() -> void:
	var seen_tags := {}
	equal(BiomeCatalog.IDS.size(), 5, "there should be five named biomes")
	for id in BiomeCatalog.IDS:
		var profile := BiomeCatalog.profile(id)
		check(profile != null, "the catalog has no profile for %s" % id)
		if profile == null:
			continue
		equal(profile.id, id, "the profile for %s reports the wrong id" % id)
		check(not profile.display_name.is_empty(), "%s has no display name" % id)
		check(profile.fog_density > 0.0,
			"%s has fog density %f -- every biome needs some depth"
			% [id, profile.fog_density])
		check(profile.foliage_density >= 0.0 and profile.foliage_density <= 1.0,
			"%s has foliage density %f, outside [0, 1]" % [id, profile.foliage_density])
		check(profile.prop_tags.size() > 0, "%s allows no props at all" % id)
		for tag in profile.prop_tags:
			check(not tag.contains("/") and not tag.contains("."),
				"%s allows '%s', which looks like an asset path rather than a tag"
				% [id, tag])
		# Every colour is a real, distinct choice rather than a default.
		var tints := {
			"ground": profile.ground_tint, "tree": profile.tree_tint,
			"rock": profile.rock_tint, "fog": profile.fog_color,
			"sky top": profile.sky_top, "sky horizon": profile.sky_horizon,
			"ambient": profile.ambient_color,
		}
		for label in tints:
			var tint: Color = tints[label]
			check(tint.r + tint.g + tint.b > 0.0, "%s has a black %s colour" % [id, label])
		check(profile.sky_top != profile.sky_horizon,
			"%s has a flat sky: top and horizon are the same colour" % id)
		seen_tags[id] = profile.prop_tags

	# The biomes are told apart by what they look like, so two of them must not
	# be the same profile under two names.
	for id in BiomeCatalog.IDS:
		for other in BiomeCatalog.IDS:
			if id == other:
				continue
			not_equal(BiomeCatalog.profile(id).ground_tint,
				BiomeCatalog.profile(other).ground_tint,
				"%s and %s have the same ground colour" % [id, other])


func _borders_blend_rather_than_snap() -> void:
	var field := BiomeField.new(SEED)
	var border := _find_border(field)
	check(border.has("at"),
		"no biome border was found to sample -- the map may have collapsed to one biome")
	if not border.has("at"):
		return

	var at: Vector2 = border["at"]
	var along: Vector2 = border["along"]
	var samples := 240
	var span := 24.0

	var blended: Array[BiomeProfile] = []
	var snapped: Array[BiomeProfile] = []
	for i in samples:
		var offset := (float(i) / float(samples - 1) - 0.5) * 2.0 * span
		var point := at + along * offset
		blended.append(field.profile_at(point.x, point.y))
		# What the same walk would look like if the profile were looked up by
		# whichever biome happened to be strongest: the thing being ruled out.
		snapped.append(BiomeCatalog.profile(field.biome_at(point.x, point.y)))

	var blended_total := _profile_distance(blended[0], blended[samples - 1])
	var snapped_total := _profile_distance(snapped[0], snapped[samples - 1])
	check(blended_total > 0.1,
		"the transect crossed no visible change: profiles differ by only %f"
		% blended_total)

	var blended_step := 0.0
	var snapped_step := 0.0
	var gradual_steps := 0
	for i in range(1, samples):
		var step := _profile_distance(blended[i - 1], blended[i])
		blended_step = maxf(blended_step, step)
		snapped_step = maxf(snapped_step, _profile_distance(snapped[i - 1], snapped[i]))
		if step > blended_total * 0.002:
			gradual_steps += 1

	check(blended_step < blended_total * 0.15,
		"the blended profile moved %.1f%% of the whole change in a single step, which"
		% (100.0 * blended_step / blended_total) + " is a snap, not a blend")
	check(gradual_steps > 30,
		"the change happened over only %d of %d steps" % [gradual_steps, samples - 1])
	check(snapped_step > snapped_total * 0.5,
		"the control did not snap (%.1f%% of the change in its largest step), so the"
		% (100.0 * snapped_step / maxf(0.0001, snapped_total))
		+ " comparison above proves nothing")

	# Fog density and foliage density are read separately by the render shell
	# and by the scatter layer, so check they slide too rather than only the
	# combined measure above.
	var fog_step := 0.0
	var foliage_step := 0.0
	for i in range(1, samples):
		fog_step = maxf(fog_step, absf(blended[i].fog_density - blended[i - 1].fog_density))
		foliage_step = maxf(
			foliage_step, absf(blended[i].foliage_density - blended[i - 1].foliage_density)
		)
	var fog_total := absf(blended[samples - 1].fog_density - blended[0].fog_density)
	var foliage_total := absf(
		blended[samples - 1].foliage_density - blended[0].foliage_density
	)
	if fog_total > 0.0005:
		check(fog_step < fog_total * 0.2,
			"fog density jumped %.1f%% of its change in one step"
			% (100.0 * fog_step / fog_total))
	if foliage_total > 0.02:
		check(foliage_step < foliage_total * 0.2,
			"foliage density jumped %.1f%% of its change in one step"
			% (100.0 * foliage_step / foliage_total))


func _a_handed_out_profile_is_detached() -> void:
	# A profile is data the simulation hands out. Whatever a holder does to it,
	# the catalog every later sample reads must be unchanged.
	var before := BiomeCatalog.profile(BiomeCatalog.MEADOW)
	var handed := BiomeCatalog.profile(BiomeCatalog.MEADOW)
	handed.ground_tint = Color(1.0, 0.0, 1.0)
	handed.foliage_density = 0.0
	handed.prop_tags.append("smuggled_in")
	var after := BiomeCatalog.profile(BiomeCatalog.MEADOW)
	equal(after.ground_tint, before.ground_tint,
		"writing into a handed-out profile changed the catalog's ground colour")
	equal(after.prop_tags, before.prop_tags,
		"writing into a handed-out profile changed the catalog's prop tags")

	var field := BiomeField.new(SEED)
	var sampled := field.profile_at(0.0, 0.0)
	var digest_before := sampled.digest()
	sampled.prop_tags.append("smuggled_in")
	sampled.fog_density = 99.0
	var resampled := field.profile_at(0.0, 0.0)
	equal(resampled.digest(), digest_before,
		"writing into a sampled profile changed what the field answers next time")


func _biomes_match_across_processes() -> void:
	# The claim is about separate runs, so this really runs the headless command
	# twice, in two fresh processes, and asks each for its biome map.
	var first := _run_headless_biomes(1234)
	var second := _run_headless_biomes(1234)
	equal(first["exit_code"], 0,
		"headless run should exit 0 (output: %s)" % first["output"])
	var lines: PackedStringArray = first["biomes"]
	check(lines.size() > 100,
		"expected the headless run to report its biome map, got %d line(s)"
		% lines.size())
	equal(first["biomes"], second["biomes"],
		"two separate runs of seed 1234 produced different biomes")

	# And the same positions, resolved here in this process, come out identical.
	var field := BiomeField.new(1234)
	var rebuilt := PackedStringArray()
	var named := {}
	for line in lines:
		var parts := line.split(" ")
		var x := float(parts[1])
		var z := float(parts[2])
		var id := field.biome_at(x, z)
		named[id] = true
		rebuilt.append("biome %.1f %.1f %s %.6f %s" % [
			x, z, id, float(field.weights_at(x, z)[id]), field.profile_at(x, z).digest(),
		])
	equal(rebuilt, lines,
		"resolving seed 1234's biomes in this process gave a different map")
	check(named.size() >= 2,
		"the reported lattice only reached %d biome(s), so the comparison is weak"
		% named.size())


## How many of each biome a square region of samples resolves to.
func _census(field: BiomeField, centre: Vector2, span: int, spacing: float) -> Dictionary:
	var counts := {}
	for id in BiomeCatalog.IDS:
		counts[id] = 0
	for row in range(-span, span + 1):
		for column in range(-span, span + 1):
			var x := centre.x + float(column) * spacing
			var z := centre.y + float(row) * spacing
			counts[field.biome_at(x, z)] += 1
	return counts


## A place where the strongest biome changes, and the direction to walk to cross
## it. Returns {} if the search found nothing, which would itself be a failure.
func _find_border(field: BiomeField) -> Dictionary:
	var step := 3.0
	for line in 8:
		var z := float(line) * 137.0
		var previous := field.biome_at(-1200.0, z)
		for i in range(1, 800):
			var x := -1200.0 + float(i) * step
			var here := field.biome_at(x, z)
			if here == previous:
				continue
			previous = here
			# Only a border worth measuring: the two sides must actually look
			# different, or "gradual" would be indistinguishable from "flat".
			var left := BiomeCatalog.profile(field.biome_at(x - 24.0, z))
			var right := BiomeCatalog.profile(field.biome_at(x + 24.0, z))
			if left.id == right.id or _profile_distance(left, right) < 0.3:
				continue
			return {"at": Vector2(x, z), "along": Vector2(1.0, 0.0)}
	return {}


## How far apart two profiles look, as one number. The colours dominate; fog
## density is scaled up because it lives in thousandths of a fraction per world
## unit, and foliage density is already in [0, 1].
func _profile_distance(a: BiomeProfile, b: BiomeProfile) -> float:
	var total := 0.0
	var pairs := [
		[a.ground_tint, b.ground_tint], [a.tree_tint, b.tree_tint],
		[a.rock_tint, b.rock_tint], [a.fog_color, b.fog_color],
		[a.sky_top, b.sky_top], [a.sky_horizon, b.sky_horizon],
		[a.ambient_color, b.ambient_color],
	]
	for pair in pairs:
		var first: Color = pair[0]
		var second: Color = pair[1]
		total += Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length()
	total += absf(a.fog_density - b.fog_density) * 200.0
	total += absf(a.foliage_density - b.foliage_density)
	return total


func _run_headless_biomes(seed_value: int) -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(seed_value),
		"--ticks", "5",
		"--biomes",
	], output, true)
	var biomes := PackedStringArray()
	for line in "\n".join(output).split("\n"):
		if line.begins_with("biome "):
			biomes.append(line.strip_edges())
	return {"exit_code": exit_code, "output": "\n".join(output), "biomes": biomes}
