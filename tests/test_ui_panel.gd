extends TestSuite
## The character sheet is drawn from the pack, at whole pixels, off the
## simulation's own object -- and a headless run loads none of it.
##
## Five claims, in the order they matter:
##
##   1. **The pack is really there and really fits.** Every file the table names
##      exists, and every rectangle it cuts is inside the file it cuts from.
##      A rectangle that has slid off its sheet draws the neighbouring sixteen
##      pixels without complaining, so it is checked rather than looked at.
##   2. **The two switches that decide whether a pixel font looks right are
##      off.** Antialiasing and hinting are both on by default in this engine.
##   3. **Nothing falls back to the engine's own look.** A Control with no style
##      still draws, in grey, so this asks the theme for each entry by name.
##   4. **The panel is a view and not a copy.** A score written on the character
##      after the panel was built shows on the panel, and the panel has no field
##      holding one. This is the claim the whole design rests on.
##   5. **A headless run loads no interface at all** -- no texture, no font, not
##      one script of render/ui/ -- and the panel changes nothing about the
##      world it is drawn over.
##
## The sixth claim, that the drawn result is actually crisp, is not a thing a
## test can assert about an object: it is a property of pixels on a screen. It is
## measured instead, by tools/measure_ui.sh, and reports/ui.md has the numbers.
class_name TestUiPanel

const SEED := 5
const FIXED_FPS := 60
const FRAMES := 60


func _init() -> void:
	suite_name = "ui panel"


func run() -> void:
	_the_pack_is_unpacked_and_every_region_fits()
	_the_font_has_antialiasing_and_hinting_off()
	_every_size_is_a_multiple_of_the_font_cell()
	_the_theme_leaves_no_entry_to_the_engine()
	_every_drawn_icon_is_sixteen_by_sixteen_in_three_colours()
	_there_is_an_icon_for_every_score_and_every_slot()
	_the_panel_reads_the_character_and_keeps_no_copy()
	_the_source_hands_over_the_world_s_own_objects()
	_a_headless_run_loads_no_interface()
	_the_panel_changes_nothing_about_the_world()


# --- The pack -------------------------------------------------------------


func _the_pack_is_unpacked_and_every_region_fits() -> void:
	check(SproutPack.is_installed(),
		"the Sprout Lands pack is not unpacked; run ./tools/extract_sprout_lands.sh")
	if not SproutPack.is_installed():
		return
	for path in SproutPack.FILES:
		check(ResourceLoader.exists(path), "the pack is missing %s" % path)

	# Every rectangle the interface cuts, against the file it cuts from.
	var cuts := [
		[SproutPack.SHEET, SproutPack.FRAME, "the frame"],
		[SproutPack.BUTTONS, SproutPack.BUTTON_IDLE, "the idle button"],
		[SproutPack.BUTTONS, SproutPack.BUTTON_HOVER, "the lit button"],
		[SproutPack.BUTTONS, SproutPack.BUTTON_DOWN, "the pressed button"],
		[SproutPack.SLOTS, SproutPack.SLOT_FULL, "an occupied slot"],
		[SproutPack.SLOTS, SproutPack.SLOT_EMPTY, "an empty slot"],
		[SproutPack.HEARTS, SproutPack.HEART_FULL, "a full heart"],
		[SproutPack.HEARTS, SproutPack.HEART_HALF, "a half heart"],
		[SproutPack.HEARTS, SproutPack.HEART_EMPTY, "an empty heart"],
	]
	for cut in cuts:
		var sheet: Texture2D = load(cut[0])
		var rect: Rect2i = cut[1]
		check(sheet != null and rect.position.x >= 0 and rect.position.y >= 0
			and rect.end.x <= sheet.get_width() and rect.end.y <= sheet.get_height(),
			"%s is cut from outside %s" % [cut[2], cut[0]])
		var region := SproutPack.region(cut[0], rect)
		check(region != null and region.get_width() == rect.size.x,
			"%s did not come back at the size it was asked for" % cut[2])

	for named in [SproutPack.ICON_STAR, SproutPack.ICON_CROWN, SproutPack.ICON_COIN,
			SproutPack.ICON_WORN, SproutPack.ICON_NO_SLOT]:
		var icon := SproutPack.icon(named)
		check(icon != null and icon.get_width() == SproutPack.CELL
			and icon.get_height() == SproutPack.CELL,
			"the generic icon at column %d row %d is not one cell"
			% [named.x, named.y])


# --- The font -------------------------------------------------------------


