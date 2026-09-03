extends TestSuite
## The world is running: it holds a cast, asks it every tick, and moves because
## of what the cast chose.
##
## The claim being checked is the difference between a game and a photograph of
## one. Before this, `SimWorld.step` turned an observer's heading by a random
## amount, walked it, streamed the ground around it and handed whichever fight
## was on one turn; nothing in the world was ever asked what it wanted. Now the
## same `step()` -- the one the render shell and the headless runner both call --
## services every character in the world through one `ControlLoop`, and the
## observer is a *view* on whichever character `follow_id` names rather than a
## walker of its own.
##
## Six claims, and every one of them is read off the world rather than off a
## scenario:
##
##   1. an ordinary world has people in it, and one control loop over one scene;
##   2. a character moves because its own decision function was asked, and the
##      loop's journal names the tick, the character, the choice and the answer;
##   3. being followed is the whole of what the followed character gets;
##   4. two worlds of one seed live the same life, and two seeds do not;
##   5. a scenario set out live is set out where it starts, and the frozen frame
##      is still available by name;
##   6. an emptied world is the world it was before any of this existed;
##   7. a cast is stood on ground it can walk from, and a walk the world refuses
##      turns the walker away rather than pinning it.
class_name TestLiveWorld

## The seed every claim here is played on: the world the headless run reports.
const SEED := 1234

## How many ticks are enough for a `go_to` to be chosen, run its course and be
## resolved. One leg costs `ActionCatalog`'s 20 ticks, so two legs and a little
## over is plenty.
const TICKS := 50

## A seed whose world origin is the middle of a river. The water suite works on
## it for the same reason: it is where "the spot a character is written down at
## cannot be stood on" is a real case rather than a hypothetical one.
const RIVER_SEED := 19

## Long enough for four legs, so a walker that has to turn away from water has
## had several goes at getting clear.
const RIVER_TICKS := 90


func _init() -> void:
	suite_name = "live world"


func run() -> void:
	_an_ordinary_world_holds_a_cast()
	_a_character_moves_because_it_was_asked()
	_following_is_all_the_followed_one_gets()
	_one_seed_is_one_life()
	_a_scenario_is_lived_forward_unless_a_frame_is_asked_for()
	_an_emptied_world_is_the_world_it_was()
	_a_cast_is_stood_where_it_can_walk_from()


## An ordinary world -- nobody having asked for a scenario -- has characters in
## it, one loop over the roster's own scene, and a view on one of them.
func _an_ordinary_world_holds_a_cast() -> void:
	var world := SimWorld.new(SEED)
	equal(world.combat.size(), WorldCast.CAST.size(),
		"an ordinary world should stand its own cast up")
	check(world.loop != null, "an ordinary world should have a control loop")
	check(world.loop.scene == world.combat.scene,
		"the loop should be over the world's own scene, not a scene beside it")
	check(world.follow_id != 0, "the world should be looking through somebody")
	check(world.followed() != null, "the followed id should name a member")

	# Everybody in it is a character with a name, a full roll and a decision
	# function -- the same three things a scenario's cast carries.
	var named := 0
	for one in world.combat.members:
		var sheet: Character = (one.piece as Commander).sheet
		if sheet == null:
			continue
		not_equal(sheet.character_name, "", "a member of the cast has no name")
		check(sheet.decide.is_valid(), "%s has no decision function"
			% sheet.character_name)
		for ability in Ability.ALL:
			check(sheet.has_score(ability),
				"%s has no %s recorded" % [sheet.character_name, ability])
		named += 1
	equal(named, WorldCast.CAST.size(), "every member should carry a sheet")

	# And they are one band, so an ordinary world is not a brawl.
	var bands := {}
	for one in world.combat.members:
		bands[one.band] = true
	equal(bands.size(), 1, "the ordinary cast should be one band")


