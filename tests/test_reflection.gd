extends TestSuite
## The water's mirror: that it is aimed correctly, that it costs nothing where
## there is nothing to mirror, and -- the load-bearing one -- that it does not
## reach the world.
##
## A planar reflection is the largest single thing the render shell does that the
## simulation knows nothing about: it draws the whole scene a second time from a
## camera that does not exist in the world, through a plane read out of the water
## field. Two claims follow from that and both are checked here from opposite
## ends. The world must be byte-identical with the mirror and without it, which
## is checked by running the shell both ways and comparing fingerprints. And the
## mirror must actually be a mirror -- a camera at the reflected position, the
## same distance the other side of the plane, looking back up at the same angle
## it was looking down -- which is checked as arithmetic on the transform rather
## than by looking at a picture.
##
## The geometry checks matter more than they look. The mirror camera is *not*
## built by reflecting the main camera's basis, because that would flip its
## handedness and invert every triangle's winding; it is aimed with look_at from
## the reflected position, which is right-handed and differs from the true mirror
## by a left-right flip that the water shader undoes. So "is it aimed right" is
## not obvious from the code and has to be measured: the position, the distance
## to the plane, the pitch and the bearing are each checked against the main
## camera's.
class_name TestReflection

## The seed and the place the shell is run from for the world-identity check.
## The lakeside village of seed 1234: somewhere with water in the streamed
## window, so the run with the mirror really draws one and the comparison against
## the run without is not two dry frames agreeing.
const SEED := 1234
const START_X := -10.0
const START_Z := -466.0
const FIXED_FPS := 60
const FRAMES := 90
## FRAMES / FIXED_FPS seconds of simulated time, at the shell's tick rate of 20.
const EXPECTED_TICKS := 30

## The plane and the camera the geometry checks are run against. Arbitrary but
## awkward on purpose: an off-axis bearing, a plane that is not zero, and a
## camera that is neither level nor over the origin.
const PLANE := -6.36
const EYE := Vector3(11.5, -1.4, -437.2)
const LOOK := Vector3(-8.8, -2.7, -463.7)

## How close two floats have to be to count as the same, in world units and in
## radians. Loose enough for a normalised basis, tight enough that a mirror out
## by anything visible would fail.
const CLOSE := 0.0005

## The lens the geometry checks are run with, and the far plane the main camera
## uses -- the shell's own CAMERA_FAR, quoted here because a suite may not load
## the shell's scene.
const FOV := 75.0
const CAMERA_FAR := 900.0


func _init() -> void:
	suite_name = "reflection"


func run() -> void:
	_the_mirror_camera_is_the_main_camera_reflected()
	_the_mirror_sees_a_shorter_world_and_never_the_water()
	_nothing_is_drawn_where_there_is_nothing_to_mirror()
	_the_mirror_follows_the_resolution_dial()
	_the_water_shader_takes_a_mirror_and_defaults_to_none()
	_the_world_is_byte_identical_with_and_without_the_mirror()


# --- The geometry --------------------------------------------------------

## The mirror camera stands where the main camera's reflection stands, looks
## back up at the angle the main camera looks down at, and faces the same way
## round the compass.
##
## Those three are the whole of "it is a mirror", and each is checked against the
## main camera rather than against a number written here -- so a change to how
## the transform is built fails this unless it still reflects.
func _the_mirror_camera_is_the_main_camera_reflected() -> void:
	var made := _aimed(EYE, LOOK, PLANE, true)
	if made.is_empty():
		return
	var view: Transform3D = made["view"]
	var mirror: Camera3D = made["mirror"]

	# Straight over the main camera, and as far under the plane as the main
	# camera is over it.
	var eye := view.origin
	var seen := mirror.transform.origin
	check(absf(seen.x - eye.x) < CLOSE and absf(seen.z - eye.z) < CLOSE,
		"the mirror camera stands at (%.3f, %.3f), not over the main camera at (%.3f, %.3f)"
		% [seen.x, seen.z, eye.x, eye.z])
	check(absf((eye.y - PLANE) - (PLANE - seen.y)) < CLOSE,
		"the main camera is %.3f over the plane and the mirror is %.3f under it"
		% [eye.y - PLANE, PLANE - seen.y])

	# Looking back up at the angle the main camera looks down at, and along the
	# same bearing.
	var down := -view.basis.z
	var up := -mirror.transform.basis.z
	check(absf(down.y + up.y) < CLOSE,
		"the main camera's pitch is %.4f and the mirror's is %.4f; a mirror's is "
		% [down.y, up.y] + "the negative of it")
	var flat_down := Vector2(down.x, down.z).normalized()
	var flat_up := Vector2(up.x, up.z).normalized()
	check(flat_down.distance_to(flat_up) < CLOSE,
		"the mirror looks along bearing (%.4f, %.4f), the main camera along (%.4f, %.4f)"
		% [flat_up.x, flat_up.y, flat_down.x, flat_down.y])

	# And it is not a squashed or widened view of the world: what a mirror shows
	# is the same lens.
	check(absf(mirror.fov - FOV) < CLOSE,
		"the mirror's field of view is %.3f and the camera's is %.3f"
		% [mirror.fov, FOV])
	_drop(made)


