extends RefCounted
## Does a lesson change what a character chooses? One character, one moment, and
## the same question put four times.
##
##     ./run_lesson.sh                # replays the recorded exchange
##     ./run_lesson.sh --live         # puts the same four questions to a model
##
## A lesson is only worth keeping if it *bends* something. This file is the
## measurement of that, and it is built so that the lesson is the only thing that
## can be doing the bending.
##
## ## How the four arms are made identical
##
## The world is staged from scratch for every arm, from the one seed, and stepped
## the same number of ticks with the same five characters doing the same things.
## The model character stands through all of it -- its decision function is an
## empty plan, so it chooses nothing and the world happens around it -- writing
## down what it can see every `ControlLoop.REVIEW_EVERY` ticks, which is the
## cadence a mind is asked at. Four things follow:
##
##   * every arm's observation has the same fingerprint, printed, so the
##     *situation* is the same situation and not merely a similar one;
##   * every arm's memory holds the same log, written out of that one packet;
##   * arm 0 keeps no lesson; arms 1 to 3 each keep exactly one, through
##     `CharacterMemory.learn()` -- the same door a model's own `learn` goes
##     through, and the only door there is;
##   * every arm's prompt is therefore identical outside its "What you remember"
##     block, which is checked by stripping that block out of all four and
##     comparing what is left.
##
## So a difference in what comes back is a difference the lesson made. The run
## prints all four transcripts, says which choices differ from the one with no
## lesson, and names the difference in words.
##
## ## The lessons are the character's own sentences, not rules
##
## Each is a thing this character could have concluded from something it lived
## through -- what it has found works, what it has found does not. None of them
## says what the world allows, what anything costs or how far anything reaches;
## that is the engine's business and no lesson may borrow it. `run_lesson.sh`'s
## own suite runs the prompt rule-word scan over all four prompts.
##
## The lessons are stated here rather than drawn out of the shipped run because
## this is a controlled comparison: the point is to hold everything else still,
## and the shipped run is where a model writes its own.
class_name ScriptedLesson

## The world the moment is taken from: the shipped run's own, unchanged.
const SEED := ScriptedAgent.SEED
const LOOP_SEED := ScriptedAgent.LOOP_SEED
const PELL := ScriptedAgent.PELL

## How many ticks the world runs before the question is put. Long enough that the
## market has done its talking and the character has a log of its own rather than
## a single glance, short enough that it is still standing where it started.
const WATCHED := 100

## The four arms. The first keeps nothing; the other three keep one lesson each,
## aimed at three different things the character might otherwise do.
const ARMS := [
	{
		"name": "no lesson",
		"lesson": "",
	},
	{
		"name": "the ground first",
		"lesson": "Whenever I have been slow to go and look at what is lying on"
			+ " the ground here, it has been gone by the time I turned round."
			+ " Wren's bargains keep; the ground does not.",
	},
	{
		"name": "Rook, not Wren",
		"lesson": "Wren calls the whole market to every bargain and has never yet"
			+ " meant me. Rook is the only one here who has ever actually traded"
			+ " with me.",
	},
	{
		"name": "let them come",
		"lesson": "The three times I have answered a shout in this market, the"
			+ " one who shouted had already turned away and I was left talking to"
			+ " nobody. I do better letting them come to me.",
	},
]


# --- The one moment, staged for each arm ----------------------------------


