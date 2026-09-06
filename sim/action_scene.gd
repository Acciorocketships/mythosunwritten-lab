extends RefCounted
## Everything an atomic action can reach: who is standing where, what is lying
## about, what has been offered to whom, and what has been said.
##
## This is state and nothing else. It decides nothing, refuses nothing and
## resolves nothing -- every rule about what may happen lives in `ActionEngine`,
## so that "the engine resolves the action" is a fact about where the code is and
## not a claim in a comment. What this class contributes is the two things the
## rules need and cannot invent: a world to read, and one id space to name it
## with.
##
## ## One id space over characters and objects
##
## Section 10 gives an agent its surroundings as one numbered list -- "nearby
## entities: id; type (NPC/player/monster/object)" -- so a target is an id and
## the caller never has to know which sort of list a thing came from. Ids are
## handed out here, from one counter, to characters and objects alike. That is
## why the scene owns the actors rather than borrowing `CombatantRoster`'s: the
## roster numbers combatants out of its own counter for its own fights, and two
## counters over one id space is the drift this file exists to avoid.
##
## ## The fight is the combat layer's, and driving it is this file's
##
## A scene may have an `Encounter` under way, and it is exactly the encounter the
## world's own roster would have begun: the same board, the same seating, the
## same turn economy. `ActionEngine.attack` hands the blow to it rather than
## resolving one itself, because the damage matrix is section 3.7's and lives in
## one file (`CombatResolution`), and a second path to it would be a second
## answer to the same question.
##
## What is new here is that the *cycle* -- begin, advance, conclude -- is this
## file's too, in `fight_step()`. It used to be `CombatantRoster.step`'s, and a
## scenario built on the action surface had to re-apply the roster's four rules
## by hand to hold a fight at all. The four now exist once, here:
##
##   * **who fights** -- two commanders of different bands within
##     `ENGAGE_RADIUS` of each other, pairs walked in id order (`_two_who_have_met`).
##   * **how near is near enough** -- `ENGAGE_RADIUS`, the constant itself.
##   * **the cadence** -- one whole turn per call to `fight_step()`, through
##     `Encounter.advance`, which is the only place that call is made under `sim/`.
##   * **the ordering inside a tick** -- a fight that is on takes its turn before
##     anything else is asked, and a fight that ends on a tick does not start
##     another on the same tick.
##
## `CombatantRoster` now walks its combatants in real time and calls
## `fight_step()`; it holds no rule of its own about when a fight begins.
##
## ## A turn lasts as long as the weapon action that spends it
##
## The fifth rule of the cycle, and the one that makes a commander on the board
## something other than a spectator in its own fight. An atomic attack takes
## ticks to carry out; a turn is what section 3.6 spends a weapon action out of.
## Neither number can be made to fit the other, so the turn waits: while the
## commander whose turn it is is part-way through an `attack` it committed to,
## `fight_step()` plays no turn at all. The tick that span runs out, the blow is
## resolved -- still on its own turn -- and spends that turn's one weapon action;
## the turn is then played out and passes on.
##
## Only an attack holds a turn, because only an attack is spent out of one. A
## commander doing anything else, or one that has committed nothing at all when
## its turn comes up, holds nothing: the turn is played at once and it has
## passed. So the longest the board can ever wait is one attack's span, and it
## never waits on a decision that has not been made.
##
## What is part-way through is not held here. `in_progress` is a window onto
## whatever is driving the characters -- `ControlLoop` fills it in -- so there is
## one account of what a character is doing and this file only reads it. A scene
## nobody drives leaves it unset and every turn is played the tick it comes up,
## which is what the world's own roster does and why the world's fights are
## exactly what they were.
class_name ActionScene

## How close two commanders of different bands have to come, in world units, for
## a fight to begin. Three lattice cells -- near enough that the two are already
## in each other's neighbourhood when the board appears under them.
##
## This constant used to live on `CombatantRoster`. It is here because the rule
## that reads it is here, and reading it from anywhere else is naming this file.
const ENGAGE_RADIUS := 9.0

## The ground, for walking on and settling onto. May be null: a scene with no
## terrain is a bare stage, which is what the failure cases and the interface
## checks are played on, and every rule that needs the ground says so.
var terrain: TerrainQuery = null

