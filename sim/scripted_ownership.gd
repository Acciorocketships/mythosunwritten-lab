extends RefCounted
## The measurement that chose the three numbers section 6 leaves open.
##
## Section 13 lists them as an open decision -- "Ownership thresholds and
## weighting functions -- softmin temperature, radius, and threshold" -- and
## `OwnershipField` settles them. This file is why they are what they are. It
## stands up the shipped seeded run, samples a stated grid of ground over it, and
## prints every table the three choices rest on. Nothing here is part of the
## rule: `OwnershipField.measured()` is called with stated constants and there is
## no second copy of the arithmetic anywhere.
##
## What it measures on is `ScriptedScenario` at its own seed and tick count --
## the same run `./run_scenario.sh` prints. Two of its five characters traded and
## came to like each other, two fought and came to fear each other, one walked
## away and met nobody; one of the fighters fell. That is a small world, and
## deliberately so: it is the world the project actually ships, its relationship
## graph was written by the engine's own record of what happened, and a constant
## tuned against a world invented here would be tuned against nothing.
##
## ## The one thing worth knowing before reading the tables
##
## Section 6's rule is an *average*, so the score is scale-free in distance: a
## point 100 units from a lone friendly character scores exactly what a point one
## unit away scores, because in both cases that character is the whole of the
## neighbourhood being averaged over. Distance decides *which* neighbours are
## heard and how loudly relative to each other; it does not decide whether
## anybody is heard at all.
##
## That is not a defect in the arithmetic, it is what "distance-weighted average"
## means, and it fixes what each of the three numbers is actually for:
##
##   * the **radius** is what gives territory an edge, because nothing else does;
##   * the **temperature** decides whose opinion wins inside that edge;
##   * the **threshold** decides how favourable a neighbourhood has to be.
##
## Each is chosen below against a criterion stated before the table that settles
## it, so the number can be checked against the measurement rather than believed.
##
## Six sections come out, in the order the choices were made:
##
##   1. the world being measured on -- who stands where, and what the graph says;
##   2. the proximity shape, both of them, swept over temperature;
##   3. the radius;
##   4. the threshold, against the distribution of top scores over the grid;
##   5. status and level, one changed at a time, on ground otherwise identical;
##   6. what asking costs.
##
## No clock is read here at all -- nothing under sim/ may read one, and
## `tests/test_control_loop.gd` fails the build if anything does. What `--cost`
## adds is timed by `bin/ownership_main.gd` around `sample_all()` below, outside
## the simulation, so this report is byte-identical across two processes.
class_name ScriptedOwnership

## The run measured on: the shipped scenario, at its own seed and length.
const SEED := ScriptedScenario.SEED
const TICKS := ScriptedScenario.TICKS

## The grid of ground sampled, stated here and nowhere else: a square centred on
## the meeting place, this far out in each direction, sampled this far apart.
## 41 x 41 = 1681 points over 240 x 240 world units.
const GRID_REACH := 120.0
const GRID_STEP := 6.0

## The two characters whose ground the single-number probe is taken on: the pair
## who traded, and so the only pair in this run with anything good to say about
## each other. The probe is the midpoint between where they are standing at the
## end of the run.
const TRADED := [ScriptedScenario.WREN, ScriptedScenario.ROOK]

## The temperatures swept, in world units.
const TEMPERATURES := [3.0, 6.0, 12.0, 24.0, 48.0, 96.0]

## The radii swept, in world units, and the one that stands for "no radius at
## all" -- every entity in the world has a say however far off it is.
const RADII := [20.0, 40.0, 60.0, 90.0, 120.0, 180.0, 240.0, 360.0]
const UNBOUNDED := 1.0e9

## The thresholds swept.
const THRESHOLDS := [0.005, 0.01, 0.02, 0.05, 0.10, 0.15, 0.20, 0.30]

## How far a claim may be diluted at the holder's own feet before the temperature
## is judged too warm: the share of the raw sentiment that must survive there.
const KEEPS := 0.95

## How much one character's standing and battle strength are moved by in the
## counterfactual of section 5, and which character's.
const MOVED_BY := 4
const MOVED := ScriptedScenario.ROOK


## The shipped seeded run, played out and handed over: what the whole report is
## measured on, and what the entry point times a sweep of.
static func staged() -> ActionScene:
	return ScriptedScenario.played_to(TICKS, SEED)


