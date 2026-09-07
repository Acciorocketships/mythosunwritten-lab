extends RefCounted
## The icons the pack does not have, drawn here in the pack's own idiom.
##
## The Sprout Lands pack ships a generic icon sheet -- a star, a crown, a coin, a
## tick, a skull, a cog and a dozen more -- and none of them is an ability score,
## a helmet, a boot, a chess-piece minion or the pattern of cells a weapon
## reaches. So the panels take what the sheet has and draw the rest,
## and this file is the rest. Every icon in the panels is one or the other and
## reports/ui.md and reports/dialogue-trade.md name which, one by one.
##
## Two kinds of drawn icon live here. The named ones (`ART`) are sixteen rows
## of source each: the six ability scores, the five equipment slots, and the
## four minion types, keyed by the simulation's own names. The attack-pattern
## glyphs (`pattern()`) are *generated*, because they cannot be a table: a
## weapon's reach is data on the item -- randomised weapons carry patterns
## nobody drew -- so the glyph is built from the shape itself, a mini-board on
## the same sixteen-pixel cell.
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
## in `Inventory.SLOT_ORDER` order, then the four minion types in
## `Minion.KINDS` order. Keyed by the simulation's own names, so the
## panel asks for an icon with the string the sheet already uses and there is no
## second vocabulary to keep in step.
##
##   str -- a barbell        con -- a shield         cha -- a face
##   dex -- an arrow         wis -- an eye           int -- an open book
##   boots, leggings, chestplate, helmet -- the piece of gear itself
##   hand -- a sword, because the hand slot is what a weapon is held in
##   toadstool -- a spotted mushroom · cat -- an eared face, whiskerless
##   ent -- a tree on its trunk · frog -- a wide face with raised eyes
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
	"toadstool": [
		"................",
		".....oooooo.....",
		"....ollllllo....",
		"...olllmmlllo...",
		"..ollmllllmllo..",
		"..olllllmllllo..",
		"..ollmlllllllo..",
		"..oooooooooooo..",
		".....ollllo.....",
		".....ollllo.....",
		".....ollllo.....",
		".....ollllo.....",
		".....oooooo.....",
		"................",
		"................",
		"................",
	],
	"cat": [
		"................",
		"..oo........oo..",
		"..olo......olo..",
		"..ollo....ollo..",
		"..olloooooollo..",
		"..ollllllllllo..",
		"..ollllllllllo..",
		"..olmllllllmlo..",
		"..olmllllllmlo..",
		"..ollllllllllo..",
		"..ollllmmllllo..",
		"..ollllllllllo..",
		"...oooooooooo...",
		"................",
		"................",
		"................",
	],
	"ent": [
		"................",
		".....oooooo.....",
		"....ollllllo....",
		"...ollllllllo...",
		"..ollllmlllllo..",
		"..olllllllmllo..",
		"...ollllllllo...",
		"....ollllllo....",
		".....oooooo.....",
		"......omlo......",
		"......omlo......",
		"......omlo......",
		".....oomloo.....",
		"....oooooooo....",
		"................",
		"................",
	],
	"frog": [
		"................",
		"................",
		"...oo......oo...",
		"..olmo....olmo..",
		"..ollo....ollo..",
		"..olloooooollo..",
		".ollllllllllllo.",
		".ollllllllllllo.",
		".olmoooooooomlo.",
		".ollllllllllllo.",
		"..oooooooooooo..",
		"................",
		"................",
		"................",
		"................",
		"................",
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


## How far the pattern glyph's window reaches from the attacker, in board
## cells: a seven-by-seven window, the observation packet's own choice of
## window, drawn at two art pixels per cell inside a one-pixel edge.
const PATTERN_REACH := 3

# One glyph per distinct shape, built on first ask. Keyed by the shape itself,
# because two weapon actions with one reach should share one glyph.
static var _patterns := {}


## The attack-pattern glyph for a weapon action: the cells its shape covers,
## drawn as a mini-board on the same sixteen-pixel cell as everything else.
##
## Generated rather than tabled, because the shape is data on the item and a
## randomised weapon carries patterns nobody drew. The attacker's own cell is
## the shaded block in the middle; every covered cell within the window is a
## lit block, north up, exactly as the shape is written
## (`sim/attack.gd`: relative to an attacker facing north); a covered cell
## beyond the window -- a bow's ring at distance five to ten -- is clamped to
## the window's rim and drawn in the edge colour, which reads as "further,
## this way". The idiom's one-pixel edge runs all the way round.
static func pattern(offsets: Array) -> ImageTexture:
	var parts := PackedStringArray()
	for cell in offsets:
		parts.append("%d:%d" % [(cell as Vector2i).x, (cell as Vector2i).y])
	var key := ";".join(parts)
	if _patterns.has(key):
		return _patterns[key]
	var image := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for at in CELL:
		image.set_pixel(at, 0, EDGE)
		image.set_pixel(at, CELL - 1, EDGE)
		image.set_pixel(0, at, EDGE)
		image.set_pixel(CELL - 1, at, EDGE)
	# Far cells first and near cells over them, so a shape with both keeps its
	# readable part readable; the attacker last, because where you stand is the
	# one block nothing may cover.
	var centre := Vector2i(PATTERN_REACH, PATTERN_REACH)
	for cell in offsets:
		var v := cell as Vector2i
		if absi(v.x) > PATTERN_REACH or absi(v.y) > PATTERN_REACH:
			_pattern_block(image, centre + Vector2i(
				clampi(v.x, -PATTERN_REACH, PATTERN_REACH),
				clampi(v.y, -PATTERN_REACH, PATTERN_REACH)), EDGE)
	for cell in offsets:
		var v := cell as Vector2i
		if absi(v.x) <= PATTERN_REACH and absi(v.y) <= PATTERN_REACH:
			_pattern_block(image, centre + v, LIT)
	_pattern_block(image, centre, SHADE)
	var texture := ImageTexture.create_from_image(image)
	_patterns[key] = texture
	return texture


# One two-by-two block of the mini-board, inside the edge.
static func _pattern_block(image: Image, cell: Vector2i, colour: Color) -> void:
	for dy in 2:
		for dx in 2:
			image.set_pixel(1 + cell.x * 2 + dx, 1 + cell.y * 2 + dy, colour)


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
