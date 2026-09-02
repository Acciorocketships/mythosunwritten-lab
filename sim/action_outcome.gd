extends RefCounted
## What came of one atomic action: it happened, or it did not and this is why.
##
## Section 2.1's second sentence is that any action may fail with a returned
## reason, so there is no path out of `ActionEngine` that is not one of these and
## no failure that is a bare `false`. A refusal carries the same object a success
## does, with `ok` false and `reason` filled in; a caller that ignores the reason
## is throwing away the only thing the engine can tell it about a world it cannot
## see.
##
## `detail` is what the action observed or moved: how far a walk went, who heard
## a shout, what an examine saw, what a trade exchanged. It is a dictionary
## rather than a class per action because the set of actions is meant to grow and
## a new action must not need a new result type to be added.
class_name ActionOutcome

## Which action this answers for.
var action: String = ""

## Whether it happened.
var ok: bool = false

## Why it did not, or "" when it did. Never both empty and false: a refusal with
## no reason would be exactly the thing this class exists to prevent, and
## `failed()` is the only way to build one.
var reason: String = ""

## What happened, or what was seen.
var detail: Dictionary = {}


## It happened.
static func done(for_action: String, with: Dictionary = {}) -> ActionOutcome:
	var outcome := ActionOutcome.new()
	outcome.action = for_action
	outcome.ok = true
	outcome.detail = with
	return outcome


## It did not, and this is why. A blank reason is refused a blank: an unexplained
## refusal becomes "refused" rather than nothing at all.
static func failed(
	for_action: String, why: String, with: Dictionary = {}
) -> ActionOutcome:
	var outcome := ActionOutcome.new()
	outcome.action = for_action
	outcome.ok = false
	outcome.reason = "refused" if why.strip_edges() == "" else why
	outcome.detail = with
	return outcome


## One value out of the detail, or a default.
func got(key: String, fallback: Variant = null) -> Variant:
	return detail.get(key, fallback)


## One line, in the form the transcripts and the tests compare.
func line() -> String:
	if not ok:
		return "%s refused: %s" % [action, reason]
	return "%s ok%s" % [action, "" if _detail_line() == "" else " " + _detail_line()]


# The detail in a fixed order -- the dictionary's insertion order, which is the
# order the resolver wrote it in -- so two equal outcomes print equal lines.
func _detail_line() -> String:
	var written := PackedStringArray()
	for key in detail:
		written.append("%s=%s" % [key, Action._value_line(detail[key])])
	return " ".join(written)
