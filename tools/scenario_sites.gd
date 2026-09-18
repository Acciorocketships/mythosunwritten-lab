extends SceneTree
## Where the scripted scenario's cast can stand on the adopted ground.
##
## `ScriptedScenario` places its five characters as offsets from
## `ScriptedEncounter.WHERE`, and those offsets were measured on the ground this
## project generated before the base adoption (ADOPTION.md). The adopted
## heightfield and water plan put a lake east and north of `WHERE`, so two of
## the offsets no longer name land: the quarrel pair stood in open water and
## could not take a stride, and the bystander's destination was under the same
## lake. A scenario whose fight never begins certifies nothing.
##
## This is the measurement that re-finds them, so the numbers in
## `sim/scripted_scenario.gd` are read off the ground rather than guessed:
##
##   * **the quarrel pair** -- two offsets `APART` units apart on one row, both
##     on standable ground, with every stride of the straight line between them
##     standable, far enough from the market that `Encounter.JOIN_RADIUS` cannot
##     pull the traders in, and with a tactical board at their meeting point
##     that has ground to fight on.
##   * **the bystander's destination** -- a place the straight walk from where
##     Odo starts reaches without crossing water, as far out as the ground
##     allows.
##
## Every candidate that fails is counted by the reason it failed, so the answer
## is a survey and not a lucky hit.
##
## Usage: godot4 --headless --path . -s res://tools/scenario_sites.gd
##        [-- --seed <seed> --span <world units> --step <world units>]

## The seed the scenario is written for, and how far out and how finely the
## sweep looks around `WHERE`.
const DEFAULT_SEED := ScriptedScenario.SEED
const DEFAULT_SPAN := 72.0
const DEFAULT_STEP := 3.0

## How far apart the two who quarrel stand, in world units. Read off the
## scenario so that changing it there changes what is searched for here.
const APART := ScriptedScenario.CAST[3]["at"].x - ScriptedScenario.CAST[2]["at"].x

## How much of a tactical board laid at the meeting has to be ground somebody
## can stand on. A quarrel is only worth watching if there is somewhere to fight
## it: a board half under water is half a board, and the pieces spend the match
## walking round the hole. Nine cells in ten standable is the line drawn here.
const BOARD_OPEN := 0.9

## How much further than `Encounter.JOIN_RADIUS` the quarrel has to be from
## either trader. The radius is the line the join rule reads; the margin is so
## that a character who has walked a stride or two is still outside it.
const JOIN_MARGIN := 8.0

## The stride a walk is taken in, so "the way between them is walkable" is asked
## at the resolution the walk is actually taken at.
const STRIDE := ActionEngine.STEP

## How far Odo's walk is, as the scenario wrote it: the distance from where Odo
## starts to where it was sent. The run is 160 ticks long and a walk is lived
## through one stride per tick, so a destination three times further away is not
## the same scenario -- Odo would still be walking when the transcript ends.
## Destinations are looked for at this distance, give or take ODO_SLACK.
static func odo_walk() -> float:
	return ((ScriptedScenario.ODO_WALKS_TO as Vector2)
		- (ScriptedScenario.CAST[4]["at"] as Vector2)).length()

const ODO_SLACK := 6.0


func _initialize() -> void:
	var options := _options()
	var seed_value: int = options["seed"]
	var span: float = options["span"]
	var step: float = options["step"]
	var terrain := TerrainQuery.for_seed(seed_value)
	var where: Vector2 = ScriptedEncounter.WHERE
	print("scenario-sites seed=%d where=(%.1f, %.1f) span=%.1f step=%.1f" % [
		seed_value, where.x, where.y, span, step])
	print("  apart=%.1f join_radius=%.1f margin=%.1f stride=%.2f" % [
		APART, Encounter.JOIN_RADIUS, JOIN_MARGIN, STRIDE])
	_report_cast_today(terrain, where)
	_report_quarrel(terrain, where, span, step)
	_report_odo(terrain, where, span, step)
	quit()


