extends RefCounted
## The world's dungeon master: the third and last shape of language-model call in
## this game.
##
## The three differ in what makes them run, and that is the whole taxonomy:
##
##   * a **character agent** loops over one character, and is asked what that
##     character does next for as long as it is alive;
##   * the **difficulty-class agent** is hook-triggered and one-off -- it sits
##     idle until something in the world raises a check, handles that one check
##     and goes quiet;
##   * this one is **polled over the world**. Every `every` ticks it is shown the
##     world as it stands and asked what changes, out of a fixed list of
##     operations the engine exposes. Nothing raises it and nobody is its
##     subject: its subject is the place.
##
## ## What it does, and the two things it does not
##
##   1. **Look**, with `OrchestratorPrompt.watching_for`. One call, on a cadence.
##   2. **Carry out** what came back, through `WorldEffects` and nothing else. A
##      line naming an operation the engine exposes is carried out by the engine;
##      every other line changes nothing and is printed as refused. It writes no
##      state itself -- there is not one assignment to anything in the world in
##      this file, which `tests/test_orchestrator.gd` reads off the source.
##   3. **Spawn, rolls first.** A `spawn` operation rolls the sheet -- from the
##      role's bands and the region's own difficulty -- and stands the character
##      in the world with it. Only then, and in a second call with a different
##      system prompt, is anybody asked who that makes them. The order is not a
##      convention here; the second call is written out of the sheet the first
##      half already produced, so it cannot happen first, and nothing that reads
##      its answer can write a score.
##
## It does not script anything. What it may do is a list of world operations, and
## there is no quest, no beat and no intended path anywhere in this file or in
## the table it works through. And it does not reach into a mind: it never sets a
## decision function, never writes a goal, never chooses an action and never
## writes into anybody's memory. The one thing it writes onto a character sheet
## is the persona of a character it spawned itself, once, at the spawn.
##
## ## Nothing waits
##
## Every question goes to a `ModelChannel` and is polled, exactly as a
## character's decision is. A look that has been asked and not answered simply
## stays open; the world goes on turning, the characters in it go on acting, and
## the next look is not due until it is due. A run measures that rather than
## claiming it -- see `sim/scripted_world.gd`.
class_name Orchestrator

## The two stages a question can be at.
const WATCHING := "watching"
const PEOPLING := "peopling"

## How many ticks between one look at the world and the next. At
## `ModelCast.TICKS_A_SECOND` that is a look every second and a half, which is
## slower than any character's re-evaluation and faster than anything in the
## world can get far.
const EVERY := 30

## Where the answers come from.
var channel: ModelChannel = null

## The seed the world was made with, which is what a rolled sheet is drawn
## against. It enters no prompt.
var world_seed: int = 0

## How many ticks between looks, for a run that wants a different cadence.
var every: int = EVERY

## What the run cost: questions put, looks taken, and looks answered with the
## world left alone.
var calls: int = 0
var looks: int = 0
var quiet: int = 0

## Every operation the engine considered, in order, each the row `WorldEffects`
## handed back: `{"ok", "reason", "line", "target"}`.
var operations: Array[Dictionary] = []

## One row per character spawned, in the order they were spawned. Each carries
## what was rolled, when, and what was afterwards written to explain it.
var spawns: Array[Dictionary] = []

## The ids of the characters this orchestrator spawned. The only characters it
## will ever write a persona onto.
var spawned := PackedInt32Array()

## What happened, one line at a time, for a transcript to print.
var journal := PackedStringArray()

var _open: Dictionary = {}
var _due: int = 0


## An orchestrator answering out of a channel, over a world made with a seed.
static func with_channel(
	from: ModelChannel, seed_value: int, ticks_between: int = EVERY
) -> Orchestrator:
	var world := Orchestrator.new()
	world.channel = from
	world.world_seed = seed_value
	world.every = maxi(1, ticks_between)
	return world


## One tick of the orchestrator: take up whatever has been answered, then look
## again if a look is due. Called once a tick by whatever is running the world,
## and it returns immediately whatever state it is in.
func step(scene: ActionScene) -> void:
	if scene == null or channel == null:
		return
	_poll(scene)
	_look(scene)


## How many questions are outstanding right now. What a run samples once a tick
## to say, as a count of ticks rather than an argument, that the world went on
## turning while the orchestrator was thinking.
func waiting() -> int:
	return _open.size()


## Whether a character was spawned by this orchestrator.
func mine(id: int) -> bool:
	return spawned.has(id)


