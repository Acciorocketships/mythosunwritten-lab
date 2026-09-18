extends SceneTree
## Headless entry point: run the simulation for a fixed number of ticks, print
## the report, exit 0. No window, no renderer, no main scene.
##
## Run it with:  ./run_headless.sh --seed 1234 --ticks 100 [--biomes]
##
## An ordinary run reports the world and the handful of characters living in it,
## with everything they chose and everything the engine answered written into the
## report at the tick it happened on. `--scenario NAME` stands a named cast up in
## place of that one and lives it forward; `--frozen` photographs it instead.

const DEFAULT_SEED := 1234
const DEFAULT_TICKS := 100

## File extensions that only exist to be looked at. --assets counts every file
## in the project carrying one, and how many of them this process has loaded.
const VISUAL_EXTENSIONS := [
	"tscn", "scn", "glb", "gltf", "obj", "fbx", "dae",
	"png", "jpg", "jpeg", "webp", "svg", "exr", "hdr",
	"tres", "res", "material", "mesh", "gdshader",
	# Type is something that only exists to be looked at too. Added when the
	# character-sheet panel landed, so that "a headless run loads no font" is a
	# claim this report can actually answer.
	"ttf", "otf", "woff", "woff2", "fnt",
]

## Directories the asset scan does not walk: the engine binary and its home, and
## the write-ups. Neither is part of the game.
##
## Full paths rather than bare names, and that is a correction rather than a
## style: as bare names they matched *any* directory so called at any depth, and
## the adopted base has a `scripts/terrain/tools/` of its own -- which quietly
## hid two of its scene scripts from the purity scan until the render seam came
## to lean on it.
const UNSCANNED := ["res://tools", "res://reports"]


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr(
			"usage: run_headless.sh [--seed N] [--ticks N] [--start X Z]"
			+ " [--scenario NAME] [--frozen]"
			+ " [--biomes] [--water] [--islands] [--settlements]"
			+ " [--scatter] [--enemies] [--board] [--board-at X Z]"
			+ " [--snap] [--board-sweep]"
			+ " [--assets] [--digest]"
			+ "\nscenarios: " + " ".join(Simulation.SCENARIOS)
		)
		quit(2)
		return

	var sim := Simulation.new(options["seed"])
	# The scenario first, because it stands up a cast of its own in place of the
	# world's and puts the view where that cast is; --start then has the last word
	# on where the view goes, which is what somebody typing both means.
	var scenario := String(options["scenario"])
	# The two scenarios with model-driven minds need a channel of replies, and
	# where replies come from is the entry point's business: the shipped
	# recorded exchange, so a headless run of them still needs no key, no
	# network and no model.
	var minds: ModelChannel = null
	if scenario == Simulation.SCENARIO_BARGAIN:
		minds = ModelChannel.for_run(ModelRecording.bargain_exchange())
	elif scenario == Simulation.SCENARIO_AGENT:
		minds = ModelChannel.for_run(ModelRecording.exchange())
	if not sim.begin_scenario(scenario, options["frozen"], minds):
		printerr("headless unknown or unavailable --scenario %s" % scenario)
		quit(2)
		return
	if options["start"]:
		sim.world.place_observer(options["start_x"], options["start_z"])
	for line in sim.run(options["ticks"]):
		print(line)
	if options["biomes"]:
		# The biome map itself, on a fixed lattice around the origin, so two
		# runs can be compared position by position.
		for line in sim.biome_report():
			print(line)
	if options["water"]:
		# The water map itself, on its own fixed lattice, for the same reason.
		for line in sim.water_report():
			print(line)
	if options["islands"]:
		# Every island in a fixed square of the world, for the same reason
		# again: it answers for the field rather than for what got built.
		for line in sim.island_report():
			print(line)
	if options["settlements"]:
		# Every village in a fixed square of the world, with its roads and its
		# bridges. It answers for the field rather than for what got streamed.
		for line in sim.settlement_report():
			print(line)
	if options["scatter"]:
		# Everything the scatter layer put down in a fixed square of chunks,
		# with what it is, where it stands and how big it came out. It answers
		# for the layer rather than for what got streamed.
		for line in sim.scatter_report():
			print(line)
	if options["enemies"]:
		# Every enemy the field places in a fixed square of the world, with how
		# far from spawn it stands and the level it is actually stood up at. It
		# answers for the field rather than for whatever a particular walk
		# happened to meet.
		for line in sim.enemy_report():
			print(line)
	if options["board"]:
		# The tactical lattice over a fixed set of overlapping rectangles, cell
		# by cell, and one board read on a floating island's top. It answers for
		# the lattice rather than for whatever is underfoot -- unless --board-at
		# named a place, which prints the one board read there instead. That is
		# how the ground a particular fight was held on gets printed: the board
		# is a function of the place and the seed, so a board read there now is
		# the board that fight was played on.
		for line in sim.board_report(
			CombatBoardBuilder.DEFAULT_SPAN, 40.0, 2, options["board_at"]
		):
			print(line)
	if options["snap"]:
		# Where a fight can be held, measured over a fixed grid of candidate
		# places. This is where the scenario's meeting place comes from.
		for line in sim.snap_report():
			print(line)
	if options["board_sweep"]:
		# What each candidate cell size costs, measured against a fine grid of
		# the terrain query's own answers. This is where the chosen cell size
		# comes from.
		for line in sim.board_sweep_report():
			print(line)
	if options["assets"]:
		# What this process has actually loaded. Asked after the run, so it
		# answers for a whole world having been generated and stepped.
		for line in _asset_report():
			print(line)
	if options["digest"]:
		# The same fingerprint the render shell's stop line carries, printed in
		# the same `digest=` spelling, so the two runs are compared by grepping
		# one word out of each.
		print("digest=%s" % sim.world.digest())
	quit(0)


