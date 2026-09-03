extends RefCounted
## Every character in a scene whose mind is a language model, and the numbers a
## run reports about what that came to.
##
## A `ModelMind` is one character's mind. This is the several of them a run has
## at once, standing in one scene, sharing one `ModelChannel` and answering
## independently of each other. It exists for two reasons and no others:
##
##   1. **to hand them out** -- `over()` puts a mind on each named character's
##      own sheet, as `DecisionSource.model`, which is the same `Callable` shape
##      a written-down plan and a rule are put on. Nothing here is a second way
##      of deciding; it is the one way, done five times.
##   2. **to be counted** -- how many questions the run put, per character and in
##      total, how many of the asks those questions came out of, and how many
##      answers were outstanding at the same moment. Those are the numbers that
##      say whether the deferred engineering of section 12 is ever needed, and
##      they are read off the minds rather than instrumented anywhere else.
##
## ## Several answers outstanding at once is the ordinary case, not a mode
##
## Nothing in this file makes concurrency happen and nothing in it could prevent
## it. Each mind takes its own ticket from the channel and is polled on its own
## character's tick; a mind with no answer yet returns null, which is what a
## driver already reads as "nothing chosen". So while one character is waiting,
## every other character -- model-driven or not -- is serviced exactly as it
## would be if nobody were waiting at all, and two, three or five outstanding
## questions are the same thing happening more than once rather than a queue.
## `waiting()` is what a run samples every tick to print that as tick counts.
##
## ## What an hour of play would cost
##
## The one number this file states rather than reads: `TICKS_A_SECOND`, the rate
## `ControlLoop` says the world is stepped at in its own words -- twenty ticks is
## a second, which is what makes its five-tick review "about four times a second
## while it walks". It is written here rather than added to the loop because the
## loop has no use for it: no line of the simulation reads a clock, and this is
## arithmetic done by a report about the simulation, not by the simulation.
class_name ModelCast

## The rate the world is stated to be stepped at, in ticks. See the note above.
const TICKS_A_SECOND := 20

## How many ticks an hour of play comes to at that rate.
const TICKS_AN_HOUR := TICKS_A_SECOND * 60 * 60

## The channel every mind in the cast asks through. One channel, several askers:
## a ticket belongs to whoever took it, and an answer to one is not an answer to
## another.
var channel: ModelChannel = null

## The characters this cast drives, in the order they were given minds -- which
## is the order they stand in the scene, and so the order the loop services them
## in.
var order := PackedStringArray()

## Each of those characters' minds, by name.
var minds: Dictionary = {}


## Put a model mind on every named character's own sheet.
##
## The names are looked up in the scene; a name nothing in the scene answers to
## is skipped rather than invented, so a caller cannot silently drive a character
## that is not there. Every mind gets the same channel and the same observation
## trail, because both are facts about the run rather than about a character.
static func over(
	scene: ActionScene, from: ModelChannel, watching: ObservationTrail,
	names: Array
) -> ModelCast:
	var cast := ModelCast.new()
	cast.channel = from
	for who in names:
		var sheet := _sheet_named(scene, who)
		if sheet == null:
			continue
		var mind := ModelMind.with_channel(from, watching)
		sheet.decide = DecisionSource.model(mind)
		cast.order.append(who)
		cast.minds[who] = mind
	return cast


## One character's mind, or null.
func mind_of(who: String) -> ModelMind:
	return minds.get(who, null)


## Whether a name is one of the characters this cast drives.
func drives(who: String) -> bool:
	return minds.has(who)


# --- What the run cost -----------------------------------------------------


## How many questions were put to the model, across the whole cast.
func calls() -> int:
	var found := 0
	for who in order:
		found += (minds[who] as ModelMind).opened
	return found


## How many of those came back and were read.
func answered() -> int:
	var found := 0
	for who in order:
		found += (minds[who] as ModelMind).turns.size()
	return found


## How many times a driver asked any of these minds what to do next.
##
## The number the continue bias is measured against: every one of these is an
## opportunity to call a model, and `calls()` is how many were taken.
func consulted() -> int:
	var found := 0
	for who in order:
		found += (minds[who] as ModelMind).consulted
	return found


## Every turn any of them took, in the order the answers arrived, each row the
## mind's own turn dictionary with the character's name added.
##
## Sorted by the tick the answer landed on and then by the order the characters
## are serviced in, so that the table a run prints reads down the run.
func turns() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for at in order.size():
		var who := order[at]
		var mind: ModelMind = minds[who]
		for index in mind.turns.size():
			var row := (mind.turns[index] as Dictionary).duplicate()
			row["who"] = who
			row["seat"] = at
			row["turn"] = index + 1
			found.append(row)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["tick"]) != int(b["tick"]):
			return int(a["tick"]) < int(b["tick"])
		return int(a["seat"]) < int(b["seat"]))
	return found


## Who is waiting for an answer right now, in cast order. Sampled by a run once
## a tick, which is how "more than one answer outstanding" becomes a count of
## ticks rather than an argument.
func waiting() -> PackedStringArray:
	var found := PackedStringArray()
	for who in order:
		if (minds[who] as ModelMind).is_waiting():
			found.append(who)
	return found


## Anything the channel has to say about a question still outstanding for any of
## them, one line each, or an empty array.
func waiting_notes() -> PackedStringArray:
	var found := PackedStringArray()
	for who in order:
		var note := (minds[who] as ModelMind).waiting_note()
		if note != "":
			found.append("%s: %s" % [who, note])
	return found


# --- The furniture ---------------------------------------------------------


static func _sheet_named(scene: ActionScene, who: String) -> Character:
	for one in scene.actors:
		if one.piece == null or not (one.piece is Commander):
			continue
		var sheet := (one.piece as Commander).sheet
		if sheet != null and sheet.character_name == who:
			return sheet
	return null
