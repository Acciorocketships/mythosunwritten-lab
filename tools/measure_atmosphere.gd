extends SceneTree
## What the lighting and atmosphere stack costs, on the scene the game actually
## draws, at the streaming radius.
##
##   ./tools/measure_atmosphere.sh                   # seed 1234 at the origin
##   ./tools/measure_atmosphere.sh --seed 1234 --start -216 -504
##
## Runs the render shell itself rather than a stand-in, so what is measured is
## the frame the game draws with everything else -- the terrain, the islands, the
## villages, the props and the grass -- already in it.
##
## The stack is taken apart one piece at a time and put back, in this order:
##
##   full          everything on
##   -motes        the drifting particles hidden
##   -warm lights  every OmniLight3D the glowing tags carry, removed
##   -depth field  the miniature depth of field switched off
##   -bloom        the glow switched off
##   bare          all four off together
##
## Each row is measured over the same number of frames after the same settling
## time, so the differences between the rows are the differences between the
## pieces. The last row is the check: it should land near the sum of the four
## savings, and where it does not, the pieces are interacting.
##
## Frame times on a machine with no GPU are software rasterisation and are not
## the game's frame rate. What carries across is the ordering of the rows, the
## share of the frame each piece takes, the light and draw-call counts, and the
## fact that the whole stack is a bounded and known cost rather than an unknown
## one.

const WARM_FRAMES := 150
const SAMPLE_FRAMES := 120
const SETTLE_FRAMES := 30

var _shell: Node = null
var _frames := 0
var _step := 0
var _settling := true
var _last_usec := 0
var _times: Array[float] = []
var _rows := []
var _stripped_lights := []

## What is switched off for each row, in the order they are measured.
const PLAN := [
	{"label": "full", "off": []},
	{"label": "-motes", "off": ["motes"]},
	{"label": "-warm lights", "off": ["lights"]},
	{"label": "-depth field", "off": ["dof"]},
	{"label": "-bloom", "off": ["bloom"]},
	{"label": "bare", "off": ["motes", "lights", "dof", "bloom"]},
]


func _initialize() -> void:
	_shell = load("res://render/main.tscn").instantiate()
	root.add_child(_shell)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	_frames += 1
	# Held still for the whole measurement, and set here rather than at start-up
	# because the shell's own _ready() runs on the first frame of the tree and
	# would overwrite it. Without this the observer walks while the rows are
	# being taken, so the later rows price a different view from the earlier ones
	# and the differences between them mean nothing.
	_shell.set("_paused", true)

	if _settling:
		if _frames >= (WARM_FRAMES if _rows.is_empty() else SETTLE_FRAMES):
			_settling = false
			_frames = 0
			_times = []
		return false

	_times.append(frame_ms)
	if _frames < SAMPLE_FRAMES:
		return false

	_rows.append(_summary(PLAN[_step]["label"]))
	_step += 1
	if _step >= PLAN.size():
		_report()
		return true
	_restore()
	for piece in PLAN[_step]["off"]:
		_switch_off(piece)
	_settling = true
	_frames = 0
	return false


func _summary(label: String) -> Dictionary:
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for one in sorted:
		total += one
	return {
		"label": label,
		"mean": total / float(sorted.size()),
		"median": sorted[sorted.size() / 2],
		"lights": _count(_shell, "OmniLight3D"),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	}


func _atmosphere():
	return _shell.get("_atmosphere")


func _switch_off(piece: String) -> void:
	var layer = _atmosphere()
	if layer == null:
		return
	match piece:
		"motes":
			layer.motes().view().visible = false
		"lights":
			for node in _find_class(_shell, "OmniLight3D"):
				var parent := node.get_parent()
				_stripped_lights.append({"node": node, "parent": parent})
				parent.remove_child(node)
		"dof":
			var attributes := layer.camera_attributes() as CameraAttributesPractical
			attributes.dof_blur_near_enabled = false
			attributes.dof_blur_far_enabled = false
		"bloom":
			layer.environment().glow_enabled = false


func _restore() -> void:
	var layer = _atmosphere()
	if layer == null:
		return
	layer.motes().view().visible = true
	# Back where each came from: a light is a child of the thing that glows, and
	# putting it anywhere else would price a different scene.
	for taken in _stripped_lights:
		var node: Node = taken["node"]
		var parent: Node = taken["parent"]
		if is_instance_valid(node) and is_instance_valid(parent):
			parent.add_child(node)
	_stripped_lights = []
	var attributes := layer.camera_attributes() as CameraAttributesPractical
	attributes.dof_blur_near_enabled = true
	attributes.dof_blur_far_enabled = true
	layer.environment().glow_enabled = true


func _report() -> void:
	var world = _shell.get("_sim")
	var motes: Vector2i = _atmosphere().mote_counts() if _atmosphere() != null else Vector2i.ZERO
	print("seed              %d" % world.world.world_seed)
	print("observer          %.1f %.1f (%s)" % [
		world.world.observer_x, world.world.observer_z, world.world.observer_biome(),
	])
	print("chunks loaded     %d" % (world.world.terrain_streamer.loaded_keys() as Array).size())
	print("ticks run         %d (has to be small: the world is held still)"
		% world.world.tick)
	print("motes drawn       %d of %d pooled" % [motes.y, motes.x])
	print("")
	print("%-14s %9s %9s %9s %8s %8s" % [
		"row", "mean ms", "median", "vs full", "lights", "draws",
	])
	var full: float = float(_rows[0]["median"])
	for row in _rows:
		print("%-14s %9.2f %9.2f %9.2f %8d %8d" % [
			row["label"], row["mean"], row["median"],
			float(row["median"]) - full, row["lights"], row["draws"],
		])
	var pieces := 0.0
	for at in range(1, _rows.size() - 1):
		pieces += full - float(_rows[at]["median"])
	var bare: float = full - float(_rows[_rows.size() - 1]["median"])
	print("")
	print("the four pieces separately save %.2f ms; all four at once save %.2f ms"
		% [pieces, bare])


## Every node of a class under a root.
func _find_class(node: Node, class_wanted: String) -> Array[Node]:
	var found: Array[Node] = []
	if node.is_class(class_wanted):
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_class(child, class_wanted))
	return found


func _count(node: Node, class_wanted: String) -> int:
	return _find_class(node, class_wanted).size()
