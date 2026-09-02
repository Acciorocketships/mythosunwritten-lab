extends SceneTree
## Entry point for the control-loop walkthrough: the cadence, section 2.2's four
## interruptions one scene each, the bias measured with and without itself, and
## a decision function that takes forty ticks to answer. Exit 0.
##
## Run it with:  ./run_loop.sh


func _initialize() -> void:
	for line in ScriptedLoop.report():
		print(line)
	quit(0)
