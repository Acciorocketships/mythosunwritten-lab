extends SceneTree
## What the grass does to the ground it is standing on, pixel by pixel.
##
##   ./tools/measure_stipple.sh --start 228 -60              # the meadow
##   ./tools/measure_stipple.sh --mixes 0.5,0.3,0.2 --shots /tmp/mix
##   ./tools/measure_stipple.sh --start 96 -232 --region 250 380 800 560
##
## This is the instrument the blade colour was chosen with. It draws one frame
## twice -- once with the grass hidden and once with it drawn -- and reports how
## far the blades move the picture away from the bare ground underneath them:
## what share of the pixels they touch at all, how much of that share they
## brighten and by how much, how much they darken and by how much, and where the
## red, green and blue of the touched pixels sit with the grass on and off.
##
## Two ways of saying "stipple" are reported, because the obvious one misleads.
## The *bipolar spread* is the gap between the mean brightening and the mean
## darkening, which is how the diagnosis stated it: grass laid over smooth ground
## pushes some pixels up and others down, and that gap is what reads as noise.
## But those are conditional means, so on a change that is nearly all one way
## they are each an average of a thin tail and they drift *apart* as the change
## becomes more uniform. The honest version is the standard deviation of the
## change itself over every pixel the grass touches: grass that darkens all of
## its ground by the same amount is a shade over it and scores zero however dark
## it is, and grass that throws pixels both ways scores high. Both are quoted
## against the ground's own variation, the standard deviation of luminance with
## the grass hidden, because grass that disturbs the picture by less than the
## ground already varies by cannot be what is standing out.
##
## The two frames come from one process, one world, one camera and one paused
## tick, differing only in whether the grass drawables are visible, so nothing
## but the grass can move between them. With --mixes the grass is then rebuilt at
## each blade-colour mix in turn and measured again, which is the sweep in
## reports/grass.md that picked GrassLayer.LEAF_MIX.
##
## Frame times are not reported here and are not the point: this measures the
## picture. tools/measure_aa.sh is where cost is priced.

const NoiseMetric := preload("res://tools/noise_metric.gd")

## Long enough for the streamer to have built the radius and the renderer to have
## settled, then a few frames after every change of state so that what is read
## back is the frame the change produced and not the one before it.
const SETTLE_FRAMES := 60
const WARM_FRAMES := 8

## A pixel counts as touched when the grass moved any channel by more than this.
## One step of an eight-bit channel, so it is "the picture changed here" and not
## a threshold with an opinion.
const TOUCHED := 1.0 / 255.0

var _shell: Node = null
var _region := NoiseMetric.MEADOW
var _shots := ""
var _mixes: Array[float] = []
var _off: Image = null
var _ground := {}
var _rows: Array = []
var _stage := -1
var _frames := 0


func _initialize() -> void:
	# The shell reads the same command line for its own arguments -- --seed,
	# --start, --camera and the rest -- so they are left to reach it untouched.
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--region":
				if i + 4 < args.size():
					var left := args[i + 1].to_int()
					var top := args[i + 2].to_int()
					var right := args[i + 3].to_int()
					var bottom := args[i + 4].to_int()
					_region = Rect2i(left, top, right - left, bottom - top)
					i += 4
			"--mixes":
				if i + 1 < args.size():
					for one in args[i + 1].split(",", false):
						_mixes.append(one.to_float())
					i += 1
			"--shots":
				if i + 1 < args.size():
					_shots = args[i + 1]
					i += 1
		i += 1
	if _mixes.is_empty():
		_mixes.append(GrassLayer.LEAF_MIX)

	_shell = load("res://render/main.tscn").instantiate()
	root.add_child(_shell)
	print("region              x %d..%d, y %d..%d" % [
		_region.position.x, _region.end.x, _region.position.y, _region.end.y,
	])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# Held still for the whole sweep, so every capture is the same world seen
		# from the same place and the grass is the only thing that differs.
		_shell.set("_paused", true)
		return false
	if _shell.get("_grass") == null:
		printerr("measure_stipple: this run has no grass layer to measure")
		return true

	if _stage < 0:
		if _frames < SETTLE_FRAMES:
			return false
		_show_grass(false)
		_stage = 0
		_frames = 0
		return false

	if _frames < WARM_FRAMES:
		return false
	if _stage == 0:
		_off = _capture("off")
		_ground = NoiseMetric.measure(_off, _region)
		_show_grass(true)
		_rebuild(_mixes[0])
		_stage = 1
		_frames = 0
		return false

	_rows.append(_measure(_mixes[_stage - 1], _capture("mix-%.2f" % _mixes[_stage - 1])))
	if _stage < _mixes.size():
		_rebuild(_mixes[_stage])
		_stage += 1
		_frames = 0
		return false
	_report()
	return true


