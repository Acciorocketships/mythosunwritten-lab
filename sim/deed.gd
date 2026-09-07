extends RefCounted
## A deed: something one character wanted, which another character brought
## about.
##
## Section 6's first way sentiment goes up -- "completing quests raises it" --
## with no quest in it. There is no quest system in this project, no quest log
## and no quest-giver: what a character wants is its own `GoalSet`, put there by
## whoever set the scene up and by nothing in the machinery, and a *deed* is what
## this file calls the case where the world's own records say somebody else is
## why one of those goals is now finished.
##
## So nothing is ever handed out, scheduled or accepted. Wren wants a wool cap;
## Rook happens to give Wren one; the world closes Wren's goal because Wren is
## now carrying a wool cap, and this file reads back off the world's own account
## of what happened that the cap came from Rook. Rook was never told, never asked
## and never rewarded. The only thing that follows is that Wren now thinks a
## little better of Rook, which is the whole of it.
##
## ## What "who did it" is read off
##
## The engine's own three records and nothing else -- the same records
## `RelationshipGraph` is folded from, for the same reason. A deed cannot be
## claimed, proposed or asserted; it is read back out of what the engine wrote
## down while carrying something out.
##
##   | wanted state | the record read | who did it |
##   |--------------|-----------------|------------|
##   | `HOLD`  -- carrying a named thing | the latest honoured trade in which this character *received things* | the other party |
##   | `MONEY` -- having an amount | the latest honoured trade in which this character *received money* | the other party |
##   | `TRADED` -- having traded | the trade that answers the goal | the other party |
##   | `FELLED` -- somebody no longer standing | the latest blow landed on them | whoever struck it |
##
## The other four kinds the engine answers -- `BE_AT`, `APART_FROM`, `STANDING`
## and the eighth, `UNWRITTEN` -- have no second hand in them at all. Being
## somewhere is something a character did by walking there; standing is something
## it rose to; and `UNWRITTEN` is the one kind the character closes itself, so
## crediting anybody for it would let a character hand out goodwill by saying it
## was owed. Those four are refused here by name, with that reason.
##
## ## The window, which is why an old dealing cannot be credited
##
## A record only counts if it happened while the goal was still open. The world
## looks at every open goal it can answer every time it services the character
## that holds it (`GoalCheck.settle`), and stamps the tick on each one it finds
## unmet -- `Goal.open_at`. A closed goal therefore carries the last moment the
## world said "not yet", and the record that brought it about has to be at or
## after that moment and at or before the closing.
##
## That is what stops the obvious misreading: a character that bought bread from
## a merchant forty ticks ago, and then found the cap it wanted lying on the
## ground, is not held to have been given the cap by the merchant. The bread is
## outside the window, so nobody did it, and nothing moves. There is no constant
## here doing that work -- no "recently", no number of ticks -- because the world
## already knows exactly when it last said no.
class_name Deed

## Nobody did it: no second hand appears in any record inside the window.
const NOBODY := ActionScene.NOBODY

## The kinds of wanted state whose closing can name somebody else.
const CREDITED := [Goal.HOLD, Goal.MONEY, Goal.TRADED, Goal.FELLED]

## Why the other kinds name nobody, one sentence each, so a transcript can print
## the reason rather than an absence.
const NOBODY_ELSE := {
	Goal.BE_AT: "getting somewhere is something a character does by walking there",
	Goal.APART_FROM: "getting away from something is a character's own doing",
	Goal.STANDING: "standing is what a character has risen to, not a gift",
	Goal.UNWRITTEN: "this one the character closed itself, so nobody else may be"
		+ " credited for it",
}


## Who, if anybody, the world says brought this closed goal about.
##
## `{"who": int, "what": String, "why": String}` -- the doer's id or `NOBODY`,
## the world's own line for what happened, and where there is no doer, why not.
##
## Everything read here is `scene.trades` and `scene.blows`, both of which the
## engine writes on the one path the thing they record goes through. Nothing
## here reads a character, an intention or an offer.
static func done_for(goal: Goal, scene: ActionScene, actor: Combatant) -> Dictionary:
	if goal == null or scene == null or actor == null:
		return _nobody("there is nothing to read")
	if not goal.closed:
		return _nobody("it is not finished")
	if not CREDITED.has(goal.kind):
		return _nobody(String(NOBODY_ELSE.get(goal.kind, "nothing names a second hand")))
	match goal.kind:
		Goal.HOLD:
			return _out_of_a_trade(goal, scene, actor, true, false)
		Goal.MONEY:
			return _out_of_a_trade(goal, scene, actor, false, true)
		Goal.TRADED:
			return _out_of_a_trade(goal, scene, actor, false, false)
		Goal.FELLED:
			return _out_of_a_blow(goal, scene, actor)
	return _nobody("nothing names a second hand")


