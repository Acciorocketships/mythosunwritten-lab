extends RefCounted
## One character's mind, when that mind is a language model.
##
## It is asked the same question every decision function in this project is
## asked -- what does this character do next, given the world and the character
## -- and it answers it in four steps and no others:
##
##   1. assemble what the character can see, with `Observation.of()`;
##   2. write that out as a prompt, with `ModelPrompt.written_for()`;
##   3. put the question to a `ModelChannel` and take a ticket for it;
##   4. read the answer back as an `Action`, with `ModelPrompt.action_of()`.
##
## Between 3 and 4 the world goes on turning. The mind is polled, not waited on:
## while the answer is outstanding it returns null, which every driver in this
## project already reads as "nothing chosen, the character stands there", and
## every other character in the scene is serviced in the usual way on every one
## of those ticks. That is the whole of section 12's "the sim never blocks on an
## LLM", and it needs nothing of the control loop that the loop did not already
## do for a recorded person who has run out of choices.
##
## ## It is asked more often than it asks
##
## `ControlLoop` calls a decision function again every `REVIEW_EVERY` ticks to
## ask whether the character has changed its mind, and a mind that started a new
## exchange on every one of those would make a model call four times a second and
## spend a recorded exchange in a handful of ticks. So the mind is read the way
## `DecisionSource.plan` is read: it keeps its answer against the number of
## actions the character has attempted, which the world counts in
## `ActionScene.actions_taken`. Asked again while its action is still running it
## offers the same action back -- the review line reads "wanted the same thing"
## -- and it asks the model again only once the world says the character has
## actually had a go. One action resolved, one exchange.
##
## An answer the catalogue cannot read is one of those. It is offered to the
## engine like any other, refused there in the catalogue's own words, and counted
## as the turn it spent, so the next review opens a new exchange rather than
## handing the same unreadable line back for the rest of the run. Nothing here
## reads the refusal or knows there was one: what closes the loop is the world's
## count moving, which is the same thing that moves for a plan and for a person.
##
## ## Memory, which lives on the character and not here
##
## The mind holds no memory of its own. What the character remembers is a
## `CharacterMemory` on that character's own sheet, and the mind only reads it --
## so a mind replaced between two decisions loses nothing, and a character
## carried out of this scene carries its memory with it.
##
## This file *reads* that store and does not fill it. What a character has
## witnessed is written down by `CharacterUpkeep`, on the path every character
## passes whoever is deciding for it, before any decision function is called --
## so a character a person drives accrues a memory exactly as this one does, and
## a mind that filled the store itself would be an affordance of having a model
## for a mind. Two things happen around each question:
##
##   1. the prompt carries every lesson the character has kept and the most
##      recent few lines of its log, both read off the character's own sheet;
##   2. a reply that names one of the three tools rather than an action is acted
##      on here -- `recall` looks back through the same store and the answer goes
##      into the next prompt, `learn` keeps a sentence, `done` asks `GoalCheck` to
##      close one of the character's own goals -- and then the question is asked
##      again. A tool call costs one exchange and changes nothing in the world,
##      which is why it is not an action.
##
## `learn` is the one thing here that writes into a store, and it writes into the
## lessons rather than the log: a lesson is a sentence somebody chose to keep,
## which is a decision and not a perception, and the eventual human-input layer
## needs a way to keep one too. It goes in through the same door every writer
## uses, carrying the observation it was drawn from.
##
## What a recall turned up is the only thing the mind keeps between questions, and
## it keeps it for exactly one: it is section 10's "working context, short-lived,
## not persisted", and persisting it would make the tool a slow way of growing the
## packet.
##
## ## What a tool costs, which the world says and this file only asks
##
## A tool changes nothing in the world, so nothing about the world stops one
## being asked again on the very next tick -- and a cheap model asked the same
## one four thousand seven hundred times in a single run, resolving no action at
## all. The world now prices them: `ToolBudget.asked()` is put the question
## before any of the three is carried out, answers whether this character may,
## and past its budget refuses in the world's own words and charges the character
## a turn. A refused tool is carried out on nothing, is kept on the turn like any
## other answer, and goes into the next prompt so the character is told what it
## was told. Nothing about the rule is here: this file asks and obeys, and a
## person's hand on the same door gets the same sentence.
##
## ## Goals, which also live on the character and not here
##
## The same arrangement as the memory, and read the same way. What the character
## is after is a `GoalSet` on its own sheet; this file reads it into the prompt
## and neither declares one nor closes one out of the world's state. Which goals
## the *world* says are finished is settled by `CharacterUpkeep` before any
## decision function is called, so a goal naming a position, an inventory or a
## trade closes for every character on the tick the world's own state answers it.
##
## The one thing a character may close for itself is a goal in its own words that
## names nothing the world holds, and the `done` tool is one caller of the shared
## closing that does it -- `GoalCheck.close_by_hand()`, which is where the rule
## lives, refuses any of the seven kinds the world answers with the world named
## as the reason, and writes both the closing and the refusal down on the
## character's own goal set. A human-input layer calling the same function gets
## the same answer and leaves the same record.
##
## ## What it does not do
##
## It holds no relationship and no opinion, and it resolves nothing. What comes
## back is an `Action` -- a choice -- and `ActionEngine` is what says whether the
## world allows it. A choice the world refuses comes back as an `ActionOutcome`
## carrying a sentence, the same sentence any other caller would get for the same
## choice.
class_name ModelMind

