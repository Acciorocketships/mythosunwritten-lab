extends TestSuite
## The seed determines the world.
##
## The important half of this suite runs the documented headless command twice
## as a real subprocess, because that -- not an in-process loop -- is what the
## acceptance criterion is about: two headless runs with the same seed must
## produce byte-identical output, and two runs with different seeds must not.
class_name TestDeterminism

const TICKS := 50

## The seed the two-route check works with. Any seed does; a fixed one keeps
## the check reproducible.
const SEED := 20250824


func _init() -> void:
	suite_name = "determinism"


func run() -> void:
	_in_process_runs_match()
	_seed_reaches_the_world()
	_two_routes_to_the_same_ground_agree()
	_headless_runs_match()


func _in_process_runs_match() -> void:
	var first := Simulation.new(1234).run(TICKS)
	var second := Simulation.new(1234).run(TICKS)
	equal(first, second, "same seed should give the same report")

	var other := Simulation.new(1235).run(TICKS)
	not_equal(other, first, "a different seed should give a different report")


func _seed_reaches_the_world() -> void:
	var sim := Simulation.new(999)
	equal(sim.world.world_seed, 999, "the seed should be stored on the world")
	equal(sim.world.tick, 0, "a fresh world should be at tick 0")
	sim.run(TICKS)
	equal(sim.world.tick, TICKS, "the world should have advanced exactly %d ticks" % TICKS)

	# Resetting to a seed rebuilds the same world the constructor would have.
	var rebuilt := SimWorld.new(999)
	var reused := SimWorld.new(1)
	reused.reset(999)
	equal(reused.digest(), rebuilt.digest(), "reset(seed) should rebuild the same world")


## The same ground, reached two ways, is the same world.
##
## Every other check here compares two runs of the same seed, which take the
## same route and so load their chunks in the same order -- any dependence on
## that order cancels out on both sides and stays invisible. This one loads one
## set of chunks by two different orderings of the same pair of observers. The
## loaded set is a set, so the fingerprint of the world must not be able to tell
## which order it was filled in.
func _two_routes_to_the_same_ground_agree() -> void:
	# Both observers stand away from where the world starts. A fresh world has
	# already loaded the ground around the origin, so an observer standing there
	# adds nothing and the two orderings would fill the loaded set identically --
	# which would make this check pass for the wrong reason.
	var here := Vector2(70.0, -45.0)
	var there := Vector2(-60.0, 50.0)

	var one := SimWorld.new(SEED)
	one.terrain_streamer.update([here, there])

	var other := SimWorld.new(SEED)
	other.terrain_streamer.update([there, here])

	# The routes have to arrive at the same ground, or comparing the two
	# fingerprints would prove nothing.
	equal(other.terrain_streamer.loaded_keys(), one.terrain_streamer.loaded_keys(),
		"the two orderings loaded different ground, so the digests below "
		+ "would not be comparable")
	check(one.terrain_streamer.loaded_count() > 20,
		"expected a substantial loaded set, got %d chunk(s)"
		% one.terrain_streamer.loaded_count())

	equal(other.digest(), one.digest(),
		"the same loaded ground fingerprinted differently depending on the "
		+ "order the observers were given in")


func _headless_runs_match() -> void:
	var same_a := _run_headless(1234)
	var same_b := _run_headless(1234)
	var different := _run_headless(4321)

	equal(same_a["exit_code"], 0, "headless run should exit 0 (stdout: %s)" % same_a["output"])
	equal(same_b["exit_code"], 0, "headless run should exit 0")
	equal(different["exit_code"], 0, "headless run should exit 0")

	check(not same_a["output"].strip_edges().is_empty(), "headless run produced no output")
	equal(same_a["output"], same_b["output"],
		"two headless runs with seed 1234 should produce identical output")
	not_equal(different["output"], same_a["output"],
		"headless runs with seeds 1234 and 4321 should produce different output")


## Run the same command run_headless.sh runs, and capture what it printed.
func _run_headless(seed_value: int) -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(seed_value),
		"--ticks", str(TICKS),
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}
