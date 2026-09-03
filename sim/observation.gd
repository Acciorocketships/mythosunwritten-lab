extends RefCounted
## What one character can see from where it is standing: section 10's local,
## structured observation, assembled out of the world and out of nothing else.
##
## This is the packet a language model will later be handed. Producing it does
## not require one, and there is nothing in this file that prompts, chooses,
## decides or calls anything -- an observation is a *reading*, and what is done
## with it is somebody else's business entirely.
##
## ## What is in it, in section 10's own order
##
##   * **nearby entities** -- id; what sort of thing it is; its name if this
##     character knows it; the offset from here to there; how far away; whether
##     it is in line of sight; what it is doing if that can be seen; how hurt it
##     looks if that can be seen; and what it is wearing if that can be seen.
##   * **nearby objects** -- what sort of thing it is, where it is, and the state
##     an interaction could move: open or shut, what it wants to be opened with,
##     and what is in it when it is open.
##   * **the ground** -- a window of the tactical lattice, which is the board a
##     fight is played on and not a second representation of the same ground,
##     printed with a legend saying what each of its seven marks means.
##   * **what was heard** -- the last few lines of speech this character could
##     hear, in the order they were spoken: who spoke, what was said, and
##     whether it was spoken to this character or shouted to everyone.
##   * **what has recently changed** -- this character's own last few state
##     transitions, in words, out of `ObservationTrail`.
##
## Everything within `NEARBY` is *listed*; only what is in line of sight is
## *filled in*. That is section 10's own split -- it gives an entity a
## line-of-sight field and an object a visibility, and neither means anything if
## a thing out of sight is left out altogether -- so somebody behind a bluff
## appears with an id, a type and where the sound is coming from, and with their
## name, action, health and gear absent for a stated reason.
##
## Every field is either present with a value or *absent with a stated reason*.
## A name that is not there says it is not there because this character has not
## met the thing; a health that is not there says it is not there because the
## thing is out of line of sight. There is no field that is silently blank, and
## reading one is never guessing.
##
## ## It is local, and here is the whole of what that means
##
## Nothing in it is read from anywhere but the character's own surroundings.
## There is no weather, no season, no clock, no tick number, no seed, no region
## summary, no count of how many characters exist and no list of who is alive.
## Two facts follow that are worth stating because they are easy to lose:
##
##   * **The observation carries no tick.** A tick is a clock, and a character
##     standing in a field cannot read one. What has changed recently is said in
##     words -- "moved 0.9m north-east" -- and never as a timestamp.
##   * **There is no such thing here as a player.** Section 10 writes the entity
##     type as "NPC/player/monster/object", and that distinction cannot be made
##     from this side and must not be: `Character` has no field saying who is
##     driving it, deliberately, and an observation that answered the question
##     would be the preferential treatment the design forbids. The type reported
##     is what a thing *is* on the board -- `commander`, `cat`, `frog`, `pile` --
##     which is what anybody looking would see.
##
## ## The ground is the combat lattice, not a third grid
##
## Section 13 lists "terrain observation representation" as open and says it must
## converge with the combat lattice. It does, here, by being it: `board` is a
## `CombatBoard` built by the world's own `CombatBoardBuilder`, the same call and
## the same type a fight is played on. Nothing in this file computes a height, a
## walkability, a hole or a blocked line; every one of those is a cell of that
## board, and `reports/observation.md` carries the measurement that says the
## lattice serves.
##
## Line of sight is traced across that board too, cell by cell, so "can I see
## that" is answered by the same ground the fight would be fought on rather than
## by a second opinion about what a wall is.
##
## ## Who heard a line is the engine's answer, not a second one
##
## `ActionEngine._say` already works out who hears a line -- the one character it
## was aimed at, or everybody within earshot of a shout -- and writes that list
## into `ActionScene.said` as `heard_by`. This file reads that list and filters
## by it. There is no earshot here, no comparison of positions and no second
## opinion about who was near enough: a line is in a character's observation
## exactly when the engine put that character in its `heard_by`, or when that
## character is the one who said it. A character knows what it itself said.
##
## The consequence is worth stating because it is the engine's rule and not this
## file's: a line spoken *to* somebody is heard by that somebody alone, so
## standing beside two people talking is not the same as hearing them. Changing
## that would be changing how `say` resolves, which is the engine's business.
class_name Observation

