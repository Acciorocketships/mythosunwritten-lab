# Reviewer's evidence for W-llm-review

An independent check of the two claims the language-model layer rests on, made
against the source and against runs. Nothing here is fixed; every line is
reproducible from a clean checkout with the commands quoted.

Terms used below, restated because this project coined them:

* **the layer** — the three shapes of model call in `sim/`: the *character
  agent* (`ModelMind`, one per character, polled by the control loop), the
  *difficulty-class agent* (`CheckDesk`, one-off, raised by a hook), and the
  *orchestrator* (`Orchestrator`, polled over the whole world every 30 ticks).
* **the engine** — `ActionEngine` and the files it calls: the only thing that
  decides whether a chosen action is allowed and what it does.
* **prompt families** — the three files that write text for a model:
  `sim/model_prompt.gd`, `sim/check_prompt.gd`, `sim/orchestrator_prompt.gd`.
* **the rule-word scan** — `ModelPrompt.RULE_WORDS`, a list of words whose
  presence in a prompt would mean a rule had got into it, compiled into a regex
  by three tests and run over a real character prompt.
* **replay / live / record** — the three kinds of `ModelChannel`. Replay answers
  out of the table in `net/model_recording.gd`; live calls the provider on a
  worker thread; record does both and is the recorder's only.

Suites run for this review, all green (`./run_agent_suite.sh` and friends):

| suite | checks |
| --- | --- |
| agent | 1157 |
| orchestrator | 282 |
| observation | 218 |
| goals | 130 |
| checks | 118 |
| memory | 93 |

---

## 1. Every prompt read for rules about distance, reach, cost, damage, possibility

### 1a. The scan itself covers one of the three prompt families

```
$ grep -rn "RULE_WORDS" tests/ sim/
tests/test_agent.gd:818:  finder.compile("(?i)\\b(%s)\\b" % ModelPrompt.RULE_WORDS)
tests/test_goals.gd:552:  finder.compile("(?i)\\b(%s)\\b" % ModelPrompt.RULE_WORDS)
tests/test_memory.gd:615:  finder.compile("(?i)\\b(%s)\\b" % ModelPrompt.RULE_WORDS)
sim/model_prompt.gd:103:const RULE_WORDS := (
```

All three call sites scan a **character** prompt. `tests/test_checks.gd` and
`tests/test_orchestrator.gd` scan their prompts for *story* words and for the
word `roll`, never for rule words (`tests/test_checks.gd:259`,
`tests/test_orchestrator.gd:519`).

### 1b. What the character prompt actually carries

The prompt printed by `./run_agent.sh` (`reports/agent-evidence.txt:853-925`,
3111 characters, digest `16dcbdfe447a1187`) has **no hit** for the layer's own
rule-word list. It does carry four lines that state distance or affordance in
words the list does not contain:

```
line 31:  entities   2 within 40.0
line 34:  objects    1 within 40.0
line 36:  ground     7x7 cells of 3.0, ... each mark is followed by how far that cell stands above you
line 37:  legend     @ where you stand; ~ a hole with nothing to stand on; x a building;
                     # a face of ground too tall to climb; ! the edge of a drop;
                     . ground to walk on; ? not read
```

* `40.0` is `ActionEngine.SIGHT`, printed by `sim/observation.gd:543` and
  `sim/observation.gd:546`.
* the legend words are `Observation.MEANS`, `sim/observation.gd:137-146`. Three
  of the seven are phrased as affordances — "too tall to climb", "ground to walk
  on", "nothing to stand on" — against that constant's own docstring, which says
  it "says what a mark *is*, never what may be done about it".

The engine still answers; nothing here lets the model resolve anything.

### 1c. What the difficulty-class prompts carry

From `./run_check.sh`, question 2 as actually sent (852 characters, digest
`b4dc9bc7079ce35a`):

```
What is within 12 paces of it:
  ...
  move   target=#7 to=(12.5, -4.0) -- a thing is shoved, at most 4.0 units, onto ground that carries it
```

