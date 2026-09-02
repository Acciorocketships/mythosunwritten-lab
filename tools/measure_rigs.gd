extends SceneTree
## Measure every rigged model in the installed character packs, and answer the
## one question the whole character phase rests on: is it one skeleton or many?
##
##   ./tools/measure_rigs.sh                # every rigged model, every clip file
##   ./tools/measure_rigs.sh Skeleton       # only paths containing "Skeleton"
##
## Three sections:
##   RIGGED MODELS  one line per model with a Skeleton3D under it -- file,
##                  triangles, height in metres as drawn, the y of its lowest
##                  point, bone count, and a short hash of its skeleton.
##   SKELETONS      the distinct skeletons, by that hash, with the models that
##                  carry each. Two models share a skeleton when, and only when,
##                  their hash matches -- the bone names and each bone's parent
##                  are compared, not the pack name, not the file name, and not
##                  the artist's word for it.
##   CLIP FILES     every file carrying animation clips, with the skeleton it
##                  drives and the clips it ships.
##
## The hash is over the SET of "bone<parent" pairs, sorted, deliberately not
## over the glTF node order. Order differs file to file for the same rig -- the
## six adventurers list the same 23 bones in six different orders -- and an
## animation track addresses a bone by name, never by index, so order is not
## part of what "the same skeleton" means.
##
## A second, finer hash covers the REST POSE: each bone's rest position, rounded
## to a millimetre. Two rigs can agree on every bone name and still be different
## sizes, and a clip carries bone positions, so a clip authored for a taller rig
## stretches a shorter one. Name-identical but rest-different rigs print as the
## same "skeleton" and a different "pose" -- which is the honest answer.
##
## Nothing here reads or writes the simulation. This is a measurement of files
## on disk, run before anything is built on top of them.


func _initialize() -> void:
	var wanted := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		wanted.append(arg.to_lower())

	var paths := _models("res://assets")
	paths.sort()

	# hash -> {"pairs": PackedStringArray, "models": PackedStringArray}
	var skeletons := {}
	var clip_files := []
	var rows := []

	for path in paths:
		if not _wanted(path, wanted):
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			continue
		var node := packed.instantiate()

		var skel := _first_skeleton(node)
		var clips := _clips(node)
		var key := "-"

		if skel != null:
			var pairs := _hierarchy(skel)
			key = _fingerprint(pairs)
			if not skeletons.has(key):
				skeletons[key] = {"pairs": pairs, "models": PackedStringArray()}
			var pose := _rest_fingerprint(skel)
			var box := _rest_bounds(node, Transform3D.IDENTITY)
			var tris := _triangles(node)
			if tris > 0:
				skeletons[key]["models"].append(path)
				rows.append({
					"path": path, "tris": tris, "height": box.size.y,
					"floor": box.position.y, "bones": skel.get_bone_count(),
					"skel": key, "pose": pose,
				})
		if clips.size() > 0:
			clip_files.append({
				"path": path, "skel": key,
				"pose": "-" if skel == null else _rest_fingerprint(skel),
				"clips": clips,
			})

		node.free()

	print("RIGGED MODELS")
	print("  %-70s %7s %8s %8s %6s  %-8s %s"
		% ["file", "tris", "height", "floor", "bones", "skeleton", "pose"])
	for row in rows:
		print("  %-70s %7d %7.3fm %+7.3fm %6d  %-8s %s" % [
			_short(row["path"]), row["tris"], row["height"], row["floor"],
			row["bones"], row["skel"], row["pose"],
		])
	print("  %d rigged models" % rows.size())
	print("")

	print("SKELETONS  (bone name and parent, compared as a set)")
	for key in skeletons:
		var entry: Dictionary = skeletons[key]
		var models: PackedStringArray = entry["models"]
		if models.is_empty():
			continue
		var pairs: PackedStringArray = entry["pairs"]
		print("  %s  %d bones, %d models" % [key, pairs.size(), models.size()])
		for m in models:
			print("      %s" % _short(m))
		print("      bones: %s" % ", ".join(pairs))
	print("")

	print("CLIP FILES")
	for f in clip_files:
		var clips: PackedStringArray = f["clips"]
		print("  %-70s skeleton %s pose %s  %d clips"
			% [_short(f["path"]), f["skel"], f["pose"], clips.size()])
		print("      %s" % ", ".join(clips))
	print("")

	# The single fact everything downstream rests on, printed as a verdict so a
	# reader does not have to compare hashes by eye.
	var used := 0
	for key in skeletons:
		if not (skeletons[key]["models"] as PackedStringArray).is_empty():
			used += 1
	var poses := {}
	for row in rows:
		poses[row["pose"]] = true
	print("VERDICT: %d rigged models, %d distinct skeleton%s by bone name, %d by rest pose" % [
		rows.size(), used, "" if used == 1 else "s", poses.size(),
	])
	quit()


