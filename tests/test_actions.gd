extends TestSuite
## The atomic action set, tested as the interface a language model will later be
## handed -- which means tested without one.
##
## Six claims:
##
##   1. **Every action section 2.1 lists exists and is callable.** Not "the
##      catalogue names them" -- each one is chosen and resolved on a real
##      scene and the world change it made is asserted, including the variants
##      section 2.1 spells out: going to a position, an item and a character;
##      saying targeted and shouted; trading proposed, accepted and denied;
##      dropping on the ground and into a chest.
##   1a. **`go to` names a place in either of two spaces.** Section 10 spells the
##      row `MoveRelative(offset)` as well as `MoveTo(position)`, so the row takes
##      `target` or `offset` and exactly one of them; the same offset resolved for
##      two characters standing apart lands in two different places, and a person
##      at a keyboard reaches the same shape through the walk keys.
##   2. **Section 2.1's list and section 10's call surface are one list.** The
##      check is `ActionCatalog.faults()`, run over the real table and then over
##      six deliberately broken copies of it, each of which it must catch.
##   3. **Any action may fail and says why.** Every one of them is made to
##      fail; the four the acceptance names are checked against their exact
##      sentences.
##   4. **The engine resolves and the caller only chooses.** The action
##      implementations are read off disk and nothing in them asks who is
##      calling; the same scan is then run over a control line that does ask, and
##      must catch it.
##   5. **A person's decision function and a program's drive the identical
##      surface**, shown by the same choice through each producing the same world
##      change -- one fingerprint, compared.
##   6. **A choice the catalogue cannot read costs the character one turn.** It
##      is counted as an action attempted and refused in the catalogue's own
##      words; the four refusals that are about the world rather than the choice
##      are counted for nobody; and a plan, a person and a model each move on to
##      their next choice rather than offering the refused one back forever.
##      Nothing outside `ActionScene` keeps that count, which is scanned for
##      rather than promised.
##   7. **Two processes agree** on `./run_actions.sh`, so nothing in the layer
##      reads a clock, a random number or an address.
class_name TestActions

## The files that implement the action surface. `sim/decision_source.gd` is
## deliberately *not* among them: it is the caller's side of the line, and it is
## where the words "recorded" and "scripted" are allowed to be. The claim is
## about what resolves an action, not about what chooses one.
const IMPLEMENTATION := [
	"res://sim/action.gd",
	"res://sim/action_catalog.gd",
	"res://sim/action_engine.gd",
	"res://sim/action_outcome.gd",
	"res://sim/action_scene.gd",
]

## How a line of code would ask who is calling it. Whole words, so `fail` is not
## read as `ai` and `character` is not read as `act`.
const WHO_IS_CALLING := (
	"player|human|npc|agent|llm|bot|user|caller|owner_kind"
	+ "|is_player|is_human|controlled_by|driven_by|decide|decides"
	+ "|scripted|recorded"
)

## The line that would break claim 4 if it were in the engine, and which the scan
## must catch to be worth anything.
const BROKEN_CONTROL := "	if actor.is_player():"

## A line that is really in the engine, which the scan must not catch.
const HONEST_CONTROL := "	var sheet := _sheet_of(actor)"

## What the two characters in the bare test scene carry.
const PICK := "lockpick"
const HATCHET := "worn hatchet"
const BOOTS := "leather boots"
const DRAUGHT := "mending draught"

## Where the two of them stand in the bare scene, and where the furniture is.
## No terrain: a bare stage, so a walk is arithmetic and nothing about the
## world's fields can move a number in this suite.
const ROOK_AT := Vector2(0.0, 0.0)
const WREN_AT := Vector2(2.0, 0.0)
const PILE_AT := Vector2(10.0, 0.0)
const CHEST_AT := Vector2(-10.0, 0.0)

## How long the three minds are run for when each is handed a faulted choice and
## a good one: long enough for both to be resolved and reviewed several times.
const MIND_TICKS := 40

## Rook's dexterity in the bare scene, and the two jumps measured against it:
## `ActionEngine.JUMP_BASE + 4 x JUMP_PER_DEX` is 4.5.
const ROOK_DEX := 4
const JUMP_REACH := 4.5


func _init() -> void:
	suite_name = "actions"


func run() -> void:
	_every_action_exists_and_is_callable()
	_the_variants_section_2_1_names_are_callable()
	_a_place_can_be_named_in_either_space()
	_the_two_lists_are_one_list()
	_the_one_list_check_would_notice()
	_every_action_can_fail_and_says_why()
	_the_four_worked_refusals()
	_nothing_asks_who_is_calling()
	_the_who_is_calling_scan_would_notice()
	_every_resolver_takes_the_same_three_things()
	_two_minds_one_surface()
	_a_recorded_person_stops_when_the_list_runs_out()
	_a_refused_choice_is_a_turn_spent()
	_every_mind_moves_on_from_a_line_the_catalogue_faults()
	_nothing_outside_the_scene_counts_an_action()
	_two_processes_agree()


# --- 1. Every action exists and is callable -------------------------------


