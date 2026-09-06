extends RefCounted
## What a language model is asked, and how its answer is read back as one atomic
## action.
##
## Two functions and nothing else: `written_for()` turns an `Observation` into
## the text a model is handed, and `action_of()` turns a model's line back into
## an `Action`. Both are pure -- no world, no network, no state -- so the same
## observation writes the same prompt in every process, and the same reply reads
## back as the same choice.
##
## ## The prompt is a menu and a view, and nothing else
##
## It carries two things: every action with the shape of its arguments, read
## straight out of `ActionCatalog.ROWS` so a second list cannot appear here, and the observation packet `sim/observation.gd` assembled. It carries no
## rule. There is no sentence in it about how far a character can walk, what a
## jump costs in dexterity, what an attack does, whether a target is in reach,
## whether an item can be picked up from where the character is standing, or
## whether any particular choice would work at all. `RULE_WORDS` is that claim
## written as a check: `tests/test_agent.gd` runs it over a real prompt and
## requires no hit.
##
## The reason is the same one that keeps `sim/action.gd` free of positions: a
## chosen action is a *choice*, and what is possible is `ActionEngine`'s answer.
## A model told the rules would be resolving as well as choosing, and would then
## be a second, worse copy of the engine. A model told nothing chooses, is
## refused with a sentence when it chooses something the world will not allow,
## and the refusal is the same sentence any other caller gets.
##
## ## What it remembers, and the three things it may answer with instead
##
## Beside the packet the prompt carries what the character remembers: every
## lesson it has kept, and the most recent few lines of its own log. Older lines
## are not in it, and the way to reach them is the first of three *tools* the
## prompt offers -- `recall`, which looks back through the same store, `learn`,
## which keeps a sentence for good, and `done`, which says one of the things the
## character is after is finished. None is an atomic action: they change nothing
## in the world, they take no time in it, and they are deliberately not rows of
## `ActionCatalog`, which is the one list of what changes the world. A reply
## naming one is read by `tool_of()` rather than by `action_of()`, and what is
## done about it is `ModelMind`'s business.
##
## What is remembered is the character's own log, so it carries no rule for the
## same reason the packet does not: every line of it was written out of an
## observation, and an observation holds no rule either.
##
## Two things the packet carries are worth naming here, because both look at
## first glance like rules and neither is one. The window of ground arrives with
## a legend saying what each of its marks means -- `@` where you stand, `~` a
## hole, `#` a face too tall to climb -- which is a key to a picture and says
## nothing about what may be done on any of them. And the packet carries the
## lines of speech the character heard, which is `ActionEngine`'s own account of
## who heard what: the observation filters by the `heard_by` the engine wrote
## down and there is no earshot anywhere in the prompt.
##
## ## It names outcomes now, and still no route to one
##
## Until this step the prompt named no outcome at all: no goal, no quest, no
## story. It now carries what the character is after -- section 10's structured
## goals, off that character's own sheet, written as wanted states of the world
## and printed in the order they press. Three things about that block are worth
## stating, because the difference between an outcome and a story is the whole
## of this file's job:
##
##   * it is *this character's* goals and not the run's. Nothing here declares a
##     goal, `GoalSet` declares none either, and a character nobody has set
##     anything for is shown that it is after nothing in particular;
##   * every line is a state and never a route. "Be beside #6" says what would be
##     true if it were done and nothing about walking, and no line of the block
##     names an action out of the menu above it;
##   * no line says a goal is a good idea, worth points, or the reason the
##     character exists. There is no reward anywhere in the prompt, because a
##     reward is what turns a goal into a quest.
##
## What is still not in it: a quest, a giver, a chain, a step, a hint, or any
## suggestion of what a good answer would be. It says who you are, what you can
## see, what you are after, what you remember, and what the verbs are.
##
## ## Reading the answer
##
## The reply is expected to be one line of the form
##
##     go_to target=#6
##     go_to offset=(+2.0, -6.0)
##     say text=good morning target=#2
##     trade_propose target=#2 give_money=12 want=[silk cloak]
##
## and it is read by the catalogue: which keys an action takes and what sort of
## value each key holds are `ActionCatalog.ROWS`'s to say, so the parser asks the
## row rather than guessing from the text. A value that will not read as the sort
## its key declares is left as it came, and `ActionCatalog.fault()` refuses the
## choice with the same sentence it gives any other caller who gets a parameter
## wrong. A reply naming nothing in the catalogue reads as no choice at all, and
## a decision function with no choice is a character that waits -- which every
## driver in this project already knows how to do.
class_name ModelPrompt

