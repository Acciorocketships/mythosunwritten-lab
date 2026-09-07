extends PanelContainer
## The trade panel: both sides of every proposal standing, and what came of the
## last trade verb, in the engine's own words.
##
## The sixth panel of the interface, in the same Sprout Lands pack and the same
## theme as the rest. A trade is the one action whose whole meaning is a
## question waiting for an answer, and a person cannot be asked to accept what
## they cannot read -- so each standing offer is written out in full, three
## lines each: who is asking whom, what would go across, and what would come
## back, items and money separately on both halves. What the offer may be
## answered *with* is the same three keys the run prints -- offer, accept, deny
## -- and this panel adds no fourth.
##
## ## It quotes; it does not phrase
##
## The offers come off `SimWorld.surroundings_of()`, which is `Observation` --
## the same packet a language-model mind is handed, where "a trade you are
## party to is observable" is decided -- turned into plain rows. The halves are
## spelled by `PlayPanel.half_line`, the one spelling of a half. And the answer
## row is `ActionOutcome.line()` carried out of `ControlLoop.answer_of`
## unchanged whenever the last thing answered was a trade verb: an acceptance
## with what moved, or a refusal in the engine's own words -- "the offer from
## Hob was denied" reaches this panel exactly as the engine wrote it.
##
## ## It is a view, and it holds nothing
##
## A handle on the world and the id of the character whose trades these are,
## both read again on every frame. No copy of an offer, no note of the last
## answer, no signal: throw the panel away, rebuild it from the same world and
## it says the same thing.
##
## ## Sizes
##
## In pixels of the art, before the whole interface is scaled up by a whole
## number (render/ui/pixel_ui.gd), as on the other panels.
class_name TradePanel

## How wide the panel is, in art pixels: seventeen of the art's cells, the
## dialogue panel's width and a shade narrower than the answer panel, so the
## two bottom columns fit side by side; see render/ui/dialogue_panel.gd. An
## offer's halves wrap rather than trim.
const WIDTH := 272

## How many standing offers are drawn, newest last. The heading's count is the
## truth either way; two is every offer the runs so far have had standing at
## once -- one each way between two characters.
const OFFERS := 2

## The gaps, in art pixels: eighths of the art's own cell, as on the other
## panels.
const GAP := 2
const ROW_GAP := 2

## What the panel reads while no trade is standing and nothing has been
## answered.
const RESTING := "no trade standing"

## The world being read, and whose trades these are. Handles, never written to.
var world: SimWorld = null
var trader_id := 0

var _head: Label
var _offers: Array[Dictionary] = []
var _resting: Label
var _answer_icon: TextureRect
var _answer_label: Label
var _faces := {}


## Built here rather than in `_ready`, for the reason the other panels are: a
## test builds one, hands it a world and reads what it says with no window
## anywhere.
func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_STOP
	_faces = {
		"coin": SproutPack.icon(SproutPack.ICON_COIN),
		"tick": SproutPack.icon(SproutPack.ICON_TICK),
		"bar": SproutPack.icon(SproutPack.ICON_BAR),
	}

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	_head = Label.new()
	_head.theme_type_variation = SproutTheme.HEADING_LABEL
	_head.text = "trades"
	column.add_child(_head)
	_resting = _sentence()
	_resting.theme_type_variation = SproutTheme.DIM_LABEL
	_resting.text = RESTING
	column.add_child(_labelled(_faces["coin"], _resting))
	for _each in OFFERS:
		var between := _sentence()
		var gives := _sentence()
		var wants := _sentence()
		gives.theme_type_variation = SproutTheme.DIM_LABEL
		wants.theme_type_variation = SproutTheme.DIM_LABEL
		_offers.append({"between": between, "gives": gives, "wants": wants})
		column.add_child(_labelled(_faces["coin"], between))
		column.add_child(_indented(gives))
		column.add_child(_indented(wants))
	var answer_row := HBoxContainer.new()
	answer_row.add_theme_constant_override("separation", GAP)
	_answer_icon = TextureRect.new()
	_answer_icon.texture = _faces["tick"]
	_answer_icon.custom_minimum_size = Vector2(SproutPack.CELL, SproutPack.CELL)
	_answer_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_answer_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	answer_row.add_child(_answer_icon)
	_answer_label = _sentence()
	answer_row.add_child(_answer_label)
	column.add_child(answer_row)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Watch a world and the character whose trades are being read. The handles,
## not their contents: everything is read again every frame.
func watch(watching: SimWorld, id: int) -> void:
	world = watching
	trader_id = id


## Read the panel off the world again.
func refresh() -> void:
	visible = world != null and trader_id != 0
	if not visible:
		return
	var offers := world.surroundings_of(trader_id).offers
	_head.text = "trades %d" % offers.size()
	_show(_resting, offers.is_empty())
	for index in _offers.size():
		var at := offers.size() - _offers.size() + index
		var rows: Dictionary = _offers[index]
		var showing := at >= 0
		for key in ["between", "gives", "wants"]:
			_show(rows[key], showing)
		if not showing:
			continue
		var offer: Dictionary = offers[at]
		(rows["between"] as Label).text = SproutPack.drawable(
			"%s -> %s" % [String(offer["from"]), String(offer["to"])])
		(rows["gives"] as Label).text = SproutPack.drawable("gives %s" % (
			PlayPanel.half_line(
				PackedStringArray(offer["give"]), int(offer["give_money"]))))
		(rows["wants"] as Label).text = SproutPack.drawable("wants %s" % (
			PlayPanel.half_line(
				PackedStringArray(offer["want"]), int(offer["want_money"]))))
	_refresh_answer()


# The engine's answer to the last trade verb the character chose, quoted whole,
# or nothing while the last answer was about something else.
func _refresh_answer() -> void:
	var answer := {}
	if world != null and world.loop != null:
		answer = world.loop.answer_of(trader_id)
	var about_a_trade := not answer.is_empty() \
		and String(answer.get("action", "")).begins_with("trade_")
	_answer_icon.visible = about_a_trade
	_answer_label.visible = about_a_trade
	if not about_a_trade:
		return
	var refused := not bool(answer.get("ok", true))
	_answer_label.text = SproutPack.drawable(String(answer.get("line", "")))
	_answer_icon.texture = _faces["bar"] if refused else _faces["tick"]
	# A refusal is the sentence a person most needs to read, so it is the one
	# that is not dimmed -- as on the answer panel.
	_answer_label.theme_type_variation = StringName(
		"") if refused else StringName(SproutTheme.DIM_LABEL)


## One sentence, wrapped rather than trimmed, as on the other panels.
func _sentence() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(WIDTH - SproutPack.CELL - GAP, 0)
	return label


func _show(row: Label, showing: bool) -> void:
	row.visible = showing
	var holder := row.get_parent() as Control
	if holder != null:
		holder.visible = showing


# One row: a 16x16 sprite at exactly its own size and the sentence beside it.
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


# One of an offer's two halves, set in from the heading by the width of the
# icon above it, so the three lines of an offer read as one thing.
func _indented(label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(SproutPack.CELL, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	label.custom_minimum_size = Vector2(WIDTH - SproutPack.CELL * 2 - GAP, 0)
	row.add_child(label)
	return row
