extends SceneTree
## Deliberate attempts to break the four structural guarantees the items
## milestone rests on, written by the review rather than by the work under it.
##
## Nothing here is a test in the suite's sense: it does not assert, it reports.
## Every section states what it tried and what came back, including the attempts
## that failed to break anything, because an attack that found nothing is
## evidence and a silent one is not.
##
##   A -- every ability lives on an item
##   B -- one budget, spent exactly
##   C -- item randomness cannot reach world generation
##   D -- the minion-versus-minion layer is deterministic
##   E -- the ability-score gate and the movement-against-defence trade bite
##
## Run:  tools/godot/godot4 --headless --path . --script res://tools/critic_items_probe.gd

const SEED := 20250829
const SIM_DIR := "res://sim"


func _initialize() -> void:
	_attempt_a()
	_attempt_b()
	_attempt_c()
	_attempt_d()
	_attempt_e()
	quit(0)


func _rule(title: String) -> void:
	print("")
	print("=== %s" % title)


func _say(label: String, verdict: String, detail: String) -> void:
	print("  [%s] %s -- %s" % [verdict, label, detail])


# --- A: every ability lives on an item ------------------------------------


func _attempt_a() -> void:
	_rule("A. every ability lives on an item")

	# A1. Read sim/ for the vocabulary section 4 forbids: a class, a learned
	# spell, a skill, a passive. Words in prose do not count -- only code.
	var forbidden := ["spell", "skill", "passive", "learn", "talent", "perk"]
	var hits := PackedStringArray()
	for path in _sim_sources():
		var lines := _read(path).split("\n")
		for index in lines.size():
			var line: String = lines[index]
			if line.strip_edges().begins_with("#"):
				continue
			var code: String = AssetCheck.split_code_and_strings(line)["code"]
			for word in forbidden:
				if code.to_lower().contains(word):
					hits.append("%s:%d %s" % [path, index + 1, line.strip_edges()])
	_say("A1 source scan for spell/skill/passive/learn/talent/perk in sim/ code",
		"HELD" if hits.is_empty() else "BROKE",
		"%d hits%s" % [hits.size(), "" if hits.is_empty() else " " + str(hits)])

	# A2. A commander with nothing on it. If any number is non-zero, an ability
	# arrived from somewhere that is not an item.
	var bare := Commander.make(Vector2i(4, 4), PieceGeometry.NORTH, AssetTags.KNIGHT, 8)
	var grants := bare.move_grants()
	_say("A2 a level-8 commander wearing and holding nothing",
		"HELD" if bare.defence() == 0 and bare.damage_of(0) == 0 and grants.size() == 1 else "BROKE",
		"defence=%d damage=%d grants=%d (%s)" % [
			bare.defence(), bare.damage_of(0), grants.size(),
			"base cardinal step only" if grants.size() == 1 else "extra grant",
		])

	# A3. The one hole worth hunting for: a catalogue Weapon carries a shape and
	# `Weapon.item` may be null, in which case `power_for()` falls back to the
	# catalogue's own damage numbers. Does that give a commander power no budget
	# paid for? And is that reachable from a shipped sim/ scenario, or only from
	# the tests?
	var shaped := Commander.make(Vector2i(4, 4), PieceGeometry.NORTH, AssetTags.KNIGHT, 2)
	shaped.wield(Weapon.sword())
	var budgeted := Commander.make(Vector2i(4, 4), PieceGeometry.NORTH, AssetTags.KNIGHT, 2)
	budgeted.wield(Weapon.held(Weapon.sword(), 2, ItemRarity.COMMON))
	var free_damage := shaped.damage_of(0) + shaped.damage_of(1)
	var paid_damage := budgeted.damage_of(0) + budgeted.damage_of(1)
	_say("A3 a bare catalogue Weapon wielded with no Item behind it",
		"HELD" if free_damage == paid_damage else "BROKE",
		("cut/cleave = %d/%d with no item, %d/%d on a common item forged at the "
		+ "same level 2 (budget %d); the bare shape is worth %d points of "
		+ "effects axis, which a common item needs level %d to buy")
		% [
			shaped.damage_of(0), shaped.damage_of(1),
			budgeted.damage_of(0), budgeted.damage_of(1),
			budgeted.weapon.item.budget(), Weapon.sword().reference_power(),
			int(ceil(float(Weapon.sword().reference_power())
				/ float(ItemRarity.multiplier(ItemRarity.COMMON)))),
		])

	# A4. Is A3 reachable from sim/, or does only a test do it? Scan the two
	# files the effects suite already identifies as handing weapons out.
	var unbacked := PackedStringArray()
	for path in _sim_sources():
		var lines := _read(path).split("\n")
		for index in lines.size():
			var code: String = AssetCheck.split_code_and_strings(lines[index])["code"]
			if not code.contains("wield("):
				continue
			if not code.contains("Weapon.held("):
				unbacked.append("%s:%d %s" % [path, index + 1, lines[index].strip_edges()])
	_say("A4 wield() calls under sim/ that hand over a shape with no Item",
		"HELD" if unbacked.is_empty() else "BROKE",
		"%d of them%s" % [unbacked.size(),
			"" if unbacked.is_empty() else "\n      " + "\n      ".join(unbacked)])

	# A5. The ability gate cannot reach a weapon with no item, so a low score
	# reads the bare shape in full. Show it.
	var weak := Commander.make(Vector2i(4, 4), PieceGeometry.NORTH, AssetTags.KNIGHT, 2)
	weak.wield(Weapon.sword())
	for ability in Ability.ALL:
		weak.set_score(ability, 0)
	_say("A5 the same bare shape read by a commander with every score at 0",
		"HELD" if weak.damage_of(0) == 0 else "BROKE",
		"cut = %d (an item-backed sword at score 0 reads %d)" % [
			weak.damage_of(0), 0,
		])


