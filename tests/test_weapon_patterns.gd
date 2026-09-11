extends TestSuite
## The five shapes the art packs were already carrying, as weapons somebody can
## hold: reachable, non-transitive, paid for out of the one budget, and swung in
## a seeded fight.
##
## Five silhouettes were installed, imported and measured -- an axe, a two-handed
## sword, a crossbow, a wand and a spellbook -- and nothing in the simulation
## could be one of them, because a shape is reached by a *word* and a word with
## no attack pattern behind it is a name no item can carry. `sim/weapon.gd` now
## has those five patterns. This suite is what says so, in six claims:
##
##   1. **Each of the five is reachable as an item.** A word reaches a catalogue
##      weapon, the weapon carries cells and a wait and a motion out of the
##      written-down vocabularies, and an item forged from it records the shape
##      so that reading it back gives the same pattern rather than a budget with
##      nothing to swing.
##   2. **No new pattern is a strict improvement on an older one.** Domination is
##      written out as arithmetic -- covering at least the same cells, on at most
##      the same wait, for at least the same share of the budget, with at least
##      the same shove -- and every pair of the catalogue's twelve weapons is
##      walked. One pair dominates, it is one that was there before this work,
##      and it is named here rather than discovered later.
##   3. **What each of the five beats and what it loses to**, as numbers rather
##      than as prose: the cells the axe covers that no sword does, the range the
##      crossbow has at both ends of the bow's ring, what one landing keeps
##      against armour that three landings lose, and how far a spellbook cannot
##      reach.
##   4. **The one power budget still spends in full.** Every new shape, forged
##      across levels and rarities, sums to its budget exactly and divides its
##      effects axis across its attacks without losing a point.
##   5. **Section 5's frontier guarantee still holds.** A new shape forged in a
##      ring is bounded by that ring's ceiling, and the next ring's ceiling is
##      strictly higher, so gear is still capped by what has been defeated.
##   6. **One seeded fight**, five commanders with one new weapon each, in which
##      every one of the five is held, swung and lands -- read off the frames the
##      render layer would have been handed, with the clip each blow was drawn
##      with checked against the blow's own tag.
class_name TestWeaponPatterns

## The five shape words this work added, in catalogue order.
const NEW_SHAPES := ["axe", "greatsword", "crossbow", "wand", "spellbook"]

## What each of them is drawn as. Written out rather than read from
## `ItemModel.BY_SHAPE`, so a row lost from that table fails here.
const NEW_TAGS := {
	"axe": AssetTags.GEAR_AXE,
	"greatsword": AssetTags.GEAR_GREATSWORD,
	"crossbow": AssetTags.GEAR_CROSSBOW,
	"wand": AssetTags.GEAR_WAND,
	"spellbook": AssetTags.GEAR_SPELLBOOK,
}

## The shapes that were in the catalogue before this work, in its own order.
const OLD_SHAPES := ["spear", "dagger", "sword", "bow", "staff", "flail", "shield"]

## The one pair of weapons in which every attack of the second is dominated by an
## attack of the first, found by the walk in claim 2 rather than asserted.
##
## It is older than the five patterns this suite is about: a flail sweeps all
## eight cells around itself every turn, and a dagger stabs two of those same
## eight on the same turn, and at equal budget two one-attack weapons deal equal
## damage -- so there is nothing a dagger does that a flail does not. It is
## recorded here so that the walk has a known answer, and so that a *sixth*
## weapon falling into the same hole is a failure of this suite rather than a
## thing somebody notices in a year.
const KNOWN_DOMINATION := ["flail over dagger"]

# --- The seeded fight -----------------------------------------------------

## Who carries the five, and what each is drawn as. Five different models for the
## reason the seven-weapon run has seven: a photograph of the run has to show
## which of them is which.
const BEARERS := ["Alder", "Brae", "Cinder", "Dusk", "Ember"]
const BEARER_LOOKS := [
	AssetTags.BARBARIAN, AssetTags.KNIGHT, AssetTags.SKELETON_ROGUE,
	AssetTags.SKELETON_MAGE, AssetTags.MAGE,
]

