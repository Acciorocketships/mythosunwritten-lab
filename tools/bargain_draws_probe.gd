extends SceneTree
## The bargain run played through every draw there is, printed side by side.
##
##   ./tools/bargain_draws_probe.sh
##
## One run of `TestBargain.play()` per recorded table -- the shipped one and
## every past draw `net/bargain_draws.gd` keeps -- with two things printed for
## each: what that draw's trader happened to do, and whether the machinery the
## suite asserts held while he did it.
##
## The point of printing them together is that the second block must read the
## same down every column and the first one must not. A claim that changes with
## the draw is a claim about the draw.


func _initialize() -> void:
	var tables: Array[Dictionary] = [{
		"name": "the shipped table, %s" % ModelRecording.BARGAIN_RECORDED_ON,
		"rows": ModelRecording.BARGAIN_ROWS,
		"from": ModelRecording.bargain_provenance(),
		"model": ModelRecording.MODEL,
	}]
	tables.append_array(BargainDraws.past())
	for table in tables:
		_one(table)
	quit()


func _one(table: Dictionary) -> void:
	var channel := ModelChannel.replaying(table, "a probe replaying one draw")
	var run := TestBargain.play(channel)
	var world: SimWorld = run["world"]
	var scene := world.combat.scene
	var fen := scene.actor_of(int(run["id"]))
	var hob := scene.actor_of(ScriptedPlay.id_of(scene, ScriptedPlay.HOB))
	print("")
	print("=== %s" % String(table["name"]))
	print("    %s" % String(table["from"]))

	print("  what this draw's trader did:")
	print("    a trade_accept of his finished ok: %s" % _accepted(world))
	print("    the lantern is in the person's pack: %s" % _carries(fen))
	print("    the person's purse: %d (started %d, the price is %d)" % [
		ActionScene.inventory_of(fen).money, ScriptedPlay.FEN_MONEY,
		ScriptedPlay.LANTERN_PRICE,
	])
	print("    the trader still carries the lantern: %s" % _carries(hob))
	print("    the trader's purse: %d (he is after %d)" % [
		ActionScene.inventory_of(hob).money, ScriptedBargain.AFTER_MONEY,
	])
	print("    the closing examine shows a pack: %s" % _closing_shows_pack(run))

	print("  the machinery, whatever he did:")
	print("    coins in the two purses: %d at the end, %d at the start" % [
		ActionScene.inventory_of(fen).money + ActionScene.inventory_of(hob).money,
		ScriptedPlay.FEN_MONEY + ScriptedPlay.HOB_MONEY,
	])
	print("    the lantern has exactly one holder: %s" % (
		_carries(fen) != _carries(hob)))
	print("    honoured trades on the scene ledger: %d" % scene.trades.size())
	print("    every purse moves by what the ledger says: %s" % _books_balance(scene, run))
	print("    the pack window opened exactly while a trade stood: %s"
		% _window_agreed(run))
	print("    the person's ask named the lantern and stood: %s" % _ask_stood(run))
	print("    every answer either of them got carried the engine's words: %s"
		% _every_answer_spoken(world))


static func _accepted(world: SimWorld) -> String:
	for line in world.loop.journal:
		if line.contains("finished trade_accept") and line.contains("ok"):
			return "yes -- %s" % line.strip_edges()
	return "no"


static func _carries(one: Combatant) -> bool:
	var pack := ActionScene.inventory_of(one)
	if pack == null:
		return false
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == ScriptedPlay.LANTERN:
			return true
	return false


static func _closing_shows_pack(run: Dictionary) -> bool:
	var last := {}
	for row in run["table"]:
		if String(row["line"]).begins_with("examine"):
			last = row
	return not last.is_empty() and String(last["line"]).contains("carries")


static func _books_balance(scene: ActionScene, run: Dictionary) -> String:
	var fen_id := int(run["id"])
	var hob_id := ScriptedPlay.id_of(scene, ScriptedPlay.HOB)
	var moved := {fen_id: 0, hob_id: 0}
	for trade in scene.trades:
		var from_id := int(trade["from"])
		var to_id := int(trade["to"])
		var out := int(trade["gave_money"])
		var back := int(trade["back_money"])
		moved[from_id] = int(moved.get(from_id, 0)) - out + back
		moved[to_id] = int(moved.get(to_id, 0)) + out - back
	var fen_now := ActionScene.inventory_of(scene.actor_of(fen_id)).money
	var hob_now := ActionScene.inventory_of(scene.actor_of(hob_id)).money
	var ok := fen_now == ScriptedPlay.FEN_MONEY + int(moved[fen_id]) \
		and hob_now == ScriptedPlay.HOB_MONEY + int(moved[hob_id])
	return "%s (person %+d, trader %+d)" % [ok, int(moved[fen_id]), int(moved[hob_id])]


static func _window_agreed(run: Dictionary) -> String:
	var open_ticks := 0
	var wrong := 0
	for row in run["window"]:
		if bool(row["standing"]):
			open_ticks += 1
		if bool(row["person_shown"]) != bool(row["standing"]) \
				or bool(row["trader_shown"]) != bool(row["standing"]):
			wrong += 1
	return "%s (%d ticks with a trade standing, %d ticks that disagreed)" % [
		wrong == 0, open_ticks, wrong,
	]


static func _ask_stood(run: Dictionary) -> String:
	for row in run["table"]:
		if String(row.get("action", "")).contains("want=[%s]" % ScriptedPlay.LANTERN):
			return "%s -- %s" % [bool(row["ok"]), String(row["line"])]
	return "the ask was never resolved"


static func _every_answer_spoken(world: SimWorld) -> String:
	var refused := 0
	var mute := 0
	for line in world.loop.journal:
		if not line.contains("finished "):
			continue
		if line.contains("refused"):
			refused += 1
			if line.strip_edges().ends_with("refused"):
				mute += 1
	return "%s (%d refusals, %d of them wordless)" % [mute == 0, refused, mute]