## Sample every point of the stated grid once under the settled constants, and
## hand back how many were sampled. This is the call `--cost` puts a clock
## around, from outside.
static func sample_all(scene: ActionScene) -> int:
	return _owners_over_grid(scene, OwnershipField.PROXIMITY,
		OwnershipField.TEMPERATURE, OwnershipField.RADIUS,
		OwnershipField.THRESHOLD).size()


## The whole report.
static func report() -> PackedStringArray:
	var scene := staged()
	var probe := probe_at(scene)
	var written := PackedStringArray()
	written.append("ownership seed=%d ticks=%d grid=%dx%d step=%.1f centred on (%.1f, %.1f)"
		% [
			SEED, TICKS, _across(), _across(), GRID_STEP,
			ScriptedScenario.WHERE.x, ScriptedScenario.WHERE.y,
		])
	written.append("the probe is the ground between the two who traded, (%.1f, %.1f)"
		% [probe.x, probe.y])
	written.append("")
	written.append_array(_the_world(scene))
	written.append("")
	written.append_array(_the_shape(scene, probe))
	written.append("")
	written.append_array(_the_radius(scene))
	written.append("")
	written.append_array(_the_threshold(scene, probe))
	written.append("")
	written.append_array(_status_and_level())
	written.append("")
	written.append_array(_what_it_costs(scene))
	return written


# --- 1. The world it is measured on ---------------------------------------


