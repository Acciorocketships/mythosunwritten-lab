extends RefCounted
## Everyone in the world who can fight, walking in real time, and whichever
## fight is under way.
##
## This is the layer that makes the overworld and the board one world. It holds
## the combatants, walks them once per tick, decides when a fight begins, hands
## the fight one turn per tick while it lasts, and takes the survivors back when
## it ends. Everything else in the simulation -- the ground, the streaming, the
## water, the islands, the observer -- is stepped by `SimWorld` and knows nothing
## about any of it.
##
## ## The three states, and there are only three
##
##   * **real time** -- every combatant walks, and every tick the scene is asked
##     whether two commanders of different bands have come within
##     `ActionScene.ENGAGE_RADIUS` of each other.
##   * **fighting** -- the fight takes one turn per tick. Every combatant that
##     did *not* join keeps walking, on the same tick, through the same call --
##     and it is the same call, because `Combatant.walk` does nothing for anyone
##     seated on a board.
##   * **real time again** -- the survivors are put down where their final cells
##     say, the fallen are dropped, and the roster is back in the first state.
##
## An empty roster contributes nothing to the world's fingerprint, so a world
## with no fighters in it fingerprints exactly as it did before this layer
## existed. That is deliberate: the fingerprint answers for what is there.
##
## ## What this file no longer holds
##
## The pairing rule, the engage radius, the one-turn-per-tick cadence and the
## ordering inside a tick used to be written here, and a second copy of all four
## had to be written by hand in any scenario built on the atomic action surface.
## They are now `ActionScene.fight_step()`'s, once, and this file *drives* that:
## it walks its combatants in real time and then calls it. Everything below is
## either the walking, or the counting, or the world-facing view of the two --
## nothing here decides when a fight begins.
class_name CombatantRoster

## What the roster is doing.
const REAL_TIME := "real-time"
const FIGHTING := "fighting"

## How many of the most recent blows the snapshot carries. More than a fight
## lands in the time any of them is worth drawing for, and small enough that a
## snapshot taken every frame stays a handful of rows.
const BLOWS_SHOWN := 8

## Where the fight is actually held, and where everyone in it stands.
##
## The roster is a scene with a real-time walk on top: combatants are its actors,
## the fight under way is its fight, and the cycle is its `fight_step()`. Sharing
## the class rather than the rules is what makes the world's fights and the
## action surface's fights the same fights -- there is no second answer to who
## engages whom, because there is no second rule.
var scene: ActionScene = ActionScene.new()

## Everyone who can fight, in the order they were added, which is id order. The
## scene's actors, under the name the world has always called them by.
var members: Array[Combatant]:
	get:
		return scene.actors

## The fight under way, or null.
var fight: Encounter:
	get:
		return scene.fight

## How many fights have begun and how many have ended. Diagnostic, and what a
## test asserts against so that "a fight happened" is a number rather than a
## reading of the transcript.
var fights_begun: int:
	get:
		return scene.fights_begun

var fights_ended: int:
	get:
		return scene.fights_ended

## How many boards have been built for a fight. A viewer watches this rather than
## the board itself, exactly as it watches the water sheet's version, so it only
## re-reads the lattice when there is a new lattice to read.
var board_version: int:
	get:
		return scene.board_version

## Everything that has been written down about the fights this roster has held,
## in order.
var lines: PackedStringArray:
	get:
		return scene.fight_lines


## Put a combatant in the world, giving it an id. A commander is made its own
## band, so "everyone in this band" is one comparison and includes the commander.
## The scene's own enrolment, because the id space is the scene's.
func add(one: Combatant) -> Combatant:
	return scene.add_actor(one)


func is_empty() -> bool:
	return members.is_empty()


func size() -> int:
	return members.size()


## What the roster is doing, in one word.
func phase() -> String:
	return FIGHTING if fight != null else REAL_TIME


## The combatant with an id, or null.
func member_of(id: int) -> Combatant:
	return scene.actor_of(id)


## Advance one tick. Returns whatever was written down this tick, so a caller
## tracing the world can interleave it with its own lines.
##
## Two statements, and the order of them is the one thing this file says about a
## fight: everybody walks, and then whichever fight is on takes its turn. That is
## the ordering `SimWorld.step` describes -- the fight is serviced after the
## world around it -- and a combatant seated on a board does not walk, because
## `Combatant.walk` returns at once for anyone who is fighting. So a fight that
## begins on one tick is noticed on the next, and a survivor of a fight that ends
## on a tick does not also walk on it.
func step(terrain: TerrainQuery) -> PackedStringArray:
	scene.terrain = terrain
	for one in members:
		one.walk(terrain)
	var turn := scene.fight_step()
	var written := PackedStringArray()
	written.append_array(turn["lines"])
	written.append_array(turn["over"])
	return written


## The board the fight is on, as anyone outside the simulation gets it: a
## detached copy, or null when no fight is on. Copied for the same reason chunk
## geometry and the water sheet are -- this engine's packed arrays share their
## storage when assigned.
func board_copy() -> CombatBoard:
	return null if fight == null else fight.board.detached_copy()


