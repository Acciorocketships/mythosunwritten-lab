extends TestSuite
## Items you can see: a forged item's name, a pile you can tell apart, drops
## where somebody fell, and a round trip that changes nothing.
##
## Six claims, and every one of them is about the *body* a generated item gets.
## Not one of them touches the item rules -- the budget, the rarity table, the
## ability gate and the one-in-five drop are settled and are read here rather
## than re-decided.
##
##   1. Every item the forge makes resolves to a name in the asset catalog, and
##      every name the table can hand out is a name the render layer draws.
##   2. An item with no name of its own falls back to something visible, and how
##      many of the items the project actually ships take that fallback is a
##      number rather than a hope.
##   3. A pile of several is legible: no two things in one heap come closer than
##      the layout's own spacing, whatever the heap holds.
##   4. A defeated character's gear appears where it fell, and it is exactly what
##      `ItemDrop` says fell -- the drop probability is read, not re-applied.
##   5. Picking an item up and dropping it back leaves the same item, shown by
##      reading every number off it before and after.
##   6. The simulation still names no art. (`AssetCheck` is the checker; this is
##      the reminder that the gear names went into the catalog and not into a
##      table of paths.)
class_name TestGroundItems

## The world seed the forge is exercised on, and how many items are forged
## through it. Large enough that all six rarity tiers turn up.
const SEED := 4321
const FORGED := 400

## How many of the items the six shipped scenarios put in the world resolve to
## no name of their own and are therefore drawn as `GroundItems.FALLBACK_TAG`.
##
## Written down rather than merely counted, so that an item added with no shape
## recorded moves a number a test compares instead of quietly becoming another
## anonymous bundle on the ground. The report beside it is
## `reports/ground-items.md`; `tools/ground_items_probe.sh` prints the roll call.
const SHIPPED_FALLBACKS := 6

## And how many items the six scenarios ship altogether, for the same reason:
##
## Six rather than five since the battle scenario landed, which is the encounter
## scenario with the camera on one of the two who fight -- so its six items are
## the encounter's six, counted a second time because it is a second scenario a
## person can be handed.
## a fallback count means nothing without the total it is out of.
const SHIPPED_ITEMS := 37

## The pile sizes the layout is measured over. One is the case that must land
## exactly on the pile's own point; the rest are heaps.
const PILE_SIZES := [1, 2, 3, 5, 8, 13, 24]

## How far a pile may be from the last place the fallen character was seen, in
## world units: one lattice cell, because a character can take one board move
## inside the tick it goes down on.
const WHERE_IT_FELL := 3.0

## How long the skirmish is played for before the drops are read. The stranger
## falls well inside `ScriptedSkirmish.TICKS`.
const SKIRMISH_TICKS := ScriptedSkirmish.TICKS


func _init() -> void:
	suite_name = "ground items"


func run() -> void:
	_the_table_hands_out_real_names()
	_every_forged_item_has_a_name()
	_an_unnamed_item_falls_back_to_something_visible()
	_the_shipped_items_that_fall_back_are_counted()
	_a_pile_of_several_is_legible()
	_a_pile_is_drawn_where_the_simulation_put_it()
	_the_fallen_leave_their_gear_where_they_fell()
	_up_and_down_again_leaves_the_same_item()


## Every name `ItemModel` can produce is in the catalog, and the render layer has
## a row for it that actually builds. A name with no row is an item that would be
## placed and then not appear, which is the one failure the indirection exists to
## make impossible.
func _the_table_hands_out_real_names() -> void:
	check(ItemModel.tags_are_real(), "ItemModel hands out a name the catalog does not have")
	var names := ItemModel.tags()
	check(names.size() >= 10, "the table hands out only %d names" % names.size())
	names.append(GroundItems.FALLBACK_TAG)
	for tag in names:
		check(AssetTags.is_tag(tag), "'%s' is not a catalog tag" % tag)
		equal(AssetTags.category_of(tag), AssetTags.GEAR,
			"'%s' is not filed under gear" % tag)
		check(AssetLibrary.has_visual(tag), "the render table has no row for '%s'" % tag)
		var built := AssetLibrary.build(tag)
		check(built != null, "'%s' would not build" % tag)
		if built != null:
			check(_mesh_count(built) > 0, "'%s' builds nothing visible" % tag)
			built.free()


