extends RefCounted
## Keeps the enemies near the people in the world standing in it, and forgets the
## rest.
##
## The same rule the ground, the islands, the villages and the dressing are
## streamed by: what is near somebody exists, what is far from everybody does
## not, and the two radii differ so walking back and forth across the boundary
## does not churn. What is different about this streamer is only what it builds
## -- not a mesh or a list of props but a `Combatant` with a character sheet and
## a decision function, added to the world's own scene and serviced by the world's
## own control loop from the tick it arrives.
##
## ## Walking away and coming back
##
## An enemy that is dropped is *forgotten*, not stored. Coming back re-derives it
## from `EnemyField`, which is a pure function of the cell and the seed, so the
## enemy you find is the enemy the seed always said was there -- same role, same
## level, same rolled scores, same gear, standing at the same spot. There is no
## saved state to lose and no fresh roll to differ.
##
## Two things about a cell are remembered, and both are things that happened in
## the world rather than rolls:
##
##   * **a cell is not spawned twice while you are standing next to it.** Once an
##     enemy has been stood up, its cell is held until the *site* is out of
##     `KEEP_RADIUS` of everybody. Without that, an enemy that wandered off and
##     was dropped would be stood up again at its site on the next tick, which is
##     a teleport rather than a world.
##   * **the dead stay dead.** A cell whose enemy fell is never spawned again.
##     A defeated enemy is something that happened, not a roll to repeat.
##
## ## How many can exist at once
##
## At most `AT_MOST`, and the number is enforced rather than hoped for.
##
## The natural bound is nine. A site always lies inside its own cell (see
## `EnemyField.JITTER_LOW`), so any site within `SPAWN_RADIUS` of somebody
## belongs to a cell whose nearest point is within `SPAWN_RADIUS`; with a radius
## smaller than one cell that is the observer's own cell and its eight
## neighbours, and each cell holds at most one enemy. That bounds what can be
## *spawned* around one observer. It does not by itself bound what can be
## *standing*, because an enemy that follows you stays inside `KEEP_RADIUS` while
## new cells come into range ahead of you -- so the count is also capped
## outright: at the cap, no further cell is stood up until somebody leaves.
## `AT_MOST` is therefore a real ceiling on how many enemies the world steps
## around one person, and `tools/measure_enemies.sh` measures what stepping them
## costs.
class_name EnemyStreamer

## The band every enemy the field stands up belongs to.
##
## One band for all of them, for the reason `WorldCast` gives for the meadow folk
## sharing one: the engagement rule pits commanders of *different* bands against
## each other, so a world where each enemy were its own band would be a world of
## enemies brawling with each other in the middle distance. Negative, so it can
## never collide with a combatant id -- ids are handed out from one upwards.
##
## A band is not a side of a board. Who an enemy strikes on the board is its
## mind's business (`EnemyMind`), and this only keeps them from starting fights
## with one another.
const WILD_BAND := -1

## How near somebody an enemy's site has to be for it to be stood up, in world
## units. Smaller than one cell of the field, which is what makes the spawn bound
## the observer's own cell and its eight neighbours.
const SPAWN_RADIUS := 48.0

## How far from everybody an enemy has to get before it is dropped. Wider than
## the spawn radius, so a walker on the boundary does not churn.
const KEEP_RADIUS := 60.0

## The most enemies that may stand in the world at once. See the note above.
const AT_MOST := 9

## Where the enemies are.
var field: EnemyField = null

## What the world seed is, for the wander rule a hunting enemy falls back on.
var world_seed: int = 0

## Whether this stands anybody up at all.
##
## True in an ordinary world. `SimWorld.clear_cast()` turns it off, because a
## scenario is a stage somebody set out and nothing spawns onto a stage; the
## measurement runner turns it off to weigh a world without the layer against the
## same world with it.
var spawning: bool = true

## How many have ever been stood up and how many dropped. Diagnostic only.
var spawns: int = 0
var despawns: int = 0

# Vector2i cell -> the combatant id standing for it.
var _standing := {}

# Vector2i cell -> true while its site is near enough that it must not be stood
# up again.
var _held := {}

# Vector2i cell -> true once its enemy has fallen. Never cleared.
var _felled := {}


func _init(enemy_field: EnemyField = null) -> void:
	field = enemy_field
	world_seed = 0 if enemy_field == null else enemy_field.world_seed


## Bring the standing set in line with where the people are now, and hand back
## the ids of whoever was dropped so that the caller can let go of them too.
##
## Dropping first is deliberate: it is what makes the cap a statement about the
## world after the call rather than before it.
func update(scene: ActionScene, observers: Array[Vector2]) -> PackedInt32Array:
	if field == null or scene == null:
		return PackedInt32Array()
	var gone := _drop_far_from(scene, observers)
	_release_cells(observers)
	if spawning:
		_stand_up_around(scene, observers)
	return gone


## Stop spawning and forget every cell. What a world being handed to a scenario
## does: the people on that stage are the scenario's, and nothing joins them.
##
## Nothing is taken out of the scene here, because the scene a scenario is about
## to fill is a fresh one -- `SimWorld.clear_cast()` makes it.
func stop() -> void:
	spawning = false
	_standing.clear()
	_held.clear()
	_felled.clear()


