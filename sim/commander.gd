extends Piece
## A character on the board: the wildcard of section 3.3, and the king.
##
## Three things separate a commander from a minion, and all three are here.
##
## **It has a facing, and turning is free.** `face()` takes no turn and no
## action, and it cannot take one: it sets a direction and touches nothing else,
## not a cooldown, not a cell, not a piece. Every attack pattern is written for a
## commander facing north and rotated by the facing when its cells are asked for,
## so an attack aimed at the front reaches nothing behind until the commander
## turns -- and a pattern that is symmetric about its wielder, a bow's ring or a
## flail's sweep, rotates onto itself and covers the same cells whichever way it
## looks. Section 3.5's backstab, flanking and guarding a lane are all that one
## rotation.
##
## **Its movement is its armour, and its armour is its power budget.** The base
## is one cardinal step. Each piece worn may add a movement grant, and the
## commander's move pattern is the union of the base and all of them. Boots add
## the diagonal, so base and boots is a king; leggings add the knight's hop; a
## chestplate with enough on its movement axis adds a queen-like slide of up to
## two cells. Wearing several produces a piece that does not exist in chess,
## which is exactly section 3.4's intent -- and *which* grants a loadout gives is
## decided by what its items paid for, so the balancing lever is the budget and
## there is no cap written here.
##
## **It is a character, and a minion is not.** A commander carries section 2's
## character sheet -- the six ability scores its gear is read against, its level,
## its status, its health and its identity -- and `level` and `health` are the
## sheet's, read and written straight through. A character a person drives and a
## character an agent drives are the same `Character`; nothing in this file asks
## which of the two it has, and there is nothing here that could answer.
##
## **It captures with a weapon, not by walking.** `capture_grants()` is empty. A
## minion takes a cell by moving onto it; a commander reaches cells its feet
## never touch, in patterns that come off the item in its hands and sit on their
## own cooldowns. What happens in those cells is the resolution step's business.
class_name Commander

## The turn cooldowns are counted in. Nothing here advances it -- a turn number
## is handed in by whoever is asking, because the turn economy that would own one
## does not exist yet and this layer must not grow a private copy of it.
const FIRST_TURN := 1

## Which way it looks: one of PieceGeometry's four facings.
var facing: int = PieceGeometry.NORTH

## What it wears, kept in slot order so that two commanders equipped in
## different orders are the same commander.
##
## A view onto the character's inventory and not a store of its own: what is
## worn is which slots of `sheet.inventory` point at which of the things that
## inventory carries, so a commander cannot be wearing something its character
## does not have. Reading this builds the list in slot order out of the
## inventory; there is nothing to assign to, because equipping is
## `equip()` and taking off is `unequip()`.
var armour: Array[Armour]:
	get:
		return sheet.inventory.worn()

## What it holds, or null for empty hands. The same view, of the hand slot.
var weapon: Weapon:
	get:
		return sheet.inventory.held()

## The character this commander is: section 2's sheet, whole.
##
## The six ability scores its gear is read against, its level, its status, its
## health and its identity all live there and nowhere else. This is a handle and
## not a copy -- `level` and `health` are read and written straight through to
## the sheet by the four accessors at the foot of this file -- so a commander and
## its character cannot come to hold two different levels.
##
## What is *not* on the sheet is a default ability score. A score nobody has
## recorded is not zero -- zero is a real score, and a commander with six of them
## could wear nothing -- so an unrecorded score reads the item at its own level,
## which is to say in full. Recording one is what makes the gate bite, and it is
## what the worked example does.
var sheet: Character = Character.new()

# For each attack of the held weapon, the earliest turn it may next be used on.
# An attack absent from here has never been used and is ready. Recording the turn
# it becomes ready rather than a countdown means nothing has to be ticked, so
# nothing can be ticked twice or forgotten.
var _ready_on: Dictionary = {}


## A commander standing on a cell, looking a way, wearing an appearance tag.
static func make(
	at: Vector2i,
	looking: int = PieceGeometry.NORTH,
	looks_like: String = AssetTags.KNIGHT,
	at_level: int = 1,
) -> Commander:
	var commander := Commander.new()
	commander.cell = at
	commander.facing = looking
	commander.appearance = looks_like
	commander.set_level(at_level)
	return commander


