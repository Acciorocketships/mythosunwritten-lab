extends TestSuite
## An inventory a person can operate: the character sheet with controls on it.
##
## `tests/test_ui_panel.gd` showed the sheet as a readout -- it holds a reference
## to the simulation's own `Character`, re-reads every number off it every frame
## and offers nothing to press. This is the same panel with controls, and the
## point of the suite is that adding them added no rule and no second copy of
## anything.
##
## Six claims:
##
##   1. **Every change is made from input, through the world.** One seeded run of
##      the play scenario, driven by key presses through `PlayerControls`: the
##      boots go on and come off, the sword comes out of hand and goes back, a
##      bargain is paid for, a thing is given away, a thing is dropped and a
##      draught is drunk. Every row of the table is an answer the engine gave.
##   2. **The rules are the simulation's and the interface refuses nothing.**
##      Three attempts the rules turn down come back in the engine's own words,
##      and the interface builds all three rather than declining to.
##   3. **Equipping changes what the character can do**, shown before and after:
##      a pair of boots adds a way of moving and a sword taken out of hand takes
##      its attacks with it.
##   4. **The panel still holds no copy.** It is built, handed a character, the
##      character is changed behind its back, and the change is on it at the next
##      refresh; it has no field of its own for anything it draws.
##   5. **A control on the panel is a key press.** Every button hands its keycode
##      to the shell's own input path and does nothing else, so a click and a key
##      are one thing and there is no second way into the world.
##   6. **The sheet opens and shuts** without the simulation being told.
class_name TestPlayerInventory

## The seed and the stage: the play scenario, the same one every other
## walkthrough of the control surface is played on.
const SEED := ScriptedPlay.SEED

## What the cast carries, read back off the scenario rather than typed again.
const HOB := ScriptedPlay.HOB
const SWORD := ScriptedPlay.SWORD
const BOOTS := ScriptedPlay.BOOTS
const BLANKET := ScriptedPlay.BLANKET
const DRAUGHT := ScriptedPlay.DRAUGHT
const LANTERN := ScriptedPlay.LANTERN

## How long the run waits between beats so the trader can take his own turn.
const BREATH := 12

## The fields a panel may not have one of its own. The same list
## `tests/test_ui_panel.gd` asks for, because the claim is the same claim and a
## second list of it would drift.
const NO_FIELDS := [
	"level", "status", "health", "scores", "money", "inventory", "equipment",
	"carried",
]


func _init() -> void:
	suite_name = "player inventory"


func run() -> void:
	var played := play()
	_every_change_was_made_from_input(played)
	_the_rules_are_the_simulations(played)
	_equipping_changes_what_the_character_can_do(played)
	_the_panel_still_holds_no_copy()
	_a_control_is_a_key_press()
	_the_sheet_opens_and_shuts()


# --- 1: one seeded run ------------------------------------------------------


