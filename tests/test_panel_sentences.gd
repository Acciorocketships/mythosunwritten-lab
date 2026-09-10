extends TestSuite
## What the panels print reads as English, and says how old it is.
##
## Three things a person reads used to be the engine's data structures printed at
## them, and all three are drawn by one pure function each. This suite is about
## those three functions and about the line they sit on.
##
##   1. **A chosen action.** `ActionSentence.of()` writes an `Action` as a
##      sentence. Every one of the catalogue's fifteen rows has one, no sentence
##      carries the punctuation the pack's font cannot draw, and none of them is
##      the call the simulation writes the same choice down as.
##   2. **What is picked on a board.** `BoardControls.step_line()` writes the two
##      rings as a sentence, in every shape they can be in.
##   3. **How old an answer is.** `AnswerPanel.age_line()` is the whole of the
##      rule that an answer says its age and then stops being drawn, so that a
##      refusal from two hundred ticks ago cannot read as the answer to the last
##      key pressed.
##
## ## Which side of the split each string lives on
##
## This item rewrote presentation and nothing else, and that claim is worth what
## it can be checked by. `_the_two_spellings_are_both_there()` puts the two side
## by side for one action at a time: the simulation's own `Action.line()`, pinned
## to the exact string it has always been, and the panel's sentence beside it.
## The first is what the journal, the traces, the loop's record of what it
## answered and every run-against-run comparison are written in; the second
## reaches a screen and nothing else. A change that moved a word from one column
## to the other would fail here.
##
## ## Purity
##
## All three functions are static, take only what they are given and read no
## world, so the whole suite runs headless with no scene tree, no window and no
## simulation anywhere. The one check that needs the pack on disk is the
## legibility one, which measures real colours out of real art and is skipped on
## a clone where the pack is not unpacked.
class_name TestPanelSentences

## The punctuation the pack's font draws as something else: round brackets as
## bare vertical strokes, and a comma as a full stop. A sentence a person reads
## carries none of it.
const UNREADABLE := ["(", ")", ",", "[", "]"]

## What the frame's own interior is, for the legibility check: the middle of the
## nine-slice, which is the flat brown every panel's text is drawn over.
const FRAME_MIDDLE := Vector2i(15, 15)

## How far a line has to stand off its background to count as legible here, as a
## WCAG contrast ratio.
##
## Three rather than the 4.5 that standard asks of body text, and the reason is
## the art. Every glyph on these panels is drawn with a one-pixel shadow of the
## pack's own dark under it (`SproutTheme._dress_labels`), so what a reader
## actually sees is an outlined shape rather than a flat fill -- which is what
## the standard's 3:1 bar for large text and graphical objects is about. Three is
## also what this pack's own text colour measures over its own frame, so the bar
## says "as readable as everything else on this panel" rather than a number
## picked to be passed.
const LEGIBLE := 3.0


func _init() -> void:
	suite_name = "panel words"


func run() -> void:
	_every_action_has_a_sentence()
	_no_sentence_carries_punctuation_the_font_cannot_draw()
	_the_two_spellings_are_both_there()
	_a_walk_says_which_way_it_heads()
	_the_sentences_are_pure()
	_the_step_line_is_a_sentence_in_every_shape()
	_the_step_line_is_legible_on_the_panel_it_is_drawn_on()
	_an_answer_says_how_old_it_is_and_then_stops()


# --- 1. A chosen action ---------------------------------------------------


# Every row of the one list has a sentence of its own, and none of them is the
# fallback -- which is the call spelling, quoted, and is what a sixteenth row
# would read as until somebody wrote its sentence.
func _every_action_has_a_sentence() -> void:
	for kind in ActionCatalog.names():
		var params := _example_params(kind)
		var sentence := ActionSentence.of_choice(kind, params)
		check(sentence != "", "%s has no sentence" % kind)
		not_equal(sentence, Action.of(kind, params).line(),
			"%s is drawn as the call rather than as a sentence" % kind)
		check(not sentence.contains("="),
			"%s's sentence still spells a parameter out: %s" % [kind, sentence])
	# And the fallback really is the call spelling, for a kind that is not a row.
	equal(ActionSentence.of_choice("somersault", {}),
		Action.of("somersault", {}).line(),
		"a kind with no sentence should be quoted in the engine's own spelling")
	equal(ActionSentence.of(null), "", "no choice at all should draw nothing")


