extends RefCounted
## The two questions a difficulty-class check puts, and how the answers are read.
##
## Section 7 wants two calls with *different system prompts*, and this file is
## where the difference is: `judging_for` asks how hard something is and forbids
## saying whether it works; `resolving_for` is only ever written after the engine
## has already decided that it worked, and asks what changes, from a fixed list of
## operations the engine exposes. Neither prompt carries a die, a total or a
## threshold, because neither call is allowed anywhere near the arithmetic --
## that is `AbilityCheck`'s three functions and nothing else.
##
## Both prompts open with a line naming what the call is for, and those two lines
## are constants below so a test can assert they are not the same prompt with the
## question swapped.
##
## ## What is deliberately not in either
##
##   * No roll and no total. The judging call is asked before the die is drawn,
##     and the resolving call is told only that the attempt succeeded.
##   * No suggestion of an answer. The judging prompt does not say what class a
##     thing like this usually gets, and the resolving prompt does not say which
##     operation a thing like this usually takes.
##   * No world beyond the attempt and what is in reach of it. A check is a
##     one-off about one attempt; it is not a character's turn and does not carry
##     a character's observation.
class_name CheckPrompt

## The first line of each of the two prompts. Different questions, different
## calls, and the difference is checkable from outside.
const JUDGES := "You judge how hard something is. You do not decide whether it works."
const RESOLVES := "You say what changes in a world after something has already worked."

## The line the judging call must answer with, and the keys in it.
const CLASS_KEY := "dc"
const ABILITY_KEY := "ability"

## How far around the attempt the resolving call is shown, in world units.
const IN_REACH := 12.0


# --- The first call: how hard is it, and against what ---------------------


## The judging prompt for one raised check.
static func judging_for(check: AbilityCheck, sheet: Character) -> String:
	var written := PackedStringArray()
	written.append(JUDGES)
	written.append("")
	written.append("Someone in a world has attempted this:")
	written.append("")
	written.append("  %s." % check.attempt)
	written.append("")
	written.append("Who is attempting it:")
	written.append_array(_who_lines(check, sheet))
	written.append("")
	written.append("Judge how likely you think that is to succeed, and from your"
		+ " judgement give two things:")
	written.append("  a difficulty class -- a whole number from %d to %d, higher"
		% [AbilityCheck.DC_LOWEST, AbilityCheck.DC_HIGHEST]
		+ " being harder;")
	written.append("  the one ability score it should be tested against, out of:"
		+ " %s." % ", ".join(PackedStringArray(Ability.ALL)))
	written.append("")
	written.append("Answer with one line and nothing else:")
	written.append("  %s=<whole number> %s=<one of the six>" % [CLASS_KEY, ABILITY_KEY])
	return "\n".join(written)


# --- The second call: it worked, so what changed --------------------------


## The resolving prompt for one check the engine has already passed.
##
## It is never written for a check that failed: `CheckDesk` asks this question
## only on the success branch, so a failed attempt costs one call and not two.
static func resolving_for(
	check: AbilityCheck, sheet: Character, scene: ActionScene
) -> String:
	var written := PackedStringArray()
	written.append(RESOLVES)
	written.append("")
	written.append("This happened, and it worked:")
	written.append("")
	written.append("  %s, and succeeded." % check.attempt)
	written.append("")
	written.append("Who did it:")
	written.append_array(_who_lines(check, sheet))
	written.append("")
	written.append("What is within %.0f paces of it:" % IN_REACH)
	written.append_array(_in_reach_lines(check, scene))
	written.append("")
	written.append("Say what that success changes. You may name only these"
		+ " operations; anything else changes nothing:")
	written.append_array(CheckEffects.catalogue_lines())
	written.append("")
	written.append("Answer with at most %d line%s, one operation each, and"
		% [CheckEffects.AT_MOST, "" if CheckEffects.AT_MOST == 1 else "s"]
		+ " nothing else.")
	return "\n".join(written)


# --- What both of them say about the one attempting ------------------------


static func _who_lines(check: AbilityCheck, sheet: Character) -> PackedStringArray:
	var written := PackedStringArray()
	if sheet == null:
		written.append("  %s, of whom nothing else is known." % check.who_named)
		return written
	written.append("  %s, level %d." % [sheet.character_name, sheet.level])
	var scores := PackedStringArray()
	for ability in Ability.ALL:
		scores.append("%s %d" % [ability, sheet.score(ability, 0)])
	written.append("  ability scores: %s." % ", ".join(scores))
	return written


static func _in_reach_lines(check: AbilityCheck, scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	if scene == null:
		written.append("  nothing.")
		return written
	var here := scene.object_of(check.target)
	for thing in scene.objects:
		if here != null and thing.distance_from(here.x, here.z) > IN_REACH:
			continue
		written.append("  #%d %s, %s%s" % [
			thing.id, thing.object_name, "shut" if thing.shut else "open",
			"" if not thing.holds_things() or thing.shut
				else ", holding %d thing%s and %d coins" % [
					thing.contents.size(), "" if thing.contents.size() == 1 else "s",
					thing.contents.money,
				],
		])
	if written.is_empty():
		written.append("  nothing.")
	return written


# --- Reading the judgement -------------------------------------------------


## Read the first call's answer.
##
## Returns `{"read": bool, "dc": int, "ability": String, "why": String}`. A reply
## that names no number, or names something that is not one of the six ability
## scores, is not read -- and a check whose judgement cannot be read lapses,
## because there is nothing to roll against. The number is taken as the model
## said it; bounding it to a class the engine will accept is the engine's, in
## `AbilityCheck.bounded`.
static func judgement_of(reply: String) -> Dictionary:
	var said := -1
	var ability := ""
	for line in reply.split("\n"):
		var text := String(line).strip_edges().to_lower()
		if said < 0:
			var number: Variant = _number_after(text, CLASS_KEY)
			if number != null:
				said = int(number)
		if ability == "":
			ability = _ability_after(text)
		if said >= 0 and ability != "":
			break
	if said < 0:
		return {"read": false, "dc": -1, "ability": "", "why": "no %s= in it" % CLASS_KEY}
	if ability == "":
		return {
			"read": false, "dc": said, "ability": "",
			"why": "no %s= naming one of the six in it" % ABILITY_KEY,
		}
	return {"read": true, "dc": said, "ability": ability, "why": ""}


static func _number_after(text: String, key: String) -> Variant:
	var at := text.find("%s=" % key)
	if at < 0:
		at = text.find("%s =" % key)
		if at < 0:
			return null
	var rest := text.substr(text.find("=", at) + 1).strip_edges()
	var digits := ""
	for index in rest.length():
		if not rest.substr(index, 1).is_valid_int():
			break
		digits += rest.substr(index, 1)
	return null if digits == "" else digits.to_int()


static func _ability_after(text: String) -> String:
	var at := text.find("%s=" % ABILITY_KEY)
	if at < 0:
		return ""
	var rest := text.substr(at + ABILITY_KEY.length() + 1).strip_edges().to_lower()
	for ability in Ability.ALL:
		if rest.begins_with(ability):
			return ability
	return ""


## The prompt's fingerprint, the same one the recording is keyed by.
static func digest_of(prompt: String) -> String:
	return prompt.sha256_text().substr(0, 16)
