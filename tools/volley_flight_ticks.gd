extends SceneTree
## Print, for one seeded volley run, which ticks have flights in the air and
## what each is: the timing a frame capture of the crossing is aimed with.


func _initialize() -> void:
	var sim := Simulation.new(1234)
	if not sim.begin_scenario(Simulation.SCENARIO_VOLLEY):
		push_error("volley refused to muster")
		quit(1)
		return
	for _tick in 60:
		sim.run(1)
		var rows := BlowFlights.flights(sim.world.snapshot())
		if rows.is_empty():
			continue
		var told := PackedStringArray()
		for row in rows:
			told.append("%s %s->%s phase=%.2f" % [
				String(row["sprite"]),
				str(row["from_cell"]), str(row["to_cell"]),
				float(row["phase"]),
			])
		print("tick %d: %s" % [
			int(sim.world.snapshot()["combat"]["tick"]), "; ".join(told),
		])
	quit(0)
