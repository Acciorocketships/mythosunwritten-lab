extends SceneTree
## Print everything the drop layer claims about itself, as numbers.
##
## Run it with:  ./run_drops.sh
##
## Six tables, all from a fixed seed written into this file, so two runs of this
## command print identical bytes -- which is what tests/test_drops.gd checks by
## running it twice as a subprocess:
##
##   1. what the generator produces over more than a thousand rolls;
##   2. the realised per-item drop rate against the intended one in five;
##   3. one kill, worked, with the dropped items written out in full;
##   4. the frontier: what a ring's gear can be worth against the ring beyond;
##   5. how far a lucky roll lets a near ring reach into a far one;
##   6. the world fingerprint before and after thousands of item rolls.

## The seed every table below is forged from. The same one tests/test_drops.gd
## and reports/drops.md use, so a number here and a number there is one number.
const SEED := 1234

## How many items the distribution walks. The acceptance asks for at least a
## thousand rolls; twelve hundred of each kind is what this prints.
const ROLLS := 1200

## The source level the distribution is rolled at.
const ROLL_LEVEL := 8

## How many kills the drop rate is measured over, each carrying five items, each
## kill's gear forged for that kill.
const RATE_KILLS := 2000

## How many further kills the rate is measured over against one fixed set of
## carried items. Every roll is still its own stream -- the kill differs -- so
## this is the same measurement with the forge taken out of it, and it is cheap
## enough to run wide: two hundred thousand rolls put the standard error of the
## estimate near 0.0009.
const WIDE_KILLS := 40000

## How many kills each ring of the frontier table is ground for.
const GRIND_KILLS := 400

## The distances the frontier is tabulated at, in world units.
const FRONTIER_DISTANCES := [0.0, 64.0, 128.0, 256.0, 512.0, 1024.0]

## The grind lengths the saturation table reports the best-of over.
const SATURATION_STEPS := [1, 10, 100, 1000, 2000]

## How many ticks the world is stepped for in the last table.
const WORLD_TICKS := 50

## How many item rolls are made against the running world there.
const WORLD_ROLLS := 5000


func _initialize() -> void:
	_distribution_table()
	_rate_table()
	_one_kill_table()
	_frontier_table()
	_shortcut_table()
	_world_table()
	quit(0)


# --- 1. What the generator produces ---------------------------------------


func _distribution_table() -> void:
	print("# the distribution over %d rolls of each kind, at source level %d"
		% [ROLLS, ROLL_LEVEL])
	var worn := ItemForge.batch(SEED, "roll-worn", ROLL_LEVEL, Item.KIND_ARMOUR, ROLLS)
	var held := ItemForge.batch(SEED, "roll-held", ROLL_LEVEL, Item.KIND_WEAPON, ROLLS)
	var both: Array[Item] = []
	both.append_array(worn)
	both.append_array(held)

	print("## rarity mix, over all %d rolls" % both.size())
	print("tier         rolled   share   intended    P at L=%d" % ROLL_LEVEL)
	for tier in ItemRarity.TIERS:
		var rolled := 0
		for item in both:
			if item.rarity == tier:
				rolled += 1
		print("%-12s %6d  %6.2f%%  %6.2f%%  %10d" % [
			tier, rolled, 100.0 * rolled / both.size(),
			100.0 * ItemForge.RARITY_WEIGHTS[ItemRarity.rank(tier)] / _weight_total(),
			ItemBudget.total(tier, ROLL_LEVEL),
		])
	print("")

	print("## mean budget and where it is spent")
	print("rolls        n     mean P   mean mov   mean def   mean eff    mov%    def%    eff%")
	_spend_row("worn", worn)
	_spend_row("held", held)
	_spend_row("both", both)

	var exact := 0
	for item in both:
		if item.spends_budget():
			exact += 1
	print("exact: %d of %d rolls spend their budget to the point" % [exact, both.size()])
	print("")


func _spend_row(called: String, items: Array[Item]) -> void:
	var budget := 0.0
	var axes := [0.0, 0.0, 0.0]
	for item in items:
		budget += item.budget()
		var spent := item.axes()
		for axis in 3:
			axes[axis] += spent[axis]
	var n := maxi(1, items.size())
	print("%-12s %5d %8.3f %10.3f %10.3f %10.3f %7.2f %7.2f %7.2f" % [
		called, items.size(), budget / n, axes[0] / n, axes[1] / n, axes[2] / n,
		100.0 * axes[0] / maxf(1.0, budget), 100.0 * axes[1] / maxf(1.0, budget),
		100.0 * axes[2] / maxf(1.0, budget),
	])


func _weight_total() -> float:
	var total := 0.0
	for weight in ItemForge.RARITY_WEIGHTS:
		total += weight
	return total


# --- 2. One item in five --------------------------------------------------


