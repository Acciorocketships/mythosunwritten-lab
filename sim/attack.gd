extends RefCounted
## One composable effect: the single base every melee attack, projectile, spell
## and action in this project is built out of.
##
## Section 4 asks for one base rather than a hierarchy -- "melee attacks,
## projectiles, spells, and actions share one base, customized by effect,
## damage, properties, hitbox shape, sprite, animation, and movement". This is
## that base, and those seven customisation points are seven of its fields:
##
## | customisation point | field | what it holds |
## |---|---|---|
## | hitbox shape | `offsets` | the cells it covers, written facing north |
## | damage | `damage` | what one landing is worth, before defence |
## | properties | `properties` | named whole numbers: push, split, homing |
## | movement | `movement` | how it gets from its wielder to those cells |
## | effect | `effects` | what it does besides damage, by mechanic name |
## | sprite | `sprite_tag` | which art says so -- a tag, never a path |
## | animation | `animation_tag` | which motion says so -- a tag, never a path |
##
## plus the two every one of them has: a name, and a cooldown in turns.
##
## ## Why one base and not four
##
## The two things the earlier representation could not hold cost no new code at
## all. An arrow is this class with projectile movement and the arrow tag. A
## magic missile is this class with projectile movement, a split of three and a
## homing reach of one. Neither is a subclass, neither is a kind, and neither
## needed a line of the resolution step to change: a split is arithmetic on
## `damage`, homing is arithmetic on `offsets`, and travelling is arithmetic on
## the two cells at either end of the flight.
##
## That is the property randomised items need. A generator can set fields; it
## cannot write a class. So every axis along which an item may vary has to be a
## field here, and no rule anywhere may ask which item it is looking at.
##
## ## A shove is not a separate kind of thing
##
## It is an effect whose `push` property is more than zero, which means it obeys
## exactly the rules every other one obeys -- a pattern written for a wielder
## facing north, rotated by the wielder's facing, clipped to the board, sat on a
## cooldown. Section 3.2's "a unit on a cliff edge can be pushed into a chasm" is
## therefore one entry in a dictionary and one branch in the resolution step, not
## a second targeting system. Split and homing arrived the same way and cost the
## same: one entry each.
##
## ## The pattern is relative and facing-local
##
## Offsets are written for an attacker facing north and rotated by the attacker's
## facing when the cells are asked for. That single rotation is what gives a
## commander a front and a back: a spear authored as two cells ahead reaches
## nothing behind its wielder until the wielder turns, while a bow's ring and a
## flail's sweep are symmetric about the attacker and rotate onto themselves.
## Neither of those is special-cased; they are the same rotation applied to two
## different lists.
##
## ## The cooldown is a turn number, not a countdown
##
## An attack records the turn it next becomes available on, and readiness is a
## comparison against the turn being asked about. Nothing here has to be ticked,
## so nothing here can be ticked twice or forgotten -- which matters because the
## turn economy that would do the ticking does not exist yet and this layer must
## not grow a private one.
class_name Attack

## A cooldown of one: usable on every turn, the shortest there is.
const EVERY_TURN := 1

# --- Movement -------------------------------------------------------------
#
# How the effect gets from the wielder to the cells its shape covers. This is
# the field that makes a projectile a projectile, and it is the only difference
# between a thrust and an arrow.

## It lands where it is aimed, in the turn it is used: a swing, a thrust, an
## area spell that goes off where it is put.
const INSTANT := "instant"

## It crosses the ground between its wielder and where it lands. An arrow, a
## bolt, a thrown axe.
const PROJECTILE := "projectile"

## Every movement there is, and whether it crosses the cells on the way. A table
## rather than a branch, so a third movement is a row here and nothing else.
const MOVEMENTS := {INSTANT: false, PROJECTILE: true}

# --- Properties -----------------------------------------------------------
#
# Named whole numbers, all of them zero unless something asks for them. A
# property is how an effect says it does something structural -- shoves, divides
# itself, bends towards a target -- without any of those being a class.

## How many cells it pushes what it lands on, directly away from the wielder.
##
## Any number of cells is meant literally: the resolution step walks the push one
## cell at a time and applies the shove's four checks at each of them, so a push
## of `n` is `n` applications of the rule a push of one obeys and the target
## stops or dies at the first cell that stops or kills it.
const PUSH := "push"

