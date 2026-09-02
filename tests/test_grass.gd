extends TestSuite
## The instanced grass: where it grows, what decides it, what it costs to change
## its detail, and -- the load-bearing one -- that none of it reaches the world.
##
## The last of those is the reason this suite exists in the shape it does. The
## grass layer is the first thing in the project that is generated in the render
## shell rather than in the simulation, which is a decision (nothing in the world
## can interact with a blade of grass, so it belongs to the picture) and a
## decision has to be checked rather than asserted. Two checks do that from
## opposite ends: a headless process is shown never to load the file at all, and
## the same seed run through the render shell with and without the layer is shown
## to reach a byte-identical world.
##
## The rest is about the layer itself: a tuft stands on the ground the shell is
## drawing and nowhere else, how many there are comes from the biome's foliage
## density and what colour they are comes from its foliage tint, the level of
## detail hides tufts without rebuilding anything, and a chunk of grass is a pure
## function of its chunk and the seed.
##
## The floating islands are the same layer growing on a different surface, and
## they add one claim of their own: **an island's grass belongs to the island.**
## The two walkable storeys overlap in plan, so a hash reading world position
## would grow the same patch twice, one plate directly above the other. Three
## checks hold that from three sides -- an island carried across the world keeps
## exactly the grass it had, two storeys that lap over each other are shown to
## share world lattice cells and yet place nothing in the same spot, and the same
## island grown in a second process comes back identical.
class_name TestGrass

const SEED := 5
const FIXED_FPS := 60
const FRAMES := 90
## FRAMES / FIXED_FPS seconds of simulated time, at the shell's tick rate of 20.
const EXPECTED_TICKS := 30

## Twenty floats per instance in a multimesh buffer: twelve of transform, four
## of colour, four of custom data.
const STRIDE := 20

## Where in those twenty the position, the colour and the phase are.
const AT_X := 3
const AT_Y := 7
const AT_Z := 11
const AT_COLOR := 12
const AT_PHASE := 16

## A chunk high enough above the water table that nothing anywhere is wet, for
## the synthetic chunks the density check builds.
const DRY_HEIGHT := 500.0

## How many island cells either way the island checks scan, and the wider scan
## the overlap check needs: an upper storey laps over the lower one's rim by
## design, so the overlap is a thin lens and it takes a good many pairs to gather
## enough grass standing in one to conclude anything.
const SCAN_CELLS := 5
const OVERLAP_CELLS := 9

## The seeds the overlap check runs over. More than one, because everything about
## an island is hashed per island and a claim about one world is a claim about a
## few dozen plates.
const OVERLAP_SEEDS := [11, 1234, 7]


func _init() -> void:
	suite_name = "grass"


func run() -> void:
	_the_tuft_is_the_grass_tag_baked_out_of_the_asset_table()
	_a_patch_holds_many_tufts_and_every_one_of_them_carries_its_own_root()
	_every_tuft_stands_on_the_ground_the_shell_is_drawing()
	_no_tuft_stands_in_water_or_on_a_cliff_or_inside_a_building()
	_how_much_grows_and_what_colour_it_is_come_from_the_biome_profile()
	_the_tint_divides_by_the_colour_the_art_actually_is()
	_the_clearing_mask_is_a_pure_function_of_world_position_and_the_seed()
	_the_mask_wanders_rather_than_flickering_from_cell_to_cell()
	_the_curve_sends_weak_ground_bare_and_moderate_ground_closed()
	_grass_is_thicker_in_the_open_than_under_a_closed_canopy()
	_grass_coverage_blends_across_a_biome_border()
	_the_level_of_detail_hides_tufts_and_rebuilds_nothing()
	_a_chunk_of_grass_is_a_pure_function_of_its_chunk_and_the_seed()
	_an_islands_grass_stands_on_the_islands_own_top()
	_an_islands_grass_belongs_to_the_island_not_to_where_it_hangs()
	_two_storeys_that_overlap_grow_different_grass()
	_two_processes_grow_the_same_grass_on_an_island()
	_headless_creates_no_grass_at_all()
	_the_world_is_byte_identical_with_and_without_the_grass()


## The tuft is the `grass` tag's own row, collapsed into one mesh.
##
## The point of the asset-tag indirection is that what a thing looks like is one
## edit to one table. An instanced layer could easily have escaped that by
## building its own blade out of numbers; this one does not, and the check is
## that repointing the tag changes the mesh the layer would draw.
func _the_tuft_is_the_grass_tag_baked_out_of_the_asset_table() -> void:
	AssetLibrary.restore_defaults()
	var baked := AssetLibrary.instanced_mesh(AssetTags.GRASS)
	var mesh: Mesh = baked["mesh"]
	check(mesh != null, "the grass tag bakes to no mesh at all")
	if mesh == null:
		return
	equal(mesh.get_surface_count(), 1,
		"a tuft should bake down to one surface, so a chunk of grass is one draw call")
	check(int(baked["triangles"]) > 0, "the baked tuft has no triangles")
	check(float(baked["height"]) > 0.0, "the baked tuft has no height")
	# Every vertex carries the colour its own art reads as, which is what the
	# biome tint is a shift away from. Without it the shader would have nothing
	# to multiply.
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	equal(colors.size(), int(baked["vertices"]),
		"the baked tuft does not carry a colour per vertex")

	# Repoint the tag at something else and the bake follows it.
	var elsewhere := AssetLibrary.visual(AssetTags.BOULDER)
	check(elsewhere != null, "the boulder tag has no row to repoint grass at")
	if elsewhere != null:
		AssetLibrary.repoint(AssetTags.GRASS, elsewhere)
		var swapped := AssetLibrary.instanced_mesh(AssetTags.GRASS)
		not_equal(int(swapped["triangles"]), int(baked["triangles"]),
			"repointing the grass tag left the baked tuft unchanged: the grass "
			+ "layer is not reading the asset table")
	AssetLibrary.restore_defaults()


## The instanced unit is a patch of tufts, and every tuft in it carries its own
## root through to the shader.
##
## Two things are checked, because the second is the one that can silently rot.
## First, that the patch really holds PATCH_COPIES turns of the row -- the count,
## the triangles and the blades all multiply, and the copies are spread over the
## span rather than stacked. Second, and the point of the whole exercise, that
## every copy's own root is written into the second texture-coordinate channel
## and that the shader takes its root from *there* rather than from the instance
## origin. With one root for a dozen blades a gust arrives on a whole patch at
## once and a character standing at one corner of it flattens the other corner
## two metres away, which is exactly the failure a wide unit invites.
func _a_patch_holds_many_tufts_and_every_one_of_them_carries_its_own_root() -> void:
	AssetLibrary.restore_defaults()
	var one := AssetLibrary.instanced_mesh(AssetTags.GRASS)
	var patch := AssetLibrary.instanced_mesh(
		AssetTags.GRASS, GrassLayer.PATCH_COPIES, GrassLayer.PATCH_SPAN
	)
	check(GrassLayer.PATCH_COPIES > 1,
		"the grass unit is a single tuft again, so nothing below means anything")
	equal(int(patch["copies"]), GrassLayer.PATCH_COPIES,
		"a patch baked %d copies, not the %d it was asked for"
		% [int(patch["copies"]), GrassLayer.PATCH_COPIES])
	equal(int(patch["triangles"]), int(one["triangles"]) * GrassLayer.PATCH_COPIES,
		"a patch of %d does not cost %d times one tuft" % [
			GrassLayer.PATCH_COPIES, GrassLayer.PATCH_COPIES,
		])
	equal(int(patch["blades"]), int(one["blades"]) * GrassLayer.PATCH_COPIES,
		"a patch of %d does not hold %d times one tuft's blades" % [
			GrassLayer.PATCH_COPIES, GrassLayer.PATCH_COPIES,
		])
	var mesh: Mesh = patch["mesh"]
	check(mesh != null, "a patch bakes to no mesh at all")
	if mesh == null:
		return
	equal(mesh.get_surface_count(), 1,
		"a patch should still bake down to one surface, so a chunk is one draw call")

	# Every vertex carries the root of its own copy, and there are as many
	# distinct roots as there are copies, spread over the span.
	var arrays := mesh.surface_get_arrays(0)
	var roots: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	equal(roots.size(), int(patch["vertices"]),
		"the baked patch does not carry a root per vertex")
	var distinct := {}
	var furthest := 0.0
	for root in roots:
		distinct[root] = true
		furthest = maxf(furthest, root.length())
	equal(distinct.size(), GrassLayer.PATCH_COPIES,
		"the patch's %d vertices carry %d distinct roots, not %d: the copies are "
		% [roots.size(), distinct.size(), GrassLayer.PATCH_COPIES]
		+ "sharing a root, so the wind would move them as one")
	check(furthest > GrassLayer.PATCH_SPAN * 0.25,
		"the furthest copy sits %.2f from the middle of a patch %.2f wide: the "
		% [furthest, GrassLayer.PATCH_SPAN]
		+ "copies are stacked rather than spread")
	check(furthest <= GrassLayer.PATCH_SPAN, "a copy sits %.2f outside its span"
		% furthest)

	# And the shader reads it. A wide unit whose wind still took the instance
	# origin would pass everything above and be wrong in the one way that
	# matters, so the contract is pinned where it is used.
	check(GrassLayer.GRASS_SHADER.contains("UV2"),
		"the grass shader does not mention UV2, so it cannot be reading each "
		+ "blade's own root")
	check(not GrassLayer.GRASS_SHADER.contains("root = MODEL_MATRIX[3]"),
		"the grass shader still takes a blade's root from the instance origin, "
		+ "which with %d tufts in an instance bends whole patches as one object"
		% GrassLayer.PATCH_COPIES)


