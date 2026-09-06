extends SceneTree
## What the enemy layer costs, measured headless.
##
##   ./tools/measure_enemies.sh [--seed N] [--ticks N] [--seeds "a b c"]
##
## Two worlds of the same seed are stepped side by side for the same number of
## ticks: one ordinary, and one whose enemy layer has been told not to stand
## anybody up (`EnemyStreamer.spawning`, which exists for this measurement and is
## also what a scenario's stage turns off). The difference between the two is
## what the layer costs -- standing enemies up, dropping them, and stepping the
## characters it stood up, all of it.
##
## It prints microseconds per tick for each, the difference, and how many enemies
## were standing at the most and on average, so the cost can be read per enemy as
## well as per tick.
##
## A workbench, not part of the game. It is the one place in the project that
## reads a clock, and nothing it measures feeds back into the world: the two
## worlds are stepped identically and the timings are printed, never stored.

const DEFAULT_SEED := 1234
const DEFAULT_TICKS := 300


func _initialize() -> void:
	var seed_value := DEFAULT_SEED
	var ticks := DEFAULT_TICKS
	var seeds := PackedInt32Array()
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size():
			seed_value = args[i + 1].to_int()
		if args[i] == "--ticks" and i + 1 < args.size():
			ticks = args[i + 1].to_int()
		if args[i] == "--seeds" and i + 1 < args.size():
			for word in args[i + 1].split(" ", false):
				seeds.append(word.to_int())
	if seeds.is_empty():
		seeds.append(seed_value)

	print("enemy cost: %d ticks a world, cell=%.1f spawn=%.1f keep=%.1f at_most=%d" % [
		ticks, EnemyField.CELL, EnemyStreamer.SPAWN_RADIUS,
		EnemyStreamer.KEEP_RADIUS, EnemyStreamer.AT_MOST,
	])
	print("  seed      with us/tick   without us/tick    cost us/tick"
		+ "   most   mean   spawned  dropped   us/enemy/tick")
	for one_seed in seeds:
		_row(one_seed, ticks)
	quit(0)


func _row(seed_value: int, ticks: int) -> void:
	var with := _run(seed_value, ticks, true)
	var without := _run(seed_value, ticks, false)
	var cost := float(with["us"]) / float(ticks) - float(without["us"]) / float(ticks)
	var mean := float(with["standing"]) / float(maxi(1, ticks))
	print("  %-8d %14.1f %17.1f %15.1f %6d %6.2f %9d %8d %15.2f" % [
		seed_value,
		float(with["us"]) / float(ticks),
		float(without["us"]) / float(ticks),
		cost,
		int(with["most"]),
		mean,
		int(with["spawns"]),
		int(with["despawns"]),
		0.0 if mean <= 0.0 else cost / mean,
	])


## Step one world and hand back what it cost and how many enemies it held.
##
## The clock is read around `SimWorld.step()` and nowhere else, so what is timed
## is a tick of the world and not the building of it.
func _run(seed_value: int, ticks: int, enemies: bool) -> Dictionary:
	var world := SimWorld.new(seed_value)
	if not enemies:
		# `stop()` stops the layer; whoever it had already stood up at reset is
		# taken out by hand, so the world being measured without the layer really
		# has nobody in it from the layer.
		world.enemy_streamer.stop()
		for one in world.combat.scene.actors.duplicate():
			if one.band == EnemyStreamer.WILD_BAND:
				world.combat.scene.remove_actor(one)
				world.loop.forget(one.id)
	var standing := 0
	var most := 0
	var spent := 0
	for _tick in ticks:
		var began := Time.get_ticks_usec()
		world.step()
		spent += Time.get_ticks_usec() - began
		var now := world.enemy_streamer.standing_count()
		standing += now
		most = maxi(most, now)
	return {
		"us": spent,
		"standing": standing,
		"most": most,
		"spawns": world.enemy_streamer.spawns,
		"despawns": world.enemy_streamer.despawns,
	}
