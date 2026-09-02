extends SceneTree
## What the playing camera actually sees of a floating island, as numbers.
##
## The islands were reworked close up, and from a close-up they read as torn
## chunks of land. The camera the game is played from is neither close nor level:
## it stands well above the character and looks down, so most of what it sees of
## an island is the *top surface in plan* and only a sliver of the cliff. A
## silhouette lever that works at eye level can be invisible from up there. This
## tool states the difference in numbers rather than in adjectives.
##
##   ./tools/measure_island_read.sh --seed 1234 --start -329.8 -254.1
##
## It reports two blocks.
##
## **The camera.** Where it stands relative to the character, how far that is,
## how far it looks down, and how wide its view is. Where it stands and what it
## aims at are read out of the render shell's own script rather than restated
## here, so the numbers cannot drift from the camera the game uses; the field of
## view is read off a fresh Camera3D, because the shell leaves it at the
## engine's default unless a capture overrides it.
##
## **Each island in view.** For every walkable island whose centre falls inside
## the frustum: how far it is, how high it rides in frame, how wide it is in
## degrees and in pixels of a 1152x648 frame, and then four shape readings that
## are the levers this task pulls, each measured *as the camera sees it*:
##
## * **outline ragged** -- how much the plan outline departs from the circle of
##   its own mean reach, as a share of that mean, and the same in pixels. This is
##   the wobble of the silhouette edge.
## * **outline bay** -- the deepest inward turn of the boundary: one minus the
##   smallest reach over the largest. A lid has none.
## * **relief seen** -- how many pixels the summit stands above the rim once the
##   camera's downward angle has foreshortened it, against the island's width in
##   pixels. This is what says whether the top reads as a hill or as a flat face.
## * **cliff seen** -- how many pixels of the rim cliff are visible under the
##   near edge of the top, which is the only part of the island's thickness the
##   camera gets.
##
## Nothing here changes the world; it builds islands the same way every other
## reader does and measures them.

## The frame the report's pixel numbers are quoted in. The render shell's window
## size, so a pixel here is a pixel there.
const FRAME_WIDTH := 1152.0
const FRAME_HEIGHT := 648.0

## How many directions the outline is read in for the raggedness numbers. Finer
## than the mesher's fan, because this is measuring the fine crenellation and a
## coarse read would step straight over it.
const OUTLINE_DIRECTIONS := 180

## How far out from the observer an island has to be to count as "in view" at
## all. Past this the fog has it and no silhouette lever can be judged on it.
const VIEW_LIMIT := 220.0

## How the island's summit is found: rings out to the rim, this many directions
## on each. The high point of a two-octave heightfield is not at the middle, and
## reading the middle instead would understate the relief the camera sees.
const SUMMIT_RINGS := 6
const SUMMIT_DIRECTIONS := 16


func _initialize() -> void:
	var shell: Dictionary = load("res://render/main.gd").get_script_constant_map()
	var options := _parse_args(OS.get_cmdline_user_args(), shell)
	var sim := Simulation.new(options["seed"])
	if options["start"]:
		sim.world.place_observer(options["start_x"], options["start_z"])
	sim.run(options["ticks"])

	var observer := sim.world.observers()[0]
	var stand := Vector3(
		observer.x, sim.world.observer_surface_height(), observer.y
	)
	var offset: Vector3 = options["camera"]
	var aim: float = options["aim"]
	var fov: float = options["fov"]
	var eye := stand + offset
	var target := stand + Vector3(0.0, aim, 0.0)
	var look := target - eye

	var horizontal := sqrt(look.x * look.x + look.z * look.z)
	var pitch := rad_to_deg(atan2(-look.y, horizontal))
	var half_up := tan(deg_to_rad(fov * 0.5))
	var half_side := half_up * FRAME_WIDTH / FRAME_HEIGHT

	print("camera-stand at=%.2f,%.2f,%.2f" % [stand.x, stand.y, stand.z])
	print("camera-eye at=%.2f,%.2f,%.2f" % [eye.x, eye.y, eye.z])
	print("camera-offset back=%.2f up=%.2f" % [offset.z, offset.y])
	print("camera-range distance=%.2f pitch_down_deg=%.2f aim_lift=%.2f" % [
		offset.length(), pitch, aim,
	])
	print("camera-lens fov_vertical_deg=%.2f fov_horizontal_deg=%.2f frame=%dx%d" % [
		fov, 2.0 * rad_to_deg(atan(half_side)), int(FRAME_WIDTH), int(FRAME_HEIGHT),
	])
	print("camera-scale px_per_deg_h=%.2f px_per_deg_v=%.2f" % [
		FRAME_WIDTH / (2.0 * rad_to_deg(atan(half_side))), FRAME_HEIGHT / fov,
	])

	var basis := Transform3D().looking_at(look, Vector3.UP).basis
	var to_eye := Transform3D(basis, eye).affine_inverse()

	var seen := 0
	for band in FloatingIsland.WALKABLE_BANDS:
		for island in sim.world.island_field.islands_near(
			band, observer.x, observer.y, VIEW_LIMIT
		):
			var line := _read(island, to_eye, half_up, half_side, pitch)
			if line == "":
				continue
			seen += 1
			print(line)
	print("islands-in-view count=%d" % seen)
	quit(0)