## Each row is chosen and resolved, and the world change is asserted.
##
## The catalogue is walked rather than a list written here, so an action added to
## the table with nothing to exercise it fails this test by leaving its name
## unticked.
func _every_action_exists_and_is_callable() -> void:
	equal(ActionCatalog.names().size(), 15,
		"the catalogue has section 2.1's twelve rows and the three the wardrobe added")
	var exercised := {}

	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var wren: Combatant = scene.actors[1]
	var pile: WorldObject = scene.objects[0]
	var chest: WorldObject = scene.objects[1]

	# go to a character, and arrive within reach of them.
	var walked := ActionEngine.resolve(scene, rook, Action.go_to(wren.id))
	check(walked.ok, "go to a character: %s" % walked.reason)
	check(rook.distance_to(wren) <= ActionEngine.REACH,
		"and it arrived within reach (%.2f)" % rook.distance_to(wren))
	exercised[ActionCatalog.GO_TO] = true

	# jump, inside what DEX allows.
	var here := Vector2(rook.x, rook.z)
	var jumped := ActionEngine.resolve(scene, rook, Action.jump(here + Vector2(3.0, 0.0)))
	check(jumped.ok, "jump: %s" % jumped.reason)
	equal(snappedf(rook.x, 0.001), snappedf(here.x + 3.0, 0.001),
		"and it landed where it aimed")
	exercised[ActionCatalog.JUMP] = true

	# say, at somebody.
	var spoke := ActionEngine.resolve(scene, rook, Action.say("well met", wren.id))
	check(spoke.ok, "say: %s" % spoke.reason)
	equal(scene.said.size(), 1, "and it was written down")
	exercised[ActionCatalog.SAY] = true

	# pick up, off the ground.
	ActionEngine.resolve(scene, rook, Action.go_to(pile.id))
	var took := ActionEngine.resolve(scene, rook, Action.pick_up(HATCHET))
	check(took.ok, "pick up: %s" % took.reason)
	check(_carries(rook, HATCHET), "and the hatchet is carried")
	check(scene.object_of(pile.id) == null, "and the emptied pile is gone")
	exercised[ActionCatalog.PICK_UP] = true

	# drop, on the ground.
	var dropped := ActionEngine.resolve(scene, rook, Action.drop(HATCHET))
	check(dropped.ok, "drop: %s" % dropped.reason)
	check(not _carries(rook, HATCHET), "and the hatchet is no longer carried")
	exercised[ActionCatalog.DROP] = true

	# examine, something in sight.
	var looked := ActionEngine.resolve(scene, rook, Action.examine(wren.id))
	check(looked.ok, "examine: %s" % looked.reason)
	equal(looked.got("name"), "Wren", "and it saw who it was looking at")
	equal(looked.got("health"), "unhurt", "and how hurt they looked")
	exercised[ActionCatalog.EXAMINE] = true

	# interact, with the item it needs.
	ActionEngine.resolve(scene, rook, Action.go_to(chest.id))
	var worked := ActionEngine.resolve(scene, rook, Action.interact(chest.id, PICK))
	check(worked.ok, "interact: %s" % worked.reason)
	check(chest.is_open(), "and the chest is open")
	exercised[ActionCatalog.INTERACT] = true

	# trade: propose, deny, propose again, accept.
	ActionEngine.resolve(scene, rook, Action.go_to(wren.id))
	var offered := ActionEngine.resolve(scene, rook, Action.trade_propose(
		wren.id, PackedStringArray([PICK]), 4, PackedStringArray([BOOTS]), 0))
	check(offered.ok, "trade propose: %s" % offered.reason)
	equal(scene.offers.size(), 1, "and the offer is on the table")
	exercised[ActionCatalog.TRADE_PROPOSE] = true

	var denied := ActionEngine.resolve(scene, wren, Action.trade_deny(rook.id))
	check(denied.ok, "trade deny: %s" % denied.reason)
	equal(scene.offers.size(), 0, "and the offer is off the table")
	exercised[ActionCatalog.TRADE_DENY] = true

	ActionEngine.resolve(scene, rook, Action.trade_propose(
		wren.id, PackedStringArray([PICK]), 4, PackedStringArray([BOOTS]), 0))
	var money_before := ActionScene.inventory_of(wren).money
	var accepted := ActionEngine.resolve(scene, wren, Action.trade_accept(rook.id))
	check(accepted.ok, "trade accept: %s" % accepted.reason)
	check(_carries(wren, PICK), "and the lockpick changed hands")
	check(_carries(rook, BOOTS), "and the boots came back the other way")
	equal(ActionScene.inventory_of(wren).money, money_before + 4,
		"and the money moved with them")
	exercised[ActionCatalog.TRADE_ACCEPT] = true

	# equip, and take it off again: the boots that came back across the table are
	# worn, which changes what the wearer can do, and taking them off puts that
	# back without dropping them.
	var bare := (rook.piece as Commander).loadout_line()
	var put_on := ActionEngine.resolve(scene, rook, Action.equip(BOOTS))
	check(put_on.ok, "equip: %s" % put_on.reason)
	check(ActionScene.inventory_of(rook).armour_in(Item.SLOT_BOOTS) != null,
		"and they are on")
	not_equal((rook.piece as Commander).loadout_line(), bare,
		"and the loadout is not what it was")
	exercised[ActionCatalog.EQUIP] = true

	var took_off := ActionEngine.resolve(scene, rook, Action.unequip(BOOTS))
	check(took_off.ok, "unequip: %s" % took_off.reason)
	equal(ActionScene.inventory_of(rook).armour_in(Item.SLOT_BOOTS), null,
		"and they are off")
	check(_carries(rook, BOOTS), "and still carried")
	equal((rook.piece as Commander).loadout_line(), bare,
		"and the loadout is back where it was")
	exercised[ActionCatalog.UNEQUIP] = true

	# use: a draught, which is the one sort of thing that is used up. Rook is put
	# a few points down first, because a draught mends what is missing.
	var draught := Item.consumable(
		DRAUGHT, 4, ItemRarity.COMMON, Ability.CON, [DRAUGHT] as Array[String])
	ActionScene.inventory_of(rook).carry(draught)
	rook.piece.health = rook.piece.max_health() - 3
	var drunk := ActionEngine.resolve(scene, rook, Action.use(DRAUGHT))
	check(drunk.ok, "use: %s" % drunk.reason)
	equal(drunk.got("mended"), 3, "and it mended what was missing")
	equal(rook.piece.health, rook.piece.max_health(), "and the character is whole")
	check(not _carries(rook, DRAUGHT), "and the draught is gone")
	exercised[ActionCatalog.USE] = true

	# wait.
	var waited := ActionEngine.resolve(scene, rook, Action.wait(5))
	check(waited.ok, "wait: %s" % waited.reason)
	equal(scene.idle_of(rook.id), scene.tick + 5, "and it is idle until then")
	exercised[ActionCatalog.WAIT] = true

	# attack, on a board, which is the one action that needs a fight under way.
	exercised[ActionCatalog.ATTACK] = _an_attack_lands()

	for action_name in ActionCatalog.names():
		check(exercised.has(action_name), "%s was called in this suite" % action_name)


## The one action that reaches the board: two commanders, a fight, and a spear.
##
## Returns whether it landed, so the sweep above can tick `attack` off the
## catalogue with the same evidence the acceptance asks for.
func _an_attack_lands() -> bool:
	var lines := ScriptedActions.duel()
	var refused := ""
	var landed := ""
	for line in lines:
		if line.contains("common bow"):
			refused = line
		if line.contains("common spear"):
			landed = line
	check(refused.contains("outside the pattern"),
		"a bow's ring cannot reach a target two cells away: %s" % refused)
	check(landed.contains("attack ok"), "a spear can: %s" % landed)
	check(landed.contains("dealt="), "and the blow dealt damage: %s" % landed)
	return landed.contains("attack ok")


# --- The variants section 2.1 spells out ----------------------------------


