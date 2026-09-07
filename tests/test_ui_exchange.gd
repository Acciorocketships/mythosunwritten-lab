extends TestSuite
## The dialogue panel and the trade panel: views onto the words said and the
## trades standing, holding nothing of their own.
##
## The claims, in the order the two panels earn them:
##
##   1. **One theme, no idiom of their own.** Both panels are dressed by the
##      theme the layer carries -- the Sprout Lands pack the character sheet
##      established -- and nothing under either overrides a font, a size or a
##      style. The check is `TestUiReadout`'s own, run over the two new trees.
##   2. **They are views, proved the way the combat readout was.** Each panel
##      watches a world, the world is moved through the engine without the
##      panel being told, and the panel says the new thing on the next refresh;
##      then the panel is asked for a field of its own holding what it shows,
##      and there is none.
##   3. **They quote.** A line of speech reaches the dialogue panel in the one
##      spelling `PlayPanel.heard_line` writes; a refusal reaches the trade
##      panel as `ActionOutcome.line()` through `ControlLoop.answer_of`,
##      unchanged but for the glyphs the art's font does not have.
##   4. **The pattern glyph is the shape, drawn.** `PixelIcons.pattern` is
##      generated from a weapon action's own cells: north is up, the window is
##      the packet's seven-by-seven, a covered cell beyond it is clamped to the
##      rim, only the idiom's three colours are used, and one shape is one
##      cached texture however many rows ask for it.
class_name TestUiExchange

const SEED := ScriptedActions.SEED
const WHERE := ScriptedActions.WHERE


func _init() -> void:
	suite_name = "ui exchange"


func run() -> void:
	_both_panels_wear_the_shared_theme_and_no_idiom_of_their_own()
	_the_dialogue_panel_reads_the_world_and_keeps_no_copy()
	_the_trade_panel_reads_the_world_and_keeps_no_copy()
	_the_trade_panel_quotes_the_engines_refusal_whole()
	_the_pattern_glyph_is_the_shape_drawn()


# --- 1: one theme ----------------------------------------------------------


func _both_panels_wear_the_shared_theme_and_no_idiom_of_their_own() -> void:
	if not SproutPack.is_installed():
		return
	var layer := PixelUi.build(false, false, false, true, true)
	check(layer != null, "the interface did not build")
	if layer == null:
		return
	check(layer.panel == null and layer.readout == null and layer.play == null,
		"a run that asked for only the two exchange panels got more")
	check(layer.dialogue != null, "the dialogue panel was not built")
	check(layer.trade != null, "the trade panel was not built")
	for panel in [layer.dialogue, layer.trade]:
		if panel == null:
			continue
		check((panel as Control).theme == null,
			"a panel carries a theme of its own rather than the shared one")
		var overriding := TestUiReadout._overriding_under(panel)
		equal(",".join(overriding), "",
			"part of a panel overrides the theme's own font, size or style")
	layer.free()


# --- 2: views, not copies --------------------------------------------------


## The dialogue panel says what was said, on the frame after it was said, with
## nobody telling it -- and holds no line of its own.
func _the_dialogue_panel_reads_the_world_and_keeps_no_copy() -> void:
	if not SproutPack.is_installed():
		return
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var id := world.follow_id
	var scene := world.combat.scene
	var hob := scene.actor_of(ScriptedPlay.id_of(scene, ScriptedPlay.HOB))

	var panel := DialoguePanel.new()
	panel.watch(world, id)
	panel.refresh()
	check(panel.visible, "the dialogue panel hid itself from a live world")
	check(panel._rows[DialoguePanel.ROWS - 1].text == DialoguePanel.RESTING,
		"an empty conversation should be said rather than blanked")

	# Move the simulation without telling the panel: the engine resolves a line
	# of speech, and the panel says it on the next refresh.
	var spoke := ActionEngine.resolve(scene, hob, Action.say("mind the stall", id))
	check(spoke.ok, "the stage line should have been said: %s" % spoke.line())
	panel.refresh()
	var written := _texts_of(panel._rows)
	check(written.contains("mind the stall"),
		"a line said on a tick should be on the panel on the next refresh: %s"
		% written)
	check(written.contains(SproutPack.drawable(PlayPanel.heard_line(
		world.surroundings_of(id).heard[-1]))),
		"the panel should spell the line the one way the interface spells one")

	# A shout reaches it too, and reads as one.
	var shouted := ActionEngine.resolve(scene, hob, Action.say("fresh wares"))
	check(shouted.ok, "the shout should have been shouted: %s" % shouted.line())
	panel.refresh()
	check(_texts_of(panel._rows).contains("shouts"),
		"a shout should read as a shout on the panel")

	# And there is no copy of any of it on this side.
	for field in ["heard", "said", "lines", "spoken", "transcript"]:
		check(not TestUiReadout._has_property(panel, field),
			"the dialogue panel has a field of its own called '%s'" % field)
	panel.free()


