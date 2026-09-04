extends SceneTree
## Entry point for the model run: six characters living one seeded run, one of
## whose minds is a language model, printed as one transcript. Exit 0.
##
## Run it with:  ./run_agent.sh [--seed N] [--ticks N] [--live]


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr("usage: run_agent.sh [--seed N] [--ticks N] [--live]")
		quit(2)
		return
	# Where the threads a live run starts are kept, so that a call still in
	# flight when the last tick goes by can be waited on before the engine shuts
	# down. A run that ends mid-question is the normal case, not an error.
	var flights := []
	# The transport first, because whether there is one decides which model the
	# head of this run should name. A replay names the model the rows were
	# recorded from; a live run names the one actually answering, which since
	# there are two endpoints is no longer the same thing.
	var transport := _transport(options["live"], flights)
	var exchange := ModelRecording.exchange()
	if transport.is_valid():
		exchange = ModelCall.live_exchange(exchange)
	var channel := ModelChannel.for_run(exchange, transport)
	for line in ScriptedAgent.play(
			channel, options["ticks"], options["seed"], _pacing(options["live"])):
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


# What a live run does between ticks: give the tick the length the world is
# stated to be stepped at, so that a call taking seconds lands in the tick count
# it would land in when somebody is playing rather than in a headless race. The
# pause is here rather than under `sim/`, which reads no clock.
func _pacing(live: bool) -> Callable:
	if not live:
		return Callable()
	return func() -> void:
		OS.delay_msec(ScriptedAgent.TICK_MS)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"seed": ScriptedAgent.SEED, "ticks": ScriptedAgent.TICKS, "live": false,
	}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--live":
			options["live"] = true
			i += 1
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
