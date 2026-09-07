extends TestSuite
## One composable base: the catalogue re-expressed over it, two things it can now
## say that it could not before, and a scan showing nothing asks which item it is
## holding.
##
## Every number below is written out by hand and compared exactly -- nothing is
## checked against a value the code under test produced. And every claim with a
## premise is paired with a run in which that premise is broken: the arrow is
## re-composed as an instant effect and stops travelling, the missile is
## re-composed without homing and stops widening, the exact split is replaced
## with a plain floor and points disappear, and each half of the source scan is
## run again over a line that would violate it.
class_name TestEffects

## The directory the source scan reads, all of it.
const SIM_DIR := "res://sim"

## The catalogue as this file says it is, rather than as the code produces it.
## Every one of these numbers was in `sim/weapon.gd` before the base existed and
## is compared against it after; the three columns on the right are what the
## re-expression added.
const CATALOGUE := [
	{
		"weapon": "spear", "attack": "thrust", "cells": 2, "cooldown": 1,
		"damage": 8, "push": 0, "symmetric": false,
		"movement": "instant", "sprite": "point", "animation": "lunge",
	},
	{
		"weapon": "dagger", "attack": "stab", "cells": 2, "cooldown": 1,
		"damage": 6, "push": 0, "symmetric": false,
		"movement": "instant", "sprite": "blade", "animation": "slash",
	},
	{
		"weapon": "sword", "attack": "cut", "cells": 3, "cooldown": 1,
		"damage": 10, "push": 0, "symmetric": false,
		"movement": "instant", "sprite": "blade", "animation": "slash",
	},
	{
		"weapon": "sword", "attack": "cleave", "cells": 6, "cooldown": 3,
		"damage": 16, "push": 0, "symmetric": false,
		"movement": "instant", "sprite": "blade", "animation": "swing",
	},
	{
		"weapon": "bow", "attack": "loose", "cells": 248, "cooldown": 3,
		"damage": 12, "push": 0, "symmetric": true,
		"movement": "projectile", "sprite": "arrow", "animation": "shoot",
	},
	{
		"weapon": "staff", "attack": "fireball", "cells": 9, "cooldown": 5,
		"damage": 4, "push": 0, "symmetric": false,
		"movement": "instant", "sprite": "flame", "animation": "cast",
	},
	{
		"weapon": "flail", "attack": "sweep", "cells": 8, "cooldown": 1,
		"damage": 5, "push": 0, "symmetric": true,
		"movement": "instant", "sprite": "impact", "animation": "spin",
	},
	{
		"weapon": "shield", "attack": "shove", "cells": 1, "cooldown": 2,
		"damage": 0, "push": 1, "symmetric": false,
		"movement": "instant", "sprite": "impact", "animation": "bash",
	},
]

## Every name the catalogue and the two composed items go by, weapons and
## attacks alike. The scan looks for these written down as string literals.
const CATALOGUE_NAMES := [
	"spear", "dagger", "sword", "bow", "staff", "flail", "shield",
	"thrust", "stab", "cut", "cleave", "loose", "fireball", "sweep", "shove",
	"hunting bow", "wand", "arrow", "magic missile",
]

## The constructors that hand out one particular weapon.
const CONSTRUCTORS := [
	"spear", "dagger", "sword", "bow", "staff", "flail", "shield",
	"arrow", "magic_missile",
]

## How a line of code asks a question about what it is looking at. A line that
## both names an item and holds one of these is a branch on which item it is.
const COMPARISONS := [
	"==", "!=", "match ", "begins_with(", "ends_with(", "contains(",
	"has(", " in ",
]

## Where the split arithmetic is swept.
const SPLIT_DAMAGE_TOP := 40
const SPLIT_MOST := 6


func _init() -> void:
	suite_name = "effects"