## Drive the whole wardrobe from key presses and hand back what happened.
##
## Public because `tools/play_inventory.gd` prints the same table: the run that is
## the evidence and the run that is the test are one run played by one script.
##
## The driver is `TestPlayerActions`' -- one press, one answer, one row -- rather
## than a second copy of it here, so the two suites cannot come to disagree about
## what "performed from input" means.
static func play() -> Dictionary:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var run := {
		"world": world,
		"id": world.follow_id,
		"choice": WorldCast.hand_over(world, world.follow_id),
		"controls": PlayerControls.new(),
		"table": [],
		"notes": PackedStringArray(),
		"loadout": [],
	}
	if run["choice"] == null:
		return run

	# The wardrobe, with the loadout read on either side of every change: what a
	# character can do is its gear (section 3.4), so a change of gear is only
	# shown by what it changed.
	_note_loadout(run, "to begin with")
	_wear(run, BOOTS, PlayerControls.KEY_EQUIP, "boots on")
	_wear(run, SWORD, PlayerControls.KEY_UNEQUIP, "sword out of hand")
	_wear(run, SWORD, PlayerControls.KEY_EQUIP, "sword back in hand")

	# Three the rules turn down: a draught goes in no slot, a sword is not drunk,
	# and a blanket that is not worn cannot be taken off. All three are built by
	# the interface and refused by the simulation, which is the whole claim.
	TestPlayerActions._hold(run, DRAUGHT)
	TestPlayerActions._press(run, PlayerControls.KEY_EQUIP)
	TestPlayerActions._hold(run, SWORD)
	TestPlayerActions._press(run, PlayerControls.KEY_USE)
	TestPlayerActions._hold(run, BLANKET)
	TestPlayerActions._press(run, PlayerControls.KEY_UNEQUIP)

	# The draught, drunk by somebody with something to mend.
	run["health_before"] = _health(run)
	TestPlayerActions._hold(run, DRAUGHT)
	TestPlayerActions._press(run, PlayerControls.KEY_USE)
	run["health_after"] = _health(run)

	# Money and a gift: walk over to Hob, buy the lantern he is selling, and hand
	# him the blanket for nothing, which is section 2.1's "giving is a trade with
	# nothing in return".
	TestPlayerActions._aim_at(run, HOB)
	TestPlayerActions._press(run, PlayerControls.KEY_APPROACH)
	TestPlayerActions._breathe(run, BREATH)
	run["money_before"] = _money(run)
	TestPlayerActions._press(run, PlayerControls.KEY_ACCEPT)
	TestPlayerActions._breathe(run, BREATH)
	run["money_after"] = _money(run)
	run["bought"] = _carries(run, LANTERN)
	TestPlayerActions._hold(run, BLANKET)
	TestPlayerActions._press(run, PlayerControls.KEY_OFFER)
	TestPlayerActions._breathe(run, BREATH)

	# And a thing put down: the lantern that was just bought, left on the ground.
	TestPlayerActions._hold(run, LANTERN)
	TestPlayerActions._press(run, PlayerControls.KEY_DROP)
	return run


func _every_change_was_made_from_input(run: Dictionary) -> void:
	check(run.get("choice", null) != null, "there should have been somebody to hand over")
	var table: Array = run["table"]
	var done := {}
	for row in table:
		if bool(row["ok"]):
			done[String(row["verb"])] = true
	for named in [
		ActionCatalog.EQUIP, ActionCatalog.UNEQUIP, ActionCatalog.USE,
		ActionCatalog.DROP, ActionCatalog.TRADE_PROPOSE,
		ActionCatalog.TRADE_ACCEPT,
	]:
		check(done.has(named), "'%s' never went through from input" % named)
	for row in table:
		check(String(row["answer"]).begins_with(String(row["verb"])),
			"the engine's answer to %s does not name it: %s" % [row["verb"], row["answer"]])

	# Money left the person's purse, by the trade rules and not by anything here.
	var spent := int(run.get("money_before", 0)) - int(run.get("money_after", 0))
	equal(spent, ScriptedPlay.LANTERN_PRICE,
		"the bargain should have cost the lantern's price")
	check(bool(run.get("bought", false)),
		"and the lantern should have changed hands")
	check(not _carries(run, LANTERN),
		"and then have been put down again, because it was dropped")

	# The blanket was given away: it is not carried and Hob has it.
	check(not _carries(run, BLANKET), "the blanket was given away and is still carried")
	var world: SimWorld = run["world"]
	var hob := ScriptedPlay.id_of(world.combat.scene, HOB)
	check(_carried_by(world, hob, BLANKET), "and Hob has not got it")

	# And the draught is gone, because a thing that is used up is used up.
	check(not _carries(run, DRAUGHT), "the draught was drunk and is still carried")

	# What it did: the character started `FEN_SCRATCHED` down and the draught is
	# worth more than that, so the mending is what was missing and not what the
	# draught was worth -- the cap is the item layer's arithmetic and not this
	# suite's.
	var before := int(run.get("health_before", 0))
	var after := int(run.get("health_after", 0))
	equal(after - before, ScriptedPlay.FEN_SCRATCHED,
		"the draught should have mended what was missing: %d -> %d" % [before, after])
	for row in table:
		if String(row["verb"]) == ActionCatalog.USE and bool(row["ok"]):
			check(String(row["answer"]).contains("mended=%d" % (after - before)),
				"and the answer should say by how much: %s" % row["answer"])


# --- 2: the rules are the simulation's --------------------------------------


