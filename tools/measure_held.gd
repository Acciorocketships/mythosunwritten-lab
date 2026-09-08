extends SceneTree
## Measure everything the two hand sockets need: what each held gear tag is
## shaped like as built, and which way the shared rig's hand-slot bones point.
##
##   ./tools/measure_held.sh
##
## Two sections:
##   HAND SLOTS  for each character tag that wears the shared rig: the global
##               rest transform of `handslot.l` and `handslot.r` -- basis columns
##               and origin -- plus the model's own height, so a held item's size
##               can be judged against the hand that holds it.
##   HELD GEAR   for each tag the item table can put in a hand: the built
##               model's bounding box (min, max, size), which axis its length
##               lies along, and how the box sits about the model's own origin.
##
## This exists because the packs do not agree: KayKit draws a sword along its
## height with the grip at the origin, the mistage packs draw theirs however the
## stall wanted them. Whatever mounts a thing in a hand has to know, and nobody
## should be guessing either half.

const CHARACTER_TAGS := ["knight", "mage", "rogue"]
const HELD_TAGS := [
	"gear_blade", "gear_dagger", "gear_spear", "gear_bow",
	"gear_staff", "gear_flail", "gear_buckler",
]
const SLOT_BONES := ["handslot.l", "handslot.r", "hand.l", "hand.r"]


func _initialize() -> void:
	print("HAND SLOTS")
	for tag in CHARACTER_TAGS:
		var model := AssetLibrary.build(tag)
		if model == null:
			print("  %-12s no visual" % tag)
			continue
		var box := _aabb(model, Transform3D.IDENTITY)
		print("  %-12s height %.3f  box min %s max %s" % [
			tag, box.size.y, _v(box.position), _v(box.position + box.size),
		])
		var skeleton := _first_skeleton(model)
		if skeleton == null:
			print("    no skeleton")
			model.free()
			continue
		for bone_name in SLOT_BONES:
			var at := skeleton.find_bone(bone_name)
			if at < 0:
				continue
			var rest := skeleton.get_bone_global_rest(at)
			# Where the bone sits in the *model's* frame, skeleton transform in.
			var placed: Transform3D = _relative_to(skeleton, model) * rest
			print("    %-12s origin %s" % [bone_name, _v(placed.origin)])
			print("      x -> %s  y -> %s  z -> %s" % [
				_v(placed.basis.x), _v(placed.basis.y), _v(placed.basis.z),
			])
		model.free()

	print("")
	print("HELD GEAR")
	for tag in HELD_TAGS:
		var model := AssetLibrary.build(tag)
		if model == null:
			print("  %-14s no visual" % tag)
			continue
		var box := _aabb(model, Transform3D.IDENTITY)
		var axis := _long_axis(box.size)
		print("  %-14s size %s  long axis %s (%.3f)" % [
			tag, _v(box.size), ["x", "y", "z"][axis], box.size[axis],
		])
		print("    min %s max %s  (about the model's own origin)" % [
			_v(box.position), _v(box.position + box.size),
		])
		model.free()
	quit(0)


static func _v(vector: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [vector.x, vector.y, vector.z]


static func _long_axis(size: Vector3) -> int:
	if size.x >= size.y and size.x >= size.z:
		return 0
	return 1 if size.y >= size.z else 2


static func _relative_to(node: Node3D, root: Node3D) -> Transform3D:
	var accumulated := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != root:
		if walk is Node3D:
			accumulated = (walk as Node3D).transform * accumulated
		walk = walk.get_parent()
	return accumulated


static func _first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _first_skeleton(child)
		if found != null:
			return found
	return null


static func _aabb(node: Node, up_to_here: Transform3D) -> AABB:
	var carried := up_to_here
	if node is Node3D:
		carried = up_to_here * (node as Node3D).transform
	var merged := AABB()
	var started := false
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			var local := mesh.get_aabb()
			var moved := carried * local
			merged = moved
			started = true
	for child in node.get_children():
		var below := _aabb(child, carried)
		if below.size == Vector3.ZERO and below.position == Vector3.ZERO:
			continue
		if started:
			merged = merged.merge(below)
		else:
			merged = below
			started = true
	return merged
