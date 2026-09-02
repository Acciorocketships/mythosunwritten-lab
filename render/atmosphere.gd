extends RefCounted
## The lighting and atmosphere stack: cool ambient against warm pinpoint light.
##
## Everything that decides what the world is *lit* like lives here -- the key
## light and its long soft shadows, the sky, the fog, the fill light, the bloom
## on every warm emissive, the miniature depth of field, the warm point lights
## on lanterns, windows, campfires and glowing toadstools, the drifting orbs of
## the twilight pockets, and the cloud of floating motes. It is one layer with
## one switch, which is what lets the render shell be started with `--no-atmosphere`
## and draw the identical world with none of it.
##
## Like the grass and the motes, all of it is in the render shell and none of it
## is in the simulation. That is not tidiness; it is what makes "headless skips
## the render stack" true by construction rather than by a flag. A headless
## process never loads a single file under render/, so there is no environment,
## no light, no bloom and no mote there to switch off. tests/test_atmosphere.gd
## checks that from both ends: from outside, that a headless run loads none of
## these files, and from inside, that the same seed run through the shell with
## and without the whole stack reaches a byte-identical world.
##
## None of the *values* are invented here either. The fog colour and density, the
## sky gradient and the colour of the fill light are read every frame off the
## blended biome profile the simulation produced for wherever the observer is
## standing, and how thickly the motes drift is a function of two more of its
## numbers. This file chooses which knob each one is turned into, and nothing
## else. Walk across a biome border and the mood shifts because the simulation
## says it does. reports/atmosphere.md is the write-up.
class_name Atmosphere

## The tags whose placeholders are meant to be seen glowing, and how each one
## lights the ground: how high the flame sits, what colour it is, how strong it
## is and how far it reaches, all in world units.
##
## `gloom` is the least gloomy biome the light is worth having in, as the
## fraction of the marsh's fog density that biome carries (the same measure
## MoteField uses). Zero means everywhere. It exists for the glowing toadstools:
## there are hundreds of them, they are the design's own light source for the
## eerie pockets, and in an open noon meadow a toadstool's cap is a cute detail
## that lights nothing anyone can see. So it glows everywhere and only *casts*
## where casting reads.
const GLOWING_TAGS := {
	"lantern_post": {
		"at": 2.5, "color": Color(1.0, 0.74, 0.40), "energy": 3.2, "range": 12.0,
		"gloom": 0.0,
	},
	"hanging_lantern": {
		"at": 1.9, "color": Color(1.0, 0.74, 0.40), "energy": 2.4, "range": 9.0,
		"gloom": 0.0,
	},
	"campfire": {
		"at": 0.5, "color": Color(1.0, 0.60, 0.28), "energy": 4.0, "range": 14.0,
		"gloom": 0.0,
	},
	"glowing_orb": {
		"at": 1.3, "color": Color(0.62, 0.94, 0.86), "energy": 2.6, "range": 10.0,
		"gloom": 0.0,
	},
	# A lit window. The height is the middle of the pane the asset table draws,
	# so the light comes out of the window rather than from above or below it.
	# The colour sits between the lantern's flame and the amber of the pane
	# itself: hearth-light through glass is warm but not as orange as an open
	# flame. It is the weakest and shortest-reaching of the four because there
	# are far more of them -- a village lights twenty-odd windows against five
	# lantern posts -- so each one is a pool on its own wall and the ground under
	# it rather than another light washing the green.
	"window_glow": {
		"at": AssetLibrary.WINDOW_HEIGHT,
		"color": Color(1.0, 0.76, 0.42), "energy": 2.0, "range": 8.0,
		"gloom": 0.0,
	},
	# The glowing mushroom of section 9.1, on theme with the Toadstool minion it
	# shares a name with. Weak and short: it is meant to pick out the ground it
	# is standing on and the stems around it, not to light a clearing, and in the
	# marsh there are a great many of them.
	"toadstool": {
		"at": 0.42, "color": Color(0.95, 0.55, 0.42), "energy": 1.1, "range": 3.2,
		"gloom": 0.40,
	},
}

## How far a glowing orb wanders from where the simulation put it, in world
## units, and how fast, in radians per second.
##
## Slow enough that the movement reads as the pocket being alive rather than as
## something happening: a full circuit takes the better part of a minute. Where
## the orb *is* remains the simulation's answer -- this is the picture breathing
## around that point, exactly as the far-sky islands drift around theirs, and
## nothing in the world asks where an orb has got to.
const ORB_WANDER := 0.85
const ORB_RATE := 0.11