func _the_rules_are_the_simulations(run: Dictionary) -> void:
	var refused := {}
	for row in run.get("table", []):
		if not bool(row["ok"]):
			refused[String(row["reason"])] = String(row["verb"])
	check(refused.size() >= 3,
		"three attempts should have been refused, got %d: %s" % [
			refused.size(), str(refused.keys()),
		])
	_a_refusal_saying(refused, "goes in no slot",
		"a draught cannot be worn, and the inventory is what says so")
	_a_refusal_saying(refused, "is not used up",
		"a sword is not drunk, and the engine is what says so")
	_a_refusal_saying(refused, "not wearing or holding",
		"a thing that is not on cannot be taken off")

	# And the interface said none of it: every one of the three was built and
	# handed over, which is why there is an answer to quote at all.
	var controls := PlayerControls.new()
	var view := Surroundings.new()
	view.carrying = PackedStringArray([DRAUGHT])
	controls.holding = DRAUGHT
	for keycode in [
		PlayerControls.KEY_EQUIP, PlayerControls.KEY_UNEQUIP, PlayerControls.KEY_USE,
	]:
		var built := controls.press(keycode, view)
		check(built != null, "the interface declined to build %d itself" % keycode)
		check(ActionCatalog.is_action(built.kind),
			"and what it built is not a row of the catalogue: %s" % built.kind)
	equal(controls.note, "", "and it had nothing of its own to say about any of them")


func _a_refusal_saying(refused: Dictionary, phrase: String, why: String) -> void:
	for reason in refused:
		if String(reason).contains(phrase):
			return
	check(false, "%s -- no refusal said '%s': %s" % [why, phrase, str(refused.keys())])


# --- 3: gear is what a character can do -------------------------------------


func _equipping_changes_what_the_character_can_do(run: Dictionary) -> void:
	var readings: Array = run.get("loadout", [])
	check(readings.size() >= 4, "the run should have read the loadout four times")
	var start: Dictionary = readings[0]
	var booted: Dictionary = readings[1]
	var bare_handed: Dictionary = readings[2]
	var armed: Dictionary = readings[3]

	equal(int(booted["moves"]), int(start["moves"]) + 1,
		"a pair of boots should have added a way of moving: %d -> %d" % [
			int(start["moves"]), int(booted["moves"]),
		])
	check(int(start["attacks"]) > 0, "the sword should have been in hand to begin with")
	equal(int(bare_handed["attacks"]), 0,
		"a sword taken out of hand should have taken its attacks with it")
	check(int(armed["attacks"]) > 0,
		"and putting it back should have given them back: %d" % int(armed["attacks"]))
	equal(int(armed["moves"]), int(booted["moves"]),
		"while the boots stayed on through all of it")


# --- 4: still a view --------------------------------------------------------


func _the_panel_still_holds_no_copy() -> void:
	if not SproutPack.is_installed():
		return
	var theme := SproutTheme.build()
	if theme == null:
		return
	var panel := CharacterPanel.new()
	panel.theme = theme
	var sheet := Character.make("Fen", 2)
	sheet.record_scores(ScriptedPlay.ROLL)
	sheet.health = sheet.max_health()
	var boots := Armour.boots(2)
	sheet.inventory.carry(boots)
	panel.show_sheets([sheet] as Array[Character])
	panel.refresh()
	equal(panel._carried_count.text, "carried 1", "the panel should see one thing carried")

	# Moved without the panel being told: put on, then taken off, then spent.
	sheet.inventory.equip(boots)
	panel.refresh()
	equal(panel._equipment[Item.SLOT_BOOTS].theme_type_variation, SproutTheme.SLOT_FULL,
		"the boots going on should show without anything pushing it")
	sheet.inventory.unequip(Item.SLOT_BOOTS)
	panel.refresh()
	equal(panel._equipment[Item.SLOT_BOOTS].theme_type_variation, SproutTheme.SLOT_EMPTY,
		"and coming off again")
	sheet.inventory.release(boots)
	panel.refresh()
	equal(panel._carried_count.text, "carried 0", "and being let go of")

	# And it has no field of its own for any of it.
	for field in NO_FIELDS:
		equal(panel.get(field), null,
			"the panel has a field called '%s' of its own" % field)
	panel.free()


# --- 5: a control is a key press -------------------------------------------


