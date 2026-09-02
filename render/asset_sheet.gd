extends Node3D
## Every asset tag in the catalog, built and laid out in a grid, so the table can
## be looked at rather than only read.
##
## This is a contact sheet, not part of the game: it places nothing where the
## world says anything belongs, and the simulation is not running behind it. It
## exists because a mapping table whose output nobody has seen is a table nobody
## can tell is wrong -- an invisible prop, a tree the size of a pebble and a
## lantern that does not glow all look identical in a list of tag names.
##
## Run it with:  ./run_asset_sheet.sh [--screenshot path.png]

## How far apart the cells sit, in world units. Wide enough that the tavern does
## not lean on the tower.
const CELL := Vector2(8.5, 12.0)
const COLUMNS := 8

## Which biome's colours the sheet is drawn in. One biome for the whole sheet, so
## that a difference between two cells is a difference between two tags rather
## than between two palettes.
const SHEET_BIOME := BiomeCatalog.MEADOW

var _frames := 0
var _screenshot_path := ""
var _screenshot_frame := 30


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			_screenshot_path = args[i + 1]
		if args[i] == "--screenshot-frame" and i + 1 < args.size() \
				and args[i + 1].is_valid_int():
			_screenshot_frame = args[i + 1].to_int()

	var profile := BiomeCatalog.profile(SHEET_BIOME)
	var tags := AssetTags.all()
	var rows := int(ceil(float(tags.size()) / float(COLUMNS)))
	var span := Vector2((COLUMNS - 1) * CELL.x, (rows - 1) * CELL.y)

	_build_stage(profile, span)
	for index in tags.size():
		var tag: String = tags[index]
		var at := Vector3(
			(index % COLUMNS) * CELL.x - span.x * 0.5,
			0.0,
			(index / COLUMNS) * CELL.y - span.y * 0.5,
		)
		var built := AssetLibrary.build(tag, profile)
		if built == null:
			push_error("asset sheet: '%s' would not build" % tag)
			continue
		built.position = at
		add_child(built)
		add_child(_label(tag, at + Vector3(0.0, 0.9, CELL.y * 0.38)))

	print("asset sheet: %d tags over %d rows" % [tags.size(), rows])


func _process(_delta: float) -> void:
	_frames += 1
	if _screenshot_path != "" and _frames >= _screenshot_frame:
		var path := _screenshot_path
		_screenshot_path = ""
		_save_screenshot(path)


## The ground, the light and the air the sheet stands in. Deliberately the same
## cool-ambient, warm-key setup the world uses, so a lantern reads here the way
## it will read there.
func _build_stage(profile: BiomeProfile, span: Vector2) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span.x + CELL.x * 2.0, span.y + CELL.y * 2.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = profile.ground_tint
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
	environment.ambient_light_energy = 0.75
	# Bloom, so the emissive parts read as light rather than as bright paint.
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.15
	world_environment.environment = environment
	add_child(world_environment)

	# Orthogonal on purpose: every cell has to be the same size on screen, or the
	# back row would look like a set of smaller props.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Framed on width, because that is the axis the window is wide in -- but the
	# fit has to be the larger of the two. The catalog was six categories and
	# five rows when fitting the columns was enough; it is eight and eight now,
	# and the sheet is deeper than it is wide, so fitting only the columns leaves
	# the last row off the bottom of the frame.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = maxf((span.x + CELL.x) * 1.18, (span.y + CELL.y) * 1.22)
	camera.near = 0.1
	camera.far = 500.0
	camera.position = Vector3(0.0, 70.0, 82.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 4.0, 0.0), Vector3.UP)
	add_child(camera)


func _label(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.013
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.10, 0.10, 0.10)
	label.outline_size = 0
	label.position = at
	label.no_depth_test = true
	return label


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("asset sheet: screenshot %s" % path)
	else:
		printerr("asset sheet: screenshot failed (%d) for %s" % [error, path])
	get_tree().quit(0 if error == OK else 1)
