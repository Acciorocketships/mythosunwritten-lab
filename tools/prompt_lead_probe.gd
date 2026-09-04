extends SceneTree
## Put the orchestrator's own questions to the shipping model twice: once as the
## prompt stands, and once with its naming line lifted to the top -- the shape
## `M-a-leading-instruction-paragraph-trips-the-providers-filter` records as
## refused by Anthropic's filter. That constraint was measured against a provider
## the project no longer calls, so this measures it again against the one it
## does.
##
##   OPENROUTER_API_KEY=sk-... ./tools/prompt_lead_probe.sh [--repeats N]
##                                                          [--only <digest>]
##
## `--only` narrows the pass to the one question whose digest is named, both
## arms still, which is how a single odd answer is put again on a sample of its
## own rather than argued about.
##
## It changes no file under `sim/`. The two arms are built here, out of the
## prompts the shipped run actually puts, so the shipped prompt is read and never
## written.
##
## ## The two arms, and why they are the same words
##
## `sim/orchestrator_prompt.gd` writes each of its two prompts with one line
## naming what the call is for -- `WATCHES` for the world question, `PEOPLES` for
## the persona one -- sitting just above the answer instruction, with a plain
## title at the top. The leading arm removes that line from where it sits and
## puts it back as the first line of the message, above the title, which is the
## shape the note says was refused. Nothing else moves: the probe asserts the two
## arms are the same multiset of lines before it puts either of them.
##
## A refusal is an answer with nothing readable in it. `ModelCall.fetch` never
## raises: a provider that declines, or answers with an empty content, comes back
## as an empty reply and a sentence saying which, and that sentence is printed
## verbatim beside the count.

const REPEATS := 3


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var repeats := _repeats_from(args)
	var only := _only_from(args)
	var credentials := ModelCall.credentials()
	# Where this probe's calls would go, which is the paid endpoint unless the
	# environment names a local one. See the note on the two endpoints at the head
	# of net/model_call.gd.
	var where := ModelCall.endpoint()
	print("prompt lead probe: %s" % (where["url"] if where["ok"] else "nowhere"))
	print("  model      %s%s" % [
		where["model"], " (running locally)" if where["local"] else "",
	])
	print("  reasoning  %s" % JSON.stringify(where["reasoning"]))
	print("  credential %s" % credentials["why"])
	print("  repeats    %d per question per arm" % repeats)
	if only != "":
		print("  only       the question whose digest is %s" % only)

	var channel := ModelChannel.for_run(ModelRecording.world_exchange())
	ScriptedWorld.play(channel)
	var asked := channel.questions()
	var arms := []
	for one in asked:
		if only != "" and String(one["digest"]) != only:
			continue
		var prompt := String(one["prompt"])
		var naming := _naming_in(prompt)
		if naming == "":
			printerr("  a question carried neither naming line: %s" % one["digest"])
			quit(1)
			return
		var lead := _with_the_naming_line_leading(prompt, naming)
		if not _same_words(prompt, lead):
			printerr("  the two arms are not the same words: %s" % one["digest"])
			quit(1)
			return
		arms.append({
			"which": "world" if naming == OrchestratorPrompt.WATCHES else "persona",
			"digest": String(one["digest"]),
			"as_it_stands": prompt, "leading": lead,
		})
	print("  questions  %d, of which %d the world question and %d the persona one" % [
		arms.size(), _counted(arms, "world"), _counted(arms, "persona"),
	])
	print("")
	print("%-4s %-18s %-8s %10s" % ["#", "question", "which", "characters"])
	for at in arms.size():
		print("%-4d %-18s %-8s %10d" % [
			at + 1, arms[at]["digest"], arms[at]["which"],
			String(arms[at]["as_it_stands"]).length(),
		])
	print("")
	print("The two arms, on the first world question, first four lines each:")
	for arm in arms:
		if arm["which"] != "world":
			continue
		_show_head("as it stands", String(arm["as_it_stands"]))
		_show_head("naming line leading", String(arm["leading"]))
		break
	print("")

	if not credentials["ok"]:
		printerr("  did nothing: %s" % credentials["why"])
		quit(1)
		return

	var tally := {}
	for arm_name in ["as_it_stands", "leading"]:
		tally[arm_name] = {"put": 0, "refused": 0, "why": []}
	print("%-4s %-18s %-8s %-20s %6s  %s" % [
		"#", "question", "which", "arm", "ms", "what came back",
	])
	var put := 0
	for round_at in repeats:
		for arm in arms:
			for arm_name in ["as_it_stands", "leading"]:
				put += 1
				var got := ModelCall.fetch(ModelCall.key(), String(arm[arm_name]))
				var reply := String(got["reply"]).strip_edges()
				var counts: Dictionary = tally[arm_name]
				counts["put"] = int(counts["put"]) + 1
				if reply == "":
					counts["refused"] = int(counts["refused"]) + 1
					(counts["why"] as Array).append(String(got["why"]))
				print("%-4d %-18s %-8s %-20s %6d  %s" % [
					put, arm["digest"], arm["which"],
					"as it stands" if arm_name == "as_it_stands" else "leading",
					int(got["ms"]),
					_shown(reply, String(got["why"])),
				])
	print("")
	print("Counted, over %d question%s put %d time%s each:" % [
		arms.size(), "" if arms.size() == 1 else "s",
		repeats, "" if repeats == 1 else "s",
	])
	print("%-22s %6s %9s" % ["arm", "put", "refused"])
	for arm_name in ["as_it_stands", "leading"]:
		var counts: Dictionary = tally[arm_name]
		print("%-22s %6d %9d" % [
			"as it stands" if arm_name == "as_it_stands" else "naming line leading",
			int(counts["put"]), int(counts["refused"]),
		])
	for arm_name in ["as_it_stands", "leading"]:
		var counts: Dictionary = tally[arm_name]
		for why in counts["why"]:
			print("  empty in the %s arm: %s" % [
				"as it stands" if arm_name == "as_it_stands" else "leading", why,
			])
	quit(0)


