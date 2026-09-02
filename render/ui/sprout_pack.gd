extends RefCounted
## Where the Sprout Lands UI pack is, and which rectangle of it each part of the
## interface is cut from. The one table; nothing else under render/ui/ names a
## file on disk.
##
## The pack is 2D pixel art on a 16-pixel cell with a bundled font on an 8x14
## cell, and it is the user's own download rather than anything this project may
## carry: its licence permits modification and forbids redistribution "even if
## modified", and permits non-commercial use only. So there is no fetch script
## for it the way there is one for the CC0 KayKit models --
## `tools/extract_sprout_lands.sh` unpacks the zip the user put in `assets/`, and
## both the zip and what comes out of it are ignored by git. README, "Where the
## art comes from".
##
## ## Why regions rather than files
##
## The parts the interface wants are not one-per-file in the pack. The wooden
## nine-slice frame the panel is built out of exists only inside the master
## sheet; the buttons ship as a four-tint strip; the icons ship as one sheet of
## eighteen columns by three rows. So every constant below is a rectangle in
## pixels into one of six aliased files, and `region()` turns one into something
## drawable. A rectangle is checked against the file it names, so a pack that
## changed shape fails loudly here instead of drawing the wrong sixteen pixels
## somewhere.
##
## ## The cell, and why the numbers are all multiples of it
##
## Sixteen pixels for the art, fourteen for the font's own line. Every size the
## interface asks for is a whole number of those, and the whole interface is then
## drawn at a whole-number scale with nearest-neighbour filtering
## (`project.godot`, `textures/canvas_textures/default_texture_filter`), because
## a pixel that is not square is the one way this pack can look wrong beside a
## 3D world.
class_name SproutPack

## Where tools/extract_sprout_lands.sh puts the pack.
const ROOT := "res://assets/sprout_lands_ui/"

## The six aliases the extractor writes at the pack root. The pack's own layout
## has spaces, a misspelling and one name that ends in a space before its
## extension; the aliases exist so none of that is spelled in the render layer.
const SHEET := ROOT + "ui_sheet.png"
const BUTTONS := ROOT + "buttons.png"
const ICONS := ROOT + "icons.png"
const HEARTS := ROOT + "hearts.png"
const SLOTS := ROOT + "slots.png"
const FONT := ROOT + "pixel_font.ttf"

## Every file the interface needs, for the one question "is the pack here".
const FILES := [SHEET, BUTTONS, ICONS, HEARTS, SLOTS, FONT]

## The art's cell, and the font's. Every size in the interface is a multiple of
## one of these two numbers.
const CELL := 16
const FONT_CELL := 14

# --- The frame ------------------------------------------------------------

## The wooden picture frame, out of the master sheet: cream rails with knobbed
## corners around a darker interior. Three tints ship, at y = 9, 57 and 105; this
## is the lightest, which is the only one with enough contrast against the world
## behind it.
const FRAME := Rect2i(153, 9, 30, 30)

## How much of the frame is corner rather than middle, for the nine-slice. The
## rails are eight pixels of wood plus a pixel of shadow; slicing at nine leaves
## a 12x12 middle to stretch and keeps every corner knob intact.
const FRAME_MARGIN := 9

# --- The buttons ----------------------------------------------------------

## The cream button, idle and pressed, out of the four-tint strip. The idle face
## carries two rows of drop shadow under it and the pressed face does not, which
## is the pack's own way of saying a button went down: the same 26x26 face, two
## pixels lower.
const BUTTON_IDLE := Rect2i(11, 59, 26, 28)
const BUTTON_DOWN := Rect2i(59, 59, 26, 26)
## The pale face from the strip's first row, used for hover. It is the same
## button lit, not a different button.
const BUTTON_HOVER := Rect2i(11, 11, 26, 28)
const BUTTON_MARGIN := 8

# --- The slots ------------------------------------------------------------

## An inventory slot, in the pack's three tints. Something in a slot lightens it,
## which is the pack's own read: the light plate is the front one.
const SLOT_FULL := Rect2i(9, 57, 30, 32)
const SLOT_EMPTY := Rect2i(105, 57, 30, 32)

# --- The hearts -----------------------------------------------------------

## Full, half and empty, left to right along the sheet's first row.
const HEART_FULL := Rect2i(0, 0, 16, 16)
const HEART_HALF := Rect2i(16, 0, 16, 16)
const HEART_EMPTY := Rect2i(32, 0, 16, 16)

# --- The generic icons ----------------------------------------------------

## The icon sheet is eighteen columns by three rows: the same eighteen icons in
## white (columns 0-5), cream (6-11) and tan (12-17). Cream is the set that reads
## against the frame's dark interior, so every icon named here is a cream one.
const ICON_CREAM_COLUMN := 6

## The four generic icons this panel uses, by their column and row in the sheet's
## cream set. Everything else on the panel is drawn rather than taken; see
## render/ui/pixel_icons.gd, which says which is which one by one.
const ICON_STAR := Vector2i(5, 0)
const ICON_CROWN := Vector2i(5, 1)
const ICON_COIN := Vector2i(1, 1)
const ICON_WORN := Vector2i(3, 2)
const ICON_NO_SLOT := Vector2i(5, 2)


# One cut per rectangle, made on first ask. A cut is a read-only window onto a
# sheet, so there is no reason for two askers to hold two of them -- and the
# panel asks for the same handful on every rebuild.
static var _cuts := {}


## Whether the pack has been unpacked. False on a clone where the user's zip is
## not present, which is a supported state: the render shell then draws the world
## and says why there is no panel over it.
static func is_installed() -> bool:
	for path in FILES:
		if not ResourceLoader.exists(path):
			return false
	return true


## One rectangle of one of the pack's files, as something a Control can draw.
##
## The rectangle is checked against the file's real size, so a pack whose sheets
## changed shape fails here with the name of the constant that no longer fits
## rather than quietly drawing the neighbouring sixteen pixels.
static func region(path: String, rect: Rect2i) -> AtlasTexture:
	var key := "%s%s" % [path, str(rect)]
	if _cuts.has(key):
		return _cuts[key]
	var sheet: Texture2D = load(path)
	if sheet == null:
		push_error("SproutPack: %s is not there; run tools/extract_sprout_lands.sh" % path)
		return null
	if rect.position.x < 0 or rect.position.y < 0 \
			or rect.end.x > sheet.get_width() or rect.end.y > sheet.get_height():
		push_error("SproutPack: %s is %dx%d and does not hold %s" % [
			path, sheet.get_width(), sheet.get_height(), str(rect),
		])
		return null
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = Rect2(rect)
	# Off, deliberately: a filtered edge is exactly the blur this pack must not
	# have, and an atlas that trims its own edges would move the art off the
	# 16-pixel grid it was drawn on.
	cut.filter_clip = false
	_cuts[key] = cut
	return cut


## One 16x16 icon out of the generic sheet, addressed by its place in the cream
## set rather than by a pixel offset.
static func icon(at: Vector2i) -> AtlasTexture:
	return region(ICONS, Rect2i(
		(ICON_CREAM_COLUMN + at.x) * CELL, at.y * CELL, CELL, CELL
	))
