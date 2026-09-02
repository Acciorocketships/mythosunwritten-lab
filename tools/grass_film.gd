extends SceneTree
## Film the grass: save a numbered PNG every few frames, so a still picture can
## be turned into a moving one.
##
##   ./tools/grass_film.sh --out reports/assets/frames --frames 40 --stride 3 \
##       --seed 1234 --start 228 -60
##
## Everything after the tool's own arguments is passed through to the render
## shell, which parses them itself -- so --seed, --start, --paused and --camera
## all mean what they mean everywhere else.
##
## It exists because two of the things the grass layer does are motion, and a
## screenshot cannot show motion: the gusts rolling downwind, and the clearing
## travelling with a character while the grass behind stands back up.
## tools/grass_demo.sh runs it and stitches the frames.

const DEFAULT_WARM := 60
const DEFAULT_FRAMES := 40
const DEFAULT_STRIDE := 3

var _shell: Node = null
var _frames := 0
var _saved := 0
var _out := "res://reports/assets/frames"
var _wanted := DEFAULT_FRAMES
var _stride := DEFAULT_STRIDE
var _warm := DEFAULT_WARM


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for at in args.size():
		var has_value := at + 1 < args.size()
		match args[at]:
			"--out":
				if has_value:
					_out = args[at + 1]
			"--frames":
				if has_value and args[at + 1].is_valid_int():
					_wanted = args[at + 1].to_int()
			"--stride":
				if has_value and args[at + 1].is_valid_int():
					_stride = maxi(1, args[at + 1].to_int())
			"--warm":
				if has_value and args[at + 1].is_valid_int():
					_warm = args[at + 1].to_int()
	DirAccess.make_dir_recursive_absolute(_out)
	_shell = load("res://render/main.tscn").instantiate()
	root.add_child(_shell)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _warm:
		return false
	if (_frames - _warm) % _stride != 0:
		return false
	_save()
	_saved += 1
	return _saved >= _wanted


func _save() -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/frame_%03d.png" % [_out, _saved]
	if image.save_png(path) != OK:
		printerr("grass film: cannot write %s" % path)
