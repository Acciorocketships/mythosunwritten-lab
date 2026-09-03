extends RefCounted
## Section 2.2's control loop: an action takes time, the character thinks again
## while it runs, and it thinks again at once when something happens.
##
## Section 2.2 is three sentences and this file is all three of them:
##
##   1. *"While an action is in progress"* -- an action costs ticks. What it
##      costs is the `occupies` column of `ActionCatalog.ROWS`, because a cost
##      written here would be a thirteenth list of the twelve actions.
##   2. *"the agent re-evaluates at some frequency (it may change its mind, but
##      is biased toward continuing)"* -- the frequency is `REVIEW_EVERY` and the
##      bias is `CONTINUE_BIAS`. One constant each, used in one place each.
##   3. *"It re-evaluates immediately when an action finishes or is interrupted
##      (attacked while moving, combat starts, dialogue opens, new threat)"* --
##      those four are `FINISHED`, `ATTACKED`, `COMBAT_BEGAN` and `SPOKEN_TO`,
##      and each is noticed by comparing the world against what it was a tick
##      ago rather than by anybody reporting it.
##
## ## What the loop adds, and what it is careful not to add
##
## It adds *when* an action is resolved and nothing about *how*. Every action
## still goes to `ActionEngine.resolve` and comes back as one `ActionOutcome`,
## because an atomic action's effect is indivisible -- that is what makes it
## atomic, and it is what lets one engine answer serve a person and a program
## alike. What the loop contributes is that carrying the action out costs the
## character a span of ticks, and the world only changes when the span completes.
## An abandoned span therefore never reaches the engine: a character interrupted
## halfway to somewhere did not go.
##
## It also asks nothing about who is deciding. The decision function is read off
## `Character.decide` and called with `(scene, actor)`, exactly as
## `DecisionSource.drive` calls it; a person's recorded choices and a program's
## rule reach this file as the same `Callable` and there is nothing here to tell
## them apart.
##
## ## Servicing a character is more than asking it
##
## Every character serviced here is first handed to `CharacterUpkeep`, which
## maintains the two stores the sheet declares for everybody: the world closes
## the goals its own state says are finished, and the character takes in its
## surroundings at the stated cadence. That happens before the decision function
## is called and regardless of what the decision function is -- the loop passes
## every character through it and has nothing to branch on if it wanted to. See
## `sim/character_upkeep.gd` for the cadence and why it is that one; the loop
## contributes only the servicing.
##
## ## On a board, a turn is what a character spends
##
## A character in the overworld chooses whenever it is free. One standing on a
## tactical board chooses on its own turn and once on it, because section 3.6
## makes the turn the unit of what a commander may spend. That is `_may_choose`,
## and it is the loop's half of the seam between an action measured in ticks and
## a turn measured in turns: the other half is `ActionScene.fight_step()`, which
## does not play a turn while the commander whose turn it is is part-way through
## an attack. Between them, a blow a commander chose lands on that commander's
## own turn and spends it.
##
## The gate is on *choosing* only. An action already under way runs on whosever
## turn it is, so being struck part-way through something is still possible and
## is still an interruption -- and a character that has committed nothing holds
## up nothing, which is why a decision that never comes cannot stall a fight.
##
## ## Nothing here reads a clock
##
## Every duration in this file is a count of ticks out of `ActionScene.tick`.
## There is no wall clock, no seconds, no frame counter and no measurement of how
## long anything took to compute -- which is also the whole of how a slow
## decision function is handled. A decision function that is not ready answers
## `null`, the character stands in the world with nothing committed, and the loop
## carries on servicing everybody else in the same tick. Waiting is therefore
## counted in ticks like everything else, and one character's deliberation cannot
## reach another's: the one number the loop draws is *hashed* from the seed, the
## character and the tick rather than taken off a stream, so what a character
## sees does not depend on how often it or anybody else has been asked before.
## That is the discipline `sim/damage.gd` already keeps with the die, for the
## same reason -- a stream would make the answer depend on the order of the
## questions.
class_name ControlLoop

## The cadence: while an action is in progress, the character re-evaluates every
## this-many ticks. Section 2.2's "some frequency", stated once. Twenty ticks is
## a second at the rate the world is stepped, so this is a character having
## second thoughts about four times a second while it walks.
const REVIEW_EVERY := 5

## The bias toward continuing: at a re-evaluation that proposes something
## *different*, this is the chance the character stays with what it is already
## doing. Section 2.2's "may change its mind, but is biased toward continuing",
## as one number.
##
## It is a chance rather than a margin because a decision function returns a
## choice and not a score -- there is no number to compare against a threshold,
## and inventing one would put a rule about preferences inside the loop, which is
## the one thing this layer must not hold.
const CONTINUE_BIAS := 0.85