## The proof the world is running: a character in it walks because its own
## decision function was asked on a stated tick, and the engine answered.
##
## Nothing here writes a choice down in advance. The check reads the loop's
## journal -- the world's own record of what it asked and what came back -- finds
## the line where a walk was resolved, and requires that the character actually
## moved between the tick before it and the tick after.
func _a_character_moves_because_it_was_asked() -> void:
	var world := SimWorld.new(SEED)
	var watched := world.followed()
	check(watched != null, "the world should be looking through somebody")
	if watched == null:
		return
	var began := Vector2(watched.x, watched.z)

	for _tick in TICKS:
		world.step()

	# The journal names the tick, the character and the choice; the engine's
	# answer is on the same line.
	var asked := 0
	var chose := 0
	var answered := 0
	for line in world.loop.journal:
		if line.contains("began %s(" % ActionCatalog.GO_TO):
			chose += 1
		if line.contains("%s %s(" % [ControlLoop.FINISHED, ActionCatalog.GO_TO]):
			answered += 1
		if line.contains("t=") :
			asked += 1
	check(chose > 0, "no character in the world chose to walk in %d ticks" % TICKS)
	check(answered > 0, "no walk the world's cast chose was ever resolved")
	check(asked > 0, "the loop wrote nothing down at all")

	var moved := Vector2(watched.x, watched.z).distance_to(began)
	check(moved > 1.0,
		"the followed character covered %.3f units in %d ticks, so nothing it"
		% [moved, TICKS] + " chose actually moved it")

	# And the world went with it: the view is the character's position, to the
	# last decimal, because it is read off the character rather than kept beside
	# it.
	equal(snappedf(world.observer_x, 0.0001), snappedf(watched.x, 0.0001),
		"the view is not standing where the character it follows is")
	equal(snappedf(world.observer_z, 0.0001), snappedf(watched.z, 0.0001),
		"the view is not standing where the character it follows is")

	# The engine, not the loop, is what actually carried the walk out: the scene
	# counts one action per resolution, on the one path every action takes.
	check(world.combat.scene.actions_of(watched.id) > 0,
		"the world's own count says nothing was ever carried out")


## Being followed is the only thing the followed character gets.
##
## The check is a comparison: the same world, stepped the same number of ticks,
## with the camera on somebody else. Every character must end up in exactly the
## same place either way -- the cast is asked the same questions on the same
## ticks whoever is being watched -- and only the view differs.
func _following_is_all_the_followed_one_gets() -> void:
	var watched := SimWorld.new(SEED)
	var other := SimWorld.new(SEED)
	check(other.combat.size() > 1, "this claim needs more than one character")
	if other.combat.size() < 2:
		return
	other.follow(other.combat.members[1].id)
	not_equal(other.follow_id, watched.follow_id, "the two worlds follow one character")

	for _tick in TICKS:
		watched.step()
		other.step()

	for index in watched.combat.members.size():
		var here := watched.combat.members[index]
		var there := other.combat.members[index]
		equal(there.line(), here.line(),
			"#%d ended up somewhere else because the camera was on somebody else"
			% here.id)
	not_equal(
		"%.3f,%.3f" % [other.observer_x, other.observer_z],
		"%.3f,%.3f" % [watched.observer_x, watched.observer_z],
		"the view did not move when the world looked through somebody else")


## One seed is one life: two worlds of a seed live it identically, and a
## different seed does not.
func _one_seed_is_one_life() -> void:
	var first := Simulation.new(SEED).run(TICKS)
	var second := Simulation.new(SEED).run(TICKS)
	equal(first, second, "two worlds of one seed lived different lives")
	not_equal(Simulation.new(SEED + 1).run(TICKS), first,
		"two seeds lived the same life")

	# The report says who is in the world and what they did in it, which is what
	# makes it a report of a game rather than of a heightfield.
	var report := "\n".join(first)
	check(report.contains("cast %d following #" % WorldCast.CAST.size()),
		"the report does not say who is in the world")
	check(report.contains("began %s(" % ActionCatalog.GO_TO),
		"the report does not say what anybody chose")


