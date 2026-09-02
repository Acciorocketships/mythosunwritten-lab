extends SceneTree
## Entry point for the skirmish: a patrol of two, one stranger who walks into
## them, and the fight that follows, printed as one transcript. Exit 0.
##
## Run it with:  ./run_skirmish.sh [--seed N] [--ticks N]


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr("usage: run_skirmish.sh [--seed N] [--ticks N]")
		quit(2)
		return
	for line in ScriptedSkirmish.play(options["ticks"], options["seed"]):
		print(line)
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {"seed": ScriptedSkirmish.SEED, "ticks": ScriptedSkirmish.TICKS}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg != "--seed" and arg != "--ticks":
			return {"error": "unknown argument '%s'" % arg}
		if i + 1 >= args.size() or not args[i + 1].is_valid_int():
			return {"error": "%s needs an integer" % arg}
		options[arg.substr(2)] = args[i + 1].to_int()
		i += 2
	if options["ticks"] < 0:
		return {"error": "--ticks cannot be negative"}
	return options
