extends PanelContainer
## The combat readout, drawn in the Sprout Lands pack: whose turn it is, the
## order the commanders act in, and what the one acting can swing.
##
## The second panel of the interface, and it is deliberately the same interface.
## The frame, the buttons, the slots and the type are the ones
## `render/ui/sprout_theme.gd` already built for the character sheet; this file
## re-decides none of that, and the theme is handed down from the layer both
## panels sit on rather than built twice.
##
## ## It is a view, and it holds nothing
##
## The panel keeps a reference to the world the simulation is stepping and reads
## the fight off it on every frame, through `render/ui/fight_source.gd`. There is
## no cached turn order here, no copy of a cooldown, no note of who acted last
## and no signal to keep in step: a blow struck on a tick is on the panel on the
## next frame because the panel is looking at the fight the blow was struck in.
##
## The one thing it owns is a clock, which is a fact about the picture and not
## about the world -- an animation has to be somewhere in its play, and how far
## through it is is not something the simulation has an opinion about. It is the
## same clock the drifting sky and the wandering orbs run on.
##
## ## What is on it
##
##   * **the round**, beside the pack's star;
##   * **the turn order**, one row per commander in the order they act, the one
##     acting now marked with the pack's exclamation and the rest with its plain
##     bar, each with a heart and how much health is behind it;
##   * **the weapon actions** of the commander whose turn it is: each one's own
##     effect sprite, its name, and either the pack's tick for "available now" or
##     its prohibition sign and a number for how many turns of cooldown are left;
##   * **the last blow**, as the sprite of the action that struck it, playing the
##     animation that action names.
##
## The last two are where `render/effect_art.gd` is used: the six effect sprites
## and the seven animations the simulation names are looked up there by tag, so a
## resolved weapon action is something you can watch rather than only read.
##
## ## Sizes
##
## Every number below is in pixels of the art, before the whole interface is
## scaled up by a whole number (render/ui/pixel_ui.gd). Sixteen is the art's cell
## and fourteen the font's, and every size here is a multiple of one of them.
class_name CombatPanel

## How wide the readout is, in art pixels. Fixed rather than fitted, so a
## commander with a long name does not resize the interface under the reader.
const WIDTH := 208

## How many commanders the turn order draws before it stops. The count beside
## the heading is the truth either way; a fight of more than this many is a
## thing the design allows and the panel would otherwise grow without limit.
const ORDER_ROWS := 6

## How many weapon actions the action list draws. No item in the catalogue
## carries more than two, and a randomised one is not expected to carry four.
const ACTION_ROWS := 4

## The box the last blow is played inside, in art pixels: three cells across so
## a sprite that travels has somewhere to travel to, one cell tall.
const BLOW_WIDTH := 48
const BLOW_HEIGHT := 16

## Where the sprite sits inside that box before its animation moves it: hard
## left, so a play that travels to the right has the whole box to cross.
const BLOW_REST := Vector2.ZERO

## The gaps, in art pixels: eighths of the art's own cell, as on the sheet.
const GAP := 2
const ROW_GAP := 4
const SECTION_GAP := 8

## What an absent name or an empty fight reads as. The sheet's own convention.
const NOTHING := "-"

## The world whose fight is being read. A handle, never written to, and the only
## thing this panel is given.
var world: SimWorld = null

# The labels and rows, which are the drawn picture and not a copy of anything:
# every one of them is overwritten from the simulation on every frame.
var _round_label: Label
var _acting_label: Label
var _order_head: Label
var _order_rows: VBoxContainer
var _action_head: Label
var _action_rows: VBoxContainer
var _blow_head: Label
var _blow_stage: Control
var _blow_sprite: TextureRect
var _blow_label: Label

## How long this panel has been on screen, in seconds. A clock, and the whole of
## what this file remembers: an animation has to be somewhere in its play and the
## simulation has no opinion about where. Free-running, so the play loops for as
## long as the blow is on the record and nothing has to be reset.
var _played := 0.0

## The three heart faces and the four pack icons, cut once rather than per row
## per frame.
var _faces := {}


