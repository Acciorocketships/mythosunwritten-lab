extends RefCounted
## One character sheet: everything section 2 says a character *is*.
##
## There is exactly one of these types, and a character driven by a person and a
## character driven by an agent are both it. Nothing here asks which sort it is
## holding -- there is no field for it, no method that answers it and no branch
## that reads it -- because the design's "no preferential treatment" principle is
## only true if the two are the same object. The one thing that will ever differ
## between them is `decide`: the handle a control loop calls to choose the next
## atomic action. A sheet with a person on the other end of that handle and a
## sheet with an agent on the other end are, in every other respect, this file.
##
## What is on it, in section 2's order:
##
##   * the six ability scores, by name out of `Ability`;
##   * `level` -- battle strength, the number health, damage and every item's
##     power budget are computed from;
##   * status -- diplomatic standing, a *separate* attribute (see below);
##   * `health`, and the `max_health()` its level entitles it to;
##   * `inventory`, everything it carries and its money, with `equipment` a view
##     onto that rather than a second store;
##   * the identity: `backstory`, `goal`, `traits`, `tendencies`;
##   * `memory` and `sentiment`, the two handles the agent milestones fill.
##
## **Status is not the level, and it is not a copy of it.** Section 2 gives a
## character two threat numbers: `level` is military and `status` is diplomatic,
## and for a player character "status = level". That is written here without
## anyone having to say who is a player: `assigned_status` starts unassigned, and
## an unassigned status *reads the level*. A character nobody has assigned a
## standing to therefore has status equal to its level, forever, including
## through a level-up; the orchestrator assigning one is what makes the two
## numbers part. So the sentence "for the player, status = level" is the default
## behaviour of the sheet rather than a rule about a kind of character.
##
## **A score may be unrecorded, and that is not the same as zero.** Zero is a
## real ability score -- a character with six of them can wear nothing usefully.
## An unrecorded score is a character nobody has rolled yet, and it reads an item
## at that item's own level, which is to say in full. This is the rule the item
## layer has used since the power budget landed and it is unchanged here; what
## changed is only that the six numbers now live on a character instead of in a
## dictionary hanging off a board piece.
##
## **No classes, skills or learned spells.** Six scores, a level and a status are
## the whole of what a character *is*; everything a character can *do* lives on
## an item. There is deliberately nothing here to put a spell in.
class_name Character

## What `assigned_status` holds while nobody has assigned one. Negative, because
## every real standing is zero or more, so "unassigned" cannot collide with an
## assignment.
const UNASSIGNED := -1


## The six ability scores, by name out of `Ability`. A name absent from here is
## unrecorded, which is not zero -- see the note above.
var scores: Dictionary = {}

## Battle strength, section 2. Health, damage and the level an item is forged at
## are all read from this one number.
var level: int = 1

## Diplomatic standing, section 2, or `UNASSIGNED` while nobody has set one.
## Read it through `status()`, never directly: unassigned means "the level".
var assigned_status: int = UNASSIGNED

## Hit points left. Refilled from `max_health()` whenever the level is set, so a
## character is never born wounded.
var health: int = 0

## What it is called. Not an identity field in section 2's sense -- it is how a
## report and a failure message name the character.
var character_name: String = ""

## What it carries: weapons, armour, consumables and money, in one place.
##
## Section 2 lists money among what an inventory holds, so the money is in there
## and not a field of its own here. One character, one inventory, and everything
## the character owns is in it -- including the things it is wearing.
var inventory: Inventory = Inventory.new()

## What it has on, by slot: a *view* onto the inventory and not a second store.
##
## There is no setter, because there is nothing to set: being equipped is a slot
## of the inventory pointing at something the inventory carries, so equipping
## goes through `inventory.equip()` and reading what is equipped comes back
## through here. That is the whole of why nothing can be worn or held that the
## character does not have -- it is not checked anywhere, there is simply nowhere
## else for a worn thing to be.
var equipment: Dictionary:
	get:
		return inventory.equipment()

## Identity, section 2: who it was before the simulation started.
var backstory: String = ""

## Identity: what it is trying to do now. One goal, replaceable.
var goal: String = ""

## Identity: personality traits, in the character's own vocabulary.
var traits: PackedStringArray = PackedStringArray()

## Identity: behavioural tendencies -- greedy, cautious, aggressive, friendly.
var tendencies: PackedStringArray = PackedStringArray()

