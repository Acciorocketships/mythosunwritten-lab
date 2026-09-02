extends SceneTree
## What the water's reflection costs, on the scene the game actually draws.
##
##   ./tools/measure_reflection.sh --seed 1234 --start -10 -466 --camera 19 0.33 37.6
##
## Built on the same shape as tools/measure_atmosphere.gd, and for the same
## reason: the thing priced is the frame the game draws, with the terrain, the
## village, the props and the grass already in it, and the world is held still
## for the whole measurement so every row prices the same view.
##
## The rows take the mirror apart by the two dials that decide what it costs:
##
##   off             no mirror at all -- the viewport is not updated and the
##                   water shader's mirror branch is never taken
##   quarter         the mirror drawn at a quarter of the window per side
##   half            the shipped setting, WaterReflection.SCALE
##   three-quarter   drawn at three quarters
##   full            drawn at the window's own resolution
##
## Switching the mirror off is done by disabling the viewport's updates and
## setting the shader's `reflection_amount` to zero, which is exactly what
## --no-reflection does at start-up -- so the "off" row is the frame the game
## drew before this feature existed.

const WARM_FRAMES := 150
const SAMPLE_FRAMES := 120
const SETTLE_FRAMES := 30

## The resolution scales measured, as a share of the window per side. The
## shipped one is WaterReflection.SCALE and is named in the output.
const PLAN := [
	{"label": "off", "scale": 0.0},
	{"label": "quarter", "scale": 0.25},
	{"label": "half", "scale": 0.5},
	{"label": "three-quarter", "scale": 0.75},
	{"label": "full", "scale": 1.0},
]

var _shell: Node = null
var _frames := 0
var _step := 0
var _settling := true
var _last_usec := 0
var _times: Array[float] = []
var _rows := []
## The mirror strength the shell was built with, read off the material before
## the first row switches it off.
var _amount := 1.0


func _initialize() -> void:
	_shell = load("res://render/main.tscn").instantiate()
	root.add_child(_shell)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	_frames += 1
	# Held still for the whole measurement, for the same reason the atmosphere
	# tool does it: a walking observer would price a different view in each row.
	_shell.set("_paused", true)

	if _settling:
		if _frames == 1:
			if _step == 0:
				var first := _shell.get("_water_material") as ShaderMaterial
				if first != null:
					_amount = float(first.get_shader_parameter("reflection_amount"))
			_apply(PLAN[_step])
		if _frames >= (WARM_FRAMES if _rows.is_empty() else SETTLE_FRAMES):
			_settling = false
			_frames = 0
			_times = []
		return false

	_times.append(frame_ms)
	if _frames < SAMPLE_FRAMES:
		return false

	_rows.append(_summary(PLAN[_step]))
	_step += 1
	if _step >= PLAN.size():
		_report()
		return true
	_settling = true
	_frames = 0
	return false


## Put the mirror at one of the plan's settings. Scale zero is the whole of
## switching it off: the viewport stops being redrawn and the shader stops
## taking its mirror branch.
func _apply(row: Dictionary) -> void:
	var mirror = _shell.get("_reflection")
	var material := _shell.get("_water_material") as ShaderMaterial
	if mirror == null or material == null:
		return
	var scale: float = row["scale"]
	if scale <= 0.0:
		material.set_shader_parameter("reflection_amount", 0.0)
		mirror.enabled = false
		return
	material.set_shader_parameter("reflection_amount", _amount)
	mirror.enabled = true
	mirror.scale = scale


func _summary(row: Dictionary) -> Dictionary:
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for one in sorted:
		total += one
	var mirror = _shell.get("_reflection")
	return {
		"label": row["label"],
		"scale": row["scale"],
		"mean": total / float(sorted.size()),
		"median": sorted[sorted.size() / 2],
		"size": Vector2i.ZERO if mirror == null else mirror.viewport().size,
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	}


func _report() -> void:
	var world = _shell.get("_sim")
	var mirror = _shell.get("_reflection")
	print("seed              %d" % world.world.world_seed)
	print("observer          %.1f %.1f (%s)" % [
		world.world.observer_x, world.world.observer_z, world.world.observer_biome(),
	])
	print("chunks loaded     %d" % (world.world.terrain_streamer.loaded_keys() as Array).size())
	print("ticks run         %d (has to be small: the world is held still)"
		% world.world.tick)
	print("window            %dx%d" % [
		_shell.get_viewport().size.x, _shell.get_viewport().size.y,
	])
	print("shipped scale     %.2f (WaterReflection.SCALE)" % WaterReflection.SCALE)
	print("mirror far plane  %.0f world units (the camera's own is %.0f)" % [
		WaterReflection.FAR, (_shell.get("_camera") as Camera3D).far,
	])
	print("mirror strength   %.2f" % _amount)
	print("mirror frames     %d" % (0 if mirror == null else mirror.frames_drawn))
	print("")
	print("%-15s %9s %9s %9s %11s %8s" % [
		"row", "mean ms", "median", "vs off", "mirror px", "draws",
	])
	var off: float = float(_rows[0]["median"])
	for row in _rows:
		print("%-15s %9.2f %9.2f %9.2f %11s %8d" % [
			row["label"], row["mean"], row["median"],
			float(row["median"]) - off,
			("-" if float(row["scale"]) <= 0.0
				else "%dx%d" % [row["size"].x, row["size"].y]),
			row["draws"],
		])