## What the offsets in the tree name on this ground, before anything is changed.
func _report_cast_today(terrain: TerrainQuery, where: Vector2) -> void:
	print("cast as written:")
	for row in ScriptedScenario.CAST:
		var at: Vector2 = where + (row["at"] as Vector2)
		print("  %-6s at (%7.1f, %7.1f) height=%7.2f water=%-5s standable=%s" % [
			row["name"], at.x, at.y, terrain.ground_height_at(at.x, at.y),
			terrain.is_water_at(at.x, at.y), terrain.is_passable_at(at.x, at.y)])
	var to: Vector2 = where + ScriptedScenario.ODO_WALKS_TO
	print("  %-6s to (%7.1f, %7.1f) height=%7.2f water=%-5s standable=%s" % [
		"Odo->", to.x, to.y, terrain.ground_height_at(to.x, to.y),
		terrain.is_water_at(to.x, to.y), terrain.is_passable_at(to.x, to.y)])


## Every quarrel offset the ground allows, best board first.
func _report_quarrel(
	terrain: TerrainQuery, where: Vector2, span: float, step: float
) -> void:
	var traders: Array[Vector2] = [
		where + (ScriptedScenario.CAST[0]["at"] as Vector2),
		where + (ScriptedScenario.CAST[1]["at"] as Vector2),
	]
	var builder := CombatBoardBuilder.new(terrain)
	var refused := {"standable": 0, "way": 0, "join": 0}
	var passed := []
	var dz := -span
	while dz <= span:
		var dx := -span
		while dx <= span:
			var first := where + Vector2(dx, dz)
			var second := first + Vector2(APART, 0.0)
			dx += step
			if not terrain.is_passable_at(first.x, first.y) \
					or not terrain.is_passable_at(second.x, second.y):
				refused["standable"] += 1
				continue
			if not _way_is_walkable(terrain, first, second):
				refused["way"] += 1
				continue
			var meeting := (first + second) * 0.5
			var nearest := INF
			for trader in traders:
				for at: Vector2 in [first, second, meeting]:
					nearest = minf(nearest, at.distance_to(trader))
			if nearest < Encounter.JOIN_RADIUS + JOIN_MARGIN:
				refused["join"] += 1
				continue
			var board := _board_reading(builder, meeting)
			passed.append({
				"at": Vector2(dx - step, dz), "nearest": nearest,
				"holes": board["holes"], "open": board["open"],
			})
		dz += step
	# Best board first, and among equals the offset nearest the one the
	# scenario was written with, so the run moves as little as it can.
	var written: Vector2 = ScriptedScenario.CAST[2]["at"]
	passed.sort_custom(func(a, b):
		if a["holes"] != b["holes"]:
			return a["holes"] < b["holes"]
		return (a["at"] as Vector2).distance_to(written) \
			< (b["at"] as Vector2).distance_to(written))
	print("quarrel: %d offsets stand, refused standable=%d way=%d join=%d" % [
		passed.size(), refused["standable"], refused["way"], refused["join"]])
	print("  whole board, nearest the offsets the scenario was written with:")
	for rank in mini(6, passed.size()):
		var row: Dictionary = passed[rank]
		var at: Vector2 = row["at"]
		print("    at (%6.1f, %6.1f) nearest_trader=%5.1f board holes=%d open=%.3f" % [
			at.x, at.y, row["nearest"], row["holes"], row["open"]])
	var by_move := passed.duplicate()
	by_move.sort_custom(func(a, b):
		return (a["at"] as Vector2).distance_to(written) \
			< (b["at"] as Vector2).distance_to(written))
	var fit := []
	for row in by_move:
		if row["open"] >= BOARD_OPEN:
			fit.append(row)
	print("  nearest the written offsets with a board at least %.0f%% open:"
		% (BOARD_OPEN * 100.0))
	for rank in mini(6, fit.size()):
		var row: Dictionary = fit[rank]
		var at: Vector2 = row["at"]
		print("    at (%6.1f, %6.1f) moved=%5.1f nearest_trader=%5.1f holes=%d open=%.3f" % [
			at.x, at.y, (at as Vector2).distance_to(written), row["nearest"],
			row["holes"], row["open"]])
	print("  nearest the written offsets, whatever the board reads:")
	for rank in mini(6, by_move.size()):
		var row: Dictionary = by_move[rank]
		var at: Vector2 = row["at"]
		print("    at (%6.1f, %6.1f) moved=%5.1f nearest_trader=%5.1f holes=%d open=%.3f" % [
			at.x, at.y, (at as Vector2).distance_to(written), row["nearest"],
			row["holes"], row["open"]])


