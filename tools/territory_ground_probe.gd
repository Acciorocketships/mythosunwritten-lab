extends SceneTree
## Print a passability map around the territory run's green, so the rival's post
## can be placed on ground the straight-line walks actually cross. Probe only:
## reads the terrain, writes nothing.
##
## Run it with:
##   ./tools/territory_ground_probe.sh


func _initialize() -> void:
	var terrain := TerrainQuery.for_seed(ScriptedGoodwill.SEED)
	var where := ScriptedGoodwill.WHERE
	print("passability around (%.1f, %.1f), seed %d: '.' passable, '#' not, x right, z down"
		% [where.x, where.y, ScriptedGoodwill.SEED])
	for row in range(-50, 51, 2):
		var line := ""
		for column in range(-50, 51, 2):
			var x := where.x + float(column)
			var z := where.y + float(row)
			if column == 0 and row == 0:
				line += "G"
			elif terrain.is_passable_at(x, z):
				line += "."
			else:
				line += "#"
		print("z%+04d %s" % [row, line])
	quit(0)
