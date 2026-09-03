extends RefCounted
## Whether a goal is finished, answered out of the engine's own state.
##
## The rule this file exists to keep is one sentence: **the model chooses, and
## the engine answers whether a goal is met.** A character that could declare its
## own goals finished would be marking its own homework, and a run in which every
## goal closes because somebody said so is a run that measures nothing. So for
## every goal that names something the world holds, the answer is read off the
## world here -- a position compared with a position, an inventory looked in, the
## engine's own record of a trade -- and the character is never asked.
##
## ## Where it genuinely cannot answer, it says so
##
## One kind of goal, `Goal.UNWRITTEN`, is the character's own words for something
## it wants that the engine holds no state for: being thought well of, having
## learned what happened somewhere, having seen enough of a place. There is no
## field anywhere in the simulation that is any of those, and inventing a proxy
## for one -- calling "seen enough" a distance from a spawn point -- would be this
## file making up the answer rather than reading it.
##
## There is a sentiment number now -- `RelationshipGraph.sentiment`, one per
## ordered pair -- and "be thought well of here" is still not it. It names no
## target and no threshold: well thought of by whom, and how well. Picking either
## would be this file inventing the answer exactly as a proxy would, and the
## threshold in particular is section 6's, which is the ownership item's business
## and not a goal check's.
##
## So it does not answer those, and `answers()` says which kind is which. A goal
## the engine answers is closed here and nowhere else; a goal it does not is
## closed by the character itself, through the one tool the prompt offers for it,
## and the transcript of a run shows the two closing by different hands. A
## character trying to close a goal of the first sort is refused -- see
## `ModelMind` -- with the reason that the world already answers it.
##
## ## Nothing here is a threshold of its own
##
## Where a comparison needs a number, the number is either the goal's own
## (`amount`, `span` -- what the character was set) or the engine's own
## (`ActionEngine.ARRIVE`, the gap it counts as having got somewhere;
## `ActionEngine.REACH`, the gap it counts as being beside something). There is
## no third number invented in this file, because a goal answered against a
## threshold nobody else uses would be answered against a private rule.
class_name GoalCheck

## The kinds the engine can answer, because each names something it holds.
const ANSWERED := [
	Goal.BE_AT, Goal.HOLD, Goal.MONEY, Goal.TRADED, Goal.APART_FROM,
	Goal.FELLED, Goal.STANDING,
]

## What is said in the run about a goal only the character can close.
const CLOSED_BY_HAND := "the character said so"

## Why a character is refused when it tries to close a goal the world answers.
const NOT_YOURS_TO_CLOSE := "the world answers this one"

## Why a character is refused when it names a goal that is not open.
const NO_SUCH_GOAL := "there is no such goal open"

## The two hands a goal can close by, named here rather than in any one driver's
## file because both hands are the same two whoever is deciding.
const BY_THE_WORLD := "the world"
const BY_THE_CHARACTER := "the character"


## Which hand closed a goal, read off how it closed.
static func hand_of(how: String) -> String:
	return BY_THE_CHARACTER if how == CLOSED_BY_HAND else BY_THE_WORLD


## Whether the engine can answer this goal at all.
static func answers(goal: Goal) -> bool:
	return goal != null and ANSWERED.has(goal.kind)


## Whether a goal is finished, and how -- in the engine's own reading of its own
## state. `{"met": bool, "how": String}`.
##
## A goal the engine does not answer comes back unmet with the reason, which is
## not a failure: it is the honest answer, and the character closes that one.
static func met(goal: Goal, scene: ActionScene, actor: Combatant) -> Dictionary:
	if goal == null or scene == null or actor == null:
		return _no("there is nothing to read")
	if not answers(goal):
		return _no("nothing in the world answers this one")
	match goal.kind:
		Goal.BE_AT:
			return _be_at(goal, scene, actor)
		Goal.HOLD:
			return _hold(goal, actor)
		Goal.MONEY:
			return _money(goal, actor)
		Goal.TRADED:
			return _traded(goal, scene, actor)
		Goal.APART_FROM:
			return _apart_from(goal, scene, actor)
		Goal.FELLED:
			return _felled(goal, scene)
		Goal.STANDING:
			return _standing(goal, actor)
	return _no("nothing in the world answers this one")


