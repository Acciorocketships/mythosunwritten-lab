extends RefCounted
## The eleven icons the pack does not have, drawn here in the pack's own idiom.
##
## The Sprout Lands pack ships a generic icon sheet -- a star, a crown, a coin, a
## tick, a skull, a cog and a dozen more -- and none of them is an ability score,
## a helmet or a boot. So the panel takes what the sheet has and draws the rest,
## and this file is the rest. Every icon in the panel is one or the other and
## reports/ui.md names which, one by one.
##
## ## The idiom, made literal
##
## Same sixteen-pixel cell as the pack. Same three colours, sampled out of the
## pack's own frame rather than chosen: `#aa7959` for the edge, `#c49a6c` for a
## shaded face, `#e8cfa6` for a lit one -- which is exactly the palette of the
## wooden frame these icons are drawn on top of, and the cream the pack's own
## icon sheet is drawn in. Every shape carries a one-pixel edge all the way
## round, which is what makes a pack icon and one of these sit together.
##
## ## Why the art is source and not a file
##
## Because it can be, and because the alternative is a binary blob nobody can
## review. Sixteen rows of sixteen characters is the whole of an icon; a change
## to one shows up in a diff as the shape it changes. It also keeps the licence
## line clean: the pack's own files may not be redistributed even when modified,
## and these are not derived from any of them -- they are this project's own art,
## in this project's own repository, drawn to match.
##
## `.` is nothing, `o` the edge, `m` the shaded face, `l` the lit face.
class_name PixelIcons

## The three colours, out of the pack's frame.
const EDGE := Color8(0x90, 0x62, 0x5d)
const SHADE := Color8(0xc4, 0x9a, 0x6c)
const LIT := Color8(0xe8, 0xcf, 0xa6)

## The cell every one of these is drawn on, which is the pack's.
const CELL := SproutPack.CELL

