extends TestSuite
## A fight that is over is over: it does not begin again three ticks later, and
## both sides of the board reason about who is a stranger in the same terms.
##
## Four defects were one defect, and this suite is the four of them written down
## as claims that cannot come back quietly.
##
##   1. **A finished fight does not restart.** Two commanders whose fight ran to
##      `Encounter.MAX_ROUNDS` come off the board standing three units apart --
##      well inside `ActionScene.ENGAGE_RADIUS` -- so the pairing rule found the
##      same two on the very next tick and the board came straight back up.
##      Measured before this suite existed: five boards in four hundred ticks,
##      each beginning one tick after the last ended, and on the play stage ten
##      boards in 795 ticks. `ActionScene.COOL_OFF` is the rule that stops it,
##      and the constant carries the reason it was chosen over the two
##      alternatives.
##   2. **And the two of them have to part before they can meet again.** Ticks
##      alone are a floor: two characters who both stand still are still standing
##      where the board left them when the ticks run out, which turned ten
##      back-to-back boards into eight boards a hundred ticks apart rather than
##      into one. Standing where you already stood is not meeting somebody, so
##      the pairing rule also wants them to have been further apart than
##      `ENGAGE_RADIUS` since -- and a pair that does walk away and come back is
##      released, which is the other half of the same claim.
##   3. **It is a rule of the world, and it holds for every mind alike.** The
##      same cool-off answers a blow somebody *chooses* to strike, in the world's
##      own sentence (`ActionEngine.fight_is_over`), whoever chose it -- so there
##      is no path round it for a person, for a scripted mind or for a model.
##   4. **A mind whose target has left the fight stops choosing attacks on it.**
##      `ActionScene.nearest_of_another_band` asked the band while the board asks
##      the side, so a mind went on naming somebody who had walked off the board:
##      eleven refusals of "<name> is not on the board" in one seeded run,
##      between t=29 and t=169, and none of them possible any more.
##   5. **A fight among three commanders reaches an end.** The other direction of
##      the same disagreement: two commanders of one band who *chose* to fight
##      each other are two sides of the board they are on (`Encounter._seat`) and
##      each is the other's enemy as far as `CombatPolicy` is concerned -- but
##      neither mind would ever name the other, so neither ever swung. Measured
##      in the same seeded fight: 41 rounds and 120 turns whose only lines were
##      `face`, no blow struck at all, `ending=limit survivors=3 fallen=0`.
class_name TestFightCooloff

## The seed every fight in this suite is played at -- the one every scenario in
## the repository is written on, so a tick here means the tick it means there.
const SEED := 1234

## Where the fights are staged, in world units. The play stage's own meadow.
const WHERE := Vector2(-480.0, 420.0)

## What everybody in this suite is worth: one level, one pair of scores, one
## weapon. Nothing here turns on any of them differing.
const LEVEL := 3
const DEXTERITY := 4
const STRENGTH := 5
const SWORD := "common sword"

## How long the restarting pair is watched for, in ticks. Long enough to hold
## several whole fights at `Encounter.MAX_ROUNDS`, which is how the restart was
## measured in the first place.
const WATCHING := 400

## How long a fight is given to reach an end, in ticks. Generous against
## `Encounter.MAX_ROUNDS`, so a run that uses it all has found something.
const PATIENCE := 900

## Which round the person in claim 3 walks out of the fight on. The second, so
## the board has been played rather than merely stood on.
const LEAVE_ON_ROUND := 2

## What the world says about somebody who is not on the board, which is the
## refusal claim 3 counts. `ActionEngine`'s own wording, read from the sentence
## it assembles rather than typed again.
const NOT_ON_THE_BOARD := "is not on the board"


func _init() -> void:
	suite_name = "fight cool-off"


func run() -> void:
	_a_finished_fight_does_not_restart_on_the_following_ticks()
	_a_pair_that_walks_away_and_comes_back_may_meet_again()
	_the_cool_off_answers_a_chosen_blow_in_the_world_s_own_words()
	_the_cool_off_is_between_everybody_who_was_in_the_fight()
	_a_mind_stops_choosing_attacks_on_somebody_who_left()
	_a_fight_among_three_commanders_reaches_an_end()
	_leaving_is_written_down_by_the_world_and_carried_out()