## The key light: where the sun is, how strong it is and what colour.
##
## Low on purpose. At thirty-six degrees above the horizon a fir throws a shadow
## 1.38 times its own height, which is the long raking shadow that makes a
## diorama read as a small thing on a table rather than as a landscape at noon.
##
## The yaw is not free either, and it was picked from photographs rather than
## reasoned about. At the first angle tried the shadows fell away from the
## diorama camera and were hidden behind the things casting them -- a wide shot
## of a village had no visible shadow anywhere in it. This is a three-quarter
## back-light: shadows rake towards the viewer, and the faces still catch the
## key. It is the single number that decides whether the shadows are seen at all.
## reports/atmosphere.md has the before and after.
const SUN_PITCH := -36.0
const SUN_YAW := 122.0
const SUN_ENERGY := 1.15
const SUN_COLOR := Color(1.0, 0.92, 0.78)

## How soft the shadows are: the apparent size of the sun in degrees, and how far
## the shadow edge is blurred. The real sun is 0.53 degrees across; this is a
## little over twice that, which turns a hard stencil edge into a penumbra that
## widens with distance from whatever cast it. Much past this and a tree's shadow
## stops being a shadow and becomes a smudge.
const SUN_SOFTNESS := 1.2
const SHADOW_BLUR := 1.2

## How far shadows are cast, in world units. Well inside the streamer's own load
## radius of 40 but not far past it: the shadow map is a fixed budget stretched
## over whatever this covers, so every unit spent out here is resolution taken
## from the diorama. The far-sky islands are scenery hundreds of units off and
## shadowing them would spend the whole map on empty air.
const SHADOW_DISTANCE := 110.0

## The depth-of-field band, as fractions of how far the camera is from what it is
## looking at. Everything much nearer than the observer and everything much
## further away goes soft, which is the miniature look: a real lens focused this
## close has a depth of field a few centimetres deep, and reproducing that on a
## landscape is what makes the landscape read as a model of one.
##
## Fractions rather than distances because a report may move the camera closer
## for a detail shot, and the band has to move with it or the whole frame goes
## soft.
const DOF_NEAR := 0.46
const DOF_FAR := 1.80
const DOF_TRANSITION := 1.10
const DOF_AMOUNT := 0.06

## The bloom on every warm emissive. Only genuinely bright things bloom: the
## threshold is at white, so a lit pane, a lantern bulb, a campfire and a mote
## all halo and a pale wall does not.
const GLOW_INTENSITY := 0.85
const GLOW_STRENGTH := 1.0
const GLOW_BLOOM := 0.16
const GLOW_THRESHOLD := 1.0

## How high above the observer the ground mist lies and how thick it is, as a
## multiple of the biome's own fog density.
##
## This is the one piece of the fog that is not simply the biome's number turned
## into a knob: depth fog alone fades the distance evenly, and mist in the
## reference images pools in the low ground and thins out above it. The height is
## carried with the observer rather than fixed to the world, so the mist lies
## over the valley floor you are standing in rather than at some absolute
## altitude that would bury a highland and miss a marsh.
const MIST_HEIGHT := 7.0
const MIST_SCALE := 0.20

## A gentle grade over the whole picture: a little more contrast and a little
## more colour, which is what separates the cool ground from the warm pinpoints
## without moving a single light.
const GRADE_CONTRAST := 1.04
const GRADE_SATURATION := 1.12

## How many warm point lights this layer has handed out, cumulative. Reported on
## the shell's stop line, which is how a test tells a run with the stack from a
## run without one.
var lights_made := 0

var _environment: Environment = null
var _sky_material: ProceduralSkyMaterial = null
var _key_light: DirectionalLight3D = null
var _world_environment: WorldEnvironment = null
var _camera_attributes: CameraAttributesPractical = null
var _motes: MoteField = null

# The glowing orbs on screen, as {node, anchor, phase}. Kept as its own list so
# the per-frame wander does not have to walk the scene to find them, and pruned
# as the chunks they stand on stream out.
var _orbs := []


