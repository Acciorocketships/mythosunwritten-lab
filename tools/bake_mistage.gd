extends SceneTree
## Turn a Mistage FBX into one scene the streamer can afford to instantiate.
##
##   ./tools/bake_mistage.sh              # every recipe below
##   ./tools/bake_mistage.sh house_       # only recipes whose name contains this
##
## Three things happen to every model on the way through, and all three are the
## defects reports/mistage-packs.md measured:
##
## 1. **Scale.** Both packs import at true metres -- a door is 2.204 tall, a
##    barrel 0.956, a stool 0.543 -- and this world is not at true metres. Its
##    houses are the JustCreate pack's, 5.9 x 5.5 x 6.7, and the simulation
##    reserves ground for them in `SettlementField.BUILDING_FOOTPRINTS`, which
##    no file here may edit. So each recipe carries one uniform factor, and the
##    factor is not a taste: for a building it is the largest number that still
##    fits the footprint its tag reserves, and for a prop it is the number that
##    makes the Mistage model the size of the model it stands beside. Every one
##    is written out with the measurement it came from.
##
## 2. **Mesh nodes.** A Mistage building arrives as 149 to 302 separate
##    MeshInstance3D nodes -- the artist's own kit, exported unmerged. The
##    streamer instantiates a village of these every time a chunk comes in, and
##    a node is a scene-tree entry, a transform and a draw call. Every surface
##    is merged here into one per material, so what the streamer instantiates is
##    one node with two or three surfaces.
##
## 3. **Materials that name a texture the archive does not ship.** The village
##    pack's glass (SFV_TRANSPARENT) points at an atlas belonging to a different
##    Mistage pack, so it imports white and opaque -- a white sheet across the
##    front of half the buildings. `drop` names it and the bake leaves it out;
##    the lit windows are a separate material and stay.
##
## The recipes are the whole of what this project takes from the two packs, and
## every number in one is stated with what it was measured against. Nothing here
## knows what an asset tag is: this is a workbench that writes files, and
## render/asset_library.gd is what decides a tag points at one.
##
## Output goes to assets/mistage_baked/, which is ignored by git for the reason
## the packs themselves are -- it is reproducible from an archive already on
## disk, and it is paid art.

## Where the baked scenes and their meshes are written.
const OUT_DIR := "res://assets/mistage_baked"

## The fewest triangles a surface must have before the budget may climb its
## ladder.
##
## A building's lit windows are their own surface and 20 to 42 triangles of it.
## Climbing that ladder with the rest saves nothing and costs the thing the
## village is lit by: at one rung the six small panes of a house collapse into
## one bright rectangle across its gable. So a surface this small is left at full
## detail and the budget is met out of the surface that actually holds the model.
const LOD_FLOOR := 256

## The two angles the distance ladder is built with, in degrees.
##
## Godot's scene importer defaults, unchanged and stated here only because this
## bake has to run the pass itself: 25 degrees is how far two normals may differ
## and still be welded into one vertex, 60 is where a hard edge is kept as a
## crease the simplifier will not cross. Leaving them at the importer's values is
## deliberate -- the point of the pass here is to restore what merging removed,
## not to make a different trade from the rest of the project's art.
const LOD_MERGE_ANGLE := 25.0
const LOD_SPLIT_ANGLE := 60.0

const VILLAGE := "res://assets/mistage_village/FBX"
const MARKET := "res://assets/mistage_market/FBX"

