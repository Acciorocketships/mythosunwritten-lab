extends RefCounted
## The floating glowing particles: fireflies, spores, dust motes and embers, as
## one instanced cloud that follows the view and never runs out.
##
## Like the grass, this lives in the render shell rather than in the simulation,
## and for the same reason and with more force: nothing in the world can touch a
## firefly. Nothing collides with one, nothing picks one up, no tactical rule
## reads one, and the world is exactly the same world whether or not a single
## mote is drawn. A headless process never loads this file, so there is nothing
## to switch off there -- the motes do not exist.
##
## Nothing here is per-frame work on the processor either. The cloud is a fixed
## pool of instances built once, laid out in a box, and everything that moves is
## a function of world position and time inside the shader: each mote wanders on
## its own slow path, rises, and is wrapped back into the box around wherever the
## view is centred. Walking a hundred units does not build a single new mote --
## the ones behind you come round in front of you -- and the only thing written
## per frame is the one uniform saying where the middle of the box now is.
##
## How many of them are drawn is the biome's business, and it is read off the
## profile the simulation blended for where the observer is standing: see
## `density_for()`. Nothing about the mote pool is rebuilt to change it -- the
## count is one integer on the multimesh, exactly the trick the grass uses for
## its level of detail.
class_name MoteField

## How many motes the pool holds. This is the marsh's number -- the thickest any
## biome gets -- and every other biome draws a share of it.
const COUNT := 1500

## The box the cloud lives in, in world units: how wide it is across the ground
## and how tall it stands. Wide enough that its edges are outside what the
## diorama camera has in frame, so a mote is never seen arriving at the boundary.
const BOX := 92.0
const BOX_HEIGHT := 26.0

## How far below the view's own height the box starts. Motes drift upwards, so
## most of the box wants to be above the observer rather than below it.
const BOX_DROP := 5.0

## How big one mote is drawn, in world units. A firefly is a couple of
## centimetres of light; these are drawn larger than that because a mote is a
## soft glow rather than an insect, and the bloom spreads it further still.
const SIZE_MIN := 0.055
const SIZE_MAX := 0.150

## Where a mote fades out and where it has gone, in world units from the centre
## of the box. Both inside half the box (46), so the wrap happens where nothing
## is being drawn and no mote ever pops.
const FADE_START := 30.0
const FADE_END := 42.0

## How fast a mote wanders and how far, in world units and world units per
## second, and how fast it rises. Slow on purpose: a firefly that darts reads as
## a fly, and this is meant to read as light hanging in the air.
const WANDER := 1.7
const RISE := 0.45

## How fast a mote breathes, in cycles per second, and how far down it dims at
## the bottom of that breath.
const PULSE_RATE := 0.55
const PULSE_DEPTH := 0.45

## The warm palette a mote is drawn from. Always warm, never the colour of the
## biome: the art direction's whole signature is warm pinpoints against a cool
## ground, and a teal firefly in a teal marsh would disappear into it.
const WARM_COLORS: Array[Color] = [
	Color(1.00, 0.82, 0.42),  # firefly amber
	Color(1.00, 0.93, 0.66),  # pale gold dust
	Color(1.00, 0.62, 0.28),  # ember
	Color(0.96, 0.88, 0.78),  # spore
]

## How the biome's own numbers become a density, in [0, 1].
##
## Two things the profile already carries, and no new field anywhere in the
## simulation: how thick the air is (`fog_density`) and how thickly things grow
## (`foliage_density`). Both already mean what is wanted here. A gloomy enclosed
## hollow is where the design asks for the most fireflies, and it is also the
## biome with the densest fog; a bare windswept highland is where it asks for the
## fewest, and it is also the one that grows almost nothing.
##
## GLOOM_FULL is the twilight marsh's own fog density, so the marsh scores one on
## that half of the sum and every other biome scores a fraction of it. The five
## named biomes come out at meadow 0.38, deep forest 0.74, highland 0.34,
## blossom grove 0.51, twilight marsh 0.95 -- see tests/test_atmosphere.gd, which
## checks the ordering rather than the numbers.
const GLOOM_FULL := 0.0090
const DENSITY_FLOOR := 0.15
const DENSITY_FROM_GLOOM := 0.55
const DENSITY_FROM_FOLIAGE := 0.35

