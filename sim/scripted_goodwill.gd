extends RefCounted
## The two ways goodwill is earned, run side by side and measured against
## section 6's ownership rule.
##
## Section 6 gives two, and says one of them is meant to be much harder than the
## other: "completing quests raises it (amount judged by an LLM from the quest's
## nature). Pure talk can raise it but is deliberately hard -- only truly novel
## diplomacy is even considered, so the game can't be cheesed by chatting up
## everyone." This run is what says whether that came out true, in numbers,
## rather than asserting it.
##
## ## The two arms
##
## One character, Wren, and three neighbours who each want one thing. The same
## seed, the same world, the same four characters standing in the same places.
## The only difference is what Wren does with its turns:
##
##   * **talk** -- Wren walks to each of the three in turn and speaks to them,
##     `LINES_EACH` times each. That is `LINES_EACH * 3` lines of speech, which is
##     "chatting up everyone", done as thoroughly as the run allows.
##   * **deeds** -- Wren walks to each of the three in turn and hands over the
##     thing that character was actually after, taking nothing back. Three
##     things given, and not one word spoken.
##
## The deeds arm is deliberately the *smaller* run: three gifts against nine
## conversations. If talking still moves less ground under those odds, it is not
## because it was given less to work with.
##
## ## What a deed is here, and why no quest is being handed out
##
## Nothing tells Wren what anybody wants and nothing rewards Wren for it. Each
## neighbour holds a goal of its own -- `Goal.HOLD`, be carrying such a thing --
## put on its sheet by this file, which is scenario setup in the same sense the
## starting inventories are. Wren's list of turns is a person's choices written
## down. What makes a gift a *deed* is read back afterwards, off the engine's own
## record of the trade it honoured, by `Deed`: the goal closed while that record
## was the only thing that could have closed it. There is no quest object, no
## quest log, no giver and no reward, and the word does not appear in the
## machinery at all.
##
## ## The third arm, which has no model in it
##
## A comparison of one draw against another is one draw. So the run also plays
## the talk arm at a roll seed where *every* attempt succeeds, answering each
## with the largest share the engine will accept -- `Goodwill.MOST` -- from a
## written-down reply rather than from a recording. That is the ceiling of
## chatting up everyone: the best a talker could do if it won every roll and were
## judged as persuasive as anything can be. It is measured through exactly the
## machinery the other two arms use, and the only thing invented in it is the
## reply.
##
## ## What the dice do, measured rather than claimed
##
## The gate is `AbilityCheck.class_for_talk`, and how hard it is is a fact about
## that formula and these four sheets, not about one seed. So the run sweeps
## every roll seed from 1 to `SEEDS_SWEPT` with no model call in it at all -- a
## failed persuasion costs none -- and prints how many of the three attempts land
## at each, as a distribution. `ROLL_SEED` is then not chosen by taste: it is the
## lowest seed at which exactly one of the three lands, so that the run shows a
## success, two failures, and the repeat of both costing nothing.
class_name ScriptedGoodwill

## The world this is played on, which is the one every other run is played on.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE
const LOOP_SEED := ScriptedLoop.LOOP_SEED

## How long the run is: long enough for three walks, everything either arm does
## at the end of each of them, and every answer to land.
const TICKS := 170

## The two arms. The ceilings below are these two again, answered differently.
const TALK := "talk"
const DEEDS := "deeds"
const ARMS := [TALK, DEEDS]

## How many times Wren speaks to each neighbour in the talk arm.
const LINES_EACH := 3

## How many roll seeds the sweep covers, and how many attempts there are to land.
const SEEDS_SWEPT := 200
const ATTEMPTS := 3

## What the ceiling arms answer every question with: the most a reply could ask
## for. Written down here rather than recorded, because it is a bound and not a
## model's opinion -- see the note above.
const CEILING_REPLY := "goodwill=1"

## The three ceilings measured, and what each is for.
##
## The third one is why there are three: `talk x3` and `deeds` are not the same
## number of *happenings*, and familiarity moves once per happening whatever the
## happening was. `talk x1` holds that equal, so that what is left between it and
## `deeds` is what a persuasion earns against what a deed earns and nothing else.
const CEILINGS := [
	{
		"called": "talk x%d" % LINES_EACH, "arm": TALK, "lines": LINES_EACH,
		"says": "every line landing, at the largest share allowed",
	},
	{
		"called": "talk x1", "arm": TALK, "lines": 1,
		"says": "one line each, landing, at the largest share allowed -- the same"
			+ " number of happenings as the deeds arm",
	},
	{
		"called": "deeds max", "arm": DEEDS, "lines": 0,
		"says": "the same three gifts, at the largest share allowed",
	},
]

