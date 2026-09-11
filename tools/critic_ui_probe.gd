extends SceneTree
## Whether the player-facing interface is the Sprout Lands pack's own, and
## whether it stays on the render side.
##
## Written by the review of the interface milestone (W-ui-review), not by the
## work under it. Everything the milestone claims about the interface is a claim
## about objects that exist at run time -- which stylebox a panel resolves, which
## font a label is drawn with, how many pixels wide a drawn icon is, whether a
## resource is in the engine's cache -- and every one of them can be read off
## those objects instead of out of the source that made them. That is what this
## does.
##
## Nothing here asserts. Every section prints what it asked and what came back,
## including the questions that found nothing.
##
##   A -- every panel the shell can build, walked node by node: which stylebox
##        and which typeface each Control actually resolves, and whether either
##        came from the engine's own default theme
##   B -- the pack's font as the interface holds it: antialiasing, hinting,
##        oversampling, and whether every size is a whole multiple of the font's
##        own cell
##   C -- every texture the interface can draw, measured: the pack's regions, the
##        icons drawn here, the generated attack patterns, the effect sprites
##   D -- the resource cache, with a positive control: the same
##        `ResourceLoader.has_cached` call a headless run is judged by, asked
##        before and after the interface's own art is loaded
##   E -- which files under the render layer name the vocabulary of an interface,
##        and whether the interface rule in `tests/layer_check.gd` covers each
##
## Run it with:
##   env -u DISPLAY -u WAYLAND_DISPLAY "$GODOT" --headless --path . \
##       --script res://tools/critic_ui_probe.gd

## The engine's own look, for telling "the pack dressed this" from "nothing did".
var _default_theme: Theme = null


## Everything runs on the first processed frame rather than in `_initialize()`.
## The reason is section A: a node added to the root during `_initialize()` is not
## yet inside the tree, and a Control outside the tree has no theme owner, so
## every label would resolve the engine's own typeface and the probe would report
## a fault that is its own. By the first frame the root is in the tree and a
## label answers with the font it is really drawn with.
func _process(_delta: float) -> bool:
	_default_theme = ThemeDB.get_default_theme()
	print("=== critic UI probe ===")
	print("pack installed: %s (root %s)" % [SproutPack.is_installed(), SproutPack.ROOT])
	print("")
	# The cache first, deliberately: every later section loads the pack's art,
	# and a "was it cached before" asked after that is no control at all.
	_section_d_cache()
	_section_a_panels()
	_section_b_font()
	_section_c_textures()
	_section_e_coverage()
	_section_f_glyphs()
	return true


# --- A: what dresses each panel --------------------------------------------

func _section_a_panels() -> void:
	print("--- A. every panel, node by node: what dresses it ---")
	var layer := PixelUi.build(true, true, true, true, true, true, true)
	if layer == null:
		print("A: PixelUi.build returned null -- the pack is not unpacked")
		print("")
		return
	root.add_child(layer)
	_diagnose(layer)
	var named := {
		"character sheet": layer.panel, "combat readout": layer.readout,
		"play": layer.play, "answer": layer.answer,
		"dialogue": layer.dialogue, "trade": layer.trade,
		"territory": layer.territory, "legend": layer.legend,
	}
	print("panel                controls  pack-dressed  engine-default  pack-font  default-font")
	var total_default := 0
	var offenders := PackedStringArray()
	for label in named:
		var panel: Control = named[label]
		if panel == null:
			print("%-20s MISSING -- PixelUi.build did not make one" % label)
			continue
		var tally := {"controls": 0, "pack_box": 0, "default_box": 0,
			"pack_font": 0, "default_font": 0}
		_walk(panel, tally, offenders)
		total_default += int(tally["default_box"]) + int(tally["default_font"])
		print("%-20s %8d  %12d  %14d  %9d  %12d" % [
			label, tally["controls"], tally["pack_box"], tally["default_box"],
			tally["pack_font"], tally["default_font"],
		])
	print("")
	print("theme on the frame:  %s" % ("SproutTheme.build()" if layer._frame.theme != null else "none"))
	print("engine-default draws: %d" % total_default)
	for line in offenders:
		print("  " + line)
	print("")


