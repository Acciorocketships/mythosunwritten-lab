extends TestSuite
## A person buys a specific named item from a model-driven trader, end to end:
## from the moment they had no way to name it to the moment it is in their pack.
##
## The run is the play stage with the trader's mind a language model
## (`sim/scripted_bargain.gd`), driven from a written-down script of key
## presses at stated ticks -- the same `PlayerControls` the shell feeds real
## presses through, at the same ticks `--input` would press them, so the run
## the suite asserts over and the run the shell photographs are the same run.
##
## The arc the script walks, which is the finding this run answers
## (a person could offer items and coins but never *ask* for a named item):
##
##   1. aim at the trader and examine him -- what comes back is his equipment
##      and nothing else, because what is in somebody's bag is not observable
##      from outside. There is, at this moment, no way to name the lantern.
##   2. walk over, ask "what will you take for it?", and open a trade with a
##      coin and no ask -- an offer is a question, and it may hold nothing.
##   3. the moment the trade stands, the trader within reach shows his pack
##      (`Observation.carries_shown`), so the C key now rings over what he
##      carries; pick the lantern out of it.
##   4. offer his own price for it by name -- the `want` half of
##      `trade_propose`, fillable from a keyboard for the first time.
##   5. the trader's model weighs the offer and answers it; on the shipped
##      recording he accepts, and the lantern is in the person's pack.
##   6. the trader's own counter-offer -- on the shipped recording he quoted a
##      price aloud and proposed his own bargain while the person was dialling
##      -- is left standing after the sale, offering a lantern he no longer
##      carries; the person denies it.
##   7. the person then tries to take the denied offer after all, and the
##      engine refuses in its own words: the offer from Hob was denied.
##
## The replies come from `ModelRecording.BARGAIN_ROWS`, so the suite needs no
## key, no network and no model, and two runs print identical bytes.
class_name TestBargain

const SEED := ScriptedBargain.SEED
const FEN := ScriptedPlay.FEN
const HOB := ScriptedPlay.HOB
const LANTERN := ScriptedPlay.LANTERN
const PRICE := ScriptedPlay.LANTERN_PRICE

## How many ticks the run lives for: enough that the last answer lands and the
## window is seen shutting again after the last offer is answered.
const TICKS := 130

## The written-down key presses, by the tick each lands on. The same list a
## shell run presses through `--input` (see `input_line()`), so the two runs
## cannot drift apart. The slack between beats is what an interruption costs:
## a walk restarted by being spoken to still lands inside it.
const SCRIPT := [
	{"tick": 1, "key": PlayerControls.KEY_LINE},
	{"tick": 2, "key": PlayerControls.KEY_AIM},
	{"tick": 3, "key": PlayerControls.KEY_EXAMINE},
	{"tick": 9, "key": PlayerControls.KEY_APPROACH},
	{"tick": 35, "key": PlayerControls.KEY_SAY},
	{"tick": 50, "key": PlayerControls.KEY_FEWER_COINS},
	{"tick": 52, "key": PlayerControls.KEY_OFFER},
	{"tick": 60, "key": PlayerControls.KEY_INSIDE},
	{"tick": 61, "key": PlayerControls.KEY_FEWER_COINS},
	{"tick": 62, "key": PlayerControls.KEY_FEWER_COINS},
	{"tick": 63, "key": PlayerControls.KEY_FEWER_COINS},
	{"tick": 64, "key": PlayerControls.KEY_OFFER},
	{"tick": 95, "key": PlayerControls.KEY_EXAMINE},
	{"tick": 101, "key": PlayerControls.KEY_DENY},
	{"tick": 108, "key": PlayerControls.KEY_ACCEPT},
	{"tick": 115, "key": PlayerControls.KEY_EXAMINE},
]


func _init() -> void:
	suite_name = "bargain"


func run() -> void:
	var played := play()
	_the_person_started_with_no_way_to_name_the_item(played)
	_opening_a_trade_showed_the_wares(played)
	_the_ask_was_built_from_the_keyboard(played)
	_the_trader_learned_exactly_as_much(played)
	_the_model_driven_trader_answered_and_the_item_arrived(played)
	_a_proposal_was_denied_in_the_engines_own_words(played)
	_the_window_shut_again(played)
	_two_runs_print_the_same_bytes(played)


## Play the whole run and hand back everything that happened.
##
## Public because `tools/bargain_actions.gd` prints the same run -- the
## evidence and the test are one run, played by one script. The channel is
## handed in by the recorder (`./run_record.sh --live --bargain`) and defaults
## to the shipped recording for everybody else.
static func play(minds: ModelChannel = null) -> Dictionary:
	if minds == null:
		minds = ModelChannel.for_run(ModelRecording.bargain_exchange())
	var world := SimWorld.new(SEED)
	ScriptedBargain.muster(world, minds)
	var run := {
		"world": world,
		"id": world.follow_id,
		"choice": WorldCast.hand_over(world, world.follow_id),
		"controls": PlayerControls.new(),
		"channel": minds,
		"table": [],
		"notes": PackedStringArray(),
		"presses": [],
		"shown": [],
		"answered_tick": -1,
	}
	if run["choice"] == null:
		return run
	for beat in SCRIPT:
		_step_until(run, int(beat["tick"]))
		_press(run, int(beat["key"]))
	_step_until(run, TICKS)
	return run