func _summit(island: FloatingIsland) -> float:
	var high := island.rim_height
	for ring in range(1, SUMMIT_RINGS + 1):
		var ratio := float(ring) / float(SUMMIT_RINGS + 1)
		for at in SUMMIT_DIRECTIONS:
			var angle := TAU * float(at) / float(SUMMIT_DIRECTIONS)
			var reach := island.outline_radius(angle) * ratio
			high = maxf(high, island.base_top_height_at(
				island.centre_x + cos(angle) * reach,
				island.centre_z + sin(angle) * reach,
			))
	return high


## One island, as the camera sees it, or "" when its centre is out of frame.
func _read(
	island: FloatingIsland,
	to_eye: Transform3D,
	half_up: float,
	half_side: float,
	pitch: float,
) -> String:
	var summit := _summit(island)
	var middle := to_eye * Vector3(island.centre_x, island.rim_height, island.centre_z)
	var forward := -middle.z
	if forward <= 1.0:
		return ""
	var across := middle.x / (forward * half_side)
	var up := middle.y / (forward * half_up)
	if absf(across) > 1.4 or absf(up) > 1.4:
		return ""

	# The outline, read finely enough to catch the crenellation.
	var reaches := PackedFloat32Array()
	var total := 0.0
	var least := INF
	var most := 0.0
	for at in OUTLINE_DIRECTIONS:
		var reach := island.outline_radius(TAU * float(at) / float(OUTLINE_DIRECTIONS))
		reaches.append(reach)
		total += reach
		least = minf(least, reach)
		most = maxf(most, reach)
	var mean := total / float(OUTLINE_DIRECTIONS)
	var spread := 0.0
	for reach in reaches:
		spread += absf(reach - mean)
	spread /= float(OUTLINE_DIRECTIONS)

	# Degrees per world unit at the island's distance, and pixels per degree.
	var deg_per_unit := rad_to_deg(1.0 / forward)
	var px_h := FRAME_WIDTH / (2.0 * rad_to_deg(atan(half_side)))
	var px_v := FRAME_HEIGHT / (2.0 * rad_to_deg(atan(half_up)))
	var width_px := 2.0 * mean * deg_per_unit * px_h

	# The summit's rise, foreshortened by the camera's downward angle: a camera
	# looking straight down sees none of a hill's height at all.
	var rise := summit - island.rim_height
	var rise_px := rise * cos(deg_to_rad(pitch)) * deg_per_unit * px_v
	# The cliff under the near edge, foreshortened the other way: a camera
	# looking straight down sees all of the top and none of the cliff.
	var cliff_px := island.rim_thickness * cos(deg_to_rad(pitch)) * deg_per_unit * px_v

	return (
		"island band=%d cell=%d,%d distance=%.1f frame_x=%+.2f frame_y=%+.2f"
		+ " radius=%.1f width_px=%.0f ragged=%.3f ragged_px=%.1f bay=%.3f"
		+ " relief=%.1f relief_px=%.0f relief_over_width=%.3f cliff_px=%.1f"
	) % [
		island.band, island.cell.x, island.cell.y, forward, across, up,
		island.radius, width_px, spread / mean, spread * deg_per_unit * px_h,
		1.0 - least / most,
		rise, rise_px, rise_px / maxf(1.0, width_px), cliff_px,
	]


func _parse_args(args: PackedStringArray, shell: Dictionary) -> Dictionary:
	var lens := Camera3D.new()
	var options := {
		"seed": 1234, "ticks": 0, "start": false, "start_x": 0.0, "start_z": 0.0,
		"camera": shell["CAMERA_OFFSET"], "aim": shell["CAMERA_AIM_LIFT"],
		"fov": lens.fov,
	}
	lens.free()
	var i := 0
	while i < args.size():
		match args[i]:
			"--seed":
				options["seed"] = args[i + 1].to_int()
				i += 1
			"--ticks":
				options["ticks"] = args[i + 1].to_int()
				i += 1
			"--start":
				options["start"] = true
				options["start_x"] = args[i + 1].to_float()
				options["start_z"] = args[i + 2].to_float()
				i += 2
			"--camera":
				options["camera"] = Vector3(
					args[i + 1].to_float(), args[i + 2].to_float(), args[i + 3].to_float()
				)
				i += 3
			"--aim":
				options["aim"] = args[i + 1].to_float()
				i += 1
			"--fov":
				options["fov"] = args[i + 1].to_float()
				i += 1
		i += 1
	return options
