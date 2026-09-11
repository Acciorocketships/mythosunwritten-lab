extends TestSuite
## Every verb a person can reach: the whole atomic action set, driven from input.
##
## `tests/test_player_input.gd` showed that a person is one of the minds and can
## walk, go somewhere named and jump. This is the rest of section 2.1 --
## examine, pick up, drop, say (targeted and shouted), propose, accept and deny a
## trade, interact, attack and wait -- reached from key presses, aimed at targets
## the person picked, and refused in the engine's own words.
##
## Six claims:
##
##   1. **One seeded run performs every row of the catalogue.** The play scenario is set out,
##      one of its characters is handed over, and a script of key presses drives
##      every row of `ActionCatalog.ROWS` through `ActionEngine`. The table of
##      what was chosen on which tick, at what, and what the engine answered is
##      printed by `./tools/play_actions.sh` and asserted here.
##   2. **What can be aimed at is what the character can observe.** The list the
##      controls cycle is `Surroundings`, which is `Observation` -- so a thing the
##      character cannot make out cannot be aimed at, and the rule that decides
##      which is the simulation's.
##   3. **Refusals reach the person in the engine's wording**, for several
##      different reasons, one of them a trade that was denied.
##   4. **No verb is invented and no rule is written on the render side.** A scan
##      over the interface files: every action they build is a catalogue row, and
##      none of them names the engine's reach, sight, earshot, jump or cost, or
##      the resolver itself.
##   5. **Speech and trade are legible**: who said what, to whom or shouted, and
##      both halves of an offer with the items and the coins each way.
##   6. **The controls hold nothing the world does not.** What is aimed at is
##      kept by id, so a thing that walks out of sight stops being aimed at.
##   7. **The keyboard refuses nothing the world allows.** An unarmed blow -- the
##      one choice the attack key used to answer by itself -- is built from the
##      keys and made straight out of the catalogue in two worlds off one seed,
##      and the two reach the same answer. And the condition has one wording in
##      the tree rather than three.
class_name TestPlayerActions

## The seed and the stage: the play scenario, on the same measured meadow every
## other walkthrough is played on.
const SEED := ScriptedPlay.SEED

## How long one press's action is waited for before the run gives up on it, in
## ticks. Generous, because a `go_to` costs twenty and an attack waits for a turn
## the board has to come round to.
const PATIENCE := 90

## How long the run lets the world alone between beats, so that the trader can
## take his own turn.
const BREATH := 12

## How many times the attack key is pressed before the run gives up on the fight
## coming round to the person's turn.
const SWINGS := 12

## How long the run waits for the board to appear once the person has walked
## over to the brawler, in ticks.
const CLOSING := 60

## What the play scenario's cast and furniture are called, read back rather than
## typed again.
const HOB := ScriptedPlay.HOB
const RILL := ScriptedPlay.RILL
const PILE := "pile"
const CHEST := "chest"
const KEY_ITEM := ScriptedPlay.KEY
const RING := ScriptedPlay.RING
const BLANKET := ScriptedPlay.BLANKET
const SWORD := ScriptedPlay.SWORD
const BOOTS := ScriptedPlay.BOOTS
const DRAUGHT := ScriptedPlay.DRAUGHT

## The files that turn a press into an action or put the choosing on screen. The
## scan in claim 4 is over exactly these.
const INTERFACE_FILES := [
	"res://render/player_controls.gd",
	"res://render/ui/play_panel.gd",
	"res://render/ui/answer_panel.gd",
	"res://render/ui/character_panel.gd",
	"res://render/ui/dialogue_panel.gd",
	"res://render/ui/trade_panel.gd",
]

## What none of them may name: the engine's own rules about how far a thing is,
## how far a voice carries, how far a jump reaches, what an action costs and
## whether it can be done at all -- and the resolver and the table themselves.
##
## `PlayerControls.STEP`, `HOP` and `LEAP` are not on this list and are not rules:
## they are how far one press *sends* a character, which the engine then measures
## against DEX and against the ground. A rule would be the interface deciding
## whether the character gets there.
const NO_RULES := [
	"ActionEngine", "ActionCatalog", "REACH", "SIGHT", "VOICE",
	"ENGAGE_RADIUS", "JUMP_BASE", "JUMP_PER_DEX", "ARRIVE", "MAX_STEPS",
	"occupies", "is_passable", "is_qualified", "holds_things", "was_refused",
	"can_attack", "distance_to",
]


