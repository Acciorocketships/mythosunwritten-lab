extends PanelContainer
## What the person driving has chosen, and what the world said about it.
##
## The third panel of the interface, in the same Sprout Lands pack and the same
## theme as the character sheet and the combat readout. It exists because
## section 2.1's second sentence -- any action may fail with a returned reason --
## is addressed to whoever chose, and once whoever chose is a person the reason
## has to reach a screen or it has not been returned to anybody.
##
## ## It quotes; it does not phrase
##
## Every sentence on this panel is the simulation's own. What was chosen is
## `Action.line()`, and what came of it is `ActionOutcome.line()`, both carried
## out of `ControlLoop.answer_of` unchanged. There is no table of friendly
## wordings here, no rewriting of "12.00 is further than DEX 3 jumps (3.75)" into
## something an interface author preferred, and no sentence written on this side
## of the line at all except the two labels that say which row is which and the
## resting line that says nobody has chosen anything yet. If the engine changes
## how it refuses a jump, this panel says the new thing without being touched.
##
## ## It is a view, and it holds nothing
##
## Like the combat readout, it keeps a handle on the world and on the holder the
## person's choices go into, and reads both again on every frame. There is no
## copy of a choice here, no note of the last refusal and no signal to keep in
## step. Throw the panel away, rebuild it from the same world and it says the
## same thing.
##
## ## Sizes
##
## In pixels of the art, before the whole interface is scaled up by a whole
## number (render/ui/pixel_ui.gd). Sixteen is the art's cell and fourteen the
## font's, as on the other two panels.
class_name AnswerPanel

## How wide the panel is, in art pixels. Wider than the other two because what it
## carries is a sentence rather than a name and a number, and a refusal that is
## trimmed to an ellipsis is a refusal that has not been returned.
const WIDTH := 296

## How many lines of the sentence are drawn before it is trimmed. Two is enough
## for every refusal the engine currently writes at this width.
const ANSWER_LINES := 2

## The gaps, in art pixels: eighths of the art's own cell, as on the other
## panels.
const GAP := 2
const ROW_GAP := 4

## What the choice row reads when nobody has chosen anything -- which is the
## ordinary state of a person's character, and the state the world reads as
## "waits in the world".
const RESTING := "waiting for you"

## The world being read, and where the choices of whoever is driving go. Both
## are handles, never written to.
var world: SimWorld = null
var choice: LiveChoice = null

## Which character is being driven, by the id the world knows it by.
var driven_id := 0

var _chose_label: Label
var _answer_icon: TextureRect
var _answer_label: Label
var _faces := {}


## Built here rather than in `_ready`, for the reason the other two panels are:
## the panel is a whole panel the moment it exists, so a test can build one, hand
## it a world and read what it says with no window anywhere.
func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_STOP
	_faces = {
		"mark": SproutPack.icon(SproutPack.ICON_MARK),
		"tick": SproutPack.icon(SproutPack.ICON_TICK),
		"bar": SproutPack.icon(SproutPack.ICON_BAR),
	}

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	var chose_row := _row()
	chose_row.add_child(_sprite(_faces["mark"]))
	_chose_label = _sentence()
	chose_row.add_child(_chose_label)
	column.add_child(chose_row)

	var answer_row := _row()
	_answer_icon = _sprite(_faces["tick"])
	answer_row.add_child(_answer_icon)
	_answer_label = _sentence()
	answer_row.add_child(_answer_label)
	column.add_child(answer_row)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Watch a world and the holder one of its characters is being driven through.
## The handles, not their contents: everything is read again every frame.
func watch(watching: SimWorld, id: int, driving: LiveChoice) -> void:
	world = watching
	driven_id = id
	choice = driving


## Read the panel off the world again.
func refresh() -> void:
	visible = choice != null and driven_id != 0
	if not visible:
		return
	_chose_label.text = RESTING if choice.waiting() else choice.line()
	_chose_label.theme_type_variation = StringName(
		SproutTheme.DIM_LABEL) if choice.waiting() else StringName("")

	var answer := _answer()
	var said := String(answer.get("line", ""))
	_answer_label.text = said
	_answer_icon.visible = said != ""
	_answer_label.visible = said != ""
	if said == "":
		return
	var refused := not bool(answer.get("ok", true))
	# A refusal is what this panel is for, so it is the one that is not dimmed.
	_answer_icon.texture = _faces["bar"] if refused else _faces["tick"]
	_answer_label.theme_type_variation = StringName(
		"") if refused else StringName(SproutTheme.DIM_LABEL)


## What the engine last answered the character being driven, as the loop wrote it
## down. An empty dictionary before it has answered anything.
func last_answer() -> Dictionary:
	return _answer()


func _answer() -> Dictionary:
	if world == null or world.loop == null or driven_id == 0:
		return {}
	return world.loop.answer_of(driven_id)


## One sentence, wrapped rather than trimmed: see WIDTH.
func _sentence() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = ANSWER_LINES
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(WIDTH - SproutPack.CELL - GAP, 0)
	return label


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	return row


## One 16x16 sprite at exactly its own size, as on the other two panels: a pixel
## of the art is a pixel of the interface, and the interface is what is scaled.
func _sprite(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(SproutPack.CELL, SproutPack.CELL)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return rect
