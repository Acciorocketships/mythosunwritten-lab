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
## ## The blow itself comes the other way, through the snapshot
##
## Whose turn it is and what their weapons are ready for are read live, as above.
## The blow that was struck is not: the simulation writes every blow down as it
## lands (`ActionScene.blows`) and carries the most recent ones out in the
## snapshot this shell already receives, so `blow_in` below is a read of a
## dictionary and asks the fight nothing at all.
##
## That is what the rest of this milestone needs. A cooldown can say that an
## action was spent this round; it cannot say which way the striker was facing,
## which cells the blow covered, where it started, where it landed or which tick
## it began on -- and a swing cannot be animated, nor an arrow launched, without
## those. So there is one record of a blow, the simulation writes it, and this
## reads it.
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
##     {"name", "ready", "remaining", "cooldown", "sprite", "animation"}
##
## and every value in it is read out of the simulation at the moment the row is
## made: whether the action may be used now, how many turns until it may be, how
## long its wait is in this commander's hands, and the two tags saying what it
## looks like and what it looks like happening.
##
## These rows say what a commander *may* do. Which blow was actually struck is
## `blow_in` below, off the world's own record of it, and not a second reading of
## a cooldown -- one blow, one record.
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
		})
	return rows


## The snapshot of everyone in the world and everything that has just happened
## to them, as the simulation hands it out.
##
## The same dictionary `render/main.gd` already draws the world from; taking it
## here rather than reaching into the fight is the whole of why the blow below
## can be read without naming anything of the combat layer.
static func snapshot_of(world: SimWorld) -> Dictionary:
	if world == null or world.combat == null:
		return {}
	return world.combat.snapshot()


## The most recent blow still worth showing, out of a snapshot, or an empty
## dictionary when there is none.
##
## **Every value in what comes back is read out of the dictionary handed in.**
## Nothing here asks the fight anything: who struck, what they struck with, which
## way they were facing, which cells the pattern covered, where the blow started
## and where it landed, which art and which motion say so, whether it crossed the
## ground to get there and which tick it began on are all the simulation's own
## record of the blow, carried out in the snapshot (`ActionScene.blows`, through
## `CombatantRoster.blow_rows`). That is what the three items after this one need
## -- a swing cannot be animated off a cooldown and an arrow cannot be launched
## off one.
##
## Two things are added, both of them arithmetic on numbers in the same
## dictionary: `rounds_ago`, the rounds between the round the blow was struck on
## and the round being played, and `ticks_ago`, the same in the world's own
## clock, which is what an animation is timed against.
##
## Only the fight now on the board is considered, and only a blow struck within
## the wait of the action that struck it -- which is the reading the readout has
## always shown: a blow is the fight's most recent for as many rounds as its
## action waits, and no longer.
static func blow_in(snapshot: Dictionary) -> Dictionary:
	if not bool(snapshot.get("fighting", false)):
		return {}
	var struck: Array = snapshot.get("blows", [])
	var round_now := int(snapshot.get("round", NO_ROUND))
	var tick_now := int(snapshot.get("tick", 0))
	var here := int(snapshot.get("fights_begun", 0))
	for at in range(struck.size() - 1, -1, -1):
		var blow: Dictionary = struck[at]
		if int(blow.get("fight", 0)) != here:
			continue
		var ago := round_now - int(blow.get("round", 0))
		if ago < 0 or ago >= int(blow.get("cooldown", 1)):
			continue
		var showing := blow.duplicate(true)
		showing["rounds_ago"] = ago
		showing["ticks_ago"] = tick_now - int(blow.get("tick", 0))
		return showing
	return {}


## The same blow, for a caller holding the world rather than a snapshot of it.
static func last_blow(world: SimWorld) -> Dictionary:
	return blow_in(snapshot_of(world))
