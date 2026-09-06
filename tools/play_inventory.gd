extends SceneTree
## An inventory operated from key presses, in one seeded run.
##
##   ./tools/play_inventory.sh
##
## The play scenario is set out (`sim/scripted_play.gd`), the character the world
## follows is handed to a person, and a written-down script of key presses is fed
## through `PlayerControls` -- the same file the shell feeds real presses through
## -- into that character's `LiveChoice`. Three tables come back: what the engine
## answered to each press, what the character could do after each change of gear,
## and what was refused.
##
## The run is `TestPlayerInventory.play()`, which is also what the suite asserts
## over, so these tables and the suite cannot disagree: they are one run played by
## one script.
##
## What it draws: nothing. This is the headless half of the evidence, and the
## other half is the same scenario photographed from the built shell with
## `--play --sheet --input`.


func _initialize() -> void:
	var run := TestPlayerInventory.play()
	var world: SimWorld = run["world"]
	print("seed %d, driving #%d" % [world.world_seed, int(run["id"])])
	print("")
	for line in TestPlayerInventory.table_lines(run):
		print(line)

	print("")
	print("what the gear changed, in the loadout's own terms:")
	for line in TestPlayerInventory.loadout_lines(run):
		print("  %s" % line)

	print("")
	print("what the rules refused, in the engine's words:")
	for row in run["table"]:
		if not bool(row["ok"]):
			print("  %-14s t=%-5d %s" % [row["verb"], int(row["tick"]), row["reason"]])

	print("")
	print("money %d -> %d, health %d -> %d, world at tick %d" % [
		int(run.get("money_before", 0)), int(run.get("money_after", 0)),
		int(run.get("health_before", 0)), int(run.get("health_after", 0)),
		world.tick,
	])
	for note in run["notes"]:
		print("  the interface said: %s" % note)
	quit(0)