## Whether a record's tick falls inside the window a goal was open over: at or
## after the last moment the world looked and said it was unmet, and at or before
## the moment it closed. A goal the world never looked at has no lower edge, and
## `open_at` is `Goal.NEVER_LOOKED` for it.
static func inside(goal: Goal, at_tick: int) -> bool:
	if goal.open_at != Goal.NEVER_LOOKED and at_tick < goal.open_at:
		return false
	return goal.closed_at < 0 or at_tick <= goal.closed_at


# --- One record each -------------------------------------------------------


# The latest honoured trade inside the window that this character was a party to
# and, where asked for, actually received something out of. Newest first, because
# what closed the goal is the last thing that could have.
static func _out_of_a_trade(
	goal: Goal, scene: ActionScene, actor: Combatant,
	needs_things: bool, needs_money: bool
) -> Dictionary:
	for at in range(scene.trades.size() - 1, -1, -1):
		var row: Dictionary = scene.trades[at]
		if not inside(goal, int(row.get("tick", -1))):
			continue
		var got_things := 0
		var got_money := 0
		var other := NOBODY
		if int(row["to"]) == actor.id:
			got_things = int(row.get("gave", 0))
			got_money = int(row.get("gave_money", 0))
			other = int(row["from"])
		elif int(row["from"]) == actor.id:
			got_things = int(row.get("back", 0))
			got_money = int(row.get("back_money", 0))
			other = int(row["to"])
		else:
			continue
		if needs_things and got_things <= 0:
			continue
		if needs_money and got_money <= 0:
			continue
		if other == NOBODY or other == actor.id:
			continue
		return {
			"who": other, "why": "",
			"what": "#%d handed over %s and took %s back, at tick %d" % [
				other, _parcel(got_things, got_money),
				_parcel(_given_back(row, actor), _money_back(row, actor)),
				int(row.get("tick", -1)),
			],
		}
	return _nobody("no honoured trade while it was open brought it about")


# The latest blow landed on whoever the goal wanted felled, inside the window,
# struck by somebody other than the character that wanted it.
static func _out_of_a_blow(
	goal: Goal, scene: ActionScene, actor: Combatant
) -> Dictionary:
	var felled := goal.target_id()
	for at in range(scene.blows.size() - 1, -1, -1):
		var row: Dictionary = scene.blows[at]
		if int(row["to"]) != felled or int(row.get("dealt", 0)) <= 0:
			continue
		if not inside(goal, int(row.get("tick", -1))):
			continue
		var struck_by := int(row["from"])
		if struck_by == actor.id or struck_by == NOBODY:
			continue
		return {
			"who": struck_by, "why": "",
			"what": "#%d struck #%d for %d of %d, at tick %d" % [
				struck_by, felled, int(row.get("dealt", 0)),
				int(row.get("out_of", 0)), int(row.get("tick", -1)),
			],
		}
	return _nobody("no blow struck by anybody else while it was open brought it about")


# --- The furniture ---------------------------------------------------------


static func _given_back(row: Dictionary, actor: Combatant) -> int:
	return int(row.get("back", 0)) if int(row["to"]) == actor.id \
		else int(row.get("gave", 0))


static func _money_back(row: Dictionary, actor: Combatant) -> int:
	return int(row.get("back_money", 0)) if int(row["to"]) == actor.id \
		else int(row.get("gave_money", 0))


static func _parcel(things: int, money: int) -> String:
	if things == 0 and money == 0:
		return "nothing"
	var parts := PackedStringArray()
	if things > 0:
		parts.append("%d thing%s" % [things, "" if things == 1 else "s"])
	if money > 0:
		parts.append("%d coin%s" % [money, "" if money == 1 else "s"])
	return " and ".join(parts)


static func _nobody(why: String) -> Dictionary:
	return {"who": NOBODY, "what": "", "why": why}