## How many enemies of this layer are standing in the world.
func standing_count() -> int:
	return _standing.size()


## The cells that have an enemy standing for them, in a fixed order.
func standing_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _standing:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y)
	return cells


## The combatant id standing for a cell, or 0.
func standing_id(cell: Vector2i) -> int:
	return int(_standing.get(cell, 0))


## Whether a cell's enemy has been defeated.
func is_felled(cell: Vector2i) -> bool:
	return _felled.has(cell)


## Stand one placement up in a scene as a character, and hand it back.
##
## Everything an enemy is is put on here, and every one of them is something the
## rest of the cast has too: a sheet rolled by `SpawnRoll`, the gear that sheet
## was rolled with taken up, a band, and a `Callable` on `Character.decide`. The
## only line that is about it being an enemy is the band and the rule -- there is
## no enemy type, no enemy list and no branch anywhere else in the simulation
## that asks whether a character is one.
func stand_up(scene: ActionScene, row: Dictionary) -> Combatant:
	if scene == null or field == null or row.is_empty():
		return null
	var sheet := field.sheet_for(row)
	if sheet == null:
		return null
	var one := scene.add_actor(Combatant.commander_at(
		float(row["x"]), float(row["z"]), 0.0, 0.0,
		sheet.level, SpawnRoll.looks_of(String(row["role"]))))
	one.band = WILD_BAND
	var chief := one.piece as Commander
	chief.adopt(sheet)
	_take_up_what_it_carries(chief, sheet)
	sheet.decide = EnemyMind.hunting(WorldCast.wandering(world_seed))
	one.settle(scene.terrain)
	return one


# --- The two halves of the rule -------------------------------------------


# Stand up whatever cell near somebody has an enemy in it and no enemy standing
# for it yet. Cells are walked in a fixed order and observers in the order they
# were handed over, so which cell is taken when the cap is reached is decided the
# same way in every process.
func _stand_up_around(scene: ActionScene, observers: Array[Vector2]) -> void:
	var reach := int(ceil(SPAWN_RADIUS / EnemyField.CELL))
	for observer in observers:
		var here := EnemyField.cell_at(observer.x, observer.y)
		for offset_x in range(-reach, reach + 1):
			for offset_z in range(-reach, reach + 1):
				if _standing.size() >= AT_MOST:
					return
				var cell := Vector2i(here.x + offset_x, here.y + offset_z)
				if _standing.has(cell) or _held.has(cell) or _felled.has(cell):
					continue
				var row := field.enemy_in_cell(cell)
				if row.is_empty():
					continue
				if Vector2(float(row["x"]) - observer.x,
						float(row["z"]) - observer.y).length() > SPAWN_RADIUS:
					continue
				var one := stand_up(scene, row)
				if one == null:
					continue
				_standing[cell] = one.id
				_held[cell] = true
				spawns += 1


# Take out of the world every enemy that is far from everybody, and notice the
# ones that are no longer in it at all.
#
# An enemy in a fight is never dropped, however far the walk has taken the person
# watching: a board half of whose pieces vanished is not a fight.
func _drop_far_from(scene: ActionScene, observers: Array[Vector2]) -> PackedInt32Array:
	var gone := PackedInt32Array()
	for cell in standing_cells():
		var one := scene.actor_of(int(_standing[cell]))
		if one == null:
			# It is not in the scene any more, which is what being defeated
			# leaves behind: the fight dropped it. That cell is spent.
			_standing.erase(cell)
			_felled[cell] = true
			continue
		if one.fighting:
			continue
		if _nearest_of(observers, Vector2(one.x, one.z)) <= KEEP_RADIUS:
			continue
		scene.remove_actor(one)
		_standing.erase(cell)
		gone.append(one.id)
		despawns += 1
	return gone


# Let go of the cells whose site nobody is near any more, so that walking away
# and coming back stands the same enemy up again.
func _release_cells(observers: Array[Vector2]) -> void:
	var released: Array[Vector2i] = []
	for cell in _held:
		if _standing.has(cell):
			continue
		var row := field.enemy_in_cell(cell)
		if row.is_empty():
			released.append(cell)
			continue
		if _nearest_of(observers, Vector2(float(row["x"]), float(row["z"]))) > KEEP_RADIUS:
			released.append(cell)
	for cell in released:
		_held.erase(cell)


static func _nearest_of(observers: Array[Vector2], at: Vector2) -> float:
	var nearest := INF
	for observer in observers:
		nearest = minf(nearest, at.distance_to(observer))
	return nearest


# Put on what the sheet was rolled carrying: `Inventory.dress`, the one call in
# the project that dresses somebody who has been stood up out of a roll.
#
# `SpawnRoll` fills an inventory and stops there, because what a character is
# wearing is not part of rolling what it is. The ordinary cast makes the same
# call for the same reason (`WorldCast.muster`).
static func _take_up_what_it_carries(_chief: Commander, sheet: Character) -> void:
	sheet.inventory.dress()
