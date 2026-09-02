extends SceneTree
## Print everything the item layer claims about itself, as numbers.
##
## Run it with:  ./run_items.sh
##
## No window, no renderer, no world generation. Every table below is computed
## from `sim/item_forge.gd` and `sim/item_budget.gd` alone, from the fixed seed
## written into this file, so two runs of this command print identical bytes --
## which is what tests/test_items.gd checks by running it twice as a subprocess.

## The seed every table is forged from.
const SEED := 1234

## How many items the budget table walks. Section 4's split has to hold for all
## of them, not for a sample of them.
const BUDGET_ITEMS := 60

## How many items the trade-off is measured over, before the equal-budget filter.
const TRADE_ITEMS := 400

## The source level the trade-off is measured at.
const TRADE_LEVEL := 8


func _initialize() -> void:
	_rarity_table()
	_budget_table()
	_trade_table()
	_gate_table()
	quit(0)


# --- What a tier is worth -------------------------------------------------


func _rarity_table() -> void:
	print("# rarity multipliers")
	print("tier         r    P at L=8")
	for tier in ItemRarity.TIERS:
		print("%-12s %-4d %d" % [
			tier, ItemRarity.multiplier(tier), ItemBudget.total(tier, 8),
		])
	print("")


# --- The budget is spent, not referenced ----------------------------------


func _budget_table() -> void:
	print("# %d forged items: does movement + defence + effects equal P" % BUDGET_ITEMS)
	print("  #  rarity       kind    slot        L    P  mov  def  eff  sum  P-sum")
	var exact := 0
	for index in BUDGET_ITEMS:
		var kind := Item.KIND_ARMOUR if index % 2 == 0 else Item.KIND_WEAPON
		var level := 1 + index % 12
		var item := ItemForge.forge(SEED, "budget#%d" % index, level, kind)
		var sum := item.power()
		if sum == item.budget():
			exact += 1
		print("%3d  %-12s %-7s %-10s %2d %4d %4d %4d %4d %4d %6d" % [
			index, item.rarity, item.kind, item.slot, item.level, item.budget(),
			item.movement, item.defence, item.effects_power(), sum,
			item.budget() - sum,
		])
	print("exact: %d of %d items spend their budget to the point" % [exact, BUDGET_ITEMS])
	print("")


# --- Movement and defence compete -----------------------------------------


func _trade_table() -> void:
	print("# the movement-against-defence trade, measured over forged items")
	var worn := ItemForge.batch(SEED, "trade-worn", TRADE_LEVEL, Item.KIND_ARMOUR, TRADE_ITEMS)
	var held := ItemForge.batch(SEED, "trade-hand", TRADE_LEVEL, Item.KIND_WEAPON, TRADE_ITEMS)

	var budget := ItemBudget.total(ItemRarity.COMMON, TRADE_LEVEL)
	var worn_equal := _at_budget(worn, budget)
	var held_equal := _at_budget(held, budget)

	print("all %d worn items, budgets mixed:      n=%d  r(mov,def)=%s" % [
		TRADE_ITEMS, worn.size(), _fmt(_correlation(_column(worn, 0), _column(worn, 1))),
	])
	print("worn items at P=%d (common, L=%d):     n=%d  r(mov,def)=%s" % [
		budget, TRADE_LEVEL, worn_equal.size(),
		_fmt(_correlation(_column(worn_equal, 0), _column(worn_equal, 1))),
	])
	print("held items at P=%d (common, L=%d):     n=%d  r(mov,def)=%s" % [
		budget, TRADE_LEVEL, held_equal.size(),
		_fmt(_correlation(_column(held_equal, 0), _column(held_equal, 1))),
	])
	print("")
	print("worn items at P=%d, in five bands by movement:" % budget)
	print("band  n   mov range   mean mov   mean def   mean eff")
	for band in _bands(worn_equal, 5):
		print("%4d %3d   %2d..%-2d      %8s   %8s   %8s" % [
			band["band"], band["n"], band["low"], band["high"],
			_fmt(band["mov"]), _fmt(band["def"]), _fmt(band["eff"]),
		])
	print("")


## The items whose budget is exactly `budget`.
func _at_budget(items: Array[Item], budget: int) -> Array[Item]:
	var kept: Array[Item] = []
	for item in items:
		if item.budget() == budget:
			kept.append(item)
	return kept


## One axis of a set of items, as floats.
func _column(items: Array[Item], axis: int) -> Array[float]:
	var values: Array[float] = []
	for item in items:
		values.append(float(item.axes()[axis]))
	return values


## Pearson correlation. Returns 0 for a column with no spread, which is a real
## answer and not a failure: two axes cannot covary if one of them never moves.
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


## Items sorted by movement and cut into equal bands, with the mean of each axis
## in each band. Sorting is by movement then defence then the item's whole line,
## so the order is total and two runs cut the same items into the same bands.
func _bands(items: Array[Item], count: int) -> Array[Dictionary]:
	var sorted := items.duplicate()
	sorted.sort_custom(func(x: Item, y: Item) -> bool:
		if x.movement != y.movement:
			return x.movement < y.movement
		if x.defence != y.defence:
			return x.defence < y.defence
		return x.line() < y.line()
	)
	var out: Array[Dictionary] = []
	if sorted.is_empty():
		return out
	for band in count:
		var from := band * sorted.size() / count
		var to := (band + 1) * sorted.size() / count
		if to <= from:
			continue
		var mov := 0.0
		var def := 0.0
		var eff := 0.0
		for index in range(from, to):
			mov += float(sorted[index].movement)
			def += float(sorted[index].defence)
			eff += float(sorted[index].effects_power())
		var n := float(to - from)
		out.append({
			"band": band, "n": to - from,
			"low": sorted[from].movement, "high": sorted[to - 1].movement,
			"mov": mov / n, "def": def / n, "eff": eff / n,
		})
	return out


# --- The ability-score gate -----------------------------------------------


func _gate_table() -> void:
	print("# the ability-score gate, worked through one item")
	var item := Item.armour(
		"warding hauberk", Item.SLOT_CHESTPLATE, 8, ItemRarity.RARE, Ability.WIS,
		ItemBudget.shape(25, 40), ["warding"], [1]
	)
	print(item.line())
	print("budget P = r(%s) x L = %d x %d = %d, spent %d + %d + %d = %d" % [
		item.rarity, ItemRarity.multiplier(item.rarity), item.level, item.budget(),
		item.movement, item.defence, item.effects_power(), item.power(),
	])
	print("")
	print(" wis   q=min(A,L)/L   mov   def   eff   sum   floor(P*q)")
	for score in range(0, 13):
		print("%4d   %10s%%   %3d   %3d   %3d   %3d   %10d" % [
			score, item.qualification(score),
			item.movement_for(score), item.defence_for(score),
			item.effects_for(score), item.power_for(score),
			Item.realise(item.budget(), score, item.level),
		])
	print("")


## A float printed to four places, so two processes print the same bytes.
func _fmt(value: Variant) -> String:
	return "%.4f" % float(value)
