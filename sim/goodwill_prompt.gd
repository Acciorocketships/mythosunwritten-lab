extends RefCounted
## The question that asks how much goodwill something earned, in its two
## situations.
##
## Section 6 has a model judge an amount "from the quest's nature", and this is
## that question. It is put twice in this project, about two different things,
## and both of them end in the same one-line answer -- a share -- which
## `Goodwill` reads and the engine bounds and applies.
##
##   * **a deed** -- somebody wanted something, and somebody else brought it
##     about. `for_a_deed()`. There is no quest here and none is described: what
##     is put to the model is the wanted state in the wanting character's own
##     words and the world's own record of what happened, and it is asked what
##     that is worth to the one who wanted it.
##   * **a persuasion** -- somebody talked somebody round, and the engine has
##     already rolled that it worked. `for_a_persuasion()`. The model is told the
##     attempt succeeded, exactly as `CheckPrompt.resolving_for` is, and asked
##     the same one question: how much.
##
## ## What is deliberately not in either
##
##   * **No rule about which is worth more.** Neither prompt says that words are
##     worth less than deeds, that goodwill should be rare, that most attempts
##     earn little, or anything else about how the answer should come out. That
##     is the whole reason the rarity of persuasion lives in the engine -- one
##     attempt per person, against a class the engine computes -- rather than in
##     a sentence asking a model to be stingy. A prompt that carried the rule
##     would make the measurement a measurement of the prompt.
##   * **No die, no class, no total.** As with the two check prompts, the
##     arithmetic is nowhere near either call. A persuasion is described as
##     having worked, with no mention of what it beat.
##   * **No sentiment numbers.** Neither call is shown what the two already think
##     of each other. It is asked what one thing was worth, and the engine adds
##     that to what is already there -- as a share of what is left, so that the
##     tenth good turn is worth less than the first without anybody having to say
##     so.
class_name GoodwillPrompt

## The first line of the question, which is the same line in both situations
## because it is the same judgement.
const WEIGHS := "You weigh what one thing somebody did is worth to somebody else."


## The question about a deed.
##
## `wanted` is the goal in the wanting character's own words, `what` is the
## world's own line for what happened, and the two names are what the two
## characters are called.
static func for_a_deed(
	wanted: String, what: String, wanted_by: String, done_by: String,
	sheet: Character
) -> String:
	var written := PackedStringArray()
	written.append(WEIGHS)
	written.append("")
	written.append("Someone in a world wanted this:")
	written.append("")
	written.append("  %s: %s." % [wanted_by, wanted])
	written.append("")
	written.append("It is now so, and this is what the world recorded happening:")
	written.append("")
	written.append("  %s." % what)
	written.append("")
	written.append("So %s is why %s has what it wanted." % [done_by, wanted_by])
	written.append("")
	written.append("Who wanted it:")
	written.append_array(_who_lines(wanted_by, sheet))
	written.append("")
	written.append_array(_asking_lines(wanted_by, done_by))
	return "\n".join(written)


## The question about a persuasion the engine has already rolled a success for.
##
## It is only ever written on that branch, so a failed attempt costs no call at
## all -- the same shape `CheckPrompt.resolving_for` has, and for the same
## reason.
static func for_a_persuasion(
	attempt: String, spoken_to: String, spoke: String, sheet: Character
) -> String:
	var written := PackedStringArray()
	written.append(WEIGHS)
	written.append("")
	written.append("This happened, and it worked:")
	written.append("")
	written.append("  %s, and %s was won round by it." % [attempt, spoken_to])
	written.append("")
	written.append("Who was won round:")
	written.append_array(_who_lines(spoken_to, sheet))
	written.append("")
	written.append_array(_asking_lines(spoken_to, spoke))
	return "\n".join(written)


## The prompt's fingerprint, the same one the recording is keyed by.
static func digest_of(prompt: String) -> String:
	return prompt.sha256_text().substr(0, 16)


# --- The two halves both questions share ----------------------------------


static func _who_lines(called: String, sheet: Character) -> PackedStringArray:
	var written := PackedStringArray()
	if sheet == null:
		written.append("  %s, of whom nothing else is known." % called)
		return written
	written.append("  %s, level %d." % [called, sheet.level])
	var scores := PackedStringArray()
	for ability in Ability.ALL:
		scores.append("%s %d" % [ability, sheet.score(ability, 0)])
	written.append("  ability scores: %s." % ", ".join(scores))
	return written


static func _asking_lines(who: String, toward: String) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("Judge how much better %s should think of %s for it." % [who, toward])
	written.append("  Answer with a number from %.0f, which is nothing at all, to"
		% Goodwill.SAID_LEAST
		+ " %.0f, which is the most one thing could ever be worth."
		% Goodwill.SAID_MOST)
	written.append("")
	written.append("Answer with one line and nothing else:")
	written.append("  %s=<the number>" % Goodwill.KEY)
	return written
