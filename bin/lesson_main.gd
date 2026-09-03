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
	var channel := ModelChannel.for_run(
		ModelRecording.lesson_exchange(), _transport(args.has("--live"), flights))
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