func _init(world_seed: int) -> void:
	_build_environment()
	_build_key_light()
	_camera_attributes = CameraAttributesPractical.new()
	_camera_attributes.dof_blur_near_enabled = true
	_camera_attributes.dof_blur_far_enabled = true
	_camera_attributes.dof_blur_far_transition = DOF_TRANSITION
	_camera_attributes.dof_blur_near_transition = DOF_TRANSITION
	_camera_attributes.dof_blur_amount = DOF_AMOUNT
	_motes = MoteField.new(world_seed)


## Hang the whole stack off the scene. One call, because it is one layer.
func attach(parent: Node3D) -> void:
	parent.add_child(_world_environment)
	parent.add_child(_key_light)
	parent.add_child(_motes.view())


## Focus the miniature depth of field for a camera sitting this far from what it
## is looking at. Called once when the camera is placed, and again only if a
## capture moves it.
func focus_at(distance: float) -> void:
	_camera_attributes.dof_blur_near_distance = distance * DOF_NEAR
	_camera_attributes.dof_blur_far_distance = distance * DOF_FAR


## The camera attributes the depth of field lives on.
func camera_attributes() -> CameraAttributes:
	return _camera_attributes


## Put the biome's mood on screen.
##
## Every colour here comes from the profile the simulation blended for where the
## observer is standing; none of them is chosen in this file. Because the profile
## is a blend rather than a lookup, crossing a border slides the fog, the sky and
## the fill light from one biome's numbers to the next over the width of the
## border instead of switching them.
func take(profile: BiomeProfile, observer: Vector3) -> void:
	_sky_material.sky_top_color = profile.sky_top
	_sky_material.sky_horizon_color = profile.sky_horizon
	_sky_material.ground_horizon_color = profile.sky_horizon
	_sky_material.ground_bottom_color = profile.fog_color
	_environment.fog_light_color = profile.fog_color
	_environment.fog_density = profile.fog_density
	# The mist that lies in the low ground, on top of the even depth fade. Its
	# ceiling follows the observer, so it is always the air of the place being
	# stood in.
	_environment.fog_height = observer.y + MIST_HEIGHT
	_environment.fog_height_density = profile.fog_density * MIST_SCALE
	_environment.ambient_light_color = profile.ambient_color
	_motes.take(profile)
	_motes.look_from(observer)


## Move the glowing orbs. Two circles of unrelated periods around the point the
## simulation put each orb on, so a pair of neighbours never look like they are
## on the same turntable. Nothing here touches the world: an orb is a prop the
## scatter layer placed, the terrain query does not know it has moved, and no
## answer about the world depends on where it has wandered to.
func drift(seconds: float) -> void:
	if _orbs.is_empty():
		return
	var kept := []
	for orb in _orbs:
		# Asked of the dictionary rather than of a typed local: an orb's node is
		# freed with the chunk it stood on, and binding a freed object to a typed
		# variable is itself the error this is trying to avoid.
		if not is_instance_valid(orb["node"]):
			continue
		var node: Node3D = orb["node"]
		kept.append(orb)
		var phase: float = orb["phase"]
		var angle := seconds * ORB_RATE + phase
		node.position = (orb["anchor"] as Vector3) + Vector3(
			cos(angle) * ORB_WANDER,
			sin(angle * 0.71 + phase) * ORB_WANDER * 0.55,
			sin(angle * 1.13) * ORB_WANDER,
		)
	_orbs = kept


## The point light that goes with a glowing tag, or null where that tag does not
## glow, or does not glow brightly enough here to be worth a light.
##
## An emissive surface lights itself and nothing else, and a village at dusk is
## the art direction's signature precisely because its lanterns light the ground
## around them. What glows is the simulation's decision -- it placed a
## `lantern_post` -- and how brightly is this layer's.
func light_for(tag: String, profile: BiomeProfile) -> OmniLight3D:
	if not GLOWING_TAGS.has(tag):
		return null
	var settings: Dictionary = GLOWING_TAGS[tag]
	if gloom_of(profile) < float(settings["gloom"]):
		return null
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, float(settings["at"]), 0.0)
	light.light_color = settings["color"]
	light.light_energy = float(settings["energy"])
	light.omni_range = float(settings["range"])
	light.shadow_enabled = false
	lights_made += 1
	return light