## The four things section 2.2 says end a commitment early. `FINISHED` is the
## action running out of ticks; the other three are the world changing under a
## character that is still busy.
const FINISHED := "finished"
const ATTACKED := "attacked"
const COMBAT_BEGAN := "combat began"
const SPOKEN_TO := "spoken to"

## The world being lived in.
var scene: ActionScene = null

## What the bias's one number is hashed from, together with the character and the
## tick. The bias is the only thing in the loop that draws a number at all, so
## this is the whole of what changing it can change.
var seed_value: int = 0

## The bias actually in force. It is `CONTINUE_BIAS` and the only reason it is a
## field at all is that a claim about a number is worth nothing without a run at
## a different one: `ScriptedLoop.bias_measurement()` sets it to zero to show
## what the loop does with the bias taken away.
var continue_bias: float = CONTINUE_BIAS

## Everything that happened, one line per event, in tick order. What the report
## prints and what the tests read.
var journal := PackedStringArray()

## What the world does for each character it services, beside asking it: the two
## stores on its sheet, maintained on a path every character passes. See the note
## above. It is a field so that a run can hand it what is watching the characters
## for the "recently changed" part of an observation, and so that a report can
## read off how much witnessing was done.
var upkeep := CharacterUpkeep.new()

var _busy: Dictionary = {}
var _ticks: Dictionary = {}
var _resolved: Dictionary = {}
var _thinking: Dictionary = {}
var _watched: Dictionary = {}
var _reviews: int = 0
var _changes: int = 0
var _interruptions: Dictionary = {}
var _chosen_on: Dictionary = {}
var _answers: Dictionary = {}


## A loop over a scene, with a seed for the bias draws.
##
## The scene is handed a window onto what each character is part-way through, so
## that `ActionScene.fight_step()` can let a commander's turn last as long as the
## weapon action it committed to. The window is a reader over the same `_busy`
## this file keeps -- one account of what somebody is doing, read from two places
## -- and it closes over that dictionary rather than over this loop, so a scene
## holding it does not hold the loop that made it.
static func on(
	world: ActionScene, from_seed: int, watched: ObservationTrail = null
) -> ControlLoop:
	var loop := ControlLoop.new()
	loop.scene = world
	loop.seed_value = from_seed
	loop.upkeep = CharacterUpkeep.watching(watched)
	loop._watched = loop._watch()
	var busy := loop._busy
	world.in_progress = func(id: int) -> Action:
		var doing: Activity = busy.get(id, null)
		return null if doing == null else doing.action
	return loop


## How many ticks carrying an action out costs.
##
## The catalogue's `occupies` column, with one reading on top of it: a wait names
## its own duration, because section 2.1 spells the action "wait (duration)" and
## a duration nobody honoured would not be one. Every other action costs what its
## row says.
static func occupies(chosen: Action) -> int:
	if chosen == null:
		return 0
	var stated := ActionCatalog.occupies_of(chosen.kind)
	if chosen.kind == ActionCatalog.WAIT:
		return maxi(stated, int(chosen.param("ticks", 0)))
	return stated


# --- Living ---------------------------------------------------------------


## One tick of the world.
##
## Everybody is serviced once, in id order, and then the tick's disturbances are
## noticed and acted on. Ordering the two that way is deliberate: a blow struck
## in this tick interrupts its victim in this tick, whether the victim was
## serviced before or after the one who struck it.
func step() -> void:
	scene.advance(1)
	for one in scene.actors.duplicate():
		if not scene.actors.has(one):
			continue
		_ticks[one.id] = ticks_of(one.id) + 1
		_serve(one)
	_notice_disturbances()
	_watched = _watch()


## Live for a number of ticks, and hand back everything that happened.
func run(ticks: int) -> PackedStringArray:
	for _tick in maxi(0, ticks):
		step()
	return journal


# --- What one character does in one tick ----------------------------------


func _serve(one: Combatant) -> void:
	if not _can_act(one):
		return
	upkeep.serve(scene, one)
	if not _busy.has(one.id):
		if _may_choose(one):
			_ask(one)
		return
	var doing: Activity = _busy[one.id]
	if doing.spend():
		_complete(one, doing)
	elif doing.elapsed(scene.tick) % REVIEW_EVERY == 0:
		_review(one, doing)