## How far out of the market Odo can walk in a straight line, and where to.
func _report_odo(
	terrain: TerrainQuery, where: Vector2, span: float, step: float
) -> void:
	var from: Vector2 = where + (ScriptedScenario.CAST[4]["at"] as Vector2)
	var traders: Array[Vector2] = [
		where + (ScriptedScenario.CAST[0]["at"] as Vector2),
		where + (ScriptedScenario.CAST[1]["at"] as Vector2),
	]
	var best := []
	var dz := -span
	while dz <= span * 2.0:
		var dx := -span
		while dx <= span:
			var to := where + Vector2(dx, dz)
			dx += step
			var walked := from.distance_to(to)
			if absf(walked - odo_walk()) > ODO_SLACK:
				continue
			if not terrain.is_passable_at(to.x, to.y):
				continue
			if not _way_is_walkable(terrain, from, to):
				continue
			var nearest := INF
			for trader in traders:
				nearest = minf(nearest, to.distance_to(trader))
			if nearest < Encounter.JOIN_RADIUS + JOIN_MARGIN:
				continue
			best.append({"at": Vector2(dx - step, dz), "walked": walked,
				"nearest": nearest})
		dz += step
	# Furthest from the market first: Odo's whole part in the run is to be
	# somewhere else while it happens.
	best.sort_custom(func(a, b): return a["nearest"] > b["nearest"])
	print("odo: from (%.1f, %.1f), walk=%.1f +/- %.1f, %d destinations reached" % [
		from.x, from.y, odo_walk(), ODO_SLACK, best.size()])
	for rank in mini(8, best.size()):
		var row: Dictionary = best[rank]
		var at: Vector2 = row["at"]
		print("  to (%6.1f, %6.1f) walked=%6.1f nearest_trader=%6.1f" % [
			at.x, at.y, row["walked"], row["nearest"]])


## Whether a straight walk from one place to the other crosses only ground a
## character can stand on: the same question `Walk.stride` asks, at the same
## stride, every stride of the way.
static func _way_is_walkable(terrain: TerrainQuery, from: Vector2, to: Vector2) -> bool:
	var gap := to - from
	var steps := int(ceil(gap.length() / STRIDE))
	for taken in range(1, steps + 1):
		var at := from + gap.normalized() * minf(STRIDE * taken, gap.length())
		if not terrain.is_passable_at(at.x, at.y):
			return false
	return true


## What a tactical board laid here reads: how many of its cells are holes, and
## what share of it is ground somebody can be put down on.
static func _board_reading(builder: CombatBoardBuilder, at: Vector2) -> Dictionary:
	var board := builder.build_on_ground(at.x, at.y)
	var cells := 0
	var holes := 0
	for row in board.cells_deep:
		for column in board.cells_across:
			cells += 1
			if board.is_hole(board.min_cell + Vector2i(column, row)):
				holes += 1
	return {"holes": holes, "cells": cells,
		"open": 0.0 if cells == 0 else float(cells - holes) / float(cells)}


func _options() -> Dictionary:
	var options := {"seed": DEFAULT_SEED, "span": DEFAULT_SPAN, "step": DEFAULT_STEP}
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var has_value := index + 1 < args.size()
		match args[index]:
			"--seed":
				if has_value and args[index + 1].is_valid_int():
					options["seed"] = args[index + 1].to_int()
			"--span":
				if has_value and args[index + 1].is_valid_float():
					options["span"] = args[index + 1].to_float()
			"--step":
				if has_value and args[index + 1].is_valid_float():
					options["step"] = args[index + 1].to_float()
	return options
