extends TestSuite
## One item, one power budget: rarity, level, and the movement-against-defence
## trade.
##
## Every number here is written out by hand and compared exactly -- nothing is
## checked against a value the code under test produced, and nothing is checked
## against a count where the number itself could be written down. And every claim
## that has a premise is paired with a run in which that premise is broken: the
## budget is bumped by a point, the wearer's score is raised to the item's level,
## the equal-budget filter is dropped, the largest-remainder rule is replaced
## with a plain floor. A check that passes whatever the item does is not a check.
##
## The four things this suite is about:
##
##   * `P = r(rarity) * L_source`, and the three axes summing to it *exactly*,
##     over every item the forge produces;
##   * the rounding rule -- largest remainder, ties to the earlier axis -- shown
##     to be doing work by replacing it with a plain floor and watching points
##     disappear;
##   * the trade: at equal budget, the items with the most movement have the
##     least defence, as a correlation computed here rather than quoted from the
##     generator;
##   * the gate `floor(v * min(A, L) / L)`, worked through a level-8 wisdom
##     chestplate read by a wearer with wisdom 6.
class_name TestItems

## The seed the forge is asked for everywhere below. The same one
## `bin/items_main.gd` prints its tables from, so a number in this file and a
## number in `reports/items.md` are the same number.
const SEED := 1234

## How many items the budget claim is checked over. The acceptance asks for at
## least fifty; sixty is what the report tabulates, so both walk the same items.
const BUDGET_ITEMS := 60

## The run the trade-off is measured over, and the level it is measured at.
const TRADE_ITEMS := 400
const TRADE_LEVEL := 8

## The item layer's own class names. The structural checks below find the layer's
## files by looking for the file that *declares* each of these, so a new file
## joins the checks by declaring one rather than by being added to a list here.
const ITEM_CLASSES := [
	"Item", "ItemBudget", "ItemRarity", "ItemEffect", "ItemForge", "Ability",
	"ItemDrop", "ItemFrontier",
]

## What a random source is called in this project. The same list
## `tests/test_combat_resolution.gd` uses, for the same reason: matched as plain
## text, so a mention in a comment counts too.
const RANDOM_SOURCES := [
	"randi", "randf", "randomize", "RandomNumberGenerator", "Rng.",
]

## The readers of the item layer that are not part of a fight, and what each of
## them may name.
##
## Two, and both for the same underlying reason. `Ability` is in the item layer
## because an item's gate is read against a score, and `ItemFrontier` is in it
## because the power budget was the first thing that needed section 5's
## distance-to-level gradient. So a file that reads a score, or reads what a
## piece of ground is worth, for any *other* purpose reaches into this layer
## without being part of a fight:
##
##   * the difficulty-class agent's prompt writer, which names an ability to put
##     the six scores to a language model and to read one back;
##   * the orchestrator's roller, which names an ability to roll the six of them
##     and the frontier to ask what the ground it is rolling for is worth and to
##     forge the gear that ground gives.
##
## Each is excused from the fight-reads-items direction below and checked against
## a narrower rule instead: it names what is listed for it here and no more of
## the item layer, so no rule about items can have moved into it.
const NOT_A_FIGHT := [
	{"path": "res://sim/check_prompt.gd", "may_name": ["Ability"]},
	{"path": "res://sim/spawn_roll.gd", "may_name": ["Ability", "ItemFrontier"]},
]

## The directory both structural checks read, all of it.
const SIM_DIR := "res://sim"

## The one file whose docstring carries the mutability invariant.
const ITEM_FILE := "res://sim/item.gd"


func _init() -> void:
	suite_name = "items"


func run() -> void:
	_the_six_tiers()
	_the_six_abilities()
	_the_budget_formula()
	_the_split_is_exact()
	_an_effects_share_with_no_name_is_still_spent()
	_the_axes_are_writable_and_the_file_says_who_owns_the_sum()
	_the_rounding_rule_does_work()
	_every_forged_item_spends_its_budget()
	_movement_and_defence_compete()
	_the_ability_gate()
	_the_same_seed_and_source_give_the_same_item()
	_two_processes_agree()
	_higher_rarity_carries_more()
	_the_layer_stands_on_its_own()


# --- Rarity ---------------------------------------------------------------


## The six tiers section 4 names, in the order it names them, and what each is
## worth.
func _the_six_tiers() -> void:
	equal(ItemRarity.TIERS, [
		"common", "uncommon", "rare", "legendary", "mythic", "eternal",
	], "the six tiers are the six section 4 names, in that order")
	equal(ItemRarity.TIERS.size(), 6, "and there are six of them")

	for pair in [["common", 4], ["uncommon", 6], ["rare", 9],
			["legendary", 14], ["mythic", 21], ["eternal", 32]]:
		equal(ItemRarity.multiplier(pair[0]), pair[1],
			"r(%s) is %d" % [pair[0], pair[1]])

	# Eight, not eighty: a common item off a level-16 creature carries exactly
	# what an eternal off a level-2 one carries, so rarity is a shortcut through
	# the level gradient and never a replacement for it.
	equal(ItemBudget.total(ItemRarity.COMMON, 16), 64,
		"a common item from a level-16 creature is worth 64")
	equal(ItemBudget.total(ItemRarity.ETERNAL, 2), 64,
		"and an eternal from a level-2 one is worth exactly the same")

	# Broken: a tier that is not one of the six is worth nothing, so a misspelt
	# name produces a worthless item rather than a quietly average one.
	equal(ItemRarity.multiplier("epic"), 0, "a name that is not a tier is worth 0")
	equal(ItemBudget.total("epic", 8), 0, "and an item of it has no budget at all")
	not_equal(ItemRarity.multiplier("epic"), ItemRarity.multiplier("rare"),
		"if an unknown tier fell back to a real one, the check above would prove nothing")


## Section 4's second sentence about rarity: a higher tier gives a higher
## *chance* of more effects. A chance, not a count -- so this is checked as a
## ceiling per tier and a rising average across tiers, both measured over forged
## items rather than read off the table.
func _higher_rarity_carries_more() -> void:
	for pair in [["common", 1], ["uncommon", 2], ["rare", 2],
			["legendary", 3], ["mythic", 3], ["eternal", 4]]:
		equal(ItemRarity.effect_slots(pair[0]), pair[1],
			"a %s item divides its effects at most %d ways" % [pair[0], pair[1]])
	equal(ItemRarity.effect_slots("epic"), 0,
		"and a name that is not a tier divides them no ways at all")

	# Two thousand items at one level, counted by tier. The ceiling holds and the
	# average rises.
	var counts := {}
	var totals := {}
	var over_ceiling := 0
	for index in 2000:
		var item := ItemForge.forge(SEED, "slots#%d" % index, 9,
			Item.KIND_ARMOUR if index % 2 == 0 else Item.KIND_WEAPON)
		var carried := item.effects.size()
		if carried > ItemRarity.effect_slots(item.rarity):
			over_ceiling += 1
		counts[item.rarity] = int(counts.get(item.rarity, 0)) + 1
		totals[item.rarity] = int(totals.get(item.rarity, 0)) + carried
	equal(over_ceiling, 0, "no item of 2000 carries more effects than its tier allows")

	var previous := 0.0
	var falls := 0
	var measured := 0
	for tier in ItemRarity.TIERS:
		if not counts.has(tier):
			continue
		var mean := float(totals[tier]) / float(counts[tier])
		if measured > 0 and mean < previous - 0.01:
			falls += 1
		previous = mean
		measured += 1
	check(measured >= 5, "the 2000 items covered %d of the six tiers" % measured)
	equal(falls, 0, "and the mean number of effects never falls as the tier rises")

	# Broken: an effect the item spent nothing on is not carried, so the count
	# above is a count of effects and not of slots asked for.
	var nothing := Item.weapon("nothing", 4, ItemRarity.COMMON, Ability.INT,
		ItemBudget.shape(0, 50), ["flame", "frost"], [1, 1])
	equal(nothing.effects.size(), 0,
		"an item with no effects budget carries no effects")
	equal(nothing.effects_power(), 0, "and its effects axis is worth nothing")
	var something := Item.weapon("something", 4, ItemRarity.COMMON, Ability.INT,
		ItemBudget.shape(100, 50), ["flame", "frost"], [1, 1])
	equal([something.movement, something.defence, something.effects_power()],
		[0, 0, 16], "while the same shape with all of it on effects buys 16")
	equal(something.effects_line(), "flame:8|frost:8",
		"divided evenly between the two it named")


# --- The six ability scores ----------------------------------------------


## The vocabulary the gate reads against.
func _the_six_abilities() -> void:
	equal(Ability.ALL, ["str", "con", "cha", "dex", "wis", "int"],
		"the six scores section 2 names, in that order")
	equal(Ability.ALL.size(), 6, "and there are six of them")
	check(Ability.is_ability("wis"), "wisdom is one of them")
	check(not Ability.is_ability("luck"), "luck is not")
	equal(Ability.rank("int"), 5, "and the order is a position, not a guess")


# --- P = r x L ------------------------------------------------------------


## The formula, written out against numbers computed by hand.
func _the_budget_formula() -> void:
	for row in [
		["common", 1, 4], ["common", 8, 32], ["common", 16, 64],
		["uncommon", 8, 48], ["rare", 8, 72], ["legendary", 8, 112],
		["mythic", 8, 168], ["eternal", 8, 256], ["eternal", 40, 1280],
	]:
		equal(ItemBudget.total(row[0], row[1]), row[2],
			"P = r(%s) x %d = %d" % [row[0], row[1], row[2]])

	equal(ItemBudget.total(ItemRarity.MYTHIC, 0), 0,
		"a source with no level leaves nothing to spend")
	equal(ItemBudget.total(ItemRarity.MYTHIC, -5), 0,
		"and neither does one below it")

	# The item's own level is the source level: one number, read by the budget
	# and by the gate, and not two that could drift apart.
	var item := ItemForge.forge(SEED, "formula", 7, Item.KIND_ARMOUR)
	equal(item.level, 7, "the item carries the level of what dropped it")
	equal(item.budget(), ItemRarity.multiplier(item.rarity) * 7,
		"and its budget is that level times its rarity, recomputed from both")


# --- The split ------------------------------------------------------------


## Three amounts summing to the budget exactly, with the rounding rule written
## out against cases worked by hand.
func _the_split_is_exact() -> void:
	# 72 across 30/45/25. Floors are 21, 32, 18 with remainders 60, 40, 0; that
	# is 71 spent, and the one point left goes to the axis rounded down hardest,
	# which is movement.
	equal(ItemBudget.split(72, [30, 45, 25]), [22, 32, 18],
		"72 across 30/45/25 is 22 + 32 + 18, the leftover point to movement")

	# Three equal weights that cannot divide the amount. Every remainder ties, so
	# the tie-break -- the earlier axis -- decides, twice in the second case.
	equal(ItemBudget.split(10, [1, 1, 1]), [4, 3, 3],
		"10 across three equal axes puts the leftover point on the first")
	equal(ItemBudget.split(2, [1, 1, 1]), [1, 1, 0],
		"and 2 across three equal axes fills the first two")

	# Nothing to spend, and nothing asked for.
	equal(ItemBudget.split(0, [30, 45, 25]), [0, 0, 0], "no budget, no axes")
	equal(ItemBudget.split(40, [0, 0, 0]), [40, 0, 0],
		"a shape that asks for nothing still spends the budget, on the first axis")

	# Exhaustive: every budget from 0 to 300 across a set of awkward shapes, and
	# the three parts sum to it every time. This is the acceptance's "spent, not
	# merely referenced", asked of the arithmetic rather than of a sample.
	var shapes := [
		[30, 45, 25], [1, 1, 1], [7, 11, 13], [99, 1, 0], [0, 1, 0],
		[33, 33, 34], [1, 0, 99], [50, 25, 25], [2, 3, 5], [17, 17, 66],
	]
	var drifted := 0
	var negative := 0
	for amount in range(0, 301):
		for shape in shapes:
			var typed: Array[int] = []
			for weight in shape:
				typed.append(weight)
			var parts := ItemBudget.split(amount, typed)
			if ItemBudget.sum(parts) != amount:
				drifted += 1
			for part in parts:
				if part < 0:
					negative += 1
	equal(drifted, 0,
		"over 301 budgets x 10 shapes, every split sums to its budget exactly")
	equal(negative, 0, "and no axis ever came out below zero")


## A caller that asks for an effects share and names no effect still gets the
## whole share, carried as one effect named after the item.
##
## The two cases below are the ones I-10f1e88bbc71 measured on the code before
## this: a legendary level-9 weapon of budget 126 carried 0 of it at weights
## [0, 0, 100] and 25 of it at [10, 10, 80], because `_spend_on_effects` returned
## an empty list the moment it was handed no names, without looking at the amount
## `ItemBudget.split` had already assigned to the effects axis. Neither of the
## two callers the project has today can reach it -- `Armour.worn` always passes
## an effects weight of 0 and `Weapon.held` always passes exactly one name -- so
## these are written against the constructor directly, which is where the next
## caller will arrive.
##
## Of the two fixes the finding named, this is the first: carry one effect worth
## the whole share. The second -- fold the share into defence before the split --
## was not taken, because the weights say how the item is *divided*, and folding
## would answer a different question than the one asked: a [0, 0, 100] shape
## would come back a pure defence item, and the movement-against-defence
## correlation this suite measures at equal budget would be reading shapes nobody
## asked for. Naming the effect after the item is also what `Weapon.held` already
## does with its one name, so the fallback is the existing convention rather than
## a second one.
func _an_effects_share_with_no_name_is_still_spent() -> void:
	var unnamed: Array[String] = []

	# The whole budget to effects, no names. Was 0 of 126.
	var all_effects := Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [0, 0, 100], unnamed)
	equal(all_effects.budget(), 126,
		"a legendary level-9 weapon is worth 14 x 9 = 126")
	equal([all_effects.movement, all_effects.defence, all_effects.effects_power()],
		[0, 0, 126],
		"asked for all of itself as effects and given no name, it carries all 126")
	equal(all_effects.effects_line(), "probe:126",
		"as one effect named after the item")
	check(all_effects.spends_budget(), "and it spends its budget exactly")

	# Most of the budget to effects, no names. Was 25 of 126: mov 13, def 12,
	# and the 101-point effects share lost.
	var mixed := Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [10, 10, 80], unnamed)
	equal([mixed.movement, mixed.defence, mixed.effects_power()], [13, 12, 101],
		"at 10/10/80 with no name the 101-point share is carried, not lost")
	equal(mixed.effects_line(), "probe:101", "again as one effect, again named after the item")
	check(mixed.spends_budget(), "and this one spends its budget exactly too")

	# The control that makes those two claims about the *fallback* and not about
	# the split: the same shape with a name divides the same 101 points.
	var named: Array[String] = ["cut"]
	var with_name := Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [10, 10, 80], named)
	equal([with_name.movement, with_name.defence, with_name.effects_power()],
		[13, 12, 101],
		"a name changes what the effect is called and not what the axes are worth")
	equal(with_name.effects_line(), "cut:101", "and the name given is the name kept")

	# Broken the other way: an effects share of nothing must not invent an
	# effect. If the new branch fired on amount 0 this would carry "probe:0".
	var no_share := Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [50, 50, 0], unnamed)
	equal(no_share.effects.size(), 0,
		"an item that spent nothing on effects lists no effect")
	equal([no_share.movement, no_share.defence], [63, 63],
		"and its 126 points are the two axes it did ask for")
	check(no_share.spends_budget(), "still exact")

	# And an item worth nothing has nothing to carry, named or not.
	var worthless := Item.weapon(
		"probe", 0, ItemRarity.LEGENDARY, Ability.STR, [0, 0, 100], unnamed)
	equal([worthless.budget(), worthless.effects.size()], [0, 0],
		"a level-0 item has no budget and so no unnamed effect either")


