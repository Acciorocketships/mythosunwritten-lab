extends RefCounted
## One ability check: what the world raised, what a model judged, what the engine
## rolled, and what came of it.
##
## Section 7's shape, written down as one record so that every stage of it is
## visible in one place and nothing is inferred:
##
##   raised   something in the world triggered a check -- see `HOOK`
##   judged   a model said how hard it is and which ability score it is against
##   rolled   *the engine* rolled that score plus a die against that class
##   settled  the verdict, and on a success what the engine then changed
##
## ## The engine rolls, and nothing else does
##
## The three functions at the head of this file -- `bounded`, `rolled`, `beats`
## -- are the whole of the arithmetic. A model says a number and a name; the
## engine bounds the number to a range it will accept, hashes the die out of the
## check itself, adds the character's own score, and compares. `tests/
## test_checks.gd` reads the source of every file in this layer and requires that
## the die is drawn in exactly one place and the comparison made in exactly one,
## both of them here, so that "the model never resolves" is a fact about the code
## rather than a claim about it.
##
## ## The die is hashed from the check, never streamed
##
## The same discipline the combat layer keeps for a blow, and for the same reason.
## A stream's numbers depend on how many were drawn before them, so a check's roll
## would depend on how many other checks had been settled first -- and since a
## check settled out of memory draws nothing, whether an attempt succeeded would
## depend on what the character happened to have tried earlier. Hashing the seed,
## the check's number and the shape of the attempt makes the roll a fact about
## the attempt, and `tests/test_combat_resolution.gd` forbids a stream anywhere in
## the layer that names a combatant.
##
## ## Which is why a check is a record and not a call
##
## A model answers over a socket, in seconds, and the world goes on turning
## meanwhile. So a check is a thing that sits in the scene with a state on it and
## is advanced by `CheckDesk` when an answer arrives, exactly as a character's
## decision is. Nothing waits for it.
class_name AbilityCheck

## The one place in the world a check is raised from, named here so that a report
## and a test can both say it without going looking.
##
## `ActionEngine._interact` is section 2.1's generic interaction -- the lockpick
## hook. A character that offers a shut thing an item it is carrying which is not
## the item that thing plainly opens with has attempted something the world has
## no rule for, and that is exactly the moment a difficulty class is wanted. Bare
## hands are still a flat refusal, and the right item still just works: a check is
## raised for the attempt in between, and for nothing else.
const HOOK := "ActionEngine._interact"

## The die the engine rolls. A twenty, as section 7's "ability score + roll" is
## written against.
const DIE := 20

## The range of difficulty classes the engine will accept. A model that says
## something outside it is bounded to it, and the record keeps both numbers.
const DC_LOWEST := 1
const DC_HIGHEST := 30

## The states a check passes through.
const RAISED := "raised"
const JUDGED := "judged"
const SETTLED := "settled"
const LAPSED := "lapsed"

## How the verdict was arrived at.
const BY_A_ROLL := "rolled"
const BY_MEMORY := "remembered"


# --- The arithmetic, which is all of it -----------------------------------


## Bound what a model said to a class the engine will accept.
static func bounded(said: int) -> int:
	return clampi(said, DC_LOWEST, DC_HIGHEST)


## Draw the die, out of the roll seed and the check itself. The one place in this
## layer that draws one, and a pure function of its three arguments: the same
## check at the same seed rolls the same number however many checks came before
## it.
static func rolled(roll_seed: int, check_id: int, context: String) -> int:
	return 1 + (SimRng.hash_ints(roll_seed, check_id, folded(context)) % DIE)


## One string as one whole number, so that the shape of an attempt can go into the
## hash beside the seed and the check's number. An FNV-1a fold, which is the same
## arithmetic `SimRng.fork` uses on a label and is written out here so that this
## file draws nothing from a stream.
static func folded(text: String) -> int:
	var h := 0x811C9DC5
	for at in text.length():
		h = ((h ^ text.unicode_at(at)) * 0x01000193) & 0xFFFFFFFF
	return h


