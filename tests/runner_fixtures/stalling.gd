extends TestSuite
## A suite that never returns, and never says anything while not returning.
##
## Nothing inside the process can end this: GDScript is running, the engine is
## waiting for it, and there is no frame boundary left to reach. A suite blocked
## on a child process that never exits looks exactly the same from outside. The
## bounded wait in `run_tests.sh` is the only thing that ends it, which is why
## that guard is in the shell and not here.
##
## `./run_runner_guard.sh` runs this one with a short RUN_TESTS_SILENCE.
class_name RunnerStallingFixture

## Long enough that the guard's own wait is what ends the run, short enough that
## a mistake does not leave a process on the machine for the rest of the day.
const GIVE_UP_AFTER_MS := 600_000


func _init() -> void:
	suite_name = "stalling"


func run() -> void:
	var until := Time.get_ticks_msec() + GIVE_UP_AFTER_MS
	while Time.get_ticks_msec() < until:
		pass