## The tree is built here rather than in `_ready` so that the panel is a whole
## panel the moment it exists, with no half-built state and no dependence on
## being in a scene: tests/test_ui_readout.gd builds one, hands it a world and
## reads what it says, without a window anywhere.
func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_faces = {
		"heart": SproutPack.region(SproutPack.HEARTS, SproutPack.HEART_FULL),
		"star": SproutPack.icon(SproutPack.ICON_STAR),
		"mark": SproutPack.icon(SproutPack.ICON_MARK),
		"dash": SproutPack.icon(SproutPack.ICON_DASH),
		"tick": SproutPack.icon(SproutPack.ICON_TICK),
		"bar": SproutPack.icon(SproutPack.ICON_BAR),
	}

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	column.add_child(_build_header())
	column.add_child(_spacer(SECTION_GAP - ROW_GAP))
	_order_head = _heading("turn order")
	column.add_child(_order_head)
	_order_rows = _stack()
	column.add_child(_order_rows)
	column.add_child(_spacer(SECTION_GAP - ROW_GAP))
	_action_head = _heading("actions")
	column.add_child(_action_head)
	_action_rows = _stack()
	column.add_child(_action_rows)
	column.add_child(_spacer(SECTION_GAP - ROW_GAP))
	_blow_head = _heading("last blow")
	column.add_child(_blow_head)
	column.add_child(_build_blow())
	refresh()


func _process(delta: float) -> void:
	_played += delta
	refresh()


## Watch a world. The handle, not its contents: the panel reads the fight off it
## again on every frame, so there is nothing here to keep in step.
func watch(watching: SimWorld) -> void:
	world = watching


## Whether there is a fight to draw at all.
func has_fight() -> bool:
	return FightSource.state_in(world) != null


## Read the whole panel off the fight again. Called every frame: there is
## nothing cached here to invalidate, so there is nothing to decide.
func refresh() -> void:
	var on := FightSource.fight_in(world)
	var state := FightSource.state_in(world)
	visible = state != null
	if state == null:
		return

	var turn := FightSource.round_of(state)
	var order := FightSource.order_of(state)
	var acting := FightSource.active_of(state)
	_round_label.text = "round %d" % turn
	_acting_label.text = FightSource.name_in(on, acting)

	_refresh_order(on, order, acting)
	_refresh_actions(FightSource.standing_in(on, acting), turn)
	_refresh_blow()


# --- Reading the fight ----------------------------------------------------


func _refresh_order(on: Object, order: PackedInt32Array, acting: int) -> void:
	_order_head.text = "turn order %d" % order.size()
	var wanted := mini(order.size(), ORDER_ROWS)
	if _order_rows.get_child_count() != wanted:
		_fill(_order_rows, wanted, _order_row)
	for index in wanted:
		var id := order[index]
		var row := _order_rows.get_child(index)
		(row.get_child(0) as TextureRect).texture = \
			_faces["mark"] if id == acting else _faces["dash"]
		var called := row.get_child(1) as Label
		called.text = FightSource.name_in(on, id)
		called.theme_type_variation = \
			StringName("") if id == acting else StringName(SproutTheme.DIM_LABEL)
		var hurt := FightSource.health_in(on, id)
		(row.get_child(3) as Label).text = "%d/%d" % [hurt.x, hurt.y]


func _refresh_actions(standing: Object, turn: int) -> void:
	var rows := FightSource.actions_in(standing, turn)
	_action_head.text = "actions %d" % rows.size()
	var wanted := mini(rows.size(), ACTION_ROWS)
	if _action_rows.get_child_count() != wanted:
		_fill(_action_rows, wanted, _action_row)
	for index in wanted:
		var one: Dictionary = rows[index]
		var row := _action_rows.get_child(index)
		(row.get_child(0) as TextureRect).texture = \
			EffectArt.sprite_of(String(one["sprite"]))
		(row.get_child(1) as Label).text = String(one["name"])
		var ready_now := bool(one["ready"])
		(row.get_child(2) as TextureRect).texture = \
			_faces["tick"] if ready_now else _faces["bar"]
		var state := row.get_child(3) as Label
		state.text = "ready" if ready_now else "%d" % int(one["remaining"])
		state.theme_type_variation = \
			StringName("") if ready_now else StringName(SproutTheme.DIM_LABEL)


