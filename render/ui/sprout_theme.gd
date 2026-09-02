extends RefCounted
## The Sprout Lands pack as a Godot theme: nine-sliced frames, buttons, slots and
## the pack's own font, with nothing of the engine's default theme left in it.
##
## ## What "no engine default" means here, concretely
##
## A Control with no theme draws the engine's own: a grey flat panel, a grey
## button, and whatever font the engine ships. Overriding some of that and not
## the rest is the usual way a themed interface ends up half grey, so this file
## sets, for every type the panel puts on screen, every style and colour that type
## can draw with -- including the ones nothing in this panel triggers, like a
## disabled button -- and hands back one `Theme` that the panel's root carries.
## Every Control under that root inherits it, and no Control in the panel sets a
## style of its own.
##
## ## The font, and the two switches that decide whether this looks right
##
## `pixelFont-7-8x14-sproutLands.ttf` is a pixel font on an 8x14 cell: at size 14
## a capital is exactly eight pixels wide, which is the size it was drawn to be
## read at. Two engine defaults would ruin it and both are turned off here:
##
##   * **antialiasing**, on by default (`FONT_ANTIALIASING_GRAY`), which puts
##     grey along every edge of a glyph that was drawn with none;
##   * **hinting**, on by default (`HINTING_LIGHT`), which nudges stems onto the
##     pixel grid -- helpful for a typeface with curves, and for one whose stems
##     are already exactly on the grid it can only move them off it.
##
## `oversampling` is pinned to 1.0 for the same reason. Left alone the engine
## rasterises a glyph at whatever size the canvas transform will draw it at,
## which for a whole-number scale would be harmless and for anything else would
## be a re-rasterised pixel font. Pinned, a glyph is always rasterised at its
## nominal size and the canvas scales it as an image, with the nearest-neighbour
## filter the project asks for -- so one glyph pixel is always a whole number of
## screen pixels, at any scale, by construction.
##
## Sizes are multiples of the font's own fourteen-pixel cell: 14 for body text
## and 28 for the character's name, and nothing between.
##
## tools/measure_ui.sh measures the result rather than trusting this comment: it
## counts how many distinct colours the drawn panel contains and how much of its
## detail lands off the pixel grid.
class_name SproutTheme

## The font's own cell, and the only sizes anything is drawn at.
const BODY_SIZE := SproutPack.FONT_CELL
const TITLE_SIZE := SproutPack.FONT_CELL * 2

## The pack's palette, sampled out of its own art. Text is the lightest cream the
## buttons are drawn in; a heading is the cream of the icon sheet; a dimmed line
## is the tan of the frame's rails.
const TEXT := Color8(0xf3, 0xe5, 0xc2)
const HEADING := Color8(0xe8, 0xcf, 0xa6)
const DIM := Color8(0xc4, 0x9a, 0x6c)
## The pack's own dark, for a shadow under text over the frame's brown interior,
## and for the label on a cream button. Taken out of the pack rather than
## invented -- an earlier draft used a darker brown of its own, and
## tools/measure_ui.sh reported it as the one off-palette colour on the panel,
## which is exactly the thing that measurement exists to catch.
const SHADOW := Color8(0x64, 0x55, 0x52)

## The theme type variations the panel asks for by name. A variation is how one
## Theme carries two looks for one Control type -- an occupied slot and an empty
## one are both `Panel`, drawn from two different plates of the pack.
const SLOT_FULL := "SproutSlotFull"
const SLOT_EMPTY := "SproutSlotEmpty"
const TITLE := "SproutTitle"
const HEADING_LABEL := "SproutHeading"
const DIM_LABEL := "SproutDim"


## The whole theme, or null when the pack is not unpacked.
static func build() -> Theme:
	if not SproutPack.is_installed():
		push_warning(
			"SproutTheme: the Sprout Lands pack is not unpacked; "
			+ "run ./tools/extract_sprout_lands.sh"
		)
		return null

	var theme := Theme.new()
	var font := build_font()
	theme.default_font = font
	theme.default_font_size = BODY_SIZE
	theme.default_base_scale = 1.0

	_dress_panels(theme)
	_dress_labels(theme, font)
	_dress_buttons(theme, font)
	return theme


## The pack's font, with antialiasing and hinting off. Public because the check
## that they really are off is a test, and a test should ask the object rather
## than read this file.
static func build_font() -> FontFile:
	var font := FontFile.new()
	var err := font.load_dynamic_font(SproutPack.FONT)
	if err != OK:
		push_error("SproutTheme: could not read %s (%d)" % [SproutPack.FONT, err])
		return null
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.multichannel_signed_distance_field = false
	font.generate_mipmaps = false
	font.force_autohinter = false
	# See the note above: one glyph pixel is a whole number of screen pixels at
	# any canvas scale exactly because this is not left to the engine.
	font.oversampling = 1.0
	# Nothing here should ever reach for a system typeface: a missing glyph must
	# show as a missing glyph, not as a smooth one in somebody else's font.
	font.allow_system_fallback = false
	return font


