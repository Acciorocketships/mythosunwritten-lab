extends RefCounted
## A world with something in it to do: the stage the whole atomic action set can
## be reached from by a person at a keyboard.
##
##     ./run_render.sh --scenario play --play
##
## The ordinary world is three wanderers on an empty meadow (`sim/world_cast.gd`).
## A person handed one of them can walk, go somewhere named and jump, and that is
## all there is to do -- not because the other nine actions are missing, but
## because the meadow holds nothing to do them *to*: nobody to trade with, nothing
## lying about to pick up, nothing shut to open, nobody to fight. This is the
## smallest world that holds one of each, so that every row of
## `ActionCatalog.ROWS` is a thing a person can actually reach.
##
## ## What is in it
##
##   * **Fen** -- the one the camera follows and `--play` hands over. Carries a
##     sword (in hand), a pair of boots (not on), a mending draught, a blanket
##     and twenty coins, is a few points of health down, and is on the green side
##     with Hob. The boots and the
##     draught are what make the wardrobe reachable: putting the boots on adds a
##     way of moving, taking the sword out of hand takes the attack away with it,
##     and the draught is the one thing in the world that is used up.
##   * **Hob** -- a trader on Fen's own side, so the two can stand at arm's
##     length without the world reading it as a meeting of enemies. He drives his
##     own bargain: he offers his lantern for four coins, he takes a *gift* --
##     anything offered that asks nothing of him -- and denies any bargain that
##     does ask, and if his own offer is denied he makes it again.
##   * **Rill** -- an amber-side brawler standing well off, who takes no interest
##     in anybody until they come within `NOTICES` of her, and then closes and
##     strikes. So the fight is one a person goes looking for: stay at the market
##     and it does not happen, walk east and it does. The board itself appears
##     because `ActionScene.ENGAGE_RADIUS` says so; nothing here starts one.
##   * **a pile** with the iron key lying on it.
##   * **a chest**, shut, that the iron key opens and that holds a ring and some
##     coins.
##
## ## Nothing here is a mechanic
##
## Like the other scenarios, this file resolves nothing. The cast is a table of
## constants, every choice anybody makes is an `Action`, what each one does is
## `ActionEngine`'s answer, when it happens is `ControlLoop`'s, and the fight is
## `ActionScene.fight_step()`'s. Two processes given the same seed put the same
## world out; what happens in it then depends on what the person does, which is
## the whole point of it.
##
## The three refusals it exists to make reachable are worth naming, because they
## are what section 2.1's "any action may fail with a returned reason" looks like
## from a keyboard: the chest is shut and says what it wants, the key is not in
## your hands until you pick it up, and Hob says no to a bargain he does not
## like.
class_name ScriptedPlay

## The seed and the ground: the same measured open meadow every other
## walkthrough is played on, so no new claim is made about the world.
const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE

## Who is in it.
const FEN := "Fen"
const HOB := "Hob"
const RILL := "Rill"

## Which side each is on. Fen and Hob share one, because the engagement rule pits
## commanders of *different* bands against each other and standing next to
## somebody to trade with them must not read as a meeting of enemies.
const GREEN := "green"
const AMBER := "amber"

## The cast, as one table: `at` is an offset from `WHERE` in world units.
##
## Hob stands further than an arm's length away, so the first bargain offered
## from where Fen starts is refused for reach and walking over is a thing the
## person has to decide to do. Rill stands far enough off that nothing snaps onto
## a board until she is sent for it.
const CAST := [
	{"name": FEN, "side": GREEN, "level": 2, "tag": AssetTags.KNIGHT, "at": Vector2(0.0, 0.0)},
	{"name": HOB, "side": GREEN, "level": 2, "tag": AssetTags.MAGE, "at": Vector2(6.0, 0.0)},
	{"name": RILL, "side": AMBER, "level": 2, "tag": AssetTags.BARBARIAN, "at": Vector2(30.0, 0.0)},
]

## One roll shared by the three, as every other scenario does it: nothing here
## turns on one of them having a different score, and all six are written down
## because an unrecorded score is not a zero.
##
## DEX 3 is the ordinary cast's, deliberately: `PlayerControls.HOP` is inside
## what it reaches and `PlayerControls.LEAP` is outside, so the jump refusal a
## person can provoke in the ordinary world is the same one they can provoke
## here.
const ROLL := {
	Ability.STR: 5,
	Ability.CON: 4,
	Ability.CHA: 3,
	Ability.DEX: 3,
	Ability.WIS: 3,
	Ability.INT: 2,
}

## What everybody starts with. The sword is what Fen attacks with, the blanket is
## what Fen has to offer, the lantern is what Hob is selling and the key is what
## the chest opens to.
const SWORD := "common sword"
const SPEAR := "common spear"
const BLANKET := "wool blanket"
const LANTERN := "brass lantern"
const KEY := "iron key"
const RING := "silver ring"
## What the boots Fen carries are called. `Armour.boots` names a piece by its
## rarity and its slot, so this is that name read back rather than a second one.
const BOOTS := "common boots"
const DRAUGHT := "mending draught"

