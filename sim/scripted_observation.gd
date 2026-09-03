extends RefCounted
## What each of five characters can see, taken off the shipped scenario at two
## stated ticks, printed, and measured.
##
##     ./run_observation.sh
##
## This is the walkthrough for section 10's observation. It runs no new world and
## invents no new coordinate: it plays `ScriptedScenario` -- the same five
## characters, the same seed, the same market, trade and quarrel -- and watches
## it go past. At the two ticks that scenario already names for its rendered
## frames it stops and assembles one observation per character.
##
## Nothing here decides anything, and there is no language model anywhere in it:
## an observation is what a model will *be handed*, and this run exists to show
## that producing one needs no model at all.
##
## ## What it measures, and why those numbers
##
## The last section of the output is the point of the run. An observation is
## going to have to fit in a model's context, so its size is a fact worth
## knowing rather than guessing: the table gives, per observation, how many
## entries it holds and how many characters of text the readable packet comes
## to. Underneath it, the same observation's ground is re-rendered at four window
## widths, so what a wider view of the lattice costs is a number.
class_name ScriptedObservation

## The run this is taken off: the shipped scenario, seed and all.
const SEED := ScriptedScenario.SEED

## The three ticks observations are taken at.
##
## The last two are not new ticks: they are the two the scenario already names
## for its rendered frames, so this run looks at the world at exactly the moments
## a picture of it is taken -- the market, and the quarrel once it is on the
## board. The first is the tick the run opens on, and it is here because by the
## time the market frame comes round the stall has been emptied and a pile with
## nothing in it is not a place at all: the opening tick is the one where there
## is still an object in the world to be seen.
const AT_TICKS := [
	1, ScriptedScenario.MARKET_FRAME, ScriptedScenario.QUARREL_FRAME,
]

## The window widths the ground is re-rendered at for the measurement. The
## middle two are section 10's own suggestion; the first is smaller and the last
## is the whole board the observation was read from.
const WIDTHS := [5, 7, 9]


## Play the run, take the observations, and hand back the whole transcript.
static func walk(seed_value: int = SEED) -> PackedStringArray:
	var trail := ObservationTrail.new()
	var taken: Array[Dictionary] = []
	var watcher := func(scene: ActionScene) -> void:
		trail.note(scene)
		if not AT_TICKS.has(scene.tick):
			return
		for one in scene.actors:
			taken.append({
				"tick": scene.tick,
				"id": one.id,
				"seen": Observation.of(scene, one, trail),
			})
	ScriptedScenario.played_to(_last_tick(), seed_value, watcher)

	var written := PackedStringArray()
	written.append(
		"observation walkthrough seed=%d nearby=%.1f window=%dx%d cells of %.1f"
		% [
			seed_value, Observation.NEARBY, Observation.WINDOW,
			Observation.WINDOW, CombatBoard.CELL_SIZE,
		])
	written.append("  no language model, no prompt, no network call: this is the packet,")
	written.append("  assembled out of the world by sim/observation.gd alone.")
	written.append("")
	for row in taken:
		var seen: Observation = row["seen"]
		written.append("--- tick %d, #%d ---" % [row["tick"], row["id"]])
		written.append_array(seen.lines())
		written.append("")
	written.append_array(_measurements(taken))
	written.append_array(_determinism(seed_value, taken))
	return written


## Every observation the run takes, for a test that wants them rather than the
## transcript. Same call, same order.
static func taken_at(seed_value: int = SEED) -> Array[Dictionary]:
	var trail := ObservationTrail.new()
	var taken: Array[Dictionary] = []
	var watcher := func(scene: ActionScene) -> void:
		trail.note(scene)
		if not AT_TICKS.has(scene.tick):
			return
		for one in scene.actors:
			taken.append({
				"tick": scene.tick,
				"id": one.id,
				"seen": Observation.of(scene, one, trail),
			})
	ScriptedScenario.played_to(_last_tick(), seed_value, watcher)
	return taken


