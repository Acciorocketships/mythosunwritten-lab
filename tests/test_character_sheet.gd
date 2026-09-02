extends TestSuite
## One character sheet, and the project holds one of them and not two.
##
## Five claims:
##
##   1. The sheet carries every field section 2 names -- the six ability scores,
##      the level, the status, the health, handles for inventory and equipment,
##      the four identity fields, and handles for the persistent memory and the
##      sentiment map that later milestones fill.
##   2. A character a person drives and a character an agent drives are the same
##      type with the same fields. Shown twice: by reflection over two sheets,
##      and by a scan of every file under sim/ for a word that would mean the
##      simulation knows which kind of character it is holding. The scan is run
##      against a deliberately broken control line and is required to find it, so
##      that an empty result means the scan looked rather than that it never ran.
##   3. A commander reads its ability scores off the sheet and keeps no
##      dictionary of its own, and the item gate's numbers did not move when they
##      were taken off it: the recorded six-wearer table is asserted row by row.
##   4. A level-up spends exactly one point on exactly one named score and
##      changes nothing else, and the level that health, defence, damage and an
##      item's power budget read is that one level -- the piece keeps no copy.
##   5. Status is a separate attribute from the level. Unassigned it tracks the
##      level, which is section 2's "for the player, status = level" without
##      anyone having to say who is a player; assigned, the two numbers part.
class_name TestCharacterSheet

## Every field section 2 names, by the name it has on the sheet.
const SHEET_FIELDS := [
	"scores", "level", "assigned_status", "health",
	"inventory", "equipment",
	"backstory", "goal", "traits", "tendencies",
	"memory", "sentiment", "decide",
]

## Words that would mean a file knows which kind of character it is holding.
const KIND_WORDS := [
	"player", "players", "npc", "npcs", "human", "humans",
	"llm", "ai", "bot", "bots", "robot",
]

## The control the scan is run against. It is written to fail: two kind-words in
## code, on two lines, one of them in a branch. If the scan reports nothing for
## this, the empty result over sim/ means nothing either.
const CONTROL_LINE := "func is_player() -> bool:\n\treturn npc_brain == null\n"

## The gate table `./run_loadout.sh` publishes, and the numbers this task was
## required not to move: one suit of four common level-8 worn items and a common
## level-8 sword, read by wearers of six different ability scores.
## Each row is score, defence, cut, cleave.
const GATE_ROWS := [
	[8, 6, 12, 20],
	[6, 4, 9, 15],
	[4, 3, 6, 10],
	[3, 2, 5, 7],
	[2, 1, 3, 5],
	[0, 0, 0, 0],
]

var _words := RegEx.create_from_string("[A-Z]+(?![a-z])|[A-Z][a-z]*|[a-z]+")


func _init() -> void:
	suite_name = "character sheet"


func run() -> void:
	_the_sheet_carries_section_twos_fields()
	_a_person_and_an_agent_are_one_type()
	_no_file_under_sim_asks_which_kind_of_character()
	_a_commander_reads_its_scores_off_its_sheet()
	_a_level_up_spends_one_point_on_one_score()
	_one_level_is_read_by_everything()
	_status_is_separate_from_the_level()


# --- 1. The whole of section 2's sheet ------------------------------------


func _the_sheet_carries_section_twos_fields() -> void:
	var sheet := Character.make("Wren", 3)
	var present := _field_names(sheet)
	for field in SHEET_FIELDS:
		check(present.has(field), "the sheet has no '%s'" % field)

	for ability in Ability.ALL:
		check(not sheet.has_score(ability),
			"a fresh sheet has already recorded %s" % ability)
		sheet.set_score(ability, 5)
		equal(sheet.score(ability), 5, "the sheet did not keep %s" % ability)
	equal(sheet.scores.size(), 6, "the sheet holds six ability scores")

	# An unrecorded score is not a zero: it reads whatever the caller says it
	# reads, which for the item gate is the item's own level.
	var fresh := Character.make("Bramble", 1)
	equal(fresh.score(Ability.STR, 9), 9, "an unrecorded score is read as zero")
	fresh.set_score(Ability.STR, 0)
	equal(fresh.score(Ability.STR, 9), 0, "a recorded zero is read as unrecorded")

	# The handles later milestones fill are here and empty.
	equal(sheet.inventory.size(), 0, "the inventory handle is not empty")
	equal(sheet.equipment.size(), 0, "the equipment handle is not empty")
	equal(sheet.memory.size(), 0, "the memory handle is not empty")
	equal(sheet.sentiment.size(), 0, "the sentiment handle is not empty")

	# The identity fields hold what is written on them.
	sheet.backstory = "raised by the mushroom keepers of the marsh"
	sheet.goal = "find the lantern her mother left on the far bank"
	sheet.traits = PackedStringArray(["curious", "stubborn"])
	sheet.tendencies = PackedStringArray(["cautious", "friendly"])
	check(sheet.identity_line().contains("mushroom keepers"),
		"the identity line does not carry the backstory")
	check(sheet.identity_line().contains("cautious"),
		"the identity line does not carry the tendencies")


