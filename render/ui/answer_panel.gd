extends PanelContainer
## What the person driving has chosen, and what the world said about it.
##
## The third panel of the interface, in the same Sprout Lands pack and the same
## theme as the character sheet and the combat readout. It exists because
## section 2.1's second sentence -- any action may fail with a returned reason --
## is addressed to whoever chose, and once whoever chose is a person the reason
## has to reach a screen or it has not been returned to anybody.
##
## ## It quotes the answer; it re-words the choice
##
## The answer row is the simulation's own sentence and nothing else.
## `ActionOutcome.line()`, carried out of `ControlLoop.answer_of` unchanged --
## through `SproutPack.drawable()`, which swaps the handful of characters the
## art's font has no glyph for and changes no word. There is no table of friendly
## wordings for it, no rewriting of "12.00 is further than DEX 3 jumps (3.75)"
## into something an interface author preferred. If the engine changes how it
## refuses a jump, this panel says the new thing without being touched.
##
## The choice row is the one place that is not a quotation, and it is not one
## because `Action.line()` is a call rather than a sentence: in this font
## `say(text="what will you take for it?")` draws as
## `SAYITEXT="WHAT WILL YOU TAKE FOR IT?"I`, brackets as bare strokes and the
## comma as a full stop. `render/ui/action_sentence.gd` writes the same choice as
## English, out of the action's own kind and parameters and nothing else -- it
## reads no world, decides nothing, and cannot say why anything did or did not
## happen. The simulation's own spelling is untouched and is still what the
## journal, the traces and the comparison below are written in.
##
## ## An answer says how old it is, and stops being shown
##
## An answer used to sit on this panel for ever. A refusal from two hundred ticks
## ago, still drawn under a fresh choice, reads as the answer to the key just
## pressed. So two things: the age of the answer is drawn beside it, in the
## world's own ticks, and once it is older than `ANSWER_LIFE` it is not drawn at
## all. Both are one pure function, `age_line()`, so the whole of the rule is one
## thing a test can pin.
##
## ## It is a view, and it holds nothing
##
## Like the combat readout, it keeps a handle on the world and on the holder the
## person's choices go into, and reads both again on every frame. There is no
## copy of a choice here, no note of the last refusal and no signal to keep in
## step. Throw the panel away, rebuild it from the same world and it says the
## same thing.
##
## That is also why the answer row can go blank while the choice row is not. The
## panel shows the world's answer to the choice it is showing; a choice the world
## has not answered yet has no answer, and the last one the world happened to
## give about something else is not it.

## ## Being beaten -- and having left a fight -- are said here too
##
## One thing on the panel is not about a choice at all: a character that has been
## beaten reads that it has, on the choice row, instead of being told the world is
## waiting for it. That sentence is the engine's like all the others
## (`ActionEngine.is_down`, carried out in the snapshot), and it wins over
## everything else the panel would otherwise draw -- see `refresh()`.
##
## A character that has walked out of a fight reads that it has, the same way and
## for the same reason (`ActionEngine.left_the_fight`, through
## `ActionScene.departure_of`), until it chooses something else. Without it the
## row under it went on showing the last thing the board refused them, which is
## an answer to a choice made on a board that is no longer theirs.
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