## A tuft stands on the ground the shell is drawing, not near it.
##
## The layer reads the height off the triangle under the blade rather than asking
## the height field again, precisely so that the two cannot disagree; this checks
## the arithmetic that does it, against an independent search over the chunk's
## triangles that shares no code with it.
func _every_tuft_stands_on_the_ground_the_shell_is_drawing() -> void:
	var world := SimWorld.new(SEED)
	var layer := GrassLayer.new(world.terrain, world.world_seed)
	var checked := 0
	var worst := 0.0
	var outside := 0
	for key in world.terrain_streamer.loaded_keys():
		var geometry := world.terrain_streamer.geometry(key)
		var view := layer.build(geometry)
		if view == null:
			continue
		var buffer: PackedFloat32Array = view.multimesh.buffer
		var origin_x := float(key.x) * TerrainChunkMesher.CHUNK_SIZE
		var origin_z := float(key.y) * TerrainChunkMesher.CHUNK_SIZE
		for at in view.multimesh.instance_count:
			var x := buffer[at * STRIDE + AT_X]
			var y := buffer[at * STRIDE + AT_Y]
			var z := buffer[at * STRIDE + AT_Z]
			if x < origin_x or x > origin_x + TerrainChunkMesher.CHUNK_SIZE \
					or z < origin_z or z > origin_z + TerrainChunkMesher.CHUNK_SIZE:
				outside += 1
				continue
			var surface := _surface_under(geometry, x, z)
			worst = maxf(worst, absf(surface - y))
			checked += 1
		view.free()
	check(checked > 500,
		"only %d tufts were there to check; the world under the observer grew "
		% checked + "almost no grass, so this check proves little")
	equal(outside, 0, "%d tufts stood outside the chunk they belong to" % outside)
	check(worst < 0.001,
		"a tuft floated or sank %.4f units off the triangle it stands on" % worst)


## Nothing grows where nothing should.
##
## Water, cliffs and the floors of buildings, each asked of the simulation rather
## than of the layer -- so this is a check that the layer agrees with the world
## and not that it agrees with itself.
func _no_tuft_stands_in_water_or_on_a_cliff_or_inside_a_building() -> void:
	var world := SimWorld.new(SEED)
	var layer := GrassLayer.new(world.terrain, world.world_seed)
	var wet := 0
	var impassable := 0
	var steep := 0
	var indoors := 0
	var checked := 0
	for key in world.terrain_streamer.loaded_keys():
		var geometry := world.terrain_streamer.geometry(key)
		var view := layer.build(geometry)
		if view == null:
			continue
		var buffer: PackedFloat32Array = view.multimesh.buffer
		for at in view.multimesh.instance_count:
			var x := buffer[at * STRIDE + AT_X]
			var z := buffer[at * STRIDE + AT_Z]
			checked += 1
			if world.terrain.is_water_at(x, z):
				wet += 1
			if not world.terrain.is_passable_at(x, z):
				impassable += 1
			if world.terrain.normal_at(x, z).y < GrassLayer.SLOPE_COS - 0.12:
				steep += 1
			if world.terrain.is_reserved_at(x, z):
				indoors += 1
		view.free()
	check(checked > 500, "only %d tufts were there to check" % checked)
	equal(wet, 0, "%d tufts grew in the water" % wet)
	equal(impassable, 0, "%d tufts grew where the world is not solid" % impassable)
	equal(steep, 0, "%d tufts grew on ground steeper than the layer allows" % steep)
	equal(indoors, 0, "%d tufts grew inside a building's floor" % indoors)


## How thickly it grows and what colour it is are the biome's, and nothing else's.
##
## Both are checked on synthetic chunks: flat ground, a known colour, and high
## enough that no water and no village can reach it. Everything that could vary
## is then held still except the biome, so what is left is the rule -- the share
## of the lattice that grows must be the profile's foliage density (scaled and
## floored), and the colour of a blade must be the ground colour under it carried
## half way to the profile's foliage tint.
func _how_much_grows_and_what_colour_it_is_come_from_the_biome_profile() -> void:
	var world := SimWorld.new(SEED)
	var layer := GrassLayer.new(world.terrain, world.world_seed)
	var ground := Color(0.5, 0.5, 0.5)
	var reference: Color = AssetLibrary.instanced_mesh(AssetTags.GRASS)["reference"]
	var seen := {}
	var tested := 0
	var bare_chunks := 0
	var closed_chunks := 0
	var worst_density := 0.0

	# A wide sweep of chunk coordinates, so several biomes are met. Every one is
	# used; the biome census below is what says the sweep was worth making.
	for chunk_x in range(-30, 31, 6):
		for chunk_z in range(-30, 31, 6):
			var origin_x := float(chunk_x) * TerrainChunkMesher.CHUNK_SIZE
			var origin_z := float(chunk_z) * TerrainChunkMesher.CHUNK_SIZE
			if world.terrain.settlement_at(origin_x + 8.0, origin_z + 8.0) != null:
				continue
			var leaf := PackedColorArray()
			var on_a_road := false
			for row in 2:
				for column in 2:
					var profile := world.terrain.profile_at(
						origin_x + float(column) * TerrainChunkMesher.CHUNK_SIZE,
						origin_z + float(row) * TerrainChunkMesher.CHUNK_SIZE
					)
					leaf.append(profile.tree_tint)
			# What the rule asks for, written out here rather than taken from the
			# layer: the biome's own grass coverage, cut down by the clearing
			# mask, pushed through the curve -- averaged over the same lattice
			# the layer walks. It has to be an average now rather than one
			# number, because the whole point of the mask is that the share
			# varies inside a chunk.
			var wanted := 0.0
			for cell in GrassLayer.LATTICE * GrassLayer.LATTICE:
				var at_x := origin_x + (float(cell % GrassLayer.LATTICE) + 0.5) \
					* GrassLayer.CELL
				var at_z := origin_z + (float(cell / GrassLayer.LATTICE) + 0.5) \
					* GrassLayer.CELL
				wanted += GrassLayer.grown_share(
					GrassLayer.clearing_at(at_x, at_z, world.world_seed),
					GrassLayer.coverage_for(
						world.terrain.biome_field.weights_at(at_x, at_z)
					)
				) / float(GrassLayer.LATTICE * GrassLayer.LATTICE)
			for row in GrassLayer.FIELD_SIDE:
				for column in GrassLayer.FIELD_SIDE:
					var step := TerrainChunkMesher.CHUNK_SIZE \
						/ float(GrassLayer.FIELD_SIDE - 1)
					if world.terrain.path_strength_at(
						origin_x + float(column) * step, origin_z + float(row) * step
					) > 0.0:
						on_a_road = true
			if on_a_road:
				continue

			var view := layer.build(_flat_chunk(chunk_x, chunk_z, ground))
			# A chunk that grew nothing is no longer a fault: with the floor gone
			# and the mask in, a chunk lying inside a clearing is *supposed* to
			# be bare, and the rule below is what says whether this one is.
			if view == null:
				check(wanted < 0.02,
					"chunk (%d, %d) grew nothing where the rule asks for %.3f"
					% [chunk_x, chunk_z, wanted])
				bare_chunks += 1
				tested += 1
				continue
			var grown := float(view.multimesh.instance_count) \
				/ float(GrassLayer.LATTICE * GrassLayer.LATTICE)
			worst_density = maxf(worst_density, absf(grown - wanted))
			if grown >= 0.995:
				closed_chunks += 1
			tested += 1
			seen[world.terrain.biome_at(origin_x + 8.0, origin_z + 8.0)] = true

			# The colour of a handful of blades, against the rule recomputed
			# here -- including the interpolation across the chunk, so a chunk
			# lying over a biome border is checked at the blade rather than at
			# the chunk.
			var buffer: PackedFloat32Array = view.multimesh.buffer
			for at in mini(8, view.multimesh.instance_count):
				var here := Vector2(
					buffer[at * STRIDE + AT_X] - origin_x,
					buffer[at * STRIDE + AT_Z] - origin_z
				) / TerrainChunkMesher.CHUNK_SIZE
				var expected := _expected_tint(ground, leaf[0].lerp(leaf[1], here.x).lerp(
					leaf[2].lerp(leaf[3], here.x), here.y
				), reference)
				var apart := maxf(
					absf(buffer[at * STRIDE + AT_COLOR] - expected.r),
					maxf(
						absf(buffer[at * STRIDE + AT_COLOR + 1] - expected.g),
						absf(buffer[at * STRIDE + AT_COLOR + 2] - expected.b)
					)
				)
				check(apart < 0.002,
					"a tuft at chunk (%d, %d) is not the colour the biome profile "
					% [chunk_x, chunk_z] + "asks for (off by %.4f)" % apart)
			view.free()

	check(tested >= 40, "only %d chunks were testable" % tested)
	check(seen.size() >= 3,
		"the sweep only met %d biomes, so it cannot show that the density follows "
		% seen.size() + "the biome at all")
	# Four standard deviations of binomial noise on a lattice this size is about
	# 0.07, the layer interpolates the mask on a grid rather than sampling it per
	# cell as this does, and the biome coverage is a bilinear interpolation of
	# four corners, so the tolerance is generous.
	check(worst_density < 0.11,
		"the share of the lattice that grew was %.3f away from what the biome "
		% worst_density + "coverage, the clearing mask and the curve ask for")
	# And the point of the whole exercise: the sweep must have met ground that is
	# entirely bare and ground that is entirely covered. Under the old rule --
	# one number per chunk, floored at 0.28 -- neither could exist anywhere.
	check(bare_chunks > 0,
		"not one chunk of the sweep was bare, so the mask is not clearing "
		+ "anything and the density floor has effectively survived")
	check(closed_chunks > 0,
		"not one chunk of the sweep grew a closed carpet, so the curve is not "
		+ "closing anything")


