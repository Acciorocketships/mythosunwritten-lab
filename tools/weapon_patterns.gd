extends SceneTree
## Print the weapon catalogue, what dominates what, and the seeded run in which
## the five new shapes are held, swung and landed.
##
##   ./tools/weapon_patterns.sh
##   ./tools/weapon_patterns.sh --ticks 120
##
## Four sections, and every number in them is read off the simulation rather
## than written here:
##
##   1. **The catalogue**, one line per attack: the cells it covers, the turns it
##      waits, its share of its own weapon's effects axis, and the two tags it
##      carries. Twelve weapons now; the last five are the shapes the art packs
##      were already carrying.
##   2. **What reaches each of the five**: the shape word, the weapon it reaches,
##      the name the item is forged under and the catalog name it is drawn as.
##   3. **The domination walk.** One weapon is strictly better than another when
##      every one of the second's attacks is covered by one of the first's on a
##      wait no longer, for a landing worth no less, with a shove no smaller.
##      The pairs that hold are printed; the run is the same arithmetic
##      `tests/test_weapon_patterns.gd` asserts.
##   4. **The seeded fight**: five commanders in a line two cells apart, one new
##      weapon each, and every blow struck -- who struck it, what it found, and
##      which motion the render layer would have drawn it with.
##
## A workbench, not part of the game. Nothing is written and no window is opened.

## How long the fight is watched for, in ticks.
var _ticks := TestWeaponPatterns.TICKS


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--ticks" and index + 1 < args.size():
			_ticks = args[index + 1].to_int()

	_the_catalogue()
	_what_reaches_the_five()
	_the_domination_walk()
	_the_seeded_fight()
	quit()


func _the_catalogue() -> void:
	print("the catalogue, one line per attack:")
	print("  %-11s %-14s %5s %5s %7s  %-11s %-7s %-6s %s" % [
		"weapon", "attack", "cells", "wait", "share", "movement", "sprite",
		"motion", "properties",
	])
	for weapon in Weapon.catalogue():
		var total := ItemBudget.sum(weapon.damage_weights())
		for attack in weapon.attacks:
			var carried := PackedStringArray()
			for named in Attack.PROPERTIES:
				if attack.property(named) > 0:
					carried.append("%s=%d" % [named, attack.property(named)])
			print("  %-11s %-14s %5d %5d %6.2f%%  %-11s %-7s %-6s %s" % [
				weapon.weapon_name, attack.attack_name, attack.cell_count(),
				attack.cooldown,
				0.0 if total <= 0 else 100.0 * float(attack.damage) / float(total),
				attack.movement, attack.sprite_tag, attack.animation_tag,
				" ".join(carried),
			])
	print("")


func _what_reaches_the_five() -> void:
	print("what reaches each of the five, and what it is drawn as:")
	print("  %-11s %-11s %-22s %s" % ["word", "weapon", "forged as", "drawn as"])
	for shape in TestWeaponPatterns.NEW_SHAPES:
		var weapon := Weapon.shaped_like(shape)
		var forged := Weapon.held(weapon, 6)
		print("  %-11s %-11s %-22s %s" % [
			shape, weapon.weapon_name, forged.item.item_name,
			ItemModel.of(forged.item),
		])
	print("")


func _the_domination_walk() -> void:
	var weapons := Weapon.catalogue()
	var pairs := 0
	var holds := PackedStringArray()
	for over in weapons:
		for under in weapons:
			if over.weapon_name == under.weapon_name:
				continue
			pairs += 1
			if _dominates(over, under):
				holds.append("%s over %s" % [over.weapon_name, under.weapon_name])
	holds.sort()
	print("the domination walk: %d ordered pairs of %d weapons" % [pairs, weapons.size()])
	if holds.is_empty():
		print("  nothing is strictly better than anything else")
	for line in holds:
		print("  %s" % line)
	print("")


## The same relation `tests/test_weapon_patterns.gd` states, so the trace a
## person reads and the claim the suite makes are one calculation.
func _dominates(over: Weapon, under: Weapon) -> bool:
	if over.attacks.is_empty() or under.attacks.is_empty():
		return false
	var strict := false
	for beaten in under.attacks:
		var covered := false
		for winner in over.attacks:
			if not _covers(winner, beaten):
				continue
			if winner.cooldown > beaten.cooldown or winner.push < beaten.push:
				continue
			var over_total := ItemBudget.sum(over.damage_weights())
			var under_total := ItemBudget.sum(under.damage_weights())
			var left := 0 if over_total <= 0 else \
				winner.damage * under_total * beaten.strike_count()
			var right := 0 if under_total <= 0 else \
				beaten.damage * over_total * winner.strike_count()
			if left < right:
				continue
			covered = true
			strict = strict or winner.offsets.size() > beaten.offsets.size() \
				or winner.cooldown < beaten.cooldown or winner.push > beaten.push \
				or left > right
			break
		if not covered:
			return false
	return strict


func _covers(winner: Attack, beaten: Attack) -> bool:
	for cell in beaten.offsets:
		if not winner.offsets.has(cell):
			return false
	return true


func _the_seeded_fight() -> void:
	var played := TestWeaponPatterns.play(_ticks)
	var carried: Dictionary = played["weapons"]
	print("the seeded fight: seed %d, %d ticks, began=%s, %d blows" % [
		int(played["seed"]), int(played["ticks"]), str(played["began"]),
		(played["blows"] as Array).size(),
	])
	print("  %-11s %5s %5s %8s %8s %s" % [
		"weapon", "swung", "landed", "cells", "dealt", "motion",
	])
	var swung := {}
	var landed := {}
	var cells := {}
	var dealt := {}
	var motion := {}
	var first := {}
	for blow in played["blows"]:
		var weapon := String(carried.get(int(blow["from"]), "?"))
		swung[weapon] = int(swung.get(weapon, 0)) + 1
		cells[weapon] = (blow["cells"] as Array).size()
		motion[weapon] = String(blow["animation"])
		dealt[weapon] = int(dealt.get(weapon, 0)) + int(blow["dealt"])
		if int(blow["hits"]) > 0:
			landed[weapon] = int(landed.get(weapon, 0)) + 1
		if not first.has(weapon):
			first[weapon] = int(blow["tick"])
	for shape in TestWeaponPatterns.NEW_SHAPES:
		print("  %-11s %5d %5d %8d %8d %s" % [
			shape, int(swung.get(shape, 0)), int(landed.get(shape, 0)),
			int(cells.get(shape, 0)), int(dealt.get(shape, 0)),
			String(motion.get(shape, "-")),
		])

	print("")
	print("  the first blow of each, and the frame the shell would have drawn:")
	for shape in TestWeaponPatterns.NEW_SHAPES:
		var when := int(first.get(shape, -1))
		var clip := "-"
		for frame in played["frames"]:
			if String(frame["weapon"]) == shape and int(frame["tick"]) == when:
				clip = String(frame["clip"])
		print("    %-11s t=%-4d motion %-6s clip %s" % [
			shape, when, String(motion.get(shape, "-")), clip,
		])