## Section 2.1 names more calls than rows: it names the *shapes* of some of
## them. Each shape is exercised here.
func _the_variants_section_2_1_names_are_callable() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var wren: Combatant = scene.actors[1]
	var pile: WorldObject = scene.objects[0]
	var chest: WorldObject = scene.objects[1]

	# "go to (position / item / character)" -- all three.
	var to_place := ActionEngine.resolve(scene, rook, Action.go_to(Vector2(4.0, 3.0)))
	check(to_place.ok, "go to a position: %s" % to_place.reason)
	check(Vector2(rook.x, rook.z).distance_to(Vector2(4.0, 3.0)) <= ActionEngine.ARRIVE,
		"and it arrived at it")
	var to_item := ActionEngine.resolve(scene, rook, Action.go_to(pile.id))
	check(to_item.ok, "go to an item: %s" % to_item.reason)
	var to_person := ActionEngine.resolve(scene, rook, Action.go_to(wren.id))
	check(to_person.ok, "go to a character: %s" % to_person.reason)

	# "say (text; targeted, or shout -> everyone in range hears)" -- both.
	var shouted := ActionEngine.resolve(scene, rook, Action.say("hoy"))
	check(shouted.ok, "shout: %s" % shouted.reason)
	equal(shouted.got("shout"), true, "and it went out as a shout")
	equal(shouted.got("heard_by"), 1, "and everyone in range heard it")
	var told := ActionEngine.resolve(scene, rook, Action.say("hoy", wren.id))
	equal(told.got("shout"), false, "a targeted line is not a shout")

	# "drop (ground or chest)" -- both.
	ActionEngine.resolve(scene, rook, Action.go_to(pile.id))
	ActionEngine.resolve(scene, rook, Action.pick_up(HATCHET))
	var to_ground := ActionEngine.resolve(scene, rook, Action.drop(HATCHET))
	check(to_ground.ok, "drop on the ground: %s" % to_ground.reason)
	var ground_pile := scene.object_of(to_ground.got("into"))
	check(ground_pile != null and ground_pile.pile, "and it made a pile where it stood")

	ActionEngine.resolve(scene, rook, Action.pick_up(HATCHET))
	ActionEngine.resolve(scene, rook, Action.go_to(chest.id))
	ActionEngine.resolve(scene, rook, Action.interact(chest.id, PICK))
	var to_chest := ActionEngine.resolve(scene, rook, Action.drop(HATCHET, chest.id))
	check(to_chest.ok, "drop into a chest: %s" % to_chest.reason)
	check(_holds(chest, HATCHET), "and the chest holds it")

	# "pick up (ground or chest)" -- the chest half; the ground half is above.
	var out_of_chest := ActionEngine.resolve(scene, rook, Action.pick_up(HATCHET, chest.id))
	check(out_of_chest.ok, "pick up out of a chest: %s" % out_of_chest.reason)
	check(_carries(rook, HATCHET), "and it is carried again")

	# "trade ... items + money in/out" -- both directions at once, and a gift,
	# which section 2.1 defines as a trade with nothing in return.
	ActionEngine.resolve(scene, rook, Action.go_to(wren.id))
	ActionEngine.resolve(scene, rook, Action.trade_propose(
		wren.id, PackedStringArray([HATCHET]), 0, PackedStringArray(), 0))
	var gift := ActionEngine.resolve(scene, wren, Action.trade_accept(rook.id))
	check(gift.ok, "a gift is a trade with nothing in return: %s" % gift.reason)
	check(_carries(wren, HATCHET) and not _carries(rook, HATCHET), "and it changed hands")

	# "examine (an item/person in sight)" -- an item carried, as well as a person.
	var at_item := ActionEngine.resolve(scene, rook, Action.examine(PICK))
	check(at_item.ok, "examine something carried: %s" % at_item.reason)
	check(String(at_item.got("seen", "")).contains(PICK), "and it saw what it was")


# --- The two spaces a place can be named in --------------------------------


## `go to` takes a world position or an offset from where the character stands,
## and exactly one of the two.
##
## The gap this closes was measured rather than guessed: `tools/position_space_probe.sh`
## replays the shipped model run and prints every position a model named beside
## how far it was from the character that named it. The packet says where the
## looker is standing in world coordinates and says everything else as an offset
## from it, so both readings of a pair of numbers are reasonable and only one of
## them was sayable. Now both are, and which is meant is the name of the key.
func _a_place_can_be_named_in_either_space() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var wren: Combatant = scene.actors[1]

	# The offset is measured from where the character is standing, so the same
	# offset takes two characters standing apart to two different places. No
	# character is privileged: it is one row of the one list.
	var step := Vector2(3.0, 4.0)
	var rook_from := Vector2(rook.x, rook.z)
	var wren_from := Vector2(wren.x, wren.z)
	var rook_went := ActionEngine.resolve(scene, rook, Action.go_to_offset(step))
	check(rook_went.ok, "go to an offset: %s" % rook_went.reason)
	check(Vector2(rook.x, rook.z).distance_to(rook_from + step) <= ActionEngine.ARRIVE,
		"and it arrived at where it stood plus the offset")
	var wren_went := ActionEngine.resolve(scene, wren, Action.go_to_offset(step))
	check(wren_went.ok, "the same offset for somebody else: %s" % wren_went.reason)
	check(Vector2(wren.x, wren.z).distance_to(wren_from + step) <= ActionEngine.ARRIVE,
		"and it arrived at where *it* stood plus the offset")
	check(rook_from + step != wren_from + step,
		"two characters standing apart went to two different places")

	# The same two numbers under the other key are a place in the world, and the
	# two readings are as far apart as the character is from the origin.
	var here := Vector2(rook.x, rook.z)
	ActionEngine.resolve(scene, rook, Action.go_to(here + Vector2(20.0, 0.0)))
	var stood := Vector2(rook.x, rook.z)
	var as_world := ActionEngine.resolve(scene, rook, Action.go_to(step))
	check(as_world.ok, "the same numbers as a target: %s" % as_world.reason)
	check(Vector2(rook.x, rook.z).distance_to(step) <= ActionEngine.ARRIVE,
		"and it went to the world position rather than the offset")
	check(stood.distance_to(step) > (stood + step).distance_to(stood),
		"the two readings are two different walks")

	# Exactly one of the two keys. Both, or neither, is a fault of the choice --
	# refused by the catalogue before the world is consulted at all.
	equal(ActionCatalog.fault(Action.of(ActionCatalog.GO_TO, {})),
		"go_to needs target or offset", "a go_to naming no place is refused")
	equal(ActionCatalog.fault(Action.of(ActionCatalog.GO_TO,
			{"target": wren.id, "offset": step})),
		"go_to takes target or offset, not both",
		"a go_to naming a place twice is refused")
	equal(ActionCatalog.fault(Action.of(ActionCatalog.GO_TO, {"offset": wren.id})),
		"go_to's offset must be an offset", "an id under offset is refused")
	equal(ActionCatalog.fault(Action.go_to_offset(step)), "",
		"and the offset shape itself is clean")

	# It is on the surface a model is handed, in the catalogue's own words, and
	# a reply written in it reads back as that action.
	var menu := ModelPrompt.menu_lines()
	var shapes := 0
	for line in menu:
		if line.strip_edges().begins_with(ActionCatalog.GO_TO + " "):
			shapes += 1
	equal(shapes, 2, "go_to is on the menu once per shape")
	check(" ".join(menu).contains(
			"offset=%s" % ModelPrompt.SORT_FORMS[ActionCatalog.OFFSET]),
		"the menu offers the offset shape: %s" % " ".join(menu))
	var read_back := ModelPrompt.action_of("go_to offset=(+2.0, -6.0)")
	check(read_back != null and read_back.kind == ActionCatalog.GO_TO,
		"a reply naming an offset reads back as a go_to")
	check(read_back.names_an_offset(), "and it reads back as an offset")
	equal(read_back.offset(), Vector2(2.0, -6.0), "and the offset is what was written")
	equal(ActionCatalog.fault(read_back), "", "and the catalogue takes it")

	# And a person at a keyboard reaches the same shape: a walk key is a
	# direction and a length, which is exactly what an offset is.
	var pressed := PlayerControls.walk(PlayerControls.direction_of(KEY_W))
	check(pressed != null and pressed.kind == ActionCatalog.GO_TO,
		"a walk key builds a go_to")
	check(pressed.names_an_offset(), "and it names its step as an offset")
	equal(ActionCatalog.fault(pressed), "", "and the catalogue takes that too")