## Who does the doing, and what it is like. A talker: charm well above the
## wisdom of anybody here, which is the best case for the talk arm.
const WREN := "Wren"
const WREN_LEVEL := 2
const WREN_SCORES := {
	Ability.STR: 4, Ability.CON: 5, Ability.CHA: 13,
	Ability.DEX: 6, Ability.WIS: 5, Ability.INT: 7,
}

## The three neighbours: what they are called, where they stand relative to the
## meeting place, what they are each after, how strong they are and what they
## know. Ordinary people, and none of them wise or grand enough to be beyond
## talking to.
const NEIGHBOURS := [
	{
		"name": "Bram", "at": Vector2(7.0, 0.0), "level": 3, "wants": "wool cap",
		"scores": {
			Ability.STR: 9, Ability.CON: 8, Ability.CHA: 4,
			Ability.DEX: 5, Ability.WIS: 9, Ability.INT: 3,
		},
	},
	{
		"name": "Sable", "at": Vector2(5.0, 5.0), "level": 2, "wants": "linen hood",
		"scores": {
			Ability.STR: 5, Ability.CON: 6, Ability.CHA: 6,
			Ability.DEX: 8, Ability.WIS: 10, Ability.INT: 6,
		},
	},
	{
		"name": "Odo", "at": Vector2(-4.0, -7.0), "level": 2, "wants": "horn comb",
		"scores": {
			Ability.STR: 6, Ability.CON: 7, Ability.CHA: 5,
			Ability.DEX: 4, Ability.WIS: 8, Ability.INT: 5,
		},
	},
]

## What Wren says, one line per visit. Nothing in the words is read by anything:
## the context of a check at a person is the person, so the second and third
## lines settle out of memory whatever they say. They differ so that a reader can
## see that they do.
const LINES := [
	"you have the look of someone who has been kind to strangers",
	"there is nobody on this road I would rather have met",
	"say the word and I will speak well of you wherever I go",
]

## How long anybody with something to watch for waits before looking up again,
## and how long somebody with nothing left to do waits.
const WATCH := 4
const REST := 30

## The ground sampled for the ownership comparison: a square centred on the
## meeting place, this far out each way, sampled this far apart. 31 x 31 = 961
## points over 300 x 300 world units.
##
## Wider than `OwnershipField.RADIUS`, on purpose: ground further from everybody
## than that hears nobody at all and is neutral whatever anyone thinks, so a grid
## inside the radius would report every arm as holding all of it and would
## measure nothing. This one has the edge of the territory inside it.
const GRID_REACH := 150.0
const GRID_STEP := 10.0

## What seeds the dice. See the note at the head of this file: it is the lowest
## seed at which exactly one of the three attempts lands, which `roll_seed_for()`
## works out and `tests/test_goodwill.gd` checks this against.
const ROLL_SEED := 1


# --- The world -------------------------------------------------------------


## Set the run out: Wren carrying the three things, and three neighbours who each
## want one of them.
##
## Identical in both arms, down to the goals, so that the only difference between
## the two transcripts is what Wren spends its turns on.
static func stage(seed_value: int = SEED) -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(seed_value))
	var wren := scene.add_actor(Combatant.commander_at(
		WHERE.x, WHERE.y, 0.0, 0.0, WREN_LEVEL, AssetTags.ROGUE))
	var sheet := Character.make(WREN, WREN_LEVEL)
	sheet.record_scores(WREN_SCORES)
	(wren.piece as Commander).adopt(sheet)
	wren.settle(scene.terrain)

	for row in NEIGHBOURS:
		var at: Vector2 = row["at"]
		var one := scene.add_actor(Combatant.commander_at(
			WHERE.x + at.x, WHERE.y + at.y, 0.0, 0.0, int(row["level"]),
			AssetTags.KNIGHT))
		var theirs := Character.make(String(row["name"]), int(row["level"]))
		theirs.record_scores(row["scores"])
		(one.piece as Commander).adopt(theirs)
		one.settle(scene.terrain)
		# Scenario setup, and the only place in this run a goal is written down.
		# Nobody is told about it, nothing rewards it, and what a character does
		# about it is that character's own business -- see `Goal`.
		theirs.goals.add(Goal.of(
			Goal.HOLD, {"item": String(row["wants"])}, "", Goal.SHORT))
		sheet.inventory.carry(_wearable(String(row["wants"])))
	return scene