## The colour a blade is tinted against is the mean of the art's own colours.
##
## The whole tint is a multiply: every vertex of the tuft is multiplied by (the
## colour wanted / the colour the art already reads as), so that the art's own
## light and shade survive being recoloured. That lands on the colour wanted only
## if the second of those really is the mean of the vertices being multiplied,
## and for most of this layer's life it was not: `instanced_mesh` handed back the
## row's declared tint role, (0.30, 0.55, 0.30), while the blades themselves
## average (0.42, 0.69, 0.23). Dividing by a colour a third bluer than the art
## multiplied every blade's blue by 0.6 whatever any biome asked for, which is
## how the grass came out a sharper yellow-green than the ground it stands on --
## the complaint in reports/grass.md §10.
##
## It is checked here rather than left to the eye because nothing about it is
## visible as a fault: a picture drawn with the wrong reference is not broken,
## just quietly the wrong colour, and the number it should be is not written down
## anywhere except in the art.
func _the_tint_divides_by_the_colour_the_art_actually_is() -> void:
	AssetLibrary.restore_defaults()
	var baked := AssetLibrary.instanced_mesh(AssetTags.GRASS)
	var mesh: Mesh = baked["mesh"]
	check(mesh != null, "the grass tag bakes to no mesh to take a mean of")
	if mesh == null:
		return
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(colors.size() > 0, "the baked tuft carries no vertex colours")
	if colors.is_empty():
		return
	# The vertices are stored in linear light, and so is the multiply, so the
	# mean is taken there and carried back to sRGB the way a caller reads it.
	var mean := Color(0.0, 0.0, 0.0)
	for colour in colors:
		mean += colour
	mean = mean / float(colors.size())
	var reference: Color = baked["reference"]
	var base := reference.srgb_to_linear()
	# A hundredth of a channel: the mesh stores its colours eight bits deep, so
	# the mean read back off it is a rounding away from the mean that was baked.
	var apart := maxf(
		absf(base.r - mean.r), maxf(absf(base.g - mean.g), absf(base.b - mean.b))
	)
	check(apart < 0.01,
		"the tint reference is not the colour the art is: reference "
		+ "(%.3f, %.3f, %.3f) against a mean of (%.3f, %.3f, %.3f), off by %.3f"
		% [base.r, base.g, base.b, mean.r, mean.g, mean.b, apart])

	# And the consequence, which is the thing that actually has to hold: a blade
	# asked for a colour comes out that colour on average. Checked on the two
	# biomes furthest apart in the catalog, at the shipped mix.
	for id in [BiomeCatalog.MEADOW, BiomeCatalog.TWILIGHT_MARSH]:
		var profile := BiomeCatalog.profile(id)
		var wanted := (profile.ground_tint as Color).lerp(
			profile.tree_tint, GrassLayer.LEAF_MIX
		).srgb_to_linear()
		var painted := Color(0.0, 0.0, 0.0)
		for channel in 3:
			var want: float = [wanted.r, wanted.g, wanted.b][channel]
			var art: float = [mean.r, mean.g, mean.b][channel]
			var reference_channel: float = [base.r, base.g, base.b][channel]
			# The same arithmetic the layer does: a share of MAX_GAIN in the
			# buffer, multiplied back out by the shader.
			var share := clampf(
				want / maxf(reference_channel, 0.0005), 0.0, GrassLayer.MAX_GAIN
			) / GrassLayer.MAX_GAIN
			painted[channel] = art * share * GrassLayer.MAX_GAIN
		var off := maxf(
			absf(painted.r - wanted.r),
			maxf(absf(painted.g - wanted.g), absf(painted.b - wanted.b))
		)
		check(off < 0.01,
			"%s grass averages (%.3f, %.3f, %.3f) where the rule asks for "
			% [id, painted.r, painted.g, painted.b]
			+ "(%.3f, %.3f, %.3f), off by %.3f -- the gain is clipping or the "
			% [wanted.r, wanted.g, wanted.b, off]
			+ "reference is not the art's own colour")


## The clearing mask is a pure function of world position and the world seed.
##
## Checked across a process boundary, because inside one process a mask that
## secretly depended on a clock, a counter or the order chunks arrived in would
## agree with itself perfectly. A second process shares none of that, so if the
## two agree at a list of awkward positions the only thing they can be agreeing
## through is the arithmetic.
##
## The check comes with its own control, and the control is the part that makes
## it worth having. The same probe also prints the same mask function fed the
## process's own id where the seed goes -- something that is neither position nor
## seed -- and this requires those numbers to *disagree*. Without that, a probe
## that printed a constant, or a comparison that compared nothing, would pass.
func _the_clearing_mask_is_a_pure_function_of_world_position_and_the_seed() -> void:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/grass_mask_probe.gd",
		"--", "--seed", str(SEED),
	], output, true)
	var text := "\n".join(output)
	equal(exit_code, 0, "the mask probe should exit 0 (output: %s)" % text)

	var elsewhere := _mask_lines(text)
	check(elsewhere.size() >= 8,
		"the mask probe printed %d positions, not enough to compare: %s"
		% [elsewhere.size(), text])
	if elsewhere.size() < 8:
		return

	var disagreed := 0
	var controls_disagreed := 0
	for line in elsewhere:
		var here := GrassLayer.clearing_at(line["x"], line["z"], SEED)
		if var_to_str(here) != line["pure"]:
			disagreed += 1
		if line["pure"] != line["impure"]:
			controls_disagreed += 1
		check(here >= 0.0 and here <= 1.0,
			"the mask at (%.3f, %.3f) is %.4f, outside [0, 1]"
			% [line["x"], line["z"], here])
	equal(disagreed, 0,
		"%d of %d positions gave a different mask in a second process: the mask "
		% [disagreed, elsewhere.size()]
		+ "depends on something that is not the position and the seed")
	check(controls_disagreed > 0,
		"the control passed too: feeding the mask something that is not the seed "
		+ "changed none of %d values, so the comparison above is comparing "
		% elsewhere.size() + "something that cannot vary and proves nothing")


