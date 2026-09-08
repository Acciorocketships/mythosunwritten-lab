extends TestSuite
## What a character holds in its hands, from the inventory to the sockets.
##
## Five claims:
##
##   1. The simulation snapshot says which catalog name is equipped in which
##      slot, from its own vocabulary -- a tag `AssetTags` knows, resolved by
##      `ItemModel` off the inventory, never a path and never a model.
##   2. Which hand a tag hangs in is a pure function of the slots, decided in
##      the render layer: weapons right, shields left, worn armour nowhere.
##   3. The view mounts what the snapshot says and holds no copy of it: the
##      same state gives the same sockets whatever was applied before, a swap
##      leaves nothing of what hung there, and no member of the view stores
##      what is equipped -- proved the way the combat readout was.
##   4. A change in the world is a change in the sockets on the next snapshot:
##      the armoury's changer swaps and unequips through the engine, and a view
##      driven off `CombatDiorama.placements()` follows every beat.
##   5. The measured mounting conventions still hold on the models as built --
##      grip at the origin, length along the slot's own axis, sizes in the
##      rig's own order -- so a repointed row that breaks them fails here
##      rather than drawing a sword through an arm.
class_name TestHeldItems

## How long the armoury schedule needs to play out all three changes, with room.
const TICKS := 70

## A frame's worth of seconds, for apply(); it paces cross-fades and nothing
## about what a socket holds.
const DELTA := 1.0 / 60.0


func _init() -> void:
	suite_name = "held items"


func run() -> void:
	_the_snapshot_carries_tags_and_only_tags()
	_a_minion_row_carries_no_equipment()
	_which_hand_is_a_pure_function_of_the_slots()
	_the_view_mounts_what_the_snapshot_says()
	_the_view_keeps_no_copy()
	_a_change_in_the_world_reaches_the_sockets()
	_the_measured_conventions_still_hold()


# --- 1. The snapshot -----------------------------------------------------


## Every commander on the armoury stage reports its hand in the snapshot, as
## the tag `ItemModel` resolves its own held item to, and every tag it reports
## in any slot is a name the catalog knows.
func _the_snapshot_carries_tags_and_only_tags() -> void:
	var sim := Simulation.new(ScriptedArmoury.SEED)
	check(sim.begin_scenario(Simulation.SCENARIO_ARMOURY),
		"the armoury scenario could not be set out")
	var rows: Array = (sim.world.snapshot()["combat"] as Dictionary)["pieces"]
	var commanders := 0
	for row in rows:
		if not bool(row["commander"]):
			continue
		commanders += 1
		var equipped: Dictionary = row["equipped"]
		for slot in equipped:
			check(AssetTags.is_tag(String(equipped[slot])),
				"the snapshot says '%s' is equipped, which the catalog does not know"
				% equipped[slot])
		var one := sim.world.combat.member_of(int(row["id"]))
		var item := Inventory.item_of(
			ActionScene.inventory_of(one).equipped_in(Item.SLOT_HAND))
		equal(String(equipped.get(Item.SLOT_HAND, "")), ItemModel.of(item),
			"the snapshot's hand disagrees with the inventory's")
	equal(commanders, ScriptedArmoury.RACK.size() + 1,
		"the armoury should stand one bearer per shape and the changer")


## A minion carries no inventory, and its row says so with an empty dictionary
## rather than a missing key or an invented one.
func _a_minion_row_carries_no_equipment() -> void:
	var sim := Simulation.new(ScriptedScenario.SEED)
	check(sim.begin_scenario(Simulation.SCENARIO_ENCOUNTER),
		"the encounter scenario could not be set out")
	var minions := 0
	for row in (sim.world.snapshot()["combat"] as Dictionary)["pieces"]:
		if bool(row["commander"]):
			continue
		minions += 1
		check((row["equipped"] as Dictionary).is_empty(),
			"a minion's row claims equipment it has no inventory to hold")
	check(minions > 0, "the encounter fielded no minions to check")


# --- 2. Which hand -------------------------------------------------------


