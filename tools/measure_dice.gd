extends SceneTree
## Measure what the die settled in the items phase actually costs.
##
## Run it with:  ./tools/measure_dice.sh
##
## Nothing here is asserted; everything is counted and printed. The suite checks
## that the rules hold, this says how much they are worth. Five sections:
##
##   1. the die itself -- its band, its shape, and whether it is centred;
##   2. what it costs on average, blow by blow, against the deterministic model;
##   3. the positional ladder, rung by rung, at every roll;
##   4. **the same plan played many times** -- one scripted three-commander match
##      over 400 fight seeds, and one deliberately planned two-move combination
##      over 20000, which is the measurement the task asked for;
##   5. what the two options that were *not* chosen would have cost the same
##      plan, which is arithmetic rather than simulation and is marked as such.

## How many fights each distribution is measured over.
const SWING_TRIALS := 200000
const PLAN_TRIALS := 20000
const MATCH_SEEDS := 400

## The level both sides of the planned combination are at.
const LEVEL := 8

## A flat board, so that nothing but the die and the facing is in play.
const FLAT := [
	".............",
	".............",
	".............",
	".............",
	".............",
	".............",
	".............",
]

const MIDDLE := Vector2i(6, 3)


func _initialize() -> void:
	_line("dice: what the roll model costs, measured")
	_line("=" .repeat(70))
	_line("")
	_the_die()
	_what_it_costs_on_average()
	_the_ladder()
	_the_same_plan_many_times()
	_what_the_other_two_options_would_have_cost()
	quit(0)


# --- 1. the die -----------------------------------------------------------


func _the_die() -> void:
	_head("1. the die")
	_line("  SWING=%d  two dice of %d faces each, summed" % [
		Damage.SWING, Damage.SWING_FACES,
	])
	_line("  swing band [%d, %d] hundredths, centred on %d" % [
		Damage.SWING_LOW, Damage.SWING_HIGH, Damage.NONE,
	])
	_line("")

	var setup := _setup()
	var counts := {}
	var total := 0
	var low := Damage.SWING_HIGH
	var high := Damage.SWING_LOW
	for seed_value in range(1, SWING_TRIALS + 1):
		var swing := Damage.swing_for(
			seed_value, setup["attacker"], setup["target"], 16
		)
		counts[swing] = int(counts.get(swing, 0)) + 1
		total += swing
		low = mini(low, swing)
		high = maxi(high, swing)

	var mean := float(total) / float(SWING_TRIALS)
	var variance := 0.0
	for swing in counts:
		variance += float(counts[swing]) * pow(float(swing) - mean, 2.0)
	variance /= float(SWING_TRIALS)

	_line("  over %d fights: min=%d max=%d mean=%.4f sd=%.4f" % [
		SWING_TRIALS, low, high, mean, sqrt(variance),
	])
	_line("  intended:      min=%d max=%d mean=%d sd=%.4f" % [
		Damage.SWING_LOW, Damage.SWING_HIGH, Damage.NONE,
		sqrt(2.0 * (pow(float(Damage.SWING_FACES), 2.0) - 1.0) / 12.0),
	])
	_line("")
	_line("  swing  share    intended   histogram")
	for swing in range(Damage.SWING_LOW, Damage.SWING_HIGH + 1):
		var seen := int(counts.get(swing, 0))
		var share := float(seen) / float(SWING_TRIALS)
		var want := _triangular_share(swing)
		_line("  %5d  %6.4f  %6.4f     %s" % [
			swing, share, want, "#".repeat(int(round(share * 300.0))),
		])
	_line("")


## What share of rolls a swing should get, if the two dice are fair and summed.
func _triangular_share(swing: int) -> float:
	var offset := swing - Damage.NONE
	var ways := 0
	for first in range(-Damage.SWING, Damage.SWING + 1):
		var second := offset - first
		if absi(second) <= Damage.SWING:
			ways += 1
	return float(ways) / pow(float(Damage.SWING_FACES), 2.0)


# --- 2. what it costs on average ------------------------------------------