## A scenario is set out where it starts and lived forward; the frozen frame is
## still there under its own name.
func _a_scenario_is_lived_forward_unless_a_frame_is_asked_for() -> void:
	var live := Simulation.new(ScriptedScenario.SEED)
	check(live.begin_scenario(Simulation.SCENARIO_MARKET),
		"the market scenario could not be set out live")
	equal(live.world.combat.size(), ScriptedScenario.CAST.size(),
		"the live market should put its whole cast in the world")
	equal(live.world.combat.scene.actions_of(live.world.follow_id), 0,
		"a scenario set out live should not have acted before it was set out")

	# It is the world's own loop that drives them from here: nobody has to hand
	# the scenario a driver.
	for _tick in TICKS:
		live.step()
	check(live.world.combat.scene.actions_of(live.world.follow_id) > 0,
		"nothing the live scenario's cast chose was ever carried out")

	# The frozen path is the same cast, stood where a headless play of the run
	# left them: it has already acted before the first tick.
	var frozen := Simulation.new(ScriptedScenario.SEED)
	check(frozen.begin_scenario(Simulation.SCENARIO_MARKET, true),
		"the market scenario could not be photographed")
	var acted := 0
	for one in frozen.world.combat.members:
		acted += frozen.world.combat.scene.actions_of(one.id)
	equal(acted, 0,
		"a frozen frame's scene has no history: the run happened elsewhere")
	check(frozen.world.follow_id == 0,
		"a frozen frame stands its camera still rather than following anybody")


## An emptied world is the world it was before any of this existed: no cast, no
## fingerprint from the roster, and a view that stays where it is put.
func _an_emptied_world_is_the_world_it_was() -> void:
	var world := SimWorld.new(SEED)
	world.clear_cast()
	equal(world.combat.size(), 0, "clearing the cast left somebody behind")
	equal(world.follow_id, 0, "clearing the cast left the view following somebody")
	equal(world.combat.digest(), "", "an empty roster should fingerprint as nothing")

	var stood := Vector2(world.observer_x, world.observer_z)
	for _tick in 5:
		world.step()
	equal(snappedf(world.observer_x, 0.0001), snappedf(stood.x, 0.0001),
		"the view wandered off on its own with nobody to follow")
	equal(snappedf(world.observer_z, 0.0001), snappedf(stood.y, 0.0001),
		"the view wandered off on its own with nobody to follow")
	equal(world.observer_speed, 0.0, "a view following nobody is not moving")
	equal(world.combat_lines.size(), 0, "an empty world wrote a fight down")


## A cast is stood on ground it can walk from, and a walk the world refuses turns
## the walker away rather than pinning it against what stopped it.
##
## Both halves of one problem, and both are read off a seed where the problem is
## real: at seed 19 the world origin is under a river. A character put down there
## is refused every walk it ever chooses, whichever way it faces, so it stands in
## the water for the whole run -- and the world it is the view on never moves.
##
## The first half is `WorldCast._standable_near`: the written-down spot is moved
## to the nearest ground anybody can stand on. The second is the wander rule's
## own reading of the world: a leg that ended somewhere other than where it was
## aimed was refused, so the next one is drawn from the half of the circle facing
## away rather than a quarter of a radian to one side.
func _a_cast_is_stood_where_it_can_walk_from() -> void:
	var world := SimWorld.new(RIVER_SEED)
	check(world.combat.size() > 0, "the river world stood nobody up")
	var pinned := PackedStringArray()
	for one in world.combat.members:
		check(world.terrain.is_passable_at(one.x, one.z),
			"%s was stood on ground nobody can walk from" % ActionScene.name_of(one))

	# Every one of them gets somewhere. The written-down spots are all within a
	# few units of the origin, so without either half of the fix at least one of
	# them spends the whole run refused.
	var began := {}
	for one in world.combat.members:
		began[one.id] = Vector2(one.x, one.z)
	for _tick in RIVER_TICKS:
		world.step()
	for one in world.combat.members:
		var moved := Vector2(one.x, one.z).distance_to(began[one.id] as Vector2)
		if moved <= 1.0:
			pinned.append("%s moved %.3f units" % [ActionScene.name_of(one), moved])
	equal(pinned, PackedStringArray(),
		"somebody spent %d ticks pinned against what stopped it" % RIVER_TICKS)

	# And the world refused at least one of those walks, so the turn-away half is
	# something this run actually exercised rather than something it stepped past.
	var refusals := 0
	for line in world.loop.journal:
		if line.contains("refused"):
			refusals += 1
	check(refusals > 0,
		"no walk was refused in %d ticks on the river seed, so the turn away"
			% RIVER_TICKS + " from a refusal was never exercised")
