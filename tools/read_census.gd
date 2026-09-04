extends SceneTree
## Count what the prompt reader makes of a list of recorded replies.
##
##   tools/godot/godot4 --headless --path . --script res://tools/read_census.gd -- <file>
##
## The file holds one reply per line, with newlines written as \n. Each line is
## put through `ModelPrompt` exactly as a run does and counted as one of: an
## action the reader built, a tool it recognised, or a line it refused. A reply
## whose target is a name rather than an id is counted separately: the reader
## reads the verb and leaves the target empty, which the engine then refuses.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: ... read_census.gd -- <file of replies>")
		quit(1)
		return
	var file := FileAccess.open(args[0], FileAccess.READ)
	if file == null:
		printerr("could not read %s" % args[0])
		quit(1)
		return
	var actions := 0
	var tools := 0
	var refused := 0
	var empty := 0
	var targetless := 0
	for raw in file.get_as_text().split("\n", false):
		var reply := raw.replace("\\n", "\n").replace("\\t", "\t").replace('\\"', '"')
		if reply.strip_edges() == "":
			empty += 1
			continue
		var action := ModelPrompt.action_of(reply)
		if action != null:
			actions += 1
			var fault := ActionCatalog.fault(action)
			if fault != "":
				targetless += 1
				print("  the catalogue faults it (%s): %s" % [fault, reply.substr(0, 80)])
			continue
		var tool := ModelPrompt.tool_of(reply)
		if not tool.is_empty():
			tools += 1
			continue
		refused += 1
		print("  refused: %s" % reply.substr(0, 80))
	print("actions=%d tools=%d refused-by-the-reader=%d empty=%d faulted-by-the-catalogue=%d" % [
		actions, tools, refused, empty, targetless,
	])
	quit(0)