## How many ticks the scene has been advanced. What a `wait` is counted in.
var tick: int = 0

## Everyone who can act, in the order they were added, which is id order.
var actors: Array[Combatant] = []

## Everything else in the world, in the order it was added.
var objects: Array[WorldObject] = []

## Every ability check the world has raised, in the order it raised them.
##
## The world raises one and goes on turning. Nothing here settles a check: this
## is a queue with the raised checks left in it, and whatever is running the world
## advances them. A scene nobody advances simply carries a raised check that never
## got an answer, which is the honest state of affairs and not an error.
var raised: Array[AbilityCheck] = []

## The fight under way, or null.
var fight: Encounter = null

## What each character is part-way through, as `func(id: int) -> Action`.
##
## Set by whatever is stepping the characters, and read by `fight_step()` alone.
## Unset in a scene nobody steps, and an unset one answers for nobody -- so a
## fight in such a scene takes a turn every time it is asked, exactly as it did
## before the turn ever waited for anything.
var in_progress := Callable()

## How many fights have begun and how many have ended. Diagnostic, and what a
## test asserts against so that "a fight happened" is a number rather than a
## reading of the transcript.
var fights_begun: int = 0
var fights_ended: int = 0

## How many boards have been built for a fight, refused ones included. A viewer
## watches this rather than the board itself, exactly as it watches the water
## sheet's version, so it only re-reads the lattice when there is a new lattice
## to read.
var board_version: int = 0

## Everything that has been written down about the fights this scene has held,
## in order. Named for what is in it, because `lines()` below is the scene's own
## description and these are not part of it.
var fight_lines := PackedStringArray()

## Every trade offered and not yet answered, newest last. One row per offer:
## `{"from": id, "to": id, "give": names, "give_money": int, "want": names,
## "want_money": int}`.
var offers: Array[Dictionary] = []

## Every offer that was denied, as `{"from": id, "to": id}`. Kept after the offer
## itself is gone, so accepting a refused trade is refused *as* refused rather
## than as never having existed.
var refusals: Array[Dictionary] = []

## Everything said, in order: `{"speaker": id, "text": String, "to": id,
## "shout": bool, "heard_by": PackedInt32Array}`.
var said: Array[Dictionary] = []

## Every trade the engine has actually honoured, in order:
## `{"from": id, "to": id, "tick": int, "gave": int, "gave_money": int,
## "back": int, "back_money": int}`. Written on the one path a trade goes
## through and by nothing else, so it is the world's own account of a trade
## having happened rather than a second one kept beside it.
##
## The four counts say what was actually in it, which is what makes a gift
## readable off this record: a gift is section 2.1's "trade with nothing in
## return", so it is an honoured trade whose other half was empty, and it is not
## a second kind of event kept somewhere else.
##
## It is here for the same reason `actions_taken` is: something outside the
## engine needs to be able to ask what has actually happened without holding
## whatever made it happen. What asks is `GoalCheck`, which answers a character's
## "have traded with #2" out of this and never out of the character.
var trades: Array[Dictionary] = []

## Every blow the engine has landed through an `attack`, in order:
## `{"from": id, "to": id, "tick": int, "dealt": int, "out_of": int}`. The
## world's own record of a blow struck, written by `ActionEngine` on the one path
## an attack takes.
var blows: Array[Dictionary] = []

## Every relationship in this world: section 10's graph of edges between
## entities, held here because it is the world's and not any character's.
##
## Nothing in this file writes to it. What moves an edge is a happening the
## engine has already written down above -- a line heard, a trade honoured, a
## blow landed -- folded in by `sim/character_upkeep.gd`, the path every
## character passes whoever is deciding for it. See `sim/relationship_graph.gd`
## for which field each happening moves and why.
var relationships: RelationshipGraph = RelationshipGraph.new()

## Which tick each character is idle until, by id: the engine's own record of a
## `wait` it has just resolved. The control loop does not read it -- it counts a
## wait's ticks itself, out of the same catalogue column every other action's
## cost comes from, so there is one account of how long an action takes and not
## two. Nothing here enforces it either, because being idle is not the same as
## being unable to change your mind.
var idle_until: Dictionary = {}