## A forged item always knows what it is. Both kinds, over four hundred sources:
## every one resolves, every name is a catalog tag, and all six rarity tiers turn
## up -- which is what makes the sheet a picture of the whole range rather than
## of the common tier.
func _every_forged_item_has_a_name() -> void:
	var tiers := {}
	var names := {}
	for index in FORGED:
		for of_kind in [Item.KIND_WEAPON, Item.KIND_ARMOUR]:
			var item := ItemForge.forge(SEED, "sheet#%d" % index, 6, of_kind)
			var tag := ItemModel.of(item)
			check(tag != ItemModel.NOTHING,
				"forged %s resolves to no name" % item.item_name)
			check(AssetTags.is_tag(tag),
				"forged %s resolves to '%s', which is not a tag" % [item.item_name, tag])
			equal(item.model, tag,
				"forged %s does not carry the name it resolves to" % item.item_name)
			tiers[item.rarity] = true
			names[tag] = true
	for tier in ItemRarity.TIERS:
		check(tiers.has(tier), "no forged item came out %s over %d sources" % [tier, FORGED])
	equal(names.size(), 10,
		"the forge reaches %d of the ten shapes it can draw" % names.size())


## An item nobody recorded a shape for resolves to nothing, and nothing is drawn
## as the bundle. Both halves matter: the simulation is honest that it does not
## know, and the render layer is the one that decides something has to be seen.
func _an_unnamed_item_falls_back_to_something_visible() -> void:
	var nameless := Item.weapon(
		"iron key", 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])
	equal(ItemModel.of(nameless), ItemModel.NOTHING,
		"an item with no shape recorded resolved to a name anyway")
	check(not ItemModel.is_named(nameless), "is_named disagrees with of()")

	var rows := GroundItems.placements(_snapshot_of_one_pile([nameless]))
	equal(rows.size(), 1, "one item on the ground did not make one row")
	if rows.is_empty():
		return
	equal(String(rows[0]["tag"]), GroundItems.FALLBACK_TAG,
		"an unnamed item is not drawn as the fallback")
	check(bool(rows[0]["fallback"]), "the fallback is not reported as one")
	check(AssetTags.is_tag(GroundItems.FALLBACK_TAG), "the fallback is not a catalog tag")

	# And a named one is not touched by the fallback.
	var named := ItemForge.forge(SEED, "named", 4, Item.KIND_ARMOUR)
	var named_rows := GroundItems.placements(_snapshot_of_one_pile([named]))
	if not named_rows.is_empty():
		check(not bool(named_rows[0]["fallback"]), "a named item was called a fallback")
		equal(String(named_rows[0]["tag"]), ItemModel.of(named),
			"a named item is not drawn as its own name")


## How many of the items the project actually ships take the fallback, counted
## by walking every scenario the shell can set out and reading everything in
## everybody's hands, on everybody's back and lying on the ground.
##
## The number is compared rather than merely printed, so that adding an item
## with no shape recorded is a failing test and not a silent extra bundle.
func _the_shipped_items_that_fall_back_are_counted() -> void:
	var tally := shipped_tally()
	equal(int(tally["items"]), SHIPPED_ITEMS,
		"the shipped scenarios hold %d items, not %d" % [tally["items"], SHIPPED_ITEMS])
	equal(int(tally["fallbacks"]), SHIPPED_FALLBACKS,
		"%d shipped items fall back, not %d" % [tally["fallbacks"], SHIPPED_FALLBACKS])


## Every item the six shipped scenarios put in the world, and how many of them
## resolve to no name: `{"items": int, "fallbacks": int, "lines": PackedStringArray}`.
##
## Public because the probe prints the roll call and the test compares the two
## numbers, and both have to be counting the same things.
static func shipped_tally() -> Dictionary:
	var items := 0
	var fallbacks := 0
	var lines := PackedStringArray()
	for scenario in Simulation.SCENARIOS:
		if scenario == Simulation.SCENARIO_NONE:
			continue
		var sim := Simulation.new(TestGroundItems.SEED)
		if not sim.begin_scenario(scenario):
			lines.append("%-18s unavailable" % scenario)
			continue
		var scene := sim.world.combat.scene
		var packs: Array[Inventory] = []
		for one in scene.actors:
			var pack := ActionScene.inventory_of(one)
			if pack != null:
				packs.append(pack)
		for thing in scene.objects:
			if thing.holds_things():
				packs.append(thing.contents)
		for pack in packs:
			for item in pack.items():
				items += 1
				var tag := ItemModel.of(item)
				if tag == ItemModel.NOTHING:
					fallbacks += 1
				lines.append("%-18s %-24s %s" % [
					scenario, item.item_name,
					"-- fallback" if tag == ItemModel.NOTHING else tag,
				])
	return {"items": items, "fallbacks": fallbacks, "lines": lines}


