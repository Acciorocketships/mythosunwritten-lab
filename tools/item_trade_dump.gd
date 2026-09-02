extends SceneTree
## Dump the individual items behind the movement-against-defence figure.
##
##   ./tools/item_trade_dump.sh > reports/assets/item-trade.csv
##
## Same seed and same batches as `bin/items_main.gd`'s trade table, so the
## correlations printed by ./run_items.sh are the correlations of these rows.
## One row per item: kind, movement, defence, effects, budget. Filtering to
## budget 32 gives the equal-budget subset that table reports.

const SEED := 1234
const TRADE_ITEMS := 400
const TRADE_LEVEL := 8


func _initialize() -> void:
	var budget := ItemBudget.total(ItemRarity.COMMON, TRADE_LEVEL)
	print("kind,movement,defence,effects,budget")
	_dump("worn", ItemForge.batch(SEED, "trade-worn", TRADE_LEVEL, Item.KIND_ARMOUR, TRADE_ITEMS), budget)
	_dump("held", ItemForge.batch(SEED, "trade-hand", TRADE_LEVEL, Item.KIND_WEAPON, TRADE_ITEMS), budget)
	quit(0)


func _dump(label: String, items: Array[Item], budget: int) -> void:
	for item in items:
		print("%s,%d,%d,%d,%d" % [
			label, item.movement, item.defence, item.effects_power(), item.budget(),
		])
