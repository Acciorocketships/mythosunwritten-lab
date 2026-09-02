extends PanelContainer
## One character sheet, drawn in the Sprout Lands pack: the six ability scores,
## the level, the status, the health, what is carried and what is worn.
##
## ## It is a view, and it holds nothing
##
## The panel keeps a reference to the `Character` the simulation is holding and
## reads every number off it on every frame. There is no cached level here, no
## copy of the scores, no snapshot of the inventory and no signal to keep in
## step: a blow landed on a tick is on the panel on the next frame because the
## panel is looking at the same object the blow was struck against. The only
## state this file owns is which of the characters in the world is being looked
## at, which is a fact about the interface and about nothing else.
##
## That is also why nothing here writes. The layer rule lets the render side read
## the simulation and forbids it holding a piece of the fight; a view that reads
## every frame and stores nothing is the strongest form of that, because there is
## no second copy for the two sides to disagree about.
##
## ## Where each thing on it comes from
##
## Every rectangle drawn is either the pack's or this project's own art, and
## reports/ui.md lists them one by one. In short: the frame, the slots, the
## buttons, the hearts and the font are the pack's; the star, the crown, the coin
## and the tick are off the pack's generic icon sheet; and the eleven icons the
## pack has no equivalent for -- one per ability score, one per equipment slot --
## are drawn in render/ui/pixel_icons.gd on the same sixteen-pixel cell in the
## pack's own three colours.
##
## ## Sizes
##
## Every number below is in pixels of the art, before the whole interface is
## scaled up by a whole number (render/ui/pixel_ui.gd). Sixteen is the art's cell
## and fourteen the font's, and every size here is a multiple of one of them or a
## sum of such multiples.
class_name CharacterPanel

## How wide the panel is, in art pixels. Fixed rather than fitted, so that paging
## from a character with a long name to one with a short one does not resize the
## interface under the reader.
const WIDTH := 260

## The health bar is always ten hearts, so a character of any level has a row of
## hearts that fits. Each heart is a tenth of that character's own maximum, drawn
## full, half or empty; the exact numbers are beside it.
const HEARTS := 10

## How many slots the carried row shows before it stops drawing them. The count
## beside the heading is the truth either way.
const CARRIED_SLOTS := 8

## The gap between things, in art pixels. Two, four and eight: eighths of the
## art's own cell.
const GAP := 2
const ROW_GAP := 4
const SECTION_GAP := 8

## The three-letter labels for the six scores, by the simulation's own names.
const ABILITY_LABELS := {
	Ability.STR: "STR", Ability.CON: "CON", Ability.CHA: "CHA",
	Ability.DEX: "DEX", Ability.WIS: "WIS", Ability.INT: "INT",
}

## What an unrecorded score, an unnamed character or an empty slot reads as. The
## sheet's own convention: a dash is not a zero.
const NOTHING := "-"

## The characters this panel can show, in the simulation's own order. These are
## the simulation's objects, held by reference and never written to.
var sheets: Array[Character] = []

## Which of them is on screen. The interface's own state and the only state here.
var showing := 0

var _name: Label
var _paging: Label
var _level: Label
var _status: Label
var _money: Label
var _health: Label
var _hearts: Array[TextureRect] = []
var _scores: Dictionary = {}
var _equipment: Dictionary = {}
## The three heart faces, cut once. Cutting them per heart per frame would build
## thirty throwaway objects a frame for a picture that is usually unchanged.
var _heart_faces := {}

var _carried_row: HBoxContainer
var _carried_count: Label
var _carried_names: VBoxContainer


## The tree is built here rather than in `_ready` so that the panel is a whole
## panel the moment it exists, with no half-built state and no dependence on
## being in a scene: tests/test_ui_panel.gd builds one, hands it a character and
## reads what it says, without a window anywhere.
func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_standing())
	column.add_child(_build_health())
	column.add_child(_spacer(SECTION_GAP - ROW_GAP))
	column.add_child(_build_scores())
	column.add_child(_spacer(SECTION_GAP - ROW_GAP))
	column.add_child(_heading("equipped"))
	column.add_child(_build_equipment())
	column.add_child(_spacer(SECTION_GAP - ROW_GAP))
	_carried_count = _heading("carried")
	column.add_child(_carried_count)
	_carried_row = _row()
	column.add_child(_carried_row)
	_carried_names = VBoxContainer.new()
	_carried_names.add_theme_constant_override("separation", GAP)
	column.add_child(_carried_names)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Show these characters, starting at the first. The array is kept as it is
## handed over: these are the simulation's own objects.
func show_sheets(found: Array[Character]) -> void:
	sheets = found
	showing = 0 if found.is_empty() else clampi(showing, 0, found.size() - 1)


## The character on screen, or null when the world holds none.
func current() -> Character:
	if showing < 0 or showing >= sheets.size():
		return null
	return sheets[showing]


## Page to the next character, wrapping. The interface's own state moving; the
## simulation is not touched and does not know.
func page(by: int) -> void:
	if sheets.is_empty():
		return
	showing = posmod(showing + by, sheets.size())


## Read the whole panel off the character again. Called every frame: there is
## nothing cached here to invalidate, so there is nothing to decide.
func refresh() -> void:
	var sheet := current()
	visible = sheet != null
	if sheet == null:
		return

	_name.text = NOTHING if sheet.character_name == "" else sheet.character_name
	_paging.text = "%d/%d" % [showing + 1, sheets.size()]
	_level.text = "lv %d" % sheet.level
	_status.text = "st %d" % sheet.status()
	_money.text = str(sheet.inventory.money)

	_refresh_health(sheet)
	for ability in Ability.ALL:
		var value: Label = _scores[ability]
		value.text = NOTHING if not sheet.has_score(ability) else str(sheet.score(ability))
	_refresh_equipment(sheet)
	_refresh_carried(sheet)


# --- Reading the character ------------------------------------------------


func _refresh_health(sheet: Character) -> void:
	var most := maxi(1, sheet.max_health())
	_health.text = "%d/%d" % [sheet.health, most]
	# In half hearts, so a heart can be half full. Ten hearts is twenty halves,
	# whatever the character's maximum happens to be.
	var halves := int(round(float(clampi(sheet.health, 0, most)) * HEARTS * 2.0 / most))
	for index in _hearts.size():
		var left := halves - index * 2
		var which := "empty"
		if left >= 2:
			which = "full"
		elif left == 1:
			which = "half"
		_hearts[index].texture = _heart_faces.get(which, null)


func _refresh_equipment(sheet: Character) -> void:
	var worn: Dictionary = sheet.equipment
	for slot in Inventory.SLOT_ORDER:
		var plate: PanelContainer = _equipment[slot]
		var filled := worn.has(slot)
		plate.theme_type_variation = \
			SproutTheme.SLOT_FULL if filled else SproutTheme.SLOT_EMPTY
		plate.tooltip_text = slot if not filled else _name_of(worn[slot])


func _refresh_carried(sheet: Character) -> void:
	var carried: Array = sheet.inventory.carried
	_carried_count.text = "carried %d" % carried.size()
	# The row is rebuilt only when the number of things in it changes, which is
	# the one thing about it a frame cannot just overwrite. What is *in* each
	# slot is read afresh below either way.
	var wanted := mini(carried.size(), CARRIED_SLOTS)
	if _carried_row.get_child_count() != wanted:
		_rebuild_children(_carried_row, wanted, func() -> Control: return _slot(null))
	if _carried_names.get_child_count() != carried.size():
		_rebuild_children(_carried_names, carried.size(), _carried_line)

	for index in wanted:
		var plate: PanelContainer = _carried_row.get_child(index)
		var entry: Variant = carried[index]
		var icon: TextureRect = plate.get_child(0).get_child(0)
		icon.texture = _icon_for(entry)
		plate.theme_type_variation = SproutTheme.SLOT_FULL
		plate.tooltip_text = _name_of(entry)
	for index in carried.size():
		_write_carried_line(_carried_names.get_child(index), sheet, carried[index])


## One carried thing on one line: what it is called, what tier it is, what level
## it is, and the pack's own tick when it is being worn or held.
##
## Every one of those four is read off the simulation's object at the moment the
## line is written; none of them is stored here.
static func _write_carried_line(row: Control, sheet: Character, entry: Variant) -> void:
	var behind := Inventory.item_of(entry)
	(row.get_child(0) as Label).text = _name_of(entry)
	(row.get_child(1) as Label).text = "" if behind == null else behind.rarity
	(row.get_child(2) as Label).text = "" if behind == null else "l%d" % behind.level
	row.get_child(3).visible = sheet.inventory.is_equipped(entry)


## The shape of one such line. Rebuilt only when the number of things carried
## changes; the text in it is written afresh every frame.
func _carried_line() -> Control:
	var row := _row()
	row.custom_minimum_size = Vector2(WIDTH - 32, SproutPack.FONT_CELL)
	var called := Label.new()
	called.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	called.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	called.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(called)
	for width in [SproutPack.CELL * 3, SproutPack.CELL]:
		var note := Label.new()
		note.theme_type_variation = SproutTheme.DIM_LABEL
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.custom_minimum_size = Vector2(width, SproutPack.FONT_CELL)
		row.add_child(note)
	row.add_child(_sprite(SproutPack.icon(SproutPack.ICON_WORN)))
	return row


