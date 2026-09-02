extends SceneTree
## Whether the back of a blade of grass is lit wrongly, and by how much.
##
##   ./tools/measure_blade_normals.sh --start 228 -60 --shots /tmp/normals
##
## Grass is drawn with `cull_disabled`, so every blade is a single sheet whose
## two faces are both drawn. The engine turns the normal of a back-facing
## fragment around before a fragment shader runs, so that it points out of the
## side being looked at; a shader that stylises the normal in its *vertex* stage
## does so before that turn, and every back-facing fragment then gets its answer
## negated. This tool is what settled that, and what the shipped shader's choice
## of stage is measured against.
##
## The tool draws the same paused frame once per shading variant, swapping the
## code of the grass shader in place between captures so the world, the camera,
## the tick and the instance buffer are untouched:
##
##   stock       what the game ships: the flatten done per fragment, after the
##               engine has turned the normal to the side being looked at.
##   vertex      the flatten done per vertex, which is what the layer did before
##               this was measured: correct on the near face of a blade and
##               upside down on the far one.
##   flipped     per fragment, turning the normal around again for a back-facing
##               fragment. The fix that would be needed if the engine did not
##               already do it -- so on this engine it is a double negative.
##   upright     every normal straight up, no geometric part left at all. The
##               control: whatever the stage is worth, it is bounded by this.
##   backfaces   back-facing fragments painted red, which measures how much of
##               the grass on screen is showing its far side at all.
##   sidecheck   no stylising whatever, every fragment painted by which way its
##               own normal ends up pointing once the engine has had it. This is
##               what says the engine turns a double-sided surface's normal
##               around, rather than leaving it to the shader.
##
## Each variant is reported against the frame named beside it: the share of
## pixels that changed at all, how far they moved, and what happened to the
## brightness and to the noise of the region. reports/grass.md quotes the table.

const NoiseMetric := preload("res://tools/noise_metric.gd")

const SETTLE_FRAMES := 60
const WARM_FRAMES := 8

## One step of an eight-bit channel: "this pixel changed" without an opinion.
const CHANGED := 1.0 / 255.0

## The lines the shipped shader stylises the normal with, in its fragment stage,
## and the last line of its vertex stage -- the anchors every variant below is
## cut from, so a variant is the shipped shader with one thing changed and not a
## second copy of it that can drift.
const UP_LINE := "\tvec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);"
const FLATTEN_PREFIX := "\tNORMAL = normalize(mix(NORMAL, up, "
const ALBEDO_LINE := "\tALBEDO = COLOR.rgb * max_gain;"
const LAST_VERTEX_LINE := "\tVERTEX.y -= lean * length(push) * 0.30;"


## The shipped shader's own flatten line, found rather than copied, so that
## changing how far the layer flattens does not silently turn every variant below
## into a copy of the stock shader -- which is a table of zeroes that looks like
## an answer.
static func flatten_line() -> String:
	var at := GrassLayer.GRASS_SHADER.find(FLATTEN_PREFIX)
	if at < 0:
		return ""
	var end := GrassLayer.GRASS_SHADER.find("\n", at)
	return GrassLayer.GRASS_SHADER.substr(at, end - at)


## How far the shipped shader flattens, as it is written in that line.
static func flatten_amount() -> String:
	var line := flatten_line()
	return line.substr(line.rfind(", ") + 2).trim_suffix("));")

var _shell: Node = null
var _region := NoiseMetric.MEADOW
var _shots := ""
var _variants: Array = []
var _stock: Image = null
var _frames_of := {}
var _rows: Array = []
var _stage := -1
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--region":
				if i + 4 < args.size():
					_region = Rect2i(
						args[i + 1].to_int(), args[i + 2].to_int(),
						args[i + 3].to_int() - args[i + 1].to_int(),
						args[i + 4].to_int() - args[i + 2].to_int(),
					)
					i += 4
			"--shots":
				if i + 1 < args.size():
					_shots = args[i + 1]
					i += 1
		i += 1

	_variants = [
		{"name": "stock", "code": GrassLayer.GRASS_SHADER, "against": "stock"},
		{"name": "vertex", "code": _in_vertex(), "against": "stock"},
		{
			"name": "flipped",
			"code": GrassLayer.GRASS_SHADER.replace(
				flatten_line(),
				"\tNORMAL = normalize(mix(FRONT_FACING ? NORMAL : -NORMAL, up, %s));"
					% flatten_amount()
			),
			"against": "stock",
		},
		{
			"name": "upright",
			"code": GrassLayer.GRASS_SHADER.replace(flatten_line(), "\tNORMAL = up;"),
			"against": "stock",
		},
		{
			"name": "backfaces",
			"code": GrassLayer.GRASS_SHADER.replace(
				ALBEDO_LINE,
				"\tALBEDO = FRONT_FACING ? COLOR.rgb * max_gain : vec3(1.0, 0.0, 0.0);"
			),
			"against": "stock",
		},
		{
			"name": "sidecheck",
			"code": GrassLayer.GRASS_SHADER.replace(flatten_line(), "").replace(
				ALBEDO_LINE,
				"\tALBEDO = NORMAL.z > 0.0 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);"
			),
			"against": "stock",
		},
	]
	if flatten_line() == "":
		printerr("measure_blade_normals: the shader's flatten line has moved")
		quit(2)
		return
	_shell = load("res://render/main.tscn").instantiate()
	root.add_child(_shell)
	print("region              x %d..%d, y %d..%d, flatten %s" % [
		_region.position.x, _region.end.x, _region.position.y, _region.end.y,
		flatten_amount(),
	])


