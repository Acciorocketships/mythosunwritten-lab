extends SceneTree
## Test entry point: run every suite, print the results, exit non-zero if any
## expectation failed.
##
## Run it with:  ./run_tests.sh
##
## Naming suites runs only those:  ./run_tests.sh test_rng test_items
##
## Suites run one per idle frame, not in one loop. GDScript cannot catch a
## runtime error, and an error abandons the whole GDScript call chain back to
## the engine call that entered it -- so a suite that reads past the end of an
## array used to take `_initialize()` down with it, leaving the summary
## unprinted, neither `quit()` reached, and the process idling forever. The
## engine calls `_process()` again on the next frame either way, so one suite
## per frame turns "that frame never came back" into a reported failure:
## `_running` holds the name of the suite that was entered and is cleared only
## when it returns.


const SUITES := [
	preload("res://tests/test_rng.gd"),
	preload("res://tests/test_determinism.gd"),
	preload("res://tests/test_terrain.gd"),
	preload("res://tests/test_streaming.gd"),
	preload("res://tests/test_terrain_lod.gd"),
	preload("res://tests/test_mountains.gd"),
	preload("res://tests/test_biomes.gd"),
	preload("res://tests/test_water.gd"),
	preload("res://tests/test_islands.gd"),
	preload("res://tests/test_island_cover.gd"),
	preload("res://tests/test_settlements.gd"),
	preload("res://tests/test_scatter.gd"),
	preload("res://tests/test_combat_board.gd"),
	preload("res://tests/test_combat_pieces.gd"),
	preload("res://tests/test_combat_resolution.gd"),
	preload("res://tests/test_combat_snap.gd"),
	preload("res://tests/test_live_world.gd"),
	preload("res://tests/test_layering.gd"),
	preload("res://tests/test_asset_tags.gd"),
	preload("res://tests/test_characters.gd"),
	preload("res://tests/test_character_sheet.gd"),
	preload("res://tests/test_items.gd"),
	preload("res://tests/test_inventory.gd"),
	preload("res://tests/test_drops.gd"),
	preload("res://tests/test_ground_items.gd"),
	preload("res://tests/test_effects.gd"),
	preload("res://tests/test_actions.gd"),
	preload("res://tests/test_control_loop.gd"),
	preload("res://tests/test_walk_motion.gd"),
	preload("res://tests/test_observation.gd"),
	preload("res://tests/test_scenario.gd"),
	preload("res://tests/test_agent.gd"),
	preload("res://tests/test_memory.gd"),
	preload("res://tests/test_goals.gd"),
	preload("res://tests/test_upkeep.gd"),
	preload("res://tests/test_tool_budget.gd"),
	preload("res://tests/test_relationships.gd"),
	preload("res://tests/test_ownership.gd"),
	preload("res://tests/test_checks.gd"),
	preload("res://tests/test_goodwill.gd"),
	preload("res://tests/test_territory.gd"),
	preload("res://tests/test_orchestrator.gd"),
	preload("res://tests/test_fight_driver.gd"),
	preload("res://tests/test_enemies.gd"),
	preload("res://tests/test_turn_seam.gd"),
	preload("res://tests/test_strike_record.gd"),
	preload("res://tests/test_attack_clips.gd"),
	preload("res://tests/test_flights.gd"),
	preload("res://tests/test_held_items.gd"),
	preload("res://tests/test_player_input.gd"),
	preload("res://tests/test_player_actions.gd"),
	preload("res://tests/test_bargain.gd"),
	preload("res://tests/test_player_inventory.gd"),
	preload("res://tests/test_player_combat.gd"),
	preload("res://tests/test_window_glow.gd"),
	preload("res://tests/test_board_overlay.gd"),
	preload("res://tests/test_grass.gd"),
	preload("res://tests/test_atmosphere.gd"),
	preload("res://tests/test_reflection.gd"),
	preload("res://tests/test_anti_aliasing.gd"),
	preload("res://tests/test_render_shell.gd"),
	preload("res://tests/test_ui_panel.gd"),
	preload("res://tests/test_ui_readout.gd"),
	preload("res://tests/test_ui_exchange.gd"),
	preload("res://tests/test_ui_territory.gd"),
]


## Where a named suite is looked for when one is named on the command line.
const SUITE_DIR := "res://tests/%s.gd"

## The suites this run will work through, and how far into them it has got.
var _queue: Array = []
var _index := 0

## The suite that was entered and has not come back yet, "" between suites. A
## non-empty value at the top of a frame is how a throw is detected.
var _running := ""

## How many suites this run set out to work through, including any named on the
## command line that turned out not to exist.
var _total_suites := 0

var _total_checks := 0
var _failed_suites := 0
var _total_failures := 0


func _initialize() -> void:
	_queue = _selection()
	_total_suites += _queue.size()


func _process(_delta: float) -> bool:
	if _running != "":
		# The previous frame entered this suite and the frame never finished:
		# the engine abandoned it on a runtime error, printed above this line.
		_failed_suites += 1
		_total_failures += 1
		print("FAIL  %-14s threw a runtime error (see the SCRIPT ERROR above)" % _running)
		_running = ""

	if _index >= _queue.size():
		_report()
		return true

	var suite_script: Script = _queue[_index]
	_index += 1
	_run_one(suite_script)
	return false


## Enter one suite. Everything after the `suite.run()` call is skipped when the
## suite throws, which is what leaves `_running` set for the next frame.
func _run_one(suite_script: Script) -> void:
	# Named by its file, before anything of it is loaded or entered: a suite that
	# breaks the runner before it is even instantiated still has to be nameable.
	_running = _script_label(suite_script)
	print("RUN   %s" % _running)

	var suite: TestSuite = suite_script.new()
	suite.run()

	_total_checks += suite.checks
	if suite.failures.is_empty():
		print("PASS  %-14s %d checks" % [suite.suite_name, suite.checks])
	else:
		_failed_suites += 1
		_total_failures += suite.failures.size()
		print("FAIL  %-14s %d checks, %d failed" % [
			suite.suite_name, suite.checks, suite.failures.size(),
		])
		for failure in suite.failures:
			print("        - %s" % failure)
	_running = ""


func _report() -> void:
	print("")
	if _failed_suites == 0:
		print("all %d suites passed (%d checks)" % [_total_suites, _total_checks])
		quit(0)
	else:
		print("%d of %d suites failed (%d failed checks of %d)" % [
			_failed_suites, _total_suites, _total_failures, _total_checks,
		])
		quit(1)


## Every suite, or just the ones named after `--` on the command line. A name is
## a file stem under `tests/` ("test_rng") or a full `res://` path.
func _selection() -> Array:
	var names := OS.get_cmdline_user_args()
	if names.is_empty():
		return SUITES.duplicate()
	var chosen: Array = []
	for name in names:
		var path := name if name.begins_with("res://") else SUITE_DIR % name
		if not ResourceLoader.exists(path):
			push_error("no such suite: %s" % path)
			print("FAIL  %-14s no such suite (%s)" % [name, path])
			_failed_suites += 1
			_total_failures += 1
			_total_suites += 1
			continue
		chosen.append(load(path))
	return chosen


## What to call a suite before it has been instantiated: its file stem.
func _script_label(suite_script: Script) -> String:
	var path := suite_script.resource_path
	if path.is_empty():
		return "unnamed"
	return path.get_file().get_basename()
