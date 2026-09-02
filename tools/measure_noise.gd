extends SceneTree
## How noisy a saved frame is, over a rectangle of its pixels.
##
##   ./tools/measure_noise.sh reports/assets/grass-noise-compare.png
##   ./tools/measure_noise.sh a.png b.png --region 250 380 800 560
##
## The number reported is the standard deviation of the discrete Laplacian of
## luminance -- see tools/noise_metric.gd for what that means and why it is the
## one that answers "does this look noisy". The default rectangle is the meadow
## the user's complaint was measured over (seed 1234 at (228, -60), the frame
## captured by run_render.sh --paused --start 228 -60 --screenshot-frame 40).
##
## Any number of images may be given; they are reported as one table so that a
## before and an after can be compared in a single command. Runs headless: it
## reads pixels off disk and never opens a window.

const NoiseMetric := preload("res://tools/noise_metric.gd")


func _initialize() -> void:
	var paths: Array[String] = []
	var region := NoiseMetric.MEADOW
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--region":
				# Left, top, right, bottom in pixels, the way an image viewer
				# reports a selection, rather than a position and a size.
				if i + 4 < args.size():
					var left := args[i + 1].to_int()
					var top := args[i + 2].to_int()
					var right := args[i + 3].to_int()
					var bottom := args[i + 4].to_int()
					region = Rect2i(left, top, right - left, bottom - top)
					i += 4
			_:
				paths.append(args[i])
		i += 1

	if paths.is_empty():
		printerr("measure_noise: give at least one image path")
		quit(2)
		return

	print("region              x %d..%d, y %d..%d" % [
		region.position.x, region.end.x, region.position.y, region.end.y,
	])
	print(NoiseMetric.header())
	var failed := false
	for path in paths:
		var found: Dictionary = NoiseMetric.measure_file(path, region)
		if found.is_empty():
			printerr("measure_noise: could not read %s at that region" % path)
			failed = true
			continue
		print(NoiseMetric.line(path.get_file(), found))
	quit(1 if failed else 0)