## The frame, and the two slot plates. All three are the pack's own art
## nine-sliced, so a panel of any size is the same frame with a longer rail.
static func _dress_panels(theme: Theme) -> void:
	var frame := _sliced(SproutPack.SHEET, SproutPack.FRAME, SproutPack.FRAME_MARGIN)
	# Content is inset past the rails by the rails' own width, plus four pixels
	# of air so nothing is drawn touching the wood.
	frame.content_margin_left = SproutPack.FRAME_MARGIN + 4
	frame.content_margin_right = SproutPack.FRAME_MARGIN + 4
	frame.content_margin_top = SproutPack.FRAME_MARGIN + 4
	frame.content_margin_bottom = SproutPack.FRAME_MARGIN + 4
	for type in ["Panel", "PanelContainer"]:
		theme.set_stylebox("panel", type, frame)

	# A slot is drawn at the size of the plate it is cut from, so its nine-slice
	# never actually stretches; it is sliced anyway so that a wider slot later is
	# a number rather than a new sprite.
	for variation in [
		[SLOT_FULL, SproutPack.SLOT_FULL], [SLOT_EMPTY, SproutPack.SLOT_EMPTY],
	]:
		var name: String = variation[0]
		var plate := _sliced(SproutPack.SLOTS, variation[1], 10)
		theme.add_type(name)
		theme.set_type_variation(name, "Panel")
		theme.set_stylebox("panel", name, plate)


## Every colour and size a Label can draw with, so none of them falls back.
static func _dress_labels(theme: Theme, font: FontFile) -> void:
	for entry in [
		["Label", TEXT, BODY_SIZE],
		[TITLE, HEADING, TITLE_SIZE],
		[HEADING_LABEL, HEADING, BODY_SIZE],
		[DIM_LABEL, DIM, BODY_SIZE],
	]:
		var type: String = entry[0]
		if type != "Label":
			theme.add_type(type)
			theme.set_type_variation(type, "Label")
		theme.set_font("font", type, font)
		theme.set_font_size("font_size", type, entry[2])
		theme.set_color("font_color", type, entry[1])
		theme.set_color("font_shadow_color", type, SHADOW)
		theme.set_color("font_outline_color", type, SHADOW)
		theme.set_constant("shadow_offset_x", type, 1)
		theme.set_constant("shadow_offset_y", type, 1)
		theme.set_constant("outline_size", type, 0)
		theme.set_constant("shadow_outline_size", type, 0)
		theme.set_constant("line_spacing", type, 3)
		theme.set_stylebox("normal", type, StyleBoxEmpty.new())


## The button, in the pack's three faces: idle, lit, and two pixels down.
static func _dress_buttons(theme: Theme, font: FontFile) -> void:
	var idle := _sliced(SproutPack.BUTTONS, SproutPack.BUTTON_IDLE, SproutPack.BUTTON_MARGIN)
	var hover := _sliced(SproutPack.BUTTONS, SproutPack.BUTTON_HOVER, SproutPack.BUTTON_MARGIN)
	var down := _sliced(SproutPack.BUTTONS, SproutPack.BUTTON_DOWN, SproutPack.BUTTON_MARGIN)
	# The pressed face is the idle face with its two rows of shadow gone, so a
	# press is the label moving down into where the shadow was. That is the
	# pack's own animation and it costs one number here.
	down.content_margin_top = 4
	down.content_margin_bottom = 0
	idle.content_margin_top = 2
	idle.content_margin_bottom = 2
	hover.content_margin_top = 2
	hover.content_margin_bottom = 2
	theme.set_stylebox("normal", "Button", idle)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", down)
	theme.set_stylebox("hover_pressed", "Button", down)
	theme.set_stylebox("disabled", "Button", idle)
	# No focus ring: the engine's is a blue rectangle, and there is nothing in
	# this pack it could be drawn out of.
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_font("font", "Button", font)
	theme.set_font_size("font_size", "Button", BODY_SIZE)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", SHADOW)
	theme.set_color("font_disabled_color", "Button", DIM)
	theme.set_color("font_outline_color", "Button", SHADOW)
	theme.set_constant("outline_size", "Button", 0)
	theme.set_constant("h_separation", "Button", 2)


## One rectangle of one pack file, nine-sliced by the same margin on all sides.
static func _sliced(path: String, rect: Rect2i, margin: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.region_rect = Rect2(rect)
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	# Tiled would repeat the rail's grain and put a seam wherever the repeat did
	# not divide the length; stretched holds one rail of wood at any width, which
	# is what the art was drawn for -- its middles are flat.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return box
