extends RefCounted
## The armoury: every held shape the catalogue ships, in somebody's hands, and
## one character who changes gear on a schedule.
##
## Two things stand on the measured meadow and both exist to be looked at:
##
##   * **the rack** -- one commander per catalogue shape, in a west-to-east
##     line, each wielding a forged weapon of one shape: sword, spear, dagger,
##     bow, staff, flail, shield, and then the five the art packs were already
##     carrying before anything could be one -- greatsword, axe, crossbow, wand,
##     spellbook. Nobody moves and nobody fights -- everyone is enrolled into one
##     band, so the engagement rule has nobody to pair.
##   * **the changer** -- one more commander, standing apart, holding a sword
##     and carrying a shield. On a tick schedule it swaps the shield into its
##     hand, swaps the sword back, and finally takes everything off -- through
##     `Action.equip` and `Action.unequip` on the world's own control loop, the
##     same calls a person's key presses become, so what changes its gear is
##     the engine and never a script reaching into an inventory.
##
## Nothing here decides anything the engine does not: the scenario chooses
## which action and when, `ActionEngine` resolves it, and two processes print
## the same world. That is the same division every scripted scenario keeps.
##
## What this is *for*: the render layer draws what a character holds off the
## snapshot, and this is the stage that shows every drawable shape held at once
## and a hand whose contents change mid-run. The suite steps it headless;
## `./run_render.sh --scenario armoury` photographs it.
class_name ScriptedArmoury

## The seed and the ground the rack stands on: the same measured open meadow
## the encounter scenario fights in, so no new claim is made about the world.
const SEED := ScriptedEncounter.SEED
const WHERE := ScriptedEncounter.WHERE

## What level everyone is. One constant for the reason the encounter has one:
## a level is health and a weapon budget at once.
const LEVEL := 2

## How far apart along x the rack stands, in world units. Wider than a
## character, so seven of them read as seven.
const SPACING := 2.5

## Which way everybody faces: along +z, so a camera south of the line sees
## every held thing front-on.
const FACING := PI * 0.5

## Where the changer stands, as an offset from `WHERE`: a step south-east of
## the rack, so a camera on the changer holds the rack behind it. Probed, not
## guessed: the meadow drops into a stream channel from about two units south
## of the rack line (ground -2.03 on the line, -4.77 six units south), and this
## spot is on the level ground beside it (-2.2).
const CHANGER_AT := Vector2(1.25, 2.0)

## The changer's schedule, in world ticks: when the shield goes into the hand
## (displacing the sword), when the sword comes back (displacing the shield),
## and when the hand is emptied. Each change is an action the engine charges
## ticks for, so the beats are spaced well past `equip`'s cost.
const SWAP_AT := 12
const BACK_AT := 30
const BARE_AT := 48

## How long the changer waits between looks at its schedule, and how long once
## the schedule is done. Short enough that a beat lands within a few ticks of
## its stated tick, long enough that the transcript is not all waiting.
const WATCH := 3
const REST := 30

## What the changer's two items are called: `Weapon.held` names a forged item
## "<rarity> <shape>", and these are those names read back, because an equip
## action names an item and a second spelling here would be a second answer.
const SWORD_NAME := "%s %s" % [ItemRarity.COMMON, "sword"]
const SHIELD_NAME := "%s %s" % [ItemRarity.COMMON, "shield"]

## The changer's name, and the rack's: a bearer is named for what it bears, so
## a transcript line reads as what it shows.
const CHANGER := "Hazel"