## What visual material this process has loaded, counted against what exists.
##
## A headless run must load none of it: no scene, no model, no texture, and not
## one script of the render layer. That is checked from outside rather than from
## inside the render layer, because a counter kept by the asset table could only
## be read by loading the asset table, which is the very thing that must not
## happen. The engine's own resource cache has no such problem -- it knows what
## has been loaded without any of it having been.
##
## The simulation's own scripts are counted too, and are expected to be loaded.
## Without that line the report could not be told apart from one taken in a
## process that had loaded nothing at all.
##
## Since the base adoption there is a fourth group, and it is the one that
## matters most now. The world is drawn by the adopted base's own code under
## `res://scripts/`, `res://characters/` and `res://ui/` -- and the simulation
## legitimately reads part of that same directory, because its ground is the
## adopted heightfield (`sim/adopted_ground.gd` calls `TerrainSurfaceField`,
## `WaterField`, `Helper`). "The simulation loads nothing of the render layer"
## can therefore no longer be answered by a directory name. It is answered by
## what a file *is*: a script that `extends` a scene-tree type only exists
## inside a running tree, so a headless process that has loaded one has loaded
## a piece of the picture. Those are the adopted files this report insists on
## finding uncached, and they include the terrain streamer, the grass streamer,
## the camera, the controllers, the character and every panel of their
## interface.
func _asset_report() -> PackedStringArray:
	var visual_files := PackedStringArray()
	var render_scripts := PackedStringArray()
	var adopted_scene_scripts := PackedStringArray()
	var sim_scripts := PackedStringArray()
	for path in _project_files("res://"):
		var extension := path.get_extension().to_lower()
		if extension in VISUAL_EXTENSIONS:
			visual_files.append(path)
		elif extension == "gd":
			if _is_an_adopted_scene_script(path):
				adopted_scene_scripts.append(path)
			elif path.begins_with("res://render/"):
				render_scripts.append(path)
			elif path.begins_with("res://sim/"):
				sim_scripts.append(path)

	var report := PackedStringArray()
	for group in [
		["visual-files", visual_files],
		["render-scripts", render_scripts],
		["adopted-scene-scripts", adopted_scene_scripts],
		["sim-scripts", sim_scripts],
	]:
		var label: String = group[0]
		var paths: PackedStringArray = group[1]
		var loaded := PackedStringArray()
		for path in paths:
			if ResourceLoader.has_cached(path):
				loaded.append(path)
		# Named, up to a few: on the groups that must be empty, which file got
		# loaded is the whole diagnosis. On the one that must not be, the count
		# is the point and the names are noise.
		var named := loaded.slice(0, 4)
		if loaded.size() > named.size():
			named.append("+%d more" % (loaded.size() - named.size()))
		report.append("assets %s found=%d loaded=%d%s" % [
			label, paths.size(), loaded.size(),
			"" if loaded.is_empty() else " -> " + ",".join(named),
		])
	# The adopted scene scripts are named whether or not any of them loaded.
	# The group is small, it is the one the render seam's purity argument rests
	# on, and a count alone could be zero because the scan found nothing rather
	# than because the run loaded nothing.
	for path in adopted_scene_scripts:
		report.append("assets adopted-scene-script %s cached=%d" % [
			path, 1 if ResourceLoader.has_cached(path) else 0,
		])
	return report


## The adopted directories whose scripts may be either: part of the fields the
## simulation reads, or part of the picture. Which one a file is is decided by
## what it extends, below.
const ADOPTED_DIRS := [
	"res://scripts/", "res://characters/", "res://ui/",
]

