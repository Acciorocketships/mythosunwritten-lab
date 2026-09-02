extends SceneTree
## The one asymmetry the review looked for in the other direction: something the
## library gives a program-driven character that it does not give a person-driven
## one.
##
## `DecisionSource.scripted` wraps a rule and can be handed straight to
## `ControlLoop`. `DecisionSource.recorded` -- the queue-shaped reading of a
## person's written-down list -- is spent by being asked, because the loop asks
## again every `REVIEW_EVERY` ticks. `DecisionSource.plan` is the same list read
## at the position its character has actually reached, and is what the scenario
## puts on Wren's sheet. This counts the difference on the checked-in scenario
## rather than saying that there is one.
##
## Run:  tools/godot/godot4 --headless --path . --script res://tools/critic_recorded_drain_probe.gd


func _initialize() -> void:
	print("")
	print("=== F -- the same ten choices, read two ways, under one loop")
	print("  REVIEW_EVERY=%d  CONTINUE_BIAS=%.2f  go_to costs %dt" % [
		ControlLoop.REVIEW_EVERY, ControlLoop.CONTINUE_BIAS,
		ActionCatalog.occupies_of(ActionCatalog.GO_TO)])

	for how in ["read as a plan (DecisionSource.plan)", "read as a queue (DecisionSource.recorded)"]:
		var scene := ScriptedScenario.stage_for(ScriptedScenario.SEED)
		var loop := ControlLoop.on(scene, ScriptedScenario.LOOP_SEED)
		ScriptedScenario.drive(scene)
		var wren: Combatant = null
		for one in scene.actors:
			var sheet := _sheet(one)
			if sheet != null and sheet.character_name == ScriptedScenario.WREN:
				wren = one
		var choices := ScriptedScenario.wren_choices(scene)
		if how.begins_with("read as a queue"):
			_sheet(wren).decide = DecisionSource.recorded(choices)
		for _step in ScriptedScenario.TICKS:
			loop.step()
			ScriptedScenario._fight_step(scene)
		var source: Callable = _sheet(wren).decide
		var left := 0
		while left <= choices.size() and source.call(scene, wren) != null:
			left += 1
		print("  [%d of %d resolved, %d left in the source, %d accounted for] %s"
			% [loop.actions_of(wren.id), choices.size(), left,
				loop.actions_of(wren.id) + left, how]
			+ " -- %d re-evaluations over %d ticks" % [
				int(loop.counts()["reviews"]), ScriptedScenario.TICKS])
		ScriptedScenario.release(scene)
	quit(0)


func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