## The score plus the roll against the class. The one comparison in this layer.
static func beats(score: int, roll: int, difficulty: int) -> bool:
	return score + roll >= difficulty


# --- What one check is ----------------------------------------------------


## Which check this is, counted by the scene that raised it.
var id: int = 0

## The tick it was raised on.
var raised_at: int = 0

## Who attempted it, and what they are called.
var who: int = 0
var who_named: String = ""

## What was attempted on, and what it is called.
var target: int = 0
var target_named: String = ""

## What was offered.
var item: String = ""

## The attempt in one line, as it is put to a model.
var attempt: String = ""

## The triggering context: the shape of the attempt, which is what a later
## attempt is compared against. Two attempts with the same context are the same
## kind of attempt, and the second of them is not rolled for again.
##
## The shape is the action, the kind of thing, and the thing offered -- so a
## second oak chest pried at with the same bar is the same context, and a
## strongbox is not. That is this project's definition of "similar", stated here
## rather than judged anywhere.
var context: String = ""

## Where it has got to.
var state: String = RAISED

## What the model said the class was, and what the engine used after bounding it.
var said_class: int = -1
var difficulty: int = -1

## Which ability score the model picked, and what the character has in it.
var ability: String = ""
var score: int = 0

## What the engine rolled, what that came to, and whether it beat the class.
var roll: int = 0
var total: int = 0
var passed: bool = false

## How the verdict was reached: a roll, or an answer already in the character's
## memory for this same context.
var how: String = BY_A_ROLL

## What the resolving call named and what the engine did about each one. Each row
## is `{"line", "ok", "reason"}` -- the operation as the model wrote it, whether
## the engine carried it out, and why not where it did not.
var operations: Array[Dictionary] = []

## Anything the run should say about this check that is not in the numbers.
var note: String = ""


static func raised_by(
	check_id: int, at_tick: int, actor_id: int, actor_named: String,
	thing_id: int, thing_named: String, offered: String
) -> AbilityCheck:
	var check := AbilityCheck.new()
	check.id = check_id
	check.raised_at = at_tick
	check.who = actor_id
	check.who_named = actor_named
	check.target = thing_id
	check.target_named = thing_named
	check.item = offered
	check.attempt = "%s tries to work the %s (#%d) with %s %s" % [
		actor_named, thing_named, thing_id, _an(offered), offered,
	]
	check.context = "interact:%s:%s" % [thing_named, offered]
	return check


## Whether this check is still waiting on something.
func is_open() -> bool:
	return state == RAISED or state == JUDGED


## What the engine did, in one line.
func line() -> String:
	if state == LAPSED:
		return "check #%d %s -- lapsed: %s" % [id, context, note]
	if state != SETTLED:
		return "check #%d %s -- %s" % [id, context, state]
	if how == BY_MEMORY:
		return "check #%d %s -- %s, remembered: %s (no roll, no call)" % [
			id, context, "passed" if passed else "failed", _sum_line(),
		]
	return "check #%d %s -- %s: %s" % [
		id, context, "passed" if passed else "failed", _sum_line(),
	]


## The arithmetic in one line, so that a reader can check it by eye.
func _sum_line() -> String:
	return "%s %d + roll %d = %d vs dc %d" % [ability, score, roll, total, difficulty]


## The row kept in the character's memory, which is also what a later attempt of
## the same shape is settled from.
func remembered_row() -> Dictionary:
	var kept: Array[Dictionary] = []
	for row in operations:
		if bool(row.get("ok", false)):
			kept.append({"line": String(row["line"]), "target": int(row.get("target", 0))})
	return {
		"text": "I %s the %s with %s %s: %s." % [
			"worked" if passed else "failed to work", target_named, _an(item), item,
			"it gave" if passed else "it held",
		],
		"attempt": attempt,
		"ability": ability,
		"score": score,
		"roll": roll,
		"total": total,
		"difficulty": difficulty,
		"passed": passed,
		"target": target,
		"operations": kept,
	}


static func _an(word: String) -> String:
	return "an" if "aeiou".contains(word.substr(0, 1).to_lower()) else "a"
