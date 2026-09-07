extends TestSuite
## A suite with one failed expectation and nothing else wrong, so that "a check
## failed" can be told apart from "the suite threw" in `./run_runner_guard.sh`.
class_name RunnerFailingFixture


func _init() -> void:
	suite_name = "failing"


func run() -> void:
	check(true, "a check that holds")
	equal(1, 2, "a check that does not hold, on purpose")
