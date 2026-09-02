extends Node3D
## Lay out a handful of pack models side by side, at their real size, so a choice
## between candidates for one tag can be looked at rather than only read off a
## table of triangle counts.
##
##   xvfb-run -a ./tools/model_sheet.sh --screenshot "$PWD/out.png" \
##       assets/justcreate_village/Houses/House_01.fbx ...
##
## Every model stands on the same ground under the same light, with a one-metre
## post beside it for scale. This is a workbench, not part of the game: nothing
## here knows what a tag is.

const COLUMNS := 5

## How far apart the cells sit, in world units. Set with --cell: a sheet of
## houses and a sheet of mushrooms cannot be read at the same spacing.
var CELL := 9.0

var _frames := 0
var _screenshot_path := ""
var _screenshot_frame := 30


func _ready() -> void:
	var paths := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var arg := args[index]
		if arg == "--screenshot" and index + 1 < args.size():
			_screenshot_path = args[index + 1]
			index += 1
		elif arg == "--cell" and index + 1 < args.size():
			CELL = args[index + 1].to_float()
			index += 1
		else:
			paths.append(arg if arg.begins_with("res://") else "res://" + arg.trim_prefix("./"))
		index += 1

	var rows := int(ceil(float(paths.size()) / float(COLUMNS)))
	var span := Vector2((COLUMNS - 1) * CELL, (rows - 1) * CELL)
	_build_stage(span)
	for i in paths.size():
		var at := Vector3(
			(i % COLUMNS) * CELL - span.x * 0.5, 0.0, (i / COLUMNS) * CELL - span.y * 0.5
		)
		var packed: PackedScene = load(paths[i])
		if packed == null:
			push_error("model sheet: %s would not load" % paths[i])
			continue
		var node: Node3D = packed.instantiate()
		node.position = at
		add_child(node)
		add_child(_scale_post(at + Vector3(CELL * 0.29, 0.0, CELL * 0.29)))
		add_child(_label(paths[i].get_file(), at + Vector3(0.0, 0.4, CELL * 0.42)))
	print("model sheet: %d models over %d rows" % [paths.size(), rows])


func _process(_delta: float) -> void:
	_frames += 1
	if _screenshot_path != "" and _frames >= _screenshot_frame:
		var path := _screenshot_path
		_screenshot_path = ""
		_save_screenshot(path)


## A one-metre white post, so a model's height is readable off the picture.
func _scale_post(at: Vector3) -> MeshInstance3D:
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 1.0, 0.08)
	post.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 0.95)
	post.material_override = material
	post.position = at + Vector3(0.0, 0.5, 0.0)
	return post


func _build_stage(span: Vector2) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span.x + CELL * 2.0, span.y + CELL * 2.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.48, 0.60, 0.40)
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	add_child(ground)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	light.light_energy = 1.15
	light.light_color = Color(1.0, 0.94, 0.82)
	light.shadow_enabled = true
	add_child(light)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.74, 0.82)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.76)
	environment.ambient_light_energy = 0.9
	world_environment.environment = environment
	add_child(world_environment)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = (span.x + CELL) * 1.15
	camera.near = 0.1
	camera.far = 500.0
	camera.position = Vector3(0.0, CELL * 4.4, CELL * 5.1)
	camera.look_at_from_position(camera.position, Vector3(0.0, CELL * 0.22, 0.0), Vector3.UP)
	add_child(camera)


func _label(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.011 * CELL / 9.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.08, 0.08, 0.08)
	label.outline_size = 0
	label.position = at
	label.no_depth_test = true
	return label


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("model sheet: screenshot %s" % path)
	else:
		printerr("model sheet: screenshot failed (%d) for %s" % [error, path])
	get_tree().quit(0 if error == OK else 1)