## How many ticks an answer goes on being drawn for.
##
## The longest thing a person can choose is a walk, and a walk is charged the
## strides it takes up to twenty ticks (`ActionCatalog`'s `go_to` row), so this
## is three of the longest actions there are: an answer stays through whatever it
## answered and a good pause after it, and a refusal nobody can still connect to
## a key they pressed goes away rather than standing in for the next one.
const ANSWER_LIFE := 60

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
## How old the answer under it is, in the world's own ticks. Its own row rather
## than a tail on the answer's own line, because the answer is a quotation and
## this is not part of it.
var _age_label: Label
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

	_age_label = Label.new()
	_age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_age_label.theme_type_variation = StringName(SproutTheme.DIM_LABEL)
	_age_label.custom_minimum_size = Vector2(WIDTH - SproutPack.CELL - GAP, 0)
	column.add_child(_age_label)
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
	# What has become of this character, if anything has: asked first, because it
	# is true whatever is standing in the holder and it is the one thing a person
	# most needs told. A character that has been beaten is out of the fight and
	# will not be asked for another turn, so a row that went on saying "waiting
	# for you" would be the interface asking them for one anyway. The sentence is
	# the simulation's own, carried out in the snapshot and quoted here like every
	# other sentence on this panel -- see `FightSource.defeat_in`.
	var beaten := defeat_line()
	if beaten != "":
		_chose_label.text = SproutPack.drawable(beaten)
		_chose_label.theme_type_variation = StringName("")
		# And nothing underneath it. Whatever the world last answered belonged
		# to a choice this character made while it was still standing; a walk
		# refused two hundred ticks ago, drawn under "is down", reads as the
		# answer to having been beaten.
		_answer_label.text = ""
		_answer_label.visible = false
		_answer_icon.visible = false
		_age_label.text = ""
		_age_label.visible = false
		return
	# Then what the world says about having walked out of a fight, for as long as
	# that is still the last thing that happened. Asked before the holder for the
	# same reason as being beaten is: the board that was answering this person's
	# keys is gone, and the last thing it said to them -- "the board decides where
	# a fighter goes", refused while they were still on it -- is not the answer to
	# having left it. Once they choose anything at all the world stops saying this
	# and the ordinary two rows come back.
	var left := departure_line()
	if left != "" and choice.waiting():
		_chose_label.text = SproutPack.drawable(left)
		_chose_label.theme_type_variation = StringName("")
		_answer_label.text = ""
		_answer_label.visible = false
		_answer_icon.visible = false
		_age_label.text = ""
		_age_label.visible = false
		return
	# The choice, as a sentence rather than as the call the simulation writes it
	# down as. `render/ui/action_sentence.gd` is handed the standing action and
	# nothing else, so what is drawn here is a pure function of what was chosen.
	_chose_label.text = RESTING if choice.waiting() else SproutPack.drawable(
		ActionSentence.of(choice.standing()))
	_chose_label.theme_type_variation = StringName(
		SproutTheme.DIM_LABEL) if choice.waiting() else StringName("")

	var answer := _answer()
	var said := SproutPack.drawable(String(answer.get("line", "")))
	# An answer belongs to the choice it answered. While a *different* choice is
	# standing -- one made since, that the world has not got to yet -- the older
	# answer is not drawn, because a green tick sitting under an action the world
	# has said nothing about reads as though that action had succeeded. Compared
	# by the two lines rather than by any counter kept here: both are the
	# simulation's own, `Action.line()` on one side and the loop's copy of the
	# same line on the other, so the comparison holds nothing.
	if not choice.waiting() and String(answer.get("action", "")) != choice.line():
		said = ""
	# And how long ago the world said it, which is the other half of the same
	# question: an answer with nothing to date it reads as the answer to the last
	# key pressed however old it is. Past `ANSWER_LIFE` there is no age to draw
	# and the row goes with it.
	var aged := "" if said == "" else age_line(now_tick(), int(answer.get("tick", 0)))
	if aged == "":
		said = ""
	_answer_label.text = said
	_answer_icon.visible = said != ""
	_answer_label.visible = said != ""
	_age_label.text = aged
	_age_label.visible = said != ""
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


## How old an answer given on one tick is when read on another, in words -- and
## "" for one so old it should not be drawn at all.
##
## The whole of the rule in one pure function, so that "says how old it is" and
## "stops being shown" are one decision rather than two that could disagree. A
## negative age cannot happen in a run -- the loop's clock and the world's move
## together -- and is read as "just now" rather than as a number nobody could
## make sense of.
static func age_line(now: int, then: int) -> String:
	var ago := maxi(0, now - then)
	if ago > ANSWER_LIFE:
		return ""
	if ago == 0:
		return "just now"
	if ago == 1:
		return "1 tick ago"
	return "%d ticks ago" % ago


## Which tick the world is on, or zero with no world to ask. The clock the
## answer's own `tick` was written against: `ControlLoop` stamps it off the
## scene, and the scene and the world advance on the same step.
func now_tick() -> int:
	return 0 if world == null else world.tick


## What the world says has become of the character being driven -- the engine's
## sentence for somebody who has been beaten -- and "" while they are standing.
##
## Read out of the snapshot on the frame it is asked, like everything else here,
## and nothing about it is worked out on this side: whether a character has been
## beaten is `Piece.is_alive`'s answer and the wording is `ActionEngine`'s.
## Public so that a test can pin the sentence and what is drawn to each other.
func defeat_line() -> String:
	if world == null or driven_id == 0:
		return ""
	return FightSource.defeat_of(world, driven_id)


## What the world says about the character being driven having walked out of a
## fight, and "" when leaving is not the last thing that happened to them.
##
## The same shape as `defeat_line` above and read the same way: the sentence is
## `ActionEngine.left_the_fight` and how long it stands is
## `ActionScene.departure_of`. It is on this panel because there was nowhere else
## on the screen that said a person had left a fight -- the readout simply
## stopped being about them, and this row went on drawing whatever the world had
## last refused them while they were still on the board.
func departure_line() -> String:
	if world == null or driven_id == 0:
		return ""
	return FightSource.departure_of(world, driven_id)


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
