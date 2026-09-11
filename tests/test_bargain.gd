extends TestSuite
## The trade surface, run rather than read: what a person at a keyboard can ask
## a model-driven trader for, what each of the two is shown of the other, and
## what moves when an offer is honoured.
##
## The run is the play stage with the trader's mind a language model
## (`sim/scripted_bargain.gd`), driven from a written-down script of key presses
## at stated ticks -- the same `PlayerControls` the shell feeds real presses
## through, at the same ticks `--input` would press them, so the run the suite
## asserts over and the run the shell photographs are the same run.
##
## ## What this suite claims, and what it does not
##
## It used to claim that the sale closed: that the trader accepted, that the
## lantern arrived, that the price was paid. That is not a claim about this
## project's code. It is a claim about what one language model happened to
## answer on one afternoon, and it made re-recording `BARGAIN_ROWS` a lottery
## with the suite's colour as the prize -- the first draw of 2026-09-09 had the
## trader propose from six units away, be refused for reach, and examine the
## pile for the rest of the run, and six checks went red on it. The pass was
## made again and the second draw is what ships. See
## `reports/observation-position.md`.
##
## So the claims below are split in two, and the split is the point.
##
##   * **The machinery**, in `_the_machinery_held()`, is asserted over *every*
##     recorded draw there is -- the shipped table and each past draw
##     `net/bargain_draws.gd` keeps, including the one that closed no sale. None
##     of it turns on the trader agreeing to anything: a pack is shown exactly
##     while a trade stands, a keyboard can name an item in the want half of an
##     ask, a refusal carries the engine's own reason for both kinds of mind,
##     and whatever is honoured moves exactly what it named and nothing else.
##   * **The end-to-end purchase**, in
##     `_a_purchase_closes_when_the_other_side_says_yes()`, is asserted
##     unconditionally and with no model in the run at all: the trader's mind is
##     a written-down counterparty who says yes to a bargain. That the whole arc
##     closes is machinery, and it is checked as machinery.
##   * **What one recorded reply happened to do** is one check,
##     `_what_the_shipped_recording_happened_to_do()`, which says so in its own
##     name and in its own words. It reads the transcript and asserts the
##     consequences of whatever it finds there, in either direction. A different
##     draw changes what it reports; it does not change whether it passes.
##
## The replies come from `ModelRecording.BARGAIN_ROWS` and
## `net/bargain_draws.gd`, so the suite needs no key, no network and no model,
## and two runs print identical bytes.
##
## ## The arc the script walks
##
## It is the finding this run answers -- a person could offer items and coins
## but never *ask* for a named item:
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
##   5. the trader's model weighs the offer and answers it, whichever way.
##   6. the person denies whatever the trader has left standing.
##   7. the person then tries to accept after all, and is answered in the
##      engine's own words.
class_name TestBargain

const SEED := ScriptedBargain.SEED
const FEN := ScriptedPlay.FEN
const HOB := ScriptedPlay.HOB
const LANTERN := ScriptedPlay.LANTERN
const BLANKET := ScriptedPlay.BLANKET
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

## How long the written-down counterparty of
## `_a_purchase_closes_when_the_other_side_says_yes()` stands there when nothing
## is being asked of him. One tick, so he answers the moment an offer arrives.
const WILLING_WAITS := 1

## The two sentences the engine refuses an acceptance with when there is nothing
## to accept. Written here as the engine writes them, because a check that
## matched a fragment of its own choosing would pass on a sentence the engine
## does not say.
const NOTHING_TO_ACCEPT := ["was denied", "offered nothing"]


func _init() -> void:
	suite_name = "bargain"


func run() -> void:
	var shipped := play()
	_the_machinery_held(shipped, "the shipped table, %s"
		% ModelRecording.BARGAIN_RECORDED_ON)
	for drawn in BargainDraws.past():
		_the_machinery_held(
			play(ModelChannel.replaying(drawn, "a past draw, replayed")),
			String(drawn["name"]))
	_a_purchase_closes_when_the_other_side_says_yes()
	_what_the_shipped_recording_happened_to_do(shipped)
	_two_runs_print_the_same_bytes(shipped)