func _rate_table() -> void:
	print("# the per-item drop rate, over %d kills carrying %d items each"
		% [RATE_KILLS, ItemFrontier.HELD_CARRIED + ItemFrontier.WORN_CARRIED])
	var rolled := 0
	var fell := 0
	var per_place := []
	var per_kill := []
	for _place in ItemFrontier.HELD_CARRIED + ItemFrontier.WORN_CARRIED:
		per_place.append(0)
	for _count in ItemFrontier.HELD_CARRIED + ItemFrontier.WORN_CARRIED + 1:
		per_kill.append(0)

	for index in RATE_KILLS:
		var kill := "rate-kill#%d" % index
		var carried := ItemFrontier.carried_at_level(SEED, kill, ROLL_LEVEL)
		var verdicts := ItemDrop.verdicts(SEED, kill, carried)
		var dropped := 0
		for place in verdicts.size():
			rolled += 1
			if verdicts[place]:
				fell += 1
				dropped += 1
				per_place[place] = int(per_place[place]) + 1
		per_kill[dropped] = int(per_kill[dropped]) + 1

	var intended := float(ItemDrop.CHANCE_PERCENT) / ItemDrop.RESOLUTION
	var realised := float(fell) / maxi(1, rolled)
	print("intended %.4f   realised %.4f   difference %+.4f   (%d of %d rolls fell)" % [
		intended, realised, realised - intended, fell, rolled,
	])

	var fixed := ItemFrontier.carried_at_level(SEED, "fixed-carry", ROLL_LEVEL)
	var wide_rolled := 0
	var wide_fell := 0
	for index in WIDE_KILLS:
		var kill := "wide-kill#%d" % index
		for place in fixed.size():
			wide_rolled += 1
			if ItemDrop.falls(SEED, kill, place, fixed[place]):
				wide_fell += 1
	var wide := float(wide_fell) / maxi(1, wide_rolled)
	print("wide sample, one fixed carry over %d further kills:" % WIDE_KILLS)
	print("intended %.4f   realised %.5f   difference %+.5f   (%d of %d rolls fell)" % [
		intended, wide, wide - intended, wide_fell, wide_rolled,
	])
	print("")
	print("## by place in what was carried")
	print("place    rolls   fell   rate")
	for place in per_place.size():
		print("%5d %8d %6d %6.4f" % [
			place, RATE_KILLS, per_place[place],
			float(per_place[place]) / maxi(1, RATE_KILLS),
		])
	print("")
	print("## how many items one kill leaves")
	print("dropped   kills    share   binomial(%d, %.2f)" % [per_place.size(), intended])
	for count in per_kill.size():
		print("%7d %7d %8.4f %18.4f" % [
			count, per_kill[count], float(per_kill[count]) / maxi(1, RATE_KILLS),
			_binomial(per_place.size(), count, intended),
		])
	print("")


func _binomial(trials: int, hits: int, chance: float) -> float:
	var ways := 1.0
	for step in hits:
		ways = ways * (trials - step) / (step + 1)
	return ways * pow(chance, hits) * pow(1.0 - chance, trials - hits)


# --- 3. One kill, worked --------------------------------------------------


func _one_kill_table() -> void:
	var kill := "goblin-42"
	var distance := 128.0
	var carried := ItemFrontier.carried_at(SEED, kill, distance)
	print("# one kill: %s, %0.0f from spawn, ring %d, level %d" % [
		kill, distance, ItemFrontier.ring_at(distance), ItemFrontier.level_at(distance),
	])
	print("## what it carried, and the stream each verdict was drawn from")
	print("  #  fell  roll  stream                          item")
	var verdicts := ItemDrop.verdicts(SEED, kill, carried)
	for index in carried.size():
		print("%3d %5s %5d  %-30s %s" % [
			index, "yes" if verdicts[index] else "no",
			ItemDrop.roll(SEED, kill, index, carried[index]),
			ItemDrop.stream_label(kill, index, carried[index]).substr(0, 30),
			carried[index].line(),
		])
	print("")
	print("## what it left on the ground")
	print(ItemDrop.line(SEED, kill, carried))
	print("")


# --- 4. The frontier ------------------------------------------------------


func _frontier_table() -> void:
	print("# the frontier: what a ring can hand you against the ring beyond it")
	print("# ground for %d kills a ring, %d items a kill"
		% [GRIND_KILLS, ItemFrontier.HELD_CARRIED + ItemFrontier.WORN_CARRIED])
	print("      d  ring   L(d)  ceiling  ground best  ground mean"
		+ "   next L  next ceiling  next ground best  ahead")
	var ok := 0
	var ground := {}
	for distance_value in FRONTIER_DISTANCES:
		var distance: float = distance_value
		var ring := ItemFrontier.ring_at(distance)
		var here := _cached_grind(ground, ring)
		var next := _cached_grind(ground, ring + 1)
		var ceiling := ItemFrontier.ceiling_of_ring(ring)
		var beyond := ItemFrontier.ceiling_of_ring(ring + 1)
		if int(here["best"]) <= ceiling and ceiling < beyond and int(here["best"]) < int(next["best"]):
			ok += 1
		print("%7.0f %5d %6d %8d %12d %12.3f %8d %13d %17d %6s" % [
			distance, ring, ItemFrontier.level_of_ring(ring), ceiling,
			here["best"], here["mean"], ItemFrontier.level_of_ring(ring + 1), beyond,
			next["best"], "yes" if ceiling < beyond else "NO",
		])
	print("rings where the grind stayed under its own ceiling, that ceiling stayed "
		+ "under the next, and the ring beyond was carrying more: %d of %d"
		% [ok, FRONTIER_DISTANCES.size()])
	print("")

	print("## grinding saturates: best budget found after N kills at ring %d, against ring %d"
		% [ItemFrontier.ring_at(FRONTIER_DISTANCES[2]), ItemFrontier.ring_at(FRONTIER_DISTANCES[2]) + 1])
	var ring_of := ItemFrontier.ring_at(FRONTIER_DISTANCES[2])
	print("  kills   best budget   own ceiling   next ceiling")
	var best := 0
	var walked := 0
	for step in SATURATION_STEPS:
		var kills: int = step
		while walked < kills:
			var carried := ItemFrontier.carried_at_level(
				SEED, "saturate#%d" % walked, ItemFrontier.level_of_ring(ring_of))
			best = maxi(best, ItemFrontier.best_budget(carried))
			walked += 1
		print("%7d %13d %13d %14d" % [
			kills, best, ItemFrontier.ceiling_of_ring(ring_of),
			ItemFrontier.ceiling_of_ring(ring_of + 1),
		])
	print("")