# Ask for a choice and commit to it. A decision function with no answer -- a
# recorded person out of recorded choices, or one still deliberating -- leaves
# the character standing in the world with nothing committed, and it is asked
# again the next time it may choose: next tick in the overworld, and on its next
# turn on a board.
func _ask(one: Combatant) -> void:
	var chosen := _decide(one)
	if chosen == null:
		if not _thinking.get(one.id, false):
			_thinking[one.id] = true
			_note(one, "has not decided yet, and waits in the world")
		return
	_thinking[one.id] = false
	_commit(one, chosen)


func _commit(one: Combatant, chosen: Action) -> void:
	var doing := Activity.begun(chosen, scene.tick, occupies(chosen))
	_busy[one.id] = doing
	if one.fighting:
		_chosen_on[one.id] = _this_turn()
	_note(one, "began %s, %d ticks" % [chosen.line(), doing.occupies])


# The span ran out: the action is resolved, and the character re-evaluates
# immediately -- section 2.2's first named event, and the reason the next
# `began` line carries the same tick as this one.
func _complete(one: Combatant, doing: Activity) -> void:
	_busy.erase(one.id)
	var outcome := ActionEngine.resolve(scene, one, doing.action)
	_resolved[one.id] = actions_of(one.id) + 1
	_answers[one.id] = {
		"tick": scene.tick,
		"action": doing.action.line(),
		"line": outcome.line(),
		"reason": outcome.reason,
		"ok": outcome.ok,
	}
	_count(FINISHED)
	_note(one, "%s %s -> %s" % [FINISHED, doing.action.line(), outcome.line()])
	if _can_act(one) and _may_choose(one):
		_ask(one)


# A re-evaluation while the action is still running. This is the only place the
# bias is consulted, and it is consulted only when the character actually wants
# something else: staying with a plan nobody proposed changing is not a decision.
func _review(one: Combatant, doing: Activity) -> void:
	_reviews += 1
	var proposed := _decide(one)
	if proposed == null:
		_note(one, "thought again %s, had nothing else in mind" % _through(doing))
		return
	if proposed.line() == doing.action.line():
		_note(one, "thought again %s, wanted the same thing" % _through(doing))
		return
	if _draw_for(one) < continue_bias:
		_note(one, "thought again %s, kept %s over %s" % [
			_through(doing), doing.action.line(), proposed.line(),
		])
		return
	_changes += 1
	_note(one, "changed its mind %s, dropped %s for %s" % [
		_through(doing), doing.action.line(), proposed.line(),
	])
	_busy.erase(one.id)
	_commit(one, proposed)


# --- What the world does to a character -----------------------------------


# The three interruptions that are not the action running out, applied to
# everybody still busy. An interrupted action is abandoned rather than resolved:
# a character struck halfway to somewhere did not get there.
func _notice_disturbances() -> void:
	for one in scene.actors.duplicate():
		if not _busy.has(one.id) or not scene.actors.has(one):
			continue
		var cause := _disturbance(one)
		if cause == "":
			continue
		var doing: Activity = _busy[one.id]
		_busy.erase(one.id)
		_count(cause)
		_note(one, "interrupted (%s), abandoned %s" % [cause, doing.line()])
		if _can_act(one) and _may_choose(one):
			_ask(one)


# Why a character stopped what it was doing, or "".
#
# Every one of these is read off the world by comparing it against what it was
# at the end of the last tick. Nobody reports an interruption and nothing has to
# remember to: a blow that lands, a fight that starts and a word addressed to
# somebody are all things that are simply true of the scene afterwards.
func _disturbance(one: Combatant) -> String:
	if one.piece != null and one.piece.health < int(
			_watched["health"].get(one.id, one.piece.health)):
		return ATTACKED
	if scene.fight != null and not _watched["fighting"] and one.fighting:
		return COMBAT_BEGAN
	if _was_spoken_to(one.id):
		return SPOKEN_TO
	return ""


# Whether somebody addressed this character since the last tick. A shout is not
# a conversation opening -- section 2.2 names "dialogue opens", and shouting into
# a field is the one kind of speech nobody has to answer -- so only speech with
# this character named counts.
func _was_spoken_to(id: int) -> bool:
	for index in range(int(_watched["said"]), scene.said.size()):
		var spoken: Dictionary = scene.said[index]
		if spoken["to"] == id and spoken["speaker"] != id:
			return true
	return false


# The world as it was, in the three respects an interruption is read from.
func _watch() -> Dictionary:
	var health := {}
	for one in scene.actors:
		if one.piece != null:
			health[one.id] = one.piece.health
	return {
		"health": health,
		"fighting": scene.fight != null,
		"said": scene.said.size(),
	}


# --- Reading the loop -----------------------------------------------------


## How many ticks the loop has serviced a character for. The number the
## non-blocking claim is quoted in: a character whose decision function has not
## answered still gets its tick, and so does everybody else.
func ticks_of(id: int) -> int:
	return int(_ticks.get(id, 0))