| what | where |
| --- | --- |
| `IN_REACH := 12.0`, printed as "within 12 paces" | `sim/check_prompt.gd:37`, `sim/check_prompt.gd:89` |
| "a thing is shoved, at most 4.0 units, onto ground that carries it" | `sim/check_effects.gd:51` (`NUDGE`) |
| "Judge how likely you think that is to succeed" | `sim/check_prompt.gd:56` |
| "a whole number from 1 to 30, higher being harder" | `sim/check_prompt.gd:58-60` |

The last two are section 7's own instruction and are not a defect; the first two
are rules about reach and distance stated in a prompt. Both are also enforced by
the engine (`sim/check_effects.gd:199-200` refuses a shove beyond `NUDGE`), so
the model is not resolving — it is being told a limit as well as refused by one.

### 1d. What the orchestrator prompts carry

From `./run_world.sh`, the watching prompt as actually sent:

```
The ground here is 9 rings out from the world origin, which makes it difficulty 10:
anyone rolled for it is that level, and their ability scores are drawn from bands
set by their role and lifted by the same distance.
...
  place  kind=one of chest/crate/door/stone at=(12.5, -4.0) -- a new thing stands there, on ground that carries it
  move   target=#7 to=(12.5, -4.0) -- a thing is shoved, at most 4.0 units, onto ground that carries it
...
A thing may be placed, and a character spawned, within 40 of somebody who is already there.
```

| what | where |
| --- | --- |
| section 5's distance→level gradient, stated in full | `sim/orchestrator_prompt.gd:161-171` |
| `WITHIN := 40.0`, printed as "within 40 of somebody" | `sim/world_effects.gd:55`, `sim/orchestrator_prompt.gd:97-99` |
| "on ground that carries it" | `sim/world_effects.gd:77` |
| the shove limit, borrowed | `sim/check_effects.gd:51` |

All are enforced independently: `sim/world_effects.gd:397-400` refuses a
placement past `WITHIN`.

Static form of the same scan, reproducible in one line:

```
$ grep -nEi '"[^"]*\b(distance|reach|cost|damage|within|carries it|paces|units|succeed|harder)\b[^"]*"' \
    sim/model_prompt.gd sim/check_prompt.gd sim/orchestrator_prompt.gd \
    sim/check_effects.gd sim/world_effects.gd
sim/check_prompt.gd:56,60,89
sim/orchestrator_prompt.gd:97,169
sim/check_effects.gd:51
sim/world_effects.gd:77
(sim/model_prompt.gd: only the RULE_WORDS constant itself)
```

---

## 2. The path a model-driven character takes, against a human-driven one's

**The same up to the seam.** `Character.decide` is one `Callable` of the shape
`func(scene, actor) -> Action`; `DecisionSource.drive` reads it off the sheet
and hands whatever comes back to `ActionEngine.resolve` with no branch on what
sort of function it was (`sim/decision_source.gd:192-205`). `ControlLoop` has no
branch either, and `tests/test_actions.gd:484` scans the control path for lines
that ask who is calling. A model's refused choice comes back with the same
sentence any caller gets.

**Where the paths differ.** Two per-character stores that the character sheet
declares for everybody are maintained only inside the model layer:

```
$ grep -rn "GoalCheck.settle\|\.witness(" --include=*.gd sim/
sim/model_mind.gd:192:    remembered.witness(_seen)
sim/model_mind.gd:212:  for row in GoalCheck.settle(goals_of(actor), scene, actor):
sim/scripted_goal.gd:132,140   (a demonstration run, not a driver)
sim/scripted_lesson.gd:132,183 (a demonstration run, not a driver)
```

Measured on the shipped run (section [2] of the probe below): the
human-driven character's memory holds **0** events after 160 ticks and 10
actions; the five model-driven characters hold 9–18.

Measured on a goal (section [3]): a goal the world answers `true` to at tick 0 —
"carry at least 1 coin", on a character carrying 30 — is put on the human-driven
character and is **still open after 160 ticks**. Calling `GoalCheck.settle` by
hand immediately afterwards closes it with "30 money in the pack". Nothing in
the run ever asked the world on that character's behalf, because the only place
that asks is `ModelMind._settle`.