## Persistent memory: a first-person log of what happened to it. Empty, and a
## handle: the memory milestone decides what a remembered thing is.
var memory: Array = []

## How it feels about everyone it knows of, by that character's id. Empty, and a
## handle: section 6's ownership maths and section 10's relationship edges are
## what fill it.
var sentiment: Dictionary = {}

## The one thing that differs between a character a person drives and a character
## an agent drives: what is called to choose the next action. Unset here, and
## nothing in this file calls it -- the action interface is the next work item.
## It is a handle and never a kind: a sheet does not know, and cannot be asked,
## what is on the other end of it.
var decide: Callable = Callable()


## A sheet at a level, with its health filled in.
static func make(called: String = "", at_level: int = 1) -> Character:
	var sheet := Character.new()
	sheet.character_name = called
	return sheet.set_level(at_level)


## Set the level, and refill to the health that level gives.
##
## The same one-function rule the board pieces have always had: a level cannot be
## changed without the health that follows from it, because the alternative is
## two assignments at every call site and a character half converted between.
func set_level(to: int) -> Character:
	level = maxi(1, to)
	health = max_health()
	return self


## The hit points this character has at full, from its level alone.
func max_health() -> int:
	return Damage.commander_health(level)


## Its diplomatic standing: what was assigned, or its level if nothing was.
##
## This is the whole of "for the player, status = level". No caller says who is a
## player; a character with no assigned standing simply tracks its own level.
func status() -> int:
	return level if assigned_status < 0 else assigned_status


## Assign a diplomatic standing, parting it from the level.
func set_status(to: int) -> Character:
	assigned_status = maxi(0, to)
	return self


## Give up an assigned standing, so status tracks the level again.
func clear_status() -> Character:
	assigned_status = UNASSIGNED
	return self


## One ability score. `if_unrecorded` is what a name nobody has rolled reads as,
## and the item gate hands in the item's own level for it, which reads the item
## in full.
func score(ability: String, if_unrecorded: int = 0) -> int:
	return int(scores.get(ability, if_unrecorded))


## Whether a score has been recorded at all. Recording one is what makes the
## item gate bite.
func has_score(ability: String) -> bool:
	return scores.has(ability)


## Record one ability score.
func set_score(ability: String, value: int) -> Character:
	scores[ability] = value
	return self


## Record all six at once, by name. Names that are not one of the six are
## ignored rather than stored, because a score under a typo is a score the gate
## can never read.
func record_scores(rolled: Dictionary) -> Character:
	for ability in Ability.ALL:
		if rolled.has(ability):
			scores[ability] = int(rolled[ability])
	return self


## Level up: one level, and one point on one named ability score.
##
## Section 2 gives level-up exactly one effect on the sheet beyond the level
## itself, and this is the whole body of the function: one score goes up by one,
## the level goes up by one, and the health that follows from a level follows it.
## Nothing else on the sheet is written, so nothing else on the sheet can move --
## not the other five scores, not the status, not a word of the identity. A name
## that is not one of the six spends the point on nothing and is refused, level
## and all, because a level-up that quietly lost its point would be worse than
## one that did not happen.
func level_up(ability: String) -> bool:
	if not Ability.is_ability(ability):
		return false
	scores[ability] = score(ability) + 1
	set_level(level + 1)
	return true


## The six scores in section 2's order, for a report and a failure message. An
## unrecorded score prints as a dash, because it is not a zero.
func scores_line() -> String:
	var parts := PackedStringArray()
	for ability in Ability.ALL:
		parts.append("%s %s" % [
			ability, "-" if not has_score(ability) else str(score(ability)),
		])
	return " ".join(parts)


## The whole sheet in one line, in the form the reports and the tests compare.
func sheet_line() -> String:
	return "%s level=%d status=%d hp=%d/%d [%s]" % [
		"-" if character_name == "" else character_name,
		level, status(), health, max_health(), scores_line(),
	]


## The identity in one line. Kept apart from `sheet_line()` on purpose: the
## numbers are what the combat layer reads and these are what an agent reads.
func identity_line() -> String:
	return "%s | goal: %s | traits: %s | tendencies: %s" % [
		"-" if backstory == "" else backstory,
		"-" if goal == "" else goal,
		"-" if traits.is_empty() else ", ".join(traits),
		"-" if tendencies.is_empty() else ", ".join(tendencies),
	]