## The three axes stay writable, and `sim/item.gd` says who owns the sum when
## they are written.
##
## I-80a1d45e9bcb measured `spends_budget()` going true then false after
## `item.movement += 1000`. That is still what happens -- it is reported here as
## documented, not as impossible. Making the axes read-only would have forced
## edits outside `sim/item.gd` and its two callers: this suite writes an axis on
## purpose below (`_every_forged_item_spends_its_budget`), and so does
## `tools/critic_items_probe.gd`, both to show that `spends_budget()` is a live
## report rather than a constant. A check that cannot break its own premise
## proves nothing, so the fields stay writable and the file states the invariant
## instead.
func _the_axes_are_writable_and_the_file_says_who_owns_the_sum() -> void:
	var item := Item.weapon("edited", 9, ItemRarity.LEGENDARY, Ability.STR,
		[10, 10, 80], ["cut"] as Array[String])
	check(item.spends_budget(), "as built, it spends its budget")
	item.movement += 1000
	check(not item.spends_budget(),
		"and after movement += 1000 it says so: the axes are writable")
	equal(item.budget(), 126, "while the budget itself has not moved")

	# The documentation is the fix here, so it is checked like any other claim:
	# the file has to actually say it.
	var text := _read(ITEM_FILE)
	check(text.contains("That is a guarantee") and text.contains("of the *constructors*, not of the class"),
		"sim/item.gd says exactness is a guarantee of the constructors")
	check(text.contains("owns") and text.contains("keeping the sum"),
		"and that anything writing an axis afterwards owns keeping the sum")


## The rounding rule is not decoration: take it away and points go missing.
func _the_rounding_rule_does_work() -> void:
	# Broken: the same split done with plain floors and no remainder pass. If
	# the rule were doing nothing, this would agree with it everywhere.
	var lost := 0
	var disagreed := 0
	for amount in range(0, 301):
		for shape in [[30, 45, 25], [7, 11, 13], [1, 1, 1], [17, 17, 66]]:
			var typed: Array[int] = []
			for weight in shape:
				typed.append(weight)
			var floors := _floor_only(amount, typed)
			if ItemBudget.sum(floors) < amount:
				lost += 1
			if floors != ItemBudget.split(amount, typed):
				disagreed += 1
	equal(lost, 1073,
		"a plain floor loses points on 1073 of the 1204 splits")
	equal(disagreed, 1073,
		"and disagrees with the rule on exactly those 1073")
	equal(_floor_only(72, [30, 45, 25]), [21, 32, 18],
		"on the worked case a plain floor gives 21 + 32 + 18 = 71, a point short")


## The split as it would be without the remainder pass. Only this suite uses it,
## and only to show what the rule is buying.
@warning_ignore("integer_division")
func _floor_only(amount: int, weights: Array[int]) -> Array[int]:
	var denominator := 0
	for weight in weights:
		denominator += weight
	var parts: Array[int] = []
	for weight in weights:
		parts.append(0 if denominator == 0 else amount * weight / denominator)
	return parts


# --- Every item spends its budget ----------------------------------------


## Sixty forged items, and the three axes sum to P on all sixty.
func _every_forged_item_spends_its_budget() -> void:
	var exact := 0
	var negative := 0
	var seen_rarities := {}
	var seen_kinds := {}
	for index in BUDGET_ITEMS:
		var kind := Item.KIND_ARMOUR if index % 2 == 0 else Item.KIND_WEAPON
		var level := 1 + index % 12
		var item := ItemForge.forge(SEED, "budget#%d" % index, level, kind)
		if item.movement + item.defence + item.effects_power() == item.budget():
			exact += 1
		for axis in item.axes():
			if axis < 0:
				negative += 1
		seen_rarities[item.rarity] = true
		seen_kinds[item.kind] = true
	equal(exact, BUDGET_ITEMS,
		"all %d forged items spend their budget exactly" % BUDGET_ITEMS)
	equal(negative, 0, "and no axis of any of them is below zero")
	equal(seen_kinds.keys().size(), 2,
		"both a weapon and a piece of gear are the same class, and both appear")
	check(seen_rarities.size() >= 4,
		"the sixty cover %d of the six tiers" % seen_rarities.size())

	# Named items, so that "all sixty" is a claim about particular numbers and
	# not only about a count. These are rows 2, 7 and 34 of reports/items.md.
	var row2 := ItemForge.forge(SEED, "budget#2", 3, Item.KIND_ARMOUR)
	equal(row2.line(),
		"rare armour leggings L3 P=27 mov=16 def=6 eff=5 con [blink:5] rare leggings",
		"row 2 of the table is exactly this item")
	var row7 := ItemForge.forge(SEED, "budget#7", 8, Item.KIND_WEAPON)
	equal([row7.rarity, row7.budget(), row7.movement, row7.defence,
		row7.effects_power()], ["rare", 72, 7, 12, 53],
		"row 7 is a rare weapon of 72 spent 7 + 12 + 53")
	var row34 := ItemForge.forge(SEED, "budget#34", 11, Item.KIND_ARMOUR)
	equal([row34.rarity, row34.budget(), row34.movement, row34.defence,
		row34.effects_power()], ["mythic", 231, 5, 157, 69],
		"row 34 is a mythic chestplate of 231 spent 5 + 157 + 69")

	# Broken: an item whose axes are edited behind the budget's back says so.
	check(row7.spends_budget(), "row 7 spends its budget")
	row7.defence += 1
	check(not row7.spends_budget(),
		"and one point added by hand is one point the budget does not cover")

	# The effects axis is itself spent, by the same rule: an item's effects sum
	# to what its effects share bought, with nothing left over.
	var mismatched := 0
	for index in BUDGET_ITEMS:
		var item := ItemForge.forge(SEED, "budget#%d" % index, 1 + index % 12,
			Item.KIND_ARMOUR if index % 2 == 0 else Item.KIND_WEAPON)
		var summed := 0
		for effect in item.effects:
			summed += effect.magnitude
		if summed != item.effects_power():
			mismatched += 1
	equal(mismatched, 0,
		"and each item's individual effects sum to its effects axis")


# --- The trade ------------------------------------------------------------


## At equal budget, the items with the most movement carry the least defence --
## measured here, not read off the generator.
func _movement_and_defence_compete() -> void:
	var worn := ItemForge.batch(
		SEED, "trade-worn", TRADE_LEVEL, Item.KIND_ARMOUR, TRADE_ITEMS)
	var budget := ItemBudget.total(ItemRarity.COMMON, TRADE_LEVEL)
	equal(budget, 32, "the equal budget the trade is measured at is 32")

	var equal_budget: Array[Item] = []
	for item in worn:
		if item.budget() == budget:
			equal_budget.append(item)
	equal(equal_budget.size(), 194,
		"194 of the 400 worn items came out at that budget")

	var r := _correlation(_column(equal_budget, 0), _column(equal_budget, 1))
	check(r < -0.85,
		"at equal budget movement and defence are anti-correlated: r = %.4f" % r)

	# The same measurement as a table: five bands by movement, and the mean
	# defence falls across every one of them.
	var means := _band_means(equal_budget, 5)
	equal(means.size(), 5, "five bands, each with items in it")
	var falling := true
	for index in range(1, means.size()):
		if means[index]["def"] >= means[index - 1]["def"]:
			falling = false
	check(falling, "mean defence falls across every band as mean movement rises")
	check(means[0]["def"] > 20.0,
		"the least mobile band averages %.4f defence" % means[0]["def"])
	check(means[4]["def"] < 6.0,
		"and the most mobile band averages %.4f" % means[4]["def"])
	check(means[0]["mov"] < 3.0 and means[4]["mov"] > 20.0,
		"while their movement runs the other way, %.4f against %.4f"
			% [means[0]["mov"], means[4]["mov"]])

	# Broken: drop the equal-budget filter and the same measurement over the same
	# generator all but vanishes, because a bigger budget lifts both axes at
	# once. So the number above is about the budget being shared and not about
	# the forge preferring one axis to the other.
	var mixed := _correlation(_column(worn, 0), _column(worn, 1))
	check(mixed > -0.3,
		"over mixed budgets the same correlation is only %.4f" % mixed)
	check(r < mixed - 0.5,
		"the equal-budget trade is far stronger than the unfiltered one")

	# And the trade is the arithmetic, not the generator: hand-built items at one
	# budget move exactly opposite each other.
	var mobile := Item.armour("mobile", Item.SLOT_BOOTS, TRADE_LEVEL,
		ItemRarity.COMMON, Ability.DEX, ItemBudget.shape(0, 100))
	var solid := Item.armour("solid", Item.SLOT_BOOTS, TRADE_LEVEL,
		ItemRarity.COMMON, Ability.DEX, ItemBudget.shape(0, 0))
	equal([mobile.movement, mobile.defence], [32, 0],
		"all of a 32-point budget into movement leaves no defence")
	equal([solid.movement, solid.defence], [0, 32],
		"and all of it into defence leaves no movement")
	equal(mobile.budget(), solid.budget(),
		"the two spent the same budget")


## One axis of a set of items, as floats.
func _column(items: Array[Item], axis: int) -> Array[float]:
	var values: Array[float] = []
	for item in items:
		values.append(float(item.axes()[axis]))
	return values


## Pearson correlation, written out here rather than taken from the code under
## test, so the measurement is independent of the thing it measures.
func _correlation(a: Array[float], b: Array[float]) -> float:
	var n := a.size()
	if n < 2 or b.size() != n:
		return 0.0
	var mean_a := 0.0
	var mean_b := 0.0
	for index in n:
		mean_a += a[index]
		mean_b += b[index]
	mean_a /= float(n)
	mean_b /= float(n)
	var cov := 0.0
	var var_a := 0.0
	var var_b := 0.0
	for index in n:
		var da := a[index] - mean_a
		var db := b[index] - mean_b
		cov += da * db
		var_a += da * da
		var_b += db * db
	if var_a <= 0.0 or var_b <= 0.0:
		return 0.0
	return cov / sqrt(var_a * var_b)


## Items sorted by movement, cut into equal bands, with each axis's mean.
func _band_means(items: Array[Item], count: int) -> Array[Dictionary]:
	var sorted := items.duplicate()
	sorted.sort_custom(func(x: Item, y: Item) -> bool:
		if x.movement != y.movement:
			return x.movement < y.movement
		if x.defence != y.defence:
			return x.defence < y.defence
		return x.line() < y.line()
	)
	var out: Array[Dictionary] = []
	for band in count:
		var from := band * sorted.size() / count
		var to := (band + 1) * sorted.size() / count
		if to <= from:
			continue
		var mov := 0.0
		var def := 0.0
		for index in range(from, to):
			mov += float(sorted[index].movement)
			def += float(sorted[index].defence)
		var n := float(to - from)
		out.append({"mov": mov / n, "def": def / n, "n": to - from})
	return out


# --- The gate -------------------------------------------------------------


## `floor(v * min(A, L) / L)`, worked through a level-8 wisdom chestplate.
func _the_ability_gate() -> void:
	var hauberk := Item.armour(
		"warding hauberk", Item.SLOT_CHESTPLATE, 8, ItemRarity.RARE, Ability.WIS,
		ItemBudget.shape(25, 40), ["warding"], [1]
	)
	equal(hauberk.governing, "wis", "the item says which score it is read against")
	equal(hauberk.level, 8, "and it is a level-8 item")
	equal(hauberk.budget(), 72, "its budget is 9 x 8 = 72")
	equal([hauberk.movement, hauberk.defence, hauberk.effects_power()],
		[22, 32, 18], "spent 22 movement, 32 defence, 18 effects")
	equal(hauberk.power(), 72, "which is the budget, to the point")

	# The worked example the acceptance asks for: wisdom 6 against level 8.
	# q = 6/8 = three quarters, floored once per axis.
	equal(hauberk.qualification(6), 75, "a wearer with wisdom 6 reaches 75% of it")
	equal(hauberk.movement_for(6), 16, "floor(22 x 6 / 8) = 16 movement")
	equal(hauberk.defence_for(6), 24, "floor(32 x 6 / 8) = 24 defence")
	equal(hauberk.effects_for(6), 13, "floor(18 x 6 / 8) = 13 effects")
	equal(hauberk.power_for(6), 53, "so the item is worth 53 of its 72 to them")
	check(not hauberk.is_qualified(6), "and they do not reach the whole item")

	# The three axes are floored one at a time, where each is read. That costs at
	# most two points against gating the budget in one go, and the gap is stated
	# here rather than smoothed away.
	equal(Item.realise(72, 6, 8), 54, "the budget gated in one go is 54")
	equal(54 - hauberk.power_for(6), 1,
		"one point more than the three axes gated separately")
	var worst := 0
	for score in range(0, 9):
		worst = maxi(worst, Item.realise(hauberk.budget(), score, 8)
			- hauberk.power_for(score))
	equal(worst, 1, "and across every score the gap never exceeds one point here")

	# Broken: the same item read by a wearer who reaches its level. If the gate
	# did nothing, this would print the numbers above.
	equal(hauberk.qualification(8), 100, "a wearer with wisdom 8 reaches all of it")
	equal([hauberk.movement_for(8), hauberk.defence_for(8), hauberk.effects_for(8)],
		[22, 32, 18], "and reads every axis in full")
	check(hauberk.is_qualified(8), "which is what being qualified means")
	not_equal(hauberk.defence_for(6), hauberk.defence_for(8),
		"if the gate were not applied, the wisdom-6 reading would prove nothing")

	# Above the item's level nothing more is gained: the gate takes value away
	# from the unqualified, it does not hand it to the overqualified.
	equal(hauberk.defence_for(40), 32, "wisdom 40 reads the same 32 as wisdom 8")

	# And it never runs backwards.
	var previous := -1
	var backwards := 0
	for score in range(0, 20):
		var read := hauberk.power_for(score)
		if read < previous:
			backwards += 1
		previous = read
	equal(backwards, 0, "a higher score never reads less off the same item")

	# A wearer with nothing reads nothing off a levelled item.
	equal(hauberk.power_for(0), 0, "wisdom 0 reads nothing off a level-8 item")

	# An item with no level has nothing to fall short of.
	var plain := Item.armour("plain", Item.SLOT_HELMET, 0, ItemRarity.COMMON,
		Ability.WIS, ItemBudget.shape(0, 50))
	equal(plain.budget(), 0, "a level-0 item has no budget")
	equal(plain.qualification(0), 100, "and anyone reaches all of it")

	# The gate is on the reading, never on the item: two wearers read different
	# numbers off one unchanged object.
	equal(hauberk.defence, 32, "the item itself is unchanged by being read")
	equal(hauberk.line(),
		"rare armour chestplate L8 P=72 mov=22 def=32 eff=18 wis [warding:18] warding hauberk",
		"and it describes itself the same way whoever is holding it")


# --- Determinism ----------------------------------------------------------


## The same seed and the same source give the same item; a different source does
## not.
func _the_same_seed_and_source_give_the_same_item() -> void:
	var once := ItemForge.forge(SEED, "goblin-42", 6, Item.KIND_ARMOUR)
	var twice := ItemForge.forge(SEED, "goblin-42", 6, Item.KIND_ARMOUR)
	equal(once.line(), twice.line(),
		"the same seed and source forge the same item, to the byte")

	var elsewhere := ItemForge.forge(SEED + 1, "goblin-42", 6, Item.KIND_ARMOUR)
	var other_source := ItemForge.forge(SEED, "goblin-43", 6, Item.KIND_ARMOUR)
	var differing := 0
	if elsewhere.line() != once.line():
		differing += 1
	if other_source.line() != once.line():
		differing += 1
	equal(differing, 2,
		"another seed and another source both give something else")

	# Forging an item somewhere else cannot shift the numbers this one sees:
	# each is an independent stream addressed by its label, not a position in a
	# shared one.
	var batch := ItemForge.batch(SEED, "wolf", 5, Item.KIND_WEAPON, 8)
	var alone := ItemForge.forge(SEED, "wolf#5", 5, Item.KIND_WEAPON)
	equal(batch[5].line(), alone.line(),
		"the sixth item of a run is the same item forged on its own")


## Two separate processes print the same bytes.
func _two_processes_agree() -> void:
	var first := _run_items()
	var second := _run_items()
	equal(first["exit_code"], 0, "the documented command exits 0")
	equal(second["exit_code"], 0, "and so does a second run of it")
	check(first["output"].length() > 2000,
		"it printed %d characters of tables" % first["output"].length())
	equal(first["output"], second["output"],
		"two separate processes print identical bytes")
	check(first["output"].contains("exact: 60 of 60 items spend their budget"),
		"and what they printed includes the budget claim")

	# Broken: the same comparison against text that is not what it printed fails,
	# so the equality above is a comparison and not a pair of empty strings.
	not_equal(first["output"], "", "the run printed something")
	not_equal(first["output"], first["output"] + "x",
		"and the comparison can tell two different transcripts apart")


## Run the documented command in its own process, and capture what it printed.
func _run_items() -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/items_main.gd",
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


# --- The layer's own shape ------------------------------------------------


## Three structural claims, all checked by reading `sim/` rather than by trusting
## the arrangement, and all with the files found by opening the directory.
##
##   * the item layer names no class of the combat layer at all, so it can be
##     read, tested and changed on its own and cannot quietly start deciding what
##     a blow is worth.
##   * **the naming goes one way, and only one way.** The two layers do meet now:
##     `sim/armour.gd`, `sim/weapon.gd` and `sim/commander.gd` read a budget, a
##     gate and a rarity off the item layer, which is what makes a loadout change
##     what a commander may do. The claim that survives that meeting is the
##     direction of it -- the fight reads items, items never read the fight -- and
##     it is checked here by requiring at least one combat file to name an item
##     class while no item file names a combat one. A rule with nothing on either
##     side of it is not a rule, so both sides are asserted.
##   * exactly two files of the item layer draw a random number, and they are the
##     two places where chance is the point: the forge, which decides what an
##     item is, and the drop, which decides whether a carried one falls. An
##     item's budget, its split, its gate, its description and the frontier's
##     arithmetic draw nothing; if any of them could, "the same seed gives the
##     same item" would be a property of how often they were called.
# Whether a reader is one of the two excused from the fight-reads-items
# direction, and checked against a narrower rule instead.
func _is_excused(path: String) -> bool:
	for row in NOT_A_FIGHT:
		if String(row["path"]) == path:
			return true
	return false


