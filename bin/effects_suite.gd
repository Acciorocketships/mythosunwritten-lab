extends SceneTree
## The effect suite on its own, for iterating on the composable base.
##
## Run it with:  ./run_effect_suite.sh
##
## The whole suite runs it too -- this entry point exists so that one layer can
## be re-run in seconds while it is being worked on.


func _initialize() -> void:
	var suite := TestEffects.new()
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
