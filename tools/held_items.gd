extends SceneTree
## The armoury walkthrough: what each hand holds, tick by tick, read the way
## the game reads it.
##
##   ./tools/held_items.sh
##
## One seeded world with the armoury scenario on it (`sim/scripted_armoury.gd`)
## is stepped headless. Every character on the stage is given a real
## `CharacterView` -- the same scene the render shell instantiates -- and on
## every tick each view is handed the state `CombatDiorama.placements()` reads
## out of the world's snapshot, exactly as `render/main.gd` hands it over.
##
## What is printed is both ends of the seam at once: the tag the snapshot says
## is equipped in the hand slot, and the tag actually hanging in each of the
## view's two sockets after apply(). The changer's schedule -- sword, then
## shield, then sword again, then nothing -- prints one line per change, on the
## tick the snapshot first says so.
##
## Nothing here writes to the simulation and nothing reads it but the snapshot:
## the views are driven off the same dictionary the shell is driven off, so if
## this table is right, the game is drawing the same thing.

const TICKS := 70
const DELTA := 1.0 / 60.0


func _initialize() -> void:
	var sim := Simulation.new(ScriptedArmoury.SEED)
	if not sim.begin_scenario(Simulation.SCENARIO_ARMOURY):
		printerr("the armoury scenario could not be set out")
		quit(1)
		return

	var scene: PackedScene = load(CharacterView.SCENE)
	var views := {}

	print("seed %d, %d on the stage" % [
		ScriptedArmoury.SEED, sim.world.combat.size(),
	])
	print("")
	print("the rack, before anything is stepped:")
	_sync(sim, scene, views)
	_rack_table(sim, views)

	print("")
	print("the changer, wherever the snapshot's hand changes:")
	var shown := "?"
	for _tick in TICKS:
		sim.step()
		_sync(sim, scene, views)
		var now := _changer_line(sim, views)
		if now != shown:
			shown = now
			print("  t=%-3d %s" % [sim.world.tick, now])
	for id in views:
		(views[id] as Node).free()
	quit(0)


## Hand every view its row's state, building views for new rows: the same
## drop/build/apply cycle `render/main.gd::_sync_combat` runs, minus the screen.
static func _sync(sim: Simulation, scene: PackedScene, views: Dictionary) -> void:
	for row in CombatDiorama.placements(sim.world.snapshot()):
		var id := int(row["id"])
		if not bool(row["commander"]):
			continue
		if not views.has(id):
			var view: CharacterView = scene.instantiate()
			view.set_model(String(row["tag"]))
			views[id] = view
		(views[id] as CharacterView).apply(row["state"], DELTA)


static func _rack_table(sim: Simulation, views: Dictionary) -> void:
	var snapshot := sim.world.snapshot()
	print("  %-8s %-16s %-14s %-14s %-14s" % [
		"who", "holds (sim)", "snapshot tag", "right socket", "left socket",
	])
	for row in (snapshot["combat"] as Dictionary)["pieces"]:
		if not bool(row["commander"]):
			continue
		var one := sim.world.combat.member_of(int(row["id"]))
		var sheet := (one.piece as Commander).sheet
		var equipped: Dictionary = row["equipped"]
		var view := views.get(int(row["id"]), null) as CharacterView
		print("  %-8s %-16s %-14s %-14s %-14s" % [
			sheet.character_name,
			_holding(one),
			String(equipped.get(Item.SLOT_HAND, "-")),
			_socket(view, CharacterView.RIGHT_HAND),
			_socket(view, CharacterView.LEFT_HAND),
		])


## One line for the changer: what the simulation says is in the hand slot, and
## what the view's two sockets hold after being applied.
static func _changer_line(sim: Simulation, views: Dictionary) -> String:
	var snapshot := sim.world.snapshot()
	for row in (snapshot["combat"] as Dictionary)["pieces"]:
		if not bool(row["commander"]):
			continue
		var one := sim.world.combat.member_of(int(row["id"]))
		if (one.piece as Commander).sheet.character_name != ScriptedArmoury.CHANGER:
			continue
		var equipped: Dictionary = row["equipped"]
		var view := views.get(int(row["id"]), null) as CharacterView
		return "hand slot %-14s right socket %-14s left socket %s" % [
			String(equipped.get(Item.SLOT_HAND, "-")),
			_socket(view, CharacterView.RIGHT_HAND),
			_socket(view, CharacterView.LEFT_HAND),
		]
	return "the changer is not on the stage"


static func _holding(one: Combatant) -> String:
	var item := Inventory.item_of(
		ActionScene.inventory_of(one).equipped_in(Item.SLOT_HAND))
	return "-" if item == null else item.item_name


static func _socket(view: CharacterView, socket_name: String) -> String:
	if view == null:
		return "(no view)"
	var tag := view.held_tag(socket_name)
	return "-" if tag == "" else tag