## How many actions each character has attempted, by id.
##
## The world's own count of what has been handed in for a character to do,
## written by `ActionEngine` the moment a choice reaches somebody who could act
## on it and by nothing else. It counts choices resolved and not questions:
## asking a character what it wants to do next changes nothing here, which is
## what makes it something a decision function can read its own position out of
## without holding whatever is driving it (`DecisionSource.plan`).
##
## A choice the catalogue cannot read is counted with the rest, because it is a
## turn the character spent: the engine refuses it in the catalogue's own words
## and moves nothing in the world, but the character has had its go. Leaving it
## uncounted left every mind in the project offering the same unreadable line
## back for the rest of the run -- see the note on `ActionEngine.resolve`. The
## refusals that are about the world rather than the choice are not counted.
##
## `ControlLoop.actions_of` counts the same thing for the characters that one
## loop resolved for; this counts it for the scene, whatever drove it.
var actions_taken: Dictionary = {}

## How many asks that cost the world no time each character has made since it
## last spent a turn, by id.
##
## The three tools a mind may answer with instead of an action -- `recall`,
## `learn`, `done` -- return on the tick they are asked and move nothing here in
## the world, so nothing about the world stops one being asked again at once.
## This is the count that lets `ToolBudget` say when one of them has to start
## costing something; the rule about how many are free, and what the next one
## costs, is that file's and not this one's.
var asks_taken: Dictionary = {}

## Which tick each character stands until, having spent a turn on one of those,
## by id.
##
## Not the same thing as `idle_until` above, which is a character's own `wait`
## and binds nobody: this is a turn the world took off a character, and
## `ControlLoop` will not ask it for a choice until the tick comes round --
## exactly as it would not ask a character part-way through an action.
var spent_until: Dictionary = {}

## The walk each character is part-way through, by id.
##
## A `go_to` is the one action whose effect is a journey rather than an instant,
## so it is the one action that is part-way done while its span runs. This is
## where that half-finished journey is kept between one tick and the next:
## `ControlLoop` advances it a stride a tick and `ActionEngine._go_to` finishes
## it, and both reach it through `ActionEngine.walk_under_way` so there is one
## walk per character rather than one per caller.
##
## It sits beside `idle_until` and `spent_until` for the same reason those do:
## it is something the world remembers about a character between two calls, and
## the engine is static.
var walks: Dictionary = {}

## Every such ask the world has refused, in order:
## `{"id": id, "tick": int, "why": String}`. The world's own account of what it
## charged whom, written by `ToolBudget` and read by whatever wants to report it.
var asks_refused: Array[Dictionary] = []

# One counter over everything in the scene.
var _next_id: int = 1
var _next_check: int = 1


## An empty scene, on some ground or on none.
static func on(ground: TerrainQuery = null) -> ActionScene:
	var scene := ActionScene.new()
	scene.terrain = ground
	return scene


# --- Putting things in it -------------------------------------------------


## Put a character in the world, giving it an id out of the one counter. A
## commander is made its own band, exactly as the roster does it, so "everyone in
## this band" is one comparison and includes the commander.
func add_actor(one: Combatant) -> Combatant:
	one.id = _next_id
	_next_id += 1
	if one.is_commander():
		one.band = one.id
	one.settle(terrain) if terrain != null else null
	actors.append(one)
	return one


## Put an object in the world, out of the same counter.
func add_object(thing: WorldObject) -> WorldObject:
	thing.id = _next_id
	_next_id += 1
	thing.settle(terrain)
	objects.append(thing)
	return thing


## Take an object out of the world. What an emptied pile does: a pile is a place
## items are, and when there are none it is not a place at all.
func remove_object(thing: WorldObject) -> bool:
	var at := objects.find(thing)
	if at < 0:
		return false
	objects.remove_at(at)
	return true


## Raise an ability check on the world, because something in it warranted one.
##
## `ActionEngine`'s to call, from the one hook named in `AbilityCheck.HOOK`, and
## the whole of what the world does about a check: it writes down that one was
## attempted and returns. What class it is, what it is rolled against, whether it
## passes and what follows are all somebody else's, later.
func raise_check(
	actor: Combatant, thing: WorldObject, offered: String
) -> AbilityCheck:
	var check := AbilityCheck.raised_by(
		_next_check, tick, actor.id, name_of(actor),
		thing.id, thing.object_name, offered)
	_next_check += 1
	raised.append(check)
	return check