## How far away a thing can be and still appear in the observation, in world
## units.
##
## The engine's own `SIGHT`, not a number of this file's: it is already how far a
## character can see well enough to examine something, and what appears in an
## observation should be exactly what an `examine` could be aimed at. A second
## constant here would be a second answer to one question.
const NEARBY := ActionEngine.SIGHT

## How many cells across the window of ground the readable packet prints.
##
## Section 10's own suggestion -- "a small adjacency/occupancy grid around the
## NPC (5x5 or 7x7)". The `board` itself reaches `NEARBY` in every direction,
## because line of sight to a thing forty units away cannot be traced across a
## board that stops at ten; the window is what is *printed*, and the difference
## between the two is measured in reports/observation.md.
const WINDOW := 7

## What a value that is not there is written as.
const ABSENT := "?"

# Why a field is absent. Each of these is a sentence a reader can act on rather
# than a blank.
const UNMET := "this character has not met it"
const NAMELESS := "it has no name"
const UNSEEN := "not in line of sight"
const NOT_DRIVEN := "nothing is driving this scene"
const CARRIES_NOTHING := "it carries nothing"
const UNWATCHED := "nothing has been watching this character"
const GONE := "it is no longer in the world"

## The eight ways a piece of ground can read, one character each, in the order
## they are tested. A cell that is more than one of these is written as the first
## that fits, because that is the one that stops you.
const GLYPHS := {
	"here": "@", "hole": "~", "built": "x", "wall": "#",
	"cliff": "!", "stand": ".", "unknown": "?",
}

## What each of those marks means, in words, for a reader who has never seen this
## world before. Printed into the packet itself as a legend, because a grid of
## punctuation with no key is not an observation of anything: the first
## model-driven run was handed the window seventeen times and never once chose a
## position on it.
##
## One entry per mark, keyed the same way, so a mark cannot be added to the
## window without being named here. It says what a mark *is*, never what may be
## done about it: what a piece may do on a piece of ground is the engine's answer
## and is nowhere in this packet.
const MEANS := {
	"here": "where you stand",
	"hole": "a hole with nothing to stand on",
	"built": "a building",
	"wall": "a face of ground too tall to climb",
	"cliff": "the edge of a drop",
	"stand": "ground to walk on",
	"unknown": "not read",
}

## How many lines of speech the packet carries, newest last. The same few as
## `ObservationTrail.KEEP`, and for the same reason: enough that a greeting and
## the answer to it are both still in view, short enough that the packet does not
## turn into a transcript.
const HEARD := 6


## Who is observing: their own id, name and body, which a character knows
## exactly because it is their own.
var self_id: int = 0
var self_name: String = ""
var self_type: String = ""
var self_level: int = 1
var self_status: int = 1
var self_health: int = 0
var self_max_health: int = 0
var self_x: float = 0.0
var self_y: float = 0.0
var self_z: float = 0.0
var self_heading: float = 0.0
var self_on_board: bool = false
var self_money: int = 0
var self_carrying := PackedStringArray()
var self_wearing := PackedStringArray()

## Everyone else within `NEARBY`, nearest first and by id where two are equally
## near. One dictionary per entity, in section 10's fields.
var entities: Array[Dictionary] = []

## Everything that is not a character within `NEARBY`, ordered the same way.
var objects: Array[Dictionary] = []

## The ground, as the tactical lattice reads it. The same type a fight is played
## on; see the note at the head of this file.
var board: CombatBoard = null

## Which cell of that lattice this character is standing on.
var here := Vector2i.ZERO

## The last few lines of speech this character heard, oldest first: one
## dictionary per line, with who spoke, what was said, and whether it was spoken
## to this character or shouted. Filled from the engine's own `heard_by`.
var heard: Array[Dictionary] = []

## This character's own last few state transitions, in words, newest last.
var recent := PackedStringArray()

## Why there are none, or "" when there are. Empty `recent` with an empty reason
## means nothing has changed; with a reason it means nothing was watching.
var recent_absent: String = ""

