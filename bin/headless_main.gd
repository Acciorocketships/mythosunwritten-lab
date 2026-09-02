extends SceneTree
## Headless entry point: run the simulation for a fixed number of ticks, print
## the report, exit 0. No window, no renderer, no main scene.
##
## Run it with:  ./run_headless.sh --seed 1234 --ticks 100 [--chunks] [--biomes]

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
const UNSCANNED := ["tools", "reports"]


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr(
			"usage: run_headless.sh [--seed N] [--ticks N] [--start X Z]"
			+ " [--chunks] [--biomes] [--water] [--islands] [--settlements]"
			+ " [--scatter] [--board] [--snap] [--board-sweep] [--assets]"
		)
		quit(2)
		return

	var sim := Simulation.new(options["seed"])
	if options["start"]:
		sim.world.place_observer(options["start_x"], options["start_z"])
	for line in sim.run(options["ticks"]):
		print(line)
	if options["chunks"]:
		# Every chunk still loaded at the end, with the fingerprint of the
		# geometry the mesher built for it.
		for line in sim.chunk_report():
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
	if options["board"]:
		# The tactical lattice over a fixed set of overlapping rectangles, cell
		# by cell, and one board read on a floating island's top. It answers for
		# the lattice rather than for whatever is underfoot.
		for line in sim.board_report():
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
func _asset_report() -> PackedStringArray:
	var visual_files := PackedStringArray()
	var render_scripts := PackedStringArray()
	var sim_scripts := PackedStringArray()
	for path in _project_files("res://"):
		var extension := path.get_extension().to_lower()
		if extension in VISUAL_EXTENSIONS:
			visual_files.append(path)
		elif extension == "gd":
			if path.begins_with("res://render/"):
				render_scripts.append(path)
			elif path.begins_with("res://sim/"):
				sim_scripts.append(path)

	var report := PackedStringArray()
	for group in [
		["visual-files", visual_files],
		["render-scripts", render_scripts],
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
	return report


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
		if entry.begins_with(".") or entry in UNSCANNED:
			entry = dir.get_next()
			continue
		var full := dir_path.path_join(entry)
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
		"chunks": false,
		"biomes": false,
		"water": false,
		"islands": false,
		"settlements": false,
		"scatter": false,
		"board": false,
		"board_sweep": false,
		"snap": false,
		"assets": false,
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
			"--chunks":
				options["chunks"] = true
				i += 1
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
			"--board":
				options["board"] = true
				i += 1
			"--snap":
				options["snap"] = true
				i += 1
			"--board-sweep":
				options["board_sweep"] = true
				i += 1
			"--assets":
				options["assets"] = true
				i += 1
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