# --- Finding things in it -------------------------------------------------


## The character with an id, or null.
func actor_of(id: int) -> Combatant:
	for one in actors:
		if one.id == id:
			return one
	return null


## The object with an id, or null.
func object_of(id: int) -> WorldObject:
	for thing in objects:
		if thing.id == id:
			return thing
	return null


## Whatever has an id -- a character or an object -- or null.
func thing_of(id: int) -> Variant:
	var one := actor_of(id)
	return one if one != null else object_of(id)


## Where anything in the scene stands, across the ground.
static func position_of(thing: Variant) -> Vector2:
	if thing is Combatant or thing is WorldObject:
		return Vector2(thing.x, thing.z)
	return Vector2.ZERO


## What a thing is called, for a reason and for a report.
static func name_of(thing: Variant) -> String:
	if thing is Combatant:
		var piece: Piece = thing.piece
		if piece is Commander and piece.sheet.character_name != "":
			return piece.sheet.character_name
		return "#%d" % thing.id
	if thing is WorldObject:
		return thing.object_name
	return "nothing"


## Every pile lying within a distance of a position, nearest first and by id
## where two are equally near, so which pile a drop joins is decided the same way
## in every process.
func piles_near(at: Vector2, within: float) -> Array[WorldObject]:
	var found: Array[WorldObject] = []
	for thing in objects:
		if not thing.pile or not thing.is_open():
			continue
		if thing.distance_from(at.x, at.y) <= within:
			found.append(thing)
	found.sort_custom(func(left: WorldObject, right: WorldObject) -> bool:
		var near_left := left.distance_from(at.x, at.y)
		var near_right := right.distance_from(at.x, at.y)
		if near_left == near_right:
			return left.id < right.id
		return near_left < near_right)
	return found


# --- Offers ---------------------------------------------------------------


## The offer standing from one character to another, or an empty dictionary.
func offer_between(from_id: int, to_id: int) -> Dictionary:
	for offer in offers:
		if offer["from"] == from_id and offer["to"] == to_id:
			return offer
	return {}


## Record an offer, replacing whatever that pair had standing, and clearing any
## refusal between them: proposing again is a fresh question.
func set_offer(offer: Dictionary) -> void:
	clear_offer(offer["from"], offer["to"])
	_forget_refusal(offer["from"], offer["to"])
	offers.append(offer)


## Take an offer off the table. Returns whether one was there.
func clear_offer(from_id: int, to_id: int) -> bool:
	for index in offers.size():
		if offers[index]["from"] == from_id and offers[index]["to"] == to_id:
			offers.remove_at(index)
			return true
	return false


## Write down that an offer was denied.
func record_refusal(from_id: int, to_id: int) -> void:
	if not was_refused(from_id, to_id):
		refusals.append({"from": from_id, "to": to_id})


## Whether the last thing that happened between this pair was a denial.
func was_refused(from_id: int, to_id: int) -> bool:
	for refusal in refusals:
		if refusal["from"] == from_id and refusal["to"] == to_id:
			return true
	return false


func _forget_refusal(from_id: int, to_id: int) -> void:
	for index in refusals.size():
		if refusals[index]["from"] == from_id and refusals[index]["to"] == to_id:
			refusals.remove_at(index)
			return


# --- The fight ------------------------------------------------------------