## How much brighter a mote is drawn in the gloomiest biome than in the brightest.
## A firefly in an open noon meadow is a hint; the same firefly in a twilight
## hollow is the light source.
const BRIGHT_MIN := 0.55
const BRIGHT_MAX := 1.60

## The shader.
##
## Everything that moves is a function of the mote's own fixed base position and
## of time, so two motes never share a path and none of them needs a memory. The
## wrap is the only thing that reads the outside world: the box's centre, written
## once a frame.
const MOTE_SHADER := """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// Where the box is centred and how big it is, in world units.
uniform vec3 focus = vec3(0.0, 0.0, 0.0);
uniform float box = 92.0;
uniform float box_height = 26.0;
uniform float box_drop = 5.0;

uniform float wander = 1.7;
uniform float rise = 0.45;
uniform float pulse_rate = 0.55;
uniform float pulse_depth = 0.45;
uniform float brightness = 1.0;
uniform float fade_start = 30.0;
uniform float fade_end = 42.0;

varying float glow;
varying vec3 warm;

void vertex() {
	// The instance's origin is its base position inside the box, and its custom
	// data is how big it is drawn (x) and its own phase (y), hashed once when
	// the pool was built.
	vec3 base = MODEL_MATRIX[3].xyz;
	float size = INSTANCE_CUSTOM.x;
	float phase = INSTANCE_CUSTOM.y * 6.2831853;

	// Its own slow path. Three circles of unrelated periods, so no two motes
	// travel together and none of them traces anything a viewer can name.
	vec3 path = vec3(
		sin(TIME * 0.21 + phase) + 0.4 * sin(TIME * 0.53 + phase * 2.7),
		sin(TIME * 0.13 + phase * 1.7) * 0.6,
		cos(TIME * 0.17 + phase * 1.3) + 0.4 * cos(TIME * 0.47 + phase * 3.1)
	) * wander;
	path.y += TIME * rise;

	// Wrapped back into the box around the view. This is what makes the cloud
	// endless without building anything: a mote that leaves one face of the box
	// arrives through the opposite one, and because the fade below has already
	// taken it to nothing by then, nobody sees the join.
	vec3 low = vec3(focus.x - box * 0.5, focus.y - box_drop, focus.z - box * 0.5);
	vec3 span = vec3(box, box_height, box);
	vec3 world = low + mod(base + path - low, span);

	// A round dot always facing the camera, sized in world units at its own
	// distance -- built in view space, which is what makes it face the camera
	// without any per-mote work anywhere else.
	vec3 middle = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	middle += vec3(VERTEX.x, VERTEX.y, 0.0) * size;
	POSITION = PROJECTION_MATRIX * vec4(middle, 1.0);

	// Breathing, and gone before the wrap.
	float breath = 1.0 - pulse_depth * (0.5 + 0.5 * sin(TIME * pulse_rate * 6.2831853 + phase));
	float near = 1.0 - smoothstep(fade_start, fade_end, distance(world.xz, focus.xz));
	glow = breath * near * brightness;
	warm = COLOR.rgb;
}

void fragment() {
	// A soft round core: bright in the middle, nothing at the rim. Squared so
	// the falloff is a glow rather than a disc with an edge.
	float across = length(UV - vec2(0.5)) * 2.0;
	float core = 1.0 - smoothstep(0.0, 1.0, across);
	core *= core;
	ALBEDO = warm;
	ALPHA = clamp(core * glow, 0.0, 1.0);
}
"""

## How many motes are in the pool and how many are being drawn. Reported on the
## shell's stop line, which is how a test tells a run with the atmosphere stack
## from a run without one.
var pooled := 0
var drawn := 0

var _view: MultiMeshInstance3D = null
var _material: ShaderMaterial = null
var _density := 0.0
var _brightness := 1.0


