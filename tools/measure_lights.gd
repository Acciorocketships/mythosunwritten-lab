extends SceneTree
## What the village lights cost: how many there are, and what drawing them adds
## to a frame.
##
##   ./tools/measure_lights.sh                 # seed 1234 at the origin
##   ./tools/measure_lights.sh --seed 7 --start -240 24
##
## Runs the render shell itself rather than a stand-in, so what is measured is
## the scene the game actually draws. It settles the world, samples frames with
## the lit windows in place, then deletes every window_glow node and its light
## and samples the same frames again -- so the two numbers differ by exactly the
## lit windows and by nothing else.
##
## Frame times on a machine with no GPU are software rasterisation and are not
## the game's frame rate. What carries across is the light count, the draw calls
## and the ratio between the two passes.

const WARM_FRAMES := 150
const SAMPLE_FRAMES := 150

var _shell: Node = null
var _frames := 0
var _phase := 0
var _last_usec := 0
var _times: Array[float] = []
var _with := {}
var _without := {}


func _initialize() -> void:
	_shell = load("res://render/main.tscn").instantiate()
	root.add_child(_shell)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	_frames += 1

	match _phase:
		0:
			if _frames >= WARM_FRAMES:
				_phase = 1
				_frames = 0
				_times = []
		1:
			_times.append(frame_ms)
			if _frames >= SAMPLE_FRAMES:
				_with = _summary()
				_strip_window_glows()
				_phase = 2
				_frames = 0
		2:
			# Let the frame settle after the deletions before sampling again.
			if _frames >= 30:
				_phase = 3
				_frames = 0
				_times = []
		3:
			_times.append(frame_ms)
			if _frames >= SAMPLE_FRAMES:
				_without = _summary()
				_report()
				return true
	return false


func _summary() -> Dictionary:
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for one in sorted:
		total += one
	return {
		"mean": total / float(sorted.size()),
		"median": sorted[sorted.size() / 2],
		"lights": _count(_shell, "OmniLight3D"),
		"panes": _count_named(_shell, "window_glow"),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	}


func _report() -> void:
	print("villages loaded   %d" % _villages())
	print("                   with lit windows   without")
	print("omni lights        %8d          %8d" % [_with["lights"], _without["lights"]])
	print("window panes       %8d          %8d" % [_with["panes"], _without["panes"]])
	print("draw calls         %8d          %8d" % [_with["draws"], _without["draws"]])
	print("objects in frame   %8d          %8d" % [_with["objects"], _without["objects"]])
	print("frame ms mean      %8.2f          %8.2f" % [_with["mean"], _without["mean"]])
	print("frame ms median    %8.2f          %8.2f" % [_with["median"], _without["median"]])
	var added: float = float(_with["median"]) - float(_without["median"])
	var lights: int = int(_with["lights"]) - int(_without["lights"])
	print("added by %d lit windows: %.2f ms per frame (%.4f ms each)" % [
		lights, added, added / maxf(1.0, float(lights)),
	])


func _villages() -> int:
	var world = _shell.get("_sim")
	if world == null:
		return 0
	return (world.world.settlement_streamer.loaded_keys() as Array).size()


func _strip_window_glows() -> void:
	for node in _find_named(_shell, "window_glow"):
		node.get_parent().remove_child(node)
		node.queue_free()


## Every node whose name carries `wanted`. Matched loosely because Godot renames
## the second and later children that share a name, and a village has twenty of
## them under one parent.
func _find_named(node: Node, wanted: String) -> Array[Node]:
	var found: Array[Node] = []
	if String(node.name).contains(wanted):
		found.append(node)
		return found
	for child in node.get_children():
		found.append_array(_find_named(child, wanted))
	return found


func _count_named(node: Node, wanted: String) -> int:
	return _find_named(node, wanted).size()


func _count(node: Node, class_wanted: String) -> int:
	var found := 1 if node.is_class(class_wanted) else 0
	for child in node.get_children():
		found += _count(child, class_wanted)
	return found