## What Hob wants for the lantern, and what the two start with in coin.
const LANTERN_PRICE := 4
const FEN_MONEY := 20
const HOB_MONEY := 6

## How many points of health Fen starts down.
##
## Stage dressing, and the one piece of it that needs explaining. The stage has
## to hold one of everything a person can do, and the one thing it could not
## otherwise hold is a reason to drink: nothing in this world can wound the
## person. Rill closes and strikes, but the moment two commanders come within
## `ActionScene.ENGAGE_RADIUS` the fight snaps onto a board, and a commander on a
## board has no way to walk across it -- there is no board-move action yet -- so
## whoever the snap left out of reach stays out of reach. Until there is one, a
## character who has never been scratched is a character whose draught is
## furniture.
const FEN_SCRATCHED := 6

## Where the pile and the chest lie, as offsets from `WHERE`, and what the chest
## holds.
const PILE_AT := Vector2(0.0, 4.0)
const CHEST_AT := Vector2(-5.0, 0.0)
const CHEST_MONEY := 12

## How near somebody has to come before Rill takes an interest in them, in world
## units.
##
## Wide enough that walking over to her is unmistakably walking over to her, and
## narrow enough that the market at the other end of the stage is left alone --
## a person trading has not accidentally started a fight, and the engine refuses
## a trade while one is on.
const NOTICES := 20.0

## How long anybody with something to watch for waits before looking up again,
## and how long somebody with nothing left to watch for waits.
const WATCH := 4
const REST := 20


## Set the stage out in a world and hand back how many characters are in it.
##
## The world's own cast goes first, exactly as every other scenario's muster
## does, and the camera is put on Fen -- which is the whole of what Fen gets, and
## is why `--play` hands that one over: `Simulation.hand_over_followed` replaces
## the decision function of whoever the world is looking through.
static func muster(world: SimWorld) -> int:
	world.clear_cast()
	var scene := world.combat.scene
	populate(scene)
	drive(scene)
	var fen := _named(scene, FEN)
	if fen != null:
		world.follow(fen.id)
	for one in scene.actors:
		one.settle(world.terrain)
	for thing in scene.objects:
		thing.settle(world.terrain)
	return scene.actors.size()


## Put the three characters, the pile and the chest into a scene.
##
## The order things are added in is the order they are given ids in, so it is
## fixed here and nowhere else: the cast in `CAST` order, then the pile, then the
## chest.
static func populate(scene: ActionScene) -> ActionScene:
	var bands := {}
	for row in CAST:
		var one := scene.add_actor(Combatant.commander_at(
			WHERE.x + (row["at"] as Vector2).x, WHERE.y + (row["at"] as Vector2).y,
			0.0, 0.0, int(row["level"]), String(row["tag"])))
		if bands.has(row["side"]):
			one.band = int(bands[row["side"]])
		else:
			bands[row["side"]] = one.id
		var sheet := Character.make(String(row["name"]), int(row["level"]))
		sheet.record_scores(ROLL)
		(one.piece as Commander).adopt(sheet)

	var fen := _named(scene, FEN)
	(fen.piece as Commander).wield(Weapon.held(Weapon.sword(), _level_of(FEN)))
	# Carried and deliberately *not* put on: what a person equips has to be
	# something they are already holding, or equipping it would be two actions
	# written as one.
	ActionScene.inventory_of(fen).carry(Armour.boots(_level_of(FEN)))
	ActionScene.inventory_of(fen).carry(_draught(DRAUGHT))
	ActionScene.inventory_of(fen).carry(_tool(BLANKET))
	ActionScene.inventory_of(fen).gain(FEN_MONEY)
	fen.piece.health = maxi(1, fen.piece.max_health() - FEN_SCRATCHED)

	var hob := _named(scene, HOB)
	ActionScene.inventory_of(hob).carry(_tool(LANTERN))
	ActionScene.inventory_of(hob).gain(HOB_MONEY)

	var rill := _named(scene, RILL)
	rill.piece.equip(Armour.boots())
	(rill.piece as Commander).wield(Weapon.held(Weapon.spear(), _level_of(RILL)))

	scene.add_object(WorldObject.loose(
		WHERE.x + PILE_AT.x, WHERE.y + PILE_AT.y,
		Inventory.ground([_tool(KEY)])))
	scene.add_object(WorldObject.chest(
		"chest", WHERE.x + CHEST_AT.x, WHERE.y + CHEST_AT.y,
		Inventory.ground([_tool(RING)], CHEST_MONEY), KEY))
	return scene


## Put a decision function on the two characters who are not the person's.
##
## Fen is left with none: `--play` puts `DecisionSource.live` on that sheet, and
## a run of this scenario with nobody playing is a person's character standing
## still, which is the honest picture of a game nobody is at.
static func drive(scene: ActionScene) -> void:
	_sheet(_named(scene, HOB)).decide = DecisionSource.scripted(ScriptedPlay._haggling)
	_sheet(_named(scene, RILL)).decide = DecisionSource.scripted(
		_closing_on(FEN, SPEAR))