## Where the five stand, as world offsets from the fixture's own measured
## meadow: a west-to-east line, six world units apart, which is two cells of the
## tactical lattice.
##
## Two cells is chosen and not stumbled on. Every one of the five patterns covers
## the cell two cardinal steps ahead of its wielder -- it is the near end of the
## crossbow's lane and of the wand's ring, and the far end of the axe's haft, the
## greatsword's arc and the spellbook's burst -- so every fighter can strike a
## neighbour from where it is put down, and the board's own chooser therefore
## moves nobody. A ring of five leaves whoever has the shortest reach standing
## still for the whole fight, with its nearest enemy inside somebody else's
## pattern and outside its own: the run at a radius of ten swung four of the five
## and the axe not once.
##
## The first offset is the middle of the line, because the board is anchored on
## the commander that begins the fight and everyone else has to be inside it.
const LINE := [
	Vector2(0.0, 0.0), Vector2(-6.0, 0.0), Vector2(6.0, 0.0),
	Vector2(-12.0, 0.0), Vector2(12.0, 0.0),
]

## How long the run is watched for, in ticks. Long enough for the longest wait
## among the five -- the spellbook's five turns -- to come round more than once.
const TICKS := 240

## The levels the gear check sweeps.
const LEVELS := [1, 2, 5, 9, 14, 20]

## How many rings of the frontier the ceiling claim walks.
const RINGS := 8

## The ability score the budget is read at. High enough that the gate is open, so
## the claim is about the budget and not about the gate.
const SCORE := 20


func _init() -> void:
	suite_name = "weapon patterns"


func run() -> void:
	var played := play()
	_each_shape_is_reachable_as_an_item()
	_no_new_pattern_dominates_an_old_one()
	_what_each_one_beats_and_loses_to()
	_the_budget_still_spends_in_full()
	_the_frontier_still_bounds_the_gear()
	_a_seeded_run_holds_swings_and_lands_each_one(played)
	_the_simulation_names_tags_and_never_a_model(played)


# --- 1. Reachable as an item ----------------------------------------------


## A word, a pattern, a wait, a motion and a silhouette, for each of the five --
## and the round trip that says an item forged from one is still one when it is
## read back.
func _each_shape_is_reachable_as_an_item() -> void:
	equal(NEW_SHAPES.size(), 5, "five shapes were installed and five are claimed")
	for shape in NEW_SHAPES:
		var weapon := Weapon.shaped_like(shape)
		check(weapon != null, "'%s' reaches no catalogue weapon" % shape)
		if weapon == null:
			continue
		equal(weapon.weapon_name, shape, "'%s' reaches a weapon by another name" % shape)
		check(weapon.attack_count() >= 1, "the %s carries no attack" % shape)

		for index in weapon.attack_count():
			var attack := weapon.attack_at(index)
			var where := "%s/%s" % [shape, attack.attack_name]
			check(attack.cell_count() > 0, "%s: covers no cells" % where)
			check(attack.cooldown >= Attack.EVERY_TURN,
				"%s: waits less than a turn" % where)
			check(AssetTags.is_effect_sprite(attack.sprite_tag),
				"%s: '%s' is not in the sprite vocabulary" % [where, attack.sprite_tag])
			check(AssetTags.is_animation(attack.animation_tag),
				"%s: '%s' is not in the animation vocabulary"
					% [where, attack.animation_tag])

		# What it is drawn as: a catalog name, out of the one table that answers
		# that question, and the name written down at the top of this file.
		var tag := ItemModel.for_shape(shape)
		equal(tag, String(NEW_TAGS[shape]), "'%s' is drawn under another name" % shape)
		check(AssetTags.is_tag(tag), "'%s' is not a name the catalog knows" % tag)
		equal(AssetTags.category_of(tag), AssetTags.GEAR,
			"'%s' is not filed under gear" % tag)

		# And the round trip: forged from the shape, the item records the word,
		# and reading the item back gives the same pattern rather than `around()`.
		var forged := Weapon.held(weapon, 6)
		check(forged.item != null, "a held %s has no item behind it" % shape)
		equal(forged.item.shape, shape, "a held %s does not record its shape" % shape)
		equal(forged.item.model, tag, "a held %s does not record what it looks like" % shape)
		var read_back := Weapon.for_item(forged.item)
		check(read_back != null, "a held %s does not read back as anything" % shape)
		equal(read_back.weapon_name, shape,
			"a held %s reads back as another weapon" % shape)
		equal(read_back.attack_count(), weapon.attack_count(),
			"a held %s reads back with a different number of attacks" % shape)
		for index in read_back.attack_count():
			equal(read_back.attack_at(index).offsets, weapon.attack_at(index).offsets,
				"a held %s reads back with a different pattern" % shape)

	# Broken: a word nothing ships still reaches nothing, so the five above mean
	# "these words" and not "any word".
	check(Weapon.shaped_like("halberd") == null,
		"a word the catalogue does not ship reached a weapon")
	equal(ItemModel.for_shape("halberd"), ItemModel.NOTHING,
		"a word the table does not hold was drawn as something")


