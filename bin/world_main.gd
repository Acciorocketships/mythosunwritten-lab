extends SceneTree
## Entry point for the orchestrator run: one world, one character walking a
## written-down plan through it, and the world's dungeon master looking at that
## world every so often and changing it through the operations the engine
## exposes. Exit 0.
##
## Run it with:  ./run_world.sh [--seed N] [--ticks N] [--every N] [--live]


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr("usage: run_world.sh [--seed N] [--ticks N] [--every N] [--live]")
		quit(2)
		return
	var flights := []
	var channel := ModelChannel.for_run(
		ModelRecording.world_exchange(), _transport(options["live"], flights))
	for line in ScriptedWorld.play(
			channel, options["ticks"], options["seed"], options["every"]):
		print(line)
	var settled := ModelCall.settle(flights)
	if settled > 0:
		printerr("waited for %d call%s still in flight when the run ended" % [
			settled, "" if settled == 1 else "s",
		])
	quit(0)


# How a live run calls a model, and nothing at all otherwise. The transport lives
# outside the simulation -- see the note at the head of `sim/model_channel.gd` --
# and is handed in from here, which is also where the credential is read.
func _transport(live: bool, flights: Array) -> Callable:
	if not live:
		return Callable()
	var credentials := ModelCall.credentials()
	if not credentials["ok"]:
		printerr("--live: %s, so the recorded exchange is replayed instead"
			% credentials["why"])
		return Callable()
	return ModelCall.on_a_thread(ModelCall.key(), flights)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"seed": ScriptedWorld.SEED, "ticks": ScriptedWorld.TICKS,
		"every": ScriptedWorld.EVERY, "live": false,
	}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--live":
			options["live"] = true
			i += 1
			continue
		if arg != "--seed" and arg != "--ticks" and arg != "--every":
			return {"error": "unknown argument '%s'" % arg}
		if i + 1 >= args.size() or not args[i + 1].is_valid_int():
			return {"error": "%s needs an integer" % arg}
		options[arg.substr(2)] = args[i + 1].to_int()
		i += 2
	if options["ticks"] < 0:
		return {"error": "--ticks cannot be negative"}
	if options["every"] < 1:
		return {"error": "--every has to be at least 1"}
	return options
