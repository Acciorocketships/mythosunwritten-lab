extends RefCounted
## Every atomic action, called once, written down: the walkthrough this layer is
## demonstrated by and the determinism witness for it.
##
##     ./run_actions.sh
##
## Nothing here decides anything. The scene is a list of constants -- a seed, two
## world positions, four items, two characters -- and every choice made in it is
## an `Action` written out below. What each call *does* is `ActionEngine`'s
## answer, and the only thing this file contributes to an outcome is which action
## was chosen. That is the same division `sim/scripted_match.gd` keeps with the
## turn economy and `sim/scripted_encounter.gd` keeps with the fight: the
## scenario chooses, the engine resolves, and two processes therefore print the
## same bytes.
##
## ## The four sections
##
##   * **the one list** -- section 2.1's actions beside section 10's call names,
##     printed out of `ActionCatalog` rather than typed here, so the transcript
##     cannot claim a surface the code does not have.
##   * **the walkthrough** -- all but one of the actions on one scene, in the
##     order a character would take them: look about, speak, walk to a pile, pick
##     something up, put it down, try a jump DEX will not carry, jump one it
##     will, walk to a chest, fail to open it, open it with the lockpick, take
##     what is inside, offer a trade, be denied, offer again, be accepted, and
##     wait.
##   * **the duel** -- the twelfth. Two commanders meet, the board appears under
##     them, and the same `attack` call is made twice: once with a bow, whose
##     ring cannot reach a target standing next to it, and once with a spear,
##     which can.
##   * **two minds, one surface** -- the same choice made by a person's recorded
##     choices and by a rule reading the world, on two scenes set out
##     identically, printing both fingerprints.
class_name ScriptedActions

## The seed the scenario is written for, and the ground it is played on: the same
## measured open meadow `sim/scripted_encounter.gd` holds its fight in, so no new
## coordinate is invented here and no new claim is made about the world.
const SEED := ScriptedEncounter.SEED
const WHERE := ScriptedEncounter.WHERE

## What the two characters are worth. Rook is levelled and rolled; Wren is not,
## which is deliberate -- an unrecorded score is not a zero, and Wren is here to
## be traded with rather than measured.
const ROOK_LEVEL := 3
const WREN_LEVEL := 2

## Rook's dexterity, and so how far Rook jumps: `JUMP_BASE + 4 x JUMP_PER_DEX`.
const ROOK_DEX := 4

## What the two characters start with. Names rather than literals scattered
## through the transcript, because every one of them is said three or four times
## -- once to put it in the world, once to choose an action naming it, once to
## read the outcome.
const LOCKPICK := "lockpick"
const HATCHET := "worn hatchet"
const BOOTS := "leather boots"
const CAP := "steel cap"

## Where things stand, as offsets from `WHERE` in world units. The pile is a
## short walk away, the chest a longer one, and Wren is at arm's length, because
## a trade is made within `ActionEngine.REACH`.
const PILE_AT := Vector2(6.0, 0.0)
const CHEST_AT := Vector2(10.0, 0.0)
const WREN_AT := Vector2(1.5, 0.0)

## Where Rook tries to jump to, and where Rook then jumps to, as offsets from
## `WHERE`. Both are chosen against where Rook is standing by then -- beside the
## pile, having just put the hatchet back down -- so the first is past what DEX 4
## reaches and the second is inside it.
const JUMP_TOO_FAR := Vector2(14.0, 0.0)
const JUMP_NEAR := Vector2(7.5, -1.0)

## What the trade is: Rook's coins for Wren's boots.
const TRADE_COINS := 5

## What each starts with in coins.
const ROOK_MONEY := 20
const WREN_MONEY := 3

## What is in the chest.
const CHEST_MONEY := 12

## How long Rook waits at the end of the walkthrough.
const WAIT_TICKS := 5

## How many decisions each of the two decision functions is asked for. Three:
## walk to the pile, take what is on it, look at what was taken.
const DRIVE_STEPS := 3