static func _the_world(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("1. the world it is measured on, after %d ticks" % scene.tick)
	written.append("   carry is what one character's opinion is worth: status + level.")
	for one in scene.actors:
		var sheet := OwnershipField.sheet_of(one)
		if sheet == null:
			continue
		written.append("   #%d %-6s level=%d status=%d carry=%d at (%.1f, %.1f)" % [
			one.id, sheet.character_name, sheet.level, sheet.status(),
			OwnershipField.carry(sheet), one.x, one.z,
		])
	var graph := scene.relationships
	written.append("   the graph: %d edges, %d happenings" % [
		graph.size(), graph.happenings(),
	])
	for edge in graph.all():
		for end in [edge.low, edge.high]:
			var toward := edge.other_than(end)
			written.append("     #%d -> #%d sentiment %+.4f%s" % [
				end, toward, edge.sentiment_of(end),
				_absent(scene, end, toward),
			])
	written.append("   the strongest thing anybody in this world feels about anybody"
		+ " still standing is %+.4f." % _strongest(scene))
	return written


# One end of an edge counting for nothing, said in words. A character that has
# fallen is not in the cast, so it neither has a say nor can be owed ground.
static func _absent(scene: ActionScene, viewer: int, toward: int) -> String:
	if not _standing(scene, viewer):
		return "  (#%d has fallen: this opinion has no say)" % viewer
	if not _standing(scene, toward):
		return "  (#%d has fallen: it can hold no ground)" % toward
	return ""


# --- 2. The proximity shape and its temperature ---------------------------


static func _the_shape(scene: ActionScene, probe: Vector2) -> PackedStringArray:
	var strongest := _strongest(scene)
	var written := PackedStringArray()
	written.append("2. the proximity shape and its temperature")
	written.append("   swept with no radius at all, so the radius cannot confound it.")
	written.append("   held is the share of the grid with an owner at threshold %.3f;"
		% OwnershipField.THRESHOLD)
	written.append("   probe is the top score on the ground the two who traded stand on,")
	written.append("   and kept is that as a share of the %+.4f they actually feel --"
		% strongest)
	written.append("   how much of a claim survives being averaged with the neighbours.")
	written.append("   the criterion: the warmest temperature that keeps at least"
		+ " %.0f%% of it," % (100.0 * KEEPS))
	written.append("   so the widest neighbourhood that still does not dilute a claim"
		+ " where it is strongest.")
	written.append("   %-8s %5s %7s %6s %8s %7s %8s %8s %8s" % [
		"shape", "T", "held", "owners", "probe", "kept", "p50", "p90", "max",
	])
	for shape in OwnershipField.SHAPES:
		for temperature in TEMPERATURES:
			var swept := _sweep(scene, shape, float(temperature), UNBOUNDED,
				OwnershipField.THRESHOLD)
			var here := OwnershipField.measured(scene.actors, scene.relationships,
				probe.x, probe.y, shape, float(temperature), UNBOUNDED,
				OwnershipField.THRESHOLD)
			written.append("   %-8s %5.1f %6.1f%% %6d %8.4f %6.1f%% %8.4f %8.4f %8.4f" % [
				shape, temperature, 100.0 * swept["held"], int(swept["owners"]),
				here.best, 100.0 * here.best / maxf(strongest, 0.0001),
				swept["p50"], swept["p90"], swept["max"],
			])
	return written


# --- 3. The radius --------------------------------------------------------


static func _the_radius(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("3. the radius, at %s T=%.1f" % [
		OwnershipField.PROXIMITY, OwnershipField.TEMPERATURE,
	])
	written.append("   none/one/many is how much of the grid hears no entity, exactly")
	written.append("   one, and two or more. The criterion: section 6 asks for an"
		+ " average,")
	written.append("   and an average over one opinion is not one -- so the smallest")
	written.append("   radius over which most of the sampled ground hears two or more.")
	written.append("   differs is the share of points whose owner is not what an"
		+ " unbounded radius says.")
	written.append("   %6s %10s %8s %8s %8s %8s %9s" % [
		"R", "near/point", "none", "one", "many", "held", "differs",
	])
	var unbounded := _owners_over_grid(scene, OwnershipField.PROXIMITY,
		OwnershipField.TEMPERATURE, UNBOUNDED, OwnershipField.THRESHOLD)
	for radius in RADII:
		var swept := _sweep(scene, OwnershipField.PROXIMITY,
			OwnershipField.TEMPERATURE, float(radius), OwnershipField.THRESHOLD)
		var owners: PackedInt32Array = swept["map"]
		var differs := 0
		for at in range(owners.size()):
			if owners[at] != unbounded[at]:
				differs += 1
		var points := float(maxi(1, owners.size()))
		written.append("   %6.1f %10.2f %7.1f%% %7.1f%% %7.1f%% %7.1f%% %8.1f%%%s" % [
			radius, swept["near"],
			100.0 * float(swept["heard_none"]) / points,
			100.0 * float(swept["heard_one"]) / points,
			100.0 * float(swept["heard_many"]) / points,
			100.0 * swept["held"],
			100.0 * float(differs) / points,
			"   <- chosen" if is_equal_approx(float(radius), OwnershipField.RADIUS) else "",
		])
	return written


# --- 4. The threshold -----------------------------------------------------


static func _the_threshold(scene: ActionScene, probe: Vector2) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("4. the threshold, against the top scores the grid actually holds")
	var swept := _sweep(scene, OwnershipField.PROXIMITY, OwnershipField.TEMPERATURE,
		OwnershipField.RADIUS, OwnershipField.THRESHOLD)
	var sorted: Array[float] = swept["sorted"]
	written.append("   top score over the grid, by decile:")
	var deciles := PackedStringArray()
	for tenth in range(11):
		deciles.append("%.4f" % _quantile(sorted, 0.1 * float(tenth)))
	written.append("     " + " ".join(deciles))
	var gap := _widest_gap(sorted)
	written.append("   the widest gap between neighbouring top scores: from %.4f to"
		% gap["below"])
	written.append("     %.4f, a gap of %.4f, with %.1f%% of the grid below it. There is"
		% [gap["above"], gap["size"], 100.0 * gap["share"]])
	written.append("     no valley to put a threshold in: the scores are a gradient,"
		+ " not two clumps.")
	written.append("   so it is pinned from both ends instead, by two numbers the world"
		+ " itself gives:")
	written.append("     a single honoured exchange between two strangers earns"
		+ " %.2f x %.2f = %.4f" % [
			RelationshipGraph.MET, RelationshipGraph.TRADE_TRUST, _one_dealing(),
		])
	written.append("       sentiment, which is the least a claim anybody has actually"
		+ " earned can be;")
	written.append("     and the strongest claim this run reaches is %.4f, on the ground"
		% _probe_best(scene, probe))
	written.append("       the two who traded stand on. A threshold above that owns"
		+ " nothing, ever.")
	written.append("   %9s %9s %9s %8s" % ["threshold", "neutral", "held", "owners"])
	for threshold in THRESHOLDS:
		var row := _sweep(scene, OwnershipField.PROXIMITY, OwnershipField.TEMPERATURE,
			OwnershipField.RADIUS, float(threshold))
		written.append("   %9.3f %8.1f%% %8.1f%% %8d%s" % [
			threshold, 100.0 * (1.0 - row["held"]), 100.0 * row["held"],
			int(row["owners"]),
			"   <- chosen" if is_equal_approx(float(threshold), OwnershipField.THRESHOLD) else "",
		])
	return written


## What one honoured exchange between two strangers is worth as raw sentiment:
## familiarity `MET` times trust `TRADE_TRUST`, both out of `RelationshipGraph`.
## The threshold is this number, and `tests/test_ownership.gd` fails if the two
## ever part -- so retuning what a trade is worth cannot silently leave the
## threshold defended by a sentence that stopped being true.
static func _one_dealing() -> float:
	return RelationshipGraph.MET * RelationshipGraph.TRADE_TRUST


# --- 5. Status and level, one at a time -----------------------------------


static func _status_and_level() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("5. status and level both enter, and each moves ownership on its own")
	written.append("   the same run, four times. %s's sheet is changed after the run and"
		% MOVED)
	written.append("   before the question, so the world's history is identical in all"
		+ " four and")
	written.append("   exactly one number differs at the moment of asking. Standing is"
		+ " pinned in")
	written.append("   the level row, because an unassigned status tracks the level and"
		+ " would")
	written.append("   otherwise move with it.")
	written.append("   %-14s %6s %6s %6s %9s %14s %8s" % [
		"run", "level", "status", "carry", "probe", "cells", "neutral",
	])
	for variant in [
		{"named": "shipped", "level": 0, "status": -1},
		{"named": "status +%d" % MOVED_BY, "level": 0, "status": MOVED_BY},
		{"named": "level +%d" % MOVED_BY, "level": MOVED_BY, "status": 0},
		{"named": "both +%d" % MOVED_BY, "level": MOVED_BY, "status": MOVED_BY},
	]:
		var scene := ScriptedScenario.played_to(TICKS, SEED)
		var sheet := OwnershipField.sheet_of(_named(scene, MOVED))
		# The level first, because an unassigned status tracks it; then the
		# status is pinned, so that "level +N" really does hold standing still.
		var was_status := sheet.status()
		sheet.level += int(variant["level"])
		if int(variant["status"]) >= 0:
			sheet.set_status(was_status + int(variant["status"]))
		var swept := _sweep(scene, OwnershipField.PROXIMITY, OwnershipField.TEMPERATURE,
			OwnershipField.RADIUS, OwnershipField.THRESHOLD)
		var probe := probe_at(scene)
		var here := OwnershipField.at(scene.actors, scene.relationships, probe.x, probe.y)
		var held: Dictionary = swept["cells"]
		var by_owner := PackedStringArray()
		for id in held:
			by_owner.append("#%d:%d" % [id, int(held[id])])
		written.append("   %-14s %6d %6d %6d %9.4f %14s %7.1f%%" % [
			variant["named"], sheet.level, sheet.status(),
			OwnershipField.carry(sheet), here.best,
			" ".join(by_owner) if by_owner.size() > 0 else "none",
			100.0 * (1.0 - swept["held"]),
		])
	return written


# --- 6. What asking costs -------------------------------------------------


static func _what_it_costs(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("6. what one question costs")
	var swept := _sweep(scene, OwnershipField.PROXIMITY, OwnershipField.TEMPERATURE,
		OwnershipField.RADIUS, OwnershipField.THRESHOLD)
	written.append("   %d points on the grid; %.2f entities looked at per point,"
		% [int(swept["points"]), swept["scanned"]])
	written.append("   %.2f near enough to have a say on average, %d at the most."
		% [swept["near"], int(swept["most"])])
	written.append("   the whole world is looked at once per point and the near ones"
		+ " twice: once")
	written.append("   for their weight, once per claimant for their opinion of it.")
	written.append("   (pass --cost for the wall clock. No clock is read in here: nothing")
	written.append("    under sim/ may read one, so the entry point times a sweep from")
	written.append("    outside and this report is byte-identical across two processes.)")
	return written


# --- The grid ---------------------------------------------------------------


## Every point of the stated grid, in a fixed order: z outer, x inner.
static func grid() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var steps := _across()
	for row in range(steps):
		for column in range(steps):
			points.append(Vector2(
				ScriptedScenario.WHERE.x - GRID_REACH + GRID_STEP * float(column),
				ScriptedScenario.WHERE.y - GRID_REACH + GRID_STEP * float(row)))
	return points


## The ground the single-number probe is taken on: midway between the two who
## traded, wherever the run left them standing.
static func probe_at(scene: ActionScene) -> Vector2:
	var found := Vector2.ZERO
	var count := 0
	for called in TRADED:
		var one := _named(scene, called)
		if one == null:
			continue
		found += Vector2(one.x, one.z)
		count += 1
	return found / float(maxi(1, count))


## Sample the whole grid under stated constants and reduce it to the numbers the
## tables above are made of.
static func _sweep(
	scene: ActionScene, shape: String,
	temperature: float, radius: float, threshold: float
) -> Dictionary:
	var owners := PackedInt32Array()
	var tops: Array[float] = []
	var cells := {}
	var near := 0
	var scanned := 0
	var most := 0
	var heard := [0, 0, 0]
	var points := grid()
	for at in points:
		var claim := OwnershipField.measured(scene.actors, scene.relationships,
			at.x, at.y, shape, temperature, radius, threshold)
		owners.append(claim.owner_id)
		tops.append(claim.best)
		near += claim.considered
		scanned += claim.scanned
		most = maxi(most, claim.considered)
		heard[mini(claim.considered, 2)] += 1
		if claim.is_neutral():
			continue
		cells[claim.owner_id] = int(cells.get(claim.owner_id, 0)) + 1
	var held := 0
	for id in cells:
		held += int(cells[id])
	var sorted := tops.duplicate()
	sorted.sort()
	var count := maxi(1, points.size())
	return {
		"points": points.size(),
		"map": owners,
		"sorted": sorted,
		"cells": cells,
		"owners": cells.size(),
		"held": float(held) / float(count),
		"near": float(near) / float(count),
		"scanned": float(scanned) / float(count),
		"most": most,
		"heard_none": heard[0],
		"heard_one": heard[1],
		"heard_many": heard[2],
		"p50": _quantile(sorted, 0.5),
		"p90": _quantile(sorted, 0.9),
		"max": _quantile(sorted, 1.0),
	}


static func _owners_over_grid(
	scene: ActionScene, shape: String,
	temperature: float, radius: float, threshold: float
) -> PackedInt32Array:
	var owners := PackedInt32Array()
	for at in grid():
		owners.append(OwnershipField.measured(scene.actors, scene.relationships,
			at.x, at.y, shape, temperature, radius, threshold).owner_id)
	return owners


static func _across() -> int:
	return int(round(2.0 * GRID_REACH / GRID_STEP)) + 1


static func _quantile(sorted: Array[float], share: float) -> float:
	if sorted.is_empty():
		return 0.0
	var at := int(round(clampf(share, 0.0, 1.0) * float(sorted.size() - 1)))
	return sorted[at]


## The widest gap between neighbouring values in the sorted top scores, and how
## much of the grid lies below it. If held ground and empty ground scored two
## different sorts of number, the gap between the two would be the widest one in
## the sample; the report says what it actually is.
static func _widest_gap(sorted: Array[float]) -> Dictionary:
	var found := {"below": 0.0, "above": 0.0, "size": 0.0, "share": 0.0}
	for at in range(1, sorted.size()):
		var size := sorted[at] - sorted[at - 1]
		if size > float(found["size"]):
			found = {
				"below": sorted[at - 1], "above": sorted[at], "size": size,
				"share": float(at) / float(sorted.size()),
			}
	return found


## The strongest raw sentiment in the world that could actually decide ownership:
## held by somebody standing, about somebody standing.
static func _strongest(scene: ActionScene) -> float:
	var most := 0.0
	for edge in scene.relationships.all():
		for end in [edge.low, edge.high]:
			if _standing(scene, end) and _standing(scene, edge.other_than(end)):
				most = maxf(most, edge.sentiment_of(end))
	return most


static func _probe_best(scene: ActionScene, probe: Vector2) -> float:
	return OwnershipField.at(scene.actors, scene.relationships, probe.x, probe.y).best


static func _standing(scene: ActionScene, id: int) -> bool:
	return OwnershipField.sheet_of(scene.actor_of(id)) != null


static func _named(scene: ActionScene, called: String) -> Combatant:
	for one in scene.actors:
		var sheet := OwnershipField.sheet_of(one)
		if sheet != null and sheet.character_name == called:
			return one
	return null