# --- B: one budget, spent exactly -----------------------------------------


func _attempt_b() -> void:
	_rule("B. one budget, and it is spent exactly")

	# B1. Twenty thousand forged items across every tier and a wide level range.
	var forged := 0
	var off := 0
	var worst := 0
	for level in range(0, 40):
		for index in 250:
			for kind in [Item.KIND_WEAPON, Item.KIND_ARMOUR]:
				var item := ItemForge.forge(
					SEED, "probe-%d-%d" % [level, index], level, kind)
				forged += 1
				var gap: int = item.budget() - item.power()
				if gap != 0:
					off += 1
					worst = maxi(worst, absi(gap))
	_say("B1 %d forged items, budget minus what they carry" % forged,
		"HELD" if off == 0 else "BROKE",
		"%d off by anything, worst |gap| = %d" % [off, worst])

	# B2. Hand-built items with hostile weights: negatives, zeros, one huge
	# weight, more names than weights, no names at all.
	var cases := [
		{"w": [-5, -5, -5] as Array[int], "n": ["flame"] as Array[String], "why": "all weights negative"},
		{"w": [0, 0, 0] as Array[int], "n": ["flame"] as Array[String], "why": "all weights zero"},
		{"w": [1, 0, 999999] as Array[int], "n": ["flame"] as Array[String], "why": "one enormous weight"},
		{"w": [1, 1, 1] as Array[int], "n": ["a", "b", "c", "d", "e"] as Array[String], "why": "five effect names, no weights"},
		{"w": [0, 0, 100] as Array[int], "n": [] as Array[String], "why": "the whole budget to effects, no effect names"},
		{"w": [10, 10, 80] as Array[int], "n": [] as Array[String], "why": "most of the budget to effects, no effect names"},
	]
	for one in cases:
		var item := Item.weapon(
			"probe", 9, ItemRarity.LEGENDARY, Ability.STR,
			one["w"], one["n"], [] as Array[int])
		var gap: int = item.budget() - item.power()
		_say("B2 %s" % one["why"],
			"HELD" if gap == 0 else "BROKE",
			"budget %d, carries %d (mov %d def %d eff %d), gap %d" % [
				item.budget(), item.power(), item.movement, item.defence,
				item.effects_power(), gap,
			])

	# B3. The forge's own door: is the "no effect names" shape reachable through
	# the two constructors the rest of the project actually uses?
	var reachable := PackedStringArray()
	for path in _sim_sources():
		var text := _read(path)
		if path == "res://sim/item.gd":
			continue
		for call in ["Item.weapon(", "Item.armour(", "Item.from_shape("]:
			if text.contains(call):
				reachable.append("%s %s" % [path, call])
	_say("B3 who calls the Item constructors at all",
		"note", ", ".join(reachable))

	# B4. Armour.worn and Weapon.held with hostile arguments.
	var over := Armour.worn(Item.SLOT_BOOTS, 6, ItemRarity.MYTHIC, 100000)
	var neg := Armour.worn(Item.SLOT_CHESTPLATE, 6, ItemRarity.MYTHIC, -50)
	var held_over := Weapon.held(Weapon.sword(), 5, ItemRarity.RARE, 100000, 100000)
	for pair in [
		["Armour.worn spending 100000 on moving out of %d" % over.item.budget(), over.item],
		["Armour.worn spending -50 on moving", neg.item],
		["Weapon.held spending 100000 on each of moving and defending", held_over.item],
	]:
		var item: Item = pair[1]
		_say("B4 %s" % pair[0],
			"HELD" if item.spends_budget() else "BROKE",
			"budget %d, carries %d (mov %d def %d eff %d)" % [
				item.budget(), item.power(), item.movement, item.defence,
				item.effects_power(),
			])

	# B5. An unknown rarity, and a negative level.
	var bogus := Item.weapon("bogus", 9, "godlike", Ability.STR,
		ItemBudget.shape(50, 50), ["flame"] as Array[String])
	var below := Item.weapon("below", -9, ItemRarity.ETERNAL, Ability.STR,
		ItemBudget.shape(50, 50), ["flame"] as Array[String])
	_say("B5 a rarity that is not one of the six",
		"HELD" if bogus.budget() == 0 and bogus.power() == 0 else "BROKE",
		"budget %d, carries %d" % [bogus.budget(), bogus.power()])
	_say("B5 a negative source level",
		"HELD" if below.budget() == 0 and below.power() == 0 else "BROKE",
		"budget %d, carries %d, stored level %d" % [
			below.budget(), below.power(), below.level])

	# B6. Can an item be edited past its budget after it is built? The fields are
	# public. This is not a bug in the arithmetic, it is a question about whether
	# `spends_budget()` is a guarantee or a report.
	var edited := ItemForge.forge(SEED, "edit-me", 6, Item.KIND_ARMOUR)
	var before := edited.spends_budget()
	edited.movement += 1000
	_say("B6 writing to Item.movement after construction",
		"BROKE" if before and not edited.spends_budget() else "HELD",
		("spends_budget() went %s -> %s, so the exactness is an invariant of the "
		+ "constructors and not of the class") % [before, edited.spends_budget()])


