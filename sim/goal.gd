extends RefCounted
## One thing a character is trying to do: section 10's structured intent, one
## entry of it.
##
## Section 10 gives a character *goals*, plural, "completable, replaceable,
## reprioritizable", over two horizons: long-term ones that persist -- wealth,
## powerful items, standing, exploring, staying alive -- and short-term ones that
## are immediately actionable -- go somewhere, defeat someone, loot something,
## sell, trade, escape. Until now the sheet carried one free-text line called
## `goal` and nothing read it. This is that line's replacement, and there are
## several of these on a sheet at once (`GoalSet`).
##
## ## A goal is a wanted state of the world, never a way of getting there
##
## Every kind below names something the world could be like: a place a character
## is at, a thing it is carrying, an amount of money, a trade that has happened,
## a rival no longer standing. None of them names a route, a step, an order of
## steps, or an action out of `ActionCatalog`. That is deliberate and it is the
## line between this file and a quest: a quest says what to do, and a goal says
## only what would be true if it were done. What a character does about a goal is
## the character's business and the model's answer, and this file has no opinion
## about it.
##
## ## Who says a goal is finished
##
## Whoever can. Seven of the eight kinds name something the engine holds -- a
## position, an inventory, a money count, the trades the engine wrote down, a
## standing, whether a character is still in the world -- and for those the
## engine answers, in `GoalCheck`, out of its own state. The eighth, `UNWRITTEN`,
## is a goal in the character's own words that names nothing the engine holds:
## "be thought well of in this market", "learn what happened at the ford". There
## is no state in the engine that is being thought well of, so nothing here can
## honestly answer it, and it is closed by the character itself. That asymmetry
## is stated rather than hidden: `GoalCheck.answers()` says which is which, and a
## character trying to close a goal the engine answers is refused.
##
## ## What is not here
##
## No reward, no score, no giver and no chain. A goal that had a reward attached
## would be a quest with the word filed off, and section 6 puts quests in the
## territory milestone where they emerge from situations rather than from a
## table. Nothing in this file, `GoalSet` or `GoalCheck` declares a goal of its
## own either: goals are made by whoever sets a scene up, which is why the only
## files under `sim/` that construct one are the scripted scenarios.
class_name Goal

## The two horizons of section 10. A short goal is immediately actionable; a long
## one persists and may outlive many short ones.
const SHORT := "short"
const LONG := "long"

## The kinds whose wanted state is something the engine holds.
##
## `target` is an id or a position, exactly as an action's `target` is, so a goal
## and an action name the same things the same way.
const BE_AT := "be_at"
const HOLD := "hold"
const MONEY := "money"
const TRADED := "traded"
const APART_FROM := "apart_from"
const FELLED := "felled"
const STANDING := "standing"

## The kind whose wanted state is not anything the engine holds: the character's
## own words for something it wants, closed by the character and by nobody else.
const UNWRITTEN := "unwritten"

## Every kind, for anything that wants to walk them.
const KINDS := [
	BE_AT, HOLD, MONEY, TRADED, APART_FROM, FELLED, STANDING, UNWRITTEN,
]

## What a goal that has not been given a number holds.
const UNNUMBERED := 0


## Which goal this is, within the one set that holds it. Given out by `GoalSet`
## when the goal is added, and the number the character names when it closes one
## itself.
var id: int = UNNUMBERED

## `SHORT` or `LONG`.
var horizon: String = SHORT

## One of `KINDS`.
var kind: String = UNWRITTEN

## What the kind needs: `target`, `item`, `amount`, `span`, `text`. Empty for a
## kind that needs nothing.
var params: Dictionary = {}

## The character's own words for this goal, or "" to let `said()` write the
## wanted state out of the kind and its parameters.
var text: String = ""

## How pressing it is: lower is more pressing, and `GoalSet.open()` hands them
## back in this order. Reprioritising is writing this number.
var priority: int = 0

## Whether it is finished.
var closed: bool = false

## How it finished, in the words of whoever closed it: the engine's own reading
## of its own state, or the character saying so.
var closed_by: String = ""

## Which tick it closed on, or -1.
var closed_at: int = -1


## A goal of any kind.
static func of(
	of_kind: String, with: Dictionary = {}, said_as: String = "",
	over: String = SHORT, pressing: int = 0
) -> Goal:
	var goal := Goal.new()
	goal.kind = of_kind
	goal.params = with.duplicate(true)
	goal.text = said_as
	goal.horizon = LONG if over == LONG else SHORT
	goal.priority = pressing
	return goal


## A goal in the character's own words that names nothing the engine holds.
static func unwritten(said_as: String, over: String = LONG, pressing: int = 0) -> Goal:
	return Goal.of(UNWRITTEN, {}, said_as, over, pressing)


## One parameter, or a default.
func param(key: String, if_absent: Variant = null) -> Variant:
	return params.get(key, if_absent)


## The id this goal is about, or `ActionCatalog.NOBODY`. A `target` holding a
## position is about nobody.
func target_id() -> int:
	var target: Variant = param("target")
	return int(target) if target is int else ActionCatalog.NOBODY


## The position this goal is about, or null.
func target_at() -> Variant:
	var target: Variant = param("target")
	return target if target is Vector2 else null


## The wanted state in words: the character's own if it gave any, and otherwise
## the state written out of the kind and its parameters.
##
## This is what a context carries. It says what would be true if the goal were
## finished and nothing whatever about how to make it true -- there is no verb of
## `ActionCatalog` in any branch below, on purpose.
func said() -> String:
	if text != "":
		return text
	match kind:
		BE_AT:
			var at: Variant = target_at()
			return "be at (%.1f, %.1f)" % [at.x, at.y] if at != null \
				else "be beside #%d" % target_id()
		HOLD:
			return "be carrying %s" % String(param("item", ""))
		MONEY:
			return "be carrying %d money or more" % int(param("amount", 0))
		TRADED:
			return "have traded with anyone" if target_id() == ActionCatalog.NOBODY \
				else "have traded with #%d" % target_id()
		APART_FROM:
			return "be %d or more apart from #%d" % [
				int(param("span", 0)), target_id(),
			]
		FELLED:
			return "have #%d out of the world" % target_id()
		STANDING:
			return "have a standing of %d or more" % int(param("amount", 0))
	return "something it has not put into words"


## The goal in one line, as a report prints it.
func line() -> String:
	return "%d  %-5s %-11s %-44s %s" % [
		id, horizon, kind, said(),
		"open" if not closed else "closed: %s" % closed_by,
	]


## A copy of this goal with a new number, for a set that is replacing one.
func with_id(number: int) -> Goal:
	id = number
	return self
