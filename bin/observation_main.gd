extends SceneTree
## Entry point for the observation walkthrough: what each of five characters can
## see at two stated ticks of the shipped scenario, printed and measured. Exit 0.
##
## Run it with:  ./run_observation.sh [--seed N]


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr("usage: run_observation.sh [--seed N]")
		quit(2)
		return
	for line in ScriptedObservation.walk(options["seed"]):
		print(line)
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {"seed": ScriptedObservation.SEED}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg != "--seed":
			return {"error": "unknown argument '%s'" % arg}
		if i + 1 >= args.size() or not args[i + 1].is_valid_int():
			return {"error": "%s needs an integer" % arg}
		options[arg.substr(2)] = args[i + 1].to_int()
		i += 2
	return options
