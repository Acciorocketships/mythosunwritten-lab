extends SceneTree
## Run just the orchestrator suite, print the result, exit non-zero if any
## expectation failed.
##
## Run it with:  ./run_world_suite.sh


func _initialize() -> void:
	var suite: TestSuite = preload("res://tests/test_orchestrator.gd").new()
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