## The trade panel writes out both halves of an offer the engine took, sees it
## vanish when the engine clears it, and holds no offer of its own.
func _the_trade_panel_reads_the_world_and_keeps_no_copy() -> void:
	if not SproutPack.is_installed():
		return
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var id := world.follow_id
	var scene := world.combat.scene
	var fen := scene.actor_of(id)
	var hob := scene.actor_of(ScriptedPlay.id_of(scene, ScriptedPlay.HOB))
	# Within reach, so the offer is the engine's own doing and not a planted row.
	hob.x = fen.x + 1.0
	hob.z = fen.z

	var panel := TradePanel.new()
	panel.watch(world, id)
	panel.refresh()
	check(panel.visible, "the trade panel hid itself from a live world")
	check(panel._resting.visible, "with no trade standing the panel says so")

	var proposed := ActionEngine.resolve(scene, hob, Action.trade_propose(
		id, PackedStringArray([ScriptedPlay.LANTERN]), 0,
		PackedStringArray(), ScriptedPlay.LANTERN_PRICE))
	check(proposed.ok, "the offer should stand: %s" % proposed.line())
	panel.refresh()
	check(not panel._resting.visible, "a standing trade replaces the resting line")
	var rows: Dictionary = panel._offers[panel._offers.size() - 1]
	equal((rows["gives"] as Label).text, "gives %s" % ScriptedPlay.LANTERN,
		"the given half should be written out")
	equal((rows["wants"] as Label).text,
		"wants %d coin" % ScriptedPlay.LANTERN_PRICE,
		"and the wanted half beside it")
	check((rows["between"] as Label).text.contains("you"),
		"an offer to you should say so: %s" % (rows["between"] as Label).text)

	# The engine clears it -- a denial -- and the panel says so untold.
	var denied := ActionEngine.resolve(scene, fen, Action.trade_deny(hob.id))
	check(denied.ok, "the denial should resolve: %s" % denied.line())
	panel.refresh()
	check(panel._resting.visible, "a denied offer is off the panel on the next refresh")

	for field in ["offers", "standing", "give", "want", "answers"]:
		check(not TestUiReadout._has_property(panel, field),
			"the trade panel has a field of its own called '%s'" % field)
	panel.free()


# --- 3: the refusal is quoted whole ----------------------------------------


## A trade verb refused through the loop reaches the trade panel as the
## engine's own sentence, undimmed, with only the art's missing glyphs swapped.
func _the_trade_panel_quotes_the_engines_refusal_whole() -> void:
	if not SproutPack.is_installed():
		return
	var world := SimWorld.new(SEED)
	ScriptedPlay.muster(world)
	var id := world.follow_id
	var choice := WorldCast.hand_over(world, id)
	var hob_id := ScriptedPlay.id_of(world.combat.scene, ScriptedPlay.HOB)

	# Accept an offer nobody has made, through the same loop a person's key
	# press goes through, so the refusal arrives the way it would on screen.
	choice.choose(Action.trade_accept(hob_id))
	var answer := {}
	for _tick in 30:
		world.step()
		answer = world.loop.answer_of(id)
		if not answer.is_empty():
			break
	check(not answer.is_empty(), "the loop never answered the accept")

	var panel := TradePanel.new()
	panel.watch(world, id)
	panel.refresh()
	check(panel._answer_label.visible,
		"the answer to a trade verb belongs on the trade panel")
	equal(panel._answer_label.text, SproutPack.drawable(String(answer["line"])),
		"the panel should quote the engine rather than phrase its own answer")
	check(String(answer["line"]).contains("out of reach")
		or String(answer["line"]).contains("has offered nothing"),
		"and the sentence should be the engine's refusal: %s" % answer["line"])
	equal(panel._answer_label.theme_type_variation, StringName(""),
		"a refusal is the sentence a person most needs, so it is not dimmed")
	panel.free()


# --- 4: the pattern glyph --------------------------------------------------


func _the_pattern_glyph_is_the_shape_drawn() -> void:
	# One shape is one texture, however many rows ask.
	var ahead: Array = [Vector2i(0, -1)]
	check(PixelIcons.pattern(ahead) == PixelIcons.pattern([Vector2i(0, -1)]),
		"the same shape should come back as the same cached texture")

	# North is up: a cell ahead of the attacker is lit above the centre.
	var image := PixelIcons.pattern(ahead).get_image()
	var centre := 1 + PixelIcons.PATTERN_REACH * 2
	equal(image.get_pixel(centre, centre), PixelIcons.SHADE,
		"the attacker's own cell is the shaded block in the middle")
	equal(image.get_pixel(centre, centre - 2), PixelIcons.LIT,
		"a cell ahead of an attacker facing north is drawn above the centre")

	# A covered cell beyond the window is clamped to the rim in the edge
	# colour: the bow's ring is the case the window cannot hold.
	var far := PixelIcons.pattern([Vector2i(0, -5)]).get_image()
	equal(far.get_pixel(centre, 1), PixelIcons.EDGE,
		"a cell beyond the window is clamped to the rim in the edge colour")

	# Only the idiom's three colours and the idiom's edge, nothing else.
	for glyph in [image, far]:
		for y in PixelIcons.CELL:
			for x in PixelIcons.CELL:
				var colour: Color = (glyph as Image).get_pixel(x, y)
				check(colour.a == 0.0 or colour == PixelIcons.EDGE
					or colour == PixelIcons.SHADE or colour == PixelIcons.LIT,
					"the glyph holds a colour outside the idiom at %d,%d" % [x, y])


# --- The furniture ---------------------------------------------------------


static func _texts_of(rows: Array[Label]) -> String:
	var written := PackedStringArray()
	for row in rows:
		written.append(row.text)
	return "\n".join(written)
