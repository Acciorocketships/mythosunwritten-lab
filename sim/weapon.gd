extends RefCounted
## An item that carries one or more effects, and the budget those effects are
## bought with.
##
## A weapon is two things held together: a *shape* -- which cells each of its
## attacks covers, how long each waits, which art says so -- and an `Item`, whose
## power budget says how much of that shape a particular wielder actually gets.
## The shape is the catalogue below. The numbers come off the item and are read
## through its ability-score gate, so the same sword deals different damage in
## two different hands and neither reading changes the object.
##
## ## The catalogue is data, not code
##
## Every weapon below is one call to `Attack.compose` and a handful of numbers.
## There is no branch anywhere in this layer that asks which weapon it is
## holding: a spear is a short line, a bow is a ring at a distance, a fireball is
## a block of cells offset ahead, an arrow is the same thing with its movement
## set to `projectile`, and the code that turns any of them into cells on a board
## is the same code. That is the test of whether the base is general enough, and
## it is why the catalogue lives here as constructors rather than as special
## cases elsewhere.
##
## ## The seven, and why the numbers are shaped the way they are
##
## | weapon | attack | cells | cooldown | damage | movement | sprite | animation |
## |---|---|---|---|---|---|---|---|
## | spear | thrust | 2 | 1 | 8 | instant | point | lunge |
## | dagger | stab | 2 | 1 | 6 | instant | blade | slash |
## | sword | cut | 3 | 1 | 10 | instant | blade | slash |
## | sword | cleave | 6 | 3 | 16 | instant | blade | swing |
## | bow | loose | 248 | 3 | 12 | projectile | arrow | shoot |
## | staff | fireball | 9 | 5 | 4 | instant | flame | cast |
## | flail | sweep | 8 | 1 | 5 | instant | impact | spin |
## | shield | shove | 1 | 2 | 0, pushes 1 | instant | impact | bash |
##
## The damage column is no longer a number the fight reads directly. It is the
## *weight* by which an attack takes its share of the item's effects axis, so a
## sword is "ten parts cut to sixteen parts cleave" whatever it is worth, and the
## numbers above are recovered exactly when that axis equals their sum. A weapon
## with no item behind it reads at precisely that sum, which is why every number
## in the table is still the answer for one. The cooldown column is the wait
## before any of the item's movement axis is spent shortening it.
##
## ## The null item is a reporting path, not an equipping path
##
## The fallback survives, and it survives for one job: it is how the catalogue
## states its own reference numbers -- the table above, and the reports and
## tests that quote it -- without having to name a level and a rarity to say
## what a sword's shape is. It is *not* a way to equip anybody. A weapon with no
## item has no power budget behind it, no item level, no rarity, and no ability
## score can gate it, so a commander holding one carries damage nothing paid for
## and nothing reaches. Nothing under sim/ may hand one over: every weapon a
## scenario gives out goes through `held()`, and
## `tests/test_effects.gd::_every_weapon_handed_out_has_an_item_behind_it`
## scans sim/ line by line to keep it that way.
##
## The staff is the one the design names a constraint for: "a cheap low-damage
## AOE can't free-clear an army". Four damage against a level-1 minion's defence
## of two is two points against ten hit points, so nine cells of fireball leave
## nine minions standing. The cleave, at sixteen over three turns, kills a level-1
## minion outright and does almost nothing to a level-8 one. That contrast is the
## whole of section 3.7's "attack type matters", and it is a consequence of the
## numbers here meeting `Damage`'s level scaling, not a rule anywhere.
class_name Weapon

## What it is called.
var weapon_name: String = ""

## The attacks it carries, in the order they were given.
var attacks: Array[Attack] = []

## The item behind it, or null for the catalogue's own reading of itself. Every
## number a wielder actually gets -- the damage of each attack and how long it
## waits -- is read off this and gated by the wielder's ability score.
var item: Item = null


static func make(called: String, carried: Array[Attack]) -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = called
	weapon.attacks = carried
	return weapon


## How many attacks this weapon carries.
func attack_count() -> int:
	return attacks.size()


## One attack by position, or null for a position it does not have.
func attack_at(index: int) -> Attack:
	if index < 0 or index >= attacks.size():
		return null
	return attacks[index]


# --- What the budget buys -------------------------------------------------
#
# Section 4: all abilities live on items, and an item's power is one budget split
# across movement, defence and effects. A held item's attacks *are* its effects,
# so the effects axis is what its blows are bought with -- and the movement axis
# buys the same thing it buys on a worn item, cells, except that here a cell
# bought is a cell of pattern it no longer has to wait a turn for.