# --- The two rules --------------------------------------------------------


## Hob drives his own bargain.
##
## Four things in order, and every one of them reads the world it is handed: a
## bargain offered to him he denies -- he is not buying today -- while a gift, an
## offer that asks him for nothing, he takes; and with nothing offered to him and
## nobody within arm's length there is nothing to do but wait. Standing close enough, he offers the lantern for its price, and once
## he has been paid, or while his offer is on the table, he answers whoever spoke
## to him.
##
## He never asks whether he may. A proposal out of reach, a denial of an offer
## that has gone -- those are the engine's answers, and a second opinion here
## would be a second rule.
static func _haggling(scene: ActionScene, actor: Combatant) -> Action:
	for offer in scene.offers:
		if int(offer["to"]) != actor.id:
			continue
		# A gift is a trade with nothing in return -- section 2.1's own reading
		# of it -- and he will take one. A bargain that asks him for anything he
		# will not: he is not buying today.
		var asks := not PackedStringArray(offer["want"]).is_empty() \
			or int(offer["want_money"]) > 0
		return Action.trade_deny(int(offer["from"])) if asks \
			else Action.trade_accept(int(offer["from"]))
	var buyer := _named(scene, FEN)
	if buyer == null:
		return Action.wait(REST)
	if actor.distance_to(buyer) > ActionEngine.REACH:
		return Action.wait(WATCH)
	if scene.offer_between(actor.id, buyer.id).is_empty() \
			and _carries(actor, LANTERN):
		return Action.trade_propose(
			buyer.id, PackedStringArray([LANTERN]), 0,
			PackedStringArray(), LANTERN_PRICE)
	var owed := _who_is_owed_an_answer(scene, actor.id)
	if owed != ActionCatalog.NOBODY:
		return Action.say("a fair price is a fair price", owed)
	return Action.wait(WATCH)


## Rill minds her own business until somebody comes near, then closes on them and
## strikes at them with what she carries.
##
## The same rule the quarrel in `sim/scripted_scenario.gd` is driven by, with one
## thing in front of it: she waits while whoever she is watching is further off
## than `NOTICES`, so the fight is one a person walks into rather than one that
## arrives on a stated tick. What makes a fight *begin* is the two of them being
## commanders of different bands within `ActionScene.ENGAGE_RADIUS`, which is the
## world's rule and not this file's.
static func _closing_on(other_name: String, strikes_with: String) -> Callable:
	return func(scene: ActionScene, actor: Combatant) -> Action:
		var other := _named(scene, other_name)
		if other == null or not other.piece.is_alive():
			return Action.wait(REST)
		if scene.is_fighting(actor):
			return Action.attack(other.id, strikes_with)
		var gap := actor.distance_to(other)
		if gap > NOTICES:
			return Action.wait(REST)
		if gap > ActionEngine.REACH:
			return Action.go_to(other.id)
		return Action.wait(WATCH)


# --- The furniture --------------------------------------------------------


## The id the world knows one of this cast by, or zero.
##
## What a caller outside the scenario asks when it needs to name one of them --
## a person's character is aimed at strangers by id, because a name is knowledge
## and `Observation` will not hand out one this character has not earned.
static func id_of(scene: ActionScene, who: String) -> int:
	var one := _named(scene, who)
	return 0 if one == null else one.id


## The character of a given name in a scene, or null.
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


static func _level_of(who: String) -> int:
	for row in CAST:
		if row["name"] == who:
			return int(row["level"])
	return 1


# Whether somebody is carrying a thing of this name. Read off the inventory,
# which is the world's own account of it.
static func _carries(one: Combatant, called: String) -> bool:
	var pack := ActionScene.inventory_of(one)
	if pack == null:
		return false
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == called:
			return true
	return false


# Who last said something to this character that it has not answered, or NOBODY.
# The scene's own record of what was said, read backwards.
static func _who_is_owed_an_answer(scene: ActionScene, id: int) -> int:
	for at in range(scene.said.size() - 1, -1, -1):
		var spoken: Dictionary = scene.said[at]
		if int(spoken["speaker"]) == id:
			return ActionCatalog.NOBODY
		if int(spoken["to"]) == id:
			return int(spoken["speaker"])
	return ActionCatalog.NOBODY


# A hand-held item at level 1, forged exactly as the other walkthroughs forge
# one: everything it is worth goes to its effects axis.
static func _tool(called: String) -> Item:
	return Item.weapon(called, 1, ItemRarity.COMMON, Ability.DEX, [0, 0, 1] as Array[int])


# Something to drink, at the level of the one who carries it, read against CON.
# A consumable's whole budget is on its effects axis by construction
# (`Item.consumable`), so what it is worth is the item layer's arithmetic and
# nothing here chooses a number.
static func _draught(called: String) -> Item:
	return Item.consumable(
		called, _level_of(FEN), ItemRarity.COMMON, Ability.CON,
		[called] as Array[String])