## The last blow, and the animation the action that struck it names.
##
## The sprite's pose comes out of `EffectArt.pose_of` for that animation tag, at
## the phase the panel's own clock is at. Nothing about the pose is decided here:
## the seven animations differ from each other in the table and nowhere else.
func _refresh_blow() -> void:
	var blow := FightSource.last_blow(world)
	var showing := not blow.is_empty()
	_blow_head.visible = showing
	_blow_stage.visible = showing
	_blow_label.visible = showing
	if not showing:
		return
	var animation := String(blow["animation"])
	_blow_sprite.texture = EffectArt.sprite_of(String(blow["sprite"]))
	_blow_label.text = "%s  %s" % [String(blow["name"]), String(blow["by"])]

	var seconds := EffectArt.seconds_of(animation)
	var phase := 0.0 if seconds <= 0.0 else fmod(_played, seconds) / seconds
	var pose := EffectArt.pose_of(animation, phase)
	# Whole art pixels and whole quarter turns, both decided by the table. A
	# sprite put at a fraction of a pixel, or turned by anything but a right
	# angle, is a blurred edge on the one panel that may not have one.
	var offset: Vector2i = pose["offset"]
	_blow_sprite.position = BLOW_REST + Vector2(offset)
	_blow_sprite.rotation = EffectArt.radians_of(int(pose["quarter_turns"]))


# --- Building the tree ----------------------------------------------------


func _build_header() -> Control:
	var row := _row()
	row.add_child(_sprite(_faces["star"]))
	_round_label = Label.new()
	_round_label.theme_type_variation = SproutTheme.HEADING_LABEL
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_round_label)
	row.add_child(_spacer(SECTION_GAP, true))
	row.add_child(_sprite(_faces["mark"]))
	_acting_label = Label.new()
	_acting_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_acting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_acting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_acting_label)
	return row


## One row of the turn order: the marker, the name, a heart and the health.
func _order_row() -> Control:
	var row := _row()
	row.custom_minimum_size = Vector2(WIDTH - 32, SproutPack.CELL)
	row.add_child(_sprite(null))
	var called := Label.new()
	called.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	called.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	called.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(called)
	row.add_child(_sprite(_faces["heart"]))
	var hurt := Label.new()
	hurt.theme_type_variation = SproutTheme.DIM_LABEL
	hurt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hurt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hurt.custom_minimum_size = Vector2(SproutPack.CELL * 4, SproutPack.FONT_CELL)
	row.add_child(hurt)
	return row


## One weapon action: its own effect sprite, its name, and whether it may be
## used now or how many turns are left of its wait.
func _action_row() -> Control:
	var row := _row()
	row.custom_minimum_size = Vector2(WIDTH - 32, SproutPack.CELL)
	row.add_child(_sprite(null))
	var called := Label.new()
	called.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	called.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	called.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(called)
	row.add_child(_sprite(null))
	var state := Label.new()
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.custom_minimum_size = Vector2(SproutPack.CELL * 3, SproutPack.FONT_CELL)
	row.add_child(state)
	return row


## The stage the last blow is played on: a fixed box with one sprite moving
## inside it, so a play that travels does not push the rest of the panel about.
func _build_blow() -> Control:
	var row := _row()
	_blow_stage = Control.new()
	_blow_stage.custom_minimum_size = Vector2(BLOW_WIDTH, BLOW_HEIGHT)
	_blow_stage.clip_contents = true
	_blow_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blow_sprite = TextureRect.new()
	_blow_sprite.size = Vector2(SproutPack.CELL, SproutPack.CELL)
	_blow_sprite.pivot_offset = Vector2(SproutPack.CELL, SproutPack.CELL) * 0.5
	_blow_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_blow_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blow_stage.add_child(_blow_sprite)
	row.add_child(_blow_stage)
	_blow_label = Label.new()
	_blow_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_blow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_blow_label)
	return row


## One 16x16 sprite, drawn at exactly its own size. Never stretched: a pixel of
## the art is a pixel of the interface, and the interface is what gets scaled.
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


func _stack() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	return column


func _spacer(by: int, across: bool = false) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(by if across else 0, 0 if across else by)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## Make a stack hold exactly this many rows, adding or removing at the end. The
## shape of a row is rebuilt only when the number of them changes; what is
## written into it is read afresh every frame either way.
static func _fill(into: Control, wanted: int, make: Callable) -> void:
	while into.get_child_count() > wanted:
		var last := into.get_child(into.get_child_count() - 1)
		into.remove_child(last)
		last.queue_free()
	while into.get_child_count() < wanted:
		into.add_child(make.call())