## Put an item behind a catalogue shape. The attacks are the shape's -- which
## cells, which art, which base wait -- and every number comes off the item from
## here on. The name stays the shape's, because what a thing is called is not
## what it is worth.
static func from_item(shape: Weapon, behind: Item) -> Weapon:
	var weapon := make(shape.weapon_name, shape.attacks)
	weapon.item = behind
	return weapon


## A catalogue shape carried as an item forged at a level and a rarity.
##
## What is not spent on the other two axes goes to effects, and on a held item
## the effects *are* the attacks -- so the default, spending nothing on moving
## and nothing on parrying, is a weapon that is all blow. The effects axis is
## carried by one named effect, the shape's own name, because the item layer
## stores an axis as the effects that bought it.
static func held(
	shape: Weapon,
	at_level: int,
	of_rarity: String = ItemRarity.COMMON,
	spent_on_moving: int = 0,
	spent_on_defending: int = 0,
) -> Weapon:
	var total := ItemBudget.total(of_rarity, at_level)
	var moving := clampi(spent_on_moving, 0, total)
	var defending := clampi(spent_on_defending, 0, total - moving)
	var weights: Array[int] = [moving, defending, total - moving - defending]
	var names: Array[String] = [shape.weapon_name]
	return from_item(shape, Item.weapon(
		"%s %s" % [of_rarity, shape.weapon_name], at_level, of_rarity,
		Ability.STR, weights, names, [] as Array[int],
		ItemModel.for_shape(shape.weapon_name)
	))


## An item held with no catalogue shape behind it.
##
## What somebody picks up off the ground is an `Item`; which of the catalogue's
## shapes it swings as is a question the forge and the catalogue do not yet meet
## over. Until they do, an item taken up bare is this: it defends its holder out
## of its own defence axis, exactly as it would in any other hand, and it carries
## no attack, because an attack pattern is the catalogue's and holding a thing
## does not invent one. It is the opposite case to a shape with no item -- that
## one has attacks nothing paid for; this one has a budget and nothing to spend
## it swinging.
static func around(behind: Item) -> Weapon:
	var weapon := make("" if behind == null else behind.item_name, [] as Array[Attack])
	weapon.item = behind
	return weapon


## The catalogue shape a word names, or null for a word that names none.
##
## The forge draws one of six words for a held item and the catalogue ships seven
## shapes under nine names; this is the two vocabularies meeting, and it is the
## same meeting `ItemModel.BY_SHAPE` records for what the thing looks like. A
## sword and a dagger are both a blade -- to the eye by that table, and to the
## hand by this one, where a blade swings as the sword because the sword is the
## blade the catalogue writes in full.
static func shaped_like(shape: String) -> Weapon:
	match shape:
		"blade", "sword":
			return sword()
		"dagger":
			return dagger()
		"spear":
			return spear()
		"bow":
			return bow()
		"staff":
			return staff()
		"flail":
			return flail()
		"buckler", "shield":
			return shield()
	return null


## A forged item, held as the shape it was drawn as.
##
## This is the meeting `around()` above says the forge and the catalogue do not
## yet have: an item whose shape was recorded swings as that shape, with every
## number -- the damage of each attack and how long it waits -- read off the item
## and gated by the wielder's ability score, exactly as `held()` reads them for a
## shape forged at a level. An item with no shape recorded is still `around()`'s
## case and still carries no attack, because there is still nothing to say what
## pattern it would swing in.
static func for_item(behind: Item) -> Weapon:
	if behind == null:
		return null
	var shape := shaped_like(behind.shape)
	return around(behind) if shape == null else from_item(shape, behind)


## How the effects axis is divided among the attacks: by the catalogue's own
## damage numbers, used as weights.
##
## That is what makes the catalogue a *shape* rather than a table of stubs. A
## sword is "ten parts cut to sixteen parts cleave" whatever it is worth, and the
## numbers written in the catalogue are recovered exactly when the effects axis
## equals their sum -- which is what a weapon with no item behind it reads.
func damage_weights() -> Array[int]:
	var weights: Array[int] = []
	for attack in attacks:
		weights.append(attack.damage)
	return weights


## The effects axis at which the catalogue's numbers are the answer: their sum.
func reference_power() -> int:
	return ItemBudget.sum(damage_weights())


