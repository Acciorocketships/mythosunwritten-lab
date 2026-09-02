extends SceneTree
## How near the water the world's villages stand.
##
##   ./tools/measure_shore.sh                      # seed 1234, 2200-unit square
##   ./tools/measure_shore.sh --seed 7 --span 900
##
## This is the enumeration reports/atmosphere.md section 7 cites when it says
## that "every village in a 2200-unit square around the origin was enumerated and
## the nearest water to any of them is 46 units away". It is written down as a
## tool rather than left as a one-off so that the same question can be asked
## again after the siting rule changes, and the two answers compared.
##
## For each village it walks outwards from the pad's rim until it meets water,
## and reports how far that was and whether the water it met is standing (a pond
## or a lake, level with the table) or running (a river, following the ground
## downhill). "Standing" matters because the beat this serves is a *reflection*,
## and a river in a gully three units below its banks does not reflect a house.
##
## Nothing here generates anything: every number comes out of the same fields the
## game builds the world from, so running this changes nothing about any world.

## How far out from a pad's rim the search gives up, in world units.
const SEARCH_REACH := 140.0

## How finely the search steps outwards, and how far apart two probes on the
## same ring may be. Both in world units, so the angular resolution grows with
## the radius instead of thinning out.
const SEARCH_STEP := 0.5
const SEARCH_ARC := 1.0

## The fewest directions any ring is probed in, however small it is.
const MIN_DIRECTIONS := 16


func _initialize() -> void:
	var options := _parse_args()
	var query := TerrainQuery.for_seed(int(options["seed"]))
	var span: float = options["span"]
	var sites := _villages(query, span)

	print("shore survey seed=%d span=%.0f (a %.0f-unit square)" % [
		int(options["seed"]), span, span * 2.0,
	])
	print("%-10s %10s %10s %8s %9s %9s %9s %6s %9s" % [
		"village", "x", "z", "radius", "gap", "away", "kind", "shore", "biome",
	])
	var gaps: Array[float] = []
	var standing := 0
	var touching := 0
	var shore := 0
	for site in sites:
		var found := _nearest_water(query, site)
		var gap: float = found["gap"]
		gaps.append(gap)
		if bool(found["standing"]):
			standing += 1
		if gap <= 0.0:
			touching += 1
		if site.is_shore:
			shore += 1
		print("%-10s %10.2f %10.2f %8.2f %9s %9s %9s %6d %9s" % [
			site.id(), site.centre_x, site.centre_z, site.radius,
			("none" if gap >= SEARCH_REACH else "%.2f" % gap),
			("none" if gap >= SEARCH_REACH else "%.2f" % found["reach"]),
			found["kind"], 1 if site.is_shore else 0, site.biome,
		])
		if site.is_shore:
			print("           shore village: water at (%.2f, %.2f), bearing %.0f deg"
				% [found["at_x"], found["at_z"], found["bearing"]])

	print("")
	print("villages           %d" % sites.size())
	if sites.is_empty():
		quit(0)
		return
	gaps.sort()
	var total := 0.0
	for one in gaps:
		total += one
	print("nearest water, measured from the pad's rim:")
	print("  closest          %.2f" % gaps[0])
	print("  median           %.2f" % gaps[gaps.size() / 2])
	print("  mean             %.2f" % (total / float(gaps.size())))
	print("  furthest         %.2f" % gaps[gaps.size() - 1])
	for band in [0.0, 2.0, 5.0, 10.0, 20.0, 40.0]:
		var within := 0
		for gap in gaps:
			if gap <= band:
				within += 1
		print("  within %5.1f     %d (%.1f%%)" % [
			band, within, 100.0 * float(within) / float(gaps.size()),
		])
	print("sited by the shore rule  %d (%.1f%%)"
		% [shore, 100.0 * float(shore) / float(sites.size())])
	print("water touching the pad   %d (%.1f%%)"
		% [touching, 100.0 * float(touching) / float(sites.size())])
	print("nearest water is standing %d (%.1f%%)"
		% [standing, 100.0 * float(standing) / float(sites.size())])
	quit(0)


## Every village whose cell centre falls in the square, in cell order.
func _villages(query: TerrainQuery, span: float) -> Array[Settlement]:
	var reach := int(ceil(span / SettlementField.SITE_CELL)) + 1
	var found: Array[Settlement] = []
	for cell_x in range(-reach, reach + 1):
		for cell_z in range(-reach, reach + 1):
			var centre := SettlementField.cell_centre(Vector2i(cell_x, cell_z))
			if absf(centre.x) > span or absf(centre.y) > span:
				continue
			var site := query.settlement_field.settlement_in_cell(Vector2i(cell_x, cell_z))
			if site != null:
				found.append(site)
	return found


## How far the nearest water is from a village's pad rim, and what kind it is.
##
## Walked outwards ring by ring from the pad's own rim, stopping at the first
## ring that meets water, so a village standing on a shore costs a handful of
## probes and one in the middle of dry country costs the whole search.
func _nearest_water(query: TerrainQuery, site: Settlement) -> Dictionary:
	var water := query.water_field
	var steps := int(ceil((site.radius + SEARCH_REACH) / SEARCH_STEP))
	for step in range(0, steps + 1):
		var reach := float(step) * SEARCH_STEP
		var directions := maxi(MIN_DIRECTIONS, int(ceil(TAU * reach / SEARCH_ARC)))
		for direction in directions:
			var angle := TAU * float(direction) / float(directions)
			var x := site.centre_x + cos(angle) * reach
			var z := site.centre_z + sin(angle) * reach
			var column := water.sample_column(x, z)
			if column.y <= column.x:
				continue
			var standing := absf(column.y - water.table_level_at(x, z)) < 0.0001
			return {
				"gap": maxf(0.0, reach - site.radius),
				"reach": reach,
				"standing": standing,
				"kind": "standing" if standing else "running",
				"bearing": rad_to_deg(angle),
				"at_x": x,
				"at_z": z,
			}
	return {
		"gap": SEARCH_REACH, "reach": INF, "standing": false, "kind": "none",
		"bearing": 0.0, "at_x": 0.0, "at_z": 0.0,
	}


func _parse_args() -> Dictionary:
	var options := {"seed": 1234, "span": 1100.0}
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var has_value := i + 1 < args.size()
		match args[i]:
			"--seed":
				if has_value and args[i + 1].is_valid_int():
					options["seed"] = args[i + 1].to_int()
			"--span":
				if has_value and args[i + 1].is_valid_float():
					options["span"] = args[i + 1].to_float()
	return options
