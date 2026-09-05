extends SceneTree
## What a walk looks like tick by tick, from the snapshot the render layer gets.
##
##   ./tools/measure_walk.sh [--seed N] [--ticks N]
##
## Steps `SimWorld` -- the world the render shell steps, with its own cast and
## its own control loop -- and prints one row per tick for the character the
## world is looking through: where it stands, how far it got on that tick as
## `CombatantRoster.snapshot` reports it, and which clip `CharacterView` would
## pick from that number. The loop's own journal lines are interleaved, so the
## span of a `go_to` is visible beside the motion inside it.
##
## The point of it is one question: is the character somewhere new on every tick
## of a walk, or only on the last one? A workbench, not part of the game -- but
## the numbers it prints are read off the same snapshot the shell draws from, so
## a smooth column here and a jump on screen cannot disagree.

const DEFAULT_SEED := 1234
const DEFAULT_TICKS := 48


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var ticks := DEFAULT_TICKS
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size():
			seed_value = args[i + 1].to_int()
		if args[i] == "--ticks" and i + 1 < args.size():
			ticks = args[i + 1].to_int()

	var world := SimWorld.new(seed_value)
	print("walk seed=%d ticks=%d follows=#%d stride=%.2f go_to=%dt" % [
		seed_value, ticks, world.follow_id, ActionEngine.STEP,
		ActionCatalog.occupies_of(ActionCatalog.GO_TO),
	])
	print("  tick          x          z   snapshot.speed  clip        camera")
	_row(world, 0)
	var said := 0
	for _i in ticks:
		world.step()
		_row(world, world.tick)
		said = _journal(world, said)
	print("walk end at=(%.3f, %.3f) moved_ticks=%d of %d digest=%s" % [
		world.observer_x, world.observer_z, _moving, ticks, world.digest(),
	])
	quit(0)


var _moving := 0


func _row(world: SimWorld, at_tick: int) -> void:
	var row := _followed_row(world)
	var speed := float(row.get("speed", 0.0))
	if speed > 0.0:
		_moving += 1
	var state := CharacterView.observer_state(world.snapshot())
	print("  %4d  %9.3f  %9.3f   %12.3f  %-10s  %6.3f" % [
		at_tick, float(row.get("x", 0.0)), float(row.get("z", 0.0)),
		speed, CharacterView.clip_for(state), world.observer_speed,
	])


func _followed_row(world: SimWorld) -> Dictionary:
	for row in world.snapshot()["combat"]["pieces"]:
		if int(row["id"]) == world.follow_id:
			return row
	return {}


func _journal(world: SimWorld, said: int) -> int:
	var journal := world.loop.journal
	for index in range(said, journal.size()):
		print("        | %s" % journal[index])
	return journal.size()