## One baked scene.
##
## `name`   -- the file written, <name>.tscn and <name>_mesh.res
## `src`    -- one or more source models, all merged into the one output
## `scale`  -- the uniform factor, with `why` saying what it was measured from
## `yaw`    -- degrees about Y, applied after the scale
## `drop`   -- FBX material names left out entirely
## `only`   -- if non-empty, the only FBX material names kept
## `glow`   -- FBX material name -> {"colour": Color, "energy": float}, which
##             turns that material emissive; see the window pane below
## `budget` -- the most triangles the model may cost at its closest; the level
##             of detail ladder is climbed until it is under this
## `ground` -- true to drop the model's lowest point onto y=0 (default true)
## `centre` -- true to put the box's x,z centre on the origin (default true)
## `centre_y` -- true to put the box's y centre on the origin instead of its
##             floor, for a thing that hangs rather than stands
## `lift`   -- a translation applied after all of that
##
## A recipe with several sources is how a stall gets its goods: the pieces are
## separate files in the pack because the artist meant them to be arranged, and
## arranging them once here is cheaper than a wrapper scene with six instances,
## because they merge into the same two surfaces as the stall alone.
const RECIPES := [
	# --- Buildings -------------------------------------------------------
	# The six "Fake Buildings" are the exteriors: the same six shells as
	# Buildings/Buildings/ with the furnished interior left out, which is 15-20%
	# fewer triangles for a thing this task does not open the door of.
	#
	# The scale on each is min(2 * half_width / model_width, 2 * half_depth /
	# model_depth) for the footprint its tag reserves in the simulation, rounded
	# down to three places. That is the same rule the JustCreate wrappers follow
	# -- House_01 is 5.869 x 6.650 at 0.886, which is 5.20 x 5.89 inside a
	# 5.2 x 6.0 footprint -- so a Mistage building drops into the same slot.
	#
	# The budget on each is one rung up the ladder and no further, and it is one
	# rung because that is as far as the models could be climbed without the
	# difference showing: reports/mistage-packs.md has the four side by side at
	# full detail, one rung and two, and two is where a house loses the timber
	# bracing on its gable. One rung is 17 090 triangles for a house against
	# 39 712 at full and 9 815 for the JustCreate house it replaces.
	{
		"name": "house_mistage",
		"src": [VILLAGE + "/Buildings/Fake Buildings/SFV_Building_Empty_Blue_002.fbx"],
		# 13.818 x 17.524 x 13.028; house reserves 5.2 x 6.0. min(0.376, 0.460).
		# The tallest and narrowest of the six: a three-storey timber townhouse,
		# which at this scale stands 6.59 -- taller than the JustCreate house it
		# replaces (4.84 as drawn) and the reason to take it.
		"scale": 0.376,
		"why": "13.818 wide into the 5.2 the house footprint reserves",
		"budget": 20000,
		"drop": ["SFV_TRANSPARENT"],
		"glow": {"SFV_GLOW_WINDOW": {"colour": Color(1.00, 0.72, 0.36), "energy": 2.4}},
	},
	# The cottage is baked and the table does not point at it. It is here because
	# the decision not to use it is a measurement rather than a taste: it is what
	# reports/mistage-packs.md photographs beside the JustCreate cottage, and what
	# the 116 312 triangles a village and the 0.315 window gap in that report were
	# measured from. Deleting the recipe would delete the evidence.
	{
		"name": "cottage_mistage",
		"src": [VILLAGE + "/Buildings/Fake Buildings/SFV_Building_Empty_Blue_006.fbx"],
		# 14.416 x 9.442 x 14.713; cottage reserves 4.0 x 4.4. min(0.277, 0.299).
		# The squattest of the six -- one storey under a wide roof -- which is
		# what a cottage is, and why it takes the tightest footprint.
		"scale": 0.277,
		"why": "14.416 wide into the 4.0 the cottage footprint reserves",
		"budget": 20000,
		"drop": ["SFV_TRANSPARENT"],
		"glow": {"SFV_GLOW_WINDOW": {"colour": Color(1.00, 0.72, 0.36), "energy": 2.4}},
	},
	{
		"name": "tavern_mistage",
		"src": [VILLAGE + "/Buildings/Fake Buildings/SFV_Building_Empty_Blue_005.fbx"],
		# 18.601 x 16.229 x 18.846; tavern reserves 7.2 x 7.8. min(0.387, 0.413).
		# The biggest of the six, with a balcony and a double roof, in the only
		# footprint big enough to hold it.
		"scale": 0.387,
		"why": "18.601 wide into the 7.2 the tavern footprint reserves",
		"budget": 30000,
		"drop": ["SFV_TRANSPARENT"],
		"glow": {"SFV_GLOW_WINDOW": {"colour": Color(1.00, 0.72, 0.36), "energy": 2.4}},
	},
	{
		"name": "workshop_mistage",
		"src": [VILLAGE + "/Buildings/Fake Buildings/SFV_Building_Empty_Blue_003.fbx"],
		# 15.080 x 10.972 x 14.364; workshop reserves 5.8 x 5.0. min(0.384, 0.348).
		# The one with a lean-to and an awning over its ground floor, which is
		# the closest thing in the pack to a workshop.
		"scale": 0.348,
		"why": "14.364 deep into the 5.0 the workshop footprint reserves",
		"budget": 20000,
		"drop": ["SFV_TRANSPARENT"],
		"glow": {"SFV_GLOW_WINDOW": {"colour": Color(1.00, 0.72, 0.36), "energy": 2.4}},
	},

	# The same house at the two rungs either side of the one it ships at, so the
	# choice of rung is a photograph rather than an assertion. Nothing points at
	# these; they are what reports/mistage-packs.md lays beside house_mistage,
	# and deleting them would delete the evidence for the budget above.
	{
		"name": "house_mistage_full",
		"src": [VILLAGE + "/Buildings/Fake Buildings/SFV_Building_Empty_Blue_002.fbx"],
		"scale": 0.376,
		"why": "the house, with the ladder not climbed at all: 39 712 triangles",
		"drop": ["SFV_TRANSPARENT"],
		"glow": {"SFV_GLOW_WINDOW": {"colour": Color(1.00, 0.72, 0.36), "energy": 2.4}},
	},
	{
		"name": "house_mistage_two_rungs",
		"src": [VILLAGE + "/Buildings/Fake Buildings/SFV_Building_Empty_Blue_002.fbx"],
		"scale": 0.376,
		"why": "the house one rung further than it ships at: 6206 triangles",
		"budget": 8000,
		"drop": ["SFV_TRANSPARENT"],
		"glow": {"SFV_GLOW_WINDOW": {"colour": Color(1.00, 0.72, 0.36), "energy": 2.4}},
	},

	# --- The modular kit -------------------------------------------------
	# One piece of the wall-and-roof kit, baked at the same factor as the house
	# so the two are commensurate: a 3.000 x 3.000 wall module is 1.128 beside a
	# 6.588 house, which is the storey height that house is drawn with. It is
	# baked so the kit can be measured and shown at the scale the buildings are
	# used at, which is what makes "the pack ships a kit" a fact with a number
	# rather than a directory listing.
	{
		"name": "wall_module_mistage",
		"src": [VILLAGE + "/Walls/Wooden/Windows/SFV_Wall_Wooden_Window_M_001.fbx"],
		"scale": 0.376,
		"why": "the house factor, so the kit and the buildings are one scale",
		"drop": ["SFV_TRANSPARENT"],
		"centre": false,
		"ground": false,
	},

	# --- The lit window --------------------------------------------------
	# The pack's own glow-window pane, and the only model in either pack whose
	# whole content is the SFV_GLOW_WINDOW material. It is what the window_glow
	# tag has wanted since the tag existed: the render layer has been drawing an
	# amber quad of its own because there was no model to draw.
	#
	# Not scaled to a footprint -- there is none. The pane alone is 0.741 across
	# and 0.958 tall as imported, and the row reserves 0.45 by 0.45 for it, so
	# 0.470 is the number that fits the taller side: 0.348 x 0.451, inside what
	# the fit in AssetLibrary was measured against.
	#
	# It is centred on its box in all three axes and then lifted to
	# AssetLibrary.WINDOW_HEIGHT, because that is exactly where the row's own
	# quad sits and _add_window_glow lifts the node by (fitted height -
	# WINDOW_HEIGHT) on the strength of it. Its normal is +Z as imported, which
	# is the way the placeholder's PlaneMesh.FACE_Z quad faces, so the yaw the
	# fit hands over turns it out of the wall rather than into it.
	#
	# `only` keeps the pane alone and leaves the pack's window frame out. The
	# building this is placed on already has its own frames drawn; what the tag
	# needs is the lit glass, and that is six triangles.
	{
		"name": "window_glow_mistage",
		"src": [VILLAGE + "/Walls (Empty)/Empty Windows/SFV_Windows_Glow_001.fbx"],
		"scale": 0.470,
		"why": "0.958 tall into the 0.45 the window_glow row reserves",
		"centre": true,
		"centre_y": true,
		"lift": Vector3(0.0, AssetLibrary.WINDOW_HEIGHT, 0.0),
		"only": ["SFV_GLOW_WINDOW"],
		"glow": {"SFV_GLOW_WINDOW": {"colour": Color(1.00, 0.72, 0.36), "energy": 2.4}},
	},

	# --- Market ----------------------------------------------------------
	# The greengrocer's cart, which is the one model on disk that is a market
	# stall *and* its vendor goods in one piece: a striped awning over a trestle
	# of crated fruit, a rear display panel, a sack, and cartwheels under it. The
	# artist arranged the goods; nothing here has to.
	#
	# 5.851 x 4.171 x 3.743 at true metres. The stall it replaces is 2.80 x 2.09
	# x 2.14 as drawn (JustCreate Market_Table_03 + Market_Roof_01 at 1.029), and
	# the settlement layer puts one or two on a village green between buildings,
	# so it stays at that order: 2.80 / 5.851 = 0.478.
	{
		"name": "market_stall_mistage",
		"src": [MARKET + "/Fruits Stall/Stall/SFM_Veg_Stall_003.fbx"],
		"scale": 0.478,
		"why": "5.851 across into the 2.80 the JustCreate stall it replaces draws",
	},
]


