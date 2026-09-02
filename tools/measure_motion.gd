extends SceneTree
## What the clip rule actually chooses as the world walks.
##
##   ./tools/measure_motion.sh [--seed N] [--ticks N]
##
## Steps the simulation and asks CharacterView.clip_for() for every tick, so the
## question "which of the six clips does the world as it stands ever reach?" is
## answered by counting rather than by reasoning about thresholds. It also prints
## the speed and the rise it saw, which are the two numbers the rule reads.
##
## A workbench, not part of the game. It is the only place the two layers are put
## side by side on purpose: the simulation walks, the render layer's rule reads.

const DEFAULT_SEED := 1234
const DEFAULT_TICKS := 2000


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
	var counts := {}
	for clip in CharacterView.CLIPS:
		counts[clip] = 0
	var top_speed := 0.0
	var top_rise := -INF
	var low_rise := INF

	counts[CharacterView.clip_for(CharacterView.observer_state(world.snapshot()))] += 1
	for i in ticks:
		world.step()
		var snapshot := world.snapshot()
		var state := CharacterView.observer_state(snapshot)
		counts[CharacterView.clip_for(state)] += 1
		top_speed = maxf(top_speed, float(state["speed"]))
		top_rise = maxf(top_rise, float(state["rise"]))
		low_rise = minf(low_rise, float(state["rise"]))

	print("motion seed=%d ticks=%d speed<=%.3f rise=[%+.3f,%+.3f] hop>=%.2f" % [
		seed_value, ticks, top_speed, low_rise, top_rise, CharacterView.HOP_RISE,
	])
	for clip in CharacterView.CLIPS:
		print("  %-16s %6d  %5.1f%%" % [
			clip, counts[clip], 100.0 * float(counts[clip]) / float(ticks + 1),
		])
	quit(0)
