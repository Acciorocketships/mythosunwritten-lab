extends SceneTree
## Print everything the composable effect base claims about itself.
##
## Run it with:  ./run_effects.sh
##
## No window, no renderer, no world generation, and nothing drawn at all. Every
## table below is computed from `sim/attack.gd` and `sim/weapon.gd`, and neither
## of them draws a number from anywhere, so two runs of this command print
## identical bytes without a seed having to be written down.


func _initialize() -> void:
	_catalogue_table()
	_composed_table()
	_flight_table()
	_split_table()
	_reach_table()
	quit(0)


# --- The seven, over the base ---------------------------------------------


func _catalogue_table() -> void:
	print("# the catalogue, re-expressed over the base")
	print("weapon       attack")
	for weapon in Weapon.catalogue():
		for attack in weapon.attacks:
			print("%-12s %s" % [weapon.weapon_name, attack.line()])
	print("")


# --- The two it could not hold before -------------------------------------


func _composed_table() -> void:
	print("# two the earlier representation could not hold")
	print("weapon       attack")
	for weapon in Weapon.composed():
		for attack in weapon.attacks:
			print("%-12s %s" % [weapon.weapon_name, attack.line()])
	print("")


# --- What movement buys ---------------------------------------------------


func _flight_table() -> void:
	var from := Vector2i(4, 9)
	var targets: Array[Vector2i] = [
		Vector2i(4, 5), Vector2i(8, 5), Vector2i(8, 7), Vector2i(1, 12),
	]
	print("# what an arrow crosses on its way, from (4,9)")
	print("effect        target    cells crossed")
	var effects: Array[Attack] = [Weapon.arrow(), Weapon.spear().attack_at(0)]
	for named in effects:
		for target in targets:
			var crossed := named.travel_to(from, target)
			var written := PackedStringArray()
			for cell in crossed:
				written.append("(%d,%d)" % [cell.x, cell.y])
			print("%-13s (%2d,%2d)   %s" % [
				named.attack_name, target.x, target.y, " ".join(written),
			])
	print("")


# --- What a split buys ----------------------------------------------------


func _split_table() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, -1)]
	print("# ten damage divided, by how many ways it splits")
	print("split  shares            sum")
	for bolts in range(1, 7):
		var effect := Attack.compose({
			"name": "bolt", "shape": shape, "damage": 10, Attack.SPLIT: bolts,
		})
		var shares := PackedStringArray()
		var total := 0
		for index in effect.strike_count():
			shares.append(str(effect.damage_share(index)))
			total += effect.damage_share(index)
		print("%-6d %-17s %d" % [bolts, " ".join(shares), total])
	print("")


# --- What homing buys -----------------------------------------------------


func _reach_table() -> void:
	var missile := Weapon.magic_missile()
	var from := Vector2i(20, 20)
	print("# how far a bend widens a shape, from (20,20) facing north")
	print("homing  shape cells  reachable cells")
	for reach in range(0, 4):
		var bent := Attack.compose({
			"name": "bolt", "shape": missile.offsets, Attack.HOMING: reach,
		})
		print("%-7d %-12d %d" % [
			reach,
			bent.cells_from(from, PieceGeometry.NORTH).size(),
			bent.reachable_from(from, PieceGeometry.NORTH).size(),
		])
	print("")