## One tick of whichever fight is on, or of the one that is about to begin. The
## whole of the real-time -> board -> real-time cycle, and the only place under
## `sim/` that holds it.
##
## Every driver calls this once per tick, *after* the tick's characters have been
## serviced -- the world's roster after its combatants have walked, a scenario
## after its control loop has run -- so a fight that begins on one tick is
## noticed as an interruption on the next.
##
## The order inside the call is the rule, and there are two halves of it:
##
##   * a fight that is on takes one whole turn, and if that turn finished it, the
##     survivors are handed back to real time in the same call;
##   * only when no fight is on is the pairing rule asked, so a fight that ends
##     on a tick does not immediately start another with whoever is still
##     standing next to it.
##
## Returns what happened, as four fields, because a caller writing a transcript
## needs to interleave its own lines with these: `began` is the anchoring
## commander when a fight began this tick and null otherwise, `lines` is what the
## fight wrote (the snap-in, or the turn), `ended` is whether it finished, and
## `over` is the snap-out. Nothing here formats anything; how a run announces a
## fight is the run's business.
func fight_step() -> Dictionary:
	var turn := {
		"began": null,
		"lines": PackedStringArray(),
		"ended": false,
		"over": PackedStringArray(),
	}
	if fight != null:
		if _turn_is_being_spent():
			# The commander whose turn it is is part-way through the weapon
			# action that turn will spend. Nothing is played until it lands.
			return turn
		turn["lines"] = fight.advance()
		if fight.finished:
			turn["ended"] = true
			turn["over"] = end_fight()
		return turn
	if terrain == null:
		return turn
	var anchor := _two_who_have_met()
	if anchor == null:
		return turn
	turn["began"] = anchor
	var started := begin_fight(anchor.id)
	turn["lines"] = started.lines
	return turn


## Begin a fight around one character: everyone near enough joins, the board is
## read off the terrain under them, and the turn economy takes it from there.
##
## Returns the encounter whether or not it could be held; an encounter that could
## not seat everybody comes back with `refused` set and nobody moved, and the
## scene is left with no fight on -- which is the combat layer's own stop
## condition, forwarded rather than worked around. A refused board still counts
## as a board built, because one was.
func begin_fight(anchor_id: int) -> Encounter:
	var anchor := actor_of(anchor_id)
	if terrain == null or anchor == null:
		return null
	var started := Encounter.begin(terrain, actors, anchor)
	board_version += 1
	if started.refused:
		# Nobody was seated and nobody was moved. The world carries on in real
		# time and the refusal is on the record.
		fight = null
		fight_lines.append_array(started.lines)
		return started
	fight = started
	fights_begun += 1
	return started


## End the fight, putting the survivors back in the world where their last cells
## say. The encounter's own snap-out, called rather than reproduced.
func end_fight() -> PackedStringArray:
	if fight == null:
		return PackedStringArray()
	var written := fight.conclude()
	_drop_the_fallen()
	fight_lines.append_array(fight.lines)
	fight = null
	fights_ended += 1
	return written


## Whether the turn being played is already spoken for: the commander whose turn
## it is has committed to a weapon action and has not carried it out yet.
##
## Anything else it might be part-way through is not spent out of a turn, so the
## turn does not wait for it -- and neither does the fight wait on a character
## that has committed nothing, which is the whole of why a slow decision cannot
## stall a board.
func _turn_is_being_spent() -> bool:
	if not in_progress.is_valid():
		return false
	var acting := fight.active_member()
	if acting == null:
		return false
	var doing: Variant = in_progress.call(acting.id)
	return doing is Action and doing.kind == ActionCatalog.ATTACK


## Whether a character is on the board of the fight under way.
func is_fighting(one: Combatant) -> bool:
	return fight != null and one != null and one.fighting


## Whether two commanders of different bands have come close enough, and if so,
## which of them the fight is anchored on.
##
## Pairs are walked in id order and the first pair found starts the fight, so
## which of several simultaneous meetings becomes the fight is decided the same
## way in every process. The lower-id one of the pair anchors the board, because
## a board is anchored on a position somebody is standing at.
func _two_who_have_met() -> Combatant:
	for i in actors.size():
		var one := actors[i]
		if not one.is_commander() or not one.is_alive():
			continue
		for j in range(i + 1, actors.size()):
			var other := actors[j]
			if not other.is_commander() or not other.is_alive():
				continue
			if other.band == one.band:
				continue
			if one.distance_to(other) > ENGAGE_RADIUS:
				continue
			return one
	return null