func _init() -> void:
	suite_name = "player actions"


func run() -> void:
	var played := play()
	_every_verb_was_performed_from_input(played)
	_refusals_came_back_in_the_engines_own_words(played)
	_speech_and_trade_are_legible(played)
	_what_can_be_aimed_at_is_what_can_be_observed()
	_the_interface_invents_no_verb_and_holds_no_rule()
	_an_aim_is_kept_by_id_and_not_by_position()
	_the_aim_ring_turns_both_ways()
	_nothing_is_offered_with_a_blank_name()
	_the_keyboard_refuses_nothing_the_world_allows()
	_one_condition_has_one_wording()


# --- 1: one seeded run, every verb -----------------------------------------


## Play the scenario from a script of key presses and hand back everything that
## happened: the table of actions, the refusals, and the world at the end.
##
## Public because `tools/play_actions.gd` prints the same table -- the run that is
## the evidence and the run that is the test are one run, played by one script,
## so a table in a report cannot drift from a table in a suite.
static func play() -> Dictionary:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var run := {
		"world": world,
		"id": world.follow_id,
		"choice": WorldCast.hand_over(world, world.follow_id),
		"controls": PlayerControls.new(),
		"table": [],
		"notes": PackedStringArray(),
	}
	if run["choice"] == null:
		return run

	# Hob, at arm's length and then within it: look at him, speak to him, shout,
	# offer him a bargain from too far off, and walk over.
	_aim_at(run, HOB)
	_press(run, PlayerControls.KEY_EXAMINE)
	_press(run, PlayerControls.KEY_SAY)
	_press(run, PlayerControls.KEY_SHOUT)
	_press(run, PlayerControls.KEY_OFFER)
	_press(run, PlayerControls.KEY_APPROACH)
	_breathe(run, BREATH)

	# A bargain of the person's own, which Hob denies; then his, which the person
	# denies and then cannot accept; then his again, which the person takes.
	_hold(run, BLANKET)
	_press(run, PlayerControls.KEY_MORE_COINS)
	_press(run, PlayerControls.KEY_MORE_COINS)
	_press(run, PlayerControls.KEY_OFFER)
	_breathe(run, BREATH)
	_press(run, PlayerControls.KEY_DENY)
	_press(run, PlayerControls.KEY_ACCEPT)
	_breathe(run, BREATH)
	_press(run, PlayerControls.KEY_ACCEPT)

	# The pile: walk to it and take the key off it.
	_aim_at(run, PILE)
	_press(run, PlayerControls.KEY_APPROACH)
	_take(run, KEY_ITEM)
	_press(run, PlayerControls.KEY_TAKE)

	# The chest: the wrong thing in your hands, then the right one, then what is
	# inside it, then something of your own put back in and something dropped.
	_aim_at(run, CHEST)
	_press(run, PlayerControls.KEY_APPROACH)
	_hold(run, BLANKET)
	_press(run, PlayerControls.KEY_INTERACT)
	_hold(run, KEY_ITEM)
	_press(run, PlayerControls.KEY_INTERACT)
	_take(run, RING)
	_press(run, PlayerControls.KEY_TAKE)
	_press(run, PlayerControls.KEY_PUT)
	_hold(run, RING)
	_press(run, PlayerControls.KEY_LOOK)
	_press(run, PlayerControls.KEY_DROP)

	# The wardrobe: put the boots on, take them off again, and drink the draught.
	# All three are aimed at what is in hand, which is the same ring the trade
	# beats above turned.
	_hold(run, BOOTS)
	_press(run, PlayerControls.KEY_EQUIP)
	_press(run, PlayerControls.KEY_UNEQUIP)
	_hold(run, DRAUGHT)
	_press(run, PlayerControls.KEY_USE)

	# The three that need nobody: wait, hop, and leap further than DEX reaches.
	_press(run, PlayerControls.KEY_WAIT)
	_press(run, PlayerControls.KEY_HOP)
	_press(run, PlayerControls.KEY_LEAP)
	_press(run, KEY_W)

	# The fight: the person walks over to the brawler, who takes an interest when
	# they get near, and strikes at her with the sword when the board comes round
	# to them.
	#
	# She is aimed at by id and not by name, because the two have never met and a
	# name is knowledge -- `Observation` gives a stranger no name, so what the
	# person is aiming at reads as "#3" on the panel, which is what an action
	# takes anyway.
	var rill := ScriptedPlay.id_of(world.combat.scene, RILL)
	_aim_at_id(run, rill)
	_press(run, PlayerControls.KEY_APPROACH)
	_breathe_until_fighting(run, CLOSING)
	_hold(run, SWORD)
	_aim_at_id(run, rill)
	for _swing in SWINGS:
		var swung := _press(run, PlayerControls.KEY_ATTACK)
		if swung.get("ok", false):
			break
		_breathe(run, BREATH)
	return run