func _which_hand_is_a_pure_function_of_the_slots() -> void:
	var sword := {Item.SLOT_HAND: AssetTags.GEAR_BLADE}
	equal(CharacterView.held_in_hands(sword),
		{CharacterView.LEFT_HAND: "", CharacterView.RIGHT_HAND: AssetTags.GEAR_BLADE},
		"a weapon should hang in the right hand")
	equal(CharacterView.held_in_hands({Item.SLOT_HAND: AssetTags.GEAR_BUCKLER}),
		{CharacterView.LEFT_HAND: AssetTags.GEAR_BUCKLER, CharacterView.RIGHT_HAND: ""},
		"a shield should hang on the left arm")
	equal(CharacterView.held_in_hands({}),
		{CharacterView.LEFT_HAND: "", CharacterView.RIGHT_HAND: ""},
		"empty slots should be empty hands")
	# Worn armour has no socket: a full suit changes neither hand.
	equal(CharacterView.held_in_hands({
			Item.SLOT_BOOTS: AssetTags.GEAR_BOOTS,
			Item.SLOT_HELMET: AssetTags.GEAR_HELMET,
		}),
		{CharacterView.LEFT_HAND: "", CharacterView.RIGHT_HAND: ""},
		"worn armour should hang in no hand")
	# And the same slots twice give the same hands: nothing is remembered.
	equal(CharacterView.held_in_hands(sword), CharacterView.held_in_hands(sword),
		"the same slots should give the same hands every time")


# --- 3. The view ---------------------------------------------------------


## One view walked through a weapon, a swap to a shield, and empty hands: at
## every step the sockets hold what the state says and nothing else.
func _the_view_mounts_what_the_snapshot_says() -> void:
	var view: CharacterView = (load(CharacterView.SCENE) as PackedScene).instantiate()
	view.set_model(AssetTags.KNIGHT)

	view.apply(_state(AssetTags.GEAR_SPEAR), DELTA)
	equal(view.held_tag(CharacterView.RIGHT_HAND), AssetTags.GEAR_SPEAR,
		"a spear equipped should be a spear in the right hand")
	equal(view.held_tag(CharacterView.LEFT_HAND), "",
		"and nothing on the left arm")

	view.apply(_state(AssetTags.GEAR_BUCKLER), DELTA)
	equal(view.held_tag(CharacterView.LEFT_HAND), AssetTags.GEAR_BUCKLER,
		"a shield equipped should be a shield on the left arm")
	equal(view.held_tag(CharacterView.RIGHT_HAND), "",
		"with nothing left in the right hand from before")

	view.apply(_state(""), DELTA)
	equal(view.held_tag(CharacterView.RIGHT_HAND), "",
		"empty slots should empty the right hand")
	equal(view.held_tag(CharacterView.LEFT_HAND), "",
		"and the left")

	# What hangs in a socket survives a model swap, because the sockets are the
	# scene's and not the model's.
	view.apply(_state(AssetTags.GEAR_STAFF), DELTA)
	view.set_model(AssetTags.MAGE)
	view.apply(_state(AssetTags.GEAR_STAFF), DELTA)
	equal(view.held_tag(CharacterView.RIGHT_HAND), AssetTags.GEAR_STAFF,
		"a model swap should not empty the hand the snapshot filled")
	view.queue_free()


## The proof the combat readout gave, given again here: a view that has been
## through history and a view that has not agree about the same state, and no
## member of the view stores what is equipped.
func _the_view_keeps_no_copy() -> void:
	var worn: CharacterView = (load(CharacterView.SCENE) as PackedScene).instantiate()
	worn.set_model(AssetTags.KNIGHT)
	worn.apply(_state(AssetTags.GEAR_BLADE), DELTA)
	worn.apply(_state(AssetTags.GEAR_FLAIL), DELTA)
	worn.apply(_state(AssetTags.GEAR_BUCKLER), DELTA)

	var fresh: CharacterView = (load(CharacterView.SCENE) as PackedScene).instantiate()
	fresh.set_model(AssetTags.KNIGHT)
	fresh.apply(_state(AssetTags.GEAR_BUCKLER), DELTA)

	for socket in [CharacterView.LEFT_HAND, CharacterView.RIGHT_HAND]:
		equal(worn.held_tag(socket), fresh.held_tag(socket),
			"a view with a history disagrees with a fresh one about '%s'" % socket)

	# And there is no second copy of any of it on this side: what a socket
	# holds is read off the socket, not off a field.
	for field in ["equipped", "held", "inventory", "weapon", "shield", "slots"]:
		check(not _has_property(worn, field),
			"the view has a field of its own called '%s'" % field)
	worn.queue_free()
	fresh.queue_free()


# --- 4. The seam ---------------------------------------------------------