# Which of the two naming lines a prompt carries, or "" if it carries neither.
func _naming_in(prompt: String) -> String:
	for naming in [OrchestratorPrompt.WATCHES, OrchestratorPrompt.PEOPLES]:
		for line in prompt.split("\n"):
			if line == naming:
				return naming
	return ""


# The same prompt with its naming line taken out of where it sits and put back as
# the first line of the message. The blank line that followed it goes with it, so
# that what is left has no doubled blank in it, and the message opens with the
# naming line and then the title it used to open with.
func _with_the_naming_line_leading(prompt: String, naming: String) -> String:
	var lines := prompt.split("\n")
	var kept := PackedStringArray([naming, ""])
	var at := 0
	while at < lines.size():
		if lines[at] == naming:
			at += 1
			if at < lines.size() and lines[at] == "":
				at += 1
			continue
		kept.append(lines[at])
		at += 1
	return "\n".join(kept)


# Whether two prompts are the same lines in a different order, which is what
# makes the two arms one manipulation and not two.
func _same_words(one: String, other: String) -> bool:
	var a := Array(one.split("\n"))
	var b := Array(other.split("\n"))
	a.sort()
	b.sort()
	return a == b


func _show_head(what: String, prompt: String) -> void:
	print("  %s:" % what)
	var lines := prompt.split("\n")
	for at in mini(4, lines.size()):
		print("    | %s" % lines[at])


func _shown(reply: String, why: String) -> String:
	if reply == "":
		return "REFUSED OR EMPTY -- %s" % why
	var one_line := reply.replace("\n", " / ")
	return one_line if one_line.length() <= 76 else one_line.substr(0, 73) + "..."


func _counted(arms: Array, which: String) -> int:
	var found := 0
	for arm in arms:
		if arm["which"] == which:
			found += 1
	return found


func _only_from(args: PackedStringArray) -> String:
	for at in args.size():
		if args[at] == "--only" and at + 1 < args.size():
			return args[at + 1]
	return ""


func _repeats_from(args: PackedStringArray) -> int:
	for at in args.size():
		if args[at] == "--repeats" and at + 1 < args.size() \
				and args[at + 1].is_valid_int():
			return maxi(1, args[at + 1].to_int())
	return REPEATS