## What Wren does with its turns, in each arm.
##
## A written-down plan read by `DecisionSource.plan` against the number of
## actions the world says have been carried out -- the same decision function a
## person's choices are replayed through. No model chooses anything in this run
## but the amount a deed or a persuasion was worth.
static func choices(
	scene: ActionScene, arm: String, lines_each: int = LINES_EACH
) -> Array:
	var written := []
	for at in NEIGHBOURS.size():
		var one := _named(scene, String(NEIGHBOURS[at]["name"]))
		written.append(Action.go_to(one.id))
		if arm == DEEDS:
			written.append(Action.trade_propose(
				one.id, PackedStringArray([String(NEIGHBOURS[at]["wants"])])))
			written.append(Action.wait(WATCH * 2))
			continue
		for line in maxi(0, lines_each):
			written.append(Action.say(String(LINES[line % LINES.size()]), one.id))
	written.append(Action.wait(REST))
	return written


## What a neighbour does: take whatever is held out, and otherwise stand about.
##
## It reads the world it is handed -- the offers on the table -- and nothing
## else. It never speaks, so nothing a neighbour does raises a check of its own
## and the talk arm's checks are all Wren's.
static func _standing_by(scene: ActionScene, actor: Combatant) -> Action:
	for offer in scene.offers:
		if int(offer["to"]) == actor.id:
			return Action.trade_accept(int(offer["from"]))
	return Action.wait(WATCH)


# --- Living one arm --------------------------------------------------------


## Play one arm and return everything a transcript or a test wants out of it.
static func played_with(
	channel: ModelChannel, arm: String, ticks: int = TICKS,
	seed_value: int = SEED, roll_seed: int = ROLL_SEED,
	lines_each: int = LINES_EACH
) -> Dictionary:
	var scene := stage(seed_value)
	var wren := _named(scene, WREN)
	_sheet(wren).decide = DecisionSource.plan(choices(scene, arm, lines_each))
	for row in NEIGHBOURS:
		_sheet(_named(scene, String(row["name"]))).decide = DecisionSource.scripted(
			ScriptedGoodwill._standing_by)
	var loop := ControlLoop.on(scene, LOOP_SEED)
	var desk := CheckDesk.with_channel(channel, roll_seed)
	var deeds := DeedDesk.with_channel(channel)
	for _step in maxi(0, ticks):
		loop.step()
		desk.step(scene)
		deeds.step(scene)
	return {
		"arm": arm, "scene": scene, "loop": loop, "desk": desk, "deeds": deeds,
		"wren": wren, "channel": channel, "roll_seed": roll_seed,
	}


## What one arm came to, as ownership: Wren's score on the ground the four are
## standing on, the best it reaches anywhere on the sampled grid, and how much of
## that grid it holds outright.
static func ownership_of(scene: ActionScene) -> Dictionary:
	var wren := _named(scene, WREN)
	var here := OwnershipField.at(scene.actors, scene.relationships, WHERE.x, WHERE.y)
	var best := 0.0
	var held := 0
	var points := 0
	for at in grid():
		var claim := OwnershipField.at(scene.actors, scene.relationships, at.x, at.y)
		points += 1
		best = maxf(best, claim.score_of(wren.id))
		if claim.owner_id == wren.id:
			held += 1
	return {
		"here": here.score_of(wren.id), "owner": here.owner_id,
		"best": best, "held": held, "points": points,
	}


## What the three neighbours came to think of Wren: the sentiment the ownership
## maths actually reads, one per neighbour, and the trust behind it.
static func opinions_of(scene: ActionScene) -> Array[Dictionary]:
	var wren := _named(scene, WREN)
	var found: Array[Dictionary] = []
	for row in NEIGHBOURS:
		var one := _named(scene, String(row["name"]))
		var edge := scene.relationships.between(one.id, wren.id)
		found.append({
			"name": String(row["name"]),
			"sentiment": scene.relationships.sentiment(one.id, wren.id),
			"trust": 0.0 if edge == null else edge.field(one.id, "trust"),
			"familiarity": 0.0 if edge == null else edge.field(one.id, "familiarity"),
		})
	return found