## The words that would mean a rule had got into the prompt. Whole words, tested
## with comments and quoting left alone because a prompt is all text: there is no
## code in it and nothing to strip.
##
## The five the acceptance names -- distance, reach, cost, damage, possibility --
## and the words that are the same claim in other clothes.
const RULE_WORDS := (
	"distance|distances|reach|reaches|cost|costs|damage|damages"
	+ "|possible|impossible|legal|illegal|allowed|forbidden|cannot"
	+ "|succeed|succeeds|success|fail|fails|failed|failure"
	+ "|cooldown|radius|range"
)

## How a value of each sort is written in a reply, said once here and printed
## into the prompt so the model and the parser are reading one description.
##
## Every one of them names what goes there, in angle brackets, and never shows a
## specimen of it. That is not a style: a placeholder that is itself a legal
## value is a value a model can hand back, and measured over a full recording
## pass every mind asked did. The forms used to be specimens -- `#7`,
## `(12.5, -4.0)`, `(+2.0, -6.0)`, `words` -- and put every question of all five
## runs, four small minds answered `recall about=words` 50 times in 97,
## `examine #7` 57 in 98, `say text=words target=#7` 39 in 140, and three of the
## four answered every one of the world run's five looks with a spawn at
## `(12.5, -4.0)`, ground the engine refused all fifteen times because it is 650
## units from anybody. Nor is this a small mind's failing: the checked-in
## recording in `net/model_recording.gd` answers `go_to offset=(+2.0, -6.0)` --
## this table's own offset, digit for digit -- 8 times in 77, more often than
## any other line it chose. Put the same questions again with the specimens in
## brackets and the copying falls from 108 answers in 113 to 1 in 84 on the
## worst of the four, and no spawn lands on that coordinate again.
##
## In brackets a copy is not a value. `#<id>` has no whole number after the `#`,
## `(<x>, <z>)` has no number either side of the comma, so `_value_of` leaves
## both as the text they came as and `ActionCatalog.fault()` refuses the choice
## with its own sentence, the way it refuses any other parameter that is the
## wrong sort. Two sorts cannot be made unreadable, because any string is a legal
## `text` and any list of words a legal `names`; for those the brackets do the
## other half of the job, which is that a copy is unmistakable in a transcript
## rather than passing for something a character meant to say.
##
## The shape is unchanged: the punctuation around each bracket is still the
## syntax, so the line that says how a position is written still says it with
## parentheses and a comma in it, and the parser is untouched.
const SORT_FORMS := {
	ActionCatalog.ID: "#<id>",
	ActionCatalog.POSITION: "(<x>, <z>)",
	ActionCatalog.OFFSET: "(<x from here>, <z from here>)",
	ActionCatalog.ID_OR_POSITION: "#<id> or (<x>, <z>)",
	ActionCatalog.ID_OR_NAME: "#<id> or <a name>",
	ActionCatalog.TEXT: "<what you mean>",
	ActionCatalog.COUNT: "<a whole number>",
	ActionCatalog.NAMES: "[<a name>, <another name>]",
}


## The line under the menu that says what a verb printed more than once is. An
## action with more than one shape gets a line per shape rather than one line
## carrying both, because a line carrying both is a line that gets copied whole:
## the first recording made against a menu that joined the two with a bar drew
## `go_to target=#2 offset=(-2.0, -6.0)` -- both keys at once -- on 5 of its 15
## walks, and the catalogue refused every one of them.
const SHAPES_LINE := ("An action printed on more than one line has that many"
	+ " shapes: write one of the lines, not two.")


