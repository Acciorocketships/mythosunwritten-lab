extends SceneTree
## What each shipped attack flies as, measured rather than assumed.
##
##   ./tools/measure_flights.sh
##
## `render/flight_art.gd` maps the simulation's six effect tags to bodies that
## cross the board, and falls back to a visible spark for a tag it has never
## heard of. This prints the whole resolution: the flight table itself, then
## every attack the catalogue and the composed pair ship -- which tag each
## names, whether that tag has a body of its own, and whether the attack would
## ever launch it (only a projectile movement flies) -- and finally the number
## the fallback claim rests on: how many shipped attacks take the spark.


func _initialize() -> void:
	print("the flight table: effect tag -> body")
	for tag in AssetTags.EFFECT_SPRITES:
		var row: Dictionary = FlightArt.body_row(tag)
		var wears := "fallback spark"
		if FlightArt.has_body(tag):
			var model := String(row["model"])
			if model != "":
				wears = model.get_file()
			elif bool(row["glow"]):
				wears = "glow %s" % _colour(row["colour"])
			else:
				wears = "solid %s" % _colour(row["colour"])
		print("  %-8s %s" % [tag, wears])

	print("")
	print("the shipped attacks: weapon / attack -> sprite tag, movement, body")
	var falling := 0
	var counted := 0
	for weapon in Weapon.catalogue() + Weapon.composed():
		for attack in weapon.attacks:
			counted += 1
			var covered: bool = FlightArt.has_body(attack.sprite_tag)
			if not covered:
				falling += 1
			print("  %-12s %-14s sprite=%-7s %-10s %s%s" % [
				weapon.weapon_name, attack.attack_name,
				attack.sprite_tag, attack.movement,
				"body" if covered else "FALLBACK",
				"" if attack.travels() else " (never launched: instant)",
			])
	print("")
	print("%d of %d shipped attacks take the fallback body" % [falling, counted])
	quit(0)


func _colour(colour: Color) -> String:
	return "(%.2f, %.2f, %.2f)" % [colour.r, colour.g, colour.b]