# --- 2. One list ----------------------------------------------------------


## The table and the two files implementing it agree, with nothing left over on
## any side.
func _the_two_lists_are_one_list() -> void:
	var faults := ActionCatalog.faults(
		ActionCatalog.ROWS,
		PackedStringArray(Action.constructors().keys()),
		PackedStringArray(ActionEngine.resolvers().keys()))
	equal(faults, PackedStringArray(),
		"the one list, what can choose from it and what resolves it all agree")

	equal(PackedStringArray(Action.constructors().keys()), ActionCatalog.names(),
		"there is one constructor per row, in the row order")
	# And a constructor that builds a second shape of a row names the row it
	# builds, so the extras cannot become a thirteenth verb by the back door.
	for shape in Action.shapes():
		check(ActionCatalog.is_action(String(Action.shapes()[shape])),
			"the shape %s builds an action the catalogue lists" % shape)
		check(not ActionCatalog.names().has(shape),
			"the shape %s is not itself a row" % shape)
	equal(PackedStringArray(ActionEngine.resolvers().keys()), ActionCatalog.names(),
		"there is one resolver per row, in the row order")

	# Every call-surface name resolves to exactly one action, and every action
	# has at least one call name. Neither column of the table can be blank.
	var call_names := ActionCatalog.call_names()
	check(call_names.size() >= ActionCatalog.names().size(),
		"the call surface is at least as long as the action list (%d names)" % call_names.size())
	for spelling in call_names:
		check(ActionCatalog.is_action(ActionCatalog.action_for_call(spelling)),
			"%s resolves to an action" % spelling)
	for action_name in ActionCatalog.names():
		var row := ActionCatalog.row_of(action_name)
		check(not PackedStringArray(row["calls"]).is_empty(),
			"%s has a call-surface name" % action_name)
		check(String(row["listed"]).strip_edges() != "",
			"%s quotes section 2.1" % action_name)

	# Section 10's own spellings are in the table, so the reconciliation really
	# did absorb that list rather than replace it with new words.
	for spelling in ["MoveTo", "MoveRelative", "Roam", "Flee", "Talk",
			"ProposeTrade", "AcceptTrade", "DenyTrade", "ViewInventory", "Take",
			"Drop", "AccessInventory", "Attack", "Interact", "Query"]:
		check(call_names.has(spelling), "section 10's %s is in the one list" % spelling)


## The check has teeth: six broken tables, and each break is caught.
##
## Every one of these is a way the two lists could drift apart if they were
## written down twice, which is exactly why they are not.
func _the_one_list_check_would_notice() -> void:
	var good_constructors := PackedStringArray(Action.constructors().keys())
	var good_resolvers := PackedStringArray(ActionEngine.resolvers().keys())

	var no_call := _rows_with({"name": "go_to", "calls": []})
	check(not ActionCatalog.faults(no_call, good_constructors, good_resolvers).is_empty(),
		"a row with no call-surface name is caught")

	var no_wording := _rows_with({"name": "jump", "listed": ""})
	check(not ActionCatalog.faults(no_wording, good_constructors, good_resolvers).is_empty(),
		"a row with no section 2.1 wording is caught")

	var shared := _rows_with({"name": "jump", "calls": ["Attack"]})
	check(not ActionCatalog.faults(shared, good_constructors, good_resolvers).is_empty(),
		"one call name on two rows is caught")

	var lonely := _rows_with({"name": "go_to", "either": {"target": ActionCatalog.ID}})
	check(not ActionCatalog.faults(lonely, good_constructors, good_resolvers).is_empty(),
		"a row wanting one of a group of one is caught")

	var twice := _rows_with({
		"name": "go_to",
		"params": {"target": ActionCatalog.ID_OR_POSITION},
		"either": {"target": ActionCatalog.ID_OR_POSITION, "offset": ActionCatalog.OFFSET},
	})
	check(not ActionCatalog.faults(twice, good_constructors, good_resolvers).is_empty(),
		"a row declaring one parameter twice is caught")

	var extra_row := ActionCatalog.ROWS.duplicate(true)
	extra_row.append({
		"name": "sing", "listed": "sing", "calls": ["Sing"],
		"params": {}, "optional": {},
	})
	check(not ActionCatalog.faults(extra_row, good_constructors, good_resolvers).is_empty(),
		"an action nothing can choose or resolve is caught")

	var short_constructors := good_constructors.duplicate()
	short_constructors.remove_at(short_constructors.find(ActionCatalog.WAIT))
	check(not ActionCatalog.faults(
			ActionCatalog.ROWS, short_constructors, good_resolvers).is_empty(),
		"a listed action with no constructor is caught")

	var long_resolvers := good_resolvers.duplicate()
	long_resolvers.append("teleport")
	check(not ActionCatalog.faults(
			ActionCatalog.ROWS, good_constructors, long_resolvers).is_empty(),
		"a resolver for something that is not an action is caught")

	# And the unbroken table still passes, so the six above are the breaks and
	# not the checker being permanently unhappy.
	equal(ActionCatalog.faults(ActionCatalog.ROWS, good_constructors, good_resolvers),
		PackedStringArray(), "the real table is still clean")


