extends RefCounted
## The difficulty-class agent: the second shape of language-model call in this
## game.
##
## A character agent loops -- it is asked what to do next, over and over, for as
## long as the character is alive. This one does not loop and is never polled for
## work. It sits idle until something in the world raises a check at
## `AbilityCheck.HOOK`, and then it handles that one check and goes quiet again.
## A run in which nobody attempts anything unusual makes no call from this file at
## all.
##
## ## The four things it does, and the one thing it does not
##
##   1. **Take up** a check the world raised. Before anything else it asks the
##      character's own memory whether it has already settled a check of this
##      shape. If it has, that answer stands: no model call and no roll. This is
##      section 7's "store the triggering context in memory so similar later
##      attempts don't re-roll", and it is the first branch rather than a
##      fallback, so the saving is real.
##   2. **Ask** how hard it is, with `CheckPrompt.judging_for`. One call. The
##      answer is a difficulty class and an ability score, and nothing else in it
##      is read.
##   3. **Roll**, which is the engine's and not the model's: `AbilityCheck.bounded`
##      to a class the engine accepts, `AbilityCheck.rolled` out of a seeded
##      stream, the character's own score off its own sheet, and
##      `AbilityCheck.beats` for the comparison. A reply that says the attempt
##      succeeds changes nothing; only this does.
##   4. **Resolve**, on a success only, with `CheckPrompt.resolving_for` -- a
##      second call with a different system prompt. What comes back is read into
##      rows of `CheckEffects` and carried out by the engine. A line that is not
##      one of those operations changes nothing and is printed as refused.
##
## And then the settled check is written into the character's memory, pass or
## fail, so the next attempt of the same shape takes branch 1.
##
## The one thing it does not do is wait. Both calls are put to a `ModelChannel`
## and polled exactly as a character's decision is; a check that has been asked
## and not answered simply stays open, and the world goes on turning around it.
class_name CheckDesk

## The two stages a check can be waiting at.
const JUDGING := "judging"
const RESOLVING := "resolving"

## Where the answers come from.
var channel: ModelChannel = null

## Every check this desk has taken up, in the order it took them up.
var seen: Array[AbilityCheck] = []

## What the run cost and did: model calls put, dice rolled, and checks settled
## out of a character's memory with neither.
var calls: int = 0
var rolls: int = 0
var reused: int = 0

## What happened, one line at a time, for a transcript to print.
var journal := PackedStringArray()

## What seeds the die. The roll is hashed from this, the check's number and the
## shape of the attempt -- see `AbilityCheck.rolled` -- so nothing here holds a
## stream and a check's roll does not depend on how many came before it.
var roll_seed: int = 0

var _taken: Dictionary = {}
var _open: Dictionary = {}


## A desk answering out of a channel, rolling out of a seed.
##
## The seed is the roll's and only the roll's: it enters no prompt, so two runs
## that differ only in it put word-for-word identical questions and are answered
## by the same recording.
static func with_channel(from: ModelChannel, seed_value: int) -> CheckDesk:
	var desk := CheckDesk.new()
	desk.channel = from
	desk.roll_seed = seed_value
	return desk


## Advance every check the world has raised, by as much as it can be advanced
## this tick. Called once a tick by whatever is running the world.
func step(scene: ActionScene) -> void:
	if scene == null or channel == null:
		return
	_take_up(scene)
	_poll(scene)


## How many checks are waiting on an answer.
func waiting() -> int:
	return _open.size()


## How many checks have been settled one way or the other.
func settled() -> int:
	var found := 0
	for check in seen:
		if check.state == AbilityCheck.SETTLED:
			found += 1
	return found


# --- 1. Taking one up ------------------------------------------------------


func _take_up(scene: ActionScene) -> void:
	for check in scene.raised:
		if _taken.has(check.id):
			continue
		_taken[check.id] = true
		seen.append(check)
		if _settle_from_memory(scene, check):
			continue
		_ask(scene, check, JUDGING)


# Whether this character has already settled a check of this shape. If it has,
# that answer stands and neither a call nor a roll is made.
func _settle_from_memory(scene: ActionScene, check: AbilityCheck) -> bool:
	var remembered := _memory_of(scene, check)
	if remembered == null:
		return false
	var row := remembered.check_for(check.context)
	if row.is_empty():
		return false
	check.how = AbilityCheck.BY_MEMORY
	check.ability = String(row.get("ability", ""))
	check.score = int(row.get("score", 0))
	check.roll = int(row.get("roll", 0))
	check.total = int(row.get("total", 0))
	check.difficulty = int(row.get("difficulty", 0))
	check.said_class = check.difficulty
	check.passed = bool(row.get("passed", false))
	check.state = AbilityCheck.SETTLED
	check.note = "settled out of %s's memory of \"%s\"" % [check.who_named, check.context]
	reused += 1
	if check.passed:
		_carry_out_again(scene, check, row)
	journal.append("tick %d  %s" % [scene.tick, check.line()])
	for row_of in check.operations:
		journal.append("           %s -- %s" % [row_of["line"], row_of["reason"]])
	return true