func run() -> void:
	_the_base_carries_every_customisation_point()
	_an_effect_that_asks_for_nothing_does_nothing()
	_the_catalogue_is_unchanged()
	_the_catalogue_names_tags_and_never_art()
	_an_arrow_is_a_composition()
	_a_magic_missile_splits_and_homes()
	_a_split_divides_its_damage_exactly()
	_the_composed_items_are_used_by_the_same_code()
	_nothing_is_a_kind_of_the_base()
	_no_code_asks_which_item_it_is_holding()
	_every_weapon_handed_out_has_an_item_behind_it()
	_two_processes_agree()


# --- The base -------------------------------------------------------------


## Section 4's seven customisation points, each read back off one composed
## effect. The point is that they are seven fields of one class and not seven
## classes: this effect is a melee shape, a projectile movement, a spell's named
## effect and a shove's property all at once, which is nonsense as an item and
## exactly the right thing for a base to allow.
func _the_base_carries_every_customisation_point() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, -2), Vector2i(0, -1)]
	var everything := Attack.compose({
		"name": "everything",
		"shape": shape,
		"cooldown": 4,
		"damage": 11,
		"movement": Attack.PROJECTILE,
		"effects": ["flame", "arcane"],
		"sprite": AssetTags.EFFECT_BOLT,
		"animation": AssetTags.ANIM_CAST,
		Attack.PUSH: 2,
		Attack.SPLIT: 3,
		Attack.HOMING: 1,
	})

	equal(everything.attack_name, "everything", "the name comes back")
	equal(everything.offsets, shape,
		"the hitbox shape comes back, in the canonical order every pattern is kept in")
	equal(everything.cooldown, 4, "the cooldown comes back")
	equal(everything.damage, 11, "the damage comes back")
	equal(everything.movement, "projectile", "the movement comes back")
	equal(everything.effects, PackedStringArray(["flame", "arcane"]),
		"the named effects come back, in the order they were given")
	equal(everything.sprite_tag, "bolt", "the sprite tag comes back")
	equal(everything.animation_tag, "cast", "the animation tag comes back")
	equal(everything.property(Attack.PUSH), 2, "the push property comes back")
	equal(everything.property(Attack.SPLIT), 3, "the split property comes back")
	equal(everything.property(Attack.HOMING), 1, "the homing property comes back")
	equal(everything.push, 2,
		"and push is readable under the name the resolution step has always used")

	equal(everything.line(),
		"everything cooldown=4 damage=11 cells=2 fronted projectile push=2"
		+ " split=3 homing=1 effects=flame,arcane sprite=bolt anim=cast",
		"one effect, written down in one line")

	# A movement and a property the class cannot answer for are dropped rather
	# than kept, so nothing can claim a behaviour that has no arithmetic.
	var nonsense := Attack.compose({
		"name": "nonsense", "shape": shape, "movement": "teleport", "ricochet": 3,
	})
	equal(nonsense.movement, "instant", "an unknown movement falls back to instant")
	equal(nonsense.properties, {}, "an unknown property is not carried")
	equal(nonsense.property("ricochet"), 0, "and reads as zero")


## Everything left out of a composition takes the value that means "this effect
## does not do that". Which is what makes the seven points free: a spear pays
## nothing for movement it does not have.
func _an_effect_that_asks_for_nothing_does_nothing() -> void:
	var bare := Attack.compose({"name": "bare", "shape": [] as Array[Vector2i]})
	equal(bare.cooldown, 1, "a cooldown of one, the shortest there is")
	equal(bare.damage, 0, "no damage")
	equal(bare.movement, "instant", "it lands where it is aimed")
	equal(bare.properties, {}, "it carries no property")
	equal(bare.push, 0, "it pushes nothing")
	equal(bare.strike_count(), 1, "it lands once")
	equal(bare.homing_reach(), 0, "it bends towards nothing")
	equal(bare.effects, PackedStringArray(), "it does nothing besides damage")
	equal(bare.sprite_tag, "", "it names no sprite")
	equal(bare.animation_tag, "", "it names no animation")
	equal(bare.travels(), false, "and it crosses no ground")


