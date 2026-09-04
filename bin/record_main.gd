extends SceneTree
## Put the shipped model run's questions to a real language model, once, and
## write what comes back into `net/model_recording.gd`.
##
## Run it with:  OPENROUTER_API_KEY=... ./run_record.sh --live
##
## This is the only entry point in the repository that touches the network, and
## nothing else ever calls it: not `./run_tests.sh`, not `./run_agent.sh`, not
## any other run script. Without `--live` it says what it would do and writes
## nothing, so that the command is safe to type by mistake.
##
## Everything below the marker in that file is this command's output, and that
## includes every function under it: `exchange()`, `size()` and `provenance()`
## are written out again each time. A rewrite that dropped one of them would
## leave a recording nothing could read, which is a worse failure than not
## recording at all because it only shows up on the next run.
##
## What it writes is the model's own words, including where those words were
## none. A question the provider declines is written down as an empty reply and
## reported on the way out: the run replays that as "the model said nothing
## readable", keeps the reason on the turn, and asks the character again on its
## next tick. This command used to refuse to write at all in that case, which was
## right when a run put seventeen questions and wrong now that it puts seventy --
## one declined question in seventy would have cost every other answer in the
## pass.
##
## Each question is put `TRIES` times before its answer is taken as final.
##
## ## `--cast`, `--checks` and `--world`
##
## With `--live --checks` only the difficulty-class run's questions are put, with
## `--live --world` only the orchestrator run's, and with `--live --cast` only
## the three tables the character runs read -- the shipped run, the lesson
## comparison and the goal comparison, which are recorded together because they
## put questions to the same sort of mind about the same characters. Whichever is
## asked for, every other table is written back byte for byte as it already
## stands, keeping its own date.
##
## The tables have dates of their own, and the reason any group may be recorded
## alone is the reason a whole pass would be wrong: every number quoted off the
## other runs' transcripts is a fact about the draw that recorded them, and
## re-recording them because a character prompt changed would move all of those
## for nothing. A pass with no flag at all still records all five together.

const RECORDING := "res://net/model_recording.gd"