# --- 1. The cool-off ------------------------------------------------------


## Two commanders who never swing, so their fight runs to the round limit and
## ends with both of them standing where the board put them. Nobody walked away
## and nobody was hurt, which is exactly the case the restart was measured in.
func _a_finished_fight_does_not_restart_on_the_following_ticks() -> void:
	var scene := _stage([
		{"name": "Ash", "at": Vector2(0.0, 0.0), "side": "watch", "mind": _never_swings()},
		{"name": "Corvid", "at": Vector2(4.0, 2.0), "side": "stranger", "mind": _never_swings()},
	])
	var began := PackedInt32Array()
	var ended := PackedInt32Array()
	for t in WATCHING:
		scene.tick = t
		var step := scene.fight_step()
		if step["began"] != null:
			began.append(t)
		if step["ended"]:
			ended.append(t)
	check(ended.size() == 1, "the fight ended %d times in %d ticks" % [ended.size(), WATCHING])
	equal(began.size(), 1,
		"the same two were put on %d boards in %d ticks: begun on %s, ended on %s"
		% [began.size(), WATCHING, str(began), str(ended)])
	# And the two of them are still standing where they were: the rule cooled the
	# meeting off, it did not move anybody.
	check(scene.actors[0].distance_to(scene.actors[1]) <= ActionScene.ENGAGE_RADIUS,
		"the cool-off moved the two apart instead of leaving them where they stood")
	check(scene.cooling.has(Vector2i(scene.actors[0].id, scene.actors[1].id)),
		"the world has forgotten the fight while the two are still standing in it")


## The other half: a pair that waits out the ticks *and* walks away is released,
## and coming back together is a meeting the world says so about.
##
## Without this the first claim would be satisfied by never letting two
## characters fight twice, which is not a cool-off but an ending.
func _a_pair_that_walks_away_and_comes_back_may_meet_again() -> void:
	var scene := _stage([
		{"name": "Ash", "at": Vector2(0.0, 0.0), "side": "watch", "mind": _never_swings()},
		{"name": "Corvid", "at": Vector2(4.0, 2.0), "side": "stranger", "mind": _never_swings()},
	])
	var one := scene.actors[0]
	var other := scene.actors[1]
	var ended_at := -1
	for t in WATCHING:
		scene.tick = t
		if scene.fight_step()["ended"]:
			ended_at = t
			break
	check(ended_at >= 0, "no fight ended in %d ticks" % WATCHING)
	if ended_at < 0:
		return

	# Away, further than the engagement radius, and long enough for the ticks to
	# have run out as well. Moved here rather than walked because what is being
	# checked is the rule, not anybody's walk.
	other.x = one.x + ActionScene.ENGAGE_RADIUS * 3.0
	other.settle(scene.terrain)
	for t in range(ended_at + 1, ended_at + ActionScene.COOL_OFF + 2):
		scene.tick = t
		scene.fight_step()
	check(not scene.cooling.has(Vector2i(one.id, other.id)),
		"the two walked away and waited out the cool-off and the world still holds their fight")
	check(scene.fight == null, "a board went up while the two were far apart")

	# And back. This is a meeting, so the world starts a fight.
	other.x = one.x + 3.0
	other.settle(scene.terrain)
	scene.tick += 1
	var step := scene.fight_step()
	check(step["began"] != null,
		"the two came back together and the world did not call it a meeting")


