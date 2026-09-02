extends SceneTree
## Measure installed pack models: the size of each one as the artist drew it.
##
##   ./tools/measure_models.sh                      # every installed model
##   ./tools/measure_models.sh Tree_1 Rock_2        # only names containing these
##
## Prints one line per model: path, then width x height x depth in world units,
## then the y of its lowest point. That last number matters -- a model whose
## origin is not at its feet stands sunk into or floating above the ground.
##
## This exists because `scene_height` on a table row has to come from somewhere.
## Generation asks for a fir seven units tall; the row has to say how tall the
## model is as drawn so the renderer can divide. Nobody should be guessing that.

func _initialize() -> void:
	var wanted := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		wanted.append(arg.to_lower())

	var paths := _models("res://assets")
	paths.sort()
	var shown := 0
	for path in paths:
		if wanted.size() > 0:
			var hit := false
			for want in wanted:
				if path.to_lower().contains(want):
					hit = true
					break
			if not hit:
				continue
		var packed: PackedScene = load(path)
		if packed == null:
			print("%-96s  UNLOADABLE" % path)
			continue
		var node := packed.instantiate()
		var box := _aabb(node, Transform3D.IDENTITY)
		node.free()
		if box.size == Vector3.ZERO:
			print("%-96s  NO GEOMETRY" % path)
			continue
		shown += 1
		print("%-96s  %6.3f x %6.3f x %6.3f   floor %+6.3f" % [
			path, box.size.x, box.size.y, box.size.z, box.position.y,
		])
	print("measured %d of %d models" % [shown, paths.size()])
	quit()


## Every model file under a directory, recursively.
func _models(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			found.append_array(_models(full))
		elif name.get_extension().to_lower() in ["gltf", "glb"]:
			found.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return found


## The box every mesh under a node fills, in the node's own space.
func _aabb(node: Node, at: Transform3D) -> AABB:
	var here := at
	if node is Node3D:
		here = at * (node as Node3D).transform
	var box := AABB()
	var started := false
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			box = here * mesh.get_aabb()
			started = true
	for child in node.get_children():
		var child_box := _aabb(child, here)
		if child_box.size == Vector3.ZERO:
			continue
		box = child_box if not started else box.merge(child_box)
		started = true
	return box
