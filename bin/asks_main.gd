extends SceneTree
## Entry point for the three-minds run: a person, a program and a language model
## reaching for the same thing that costs the world no time, and what the world
## charged each of them for it. Exit 0.
##
## Run it with:  ./run_asks.sh [--live]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg != "--live":
			printerr("unknown argument '%s'" % arg)
			printerr("usage: run_asks.sh [--live]")
			quit(2)
			return
	var flights := []
	var transport := _transport(args.has("--live"), flights)
	var exchange := _exchange()
	if transport.is_valid():
		exchange = ModelCall.live_exchange(exchange)
	var channel := ModelChannel.for_run(exchange, transport)
	print(channel.recorded)
	print("")
	for line in ScriptedAsks.play(channel):
		print(line)
	var settled := ModelCall.settle(flights)
	if settled > 0:
		printerr("waited for %d call%s still in flight when the run ended" % [
			settled, "" if settled == 1 else "s",
		])
	quit(0)


# The model arm's replies. Nothing new was recorded for this run: the two lines
# used are lines the recorded model actually gave in the shipped exchange -- one
# reaching for a look back, one choosing the cheapest turn in the catalogue --
# re-asked here in a different moment. They carry no prompt fingerprint, so the
# channel hands them over in the order they are written, which is what makes this
# run print the same bytes twice.
func _exchange() -> Dictionary:
	var looked := {}
	var acted := {}
	for row in ModelRecording.ROWS:
		var reply := String(row["reply"])
		if looked.is_empty() and reply.begins_with(ModelPrompt.RECALL):
			looked = row
		if acted.is_empty() and reply.begins_with(ActionCatalog.WAIT):
			acted = row
	var rows := []
	for _at in ScriptedAsks.ASKS:
		rows.append({"prompt": "", "reply": looked["reply"], "ms": looked["ms"]})
	rows.append({"prompt": "", "reply": acted["reply"], "ms": acted["ms"]})
	return {
		"rows": rows,
		"model": ModelRecording.MODEL,
		"from": "two lines %s gave in the shipped exchange recorded on %s --"
			% [ModelRecording.said_by(), ModelRecording.RECORDED_ON]
			+ " \"%s\" and \"%s\" -- re-asked here in a different moment;"
			% [looked["reply"], acted["reply"]]
			+ " nothing was recorded for this run",
	}


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
