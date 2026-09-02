extends SceneTree
## Print what a loadout is worth on a board, headless. Nothing else.
##
## Run it with:  ./run_loadout.sh
##
## Every number below is read off `sim/` -- an item's power budget, the price of
## a movement grant in cells, the conversion from defence points to reduction,
## and the ability-score gate -- against a board typed out here. Nothing draws a
## random number and nothing reads a clock, so two runs print the same bytes.

## The board the worked examples stand on: the piece suite's own fixture, so the
## cells a loadout is stopped by are the ones that suite already writes out.
##
##   `#` a building   `~` a hole   `^` earth too high to climb   `,` a step down
const MAP := [
	".............",
	"~~~~~~~~~~~~~",
	".............",
	".............",
	"....#...~....",
	".............",
	".............",
	".............",
	"....^...,....",
	".............",
	".............",
	".............",
	".............",
]

## Where the commander stands in every board below.
const MIDDLE := Vector2i(6, 6)

## The levels the tables are worked at. One below the first grant's price, the
## three at which each grant becomes affordable, and two far up the gradient.
const LEVELS := [1, 2, 3, 4, 8, 20, 40]


func _initialize() -> void:
	_price_list()
	_the_boards()
	_the_ladder()
	_the_trade()
	_the_duel()
	_the_gate()
	quit(0)


# --- The price list -------------------------------------------------------


func _price_list() -> void:
	print("price list -- one point of an item's movement axis buys one cell")
	print("  slot        pattern                cells  price")
	_priced("boots", "4 diagonal offsets", PieceGeometry.DIAGONALS.size(), 1)
	_priced("leggings", "8 knight hops", PieceGeometry.KNIGHT_HOPS.size(), 1)
	_priced("chestplate", "8 directions x 1", PieceGeometry.ALL_DIRECTIONS.size(), 1)
	_priced("chestplate", "8 directions x 2", PieceGeometry.ALL_DIRECTIONS.size(), 2)
	print("  helmet      none at any price          -      -")
	print("  defence     %d points buy 1 of reduction" % Armour.POINTS_PER_DEFENCE)
	print("")


func _priced(slot: String, pattern: String, covers: int, reach: int) -> void:
	print("  %-11s %-22s %5d %6d" % [
		slot, pattern, covers * reach, Armour.price(covers, reach),
	])


# --- The worked boards ----------------------------------------------------


## One board per loadout, with every cell the commander may move to marked.
func _the_boards() -> void:
	var cases := [
		{"name": "bare: one cardinal step", "worn": []},
		{"name": "boots: the diagonal too, which is a king", "worn": [Armour.boots()]},
		{"name": "leggings: the knight's hop", "worn": [Armour.leggings()]},
		{"name": "chestplate at 8 points: a king-like slide of one cell",
			"worn": [Armour.chestplate(2)]},
		{"name": "chestplate at 16 points: the two-cell queen",
			"worn": [Armour.chestplate(4)]},
		{"name": "all three: the union, and no piece in chess",
			"worn": [Armour.boots(), Armour.leggings(), Armour.chestplate()]},
	]
	for one in cases:
		var pieces := PieceMap.new()
		var commander := Commander.make(MIDDLE)
		for piece in one["worn"]:
			commander.equip(piece)
		pieces.add(commander)
		var board := BoardSketch.from_rows(PackedStringArray(MAP))
		var reached := LegalMoves.destinations(board, pieces, commander)
		print("loadout %s" % one["name"])
		print("  %s" % _loadout_text(commander))
		print("  reaches %d cells" % reached.size())
		for line in _picture(reached):
			print("  %s" % line)
		print("")


## The board as a picture, with `C` for the commander and `o` for a cell it may
## move to. Everything else is the map's own glyph.
func _picture(reached: Array[Vector2i]) -> PackedStringArray:
	var marked := {}
	for cell in reached:
		marked[cell] = true
	var drawn := PackedStringArray()
	for y in MAP.size():
		var row := PackedStringArray()
		for x in str(MAP[y]).length():
			var at := Vector2i(x, y)
			if at == MIDDLE:
				row.append("C")
			elif marked.has(at):
				row.append("o")
			else:
				row.append(str(MAP[y])[x])
		row.append("")
		drawn.append(" ".join(row).strip_edges())
	return drawn


func _loadout_text(commander: Commander) -> String:
	return "%s [def %d]" % [commander.loadout_line(), commander.defence()]


# --- The chestplate ladder ------------------------------------------------


