extends PanelContainer
## The dialogue panel: what a character said and what it heard, in full.
##
## The fifth panel of the interface, in the same Sprout Lands pack and the same
## theme as the character sheet, the combat readout and the two play panels.
## The model layer gave it a subject: characters say and shout through the
## atomic action surface, and five of six characters in the shipped run decide
## by asking a language model -- so there is finally a conversation to read
## rather than a mechanism to imagine. The play panel keeps its two lines of
## gossip beside the aim; this panel is the exchange itself.
##
## ## It quotes; it does not phrase
##
## Every line on it comes off `SimWorld.surroundings_of()`, which is
## `Observation` -- the same packet a language-model mind is handed -- turned
## into plain rows. Who could hear a line at all is the engine's own answer
## (`ActionEngine._say` writes `heard_by`, the observation filters by it), so a
## line is on this panel exactly when the character being read could hear it:
## its own words included, spoken-to-you lines included, a line said between
## two other people deliberately not. The wording of a line is
## `PlayPanel.heard_line`, the same sentence the play panel writes, because two
## spellings of who-said-what would drift apart.
##
## ## It is a view, and it holds nothing
##
## Like every panel before it, it keeps a handle on the world and the id of the
## character being read, and reads both again on every frame. There is no copy
## of a line here, no transcript kept on this side and no signal to keep in
## step: throw the panel away, rebuild it from the same world and it says the
## same thing.
##
## ## Sizes
##
## In pixels of the art, before the whole interface is scaled up by a whole
## number (render/ui/pixel_ui.gd), as on the other panels.
class_name DialoguePanel

## How wide the panel is, in art pixels: seventeen of the art's cells. A shade
## narrower than the answer panel, so that with a person playing -- the
## choosing panels stacked bottom-left, these bottom-right -- the two columns
## and the frame's own rails all fit a 320-art-pixel-tall window's width. The
## lines wrap rather than trim, so nothing is lost to the narrowing.
const WIDTH := 272

## How many lines of speech are drawn: everything the observation carries,
## which is `Observation.HEARD` -- the packet's own cap, not a second one.
const ROWS := 6

## The gaps, in art pixels: eighths of the art's own cell, as on the other
## panels.
const GAP := 2
const ROW_GAP := 2

## What the panel reads while nothing has been said within earshot.
const RESTING := "nothing said within earshot"

## The world being read and which character's hearing this is. Handles, never
## written to.
var world: SimWorld = null
var heard_by := 0

var _head: Label
var _rows: Array[Label] = []
var _faces := {}


## Built here rather than in `_ready`, for the reason the other panels are: the
## panel is a whole panel the moment it exists, so a test can build one, hand
## it a world and read what it says with no window anywhere.
func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_STOP
	_faces = {
		"mark": SproutPack.icon(SproutPack.ICON_MARK),
		"dash": SproutPack.icon(SproutPack.ICON_DASH),
	}

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	_head = Label.new()
	_head.theme_type_variation = SproutTheme.HEADING_LABEL
	_head.text = "dialogue"
	column.add_child(_head)
	for _each in ROWS:
		var said := _sentence()
		_rows.append(said)
		column.add_child(_labelled(_faces["dash"], said))
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Watch a world and the character whose hearing is being read. The handles,
## not their contents: everything is read again every frame.
func watch(watching: SimWorld, id: int) -> void:
	world = watching
	heard_by = id


## Read the panel off the world again.
func refresh() -> void:
	visible = world != null and heard_by != 0
	if not visible:
		return
	var heard := world.surroundings_of(heard_by).heard
	_head.text = "dialogue %d" % heard.size()
	for index in _rows.size():
		var at := heard.size() - _rows.size() + index
		var row: Label = _rows[index]
		if at < 0:
			row.text = ""
			_show(row, false)
			continue
		var said: Dictionary = heard[at]
		row.text = SproutPack.drawable(PlayPanel.heard_line(said))
		# Your own words are the dim ones: what was said to you is what you are
		# reading this panel for.
		row.theme_type_variation = StringName(
			SproutTheme.DIM_LABEL) if bool(said["yours"]) else StringName("")
		_marker(row, _faces["mark"] if bool(said["to_you"]) else _faces["dash"])
		_show(row, true)
	# An empty conversation is said rather than blanked, on the first row.
	if heard.is_empty():
		_rows[ROWS - 1].text = RESTING
		_rows[ROWS - 1].theme_type_variation = StringName(SproutTheme.DIM_LABEL)
		_marker(_rows[ROWS - 1], _faces["dash"])
		_show(_rows[ROWS - 1], true)


## One sentence, wrapped rather than trimmed: a line that ends in an ellipsis
## is not what was said. Three lines of room, because the models write longer
## sentences than the canned ones and this panel's whole point is to quote.
func _sentence() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 3
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(WIDTH - SproutPack.CELL - GAP, 0)
	return label


func _show(row: Label, showing: bool) -> void:
	row.visible = showing
	var holder := row.get_parent() as Control
	if holder != null:
		holder.visible = showing


func _marker(row: Label, face: Texture2D) -> void:
	var holder := row.get_parent()
	if holder != null and holder.get_child_count() > 0:
		(holder.get_child(0) as TextureRect).texture = face


# One row: a 16x16 sprite at exactly its own size and the sentence beside it,
# as on the other panels -- a pixel of the art is a pixel of the interface, and
# the interface is what is scaled.
func _labelled(texture: Texture2D, label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(SproutPack.CELL, SproutPack.CELL)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(rect)
	row.add_child(label)
	return row