## Close every open goal the world now says is finished, and hand back one row
## per goal that closed: `{"goal": Goal, "how": String}`.
##
## Called wherever a character is about to be asked what it wants to do next, so
## that what it is shown is what it still wants and not what it wanted before it
## got there.
static func settle(
	goals: GoalSet, scene: ActionScene, actor: Combatant
) -> Array[Dictionary]:
	var closed: Array[Dictionary] = []
	if goals == null:
		return closed
	for goal in goals.open():
		if not answers(goal):
			continue
		var answer := met(goal, scene, actor)
		if not bool(answer["met"]):
			continue
		if goals.close(goal.id, String(answer["how"]), scene.tick):
			closed.append({"goal": goal, "how": String(answer["how"])})
	return closed


## Close one goal by the character's own hand, and say what came of it:
## `{"closed": bool, "goal": Goal, "how": String, "why": String}`.
##
## This is the whole of a character closing something for itself, and it is here
## rather than in any driver's file because the rule it keeps is this file's:
## a goal the world answers is not the character's to close. The model prompt's
## `done` tool is one caller of it; a human-input layer would be another, and
## neither can be given a different answer than the other because there is only
## one answer to give.
##
## Three ways it can go, and all three are written down where anybody can read
## them back:
##
##   * **no such goal** -- the number names nothing open. Nothing closes, and the
##     refusal is kept.
##   * **the world answers it** -- refused with `NOT_YOURS_TO_CLOSE` as the
##     reason, so a character cannot mark work of its own finished when there is
##     a fact of the matter. The refusal is kept on the character's own goal set.
##   * **the character's own words** -- the one kind the world holds no state for
##     closes, with `CLOSED_BY_HAND` written on it, which is what says by whose
##     hand it closed.
static func close_by_hand(
	goals: GoalSet, number: int, at_tick: int = -1
) -> Dictionary:
	if goals == null:
		return _refused(null, NO_SUCH_GOAL)
	var goal := goals.goal_of(number)
	if goal == null or goal.closed:
		goals.refuse(null, NO_SUCH_GOAL, at_tick)
		return _refused(null, NO_SUCH_GOAL)
	if answers(goal):
		goals.refuse(goal, NOT_YOURS_TO_CLOSE, at_tick)
		return _refused(goal, NOT_YOURS_TO_CLOSE)
	if not goals.close(goal.id, CLOSED_BY_HAND, at_tick):
		return _refused(goal, NO_SUCH_GOAL)
	return {"closed": true, "goal": goal, "how": CLOSED_BY_HAND, "why": ""}


## Every goal of a set that has closed, in the order they closed, with when and
## how and by whose hand: `{"tick", "goal", "how", "by"}`.
##
## Read off the goals themselves rather than out of a list somebody kept while
## closing them, so that a closing cannot be recorded in one place and missed in
## another, and so a run prints the same row whichever hand made it.
static func closings_of(goals: GoalSet) -> Array[Dictionary]:
	var written: Array[Dictionary] = []
	if goals == null:
		return written
	for goal in goals.done():
		written.append({
			"tick": goal.closed_at, "goal": goal, "how": goal.closed_by,
			"by": hand_of(goal.closed_by),
		})
	return written


static func _refused(goal: Goal, why: String) -> Dictionary:
	return {"closed": false, "goal": goal, "how": "", "why": why}


# --- One kind each ---------------------------------------------------------


