extends Node3D
## Photograph a seeded fight while it is being fought: seven weapons in a row,
## each drawn with its own motion at the tick the record says it began on.
##
##   xvfb-run -a ./tools/swing_sheet.sh --screenshot-ticks "6:six.png,16:sixteen.png"
##
## The run is `TestAttackClips.stage()` -- the same fixture the suite asserts
## over and `tools/measure_swings.sh` prints -- stepped at the shell's own twenty
## ticks a second. Every tick, the snapshot goes through `CombatDiorama` and
## `CharacterView` exactly as `render/main.gd` puts it through them, so what is
## photographed is the game's own animation rule and not a pose set by hand.
##
## What is *not* the game: where the characters stand. They are laid out in a row
## at a fixed angle instead of where the board says they are, because the
## question a frame of this answers is "which motion is each of them playing",
## and seven characters scattered across a lattice at their own facings answer it
## worse. Everything else -- which clip, how far into it, when it starts and when
## it stops -- is the shell's.
##
## A workbench, not part of the game. No simulation state is written; the fight
## is stepped and read.

## How far apart the characters stand on the sheet, in world units.
var cell := 3.6

## How many ticks a second the fight is stepped at. The shell's own rate, so a
## clip that lasts a second lasts twenty ticks here as it does there.
const TICKS_PER_SECOND := CharacterRig.TICKS_PER_SECOND

## How tall the scale post beside each character is, in world units.
const POST_HEIGHT := 1.0

var _staged := {}
var _views := {}
var _labels := {}
var _order: Array[int] = []
var _wanted := {}

# Which weapons to put on the sheet, or empty for all of them. A frame with
# three characters on it reads better than one with seven, and the run behind it
# is the same run either way: everybody fights, and this only chooses who is
# photographed.
var _only := {}
var _tick := 0
var _seed := TestAttackClips.SEED
var _saving := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var arg := args[index]
		if arg == "--seed" and index + 1 < args.size():
			_seed = args[index + 1].to_int()
			index += 1
		elif arg == "--cell" and index + 1 < args.size():
			cell = args[index + 1].to_float()
			index += 1
		elif arg == "--only" and index + 1 < args.size():
			for named in args[index + 1].split(",", false):
				_only[named] = true
			index += 1
		elif arg == "--screenshot-ticks" and index + 1 < args.size():
			for pair in args[index + 1].split(",", false):
				var halves := pair.split(":", false, 1)
				if halves.size() == 2:
					_wanted[halves[0].to_int()] = halves[1]
			index += 1
		index += 1

	_staged = TestAttackClips.stage(_seed)
	var looks: Dictionary = _staged["looks"]
	var weapons: Dictionary = _staged["weapons"]
	for id in looks:
		if _only.is_empty() or _only.has(String(weapons.get(int(id), ""))):
			_order.append(int(id))
	_order.sort()

	var span := float(_order.size() - 1) * cell
	_build_stage(span)
	for at in _order.size():
		var id := _order[at]
		var where := Vector3(float(at) * cell - span * 0.5, 0.0, 0.0)
		var view: CharacterView = (load(CharacterView.SCENE) as PackedScene).instantiate()
		add_child(view)
		view.set_model(String(looks[id]))
		view.position = where
		# A fixed angle for every cell, so two cells differ by what is happening
		# in them rather than by which way somebody happens to be turned.
		view.rotation.y = deg_to_rad(22.0)
		# The tree advances only when it is told to, below. Left to itself it
		# would advance by the frame's own time, and a frame under a software
		# renderer is worth many ticks.
		var tree := view.get_node("AnimationTree") as AnimationTree
		tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_views[id] = view
		add_child(_scale_post(where + Vector3(cell * 0.38, 0.0, 0.0)))
		var label := _label("", where + Vector3(0.0, -0.5, cell * 0.34))
		add_child(label)
		_labels[id] = label
	var drawn_weapons := []
	for id in _order:
		drawn_weapons.append(String(weapons.get(id, "")))
	print("swing sheet: seed %d, %d of %d commanders drawn: %s" % [
		_seed, _order.size(), (weapons as Dictionary).size(), str(drawn_weapons)])


func _process(_delta: float) -> void:
	if _saving:
		return
	if _wanted.is_empty():
		get_tree().quit(0)
		return
	# Stepped by ticks and not by frames, and the animation is stepped by hand
	# with them (`_manual` below), so the picture does not depend on how fast the
	# machine draws. A frame photographed at tick N is the world at tick N with
	# every clip exactly N-minus-when-it-began ticks into itself, whether the
	# renderer managed sixty frames a second or one.
	var target := _next_wanted()
	while _tick < target:
		var snapshot := TestAttackClips.advance(_staged)
		_tick += 1
		_draw(snapshot)
		for id in _views:
			(_views[id] as CharacterView).step_animation(1.0 / TICKS_PER_SECOND)
	var path: String = _wanted[_tick]
	_wanted.erase(_tick)
	_saving = true
	_save_screenshot(path)


## The next tick a photograph is wanted on.
func _next_wanted() -> int:
	var soonest := 1 << 30
	for when in _wanted:
		soonest = mini(soonest, int(when))
	return soonest


## One tick drawn: every commander's state through the same rule the shell uses,
## and a caption under each saying what that rule was told and what it answered.
func _draw(snapshot: Dictionary) -> void:
	for row in TestAttackClips.drawn(_staged, snapshot):
		var id := int(row["id"])
		if not _views.has(id):
			continue
		(_views[id] as CharacterView).apply(row["state"], 1.0 / TICKS_PER_SECOND)
		var motion := String(row["motion"])
		(_labels[id] as Label3D).text = "%s\n%s\n%s" % [
			String(row["weapon"]),
			motion if motion != "" else "-",
			String(row["clip"]),
		]


func _build_stage(span: float) -> void:
	var profile := BiomeCatalog.profile(BiomeCatalog.MEADOW)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span + cell * 4.0, cell * 8.0)
	ground.mesh = plane
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

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = span + cell * 1.6
	camera.near = 0.1
	camera.far = 200.0
	camera.position = Vector3(0.0, 2.2, 40.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.30, 0.0), Vector3.UP)
	add_child(camera)


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
	label.font_size = 44
	label.pixel_size = 0.0045
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
		print("swing sheet: tick %d -> %s" % [_tick, path])
	else:
		printerr("swing sheet: screenshot failed (%d) for %s" % [error, path])
	if error != OK or _wanted.is_empty():
		get_tree().quit(0 if error == OK else 1)
		return
	_saving = false