func _initialize() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			filter = arg
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var failed := 0
	print("%-24s %7s %7s %8s %8s  %s" % [
		"recipe", "nodes", "surf", "tris", "scale", "w x h x d, before -> after",
	])
	for recipe in RECIPES:
		if filter != "" and not String(recipe["name"]).contains(filter):
			continue
		if not _bake(recipe):
			failed += 1
	if failed > 0:
		printerr("FAIL: %d recipe(s) did not bake" % failed)
		quit(1)
		return
	quit()


## Bake one recipe. Returns false if anything about it did not work.
func _bake(recipe: Dictionary) -> bool:
	var out_name: String = recipe["name"]
	var scale: float = recipe.get("scale", 1.0)
	var yaw: float = deg_to_rad(recipe.get("yaw", 0.0))
	var drop: Array = recipe.get("drop", [])
	var only: Array = recipe.get("only", [])

	# --- read the sources ------------------------------------------------
	var pieces: Array[Dictionary] = []
	var before := AABB()
	var before_started := false
	var before_nodes := 0
	var before_surfaces := 0
	var before_tris := 0
	for src in recipe["src"]:
		var packed: PackedScene = load(src)
		if packed == null:
			printerr("  %s: %s will not load" % [out_name, src])
			return false
		var root := packed.instantiate()
		var found: Array[Dictionary] = []
		_collect(root, Transform3D.IDENTITY, found)
		var counted := {}
		for piece in found:
			# Nodes and surfaces are different numbers and both matter: a node is
			# a scene-tree entry and a transform the streamer pays for, a surface
			# is a draw call. An FBX mesh node may carry more than one surface.
			var node_id: int = piece["node"]
			if not counted.has(node_id):
				counted[node_id] = true
				before_nodes += 1
			before_surfaces += 1
			before_tris += int(piece["tris"])
			if not _wanted(piece, drop, only):
				continue
			# Measured over the surfaces that survive `drop` and `only` only.
			# The box has to be the box of what is written out, or centring a
			# model whose glass was dropped would centre it on glass that is no
			# longer there -- which is a quarter of a window's width on the pane.
			var box: AABB = _surface_box(piece)
			before = box if not before_started else before.merge(box)
			before_started = true
			pieces.append(piece)
		root.free()
	if pieces.is_empty():
		printerr("  %s: no meshes in %s" % [out_name, recipe["src"]])
		return false

	# --- where the merged model sits -------------------------------------
	# The scale and the quarter turn first, then the box measured again in that
	# space, then the shift that puts its feet on y=0 and its middle on the
	# origin. Measured rather than asserted: a Mistage model's own origin is
	# wherever the artist's cursor was, and half of them are metres away from
	# the thing they belong to.
	var place := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), Vector3.ZERO)
	var scaled := place * before
	var shift: Vector3 = recipe.get("lift", Vector3.ZERO)
	if recipe.get("centre", true):
		shift.x -= scaled.position.x + scaled.size.x * 0.5
		shift.z -= scaled.position.z + scaled.size.z * 0.5
	if recipe.get("centre_y", false):
		shift.y -= scaled.position.y + scaled.size.y * 0.5
	elif recipe.get("ground", true):
		shift.y -= scaled.position.y
	place = Transform3D(place.basis, shift)

	# --- merge, one surface per material ---------------------------------
	var order: Array[String] = []
	var tools := {}
	var materials := {}
	for piece in pieces:
		var key := _material_name(piece)
		if not tools.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = tool
			materials[key] = piece["material"]
			order.append(key)
		(tools[key] as SurfaceTool).append_from(
			piece["mesh"], piece["surface"], place * (piece["transform"] as Transform3D))
	if order.is_empty():
		printerr("  %s: every surface was dropped" % out_name)
		return false

	var merged := ArrayMesh.new()
	var kept: Array[Material] = []
	for key in order:
		var tool: SurfaceTool = tools[key]
		var source: Material = materials[key]
		var copy: Material = null
		if source != null:
			# Duplicated so the baked file carries its own copy rather than a
			# reference back into the .fbx -- loading which would pull the whole
			# 300-node import in behind it, which is the cost this bake exists
			# to remove. The albedo texture is a file of its own and stays a
			# reference, so every baked model shares the one atlas.
			copy = source.duplicate()
			copy.resource_name = key
			var glow: Dictionary = recipe.get("glow", {})
			if glow.has(key) and copy is BaseMaterial3D:
				# The pack marks which faces are the lit pane by giving them a
				# material of their own, and that is the half this project could
				# not have drawn itself. What it does not carry is any light: the
				# FBX exports a DiffuseColor and nothing else, because the glow
				# lived in the Unity shader the artist assigned, which does not
				# travel in the file. So the material stays the pack's and the
				# emission is this project's -- the same colour and energy the
				# window_glow row already drew its own quad at.
				var std := copy as BaseMaterial3D
				std.emission_enabled = true
				std.emission = glow[key]["colour"]
				std.emission_energy_multiplier = glow[key]["energy"]
			tool.set_material(copy)
		kept.append(copy)
		tool.commit(merged)

	# The distance ladder, put back. Godot's own scene importer builds one for
	# every mesh it imports (meshes/generate_lods=true in the .import file), and
	# re-merging surfaces by hand throws it away -- which would leave a village
	# drawing its full 39 712 triangles per house at any distance. This is the
	# same meshoptimizer pass the importer runs, on the merged surfaces.
	var builder: ImporterMesh = ImporterMesh.new()
	for surface in merged.get_surface_count():
		builder.add_surface(
			Mesh.PRIMITIVE_TRIANGLES, merged.surface_get_arrays(surface), [], {},
			kept[surface], order[surface], merged.surface_get_format(surface))
	builder.generate_lods(LOD_MERGE_ANGLE, LOD_SPLIT_ANGLE, [])

	# The triangle budget. A Mistage building is drawn at four to six times the
	# triangles of the JustCreate one standing next to it, and a village holds a
	# dozen buildings, so taking the pack at full detail would multiply what a
	# village costs to draw. `budget` says how many triangles the model may cost
	# at its closest, and the ladder that was just built is climbed -- the same
	# number of rungs on every surface, so the parts of a model stay in step --
	# until the whole thing is under it. Then the surviving indices become the
	# model, its vertices are compacted, and a fresh ladder is built below.
	#
	# reports/mistage-packs.md is where the rung each model landed on was chosen,
	# by putting the candidates side by side rather than by the number alone.
	var climbed := 0
	if recipe.has("budget"):
		climbed = _climb(builder, int(recipe["budget"]))
		if climbed > 0:
			builder = _reduce(builder, climbed, order, kept)
			builder.generate_lods(LOD_MERGE_ANGLE, LOD_SPLIT_ANGLE, [])
	var mesh := builder.get_mesh()
	var ladder := PackedStringArray()
	for surface in builder.get_surface_count():
		var rungs := PackedStringArray()
		for lod in builder.get_surface_lod_count(surface):
			rungs.append(str(builder.get_surface_lod_indices(surface, lod).size() / 3))
		ladder.append("%s %d->[%s]" % [
			order[surface],
			builder.get_surface_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3,
			", ".join(rungs),
		])

	# --- write it out ----------------------------------------------------
	var mesh_path := "%s/%s_mesh.res" % [OUT_DIR, out_name]
	var scene_path := "%s/%s.tscn" % [OUT_DIR, out_name]
	if ResourceSaver.save(mesh, mesh_path) != OK:
		printerr("  %s: could not write %s" % [out_name, mesh_path])
		return false
	mesh.take_over_path(mesh_path)

	var node := MeshInstance3D.new()
	node.name = "model"
	node.mesh = mesh
	var root_node := Node3D.new()
	root_node.name = out_name
	root_node.add_child(node)
	node.owner = root_node
	var scene := PackedScene.new()
	if scene.pack(root_node) != OK or ResourceSaver.save(scene, scene_path) != OK:
		printerr("  %s: could not write %s" % [out_name, scene_path])
		root_node.free()
		return false
	root_node.free()

	var after := mesh.get_aabb()
	var after_tris := 0
	for surface in mesh.get_surface_count():
		after_tris += mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
	print("%-24s %3d->%-3d %3d->%-3d %5d->%-6d %8.3f  %.3f x %.3f x %.3f -> %.3f x %.3f x %.3f" % [
		out_name, before_nodes, 1, before_surfaces, mesh.get_surface_count(),
		before_tris, after_tris, scale,
		before.size.x, before.size.y, before.size.z,
		after.size.x, after.size.y, after.size.z,
	])
	print("    %s  floor y=%+.3f  centre x,z=%+.3f,%+.3f" % [
		recipe["why"], after.position.y,
		after.position.x + after.size.x * 0.5, after.position.z + after.size.z * 0.5,
	])
	print("    lod ladder: %s%s" % [
		" | ".join(ladder),
		"" if climbed == 0 else "   (budget %d, ladder climbed %d rung(s))" % [
			recipe["budget"], climbed,
		],
	])
	return true


