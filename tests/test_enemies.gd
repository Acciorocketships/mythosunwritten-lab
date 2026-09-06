extends TestSuite
## Enemies in the running game: where they are, who decides for them, and how a
## fight begins.
##
## Seven claims, and every one of them is read off an ordinary `SimWorld` -- the
## world the render shell and the headless runner both step -- rather than off a
## scenario. That is the point of the work: before it, an enemy existed only
## where a runner mustered one.
##
##   1. where an enemy is is a function of the cell and the seed, and of nothing
##      else -- two fields agree, one field asked twice agrees with itself, and a
##      different seed disagrees;
##   2. an enemy's level is the section 5 gradient's answer for where it stands,
##      so it rises with distance from spawn;
##   3. walking away and coming back finds the same enemy, because there was no
##      roll to repeat;
##   4. how many stand near one person at once is bounded, and the bound holds
##      over a long walk;
##   5. an enemy decides through the same seam as everybody else, and a driver
##      cannot tell it apart from the rest of the cast;
##   6. a fight starts because a character acted: the blow is in the trace with
##      the tick, who struck whom, and what the engine answered;
##   7. its turns in that fight are played by the battle AI, in the world's own
##      step, with no runner anywhere.
##
## Plus one boundary: a scenario's stage gets nobody, because a stage is
## something somebody set out.
class_name TestEnemies

## The seed the headless run reports, so that anything measured here is measured
## on the shipped world.
const SEED := 1234

## A second seed, for "a different seed is a different world".
const OTHER_SEED := 4321

## How far out the level table is walked, in rings of the gradient.
const RINGS := 8

## Long enough for an ordinary world to fall into a fight and for that fight to
## be decided: a turn waits for the attack that spends it, which is six ticks, so
## a round of two commanders is about a dozen ticks and a fight is a few hundred.
const FIGHT_TICKS := 250

## Long enough a walk that the layer has stood several enemies up and dropped
## some of them again.
const WALK := 150


func _init() -> void:
	suite_name = "enemies"


func run() -> void:
	_where_an_enemy_is_is_a_function_of_the_place()
	_level_rises_with_distance_from_spawn()
	_walking_away_and_back_finds_the_same_enemy()
	_how_many_stand_at_once_is_bounded()
	_an_enemy_decides_through_the_same_seam()
	_a_blow_begins_a_fight()
	_a_blow_out_of_reach_is_refused()
	_the_battle_ai_plays_its_turns()
	_a_scenario_stage_gets_nobody()


# --- 1. A function of the place -------------------------------------------


func _where_an_enemy_is_is_a_function_of_the_place() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var here := EnemyField.new(terrain)
	var again := EnemyField.new(TerrainQuery.for_seed(SEED))
	var elsewhere := EnemyField.new(TerrainQuery.for_seed(OTHER_SEED))

	var placed := 0
	var differed := 0
	for cell_x in range(-4, 5):
		for cell_z in range(-4, 5):
			var cell := Vector2i(cell_x, cell_z)
			var row := here.enemy_in_cell(cell)
			# Asked twice of one field, and once of a second field on the same
			# seed: three readings, one answer. Compared field by field, because
			# what has to agree is what the row says and not which object it is.
			check(_same_row(here.enemy_in_cell(cell), row),
				"the same field gave two answers for cell %s" % cell)
			check(_same_row(again.enemy_in_cell(cell), row),
				"two fields of one seed disagreed about cell %s" % cell)
			if not row.is_empty():
				placed += 1
				# And the placement is inside the cell that owns it, which is
				# what makes the streamer's bound a bound.
				var owner := EnemyField.cell_at(float(row["x"]), float(row["z"]))
				equal(owner, cell,
					"cell %s placed its enemy in cell %s" % [cell, owner])
			if not _same_row(elsewhere.enemy_in_cell(cell), row):
				differed += 1
	check(placed > 0, "the field placed no enemy at all in 81 cells")
	check(differed > 0, "a different seed placed exactly the same enemies")


## Whether two placements say the same thing. Field by field, in a fixed order,
## so a row gaining a field cannot make this quietly stop comparing.
func _same_row(left: Dictionary, right: Dictionary) -> bool:
	if left.is_empty() or right.is_empty():
		return left.is_empty() and right.is_empty()
	for key in ["cell", "x", "z", "role", "level", "ring", "key", "name"]:
		if left.get(key, null) != right.get(key, null):
			return false
	return true


