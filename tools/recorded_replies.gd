extends SceneTree
## How much of the shipped model run the checked-in recording still answers.
##
## A recorded reply is keyed to the sha256 of the prompt that asked it
## (`net/model_recording.gd`), so a recording stops answering the moment the run
## puts a different question. This counts that, for the three tables the
## character runs read: how many questions the run puts, how many of them a row
## was recorded *for*, how many fell back to being answered by position, and how
## many recorded replies were never claimed.
##
## Run it with:  ./tools/recorded_replies.sh
##
## It replays; it calls nothing and needs no key.

func _initialize() -> void:
	var total := 0
	var matched := 0
	for run in [
		{"name": "shipped run", "rows": ModelRecording.ROWS,
			"play": func(channel: ModelChannel) -> void:
				ScriptedAgent.played_with(channel)},
		{"name": "lesson comparison", "rows": ModelRecording.LESSON_ROWS,
			"play": func(channel: ModelChannel) -> void:
				ScriptedLesson.play(channel)},
		{"name": "goal comparison", "rows": ModelRecording.GOAL_ROWS,
			"play": func(channel: ModelChannel) -> void:
				ScriptedGoal.play(channel)},
		{"name": "bargain run", "rows": ModelRecording.BARGAIN_ROWS,
			"play": func(channel: ModelChannel) -> void:
				TestBargain.play(channel)},
	]:
		var rows: Array = run["rows"]
		var channel := ModelChannel.replaying(
			{"rows": rows, "from": ModelRecording.provenance(),
				"model": ModelRecording.MODEL},
			"counting what the recording still answers")
		(run["play"] as Callable).call(channel)
		var asked := channel.questions()
		var recorded_for := 0
		var by_position := 0
		var unanswered := 0
		var claimed := {}
		for asking in asked:
			var note := String(asking["note"])
			if note == "":
				recorded_for += 1
			elif note.begins_with("this reply was recorded for another"):
				by_position += 1
			else:
				unanswered += 1
			if asking.has("row"):
				claimed[String((asking["row"] as Dictionary).get("prompt", ""))] = true
		var never := 0
		for row in rows:
			if not claimed.has(String((row as Dictionary).get("prompt", ""))):
				never += 1
		print("%-18s %3d rows, %3d questions, %3d recorded for them, %3d by position, %3d unanswered, %3d rows never claimed" % [
			run["name"], rows.size(), asked.size(), recorded_for, by_position,
			unanswered, never,
		])
		total += asked.size()
		matched += recorded_for
	print("%-18s %3d questions, %3d with a reply recorded for them" % [
		"all four", total, matched,
	])
	quit(0)