## A pile of several is a scatter and not a heap: whatever it holds, no two
## things in it come closer than the layout's own spacing.
##
## Measured on the layout function directly rather than through a snapshot,
## because the claim is about every pile size and not about one.
func _a_pile_of_several_is_legible() -> void:
	for size in PILE_SIZES:
		var spots: Array[Vector2] = []
		for index in size:
			spots.append(GroundItems.spread(index))
		var closest := INF
		for left in spots.size():
			for right in range(left + 1, spots.size()):
				closest = minf(closest, spots[left].distance_to(spots[right]))
		if size > 1:
			check(closest >= GroundItems.SPACING - 0.001,
				"a pile of %d puts two things %.3f apart, under %.3f"
					% [size, closest, GroundItems.SPACING])
		# And the heap stays a heap: it grows as the square root of what is in
		# it, so twenty-four things are still something a person walks up to.
		var furthest := 0.0
		for spot in spots:
			furthest = maxf(furthest, spot.length())
		check(furthest <= GroundItems.SPACING * sqrt(float(size)) + 0.001,
			"a pile of %d reaches %.3f from its own point" % [size, furthest])


## The first thing in a pile lies exactly where the simulation says the pile is,
## so a pile of one is drawn at its own position and nowhere else.
func _a_pile_is_drawn_where_the_simulation_put_it() -> void:
	var only := ItemForge.forge(SEED, "alone", 3, Item.KIND_WEAPON)
	var rows := GroundItems.placements(_snapshot_of_one_pile([only], 12.5, -8.25))
	equal(rows.size(), 1, "one item did not make one row")
	if rows.is_empty():
		return
	check(absf(float(rows[0]["x"]) - 12.5) < 0.0001,
		"a lone item is not at the pile's x")
	check(absf(float(rows[0]["z"]) + 8.25) < 0.0001,
		"a lone item is not at the pile's z")
	equal(GroundItems.spread(0), Vector2.ZERO, "the first spot is not the centre")


## One seeded run of the skirmish: the stranger falls, and what fell off is on
## the ground where it fell -- exactly the items `ItemDrop` says fell, at the
## probability the item layer already applies.
##
## Nothing here rolls anything. The verdicts are asked of `ItemDrop` with the
## same seed and the same kill label the world used, and the pile is compared
## against them; a second roll would be a second rule.
func _the_fallen_leave_their_gear_where_they_fell() -> void:
	var scene := ScriptedSkirmish.stage(ScriptedSkirmish.SEED)
	var loop := ControlLoop.on(scene, ScriptedSkirmish.LOOP_SEED)
	ScriptedSkirmish.drive(scene)

	# What everybody was carrying and where they were standing, before the
	# fight: the drop verdict is a function of the item and the kill, so it can
	# be worked out from this alone.
	var carried := {}
	var stood := {}
	for one in scene.actors:
		var pack := ActionScene.inventory_of(one)
		if pack != null:
			carried[one.id] = pack.items()
		stood[one.id] = Vector2(one.x, one.z)

	var standing := {}
	for one in scene.actors:
		standing[one.id] = true
	for _step in SKIRMISH_TICKS:
		loop.step()
		scene.fight_step()
		# Remember where anybody who is still up is standing, so that when they
		# go down the last place they stood is known.
		for one in scene.actors:
			stood[one.id] = Vector2(one.x, one.z)
	var fell := []
	for id in standing:
		var still_here := false
		for one in scene.actors:
			if one.id == int(id):
				still_here = true
		if not still_here:
			fell.append(int(id))
	ScriptedSkirmish.release(scene)

	check(fell.size() >= 1, "nobody fell in %d ticks of the skirmish" % SKIRMISH_TICKS)
	var seed_of_the_world := scene.terrain.world_seed
	for id in fell:
		var wanted: Array[Item] = ItemDrop.drops(
			seed_of_the_world, "fallen#%d" % id, carried.get(id, [] as Array[Item]))
		var pile := _pile_nearest(scene, stood[id])
		if wanted.is_empty():
			continue
		check(pile != null, "#%d fell carrying %d droppable items and left no pile"
			% [id, wanted.size()])
		if pile == null:
			continue
		# Where it fell, to within the cell it was standing on: the last
		# position this loop saw is the start of the tick the character went
		# down on, and it may have taken one board move inside that tick.
		check(pile.distance_from(stood[id].x, stood[id].y) <= WHERE_IT_FELL,
			"the pile #%d left is %.2f from where it fell"
				% [id, pile.distance_from(stood[id].x, stood[id].y)])
		var left := pile.contents.items()
		equal(left.size(), wanted.size(),
			"#%d left %d things, not the %d that fell" % [id, left.size(), wanted.size()])
		for at in mini(left.size(), wanted.size()):
			equal(left[at].line(), wanted[at].line(),
				"what #%d left is not what fell" % id)
		# And the drops are visible: every one of them is drawn.
		var rows := GroundItems.placements(
			{"combat": {"ground": scene_ground_rows(scene)}})
		check(rows.size() >= left.size(),
			"%d things on the ground made only %d rows" % [left.size(), rows.size()])


