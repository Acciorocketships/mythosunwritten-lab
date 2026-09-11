extends PanelContainer
## What the colours painted on the ground mean, one swatch and one word each.
##
## The eighth panel of the interface, in the same Sprout Lands pack and the same
## theme as the seven before it, and the smallest of them: it says nothing about
## the world at all. Every other panel is a view of a simulation; this one is a
## key to a picture.
##
## It exists because some squares of the board overlay are drawn amber and
## nothing on screen said so much as that they were squares of anything. Amber is
## a cliff edge -- the one piece of ground a shove off can cost a character its
## whole life -- and a fight can be fought across a field of them.
##
## ## It is generated, not written
##
## Every row is one row of `render/board_legend.gd`, which is the table
## `render/main.gd` paints the ground from. The panel does not know how many
## colours there are, what any of them is, or what any of them means: it draws
## whatever the table holds, in the table's own order. So a colour cannot be
## painted without appearing here, and one cannot appear here without being
## painted -- there is no second list to keep in step, which is the whole reason
## the table was pulled out of the shell.
##
## ## The swatch is the colour as it lands on the ground
##
## Every board colour is see-through: what is painted is a tint over grass. A
## swatch drawn straight onto the panel would be that tint over a cream frame,
## which is a different colour from the one on the ground. So each swatch is two
## layers -- an opaque backing and the tint over it, at its own alpha -- exactly
## as the ground is, and `UNDER` is what the backing is.
##
## A row the board checkers -- ordinary ground, painted in two close shades of
## blue by the parity of the cell -- has both of its shades over the one backing,
## side by side, so the swatch is a picture of what that meaning looks like on
## the ground. The panel is told which those are by the table (`shades_of`); it
## does not know that any row has two, only how many the table handed it.
##
## ## Sizes
##
## In pixels of the art, before the whole interface is scaled up by a whole
## number (render/ui/pixel_ui.gd), as on every other panel.
class_name LegendPanel

## How wide the panel is, in art pixels. Wider than the combat readout it sits
## under, because three swatches and three words have to fit across it and a
## legend trimmed to an ellipsis explains nothing.
const WIDTH := 300

## How many entries are drawn side by side. Three, because nine of them in one
## column is a strip a third of the height of the window for something a person
## reads once, and the window the game ships in has no third of a column spare.
const COLUMNS := 3

## The swatch, in art pixels: the art's own cell.
const SWATCH := SproutPack.CELL

## The gaps, in art pixels: eighths of the art's own cell, as on the others.
const GAP := 2
const ROW_GAP := 2

## What a swatch is drawn over, so the tint reads as it does on the ground
## rather than as it does over a cream panel. A mid grey-green: neither the
## grass nor the panel, and dark enough that the pale end of the palette is
## visible against it and light enough that the dark end is.
const UNDER := Color(0.32, 0.36, 0.30, 1.0)

## What the panel is called on screen.
const TITLE := "the ground"


## Built here rather than in `_ready`, for the reason the other panels are: the
## panel is a whole panel the moment it exists, so a test can build one and read
## what it says with no window anywhere.
func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	var title := Label.new()
	title.theme_type_variation = SproutTheme.HEADING_LABEL
	title.text = TITLE
	column.add_child(title)

	# The table, in the table's own order, wrapped into however many rows
	# COLUMNS makes of it. Nothing here names a colour or a meaning.
	var entries := BoardLegend.rows()
	var across: HBoxContainer = null
	for at in entries.size():
		if at % COLUMNS == 0:
			across = HBoxContainer.new()
			across.add_theme_constant_override("separation", GAP)
			column.add_child(across)
		across.add_child(_entry(entries[at] as Dictionary))


## Whether there is a board on screen for this to be the key to.
##
## The shell asks the question -- it is the one that knows whether it drew a
## lattice this frame -- and the panel does no more than believe it. A key to a
## picture that is not there is clutter.
func show_board(drawn: bool) -> void:
	visible = drawn


## What the panel says, one line per colour, in the order the table holds them.
##
## The same rows the swatches are built from, as plain strings, so a test can
## pin what is drawn against the painting table with no window anywhere.
static func lines() -> PackedStringArray:
	var said := PackedStringArray()
	for row in BoardLegend.rows():
		said.append(String((row as Dictionary)["means"]))
	return said


# One swatch and one word: the tint over an opaque backing, and what the table
# says the colour means.
func _entry(row: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var backing := ColorRect.new()
	backing.color = UNDER
	backing.custom_minimum_size = Vector2(SWATCH, SWATCH)
	backing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# One shade over the whole backing, or each of a checkered row's shades over
	# its own share of it, in the table's order.
	var shades := BoardLegend.shades_of(row)
	for at in shades.size():
		var patch := ColorRect.new()
		patch.color = shades[at]
		patch.set_anchors_preset(Control.PRESET_FULL_RECT)
		patch.anchor_left = float(at) / float(shades.size())
		patch.anchor_right = float(at + 1) / float(shades.size())
		backing.add_child(patch)
	box.add_child(backing)

	var label := Label.new()
	label.text = SproutPack.drawable(String(row["means"]))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(
		WIDTH / COLUMNS - SWATCH - GAP * 2, 0)
	box.add_child(label)
	return box