# --- The catalogue, re-expressed ------------------------------------------


## Every number the combat suites assert, compared against the table written at
## the top of this file rather than against the code.
func _the_catalogue_is_unchanged() -> void:
	var rows := _catalogue_rows()
	equal(rows.size(), CATALOGUE.size(),
		"the catalogue carries %d attacks across its seven weapons" % CATALOGUE.size())
	if rows.size() != CATALOGUE.size():
		return

	for index in CATALOGUE.size():
		var expected: Dictionary = CATALOGUE[index]
		var weapon: Weapon = rows[index]["weapon"]
		var attack: Attack = rows[index]["attack"]
		var where: String = "%s/%s" % [expected["weapon"], expected["attack"]]
		equal(weapon.weapon_name, expected["weapon"], "%s: the weapon's name" % where)
		equal(attack.attack_name, expected["attack"], "%s: the attack's name" % where)
		equal(attack.cell_count(), expected["cells"], "%s: how many cells" % where)
		equal(attack.cooldown, expected["cooldown"], "%s: the cooldown" % where)
		equal(attack.damage, expected["damage"], "%s: the damage" % where)
		equal(attack.push, expected["push"], "%s: the push" % where)
		equal(attack.is_symmetric(), expected["symmetric"],
			"%s: whether it has a front" % where)
		equal(attack.strike_count(), 1, "%s: it lands once" % where)
		equal(attack.damage_share(0), expected["damage"],
			"%s: and reads its whole damage off that one landing" % where)

	# Broken: the same comparison against a table with one number moved fails.
	# So the run above means "these numbers" and not "any numbers".
	var moved := CATALOGUE[0].duplicate()
	moved["damage"] = 9
	not_equal(Weapon.spear().attack_at(0).damage, moved["damage"],
		"the spear's thrust is not the number the broken table asks for")


## What the re-expression added: how each effect travels, and the two tags. The
## tags are names out of a written-down vocabulary, and none of them is art.
func _the_catalogue_names_tags_and_never_art() -> void:
	var rows := _catalogue_rows()
	for index in mini(rows.size(), CATALOGUE.size()):
		var expected: Dictionary = CATALOGUE[index]
		var attack: Attack = rows[index]["attack"]
		var where: String = "%s/%s" % [expected["weapon"], expected["attack"]]
		equal(attack.movement, expected["movement"], "%s: how it travels" % where)
		equal(attack.sprite_tag, expected["sprite"], "%s: which art names it" % where)
		equal(attack.animation_tag, expected["animation"],
			"%s: which motion names it" % where)
		check(AssetTags.is_effect_sprite(attack.sprite_tag),
			"%s: '%s' is not in the sprite vocabulary" % [where, attack.sprite_tag])
		check(AssetTags.is_animation(attack.animation_tag),
			"%s: '%s' is not in the animation vocabulary" % [where, attack.animation_tag])

		# And neither tag is a path, checked by the project's own art scanner on
		# a line that writes the tag out as a literal.
		for tag in [attack.sprite_tag, attack.animation_tag]:
			equal(AssetCheck.first_match("var t := \"%s\"" % tag), {},
				"%s: the tag '%s' reads as art" % [where, tag])

	# The vocabularies are separate from the catalog of things that stand in the
	# world, and every one of them is separate: nothing is both a prop and a
	# sprite, and nothing is both a prop and an animation.
	for tag in AssetTags.EFFECT_SPRITES:
		check(not AssetTags.is_tag(tag), "'%s' is both a sprite and a prop" % tag)
	for tag in AssetTags.ANIMATIONS:
		check(not AssetTags.is_tag(tag), "'%s' is both an animation and a prop" % tag)
	equal(AssetTags.is_effect_sprite("fir"), false,
		"a prop tag is not a sprite, which is what makes the split mean anything")
	equal(AssetTags.is_effect_sprite("arrow"), true, "and the arrow is one")
	equal(AssetTags.is_animation("shoot"), true, "and the shot is an animation")