## The mask varies at a wandering scale, not at the scale of a lattice cell.
##
## This is the difference between patches and confetti, and it is a statement
## about *scale* rather than about values, so it is checked as one. Two things
## have to hold at once. Neighbouring cells of the grass lattice, half a metre
## apart, must read almost the same mask -- if they did not, the mask would be a
## second coin flip and nothing would ever be a patch. And the mask must have
## actually changed by the time it has travelled tens of metres, or it would be a
## constant and nothing would ever be a clearing.
##
## The scales the mask is built from are stated on the layer in world units,
## which are metres: a clearing field at CLEARING_SCALE with a smaller octave at
## CLEARING_DETAIL, and a boundary lattice at BOUNDARY_SCALE bent by a field at
## BOUNDARY_WANDER_SCALE. This requires the behaviour those numbers are there to
## produce, so a change to them that broke the look would be caught here.
func _the_mask_wanders_rather_than_flickering_from_cell_to_cell() -> void:
	check(GrassLayer.CLEARING_SCALE > TerrainChunkMesher.CHUNK_SIZE * 2.0,
		"the clearing field's scale of %.0f units is not broad against a %.0f-unit "
		% [GrassLayer.CLEARING_SCALE, TerrainChunkMesher.CHUNK_SIZE]
		+ "chunk, so a clearing would not span one")
	check(GrassLayer.BOUNDARY_PATH > GrassLayer.CELL * 4.0,
		"a bare path %.1f units wide is only %.1f lattice cells across, which is "
		% [GrassLayer.BOUNDARY_PATH, GrassLayer.BOUNDARY_PATH / GrassLayer.CELL]
		+ "not a path, it is a gap between tufts")

	# How far the mask moves over one lattice cell, against how far it moves over
	# sixty metres. Confetti would move as far over one as over the other.
	var samples := 8000
	var over_a_cell := 0.0
	var over_sixty := 0.0
	for at in samples:
		var x := -900.0 + float(at) * 0.9
		var z := 173.5 + float(at) * 0.37
		var here := GrassLayer.clearing_at(x, z, SEED)
		over_a_cell += absf(
			GrassLayer.clearing_at(x + GrassLayer.CELL, z, SEED) - here
		) / float(samples)
		over_sixty += absf(
			GrassLayer.clearing_at(x + 60.0, z, SEED) - here
		) / float(samples)
	check(over_a_cell < 0.05,
		"the mask moves %.4f on average between neighbouring lattice cells half a "
		% over_a_cell + "metre apart, which is close to a second coin flip")
	check(over_sixty > over_a_cell * 8.0,
		"the mask moves %.4f over sixty metres against %.4f over half a one: it "
		% [over_sixty, over_a_cell] + "has no scale of its own")
	check(over_sixty > 0.15,
		"two samples sixty metres apart differ by only %.4f on average: the mask "
		% over_sixty + "is close enough to a constant that nothing is ever a clearing")

	# And the shape of the thing, which is what "in patches" actually means: walk
	# the lattice for a couple of kilometres and measure how long the runs of
	# entirely bare ground and of entirely closed carpet are. Under the old rule
	# -- one number per chunk, floored -- every run of either would have been zero
	# cells long, because neither state existed anywhere in the world.
	var terrain := TerrainQuery.for_seed(SEED)
	var bare_runs: Array[int] = []
	var closed_runs: Array[int] = []
	var run := 0
	var state := 2
	for at in 30000:
		var x := -1200.0 + float(at) * GrassLayer.CELL
		var z := -318.25 + float(at) * GrassLayer.CELL * 0.21
		var grown := GrassLayer.grown_share(
			GrassLayer.clearing_at(x, z, SEED),
			GrassLayer.coverage_for(terrain.biome_field.weights_at(x, z))
		)
		var now := 2
		if grown <= 0.0:
			now = 0
		elif grown >= 1.0:
			now = 1
		if now == state:
			run += 1
			continue
		if run > 0 and state == 0:
			bare_runs.append(run)
		if run > 0 and state == 1:
			closed_runs.append(run)
		state = now
		run = 1
	check(bare_runs.size() > 40 and closed_runs.size() > 40,
		"the walk met %d runs of bare ground and %d of closed carpet, too few to "
		% [bare_runs.size(), closed_runs.size()] + "say anything about their size")
	if bare_runs.size() < 40 or closed_runs.size() < 40:
		return
	bare_runs.sort()
	closed_runs.sort()
	var bare_median := bare_runs[bare_runs.size() / 2]
	var closed_median := closed_runs[closed_runs.size() / 2]
	check(bare_median >= 4,
		"the median run of bare ground is %d lattice cells (%.1f units): the bare "
		% [bare_median, float(bare_median) * GrassLayer.CELL]
		+ "ground is holes between tufts rather than clearings")
	check(closed_median >= 12,
		"the median run of closed carpet is %d lattice cells (%.1f units): there "
		% [closed_median, float(closed_median) * GrassLayer.CELL]
		+ "are no beds, only speckle")
	check(bare_runs[-1] >= 40,
		"the longest bare run in two kilometres is %d lattice cells (%.1f units), "
		% [bare_runs[-1], float(bare_runs[-1]) * GrassLayer.CELL]
		+ "so there is no such thing as a clearing")


## The curve sends weak ground to exactly bare and moderate ground to exactly a
## closed carpet.
##
## The word that matters is *exactly*. A soft thinning is what the layer already
## did; what makes a patch is that there is ground where the answer is nothing at
## all and ground where the answer is every cell on the lattice, with the ramp
## between them narrow enough to read as an edge.
func _the_curve_sends_weak_ground_bare_and_moderate_ground_closed() -> void:
	equal(GrassLayer.grown_share(1.0, GrassLayer.CURVE_LOW), 0.0,
		"ground at the bottom of the curve is not exactly bare")
	equal(GrassLayer.grown_share(1.0, GrassLayer.CURVE_LOW * 0.5), 0.0,
		"ground below the bottom of the curve is not exactly bare")
	equal(GrassLayer.grown_share(1.0, GrassLayer.CURVE_HIGH), 1.0,
		"ground at the top of the curve is not exactly closed")
	equal(GrassLayer.grown_share(0.0, 1.0), 0.0,
		"a mask of zero still grows grass")
	check(GrassLayer.CURVE_HIGH - GrassLayer.CURVE_LOW < 0.30,
		"the curve ramps over %.2f, which is wide enough that the whole field is "
		% (GrassLayer.CURVE_HIGH - GrassLayer.CURVE_LOW) + "edge and nothing is a bed")
	# The floor is gone. It is named here rather than merely deleted, because a
	# floor is exactly the thing that would silently undo all of the above.
	var source := FileAccess.get_file_as_string("res://render/grass_layer.gd")
	check(not source.is_empty(), "the grass layer's source could not be read")
	check(not source.contains("DENSITY_FLOOR"),
		"the layer still has a density floor, which keeps every cell of every "
		+ "biome at least partly grassy and makes bare ground impossible")

	# And on real ground: a long walk through the world has to meet both.
	var terrain := TerrainQuery.for_seed(SEED)
	var bare := 0
	var closed := 0
	var between := 0
	var samples := 6000
	for at in samples:
		var x := -1500.0 + float(at) * 0.7
		var z := 640.0 - float(at) * 0.43
		var grown := GrassLayer.grown_share(
			GrassLayer.clearing_at(x, z, SEED),
			GrassLayer.coverage_for(terrain.biome_field.weights_at(x, z))
		)
		if grown <= 0.0:
			bare += 1
		elif grown >= 1.0:
			closed += 1
		else:
			between += 1
	check(bare > samples / 20,
		"only %d of %d samples along a kilometre of world were bare ground"
		% [bare, samples])
	check(closed > samples / 20,
		"only %d of %d samples along a kilometre of world were a closed carpet"
		% [closed, samples])
	check(between < bare + closed,
		"%d of %d samples are on the ramp, against %d bare and %d closed: the "
		% [between, samples, bare, closed] + "world is mostly edge")


