extends RefCounted
## What one character remembers: section 10's two segments, both persistent and
## both carried by the character whose memory they are.
##
##   * **events** -- a first-person log of experiences and facts. "I saw Bram
##     (#3), a commander, about 38m away." "Rook (#2) said to me: what will it
##     be?" "I moved 0.9m north-east." It grows for as long as the character
##     lives.
##   * **lessons** -- durable heuristics the character has drawn out of that
##     experience and means to keep. Few, and every one of them goes into every
##     later context, which is what makes them bias what is chosen next.
##
## Recent events go into the context directly and older ones do not; `recall()`
## is how the older ones are reached, and it reads this same store. There is no
## index, no embedding and no consolidation pass here -- section 10 defers all
## three until scale demands them, and `reports/agent-memory.md` carries the
## measurement that says whether it has.
##
## ## Nothing can enter this store that the character did not perceive
##
## That is not a promise in a comment; it is the shape of the file, and
## `tests/test_memory.gd` reads the shape off disk:
##
##   1. **The only way in is an `Observation`.** Every function here that writes
##      into either segment takes one, and an `Observation` is by construction
##      one character's own reading of its own surroundings -- see the note at
##      the head of `sim/observation.gd`. There is no other writer, public or
##      private.
##   2. **There is nothing else here to read the world with.** The only world
##      type this file names is `Observation`. No scene, no character, no
##      combatant, no engine, no board, no terrain, no inventory: a line that
##      reached past the packet for something the character was not shown would
##      have to name one of them, and the test requires that the set of type
##      names in this file is exactly `{Observation}`.
##
## Between them those two say the whole thing. The log is written out of the
## packet; the packet is what the character could see and what the engine says
## it heard; so the log is what the character could see and hear, and there is no
## third door.
##
## A lesson is the character's own sentence rather than a reading of a field, and
## it goes in through the same door for the same reason: `learn()` takes the
## observation the lesson was drawn from and keeps its fingerprint beside the
## words, so a lesson with no moment behind it cannot be written down.
##
## ## It holds no rule
##
## Nothing here knows how far a character can walk, what an item does or whether
## a choice would be allowed. It is a store: things go in, things come out, and
## what to do about any of it is the model's business and then the engine's.
class_name CharacterMemory

## How many of the most recent events go into the context directly. Section 10's
## "always inject recent memories directly"; the rest are reachable by `recall()`
## and by nothing else.
const RECENT := 8

## The most entries one `recall()` hands back, newest last. A query is a window
## onto the log and not a copy of it.
const RECALLED := 12

## The shortest word a query is searched on. A one- or two-letter word matches
## most of the log and tells the asker nothing.
const WORD_AT_LEAST := 3

## How many of the character's own sightings of one thing are written down. One:
## a log that wrote a line every time it looked at the same stall would be a
## clock, not a memory.
const SEEN_ONCE := 1


## The four sorts of entry, named so a report can count them apart.
const SAW := "saw"
const HEARD := "heard"
const CHANGED := "changed"
const LESSON := "lesson"

## The kind of event line a settled ability check writes into the log. The row
## itself goes into its own segment; this is the sentence the character would put
## it in.
const CHECK := "check"


## The first-person log, oldest first. One dictionary per entry:
## `{"text": String, "kind": String, "from": String}`, where `from` is the
## fingerprint of the observation it was written out of.
var events: Array[Dictionary] = []

## The durable lessons, oldest first, in the same shape.
var lessons: Array[Dictionary] = []

## The third segment: ability checks this character has already settled, one row
## per *triggering context* -- the shape of the attempt, as `AbilityCheck.context`
## defines it.
##
## Section 7's reason for it: "store the triggering context in the character's
## memory to avoid repeated rolling". A check of a shape already in here is not
## put to a model and not rolled for again; the answer in here stands. It is a
## segment of its own rather than a lesson because a lesson is a sentence that
## biases a later choice and this is a verdict that replaces a later roll -- two
## different things to read back, and reading a verdict out of prose would be a
## worse way to do it than keeping it as numbers.
var checks: Array[Dictionary] = []

# What has already been written down, so that a packet seen twice is not logged
# twice. Keys only; the entries themselves are above.
var _written: Dictionary = {}

# The last window of speech and the last window of changes this memory was
# shown. Both arrive as rolling windows of a longer stream, so what is new in
# one is its tail past whatever overlaps the one before -- see `_new_tail`.
var _last_heard: PackedStringArray = PackedStringArray()
var _last_recent: PackedStringArray = PackedStringArray()


# --- Writing: the one door, and it takes an observation --------------------


