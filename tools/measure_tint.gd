extends SceneTree
## Measure what the biome tint costs: how many materials a streamed radius draws
## with, and how long the render layer takes to build one chunk of scatter, with
## the tint on and with it off.
##
##   ./tools/measure_tint.sh                        # seed 1234 at the origin
##   ./tools/measure_tint.sh --seed 7 --start -100 34
##
## "Off" is not a different build of the table: it is the same rows built with no
## biome profile, which is exactly what AssetLibrary.build() does for a caller
## that has none, and is what the render layer did before this change. So the two
## columns differ in one thing only.
##
## What the numbers mean. Every surface of every model is drawn with one
## material, and the renderer can only batch surfaces that share a mesh *and* a
## material. So "unique materials" is the cache's job -- if it were one per
## instance the tint would have turned every fir into its own draw call -- and
## "unique mesh+material pairs" is the batching group count, which is the number
## that actually reaches the graphics card.

const DEFAULT_SEED := 1234
const DEFAULT_TICKS := 40


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var sim := Simulation.new(options["seed"])
	if options["start"]:
		sim.world.place_observer(options["start_x"], options["start_z"])
	sim.run(options["ticks"])

	var patches: Array = []
	for key in sim.world.scatter_streamer.loaded_keys():
		var patch := sim.world.scatter_streamer.patch(key)
		if patch != null:
			patches.append(patch)

	print("seed %d, observer at %.1f, %.1f, %d ticks" % [
		options["seed"], sim.world.observer_x, sim.world.observer_z, options["ticks"],
	])
	print("%d scatter chunks loaded" % patches.size())
	print("")
	print("%-28s %12s %12s" % ["", "tint off", "tint on"])
	var off := _measure(sim, patches, false)
	var on := _measure(sim, patches, true)
	for label in [
		"instances built", "mesh surfaces", "unique materials",
		"unique mesh+material pairs", "build ms total", "build ms per chunk",
	]:
		var format := "%12.3f" if label.begins_with("build") else "%12d"
		print(("%-28s " + format + " " + format) % [label, off[label], on[label]])
	quit(0)


## Build every scattered thing in the loaded radius once, and count what the
## renderer would have to draw it with.
func _measure(sim: Simulation, patches: Array, tinted: bool) -> Dictionary:
	var materials := {}
	var pairs := {}
	var instances := 0
	var surfaces := 0
	var started := Time.get_ticks_usec()
	var built: Array[Node] = []
	for patch in patches:
		for item in patch.items:
			var profile: BiomeProfile = null
			if tinted:
				profile = sim.world.terrain.profile_at(
					float(item["x"]), float(item["z"])
				)
			var node := AssetLibrary.build(String(item["tag"]), profile)
			if node == null:
				continue
			instances += 1
			built.append(node)
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	for node in built:
		surfaces += _count(node, materials, pairs)
	for node in built:
		node.free()
	var chunks := maxi(patches.size(), 1)
	return {
		"instances built": instances,
		"mesh surfaces": surfaces,
		"unique materials": materials.size(),
		"unique mesh+material pairs": pairs.size(),
		"build ms total": elapsed,
		"build ms per chunk": elapsed / float(chunks),
	}


## Every surface under a node, and which material and mesh each is drawn with.
func _count(node: Node, materials: Dictionary, pairs: Dictionary) -> int:
	var found := 0
	var view := node as MeshInstance3D
	if view != null and view.mesh != null:
		for surface in view.mesh.get_surface_count():
			found += 1
			var material: Material = view.material_override
			if material == null:
				material = view.get_surface_override_material(surface)
			if material == null:
				material = view.mesh.surface_get_material(surface)
			var material_id := 0 if material == null else material.get_instance_id()
			materials[material_id] = true
			pairs["%d:%d:%d" % [view.mesh.get_instance_id(), surface, material_id]] = true
	for child in node.get_children():
		found += _count(child, materials, pairs)
	return found


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"seed": DEFAULT_SEED, "ticks": DEFAULT_TICKS,
		"start": false, "start_x": 0.0, "start_z": 0.0,
	}
	var index := 0
	while index < args.size():
		match args[index]:
			"--seed":
				options["seed"] = args[index + 1].to_int()
				index += 1
			"--ticks":
				options["ticks"] = args[index + 1].to_int()
				index += 1
			"--start":
				options["start"] = true
				options["start_x"] = args[index + 1].to_float()
				options["start_z"] = args[index + 2].to_float()
				index += 2
		index += 1
	return options