## Grass grows thicker in the open than under a closed canopy -- which is the
## opposite of what it used to do.
##
## The layer used to take the biome profile's `foliage_density` as its coverage.
## That field is how thickly a biome puts *things* on the ground, and the deep
## forest's 0.95 against the meadow's 0.45 is exactly right for trees and exactly
## backwards for grass: it made the design's flagship lush meadow the thinnest
## ground in the world and the shaded forest floor the thickest. So this asserts
## the inversion in both directions -- that the grass layer's own table orders
## the two biomes one way and the simulation's foliage density orders them the
## other -- and then measures it on real chunks rather than trusting the table.
func _grass_is_thicker_in_the_open_than_under_a_closed_canopy() -> void:
	var meadow := BiomeCatalog.profile(BiomeCatalog.MEADOW)
	var forest := BiomeCatalog.profile(BiomeCatalog.DEEP_FOREST)
	check(forest.foliage_density > meadow.foliage_density,
		"the deep forest no longer scatters more than the meadow (%.2f against "
		% forest.foliage_density + "%.2f), so there is no inversion to check"
		% meadow.foliage_density)
	check(
		float(GrassLayer.GRASS_COVERAGE[BiomeCatalog.MEADOW])
			> float(GrassLayer.GRASS_COVERAGE[BiomeCatalog.DEEP_FOREST]),
		"the grass layer still grows more in the deep forest (%.2f) than in the "
		% float(GrassLayer.GRASS_COVERAGE[BiomeCatalog.DEEP_FOREST])
		+ "meadow (%.2f)" % float(GrassLayer.GRASS_COVERAGE[BiomeCatalog.MEADOW]))
	# Every biome the catalog names has a number here, or a blend would quietly
	# treat the missing one as bare ground.
	for id in BiomeCatalog.IDS:
		check(GrassLayer.GRASS_COVERAGE.has(id),
			"the grass layer has no coverage for the biome '%s'" % id)
	# The two biomes whose own profile advertises grass among its props are the
	# two the table is generous to. That is where the ordering comes from, so it
	# is checked rather than left to drift.
	for id in BiomeCatalog.IDS:
		var advertises: bool = BiomeCatalog.profile(id).prop_tags.has(AssetTags.GRASS)
		var covered := float(GrassLayer.GRASS_COVERAGE[id])
		if advertises:
			check(covered > GrassLayer.CURVE_HIGH,
				"'%s' lists grass among its props but the grass layer gives it "
				% id + "%.2f, which the curve can never close" % covered)
		else:
			check(covered < GrassLayer.CURVE_HIGH,
				"'%s' does not list grass among its props but the grass layer "
				% id + "gives it %.2f, enough to close the ground" % covered)

	# And measured: the average share of the lattice that grows, over every
	# sampled position that resolves to each biome.
	var terrain := TerrainQuery.for_seed(SEED)
	var totals := {}
	var counts := {}
	for id in BiomeCatalog.IDS:
		totals[id] = 0.0
		counts[id] = 0
	for gx in range(-46, 47, 3):
		for gz in range(-46, 47, 3):
			var x := float(gx) * 16.0
			var z := float(gz) * 16.0
			var id := terrain.biome_at(x, z)
			totals[id] = float(totals[id]) + GrassLayer.grown_share(
				GrassLayer.clearing_at(x, z, SEED),
				GrassLayer.coverage_for(terrain.biome_field.weights_at(x, z))
			)
			counts[id] = int(counts[id]) + 1
	var in_meadow := float(totals[BiomeCatalog.MEADOW]) \
		/ maxf(1.0, float(counts[BiomeCatalog.MEADOW]))
	var in_forest := float(totals[BiomeCatalog.DEEP_FOREST]) \
		/ maxf(1.0, float(counts[BiomeCatalog.DEEP_FOREST]))
	check(counts[BiomeCatalog.MEADOW] > 40 and counts[BiomeCatalog.DEEP_FOREST] > 40,
		"the sweep met %d meadow and %d deep-forest positions, too few to compare"
		% [counts[BiomeCatalog.MEADOW], counts[BiomeCatalog.DEEP_FOREST]])
	check(in_meadow > in_forest * 1.25,
		"measured over the world, a meadow grows %.3f of its lattice against the "
		% in_meadow + "deep forest's %.3f: the inversion has not landed" % in_forest)


## A biome border stays organic in the grass.
##
## The coverage a biome gives grass is a number per biome, and a number per biome
## is exactly the shape of thing that turns a border into a straight edge if it
## is switched on rather than blended. So it is blended, on the same continuous
## weights the profile blends its colours with, and this walks a transect across
## a real border and requires the coverage to arrive gradually.
func _grass_coverage_blends_across_a_biome_border() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var lowest := INF
	var highest := -INF
	for id in BiomeCatalog.IDS:
		lowest = minf(lowest, float(GrassLayer.GRASS_COVERAGE[id]))
		highest = maxf(highest, float(GrassLayer.GRASS_COVERAGE[id]))
	var span := highest - lowest

	# The rule, stated as an inequality the blend has to satisfy. A weighted
	# average of fixed numbers cannot move faster than the weights themselves do:
	# over one step, the coverage can change by at most the spread of the table
	# times how much of the weight moved. So if this holds everywhere, the
	# coverage is no sharper than the biome field it is read from -- which is the
	# whole of "a border must not become a straight edge in the grass".
	var crossings := 0
	var worst_excess := 0.0
	var switched_excess := 0.0
	var steps := 0
	for line in 24:
		var z := -900.0 + float(line) * 75.0
		var last_weights := {}
		var last := -1.0
		var last_switched := -1.0
		var last_id := ""
		for at in 1200:
			var x := -900.0 + float(at) * 1.5
			var weights := terrain.biome_field.weights_at(x, z)
			var here := GrassLayer.coverage_for(weights)
			var id := terrain.biome_at(x, z)
			# The same table read by switching on the strongest biome instead of
			# blending: the mistake this test exists to catch.
			var switched := float(GrassLayer.GRASS_COVERAGE[id])
			if last >= 0.0:
				var moved := 0.0
				for biome in BiomeCatalog.IDS:
					moved += absf(
						float(weights.get(biome, 0.0))
						- float(last_weights.get(biome, 0.0))
					)
				var allowed := span * moved * 0.5 + 0.000001
				worst_excess = maxf(worst_excess, absf(here - last) - allowed)
				switched_excess = maxf(
					switched_excess, absf(switched - last_switched) - allowed
				)
				steps += 1
				if id != last_id:
					crossings += 1
			last = here
			last_switched = switched
			last_weights = weights
			last_id = id
	check(crossings > 20,
		"the transects crossed only %d biome borders, so they show nothing"
		% crossings)
	check(steps > 20000, "only %d steps were walked" % steps)
	check(worst_excess <= 0.0,
		"grass coverage moved %.5f further in one step than the biome weights "
		% worst_excess + "under it did, so it is not a blend of them")
	# The control: the same table, switched on the strongest biome rather than
	# blended, breaks that bound badly. Without this the check above would pass
	# for a coverage that never varied at all.
	check(switched_excess > span * 0.4,
		"switching the coverage on the strongest biome instead of blending it "
		+ "overshot by only %.4f, so the bound above is not tight enough to tell "
		% switched_excess + "a blend from a step")


## Changing the detail changes how many tufts are drawn and nothing else.
##
## This is the level-of-detail decision, checked rather than described: no chunk
## is ever rebuilt to thin it out, so the instance count and the buffer must be
## untouched by the change, and the tufts that remain must still be spread over
## the whole chunk rather than heaped in one corner of it.
func _the_level_of_detail_hides_tufts_and_rebuilds_nothing() -> void:
	equal(GrassLayer.visible_share(0.0), 1.0, "grass underfoot should be all drawn")
	equal(GrassLayer.visible_share(GrassLayer.FULL_RADIUS), 1.0,
		"grass inside the full-detail radius should be all drawn")
	var last := 1.0
	var distance := GrassLayer.FULL_RADIUS
	while distance <= GrassLayer.BUILD_RADIUS:
		var share := GrassLayer.visible_share(distance)
		check(share <= last + 0.0001,
			"the visible share rose with distance at %.1f units" % distance)
		check(share >= GrassLayer.THIN_SHARE - 0.0001,
			"the visible share fell below the floor at %.1f units" % distance)
		last = share
		distance += 1.0

	var world := SimWorld.new(SEED)
	var layer := GrassLayer.new(world.terrain, world.world_seed)
	var view: MultiMeshInstance3D = null
	for key in world.terrain_streamer.loaded_keys():
		view = layer.build(world.terrain_streamer.geometry(key))
		if view != null and view.multimesh.instance_count > 200:
			break
		if view != null:
			view.free()
			view = null
	check(view != null, "no chunk near the observer grew enough grass to test on")
	if view == null:
		return

	var before: PackedFloat32Array = view.multimesh.buffer.duplicate()
	var full := view.multimesh.instance_count
	layer.set_detail(view, GrassLayer.BUILD_RADIUS)
	var counts := GrassLayer.counts_of(view)
	equal(counts.x, full, "thinning a chunk changed how many tufts it holds")
	check(counts.y < full, "thinning a chunk at the far edge drew just as many")
	check(counts.y >= int(float(full) * GrassLayer.THIN_SHARE) - 1,
		"thinning a chunk drew fewer than the floor allows")
	equal(view.multimesh.buffer, before,
		"thinning a chunk rewrote its instance buffer: the detail is costing a "
		+ "rebuild, which is the one thing it was arranged to avoid")

	# The tufts still drawn cover the same ground the whole chunk's did. Measured
	# against the chunk's own grass rather than against the chunk rectangle,
	# because a chunk's grass no longer fills its chunk: with the clearing mask
	# in, a bed of grass in the corner of an otherwise bare chunk is the layer
	# working, and a check that demanded the drawn tufts span the whole square
	# would be failing the patches rather than the thinning. What thinning must
	# not do is move the grass -- so the drawn subset's extent and its middle are
	# compared against the full set's.
	var whole := _spread_of(view, full)
	var thinned := _spread_of(view, counts.y)
	check(thinned["span"].x > whole["span"].x * 0.8
		and thinned["span"].y > whole["span"].y * 0.8,
		"the tufts left after thinning span %.1f by %.1f where the whole chunk's "
		% [thinned["span"].x, thinned["span"].y]
		+ "span %.1f by %.1f" % [whole["span"].x, whole["span"].y])
	var drift: Vector2 = thinned["middle"] - whole["middle"]
	check(absf(drift.x) < TerrainChunkMesher.CHUNK_SIZE * 0.08
		and absf(drift.y) < TerrainChunkMesher.CHUNK_SIZE * 0.08,
		"thinning moved the middle of the chunk's grass by (%.2f, %.2f), so it is "
		% [drift.x, drift.y] + "clearing one side rather than thinning evenly")
	view.free()


