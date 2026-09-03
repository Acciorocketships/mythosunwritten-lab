extends RefCounted
## Where every atomic action is resolved, and the only place any of them is.
##
## The division this file exists to hold is section 10's first paragraph: the
## decision-maker "never simulates the world -- movement, combat, inventory, item
## effects and physics are resolved deterministically by the engine". So a caller
## chooses an `Action` and hands it here, and everything after that -- how far a
## walk is, which attack of a weapon reaches, whether a chest opens, what a trade
## moves -- is worked out here against the world, with the caller neither
## consulted nor named.
##
## **Nothing here asks who is calling it.** There is no field, no parameter and
## no branch anywhere in this file for whether a choice came from a person or
## from a program; `resolve()` is handed a scene, a character and a choice, and
## those three are the whole of its input. That is checked rather than promised:
## `tests/test_actions.gd` reads this file's code, looks for anything that asks
## the question, requires nothing, and then runs the same scan over a line that
## does ask it and requires the scan to catch it.
##
## ## Every call may fail, and says why
##
## Every path out is an `ActionOutcome`, and a refusal carries a sentence naming
## what stopped it. Refusals come in three layers, and they are separate on
## purpose:
##
##   1. the choice is malformed -- an unknown action, a missing parameter, a
##      target of the wrong sort. `ActionCatalog.fault()` answers this without
##      looking at the world at all.
##   2. the actor cannot act -- there is nobody, or it is not a character.
##   3. the world says no -- too far to jump, out of earshot, the chest is
##      locked, the target is outside the weapon's pattern, the offer was denied.
##
## ## What this file does not do itself
##
## A blow is not resolved here. Section 3.7's damage matrix lives in
## `CombatResolution` behind one seam, and the turn economy that decides whether
## a commander may swing at all lives in `CombatMatch`; `_attack` chooses *which*
## attack reaches the target and hands the swing to the match. That is why this
## file contains no damage arithmetic, no die and no defence: there is one answer
## to "what does that blow do" and it is not here.
class_name ActionEngine

## Arm's length, in world units: how near you must be to take something out of a
## chest, put something into one, work a lock, or trade with somebody.
const REACH := 2.5

## How far you can see well enough to examine something.
const SIGHT := 40.0

## How far a voice carries, shouted or spoken.
const VOICE := 20.0

## How near a walk must get to a bare position to have arrived. A walk to a
## *thing* arrives at `REACH` of it instead, because standing on somebody is not
## arriving at them.
const ARRIVE := 0.5

## How far one step of a walk covers when the character has no speed of its own.
const STEP := 0.9

## The most steps one `go_to` takes. A walk that has not arrived by then is
## refused as too far rather than run to a standstill: an action resolves or says
## why, and "still walking" is the control loop's answer, not this one's.
const MAX_STEPS := 400

## How far anybody can jump with no DEX at all, and how much further each point
## of DEX carries them. Section 2.1 gives the failure -- "jumping farther than
## DEX allows" -- and this is the line it is measured against.
const JUMP_BASE := 1.5
const JUMP_PER_DEX := 0.75


## Every action, and the one function that resolves it.
##
## This is the resolving half of the one list: `ActionCatalog.faults()` reads
## these keys against the catalogue's rows and against `Action.constructors()`,
## so an action that can be chosen and not resolved, or resolved and not listed,
## is a failing check rather than a surprise at run time.
static func resolvers() -> Dictionary:
	return {
		ActionCatalog.GO_TO: ActionEngine._go_to,
		ActionCatalog.JUMP: ActionEngine._jump,
		ActionCatalog.ATTACK: ActionEngine._attack,
		ActionCatalog.SAY: ActionEngine._say,
		ActionCatalog.TRADE_PROPOSE: ActionEngine._trade_propose,
		ActionCatalog.TRADE_ACCEPT: ActionEngine._trade_accept,
		ActionCatalog.TRADE_DENY: ActionEngine._trade_deny,
		ActionCatalog.PICK_UP: ActionEngine._pick_up,
		ActionCatalog.DROP: ActionEngine._drop,
		ActionCatalog.EXAMINE: ActionEngine._examine,
		ActionCatalog.INTERACT: ActionEngine._interact,
		ActionCatalog.WAIT: ActionEngine._wait,
	}


