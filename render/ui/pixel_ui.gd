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
## The scale answers to the panels rather than to a number written down here:
## it is the largest whole number by which what the panels need still fits both
## across the window and down it, and never less than one. So the question the
## layer asks is "how much room do these panels want, and how many times does
## that go into this window" -- which is the question a window of any size has
## an answer to, where a design height only has an answer for the sizes it was
## written for. A window too small even for one is drawn at one, because a
## fraction blurs the art and there is nothing below one.
##
## The size the panels need only ever grows within a run. A hidden panel counts
## as much as a showing one -- a panel the world has nothing to say through is
## hidden rather than gone -- and a conversation that has grown longer never
## shrinks back. An interface that changed size every time somebody spoke would
## be worse than one that is a step smaller than it strictly had to be.
##
## ## Seven panels, one theme
##
## The character sheet sits in the top-left corner, the combat readout in the
## top-right, the two a person playing needs -- what they have aimed at and
## what the world answered -- stack along the bottom left, and the ones they
## read -- the standing and the ground, the trades standing and the dialogue
## heard -- stack along the bottom right. They are asked for
## separately, so a run may have any of them, all of them or none. What they
## may not have is seven ideas of what the interface looks like, so the theme is
## built once here and carried by the frame the panels sit in; no panel builds a
## style of its own and none names a file on disk.
##
## Nothing here belongs to the simulation. This layer, the panels under it, the
## theme and the pack are all render-side; a headless run loads not one of them,
## which `./run_headless.sh --assets` says from outside by asking the engine's
## own resource cache.
class_name PixelUi

## How far the panels sit from the corners, in art pixels.
const MARGIN := 8

## The character sheet, or null in a run that did not ask for one.
var panel: CharacterPanel = null

## The combat readout, or null in a run that did not ask for one.
var readout: CombatPanel = null

## What the person driving chose and what the world answered, or null in a run
## with nobody driving.
var answer: AnswerPanel = null

## What the person driving has aimed at, what is on the table and what has been
## said within earshot, or null in a run with nobody driving. It sits above the
## answer panel: what you are about to do, and then what came of the last thing
## you did.
var play: PlayPanel = null

## The whole exchange of words the followed character can hear, or null in a
## run that did not ask for it. Bottom-right, across from the play panel.
var dialogue: DialoguePanel = null

## Both sides of every trade standing for the followed character, and the
## engine's answer to the last trade verb, or null in a run that did not ask
## for it. Above the dialogue panel in the same corner.
var trade: TradePanel = null

## How the followed character stands with the characters it knows of and who
## owns the point it is standing on, or null in a run that did not ask for it.
## Top of the reading stack in the same corner.
var territory: TerritoryPanel = null

## What the interface is being multiplied by. Read by the measuring tool, which
## has to know what a whole number is before it can check for one.
var art_scale := 1

var _frame: MarginContainer = null

## The most room the panels have asked for so far this run, in art pixels. The
## scale is chosen against this rather than against what they happen to want on
## this frame, so that it never rises and falls with what is being said.
var _needed := Vector2.ZERO


## The layer, the theme and whichever panels were asked for, ready to be added to
## the scene -- or null when the pack has not been unpacked, in which case the
## caller says so and the world is drawn without an interface over it.
##
## The defaults are the character sheet alone, which is what `--sheet` has always
## meant and what every existing caller asks for. A run with somebody driving is
## built a sheet whether or not it asked for one, shut until the person opens it:
## a game whose inventory cannot be opened is not one an inventory can be
## operated from.
static func build(
	with_sheet: bool = true, with_readout: bool = false,
	with_answer: bool = false, with_dialogue: bool = false,
	with_trade: bool = false, with_territory: bool = false,
) -> PixelUi:
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

	# One row across the whole window: the sheet packed to the left, the readout
	# to the right, and whatever space is left between them. A run with only one
	# of the two still puts it in its own corner, because the spacer is what
	# holds the gap rather than either panel's position.
	var across := HBoxContainer.new()
	across.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	across.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	across.alignment = BoxContainer.ALIGNMENT_BEGIN
	if with_sheet or with_answer:
		layer.panel = CharacterPanel.new()
		# A run that asked for the sheet gets it open. A run that only asked to
		# play gets it shut, because opening it is one of the things a person
		# playing does -- see `render/main.gd`'s sheet key.
		layer.panel.open = with_sheet
		layer.panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		layer.panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		across.add_child(layer.panel)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	across.add_child(gap)
	if with_readout:
		layer.readout = CombatPanel.new()
		across.add_child(layer.readout)

	# One column down the window: the two top panels in their row, whatever space
	# is left, and the answer panel at the bottom. The row is what holds the two
	# corners apart and the space is what holds the bottom down, so a run with
	# only some of the three still puts each where it belongs.
	var down := VBoxContainer.new()
	down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	down.add_child(across)
	var below := Control.new()
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	below.size_flags_vertical = Control.SIZE_EXPAND_FILL
	down.add_child(below)

	# The bottom of the window is a second row with its own two corners, like
	# the top: the choosing panels stack bottom-left, the reading panels --
	# the trades standing and the words heard -- stack bottom-right, and the
	# space between is what holds the corners apart.
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	var choosing := VBoxContainer.new()
	choosing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choosing.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(choosing)
	var between := Control.new()
	between.mouse_filter = Control.MOUSE_FILTER_IGNORE
	between.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(between)
	var reading := VBoxContainer.new()
	reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reading.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(reading)
	if with_answer:
		layer.play = PlayPanel.new()
		choosing.add_child(layer.play)
		layer.answer = AnswerPanel.new()
		choosing.add_child(layer.answer)
	if with_territory:
		layer.territory = TerritoryPanel.new()
		reading.add_child(layer.territory)
	if with_trade:
		layer.trade = TradePanel.new()
		reading.add_child(layer.trade)
	if with_dialogue:
		layer.dialogue = DialoguePanel.new()
		reading.add_child(layer.dialogue)
	down.add_child(bottom)
	layer._frame.add_child(down)
	layer.add_child(layer._frame)
	return layer