# --- 2. One type for both -------------------------------------------------


func _a_person_and_an_agent_are_one_type() -> void:
	var driven_by_a_person := Character.make("Wren", 4)
	var driven_by_an_agent := Character.make("Wren", 4)
	driven_by_an_agent.decide = func(_of: Character) -> String: return "wait"

	equal(driven_by_an_agent.get_script(), driven_by_a_person.get_script(),
		"the two characters are not the same type")
	equal(_field_names(driven_by_an_agent), _field_names(driven_by_a_person),
		"the two characters do not have the same fields")

	# The only field whose value differs is the decision handle. Everything else
	# on the two sheets is the same, field by field.
	var differing := PackedStringArray()
	for field in _field_names(driven_by_a_person):
		if _value_of(driven_by_a_person, field) != _value_of(driven_by_an_agent, field):
			differing.append(field)
	equal(differing.size(), 1,
		"more than the decision handle differs: %s" % ", ".join(differing))
	equal(differing[0] if differing.size() > 0 else "", "decide",
		"the field that differs is not the decision handle")
	check(driven_by_a_person.decide.is_null(),
		"a sheet with nobody attached already has a decision function")
	check(not driven_by_an_agent.decide.is_null(),
		"attaching a decision function did not attach one")


func _no_file_under_sim_asks_which_kind_of_character() -> void:
	var offenders := PackedStringArray()
	for path in _sim_files():
		for word in _kind_words_in(FileAccess.get_file_as_string(path)):
			offenders.append("%s names '%s'" % [path, word])
	equal(offenders.size(), 0,
		"sim/ asks which kind of character it holds: %s" % ", ".join(offenders))

	# The control. The same function, over a line written to fail it.
	var caught := _kind_words_in(CONTROL_LINE)
	equal(caught.size(), 2,
		"the scan cannot see its own broken control line: [%s]" % ", ".join(caught))

	# And what the scan deliberately does not read as code: prose. Section 3.7's
	# damage matrix says "player" in a comment and must not be a finding.
	equal(_kind_words_in("## a player and an NPC are the same type").size(), 0,
		"the scan reads a comment as code")
	equal(_kind_words_in("\tvar x := 1  # not for an NPC").size(), 0,
		"the scan reads a trailing comment as code")

	# What it does read as code, so that a branch cannot hide in a literal.
	equal(_kind_words_in("\tif kind == \"npc\":").size(), 1,
		"the scan does not read a string literal as code")
	# A `#` inside a string does not end the line for the scan.
	equal(_kind_words_in("\tvar tag := \"#1\"  # a player").size(), 0,
		"a hash inside a string confuses the comment rule")


# --- 3. The commander reads the sheet -------------------------------------


func _a_commander_reads_its_scores_off_its_sheet() -> void:
	var commander := _suited(8)
	check(not _field_names(commander).has("scores"),
		"the commander still keeps its own scores dictionary")
	check(commander.sheet != null, "a commander has no character sheet")

	for row in GATE_ROWS:
		for ability in Ability.ALL:
			commander.sheet.set_score(ability, row[0])
		equal(commander.defence(), row[1],
			"defence at score %d moved" % row[0])
		equal(commander.damage_of(0), row[2],
			"the cut at score %d moved" % row[0])
		equal(commander.damage_of(1), row[3],
			"the cleave at score %d moved" % row[0])

	# Writing through the commander writes on the sheet, and nowhere else.
	commander.set_score(Ability.CON, 2)
	equal(commander.sheet.score(Ability.CON), 2,
		"a score set on the commander did not reach the sheet")

	# And an unrecorded score still reads an item at its own level, in full --
	# the rule the item layer has had since the power budget landed.
	var unrolled := _suited(8)
	equal(unrolled.sheet.scores.size(), 0, "a fresh commander has scores recorded")
	equal(unrolled.defence(), GATE_ROWS[0][1],
		"an unrecorded score no longer reads an item in full")
	equal(unrolled.damage_of(0), GATE_ROWS[0][2],
		"an unrecorded score no longer reads a weapon in full")

	# Two commanders are two sheets: recording a score on one is not recording
	# it on the other.
	unrolled.set_score(Ability.CON, 7)
	not_equal(commander.sheet, unrolled.sheet, "two commanders share one sheet")
	equal(commander.sheet.score(Ability.CON), 2,
		"a score recorded on one commander reached another")


# --- 4. One point, one score, one level -----------------------------------


func _a_level_up_spends_one_point_on_one_score() -> void:
	var sheet := Character.make("Wren", 3)
	sheet.record_scores({
		Ability.STR: 10, Ability.CON: 9, Ability.CHA: 8,
		Ability.DEX: 7, Ability.WIS: 6, Ability.INT: 5,
	})
	sheet.backstory = "a hedge witch's apprentice"
	sheet.goal = "reach the blossom grove before the petals fall"
	sheet.set_status(11)
	var before := sheet.scores.duplicate()
	var identity_before := sheet.identity_line()

	check(sheet.level_up(Ability.DEX), "the level-up was refused")
	equal(sheet.level, 4, "a level-up did not raise the level by one")
	equal(sheet.score(Ability.DEX), int(before[Ability.DEX]) + 1,
		"a level-up did not add a point to the score it named")
	var moved := PackedStringArray()
	for ability in Ability.ALL:
		if ability != Ability.DEX and sheet.score(ability) != int(before[ability]):
			moved.append(ability)
	equal(moved.size(), 0,
		"a level-up moved a score it was not given: %s" % ", ".join(moved))
	equal(sheet.identity_line(), identity_before, "a level-up rewrote the identity")
	equal(sheet.assigned_status, 11, "a level-up moved an assigned status")

	# A name that is not one of the six spends nothing, level and all: a
	# level-up that quietly lost its point would be worse than none.
	check(not sheet.level_up("luck"), "a level-up on an invented score was allowed")
	equal(sheet.level, 4, "a refused level-up raised the level anyway")
	equal(sheet.scores.size(), 6, "a refused level-up recorded a seventh score")

	# A point on a score nobody rolled records it, which is what makes the gate
	# begin to bite on that score.
	var unrolled := Character.make("Bramble", 1)
	check(unrolled.level_up(Ability.WIS), "the level-up was refused")
	equal(unrolled.score(Ability.WIS), 1, "a point on an unrecorded score is not one")
	equal(unrolled.scores.size(), 1, "a level-up recorded more than one score")


func _one_level_is_read_by_everything() -> void:
	var commander := _suited(3)
	equal(commander.level, commander.sheet.level,
		"the piece and the sheet start at different levels")

	commander.sheet.level_up(Ability.STR)
	equal(commander.sheet.level, 4, "the sheet did not level up")
	equal(commander.level, 4, "the board piece did not see the level-up")
	equal(commander.max_health(), Damage.commander_health(4),
		"health is not read from the sheet's level")
	equal(commander.health, commander.max_health(),
		"the level-up did not carry the health with it")

	# The piece keeps no second copy of the health either: wounding the piece is
	# wounding the sheet.
	commander.wound(5)
	equal(commander.sheet.health, commander.max_health() - 5,
		"the piece's hit points are not the sheet's")
	equal(commander.health, commander.sheet.health,
		"the piece and the sheet hold different hit points")

	# And the level an item is worth is that same level.
	var forged := Armour.worn(Armour.HELMET, commander.level)
	equal(forged.item.level, commander.sheet.level,
		"an item forged at the commander's level is not at the sheet's")
	equal(forged.item.budget(), ItemBudget.total(ItemRarity.COMMON, commander.sheet.level),
		"the power budget is not read against the sheet's level")

	# Setting the level on the piece is setting it on the sheet, both ways round.
	commander.set_level(9)
	equal(commander.sheet.level, 9, "a level set on the piece did not reach the sheet")
	commander.sheet.set_level(2)
	equal(commander.level, 2, "a level set on the sheet did not reach the piece")
	equal(commander.max_health(), Damage.commander_health(2),
		"the piece's health did not follow the sheet's level")

	# A minion keeps its own level: the redirection is the commander's, and it
	# did not follow the level off every piece on the board.
	var minion := Minion.of_kind(Minion.CAT, 1, Vector2i.ZERO, 6)
	equal(minion.level, 6, "a minion's level is no longer its own")
	equal(minion.health, Damage.minion_health(6), "a minion's health moved")