## Resolve one chosen action for one character in one scene.
##
## The whole surface. There is no second entry point, no per-action public
## function and no way to reach a resolver except through here, so everything
## said above about failure and about the caller is true of every call made.
##
## Being the one path, it is also where the world counts what it has carried out:
## a choice that reaches a resolver is one action taken, noted on the scene. A
## count kept anywhere else would be a second count of the same thing, and a
## count kept per driver could not be read by anything but that driver.
static func resolve(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var named := "nothing" if action == null else action.kind
	var fault := ActionCatalog.fault(action)
	if fault != "":
		return ActionOutcome.failed(named, fault)
	if scene == null:
		return ActionOutcome.failed(named, "there is no world to act in")
	if actor == null or not scene.actors.has(actor):
		return ActionOutcome.failed(named, "the one acting is not in the world")
	if _sheet_of(actor) == null:
		return ActionOutcome.failed(named, "only a character acts")
	if not actor.piece.is_alive():
		return ActionOutcome.failed(named, "%s is down" % ActionScene.name_of(actor))
	scene.note_action(actor.id)
	var resolver: Callable = resolvers()[action.kind]
	return resolver.call(scene, actor, action)


# --- go to ----------------------------------------------------------------


## Walk to a position, or to whatever has an id: an item lying on the ground, a
## chest, another character.
##
## The walk is taken in steps of the character's own speed, each step settled
## onto whatever surface is under it -- the same one-hop settle a combatant
## walking the overworld uses, so walking into a floating island's rim carries
## you up onto it here exactly as it does there. A step onto ground nothing can
## stand on stops the walk where it stands and says so.
static func _go_to(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	if scene.is_fighting(actor):
		return ActionOutcome.failed(action.kind, "the board decides where a fighter goes")
	var to := action.target_position()
	var arrive := ARRIVE
	var what := "the position"
	if not action.targets_a_position():
		var thing: Variant = scene.thing_of(action.target_id())
		if thing == null:
			return ActionOutcome.failed(
				action.kind, "there is nothing with id %d" % action.target_id())
		to = ActionScene.position_of(thing)
		arrive = REACH
		what = ActionScene.name_of(thing)

	var walked := 0.0
	var steps := 0
	var stride := maxf(actor.speed, STEP)
	while _distance_from(actor, to) > arrive:
		if steps >= MAX_STEPS:
			return ActionOutcome.failed(action.kind, "%s is too far to walk to at once" % what, {
				"walked": snappedf(walked, 0.001), "steps": steps,
			})
		var here := Vector2(actor.x, actor.z)
		var gap := to - here
		var next := here + gap.normalized() * minf(stride, gap.length())
		if scene.terrain != null and not scene.terrain.is_passable_at(next.x, next.y):
			return ActionOutcome.failed(action.kind, "the way to %s is blocked" % what, {
				"blocked_at": next, "walked": snappedf(walked, 0.001), "steps": steps,
			})
		walked += here.distance_to(next)
		actor.x = next.x
		actor.z = next.y
		actor.settle(scene.terrain) if scene.terrain != null else null
		steps += 1

	return ActionOutcome.done(action.kind, {
		"at": Vector2(actor.x, actor.z),
		"walked": snappedf(walked, 0.001),
		"steps": steps,
	})


# --- jump -----------------------------------------------------------------


## Jump to a position, as far as DEX allows and no further.
##
## Section 2.1's own example of a call that fails with a reason. The reach is
## `JUMP_BASE + JUMP_PER_DEX` per point of DEX, and a character nobody has rolled
## a DEX for reads no points -- an unrecorded score is not a score, and jumping
## is not an item being read through a gate, so there is nothing for it to fall
## back to but the base.
static func _jump(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	if scene.is_fighting(actor):
		return ActionOutcome.failed(action.kind, "the board decides where a fighter goes")
	var to := action.target_position()
	var gap := _distance_from(actor, to)
	var dexterity := _sheet_of(actor).score(Ability.DEX, 0)
	var reach := JUMP_BASE + JUMP_PER_DEX * dexterity
	if gap > reach:
		return ActionOutcome.failed(action.kind, "%.2f is further than DEX %d jumps (%.2f)" % [
			gap, dexterity, reach,
		], {"gap": snappedf(gap, 0.001), "reach": snappedf(reach, 0.001), "dex": dexterity})
	if scene.terrain != null and not scene.terrain.is_passable_at(to.x, to.y):
		return ActionOutcome.failed(action.kind, "there is nothing to land on there", {
			"gap": snappedf(gap, 0.001), "reach": snappedf(reach, 0.001),
		})
	actor.x = to.x
	actor.z = to.y
	actor.settle(scene.terrain) if scene.terrain != null else null
	# What moved it was a jump, which is a different thing from a walk of the
	# same length and is the only place in the engine that can say so.
	actor.jumped = true
	return ActionOutcome.done(action.kind, {
		"at": Vector2(actor.x, actor.z),
		"gap": snappedf(gap, 0.001),
		"reach": snappedf(reach, 0.001),
		"dex": dexterity,
	})


# --- attack ---------------------------------------------------------------


## Attack a character with a named item.
##
## Which attack of the item is used is derived and not chosen: section 10 spells
## this call `Attack(target, weapon/attack-mode derived from item)`, and the
## derivation is here -- the first of the item's attacks that covers the cell the
## target is standing on and is off its cooldown. A caller therefore never picks
## an index, which is what keeps a choice from being half a resolution.
##
## **The facing is derived with it.** Section 3.5 makes rotating a character free
## -- no turn, no action cost -- so every one of the four facings is available to
## the blow being resolved, and all four are tried, the one the character already
## has first. That is the only reading that leaves the caller out of it: the
## interface names no turn action, because the design names none, so an engine
## that did not rotate would leave a character able to choose a strike it could
## never aim. What "outside the pattern" therefore means here is exact -- no
## rotation of any of the item's patterns reaches the target -- and it is a fact
## about the shape of the pattern rather than about which way somebody happened
## to be looking.
##
## The blow itself is the match's. Everything below the derivation is handing the
## chosen index to `CombatMatch.attack`, which spends the turn's one weapon
## action and resolves it through the one damage seam.
static func _attack(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var wanted: String = action.param("item", "")
	var target := scene.actor_of(action.target_id())
	if target == null:
		return ActionOutcome.failed(
			action.kind, "there is no character with id %d" % action.target_id())
	if target == actor:
		return ActionOutcome.failed(action.kind, "nobody attacks themselves")
	if scene.fight == null:
		return ActionOutcome.failed(action.kind, "no fight is under way")
	if not actor.fighting or not target.fighting:
		return ActionOutcome.failed(action.kind, "%s is not on the board" % (
			ActionScene.name_of(actor) if not actor.fighting
			else ActionScene.name_of(target)))
	var match_state := scene.fight.match_state
	if match_state.active_id() != actor.piece.id:
		return ActionOutcome.failed(action.kind, "it is not %s's turn" % ActionScene.name_of(actor))

	var pack := ActionScene.inventory_of(actor)
	var entry: Variant = _carried_named(pack, wanted)
	if entry == null:
		return ActionOutcome.failed(action.kind, "%s carries no %s" % [
			ActionScene.name_of(actor), wanted,
		])
	var me := actor.piece as Commander
	if not pack.is_equipped(entry):
		if entry is Weapon:
			me.wield(entry)
		else:
			pack.take_up(entry)
	if me.attack_count() == 0:
		return ActionOutcome.failed(action.kind, "a %s has no attack on it" % wanted)

	var turn := match_state.turn_number(me.id)
	var chosen := -1
	var looking := me.facing
	var reaches := false
	var waits := 0
	for quarter in 4:
		var facing := (me.facing + quarter) % 4
		for index in me.attack_count():
			if not me.attack_at(index).cells_from(me.cell, facing).has(target.piece.cell):
				continue
			reaches = true
			if me.can_attack(index, turn):
				chosen = index
				looking = facing
				break
			waits = maxi(waits, me.turns_until_ready(index, turn))
		if chosen >= 0:
			break
	if not reaches:
		return ActionOutcome.failed(action.kind, "%s is outside the pattern of a %s from here" % [
			ActionScene.name_of(target), wanted,
		], {"target_cell": Vector2(target.piece.cell), "from_cell": Vector2(me.cell)})
	if chosen < 0:
		return ActionOutcome.failed(
			action.kind, "every attack of the %s that reaches is on cooldown" % wanted,
			{"turns": waits})

	me.face(looking)
	var swung := match_state.attack(chosen)
	if not swung.get("ok", false):
		return ActionOutcome.failed(action.kind, str(swung.get("reason", "refused")))
	var dealt := 0
	for hit in swung["hits"]:
		dealt += int(hit.get("dealt", 0))
	# The world's own record of the blow, on the one path an attack takes. What
	# it means to the two of them is `RelationshipGraph`'s and is worked out
	# nowhere near here.
	scene.note_blow(actor.id, target.id, dealt, target.piece.max_health())
	return ActionOutcome.done(action.kind, {
		"attack": swung["attack"],
		"cells": swung["cells"],
		"hits": (swung["hits"] as Array).size(),
		"dealt": dealt,
	})


# --- say ------------------------------------------------------------------


## Say something to one character, or -- with nobody named -- shout it, so that
## everyone within earshot hears.
static func _say(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var text: String = action.param("text", "")
	if text.strip_edges() == "":
		return ActionOutcome.failed(action.kind, "there is nothing to say")
	var to_id := action.target_id()
	var heard := PackedInt32Array()
	if to_id == ActionCatalog.NOBODY:
		for one in scene.actors:
			if one != actor and _between(actor, one) <= VOICE:
				heard.append(one.id)
	else:
		var target := scene.actor_of(to_id)
		if target == null:
			return ActionOutcome.failed(action.kind, "there is no character with id %d" % to_id)
		if target == actor:
			return ActionOutcome.failed(action.kind, "nobody talks to themselves")
		var gap := _between(actor, target)
		if gap > VOICE:
			return ActionOutcome.failed(action.kind, "%s is out of earshot (%.2f > %.2f)" % [
				ActionScene.name_of(target), gap, VOICE,
			])
		heard.append(target.id)

	scene.said.append({
		"speaker": actor.id, "text": text, "to": to_id,
		"shout": to_id == ActionCatalog.NOBODY, "heard_by": heard,
	})
	return ActionOutcome.done(action.kind, {
		"shout": to_id == ActionCatalog.NOBODY, "heard_by": heard.size(),
	})


# --- trade ----------------------------------------------------------------


## Offer a trade: items and money out, items and money back.
##
## Nothing moves here. An offer is a question, and both halves of it are checked
## against what the two characters actually have before it is asked, so a trade
## that could never have been honoured is refused at the proposal rather than
## discovered at the acceptance.
static func _trade_propose(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var target := scene.actor_of(action.target_id())
	var refusal := _trading_partner(scene, actor, target, action)
	if refusal != null:
		return refusal
	var give: PackedStringArray = action.param("give", PackedStringArray())
	var want: PackedStringArray = action.param("want", PackedStringArray())
	var give_money: int = action.param("give_money", 0)
	var want_money: int = action.param("want_money", 0)
	if give_money < 0 or want_money < 0:
		return ActionOutcome.failed(action.kind, "money moves in amounts, not debts")

	var mine: Variant = _all_carried_named(ActionScene.inventory_of(actor), give)
	if mine == null:
		return ActionOutcome.failed(action.kind, "%s carries none of that" % ActionScene.name_of(actor))
	var theirs: Variant = _all_carried_named(ActionScene.inventory_of(target), want)
	if theirs == null:
		return ActionOutcome.failed(action.kind, "%s carries none of that" % ActionScene.name_of(target))
	if give_money > ActionScene.inventory_of(actor).money:
		return ActionOutcome.failed(action.kind, "%s has only %d money" % [
			ActionScene.name_of(actor), ActionScene.inventory_of(actor).money,
		])
	if want_money > ActionScene.inventory_of(target).money:
		return ActionOutcome.failed(action.kind, "%s has only %d money" % [
			ActionScene.name_of(target), ActionScene.inventory_of(target).money,
		])

	scene.set_offer({
		"from": actor.id, "to": target.id,
		"give": give, "give_money": give_money,
		"want": want, "want_money": want_money,
	})
	return ActionOutcome.done(action.kind, {
		"to": target.id, "give": give.size(), "give_money": give_money,
		"want": want.size(), "want_money": want_money,
	})


## Accept the offer standing from a character, moving everything at once.
##
## The exchange is `Inventory.trade`, which is all or nothing: the whole of it is
## checked before any of it happens, so nobody is left having paid for something
## that did not arrive.
static func _trade_accept(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var proposer := scene.actor_of(action.target_id())
	var refusal := _trading_partner(scene, actor, proposer, action)
	if refusal != null:
		return refusal
	var offer := scene.offer_between(proposer.id, actor.id)
	if offer.is_empty():
		if scene.was_refused(proposer.id, actor.id):
			return ActionOutcome.failed(action.kind, "the offer from %s was denied" % (
				ActionScene.name_of(proposer)))
		return ActionOutcome.failed(action.kind, "%s has offered nothing" % (
			ActionScene.name_of(proposer)))

	var from_pack := ActionScene.inventory_of(proposer)
	var to_pack := ActionScene.inventory_of(actor)
	var given: Variant = _all_carried_named(from_pack, offer["give"])
	var back: Variant = _all_carried_named(to_pack, offer["want"])
	if given == null or back == null:
		return ActionOutcome.failed(action.kind, "what was offered is no longer carried")
	if not Inventory.trade(
		from_pack, to_pack, given, offer["give_money"], back, offer["want_money"]
	):
		return ActionOutcome.failed(action.kind, "the exchange could not be honoured")
	scene.clear_offer(proposer.id, actor.id)
	scene.note_trade(
		proposer.id, actor.id,
		given.size(), int(offer["give_money"]), back.size(), int(offer["want_money"]))
	return ActionOutcome.done(action.kind, {
		"from": proposer.id,
		"took": given.size(), "took_money": offer["give_money"],
		"gave": back.size(), "gave_money": offer["want_money"],
	})


## Deny the offer standing from a character. Nothing moves, and the denial is
## written down: an offer that was refused is answered as refused afterwards, not
## as one that was never made.
static func _trade_deny(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var proposer := scene.actor_of(action.target_id())
	if proposer == null:
		return ActionOutcome.failed(
			action.kind, "there is no character with id %d" % action.target_id())
	if scene.offer_between(proposer.id, actor.id).is_empty():
		return ActionOutcome.failed(action.kind, "%s has offered nothing" % (
			ActionScene.name_of(proposer)))
	scene.clear_offer(proposer.id, actor.id)
	scene.record_refusal(proposer.id, actor.id)
	return ActionOutcome.done(action.kind, {"from": proposer.id})


# --- pick up and drop -----------------------------------------------------


## Take a named item out of a named container, or off the ground within reach.
static func _pick_up(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var wanted: String = action.param("item", "")
	var source: WorldObject = null
	if action.params.has("target"):
		source = scene.object_of(action.target_id())
		var refusal := _reachable_container(actor, source, action, action.target_id())
		if refusal != null:
			return refusal
		if _carried_named(source.contents, wanted) == null:
			return ActionOutcome.failed(action.kind, "there is no %s in the %s" % [
				wanted, source.object_name,
			])
	else:
		for pile in scene.piles_near(Vector2(actor.x, actor.z), REACH):
			if _carried_named(pile.contents, wanted) != null:
				source = pile
				break
		if source == null:
			return ActionOutcome.failed(
				action.kind, "there is no %s within reach" % wanted)

	var entry: Variant = _carried_named(source.contents, wanted)
	if not Inventory.transfer(source.contents, ActionScene.inventory_of(actor), [entry], 0):
		return ActionOutcome.failed(action.kind, "the %s would not come away" % wanted)
	if source.pile and source.contents.size() == 0 and source.contents.money == 0:
		scene.remove_object(source)
	return ActionOutcome.done(action.kind, {"item": wanted, "from": source.id})


## Put a named item down: into a named container, or on the ground at your feet.
##
## A drop with nothing named joins whatever open pile is already within reach and
## makes one where there is none, so a character that drops three things leaves
## one pile and not three.
static func _drop(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var wanted: String = action.param("item", "")
	var pack := ActionScene.inventory_of(actor)
	var entry: Variant = _carried_named(pack, wanted)
	if entry == null:
		return ActionOutcome.failed(action.kind, "%s carries no %s" % [
			ActionScene.name_of(actor), wanted,
		])

	var into: WorldObject = null
	if action.params.has("target"):
		into = scene.object_of(action.target_id())
		var refusal := _reachable_container(actor, into, action, action.target_id())
		if refusal != null:
			return refusal
	else:
		var near := scene.piles_near(Vector2(actor.x, actor.z), REACH)
		into = near[0] if not near.is_empty() else scene.add_object(
			WorldObject.loose(actor.x, actor.z))

	if not Inventory.transfer(pack, into.contents, [entry], 0):
		return ActionOutcome.failed(action.kind, "the %s would not go in" % wanted)
	return ActionOutcome.done(action.kind, {"item": wanted, "into": into.id})


# --- examine --------------------------------------------------------------


## Look at something in sight: a character, an object, or something carried, by
## name.
##
## What comes back is what can be *observed* -- a name, a distance, how hurt
## somebody looks, what they have on, whether a chest is shut -- and not what the
## character sheet says. A shut chest reports that it is shut and nothing about
## what is in it.
static func _examine(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	if action.targets_a_name():
		var wanted := action.target_name()
		var entry: Variant = _carried_named(ActionScene.inventory_of(actor), wanted)
		if entry == null:
			return ActionOutcome.failed(action.kind, "%s carries no %s" % [
				ActionScene.name_of(actor), wanted,
			])
		return ActionOutcome.done(action.kind, {
			"item": wanted, "seen": Inventory.entry_line(entry),
		})

	var thing: Variant = scene.thing_of(action.target_id())
	if thing == null:
		return ActionOutcome.failed(
			action.kind, "there is nothing with id %d" % action.target_id())
	var gap := ActionScene.position_of(thing).distance_to(Vector2(actor.x, actor.z))
	if gap > SIGHT:
		return ActionOutcome.failed(action.kind, "%s is out of sight (%.2f > %.2f)" % [
			ActionScene.name_of(thing), gap, SIGHT,
		])
	var seen: Dictionary = observed_of(thing)
	seen["distance"] = snappedf(gap, 0.001)
	return ActionOutcome.done(action.kind, seen)


# --- interact -------------------------------------------------------------


## Work on an object, optionally with a named item: section 2.1's generic
## interaction, of which the lockpick is the example.
##
## What an object requires is the object's to say, so nothing here knows what a
## lock is. An object that requires an item is refused to a character that has
## not brought one, refused again if the one named is not carried, and refused a
## third time if it is carried and is not the one required -- three different
## sentences, because they are three different mistakes.
static func _interact(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var target: Variant = scene.thing_of(action.target_id())
	if target == null:
		return ActionOutcome.failed(
			action.kind, "there is nothing with id %d" % action.target_id())
	if target is Combatant:
		return ActionOutcome.failed(action.kind, "%s is a character: talk or trade" % (
			ActionScene.name_of(target)))
	var thing := target as WorldObject
	var gap := thing.distance_from(actor.x, actor.z)
	if gap > REACH:
		return ActionOutcome.failed(action.kind, "%s is out of reach (%.2f > %.2f)" % [
			thing.object_name, gap, REACH,
		])

	var used: String = action.param("item", "")
	if thing.needs != "":
		if used == "":
			return ActionOutcome.failed(action.kind, "the %s needs a %s" % [
				thing.object_name, thing.needs,
			])
		if _carried_named(ActionScene.inventory_of(actor), used) == null:
			return ActionOutcome.failed(action.kind, "%s carries no %s" % [
				ActionScene.name_of(actor), used,
			])
		if used != thing.needs:
			# --- The hook. See `AbilityCheck.HOOK`. ---
			#
			# The character is holding out something the world has no rule for.
			# Bare hands are still a flat refusal above, and the item the thing
			# plainly opens with still just works below; what is left here is an
			# attempt whose chance of working nobody has written down, which is
			# exactly what section 7's difficulty class is for. So the engine
			# raises a check and says so, and settling it is somebody else's,
			# later -- nothing here waits for it, and the interaction itself did
			# not open anything, so it is a refusal like any other.
			var check := scene.raise_check(actor, thing, used)
			return ActionOutcome.failed(
				action.kind,
				"a %s is not what the %s opens with, so it is put to a check" % [
					used, thing.object_name,
				],
				{"check": check.id, "context": check.context})
	var was := thing.shut
	thing.shut = false
	return ActionOutcome.done(action.kind, {
		"target": thing.id, "opened": was, "used": used,
	})


# --- wait -----------------------------------------------------------------


## Wait a number of ticks.
##
## What this writes is when the character is next expecting to do something, and
## nothing enforces it: section 2.2's loop re-evaluates while an action is in
## progress and may change its mind, so a wait is a stated intention and not a
## lock on the character.
static func _wait(
	scene: ActionScene, actor: Combatant, action: Action
) -> ActionOutcome:
	var ticks: int = action.param("ticks", 0)
	if ticks <= 0:
		return ActionOutcome.failed(action.kind, "a wait is at least one tick")
	scene.idle_until[actor.id] = scene.tick + ticks
	return ActionOutcome.done(action.kind, {
		"ticks": ticks, "until": scene.idle_until[actor.id],
	})


# --- Shared refusals ------------------------------------------------------


# Whether two characters can trade at all: somebody, not themselves, near
# enough. Null when they can, and the refusal when they cannot.
static func _trading_partner(
	scene: ActionScene, actor: Combatant, other: Combatant, action: Action
) -> ActionOutcome:
	if other == null:
		return ActionOutcome.failed(
			action.kind, "there is no character with id %d" % action.target_id())
	if other == actor:
		return ActionOutcome.failed(action.kind, "nobody trades with themselves")
	if ActionScene.inventory_of(other) == null or ActionScene.inventory_of(actor) == null:
		return ActionOutcome.failed(action.kind, "only a character trades")
	var gap := _between(actor, other)
	if gap > REACH:
		return ActionOutcome.failed(action.kind, "%s is out of reach (%.2f > %.2f)" % [
			ActionScene.name_of(other), gap, REACH,
		])
	if scene.fight != null and (actor.fighting or other.fighting):
		return ActionOutcome.failed(action.kind, "there is a fight on")
	return null


# Whether an object can be reached into: it exists, it holds things, it is open,
# and it is within arm's length.
static func _reachable_container(
	actor: Combatant, thing: WorldObject, action: Action, asked_for: int
) -> ActionOutcome:
	if thing == null:
		return ActionOutcome.failed(
			action.kind, "there is nothing with id %d" % asked_for)
	if not thing.holds_things():
		return ActionOutcome.failed(
			action.kind, "a %s holds nothing" % thing.object_name)
	var gap := thing.distance_from(actor.x, actor.z)
	if gap > REACH:
		return ActionOutcome.failed(action.kind, "the %s is out of reach (%.2f > %.2f)" % [
			thing.object_name, gap, REACH,
		])
	if not thing.is_open():
		return ActionOutcome.failed(action.kind, "the %s is shut%s" % [
			thing.object_name,
			"" if thing.needs == "" else ": it needs a %s" % thing.needs,
		])
	return null


# --- Reading the world ----------------------------------------------------


# The character sheet behind a combatant, or null for anything that has none. A
# minion is a piece and not a character: it is commanded, and choosing is what
# this whole layer is for.
static func _sheet_of(one: Combatant) -> Character:
	if one == null or one.piece == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet


# The first thing carried whose item is called this, or null. Entries are
# addressed by the name of the item behind them, because that is the name a
# report prints and the name whoever chose the action read.
static func _carried_named(pack: Inventory, called: String) -> Variant:
	if pack == null or called == "":
		return null
	for entry in pack.carried:
		var item := Inventory.item_of(entry)
		if item != null and item.item_name == called:
			return entry
	return null


# Every named thing, as entries, or null when any of them is not carried. All or
# nothing, because a trade is.
static func _all_carried_named(pack: Inventory, called: PackedStringArray) -> Variant:
	var found := []
	for one_name in called:
		var entry: Variant = _carried_named(pack, one_name)
		if entry == null or found.has(entry):
			return null
		found.append(entry)
	return found


# How far a character is from a position, across the ground.
static func _distance_from(one: Combatant, to: Vector2) -> float:
	return Vector2(one.x - to.x, one.z - to.y).length()


# How far two characters are apart, across the ground.
static func _between(one: Combatant, other: Combatant) -> float:
	return one.distance_to(other)


## What can be seen of a thing from outside: its kind, how hurt it looks, and
## what it has on -- and for an object, whatever `WorldObject.observed()` says.
##
## Public because it is asked twice now and must be answered once. `_examine`
## asks it of one thing a character has aimed at; `Observation` asks it of
## everything a character can see, which is section 10's observation. A second
## reading of "how hurt does that look" would be a second answer to it.
static func observed_of(thing: Variant) -> Dictionary:
	if thing is WorldObject:
		return thing.observed()
	var one := thing as Combatant
	var piece := one.piece
	var seen := {
		"id": one.id,
		"name": ActionScene.name_of(one),
		"kind": piece.kind_name(),
		"health": _health_word(piece),
		"fighting": one.fighting,
	}
	var pack := ActionScene.inventory_of(one)
	if pack != null:
		var worn := PackedStringArray()
		for slot in pack.equipment():
			var item := Inventory.item_of(pack.equipment()[slot])
			worn.append("%s=%s" % [slot, "-" if item == null else item.item_name])
		seen["equipment"] = " ".join(worn) if not worn.is_empty() else "-"
	return seen


# How hurt somebody looks, in the words somebody looking would use. Section 10's
# observation gives "health state if visible", which is a state and not a number.
static func _health_word(piece: Piece) -> String:
	if not piece.is_alive():
		return "down"
	var share := float(piece.health) / float(maxi(1, piece.max_health()))
	if share >= 1.0:
		return "unhurt"
	if share >= 0.5:
		return "hurt"
	return "badly hurt"