func _the_layer_stands_on_its_own() -> void:
	var sources := _sim_sources()
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())

	var item_files := PackedStringArray()
	var readers := PackedStringArray()
	for path in sources:
		var text := _read(path)
		if _declares_item_class(text):
			item_files.append(path)
		elif _names_item_class(text):
			readers.append(path)
	equal(item_files, PackedStringArray([
		"res://sim/ability.gd", "res://sim/item.gd", "res://sim/item_budget.gd",
		"res://sim/item_drop.gd", "res://sim/item_effect.gd",
		"res://sim/item_forge.gd", "res://sim/item_frontier.gd",
		"res://sim/item_rarity.gd",
	]), "the item layer is these eight files, found by opening sim/")

	var combat := PackedStringArray()
	for path in item_files:
		var hit := LayerCheck.first_combat_match(_read(path))
		if hit != "":
			combat.append("%s -> %s" % [path, hit])
	equal(combat, PackedStringArray(),
		"no file of the item layer names a class of the combat layer")

	# The other side of the same rule: the fight does read items, and that is
	# where the two layers are allowed to meet. Naming the readers rather than
	# counting them, so that a file quietly dropping the item layer shows up here.
	# The action surface joined them: `sim/action_engine.gd` reads an ability to
	# work out how far a jump reaches and whether an interact's item is up to its
	# task, and `sim/scripted_actions.gd` forges the items a walkthrough carries.
	# `sim/scripted_loop.gd` joined them the same way, for the same reason: the
	# control loop's own walkthrough forges a hatchet to be picked up and a spear
	# to be struck with. `sim/scripted_scenario.gd` is the fourth of the same
	# kind: the end-to-end run forges a lantern to be picked up, a cloak to be
	# traded for and the two weapons its quarrel is fought with.
	# `sim/scripted_skirmish.gd` is the fifth: the second action-surface run
	# forges the three weapons its patrol and its stranger fight with.
	# `sim/scripted_turn.gd` is the sixth: the turn/action seam's duel forges the
	# two spears whose blows the rule is about. `sim/scripted_encounter.gd` is the
	# seventh and joined for a different reason: it names an ability to *roll* its
	# three commanders' six scores, not to forge anything -- the scores an item's
	# gate is read against are named in the same vocabulary the item names.
	# `sim/scripted_check.gd` is the eighth, and the same kind again: the
	# difficulty-class run forges the two tools its attempts are made with.
	# `sim/scripted_world.gd` is the ninth: the orchestrator run forges the
	# lantern and the rope its one written-down character carries about.
	# `sim/world_cast.gd` is the tenth and is `sim/scripted_encounter.gd`'s kind:
	# it names an ability to roll the six scores of the handful of characters who
	# live in an ordinary world, and forges nothing at all.
	equal(readers, PackedStringArray([
		"res://sim/action_engine.gd", "res://sim/armour.gd", "res://sim/character.gd",
		"res://sim/check_prompt.gd", "res://sim/commander.gd",
		"res://sim/inventory.gd",
		"res://sim/scripted_actions.gd", "res://sim/scripted_check.gd",
		"res://sim/scripted_encounter.gd",
		"res://sim/scripted_loop.gd", "res://sim/scripted_match.gd",
		"res://sim/scripted_scenario.gd", "res://sim/scripted_skirmish.gd",
		"res://sim/scripted_turn.gd", "res://sim/scripted_world.gd",
		"res://sim/spawn_roll.gd", "res://sim/weapon.gd",
		"res://sim/world_cast.gd",
	]), "and these files are the ones that read the item layer")
	for path in readers:
		if _is_excused(path):
			continue
		check(LayerCheck.first_combat_match(_read(path)) != "",
			"%s is a combat file, so the naming runs fight -> items" % path)

	# The readers that are not part of a fight, each excused for a reason that is
	# checked rather than stated. The direction claim they have to keep is
	# narrower and is asserted here: each names what `NOT_A_FIGHT` lists for it
	# and nothing else of the item layer, so no rule about items can have moved
	# into either of them.
	for row in NOT_A_FIGHT:
		var path := String(row["path"])
		var allowed := PackedStringArray(row["may_name"])
		check(readers.has(path), "%s no longer reads the item layer" % path)
		equal(LayerCheck.first_combat_match(_read(path)), "",
			"%s has become a fight file, so it does not need excusing" % path)
		var named := PackedStringArray()
		for word in ITEM_CLASSES:
			if not allowed.has(word) and LayerCheck._contains_word(_read(path), word):
				named.append(word)
		equal(named, PackedStringArray(),
			"%s names more of the item layer than %s: %s" % [
				path, " ".join(allowed), " ".join(named),
			])

	var drawing := PackedStringArray()
	for path in item_files:
		var text := _read(path)
		for word in RANDOM_SOURCES:
			if text.contains(word):
				drawing.append(path)
				break
	equal(drawing, PackedStringArray([
		"res://sim/item_drop.gd", "res://sim/item_forge.gd",
	]), "exactly two files of the item layer draw a random number")

	# Broken: the same scan for a string that is in every one of those files
	# finds it in every one of them, so the two empty and single results above
	# mean "not there" and not "the scan read nothing".
	var present := PackedStringArray()
	for path in item_files:
		if _read(path).contains("func "):
			present.append(path)
	equal(present.size(), item_files.size(),
		"the same scan over a string that is there finds it in every file")
	check(_read("res://sim/item_forge.gd").contains("SimRng"),
		"and the forge does name the project's own generator")


## Every source file directly under sim/, found by opening the directory.
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


## Whether a source names any class of the item layer, whole words only.
func _names_item_class(text: String) -> bool:
	for word in ITEM_CLASSES:
		if LayerCheck._contains_word(text, word):
			return true
	return false


## Whether a source *is* one of the item layer's files: it declares one of the
## layer's class names as its own. Mentioning one is a different thing, and the
## difference is the whole of the direction claim above.
func _declares_item_class(text: String) -> bool:
	for word in ITEM_CLASSES:
		if text.contains("class_name %s\n" % word):
			return true
	return false


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