## The read-only state a viewer needs: what phase this is, and one row per
## combatant with everything needed to draw it and nothing else.
##
## Every value here is a number or a tag the simulation already holds. There is
## no model, no clip and no colour: what a `minion_frog` looks like is the render
## layer's table's business, and this layer has never heard of it.
func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	for one in members:
		rows.append({
			"id": one.id,
			"band": one.band,
			"kind": one.piece.kind_name(),
			"appearance": one.piece.appearance,
			"commander": one.is_commander(),
			"x": one.x,
			"y": one.y,
			"z": one.z,
			"heading": one.heading,
			# How fast it is actually moving and how far it just went up, both
			# read off what happened on the last tick rather than off any
			# setting -- see `Combatant.moved`. Nothing at all while it is
			# standing on a cell, because a piece on a board moves by cells and
			# not across the ground. A viewer picking an animation reads these
			# rather than working out for itself what the phase implies.
			"speed": 0.0 if one.fighting else one.moved,
			"rise": 0.0 if one.fighting else one.rose,
			"jumped": one.jumped and not one.fighting,
			"facing": (one.piece as Commander).facing if one.is_commander() else -1,
			"fighting": one.fighting,
			"health": one.piece.health,
			"max_health": one.piece.max_health(),
			"cell_x": one.piece.cell.x,
			"cell_y": one.piece.cell.y,
		})
	return {
		"phase": phase(),
		# The world's clock, so that whoever is drawing a blow can tell how long
		# ago it landed without keeping a clock of its own.
		"tick": scene.tick,
		# The same fact as the phase, as a plain flag, so that a viewer never has
		# to name one of this layer's constants to know whether a fight is on.
		"fighting": fight != null,
		"count": members.size(),
		"fights_begun": fights_begun,
		"fights_ended": fights_ended,
		"board_version": board_version,
		"round": 0 if fight == null else fight.match_state.round_number,
		"turns": 0 if fight == null else fight.turns_played,
		"anchor_x": 0.0 if fight == null else fight.anchor_x,
		"anchor_z": 0.0 if fight == null else fight.anchor_z,
		"pieces": rows,
		"ground": ground_rows(),
		"blows": blow_rows(),
	}


## The most recent blows struck in this world, oldest first: the scene's own
## record of them, carried out to whoever is drawing rather than reached for.
##
## This is the row `ActionScene.blows` holds, copied deeply because the arrays in
## it share their storage when assigned, exactly as the chunk geometry and the
## water sheet are copied. Nothing is added to it and nothing is worked out: how
## long a swing lasts, what a `blade` looks like and which way an arrow flies are
## the render layer's answers, and this layer has never heard of any of them.
##
## Only the last `BLOWS_SHOWN` are carried. A world that has been fighting for an
## hour has thousands of them and nothing drawing it has any use for the old
## ones; what is old enough to have been drawn is old enough to be left behind.
func blow_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var struck := scene.blows
	for at in range(maxi(0, struck.size() - BLOWS_SHOWN), struck.size()):
		rows.append(struck[at].duplicate(true))
	return rows


## One row per thing standing in the world that is not a character: where it is,
## what it is, and -- for an open pile -- what is lying in it.
##
## The same rule the piece rows follow. Every value is a number or a name the
## simulation already holds; there is no model, no scale and no colour, because
## what a `gear_blade` looks like is the render layer's table's business and this
## layer has never heard of one. `ItemModel` is asked which *name* an item goes
## under, which is the same sort of answer as the `appearance` on a piece row.
##
## Only a pile lists its items. A chest is a placed thing and what is inside it
## is not lying on the ground; a shut one says nothing about its contents at all,
## which is the rule `WorldObject.contents_seen` already keeps and this does not
## get a second opinion on.
func ground_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for thing in scene.objects:
		var row := {
			"id": thing.id,
			"name": thing.object_name,
			"kind": "pile" if thing.pile else "object",
			"shut": thing.shut,
			"x": thing.x,
			"y": thing.y,
			"z": thing.z,
			"items": [],
		}
		if thing.pile and thing.is_open() and thing.holds_things():
			var lying: Array[Dictionary] = []
			for entry in thing.contents.carried:
				var item := Inventory.item_of(entry)
				if item == null:
					continue
				lying.append({
					"name": item.item_name,
					"rarity": item.rarity,
					"level": item.level,
					"model": ItemModel.of(item),
				})
			row["items"] = lying
		rows.append(row)
	return rows


## One line per combatant, in id order. What a report prints and what a test
## compares.
func member_lines() -> PackedStringArray:
	var written := PackedStringArray()
	for one in members:
		written.append(one.line())
	return written


## A short, stable fingerprint of the whole roster.
##
## An empty roster fingerprints as the empty string, and `SimWorld.digest()`
## leaves it out entirely in that case, so a world with nobody in it is the world
## it was before this layer existed.
func digest() -> String:
	if members.is_empty():
		return ""
	var parts := PackedStringArray()
	parts.append("phase=%s begun=%d ended=%d board=%d" % [
		phase(), fights_begun, fights_ended, board_version,
	])
	parts.append_array(member_lines())
	if fight != null:
		parts.append("fight anchor=%d round=%d turns=%d board=%s" % [
			fight.anchor_id, fight.match_state.round_number, fight.turns_played,
			fight.board.digest(),
		])
	return "|".join(parts).sha256_text().substr(0, 16)
