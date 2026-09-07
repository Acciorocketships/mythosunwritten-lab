extends RefCounted
## How much goodwill one thing earned: the number a model judges, and the range
## the engine will accept for it.
##
## Section 6 gives two ways sentiment goes up, and both of them end here.
## "Completing quests raises it (amount judged by an LLM from the quest's
## nature)" -- a deed somebody actually wanted, weighed by a model. And pure talk,
## once the difficulty-class desk has rolled a success for it. The two are asked
## about differently (`GoodwillPrompt`) and reach the world by different paths
## (`DeedDesk` and `CheckDesk`), but what comes back is one number of one kind,
## read and bounded in one place, which is this file.
##
## ## The model judges an amount; it does not change anything
##
## A reply is prose with a number in it. This file turns that into a share the
## engine will accept or into a refusal, and nothing else in it can happen. A
## reply that says goodwill rose, in whatever words, moves nothing: there is no
## sentence a model can write here that is not either a number in range or a
## refusal, and `RelationshipGraph.favoured` is the only door on the other side
## and takes a float.
##
## ## Three answers, and only three
##
##   * **not read** -- no `goodwill=` in the reply at all, or what follows it is
##     not a number. Nothing changes and the transcript says so.
##   * **out of range** -- a number outside $[0, `SAID_MOST`]$. Refused rather
##     than clamped, because a reply that says seven has not answered the
##     question that was asked, and clamping it to the top of the range would
##     reward the mistake with the largest move the engine allows.
##   * **a share** -- a number in range. It is then *bounded* into what the
##     engine will move an edge by, which is $[0, `MOST`]$: the answer is read as
##     a share of the most one thing may be worth. Both numbers are kept -- what
##     was said and what was used -- exactly as `AbilityCheck` keeps both classes.
##
## ## Bounding scales rather than clips, and that is not a detail
##
## The obvious way to bound a number to a range is to clamp it. It would be wrong
## here. The recorded model answers this question with numbers between a half and
## seven tenths, and every one of those clamps to exactly `MOST` -- so a deed the
## model judged half again as valuable as another would move an edge by precisely
## as much, and the amount would be the engine's after all, read off a table with
## the model's answer thrown away at the door. Reading the answer as a *share* of
## `MOST` keeps the whole of the judgement and still cannot exceed the ceiling.
## The number a reply may not give is one outside the range it was asked for, and
## that is refused above rather than squeezed into it.
##
## ## Why `MOST` is a half
##
## It is what one blow costs: `RelationshipGraph.STRUCK_TRUST` is the share of
## trust being struck gives up, and `MOST` is the share of the distance left to
## complete trust that the best imaginable single deed closes. One good turn is
## worth one bad one, and neither settles a relationship on its own -- both are
## shares of what is left, so the tenth deed is worth much less than the first.
##
## The two numbers are written out separately rather than one reading the other,
## because a constant that read another file's constant would make a cycle out of
## the store and the amount. `tests/test_goodwill.gd` fails if they ever part, so
## the sentence above cannot quietly stop being true.
class_name Goodwill

## The key a reply names its number with.
const KEY := "goodwill"

## The range the question asks for, which is what a reply must be inside to be
## read at all. Nought is a real answer: a model may judge that something earned
## nothing, and then nothing happens and that is not a refusal.
const SAID_LEAST := 0.0
const SAID_MOST := 1.0

## The range the engine will actually move an edge by. `MOST` is one blow's
## worth -- see the note above.
const LEAST := 0.0
const MOST := 0.5


## Read a reply into a share, or say why it is not one.
##
## `{"read": bool, "said": float, "why": String}`. `said` is the number as the
## model wrote it, before bounding, and is meaningless when `read` is false.
static func read(reply: String) -> Dictionary:
	var found: Variant = _number_after(reply, KEY)
	if found == null:
		return _not_read("no %s= naming a number in it" % KEY)
	var said := float(found)
	if said < SAID_LEAST or said > SAID_MOST:
		return _not_read("%s=%s is outside the %.1f to %.1f it was asked for" % [
			KEY, said_as(said), SAID_LEAST, SAID_MOST,
		])
	return {"read": true, "said": said, "why": ""}


## Bound a share the engine has read to one it will move an edge by: the answer
## as a share of the most one thing may be worth. See the note above for why this
## scales rather than clips.
static func bounded(said: float) -> float:
	return clampf(said, SAID_LEAST, SAID_MOST) * MOST


## One share, written the way every table in this project writes one.
static func said_as(share: float) -> String:
	return "%.3f" % share


# --- Reading a number out of prose ----------------------------------------


# Everything after `key=`, as a number, or null where there is none. A decimal
# point and a leading minus are part of the number, so that a reply saying
# something below the range is refused as out of range rather than misread as a
# number that happens to be in it.
static func _number_after(reply: String, key: String) -> Variant:
	for line in reply.split("\n"):
		var text := String(line).strip_edges().to_lower()
		var at := text.find("%s=" % key)
		if at < 0:
			at = text.find("%s =" % key)
			if at < 0:
				continue
		var rest := text.substr(text.find("=", at) + 1).strip_edges()
		var digits := ""
		for index in rest.length():
			var one := rest.substr(index, 1)
			if one == "-" and digits == "":
				digits += one
				continue
			if one == "." and not digits.contains("."):
				digits += one
				continue
			if not one.is_valid_int():
				break
			digits += one
		if digits.is_valid_float():
			return digits.to_float()
	return null


static func _not_read(why: String) -> Dictionary:
	return {"read": false, "said": 0.0, "why": why}
