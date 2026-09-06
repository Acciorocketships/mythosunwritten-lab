extends SceneTree
## A whole fight played from key presses, in one seeded run.
##
##   ./tools/play_combat.sh
##
## The battle scenario is set out (`ScriptedEncounter.muster_played`, which is the
## encounter with the camera on one of the two who fight), the character the world
## follows is handed to a person (`Simulation.hand_over_followed`), and a
## written-down script of key presses is fed through `BoardControls` -- the same
## file the shell feeds real presses through -- into the turn the simulation holds
## open for them. What comes back is one row per thing done: the tick, the round,
## who did it, what they did and the engine's own sentence about it.
##
## The run is `TestPlayerCombat.play()`, which is also what the suite asserts
## over, so this trace and the suite cannot disagree: they are one run played by
## one script.
##
## What it draws: nothing. This is the headless half of the evidence, and the
## other half is the same scenario photographed from the built shell with
## `--scenario battle --play --readout --input`.


func _initialize() -> void:
	var run := TestPlayerCombat.play()
	var sim: Simulation = run["sim"]
	print("seed %d, driving #%d" % [sim.world.world_seed, sim.driven_id])
	print("")
	for line in TestPlayerCombat.trace_lines(run):
		print(line)
	print("")
	print("entered the fight on tick %s, left it on tick %s, took %d turns" % [
		str(run["entered"]), str(run["left"]), int(run["turns"]),
	])
	var spent: Dictionary = run["spent"]
	if not spent.is_empty():
		print("on round %s, a second of each was refused:" % str(spent["round"]))
		print("    move   -> %s" % spent["move"])
		print("    action -> %s" % spent["swing"])
		print("    minion -> %s" % spent["minion"])
	var waiting: Dictionary = run["cooldown"]
	if not waiting.is_empty():
		print("on round %s the heavy action had %d of its %d turns left -> %s" % [
			str(waiting["round"]), int(waiting["remaining"]),
			int(waiting["cooldown"]), waiting["reason"],
		])
	var turned: Dictionary = run["facing"]
	if not turned.is_empty():
		print("facing %s covered %s" % [
			turned["before_name"], _cells(turned["before"])])
		print("facing %s covered %s" % [
			turned["after_name"], _cells(turned["after"])])
		print("    and the turn cost %s" % ("something" if turned["cost"] else "nothing"))
	print("")
	print("what the fight wrote down:")
	for line in sim.world.combat_lines:
		print("  %s" % line)
	quit(0)


func _cells(cells: Array) -> String:
	var written := PackedStringArray()
	for cell in cells:
		written.append("(%d,%d)" % [cell.x, cell.y])
	return "none" if written.is_empty() else " ".join(written)