## How many actions a character has actually had resolved.
func actions_of(id: int) -> int:
	return int(_resolved.get(id, 0))


## Whether a character is part-way through something.
func is_busy(id: int) -> bool:
	return _busy.has(id)


## What a character is doing, or null.
func doing_of(id: int) -> Activity:
	return _busy.get(id, null)


## Whether a character has been asked and had no answer.
func is_thinking(id: int) -> bool:
	return bool(_thinking.get(id, false))


## What the engine last answered a character, or an empty dictionary for one it
## has never answered: `{tick, action, line, reason, ok}`.
##
## Every string in it is the engine's, verbatim -- `Action.line()` for what was
## chosen and `ActionOutcome.line()` for what came of it, which for a refusal
## carries `ActionOutcome.reason` and so carries section 2.1's "returned reason"
## in the words the resolver wrote it in. The loop copies; it does not phrase.
##
## It exists because a refusal is addressed to whoever chose, and whoever chose
## may be a person who needs to be told. The journal has always carried the same
## sentence, and reading a sentence back out of a line of prose is not reading
## it: this is the same fact with the parsing taken away. A copy comes back, so
## a caller cannot write into the loop's record of what happened.
func answer_of(id: int) -> Dictionary:
	var answer: Variant = _answers.get(id, null)
	return {} if answer == null else (answer as Dictionary).duplicate()


## Every count the loop keeps: how many mid-action re-evaluations happened, how
## many of them changed the decision, and how many times each of section 2.2's
## four events fired.
func counts() -> Dictionary:
	var kept := {"reviews": _reviews, "changes": _changes}
	for cause in [FINISHED, ATTACKED, COMBAT_BEGAN, SPOKEN_TO]:
		kept[cause] = int(_interruptions.get(cause, 0))
	return kept


## How often a mid-action re-evaluation changed the decision, as a fraction of
## the re-evaluations that happened at all. Zero when nothing was re-evaluated.
func change_rate() -> float:
	return 0.0 if _reviews == 0 else float(_changes) / float(_reviews)


# --- The furniture --------------------------------------------------------


# Call a character's own decision function. The whole of what this file knows
# about deciding.
func _decide(one: Combatant) -> Action:
	var sheet := _sheet_of(one)
	if sheet == null or not sheet.decide.is_valid():
		return null
	var chosen: Variant = sheet.decide.call(scene, one)
	return chosen if chosen is Action else null


func _can_act(one: Combatant) -> bool:
	if one == null or one.piece == null or not one.piece.is_alive():
		return false
	return _sheet_of(one) != null


# Whether a character may choose something new right now.
#
# Off a board, always: the overworld is real time and nothing rations a choice
# in it. On one, a commander chooses on its own turn and once on it, because
# section 3.6 makes the turn the unit of what a character may spend -- one that
# could choose on somebody else's turn would be spending a turn that is not its
# own, and one that could choose twice on its own would spend that turn twice.
#
# This gates *choosing* and nothing else. An action already under way keeps
# running whosever turn it is, so a character can still be struck part-way
# through something, which is what section 2.2's second interruption is.
func _may_choose(one: Combatant) -> bool:
	if scene.fight == null or not one.fighting:
		return true
	if scene.fight.active_member() != one:
		return false
	return String(_chosen_on.get(one.id, "")) != _this_turn()


# Which turn of which fight is being played, as one string. A commander takes
# exactly one turn per round, so the round number names its turn; the count of
# fights is folded in so that round 1 of a second fight is not round 1 of the
# first.
func _this_turn() -> String:
	if scene.fight == null or scene.fight.match_state == null:
		return ""
	return "%d:%d" % [scene.fights_begun, scene.fight.match_state.round_number]


static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


# The one number the loop draws, hashed from the seed, the character and the
# tick rather than taken off a stream.
#
# Two re-evaluations of one character can never fall on the same tick, so this is
# a different number every time it is consulted; and it is a function of *which*
# re-evaluation it is rather than of how many came before it, which is what makes
# a slow character harmless to everybody else's numbers.
func _draw_for(one: Combatant) -> float:
	return SimRng.hash_unit(seed_value, one.id, scene.tick)


func _count(cause: String) -> void:
	_interruptions[cause] = int(_interruptions.get(cause, 0)) + 1


# How far through its span an action is, said the way the journal says it.
static func _through(doing: Activity) -> String:
	return "at %d/%dt" % [doing.occupies - doing.remaining, doing.occupies]


func _note(one: Combatant, what: String) -> void:
	journal.append("t=%3d  %-6s %s" % [scene.tick, ActionScene.name_of(one), what])
