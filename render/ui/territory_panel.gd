extends PanelContainer
## The goodwill and territory readout: how the followed character stands with
## the characters it knows of, and who owns the point it is standing on.
##
## The last panel the interface milestone names, and the one that had to wait
## for the ownership field to exist. It is deliberately the same interface as
## the six before it: the frame, the type and the icons are the pack's, the
## theme is handed down from the layer every panel sits on, and this file
## re-decides none of that.
##
## ## It is a view, and it holds nothing
##
## The panel keeps a handle on the world and the id of the character being
## read, and reads everything else again on every frame through
## `render/ui/territory_source.gd`. Who owns the ground is the simulation's own
## rule (`OwnershipField.at`) asked at the moment the frame is drawn -- there
## is no ownership map anywhere for a copy to be pushed from -- and how the
## character stands with another is the relationship graph's own composite,
## read off the edge on the same frame. No cached ownership score, no copy of
## an edge, no signal to keep in step: throw the panel away, rebuild it from
## the same world and it says the same thing.
##
## ## What is on it
##
##   * **the ground**, beside the pack's crown: who owns the point the
##     followed character is standing on -- by name, or "neutral ground" when
##     the neighbourhood favours nobody enough -- with the top claimant's score
##     beside it, dimmed while the ground is neutral;
##   * **the standings**, one row per character the followed character knows
##     of -- known-of is having an edge in the world's relationship graph --
##     each with the pack's heart, the other's name, the followed character's
##     sentiment toward them and, dimmed, theirs back.
##
## Sentiment is the graph's own $[-1, 1]$ composite, written signed so that
## indifference reads +0.00 and a grudge reads negative. A character that
## knows nobody yet says so rather than going blank.
##
## ## Sizes
##
## In pixels of the art, before the whole interface is scaled up by a whole
## number (render/ui/pixel_ui.gd), as on every other panel.
class_name TerritoryPanel

## How wide the panel is, in art pixels: the reading column's own width, so it
## sits flush over the trade and dialogue panels in the same corner.
const WIDTH := 272

## How many standing rows are drawn before the list stops. The count beside
## the heading is the truth either way, as on the other panels.
const STANDING_ROWS := 6

## The gaps, in art pixels: eighths of the art's own cell, as on the others.
const GAP := 2
const ROW_GAP := 2

## What the ground reads as when the rule's verdict is that nobody owns it.
const NEUTRAL := "neutral ground"

## What the standings read while the followed character has met nobody.
const RESTING := "knows nobody yet"

## The world being read and which character this readout is about. Handles,
## never written to.
var world: SimWorld = null
var about := 0

var _ground_owner: Label
var _ground_score: Label
var _standing_head: Label
var _standing_rows: VBoxContainer
var _resting: Label
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
		"crown": SproutPack.icon(SproutPack.ICON_CROWN),
		"heart": SproutPack.region(SproutPack.HEARTS, SproutPack.HEART_FULL),
	}

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	column.add_child(_heading("ground"))
	column.add_child(_build_ground())
	_standing_head = _heading("standing")
	column.add_child(_standing_head)
	_standing_rows = VBoxContainer.new()
	_standing_rows.add_theme_constant_override("separation", GAP)
	column.add_child(_standing_rows)
	_resting = Label.new()
	_resting.theme_type_variation = SproutTheme.DIM_LABEL
	_resting.text = RESTING
	column.add_child(_resting)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Watch a world and the character the readout is about. The handles, not
## their contents: everything is read again every frame.
func watch(watching: SimWorld, id: int) -> void:
	world = watching
	about = id


## Read the whole panel off the world again. Called every frame: there is
## nothing cached here to invalidate, so there is nothing to decide.
func refresh() -> void:
	visible = world != null and about != 0 \
		and TerritorySource.standing_in(world, about) != null
	if not visible:
		return
	_refresh_ground()
	_refresh_standings()


# --- Reading the world ------------------------------------------------------


## Who owns the ground under the followed character, asked of the simulation's
## own rule on this frame. The claim is drawn and dropped.
func _refresh_ground() -> void:
	var claim := TerritorySource.claim_under(world, about)
	if claim == null:
		_ground_owner.text = NEUTRAL
		_ground_score.text = ""
		return
	if claim.is_neutral():
		_ground_owner.text = NEUTRAL
		_ground_owner.theme_type_variation = SproutTheme.DIM_LABEL
	else:
		_ground_owner.text = "owned by %s" % TerritorySource.name_of(
			world, claim.owner_id)
		_ground_owner.theme_type_variation = StringName("")
	# The top claimant's score, dimmed while it is not enough to own. Nothing
	# is compared against anything here: whether it was enough is the claim's
	# own verdict, already settled by the rule that made it.
	_ground_score.text = "" if claim.best_id == OwnershipClaim.NOBODY \
		else "%+.2f" % claim.best
	_ground_score.theme_type_variation = StringName(
		SproutTheme.DIM_LABEL) if claim.is_neutral() else StringName("")


func _refresh_standings() -> void:
	var rows := TerritorySource.standings_of(world, about)
	_standing_head.text = "standing %d" % rows.size()
	_resting.visible = rows.is_empty()
	# The list is rebuilt only when the number of rows changes, which is the
	# one thing about it a frame cannot just overwrite. What is *in* each row
	# is read afresh below either way.
	var wanted := mini(rows.size(), STANDING_ROWS)
	if _standing_rows.get_child_count() != wanted:
		_fill(_standing_rows, wanted, _standing_row)
	for index in wanted:
		var one: Dictionary = rows[index]
		var row := _standing_rows.get_child(index)
		(row.get_child(1) as Label).text = String(one["name"])
		(row.get_child(2) as Label).text = "%+.2f" % float(one["yours"])
		(row.get_child(3) as Label).text = "%+.2f" % float(one["theirs"])


# --- Building the tree ------------------------------------------------------


## The ground line: the pack's crown, the owner, and the top score.
func _build_ground() -> Control:
	var row := _row()
	row.add_child(_sprite(_faces["crown"]))
	_ground_owner = Label.new()
	_ground_owner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ground_owner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ground_owner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_ground_owner)
	_ground_score = Label.new()
	_ground_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ground_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ground_score.custom_minimum_size = Vector2(SproutPack.CELL * 3, SproutPack.FONT_CELL)
	row.add_child(_ground_score)
	return row


## One standing row: the pack's heart, the other's name, yours toward them and
## theirs toward you.
func _standing_row() -> Control:
	var row := _row()
	row.custom_minimum_size = Vector2(WIDTH - 32, SproutPack.CELL)
	row.add_child(_sprite(_faces["heart"]))
	var called := Label.new()
	called.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	called.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	called.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(called)
	var yours := Label.new()
	yours.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	yours.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	yours.custom_minimum_size = Vector2(SproutPack.CELL * 3, SproutPack.FONT_CELL)
	row.add_child(yours)
	var theirs := Label.new()
	theirs.theme_type_variation = SproutTheme.DIM_LABEL
	theirs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	theirs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	theirs.custom_minimum_size = Vector2(SproutPack.CELL * 3, SproutPack.FONT_CELL)
	row.add_child(theirs)
	return row


## One 16x16 sprite, drawn at exactly its own size, as on every other panel.
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


## Make a stack hold exactly this many rows, adding or removing at the end.
static func _fill(into: Control, wanted: int, make: Callable) -> void:
	while into.get_child_count() > wanted:
		var last := into.get_child(into.get_child_count() - 1)
		into.remove_child(last)
		last.queue_free()
	while into.get_child_count() < wanted:
		into.add_child(make.call())