# The world's relationship graph, for the one question this packet asks it:
# whether the character looking has met the thing it is looking at.
#
# ## What a character may see about a relationship, stated
#
# **Its own edges, and nothing else.** The graph is reached from here through
# `knows(self_id, ...)` and `edges_of(self_id)` -- both keyed by the id of the
# character this packet belongs to -- so what two other people are to each other
# is not reachable from where this character stands, any more than another
# character's memory is. That is the same locality rule everything else in this
# file obeys: an observation is a reading of one character's own surroundings.
#
# The four numbers themselves are deliberately *not* written into the packet
# today. They are what section 6's ownership maths reads and what section 6's
# diplomacy check moves, and neither exists yet; putting them in front of a
# decision function before either does would change what characters choose, which
# is not what recording what happened is for. What is in the packet is what the
# graph has always been asked here: whether these two have met.
var _known: RelationshipGraph = null


## Assemble the observation one character has of the world it is standing in.
##
## A pure function of the scene, the character and -- for the recent changes
## alone -- whatever has been watching that character. Two calls with the same
## three produce the same observation, in this process and in any other.
static func of(
	scene: ActionScene, actor: Combatant, trail: ObservationTrail = null
) -> Observation:
	var seen := Observation.new()
	seen._known = null if scene == null else scene.relationships
	seen._describe_self(actor)
	seen.board = _ground_around(scene, actor)
	seen.here = CombatBoard.cell_of(actor.x, actor.z, seen.board.cell_size)
	seen._gather(scene, actor)
	seen._listen(scene, actor)
	if trail == null or not trail.watches(actor.id):
		seen.recent_absent = UNWATCHED
	else:
		seen.recent = trail.recent_of(actor.id)
	return seen


# --- Who is looking -------------------------------------------------------


func _describe_self(actor: Combatant) -> void:
	self_id = actor.id
	self_type = actor.piece.kind_name()
	self_x = actor.x
	self_y = actor.y
	self_z = actor.z
	self_heading = actor.heading
	self_on_board = actor.fighting
	self_health = actor.piece.health
	self_max_health = actor.piece.max_health()
	self_level = actor.piece.level
	var sheet := _sheet_of(actor)
	if sheet != null:
		self_name = sheet.character_name
		self_status = sheet.status()
	else:
		self_status = self_level
	var pack := ActionScene.inventory_of(actor)
	if pack == null:
		return
	self_money = pack.money
	for entry in pack.carried:
		self_carrying.append(ObservationTrail.name_of_entry(entry))
	var worn := pack.equipment()
	for slot in worn:
		self_wearing.append("%s=%s" % [
			slot, ObservationTrail.name_of_entry(worn[slot]),
		])
	# What is carried is a set, not a history: two characters that bought the
	# same things in different orders should read the same. What is worn is
	# already in slot order and is left in it.
	var sorted := Array(self_carrying)
	sorted.sort()
	self_carrying = PackedStringArray(sorted)


# --- What is around it ----------------------------------------------------


func _gather(scene: ActionScene, actor: Combatant) -> void:
	var near: Array[Dictionary] = []
	for one in scene.actors:
		if one.id == actor.id:
			continue
		var gap := actor.distance_to(one)
		if gap > NEARBY:
			continue
		near.append({"thing": one, "gap": gap, "id": one.id})
	var near_objects: Array[Dictionary] = []
	for thing in scene.objects:
		var gap := thing.distance_from(actor.x, actor.z)
		if gap > NEARBY:
			continue
		near_objects.append({"thing": thing, "gap": gap, "id": thing.id})
	_sort_by_nearness(near)
	_sort_by_nearness(near_objects)

	# Who is near enough to be named in somebody else's business: a character
	# can see whom a fighter is swinging at only when it can see the target too.
	var visible := {}
	for row in near:
		visible[int(row["id"])] = row["thing"]

	for row in near:
		entities.append(_entity_row(scene, actor, row["thing"], float(row["gap"]), visible))
	for row in near_objects:
		objects.append(_object_row(actor, row["thing"], float(row["gap"])))