## How far apart the two duellists stand, in world units, along x only. Two cells
## of the combat lattice: near enough that a spear's front reaches and far enough
## that a bow's ring -- which starts five cells out -- cannot.
const DUEL_APART := 6.0


# --- The one list ---------------------------------------------------------


## Section 2.1's actions and section 10's call names, printed off the table
## itself.
static func catalogue_lines() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the one list: %d actions, %d call names" % [
		ActionCatalog.names().size(), ActionCatalog.call_names().size(),
	])
	for line in ActionCatalog.table_lines():
		written.append("  " + line)
	return written


# --- The walkthrough ------------------------------------------------------


## Set out the scene the walkthrough is played on: Rook, Wren, a pile and a
## chest, on the meadow at `WHERE`.
static func stage() -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))

	var rook := scene.add_actor(Combatant.commander_at(
		WHERE.x, WHERE.y, 0.0, 0.0, ROOK_LEVEL, AssetTags.KNIGHT))
	var rook_sheet := Character.make("Rook", ROOK_LEVEL)
	rook_sheet.record_scores({Ability.DEX: ROOK_DEX, Ability.STR: 5, Ability.WIS: 2})
	(rook.piece as Commander).adopt(rook_sheet)
	rook_sheet.inventory.carry(_tool(LOCKPICK))
	rook_sheet.inventory.gain(ROOK_MONEY)

	var wren := scene.add_actor(Combatant.commander_at(
		WHERE.x + WREN_AT.x, WHERE.y + WREN_AT.y, 0.0, 0.0, WREN_LEVEL, AssetTags.MAGE))
	var wren_sheet := Character.make("Wren", WREN_LEVEL)
	(wren.piece as Commander).adopt(wren_sheet)
	wren_sheet.inventory.carry(_wearable(BOOTS, Item.SLOT_BOOTS))
	wren_sheet.inventory.gain(WREN_MONEY)

	scene.add_object(WorldObject.loose(
		WHERE.x + PILE_AT.x, WHERE.y + PILE_AT.y,
		Inventory.ground([_tool(HATCHET)])))
	scene.add_object(WorldObject.chest(
		"chest", WHERE.x + CHEST_AT.x, WHERE.y + CHEST_AT.y,
		Inventory.of([_wearable(CAP, Item.SLOT_HELMET)], CHEST_MONEY), LOCKPICK))
	return scene


## Every choice the walkthrough makes, in order, as `{"who": id, "action": …}`.
##
## Written as data rather than as calls so that the same list can be read by a
## person, replayed, and -- being a list of `Action`s -- fed to a recorded
## decision function unchanged.
static func walkthrough_choices(scene: ActionScene) -> Array:
	var rook := scene.actors[0]
	var wren := scene.actors[1]
	var pile := scene.objects[0]
	var chest := scene.objects[1]
	return [
		{"who": rook, "action": Action.examine(wren.id)},
		{"who": rook, "action": Action.examine(LOCKPICK)},
		{"who": rook, "action": Action.say("well met", wren.id)},
		{"who": rook, "action": Action.say("anyone about?")},
		{"who": rook, "action": Action.go_to(pile.id)},
		{"who": rook, "action": Action.pick_up(HATCHET)},
		{"who": rook, "action": Action.drop(HATCHET)},
		{"who": rook, "action": Action.jump(WHERE + JUMP_TOO_FAR)},
		{"who": rook, "action": Action.jump(WHERE + JUMP_NEAR)},
		{"who": rook, "action": Action.go_to(chest.id)},
		{"who": rook, "action": Action.interact(chest.id)},
		{"who": rook, "action": Action.interact(chest.id, LOCKPICK)},
		{"who": rook, "action": Action.pick_up(CAP, chest.id)},
		{"who": rook, "action": Action.go_to(wren.id)},
		{"who": rook, "action": Action.trade_propose(
			wren.id, PackedStringArray(), TRADE_COINS, PackedStringArray([BOOTS]), 0)},
		{"who": wren, "action": Action.trade_deny(rook.id)},
		{"who": wren, "action": Action.trade_accept(rook.id)},
		{"who": rook, "action": Action.trade_propose(
			wren.id, PackedStringArray(), TRADE_COINS, PackedStringArray([BOOTS]), 0)},
		{"who": wren, "action": Action.trade_accept(rook.id)},
		{"who": rook, "action": Action.wait(WAIT_TICKS)},
	]