## How many rungs of the ladder to climb before the whole model is under a
## triangle budget. 0 means it already is.
static func _climb(builder: ImporterMesh, budget: int) -> int:
	var deepest := 0
	for surface in builder.get_surface_count():
		deepest = maxi(deepest, builder.get_surface_lod_count(surface))
	for rungs in range(0, deepest + 1):
		var total := 0
		for surface in builder.get_surface_count():
			total += _rung(builder, surface, rungs).size() / 3
		if total <= budget:
			return rungs
	return deepest


## Whether a surface is big enough for the budget to climb its ladder.
static func _climbable(builder: ImporterMesh, surface: int) -> bool:
	return builder.get_surface_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3 >= LOD_FLOOR


## The indices of one surface `rungs` steps up the ladder, clamped to the top of
## that surface's own ladder -- a surface with two rungs and one with five stay
## in step for as long as the shorter one lasts and then it simply stops.
static func _rung(builder: ImporterMesh, surface: int, rungs: int) -> PackedInt32Array:
	if rungs <= 0 or not _climbable(builder, surface):
		return builder.get_surface_arrays(surface)[Mesh.ARRAY_INDEX]
	var count := builder.get_surface_lod_count(surface)
	if count == 0:
		return builder.get_surface_arrays(surface)[Mesh.ARRAY_INDEX]
	return builder.get_surface_lod_indices(surface, mini(rungs, count) - 1)