## The two engine defaults that would ruin a pixel font, plus the third that
## would re-rasterise it at whatever scale it is drawn at.
func _the_font_has_antialiasing_and_hinting_off() -> void:
	if not SproutPack.is_installed():
		return
	var font := SproutTheme.build_font()
	check(font != null, "the pack's font did not load")
	if font == null:
		return
	equal(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE,
		"the font is antialiased; every glyph edge would be grey")
	equal(font.hinting, TextServer.HINTING_NONE,
		"the font is hinted; stems already on the pixel grid would be moved off it")
	equal(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED,
		"the font is positioned at sub-pixel offsets")
	equal(font.multichannel_signed_distance_field, false,
		"the font is a distance field, which is a smooth outline by construction")
	equal(font.generate_mipmaps, false, "the font has mipmaps")
	equal(font.oversampling, 1.0,
		"the font is rasterised at the canvas scale rather than at its own size")
	equal(font.allow_system_fallback, false,
		"a missing glyph would come back in somebody else's typeface")

	# The font is on an 8x14 cell: at its own size a capital is exactly eight
	# pixels wide. If that stops being true, every width in the panel is wrong.
	var width := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1,
		SproutPack.FONT_CELL).x
	equal(width, 8.0, "a capital at size %d is %.1f pixels wide, not the cell's 8"
		% [SproutPack.FONT_CELL, width])


func _every_size_is_a_multiple_of_the_font_cell() -> void:
	for size in [SproutTheme.BODY_SIZE, SproutTheme.TITLE_SIZE]:
		equal(size % SproutPack.FONT_CELL, 0,
			"font size %d is not a multiple of the font's own %d-pixel cell"
			% [size, SproutPack.FONT_CELL])
	equal(SproutPack.CELL % 8, 0, "the art's cell is not a multiple of eight")


# --- The theme ------------------------------------------------------------


func _the_theme_leaves_no_entry_to_the_engine() -> void:
	if not SproutPack.is_installed():
		return
	var theme := SproutTheme.build()
	check(theme != null, "the theme did not build")
	if theme == null:
		return
	check(theme.default_font != null and theme.default_font is FontFile,
		"the theme has no font of its own, so every Control falls back to the engine's")
	equal(theme.default_font_size, SproutTheme.BODY_SIZE,
		"the theme's default size is not the font's own cell")

	for type in ["Panel", "PanelContainer", SproutTheme.SLOT_FULL, SproutTheme.SLOT_EMPTY]:
		var box := theme.get_stylebox("panel", type)
		check(box is StyleBoxTexture,
			"%s draws with %s rather than with the pack's art"
			% [type, "nothing" if box == null else box.get_class()])
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		check(theme.has_stylebox(state, "Button"),
			"a Button in state '%s' falls back to the engine's grey" % state)
	for state in ["normal", "hover", "pressed"]:
		check(theme.get_stylebox(state, "Button") is StyleBoxTexture,
			"a Button in state '%s' is not drawn from the pack" % state)
	for type in ["Label", SproutTheme.TITLE, SproutTheme.HEADING_LABEL,
			SproutTheme.DIM_LABEL]:
		check(theme.has_font("font", type) and theme.has_font_size("font_size", type)
			and theme.has_color("font_color", type),
			"%s has no font, size or colour of its own" % type)

	# The look of a pixel interface also rests on one project setting: a
	# CanvasItem with no filter of its own takes this one, and anything but
	# nearest is a blur on every sprite in the panel.
	equal(int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter", -1)), 0,
		"the project's default 2D texture filter is not nearest-neighbour")


# --- The drawn icons ------------------------------------------------------


func _every_drawn_icon_is_sixteen_by_sixteen_in_three_colours() -> void:
	for named in PixelIcons.names():
		var rows: Array = PixelIcons.ART[named]
		equal(rows.size(), PixelIcons.CELL,
			"the icon '%s' is %d rows, not the cell's %d"
			% [named, rows.size(), PixelIcons.CELL])
		var wrong_width := 0
		var strange := ""
		for y in rows.size():
			var line: String = rows[y]
			if line.length() != PixelIcons.CELL:
				wrong_width += 1
			for x in line.length():
				if not line[x] in ".oml":
					strange = line[x]
		equal(wrong_width, 0,
			"%d row(s) of '%s' are not the cell's %d characters wide"
			% [wrong_width, named, PixelIcons.CELL])
		equal(strange, "",
			"'%s' is drawn with '%s', which is none of the three colours"
			% [named, strange])
		var drawn := PixelIcons.of(named)
		check(drawn != null and drawn.get_width() == PixelIcons.CELL
			and drawn.get_height() == PixelIcons.CELL,
			"the icon '%s' did not come out one cell square" % named)


