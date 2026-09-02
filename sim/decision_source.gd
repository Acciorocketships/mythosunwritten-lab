extends RefCounted
## The ways a character's next action gets chosen, and the one way it gets
## resolved.
##
## Section 1's "no preferential treatment" principle says that the only
## difference between a character a person drives and a character a program
## drives is the decision function -- same inventory, same action set, same
## combat rules. `Character.decide` is where that one difference lives, and this
## file is what goes in it.
##
## A decision function is a `Callable` taking the world and the character it is
## choosing for, and returning one `Action` or null for "nothing further":
##
##     func(scene: ActionScene, actor: Combatant) -> Action
##
## Four are built here. `recorded()` and `plan()` are both fed choices written
## down in advance -- what a person's turns look like once they have been taken,
## and what stands in for a person in a headless test, because a screen is not a
## thing a simulation can have. They differ in what *being asked* does to the
## list: a recorded list is a queue and hands over its next entry on every call,
## while a plan is read at the position its character has actually reached and so
## cannot be spent by a question. `scripted()` wraps a rule that computes its
## choice from the world it is handed -- what a program's turns look like.
## `deliberate()` wraps any of those in a decider that will not answer for a
## stated number of ticks -- the scripted stand-in for a decision that takes
## arbitrarily long, and the reason a driver must read "no answer yet" as "the
## character waits" rather than as "stop the world". None is privileged:
## `drive()` calls whichever is on the sheet, hands what comes back to
## `ActionEngine.resolve`, and cannot tell which it called.
##
## ## Which of the two written-down shapes to use
##
## It is a question about the *driver*, not about who is driving. Under `drive()`
## one call is one resolution, so the two are the same thing and `recorded()` is
## the simpler of them -- it reads nothing at all, not even the world it is
## handed. Under a driver that asks more than once per resolution only `plan()`
## survives: `ControlLoop` calls a decision function again every
## `ControlLoop.REVIEW_EVERY` ticks to ask whether the character has changed its
## mind, a queue answers that question by handing over its next entry, the
## continue bias then keeps what was already running, and the entry is gone. The
## same ten choices on the checked-in scenario: 4 of 10 taken as a queue, 10 of
## 10 as a plan.
##
## Nothing here resolves anything. This file contains no rule about distance,
## reach, cost or possibility -- it chooses, and the engine answers.
class_name DecisionSource


## A decision function fed choices written down in advance, as a queue.
##
## The choices are taken in order, one per call, and null comes back when they
## run out -- so a recorded person stops rather than repeating their last move.
##
## One call is one choice, which is exactly right under `drive()`, where one call
## is also one resolution, and wrong under a driver that asks more than once per
## resolution -- `plan()` below is the same list for those. It is kept beside the
## plan rather than replaced by it for three reasons: it is the shape the drain is
## measured against, so the measurement needs it to exist; it is the one decision
## function that reads neither of its two arguments, which is what makes the
## shared signature demonstrable; and the two genuinely differ on an interruption,
## where a queue treats an abandoned action as spent and a plan treats it as still
## wanted -- both of which are things somebody might mean.
static func recorded(choices: Array) -> Callable:
	var cursor := [0]
	return func(_scene: ActionScene, _actor: Combatant) -> Action:
		if cursor[0] >= choices.size():
			return null
		var next: Variant = choices[cursor[0]]
		cursor[0] += 1
		return next if next is Action else null


