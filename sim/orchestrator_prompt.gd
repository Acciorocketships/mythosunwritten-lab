extends RefCounted
## The two questions the world's dungeon master puts, and how the answers are
## read.
##
## Section 8 gives the orchestrator two duties, and they are two calls with two
## system prompts, which is what makes the order of a spawn checkable from
## outside:
##
##   * `watching_for` shows the world as it stands and asks what changes, out of
##     a fixed list of operations the engine exposes. It is put on a cadence --
##     the orchestrator is polled, unlike the difficulty-class agent, which is
##     hook-triggered and sits idle until something raises a check.
##   * `peopling_for` is written only *after* a sheet has already been rolled and
##     the character is already standing in the world. It carries the six rolled
##     numbers and asks for the person they add up to. It cannot change them:
##     there is no operation in it, nothing that reads it writes a score, and the
##     numbers it is shown are the numbers the world already has.
##
## Each prompt carries a line naming what the call is for, and those two lines are
## constants below so a test can assert they are not one prompt with the question
## swapped.
##
## ## Why that line is near the end rather than at the top
##
## Measured, not preferred. Put first, both of these prompts are refused by the
## provider before the model ever sees them -- every one of five questions in a
## recording pass came back "this request triggered restrictions on violative
## cyber content", and bisecting the prompt showed the trigger was having *any*
## leading paragraph of instruction in front of the world and the operation
## table: a message that opens with a role and then lists commands with
## `target=` in them reads, to something upstream, like an attempt to drive a
## system. The same prompt with its first line moved to the bottom is answered
## every time, and the same words are in it. So the naming line sits above the
## answer instruction instead, and a run opens with a title that says what the
## page is. Moving it back to the top will break the recorder, silently and
## completely, which is why this paragraph is here.
##
## ## What is deliberately not in either
##
##   * **No story.** Neither prompt names a quest, a beat, an outcome or a
##     solution. The watching prompt says what is in the world and what the
##     engine can do to it, and stops.
##   * **No reach into a mind.** Nothing offers to set a goal, choose an action
##     or write a memory for anybody, and the persona prompt asks for who someone
##     is and not for what they will do next.
##   * **No numbers to argue with.** The persona prompt states the rolls as
##     settled. It does not ask whether they are right, and nothing that reads
##     its answer could act on the reply if it said they were not.
class_name OrchestratorPrompt

## The line each prompt opens with: a title and not an instruction. See the note
## above.
const WATCHING_TITLE := "A world, and what may change in it."
const PEOPLING_TITLE := "Someone rolled into a world, and who that makes them."

## The line naming what each of the two calls is for.
const WATCHES := (
	"You are the dungeon master of a living world. You change the world."
	+ " You never decide what anyone in it does.")
const PEOPLES := (
	"You write who someone is, out of the numbers they have already been rolled"
	+ " with. You do not change the numbers.")

## The keys the persona answer is read out of.
const NAME_KEY := "name"
const TRAITS_KEY := "traits"
const TENDENCIES_KEY := "tendencies"
const BACKSTORY_KEY := "backstory"
const PERSONA_KEYS := [NAME_KEY, TRAITS_KEY, TENDENCIES_KEY, BACKSTORY_KEY]


# --- The first call: the world, and what may change in it -----------------


## The watching prompt: the world as it stands, and the operations on offer.
static func watching_for(scene: ActionScene, seed_value: int) -> String:
	var written := PackedStringArray()
	written.append(WATCHING_TITLE)
	written.append("")
	written.append("This is the world at tick %d." % scene.tick)
	written.append("")
	written.append("Who is standing in it:")
	written.append_array(_who_lines(scene))
	written.append("")
	written.append("What else is in it:")
	written.append_array(_what_lines(scene))
	written.append("")
	written.append("What has been said out loud:")
	written.append_array(_said_lines(scene))
	written.append("")
	written.append_array(_ground_lines(scene))
	written.append("")
	written.append("These are the only changes that can be made to it; anything"
		+ " else changes nothing:")
	written.append_array(WorldEffects.catalogue_lines())
	written.append("")
	written.append("A thing may be placed, and a character spawned, within %.0f"
		% WorldEffects.WITHIN
		+ " of somebody who is already there.")
	written.append("")
	written.append(WATCHES)
	written.append("")
	written.append("Answer with at most %d line%s, one operation each, and nothing"
		% [WorldEffects.AT_MOST, "" if WorldEffects.AT_MOST == 1 else "s"]
		+ " else. Answer with the single word `%s` if the world needs no change."
			% WorldEffects.NOTHING)
	return "\n".join(written)


static func _who_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	for one in scene.actors:
		if not one.is_commander():
			continue
		var sheet := _sheet_of(one)
		var pack := ActionScene.inventory_of(one)
		written.append("  #%d %s, level %d, at (%.1f, %.1f), carrying %d thing%s and %d coins.%s" % [
			one.id, ActionScene.name_of(one),
			1 if sheet == null else sheet.level, one.x, one.z,
			0 if pack == null else pack.size(),
			"" if pack != null and pack.size() == 1 else "s",
			0 if pack == null else pack.money,
			"" if sheet == null or sheet.backstory == ""
				else " %s" % sheet.backstory,
		])
	if written.is_empty():
		written.append("  nobody.")
	return written