## The points its blows are bought with, for a wielder with this score: the
## item's effects axis as that wielder reads it, or the catalogue's own total
## when there is no item behind the shape.
##
## That second branch is a *reporting* path and not an equipping one. It is how
## the catalogue reads itself -- the table at the top of this file, and the
## reports that publish it -- and it answers with numbers no budget paid for and
## no ability score gates, which is exactly why nothing under sim/ hands a
## commander a weapon that takes it. See the note at the top of the file.
func power_for(score: int) -> int:
	return reference_power() if item == null else item.effects_for(score)


## What one attack deals for that wielder, before any modifier and before the
## target's defence.
##
## A weapon whose attacks all deal nothing divides nothing among them however
## large its budget: a shield is a shield, and its shove is a push and not a
## blow.
func damage_of(index: int, score: int) -> int:
	if index < 0 or index >= attacks.size():
		return 0
	var weights := damage_weights()
	if ItemBudget.sum(weights) <= 0:
		return 0
	return ItemBudget.split(power_for(score), weights)[index]


## How long that wielder waits between two uses of an attack.
##
## One point of the item's movement axis buys one cell of the attack's pattern;
## enough points to buy the whole pattern take one turn off the wait. So speeding
## up a wide attack costs what its width costs, and no attack comes round faster
## than once a turn, because a turn is the smallest thing there is.
@warning_ignore("integer_division")
func cooldown_of(index: int, score: int) -> int:
	var attack := attack_at(index)
	if attack == null:
		return 0
	var bought := 0
	if item != null:
		bought = item.movement_for(score) / maxi(1, attack.cell_count())
	return maxi(Attack.EVERY_TURN, attack.cooldown - bought)


## What the whole weapon is worth to that wielder, in one line, in the form the
## reports and the tests compare.
func line_for(score: int) -> String:
	var parts := PackedStringArray()
	for index in attacks.size():
		parts.append("%s:%d/%d" % [
			attacks[index].attack_name, damage_of(index, score), cooldown_of(index, score),
		])
	return "%s %s" % [weapon_name, " ".join(parts)]


# --- The design's examples ------------------------------------------------
#
# Section 3.5: "spear = front; dagger = diagonal; sword = front + diagonals;
# bow = ring at distance 5-10; fireball = 3x3 AOE within range; flail =
# all-around but lower damage."


## Front: two cells straight ahead. The reach weapon, and the narrowest pattern
## there is -- it covers nothing at all to either side.
static func spear() -> Weapon:
	var ahead: Array[Vector2i] = [Vector2i(0, -1)]
	return make("spear", [
		Attack.compose({
			"name": "thrust",
			"shape": PieceGeometry.line(ahead, 1, 2),
			"cooldown": 1,
			"damage": 8,
			"sprite": AssetTags.EFFECT_POINT,
			"animation": AssetTags.ANIM_LUNGE,
		}),
	])


## Diagonal: the two cells off the attacker's front corners. What a backstab is
## aimed with, and the shortest-cooldown attack in the catalogue.
static func dagger() -> Weapon:
	return make("dagger", [
		Attack.compose({
			"name": "stab",
			"shape": [Vector2i(-1, -1), Vector2i(1, -1)] as Array[Vector2i],
			"cooldown": 1,
			"damage": 6,
			"sprite": AssetTags.EFFECT_BLADE,
			"animation": AssetTags.ANIM_SLASH,
		}),
	])


## Front and the diagonals beside it, and a heavier sweep of the same arc two
## cells out. Two attacks on one item, and the cheaper one is the quicker: this
## is where "a stronger attack waits longer" is visible inside a single weapon.
static func sword() -> Weapon:
	var arc: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	return make("sword", [
		Attack.compose({
			"name": "cut",
			"shape": arc,
			"cooldown": 1,
			"damage": 10,
			"sprite": AssetTags.EFFECT_BLADE,
			"animation": AssetTags.ANIM_SLASH,
		}),
		Attack.compose({
			"name": "cleave",
			"shape": PieceGeometry.line(arc, 1, 2),
			"cooldown": 3,
			"damage": 16,
			"sprite": AssetTags.EFFECT_BLADE,
			"animation": AssetTags.ANIM_SWING,
		}),
	])


## A ring at five to ten cells. Symmetric about the archer, so it rotates onto
## itself -- a bow does not have a front, and the pattern says so rather than a
## flag saying so.
##
## The one weapon of the seven whose effect travels: what it fires crosses the
## ground between the archer and where it lands, and the tag on it is the arrow.
## No number of it moved to say so.
static func bow() -> Weapon:
	return make("bow", [
		Attack.compose({
			"name": "loose",
			"shape": PieceGeometry.ring(5.0, 10.0),
			"cooldown": 3,
			"damage": 12,
			"movement": Attack.PROJECTILE,
			"sprite": AssetTags.EFFECT_ARROW,
			"animation": AssetTags.ANIM_SHOOT,
		}),
	])