# --- 2. The gradient ------------------------------------------------------


## The level an enemy is stood up at is `ItemFrontier`'s answer for the distance
## it stands at, which is section 5's gradient and nothing this layer invented.
##
## Checked on what is actually built -- the character sheet of a stood-up enemy
## -- rather than on the field's own row, so the claim is about the enemy in the
## world and not about a number in a dictionary.
func _level_rises_with_distance_from_spawn() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var field := EnemyField.new(terrain)
	var streamer := EnemyStreamer.new(field)
	var scene := ActionScene.on(terrain)

	var seen := 0
	var highest_ring := -1
	var highest_level := 0
	for row in field.enemies_in_square(EnemyField.CELL * float(RINGS)):
		var one := streamer.stand_up(scene, row)
		if one == null:
			continue
		var sheet: Character = (one.piece as Commander).sheet
		var distance := Vector2(float(row["x"]), float(row["z"])).length()
		equal(sheet.level, ItemFrontier.level_at(distance),
			"an enemy %.1f from spawn was stood up at level %d"
			% [distance, sheet.level])
		var ring := ItemFrontier.ring_at(distance)
		if ring > highest_ring:
			highest_ring = ring
			highest_level = sheet.level
		elif ring == highest_ring:
			equal(sheet.level, highest_level,
				"two enemies in ring %d were different levels" % ring)
		seen += 1
	check(seen > 0, "no enemy was stood up anywhere in %d rings" % RINGS)
	check(highest_ring > 0 and highest_level > ItemFrontier.SPAWN_LEVEL,
		"nothing further out was worth more than something at spawn")


# --- 3. Away and back -----------------------------------------------------


## An enemy dropped and met again is the enemy the seed says, not a fresh roll.
##
## The world is walked away from -- far enough that the layer lets go of the cell
## -- and walked back to, and what comes back is compared on everything that is a
## fact about the place: the cell, the role, the level, the spot and the whole
## rolled inventory.
func _walking_away_and_back_finds_the_same_enemy() -> void:
	var world := SimWorld.new(SEED)
	var cells := world.enemy_streamer.standing_cells()
	check(not cells.is_empty(), "an ordinary world stood no enemy up at all")
	if cells.is_empty():
		return
	var cell := cells[0]
	var before := _row_of(world, cell)
	check(not before.is_empty(), "the standing enemy had no readable state")

	# Away: far enough that neither the enemy nor its cell is anywhere near.
	world.place_observer(4000.0, 4000.0)
	equal(world.enemy_streamer.standing_id(cell), 0,
		"walking away left the enemy standing")
	check(world.combat.scene.actor_of(int(before["id"])) == null,
		"walking away left the enemy in the scene")

	# And back.
	world.place_observer(0.0, 0.0)
	var after := _row_of(world, cell)
	check(not after.is_empty(), "coming back found nobody in cell %s" % cell)
	if after.is_empty():
		return
	for key in ["name", "role", "level", "x", "z", "gear"]:
		equal(after[key], before[key],
			"coming back found a different %s in cell %s" % [key, cell])


# What is standing for a cell, as the facts about it that the seed decides.
func _row_of(world: SimWorld, cell: Vector2i) -> Dictionary:
	var id := world.enemy_streamer.standing_id(cell)
	if id == 0:
		return {}
	var one := world.combat.scene.actor_of(id)
	if one == null:
		return {}
	var sheet: Character = (one.piece as Commander).sheet
	return {
		"id": id,
		"name": sheet.character_name,
		"role": world.enemy_field.enemy_in_cell(cell).get("role", ""),
		"level": sheet.level,
		"x": snappedf(one.x, 0.0001),
		"z": snappedf(one.z, 0.0001),
		"gear": sheet.inventory.fingerprint(),
	}


# --- 4. The bound ---------------------------------------------------------


func _how_many_stand_at_once_is_bounded() -> void:
	var world := SimWorld.new(SEED)
	var most := world.enemy_streamer.standing_count()
	for _tick in WALK:
		world.step()
		most = maxi(most, world.enemy_streamer.standing_count())
		check(world.enemy_streamer.standing_count() <= EnemyStreamer.AT_MOST,
			"%d enemies stood at once, over the bound of %d"
			% [world.enemy_streamer.standing_count(), EnemyStreamer.AT_MOST])
	check(most > 0, "no enemy ever stood up in %d ticks of walking" % WALK)
	check(world.enemy_streamer.spawns > 1,
		"the walk met only %d enemy in %d ticks, so the bound was never under"
		% [world.enemy_streamer.spawns, WALK] + " any pressure")