# --- 3. Any action may fail, and says why ---------------------------------


## Every row is made to fail, and every refusal carries a sentence.
func _every_action_can_fail_and_says_why() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var wren: Combatant = scene.actors[1]
	var chest: WorldObject = scene.objects[1]
	var nobody := 999

	var refusals := {
		ActionCatalog.GO_TO: Action.go_to(nobody),
		ActionCatalog.JUMP: Action.jump(Vector2(500.0, 500.0)),
		ActionCatalog.ATTACK: Action.attack(wren.id, PICK),
		ActionCatalog.SAY: Action.say("   "),
		ActionCatalog.TRADE_PROPOSE: Action.trade_propose(nobody),
		ActionCatalog.TRADE_ACCEPT: Action.trade_accept(wren.id),
		ActionCatalog.TRADE_DENY: Action.trade_deny(wren.id),
		ActionCatalog.PICK_UP: Action.pick_up("a crown"),
		ActionCatalog.DROP: Action.drop("a crown"),
		ActionCatalog.EXAMINE: Action.examine(nobody),
		ActionCatalog.INTERACT: Action.interact(chest.id),
		ActionCatalog.WAIT: Action.wait(0),
		ActionCatalog.EQUIP: Action.equip("a crown"),
		ActionCatalog.UNEQUIP: Action.unequip(PICK),
		ActionCatalog.USE: Action.use(PICK),
	}
	for action_name in ActionCatalog.names():
		check(refusals.has(action_name), "%s has a refusal case here" % action_name)
		var outcome := ActionEngine.resolve(scene, rook, refusals[action_name])
		check(not outcome.ok, "%s was refused" % action_name)
		check(outcome.reason.strip_edges() != "", "%s said why" % action_name)
		equal(outcome.action, action_name, "and the refusal names the action")

	# A malformed choice fails before the world is consulted at all.
	var wrong_sort := ActionEngine.resolve(scene, rook, Action.of(
		ActionCatalog.JUMP, {"target": 3}))
	check(not wrong_sort.ok and wrong_sort.reason.contains("position"),
		"a target of the wrong sort is refused: %s" % wrong_sort.reason)
	var missing := ActionEngine.resolve(scene, rook, Action.of(ActionCatalog.WAIT, {}))
	check(not missing.ok and missing.reason.contains("ticks"),
		"a missing parameter is refused: %s" % missing.reason)
	var unknown := ActionEngine.resolve(scene, rook, Action.of("sing", {}))
	check(not unknown.ok and unknown.reason.contains("not an action"),
		"an action that does not exist is refused: %s" % unknown.reason)
	var strange := ActionEngine.resolve(scene, rook, Action.of(
		ActionCatalog.WAIT, {"ticks": 2, "loudly": true}))
	check(not strange.ok and strange.reason.contains("loudly"),
		"a parameter the row does not take is refused: %s" % strange.reason)

	# A refusal never moves anything: the world before and after is one string.
	var before := scene.fingerprint()
	for action_name in refusals:
		ActionEngine.resolve(scene, rook, refusals[action_name])
	equal(scene.fingerprint(), before, "every refusal moved nothing in the world")


## The four refusals the acceptance names, with the sentence each returns.
func _the_four_worked_refusals() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var wren: Combatant = scene.actors[1]
	var chest: WorldObject = scene.objects[1]

	# A jump farther than DEX allows.
	var here := Vector2(rook.x, rook.z)
	var far := ActionEngine.resolve(scene, rook, Action.jump(here + Vector2(8.0, 0.0)))
	check(not far.ok, "a jump of 8.00 with DEX %d is refused" % ROOK_DEX)
	equal(far.reason, "8.00 is further than DEX 4 jumps (4.50)",
		"and the reason says how far it could have gone")
	equal(far.got("reach"), JUMP_REACH, "and the reach is the DEX line")
	var near := ActionEngine.resolve(scene, rook, Action.jump(here + Vector2(4.0, 0.0)))
	check(near.ok, "and a jump of 4.00 is not refused: %s" % near.reason)

	# A refused trade.
	ActionEngine.resolve(scene, rook, Action.go_to(wren.id))
	ActionEngine.resolve(scene, rook, Action.trade_propose(
		wren.id, PackedStringArray(), 3, PackedStringArray([BOOTS]), 0))
	ActionEngine.resolve(scene, wren, Action.trade_deny(rook.id))
	var after_denial := ActionEngine.resolve(scene, wren, Action.trade_accept(rook.id))
	check(not after_denial.ok, "an offer that was denied cannot then be accepted")
	equal(after_denial.reason, "the offer from Rook was denied",
		"and the reason is that it was denied, not that it never existed")
	check(not _carries(rook, BOOTS), "and nothing moved")

	# An attack whose target lies outside the weapon's pattern.
	var duel_lines := ScriptedActions.duel()
	var outside := ""
	for line in duel_lines:
		if line.contains("common bow"):
			outside = line
	check(outside.contains("is outside the pattern of a common bow from here"),
		"a bow cannot reach a target two cells away: %s" % outside)

	# An interact attempted without the item it needs.
	ActionEngine.resolve(scene, rook, Action.go_to(chest.id))
	var bare := ActionEngine.resolve(scene, rook, Action.interact(chest.id))
	check(not bare.ok, "a chest that needs a lockpick refuses a bare hand")
	equal(bare.reason, "the chest needs a lockpick",
		"and the reason names what it needs")
	check(chest.shut, "and the chest is still shut")
	var wrong := ActionEngine.resolve(scene, rook, Action.interact(chest.id, BOOTS))
	check(not wrong.ok and wrong.reason.contains("carries no"),
		"an item the character does not have is a different refusal: %s" % wrong.reason)
	var opened := ActionEngine.resolve(scene, rook, Action.interact(chest.id, PICK))
	check(opened.ok and chest.is_open(), "and the lockpick opens it: %s" % opened.reason)


