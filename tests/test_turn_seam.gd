extends TestSuite
## The seam between an action measured in ticks and a turn measured in turns.
##
## Before this, a commander on a board was a spectator in its own fight. An
## atomic `attack` occupies `ActionCatalog.occupies_of(ATTACK)` ticks, a fight
## took one whole turn every tick, being hit is one of section 2.2's
## interruptions, and `ActionEngine._attack` refuses unless it is already the
## actor's turn -- so with two commanders every chosen blow was abandoned before
## it landed and `CombatPolicy` resolved the whole fight by itself.
##
## The rule that settles it: **a turn lasts as long as the weapon action that
## spends it.** Five claims, each of which fails on the behaviour above:
##
##   1. **Both chosen blows land.** Two commanders whose decision functions both
##      choose `attack`, and both of them strike. Nothing is refused for being
##      out of turn and nothing is abandoned for being struck mid-swing.
##   2. **Every blow on the board was somebody's choice.** The number of weapon
##      actions the match resolved equals the number of chosen attacks that
##      finished, so the board's own stand-in chooser swung for nobody. This is
##      the check that fails hardest on the old behaviour, where the two counts
##      were many and zero.
##   3. **The wait is bounded by one action's span.** The longest a turn was ever
##      held is at most what an attack costs plus the tick the turn takes to be
##      played, computed off the catalogue rather than typed.
##   4. **A fight never waits on a decision.** With one commander wrapped in
##      `DecisionSource.deliberate`, its turns come up and pass, the other's
##      blows go on landing, and the fight reaches a decision -- in *more* turns
##      than the run where both answer, never fewer.
##   5. **One rule for everyone.** The same duel driven by a person's recorded
##      turns and by a program's rule produces the same world, fingerprinted.
##
## And, as every walkthrough in the project must: two processes agree on
## `./run_turn.sh`.
class_name TestTurnSeam

## The command the walkthrough is printed by.
const COMMAND := "res://run_turn.sh"

## How many identical choices a recorded decider is given for claim 5: more than
## it can be asked for in the run, because a recorded list is drained by every
## re-evaluation as well as by every commitment.
const RECORDED_TURNS := 200


func _init() -> void:
	suite_name = "turn seam"


func run() -> void:
	_both_chosen_blows_land()
	_every_blow_on_the_board_was_somebodys_choice()
	_the_wait_is_bounded_by_one_actions_span()
	_a_fight_never_waits_on_a_decision()
	_one_rule_for_a_person_and_a_program()
	_two_processes_agree()


# --- 1. Both chosen blows land --------------------------------------------


## Two commanders, both choosing `attack`, and both of them strike.
func _both_chosen_blows_land() -> void:
	var run := ScriptedTurn.played()
	var journal: PackedStringArray = run["lines"]

	var landed := {}
	for line in journal:
		if line.contains("finished attack(") and line.contains("-> attack ok"):
			landed[_who(line)] = int(landed.get(_who(line), 0)) + 1
	equal(landed.size(), 2,
		"both commanders landed a blow they chose (%s)" % _counted(landed))
	for who in [ScriptedTurn.HELD, ScriptedTurn.OTHER]:
		check(int(landed.get(who, 0)) >= 1, "%s struck at least once" % who)

	equal(int(run["refused"]), 0,
		"and no chosen blow was refused -- every one was resolved on its own turn")
	equal(_count(journal, "interrupted (attacked), abandoned attack("), 0,
		"and none was abandoned because somebody struck part-way through it")
	check(_count(journal, "ending=decided") == 1,
		"and the fight reached a decision rather than the round limit")


# --- 2. Nobody swings for a commander that chooses ------------------------


## Every weapon action the match resolved came from a character's own choice.
##
## `CombatMatch` writes one `attack #N` line per weapon action it resolves,
## whoever asked for it. Counting those against the chosen attacks that finished
## is the whole claim: equal means the board's stand-in chooser swung for
## nobody, and on the old behaviour the two counts were many and zero.
func _every_blow_on_the_board_was_somebodys_choice() -> void:
	var run := ScriptedTurn.played()
	var journal: PackedStringArray = run["lines"]
	var resolved := 0
	var chosen := 0
	for line in journal:
		if line.strip_edges().begins_with("attack #"):
			resolved += 1
		if line.contains("finished attack(") and line.contains("-> attack ok"):
			chosen += 1
	check(resolved > 0, "the match resolved %d weapon actions" % resolved)
	equal(resolved, chosen,
		"and every one of them was a blow somebody chose (%d resolved, %d chosen)"
		% [resolved, chosen])


# --- 3. What the board waits for ------------------------------------------