## Draw the frame the shell is holding, and keep it if pictures were asked for.
func _capture(label: String) -> Image:
	var image := _shell.get_viewport().get_texture().get_image()
	if _shots != "":
		image.save_png("%s/stipple-%s.png" % [_shots, label])
	return image


## Hide or show every chunk of grass, without touching anything else in the
## frame. Hiding rather than restarting the shell without grass is what makes the
## two pictures comparable pixel for pixel.
func _show_grass(shown: bool) -> void:
	var views: Dictionary = _shell.get("_grass_views")
	for key in views:
		(views[key] as Node3D).visible = shown


## Throw away every chunk of grass and grow it again at a different blade colour.
## The colour is baked into the instance buffer when a chunk is built, so a mix
## is a rebuild and not a uniform -- which is exactly why the shipped value is a
## constant and this is a measuring tool.
func _rebuild(mix: float) -> void:
	var grass: GrassLayer = _shell.get("_grass")
	grass.leaf_mix = mix
	var views: Dictionary = _shell.get("_grass_views")
	for key in views:
		(views[key] as Node3D).free()
	views.clear()
	_shell.call("_sync_views")


## How far the grass moved the picture, over the pixels it touched at all.
func _measure(mix: float, on: Image) -> Dictionary:
	var clipped := _region.intersection(Rect2i(0, 0, on.get_width(), on.get_height()))
	var touched := 0
	var changes := PackedFloat32Array()
	var up := 0
	var down := 0
	var up_total := 0.0
	var down_total := 0.0
	var absolute := 0.0
	var channels_on := Vector3.ZERO
	var channels_off := Vector3.ZERO
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var here := on.get_pixel(x, y)
			var bare := _off.get_pixel(x, y)
			if absf(here.r - bare.r) <= TOUCHED \
				and absf(here.g - bare.g) <= TOUCHED \
				and absf(here.b - bare.b) <= TOUCHED:
				continue
			touched += 1
			var change := here.get_luminance() - bare.get_luminance()
			changes.append(change)
			absolute += absf(change)
			if change >= 0.0:
				up += 1
				up_total += change
			else:
				down += 1
				down_total += change
			channels_on += Vector3(here.r, here.g, here.b)
			channels_off += Vector3(bare.r, bare.g, bare.b)
	var pixels := float(maxi(clipped.size.x * clipped.size.y, 1))
	var seen := float(maxi(touched, 1))
	# How much the change itself varies from one touched pixel to the next. This
	# is the stipple, stated without asking first whether a pixel went up or
	# down: grass that darkened every pixel it covers by the same amount is a
	# shade over the ground and scores zero here however dark it is, and grass
	# that throws some pixels up and others down scores high. The pair of
	# conditional means below cannot tell those apart, and on a one-sided change
	# they drift apart as the change gets *more* uniform.
	var mean_change := 0.0
	for change in changes:
		mean_change += change
	mean_change /= seen
	var spread := 0.0
	for change in changes:
		spread += (change - mean_change) * (change - mean_change)
	return {
		"change_mean": mean_change,
		"change_std": sqrt(spread / seen),
		"mix": mix,
		"touched": float(touched) / pixels,
		"up_share": float(up) / seen,
		"down_share": float(down) / seen,
		"up_mean": up_total / float(maxi(up, 1)),
		"down_mean": down_total / float(maxi(down, 1)),
		"amplitude": absolute / seen,
		"on": channels_on / seen,
		"off": channels_off / seen,
		"noise": NoiseMetric.measure(on, _region),
	}