## The shipped shader with the flatten moved back into the vertex stage, which
## is what the layer did before this was measured -- and towards (0, 1, 0)
## literally, because the vertex stage works in world coordinates while the
## fragment stage works in the camera's.
func _in_vertex() -> String:
	return GrassLayer.GRASS_SHADER \
		.replace(UP_LINE, "") \
		.replace(flatten_line(), "") \
		.replace(
			LAST_VERTEX_LINE,
			LAST_VERTEX_LINE
				+ "\n\tNORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), %s));"
					% flatten_amount()
		)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_shell.set("_paused", true)
		return false
	var grass: GrassLayer = _shell.get("_grass")
	if grass == null:
		printerr("measure_blade_normals: this run has no grass layer to measure")
		return true

	if _stage < 0:
		if _frames < SETTLE_FRAMES:
			return false
		_stage = 0
		_frames = 0
		_apply(grass, 0)
		return false
	if _frames < WARM_FRAMES:
		return false

	var image := _shell.get_viewport().get_texture().get_image()
	var name := String(_variants[_stage]["name"])
	if _shots != "":
		image.save_png("%s/normals-%s.png" % [_shots, name])
	if _stock == null:
		_stock = image
	_frames_of[name] = image
	_rows.append(_measure(name, image, String(_variants[_stage]["against"])))
	_stage += 1
	if _stage < _variants.size():
		_frames = 0
		_apply(grass, _stage)
		return false
	_report()
	return true


## Swap the grass shader's code in place. The material, its uniforms and every
## chunk's instance buffer are left exactly as they are, so nothing but the
## shading changes between one capture and the next.
func _apply(grass: GrassLayer, index: int) -> void:
	var material: ShaderMaterial = grass.get("_material")
	material.shader.code = String(_variants[index]["code"])


## How far this variant moved the picture away from the one it is measured
## against -- the stock frame for most of them, the unflipped control for the
## flip, so that the flip is credited with its own difference and no one else's.
func _measure(name: String, image: Image, against: String) -> Dictionary:
	var base: Image = _frames_of.get(against, _stock)
	var clipped := _region.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
	var changed := 0
	var total := 0.0
	var most := 0.0
	var red := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var here := image.get_pixel(x, y)
			var was := base.get_pixel(x, y)
			# Everything in this frame that is not painted is green ground under
			# green grass, so a fragment the shader has painted red is the only
			# thing whose red beats its green.
			if here.r > here.g + 0.05:
				red += 1
			var gap := absf(here.get_luminance() - was.get_luminance())
			if absf(here.r - was.r) > CHANGED or absf(here.g - was.g) > CHANGED \
				or absf(here.b - was.b) > CHANGED:
				changed += 1
			total += gap
			most = maxf(most, gap)
	var pixels := float(maxi(clipped.size.x * clipped.size.y, 1))
	return {
		"name": name,
		"against": against,
		"changed": float(changed) / pixels,
		"mean": total / pixels,
		"max": most,
		"red": float(red) / pixels,
		"noise": NoiseMetric.measure(image, _region),
	}


func _report() -> void:
	var world = _shell.get("_sim").world
	var profile: BiomeProfile = world.terrain.profile_at(world.observer_x, world.observer_z)
	print("")
	print("measured at         (%.1f, %.1f) in %s, %d tufts drawn" % [
		world.observer_x, world.observer_z, profile.display_name,
		int(_shell.get("_grass_drawn")),
	])
	print("")
	print("%-10s %-10s %9s %10s %9s %9s %9s" % [
		"variant", "against", "changed", "mean |d|", "max |d|", "lum mean", "lap std",
	])
	for row in _rows:
		print("%-10s %-10s %8.1f%% %10.5f %9.4f %9.4f %9.4f" % [
			row["name"], row["against"], 100.0 * row["changed"], row["mean"],
			row["max"], row["noise"]["lum_mean"], row["noise"]["laplacian_std"],
		])
	print("")
	for row in _rows:
		if row["name"] == "backfaces":
			print("grass showing its far side:  %.1f%% of the region's pixels" % [
				100.0 * row["red"],
			])
		if row["name"] == "sidecheck":
			print("normals still facing away:   %.1f%% of the region's pixels" % [
				100.0 * row["red"],
			])
	print("changed / mean |d| / max |d| are against the variant named in `against`.")