# One entity, in section 10's fields, with every absence given its reason.
func _entity_row(
	scene: ActionScene,
	actor: Combatant,
	one: Combatant,
	gap: float,
	visible: Dictionary,
) -> Dictionary:
	var sighted := sees(board, here, CombatBoard.cell_of(one.x, one.z, board.cell_size))
	var row := {
		"id": one.id,
		"type": one.piece.kind_name(),
		"offset": Vector3(one.x - actor.x, one.y - actor.y, one.z - actor.z),
		"distance": gap,
		"line_of_sight": sighted,
	}
	_name_field(row, actor, one)
	if not sighted:
		row["doing"] = null
		row["doing_absent"] = UNSEEN
		row["health"] = null
		row["health_absent"] = UNSEEN
		row["equipment"] = null
		row["equipment_absent"] = UNSEEN
		return row
	var seen := ActionEngine.observed_of(one)
	row["health"] = seen["health"]
	if seen.has("equipment"):
		row["equipment"] = seen["equipment"]
	else:
		row["equipment"] = null
		row["equipment_absent"] = CARRIES_NOTHING
	if not scene.in_progress.is_valid():
		row["doing"] = null
		row["doing_absent"] = NOT_DRIVEN
	else:
		row["doing"] = _doing(scene, actor, one, visible)
	return row


# What a thing is called, if this character knows.
#
# Knowing a name is not a fact about the thing; it is a fact about the character
# looking. Two ways it can be there, and there is no third:
#
#   * the two are of one band -- a character knows the people it stands with;
#   * the world's relationship graph has an edge between the two, which is the
#     world's own record that something has actually passed between them: a word
#     heard, a trade honoured, a blow struck (see sim/relationship_graph.gd).
#
# It used to be the second of those read off a dictionary on the looker's own
# sheet. It is the graph now for the reason the graph exists: having met
# somebody is not a fact one of the two can hold privately, and two sheets each
# keeping their own half of it would be two answers to whether these two have
# met.
#
# Everything else is a stranger, however plainly it can be seen, which is the
# whole point: a name is knowledge and a silhouette is not.
func _name_field(row: Dictionary, actor: Combatant, one: Combatant) -> void:
	var known := one.band != Combatant.NO_BAND and one.band == actor.band
	if not known:
		known = _known != null and _known.knows(actor.id, one.id)
	if not known:
		row["name"] = null
		row["name_absent"] = UNMET
		return
	var theirs := _sheet_of(one)
	if theirs == null or theirs.character_name == "":
		row["name"] = null
		row["name_absent"] = NAMELESS
		return
	row["name"] = theirs.character_name


# What somebody in sight is part-way through, in the words of the one list of
# actions: the action's own kind, and -- only when the character looking can see
# the target as well -- who it is aimed at.
#
# Deliberately not a phrase per action. There are twelve actions and one list of
# them; a table of readable sentences here would be a thirteenth.
func _doing(
	scene: ActionScene, actor: Combatant, one: Combatant, visible: Dictionary
) -> String:
	var busy: Variant = scene.in_progress.call(one.id)
	if busy == null:
		return "nothing"
	var chosen := busy as Action
	var at := chosen.target_id()
	if at == ActionCatalog.NOBODY or at == one.id:
		return chosen.kind
	if at == actor.id:
		return "%s you" % chosen.kind
	if not visible.has(at):
		return chosen.kind
	var row := {}
	_name_field(row, actor, visible[at])
	return "%s %s" % [
		chosen.kind, "#%d" % at if row["name"] == null else row["name"],
	]


# One object. What can be seen of it is the object's own answer, forwarded --
# `WorldObject.observed()` is already "what can be seen of it from outside" and
# a second reading of the same state here would be a second answer.
func _object_row(actor: Combatant, thing: WorldObject, gap: float) -> Dictionary:
	var sighted := sees(board, here, CombatBoard.cell_of(thing.x, thing.z, board.cell_size))
	var row := {
		"id": thing.id,
		"type": "pile" if thing.pile else "object",
		"name": thing.object_name,
		"offset": Vector3(thing.x - actor.x, thing.y - actor.y, thing.z - actor.z),
		"distance": gap,
		"line_of_sight": sighted,
	}
	if not sighted:
		row["state"] = null
		row["state_absent"] = UNSEEN
		return row
	var seen := ActionEngine.observed_of(thing)
	row["state"] = "shut" if thing.shut else "open"
	if seen.has("needs"):
		row["needs"] = seen["needs"]
	if seen.has("holds"):
		row["holds"] = seen["holds"]
		row["money"] = seen["money"]
	return row


