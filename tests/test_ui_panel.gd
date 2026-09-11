extends TestSuite
## The character sheet is drawn from the pack, at whole pixels, off the
## simulation's own object -- and a headless run loads none of it.
##
## Six claims, in the order they matter:
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
##      holding one. This is the claim the whole design rests on. What a row
##      *shows* is part of the same claim: a carried row and a filled equipment
##      slot show the item's own drawn face, resolved through the simulation's
##      own `sim/item_model.gd` on the frame it is drawn -- and so does the play
##      panel's hand row, which is the one row of that panel naming a carried
##      thing.
##   5. **A headless run loads no interface at all** -- no texture, no font, not
##      one script of render/ui/ -- and the panel changes nothing about the
##      world it is drawn over.
##   6. **Nothing on the panel is a mark a person has to be told the meaning
##      of.** Every equipped slot carries the simulation's own word for what
##      goes in it and every button carries the key that presses it. Both are
##      checked by walking what was drawn and counting it against the
##      simulation's own list -- `Inventory.SLOT_ORDER` and the panel's
##      `CONTROLS` -- rather than by looking for the five words and six verbs
##      that happen to be there today, so a slot or a control added later and
##      left unlabelled fails this.
##
## The last claim, that the drawn result is actually crisp, is not a thing a
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
	_a_row_shows_the_items_own_face()
	_the_hand_row_shows_what_is_held()
	_the_source_hands_over_the_world_s_own_objects()
	_a_headless_run_loads_no_interface()
	_the_panel_changes_nothing_about_the_world()
	_every_slot_is_named_and_every_button_names_its_key()


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
			SproutPack.ICON_WORN]:
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


## How many of the drawn icons exist only for the gear faces: the eight of
## `PixelIcons.GEAR`'s thirteen rows that do not reuse an icon already on the
## sheet (the four armour slots and the hand's sword carry five tags between
## them). Written down so an icon drawn for nothing, or a face quietly dropped,
## moves a number a test compares.
const GEAR_ONLY_ICONS := 8


## Every score, every slot, every minion and every gear tag has an icon, because
## the panel asks for one by the simulation's own name and a missing one would
## draw as nothing at all.
func _there_is_an_icon_for_every_score_and_every_slot() -> void:
	for ability in Ability.ALL:
		check(PixelIcons.has(ability), "no icon is drawn for the score '%s'" % ability)
	for slot in Inventory.SLOT_ORDER:
		check(PixelIcons.has(slot), "no icon is drawn for the slot '%s'" % slot)
	for kind in Minion.KINDS:
		check(PixelIcons.has(kind), "no icon is drawn for the minion '%s'" % kind)
	equal(PixelIcons.names().size(),
		Ability.ALL.size() + Inventory.SLOT_ORDER.size() + Minion.KINDS.size()
		+ GEAR_ONLY_ICONS,
		"there are icons drawn that nothing asks for, or the other way round")

	# Every gear tag the catalog has -- not just the ones `ItemModel` hands out
	# today -- resolves to a drawn face, and no row of the face table points at
	# a tag the catalog has dropped or an icon nobody drew.
	var gear_tags := AssetTags.in_category(AssetTags.GEAR)
	for tag in gear_tags:
		check(PixelIcons.GEAR.has(tag), "no face is named for the gear tag '%s'" % tag)
		var named := String(PixelIcons.GEAR.get(tag, ""))
		check(PixelIcons.has(named),
			"the face '%s' named for '%s' is not drawn" % [named, tag])
		check(PixelIcons.gear(tag) != null, "the gear tag '%s' drew nothing" % tag)
	equal(PixelIcons.GEAR.size(), gear_tags.size(),
		"the face table has rows for tags the catalog does not have")

	# And every tag `ItemModel` can actually resolve an item to is among them,
	# so nothing a scenario ships can ask for a face that is not there.
	for tag in ItemModel.tags():
		check(PixelIcons.GEAR.has(tag),
			"'%s' can be an item's answer and has no face" % tag)

	# An item that resolves to nothing shows the wrapped parcel -- the same
	# honest answer, by name, that the ground gives an unnamed item.
	check(PixelIcons.gear(ItemModel.NOTHING) == PixelIcons.of(PixelIcons.GEAR_FALLBACK),
		"a thing with no tag should show the parcel")
	check(PixelIcons.gear("gear_axe") == PixelIcons.of(PixelIcons.GEAR_FALLBACK),
		"a tag nobody drew should show the parcel, not a hole")
	equal(String(PixelIcons.GEAR.get(GroundItems.FALLBACK_TAG, "")),
		PixelIcons.GEAR_FALLBACK,
		"the bag's parcel and the ground's bundle should be the same picture")


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
	# aimed at, child 1 the thing's own face; the name is the one after that
	# and the "worn" tick is the last.
	equal((panel._carried_names.get_child(0).get_child(2) as Label).text, "oak cloak",
		"the panel did not read the name off the item the character is carrying")
	check(panel._carried_names.get_child(0).get_child(5).visible,
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


## A carried row and an equipment slot show the thing's own face -- the drawn
## face of the tag `sim/item_model.gd` resolves it to -- read off the
## simulation's object on the frame it is drawn. A thing that resolves to no
## tag shows the wrapped parcel, and a dagger and a helmet are visibly two
## different things in the bag, which is the whole reason the faces exist.
func _a_row_shows_the_items_own_face() -> void:
	if not SproutPack.is_installed():
		return
	var layer := PixelUi.build()
	if layer == null:
		return
	var sheet := Character.make("Wren", 3)
	var dagger := Item.new()
	dagger.item_name = "iron dagger"
	dagger.kind = Item.KIND_WEAPON
	dagger.slot = Item.SLOT_HAND
	dagger.model = AssetTags.GEAR_DAGGER
	var helmet := Item.new()
	helmet.item_name = "iron helmet"
	helmet.kind = Item.KIND_ARMOUR
	helmet.slot = Item.SLOT_HELMET
	var blanket := Item.new()
	blanket.item_name = "wool blanket"
	sheet.inventory.carry(dagger)
	sheet.inventory.carry(helmet)
	sheet.inventory.carry(blanket)
	var panel := layer.panel
	panel.show_sheets([sheet] as Array[Character])
	panel.refresh()

	# The bag's slot row: the dagger's own face, the helmet's own face, and the
	# parcel for the blanket nobody recorded a shape for.
	var faces: Array[Texture2D] = []
	for index in 3:
		var plate: PanelContainer = panel._carried_row.get_child(index)
		faces.append((plate.get_child(0).get_child(0) as TextureRect).texture)
	check(faces[0] == PixelIcons.gear(AssetTags.GEAR_DAGGER),
		"the carried dagger does not show the dagger's face")
	check(faces[1] == PixelIcons.gear(AssetTags.GEAR_HELMET),
		"the carried helmet does not show the helmet's face")
	check(faces[0] != faces[1],
		"a dagger and a helmet look identical in the bag")
	check(faces[2] == PixelIcons.of(PixelIcons.GEAR_FALLBACK),
		"a thing with no shape recorded does not show the parcel")
	# And each carried line carries the same face beside the name.
	for index in 3:
		var line := panel._carried_names.get_child(index)
		check((line.get_child(1) as TextureRect).texture == faces[index],
			"line %d does not carry the same face as its slot" % index)

	# The hand slot shows what could go there while empty, and the thing itself
	# once it is held -- read off the same object, on the frame after it moved,
	# with nothing told and nothing cached.
	var hand: PanelContainer = panel._equipment[Item.SLOT_HAND]
	var hand_icon := hand.get_child(0).get_child(0) as TextureRect
	check(hand_icon.texture == PixelIcons.of(Item.SLOT_HAND),
		"an empty hand slot should show the slot's own icon")
	check(sheet.inventory.equip(dagger), "the dagger should be holdable")
	panel.refresh()
	check(hand_icon.texture == PixelIcons.gear(AssetTags.GEAR_DAGGER),
		"the hand slot did not show the dagger being held")
	sheet.inventory.unequip(Item.SLOT_HAND)
	panel.refresh()
	check(hand_icon.texture == PixelIcons.of(Item.SLOT_HAND),
		"the hand slot kept the dagger's face after it was put away")

	layer.free()


## The play panel's hand row carries the held thing's own face too, for the same
## reason the sheet's rows do: three of that panel's four marks are about the
## row, and the hand row names one carried thing.
##
## Read off the world's own `Character` under the id being driven, on the frame
## the row is written, through the one file the interface reaches for a sheet
## with. Bare hands keep the row's star, because bare hands are a choice and
## not a thing.
func _the_hand_row_shows_what_is_held() -> void:
	if not SproutPack.is_installed():
		return
	var sim := Simulation.new(SEED)
	check(sim.begin_scenario(Simulation.SCENARIO_ENCOUNTER),
		"the encounter scenario should have been set out")
	var driven := 0
	for row in (sim.world.combat.snapshot()["pieces"] as Array):
		if bool(row["commander"]):
			driven = int(row["id"])
			break
	check(driven != 0, "the encounter put no commander in the world to drive")
	if driven == 0:
		return
	var sheet := SheetSource.sheet_of(sim.world, driven)
	check(sheet != null, "the source found no sheet under the id being driven")
	if sheet == null:
		return
	# The same object the world is holding, as `sheets_in` hands over: writing
	# on it is writing on the world's, which is why nothing here writes.
	check(SheetSource.sheet_of(sim.world, driven) == sheet,
		"asking twice gave two different objects, so one of them is a copy")
	check(SheetSource.sheet_of(sim.world, 0) == null,
		"an id nobody stands under should hand back nothing")

	var panel := PlayPanel.new()
	var controls := PlayerControls.new()
	panel.watch(sim.world, driven, controls)
	# Bare hands: the row's own star, which is what the other three rows carry.
	check(panel.held_face() == SproutPack.icon(SproutPack.ICON_STAR),
		"an empty hand should keep the row's own mark")
	# And each thing the scenario gave this character, held in turn, shows its
	# own face -- the face of the tag the simulation resolves it to, and the
	# parcel for a thing whose shape nobody recorded.
	var seen := 0
	for entry in sheet.inventory.carried:
		controls.holding = ObservationTrail.name_of_entry(entry)
		var tag := ItemModel.of(Inventory.item_of(entry))
		check(panel.held_face() == PixelIcons.gear(tag),
			"holding '%s' did not show the face of '%s'" % [controls.holding, tag])
		check(panel.held_face() != null, "a held thing drew nothing")
		seen += 1
	check(seen > 0, "the encounter's driven character carries nothing to hold")
	# A name nothing in the bag answers to -- a thing given away between the
	# press and the frame -- is the row's mark again rather than a stale face.
	controls.holding = "a thing nobody has"
	check(panel.held_face() == SproutPack.icon(SproutPack.ICON_STAR),
		"a name the bag does not answer to should not draw a face")
	panel.free()


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


# --- Nothing on the panel is an unexplained mark --------------------------


## Every equipped slot says what goes in it, and every button says which key
## presses it.
##
## Both halves are read off what was actually built and counted against the
## simulation's own lists, so this cannot pass by having the five words and the
## six verbs that exist today written into it:
##
##   * every entry of `Inventory.SLOT_ORDER` -- which is `Item`'s own `SLOT_*`
##     vocabulary, the same strings the engine matches an item's `slot` against
##     -- has one plate on the row with that word under it, and the row carries
##     no label belonging to no slot. A sixth slot added to that array and drawn
##     without a word fails the count.
##   * every entry of `CharacterPanel.CONTROLS` has one button whose text is its
##     verb followed by the engine's name for its keycode -- and pressing that
##     button hands the shell that same keycode, so the letter on the button is
##     the key that presses it rather than a letter typed beside it.
func _every_slot_is_named_and_every_button_names_its_key() -> void:
	if not SproutPack.is_installed():
		return
	var layer := PixelUi.build()
	check(layer != null, "the interface did not build")
	if layer == null:
		return
	var panel := layer.panel

	var row := _equipment_row(panel)
	check(row != null, "the panel drew no equipped row to read")
	if row == null:
		layer.free()
		return
	equal(row.get_child_count(), Inventory.SLOT_ORDER.size(),
		"the equipped row draws %d columns for the simulation's %d slots"
		% [row.get_child_count(), Inventory.SLOT_ORDER.size()])
	var named := {}
	for column in row.get_children():
		var word := _label_under(column)
		check(word != "", "a column of the equipped row carries no word at all")
		named[word] = int(named.get(word, 0)) + 1
	for slot in Inventory.SLOT_ORDER:
		var word: String = CharacterPanel.slot_text(slot)
		equal(int(named.get(word, 0)), 1,
			"the slot the simulation calls '%s' is drawn %d times with its own"
			% [slot, int(named.get(word, 0))] + " word under it, not once")
		# The word under the plate is the tag itself, not a second vocabulary
		# kept here, and it is drawn in glyphs this pack's font has.
		equal(word, SproutPack.drawable(slot),
			"the label under the '%s' slot is not that slot's own word" % slot)
		var plate: PanelContainer = panel._equipment[slot]
		equal(_label_under(plate.get_parent()), word,
			"the '%s' plate does not stand over the '%s' label" % [slot, word])
	equal(named.size(), Inventory.SLOT_ORDER.size(),
		"the equipped row draws %d distinct words for %d slots"
		% [named.size(), Inventory.SLOT_ORDER.size()])

	# Every button, and the key it says it presses.
	var buttons := panel._control_row.get_children()
	equal(buttons.size(), CharacterPanel.CONTROLS.size(),
		"the panel drew %d buttons for its %d controls"
		% [buttons.size(), CharacterPanel.CONTROLS.size()])
	var pressed: Array[int] = []
	panel.on_key = func(keycode: int) -> void: pressed.append(keycode)
	for index in CharacterPanel.CONTROLS.size():
		var entry: Dictionary = CharacterPanel.CONTROLS[index]
		var button: Button = buttons[index]
		var key := int(entry["key"])
		var letter := OS.get_keycode_string(key)
		check(letter != "", "control '%s' presses a keycode with no name"
			% String(entry["label"]))
		equal(button.text, SproutPack.drawable(
			"%s %s" % [String(entry["label"]), letter]),
			"the '%s' button reads '%s', which does not name its key"
			% [String(entry["label"]), button.text])
		check(button.text.ends_with(letter),
			"the '%s' button does not end with the key that presses it"
			% String(entry["label"]))
		# And the letter on it is the key it really presses.
		pressed.clear()
		button.pressed.emit()
		equal(pressed.size(), 1,
			"pressing the '%s' button pressed %d keys"
			% [String(entry["label"]), pressed.size()])
		if pressed.size() == 1:
			equal(OS.get_keycode_string(pressed[0]), letter,
				"the '%s' button says '%s' and presses '%s'"
				% [String(entry["label"]), letter,
					OS.get_keycode_string(pressed[0])])
	layer.free()


## The row the equipped plates stand on, found through a plate rather than by
## counting children of the panel, so moving the section does not silently stop
## this from looking at anything.
func _equipment_row(panel: CharacterPanel) -> Control:
	if Inventory.SLOT_ORDER.is_empty():
		return null
	var plate: Variant = panel._equipment.get(Inventory.SLOT_ORDER[0], null)
	return null if plate == null else plate.get_parent().get_parent() as Control


## The one word written under a slot's plate, or "" when there is none.
static func _label_under(column: Node) -> String:
	if column == null:
		return ""
	for child in column.get_children():
		if child is Label:
			return String((child as Label).text)
	return ""


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
