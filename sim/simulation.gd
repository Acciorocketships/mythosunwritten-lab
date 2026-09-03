extends RefCounted
## Drives a SimWorld forward and reports what happened, as text.
##
## It returns report lines rather than printing them: writing to a console is an
## outside-world concern belonging to an entry point, not to the simulation. The
## same object backs both entry points -- the headless one runs it to completion
## in a loop, the render shell steps it once per frame.
class_name Simulation

## How often the trace records a line, in ticks. Every tick would be exact but
## noisy; the first and last tick are always recorded regardless.
const TRACE_EVERY := 10

## What `snap_report()` calls a place a fight can be held on, and it is three
## thresholds rather than a judgement: at least this share of the board standable,
## at most this much height between its highest and lowest standable cell, and at
## most this many things grown in the chunk it sits in.
const OPEN_ENOUGH := 0.90
const FLAT_ENOUGH := 6.0
const UNCLUTTERED := 40

## The scenarios an entry point may ask for by name.
##
## A name rather than a call into the scenario file, because both entry points
## want the same fight and one of them is the render shell -- which must not name
## the combat layer at all. Asking the simulation for "the encounter" keeps the
## whole vocabulary of pieces, matches and rosters on this side of the line; see
## `LayerCheck.FORBIDDEN_IN_RENDER`.
const SCENARIO_NONE := ""
const SCENARIO_ENCOUNTER := "encounter"
const SCENARIO_ENCOUNTER_ISLAND := "encounter-island"
const SCENARIO_MARKET := "market"
const SCENARIO_QUARREL := "quarrel"

## Every scenario there is, in a fixed order, for a report line and a usage
## message.
const SCENARIOS := [
	SCENARIO_ENCOUNTER, SCENARIO_ENCOUNTER_ISLAND,
	SCENARIO_MARKET, SCENARIO_QUARREL,
]

var world: SimWorld = null

## Where the choices of whoever is driving go, or null in a run nobody is
## driving -- which is every headless run and every run of the shell that did
## not ask to play. See `hand_over_followed()`.
var driven: LiveChoice = null

## Which character those choices are for, or 0.
var driven_id: int = 0


func _init(seed_value: int = 0) -> void:
	world = SimWorld.new(seed_value)


## Hand the character the world is looking through over to a person.
##
## The one call an entry point makes to turn a world being watched into a world
## being played. It replaces that character's decision function and nothing else
## -- see `WorldCast.hand_over` -- so what changes is who is answering, not what
## the answer may be, who else is in the world, or what the engine does with any
## of it.
##
## Returns whether there was somebody to hand over. There is not when the world
## is looking through nobody, which is what `SimWorld.place_observer` leaves and
## what a scenario wanting a fixed camera asks for.
func hand_over_followed() -> bool:
	driven = WorldCast.hand_over(world, world.follow_id)
	driven_id = world.follow_id if driven != null else 0
	return driven != null


## What the person driving has chosen and not yet had carried out, in one line,
## for a trace or a readout. "nobody is driving" in a run with no person in it.
func driven_line() -> String:
	return "nobody is driving" if driven == null else driven.line()


## What the engine last answered the character being driven, or an empty
## dictionary. The loop's own record, forwarded, so an entry point has one place
## to ask; every string in it is the engine's own wording. See
## `ControlLoop.answer_of`.
func driven_answer() -> Dictionary:
	if driven_id == 0 or world.loop == null:
		return {}
	return world.loop.answer_of(driven_id)


## Set a named scenario out in the world. Returns whether it was recognised and
## could be set out.
##
## An unknown name changes nothing, and so does a scenario the world cannot hold
## -- a seed with no walkable floating island anywhere near the origin has
## nowhere for the aerial fight to happen, and saying so is the answer rather
## than putting it on the ground instead.
## `frozen` asks for the old behaviour of the two character scenarios: the run is
## played out headless to a stated tick and the cast is stood where that run left
## it, which is a photograph and not a game. It is off by default, because a
## scenario is a thing that happens: set out live, the same five characters are
## driven by the world's own control loop from the tick they are set out on, and
## the greeting, the trade and the quarrel happen in front of the camera.
##
## The two encounter scenarios were always live and take no notice of it.
func begin_scenario(named: String, frozen: bool = false) -> bool:
	match named:
		SCENARIO_NONE:
			return true
		SCENARIO_ENCOUNTER:
			ScriptedEncounter.muster(world)
			return true
		SCENARIO_ENCOUNTER_ISLAND:
			return ScriptedEncounter.muster_on_island(world) != null
		SCENARIO_MARKET:
			if frozen:
				# Played headless to the tick the trade is done on, and
				# everybody stood where that run left them.
				return ScriptedScenario.muster(
					world, ScriptedScenario.MARKET_FRAME,
					ScriptedScenario.watch_market()) > 0
			# Set out where it starts and lived forward, with the camera on the
			# one who does the trading.
			return ScriptedScenario.muster_live(
				world, ScriptedScenario.WREN) > 0
		SCENARIO_QUARREL:
			if frozen:
				# The same run, photographed at a tick while the quarrel is on
				# the board.
				return ScriptedScenario.muster(
					world, ScriptedScenario.QUARREL_FRAME,
					ScriptedScenario.watch_quarrel()) > 0
			# The same cast again, with the camera on one of the two who
			# quarrel: live, the quarrel is something you watch happen.
			return ScriptedScenario.muster_live(
				world, ScriptedScenario.BRAM) > 0
	return false