func _no_sentence_carries_punctuation_the_font_cannot_draw() -> void:
	for kind in ActionCatalog.names():
		var sentence := ActionSentence.of_choice(kind, _example_params(kind))
		for mark in UNREADABLE:
			check(not sentence.contains(mark),
				"%s's sentence carries '%s', which this font draws as something "
				% [kind, mark] + "else: %s" % sentence)
	# The step line is drawn in the same font and answers to the same rule.
	for shape in _step_shapes():
		for mark in UNREADABLE:
			check(not String(shape["line"]).contains(mark),
				"the step line carries '%s': %s" % [mark, shape["line"]])


# The claim the whole item rests on: both spellings exist, the engine's is the
# one it has always been, and the panel's is the other one. Pinned to exact
# strings on both sides, so a word cannot cross the line unnoticed.
func _the_two_spellings_are_both_there() -> void:
	var both := [
		{
			"what": Action.say("what will you take for it?", 4),
			"engine": "say(text=what will you take for it? target=4)",
			"panel": "says to #4 \"what will you take for it?\"",
		},
		{
			"what": Action.say("stand back"),
			"engine": "say(text=stand back)",
			"panel": "shouts \"stand back\"",
		},
		{
			"what": PlayerControls.walk(Vector2(0.0, -1.0)),
			"engine": "go_to(offset=(0.000, -3.600))",
			"panel": "walks 3.6 to the north",
		},
		{
			"what": Action.go_to(7),
			"engine": "go_to(target=7)",
			"panel": "walks over to #7",
		},
		{
			"what": Action.go_to(Vector2(12.0, -4.5)),
			"engine": "go_to(target=(12.000, -4.500))",
			"panel": "walks to the spot 12.0 by -4.5",
		},
		{
			"what": Action.trade_propose(
				4, PackedStringArray(["boots"]), 0,
				PackedStringArray(["iron key"]), 3),
			"engine": "trade_propose(target=4 give=[boots] give_money=0"
				+ " want=[iron key] want_money=3)",
			"panel": "offers #4 the boots for the iron key and 3 coins",
		},
		{
			"what": Action.trade_propose(4, PackedStringArray(), 2),
			"engine": "trade_propose(target=4 give=[] give_money=2 want=[]"
				+ " want_money=0)",
			"panel": "offers #4 2 coins for nothing",
		},
		{
			"what": Action.attack(2, "sword"),
			"engine": "attack(target=2 item=sword)",
			"panel": "attacks #2 with the sword",
		},
		{
			"what": Action.attack(2, ""),
			"engine": "attack(target=2 item=)",
			"panel": "attacks #2 bare-handed",
		},
		{
			"what": Action.jump(Vector2(1.5, 2.0)),
			"engine": "jump(target=(1.500, 2.000))",
			"panel": "leaps to the spot 1.5 by 2.0",
		},
		{
			"what": Action.pick_up("iron key", 9),
			"engine": "pick_up(item=iron key target=9)",
			"panel": "takes the iron key out of #9",
		},
		{
			"what": Action.drop("iron key"),
			"engine": "drop(item=iron key)",
			"panel": "drops the iron key",
		},
		{
			"what": Action.wait(5),
			"engine": "wait(ticks=5)",
			"panel": "waits 5 ticks",
		},
	]
	for one in both:
		var chosen: Action = one["what"]
		equal(chosen.line(), String(one["engine"]),
			"the simulation's own spelling of %s changed" % chosen.kind)
		equal(ActionSentence.of(chosen), String(one["panel"]),
			"the panel's sentence for %s" % chosen.kind)


func _a_walk_says_which_way_it_heads() -> void:
	var ways := {
		Vector2(0.0, -1.0): "north",
		Vector2(1.0, -1.0): "north-east",
		Vector2(1.0, 0.0): "east",
		Vector2(1.0, 1.0): "south-east",
		Vector2(0.0, 1.0): "south",
		Vector2(-1.0, 1.0): "south-west",
		Vector2(-1.0, 0.0): "west",
		Vector2(-1.0, -1.0): "north-west",
	}
	for way in ways:
		equal(ActionSentence.heading_of(way), String(ways[way]),
			"which way %s heads" % str(way))
	# Every walk key a person can press comes out as one of the eight, and the
	# four that are a single key each come out as the four points of the compass.
	for keycode in PlayerControls.WALK_KEYS:
		var way: Vector2 = PlayerControls.WALK_KEYS[keycode]
		check(ActionSentence.COMPASS.has(ActionSentence.heading_of(way)),
			"a walk key heads somewhere the compass has no word for: %s" % str(way))


