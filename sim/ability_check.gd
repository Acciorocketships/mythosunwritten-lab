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

## The two places in the world a check is raised from, named here so that a
## report and a test can both say them without going looking.
##
## `ActionEngine._interact` is section 2.1's generic interaction -- the lockpick
## hook. A character that offers a shut thing an item it is carrying which is not
## the item that thing plainly opens with has attempted something the world has
## no rule for, and that is exactly the moment a difficulty class is wanted. Bare
## hands are still a flat refusal, and the right item still just works: a check is
## raised for the attempt in between, and for nothing else.
const HOOK := "ActionEngine._interact"

## `ActionEngine._say` is section 6's other one: pure talk, which "can raise
## sentiment but is deliberately hard". A line addressed to one character raises
## a check on winning that character round. A shout raises none -- it is
## addressed to nobody in particular, and there is no one person being won over
## -- and neither does a line to anything that keeps no character sheet, because
## the class below is read off one.
##
## The words are said either way. The check is about what they *earn*, not about
## whether they were heard, so a persuasion that fails is a line of speech like
## any other: it is heard, it is written into the world's record, and it moves
## familiarity through `RelationshipGraph.heard` exactly as it always did.
const TALK_HOOK := "ActionEngine._say"

## The two sorts of check, which differ in one thing: who says how hard it is.
##
##   * `AT_A_THING` -- the lockpick hook. Nobody has written down how hard it is
##     to lever an oak chest with a pry bar, so a model is asked, which is
##     section 7's shape.
##   * `AT_A_PERSON` -- the talk hook. Section 6 *does* write it down -- "CHA +
##     roll vs a DC factoring WIS and max(status, level)" -- so there is nothing
##     to ask. The class is `class_for_talk` below and the ability is `CHA`, both
##     of them the engine's, and the judging call is not made at all.
const AT_A_THING := "thing"
const AT_A_PERSON := "person"

## The die the engine rolls. A twenty, as section 7's "ability score + roll" is
## written against.
const DIE := 20

## The range of difficulty classes the engine will accept. A model that says
## something outside it is bounded to it, and the record keeps both numbers. A
## class the engine works out for itself goes through the same bound, so there
## is one range and not one per sort.
const DC_LOWEST := 1
const DC_HIGHEST := 30

## The ability score a persuasion is tested against. Section 6 names it: "CHA +
## roll".
const TALK_ABILITY := Ability.CHA

## Section 13's third open question, settled: the difficulty class of winning
## somebody round by talking is
##
## $$\mathrm{DC} = \mathrm{TALK\_FLOOR}
##   + \mathrm{WIS}(\text{the listener})
##   + \max\big(\mathrm{status}(\text{the listener}),
##               \mathrm{level}(\text{the listener})\big)$$
##
## bounded to the range above like any other class. Four things are decided in
## that line, and each of them is section 6's own words or a reading of them.
##
##   * **It is the listener's wisdom and the listener's standing.** Section 6
##     gives the terms but not whose they are. They are the one being talked at:
##     wisdom is what sees through a line, and standing -- diplomatic or military,
##     whichever is greater -- is how little this person needs anything from you.
##     Reading them off the speaker would make a wise, powerful character
##     *worse* at diplomacy, which is backwards.
##   * **The greater of status and level, not the sum.** Section 6 wrote
##     `max(status, level)`, and the reason it is the right shape is that the two
##     are alternative kinds of standing rather than parts of one: a warlord of no
##     rank and a herald of no army are each hard to impress, and neither is twice
##     as hard as the other. (`OwnershipField.carry` adds them instead, and that
##     is not an inconsistency: there the two are being *spent*, and both count.)
##   * **The speaker's charm is on the other side of the comparison**, because
##     section 6 puts it there: CHA plus the roll against the class. So charm is
##     the lever and the class is what it is levering.
##   * **`TALK_FLOOR` is 15**, which is what makes the whole thing hard. The
##     criterion it was chosen against: a speaker whose charm exactly equals the
##     listener's wisdom, against the least standing there is (level 1, no
##     assigned status), must succeed on a quarter of the faces of the die. That
##     comes to needing 16 or better on a d20, so the floor is
##     $16 - 1 = 15$. Every point of the listener's wisdom or standing above the
##     speaker's charm takes another face away, and against a wise character of
##     rank the class reaches the bound, where only the highest faces are left.
##
## What makes talking hard is not this number alone, and it was not asked to do
## the whole job. There is one attempt per person, ever -- `context` below is the
## person and nothing else -- so the class decides what one attempt is worth
## trying and the context decides that there is only the one. See
## `sim/scripted_goodwill.gd`, which measures what the two come to together.
const TALK_FLOOR := 15

## The states a check passes through.
const RAISED := "raised"
const JUDGED := "judged"
const SETTLED := "settled"
const LAPSED := "lapsed"

## What `said_share` and `share` hold while nothing has been judged. Negative,
## because `Goodwill` accepts nothing below nought.
const NOTHING_JUDGED := -1.0

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


