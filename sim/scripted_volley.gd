extends RefCounted
## Three commanders and two things that fly: the ranged scenario.
##
##     ./run_headless.sh --scenario volley
##     ./run_render.sh --scenario volley
##
## Every other fight this project stages is settled with instant weapons -- a
## sword lands where it is aimed and nothing crosses the ground. This one exists
## so that a seeded, watchable run has effects that *travel*: an archer whose
## arrows cross the board, a mage whose magic missile is section 4's own example
## of a composition -- projectile movement, a split of three, a homing reach of
## one -- and a swordsman between them whose blows land instantly, so the same
## record shows both kinds side by side.
##
## Like every scenario, this file decides nothing about the fight. It stands
## three commanders on the measured meadow, hands them forged weapons, and
## begins the fight the way `sim/scripted_strike.gd` does; every move and every
## blow after that is `CombatPolicy`'s, and the record of each blow leaves
## through the snapshot exactly as every other fight's does. There is no policy,
## no search and no language model here.
##
## The levels are the attack-clips fixture's idiom: tough commanders holding
## weak weapons make a long fight, and a long fight is one where the bow's and
## the wand's cooldowns come round again and again -- a volley, not a shot.
class_name ScriptedVolley

## The seed the scenario is written for, and the measured open meadow every
## other walkthrough is played on, so this run invents no coordinate.
const SEED := ScriptedEncounter.SEED
const WHERE := ScriptedEncounter.WHERE

## The seed the control loop's continue-bias draws are hashed from. Nobody here
## has a decision function, so the loop only moves the clock -- but a blow that
## says which tick it began on needs a clock that runs.
const LOOP_SEED := 77

## Who fights, and what each of them looses.
##
## | name | weapon | movement | what flies |
## |---|---|---|---|
## | Yew | bow (loose) | projectile | an arrow |
## | Sorrel | wand (magic missile) | projectile, split 3, homing 1 | a bolt |
## | Thorn | sword (cut, cleave) | instant | nothing |
const ARCHER := "Yew"
const MAGE := "Sorrel"
const SWORD := "Thorn"

## How far out from the middle each stands when the fight begins, in world
## units. The bow's ring reaches five to ten cells and the wand's two to six;
## at eight world-unit-triples apart everyone starts inside somebody's pattern
## and `CombatPolicy` walks the rest into range.
const APART := 12.0

## How long the scenario is watched for, in ticks: long enough for several
## volleys on the bow's three-turn cooldown and the wand's three-turn one.
const TICKS := 240

## Tough people, weak weapons -- the attack-clips fixture's numbers, for the
## fixture's reason: the fight must outlast every cooldown several times over.
const LEVEL := 20
const WEAPON_LEVEL := 1

## Ability scores for everybody, one roll shared: nothing here turns on a score
## differing, and STR above `WEAPON_LEVEL` reads every forged weapon in full.
const ROLL := {
	Ability.STR: 5,
	Ability.CON: 4,
	Ability.CHA: 3,
	Ability.DEX: 4,
	Ability.WIS: 3,
	Ability.INT: 2,
}

## Where the observer stands to watch: just off the middle of the triangle,
## still, so a camera at the observer has all three fighters -- and everything
## flying between them -- around it.
const WATCH_FROM := Vector2(2.0, 5.0)


## Stand the three up in a world and begin the fight. Returns true when the
## board took everyone.
static func muster(world: SimWorld) -> bool:
	world.clear_cast()
	world.place_observer(WHERE.x + WATCH_FROM.x, WHERE.y + WATCH_FROM.y)
	var roster := world.combat

	var archer := roster.add(Combatant.commander_at(
		WHERE.x - APART, WHERE.y, 0.0, 0.0, LEVEL, AssetTags.RANGER))
	(archer.piece as Commander).wield(Weapon.held(Weapon.bow(), WEAPON_LEVEL))
	_name_and_roll(archer, ARCHER)

	var mage := roster.add(Combatant.commander_at(
		WHERE.x + APART, WHERE.y, 0.0, 0.0, LEVEL, AssetTags.MAGE))
	(mage.piece as Commander).wield(
		Weapon.held(Weapon.composed()[1], WEAPON_LEVEL))
	_name_and_roll(mage, MAGE)

	var sword := roster.add(Combatant.commander_at(
		WHERE.x, WHERE.y - APART, 0.0, 0.0, LEVEL, AssetTags.KNIGHT))
	(sword.piece as Commander).wield(Weapon.held(Weapon.sword(), WEAPON_LEVEL))
	_name_and_roll(sword, SWORD)

	for one in roster.members:
		one.settle(world.terrain)

	var began := roster.scene.begin_fight(archer.id)
	return began != null and not began.refused


# Name a commander this scenario stood up and roll its six ability scores --
# the same two lines every scenario writes, because `Commander.make` starts a
# sheet with a blank name and no scores on it.
static func _name_and_roll(one: Combatant, called: String) -> void:
	var sheet := (one.piece as Commander).sheet
	sheet.character_name = called
	sheet.record_scores(ROLL)
