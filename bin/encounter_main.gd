extends SceneTree
## Play the whole cycle headless and print its transcript. Nothing else.
##
## Run it with:  ./run_encounter.sh [--ticks N] [--seed N]
##
## No window, no renderer and no input of any kind: the world generates itself
## from the seed, the combatants walk from written-down positions along
## written-down headings, the fight begins when two commanders meet and every
## move in it comes from sim/combat_policy.gd. Two runs of this print the same
## bytes, which is what tests/test_combat_snap.gd checks by running it twice as a
## subprocess.


func _initialize() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr("usage: run_encounter.sh [--seed N] [--ticks N] [--island]")
		quit(2)
		return
	for line in ScriptedEncounter.play(
		options["ticks"], options["seed"], options["island"]
	):
		print(line)
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"seed": ScriptedEncounter.SEED,
		"ticks": ScriptedEncounter.TICKS,
		# Hold the fight on the first walkable floating island instead of on the
		# ground, which is how "combat works anywhere a character can stand" is
		# a command rather than a claim.
		"island": false,
	}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--island":
			options["island"] = true
			i += 1
			continue
		if arg != "--seed" and arg != "--ticks":
			return {"error": "unknown argument '%s'" % arg}
		if i + 1 >= args.size() or not args[i + 1].is_valid_int():
			return {"error": "%s needs an integer" % arg}
		options[arg.substr(2)] = args[i + 1].to_int()
		i += 2
	if options["ticks"] < 0:
		return {"error": "--ticks cannot be negative"}
	return options