# --- 2. Nothing here is a strict improvement ------------------------------


## Section 3.1 asks for a non-transitive space rather than a ladder. Written as
## arithmetic: one attack *dominates* another when it covers at least the same
## cells, waits at most as long, takes at least the same share of its own item's
## effects axis, and shoves at least as far -- and is strictly better on one of
## the four. A weapon dominates another when every one of the second's attacks is
## dominated by one of the first's, which is the honest unit, because what a
## person equips is a weapon and not an attack.
##
## The walk covers all twelve weapons against each other, so a claim about the
## five is made in the same breath as a claim about the seven.
func _no_new_pattern_dominates_an_old_one() -> void:
	var weapons := Weapon.catalogue()
	equal(weapons.size(), 12, "the walk covers twelve weapons")

	var found := PackedStringArray()
	var pairs := 0
	for over in weapons:
		for under in weapons:
			if over.weapon_name == under.weapon_name:
				continue
			pairs += 1
			if _dominates(over, under):
				found.append("%s over %s" % [over.weapon_name, under.weapon_name])
	equal(pairs, 132, "every ordered pair of the twelve was compared")
	found.sort()
	equal(found, PackedStringArray(KNOWN_DOMINATION),
		"the catalogue holds a weapon that is strictly better than another")

	# And the part of that claim this work is answerable for, said on its own so
	# a failure names it: no pair with one of the five in it dominates either way.
	for shape in NEW_SHAPES:
		var fresh := Weapon.shaped_like(shape)
		for other in weapons:
			if other.weapon_name == shape:
				continue
			check(not _dominates(fresh, other),
				"the %s is strictly better than the %s" % [shape, other.weapon_name])
			check(not _dominates(other, fresh),
				"the %s is strictly better than the %s" % [other.weapon_name, shape])

	# Broken: a weapon built to be a plain upgrade of the spear -- the same two
	# cells and one more, on the same wait -- is caught. Without this the walk
	# above would pass just as happily against a rule that never fires.
	var longer: Array[Attack] = [Attack.compose({
		"name": "longer thrust",
		"shape": PieceGeometry.line([Vector2i(0, -1)] as Array[Vector2i], 1, 3),
		"cooldown": 1,
		"damage": 8,
	})]
	var upgrade := Weapon.make("longer spear", longer)
	check(_dominates(upgrade, Weapon.spear()),
		"the rule does not see a weapon that is a plain upgrade of the spear")
	check(not _dominates(Weapon.spear(), upgrade),
		"the rule sees domination in the direction it does not hold")


