extends SceneTree
## What a village is made of, and what that costs to draw.
##
##   ./tools/measure_village.sh                      # eight seeds, headless
##   ./tools/measure_village.sh --seed 1234
##   xvfb-run -a ./tools/measure_village.sh --rendered --seed 1234 --start -100 34
##
## The default pass is headless and exact. It asks the settlement field what a
## village places, asks the mapping table what each of those tags resolves to,
## and adds up the nodes, the surfaces and the triangles. Nothing is sampled and
## no frame is drawn, so the numbers are the same on any machine -- which is what
## makes "this swap costs a village N more triangles" a fact rather than a
## reading off a software rasteriser.
##
## `--rendered` runs render/main.tscn itself and reports draw calls, objects and
## frame times beside the same counts, for when the question is the frame rather
## than the content. On a machine with no GPU those times are software
## rasterisation and are a ratio, not a frame rate.
##
## It exists to answer one question with a number: whether swapping a tag's model
## for a heavier one costs a village more than the world can stream. Run it, edit
## the table, run it again -- the two outputs differ by exactly the swap.

## Seeds sampled by the headless pass when none is named, and how far out from
## each origin villages are counted. Eight seeds is what tools/_light_cost.gd
## uses for the same job, so the two are comparable.
const SEEDS := [1234, 7, 3, 19, 42, 101, 5, 11]
const CELL_REACH := 2

const WARM_FRAMES := 45
const SAMPLE_FRAMES := 15

var _shell: Node = null
var _frames := 0
var _phase := 0
var _last_usec := 0
var _times: Array[float] = []


func _initialize() -> void:
	var rendered := false
	var seeds: Array[int] = []
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--rendered":
			rendered = true
		elif args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			seeds.append(args[i + 1].to_int())
	if rendered:
		_shell = load("res://render/main.tscn").instantiate()
		root.add_child(_shell)
		_last_usec = Time.get_ticks_usec()
		return
	_count(seeds if seeds.size() > 0 else SEEDS)
	quit()


# --- The headless pass ---------------------------------------------------

## Add up what the villages on these seeds place, and what each tag costs.
func _count(seeds: Array) -> void:
	var per_tag := {}
	var villages := 0
	for world_seed: int in seeds:
		var field := TerrainQuery.for_seed(world_seed).settlement_field
		for cx in range(-CELL_REACH, CELL_REACH + 1):
			for cz in range(-CELL_REACH, CELL_REACH + 1):
				var site := field.settlement_in_cell(Vector2i(cx, cz))
				if site == null:
					continue
				villages += 1
				for building in site.buildings:
					_tally(per_tag, String(building["tag"]))
				for prop in site.props:
					_tally(per_tag, String(prop["tag"]))
				for glow in site.glows:
					_tally(per_tag, String(glow["tag"]))
	if villages == 0:
		print("no villages on those seeds")
		return

	print("%d villages over %d seed(s)" % [villages, seeds.size()])
	print("")
	print("%-16s %8s %8s %9s %11s %13s" % [
		"tag", "placed", "meshes", "surfaces", "triangles", "tris/village",
	])
	var names := per_tag.keys()
	names.sort()
	var totals := {"placed": 0, "meshes": 0, "surfaces": 0, "tris": 0}
	for tag: String in names:
		var placed: int = per_tag[tag]
		var one := _weigh_tag(tag)
		var meshes: int = int(one["meshes"]) * placed
		var surfaces: int = int(one["surfaces"]) * placed
		var tris: int = int(one["tris"]) * placed
		totals["placed"] = int(totals["placed"]) + placed
		totals["meshes"] = int(totals["meshes"]) + meshes
		totals["surfaces"] = int(totals["surfaces"]) + surfaces
		totals["tris"] = int(totals["tris"]) + tris
		print("%-16s %8d %8d %9d %11d %13.0f" % [
			tag, placed, meshes, surfaces, tris, float(tris) / float(villages),
		])
	print("%-16s %8d %8d %9d %11d %13.0f" % [
		"ALL", totals["placed"], totals["meshes"], totals["surfaces"], totals["tris"],
		float(totals["tris"]) / float(villages),
	])
	print("")
	print("%-16s %8s %8s %9s %11s" % ["tag", "", "meshes", "surfaces", "triangles"])
	for tag: String in names:
		var one := _weigh_tag(tag)
		print("%-16s %8s %8d %9d %11d   <- one of them" % [
			tag, "", one["meshes"], one["surfaces"], one["tris"],
		])


func _tally(into: Dictionary, tag: String) -> void:
	into[tag] = int(into.get(tag, 0)) + 1


## What one copy of a tag's visual is made of: mesh nodes, surfaces, and the
## triangles of the top level of detail.
func _weigh_tag(tag: String) -> Dictionary:
	var node := AssetLibrary.build(tag)
	var seen := {"meshes": 0, "surfaces": 0, "tris": 0}
	if node != null:
		_weigh(node, seen)
		node.free()
	return seen


# --- The rendered pass ---------------------------------------------------

func _process(_delta: float) -> bool:
	if _shell == null:
		return true
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	_frames += 1
	if _phase == 0:
		if _frames % 20 == 0:
			print("settling %d/%d" % [_frames, WARM_FRAMES])
		if _frames >= WARM_FRAMES:
			_phase = 1
			_frames = 0
	else:
		_times.append(frame_ms)
		if _frames >= SAMPLE_FRAMES:
			_report()
			return true
	return false


func _report() -> void:
	var sim = _shell.get("_sim")
	var villages := 0 if sim == null \
		else (sim.world.settlement_streamer.loaded_keys() as Array).size()
	var whole := {"meshes": 0, "surfaces": 0, "tris": 0}
	_weigh(_shell, whole)
	var sorted := _times.duplicate()
	sorted.sort()
	var sum := 0.0
	for one in sorted:
		sum += one
	print("villages loaded    %d" % villages)
	print("whole scene        %d meshes, %d surfaces, %d triangles" % [
		whole["meshes"], whole["surfaces"], whole["tris"],
	])
	print("draw calls         %d" % Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("objects in frame   %d" % Performance.get_monitor(
		Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("primitives/frame   %d" % Performance.get_monitor(
		Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("frame ms mean      %.2f" % (sum / float(sorted.size())))
	print("frame ms median    %.2f" % sorted[sorted.size() / 2])


# --- Shared ---------------------------------------------------------------

## Meshes, surfaces and top-level-of-detail triangles under a node.
func _weigh(node: Node, into: Dictionary) -> void:
	if node is MeshInstance3D:
		_weigh_mesh((node as MeshInstance3D).mesh, 1, into)
	elif node is MultiMeshInstance3D:
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		if multi != null:
			_weigh_mesh(multi.mesh, multi.instance_count, into)
	for child in node.get_children():
		_weigh(child, into)


func _weigh_mesh(mesh: Mesh, copies: int, into: Dictionary) -> void:
	if mesh == null:
		return
	into["meshes"] = int(into["meshes"]) + 1
	for surface in mesh.get_surface_count():
		into["surfaces"] = int(into["surfaces"]) + 1
		var arrays := mesh.surface_get_arrays(surface)
		var tris := 0
		if arrays[Mesh.ARRAY_INDEX] != null:
			tris = arrays[Mesh.ARRAY_INDEX].size() / 3
		elif arrays[Mesh.ARRAY_VERTEX] != null:
			tris = arrays[Mesh.ARRAY_VERTEX].size() / 3
		into["tris"] = int(into["tris"]) + tris * copies
