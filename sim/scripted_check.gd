extends RefCounted
## The difficulty-class run: four attempts, two of which are rolled for and two of
## which are not, because the character already remembers how attempts of that
## shape go.
##
## One character, Rook, walks a written-down list of actions past four shut things
## it has no key to, offering each one a tool the world has no rule for. Every one
## of those four attempts trips `AbilityCheck.HOOK` in `ActionEngine._interact`
## and raises a check on the world. What `CheckDesk` then does with them is the
## whole point of the run:
##
##   1. **oak chest, iron pry bar** -- a shape this character has never attempted.
##      One call to judge it, the engine rolls, and on a success a second call
##      with a different system prompt resolves it into operations the engine
##      carries out.
##   2. **another oak chest, the same bar** -- the same shape. Settled out of
##      Rook's own memory: no call, no roll, and the operations that worked the
##      first time carried out again against the thing in front of it now.
##   3. **hazel crate, whittling knife** -- a different shape, so it is judged and
##      rolled like the first.
##   4. **another hazel crate, the same knife** -- the same shape as 3, settled out
##      of memory again, and settled the *same way* it went the first time,
##      whichever way that was.
##
## Rook's mind here is a written-down plan and not a model, on purpose: this run
## is about the check layer, and a character agent choosing its own way through
## would make what is being measured depend on what it chose. The only model calls
## in it are the difficulty-class agent's.
##
## ## The roll seed is not the world seed
##
## `ROLL_SEED` seeds the dice and nothing else. It enters no prompt -- the judging
## question is written before any die is drawn, and the resolving question is told
## only that the attempt succeeded -- so changing it cannot change the *wording* of
## a question.
##
## It can change *how many* questions there are, and that is worth saying plainly:
## a check that fails asks one question and a check that passes asks two, so a
## seed at which the third attempt succeeded would put a fourth question the
## recording has no reply for. The recording and the seed are therefore a pair,
## exactly as the recording and the prompts are: change one and re-record. This
## seed is the value below because at it the run shows a success and a failure,
## and both of them reused -- which is worth more as evidence than four of a kind.
class_name ScriptedCheck

## The world this is played on, which is the one every other run is played on.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE
const LOOP_SEED := ScriptedLoop.LOOP_SEED

## What seeds the dice. See the note above: it is in no prompt.
const ROLL_SEED := 1

## How long the run is. Long enough for four walks, four attempts and the answers
## to all of them to land: the run raises its checks about twenty-six ticks apart
## and the last of them needs its answers back before the last tick.
const TICKS := 140

## Who attempts them.
const ROOK := "Rook"
const ROOK_LEVEL := 2

## What Rook is carrying. Neither of them is what anything here opens with.
const PRY_BAR := "iron pry bar"
const KNIFE := "whittling knife"

## What everything here actually opens with, and which nobody has.
const KEY := "brass key"

## The four shut things, as `[name, offset, what is inside, how many coins]`.
const OAK := "oak chest"
const HAZEL := "hazel crate"
const SHUT_THINGS := [
	{"name": OAK, "at": Vector2(6.0, 0.0), "holds": "linen hood", "coins": 7},
	{"name": OAK, "at": Vector2(6.0, 8.0), "holds": "wool cap", "coins": 3},
	{"name": HAZEL, "at": Vector2(-6.0, 0.0), "holds": "", "coins": 0},
	{"name": HAZEL, "at": Vector2(-6.0, -8.0), "holds": "", "coins": 0},
]

## Which tool is offered to which of them, by index into `SHUT_THINGS`.
const OFFERS := [PRY_BAR, PRY_BAR, KNIFE, KNIFE]


# --- The world -------------------------------------------------------------


