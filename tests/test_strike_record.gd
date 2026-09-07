extends TestSuite
## The world's record of a blow: what it carries, that there is one of it, and
## that it reaches whatever draws it through the snapshot.
##
## `sim/action_scene.gd`'s `note_blow` was the one place this world said a blow
## had happened, and it said who hit whom for how much and nothing else. That is
## enough to work out what two people are to each other; it is not enough to draw
## anything. A swing is a motion and needs to know which motion and when it
## began; an arrow is a thing crossing the ground and needs a cell to leave from
## and a cell to arrive at. `sim/attack.gd` already knew all of it -- the sprite
## tag, the animation tag, and whether the effect lands where it is aimed or
## travels -- so nothing had to be invented. The record had to carry it.
##
## Six claims:
##
##   1. **The record carries everything a blow has to say**, on every row of a
##      seeded run: who struck whom, the damage and the health it was out of, the
##      striker's facing, the cells the pattern covered, where it started and
##      where it landed, the two tags, the movement, and the tick it began on.
##   2. **The two ways into a blow write the same record.** A turn taken by hand
##      through `BoardTurn` and a turn taken by a character's own decision
##      function through `ActionEngine` land rows with the same fields, all
##      filled. `./run_strike.sh` prints the two side by side.
##   3. **A render-side consumer reads all of it out of the snapshot**, and out of
##      nothing else: `FightSource.blow_in` is handed a dictionary built here, by
##      hand, with no simulation object anywhere near it, and answers in full.
##   4. **There is one record and not two.** Not a list of the places a blow is
##      published -- a scan of every source file under `sim/` and `render/` for
##      anything that publishes one, and the finding that each shape of
##      publication happens in exactly one file.
##   5. **The tags are names out of `sim/asset_tags.gd`**, copied off the attack
##      rather than made up, so the simulation still names no piece of art.
##   6. **The run is the same run twice**, in one process, which is the half of
##      determinism a suite can check; the shell checks the other half by running
##      two processes.
class_name TestStrikeRecord

## Every field a blow record carries, and what claim 1 requires of each. `true`
## means it must say something on every row -- a name, a number of its own, a
## list with something in it. `false` means the field is required to be *there*
## and is allowed to be zero, because zero is a real answer for it: a swing that
## found nobody dealt nothing to nobody, and north is a facing.
const FIELDS := {
	"from": true, "by": true, "to": false, "tick": true, "round": true,
	"fight": true, "dealt": false, "out_of": false, "hits": false,
	"attack": true, "facing": false, "from_cell": false, "to_cell": false,
	"cells": true, "sprite": true, "animation": true, "movement": true,
	"cooldown": true,
}

## The directories scanned for anything that publishes a blow.
const SCANNED := ["res://sim", "res://render"]

## The shapes a blow gets published in. Each is a substring; a line of code
## carrying one is a line that writes a blow down somewhere.
const APPENDS_TO_THE_WORLD := "blows.append("
const APPENDS_TO_THE_BOARD := "struck.append("
const DEFINES := "func note_blow("
const CALLS := "note_blow("


func _init() -> void:
	suite_name = "strike record"


func run() -> void:
	var run := ScriptedStrike.played()
	_the_record_carries_everything(run)
	_both_hands_write_the_same_record(run)
	_the_render_side_reads_it_out_of_a_dictionary()
	_the_snapshot_carries_it(run)
	_there_is_one_record_and_not_two()
	_the_tags_are_the_attacks_own(run)
	_the_run_is_the_same_twice()


# --- 1. What the record carries -------------------------------------------


func _the_record_carries_everything(run: Dictionary) -> void:
	var blows: Array = run["blows"]
	check(blows.size() >= 2, "the run landed %d blows; it needs at least two"
		% blows.size())
	for blow in blows:
		for field in FIELDS:
			check(blow.has(field), "a blow record has no '%s': %s" % [field, blow])
			if not bool(FIELDS[field]) or not blow.has(field):
				continue
			check(not _is_empty(blow[field]),
				"a blow record's '%s' is empty: %s" % [field, blow])
		# The four the whole milestone turns on, said as themselves rather than
		# as "not empty": a motion, a moment, a shape and a way of travelling.
		check(AssetTags.ANIMATIONS.has(String(blow["animation"])),
			"the animation tag '%s' is not one of the seven"
			% String(blow["animation"]))
		check(int(blow["tick"]) > 0, "a blow began on tick %d" % int(blow["tick"]))
		check((blow["cells"] as Array).size() > 0, "a blow covered no cells")
		check(Attack.MOVEMENTS.has(String(blow["movement"])),
			"'%s' is not a movement" % String(blow["movement"]))
		# The cells are the pattern from where the striker stood, so the striker's
		# own cell is not one of them and the target's is.
		check(not (blow["cells"] as Array).has(blow["from_cell"]),
			"the striker's own cell is among the cells the blow covered")
		check(PieceGeometry.FACINGS.size() > int(blow["facing"])
			and int(blow["facing"]) >= 0,
			"the striker was facing %d, which is not a facing" % int(blow["facing"]))
		if int(blow["to"]) != ActionScene.NOBODY:
			check((blow["cells"] as Array).has(blow["to_cell"]),
				"the blow landed on a cell its pattern did not cover")
			check(int(blow["out_of"]) > 0,
				"a blow landed on somebody with no health to land on")
			check(int(blow["hits"]) >= 1,
				"a blow named a target and landed on nobody")