## How many ticks past the end of the shipped run the recorder plays.
##
## A question is written down when the deciding side takes its answer, and a
## question put in the last few ticks of the run is answered -- and paid for --
## after the last tick has gone by, so it is dropped. The shipped run then puts a
## question the recording has no reply for and the character stands there for the
## rest of it. Playing on for a moment lets that last answer land. The extra rows
## are read in order like every other, so a row the shipped run never reaches
## costs nothing but the call that made it.
const AFTER := 20


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var live := args.has("--live")
	# Record one group of tables alone and write every other one back exactly as
	# it is. See the note on `--cast`, `--checks` and `--world` at the head of
	# this file.
	var only_checks := args.has("--checks")
	var only_world := args.has("--world")
	var only_cast := args.has("--cast")
	var everything := not only_checks and not only_world and not only_cast
	var credentials := ModelCall.credentials()
	# Where this pass would go, rather than where the shipped recording came
	# from. They are the same unless the environment names a local endpoint, and
	# the whole reason the head prints it is so that a pass which is not the
	# shipped kind cannot be mistaken for one.
	var where := ModelCall.endpoint()
	print("recorder: %s" % (where["url"] if where["ok"] else "nowhere"))
	print("  model      %s%s" % [
		where["model"], " (running locally)" if where["local"] else "",
	])
	print("  credential %s" % credentials["why"])
	print("  putting    %s" % _what_is_being_put(
		everything, only_cast, only_checks, only_world))
	if not live:
		print("  did nothing: pass --live to actually call the model")
		print("")
		for line in _first_question():
			print(line)
		quit(0)
		return
	if not credentials["ok"]:
		printerr("  did nothing: %s" % credentials["why"])
		printerr("  a person with a key would run:")
		printerr("    %s=sk-... ./run_record.sh --live" % ModelCall.KEY_VARIABLE)
		printerr("  or, against a model running on this machine:")
		printerr("    %s=http://127.0.0.1:11435/v1/chat/completions \\" % (
			ModelCall.ENDPOINT_VARIABLE))
		printerr("    %s=<the model> ./run_record.sh --live" % ModelCall.MODEL_VARIABLE)
		quit(1)
		return

	var rows := {
		"main": ModelRecording.ROWS, "lessons": ModelRecording.LESSON_ROWS,
		"goals": ModelRecording.GOAL_ROWS, "checks": ModelRecording.CHECK_ROWS,
		"world": ModelRecording.WORLD_ROWS,
		"on": ModelRecording.RECORDED_ON,
		"checks_on": ModelRecording.CHECKS_RECORDED_ON,
		"world_on": ModelRecording.WORLD_RECORDED_ON,
	}
	if everything or only_cast:
		var channel := _fresh()
		var played := ScriptedAgent.played_with(channel, ScriptedAgent.TICKS + AFTER)
		var cast: ModelCast = played["cast"]
		print("  asked      %d questions for the shipped run, %d answered" % [
			channel.asked(), channel.exchanges.size(),
		])
		for turn in cast.turns():
			print("    %-6s %-16s %s" % [turn["who"], turn["observed"], turn["said"]])

		# The lesson comparison's own four questions, put in the same pass and out
		# of a second channel, so that the two tables are recorded together and can
		# never be a recording of two different days.
		var lessons := _fresh()
		for line in ScriptedLesson.play(lessons):
			print("    | %s" % line)
		print("  asked      %d questions for the lesson comparison, %d answered" % [
			lessons.asked(), lessons.exchanges.size(),
		])

		# The goal comparison's own four questions, put in the same pass and out of
		# a third channel, for the same reason the lesson comparison's are.
		var goals := _fresh()
		for line in ScriptedGoal.play(goals):
			print("    | %s" % line)
		print("  asked      %d questions for the goal comparison, %d answered" % [
			goals.asked(), goals.exchanges.size(),
		])
		if channel.exchanges.is_empty() or lessons.exchanges.is_empty() \
				or goals.exchanges.is_empty():
			printerr("  wrote nothing: one of the three exchanges is empty")
			quit(1)
			return
		var faults := _empty_in(channel, "the shipped run") \
			+ _empty_in(lessons, "the lesson comparison") \
			+ _empty_in(goals, "the goal comparison")
		if faults > 0:
			_report_empty(faults)
		rows["main"] = channel.exchanges
		rows["lessons"] = lessons.exchanges
		rows["goals"] = goals.exchanges
		rows["on"] = Time.get_date_string_from_system(true)

	# The difficulty-class run's own questions, out of a channel of its own. How
	# many there are is not fixed: one to judge each attempt of a shape the
	# character has not attempted before, and one more for each of those the engine
	# then rolled a success on. An attempt of a shape already in the character's
	# memory puts none.
	if everything or only_checks:
		var dc := _fresh()
		for line in ScriptedCheck.play(dc):
			print("    | %s" % line)
		print("  asked      %d questions for the difficulty-class run, %d answered" % [
			dc.asked(), dc.exchanges.size(),
		])
		var declined := _empty_in(dc, "the difficulty-class run")
		if declined > 0:
			_report_empty(declined)
		if dc.exchanges.is_empty():
			printerr("  wrote nothing: the difficulty-class exchange is empty")
			quit(1)
			return
		rows["checks"] = dc.exchanges
		rows["checks_on"] = Time.get_date_string_from_system(true)

	# The orchestrator run's own questions, out of a channel of its own. How many
	# there are is not fixed either: one every time it looks at the world, and one
	# more every time a look spawned somebody.
	if everything or only_world:
		var dm := _fresh()
		for line in ScriptedWorld.play(dm):
			print("    | %s" % line)
		print("  asked      %d questions for the orchestrator run, %d answered" % [
			dm.asked(), dm.exchanges.size(),
		])
		var quiet := _empty_in(dm, "the orchestrator run")
		if quiet > 0:
			_report_empty(quiet)
		if dm.exchanges.is_empty():
			printerr("  wrote nothing: the orchestrator exchange is empty")
			quit(1)
			return
		rows["world"] = dm.exchanges
		rows["world_on"] = Time.get_date_string_from_system(true)

	var written := _write(rows)
	if written == "":
		printerr("  could not write %s" % RECORDING)
		quit(1)
		return
	print("  wrote      %s, %d replies, %d lesson, %d goal, %d check and %d world replies" % [
		RECORDING, (rows["main"] as Array).size(), (rows["lessons"] as Array).size(),
		(rows["goals"] as Array).size(), (rows["checks"] as Array).size(),
		(rows["world"] as Array).size(),
	])
	if everything or only_cast:
		print("  now run:   ./run_agent.sh > reports/agent-evidence.txt")
		print("             ./run_lesson.sh > reports/lesson-evidence.txt")
		print("             ./run_goal.sh > reports/goal-evidence.txt")
	if everything or only_checks:
		print("  now run:   ./run_check.sh > reports/check-evidence.txt")
	if everything or only_world:
		print("  now run:   ./run_world.sh > reports/world-evidence.txt")
	quit(0)