## Whether every attack of `under` is dominated by some attack of `over`, with at
## least one comparison strict.
func _dominates(over: Weapon, under: Weapon) -> bool:
	if over.attacks.is_empty() or under.attacks.is_empty():
		return false
	var strict := false
	for beaten in under.attacks:
		var covered := false
		for winner in over.attacks:
			var verdict := _attack_dominates(winner, over, beaten, under)
			if int(verdict["holds"]) == 1:
				covered = true
				strict = strict or int(verdict["strict"]) == 1
				break
		if not covered:
			return false
	return strict


## One attack against one attack, each read together with the weapon it is
## carried on, because what an attack is *worth* is its share of that weapon's
## own effects axis and not the number written beside it.
func _attack_dominates(
	winner: Attack, carrying: Weapon, beaten: Attack, carried_on: Weapon
) -> Dictionary:
	var cells := {}
	for cell in winner.offsets:
		cells[cell] = true
	var covers_more := false
	for cell in beaten.offsets:
		if not cells.has(cell):
			return {"holds": 0, "strict": 0}
	covers_more = winner.offsets.size() > beaten.offsets.size()

	if winner.cooldown > beaten.cooldown:
		return {"holds": 0, "strict": 0}
	if winner.push < beaten.push:
		return {"holds": 0, "strict": 0}

	# What one landing is worth, compared by cross-multiplication so the whole
	# thing stays in whole numbers: the winner's damage over its own weapon's
	# total, divided by how many landings one use makes, against the same for the
	# one it is beating. A weapon whose attacks all deal nothing takes no share.
	#
	# The landings matter because the defence is subtracted from each of them.
	# A wand's missile covers every cell a staff's fireball covers and waits two
	# turns fewer, and is still not strictly better than it: the missile splits
	# into three, so one third of the budget arrives at a time where the
	# fireball's whole share arrives at once.
	var winner_total := ItemBudget.sum(carrying.damage_weights())
	var beaten_total := ItemBudget.sum(carried_on.damage_weights())
	var left := 0 if winner_total <= 0 else \
		winner.damage * beaten_total * beaten.strike_count()
	var right := 0 if beaten_total <= 0 else \
		beaten.damage * winner_total * winner.strike_count()
	if left < right:
		return {"holds": 0, "strict": 0}

	var strict := covers_more or winner.cooldown < beaten.cooldown \
		or winner.push > beaten.push or left > right
	return {"holds": 1, "strict": 1 if strict else 0}


# --- 3. What each one beats, and what it loses to -------------------------


## The five sentences in the catalogue's own notes, each turned into a number.
func _what_each_one_beats_and_loses_to() -> void:
	_the_axe_covers_its_flanks_and_waits_for_it()
	_the_greatsword_keeps_against_armour_what_the_wand_loses()
	_the_crossbow_reaches_where_the_ring_has_a_hole()
	_the_spellbook_covers_everything_near_and_nothing_far()


## The axe: it beats anything that closes, because it covers the two cells beside
## its wielder that no sword attack reaches and one more up the middle than
## anything that reaches only one; it loses to the sword on tempo, three cuts to
## its one blow, and it is the only blow in the catalogue that wounds and shoves
## at once.
func _the_axe_covers_its_flanks_and_waits_for_it() -> void:
	var hew := Weapon.axe().attack_at(0)
	for beside in [Vector2i(-1, 0), Vector2i(1, 0)]:
		check(hew.offsets.has(beside),
			"the axe does not cover the cell at %s beside its wielder" % beside)
		for attack in Weapon.sword().attacks:
			check(not attack.offsets.has(beside),
				"the sword's %s covers %s, so the axe's flanks are not its own"
					% [attack.attack_name, beside])
		check(not Weapon.greatsword().attack_at(0).offsets.has(beside),
			"the greatsword covers %s, so the axe's flanks are not its own" % beside)
	check(hew.offsets.has(Vector2i(0, -2)),
		"the axe does not reach the second cell ahead")
	check(not Weapon.flail().attack_at(0).offsets.has(Vector2i(0, -2)),
		"the flail reaches the second cell ahead, so the axe has nothing over it")

	equal(hew.cooldown, 3, "the axe waits three turns")
	equal(Weapon.sword().attack_at(0).cooldown, 1, "and a cut comes round every turn")

	# The one blow that does both. A shove that leaves its target standing is the
	# shield's; every other blow leaves its target where it was.
	var both := PackedStringArray()
	for weapon in Weapon.catalogue():
		for attack in weapon.attacks:
			if attack.damage > 0 and attack.push > 0:
				both.append("%s/%s" % [weapon.weapon_name, attack.attack_name])
	equal(both, PackedStringArray(["axe/hew"]),
		"the axe is not the only blow that wounds and shoves at once")