# --- The two the earlier representation could not hold --------------------


## An arrow: projectile movement, an arrow tag, and nothing else new.
##
## What travelling buys is the cells in between. An instant effect is already
## where it is aimed, so the ground it passed over is the one cell it landed on;
## a projectile crosses every cell of the lattice line, which is the only reason
## anything could ever stand in its way.
func _an_arrow_is_a_composition() -> void:
	var arrow := Weapon.arrow()
	equal(arrow.attack_name, "arrow", "it is called an arrow")
	equal(arrow.movement, "projectile", "it is a projectile")
	equal(arrow.sprite_tag, "arrow", "and the art that names it is the arrow")
	equal(arrow.animation_tag, "shoot", "the motion is the shot")
	equal(arrow.cell_count(), 11, "a lane two to twelve cells ahead is eleven cells")
	equal(arrow.damage, 12, "twelve damage, the bow's")
	equal(arrow.cooldown, 2, "on a two-turn cooldown")
	equal(arrow.properties, {}, "it carries no property at all")
	equal(arrow.travels(), true, "it crosses the ground")

	var from := Vector2i(4, 9)
	equal(arrow.travel_to(from, Vector2i(4, 5)), [
		Vector2i(4, 8), Vector2i(4, 7), Vector2i(4, 6), Vector2i(4, 5),
	] as Array[Vector2i], "four cells ahead, it crosses all four")
	equal(arrow.travel_to(from, Vector2i(8, 5)), [
		Vector2i(5, 8), Vector2i(6, 7), Vector2i(7, 6), Vector2i(8, 5),
	] as Array[Vector2i], "and on the diagonal it crosses the diagonal")
	equal(arrow.travel_to(from, Vector2i(8, 7)), [
		Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 7), Vector2i(8, 7),
	] as Array[Vector2i],
		"a flight four across and two up rounds onto four whole cells")

	# Broken: the same shape, composed instant, crosses nothing. So the four
	# cells above are the movement's doing and not the shape's.
	var thrown := Attack.compose({"name": "arrow", "shape": arrow.offsets})
	equal(thrown.travels(), false, "composed instant, it does not travel")
	equal(thrown.travel_to(from, Vector2i(4, 5)), [Vector2i(4, 5)] as Array[Vector2i],
		"and the ground it covered is the one cell it landed on")
	equal(thrown.cells_from(from, PieceGeometry.NORTH),
		arrow.cells_from(from, PieceGeometry.NORTH),
		"while the cells the two of them cover are the same, because the shape is")

	# The one weapon of the seven that travels does the same thing, which is the
	# point: an arrow is not a new item, it is a field.
	equal(Weapon.bow().attack_at(0).travels(), true, "the bow's loose travels too")
	equal(Weapon.spear().attack_at(0).travels(), false, "and a thrust does not")


