extends RefCounted
## The automated check that the layer split actually holds.
##
## The rule it enforces is one-directional: the render layer may read the
## simulation, the simulation may not know the render layer exists. It fails if
## any file under sim/ names a path in the render layer, or names one of the
## engine's presentation and scene-tree types -- which since the character-sheet
## panel landed includes the whole vocabulary of an interface: a CanvasLayer, a
## Control, a theme, a font, a widget.
##
## Two narrower rules live here too, both about the render layer rather than the
## simulation. `run_render()` says the shell may draw the fight and may hold none
## of it. `run_ui()` says the interface names its art in one table and never
## reaches for the engine's own theme or typeface.
##
## Comments are stripped before scanning, so prose like this can discuss the
## render layer without tripping the check; string literals are kept, so a path
## smuggled into a string is still caught.
class_name LayerCheck

## The directory whose contents must stay ignorant of everything below.
const SIM_DIR := "res://sim"

## Path fragments that mean "the render layer". Matched as plain substrings.
const FORBIDDEN_PATHS := ["res://render", "render/"]

## Engine types that only exist to put something on a screen or in a scene tree.
## Matched as whole words. Reaching for any of these inside sim/ means the split
## has started to leak, even if no render/ file is named.
const FORBIDDEN_SYMBOLS := [
	"Node", "Node2D", "Node3D", "CanvasItem", "SceneTree", "Viewport", "Window",
	"MeshInstance3D", "Camera3D", "Camera2D", "Sprite2D", "Sprite3D",
	"DirectionalLight3D", "OmniLight3D", "WorldEnvironment", "Environment",
	"Mesh", "SphereMesh", "PlaneMesh", "Material", "StandardMaterial3D",
	"Texture", "Texture2D", "Shader", "ShaderMaterial", "RenderingServer",
	"DisplayServer", "InputEvent", "Input", "get_tree", "get_viewport",
	"add_child", "queue_redraw", "_process", "_physics_process", "_draw",
	# The interface's own vocabulary, added when the character-sheet panel
	# landed. Everything a player-facing panel is made of: the layer it lives on,
	# the base class of every widget, the widgets themselves, the theme that
	# dresses them, and the type of the art and the letters they are drawn with.
	# A simulation that names one of these has started to hold what it looks
	# like, which is exactly the same mistake as naming a model.
	"CanvasLayer", "Control", "Theme", "ThemeDB", "StyleBox", "StyleBoxTexture",
	"StyleBoxFlat", "StyleBoxEmpty", "Font", "FontFile", "SystemFont",
	"TextServer", "Label", "RichTextLabel", "Button", "BaseButton", "Panel",
	"PanelContainer", "TextureRect", "NinePatchRect", "ColorRect", "TextureButton",
	"VBoxContainer", "HBoxContainer", "GridContainer", "MarginContainer",
	"CenterContainer", "ScrollContainer", "Image", "ImageTexture", "AtlasTexture",
]


## The directory that draws the simulation and must hold none of it.
const RENDER_DIR := "res://render"

## The whole vocabulary of the combat simulation. Naming any of these under
## render/ means the shell has started to hold a piece of the fight rather than
## to read one.
##
## Two names of the combat layer are deliberately *not* here, and both are
## read-only handles:
##
##   * `CombatBoard` -- the lattice the shell draws as an overlay. What it is
##     handed is a detached copy, exactly like a chunk's geometry.
##   * nothing else. Every fact about the fight itself -- who is standing where,
##     which way they are turned, whether one is hurt -- reaches the shell inside
##     the snapshot, as plain numbers and tags.
##
## Which is why the shell asks for a *named* scenario rather than calling into
## the scenario file: `Simulation.begin_scenario("encounter")` names a string,
## and the string is the whole of what the render layer knows about combat.
const FORBIDDEN_IN_RENDER := [
	"CombatMatch", "CombatantRoster", "CombatPolicy", "CombatResolution",
	"CombatSnap", "Encounter", "ScriptedEncounter", "ScriptedMatch",
	"PieceMap", "LegalMoves", "MoveGrant", "PieceGeometry", "BoardSketch",
	"Combatant", "Commander", "Minion", "Piece", "Damage", "Attack",
	"Weapon", "Armour",
]


## The directory the player-facing interface lives in.
##
## It is under the render layer, so `run_render()` already sweeps it for the
## combat vocabulary along with everything else drawn. This is the rule that is
## only about an interface: the pack it is drawn from is a table of paths in one
## file, and no widget anywhere reaches for the engine's own theme or font.
const UI_DIR := "res://render/ui"

## The one file under `UI_DIR` allowed to name a file on disk. Everything else
## asks it, so repointing the interface at a different pack -- or finding it
## missing -- is one file rather than a search.
const UI_TABLE := "res://render/ui/sprout_pack.gd"

## Path shapes that mean "a file on disk", matched inside the interface's source.
## The same shapes `AssetCheck` looks for under sim/, for the same reason: a path
## is how art gets named, and the interface must name its art in one place.
const UI_ASSET_PATHS := ["res://assets", "assets/"]

## The ways the engine's own look gets in. A pixel interface that falls back to
## the engine's grey theme or its default typeface is the failure this rule is
## about, and it is a silent one -- a Control with no style still draws.
const UI_DEFAULTS := [
	"ThemeDB", "SystemFont", "get_theme_default_font",
	"get_theme_default_font_size", "get_theme_default_base_scale",
]


## Returns a list of violations. An empty list means the split holds.
## Each violation is {"file": String, "line": int, "match": String, "text": String}.
static func run() -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	for path in _files_under(SIM_DIR):
		violations.append_array(_scan_file(path))
	return violations


## The rule in the other direction, for one layer only: the render shell may
## draw the fight and may not hold it.
##
## The simulation rule above is about a whole directory not knowing another
## exists. This one is narrower and is about state: the shell reads the fight
## through `SimWorld.snapshot()` and through a detached `CombatBoard`, and there
## is nothing else of the combat layer it is allowed to name. A violation is the
## render layer starting to keep a second copy of the fight.
static func run_render() -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	for path in _files_under(RENDER_DIR):
		violations.append_array(_scan_render_file(path))
	return violations


## The interface's own rule: one table names the art, and nothing reaches for the
## engine's default look.
static func run_ui() -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	for path in _files_under(UI_DIR):
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty() and FileAccess.get_open_error() != OK:
			push_error("LayerCheck: cannot read %s" % path)
			continue
		var lines := text.split("\n")
		for index in lines.size():
			var raw: String = lines[index]
			var code := _strip_comment(raw)
			if code.strip_edges().is_empty():
				continue
			var hit := first_ui_match(code, path)
			if hit != "":
				violations.append({
					"file": path, "line": index + 1, "match": hit,
					"text": raw.strip_edges(),
				})
	return violations


## The first thing a line of interface source does that it may not, or "".
##
## `in_file` decides only one of the two rules: the table is allowed to name the
## pack's files, because being the one place that does is what it is for.
static func first_ui_match(code: String, in_file: String = "") -> String:
	for symbol in UI_DEFAULTS:
		if _contains_word(code, symbol):
			return symbol
	if in_file == UI_TABLE:
		return ""
	for fragment in UI_ASSET_PATHS:
		if code.contains(fragment):
			return fragment
	return ""


## Human-readable one-line summary of an interface violation.
static func format_ui_violation(violation: Dictionary) -> String:
	return "%s:%d reaches past %s via '%s'  ->  %s" % [
		violation["file"], violation["line"], UI_TABLE.get_file(),
		violation["match"], violation["text"],
	]


## Human-readable one-line summary of a render-side violation.
static func format_render_violation(violation: Dictionary) -> String:
	return "%s:%d holds a piece of the combat simulation via '%s'  ->  %s" % [
		violation["file"], violation["line"], violation["match"], violation["text"],
	]


static func _scan_render_file(path: String) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		push_error("LayerCheck: cannot read %s" % path)
		return violations
	var lines := text.split("\n")
	for index in lines.size():
		var raw: String = lines[index]
		var code := _strip_comment(raw)
		if code.strip_edges().is_empty():
			continue
		var hit := first_combat_match(code)
		if hit != "":
			violations.append({
				"file": path, "line": index + 1, "match": hit,
				"text": raw.strip_edges(),
			})
	return violations


## The first combat name a line of render-layer source uses, or "".
static func first_combat_match(code: String) -> String:
	for symbol in FORBIDDEN_IN_RENDER:
		if _contains_word(code, symbol):
			return symbol
	return ""


## Human-readable one-line summary of a violation, for test output.
static func format_violation(violation: Dictionary) -> String:
	return "%s:%d references the render layer via '%s'  ->  %s" % [
		violation["file"], violation["line"], violation["match"], violation["text"],
	]


static func _files_under(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("LayerCheck: cannot open %s" % dir_path)
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


static func _scan_file(path: String) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		push_error("LayerCheck: cannot read %s" % path)
		return violations

	var lines := text.split("\n")
	for index in lines.size():
		var raw: String = lines[index]
		var code := _strip_comment(raw)
		if code.strip_edges().is_empty():
			continue
		var hit := _first_match(code)
		if hit != "":
			violations.append({
				"file": path,
				"line": index + 1,
				"match": hit,
				"text": raw.strip_edges(),
			})
	return violations


static func _first_match(code: String) -> String:
	for fragment in FORBIDDEN_PATHS:
		if code.contains(fragment):
			return fragment
	for symbol in FORBIDDEN_SYMBOLS:
		if _contains_word(code, symbol):
			return symbol
	return ""


## Whole-word containment, so that a symbol like "Mesh" does not match inside an
## unrelated identifier such as "MeshlessThing" or "my_mesh".
static func _contains_word(code: String, word: String) -> bool:
	var from := 0
	while true:
		var at := code.find(word, from)
		if at == -1:
			return false
		var before_ok := at == 0 or not _is_word_char(code[at - 1])
		var after := at + word.length()
		var after_ok := after >= code.length() or not _is_word_char(code[after])
		if before_ok and after_ok:
			return true
		from = at + 1
	return false


static func _is_word_char(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() \
		or (character >= "0" and character <= "9")


static func _strip_comment(line: String) -> String:
	var at := line.find("#")
	if at == -1:
		return line
	return line.substr(0, at)