## Play the walkthrough and write down what happened.
static func walkthrough() -> PackedStringArray:
	var scene := stage()
	var written := PackedStringArray()
	written.append("walkthrough on seed %d at (%.1f, %.1f)" % [SEED, WHERE.x, WHERE.y])
	written.append_array(_indent(scene.lines()))
	for step in walkthrough_choices(scene):
		var who: Combatant = step["who"]
		var outcome := ActionEngine.resolve(scene, who, step["action"])
		written.append("  %s %s -> %s" % [
			ActionScene.name_of(who), step["action"].line(), outcome.line(),
		])
	written.append("after")
	written.append_array(_indent(scene.lines()))
	written.append("  fingerprint %s" % scene.fingerprint())
	return written


# --- The duel -------------------------------------------------------------


## Two commanders, two cells apart, and the one action that reaches the board.
##
## The same `attack` call is made twice with two different items. The bow is
## refused because no rotation of a ring that starts five cells out covers a
## target standing two cells away -- which is what "outside the pattern" means
## once turning is free -- and the spear lands, through the match's own turn
## economy and the one damage seam.
static func duel() -> PackedStringArray:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var rook := scene.add_actor(Combatant.commander_at(
		WHERE.x - DUEL_APART * 0.5, WHERE.y, 0.0, 0.0, ROOK_LEVEL, AssetTags.KNIGHT))
	var rook_sheet := Character.make("Rook", ROOK_LEVEL)
	rook_sheet.record_scores({Ability.STR: 5, Ability.DEX: ROOK_DEX})
	(rook.piece as Commander).adopt(rook_sheet)
	(rook.piece as Commander).wield(Weapon.held(Weapon.bow(), ROOK_LEVEL))
	(rook.piece as Commander).wield(Weapon.held(Weapon.spear(), ROOK_LEVEL))

	var vex := scene.add_actor(Combatant.commander_at(
		WHERE.x + DUEL_APART * 0.5, WHERE.y, 0.0, 0.0, WREN_LEVEL, AssetTags.BARBARIAN))
	var vex_sheet := Character.make("Vex", WREN_LEVEL)
	(vex.piece as Commander).adopt(vex_sheet)

	var written := PackedStringArray()
	written.append("duel on seed %d, %.1f units apart" % [SEED, DUEL_APART])
	var began := scene.begin_fight(rook.id)
	if began == null or began.refused:
		written.append("  the fight was refused: %s" % (
			"no ground" if began == null else "nobody could be seated"))
		return written
	written.append("  seated: %s" % _cells(scene))
	var acting := _whose_turn(scene)
	written.append("  it is %s's turn" % ActionScene.name_of(acting))
	var other := vex if acting == rook else rook
	for chosen in [
		Action.attack(other.id, "common bow"),
		Action.attack(other.id, "common spear"),
	]:
		var outcome := ActionEngine.resolve(scene, acting, chosen)
		written.append("  %s %s -> %s" % [
			ActionScene.name_of(acting), chosen.line(), outcome.line(),
		])
	written.append("  %s" % _cells(scene))
	return written


# --- Two minds, one surface ----------------------------------------------


