extends SceneTree
## The numbers behind "items you can see", printed rather than described.
##
##   ./tools/ground_items_probe.sh
##
## Four sections, and each is one of the claims the work item makes:
##
##   1. **The table.** Every gear name in the catalog, which model it resolves
##      to, and whether that is an installed model or the placeholder underneath.
##   2. **The fallback.** Every item the five shipped scenarios put in the world,
##      the name each resolved through, and how many of them resolved to nothing
##      and are therefore drawn as the bundle.
##   3. **The drop.** One seeded run of the skirmish, played until the stranger
##      falls, with what fell, what stayed on the body, and which stream each
##      verdict came off.
##   4. **The round trip.** One item read before it is picked up and after it is
##      put back down, number by number.
##
## Nothing here decides anything. Every number is read out of the layer that owns
## it -- `ItemModel` for a name, `ItemDrop` for a verdict, `Item.line()` for what
## an item is worth -- so a disagreement between this and the suite is a real
## disagreement and not two implementations of the same rule.

const SEED := TestGroundItems.SEED
const SKIRMISH_TICKS := ScriptedSkirmish.TICKS


func _initialize() -> void:
	_the_table()
	_the_fallback()
	_the_drop()
	_the_round_trip()
	quit()


func _the_table() -> void:
	print("=== the gear table ===")
	var installed := 0
	var tags := AssetTags.in_category(AssetTags.GEAR)
	for tag in tags:
		var row := AssetLibrary.visual(tag)
		var drawn := "placeholder (%d parts)" % row.parts.size()
		if not row.is_placeholder():
			installed += 1
			drawn = "%s  (%.3f tall as drawn)" % [
				row.scene_path.get_file(), row.scene_height,
			]
		print("  %-18s %s" % [tag, drawn])
	print("  %d gear names, %d on an installed model, %d on the placeholder" % [
		tags.size(), installed, tags.size() - installed,
	])
	print("")


func _the_fallback() -> void:
	print("=== what the shipped scenarios carry ===")
	var tally := TestGroundItems.shipped_tally()
	for line in tally["lines"]:
		print("  " + String(line))
	print("  %d shipped items, %d of them drawn through the fallback (%s)" % [
		tally["items"], tally["fallbacks"], GroundItems.FALLBACK_TAG,
	])
	print("")


func _the_drop() -> void:
	print("=== one seeded skirmish, and what the fallen left ===")
	var scene := ScriptedSkirmish.stage(ScriptedSkirmish.SEED)
	var loop := ControlLoop.on(scene, ScriptedSkirmish.LOOP_SEED)
	ScriptedSkirmish.drive(scene)

	var carried := {}
	var named := {}
	var standing := {}
	for one in scene.actors:
		var pack := ActionScene.inventory_of(one)
		carried[one.id] = [] as Array[Item] if pack == null else pack.items()
		named[one.id] = ActionScene.name_of(one)
		standing[one.id] = true
	print("  seed=%d ticks=%d drop chance=%d%%" % [
		scene.terrain.world_seed, SKIRMISH_TICKS, ItemDrop.CHANCE_PERCENT,
	])

	var fell_at := -1
	for step in SKIRMISH_TICKS:
		loop.step()
		scene.fight_step()
		if fell_at < 0 and scene.actors.size() < standing.size():
			fell_at = step
	ScriptedSkirmish.release(scene)

	var still_here := {}
	for one in scene.actors:
		still_here[one.id] = true
	for id in standing:
		if still_here.has(id):
			continue
		var kill := "fallen#%d" % int(id)
		var was: Array[Item] = carried[id]
		print("  %s (#%d) went down on tick %d carrying %d" % [
			named[id], int(id), fell_at, was.size(),
		])
		for index in was.size():
			var item: Item = was[index]
			print("    %-7s %-24s %-14s %s" % [
				"DROPPED" if ItemDrop.falls(scene.terrain.world_seed, kill, index, item)
					else "kept",
				item.item_name, ItemModel.of(item),
				ItemDrop.stream_label(kill, index, item),
			])

	print("  what is on the ground now:")
	for row in TestGroundItems.scene_ground_rows(scene):
		print("    #%d %s at (%.2f, %.2f, %.2f) holding %d" % [
			int(row["id"]), String(row["name"]),
			float(row["x"]), float(row["y"]), float(row["z"]),
			(row["items"] as Array).size(),
		])
	for placement in GroundItems.placements(
			{"combat": {"ground": TestGroundItems.scene_ground_rows(scene)}}):
		print("    drawn %-22s as %-16s at (%.2f, %.2f)%s" % [
			String(placement["name"]), String(placement["tag"]),
			float(placement["x"]), float(placement["z"]),
			"  [fallback]" if bool(placement["fallback"]) else "",
		])
	print("")


func _the_round_trip() -> void:
	print("=== up and down again ===")
	var scene := ActionScene.on(null)
	var one := scene.add_actor(
		Combatant.commander_at(0.0, 0.0, 0.0, 0.0, 4, AssetTags.KNIGHT))
	(one.piece as Commander).adopt(Character.make("Wren", 4))

	var loot := ItemForge.forge(SEED, "round-trip", 5, Item.KIND_ARMOUR)
	var pile := scene.add_object(WorldObject.loose(0.0, 0.0, Inventory.ground([loot])))
	print("  on the ground   %s" % loot.line())
	print("  drawn as        %s" % ItemModel.of(loot))

	var taken := ActionEngine.resolve(
		scene, one, Action.pick_up(loot.item_name, pile.id))
	print("  pick up         %s" % taken.line())
	for item in ActionScene.inventory_of(one).items():
		print("    carried       %s" % item.line())

	var put := ActionEngine.resolve(scene, one, Action.drop(loot.item_name))
	print("  drop            %s" % put.line())
	for thing in scene.objects:
		if not thing.holds_things():
			continue
		for item in thing.contents.items():
			print("    on the ground %s" % item.line())
			print("    drawn as      %s" % ItemModel.of(item))
			print("    same object   %s" % ("yes" if item == loot else "no"))
	print("")