# --- 5. The same seam -----------------------------------------------------


## An enemy is a character with a `Callable` on its sheet, in the world's own
## roster, serviced by the world's own loop. Nothing about it is a special case,
## and this is the check that says so in the terms the rest of the cast is
## checked in.
func _an_enemy_decides_through_the_same_seam() -> void:
	var world := SimWorld.new(SEED)
	var enemy := _first_enemy(world)
	check(enemy != null, "an ordinary world stood no enemy up")
	if enemy == null:
		return

	# It is in the same roster and the same scene as everybody else...
	check(world.combat.member_of(enemy.id) == enemy,
		"the enemy is not in the world's own roster")
	check(world.combat.scene.actor_of(enemy.id) == enemy,
		"the enemy is not in the world's own scene")
	var sheet: Character = (enemy.piece as Commander).sheet
	check(sheet != null and sheet.decide.is_valid(),
		"the enemy has no decision function on its sheet")

	# ...and its decision function has the shape every decision function has:
	# two arguments, one action or nothing at all.
	var chosen: Variant = sheet.decide.call(world.combat.scene, enemy)
	check(chosen == null or chosen is Action,
		"an enemy's decision function answered something that is not an action")

	# The driver cannot tell it apart: the same call that drives a member of the
	# ordinary cast drives it, and comes back with the same two fields.
	var taken := DecisionSource.drive(world.combat.scene, enemy, 1)
	equal(taken.size(), 1, "driving an enemy took no action")
	if taken.size() == 1:
		check(taken[0]["chose"] is Action, "an enemy chose something that is not an action")
		check(taken[0]["got"] is ActionOutcome, "the engine answered an enemy with something else")

	# And the world's own loop services it, by name, on a stated tick.
	var named := false
	for _tick in 30:
		world.step()
	for line in world.loop.journal:
		if line.contains(sheet.character_name):
			named = true
			break
	check(named, "the world's control loop never serviced %s" % sheet.character_name)


# --- 6. A fight starts because somebody acted -----------------------------


## The blow that starts a fight, on the world's own action surface.
##
## Nothing here declares a fight. An enemy is stood beside a member of the cast,
## its own rule is asked, and what it chooses is handed to `ActionEngine` -- the
## same call every action in the project goes through. The check is on the
## engine's answer and on the world afterwards.
func _a_blow_begins_a_fight() -> void:
	var world := SimWorld.new(SEED)
	var scene := world.combat.scene
	var followed := world.followed()
	check(followed != null, "the world is looking through nobody")
	if followed == null:
		return
	var enemy := _stand_an_enemy_beside(world, followed, EnemyMind.STRIKE - 2.0)
	check(enemy != null, "no enemy could be stood beside the cast")
	if enemy == null:
		return
	# Who it swings at is its own rule's answer, not the test's: the world has
	# more than one person in it and the nearest of another band may not be the
	# one the camera is on.
	var mark := scene.nearest_of_another_band(enemy)
	check(mark != null, "the enemy found nobody of another band to swing at")
	if mark == null:
		return

	check(scene.fight == null, "a fight was already on before anybody acted")
	var sheet: Character = (enemy.piece as Commander).sheet
	var chosen: Variant = sheet.decide.call(scene, enemy)
	check(chosen is Action and chosen.kind == ActionCatalog.ATTACK,
		"an enemy at %.1f units chose %s rather than to attack"
		% [enemy.distance_to(mark), "nothing" if chosen == null else chosen.line()])
	if not (chosen is Action):
		return
	equal(chosen.target_id(), mark.id, "the enemy swung at somebody else")

	var answered := ActionEngine.resolve(scene, enemy, chosen)
	check(answered.ok, "the engine refused the blow: %s" % answered.reason)
	equal(String(answered.got("fight", "")), "begins",
		"the engine's answer did not say a fight began: %s" % answered.line())
	check(scene.fight != null, "no fight is on after a blow that began one")
	check(enemy.fighting and mark.fighting,
		"the two of them are not on the board the blow called up")
	equal(scene.fights_begun, 1, "the fight was counted more than once")

	# The two things the trace has to carry: who struck whom, and what came back.
	check(chosen.line().contains("target=%d" % mark.id),
		"the choice does not name who was struck: %s" % chosen.line())
	check(answered.line().contains("anchor=%d" % enemy.id),
		"the answer does not name who struck: %s" % answered.line())


