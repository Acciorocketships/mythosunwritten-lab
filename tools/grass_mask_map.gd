extends SceneTree
## Draw the grass layer's clearing mask over a square of world, as a picture.
##
## The mask decides where grass grows in patches rather than in confetti, and it
## is a field over the whole world rather than anything a frame can hold: the
## playing camera only ever shows the 76-unit disc the grass is built in, so a
## screenshot can show that *this* meadow has a clearing in it but cannot show
## what clearings are like. This can. It is the only way to look at the shape of
## the thing rather than at one sample of it.
##
##   ./tools/grass_mask_map.sh --seed 1234 --at 228 -60 --out /tmp/mask.png
##   ./tools/grass_mask_map.sh --span 480 --side 720
##
## What is drawn is the finished answer -- the biome's own grass coverage times
## the clearing mask, pushed through the curve -- and not the mask alone, because
## the finished answer is what the ground looks like. Bare earth is drawn in the
## catalog's own path dirt and closed carpet in a mid green, so the ramp between
## them reads as the edge of a bed. The white ring is GrassLayer.BUILD_RADIUS
## round the position asked for: everything inside it is what one frame from the
## playing camera can contain.
##
## Needs no display and no render shell: the mask is a pure function of world
## position and the seed, which is the whole point of it.

const BARE := Color(0.44, 0.32, 0.21)
const CLOSED := Color(0.30, 0.72, 0.28)


func _initialize() -> void:
	var world_seed := 1234
	var at := Vector2(228.0, -60.0)
	var span := 240.0
	var side := 512
	var out := "/tmp/grass-mask.png"

	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var has_value := i + 1 < args.size()
		match args[i]:
			"--seed":
				if has_value and args[i + 1].is_valid_int():
					world_seed = args[i + 1].to_int()
			"--at":
				if i + 2 < args.size() and args[i + 1].is_valid_float() \
						and args[i + 2].is_valid_float():
					at = Vector2(args[i + 1].to_float(), args[i + 2].to_float())
			"--span":
				if has_value and args[i + 1].is_valid_float():
					span = args[i + 1].to_float()
			"--side":
				if has_value and args[i + 1].is_valid_int():
					side = args[i + 1].to_int()
			"--out":
				if has_value:
					out = args[i + 1]

	var terrain := TerrainQuery.for_seed(world_seed)
	var image := Image.create(side, side, false, Image.FORMAT_RGB8)
	var bare := 0
	var closed := 0
	var between := 0
	for row in side:
		for column in side:
			var x := at.x + (float(column) / float(side) - 0.5) * span
			var z := at.y + (float(row) / float(side) - 0.5) * span
			var grown := GrassLayer.grown_share(
				GrassLayer.clearing_at(x, z, world_seed),
				GrassLayer.coverage_for(terrain.biome_field.weights_at(x, z))
			)
			if grown <= 0.0:
				bare += 1
			elif grown >= 1.0:
				closed += 1
			else:
				between += 1
			image.set_pixel(column, row, BARE.lerp(CLOSED, grown))

	# The ring one frame can show.
	var steps := side * 4
	for step in steps:
		var angle := float(step) * TAU / float(steps)
		var column := int(round(float(side) * (0.5 + cos(angle) * GrassLayer.BUILD_RADIUS / span)))
		var row := int(round(float(side) * (0.5 + sin(angle) * GrassLayer.BUILD_RADIUS / span)))
		if column >= 0 and column < side and row >= 0 and row < side:
			image.set_pixel(column, row, Color(1.0, 1.0, 1.0))

	var whole := float(side * side)
	print("seed %d at (%.0f, %.0f), %.0f units across, %d px" % [
		world_seed, at.x, at.y, span, side,
	])
	print("biome              %s" % terrain.biome_at(at.x, at.y))
	print("mask scales        clearing %.0f (detail %.0f), boundary %.0f bent at %.0f, path %.1f" % [
		GrassLayer.CLEARING_SCALE, GrassLayer.CLEARING_DETAIL,
		GrassLayer.BOUNDARY_SCALE, GrassLayer.BOUNDARY_WANDER_SCALE,
		GrassLayer.BOUNDARY_PATH,
	])
	print("curve              %.2f to %.2f" % [GrassLayer.CURVE_LOW, GrassLayer.CURVE_HIGH])
	print("ground             %.1f%% bare, %.1f%% ramp, %.1f%% closed carpet" % [
		100.0 * float(bare) / whole,
		100.0 * float(between) / whole,
		100.0 * float(closed) / whole,
	])
	if image.save_png(out) != OK:
		printerr("could not write %s" % out)
		quit(1)
		return
	print("wrote %s" % out)
	quit(0)