## A magic missile: a projectile that splits and homes. Three properties, no
## code.
func _a_magic_missile_splits_and_homes() -> void:
	var missile := Weapon.magic_missile()
	equal(missile.attack_name, "magic missile", "it is called a magic missile")
	equal(missile.movement, "projectile", "it is a projectile")
	equal(missile.property(Attack.SPLIT), 3, "it splits three ways")
	equal(missile.property(Attack.HOMING), 1, "and bends one cell to find something")
	equal(missile.damage, 10, "ten damage in total")
	equal(missile.strike_count(), 3, "which lands three times")
	equal(missile.damage_share(0), 4, "the first landing takes four")
	equal(missile.damage_share(1), 3, "the second three")
	equal(missile.damage_share(2), 3, "the third three")
	equal(missile.damage_share(3), 0, "and there is no fourth")
	equal(missile.damage_share(0) + missile.damage_share(1) + missile.damage_share(2),
		10, "the three of them are the whole ten, exactly")
	equal(missile.sprite_tag, "bolt", "the art that names it is the bolt")
	equal(missile.effects, PackedStringArray(["arcane"]), "and what it does is arcane")

	var from := Vector2i(20, 20)
	var covered := missile.cells_from(from, PieceGeometry.NORTH)
	var reachable := missile.reachable_from(from, PieceGeometry.NORTH)
	equal(covered.size(), 104, "its ring at two to six cells covers 104 cells")
	equal(reachable.size(), 168, "and with a bend of one it can reach 168")
	for cell in covered:
		check(reachable.has(cell), "a cell of the shape fell out of the reach")
	check(reachable.has(Vector2i(20, 13)),
		"seven cells ahead is outside the ring and one bend inside the reach")
	check(not covered.has(Vector2i(20, 13)), "and is outside the ring")

	# Broken: the same ring, composed without homing, reaches exactly its shape.
	var straight := Attack.compose({"name": "bolt", "shape": missile.offsets})
	equal(straight.homing_reach(), 0, "no homing")
	equal(straight.reachable_from(from, PieceGeometry.NORTH), covered,
		"so what it can reach is what it covers, and the 168 above is the bend")

	# Broken: the same missile without the split lands once for its whole damage.
	var single := Attack.compose({
		"name": "bolt", "shape": missile.offsets, "damage": 10,
	})
	equal(single.strike_count(), 1, "no split")
	equal(single.damage_share(0), 10, "so one landing takes all ten")


## The split divides exactly, over every damage and every split, and the
## largest-remainder rule is shown to be doing work.
func _a_split_divides_its_damage_exactly() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, -1)]
	var swept := 0
	var uneven := 0
	var lost_by_floor := 0
	for damage in range(0, SPLIT_DAMAGE_TOP + 1):
		for bolts in range(1, SPLIT_MOST + 1):
			var effect := Attack.compose({
				"name": "bolt", "shape": shape, "damage": damage, Attack.SPLIT: bolts,
			})
			swept += 1
			var total := 0
			var least := damage
			var most := 0
			for index in bolts:
				var share := effect.damage_share(index)
				check(share >= 0, "a landing was worth less than nothing")
				total += share
				least = mini(least, share)
				most = maxi(most, share)
			if total != damage:
				uneven += 1
			@warning_ignore("integer_division")
			var floored := (damage / bolts) * bolts
			if floored != damage:
				lost_by_floor += 1
			check(most - least <= 1,
				"%d across %d landings is not spread evenly" % [damage, bolts])
	equal(swept, 246, "246 splits were walked")
	equal(uneven, 0, "and every one of them summed to its whole damage")
	equal(lost_by_floor, 143,
		"a plain floor would have lost points on 143 of the 246")


## The composed items are taken up, aimed and spent by exactly the code a spear
## is. Nothing was added to the commander, the board or the turn for them.
func _the_composed_items_are_used_by_the_same_code() -> void:
	var composed := Weapon.composed()
	equal(composed.size(), 2, "there are two of them")
	equal(composed[0].weapon_name, "hunting bow", "the first carries the arrow")
	equal(composed[1].weapon_name, "wand", "the second carries the missile")

	var commander := Commander.make(Vector2i(20, 20), PieceGeometry.NORTH)
	commander.wield(composed[0])
	equal(commander.attack_count(), 1, "a hunting bow carries one attack")
	equal(commander.attack_at(0).attack_name, "arrow", "and it is the arrow")
	equal(commander.attack_cells(0).size(), 11,
		"eleven cells of lane, laid out from where it stands")
	check(commander.attack_cells(0).has(Vector2i(20, 18)),
		"two cells ahead is the nearest of them")
	check(not commander.attack_cells(0).has(Vector2i(20, 19)),
		"and one cell ahead is inside the lane's near end")

	# It turns with its wielder, on the same rotation as every other pattern.
	commander.facing = PieceGeometry.EAST
	check(commander.attack_cells(0).has(Vector2i(22, 20)),
		"turned east, the lane runs east")
	check(not commander.attack_cells(0).has(Vector2i(20, 18)),
		"and no longer north")

	# And it sits on its cooldown like every other attack.
	check(commander.can_attack(0, 5), "ready on turn five")
	check(commander.spend_attack(0, 5), "spent on turn five")
	check(not commander.can_attack(0, 6), "not ready one turn later")
	check(commander.can_attack(0, 7), "ready two turns later, which is its cooldown")

	commander.wield(composed[1])
	equal(commander.attack_at(0).attack_name, "magic missile",
		"the same commander takes up the wand with the same call")
	equal(commander.attack_cells(0).size(), 104, "and aims its ring the same way")


# --- The shape of the layer -----------------------------------------------


## Nothing under sim/ is a kind of the base. An arrow being a subclass would be
## exactly the thing section 4 asks not to happen, and it is checkable by
## reading the directory rather than by trusting that nobody did it.
func _nothing_is_a_kind_of_the_base() -> void:
	var sources := _sim_sources()
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())

	var kinds := PackedStringArray()
	for path in sources:
		if _code_of(path).contains("extends Attack"):
			kinds.append(path)
	equal(kinds, PackedStringArray(), "no file under sim/ is a kind of the base")

	# Broken: the same scan for the thing every one of them does extend finds
	# them all, so the empty result means "not there" and not "read nothing".
	var extending := PackedStringArray()
	for path in sources:
		if _code_of(path).contains("extends "):
			extending.append(path)
	equal(extending.size(), sources.size(),
		"the same scan over a word that is there finds it in every file")

	# The two composed items are the same class as the spear's thrust, which is
	# what "one base" means when it is not a promise.
	var thrust := Weapon.spear().attack_at(0)
	equal(Weapon.arrow().get_script(), thrust.get_script(),
		"the arrow is the same class as a thrust")
	equal(Weapon.magic_missile().get_script(), thrust.get_script(),
		"and so is the magic missile")


## Nothing under sim/ asks which item it is holding, shown by opening the
## directory rather than by a list of files written here.
##
## Three scans, each with the run that would fail it:
##
##   * no line of code both names an item and asks a question. A name in a list
##     of names -- the forge's shapes, the sprite vocabulary -- is not a branch;
##     a name beside a comparison is.
##   * `weapon_name` and `attack_name` are read only to write down what happened,
##     never to decide anything.
##   * the constructors that hand out one particular weapon are called from the
##     two files that hand weapons out, and every one of those calls hands it to
##     somebody in the same breath.
func _no_code_asks_which_item_it_is_holding() -> void:
	var sources := _sim_sources()
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())
	for expected in ["res://sim/weapon.gd", "res://sim/attack.gd",
			"res://sim/commander.gd", "res://sim/combat_resolution.gd",
			"res://sim/item_forge.gd"]:
		check(sources.has(expected), "the scan reaches %s" % expected)

	var branching := PackedStringArray()
	var naming := PackedStringArray()
	var reading := PackedStringArray()
	var handing := PackedStringArray()
	var handing_files := {}
	for path in sources:
		var lines := _read(path).split("\n")
		for index in lines.size():
			var line: String = lines[index]
			var where := "%s:%d" % [path, index + 1]
			if _names_an_item(line):
				naming.append(where)
				if _asks_a_question(line):
					branching.append(where)
			var code: String = AssetCheck.split_code_and_strings(line)["code"]
			if _compares_a_name(code):
				reading.append(where)
			if _hands_out_a_weapon(code):
				handing_files[path] = true
				if not code.contains("wield("):
					handing.append(where)

	equal(branching, PackedStringArray(),
		"no line under sim/ both names an item and asks a question about it")
	equal(reading, PackedStringArray(),
		"nothing compares an item's name against anything")
	equal(handing, PackedStringArray(),
		"every call that names one weapon hands it to somebody in the same line")
	var handed_out := PackedStringArray(handing_files.keys())
	handed_out.sort()
	equal(handed_out, PackedStringArray([
		"res://sim/scripted_actions.gd", "res://sim/scripted_encounter.gd",
		"res://sim/scripted_loop.gd", "res://sim/scripted_match.gd",
		"res://sim/scripted_play.gd",
		"res://sim/scripted_scenario.gd", "res://sim/scripted_skirmish.gd",
		"res://sim/scripted_strike.gd", "res://sim/scripted_turn.gd",
	]), "and only the files that set a scenario up name a weapon at all")

	# Broken, three times. Each scan is run again over a line that does not exist
	# on disk and that it must catch, so an empty result above is the code's
	# doing and not the scan's.
	check(_names_an_item("	if held.weapon_name == \"sword\":"),
		"the first scan does not see an item named")
	check(_asks_a_question("	if held.weapon_name == \"sword\":"),
		"the first scan does not see a question asked")
	check(_compares_a_name("	if held.weapon_name == \"sword\":"),
		"the second scan does not see a name compared")
	check(_compares_a_name("	match attack.attack_name:"),
		"the second scan does not see a name matched on")
	check(not _compares_a_name("	return \"-\" if weapon == null else weapon.weapon_name"),
		"the second scan fires on a line that reads a name without asking anything")
	check(_hands_out_a_weapon("	var held := Weapon.sword()"),
		"the third scan does not see a weapon named")
	check(not _hands_out_a_weapon("	var held := Weapon.make(called, carried)"),
		"the third scan fires on a call that names no particular weapon")

	# And the positive side of the first scan: the names really are written down
	# under sim/, in more than one file, so "no branch" is a claim about branches.
	check(naming.size() >= 20,
		"the names are written down %d times under sim/" % naming.size())


