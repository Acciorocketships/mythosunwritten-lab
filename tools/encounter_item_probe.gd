extends SceneTree
## What the five shipped scenario commanders are actually holding, and what a
## bare catalogue shape is worth beside an item forged at the same level.
##
## Nothing here asserts; it reports. Run it before a change and after one and
## the two outputs are the before and the after.
##
##   A -- a bare Weapon.sword() against a sword forged at the same level 2
##   B -- the same pair read by a commander with every ability score at 0
##   C -- every commander sim/scripted_encounter.gd musters, ground and island
##
## Run:  tools/godot/godot4 --headless --path . --script res://tools/encounter_item_probe.gd

const SEED := 1234


func _initialize() -> void:
	_bare_against_forged()
	_read_by_a_commander_with_no_scores()
	_what_the_scenario_hands_out()
	quit(0)


func _heading(title: String) -> void:
	print("")
	print("=== %s" % title)


## A level-2 commander holding a catalogue shape, and one holding a sword forged
## at the same level 2, side by side.
func _bare_against_forged() -> void:
	_heading("A. a bare catalogue sword against one forged at level 2")
	var bare := _commander_holding(Weapon.sword(), 2)
	var forged := _commander_holding(Weapon.held(Weapon.sword(), 2), 2)
	print("  bare Weapon.sword()          cut/cleave = %d/%d" % [
		bare.damage_of(0), bare.damage_of(1)])
	print("  Weapon.held(sword(), 2)      cut/cleave = %d/%d  (budget %d)" % [
		forged.damage_of(0), forged.damage_of(1), forged.weapon.item.budget()])
	print("  the bare shape is worth %d points of effects axis" % [
		Weapon.sword().reference_power()])


## The same pair, with every ability score recorded as 0. The gate is on the
## item, so a shape with no item behind it has nothing to read it through.
func _read_by_a_commander_with_no_scores() -> void:
	_heading("B. the same pair read by a commander with every score at 0")
	var bare := _commander_holding(Weapon.sword(), 2)
	var forged := _commander_holding(Weapon.held(Weapon.sword(), 2), 2)
	for ability in Ability.ALL:
		bare.set_score(ability, 0)
		forged.set_score(ability, 0)
	print("  bare Weapon.sword()          cut = %d" % bare.damage_of(0))
	print("  Weapon.held(sword(), 2)      cut = %d" % forged.damage_of(0))


## Every commander the shipped scenario musters, as it musters them.
func _what_the_scenario_hands_out() -> void:
	_heading("C. the commanders sim/scripted_encounter.gd musters")
	var ground := SimWorld.new(SEED)
	ScriptedEncounter.muster(ground)
	_write_down("ground", ground)
	var aerial := SimWorld.new(SEED)
	var island := ScriptedEncounter.muster_on_island(aerial)
	if island == null:
		print("  island: seed %d has no walkable island to fight on" % SEED)
		return
	_write_down("island", aerial)


func _write_down(where: String, world: SimWorld) -> void:
	for one in world.combat.members:
		var commander := one.piece as Commander
		if commander == null or commander.weapon == null:
			continue
		var held := commander.weapon
		print("  %s #%d level=%d %s item=%s" % [
			where, one.id, commander.level,
			held.line_for(commander.score_for(held.item)),
			"none" if held.item == null
				else "%s level %d budget %d" % [
					held.item.rarity, held.item.level, held.item.budget()],
		])


func _commander_holding(held: Weapon, at_level: int) -> Commander:
	var commander := Commander.make(
		Vector2i(4, 4), PieceGeometry.NORTH, AssetTags.KNIGHT, at_level)
	commander.wield(held)
	return commander