## The scene-tree types a script can extend. A script that extends one of these
## cannot do anything outside a running tree, so it is a piece of the picture
## however it is filed.
const SCENE_TREE_BASES := [
	"Node", "Node2D", "Node3D", "CanvasLayer", "CanvasItem", "Control",
	"CharacterBody3D", "RigidBody3D", "StaticBody3D", "Area3D", "Camera3D",
	"MeshInstance3D", "MultiMeshInstance3D", "Sprite2D", "Sprite3D",
	"Label", "RichTextLabel", "Button", "Panel", "PanelContainer", "TextureRect",
	"ColorRect", "NinePatchRect", "VBoxContainer", "HBoxContainer",
	"GridContainer", "MarginContainer", "CenterContainer", "ScrollContainer",
	"SubViewport", "WorldEnvironment", "DirectionalLight3D", "OmniLight3D",
	"GPUParticles3D", "AnimationPlayer", "AnimationTree", "BoneAttachment3D",
	"Skeleton3D", "SceneTree",
]


## Whether an adopted script only exists inside a scene tree.
##
## Read off the file's own `extends` line rather than off a list kept here, so a
## file the base adds tomorrow is classified by what it is. A script extending
## another script by path (`extends "res://..."`) is followed one step, which is
## how the base's panels reach their own base class.
func _is_an_adopted_scene_script(path: String) -> bool:
	var adopted := false
	for directory in ADOPTED_DIRS:
		if path.begins_with(directory):
			adopted = true
			break
	if not adopted:
		return false
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return false
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.begins_with("extends "):
			continue
		var base := trimmed.substr(8).strip_edges()
		if base.begins_with("\""):
			# `extends "res://..."` -- ask the file it names instead.
			var other := base.trim_prefix("\"").trim_suffix("\"")
			return other != path and _is_an_adopted_scene_script(other)
		return base in SCENE_TREE_BASES
	return false


## Every file in the project, minus the hidden directories and the ones that
## hold no game content.
func _project_files(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if entry.begins_with(".") or full in UNSCANNED:
			entry = dir.get_next()
			continue
		if dir.current_is_dir():
			found.append_array(_project_files(full))
		else:
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"seed": DEFAULT_SEED,
		"ticks": DEFAULT_TICKS,
		"biomes": false,
		"water": false,
		"islands": false,
		"settlements": false,
		"scatter": false,
		"enemies": false,
		"board": false,
		# Places to read a board at, instead of the fixed grid around the origin.
		"board_at": [] as Array[Vector2],
		"board_sweep": false,
		"snap": false,
		"assets": false,
		# Print the world's digest after the run: the same fingerprint the
		# render shell reports at its stop line, so a headless run and a
		# rendered run of one seed can be compared state for state.
		"digest": false,
		# Which named scenario to set out, and whether to photograph it rather
		# than live it. Empty means the ordinary world and the cast that lives
		# in it.
		"scenario": Simulation.SCENARIO_NONE,
		"frozen": false,
		# Where the observer starts. Off by default, so the world an ordinary
		# run reports is the world the origin gets; with it, a run can be aimed
		# at a particular place -- an island, for instance.
		"start": false,
		"start_x": 0.0,
		"start_z": 0.0,
	}
	var i := 0
	while i < args.size():
		var arg := args[i]
		match arg:
			"--biomes":
				options["biomes"] = true
				i += 1
			"--water":
				options["water"] = true
				i += 1
			"--islands":
				options["islands"] = true
				i += 1
			"--settlements":
				options["settlements"] = true
				i += 1
			"--scatter":
				options["scatter"] = true
				i += 1
			"--enemies":
				options["enemies"] = true
				i += 1
			"--board":
				options["board"] = true
				i += 1
			"--board-at":
				if i + 2 >= args.size():
					return {"error": "--board-at needs two values"}
				if not args[i + 1].is_valid_float() or not args[i + 2].is_valid_float():
					return {"error": "--board-at needs two numbers"}
				options["board"] = true
				(options["board_at"] as Array[Vector2]).append(Vector2(
					args[i + 1].to_float(), args[i + 2].to_float()
				))
				i += 3
			"--snap":
				options["snap"] = true
				i += 1
			"--board-sweep":
				options["board_sweep"] = true
				i += 1
			"--assets":
				options["assets"] = true
				i += 1
			"--digest":
				options["digest"] = true
				i += 1
			"--frozen":
				options["frozen"] = true
				i += 1
			"--scenario":
				if i + 1 >= args.size():
					return {"error": "--scenario needs a name"}
				options["scenario"] = args[i + 1]
				i += 2
			"--start":
				if i + 2 >= args.size():
					return {"error": "--start needs two values"}
				if not args[i + 1].is_valid_float() or not args[i + 2].is_valid_float():
					return {"error": "--start needs two numbers"}
				options["start"] = true
				options["start_x"] = args[i + 1].to_float()
				options["start_z"] = args[i + 2].to_float()
				i += 3
			"--seed", "--ticks":
				if i + 1 >= args.size():
					return {"error": "%s needs a value" % arg}
				var value := args[i + 1]
				if not value.is_valid_int():
					return {"error": "%s needs an integer, got '%s'" % [arg, value]}
				options[arg.substr(2)] = value.to_int()
				i += 2
			_:
				return {"error": "unknown argument '%s'" % arg}
	if options["ticks"] < 0:
		return {"error": "--ticks cannot be negative"}
	return options
