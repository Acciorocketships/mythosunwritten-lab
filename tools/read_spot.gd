extends SceneTree
## Print, line by line, what the prompt reader makes of a reply and what the
## action catalogue then says about it.
##
##   tools/godot/godot4 --headless --path . --script res://tools/read_spot.gd -- <file>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var file := FileAccess.open(args[0], FileAccess.READ)
	for reply in file.get_as_text().split("\n", false):
		var action := ModelPrompt.action_of(reply)
		var tool := ModelPrompt.tool_of(reply)
		print("%-28s | action=%-10s params=%-30s | catalogue: %s | tool=%s" % [
			reply, "-" if action == null else action.kind,
			"-" if action == null else str(action.params),
			"nothing was chosen" if action == null else ActionCatalog.fault(action),
			str(tool),
		])
	quit(0)