## The same choice, made twice: once by a person's recorded choices and once by a
## rule that reads the world, on two scenes set out identically.
##
## Both decision functions go on `Character.decide`, both are called by
## `DecisionSource.drive`, and both have their answers resolved by
## `ActionEngine.resolve`. What is compared is the scene's fingerprint: if the
## surface were not identical, the two worlds would not be.
static func two_minds() -> PackedStringArray:
	var written := PackedStringArray()
	var by_hand := stage()
	var by_rule := stage()

	var hand_rook := by_hand.actors[0]
	var hand_pile := by_hand.objects[0]
	_sheet(hand_rook).decide = DecisionSource.recorded([
		Action.go_to(hand_pile.id),
		Action.pick_up(HATCHET),
		Action.examine(HATCHET),
	])
	var rule_rook := by_rule.actors[0]
	_sheet(rule_rook).decide = DecisionSource.scripted(ScriptedActions._reach_for_it)

	var by_hand_taken := DecisionSource.drive(by_hand, hand_rook, DRIVE_STEPS)
	var by_rule_taken := DecisionSource.drive(by_rule, rule_rook, DRIVE_STEPS)

	written.append("recorded choices, driven by a person's list")
	written.append_array(_indent(DecisionSource.transcript(by_hand_taken)))
	written.append("  fingerprint %s" % by_hand.fingerprint())
	written.append("computed choices, driven by a rule reading the world")
	written.append_array(_indent(DecisionSource.transcript(by_rule_taken)))
	written.append("  fingerprint %s" % by_rule.fingerprint())
	written.append("same world change: %s" % (
		"yes" if by_hand.fingerprint() == by_rule.fingerprint() else "no"))
	return written


## The rule the scripted decision function computes with: reach for the hatchet.
##
## It reads the world it is handed and nothing else -- what is carried, what is
## lying about, how far away it is -- and it chooses; it never asks whether it
## may, because that is the engine's answer and it would be a second one.
static func _reach_for_it(scene: ActionScene, actor: Combatant) -> Action:
	var pack := ActionScene.inventory_of(actor)
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == HATCHET:
			return Action.examine(HATCHET)
	for thing in scene.objects:
		if thing.contents == null:
			continue
		for entry in thing.contents.carried:
			var item := Inventory.item_of(entry)
			if item == null or item.item_name != HATCHET:
				continue
			if thing.distance_from(actor.x, actor.z) > ActionEngine.REACH:
				return Action.go_to(thing.id)
			return Action.pick_up(HATCHET)
	return null


# --- The whole transcript -------------------------------------------------


## Everything above, in order. What `./run_actions.sh` prints.
static func report() -> PackedStringArray:
	var written := PackedStringArray()
	written.append_array(catalogue_lines())
	written.append("")
	written.append_array(walkthrough())
	written.append("")
	written.append_array(duel())
	written.append("")
	written.append_array(two_minds())
	return written


# --- The scene's furniture ------------------------------------------------


# A hand-held item at level 1: a lockpick, a hatchet. Everything it is worth goes
# to its effects axis, which is where a held item's worth goes.
static func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


# A worn item at level 2, half defence and half movement.
static func _wearable(called: String, slot: String) -> Item:
	return Item.armour(
		called, slot, 2, ItemRarity.COMMON, Ability.DEX, [1, 1, 0] as Array[int])


static func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet


# Whose turn it is in the fight, as the character standing in the world.
static func _whose_turn(scene: ActionScene) -> Combatant:
	for one in scene.actors:
		if one.piece.id == scene.fight.match_state.active_id():
			return one
	return scene.actors[0]


# Where everybody is standing on the lattice, in one line.
static func _cells(scene: ActionScene) -> String:
	var written := PackedStringArray()
	for one in scene.actors:
		written.append("%s (%d,%d) hp=%d" % [
			ActionScene.name_of(one), one.piece.cell.x, one.piece.cell.y,
			one.piece.health,
		])
	return " ".join(written)


static func _indent(lines: PackedStringArray) -> PackedStringArray:
	var written := PackedStringArray()
	for line in lines:
		written.append("  " + line)
	return written
