extends SceneTree
## Test entry point: run every suite, print the results, exit non-zero if any
## expectation failed.
##
## Run it with:  ./run_tests.sh

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
	preload("res://tests/test_checks.gd"),
	preload("res://tests/test_orchestrator.gd"),
	preload("res://tests/test_fight_driver.gd"),
	preload("res://tests/test_enemies.gd"),
	preload("res://tests/test_turn_seam.gd"),
	preload("res://tests/test_player_input.gd"),
	preload("res://tests/test_player_actions.gd"),
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
]


func _initialize() -> void:
	var total_checks := 0
	var failed_suites := 0
	var total_failures := 0

	for suite_script in SUITES:
		var suite: TestSuite = suite_script.new()
		suite.run()
		total_checks += suite.checks
		if suite.failures.is_empty():
			print("PASS  %-14s %d checks" % [suite.suite_name, suite.checks])
		else:
			failed_suites += 1
			total_failures += suite.failures.size()
			print("FAIL  %-14s %d checks, %d failed" % [
				suite.suite_name, suite.checks, suite.failures.size(),
			])
			for failure in suite.failures:
				print("        - %s" % failure)

	print("")
	if failed_suites == 0:
		print("all %d suites passed (%d checks)" % [SUITES.size(), total_checks])
		quit(0)
	else:
		print("%d of %d suites failed (%d failed checks of %d)" % [
			failed_suites, SUITES.size(), total_failures, total_checks,
		])
		quit(1)
