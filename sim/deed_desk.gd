extends RefCounted
## The desk that weighs deeds: section 6's first way sentiment goes up.
##
## It watches for a goal the world has closed which one of the world's own
## records says somebody *else* brought about (`Deed`), asks a model what that
## was worth to the character that wanted it (`GoodwillPrompt.for_a_deed`), and
## writes the number the engine will accept for it into the world's own record of
## goodwill earned.
##
## ## It is hook-shaped, like the check desk, and for the same reason
##
## It is not polled for work and it does not loop. A world in which nobody
## finishes anything anybody wanted makes no call from this file however long it
## is stepped, and a world in which a character walks to where it wanted to be
## makes none either -- because walking somewhere is something that character did
## for itself, and `Deed` says so by name.
##
## ## The mark, and why it is here rather than on the goal
##
## Each closed goal is taken up once, and what remembers that is a mark on this
## desk keyed by the character and the goal's own number. It is deliberately not
## written onto the goal: a goal is a wanted state of the world and knowing
## whether a desk has looked at it is not part of being wanted. This is the same
## split the relationship graph keeps, where the read-marks live on the store
## doing the reading.
##
## ## What it may change, which is one number in one place
##
## Nothing here writes the world. There is no operation table, no object, no
## inventory and no position: the only thing this file can do to a world is write
## one row into `ActionScene.favours` -- a share `Goodwill` has read out of a
## reply and bounded -- and what that comes to for two characters is the
## relationship graph's, folded in by `CharacterUpkeep` along with every other
## thing that has happened. This file names neither the graph nor an edge, which
## `tests/test_relationships.gd` reads off the source of every model-facing file.
## A reply that says the two are now firm friends, or that a reward is owed, or
## that anything at all happened, moves nothing.
class_name DeedDesk

## Where the answers come from.
var channel: ModelChannel = null

## Every closed goal this desk has taken up, in order. One row each:
## `{"who", "who_named", "doer", "doer_named", "goal", "wanted", "what", "why",
##   "asked", "said", "share", "moved", "reason"}`.
var seen: Array[Dictionary] = []

## What the run cost and did.
var calls: int = 0
var favoured: int = 0
var refused: int = 0

## How much trust all the deeds weighed here came to, added up.
var earned: float = 0.0

## What happened, one line at a time, for a transcript to print.
var journal := PackedStringArray()

# Which closed goals have been taken up, by "<character id>:<goal number>".
var _taken: Dictionary = {}
var _open: Dictionary = {}
var _next: int = 0


## A desk answering out of a channel.
static func with_channel(from: ModelChannel) -> DeedDesk:
	var desk := DeedDesk.new()
	desk.channel = from
	return desk


## Advance every deed the world has closed, by as much as it can be advanced this
## tick. Called once a tick by whatever is running the world, exactly as
## `CheckDesk.step` is.
func step(scene: ActionScene) -> void:
	if scene == null or channel == null:
		return
	_take_up(scene)
	_poll(scene)


## How many deeds are waiting on an answer.
func waiting() -> int:
	return _open.size()


## Every row a doer was actually found for, which is what a report counts as a
## deed rather than as a goal that happened to close.
func deeds() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for row in seen:
		if int(row["doer"]) != Deed.NOBODY:
			found.append(row)
	return found


# --- Taking one up ---------------------------------------------------------


func _take_up(scene: ActionScene) -> void:
	for one in scene.actors:
		var sheet := _sheet_of(one)
		if sheet == null or sheet.goals == null:
			continue
		for goal in sheet.goals.done():
			var key := "%d:%d" % [one.id, goal.id]
			if _taken.has(key):
				continue
			_taken[key] = true
			_took_up(scene, one, sheet, goal)