## The armoury's changer swaps through the engine while a view is driven off
## `CombatDiorama.placements()`, the shell's own reading of the snapshot. Every
## beat of the schedule -- sword, shield, sword, nothing -- lands in the
## sockets, and at each beat the socket the last item hung in is empty.
func _a_change_in_the_world_reaches_the_sockets() -> void:
	var sim := Simulation.new(ScriptedArmoury.SEED)
	check(sim.begin_scenario(Simulation.SCENARIO_ARMOURY),
		"the armoury scenario could not be set out")
	var view: CharacterView = (load(CharacterView.SCENE) as PackedScene).instantiate()
	view.set_model(AssetTags.HOODED_ROGUE)

	var seen := PackedStringArray()
	for _tick in TICKS:
		sim.step()
		var row := _changer_row(sim)
		check(not row.is_empty(), "the changer left the stage")
		if row.is_empty():
			break
		view.apply(row["state"], DELTA)
		var hands := "%s|%s" % [
			view.held_tag(CharacterView.RIGHT_HAND),
			view.held_tag(CharacterView.LEFT_HAND),
		]
		if seen.is_empty() or seen[seen.size() - 1] != hands:
			seen.append(hands)
	equal(" then ".join(seen),
		" then ".join(PackedStringArray([
			"%s|" % AssetTags.GEAR_BLADE,
			"|%s" % AssetTags.GEAR_BUCKLER,
			"%s|" % AssetTags.GEAR_BLADE,
			"|",
		])),
		"the sockets should follow the changer's schedule beat for beat")
	view.queue_free()


# --- 5. The measurements -------------------------------------------------


## The identity mount rests on measured facts about the models as built; this
## re-measures them, so a repointed row that breaks a convention is a failure
## with a number in it and not a sword through an arm.
##
## The conventions, from ./tools/measure_held.sh (quoted in CharacterView):
## every elongated weapon lies along its model's +Y with the grip at the
## origin and more of it in front of the grip than behind; the bow lies along
## Z, which the slot turns upright; the buckler is a disc in XY with its boss
## out along +Z; and everything is sized in the rig's own order against its
## 2.5-unit characters.
func _the_measured_conventions_still_hold() -> void:
	var along := {
		AssetTags.GEAR_BLADE: 1, AssetTags.GEAR_DAGGER: 1, AssetTags.GEAR_SPEAR: 1,
		AssetTags.GEAR_STAFF: 1, AssetTags.GEAR_FLAIL: 1, AssetTags.GEAR_BOW: 2,
	}
	for tag in along:
		var box := _built_box(String(tag))
		var axis := int(along[tag])
		var length := box.size[axis]
		for other in 3:
			if other != axis:
				check(box.size[other] < length,
					"'%s' is no longer longest along axis %d" % [tag, axis])
		check(length >= 0.8 and length <= 2.4,
			"'%s' is %.3f long, out of the rig's order" % [tag, length])
		var behind := -box.position[axis]
		var ahead := box.position[axis] + box.size[axis]
		check(behind >= 0.0 and ahead > 0.0,
			"'%s' no longer has its grip at the origin" % tag)
		check(ahead >= behind,
			"'%s' has more of itself behind the grip than in front" % tag)

	var buckler := _built_box(AssetTags.GEAR_BUCKLER)
	check(buckler.size.z < buckler.size.x and buckler.size.z < buckler.size.y,
		"the buckler's face is no longer the XY disc")
	check(buckler.position.z + buckler.size.z > -buckler.position.z,
		"the buckler's boss no longer points out along +Z")


# --- Furniture -----------------------------------------------------------


## A state with one thing (or nothing) in the hand slot, shaped exactly as
## `CombatDiorama.placements()` shapes it.
static func _state(hand_tag: String) -> Dictionary:
	var equipped := {}
	if hand_tag != "":
		equipped[Item.SLOT_HAND] = hand_tag
	return {"speed": 0.0, "alive": true, "equipped": equipped}


## The diorama row for the armoury's changer, or {} if it has gone.
static func _changer_row(sim: Simulation) -> Dictionary:
	var snapshot := sim.world.snapshot()
	for row in CombatDiorama.placements(snapshot):
		if not bool(row["commander"]):
			continue
		var one := sim.world.combat.member_of(int(row["id"]))
		if (one.piece as Commander).sheet.character_name == ScriptedArmoury.CHANGER:
			return row
	return {}


static func _built_box(tag: String) -> AABB:
	var model := AssetLibrary.build(tag)
	var box := _aabb(model, Transform3D.IDENTITY)
	model.free()
	return box


static func _aabb(node: Node, up_to_here: Transform3D) -> AABB:
	var carried := up_to_here
	if node is Node3D:
		carried = up_to_here * (node as Node3D).transform
	var merged := AABB()
	var started := false
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			merged = carried * mesh.get_aabb()
			started = true
	for child in node.get_children():
		var below := _aabb(child, carried)
		if below.size == Vector3.ZERO and below.position == Vector3.ZERO:
			continue
		merged = merged.merge(below) if started else below
		started = true
	return merged


static func _has_property(on: Object, named: String) -> bool:
	for property in on.get_property_list():
		if String(property["name"]) == named \
				or String(property["name"]) == "_%s" % named:
			return true
	return false