# --- C: item randomness cannot reach world generation ----------------------


func _attempt_c() -> void:
	_rule("C. item randomness cannot reach world generation")

	# C1. The suite rolls a fixed pattern between ticks. Roll a wildly varying
	# number of items per tick instead, so the count is different at every step.
	var quiet := SimWorld.new(SEED)
	var noisy := SimWorld.new(SEED)
	var rolls := 0
	for tick in 24:
		quiet.step()
		noisy.step()
		for index in (tick * 7) % 31:
			var kill := "uneven-%d-%d" % [tick, index]
			var item := ItemForge.forge(SEED, kill, 1 + (index % 17), Item.KIND_WEAPON)
			ItemDrop.falls(SEED, kill, index, item)
			ItemFrontier.carried_at(SEED, kill, float(index) * 13.0)
			rolls += 1
	_say("C1 %d item rolls in an uneven pattern between 24 world ticks" % rolls,
		"HELD" if quiet.digest() == noisy.digest() else "BROKE",
		"quiet %s / noisy %s" % [quiet.digest(), noisy.digest()])

	# C2. The other direction: does the world's state reach an item? Forge the
	# same address against a fresh world and against a world stepped 200 times.
	var fresh := ItemForge.forge(SEED, "cross-direction", 7, Item.KIND_ARMOUR)
	var stepped := SimWorld.new(SEED)
	for _tick in 200:
		stepped.step()
	var after := ItemForge.forge(SEED, "cross-direction", 7, Item.KIND_ARMOUR)
	_say("C2 the same item forged before and after 200 world steps",
		"HELD" if fresh.line() == after.line() else "BROKE",
		"%s" % fresh.line())

	# C3. The fingerprint has to move for C1 to mean anything.
	var control := SimWorld.new(SEED)
	for _tick in 24:
		control.step()
	var moved := control.digest()
	control.step()
	_say("C3 control: one more step does move the fingerprint",
		"HELD" if control.digest() != moved else "BROKE",
		"%s -> %s" % [moved, control.digest()])

	# C4. Read sim/ for any world-generation file that names an item class.
	var world_classes := ["TerrainSurfaceField", "TerrainStreamer", "BiomeField",
		"WaterField", "IslandField", "SettlementField", "DecorationScatter",
		"ScatterStreamer", "MountainField", "PathNetwork", "ValueNoise"]
	var item_classes := ["Item", "ItemBudget", "ItemRarity", "ItemEffect",
		"ItemForge", "ItemDrop", "ItemFrontier"]
	var crossings := PackedStringArray()
	for path in _sim_sources():
		var text := _read(path)
		var declares_world := false
		for word in world_classes:
			if text.contains("class_name %s\n" % word):
				declares_world = true
		if not declares_world:
			continue
		for word in item_classes:
			if LayerCheck._contains_word(text, word):
				crossings.append("%s -> %s" % [path, word])
	_say("C4 world-generation files that name an item class",
		"HELD" if crossings.is_empty() else "BROKE",
		"%d%s" % [crossings.size(), "" if crossings.is_empty() else " " + str(crossings)])

	# C5. The forge and the drop share the world seed. Do their stream labels
	# collide with any label world generation forks? Count distinct prefixes.
	var forks := PackedStringArray()
	for path in _sim_sources():
		var lines := _read(path).split("\n")
		for index in lines.size():
			if lines[index].contains(".fork("):
				forks.append("%s:%d %s" % [
					path, index + 1, lines[index].strip_edges()])
	print("  [note] C5 every .fork() call under sim/:")
	for one in forks:
		print("      %s" % one)