func _what_it_costs_on_average() -> void:
	_head("2. what the die costs on average")
	_line("  The swing is centred and the second step rounds to nearest, so a")
	_line("  blow's mean is the deterministic number itself. Folding the swing in")
	_line("  beside the multiplier and flooring once gave ratios of 0.85 to 0.99")
	_line("  instead -- a quiet nerf on every attack in the game, which is what")
	_line("  this table was written to catch.")
	_line("")
	_line("  power   x    def | steady | mean over %d fights | ratio" % PLAN_TRIALS)
	var setup := _setup()
	for row in [
		[3, Damage.NONE, 0], [8, Damage.NONE, 2], [16, Damage.NONE, 2],
		[16, Damage.FLANK, 2], [16, Damage.BACK, 8], [16, 300, 8],
		[40, Damage.NONE, 8], [3, Damage.NONE, 100],
	]:
		var power: int = row[0]
		var multiplier: int = row[1]
		var defence: int = row[2]
		var steady := Damage.resolve(power, multiplier, defence)
		var total := 0
		for seed_value in range(1, PLAN_TRIALS + 1):
			var swing := Damage.swing_for(
				seed_value, setup["attacker"], setup["target"], power
			)
			total += Damage.resolve(power, multiplier, defence, swing)
		var mean := float(total) / float(PLAN_TRIALS)
		_line("  %5d %4d %4d | %6d | %18.4f | %.4f" % [
			power, multiplier, defence, steady, mean, mean / float(steady),
		])
	_line("")


# --- 3. the ladder --------------------------------------------------------


func _the_ladder() -> void:
	_head("3. the positional ladder, at every roll")
	_line("  The die must be narrower than the narrowest rung, or a player who")
	_line("  manoeuvred round the back would sometimes be punished for it. The")
	_line("  worst roll on a rung is compared with the best roll on the one below.")
	_line("")
	_line("  A sweep over every die width, at every power from 1 to 128:")
	_line("")
	_line("  SWING  band        spread  inverts the ladder?  strictly ordered from")
	for width in range(1, 9):
		var band_low := Damage.NONE - 2 * width
		var band_high := Damage.NONE + 2 * width
		var inverted := false
		var strict_from := -1
		for power in range(1, 129):
			var ordered := true
			for rung in range(1, _LADDER.size()):
				var worse: int = _LADDER[rung - 1]
				var better: int = _LADDER[rung]
				var best_of_worse := Damage.resolve(power, worse, 0, band_high)
				var worst_of_better := Damage.resolve(power, better, 0, band_low)
				if worst_of_better < best_of_worse:
					inverted = true
				if worst_of_better <= best_of_worse:
					ordered = false
			if ordered and strict_from < 0:
				strict_from = power
			elif not ordered:
				strict_from = -1
		_line("  %5d  [%3d, %3d]  %6.4f  %-19s  %s%s" % [
			width, band_low, band_high, float(band_high) / float(band_low),
			"YES -- unusable" if inverted else "no",
			"never" if strict_from < 0 else "power %d" % strict_from,
			"   <-- shipped" if width == Damage.SWING else "",
		])
	_line("")
	_line("  Rung by rung at the die that shipped, for a 16-point blow, no armour:")
	_line("")
	_line("  rung          worst roll | best roll of the rung below | margin")
	for rung in range(1, _LADDER.size()):
		var worst_of_better := Damage.resolve(
			16, _LADDER[rung], 0, Damage.SWING_LOW
		)
		var best_of_worse := Damage.resolve(
			16, _LADDER[rung - 1], 0, Damage.SWING_HIGH
		)
		_line("  x%-3d -> x%-3d  %10d | %27d | %+d" % [
			_LADDER[rung - 1], _LADDER[rung], worst_of_better, best_of_worse,
			worst_of_better - best_of_worse,
		])
	_line("")


const _LADDER := [100, 150, 200, 300]


# --- 4. the same plan, many times -----------------------------------------