## The rack, in line order: the shape each bearer wields and the character tag
## it is drawn as. Every rigged adventurer and skeleton tag the table ships is
## someone here, so the same frame also shows the shared rig wearing gear on
## more than one body -- twelve bearers across ten tags, the two repeats being
## the knight who holds both swords and the barbarian who holds both hafts.
const RACK := [
	{"shape": "sword", "tag": AssetTags.KNIGHT},
	{"shape": "spear", "tag": AssetTags.BARBARIAN},
	{"shape": "dagger", "tag": AssetTags.ROGUE},
	{"shape": "bow", "tag": AssetTags.RANGER},
	{"shape": "staff", "tag": AssetTags.MAGE},
	{"shape": "flail", "tag": AssetTags.SKELETON_WARRIOR},
	{"shape": "shield", "tag": AssetTags.HOODED_ROGUE},
	{"shape": "greatsword", "tag": AssetTags.KNIGHT},
	{"shape": "axe", "tag": AssetTags.BARBARIAN},
	{"shape": "crossbow", "tag": AssetTags.SKELETON_ROGUE},
	{"shape": "wand", "tag": AssetTags.SKELETON_MAGE},
	{"shape": "spellbook", "tag": AssetTags.SKELETON_MINION},
]


## Set the stage out in a world and hand back how many characters stand on it.
static func muster(world: SimWorld) -> int:
	world.clear_cast()
	var roster := world.combat

	var band := 0
	var across := -float(RACK.size() - 1) * 0.5 * SPACING
	for row in RACK:
		var one := roster.add(Combatant.commander_at(
			WHERE.x + across, WHERE.y, FACING, 0.0, LEVEL, String(row["tag"])))
		across += SPACING
		# One band for everyone: bands are teams, and a rack of commanders each
		# its own band would be a brawl by the engagement rule.
		if band == 0:
			band = one.id
		else:
			one.band = band
		(one.piece as Commander).wield(
			Weapon.held(Weapon.shaped_like(String(row["shape"])), LEVEL))
		_name_and_roll(one, String(row["shape"]).capitalize())

	var changer := roster.add(Combatant.commander_at(
		WHERE.x + CHANGER_AT.x, WHERE.y + CHANGER_AT.y,
		FACING, 0.0, LEVEL, AssetTags.HOODED_ROGUE))
	changer.band = band
	_name_and_roll(changer, CHANGER)
	(changer.piece as Commander).wield(Weapon.held(Weapon.sword(), LEVEL))
	ActionScene.inventory_of(changer).carry(Weapon.held(Weapon.shield(), LEVEL))
	_sheet(changer).decide = DecisionSource.scripted(ScriptedArmoury._changing)

	# The camera follows the changer, the way the battle scenario follows one
	# of its fighters: it stands south of the rack facing the camera, so one
	# frame holds its hands in front and the whole rack behind them.
	world.follow(changer.id)

	for one in roster.members:
		one.settle(world.terrain)
	return roster.size()


## What the changer does when the control loop asks: read the clock, read its
## own hand, and choose the next change the schedule calls for -- or wait.
##
## Read off the inventory rather than off a step counter, so a change that has
## already landed is never asked for twice and the rule is a function of the
## scene it is handed.
static func _changing(scene: ActionScene, actor: Combatant) -> Action:
	var holding := _holding(actor)
	if scene.tick >= BARE_AT:
		return Action.unequip(holding) if holding != "" else Action.wait(REST)
	if scene.tick >= BACK_AT:
		return Action.equip(SWORD_NAME) if holding != SWORD_NAME else Action.wait(WATCH)
	if scene.tick >= SWAP_AT:
		return Action.equip(SHIELD_NAME) if holding != SHIELD_NAME else Action.wait(WATCH)
	return Action.wait(WATCH)


## The name of what a combatant holds in its hand, or "" for an empty one.
static func _holding(actor: Combatant) -> String:
	var pack := ActionScene.inventory_of(actor)
	if pack == null:
		return ""
	var item := Inventory.item_of(pack.equipped_in(Item.SLOT_HAND))
	return "" if item == null else item.item_name


static func _name_and_roll(one: Combatant, called: String) -> void:
	var sheet := (one.piece as Commander).sheet
	sheet.character_name = called
	sheet.record_scores(ScriptedEncounter.ROLL)


static func _sheet(one: Combatant) -> Character:
	return (one.piece as Commander).sheet