## Take the fallen out of the world, leaving behind whatever fell off them. A
## combatant whose piece is no longer on the board is gone -- including one
## despawned by the king rule, which never lost a hit point, which is why this
## asks the fight rather than reading a health.
##
## What is left is `Inventory.spill_into`: each carried item rolled on its own
## one-in-five stream by the drop layer, exactly as it has always been rolled.
## Not one number of the drop rule is decided here, and this file does not name
## that layer -- it asks the inventory, which is the same call a gift and a
## purchase go through. This is only the place the roll finally has a floor to
## land on, which is a pile at the position the character was standing when it
## went down.
##
## An empty pile is not made. A defeat where nothing fell leaves nothing, which
## is what "each item drops with some probability" means at the bottom of the
## distribution and is also what keeps a long fight from littering the meadow
## with things nobody can pick up.
func _drop_the_fallen() -> void:
	var gone := {}
	for one in fight.fallen():
		gone[one.id] = true
	if gone.is_empty():
		return
	var kept: Array[Combatant] = []
	for one in actors:
		if not gone.has(one.id):
			kept.append(one)
		else:
			_leave_what_fell(one)
	actors = kept


## Roll one defeated character's gear onto the ground where it fell.
##
## The kill is addressed by the character's id, which is unique in the scene's
## one id space and never reused, so the same world seed and the same defeat
## produce the same drops however the fight got there. A minion carries nothing
## -- it has no sheet -- and so leaves nothing.
func _leave_what_fell(one: Combatant) -> WorldObject:
	var pack := inventory_of(one)
	if pack == null or pack.size() == 0:
		return null
	var pile := WorldObject.loose(one.x, one.z)
	var seed_of_the_world := 0 if terrain == null else terrain.world_seed
	if pack.spill_into(pile.contents, seed_of_the_world, kill_label(one)).is_empty():
		return null
	return add_object(pile)


## How a defeat is named to the drop layer: `fallen#<id>`.
##
## Public because a report and a test both have to be able to say which stream a
## verdict came off, and a claim about which streams exist is worth more when the
## name can be read next to the number it produced.
static func kill_label(one: Combatant) -> String:
	return "fallen#%d" % (0 if one == null else one.id)


# --- Time -----------------------------------------------------------------


## Advance the scene's clock. The control loop's business, and here only so that
## a `wait` has something to be counted against.
func advance(ticks: int = 1) -> int:
	tick += maxi(0, ticks)
	return tick


## Which tick a character is idle until.
func idle_of(id: int) -> int:
	return int(idle_until.get(id, 0))


## How many actions a character has attempted.
func actions_of(id: int) -> int:
	return int(actions_taken.get(id, 0))


## Count one action as attempted for a character. `ActionEngine`'s to call, on
## the one path every action takes, so that one action attempted is one count --
## including one the catalogue refused, which is a turn spent all the same.
##
## It also forgets how many asks that cost the world no time the character has
## made, because `asks_taken` counts them *since the character last took a turn
## on an action* and this is that turn. One definition, maintained where the
## thing it is defined against moves. The one caller that counts a turn for
## something other than an action -- `ToolBudget`, charging for an ask -- puts
## the count straight back afterwards, because a look is not an action.
func note_action(id: int) -> void:
	actions_taken[id] = actions_of(id) + 1
	clear_asks(id)


## How many asks that cost the world no time a character has made since it last
## spent a turn.
func asks_of(id: int) -> int:
	return int(asks_taken.get(id, 0))


## Count one of those asks for a character. `ToolBudget`'s to call, on the one
## path all three tools take.
func note_ask(id: int) -> void:
	asks_taken[id] = asks_of(id) + 1


## Forget how many a character has made, which is what taking a turn on an
## action does.
func clear_asks(id: int) -> void:
	asks_taken[id] = 0


## Set how many a character is to be counted as having made. `ToolBudget`'s to
## call: the count means something the rule decides, so the rule is what puts a
## number back into it.
func keep_asks(id: int, count: int) -> void:
	asks_taken[id] = maxi(0, count)


## The walk a character is part-way through, or null.
func walk_of(id: int) -> Walk:
	return walks.get(id, null)


## Remember the walk a character is part-way through.
func set_walk(id: int, leg: Walk) -> void:
	walks[id] = leg


## Forget it: the walk was resolved, or abandoned where it had reached. Either
## way the character stays where it actually got to -- a walk is not undone by
## being given up on.
func clear_walk(id: int) -> void:
	walks.erase(id)


## Which tick a character stands until, having spent a turn on one of those.
func spent_until_of(id: int) -> int:
	return int(spent_until.get(id, 0))


## Write down one such ask the world refused, and the tick the character stands
## until for it. `ToolBudget`'s to call, on the one path a refusal takes.
func note_ask_spent(id: int, until: int, why: String) -> void:
	spent_until[id] = until
	asks_refused.append({"id": id, "tick": tick, "why": why})


