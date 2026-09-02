extends SceneTree
## Inventory an installed pack: every model, once, with the numbers a table row
## is chosen from.
##
##   ./tools/inventory_pack.sh assets/justcreate_village
##   ./tools/inventory_pack.sh assets/justcreate_village --require-textures
##   ./tools/inventory_pack.sh assets/tag_scenes            # the wrappers, as drawn
##
## Prints one line per model: path, triangle count, width x height x depth in
## world units as the artist drew it, the y of the model's lowest point, how many
## MeshInstance3D nodes it is split across, and the albedo texture its material
## binds -- or "NONE" where nothing bound.
##
## The size and the floor are what tools/measure_models.sh already prints, and
## are here for the same reason: a row's `scene_height` has to be measured rather
## than guessed, and a model whose origin is not at its feet stands sunk into the
## ground. The centre is the same fact sideways: a lamp post whose lantern hangs
## off an arm has its light a metre from its own origin, and the row has to say
## so or the point light comes out of the post. The two additions are the ones
## that decide between candidates rather than place one: the triangle count,
## because the world places thousands of some of these, and the bound texture,
## because a pack whose atlas does not bind draws untextured white.
##
## "No albedo texture" is not the same as "untextured", and the column has to be
## read with that in mind: the KayKit medieval builder pack ships no texture file
## at all and all 226 of its models report UNBOUND, because they are
## vertex-coloured and draw in full colour anyway. The check below is worth
## running on a pack that *has* an atlas, to find out whether it bound.
##
## --require-textures exits non-zero if any material in the pack failed to bind
## its albedo. That is the form the "the pack imports with textures bound" claim
## takes. A model that ships no material at all is reported separately and does
## not fail the check -- it is not a broken import, it is art the pack never
## textured, and no row points at one.
##
## By default that question is asked of the *model*: did anything in it bind? A
## model whose walls bind and whose glass does not still passes, which is right
## for a pack whose glass is a flat colour and wrong for finding out that a whole
## material is unbound across hundreds of files. --every-material asks it of each
## material instead, and --except-material NAME excuses one by name -- which is
## how the Mistage packs are checked, where two materials name an atlas that
## belongs to a pack the archive does not contain and every glow material names
## no texture at all because the glow lived in a shader.

