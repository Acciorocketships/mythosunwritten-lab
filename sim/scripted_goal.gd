extends RefCounted
## Does a goal change what a character chooses? One character, one moment, and
## the same question put four times.
##
##     ./run_goal.sh                # replays the recorded exchange
##     ./run_goal.sh --live         # puts the same four questions to a model
##
## A goal is only worth carrying if it *bends* something. This file is the
## measurement of that, and it is built so that the goal is the only thing that
## can be doing the bending. It is the lesson comparison's twin -- same moment,
## same method -- with the one block of the prompt that differs between arms
## being what the character is after rather than what it remembers.
##
## ## How the four arms are made identical
##
## The world is staged from scratch for every arm, from the one seed, and stepped
## the same number of ticks with the same five characters doing the same things.
## The character being asked stands through all of it -- its decision function is
## an empty plan, so it chooses nothing and the world happens around it -- writing
## down what it can see every `ControlLoop.REVIEW_EVERY` ticks, which is the
## cadence a mind is asked at. Four things follow:
##
##   * every arm's observation has the same fingerprint, printed, so the
##     *situation* is the same situation and not merely a similar one;
##   * every arm's memory holds the same log, written out of that one packet, and
##     no arm keeps a lesson -- the memory block is identical in all four;
##   * arm 0 is after nothing; arms 1 to 3 are each after exactly one thing,
##     added to that character's own `GoalSet` the way anything adds one;
##   * every arm's prompt is therefore identical outside its "What you are after"
##     block, which is checked by stripping that block out of all four and
##     comparing what is left.
##
## So a difference in what comes back is a difference the goal made. The run
## prints all four transcripts, says which choices differ from the one with no
## goal, and names the difference in words.
##
## ## The three goals, and why these three
##
## One names a thing lying in the world, one names another character, and one
## names something the world holds no state for at all:
##
##   * **be where the stall stands** -- a short goal about a position, which the
##     world answers by comparing two positions;
##   * **have traded with the other trader** -- a short goal about an exchange,
##     which the world answers out of the trades the engine has honoured;
##   * **be thought well of here** -- a long goal in the character's own words.
##     Nothing in the simulation is being thought well of *here*: there is a
##     sentiment number now, one per ordered pair of characters, but this goal
##     names neither a target nor a threshold and picking either would be this
##     file answering its own question. So the world does not answer it, the
##     prompt says so beside it, and the character is the only thing that can
##     close it.
##
## None of them says what to do. Every one is a state the world could be in, and
## the run measures whether being after a state changes which verb comes back.
##
## The goals are stated here rather than taken off a shipped character because
## this is a controlled comparison: the point is to hold everything else still.
## They are this file's setup for one experiment and not content of the game --
## nothing under `sim/` outside the scripted scenarios declares a goal at all.
class_name ScriptedGoal

## The world the moment is taken from: the shipped run's own, unchanged.
const SEED := ScriptedAgent.SEED
const LOOP_SEED := ScriptedAgent.LOOP_SEED
const PELL := ScriptedAgent.PELL

## How many ticks the world runs before the question is put. The lesson
## comparison's own number, so the two are asking about the same moment.
const WATCHED := ScriptedLesson.WATCHED

## The four arms, by name. What each is after is built in `_goals_for()` below,
## because two of the three name things whose ids the scene hands out.
const ARMS := ["no goal", "the empty stall", "a trade with Rook", "thought well of here"]

## Where the stall stands, which is where arm 1's goal is: a spot on the ground a
## few units off, named as a position so that the goal is about a place and not
## about a thing that might be picked up before the question is put. By the time
## the moment arrives the lantern has gone and the pile with it, which is exactly
## why the goal names the ground.
const STALL := ScriptedScenario.STALL_AT


# --- The one moment, staged for each arm ----------------------------------


## Play every arm and hand back the transcript.
static func play(channel: ModelChannel) -> PackedStringArray:
	var played := played_with(channel)
	var arms: Array[Dictionary] = played["arms"]

	var written := PackedStringArray()
	written.append("does a goal change what is chosen? seed=%d, %d ticks watched"
		% [SEED, WATCHED])
	written.append("  channel    %s -- %s" % [channel.kind, channel.why])
	written.append("  recording  %s" % channel.recorded)
	written.append("  character  %s, standing in the market, choosing nothing while"
		% PELL + " the %d ticks go by" % WATCHED)
	written.append("")
	written.append_array(_same_moment_lines(arms, played))
	written.append("")
	for arm in arms:
		written.append_array(_arm_lines(arm))
		written.append("")
	written.append_array(_difference_lines(arms))
	written.append("")
	written.append_array(_who_closes_lines(arms))
	written.append("")
	written.append_array(_both_hands_lines())
	return written