## The enemy's turns in a fight are played by the battle AI, in the running game.
##
## Read off an ordinary world stepped by `SimWorld.step` and nothing else. There
## is no runner here and no scenario: a world of the shipped seed is built, it is
## stepped, and what is asserted is what the world wrote down about the fight it
## fell into -- pieces moved by `CombatPolicy`, and a blow that landed through
## the one damage seam.
func _the_battle_ai_plays_its_turns() -> void:
	var world := SimWorld.new(SEED)
	for _tick in FIGHT_TICKS:
		world.step()
		if world.combat.fights_ended > 0:
			break
	check(world.combat.fights_begun > 0,
		"no fight began anywhere in %d ticks of an ordinary world" % FIGHT_TICKS)

	var moved := 0
	var struck := 0
	var dealt := 0
	for line in world.combat_lines:
		if line.contains("move #"):
			moved += 1
		if line.contains("hit #"):
			struck += 1
			# `hit #a->#b power=P x100 swing=S ... dealt=D hp=h/H`
			for word in line.split(" ", false):
				if word.begins_with("dealt="):
					dealt += word.substr("dealt=".length()).to_int()
	check(moved > 0,
		"nothing ever moved a piece: the battle AI played no turn in the world")
	check(struck > 0,
		"no blow landed in the world's own fight in %d ticks" % FIGHT_TICKS)
	check(dealt > 0, "%d blows landed and took nothing off" % struck)


## A blow at somebody too far away to be on one board is refused, and says so
## rather than beginning a fight the target is not in.
func _a_blow_out_of_reach_is_refused() -> void:
	var world := SimWorld.new(SEED)
	var mark := world.followed()
	if mark == null:
		return
	var far := _stand_an_enemy_beside(world, mark, Encounter.JOIN_RADIUS + 20.0)
	check(far != null, "no enemy could be stood out of reach of the cast")
	if far == null:
		return
	var refused := ActionEngine.resolve(
		world.combat.scene, far,
		Action.attack(mark.id, EnemyMind.strikes_with(far)))
	check(not refused.ok, "a blow from beyond the join radius began a fight")
	check(refused.reason.contains("too far away"),
		"the refusal did not say why: %s" % refused.line())
	check(world.combat.scene.fight == null,
		"a fight is on after a blow that was refused")


# --- The boundary ---------------------------------------------------------


## A scenario's stage gets nobody. The world hands the cast over to whoever set
## the stage out, and the enemy layer stops.
func _a_scenario_stage_gets_nobody() -> void:
	var world := SimWorld.new(SEED)
	check(world.enemy_streamer.standing_count() > 0,
		"an ordinary world stood no enemy up")
	world.clear_cast()
	equal(world.enemy_streamer.standing_count(), 0,
		"clearing the cast left the enemy layer holding somebody")
	check(not world.enemy_streamer.spawning,
		"the enemy layer is still spawning onto a stage somebody set out")
	for _tick in 40:
		world.step()
	equal(world.combat.size(), 0, "an emptied world filled itself back up")


# --- Standing one up beside somebody --------------------------------------


## Put one of the field's own enemies down at a stated distance from somebody,
## and hand it back.
##
## It is the field's enemy, stood up by the streamer's own call, so what is being
## driven below is exactly what an ordinary world would have stood up -- only its
## position is the test's, because a test that waited for the walk to bring one
## into range would be a test of the walk.
func _stand_an_enemy_beside(
	world: SimWorld, mark: Combatant, gap: float
) -> Combatant:
	var row := {}
	for cell in world.enemy_field.enemies_in_square(EnemyField.CELL * 3.0):
		row = cell
		break
	if row.is_empty():
		return null
	var one := world.enemy_streamer.stand_up(world.combat.scene, row)
	if one == null:
		return null
	one.x = mark.x + gap
	one.z = mark.z
	one.settle(world.terrain)
	return one


# The first enemy standing in a world, or null.
func _first_enemy(world: SimWorld) -> Combatant:
	for cell in world.enemy_streamer.standing_cells():
		var one := world.combat.scene.actor_of(world.enemy_streamer.standing_id(cell))
		if one != null:
			return one
	return null
