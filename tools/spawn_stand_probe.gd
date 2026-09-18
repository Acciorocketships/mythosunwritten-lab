extends SceneTree
## Where the ordinary cast is stood up, and whether it can walk from there.
##
## The suites that walk a world and then ask what the walking did -- streaming's
## `_the_world_streams_as_the_observer_walks`, live world's `_a_cast_is_stood_
## where_it_can_walk_from` -- fail on some seeds of the adopted base with the
## observer at exactly its starting position. This prints the ground under each
## of `WorldCast.CAST`'s written-down spots, where the landing search actually
## put that character, and how far the view has travelled after a run of ticks,
## so the difference between "nobody is followed", "the cast is standing in
## water" and "the cast simply stayed near home" can be told apart by reading
## rather than by guessing.
##
## Usage: godot4 --headless --path . -s res://tools/spawn_stand_probe.gd \
##   -- --seed 7 --ticks 200

const DEFAULT_SEED := 7
const DEFAULT_TICKS := 200

## How far out the reach scan below looks, in world units: well past the adopted
## base's spawn clearing, which is 60 units of exactly-zero ground with its
## height fading back in over the next 180 (HeightfieldPlan.height01).
const SCAN_REACH := 400.0


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var ticks := DEFAULT_TICKS
	var arguments := OS.get_cmdline_user_args()
	var index := 0
	while index < arguments.size() - 1:
		match arguments[index]:
			"--seed":
				seed_value = int(arguments[index + 1])
			"--ticks":
				ticks = int(arguments[index + 1])
		index += 1

	var lines := PackedStringArray()
	lines.append("seed %d ticks %d" % [seed_value, ticks])

	# The ground under each written-down spot, before anybody is stood on it.
	var terrain := TerrainQuery.for_seed(seed_value)
	for row in WorldCast.CAST:
		var at: Vector2 = row["at"] as Vector2
		lines.append(
			"spot %-7s at=(%.3f, %.3f) height=%.3f water=%s passable=%s" % [
				String(row["name"]), at.x, at.y,
				terrain.ground_height_at(at.x, at.y),
				terrain.is_water_at(at.x, at.y, terrain.ground_height_at(at.x, at.y)),
				terrain.is_passable_at(at.x, at.y),
			])

	# How far the landing search would have to reach from each spot before it
	# finds ground anybody can stand on: the same ring search WorldCast uses,
	# run out to a reach that is not the one in the constant.
	for row in WorldCast.CAST:
		var at: Vector2 = row["at"] as Vector2
		var found := Vector2.INF
		var at_radius := 0.0
		var ring := 1
		while ring <= int(SCAN_REACH / WorldCast.LANDING_STEP) and found == Vector2.INF:
			var radius := float(ring) * WorldCast.LANDING_STEP
			var around := ring * 8
			for step in around:
				var angle := float(step) * TAU / float(around)
				var here := at + Vector2(cos(angle), sin(angle)) * radius
				if terrain.is_passable_at(here.x, here.y):
					found = here
					at_radius = radius
					break
			ring += 1
		if found == Vector2.INF:
			lines.append("reach %-7s nothing standable within %.0f units" % [
				String(row["name"]), SCAN_REACH])
		else:
			lines.append("reach %-7s first standable at %.1f units, (%.3f, %.3f)" % [
				String(row["name"]), at_radius, found.x, found.y])

	var sim := Simulation.new(seed_value)
	var world := sim.world
	lines.append("cast %d following #%d" % [world.combat.size(), world.follow_id])
	for one in world.combat.members:
		lines.append("stood #%d at=(%.3f, %.3f, %.3f) passable=%s" % [
			one.id, one.x, one.y, one.z,
			terrain.is_passable_at(one.x, one.z),
		])
	lines.append("observer at=(%.3f, %.3f) before" % [world.observer_x, world.observer_z])

	var built_before: int = world.scatter_streamer.patches_built
	for i in ticks:
		sim.step()

	lines.append("observer at=(%.3f, %.3f) after %d ticks, %.3f from the origin" % [
		world.observer_x, world.observer_z, ticks,
		Vector2(world.observer_x, world.observer_z).length(),
	])
	for one in world.combat.members:
		lines.append("ended #%d at=(%.3f, %.3f, %.3f)" % [one.id, one.x, one.y, one.z])
	lines.append("chunks built %d -> %d, loaded %d" % [
		built_before, world.scatter_streamer.patches_built,
		world.scatter_streamer.loaded_count(),
	])

	print("\n".join(lines))
	quit(0)
