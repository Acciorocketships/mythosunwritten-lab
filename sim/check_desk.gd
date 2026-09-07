extends RefCounted
## The difficulty-class agent: the second shape of language-model call in this
## game.
##
## A character agent loops -- it is asked what to do next, over and over, for as
## long as the character is alive. This one does not loop and is never polled for
## work. It sits idle until something in the world raises a check at one of the
## two hooks -- `AbilityCheck.HOOK`, a thing worked with the wrong item, and
## `AbilityCheck.TALK_HOOK`, a character talked at -- and then it handles that one
## check and goes quiet again. A run in which nobody attempts anything unusual
## makes no call from this file at all.
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
##      is read. This step is skipped entirely for a check at a person: section 6
##      writes that class down -- CHA against a class factoring the listener's
##      wisdom and standing -- so there is nothing to ask, and
##      `AbilityCheck.class_for_talk` answers it. A persuasion therefore costs no
##      call at all unless it succeeds.
##   3. **Roll**, which is the engine's and not the model's: `AbilityCheck.bounded`
##      to a class the engine accepts, `AbilityCheck.rolled` out of a seeded
##      stream, the character's own score off its own sheet, and
##      `AbilityCheck.beats` for the comparison. A reply that says the attempt
##      succeeds changes nothing; only this does.
##   4. **Resolve**, on a success only, with a second call under a different
##      system prompt. For a check at a thing that is `CheckPrompt.resolving_for`,
##      and what comes back is read into rows of `CheckEffects` and carried out by
##      the engine; a line that is not one of those operations changes nothing and
##      is printed as refused. For a check at a person it is
##      `GoodwillPrompt.for_a_persuasion`, and what comes back is one number,
##      which `Goodwill` reads and bounds and the engine writes into the world's
##      own record of goodwill earned -- so the model judges an amount, the engine
##      records it, and what it comes to for the two characters is decided where
##      every other happening's meaning is decided. A reply that merely says the
##      two are now friends moves nothing.
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

## How many edges a persuasion moved here, and how much trust that came to all
## told. What a run prints when it wants to say what talking actually earned
## rather than assert it.
var favoured: int = 0
var earned: float = 0.0

## What happened, one line at a time, for a transcript to print.
var journal := PackedStringArray()

## What seeds the die. The roll is hashed from this, the check's number and the
## shape of the attempt -- see `AbilityCheck.rolled` -- so nothing here holds a
## stream and a check's roll does not depend on how many came before it.
var roll_seed: int = 0

var _taken: Dictionary = {}
var _open: Dictionary = {}
var _settling: Dictionary = {}


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


# The shape of an attempt, for the purpose of not having two of it in flight at
# once: the character attempting it and the triggering context. Two characters
# prying at the same sort of chest are two attempts, because a check is settled
# out of one character's memory and not out of the world's.
static func _shape_of(check: AbilityCheck) -> String:
	return "%d/%s" % [check.who, check.context]


# Drop the shapes whose check has finished, so that a later attempt of the same
# shape is taken up and answered out of memory.
func _forget_settled() -> void:
	for shape in _settling.keys():
		if not (_settling[shape] as AbilityCheck).is_open():
			_settling.erase(shape)


func _take_up(scene: ActionScene) -> void:
	_forget_settled()
	for check in scene.raised:
		if _taken.has(check.id):
			continue
		# An attempt of this shape by this character is already being settled and
		# has not finished yet, so this one is left where it is and taken up on a
		# later tick, when the memory branch above will answer it for nothing.
		#
		# Without this, everything a check is supposed to save could be undone by
		# being quick: a model answers in `ModelChannel.THINKS_FOR` ticks, and a
		# character that spoke to the same person again inside that window would
		# find nothing in its memory yet and be rolled for a second time. One
		# attempt per shape has to mean one attempt in flight as well as one on
		# the record.
		if _settling.has(_shape_of(check)):
			continue
		_taken[check.id] = true
		seen.append(check)
		if _settle_from_memory(scene, check):
			continue
		_settling[_shape_of(check)] = check
		if check.is_at_a_person():
			# Nothing to ask: section 6 wrote this class down, so the engine
			# works it out and rolls, and the only call a persuasion can cost is
			# the resolving one, on a success.
			_roll_it(scene, check, AbilityCheck.class_for_talk(
				_sheet_of_target(scene, check)), AbilityCheck.TALK_ABILITY)
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
	check.said_share = float(row.get("said_share", AbilityCheck.NOTHING_JUDGED))
	check.share = float(row.get("share", AbilityCheck.NOTHING_JUDGED))
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
	if check.is_at_a_person():
		# A remembered persuasion earns nothing further, and there is nothing to
		# do again. The context of a check at a person *is* that person, so this
		# is the same conversation being had a second time with the same
		# character -- not the same trick worked on a second chest -- and being
		# thanked again for it is exactly the cheese section 6 forbids.
		check.operations.append({
			"ok": false, "line": "goodwill", "target": check.target,
			"reason": "it was already earned from %s, and is not earned twice"
				% check.target_named,
		})
		return
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
	var prompt := _question_for(scene, check, stage)
	_open[check.id] = {
		"stage": stage, "check": check,
		"ticket": channel.ask(prompt, scene.tick),
		"digest": CheckPrompt.digest_of(prompt),
	}
	calls += 1
	journal.append("tick %d  check #%d asked the %s question (%s)" % [
		scene.tick, check.id, stage, _open[check.id]["digest"],
	])