## The greatsword against the wand, which is the same budget arriving as one
## landing or as three, and armour is subtracted from each landing.
##
## Both weapons carry one attack, so both put the whole effects axis on it; the
## wand's missile then splits that into three. Against a bare target the two are
## worth the same to the point; against a defended one they are not, and the gap
## is exactly the defence paid twice more.
func _the_greatsword_keeps_against_armour_what_the_wand_loses() -> void:
	var arc := Weapon.greatsword()
	var missile := Weapon.wand()
	equal(arc.attack_at(0).strike_count(), 1, "the greatsword lands once")
	equal(missile.attack_at(0).strike_count(), 3, "and the wand lands three times")

	var power := 24
	@warning_ignore("integer_division")
	var share := power / 3
	for defence in [0, 2, 5, 8]:
		var one := Damage.resolve(power, Damage.NONE, defence)
		var three := 0
		for _index in 3:
			three += Damage.resolve(share, Damage.NONE, defence)
		if defence == 0:
			equal(one, three,
				"against no armour one landing and three are not worth the same")
			continue
		check(one > three,
			"against a defence of %d, one landing of %d (%d) did not beat three of %d (%d)"
				% [defence, power, one, share, three])
		if defence < share:
			equal(one - three, 2 * defence,
				"the gap against a defence of %d is not that defence paid twice more"
					% defence)
		else:
			# Past the point where a single landing would be worth nothing, the
			# one-point floor holds each of the three up and the gap is wider
			# than twice the defence rather than exactly it.
			equal(three, 3 * Damage.MINIMUM,
				"a defence of %d did not grind each of the three down to the floor"
					% defence)

	# And the other half of the trade, which is why the wand is not simply worse:
	# three landings is three separate targets where one blow is one, and the
	# missile bends a cell off its own shape to find them.
	equal(missile.attack_at(0).homing_reach(), 1, "the wand's missile does not home")
	equal(arc.attack_at(0).homing_reach(), 0, "the greatsword's arc homes, which it must not")
	var bent := missile.attack_at(0).reachable_from(Vector2i(0, 0), PieceGeometry.NORTH)
	check(bent.size() > missile.attack_at(0).cell_count(),
		"homing did not widen what the wand can reach")


## The crossbow against the bow: a lane that starts at two and carries to
## sixteen, against a ring that starts at five and stops at ten.
func _the_crossbow_reaches_where_the_ring_has_a_hole() -> void:
	var bolt := Weapon.crossbow().attack_at(0)
	var loose := Weapon.bow().attack_at(0)

	for near in [Vector2i(0, -2), Vector2i(0, -3), Vector2i(0, -4)]:
		check(bolt.offsets.has(near),
			"the crossbow does not cover %s, inside the ring's own hole" % near)
		check(not loose.offsets.has(near),
			"the bow's ring covers %s, so the hole this claim rests on is not there"
				% near)
	check(bolt.offsets.has(Vector2i(0, -16)),
		"the crossbow does not carry to sixteen cells")
	check(not loose.offsets.has(Vector2i(0, -16)),
		"the bow's ring reaches sixteen cells, which it must not")
	check(not bolt.offsets.has(Vector2i(0, -1)),
		"the crossbow covers the cell in contact with it, which it must not")

	# What it pays: a front, and fifteen cells of ground to be blocked on.
	check(not bolt.is_symmetric(), "the crossbow has no front, so turning costs it nothing")
	check(loose.is_symmetric(), "the bow has a front, so this trade is not the trade")
	equal(bolt.cooldown, 4, "the crossbow waits four turns")
	equal(loose.cooldown, 3, "and the bow three")
	check(bolt.travels(), "the bolt does not cross the ground")
	var crossed := bolt.travel_to(Vector2i(0, 0), Vector2i(0, -16))
	equal(crossed.size(), 16,
		"the bolt does not cross every cell between its wielder and where it lands")


