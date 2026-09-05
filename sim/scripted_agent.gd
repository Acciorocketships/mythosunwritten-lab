extends RefCounted
## Every non-player character in the run decides through a language model, all of
## them at once.
##
##     ./run_agent.sh                 # replays the recorded exchange
##     ./run_agent.sh --live          # puts the same questions to a real model
##
## This is the market and the quarrel of `ScriptedScenario` -- the same seed, the
## same ground, the same five characters standing in the same places -- with a
## sixth added, and with five of the six driven by a model rather than one. The
## loop that services all six is `ControlLoop`, the thing that resolves what any
## of them chooses is `ActionEngine`, and neither is told which of the six is
## which.
##
## ## The six, and the one column they differ in
##
##   * **Wren** -- a person's choices, written down in advance (`plan`). The one
##     human-driven character, kept so that the run has something to compare
##     against: it is handed the same action set through the same call surface,
##     observes the world the same way, and is refused in the same words.
##   * **Rook, Bram, Sable, Odo, Pell** -- a language model each (`model`), one
##     `ModelMind` per character, all five asking through one `ModelChannel` and
##     none of them waiting on another.
##
## The cast table prints that column, and it is the only place in the run where
## the distinction exists. There is no field on `Character` naming it, nothing in
## the observation reporting it, and nothing in the engine branching on it.
##
## ## Nothing about the run is written down any more except where people stand
##
## The earlier version of this file had four of the five on rules -- Rook minded
## its stall, Bram and Sable quarrelled from tick 55, Odo walked away -- and one
## on a model. Those rules are gone from this run: `ScriptedScenario.drive` still
## hands them out, and this file then replaces four of the five with minds, so
## the scenario that `./run_scenario.sh` plays is untouched and reads the same.
## What is left written down here is the staging -- who is in it, where they
## stand, what they carry -- which is the scene and not the story. Whether the
## trade happens, whether the quarrel happens, whether anybody goes anywhere is
## the models' business, and the transcript is what they did.
##
## ## What is being shown, and how to read it for each
##
##   * *every non-player character decides through a model* -- the cast table
##     names the driver of each, and the turn table has a row for every question
##     any of the five was put: what it observed, what the model said, what that
##     read back as, and what the engine answered. A refusal is in the engine's
##     own words, and it is the same sentence the human-driven character gets for
##     the same choice.
##   * *several outstanding answers do not serialise* -- the waiting table gives,
##     for every one of those questions, how many ticks that character stood with
##     nothing committed, how many *other* answers were outstanding across the
##     same span, and how many ticks each of the other five was serviced for in
##     it. A run that serialised would show a character's span growing with the
##     number pending; a run that blocked would show zeroes in the other columns.
##   * *what the run cost* -- the volume table gives model calls per character and
##     in total, the calls-per-tick that comes to, and what an hour of play would
##     be at the same rate. That number is the whole reason the table is here:
##     section 12's distance-based back-off and speculative next action are
##     deferred, and this is the measurement that says whether they are needed.
##   * *the continue-biased loop doing its job* -- the bias table gives, per
##     character, how many times a driver asked the mind what to do next against
##     how many of those asks put a question to the model. The gap is section
##     2.2's bias toward continuing, priced.
##   * *no credential is needed* -- the head of the run says which channel
##     answered and why. The shipped run replays a written-down exchange, handed
##     in by whoever built the channel, so it needs no key, no network and no
##     model, and two processes print the same bytes.
##
## ## Where Pell stands, and why it is in the market's band
##
## Beside the stall, a few units from Wren and Rook, so that there is something
## in its observation worth choosing about: two characters, a pile with a lantern
## on it, and open ground. It shares the market's `Combatant.band` for the reason
## Wren and Rook share it -- the engagement rule pits commanders of *different*
## bands against each other, and a band is the only way this scene has of saying
## "these three are not enemies". That is not an affordance a model gets and a
## person does not; it is the same sentence the scenario already writes for the
## two who trade.
##
## ## The three things Pell is after, which are scenario setup and not game content
##
## Pell starts the run after three things, put on its own sheet by `set_out()`
## below and by nothing in the simulation. They are this scenario's setup in
## exactly the sense the five other characters' positions, money and items are
## setup: a scene has to start somewhere, and a character standing in a market
## after nothing at all was the one thing an earlier version of this run could
## not show.
##
## What they are not is a quest. Nothing gives them, nothing rewards them, no
## step towards any of them is written down, and no other character knows they
## exist. Two of them name something the world holds -- being beside another
## character, carrying a named thing -- and the world answers those out of its
## own state on every question. The third is in Pell's own words and names
## nothing the world holds, so Pell is the only thing that can close it, which is
## the difference the goals table at the end of the run prints.
##
## Beyond setting them, nothing in this file tells any model anything. There is
## no errand, no script and no line here that steers what any of the five
## chooses -- what happens in the transcript is what the models said when they
## were shown the world.
class_name ScriptedAgent

## The run this is played on: the shipped scenario's seed, ground and cast.
const SEED := ScriptedScenario.SEED
const WHERE := ScriptedScenario.WHERE
const LOOP_SEED := ScriptedScenario.LOOP_SEED

## How many ticks it lives for. The scenario's own length, unchanged, so that
## what this run does with the same ground over the same span can be read against
## what `./run_scenario.sh` does with it.
const TICKS := ScriptedScenario.TICKS

## How many milliseconds of real time a tick is given when a live model is
## answering. `ControlLoop` says twenty ticks is a second at the rate the world
## is stepped, so this is that rate written as a number.
##
## It is a number here and a pause nowhere here: nothing under `sim/` reads a
## clock, so the pausing itself is done by whoever asked for a live run --
## `bin/agent_main.gd` -- and handed in as the `between_ticks` callable. It is
## used by that one command and by nothing that ships a transcript, because a run
## nobody is watching has no reason to go at the speed of a run somebody is.
const TICK_MS := 50

## The one character this step adds. One name, one side, one level, one place.
const PELL := "Pell"
const PELL_AT := Vector2(4.0, 2.0)
const PELL_LEVEL := 2
const PELL_MONEY := 9

## Who decides through a model, in the order they are serviced in.
##
## Every character in the scene except the one human-driven character, which is
## the whole claim of this run written as a list. It is a list of names and not a
## rule about names: the five are looked up in the scene by `ModelCast.over`, and
## a name nothing answers to is skipped rather than invented.
const MODEL_CAST := [
	ScriptedScenario.ROOK, ScriptedScenario.BRAM, ScriptedScenario.SABLE,
	ScriptedScenario.ODO, PELL,
]

## The one character in the run a person drives, through a list of choices
## written down in advance. Kept so that the run has the comparison in it: the
## same action set, the same observation, the same refusals.
const PERSON := ScriptedScenario.WREN

## What Pell is after when the run opens: scenario setup, in this file, and
## nothing the simulation declares. See the note at the head of the file.
##
## Two of the three name something the world holds and are answered out of it;
## the third is in Pell's own words and names nothing the world holds, so Pell
## closes it or nobody does. Ordered by how pressing they are, most first.
const AFTER_LANTERN := ScriptedScenario.LANTERN
const AFTER_STANDING := "be thought well of in this market"

## What the character a person drives is after: to be carrying at least one coin.
##
## It is one coin because that character opens the run carrying thirty, so the
## world already answers it true before anything has happened -- which makes it
## the shortest statement of the thing this run is here to show. A goal the world
## answers is closed by the world at that character's first servicing, whoever is
## driving it; before the two stores were maintained on a shared path this one
## stayed open for the whole run and closed only when somebody asked by hand.
const AFTER_A_COIN := 1


# --- The world the run is played in ---------------------------------------


## The scenario's scene with one more character standing in it.
##
## `ScriptedScenario.stage_for` is called rather than copied, so the five and the
## stall are exactly what `./run_scenario.sh` plays and no coordinate of theirs is
## restated here. Pell is added afterwards, which gives it the last id.
static func stage(seed_value: int = SEED) -> ActionScene:
	var scene := ScriptedScenario.stage_for(seed_value)
	var pell := scene.add_actor(Combatant.commander_at(
		WHERE.x + PELL_AT.x, WHERE.y + PELL_AT.y,
		0.0, 0.0, PELL_LEVEL, AssetTags.HOODED_ROGUE))
	pell.band = _market_band(scene)
	var sheet := Character.make(PELL, PELL_LEVEL)
	sheet.record_scores(ScriptedScenario.ROLL)
	(pell.piece as Commander).adopt(sheet)
	ActionScene.inventory_of(pell).gain(PELL_MONEY)
	pell.settle(scene.terrain)
	return scene


## Put the six decision functions on the six sheets, and hand back the five model
## minds so the run can read what each was asked and what it said.
##
## `ScriptedScenario.drive` is called first and unchanged, so the scenario that
## `./run_scenario.sh` plays is what it always was and no coordinate or rule of
## it is restated here. Then `ModelCast.over` replaces four of those five
## decision functions with model minds and gives the sixth character one, leaving
## exactly one driven by a person's written-down choices.
##
## Every one of the five is `DecisionSource.model`, which is a `Callable` of the
## same two arguments as the plan it replaced and is put on the sheet in the same
## way. Nothing downstream is told which is which because there is nothing
## downstream to tell.
static func drive(
	scene: ActionScene, channel: ModelChannel, trail: ObservationTrail
) -> ModelCast:
	ScriptedScenario.drive(scene)
	var cast := ModelCast.over(scene, channel, trail, MODEL_CAST)
	set_out(scene)
	return cast


## Put the three goals Pell starts after onto its own sheet.
##
## It is separate from `stage()` on purpose. Staging is the world -- the ground,
## the six characters, the stall -- and everything built on this scene shares it;
## what one character happens to be after is setup for *this* run, and the
## controlled comparison in `sim/scripted_goal.gd` stages the same world and sets
## out its own. A goal put in `stage()` would appear in every arm of that
## comparison and there would be no arm that was after nothing.
static func set_out(scene: ActionScene) -> GoalSet:
	var pell := _named(scene, PELL)
	var sheet := _sheet(pell)
	if sheet == null:
		return null
	var rook := _named(scene, ScriptedScenario.ROOK)
	sheet.goals.add(Goal.of(
		Goal.BE_AT, {"target": ActionCatalog.NOBODY if rook == null else rook.id},
		"", Goal.SHORT, 0))
	sheet.goals.add(Goal.of(
		Goal.HOLD, {"item": AFTER_LANTERN}, "", Goal.SHORT, 1))
	sheet.goals.add(Goal.unwritten(AFTER_STANDING, Goal.LONG, 2))
	var person := _sheet(_named(scene, PERSON))
	if person != null:
		person.goals.add(Goal.of(
			Goal.MONEY, {"amount": AFTER_A_COIN}, "", Goal.SHORT, 0))
	return sheet.goals


# --- Living the run -------------------------------------------------------


## Play the whole run and hand back the transcript.
##
## The channel is handed in rather than chosen here -- a shipped run's is the
## recorded exchange, and a live one's is a transport built by the entry point --
## so nothing in this file decides where an answer comes from or is able to.
##
## The run itself is `played_with` below: one tick at a time, exactly as the
## scenario is played, with the loop servicing all six and the fight taking its
## turn. Everything the model layer contributes happens inside `loop.step()`, on
## Pell's own decision function, and nothing here waits for anything.
static func play(
	channel: ModelChannel, ticks: int = TICKS, seed_value: int = SEED,
	between_ticks: Callable = Callable()
) -> PackedStringArray:
	var played := played_with(channel, ticks, seed_value, between_ticks)
	var scene: ActionScene = played["scene"]
	var loop: ControlLoop = played["loop"]
	var cast: ModelCast = played["cast"]
	var mind: ModelMind = played["mind"]

	var written := PackedStringArray()
	written.append_array(_opening(played["roster"], played["opened"], channel, ticks, seed_value))
	written.append_array(played["lines"])
	written.append("")
	written.append_array(turn_lines(cast, loop))
	written.append("")
	written.append_array(waiting_lines(cast, played["serviced"], played["pending"]))
	written.append("")
	written.append_array(volume_lines(cast, scene, loop))
	written.append("")
	written.append_array(bias_lines(cast, loop))
	written.append("")
	written.append_array(measured_lines(cast))
	written.append("")
	written.append_array(memory_summary_lines(cast, scene))
	written.append("")
	written.append_array(relationship_lines(scene))
	written.append("")
	written.append_array(memory_lines(mind, scene, channel))
	written.append("")
	written.append_array(goal_lines(scene))
	written.append("")
	written.append("after %d ticks" % scene.tick)
	written.append_array(_indent(scene.lines()))
	written.append("  " + _counts_line(loop))
	written.append("  fingerprint %s" % scene.fingerprint())
	written.append("")
	written.append_array(first_question_lines(channel))
	return written


## Play the run out of a channel handed in, and hand back everything anybody
## reads off it: the scene, the loop, the mind, the transcript of the ticks
## themselves, and how many ticks each character was serviced for at the end of
## every tick.
##
## `between_ticks` is called at the end of every tick and is nothing by default,
## which is what every shipped run and every test passes: the world goes as fast
## as the machine can step it. The one caller that passes anything is the run with
## a live model in it, which passes a pause of `TICK_MS` so that the world runs at
## the rate it is stated to run at rather than racing past a call that has not
## come back yet. It is not a wait on the model -- the loop has already stepped
## everybody by the time it is called, and it is called whether or not anybody is
## waiting for anything.
static func played_with(
	channel: ModelChannel, ticks: int = TICKS, seed_value: int = SEED,
	between_ticks: Callable = Callable()
) -> Dictionary:
	var scene := stage(seed_value)
	var trail := ObservationTrail.new()
	trail.note(scene)
	var loop := ControlLoop.on(scene, LOOP_SEED, trail)
	var cast := drive(scene, channel, trail)
	var roster := cast_lines(scene)
	var opened := scene.lines()

	var written := PackedStringArray()
	var serviced: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	var said := 0
	for _step in maxi(0, ticks):
		loop.step()
		for at in range(said, loop.journal.size()):
			written.append(loop.journal[at])
		said = loop.journal.size()
		written.append_array(ScriptedScenario._fight_step(scene))
		trail.note(scene)
		serviced.append(_serviced(scene, loop))
		pending.append({"tick": scene.tick, "waiting": cast.waiting()})
		if between_ticks.is_valid():
			between_ticks.call()

	ScriptedScenario.release(scene)
	return {
		"scene": scene, "loop": loop, "cast": cast, "mind": cast.mind_of(PELL),
		"channel": channel, "serviced": serviced, "pending": pending,
		"lines": written, "roster": roster, "opened": opened,
	}


# --- The head of the transcript -------------------------------------------