## Play every arm and hand back the transcript.
static func play(channel: ModelChannel) -> PackedStringArray:
	var played := played_with(channel)
	var arms: Array[Dictionary] = played["arms"]

	var written := PackedStringArray()
	written.append("does a lesson change what is chosen? seed=%d, %d ticks watched"
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
	return written


## Play every arm out of a channel handed in.
static func played_with(channel: ModelChannel) -> Dictionary:
	var arms: Array[Dictionary] = []
	for at in ARMS.size():
		arms.append(_arm(channel, at))
	return {
		"arms": arms,
		"same_situation": _all_same(arms, "observed"),
		"same_outside_memory": _all_same(arms, "bare"),
	}


# One arm: the world staged and stepped, one observation taken and witnessed,
# this arm's lesson kept if it has one, and the one question put.
static func _arm(channel: ModelChannel, at: int) -> Dictionary:
	var row: Dictionary = ARMS[at]
	var watched := _watched()
	var scene: ActionScene = watched["scene"]
	var actor := _named(scene, PELL)
	var seen := Observation.of(scene, actor, watched["trail"])
	var remembered: CharacterMemory = _sheet(actor).memory
	remembered.witness(seen)
	var kept := String(row["lesson"]) != ""
	if kept:
		remembered.learn(String(row["lesson"]), seen)

	var prompt := ModelPrompt.written_for(seen, remembered)
	var ticket := channel.ask(prompt, 0)
	var reply := channel.reply_to(ticket, ModelChannel.THINKS_FOR)
	var chosen := ModelPrompt.action_of(reply)
	return {
		"name": String(row["name"]),
		"lesson": String(row["lesson"]),
		"observed": seen.digest(),
		"prompt": prompt,
		"digest": ModelPrompt.digest_of(prompt),
		"bare": _without_memory(prompt),
		"memory": ModelPrompt.memory_lines(remembered),
		"remembered": remembered.entry_count(),
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


# The world, staged and stepped, with the model character standing through it.
#
# Its decision function is an empty plan: it chooses nothing, which every driver
# reads as "the character waits", so nothing about what a model would have done
# in these thirty ticks can differ between arms -- there is nothing to differ.
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
		# Written down at the cadence a mind would be asked at, so that the log is
		# the log a character living those ticks would have and not one glance.
		if (step + 1) % ControlLoop.REVIEW_EVERY == 0:
			remembered.witness(Observation.of(scene, pell, trail))
	ScriptedScenario.release(scene)
	return {"scene": scene, "trail": trail}


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
	written.append("  prompt outside its memory  identical in all four arms: %s" % (
		"yes" if bool(played["same_outside_memory"]) else "NO"))
	written.append("  so the only thing that differs between the arms is what the"
		+ " character remembers")
	written.append("  what it lived through   %d things in its log before any lesson"
		% (0 if arms.is_empty() else int(arms[0]["remembered"])))
	return written


static func _arm_lines(arm: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("arm: %s -- prompt %s, %d things remembered" % [
		arm["name"], arm["digest"], arm["remembered"],
	])
	if String(arm["lesson"]) == "":
		written.append("  lesson kept: none")
	else:
		written.append("  lesson kept: %s" % arm["lesson"])
	written.append("  what it remembers, as the prompt carried it:")
	for line in arm["memory"]:
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
	written.append("what the lessons changed")
	written.append("  two columns, because the two are different claims: a different"
		+ " action, and a different")
	written.append("  choice of any sort including the same action with other words"
		+ " in it")
	written.append("  %-18s %-16s %-46s %-10s %s" % [
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
		written.append("  %-18s %-16s %-46s %-10s %s" % [
			arm["name"], arm["sort"], _clip(String(arm["line"]), 46),
			"--" if arm == baseline else ("differs" if other_sort else "same"),
			"--" if arm == baseline else ("differs" if other_choice else "same"),
		])
	written.append("  %d of %d lessons changed which action was chosen; %d changed the"
		% [differed, arms.size() - 1, reworded] + " choice at all")
	for arm in arms:
		if arm == baseline or String(arm["line"]) == String(baseline["line"]):
			continue
		written.append("")
		written.append("  keeping \"%s\"" % arm["lesson"])
		written.append("    with no lesson it chose  %s" % baseline["line"])
		written.append("    with that one it chose   %s" % arm["line"])
		written.append("    which is %s" % (
			"a different action: %s rather than %s" % [arm["sort"], baseline["sort"]]
				if String(arm["sort"]) != String(baseline["sort"])
				else "the same action, %s, said in other words" % arm["sort"]))
	return written


static func _clip(text: String, width: int) -> String:
	return text if text.length() <= width else text.substr(0, width - 1) + "\u2026"


# --- The furniture ---------------------------------------------------------


## The prompt with its "What you remember" block taken out, which is what has to
## be identical between two arms for the comparison to mean anything.
static func _without_memory(prompt: String) -> String:
	return prompt.replace(ModelPrompt.memory_block_of(prompt), "")


static func _all_same(arms: Array[Dictionary], key: String) -> bool:
	for arm in arms:
		if String(arm[key]) != String(arms[0][key]):
			return false
	return true


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