## Set the run out: Rook with two tools, and four shut things nothing here opens.
static func stage(seed_value: int = SEED) -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(seed_value))
	var rook := scene.add_actor(Combatant.commander_at(
		WHERE.x, WHERE.y, 0.0, 0.0, ROOK_LEVEL, AssetTags.ROGUE))
	var sheet := Character.make(ROOK, ROOK_LEVEL)
	sheet.record_scores(ScriptedScenario.ROLL)
	(rook.piece as Commander).adopt(sheet)
	sheet.inventory.carry(_tool(PRY_BAR))
	sheet.inventory.carry(_tool(KNIFE))
	rook.settle(scene.terrain)

	for row in SHUT_THINGS:
		var holding := Inventory.of([], int(row["coins"])) if String(row["holds"]) == "" \
			else Inventory.of([_wearable(String(row["holds"]))], int(row["coins"]))
		scene.add_object(WorldObject.chest(
			String(row["name"]),
			WHERE.x + (row["at"] as Vector2).x, WHERE.y + (row["at"] as Vector2).y,
			holding, KEY))
	return scene


## What Rook does, in order: walk to each shut thing and offer it a tool.
##
## A written-down plan, read by `DecisionSource.plan` against the number of
## actions the world says have been carried out -- the same decision function a
## person's choices are replayed through.
static func choices(scene: ActionScene) -> Array:
	var written := []
	for at in SHUT_THINGS.size():
		var thing := scene.objects[at]
		written.append(Action.go_to(thing.id))
		written.append(Action.interact(thing.id, String(OFFERS[at])))
	written.append(Action.wait(4))
	return written


# --- Living it -------------------------------------------------------------


## Play the run and return everything a transcript or a test wants out of it.
static func played_with(
	channel: ModelChannel, ticks: int = TICKS, seed_value: int = SEED,
	roll_seed: int = ROLL_SEED
) -> Dictionary:
	var scene := stage(seed_value)
	var rook := _named(scene, ROOK)
	_sheet(rook).decide = DecisionSource.plan(choices(scene))
	var loop := ControlLoop.on(scene, LOOP_SEED)
	var desk := CheckDesk.with_channel(channel, roll_seed)
	var opened := scene.lines()
	for _step in maxi(0, ticks):
		loop.step()
		desk.step(scene)
	return {
		"scene": scene, "loop": loop, "desk": desk, "rook": rook,
		"memory": _sheet(rook).memory, "opened": opened, "channel": channel,
	}


## The run as a transcript.
static func play(
	channel: ModelChannel, ticks: int = TICKS, seed_value: int = SEED,
	roll_seed: int = ROLL_SEED
) -> PackedStringArray:
	var played := played_with(channel, ticks, seed_value, roll_seed)
	var scene: ActionScene = played["scene"]
	var desk: CheckDesk = played["desk"]

	var written := PackedStringArray()
	written.append_array(_opening(played, ticks, seed_value, roll_seed))
	written.append("")
	written.append_array(_two_prompts_lines())
	written.append("")
	written.append_array(_what_the_character_did_lines(played["loop"]))
	written.append("")
	written.append_array(_what_happened_lines(desk))
	written.append("")
	written.append_array(check_lines(desk))
	written.append("")
	written.append_array(cost_lines(desk))
	written.append("")
	written.append_array(memory_lines(played["memory"]))
	written.append("")
	written.append("after %d ticks" % scene.tick)
	for line in scene.lines():
		written.append("  %s" % line)
	written.append("  fingerprint %s" % scene.fingerprint())
	written.append("")
	written.append_array(questions_lines(played))
	return written


# --- The head --------------------------------------------------------------


static func _opening(
	played: Dictionary, ticks: int, seed_value: int, roll_seed: int
) -> PackedStringArray:
	var channel: ModelChannel = played["channel"]
	var written := PackedStringArray()
	written.append("difficulty-class run seed=%d roll_seed=%d ticks=%d where=(%.1f, %.1f)"
		% [seed_value, roll_seed, ticks, WHERE.x, WHERE.y])
	written.append("  hook       %s -- a check is raised there and nowhere else"
		% AbilityCheck.HOOK)
	written.append("  channel    %s -- %s" % [channel.kind, channel.why])
	written.append("  recording  %s" % channel.recorded)
	written.append("  rolls      d%d, ability score + roll vs the class, in the engine"
		% AbilityCheck.DIE)
	written.append("  who        %s, carrying %s and %s, with no %s" % [
		ROOK, PRY_BAR, KNIFE, KEY,
	])
	written.append("  what       %d shut things, none of which either tool opens"
		% SHUT_THINGS.size())
	written.append("")
	written.append("the world at the start")
	for line in played["opened"]:
		written.append("  %s" % line)
	return written