func _ready() -> void:
	fit_to(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(_on_resize)


func _on_resize() -> void:
	fit_to(get_viewport().get_visible_rect().size)


## Asked again every frame, because what the panels need changes while the game
## is played: a line of speech arrives, a bag fills up, the sheet is opened. The
## answer is the same on almost every frame and a size set to what it already is
## costs nothing, so this is a comparison rather than a re-layout.
func _process(_delta: float) -> void:
	fit_to(get_viewport().get_visible_rect().size)


## Lay the interface out for a window of this size, in screen pixels.
##
## Public because a window is not the only thing that has a size: a test asks
## for the three window sizes it wants to see the layout at without opening any
## of them, which is the only way an assertion about a window the game ships in
## can be made by a run that has no window at all.
func fit_to(window: Vector2) -> void:
	if _frame == null:
		return
	_needed = _needed.max(_measure())
	art_scale = scale_that_fits(window, _needed)
	scale = Vector2(art_scale, art_scale)
	# The frame is laid out in art pixels, so it is as many of them across as the
	# window is screen pixels divided by the scale. The scale above is chosen so
	# that this is at least as big as what the panels need, which is what keeps
	# the frame from growing past the window and carrying a panel off the edge.
	_frame.size = window / float(art_scale)


## How many times over the room the panels need fits inside the window: the
## smaller of how many times it goes across and how many times it goes down,
## and never less than one.
static func scale_that_fits(window: Vector2, needed: Vector2) -> int:
	if needed.x <= 0.0 or needed.y <= 0.0:
		return 1
	return maxi(1, mini(int(window.x / needed.x), int(window.y / needed.y)))


## How much room the panels this run built need, in art pixels.
##
## Two answers, and the larger of them. The frame's own combined minimum is
## exact, and it is the whole answer once every panel this run built is showing;
## while some are hidden the containers leave them out of it, so the arrangement
## `build` made -- two panels across the top, two stacks across the bottom -- is
## added up here from the panels themselves, hidden ones included.
func _measure() -> Vector2:
	var gap := float(_frame.get_theme_constant("separation", "BoxContainer"))
	var top := _beside(_room_for(panel), _room_for(readout), gap)
	var bottom := _beside(
		_stacked([play, answer], gap),
		_stacked([territory, trade, dialogue], gap),
		gap)
	var panels := Vector2(
		maxf(top.x, bottom.x),
		top.y + bottom.y + (gap if top.y > 0.0 and bottom.y > 0.0 else 0.0))
	var margins := Vector2(MARGIN, MARGIN) * 2.0
	return (panels + margins).max(_frame.get_combined_minimum_size())


## What one panel needs, or nothing at all for a panel this run did not build.
static func _room_for(which: Control) -> Vector2:
	return Vector2.ZERO if which == null else which.get_combined_minimum_size()


## Two things side by side with the containers' own gap between them, or just
## the one of them there is.
static func _beside(left: Vector2, right: Vector2, gap: float) -> Vector2:
	if left.x <= 0.0:
		return right
	if right.x <= 0.0:
		return left
	return Vector2(left.x + gap + right.x, maxf(left.y, right.y))


## A column of panels, one under the other, with the containers' own gap between
## each pair of them.
static func _stacked(column: Array, gap: float) -> Vector2:
	var size := Vector2.ZERO
	for which in column:
		var one := _room_for(which)
		if one.y <= 0.0:
			continue
		size = Vector2(
			maxf(size.x, one.x),
			size.y + one.y + (gap if size.y > 0.0 else 0.0))
	return size


## Where a panel landed and how big it came out, in screen pixels: what the
## measuring tool needs in order to ask whether that rectangle is made of whole
## art pixels. Empty for a panel this run did not build.
func geometry_of(which: Control) -> Rect2i:
	if which == null:
		return Rect2i()
	return Rect2i(
		int(which.global_position.x * art_scale),
		int(which.global_position.y * art_scale),
		int(which.size.x * art_scale),
		int(which.size.y * art_scale),
	)