## The three things a reply may name that are not actions. See the note above: a
## tool touches the character's own memory or its own goals and nothing in the
## world, so they are here and not in `ActionCatalog`.
##
## `says` is what the prompt prints beside each. It says what the tool does to
## what the character holds and nothing about the world, so the rule scan over
## the whole prompt covers these lines too.
## The line the memory block opens with and the line that closes the prompt after
## it. Named because three things read them: the prompt writes them, the run
## measures how many characters lie between them, and the lesson comparison takes
## the block out to check that two prompts differ nowhere else.
const REMEMBERS := "What you remember"
const CLOSES := "Answer with one line"

const RECALL := "recall"
const LEARN := "learn"
const DONE := "done"
const TOOLS := [
	{
		"name": RECALL,
		"key": "about",
		"sort": ActionCatalog.TEXT,
		"says": "look back through everything you remember for anything about it",
	},
	{
		"name": LEARN,
		"key": "text",
		"sort": ActionCatalog.TEXT,
		"says": "keep one sentence in mind from now on, in every later moment",
	},
	{
		"name": DONE,
		"key": "goal",
		"sort": ActionCatalog.COUNT,
		"says": "say that one of the things you are after, by its number, is done",
	},
]

## The line the goals block opens with. Read the same way `REMEMBERS` is: the
## block written into the prompt runs from here to `REMEMBERS`, so what is
## measured and what is compared between two prompts is the text that was
## actually sent.
const WANTS := "What you are after"

## What is printed beside a goal, saying whose answer closes it. Neither line
## says anything about the world -- only about which hand writes the goal off.
const WORLD_ANSWERS := "the world says when this one is done"
const YOU_ANSWER := "answer `%s %s=%d` when you judge it done"

## What is printed when a character is after nothing at all, which is what a
## character nobody has set anything for is after.
const WANTS_NOTHING := "%s: nothing in particular." % WANTS


# --- Writing the prompt ---------------------------------------------------


## The whole prompt for one character standing where it is standing.
##
## `seen` is what `Observation.of()` assembled for it; nothing else about the
## world is read here, and nothing about the character that is not in the packet.
static func written_for(
	seen: Observation, remembered: CharacterMemory = null,
	looked_back: Dictionary = {}, wanted: GoalSet = null
) -> String:
	var written := PackedStringArray()
	written.append("You are %s, one character in a world of many." % _who(seen))
	written.append("")
	written.append("Choose the one thing your character does next.")
	written.append("")
	written.append("The actions, and the keys each one takes:")
	written.append_array(menu_lines())
	written.append("")
	written.append("Or answer with one of these three instead, which are not"
		+ " actions and touch only what you remember and what you are after:")
	written.append_array(tool_lines())
	written.append("")
	written.append("A key marked (may be left out) can be left out.")
	written.append(SHAPES_LINE)
	written.append("Values are written like this: %s." % _sort_forms_line())
	written.append("")
	written.append("What you can see from where you are standing:")
	written.append("")
	written.append(seen.text())
	written.append("")
	written.append_array(goal_lines(wanted))
	written.append("")
	written.append_array(memory_lines(remembered, looked_back))
	written.append("")
	written.append("%s: the action or the tool, then its keys. Nothing else."
		% CLOSES)
	return "\n".join(written)