# What a question the provider declined costs, said once for whichever table it
# was in. Written down as what it was, not dropped: the provider was asked TRIES
# times and answered with nothing every time, so an empty row is the honest
# record of that question. The run replays it as "the model said nothing
# readable", records the turn with the reason on it, and asks again on the next
# tick. Refusing to write the recording at all -- which this command used to do
# -- means one declined question in seventy costs the whole pass, and at this
# cast's volume that is a recording that can never be made.
func _report_empty(declined: int) -> void:
	printerr("  %d answer%s came back empty and %s written down as such" % [
		declined, "" if declined == 1 else "s",
		"is" if declined == 1 else "are",
	])


## How many times one question is put before its answer is taken as final.
##
## A run of the whole cast puts about seventy questions in one pass, and measured
## over three passes the provider declines one or two of them -- the same question
## answered on one pass and refused on the next, which makes it a flaky classifier
## and not a judgement about the question. Asking again is the cheapest honest
## answer: the question is unchanged, and what is written down is still something
## the model said. Six is enough that a decline surviving every try is rare;
## when one does, it is written down as an empty reply and reported.
const TRIES := 6


# A channel with nothing written down yet, which therefore asks the model
# everything.
func _fresh() -> ModelChannel:
	return ModelChannel.recording(
		{
			"rows": [], "from": "nothing recorded yet",
			"model": ModelCall.endpoint()["model"],
		},
		ModelCall.at_once(ModelCall.key(), TRIES))


# How many of a channel's answers came back with nothing in them. A recorded
# silence would replay as a character that never chooses anything.
func _empty_in(channel: ModelChannel, which: String) -> int:
	var empty := 0
	for at in channel.exchanges.size():
		var exchange: Dictionary = channel.exchanges[at]
		if String(exchange["reply"]).strip_edges() == "":
			empty += 1
			printerr("    empty answer to question %d of %s (%s): %s" % [
				at + 1, which, exchange["prompt"], exchange["note"],
			])
	return empty


# The first question the shipped run puts, in full, printed rather than asked.
# The run is played with the channel a shipped run uses, so this is the prompt
# itself and not a reconstruction of one.
func _first_question() -> PackedStringArray:
	var channel := ModelChannel.for_run(ModelRecording.exchange())
	ScriptedAgent.played_with(channel)
	var asked := channel.questions()
	if asked.is_empty():
		return PackedStringArray(["the run asked nothing"])
	var written := PackedStringArray()
	written.append("the first question the run puts, %d characters, digest %s:" % [
		String(asked[0]["prompt"]).length(), asked[0]["digest"],
	])
	written.append("")
	written.append_array(String(asked[0]["prompt"]).split("\n"))
	return written


