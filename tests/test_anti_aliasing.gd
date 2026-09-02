extends TestSuite
## Anti-aliasing: that the project asks for it, that a capture can name a
## different mode, that the water's mirror makes its own smaller choice, and that
## the number the choice was made on measures what it claims to.
##
## The project shipped with no anti-aliasing key at all, which is what made a
## meadow read as noise: a field of thin blades is the worst case for a renderer
## that takes one sample per pixel. The mode is now a project setting, so most of
## what there is to check is that the setting reaches the viewport and that
## nothing else quietly overrides it.
##
## The noise metric is checked here too, on pictures whose answer is known by
## construction -- flat ground, a straight ramp, a one-pixel checkerboard --
## because every claim in reports/grass.md is a number that tool produced.
class_name TestAntiAliasing

const SEED := 5
const FIXED_FPS := 60
const FRAMES := 30

const NoiseMetric := preload("res://tools/noise_metric.gd")


func _init() -> void:
	suite_name = "anti-alias"


func run() -> void:
	_the_project_asks_for_a_mode_the_table_knows()
	_every_mode_can_be_applied_to_a_viewport_and_read_back()
	_the_noise_number_is_flat_on_smooth_ground_and_high_on_a_stipple()
	_the_noise_number_falls_when_the_same_picture_is_resolved_more_finely()
	_a_region_outside_the_picture_is_refused_rather_than_guessed()
	_the_shell_draws_with_the_project_mode_and_with_the_one_a_capture_names()
	_the_water_mirror_takes_the_filter_and_refuses_the_sampling()
	_headless_loads_no_part_of_the_render_layer_including_this_setting()


## The setting exists, names a mode this table knows, and is not "off".
##
## The point of the work: before it, project.godot had no anti-aliasing key, so
## the engine drew the main viewport with one sample per pixel.
func _the_project_asks_for_a_mode_the_table_knows() -> void:
	var mode := AntiAliasing.from_project_settings()
	check(AntiAliasing.MODES.has(mode),
		"the project's anti-aliasing settings are a combination the table does " +
		"not name (%s)" % mode)
	not_equal(mode, "off",
		"the project sets no anti-aliasing on the main viewport, which is what " +
		"made the grass read as noise")
	check(ProjectSettings.has_setting(AntiAliasing.SETTING_MSAA),
		"project.godot carries no %s key" % AntiAliasing.SETTING_MSAA)


## Applying a mode sets the three properties that make it, and reading a
## viewport back names the mode it was set to. The table and the order it is
## reported in have to agree, or a sweep would silently skip a mode.
func _every_mode_can_be_applied_to_a_viewport_and_read_back() -> void:
	var viewport := SubViewport.new()
	for mode in AntiAliasing.MODES:
		check(AntiAliasing.apply(viewport, mode), "mode %s could not be applied" % mode)
		equal(AntiAliasing.of(viewport), mode,
			"a viewport set to %s reads back as something else" % mode)
	AntiAliasing.apply(viewport, "msaa4")
	check(not AntiAliasing.apply(viewport, "no-such-mode"),
		"an unknown mode was accepted rather than refused")
	equal(AntiAliasing.of(viewport), "msaa4",
		"an unknown mode changed the viewport it was refused on")
	equal(AntiAliasing.ORDER.size(), AntiAliasing.MODES.size(),
		"the reporting order covers %d modes but the table has %d"
		% [AntiAliasing.ORDER.size(), AntiAliasing.MODES.size()])
	for mode in AntiAliasing.ORDER:
		check(AntiAliasing.MODES.has(mode),
			"the reporting order names %s, which is not in the table" % mode)
	viewport.free()