## Grass on a chunk depends on the chunk and the seed and on nothing else.
##
## The same claim the ground itself makes, and it has to hold here too or a chunk
## dropped and walked back to would come back different -- which is exactly what
## streaming does all day.
func _a_chunk_of_grass_is_a_pure_function_of_its_chunk_and_the_seed() -> void:
	var world := SimWorld.new(SEED)
	var keys := world.terrain_streamer.loaded_keys()
	check(keys.size() > 4, "a fresh world should have ground loaded")
	if keys.size() < 5:
		return

	var first := GrassLayer.new(world.terrain, world.world_seed)
	var forwards := {}
	for key in keys:
		var view := first.build(world.terrain_streamer.geometry(key))
		forwards[key] = PackedFloat32Array() if view == null else view.multimesh.buffer
		if view != null:
			view.free()

	# A second layer that has never seen any of it, walking the chunks the other
	# way round, so neither the order nor anything kept between chunks can be
	# what made them agree.
	var second := GrassLayer.new(world.terrain, world.world_seed)
	var backwards := keys.duplicate()
	backwards.reverse()
	var differed := 0
	for key in backwards:
		var view := second.build(world.terrain_streamer.geometry(key))
		var again := PackedFloat32Array() if view == null else view.multimesh.buffer
		if again != forwards[key]:
			differed += 1
		if view != null:
			view.free()
	equal(differed, 0,
		"%d chunks grew different grass the second time round" % differed)

	# A different seed grows different grass, so the check above is not passing
	# because the layer ignores the seed.
	var elsewhere := SimWorld.new(SEED + 1)
	var other := GrassLayer.new(elsewhere.terrain, elsewhere.world_seed)
	var same := 0
	var compared := 0
	for key in keys:
		if not elsewhere.terrain_streamer.is_loaded(key):
			continue
		var view := other.build(elsewhere.terrain_streamer.geometry(key))
		var buffer := PackedFloat32Array() if view == null else view.multimesh.buffer
		compared += 1
		if buffer == forwards[key]:
			same += 1
		if view != null:
			view.free()
	check(compared > 0, "the two seeds shared no loaded chunk to compare")
	equal(same, 0, "%d chunks grew identical grass under two different seeds" % same)


## An island's grass stands on the island's own top surface and nowhere else.
##
## The same claim the ground gets, against the same kind of independent search:
## the height under every patch is found by walking the island's triangles from
## scratch rather than by asking the layer what it thought it did. What differs
## is what "nowhere else" means on a plate -- inside the outline, off the cliff
## and the keel, and out of the pond.
func _an_islands_grass_stands_on_the_islands_own_top() -> void:
	var world := SimWorld.new(SEED)
	var mesher := IslandMesher.new()
	var layer := GrassLayer.new(world.terrain, world.world_seed)
	var checked := 0
	var islands := 0
	var worst := 0.0
	var past := 0.0
	var wet := 0
	var steep := 0
	for island in _walkable_islands(world):
		var geometry := mesher.build(island)
		var view := layer.build_island(geometry, island)
		if view == null:
			continue
		islands += 1
		var buffer: PackedFloat32Array = view.multimesh.buffer
		for at in view.multimesh.instance_count:
			var x := buffer[at * STRIDE + AT_X]
			var y := buffer[at * STRIDE + AT_Y]
			var z := buffer[at * STRIDE + AT_Z]
			checked += 1
			past = maxf(past, island.ratio_at(x, z) - 1.0)
			if island.holds_water_at(x, z):
				wet += 1
			var found := _island_top_under(geometry, x, z)
			if found["normal"].y < GrassLayer.ISLAND_SLOPE_COS - 0.001:
				steep += 1
			worst = maxf(worst, absf(float(found["height"]) - y))
		view.free()
	check(islands >= 4,
		"only %d islands grew any grass at all, which is too few to conclude from"
		% islands)
	check(checked > 500,
		"only %d patches were there to check on the islands near the origin" % checked)
	# Not zero, and the reason is the mesher rather than this layer. The fan cuts
	# the island into IslandMesher.AERIAL_SECTORS directions and joins the
	# outline with straight chords between them; the outline is the union of
	# several blobs and so has bays in it, and a chord drawn across a bay stands
	# outside the curve it is cutting. So the drawn surface -- the one a patch is
	# checked to a millimetre against above -- reaches a little past the analytic
	# outline wherever there is a notch. Measured at 0.097 of the outline at the
	# worst; the bound is there to catch a patch standing off the plate
	# altogether rather than to police the mesher's chords.
	check(past < 0.15,
		"a patch stood %.3f of the outline past the island's edge, which is far "
		% past + "more than a chord between two of the mesher's %d directions"
		% IslandMesher.AERIAL_SECTORS)
	equal(wet, 0, "%d patches grew in an island's own pond" % wet)
	equal(steep, 0,
		"%d patches grew on a face steeper than the island layer allows -- on the "
		% steep + "cliff at the rim or on the keel underneath")
	check(worst < 0.001,
		"a patch floated or sank %.4f units off the island triangle it stands on"
		% worst)


## An island's grass belongs to the island, not to where the island hangs.
##
## Move an island through the world without changing anything about it, and its
## grass has to move with it *unchanged* -- the same number of patches, at the
## same places relative to the island's middle, the same colours, the same
## sizes, the same wind phases. That is the property a hash taking world x and z
## cannot have: every cell index and every jitter would be different at the new
## position, so the grass would be re-rolled rather than carried. The move is
## deliberately not a whole number of lattice cells, so a world-position hash
## could not accidentally survive it either.
##
## The control is the other half: change the island's *cell* and leave it exactly
## where it is, and the grass has to change. Without that, a layer that ignored
## all of its inputs would pass the first half.
func _an_islands_grass_belongs_to_the_island_not_to_where_it_hangs() -> void:
	var world := SimWorld.new(SEED)
	var mesher := IslandMesher.new()
	var layer := GrassLayer.new(world.terrain, world.world_seed)
	# A plate with no basin: the pond is the one thing this layer asks the
	# island's own shape functions about, and those read the world's noise at
	# absolute positions, so a basin island genuinely is a different island once
	# it has been moved.
	var island: FloatingIsland = null
	for candidate in _walkable_islands(world):
		if not candidate.has_basin():
			island = candidate
			break
	check(island != null, "found no island without a basin to move")
	if island == null:
		return

	var geometry := mesher.build(island)
	var here := layer.build_island(geometry, island)
	check(here != null, "the island grew no grass, so there is nothing to compare")
	if here == null:
		return

	# 137.0 and 219.0 are not multiples of the lattice's cell size, so a hash
	# reading world position would land on different cells at the new place.
	var shift := Vector2(137.0, 219.0)
	var moved := island.detached_copy()
	moved.centre_x += shift.x
	moved.centre_z += shift.y
	var moved_geometry := _shifted(geometry, shift)
	var there := layer.build_island(moved_geometry, moved)
	check(there != null, "the moved island grew no grass")
	if there == null:
		here.free()
		return

	equal(there.multimesh.instance_count, here.multimesh.instance_count,
		"the same island grew %d patches here and %d after being moved %.0f, %.0f: "
		% [here.multimesh.instance_count, there.multimesh.instance_count, shift.x, shift.y]
		+ "its grass is being decided by where it hangs")
	var drifted := 0.0
	var differed := 0
	if there.multimesh.instance_count == here.multimesh.instance_count:
		var before: PackedFloat32Array = here.multimesh.buffer
		var after: PackedFloat32Array = there.multimesh.buffer
		for at in here.multimesh.instance_count:
			for field in STRIDE:
				var was := before[at * STRIDE + field]
				var now := after[at * STRIDE + field]
				if field == AT_X:
					was += shift.x
				elif field == AT_Z:
					was += shift.y
				if field == AT_X or field == AT_Z:
					drifted = maxf(drifted, absf(now - was))
				elif absf(now - was) > 0.00001:
					differed += 1
	check(drifted < 0.0005,
		"a patch moved %.4f units out of place when the island was carried %.0f, %.0f"
		% [drifted, shift.x, shift.y])
	equal(differed, 0,
		"%d of the moved island's patch fields changed -- its colour, size, turn "
		% differed + "or wind phase is being hashed from world position")

	# The control. Same island, same place, one different cell.
	var relabelled := island.detached_copy()
	relabelled.cell = island.cell + Vector2i(1, 0)
	var other := layer.build_island(geometry, relabelled)
	var same := other != null and other.multimesh.instance_count == here.multimesh.instance_count \
		and other.multimesh.buffer == here.multimesh.buffer
	check(not same,
		"an island given a different cell grew exactly the same grass, so the "
		+ "comparison above is comparing something that cannot vary")
	if other != null:
		other.free()
	here.free()
	there.free()