# What a remembered success does to the thing attempted now.
#
# The operations the resolving call named the first time are carried out again by
# the engine, with the thing they were about swapped for the thing this attempt is
# about. An operation that was about something else is not repeated: a success on
# this chest is a fact about this chest.
func _carry_out_again(scene: ActionScene, check: AbilityCheck, row: Dictionary) -> void:
	var was := int(row.get("target", 0))
	for kept in row.get("operations", []):
		var line := String(kept.get("line", ""))
		if int(kept.get("target", 0)) != was:
			check.operations.append({
				"ok": false, "line": line, "target": int(kept.get("target", 0)),
				"reason": "that one was about something else, so it is not repeated",
			})
			continue
		var here := line.replace("#%d" % was, "#%d" % check.target)
		var again := CheckEffects.read(here)
		if again.is_empty():
			check.operations.append({
				"ok": false, "line": here, "target": check.target,
				"reason": "the engine could not read it back",
			})
			continue
		check.operations.append(CheckEffects.apply(scene, again[0]))


# --- 2 and 4. Asking ------------------------------------------------------


func _ask(scene: ActionScene, check: AbilityCheck, stage: String) -> void:
	var sheet := _sheet_of(scene, check)
	var prompt := CheckPrompt.judging_for(check, sheet) if stage == JUDGING \
		else CheckPrompt.resolving_for(check, sheet, scene)
	_open[check.id] = {
		"stage": stage, "check": check,
		"ticket": channel.ask(prompt, scene.tick),
		"digest": CheckPrompt.digest_of(prompt),
	}
	calls += 1
	journal.append("tick %d  check #%d asked the %s question (%s)" % [
		scene.tick, check.id, stage, _open[check.id]["digest"],
	])


func _poll(scene: ActionScene) -> void:
	for id in _open.keys():
		var open: Dictionary = _open[id]
		var ticket := int(open["ticket"])
		var reply := channel.reply_to(ticket, scene.tick)
		if reply == "" and not channel.has_answered(ticket):
			continue
		_open.erase(id)
		var check: AbilityCheck = open["check"]
		if String(open["stage"]) == JUDGING:
			_judged(scene, check, reply, channel.note_on(ticket))
		else:
			_resolved(scene, check, reply)


# --- 3. The roll, which is the engine's -----------------------------------


func _judged(
	scene: ActionScene, check: AbilityCheck, reply: String, note: String
) -> void:
	var judgement := CheckPrompt.judgement_of(reply)
	if not bool(judgement["read"]):
		check.state = AbilityCheck.LAPSED
		check.note = "the answer could not be read: %s%s" % [
			judgement["why"], "" if note == "" else " (%s)" % note,
		]
		journal.append("tick %d  %s" % [scene.tick, check.line()])
		return

	check.said_class = int(judgement["dc"])
	check.ability = String(judgement["ability"])
	check.difficulty = AbilityCheck.bounded(check.said_class)
	if check.difficulty != check.said_class:
		check.note = "the class said was %d, which the engine bounded to %d" % [
			check.said_class, check.difficulty,
		]
	var sheet := _sheet_of(scene, check)
	check.score = 0 if sheet == null else sheet.score(check.ability, 0)
	check.roll = AbilityCheck.rolled(roll_seed, check.id, check.context)
	check.total = check.score + check.roll
	check.passed = AbilityCheck.beats(check.score, check.roll, check.difficulty)
	rolls += 1
	check.state = AbilityCheck.JUDGED

	if not check.passed:
		check.state = AbilityCheck.SETTLED
		journal.append("tick %d  %s" % [scene.tick, check.line()])
		_remember(scene, check)
		return
	journal.append("tick %d  %s, so it is resolved" % [scene.tick, check.line()])
	_ask(scene, check, RESOLVING)


# --- 4. The resolution, carried out by the engine -------------------------


func _resolved(scene: ActionScene, check: AbilityCheck, reply: String) -> void:
	var named := CheckEffects.read(reply)
	if named.is_empty():
		check.operations.append({
			"ok": false, "line": ModelPrompt.said_line(reply), "target": 0,
			"reason": "no operation the engine exposes was named, so nothing changed",
		})
	for at in named.size():
		if at >= CheckEffects.AT_MOST:
			check.operations.append({
				"ok": false, "line": String(named[at]["line"]), "target": 0,
				"reason": "the engine carries out at most %d" % CheckEffects.AT_MOST,
			})
			continue
		check.operations.append(CheckEffects.apply(scene, named[at]))
	check.state = AbilityCheck.SETTLED
	journal.append("tick %d  check #%d resolved" % [scene.tick, check.id])
	for row in check.operations:
		journal.append("           %s -- %s" % [row["line"], row["reason"]])
	_remember(scene, check)


# --- What is kept -----------------------------------------------------------


# The settled check into the character's own memory, through the one door that
# store has: a function that was handed an observation.
func _remember(scene: ActionScene, check: AbilityCheck) -> void:
	var remembered := _memory_of(scene, check)
	var actor := scene.actor_of(check.who)
	if remembered == null or actor == null:
		return
	remembered.settle_check(
		check.context, check.remembered_row(), Observation.of(scene, actor))


# --- The furniture ---------------------------------------------------------


static func _sheet_of(scene: ActionScene, check: AbilityCheck) -> Character:
	var actor := scene.actor_of(check.who)
	if actor == null or actor.piece == null or not (actor.piece is Commander):
		return null
	return (actor.piece as Commander).sheet


static func _memory_of(scene: ActionScene, check: AbilityCheck) -> CharacterMemory:
	var sheet := _sheet_of(scene, check)
	return null if sheet == null else sheet.memory
