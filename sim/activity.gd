extends RefCounted
## What one character is doing right now, and how long it has been doing it.
##
## Section 2.2's sentence -- "while an action is in progress the agent
## re-evaluates at some frequency" -- needs an action to be a thing that is *in
## progress*, and an `Action` is not: it is a choice, complete the moment it is
## made, with no duration and no history. This is the choice once it has been
## committed to: the same `Action`, plus the tick it began on, the ticks it costs
## and the ticks it has left.
##
## Nothing here decides anything and nothing here resolves anything. It is the
## bookkeeping `ControlLoop` keeps per character, split out because "what a
## character is doing" is a thing a report prints and a test reads, not a private
## triple of dictionaries.
##
## **Time is counted in ticks and in nothing else.** There is no wall clock here,
## no seconds and no frame count: `began`, `occupies` and `remaining` are all
## counts of ticks out of `ActionScene.tick`, so a run is the same length however
## fast or slow the machine it runs on is.
class_name Activity

## The choice being carried out.
var action: Action = null

## The tick it was committed on.
var began: int = 0

## How many ticks carrying it out costs, all told.
var occupies: int = 1

## How many of those are left. Zero means the span is over and the action is due
## to be resolved.
var remaining: int = 0


## Commit to an action for a span of ticks, starting now.
static func begun(chosen: Action, at_tick: int, for_ticks: int) -> Activity:
	var doing := Activity.new()
	doing.action = chosen
	doing.began = at_tick
	doing.occupies = maxi(1, for_ticks)
	doing.remaining = doing.occupies
	return doing


## How many ticks it has been running at a given tick.
func elapsed(at_tick: int) -> int:
	return maxi(0, at_tick - began)


## Whether the span is over.
func is_done() -> bool:
	return remaining <= 0


## Spend one tick of the span. Returns whether that finished it.
func spend() -> bool:
	remaining = maxi(0, remaining - 1)
	return is_done()


## One line, in the form the transcripts and the tests compare.
func line() -> String:
	return "%s %d/%dt" % [
		"nothing" if action == null else action.line(),
		occupies - remaining, occupies,
	]
