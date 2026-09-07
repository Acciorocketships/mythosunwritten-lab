extends SceneTree
## Review probe (W-territory-review): what the implemented ownership average
## does with status and level, at the two edges section 6's sentence does not
## pin down.
##
## Section 6 reads "distance-weighted average of weighted sentiment", weighted
## sentiment being raw sentiment scaled by status and level. The implementation
## (`sim/ownership_field.gd`) divides by the sum of proximity-times-carry, so
## carry is a *relative voting weight* rather than a magnitude. Two
## consequences follow that no shipped table shows, and this probe measures
## both rather than arguing them:
##
##   A -- a lone voter's carry cancels: one neighbour's opinion produces the
##        same score whether that neighbour is level 1 or level 9.
##   B -- a claimant's own status and level never enter its own claim: the
##        claimant at level 2 and at level 9 scores identically on the same
##        ground with the same crowd.
##
## Neither is asserted to be wrong; both are facts about the shipped rule that
## the review reports with numbers.
##
## Run:  tools/godot/godot4 --headless --path . --script res://tools/critic_ownership_carry_probe.gd

const AT := Vector2(-480.0, 420.0)


func _initialize() -> void:
	print("=== A: one voter, three carries -- does the voter's weight move a lone opinion?")
	for voter_level in [1, 5, 9]:
		var scored := _lone_voter_score(voter_level, 2)
		print("  voter level %d (carry %d): claimant's score %+.4f" % [
			voter_level, 2 * voter_level, scored])

	print("")
	print("=== B: the claimant's own level, three ways -- does it enter its own claim?")
	for claimant_level in [2, 5, 9]:
		var scored := _lone_voter_score(3, claimant_level)
		print("  claimant level %d (carry %d): claimant's score %+.4f" % [
			claimant_level, 2 * claimant_level, scored])

	print("")
	print("=== C: two voters of unequal carry -- the relative weighting that does work")
	print("  one likes the claimant, one is a stranger, both at the point:")
	for liked_by_level in [1, 9]:
		var scored := _two_voter_score(liked_by_level, 1)
		print("  friend level %d vs stranger level 1: score %+.4f" % [
			liked_by_level, scored])
	quit(0)


# One claimant, one voter standing on the point, one edge built the way the
# engine builds one: a single honoured gift, so the voter's sentiment toward
# the claimant is the familiarity-times-trust a trade earns. Nobody else in
# the world.
func _lone_voter_score(voter_level: int, claimant_level: int) -> float:
	var scene := ActionScene.on(TerrainQuery.for_seed(1234))
	var claimant := _commander(scene, AT.x + 300.0, AT.y, "Claimant", claimant_level)
	var voter := _commander(scene, AT.x, AT.y, "Voter", voter_level)
	scene.relationships.traded(claimant.id, voter.id, 1, 0, 0, 0)
	var claim := OwnershipField.at(scene.actors, scene.relationships, AT.x, AT.y)
	return claim.score_of(claimant.id)


# Two voters on the point: one trusts the claimant, one has never met anybody.
func _two_voter_score(friend_level: int, stranger_level: int) -> float:
	var scene := ActionScene.on(TerrainQuery.for_seed(1234))
	var claimant := _commander(scene, AT.x + 300.0, AT.y, "Claimant", 2)
	var friend := _commander(scene, AT.x, AT.y, "Friend", friend_level)
	_commander(scene, AT.x + 1.0, AT.y, "Stranger", stranger_level)
	scene.relationships.traded(claimant.id, friend.id, 1, 0, 0, 0)
	var claim := OwnershipField.at(scene.actors, scene.relationships, AT.x, AT.y)
	return claim.score_of(claimant.id)


func _commander(
	scene: ActionScene, x: float, z: float, named: String, level: int
) -> Combatant:
	var one := scene.add_actor(Combatant.commander_at(
		x, z, 0.0, 0.0, level, AssetTags.KNIGHT))
	var sheet := Character.make(named, level)
	(one.piece as Commander).adopt(sheet)
	one.settle(scene.terrain)
	return one