## A three-by-three block landing four cells ahead: the area attack. The longest
## cooldown in the catalogue, on the widest pattern.
static func staff() -> Weapon:
	return make("staff", [
		Attack.compose({
			"name": "fireball",
			"shape": PieceGeometry.block(Vector2i(0, -4), 1),
			"cooldown": 5,
			"damage": 4,
			"effects": ["flame"],
			"sprite": AssetTags.EFFECT_FLAME,
			"animation": AssetTags.ANIM_CAST,
		}),
	])


## Every cell touching the wielder. Symmetric, like the bow, for the same reason
## and by the same rotation.
static func flail() -> Weapon:
	return make("flail", [
		Attack.compose({
			"name": "sweep",
			"shape": PieceGeometry.ring(1.0, 1.5),
			"cooldown": 1,
			"damage": 5,
			"sprite": AssetTags.EFFECT_IMPACT,
			"animation": AssetTags.ANIM_SPIN,
		}),
	])


## One cell straight ahead, no damage, and a push of one. The shove of section
## 3.2, and it is an ordinary item carrying an ordinary attack: the pattern is
## written facing north like every other, it turns with its wielder like every
## other, it is clipped to the board like every other, and it waits two turns.
##
## What makes it lethal is not the item. It is where the target is standing --
## over a hole, or on the lip of a fall -- which is the board's answer and not
## the weapon's.
static func shield() -> Weapon:
	return make("shield", [
		Attack.compose({
			"name": "shove",
			"shape": [Vector2i(0, -1)] as Array[Vector2i],
			"cooldown": 2,
			"damage": 0,
			Attack.PUSH: 1,
			"sprite": AssetTags.EFFECT_IMPACT,
			"animation": AssetTags.ANIM_BASH,
		}),
	])


## Every weapon the catalogue holds, in a fixed order. What a report tabulates
## and what a test walks.
static func catalogue() -> Array[Weapon]:
	return [spear(), dagger(), sword(), bow(), staff(), flail(), shield()]


# --- Two the earlier representation could not hold ------------------------
#
# Section 4's own examples, and the reason the base exists: "An arrow is 'an
# attack with projectile movement + arrow sprite'; magic missile = projectile +
# split + homing."
#
# Neither of these is a class, a kind, or a flag anything branches on. Each is
# the same `Attack.compose` call the seven above are, with different values in
# fields that were already there. Before the base there was nowhere to put
# "travels", "divides itself" or "bends towards a target", so neither could be
# said at all; after it, neither costs a line of code anywhere else.


## An arrow: a lane of cells two to twelve ahead, crossed rather than covered.
##
## Everything about it that is new is a field. Its movement is `projectile`, so
## it passes through what stands between the archer and the target instead of
## appearing on it; its sprite is the arrow; its motion is the shot. The pattern
## generator, the rotation, the cooldown and the damage are the spear's.
static func arrow() -> Attack:
	var ahead: Array[Vector2i] = [Vector2i(0, -1)]
	return Attack.compose({
		"name": "arrow",
		"shape": PieceGeometry.line(ahead, 2, 12),
		"cooldown": 2,
		"damage": 12,
		"movement": Attack.PROJECTILE,
		"sprite": AssetTags.EFFECT_ARROW,
		"animation": AssetTags.ANIM_SHOOT,
	})


## A magic missile: a projectile that splits and homes.
##
## Three properties and nothing else. `projectile` movement, so it crosses the
## ground; a split of three, so its ten damage divides into 4, 3 and 3 -- exactly,
## by the same largest-remainder rule the rest of the project divides things by;
## and a homing reach of one, so every cell of its ring brings its eight
## neighbours with it. A ring, so it has no front and rotates onto itself.
static func magic_missile() -> Attack:
	return Attack.compose({
		"name": "magic missile",
		"shape": PieceGeometry.ring(2.0, 6.0),
		"cooldown": 3,
		"damage": 10,
		"movement": Attack.PROJECTILE,
		Attack.SPLIT: 3,
		Attack.HOMING: 1,
		"effects": ["arcane"],
		"sprite": AssetTags.EFFECT_BOLT,
		"animation": AssetTags.ANIM_CAST,
	})


## The two composed items, each on a weapon so it can actually be taken up and
## used by the same code that uses a spear. In a fixed order, like the catalogue.
static func composed() -> Array[Weapon]:
	return [
		make("hunting bow", [arrow()]),
		make("wand", [magic_missile()]),
	]
