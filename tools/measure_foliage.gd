extends SceneTree
## How often a tree stands between the playing camera and the person, and where.
##
##   ./tools/measure_foliage.sh [--seed N] [--span N] [--step N] [--camera X Y Z]
##
## The second playtest reported that the person is "standing behind trees and
## grass with no fade and no camera collision". This turns that into a number:
## the world is walked on a lattice of standing places, the camera is put where
## the game puts it at each of them, and `FoliageFade` -- the same pure function
## the shell uses every frame -- is asked how much of the sight line each nearby
## prop is across.
##
## Two things come out. The share of standing places where something is in the
## way, which is the size of the defect; and the worst few places by name, which
## is where a frame showing the rule should be photographed from.
##
## Every prop's crown is measured off the model the asset table actually builds,
## once per catalog name and then scaled, because the packs do not agree on how
## broad a thing of a given height is.

const DEFAULT_SEED := 1234
const DEFAULT_SPAN := 60.0
const DEFAULT_STEP := 4.0

const RenderShell := preload("res://render/main.gd")


func _initialize() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	var seed_value := int(options["seed"])
	var span := float(options["span"])
	var step := float(options["step"])
	var offset: Vector3 = options["camera"]
	var sim := Simulation.new(seed_value)
	var terrain := sim.world.terrain
	var scatter := DecorationScatter.new(terrain)
	var shapes := {}
	# One patch per chunk for the whole survey rather than one per standing
	# place: neighbouring places share nearly all their chunks, and building a
	# patch is by far the most expensive thing here.
	var patches := {}

	# Where the world's own observer stands, so the lattice is walked around the
	# place a run of this seed actually opens on.
	var centre := Vector2(sim.world.observer_x, sim.world.observer_z)
	print("=== the survey ===")
	print("  seed %d, %.0f units either way from (%.1f, %.1f) every %.1f units" % [
		seed_value, span, centre.x, centre.y, step])
	print("  camera %s, %.1f units back" % [
		offset, offset.length()])

	var places := 0
	var blocked := 0
	var worst: Array[Dictionary] = []
	var at_z := -span
	while at_z <= span:
		var at_x := -span
		while at_x <= span:
			var stand := Vector2(centre.x + at_x, centre.y + at_z)
			var feet := Vector3(
				stand.x, terrain.ground_height_at(stand.x, stand.y), stand.y)
			var camera := feet + offset
			var worst_here := 0.0
			var count := 0
			for item in _props_near(scatter, patches, stand, offset.length()):
				var shape := _shape_of(shapes, String(item["tag"]))
				var size := float(item["size"])
				var foot := Vector3(
					float(item["x"]), float(item["y"]), float(item["z"]))
				if foot.y == 0.0:
					foot.y = terrain.ground_height_at(foot.x, foot.z)
				var covered := FoliageFade.cover(
					camera, feet, foot,
					float(shape["broad"]) * size, float(shape["tall"]) * size)
				if covered > 0.0:
					count += 1
					worst_here = maxf(worst_here, covered)
			places += 1
			if count > 0:
				blocked += 1
				worst.append({
					"x": stand.x, "z": stand.y, "props": count, "worst": worst_here,
				})
			at_x += step
		at_z += step

	print("=== what the shipping camera meets ===")
	print("  %d standing places, %d of them with something across the sight line: %.1f%%" % [
		places, blocked, 0.0 if places == 0 else 100.0 * float(blocked) / float(places)])
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["props"]) != int(b["props"]):
			return int(a["props"]) > int(b["props"])
		return float(a["worst"]) > float(b["worst"]))
	print("  the ten worst places to stand, as --start x z:")
	for at in mini(10, worst.size()):
		var row: Dictionary = worst[at]
		print("    --start %.1f %.1f   %d props, the worst %.2f across the line" % [
			row["x"], row["z"], int(row["props"]), float(row["worst"])])
	quit()


## Every scattered prop on the chunks that could hold one in the way of somebody
## standing here.
func _props_near(
	scatter: DecorationScatter, patches: Dictionary, stand: Vector2, back: float
) -> Array:
	var reach := back + FoliageFade.WIDEST_CROWN
	var found: Array = []
	var steps := int(ceil(reach / SimTerrainChunkMesher.CHUNK_SIZE)) + 1
	var here := SimTerrainChunkMesher.chunk_at(stand.x, stand.y)
	for offset_x in range(-steps, steps + 1):
		for offset_z in range(-steps, steps + 1):
			var key := Vector2i(here.x + offset_x, here.y + offset_z)
			if SimTerrainChunkMesher.distance_to_chunk(key, stand.x, stand.y) > reach:
				continue
			if not patches.has(key):
				patches[key] = scatter.build(key.x, key.y)
			var patch: ScatterPatch = patches[key]
			if patch == null:
				continue
			found.append_array(patch.items)
	return found


## How broad and how tall one catalog name is drawn, as shares of the size the
## scatter asks for. Built once per name and kept, because building a model is
## far and away the most expensive thing here.
func _shape_of(shapes: Dictionary, tag: String) -> Dictionary:
	if shapes.has(tag):
		return shapes[tag]
	var row := {"broad": 0.0, "tall": 0.0}
	var node := AssetLibrary.build(tag, null)
	var natural := AssetLibrary.natural_height(tag)
	if node != null and natural > 0.0:
		get_root().add_child(node)
		var box := _aabb(node, Transform3D.IDENTITY)
		row["broad"] = maxf(box.size.x, box.size.z) * 0.5 / natural
		row["tall"] = box.size.y / natural
		node.queue_free()
	shapes[tag] = row
	return row


func _aabb(node: Node, so_far: Transform3D) -> AABB:
	var box := AABB()
	var started := false
	if node is VisualInstance3D:
		box = so_far * (node as VisualInstance3D).get_aabb()
		started = true
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var below := _aabb(child, so_far * (child as Node3D).transform)
		if below.size == Vector3.ZERO:
			continue
		box = below if not started else box.merge(below)
		started = true
	return box


func _parse(args: PackedStringArray) -> Dictionary:
	var options := {
		"seed": DEFAULT_SEED, "span": DEFAULT_SPAN, "step": DEFAULT_STEP,
		# The camera the game ships with, unless a run wants to price a
		# different one -- which is how the camera this replaced is still
		# answerable to the same measurement.
		"camera": RenderShell.CAMERA_OFFSET,
	}
	var i := 0
	while i < args.size():
		match args[i]:
			"--seed":
				options["seed"] = args[i + 1].to_int()
				i += 1
			"--span":
				options["span"] = args[i + 1].to_float()
				i += 1
			"--step":
				options["step"] = args[i + 1].to_float()
				i += 1
			"--camera":
				options["camera"] = Vector3(
					args[i + 1].to_float(),
					args[i + 2].to_float(),
					args[i + 3].to_float())
				i += 3
		i += 1
	return options