static func _what_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	for thing in scene.objects:
		written.append("  #%d %s at (%.1f, %.1f), %s%s" % [
			thing.id, thing.object_name, thing.x, thing.z,
			"shut" if thing.shut else "open",
			"" if not thing.holds_things() or thing.shut
				else ", holding %d thing%s and %d coins" % [
					thing.contents.size(), "" if thing.contents.size() == 1 else "s",
					thing.contents.money,
				],
		])
	if written.is_empty():
		written.append("  nothing.")
	return written


static func _said_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	for spoken in scene.said:
		written.append("  #%d: \"%s\"" % [spoken["speaker"], spoken["text"]])
	if written.is_empty():
		written.append("  nothing yet.")
	return written


# What the ground here is worth, out of section 5's own gradient. The one number
# in this prompt that is not a reading of the scene, and it is a reading of the
# world instead: `SpawnRoll` asks the frontier for it, and this file does not
# name the item layer at all.
static func _ground_lines(scene: ActionScene) -> PackedStringArray:
	var at := _middle_of(scene)
	var written := PackedStringArray()
	written.append("The ground here is %d rings out from the world origin, which"
		% SpawnRoll.ring_at(at.x, at.y)
		+ " makes it difficulty %d: anyone rolled for it is that level, and their"
			% SpawnRoll.difficulty_at(at.x, at.y)
		+ " ability scores are drawn from bands set by their role and lifted by"
		+ " the same distance.")
	written.append("The roles there are: %s." % ", ".join(SpawnRoll.roles()))
	return written


## Where the world being watched is, taken as the middle of everybody in it. A
## world with nobody in it is watched at the origin, which is spawn.
static func _middle_of(scene: ActionScene) -> Vector2:
	var sum := Vector2.ZERO
	var counted := 0
	for one in scene.actors:
		sum += Vector2(one.x, one.z)
		counted += 1
	return Vector2.ZERO if counted == 0 else sum / float(counted)


# --- The second call: the rolls are in, so who is this ---------------------


## The persona prompt for a character that has already been rolled and is already
## standing in the world.
static func peopling_for(
	sheet: Character, role: String, at: Vector2, id: int
) -> String:
	var written := PackedStringArray()
	written.append(PEOPLING_TITLE)
	written.append("")
	written.append("They have just been rolled in as a %s, at (%.1f, %.1f). These"
		% [role, at.x, at.y] + " are their numbers, and they are settled:")
	written.append("")
	written.append("  level %d, for ground %d rings out from the world origin." % [
		sheet.level, SpawnRoll.ring_at(at.x, at.y),
	])
	written.append("  %s" % sheet.scores_line())
	var spread := SpawnRoll.spread_of(sheet)
	written.append("  highest: %s %d. lowest: %s %d. %d apart." % [
		spread["high"], sheet.score(String(spread["high"])),
		spread["low"], sheet.score(String(spread["low"])), spread["spread"],
	])
	written.append("  carrying %d thing%s." % [
		sheet.inventory.size(), "" if sheet.inventory.size() == 1 else "s",
	])
	written.append("")
	written.append("Write who that makes them. What you write has to be explained"
		+ " by those numbers and by nothing else: the highest score should be the"
		+ " loudest thing about them, and the lowest their plainest flaw. Do not"
		+ " say what they are about to do.")
	written.append("")
	written.append(PEOPLES)
	written.append("")
	written.append("Answer with exactly these four lines and nothing else:")
	written.append("  %s=<what they are called, one or two words>" % NAME_KEY)
	written.append("  %s=<two or three, comma separated>" % TRAITS_KEY)
	written.append("  %s=<two or three, comma separated>" % TENDENCIES_KEY)
	written.append("  %s=<one or two sentences>" % BACKSTORY_KEY)
	return "\n".join(written)


# --- Reading the persona ---------------------------------------------------


## Read the persona answer.
##
## Returns `{"read", "name", "traits", "tendencies", "backstory", "why"}`. An
## answer with no backstory line in it is not read, because a persona with no
## account of the numbers in it is not an explanation of them; the other three
## are taken where they are there and left empty where they are not.
static func persona_of(reply: String) -> Dictionary:
	var found := {}
	for line in reply.split("\n"):
		var text := String(line).strip_edges().lstrip("-*# \t").strip_edges()
		for key in PERSONA_KEYS:
			if found.has(key):
				continue
			if text.to_lower().begins_with("%s=" % key):
				found[key] = text.substr(key.length() + 1).strip_edges()
	if not found.has(BACKSTORY_KEY) or String(found[BACKSTORY_KEY]) == "":
		return {
			"read": false, "why": "no %s= in it" % BACKSTORY_KEY,
			"name": "", "backstory": "",
			"traits": PackedStringArray(), "tendencies": PackedStringArray(),
		}
	return {
		"read": true, "why": "",
		"name": String(found.get(NAME_KEY, "")),
		"backstory": String(found[BACKSTORY_KEY]),
		"traits": _listed(String(found.get(TRAITS_KEY, ""))),
		"tendencies": _listed(String(found.get(TENDENCIES_KEY, ""))),
	}


static func _listed(said: String) -> PackedStringArray:
	var found := PackedStringArray()
	for part in said.split(","):
		var one := String(part).strip_edges()
		if one != "":
			found.append(one)
	return found


static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