## Where answers come from.
var channel: ModelChannel = null

## What has been watching this character, for the "recently changed" part of the
## observation. Optional: with none, that part of the packet is absent with its
## own stated reason, exactly as it is for anybody else.
var trail: ObservationTrail = null

## One row per question that has come back: what was seen, what was asked, what
## the model said, what that read as, and when. What the run prints and what the
## tests read.
var turns: Array[Dictionary] = []

## How many times each tool has been used across the run, for the report that
## measures what the memory came to.
var recalls: int = 0
var lessons_written: int = 0

## How many tool calls the world refused for costing it no time -- `ToolBudget`'s
## answer, counted here only so a run can print it.
var refused_asks: int = 0

## What every ask of this mind came to. Four numbers that sum: `consulted` is the
## total, and it is `opened` plus `held` plus `polled`.
##
## A driver asks a decision function what its character does next once when
## nothing is committed and again every `ControlLoop.REVIEW_EVERY` ticks while an
## action is running. Only some of those asks cost a model call, and these are the
## numbers that say which:
##
##   * `opened` -- a new question was put to the model. This is the run's call
##     volume, and the only one of the four that costs anything.
##   * `held` -- the mind already had an answer for the number of actions the
##     world says this character has carried out, and offered the same action
##     back. This is section 2.2's bias toward continuing, priced: being asked
##     again mid-action is *this*, and it is not a call.
##   * `polled` -- a question was already outstanding, so the channel was read
##     once and, if the answer was not there yet, nothing was chosen. This is the
##     asking that happens while a character stands in the world waiting, and it
##     is not a call either.
var consulted: int = 0
var opened: int = 0
var held: int = 0
var polled: int = 0

var _ticket: int = -1
var _asked_for: int = -1
var _seen: Observation = null
var _answer: Action = null
var _answered_for: int = -1
var _looked_back: Dictionary = {}


## A mind answering out of a channel.
static func with_channel(from: ModelChannel, watching: ObservationTrail = null) -> ModelMind:
	var mind := ModelMind.new()
	mind.channel = from
	mind.trail = watching
	return mind


## What this character does next: one action, or null while there is no answer.
##
## The signature `DecisionSource.model()` wraps, and the only method a driver
## ever reaches.
func answer_for(scene: ActionScene, actor: Combatant) -> Action:
	if scene == null or actor == null or channel == null:
		return null
	consulted += 1
	var carried_out := scene.actions_of(actor.id)
	if _answered_for == carried_out and _answer != null:
		held += 1
		return _answer
	if _ticket >= 0 and _asked_for == carried_out:
		polled += 1
		return _take(scene, actor, carried_out)
	_open(scene, actor, carried_out)
	return null


## How many questions have been answered.
func answered() -> int:
	return turns.size()


## Whether the mind is waiting for an answer right now.
func is_waiting() -> bool:
	return _ticket >= 0


# --- Asking ---------------------------------------------------------------


func _open(scene: ActionScene, actor: Combatant, carried_out: int) -> void:
	_seen = Observation.of(scene, actor, trail)
	_ticket = channel.ask(
		ModelPrompt.written_for(
			_seen, memory_of(actor), _looked_back, goals_of(actor)),
		scene.tick)
	opened += 1
	_looked_back = {}
	_asked_for = carried_out
	_answer = null
	_answered_for = -1


## The goals of whichever character is being decided for, or null when the thing
## being decided for keeps no sheet. Read off the character every time, for the
## same reason its memory is: the goals are the character's and the mind is not.
static func goals_of(actor: Combatant) -> GoalSet:
	var sheet := _sheet_of(actor)
	return null if sheet == null else sheet.goals


static func _sheet_of(actor: Combatant) -> Character:
	if actor == null or actor.piece == null or not (actor.piece is Commander):
		return null
	return (actor.piece as Commander).sheet


## The memory of whichever character is being decided for, or null when the thing
## being decided for keeps no sheet.
##
## Read off the character every time rather than held here, because the memory is
## the character's and the mind is not.
static func memory_of(actor: Combatant) -> CharacterMemory:
	var sheet := _sheet_of(actor)
	return null if sheet == null else sheet.memory