## Take note of a glowing orb so it can be made to wander. The anchor is where
## the simulation put it, and it is never moved from -- the orb circles it.
func hold_orb(node: Node3D, world_seed: int) -> void:
	var anchor := node.position
	_orbs.append({
		"node": node,
		"anchor": anchor,
		"phase": SimRng.hash_unit(
			world_seed, int(anchor.x * 16.0), int(anchor.z * 16.0)
		) * TAU,
	})


## How gloomy a biome is, as the share of the gloomiest one's fog density it
## carries. The same measure the motes are counted by, so "dark enough for a
## toadstool to be a light source" and "dark enough for fireflies to be thick"
## are one number rather than two that could drift apart.
static func gloom_of(profile: BiomeProfile) -> float:
	return clampf(profile.fog_density / MoteField.GLOOM_FULL, 0.0, 1.0)


## How many motes are pooled and how many are drawn, for the shell's stop line.
func mote_counts() -> Vector2i:
	return Vector2i(_motes.pooled, _motes.drawn)


## The mote cloud, for the tests and the cost measurement.
func motes() -> MoteField:
	return _motes


## Free the scene nodes this layer made, for a holder that never put them in a
## tree.
##
## The shell does not need this -- it hands them to the tree, which owns them
## from then on -- but a test builds a layer, reads it and drops it, and a
## RefCounted going out of scope does not take a Node with it. Without this a
## test run ends with a page of leaked-instance errors that would hide a real one.
func dispose() -> void:
	for node: Node in [_world_environment, _key_light, _motes.view()]:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	_orbs.clear()


## The engine objects the values are written into. Handed out so that a test can
## read back what the biome profile turned into rather than take this file's word
## for it, and so the cost measurement can switch one part of the stack off at a
## time. Nothing in the shell writes to them.
func environment() -> Environment:
	return _environment


func sky_material() -> ProceduralSkyMaterial:
	return _sky_material


func key_light() -> DirectionalLight3D:
	return _key_light


## How many orbs are wandering right now.
func orb_count() -> int:
	return _orbs.size()


func _build_environment() -> void:
	_world_environment = WorldEnvironment.new()
	_environment = Environment.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_curve = 0.25
	_sky_material.ground_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	# The fill light is a colour, not the sky. That is the whole point of it: an
	# ambient taken from the sky would pour blue into every shadow and turn
	# shadowed stone into shadowed slate, and the profiles carry a warm-neutral
	# colour instead so that stone in shade still reads as stone.
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_energy = 0.7
	_environment.fog_enabled = true
	_environment.fog_sky_affect = 0.4
	_environment.fog_aerial_perspective = 0.2

	# Bloom on every warm emissive. The lower levels are where a lantern's tight
	# halo comes from and the higher ones are the wide soft wash around a lit
	# village; weighting the middle gives a glow that reads at both scales
	# without smearing the whole frame.
	_environment.glow_enabled = true
	_environment.glow_intensity = GLOW_INTENSITY
	_environment.glow_strength = GLOW_STRENGTH
	_environment.glow_bloom = GLOW_BLOOM
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_environment.glow_hdr_threshold = GLOW_THRESHOLD
	_environment.set_glow_level(1, 0.2)
	_environment.set_glow_level(2, 0.7)
	_environment.set_glow_level(3, 1.0)
	_environment.set_glow_level(4, 0.7)
	_environment.set_glow_level(5, 0.3)

	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = GRADE_CONTRAST
	_environment.adjustment_saturation = GRADE_SATURATION

	_world_environment.environment = _environment


func _build_key_light() -> void:
	_key_light = DirectionalLight3D.new()
	_key_light.name = "key_light"
	_key_light.rotation_degrees = Vector3(SUN_PITCH, SUN_YAW, 0.0)
	_key_light.light_energy = SUN_ENERGY
	_key_light.light_color = SUN_COLOR
	_key_light.light_angular_distance = SUN_SOFTNESS
	_key_light.shadow_enabled = true
	_key_light.shadow_blur = SHADOW_BLUR
	_key_light.directional_shadow_max_distance = SHADOW_DISTANCE
	# The normal bias pushes the depth comparison along the surface normal, and at
	# a low sun that shrinks every shadow by roughly bias / tan(elevation) -- at
	# thirty-six degrees the 2.0 inherited from the old high-sun setup ate 2.8
	# world units off every edge, which erases a tree's shadow entirely. These are
	# the smallest values that still keep the ground from shadow-fighting itself.
	_key_light.shadow_normal_bias = 0.7
	_key_light.shadow_bias = 0.035
