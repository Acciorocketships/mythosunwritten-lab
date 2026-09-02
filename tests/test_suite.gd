extends RefCounted
## Minimal test-case base class.
##
## The engine has no test runner of its own, and pulling in a framework for a
## skeleton this size would be more machinery than the thing being tested. A
## suite collects failures instead of aborting, so one broken expectation does
## not hide the rest.
class_name TestSuite

var suite_name := "unnamed"
var checks := 0
var failures := PackedStringArray()


## Override this. Call the check helpers below; do not return anything.
func run() -> void:
	push_error("TestSuite.run() not overridden by %s" % suite_name)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func equal(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s\n      expected: %s\n      actual:   %s" % [
			message, str(expected), str(actual),
		])


func not_equal(actual: Variant, unexpected: Variant, message: String) -> void:
	checks += 1
	if actual == unexpected:
		failures.append("%s\n      both values were: %s" % [message, str(unexpected)])
