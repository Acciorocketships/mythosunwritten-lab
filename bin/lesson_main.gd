extends SceneTree
## Entry point for the lesson comparison: one character, one moment, and the same
## question put with no lesson in its memory and with each of three. Exit 0.
##
## Run it with:  ./run_lesson.sh [--live]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg != "--live":
			printerr("unknown argument '%s'" % arg)
			printerr("usage: run_lesson.sh [--live]")
			quit(2)
			return
	var flights := []
	# The transport first, because whether there is one decides which model the
	# head of this run should name. A replay names the model the rows were
	# recorded from; a live run names the one actually answering, which since
	# there are two endpoints is no longer the same thing.
	var transport := _transport(args.has("--live"), flights)
	var exchange := ModelRecording.lesson_exchange()
	if transport.is_valid():
		exchange = ModelCall.live_exchange(exchange)
	var channel := ModelChannel.for_run(exchange, transport)
	for line in ScriptedLesson.play(channel):
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
