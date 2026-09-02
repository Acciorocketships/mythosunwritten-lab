extends SceneTree
## The resolution suite on its own, for iterating on this layer and for the
## mutation check in tools/resolution_mutations.sh.
##
## Run it with:  ./run_resolution.sh


func _initialize() -> void:
	var suite := TestCombatResolution.new()
	suite.run()
	if suite.failures.is_empty():
		print("PASS  %s  %d checks" % [suite.suite_name, suite.checks])
		quit(0)
		return
	print("FAIL  %s  %d checks, %d failed" % [
		suite.suite_name, suite.checks, suite.failures.size(),
	])
	for failure in suite.failures:
		print("        - %s" % failure)
	quit(1)
