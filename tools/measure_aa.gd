extends SceneTree
## What each anti-aliasing mode removes from a frame, and what it costs.
##
##   ./tools/measure_aa.sh                                   # the meadow, seed 1234
##   ./tools/measure_aa.sh --seed 7 --start 228 -60 --region 250 380 800 560
##   ./tools/measure_aa.sh --no-grass --shots /tmp/aa        # save each mode's frame
##
## Runs the render shell itself, holds the world still, and then draws the *same
## paused frame* once per mode in AntiAliasing.MODES: it switches the mode on the
## main viewport, lets the renderer settle, samples frame times, and reads the
## finished picture back to measure how noisy it is (tools/noise_metric.gd). One
## process, one world, one camera, so the modes differ by the mode alone.
##
## Grass is on unless --no-grass is given, deliberately: grass is the great
## majority of the primitives in this frame and thin geometry is the worst case
## for multi-sampling, so a table measured without it would price the cheap
## answer and not the real one.
##
## Frame times on a machine with no graphics card are software rasterisation.
## They are a fair *ranking* of what each mode asks for and they are not the
## game's frame rate; a mode that multiplies the per-pixel work shows up here
## far heavier than it does on hardware built to do it.

const NoiseMetric := preload("res://tools/noise_metric.gd")

## The world is held still and the camera never moves, so a frame costs what the
## mode costs and little else: a few dozen frames settle the shell, a dozen more
## absorb the render targets being rebuilt and temporal anti-aliasing converging,
## and twenty samples are enough for a mean that does not wander. They are small
## on purpose -- one frame of this scene under software rasterisation is seconds,
## not milliseconds, and the sweep draws it in every mode.
const SETTLE_FRAMES := 60
const WARM_FRAMES := 15
const SAMPLE_FRAMES := 20

var _shell: Node = null
var _region := NoiseMetric.MEADOW
var _shots := ""
var _modes: Array = []
var _mode := -1
var _frames := 0
var _last_usec := 0
var _times: Array[float] = []
var _rows: Array = []
var _baseline := {}


func _initialize() -> void:
	# The shell reads the same command line for its own arguments -- --seed,
	# --start, --no-grass, --camera and the rest -- so those are left alone here
	# and simply reach it. Only this tool's own are consumed.
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
			"--shots":
				# Where to save each mode's frame, so the table has pictures to
				# go with it. One PNG per mode, named after the mode.
				if i + 1 < args.size():
					_shots = args[i + 1]
					i += 1
			"--modes":
				# A comma-separated subset, for when only two of them are in
				# question and each one costs a minute of software rasterising.
				if i + 1 < args.size():
					_modes = Array(args[i + 1].split(",", false))
					i += 1
		i += 1
	if _modes.is_empty():
		_modes = AntiAliasing.ORDER.duplicate()

	_shell = load("res://render/main.tscn").instantiate()
	root.add_child(_shell)
	_last_usec = Time.get_ticks_usec()
	print("region              x %d..%d, y %d..%d" % [
		_region.position.x, _region.end.x, _region.position.y, _region.end.y,
	])


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	_frames += 1
	if _frames == 1:
		# Held still for the whole sweep: every mode draws the same world from
		# the same place, so the numbers differ by the mode and by nothing else.
		_shell.set("_paused", true)

	if _mode < 0:
		if _frames >= SETTLE_FRAMES:
			_start_mode(0)
		return false

	if _frames <= WARM_FRAMES:
		# Switching the mode rebuilds the render targets, and temporal
		# anti-aliasing has to accumulate several frames before it is showing
		# what it is worth. Neither belongs in the timing.
		return false
	_times.append(frame_ms)
	if _times.size() < SAMPLE_FRAMES:
		return false

	_finish_mode()
	if _mode + 1 < _modes.size():
		_start_mode(_mode + 1)
		return false
	_report()
	return true


func _start_mode(index: int) -> void:
	_mode = index
	_frames = 0
	_times = []
	var mode: String = _modes[index]
	if not AntiAliasing.apply(_shell.get_viewport(), mode):
		printerr("measure_aa: unknown mode %s" % mode)
		_rows.append({"mode": mode, "unknown": true})


func _finish_mode() -> void:
	var mode: String = _modes[_mode]
	var image := _shell.get_viewport().get_texture().get_image()
	var found: Dictionary = NoiseMetric.measure(image, _region)
	if _shots != "":
		image.save_png("%s/aa-%s.png" % [_shots, mode.replace("+", "-")])
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for one in sorted:
		total += one
	var row := {
		"mode": mode,
		"label": String(AntiAliasing.MODES[mode]["label"]),
		"mean_ms": total / float(sorted.size()),
		"median_ms": sorted[sorted.size() / 2],
		"p95_ms": sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))],
		"noise": found,
	}
	if _baseline.is_empty():
		_baseline = row
	_rows.append(row)
	# Printed as each mode finishes rather than only at the end: a sweep of seven
	# modes on a machine with no graphics card takes minutes, and a run that is
	# killed halfway is still worth what it had measured.
	print("  %-11s %s" % [mode, NoiseMetric.line(row["label"], found)])


func _report() -> void:
	var world = _shell.get("_sim").world
	var profile: BiomeProfile = world.terrain.profile_at(world.observer_x, world.observer_z)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("")
	print("measured at         (%.1f, %.1f) in %s, %d primitives in the frame" % [
		world.observer_x, world.observer_z, profile.display_name, int(primitives),
	])
	print("project setting     %s" % AntiAliasing.from_project_settings())
	print("")
	print("%-11s %-26s %9s %9s %9s %8s" % [
		"mode", "what it is", "lap std", "vs off", "frame ms", "vs off",
	])
	var base_noise: float = _baseline["noise"]["laplacian_std"]
	var base_ms: float = _baseline["mean_ms"]
	for row in _rows:
		if row.has("unknown"):
			continue
		var noise: float = row["noise"]["laplacian_std"]
		print("%-11s %-26s %9.4f %8.0f%% %9.1f %7.2fx" % [
			row["mode"], row["label"], noise,
			100.0 * (noise / base_noise - 1.0),
			row["mean_ms"], row["mean_ms"] / base_ms,
		])
	print("")
	print("frame times are software rasterisation on this machine: a ranking of")
	print("what each mode asks for, not the game's frame rate.")