## How many of the operations it named the engine actually carried out.
func carried_out() -> int:
	var done := 0
	for row in operations:
		if bool(row["ok"]):
			done += 1
	return done


# --- 1. Looking ------------------------------------------------------------


func _look(scene: ActionScene) -> void:
	if scene.tick < _due or _already_watching():
		return
	_due = scene.tick + every
	var prompt := OrchestratorPrompt.watching_for(scene, world_seed)
	var ticket := channel.ask(prompt, scene.tick)
	_open[ticket] = {"stage": WATCHING}
	calls += 1
	looks += 1
	journal.append("tick %d  looked at the world (%s)" % [
		scene.tick, ModelPrompt.digest_of(prompt),
	])


func _already_watching() -> bool:
	for ticket in _open:
		if String((_open[ticket] as Dictionary)["stage"]) == WATCHING:
			return true
	return false


func _poll(scene: ActionScene) -> void:
	for ticket in _open.keys():
		var open: Dictionary = _open[ticket]
		var reply := channel.reply_to(ticket, scene.tick)
		if reply == "" and not channel.has_answered(ticket):
			continue
		_open.erase(ticket)
		if String(open["stage"]) == WATCHING:
			_watched(scene, reply)
		else:
			_peopled(scene, open, reply)


# --- 2. Carrying out what came back ---------------------------------------


func _watched(scene: ActionScene, reply: String) -> void:
	var named := WorldEffects.read(reply)
	if named.is_empty():
		if WorldEffects.says_nothing(reply):
			quiet += 1
			journal.append("tick %d  and left the world alone" % scene.tick)
			return
		operations.append({
			"ok": false, "line": ModelPrompt.said_line(reply), "target": 0,
			"reason": "no operation the engine exposes was named, so nothing changed",
		})
		journal.append("tick %d  named no operation the engine exposes" % scene.tick)
		return
	for at in named.size():
		if at >= WorldEffects.AT_MOST:
			operations.append({
				"ok": false, "line": String(named[at]["line"]), "target": 0,
				"reason": "the engine carries out at most %d" % WorldEffects.AT_MOST,
			})
			continue
		var done := WorldEffects.apply(
			scene, named[at], world_seed, spawns.size() + 1)
		operations.append(done)
		journal.append("tick %d  %-9s %s -- %s" % [
			scene.tick, "did" if bool(done["ok"]) else "would not",
			done["line"], done["reason"],
		])
		if done.has("spawned"):
			_ask_who_that_is(scene, done)


# --- 3. The spawn, in section 8's order -----------------------------------


# The sheet has already been rolled and the character is already standing in the
# world; this is the second half, and it is a second call.
func _ask_who_that_is(scene: ActionScene, done: Dictionary) -> void:
	var id := int(done["spawned"])
	var one := scene.actor_of(id)
	var sheet := _sheet_of(one)
	if sheet == null:
		return
	spawned.append(id)
	var at := Vector2(one.x, one.z)
	var row := {
		"id": id, "role": String(done.get("role", "")), "at": at,
		"rolled_at": scene.tick, "level": sheet.level,
		"rolls": sheet.scores_line(), "spread": SpawnRoll.spread_of(sheet),
		"called_when_rolled": sheet.character_name,
		"written_at": -1, "rolls_after": "", "persona": {}, "note": "not back yet",
	}
	spawns.append(row)
	var prompt := OrchestratorPrompt.peopling_for(sheet, String(row["role"]), at, id)
	var ticket := channel.ask(prompt, scene.tick)
	_open[ticket] = {"stage": PEOPLING, "id": id, "row": row}
	calls += 1
	journal.append("tick %d  #%d is rolled and standing: %s -- asked who that is (%s)" % [
		scene.tick, id, row["rolls"], ModelPrompt.digest_of(prompt),
	])


func _peopled(scene: ActionScene, open: Dictionary, reply: String) -> void:
	var row: Dictionary = open["row"]
	var id := int(open["id"])
	if not mine(id):
		row["note"] = "not this orchestrator's to write into"
		return
	var persona := OrchestratorPrompt.persona_of(reply)
	var done := WorldEffects.dress(scene, id, persona)
	row["persona"] = persona
	row["written_at"] = scene.tick
	row["note"] = String(done["reason"])
	var sheet := _sheet_of(scene.actor_of(id))
	row["rolls_after"] = "" if sheet == null else sheet.scores_line()
	journal.append("tick %d  %-9s %s" % [
		scene.tick, "wrote" if bool(done["ok"]) else "would not", done["reason"],
	])


# --- The furniture ---------------------------------------------------------


static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet
