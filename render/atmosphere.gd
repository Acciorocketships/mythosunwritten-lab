extends RefCounted
## What the adopted world's own atmosphere does not do: warm pinpoint light,
## wandering orbs, drifting motes, and the mist that pools in the low ground.
##
## The sun, the sky, the fog, the bloom, the ambient fill, the ambient occlusion
## and the miniature depth of field are **not** here any more, and that is the
## whole of this file's rewrite for the adopted base. They belong to the world
## scene this shell inherits -- `AtmosphereDirector` in the base's own
## `scripts/terrain/biome/`, hung in `scenes/world.tscn`, grading its own
## terrain against its own biome field. Two layers cannot own one Environment,
## and the one that ships with the world the shell draws is the one that keeps
## it. What is left here is what theirs has no equivalent for.
##
## Their director states its own rule for why the grade is global: "Local biome
## mood belongs to world-space fog, vegetation and ground, so walking cannot
## relight distant scenery." This project used to slide the sky and the fog from
## one biome's numbers to the next as the observer crossed a border. That is
## their call to make on their world, and it is adopted: the only per-biome
## number this file still turns into a knob is how thick the low mist and the
## motes are where the observer is standing, neither of which relights anything
## in the distance.
##
## So, what this layer is: the warm point lights on lanterns, windows,
## campfires and glowing toadstools; the slow wander of the twilight pockets'
## orbs; the cloud of floating motes; and the ground mist, written onto the
## adopted Environment rather than onto one of ours. It is one layer with one
## switch, which is what lets the render shell be started with
## `--no-atmosphere` -- and that switch now means "none of this layer", not
## "no lighting at all": the adopted world still lights itself.
##
## Like the motes, all of it is in the render shell and none of it is in the
## simulation. That is not tidiness; it is what makes "headless skips the render
## stack" true by construction rather than by a flag. A headless process never
## loads a single file under render/, so there is no light, no orb and no mote
## there to switch off.
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

## How many warm point lights this layer has handed out, cumulative. Reported on
## the shell's stop line, which is how a test tells a run with the stack from a
## run without one.
var lights_made := 0

## The adopted world's Environment, handed over by `attach()`. This layer reads
## none of it and writes exactly two numbers into it -- the height fog that is
## the ground mist -- so that the mist is part of the same air the base's own
## depth fog is, rather than a second fog fighting it.
var _environment: Environment = null
var _motes: MoteField = null

# The glowing orbs on screen, as {node, anchor, phase}. Kept as its own list so
# the per-frame wander does not have to walk the scene to find them, and pruned
# as the chunks they stand on stream out.
var _orbs := []


func _init(world_seed: int) -> void:
	_motes = MoteField.new(world_seed)


## Hang this layer off the world the shell inherited. One call, because it is
## one layer.
##
## `world_environment` is the adopted scene's own WorldEnvironment -- the node
## `AtmosphereDirector` grades. This layer is handed it rather than building
## one, which is the whole of the rewrite: the mist goes into the air the base
## already lit, and switching this layer off leaves that air exactly as the
## base set it.
func attach(parent: Node3D, world_environment: WorldEnvironment) -> void:
	if world_environment != null:
		_environment = world_environment.environment
	parent.add_child(_motes.view())


## Put the mist and the motes where the observer is standing.
##
## Both numbers come from the profile the simulation blended for that place;
## neither is chosen in this file. What used to be here as well -- the sky, the
## depth fog and the fill light sliding from one biome's numbers to the next --
## is the adopted director's now, by its own stated rule, and this keeps only
## the two that are about the air immediately around the observer.
func take(profile: SimBiomeProfile, observer: Vector3) -> void:
	if _environment != null:
		# The mist that lies in the low ground, on top of the base's own even
		# depth fade. Its ceiling follows the observer, so it is always the air
		# of the place being stood in.
		_environment.fog_height = observer.y + MIST_HEIGHT
		_environment.fog_height_density = profile.fog_density * MIST_SCALE
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
func light_for(tag: String, profile: SimBiomeProfile) -> OmniLight3D:
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
static func gloom_of(profile: SimBiomeProfile) -> float:
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
	for node: Node in [_motes.view()]:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	_orbs.clear()


## The adopted Environment this layer writes the mist into, or null before
## `attach()`. Handed out so that a test can read back what the biome profile
## turned into rather than take this file's word for it.
func environment() -> Environment:
	return _environment


## How many orbs are wandering right now.
func orb_count() -> int:
	return _orbs.size()