func _the_same_plan_many_times() -> void:
	_head("4. the same plan, played many times")

	# 4a. The whole scripted match, decision for decision, under many seeds.
	_line("")
	_line("  4a. the scripted three-commander match, the same %d decisions," % (
		ScriptedMatch.DECISIONS.size()
	))
	_line("      replayed under %d fight seeds" % MATCH_SEEDS)
	_line("")
	var conclusions := {}
	var transcripts := {}
	for seed_value in range(1, MATCH_SEEDS + 1):
		var played := _play_scripted(seed_value)
		var conclusion := played[played.size() - 1]
		conclusions[conclusion] = int(conclusions.get(conclusion, 0)) + 1
		transcripts["\n".join(played)] = true
	_line("      conclusion                          fights   share")
	var ordered_conclusions := conclusions.keys()
	ordered_conclusions.sort()
	for conclusion in ordered_conclusions:
		_line("      %-34s  %6d   %.4f" % [
			conclusion, conclusions[conclusion],
			float(conclusions[conclusion]) / float(MATCH_SEEDS),
		])
	_line("")
	_line("      %d distinct transcripts over %d seeds; %d distinct conclusion(s)."
		% [transcripts.size(), MATCH_SEEDS, conclusions.size()])
	_line("")

	# How far each seeded transcript is from the deterministic one, blow by blow.
	var steady_lines := _play_scripted(Damage.NO_DIE)
	var steady_blows := _dealt_in(steady_lines)
	var blows_seen := 0
	var blows_changed := 0
	var points_off := 0
	var worst_off := 0
	for seed_value in range(1, MATCH_SEEDS + 1):
		var rolled := _dealt_in(_play_scripted(seed_value))
		for i in mini(rolled.size(), steady_blows.size()):
			blows_seen += 1
			var off: int = rolled[i] - steady_blows[i]
			if off != 0:
				blows_changed += 1
			points_off += absi(off)
			worst_off = maxi(worst_off, absi(off))
	_line("      against the same match with the die switched off:")
	_line("        %d blows compared, %d landed for a different number (%.1f%%)" % [
		blows_seen, blows_changed,
		100.0 * float(blows_changed) / float(maxi(1, blows_seen)),
	])
	_line("        %.3f points off per blow on average, worst single blow %+d" % [
		float(points_off) / float(maxi(1, blows_seen)), worst_off,
	])
	_line("")

	# 4b. One deliberately planned two-move combination.
	_line("  4b. a deliberately planned two-move combination, %d fights" % PLAN_TRIALS)
	_line("")
	_line("      The plan: a level-%d commander has manoeuvred behind a level-%d"
		% [LEVEL, LEVEL])
	_line("      one wearing a full armoured suit, and lands a cut and then a")
	_line("      cleave, both backstabs, over two turns. Nothing about the")
	_line("      positioning is in doubt; the only question is the size of the")
	_line("      two blows.")
	_line("")

	var steady := _play_plan(Damage.NO_DIE, 10000)
	var deterministic_total: int = steady["total"]
	_line("      with the die switched off: %d + %d = %d points" % [
		steady["first"], steady["second"], deterministic_total,
	])
	_line("")

	var totals := PackedInt32Array()
	var counts := {}
	var sum := 0
	for seed_value in range(1, PLAN_TRIALS + 1):
		var run := _play_plan(seed_value, 10000)
		var total: int = run["total"]
		totals.append(total)
		counts[total] = int(counts.get(total, 0)) + 1
		sum += total
	var mean := float(sum) / float(PLAN_TRIALS)
	var variance := 0.0
	for total in totals:
		variance += pow(float(total) - mean, 2.0)
	variance /= float(PLAN_TRIALS)
	var lowest := totals[0]
	var highest := totals[0]
	for total in totals:
		lowest = mini(lowest, total)
		highest = maxi(highest, total)

	_line("      the two-blow total over %d fights:" % PLAN_TRIALS)
	_line("        min=%d  max=%d  mean=%.3f  sd=%.3f  (deterministic %d)" % [
		lowest, highest, mean, sqrt(variance), deterministic_total,
	])
	_line("        spread is %+.1f%% / %+.1f%% of the planned number" % [
		100.0 * float(lowest - deterministic_total) / float(deterministic_total),
		100.0 * float(highest - deterministic_total) / float(deterministic_total),
	])
	_line("")
	_line("      total  fights   share   histogram")
	for total in range(lowest, highest + 1):
		var seen := int(counts.get(total, 0))
		if seen == 0:
			continue
		_line("      %5d  %6d  %.4f   %s" % [
			total, seen, float(seen) / float(PLAN_TRIALS),
			"#".repeat(int(round(float(seen) / float(PLAN_TRIALS) * 300.0))),
		])
	_line("")

	# The success curve: how often the plan kills, against a target on health
	# the planner left a given margin under.
	_line("      Does the plan work? A plan that kills is one whose two blows")
	_line("      come to at least the target's remaining health. `margin` is how")
	_line("      many points of slack the planner left: 0 means the plan was")
	_line("      exact to the point with the die switched off.")
	_line("")
	_line("      margin  target hp  plans that killed  share")
	for margin in range(-4, 9):
		var health := deterministic_total - margin
		if health < 1:
			continue
		var killed := 0
		for seed_value in range(1, PLAN_TRIALS + 1):
			var run := _play_plan(seed_value, health)
			if bool(run["killed"]):
				killed += 1
		_line("      %6d  %9d  %17d  %.4f%s" % [
			margin, health, killed, float(killed) / float(PLAN_TRIALS),
			"   <-- exact to the point" if margin == 0 else "",
		])
	_line("")