## Every score and every slot has an icon, because the panel asks for one by the
## simulation's own name and a missing one would draw as nothing at all.
func _there_is_an_icon_for_every_score_and_every_slot() -> void:
	for ability in Ability.ALL:
		check(PixelIcons.has(ability), "no icon is drawn for the score '%s'" % ability)
	for slot in Inventory.SLOT_ORDER:
		check(PixelIcons.has(slot), "no icon is drawn for the slot '%s'" % slot)
	equal(PixelIcons.names().size(), Ability.ALL.size() + Inventory.SLOT_ORDER.size(),
		"there are icons drawn that nothing asks for, or the other way round")


# --- The panel is a view --------------------------------------------------


## A number written on the character after the panel was built shows on the
## panel. Nothing pushes it there and nothing is invalidated: the panel is
## looking at the same object.
func _the_panel_reads_the_character_and_keeps_no_copy() -> void:
	if not SproutPack.is_installed():
		return
	var layer := PixelUi.build()
	check(layer != null, "the interface did not build")
	if layer == null:
		return
	var sheet := Character.make("Wren", 3)
	sheet.record_scores({Ability.STR: 11, Ability.WIS: 4})
	sheet.inventory.gain(120)
	var panel := layer.panel
	panel.show_sheets([sheet] as Array[Character])
	panel.refresh()

	check(panel.current() == sheet,
		"the panel is showing something other than the object it was handed")
	equal(_text_at(panel, "_level"), "lv 3", "the level did not reach the panel")
	equal(_text_at(panel, "_status"), "st 3",
		"an unassigned status should read the level")
	equal(_text_at(panel, "_money"), "120", "the money did not reach the panel")
	equal(_score_text(panel, Ability.STR), "11", "a recorded score did not reach the panel")
	equal(_score_text(panel, Ability.CON), CharacterPanel.NOTHING,
		"an unrecorded score should read as a dash, which is not a zero")

	# Now move the character, and ask the panel again without telling it.
	sheet.level_up(Ability.CON)
	sheet.set_status(9)
	sheet.health -= 5
	sheet.inventory.pay(20)
	panel.refresh()
	equal(_text_at(panel, "_level"), "lv 4", "the panel kept its own copy of the level")
	equal(_text_at(panel, "_status"), "st 9", "the panel kept its own copy of the status")
	equal(_score_text(panel, Ability.CON), "1",
		"the panel kept its own copy of the ability scores")
	equal(_text_at(panel, "_money"), "100", "the panel kept its own copy of the money")
	equal(_text_at(panel, "_health"), "%d/%d" % [sheet.health, sheet.max_health()],
		"the panel kept its own copy of the health")

	# And the inventory, which is the part with a shape rather than a number.
	var cloak := Item.new()
	cloak.item_name = "oak cloak"
	cloak.kind = Item.KIND_ARMOUR
	cloak.slot = Item.SLOT_CHESTPLATE
	cloak.level = 4
	sheet.inventory.carry(cloak)
	sheet.inventory.equip(cloak)
	panel.refresh()
	equal(panel._carried_names.get_child_count(), 1,
		"a thing picked up by the character did not appear on the panel")
	# Child 0 of a carried line is the mark saying which one the controls are
	# aimed at; the name is the one after it and the "worn" tick is the last.
	equal((panel._carried_names.get_child(0).get_child(1) as Label).text, "oak cloak",
		"the panel did not read the name off the item the character is carrying")
	check(panel._carried_names.get_child(0).get_child(4).visible,
		"the panel did not notice the item was put on")
	equal(panel._equipment[Item.SLOT_CHESTPLATE].theme_type_variation,
		StringName(SproutTheme.SLOT_FULL),
		"the chestplate slot did not fill when the character put one on")

	# And there is no second copy of any of it anywhere on this side.
	for field in ["level", "status", "health", "scores", "money", "inventory",
			"equipment", "carried"]:
		check(not _has_property(panel, field),
			"the panel has a field of its own called '%s'" % field)

	layer.free()