## The two system prompts, named side by side, so that "a second call with a
## different system prompt" is visible rather than asserted.
static func _two_prompts_lines() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("two prompts, two calls")
	written.append("  judging    %s" % CheckPrompt.JUDGES)
	written.append("  resolving  %s" % CheckPrompt.RESOLVES)
	written.append("  and the resolving call may name only these, which the engine"
		+ " carries out:")
	for line in CheckEffects.catalogue_lines():
		written.append("  " + line)
	return written


## What Rook actually did, off the control loop's own journal, so that the four
## attempts and the walks between them can be counted rather than assumed.
static func _what_the_character_did_lines(loop: ControlLoop) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what the character did")
	for line in loop.journal:
		written.append("  %s" % line)
	return written


static func _what_happened_lines(desk: CheckDesk) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what happened, as it happened")
	for line in desk.journal:
		written.append("  %s" % line)
	return written


# --- The tables ------------------------------------------------------------


## One row per check: what was attempted, how it was settled, and the arithmetic.
static func check_lines(desk: CheckDesk) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("the checks")
	written.append("  %-3s %-34s %-11s %-5s %-5s %-5s %-5s %-5s %s" % [
		"#", "context", "settled by", "abil", "score", "roll", "total", "dc", "verdict",
	])
	for check in desk.seen:
		written.append("  %-3d %-34s %-11s %-5s %-5d %-5d %-5d %-5d %s" % [
			check.id, check.context, check.how, check.ability, check.score,
			check.roll, check.total, check.difficulty,
			"passed" if check.passed else "failed",
		])
		for row in check.operations:
			written.append("      %-6s %-40s %s" % [
				"did" if bool(row["ok"]) else "would not", row["line"], row["reason"],
			])
	return written


## What the run cost, and what it saved.
static func cost_lines(desk: CheckDesk) -> PackedStringArray:
	var written := PackedStringArray()
	var settled := desk.settled()
	written.append("what it cost")
	written.append("  checks     %d raised, %d settled" % [desk.seen.size(), settled])
	written.append("  calls      %d put to a model" % desk.calls)
	written.append("  rolls      %d rolled by the engine" % desk.rolls)
	written.append("  remembered %d settled out of a character's memory, with"
		% desk.reused + " neither a call nor a roll")
	if settled > 0:
		written.append("  which is   %.2f calls a settled check, against the %.2f it"
			% [float(desk.calls) / float(settled),
				float(desk.calls + desk.reused) / float(settled)]
			+ " would have been had every one of them been judged afresh")
	return written


## What is in the character's memory afterwards: the checks segment, and the
## first-person lines the same writes put in the log.
static func memory_lines(remembered: CharacterMemory) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what %s remembers about it" % ROOK)
	written.append("  checks     %d, one per triggering context" % remembered.checks.size())
	for line in remembered.check_lines():
		written.append("    %s" % line)
	written.append("  and in its own account of itself:")
	for one in remembered.events:
		if String(one["kind"]) == CharacterMemory.CHECK:
			written.append("    %s" % one["text"])
	return written


## The two questions in full, so the difference between them can be read.
static func questions_lines(played: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()
	var channel: ModelChannel = played["channel"]
	var asked := channel.questions()
	if asked.is_empty():
		written.append("the run asked nothing")
		return written
	written.append("the two questions in full")
	for at in mini(2, asked.size()):
		written.append("")
		written.append("  --- question %d, %d characters, digest %s ---" % [
			at + 1, String(asked[at]["prompt"]).length(), asked[at]["digest"],
		])
		for line in String(asked[at]["prompt"]).split("\n"):
			written.append("  %s" % line)
	return written


# --- The furniture ---------------------------------------------------------


static func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


static func _wearable(called: String) -> Item:
	return Item.armour(
		called, Item.SLOT_HELMET, 2, ItemRarity.COMMON, Ability.DEX,
		[1, 1, 0] as Array[int])


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