## Two storeys that lap over each other in plan grow different grass.
##
## This is the failure the island's own lattice exists to prevent, written down.
## The upper storey laps over the lower one's rim by design -- that lap is the
## staircase you walk up -- so a patch of ground can have two plates over it. A
## hash reading world x and z would make one decision for that patch of ground
## and hand it to both plates, so the upper storey's grass would stand directly
## over the lower storey's, tuft for tuft.
##
## The control is the number that says how big that failure would be: how many
## cells of the world's own lattice carry a patch on both plates. A hash taking
## the world cell makes one decision per cell whoever is asking, so every one of
## those would be a coincidence. Measured on the island's own lattice, none are.
func _two_storeys_that_overlap_grow_different_grass() -> void:
	var pairs := 0
	var compared := 0
	var coincidences := 0
	var shared_cells := 0
	for seed_value in OVERLAP_SEEDS:
		var world := SimWorld.new(seed_value)
		var mesher := IslandMesher.new()
		var layer := GrassLayer.new(world.terrain, world.world_seed)
		for cell_x in range(-OVERLAP_CELLS, OVERLAP_CELLS + 1):
			for cell_z in range(-OVERLAP_CELLS, OVERLAP_CELLS + 1):
				var cell := Vector2i(cell_x, cell_z)
				var lower := world.island_field.island_in_cell(FloatingIsland.AERIAL, cell)
				var upper := world.island_field.island_in_cell(
					FloatingIsland.AERIAL_UPPER, cell
				)
				if lower == null or upper == null:
					continue
				var below := _patches_over(layer, mesher, lower, upper)
				var above := _patches_over(layer, mesher, upper, lower)
				if below.is_empty() or above.is_empty():
					continue
				pairs += 1
				compared += above.size()
				var below_cells := {}
				for one in below:
					below_cells[_world_cell(one)] = true
				for one in above:
					if below_cells.has(_world_cell(one)):
						shared_cells += 1
					for other in below:
						# Tight, because under a world-position hash the two
						# plates would place a patch at exactly the same point.
						# A window wide enough for two independent rolls to land
						# in by chance would measure luck rather than the rule:
						# at 0.02 on a 0.57-unit cell, a couple of the few
						# hundred pairs in the laps meet by coincidence.
						if absf(one.x - other.x) < 0.001 and absf(one.y - other.y) < 0.001:
							coincidences += 1
	check(pairs >= 4,
		"found only %d overlapping pairs with grass in the lap on both plates" % pairs)
	check(compared >= 25,
		"only %d patches stand in the laps, which is too few to conclude from"
		% compared)
	check(shared_cells > 0,
		"no cell of the world's lattice carries a patch on both plates, so the "
		+ "coincidence count below could not have been anything but zero and "
		+ "proves nothing")
	equal(coincidences, 0,
		("%d of %d patches on an upper storey stand exactly where a patch stands"
		+ " on the plate below -- island grass is being hashed from world"
		+ " position") % [coincidences, compared])
	print("        island grass: %d overlapping storey pairs, %d patches in the laps, "
		% [pairs, compared]
		+ "%d sharing a world cell, %d coincidences" % [shared_cells, coincidences])


## The same island grows the same grass in a process that shares nothing with
## this one.
##
## Asked of a second process rather than of a second layer in this one, for the
## reason tests/island_grass_probe.gd sets out: a layer that depended on a clock,
## a counter or the order islands streamed in would agree with itself perfectly
## well inside a single run.
func _two_processes_grow_the_same_grass_on_an_island() -> void:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/island_grass_probe.gd",
		"--", "--seed", str(SEED),
	], output, true)
	var text := "\n".join(output)
	equal(exit_code, 0, "the island grass probe should exit 0 (output: %s)" % text)

	var world := SimWorld.new(SEED)
	var mesher := IslandMesher.new()
	var layer := GrassLayer.new(world.terrain, world.world_seed)
	var compared := 0
	var disagreed := 0
	var controls_disagreed := 0
	var grew := 0
	for line in text.split("\n"):
		var fields := line.strip_edges().split(" ")
		if fields.size() != 6 or fields[0] != "islandgrass":
			continue
		var island := world.island_field.island_in_cell(
			fields[1].to_int(), Vector2i(fields[2].to_int(), fields[3].to_int())
		)
		if island == null:
			continue
		var view := layer.build_island(mesher.build(island), island)
		var here := "0/none"
		if view != null:
			here = _island_digest(view)
			if view.multimesh.instance_count > 0:
				grew += 1
			view.free()
		compared += 1
		if here != fields[4]:
			disagreed += 1
		if fields[4] != fields[5]:
			controls_disagreed += 1
	check(compared >= 6,
		"the probe reported only %d islands, not enough to compare" % compared)
	check(grew >= 4, "only %d of the probe's islands grew any grass" % grew)
	equal(disagreed, 0,
		"%d of %d islands grew different grass in a second process: the layer "
		% [disagreed, compared]
		+ "depends on something that is not the island and the seed")
	check(controls_disagreed > 0,
		"the control passed too: a layer built on something that is not the seed "
		+ "grew identical grass on all %d islands, so the comparison above is "
		% compared + "comparing something that cannot vary and proves nothing")


## A headless process creates no grass, because it never loads the file that
## makes any.
##
## Asked from outside the render layer, of the engine's own resource cache: a
## counter kept inside the grass layer could only be read by loading the grass
## layer, which is the very thing that must not happen.
func _headless_creates_no_grass_at_all() -> void:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(SEED), "--ticks", "40", "--assets",
	], output, true)
	var text := "\n".join(output)
	equal(exit_code, 0, "headless run should exit 0 (output: %s)" % text)

	var render_scripts := _asset_line(text, "render-scripts")
	check(not render_scripts.is_empty(),
		"the headless run reported no render-scripts line: %s" % text)
	if render_scripts.is_empty():
		return
	equal(render_scripts["loaded"], 0,
		"a headless run loaded %d file(s) of the render layer, which is where the "
		% render_scripts["loaded"] + "grass lives")
	# The count has to include the grass layer, or "none of them was loaded" is
	# an answer about a set the grass is not in.
	check(FileAccess.file_exists("res://render/grass_layer.gd"),
		"render/grass_layer.gd is missing, so the check above covers nothing")
	check(render_scripts["found"] >= 5,
		"only %d render scripts were counted; the grass layer is not among them"
		% render_scripts["found"])


## The world the shell reaches is byte-identical with the grass and without it.
##
## Three runs rather than two: the shell with grass, the shell with --no-grass,
## and a simulation with no renderer at all. All three must arrive at the same
## fingerprint at the same tick. The two shell runs also have to differ in the
## one way they are supposed to -- one grows thousands of tufts and the other
## grows none -- or "the fingerprints matched" would be a statement about two
## runs that did the same thing.
func _the_world_is_byte_identical_with_and_without_the_grass() -> void:
	var green := _run_render_shell([])
	var bare := _run_render_shell(["--no-grass"])
	equal(green["exit_code"], 0, "render shell should exit 0 (output: %s)" % green["output"])
	equal(bare["exit_code"], 0, "render shell should exit 0 (output: %s)" % bare["output"])

	var green_counts := _counts_from(green["output"])
	var bare_counts := _counts_from(bare["output"])
	check(not green_counts.is_empty(), "no counters from the shell: %s" % green["output"])
	check(not bare_counts.is_empty(), "no counters from the shell: %s" % bare["output"])
	if green_counts.is_empty() or bare_counts.is_empty():
		return

	check(green_counts["grass"] > 1000,
		"the run with grass only grew %d tufts, so comparing it against a run "
		% green_counts["grass"] + "without grass shows nothing")
	equal(bare_counts["grass"], 0,
		"--no-grass still grew %d tufts" % bare_counts["grass"])
	equal(bare_counts["patches"], 0,
		"--no-grass still built grass for %d chunks" % bare_counts["patches"])
	equal(green_counts["tick"], EXPECTED_TICKS,
		"the shell should have run %d ticks" % EXPECTED_TICKS)

	var headless := Simulation.new(SEED)
	headless.run(EXPECTED_TICKS)
	equal(_digest_from(green["output"]), headless.world.digest(),
		"the shell with grass reached a different world from a headless run of "
		+ "seed %d at tick %d" % [SEED, EXPECTED_TICKS])
	equal(_digest_from(bare["output"]), _digest_from(green["output"]),
		"the same seed reached different worlds with and without the grass layer: "
		+ "growing grass is changing the world")


# --- helpers -------------------------------------------------------------