# --- Being answered -------------------------------------------------------


# Read the channel once. Still outstanding is null and no record; answered is one
# row in `turns` and, when the answer named an action, that action.
#
# An answer that names no action is recorded as such and the question is asked
# again -- a model that said nothing readable is a model that has not chosen, and
# the alternative, holding the silence against the character forever, would leave
# it standing in the world with nothing to be done about it. That includes an
# answer with nothing in it at all: a provider that declines a question has
# answered it, so the ticket is closed and the note saying why is kept on the
# turn. Telling that apart from "not yet" is what `ModelChannel.has_answered`
# is for. An answer that named
# a tool instead is one of those: the tool is carried out against the character's
# own memory, no action is returned, and the next question carries what it did.
func _take(scene: ActionScene, actor: Combatant, carried_out: int) -> Action:
	var reply := channel.reply_to(_ticket, scene.tick)
	if reply == "" and not channel.has_answered(_ticket):
		return null
	var chosen := ModelPrompt.action_of(reply)
	var used := {} if chosen != null else ModelPrompt.tool_of(reply)
	turns.append({
		"tick": scene.tick,
		"waited": channel.waited_for(_ticket),
		"seen": _seen,
		"observed": _seen.digest(),
		"said": ModelPrompt.said_line(reply),
		"chose": chosen,
		"tool": String(used.get("tool", "")),
		"asked_for": String(used.get("text", "")),
		"found": int(used.get("found", 0)),
		"refused": "",
		"note": channel.note_on(_ticket),
	})
	_ticket = -1
	if not used.is_empty():
		_use(used, turns[turns.size() - 1], actor, scene)
		return null
	if chosen == null:
		return null
	_answer = chosen
	_answered_for = carried_out
	return chosen


# One tool call, carried out against the character's own memory.
#
# The world is asked first, because a tool costs it no time and something has to:
# `ToolBudget.asked()` answers whether this character may make another such ask,
# and one past its budget is refused there and costs the character a turn. A
# refused tool is not carried out at all -- nothing is looked up, nothing is
# learned and no goal is closed -- and what the world said goes onto the turn and
# into the next prompt.
#
# `recall` reads the same store the recent lines came out of and keeps what it
# found for the next prompt alone. `learn` writes one sentence into the lessons,
# stamped with the observation it was drawn from -- which is the only door that
# store has. Neither touches the world, and neither closes the turn: the mind has
# no action, so the character stands where it is and is asked again.
func _use(
	used: Dictionary, turn: Dictionary, actor: Combatant, scene: ActionScene
) -> void:
	var allowed := ToolBudget.asked(scene, actor)
	if not bool(allowed["allowed"]):
		refused_asks += 1
		turn["refused"] = String(allowed["why"])
		_looked_back = {
			"tool": String(used["tool"]),
			"about": String(used["text"]),
			"refused": String(allowed["why"]),
		}
		return
	if String(used["tool"]) == ModelPrompt.DONE:
		_close_by_hand(String(used["text"]), turn, actor, scene)
		return
	var remembered := memory_of(actor)
	if remembered == null:
		return
	var asked_for := String(used["text"])
	if String(used["tool"]) == ModelPrompt.RECALL:
		var found := remembered.recall(asked_for)
		_looked_back = {"about": asked_for, "lines": found}
		turn["found"] = found.size()
		recalls += 1
		return
	if remembered.learn(asked_for, _seen):
		lessons_written += 1


# The character closing one of its own goals, through the shared closing.
#
# Everything about which closings are allowed is `GoalCheck.close_by_hand()`'s:
# a goal naming something the world holds -- a position, an inventory, a trade --
# is refused there with the world named as the reason, and the goal in the
# character's own words closes. This file passes the number the model named and
# keeps what came back on the turn, so that the transcript of a question says
# what the answer to it was; the record a run prints is on the character's own
# goal set, written by the same call whoever made it.
func _close_by_hand(
	numbered: String, turn: Dictionary, actor: Combatant, scene: ActionScene
) -> void:
	var goals := goals_of(actor)
	if goals == null:
		return
	var answer := GoalCheck.close_by_hand(
		goals, numbered.lstrip("#").strip_edges().to_int(), scene.tick)
	turn["refused"] = String(answer["why"])


## Anything the channel has to say about the question outstanding -- that the
## recording has no reply for it, or that a live call came back empty. "" when
## nothing is outstanding or nothing is wrong. Printed by the run rather than
## acted on: a mind with no answer waits, whatever the reason.
func waiting_note() -> String:
	return "" if _ticket < 0 or channel == null else channel.note_on(_ticket)