# --- The measurement ------------------------------------------------------


static func _measurements(taken: Array[Dictionary]) -> PackedStringArray:
	var written := PackedStringArray()
	written.append("how big one observation is")
	written.append("  tick  who  entities objects cells recent entries characters")
	var lengths := PackedInt32Array()
	var counts := PackedInt32Array()
	for row in taken:
		var seen: Observation = row["seen"]
		lengths.append(seen.text_length())
		counts.append(seen.entry_count())
		written.append("  %4d  #%-3d %8d %7d %5d %6d %7d %10d" % [
			row["tick"], row["id"], seen.entities.size(), seen.objects.size(),
			Observation.WINDOW * Observation.WINDOW, seen.recent.size(),
			seen.entry_count(), seen.text_length(),
		])
	written.append("  %d observations: %d to %d characters, %d in the middle" % [
		lengths.size(), _least(lengths), _most(lengths), _middle(lengths),
	])
	written.append("  entries: %d to %d, %d in the middle" % [
		_least(counts), _most(counts), _middle(counts),
	])
	written.append("")

	# What a wider view of the same lattice costs. The board every observation
	# was read from reaches `NEARBY` in each direction, so its own width is the
	# last row: printing all of it is what a window of the whole board costs.
	written.append("what a wider window of the same lattice costs")
	written.append("  cells across  cells  ground lines  ground characters")
	var sample: Observation = taken[0]["seen"]
	var widths := Array(WIDTHS).duplicate()
	widths.append(sample.board.cells_across)
	for width in widths:
		var ground := sample.ground_lines(int(width))
		written.append("  %12d %6d %13d %18d" % [
			int(width), int(width) * int(width), ground.size(),
			"\n".join(ground).length(),
		])
	written.append("  the last row is the whole board the observation was read from:")
	written.append("  it reaches %.1f world units so a line of sight to anything" % (
		Observation.NEARBY))
	written.append("  reported can be traced across it, and it is not printed.")
	return written


static func _determinism(seed_value: int, taken: Array[Dictionary]) -> PackedStringArray:
	var again := taken_at(seed_value)
	var same := again.size() == taken.size()
	if same:
		for at in taken.size():
			var first: Observation = taken[at]["seen"]
			var second: Observation = again[at]["seen"]
			if first.digest() != second.digest():
				same = false
				break
	var written := PackedStringArray()
	written.append("")
	written.append("the same run played twice gives %s observations (%d of them)" % [
		"the same" if same else "DIFFERENT", taken.size(),
	])
	written.append("fingerprint %s" % _digest_of(taken))
	return written


## A short, stable fingerprint of every observation the run took. What two
## processes on one seed are compared on.
static func digest(seed_value: int = SEED) -> String:
	return _digest_of(taken_at(seed_value))


static func _digest_of(taken: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for row in taken:
		var seen: Observation = row["seen"]
		parts.append("%d/%d/%s" % [row["tick"], row["id"], seen.digest()])
	return "|".join(parts).sha256_text().substr(0, 16)


# --- The furniture --------------------------------------------------------


static func _last_tick() -> int:
	var latest := 0
	for at in AT_TICKS:
		latest = maxi(latest, int(at))
	return latest


static func _least(values: PackedInt32Array) -> int:
	var found := 0
	for at in values.size():
		found = values[at] if at == 0 else mini(found, values[at])
	return found


static func _most(values: PackedInt32Array) -> int:
	var found := 0
	for value in values:
		found = maxi(found, value)
	return found


# The middle value, which is what "a typical observation" means here: half are
# smaller and half are bigger. An average would be pulled about by the one
# character standing alone in a field with nothing to report.
static func _middle(values: PackedInt32Array) -> int:
	if values.is_empty():
		return 0
	var sorted := Array(values)
	sorted.sort()
	return int(sorted[sorted.size() / 2])