# --- 4. The engine resolves, the caller only chooses ----------------------


## Nothing in the action implementations asks who is calling.
##
## The files are opened and read; comments and string literals are taken off, so
## prose about a person or a program is not read as code branching on one.
func _nothing_asks_who_is_calling() -> void:
	var asking := PackedStringArray()
	var read := 0
	for path in IMPLEMENTATION:
		var text := _read(path)
		check(text != "", "the scan opened %s" % path)
		read += 1
		var lines := text.split("\n")
		for index in lines.size():
			if _asks_who_is_calling(lines[index]):
				asking.append("%s:%d" % [path, index + 1])
	equal(read, IMPLEMENTATION.size(), "the scan opened every implementation file")
	equal(asking, PackedStringArray(),
		"no line of the action implementations asks who is calling it")

	# The other half of the same claim: the surface takes no such parameter. A
	# caller hands in a scene, a character and a choice, and there is nowhere in
	# that signature to say what sort of thing is calling.
	var engine := _code_of("res://sim/action_engine.gd")
	check(engine.contains(
		"static func resolve( scene: ActionScene, actor: Combatant, action: Action ) -> ActionOutcome:"),
		"the one entry point takes a scene, a character and a choice, and nothing else")


## The scan has teeth: a control line that does ask, and one that does not.
func _the_who_is_calling_scan_would_notice() -> void:
	check(_asks_who_is_calling(BROKEN_CONTROL),
		"the scan does not catch a line asking whether the actor is a player")
	check(_asks_who_is_calling("	if actor.decide.is_valid() and actor.is_human:"),
		"the scan does not catch a line reading a decision function's owner")
	check(_asks_who_is_calling("	if actor.agent != null:"),
		"the scan does not catch a line branching on an agent")
	check(not _asks_who_is_calling("	var by_agent := chosen_by != 0"),
		"the scan fires on a word that merely ends in one it looks for")
	check(not _asks_who_is_calling(HONEST_CONTROL),
		"the scan fires on a line that asks nothing")
	check(not _asks_who_is_calling("	## the caller only chooses; a human or an agent may call it"),
		"the scan fires on a comment saying the words")
	check(not _asks_who_is_calling("	return ActionOutcome.failed(named, \"only a character acts\")"),
		"the scan fires on a refusal sentence")


## Every resolver takes the same three things, so none of them can be handed
## anything else about who asked.
func _every_resolver_takes_the_same_three_things() -> void:
	var engine := _code_of("res://sim/action_engine.gd")
	for action_name in ActionCatalog.names():
		check(engine.contains(
			"static func _%s( scene: ActionScene, actor: Combatant, action: Action ) -> ActionOutcome:"
			% action_name),
			"%s is resolved by a function of exactly a scene, a character and a choice"
			% action_name)


# --- 5. Two minds, one surface -------------------------------------------


## The same choice, made by a person's recorded choices and by a rule reading the
## world, produces the same world change.
##
## The two scenes are set out identically and driven identically; what is
## compared is the scene's own fingerprint, which covers every position, every
## item, every coin, every offer and everything said. If the two decision
## functions were reaching different code, the two worlds would differ.
func _two_minds_one_surface() -> void:
	var lines := ScriptedActions.two_minds()
	var fingerprints := PackedStringArray()
	for line in lines:
		if line.strip_edges().begins_with("fingerprint "):
			fingerprints.append(line.strip_edges().substr("fingerprint ".length()))
	equal(fingerprints.size(), 2, "two runs, two fingerprints")
	check(fingerprints.size() == 2 and fingerprints[0] == fingerprints[1],
		"the same choice through each produced the same world change: %s" % str(fingerprints))
	check(lines[lines.size() - 1] == "same world change: yes",
		"and the transcript says so")

	# And the comparison can tell two worlds apart, so "the same" means
	# something: one extra action on one side moves its fingerprint.
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var before := scene.fingerprint()
	ActionEngine.resolve(scene, rook, Action.say("hoy"))
	not_equal(scene.fingerprint(), before,
		"a fingerprint moves when the world does")

	# The two decision functions really are two different sorts of thing: one
	# reads a list written in advance, the other reads the world. Fed a world
	# where the hatchet is already carried, the rule chooses differently while
	# the list cannot.
	var staged := _bare_scene()
	var actor: Combatant = staged.actors[0]
	var listed := DecisionSource.recorded([Action.wait(1)])
	var ruled := DecisionSource.scripted(ScriptedActions._reach_for_it)
	var from_list: Action = listed.call(staged, actor)
	var from_rule: Action = ruled.call(staged, actor)
	equal(from_list.kind, ActionCatalog.WAIT, "the recorded choice is what was recorded")
	equal(from_rule.kind, ActionCatalog.GO_TO, "the computed choice is what the world calls for")
	ActionEngine.resolve(staged, actor, from_rule)
	ActionEngine.resolve(staged, actor, Action.pick_up(HATCHET))
	var after_rule: Action = ruled.call(staged, actor)
	equal(after_rule.kind, ActionCatalog.EXAMINE,
		"and it chooses differently once the world has changed")


## A recorded person stops when their choices run out, rather than repeating.
func _a_recorded_person_stops_when_the_list_runs_out() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	(rook.piece as Commander).sheet.decide = DecisionSource.recorded([
		Action.wait(2), Action.say("hoy"),
	])
	var taken := DecisionSource.drive(scene, rook, 5)
	equal(taken.size(), 2, "two choices were recorded, so two were taken")
	equal(DecisionSource.transcript(taken).size(), 2, "and two lines were written")
	check(taken[0]["got"].ok and taken[1]["got"].ok, "and both were resolved")

	# A character with no decision function at all is driven nowhere, and that
	# is not an error: choosing is somebody else's business.
	var quiet := _bare_scene()
	equal(DecisionSource.drive(quiet, quiet.actors[0], 3).size(), 0,
		"a character nobody is deciding for takes no action")


# --- 6. A refused choice is a turn spent ----------------------------------


