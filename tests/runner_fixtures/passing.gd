extends TestSuite
## A suite that passes, cheaply, so that ./run_runner_guard.sh can check what a
## run does after a suite -- carry on to the next one, print "all N passed" --
## without borrowing a real suite for it.
##
## It used to borrow test_asset_tags for that. On the adopted base that suite
## costs four minutes and 12.4 GiB, and it is red for two reasons of its own, so
## borrowing it made the guard slow and made the runner's own verdict depend on
## whether some other suite happened to be green that week. The guard is about
## the runner; what a real suite asserts is the suites' business.
class_name RunnerPassingFixture


func _init() -> void:
	suite_name = "passing"


func run() -> void:
	check(true, "a check that holds")
	equal(2, 2, "another check that holds")