## Every weapon a file under sim/ hands out is forged, not a bare catalogue
## shape.
##
## The scan beside this one asks whether any code *branches* on which item it is
## holding. This one asks the other half of section 4's first sentence -- that
## every ability lives on an item -- structurally rather than by assertion. A
## `Weapon` is a shape plus an `Item`, and the `Item` may be null; when it is,
## `Weapon.power_for()` falls back to the catalogue's own damage numbers, which
## no budget paid for and no ability score can gate. That fallback is a reporting
## path (see sim/weapon.gd), so nothing under sim/ may equip through it.
##
## Two sweeps, which together close the door:
##
##   * every line that names one particular weapon also says `Weapon.held(`, so
##     the shape it names is being forged and not handed over bare;
##   * every line that both names a weapon and hands it to somebody with
##     `wield(` says the same thing, which is the equipping half on its own.
##
## Both are run again over lines that do not exist on disk and that they must
## catch, so an empty result is the code's doing and not the scan's.
func _every_weapon_handed_out_has_an_item_behind_it() -> void:
	var sources := _sim_sources()
	check(sources.size() > 40, "the scan opened sim/ and found %d files" % sources.size())

	var bare := PackedStringArray()
	var bare_wielded := PackedStringArray()
	var forged := PackedStringArray()
	for path in sources:
		var lines := _read(path).split("\n")
		for index in lines.size():
			var code: String = AssetCheck.split_code_and_strings(lines[index])["code"]
			if not _hands_out_a_weapon(code):
				continue
			var where := "%s:%d" % [path, index + 1]
			if _forges_what_it_hands_out(code):
				forged.append(where)
			else:
				bare.append(where)
				if code.contains("wield("):
					bare_wielded.append(where)

	equal(bare, PackedStringArray(),
		"every line under sim/ that names one weapon forges it onto an item")
	equal(bare_wielded, PackedStringArray(),
		"no wield() call under sim/ hands over a weapon with no item behind it")

	# The positive side: the sweep really does see the forged calls, so the two
	# empty results above mean "no bare one is there" and not "nothing was read".
	check(forged.size() >= 8,
		"the sweep found %d item-backed weapons handed out under sim/" % forged.size())

	# Broken, twice. The line the fix removed, and the line it put in its place.
	check(_hands_out_a_weapon("	(green.piece as Commander).wield(Weapon.sword())")
			and not _forges_what_it_hands_out(
				"	(green.piece as Commander).wield(Weapon.sword())"),
		"the scan does not see a bare catalogue weapon handed over")
	check(_hands_out_a_weapon("	commander.wield(Weapon.held(Weapon.sword(), 2))")
			and _forges_what_it_hands_out(
				"	commander.wield(Weapon.held(Weapon.sword(), 2))"),
		"the scan calls a forged weapon bare")


