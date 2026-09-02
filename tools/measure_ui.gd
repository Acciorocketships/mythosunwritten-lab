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
		quit(2)
		return

	if options["icons"] != "":
		_write_icon_sheet(options["icons"], options["icon_scale"])
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
		"icons": "", "icon_scale": 6,
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
			"--icons":
				if i + 1 >= args.size():
					return {"error": "--icons needs a path"}
				options["icons"] = args[i + 1]
				i += 2
			_:
				return {"error": "unknown argument '%s'" % args[i]}
	if options["icons"] == "" and (options["width"] <= 0 or options["height"] <= 0):
		return {"error": "--size needs a rectangle with area"}
	return options