## Picking an item up and putting it back down leaves the same item.
##
## Read before and after rather than trusted: every number that makes the item
## what it is -- its rarity, its level, its budget, each axis and every effect
## with what it cost -- is `Item.line()`, and the name it is drawn under is read
## beside it. Identity is checked too, because two items that print the same are
## not necessarily one item.
func _up_and_down_again_leaves_the_same_item() -> void:
	var scene := ActionScene.on(null)
	var one := scene.add_actor(Combatant.commander_at(0.0, 0.0, 0.0, 0.0, 4, AssetTags.KNIGHT))
	(one.piece as Commander).adopt(Character.make("Wren", 4))

	var loot := ItemForge.forge(SEED, "round-trip", 5, Item.KIND_ARMOUR)
	var before := loot.line()
	var drawn_as := ItemModel.of(loot)
	var pile := scene.add_object(WorldObject.loose(0.0, 0.0, Inventory.ground([loot])))

	var taken := ActionEngine.resolve(
		scene, one, Action.pick_up(loot.item_name, pile.id))
	check(taken.ok, "picking it up was refused: %s" % taken.line())
	var held := _named_in(ActionScene.inventory_of(one), loot.item_name)
	check(held != null, "it is not in the character's inventory after picking it up")

	var put := ActionEngine.resolve(scene, one, Action.drop(loot.item_name))
	check(put.ok, "putting it down was refused: %s" % put.line())

	var down: Item = null
	for thing in scene.objects:
		if thing.holds_things():
			var found := _named_in(thing.contents, loot.item_name)
			if found != null:
				down = found
	check(down != null, "it is not on the ground after being dropped")
	if down == null:
		return
	equal(down.line(), before, "the round trip changed what the item is worth")
	equal(down.rarity, loot.rarity, "the round trip changed its rarity")
	equal(down.level, loot.level, "the round trip changed its level")
	equal(down.budget(), loot.budget(), "the round trip changed its budget")
	equal(down.effects_line(), loot.effects_line(), "the round trip changed its effects")
	equal(ItemModel.of(down), drawn_as, "the round trip changed what it is drawn as")
	check(down == loot, "the round trip replaced the item with a copy of it")


# --- Reading a scene ------------------------------------------------------


## The ground rows of a scene, in the shape the snapshot carries them. A test
## helper and the probe's, so both read a scene the same way the shell does.
static func scene_ground_rows(scene: ActionScene) -> Array:
	var roster := CombatantRoster.new()
	roster.scene = scene
	return roster.ground_rows()


# One snapshot holding one pile at a position, with the given items in it.
func _snapshot_of_one_pile(
	items: Array, at_x: float = 0.0, at_z: float = 0.0
) -> Dictionary:
	var lying := []
	for entry in items:
		var item: Item = entry
		lying.append({
			"name": item.item_name,
			"rarity": item.rarity,
			"level": item.level,
			"model": ItemModel.of(item),
		})
	return {"combat": {"ground": [{
		"id": 7, "name": "pile", "kind": "pile", "shut": false,
		"x": at_x, "y": 0.0, "z": at_z, "items": lying,
	}]}}


func _pile_nearest(scene: ActionScene, at: Vector2) -> WorldObject:
	var found: WorldObject = null
	var nearest := 0.0
	for thing in scene.objects:
		if not thing.pile:
			continue
		var gap := thing.distance_from(at.x, at.y)
		if found == null or gap < nearest:
			found = thing
			nearest = gap
	return found


func _named_in(pack: Inventory, called: String) -> Item:
	if pack == null:
		return null
	for item in pack.items():
		if item.item_name == called:
			return item
	return null


func _mesh_count(node: Node) -> int:
	var found := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		found += 1
	for child in node.get_children():
		found += _mesh_count(child)
	return found