The layer's own symmetry test (`tests/test_agent.gd:700-717`) builds an
observation and a prompt *for* the human-driven character and checks both offer
the same twelve actions. That is true and worth having, but it is an as-if
construction: in the run itself, `Observation.of` is never called for that
character.

---

## 3. "The simulation never blocks on a model", checked against a run

The layer's own test (`tests/test_agent.gd:421`) is thorough but exercises only
a replay channel, whose latency is the constant `ModelChannel.THINKS_FOR = 3`
ticks. It does not exercise a channel that never answers. (The orchestrator
does have that test — `tests/test_orchestrator.gd:589`.)

So the probe below builds a **live** channel whose transport hands back a flight
returning `{}` for ever — the shape of a provider that has hung — and plays the
shipped six-character run through it:

```
[1] a model that never answers
  asked for 160 ticks, the world reached tick 160
    Wren   carried out 10 actions          <- driven by a person's written-down choices
    Rook   carried out 0 actions           <- the five model-driven characters
    ... (Bram, Sable, Odo, Pell: 0 each)
  10 actions in all, and 5 questions outstanding at the end
    Rook   opened=1 held=0 polled=159 answered=0 waiting=yes
    ... (same for the other four)
```

The world reached every one of its 160 ticks; the human-driven character carried
out all ten of its actions; each stalled mind opened exactly one question and
polled 159 times without re-asking. The characters wait in-world; the world does
not wait for them.

Wall-clock, for scale — 160 ticks, six characters, 94 recorded replies:

```
$ time ./run_agent.sh    real 0m23.2s
$ time ./run_check.sh    real 0m1.4s
$ time ./run_world.sh    real 0m1.0s
```

---

## 4. Can the recorded-replay path hide a live dependency, a credential, or a call?

**No credential is reachable from a test or a shipped run.** `OPENROUTER_API_KEY`
is read in exactly one function, `ModelCall.key()` (`net/model_call.gd`), called
only from the `_transport` helpers in `bin/agent_main.gd`, `bin/check_main.gd`,
`bin/world_main.gd`, `bin/goal_main.gd`, `bin/lesson_main.gd` and
`bin/record_main.gd`, each behind an explicit `--live`. Every test builds its
channel with `ModelChannel.for_run(exchange)` and passes no transport, and
`for_run` returns a replay channel unconditionally when the transport is invalid
(`sim/model_channel.gd:127-133`) — it consults nothing.

Checked rather than read:

```
$ ./run_agent.sh > a.txt
$ OPENROUTER_API_KEY=sk-bogus-not-a-real-key ./run_agent.sh > b.txt
$ cmp a.txt b.txt   # identical
```

The run is byte-identical with a key in the environment and without one.

**Two ways the replay path can be wrong without anything failing.**

