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
## Six are built here. `recorded()` and `plan()` are both fed choices written
## down in advance -- what a person's turns look like once they have been taken,
## and what stands in for a person in a headless test, because a screen is not a
## thing a simulation can have. They differ in what *being asked* does to the
## list: a recorded list is a queue and hands over its next entry on every call,
## while a plan is read at the position its character has actually reached and so
## cannot be spent by a question. `live()` is the person themselves rather than a
## stand-in for one: it reads a `LiveChoice` that whoever is driving writes into
## while the world runs, and answers null on every tick they have not chosen
## anything -- which is the same null a model mind returns while its call is
## outstanding, read the same way. `scripted()` wraps a rule that computes its
## choice from the world it is handed -- what a program's turns look like.
## `model()` hands the question to a `ModelMind`, which assembles what the
## character can see, writes it out as a prompt, puts it to a language model and
## reads the answer back as one action -- what a model's turns look like.
## `deliberate()` wraps any of those in a decider that will not answer for a
## stated number of ticks -- the scripted stand-in for a decision that takes
## arbitrarily long, and the reason a driver must read "no answer yet" as "the
## character waits" rather than as "stop the world", which is also exactly how
## `model()` answers while its call is outstanding. None is privileged:
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
##
## ## Driving a character is more than asking it
##
## `drive()` passes every character it drives through `CharacterUpkeep` before
## asking it anything, which is the same object `ControlLoop` passes every
## character it services through: the two stores the sheet declares for
## everybody -- what the character remembers and what it is after -- are
## maintained on a path that runs whatever is on `Character.decide`, and there is
## nothing here that could tell which is on it.
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
## the one at the index of how many actions the character has attempted, which the
## world counts in `ActionScene.actions_taken` -- a choice the catalogue refused
## among them, so an entry the engine cannot read costs the plan one line rather
## than stopping it where it stands. Nothing is
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


## A decision function whose answer is whatever the person driving has chosen.
##
## The seam this file has documented since it was written, filled. The same two
## arguments and the same one return as every function above it: what makes it
## the live one is not its shape -- its shape is the point -- but *when* its
## answer is decided, which is while the world is running rather than before it
## started. A `LiveChoice` is where the answer is put when it arrives; see
## sim/live_choice.gd.
##
## **Nothing here knows how a person chooses.** There is no key, no button, no
## pointer and no screen in this function or in the object it reads: whoever is
## driving builds an `Action` out of `ActionCatalog`'s own constructors and calls
## `LiveChoice.choose()`. That is the whole surface, and it is the same surface a
## rule and a model reach the engine through.
##
## **The world does not wait for it.** On every tick nobody has chosen anything
## it answers null -- exactly what `model()` answers while its call is
## outstanding and what `recorded()` answers when its list runs out -- and every
## driver already reads null as "nothing chosen": the character stands in the
## world with nothing committed and everybody else carries on being serviced in
## the same tick. So a person is simply a slower mind, and being slow is a thing
## the world already knows how to hold.
##
## **Being asked spends nothing.** The choice is read at the position its
## character has actually reached, exactly as `plan()` reads its list: the same
## action is offered back for as long as the world has not resolved one for that
## character, and it is only taken back once `ActionScene.actions_of` has moved
## on. That is what makes it survive a `ControlLoop` review -- a person asked
## what they want while their character is still walking has not thereby spent
## their next turn -- and what makes an interrupted walk something the character
## takes up again rather than something the person has to press twice.
##
## A choice the engine refuses has still been had: the count moves, the standing
## choice is taken back, and the person is asked for another one. That holds for
## the refusals the catalogue gives as much as for the ones the world gives, so a
## line the engine cannot read costs a person one turn rather than leaving the
## same unusable choice standing for the rest of the run.
static func live(chosen: LiveChoice) -> Callable:
	# Which choice was last read, and what its character had carried out at the
	# moment it was read. Two numbers, kept beside the function for the same
	# reason `recorded()`'s cursor is kept beside that one.
	var reading := [0, 0]
	return func(scene: ActionScene, actor: Combatant) -> Action:
		if chosen == null or scene == null or actor == null:
			return null
		var standing := chosen.standing()
		if standing == null:
			return null
		var done := scene.actions_of(actor.id)
		if chosen.serial != reading[0]:
			# A choice this function has not read before: note where its
			# character stood when it arrived, and offer it.
			reading[0] = chosen.serial
			reading[1] = done
		elif done > reading[1]:
			# The world has resolved an action for this character since the
			# choice was made, so the choice has been had -- whether the engine
			# carried it out or refused it. The person chooses again, and until
			# they do their character waits.
			chosen.carried_out += 1
			chosen.withdraw()
			return null
		chosen.offered += 1
		return standing


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


## A decision function whose mind is a language model.
##
## The same two arguments, the same one return, and the same nothing-else: a
## `ModelMind` is asked what its character does next, and whatever it says is
## handed back if it is an action and dropped if it is not. This function is the
## whole of the seam between the model layer and everything else, and it is four
## lines long for the reason `scripted()` above it is four lines long -- there is
## nothing for it to do but call and check.
##
## What makes it worth a factory of its own rather than `scripted(mind.answer_for)`
## is nothing about privilege and everything about being able to say where the
## seam is. A driver cannot tell the two apart, and neither can the engine: the
## `Callable` this returns has the same signature as the three above it, and a
## model's choice reaches `ActionEngine.resolve` as an `Action` like any other,
## to be refused with the same sentence when the world will not allow it.
##
## The mind answers null while it is waiting for the model, which is the same
## null a recorded person out of choices returns and is read the same way: the
## character stands in the world and everybody else carries on. Nothing anywhere
## in this file waits for a model, and nothing in `ControlLoop` does either.
static func model(mind: ModelMind) -> Callable:
	return func(scene: ActionScene, actor: Combatant) -> Action:
		var next: Variant = mind.answer_for(scene, actor)
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
## Before each choice the character is serviced by `CharacterUpkeep`, exactly as
## `ControlLoop` services it: the world closes the goals its own state says are
## finished, and the character takes in its surroundings. That is not a second
## way of doing it -- it is the same object, called at the same point relative to
## the decision function, so a character driven here accrues a memory and has its
## goals closed exactly as one serviced by the loop does. One is handed in by a
## caller that keeps its own -- a run watching its characters with an
## `ObservationTrail` -- and one is made here otherwise, which costs nothing
## because under `drive()` one call is one resolution and so every call is due a
## look anyway.
##
## Returns one row per action taken: `{"chose": Action, "got": ActionOutcome}`.
## It stops early when the decision function returns null, which is how a
## recorded person's list of choices ends.
static func drive(
	scene: ActionScene, actor: Combatant, steps: int = 1,
	upkeep: CharacterUpkeep = null
) -> Array:
	var taken := []
	var sheet := _sheet_of(actor)
	if sheet == null or not sheet.decide.is_valid():
		return taken
	var serving := CharacterUpkeep.new() if upkeep == null else upkeep
	for _step in steps:
		serving.serve(scene, actor)
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