## What one slot's budget buys, level by level. The chestplate, because it is the
## slot whose grant has more than one size.
func _the_ladder() -> void:
	print("a chestplate off a common creature, level by level")
	print("  level  budget  movement  defence  reach")
	for level in LEVELS:
		var plate := Armour.chestplate(level)
		var score := plate.item.level
		print("  %5d %7d %9d %8d %6d" % [
			level, plate.item.budget(), plate.movement_for(score),
			plate.defence_for(score), plate.reach_for(score),
		])
	print("")


# --- The trade ------------------------------------------------------------


## Two commanders at one level, carrying four items each off creatures of that
## level -- the same budget -- one spending on every grant it can and the other on
## none. What each reaches, and what each survives.
func _the_trade() -> void:
	print("the same budget, spent two ways (four worn items, common, level 4)")
	print("  build      budget  def  cells  cut  blows  cleave  blows")
	var sword := Weapon.held(Weapon.sword(), 4)
	for one in [
		{"name": "mobile", "moving": -1},
		{"name": "armoured", "moving": 0},
	]:
		var pieces := PieceMap.new()
		var commander := Commander.make(MIDDLE, PieceGeometry.NORTH, AssetTags.KNIGHT, 4)
		var budget := 0
		for slot in Armour.SLOTS:
			var piece := Armour.worn(slot, 4, ItemRarity.COMMON, int(one["moving"]))
			budget += piece.item.budget()
			commander.equip(piece)
		pieces.add(commander)
		var board := BoardSketch.from_rows(PackedStringArray(MAP))
		var cut := Damage.resolve(sword.damage_of(0, 4), Damage.NONE, commander.defence())
		var cleave := Damage.resolve(sword.damage_of(1, 4), Damage.NONE, commander.defence())
		print("  %-10s %6d %4d %6d %4d %6d %7d %6d" % [
			one["name"], budget, commander.defence(),
			LegalMoves.destinations(board, pieces, commander).size(),
			cut, _blows(commander.max_health(), cut),
			cleave, _blows(commander.max_health(), cleave),
		])
	print("")


# --- The duel -------------------------------------------------------------


## A front-on duel between equals, level by level: both carrying four worn items
## and a sword off creatures of their own level. What a cut is worth from each of
## the four positions, and how many of them a commander survives.
func _the_duel() -> void:
	print("two equals at each level: four common worn items and a common sword")
	print("  level  health  def  cut  front  blows  flank  back  back+high  blows")
	for level in LEVELS:
		var commander := Commander.make(MIDDLE, PieceGeometry.NORTH, AssetTags.KNIGHT, level)
		for slot in Armour.SLOTS:
			commander.equip(Armour.worn(slot, level))
		var sword := Weapon.held(Weapon.sword(), level)
		var cut := sword.damage_of(0, level)
		var armour := commander.defence()
		var best := Damage.BACK * Damage.HIGH_GROUND / Damage.NONE
		var front := Damage.resolve(cut, Damage.NONE, armour)
		var hardest := Damage.resolve(cut, best, armour)
		print("  %5d %7d %4d %4d %6d %6d %6d %5d %10d %6d" % [
			level, commander.max_health(), armour, cut,
			front, _blows(commander.max_health(), front),
			Damage.resolve(cut, Damage.FLANK, armour),
			Damage.resolve(cut, Damage.BACK, armour),
			hardest, _blows(commander.max_health(), hardest),
		])
	print("")


# --- The gate -------------------------------------------------------------


## One suit and one sword off level-8 creatures, read by wearers of six different
## ability scores. The objects are the same objects throughout.
func _the_gate() -> void:
	print("one level-8 loadout, read by six wearers")
	print("  score  reach  fraction  def  cut  cleave  cells")
	var pieces := PieceMap.new()
	var commander := Commander.make(MIDDLE, PieceGeometry.NORTH, AssetTags.KNIGHT, 8)
	for slot in Armour.SLOTS:
		commander.equip(Armour.worn(slot, 8))
	commander.wield(Weapon.held(Weapon.sword(), 8))
	pieces.add(commander)
	var board := BoardSketch.from_rows(PackedStringArray(MAP))
	var plate := commander.worn_in(Armour.CHESTPLATE)
	for score in [8, 6, 4, 3, 2, 0]:
		for ability in Ability.ALL:
			commander.set_score(ability, score)
		print("  %5d %6d %8s %4d %4d %7d %6d" % [
			score, plate.reach_for(score), "%d%%" % plate.item.qualification(score),
			commander.defence(), commander.damage_of(0), commander.damage_of(1),
			LegalMoves.destinations(board, pieces, commander).size(),
		])
	print("")
	print("the items themselves, unchanged by any of that:")
	for piece in commander.armour:
		print("  %s" % piece.item.line())
	print("  %s" % commander.weapon.item.line())


func _blows(health: int, dealt: int) -> int:
	return int(ceil(float(health) / float(maxi(1, dealt))))