func _a_control_is_a_key_press() -> void:
	if not SproutPack.is_installed():
		return
	var theme := SproutTheme.build()
	if theme == null:
		return
	var panel := CharacterPanel.new()
	panel.theme = theme
	var pressed := PackedInt32Array()
	panel.on_key = func(keycode: int) -> void: pressed.append(keycode)
	# Every control on the panel, pressed the way a pointer presses it: the
	# button's own signal.
	var wanted := PackedInt32Array()
	for entry in CharacterPanel.CONTROLS:
		wanted.append(int(entry["key"]))
	var row := panel._control_row
	equal(row.get_child_count(), CharacterPanel.CONTROLS.size(),
		"there should be one button per control")
	for index in row.get_child_count():
		(row.get_child(index) as Button).emit_signal("pressed")
	equal(pressed, wanted,
		"a button should press its own key and nothing else")

	# With nobody driving there is nowhere for a press to go, and pressing is
	# still not an error: the panel asks and the shell is not listening.
	var idle := CharacterPanel.new()
	idle.theme = theme
	idle.press(PlayerControls.KEY_EQUIP)
	panel.free()
	idle.free()


# --- 6: opening and shutting ------------------------------------------------


func _the_sheet_opens_and_shuts() -> void:
	if not SproutPack.is_installed():
		return
	var theme := SproutTheme.build()
	if theme == null:
		return
	var panel := CharacterPanel.new()
	panel.theme = theme
	var sheet := Character.make("Fen", 2)
	panel.show_sheets([sheet] as Array[Character])
	var was := sheet.sheet_line()
	panel.open = false
	panel.refresh()
	check(not panel.visible, "a shut sheet should not be on screen")
	panel.toggle()
	panel.refresh()
	check(panel.visible, "and an opened one should be")
	equal(sheet.sheet_line(), was,
		"and opening it should have changed nothing about the character")
	panel.free()


# --- The stage --------------------------------------------------------------


# Hold a named thing and press one of the wardrobe keys, then write down what
# the character can do afterwards.
static func _wear(run: Dictionary, called: String, keycode: int, why: String) -> void:
	TestPlayerActions._hold(run, called)
	TestPlayerActions._press(run, keycode)
	_note_loadout(run, why)


# What the character can do right now, read off the commander the world is
# holding: how many ways it may move and how many attacks it may choose from.
# Both are `Commander`'s own answers, read through the ability gate; nothing
# here computes either.
static func _note_loadout(run: Dictionary, why: String) -> void:
	var me := _commander(run)
	(run["loadout"] as Array).append({
		"why": why,
		"moves": 0 if me == null else me.move_grants().size(),
		"attacks": 0 if me == null else me.attack_count(),
		"tick": (run["world"] as SimWorld).tick,
	})


static func _commander(run: Dictionary) -> Commander:
	var world: SimWorld = run["world"]
	var one := world.combat.scene.actor_of(int(run["id"]))
	if one == null or not (one.piece is Commander):
		return null
	return one.piece as Commander


static func _health(run: Dictionary) -> int:
	var me := _commander(run)
	return 0 if me == null else me.health


static func _money(run: Dictionary) -> int:
	var world: SimWorld = run["world"]
	var pack := ActionScene.inventory_of(world.combat.scene.actor_of(int(run["id"])))
	return 0 if pack == null else pack.money


static func _carries(run: Dictionary, called: String) -> bool:
	return _carried_by(run["world"], int(run["id"]), called)


static func _carried_by(world: SimWorld, id: int, called: String) -> bool:
	var pack := ActionScene.inventory_of(world.combat.scene.actor_of(id))
	if pack == null:
		return false
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == called:
			return true
	return false


## The table one line per row, in the form `tools/play_inventory.gd` prints and
## this suite asserts over.
static func table_lines(run: Dictionary) -> PackedStringArray:
	var written := PackedStringArray([
		"%-14s %5s  %-22s %s" % ["verb", "tick", "at", "the engine's answer"],
	])
	for row in run.get("table", []):
		written.append("%-14s %5d  %-22s %s" % [
			row["verb"], int(row["tick"]), row["at"], row["answer"],
		])
	return written


## What the character could do at each reading, one line each.
static func loadout_lines(run: Dictionary) -> PackedStringArray:
	var written := PackedStringArray([
		"%5s  %-22s %6s %8s" % ["tick", "after", "moves", "attacks"],
	])
	for reading in run.get("loadout", []):
		written.append("%5d  %-22s %6d %8d" % [
			int(reading["tick"]), reading["why"],
			int(reading["moves"]), int(reading["attacks"]),
		])
	return written