## Play every arm out of a channel handed in.
static func played_with(channel: ModelChannel) -> Dictionary:
	var arms: Array[Dictionary] = []
	for at in ARMS.size():
		arms.append(_arm(channel, at))
	return {
		"arms": arms,
		"same_situation": _all_same(arms, "observed"),
		"same_outside_goals": _all_same(arms, "bare"),
		"same_memory": _all_same(arms, "memory_block"),
	}


# One arm: the world staged and stepped, one observation taken and witnessed,
# this arm's goal put on the character's own sheet, and the one question put.
static func _arm(channel: ModelChannel, at: int) -> Dictionary:
	var watched := _watched()
	var scene: ActionScene = watched["scene"]
	var actor := _named(scene, PELL)
	var sheet := _sheet(actor)
	var seen := Observation.of(scene, actor, watched["trail"])
	sheet.memory.witness(seen)
	for goal in _goals_for(at, scene):
		sheet.goals.add(goal)

	# The world is asked, before the question is written, which of these it says
	# are finished already -- through the same `CharacterUpkeep` every character
	# is served by, so this arm is settled exactly as a character serviced by the
	# loop is. None of them is finished, at tick 0 of a character that has done
	# nothing, and the run prints what it answered so that is visible rather than
	# assumed.
	var settled: Array = watched["upkeep"].serve(scene, actor)["closed"]
	var prompt := ModelPrompt.written_for(seen, sheet.memory, {}, sheet.goals)
	var ticket := channel.ask(prompt, 0)
	var reply := channel.reply_to(ticket, ModelChannel.THINKS_FOR)
	var chosen := ModelPrompt.action_of(reply)
	return {
		"name": String(ARMS[at]),
		"goals": sheet.goals,
		"answered": _answered_lines(sheet.goals, scene, actor),
		"settled": settled.size(),
		"observed": seen.digest(),
		"prompt": prompt,
		"digest": ModelPrompt.digest_of(prompt),
		"bare": _without_goals(prompt),
		"memory_block": ModelPrompt.memory_block_of(prompt),
		"block": ModelPrompt.goal_lines(sheet.goals),
		"said": ModelPrompt.said_line(reply),
		"chose": chosen,
		"line": "-- nothing readable --" if chosen == null else chosen.line(),
		"sort": "--" if chosen == null else "%s %s" % [
			chosen.kind,
			"at nobody" if chosen.target_id() == ActionCatalog.NOBODY
				else "at #%d" % chosen.target_id(),
		],
		"note": channel.note_on(ticket),
	}


# What this arm is after. Two of the three name something the scene hands an id
# out for, so they are built against the staged scene rather than written down as
# numbers.
static func _goals_for(at: int, scene: ActionScene) -> Array[Goal]:
	match at:
		1:
			return [Goal.of(Goal.BE_AT, {
				"target": ScriptedScenario.WHERE + STALL,
			}, "", Goal.SHORT)]
		2:
			return [Goal.of(
				Goal.TRADED, {"target": _named(scene, ScriptedScenario.ROOK).id},
				"", Goal.SHORT)]
		3:
			return [Goal.unwritten("be thought well of in this market", Goal.LONG)]
	return []


# The world, staged and stepped, with the character standing through it.
#
# Its decision function is an empty plan: it chooses nothing, which every driver
# reads as "the character waits", so nothing about what a model would have done
# in these ticks can differ between arms -- there is nothing to differ.
static func _watched() -> Dictionary:
	var scene := ScriptedAgent.stage(SEED)
	ScriptedScenario.drive(scene)
	_sheet(_named(scene, PELL)).decide = DecisionSource.plan([])
	var trail := ObservationTrail.new()
	trail.note(scene)
	var loop := ControlLoop.on(scene, LOOP_SEED, trail)
	var pell := _named(scene, PELL)
	var remembered := _sheet(pell).memory
	for step in WATCHED:
		loop.step()
		ScriptedScenario._fight_step(scene)
		trail.note(scene)
		if (step + 1) % ControlLoop.REVIEW_EVERY == 0:
			remembered.witness(Observation.of(scene, pell, trail))
	ScriptedScenario.release(scene)
	return {"scene": scene, "trail": trail, "upkeep": loop.upkeep}


