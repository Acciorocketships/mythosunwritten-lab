extends TestSuite
## What a kill leaves behind, and why grinding a safe ring cannot outrun the
## frontier.
##
## Four claims, and each is paired with a run in which its premise is broken, so
## that a check which would pass whatever the code did is not counted as
## evidence:
##
##   * **one in five.** Every carried item is rolled on its own and kept about
##     one time in five. The realised rate is counted over ten thousand rolls and
##     compared with $0.2$; the broken run counts the same rolls against a
##     threshold of fifty and finds a half, so the counter is reading the roll
##     and not the intention.
##   * **addressed, not sequential.** An item's verdict depends on the kill, its
##     place and its name, and on nothing else that was carried -- shown by
##     truncating what was carried and finding the surviving verdicts unmoved.
##   * **the frontier stays ahead.** The best budget a ring can ever hand you is
##     its top multiplier against its own level, and that number is strictly
##     below the same number one ring out. Ground over a thousand items a ring;
##     the broken run compares a ring against itself and finds no gap.
##   * **the item stream cannot move the world.** A world is fingerprinted,
##     thousands of item rolls are made against it, and it is fingerprinted
##     again. The broken run steps the world once and watches the fingerprint
##     move, so the comparison is between two live fingerprints and not two
##     copies of a constant.
class_name TestDrops

## The seed every measurement here uses. The same one `bin/drops_main.gd` prints
## its tables from and `reports/drops.md` quotes, so a number in one is a number
## in the others.
const SEED := 1234

## How many kills the drop rate is counted over, each carrying five items.
const RATE_KILLS := 2000

## How many rolls the distribution is tabulated over. The acceptance asks for at
## least a thousand.
const ROLLS := 1200

## The source level the distribution is rolled at.
const ROLL_LEVEL := 8

## How many kills a ring is ground for in the frontier check.
const GRIND_KILLS := 200

## How many item rolls are made against a live world.
const WORLD_ROLLS := 2000

## How many ticks that world is stepped for.
const WORLD_TICKS := 20

## The vocabulary of world generation. No file of the item layer may name any of
## these: the two are separate streams, and the cheapest way to keep them
## separate is for neither to be able to reach the other.
const WORLD_CLASSES := [
	"SimWorld", "Simulation", "TerrainQuery", "TerrainSurfaceField",
	"TerrainStreamer", "TerrainChunkMesher", "TerrainChunkGeometry",
	"BiomeField", "BiomeCatalog", "BiomeProfile", "WaterField", "WaterSheet",
	"IslandField", "FloatingIsland", "IslandStreamer", "SettlementField",
	"Settlement", "SettlementStreamer", "PathNetwork", "DecorationScatter",
	"ScatterPatch", "ScatterStreamer", "MountainField", "ValueNoise",
]

## The item layer's files, by the class each one declares.
const ITEM_CLASSES := [
	"Item", "ItemBudget", "ItemRarity", "ItemEffect", "ItemForge", "Ability",
	"ItemDrop", "ItemFrontier",
]

const SIM_DIR := "res://sim"


func _init() -> void:
	suite_name = "drops"


func run() -> void:
	_the_rule_is_one_in_five()
	_the_realised_rate_matches()
	_a_verdict_is_addressed_not_sequential()
	_the_same_kill_drops_the_same_items()
	_two_processes_agree()
	_the_distribution_over_a_thousand_rolls()
	_the_gradient_rises_with_distance()
	_the_frontier_stays_ahead()
	_item_rolls_do_not_move_the_world()
	_the_item_layer_cannot_reach_world_generation()


# --- One in five ----------------------------------------------------------


## The intended rate is a constant, not a literal repeated at every call site.
func _the_rule_is_one_in_five() -> void:
	equal(ItemDrop.CHANCE_PERCENT, 20, "section 4's ~20% each, as a number")
	equal(ItemDrop.RESOLUTION, 100, "and the draw it is compared against")
	equal(float(ItemDrop.CHANCE_PERCENT) / ItemDrop.RESOLUTION, 0.2,
		"so the intended rate is exactly one in five")


## The realised rate, counted rather than assumed.
func _the_realised_rate_matches() -> void:
	var rolled := 0
	var fell := 0
	var half := 0
	for index in RATE_KILLS:
		var kill := "rate-kill#%d" % index
		var carried := ItemFrontier.carried_at_level(SEED, kill, ROLL_LEVEL)
		if index == 0:
			equal(carried.size(), 5, "a kill carries five items")
		for place in carried.size():
			rolled += 1
			if ItemDrop.falls(SEED, kill, place, carried[place]):
				fell += 1
			# The broken run: the same draws against a threshold of fifty. If the
			# counter above were reporting the intention rather than the roll,
			# this would come out at a fifth too.
			if ItemDrop.roll(SEED, kill, place, carried[place]) < 50:
				half += 1

	equal(rolled, RATE_KILLS * 5, "the sample is %d rolls" % (RATE_KILLS * 5))
	var realised := float(fell) / rolled
	check(absf(realised - 0.2) < 0.01,
		"realised drop rate %.5f (%d of %d) is more than 0.01 from 0.2"
		% [realised, fell, rolled])
	var at_half := float(half) / rolled
	check(absf(at_half - 0.5) < 0.02,
		"the same draws read at a threshold of fifty came out at %.5f, not near "
		% at_half + "a half, so the counter is not reading the draw")

	# And the rate does not depend on how rich the item is: an item's chance of
	# falling is one in five whatever its tier, which is what makes rarity a
	# property of the item and not of the corpse.
	var by_tier := {}
	for tier in ItemRarity.TIERS:
		by_tier[tier] = [0, 0]
	for index in RATE_KILLS:
		var kill := "tier-kill#%d" % index
		var carried := ItemFrontier.carried_at_level(SEED, kill, ROLL_LEVEL)
		for place in carried.size():
			var seen: Array = by_tier[carried[place].rarity]
			seen[0] += 1
			if ItemDrop.falls(SEED, kill, place, carried[place]):
				seen[1] += 1
	for tier in ItemRarity.TIERS:
		var seen: Array = by_tier[tier]
		if int(seen[0]) < 300:
			continue
		var tier_rate := float(seen[1]) / int(seen[0])
		check(absf(tier_rate - 0.2) < 0.05,
			"%s items fell at %.4f over %d rolls, which is not near one in five"
			% [tier, tier_rate, seen[0]])


## An item's verdict is a function of the kill, its place and its name. Nothing
## else that was carried can move it.
func _a_verdict_is_addressed_not_sequential() -> void:
	var kill := "addressed-kill"
	var carried := ItemFrontier.carried_at_level(SEED, kill, 6)
	var full := ItemDrop.verdicts(SEED, kill, carried)

	var shorter: Array[Item] = []
	for index in carried.size() - 2:
		shorter.append(carried[index])
	var truncated := ItemDrop.verdicts(SEED, kill, shorter)
	equal(truncated.size(), shorter.size(), "the shorter carry gives a shorter list")
	var moved := 0
	for index in truncated.size():
		if truncated[index] != full[index]:
			moved += 1
	equal(moved, 0,
		"dropping the last two items moved %d of the surviving verdicts" % moved)

	# Broken: the same items at shifted places draw different numbers, because the
	# place is part of the address. The comparison is on the draw rather than on
	# the verdict: two draws either side of the threshold agree as verdicts one
	# time in three by luck, and a control that can pass by luck is not a control.
	var shifted := 0
	for index in carried.size():
		if ItemDrop.roll(SEED, kill, index, carried[index]) \
				!= ItemDrop.roll(SEED, kill, index + 1, carried[index]):
			shifted += 1
	equal(shifted, carried.size(),
		"moving every item one place along left %d of %d draws unmoved, so the "
		% [carried.size() - shifted, carried.size()] + "place is not part of the address")

	# And so is the name: the same place on the same kill, asked about a different
	# item, is a different draw.
	var renamed := 0
	for index in carried.size():
		var other: Item = carried[(index + 1) % carried.size()]
		if carried[index].item_name != other.item_name \
				and ItemDrop.roll(SEED, kill, index, carried[index]) \
				!= ItemDrop.roll(SEED, kill, index, other):
			renamed += 1
	check(renamed > 0, "the item's name is part of the address too")


