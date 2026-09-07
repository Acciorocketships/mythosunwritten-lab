extends SceneTree
## Review probe (W-territory-review): does a character a person drives accrue
## relationship edges and own ground on exactly the path a program-driven one
## does?
##
## The friendship arm of the territory run is played twice. Once as shipped:
## Wren driven by the written rule `ScriptedTerritory._winning_hearts` through
## `DecisionSource.scripted`. Once with Wren driven through
## `DecisionSource.live` -- the person's input surface, a `LiveChoice` holder --
## with the person pressing, at the top of every tick, the same choice the
## written rule would make at that moment. Everything else is byte-for-byte the
## same code: same seed, same cast, same loop, same desks, same recording.
##
## Nothing here asserts; every section prints a number. Written by the review,
## not by the work under it, and deleted with it.
##
## Run:  tools/godot/godot4 --headless --path . --script res://tools/critic_territory_live_probe.gd


func _initialize() -> void:
	var scripted := _play(false)
	var person := _play(true)

	print("=== the friendship arm, twice: a program's Wren and a person's Wren")
	print("")
	_section(scripted, "scripted (as shipped)")
	_section(person, "live (a person pressing)")

	print("")
	print("=== side by side")
	var left: PackedStringArray = scripted["wren_lines"]
	var right: PackedStringArray = person["wren_lines"]
	var differing := 0
	for at in maxi(left.size(), right.size()):
		var one := left[at] if at < left.size() else "<none>"
		var two := right[at] if at < right.size() else "<none>"
		if one != two:
			differing += 1
			if differing <= 6:
				print("  differs at %d: %s | %s" % [at, one, two])
	print("  Wren journal lines: %d / %d, differing %d" % [
		left.size(), right.size(), differing])
	print("  parting fingerprints: %s / %s -- %s" % [
		scripted["parted_print"], person["parted_print"],
		"same" if scripted["parted_print"] == person["parted_print"] else "DIFFERENT"])
	print("  end fingerprints: %s / %s -- %s" % [
		scripted["end_print"], person["end_print"],
		"same" if scripted["end_print"] == person["end_print"] else "DIFFERENT"])
	print("  green owner: %s / %s;  Wren cells: %d / %d;  Rook cells: %d / %d" % [
		scripted["green_owner"], person["green_owner"],
		scripted["wren_cells"], person["wren_cells"],
		scripted["rook_cells"], person["rook_cells"]])
	print("  edges toward Wren (trust), scripted: %s" % scripted["toward_wren"])
	print("  edges toward Wren (trust), live:     %s" % person["toward_wren"])
	print("  model calls: %d / %d;  deeds favoured: %d / %d;  earned: %s / %s" % [
		scripted["calls"], person["calls"],
		scripted["favoured"], person["favoured"],
		scripted["earned"], person["earned"]])
	print("  live-holder counters: %d chosen, %d offered to the loop" % [
		person["made"], person["offered"]])
	quit(0)


func _play(as_person: bool) -> Dictionary:
	var channel := ModelChannel.for_run(ModelRecording.goodwill_exchange())
	var scene := ScriptedTerritory.stage()
	ScriptedTerritory.drive(scene, ScriptedTerritory.FRIENDSHIP)
	var wren := _named(scene, ScriptedTerritory.WREN)
	var choice := LiveChoice.new()
	if as_person:
		_sheet(wren).decide = DecisionSource.live(choice)
	var loop := ControlLoop.on(scene, ScriptedTerritory.LOOP_SEED)
	var desk := CheckDesk.with_channel(channel, ScriptedTerritory.ROLL_SEED)
	var deeds := DeedDesk.with_channel(channel)
	var parted := {}
	for _step in ScriptedTerritory.TICKS:
		if as_person:
			# The person presses: the same choice the written rule would make of
			# this world, entered through the person's own surface before the
			# tick is lived.
			choice.choose(ScriptedTerritory._winning_hearts(scene, wren))
		if scene.tick == ScriptedTerritory.WREN_FROM:
			parted = ScriptedTerritory.survey(scene)
		loop.step()
		scene.fight_step()
		desk.step(scene)
		deeds.step(scene)
	var ended := ScriptedTerritory.survey(scene)

	var wren_lines := PackedStringArray()
	for line in loop.journal:
		if line.contains(ScriptedTerritory.WREN) \
				and not line.contains("wait(ticks=%d)" % ScriptedTerritory.WATCH):
			wren_lines.append(line)
	var toward := PackedStringArray()
	for line in scene.relationships.lines():
		if line.contains("-> #%d" % wren.id):
			toward.append(line.strip_edges())
	var green: Dictionary = ended["points"][0]
	var cells: Dictionary = ended["cells"]
	return {
		"wren_lines": wren_lines,
		"parted_print": String(parted.get("fingerprint", "?")),
		"end_print": String(ended["fingerprint"]),
		"green_owner": _owner_named(scene, int(green["owner"])),
		"green_wren": float(green["wren"]),
		"green_rook": float(green["rook"]),
		"wren_cells": int(cells.get(wren.id, 0)),
		"rook_cells": int(cells.get(_named(scene, ScriptedTerritory.ROOK).id, 0)),
		"toward_wren": "; ".join(toward),
		"calls": desk.calls + deeds.calls,
		"favoured": deeds.favoured,
		"earned": Goodwill.said_as(deeds.earned),
		"made": choice.made,
		"offered": choice.offered,
	}


func _section(played: Dictionary, titled: String) -> void:
	print("--- %s" % titled)
	print("  what Wren did (idle watch-waits elided)")
	for line in played["wren_lines"]:
		print("    %s" % line)
	print("  green: owner %s, Wren %+.4f, Rook %+.4f" % [
		played["green_owner"], played["green_wren"], played["green_rook"]])
	print("")


func _owner_named(scene: ActionScene, id: int) -> String:
	if id == OwnershipField.NOBODY:
		return "nobody"
	var sheet := _sheet(scene.actor_of(id))
	return "#%d" % id if sheet == null else sheet.character_name


func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == who:
			return one
	return null


func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
