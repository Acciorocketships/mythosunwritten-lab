extends RefCounted
## What the person driving a character has chosen, and has not yet had carried
## out.
##
## Section 1's "no preferential treatment" principle puts the whole difference
## between a character a person drives and one a program drives on the decision
## function. `DecisionSource.recorded`, `plan` and `scripted` are all fed their
## answers *before* the run starts, which is what a headless test needs and is
## not what a person is: a person answers while the world is running, at a moment
## nobody can write down in advance. This is where that answer is put when it
## arrives, and `DecisionSource.live()` is the decision function that reads it.
##
## ## It is a holder and nothing else
##
## There is no rule here about distance, reach, cost or possibility, and no
## opinion about what a good choice would be -- the same discipline
## `sim/decision_source.gd` keeps, for the same reason. There is also nothing in
## it about *how* the choice arrived: no key, no button, no pointer, no screen.
## Whoever is driving builds an `Action` out of the catalogue and calls
## `choose()`; what made them press something is their business and cannot be
## seen from here.
##
## ## What "not yet carried out" means
##
## A choice stands until the world has actually resolved one action for the
## character it was made for -- that is `serial`, and the reading of it is in
## `DecisionSource.live()`. Being *asked* spends nothing, which matters for
## exactly the reason it matters for `DecisionSource.plan`: `ControlLoop` asks
## again every few ticks while an action is running, and a person asked what they
## want while their character is still walking has not thereby spent their next
## turn.
##
## The counters are diagnostics and nothing reads them to decide anything: how
## many choices have been made, how many times a decision function handed the
## standing one over, and how many of them the world got through.
class_name LiveChoice

## What has been chosen and not yet carried out, or null for "nothing yet".
##
## Null is the ordinary state of this object: a person is not choosing on most
## ticks, and a decision function reading null returns null, which every driver
## already reads as "the character waits in the world".
var action: Action = null

## Which choice this is. Bumped whenever what is standing changes -- a new
## choice, or the withdrawal of one that has been carried out -- so a decision
## function can tell a fresh choice from the one it read last time without
## comparing actions.
var serial: int = 0

## How many choices the person driving has made.
var made: int = 0

## How many times a decision function has handed the standing choice over.
var offered: int = 0

## How many standing choices the world has actually carried out.
var carried_out: int = 0


## Choose what to do next. Whatever was standing is replaced.
##
## Anything that is not an `Action` clears the choice instead of standing as a
## malformed one, which is the same care `DecisionSource.scripted` takes with
## what a rule returns.
func choose(what: Variant) -> void:
	action = what if what is Action else null
	serial += 1
	if action != null:
		made += 1


## Take the standing choice back, so the character waits again. What the decision
## function calls once the world has carried the choice out, and what somebody
## changing their mind about acting at all would call.
func withdraw() -> void:
	if action == null:
		return
	action = null
	serial += 1


## The choice standing right now, or null.
func standing() -> Action:
	return action


## Whether nothing is chosen -- the state a person's character spends most of its
## ticks in, and the one the world reads as "waits in the world".
func waiting() -> bool:
	return action == null


## One line, in the form the transcripts and the tests compare.
func line() -> String:
	return "nothing chosen" if action == null else action.line()