func _every_verb_was_performed_from_input(run: Dictionary) -> void:
	check(run.get("choice", null) != null, "there should have been somebody to hand over")
	var table: Array = run["table"]
	check(not table.is_empty(), "the run performed nothing at all")
	var done := {}
	for row in table:
		done[String(row["verb"])] = true
	for named in ActionCatalog.names():
		check(done.has(named),
			"'%s' was never performed from input in the played run" % named)
	# And every one of them went through the engine: a row exists because the
	# loop answered it, and the answer says which action it was answering.
	for row in table:
		check(String(row["answer"]).begins_with(String(row["verb"])),
			"the engine's answer to %s does not name it: %s" % [
				row["verb"], row["answer"],
			])


# --- 3: the engine's own words ---------------------------------------------


func _refusals_came_back_in_the_engines_own_words(run: Dictionary) -> void:
	var reasons := {}
	for row in run.get("table", []):
		if not bool(row["ok"]):
			reasons[String(row["reason"])] = String(row["verb"])
	check(reasons.size() >= 3,
		"a person should have been refused for at least three reasons, got %d" % reasons.size())

	# One of them is a trade the other side would not have: the person denied
	# Hob's offer and then tried to take it, and the engine says so.
	var denied := ""
	for reason in reasons:
		if reason.contains("was denied"):
			denied = reason
	not_equal(denied, "",
		"none of the refusals was a trade that had been denied: %s" % str(reasons.keys()))

	# And the denying went both ways: the person denied Hob's offer, above, and
	# Hob denied the person's -- which is the half a table of the person's own
	# actions cannot show, so it is read out of the loop's journal.
	var refused_by_the_other_side := false
	for line in (run["world"] as SimWorld).loop.journal:
		if line.contains("trade_deny") and line.contains("finished") \
				and not line.contains(ScriptedPlay.FEN):
			refused_by_the_other_side = true
	check(refused_by_the_other_side,
		"the other side should have denied the bargain the person offered it")

	# And the sentences are the resolver's, not the interface's: every one of
	# them is quoted whole on the answer panel, which writes none of its own.
	if not SproutPack.is_installed():
		return
	var panel := AnswerPanel.new()
	panel.watch(run["world"], int(run["id"]), run["choice"])
	panel.refresh()
	var answer: Dictionary = (run["world"] as SimWorld).loop.answer_of(int(run["id"]))
	if answer.is_empty():
		return
	equal(panel._answer_label.text, SproutPack.drawable(String(answer["line"])),
		"the panel should quote the engine rather than phrase its own answer")


# --- 5: speech and trade are legible ---------------------------------------


func _speech_and_trade_are_legible(run: Dictionary) -> void:
	var world: SimWorld = run["world"]
	var view := world.surroundings_of(int(run["id"]))
	check(not view.heard.is_empty(), "the person should have heard something by now")
	var shouted := false
	var aimed := false
	for said in view.heard:
		var line := PlayPanel.heard_line(said)
		check(line.contains(String(said["text"])),
			"a line of speech should carry the words that were said: %s" % line)
		if bool(said["shout"]):
			shouted = true
			check(line.contains("shouts"), "a shout should read as one: %s" % line)
		else:
			aimed = true
			check(line.contains("to "), "a targeted line should say who to: %s" % line)
	check(shouted, "the run shouted and the packet does not hold it")
	check(aimed, "the run spoke to somebody and the packet does not hold it")

	# Both halves of an offer, with the items and the coins each way. The run has
	# honoured its offers by now, so this is asserted over the offer the person
	# made, which is written down exactly as it was proposed.
	var offer := {
		"from": "you", "to": HOB,
		"give": PackedStringArray([BLANKET]), "give_money": 0,
		"want": PackedStringArray(), "want_money": 2,
	}
	var written := PlayPanel.offer_line(offer)
	check(written.contains(BLANKET), "an offer should name what goes across: %s" % written)
	check(written.contains("2 coin"), "an offer should name the coins: %s" % written)
	check(written.contains("gives") and written.contains("wants"),
		"an offer should say which half is which: %s" % written)
	check(PlayPanel.offer_line({
		"from": "you", "to": HOB,
		"give": PackedStringArray([BLANKET]), "give_money": 0,
		"want": PackedStringArray(), "want_money": 0,
	}).contains("wants nothing"),
		"a gift should read as a trade with nothing in return")