## The same script as one `--input` schedule, so the shell run that photographs
## the panels presses exactly these keys on exactly these ticks.
static func input_line() -> String:
	var parts := PackedStringArray()
	for beat in SCRIPT:
		parts.append("%d:%s" % [
			int(beat["tick"]),
			OS.get_keycode_string(int(beat["key"])).to_lower(),
		])
	return ",".join(parts)


# --- The claims ------------------------------------------------------------


## Before any trade stands, the trader's pack is not observable: the first
## examine answers with his equipment and no `carries`, and nothing can be
## picked out of him. This is the moment the person has no way to name the
## lantern, and the run holds it on record.
func _the_person_started_with_no_way_to_name_the_item(run: Dictionary) -> void:
	var first := _answer_matching(run, "examine")
	check(not first.is_empty(), "the run should open with an examine")
	check(not String(first["line"]).contains("carries"),
		"the first examine should show no pack: %s" % first.get("line", "-"))
	var opening: Dictionary = (run["presses"] as Array)[2]
	equal(String(opening["taking"]), "",
		"before a trade stands there is nothing of his to pick")


## The moment the person's opening offer stands, the trader within reach shows
## his pack, and the C key picks the lantern out of it by name.
func _opening_a_trade_showed_the_wares(run: Dictionary) -> void:
	var shown: Array = run["shown"]
	check(not shown.is_empty(),
		"the standing trade should have shown somebody's pack to somebody")
	var lantern_seen := false
	for row in shown:
		if PackedStringArray(row["fen_sees"]).has(LANTERN):
			lantern_seen = true
	check(lantern_seen, "the person should have been shown the lantern by name")
	var picked := _press_of(run, PlayerControls.KEY_INSIDE)
	equal(String(picked["taking"]), LANTERN,
		"the C key should have picked the lantern out of the shown pack")


## The offer that asks for the item by name was built from key presses alone:
## the engine's answer echoes all four halves as the person dialled them.
func _the_ask_was_built_from_the_keyboard(run: Dictionary) -> void:
	var asked := _answer_matching(run, "want=1")
	check(not asked.is_empty(),
		"a proposal asking for a named item should have been resolved")
	check(String(asked["action"]).contains("want=[%s]" % LANTERN),
		"and it should name the lantern: %s" % asked.get("action", "-"))
	check(String(asked["action"]).contains("give_money=%d" % PRICE),
		"with the price on the other half: %s" % asked.get("action", "-"))
	check(bool(asked["ok"]), "and it should stand: %s" % asked.get("line", "-"))


## Symmetry, run rather than read: while the trade stood, the model-driven
## trader's own observation showed the person's pack exactly as the person's
## showed his. The rule does not know who is driving either of them.
func _the_trader_learned_exactly_as_much(run: Dictionary) -> void:
	var both := false
	for row in run["shown"]:
		if not PackedStringArray(row["fen_sees"]).is_empty() \
				and not PackedStringArray(row["hob_sees"]).is_empty():
			both = true
			check(PackedStringArray(row["hob_sees"]).has(ScriptedPlay.BLANKET),
				"the trader should be shown the person's blanket: %s" % str(row))
	check(both,
		"the packs should have been shown in both directions at once")


## The trader's model answered the ask itself -- through the same loop, in the
## same words anybody is answered in -- and the item is in the person's pack.
func _the_model_driven_trader_answered_and_the_item_arrived(run: Dictionary) -> void:
	var world: SimWorld = run["world"]
	var accepted := ""
	for line in world.loop.journal:
		if line.contains(HOB) and line.contains("finished trade_accept") \
				and line.contains("ok"):
			accepted = line
	not_equal(accepted, "",
		"the trader should have accepted a bargain: %s" % "\n".join(world.loop.journal))
	var fen := world.combat.scene.actor_of(int(run["id"]))
	check(_carries(fen, LANTERN), "the lantern should be in the person's pack")
	# The opening coin moves only if the trader took the opener as a gift
	# before the real ask replaced it; either way the price was paid.
	var gift := 0
	for line in world.loop.journal:
		if line.contains(HOB) and line.contains("finished trade_accept") \
				and line.contains("took_money=1"):
			gift = 1
	equal(ActionScene.inventory_of(fen).money, ScriptedPlay.FEN_MONEY - PRICE - gift,
		"the person paid the price%s" % (
			" and the opening coin" if gift == 1 else ""))
	var hob := world.combat.scene.actor_of(ScriptedPlay.id_of(world.combat.scene, HOB))
	check(not _carries(hob, LANTERN), "and the trader no longer carries it")
	check(ActionScene.inventory_of(hob).money >= ScriptedBargain.AFTER_MONEY,
		"the sale closed what the trader was after: %d coins" % (
			ActionScene.inventory_of(hob).money))