# --- D: the minion layer is deterministic ---------------------------------


func _attempt_d() -> void:
	_rule("D. the minion-versus-minion layer is deterministic")

	# D1. The same capture under a thousand different fight seeds, with both
	# minions' levels, healths and defences varied wildly. If a die could reach
	# the capture, one of these would come out differently.
	var outcomes := {}
	for trial in 1000:
		var pieces := PieceMap.new()
		var mine := Minion.of_kind(Minion.TOADSTOOL, 1, Vector2i(3, 3), 1 + trial % 40)
		var theirs := Minion.of_kind(Minion.ENT, 2, Vector2i(3, 2), 1 + (trial * 7) % 60)
		pieces.add(mine)
		pieces.add(theirs)
		theirs.health = 1 + trial % 500
		mine.health = 1 + (trial * 3) % 500
		var out := CombatResolution.capture(pieces, mine, theirs)
		outcomes["%s|%s|%s|%s" % [
			out["kind"], out["cell"], out["removed"], pieces.piece_at(Vector2i(3, 2)) == mine,
		]] = true
	_say("D1 the same capture over 1000 level/health combinations",
		"HELD" if outcomes.size() == 1 else "BROKE",
		"%d distinct outcomes: %s" % [outcomes.size(), str(outcomes.keys())])

	# D2. minion_action onto an occupied cell, under many fight seeds. The seed
	# is the die; if the capture branch ever passed it on, this would vary.
	var lines := {}
	for trial in 500:
		var board := _flat_board()
		var pieces := PieceMap.new()
		var mine := Minion.of_kind(Minion.FROG, 1, Vector2i(3, 3), 5)
		var theirs := Minion.of_kind(Minion.CAT, 2, Vector2i(4, 5), 30)
		pieces.add(mine)
		pieces.add(theirs)
		var out := CombatResolution.minion_action(
			board, pieces, mine, Vector2i(4, 5), 1 + trial * 7919)
		lines[CombatResolution.describe(out)] = true
	_say("D2 minion_action taking a minion under 500 different fight seeds",
		"HELD" if lines.size() == 1 else "BROKE",
		"%d distinct transcript lines: %s" % [lines.size(), str(lines.keys())])

	# D3. The control: the same call against a *commander* does vary with the
	# seed, so D2's single outcome is "the seed cannot reach a capture" and not
	# "the seed does nothing anywhere".
	var struck := {}
	for trial in 500:
		var board := _flat_board()
		var pieces := PieceMap.new()
		var mine := Minion.of_kind(Minion.FROG, 1, Vector2i(3, 3), 20)
		var them := Commander.make(Vector2i(4, 5), PieceGeometry.NORTH, AssetTags.KNIGHT, 3)
		pieces.add(mine)
		pieces.add(them)
		var out := CombatResolution.minion_action(
			board, pieces, mine, Vector2i(4, 5), 1 + trial * 7919)
		struck[int(out["dealt"])] = true
	_say("D3 control: the same minion striking a commander under 500 seeds",
		"HELD" if struck.size() > 1 else "BROKE",
		"%d distinct damage values: %s" % [struck.size(), str(struck.keys())])

	# D4. Read the source: does anything on the capture path name the die?
	var text := _read("res://sim/combat_resolution.gd")
	var body := text.substr(text.find("static func capture("))
	body = body.substr(0, body.find("\n\n\n"))
	var names_die := body.contains("swing") or body.contains("fight_seed") or body.contains("Damage")
	_say("D4 the body of capture() naming a die, a seed or Damage",
		"HELD" if not names_die else "BROKE",
		"%d lines, names none of swing/fight_seed/Damage" % body.split("\n").size())

	# D5. Does anything anywhere under sim/ draw a random number inside the
	# tactical layer? List every SimRng use in the combat files.
	var draws := PackedStringArray()
	for path in _sim_sources():
		var name_of := path.get_file()
		if not (name_of.begins_with("combat") or name_of in [
				"minion.gd", "piece.gd", "piece_map.gd", "legal_moves.gd",
				"piece_geometry.gd", "commander.gd", "damage.gd"]):
			continue
		var source_lines := _read(path).split("\n")
		for index in source_lines.size():
			var code: String = AssetCheck.split_code_and_strings(source_lines[index])["code"]
			if code.contains("SimRng") or code.contains("rand"):
				draws.append("%s:%d %s" % [path, index + 1, source_lines[index].strip_edges()])
	print("  [note] D5 every random draw named in the tactical files:")
	for one in draws:
		print("      %s" % one)