func _took_up(
	scene: ActionScene, one: Combatant, sheet: Character, goal: Goal
) -> void:
	var done := Deed.done_for(goal, scene, one)
	var row := {
		"id": _next, "who": one.id, "who_named": sheet.character_name,
		"doer": int(done["who"]), "doer_named": "",
		"goal": goal.id, "wanted": goal.said(), "kind": goal.kind,
		"what": String(done["what"]), "why": String(done["why"]),
		"asked": false, "said": AbilityCheck.NOTHING_JUDGED,
		"share": AbilityCheck.NOTHING_JUDGED, "moved": false, "reason": "",
	}
	_next += 1
	seen.append(row)
	if int(done["who"]) == Deed.NOBODY:
		journal.append("tick %d  %s finished \"%s\" and nobody else is why: %s" % [
			scene.tick, sheet.character_name, goal.said(), done["why"],
		])
		return
	row["doer_named"] = ActionScene.name_of(scene.actor_of(int(done["who"])))
	var prompt := GoodwillPrompt.for_a_deed(
		goal.said(), String(done["what"]), sheet.character_name,
		String(row["doer_named"]), sheet)
	_open[int(row["id"])] = {
		"row": row, "ticket": channel.ask(prompt, scene.tick),
		"digest": GoodwillPrompt.digest_of(prompt),
	}
	row["asked"] = true
	calls += 1
	journal.append("tick %d  %s finished \"%s\" and %s is why -- asked what that"
		% [scene.tick, sheet.character_name, goal.said(), row["doer_named"]]
		+ " is worth (%s)" % _open[int(row["id"])]["digest"])


# --- The answer, and the one thing it may move -----------------------------


func _poll(scene: ActionScene) -> void:
	for id in _open.keys():
		var open: Dictionary = _open[id]
		var ticket := int(open["ticket"])
		var reply := channel.reply_to(ticket, scene.tick)
		if reply == "" and not channel.has_answered(ticket):
			continue
		_open.erase(id)
		_weighed(scene, open["row"], reply)


func _weighed(scene: ActionScene, row: Dictionary, reply: String) -> void:
	var judged := Goodwill.read(reply)
	if not bool(judged["read"]):
		row["reason"] = "%s, so nothing changed" % judged["why"]
		refused += 1
		journal.append("tick %d  %s" % [scene.tick, line_of(row)])
		return
	row["said"] = float(judged["said"])
	row["share"] = Goodwill.bounded(float(judged["said"]))
	# The one thing this file does with the number: write it into the world's own
	# record of goodwill earned, which `CharacterUpkeep` folds into the
	# relationship graph along with everything else that has happened. This file
	# names neither the graph nor an edge.
	if not scene.note_favour(
		int(row["doer"]), int(row["who"]), float(row["share"]), String(row["what"])
	):
		row["reason"] = "the world would not record goodwill earned by it," \
			+ " so nothing changed"
		refused += 1
		journal.append("tick %d  %s" % [scene.tick, line_of(row)])
		return
	row["moved"] = true
	favoured += 1
	earned += float(row["share"])
	row["reason"] = "%s of goodwill earned by %s from %s" % [
		Goodwill.said_as(float(row["share"])), row["doer_named"], row["who_named"],
	]
	journal.append("tick %d  %s" % [scene.tick, line_of(row)])


## One row as one line, for a transcript.
static func line_of(row: Dictionary) -> String:
	if int(row["doer"]) == Deed.NOBODY:
		return "%s wanted \"%s\" -- nobody else did it: %s" % [
			row["who_named"], row["wanted"], row["why"],
		]
	if not bool(row["moved"]):
		return "%s wanted \"%s\", %s did it -- %s" % [
			row["who_named"], row["wanted"], row["doer_named"], row["reason"],
		]
	return "%s wanted \"%s\", %s did it -- %s said %s, the engine moved %s: %s" % [
		row["who_named"], row["wanted"], row["doer_named"], Goodwill.KEY,
		Goodwill.said_as(float(row["said"])), Goodwill.said_as(float(row["share"])),
		row["reason"],
	]


static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