## The six ability scores, in `Ability.ALL` order, then the five equipment slots
## in `Inventory.SLOT_ORDER` order. Keyed by the simulation's own names, so the
## panel asks for an icon with the string the sheet already uses and there is no
## second vocabulary to keep in step.
##
##   str -- a barbell        con -- a shield         cha -- a face
##   dex -- an arrow         wis -- an eye           int -- an open book
##   boots, leggings, chestplate, helmet -- the piece of gear itself
##   hand -- a sword, because the hand slot is what a weapon is held in
const ART := {
	"str": [
		"................",
		"................",
		"................",
		".oooo......oooo.",
		".ollo......ollo.",
		".ollo......ollo.",
		".ollloooooolllo.",
		".ollllllllllllo.",
		".ollllllllllllo.",
		".ollloooooolllo.",
		".ollo......ollo.",
		".ollo......ollo.",
		".oooo......oooo.",
		"................",
		"................",
		"................",
	],
	"con": [
		"................",
		"................",
		"...oooooooooo...",
		"...ollllllllo...",
		"...olllmmlllo...",
		"...olllmmlllo...",
		"...olllmmlllo...",
		"...olllmmlllo...",
		"...olllmmlllo...",
		"....ollllllo....",
		".....ollllo.....",
		"......ollo......",
		".......oo.......",
		"................",
		"................",
		"................",
	],
	"cha": [
		"................",
		"................",
		".....oooooo.....",
		"....ollllllo....",
		"...ollllllllo...",
		"...oloolloolo...",
		"...oloolloolo...",
		"...ollllllllo...",
		"...ollllllllo...",
		"...olollllolo...",
		"....oloooolo....",
		".....oooooo.....",
		"................",
		"................",
		"................",
		"................",
	],
	"dex": [
		"................",
		".......oo.......",
		"......ollo......",
		".....ollllo.....",
		"....ollllllo....",
		"...ooollllooo...",
		"......ollo......",
		"......ollo......",
		"......ollo......",
		"......ollo......",
		"......ollo......",
		"......ollo......",
		"......ollo......",
		"......oooo......",
		"......o..o......",
		"......o..o......",
	],
	"wis": [
		"................",
		"................",
		"................",
		"......oooo......",
		"....oommmmoo....",
		"...olmmmmmmlo...",
		"..ollmoooomllo..",
		".olllmoooomlllo.",
		"..ollmoooomllo..",
		"...olmoooomlo...",
		"....oommmmoo....",
		"......oooo......",
		"................",
		"................",
		"................",
		"................",
	],
	"int": [
		"................",
		"................",
		"................",
		"..ooooo..ooooo..",
		".olllloooollllo.",
		".ollllloolllllo.",
		".ollllloolllllo.",
		".ollllloolllllo.",
		".ollllloolllllo.",
		".ollllloolllllo.",
		".ollllloolllllo.",
		".ollllloolllllo.",
		".oooooooooooooo.",
		"................",
		"................",
		"................",
	],
	"helmet": [
		"................",
		"......oooo......",
		".....ollllo.....",
		"....ollllllo....",
		"...ollllllllo...",
		"...ollllllllo...",
		"...ollllllllo...",
		"...oloooooolo...",
		"...oloooooolo...",
		"...ollllllllo...",
		"...ollllllllo...",
		"...ollllllllo...",
		"...ollllllllo...",
		"...oooooooooo...",
		"................",
		"................",
	],
	"chestplate": [
		"................",
		"................",
		"................",
		"..oooooooooooo..",
		"..ollllllllllo..",
		"..ollllmmllllo..",
		"..oolllmmllloo..",
		"....ollmmllo....",
		"....ollmmllo....",
		"....ollmmllo....",
		"....ollmmllo....",
		".....olmmlo.....",
		"......oooo......",
		"................",
		"................",
		"................",
	],
	"leggings": [
		"................",
		"................",
		"...oooooooooo...",
		"...ollllllllo...",
		"...ollllllllo...",
		"...ollloolllo...",
		"...ollo..ollo...",
		"...ollo..ollo...",
		"...ollo..ollo...",
		"...ollo..ollo...",
		"...ollo..ollo...",
		"...ollo..ollo...",
		"...ollo..ollo...",
		"...oooo..oooo...",
		"................",
		"................",
	],
	"boots": [
		"................",
		"................",
		"....ooooo.......",
		"....olllo.......",
		"....olllo.......",
		"....olllo.......",
		"....olllo.......",
		"....olllo.......",
		"....olllo.......",
		"....olllo.......",
		"....olllo.......",
		"....ollllooooo..",
		"....ollllllllo..",
		"....oooooooooo..",
		"................",
		"................",
	],
	"hand": [
		".......oo.......",
		"......ollo......",
		"......ollo......",
		"......ommo......",
		"......ommo......",
		"......ommo......",
		"......ommo......",
		"......ommo......",
		"......ommo......",
		"......ommo......",
		"......ollo......",
		"..oooolllloooo..",
		"..ollllllllllo..",
		"..oooolllloooo..",
		"......ollo......",
		"......oooo......",
	],
}

# Built once each, on first ask. An icon is sixteen rows of source and costs a
# 256-pixel image to make; making it twice would be waste rather than a bug, but
# the panel asks for the same six icons on every rebuild.
static var _made := {}


## The icon for a name, or null if there is none drawn for it. `Ability.ALL` and
## `Inventory.SLOT_ORDER` are between them every name that answers.
static func of(named: String) -> Texture2D:
	if _made.has(named):
		return _made[named]
	if not ART.has(named):
		return null
	var texture := draw(ART[named])
	_made[named] = texture
	return texture


## Whether an icon is drawn for a name.
static func has(named: String) -> bool:
	return ART.has(named)


## Every name there is an icon for, in the order they are written above.
static func names() -> PackedStringArray:
	var found := PackedStringArray()
	for key in ART:
		found.append(String(key))
	return found


## Sixteen rows of source, as something drawable.
##
## Public because this idiom has a second user: render/effect_art.gd draws the
## six effect sprites the same way, on the same cell and in the same three
## colours, and there should be one place that turns `.oml` into pixels rather
## than two that could drift apart.
static func draw(rows: Array) -> ImageTexture:
	var image := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in mini(CELL, rows.size()):
		var line: String = rows[y]
		for x in mini(CELL, line.length()):
			match line[x]:
				"o":
					image.set_pixel(x, y, EDGE)
				"m":
					image.set_pixel(x, y, SHADE)
				"l":
					image.set_pixel(x, y, LIT)
	return ImageTexture.create_from_image(image)
