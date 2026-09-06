extends RefCounted
## Turns the ground part of a snapshot into things to draw, and holds nothing.
##
## The companion of `render/combat_diorama.gd`, and built to the same rule.
## Everything the shell needs to put loot on screen -- where each item lies,
## which way round it is, and which name says what it looks like -- comes out of
## `placements()`, a pure function of one snapshot dictionary. It has no members,
## it remembers nothing between calls, and it never asks the simulation a
## question. The simulation owns what is lying where; this decides only how a
## heap of it is arranged so a person can tell one thing from another.
##
## ## Why a pile is spread out
##
## A pile in the simulation is one position: three things dropped at your feet
## are three things at exactly your feet, because to the engine a pile is an
## inventory with a place and the place is a point. Drawn literally that is one
## model with two more hidden inside it, which reads as a single item and loses
## two.
##
## So the items of a pile are laid out around its point on a sunflower spiral --
## the i-th item at angle `i * GOLDEN_ANGLE` and radius `SPACING * sqrt(i)`.
## That particular spiral is chosen because its nearest-neighbour distance is
## flat: whether a pile holds two things or twenty, no two of them come closer
## than `SPACING`, and the heap grows outwards instead of getting denser. The
## first item sits exactly on the pile's own point, so a pile of one is drawn
## where the simulation says it is and nowhere else.
##
## This is presentation and nothing else. Not one number here goes back: what an
## action can reach is the pile's own position, which is what it always was, and
## a person walking up to the outermost sword of a spread is walking up to the
## pile.
##
## ## The fallback
##
## An item resolves to a catalog name through `ItemModel`, in the simulation,
## and some items resolve to nothing -- an iron key, a wool blanket, anything
## held whose shape nobody recorded. Nothing is not drawable, and an item that
## cannot be seen is an item that cannot be picked up by somebody who does not
## already know it is there. So an unnamed item is drawn as `FALLBACK_TAG`: a
## wrapped bundle, which is what an unidentified thing on the ground looks like.
##
## The decision belongs here rather than in the simulation because it is a
## decision about pictures: the simulation's honest answer is that it does not
## know what a wool blanket looks like, and the render layer's answer is that
## something has to be visible anyway.
class_name GroundItems

## What an item with no name of its own is drawn as. A real catalog tag, so it
## goes through the same table every other item does and cannot be a hole.
const FALLBACK_TAG := AssetTags.GEAR_BUNDLE

## How far apart two items of one pile are laid, in world units.
##
## The nearest-neighbour distance of the spiral below is exactly this number,
## whatever the pile holds, so it is the whole of "a pile of several is legible":
## at a `DRAWN_SPAN` of 0.75 units an item is narrower than the gap to its
## neighbour, so two things next to each other are two things.
const SPACING := 0.85

## The angle between one item of a pile and the next, in radians: the golden
## angle, `PI * (3 - sqrt(5))`. Written out rather than computed because it is a
## constant of the layout and not a thing to be recalculated.
const GOLDEN_ANGLE := 2.39996322972865332

## The box an item is drawn inside, in world units: its longest dimension,
## whatever the model's own size.
##
## Loot is normalised on purpose. The models come out of different packs at
## wildly different scales -- the installed staff is 2.16 units tall and the
## installed bottle 0.89 -- and they are not even drawn along the same axis: the
## sword's length is its height and the bow's length is its depth. A pile whose
## members were drawn at their own sizes would read as one enormous thing beside
## some specks, and one normalised by *height* would blow the bow up thirteen
## times to make its 0.16-unit thickness reach.
##
## So the shell measures what it built and divides by the longest side. What
## tells a legendary from a common is the label, never the size.
##
## Three quarters of a unit, which is chosen against the *grass* rather than
## against the models: a tuft stands between 0.36 and 0.78 units
## (`GrassLayer.HEIGHT_MIN`/`HEIGHT_MAX`), and loot smaller than that is loot a
## person walks past because it is inside the meadow rather than on it.
const DRAWN_SPAN := 0.75

## How far off the ground an item is lifted, in world units, so that it does not
## fight the terrain surface for the same pixels.
const LIFT := 0.04


## Everything needed to draw the loot on the ground, one row per item.
##
## Each row is
##
##     {"key": String, "object": int, "index": int, "tag": String,
##      "fallback": bool, "x": float, "z": float, "yaw": float,
##      "name": String, "rarity": String, "level": int}
##
## `key` is stable across frames -- the object's id and the item's place in it --
## so the shell can keep a drawable per item and add and drop only what changed.
## `x` and `z` are world positions with the spread already applied; the height is
## the shell's to sample, because how high the ground is under a point is the
## world's answer and not the snapshot's.
static func placements(snapshot: Dictionary) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	for row in _rows(snapshot):
		var object_id := int(row.get("id", 0))
		var at_x := float(row.get("x", 0.0))
		var at_z := float(row.get("z", 0.0))
		var items: Variant = row.get("items", [])
		if not (items is Array):
			continue
		for index in (items as Array).size():
			var item: Dictionary = (items as Array)[index]
			var offset := spread(index)
			var tag := String(item.get("model", ""))
			made.append({
				"key": "%d:%d" % [object_id, index],
				"object": object_id,
				"index": index,
				"tag": FALLBACK_TAG if tag == "" else tag,
				"fallback": tag == "",
				"x": at_x + offset.x,
				"z": at_z + offset.y,
				"yaw": float(index) * GOLDEN_ANGLE,
				"name": String(item.get("name", "")),
				"rarity": String(item.get("rarity", "")),
				"level": int(item.get("level", 0)),
			})
	return made


## Where the i-th item of a pile lies, relative to the pile's own point.
##
## Public because it is the claim: a test walks it for piles of every size and
## measures that no two items land closer than `SPACING`.
static func spread(index: int) -> Vector2:
	var at := maxi(0, index)
	var angle := float(at) * GOLDEN_ANGLE
	var radius := SPACING * sqrt(float(at))
	return Vector2(cos(angle), sin(angle)) * radius


## How much a built model has to be scaled so its longest side is `DRAWN_SPAN`.
## A model that measures nothing at all is left alone rather than divided by
## zero.
static func scale_for(measured: Vector3) -> float:
	var longest := maxf(measured.x, maxf(measured.y, measured.z))
	return 1.0 if longest <= 0.0 else DRAWN_SPAN / longest


static func _rows(snapshot: Dictionary) -> Array:
	var rows: Variant = _combat(snapshot).get("ground", [])
	return rows if rows is Array else []


static func _combat(snapshot: Dictionary) -> Dictionary:
	var combat: Variant = snapshot.get("combat", {})
	return combat if combat is Dictionary else {}
