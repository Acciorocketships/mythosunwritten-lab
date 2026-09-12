extends RefCounted
## Minimal test-case base class.
##
## The engine has no test runner of its own, and pulling in a framework for a
## skeleton this size would be more machinery than the thing being tested. A
## suite collects failures instead of aborting, so one broken expectation does
## not hide the rest.
##
## A suite also says where it has got to as it works. It used to print only when
## it finished, and from outside a suite grinding honestly and a suite spinning
## forever were the same picture: the run that certified nothing at cycle 3730
## watched test_terrain_lod print nothing for two hours and could not tell which
## of the two it was looking at. Every PROGRESS_EVERY seconds of work, the check
## helpers below print the suite's name, how many checks it has completed, how
## long it has been going and what it last checked -- so the transcript says what
## a suite was doing when it went quiet, and a silence in the transcript now
## means stuck rather than slow.
class_name TestSuite

## Seconds of work between progress lines. Low enough that the slowest suite
## here says something many times over, high enough that a suite making
## thousands of cheap checks a second does not drown its own transcript.
## RUN_TESTS_PROGRESS overrides it, which is how ./run_runner_guard.sh sees
## progress lines out of a suite that finishes in a second.
static func _progress_every() -> float:
	var set_to := OS.get_environment("RUN_TESTS_PROGRESS")
	if set_to.is_valid_float():
		return maxf(0.0, set_to.to_float())
	return 30.0

var suite_name := "unnamed"
var checks := 0
var failures := PackedStringArray()

## When this suite's first check ran, and when it last said so, in seconds.
## Both are zero until the first check, so a suite that is never entered costs
## nothing and prints nothing.
var _first_check_at := 0.0
var _said_at := 0.0


## Override this. Call the check helpers below; do not return anything.
func run() -> void:
	push_error("TestSuite.run() not overridden by %s" % suite_name)


func check(condition: bool, message: String) -> void:
	checks += 1
	_progress(message)
	if not condition:
		failures.append(message)


func equal(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	_progress(message)
	if actual != expected:
		failures.append("%s\n      expected: %s\n      actual:   %s" % [
			message, str(expected), str(actual),
		])


func not_equal(actual: Variant, unexpected: Variant, message: String) -> void:
	checks += 1
	_progress(message)
	if actual == unexpected:
		failures.append("%s\n      both values were: %s" % [message, str(unexpected)])


## Say where this suite has got to, at most once every _progress_every() seconds.
##
## It is driven from the check helpers rather than from a timer or a thread on
## purpose: what the runner's silence watchdog needs to see is *progress*, not
## liveness. A heartbeat that printed regardless would keep an endless loop
## looking alive for ever and leave the watchdog nothing to judge. A line that
## only appears when a check has completed means a gap in the transcript is a
## gap in the work -- so the budget can be sized against the longest gap a
## healthy suite leaves, and anything longer is genuinely stuck.
func _progress(message: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _first_check_at <= 0.0:
		_first_check_at = now
		_said_at = now
		return
	if now - _said_at < _progress_every():
		return
	_said_at = now
	# The message can run to several lines (expected/actual); one line of it is
	# enough to place the suite, and more would break the transcript's shape.
	var where := message.split("\n")[0]
	if where.length() > 72:
		where = where.substr(0, 69) + "..."
	print("  ..  %-14s %5.0f s, %d checks: %s" % [
		suite_name, now - _first_check_at, checks, where,
	])