func _init(world_seed: int) -> void:
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = MOTE_SHADER
	_material.shader = shader
	_material.set_shader_parameter("box", BOX)
	_material.set_shader_parameter("box_height", BOX_HEIGHT)
	_material.set_shader_parameter("box_drop", BOX_DROP)
	_material.set_shader_parameter("wander", WANDER)
	_material.set_shader_parameter("rise", RISE)
	_material.set_shader_parameter("pulse_rate", PULSE_RATE)
	_material.set_shader_parameter("pulse_depth", PULSE_DEPTH)
	_material.set_shader_parameter("fade_start", FADE_START)
	_material.set_shader_parameter("fade_end", FADE_END)
	_material.set_shader_parameter("brightness", _brightness)

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = COUNT
	multimesh.buffer = _pool(world_seed)
	pooled = COUNT

	_view = MultiMeshInstance3D.new()
	_view.name = "motes"
	_view.multimesh = multimesh
	_view.material_override = _material
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves every mote and wraps it around a box that follows the
	# view, so the engine cannot work the bounds out from the transforms. Stated
	# instead, and generously: without it the whole cloud is culled the moment
	# the camera turns away from the origin.
	_view.custom_aabb = AABB(
		Vector3(-BOX, -BOX, -BOX), Vector3(BOX * 2.0, BOX * 2.0, BOX * 2.0)
	)
	_view.extra_cull_margin = BOX


## The node the cloud is drawn as. It never moves; the box the motes live in
## follows the view inside the shader.
func view() -> MultiMeshInstance3D:
	return _view


## How thickly a biome carries motes, in [0, 1]. A pure function of the profile,
## so a test can state the rule and check the five named biomes against it.
static func density_for(profile: BiomeProfile) -> float:
	var gloom := clampf(profile.fog_density / GLOOM_FULL, 0.0, 1.0)
	return clampf(
		DENSITY_FLOOR
		+ DENSITY_FROM_GLOOM * gloom
		+ DENSITY_FROM_FOLIAGE * clampf(profile.foliage_density, 0.0, 1.0),
		0.0, 1.0
	)


## How brightly a mote burns in a biome. The gloomier the air, the more of the
## light in the scene a firefly is.
static func brightness_for(profile: BiomeProfile) -> float:
	var gloom := clampf(profile.fog_density / GLOOM_FULL, 0.0, 1.0)
	return lerpf(BRIGHT_MIN, BRIGHT_MAX, gloom)


## Take the biome's mood. Changing how many motes are drawn is one integer on
## the multimesh -- nothing is rebuilt, nothing is re-hashed, and the motes that
## stay drawn do not so much as blink, because the pool was laid out shuffled.
func take(profile: BiomeProfile) -> void:
	_density = density_for(profile)
	_brightness = brightness_for(profile)
	_material.set_shader_parameter("brightness", _brightness)
	var wanted := clampi(int(round(float(COUNT) * _density)), 0, COUNT)
	if _view.multimesh.visible_instance_count != wanted:
		_view.multimesh.visible_instance_count = wanted
	drawn = wanted


## Centre the box on the view. The one write per frame this layer costs.
func look_from(focus: Vector3) -> void:
	_material.set_shader_parameter("focus", focus)


## How thick the cloud is here and how bright, for the record.
func density() -> float:
	return _density


func brightness() -> float:
	return _brightness


## The pool, laid out once: a base position anywhere in the box, a size, a phase
## and a warm colour, all hashed off the mote's own index and the world seed.
##
## The order matters. Drawing a share of the pool draws a prefix of it, so the
## prefix has to be spread through the whole box rather than filling one corner
## of it -- which it is, because a position is hashed rather than stepped.
func _pool(world_seed: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(COUNT * 20)
	for at in COUNT:
		var h := SimRng.hash_ints(world_seed, at, 0x9E37)
		var base := at * 20
		# Twelve floats of transform: no rotation and no scale, because the
		# shader builds the quad in view space and sizes it itself. Only the
		# origin is read, and it is the mote's place in the box.
		buffer[base] = 1.0
		buffer[base + 5] = 1.0
		buffer[base + 10] = 1.0
		buffer[base + 3] = (float(h & 0xFFFF) / 65535.0) * BOX
		buffer[base + 7] = (float((h >> 16) & 0xFF) / 255.0) * BOX_HEIGHT
		buffer[base + 11] = (float((h >> 24) & 0xFF) / 255.0) * BOX

		var g := SimRng.hash_ints(world_seed, at, 0x5BD1)
		var warm := WARM_COLORS[int(g % WARM_COLORS.size())]
		buffer[base + 12] = warm.r
		buffer[base + 13] = warm.g
		buffer[base + 14] = warm.b
		buffer[base + 15] = 1.0
		# Custom data: how big this mote is drawn, and its own phase.
		buffer[base + 16] = lerpf(SIZE_MIN, SIZE_MAX, float((g >> 8) & 0xFF) / 255.0)
		buffer[base + 17] = float((g >> 16) & 0xFFFF) / 65535.0
	return buffer
