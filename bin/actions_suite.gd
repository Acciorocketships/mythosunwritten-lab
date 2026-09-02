extends SceneTree
## Run just the atomic-action suite headless. Exits 0 when it passes.
##
## Run it with:  ./run_actions_suite.sh

const SUITE := preload("res://tests/test_actions.gd")


func _initialize() -> void:
	var suite: TestSuite = SUITE.new()
	suite.run()
	if suite.failures.is_empty():
		print("PASS  %-14s %d checks" % [suite.suite_name, suite.checks])
		quit(0)
		return
	print("FAIL  %-14s %d checks, %d failed" % [
		suite.suite_name, suite.checks, suite.failures.size(),
	])
	for failure in suite.failures:
		print("        - %s" % failure)
	quit(1)
