extends SceneTree
## Play the scripted match headless and print its transcript. Nothing else.
##
## Run it with:  ./run_match.sh
##
## No window, no renderer, no world generation, and no input of any kind -- the
## board, the pieces and every decision are constants in sim/scripted_match.gd.
## Two runs of this print the same bytes, which is what tests/test_combat_resolution.gd
## checks by running it twice as a subprocess.


func _initialize() -> void:
	for line in ScriptedMatch.play():
		print(line)
	quit(0)