# --- 2: aiming is observing ------------------------------------------------


func _what_can_be_aimed_at_is_what_can_be_observed() -> void:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var id := world.follow_id
	var view := world.surroundings_of(id)
	var scene := world.combat.scene
	var actor := scene.actor_of(id)
	var seen := Observation.of(scene, actor)
	equal(view.aims.size(), seen.entities.size() + seen.objects.size(),
		"what can be aimed at should be exactly what the character observes")
	for row in view.aims:
		not_equal(int(row["id"]), id, "a character should not be in its own aim list")

	# The whole world is not in it: something put down far past what the packet
	# reaches is observed by nobody and so can be aimed at by nobody.
	var far := scene.add_object(WorldObject.loose(
		actor.x + Observation.NEARBY * 3.0, actor.z, Inventory.ground([])))
	var again := world.surroundings_of(id)
	check(again.aim_of(far.id).is_empty(),
		"a thing the character cannot observe should not be aimable")

	# And what can be seen inside something is the object's own answer: a shut
	# chest names nothing, and the same chest opened names what is in it.
	var shut := scene.add_object(WorldObject.chest(
		"strongbox", actor.x + 1.0, actor.z,
		Inventory.ground([Item.weapon("brass key", 1, ItemRarity.COMMON,
			Ability.DEX, [0, 0, 1] as Array[int])]), "brass key"))
	var closed := world.surroundings_of(id)
	check(PlayerControls.inside_of(closed, shut.id).is_empty(),
		"a shut chest should show nothing of what is in it")
	shut.shut = false
	var opened := world.surroundings_of(id)
	equal(PlayerControls.inside_of(opened, shut.id), PackedStringArray(["brass key"]),
		"an open chest should name what is in it")


# --- 4: no invented verb, no rule on this side -----------------------------


func _the_interface_invents_no_verb_and_holds_no_rule() -> void:
	var listed := ActionCatalog.names()
	for path in INTERFACE_FILES:
		var code := _code_of(path)
		check(code != "", "could not read %s" % path)
		for word in NO_RULES:
			check(not code.contains(word),
				"%s names '%s', which is the engine's answer and not the interface's"
					% [path, word])
		# Every action it builds is a row of the one list, and it never reaches
		# past the constructors to `Action.of`, which takes any name at all.
		check(not code.contains("Action.of("),
			"%s builds an action by name, which can name a verb that is not one" % path)
		for built in _actions_built_in(code):
			check(listed.has(built) or Action.shapes().has(built),
				"%s builds '%s', which the catalogue does not list" % [path, built])

	# And the controls really can build every row: what the run performed is what
	# the catalogue lists, which claim 1 asserts, and this is the other direction
	# -- there is no extra key that means something the catalogue does not list.
	var view := Surroundings.new()
	var controls := PlayerControls.new()
	for keycode in PlayerControls.WALK_KEYS:
		var walked := controls.press(keycode, view)
		check(walked != null and walked.kind == ActionCatalog.GO_TO,
			"a walk key should walk")


# --- 6: an aim is a thing, not a place in a list ---------------------------