## The same rule, asked the other way in: somebody chooses to strike somebody
## they have just finished a fight with, and the world refuses in its own words.
##
## This is the whole of "it holds for every mind alike". The refusal comes out of
## `ActionEngine`, which is the one path every choice takes -- a person's key, a
## scripted rule's `Action` and a model's, indistinguishably.
func _the_cool_off_answers_a_chosen_blow_in_the_world_s_own_words() -> void:
	var scene := _stage([
		{"name": "Ash", "at": Vector2(0.0, 0.0), "side": "watch", "mind": _never_swings()},
		{"name": "Corvid", "at": Vector2(4.0, 2.0), "side": "stranger", "mind": _never_swings()},
	])
	var one := scene.actors[0]
	var other := scene.actors[1]
	var ended_at := -1
	for t in WATCHING:
		scene.tick = t
		if scene.fight_step()["ended"]:
			ended_at = t
			break
	check(ended_at >= 0, "no fight ended in %d ticks" % WATCHING)
	if ended_at < 0:
		return
	check(scene.cooling_between(one.id, other.id),
		"the two who just finished a fight are not cooling off")
	equal(scene.cool_off_between(one.id, other.id), ActionScene.COOL_OFF,
		"the cool-off did not start with its whole length on it")

	# Chosen, by each of them in turn, and refused in the world's own sentence.
	for pair in [[one, other], [other, one]]:
		var striker: Combatant = pair[0]
		var mark: Combatant = pair[1]
		var out := ActionEngine.resolve(scene, striker, Action.attack(mark.id, SWORD))
		check(not out.ok, "%s was allowed to start the fight again at once"
			% ActionScene.name_of(striker))
		equal(out.reason, ActionEngine.fight_is_over(mark),
			"the refusal was not the world's own sentence for a fight that is over")
	check(scene.fight == null, "a refused blow started a fight anyway")

	# And it runs out, rather than standing for ever: a pair that is still
	# together when the cool-off is up has genuinely stayed.
	scene.tick = ended_at + ActionScene.COOL_OFF
	check(not scene.cooling_between(one.id, other.id),
		"the cool-off had not run out %d ticks after the fight ended"
		% ActionScene.COOL_OFF)
	equal(scene.cool_off_between(one.id, other.id), 0,
		"a cool-off that has run out still has ticks left on it")
	var again := ActionEngine.resolve(scene, one, Action.attack(other.id, SWORD))
	check(again.ok, "a fight could not be chosen once the cool-off had run out: %s"
		% again.reason)


## A fight is over between everybody who was in it, not only between the two it
## was nominally between: a bystander the join radius reached was in that fight
## too, and standing where the board put them is not meeting anybody either.
func _the_cool_off_is_between_everybody_who_was_in_the_fight() -> void:
	var scene := _stage([
		{"name": "Ash", "at": Vector2(0.0, 0.0), "side": "watch", "mind": _never_swings()},
		{"name": "Fen", "at": Vector2(-3.0, 2.0), "side": "watch", "mind": _never_swings()},
		{"name": "Corvid", "at": Vector2(4.0, 2.0), "side": "stranger", "mind": _never_swings()},
	])
	var seated := 0
	for t in WATCHING:
		scene.tick = t
		var step := scene.fight_step()
		if step["began"] != null:
			seated = scene.fight.members.size()
		if step["ended"]:
			break
	equal(seated, 3, "the bystander did not join the board")
	for i in scene.actors.size():
		for j in range(i + 1, scene.actors.size()):
			check(scene.cooling.has(ActionScene._pair(
					scene.actors[i].id, scene.actors[j].id)),
				"%s and %s were in one fight and are not cooling off together" % [
					ActionScene.name_of(scene.actors[i]),
					ActionScene.name_of(scene.actors[j]),
				])


# --- 3. A mind whose target left ------------------------------------------


