extends TestSuite
## Section 6's claim measured end to end: winning battles and winning hearts
## both shift ownership of the same ground.
##
## Every check runs with no key, no network and no model: the friendship run's
## three deed questions replay the recorded goodwill exchange, exactly as
## `./run_territory.sh` replays it.
##
## Six claims:
##
##   1. **The two runs are one world until they part.** Same seed, same cast,
##      same staging fingerprint; at the parting tick the two processes' worlds
##      carry the same fingerprint and the same survey of every named point.
##   2. **Before they part, the rival owns the ground.** Nothing is owned as
##      staged; six honoured trades later the green and the named near points
##      answer with the rival, built by the engine's own record and no other
##      machinery.
##   3. **Winning the fight shifts ownership by removal.** After the fight run
##      the rival is out of the cast, and every point the rival held is neutral:
##      the fallen hold no ground and their opinions hold none for anybody else.
##   4. **Winning hearts shifts ownership by out-earning.** After the friendship
##      run the rival still stands, and the green's owner is Wren, whose claim
##      there exceeds the incumbent's -- deeds and gifts against gifts alone.
##   5. **Both paths moved sampled ground**, counted over the same grid, and the
##      counts are the run's own numbers rather than impressions.
##   6. **Both effects are local.** The far road hears nobody and is neutral in
##      every survey of both runs.
class_name TestTerritory

func _init() -> void:
	suite_name = "territory"


func run() -> void:
	var channel := ModelChannel.for_run(ModelRecording.goodwill_exchange())
	var fought := ScriptedTerritory.played_with(channel, ScriptedTerritory.FIGHT)
	var loved := ScriptedTerritory.played_with(channel, ScriptedTerritory.FRIENDSHIP)
	_one_world_until_they_part(fought, loved)
	_the_rival_owns_the_ground_before(fought)
	_the_fight_removes_the_owner(fought)
	_the_friendship_out_earns_him(loved)
	_both_paths_moved_ground(fought, loved)
	_both_effects_are_local(fought, loved)


func _one_world_until_they_part(fought: Dictionary, loved: Dictionary) -> void:
	equal(ScriptedTerritory.stage().fingerprint(),
		ScriptedTerritory.stage().fingerprint(),
		"two staged scenes carry one fingerprint")
	var fight_parted: Dictionary = fought["parted"]
	var love_parted: Dictionary = loved["parted"]
	equal(fight_parted["fingerprint"], love_parted["fingerprint"],
		"at the parting tick the two runs' worlds are byte-for-byte one world")
	for at in ScriptedTerritory.POINTS.size():
		var one: Dictionary = fight_parted["points"][at]
		var other: Dictionary = love_parted["points"][at]
		equal(int(one["owner"]), int(other["owner"]),
			"the parting owner of %s is the same in both runs"
			% ScriptedTerritory.POINTS[at]["named"])


func _the_rival_owns_the_ground_before(fought: Dictionary) -> void:
	var staged: Dictionary = fought["staged"]
	for point in staged["points"]:
		equal(int(point["owner"]), OwnershipField.NOBODY,
			"as staged, %s is neutral: nobody has met anybody" % point["named"])
	var scene: ActionScene = fought["scene"]
	var parted: Dictionary = fought["parted"]
	for at in ScriptedTerritory.POINTS.size() - 1:
		# Named, not by id: the rival is out of this run's cast by the end, and
		# `_owner_name` still names the fallen off the staged order.
		equal(ScriptedTerritory._owner_name(
				int(parted["points"][at]["owner"]), scene),
			ScriptedTerritory.ROOK,
			"at the parting, %s is the rival's, earned by trading"
			% ScriptedTerritory.POINTS[at]["named"])


func _the_fight_removes_the_owner(fought: Dictionary) -> void:
	var scene: ActionScene = fought["scene"]
	check(ScriptedTerritory._named(scene, ScriptedTerritory.ROOK) == null,
		"after the fight run the rival is no longer in the cast")
	var deeds: DeedDesk = fought["deeds"]
	var desk: CheckDesk = fought["desk"]
	equal(desk.calls + deeds.calls, 0,
		"the fight run makes no model call: no word is spoken, no goal closes")
	var ended: Dictionary = fought["ended"]
	for point in ended["points"]:
		equal(int(point["owner"]), OwnershipField.NOBODY,
			"after the fight, %s is neutral: the fallen hold no ground"
			% point["named"])
	equal((ended["cells"] as Dictionary).size(), 0,
		"after the fight, not one sampled point on the grid has an owner")


func _the_friendship_out_earns_him(loved: Dictionary) -> void:
	var scene: ActionScene = loved["scene"]
	var rook := ScriptedTerritory._named(scene, ScriptedTerritory.ROOK)
	check(rook != null and rook.is_alive(),
		"after the friendship run the rival still stands")
	var wren_id := _id_of(scene, ScriptedTerritory.WREN)
	var green: Dictionary = (loved["ended"] as Dictionary)["points"][0]
	equal(int(green["owner"]), wren_id,
		"after the friendship, the green's owner is Wren")
	check(float(green["wren"]) > float(green["rook"]),
		"Wren's claim at the green exceeds the incumbent's")
	check(float(green["rook"]) > 0.0,
		"the incumbent's claim was out-earned, not erased")
	var deeds: DeedDesk = loved["deeds"]
	equal(deeds.deeds().size(), 3,
		"three deeds were read off the world's own records, one per neighbour")


func _both_paths_moved_ground(fought: Dictionary, loved: Dictionary) -> void:
	var by_fighting := ScriptedTerritory._changed_hands(fought)
	var by_loving := ScriptedTerritory._changed_hands(loved)
	check(by_fighting > 0,
		"the fight changed the owner of at least one sampled point")
	check(by_loving > 0,
		"the friendship changed the owner of at least one sampled point")


func _both_effects_are_local(fought: Dictionary, loved: Dictionary) -> void:
	var far := ScriptedTerritory.POINTS.size() - 1
	for played in [fought, loved]:
		for survey in [played["staged"], played["parted"], played["ended"]]:
			equal(int((survey["points"] as Array)[far]["owner"]),
				OwnershipField.NOBODY,
				"the far road hears nobody and is neutral in the %s run's tick-%d survey"
				% [played["arm"], int(survey["tick"])])


func _id_of(scene: ActionScene, who: String) -> int:
	var one := ScriptedTerritory._named(scene, who)
	return OwnershipClaim.NOBODY if one == null else one.id