## A flat chunk of ground at DRY_HEIGHT, one colour, facing straight up, laid out
## exactly the way TerrainChunkMesher lays a chunk out.
## The walkable islands within SCAN_CELLS of the origin, in a fixed order.
func _walkable_islands(world: SimWorld) -> Array[FloatingIsland]:
	var found: Array[FloatingIsland] = []
	for band in FloatingIsland.WALKABLE_BANDS:
		for cell_x in range(-SCAN_CELLS, SCAN_CELLS + 1):
			for cell_z in range(-SCAN_CELLS, SCAN_CELLS + 1):
				var island := world.island_field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island != null and island.walkable:
					found.append(island)
	return found


## The island's *top* at a position, found by walking the geometry rather than by
## asking the island's own shape functions: the height of the highest up-facing
## triangle covering it, and the flattest facing any of them has.
##
## Only the up-facing triangles are considered, and the highest is the one that
## answers for the height: a plate's keel covers every plan position its top
## does, so a search that took the first triangle it landed in could answer for
## the underside. The facing is the flattest rather than the highest one's,
## because a position on the edge two triangles share stands on both, and the
## layer put its patch on whichever of them it walked into.
func _island_top_under(
	geometry: TerrainChunkGeometry, x: float, z: float
) -> Dictionary:
	var found := {"height": INF, "normal": Vector3.UP}
	var highest := -INF
	var flattest := -INF
	for triangle in geometry.triangle_count():
		var base := triangle * 3
		if geometry.normals[base].y <= 0.0:
			continue
		var a := geometry.vertices[base]
		var b := geometry.vertices[base + 1]
		var c := geometry.vertices[base + 2]
		var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(area) < 0.000001:
			continue
		var wb := ((x - a.x) * (c.z - a.z) - (c.x - a.x) * (z - a.z)) / area
		var wc := ((b.x - a.x) * (z - a.z) - (x - a.x) * (b.z - a.z)) / area
		var wa := 1.0 - wb - wc
		if wa < -0.0001 or wb < -0.0001 or wc < -0.0001:
			continue
		var height := a.y * wa + b.y * wb + c.y * wc
		if height > highest:
			highest = height
			found["height"] = height
		if geometry.normals[base].y > flattest:
			flattest = geometry.normals[base].y
			found["normal"] = geometry.normals[base]
	return found


## The same geometry carried across the world by `shift`, with nothing else
## changed.
func _shifted(geometry: TerrainChunkGeometry, shift: Vector2) -> TerrainChunkGeometry:
	var moved := geometry.detached_copy()
	for at in moved.vertices.size():
		moved.vertices[at] = moved.vertices[at] + Vector3(shift.x, 0.0, shift.y)
	return moved


## Where one island's grass stands, in plan, over the part of its top that
## another island's plan also covers.
func _patches_over(
	layer: GrassLayer, mesher: IslandMesher, island: FloatingIsland, other: FloatingIsland
) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var view := layer.build_island(mesher.build(island), island)
	if view == null:
		return found
	var buffer: PackedFloat32Array = view.multimesh.buffer
	for at in view.multimesh.instance_count:
		var x := buffer[at * STRIDE + AT_X]
		var z := buffer[at * STRIDE + AT_Z]
		if other.covers(x, z):
			found.append(Vector2(x, z))
	view.free()
	return found


## Which cell of the *world's* grass lattice a plan position falls in.
func _world_cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / GrassLayer.CELL), floori(at.y / GrassLayer.CELL))


## A fingerprint of one island's grass, in the probe's own format.
func _island_digest(view: MultiMeshInstance3D) -> String:
	var parts := PackedStringArray()
	for value in view.multimesh.buffer:
		parts.append("%.5f" % value)
	return "%d/%s" % [
		view.multimesh.instance_count,
		"|".join(parts).sha256_text().substr(0, 16),
	]


func _flat_chunk(chunk_x: int, chunk_z: int, tint: Color) -> TerrainChunkGeometry:
	var geometry := TerrainChunkGeometry.new(chunk_x, chunk_z)
	var origin_x := float(chunk_x) * TerrainChunkMesher.CHUNK_SIZE
	var origin_z := float(chunk_z) * TerrainChunkMesher.CHUNK_SIZE
	var cells := TerrainChunkMesher.CELLS
	var size := TerrainChunkMesher.CELL_SIZE
	for row in cells:
		for column in cells:
			var corners: Array[Vector2] = [
				Vector2(float(column), float(row)),
				Vector2(float(column + 1), float(row)),
				Vector2(float(column), float(row + 1)),
				Vector2(float(column + 1), float(row)),
				Vector2(float(column + 1), float(row + 1)),
				Vector2(float(column), float(row + 1)),
			]
			for corner in corners:
				geometry.vertices.append(Vector3(
					origin_x + corner.x * size, DRY_HEIGHT, origin_z + corner.y * size
				))
				geometry.normals.append(Vector3.UP)
				geometry.colors.append(tint)
				geometry.indices.append(geometry.indices.size())
	geometry.lowest = DRY_HEIGHT
	geometry.highest = DRY_HEIGHT
	return geometry


## The rule for a blade's colour, written out again here so that the layer is
## checked against a statement of the rule rather than against itself.
func _expected_tint(ground: Color, foliage: Color, reference: Color) -> Color:
	var wanted := ground.lerp(foliage, GrassLayer.LEAF_MIX).srgb_to_linear()
	var base := reference.srgb_to_linear()
	var most := GrassLayer.MAX_GAIN
	return Color(
		clampf(wanted.r / base.r, 0.0, most) / most,
		clampf(wanted.g / base.g, 0.0, most) / most,
		clampf(wanted.b / base.b, 0.0, most) / most,
	)


## The height of a chunk's drawn surface at a position, found by testing every
## triangle in the chunk rather than by computing which one it must be. Slower
## and independent, which is the point.
func _surface_under(geometry: TerrainChunkGeometry, x: float, z: float) -> float:
	for triangle in geometry.triangle_count():
		var base := triangle * 3
		var a := geometry.vertices[base]
		var b := geometry.vertices[base + 1]
		var c := geometry.vertices[base + 2]
		var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(area) < 0.000001:
			continue
		var wb := ((x - a.x) * (c.z - a.z) - (c.x - a.x) * (z - a.z)) / area
		var wc := ((b.x - a.x) * (z - a.z) - (x - a.x) * (b.z - a.z)) / area
		var wa := 1.0 - wb - wc
		if wa < -0.0001 or wb < -0.0001 or wc < -0.0001:
			continue
		return a.y * wa + b.y * wb + c.y * wc
	return INF


## Where the first `count` instances of a chunk's grass sit: the extent they
## cover and their middle.
func _spread_of(view: MultiMeshInstance3D, count: int) -> Dictionary:
	var lowest := Vector2(INF, INF)
	var highest := Vector2(-INF, -INF)
	var middle := Vector2.ZERO
	var buffer: PackedFloat32Array = view.multimesh.buffer
	for at in count:
		var here := Vector2(buffer[at * STRIDE + AT_X], buffer[at * STRIDE + AT_Z])
		lowest = Vector2(minf(lowest.x, here.x), minf(lowest.y, here.y))
		highest = Vector2(maxf(highest.x, here.x), maxf(highest.y, here.y))
		middle += here / float(count)
	return {"span": highest - lowest, "middle": middle}


## The "mask x z pure impure" lines of the probe's output.
func _mask_lines(text: String) -> Array:
	var found: Array = []
	for line in text.split("\n"):
		var parts := line.strip_edges().split(" ")
		if parts.size() != 5 or parts[0] != "mask":
			continue
		found.append({
			"x": parts[1].to_float(), "z": parts[2].to_float(),
			"pure": parts[3], "impure": parts[4],
		})
	return found


func _run_render_shell(extra: Array) -> Dictionary:
	var output: Array[String] = []
	var args: Array = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", str(FIXED_FPS),
		"--quit-after", str(FRAMES),
		"--",
		"--seed", str(SEED),
	]
	args.append_array(extra)
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _digest_from(output: String) -> String:
	for line in output.split("\n"):
		if not line.contains("render-shell stop tick="):
			continue
		var at := line.find("digest=")
		if at == -1:
			continue
		return line.substr(at + "digest=".length()).strip_edges()
	return ""


func _counts_from(output: String) -> Dictionary:
	for line in output.split("\n"):
		if not line.contains("render-shell stop tick="):
			continue
		var counts := {}
		for field in line.strip_edges().split(" "):
			var parts := field.split("=")
			if parts.size() == 2 and parts[1].is_valid_int():
				counts[parts[0]] = parts[1].to_int()
		return counts
	return {}


## The "assets <label> found=N loaded=M" line of a headless report, as
## {found, loaded}, or empty when the line is missing.
func _asset_line(text: String, label: String) -> Dictionary:
	for line in text.split("\n"):
		if not line.contains("assets %s " % label):
			continue
		var found := {}
		for field in line.strip_edges().split(" "):
			var parts := field.split("=")
			if parts.size() == 2 and parts[1].is_valid_int():
				found[parts[0]] = parts[1].to_int()
		return found
	return {}