## How many separate landings one use of it makes. A magic missile with a split
## of three lands three times; everything else lands once.
const SPLIT := "split"

## How far off its own shape it may bend to find something. Zero for everything
## that does not home, and then the cells it can reach are exactly its shape.
const HOMING := "homing"

## Every property there is, in a fixed order, so anything that walks them walks
## them the same way in every process.
const PROPERTIES := [PUSH, SPLIT, HOMING]

## What it is called. Names an effect, never an item's art.
var attack_name: String = ""

## The hitbox shape: the cells it reaches, relative to the attacker facing
## north. Canonical.
var offsets: Array[Vector2i] = []

## How many turns from using it until it may be used again. One means every
## turn; the design's rule that a stronger attack waits longer lives in the
## numbers the weapons choose, not in a rule here.
var cooldown: int = EVERY_TURN

## What one landing is worth before any terrain or facing modifier and before
## the target's defence. Zero means the effect does no damage at all and the
## resolution seam is never asked -- which is what a shove is.
var damage: int = 0

## How it gets to the cells it covers. One of `MOVEMENTS`.
var movement: String = INSTANT

## The properties it carries, by name, none of them zero. Read through
## `property()` rather than directly, so an absent property and a zero one are
## the same thing everywhere.
var properties: Dictionary = {}

## What it does besides damage, by mechanic name -- "flame", "arcane". A name
## here is a mechanic and never a piece of art, exactly as it is everywhere else
## in this layer.
var effects: PackedStringArray = PackedStringArray()

## Which art says what it is. A tag out of the effect vocabulary, resolved to
## something drawable by the render layer's own table and by nothing here.
var sprite_tag: String = ""

## Which motion says it happened. A tag, on the same terms as the sprite.
var animation_tag: String = ""

## How many cells it pushes what it lands on. The `PUSH` property under the name
## the resolution step has always read it by, so there is one place it is stored.
var push: int:
	get:
		return property(PUSH)


## Compose one, from any subset of the customisation points.
##
## Keys: `name`, `shape`, `cooldown`, `damage`, `movement`, `effects`, `sprite`,
## `animation`, and any of `PROPERTIES` by its own name. Everything left out
## takes the default that means "this effect does not do that", so the shortest
## call is a name and a shape and the longest is an arrow.
##
## A movement that is not one of `MOVEMENTS` and a property that is not one of
## `PROPERTIES` are dropped rather than kept, so what an effect claims about
## itself is always something this class can answer for.
static func compose(spec: Dictionary) -> Attack:
	var attack := Attack.new()
	attack.attack_name = str(spec.get("name", ""))

	var shape: Array[Vector2i] = []
	for cell in spec.get("shape", []):
		shape.append(cell)
	attack.offsets = PieceGeometry.canonical(shape)

	attack.cooldown = maxi(EVERY_TURN, int(spec.get("cooldown", EVERY_TURN)))
	attack.damage = maxi(0, int(spec.get("damage", 0)))

	var moves := str(spec.get("movement", INSTANT))
	attack.movement = moves if MOVEMENTS.has(moves) else INSTANT

	var carried := {}
	for named in PROPERTIES:
		var worth := maxi(0, int(spec.get(named, 0)))
		if worth > 0:
			carried[named] = worth
	attack.properties = carried

	var named_effects := PackedStringArray()
	for effect in spec.get("effects", []):
		named_effects.append(str(effect))
	attack.effects = named_effects

	attack.sprite_tag = str(spec.get("sprite", ""))
	attack.animation_tag = str(spec.get("animation", ""))
	return attack


## The short form: a name, a shape, a cooldown, a damage and a push. What a plain
## melee swing needs and nothing more, on top of the same `compose`.
static func make(
	called: String,
	pattern: Array[Vector2i],
	turns: int = EVERY_TURN,
	deals: int = 0,
	pushes: int = 0,
) -> Attack:
	return compose({
		"name": called,
		"shape": pattern,
		"cooldown": turns,
		"damage": deals,
		PUSH: pushes,
	})


## What one property is worth, zero for one it does not carry.
func property(named: String) -> int:
	return int(properties.get(named, 0))


## How many cells the shape covers.
func cell_count() -> int:
	return offsets.size()


## The shape as the attacker facing `facing` would lay it out, still relative to
## the attacker.
func offsets_facing(facing: int) -> Array[Vector2i]:
	return PieceGeometry.rotate_all(offsets, facing)