## The spellbook: everything within two cells and nothing beyond, on the longest
## wait in the catalogue.
func _the_spellbook_covers_everything_near_and_nothing_far() -> void:
	var flare := Weapon.spellbook().attack_at(0)
	equal(flare.cell_count(), 20, "the spellbook covers twenty cells")
	check(flare.is_symmetric(), "the spellbook has a front, so it can be flanked")

	# Every one of the eight cells touching the caster, and the caster's own cell
	# is not among them.
	for cell in PieceGeometry.ring(1.0, 1.5):
		check(flare.offsets.has(cell),
			"the spellbook does not cover %s, which is in contact with it" % cell)
	check(not flare.offsets.has(Vector2i(0, 0)),
		"the spellbook covers the cell the caster is standing in")

	# And nothing at three cells or further, which is where the staff's fireball
	# and the bow's ring are looking at it from.
	for far in flare.offsets:
		check(Vector2(far).length() <= 2.5,
			"the spellbook reaches %s, further than the two cells it claims" % far)
	check(Weapon.staff().attack_at(0).offsets.has(Vector2i(0, -4)),
		"the staff no longer lands four cells away, so nothing outranges the spellbook")
	equal(flare.cooldown, 5, "the spellbook waits five turns")
	equal(Weapon.staff().attack_at(0).cooldown, 5, "the same as the staff's fireball")


# --- 4. The one budget, spent in full -------------------------------------


## Section 4's budget, on every new shape: forged at a level and a rarity, an
## item's three axes sum to its whole budget, and a weapon's blows divide its
## effects axis without losing a point.
func _the_budget_still_spends_in_full() -> void:
	var forged := 0
	for shape in NEW_SHAPES:
		var catalogue_shape := Weapon.shaped_like(shape)
		if catalogue_shape == null:
			continue
		for level in LEVELS:
			for rarity in ItemRarity.TIERS:
				var weapon := Weapon.held(catalogue_shape, level, rarity)
				var item := weapon.item
				forged += 1
				var whole := ItemBudget.total(rarity, level)
				equal(item.budget(), whole,
					"a %s %s at level %d is not worth its rarity times its level"
						% [rarity, shape, level])
				equal(item.movement + item.defence + ItemBudget.sum(_effect_points(item)),
					whole,
					"a %s %s at level %d loses points between its three axes"
						% [rarity, shape, level])

				# And the effects axis, divided among the blows: exactly, and
				# into the same number of parts as there are attacks.
				var spent := 0
				for index in weapon.attack_count():
					spent += weapon.damage_of(index, SCORE)
				equal(spent, item.effects_for(SCORE),
					"a %s %s at level %d does not spend its effects axis on its blows"
						% [rarity, shape, level])

				# The wait is never shorter than a turn, whatever the movement
				# axis bought.
				for index in weapon.attack_count():
					check(weapon.cooldown_of(index, SCORE) >= Attack.EVERY_TURN,
						"a %s %s comes round faster than once a turn" % [rarity, shape])
	equal(forged, NEW_SHAPES.size() * LEVELS.size() * ItemRarity.TIERS.size(),
		"every new shape was forged at every level and rarity")

	# A weapon whose blows are all worth nothing divides nothing among them, so
	# spending "in full" never means inventing damage: checked against the shield,
	# which is the case, and against a new shape, which is not.
	var shield := Weapon.held(Weapon.shield(), 9, ItemRarity.LEGENDARY)
	equal(shield.damage_of(0, SCORE), 0, "a shove became a blow")
	check(Weapon.held(Weapon.axe(), 9, ItemRarity.LEGENDARY).damage_of(0, SCORE) > 0,
		"a legendary axe deals nothing, so the comparison above proves nothing")


