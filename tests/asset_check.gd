extends RefCounted
## The automated check that generation names tags and never art.
##
## The layer check next door enforces that the simulation does not know the
## render layer exists. This one enforces the narrower rule the asset-tag
## indirection rests on: a file under sim/ may say *what* goes somewhere -- a
## "fir", a "bridge_wood" -- but never *which model that is*. The moment a
## generation file names a scene, a file path, a resource loader or an asset
## pack, swapping packs stops being an edit to one table, which is the entire
## point of the indirection.
##
## Two kinds of naming are caught, and they are looked for in different places:
##
##   * paths and file names -- looked for inside string literals only, because
##     that is the only place a path can be. Looking for them in code as well
##     would flag ordinary calls: BiomeCatalog.blend() is not a Blender file.
##   * loaders and pack names -- looked for in code, as whole words, because
##     preload and ResourceLoader are how a path gets used and KayKit is how a
##     pack gets named.
##
## Comments are ignored, so this docstring can name preload and KayKit without
## failing the project. String literals are not, so a path smuggled into one is
## still caught.
class_name AssetCheck

## The directory whose contents must name tags and nothing else.
const SIM_DIR := "res://sim"

## File extensions that only ever appear at the end of an asset. Matched inside
## string literals, and only when nothing word-like follows, so that ".res" does
## not fire on ".resource".
const ASSET_EXTENSIONS := [
	".tscn", ".scn", ".glb", ".gltf", ".obj", ".fbx", ".dae", ".blend",
	".png", ".jpg", ".jpeg", ".webp", ".svg", ".exr", ".hdr",
	".tres", ".res", ".material", ".mesh", ".mtl", ".shader", ".gdshader",
	# Type is art too. Added when the interface landed: a font is a file the
	# simulation must no more name than it names a model.
	".ttf", ".otf", ".woff", ".woff2", ".fnt",
]

## Path shapes that mean "a file on disk". Matched inside string literals as
## plain substrings.
const ASSET_PATHS := [
	"res://", "user://", "assets/", "models/", "meshes/", "textures/",
	"materials/", "art/", "addons/", "packs/", "fonts/", "sprites/", "ui/",
]

## The ways a path turns into a resource, and the names of the render layer's
## own asset machinery. Matched in code, as whole words.
const ASSET_SYMBOLS := [
	"preload", "load", "ResourceLoader", "ResourcePreloader", "PackedScene",
	"instantiate", "AssetLibrary", "AssetVisual",
]

## Asset packs by name. Matched case-insensitively anywhere in code, because a
## pack gets named as an identifier as often as as a string.
const PACK_NAMES := [
	"kaykit", "kay_kit", "kaylousberg", "lousberg",
	"mistage", "synty", "quaternius", "polyperfect",
	"sproutlands", "sprout_lands", "cupnooble", "cup_nooble",
]


## Returns a list of violations. An empty list means generation names only tags.
## Each violation is {"file": String, "line": int, "match": String,
## "reason": String, "text": String}.
static func run() -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	for path in _files_under(SIM_DIR):
		violations.append_array(_scan_file(path))
	return violations


## Human-readable one-line summary of a violation, for test output.
static func format_violation(violation: Dictionary) -> String:
	return "%s:%d names %s via '%s'  ->  %s" % [
		violation["file"], violation["line"], violation["reason"],
		violation["match"], violation["text"],
	]


static func _files_under(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("AssetCheck: cannot open %s" % dir_path)
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
		push_error("AssetCheck: cannot read %s" % path)
		return violations

	var lines := text.split("\n")
	for index in lines.size():
		var raw: String = lines[index]
		var hit := first_match(raw)
		if hit.is_empty():
			continue
		violations.append({
			"file": path,
			"line": index + 1,
			"match": hit["match"],
			"reason": hit["reason"],
			"text": raw.strip_edges(),
		})
	return violations


## The first thing wrong with one line of source, as {"match", "reason"}, or an
## empty dictionary for a line that names no art. Public so the suite can
## exercise the rules on lines that do not exist on disk.
static func first_match(line: String) -> Dictionary:
	var split := split_code_and_strings(line)
	var code: String = split["code"]

	for name in PACK_NAMES:
		if code.to_lower().contains(name):
			return {"match": name, "reason": "an asset pack"}
	for symbol in ASSET_SYMBOLS:
		if _contains_word(code, symbol):
			return {"match": symbol, "reason": "a resource loader"}

	for literal in split["strings"]:
		for fragment in ASSET_PATHS:
			if literal.contains(fragment):
				return {"match": fragment, "reason": "a file path"}
		for extension in ASSET_EXTENSIONS:
			if _ends_a_word(literal, extension):
				return {"match": extension, "reason": "an asset file"}
	return {}


## One line of source, separated into the code outside its string literals and
## the contents of the literals themselves. A comment ends the line, unless the
## '#' is inside a string.
##
## Returns {"code": String, "strings": PackedStringArray}.
static func split_code_and_strings(line: String) -> Dictionary:
	var code := ""
	var literals := PackedStringArray()
	var current := ""
	var quote := ""
	var index := 0
	while index < line.length():
		var character := line[index]
		if quote.is_empty():
			if character == "#":
				break
			if character == "\"" or character == "'":
				quote = character
				current = ""
			else:
				code += character
		else:
			if character == "\\" and index + 1 < line.length():
				current += line[index + 1]
				index += 2
				continue
			if character == quote:
				literals.append(current)
				quote = ""
			else:
				current += character
		index += 1
	if not quote.is_empty():
		# An unterminated literal: keep what there was of it rather than losing it.
		literals.append(current)
	return {"code": code, "strings": literals}


## Whole-word containment, so that "load" does not match inside "load_radius".
static func _contains_word(code: String, word: String) -> bool:
	var at := code.find(word)
	while at != -1:
		var before_ok := at == 0 or not _is_word_char(code[at - 1])
		var after := at + word.length()
		var after_ok := after >= code.length() or not _is_word_char(code[after])
		if before_ok and after_ok:
			return true
		at = code.find(word, at + 1)
	return false


## Whether a fragment appears with nothing word-like after it, which is what
## tells a file extension from the start of a longer word.
static func _ends_a_word(text: String, fragment: String) -> bool:
	var at := text.find(fragment)
	while at != -1:
		var after := at + fragment.length()
		if after >= text.length() or not _is_word_char(text[after]):
			return true
		at = text.find(fragment, at + 1)
	return false


static func _is_word_char(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() \
		or (character >= "0" and character <= "9")