## A choice the catalogue cannot read counts as one action attempted, and the
## four refusals that are about the world rather than the choice count for
## nobody.
##
## The count is what every mind reads its own position out of, so this is the
## whole of why a malformed line costs one turn instead of the rest of the run.
## What it must not become is a silent no-op or an action the world carried out:
## the sentence is the catalogue's own, and the world is unmoved either side of
## it.
func _a_refused_choice_is_a_turn_spent() -> void:
	var scene := _bare_scene()
	var rook: Combatant = scene.actors[0]
	var faulted := {
		"a missing key": Action.of(ActionCatalog.EXAMINE, {}),
		"a name where an id is wanted": Action.of(
			ActionCatalog.SAY, {"text": "well met", "target": "Wren"}),
		"a key the row does not take": Action.of(
			ActionCatalog.WAIT, {"ticks": 2, "loudly": true}),
		"an action that does not exist": Action.of("sing", {}),
		"nothing chosen at all": null,
	}
	for how in faulted:
		var before := scene.actions_of(rook.id)
		var world := scene.fingerprint()
		var outcome := ActionEngine.resolve(scene, rook, faulted[how])
		check(not outcome.ok, "%s is refused" % how)
		equal(scene.actions_of(rook.id), before + 1,
			"%s costs the character one action attempted" % how)
		equal(scene.fingerprint(), world, "%s moved nothing in the world" % how)
	equal(ActionEngine.resolve(scene, rook, Action.of(ActionCatalog.EXAMINE, {})).reason,
		ActionCatalog.fault(Action.of(ActionCatalog.EXAMINE, {})),
		"and the refusal is still the catalogue's own sentence")

	# The four that are about the world and not about the choice. Each is given a
	# well-formed choice and then a malformed one, because the catalogue's
	# sentence is the one that comes back when both apply and neither may count.
	var outsider := Combatant.commander_at(0.0, 0.0, 0.0, 0.0, 1, AssetTags.KNIGHT)
	(outsider.piece as Commander).adopt(Character.make("Nobody", 1))
	var minion := scene.add_actor(Combatant.minion_at(
		Minion.TOADSTOOL, 9, 1.0, 0.0, 0.0, 0.0))
	var downed := scene.add_actor(Combatant.commander_at(
		3.0, 0.0, 0.0, 0.0, 1, AssetTags.KNIGHT))
	(downed.piece as Commander).adopt(Character.make("Fallen", 1))
	downed.piece.health = 0
	var nowhere := {
		"there is no world to act in": [null, rook, rook.id],
		"the one acting is not in the world": [scene, outsider, outsider.id],
		"only a character acts": [scene, minion, minion.id],
		"%s is down" % ActionScene.name_of(downed): [scene, downed, downed.id],
	}
	for said in nowhere:
		var at: ActionScene = nowhere[said][0]
		var actor: Combatant = nowhere[said][1]
		var id: int = nowhere[said][2]
		var before := scene.actions_of(id)
		var refused := ActionEngine.resolve(at, actor, Action.wait(1))
		check(not refused.ok, "'%s' is a refusal" % said)
		equal(refused.reason, said, "and it says so")
		equal(scene.actions_of(id), before, "and nothing is counted for it")
		var both := ActionEngine.resolve(at, actor, Action.of(ActionCatalog.EXAMINE, {}))
		equal(both.reason, ActionCatalog.fault(Action.of(ActionCatalog.EXAMINE, {})),
			"a malformed choice for '%s' still reads back as the catalogue's fault" % said)
		equal(scene.actions_of(id), before,
			"and it is still counted for nobody: %s" % said)


## A plan, a person and a model, each handed a line the catalogue faults and a
## good one after it, each reaching the good one.
##
## Run rather than read: the three are put on three identical scenes under the
## same loop, and what is asserted is the second choice actually being resolved.
## Before a refused choice counted, all three offered the refused one back on
## every review for as long as the run lasted.
func _every_mind_moves_on_from_a_line_the_catalogue_faults() -> void:
	var faulted := Action.of(ActionCatalog.SAY, {"text": "well met", "target": "Wren"})
	not_equal(ActionCatalog.fault(faulted), "", "the first choice is one the catalogue faults")

	var by_a_plan := func(_c: LiveChoice) -> Callable:
		return DecisionSource.plan([faulted, Action.wait(2)])
	var written := _run_one_mind(by_a_plan)
	equal(written["resolved"], 2, "a written-down plan reaches its second entry")
	check(written["reached"], "and the second entry is the one it wanted")

	var person := LiveChoice.new()
	var by_a_person := func(chosen: LiveChoice) -> Callable:
		chosen.choose(faulted)
		return DecisionSource.live(chosen)
	var by_hand := _run_one_mind(by_a_person, person)
	equal(by_hand["resolved"], 2, "a person chooses again once their choice has been had")
	check(by_hand["reached"], "and their second choice is the one they made")
	equal(person.carried_out, 2,
		"and both of their choices -- the refused one and the good one -- were had")

	var mind := ModelMind.with_channel(ModelChannel.replaying({
		"rows": [
			{"prompt": "", "reply": "say text=well met target=#Wren", "ms": 0},
			{"prompt": "", "reply": "wait ticks=2", "ms": 0},
		],
		"from": "written here: two replies, the first of them unreadable",
		"model": "none",
	}, "two replies handed in, the first of them unreadable"))
	var by_a_model := func(_c: LiveChoice) -> Callable:
		return DecisionSource.model(mind)
	var answered := _run_one_mind(by_a_model)
	equal(answered["resolved"], 2, "a model is asked again once its answer has been had")
	check(answered["reached"], "and its second answer is the one it gave")
	check(mind.opened >= 2,
		"and the second answer cost a second question: %d were put" % mind.opened)


# One character, one mind, one loop, run long enough for two actions and their
# reviews. Hands back what the world counted and whether the second choice was
# reached.
#
# The person is a person: nothing is written down in advance, and the second
# choice is made only once the world has taken the first one back, which is what
# somebody watching their character would see happen.
func _run_one_mind(make: Callable, chosen: LiveChoice = null) -> Dictionary:
	var scene := _bare_scene()
	var one: Combatant = scene.actors[0]
	var holder := chosen if chosen != null else LiveChoice.new()
	(one.piece as Commander).sheet.decide = make.call(holder)
	var loop := ControlLoop.on(scene, 7)
	var reached := false
	for _tick in MIND_TICKS:
		loop.step()
		if holder.made > 0 and holder.waiting() and holder.made < 2:
			holder.choose(Action.wait(2))
		var answer := loop.answer_of(one.id)
		if not answer.is_empty() and String(answer["action"]).begins_with(
				ActionCatalog.WAIT) and bool(answer["ok"]):
			reached = true
	return {"resolved": scene.actions_of(one.id), "reached": reached}