# --- 2. Two drivers, one record -------------------------------------------


func _both_hands_write_the_same_record(run: Dictionary) -> void:
	var by_hand := _first_from(run, int(run["hand_id"]))
	var by_itself := _first_from(run, int(run["mind_id"]))
	check(not by_hand.is_empty(),
		"the character played by hand struck no blow in the run")
	check(not by_itself.is_empty(),
		"the character playing itself struck no blow in the run")
	if by_hand.is_empty() or by_itself.is_empty():
		return
	var mine := by_hand.keys()
	var theirs := by_itself.keys()
	mine.sort()
	theirs.sort()
	equal(mine, theirs,
		"the two drivers wrote records with different fields on them")
	for field in FIELDS:
		if not bool(FIELDS[field]):
			continue
		check(not _is_empty(by_hand.get(field)),
			"the hand-played blow left '%s' empty" % field)
		check(not _is_empty(by_itself.get(field)),
			"the self-played blow left '%s' empty" % field)
	# And both of them found somebody, so the two rows are filled in the same
	# places and not merely shaped alike.
	for blow in [by_hand, by_itself]:
		check(int(blow["to"]) != ActionScene.NOBODY,
			"a blow named nobody: %s" % blow)
		check(int(blow["out_of"]) > 0, "a blow was out of nothing: %s" % blow)
	check(int(by_hand["from"]) != int(by_itself["from"]),
		"both records name the same striker")


# --- 3. The render side reads a dictionary --------------------------------


## The consumer, handed a dictionary written here.
##
## There is no world in this test, no roster, no fight and no commander: what
## `FightSource.blow_in` is given is the shape of a snapshot, and everything it
## answers with it read out of that. If it ever reached for a simulation object
## again, it could not answer this at all.
func _the_render_side_reads_it_out_of_a_dictionary() -> void:
	var newest := _a_record({
		"attack": "cut", "round": 4, "cooldown": 3, "tick": 118,
		"animation": AssetTags.ANIM_SLASH, "sprite": AssetTags.EFFECT_BLADE,
	})
	var made := {
		"fighting": true,
		"round": 5,
		"tick": 120,
		"fights_begun": 1,
		"blows": [
			# Struck long enough ago that its own wait has run out: not shown.
			_a_record({"attack": "cleave", "round": 1, "cooldown": 3, "tick": 90}),
			newest,
		],
	}
	var read := FightSource.blow_in(made)
	check(not read.is_empty(), "the consumer found no blow in a snapshot with two")
	if read.is_empty():
		return
	equal(String(read["attack"]), "cut",
		"the consumer showed a blow whose wait had already run out")
	equal(int(read["rounds_ago"]), 1, "the rounds since the blow are wrong")
	equal(int(read["ticks_ago"]), 2, "the ticks since the blow are wrong")
	for field in FIELDS:
		equal(read.get(field), newest.get(field),
			"the consumer changed the record's '%s'" % field)
	check(FightSource.blow_in({}).is_empty(),
		"the consumer found a blow in an empty snapshot")
	check(FightSource.blow_in({"fighting": false, "blows": [newest]}).is_empty(),
		"the consumer showed a blow with no fight on")


# --- 3b. And the snapshot really carries them ------------------------------


func _the_snapshot_carries_it(run: Dictionary) -> void:
	var snapshot: Dictionary = run["snapshot"]
	check(snapshot.has("blows"), "the snapshot carries no blows at all")
	var rows: Array = snapshot.get("blows", [])
	check(not rows.is_empty(), "the snapshot carried no blow from a fought fight")
	check(rows.size() <= CombatantRoster.BLOWS_SHOWN,
		"the snapshot carried %d blows, more than the %d it may"
		% [rows.size(), CombatantRoster.BLOWS_SHOWN])
	if rows.is_empty():
		return
	for field in FIELDS:
		check(rows[-1].has(field),
			"the snapshot's blow row has no '%s'" % field)
	# A copy, not the row itself: writing on what left the simulation must not
	# write on what the simulation is holding.
	var blows: Array = run["blows"]
	(rows[-1]["cells"] as Array).clear()
	check(not (blows[-1]["cells"] as Array).is_empty(),
		"the snapshot handed out the world's own array rather than a copy")


# --- 4. One record and not two --------------------------------------------