func _initialize() -> void:
	var roots := PackedStringArray()
	var excused := PackedStringArray()
	var excused_materials := PackedStringArray()
	var strict := false
	var every := false
	var wants := ""
	for arg in OS.get_cmdline_user_args():
		if wants == "--except":
			excused.append(arg)
			wants = ""
		elif wants == "--except-material":
			excused_materials.append(arg)
			wants = ""
		elif arg == "--require-textures":
			strict = true
		elif arg == "--every-material":
			every = true
		elif arg == "--except" or arg == "--except-material":
			wants = arg
		else:
			roots.append(arg)
	if roots.is_empty():
		roots.append("res://assets")

	var paths := PackedStringArray()
	for root in roots:
		var res_root := root if root.begins_with("res://") else "res://" + root.trim_prefix("./")
		paths.append_array(_models(res_root))
	paths.sort()

	var untextured := 0
	var materialless := 0
	var unbound_names := PackedStringArray()
	var unbound_materials := {}
	var measured := 0
	var total_tris := 0
	print("%-64s %8s  %-24s %8s %15s %6s  %s" % [
		"model", "tris", "size w x h x d (m)", "floor", "centre x,z", "meshes", "albedo",
	])
	for path in paths:
		var packed: PackedScene = load(path)
		if packed == null:
			print("%-64s  UNLOADABLE" % path)
			untextured += 1
			continue
		var node := packed.instantiate()
		var seen := {
			"tris": 0, "meshes": 0, "albedo": "", "materials": 0, "unbound": [],
		}
		_walk(node, seen)
		var box := _aabb(node, Transform3D.IDENTITY)
		node.free()
		measured += 1
		total_tris += int(seen["tris"])
		var albedo: String = seen["albedo"]
		if albedo == "":
			# Two different things, kept apart because only one is a failure. A
			# model with a material whose texture did not resolve draws white and
			# means the import is broken; a model with no material at all is one
			# the pack never textured, and the table simply does not point at it.
			albedo = "UNBOUND" if int(seen["materials"]) > 0 else "NO MATERIAL"
			if _excused(path, excused):
				albedo = "(none in the archive)"
				materialless += 1
			elif int(seen["materials"]) > 0:
				untextured += 1
				unbound_names.append(path.trim_prefix("res://"))
			else:
				materialless += 1
		if every:
			# The same question asked of every material rather than of the model:
			# each one that bound nothing is a failure unless its name is excused.
			for material_name: String in seen["unbound"]:
				if _excused(material_name, excused_materials) or _excused(path, excused):
					continue
				unbound_materials[material_name] = int(
					unbound_materials.get(material_name, 0)) + 1
		var centre := box.position + box.size * 0.5
		print("%-64s %8d  %6.3f x %6.3f x %6.3f %+8.3f %+7.3f,%+7.3f %6d  %s" % [
			path.trim_prefix("res://"), int(seen["tris"]),
			box.size.x, box.size.y, box.size.z, box.position.y,
			centre.x, centre.z, int(seen["meshes"]), albedo,
		])
	print("")
	print("%d models, %d triangles, %d with no albedo bound (%d of those excused)" % [
		measured, total_tris, untextured + materialless, materialless,
	])
	if every:
		if unbound_materials.is_empty():
			print("every material in every model binds an albedo texture")
		else:
			var names := unbound_materials.keys()
			names.sort()
			for material_name: String in names:
				printerr("  material '%s' bound no albedo on %d surface(s)" % [
					material_name, unbound_materials[material_name],
				])
			if strict:
				printerr("FAIL: %d material(s) bound no albedo" % unbound_materials.size())
				quit(1)
				return
		# The material-level question supersedes the model-level one. A model
		# whose only material is an untextured glow is not a broken import, and
		# once every material has been named and judged by name, failing again
		# per model would fail the check on art the pack never textured.
		if strict:
			print("OK: every material in the %d models binds its albedo, or is excused by name" %
				measured)
		quit()
		return
	if strict and untextured > 0:
		for name in unbound_names:
			printerr("  unbound: %s" % name)
		printerr("FAIL: %d of %d models have a material whose albedo did not bind" % [untextured, measured])
		quit(1)
		return
	if strict:
		print("OK: every material in the %d models binds its albedo texture (%d excused)" % [
			measured, materialless,
		])
	quit()


## Whether a model or a material was excused by name on the command line.
static func _excused(path: String, excused: PackedStringArray) -> bool:
	for fragment in excused:
		if fragment != "" and path.contains(fragment):
			return true
	return false


## Triangles, mesh nodes and the first albedo texture found under a node.
func _walk(node: Node, into: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			into["meshes"] = int(into["meshes"]) + 1
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					into["tris"] = int(into["tris"]) + arrays[Mesh.ARRAY_INDEX].size() / 3
				elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					into["tris"] = int(into["tris"]) + arrays[Mesh.ARRAY_VERTEX].size() / 3
				var material := mesh.surface_get_material(surface)
				if material is BaseMaterial3D:
					into["materials"] = int(into["materials"]) + 1
					var texture: Texture2D = (material as BaseMaterial3D).albedo_texture
					if texture == null:
						var unnamed: String = material.resource_name
						(into["unbound"] as Array).append(
							unnamed if unnamed != "" else "(unnamed material)")
					elif into["albedo"] == "":
						# A texture the importer pulled *out* of the model file
						# has no path of its own. It is still bound, and saying
						# "unbound" of it would be a lie -- the KayKit builder
						# pack ships exactly that.
						var named := texture.resource_path.get_file()
						into["albedo"] = named if named != "" else "(embedded)"
	for child in node.get_children():
		_walk(child, into)


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
		elif name.get_extension().to_lower() in ["gltf", "glb", "fbx", "tscn"]:
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