## Write down what this character can see, and hand back how many lines it came
## to.
##
## Everything written is read off the packet and off nothing else. Three kinds of
## line -- the fourth kind of entry, a lesson, is `learn()`'s -- in a fixed order
## so that two processes write the same log:
##
##   * what it is standing among, the first time it sees each thing;
##   * what it has heard since the last look;
##   * what has changed about it since the last look;
##
## and nothing at all when it is shown the same surroundings twice, which is why
## a character standing still for fifty ticks does not fill its own memory with
## fifty copies of the stall.
func witness(seen: Observation) -> int:
	if seen == null:
		return 0
	var before := events.size()
	for row in seen.entities:
		_saw_entity(row, seen)
	for row in seen.objects:
		_saw_object(row, seen)
	for line in _new_tail(_last_heard, _heard_keys(seen)):
		_write(HEARD, line, seen)
	_last_heard = _heard_keys(seen)
	for line in _new_tail(_last_recent, seen.recent):
		_write(CHANGED, "I %s." % line, seen)
	_last_recent = seen.recent.duplicate()
	return events.size() - before


## Keep a lesson: one sentence the character means to be biased by from now on.
##
## The observation it was drawn from is required and its fingerprint is kept, so
## that a lesson always has a moment behind it. A blank lesson, or one already
## kept word for word, is not written again and answers false.
func learn(text: String, seen: Observation) -> bool:
	var said := text.strip_edges()
	if said == "" or seen == null:
		return false
	var key := "%s:%s" % [LESSON, said.to_lower()]
	if _written.has(key):
		return false
	_written[key] = true
	lessons.append({"text": said, "kind": LESSON, "from": seen.digest()})
	return true


## Write down one ability check this character has settled, and the sentence it
## would put that in.
##
## Two segments in one call on purpose: the row goes into `checks`, where a later
## attempt of the same shape reads it back instead of rolling, and a first-person
## line goes into the log through the same `_write` every other event uses, so
## the character's own account of itself says it forced a chest. One context is
## written once -- the first settled check of a shape is the one that stands.
##
## It takes an observation for the reason every writer in this file does: nothing
## enters the store that was not handed a packet the character could perceive.
func settle_check(context: String, row: Dictionary, seen: Observation) -> bool:
	if context.strip_edges() == "" or seen == null:
		return false
	if not check_for(context).is_empty():
		return false
	var kept := row.duplicate(true)
	kept["context"] = context
	kept["from"] = seen.digest()
	checks.append(kept)
	_write(CHECK, String(row.get("text", "")), seen)
	return true


# --- Reading: recent goes in, the rest is asked for ------------------------


## The last few events, oldest last: what goes into every context directly.
func recent(how_many: int = RECENT) -> PackedStringArray:
	var written := PackedStringArray()
	for at in range(maxi(0, events.size() - maxi(0, how_many)), events.size()):
		written.append(String(events[at]["text"]))
	return written


## Every lesson, oldest first. All of them, always: a lesson that was not in the
## context could not bias anything, and there are few enough that keeping them
## all is cheaper than deciding which to leave out.
func lesson_lines() -> PackedStringArray:
	var written := PackedStringArray()
	for one in lessons:
		written.append(String(one["text"]))
	return written


## Look back through the whole store for anything about something.
##
## This is section 10's "optional tool for querying older ones", and it reads the
## same two segments the context is written out of -- there is no second store
## and no index. An entry matches when it holds any of the query's words; the
## newest `RECALLED` matches come back, oldest first, so the answer to "what do I
## remember about Alice" is the last dozen things about Alice.
func recall(about: String) -> PackedStringArray:
	var wanted := _words_of(about)
	if wanted.is_empty():
		return PackedStringArray()
	var found := PackedStringArray()
	for one in lessons:
		if _matches(String(one["text"]), wanted):
			found.append("lesson: %s" % one["text"])
	for one in events:
		if _matches(String(one["text"]), wanted):
			found.append(String(one["text"]))
	if found.size() <= RECALLED:
		return found
	var kept := PackedStringArray()
	for at in range(found.size() - RECALLED, found.size()):
		kept.append(found[at])
	return kept


## The settled check for one triggering context, or an empty dictionary.
##
## The whole of what "similar" means in this project: two attempts are similar
## when `AbilityCheck.context` writes them the same way -- the same action, the
## same kind of thing, the same thing offered. A second oak chest pried at with
## the same bar is the same context; a strongbox is not.
func check_for(context: String) -> Dictionary:
	for one in checks:
		if String(one.get("context", "")) == context:
			return one
	return {}


## Every settled check, one line each.
func check_lines() -> PackedStringArray:
	var written := PackedStringArray()
	for one in checks:
		written.append("%s -- %s %d + roll %d = %d vs dc %d, %s" % [
			one.get("context", ""), one.get("ability", ""), int(one.get("score", 0)),
			int(one.get("roll", 0)), int(one.get("total", 0)),
			int(one.get("difficulty", 0)),
			"passed" if bool(one.get("passed", false)) else "failed",
		])
	return written


# --- How much of it there is ----------------------------------------------


## How many things this character remembers, both segments together.
func entry_count() -> int:
	return events.size() + lessons.size()


## How many characters those entries come to, newlines between them counted, so
## the number is the size of the store as text.
func text_length() -> int:
	var found := 0
	for one in lessons:
		found += String(one["text"]).length() + 1
	for one in events:
		found += String(one["text"]).length() + 1
	return found


## What a context carries: every lesson and the most recent events, in the order
## a packet prints them.
func context_lines(how_many: int = RECENT) -> PackedStringArray:
	var written := PackedStringArray()
	written.append_array(lesson_lines())
	written.append_array(recent(how_many))
	return written


