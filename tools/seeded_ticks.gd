extends SceneTree
## Print, tick by tick, the two things tests write tick numbers down about: what
## the ownership rule says about the ground under the followed character, and
## whether a fight is on. Probe only: steps a simulation of its own and writes
## nothing.
##
## It exists because a tick number written into a test is a claim about a seeded
## run, and such a claim goes quietly out of date whenever anything changes how
## fast the run gets through its plan -- which is how a `NEUTRAL_TICK := 55` in
## tests/test_ui_territory.gd survived a change that moved the tick it named
## from 62 to 34. Rather than trust a number in a comment, ask.
##
## Run it with:
##   ./tools/seeded_ticks.sh --seed 1234 --scenario market --ticks 90
##   ./tools/seeded_ticks.sh --seed 1234 --scenario encounter --ticks 40

const DEFAULT_SEED := 1234
const DEFAULT_TICKS := 120


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var ticks := DEFAULT_TICKS
	var scenario := Simulation.SCENARIO_MARKET
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seed" and index + 1 < args.size():
			seed_value = int(args[index + 1])
		elif args[index] == "--ticks" and index + 1 < args.size():
			ticks = int(args[index + 1])
		elif args[index] == "--scenario" and index + 1 < args.size():
			scenario = String(args[index + 1])

	var sim := Simulation.new(seed_value)
	sim.begin_scenario(scenario)
	var followed := sim.world.follow_id
	print("seeded ticks: seed %d, scenario %s, followed id %d (%s)"
		% [seed_value, scenario, followed, TerritorySource.name_of(sim.world, followed)])
	print("tick  ground                    best      considered  edges  fight")

	var was := ""
	for _tick in ticks:
		sim.step()
		var scene := sim.world.combat.scene
		var claim := _claim_under(sim, sim.world.follow_id)
		var reads := "no actor"
		if claim != null:
			reads = "neutral" if claim.is_neutral() \
				else "owned by %s" % TerritorySource.name_of(sim.world, claim.owner_id)
		var fighting := "on" if scene.fight != null else "-"
		var line := "%4d  %-24s  %+.3f    %-10d  %-5d  %s" % [sim.world.tick, reads,
			0.0 if claim == null else claim.best,
			0 if claim == null else claim.considered,
			scene.relationships.edges_of(followed).size(),
			fighting]
		var state := "%s|%s" % [reads, fighting]
		if state != was:
			print("%s   <- changed" % line)
			was = state
		else:
			print(line)
	quit(0)


## The rule's own answer for the ground under one character, asked directly of
## the field -- the same call tests/test_ui_territory.gd makes.
func _claim_under(sim: Simulation, id: int) -> OwnershipClaim:
	var scene := sim.world.combat.scene
	var one := scene.actor_of(id)
	if one == null:
		return null
	return OwnershipField.at(scene.actors, scene.relationships, one.x, one.z)