## What every blow of a transcript dealt, in order.
func _dealt_in(lines: PackedStringArray) -> PackedInt32Array:
	var dealt := PackedInt32Array()
	for line in lines:
		var at := line.find("dealt=")
		if at < 0:
			continue
		var rest := line.substr(at + 6)
		dealt.append(int(rest.split(" ")[0]))
	return dealt


## Play the scripted match's own decisions under one fight seed.
func _play_scripted(seed_value: int) -> PackedStringArray:
	var set_out := ScriptedMatch.set_up()
	var played := CombatMatch.start(
		set_out["board"], set_out["pieces"], seed_value
	)
	for decision in ScriptedMatch.DECISIONS:
		if played.is_over() and str(decision[0]) != "end":
			continue
		ScriptedMatch.apply(played, decision)
	return played.lines


## Play the two-move combination once, against a target on the given health.
func _play_plan(seed_value: int, health: int) -> Dictionary:
	var setup := _setup()
	var target: Commander = setup["target"]
	target.health = health
	var first := CombatResolution.strike(
		setup["board"], setup["pieces"], setup["attacker"], target,
		setup["attacker"].damage_of(0), 0, seed_value
	)
	if bool(first["killed"]):
		return {
			"first": first["dealt"], "second": 0,
			"total": int(first["dealt"]), "killed": true,
		}
	var second := CombatResolution.strike(
		setup["board"], setup["pieces"], setup["attacker"], target,
		setup["attacker"].damage_of(1), 0, seed_value
	)
	return {
		"first": first["dealt"],
		"second": second["dealt"],
		"total": int(first["dealt"]) + int(second["dealt"]),
		"killed": bool(second["killed"]),
	}


## One attacker standing behind one armoured target on flat ground.
func _setup() -> Dictionary:
	var board := BoardSketch.from_rows(PackedStringArray(FLAT))
	var pieces := PieceMap.new()
	var target := Commander.make(MIDDLE, PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL)
	for slot in Armour.SLOTS:
		target.equip(Armour.worn(slot, LEVEL, ItemRarity.COMMON, 0))
	target.wield(Weapon.spear())
	pieces.add(target)
	var attacker := Commander.make(
		MIDDLE + Vector2i(0, 1), PieceGeometry.NORTH, AssetTags.KNIGHT, LEVEL
	)
	attacker.wield(Weapon.sword())
	pieces.add(attacker)
	return {"board": board, "pieces": pieces, "target": target, "attacker": attacker}


# --- 5. the two options that were not chosen ------------------------------


func _what_the_other_two_options_would_have_cost() -> void:
	_head("5. what the two options that were not chosen would have cost")
	_line("  Arithmetic, not simulation: a to-hit roll makes a planned sequence")
	_line("  of n blows land with probability (1-p)^n, for a single-blow miss")
	_line("  chance p. Nothing a planner can do changes that -- margin does not")
	_line("  help, because the blow that missed dealt nothing at all.")
	_line("")
	_line("  miss chance p |  1 blow  2 blows  3 blows  4 blows")
	for p in [0.05, 0.10, 0.20, 0.25, 0.293, 0.30, 0.35, 0.40, 0.45, 0.50]:
		var row := "  %13.3f |" % p
		for blows in range(1, 5):
			row += " %7.4f " % pow(1.0 - p, float(blows))
		_line(row + ("   <-- two blows fall to a coin toss" if absf(p - 0.293) < 0.001
			else ""))
	_line("")
	_line("  A two-move combination fails more often than it succeeds as soon as")
	_line("  p > 1 - 1/sqrt(2) = 0.2929. A d20 attack roll needing 8 or more --")
	_line("  a generous target -- misses 35% of the time, so the two-move")
	_line("  combination the tactical layer exists to reward would land 42% of")
	_line("  the time. That is this task's stop condition, and it is why option")
	_line("  (a) was not taken.")
	_line("")
	_line("  Option (c), both a to-hit roll and armour as reduction, carries the")
	_line("  same (1-p)^n and adds the magnitude spread on top, so it is strictly")
	_line("  worse for planning than either of the other two.")
	_line("")
	_line("  Option (b) as shipped has no such term: every blow lands, so a plan")
	_line("  can only be off by how much. Section 4b above is the price of that,")
	_line("  and it is paid in points rather than in whole failed plans.")
	_line("")


# --- writing --------------------------------------------------------------


func _head(title: String) -> void:
	_line(title)
	_line("-".repeat(70))


func _line(text: String) -> void:
	print(text)