## A new mesh built from the indices `rungs` up each surface's ladder, with the
## vertices no longer referenced dropped.
static func _reduce(
	builder: ImporterMesh, rungs: int, order: Array[String], materials: Array[Material],
) -> ImporterMesh:
	var out := ImporterMesh.new()
	for surface in builder.get_surface_count():
		var arrays := builder.get_surface_arrays(surface)
		out.add_surface(
			Mesh.PRIMITIVE_TRIANGLES,
			_compact(arrays, _rung(builder, surface, rungs)),
			[], {}, materials[surface], order[surface],
			builder.get_surface_format(surface))
	return out


## One surface's arrays, rebuilt to hold only the vertices these indices use.
##
## An index buffer that has lost nine tenths of its triangles still points into
## a vertex buffer holding all of the original vertices. The GPU never fetches
## the unreferenced ones, so this is memory rather than draw cost -- but it is a
## megabyte or so per building carried in a file for nothing.
static func _compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var moved := {}
	var keep := PackedInt32Array()
	var rebuilt := PackedInt32Array()
	rebuilt.resize(indices.size())
	for at in indices.size():
		var old := indices[at]
		if not moved.has(old):
			moved[old] = keep.size()
			keep.append(old)
		rebuilt[at] = moved[old]
	var out := arrays.duplicate()
	for channel in [
		Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
		Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2,
	]:
		if arrays[channel] == null:
			continue
		# ARRAY_TANGENT is four floats a vertex; every other channel here is one
		# value a vertex, so the stride does the work and the loop is the same.
		var source = arrays[channel]
		var stride := 4 if channel == Mesh.ARRAY_TANGENT else 1
		var built = source.duplicate()
		built.resize(keep.size() * stride)
		for at in keep.size():
			for step in stride:
				built[at * stride + step] = source[keep[at] * stride + step]
		out[channel] = built
	out[Mesh.ARRAY_INDEX] = rebuilt
	return out