## The grid of ground sampled, in world units.
static func grid() -> Array[Vector2]:
	var found: Array[Vector2] = []
	var across := int(round(GRID_REACH * 2.0 / GRID_STEP)) + 1
	for row in across:
		for column in across:
			found.append(Vector2(
				WHERE.x - GRID_REACH + float(column) * GRID_STEP,
				WHERE.y - GRID_REACH + float(row) * GRID_STEP))
	return found


# --- What the dice do, over every seed -------------------------------------


## How many of the three attempts land at one roll seed, with no model call in
## it: a persuasion that fails costs none, and this never asks about one that
## passed.
##
## Every number in it is the engine's own -- `AbilityCheck.class_for_talk` for
## the class, `AbilityCheck.rolled` for the die, `AbilityCheck.beats` for the
## comparison -- so this measures the gate rather than a run.
static func lands_at(roll_seed: int, lines_each: int = LINES_EACH) -> int:
	var landed := 0
	for at in NEIGHBOURS.size():
		var listener := Character.make(String(NEIGHBOURS[at]["name"]),
			int(NEIGHBOURS[at]["level"]))
		listener.record_scores(NEIGHBOURS[at]["scores"])
		var difficulty := AbilityCheck.bounded(AbilityCheck.class_for_talk(listener))
		# Which check the first line to this neighbour is, and which id that
		# neighbour has. Both are read off the order `stage()` and `choices()`
		# put things in: Wren is added first and the neighbours in the order
		# below, and Wren says `LINES_EACH` lines to each before moving on -- so
		# only the first line of each visit is ever rolled for, and it is the
		# one this counts. `tests/test_goodwill.gd` checks this against what the
		# run actually rolled rather than trusting the arithmetic.
		var check_id := 1 + at * maxi(1, lines_each)
		var listener_id := at + 2
		var roll := AbilityCheck.rolled(
			roll_seed, check_id, "persuade:#%d" % listener_id)
		if AbilityCheck.beats(int(WREN_SCORES[AbilityCheck.TALK_ABILITY]), roll, difficulty):
			landed += 1
	return landed


## How often each number of the three lands, over every seed swept.
static func sweep() -> Dictionary:
	var found := {}
	for how_many in ATTEMPTS + 1:
		found[how_many] = 0
	for roll_seed in range(1, SEEDS_SWEPT + 1):
		var landed := lands_at(roll_seed)
		found[landed] = int(found[landed]) + 1
	return found


## The lowest roll seed at which exactly `how_many` of the three land, or -1.
## `ROLL_SEED` is this for one, and nothing about it was chosen by taste.
##
## It takes the number of lines because how many are said before moving on
## decides which check number each first line is, and the die is hashed from the
## check's number: a run that says one line each rolls different dice from one
## that says three, at the same seed.
static func roll_seed_for(how_many: int, lines_each: int = LINES_EACH) -> int:
	for roll_seed in range(1, SEEDS_SWEPT + 1):
		if lands_at(roll_seed, lines_each) == how_many:
			return roll_seed
	return -1


# --- The run ---------------------------------------------------------------