# Pure: nothing here reads a clock, a world or a machine, so the same input is
# the same sentence every time and in every order.
func _the_sentences_are_pure() -> void:
	for kind in ActionCatalog.names():
		var params := _example_params(kind)
		equal(ActionSentence.of_choice(kind, params.duplicate()),
			ActionSentence.of_choice(kind, params.duplicate()),
			"%s's sentence is not the same twice" % kind)
	for shape in _step_shapes():
		equal(_step_line_of(shape), String(shape["line"]),
			"the step line is not the same twice: %s" % shape["what"])
	for pair in [[0, 0], [4, 0], [61, 0], [200, 140]]:
		equal(AnswerPanel.age_line(int(pair[0]), int(pair[1])),
			AnswerPanel.age_line(int(pair[0]), int(pair[1])),
			"an age is not the same twice: %s" % str(pair))


# --- 2. What is picked on a board -----------------------------------------


func _the_step_line_is_a_sentence_in_every_shape() -> void:
	for shape in _step_shapes():
		equal(_step_line_of(shape), String(shape["line"]), String(shape["what"]))
	# And the object says the same thing as the function it is made of, which is
	# what makes pinning the function worth anything.
	var controls := BoardControls.new()
	equal(controls.picked_line(), BoardControls.NOTHING_PICKED,
		"a fresh set of controls has picked nothing")
	controls.has_cell = true
	controls.cell = Vector2i(-161, 138)
	controls.minion_id = 3
	controls.has_minion_cell = true
	controls.minion_cell = Vector2i(-160, 139)
	equal(controls.picked_line(),
		"stepping to -161 by 138 and sending #3 to -160 by 139",
		"the controls should say what they have picked")


# The other half of "legible": the colour. The line is drawn in the panel's own
# text colour over the frame's own interior, and the dimmed tan it used to be
# drawn in is the colour of the frame's rails -- a shade off the brown it sits
# on. Both ratios are measured out of the pack's real art rather than asserted
# from a table.
func _the_step_line_is_legible_on_the_panel_it_is_drawn_on() -> void:
	check(SproutPack.is_installed(),
		"the Sprout Lands pack is not unpacked; run tools/extract_sprout_lands.sh")
	if not SproutPack.is_installed():
		return
	var frame := SproutPack.region(SproutPack.SHEET, SproutPack.FRAME)
	var sheet := frame.atlas.get_image()
	var behind := sheet.get_pixelv(SproutPack.FRAME.position + FRAME_MIDDLE)
	var plain := _contrast(SproutTheme.TEXT, behind)
	var dimmed := _contrast(SproutTheme.DIM, behind)
	check(plain >= LEGIBLE,
		"the panel's text colour is %.2f against the frame it is drawn on, under %.1f"
			% [plain, LEGIBLE])
	check(dimmed < LEGIBLE,
		"the dimmed colour is %.2f, which would make it as readable as the plain one"
			% dimmed)
	check(plain > dimmed * 1.5,
		"the plain colour should stand well clear of the dimmed one: %.2f against %.2f"
			% [plain, dimmed])
	# What "the plain colour" is, asked of the theme rather than assumed: a Label
	# with no type variation is dressed in `SproutTheme.TEXT`.
	var theme := SproutTheme.build()
	check(theme != null, "the theme could not be built")
	if theme != null:
		equal(theme.get_color("font_color", "Label"), SproutTheme.TEXT,
			"a plain Label is not drawn in the colour measured above")
	# And the panel draws the picked line as a plain Label.
	var panel := CombatPanel.new()
	var label := panel._picked_label
	not_equal(String(label.theme_type_variation), SproutTheme.DIM_LABEL,
		"the picked line is drawn in the dimmed colour")
	equal(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART,
		"the picked line should wrap rather than end in an ellipsis")
	equal(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING,
		"the picked line should not end in an ellipsis")
	panel.free()


# --- 3. How old an answer is ----------------------------------------------


func _an_answer_says_how_old_it_is_and_then_stops() -> void:
	equal(AnswerPanel.age_line(40, 40), "just now", "an answer given this tick")
	equal(AnswerPanel.age_line(41, 40), "1 tick ago", "an answer given last tick")
	equal(AnswerPanel.age_line(52, 40), "12 ticks ago", "an answer twelve ticks old")
	equal(AnswerPanel.age_line(40 + AnswerPanel.ANSWER_LIFE, 40),
		"%d ticks ago" % AnswerPanel.ANSWER_LIFE,
		"the oldest answer still drawn")
	equal(AnswerPanel.age_line(41 + AnswerPanel.ANSWER_LIFE, 40), "",
		"an answer past its life should not be drawn at all")
	equal(AnswerPanel.age_line(240, 40), "",
		"a refusal two hundred ticks old should not be drawn at all")
	# A clock that reads behind the answer's own tick cannot happen in a run --
	# the loop's clock and the world's advance on the same step -- and is read as
	# "just now" rather than as a number nobody could make sense of.
	equal(AnswerPanel.age_line(39, 40), "just now", "an answer from the tick ahead")
	# Older is never shorter-lived: the rule is one threshold and not a table.
	var previous := ""
	for ago in range(0, AnswerPanel.ANSWER_LIFE + 1):
		var said := AnswerPanel.age_line(1000 + ago, 1000)
		check(said != "", "%d ticks ago should still be drawn" % ago)
		not_equal(said, previous, "%d ticks ago reads the same as the tick before" % ago)
		previous = said


# --- What the checks are made of ------------------------------------------


# One example of every row of the catalogue, filled in from the row's own
# declared parameters so a row that grows one is filled in here without this
# file being touched. Ids, names, counts and places are stand-ins and mean
# nothing beyond being of the right sort.
func _example_params(kind: String) -> Dictionary:
	var row := ActionCatalog.row_of(kind)
	if row.is_empty():
		return {}
	var params := {}
	for key in row["params"]:
		params[key] = _example_value(key, String(row["params"][key]))
	for key in ActionCatalog.either_of(row):
		params[key] = _example_value(key, String(ActionCatalog.either_of(row)[key]))
		break
	for key in row["optional"]:
		params[key] = _example_value(key, String(row["optional"][key]))
	return params


func _example_value(key: String, sort: String) -> Variant:
	match sort:
		ActionCatalog.ID:
			return 4
		ActionCatalog.POSITION:
			return Vector2(12.0, -4.5)
		ActionCatalog.OFFSET:
			return Vector2(0.0, -3.6)
		ActionCatalog.ID_OR_POSITION:
			return 4
		ActionCatalog.ID_OR_NAME:
			return 4
		ActionCatalog.COUNT:
			return 3
		ActionCatalog.NAMES:
			return PackedStringArray(["boots"])
	return "iron key" if key == "item" else "well met"


# Every shape the two rings on a board can be in, with the sentence each one
# should read as.
func _step_shapes() -> Array:
	return [
		{
			"what": "nothing picked at all",
			"cell": false, "at": Vector2i.ZERO,
			"unit": 0, "sending": false, "to": Vector2i.ZERO,
			"line": "nothing picked yet",
		},
		{
			"what": "a cell to step onto and no minion",
			"cell": true, "at": Vector2i(-161, 138),
			"unit": 0, "sending": false, "to": Vector2i.ZERO,
			"line": "stepping to -161 by 138",
		},
		{
			"what": "a minion with a cell and no step",
			"cell": false, "at": Vector2i.ZERO,
			"unit": 3, "sending": true, "to": Vector2i(-160, 139),
			"line": "sending #3 to -160 by 139",
		},
		{
			"what": "a minion with nowhere to go",
			"cell": false, "at": Vector2i.ZERO,
			"unit": 3, "sending": false, "to": Vector2i.ZERO,
			"line": "nowhere picked yet for #3",
		},
		{
			"what": "both rings picked",
			"cell": true, "at": Vector2i(-161, 138),
			"unit": 3, "sending": true, "to": Vector2i(-160, 139),
			"line": "stepping to -161 by 138 and sending #3 to -160 by 139",
		},
	]


static func _step_line_of(shape: Dictionary) -> String:
	return BoardControls.step_line(
		bool(shape["cell"]), shape["at"],
		int(shape["unit"]), bool(shape["sending"]), shape["to"])


# The WCAG contrast ratio between two colours: the lighter's relative luminance
# over the darker's, both nudged away from zero. It is the standard reading of
# "can this be read on that", and it is used here rather than a difference of
# channels because a difference of channels is what let a tan on a brown pass.
static func _contrast(text: Color, behind: Color) -> float:
	var one := _luminance(text)
	var two := _luminance(behind)
	return (maxf(one, two) + 0.05) / (minf(one, two) + 0.05)


static func _luminance(colour: Color) -> float:
	var parts := [colour.r, colour.g, colour.b]
	var linear := PackedFloat32Array()
	for part in parts:
		var value: float = part
		linear.append(value / 12.92 if value <= 0.04045
			else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