## One seeded run: a person on a board of three walks out of the fight on their
## second round, and the fight carries on without them. Every attack the enemy's
## mind chooses is counted, and none of them may be at the person who left.
func _a_mind_stops_choosing_attacks_on_somebody_who_left() -> void:
	var scene := _stage([
		{"name": "Fen", "at": Vector2(0.0, 0.0), "side": "meadow", "mind": Callable()},
		{"name": "Hob", "at": Vector2(-2.0, 2.0), "side": "meadow",
			"mind": WorldCast.wandering(8)},
		{"name": "Rill", "at": Vector2(4.0, 1.0), "side": "wild",
			"mind": EnemyMind.hunting(WorldCast.wandering(9))},
	])
	var loop := ControlLoop.on(scene, 99)
	var fen := scene.actors[0]
	scene.take_by_hand(fen.id)

	var left_at := -1
	for _tick in PATIENCE:
		loop.step()
		scene.fight_step()
		if left_at >= 0 or scene.fight == null:
			continue
		var turn := BoardTurn.of(scene, fen.id)
		if turn == null:
			continue
		if turn.round_number() < LEAVE_ON_ROUND:
			turn.finish()
			continue
		if bool(turn.leave()["ok"]):
			left_at = scene.tick
	check(left_at >= 0, "the person never got a turn to leave the fight on")
	if left_at < 0:
		return
	check(not fen.fighting, "the person is still on the board after leaving it")

	var after := PackedStringArray()
	for line in loop.journal:
		if line.contains(NOT_ON_THE_BOARD):
			after.append(line)
	equal(after.size(), 0,
		"a mind went on striking at somebody who is not on the board: %s"
		% "; ".join(after))
	# And the reading that makes it so, asked directly: on a board, the nearest
	# stranger is somebody the board says is a stranger.
	for one in scene.actors:
		if not one.fighting:
			continue
		var mark := scene.nearest_of_another_band(one)
		check(mark == null or mark.fighting,
			"%s's nearest stranger is somebody who is not on the board"
			% ActionScene.name_of(one))


# --- 4. Three commanders --------------------------------------------------


## Three commanders of one band, and one of them chooses to fight another.
##
## Nothing starts by drifting, because the engagement rule pits commanders of
## *different* bands -- so the only fight here is the one somebody chose, which
## is the shape `sim/scripted_territory.gd` stages on purpose. The two who chose
## are two sides of the board; the third shares a band with both and is its own
## side. All three therefore oppose each other on the board, and the claim is
## that the minds agree with the board about that.
func _a_fight_among_three_commanders_reaches_an_end() -> void:
	var scene := _stage([
		{"name": "Wren", "at": Vector2(0.0, 0.0), "side": "one",
			"mind": WorldCast.wandering(7)},
		{"name": "Rook", "at": Vector2(3.0, 1.0), "side": "one",
			"mind": WorldCast.wandering(8)},
		{"name": "Corvid", "at": Vector2(-3.0, 2.0), "side": "one",
			"mind": WorldCast.wandering(9)},
	])
	var loop := ControlLoop.on(scene, 99)
	var opened := ActionEngine.resolve(
		scene, scene.actors[0], Action.attack(scene.actors[1].id, SWORD))
	check(opened.ok, "the chosen blow did not start a fight: %s" % opened.reason)
	if scene.fight == null:
		return
	equal(scene.fight.members.size(), 3, "the third commander did not join the board")

	var ended_at := -1
	for _tick in PATIENCE:
		loop.step()
		if scene.fight_step()["ended"]:
			ended_at = scene.tick
			break
	check(ended_at >= 0, "the three-commander fight did not end in %d ticks" % PATIENCE)

	# Ended, and ended by being fought: a board where nobody ever swings runs out
	# of rounds instead, which is what this used to do.
	var over := ""
	var blows := 0
	for line in scene.fight_lines:
		if line.begins_with("over ") and line.contains("ending="):
			over = line
		if line.strip_edges().begins_with("hit "):
			blows += 1
	check(over.contains("ending=decided"),
		"the fight did not reach a decision -- it ended '%s'" % over)
	check(blows > 0, "not one blow was struck in the whole fight")


# --- Leaving, as the world writes it down ---------------------------------


