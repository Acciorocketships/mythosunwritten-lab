extends RefCounted
## The several goals one character holds at once, and the four things section 10
## says can happen to them.
##
## Section 10's sentence is "goals -- structured intent over time; completable,
## replaceable, reprioritizable", held over two horizons at the same time. This
## is that sentence with a body:
##
##   * **several at once** -- `held` is a list, not a field, and `open()` hands
##     back every unfinished one in the order it is pressing;
##   * **completable** -- `close()` finishes one and it stays in the set,
##     finished, with how it finished written on it. A goal is not deleted when
##     it is met, because what a character has already done is worth as much to
##     the next decision as what it has not;
##   * **replaceable** -- `replace()` puts a new goal in an old one's place,
##     keeping its number and how pressing it was, so a character that has
##     changed its mind about what it wants has not renumbered everything it
##     wants;
##   * **reprioritisable** -- `reprioritise()` writes one goal's `priority`, and
##     the order `open()` hands them back in changes with it.
##
## ## It holds no goal of its own
##
## Nothing here declares a goal. A set starts empty, and every goal in it was put
## there by whoever set the scene up. A shipped run's starting goals are
## therefore scenario setup, in the file that stages the scenario, and there is
## no table of goals anywhere in the machinery -- which is the whole of "nothing
## hard-codes a story" as far as this layer is concerned.
##
## ## Numbering
##
## Every goal added is given the next number, from one, and keeps it for as long
## as the set lives -- through being closed, through being replaced. The number
## is how a character names a goal when it closes one itself, so it has to be
## stable and short; the alternative, naming a goal by its words, would make a
## character's own typing decide which goal it had finished.
class_name GoalSet

## Every goal this character holds, open and closed, in the order they were
## added.
var held: Array[Goal] = []

## Every time this character was refused a closing of its own, in order:
## `{"tick": int, "goal": Goal, "why": String}`, where `goal` is null when the
## number named nothing open.
##
## It is kept here, on the character's own set, for the reason the closings are
## kept on the goals themselves: a refusal is something that happened to this
## character, and whoever was deciding for it at the time is not the sort of
## thing the record should depend on. `GoalCheck.close_by_hand()` writes it,
## whoever called that.
var refusals: Array[Dictionary] = []

var _next_id: int = 1


## A set with these goals in it, in order.
static func of(goals: Array = []) -> GoalSet:
	var set_of := GoalSet.new()
	for goal in goals:
		set_of.add(goal)
	return set_of


## Add one goal and give it its number.
func add(goal: Goal) -> Goal:
	if goal == null:
		return null
	goal.id = _next_id
	_next_id += 1
	held.append(goal)
	return goal


## The goal with a number, or null.
func goal_of(number: int) -> Goal:
	for goal in held:
		if goal.id == number:
			return goal
	return null


## Every unfinished goal, most pressing first, and within one priority in the
## order they were added.
func open() -> Array[Goal]:
	var found: Array[Goal] = []
	for goal in held:
		if not goal.closed:
			found.append(goal)
	found.sort_custom(func(left: Goal, right: Goal) -> bool:
		if left.priority != right.priority:
			return left.priority < right.priority
		return left.id < right.id)
	return found


## Every finished goal, in the order they finished.
func done() -> Array[Goal]:
	var found: Array[Goal] = []
	for goal in held:
		if goal.closed:
			found.append(goal)
	found.sort_custom(func(left: Goal, right: Goal) -> bool:
		return left.closed_at < right.closed_at)
	return found


## Every unfinished goal over one horizon, most pressing first.
func open_over(horizon: String) -> Array[Goal]:
	var found: Array[Goal] = []
	for goal in open():
		if goal.horizon == horizon:
			found.append(goal)
	return found


## Finish one goal, with how it finished and when. False when there is no such
## goal or it was finished already.
func close(number: int, how: String, at_tick: int = -1) -> bool:
	var goal := goal_of(number)
	if goal == null or goal.closed:
		return false
	goal.closed = true
	goal.closed_by = how
	goal.closed_at = at_tick
	return true


## Write down that this character was refused a closing of its own, and why.
##
## Called by `GoalCheck.close_by_hand()` and by nothing else: which closings are
## refused is that file's rule, and this is only where the answer is kept.
func refuse(goal: Goal, why: String, at_tick: int = -1) -> void:
	refusals.append({"tick": at_tick, "goal": goal, "why": why})


## Put a new goal in an old one's place, keeping the old one's number and how
## pressing it was. Null when there is no such goal.
##
## The old goal is gone from the set: replacing is not closing, because a goal a
## character has given up on was never finished and recording it as finished
## would be a lie the next decision reads.
func replace(number: int, with: Goal) -> Goal:
	if with == null:
		return null
	for at in held.size():
		if held[at].id != number:
			continue
		with.id = number
		with.priority = held[at].priority
		held[at] = with
		return with
	return null


## Write one goal's priority. False when there is no such goal.
func reprioritise(number: int, pressing: int) -> bool:
	var goal := goal_of(number)
	if goal == null:
		return false
	goal.priority = pressing
	return true


## How many goals are held, open and closed.
func size() -> int:
	return held.size()


## Whether this character is trying to do anything at all.
func is_empty() -> bool:
	return open().is_empty()


## Every goal in the set, one line each, open ones first. What a report prints.
func lines() -> PackedStringArray:
	var written := PackedStringArray()
	for goal in open():
		written.append(goal.line())
	for goal in done():
		written.append(goal.line())
	return written
