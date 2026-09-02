extends Node3D
## Lay characters and creatures out side by side, at world scale, each holding a
## named frame of a named clip.
##
##   xvfb-run -a ./tools/character_sheet.sh --screenshot "$PWD/out.png" \
##       minion_toadstool minion_cat skeleton_warrior:Idle_A
##
## An argument is a catalog tag, optionally followed by `:` and the clip to hold.
## A tag with no clip stands in its idle; a tag whose model has no bones stands
## as it ships, which is the honest answer for the board pieces the four minions
## currently resolve to.
##
## This goes through the same two things the game goes through -- AssetLibrary
## for the model, CharacterView for the animation -- rather than loading files,
## so what it photographs is what the table resolves and what the view plays. It
## is still a workbench and not part of the game: it places nothing where the
## world says anything belongs, and no simulation is running behind it.

## How far apart the cells sit, in world units. Set with --cell. The default
## fits a 2.7-unit adventurer with room for the scale post beside it.
var cell := 4.0

## How far into a clip a character is posed, in seconds. Set with --at. A little
## way in rather than at zero, because frame zero of a walk is a rest pose.
var pose_at := 0.45

## How tall the scale post beside every character is, in world units. One unit,
## so a character's height can be read straight off the picture.
const POST_HEIGHT := 1.0

var _frames := 0
var _screenshot_path := ""
var _screenshot_frame := 30


func _ready() -> void:
	var entries := []
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var arg := args[index]
		if arg == "--screenshot" and index + 1 < args.size():
			_screenshot_path = args[index + 1]
			index += 1
		elif arg == "--cell" and index + 1 < args.size():
			cell = args[index + 1].to_float()
			index += 1
		elif arg == "--at" and index + 1 < args.size():
			pose_at = args[index + 1].to_float()
			index += 1
		elif arg == "--frame" and index + 1 < args.size():
			_screenshot_frame = args[index + 1].to_int()
			index += 1
		else:
			var parts := arg.split(":")
			entries.append({
				"tag": parts[0],
				"clip": parts[1] if parts.size() > 1 else CharacterView.CLIP_IDLE,
			})
		index += 1

	var span := (entries.size() - 1) * cell
	_build_stage(span)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var tag: String = entry["tag"]
		if not AssetTags.is_tag(tag):
			push_error("character sheet: '%s' is not a catalog tag" % tag)
			continue
		var at := Vector3(i * cell - span * 0.5, 0.0, 0.0)

		var view: CharacterView = (load(CharacterView.SCENE) as PackedScene).instantiate()
		add_child(view)
		view.set_model(tag)
		view.position = at
		# Turned a little off square so a silhouette reads as a body rather than
		# as a flat front. Same angle for every cell, so two cells differ by what
		# is in them. Zero would be face-on: the models face their own +Z and the
		# camera is out along +Z.
		view.rotation.y = deg_to_rad(22.0)

		var row := AssetLibrary.visual(tag)
		var rigged := row != null and row.is_rigged()
		if rigged:
			view.pose(entry["clip"], pose_at)

		add_child(_scale_post(at + Vector3(cell * 0.36, 0.0, 0.0)))
		var caption := tag if not rigged else "%s\n%s" % [tag, entry["clip"]]
		add_child(_label(caption, at + Vector3(0.0, -0.55, cell * 0.30)))
		print("character sheet: %-18s %-16s %s" % [
			tag, entry["clip"] if rigged else "(no rig)",
			"" if row == null else row.scene_path.get_file(),
		])
	print("character sheet: %d cells" % entries.size())


func _process(_delta: float) -> void:
	_frames += 1
	if _screenshot_path != "" and _frames >= _screenshot_frame:
		var path := _screenshot_path
		_screenshot_path = ""
		_save_screenshot(path)


## The ground, the light and the air. The meadow's own colours, so the pieces are
## seen in the light the world would put them in.
func _build_stage(span: float) -> void:
	var profile := BiomeCatalog.profile(BiomeCatalog.MEADOW)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span + cell * 4.0, cell * 8.0)
	ground.mesh = plane
	# Pushed back so its near edge is behind the feet rather than in front of
	# them: the camera looks slightly down, and a ground plane reaching towards
	# the viewer crops every character off at the ankle.
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = profile.ground_tint
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	ground.position.z = -cell * 3.6
	add_child(ground)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.94, 0.82)
	light.shadow_enabled = true
	add_child(light)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = profile.sky_top
	sky_material.sky_horizon_color = profile.sky_horizon
	sky_material.ground_horizon_color = profile.sky_horizon
	sky_material.ground_bottom_color = profile.fog_color
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = profile.ambient_color
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)

	# Orthogonal, and framed on width. Every cell has to be the same size on
	# screen or the sheet stops answering the question it exists for -- how big
	# these things are next to each other.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = span + cell * 1.4
	camera.near = 0.1
	camera.far = 200.0
	camera.position = Vector3(0.0, 2.2, 40.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.35, 0.0), Vector3.UP)
	add_child(camera)


## A one-unit post, so height can be read off the picture rather than taken on
## trust.
func _scale_post(at: Vector3) -> MeshInstance3D:
	var post := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, POST_HEIGHT, 0.05)
	post.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.10, 0.12)
	post.material_override = material
	post.position = at + Vector3(0.0, POST_HEIGHT * 0.5, 0.0)
	return post


func _label(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 52
	label.pixel_size = 0.0055
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.08, 0.08, 0.10)
	label.outline_size = 0
	label.position = at
	label.no_depth_test = true
	return label


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("character sheet: screenshot %s" % path)
	else:
		printerr("character sheet: screenshot failed (%d) for %s" % [error, path])
	get_tree().quit(0 if error == OK else 1)
