extends SceneTree
## The piece suite on its own, for iterating on this layer and for the mutation
## check in tools/piece_mutations.sh.
##
## Run it with:  ./run_pieces.sh
##
## The whole suite runs it too -- this entry point exists so that one layer can
## be re-run in seconds while it is being worked on, and so that a script can
## break a rule on purpose and ask whether the suite noticed.


func _initialize() -> void:
	var suite := TestCombatPieces.new()
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