## The points each of an item's effects cost, in order.
func _effect_points(item: Item) -> Array[int]:
	var points: Array[int] = []
	for effect in item.effects:
		points.append(effect.magnitude)
	return points


# --- 5. The frontier still bounds the gear --------------------------------


## Section 5: "your gear budget is capped by what you've killed, which is always
## behind the frontier". A new shape is not a way round it, because the cap is a
## property of the budget and a shape spends the budget rather than adding to it.
func _the_frontier_still_bounds_the_gear() -> void:
	for ring in RINGS:
		var level := ItemFrontier.level_of_ring(ring)
		var ceiling := ItemFrontier.ceiling_of_ring(ring)
		check(ItemFrontier.ceiling_of_ring(ring + 1) > ceiling,
			"ring %d's ceiling is not below the next ring's" % ring)
		for shape in NEW_SHAPES:
			var catalogue_shape := Weapon.shaped_like(shape)
			for rarity in ItemRarity.TIERS:
				var weapon := Weapon.held(catalogue_shape, level, rarity)
				check(weapon.item.budget() <= ceiling,
					"a %s %s from ring %d is worth more than that ring can drop"
						% [rarity, shape, ring])
				check(weapon.item.budget()
						<= ItemFrontier.ceiling_of_ring(ring + 1),
					"a %s %s from ring %d passes the next ring's ceiling"
						% [rarity, shape, ring])
		# The top tier of this ring is exactly the ceiling, so the bound is tight
		# rather than generous -- an untight bound would hold for any numbers.
		var best := Weapon.held(
			Weapon.shaped_like(NEW_SHAPES[0]), level, ItemFrontier.top_tier())
		equal(best.item.budget(), ceiling,
			"the best new-shape item of ring %d does not reach that ring's ceiling"
				% ring)


# --- 6. One seeded fight --------------------------------------------------


## Five commanders, one new weapon each, on the measured meadow: every one of the
## five is held, is swung, and lands -- and every frame that shows a blow shows
## the clip that blow's own tag names.
func _a_seeded_run_holds_swings_and_lands_each_one(played: Dictionary) -> void:
	check(bool(played["began"]), "the fight was refused, so there is no run")
	var carried: Dictionary = played["weapons"]
	equal(carried.size(), NEW_SHAPES.size(), "five commanders took up five weapons")
	var held := PackedStringArray()
	for id in carried:
		held.append(String(carried[id]))
	held.sort()
	var wanted := PackedStringArray(NEW_SHAPES.duplicate())
	wanted.sort()
	equal(held, wanted, "the run is not carrying the five new shapes")

	# Swung, and landed. A blow in the record is a blow that was struck; `hits`
	# is what it found.
	var struck := {}
	var landed := {}
	var motions := {}
	for blow in played["blows"]:
		var weapon := String(carried.get(int(blow["from"]), ""))
		struck[weapon] = int(struck.get(weapon, 0)) + 1
		motions[weapon] = String(blow["animation"])
		if int(blow.get("hits", 0)) > 0:
			landed[weapon] = int(landed.get(weapon, 0)) + 1
	for shape in NEW_SHAPES:
		check(int(struck.get(shape, 0)) > 0,
			"the %s was never swung in the run" % shape)
		check(int(landed.get(shape, 0)) > 0,
			"the %s was swung %d times and never landed"
				% [shape, int(struck.get(shape, 0))])
		equal(String(motions.get(shape, "")),
			Weapon.shaped_like(shape).attack_at(0).animation_tag,
			"the %s was struck with a motion that is not its own" % shape)

	# And the frames: what the render layer would have drawn, on the ticks it
	# would have drawn them.
	var drawn := 0
	for frame in played["frames"]:
		var motion := String(frame["motion"])
		if motion == CharacterView.NO_MOTION or not bool(frame["alive"]):
			continue
		drawn += 1
		equal(String(frame["clip"]), CharacterRig.clip_for_motion(motion),
			"on tick %d a %s striking '%s' was drawn with the wrong clip"
				% [int(frame["tick"]), String(frame["weapon"]), motion])
	check(drawn > 0, "no frame of the run showed a blow being struck")

	# The same timing the seven-weapon run is held to: a motion runs from the
	# tick the record says the blow began on until its clip's length has passed.
	var timed := TestAttackClips.timings(played)
	check(int(timed["checked"]) > 0,
		"no blow of the run could be timed against its own record")
	equal(int(timed["dropped"]), 0,
		"%d blow(s) left the snapshot before their own motion was over"
			% int(timed["dropped"]))
	for failure in timed["failures"]:
		check(false, String(failure))


