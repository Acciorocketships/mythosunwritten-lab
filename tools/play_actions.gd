extends SceneTree
## Every atomic action performed from a key press, in one seeded run.
##
##   ./tools/play_actions.sh
##
## The play scenario is set out (`sim/scripted_play.gd`), the character the world
## follows is handed to a person (`Simulation.hand_over_followed`'s own call,
## `WorldCast.hand_over`), and a written-down script of key presses is fed
## through `PlayerControls` -- the same file the shell feeds real presses through
## -- into that character's `LiveChoice`. What comes back is one row per action
## the engine actually resolved: the verb, the tick it was answered on, what it
## was aimed at, and the engine's own sentence about it.
##
## The run is `TestPlayerActions.play()`, which is also what the suite asserts
## over, so this table and the suite cannot disagree: they are one run played by
## one script.
##
## What it draws: nothing. This is the headless half of the evidence, and the
## other half is the same scenario photographed from the built shell with
## `--play --input`.


func _initialize() -> void:
	var run := TestPlayerActions.play()
	print("seed %d, driving #%d" % [
		(run["world"] as SimWorld).world_seed, int(run["id"]),
	])
	for line in TestPlayerActions.table_lines(run):
		print(line)
	var refused := 0
	for row in run["table"]:
		if not bool(row["ok"]):
			refused += 1
	print("")
	print("%d actions performed, %d of them refused, world at tick %d" % [
		(run["table"] as Array).size(), refused, (run["world"] as SimWorld).tick,
	])
	for note in run["notes"]:
		print("  the interface said: %s" % note)
	# What the other side did about all this, in the loop's own words: the
	# person's bargain was denied by somebody who is not the person, which is the
	# half of a trade a table of the person's own actions cannot show.
	print("")
	print("what the other side did:")
	for line in (run["world"] as SimWorld).loop.journal:
		if line.contains("trade_") and not line.contains("Fen"):
			print("  %s" % line)
	quit(0)