## What the noise number does on pictures whose answer is known without
## measuring: flat ground and a straight ramp of brightness are both perfectly
## smooth and must score zero however light or dark they are, and a checkerboard
## that flips every pixel is the noisiest thing a picture can be.
func _the_noise_number_is_flat_on_smooth_ground_and_high_on_a_stipple() -> void:
	var region := Rect2i(0, 0, 64, 64)
	var flat := _painted(64, 64, func(_x: int, _y: int) -> float: return 0.42)
	var ramp := _painted(64, 64, func(x: int, _y: int) -> float: return float(x) / 128.0)
	var stipple := _painted(64, 64, func(x: int, y: int) -> float:
		return 1.0 if (x + y) % 2 == 0 else 0.0)

	var flat_found: Dictionary = NoiseMetric.measure(flat, region)
	var ramp_found: Dictionary = NoiseMetric.measure(ramp, region)
	var stipple_found: Dictionary = NoiseMetric.measure(stipple, region)

	check(flat_found["laplacian_std"] < 0.001,
		"flat grey scored %.4f, so the number is measuring brightness rather "
		% flat_found["laplacian_std"] + "than pixel-to-pixel jitter")
	check(ramp_found["laplacian_std"] < 0.01,
		"a straight ramp scored %.4f; a smooth slope of ground is not noise"
		% ramp_found["laplacian_std"])
	check(ramp_found["lum_std"] > 0.1,
		"the ramp used for that check is not actually a ramp (spread %.4f)"
		% ramp_found["lum_std"])
	check(stipple_found["laplacian_std"] > 1.0,
		"a one-pixel checkerboard only scored %.4f, so the number is not "
		% stipple_found["laplacian_std"] + "sensitive to the thing it is for")
	equal(flat_found["pixels"], 64 * 64, "the whole region should have been measured")


## The point of anti-aliasing, in miniature: the same picture resolved more
## finely and then averaged down -- which is what multi-sampling does -- scores
## far lower, while the brightness it is a picture of stays where it was.
func _the_noise_number_falls_when_the_same_picture_is_resolved_more_finely() -> void:
	var region := Rect2i(0, 0, 64, 64)
	var aliased := _painted(64, 64, func(x: int, y: int) -> float:
		# One-pixel-wide stripes at an angle: thin geometry sampled once a pixel,
		# which is a blade of grass as the renderer sees it.
		return 1.0 if (x + 2 * y) % 3 == 0 else 0.2)
	# The same stripes, but each pixel is the average of the four it covers --
	# a 2x2 resolve, which is what 4x multi-sampling ends up doing to an edge.
	var resolved := _painted(64, 64, func(x: int, y: int) -> float:
		var total := 0.0
		for dx in 2:
			for dy in 2:
				total += 1.0 if (2 * x + dx + 2 * (2 * y + dy)) % 3 == 0 else 0.2
		return total / 4.0)

	var before: Dictionary = NoiseMetric.measure(aliased, region)
	var after: Dictionary = NoiseMetric.measure(resolved, region)
	check(after["laplacian_std"] < 0.6 * before["laplacian_std"],
		"resolving the stripes more finely moved the noise number from %.4f to "
		% before["laplacian_std"] + "%.4f, which is not the fall it should be"
		% after["laplacian_std"])
	check(absf(after["lum_mean"] - before["lum_mean"]) < 0.05,
		"the resolve moved mean brightness from %.4f to %.4f, so the number "
		% [before["lum_mean"], after["lum_mean"]] + "would be measuring exposure")


## A rectangle that is not really in the picture gives nothing back rather than a
## number over whatever part of it happened to overlap, because a noise number
## quoted over an unknown region is worse than none.
func _a_region_outside_the_picture_is_refused_rather_than_guessed() -> void:
	var image := _painted(16, 16, func(_x: int, _y: int) -> float: return 0.5)
	check(NoiseMetric.measure(image, Rect2i(100, 100, 20, 20)).is_empty(),
		"a region entirely off the picture returned a number")
	check(NoiseMetric.measure(image, Rect2i(15, 15, 20, 20)).is_empty(),
		"a region overlapping the picture in one pixel returned a number")
	check(NoiseMetric.measure_file("res://tests/no-such-frame.png", Rect2i(0, 0, 8, 8)).is_empty(),
		"a missing file returned a number")