## What the character is after, as the prompt prints it: every open goal in the
## order it is pressing, then the ones already finished.
##
## Each line is a *wanted state* and never a way of getting to one: "be beside
## #6", "be carrying 20 money or more", "have traded with #2". There is no step
## in any of them, no order of steps, and no verb out of the action menu above --
## a goal that named an action would be an instruction, and the whole point of
## the layer is that what to do about a goal is the character's own answer.
##
## Beside each open goal is the one thing that is not about the world: which hand
## closes it. A goal naming something the world holds is closed by the world, and
## a goal in the character's own words that names nothing the world holds is
## closed by the character with the `done` tool. That is bookkeeping about the
## goal, not a rule about what may be done, which is why the rule-word scan runs
## over these lines like every other.
static func goal_lines(wanted: GoalSet) -> PackedStringArray:
	var written := PackedStringArray()
	if wanted == null or wanted.size() == 0:
		written.append(WANTS_NOTHING)
		return written
	var open := wanted.open()
	if open.is_empty():
		written.append("%s: nothing more -- everything is done." % WANTS)
	else:
		written.append("%s, the most pressing first:" % WANTS)
	for goal in open:
		written.append("  %-2d %-5s %-46s %s" % [
			goal.id, goal.horizon, goal.said(), _closed_by_line(goal),
		])
	var finished := wanted.done()
	if finished.is_empty():
		return written
	written.append("  and these you have already done:")
	for goal in finished:
		written.append("  %-2d %-5s %-46s %s" % [
			goal.id, goal.horizon, goal.said(), goal.closed_by,
		])
	return written


## The part of a written prompt that is what the character is after: everything
## from the block's own first line to the line the memory block opens with.
static func goal_block_of(prompt: String) -> String:
	var opens := prompt.find(WANTS)
	if opens < 0:
		return ""
	var closes := prompt.find(REMEMBERS, opens)
	return prompt.substr(opens).strip_edges() if closes < 0 \
		else prompt.substr(opens, closes - opens).strip_edges()


# Which hand closes one goal, said in the prompt beside it.
static func _closed_by_line(goal: Goal) -> String:
	return WORLD_ANSWERS if GoalCheck.answers(goal) \
		else YOU_ANSWER % [DONE, "goal", goal.id]


## What the character remembers, as the prompt prints it: every lesson it keeps,
## the most recent few lines of its log, and -- when the last thing it did was
## look back -- what looking back turned up, or the world's sentence when it
## would not allow the look at all.
##
## Neither of those last two is a line of the prompt's own: they appear only when
## the character did that thing on the question before, exactly as a refused
## action's sentence reaches whoever chose it. A run in which no tool was used
## and none refused writes the same prompt it always wrote.
##
## The older lines of the log are deliberately not here. They are what `recall`
## is for, and a prompt that carried them all would make the tool pointless and
## the packet unbounded.
static func memory_lines(
	remembered: CharacterMemory, looked_back: Dictionary = {}
) -> PackedStringArray:
	var written := PackedStringArray()
	if remembered == null:
		written.append("%s: nothing is keeping a memory for you." % REMEMBERS)
		return written
	written.append("%s:" % REMEMBERS)
	var kept := remembered.lesson_lines()
	written.append("  lessons    %d you have kept" % kept.size())
	for line in kept:
		written.append("    - %s" % line)
	var lately := remembered.recent()
	written.append("  lately     the last %d of %d things you remember" % [
		lately.size(), remembered.events.size(),
	])
	for line in lately:
		written.append("    - %s" % line)
	if looked_back.is_empty():
		return written
	if looked_back.has("refused"):
		written.append("  the world refused your %s: %s" % [
			looked_back.get("tool", ""), looked_back["refused"],
		])
		return written
	var found := PackedStringArray(looked_back.get("lines", PackedStringArray()))
	written.append("  looked back for \"%s\": %d thing%s" % [
		looked_back.get("about", ""), found.size(), "" if found.size() == 1 else "s",
	])
	for line in found:
		written.append("    - %s" % line)
	return written


## The part of a written prompt that is what the character remembers: everything
## from the block's own first line to the line that closes the prompt.
##
## Read back out of the text rather than kept beside it, so that what is measured
## is what was actually sent.
static func memory_block_of(prompt: String) -> String:
	var opens := prompt.find(REMEMBERS)
	if opens < 0:
		return ""
	var closes := prompt.find(CLOSES, opens)
	return prompt.substr(opens).strip_edges() if closes < 0 \
		else prompt.substr(opens, closes - opens).strip_edges()