## The documented command run twice, in two processes, printing the same bytes.
##
## The base draws nothing -- there is no seed anywhere in this layer -- and this
## is what says so from outside: if any of the arithmetic above depended on
## anything but its inputs, the two transcripts would differ.
func _two_processes_agree() -> void:
	var first := _run_effects()
	var second := _run_effects()
	equal(first["exit_code"], 0, "the documented command failed")
	equal(first["output"], second["output"],
		"two runs of ./run_effects.sh printed different bytes")
	not_equal(first["output"], "", "the run printed something")
	not_equal(first["output"], first["output"] + "x",
		"and the comparison can tell two different transcripts apart")


## Run the documented command in its own process, and capture what it printed.
func _run_effects() -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/effects_main.gd",
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


# --- Helpers ---------------------------------------------------------------


## The catalogue flattened to one row per attack, in catalogue order.
func _catalogue_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for weapon in Weapon.catalogue():
		for attack in weapon.attacks:
			rows.append({"weapon": weapon, "attack": attack})
	return rows


## Whether a line writes down the name of one of the catalogue's items, as a
## string literal and exactly rather than as part of a longer word.
func _names_an_item(line: String) -> bool:
	for literal in AssetCheck.split_code_and_strings(line)["strings"]:
		if CATALOGUE_NAMES.has(literal):
			return true
	return false


## Whether a line of code asks a question about what it is looking at.
func _asks_a_question(line: String) -> bool:
	var code: String = AssetCheck.split_code_and_strings(line)["code"]
	for token in COMPARISONS:
		if code.contains(token):
			return true
	return false


## Whether a line of code compares an item's name against anything, as opposed
## to reading it to write it down. A null check beside a name is not a branch on
## which item it is; a comparison against the name itself is.
func _compares_a_name(code: String) -> bool:
	for field in ["weapon_name", "attack_name"]:
		var at := code.find(field)
		while at != -1:
			if code.contains("match "):
				return true
			var before := code.substr(0, at).strip_edges()
			for token in ["==", "!=", "match"]:
				if before.ends_with(token):
					return true
			var after := code.substr(at + field.length()).strip_edges()
			for token in ["==", "!=", "in ", ".begins_with(", ".ends_with(", ".contains("]:
				if after.begins_with(token):
					return true
			at = code.find(field, at + 1)
	return false


## Whether a line of code calls a constructor that hands out one particular
## weapon, as opposed to one that builds a weapon out of what it was given.
func _hands_out_a_weapon(code: String) -> bool:
	for called in CONSTRUCTORS:
		if code.contains("Weapon.%s(" % called):
			return true
	return false


## Whether a line of code that names one particular weapon puts an item behind
## it in the same breath. `Weapon.held` is the one constructor that forges one;
## anything else leaves `Weapon.item` null.
func _forges_what_it_hands_out(code: String) -> bool:
	return code.contains("Weapon.held(")


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


## One file with its comments taken off, so prose about the base is not read as
## code doing it.
func _code_of(path: String) -> String:
	var kept := PackedStringArray()
	for line in _read(path).split("\n"):
		kept.append(AssetCheck.split_code_and_strings(line)["code"])
	return "\n".join(kept)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
