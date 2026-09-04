extends SceneTree
## Which coordinate space a chosen position is in, measured rather than argued.
##
##   tools/position_space_probe.sh
##
## The packet a model is handed says where the looker is standing in world
## coordinates and says where everything else is as an offset from it. `go_to`
## and `jump` take a world position. Nothing in the prompt says which of the two
## spaces the parameter is in, because that is a sentence about what an action
## means and the packet holds none. So a model that means "six paces back and six
## left" and a model that means "the point at world (-6, -6)" write the same
## line, and only one of them is heard.
##
## This is the size of that gap as a number. The shipped seeded model run is
## replayed -- the same run `./run_agent.sh` prints, the same recorded exchange,
## no key and no network -- and every turn on which a model named a place by its
## coordinates rather than by an id is printed with five things beside it:
##
##   * which key it was named under, which is what says the space it is in;
##   * where the character was standing when it was asked;
##   * how far the walk it asked for is;
##   * how far the walk would have been had the same two numbers been written
##     under the other key -- the reading the character may have meant;
##   * the engine's own sentence about it.
##
## Two runs print identical bytes. It measures whatever exchange is checked in,
## so running it before and after a change to the recording is how the two are
## compared; `reports/position-space-evidence.txt` holds both captures and names
## the commit each was taken at.
##
## The counts at the foot are the measurement: how many places were named, under
## which key, how many walks the engine carried out, and how many it refused for
## not being reachable -- the walk that ran out of steps and the walk that met
## something in the way, which are the two ways a place named in the wrong space
## comes back.

## The refusals that mean the named place was not somewhere the character could
## walk to. Matched against the engine's own sentence, which is quoted in full in
## the table beside every one of them.
const OUT_OF_REACH := ["too far to walk to", "the way to"]

## What the transcript says about a choice the run ended in the middle of.
const STILL_RUNNING := "still running when the run ended"


func _initialize() -> void:
	print("")
	print("=== which space a chosen position is in -- the shipped model run")
	var channel := ModelChannel.for_run(ModelRecording.exchange())
	print("  run        ./run_agent.sh, seed %d, %d ticks, replayed" % [
		ScriptedAgent.SEED, ScriptedAgent.TICKS,
	])
	print("  exchange   %s" % ModelRecording.provenance())
	var played := ScriptedAgent.played_with(channel)
	var cast: ModelCast = played["cast"]
	var loop: ControlLoop = played["loop"]

	var answers := {}
	var at := {}
	for who in cast.order:
		answers[who] = ScriptedAgent._engine_answers(loop.journal, who)
		at[who] = 0

	var rows := cast.turns()
	var named: Array[Dictionary] = []
	for turn in rows:
		var chose: Action = turn["chose"]
		if chose == null:
			continue
		var who := String(turn["who"])
		var mine: Array[Dictionary] = answers[who]
		var seen := int(at[who])
		var said := STILL_RUNNING
		if seen < mine.size():
			said = String(mine[seen]["said"])
			at[who] = seen + 1
		var under := _key_of(chose)
		if under == "":
			continue
		var packet: Observation = turn["seen"]
		var stood := Vector2(packet.self_x, packet.self_z)
		var value: Vector2 = chose.params[under]
		var relative := under == "offset"
		named.append({
			"who": who, "turn": int(turn["turn"]), "under": under, "value": value,
			"stood": stood,
			"asked": value.length() if relative else stood.distance_to(value),
			"other": stood.distance_to(value) if relative else value.length(),
			"said": said,
		})

	print("")
	print("  %-6s %-4s %-7s %-16s %-20s %8s %8s  %s" % [
		"who", "turn", "under", "the value written", "standing at",
		"the walk", "the other", "what the engine answered",
	])
	for row in named:
		print("  %-6s %-4d %-7s %-16s %-20s %8.1f %8.1f  %s" % [
			row["who"], row["turn"], row["under"],
			_said_position(row["value"]), _said_position(row["stood"]),
			row["asked"], row["other"], row["said"],
		])
	if named.is_empty():
		print("  (no turn named a place by its coordinates)")

	var under_key := {"target": 0, "offset": 0}
	var walked := 0
	var refused := 0
	var running := 0
	var unreachable := 0
	for row in named:
		under_key[row["under"]] = int(under_key[row["under"]]) + 1
		var said := String(row["said"])
		if said == STILL_RUNNING:
			running += 1
		elif said.contains(" ok "):
			walked += 1
		else:
			refused += 1
		for phrase in OUT_OF_REACH:
			if said.contains(phrase):
				unreachable += 1
				break

	print("")
	print("  turns                        %d, across %d characters" % [
		rows.size(), cast.order.size(),
	])
	print("  turns that named a place      %d" % named.size())
	print("    of those, under target      %d (a place in the world)" % int(under_key["target"]))
	print("    of those, under offset      %d (a place from where it stood)"
		% int(under_key["offset"]))
	print("  the engine walked it          %d" % walked)
	print("  the engine refused it         %d" % refused)
	print("  still running at the end      %d" % running)
	print("  refused for not being reachable  %d (the walk ran out of steps, or"
		% unreachable + " met something in the way)")
	print("  the walk asked for            %s" % _spread(named, "asked"))
	print("  the walk under the other key  %s" % _spread(named, "other"))
	quit(0)


# The key a chosen action named a place under -- `target` or `offset` -- or ""
# when it named none. The sort of the value is what says it is a place, which is
# the catalogue's own rule.
static func _key_of(chosen: Action) -> String:
	for key in chosen.params:
		if chosen.params[key] is Vector2:
			return key
	return ""


static func _said_position(where: Vector2) -> String:
	return "(%.1f, %.1f)" % [where.x, where.y]


# The smallest, middle and largest of one column, for a handful of rows.
static func _spread(rows: Array[Dictionary], key: String) -> String:
	if rows.is_empty():
		return "-"
	var all := PackedFloat32Array()
	for row in rows:
		all.append(float(row[key]))
	all.sort()
	return "%.1f least, %.1f middle, %.1f most (units)" % [
		all[0], all[all.size() / 2], all[all.size() - 1],
	]