## Level-scaled hit points, and nothing else scaled by level.
##
## A commander's defence is deliberately *not* a function of its level: it is
## what the items it carries spent on their defence axis, and its damage is what
## the item in its hands spent on its effects axis. That is section 4's
## arrangement -- power arrives on items -- and it is what keeps the level gap
## from making a duel unwinnable on both sides at once. Levels reach the numbers
## anyway, because an item's budget is the level of whatever dropped it.
func max_health() -> int:
	return sheet.max_health()


## What a blow landing on this commander is reduced by.
##
## Every item it carries -- the four worn slots and the thing in its hands --
## offers the points on its defence axis, as *this* commander reads them through
## the gate; the heap is turned into reduction once, by `Armour.reduction`,
## because converting each piece on its own would round five times over. A bare
## commander has no defence at all, which is what makes movement-versus-defence a
## real trade rather than a slogan.
func defence() -> int:
	var points := 0
	for piece in armour:
		points += piece.defence_for(score_for(piece.item))
	if weapon != null and weapon.item != null:
		points += weapon.item.defence_for(score_for(weapon.item))
	return Armour.reduction(points)


## The score this commander reads an item against: its sheet's score in the
## ability that item names, or -- while nobody has recorded one -- the item's own
## level, which reads every value on it in full.
func score_for(read: Item) -> int:
	if read == null:
		return 0
	return sheet.score(read.governing, read.level)


## Whether this commander's weapon action is its own to choose.
##
## A commander with a decision function on its sheet spends its turn's one weapon
## action itself -- by striking, by doing something else with the turn, or by not
## having answered in time and passing. One without has nobody to ask, so the
## board's own stand-in chooser fills the turn for it, which is what every fight
## in the world did before any character had a decision function at all.
##
## The question is what is on the sheet, never whose hand is behind it: a
## person's recorded turns and a program's rule are one `Callable` here and this
## answers `true` for both.
func chooses_for_itself() -> bool:
	return sheet != null and sheet.decide.is_valid()


## Record one ability score, on the sheet. Kept as a convenience over
## `sheet.set_score` because a board test says what a wearer's score is far more
## often than it says anything else about the character.
func set_score(ability: String, value: int) -> void:
	sheet.set_score(ability, value)


## Stand this commander up as a character that already exists.
##
## The sheet replaces the one it was made with, so its level, its health, its
## scores and its identity become that character's all at once. There is nothing
## to copy across and therefore nothing that can be copied wrongly.
func adopt(of: Character) -> Commander:
	sheet = of
	return self


# Where a commander's level and hit points are kept: on its character sheet.
# `Piece` reads and writes both through these four, so the piece holds no copy of
# either and cannot come to disagree with the sheet about them.
func _read_level() -> int:
	return sheet.level


func _write_level(to: int) -> void:
	sheet.level = to


func _read_health() -> int:
	return sheet.health


func _write_health(to: int) -> void:
	sheet.health = to


## One cardinal step, before any armour. Section 3.4's base.
static func base_grant() -> MoveGrant:
	return MoveGrant.land(PieceGeometry.CARDINALS, "base")


# --- Facing ---------------------------------------------------------------


## Turn to face a direction. Free: no turn, no action.
##
## It takes no turn number because there is nothing for it to spend one on, and
## it leaves every cooldown exactly as it found it. That is not a promise made in
## a comment -- it is the whole body of the function.
func face(direction: int) -> void:
	facing = ((direction % 4) + 4) % 4


## Turn by whole quarter turns, clockwise. The same freedom, said relatively.
func turn_by(quarter_turns: int) -> void:
	face(facing + quarter_turns)


func has_facing() -> bool:
	return true


func is_commander() -> bool:
	return true


func kind_name() -> String:
	return "commander"


func _facing_for_line() -> int:
	return facing


# --- Movement as armour ---------------------------------------------------


## Wear a piece of armour, replacing whatever was in its slot.
##
## The piece goes into the character's inventory first and is then put on out of
## it, because the inventory refuses to equip what it does not carry. Whatever
## was in the slot comes off and stays carried: taking a breastplate off is not
## the same as leaving it on the floor.
func equip(piece: Armour) -> void:
	sheet.inventory.take_up(piece)


