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
## Nothing here belongs to the simulation. This layer, the panel under it, the
## theme and the pack are all render-side; a headless run loads not one of them,
## which `./run_headless.sh --assets` says from outside by asking the engine's
## own resource cache.
class_name PixelUi

## How many pixels of window height buy one step of interface scale.
const DESIGN_HEIGHT := 320

## How far the panel sits from the corner, in art pixels.
const MARGIN := 8

## The panel this layer exists to hold.
var panel: CharacterPanel = null

## What the interface is being multiplied by. Read by the measuring tool, which
## has to know what a whole number is before it can check for one.
var art_scale := 1

var _frame: MarginContainer = null


## The layer, the theme and the panel, ready to be added to the scene -- or null
## when the pack has not been unpacked, in which case the caller says so and the
## world is drawn without an interface over it.
static func build() -> PixelUi:
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
	layer.panel = CharacterPanel.new()
	layer.panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layer.panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	layer._frame.add_child(layer.panel)
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