func _the_same_kill_drops_the_same_items() -> void:
	var carried := ItemFrontier.carried_at(SEED, "goblin-42", 128.0)
	var once := ItemDrop.line(SEED, "goblin-42", carried)
	var twice := ItemDrop.line(SEED, "goblin-42", carried)
	equal(once, twice, "the same seed and kill drop the same items, to the byte")

	var elsewhere := ItemDrop.line(SEED + 1, "goblin-42", carried)
	var another := ItemDrop.line(SEED, "goblin-43", carried)
	var differing := 0
	if elsewhere != once:
		differing += 1
	if another != once:
		differing += 1
	equal(differing, 2, "another seed and another kill both give something else")

	# Over a run of kills the drops differ from one another, so "the same kill
	# gives the same drops" is not "every kill gives the same drops".
	var seen := {}
	for index in 200:
		var kill := "vary#%d" % index
		seen[ItemDrop.line(SEED, kill, ItemFrontier.carried_at_level(SEED, kill, 6))] = true
	check(seen.size() > 150,
		"two hundred kills produced only %d distinct outcomes" % seen.size())


## Two separate processes print the same bytes, the worked kill among them.
func _two_processes_agree() -> void:
	var first := _run_drops()
	var second := _run_drops()
	equal(first["exit_code"], 0, "the documented command exits 0")
	equal(second["exit_code"], 0, "and so does a second run of it")
	check(first["output"].length() > 2000,
		"it printed %d characters of tables" % first["output"].length())
	equal(first["output"], second["output"],
		"two separate processes print identical bytes")

	var carried := ItemFrontier.carried_at(SEED, "goblin-42", 128.0)
	check(first["output"].contains(ItemDrop.line(SEED, "goblin-42", carried)),
		"and what they printed includes this run's own line for the same kill")
	check(first["output"].contains("unchanged by the rolls:              yes"),
		"and the world fingerprint it printed was unchanged by the rolls")

	not_equal(first["output"], "", "the run printed something")
	not_equal(first["output"], first["output"] + "x",
		"and the comparison can tell two transcripts apart")


func _run_drops() -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/drops_main.gd",
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


# --- What the generator produces ------------------------------------------


## Over more than a thousand rolls: the rarity mix, the mean budget, and how the
## spend divides across the three axes.
func _the_distribution_over_a_thousand_rolls() -> void:
	var worn := ItemForge.batch(SEED, "roll-worn", ROLL_LEVEL, Item.KIND_ARMOUR, ROLLS)
	var held := ItemForge.batch(SEED, "roll-held", ROLL_LEVEL, Item.KIND_WEAPON, ROLLS)
	var both: Array[Item] = []
	both.append_array(worn)
	both.append_array(held)
	check(both.size() >= 1000, "the sample is %d rolls" % both.size())

	var weight_total := 0.0
	for weight in ItemForge.RARITY_WEIGHTS:
		weight_total += weight

	var counted := 0
	var budget := 0.0
	for tier in ItemRarity.TIERS:
		var rolled := 0
		for item in both:
			if item.rarity == tier:
				rolled += 1
		counted += rolled
		var share := float(rolled) / both.size()
		var intended: float = ItemForge.RARITY_WEIGHTS[ItemRarity.rank(tier)] / weight_total
		check(absf(share - intended) < 0.03,
			"%s came up at %.4f against an intended %.4f" % [tier, share, intended])
	equal(counted, both.size(), "every roll landed on one of the six tiers")

	var exact := 0
	var axes := [0.0, 0.0, 0.0]
	for item in both:
		budget += item.budget()
		if item.spends_budget():
			exact += 1
		var spent := item.axes()
		for axis in 3:
			axes[axis] += spent[axis]
	equal(exact, both.size(), "every roll spends its budget to the point")

	# The mean budget is the mean multiplier against the level, and the mean
	# multiplier is fixed by the weights -- so this number is predicted here and
	# then measured, rather than read off the run.
	var mean_multiplier := 0.0
	for index in ItemRarity.TIERS.size():
		mean_multiplier += ItemForge.RARITY_WEIGHTS[index] / weight_total \
			* ItemRarity.MULTIPLIERS[index]
	var predicted := mean_multiplier * ROLL_LEVEL
	var mean_budget := budget / both.size()
	check(absf(mean_budget - predicted) < 0.1 * predicted,
		"mean budget %.3f is more than a tenth from the predicted %.3f"
		% [mean_budget, predicted])

	# Worn gear spends on movement and defence; held gear spends on effects. Both
	# spend the whole budget, so the two shares are one statement made twice.
	var worn_effects := _axis_share(worn, ItemBudget.EFFECTS)
	var held_effects := _axis_share(held, ItemBudget.EFFECTS)
	check(worn_effects < 0.3,
		"worn gear put %.4f of its budget into effects" % worn_effects)
	check(held_effects > 0.5,
		"held gear put only %.4f of its budget into effects" % held_effects)
	check(_axis_share(worn, ItemBudget.MOVEMENT) + _axis_share(worn, ItemBudget.DEFENCE)
			> 2.0 * (_axis_share(held, ItemBudget.MOVEMENT)
			+ _axis_share(held, ItemBudget.DEFENCE)),
		"worn gear should put far more of itself into movement and defence than held gear")

	var shares := 0.0
	for axis in 3:
		shares += _axis_share(both, axis)
	check(absf(shares - 1.0) < 0.0001,
		"the three shares came to %.6f rather than one" % shares)


