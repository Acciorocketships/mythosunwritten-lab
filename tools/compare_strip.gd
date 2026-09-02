extends SceneTree
## Stack several captured frames into one labelled comparison image.
##
##   ./tools/compare_strip.sh --out reports/assets/grass-noise-compare.png \
##       --crop 250 380 800 560 --zoom 2 \
##       --panel /tmp/before.png "current build - noisy" \
##       --panel /tmp/after.png  "same frame + 4x MSAA"
##
## Every evidence image that shows the same view under two or three treatments
## is this shape -- the frames cropped to the same rectangle, stacked, each with
## a caption saying which is which -- and building it by hand is how a panel ends
## up labelled as the wrong treatment. So it is a command.
##
## Needs a display for the text: the captions are drawn by the engine's own font
## through a viewport. Use xvfb-run on a machine with no screen.

const BAR := 24
const BAR_COLOR := Color(0.05, 0.05, 0.05)
const CAPTION_COLOR := Color(0.95, 0.96, 0.98)
const CAPTION_SIZE := 13
const CAPTION_INSET := 6

var _out := ""
var _crop := Rect2i()
var _zoom := 1
var _panels: Array = []
var _viewport: SubViewport = null
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--out":
				if i + 1 < args.size():
					_out = args[i + 1]
					i += 1
			"--crop":
				# Left, top, right, bottom in the captured frame's pixels.
				if i + 4 < args.size():
					_crop = Rect2i(
						args[i + 1].to_int(), args[i + 2].to_int(),
						args[i + 3].to_int() - args[i + 1].to_int(),
						args[i + 4].to_int() - args[i + 2].to_int(),
					)
					i += 4
			"--zoom":
				# Scale every panel up by a whole number, nearest neighbour, so
				# that what is being compared is one pixel of the frame drawn as
				# a block rather than a resampling of it. Aliasing lives at the
				# pixel, and a crop small enough to show it is too small to
				# look at.
				if i + 1 < args.size():
					_zoom = maxi(1, args[i + 1].to_int())
					i += 1
			"--panel":
				if i + 2 < args.size():
					_panels.append({"path": args[i + 1], "caption": args[i + 2]})
					i += 2
		i += 1

	if _out == "" or _panels.is_empty():
		printerr("compare_strip: --out and at least one --panel are required")
		quit(2)
		return

	var images: Array[Image] = []
	for panel in _panels:
		var image := Image.load_from_file(panel["path"])
		if image == null:
			printerr("compare_strip: could not read %s" % panel["path"])
			quit(2)
			return
		var region := _crop
		if region.size.x <= 0 or region.size.y <= 0:
			region = Rect2i(0, 0, image.get_width(), image.get_height())
		var cropped := image.get_region(region)
		if _zoom > 1:
			cropped.resize(
				cropped.get_width() * _zoom, cropped.get_height() * _zoom,
				Image.INTERPOLATE_NEAREST,
			)
		images.append(cropped)

	var width := images[0].get_width()
	var height := images[0].get_height()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(width, images.size() * (height + BAR))
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var background := ColorRect.new()
	background.color = BAR_COLOR
	background.size = _viewport.size
	_viewport.add_child(background)
	for index in images.size():
		var top := index * (height + BAR)
		var caption := Label.new()
		caption.text = String(_panels[index]["caption"])
		caption.position = Vector2(CAPTION_INSET, top + 2)
		caption.add_theme_color_override("font_color", CAPTION_COLOR)
		caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
		_viewport.add_child(caption)
		var frame := TextureRect.new()
		frame.texture = ImageTexture.create_from_image(images[index])
		frame.position = Vector2(0, top + BAR)
		_viewport.add_child(frame)
	root.add_child(_viewport)


func _process(_delta: float) -> bool:
	# The viewport has to have been drawn before it can be read back, and the
	# text is laid out a frame after the labels are added, so a couple of frames
	# go by before the picture is what it is meant to be.
	_frames += 1
	if _frames < 4:
		return false
	var image := _viewport.get_texture().get_image()
	var error := image.save_png(_out)
	if error == OK:
		print("compare-strip %s (%d panels, %dx%d, zoom %dx)" % [
			_out, _panels.size(), image.get_width(), image.get_height(), _zoom,
		])
	else:
		printerr("compare-strip failed (%d) for %s" % [error, _out])
	return true