## One Control and everything under it: what its stylebox and its font are.
##
## A Control that draws no background resolves no stylebox, which is not a
## fallback to the engine's look -- it is a node that draws nothing. So the tally
## counts three states rather than two: dressed by the pack, dressed by the
## engine, and drawing no box at all.
func _walk(node: Node, tally: Dictionary, offenders: PackedStringArray) -> void:
	if node is Control:
		tally["controls"] = int(tally["controls"]) + 1
		var control := node as Control
		if control is PanelContainer or control is Panel or control is Button:
			var kind := "panel" if not (control is Button) else "normal"
			var type := control.get_class()
			var box := control.get_theme_stylebox(kind, type)
			var source := _stylebox_source(box, kind, type)
			if source == "pack":
				tally["pack_box"] = int(tally["pack_box"]) + 1
			elif source == "engine":
				tally["default_box"] = int(tally["default_box"]) + 1
				offenders.append("%s (%s) resolves the engine's own %s stylebox"
					% [control.name, type, kind])
		if control is Label or control is Button or control is RichTextLabel:
			var font := control.get_theme_font("font")
			var from := _font_source(font)
			if from == "pack":
				tally["pack_font"] = int(tally["pack_font"]) + 1
			else:
				tally["default_font"] = int(tally["default_font"]) + 1
				offenders.append("%s (%s) is drawn with the %s font, '%s'" % [
					control.name, control.get_class(), from,
					"null" if font == null else font.get_font_name(),
				])
	for child in node.get_children():
		_walk(child, tally, offenders)


## Where a stylebox came from: the pack's own art, the engine's default theme, or
## nothing at all.
func _stylebox_source(box: StyleBox, kind: String, type: String) -> String:
	if box == null:
		return "none"
	if box == _default_theme.get_stylebox(kind, type):
		return "engine"
	if box is StyleBoxTexture:
		var texture := (box as StyleBoxTexture).texture
		if texture is AtlasTexture:
			var atlas: Texture2D = (texture as AtlasTexture).atlas
			if atlas != null and atlas.resource_path.begins_with(SproutPack.ROOT):
				return "pack"
		if texture != null and texture.resource_path.begins_with(SproutPack.ROOT):
			return "pack"
		return "other-texture"
	if box is StyleBoxEmpty:
		return "none"
	return "other"


## Where a font came from. The pack's font is loaded from the pack's own file, so
## the file it was read out of is the whole answer.
func _font_source(font: Font) -> String:
	if font == null:
		return "null"
	if font is FontFile:
		var file := font as FontFile
		# FontFile.load_dynamic_font leaves no resource_path, so the name the
		# face carries is what identifies it. The pack's face is
		# pixelFont-7-8x14-sproutLands.
		var name := file.get_font_name()
		if name == _pack_font_name():
			return "pack"
		return "font '%s'" % name
	if font == ThemeDB.fallback_font:
		return "engine"
	return "engine-ish (%s)" % font.get_class()


var _pack_name_cache := ""

func _pack_font_name() -> String:
	if _pack_name_cache != "":
		return _pack_name_cache
	var font := SproutTheme.pack_font()
	_pack_name_cache = "" if font == null else font.get_font_name()
	return _pack_name_cache


## Whether the theme the frame carries is the theme its labels actually resolve.
## Printed because a probe that walked the tree at the wrong moment would report
## the engine's own font everywhere and look like a finding.
func _diagnose(layer: PixelUi) -> void:
	var frame: MarginContainer = layer._frame
	print("frame in tree: %s; theme default_font: %s; Label font in theme: %s" % [
		frame.is_inside_tree(),
		"null" if frame.theme.default_font == null else frame.theme.default_font.get_font_name(),
		"null" if frame.theme.get_font("font", "Label") == null
			else frame.theme.get_font("font", "Label").get_font_name(),
	])
	var first := _first_label(layer)
	if first == null:
		print("no label found at all")
		return
	print("first label '%s': in tree %s, owner-resolved font %s, explicit-type font %s" % [
		first.text, first.is_inside_tree(),
		"null" if first.get_theme_font("font") == null else first.get_theme_font("font").get_font_name(),
		"null" if first.get_theme_font("font", "Label") == null
			else first.get_theme_font("font", "Label").get_font_name(),
	])
	print("theme_owner chain: %s" % str(first.get_theme_font("font") == frame.theme.default_font))


func _first_label(node: Node) -> Label:
	if node is Label:
		return node as Label
	for child in node.get_children():
		var found := _first_label(child)
		if found != null:
			return found
	return null


# --- B: the font ------------------------------------------------------------

func _section_b_font() -> void:
	print("--- B. the pack's font, read off the object the interface holds ---")
	var font := SproutTheme.build_font()
	if font == null:
		print("B: SproutTheme.build_font() returned null")
		print("")
		return
	print("face                 %s" % font.get_font_name())
	print("antialiasing         %d (NONE=%d)" % [
		font.antialiasing, TextServer.FONT_ANTIALIASING_NONE])
	print("hinting              %d (NONE=%d)" % [
		font.hinting, TextServer.HINTING_NONE])
	print("subpixel positioning %d (DISABLED=%d)" % [
		font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED])
	print("oversampling         %.2f" % font.oversampling)
	print("mipmaps / msdf       %s / %s" % [
		font.generate_mipmaps, font.multichannel_signed_distance_field])
	print("system fallback      %s" % font.allow_system_fallback)
	print("font cell            %d px; sizes asked for %s" % [
		SproutPack.FONT_CELL, str(SproutTheme.SIZES)])
	for size in SproutTheme.SIZES:
		print("  size %-3d is %s multiple of the %d-pixel cell" % [
			size, "a whole" if int(size) % SproutPack.FONT_CELL == 0 else "NOT a whole",
			SproutPack.FONT_CELL,
		])
	print("art cell             %d px" % SproutPack.CELL)
	print("2D texture filter    rendering/textures/canvas_textures/"
		+ "default_texture_filter = %s (0 = nearest)" % ProjectSettings.get_setting(
			"rendering/textures/canvas_textures/default_texture_filter"))
	print("")


# --- C: every texture, measured --------------------------------------------

func _section_c_textures() -> void:
	print("--- C. every texture the interface draws, measured against the 16-pixel cell ---")
	var cell := SproutPack.CELL
	var wrong := PackedStringArray()

	print("the pack's own regions (file, rectangle, size):")
	for entry in [
		["frame", SproutPack.SHEET, SproutPack.FRAME],
		["button idle", SproutPack.BUTTONS, SproutPack.BUTTON_IDLE],
		["button down", SproutPack.BUTTONS, SproutPack.BUTTON_DOWN],
		["button hover", SproutPack.BUTTONS, SproutPack.BUTTON_HOVER],
		["slot full", SproutPack.SLOTS, SproutPack.SLOT_FULL],
		["slot empty", SproutPack.SLOTS, SproutPack.SLOT_EMPTY],
		["heart full", SproutPack.HEARTS, SproutPack.HEART_FULL],
		["heart half", SproutPack.HEARTS, SproutPack.HEART_HALF],
		["heart empty", SproutPack.HEARTS, SproutPack.HEART_EMPTY],
	]:
		var rect: Rect2i = entry[2]
		var cut := SproutPack.region(String(entry[1]), rect)
		print("  %-13s %-40s %s -> %dx%d" % [
			entry[0], String(entry[1]).replace(SproutPack.ROOT, ""), str(rect),
			0 if cut == null else cut.get_width(), 0 if cut == null else cut.get_height(),
		])

	print("the pack's generic icons used by the panels (16x16 by construction):")
	for entry in [
		["star", SproutPack.ICON_STAR], ["crown -- territory", SproutPack.ICON_CROWN],
		["coin", SproutPack.ICON_COIN], ["tick -- usable now", SproutPack.ICON_TICK],
		["bar -- cooling down", SproutPack.ICON_BAR],
		["mark -- whose turn", SproutPack.ICON_MARK],
		["dash -- waiting", SproutPack.ICON_DASH],
	]:
		var icon := SproutPack.icon(entry[1] as Vector2i)
		var size := Vector2i.ZERO if icon == null else Vector2i(icon.get_width(), icon.get_height())
		print("  %-24s at column,row %s -> %dx%d%s" % [
			entry[0], str(entry[1]), size.x, size.y,
			"" if size == Vector2i(cell, cell) else "   <-- NOT 16x16",
		])
		if size != Vector2i(cell, cell):
			wrong.append("pack icon %s is %s" % [entry[0], str(size)])

	print("the icons drawn here, one per name in PixelIcons.ART:")
	var abilities := Ability.ALL
	var minions := Minion.KINDS
	for name in PixelIcons.names():
		var drawn := PixelIcons.of(name)
		var size := Vector2i.ZERO if drawn == null else Vector2i(drawn.get_width(), drawn.get_height())
		var what := "other"
		if Array(abilities).has(name):
			what = "ability score"
		elif Array(minions).has(name):
			what = "minion type"
		print("  %-12s %-14s %dx%d%s" % [
			name, what, size.x, size.y,
			"" if size == Vector2i(cell, cell) else "   <-- NOT 16x16",
		])
		if size != Vector2i(cell, cell):
			wrong.append("drawn icon %s is %s" % [name, str(size)])
	print("  ability scores covered: %d of %d %s" % [
		_covered(abilities, PixelIcons.names()), abilities.size(), str(abilities)])
	print("  minion types covered:   %d of %d %s" % [
		_covered(minions, PixelIcons.names()), minions.size(), str(minions)])

	print("the effect sprites the readout draws a blow with:")
	for tag in AssetTags.EFFECT_SPRITES:
		var sprite := EffectArt.sprite_of(tag)
		var size := Vector2i.ZERO if sprite == null else Vector2i(sprite.get_width(), sprite.get_height())
		print("  %-12s %dx%d%s" % [tag, size.x, size.y,
			"" if size == Vector2i(cell, cell) else "   <-- NOT 16x16"])
		if size != Vector2i(cell, cell):
			wrong.append("effect sprite %s is %s" % [tag, str(size)])
	print("  EffectArt.CELL=%d, SproutPack.CELL=%d" % [EffectArt.CELL, cell])

	print("the attack-pattern glyphs, one per distinct shape in the weapon catalogue:")
	var shapes := {}
	for shape in Weapon.catalogue() + Weapon.composed():
		for index in shape.attack_count():
			var one := shape.attack_at(index)
			var offsets := Array(one.offsets)
			var key := "%s/%s" % [shape.weapon_name, one.attack_name]
			shapes[key] = offsets
	var counted := 0
	var patterns_wrong := 0
	for key in shapes:
		var glyph := PixelIcons.pattern(shapes[key])
		var size := Vector2i.ZERO if glyph == null else Vector2i(glyph.get_width(), glyph.get_height())
		counted += 1
		if size != Vector2i(cell, cell):
			wrong.append("pattern glyph %s is %s" % [key, str(size)])
			patterns_wrong += 1
		if counted <= 6 or size != Vector2i(cell, cell):
			print("  %-28s %d cells -> %dx%d%s" % [
				key, (shapes[key] as Array).size(), size.x, size.y,
				"" if size == Vector2i(cell, cell) else "   <-- NOT 16x16"])
	print("  %d attack patterns measured, %d off the %d-pixel cell" % [
		counted, patterns_wrong, cell])

	print("")
	print("textures off the 16-pixel cell: %d%s" % [
		wrong.size(), "" if wrong.is_empty() else " -> " + ", ".join(wrong)])
	print("")


func _covered(wanted: Variant, have: PackedStringArray) -> int:
	var found := 0
	for one in wanted:
		if Array(have).has(String(one)):
			found += 1
	return found


# --- D: the resource cache, with a control ----------------------------------

func _section_d_cache() -> void:
	print("--- D. the resource cache, asked before and after the art is loaded ---")
	print("This is the same ResourceLoader.has_cached call bin/headless_main.gd")
	print("counts a headless run by. Asked twice, so the answer 'loaded=0' can be")
	print("told apart from an answer that is always no.")
	print("")
	print("%-24s before  after" % "the interface's own art")
	var before := PackedStringArray()
	for path in SproutPack.FILES:
		before.append("%s" % ResourceLoader.has_cached(path))
	# Load every one of them the way the interface does: the textures through the
	# pack's own table, the font through the theme.
	SproutPack.region(SproutPack.SHEET, SproutPack.FRAME)
	SproutPack.region(SproutPack.BUTTONS, SproutPack.BUTTON_IDLE)
	SproutPack.region(SproutPack.SLOTS, SproutPack.SLOT_FULL)
	SproutPack.region(SproutPack.HEARTS, SproutPack.HEART_FULL)
	SproutPack.icon(SproutPack.ICON_STAR)
	var font := load(SproutPack.FONT)
	var index := 0
	for path in SproutPack.FILES:
		print("%-24s %-7s %s" % [
			path.replace(SproutPack.ROOT, ""), before[index],
			ResourceLoader.has_cached(path)])
		index += 1
	print("")
	print("the font resource loaded as: %s" % ("null" if font == null else font.get_class()))
	print("")


# --- E: what the interface rule covers --------------------------------------

func _section_e_coverage() -> void:
	print("--- E. which render-layer files name an interface, and whether the rule covers them ---")
	print("LayerCheck.UI_DIR = %s" % LayerCheck.UI_DIR)
	print("LayerCheck.UI_TABLE = %s" % LayerCheck.UI_TABLE)
	print("")
	# The vocabulary the simulation is forbidden, used here the other way round:
	# a render-layer file naming one of these is a file the interface lives in.
	var vocabulary := [
		"CanvasLayer", "Control", "Theme", "StyleBox", "StyleBoxTexture",
		"FontFile", "Label", "Button", "PanelContainer", "TextureRect",
		"NinePatchRect", "VBoxContainer", "HBoxContainer", "GridContainer",
		"MarginContainer",
	]
	var files := _files_under("res://render")
	print("%-44s %-9s %s" % ["file under res://render", "in UI_DIR", "interface words it names"])
	var outside := PackedStringArray()
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		var code := PackedStringArray()
		for line in text.split("\n"):
			var at := line.find("#")
			code.append(line if at == -1 else line.substr(0, at))
		var body := "\n".join(code)
		var named := PackedStringArray()
		for word in vocabulary:
			if _word_in(body, word):
				named.append(word)
		if named.is_empty():
			continue
		var inside := path.begins_with(LayerCheck.UI_DIR + "/")
		if not inside:
			outside.append(path)
		print("%-44s %-9s %s" % [
			path.replace("res://", ""), "yes" if inside else "NO",
			", ".join(named.slice(0, 6)) + ("" if named.size() <= 6 else " +%d" % (named.size() - 6)),
		])
	print("")
	print("interface files the UI rule does not scan: %d%s" % [
		outside.size(), "" if outside.is_empty() else " -> " + ", ".join(outside)])
	# The two things the rule is about, asked of the files it does not scan: does
	# one of them name a file on disk, or reach for the engine's own look?
	for path in outside:
		var text := FileAccess.get_file_as_string(path)
		var lines := text.split("\n")
		for index in lines.size():
			var raw: String = lines[index]
			var at := raw.find("#")
			var code := raw if at == -1 else raw.substr(0, at)
			if code.strip_edges().is_empty():
				continue
			var hit := LayerCheck.first_ui_match(code, "")
			if hit != "":
				print("  %s:%d would fail the UI rule on '%s' -> %s" % [
					path, index + 1, hit, raw.strip_edges()])
	print("")


func _word_in(text: String, word: String) -> bool:
	var from := 0
	while true:
		var at := text.find(word, from)
		if at == -1:
			return false
		var before_ok := at == 0 or not _word_char(text[at - 1])
		var after := at + word.length()
		var after_ok := after >= text.length() or not _word_char(text[after])
		if before_ok and after_ok:
			return true
		from = at + 1
	return false


func _word_char(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() \
		or (character >= "0" and character <= "9")


func _files_under(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			found.append_array(_files_under(full))
		elif entry.get_extension() in ["gd", "tscn", "tres"]:
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


# --- F: the letters that can still reach a label ---------------------------

## Which characters the pack's font has no glyph for, and which of those the
## interface folds away before they are drawn.
##
## This is the one way the pixel seam can still be lost on a real sentence, and
## reports/dialogue-trade.md section 8 measured it happening: a character the
## font has no glyph for is drawn by the engine as its own hex box, whose edges
## do not fall on the interface's grid. `SproutPack.FONT_SUBSTITUTES` is the
## mechanism that closes it, so the question worth asking is not "is there a
## hole" but "which characters are still through it".
##
## The list is what a language model writes: the typography an English sentence
## picks up when a model rather than a programmer wrote it, plus the five the
## table already covers, as a control.
func _section_f_glyphs() -> void:
	print("--- F. characters a sentence can carry, against the pack's own glyph set ---")
	var font := SproutTheme.build_font()
	if font == null:
		print("F: no font")
		return
	var characters := {
		"\u2014": "em dash", "\u2013": "en dash", "\u2018": "left single quote",
		"\u2019": "right single quote / apostrophe", "\u201c": "left double quote",
		"\u201d": "right double quote", "\u2026": "ellipsis",
		"\u00e9": "e acute", "\u00b0": "degree sign",
		# The five the table already folds away, as a control: each of these must
		# come out "substituted".
		"#": "hash", "_": "underscore", "[": "left bracket", "]": "right bracket",
		"\u00b7": "middle dot",
	}
	print("%-32s %-8s %-12s %s" % ["character", "glyph?", "folded away?", "what a label would draw"])
	var open_holes := PackedStringArray()
	for key in characters:
		var character := String(key)
		var code := character.unicode_at(0)
		var has := font.has_char(code)
		var folded: bool = SproutPack.drawable(character) != character
		var draws := "the pack's own glyph"
		if not has and not folded:
			draws = "the ENGINE'S OWN hex box, off the pixel grid"
			open_holes.append("%s (U+%04X)" % [characters[character], code])
		elif folded:
			draws = "'%s' instead" % SproutPack.drawable(character)
		print("%-32s %-8s %-12s %s" % [
			characters[character], "yes" if has else "no",
			"yes" if folded else "no", draws])
	print("")
	print("characters with no glyph and no substitute: %d%s" % [
		open_holes.size(),
		"" if open_holes.is_empty() else " -> " + ", ".join(open_holes)])
	print("FONT_SUBSTITUTES covers %d characters: %s" % [
		SproutPack.FONT_SUBSTITUTES.size(), str(SproutPack.FONT_SUBSTITUTES.keys())])
	print("")