func _the_source_hands_over_the_world_s_own_objects() -> void:
	var sim := Simulation.new(SEED)
	# Everybody living in an ordinary world: the cast the world musters, plus
	# whatever the enemy layer has stood up around it. Both are characters in the
	# world's own roster and the source does not know the difference, which is
	# the point of it.
	equal(SheetSource.sheets_in(sim.world).size(),
		WorldCast.CAST.size() + sim.world.enemy_streamer.standing_count(),
		"an ordinary world should hand over the sheets of the cast living in it")
	check(sim.begin_scenario(Simulation.SCENARIO_ENCOUNTER),
		"the encounter scenario should have been set out")
	var sheets := SheetSource.sheets_in(sim.world)
	check(sheets.size() >= 2,
		"the encounter puts characters in the world; the source found %d"
		% sheets.size())
	if sheets.is_empty():
		return

	# The same object, not a copy of it: writing on what the source handed back
	# is writing on what the world is holding, which is why nothing writes.
	var before := sheets[0].health
	sheets[0].health = before - 3
	equal(SheetSource.sheets_in(sim.world)[0].health, before - 3,
		"the source handed back a copy rather than the world's own character")
	sheets[0].health = before

	# And they carry what the scenario gave them, which is what the panel draws.
	check(sheets[0].inventory.size() > 0,
		"the encounter's characters carry gear; the sheet handed over carries none")
	check(not sheets[0].equipment.is_empty(),
		"the encounter's characters are equipped; the sheet handed over is not")


# --- Headless, and the world underneath -----------------------------------


## A headless run loads no texture, no font and not one script of the interface.
##
## Asked from outside, of the engine's own resource cache, exactly the way the
## same claim is asked about the models: a counter kept inside the interface
## could only be read by loading the interface.
func _a_headless_run_loads_no_interface() -> void:
	var output := _run(["--seed", str(SEED), "--ticks", "20", "--assets"],
		"res://bin/headless_main.gd")
	check(output.contains("assets visual-files found="),
		"the headless run printed no asset report")
	for line in output.split("\n"):
		if line.begins_with("assets visual-files") or line.begins_with("assets render-scripts"):
			check(line.contains("loaded=0"),
				"a headless run loaded something it should not have: %s" % line)

	# And the pack and the interface are actually among what was counted, or the
	# two zeros above would be about a project that has no interface in it.
	var found := 0
	for path in SproutPack.FILES:
		if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			found += 1
	equal(found, SproutPack.FILES.size(),
		"the pack's files are not on disk, so the headless report was not about them")
	check(LayerCheck._files_under(LayerCheck.UI_DIR).size() >= 3,
		"there is no interface under %s for the report to have skipped"
		% LayerCheck.UI_DIR)


## The panel draws the world and changes none of it: the same seed with and
## without it reaches the same world.
func _the_panel_changes_nothing_about_the_world() -> void:
	var without := _digest_of(_run_shell([]))
	var with_panel := _digest_of(_run_shell(["--sheet", "--scenario",
		Simulation.SCENARIO_ENCOUNTER]))
	var with_scenario := _digest_of(_run_shell(["--scenario",
		Simulation.SCENARIO_ENCOUNTER]))
	check(without != "", "the shell printed no world fingerprint")
	# The scenario changes the world -- it puts characters in it -- and the panel
	# over the same scenario does not. Both halves, or the comparison would pass
	# for a shell that never drew anything.
	not_equal(with_scenario, without,
		"setting the encounter out should have changed the world")
	equal(with_panel, with_scenario,
		"the world the shell reached differed with the character sheet on screen")


# --- Helpers --------------------------------------------------------------


func _text_at(panel: CharacterPanel, field: String) -> String:
	var label: Variant = panel.get(field)
	return "" if label == null else String(label.text)


func _score_text(panel: CharacterPanel, ability: String) -> String:
	var label: Variant = panel._scores.get(ability, null)
	return "" if label == null else String(label.text)


static func _has_property(on: Object, named: String) -> bool:
	for entry in on.get_property_list():
		if String(entry["name"]) == named:
			return true
	return false


func _run_shell(extra: Array) -> String:
	var args := ["--fixed-fps", str(FIXED_FPS), "--quit-after", str(FRAMES),
		"--", "--seed", str(SEED), "--no-grass", "--no-atmosphere"]
	args.append_array(extra)
	return _run(args, "")


func _run(args: Array, script: String) -> String:
	var full: Array = ["--headless", "--path",
		ProjectSettings.globalize_path("res://")]
	if script != "":
		full.append_array(["--script", script, "--"])
	full.append_array(args)
	var output: Array[String] = []
	OS.execute(OS.get_executable_path(), full, output, true)
	return "\n".join(output)


func _digest_of(output: String) -> String:
	for line in output.split("\n"):
		var at := line.find("digest=")
		if line.contains("render-shell stop tick=") and at != -1:
			return line.substr(at + "digest=".length()).strip_edges()
	return ""
