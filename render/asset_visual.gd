extends RefCounted
## One row of the asset table: what an asset tag looks like.
##
## A visual is either a scene -- a model out of a purchased pack, named by its
## path -- or a small stack of placeholder primitives that stand in for one
## until a pack arrives. Both forms are described here as plain data, so that
## installing the real art is a matter of filling in `scene_path` on a row
## rather than of changing how anything is built.
##
## The placeholder is deliberately more than one cube. A fir is a trunk and a
## cone; a lantern post is a post and a glowing bulb; a house is walls, a roof
## and a lit window. That is enough for the diorama to read at a glance and for a
## screenshot to be worth looking at, and it is the same shape language -- flat
## faceted solids -- the bought packs are drawn in, so swapping one in should not
## change the composition of a scene, only its detail.
##
## Colour is where a placeholder meets the world. A part may keep its own colour
## (a wooden trunk is brown in every biome) or take a role -- "tree", "rock",
## "ground" -- in which case the biome profile at that position supplies the
## colour and the part's own is only the fallback for when no profile is given.
## That is the same rule the terrain already follows: the palette lives in the
## biome catalog, and this layer only shows it.
##
## A row that names a scene follows the same rule with one role for the whole
## model -- `scene_tint_role` and `scene_tint_mix` below -- because a pack model
## has no seam to hang a second role on. Without that a border would shift the
## ground, the water and the fog and leave every tree in the world the one green
## the pack's texture happens to be.
class_name AssetVisual

## The primitive shapes a placeholder can be made of. Every one of them exists
## as a mesh the engine can build from numbers, so a placeholder needs no file.
const SHAPE_BOX := "box"
const SHAPE_SPHERE := "sphere"
const SHAPE_CONE := "cone"
const SHAPE_CYLINDER := "cylinder"
const SHAPE_CAPSULE := "capsule"
const SHAPE_PRISM := "prism"
const SHAPE_TORUS := "torus"
const SHAPE_PLANE := "plane"

const SHAPES := [
	SHAPE_BOX, SHAPE_SPHERE, SHAPE_CONE, SHAPE_CYLINDER,
	SHAPE_CAPSULE, SHAPE_PRISM, SHAPE_TORUS, SHAPE_PLANE,
]

## Which biome colour a part follows, if any.
const TINT_NONE := ""
const TINT_TREE := "tree"
const TINT_ROCK := "rock"
const TINT_GROUND := "ground"
const TINT_WATER := "water"

const TINT_ROLES := [TINT_NONE, TINT_TREE, TINT_ROCK, TINT_GROUND, TINT_WATER]

## What a scene row means when it says nothing at all about its model's colour.
##
## Not a role, and never stored on a row -- AssetLibrary._row() resolves it to
## the placeholder's own role before the row is written, so by the time anything
## reads `scene_tint_role` it is one of TINT_ROLES. It exists because "this model
## keeps the colours the pack drew it in" and "nobody said" have to be two
## different things. They were one thing once: the tint role was an optional
## trailing argument defaulting to TINT_NONE, so a row repointed at a pack model
## and left at five arguments shipped untinted and looked exactly like a fence
## that had chosen to. That is how the bare tree came to stand in the twilight
## marsh in its pack's warm orange. reports/model-tint.md tells the whole of it.
const TINT_UNSTATED := "?"

## The tag this row answers for.
var tag := ""

## The model to use, once there is one. Empty means "no pack installed for this
## tag yet, use the placeholder below". This is the field an art drop edits.
var scene_path := ""

## How tall the model in `scene_path` stands, in world units. Only meaningful on
## a row that names a scene, and the second thing an art drop fills in.
##
## Generation asks for things by *size*: a fir in deep forest is meant to stand
## seven units tall and the same fir on the tops two and a half, and it says so
## in world units because the simulation has no idea what a fir looks like. The
## renderer turns that into a scale, which means it has to know what one unit of
## the model is. For a placeholder it works that out from the parts; for a real
## model only the pack knows, so the row says.
var scene_height := 0.0

## Which skeleton the model in `scene_path` is rigged on, for a row whose model
## is animated. Empty -- every row but the characters and the creatures -- means
## the model is a still thing with no bones in it.
##
## This is the same kind of fact as `scene_height`: something only the pack knows
## and only the table records. It is here rather than in a second table beside
## the first so that a tag still has exactly one row, and so that repointing a
## character at a different model cannot leave its animation behind on the old
## one. Which clip a character plays is not here and is not anywhere in the
## table: that is decided per frame from the simulation's state.
var scene_rig := ""

## Which biome colour the *model* follows, for a row that names a scene.
##
## A placeholder is a stack of parts and each part carries its own role, so a
## trunk can stay brown while the canopy above it takes the biome's green. A
## pack model has no such seam to hang two roles on -- KayKit draws a whole tree
## as one mesh with one surface, reading its brown and its green out of two
## corners of one texture atlas -- so a scene row carries one role for the whole
## model, and the trunk shifts along with the canopy. `scene_tint_role` is which
## of TINT_ROLES that is, TINT_NONE meaning the model keeps the colours the
## artist gave it.
var scene_tint_role := TINT_NONE