## How many characters of the store a context carries.
func context_length(how_many: int = RECENT) -> int:
	var found := 0
	for line in context_lines(how_many):
		found += line.length() + 1
	return found


## How many entries of each kind there are, for a report that counts them apart.
func counts() -> Dictionary:
	var found := {SAW: 0, HEARD: 0, CHANGED: 0, LESSON: lessons.size()}
	for one in events:
		var kind := String(one["kind"])
		found[kind] = int(found.get(kind, 0)) + 1
	return found


## The whole store as lines, oldest first, lessons above events. What a report
## prints when it wants to show what a character actually came to remember.
func lines() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("lessons %d" % lessons.size())
	for one in lessons:
		written.append("  %s" % one["text"])
	written.append("events %d" % events.size())
	for one in events:
		written.append("  %s" % one["text"])
	if checks.is_empty():
		return written
	written.append("checks %d" % checks.size())
	for line in check_lines():
		written.append("  %s" % line)
	return written


# --- Writing one line out of the packet ------------------------------------


# Somebody this character can see, the first time it sees them. A thing out of
# line of sight is heard rather than seen and is left to the speech lines: what
# is written down is what was looked at.
func _saw_entity(row: Dictionary, seen: Observation) -> void:
	if not bool(row["line_of_sight"]):
		return
	_write(SAW, "I saw %s, a %s, about %dm away." % [
		_called(row), row["type"], int(roundf(float(row["distance"]))),
	], seen)


# Something lying about, the first time it is seen. What it is holding is said
# only when the packet says it, which is only when it can be seen into.
func _saw_object(row: Dictionary, seen: Observation) -> void:
	if not bool(row["line_of_sight"]):
		return
	var holding := ""
	if row.has("holds"):
		holding = ", holding %d thing%s and %d coins" % [
			row["holds"], "" if int(row["holds"]) == 1 else "s", row["money"],
		]
	_write(SAW, "I saw a %s (#%d) about %dm away, %s%s." % [
		row["name"], row["id"], int(roundf(float(row["distance"]))),
		row.get("state", "there"), holding,
	], seen)


# Every line of speech in the packet, as the character would put it to itself.
# The packet holds the last few it heard, so this is a rolling window and only
# its new tail is written -- see `_new_tail`.
static func _heard_keys(seen: Observation) -> PackedStringArray:
	var written := PackedStringArray()
	for row in seen.heard:
		if bool(row["yours"]):
			written.append("I said: \"%s\"" % row["text"])
			continue
		written.append("%s %s: \"%s\"" % [
			_called(row),
			"shouted" if bool(row["shout"]) else "said to me",
			row["text"],
		])
	return written


# One entry, unless one word for word the same is already in the log.
#
# It takes the observation and not its fingerprint, so that *every* function in
# this file that puts something into a segment has one in its signature. That is
# what `tests/test_memory.gd` reads off the source: there is no way to reach
# either segment except through a door that was handed a packet.
func _write(kind: String, text: String, seen: Observation) -> void:
	var key := "%s:%s" % [kind, text]
	if int(_written.get(key, 0)) >= SEEN_ONCE:
		return
	_written[key] = int(_written.get(key, 0)) + 1
	events.append({"text": text, "kind": kind, "from": seen.digest()})


# What a row of the packet calls somebody: their name where this character knows
# one, and their id where it does not. The packet has already decided which, and
# this only prints it.
static func _called(row: Dictionary) -> String:
	var id := int(row.get("id", row.get("speaker", 0)))
	if row.get("name", null) == null:
		return "#%d" % id
	return "%s (#%d)" % [row["name"], id]


# --- The furniture ---------------------------------------------------------


# What is new in a rolling window.
#
# Both the speech and the changes arrive as the last few of a longer stream, so
# "what has happened since I last looked" is the tail of the new window past
# whatever of the old window it still overlaps. The longest suffix of `before`
# that is a prefix of `after` is that overlap; everything after it is new. With
# no overlap at all -- a character that heard six new lines between two looks --
# the whole window is new, which is right.
static func _new_tail(
	before: PackedStringArray, after: PackedStringArray
) -> PackedStringArray:
	var overlap := 0
	for size in range(mini(before.size(), after.size()), 0, -1):
		var same := true
		for at in size:
			if before[before.size() - size + at] != after[at]:
				same = false
				break
		if same:
			overlap = size
			break
	var written := PackedStringArray()
	for at in range(overlap, after.size()):
		written.append(after[at])
	return written


# The words of a query worth searching on, lowered.
static func _words_of(about: String) -> PackedStringArray:
	var found := PackedStringArray()
	for word in about.to_lower().split(" ", false):
		var one := String(word).strip_edges().lstrip("\"'#(").rstrip("\"'?.,!)")
		if one.length() >= WORD_AT_LEAST and not found.has(one):
			found.append(one)
	return found


# Whether an entry holds any of the query's words.
static func _matches(text: String, wanted: PackedStringArray) -> bool:
	var lowered := text.to_lower()
	for word in wanted:
		if lowered.contains(word):
			return true
	return false