## It draws less than the main camera does, and never the water itself.
func _the_mirror_sees_a_shorter_world_and_never_the_water() -> void:
	var made := _aimed(EYE, LOOK, PLANE, true)
	if made.is_empty():
		return
	var mirror: Camera3D = made["mirror"]
	check(mirror.far < CAMERA_FAR,
		"the mirror sees %.0f units and the camera %.0f; a reflection of the far "
		% [mirror.far, CAMERA_FAR] + "sky is paid for twice and shows nothing")
	equal(mirror.cull_mask & WaterReflection.HIDDEN_LAYER, 0,
		"the mirror camera draws the layer the water is on, so the water reflects "
		+ "itself")
	check(mirror.cull_mask & ~WaterReflection.HIDDEN_LAYER != 0,
		"the mirror camera draws nothing at all")
	_drop(made)


## The three ways a frame is not worth drawing, each of which leaves the
## viewport un-updated -- which is the whole of the mirror costing nothing.
func _nothing_is_drawn_where_there_is_nothing_to_mirror() -> void:
	var wet := _aimed(EYE, LOOK, PLANE, true)
	if wet.is_empty():
		return
	var mirror: WaterReflection = wet["reflection"]
	check(mirror.is_drawn(), "the mirror was not drawn over open water")
	equal(mirror.frames_drawn, 1, "a drawn frame was not counted")

	# No water in the streamed window: most of this world.
	mirror.aim(wet["view"], FOV, PLANE, Vector2i(320, 180), false)
	check(not mirror.is_drawn(), "the mirror was drawn with no water on screen")
	equal(mirror.viewport().render_target_update_mode, SubViewport.UPDATE_DISABLED,
		"the mirror's viewport is still being redrawn with no water on screen")
	equal(mirror.frames_drawn, 1, "a frame that was not drawn was counted")

	# Under the plane: there is nothing over it to mirror.
	var sunk := Transform3D(Basis(), Vector3(EYE.x, PLANE - 1.0, EYE.z)) \
		.looking_at(LOOK, Vector3.UP)
	mirror.aim(sunk, FOV, PLANE, Vector2i(320, 180), true)
	check(not mirror.is_drawn(), "the mirror was drawn from under the water")

	# And switched off from outside, which is what a measurement does.
	mirror.enabled = false
	mirror.aim(wet["view"], FOV, PLANE, Vector2i(320, 180), true)
	check(not mirror.is_drawn(), "a disabled mirror was still drawn")
	_drop(wet)


## The mirror is drawn at its share of the window, and follows the dial.
func _the_mirror_follows_the_resolution_dial() -> void:
	var made := _aimed(EYE, LOOK, PLANE, true)
	if made.is_empty():
		return
	var mirror: WaterReflection = made["reflection"]
	var window := Vector2i(1152, 648)
	mirror.aim(made["view"], FOV, PLANE, window, true)
	equal(mirror.viewport().size, Vector2i(
		int(round(float(window.x) * WaterReflection.SCALE)),
		int(round(float(window.y) * WaterReflection.SCALE)),
	), "the mirror is not drawn at WaterReflection.SCALE of the window")
	check(WaterReflection.SCALE < 1.0,
		"the mirror is drawn at the window's full resolution, which is the whole "
		+ "of what the scale is for")
	mirror.scale = 0.25
	mirror.aim(made["view"], FOV, PLANE, window, true)
	equal(mirror.viewport().size, Vector2i(288, 162),
		"the mirror did not follow the resolution dial")
	_drop(made)