# --- What was said --------------------------------------------------------


# Everything this character could hear, out of everything that has been said.
#
# The filter is one line long and it is the engine's own answer: a character
# hears a line when the engine put it in that line's `heard_by`, or when it is
# the one who said it. Nothing here measures how far away the speaker was.
func _listen(scene: ActionScene, actor: Combatant) -> void:
	var mine: Array[Dictionary] = []
	for spoken in scene.said:
		var by := int(spoken["speaker"])
		var to_them := PackedInt32Array(spoken["heard_by"])
		if by != actor.id and not to_them.has(actor.id):
			continue
		mine.append(spoken)
	for at in range(maxi(0, mine.size() - HEARD), mine.size()):
		heard.append(_heard_row(scene, actor, mine[at]))


# One line of speech, in the fields a listener has: who said it, what they said,
# and whom it was said to. The order is the order it was said in, which is the
# order `ActionScene.said` is already kept in.
func _heard_row(
	scene: ActionScene, actor: Combatant, spoken: Dictionary
) -> Dictionary:
	var by := int(spoken["speaker"])
	var to_id := int(spoken["to"])
	var row := {
		"speaker": by,
		"yours": by == actor.id,
		"text": String(spoken["text"]),
		"shout": bool(spoken["shout"]),
		"to": to_id,
		"to_you": to_id == actor.id,
	}
	_speaker_name(row, scene, actor, by)
	return row


# What the speaker is called, by the same rule that names anybody else in the
# packet: a name is knowledge of the character looking, not a fact about the one
# speaking. Its own name it knows; a speaker who has since fallen out of the
# world it can no longer put a name to.
func _speaker_name(
	row: Dictionary, scene: ActionScene, actor: Combatant, by: int
) -> void:
	if by == actor.id:
		if self_name == "":
			row["name"] = null
			row["name_absent"] = NAMELESS
		else:
			row["name"] = self_name
		return
	var speaker := scene.actor_of(by)
	if speaker == null:
		row["name"] = null
		row["name_absent"] = GONE
		return
	_name_field(row, actor, speaker)


# --- Line of sight --------------------------------------------------------


## Whether a straight line from one cell to another is clear on this board.
##
## Traced across the lattice a fight is played on, cell by cell, and stopped by
## exactly what stops a line there: a building, or a face of ground taller than a
## piece can climb. A hole does not stop it -- you can see across a chasm, which
## is the same rule that lets you shoot across one.
##
## The two end cells are not tested. A piece can stand on a cell that blocks a
## line -- the top of a bluff is standable and its face is what does the blocking
## -- so testing the ends would make anyone standing on high ground invisible,
## including to themselves.
static func sees(on: CombatBoard, from: Vector2i, to: Vector2i) -> bool:
	if on == null or not on.contains(from) or not on.contains(to):
		return false
	if from == to:
		return true
	var start := on.centre(from)
	var finish := on.centre(to)
	var along := finish - start
	# A quarter of a cell per sample: short enough that no cell the segment
	# crosses is stepped over, and fixed rather than adaptive so that the same
	# two cells are always tested the same way.
	var steps := int(ceilf(along.length() / (on.cell_size * 0.25)))
	for step in range(1, steps):
		var at := start + along * (float(step) / float(steps))
		var cell := CombatBoard.cell_of(at.x, at.y, on.cell_size)
		if cell == from or cell == to:
			continue
		if on.blocks_line(cell):
			return false
	return true


# The ground around a character, read on the storey it is standing on, out to
# `NEARBY` so that line of sight to anything reported can be traced across it.
static func _ground_around(scene: ActionScene, actor: Combatant) -> CombatBoard:
	var builder := CombatBoardBuilder.new(scene.terrain)
	return builder.build(actor.x, actor.z, actor.y, NEARBY)


# --- The readable packet --------------------------------------------------


