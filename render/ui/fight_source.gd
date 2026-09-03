extends RefCounted
## The one place the interface reaches into the simulation for a fight.
##
## The readout is a view onto the fight the simulation is holding -- the same
## objects, not copies of them -- so this file's whole job is to hand the panel
## a live handle and then get out of the way. Everything the readout shows it
## reads through here on every frame: whose turn it is, the order the commanders
## act in, and, for the commander whose turn it is, each weapon action's name,
## its cooldown and how much of that cooldown is left. Nothing is stored here
## and nothing is stored in the panel, so there is no second copy of a turn
## order or a cooldown for the two sides to disagree about.
##
## ## Why the hops are dynamic, and why that is the smaller sin
##
## `tests/layer_check.gd` lists every name of the combat layer the render side
## may not hold -- the units, the board's rules, the match, the roster, gear --
## because a shell that names one of them has started to keep a piece of the
## fight rather than to read one. `render/ui/sheet_source.gd` already takes one
## step through a `Variant` for the same reason: the type between the roster and
## a character sheet is one of the combat layer's own. This file takes the same
## kind of step three times over, and each is a read.
##
## The alternative would have been to widen the simulation's own snapshot until
## it carried a turn order and a cooldown table, and that is exactly the second
## copy this design is built to avoid: a snapshot is a copy by construction, and
## a cooldown copied on a tick is a cooldown that can be wrong on the next.
## Nothing under sim/ changed for this readout.
##
## ## What is actually being read
##
## The fight keeps, for each of the commander's weapon actions, the turn it next
## becomes available on. So "available now" is a comparison against the turn
## being played, and "three turns left" is a subtraction -- both of them the
## simulation's own answers, asked through its own methods
## (`can_attack`, `turns_until_ready`), never worked out again here.
##
## One consequence is worth stating because the readout leans on it. An action
## used on turn `t` with a cooldown of `c` becomes ready on `t + c`, so on turn
## `t` itself it reads exactly `c` turns remaining -- its whole cooldown, which
## no other reading of it can produce. That is how the readout knows which blow
## was struck this round without remembering anything: the action whose remaining
## cooldown equals its own full cooldown is the one that was just spent.
class_name FightSource

## What a fight's round is when there is no fight.
const NO_ROUND := 0


## The fight under way in a world, or null. An `Object` rather than its own type
## on purpose: see the note above.
static func fight_in(world: SimWorld) -> Object:
	if world == null or world.combat == null:
		return null
	var on: Variant = world.combat.fight
	return on if on is Object else null


## The match being played in that fight, or null when no fight is on.
static func state_in(world: SimWorld) -> Object:
	var on := fight_in(world)
	if on == null:
		return null
	var playing: Variant = on.match_state
	return playing if playing is Object else null


## Which round is being played. One round is one turn per commander, and a
## cooldown counted in turns is counted in these.
static func round_of(state: Object) -> int:
	return NO_ROUND if state == null else int(state.round_number)


## The commanders still in the fight, in the order they take their turns.
static func order_of(state: Object) -> PackedInt32Array:
	if state == null:
		return PackedInt32Array()
	var order: Variant = state.commanders()
	return order if order is PackedInt32Array else PackedInt32Array()


## Whose turn it is, by the id the match knows them by.
static func active_of(state: Object) -> int:
	return 0 if state == null else int(state.active_id())


## The commander standing on the board under one of those ids, or null.
##
## The fight's own map from the ids the match counts turns in to the people
## standing in the world; the piece is one property further in, and it is the
## object the fight is being played with rather than a description of it.
static func standing_in(on: Object, id: int) -> Object:
	if on == null:
		return null
	var member: Variant = on.by_piece.get(id, null)
	if member == null:
		return null
	var standing: Variant = member.piece
	return standing if standing is Object else null


## The character sheet of one of those commanders, or null.
static func sheet_in(on: Object, id: int) -> Character:
	var standing := standing_in(on, id)
	if standing == null:
		return null
	var sheet: Variant = standing.sheet
	return sheet if sheet is Character else null


## What one of them is called: its own name, or the id it is known by while it
## has none. A world with no character layer in it yet is full of the second.
static func name_in(on: Object, id: int) -> String:
	var sheet := sheet_in(on, id)
	if sheet == null or sheet.character_name == "":
		return "#%d" % id
	return sheet.character_name


## How hurt one of them is: what it has left and the most it can have.
static func health_in(on: Object, id: int) -> Vector2i:
	var standing := standing_in(on, id)
	if standing == null:
		return Vector2i.ZERO
	return Vector2i(int(standing.health), int(standing.max_health()))


## Every weapon action of a commander, on a given turn, in the weapon's own
## order.
##
## Each row is
##
##     {"name", "ready", "remaining", "cooldown", "sprite", "animation",
##      "struck"}
##
## and every value in it is read out of the simulation at the moment the row is
## made: whether the action may be used now, how many turns until it may be, how
## long its wait is in this commander's hands, and the two tags saying what it
## looks like and what it looks like happening. `struck` is the reading set out
## at the head of this file -- the whole cooldown remaining, which only the turn
## it was spent on produces.
##
## Nothing keeps these rows. They are made when the panel asks and dropped when
## it has drawn them.
static func actions_in(standing: Object, turn: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if standing == null:
		return rows
	for index in int(standing.attack_count()):
		var one: Variant = standing.attack_at(index)
		if one == null:
			continue
		var waits := int(standing.cooldown_of(index))
		var left := int(standing.turns_until_ready(index, turn))
		rows.append({
			"name": String(one.attack_name),
			"ready": bool(standing.can_attack(index, turn)),
			"remaining": left,
			"cooldown": waits,
			"sprite": String(one.sprite_tag),
			"animation": String(one.animation_tag),
			"struck": left > 0 and left == waits,
		})
	return rows


## The weapon action most recently resolved in the fight, or an empty dictionary
## when nothing on the board has been struck within its own cooldown.
##
## Read rather than remembered, and read out of the cooldowns themselves. An
## action with `r` turns left of a wait of `c` was spent `c - r` rounds ago, so
## the most recent blow still on record is the smallest of those differences
## across every commander -- with the turn order breaking a tie backwards from
## whoever is acting now, because the commander who acted least recently ago is
## the one nearest behind the active one.
##
## An action that is ready again keeps no record of when it was last used, so it
## is not a candidate: a blow is visible for as many rounds as the action that
## struck it waits, and no longer. Returns the row `actions_in` makes, with how
## many rounds ago it landed and the striker's name and id added.
static func last_blow(world: SimWorld) -> Dictionary:
	var on := fight_in(world)
	var state := state_in(world)
	if on == null or state == null:
		return {}
	var order := order_of(state)
	if order.is_empty():
		return {}
	var turn := round_of(state)
	var at := order.find(active_of(state))
	if at < 0:
		at = 0
	var best := {}
	var soonest := -1
	for step in range(order.size()):
		var id := order[posmod(at - step, order.size())]
		for row in actions_in(standing_in(on, id), turn):
			var left := int(row["remaining"])
			if left <= 0:
				continue
			var ago := int(row["cooldown"]) - left
			if soonest >= 0 and ago >= soonest:
				continue
			soonest = ago
			best = row.duplicate()
			best["rounds_ago"] = ago
			best["by"] = name_in(on, id)
			best["by_id"] = id
	return best
