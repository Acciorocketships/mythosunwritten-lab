extends SceneTree
## Entry point for the territory run: section 6's claim that winning battles and
## winning hearts both shift ownership, measured as two runs of one world that
## differ in exactly one written rule. Exit 0.
##
## Run it with:  ./run_territory.sh [--seed N] [--ticks N] [--arm fight|friendship]


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr("usage: run_territory.sh [--seed N] [--ticks N] [--arm fight|friendship]")
		quit(2)
		return
	# The recorded goodwill exchange, replayed: no key, no network, no model.
	# The friendship run's three deed questions are answered by position out of
	# it, and each reply says in the transcript that its prompt is not the one
	# recorded -- see the note at the head of `sim/scripted_territory.gd`.
	var channel := ModelChannel.for_run(ModelRecording.goodwill_exchange())
	for line in ScriptedTerritory.play(
			channel, options["ticks"], options["seed"], options["arms"]):
		print(line)
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"seed": ScriptedTerritory.SEED, "ticks": ScriptedTerritory.TICKS,
		"arms": ScriptedTerritory.ARMS,
	}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--arm":
			if i + 1 >= args.size() or not ScriptedTerritory.ARMS.has(args[i + 1]):
				return {"error": "--arm needs one of: %s" % ", ".join(ScriptedTerritory.ARMS)}
			options["arms"] = [String(args[i + 1])]
			i += 2
			continue
		if arg != "--seed" and arg != "--ticks":
			return {"error": "unknown argument '%s'" % arg}
		if i + 1 >= args.size() or not args[i + 1].is_valid_int():
			return {"error": "%s needs an integer" % arg}
		options[arg.substr(2)] = args[i + 1].to_int()
		i += 2
	if options["ticks"] < 0:
		return {"error": "--ticks cannot be negative"}
	return options