func _cached_grind(cache: Dictionary, ring: int) -> Dictionary:
	if not cache.has(ring):
		cache[ring] = _grind(ring)
	return cache[ring]


func _grind(ring: int) -> Dictionary:
	var level := ItemFrontier.level_of_ring(ring)
	var best := 0
	var total := 0
	var count := 0
	for index in GRIND_KILLS:
		var carried := ItemFrontier.carried_at_level(SEED, "grind-%d#%d" % [ring, index], level)
		for item in carried:
			best = maxi(best, item.budget())
			total += item.budget()
			count += 1
	return {"best": best, "mean": float(total) / maxi(1, count)}


# --- 5. How far a lucky roll reaches --------------------------------------


func _shortcut_table() -> void:
	print("# what rarity buys: the chance one item from ring d beats one from ring d+k")
	print("# exact, from the tier weights and the two levels -- no sampling")
	print("ring d  L(d)    k=1     k=2     k=4     k=8")
	for ring in [0, 1, 2, 4, 8, 16]:
		var line := "%6d %5d" % [ring, ItemFrontier.level_of_ring(ring)]
		for k in [1, 2, 4, 8]:
			line += " %6.4f" % _beats(ring, ring + int(k))
		print(line)
	print("")


## The exact chance that one item rolled at ring `here` is worth more than one
## rolled at ring `there`, summed over the thirty-six tier pairs.
func _beats(here: int, there: int) -> float:
	var total := _weight_total()
	var chance := 0.0
	for near in ItemRarity.TIERS.size():
		for far in ItemRarity.TIERS.size():
			var near_budget := int(ItemRarity.MULTIPLIERS[near]) * ItemFrontier.level_of_ring(here)
			var far_budget := int(ItemRarity.MULTIPLIERS[far]) * ItemFrontier.level_of_ring(there)
			if near_budget > far_budget:
				chance += (ItemForge.RARITY_WEIGHTS[near] / total) \
					* (ItemForge.RARITY_WEIGHTS[far] / total)
	return chance


# --- 6. The item stream cannot move the world -----------------------------


func _world_table() -> void:
	print("# the item stream against the world-generation stream")
	print("streams the item layer opens:  item:<source>   %s:<kill>#<index>:<item>"
		% ItemDrop.STREAM_PREFIX)
	print("each is forked from the world seed into a fresh generator and dropped "
		+ "after the roll; nothing is held between calls")
	print("")

	var quiet := SimWorld.new(SEED)
	var noisy := SimWorld.new(SEED)
	print("fresh world digest:                  %s" % quiet.digest())
	print("same digest on the second world:     %s" % ("yes" if noisy.digest() == quiet.digest() else "NO"))

	var rolled := 0
	for index in WORLD_ROLLS:
		var item := ItemForge.forge(SEED, "against-world#%d" % index, 1 + index % 12,
			Item.KIND_ARMOUR if index % 2 == 0 else Item.KIND_WEAPON)
		if ItemDrop.falls(SEED, "against-world#%d" % index, 0, item):
			rolled += 1
	print("after %d item rolls (%d fell):        %s" % [
		WORLD_ROLLS, rolled, noisy.digest(),
	])
	print("unchanged by the rolls:              %s"
		% ("yes" if noisy.digest() == quiet.digest() else "NO"))
	print("")

	for tick in WORLD_TICKS:
		quiet.step()
		noisy.step()
		for index in 20:
			var item := ItemForge.forge(SEED, "tick%d#%d" % [tick, index], 1 + index % 9,
				Item.KIND_WEAPON)
			ItemDrop.falls(SEED, "tick%d#%d" % [tick, index], index, item)
	print("after %d ticks, world with no rolls:  %s" % [WORLD_TICKS, quiet.digest()])
	print("after %d ticks, world with rolls:     %s" % [WORLD_TICKS, noisy.digest()])
	print("the two worlds agree:                %s"
		% ("yes" if noisy.digest() == quiet.digest() else "NO"))
	print("")