## Nothing outside `ActionScene` keeps the count, and two files alone move it.
##
## Read off disk over every script in the project rather than off the one
## function: the count is the thing three decision functions read their own
## position out of, so a second place that moved it would be a second answer to
## "has this character had its go".
##
## The second file is `sim/tool_budget.gd`, and it is the one thing besides an
## action that spends a character's turn: an ask that costs the world no time,
## made past the budget, is refused and charged the same turn a refused action is
## charged. It moves the count through `ActionScene.note_action` -- the same call
## on the same path -- rather than keeping a second count of its own, which is
## exactly what this check is for.
func _nothing_outside_the_scene_counts_an_action() -> void:
	var moved := PackedStringArray()
	var kept := PackedStringArray()
	var scripts := _every_script()
	check(scripts.size() > 100, "the scan opened the project: %d scripts" % scripts.size())
	for path in scripts:
		var code := _code_of(path)
		if code.contains("note_action("):
			moved.append(path)
		if code.contains("actions_taken"):
			kept.append(path)
	equal(", ".join(kept), "res://sim/action_scene.gd",
		"only the scene keeps the count")
	equal(", ".join(moved),
		"res://sim/action_engine.gd, res://sim/action_scene.gd,"
		+ " res://sim/tool_budget.gd",
		"only the engine and the tool budget move it, and only the scene"
		+ " declares it")
	var engine := _code_of("res://sim/action_engine.gd")
	equal(engine.count("scene.note_action("), 1,
		"and the engine moves it in exactly one place")

	# The three minds read that one count and no other.
	for path in ["res://sim/decision_source.gd", "res://sim/model_mind.gd"]:
		var code := _code_of(path)
		equal(code.count("actions_of("), code.count("scene.actions_of("),
			"%s reads its position out of the scene and nowhere else" % path)

	# And the scan has teeth: a line that would keep a second count is caught.
	check(_code_like("var actions_taken := {}").contains("actions_taken"),
		"the scan would notice a second count kept somewhere else")
	check(_code_like("# actions_taken is what the scene keeps").strip_edges() == "",
		"and it does not read prose about the count as a second one")


## Every script in the project, as paths.
func _every_script() -> PackedStringArray:
	var found := PackedStringArray()
	var stack := PackedStringArray(["res://"])
	while not stack.is_empty():
		var here := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var directory := DirAccess.open(here)
		if directory == null:
			continue
		for name in directory.get_directories():
			if not name.begins_with("."):
				stack.append(here + name + "/")
		for name in directory.get_files():
			if name.ends_with(".gd"):
				found.append(here + name)
	found.sort()
	return found


## One line with its comments and string literals taken off, the way the scan
## above reads a file.
func _code_like(line: String) -> String:
	return AssetCheck.split_code_and_strings(line)["code"].strip_edges()


# --- 7. Two processes agree ----------------------------------------------


## The documented command run twice, in two processes, printing the same bytes.
func _two_processes_agree() -> void:
	var first := _run_actions()
	var second := _run_actions()
	equal(first["exit_code"], 0, "the documented command failed")
	equal(first["output"], second["output"],
		"two runs of ./run_actions.sh printed different bytes")
	not_equal(first["output"], "", "the run printed something")
	not_equal(first["output"], first["output"] + "x",
		"and the comparison can tell two different transcripts apart")


func _run_actions() -> Dictionary:
	var output := []
	var code := OS.execute(
		ProjectSettings.globalize_path("res://run_actions.sh"), [], output, true)
	return {"exit_code": code, "output": "\n".join(PackedStringArray(output))}


# --- The bare stage -------------------------------------------------------


## Two characters, a pile and a chest, on no terrain at all.
##
## No ground, deliberately: every number in this suite is then the action layer's
## own arithmetic, and nothing about the world's fields can move one. The scene
## the walkthrough is played on -- `ScriptedActions.stage()` -- is the one with
## real ground under it.
func _bare_scene() -> ActionScene:
	var scene := ActionScene.on()

	var rook := scene.add_actor(Combatant.commander_at(
		ROOK_AT.x, ROOK_AT.y, 0.0, 0.0, 3, AssetTags.KNIGHT))
	var rook_sheet := Character.make("Rook", 3)
	rook_sheet.record_scores({Ability.DEX: ROOK_DEX})
	(rook.piece as Commander).adopt(rook_sheet)
	rook_sheet.inventory.carry(_tool(PICK))
	rook_sheet.inventory.gain(20)

	var wren := scene.add_actor(Combatant.commander_at(
		WREN_AT.x, WREN_AT.y, 0.0, 0.0, 2, AssetTags.MAGE))
	var wren_sheet := Character.make("Wren", 2)
	(wren.piece as Commander).adopt(wren_sheet)
	wren_sheet.inventory.carry(Item.armour(
		BOOTS, Item.SLOT_BOOTS, 2, ItemRarity.COMMON, Ability.DEX, [1, 1, 0] as Array[int]))
	wren_sheet.inventory.gain(3)

	scene.add_object(WorldObject.loose(
		PILE_AT.x, PILE_AT.y, Inventory.ground([_tool(HATCHET)])))
	scene.add_object(WorldObject.chest(
		"chest", CHEST_AT.x, CHEST_AT.y, Inventory.new(), PICK))
	return scene


func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


func _carries(one: Combatant, called: String) -> bool:
	return _named_in(ActionScene.inventory_of(one), called)


func _holds(thing: WorldObject, called: String) -> bool:
	return thing.contents != null and _named_in(thing.contents, called)


func _named_in(pack: Inventory, called: String) -> bool:
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == called:
			return true
	return false


# --- Reading the source ---------------------------------------------------


## Whether a line of code asks who is calling it. Comments and string literals
## are taken off first: what a file *says* about people and programs is prose,
## and only what it *does* is a branch.
func _asks_who_is_calling(line: String) -> bool:
	var code: String = AssetCheck.split_code_and_strings(line)["code"]
	var finder := RegEx.new()
	finder.compile("\\b(%s)\\b" % WHO_IS_CALLING)
	return finder.search(code) != null


## One file with its comments and string literals taken off and its whitespace
## collapsed, so a declaration split over three lines reads as one.
func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in _read(path).split("\n"):
		kept.append(AssetCheck.split_code_and_strings(line)["code"].strip_edges())
	var joined := " ".join(kept)
	while joined.contains("  "):
		joined = joined.replace("  ", " ")
	return joined


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


## A copy of the real table with one row's field replaced -- how the six broken
## tables above are built, so each break differs from the truth in exactly one
## place.
func _rows_with(change: Dictionary) -> Array:
	var copied := ActionCatalog.ROWS.duplicate(true)
	for row in copied:
		if row["name"] == change["name"]:
			for key in change:
				if key != "name":
					row[key] = change[key]
	return copied