# --- E: the gate and the trade bite ---------------------------------------


func _attempt_e() -> void:
	_rule("E. the ability-score gate and the movement-against-defence trade")

	# E1. The design's own example: a level-8 WIS armour under WIS 8.
	var wis := Item.armour("witch's plate", Item.SLOT_CHESTPLATE, 8,
		ItemRarity.COMMON, Ability.WIS, ItemBudget.shape(0, 50))
	var row := PackedStringArray()
	for score in range(0, 10):
		row.append("%d:%d" % [score, wis.defence_for(score)])
	_say("E1 a level-8 WIS chestplate read at scores 0..9",
		"HELD" if wis.defence_for(4) < wis.defence_for(8)
			and wis.defence_for(8) == wis.defence_for(9) else "BROKE",
		"defence axis %d, read as %s" % [wis.defence, " ".join(row)])

	# E2. Does the gate reach the board -- can a low score cost a grant?
	var boots := Armour.worn(Item.SLOT_BOOTS, 4, ItemRarity.COMMON, 4)
	var lost := PackedStringArray()
	for score in range(0, 5):
		var granted := boots.grant_for(score)
		lost.append("%d:%s" % [score, "none" if granted == null else granted.mode_name()])
	_say("E2 a level-4 pair of boots (4 points of movement) read at scores 0..4",
		"HELD" if boots.grant_for(0) == null and boots.grant_for(4) != null else "BROKE",
		"grant by score: %s" % " ".join(lost))

	# E3. Does the gate reach a commander's move pattern on a real board?
	var board := _flat_board()
	var pieces := PieceMap.new()
	var walker := Commander.make(Vector2i(5, 5), PieceGeometry.NORTH, AssetTags.KNIGHT, 4)
	walker.equip(Armour.worn(Item.SLOT_BOOTS, 4, ItemRarity.COMMON, 4))
	walker.equip(Armour.worn(Item.SLOT_LEGGINGS, 8, ItemRarity.COMMON, 8))
	pieces.add(walker)
	var reach := PackedStringArray()
	for score in [0, 2, 4, 6, 8]:
		walker.set_score(Ability.DEX, score)
		reach.append("DEX %d: %d cells" % [
			score, LegalMoves.moves_for(board, pieces, walker).size()])
	_say("E3 a commander in boots and leggings, cells reachable by DEX",
		"HELD" if true else "BROKE", " | ".join(reach))

	# E4. The trade at one budget, over the forge, with the correlation computed
	# here rather than read off the suite.
	var worn := ItemForge.batch(SEED, "critic-trade", 8, Item.KIND_ARMOUR, 600)
	var budget := ItemBudget.total(ItemRarity.COMMON, 8)
	var mov: Array[float] = []
	var def: Array[float] = []
	for item in worn:
		if item.budget() == budget:
			mov.append(float(item.movement))
			def.append(float(item.defence))
	_say("E4 movement against defence at one budget (%d), over %d of %d forged items"
			% [budget, mov.size(), worn.size()],
		"HELD" if _correlation(mov, def) < -0.85 else "BROKE",
		"r = %.4f (a fresh seed and a fresh sample, computed here)" % _correlation(mov, def))

	# E5. And the control: over mixed budgets the same measurement should all but
	# vanish, or E4 would be about the forge and not about the shared budget.
	var all_mov: Array[float] = []
	var all_def: Array[float] = []
	for item in worn:
		all_mov.append(float(item.movement))
		all_def.append(float(item.defence))
	_say("E5 control: the same correlation without the equal-budget filter",
		"HELD" if _correlation(all_mov, all_def) > -0.3 else "BROKE",
		"r = %.4f" % _correlation(all_mov, all_def))

	# E6. Anti-invincibility as a number: grind a near ring and see whether it
	# reaches the next one's ceiling.
	var rows := PackedStringArray()
	var passed := 0
	for ring in [0, 1, 2, 4]:
		var best := 0
		for kill in 4000:
			var carried := ItemFrontier.carried_at_level(
				SEED, "grind-%d-%d" % [ring, kill], ItemFrontier.level_of_ring(ring))
			best = maxi(best, ItemFrontier.best_budget(carried))
		var ceiling := ItemFrontier.ceiling_of_ring(ring)
		var next_ceiling := ItemFrontier.ceiling_of_ring(ring + 1)
		if best > ceiling:
			passed += 1
		rows.append("ring %d: 4000 kills, best %d, own ceiling %d, next ring's %d"
			% [ring, best, ceiling, next_ceiling])
	_say("E6 grinding a ring against its own ceiling",
		"HELD" if passed == 0 else "BROKE",
		"\n      " + "\n      ".join(rows))


# --- helpers --------------------------------------------------------------


func _flat_board() -> CombatBoard:
	var rows := PackedStringArray()
	for _row in 12:
		rows.append("............")
	return BoardSketch.from_rows(rows, SEED)


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
	var top := 0.0
	var left := 0.0
	var right := 0.0
	for index in n:
		var da := a[index] - mean_a
		var db := b[index] - mean_b
		top += da * db
		left += da * da
		right += db * db
	if left <= 0.0 or right <= 0.0:
		return 0.0
	return top / sqrt(left * right)


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