# --- 5. Status ------------------------------------------------------------


func _status_is_separate_from_the_level() -> void:
	# Nobody assigned this one a standing, which is section 2's player case.
	var tracking := Character.make("Wren", 5)
	equal(tracking.status(), tracking.level, "an unassigned status is not the level")
	tracking.level_up(Ability.CHA)
	equal(tracking.level, 6, "the level-up did not land")
	equal(tracking.status(), 6, "an unassigned status stopped tracking the level")

	# And this one the orchestrator gave a standing: a minor noble who has never
	# fought. The two numbers are not one number.
	var assigned := Character.make("Bramble", 5)
	assigned.set_status(12)
	equal(assigned.level, 5, "assigning a status moved the level")
	equal(assigned.status(), 12, "an assigned status is not read back")
	not_equal(assigned.status(), assigned.level,
		"the status and the level are one number")
	assigned.level_up(Ability.STR)
	equal(assigned.level, 6, "the level-up did not land")
	equal(assigned.status(), 12, "a level-up moved an assigned status")

	# Giving the standing up puts it back on the level.
	assigned.clear_status()
	equal(assigned.status(), assigned.level,
		"a cleared status did not go back to tracking the level")

	# The two are the same type, and the difference is one number on the sheet.
	equal(assigned.get_script(), tracking.get_script(),
		"a character with a standing is a different type")


# --- Helpers --------------------------------------------------------------


## A commander at a level, in four common worn items and a common sword, all
## forged at that same level. The loadout the gate table is measured on.
func _suited(at_level: int) -> Commander:
	var commander := Commander.make(
		Vector2i.ZERO, PieceGeometry.NORTH, AssetTags.KNIGHT, at_level
	)
	for slot in Armour.SLOTS:
		commander.equip(Armour.worn(slot, at_level))
	commander.wield(Weapon.held(Weapon.sword(), at_level))
	return commander


## One field of a sheet, as a string that says what it *holds* rather than where
## it is. Two empty inventories are two objects, and `str()` of an object is its
## address, so the inventory is compared by its contents -- which is the question
## being asked: two characters made the same way carry the same nothing.
func _value_of(sheet: Character, field: String) -> String:
	if field == "inventory":
		return sheet.inventory.fingerprint()
	return str(sheet.get(field))


## The script variables of an object, in declaration order.
func _field_names(of: Object) -> PackedStringArray:
	var names := PackedStringArray()
	for property in of.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(str(property["name"]))
	return names


## Every kind-word appearing in the *code* of a source text.
##
## Comments are cut first, so prose that says "player" is not a finding. String
## literals are kept, so a branch comparing against a literal is one.
func _kind_words_in(source: String) -> PackedStringArray:
	var found := PackedStringArray()
	for line in source.split("\n"):
		for hit in _words.search_all(_code_of(line)):
			if KIND_WORDS.has(hit.get_string().to_lower()):
				found.append(hit.get_string())
	return found


## The part of a line that is code: everything before the first `#` that is not
## inside a string. `"%s#%d"` is a format, not a comment.
func _code_of(line: String) -> String:
	var in_string := false
	var index := 0
	while index < line.length():
		var here := line[index]
		if in_string and here == "\\":
			index += 2
			continue
		if here == "\"":
			in_string = not in_string
		elif here == "#" and not in_string:
			return line.substr(0, index)
		index += 1
	return line


func _sim_files() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open("res://sim")
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.get_extension() == "gd":
			found.append("res://sim".path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return found
