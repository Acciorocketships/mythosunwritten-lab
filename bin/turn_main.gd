extends SceneTree
## Entry point for the turn/action seam walkthrough: two commanders on one board,
## both choosing to strike, and the rule that lets a chosen blow land on the turn
## that spends it. Exit 0.
##
## Run it with:  ./run_turn.sh


func _initialize() -> void:
	for line in ScriptedTurn.play():
		print(line)
	quit(0)