## How far towards the biome's colour the model goes, in [0, 1]. Zero, the
## default, leaves it alone; a row that names a role and leaves this at zero is
## saying nothing, which the asset report calls out.
##
## Unlike a placeholder part, which is *replaced* by the biome colour, a model
## is *shifted* by it: the tint is applied as the difference between the biome's
## colour and the colour the pack's own art already reads as, so the model's own
## light and shade -- and the difference between its brown and its green --
## survive. See AssetLibrary._scene_tint().
var scene_tint_mix := 0.0

## The placeholder, as a list of parts. Each part is a dictionary:
##   shape     -- one of SHAPES
##   size      -- Vector3 in world units (width, height, depth)
##   offset    -- Vector3, the part's centre relative to the tag's ground point
##   rotation  -- Vector3 of degrees, so a part can lie down or lean
##   color     -- the part's own colour, and the fallback when it has a role
##   tint_role -- one of TINT_ROLES; "" means the part keeps its own colour
##   tint_mix  -- how far towards the biome colour a roled part goes, in [0, 1]
##   emission  -- glow strength; 0 for everything that is not a light
var parts: Array[Dictionary] = []


func _init(for_tag: String = "") -> void:
	tag = for_tag


## A part, with the defaults filled in. Used to write the table compactly.
static func part(
	shape: String,
	size: Vector3,
	offset: Vector3,
	color: Color,
	tint_role: String = TINT_NONE,
	emission: float = 0.0,
	rotation: Vector3 = Vector3.ZERO,
	tint_mix: float = 0.75,
) -> Dictionary:
	return {
		"shape": shape,
		"size": size,
		"offset": offset,
		"rotation": rotation,
		"color": color,
		"tint_role": tint_role,
		"tint_mix": tint_mix,
		"emission": emission,
	}


## Which biome colour this row's *placeholder* takes, and how far towards it, as
## {"role": one of TINT_ROLES, "mix": float}. The role of whichever part goes
## furthest towards a biome colour, or TINT_NONE at mix 0 when no part takes one.
##
## Every row carries a placeholder underneath whatever model it names, because a
## checkout without the packs still has to draw a world. That makes the
## placeholder the row's own record of what the thing is *made of*, written
## before any pack existed: a fir's canopy takes the foliage colour and its trunk
## does not, a fence's slats take nothing at all. A model that arrives for the row
## is the same thing in better geometry, so it belongs to the same colour -- which
## is why this is what a row that names a model and says nothing about its colour
## is answered with, and what AssetLibrary.dropped_tints() holds a row that does
## say something against.
func placeholder_tint() -> Dictionary:
	var role := TINT_NONE
	var mix := 0.0
	for entry in parts:
		var part_role: String = entry["tint_role"]
		var part_mix := float(entry["tint_mix"])
		if part_role == TINT_NONE or part_mix <= 0.0:
			continue
		if part_mix > mix:
			role = part_role
			mix = part_mix
	return {"role": role, "mix": mix}


## Whether this row is still standing in for art that has not arrived.
func is_placeholder() -> bool:
	return scene_path.is_empty()


## How tall the placeholder stands, in world units. Zero for a scene row, whose
## size is a property of the file rather than of this description.
func height() -> float:
	var top := 0.0
	for entry in parts:
		var size: Vector3 = entry["size"]
		var offset: Vector3 = entry["offset"]
		top = maxf(top, offset.y + size.y * 0.5)
	return top


## How tall this visual stands as drawn, in world units, whichever form it takes.
## Zero when a scene row has not said, in which case whoever asked for a size has
## to settle for the model's own.
func natural_height() -> float:
	return height() if is_placeholder() else scene_height


## A detached copy: same values, no shared storage.
##
## The same reason BiomeProfile has one. The table's own rows are never handed
## out, because a caller that wrote into a row it was merely shown would be
## rewriting what every later lookup returns.
func detached_copy() -> AssetVisual:
	var copy := AssetVisual.new(tag)
	copy.scene_path = scene_path
	copy.scene_height = scene_height
	copy.scene_rig = scene_rig
	copy.scene_tint_role = scene_tint_role
	copy.scene_tint_mix = scene_tint_mix
	for entry in parts:
		copy.parts.append(entry.duplicate())
	return copy


## Whether this row's model is a rigged one, and so can be given an animation
## library and played. False for every placeholder, whose primitives have no
## bones to move.
func is_rigged() -> bool:
	return not is_placeholder() and not scene_rig.is_empty()


## Whether this row's model is shifted towards the biome colour where it stands.
## False for a placeholder row, whose parts carry their own roles instead.
func takes_scene_tint() -> bool:
	return (not is_placeholder()
		and scene_tint_role != TINT_NONE
		and scene_tint_mix > 0.0)


## A one-line description, for the asset report and for test failures.
func describe() -> String:
	if not is_placeholder():
		var rigged := "" if scene_rig.is_empty() else " rig %s" % scene_rig
		if takes_scene_tint():
			return "scene %s tinted %s %.2f%s" % [
				scene_path, scene_tint_role, scene_tint_mix, rigged,
			]
		return "scene %s%s" % [scene_path, rigged]
	if parts.is_empty():
		return "nothing"
	var shapes := PackedStringArray()
	for entry in parts:
		var shape: String = entry["shape"]
		var role: String = entry["tint_role"]
		shapes.append(shape if role.is_empty() else "%s:%s" % [shape, role])
	return "placeholder %s h=%.2f" % ["+".join(shapes), height()]
