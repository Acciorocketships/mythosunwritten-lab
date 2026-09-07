extends SceneTree
## Entry point for the record of a blow: two commanders on one board, one played
## by hand and one by its own decision function, and the one record both of their
## blows are written into. Exit 0.
##
## Run it with:  ./run_strike.sh


func _initialize() -> void:
	for line in ScriptedStrike.play():
		print(line)
	quit(0)