## The class of winning one character round by talking, out of that character's
## own sheet. See the note on `TALK_FLOOR` above for every term in it.
##
## Unbounded, exactly as a model's answer is unbounded before `bounded()` sees
## it, so that the record can keep what the formula said beside what the engine
## used and a class that ran past the range is visible rather than silent.
static func class_for_talk(listener: Character) -> int:
	if listener == null:
		return TALK_FLOOR
	return TALK_FLOOR + maxi(listener.score(Ability.WIS, 0), 0) \
		+ maxi(maxi(listener.status(), listener.level), 0)


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

## What was offered, for a check at a thing. Empty for a check at a person:
## nothing is held out in a conversation.
var item: String = ""

## Which sort of check this is: `AT_A_THING` or `AT_A_PERSON`. It decides one
## thing only -- whether the class is asked for or worked out -- and every other
## stage is the same for both.
var sort: String = AT_A_THING

## The attempt in one line, as it is put to a model.
var attempt: String = ""

## The triggering context: the shape of the attempt, which is what a later
## attempt is compared against. Two attempts with the same context are the same
## kind of attempt, and the second of them is not rolled for again.
##
## For a check at a thing the shape is the action, the kind of thing, and the
## thing offered -- so a second oak chest pried at with the same bar is the same
## context, and a strongbox is not. That is this project's definition of
## "similar", stated here rather than judged anywhere.
##
## For a check at a person the shape is **the person, and nothing else**. Two
## attempts to win the same character round are the same attempt however
## differently they are worded, so the second of them is settled out of memory
## with no call and no roll, and it earns nothing further. That is where section
## 6's "only truly novel diplomacy is even considered" lives: talking to somebody
## you have already talked round, or already failed to talk round, is not novel,
## and the words are not read to decide that -- which is deliberate, because a
## rule that read the words would be a rule about what a character is allowed to
## say. It is also what stops the obvious cheese, and `sim/scripted_goodwill.gd`
## measures how much it stops.
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

## What a model said one persuasion was worth and what the engine moved the edge
## by, for a check at a person that passed. Both are kept for the reason both
## classes are: what was asked for and what was allowed are two facts.
## `NOTHING_JUDGED` while no amount has been judged at all.
var said_share: float = NOTHING_JUDGED
var share: float = NOTHING_JUDGED

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


## A check raised over talking one character round.
##
## No item, because nothing is held out; the words are in the attempt, and the
## context is the listener alone -- see the note on `context`.
static func raised_over(
	check_id: int, at_tick: int, speaker_id: int, speaker_named: String,
	listener_id: int, listener_named: String, said: String
) -> AbilityCheck:
	var check := AbilityCheck.new()
	check.id = check_id
	check.sort = AT_A_PERSON
	check.raised_at = at_tick
	check.who = speaker_id
	check.who_named = speaker_named
	check.target = listener_id
	check.target_named = listener_named
	check.attempt = "%s tries to win %s (#%d) round by saying \"%s\"" % [
		speaker_named, listener_named, listener_id, said.strip_edges(),
	]
	check.context = "persuade:#%d" % listener_id
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


## Whether this check is about winning a character round rather than working a
## thing. Asked in three places -- which prompt is put, whether a judging call is
## made at all, and whether a remembered success is carried out again -- and it
## is a question about the check rather than about the hook, so it is here.
func is_at_a_person() -> bool:
	return sort == AT_A_PERSON


## The row kept in the character's memory, which is also what a later attempt of
## the same shape is settled from.
func remembered_row() -> Dictionary:
	var kept: Array[Dictionary] = []
	# Nothing is kept for a check at a person, because there is nothing to carry
	# out again: what a success there earned was earned once, from that one
	# character, and the context *is* that character. Keeping the row would be
	# keeping a way of being thanked twice for the same conversation.
	if not is_at_a_person():
		for row in operations:
			if bool(row.get("ok", false)):
				kept.append({
					"line": String(row["line"]), "target": int(row.get("target", 0)),
				})
	return {
		"text": _said_of_itself(),
		"attempt": attempt,
		"sort": sort,
		"ability": ability,
		"score": score,
		"roll": roll,
		"total": total,
		"difficulty": difficulty,
		"passed": passed,
		"share": share,
		"said_share": said_share,
		"target": target,
		"operations": kept,
	}


# What the character puts in its own first-person log about this check, which is
# a sentence about what it tried and how it went and never about a number.
func _said_of_itself() -> String:
	if is_at_a_person():
		return "I tried to win %s round with words: %s." % [
			target_named, "they came round" if passed else "they did not",
		]
	return "I %s the %s with %s %s: %s." % [
		"worked" if passed else "failed to work", target_named, _an(item), item,
		"it gave" if passed else "it held",
	]


static func _an(word: String) -> String:
	return "an" if "aeiou".contains(word.substr(0, 1).to_lower()) else "a"
