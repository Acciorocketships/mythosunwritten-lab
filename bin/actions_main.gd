extends SceneTree
## Entry point for the atomic-action walkthrough: print the one list, play every
## action once, fight one round, and drive the same choice through a person's
## recorded choices and through a rule. Exit 0.
##
## Run it with:  ./run_actions.sh


func _initialize() -> void:
	for line in ScriptedActions.report():
		print(line)
	quit(0)