## The shell draws with what the project asks for, and a capture can name a
## different mode on the command line without the project file being edited.
## Read off the boot line, so it needs no screen to look at.
func _the_shell_draws_with_the_project_mode_and_with_the_one_a_capture_names() -> void:
	var project_mode := AntiAliasing.from_project_settings()
	var plain := _run_render_shell([])
	var named := _run_render_shell(["--aa", "off"])
	equal(plain["exit_code"], 0, "render shell should exit 0 (output: %s)" % plain["output"])
	equal(named["exit_code"], 0, "render shell should exit 0 (output: %s)" % named["output"])
	equal(_aa_from(plain["output"]), project_mode,
		"a run with no --aa drew with something other than the project's mode")
	equal(_aa_from(named["output"]), "off",
		"--aa off did not reach the viewport")
	not_equal(project_mode, "off",
		"the two runs above would not differ, so the check shows nothing")


## The mirror under the water takes the screen-space filter and refuses the
## multi-sampling, which is a measured split rather than a tidy one: priced on
## the pond beat, FXAA inside the mirror is 17% of the reflection's noise for
## 0.6% of the frame, and multi-sampling it as well is a further 5% for half a
## frame again (reports/grass.md section 9.6). Both halves are pinned here so
## that neither drifts into matching the main viewport by tidiness.
func _the_water_mirror_takes_the_filter_and_refuses_the_sampling() -> void:
	var host := Node.new()
	var mirror := WaterReflection.new()
	mirror.attach(host)
	var viewport := host.get_node_or_null("water_reflection") as SubViewport
	check(viewport != null, "the reflection did not hang a viewport on the shell")
	if viewport != null:
		equal(AntiAliasing.of(viewport), "fxaa",
			"the water's mirror is not drawing with the filter alone; sampling " +
			"a half-resolution image four times a pixel is spent on detail the " +
			"ripples destroy, and it is a second whole view of the world")
		equal(viewport.msaa_3d, Viewport.MSAA_DISABLED,
			"the mirror is multi-sampling, which is the expensive half")
		equal(viewport.use_debanding, false, "the mirror should not deband either")
		not_equal(AntiAliasing.of(viewport), AntiAliasing.from_project_settings(),
			"the mirror is drawing with exactly what the main viewport does, so " +
			"nothing here is checking that it makes its own choice")
	host.free()


## A headless process has no viewport to set any of this on, and never loads the
## file that would set it. Asked of the engine's own resource cache from outside
## the render layer, the same way the grass and the atmosphere are asked.
func _headless_loads_no_part_of_the_render_layer_including_this_setting() -> void:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(SEED), "--ticks", "20", "--assets",
	], output, true)
	var text := "\n".join(output)
	equal(exit_code, 0, "headless run should exit 0 (output: %s)" % text)

	var render_scripts := _asset_line(text, "render-scripts")
	check(not render_scripts.is_empty(),
		"the headless run reported no render-scripts line: %s" % text)
	if render_scripts.is_empty():
		return
	equal(render_scripts["loaded"], 0,
		"a headless run loaded %d file(s) of the render layer"
		% render_scripts["loaded"])
	check(FileAccess.file_exists("res://render/anti_aliasing.gd"),
		"render/anti_aliasing.gd is missing, so the check above covers nothing")
	check(render_scripts["found"] >= 9,
		"only %d render scripts were counted; the anti-aliasing table is not "
		% render_scripts["found"] + "among them")


## A greyscale picture painted by a rule, for the metric checks.
func _painted(width: int, height: int, value: Callable) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var level: float = clampf(value.call(x, y), 0.0, 1.0)
			image.set_pixel(x, y, Color(level, level, level))
	return image


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


func _aa_from(output: String) -> String:
	for line in output.split("\n"):
		var at := line.find("render-shell boot")
		if at == -1:
			continue
		var mark := line.find("aa=")
		if mark == -1:
			continue
		return line.substr(mark + "aa=".length()).strip_edges()
	return ""


## "assets render-scripts found=8 loaded=0 -> ..." as {found, loaded}.
func _asset_line(text: String, label: String) -> Dictionary:
	for line in text.split("\n"):
		if not line.begins_with("assets %s " % label):
			continue
		var found := -1
		var loaded := -1
		for piece in line.split(" ", false):
			if piece.begins_with("found="):
				found = piece.substr("found=".length()).to_int()
			elif piece.begins_with("loaded="):
				loaded = piece.substr("loaded=".length()).to_int()
		if found >= 0 and loaded >= 0:
			return {"found": found, "loaded": loaded}
	return {}