## The shader takes a mirror, and takes none by default.
##
## The default matters: --no-reflection builds no mirror at all and never sets
## the strength, so the branch the shader takes with no mirror has to be the one
## that never reads the sampler.
func _the_water_shader_takes_a_mirror_and_defaults_to_none() -> void:
	var shell := load("res://render/main.gd") as GDScript
	var code := String(shell.get_script_constant_map().get("WATER_SHADER", ""))
	check(code.contains("uniform sampler2D reflection_map"),
		"the water shader takes no reflection map")
	check(code.contains("uniform float reflection_amount = 0.0"),
		"the water shader's mirror strength does not default to none, so a run "
		+ "with no mirror would sample a texture that was never set")
	check(code.contains("if (reflection_amount > 0.0)"),
		"the water shader reads the mirror unconditionally")
	check(code.contains("1.0 - SCREEN_UV.x"),
		"the water shader does not undo the mirror camera's left-right flip")


# --- And none of it reaches the world ------------------------------------

func _the_world_is_byte_identical_with_and_without_the_mirror() -> void:
	var mirrored := _run_render_shell([])
	var flat := _run_render_shell(["--no-reflection"])
	equal(mirrored["exit_code"], 0,
		"render shell should exit 0 (output: %s)" % mirrored["output"])
	equal(flat["exit_code"], 0,
		"render shell should exit 0 (output: %s)" % flat["output"])

	var with_counts := _counts_from(mirrored["output"])
	var without_counts := _counts_from(flat["output"])
	check(not with_counts.is_empty(),
		"no counters from the shell: %s" % mirrored["output"])
	check(not without_counts.is_empty(),
		"no counters from the shell: %s" % flat["output"])
	if with_counts.is_empty() or without_counts.is_empty():
		return

	equal(without_counts["mirror"], 0, "--no-reflection still drew %d mirror frames"
		% without_counts["mirror"])
	equal(with_counts["tick"], EXPECTED_TICKS,
		"the shell should have run %d ticks" % EXPECTED_TICKS)

	check(with_counts["mirror"] > 0,
		"the run with the mirror drew %d mirror frames, so comparing it against a "
		% with_counts["mirror"] + "run with none shows nothing")

	var headless := Simulation.new(SEED)
	headless.world.place_observer(START_X, START_Z)
	headless.run(EXPECTED_TICKS)
	equal(_digest_from(mirrored["output"]), headless.world.digest(),
		"the shell with the mirror reached a different world from a headless run "
		+ "of seed %d at tick %d" % [SEED, EXPECTED_TICKS])
	equal(_digest_from(flat["output"]), _digest_from(mirrored["output"]),
		"the same seed reached different worlds with and without the mirror: "
		+ "reflecting the world is changing it")


# --- helpers -------------------------------------------------------------

## A mirror hung in the tree, aimed once at a main camera looking from `eye` at
## `look` through the plane at `plane`. Returns the pieces so a check can read
## them, and `_drop` takes them down again.
func _aimed(
	eye: Vector3, look: Vector3, plane: float, water_on_screen: bool
) -> Dictionary:
	# Not hung in a tree on purpose. Everything checked here is arithmetic on a
	# transform, and a mirror that needed a scene loaded before it could be shown
	# to be a mirror would be checked by a much weaker test.
	var host := Node3D.new()
	var view := Transform3D(Basis(), eye).looking_at(look, Vector3.UP)
	var reflection := WaterReflection.new()
	reflection.attach(host)
	reflection.aim(view, FOV, plane, Vector2i(320, 180), water_on_screen)
	return {
		"host": host,
		"view": view,
		"reflection": reflection,
		"mirror": reflection.camera(),
	}


func _drop(made: Dictionary) -> void:
	(made["host"] as Node).free()


func _run_render_shell(extra: Array) -> Dictionary:
	var output: Array[String] = []
	var args: Array = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", str(FIXED_FPS),
		"--quit-after", str(FRAMES),
		"--",
		"--seed", str(SEED),
		"--start", str(START_X), str(START_Z),
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