# Rewrite the recording, keeping everything above the marker and replacing
# everything below it.
func _write(rows: Dictionary) -> String:
	var file := FileAccess.open(RECORDING, FileAccess.READ)
	if file == null:
		return ""
	var kept := PackedStringArray()
	for line in file.get_as_text().split("\n"):
		if line.begins_with("## Which model was asked"):
			break
		kept.append(line)

	var where := ModelCall.endpoint()
	kept.append("## Which model was asked, where, and when. Rewritten by the recorder.")
	kept.append('const MODEL := "%s"' % where["model"])
	kept.append('const ENDPOINT := "%s"' % where["url"])
	kept.append('const RECORDED_ON := "%s"' % rows["on"])
	kept.append("")
	kept.append("## Whether these replies came from a model running on the machine that recorded")
	kept.append("## them rather than from the endpoint the shipped recording is made against.")
	kept.append("##")
	kept.append("## A local model answers this run's questions in a fifth of a second and for")
	kept.append("## nothing, which makes it the right thing to iterate against and the wrong")
	kept.append("## thing to ship: the replies checked in here are quoted across the reports as")
	kept.append("## what a capable model chose. So a recording made against one says so in its")
	kept.append("## own provenance line -- printed at the head of every run that replays it --")
	kept.append("## and no report can quote it as the other thing.")
	kept.append("const LOCAL := %s" % ("true" if where["local"] else "false"))
	kept.append("")
	kept.append("## When the difficulty-class table was recorded, which is its own date because")
	kept.append("## it is the one table that can be recorded on its own -- `./run_record.sh")
	kept.append("## --live --checks` puts only its questions and writes the other three back")
	kept.append("## unchanged. A run that adds a fourth table is not a reason to spend a whole")
	kept.append("## pass on the other three and to move every number quoted off their")
	kept.append("## transcripts.")
	kept.append('const CHECKS_RECORDED_ON := "%s"' % rows["checks_on"])
	kept.append("")
	kept.append("## When the orchestrator table was recorded, which is its own date for the same")
	kept.append("## reason the difficulty-class one is: `./run_record.sh --live --world` puts only")
	kept.append("## its questions and writes the other four back unchanged.")
	kept.append('const WORLD_RECORDED_ON := "%s"' % rows["world_on"])
	kept.append("")
	kept.append("## The exchange. Rewritten by the recorder; see the note above.")
	kept.append("const ROWS := [")
	kept.append_array(_rows_of(rows["main"]))
	kept.append("]")
	kept.append("")
	kept.append("## The goal comparison's four questions, recorded in the same pass.")
	kept.append("const GOAL_ROWS := [")
	kept.append_array(_rows_of(rows["goals"]))
	kept.append("]")
	kept.append("")
	kept.append("## The lesson comparison's four questions, recorded in the same pass.")
	kept.append("const LESSON_ROWS := [")
	kept.append_array(_rows_of(rows["lessons"]))
	kept.append("]")
	kept.append("")
	kept.append("## The difficulty-class run's questions, on their own date above.")
	kept.append("const CHECK_ROWS := [")
	kept.append_array(_rows_of(rows["checks"]))
	kept.append("]")
	kept.append("")
	kept.append("## The orchestrator run's questions, on their own date above.")
	kept.append("const WORLD_ROWS := [")
	kept.append_array(_rows_of(rows["world"]))
	kept.append("]")
	kept.append("")
	kept.append("")
	kept.append("## The whole recording as one thing to hand to a channel: the replies, a line")
	kept.append("## saying where they came from, and which model said them.")
	kept.append("##")
	kept.append("## One bundle rather than three arguments, because `sim/model_channel.gd` may not")
	kept.append("## name this file and so has to be given everything it needs about it in one go.")
	kept.append("static func exchange() -> Dictionary:")
	kept.append('\treturn {"rows": ROWS, "from": provenance(), "model": MODEL}')
	kept.append("")
	kept.append("")
	kept.append("## The lesson comparison's own exchange, in the same shape.")
	kept.append("static func lesson_exchange() -> Dictionary:")
	kept.append('\treturn {"rows": LESSON_ROWS, "from": provenance(), "model": MODEL}')
	kept.append("")
	kept.append("")
	kept.append("## The goal comparison's own exchange, in the same shape.")
	kept.append("static func goal_exchange() -> Dictionary:")
	kept.append('\treturn {"rows": GOAL_ROWS, "from": provenance(), "model": MODEL}')
	kept.append("")
	kept.append("")
	kept.append("## The difficulty-class run's own exchange, in the same shape, and with its own")
	kept.append("## date on it.")
	kept.append("static func check_exchange() -> Dictionary:")
	kept.append('\treturn {"rows": CHECK_ROWS, "from": check_provenance(), "model": MODEL}')
	kept.append("")
	kept.append("")
	kept.append("## The orchestrator run's own exchange, in the same shape, and with its own date")
	kept.append("## on it.")
	kept.append("static func world_exchange() -> Dictionary:")
	kept.append('\treturn {"rows": WORLD_ROWS, "from": world_provenance(), "model": MODEL}')
	kept.append("")
	kept.append("")
	kept.append("## How a provenance line names who answered: the model, and whether it was one")
	kept.append("## running on the machine that recorded it. See `LOCAL` above.")
	kept.append("static func said_by() -> String:")
	kept.append('\treturn "a local model, %s" % MODEL if LOCAL else MODEL')
	kept.append("")
	kept.append("")
	kept.append("## Where the orchestrator replies came from.")
	kept.append("static func world_provenance() -> String:")
	kept.append('\treturn "recorded %s from %s at %s, %d replies" % [')
	kept.append("\t\tWORLD_RECORDED_ON, said_by(), ENDPOINT, WORLD_ROWS.size(),")
	kept.append("\t]")
	kept.append("")
	kept.append("")
	kept.append("## Where the difficulty-class replies came from.")
	kept.append("static func check_provenance() -> String:")
	kept.append('\treturn "recorded %s from %s at %s, %d replies" % [')
	kept.append("\t\tCHECKS_RECORDED_ON, said_by(), ENDPOINT, CHECK_ROWS.size(),")
	kept.append("\t]")
	kept.append("")
	kept.append("")
	kept.append("## How many replies the recording holds.")
	kept.append("static func size() -> int:")
	kept.append("\treturn ROWS.size() + LESSON_ROWS.size() + GOAL_ROWS.size() \\")
	kept.append("\t\t+ CHECK_ROWS.size() + WORLD_ROWS.size()")
	kept.append("")
	kept.append("")
	kept.append("## One line saying where the replies came from, printed at the head of a run that")
	kept.append("## replays them.")
	kept.append("##")
	kept.append("## It counts the three tables it is the date of, and not the difficulty-class or")
	kept.append("## orchestrator tables, each of which has its own date and its own line.")
	kept.append("static func provenance() -> String:")
	kept.append('\treturn "recorded %s from %s at %s, %d replies" % [')
	kept.append("\t\tRECORDED_ON, said_by(), ENDPOINT,")
	kept.append("\t\tROWS.size() + LESSON_ROWS.size() + GOAL_ROWS.size(),")
	kept.append("\t]")

	var out := FileAccess.open(RECORDING, FileAccess.WRITE)
	if out == null:
		return ""
	var text := "\n".join(kept) + "\n"
	out.store_string(text)
	out.close()
	return text


# One table's rows, whether they came off a channel this pass or out of the
# recording as it already stands.
func _rows_of(exchanges: Array) -> PackedStringArray:
	var written := PackedStringArray()
	for exchange in exchanges:
		written.append('\t{"prompt": "%s", "reply": "%s", "ms": %d},' % [
			exchange["prompt"], _quoted(String(exchange["reply"])), int(exchange["ms"]),
		])
	return written


# One reply as it goes inside a GDScript string literal.
static func _quoted(reply: String) -> String:
	return reply.replace("\\", "\\\\").replace('"', '\\"') \
		.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "")


# What this pass is putting to the model, in one line for the head of the run.
static func _what_is_being_put(
	everything: bool, only_cast: bool, only_checks: bool, only_world: bool
) -> String:
	if everything:
		return "every question of all five runs, in one pass"
	var which := "the character runs' questions only -- the shipped run, the" \
		+ " lesson comparison and the goal comparison"
	if only_checks:
		which = "the difficulty-class run's questions only"
	elif only_world:
		which = "the orchestrator run's questions only"
	elif not only_cast:
		which = "nothing"
	return which + "; every other table is written back unchanged"