## The two tools, one line each, read out of the one table.
static func tool_lines() -> PackedStringArray:
	var written := PackedStringArray()
	for tool in TOOLS:
		written.append("  %-14s %s=%s   -- %s" % [
			tool["name"], tool["key"],
			SORT_FORMS.get(tool["sort"], "?"), tool["says"],
		])
	return written


## Every action and its keys, one line each, read out of the one list.
##
## The catalogue's `listed` column -- section 2.1's own wording of a row -- is
## deliberately not printed. It is prose about what an action does, and one row
## of it says who hears a shout, which is close enough to a rule that leaving it
## out is cheaper than arguing about it. What is printed is the verb and the
## shape of its arguments.
static func menu_lines() -> PackedStringArray:
	var written := PackedStringArray()
	for row in ActionCatalog.ROWS:
		var keys := PackedStringArray()
		for key in row["params"]:
			keys.append("%s=%s" % [key, SORT_FORMS.get(row["params"][key], "?")])
		for key in row["optional"]:
			keys.append("%s=%s (may be left out)" % [
				key, SORT_FORMS.get(row["optional"][key], "?"),
			])
		var one_of := ActionCatalog.either_of(row)
		if one_of.is_empty():
			written.append("  %-14s %s" % [row["name"], " ".join(keys)])
			continue
		for key in one_of:
			var shape := PackedStringArray(["%s=%s" % [
				key, SORT_FORMS.get(one_of[key], "?"),
			]])
			shape.append_array(keys)
			written.append("  %-14s %s" % [row["name"], " ".join(shape)])
	return written


## A short fingerprint of a prompt, which is what a recorded exchange is keyed
## against and what a transcript prints instead of two thousand characters.
static func digest_of(prompt: String) -> String:
	return prompt.sha256_text().substr(0, 16)


# --- Reading the answer ---------------------------------------------------


## The action a reply names, or null when it names none.
##
## The first line of the reply that begins with one of the catalogue's action
## names is the choice; anything a model wrote around it is ignored rather than
## refused, because a model that answers "go_to target=#6" after a sentence of
## its own has still chosen. A reply naming no action at all is null: nothing
## chosen, which every driver already reads as "the character waits".
static func action_of(reply: String) -> Action:
	for line in reply.split("\n"):
		var chosen := _action_of_line(line)
		if chosen != null:
			return chosen
	return null


## The reply as the transcript prints it: one line, with whatever the model wrote
## around its choice collapsed away.
static func said_line(reply: String) -> String:
	var flattened := reply.strip_edges().replace("\n", " / ")
	while flattened.contains("  "):
		flattened = flattened.replace("  ", " ")
	return flattened


## The tool a reply names, or an empty dictionary when it names none.
##
## Read the same way an action is: the first line beginning with a tool's name is
## the answer, and whatever a model wrote around it is ignored. What comes back is
## `{"tool": String, "text": String}` -- the whole of a tool call, because both
## tools take one piece of text and nothing else.
##
## A reply that names an action is not looked at here at all: `ModelMind` asks for
## an action first and only asks this when there was none, so a line naming both
## is a choice and not a query.
static func tool_of(reply: String) -> Dictionary:
	for line in reply.split("\n"):
		var found := _tool_of_line(line)
		if not found.is_empty():
			return found
	return {}


static func _tool_of_line(line: String) -> Dictionary:
	var text := _bared(line)
	for tool in TOOLS:
		var named: String = tool["name"]
		if not text.begins_with(named + " "):
			continue
		var rest := text.substr(named.length()).strip_edges()
		var key: String = tool["key"]
		var at := _key_at(rest, key)
		if at < 0:
			continue
		var said := rest.substr(at + key.length() + 1).strip_edges()
		if said == "":
			continue
		return {"tool": named, "text": said}
	return {}


