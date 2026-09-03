extends CanvasLayer
## The interface's own layer, held at a whole-number scale over the 3D world.
##
## The world is low-poly 3D and the interface is 16-pixel pixel art. That pairing
## is the point, and it only works while a pixel of the art is a whole number of
## pixels on the screen -- half a pixel of art is a blurred edge, and a blurred
## edge next to a crisp one is what makes a pixel interface look broken rather
## than deliberate. So the whole interface is laid out in the art's own pixels and
## this layer multiplies it by an integer, never by a fraction, and the project's
## canvas filter is nearest-neighbour so the multiplication has no opinion of its
## own about what is between two pixels.
##
## The scale comes from the window's height: one step per `DESIGN_HEIGHT` pixels
## of window, never less than one. A 720-pixel window draws at 2, a 1080-pixel
## one at 3, and a window too small for even that draws at 1 and lets the panel
## run off the bottom rather than shrinking it to a fraction.
##
## ## Four panels, one theme
##
## The character sheet sits in the top-left corner, the combat readout in the
## top-right, and the two a person playing needs -- what they have aimed at and
## what the world answered -- stack along the bottom left. They are asked for
## separately, so a run may have any of them, all of them or none. What they
## may not have is three ideas of what the interface looks like, so the theme is
## built once here and carried by the frame the panels sit in; no panel builds a
## style of its own and none names a file on disk.
##
## Nothing here belongs to the simulation. This layer, the panels under it, the
## theme and the pack are all render-side; a headless run loads not one of them,
## which `./run_headless.sh --assets` says from outside by asking the engine's
## own resource cache.
class_name PixelUi

## How many pixels of window height buy one step of interface scale.
const DESIGN_HEIGHT := 320

## How far the panels sit from the corners, in art pixels.
const MARGIN := 8

## The character sheet, or null in a run that did not ask for one.
var panel: CharacterPanel = null

## The combat readout, or null in a run that did not ask for one.
var readout: CombatPanel = null

## What the person driving chose and what the world answered, or null in a run
## with nobody driving.
var answer: AnswerPanel = null

## What the person driving has aimed at, what is on the table and what has been
## said within earshot, or null in a run with nobody driving. It sits above the
## answer panel: what you are about to do, and then what came of the last thing
## you did.
var play: PlayPanel = null

## What the interface is being multiplied by. Read by the measuring tool, which
## has to know what a whole number is before it can check for one.
var art_scale := 1

var _frame: MarginContainer = null


## The layer, the theme and whichever panels were asked for, ready to be added to
## the scene -- or null when the pack has not been unpacked, in which case the
## caller says so and the world is drawn without an interface over it.
##
## The defaults are the character sheet alone, which is what `--sheet` has always
## meant and what every existing caller asks for.
static func build(
	with_sheet: bool = true, with_readout: bool = false,
	with_answer: bool = false,
) -> PixelUi:
	var theme := SproutTheme.build()
	if theme == null:
		return null
	var layer := PixelUi.new()
	layer.layer = 1
	layer._frame = MarginContainer.new()
	layer._frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	layer._frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		layer._frame.add_theme_constant_override(side, MARGIN)
	layer._frame.theme = theme

	# One row across the whole window: the sheet packed to the left, the readout
	# to the right, and whatever space is left between them. A run with only one
	# of the two still puts it in its own corner, because the spacer is what
	# holds the gap rather than either panel's position.
	var across := HBoxContainer.new()
	across.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	across.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	across.alignment = BoxContainer.ALIGNMENT_BEGIN
	if with_sheet:
		layer.panel = CharacterPanel.new()
		layer.panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		layer.panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		across.add_child(layer.panel)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	across.add_child(gap)
	if with_readout:
		layer.readout = CombatPanel.new()
		across.add_child(layer.readout)

	# One column down the window: the two top panels in their row, whatever space
	# is left, and the answer panel at the bottom. The row is what holds the two
	# corners apart and the space is what holds the bottom down, so a run with
	# only some of the three still puts each where it belongs.
	var down := VBoxContainer.new()
	down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	down.add_child(across)
	var below := Control.new()
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	below.size_flags_vertical = Control.SIZE_EXPAND_FILL
	down.add_child(below)
	if with_answer:
		layer.play = PlayPanel.new()
		down.add_child(layer.play)
		layer.answer = AnswerPanel.new()
		down.add_child(layer.answer)
	layer._frame.add_child(down)
	layer.add_child(layer._frame)
	return layer


func _ready() -> void:
	_fit(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(_on_resize)


func _on_resize() -> void:
	_fit(get_viewport().get_visible_rect().size)


## Multiply the interface by the largest whole number the window has room for.
func _fit(window: Vector2) -> void:
	art_scale = maxi(1, int(window.y) / DESIGN_HEIGHT)
	scale = Vector2(art_scale, art_scale)
	# The frame is laid out in art pixels, so it is as many of them across as the
	# window is screen pixels divided by the scale.
	if _frame != null:
		_frame.size = window / float(art_scale)


## Where a panel landed and how big it came out, in screen pixels: what the
## measuring tool needs in order to ask whether that rectangle is made of whole
## art pixels. Empty for a panel this run did not build.
func geometry_of(which: Control) -> Rect2i:
	if which == null:
		return Rect2i()
	return Rect2i(
		int(which.global_position.x * art_scale),
		int(which.global_position.y * art_scale),
		int(which.size.x * art_scale),
		int(which.size.y * art_scale),
	)