func _wanted(path: String, wanted: PackedStringArray) -> bool:
	if wanted.is_empty():
		return true
	for want in wanted:
		if path.to_lower().contains(want):
			return true
	return false


## Every bone as "name<parent", sorted. Sorting is the point: it makes the
## result independent of the order the exporter happened to write the bones in.
func _hierarchy(skel: Skeleton3D) -> PackedStringArray:
	var pairs := PackedStringArray()
	for i in skel.get_bone_count():
		var parent := skel.get_bone_parent(i)
		pairs.append("%s<%s" % [
			skel.get_bone_name(i),
			"" if parent < 0 else skel.get_bone_name(parent),
		])
	pairs.sort()
	return pairs


## A short, stable name for a skeleton. Same bones with the same parents ->
## same string; one renamed or re-parented bone -> a different string.
func _fingerprint(pairs: PackedStringArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("\n".join(pairs)).to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 8)


## A short, stable name for the rest pose: every bone's rest position rounded
## to a millimetre, in bone-name order so the exporter's ordering cannot move it.
func _rest_fingerprint(skel: Skeleton3D) -> String:
	var lines := PackedStringArray()
	for i in skel.get_bone_count():
		var o := skel.get_bone_rest(i).origin
		lines.append("%s:%.3f,%.3f,%.3f" % [skel.get_bone_name(i), o.x, o.y, o.z])
	lines.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("\n".join(lines)).to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 8)


func _short(path: String) -> String:
	return path.replace("res://assets/", "")


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


func _first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _first_skeleton(child)
		if found != null:
			return found
	return null


func _clips(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is AnimationPlayer:
		for name in (node as AnimationPlayer).get_animation_list():
			if name != "RESET":
				out.append(name)
	for child in node.get_children():
		out.append_array(_clips(child))
	return out


func _triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			total += mesh.get_faces().size() / 3
	for child in node.get_children():
		total += _triangles(child)
	return total


## The box every mesh under a node fills, in the node's own space, measured from
## the vertices themselves rather than from Mesh.get_aabb().
##
## Mesh.get_aabb() is a stored box, and for a skinned mesh an importer is free to
## pad it so it still holds the mesh once the skeleton bends. get_faces() returns
## the rest-pose vertices, which is the definition of "how tall is this model as
## drawn" and so the number a table row would divide by. For these packs the two
## happen to agree to the millimetre on every model checked (Barbarian,
## Skeleton_Minion and Mannequin_Medium all report the same height either way),
## so this costs nothing here; it is the vertices because that is the question,
## not because Godot was caught padding.
func _rest_bounds(node: Node, at: Transform3D) -> AABB:
	var here := at
	if node is Node3D:
		here = at * (node as Node3D).transform
	var box := AABB()
	var started := false
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			for v in mesh.get_faces():
				var p := here * v
				if not started:
					box = AABB(p, Vector3.ZERO)
					started = true
				else:
					box = box.expand(p)
	for child in node.get_children():
		var child_box := _rest_bounds(child, here)
		if child_box.size == Vector3.ZERO and child_box.position == Vector3.ZERO:
			continue
		box = child_box if not started else box.merge(child_box)
		started = true
	return box