# Which of the three questions this is. A check at a person never reaches the
# judging one -- see `_take_up` -- so the only question it can put is the last.
func _question_for(scene: ActionScene, check: AbilityCheck, stage: String) -> String:
	if stage == JUDGING:
		return CheckPrompt.judging_for(check, _sheet_of(scene, check))
	if check.is_at_a_person():
		return GoodwillPrompt.for_a_persuasion(
			check.attempt, check.target_named, check.who_named,
			_sheet_of_target(scene, check))
	return CheckPrompt.resolving_for(check, _sheet_of(scene, check), scene)


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

	_roll_it(scene, check, int(judgement["dc"]), String(judgement["ability"]))


## The roll itself, whoever named the class.
##
## Both sorts of check pass through here and the arithmetic is the same for
## both: bound the class, take the character's own score off its own sheet, hash
## the die, compare. What differs above it is only where `said_class` came from
## -- a model's answer for a thing, `AbilityCheck.class_for_talk` for a person --
## and nothing below this line can tell which.
func _roll_it(
	scene: ActionScene, check: AbilityCheck, said_class: int, ability: String
) -> void:
	check.said_class = said_class
	check.ability = ability
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
	if check.is_at_a_person():
		_won_round(scene, check, reply)
		return
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
	_settle_after_resolving(scene, check)


# What a persuasion the engine rolled a success for comes to.
#
# The model is asked one number and nothing else it writes is acted on. Three
# ways it can go, and all three are written into the check where a transcript
# reads them back: a reply with no share in it changes nothing; a share outside
# what `Goodwill` accepts changes nothing; and a share it accepts is bounded to
# what one thing may be worth and handed to `RelationshipGraph.favoured`, which
# refuses it again if it is out of range and otherwise raises the listener's
# trust toward the speaker by it.
func _won_round(scene: ActionScene, check: AbilityCheck, reply: String) -> void:
	var judged := Goodwill.read(reply)
	if not bool(judged["read"]):
		check.operations.append({
			"ok": false, "line": ModelPrompt.said_line(reply), "target": check.target,
			"reason": "%s, so nothing changed" % judged["why"],
		})
		_settle_after_resolving(scene, check)
		return
	check.said_share = float(judged["said"])
	check.share = Goodwill.bounded(check.said_share)
	# The one thing this file does with the number: write it into the world's own
	# record of goodwill earned. What that comes to for the two characters is the
	# relationship graph's, folded in by `CharacterUpkeep` along with everything
	# else that has happened -- and this file names neither.
	var written := scene.note_favour(
		check.who, check.target, check.share, check.attempt)
	var line := "%s=%s" % [Goodwill.KEY, Goodwill.said_as(check.said_share)]
	if not written:
		check.operations.append({
			"ok": false, "line": line, "target": check.target,
			"reason": "the world would not record goodwill earned by it, so nothing"
				+ " changed",
		})
		_settle_after_resolving(scene, check)
		return
	favoured += 1
	earned += check.share
	check.operations.append({
		"ok": true, "line": line, "target": check.target,
		"reason": "%s said %s, which the engine recorded as %s of goodwill earned"
			% [
				Goodwill.KEY, Goodwill.said_as(check.said_share),
				Goodwill.said_as(check.share),
			]
			+ " by %s from %s" % [check.who_named, check.target_named],
	})
	_settle_after_resolving(scene, check)


# The tail both resolving branches share: the check is settled, what it came to
# is written into the journal, and it goes into the character's memory.
func _settle_after_resolving(scene: ActionScene, check: AbilityCheck) -> void:
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
	return _sheet_at(scene, check.who)


# The sheet of whoever the check is *about*: the listener for a check at a
# person, which is whose wisdom and standing the class is read off. For a check
# at a thing there is no sheet there at all, because a thing keeps none.
static func _sheet_of_target(scene: ActionScene, check: AbilityCheck) -> Character:
	return _sheet_at(scene, check.target)


static func _sheet_at(scene: ActionScene, id: int) -> Character:
	var actor := scene.actor_of(id)
	if actor == null or actor.piece == null or not (actor.piece is Commander):
		return null
	return (actor.piece as Commander).sheet


static func _memory_of(scene: ActionScene, check: AbilityCheck) -> CharacterMemory:
	var sheet := _sheet_of(scene, check)
	return null if sheet == null else sheet.memory