## Take off whatever is worn in a slot. Returns whether anything came off.
## What came off is still carried.
func unequip(slot: String) -> bool:
	return sheet.inventory.unequip(slot) != null


## What is worn in a slot, or null.
func worn_in(slot: String) -> Armour:
	return sheet.inventory.armour_in(slot)


## The base step, plus one grant for every piece of armour that carries one.
##
## The union the design asks for is taken here as a list of grants rather than as
## a merged pattern, because the three kinds of grant are resolved differently
## against the board -- a slide is stopped by what a hop ignores. The union of
## the *cells* they reach is what LegalMoves produces from them.
func move_grants() -> Array[MoveGrant]:
	var grants: Array[MoveGrant] = [base_grant()]
	for piece in armour:
		var granted := piece.grant_for(score_for(piece.item))
		if granted != null:
			grants.append(granted)
	return grants


## A commander captures with its weapon, never by moving onto a piece.
func capture_grants() -> Array[MoveGrant]:
	return []


## The loadout in one line, for a report and a failure message.
func loadout_line() -> String:
	var slots := PackedStringArray()
	for piece in armour:
		var score := score_for(piece.item)
		slots.append("%s(%d/%d)" % [
			piece.slot, piece.movement_for(score), piece.defence_for(score),
		])
	if slots.is_empty():
		slots.append("bare")
	return "%s + %s" % [
		"-" if weapon == null else weapon.weapon_name, " ".join(slots),
	]


# --- Weapons and cooldowns ------------------------------------------------


## Take up a weapon. Cooldowns are the held weapon's, so they start clean.
##
## Like `equip()`, through the inventory: the weapon is carried and then put in
## the hand, so a commander swinging something is a character that has it.
func wield(held: Weapon) -> void:
	sheet.inventory.take_up(held)
	_ready_on = {}


## How many attacks are available to be chosen from at all.
func attack_count() -> int:
	return 0 if weapon == null else weapon.attack_count()


## One attack of the held weapon, or null.
func attack_at(index: int) -> Attack:
	return null if weapon == null else weapon.attack_at(index)


## What one of the held weapon's attacks deals in this commander's hands, before
## any modifier and before the target's defence. The item's effects axis, gated
## and divided; the fight asks here and reads no number off an `Attack`.
func damage_of(index: int) -> int:
	if weapon == null:
		return 0
	return weapon.damage_of(index, score_for(weapon.item))


## How long this commander waits between two uses of an attack: the pattern's own
## wait, less what the item's movement axis bought off it.
func cooldown_of(index: int) -> int:
	if weapon == null:
		return 0
	return weapon.cooldown_of(index, score_for(weapon.item))


## Whether an attack may be used on a given turn.
func can_attack(index: int, turn: int) -> bool:
	if attack_at(index) == null:
		return false
	return turn >= int(_ready_on.get(index, turn))


## How many turns until an attack may be used, counted from a given turn.
func turns_until_ready(index: int, turn: int) -> int:
	if attack_at(index) == null:
		return -1
	return maxi(0, int(_ready_on.get(index, turn)) - turn)


## Use an attack on a turn, putting it on its cooldown. Returns false, and
## changes nothing, if it was not available.
func spend_attack(index: int, turn: int) -> bool:
	if not can_attack(index, turn):
		return false
	_ready_on[index] = turn + cooldown_of(index)
	return true


## The cells an attack covers from where the commander stands, as it is facing.
## Absolute lattice coordinates, canonical, unfiltered by any board.
func attack_cells(index: int, from_turn: int = -1) -> Array[Vector2i]:
	var attack := attack_at(index)
	if attack == null:
		return []
	if from_turn >= 0 and not can_attack(index, from_turn):
		return []
	return attack.cells_from(cell, facing)


## Every attack's readiness on a turn, in one string.
##
## What the facing check compares before and after turning, and the reason it can
## be sure that rotating costs nothing: if turning had spent anything, it would
## have spent it here.
func readiness_line(turn: int) -> String:
	var parts := PackedStringArray()
	for index in attack_count():
		parts.append("%s:%d" % [attack_at(index).attack_name, turns_until_ready(index, turn)])
	return " ".join(parts) if parts.size() > 0 else "-"