1. *Drift is a note, not a failure.* `ModelChannel._row_for`
   (`sim/model_channel.gd:308-316`) matches a recorded row by prompt digest
   first and falls back to the n-th row for the n-th question. On a mismatch it
   writes a sentence into the transcript ("this reply was recorded for another
   question") and answers anyway. No test asserts that sentence is absent, so a
   change to the observation layer would leave every LLM suite green while the
   run replayed answers recorded for different questions. The shipped
   transcripts carry no such note today (`grep -n "recorded for another
   question" reports/*.txt` → nothing), so the recording is currently in step.

2. *A live run can silently become a partly-recorded one, by position.* When a
   live call comes back empty, `_fall_back_to_the_recording`
   (`sim/model_channel.gd:373-383`) takes row `ticket - 1` — position only, with
   no digest check and no mismatch note, unlike the replay path directly above
   it. The note it does write says only "the recorded reply was replayed
   instead". This affects `--live` runs only; the shipped run never reaches it.

---

## The probe

Written to `bin/critic_probe.gd`, run, and deleted. Recreate it verbatim and run
`godot --headless --path . --script res://bin/critic_probe.gd`.

```gdscript
extends SceneTree

func _initialize() -> void:
	_never_answers()
	_two_paths()
	_a_goal_on_the_person()
	quit(0)


func _never_answers() -> void:
	var transport := func(_prompt: String) -> Callable:
		return func() -> Dictionary:
			return {}
	var channel := ModelChannel.calling(
		{"rows": [], "from": "nothing", "model": "a model that never answers"},
		transport)
	var played := ScriptedAgent.played_with(channel, ScriptedAgent.TICKS)
	var scene: ActionScene = played["scene"]
	var cast: ModelCast = played["cast"]
	print("[1] a model that never answers")
	print("  asked for %d ticks, the world reached tick %d" % [
		ScriptedAgent.TICKS, scene.tick,
	])
	var total := 0
	for one in scene.actors:
		var did := scene.actions_of(one.id)
		total += did
		print("    %-6s carried out %d action%s" % [
			ActionScene.name_of(one), did, "" if did == 1 else "s",
		])
	print("  %d actions in all, and %d question%s outstanding at the end" % [
		total, channel.asked(), "" if channel.asked() == 1 else "s",
	])
	for who in cast.order:
		var mind := cast.mind_of(who)
		print("    %-6s opened=%d held=%d polled=%d answered=%d waiting=%s" % [
			who, mind.opened, mind.held, mind.polled, mind.answered(),
			"yes" if mind.is_waiting() else "no",
		])


func _two_paths() -> void:
	var played := ScriptedAgent.played_with(
		ModelChannel.for_run(ModelRecording.exchange()))
	var scene: ActionScene = played["scene"]
	print("")
	print("[2] the shipped replayed run: what each character's own sheet holds")
	for one in scene.actors:
		if one.piece == null or not (one.piece is Commander):
			continue
		var sheet: Character = (one.piece as Commander).sheet
		if sheet == null:
			continue
		var named := sheet.character_name
		var events := 0 if sheet.memory == null else sheet.memory.events.size()
		var lessons := 0 if sheet.memory == null else sheet.memory.lesson_lines().size()
		var goals := 0 if sheet.goals == null else sheet.goals.size()
		var closed := 0 if sheet.goals == null else sheet.goals.done().size()
		print("    %-6s driven-by=%-6s remembered=%-3d lessons=%d goals=%d closed=%d actions=%d" % [
			named, "person" if named == ScriptedAgent.PERSON else "model",
			events, lessons, goals, closed, scene.actions_of(one.id),
		])


func _a_goal_on_the_person() -> void:
	var scene := ScriptedAgent.stage(ScriptedAgent.SEED)
	var trail := ObservationTrail.new()
	trail.note(scene)
	var loop := ControlLoop.on(scene, ScriptedAgent.LOOP_SEED)
	var cast := ScriptedAgent.drive(scene, ModelChannel.for_run(
		ModelRecording.exchange()), trail)
	var person: Combatant = null
	for one in scene.actors:
		if ActionScene.name_of(one) == ScriptedAgent.PERSON:
			person = one
	var sheet: Character = (person.piece as Commander).sheet
	sheet.goals.add(Goal.of(Goal.MONEY, {"amount": 1}, "", Goal.SHORT, 0))
	for _step in ScriptedAgent.TICKS:
		loop.step()
		trail.note(scene)
	print("")
	print("[3] one goal, on the character a person drives")
	print("    the goal: carry at least 1 coin, which was already true at tick 0")
	var goal := sheet.goals.goal_of(1)
	print("    after %d ticks: closed=%s, by=%s" % [
		scene.tick, goal.closed, "-" if goal.closed_by == "" else goal.closed_by,
	])
	var would := GoalCheck.settle(sheet.goals, scene, person)
	print("    asking the world by hand afterwards closes %d of them: %s" % [
		would.size(), "none" if would.is_empty() else String(would[0]["how"]),
	])
	print("    (cast is %d model minds; nothing in the run ever asked on this"
		% cast.order.size() + " character's behalf)")
```
