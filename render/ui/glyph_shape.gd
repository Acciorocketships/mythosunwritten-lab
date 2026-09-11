extends RefCounted
## What one glyph of the interface's font actually looks like at the size the
## game draws it, and the one question a reader's eye asks of a digit.
##
## The interface is drawn with the pack's pixel font at a nominal size, and the
## canvas then magnifies that bitmap by a whole number
## (`render/ui/pixel_ui.gd`). So what a person actually reads is the glyph as the
## engine rasterised it at its nominal size -- not the outline in the font file,
## and not the design the pack's artist drew on paper. Those three differ: the
## pack's font is drawn on an 8x14 cell, and at nominal size 14 the engine
## rasterises it into six pixels by eleven. A claim about legibility that reads
## the design instead of the raster is a claim about the wrong picture.
##
## This reads the raster. `of()` hands back the glyph exactly as it sits in the
## font's own glyph cache, one string per row, and the rest are the measurements
## made on it.
##
## ## Counters, and why they are the measure for a digit
##
## A counter is an enclosed hole -- the space inside an `O`, the two spaces
## inside an `8`. Counting holes is how a reader tells one round glyph from
## another before reading any of its curves, and it is the difference that
## survives being small: at the size this interface ships at, an `8` and a
## slashed `0` are five pixels apart out of a hundred and four, which is nothing,
## while "one hole" and "two holes" is the whole of what a person sees. So the
## test that keeps the interface's numerals legible asks how many holes each
## digit has, not how many pixels separate them.
class_name GlyphShape


## One glyph as the engine rasterised it, "#" where it is drawn and "." where it
## is not, one string per row. Empty when the font has no such glyph.
##
## The rectangle includes whatever blank border the rasteriser left around the
## ink, which is what makes two glyphs of one font at one size directly
## comparable -- and what gives `counters()` an outside to flood from.
static func of(font: FontFile, size: int, character: String) -> PackedStringArray:
	var rows := PackedStringArray()
	if font == null or character.is_empty():
		return rows
	var key := Vector2i(size, 0)
	var glyph := font.get_glyph_index(size, character.unicode_at(0), 0)
	# Asking where a glyph sits in the cache is what puts it there; a font that
	# has drawn nothing yet has an empty cache and no rectangle to hand back.
	var at := font.get_glyph_uv_rect(0, key, glyph)
	if at.size.x <= 0.0 or at.size.y <= 0.0:
		return rows
	var sheet := font.get_texture_image(
		0, key, font.get_glyph_texture_idx(0, key, glyph))
	if sheet == null:
		return rows
	for y in int(at.size.y):
		var row := ""
		for x in int(at.size.x):
			var pixel := sheet.get_pixel(
				int(at.position.x) + x, int(at.position.y) + y)
			row += "#" if pixel.a > 0.5 else "."
		rows.append(row)
	return rows


## How many enclosed holes the glyph has: one for an `O`, two for an `8`, none
## for a `1`.
##
## The outside is whatever background reaches the rectangle's border, found by
## flooding inwards; every run of background that flood did not reach is a hole.
## Holes are counted four-connected, which is the same rule a person's eye uses
## on a pixel grid -- a diagonal touch closes a counter visually and it closes it
## here.
static func counters(shape: PackedStringArray) -> int:
	if shape.is_empty():
		return 0
	var wide := shape[0].length()
	var tall := shape.size()
	var seen := {}
	var stack: Array[Vector2i] = []
	for x in wide:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, tall - 1))
	for y in tall:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(wide - 1, y))
	_flood(shape, seen, stack, wide, tall)
	var holes := 0
	for y in tall:
		for x in wide:
			if seen.has(Vector2i(x, y)) or shape[y][x] == "#":
				continue
			holes += 1
			_flood(shape, seen, [Vector2i(x, y)] as Array[Vector2i], wide, tall)
	return holes


## How many pixels two glyphs of the same font and size disagree on, or -1 when
## they are not the same shape of rectangle and so cannot be compared at all.
static func differing(one: PackedStringArray, other: PackedStringArray) -> int:
	if one.is_empty() or other.is_empty() or one.size() != other.size() \
			or one[0].length() != other[0].length():
		return -1
	var apart := 0
	for y in one.size():
		for x in one[0].length():
			if one[y][x] != other[y][x]:
				apart += 1
	return apart


## How many pixels the glyph is drawn in.
static func ink(shape: PackedStringArray) -> int:
	var lit := 0
	for row in shape:
		lit += row.count("#")
	return lit


## Everything in `open` that is background, and everything background reachable
## from it, marked in `seen`.
static func _flood(
	shape: PackedStringArray, seen: Dictionary, open: Array[Vector2i],
	wide: int, tall: int
) -> void:
	while not open.is_empty():
		var at: Vector2i = open.pop_back()
		if at.x < 0 or at.y < 0 or at.x >= wide or at.y >= tall:
			continue
		if seen.has(at) or shape[at.y][at.x] == "#":
			continue
		seen[at] = true
		open.append(at + Vector2i(1, 0))
		open.append(at + Vector2i(-1, 0))
		open.append(at + Vector2i(0, 1))
		open.append(at + Vector2i(0, -1))
