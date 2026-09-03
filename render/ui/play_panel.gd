extends PanelContainer
## What the person driving has picked, what has been offered them, and what they
## have heard.
##
## The fourth panel of the interface, in the same Sprout Lands pack and the same
## theme as the character sheet, the combat readout and the answer panel. It
## exists because nine of the twelve atomic actions are aimed at something, and a
## person cannot aim at what they cannot see: without this, choosing a target is
## pressing a key and hoping. Four rows, and each is one question a person has to
## be able to answer before they can act:
##
##   * **aim** -- what you have aimed at, what sort of thing it is, how far off,
##     and what can be seen inside it.
##   * **hand** -- what you are holding, which of the things inside what you have
##     aimed at you are taking, the coins on the dial and the line you would say.
##   * **offers** -- every trade standing between you and anybody, with both
##     halves written out: the items and the coins each way. A person cannot be
##     asked to accept what they cannot read.
##   * **heard** -- the last few lines said within earshot, each with who said it
##     and whether it was aimed at you or shouted at everybody.
##
## ## It quotes and it holds nothing
##
## Every fact on it comes off `SimWorld.surroundings_of()`, which is `Observation`
## -- the
## same packet a language-model mind is handed -- turned into plain rows. What
## can be aimed at, what can be heard and what can be seen inside a chest are all
## decided there; this panel has no opinion about any of them and no copy of any
## of them. It keeps a handle on the world and on the controls, reads both again
## on every frame, and rebuilding it from the same world says the same thing.
##
## The one thing on it that is not the simulation's is the line of speech the
## person has picked, which is `PlayerControls`' -- an interface with no text
## field in it yet offers a few things to say. See that file.
class_name PlayPanel

## How wide the panel is, in art pixels. As wide as the answer panel, because
## an offer written out in full is a sentence and a trimmed offer is one a person
## cannot judge.
const WIDTH := 296

## How many offers and how many lines of speech are drawn. Both are the newest,
## because an offer that has been answered is gone and a line that has been
## answered is old news. Two each: the panel stands above the answer panel in
## the same column, and a panel tall enough to push that one off the bottom of
## the window has taken the refusal away to make room for the gossip.
const OFFERS := 2
const HEARD := 2

## The gaps, in art pixels: eighths of the art's own cell, as on the other
## panels.
const GAP := 2
const ROW_GAP := 2

## What the two picking rows read when there is nothing to read.
const NOTHING_AIMED := "nothing aimed"

## Everything the simulation hands over keeps the project's own spelling -- a
## trace, a report and a journal line all say `#3` -- and what reaches the screen
## goes through `SproutPack.drawable()`, which spells the same thing in letters
## the art's font actually has. See that file.

## The world being read, the controls being driven, and which character. All
## three are handles, never written to.
var world: SimWorld = null
var controls: PlayerControls = null
var driven_id := 0

var _aim: Label
var _hand: Label
var _offers: Array[Label] = []
var _heard: Array[Label] = []
var _faces := {}


## Built here rather than in `_ready`, for the reason the other panels are: the
## panel is a whole panel the moment it exists, so a test can build one, hand it
## a world and read what it says with no window anywhere.
func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_STOP
	_faces = {
		"mark": SproutPack.icon(SproutPack.ICON_MARK),
		"coin": SproutPack.icon(SproutPack.ICON_COIN),
		"star": SproutPack.icon(SproutPack.ICON_STAR),
		"dash": SproutPack.icon(SproutPack.ICON_DASH),
	}

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	_aim = _sentence()
	column.add_child(_labelled(_faces["mark"], _aim))
	_hand = _sentence()
	column.add_child(_labelled(_faces["star"], _hand))
	for _each in OFFERS:
		var offer := _sentence()
		_offers.append(offer)
		column.add_child(_labelled(_faces["coin"], offer))
	for _each in HEARD:
		var said := _sentence()
		_heard.append(said)
		column.add_child(_labelled(_faces["dash"], said))
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Watch a world, the character being driven in it, and the controls driving it.
## The handles, not their contents: everything is read again every frame.
func watch(watching: SimWorld, id: int, driving: PlayerControls) -> void:
	world = watching
	driven_id = id
	controls = driving


## Read the panel off the world again.
func refresh() -> void:
	visible = world != null and controls != null and driven_id != 0
	if not visible:
		return
	var view := world.surroundings_of(driven_id)
	_aim.text = SproutPack.drawable(_aim_text(view))
	_hand.text = SproutPack.drawable(controls.holding_line())
	var offers := view.offers
	for index in _offers.size():
		var at := offers.size() - _offers.size() + index
		var row: Label = _offers[index]
		row.text = "" if at < 0 else SproutPack.drawable(offer_line(offers[at]))
		_show(row, row.text != "")
	var heard := view.heard
	for index in _heard.size():
		var at := heard.size() - _heard.size() + index
		var row: Label = _heard[index]
		row.text = "" if at < 0 else SproutPack.drawable(heard_line(heard[at]))
		_show(row, row.text != "")


## One offer, with both halves written out: who offered it, what goes across and
## what comes back, items and coins each way.
##
## The two halves are the proposer's, whichever side the reader is on, because
## that is how the offer was made and how the engine will honour it. Written out
## rather than summed: a person deciding whether to accept has to see the items
## and the coins separately.
static func offer_line(offer: Dictionary) -> String:
	return "%s -> %s: gives %s, wants %s" % [
		String(offer["from"]), String(offer["to"]),
		_half(PackedStringArray(offer["give"]), int(offer["give_money"])),
		_half(PackedStringArray(offer["want"]), int(offer["want_money"])),
	]


## One line of speech: who said it, whether it was aimed at you or shouted, and
## the words themselves.
static func heard_line(said: Dictionary) -> String:
	var aimed := "shouts" if bool(said["shout"]) else (
		"to you" if bool(said["to_you"]) else "to %s" % String(said["to"]))
	return "%s %s: \"%s\"" % [String(said["speaker"]), aimed, String(said["text"])]


# One half of an offer: what is in it, and what it is worth in coin. "nothing"
# for an empty half, which is section 2.1's gift -- a trade with nothing in
# return -- and has to read as a half rather than as a blank.
static func _half(items: PackedStringArray, money: int) -> String:
	var written := PackedStringArray()
	if not items.is_empty():
		written.append(", ".join(items))
	if money > 0:
		written.append("%d coin" % money)
	return "nothing" if written.is_empty() else " + ".join(written)


# What is aimed at, and what can be seen inside it.
func _aim_text(view: Surroundings) -> String:
	var line := controls.aim_line(view)
	var inside := PlayerControls.inside_of(view, controls.aimed_id)
	if inside.is_empty():
		return line
	return "%s holding %s" % [line, ", ".join(inside)]


func _show(row: Label, showing: bool) -> void:
	row.visible = showing
	var holder := row.get_parent() as Control
	if holder != null:
		holder.visible = showing


## One sentence, wrapped rather than trimmed: as on the answer panel, a line that
## ends in an ellipsis is a line a person cannot act on.
func _sentence() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(WIDTH - SproutPack.CELL - GAP, 0)
	return label


# One row: a 16x16 sprite at exactly its own size and the sentence beside it, as
# on the answer panel -- a pixel of the art is a pixel of the interface, and the
# interface is what is scaled.
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