## The whole observation as lines of text: what a model would be handed, and
## what `reports/observation.md` measures.
func lines() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("observation for #%d %s" % [
		self_id, "-" if self_name == "" else self_name,
	])
	written.append("  you        %s level %d status %d hp %d/%d at (%.3f, %.3f, %.3f) facing %.2f %s" % [
		self_type, self_level, self_status, self_health, self_max_health,
		self_x, self_y, self_z, self_heading,
		"on the board" if self_on_board else "in the world",
	])
	written.append("  carrying   %s (%d coins)" % [
		"nothing" if self_carrying.is_empty() else ", ".join(self_carrying),
		self_money,
	])
	written.append("  wearing    %s" % [
		"nothing" if self_wearing.is_empty() else " ".join(self_wearing),
	])
	written.append("  entities   %d within %.1f" % [entities.size(), NEARBY])
	for row in entities:
		written.append_array(_entity_lines(row))
	written.append("  objects    %d within %.1f" % [objects.size(), NEARBY])
	for row in objects:
		written.append_array(_object_lines(row))
	written.append_array(ground_lines())
	written.append_array(heard_lines())
	written.append("  recently   %s" % (
		recent_absent if recent_absent != "" else "%d change%s" % [
			recent.size(), "" if recent.size() == 1 else "s",
		]))
	for change in recent:
		written.append("    " + change)
	return written