func _an_aim_is_kept_by_id_and_not_by_position() -> void:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var id := world.follow_id
	var controls := PlayerControls.new()
	var view := world.surroundings_of(id)
	controls.press(PlayerControls.KEY_AIM, view)
	var first := controls.aimed_id
	not_equal(first, 0, "the first press should have aimed at something")

	# Aimed at, and still aimed at when the list is asked for again.
	equal(controls.press(PlayerControls.KEY_EXAMINE, world.surroundings_of(id)).target_id(),
		first, "the aim should still be on the same thing")

	# The thing goes away: the aim goes with it, and what would have been aimed
	# at is nothing rather than whatever moved up into its place.
	var scene := world.combat.scene
	var gone := scene.actor_of(first)
	if gone != null:
		gone.x += Observation.NEARBY * 4.0
	else:
		scene.remove_object(scene.object_of(first))
	var after := world.surroundings_of(id)
	check(after.aim_of(first).is_empty(), "the aimed thing should be out of the list")
	equal(controls.press(PlayerControls.KEY_EXAMINE, after), null,
		"nothing should be chosen at a target that is no longer there")
	equal(controls.note, "nothing is aimed at",
		"the interface should say what is missing rather than aim at something else")


# --- 7: the ring turns both ways -------------------------------------------


## Aiming used to go one way only, so overshooting what you wanted cost a lap of
## everything in sight. What is pinned here is the ring itself: its order, its
## contents, and that a step back is the step forward undone.
func _the_aim_ring_turns_both_ways() -> void:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var id := world.follow_id
	var view := world.surroundings_of(id)
	check(view.aims.size() >= 3,
		"the scenario should have enough in sight for a ring to be a ring")

	# The ring is the observation's own list, in the observation's own order,
	# and the whole of it: forward from nothing lands on the first row and comes
	# back round to it after exactly as many presses as there are rows.
	var order := PackedInt32Array()
	for row in view.aims:
		order.append(int((row as Dictionary)["id"]))
	var forwards := PackedInt32Array()
	var controls := PlayerControls.new()
	for _each in order.size():
		controls.press(PlayerControls.KEY_AIM, view)
		forwards.append(controls.aimed_id)
	equal(forwards, order,
		"aiming forward should walk the observation's own list, nearest first")
	controls.press(PlayerControls.KEY_AIM, view)
	equal(controls.aimed_id, order[0], "the ring should come round to the start")

	# And back the other way, from where the forward walk left off: the same
	# list, read from the end.
	var backwards := PackedInt32Array()
	for _each in order.size():
		controls.press(PlayerControls.KEY_AIM_BACK, view)
		backwards.append(controls.aimed_id)
	var reversed := PackedInt32Array()
	for at in order.size():
		reversed.append(order[order.size() - 1 - at])
	equal(backwards, reversed,
		"aiming back should walk the same list the other way")

	# One press forward and one back is where you started, which is the whole of
	# what the complaint was about.
	var here := controls.aimed_id
	controls.press(PlayerControls.KEY_AIM, view)
	not_equal(controls.aimed_id, here, "a press should move the aim")
	controls.press(PlayerControls.KEY_AIM_BACK, view)
	equal(controls.aimed_id, here, "a press back should undo a press forward")

	# From nothing aimed at, each direction starts at its own end of the ring.
	var fresh := PlayerControls.new()
	fresh.press(PlayerControls.KEY_AIM_BACK, view)
	equal(fresh.aimed_id, order[order.size() - 1],
		"aiming back from nothing should start at the far end of the ring")

	# With nothing in sight, both directions say the same thing and aim at
	# nothing -- the interface's own note, because the simulation was asked
	# nothing.
	var empty := Surroundings.new()
	for key in [PlayerControls.KEY_AIM, PlayerControls.KEY_AIM_BACK]:
		var alone := PlayerControls.new()
		equal(alone.press(key, empty), null, "an empty ring should build no action")
		equal(alone.aimed_id, 0, "an empty ring should leave nothing aimed at")
		equal(alone.note, "there is nothing in sight to aim at",
			"an empty ring should say so, whichever way it was turned")


# --- 8: nothing is offered with a blank name -------------------------------