func _axis_share(items: Array[Item], axis: int) -> float:
	var on_axis := 0.0
	var total := 0.0
	for item in items:
		on_axis += item.axes()[axis]
		total += item.budget()
	return 0.0 if total <= 0.0 else on_axis / total


# --- The frontier ---------------------------------------------------------


func _the_gradient_rises_with_distance() -> void:
	equal(ItemFrontier.level_at(0.0), ItemFrontier.SPAWN_LEVEL,
		"a creature on spawn is worth the spawn level")
	equal(ItemFrontier.ring_at(ItemFrontier.RING_SPAN - 0.001), 0,
		"the last step of ring 0 is still ring 0")
	equal(ItemFrontier.ring_at(ItemFrontier.RING_SPAN), 1,
		"and the first step past it is ring 1")
	equal(ItemFrontier.level_at(ItemFrontier.RING_SPAN),
		ItemFrontier.SPAWN_LEVEL + ItemFrontier.LEVELS_PER_RING,
		"which is worth one more level")

	var falls := 0
	var previous := ItemFrontier.level_at(0.0)
	for step in 200:
		var level := ItemFrontier.level_at(step * 8.0)
		if level < previous:
			falls += 1
		previous = level
	equal(falls, 0, "the gradient fell back %d times over 1600 units" % falls)
	check(ItemFrontier.level_at(1600.0) > ItemFrontier.level_at(0.0),
		"and it did rise: a gradient that never fell but also never rose would "
		+ "pass the check above")


## Anti-invincibility as a number.
func _the_frontier_stays_ahead() -> void:
	var behind := 0
	var carrying_more := 0
	var rings := [0, 1, 2, 4, 8, 16]
	var ground := {}
	for ring_value in rings:
		var ring: int = ring_value
		var here := _grind(ground, ring)
		var beyond := _grind(ground, ring + 1)
		var ceiling := ItemFrontier.ceiling_of_ring(ring)

		check(int(here["best"]) <= ceiling,
			"ring %d ground out %d, above its own ceiling of %d"
			% [ring, here["best"], ceiling])
		if ceiling < ItemFrontier.ceiling_of_ring(ring + 1):
			behind += 1
		if int(here["best"]) < int(beyond["best"]):
			carrying_more += 1
	equal(behind, rings.size(),
		"every ring's ceiling should sit under the ceiling of the ring beyond it")
	equal(carrying_more, rings.size(),
		"and the best a ring ground out should sit under the best the next ring "
		+ "was carrying")

	# Broken: the same comparison of a ring against itself finds no gap at all,
	# so the gaps above are the gradient and not an artefact of the comparison.
	var self_gaps := 0
	for ring_value in rings:
		var ring: int = ring_value
		if ItemFrontier.ceiling_of_ring(ring) < ItemFrontier.ceiling_of_ring(ring):
			self_gaps += 1
	equal(self_gaps, 0, "a ring compared against itself should show no gap")

	# Grinding saturates: past a few hundred kills the best a ring can offer
	# stops moving, and where it stops is the ceiling.
	var ring_of := 2
	var best := 0
	for index in 600:
		best = maxi(best, ItemFrontier.best_budget(ItemFrontier.carried_at_level(
			SEED, "saturate#%d" % index, ItemFrontier.level_of_ring(ring_of))))
	equal(best, ItemFrontier.ceiling_of_ring(ring_of),
		"six hundred kills at ring %d should reach that ring's ceiling and stop"
		% ring_of)
	check(best < ItemFrontier.ceiling_of_ring(ring_of + 1),
		"and stop below the next ring's ceiling")