func _entity_lines(row: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()
	var offset: Vector3 = row["offset"]
	written.append("    #%-3d %-10s %-8s (%+.1f, %+.1f, %+.1f) %6.2f %-6s doing %-14s health %-10s wearing %s" % [
		row["id"], row["type"], _or_absent(row, "name"),
		offset.x, offset.y, offset.z, row["distance"],
		"seen" if row["line_of_sight"] else "unseen",
		_or_absent(row, "doing"), _or_absent(row, "health"),
		_or_absent(row, "equipment"),
	])
	var why := _absences(row, ["name", "doing", "health", "equipment"])
	if why != "":
		written.append("         not shown: %s" % why)
	return written


func _object_lines(row: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()
	var offset: Vector3 = row["offset"]
	var holds := ""
	if row.has("holds"):
		holds = " holds %d, %d coins" % [row["holds"], row["money"]]
	var needs := ""
	if row.has("needs"):
		needs = " opened by %s" % row["needs"]
	written.append("    #%-3d %-10s %-8s (%+.1f, %+.1f, %+.1f) %6.2f %-6s %s%s%s" % [
		row["id"], row["type"], row["name"],
		offset.x, offset.y, offset.z, row["distance"],
		"seen" if row["line_of_sight"] else "unseen",
		_or_absent(row, "state"), holds, needs,
	])
	var why := _absences(row, ["state"])
	if why != "":
		written.append("         not shown: %s" % why)
	return written


## What was heard, oldest first: one line per line of speech, saying who spoke,
## what they said, and whether it was said to this character or shouted to
## everyone within earshot.
##
## A character's own words are in it too, written as "you", because a character
## that could not tell it had already spoken would have no way to know it was
## repeating itself.
func heard_lines() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("  heard      %d line%s of speech, oldest first" % [
		heard.size(), "" if heard.size() == 1 else "s",
	])
	for row in heard:
		written.append("    %s %s \"%s\"" % [
			_speaker_of(row), _aimed_of(row), row["text"],
		])
		var why := _absences(row, ["name"])
		if why != "":
			written.append("         not shown: %s" % why)
	return written


# Who said a line, as the listener would put it: itself as "you", anybody else by
# id and by name where it knows one.
static func _speaker_of(row: Dictionary) -> String:
	if bool(row["yours"]):
		return "you"
	return "#%d %s" % [row["speaker"], _or_absent(row, "name")]


# Whom a line was aimed at: everyone within earshot, this character, or somebody
# else by id.
static func _aimed_of(row: Dictionary) -> String:
	if bool(row["shout"]):
		return "shouted"
	if bool(row["to_you"]):
		return "said to you"
	return "said to #%d" % int(row["to"])


## The window of ground, as the lattice reads it: one token per cell, north at
## the top and east to the right, each token the cell's own character followed by
## its height relative to where this character is standing.
##
## `width` is how many cells across, and it is a parameter for one reason: the
## walkthrough prints the same observation's ground at four widths so that the
## cost of a wider window is a measured number rather than a preference. The
## packet itself always uses `WINDOW`.
func ground_lines(width: int = WINDOW) -> PackedStringArray:
	var written := PackedStringArray()
	if board == null:
		written.append("  ground     %s (%s)" % [ABSENT, "there is no ground to read"])
		return written
	var across := maxi(1, width | 1)
	written.append(
		"  ground     %dx%d cells of %.1f, north up, east right; each mark is"
		% [across, across, board.cell_size]
		+ " followed by how far that cell stands above you")
	written.append("  legend     " + legend_line())
	var half := across / 2
	for row in range(-half, half + 1):
		var tokens := PackedStringArray()
		for column in range(-half, half + 1):
			tokens.append(_cell_token(here + Vector2i(column, row)))
		written.append("    " + " ".join(tokens))
	return written


# One cell as a token: what it is, and how far above or below this character it
# stands, rounded to whole world units. A hole has no height and says so.
func _cell_token(cell: Vector2i) -> String:
	var glyph := glyph_of(board, cell, here)
	if board.is_hole(cell) or not board.contains(cell):
		return "%s%-3s" % [glyph, "-"]
	return "%s%-3d" % [glyph, int(roundf(board.height_at(cell) - self_y))]


## The legend: every mark the window can hold and what it means, in one line and
## in the order the marks are tested.
##
## Read out of the two tables above rather than written out here, so a mark and
## its meaning cannot drift apart.
static func legend_line() -> String:
	var written := PackedStringArray()
	for key in GLYPHS:
		written.append("%s %s" % [GLYPHS[key], MEANS[key]])
	return "; ".join(written)


## What one cell reads as, in one character. First match wins, because the first
## match is the one that stops you.
static func glyph_of(on: CombatBoard, cell: Vector2i, standing_on: Vector2i) -> String:
	if cell == standing_on:
		return GLYPHS["here"]
	if not on.contains(cell):
		return GLYPHS["unknown"]
	if on.is_hole(cell):
		return GLYPHS["hole"]
	if on.blocks_move(cell):
		return GLYPHS["built"]
	if on.blocks_line(cell):
		return GLYPHS["wall"]
	if on.is_cliff_edge(cell):
		return GLYPHS["cliff"]
	if on.is_standable(cell):
		return GLYPHS["stand"]
	return GLYPHS["unknown"]


## How many entries the observation holds: everyone in it, everything in it,
## every cell of ground printed, every line of speech heard and every change
## reported. The number reports/observation.md quotes beside the character
## count.
func entry_count() -> int:
	return entities.size() + objects.size() + WINDOW * WINDOW \
		+ heard.size() + recent.size()


## How many characters of text the readable packet comes to, newlines included.
func text_length() -> int:
	return text().length()


## The readable packet as one string.
func text() -> String:
	return "\n".join(lines())


## A short, stable fingerprint of the whole observation. Two characters with the
## same surroundings fingerprint the same; two processes on one seed do too.
func digest() -> String:
	return text().sha256_text().substr(0, 16)


# --- The furniture --------------------------------------------------------


# A field's value, or the absent mark. Never a blank: a blank is the thing this
# file exists to avoid.
static func _or_absent(row: Dictionary, key: String) -> String:
	var value: Variant = row.get(key, null)
	return ABSENT if value == null else str(value)


# Every absent field of a row, grouped by the reason they are absent, so a row
# with three fields missing for one reason says it once.
static func _absences(row: Dictionary, keys: Array) -> String:
	var reasons: Dictionary = {}
	var order := PackedStringArray()
	for key in keys:
		var why := String(row.get("%s_absent" % key, ""))
		if why == "":
			continue
		if not reasons.has(why):
			reasons[why] = PackedStringArray()
			order.append(why)
		reasons[why].append(key)
	var written := PackedStringArray()
	for why in order:
		written.append("%s (%s)" % [", ".join(reasons[why]), why])
	return "; ".join(written)


# Nearest first, and by id where two are equally near, so the order is the same
# in every process. `piles_near` sorts the same way and for the same reason.
static func _sort_by_nearness(rows: Array[Dictionary]) -> void:
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left["gap"] == right["gap"]:
			return int(left["id"]) < int(right["id"])
		return float(left["gap"]) < float(right["gap"]))


static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