## A stranger across the meadow used to be offered as `#3 (character) 30.0 away`
## -- a number and a gap where a name goes. What goes in the gap is the packet's
## own reason there is no name, and which reason it is is `Observation`'s answer
## and not the interface's.
func _nothing_is_offered_with_a_blank_name() -> void:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var id := world.follow_id
	var view := world.surroundings_of(id)
	var reasons := [Observation.UNMET, Observation.NAMELESS, Observation.UNSEEN]
	var unnamed := 0
	for row in view.aims:
		var entry := row as Dictionary
		not_equal(String(entry["label"]), "",
			"nothing should be offered with nothing to call it")
		not_equal(String(entry["type"]), "",
			"every row should say what sort of thing it is, in the packet's word")
		var why := String(entry["unnamed"])
		if why != "":
			unnamed += 1
			check(reasons.has(why),
				"a nameless row should carry the packet's own reason, not '%s'" % why)
		var line := PlayerControls.row_line(entry)
		check(line.contains(String(entry["type"])),
			"the line for %s should say what sort of thing it is" % entry["id"])
		check(line.contains(why if why != "" else String(entry["label"])),
			"the line for %s should say its name or why it has none" % entry["id"])
		# And no gap where something was left out: two spaces in a row is what a
		# missing field looked like.
		check(not line.contains("  "),
			"the line for %s should have nothing missing out of it: %s" % [
				entry["id"], line,
			])
	check(unnamed > 0,
		"the scenario should hold somebody this character has not met")

	# The reason really is the packet's: a character that has met the stranger
	# knows its name, and the row stops carrying a reason at all.
	var stranger := 0
	for row in view.aims:
		if String((row as Dictionary)["unnamed"]) == Observation.UNMET \
				and String((row as Dictionary)["kind"]) == Surroundings.CHARACTER:
			stranger = int((row as Dictionary)["id"])
			break
	if stranger != 0:
		# The world's own record that something passed between them -- a line
		# heard, which is one of the four things that make an edge -- rather than
		# anything written on either sheet.
		world.combat.scene.relationships.heard(stranger, id, "well met", false)
		var known := world.surroundings_of(id).aim_of(stranger)
		equal(String(known["unnamed"]), "",
			"a character that has been met should be offered by name")
		not_equal(String(known["label"]), Surroundings.ANONYMOUS % stranger,
			"a character that has been met should be called something")


# --- The driver -----------------------------------------------------------


# Press one key, put whatever it chose in the holder, and live the world until
# the engine has answered it. Returns the row that was written down, or an empty
# dictionary for a key that only picked something.
static func _press(run: Dictionary, keycode: int) -> Dictionary:
	var world: SimWorld = run["world"]
	var id: int = run["id"]
	var controls: PlayerControls = run["controls"]
	var chosen := controls.press(keycode, world.surroundings_of(id))
	if chosen == null:
		if controls.note != "":
			(run["notes"] as PackedStringArray).append(
				"t=%d %s" % [world.tick, controls.note])
		return {}
	(run["choice"] as LiveChoice).choose(chosen)
	var was := int((world.loop.answer_of(id) as Dictionary).get("tick", -1))
	for _tick in PATIENCE:
		world.step()
		var answer := world.loop.answer_of(id)
		if answer.is_empty() or int(answer["tick"]) == was:
			continue
		var row := {
			"verb": chosen.kind,
			"tick": int(answer["tick"]),
			"at": _target_line(chosen),
			"answer": String(answer["line"]),
			"reason": String(answer["reason"]),
			"ok": bool(answer["ok"]),
		}
		(run["table"] as Array).append(row)
		return row
	return {}


# Let the world alone for a while, so that everybody else takes their turns.
static func _breathe(run: Dictionary, ticks: int) -> void:
	var world: SimWorld = run["world"]
	for _tick in maxi(0, ticks):
		world.step()


# Live the world until a fight is on, or until the run gives up waiting.
static func _breathe_until_fighting(run: Dictionary, ticks: int) -> bool:
	var world: SimWorld = run["world"]
	for _tick in maxi(0, ticks):
		if world.combat.phase() != CombatantRoster.REAL_TIME:
			return true
		world.step()
	return world.combat.phase() != CombatantRoster.REAL_TIME


# Aim at the thing with this id, by pressing the aim key until it comes round.
static func _aim_at_id(run: Dictionary, id: int) -> bool:
	var world: SimWorld = run["world"]
	var controls: PlayerControls = run["controls"]
	var view := world.surroundings_of(int(run["id"]))
	for _each in view.aims.size() + 1:
		controls.press(PlayerControls.KEY_AIM, view)
		if controls.aimed_id == id:
			return true
	return false