## The whole comparison as a transcript.
static func play(
	channel: ModelChannel, ticks: int = TICKS, seed_value: int = SEED,
	roll_seed: int = ROLL_SEED
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append_array(_opening(channel, ticks, seed_value, roll_seed))

	var played := {}
	for arm in ARMS:
		played[arm] = played_with(channel, arm, ticks, seed_value, roll_seed)
		written.append("")
		written.append_array(_arm_lines(played[arm]))

	var ceilings := []
	for row in CEILINGS:
		# Each ceiling arm gets the lowest seed at which *its* rolls all land,
		# because the die is hashed from the check's number and a run that says
		# one line each does not raise the same numbered checks as one that says
		# three. The deeds arm rolls nothing, so any seed will do and it takes
		# the shipped one.
		var at_seed := roll_seed if int(row["lines"]) <= 0 \
			else roll_seed_for(ATTEMPTS, int(row["lines"]))
		if at_seed <= 0:
			continue
		var at_most := played_with(
			_ceiling_channel(), String(row["arm"]), ticks, seed_value,
			at_seed, int(row["lines"]))
		at_most["called"] = String(row["called"])
		at_most["says"] = String(row["says"])
		at_most["at_seed"] = at_seed
		ceilings.append(at_most)
	if not ceilings.is_empty():
		written.append("")
		written.append_array(_ceiling_lines(ceilings))

	written.append("")
	written.append_array(_gate_lines(roll_seed))
	written.append("")
	written.append_array(_side_by_side(played, ceilings))
	written.append("")
	written.append_array(_questions_lines(channel))
	return written


static func _ceiling_channel() -> ModelChannel:
	var rows := []
	for _at in ATTEMPTS:
		rows.append({"prompt": "", "reply": CEILING_REPLY, "ms": 0})
	return ModelChannel.replaying(
		{"rows": rows, "from": "written down in sim/scripted_goodwill.gd", "model": ""},
		"the ceiling arm answers every question with the most a reply could ask"
		+ " for, so that what talking could ever be worth is measured and not"
		+ " guessed at")


# --- The head --------------------------------------------------------------


static func _opening(
	channel: ModelChannel, ticks: int, seed_value: int, roll_seed: int
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("goodwill run seed=%d roll_seed=%d ticks=%d where=(%.1f, %.1f)"
		% [seed_value, roll_seed, ticks, WHERE.x, WHERE.y])
	written.append("  hooks      %s for a thing, %s for a person" % [
		AbilityCheck.HOOK, AbilityCheck.TALK_HOOK,
	])
	written.append("  channel    %s -- %s" % [channel.kind, channel.why])
	written.append("  recording  %s" % channel.recorded)
	written.append("  the class  dc = %d + wis(listener) + max(status, level)(listener),"
		% AbilityCheck.TALK_FLOOR
		+ " bounded to %d..%d, against %s + d%d" % [
			AbilityCheck.DC_LOWEST, AbilityCheck.DC_HIGHEST,
			AbilityCheck.TALK_ABILITY, AbilityCheck.DIE,
		])
	written.append("  the amount a model judges it, in %.1f..%.1f, which the engine"
		% [Goodwill.SAID_LEAST, Goodwill.SAID_MOST]
		+ " bounds to at most %s" % Goodwill.said_as(Goodwill.MOST))
	written.append("  who        %s, %s, level %d, carrying all three things" % [
		WREN, _scores_line(WREN_SCORES), WREN_LEVEL,
	])
	written.append("  and        %d neighbours, each wanting one of them:"
		% NEIGHBOURS.size())
	for row in NEIGHBOURS:
		var listener := Character.make(String(row["name"]), int(row["level"]))
		listener.record_scores(row["scores"])
		written.append("    %-6s level %d, %s -- wants %s; dc to win round %d" % [
			row["name"], int(row["level"]), _scores_line(row["scores"]),
			row["wants"],
			AbilityCheck.bounded(AbilityCheck.class_for_talk(listener)),
		])
	written.append("  the arms   %s: %d lines to each of them; %s: the thing each"
		% [TALK, LINES_EACH, DEEDS] + " one wanted, handed over, and no words")
	return written


# --- One arm ---------------------------------------------------------------


static func _arm_lines(played: Dictionary) -> PackedStringArray:
	var scene: ActionScene = played["scene"]
	var desk: CheckDesk = played["desk"]
	var deeds: DeedDesk = played["deeds"]
	var written := PackedStringArray()
	written.append("--- the %s arm ---" % played["arm"])
	written.append("")
	written.append("what %s did" % WREN)
	for line in (played["loop"] as ControlLoop).journal:
		if line.contains(WREN):
			written.append("  %s" % line)
	written.append("")
	written.append("what the world made of it")
	for line in desk.journal:
		written.append("  %s" % line)
	for line in deeds.journal:
		written.append("  %s" % line)
	if desk.journal.is_empty() and deeds.journal.is_empty():
		written.append("  nothing was raised and nothing closed")
	written.append("")
	written.append_array(_cost_lines(desk, deeds))
	written.append("")
	written.append("the edges afterwards")
	for line in scene.relationships.lines():
		written.append("  %s" % line)
	written.append("")
	written.append_array(_ownership_lines(scene))
	written.append("")
	written.append("after %d ticks" % scene.tick)
	for line in scene.lines():
		written.append("  %s" % line)
	written.append("  fingerprint %s" % scene.fingerprint())
	return written


static func _cost_lines(desk: CheckDesk, deeds: DeedDesk) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what it cost")
	written.append("  checks     %d raised, %d rolled, %d settled out of memory"
		% [desk.seen.size(), desk.rolls, desk.reused])
	written.append("  deeds      %d goals closed and looked at, %d of them with"
		% [deeds.seen.size(), deeds.deeds().size()] + " somebody else behind them")
	written.append("  calls      %d put to a model (%d for persuasions, %d for deeds)"
		% [desk.calls + deeds.calls, desk.calls, deeds.calls])
	written.append("  earned     %s of trust over %d edges, %s over %d more" % [
		Goodwill.said_as(desk.earned), desk.favoured,
		Goodwill.said_as(deeds.earned), deeds.favoured,
	])
	return written


static func _ownership_lines(scene: ActionScene) -> PackedStringArray:
	var owned := ownership_of(scene)
	var written := PackedStringArray()
	written.append("what %s owns, by section 6's rule" % WREN)
	written.append("  at the meeting place  %.4f, and the ground is %s" % [
		float(owned["here"]),
		"neutral" if int(owned["owner"]) == OwnershipField.NOBODY
			else "held by #%d" % int(owned["owner"]),
	])
	written.append("  best anywhere on the grid  %.4f" % float(owned["best"]))
	written.append("  ground held  %d of %d sampled points (%.1f%%)" % [
		int(owned["held"]), int(owned["points"]),
		100.0 * float(owned["held"]) / maxf(1.0, float(owned["points"])),
	])
	written.append("  the threshold it is against is %.4f" % OwnershipField.THRESHOLD)
	written.append("  what each of them thinks of %s, which is what that is made of:"
		% WREN)
	for row in opinions_of(scene):
		written.append("    %-6s sentiment %.4f = familiarity %.3f x trust %.3f" % [
			row["name"], float(row["sentiment"]), float(row["familiarity"]),
			float(row["trust"]),
		])
	return written


static func _ceiling_lines(ceilings: Array) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("--- the ceilings: every roll landing and every answer the"
		+ " largest one allowed ---")
	written.append("")
	written.append("  every reply is \"%s\", written down rather than recorded"
		% CEILING_REPLY)
	for at_most in ceilings:
		written.append("")
		written.append("  %s, roll seed %d -- %s" % [
			at_most["called"], int(at_most["at_seed"]), at_most["says"],
		])
		written.append_array(_ownership_lines(at_most["scene"]))
	return written


# --- What the dice do ------------------------------------------------------


static func _gate_lines(roll_seed: int) -> PackedStringArray:
	var swept := sweep()
	var written := PackedStringArray()
	written.append("--- how hard the gate is, over every roll seed from 1 to %d ---"
		% SEEDS_SWEPT)
	written.append("")
	written.append("  no model call is made anywhere in this table: a persuasion"
		+ " that fails costs none, and this asks about no persuasion that passed.")
	written.append("")
	written.append("  %-14s %-8s %s" % ["attempts landed", "seeds", "share"])
	for how_many in ATTEMPTS + 1:
		written.append("  %-14d %-8d %.1f%%" % [
			how_many, int(swept[how_many]),
			100.0 * float(swept[how_many]) / float(SEEDS_SWEPT),
		])
	var expected := 0.0
	for how_many in ATTEMPTS + 1:
		expected += float(how_many) * float(swept[how_many]) / float(SEEDS_SWEPT)
	written.append("")
	written.append("  %.2f of %d attempts land on average, which is %.1f%% of them"
		% [expected, ATTEMPTS, 100.0 * expected / float(ATTEMPTS)])
	written.append("  the seed this run uses is %d, the lowest at which exactly one"
		% roll_seed + " lands (%d)" % roll_seed_for(1))
	return written


# --- The two numbers side by side -----------------------------------------


static func _side_by_side(
	played: Dictionary, ceilings: Array
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("--- the two ways, side by side ---")
	written.append("")
	written.append("  %-10s %-8s %-8s %-10s %-10s %-8s %-10s %s" % [
		"arm", "actions", "calls", "at centre", "best", "held",
		"best trust", "owner of the centre",
	])
	for arm in ARMS:
		written.append("  %s" % _row_for(played[arm], String(arm)))
	for at_most in ceilings:
		written.append("  %s" % _row_for(at_most, String(at_most["called"])))
	written.append("")
	var talking := ownership_of((played[TALK] as Dictionary)["scene"])
	var doing := ownership_of((played[DEEDS] as Dictionary)["scene"])
	written.append("  talking moved the ground under the four of them to %.4f;"
		% float(talking["here"])
		+ " doing something moved it to %.4f." % float(doing["here"]))
	if float(talking["here"]) > 0.0:
		written.append("  that is %.1f times as much for the arm that did something,"
			% (float(doing["here"]) / float(talking["here"]))
			+ " off a third as many turns.")
	written.append("")
	written.append("  where the difference is, and where it is not:")
	written.append("    talking with nothing earned is worth exactly nothing. A"
		+ " neighbour talked at %d times and not won round has familiarity but no"
			% LINES_EACH
		+ " trust, and familiarity multiplies, so its sentiment is 0.0000 --"
		+ " which the tables above show for every attempt that missed.")
	written.append("    what one thing earns is trust, and that is where a deed"
		+ " and a persuasion can be put beside each other: the best trust either"
		+ " arm reached is in the table above, on a single edge, out of the same"
		+ " judged share bounded the same way.")
	if ceilings.size() >= 3:
		var talk_most := ownership_of((ceilings[0] as Dictionary)["scene"])
		var once_most := ownership_of((ceilings[1] as Dictionary)["scene"])
		var deed_most := ownership_of((ceilings[2] as Dictionary)["scene"])
		written.append("    at their ceilings -- every one of the %d rolls landing,"
			% ATTEMPTS
			+ " which happens on %.1f%% of roll seeds, and every answer the largest"
				% (100.0 * float(sweep()[ATTEMPTS]) / float(SEEDS_SWEPT))
			+ " the engine allows -- %d lines each reaches %.4f, one line each"
				% [LINES_EACH, float(talk_most["here"])]
			+ " reaches %.4f, and %d gifts reach %.4f." % [
				float(once_most["here"]), NEIGHBOURS.size(), float(deed_most["here"]),
			])
		written.append("    so at the same number of happenings a gift beats the"
			+ " best persuasion there is, and what buys the %d-line arm its lead is"
				% LINES_EACH
			+ " familiarity rather than goodwill: %d conversations put it at %.3f"
				% [LINES_EACH * NEIGHBOURS.size(),
					1.0 - pow(1.0 - RelationshipGraph.MET, LINES_EACH)]
			+ " against a single dealing's %.3f, off three times the turns."
				% RelationshipGraph.MET)
	return written


static func _row_for(played: Dictionary, called: String) -> String:
	var scene: ActionScene = played["scene"]
	var desk: CheckDesk = played["desk"]
	var deeds: DeedDesk = played["deeds"]
	var owned := ownership_of(scene)
	var trust := 0.0
	for opinion in opinions_of(scene):
		trust = maxf(trust, float(opinion["trust"]))
	return "%-10s %-8d %-8d %-10.4f %-10.4f %-8d %-10.3f %s" % [
		called, scene.actions_of(_named(scene, WREN).id), desk.calls + deeds.calls,
		float(owned["here"]), float(owned["best"]), int(owned["held"]), trust,
		"nobody" if int(owned["owner"]) == OwnershipField.NOBODY
			else "#%d" % int(owned["owner"]),
	]


static func _questions_lines(channel: ModelChannel) -> PackedStringArray:
	var written := PackedStringArray()
	var asked := channel.questions()
	if asked.is_empty():
		written.append("the run asked nothing")
		return written
	written.append("--- the questions in full ---")
	for at in mini(2, asked.size()):
		written.append("")
		written.append("  --- question %d, %d characters, digest %s ---" % [
			at + 1, String(asked[at]["prompt"]).length(), asked[at]["digest"],
		])
		for line in String(asked[at]["prompt"]).split("\n"):
			written.append("  %s" % line)
	return written


# --- The furniture ---------------------------------------------------------


static func _scores_line(scores: Dictionary) -> String:
	var parts := PackedStringArray()
	for ability in Ability.ALL:
		parts.append("%s %d" % [ability, int(scores.get(ability, 0))])
	return ", ".join(parts)


static func _wearable(called: String) -> Item:
	return Item.armour(
		called, Item.SLOT_HELMET, 1, ItemRarity.COMMON, Ability.DEX,
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
