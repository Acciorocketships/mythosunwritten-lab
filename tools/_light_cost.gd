extends SceneTree
func _initialize() -> void:
	var glows := 0
	var lanterns := 0
	var fires := 0
	var buildings := 0
	var villages := 0
	var per_village_max := 0
	for world_seed: int in [1234, 7, 3, 19, 42, 101, 5, 11]:
		var field := TerrainQuery.for_seed(world_seed).settlement_field
		for cx in range(-2, 3):
			for cz in range(-2, 3):
				var site := field.settlement_in_cell(Vector2i(cx, cz))
				if site == null: continue
				villages += 1
				buildings += site.buildings.size()
				glows += site.glows.size()
				var here := site.glows.size()
				for p in site.props:
					if p["tag"] == "lantern_post":
						lanterns += 1; here += 1
					elif p["tag"] == "campfire":
						fires += 1; here += 1
				per_village_max = maxi(per_village_max, here)
	print("villages=%d buildings/village=%.1f glows/village=%.1f lanterns/village=%.1f fires/village=%.1f  lights/village=%.1f  worst=%d" % [
		villages, float(buildings)/villages, float(glows)/villages,
		float(lanterns)/villages, float(fires)/villages,
		float(glows + lanterns + fires)/villages, per_village_max])
	quit()