# Aim at the thing with this label, by pressing the aim key until it comes
# round. Nothing happens if there is no such thing in sight.
static func _aim_at(run: Dictionary, label: String) -> bool:
	var world: SimWorld = run["world"]
	var controls: PlayerControls = run["controls"]
	var view := world.surroundings_of(int(run["id"]))
	for _each in view.aims.size() + 1:
		controls.press(PlayerControls.KEY_AIM, view)
		var row := view.aim_of(controls.aimed_id)
		if not row.is_empty() and String(row["label"]) == label:
			return true
	return false


# Hold the thing of this name, by pressing the hold key until it comes round.
static func _hold(run: Dictionary, called: String) -> bool:
	var world: SimWorld = run["world"]
	var controls: PlayerControls = run["controls"]
	var view := world.surroundings_of(int(run["id"]))
	for _each in view.carrying.size() + 2:
		controls.press(PlayerControls.KEY_HOLD, view)
		if controls.holding == called:
			return true
	return false


# Pick the thing of this name out of whatever is aimed at.
static func _take(run: Dictionary, called: String) -> bool:
	var world: SimWorld = run["world"]
	var controls: PlayerControls = run["controls"]
	var view := world.surroundings_of(int(run["id"]))
	var inside := PlayerControls.inside_of(view, controls.aimed_id)
	for _each in inside.size() + 1:
		if controls.taking == called:
			return true
		controls.press(PlayerControls.KEY_INSIDE, view)
	return controls.taking == called


## The table one played run wrote down, as lines: the verb, the tick, what it
## was aimed at and what the engine answered.
static func table_lines(run: Dictionary) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("%-14s %5s  %-22s %s" % ["verb", "tick", "at", "the engine's answer"])
	for row in run.get("table", []):
		written.append("%-14s %5d  %-22s %s" % [
			String(row["verb"]), int(row["tick"]), String(row["at"]),
			String(row["answer"]),
		])
	return written


# What an action was aimed at, in one short field: a position, a name, or an id
# with whatever item the action carries.
static func _target_line(action: Action) -> String:
	var written := ""
	if action.names_an_offset():
		var step := action.offset()
		written = "offset (%+.1f, %+.1f)" % [step.x, step.y]
	elif action.targets_a_position():
		var to := action.target_position()
		written = "(%.1f, %.1f)" % [to.x, to.y]
	elif action.targets_a_name():
		written = action.target_name()
	elif action.target_id() != ActionCatalog.NOBODY:
		written = "#%d" % action.target_id()
	else:
		written = "-"
	var item: Variant = action.param("item", "")
	if item is String and String(item) != "":
		written += " with %s" % item
	return written


## What a caller does with an action once it has one, as opposed to how it makes
## one. Reading a chosen action is not choosing one, so these are skipped by the
## scan below; `of` is not among them and is caught separately, because it takes
## any name at all and is how a thirteenth verb would get in.
const ACTION_READERS := [
	"line", "param", "target_id", "target_position", "target_name",
	"targets_a_position", "targets_a_name", "names_an_offset", "offset",
	"new", "constructors",
]


# Which actions a file builds, by the constructors it names.
static func _actions_built_in(code: String) -> PackedStringArray:
	var built := PackedStringArray()
	for piece in code.split("Action."):
		var at := piece.find("(")
		if at <= 0:
			continue
		var named := piece.substr(0, at)
		if not named.is_valid_identifier() or ACTION_READERS.has(named):
			continue
		if not built.has(named):
			built.append(named)
	return built