## The other ways of answering an offer are on the record in the engine's own
## words: the person's deny key and their accept key were both answered -- as
## a denial of whatever the trader had left standing, and as a refusal naming
## why there was nothing to take. Which sentences exactly depends on what the
## recorded draw had the trader leave on the table, so the claim is that every
## answer is the engine's, not which answer it is.
func _a_proposal_was_denied_in_the_engines_own_words(run: Dictionary) -> void:
	var denied := _answer_matching(run, "trade_deny")
	check(not denied.is_empty(), "the deny key should have been answered")
	var accepted_late := {}
	for row in run["table"]:
		if String(row["action"]).begins_with("trade_accept") \
				and int(row["tick"]) > int(denied.get("tick", 0)):
			accepted_late = row
	check(not accepted_late.is_empty(),
		"the accept key after the denial should have been answered")
	check(not bool(accepted_late.get("ok", true)),
		"and refused, since nothing acceptable stood: %s" % (
			accepted_late.get("line", "-")))
	check(String(accepted_late.get("reason", "")).contains("was denied")
		or String(accepted_late.get("reason", "")).contains("offered nothing"),
		"in the engine's own words: %s" % accepted_late.get("line", "-"))


## Once the trade is honoured there is no offer standing, so the window shuts
## again: the closing examine shows equipment and no pack, in the engine's own
## words.
func _the_window_shut_again(run: Dictionary) -> void:
	var last := {}
	for row in run["table"]:
		if String(row["line"]).begins_with("examine"):
			last = row
	check(not last.is_empty(), "the run should close with an examine")
	check(not String(last["line"]).contains("carries"),
		"with no trade standing the pack is shut again: %s" % last.get("line", "-"))


## The run is a fact about the seed and the recording: played twice, it prints
## identical bytes, which is what lets a report quote it.
func _two_runs_print_the_same_bytes(run: Dictionary) -> void:
	var again := play()
	equal("\n".join((again["world"] as SimWorld).loop.journal),
		"\n".join((run["world"] as SimWorld).loop.journal),
		"two replays of the recorded exchange should live identical runs")


# --- The driver ------------------------------------------------------------


# Live the world to a stated tick, watching two things as it goes: every new
# answer the engine gives the person, and -- on every tick -- whether either of
# the two at the stall is being shown the other's pack, in both directions,
# read off each one's own observation.
static func _step_until(run: Dictionary, tick: int) -> void:
	var world: SimWorld = run["world"]
	var scene := world.combat.scene
	var fen_id := int(run["id"])
	var hob_id := ScriptedPlay.id_of(scene, HOB)
	while world.tick < tick:
		world.step()
		var answer := world.loop.answer_of(fen_id)
		if not answer.is_empty() and int(answer["tick"]) != int(run["answered_tick"]):
			run["answered_tick"] = int(answer["tick"])
			(run["table"] as Array).append(answer)
		var fen := scene.actor_of(fen_id)
		var hob := scene.actor_of(hob_id)
		if fen == null or hob == null:
			continue
		var fen_sees := _carries_row(Observation.of(scene, fen), hob_id)
		var hob_sees := _carries_row(Observation.of(scene, hob), fen_id)
		if not fen_sees.is_empty() or not hob_sees.is_empty():
			(run["shown"] as Array).append({
				"tick": world.tick, "fen_sees": fen_sees, "hob_sees": hob_sees,
			})


# Press one key exactly as the shell would on this tick, put whatever it chose
# in the holder, and write down what the controls were left holding.
static func _press(run: Dictionary, keycode: int) -> void:
	var world: SimWorld = run["world"]
	var controls: PlayerControls = run["controls"]
	var chosen := controls.press(keycode, world.surroundings_of(int(run["id"])))
	if chosen != null:
		(run["choice"] as LiveChoice).choose(chosen)
	elif controls.note != "":
		(run["notes"] as PackedStringArray).append(
			"t=%d %s" % [world.tick, controls.note])
	(run["presses"] as Array).append({
		"tick": world.tick,
		"key": OS.get_keycode_string(keycode),
		"chose": "-" if chosen == null else chosen.line(),
		"taking": controls.taking,
		"holding": controls.holding,
		"coins": controls.coins,
	})


# What one packet shows of a given entity's pack, or an empty list.
static func _carries_row(seen: Observation, id: int) -> PackedStringArray:
	for row in seen.entities:
		if int(row["id"]) == id and row.has("carries"):
			return PackedStringArray(row["carries"])
	return PackedStringArray()


# The first answer whose line carries this fragment, or an empty dictionary.
func _answer_matching(run: Dictionary, fragment: String) -> Dictionary:
	for row in run["table"]:
		if String(row["line"]).contains(fragment):
			return row
	return {}


# The record of the first press of a given key.
func _press_of(run: Dictionary, keycode: int) -> Dictionary:
	var named := OS.get_keycode_string(keycode)
	for row in run["presses"]:
		if String(row["key"]) == named:
			return row
	return {}


static func _carries(one: Combatant, called: String) -> bool:
	var pack := ActionScene.inventory_of(one)
	if pack == null:
		return false
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == called:
			return true
	return false