static func _opening(
	cast: PackedStringArray, opened: PackedStringArray,
	channel: ModelChannel, ticks: int, seed_value: int
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("model cast run seed=%d ticks=%d where=(%.1f, %.1f)" % [
		seed_value, ticks, WHERE.x, WHERE.y,
	])
	written.append("  cast       %d of the %d characters decide through a model; %s is"
		% [MODEL_CAST.size(), MODEL_CAST.size() + 1, PERSON]
		+ " driven by a person's choices written down in advance")
	written.append("  channel    %s -- %s" % [channel.kind, channel.why])
	written.append("  recording  %s" % channel.recorded)
	written.append("  prompt     the twelve actions of the one list, the observation packet,")
	written.append("             and what this character remembers -- every lesson it has kept")
	written.append("             and the last few lines of its own log, with the three tools")
	written.append("             that look further back, keep a new lesson and close a goal;")
	written.append("             no rule about distance, reach, cost, damage or possibility;")
	written.append("             and what this character is after, as several structured goals")
	written.append("             off its own sheet -- wanted states of the world, in the order")
	written.append("             they press, with no step, no giver and no reward. Only %s"
		% PELL)
	written.append("             was set out after anything; the rest are told, in one line,")
	written.append("             that they are after nothing in particular.")
	written.append_array(_indent(cast))
	written.append_array(_indent(opened))
	written.append("")
	return written


## One line per character: who they are, what drives them, and what they are
## worth. Six rows of one shape, differing in one column.
static func cast_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet == null:
			continue
		written.append("%-6s #%d driven by %-8s %s" % [
			sheet.character_name, one.id,
			_driver_of(sheet.character_name), sheet.sheet_line(),
		])
	return written


# Which sort of decision function a character was given. Said here, in the file
# that gave them out, and nowhere else -- there is nothing anywhere in the
# simulation to tell it by.
static func _driver_of(who: String) -> String:
	if MODEL_CAST.has(who):
		return "a model"
	return "a person" if who == PERSON else "a rule"


# --- What the model was asked, and what came of it -------------------------


## The turn table: one row for every question any of the five was put -- who was
## asked, what it observed, what the model said, what that read as, and what the
## engine answered.
##
## Rows are in the order the answers arrived, so the table reads down the run and
## the interleaving of the five is visible in it. A turn is closed by the world
## resolving the action it chose, so the answer column is that resolution in the
## engine's own words -- including a refusal, where a model chose something the
## world would not allow. An action that was interrupted part-way through was
## chosen again by the same unchanged answer and eventually resolved, and the row
## says how many times that happened.
static func turn_lines(cast: ModelCast, loop: ControlLoop) -> PackedStringArray:
	var written := PackedStringArray()
	var rows := cast.turns()
	written.append("the model cast's turns -- %d questions across %d characters, %d chose an action" % [
		rows.size(), cast.order.size(), _chosen(cast),
	])
	written.append("  %-6s %-4s %5s %8s  %-16s  %-30s %-28s %s" % [
		"who", "turn", "asked", "answered", "observed", "the model said",
		"which read back as", "what the engine answered",
	])
	var answers := {}
	var at := {}
	for who in cast.order:
		answers[who] = _engine_answers(loop.journal, who)
		at[who] = 0
	for row in rows:
		var who := String(row["who"])
		var chose: Action = row["chose"]
		var chose_line := "-- nothing readable --" if chose == null else chose.line()
		var answered := "(nothing was chosen)"
		if String(row["tool"]) != "":
			chose_line = "%s about=%s" % [row["tool"], _clip(String(row["asked_for"]), 18)]
			answered = "(a tool, not an action: %s)" % (
				"%d thing%s came back" % [
					int(row["found"]), "" if int(row["found"]) == 1 else "s",
				] if String(row["tool"]) == ModelPrompt.RECALL else "one lesson kept")
			# An ask the world would not allow: its own sentence, in place of
			# what the tool would have come back with, because it did not run.
			if String(row["refused"]) != "":
				answered = "(the world refused it: %s)" % row["refused"]
		if chose != null:
			answered = "still running when the run ended"
			var mine: Array[Dictionary] = answers[who]
			var seen := int(at[who])
			if seen < mine.size():
				answered = String(mine[seen]["said"])
				if int(mine[seen]["interrupted"]) > 0:
					answered += "  (chosen again after %d interruption%s)" % [
						mine[seen]["interrupted"],
						"" if int(mine[seen]["interrupted"]) == 1 else "s",
					]
				at[who] = seen + 1
		written.append("  %-6s %-4d %5d %8d  %-16s  %-30s %-28s %s" % [
			who, int(row["turn"]), int(row["tick"]) - int(row["waited"]),
			int(row["tick"]), row["observed"], _clip(String(row["said"]), 30),
			_clip(chose_line, 28), answered,
		])
	for note in cast.waiting_notes():
		written.append("  still waiting: %s" % note)
	return written


## The waiting table: what everybody else did while each of the five stood there
## with nothing committed, and how many other answers were outstanding with it.
##
## The claim is not argued anywhere; it is this table. For each question, the span
## is the ticks between the question and the answer; `alongside` is how many other
## model characters were also waiting at some point inside that span; and the last
## columns are how many ticks the control loop serviced each of the other five for
## across exactly that span and how many actions they resolved in it.
##
## Two things would show here if the layer did not do what it claims. A run that
## *blocked* would show zeroes in the serviced columns. A run that *serialised*
## the answers would show the span growing with `alongside` -- a second question
## waiting on the first would take twice as long -- and it does not: every span is
## the stated one whatever else is outstanding.
static func waiting_lines(
	cast: ModelCast, serviced: Array[Dictionary], pending: Array[Dictionary]
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("nobody waits on anybody")
	written.append("  %-6s %-4s %5s %8s %6s %9s  %-46s %s" % [
		"who", "turn", "asked", "answered", "waited", "alongside",
		"ticks each of the others was serviced for", "actions",
	])
	written.append("        (a character that has fallen out of the world is serviced no"
		+ " further, and shows 0)")
	for row in cast.turns():
		var who := String(row["who"])
		var answered := int(row["tick"])
		var asked := answered - int(row["waited"])
		var ticks := PackedStringArray()
		var resolved := 0
		for other in _others_than(serviced, who):
			ticks.append("%s %d" % [other, _gap(serviced, other, "ticks", asked, answered)])
			resolved += _gap(serviced, other, "actions", asked, answered)
		written.append("  %-6s %-4d %5d %8d %6d %9d  %-46s %d" % [
			who, int(row["turn"]), asked, answered, int(row["waited"]),
			_alongside(pending, who, asked, answered), " ".join(ticks), resolved,
		])
	written.append_array(_pending_summary(pending, cast))
	return written


# How many other characters had a question outstanding at some point inside one
# character's wait. Read off the per-tick sample rather than reconstructed, so it
# is what was actually pending and not what should have been.
static func _alongside(
	pending: Array[Dictionary], who: String, from_tick: int, to_tick: int
) -> int:
	var found := {}
	for row in pending:
		var at := int(row["tick"])
		if at < from_tick or at > to_tick:
			continue
		for other in (row["waiting"] as PackedStringArray):
			if other != who:
				found[other] = true
	return found.size()


# The three numbers that say the answers did not queue: how often more than one
# was outstanding at once, the most that ever were, and whether any span was
# longer than the stated one.
static func _pending_summary(
	pending: Array[Dictionary], cast: ModelCast
) -> PackedStringArray:
	var written := PackedStringArray()
	var busy := 0
	var most := 0
	var histogram := {}
	for row in pending:
		var many := (row["waiting"] as PackedStringArray).size()
		histogram[many] = int(histogram.get(many, 0)) + 1
		most = maxi(most, many)
		if many > 1:
			busy += 1
	var spread := PackedStringArray()
	for many in range(most + 1):
		spread.append("%d:%d" % [many, int(histogram.get(many, 0))])
	var longest := 0
	var stated := 0
	var by_alongside := {}
	var rows := cast.turns()
	for row in rows:
		var waited := int(row["waited"])
		longest = maxi(longest, waited)
		if waited == ModelChannel.THINKS_FOR:
			stated += 1
		var others := _alongside(
			pending, String(row["who"]), int(row["tick"]) - waited, int(row["tick"]))
		by_alongside[others] = maxi(int(by_alongside.get(others, 0)), waited)
	var longest_by := PackedStringArray()
	for others in range(most + 1):
		if by_alongside.has(others):
			longest_by.append("%d:%d" % [others, int(by_alongside[others])])
	written.append("  ticks with more than one answer outstanding  %d of %d" % [
		busy, pending.size(),
	])
	written.append("  the most outstanding at once                 %d" % most)
	written.append("  ticks by how many were outstanding           %s" % " ".join(spread))
	written.append("  spans: %d of %d took the stated %d ticks, the longest took %d" % [
		stated, rows.size(), ModelChannel.THINKS_FOR, longest,
	])
	written.append("  the longest span, by how many other answers were outstanding across it")
	written.append("    %s" % " ".join(longest_by))
	written.append("    this is the line that says the answers do not queue: a channel that"
		+ " served them")
	written.append("    in turn would make a question put while %d others were outstanding"
		% most)
	written.append("    take about %d ticks, not %d. A span longer than the stated %d is a"
		% [(most + 1) * ModelChannel.THINKS_FOR, ModelChannel.THINKS_FOR,
			ModelChannel.THINKS_FOR])
	written.append("    character that was not serviced on the tick its answer was ready --"
		+ " a")
	written.append("    commander waiting for its turn on the board -- and not an answer"
		+ " waiting")
	written.append("    for another answer.")
	return written


## The volume table: what the run cost in model calls, and what an hour would.
##
## This is the number the milestone is measured by. Section 12 defers both a
## distance-based back-off and a speculative next action, and the only thing that
## can say whether either is ever needed is how many calls a run of this shape
## actually makes. So it is printed every run: per character, in total, as a rate
## per tick, and carried out to an hour of play at the rate `ControlLoop` states
## the world is stepped at.
##
## Nothing here is an estimate of a live call's latency or price. It is a count
## of questions put, which is the thing that does not change between a replayed
## run and a live one.
static func volume_lines(
	cast: ModelCast, scene: ActionScene, loop: ControlLoop
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what the run cost in model calls")
	written.append("  %-6s %6s %9s %9s %s" % [
		"who", "calls", "answered", "resolved", "calls per 100 ticks",
	])
	var ticks := maxi(1, scene.tick)
	for who in cast.order:
		var mind := cast.mind_of(who)
		written.append("  %-6s %6d %9d %9d %19.1f" % [
			who, mind.opened, mind.turns.size(), _resolved_by(loop.journal, who),
			100.0 * float(mind.opened) / float(ticks),
		])
	var calls := cast.calls()
	written.append("  %-6s %6d %9d" % ["total", calls, cast.answered()])
	written.append("  the run                    %d ticks, %d calls -> %.3f calls a tick" % [
		scene.tick, calls, float(calls) / float(ticks),
	])
	written.append("  an hour of play at that rate  %d ticks a second, so %d ticks an hour" % [
		ModelCast.TICKS_A_SECOND, ModelCast.TICKS_AN_HOUR,
	])
	written.append("                                %d calls an hour for %d characters"
		% [_an_hour(calls, ticks), cast.order.size()]
		+ ", %d each" % _an_hour(calls, ticks * cast.order.size()))
	# What the world charged for asks that cost it no time, when it charged
	# anything. Printed only when there was something to print, so a run nobody
	# was refused anything in says what it always said.
	var refused := scene.asks_refused.size()
	if refused > 0:
		written.append("  asks the world refused     %d of %d calls (%.1f%%), each"
			% [refused, calls, 100.0 * float(refused) / float(maxi(1, calls))]
			+ " one turn and %d ticks standing -- see sim/tool_budget.gd"
			% ToolBudget.costs())
	return written


## What a run of this shape would come to in an hour of play, at the rate it
## made calls over the ticks it lived for. Rounded to a whole call.
static func _an_hour(calls: int, ticks: int) -> int:
	return 0 if ticks <= 0 else int(round(
		float(calls) * float(ModelCast.TICKS_AN_HOUR) / float(ticks)))


## The bias table: being asked again mid-action is not a new call.
##
## `ControlLoop` asks a decision function again every `REVIEW_EVERY` ticks while
## an action is running -- section 2.2's "the agent re-evaluates at some
## frequency" -- and a mind that started a new exchange on every one of those
## would call a model four times a second. It does not: it keeps its answer
## against the number of actions the world says its character has had carried
## out, so an ask that arrives mid-action is answered out of what it already
## said.
##
## The table prices that. Every ask of a mind is one of exactly three things and
## the three columns sum to the asks:
##
##   * `calls` -- a new question was put. The only column that costs anything.
##   * `held` -- the mind offered back the action it had already chosen, because
##     the world says the character has not finished it. This is the bias.
##   * `polled` -- a question was already outstanding, the channel was read, and
##     the character went on standing in the world. This is what a wait looks
##     like from the deciding side.
##
## `re-evaluations` is the loop's own count of mid-action reviews for that
## character, read out of the journal rather than instrumented, because the
## journal is already the account of what happened. The last line is the ratio
## the milestone asks for: re-evaluations against model calls.
static func bias_lines(cast: ModelCast, loop: ControlLoop) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("being asked again is not a new call")
	written.append("  %-6s %8s %6s %7s %7s %15s %s" % [
		"who", "asked", "calls", "held", "polled", "re-evaluations",
		"re-evaluations per call",
	])
	var consulted := 0
	var calls := 0
	var held := 0
	var polled := 0
	var reviews := 0
	for who in cast.order:
		var mind := cast.mind_of(who)
		var mine := _reviews_of(loop.journal, who)
		consulted += mind.consulted
		calls += mind.opened
		held += mind.held
		polled += mind.polled
		reviews += mine
		written.append("  %-6s %8d %6d %7d %7d %15d %23.2f" % [
			who, mind.consulted, mind.opened, mind.held, mind.polled, mine,
			0.0 if mind.opened == 0 else float(mine) / float(mind.opened),
		])
	written.append("  %-6s %8d %6d %7d %7d %15d %23.2f" % [
		"total", consulted, calls, held, polled, reviews,
		0.0 if calls == 0 else float(reviews) / float(calls),
	])
	written.append("  re-evaluations to model calls  %d : %d = %.2f -- the loop asks again"
		% [reviews, calls, 0.0 if calls == 0 else float(reviews) / float(calls)]
		+ " every %d ticks an action runs, and none of those asks is a call"
		% ControlLoop.REVIEW_EVERY)
	written.append("  asks that cost a call          %d of %d (%.1f%%)" % [
		calls, consulted,
		0.0 if consulted == 0 else 100.0 * float(calls) / float(consulted),
	])
	written.append("  the loop's own counts          %s" % _counts_line(loop).strip_edges())
	return written


# How many mid-action re-evaluations the loop made for one character, counted off
# its journal. The loop writes "thought again" for every review that kept what
# was running and "changed its mind" for every one that did not.
static func _reviews_of(journal: PackedStringArray, who: String) -> int:
	var found := 0
	for line in journal:
		if _who_of(line) != who:
			continue
		var what := _what_of(line)
		if what.begins_with("thought again") or what.begins_with("changed its mind"):
			found += 1
	return found


# How many actions a character actually had resolved, counted off the journal for
# the same reason the re-evaluations are: the journal is already the account of
# what happened, and a second one could disagree with it.
static func _resolved_by(journal: PackedStringArray, who: String) -> int:
	var found := 0
	for line in journal:
		if _who_of(line) == who and _what_of(line).begins_with("finished "):
			found += 1
	return found


## The two things the first run of this file measured, measured again.
##
## That run found the model repeating one greeting off observations that were
## byte-identical, and never once choosing a position on the window of ground it
## was handed. Neither was a fault of the model: it could not observe that it had
## already spoken, and the window arrived with no key. Both are now in the
## packet, so both numbers are printed here every run rather than being read off
## a transcript by hand afterwards.
##
##   * *repeated speech* -- the most times one line of speech was chosen, and how
##     many turns in a row were asked with one unchanged observation. A run in
##     which the character can tell it has spoken should show fewer of both.
##   * *a position chosen* -- how many turns named a position rather than an id.
##     The window is only worth its characters if somebody can act on it.
static func measured_lines(cast: ModelCast) -> PackedStringArray:
	var written := PackedStringArray()
	var spoken := {}
	var most := 0
	var most_said := ""
	var positions := 0
	var says := 0
	var rows := cast.turns()
	for turn in rows:
		var chose: Action = turn["chose"]
		if chose == null:
			continue
		if chose.kind == ActionCatalog.SAY:
			says += 1
			var text := String(chose.param("text", ""))
			spoken[text] = int(spoken.get(text, 0)) + 1
			if int(spoken[text]) > most:
				most = int(spoken[text])
				most_said = text
		for key in chose.params:
			if chose.params[key] is Vector2:
				positions += 1
				break
	written.append("what the first run of this file measured, measured again")
	written.append("  turns                      %d, across %d characters" % [
		rows.size(), cast.order.size(),
	])
	written.append("  lines of speech chosen     %d, %d of them different" % [
		says, spoken.size(),
	])
	written.append("  the most-repeated line     %d time%s%s" % [
		most, "" if most == 1 else "s",
		"" if most_said == "" else ": \"%s\"" % _clip(most_said, 60),
	])
	written.append("  turns asked with the same observation as the one before  %d" % (
		_repeated_questions(cast)))
	written.append("  turns that chose a position %d" % positions)
	return written


## One line per character saying what its memory came to -- every character in
## the run, not only the ones whose minds are models.
##
## The full log of one of them is printed below; six full logs would be most of
## the transcript. This is the shape of all six side by side: how much each came
## to remember, how many characters that is, and how often each reached for a
## tool. The tool columns are the only ones a character a person drives has no
## number in, because the three tools are how a *model* asks for a thing the
## prompt offers; the two stores themselves are maintained for it by the same
## `CharacterUpkeep` that maintains them for the other five, which is what the
## `entries` column of its row is evidence of.
static func memory_summary_lines(cast: ModelCast, scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what each of them came to remember")
	written.append("  %-6s %-8s %8s %8s %9s %11s %8s %s" % [
		"who", "driven by", "entries", "events", "lessons", "characters",
		"recalls", "lessons written",
	])
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet == null:
			continue
		var who := sheet.character_name
		var mind := cast.mind_of(who)
		var remembered := sheet.memory
		if remembered == null:
			written.append("  %-6s nothing is keeping a memory for it" % who)
			continue
		written.append("  %-6s %-8s %8d %8d %9d %11d %8s %15s" % [
			who, _driver_of(who), remembered.entry_count(), remembered.events.size(),
			remembered.lessons.size(), remembered.text_length(),
			"-" if mind == null else str(mind.recalls),
			"-" if mind == null else str(mind.lessons_written),
		])
	return written


## Every relationship the world recorded over the run: one line per end of every
## edge, with the character a person drives standing in the same table as the
## five whose minds are models.
##
## This is the "no preferential treatment" claim for the third store, as numbers
## rather than as an argument. The edges are not on anybody's sheet -- they are
## one graph the world owns -- and every one of them was folded in by the same
## `CharacterUpkeep` all six characters pass, which names no decision function
## and so has nothing to branch on. A row is what one end of one edge holds:
## what that character trusts, fears and respects about the one at the other end,
## how much of them it has actually seen, and the one composite section 6's
## ownership maths reads.
static func relationship_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	var graph := scene.relationships
	written.append("what the world recorded between them")
	written.append("  %d edge%s, made of %d happening%s, and not one of them on"
		% [
			graph.size(), "" if graph.size() == 1 else "s",
			graph.happenings(), "" if graph.happenings() == 1 else "s",
		]
		+ " anybody's sheet")
	written.append("  sentiment is familiarity x (trust - fear), which is the one"
		+ " number section 6 reads")
	written.append("  %-6s %-9s %-6s %7s %7s %9s %13s %10s" % [
		"who", "driven by", "with", "trust", "fear", "respect", "familiarity",
		"sentiment",
	])
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet == null:
			continue
		var theirs := graph.edges_of(one.id)
		if theirs.is_empty():
			written.append("  %-6s %-9s nothing has passed between it and anybody"
				% [sheet.character_name, _driver_of(sheet.character_name)])
			continue
		for edge in theirs:
			var side := edge.toward(one.id)
			written.append("  %-6s %-9s %-6s %7.2f %7.2f %9.2f %13.2f %+10.2f" % [
				sheet.character_name, _driver_of(sheet.character_name),
				_called(scene, edge.other_than(one.id)),
				side["trust"], side["fear"], side["respect"], side["familiarity"],
				edge.sentiment_of(one.id),
			])
	written.append("  and what each edge is made of, in the world's own words")
	for line in graph.lines():
		written.append("    " + line)
	return written


## What the character with this id is called, for a table.
static func _called(scene: ActionScene, id: int) -> String:
	var sheet := _sheet(scene.actor_of(id))
	return "#%d" % id if sheet == null or sheet.character_name == "" \
		else sheet.character_name


## The memory of one named character, off its own sheet.
static func _memory_named(scene: ActionScene, who: String) -> CharacterMemory:
	var sheet := _sheet(_named(scene, who))
	return null if sheet == null else sheet.memory


## What one model character's memory came to, measured rather than guessed.
##
## Pell's, in full, because printing all five logs would be most of the
## transcript; the five side by side are the summary table above.
##
## Five numbers and no adjectives: how many things it remembers, how many
## characters those come to, how much of that the last packet it was handed
## actually carried, and how often it reached for any of the three tools. The
## fourth is the one the stop condition is about -- a memory that outgrows what a
## context can carry is a number here before it is a problem anywhere.
static func memory_lines(
	mind: ModelMind, scene: ActionScene, channel: ModelChannel = null
) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what %s came to remember" % PELL)
	var remembered := _memory_of(scene)
	if remembered == null:
		written.append("  nothing is keeping a memory for it")
		return written
	var counts := remembered.counts()
	var carried := remembered.context_length()
	var held := remembered.text_length()
	written.append("  entries                    %d (%d events, %d lessons)" % [
		remembered.entry_count(), remembered.events.size(), remembered.lessons.size(),
	])
	written.append("  events by kind             %s" % _counts_of(counts))
	written.append("  characters held            %d" % held)
	written.append("  characters a packet carries %d of %d (%.0f%%), being every"
		% [carried, held, 0.0 if held == 0 else 100.0 * float(carried) / float(held)]
		+ " lesson and the last %d event%s" % [
			mini(CharacterMemory.RECENT, remembered.events.size()),
			"" if remembered.events.size() == 1 else "s",
		])
	written.append_array(_last_question_lines(channel))
	written.append("  tools used                 %d recall%s, %d lesson%s written%s" % [
		mind.recalls, "" if mind.recalls == 1 else "s",
		mind.lessons_written, "" if mind.lessons_written == 1 else "s",
		"" if mind.refused_asks == 0 else ", %d ask%s the world refused" % [
			mind.refused_asks, "" if mind.refused_asks == 1 else "s",
		],
	])
	written.append("  everything it remembers")
	for line in remembered.lines():
		written.append("    " + line)
	return written


# How much of the last question this character was put was what it remembers.
# Measured off the text that was actually sent rather than off the store, so the
# number is the share of the context and not an estimate of one.
static func _last_question_lines(channel: ModelChannel) -> PackedStringArray:
	var written := PackedStringArray()
	if channel == null:
		return written
	var asked := channel.questions()
	if asked.is_empty():
		return written
	var prompt := String(asked[asked.size() - 1]["prompt"])
	var block := ModelPrompt.memory_block_of(prompt).length()
	written.append("  the last question put      %d characters, of which %d (%.0f%%)"
		% [prompt.length(), block,
			0.0 if prompt.length() == 0 else 100.0 * float(block) / float(prompt.length())]
		+ " are what it remembers")
	return written


static func _counts_of(counts: Dictionary) -> String:
	var written := PackedStringArray()
	for key in counts:
		written.append("%s %d" % [key, counts[key]])
	return " ".join(written)


## Pell's memory, off its own sheet.
static func _memory_of(scene: ActionScene) -> CharacterMemory:
	var sheet := _sheet(_named(scene, PELL))
	return null if sheet == null else sheet.memory


# How many turns were asked with the observation that character's turn before was
# asked with. The number that says a question was put again unchanged -- counted
# per character, because two characters standing in the same market see different
# packets and comparing across them would say nothing.
static func _repeated_questions(cast: ModelCast) -> int:
	var same := 0
	for who in cast.order:
		var mind := cast.mind_of(who)
		for index in range(1, mind.turns.size()):
			if String(mind.turns[index]["observed"]) \
					== String(mind.turns[index - 1]["observed"]):
				same += 1
	return same


## What the character was after, who answered each, and what came of it.
##
## The claim this table carries is the one the goal layer is built around: **the
## model chooses, and the world says whether a goal is met.** So the table prints,
## for every goal Pell started after, which hand can close it and what the world
## last said about it in the world's own words -- and then every closing that
## actually happened, in order, with the hand that did it.
##
## A goal the world answers is settled out of `ActionScene` by `GoalCheck`, at
## every servicing of the character it is on, and the character is never
## consulted about it. A goal the world holds no state for is the character's to
## close through the shared closing, and an attempt to close one of the others is
## refused with the world named as the reason. Both appear here: the refusals are
## printed rather than hidden, because a boundary nobody ever tested is a
## boundary nobody has evidence for.
##
## Two characters are printed, not one, and that is the point of the table: the
## one whose mind is a model and the one a person drives through choices written
## down in advance. Both are read off their own sheets, in the same shape, by
## code that is not told which is which -- and the world closes a goal for the
## second exactly as it does for the first.
static func goal_lines(scene: ActionScene) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("what they were after -- scenario setup, not game content")
	for who in [PELL, PERSON]:
		written.append_array(_goals_of_one(scene, String(who)))
	return written


# One character's goals, what the world last said about each, and every closing
# and refusal that happened to it.
static func _goals_of_one(scene: ActionScene, who: String) -> PackedStringArray:
	var written := PackedStringArray()
	var actor := _named(scene, who)
	var sheet := _sheet(actor)
	var goals: GoalSet = null if sheet == null else sheet.goals
	if goals == null or goals.size() == 0:
		written.append("  %s was after nothing" % who)
		return written
	written.append("  %s, driven by %s" % [who, _driver_of(who)])
	written.append("  %-3s %-5s %-42s %-24s %s" % [
		"no", "over", "what it is after", "answered by", "where it stands now",
	])
	for goal in goals.held:
		var answer := GoalCheck.met(goal, scene, actor)
		written.append("  %-3d %-5s %-42s %-24s %s" % [
			goal.id, goal.horizon, goal.said(),
			"the world" if GoalCheck.answers(goal) else "the character itself",
			("closed at tick %d: %s" % [goal.closed_at, goal.closed_by])
				if goal.closed else "open -- %s" % answer["how"],
		])
	var closings := GoalCheck.closings_of(goals)
	written.append("  closings                   %d" % closings.size())
	for row in closings:
		var closed: Goal = row["goal"]
		written.append("    t=%-4d %-42s closed by %s: %s" % [
			int(row["tick"]), closed.said(), row["by"], row["how"],
		])
	written.append("  refused closings           %d (the character asked to close a"
		% goals.refusals.size() + " goal and was told it could not)")
	for row in goals.refusals:
		var refused: Goal = row["goal"]
		written.append("    t=%-4d %-42s refused: %s" % [
			int(row["tick"]),
			"a goal it does not hold" if refused == null else refused.said(),
			row["why"],
		])
	return written


## Pell's goals, off its own sheet. Pell is the only character in the run that
## was set out after anything; see the note at the head of the file.
static func _goals_of(scene: ActionScene) -> GoalSet:
	var sheet := _sheet(_named(scene, PELL))
	return null if sheet == null else sheet.goals


## What one observation held, in one line: who was in it, what it had heard, what
## was lying about, and how much ground it carried.
##
## The turn table names the observation by its digest, which says *which* one it
## was and nothing about what was in it. This says what was in it. The whole
## packet, for the first question of the run, is printed at the end of the
## transcript; printing all seventeen would be seven hundred lines of it.
static func saw_line(seen: Observation) -> String:
	var written := PackedStringArray()
	written.append("%d nearby" % seen.entities.size())
	for row in seen.entities:
		written.append("%s#%d %.1f %s" % [
			"" if not row.has("name") or row["name"] == null else "%s " % row["name"],
			row["id"], row["distance"], "seen" if row["line_of_sight"] else "unseen",
		])
	written.append("| %d heard" % seen.heard.size())
	written.append("| %d about" % seen.objects.size())
	for row in seen.objects:
		written.append("%s#%d %.1f %s" % [
			row["type"], row["id"], row["distance"],
			"?" if not row.has("state") or row["state"] == null else str(row["state"]),
		])
	written.append("| ground %dx%d, %d recent" % [
		Observation.WINDOW, Observation.WINDOW, seen.recent.size(),
	])
	return " ".join(written)


## The first question of the run in full: the menu, the packet, and the sentence
## that asks for one line back.
##
## This is here so that the transcript is evidence on its own -- what a model is
## handed is in it, rather than named by a digest and reproducible in principle.
## It is the first question rather than all of them because seventeen of these
## would be most of the file.
static func first_question_lines(channel: ModelChannel) -> PackedStringArray:
	var asked := channel.questions()
	if asked.is_empty():
		return PackedStringArray(["nothing was asked"])
	var written := PackedStringArray()
	written.append("the first question in full -- %d characters, digest %s" % [
		String(asked[0]["prompt"]).length(), asked[0]["digest"],
	])
	written.append("")
	written.append_array(_indent(String(asked[0]["prompt"]).split("\n")))
	return written


# --- Reading the run ------------------------------------------------------


# How many ticks the loop has serviced everybody for, and how many actions each
# has had resolved, at the end of one tick. Sampled every tick so that a span
# between two ticks can be read off afterwards rather than instrumented.
static func _serviced(scene: ActionScene, loop: ControlLoop) -> Dictionary:
	var row := {"tick": scene.tick, "ticks": {}, "actions": {}}
	for one in scene.actors:
		var sheet := _sheet(one)
		if sheet == null:
			continue
		row["ticks"][sheet.character_name] = loop.ticks_of(one.id)
		row["actions"][sheet.character_name] = loop.actions_of(one.id)
	return row


# How much of a count a character gained between two ticks.
static func _gap(
	serviced: Array[Dictionary], who: String, what: String, from_tick: int, to_tick: int
) -> int:
	return _at(serviced, who, what, to_tick) - _at(serviced, who, what, from_tick)


static func _at(
	serviced: Array[Dictionary], who: String, what: String, at_tick: int
) -> int:
	var found := 0
	for row in serviced:
		if int(row["tick"]) > at_tick:
			break
		found = int(row[what].get(who, found))
	return found


# Everybody the run serviced except one named character, in the order they were
# first seen.
static func _others_than(serviced: Array[Dictionary], than: String) -> PackedStringArray:
	var found := PackedStringArray()
	for row in serviced:
		for who in row["ticks"]:
			if who != than and not found.has(who):
				found.append(who)
	return found


## What the engine answered a character, one entry per action it actually
## resolved, in order: the outcome in the engine's own words, and how many times
## the same action had to be committed again because something interrupted it.
##
## Read out of the loop's journal rather than instrumented, because the journal
## is already the account of what happened and a second one could disagree with
## it. One resolution closes one turn -- a decision function is only asked for
## something new once the world says the last thing was carried out -- so these
## line up with the turns one for one.
static func _engine_answers(journal: PackedStringArray, who: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var interrupted := 0
	for line in journal:
		if _who_of(line) != who:
			continue
		var what := _what_of(line)
		if what.begins_with("interrupted ("):
			interrupted += 1
		elif what.begins_with("finished "):
			var at := what.find(" -> ")
			found.append({
				"said": what.substr(at + 4) if at >= 0 else what,
				"interrupted": interrupted,
			})
			interrupted = 0
	return found


# Whose line of the journal this is. The journal writes "t=%3d  %-6s %s".
static func _who_of(line: String) -> String:
	return "" if line.length() < 14 else line.substr(7, 6).strip_edges()


static func _what_of(line: String) -> String:
	return "" if line.length() < 14 else line.substr(14)


static func _chosen(cast: ModelCast) -> int:
	var found := 0
	for turn in cast.turns():
		if turn["chose"] != null:
			found += 1
	return found


static func _market_band(scene: ActionScene) -> int:
	var wren := _named(scene, ScriptedScenario.WREN)
	return 0 if wren == null else wren.band


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


static func _counts_line(loop: ControlLoop) -> String:
	var counts := loop.counts()
	var written := PackedStringArray()
	for key in counts:
		written.append("%s=%s" % [key, counts[key]])
	return " ".join(written)


static func _clip(text: String, width: int) -> String:
	return text if text.length() <= width else text.substr(0, width - 1) + "…"


static func _indent(lines: PackedStringArray) -> PackedStringArray:
	var written := PackedStringArray()
	for line in lines:
		written.append("    " + line)
	return written