## A decision function fed a plan written down in advance.
##
## The same list as `recorded()`, read the other way round: the choice offered is
## the one at the index of how many actions the character has actually had
## carried out, which the world counts in `ActionScene.actions_taken`. Nothing is
## consumed by being asked, so a driver may ask as often as it likes and get the
## same answer until the world changes under it:
##
##   * **asked again while the action is still running** it offers that same
##     action back, which is what somebody who has not changed their mind says --
##     and what makes a `ControlLoop` review line read "wanted the same thing";
##   * **asked again after an action was abandoned part-way through** it offers
##     that action again, because an interrupted walk was not taken and so is
##     still what was planned;
##   * **asked once an action has been resolved** it moves on to the next entry.
##
## This is the shape the eventual human-input layer needs, and it needs it for the
## first of those: a person asked what they want while their character is still
## walking has not thereby spent their next turn. It reads the world for that
## position and for nothing else -- no distance, no reach, no possibility -- and a
## driver cannot tell it from a rule.
##
## Null comes back when the plan runs out, so a person stops rather than repeating
## their last move.
static func plan(choices: Array) -> Callable:
	return func(scene: ActionScene, actor: Combatant) -> Action:
		if scene == null or actor == null:
			return null
		var at := scene.actions_of(actor.id)
		if at < 0 or at >= choices.size():
			return null
		var next: Variant = choices[at]
		return next if next is Action else null


## A decision function that works its choice out from the world it is given.
##
## The rule is handed the same two arguments a recorded function ignores, so the
## two have one signature and one return; anything the rule returns that is not
## an action becomes null, which the driver reads as "nothing further" rather
## than passing a malformed choice to the engine.
static func scripted(rule: Callable) -> Callable:
	return func(scene: ActionScene, actor: Combatant) -> Action:
		var next: Variant = rule.call(scene, actor)
		return next if next is Action else null


## A decision function that takes its time.
##
## Section 12 requires that the simulation never blocks on a decision -- "the
## character waits in-world instead of lagging the game" -- and the only honest
## way to show that without a language model is to have a scripted decider be
## *slow on purpose*. This is that stand-in: it wraps another decision function
## and will not answer for `ticks` ticks after it is first asked.
##
## **Slowness is counted in ticks, never in time.** The wrapper reads
## `ActionScene.tick` and nothing else -- no clock, no seconds, no measurement of
## how long the inner function took. That is not a limitation of the stand-in, it
## is the shape the eventual model layer has to take too: the world advances by
## ticks, so "not ready yet" can only mean "not ready as of this tick".
##
## While it is thinking it returns null, which every driver reads the same way --
## nothing chosen -- so the character stands in the world and everybody else
## carries on. Once the ticks have passed it asks the function it wraps, answers
## with whatever that says, and starts thinking again the next time it is asked.
static func deliberate(inner: Callable, ticks: int) -> Callable:
	var started := [-1]
	return func(scene: ActionScene, actor: Combatant) -> Action:
		var now := 0 if scene == null else scene.tick
		if started[0] < 0:
			started[0] = now
		if now - started[0] < maxi(0, ticks):
			return null
		started[0] = -1
		var next: Variant = inner.call(scene, actor)
		return next if next is Action else null


## Ask a character for its next action and resolve it, up to a number of times.
##
## The whole of what a driver does, and the reason a person and a program are
## interchangeable: the decision function is read off the character's own sheet,
## called, and its answer handed to the engine. There is no branch here on what
## sort of function it is, and nothing to branch on -- a `Callable` is a
## `Callable`.
##
## Returns one row per action taken: `{"chose": Action, "got": ActionOutcome}`.
## It stops early when the decision function returns null, which is how a
## recorded person's list of choices ends.
static func drive(scene: ActionScene, actor: Combatant, steps: int = 1) -> Array:
	var taken := []
	var sheet := _sheet_of(actor)
	if sheet == null or not sheet.decide.is_valid():
		return taken
	for _step in steps:
		var chosen: Variant = sheet.decide.call(scene, actor)
		if not (chosen is Action):
			break
		taken.append({
			"chose": chosen,
			"got": ActionEngine.resolve(scene, actor, chosen),
		})
	return taken


## What a run of `drive()` did, one line per action: what was chosen, and what
## came of it. What the transcripts print and what the tests compare.
static func transcript(taken: Array) -> PackedStringArray:
	var written := PackedStringArray()
	for row in taken:
		written.append("%s -> %s" % [row["chose"].line(), row["got"].line()])
	return written


# The character sheet behind a combatant, or null for anything that has none.
static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