static func _action_of_line(line: String) -> Action:
	var text := _bared(line)
	for row in ActionCatalog.ROWS:
		var name_of_row: String = row["name"]
		if text != name_of_row and not text.begins_with(name_of_row + " "):
			continue
		return Action.of(
			name_of_row,
			_params_of(text.substr(name_of_row.length()).strip_edges(), row))
	return null


# The `key=value` pairs of one line, read against the row that says which keys
# there are and what sort of thing each holds.
#
# Keys are found by where they appear rather than by splitting on spaces, so a
# value with spaces in it -- a line of speech, a position, a list of names --
# survives being read.
static func _params_of(rest: String, row: Dictionary) -> Dictionary:
	var sorts := ActionCatalog.keys_of(row)

	var marks := []
	for key in sorts:
		var at := _key_at(rest, key)
		if at >= 0:
			marks.append({"key": key, "at": at, "from": at + key.length() + 1})
	marks.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["at"]) < int(right["at"]))

	var found := {}
	for index in marks.size():
		var mark: Dictionary = marks[index]
		var ends := rest.length() if index + 1 >= marks.size() else int(marks[index + 1]["at"])
		var raw := rest.substr(int(mark["from"]), ends - int(mark["from"])).strip_edges()
		found[mark["key"]] = _value_of(raw, String(sorts[mark["key"]]))
	return found


# Where `key=` starts in a line, or -1. It has to be a whole word: `money=3`
# must not be found inside `give_money=3`.
static func _key_at(rest: String, key: String) -> int:
	var at := rest.find(key + "=")
	while at != -1:
		if at == 0 or rest[at - 1] == " ":
			return at
		at = rest.find(key + "=", at + 1)
	return -1


# One written value read as the sort its key declares. A value that will not
# read as that sort comes back as the text it was, so that the catalogue refuses
# the choice with its own sentence rather than this file inventing one.
static func _value_of(raw: String, sort: String) -> Variant:
	match sort:
		ActionCatalog.ID:
			return _id_of(raw)
		ActionCatalog.POSITION, ActionCatalog.OFFSET:
			return _position_of(raw)
		ActionCatalog.ID_OR_POSITION:
			return _position_of(raw) if raw.begins_with("(") else _id_of(raw)
		ActionCatalog.ID_OR_NAME:
			return _id_of(raw) if raw.begins_with("#") else raw
		ActionCatalog.COUNT:
			return _id_of(raw)
		ActionCatalog.NAMES:
			return _names_of(raw)
	return raw


static func _id_of(raw: String) -> Variant:
	var digits := raw.lstrip("#").strip_edges()
	return digits.to_int() if digits.is_valid_int() else raw


static func _position_of(raw: String) -> Variant:
	var inside := raw.strip_edges().lstrip("(").rstrip(")")
	var halves := inside.split(",")
	if halves.size() != 2:
		return raw
	var x := String(halves[0]).strip_edges()
	var z := String(halves[1]).strip_edges()
	if not x.is_valid_float() or not z.is_valid_float():
		return raw
	return Vector2(x.to_float(), z.to_float())


static func _names_of(raw: String) -> Variant:
	var inside := raw.strip_edges().lstrip("[").rstrip("]").strip_edges()
	if inside == "":
		return PackedStringArray()
	var found := PackedStringArray()
	for part in inside.split(","):
		var one := String(part).strip_edges()
		if one != "":
			found.append(one)
	return found


# One line of a reply with a list marker taken off the front, so that a model
# that answers with a bullet has still answered.
static func _bared(line: String) -> String:
	var text := line.strip_edges()
	if text.begins_with("-") or text.begins_with("*"):
		return text.substr(1).strip_edges()
	return text


static func _who(seen: Observation) -> String:
	return "#%d" % seen.self_id if seen.self_name == "" else seen.self_name


static func _sort_forms_line() -> String:
	var written := PackedStringArray()
	for sort in SORT_FORMS:
		written.append("%s is %s" % [sort, SORT_FORMS[sort]])
	return "; ".join(written)
