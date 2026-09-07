extends TestSuite
## A suite that raises a runtime error on purpose, one frame below its `run()`.
##
## This is the shape `tests/test_goals.gd` was in when the run stopped being
## trusted: a read one past the end of an `Array[Dictionary]`, in a helper the
## suite's own `run()` called. The engine abandons the helper and returns to
## `run()`, so the runner is told nothing and would otherwise print `PASS` for a
## suite that never finished its checks -- which is what the full run of cycle
## 194 did print. `run_tests.sh` reads the engine's `SCRIPT ERROR` line back
## instead, and `./run_runner_guard.sh` is where that is checked.
##
## Nothing loads this but that check. It is not in `bin/test_main.gd`'s list.
class_name RunnerThrowingFixture


func _init() -> void:
	suite_name = "throwing"


func run() -> void:
	check(true, "a check before the error")
	_reads_past_the_end()
	check(true, "a check after the error, which is reached because the caller resumes")


func _reads_past_the_end() -> void:
	var refusals: Array[Dictionary] = [{"why": "the one refusal that is written down"}]
	print("never printed: %s" % String(refusals[1]["why"]))