# Being somewhere: at a position within the gap the engine counts as having
# arrived, or beside a character within the gap it counts as being in reach of
# one. Both numbers are the engine's own.
static func _be_at(goal: Goal, scene: ActionScene, actor: Combatant) -> Dictionary:
	var at: Variant = goal.target_at()
	if at != null:
		var to: Vector2 = at
		var gap := Vector2(actor.x - to.x, actor.z - to.y).length()
		return _answer(gap <= ActionEngine.ARRIVE,
			"%.1f from (%.1f, %.1f)" % [gap, to.x, to.y])
	var thing: Variant = scene.thing_of(goal.target_id())
	if thing == null:
		return _no("#%d is no longer in the world" % goal.target_id())
	var there := ActionScene.position_of(thing)
	var span := Vector2(actor.x - there.x, actor.z - there.y).length()
	return _answer(span <= ActionEngine.REACH,
		"#%d is %.1f away" % [goal.target_id(), span])


# Carrying a named thing: looked for in the pack the engine moves things in and
# out of, under the name that pack gives it.
static func _hold(goal: Goal, actor: Combatant) -> Dictionary:
	var wanted := String(goal.param("item", ""))
	var pack := ActionScene.inventory_of(actor)
	if pack == null or wanted == "":
		return _no("there is no pack to look in")
	for entry in pack.carried:
		if ObservationTrail.name_of_entry(entry) == wanted:
			return _yes("%s is in the pack" % wanted)
	return _no("%s is not in the pack" % wanted)


static func _money(goal: Goal, actor: Combatant) -> Dictionary:
	var pack := ActionScene.inventory_of(actor)
	if pack == null:
		return _no("there is no pack to look in")
	var wanted := int(goal.param("amount", 0))
	return _answer(pack.money >= wanted, "%d money in the pack" % pack.money)


# A trade carried out: read off the engine's own record of the trades it has
# honoured, which is written on the one path a trade goes through.
static func _traded(goal: Goal, scene: ActionScene, actor: Combatant) -> Dictionary:
	var with_whom := goal.target_id()
	for row in scene.trades:
		var between := [int(row["from"]), int(row["to"])]
		if not between.has(actor.id):
			continue
		if with_whom != ActionCatalog.NOBODY and not between.has(with_whom):
			continue
		return _yes("traded with #%d at tick %d" % [
			int(row["from"]) if int(row["to"]) == actor.id else int(row["to"]),
			int(row["tick"]),
		])
	return _no("no trade of its has been honoured")


static func _apart_from(goal: Goal, scene: ActionScene, actor: Combatant) -> Dictionary:
	var thing: Variant = scene.thing_of(goal.target_id())
	if thing == null:
		return _yes("#%d is no longer in the world" % goal.target_id())
	var there := ActionScene.position_of(thing)
	var span := Vector2(actor.x - there.x, actor.z - there.y).length()
	return _answer(span >= float(goal.param("span", 0)),
		"%.1f apart from #%d" % [span, goal.target_id()])


static func _felled(goal: Goal, scene: ActionScene) -> Dictionary:
	var who := scene.actor_of(goal.target_id())
	if who == null:
		return _yes("#%d is no longer in the world" % goal.target_id())
	return _answer(who.piece != null and who.piece.health <= 0,
		"#%d is standing with %d hit points" % [
			goal.target_id(), 0 if who.piece == null else who.piece.health,
		])


static func _standing(goal: Goal, actor: Combatant) -> Dictionary:
	var sheet := _sheet_of(actor)
	if sheet == null:
		return _no("it keeps no sheet")
	return _answer(sheet.status() >= int(goal.param("amount", 0)),
		"its standing is %d" % sheet.status())


# --- The furniture ---------------------------------------------------------


static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


static func _answer(is_met: bool, how: String) -> Dictionary:
	return {"met": is_met, "how": how}


static func _yes(how: String) -> Dictionary:
	return {"met": true, "how": how}


static func _no(how: String) -> Dictionary:
	return {"met": false, "how": how}