## The FBX material name a surface carries, or "unnamed".
static func _material_name(piece: Dictionary) -> String:
	var material: Material = piece["material"]
	var name := "" if material == null else material.resource_name
	return "unnamed" if name == "" else name


## Whether a surface survives the recipe's `drop` and `only` lists.
static func _wanted(piece: Dictionary, drop: Array, only: Array) -> bool:
	var key := _material_name(piece)
	if only.size() > 0 and not only.has(key):
		return false
	return not drop.has(key)


## The box one surface fills in the root's space.
##
## Its own vertices rather than the whole mesh's AABB: an FBX mesh node may hold
## several surfaces, and taking the mesh box would put the glass back into the
## measurement the moment the glass shares a node with the wall.
static func _surface_box(piece: Dictionary) -> AABB:
	var arrays := (piece["mesh"] as Mesh).surface_get_arrays(int(piece["surface"]))
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var at: Transform3D = piece["transform"]
	var box := AABB(at * points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(at * point)
	return box


## Every drawable surface under a node, with the transform that puts it in the
## root's space.
func _collect(node: Node, at: Transform3D, into: Array[Dictionary]) -> void:
	var here := at
	if node is Node3D:
		here = at * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var tris := 0
				if arrays[Mesh.ARRAY_INDEX] != null:
					tris = arrays[Mesh.ARRAY_INDEX].size() / 3
				elif arrays[Mesh.ARRAY_VERTEX] != null:
					tris = arrays[Mesh.ARRAY_VERTEX].size() / 3
				# The override on the node wins over the one on the mesh, which
				# is where the FBX importer puts a per-instance material.
				var material := (node as MeshInstance3D).get_surface_override_material(surface)
				if material == null:
					material = mesh.surface_get_material(surface)
				into.append({
					"mesh": mesh, "surface": surface, "material": material,
					"transform": here, "tris": tris,
					"node": node.get_instance_id(),
				})
	for child in node.get_children():
		_collect(child, here, into)