# --- 7. Tags, never art ---------------------------------------------------


## The five patterns name sprites and motions out of the written-down
## vocabularies, and nothing in the simulation reads as a picture.
func _the_simulation_names_tags_and_never_a_model(played: Dictionary) -> void:
	for shape in NEW_SHAPES:
		var weapon := Weapon.shaped_like(shape)
		for attack in weapon.attacks:
			for tag in [attack.sprite_tag, attack.animation_tag]:
				equal(AssetCheck.first_match("var t := \"%s\"" % tag), {},
					"the %s's tag '%s' reads as art" % [shape, tag])
		# The name it is drawn under is a tag too, and a tag is not a path.
		equal(AssetCheck.first_match("var t := \"%s\"" % ItemModel.for_shape(shape)), {},
			"the %s's catalog name reads as art" % shape)

	# The three files this work touched under sim/ name no asset path, line by
	# line, through the project's own scanner rather than by reading them here.
	var scanned := 0
	for path in ["res://sim/weapon.gd", "res://sim/item_model.gd",
			"res://sim/scripted_armoury.gd"]:
		var file := FileAccess.open(path, FileAccess.READ)
		check(file != null, "the scan could not open %s" % path)
		if file == null:
			continue
		var lines := file.get_as_text().split("\n")
		for index in lines.size():
			scanned += 1
			equal(AssetCheck.first_match(lines[index]), {},
				"%s:%d reads as art" % [path, index + 1])
	check(scanned > 500, "the scan read only %d lines of the three files" % scanned)

	# And the run itself: every blow the five struck carried a sprite and a
	# motion out of the two vocabularies, and no frame carried anything else.
	for blow in played["blows"]:
		check(AssetTags.is_effect_sprite(String(blow["sprite"])),
			"a blow in the run carried the sprite '%s', which is not in the vocabulary"
				% String(blow["sprite"]))
		check(AssetTags.is_animation(String(blow["animation"])),
			"a blow in the run carried the motion '%s', which is not in the vocabulary"
				% String(blow["animation"]))


## The run this suite is about, played: the five in a line on the measured
## meadow, fought for `TICKS` ticks.
##
## Shared with the workbench that photographs it (`tools/swing_sheet.sh
## --patterns`), so the picture a person looks at and the claim the suite makes
## are one run and not two.
static func play(
	ticks: int = TICKS, seed_value: int = TestAttackClips.SEED
) -> Dictionary:
	return TestAttackClips.play(ticks, seed_value, _new_weapons(), BEARERS,
		BEARER_LOOKS, TestAttackClips.APART, LINE)


## The same fight, set out and not yet stepped, for a workbench that wants to
## step it a tick at a time and draw it.
static func stage(seed_value: int = TestAttackClips.SEED) -> Dictionary:
	return TestAttackClips.stage(seed_value, _new_weapons(), BEARERS,
		BEARER_LOOKS, TestAttackClips.APART, LINE)


## The five, in catalogue order, as the fixture takes them up.
static func _new_weapons() -> Array:
	return [
		Weapon.axe(), Weapon.greatsword(), Weapon.crossbow(),
		Weapon.wand(), Weapon.spellbook(),
	]
