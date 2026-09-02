extends SceneTree
## The two measured cases of I-10f1e88bbc71, the mutability case of
## I-80a1d45e9bcb, and the sweep that must stay exact around them.
##
## Reports, never asserts: it prints the gap it measures so the same script run
## before and after the change shows the change.
##
##   A -- the two B2 cases: a non-empty effects share with no effect names
##   B -- the sweep: 20,000 items, all six tiers, levels 0-39
##   C -- the hostile-weight cases the review tried
##   D -- writing an axis after construction
##
## Run:  tools/godot/godot4 --headless --path . --script res://tools/item_budget_hole_probe.gd

## The review's own sweep, reproduced: 40 levels x 250 sources x 2 kinds.
const SWEEP_LEVELS := 40
const SWEEP_PER_LEVEL := 250


func _initialize() -> void:
	_case_a()
	_case_b()
	_case_c()
	_case_d()
	quit(0)


func _rule(title: String) -> void:
	print("")
	print("=== %s" % title)


func _report(label: String, item: Item) -> void:
	print("  %-46s budget=%d carries=%d gap=%d  mov=%d def=%d eff=%d  eff=[%s]" % [
		label, item.budget(), item.power(), item.budget() - item.power(),
		item.movement, item.defence, item.effects_power(), item.effects_line(),
	])


# --- A: a non-empty effects share with no effect names --------------------


func _case_a() -> void:
	_rule("A -- legendary level-9 weapon, no effect names (I-10f1e88bbc71 B2)")
	var no_names: Array[String] = []
	var all_effects := Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [0, 0, 100], no_names
	)
	_report("weights [0, 0, 100], no names", all_effects)
	var mixed := Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [10, 10, 80], no_names
	)
	_report("weights [10, 10, 80], no names", mixed)

	# The control: the same shape WITH a name is what the review found exact.
	var named: Array[String] = ["cut"]
	_report("weights [10, 10, 80], one name", Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [10, 10, 80], named
	))

	# A zero effects share has nothing to lose, named or not.
	_report("weights [50, 50, 0], no names", Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [50, 50, 0], no_names
	))
	# And an item worth nothing at all cannot lose anything either.
	_report("level 0, weights [0, 0, 100], no names", Item.weapon(
		"probe", 0, ItemRarity.LEGENDARY, Ability.STR, [0, 0, 100], no_names
	))


# --- B: the sweep ---------------------------------------------------------


func _case_b() -> void:
	_rule("B -- the review's sweep: levels 0-%d, both kinds" % [SWEEP_LEVELS - 1])
	var count := 0
	var worst := 0
	var inexact := 0
	var tiers := {}
	for level in SWEEP_LEVELS:
		for index in SWEEP_PER_LEVEL:
			for kind in [Item.KIND_WEAPON, Item.KIND_ARMOUR]:
				var item := ItemForge.forge(
					20250829, "probe-%d-%d" % [level, index], level, kind
				)
				count += 1
				tiers[item.rarity] = true
				var gap: int = absi(item.budget() - item.power())
				worst = maxi(worst, gap)
				if gap != 0:
					inexact += 1
	print("  %d items forged over %d tiers, %d inexact, worst |gap| = %d" % [
		count, tiers.size(), inexact, worst])


# --- C: hostile weights ---------------------------------------------------


func _case_c() -> void:
	_rule("C -- hostile shapes")
	var none: Array[String] = []
	var five: Array[String] = ["a", "b", "c", "d", "e"]
	var no_weights: Array[int] = []
	_report("all-negative weights", Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [-5, -5, -5], none))
	_report("all-zero weights", Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [0, 0, 0], none))
	_report("one enormous weight", Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [0, 999999, 1], none))
	_report("five names, no weights", Item.weapon(
		"probe", 9, ItemRarity.LEGENDARY, Ability.STR, [0, 0, 100], five, no_weights))
	_report("unknown rarity", Item.weapon(
		"probe", 9, "godlike", Ability.STR, [0, 0, 100], none))
	_report("negative level", Item.weapon(
		"probe", -9, ItemRarity.ETERNAL, Ability.STR, [0, 0, 100], none))
	var worn := Armour.worn(Item.SLOT_CHESTPLATE, 9, ItemRarity.LEGENDARY, 100000)
	_report("Armour.worn spending 100000 on moving", worn.item)
	var held := Weapon.held(Weapon.sword(), 9, ItemRarity.LEGENDARY, 100000, 100000)
	_report("Weapon.held spending 100000 twice", held.item)


# --- D: writing an axis after construction --------------------------------


func _case_d() -> void:
	_rule("D -- writing an axis after construction (I-80a1d45e9bcb B6)")
	var item := ItemForge.forge(20250829, "mutable", 9, Item.KIND_WEAPON)
	print("  before: spends_budget=%s  budget=%d power=%d" % [
		item.spends_budget(), item.budget(), item.power()])
	item.movement += 1000
	print("  after movement += 1000: spends_budget=%s  budget=%d power=%d" % [
		item.spends_budget(), item.budget(), item.power()])