# --- What the run prints ---------------------------------------------------


static func _same_moment_lines(
	arms: Array[Dictionary], played: Dictionary
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the same moment, four times")
	written.append("  observation fingerprint    %s in all four arms: %s" % [
		"" if arms.is_empty() else String(arms[0]["observed"]),
		"yes" if bool(played["same_situation"]) else "NO",
	])
	written.append("  what it remembers          identical in all four arms: %s" % (
		"yes" if bool(played["same_memory"]) else "NO"))
	written.append("  prompt outside its goals   identical in all four arms: %s" % (
		"yes" if bool(played["same_outside_goals"]) else "NO"))
	written.append("  so the only thing that differs between the arms is what the"
		+ " character is after")
	return written


static func _arm_lines(arm: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("arm: %s -- prompt %s" % [arm["name"], arm["digest"]])
	written.append("  what it is after, as the prompt carried it:")
	for line in arm["block"]:
		written.append("    " + line)
	written.append("  what the world answered about each, before the question:")
	for line in arm["answered"]:
		written.append("    " + line)
	written.append("  the model said:     %s" % arm["said"])
	written.append("  which read back as: %s" % arm["line"])
	if String(arm["note"]) != "":
		written.append("  note: %s" % arm["note"])
	return written


static func _difference_lines(arms: Array[Dictionary]) -> PackedStringArray:
	var written := PackedStringArray()
	if arms.is_empty():
		return PackedStringArray(["nothing was asked"])
	var baseline: Dictionary = arms[0]
	written.append("what the goals changed")
	written.append("  two columns, because the two are different claims: a different"
		+ " action, and a different")
	written.append("  choice of any sort including the same action with other words"
		+ " in it")
	written.append("  %-22s %-16s %-42s %-10s %s" % [
		"arm", "which action", "chose", "action", "choice",
	])
	var differed := 0
	var reworded := 0
	for arm in arms:
		var other_sort := String(arm["sort"]) != String(baseline["sort"])
		var other_choice := String(arm["line"]) != String(baseline["line"])
		if arm != baseline:
			differed += 1 if other_sort else 0
			reworded += 1 if other_choice else 0
		written.append("  %-22s %-16s %-42s %-10s %s" % [
			arm["name"], arm["sort"], _clip(String(arm["line"]), 42),
			"--" if arm == baseline else ("differs" if other_sort else "same"),
			"--" if arm == baseline else ("differs" if other_choice else "same"),
		])
	written.append("  %d of %d goals changed which action was chosen; %d changed the"
		% [differed, arms.size() - 1, reworded] + " choice at all")
	for arm in arms:
		if arm == baseline or String(arm["line"]) == String(baseline["line"]):
			continue
		written.append("")
		written.append("  being after \"%s\"" % _wanted(arm))
		written.append("    after nothing it chose  %s" % baseline["line"])
		written.append("    after that one it chose %s" % arm["line"])
		written.append("    which is %s" % (
			"a different action: %s rather than %s" % [arm["sort"], baseline["sort"]]
				if String(arm["sort"]) != String(baseline["sort"])
				else "the same action, %s, said in other words" % arm["sort"]))
	return written


## Which hand can close each of the goals the arms carried, and why -- the
## difference the acceptance asks to be visible rather than asserted.
static func _who_closes_lines(arms: Array[Dictionary]) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("who answers each of these goals")
	written.append("  %-22s %-46s %s" % ["arm", "what it is after", "answered by"])
	for arm in arms:
		var goals: GoalSet = arm["goals"]
		for goal in goals.held:
			written.append("  %-22s %-46s %s" % [
				arm["name"], goal.said(),
				"the world, out of its own state" if GoalCheck.answers(goal)
					else "the character: the world holds no state for it",
			])
	written.append("  a goal the world answers is closed by the world and by nothing"
		+ " else; the section below")
	written.append("  tries the `done` tool on one of each, and the shipped run's own"
		+ " goals table shows")
	written.append("  the world closing one out of its own state -- see reports/goals.md")
	return written


## Both hands, tried: a character closing one of its own goals, and the same
## character refused on one the world answers.
##
## The `done` line here is written down by this run and not said by a model. It
## has to be: the model was offered the tool in all four arms above and did not
## reach for it, and a mechanism nobody ever exercises is a mechanism nobody has
## evidence for. What is being shown is the *rule* -- which hand may close what --
## and the rule is the same whoever asks for the closing, because every driver
## goes through one function: `ModelMind` reads the reply and hands the number to
## `GoalCheck.close_by_hand`, which is where the rule that the world's own goals
## are not the character's to close lives, and which writes both the closing and
## the refusal onto the character's own goal set.
static func _both_hands_lines() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("both hands, tried -- the `done` line below is written down by this"
		+ " run, not said by")
	written.append("  the model, which was offered the tool in all four arms above and"
		+ " did not use it")
	var scene := ScriptedAgent.stage(SEED)
	var actor := _named(scene, PELL)
	var sheet := _sheet(actor)
	sheet.goals.add(Goal.of(Goal.MONEY, {"amount": 900}, "", Goal.LONG))
	sheet.goals.add(Goal.unwritten("be thought well of in this market", Goal.LONG))
	written.append("  %-3s %-46s %-24s %s" % [
		"no", "what it is after", "answered by", "what `done` did",
	])
	for number in [1, 2]:
		var mind := _saying("%s goal=%d" % [ModelPrompt.DONE, number])
		for _at in ModelChannel.THINKS_FOR + 2:
			mind.answer_for(scene, actor)
			scene.advance(1)
		var goal := sheet.goals.goal_of(number)
		written.append("  %-3d %-46s %-24s %s" % [
			number, goal.said(),
			"the world" if GoalCheck.answers(goal) else "the character itself",
			("closed: %s" % goal.closed_by) if goal.closed
				else "refused: %s" % _refusal(sheet.goals),
		])
	ScriptedScenario.release(scene)
	return written


# A mind whose channel answers every question with one line this file wrote down.
# The same `ModelChannel` a shipped run uses, replaying an exchange handed in.
static func _saying(reply: String) -> ModelMind:
	var rows := []
	for _at in 4:
		rows.append({"prompt": "", "reply": reply, "ms": 0})
	return ModelMind.with_channel(ModelChannel.replaying(
		{"rows": rows, "from": "written down by this run", "model": "none"},
		"written down by this run, so that both hands are tried"))


# Why the last closing this character asked for was refused, read off the
# character's own goal set -- where every refusal is written down, whoever asked
# for the closing.
static func _refusal(goals: GoalSet) -> String:
	return "nothing happened" if goals.refusals.is_empty() \
		else String(goals.refusals[goals.refusals.size() - 1]["why"])


# --- The furniture ---------------------------------------------------------


## What the world answered about each of an arm's goals at the moment it was
## asked, in the world's own words.
static func _answered_lines(
	goals: GoalSet, scene: ActionScene, actor: Combatant
) -> PackedStringArray:
	var written := PackedStringArray()
	if goals.size() == 0:
		written.append("(it is after nothing, so there was nothing to answer)")
		return written
	for goal in goals.held:
		var answer := GoalCheck.met(goal, scene, actor)
		written.append("%-46s %s -- %s" % [
			goal.said(), "done" if bool(answer["met"]) else "not yet", answer["how"],
		])
	return written


static func _wanted(arm: Dictionary) -> String:
	var goals: GoalSet = arm["goals"]
	return "nothing" if goals.held.is_empty() else goals.held[0].said()


## The prompt with its "What you are after" block taken out, which is what has to
## be identical between two arms for the comparison to mean anything.
static func _without_goals(prompt: String) -> String:
	return prompt.replace(ModelPrompt.goal_block_of(prompt), "")


static func _all_same(arms: Array[Dictionary], key: String) -> bool:
	for arm in arms:
		if String(arm[key]) != String(arms[0][key]):
			return false
	return true


static func _clip(text: String, width: int) -> String:
	return text if text.length() <= width else text.substr(0, width - 1) + "…"


static func _named(scene: ActionScene, who: String) -> Combatant:
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet != null and sheet.character_name == who:
			return one
	return null


static func _sheet(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