## Advance one tick. The render shell calls this; so does run().
func step() -> void:
	world.step()


## Run for a fixed number of ticks and return the report, one line per entry.
##
## The report is the headless run's entire output, and is what the determinism
## test compares between runs: same seed must give the same lines, a different
## seed must not.
func run(ticks: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("seed %d" % world.world_seed)
	lines.append_array(cast_report())
	lines.append(_trace_line())
	# Everything the world's cast did, as the control loop wrote it down, put
	# into the report at the tick it happened on. This is the run saying who
	# chose what and what the engine answered, rather than only where the ground
	# got to.
	var said := world.loop.journal.size()
	for i in ticks:
		step()
		for at in range(said, world.loop.journal.size()):
			lines.append("  " + world.loop.journal[at])
		said = world.loop.journal.size()
		var is_last := i == ticks - 1
		if is_last or world.tick % TRACE_EVERY == 0:
			lines.append(_trace_line())
	lines.append("done ticks=%d chunks=%d built=%d final=%s" % [
		world.tick,
		world.terrain_streamer.loaded_count(),
		world.terrain_streamer.chunks_built,
		world.digest(),
	])
	return lines


## Who is in the world, one line each, and which of them the world is looking
## through.
##
## Being followed is the whole of what the followed character gets: it is asked
## the same question on the same tick as the rest, through the same loop, and its
## answer goes to the same engine. The line says so where a reader can check it.
func cast_report() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("cast %d following #%d" % [world.combat.size(), world.follow_id])
	for one in world.combat.members:
		lines.append("  %-7s %s%s" % [
			ActionScene.name_of(one), one.line(),
			"  <- followed" if one.id == world.follow_id else "",
		])
	return lines


## One line per loaded chunk: its coordinate and the fingerprint of the geometry
## the mesher produced for it, in sorted coordinate order.
##
## This is how a run can be compared with another run chunk by chunk rather than
## only world by world, which is what the mesher's determinism is really about.
func chunk_report() -> PackedStringArray:
	var lines := PackedStringArray()
	for key in world.terrain_streamer.loaded_keys():
		lines.append("chunk %d %d %s" % [
			key.x, key.y, world.terrain_streamer.live_geometry(key).digest(),
		])
	return lines


## One line per position on a fixed lattice around the world origin: whether it
## is water, whether it is a bank, and how deep the water is there.
##
## The lattice is fixed rather than read off the streamer or off the water sheet,
## so this answers for the water field itself rather than for whichever water
## happens to be built -- which is what lets two separate processes be compared
## position by position, and what shows that being water is a property of the
## position rather than of when anything was built.
func water_report(span: int = 30, spacing: float = 3.0) -> PackedStringArray:
	var lines := PackedStringArray()
	var wet := 0
	var banks := 0
	for row in range(-span, span + 1):
		for column in range(-span, span + 1):
			var x := float(column) * spacing
			var z := float(row) * spacing
			var ground := world.terrain.ground_at(x, z)
			var is_water: bool = ground["water"]
			var is_bank: bool = ground["bank"]
			if is_water:
				wet += 1
			if is_bank:
				banks += 1
			lines.append("water %.1f %.1f %d %d %.4f %.4f" % [
				x, z,
				1 if is_water else 0,
				1 if is_bank else 0,
				float(ground["water_depth"]),
				float(ground["height"]),
			])
	var total := lines.size()
	lines.append("water-summary points=%d wet=%d banks=%d wet_fraction=%.4f" % [
		total, wet, banks, float(wet) / float(maxi(1, total)),
	])
	return lines


## One line per floating island whose centre falls inside a fixed square around
## the world origin, in cell order, with the fingerprint of its placement.
##
## Like the biome and water reports, the region is fixed rather than read off the
## streamer, so this answers for the island field itself rather than for whichever
## islands happen to be built. That is what lets two separate processes be
## compared island by island, and what shows that where an island is depends on
## its cell and the seed and on nothing about when anything was loaded.
##
## The summary line carries the density, which is the number the report's
## reasoning about "sparse" is checked against.
func island_report(span: float = 600.0) -> PackedStringArray:
	var lines := PackedStringArray()
	var counts := {}
	var steps: Array[float] = []
	var clearances: Array[float] = []
	var floats: Array[float] = []
	for band in [
		FloatingIsland.AERIAL, FloatingIsland.AERIAL_UPPER, FloatingIsland.FAR_SKY,
	]:
		counts[band] = 0
		var size := IslandField.cell_size(band)
		var reach := int(ceil(span / size))
		for cell_x in range(-reach, reach + 1):
			for cell_z in range(-reach, reach + 1):
				var island := world.island_field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island == null:
					continue
				if absf(island.centre_x) > span or absf(island.centre_z) > span:
					continue
				counts[band] = int(counts[band]) + 1
				var measured := _island_footprint(island)
				if island.walkable:
					steps.append(island.landing_step)
					clearances.append(float(measured["clearance"]))
					floats.append(float(measured["float"]))
				lines.append(
					"island %d %d %d %.3f %.3f %.3f %.3f %.3f %.3f %d %s %.3f %.3f %s" % [
						band, cell_x, cell_z,
						island.centre_x, island.centre_z, island.radius,
						island.rim_height, island.landing_step, island.keel_depth,
						1 if island.walkable else 0,
						island.biome,
						float(measured["clearance"]), float(measured["float"]),
						island.digest(),
					]
				)
	lines.append_array(_island_cover_report(span))
	# Islands per million square units of world.
	var area := (2.0 * span) * (2.0 * span) / 1000000.0
	lines.append(
		"island-summary span=%.0f lower=%d upper=%d far=%d per_million=%.2f/%.2f/%.2f" % [
			span,
			int(counts[FloatingIsland.AERIAL]),
			int(counts[FloatingIsland.AERIAL_UPPER]),
			int(counts[FloatingIsland.FAR_SKY]),
			float(counts[FloatingIsland.AERIAL]) / area,
			float(counts[FloatingIsland.AERIAL_UPPER]) / area,
			float(counts[FloatingIsland.FAR_SKY]) / area,
		]
	)
	lines.append("island-walkable %s %s %s" % [
		_spread("step", steps), _spread("clearance", clearances), _spread("float", floats),
	])
	return lines


## What the walkable islands in the same square are dressed with, and which of
## them hold water.
##
## Separate lines rather than more fields on the island line, because this is a
## different claim: the island line answers for where an island is, and these
## answer for what is on it. Both are pure functions of the cell and the seed,
## so two processes produce these byte for byte alike as well.
func _island_cover_report(span: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cover := IslandCover.new(world.world_seed)
	var mesher := IslandMesher.new()
	var counts := {}
	var placed := 0
	var islands := 0
	var basins := 0
	var spills := 0
	for band in FloatingIsland.WALKABLE_BANDS:
		var size := IslandField.cell_size(band)
		var reach := int(ceil(span / size))
		for cell_x in range(-reach, reach + 1):
			for cell_z in range(-reach, reach + 1):
				var island := world.island_field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island == null:
					continue
				if absf(island.centre_x) > span or absf(island.centre_z) > span:
					continue
				islands += 1
				var patch := cover.build(island)
				placed += patch.count()
				for item in patch.items:
					var tag := String(item["tag"])
					counts[tag] = int(counts.get(tag, 0)) + 1
				var pond := mesher.build_water(island)
				if island.has_basin():
					basins += 1
				if island.has_spill():
					spills += 1
				lines.append(
					"island-cover %d %d %d %d %d %.3f %.3f %.3f %d %.3f %.3f %.3f %d %s" % [
						band, cell_x, cell_z, patch.count(),
						1 if island.has_basin() else 0,
						island.basin_ratio, island.basin_depth, island.water_level,
						1 if island.has_spill() else 0,
						island.spill_x, island.spill_z, island.spill_fall,
						pond.triangle_count(), patch.digest(),
					]
				)
	lines.append(
		"island-cover-summary islands=%d placed=%d per_island=%.1f basins=%d spills=%d" % [
			islands, placed,
			float(placed) / float(maxi(1, islands)), basins, spills,
		]
	)
	var tags := counts.keys()
	tags.sort()
	for tag in tags:
		lines.append("island-cover-tag %s %d" % [tag, int(counts[tag])])
	return lines


## An island measured against the ground under it, on a grid the placement rule
## never sampled: how close its underside comes to what is below (`clearance`,
## which the placement rule keeps positive) and how far its top surface stands
## above the ground (`float`, averaged over the footprint).
func _island_footprint(island: FloatingIsland, steps: int = 12) -> Dictionary:
	var clearance := INF
	var above := 0.0
	var samples := 0
	for grid_x in range(-steps, steps + 1):
		for grid_z in range(-steps, steps + 1):
			var x := island.centre_x + float(grid_x) / float(steps) * island.max_reach()
			var z := island.centre_z + float(grid_z) / float(steps) * island.max_reach()
			if not island.covers(x, z):
				continue
			var under := world.terrain.ground_height_at(x, z)
			clearance = minf(clearance, island.bottom_height_at(x, z) - under)
			above += island.top_height_at(x, z) - under
			samples += 1
	if samples == 0:
		return {"clearance": 0.0, "float": 0.0}
	return {"clearance": clearance, "float": above / float(samples)}


## The spread of a set of measurements, as one field of the summary line.
func _spread(label: String, values: Array[float]) -> String:
	if values.is_empty():
		return "%s=none" % label
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	return "%s(min/median/max/mean)=%.2f/%.2f/%.2f/%.2f" % [
		label, values[0], values[values.size() / 2],
		values[values.size() - 1], total / float(values.size()),
	]


## One line per village whose middle falls inside a fixed square around the
## world origin, in cell order, with the fingerprint of its layout; then one line
## per road out of those villages; then a summary.
##
## Like the biome, water and island reports, the region is fixed rather than read
## off the streamer, so this answers for the settlement field itself rather than
## for whichever villages happen to be loaded. That is what lets two separate
## processes be compared village by village, and what shows that where a village
## is depends on its cell and the seed and on nothing about when anything was
## built.
##
## The summary carries the density and the biome split, which are the numbers the
## placement rule in reports/settlements.md is checked against.
func settlement_report(span: float = 900.0) -> PackedStringArray:
	var lines := PackedStringArray()
	var reach := int(ceil(span / SettlementField.SITE_CELL)) + 1
	var by_biome := {}
	var sites := 0
	var buildings := 0
	var wanted := 0
	var roads := 0
	var bridges := 0
	var landmarks := 0
	for cell_x in range(-reach, reach + 1):
		for cell_z in range(-reach, reach + 1):
			var cell := Vector2i(cell_x, cell_z)
			var centre_x := (float(cell_x) + 0.5) * SettlementField.SITE_CELL
			var centre_z := (float(cell_z) + 0.5) * SettlementField.SITE_CELL
			if absf(centre_x) > span or absf(centre_z) > span:
				continue
			wanted += 1
			var site := world.settlement_field.settlement_in_cell(cell)
			if site == null:
				continue
			sites += 1
			buildings += site.buildings.size()
			by_biome[site.biome] = int(by_biome.get(site.biome, 0)) + 1
			lines.append("settlement %d %d %.3f %.3f %.3f %.3f %s %d %d %d %s" % [
				cell_x, cell_z, site.centre_x, site.centre_z,
				site.radius, site.pad_height, site.biome,
				site.buildings.size(), site.props.size(),
				1 if site.is_spawn else 0, site.digest(),
			])
			# Every road touching this village. A road belongs to whichever of
			# its ends sorts first, which is often the landmark rather than the
			# village, so they are gathered by proximity rather than by owner.
			for road in world.path_network.edges_near(
				site.centre_x, site.centre_z, site.radius + 30.0
			):
				if road["from_id"] != site.id() and road["to_id"] != site.id():
					continue
				roads += 1
				bridges += (road["bridges"] as Array).size()
				lines.append("road %s %s %.2f %d %d %s" % [
					road["from_id"], road["to_id"], road["length"],
					(road["bridges"] as Array).size(), (road["props"] as Array).size(),
					SettlementStreamer.road_digest(road),
				])
				for bridge in road["bridges"]:
					lines.append("bridge %s %.3f %.3f %.3f %.3f %.3f" % [
						bridge["tag"], bridge["x"], bridge["z"],
						bridge["yaw"], bridge["span"], bridge["height"],
					])
	var mark_reach := int(ceil(span / SettlementField.LANDMARK_CELL))
	for cell_x in range(-mark_reach, mark_reach + 1):
		for cell_z in range(-mark_reach, mark_reach + 1):
			if not world.settlement_field.landmark_in_cell(Vector2i(cell_x, cell_z)).is_empty():
				landmarks += 1
	var splits := PackedStringArray()
	for id in BiomeCatalog.IDS:
		splits.append("%s=%d" % [id, int(by_biome.get(id, 0))])
	# Villages per million square units of world, which is the density the
	# placement rule is stated in.
	var area := (2.0 * span) * (2.0 * span) / 1000000.0
	lines.append(
		"settlement-summary span=%.0f cells=%d sites=%d per_million=%.2f "
		% [span, wanted, sites, float(sites) / area]
		+ "buildings=%d landmarks=%d roads=%d bridges=%d %s" % [
			buildings, landmarks, roads, bridges, " ".join(splits),
		]
	)
	return lines


## One line per thing the scatter layer puts down inside a fixed square of
## chunks around the world origin, in chunk order then placement order; then a
## survey of a much wider region, biome by biome.
##
## Like the biome, water, island and settlement reports, the region is fixed
## rather than read off the streamer, so this answers for the scatter layer
## itself rather than for whichever dressing happens to be loaded. That is what
## lets two separate processes be compared thing by thing, and what shows that
## what grows in a cell depends on the cell and the seed and on nothing about
## when anything was built.
##
## The square is small and contiguous, because that is what a thing-by-thing
## comparison needs. The survey is the opposite: chunks spread thinly over a
## wide region, so that every biome is met somewhere and the numbers
## reports/scatter.md quotes -- how thickly each biome grows, and how tall its
## trees and how big its stone come out -- are measured over real ground rather
## than over whatever happens to surround the origin.
func scatter_report(
	reach: int = 4, survey_reach: int = 36, survey_step: int = 6
) -> PackedStringArray:
	var lines := PackedStringArray()
	var counts := {}
	var placed := 0
	for chunk_x in range(-reach, reach + 1):
		for chunk_z in range(-reach, reach + 1):
			var patch := world.scatter_field.build(chunk_x, chunk_z)
			lines.append("patch %d %d %d %s" % [
				chunk_x, chunk_z, patch.count(), patch.digest(),
			])
			for item in patch.items:
				placed += 1
				var tag := String(item["tag"])
				counts[tag] = int(counts.get(tag, 0)) + 1
				lines.append("scatter %s %.3f %.3f %.3f %.4f %.3f %s %s" % [
					tag, item["x"], item["z"], item["y"], item["yaw"],
					item["size"], item["kind"], item["context"],
				])
	var chunks := (2 * reach + 1) * (2 * reach + 1)
	var area := float(chunks) * TerrainChunkMesher.CHUNK_SIZE * TerrainChunkMesher.CHUNK_SIZE
	lines.append("scatter-summary chunks=%d placed=%d per_chunk=%.2f per_1000=%.2f" % [
		chunks, placed, float(placed) / float(chunks), 1000.0 * float(placed) / area,
	])
	var tags := counts.keys()
	tags.sort()
	for tag in tags:
		lines.append("scatter-tag %s %d" % [tag, int(counts[tag])])
	lines.append_array(_scatter_survey(survey_reach, survey_step))
	return lines


## The wide survey: what each biome actually grew, over chunks spread across
## roughly fifteen hundred units of world.
func _scatter_survey(reach: int, step: int) -> PackedStringArray:
	var chunks := {}
	var placed := {}
	var kinds := {}
	var trees := {}
	var stones := {}
	var props := {}
	for id in BiomeCatalog.IDS:
		chunks[id] = 0
		placed[id] = 0
		trees[id] = [] as Array[float]
		stones[id] = [] as Array[float]
		for kind in ScatterCatalog.KINDS:
			kinds["%s/%s" % [id, kind]] = 0
	for chunk_x in range(-reach, reach + 1, step):
		for chunk_z in range(-reach, reach + 1, step):
			var middle_x := (float(chunk_x) + 0.5) * TerrainChunkMesher.CHUNK_SIZE
			var middle_z := (float(chunk_z) + 0.5) * TerrainChunkMesher.CHUNK_SIZE
			var biome := world.terrain.biome_at(middle_x, middle_z)
			chunks[biome] = int(chunks[biome]) + 1
			for item in world.scatter_field.build(chunk_x, chunk_z).items:
				placed[biome] = int(placed[biome]) + 1
				var kind := String(item["kind"])
				var key := "%s/%s" % [biome, kind]
				kinds[key] = int(kinds[key]) + 1
				if kind == ScatterCatalog.KIND_TREE:
					(trees[biome] as Array[float]).append(float(item["size"]))
				elif kind == ScatterCatalog.KIND_ROCK:
					(stones[biome] as Array[float]).append(float(item["size"]))
				var tag := String(item["tag"])
				props[tag] = int(props.get(tag, 0)) + 1

	var lines := PackedStringArray()
	for id in BiomeCatalog.IDS:
		var seen := int(chunks[id])
		var parts := PackedStringArray()
		for kind in ScatterCatalog.KINDS:
			parts.append("%s=%d" % [kind, int(kinds["%s/%s" % [id, kind]])])
		lines.append("scatter-survey %s chunks=%d placed=%d per_chunk=%.2f %s" % [
			id, seen, int(placed[id]),
			float(placed[id]) / float(maxi(1, seen)), " ".join(parts),
		])
		lines.append("scatter-survey-size %s %s %s" % [
			id, _spread("tree", trees[id]), _spread("rock", stones[id]),
		])
	var surveyed := 0
	for id in BiomeCatalog.IDS:
		surveyed += int(chunks[id])
	var tags := props.keys()
	tags.sort()
	var named := PackedStringArray()
	for tag in tags:
		named.append("%s=%d" % [tag, int(props[tag])])
	lines.append("scatter-survey-summary chunks=%d step=%d %s" % [
		surveyed, step, " ".join(named),
	])
	return lines


## One line per position on a fixed lattice around the world origin: which biome
## it resolves to, that biome's share of the position, and the fingerprint of the
## blended profile there.
##
## The lattice is fixed rather than read off the streamer, so this answers for
## the biome map itself rather than for whichever ground happens to be built --
## which is what lets two separate processes be compared position by position.
func biome_report(span: int = 10, spacing: float = 24.0) -> PackedStringArray:
	var lines := PackedStringArray()
	for row in range(-span, span + 1):
		for column in range(-span, span + 1):
			var x := float(column) * spacing
			var z := float(row) * spacing
			var weights := world.biome_field.weights_at(x, z)
			var id := world.biome_field.biome_at(x, z)
			lines.append("biome %.1f %.1f %s %.6f %s" % [
				x, z, id, float(weights[id]), world.biome_field.profile_at(x, z).digest(),
			])
	return lines


## One traced line: where the world is, how much ground and how many islands are
## currently built, and how much of the water sheet around it is wet.
func _trace_line() -> String:
	var sheet := world.live_water_sheet()
	return ("tick %d chunks=%d islands=%d villages=%d roads=%d props=%d cover=%d "
		+ "cast=%d biome=%s water=%d on_island=%d on_path=%.2f %s") % [
		world.tick,
		world.terrain_streamer.loaded_count(),
		world.island_streamer.loaded_count(),
		world.settlement_streamer.loaded_count(),
		world.settlement_streamer.road_count(),
		world.scatter_streamer.item_count(),
		world.island_streamer.cover_count(),
		world.combat.size(),
		world.observer_biome(),
		sheet.wet_cells if sheet != null else 0,
		1 if world.observer_on_island() else 0,
		world.observer_on_path(),
		world.digest(),
	]


## The board over a fixed set of rectangles of the world, cell by cell, then one
## board read on a floating island's top.
##
## Like the biome, water, island and settlement reports, the rectangles are fixed
## rather than read off the observer, so this answers for the lattice itself
## rather than for whichever ground happens to be underfoot. That is what lets
## two separate processes be compared cell by cell, and what shows that what a
## cell says depends on the cell and the seed and on nothing about when anything
## was built or which board was built before it.
##
## The rectangles overlap deliberately: they are spaced closer together than they
## are wide, so every board shares a band of cells with its neighbours and the
## claim that two boards agree on the ground they share is checked by the report
## rather than only by the suite.
func board_report(
	span: float = CombatBoardBuilder.DEFAULT_SPAN,
	spacing: float = 40.0,
	reach: int = 2,
) -> PackedStringArray:
	var lines := PackedStringArray()
	for row in range(-reach, reach + 1):
		for column in range(-reach, reach + 1):
			var x := float(column) * spacing
			var z := float(row) * spacing
			lines.append_array(_board_lines(
				"board", world.combat_board_builder.build_on_top(x, z, span)
			))
	var aerial := _first_walkable_island()
	if aerial != null:
		lines.append_array(_board_lines("board-aerial", world.combat_board_builder.build(
			aerial.centre_x, aerial.centre_z,
			aerial.top_height_at(aerial.centre_x, aerial.centre_z), span,
		)))
	return lines


## One board written out: a header, one line per cell in row order, and a tally.
func _board_lines(label: String, board: CombatBoard) -> PackedStringArray:
	var lines := PackedStringArray()
	var edges: Array = board.extent()
	lines.append("%s-at %d %d %d %d %.1f %.1f %.1f %.1f %d %s %d %s" % [
		label, board.min_cell.x, board.min_cell.y,
		board.cells_across, board.cells_deep,
		float(edges[0]), float(edges[1]), float(edges[2]), float(edges[3]),
		board.anchor_storey, CombatBoard.number_text(board.anchor_height),
		board.cell_count(), board.digest(),
	])
	for row in board.cells_deep:
		for column in board.cells_across:
			lines.append("%s %s" % [
				label, board.cell_line(board.min_cell + Vector2i(column, row)),
			])
	lines.append("%s-tally %d %d %d %d %d %d" % [
		label, board.cell_count(), board.standable_count(), board.hole_count(),
		board.blocking_count(), board.cliff_edge_count(), board.aerial_count(),
	])
	return lines


## The first walkable island in a fixed square around the origin, in cell order,
## or null. What the aerial board is read on, chosen by the world rather than by
## a coordinate anyone typed, so the report keeps answering when the seed changes.
func _first_walkable_island(span: float = 400.0) -> FloatingIsland:
	return world.island_field.first_walkable_island(span)


## Where a fight can be *held*, measured over a grid of candidate places.
##
## The board layer answers whether a cell can be stood on. This answers the
## question a scenario actually has to make: which stretches of the world make a
## legible fight. Three numbers per candidate, and every one of them is measured
## rather than judged:
##
##   * `stand`  -- the share of the board's cells a piece may stand on. A fight
##     on ground that is mostly hole is a fight on a few islands of cells.
##   * `relief` -- the spread between the highest and lowest standable cell, in
##     world units. Flat ground makes a legible board; a hillside does not.
##   * `flora`  -- how many things the scatter layer grew in the chunk the
##     candidate falls in. The board does not carry a tree, so a fight in a
##     canopy is legal and unwatchable: this is the openness of the place, and it
##     is the one number here that is about the *picture*.
##
## The summary line names the candidates that pass all three stated thresholds,
## which is where sim/scripted_encounter.gd's meeting place comes from. The grid
## is fixed rather than read off the observer, so two processes compare candidate
## by candidate.
func snap_report(
	span: float = 480.0,
	spacing: float = 60.0,
	board_span: float = CombatBoardBuilder.DEFAULT_SPAN,
) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("snap-thresholds stand>=%.2f relief<=%.1f flora<=%d" % [
		OPEN_ENOUGH, FLAT_ENOUGH, UNCLUTTERED,
	])
	var reach := int(span / spacing)
	var passing := PackedStringArray()
	for row in range(-reach, reach + 1):
		for column in range(-reach, reach + 1):
			var x := float(column) * spacing
			var z := float(row) * spacing
			var board := world.combat_board_builder.build_on_top(x, z, board_span)
			var low := INF
			var high := -INF
			for cell_row in board.cells_deep:
				for cell_column in board.cells_across:
					var cell := board.min_cell + Vector2i(cell_column, cell_row)
					if not board.is_standable(cell):
						continue
					var height := board.height_at(cell)
					low = minf(low, height)
					high = maxf(high, height)
			var relief := 0.0 if low == INF else high - low
			var stand := float(board.standable_count()) / float(maxi(1, board.cell_count()))
			var chunk_size := TerrainChunkMesher.CHUNK_SIZE
			var flora := world.scatter_field.build(
				int(floorf(x / chunk_size)), int(floorf(z / chunk_size))
			).count()
			var ok := stand >= OPEN_ENOUGH and relief <= FLAT_ENOUGH and flora <= UNCLUTTERED
			var line := ("snap %.0f %.0f %s stand=%.3f relief=%.2f flora=%d "
				+ "holes=%d cliffs=%d built=%d %s") % [
				x, z, world.terrain.biome_at(x, z), stand, relief, flora,
				board.hole_count(), board.cliff_edge_count(), board.blocking_count(),
				"ok" if ok else "--",
			]
			lines.append(line)
			if ok:
				passing.append("(%.0f, %.0f)" % [x, z])
	lines.append("snap-summary candidates=%d passing=%d %s" % [
		lines.size() - 1, passing.size(), " ".join(passing.slice(0, 12)),
	])
	return lines


## What each candidate cell size costs, measured against the ground itself.## What each candidate cell size costs, measured against the ground itself.
##
## The question the sweep answers is the one the cell size has to be argued from:
## a coarser lattice is more legible and holds a fight in fewer cells, and it
## loses the obstacles that fall between its cells. Both halves are measured
## here, and against the same truth for every candidate -- a fine grid of
## positions sampled once per region at `truth_step` world units, well under the
## terrain-generation lattice, so no candidate is compared against a truth of its
## own resolution.
##
## Per candidate size it reports, over every region:
##
##   * `across`   -- how many cells a board of the default span spans.
##   * `mixed`    -- the share of cells whose ground is not all of one kind: a
##     shoreline, a building's wall or the lip of a cliff runs through them.
##   * `lost`     -- the share of impassable ground the board calls standable.
##     This is the cost: an obstacle the terrain placed that falls between the
##     cell centres and is not on the board at all.
##   * `phantom`  -- the share of standable ground the board calls a hole, the
##     same error the other way round.
##   * `cliff`    -- the share of standable cells flagged as a cliff edge, which
##     is how the flag stops meaning anything as the baseline between cell
##     centres grows: at a coarse enough size an ordinary hillside is a cliff.
func board_sweep_report(
	sizes: Array = [2.0, 2.5, 3.0, 4.0, 5.0, 6.0],
	spacing: float = 130.0,
	reach: int = 4,
	span: float = CombatBoardBuilder.DEFAULT_SPAN,
	truth_step: float = 0.5,
) -> PackedStringArray:
	var lines := PackedStringArray()
	var regions: Array[Vector2] = []
	for row in range(-reach, reach + 1):
		for column in range(-reach, reach + 1):
			regions.append(Vector2(float(column) * spacing, float(row) * spacing))

	# The truth, once per region and shared by every candidate: whether ordinary
	# movement can cross each of a fine grid of positions. It is the terrain
	# query's own answer, the same one the board reads, so the only difference
	# being measured is where the samples fall.
	var truth := {}
	var truth_side := int(round(2.0 * span / truth_step)) + 1
	for region in regions:
		var passable := PackedInt32Array()
		passable.resize(truth_side * truth_side)
		for row in truth_side:
			for column in truth_side:
				var x := region.x - span + float(column) * truth_step
				var z := region.y - span + float(row) * truth_step
				passable[row * truth_side + column] = \
					1 if world.terrain.is_passable_at(x, z) else 0
		truth[region] = passable

	# The obstacles themselves, once per region: every connected run of ground a
	# piece cannot cross, with how far across it is. A cell size is not really
	# paid for in area lost -- it is paid for in whole obstacles that fall
	# between the cell centres and are not on the board at all, and this is what
	# counts them.
	var obstacles := {}
	for region in regions:
		obstacles[region] = _hole_shapes(truth[region], truth_side, truth_step)

	for size in sizes:
		var cells := 0
		var mixed := 0
		var blocked_truth := 0
		var lost := 0
		var open_truth := 0
		var phantom := 0
		var standable := 0
		var cliffs := 0
		var across := 0
		var shapes := 0
		var unseen := 0
		var widest_unseen := 0.0
		for region in regions:
			var passable: PackedInt32Array = truth[region]
			var found: Dictionary = obstacles[region]
			var ids: PackedInt32Array = found["ids"]
			var widths: PackedFloat32Array = found["widths"]
			var seen := PackedInt32Array()
			seen.resize(widths.size())
			var board := world.combat_board_builder.build_on_ground(
				region.x, region.y, span, float(size)
			)
			across = board.cells_across
			for row in board.cells_deep:
				for column in board.cells_across:
					var cell := board.min_cell + Vector2i(column, row)
					var here := board.is_hole(cell)
					cells += 1
					if here:
						# Which obstacle this cell landed on, by the truth
						# sample nearest its centre. An obstacle no cell centre
						# lands on is one the board does not have.
						var middle := board.centre(cell)
						var sample_x := int(round(
							(middle.x - (region.x - span)) / truth_step
						))
						var sample_z := int(round(
							(middle.y - (region.y - span)) / truth_step
						))
						if sample_x >= 0 and sample_z >= 0 \
								and sample_x < truth_side and sample_z < truth_side:
							var id := ids[sample_z * truth_side + sample_x]
							if id >= 0:
								seen[id] = 1
					if board.is_standable(cell):
						standable += 1
						if board.is_cliff_edge(cell):
							cliffs += 1
					# Every truth sample whose position falls inside this cell.
					var low_x := int(ceil((
						float(cell.x) * float(size) - (region.x - span)
					) / truth_step))
					var low_z := int(ceil((
						float(cell.y) * float(size) - (region.y - span)
					) / truth_step))
					var high_x := int(floor((
						float(cell.x + 1) * float(size) - (region.x - span)
					) / truth_step))
					var high_z := int(floor((
						float(cell.y + 1) * float(size) - (region.y - span)
					) / truth_step))
					var open := 0
					var shut := 0
					for at_z in range(maxi(0, low_z), mini(truth_side, high_z + 1)):
						for at_x in range(maxi(0, low_x), mini(truth_side, high_x + 1)):
							if passable[at_z * truth_side + at_x] == 1:
								open += 1
							else:
								shut += 1
					if open > 0 and shut > 0:
						mixed += 1
					blocked_truth += shut
					open_truth += open
					if here:
						phantom += open
					else:
						lost += shut
			for id in widths.size():
				shapes += 1
				if seen[id] == 0:
					unseen += 1
					widest_unseen = maxf(widest_unseen, widths[id])
		var counted := maxi(1, cells)
		lines.append(
			"board-sweep size=%.2f across=%d cells=%d mixed=%.4f lost=%.4f"
			% [float(size), across, cells, float(mixed) / float(counted),
				float(lost) / float(maxi(1, blocked_truth))]
			+ " phantom=%.4f cliff=%.4f" % [
				float(phantom) / float(maxi(1, open_truth)),
				float(cliffs) / float(maxi(1, standable)),
			]
			+ " obstacles=%d missed=%d missed_share=%.4f widest_missed=%.2f" % [
				shapes, unseen, float(unseen) / float(maxi(1, shapes)), widest_unseen,
			]
		)
	lines.append_array(_board_sweep_buildings(sizes))
	lines.append("board-sweep-regions count=%d span=%.1f truth_step=%.2f" % [
		regions.size(), span, truth_step,
	])
	return lines


## The other half of what a cell size costs, measured on the obstacles the
## settlement layer places rather than on the holes the water and the islands do.
##
## A building is between 2.6 and 7.8 world units across. A lattice sees one only
## if a cell centre lands inside its footprint, so the smallest buildings start
## falling between the cells long before the water does. This counts, per
## candidate size and per kind of building, how many of them the lattice has and
## how many it misses, over every village in a fixed square of the world.
func _board_sweep_buildings(sizes: Array, span: float = 900.0) -> PackedStringArray:
	var lines := PackedStringArray()
	var reach := int(ceil(span / SettlementField.SITE_CELL)) + 1
	var placed: Array[Dictionary] = []
	for cell_x in range(-reach, reach + 1):
		for cell_z in range(-reach, reach + 1):
			var site := world.settlement_field.settlement_in_cell(Vector2i(cell_x, cell_z))
			if site == null:
				continue
			if absf(site.centre_x) > span or absf(site.centre_z) > span:
				continue
			placed.append_array(site.buildings)
	for size in sizes:
		var seen := {}
		var total := {}
		for building in placed:
			var tag := String(building["tag"])
			total[tag] = int(total.get(tag, 0)) + 1
			# Every lattice cell whose centre could fall inside this footprint.
			var span_x: float = float(building["half_width"]) + float(building["half_depth"])
			var low := CombatBoard.cell_of(
				float(building["x"]) - span_x, float(building["z"]) - span_x, float(size)
			)
			var high := CombatBoard.cell_of(
				float(building["x"]) + span_x, float(building["z"]) + span_x, float(size)
			)
			var on_the_lattice := false
			for cell_x in range(low.x, high.x + 1):
				for cell_z in range(low.y, high.y + 1):
					var middle := CombatBoard.centre_of(
						Vector2i(cell_x, cell_z), float(size)
					)
					if Settlement.footprint_contains(building, middle.x, middle.y):
						on_the_lattice = true
						break
				if on_the_lattice:
					break
			if on_the_lattice:
				seen[tag] = int(seen.get(tag, 0)) + 1
		var tags := total.keys()
		tags.sort()
		var found := 0
		var counted := 0
		var parts := PackedStringArray()
		for tag in tags:
			found += int(seen.get(tag, 0))
			counted += int(total[tag])
			parts.append("%s=%d/%d" % [tag, int(seen.get(tag, 0)), int(total[tag])])
		lines.append("board-sweep-built size=%.2f seen=%d/%d share=%.4f %s" % [
			float(size), found, counted,
			float(found) / float(maxi(1, counted)), " ".join(parts),
		])
	return lines


## Every connected run of ground a piece cannot cross in one region's truth grid,
## as {ids, widths}: which obstacle each sample belongs to (-1 for ground a piece
## can cross) and how far across each obstacle is, in world units.
##
## "Across" is the longer side of the obstacle's bounding box rather than its
## area, because what decides whether a lattice can see an obstacle is how wide
## it is, not how much of the world it covers: a long thin river neck is easy to
## miss and a round pond of the same area is not.
##
## Four-connected, walked with an explicit stack rather than by recursion, so a
## lake spanning the whole region cannot run the call stack out.
func _hole_shapes(
	passable: PackedInt32Array, side: int, step: float
) -> Dictionary:
	var ids := PackedInt32Array()
	ids.resize(side * side)
	ids.fill(-1)
	var widths := PackedFloat32Array()
	for start in side * side:
		if passable[start] == 1 or ids[start] != -1:
			continue
		var id := widths.size()
		var low_x := start % side
		var high_x := low_x
		var low_z := start / side
		var high_z := low_z
		var stack: Array[int] = [start]
		ids[start] = id
		while not stack.is_empty():
			var at: int = stack.pop_back()
			var at_x := at % side
			var at_z := at / side
			low_x = mini(low_x, at_x)
			high_x = maxi(high_x, at_x)
			low_z = mini(low_z, at_z)
			high_z = maxi(high_z, at_z)
			for step_at in CombatBoard.NEIGHBOURS:
				var next_x := at_x + step_at.x
				var next_z := at_z + step_at.y
				if next_x < 0 or next_z < 0 or next_x >= side or next_z >= side:
					continue
				var next := next_z * side + next_x
				if passable[next] == 1 or ids[next] != -1:
					continue
				ids[next] = id
				stack.append(next)
		widths.append(float(maxi(high_x - low_x, high_z - low_z) + 1) * step)
	return {"ids": ids, "widths": widths}