## Walking out of a fight is something the world says happened, in its own words,
## and carries out to whoever is drawing -- and it stops saying it once the
## character has done something else, because leaving is the last thing that
## happened to you only until it is not.
func _leaving_is_written_down_by_the_world_and_carried_out() -> void:
	var sim := Simulation.new(SEED)
	if not sim.begin_scenario(Simulation.SCENARIO_PLAY):
		check(false, "the play stage could not be stood up")
		return
	if not sim.hand_over_followed():
		check(false, "the play stage handed nobody to drive")
		return
	var scene: ActionScene = sim.world.combat.scene
	var me := scene.actor_of(sim.driven_id)
	check(me != null, "the play stage handed nobody to drive")
	if me == null:
		return
	# A fight of this person's own choosing, so the claim does not wait on two
	# characters drifting together.
	var mark := scene.nearest_of_another_band(me)
	check(mark != null, "there is nobody on the play stage of another band")
	if mark == null:
		return
	while me.distance_to(mark) > Encounter.JOIN_RADIUS * 0.5:
		me.x = mark.x + (me.x - mark.x) * 0.5
		me.z = mark.z + (me.z - mark.z) * 0.5
		me.settle(scene.terrain)
	var opened := ActionEngine.resolve(scene, me, Action.attack(mark.id, SWORD))
	check(opened.ok, "the chosen blow did not start a fight: %s" % opened.reason)
	if scene.fight == null:
		return

	var left := false
	for _tick in PATIENCE:
		var turn := BoardTurn.of(scene, me.id)
		if turn != null and bool(turn.leave()["ok"]):
			left = true
			break
		sim.step()
	check(left, "the person never got a turn to leave the fight on")
	if not left:
		return

	equal(scene.departure_of(me.id), ActionEngine.left_the_fight(me),
		"the world does not say the person left the fight")
	check(scene.cooling_between(me.id, mark.id),
		"leaving a fight did not start the cool-off between the two who were in it")
	equal(FightSource.departure_in(sim.world.combat.snapshot(), me.id),
		ActionEngine.left_the_fight(me),
		"the sentence did not reach the snapshot whoever is drawing reads")
	check(not FightSource.on_the_board_in(sim.world.combat.snapshot(), me.id),
		"the snapshot still says the person is on a board")

	# And it stops being the last thing that happened once they do something.
	ActionEngine.resolve(scene, me, Action.wait(1))
	equal(scene.departure_of(me.id), "",
		"the world went on saying the person had left after they chose something else")


# --- The stage ------------------------------------------------------------


## Stand a cast out on the meadow: a name, which side it is on, where it stands
## relative to `WHERE`, and the rule that drives it.
##
## Everyone on one side is one band, exactly as `sim/scripted_skirmish.gd` does
## it -- `ActionScene.add_actor` makes each commander its own band and a side is
## what a stage has to say on top of that.
func _stage(rows: Array) -> ActionScene:
	var scene := ActionScene.on(TerrainQuery.for_seed(SEED))
	var bands := {}
	for row in rows:
		var at: Vector2 = row["at"]
		var one := scene.add_actor(Combatant.commander_at(
			WHERE.x + at.x, WHERE.y + at.y, 0.0, 0.0, LEVEL, AssetTags.KNIGHT))
		if bands.has(row["side"]):
			one.band = int(bands[row["side"]])
		else:
			bands[row["side"]] = one.id
		var sheet := Character.make(String(row["name"]), LEVEL)
		sheet.record_scores({Ability.DEX: DEXTERITY, Ability.STR: STRENGTH})
		var mind: Callable = row["mind"]
		if mind.is_valid():
			sheet.decide = mind
		var chief := one.piece as Commander
		chief.adopt(sheet)
		one.piece.equip(Armour.boots())
		# Forged at the character's own level rather than taken bare off the
		# catalogue, which is the discipline every other stage in the project
		# keeps: a bare shape reads damage no power budget paid for.
		chief.wield(Weapon.held(Weapon.sword(), LEVEL))
	return scene


# A mind that never swings and never walks. Its fight therefore runs to
# `Encounter.MAX_ROUNDS` and ends with both of them standing exactly where the
# board put them, which is the case the restart was measured in -- and it is also
# what a person pressing nothing does.
func _never_swings() -> Callable:
	return DecisionSource.scripted(
		func(_scene: ActionScene, _actor: Combatant) -> Action:
			return Action.wait(4))
