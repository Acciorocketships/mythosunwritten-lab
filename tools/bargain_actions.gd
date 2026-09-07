extends SceneTree
## A person buys a specific named item from a model-driven trader, in one
## seeded run, printed end to end.
##
##   ./tools/bargain_actions.sh
##
## The bargain stage is set out (`sim/scripted_bargain.gd`): the play scenario's
## cast on the play scenario's seed, with the trader Hob deciding through a
## language model -- the shipped recording's replies, so the run needs no key,
## no network and no model, and two runs print identical bytes. A written-down
## script of key presses drives the person through `PlayerControls`, the same
## file the shell feeds real presses through, on the same ticks `--input`
## presses them.
##
## The run is `TestBargain.play()`, which is also what the suite asserts over,
## so this table and the suite cannot disagree: they are one run played by one
## script.


func _initialize() -> void:
	var run := TestBargain.play()
	var world: SimWorld = run["world"]
	print("seed %d, driving #%d, trader %s driven by a model" % [
		world.world_seed, int(run["id"]), TestBargain.HOB,
	])
	print("channel: %s" % (run["channel"] as ModelChannel).why)
	print("")
	print("the same run from a shell:  ./run_render.sh --scenario bargain --play \\")
	print("    --input \"%s\"" % TestBargain.input_line())
	print("")
	print("every key pressed, and what the controls were left holding:")
	for row in run["presses"]:
		print("  t=%-3d %-6s chose %-58s taking=%s coins=%d" % [
			int(row["tick"]), String(row["key"]), String(row["chose"]),
			"-" if String(row["taking"]) == "" else String(row["taking"]),
			int(row["coins"]),
		])
	for note in run["notes"]:
		print("  the interface said: %s" % note)
	print("")
	print("every answer the engine gave the person:")
	for row in run["table"]:
		print("  t=%-3d %s" % [int(row["tick"]), String(row["line"])])
	print("")
	print("the ticks either of the two was shown the other's pack, both directions:")
	var opened := -1
	var shut := -1
	for row in run["shown"]:
		if opened < 0:
			opened = int(row["tick"])
		shut = int(row["tick"])
	if opened < 0:
		print("  never")
	else:
		var first: Dictionary = (run["shown"] as Array)[0]
		print("  t=%d to t=%d; at t=%d the person was shown [%s] and the trader [%s]" % [
			opened, shut, int(first["tick"]),
			", ".join(PackedStringArray(first["fen_sees"])),
			", ".join(PackedStringArray(first["hob_sees"])),
		])
	print("")
	print("what the whole world did about it, in the loop's own words:")
	for line in world.loop.journal:
		print("  %s" % line)
	quit(0)