## A turn is held for at most one attack's span, and the number is computed.
func _the_wait_is_bounded_by_one_actions_span() -> void:
	var costs := ActionCatalog.occupies_of(ActionCatalog.ATTACK)
	var bound := costs + 1
	var run := ScriptedTurn.played()
	var gaps: PackedInt32Array = run["gaps"]
	check(gaps.size() >= 3, "%d turns were played after the first" % gaps.size())
	var longest := 0
	for gap in gaps:
		longest = maxi(longest, gap)
	check(longest <= bound,
		"the longest a turn was held is %d ticks, and an attack's span plus the"
		% longest + " tick the turn is played on is %d" % bound)
	check(longest > 1,
		"and a turn really was held: on the behaviour this replaces every turn"
		+ " was one tick apart")


# --- 4. A fight never waits on a decision ---------------------------------


## A commander whose decision function has not answered by the time its turn
## comes up passes, and the fight carries on without it.
func _a_fight_never_waits_on_a_decision() -> void:
	var quick := ScriptedTurn.played()
	var slow := ScriptedTurn.played(ScriptedTurn.HELD)
	var journal: PackedStringArray = slow["lines"]

	check(_count(journal, "has not decided yet") >= 1,
		"%s was asked on its own turn and had no answer" % ScriptedTurn.HELD)
	var played: PackedInt32Array = slow["turns"]
	var quick_turns: PackedInt32Array = quick["turns"]
	check(played.size() >= quick_turns.size(),
		"and the fight played %d turns rather than the %d it plays when both"
		% [played.size(), quick_turns.size()]
		+ " answer -- turns nobody answered are passed, not waited on")

	var gaps: PackedInt32Array = slow["gaps"]
	var quiet := 0
	for gap in gaps:
		if gap == 1:
			quiet += 1
	check(quiet >= 1,
		"%d of its turns were played the tick they came up" % quiet)
	check(_count(journal, "ending=decided") == 1,
		"and the fight still reached a decision")
	check(int(slow["landed"]) >= 1,
		"and the slow one struck once it had an answer")


# --- 5. One rule for everyone ---------------------------------------------


## A person's recorded turns and a program's rule reach the board the same way.
##
## The two scenes are set out identically and the choices made in them are the
## same choices; the only difference is which sort of `Callable` is on the sheet.
## The worlds they leave behind are compared by fingerprint.
func _one_rule_for_a_person_and_a_program() -> void:
	var by_rule := _play_with(false)
	var by_hand := _play_with(true)
	equal(by_hand["fingerprint"], by_rule["fingerprint"],
		"a person's recorded turns and a program's rule left the same world")
	check(int(by_hand["landed"]) >= 2,
		"and the recorded turns landed %d blows" % by_hand["landed"])
	equal(by_hand["landed"], by_rule["landed"],
		"as many as the rule did")


# One duel, driven either by written-down choices or by a rule that works them
# out. Everything else about the two runs is the same.
func _play_with(written_down: bool) -> Dictionary:
	var scene := ScriptedTurn.stage()
	var loop := ControlLoop.on(scene, ScriptedTurn.LOOP_SEED)
	if written_down:
		for one in scene.actors:
			var mark := _the_other(scene, one)
			var choices := []
			for _turn in RECORDED_TURNS:
				choices.append(Action.attack(mark.id, ScriptedTurn.SPEAR))
			_sheet(one).decide = DecisionSource.recorded(choices)
	else:
		ScriptedTurn.drive(scene)

	for _step in ScriptedTurn.TICKS:
		loop.step()
		scene.fight_step()
	var landed := 0
	for line in loop.journal:
		if line.contains("finished attack(") and line.contains("-> attack ok"):
			landed += 1
	var read := {"fingerprint": scene.fingerprint(), "landed": landed}
	ScriptedTurn.release(scene)
	return read


# --- 6. Two processes agree -----------------------------------------------


func _two_processes_agree() -> void:
	var first := _run_command()
	var second := _run_command()
	equal(first["code"], 0, "./run_turn.sh exits 0")
	equal(second["code"], 0, "and again")
	equal(first["text"], second["text"],
		"two runs of ./run_turn.sh printed different bytes")
	check(String(first["text"]).contains("what the board waits for"),
		"and the transcript is the walkthrough's")


# --- Reading a transcript -------------------------------------------------


func _run_command() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path(COMMAND), [], output, true)
	return {"code": code, "text": "\n".join(PackedStringArray(output))}


static func _count(lines: PackedStringArray, phrase: String) -> int:
	var found := 0
	for line in lines:
		if line.contains(phrase):
			found += 1
	return found


# Whose journal line this is: the name in the column the loop writes it in.
static func _who(line: String) -> String:
	for who in [ScriptedTurn.HELD, ScriptedTurn.OTHER]:
		if line.contains(" %s " % who):
			return who
	return ""


static func _counted(tally: Dictionary) -> String:
	var written := PackedStringArray()
	for key in tally:
		written.append("%s=%d" % [key, int(tally[key])])
	return ", ".join(written)


static func _the_other(scene: ActionScene, than: Combatant) -> Combatant:
	for one in scene.actors:
		if one != than:
			return one
	return than


static func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet
