extends SceneTree
## Is the pixel interface actually made of whole pixels?
##
##   ./tools/measure_ui.sh
##   ./tools/measure_ui.sh --keep reports/assets/character-sheet.png
##
## The interface is 16-pixel art drawn over a 3D world at a whole-number scale
## with a nearest-neighbour filter. Every one of those three words can be got
## wrong quietly -- a bilinear filter, a fractional scale, an antialiased font --
## and each one shows up as the same thing in the end: colours that are in
## neither the pack's palette nor this project's, and edges that fall between the
## art's own pixels. So this measures both, on a real frame off the real shell.
##
## Two numbers, over the panel's interior (inside its frame, where every pixel is
## either pack art, drawn art or type):
##
##   * **off-palette share** -- the share of pixels whose colour is in neither
##     the pack's own files nor `PixelIcons`'s three. Antialiasing of any kind
##     invents in-between colours and this is what finds them. A crisp panel is
##     at or near zero.
##   * **off-grid share** -- of every place where the colour changes along a row
##     or a column, the share that does not fall on a multiple of the interface
##     scale. A whole-number scale puts every edge of the art on that grid by
##     construction; a fractional one, or a filter that blends, does not.
##
## It reads a saved frame off disk, so it needs no display of its own; the shell
## script beside it is what takes the frame.

const DEFAULT_FRAME := "res://reports/assets/character-sheet.png"


func _initialize() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	if options.has("error"):
		printerr(options["error"])
		printerr("usage: measure_ui.gd --frame PNG --at X Y --size W H --scale N")
		printerr("       measure_ui.gd --icons PNG [--icon-scale N]")
		printerr("       measure_ui.gd --effects PNG [--icon-scale N]")
		printerr("       measure_ui.gd --digits PNG [--icon-scale N]")
		quit(2)
		return

	if options["icons"] != "":
		_write_icon_sheet(options["icons"], options["icon_scale"])
		quit(0)
		return

	if options["effects"] != "":
		_write_effect_sheet(options["effects"], options["icon_scale"])
		quit(0)
		return

	if options["digits"] != "":
		_write_digit_strip(options["digits"], options["icon_scale"])
		quit(0)
		return

	var image := Image.load_from_file(options["frame"])
	if image == null:
		printerr("could not read the frame at %s" % options["frame"])
		quit(1)
		return

	var scale: int = options["scale"]
	var panel := Rect2i(
		Vector2i(options["at_x"], options["at_y"]),
		Vector2i(options["width"], options["height"])
	)
	# Inside the wooden frame, where there is no transparency for the world to
	# show through: the rails are nine art pixels and the corner knobs stand
	# proud of them, so a whole rail's width in is safely inside.
	var inset := SproutPack.FRAME_MARGIN * scale
	var inside := Rect2i(
		panel.position + Vector2i(inset, inset),
		panel.size - Vector2i(inset * 2, inset * 2)
	)
	if inside.size.x <= 0 or inside.size.y <= 0 \
			or not Rect2i(Vector2i.ZERO, image.get_size()).encloses(inside):
		printerr("the panel rectangle %s is not inside the %dx%d frame"
			% [str(panel), image.get_width(), image.get_height()])
		quit(1)
		return

	print("frame          %s (%dx%d)" % [
		options["frame"], image.get_width(), image.get_height()])
	print("panel          at %d,%d size %dx%d, interface scale %d" % [
		panel.position.x, panel.position.y, panel.size.x, panel.size.y, scale])
	print("measured       at %d,%d size %dx%d (inside the frame's rails)" % [
		inside.position.x, inside.position.y, inside.size.x, inside.size.y])

	var palette := _palette()
	print("palette        %d colours: the pack's own files plus PixelIcons' three"
		% palette.size())

	var seen := {}
	var off_palette := 0
	for y in inside.size.y:
		for x in inside.size.x:
			var key := _key(image.get_pixel(
				inside.position.x + x, inside.position.y + y))
			seen[key] = int(seen.get(key, 0)) + 1
			if not palette.has(key):
				off_palette += 1
	var pixels := inside.size.x * inside.size.y
	print("distinct       %d colours over %d pixels" % [seen.size(), pixels])
	print("off-palette    %d of %d = %.4f%%" % [
		off_palette, pixels, 100.0 * float(off_palette) / float(pixels)])

	var edges := _edges(image, inside, scale)
	print("edges          %d changes of colour along rows and columns" % edges["total"])
	print("off-grid       %d of %d = %.4f%%" % [
		edges["off"], edges["total"],
		0.0 if edges["total"] == 0 else 100.0 * float(edges["off"]) / float(edges["total"]),
	])

	print("")
	print("the ten commonest colours in it")
	var order := seen.keys()
	order.sort_custom(func(left: int, right: int) -> bool:
		return int(seen[left]) > int(seen[right]))
	for i in mini(10, order.size()):
		var key: int = order[i]
		print("  #%06x  %7d  %5.2f%%  %s" % [
			key, seen[key], 100.0 * float(seen[key]) / float(pixels),
			"pack" if palette.has(key) else "OFF-PALETTE",
		])
	quit(0)


## Lay the eleven drawn icons out side by side, magnified, so a reader can see
## what they are.
##
## Only this project's own art is drawn here -- the pack's icons are the pack's
## and are not written out of this repository, which its licence forbids even for
## a modified copy. What comes out is a picture of `PixelIcons.ART`, which is
## sixteen rows of source per icon and nothing else.
func _write_icon_sheet(path: String, at_scale: int) -> void:
	var names := PixelIcons.names()
	var cell := PixelIcons.CELL
	var pad := 4
	var sheet := Image.create_empty(
		names.size() * (cell + pad) + pad, cell + pad * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))
	for index in names.size():
		var icon := PixelIcons.of(names[index]).get_image()
		sheet.blit_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()),
			Vector2i(pad + index * (cell + pad), pad))
	if at_scale > 1:
		sheet.resize(sheet.get_width() * at_scale, sheet.get_height() * at_scale,
			Image.INTERPOLATE_NEAREST)
	var error := sheet.save_png(path)
	if error != OK:
		printerr("could not write %s (%d)" % [path, error])
		return
	print("wrote %s: %s at %dx" % [path, ", ".join(names), at_scale])


## Lay the second art table out as a picture: the six effect sprites along the
## top, and under each animation one row of the poses it puts a sprite through.
##
## This is what "the seven animations differ" looks like rather than what it
## reads like, and it is a still picture of a moving thing on purpose -- a strip
## of poses can be committed and looked at, where a recording of the panel cannot
## be either. Every pixel of it is this project's own art, so nothing here
## touches the pack's redistribution line.
##
## The sprite each animation is shown with is one that names it in the weapon
## catalogue, so the strip shows the pairs the simulation actually makes.
func _write_effect_sheet(path: String, at_scale: int) -> void:
	const POSES := 6
	var cell := EffectArt.CELL
	# Wide enough across that the furthest any of the seven travels -- the shot's
	# twenty-four pixels -- still lands inside its own cell, so the strip shows
	# the distance of a play and not only its shape; tight enough down that the
	# rows read as a table.
	var gap_x := 26
	var gap_y := 10

	# Which sprite the weapon catalogue actually pairs each animation with. The
	# strip below is drawn with the arrow instead, because a diagram of seven
	# motions should differ between rows only in the motion -- and because the
	# flail's burst, which is what the catalogue pairs `spin` with, is symmetric
	# under a quarter turn and would show a spin as nothing at all. The pairing
	# is printed rather than drawn.
	var paired := {}
	for shape in Weapon.catalogue() + Weapon.composed():
		for index in shape.attack_count():
			var one := shape.attack_at(index)
			if one.animation_tag != "" and not paired.has(one.animation_tag):
				paired[one.animation_tag] = one.sprite_tag

	var sprites := AssetTags.EFFECT_SPRITES
	var animations := AssetTags.ANIMATIONS
	var across := maxi(sprites.size(), POSES)
	var rows := 1 + animations.size()
	var sheet := Image.create_empty(
		across * (cell + gap_x) + gap_x, rows * (cell + gap_y) + gap_y,
		false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))
	var written := PackedStringArray()

	for index in sprites.size():
		var sprite := EffectArt.sprite_of(sprites[index]).get_image()
		sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()),
			Vector2i(gap_x + index * (cell + gap_x), gap_y))
	written.append("sprites: " + ", ".join(sprites))

	var art := EffectArt.sprite_of(AssetTags.EFFECT_ARROW).get_image()
	for row in animations.size():
		var animation: String = animations[row]
		var trace := PackedStringArray()
		for step in POSES:
			var pose := EffectArt.pose_of(animation, float(step) / float(POSES - 1))
			var offset: Vector2i = pose["offset"]
			var quarters := int(pose["quarter_turns"])
			trace.append("(%d,%d)x%d" % [offset.x, offset.y, quarters])
			var posed := _turned(art, quarters)
			# The offset is in whole art pixels, applied as it is and clamped
			# only at the edge of the cell's own padding.
			var at := Vector2i(
				gap_x + step * (cell + gap_x) + clampi(offset.x, -gap_x, gap_x),
				(row + 1) * (cell + gap_y) + gap_y + clampi(offset.y, -gap_y, gap_y))
			sheet.blit_rect(posed, Rect2i(Vector2i.ZERO, posed.get_size()), at)
		written.append("%s (the catalogue pairs it with the %s): %s" % [
			animation, paired.get(animation, "-"), " ".join(trace),
		])

	if at_scale > 1:
		sheet.resize(sheet.get_width() * at_scale, sheet.get_height() * at_scale,
			Image.INTERPOLATE_NEAREST)
	var error := sheet.save_png(path)
	if error != OK:
		printerr("could not write %s (%d)" % [path, error])
		return
	print("wrote %s at %dx" % [path, at_scale])
	for line in written:
		print("  " + line)


## One image turned by whole quarter turns clockwise. Whole quarter turns only,
## because that is all `EffectArt.pose_of` ever asks for -- and it is the only
## turn that maps a square of pixels exactly onto itself.
static func _turned(source: Image, quarter_turns: int) -> Image:
	var turned := source.duplicate() as Image
	for _step in posmod(quarter_turns, 4):
		turned.rotate_90(CLOCKWISE)
	return turned


## Every colour the interface is allowed to be: every opaque colour in the pack's
## own files, plus the three `PixelIcons` draws with.
##
## Read out of the files rather than written down, so the answer is about the art
## that is actually installed. A colour the pack does not contain and this project
## did not draw can only have been invented while drawing, which is the whole
## question.
func _palette() -> Dictionary:
	var found := {}
	for path in [
		SproutPack.SHEET, SproutPack.BUTTONS, SproutPack.ICONS,
		SproutPack.HEARTS, SproutPack.SLOTS,
	]:
		var sheet: Texture2D = load(path)
		if sheet == null:
			continue
		var image := sheet.get_image()
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.5:
					found[_key(pixel)] = true
	for colour in [PixelIcons.EDGE, PixelIcons.SHADE, PixelIcons.LIT,
			SproutTheme.TEXT, SproutTheme.HEADING, SproutTheme.DIM, SproutTheme.SHADOW]:
		found[_key(colour)] = true
	return found


## Where the colour changes along every row and every column of the region, and
## how many of those places are not on the art's own grid.
func _edges(image: Image, inside: Rect2i, scale: int) -> Dictionary:
	var total := 0
	var off := 0
	for y in inside.size.y:
		var previous := _key(image.get_pixel(inside.position.x, inside.position.y + y))
		for x in range(1, inside.size.x):
			var here := _key(image.get_pixel(
				inside.position.x + x, inside.position.y + y))
			if here != previous:
				total += 1
				if x % scale != 0:
					off += 1
			previous = here
	for x in inside.size.x:
		var previous := _key(image.get_pixel(inside.position.x + x, inside.position.y))
		for y in range(1, inside.size.y):
			var here := _key(image.get_pixel(
				inside.position.x + x, inside.position.y + y))
			if here != previous:
				total += 1
				if y % scale != 0:
					off += 1
			previous = here
	return {"total": total, "off": off}


## One colour as one integer, so colours can be counted and compared exactly.
static func _key(colour: Color) -> int:
	return (colour.r8 << 16) | (colour.g8 << 8) | colour.b8


func _parse(args: PackedStringArray) -> Dictionary:
	var options := {
		"frame": ProjectSettings.globalize_path(DEFAULT_FRAME),
		"at_x": 0, "at_y": 0, "width": 0, "height": 0, "scale": 1,
		"icons": "", "effects": "", "digits": "", "icon_scale": 6,
	}
	var i := 0
	while i < args.size():
		match args[i]:
			"--frame":
				if i + 1 >= args.size():
					return {"error": "--frame needs a path"}
				options["frame"] = args[i + 1]
				i += 2
			"--at", "--size":
				if i + 2 >= args.size():
					return {"error": "%s needs two numbers" % args[i]}
				var keys := ["at_x", "at_y"] if args[i] == "--at" else ["width", "height"]
				options[keys[0]] = args[i + 1].to_int()
				options[keys[1]] = args[i + 2].to_int()
				i += 3
			"--scale", "--icon-scale":
				if i + 1 >= args.size():
					return {"error": "%s needs a number" % args[i]}
				var key := "scale" if args[i] == "--scale" else "icon_scale"
				options[key] = maxi(1, args[i + 1].to_int())
				i += 2
			"--icons", "--effects", "--digits":
				if i + 1 >= args.size():
					return {"error": "%s needs a path" % args[i]}
				options[args[i].substr(2)] = args[i + 1]
				i += 2
			_:
				return {"error": "unknown argument '%s'" % args[i]}
	if options["icons"] == "" and options["effects"] == "" \
			and options["digits"] == "" \
			and (options["width"] <= 0 or options["height"] <= 0):
		return {"error": "--size needs a rectangle with area"}
	return options


# --- The digits ------------------------------------------------------------


## The ten digits, and the two lines a playtest misread, drawn with the pack's
## font at the size the interface ships at -- once as the pack draws them and
## once as the game now draws them -- at that size and magnified beside it.
##
## Every pixel here is the font drawing a character, which is what a frame of
## this game already is: `reports/assets/playtest-*.png` carry hundreds of these
## same glyphs at this same size. Nothing of the pack's own files is copied out
## -- no sheet, no atlas, no typeface -- so this stays on the right side of the
## line the icon sheet above draws, which is that the pack's art is not written
## out of this repository even modified.
##
## The numbers printed beside the picture are the argument the picture makes:
## how many enclosed holes each digit has, and how many pixels separate it from
## the `8`. A reader tells round glyphs apart by counting holes long before
## reading any curve, so a zero with two holes is an eight however many pixels
## it differs by.
func _write_digit_strip(path: String, at_scale: int) -> void:
	if not SproutPack.is_installed():
		printerr("the Sprout Lands pack is not unpacked; "
			+ "run ./tools/extract_sprout_lands.sh")
		return
	var size := SproutTheme.BODY_SIZE
	var fonts := {
		"the pack's own zero": SproutTheme.pack_font(),
		"what the game draws": SproutTheme.build_font(),
	}

	_report_digits(fonts, size)

	# The panel's own ground and its own two inks, so the picture is the colours
	# a player sees rather than black on white.
	var sheet_art: Texture2D = load(SproutPack.SHEET)
	var brown: Color = sheet_art.get_image().get_pixel(
		SproutPack.FRAME.position.x + SproutPack.FRAME.size.x / 2,
		SproutPack.FRAME.position.y + SproutPack.FRAME.size.y / 2)
	var lines := PackedStringArray([
		"0123456789", "TRADES 0  ACTIONS 0", "0.4 AWAY  10/10  +0.00",
	])
	var pad := 4
	var step := size + 4
	var wide := 0
	for which in fonts:
		wide = maxi(wide, _line_width(fonts[which], size, which))
		for line in lines:
			wide = maxi(wide, size + _line_width(fonts[which], size, line))
	var tall := fonts.size() * (lines.size() + 1) * step + pad
	var block := Image.create_empty(wide + pad * 2, tall + pad, false, Image.FORMAT_RGBA8)
	block.fill(brown)
	var y := pad
	for which in fonts:
		var font: FontFile = fonts[which]
		_write_line(block, font, size, which, Vector2i(pad, y), SproutTheme.DIM)
		y += step
		for line in lines:
			_write_line(block, font, size, line, Vector2i(pad + size, y), SproutTheme.TEXT)
			y += step
	var big := block.duplicate() as Image
	big.resize(big.get_width() * at_scale, big.get_height() * at_scale,
		Image.INTERPOLATE_NEAREST)
	var sheet := Image.create_empty(
		maxi(block.get_width(), big.get_width()),
		block.get_height() + big.get_height() + pad, false, Image.FORMAT_RGBA8)
	sheet.fill(brown)
	sheet.blit_rect(block, Rect2i(Vector2i.ZERO, block.get_size()), Vector2i.ZERO)
	sheet.blit_rect(big, Rect2i(Vector2i.ZERO, big.get_size()),
		Vector2i(0, block.get_height() + pad))
	var error := sheet.save_png(path)
	if error != OK:
		printerr("could not write %s (%d)" % [path, error])
		return
	print("wrote %s: the ten digits at %d, and the same at %dx"
		% [path, size, at_scale])


## Holes and distances for every digit, both fonts, at every size the interface
## draws at.
func _report_digits(fonts: Dictionary, body: int) -> void:
	for which in fonts:
		var font: FontFile = fonts[which]
		for size in SproutTheme.SIZES:
			var shapes := {}
			for digit in range(10):
				shapes[str(digit)] = GlyphShape.of(font, size, str(digit))
			var holes := PackedStringArray()
			var from_eight := PackedStringArray()
			var nearest := PackedStringArray()
			for digit in shapes:
				holes.append("%s:%d" % [digit, GlyphShape.counters(shapes[digit])])
				from_eight.append("%s:%d" % [
					digit, GlyphShape.differing(shapes[digit], shapes["8"])])
				var closest := 999
				var to := ""
				for other in shapes:
					if other == digit:
						continue
					var apart := GlyphShape.differing(shapes[digit], shapes[other])
					if apart < closest:
						closest = apart
						to = other
				nearest.append("%s:%s/%d" % [digit, to, closest])
			print("%s, size %d" % [which, size])
			print("   holes          %s" % " ".join(holes))
			print("   px from the 8  %s" % " ".join(from_eight))
			print("   nearest digit  %s" % " ".join(nearest))
			print("   the 0 is the pack's own O: %s" % (
				"yes" if GlyphShape.differing(
					shapes["0"], GlyphShape.of(font, size, "O")) == 0 else "no"))


## How wide one line of text is, at the font's own advances.
func _line_width(font: FontFile, size: int, text: String) -> int:
	var wide := 0.0
	for at in text.length():
		var glyph := font.get_glyph_index(size, text.unicode_at(at), 0)
		wide += font.get_glyph_advance(0, size, glyph).x
	return int(ceil(wide))


## One line of text blitted into an image, glyph by glyph, at the font's own
## advances and offsets, with the panel's own one-pixel shadow under it.
##
## `at` is where the line's own top-left would be, so a caller can stack lines
## without knowing where a baseline is; the font's ascent puts each glyph on it.
## This needs no canvas and so no display, which is the whole reason the picture
## can be written by a headless run.
func _write_line(
	into: Image, font: FontFile, size: int, text: String, at: Vector2i, ink: Color
) -> void:
	var pen := Vector2(at.x, at.y + font.get_ascent(size))
	for index in text.length():
		var glyph := font.get_glyph_index(size, text.unicode_at(index), 0)
		var shape := GlyphShape.of(font, size, text[index])
		var offset := font.get_glyph_offset(0, Vector2i(size, 0), glyph)
		var corner := Vector2i(pen + offset)
		for pass_at: Vector2i in [Vector2i.ONE, Vector2i.ZERO]:
			for y in shape.size():
				for column in shape[y].length():
					if shape[y][column] != "#":
						continue
					var here := corner + Vector2i(column, y) + pass_at
					if here.x < 0 or here.y < 0 or here.x >= into.get_width() \
							or here.y >= into.get_height():
						continue
					into.set_pixelv(here,
						SproutTheme.SHADOW if pass_at == Vector2i.ONE else ink)
		pen.x += font.get_glyph_advance(0, size, glyph).x