## Write down one trade the engine has honoured. `ActionEngine`'s to call, on the
## one path a trade goes through.
func note_trade(
	from_id: int, to_id: int,
	gave: int = 0, gave_money: int = 0, back: int = 0, back_money: int = 0
) -> void:
	trades.append({
		"from": from_id, "to": to_id, "tick": tick,
		"gave": gave, "gave_money": gave_money,
		"back": back, "back_money": back_money,
	})


## Write down one blow the engine has landed: who swung, who was hit, how much it
## took and how much that character has at full. `ActionEngine`'s to call, on the
## one path an attack takes.
##
## Here for the same reason `trades` is: the world needs to be able to say what
## has happened in it without holding whatever made it happen. What reads it is
## `CharacterUpkeep`, folding it into the relationship graph; nothing else does,
## and nothing here decides what a blow *means*.
func note_blow(from_id: int, to_id: int, dealt: int, out_of: int) -> void:
	blows.append({
		"from": from_id, "to": to_id, "tick": tick,
		"dealt": dealt, "out_of": out_of,
	})


# --- Description ----------------------------------------------------------


## Everything in the scene, one line each: the characters, what each carries,
## then the objects, then anything said. What a report prints and what a test
## compares.
func lines() -> PackedStringArray:
	var written := PackedStringArray()
	written.append("tick %d actors=%d objects=%d offers=%d" % [
		tick, actors.size(), objects.size(), offers.size(),
	])
	for one in actors:
		written.append("  " + one.line())
		var pack := inventory_of(one)
		if pack != null:
			written.append("    carries %s" % pack.fingerprint())
	for thing in objects:
		written.append("  " + thing.line())
	for check in raised:
		written.append("  " + check.line())
	for spoken in said:
		written.append("  said #%d %s \"%s\" heard by %s" % [
			spoken["speaker"],
			"to #%d" % spoken["to"] if not spoken["shout"] else "aloud",
			spoken["text"],
			"nobody" if PackedInt32Array(spoken["heard_by"]).is_empty()
				else str(Array(spoken["heard_by"])),
		])
	return written


## What a character carries, or null for anything that carries nothing. The one
## place the action layer reaches through a combatant to its character sheet.
static func inventory_of(one: Combatant) -> Inventory:
	if one == null or not (one.piece is Commander):
		return null
	return (one.piece as Commander).sheet.inventory


## A short, stable fingerprint of everything an action can move.
##
## This is what "the same choice produces the same world change" is measured
## with: two scenes that were set out identically and driven identically
## fingerprint identically, whatever drove them.
func fingerprint() -> String:
	var parts := PackedStringArray()
	parts.append("tick=%d" % tick)
	for one in actors:
		var pack := inventory_of(one)
		parts.append("#%d %s (%.3f, %.3f, %.3f) hp=%d %s" % [
			one.id, name_of(one), one.x, one.y, one.z, one.piece.health,
			"-" if pack == null else pack.fingerprint(),
		])
	for thing in objects:
		parts.append(thing.fingerprint())
	for offer in offers:
		parts.append("offer %d->%d give=[%s] %d want=[%s] %d" % [
			offer["from"], offer["to"],
			", ".join(PackedStringArray(offer["give"])), offer["give_money"],
			", ".join(PackedStringArray(offer["want"])), offer["want_money"],
		])
	for refusal in refusals:
		parts.append("refused %d->%d" % [refusal["from"], refusal["to"]])
	for spoken in said:
		parts.append("said %d->%d %s [%s]" % [
			spoken["speaker"], spoken["to"], spoken["text"],
			", ".join(PackedStringArray(Array(spoken["heard_by"]).map(
				func(id: int) -> String: return str(id)))),
		])
	for id in idle_until:
		parts.append("idle %d until %d" % [id, idle_until[id]])
	parts.append("relationships %s" % relationships.fingerprint())
	for check in raised:
		parts.append("check %d %s %s %s %d+%d vs %d" % [
			check.id, check.context, check.state,
			"passed" if check.passed else "failed",
			check.score, check.roll, check.difficulty,
		])
	return "|".join(parts).sha256_text().substr(0, 16)