## What a carried thing is called. Almost everything carries an item and the item
## carries the name; the one thing that does not is a catalogue shape reading
## itself, which carries its own.
static func _name_of(entry: Variant) -> String:
	var behind := Inventory.item_of(entry)
	if behind != null and behind.item_name != "":
		return behind.item_name
	if entry != null:
		var own: Variant = entry.get("weapon_name")
		if own != null and String(own) != "":
			return String(own)
	return NOTHING


## The icon for a carried thing: the icon of the slot it goes in, or the pack's
## own "no" sign for something that goes in no slot at all.
static func _icon_for(entry: Variant) -> Texture2D:
	var slot := Inventory.slot_of(entry)
	if PixelIcons.has(slot):
		return PixelIcons.of(slot)
	return SproutPack.icon(SproutPack.ICON_NO_SLOT)


# --- Building the tree ----------------------------------------------------


func _build_header() -> Control:
	var row := _row()
	_name = Label.new()
	_name.theme_type_variation = SproutTheme.TITLE
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name)
	_paging = Label.new()
	_paging.theme_type_variation = SproutTheme.DIM_LABEL
	_paging.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_paging)
	row.add_child(_pager("<", -1))
	row.add_child(_pager(">", 1))
	return row


func _pager(glyph: String, by: int) -> Button:
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = Vector2(SproutPack.CELL + 8, SproutPack.CELL + 8)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: page(by))
	return button


func _build_standing() -> Control:
	var row := _row()
	_level = _with_icon(row, SproutPack.icon(SproutPack.ICON_STAR))
	row.add_child(_spacer(SECTION_GAP, true))
	_status = _with_icon(row, SproutPack.icon(SproutPack.ICON_CROWN))
	row.add_child(_spacer(SECTION_GAP, true))
	_money = _with_icon(row, SproutPack.icon(SproutPack.ICON_COIN))
	return row


func _build_health() -> Control:
	var row := _row()
	_hearts.clear()
	_heart_faces = {
		"full": SproutPack.region(SproutPack.HEARTS, SproutPack.HEART_FULL),
		"half": SproutPack.region(SproutPack.HEARTS, SproutPack.HEART_HALF),
		"empty": SproutPack.region(SproutPack.HEARTS, SproutPack.HEART_EMPTY),
	}
	for i in HEARTS:
		var heart := _sprite(_heart_faces["full"])
		_hearts.append(heart)
		row.add_child(heart)
	_health = Label.new()
	_health.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_health)
	return row


func _build_scores() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", ROW_GAP)
	for ability in Ability.ALL:
		var cell := _row()
		cell.add_child(_sprite(PixelIcons.of(ability)))
		var label := Label.new()
		label.theme_type_variation = SproutTheme.HEADING_LABEL
		label.text = ABILITY_LABELS[ability]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(label)
		var value := Label.new()
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.custom_minimum_size = Vector2(SproutPack.CELL, 0)
		cell.add_child(value)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scores[ability] = value
		grid.add_child(cell)
	return grid


func _build_equipment() -> Control:
	var row := _row()
	for slot in Inventory.SLOT_ORDER:
		var plate := _slot(PixelIcons.of(slot))
		_equipment[slot] = plate
		row.add_child(plate)
	return row


## One inventory slot: the pack's plate with one 16-pixel icon centred in it.
func _slot(icon: Texture2D) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.theme_type_variation = SproutTheme.SLOT_EMPTY
	var centre := CenterContainer.new()
	centre.add_child(_sprite(icon))
	plate.add_child(centre)
	return plate


func _with_icon(row: HBoxContainer, icon: Texture2D) -> Label:
	row.add_child(_sprite(icon))
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return label


## One 16x16 sprite, drawn at exactly its own size. Never stretched: a pixel of
## the art is a pixel of the interface, and the interface as a whole is what gets
## scaled up.
func _sprite(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(SproutPack.CELL, SproutPack.CELL)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


func _heading(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = SproutTheme.HEADING_LABEL
	label.text = text
	return label


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	return row


func _spacer(by: int, across: bool = false) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(by if across else 0, 0 if across else by)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## Make a row hold exactly this many children, adding or removing at the end.
static func _rebuild_children(into: Control, wanted: int, make: Callable) -> void:
	while into.get_child_count() > wanted:
		var last := into.get_child(into.get_child_count() - 1)
		into.remove_child(last)
		last.queue_free()
	while into.get_child_count() < wanted:
		into.add_child(make.call())