## The cells the shape covers from a given cell, for an attacker facing a given
## way. Absolute lattice coordinates, canonical, and not yet filtered against any
## board -- what falls off the edge is the board's business.
func cells_from(origin: Vector2i, facing: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in offsets_facing(facing):
		cells.append(origin + offset)
	return PieceGeometry.canonical(cells)


## Whether the shape is unchanged by every quarter turn -- a ring or an all-round
## sweep. True of a bow and a flail, false of a spear.
func is_symmetric() -> bool:
	for turns in [1, 2, 3]:
		if PieceGeometry.rotate_all(offsets, turns) != offsets:
			return false
	return true


# --- Movement, split and homing, as arithmetic ----------------------------


## Whether it crosses the ground on its way, which is what the movement table
## says and the only thing it says.
func travels() -> bool:
	return bool(MOVEMENTS.get(movement, false))


## The cells it passes through getting from `origin` to `cell`.
##
## An instant effect passes through nothing: it is already there, so the answer
## is the one cell it lands on. A projectile walks the lattice line between the
## two, `origin` excluded and `cell` included, which is what lets something
## standing in between ever be in the way. Nothing here decides that it *is* in
## the way -- that is the board's answer, as it is for every other pattern.
func travel_to(origin: Vector2i, cell: Vector2i) -> Array[Vector2i]:
	if not travels():
		return [cell]
	var delta := cell - origin
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps == 0:
		return [cell]
	var crossed: Array[Vector2i] = []
	for step in range(1, steps + 1):
		crossed.append(origin + Vector2i(
			_share(delta.x, step, steps), _share(delta.y, step, steps)
		))
	return crossed


## How many separate landings one use of it makes. One unless it splits.
func strike_count() -> int:
	return maxi(1, property(SPLIT))


## What the `index`th of those landings is worth.
##
## The damage is divided across them exactly, in whole numbers, the remainder
## going to the earliest -- the same largest-remainder shape the rest of this
## project divides things by. So a split costs nothing and gains nothing by
## arithmetic accident, and an effect that does not split reads its whole damage
## off landing zero.
func damage_share(index: int) -> int:
	var landings := strike_count()
	if index < 0 or index >= landings:
		return 0
	@warning_ignore("integer_division")
	var each := damage / landings
	return each + (1 if index < damage % landings else 0)


## How far off its own shape it may bend to find something.
func homing_reach() -> int:
	return property(HOMING)


## Every cell it could end up covering: its shape, widened by its homing reach.
##
## With no homing this is exactly `cells_from`, which is why nothing that does
## not home pays for the field. With a homing reach of one, every cell of the
## shape brings its eight neighbours with it.
func reachable_from(origin: Vector2i, facing: int) -> Array[Vector2i]:
	var reach := homing_reach()
	var cells := cells_from(origin, facing)
	if reach <= 0:
		return cells
	var widened: Array[Vector2i] = []
	for cell in cells:
		for row in range(-reach, reach + 1):
			for column in range(-reach, reach + 1):
				widened.append(cell + Vector2i(column, row))
	return PieceGeometry.canonical(widened)


## One line describing the effect, in the form the reports and the tests compare.
func line() -> String:
	var parts := PackedStringArray([
		attack_name,
		"cooldown=%d" % cooldown,
		"damage=%d" % damage,
		"cells=%d" % offsets.size(),
		"symmetric" if is_symmetric() else "fronted",
		movement,
	])
	for named in PROPERTIES:
		if property(named) > 0:
			parts.append("%s=%d" % [named, property(named)])
	if effects.size() > 0:
		parts.append("effects=%s" % ",".join(effects))
	parts.append("sprite=%s" % _or_dash(sprite_tag))
	parts.append("anim=%s" % _or_dash(animation_tag))
	return " ".join(parts)


static func _or_dash(tag: String) -> String:
	return tag if tag != "" else "-"


## `value * step / steps`, rounded half away from zero in whole numbers, so the
## flight of a projectile is the same on every machine and in every process.
static func _share(value: int, step: int, steps: int) -> int:
	var doubled := value * step * 2
	var negative := doubled < 0
	@warning_ignore("integer_division")
	var rounded := (absi(doubled) + steps) / (steps * 2)
	return -rounded if negative else rounded
