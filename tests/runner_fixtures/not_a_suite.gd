extends RefCounted
## Not a suite at all: whatever else it is, it is not a `TestSuite`, so the
## runner's own `var suite: TestSuite = suite_script.new()` fails.
##
## That error is raised in the runner's frame rather than in a suite's, and an
## error takes the frame it was raised in with it. In the old runner that frame
## was `_initialize()` itself -- the one holding the loop, the summary and both
## `quit()` calls -- so the process printed nothing more and idled forever.
## Running one suite per idle frame is what makes this cost one suite instead of
## the run; `./run_runner_guard.sh` is where that is checked.
class_name RunnerNotASuiteFixture