## Nothing is listed here. Every source file under `sim/` and `render/` is read,
## the lines that publish a blow are found in whatever files have them, and the
## claim is about how many files that turned out to be.
func _there_is_one_record_and_not_two() -> void:
	var into_the_world := _files_matching(APPENDS_TO_THE_WORLD)
	var onto_the_board := _files_matching(APPENDS_TO_THE_BOARD)
	var defines := _files_matching(DEFINES)
	var calls := _files_matching(CALLS)
	equal(into_the_world.size(), 1,
		"%d files write a blow into the world's record: %s"
		% [into_the_world.size(), str(into_the_world)])
	equal(onto_the_board.size(), 1,
		"%d files record a blow on the board: %s"
		% [onto_the_board.size(), str(onto_the_board)])
	equal(defines.size(), 1,
		"%d files define note_blow: %s" % [defines.size(), str(defines)])
	if into_the_world.is_empty() or defines.is_empty():
		return
	# The file that appends is the file that defines it, and the only file that
	# names it -- so there is one door into the record and it is not held open
	# from anywhere else.
	equal(into_the_world[0], defines[0],
		"a blow is appended somewhere other than where note_blow is defined")
	equal(calls, defines,
		"note_blow is named in %s, and defined in %s" % [str(calls), str(defines)])


# --- 5. The tags are the attack's own --------------------------------------


## The weapon is asked, not the striker: a striker that fell has left the world,
## and the claim is about where the tags came from rather than about who is still
## standing. Both of the two carry the same spear, which is what makes the run a
## comparison at all.
func _the_tags_are_the_attacks_own(run: Dictionary) -> void:
	var spear := Weapon.held(Weapon.spear(), ScriptedStrike.LEVEL)
	for blow in run["blows"]:
		var attack := _attack_named(spear, String(blow["attack"]))
		check(attack != null,
			"no attack called '%s' on the striker of a blow" % String(blow["attack"]))
		if attack == null:
			continue
		equal(String(blow["sprite"]), String(attack.sprite_tag),
			"the record's sprite tag is not the attack's")
		equal(String(blow["animation"]), String(attack.animation_tag),
			"the record's animation tag is not the attack's")
		equal(String(blow["movement"]), String(attack.movement),
			"the record's movement is not the attack's")
		check(AssetTags.EFFECT_SPRITES.has(String(blow["sprite"])),
			"the sprite tag '%s' is not one of the six" % String(blow["sprite"]))
	# And the movement is a real field with more than one value in it: a bow's
	# arrow is a projectile, so a record of one says so.
	var bow := Weapon.held(Weapon.bow(), ScriptedStrike.LEVEL)
	var shot := bow.attack_at(0)
	check(shot != null and shot.movement == Attack.PROJECTILE,
		"a bow's first attack does not travel, so the record's movement says nothing")


# --- 6. The same run twice -------------------------------------------------


func _the_run_is_the_same_twice() -> void:
	var once := ScriptedStrike.play()
	var again := ScriptedStrike.play()
	equal(once.size(), again.size(), "two runs of the same seed wrote different lines")
	for at in range(mini(once.size(), again.size())):
		if once[at] != again[at]:
			check(false, "line %d differs between two runs:\n  %s\n  %s"
				% [at, once[at], again[at]])
			return


# --- The furniture --------------------------------------------------------


## One record with every field on it, for the consumer to be handed. Whatever is
## passed in overrides the field of the same name.
func _a_record(changed: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = [Vector2i(3, 4), Vector2i(3, 5)]
	var row := {
		"from": 1, "by": "Alder", "to": 2, "tick": 100, "round": 3, "fight": 1,
		"dealt": 7, "out_of": 38, "hits": 1, "attack": "thrust", "facing": 2,
		"from_cell": Vector2i(3, 3), "to_cell": Vector2i(3, 4), "cells": cells,
		"sprite": AssetTags.EFFECT_POINT, "animation": AssetTags.ANIM_LUNGE,
		"movement": Attack.INSTANT, "cooldown": 1,
	}
	for field in changed:
		row[field] = changed[field]
	return row


func _first_from(run: Dictionary, id: int) -> Dictionary:
	for blow in run["blows"]:
		if int(blow["from"]) == id:
			return blow
	return {}


func _attack_named(weapon: Weapon, called: String) -> Attack:
	for index in weapon.attack_count():
		var attack := weapon.attack_at(index)
		if attack != null and attack.attack_name == called:
			return attack
	return null


## Whether a field says nothing: an empty string, an empty list, or the number
## that means "this blow does not say".
func _is_empty(value: Variant) -> bool:
	if value is String:
		return value == ""
	if value is Array:
		return value.is_empty()
	if value is int:
		return value <= ActionScene.NOBODY
	return value == null


## Every file under the scanned directories whose code -- comments left out --
## carries a shape, in the order they were walked.
func _files_matching(shape: String) -> Array:
	var found := []
	for directory in SCANNED:
		for path in _source_under(directory):
			if _code_of(path).contains(shape):
				found.append(path)
	found.sort()
	return found


## One file's code with its comment lines taken out, so that a file *mentioning*
## a blow record in a comment is not a file publishing one.
func _code_of(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var kept := PackedStringArray()
	for line in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


func _source_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := directory.path_join(entry)
		if dir.current_is_dir() and not entry.begins_with("."):
			found.append_array(_source_under(full))
		elif entry.get_extension() == "gd":
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