func _report() -> void:
	var world = _shell.get("_sim").world
	var profile: BiomeProfile = world.terrain.profile_at(world.observer_x, world.observer_z)
	print("")
	print("measured at         (%.1f, %.1f) in %s, %d tufts drawn" % [
		world.observer_x, world.observer_z, profile.display_name,
		int(_shell.get("_grass_drawn")),
	])
	print("bare ground         lum mean %.4f, lum std %.4f, lap std %.4f" % [
		_ground["lum_mean"], _ground["lum_std"], _ground["laplacian_std"],
	])
	print("")
	print("%-6s %8s %9s %9s %9s %9s %9s %9s %9s" % [
		"mix", "touched", "brighter", "by", "darker", "by", "spread",
		"mean", "std",
	])
	for row in _rows:
		print("%-6.2f %7.1f%% %8.1f%% %+9.4f %8.1f%% %+9.4f %9.4f %+9.4f %9.4f" % [
			row["mix"], 100.0 * row["touched"], 100.0 * row["up_share"], row["up_mean"],
			100.0 * row["down_share"], row["down_mean"], row["up_mean"] - row["down_mean"],
			row["change_mean"], row["change_std"],
		])
	print("")
	print("per channel over the pixels the grass touches, grass off -> grass on")
	print("%-6s %21s %21s %21s %9s" % ["mix", "red", "green", "blue", "lap std"])
	for row in _rows:
		var on: Vector3 = row["on"]
		var off: Vector3 = row["off"]
		print("%-6.2f %8.3f -> %-8.3f %8.3f -> %-8.3f %8.3f -> %-8.3f %9.4f" % [
			row["mix"], off.x, on.x, off.y, on.y, off.z, on.z,
			row["noise"]["laplacian_std"],
		])
	print("")
	# The number the shipped mix was chosen on. Grass that changes every channel
	# by the same share is the *same* colour under less light -- ground cover.
	# Grass that changes one channel much further than the others is a different
	# colour laid on top, which is what a stipple of confetti is, and it is what
	# the diagnosis measured: red and green moved 3% while blue fell 23%.
	print("what the grass does to each channel, as a share of the ground's own")
	print("%-6s %9s %9s %9s %11s" % ["mix", "red", "green", "blue", "hue spread"])
	for row in _rows:
		var on: Vector3 = row["on"]
		var off: Vector3 = row["off"]
		var share := Vector3(
			100.0 * (on.x / maxf(off.x, 0.0001) - 1.0),
			100.0 * (on.y / maxf(off.y, 0.0001) - 1.0),
			100.0 * (on.z / maxf(off.z, 0.0001) - 1.0),
		)
		var most := maxf(share.x, maxf(share.y, share.z))
		var least := minf(share.x, minf(share.y, share.z))
		print("%-6.2f %8.1f%% %8.1f%% %8.1f%% %10.1f" % [
			row["mix"], share.x, share.y, share.z, most - least,
		])
	print("")
	print("spread is the gap between the mean brightening and the mean darkening,")
	print("mean and std are of the change itself over every pixel the grass touches:")
	print("std is the stipple, and it is zero for grass that is simply a shade over")
	print("its ground. The ground's own std is %.4f." % _ground["lum_std"])
	print("hue spread is the gap between the channel that moved furthest and the")
	print("one that moved least: zero is grass the colour of its ground, lit less.")