## Play the whole run and hand back everything that happened.
##
## Public because `tools/bargain_actions.gd` prints the same run -- the
## evidence and the test are one run, played by one script. The channel is
## handed in by the recorder (`./run_record.sh --live --bargain`) and defaults
## to the shipped recording for everybody else.
##
## `trader` replaces the trader's mind after the stage is set out, and is what
## `_a_purchase_closes_when_the_other_side_says_yes()` hands in: with a
## written-down mind on him the channel is never asked anything, so that run
## holds no recorded reply at all. It stages nothing -- the world, the cast, the
## seed and the key presses are the same ones every other run here uses.
static func play(
	minds: ModelChannel = null, trader: Callable = Callable()
) -> Dictionary:
	if minds == null:
		minds = ModelChannel.for_run(ModelRecording.bargain_exchange())
	var world := SimWorld.new(SEED)
	ScriptedBargain.muster(world, minds)
	if trader.is_valid():
		var scene := world.combat.scene
		var hob := scene.actor_of(ScriptedPlay.id_of(scene, HOB))
		if hob != null and hob.piece is Commander:
			(hob.piece as Commander).sheet.decide = trader
	var run := {
		"world": world,
		"id": world.follow_id,
		"choice": WorldCast.hand_over(world, world.follow_id),
		"controls": PlayerControls.new(),
		"channel": minds,
		"table": [],
		"trader_table": [],
		"notes": PackedStringArray(),
		"presses": [],
		"shown": [],
		"window": [],
		"answered_tick": -1,
		"trader_answered_tick": -1,
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


# --- The machinery, over every draw there is -------------------------------


## Every claim this suite makes that is a claim about the code, asserted over
## one played run whatever its trader did.
##
## `called` names the draw in every failure message, because a claim that holds
## on one table and not on another is exactly the thing this suite exists to
## catch, and a message that did not say which table was replaying would leave
## that unreadable.
func _the_machinery_held(run: Dictionary, called: String) -> void:
	_the_pack_window_opened_exactly_while_a_trade_stood(run, called)
	_the_two_were_shown_each_others_packs_alike(run, called)
	_the_keyboard_built_an_ask_that_named_an_item(run, called)
	_nothing_appeared_and_nothing_vanished(run, called)
	_every_purse_moved_by_what_the_ledger_says(run, called)
	_every_refusal_carried_the_engines_own_reason(run, called)
	_the_deny_and_accept_keys_were_both_answered(run, called)


## What is in somebody's bag is observable from one place only: across a trade
## that stands, at arm's length. So on every tick of the run, each one's packet
## carries the other's pack exactly when an offer stands between them and they
## are within `ActionEngine.REACH` -- and carries nothing of it otherwise.
##
## This is the whole of `Observation.carries_shown` as a run rather than as a
## reading, and it holds whatever either mind chose: the window is opened by an
## offer standing, and closed by there being none.
##
## That a trade stood at all is the person's own doing and not the trader's --
## the script offers him a coin at tick 52 -- but a trader who had walked out of
## reach by then would have that offer refused for reach, and then no window
## opens. So the run holding no standing trade is not a failure here: it is a
## run whose opening offer the engine refused, and the check says which.
func _the_pack_window_opened_exactly_while_a_trade_stood(
	run: Dictionary, called: String
) -> void:
	var window: Array = run["window"]
	check(not window.is_empty(), "%s: the run should have been watched" % called)
	var opened := 0
	var wrong := {}
	for row in window:
		if bool(row["standing"]):
			opened += 1
		if bool(row["person_shown"]) != bool(row["standing"]) \
				or bool(row["trader_shown"]) != bool(row["standing"]):
			if wrong.is_empty():
				wrong = row
	check(wrong.is_empty(),
		"%s: a pack was shown when no trade stood, or hidden while one did: %s"
			% [called, str(wrong)])
	if opened == 0:
		var opener := _answer_beginning("trade_propose", run, 0)
		check(not opener.is_empty() and not bool(opener.get("ok", false))
				and String(opener.get("reason", "")) != "",
			"%s: no trade ever stood, so the person's opening offer must have"
				% called + " been refused in the engine's own words: %s"
				% opener.get("line", "nothing was answered at all"))
		return
	check(opened < window.size(),
		"%s: and the run should also hold ticks with no trade standing" % called)


## Symmetry, run rather than read: while the window is open the person is shown
## what the trader carries and the trader is shown what the person carries, in
## the same packet on the same tick. The rule does not know which of the two is
## driven by a person and which by a model.
func _the_two_were_shown_each_others_packs_alike(
	run: Dictionary, called: String
) -> void:
	var both := 0
	for row in run["window"]:
		if not bool(row["standing"]):
			continue
		both += 1
		check(PackedStringArray(row["person_sees"]).has(LANTERN)
				== _held_at(row, "trader_carries", LANTERN),
			"%s: the person should be shown the lantern exactly while the trader"
				% called + " holds it: %s" % str(row))
		check(PackedStringArray(row["trader_sees"]).has(BLANKET),
			"%s: the trader should be shown the person's blanket: %s" % [
				called, str(row)])
	check(both > 0 or _never_stood(run),
		"%s: the packs should have been shown in both directions at once" % called)


## The offer that asks for an item by name was built from key presses alone: the
## C key picked the lantern out of the pack the window had opened, the minus key
## dialled the price, and what the controls composed names both halves.
##
## The engine's answer to it is checked for being the engine's -- it stands and
## the offer is on the scene, or it is refused and the refusal says why. Which
## of those happened is not this check's business: the trader may have walked
## off or sold the thing, and either is a world the engine has a sentence for.
##
## And the key rings over what the packet shows, which is the same rule again
## from the keyboard's side. A draw whose trader had denied or honoured the
## opening offer before tick 60 has shut the window by then, and then there is
## nothing of his to name and the C key takes nothing. That is checked as the
## claim it is, rather than assumed away; the same claim with no model in it at
## all is `_a_purchase_closes_when_the_other_side_says_yes()`, where the window
## is held open by a written-down rule.
func _the_keyboard_built_an_ask_that_named_an_item(
	run: Dictionary, called: String
) -> void:
	var picked := _press_of(run, PlayerControls.KEY_INSIDE)
	check(not picked.is_empty(), "%s: the C key should have been pressed" % called)
	var showing := _window_at(run, int(picked.get("tick", -1)))
	if showing.is_empty() or not bool(showing["person_shown"]):
		equal(String(picked.get("taking", "")), "",
			"%s: with no pack being shown there is nothing of his to pick"
				% called)
		return
	equal(String(picked.get("taking", "")), LANTERN,
		"%s: the C key should have picked the lantern out of the shown pack"
			% called)
	var asks := _presses_of(run, PlayerControls.KEY_OFFER)
	check(asks.size() == 2,
		"%s: the script presses the offer key twice" % called)
	var ask: Dictionary = asks[asks.size() - 1]
	check(String(ask["chose"]).contains("want=[%s]" % LANTERN),
		"%s: the composed ask should name the lantern: %s" % [
			called, ask.get("chose", "-")])
	check(String(ask["chose"]).contains("give_money=%d" % PRICE),
		"%s: with the price on the other half: %s" % [
			called, ask.get("chose", "-")])
	var answer := _answer_to(run, String(ask["chose"]))
	check(not answer.is_empty(),
		"%s: the engine should have answered the ask" % called)
	if bool(answer.get("ok", false)):
		check(String(answer["line"]).contains("want=1"),
			"%s: a standing ask is answered with both halves counted: %s" % [
				called, answer.get("line", "-")])
	else:
		not_equal(String(answer.get("reason", "")), "",
			"%s: a refused ask is refused in the engine's own words: %s" % [
				called, answer.get("line", "-")])


## Nothing the world did not have appeared, and nothing it had vanished: on
## every tick, the two packs between them hold the same items and the same
## coins they started with, and the lantern has exactly one holder.
##
## A trade moves things between two packs. Whatever either mind chose, it cannot
## have made or destroyed any of it, and this is that said as a run.
func _nothing_appeared_and_nothing_vanished(
	run: Dictionary, called: String
) -> void:
	var window: Array = run["window"]
	if window.is_empty():
		return
	var opening: Dictionary = window[0]
	var coins := int(opening["person_money"]) + int(opening["trader_money"])
	equal(coins, ScriptedPlay.FEN_MONEY + ScriptedPlay.HOB_MONEY,
		"%s: the two should open with the coins the stage gives them" % called)
	for row in window:
		equal(int(row["person_money"]) + int(row["trader_money"]), coins,
			"%s: coins should not be minted or burnt at t=%d" % [
				called, int(row["tick"])])
		equal(String(row["between_them"]), String(opening["between_them"]),
			"%s: the two packs should hold the same things throughout, at t=%d: %s"
				% [called, int(row["tick"]), String(row["between_them"])])
		equal(int(_held_at(row, "person_carries", LANTERN))
				+ int(_held_at(row, "trader_carries", LANTERN)), 1,
			"%s: the lantern should have exactly one holder at t=%d" % [
				called, int(row["tick"])])


## Every coin that moved, moved because a trade was honoured, and moved by the
## amount that trade named.
##
## `ActionScene.trades` is the engine's own record of the trades it honoured,
## written on the one path a trade goes through. So each purse at the end is its
## opening purse plus what that ledger says, exactly -- and a draw in which
## nothing was honoured is a draw in which nothing moved.
func _every_purse_moved_by_what_the_ledger_says(
	run: Dictionary, called: String
) -> void:
	var world: SimWorld = run["world"]
	var scene := world.combat.scene
	var person_id := int(run["id"])
	var trader_id := ScriptedPlay.id_of(scene, HOB)
	var moved := {person_id: 0, trader_id: 0}
	var items := {person_id: 0, trader_id: 0}
	for trade in scene.trades:
		var from_id := int(trade["from"])
		var to_id := int(trade["to"])
		check(moved.has(from_id) and moved.has(to_id),
			"%s: only the two at the stall can have traded: %s" % [
				called, str(trade)])
		if not (moved.has(from_id) and moved.has(to_id)):
			continue
		moved[from_id] = int(moved[from_id]) - int(trade["gave_money"]) \
			+ int(trade["back_money"])
		moved[to_id] = int(moved[to_id]) + int(trade["gave_money"]) \
			- int(trade["back_money"])
		items[from_id] = int(items[from_id]) - int(trade["gave"]) + int(trade["back"])
		items[to_id] = int(items[to_id]) + int(trade["gave"]) - int(trade["back"])
	equal(_purse(scene, person_id), ScriptedPlay.FEN_MONEY + int(moved[person_id]),
		"%s: the person's purse is what the ledger says it is" % called)
	equal(_purse(scene, trader_id), ScriptedPlay.HOB_MONEY + int(moved[trader_id]),
		"%s: the trader's purse is what the ledger says it is" % called)
	var window: Array = run["window"]
	if not window.is_empty():
		var opening: Dictionary = window[0]
		var closing: Dictionary = window[window.size() - 1]
		equal(int(closing["person_carries_count"]) - int(opening["person_carries_count"]),
			int(items[person_id]),
			"%s: and the person's pack grew by what the ledger moved" % called)
		equal(int(closing["trader_carries_count"]) - int(opening["trader_carries_count"]),
			int(items[trader_id]),
			"%s: and the trader's pack grew by what the ledger moved" % called)


## Section 2.1's returned reason, for both kinds of mind: every action either of
## the two chose that the engine refused was refused in words, and the words are
## the engine's. The person at the keyboard and the trader's model are answered
## out of one resolver, so neither can be refused mutely.
func _every_refusal_carried_the_engines_own_reason(
	run: Dictionary, called: String
) -> void:
	var answered := 0
	var mute := {}
	for who in ["table", "trader_table"]:
		for row in run[who]:
			answered += 1
			if bool(row.get("ok", true)):
				continue
			if String(row.get("reason", "")).strip_edges() == "" and mute.is_empty():
				mute = row
			check(String(row["line"]).contains(String(row.get("reason", ""))),
				"%s: a refusal's sentence should carry its reason: %s" % [
					called, row.get("line", "-")])
	check(answered > 0, "%s: both should have been answered something" % called)
	check(mute.is_empty(),
		"%s: nobody may be refused without being told why: %s" % [called, str(mute)])


## The deny key and the accept key were both answered, and the answer to the
## accept agrees with what actually stood at that moment.
##
## Which of the two the trader left an offer standing for is the draw's
## business. Whether the engine answered the key that was pressed, and whether
## what it answered matches the scene it answered over, is not.
func _the_deny_and_accept_keys_were_both_answered(
	run: Dictionary, called: String
) -> void:
	var denied := _answer_beginning("trade_deny", run, 0)
	check(not denied.is_empty(),
		"%s: the deny key should have been answered" % called)
	var accepted := _answer_beginning(
		"trade_accept", run, int(denied.get("tick", 0)))
	check(not accepted.is_empty(),
		"%s: the accept key after the denial should have been answered" % called)
	if accepted.is_empty():
		return
	if bool(accepted.get("ok", false)):
		check(_ledger_has(run, int(accepted["tick"])),
			"%s: an acceptance that stood is on the trade ledger: %s" % [
				called, accepted.get("line", "-")])
	else:
		var says := false
		for sentence in NOTHING_TO_ACCEPT:
			if String(accepted.get("reason", "")).contains(sentence):
				says = true
		check(says,
			"%s: an acceptance with nothing to accept is refused in the engine's"
				% called + " own words: %s" % accepted.get("line", "-"))


# --- The purchase, with no model in the run at all -------------------------


## A person at a keyboard buys a named item from somebody who says yes, end to
## end, and everything the sale should move moves.
##
## The counterparty here is written down: `_willing()` below accepts a bargain
## -- an offer that asks him for something -- and otherwise stands there. That
## is deliberate and it is the whole
## point of this check. Whether a language model agrees to a bargain is the
## model's business and nothing this repository can assert; whether the trade
## surface carries a purchase from "there is no way to name that item" to "it is
## in my pack and I have paid for it" is machinery, and here it is checked as
## machinery, with the same key presses and no recording anywhere in the run.
func _a_purchase_closes_when_the_other_side_says_yes() -> void:
	var run := play(null, DecisionSource.scripted(TestBargain._willing))
	var world: SimWorld = run["world"]
	var scene := world.combat.scene
	var person := scene.actor_of(int(run["id"]))
	var trader := scene.actor_of(ScriptedPlay.id_of(scene, HOB))

	var window: Array = run["window"]
	check(not window.is_empty(), "the willing run should have been watched")
	check(not bool((window[0] as Dictionary)["person_shown"]),
		"the person should open the run with no way to name the lantern")

	check(_carries(person, LANTERN), "the lantern should be in the person's pack")
	check(not _carries(trader, LANTERN), "and the trader should no longer carry it")
	equal(ActionScene.inventory_of(person).money, ScriptedPlay.FEN_MONEY - PRICE,
		"the person should have paid the price and nothing besides")
	equal(ActionScene.inventory_of(trader).money, ScriptedBargain.AFTER_MONEY,
		"and the trader should be carrying what he was after")
	var closing: Dictionary = window[window.size() - 1]
	check(not bool(closing["standing"]),
		"with the sale honoured there is no offer standing")
	check(not bool(closing["person_shown"]),
		"so the window is shut again and the pack is not observable")
	_the_machinery_held(run, "the written-down willing counterparty")


# The written-down counterparty: he accepts a bargain -- an offer that asks him
# for something -- and otherwise stands there.
#
# The exact mirror of `ScriptedPlay._haggling`, which denies every bargain and
# takes every gift; and mirrored on purpose, because a counterparty that took
# the gift as well would take the person's opening coin and shut the pack window
# before the C key could ring over it. No rule of the world is restated here:
# what an acceptance does, and whether it may happen at all, is `ActionEngine`'s
# answer, refusals included.
static func _willing(scene: ActionScene, actor: Combatant) -> Action:
	for offer in scene.offers:
		if int(offer["to"]) != actor.id:
			continue
		if not PackedStringArray(offer["want"]).is_empty() \
				or int(offer["want_money"]) > 0:
			return Action.trade_accept(int(offer["from"]))
	return Action.wait(WILLING_WAITS)


# --- What one recorded reply happened to do --------------------------------


## The one check in this suite that turns on what the shipped recording says,
## and it says so.
##
## It reads the transcript for a trade of the trader's that the engine honoured
## and asserts the consequences of what it finds -- in either direction. On a
## draw where the sale closed, the lantern is in the person's pack, the price
## left their purse and the trader is carrying what he was after. On a draw
## where it did not, the lantern is still his and nobody paid for anything.
## Both are worlds this code is supposed to produce; which one a re-recording
## lands in is the model's business.
func _what_the_shipped_recording_happened_to_do(run: Dictionary) -> void:
	var world: SimWorld = run["world"]
	var scene := world.combat.scene
	var person := scene.actor_of(int(run["id"]))
	var trader := scene.actor_of(ScriptedPlay.id_of(scene, HOB))
	var paid := _paid_by(scene, person.id)
	equal(_purse(scene, person.id), ScriptedPlay.FEN_MONEY - paid,
		"whatever this draw did, the person paid what the honoured trades named")
	if not _carries(person, LANTERN):
		check(_carries(trader, LANTERN),
			"this draw closed no sale, so the trader still has the lantern")
		check(scene.trades.is_empty() or paid == 0,
			"and nothing the person paid for was the lantern")
		return
	check(not _carries(trader, LANTERN),
		"this draw closed the sale, so the trader no longer carries the lantern")
	check(paid >= PRICE,
		"and the person paid at least the asking price of %d: %d" % [PRICE, paid])
	check(_purse(scene, trader.id) >= ScriptedBargain.AFTER_MONEY,
		"and the sale closed what the trader was after: %d coins, wanting %d" % [
			_purse(scene, trader.id), ScriptedBargain.AFTER_MONEY])


## The run is a fact about the seed and the recording: played twice, it prints
## identical bytes, which is what lets a report quote it.
func _two_runs_print_the_same_bytes(run: Dictionary) -> void:
	var again := play()
	equal("\n".join((again["world"] as SimWorld).loop.journal),
		"\n".join((run["world"] as SimWorld).loop.journal),
		"two replays of the recorded exchange should live identical runs")


# --- The driver ------------------------------------------------------------


# Live the world to a stated tick, watching three things as it goes: every new
# answer the engine gives either of the two, and -- on every tick -- what each
# of them is shown of the other's pack beside what the scene says is standing
# between them.
static func _step_until(run: Dictionary, tick: int) -> void:
	var world: SimWorld = run["world"]
	var scene := world.combat.scene
	var person_id := int(run["id"])
	var trader_id := ScriptedPlay.id_of(scene, HOB)
	while world.tick < tick:
		world.step()
		_collect(run, "table", "answered_tick", person_id)
		_collect(run, "trader_table", "trader_answered_tick", trader_id)
		var person := scene.actor_of(person_id)
		var trader := scene.actor_of(trader_id)
		if person == null or trader == null:
			continue
		var seen_by_person := Observation.of(scene, person)
		var seen_by_trader := Observation.of(scene, trader)
		var person_sees := _carries_row(seen_by_person, trader_id)
		var trader_sees := _carries_row(seen_by_trader, person_id)
		var person_carries := Observation.carried_names_of(person)
		var trader_carries := Observation.carried_names_of(trader)
		var between := []
		between.append_array(Array(person_carries))
		between.append_array(Array(trader_carries))
		between.sort()
		(run["window"] as Array).append({
			"tick": world.tick,
			# What the scene says, read off the offers and the distance rather
			# than off the rule the packet is built by.
			"standing": (not scene.offer_between(person_id, trader_id).is_empty()
					or not scene.offer_between(trader_id, person_id).is_empty())
				and person.distance_to(trader) <= ActionEngine.REACH,
			# Whether the pack is being shown is whether the field is *there*:
			# an emptied pack is shown as nothing carried, which is not the same
			# fact as a pack that is not observable. See `Observation.of`.
			"person_shown": _shows_pack(seen_by_person, trader_id),
			"trader_shown": _shows_pack(seen_by_trader, person_id),
			"person_sees": person_sees,
			"trader_sees": trader_sees,
			"person_carries": person_carries,
			"trader_carries": trader_carries,
			"person_carries_count": person_carries.size(),
			"trader_carries_count": trader_carries.size(),
			"person_money": ActionScene.inventory_of(person).money,
			"trader_money": ActionScene.inventory_of(trader).money,
			"between_them": ", ".join(PackedStringArray(between)),
		})
		if _shows_pack(seen_by_person, trader_id) \
				or _shows_pack(seen_by_trader, person_id):
			(run["shown"] as Array).append({
				"tick": world.tick,
				"fen_sees": person_sees, "hob_sees": trader_sees,
			})


# Keep every new answer the engine gives one character, in the order they come.
static func _collect(run: Dictionary, into: String, seen: String, id: int) -> void:
	var world: SimWorld = run["world"]
	var answer := world.loop.answer_of(id)
	if answer.is_empty() or int(answer["tick"]) == int(run[seen]):
		return
	run[seen] = int(answer["tick"])
	(run[into] as Array).append(answer)


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


# Whether one packet is showing a given entity's pack at all, which is whether
# the field is there. A pack shown with nothing in it is still a pack shown.
static func _shows_pack(seen: Observation, id: int) -> bool:
	for row in seen.entities:
		if int(row["id"]) == id:
			return row.has("carries")
	return false


# What one packet shows of a given entity's pack, or an empty list.
static func _carries_row(seen: Observation, id: int) -> PackedStringArray:
	for row in seen.entities:
		if int(row["id"]) == id and row.has("carries"):
			return PackedStringArray(row["carries"])
	return PackedStringArray()


# Whether a watched tick's named pack held a named item.
static func _held_at(row: Dictionary, which: String, called: String) -> bool:
	return PackedStringArray(row[which]).has(called)


# The first answer the person got whose chosen action was this exact line.
func _answer_to(run: Dictionary, line: String) -> Dictionary:
	for row in run["table"]:
		if String(row.get("action", "")) == line:
			return row
	return {}


# The first answer the person got after a stated tick whose chosen action was of
# a named kind.
func _answer_beginning(kind: String, run: Dictionary, after: int) -> Dictionary:
	for row in run["table"]:
		if String(row.get("action", "")).begins_with(kind) and int(row["tick"]) > after:
			return row
	return {}


# What was watched on one tick, or an empty dictionary for a tick not watched.
func _window_at(run: Dictionary, tick: int) -> Dictionary:
	for row in run["window"]:
		if int(row["tick"]) == tick:
			return row
	return {}


# Whether no trade ever stood between the two in this run, which is the world a
# trader who walked out of reach leaves behind.
func _never_stood(run: Dictionary) -> bool:
	for row in run["window"]:
		if bool(row["standing"]):
			return false
	return true


# Whether the engine wrote a trade down on the scene's ledger at a given tick.
func _ledger_has(run: Dictionary, tick: int) -> bool:
	for trade in ((run["world"] as SimWorld).combat.scene.trades):
		if int(trade["tick"]) == tick:
			return true
	return false


# The record of the first press of a given key.
func _press_of(run: Dictionary, keycode: int) -> Dictionary:
	var found := _presses_of(run, keycode)
	return {} if found.is_empty() else found[0]


# Every press of a given key, in the order they were pressed.
func _presses_of(run: Dictionary, keycode: int) -> Array:
	var named := OS.get_keycode_string(keycode)
	var found := []
	for row in run["presses"]:
		if String(row["key"]) == named:
			found.append(row)
	return found


# What one character paid out across every trade the engine honoured.
static func _paid_by(scene: ActionScene, id: int) -> int:
	var paid := 0
	for trade in scene.trades:
		if int(trade["from"]) == id:
			paid += int(trade["gave_money"]) - int(trade["back_money"])
		elif int(trade["to"]) == id:
			paid += int(trade["back_money"]) - int(trade["gave_money"])
	return paid


static func _purse(scene: ActionScene, id: int) -> int:
	var pack := ActionScene.inventory_of(scene.actor_of(id))
	return 0 if pack == null else pack.money


static func _carries(one: Combatant, called: String) -> bool:
	var pack := ActionScene.inventory_of(one)
	if pack == null:
		return false
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == called:
			return true
	return false
