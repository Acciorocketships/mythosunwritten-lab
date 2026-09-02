extends RefCounted
## The look of one biome: plain data, and nothing but plain data.
##
## A profile is what a named biome *is* as far as the rest of the project is
## concerned -- a palette, an atmosphere, how thickly things grow, and which
## props are allowed to appear there. It holds numbers and colours only. It
## holds no engine object, draws nothing, and knows nothing about how any of it
## is eventually put on a screen; the render shell reads these values and
## decides for itself what to do with them.
##
## Colours are stored as Color, which is one of the engine's plain value types
## -- four floats in a struct, the same kind of thing as the Vector3 the ground
## is already made of. Nothing here is a presentation object, which is why the
## layer check (which forbids the simulation every scene-tree and presentation
## type) is happy with it.
##
## Two profiles are also blended into a third along a border, which is the whole
## reason this is a small bag of independently interpolatable values rather than
## an opaque handle to something.
class_name BiomeProfile

## Stable identifier, e.g. "twilight_marsh". This is what other layers key on.
var id: String = ""

## What to call it in prose. A blend of several biomes names the strongest.
var display_name: String = ""

## Ground colour: the tint of the terrain surface itself.
var ground_tint := Color(0.5, 0.5, 0.5)

## The tint trees and other foliage take here.
var tree_tint := Color(0.3, 0.4, 0.3)

## The tint rocks, boulders and cliffs take here.
var rock_tint := Color(0.5, 0.5, 0.5)

## The colour of water here. Water is one world-space sheet rather than a thing
## each biome owns a piece of, so its colour has to come from the position it is
## drawn at -- which means it belongs on the profile alongside the ground and
## the fog, and blends across a border exactly as they do.
var water_tint := Color(0.30, 0.55, 0.70)

## The colour distance fades towards, and how quickly it gets there. Density is
## a fraction of the light lost per world unit, so it is calibrated against the
## scale of the world rather than of a screen: the diorama camera looks about 60
## units into the scene, where the meadow's density loses under a tenth of the
## far ground and the twilight marsh's loses about half of it. The marsh's is
## seven times the meadow's, which is what turns it into an enclosed hollow.
var fog_color := Color(0.7, 0.8, 0.85)
var fog_density := 0.0015

## The sky gradient, from straight overhead to the horizon.
var sky_top := Color(0.35, 0.6, 0.9)
var sky_horizon := Color(0.8, 0.88, 0.95)

## The colour of the light that fills the shadows. Deliberately warm-neutral
## rather than sky-blue in the bright biomes, so shadowed stone still reads as
## stone.
var ambient_color := Color(0.7, 0.72, 0.7)

## How thickly things grow here, in [0, 1]. The scatter layer will read it; no
## props are placed yet.
var foliage_density := 0.4

## Which prop tags may appear here. Tags, never asset paths -- the scatter layer
## maps a tag to whatever scene is installed for it, so a pack can be swapped
## without touching generation. Naming them is this layer's job; placing them is
## a later one's.
var prop_tags := PackedStringArray()


func _init(biome_id: String = "", name_for_display: String = "") -> void:
	id = biome_id
	display_name = name_for_display


## A detached copy: same values, no shared storage.
##
## This is how a profile leaves the simulation. The catalog's own profiles are
## never handed out directly, because the engine's packed arrays share storage
## when assigned -- a holder that wrote into the prop tags of a profile it was
## merely shown would be writing into the catalog every later sample reads.
func detached_copy() -> BiomeProfile:
	var copy := BiomeProfile.new(id, display_name)
	copy.ground_tint = ground_tint
	copy.tree_tint = tree_tint
	copy.rock_tint = rock_tint
	copy.water_tint = water_tint
	copy.fog_color = fog_color
	copy.fog_density = fog_density
	copy.sky_top = sky_top
	copy.sky_horizon = sky_horizon
	copy.ambient_color = ambient_color
	copy.foliage_density = foliage_density
	copy.prop_tags = prop_tags.duplicate()
	return copy


## A short, stable fingerprint of these values, for tests and world digests.
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("id=%s" % id)
	for tint in [
		ground_tint, tree_tint, rock_tint, water_tint,
		fog_color, sky_top, sky_horizon, ambient_color,
	]:
		parts.append("%.4f,%.4f,%.4f" % [tint.r, tint.g, tint.b])
	parts.append("fog=%.5f" % fog_density)
	parts.append("foliage=%.4f" % foliage_density)
	parts.append("tags=%s" % ",".join(prop_tags))
	return "|".join(parts).sha256_text().substr(0, 16)