func _grind(cache: Dictionary, ring: int) -> Dictionary:
	if cache.has(ring):
		return cache[ring]
	var level := ItemFrontier.level_of_ring(ring)
	var best := 0
	var total := 0
	var count := 0
	for index in GRIND_KILLS:
		for item in ItemFrontier.carried_at_level(SEED, "grind-%d#%d" % [ring, index], level):
			best = maxi(best, item.budget())
			total += item.budget()
			count += 1
	cache[ring] = {"best": best, "mean": float(total) / maxi(1, count)}
	return cache[ring]


# --- The item stream against the world-generation stream ------------------


## Rolling items cannot move the world, shown on the world's own fingerprint.
func _item_rolls_do_not_move_the_world() -> void:
	var quiet := SimWorld.new(SEED)
	var noisy := SimWorld.new(SEED)
	equal(noisy.digest(), quiet.digest(),
		"two worlds from one seed start out identical, or nothing below means anything")

	var before := noisy.digest()
	for index in WORLD_ROLLS:
		var kill := "against-world#%d" % index
		var item := ItemForge.forge(SEED, kill, 1 + index % 12,
			Item.KIND_ARMOUR if index % 2 == 0 else Item.KIND_WEAPON)
		ItemDrop.falls(SEED, kill, index % 5, item)
	equal(noisy.digest(), before,
		"%d item rolls moved the world's fingerprint" % WORLD_ROLLS)

	# Interleaved: the rolls happen between ticks, where a shared stream would do
	# its damage. The control world takes the same ticks and no rolls.
	for tick in WORLD_TICKS:
		quiet.step()
		noisy.step()
		for index in 20:
			var kill := "tick%d#%d" % [tick, index]
			ItemDrop.falls(SEED, kill, index,
				ItemForge.forge(SEED, kill, 1 + index % 9, Item.KIND_WEAPON))
	equal(noisy.digest(), quiet.digest(),
		"a world stepped with item rolls between the ticks ended up different "
		+ "from one stepped without them")

	# Broken: one more tick does move the fingerprint, so the equalities above
	# are between two live fingerprints rather than two copies of a constant.
	var moved := noisy.digest()
	noisy.step()
	not_equal(noisy.digest(), moved,
		"stepping the world did not move its fingerprint, so the fingerprint is "
		+ "not reading the world")


## Neither stream can reach the other, checked by reading sim/ rather than said.
func _the_item_layer_cannot_reach_world_generation() -> void:
	var item_files := PackedStringArray()
	for path in _sim_sources():
		var text := _read(path)
		for word in ITEM_CLASSES:
			if text.contains("class_name %s\n" % word):
				item_files.append(path)
				break
	equal(item_files, PackedStringArray([
		"res://sim/ability.gd", "res://sim/item.gd", "res://sim/item_budget.gd",
		"res://sim/item_drop.gd", "res://sim/item_effect.gd",
		"res://sim/item_forge.gd", "res://sim/item_frontier.gd",
		"res://sim/item_rarity.gd",
	]), "the item layer is these eight files, found by opening sim/")

	var reaching := PackedStringArray()
	for path in item_files:
		for word in WORLD_CLASSES:
			if LayerCheck._contains_word(_read(path), word):
				reaching.append("%s -> %s" % [path, word])
				break
	equal(reaching, PackedStringArray(),
		"no file of the item layer names a class of world generation")

	# Broken: the same scan over the file that does own world generation finds it
	# at once, so the empty result above is "not there" and not "did not look".
	check(LayerCheck._contains_word(_read("res://sim/world.gd"), "TerrainStreamer"),
		"the same scan does find world generation where world generation lives")


func _sim_sources() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(SIM_DIR)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.get_extension() == "gd":
			found.append(SIM_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