## A file's source with the comments taken off, so that prose discussing a rule
## is not read as code holding one. String literals are kept, for the reason
## `LayerCheck` keeps them.
static func _code_of(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return ""
	var kept := PackedStringArray()
	for line in text.split("\n"):
		var at := line.find("#")
		kept.append(line if at < 0 else line.substr(0, at))
	return "\n".join(kept)


# --- 7: the keyboard refuses nothing the world allows -----------------------


## The one choice a person could not make and everybody else could.
##
## Pressing the attack key with nothing in hand used to be answered by
## `render/player_controls.gd` with a sentence of its own, and no action was ever
## built -- while the same choice handed to the simulation directly began an
## unarmed fight. So this is played twice off one seed: once with the choice
## built by the attack key, once with the same choice taken off the catalogue by
## hand, and the two runs are compared. Nothing else differs between them.
##
## Hob is the target because he stands six units from the person at the start,
## well inside `Encounter.JOIN_RADIUS`, and is of the same band -- so no fight has
## begun by itself and the blow is the thing that starts one.
func _the_keyboard_refuses_nothing_the_world_allows() -> void:
	var by_key := _unarmed_blow(true)
	var by_hand := _unarmed_blow(false)

	equal(String(by_key["note"]), "",
		"the attack key wrote a refusal of its own: %s" % by_key["note"])
	var pressed: Action = by_key["action"]
	check(pressed != null,
		"the attack key built no action for a blow the world allows")
	if pressed == null:
		return
	var taken: Action = by_hand["action"]
	equal(pressed.kind, taken.kind, "the key should build the catalogue's verb")
	equal(pressed.target_id(), taken.target_id(),
		"the key should aim the blow at who was aimed at")
	equal(String(pressed.param("item", "")), String(taken.param("item", "")),
		"bare hands from the keys should be the bare hands the catalogue takes")

	var key_answer: Dictionary = by_key["answer"]
	var hand_answer: Dictionary = by_hand["answer"]
	check(not key_answer.is_empty(),
		"the world never answered the blow chosen from the keys")
	check(not hand_answer.is_empty(),
		"the world never answered the blow chosen off the catalogue")
	if key_answer.is_empty() or hand_answer.is_empty():
		return
	equal(String(key_answer["line"]), String(hand_answer["line"]),
		"the same choice made two ways should reach one answer")
	check(bool(key_answer["ok"]),
		"an unarmed blow the world allows was refused: %s" % key_answer["line"])
	check(String(key_answer["line"]).contains("fight"),
		"an unarmed blow should have begun a fight: %s" % key_answer["line"])


# Play one seeded world up to a single unarmed blow at Hob and hand back what
# was chosen, what the interface said about it, and what the world answered.
# `from_the_keys` is the only difference between the two runs.
static func _unarmed_blow(from_the_keys: bool) -> Dictionary:
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var id := world.follow_id
	var choice := WorldCast.hand_over(world, id)
	var hob := ScriptedPlay.id_of(world.combat.scene, HOB)
	var made := {"action": null, "note": "", "answer": {}}
	if choice == null or hob == 0:
		return made

	if from_the_keys:
		var controls := PlayerControls.new()
		var view := world.surroundings_of(id)
		for _each in view.aims.size() + 1:
			controls.press(PlayerControls.KEY_AIM, view)
			if controls.aimed_id == hob:
				break
		# Nothing in hand, which is where the hold ring starts and is a choice.
		made["action"] = controls.press(
			PlayerControls.KEY_ATTACK, world.surroundings_of(id))
		made["note"] = controls.note
	else:
		made["action"] = Action.attack(hob, PlayerControls.EMPTY_HANDS)
	if made["action"] == null:
		return made

	choice.choose(made["action"])
	var was := int((world.loop.answer_of(id) as Dictionary).get("tick", -1))
	for _tick in PATIENCE:
		world.step()
		var answer := world.loop.answer_of(id)
		if answer.is_empty() or int(answer["tick"]) == was:
			continue
		made["answer"] = answer
		return made
	return made


## One condition, one wording, and one copy of it in the tree.
##
## The sentence is `CombatResolution.empty_handed`, which is where a weapon
## action is actually spent. It is written in one file and quoted everywhere
## else; the two sentences that used to answer the same situation -- the attack
## key's own, and `no such attack` for a commander holding nothing -- are gone.
##
## `no such attack` itself is still in the tree and is meant to be: it now
## answers a different question, which is a weapon asked for an attack it does
## not have.
func _one_condition_has_one_wording() -> void:
	var wording := CombatResolution.empty_handed("").strip_edges()
	check(wording != "", "the empty-handed sentence should not be empty")
	var carrying := PackedStringArray()
	var inventing := PackedStringArray()
	for directory in [LayerCheck.SIM_DIR, LayerCheck.RENDER_DIR]:
		for path in LayerCheck._files_under(directory):
			var code := FileAccess.get_file_as_string(path)
			if code.contains(wording):
				carrying.append(path)
			if code.contains("holding nothing to attack with"):
				inventing.append(path)
	equal(carrying.size(), 1,
		"the empty-handed sentence should be written in one file, found it in: %s"
			% str(carrying))
	equal(inventing.size(), 0,
		"a second sentence for the same condition is still in the tree: %s"
			% str(inventing))
