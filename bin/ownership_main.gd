extends SceneTree
## Entry point for the ownership measurement: the tables the three constants
## section 6 leaves open were chosen against. Exit 0.
##
## Run it with:  ./run_ownership.sh [--cost]
##
## `--cost` puts a clock around one sweep of the stated grid. The clock is read
## here rather than in `ScriptedOwnership`, because nothing under sim/ may read
## one -- the simulation would stop being a function of its seed -- and because
## a report with a duration in it could not be byte-identical across two
## processes. So the timing is the last two lines and everything above them is.


func _initialize() -> void:
	var with_cost := false
	for arg in OS.get_cmdline_user_args():
		if arg != "--cost":
			printerr("unknown argument '%s'" % arg)
			printerr("usage: run_ownership.sh [--cost]")
			quit(2)
			return
		with_cost = true

	for line in ScriptedOwnership.report():
		print(line)
	if with_cost:
		for line in _the_clock():
			print(line)
	quit(0)


# One sweep of the stated grid, timed from outside the simulation.
func _the_clock() -> PackedStringArray:
	var scene := ScriptedOwnership.staged()
	var began := Time.get_ticks_usec()
	var points := ScriptedOwnership.sample_all(scene)
	var spent := Time.get_ticks_usec() - began
	return PackedStringArray([
		"   the whole grid of %d points took %.1f ms, %.1f us a point." % [
			points, float(spent) / 1000.0,
			float(spent) / float(maxi(1, points)),
		],
	])
