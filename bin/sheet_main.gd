extends SceneTree
## Print what a character sheet holds, headless. Nothing else.
##
## Run it with:  ./run_sheet.sh
##
## Every number below is read off `sim/` -- the sheet, the level scaling, the
## item power budget and the ability-score gate. Nothing draws a random number
## and nothing reads a clock, so two runs print the same bytes.

## Two characters, made the same way and differing in one thing each: what is
## attached to `decide`, and whether anybody assigned a diplomatic standing.
const ADVENTURER := "Wren"
const NOBLE := "Bramble"

## The scores the two are rolled with, in section 2's order.
const ROLLED := {
	ADVENTURER: [12, 11, 9, 14, 8, 10],
	NOBLE: [7, 8, 16, 9, 13, 12],
}


func _initialize() -> void:
	var person := _rolled(ADVENTURER)
	person.backstory = "a marsh lantern-keeper's daughter, out of the reeds"
	person.goal = "find the lantern her mother left on the far bank"
	person.traits = PackedStringArray(["curious", "stubborn"])
	person.tendencies = PackedStringArray(["cautious", "friendly"])

	var agent := _rolled(NOBLE)
	agent.backstory = "third child of a blossom-grove house, never in a fight"
	agent.goal = "be owed a favour by everyone who matters"
	agent.traits = PackedStringArray(["charming", "idle"])
	agent.tendencies = PackedStringArray(["greedy", "diplomatic"])
	agent.decide = func(_of: Character) -> String: return "wait"
	agent.set_status(12)

	_two_sheets(person, agent)
	_status_and_level(person, agent)
	_a_level_up(person)
	_the_gate_through_the_sheet()
	quit(0)


# --- 1. Two sheets, one type ----------------------------------------------


func _two_sheets(person: Character, agent: Character) -> void:
	print("two characters, one type: %s" % person.get_script().resource_path)
	for sheet in [person, agent]:
		print("  %s" % sheet.sheet_line())
		print("      %s" % sheet.identity_line())
		print("      decision function attached: %s" % (
			"no" if sheet.decide.is_null() else "yes"
		))
	print("  fields on each sheet: %d, and the same %d" % [
		_fields(person).size(), _fields(agent).size(),
	])
	print("  %s" % ", ".join(_fields(person)))
	print("")


# --- 2. Status is not the level -------------------------------------------


func _status_and_level(person: Character, agent: Character) -> void:
	print("status is a separate attribute from level")
	print("  who        level  status  assigned")
	for sheet in [person, agent]:
		print("  %-9s %5d %7d  %s" % [
			sheet.character_name, sheet.level, sheet.status(),
			"-" if sheet.assigned_status < 0 else str(sheet.assigned_status),
		])
	print("  nobody assigned %s a standing, so its status is its level; the" % ADVENTURER)
	print("  orchestrator assigned %s one, so the two numbers part." % NOBLE)
	print("")


# --- 3. A level-up --------------------------------------------------------


func _a_level_up(person: Character) -> void:
	print("one level-up: one point on one score, and nothing else")
	print("  when       level  health  %s" % _score_header())
	print("  before     %5d %7d  %s" % [
		person.level, person.max_health(), _score_row(person),
	])
	person.level_up(Ability.DEX)
	print("  after DEX  %5d %7d  %s" % [
		person.level, person.max_health(), _score_row(person),
	])
	print("  the level everything reads is that one level:")
	var commander := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, 1)
	commander.adopt(person)
	print("    piece level %d, sheet level %d, health %d/%d" % [
		commander.level, person.level, commander.health, commander.max_health(),
	])
	var forged := Armour.worn(Armour.HELMET, commander.level)
	print("    a common helmet forged at that level: P=%d, item level %d" % [
		forged.item.budget(), forged.item.level,
	])
	print("")


# --- 4. The gate, read through the sheet -----------------------------------


func _the_gate_through_the_sheet() -> void:
	print("one level-8 loadout, read by six wearers -- through the sheet")
	print("  score  def  cut  cleave")
	var commander := Commander.make(Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, 8)
	for slot in Armour.SLOTS:
		commander.equip(Armour.worn(slot, 8))
	commander.wield(Weapon.held(Weapon.sword(), 8))
	print("  %5s %4d %4d %7d" % [
		"-", commander.defence(), commander.damage_of(0), commander.damage_of(1),
	])
	for score in [8, 6, 4, 3, 2, 0]:
		for ability in Ability.ALL:
			commander.sheet.set_score(ability, score)
		print("  %5d %4d %4d %7d" % [
			score, commander.defence(), commander.damage_of(0), commander.damage_of(1),
		])
	print("  the first row is a sheet with no score recorded, which reads the")
	print("  item at its own level -- in full, the same as a score of 8.")
	print("")


# --- Helpers --------------------------------------------------------------


func _rolled(called: String) -> Character:
	var sheet := Character.make(called, 3)
	var rolled: Array = ROLLED[called]
	for index in Ability.ALL.size():
		sheet.set_score(Ability.ALL[index], int(rolled[index]))
	return sheet


func _score_header() -> String:
	var parts := PackedStringArray()
	for ability in Ability.ALL:
		parts.append("%3s" % ability)
	return " ".join(parts)


func _score_row(sheet: Character) -> String:
	var parts := PackedStringArray()
	for ability in Ability.ALL:
		parts.append("%3d" % sheet.score(ability))
	return " ".join(parts)


func _fields(of: Object) -> PackedStringArray:
	var names := PackedStringArray()
	for property in of.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(str(property["name"]))
	return names
