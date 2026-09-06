extends RefCounted
## The mapping table: asset tag -> what it looks like. The only file in the
## project that is allowed to know what a tree is made of.
##
## Generation names tags. The biome catalog says a meadow may grow a "fir"; the
## settlement layer will say a village has a "house" and a "lantern_post"; the
## path layer will say a crossing needs a "bridge_wood". None of them says which
## model that is. This file answers that, once, for every tag in the catalog --
## and it is the only place the answer appears, so changing it is the whole cost
## of changing what the world looks like.
##
## A row's shape is `scene_path` first and primitives second, so installing a
## pack means filling in one string per row. Of the seventy rows, fifty-nine name
## a model out of an installed pack and eleven keep their primitives -- and every
## row carries the primitives underneath either way, so a checkout without the
## packs draws the old coloured world rather than an empty one.
## `./run_assets.sh` prints which is which and is the answer this comment is a
## snapshot of; reports/asset-packs.md says why each gap is a gap.
##
## A row points either straight at a pack model, for the tags the scatter layer
## sizes from `scene_height`, or at a wrapper scene under assets/tag_scenes/,
## for the placements nothing scales and which therefore have to arrive already
## the size the placeholder was. The README's "Dropping in the real asset packs"
## section is the procedure, tools/fetch_kaykit.sh installs the packs,
## tools/measure_models.sh is where `scene_height` comes from, and
## tools/repoint_tag_demo.sh demonstrates that a repoint touches nothing else.
##
## Either form takes the biome's colours where it stands. A placeholder part
## carries a tint role and is mixed towards the profile's colour for it; a model
## carries one role for the whole file and is *shifted* by the same profile, by
## the ratio between the biome's colour and the colour the pack's art already
## reads as -- which is what keeps a border shifting the trees and the rocks and
## not only the ground, the water and the fog. reports/model-tint.md is the
## write-up, tools/measure_tint.sh is what it costs, and `run_render.sh
## --no-model-tint` draws the models in the colours they ship in for comparison.
##
## Nothing in the simulation may reach this file. The simulation names tags and
## stops there, which tests/asset_check.gd enforces by failing if any file under
## sim/ ever names a scene, a path or a pack.

class_name AssetLibrary

## Where installed packs are expected to live. Only prose and a default: no row
## is required to sit under it, and a row may name any path the project can read.
const PACK_ROOT := "res://assets/"

# --- Placeholder palette -------------------------------------------------
# Fallback colours, used directly by parts that keep their own colour and as the
# base a biome-tinted part is mixed away from. These are not the world's
# palette -- the ground, foliage and rock colours come from the biome catalog in
# the simulation, and arrive here as a profile.

const WOOD := Color(0.42, 0.30, 0.20)
const DARK_WOOD := Color(0.28, 0.20, 0.14)
const LEAF := Color(0.30, 0.55, 0.30)
const DRY_LEAF := Color(0.46, 0.50, 0.30)
const STONE := Color(0.58, 0.58, 0.56)
const DARK_STONE := Color(0.40, 0.41, 0.42)
const THATCH := Color(0.68, 0.56, 0.32)
const PLASTER := Color(0.86, 0.82, 0.72)
const AMBER := Color(1.00, 0.72, 0.36)
const CLOTH := Color(0.72, 0.30, 0.32)
const PETAL := Color(0.94, 0.68, 0.80)
const CAP_RED := Color(0.80, 0.26, 0.24)
const STEEL := Color(0.72, 0.75, 0.80)
const LEATHER := Color(0.46, 0.32, 0.22)
const GLASS_GREEN := Color(0.40, 0.72, 0.46)
const CREAM := Color(0.90, 0.86, 0.74)
const MARSH_GLOW := Color(0.62, 0.94, 0.86)

# --- What the packs' own art already reads as ----------------------------
# A pack model arrives already coloured, and the tint has to be a *shift* from
# that rather than a replacement, or the model's own light, shade and detail
# would be flattened into one flat colour. These are the colours the installed
# art looks like it was drawn for -- open-meadow foliage, dry stone, meadow turf,
# daylight water -- and a model standing in a biome whose profile matches one of
# them comes out exactly as the artist drew it. Everywhere else it moves by the
# difference. LEAF and STONE do double duty: they are also the base a placeholder
# part of that role is mixed away from, which is what keeps a placeholder and a
# model reading as the same thing in the same biome.
const REFERENCE_TINTS := {
	AssetVisual.TINT_TREE: LEAF,
	AssetVisual.TINT_ROCK: STONE,
	AssetVisual.TINT_GROUND: Color(0.48, 0.72, 0.34),
	AssetVisual.TINT_WATER: Color(0.20, 0.46, 0.62),
}

## The most a tint may brighten one channel of a model.
##
## A ratio is unbounded upwards, and a multiply can only carry a texture so far
## before it clips. The blossom grove asks for three times the red the pack's
## green foliage has; the atlas draws foliage as a ramp from (0.13, 0.49, 0.22)
## up to (0.48, 0.73, 0.24), so at that gain the bright end of the ramp lands
## past white and a bush comes out cream rather than pink. This is where that
## stops. It binds in exactly one place -- the blossom grove's foliage; every
## other biome and role asks for 1.25 or less -- and reports/model-tint.md shows
## the three settings side by side and why this one was chosen.
const MAX_TINT_GAIN := 1.5

## How finely a tint multiplier is rounded before it becomes a material.
##
## The profile is a blend, so no two positions in the world have quite the same
## colour, and keying a material cache on the exact one would mean a material per
## instance -- which is what makes a thousand firs a thousand draw calls instead
## of one. Rounding to thirty-seconds of a channel is finer than the eye can
## follow across a gradient and coarse enough that a streamed radius shares a
## handful of materials. tools/measure_tint.sh is where that claim is measured.
const TINT_QUANTUM := 32.0

# --- The lit window ------------------------------------------------------
# Every building in a village carries one or two of these. The simulation says
# which wall and where along it; everything about how big, how high and how far
# off the wall the pane sits is here, because it is a fact about the model that
# actually stands there and generation has never seen one.

## How big a lit pane is, in world units: width across the wall, then height.
##
## Small. It is one window of a building four to eight units tall, and the
## smaller it is the more places on a hand-made model it fits flat against --
## which is what the fit below spends its time looking for.
const WINDOW_WIDTH := 0.45
const WINDOW_TALL := 0.45

## How high off a building's floor a pane is drawn when nothing moves it, in
## world units, and the storeys the fit may raise it to.
##
## 1.25 is a first-storey window, and it is low because the models are small:
## the installed cottage is four units to its ridge and its eaves come down over
## its wall by 1.5, so anything higher than this is in its roof. The others exist
## because the models are hand-made and not alike -- a workshop has a lean-to
## against its ground floor, so the lowest flat piece of wall a pane fits on is
## not at the same height on all six. The fit takes the lowest storey that has
## flat wall, so a cottage is lit at head height and a tower higher up.
##
## The ladder runs to 6.05 rather than stopping at the second storey because the
## village pack's tower is a watchtower on stilts: there is no wall at all below
## its platform, and every rung under 4.55 finds nothing but air between its legs.
## Stopping at 2.15 left ten of a village's lit windows with no wall to sit on.
## Rungs above the second cost only the depth map's extra rows, which are
## measured once per tag and per face and then cached, and no building that has
## a ground-floor wall ever reaches them -- the loop stops at the first rung that
## works.
const WINDOW_HEIGHT := 1.25
const WINDOW_STOREYS := [
	WINDOW_HEIGHT, 1.55, 1.85, 2.15, 2.45, 2.75, 3.05, 3.35, 3.65, 3.95,
	4.25, 4.55, 4.85, 5.15, 5.45, 5.75, 6.05,
]

## How far in front of the wall the pane stands, in world units.
##
## Enough that a flat pane never fights the wall it is on for the same depth, and
## enough to clear the slight bulge of a round tower's facets across the pane's
## own width. Not so much that it reads as a sign hung off the wall rather than a
## window in it.
const WINDOW_STANDOFF := 0.05

## How the facade of a model is measured, so that a pane can be put on flat wall
## rather than on the first thing that sticks out of it.
##
## A building is not a box. The installed tavern has a wing standing 1.8 in front
## of the boards beside it, the house has mullions 0.14 proud of its wall, and
## the tower is round with a canopy over its door. Taking the outermost point of
## a face and calling it the wall puts a pane on the canopy and leaves its
## corners hanging half a unit off the stonework.
##
## So a face is measured as a *depth map*: sliced into cells WINDOW_GRID_STEP
## across and the same up, over the whole band of heights a window may sit in,
## with every triangle of the model rasterised into it and each cell keeping the
## outermost surface over it. A pane may then only go where all of its own cells
## are covered and the deepest and shallowest of them differ by no more than
## WINDOW_FLATNESS -- which is to say, on flat wall its own size.
##
## 0.16 rather than something tighter because these walls are timbered: the
## installed cottage has framing 0.15 proud of the boards between it, and a pane
## that refused to cross a timber would have nowhere at all to go on a cottage.
## At 0.16 a pane may lie across framing, sitting at the framing's own depth with
## the boards 0.15 behind its corners -- which is what a window in a timber frame
## looks like anyway. Tightening it to 0.08 leaves eight of the fifteen faces
## with no legal spot at all, falling back to the least uneven place on each and
## putting every window on a face in the same place.
const WINDOW_GRID_STEP := 0.05
const WINDOW_FLATNESS := 0.16

## How many visuals this library has built, ever, in this process.
##
## A headless run must never build one, and this is how that is stated from the
## inside; the outside statement -- that a headless process never even loads
## this file -- is what run_headless.sh --assets reports and what
## tests/test_asset_tags.gd checks.
static var visuals_built := 0

## Whether a model built from a scene row takes the biome colour at all.
##
## Always true in the game. It exists so that "what the tint is doing" can be
## photographed rather than asserted: `run_render.sh --no-model-tint` draws the
## same world with the pack's own colours, which is what this layer did before
## the tint existed, and the two screenshots in reports/model-tint.md are that
## pair. It gates nothing but the override -- placeholders, terrain, water and
## fog still take their colours from the biome either way.
static var model_tint_enabled := true

# tag -> AssetVisual. Built once, never handed out directly.
static var _table := {}

# A cache of the materials the placeholders are drawn with, keyed by colour and
# glow, so that a thousand firs share one green rather than carrying a thousand
# copies of it.
static var _materials := {}

# The same cache for the tinted copies of a pack's own materials, keyed by which
# material of the pack was copied and by the rounded multiplier applied to it, so
# that every fir in one biome shares one material and the pack's own is never
# written to. It grows as a walker meets new blends and is never emptied, which is
# affordable because the rounding bounds how many distinct multipliers exist: a
# streamed radius holds 85 of them, and each is a small material with the pack's
# own textures shared by reference rather than copied.
static var _tinted_materials := {}

# Where each tag's model actually has wall, measured once per tag and face and
# kept, because a village asks the same five questions of the same five models
# for as long as the process lives. Cleared whenever the table is repointed.
static var _facades := {}

# The vertices of each tag's visual in its own frame, which is what the facade
# measurement above is taken from. Kept for the same reason and cleared with it.
static var _model_points := {}

# Each tag's visual collapsed into one mesh, for a layer that instances it. Kept
# and cleared for the same reasons: baking one means instantiating the whole
# visual, and a repoint means the bake is of the wrong model.
static var _baked := {}


## Every tag this table answers for, in the catalog's order.
static func tags() -> PackedStringArray:
	var known := PackedStringArray()
	for tag in AssetTags.all():
		if _built().has(tag):
			known.append(tag)
	return known


## Whether this table has a row for a tag.
static func has_visual(tag: String) -> bool:
	return _built().has(tag)


## The row for a tag, as a detached copy, or null for a tag with no row.
static func visual(tag: String) -> AssetVisual:
	var found: AssetVisual = _built().get(tag, null)
	if found == null:
		return null
	return found.detached_copy()


## How tall the visual for a tag stands as drawn, in world units, or zero when
## nothing is known -- an unknown tag, or a scene row whose height the art drop
## has not filled in.
##
## This is what turns the size generation asked for into a scale. Generation says
## "a fir seven units tall here"; the table knows a fir is 4.3 units as drawn; the
## shell divides.
static func natural_height(tag: String) -> float:
	var row: AssetVisual = _built().get(tag, null)
	return 0.0 if row == null else row.natural_height()


## Catalog tags this table has no row for. Empty is the only acceptable answer,
## and a test says so: a tag generation can name but nothing can draw would be a
## hole that only showed up as an invisible prop.
static func missing_tags() -> PackedStringArray:
	var missing := PackedStringArray()
	for tag in AssetTags.all():
		if not _built().has(tag):
			missing.append(tag)
	return missing


## Rows for names that are not catalog tags. Also expected to be empty: a row
## nothing can ask for is dead weight, and usually a typo.
static func unknown_rows() -> PackedStringArray:
	var unknown := PackedStringArray()
	for tag in _built().keys():
		if not AssetTags.is_tag(tag):
			unknown.append(tag)
	unknown.sort()
	return unknown


## Rows whose model drops or contradicts a biome colour their own placeholder
## takes: one string per offender, "tag: placeholder tree, model none". Expected
## to be empty, and the asset report fails when it is not.
##
## This is the other half of the guard in _row() below, and the half that catches
## a wrong answer rather than a missing one. The placeholder underneath a row says what
## the thing is made of; a model arriving for that row is the same thing in
## better geometry, so if the placeholder's branches take the foliage colour then
## the model's branches do too. A repoint that decides otherwise is not making an
## art choice, it is forgetting that the biome exists -- which is precisely the
## judgement that put an orange bare tree in the twilight marsh: its placeholder
## said `tree`, the model said nothing, and "wood is wood" looked reasonable right
## up until it was photographed. A model whose placeholder takes no colour is not
## constrained, because there is nothing there to drop.
static func dropped_tints() -> PackedStringArray:
	var dropped := PackedStringArray()
	for tag in AssetTags.all():
		var row: AssetVisual = _built().get(tag, null)
		if row == null or row.is_placeholder():
			continue
		var stood_for: String = row.placeholder_tint()["role"]
		if stood_for == AssetVisual.TINT_NONE or row.scene_tint_role == stood_for:
			continue
		var took := row.scene_tint_role
		if took == AssetVisual.TINT_NONE:
			took = "none"
		dropped.append("%s: placeholder %s, model %s" % [tag, stood_for, took])
	return dropped


## Point a tag at a different visual, replacing whatever it had.
##
## The permanent way to repoint a tag is to edit its row below -- that is the
## table, and that is what an art drop changes. This is the same operation done
## at run time, for a test that wants to show the swap costs nothing elsewhere,
## and for whoever eventually wants to preview a pack without restarting.
static func repoint(tag: String, to_visual: AssetVisual) -> void:
	var row := to_visual.detached_copy()
	row.tag = tag
	_built()[tag] = row
	_forget_measurements()


## Undo every repoint, back to the table as written below.
static func restore_defaults() -> void:
	_table = {}
	_forget_measurements()


## Drop what was measured off the models, because the models may have changed.
static func _forget_measurements() -> void:
	_facades = {}
	_model_points = {}
	_baked = {}


## Build the visual for a tag as something drawable, or null for an unknown tag.
##
## `profile` is the blended biome profile where the thing stands; parts that
## carry a tint role take their colour from it, so the same fir is deep green
## under canopy and bright green in the meadow without the table knowing either
## colour. Passing null gives every part its own fallback colour.
static func build(tag: String, profile: BiomeProfile = null) -> Node3D:
	var row: AssetVisual = _built().get(tag, null)
	if row == null:
		return null
	visuals_built += 1

	if not row.is_placeholder():
		var packed: PackedScene = load(row.scene_path)
		if packed == null:
			push_error("AssetLibrary: '%s' names %s, which will not load" % [
				tag, row.scene_path,
			])
			return null
		var instance := packed.instantiate()
		instance.name = tag
		if model_tint_enabled:
			_apply_scene_tint(instance, _scene_tint(row, profile))
		return instance as Node3D

	var root := Node3D.new()
	root.name = tag
	for entry in row.parts:
		root.add_child(_build_part(entry, profile))
	return root


## A tag's visual baked down to one mesh, for a layer that draws thousands of
## copies of it instead of one.
##
## `build()` hands back a little scene: a node with a model under it, or a stack
## of primitive parts. That is exactly right for a fir standing on a hillside and
## exactly wrong for ground cover, where the same thing is drawn ten thousand
## times and every node, every material and every draw call is paid ten thousand
## times over. So this collapses it: every mesh under the visual, moved into the
## visual's own frame, appended into a single surface with no material on it.
## What comes back is the numbers plus what is needed to draw them --
##
##   mesh       -- one ArrayMesh, one surface, positions, normals and a colour
##                 per vertex, in linear light
##   height     -- how tall it stands in its own frame, in world units
##   base_height -- how tall *one* copy of the row stands, which is the length a
##                 layer divides by to make a tuft a wanted number of units tall
##   reference  -- the colour its art already reads as, which is what a biome
##                 tint is a shift away from: the mean of the baked vertex
##                 colours, falling back to the row's tint role only when there
##                 are no vertices to average
##   vertices, triangles -- what one copy costs, for the cost measurement
##   blades     -- how many separate pieces of art the mesh is made of: the
##                 connected components of its triangles, which for a grass tuft
##                 is how many blades are standing in it
##   copies, reach -- how many copies of the row were baked in, and how far the
##                 furthest of them sits from the middle in the mesh's own frame
##
## `copies` above one bakes a *patch* rather than a single unit: that many
## copies of the row, spread over a square `span` wide in the mesh's own frame,
## each turned to its own heading and given its own size. That is how a layer
## gets ground cover out of a unit that is only a hand's breadth across without
## paying for one instance per hand's breadth -- a patch is still one instance,
## one transform and one row of the buffer, and holds `copies` times the art.
##
## The copies are placed on the R2 low-discrepancy sequence rather than on a grid
## or at random: a grid inside a patch would show as a grid once the patch is
## repeated across a field, and random points clump and leave holes at the dozen
## or so copies a patch holds. R2 fills the square evenly at every count.
##
## Each vertex also carries, in its second texture-coordinate channel, the
## position of the *root of its own copy* in the mesh's frame. Without it a
## shader has only `MODEL_MATRIX[3]`, the middle of the whole patch, and would
## bend every blade in a patch as one object -- one gust arriving on a patch at
## once, one character flattening all of it. With it a gust crosses a patch and a
## character parts only the blades near their feet.
##
## The material is deliberately dropped, and so is the texture. An instanced
## layer draws with one shader of its own, so a per-surface material would only
## be overridden by it -- and a texture is actively wrong here. A KayKit atlas is
## a palette: blocks of flat colour packed side by side. A tuft thirty
## centimetres across is a few pixels on screen, which is deep into the mip
## chain, and a mip of a palette is the average of colours that were never meant
## to be mixed -- which is why a field of it comes out a muddy yellow-green. So
## the palette is read *here*, once, at full resolution: every vertex is given
## the colour its own UV points at, and the mesh carries no texture at all.
## Fewer fetches, no bleeding, and the biome tint lands on an exact colour.
##
## Kept per tag, because baking instantiates the whole visual and a streamer asks
## for the same one every time a chunk appears.
static func instanced_mesh(tag: String, copies: int = 1, span: float = 0.0) -> Dictionary:
	copies = maxi(1, copies)
	span = maxf(0.0, span)
	var key := tag if copies == 1 else "%s|%d|%.4f" % [tag, copies, span]
	if _baked.has(key):
		return _baked[key]

	var answer := {
		"mesh": null, "height": 0.0, "base_height": 0.0,
		"reference": Color(1.0, 1.0, 1.0), "vertices": 0, "triangles": 0,
		"blades": 0, "copies": copies, "reach": 0.0,
	}
	var row: AssetVisual = _built().get(tag, null)
	if row == null:
		return answer

	if row.is_placeholder():
		if not row.parts.is_empty():
			answer["reference"] = row.parts[0]["color"]
	else:
		answer["reference"] = REFERENCE_TINTS.get(
			row.scene_tint_role, Color(1.0, 1.0, 1.0)
		)

	var built := build(tag, null)
	if built == null:
		_baked[key] = answer
		return answer

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_bake_into(built, Transform3D.IDENTITY, vertices, normals, colors, indices)
	built.free()

	if vertices.is_empty():
		_baked[key] = answer
		return answer

	var base_height := 0.0
	for vertex in vertices:
		base_height = maxf(base_height, vertex.y)
	var blades := _components_of(vertices, indices)

	# What the art reads as, *measured off the art* rather than taken from the
	# row's declared tint role.
	#
	# This is the number a tinted layer divides by: it multiplies every vertex by
	# (wanted / reference) so that the art's own light and shade survive being
	# recoloured, which only lands on the colour wanted if the reference really is
	# the mean colour of the vertices being multiplied. The row's tint role is a
	# statement of what the model is *for* -- foliage, rock, water -- and is not
	# that mean: the grass row's role colour is (0.30, 0.55, 0.30) while the mean
	# of the blades themselves is (0.42, 0.69, 0.23), a third less blue. Dividing
	# by the role colour therefore multiplied every blade's blue by 0.6 whatever
	# it was asked for, which is how grass came out a sharper yellow-green than
	# any biome ever requested. See reports/grass.md.
	#
	# The mean is over vertices and in linear light, because that is exactly what
	# the shader's multiply is over. It is converted back on the way out, since a
	# caller hands it colours in sRGB. One copy's worth of vertices is averaged
	# even when a patch is being baked: the copies carry the same colours, so the
	# answer is the same and does not depend on how many were asked for.
	if not colors.is_empty():
		var mean := Color(0.0, 0.0, 0.0)
		for colour in colors:
			mean += colour
		answer["reference"] = (mean / float(colors.size())).linear_to_srgb()

	# One copy or many, the mesh is assembled the same way: a list of placements,
	# each a transform, and every vertex of every copy stamped out through it
	# with the copy's own root written into the second texture-coordinate
	# channel. A single unit is the one-placement case of a patch.
	var placements := _patch_placements(copies, span)
	var patch_vertices := PackedVector3Array()
	var patch_normals := PackedVector3Array()
	var patch_colors := PackedColorArray()
	var patch_roots := PackedVector2Array()
	var patch_indices := PackedInt32Array()
	patch_vertices.resize(vertices.size() * placements.size())
	patch_normals.resize(vertices.size() * placements.size())
	patch_colors.resize(vertices.size() * placements.size())
	patch_roots.resize(vertices.size() * placements.size())
	patch_indices.resize(indices.size() * placements.size())
	var tallest := 0.0
	var reach := 0.0
	var vertex_at := 0
	var index_at := 0
	for placement: Transform3D in placements:
		var root := Vector2(placement.origin.x, placement.origin.z)
		reach = maxf(reach, root.length())
		var first := vertex_at
		for at in vertices.size():
			var moved := placement * vertices[at]
			patch_vertices[vertex_at] = moved
			patch_normals[vertex_at] = (placement.basis * normals[at]).normalized()
			patch_colors[vertex_at] = colors[at]
			patch_roots[vertex_at] = root
			tallest = maxf(tallest, moved.y)
			vertex_at += 1
		for at in indices.size():
			patch_indices[index_at] = first + indices[at]
			index_at += 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = patch_vertices
	arrays[Mesh.ARRAY_NORMAL] = patch_normals
	arrays[Mesh.ARRAY_COLOR] = patch_colors
	arrays[Mesh.ARRAY_TEX_UV2] = patch_roots
	arrays[Mesh.ARRAY_INDEX] = patch_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	answer["mesh"] = mesh
	answer["height"] = tallest
	answer["base_height"] = base_height
	answer["vertices"] = patch_vertices.size()
	answer["triangles"] = patch_indices.size() / 3
	answer["blades"] = blades * placements.size()
	answer["copies"] = placements.size()
	answer["reach"] = reach
	_baked[key] = answer
	return answer


## Where the copies of a patch stand, in the mesh's own frame.
##
## The R2 low-discrepancy sequence spreads them over a `span`-wide square; a
## heading and a size come off the same index so no two copies in a patch are
## the same shape, and the whole set is a pure function of the count and the
## span, so a patch is identical in every process that bakes it.
static func _patch_placements(copies: int, span: float) -> Array[Transform3D]:
	var placements: Array[Transform3D] = []
	if copies <= 1 or span <= 0.0:
		placements.append(Transform3D.IDENTITY)
		return placements
	# The plastic constant's reciprocal powers: the two-dimensional analogue of
	# the golden ratio, which is what makes the sequence fill a square evenly at
	# every count rather than only at squares of an integer.
	const R2_X := 0.7548776662466927
	const R2_Y := 0.5698402909980532
	for at in copies:
		var index := float(at + 1)
		var u := fmod(0.5 + R2_X * index, 1.0)
		var v := fmod(0.5 + R2_Y * index, 1.0)
		# A third irrational for the heading, so a copy's turn is unrelated to
		# where it stands and the patch has no visible grain.
		var yaw := fmod(0.3 + 0.4142135623730951 * index, 1.0) * TAU
		var size := 0.78 + 0.44 * fmod(0.7 + 0.6180339887498949 * index, 1.0)
		var turned := Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size))
		placements.append(Transform3D(
			turned, Vector3((u - 0.5) * span, 0.0, (v - 0.5) * span)
		))
	return placements


## How many separate pieces of art a baked surface is made of: the connected
## components of its triangles, welding vertices that share a position.
##
## For the grass row this is how many blades are standing in one tuft, which is
## the unit the coverage of a field is honestly counted in -- a tuft is not one
## blade, and a triangle is not one blade either.
static func _components_of(
	vertices: PackedVector3Array, indices: PackedInt32Array
) -> int:
	if indices.is_empty():
		return 0
	# Weld first: a baked surface has unshared vertices per triangle wherever the
	# art did, so without this every triangle is its own component.
	var welded := {}
	var owner := PackedInt32Array()
	owner.resize(vertices.size())
	for at in vertices.size():
		var spot := vertices[at].snapped(Vector3(0.0001, 0.0001, 0.0001))
		if not welded.has(spot):
			welded[spot] = at
		owner[at] = welded[spot]

	var parent := PackedInt32Array()
	parent.resize(vertices.size())
	for at in vertices.size():
		parent[at] = at
	for at in range(0, indices.size(), 3):
		var a := _root_of(parent, owner[indices[at]])
		var b := _root_of(parent, owner[indices[at + 1]])
		var c := _root_of(parent, owner[indices[at + 2]])
		if a != b:
			parent[b] = a
		if a != c:
			parent[_root_of(parent, c)] = a

	var roots := {}
	for at in range(0, indices.size(), 3):
		roots[_root_of(parent, owner[indices[at]])] = true
	return roots.size()


static func _root_of(parent: PackedInt32Array, at: int) -> int:
	var here := at
	while parent[here] != here:
		parent[here] = parent[parent[here]]
		here = parent[here]
	return here


## Append every mesh under a node into one set of arrays, in the frame of the
## node the walk started at, giving every vertex the colour its own material --
## or its material's texture, read at that vertex's UV -- says it is.
static func _bake_into(
	node: Node,
	so_far: Transform3D,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
) -> void:
	var here := so_far
	var spatial := node as Node3D
	if spatial != null:
		here = so_far * spatial.transform

	var mesh_view := node as MeshInstance3D
	if mesh_view != null and mesh_view.mesh != null:
		var mesh := mesh_view.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var surface_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if surface_vertices.is_empty():
				continue
			var surface_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var surface_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var surface_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

			var material := mesh_view.get_surface_override_material(surface)
			if material == null:
				material = mesh.surface_get_material(surface)
			var flat := Color(1.0, 1.0, 1.0)
			var palette: Image = null
			if material is StandardMaterial3D:
				flat = (material as StandardMaterial3D).albedo_color
				var texture := (material as StandardMaterial3D).albedo_texture
				if texture != null:
					palette = texture.get_image()
					if palette != null and palette.is_compressed():
						palette = palette.duplicate()
						palette.decompress()

			var first := vertices.size()
			for at in surface_vertices.size():
				vertices.append(here * surface_vertices[at])
				normals.append(
					(here.basis * surface_normals[at]).normalized()
					if at < surface_normals.size() else Vector3.UP
				)
				var art := flat
				if palette != null and at < surface_uvs.size():
					art = flat * _palette_at(palette, surface_uvs[at])
				# Stored in linear light, because a shader multiplying a tint
				# onto it works there and a vertex colour, unlike a texture,
				# arrives exactly as it was written.
				colors.append(art.srgb_to_linear())
			if surface_indices.is_empty():
				for at in surface_vertices.size():
					indices.append(first + at)
			else:
				for at in surface_indices:
					indices.append(first + at)

	for child in node.get_children():
		_bake_into(child, here, vertices, normals, colors, indices)


## One pixel of a palette, at full resolution, at the UV a vertex points at.
static func _palette_at(palette: Image, uv: Vector2) -> Color:
	var x := clampi(int(uv.x * float(palette.get_width())), 0, palette.get_width() - 1)
	var y := clampi(int(uv.y * float(palette.get_height())), 0, palette.get_height() - 1)
	return palette.get_pixel(x, y)


## Where a lit window goes on one building, in world units.
##
## The simulation placed the glow on the facade of the ground the building
## *reserved*, which is all it can do: it has never seen a model, and a reserved
## rectangle is deliberately roomier than whatever ends up standing in it. On the
## installed models that slack runs from 0.43 to 3.8 world units depending on the
## tag and the face, so a pane left where generation put it would hang in the air
## beside a house rather than sit on it. reports/window-glow.md has the table. This takes the two things generation
## really decided -- which wall, and where along it as a share of that wall --
## and puts them on the wall the model actually has there.
##
## Which is the same split as `natural_height()`: generation asks in world units,
## and the table, which is the only thing that has seen the model, does the
## arithmetic that turns that into where the art goes.
##
## Returns {x, z, yaw, height, fitted}. `height` is how high off the building's
## floor the pane's middle ends up, which is not always the same storey on every
## model. `fitted` is false when the model has no wall in the window band on that
## face at all, in which case the point is left exactly where generation put it.
static func window_glow_point(building: Dictionary, glow: Dictionary) -> Dictionary:
	var yaw := float(glow["yaw"])
	var host_yaw := float(building["yaw"])
	# Which face, as a quarter turn off the building's own facing, and then as a
	# direction in the model's own frame -- where local +Z is the way it looks.
	var turn := wrapf(yaw - host_yaw, -PI, PI)
	var face := Vector2(sin(turn), cos(turn))
	var side := Vector2(face.y, -face.x)

	# Where along the face generation put it, as a share of that face's half-span
	# on the reserved rectangle. That share is the part of its decision that
	# survives being moved onto a differently sized wall.
	var reserved_span := absf(face.y) * float(building["half_width"]) \
		+ absf(face.x) * float(building["half_depth"])
	var local := Settlement.footprint_local(
		building, float(glow["x"]), float(glow["z"])
	)
	var share := 0.0 if reserved_span <= 0.0 \
		else clampf(local.dot(side) / reserved_span, -1.0, 1.0)

	var wall := facade_window(String(building["tag"]), face, share)
	if not bool(wall["ok"]):
		return {
			"x": float(glow["x"]), "z": float(glow["z"]), "yaw": yaw,
			"height": WINDOW_HEIGHT, "fitted": false,
		}

	var at := face * (float(wall["depth"]) + WINDOW_STANDOFF) \
		+ side * float(wall["lateral"])
	var across := Vector2(cos(host_yaw), -sin(host_yaw))
	var along := Vector2(sin(host_yaw), cos(host_yaw))
	var world := Vector2(float(building["x"]), float(building["z"])) \
		+ across * at.x + along * at.y
	return {
		"x": world.x, "z": world.y, "yaw": yaw,
		"height": float(wall["height"]), "fitted": true,
	}


## Where a pane may go on one face of one tag's model, and how deep the wall is
## there.
##
## `face` is a direction in the model's own frame, as (local X, local Z).
## `share` is where along the face generation wanted it, in [-1, 1]. Returns
## {ok, depth, lateral, height}: how far out along `face` the wall is at the
## chosen spot, where across the face that spot is, and how high off the
## building's floor its middle sits -- all in the model's own frame and in world
## units. `ok` is false when the model has no wall on that side at all.
##
## The share does not land on the face proportionally -- it picks among the
## places on that face where a pane actually fits, in order. A share of -1 is the
## leftmost such place and +1 the rightmost, so generation's decision survives
## being moved onto a wall of a different width, and a wall with only one good
## spot puts every window in it rather than sliding some of them onto a beam.
static func facade_window(tag: String, face: Vector2, share: float) -> Dictionary:
	var spots := _facade_spots(tag, face)
	var laterals: PackedFloat32Array = spots["lateral"]
	if laterals.is_empty():
		return {"ok": false, "depth": 0.0, "lateral": 0.0, "height": WINDOW_HEIGHT}
	var depths: PackedFloat32Array = spots["depth"]
	var at := 0 if laterals.size() == 1 else int(round(
		(clampf(share, -1.0, 1.0) + 1.0) * 0.5 * float(laterals.size() - 1)
	))
	return {
		"ok": true,
		"depth": depths[at],
		"lateral": laterals[at],
		"height": float(spots["height"]),
	}


## Every place on one face where a pane sits flat against wall, in order across
## the face, with the depth of the wall at each and the storey they are on.
##
## The lowest storey that has anywhere at all wins: a lit window belongs on the
## ground floor unless the model's ground floor has no flat wall to put one on.
## If no storey has a flat enough piece, the least uneven place on the whole face
## is used, so a face always ends up with somewhere -- a round tower has no flat
## wall anywhere and still has to light a window.
static func _facade_spots(tag: String, face: Vector2) -> Dictionary:
	var key := "%s|%+.4f,%+.4f" % [tag, face.x, face.y]
	var cached: Dictionary = _facades.get(key, {})
	if not cached.is_empty():
		return cached

	var grid := _depth_map(tag, face)
	var columns := int(grid["columns"])
	var rows := int(grid["rows"])
	var covered: PackedByteArray = grid["covered"]
	var surface: PackedFloat32Array = grid["surface"]
	var half_wide := int(round(WINDOW_WIDTH * 0.5 / WINDOW_GRID_STEP))
	var half_tall := int(round(WINDOW_TALL * 0.5 / WINDOW_GRID_STEP))

	var answer := {
		"lateral": PackedFloat32Array(), "depth": PackedFloat32Array(),
		"height": WINDOW_HEIGHT,
	}
	var best_rough := INF
	var best_column := -1
	var best_row := 0
	var best_depth := 0.0
	for storey: float in WINDOW_STOREYS:
		var middle := int(round((storey - float(grid["floor"])) / WINDOW_GRID_STEP))
		if middle - half_tall < 0 or middle + half_tall >= rows:
			continue
		var lateral := PackedFloat32Array()
		var depth := PackedFloat32Array()
		for column in range(half_wide, columns - half_wide):
			var deepest := -INF
			var shallowest := INF
			var whole := true
			for step in range(column - half_wide, column + half_wide + 1):
				for row in range(middle - half_tall, middle + half_tall + 1):
					var cell := row * columns + step
					if covered[cell] == 0:
						whole = false
						break
					deepest = maxf(deepest, surface[cell])
					shallowest = minf(shallowest, surface[cell])
				if not whole:
					break
			if not whole:
				continue
			var rough := deepest - shallowest
			if rough < best_rough:
				best_rough = rough
				best_column = column
				best_row = middle
				best_depth = deepest
			if rough > WINDOW_FLATNESS:
				continue
			lateral.append(float(grid["low"]) + float(column) * WINDOW_GRID_STEP)
			depth.append(deepest)
		if not lateral.is_empty():
			answer = {"lateral": lateral, "depth": depth, "height": storey}
			break
	if (answer["lateral"] as PackedFloat32Array).is_empty() and best_column >= 0:
		var lateral := PackedFloat32Array()
		var depth := PackedFloat32Array()
		lateral.append(float(grid["low"]) + float(best_column) * WINDOW_GRID_STEP)
		depth.append(best_depth)
		answer = {
			"lateral": lateral, "depth": depth,
			"height": float(grid["floor"]) + float(best_row) * WINDOW_GRID_STEP,
		}
	_facades[key] = answer
	return answer


## One face of one model as a depth map: for each cell across the face and up it,
## how far out the model's outermost surface is there, and whether there is any
## surface there at all.
##
## Built by rasterising the model's triangles rather than by looking at where its
## vertices are, because a low-poly wall is one quad with four corners and
## nothing in between -- a vertex-only measurement would find no wall at all in
## the middle of it.
static func _depth_map(tag: String, face: Vector2) -> Dictionary:
	var side := Vector2(face.y, -face.x)
	var triangles := _triangles_of(tag)
	var floor_at: float = float(WINDOW_STOREYS[0]) - WINDOW_TALL * 0.5
	var ceiling: float = float(WINDOW_STOREYS[WINDOW_STOREYS.size() - 1]) \
		+ WINDOW_TALL * 0.5
	var rows := int(round((ceiling - floor_at) / WINDOW_GRID_STEP)) + 1

	# How wide the map has to be: the model's own reach across this face.
	var lowest := INF
	var highest := -INF
	for point in triangles:
		if point.y < floor_at - 0.5 or point.y > ceiling + 0.5:
			continue
		var at := Vector2(point.x, point.z).dot(side)
		lowest = minf(lowest, at)
		highest = maxf(highest, at)
	if lowest > highest:
		return {"low": 0.0, "floor": floor_at, "columns": 0, "rows": 0,
			"covered": PackedByteArray(), "surface": PackedFloat32Array()}

	var low := lowest - WINDOW_GRID_STEP
	var columns := int(ceil((highest - lowest) / WINDOW_GRID_STEP)) + 3
	var covered := PackedByteArray()
	var surface := PackedFloat32Array()
	covered.resize(columns * rows)
	surface.resize(columns * rows)

	var at_triangle := 0
	while at_triangle + 2 < triangles.size():
		var one := triangles[at_triangle]
		var two := triangles[at_triangle + 1]
		var three := triangles[at_triangle + 2]
		at_triangle += 3
		if maxf(one.y, maxf(two.y, three.y)) < floor_at:
			continue
		if minf(one.y, minf(two.y, three.y)) > ceiling:
			continue
		# The triangle in (across the face, up) with its depth as the value.
		var a := Vector3(Vector2(one.x, one.z).dot(side), one.y,
			Vector2(one.x, one.z).dot(face))
		var b := Vector3(Vector2(two.x, two.z).dot(side), two.y,
			Vector2(two.x, two.z).dot(face))
		var c := Vector3(Vector2(three.x, three.z).dot(side), three.y,
			Vector2(three.x, three.z).dot(face))
		var area := (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
		if is_zero_approx(area):
			continue
		var first := maxi(0, int(floor((minf(a.x, minf(b.x, c.x)) - low)
			/ WINDOW_GRID_STEP)))
		var last := mini(columns - 1, int(ceil((maxf(a.x, maxf(b.x, c.x)) - low)
			/ WINDOW_GRID_STEP)))
		var first_row := maxi(0, int(floor((minf(a.y, minf(b.y, c.y)) - floor_at)
			/ WINDOW_GRID_STEP)))
		var last_row := mini(rows - 1, int(ceil((maxf(a.y, maxf(b.y, c.y)) - floor_at)
			/ WINDOW_GRID_STEP)))
		for row in range(first_row, last_row + 1):
			var height := floor_at + float(row) * WINDOW_GRID_STEP
			for column in range(first, last + 1):
				var across := low + float(column) * WINDOW_GRID_STEP
				var weight_a := ((b.x - across) * (c.y - height)
					- (c.x - across) * (b.y - height)) / area
				if weight_a < 0.0:
					continue
				var weight_b := ((c.x - across) * (a.y - height)
					- (a.x - across) * (c.y - height)) / area
				if weight_b < 0.0:
					continue
				var weight_c := 1.0 - weight_a - weight_b
				if weight_c < 0.0:
					continue
				var depth := weight_a * a.z + weight_b * b.z + weight_c * c.z
				var cell := row * columns + column
				if covered[cell] == 0 or depth > surface[cell]:
					covered[cell] = 1
					surface[cell] = depth
	return {"low": low, "floor": floor_at, "columns": columns, "rows": rows,
		"covered": covered, "surface": surface}


## Every triangle of a tag's visual, in the tag's own frame, as flat triples.
##
## Built the same way for both forms of row: a scene row is instanced, a
## placeholder row's parts are turned into the same meshes `build()` would give
## them. So a checkout with no packs installed measures its own primitives and
## the fit above still lands a pane on a wall.
static func _triangles_of(tag: String) -> PackedVector3Array:
	if _model_points.has(tag):
		return _model_points[tag]
	var points := PackedVector3Array()
	var row: AssetVisual = _built().get(tag, null)
	var node: Node3D = null
	if row != null and not row.is_placeholder():
		var packed: PackedScene = load(row.scene_path)
		if packed != null:
			node = packed.instantiate() as Node3D
	elif row != null:
		node = Node3D.new()
		for entry in row.parts:
			var view := MeshInstance3D.new()
			view.mesh = _mesh_for(entry["shape"], entry["size"])
			view.position = entry["offset"]
			view.rotation_degrees = entry["rotation"]
			node.add_child(view)
	if node != null:
		_gather_triangles(node, Transform3D.IDENTITY, points)
		node.free()
	_model_points[tag] = points
	return points


static func _gather_triangles(
	node: Node, at: Transform3D, into: PackedVector3Array
) -> void:
	var here := at
	if node is Node3D:
		here = at * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_VERTEX:
					continue
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var order := PackedInt32Array()
				if arrays[Mesh.ARRAY_INDEX] != null:
					order = arrays[Mesh.ARRAY_INDEX]
				if order.is_empty():
					for vertex in verts:
						into.append(here * vertex)
				else:
					for index in order:
						into.append(here * verts[index])
	for child in node.get_children():
		_gather_triangles(child, here, into)


static func _build_part(entry: Dictionary, profile: BiomeProfile) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = _mesh_for(entry["shape"], entry["size"])
	view.position = entry["offset"]
	view.rotation_degrees = entry["rotation"]
	view.material_override = _material_for(
		_colour_of(entry, profile), float(entry["emission"])
	)
	return view


## The colour a part ends up: its own, or a mix towards the biome's colour for
## the role it carries.
static func _colour_of(entry: Dictionary, profile: BiomeProfile) -> Color:
	var own: Color = entry["color"]
	var role: String = entry["tint_role"]
	if profile == null or role == AssetVisual.TINT_NONE:
		return own
	var biome := own
	match role:
		AssetVisual.TINT_TREE:
			biome = profile.tree_tint
		AssetVisual.TINT_ROCK:
			biome = profile.rock_tint
		AssetVisual.TINT_GROUND:
			biome = profile.ground_tint
		AssetVisual.TINT_WATER:
			biome = profile.water_tint
	return own.lerp(biome, clampf(float(entry["tint_mix"]), 0.0, 1.0))


## The multiplier a model's own colours are scaled by where it stands: white for
## a row that takes no tint or a build with no profile, and otherwise the biome's
## colour for the row's role divided by the colour the pack's art already reads
## as, walked back towards white by however far short of 1.0 the row's mix is.
##
## Division rather than replacement is the whole trick. A KayKit tree is one mesh
## with one surface reading a brown trunk and a green canopy out of two corners of
## one atlas, so there is nothing to give two roles to; but scaling the *whole*
## surface by the ratio between this biome's foliage green and open-meadow green
## moves the canopy to the biome's green and carries the trunk along by the same
## proportion -- darker and cooler under canopy, unchanged in the meadow, pink in
## a blossom grove. The compromise is that the trunk does move: reports/model-tint.md
## says so and shows it.
static func _scene_tint(row: AssetVisual, profile: BiomeProfile) -> Color:
	if profile == null or not row.takes_scene_tint():
		return Color(1.0, 1.0, 1.0)
	var reference: Color = REFERENCE_TINTS.get(row.scene_tint_role, Color(1.0, 1.0, 1.0))
	var biome := _role_colour(row.scene_tint_role, profile, reference)
	var mix := clampf(row.scene_tint_mix, 0.0, 1.0)
	var gain := Color(
		_channel_gain(biome.r, reference.r),
		_channel_gain(biome.g, reference.g),
		_channel_gain(biome.b, reference.b),
	)
	return _quantised(Color(1.0, 1.0, 1.0).lerp(gain, mix))


## One channel of that ratio, floored so a near-black reference cannot divide by
## nothing and ceilinged so a bright texel cannot be driven into the bloom.
static func _channel_gain(biome: float, reference: float) -> float:
	return clampf(biome / maxf(reference, 0.02), 0.0, MAX_TINT_GAIN)


## The biome's colour for a tint role, or a fallback for TINT_NONE.
static func _role_colour(role: String, profile: BiomeProfile, fallback: Color) -> Color:
	match role:
		AssetVisual.TINT_TREE:
			return profile.tree_tint
		AssetVisual.TINT_ROCK:
			return profile.rock_tint
		AssetVisual.TINT_GROUND:
			return profile.ground_tint
		AssetVisual.TINT_WATER:
			return profile.water_tint
	return fallback


## A colour rounded to the cache's grid, so that neighbours in a gradient land on
## the same material instead of on one each.
static func _quantised(colour: Color) -> Color:
	return Color(
		roundf(colour.r * TINT_QUANTUM) / TINT_QUANTUM,
		roundf(colour.g * TINT_QUANTUM) / TINT_QUANTUM,
		roundf(colour.b * TINT_QUANTUM) / TINT_QUANTUM,
	)


## Hang a tinted copy of every material this model draws with on the *instance*,
## as a surface override, leaving the mesh and the material the pack loaded
## exactly as they were.
##
## This is the one place the difference matters. `mesh.surface_set_material()`
## would write through to the resource the whole world shares, so tinting one fir
## would repaint every fir already standing; a surface override belongs to this
## MeshInstance3D alone. tests/test_asset_tags.gd builds the same tag in two
## biomes and checks both halves of that: two colours out, and the pack's own
## material still the colour it was loaded as.
static func _apply_scene_tint(node: Node, multiplier: Color) -> void:
	if multiplier == Color(1.0, 1.0, 1.0):
		return
	var mesh_view := node as MeshInstance3D
	if mesh_view != null:
		if mesh_view.material_override != null:
			mesh_view.material_override = _tinted_material(
				mesh_view.material_override, multiplier
			)
		var mesh := mesh_view.mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var source := mesh_view.get_surface_override_material(surface)
				if source == null:
					source = mesh.surface_get_material(surface)
				if source == null:
					continue
				mesh_view.set_surface_override_material(
					surface, _tinted_material(source, multiplier)
				)
	for child in node.get_children():
		_apply_scene_tint(child, multiplier)


## A copy of one of the pack's materials with its albedo scaled by the tint,
## shared by every instance that lands on the same rounded multiplier.
##
## A material the renderer cannot reason about -- anything that is not a
## StandardMaterial3D or an ORMMaterial3D -- is handed back untouched rather than
## guessed at; no installed pack ships one, and a pack that did would draw in its
## own colours instead of being mangled.
static func _tinted_material(source: Material, multiplier: Color) -> Material:
	var base := source as BaseMaterial3D
	if base == null:
		return source
	var key := "%s|%d|%.3f,%.3f,%.3f" % [
		source.resource_path, source.get_instance_id(),
		multiplier.r, multiplier.g, multiplier.b,
	]
	var cached: Material = _tinted_materials.get(key, null)
	if cached != null:
		return cached
	var tinted: BaseMaterial3D = base.duplicate()
	var own := base.albedo_color
	tinted.albedo_color = Color(
		own.r * multiplier.r, own.g * multiplier.g, own.b * multiplier.b, own.a
	)
	_tinted_materials[key] = tinted
	return tinted


## Faceted, low-segment primitives on purpose: the look is flat-shaded chunky
## solids, and a sphere with eight segments reads as a hand-carved pebble where a
## smooth one reads as a ball bearing.
static func _mesh_for(shape: String, size: Vector3) -> Mesh:
	match shape:
		AssetVisual.SHAPE_BOX:
			var box := BoxMesh.new()
			box.size = size
			return box
		AssetVisual.SHAPE_SPHERE:
			var sphere := SphereMesh.new()
			sphere.radius = size.x * 0.5
			sphere.height = size.y
			sphere.radial_segments = 8
			sphere.rings = 4
			return sphere
		AssetVisual.SHAPE_CONE:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = size.x * 0.5
			cone.height = size.y
			cone.radial_segments = 7
			cone.rings = 0
			return cone
		AssetVisual.SHAPE_CYLINDER:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = size.x * 0.5
			cylinder.bottom_radius = size.x * 0.5
			cylinder.height = size.y
			cylinder.radial_segments = 7
			cylinder.rings = 0
			return cylinder
		AssetVisual.SHAPE_CAPSULE:
			var capsule := CapsuleMesh.new()
			capsule.radius = size.x * 0.5
			capsule.height = maxf(size.y, size.x + 0.01)
			capsule.radial_segments = 7
			capsule.rings = 3
			return capsule
		AssetVisual.SHAPE_PRISM:
			var prism := PrismMesh.new()
			prism.size = size
			return prism
		AssetVisual.SHAPE_TORUS:
			var torus := TorusMesh.new()
			torus.outer_radius = size.x * 0.5
			torus.inner_radius = maxf(0.01, size.x * 0.5 - size.y)
			torus.rings = 8
			torus.ring_segments = 5
			return torus
		AssetVisual.SHAPE_PLANE:
			var plane := PlaneMesh.new()
			plane.size = Vector2(size.x, size.z)
			plane.orientation = PlaneMesh.FACE_Z
			return plane
	push_error("AssetLibrary: unknown placeholder shape '%s'" % shape)
	var fallback := BoxMesh.new()
	fallback.size = size
	return fallback


static func _material_for(colour: Color, emission: float) -> StandardMaterial3D:
	var key := "%.3f,%.3f,%.3f,%.2f" % [colour.r, colour.g, colour.b, emission]
	var cached: StandardMaterial3D = _materials.get(key, null)
	if cached != null:
		return cached
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	# Flat-shaded: the facets are the style, so the normals must not be smoothed
	# across them.
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material


# --- The table -----------------------------------------------------------
#
# One row per catalog tag. To repoint a tag at a real model, set `scene_path` on
# its row and leave everything else alone; the placeholder parts stay as the
# fallback for a machine that does not have the pack installed.

static func _built() -> Dictionary:
	if not _table.is_empty():
		return _table
	var rows := {}

	# --- Flora -----------------------------------------------------------

	# The one row in this table that is *instanced* rather than placed: the grass
	# layer bakes it down to a single mesh and draws thousands of copies of it
	# per view, so the model's own triangle count is what the layer costs. The
	# row named Grass_1_C, the pack's big double-sided clump, at 396 triangles a
	# copy -- fine for something placed once, nine and a half times too much for
	# something placed ten thousand times. This is the single-sided variant of
	# the medium clump: the same round silhouette in 42 triangles. Single-sided
	# is right for grass anyway, because the wind shader draws both faces and
	# lights them as if they faced the sky. Grass_2 rather than Grass_1 because
	# the pack draws two kinds under that name and only one of them is grass:
	# Grass_1 is a rosette of broad leaves, which reads as a ground plant, and
	# Grass_2 is a fan of tall narrow blades, which reads as turf.
	_row(rows, AssetTags.GRASS, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Grass_2_B_Singlesided_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(0.14, 0.42, 0.05), Vector3(0.0, 0.21, 0.0),
			LEAF, AssetVisual.TINT_TREE),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(0.12, 0.32, 0.05), Vector3(0.12, 0.16, 0.07),
			LEAF, AssetVisual.TINT_TREE, 0.0, Vector3(0.0, 40.0, 12.0)),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(0.12, 0.36, 0.05), Vector3(-0.11, 0.18, -0.06),
			LEAF, AssetVisual.TINT_TREE, 0.0, Vector3(0.0, -50.0, -10.0)),
	], 0.919, AssetVisual.TINT_TREE, 0.75)
	# A clump of white daisies with their own leaves, at 490 triangles the fullest
	# of the pack's five flowers -- Flower_01 is 122 triangles but only 0.18 tall
	# and reads as a speck of dirt at the size a meadow grows one, and Flower_04's
	# yellow reads as a dandelion rather than as the meadow flower this is.
	# It takes the foliage tint at the flora's usual strength, which the placeholder
	# stem already did: the meadow's foliage colour *is* the reference, so a meadow
	# daisy stays white, and a blossom grove turns it pink and a marsh turns it
	# cold, which is the point.
	_row(rows, AssetTags.FLOWER, "res://assets/justcreate_village/Nature/Flower_05.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 0.34, 0.05), Vector3(0.0, 0.17, 0.0),
			LEAF, AssetVisual.TINT_TREE),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.20, 0.14, 0.20), Vector3(0.0, 0.38, 0.0),
			Color(0.96, 0.84, 0.40)),
	], 0.322, AssetVisual.TINT_TREE, 0.75)
	_row(rows, AssetTags.FERN, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Bush_3_A_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(0.55, 0.70, 0.08), Vector3(0.0, 0.35, 0.0),
			LEAF, AssetVisual.TINT_TREE),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(0.45, 0.58, 0.08), Vector3(0.0, 0.29, 0.0),
			LEAF, AssetVisual.TINT_TREE, 0.0, Vector3(0.0, 65.0, 0.0)),
	], 0.485, AssetVisual.TINT_TREE, 0.75)
	_row(rows, AssetTags.BUSH, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Bush_2_C_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(1.10, 0.85, 1.10), Vector3(0.0, 0.40, 0.0),
			LEAF, AssetVisual.TINT_TREE),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.70, 0.55, 0.70), Vector3(0.38, 0.28, 0.22),
			LEAF, AssetVisual.TINT_TREE),
	], 1.320, AssetVisual.TINT_TREE, 0.75)
	_row(rows, AssetTags.HARDY_SHRUB, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Bush_4_A_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.80, 0.45, 0.80), Vector3(0.0, 0.22, 0.0),
			DRY_LEAF, AssetVisual.TINT_TREE, 0.0, Vector3.ZERO, 0.55),
	], 0.434, AssetVisual.TINT_TREE, 0.55)
	_row(rows, AssetTags.REED, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Grass_2_C_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.06, 1.30, 0.06), Vector3(0.0, 0.65, 0.0),
			DRY_LEAF, AssetVisual.TINT_TREE, 0.0, Vector3(0.0, 0.0, 5.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 1.05, 0.05), Vector3(0.14, 0.52, 0.10),
			DRY_LEAF, AssetVisual.TINT_TREE, 0.0, Vector3(4.0, 0.0, -8.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 1.45, 0.05), Vector3(-0.12, 0.72, 0.06),
			DRY_LEAF, AssetVisual.TINT_TREE, 0.0, Vector3(-6.0, 0.0, 3.0)),
	], 0.935, AssetVisual.TINT_TREE, 0.75)
	# A real cattail: thin stalks with brown heads, 348 triangles, 0.688 tall as
	# drawn. What it replaces was a 0.247-tall pond plant blown up 5.3 times to
	# reach the 1.3 units a bank asks for, which made a cattail a metre wide;
	# this one only has to grow 1.9 times and stays a stalk.
	_row(rows, AssetTags.CATTAIL, "res://assets/justcreate_village/Nature/Reeds_01.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 1.20, 0.05), Vector3(0.0, 0.60, 0.0),
			DRY_LEAF, AssetVisual.TINT_TREE),
		AssetVisual.part(AssetVisual.SHAPE_CAPSULE, Vector3(0.16, 0.42, 0.16), Vector3(0.0, 1.34, 0.0),
			Color(0.38, 0.24, 0.16)),
	], 0.688, AssetVisual.TINT_TREE, 0.60)
	_row(rows, AssetTags.LILY_PAD, "res://assets/kaykit_medieval_hexagon/KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/decoration/nature/waterlily_A.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.90, 0.05, 0.90), Vector3(0.0, 0.03, 0.0),
			LEAF, AssetVisual.TINT_TREE, 0.0, Vector3.ZERO, 0.45),
	], 0.017, AssetVisual.TINT_TREE, 0.45)
	# The brown cone-capped mushroom, and at 90 triangles the cheapest of the
	# pack's seven -- which is what a tag scattered across every forest floor
	# should be. Mushroom_01 is the red toadstool and belongs to the row below;
	# Mushroom_05 and _07 are clusters of thin stalks that disappear at this size.
	#
	# It takes the foliage tint although its placeholder took none, which is an
	# addition rather than a drop: a mushroom is undergrowth and stands in the
	# same light as the ferns beside it, so a deep forest darkens it and a marsh
	# cools it. Under the flora's usual strength because a cap is not a leaf.
	_row(rows, AssetTags.MUSHROOM, "res://assets/justcreate_village/Nature/Mushroom_03.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.14, 0.30, 0.14), Vector3(0.0, 0.15, 0.0), CREAM),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.46, 0.28, 0.46), Vector3(0.0, 0.32, 0.0),
			Color(0.62, 0.46, 0.30)),
	], 0.393, AssetVisual.TINT_TREE, 0.60)
	# The red cap with white spots, drawn exactly as the placeholder described it:
	# 328 triangles against Mushroom_03's 90, which buys the spots and the flare
	# of the cap, and worth paying because a toadstool is the marsh's signature
	# and there are far fewer of them than there are mushrooms.
	#
	# The one repointed row that deliberately keeps the pack's own colours. Its
	# placeholder took none either -- the red *is* the tag -- and shifting a red
	# cap by a marsh's teal foliage colour would take the red out of the one
	# thing in the marsh that is meant to be warm. The warmth it loses is the
	# placeholder's emissive cap, which the model does not have; the point light
	# Atmosphere hangs on this tag in gloomy biomes is untouched and is what
	# actually lights the ground around it.
	_row(rows, AssetTags.TOADSTOOL, "res://assets/justcreate_village/Nature/Mushroom_01.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.16, 0.40, 0.16), Vector3(0.0, 0.20, 0.0), CREAM),
		# A faint glow, on theme with the marsh it mostly grows in and with the
		# minion it shares a name with.
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.60, 0.34, 0.60), Vector3(0.0, 0.42, 0.0),
			CAP_RED, AssetVisual.TINT_NONE, 0.35),
	], 0.352, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.PETAL_DRIFT, "", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.22, 0.02, 0.16), Vector3(0.10, 0.01, 0.06),
			PETAL, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 25.0, 0.0)),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.18, 0.02, 0.14), Vector3(-0.14, 0.01, -0.09),
			PETAL, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, -40.0, 0.0)),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.20, 0.02, 0.15), Vector3(0.02, 0.01, -0.20),
			PETAL, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 70.0, 0.0)),
	])
	_row(rows, AssetTags.FIR, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Tree_4_A_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.34, 1.20, 0.34), Vector3(0.0, 0.60, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_CONE, Vector3(2.00, 2.40, 2.00), Vector3(0.0, 2.00, 0.0),
			LEAF, AssetVisual.TINT_TREE),
		AssetVisual.part(AssetVisual.SHAPE_CONE, Vector3(1.40, 1.80, 1.40), Vector3(0.0, 3.40, 0.0),
			LEAF, AssetVisual.TINT_TREE),
	], 5.274, AssetVisual.TINT_TREE, 0.75)
	_row(rows, AssetTags.CANOPY_TREE, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Tree_1_B_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.70, 4.60, 0.70), Vector3(0.0, 2.30, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(4.60, 3.60, 4.60), Vector3(0.0, 5.40, 0.0),
			LEAF, AssetVisual.TINT_TREE),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(2.80, 2.20, 2.80), Vector3(1.10, 4.20, -0.80),
			LEAF, AssetVisual.TINT_TREE),
	], 4.930, AssetVisual.TINT_TREE, 0.75)
	# The one row whose mix runs the other way. The placeholder was pink already
	# and barely tinted, because a blossom grove is pink whatever the biome around
	# it is doing; the pack's round tree is green, and the *only* thing that makes
	# it pink is the grove's own foliage colour, so it takes the tint at full
	# strength. reports/model-tint.md is where that swap is shown and argued.
	_row(rows, AssetTags.BLOSSOM_TREE, "", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.50, 2.60, 0.50), Vector3(0.0, 1.30, 0.0), WOOD),
		# Barely tinted: the point of a blossom grove is that its canopy is pink
		# whatever the biome around it is doing.
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(3.20, 2.20, 3.20), Vector3(0.0, 3.20, 0.0),
			PETAL, AssetVisual.TINT_TREE, 0.0, Vector3.ZERO, 0.20),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(1.90, 1.40, 1.90), Vector3(-0.90, 2.60, 0.70),
			PETAL, AssetVisual.TINT_TREE, 0.0, Vector3.ZERO, 0.20),
	])
	# The one row where the tint is doing a job no other row asks of it. A bare
	# tree has no canopy, so its whole model is bark -- and the pack draws that
	# bark a warm orange-brown. Left untinted it was the brightest thing in a
	# twilight marsh, a row of orange sticks against the teal, which reads as a
	# missing tint rather than as a dead tree. Taking the foliage role fixes it
	# without a second rule: the gain is the biome's foliage colour over the
	# reference green, which in the marsh is (0.40, 0.40, 0.93) -- it takes the
	# red out and leaves the blue, so the bark goes cold. In the meadow, whose
	# foliage colour *is* the reference, the gain is exactly white and the tree
	# is the brown the pack drew.
	#
	# At full strength rather than the living trees' 0.75, for the same reason the
	# blossom tree above is: a canopy tree's green is already most of the way to
	# any biome's green and only needs nudging, but a bare tree has no canopy at
	# all -- the warm bark *is* the whole model -- so the only thing that can make
	# it belong to the marsh is the tint, and at three quarters it still came out
	# the warmest object in a teal frame.
	_row(rows, AssetTags.DEAD_TREE, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Tree_Bare_1_B_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.42, 3.20, 0.42), Vector3(0.0, 1.60, 0.0),
			DARK_WOOD, AssetVisual.TINT_TREE, 0.0, Vector3.ZERO, 0.45),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.16, 1.20, 0.16), Vector3(0.45, 2.40, 0.10),
			DARK_WOOD, AssetVisual.TINT_TREE, 0.0, Vector3(0.0, 0.0, -55.0), 0.45),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.14, 0.95, 0.14), Vector3(-0.38, 2.80, -0.15),
			DARK_WOOD, AssetVisual.TINT_TREE, 0.0, Vector3(0.0, 0.0, 48.0), 0.45),
	], 3.251, AssetVisual.TINT_TREE, 1.0)
	# The same row as the dead tree, for the same reason and at the same strength:
	# a felled log is bare bark from end to end, the pack draws that bark the same
	# warm orange, and it lies in the same twilight ground the dead trees stand
	# in. Fixing one and not the other would have left the marsh with a bright
	# orange log in it.
	# A felled log with its bark and cut ends, 232 triangles against the KayKit
	# billet's, and 1.758 long as drawn where that one was 1.350 -- so it grows
	# less to reach the 1.3 to 2.2 units of length generation asks for. Log_02 and
	# Log_03 are a mossy stump and a pile; this is the one that lies down.
	#
	# `scene_height` here is the log's *length*, as it was for the model this
	# replaces, because that is what generation means by the size of a log.
	_row(rows, AssetTags.FALLEN_LOG, "res://assets/justcreate_village/Nature/Log_01.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.55, 2.80, 0.55), Vector3(0.0, 0.28, 0.0),
			DARK_WOOD, AssetVisual.TINT_TREE, 0.0, Vector3(90.0, 20.0, 0.0), 0.45),
	], 1.758, AssetVisual.TINT_TREE, 1.0)

	# What hangs off the underside of a floating island. No pack has one -- a
	# torn root hanging into the air is not a thing a forest pack ships -- so
	# this is a placeholder for now.
	#
	# It is built *upwards* from its node, thickest at the top and tapering to a
	# tip, and its node is put at the bottom of the root rather than the top.
	# That is the one convention every tag in this table follows: a thing
	# occupies the `natural_height` above where it was placed. The simulation
	# places a root by handing over the height of its lower end, which is what
	# lets the same rule put the thick end exactly on the keel it hangs from.
	_row(rows, AssetTags.HANGING_ROOT, "", [
		AssetVisual.part(AssetVisual.SHAPE_CONE, Vector3(0.34, 1.60, 0.34), Vector3(0.0, 0.80, 0.0),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(180.0, 0.0, 0.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.12, 0.70, 0.12), Vector3(0.13, 1.10, 0.06),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 0.0, 14.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.10, 0.55, 0.10), Vector3(-0.11, 1.25, -0.08),
			WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(9.0, 0.0, -11.0)),
	])

	# --- Rocks -----------------------------------------------------------

	_row(rows, AssetTags.PEBBLE, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Rock_2_A_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.55, 0.38, 0.55), Vector3(0.0, 0.15, 0.0),
			STONE, AssetVisual.TINT_ROCK),
	], 0.216, AssetVisual.TINT_ROCK, 0.75)
	_row(rows, AssetTags.GRAVEL, "res://assets/kaykit_medieval_hexagon/KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/decoration/nature/rock_single_A.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.22, 0.14, 0.22), Vector3(0.10, 0.06, 0.05),
			STONE, AssetVisual.TINT_ROCK),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.17, 0.11, 0.17), Vector3(-0.13, 0.05, 0.11),
			STONE, AssetVisual.TINT_ROCK),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.20, 0.12, 0.20), Vector3(0.01, 0.05, -0.15),
			STONE, AssetVisual.TINT_ROCK),
	], 0.069, AssetVisual.TINT_ROCK, 0.75)
	_row(rows, AssetTags.BOULDER, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Rock_1_D_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(2.40, 1.80, 2.40), Vector3(0.0, 0.75, 0.0),
			STONE, AssetVisual.TINT_ROCK),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(1.30, 0.95, 1.30), Vector3(1.05, 0.40, 0.45),
			STONE, AssetVisual.TINT_ROCK),
	], 1.130, AssetVisual.TINT_ROCK, 0.75)
	_row(rows, AssetTags.ROCK_SPIRE, "res://assets/kaykit_forest_nature/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/Rock_3_I_Color1.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CONE, Vector3(1.40, 3.80, 1.40), Vector3(0.0, 1.90, 0.0),
			DARK_STONE, AssetVisual.TINT_ROCK, 0.0, Vector3(3.0, 0.0, 5.0)),
	], 2.109, AssetVisual.TINT_ROCK, 0.75)
	_row(rows, AssetTags.STONE_HENGE, "res://assets/tag_scenes/stone_henge.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.80, 3.40, 0.60), Vector3(-1.60, 1.70, 0.0),
			DARK_STONE, AssetVisual.TINT_ROCK, 0.0, Vector3(0.0, 0.0, 2.0)),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.80, 3.40, 0.60), Vector3(1.60, 1.70, 0.0),
			DARK_STONE, AssetVisual.TINT_ROCK, 0.0, Vector3(0.0, 0.0, -3.0)),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(4.20, 0.60, 0.70), Vector3(0.0, 3.70, 0.0),
			DARK_STONE, AssetVisual.TINT_ROCK),
	], 4.000, AssetVisual.TINT_ROCK, 0.75)

	# --- Props -----------------------------------------------------------

	# A rail fence, 120 triangles, 2.381 long and 1.020 tall as drawn. The wrapper
	# turns it a quarter turn, because the pack lays a fence along its own X and
	# every row in this table lays a long thing along Z, and scales it by 1.092 --
	# which is the length clamp rather than the height match. A fence closes the
	# gap between two buildings on a village ring, so it is the length that must
	# not burst the layout; matching the placeholder's height instead would have
	# made it 2.89 long against the 2.60 the ring was laid out for.
	_row(rows, AssetTags.FENCE, "res://assets/tag_scenes/fence.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.16, 1.10, 0.16), Vector3(0.0, 0.55, -1.20), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.16, 1.10, 0.16), Vector3(0.0, 0.55, 1.20), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.09, 0.14, 2.60), Vector3(0.0, 0.85, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.09, 0.14, 2.60), Vector3(0.0, 0.48, 0.0), WOOD),
	], 1.114)
	# The loaded cart -- 4960 triangles against Cart_01's 938, and worth it for one
	# or two per village: the load is where the pack's colour is, and an empty cart
	# at this size reads as a crate on wheels. Turned a quarter turn so its shafts
	# point along Z like the placeholder's, scaled 1.047 to the placeholder's
	# height, and shifted 0.53 along its own length because the model's box sits
	# half a unit off its origin -- the inventory's centre column is where that
	# number comes from.
	_row(rows, AssetTags.CART, "res://assets/tag_scenes/cart.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(1.30, 0.55, 2.20), Vector3(0.0, 0.80, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.14, 0.12, 1.30), Vector3(0.0, 0.62, 1.60), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_TORUS, Vector3(1.00, 0.16, 1.00), Vector3(0.72, 0.50, -0.55),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 0.0, 90.0)),
		AssetVisual.part(AssetVisual.SHAPE_TORUS, Vector3(1.00, 0.16, 1.00), Vector3(-0.72, 0.50, -0.55),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 0.0, 90.0)),
	], 1.077)
	# A post with one board nailed across it, 52 triangles -- the cheapest thing
	# in the pack that is a signpost, and the closest to what the placeholder
	# described. Pointer_02 and _03 are the same post with two and three boards;
	# one board is what a road leaving a village needs.
	_row(rows, AssetTags.SIGNPOST, "res://assets/tag_scenes/signpost.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.14, 1.90, 0.14), Vector3(0.0, 0.95, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(1.10, 0.42, 0.08), Vector3(0.35, 1.60, 0.0),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 0.0, -4.0)),
	], 1.900)
	# The village pack's own barrel, so that the barrels stacked against a village
	# wall are made of the same wood as the wall. 872 triangles against the
	# dungeon pack's; Barrel_02 is the same barrel with its lid off, which reads
	# as an open crate at the size a yard prop is drawn.
	_row(rows, AssetTags.BARREL, "res://assets/justcreate_village/Props/Barrel_01.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.72, 1.00, 0.72), Vector3(0.0, 0.50, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_TORUS, Vector3(0.80, 0.08, 0.80), Vector3(0.0, 0.72, 0.0), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_TORUS, Vector3(0.80, 0.08, 0.80), Vector3(0.0, 0.28, 0.0), DARK_WOOD),
	], 1.030)
	# The pack's crate, 328 triangles, and the same wood as the barrel beside it
	# and the wall behind them both.
	_row(rows, AssetTags.CRATE, "res://assets/tag_scenes/crate.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.80, 0.80, 0.80), Vector3(0.0, 0.40, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.86, 0.10, 0.10), Vector3(0.0, 0.40, 0.0), DARK_WOOD),
	], 0.800)
	# The one wrapper that holds two models, because the pack draws a market stall
	# SFM_Veg_Stall_003, merged: 9734 triangles in one surface, 2.80 x 1.99 x 1.79.
	# The one model on either pack's disk that is a stall *and* its vendor goods
	# in one piece -- a striped awning over a trestle of crated fruit, a rear
	# display panel and cartwheels under it, arranged by the artist. It replaces
	# two JustCreate pieces totalling 7832 triangles in two nodes; 24% more
	# geometry for half the nodes and a stall that is stocked rather than bare.
	_row(rows, AssetTags.MARKET_STALL, "res://assets/mistage_baked/market_stall_mistage.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.10, 2.10, 0.10), Vector3(-1.10, 1.05, -0.90), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.10, 2.10, 0.10), Vector3(1.10, 1.05, -0.90), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.10, 2.10, 0.10), Vector3(-1.10, 1.05, 0.90), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.10, 2.10, 0.10), Vector3(1.10, 1.05, 0.90), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(2.60, 0.18, 2.20), Vector3(0.0, 1.00, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(2.80, 0.70, 2.40), Vector3(0.0, 2.40, 0.0), CLOTH),
	], 1.994)
	_row(rows, AssetTags.WATER_WHEEL, "res://assets/tag_scenes/water_wheel.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_TORUS, Vector3(3.20, 0.30, 3.20), Vector3(0.0, 1.70, 0.0),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 0.0, 90.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.30, 0.90, 0.30), Vector3(0.0, 1.70, 0.0),
			WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 0.0, 90.0)),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.20, 3.00, 0.20), Vector3(0.0, 0.90, 0.60), WOOD),
	], 2.401)
	_row(rows, AssetTags.CRAFTING_BENCH, "res://assets/tag_scenes/crafting_bench.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(1.80, 0.16, 0.90), Vector3(0.0, 0.90, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.14, 0.90, 0.14), Vector3(-0.75, 0.45, -0.32), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.14, 0.90, 0.14), Vector3(0.75, 0.45, -0.32), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.14, 0.90, 0.14), Vector3(-0.75, 0.45, 0.32), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.14, 0.90, 0.14), Vector3(0.75, 0.45, 0.32), DARK_WOOD),
	], 0.980)

	# --- Buildings -------------------------------------------------------
	#
	# Every building carries a lit window, because the warm pinpoint against cool
	# ambient is the signature the art direction is built around and a settlement
	# without one reads as a model village rather than a lived-in one.

	# The six buildings below all come out of one pack and all fill the ground the
	# settlement layer reserved for them: the wrapper's scale is the smaller of
	# (reserved width / model width) and (reserved depth / model depth), so a
	# building is as big as its plot allows and never bigger. That is why their
	# heights are not the placeholder's -- a plot is a rectangle on the ground and
	# the model that fits it is whatever height it happens to be.
	#
	# SFV_Building_Empty_Blue_002, merged and reduced: 17 090 triangles in two
	# surfaces, 5.20 x 6.59 x 4.90. A three-storey timber townhouse with a jetty,
	# a shingle roof and six lit windows, against the JustCreate house's one
	# storey and a half -- and it is the tallest of its pack's six, which is what
	# makes the plain house the building that gives a village its skyline.
	# 1.74x the triangles of the model it replaces, for 1.36x the height.
	_row(rows, AssetTags.HOUSE, "res://assets/mistage_baked/house_mistage.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(4.40, 3.00, 5.20), Vector3(0.0, 1.50, 0.0), PLASTER),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(4.60, 0.30, 0.26), Vector3(0.0, 1.60, 2.62), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(5.00, 1.90, 5.60), Vector3(0.0, 3.95, 0.0), THATCH),
		AssetVisual.part(AssetVisual.SHAPE_PLANE, Vector3(0.90, 0.0, 1.00), Vector3(1.20, 1.80, 2.62),
			AMBER, AssetVisual.TINT_NONE, 2.20),
	], 6.588)
	# House_02: 7179 triangles, 4.00 x 3.53 x 4.33 in the cottage's smaller plot.
	# The simplest of the seven -- one storey and a half under a plain gable -- so
	# it still reads as a whole building at the two-thirds scale a cottage plot
	# forces, where House_01's balcony would come out as clutter.
	#
	# This is the one building row the Mistage pack did *not* take, and it was
	# tried: assets/mistage_baked/cottage_mistage.tscn is baked and photographed
	# beside this one in reports/mistage-packs.md. Three numbers kept it out.
	# Cottages are 7.7 of a village's 12.6 buildings, so the Mistage one would be
	# 116 312 of a village's triangles against this one's 55 381 -- 79% more than
	# everything a village drew before it, for the building that is on screen
	# smallest. No Mistage building fits the 4.0 by 4.4 plot a cottage reserves
	# without coming down to 2.62 tall against this one's 3.53. And at 2.62 its
	# eaves overhang the only wall a pane can sit on, so the lit-window fit puts
	# the pane 0.315 off the model's surface, past the 0.25 tests/test_window_glow
	# allows -- which is the check saying, in its own terms, that the building has
	# no flat wall left at window height.
	_row(rows, AssetTags.COTTAGE, "res://assets/tag_scenes/cottage.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(3.20, 2.40, 3.60), Vector3(0.0, 1.20, 0.0), PLASTER),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(3.70, 1.60, 4.00), Vector3(0.0, 3.20, 0.0), THATCH),
		AssetVisual.part(AssetVisual.SHAPE_PLANE, Vector3(0.70, 0.0, 0.80), Vector3(0.70, 1.40, 1.82),
			AMBER, AssetVisual.TINT_NONE, 2.20),
	], 3.526)
	# SFV_Building_Empty_Blue_005, merged and reduced: 26 924 triangles in two
	# surfaces, 7.16 x 6.28 x 7.29. The biggest of its pack's six, with a balcony
	# along one side, a second roof over a wing and eleven lit windows -- which is
	# what a tavern has to be to read as the biggest thing on the green.
	_row(rows, AssetTags.TAVERN, "res://assets/mistage_baked/tavern_mistage.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(6.40, 4.20, 7.00), Vector3(0.0, 2.10, 0.0), PLASTER),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(6.60, 0.34, 0.28), Vector3(0.0, 2.30, 3.52), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(7.00, 2.30, 7.40), Vector3(0.0, 5.35, 0.0), THATCH),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(1.20, 0.70, 0.10), Vector3(2.30, 3.30, 3.55), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_PLANE, Vector3(1.10, 0.0, 1.20), Vector3(-1.40, 2.20, 3.52),
			AMBER, AssetVisual.TINT_NONE, 2.60),
	], 6.281)
	# SFV_Building_Empty_Blue_003, merged and reduced: 10 319 triangles in two
	# surfaces, 5.25 x 3.82 x 5.00. The one of its pack's six with canvas awnings
	# stretched over its ground floor and a stone chimney up its end wall, which
	# is the only thing in either pack that reads as somewhere work happens.
	_row(rows, AssetTags.WORKSHOP, "res://assets/mistage_baked/workshop_mistage.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(5.00, 3.00, 4.20), Vector3(0.0, 1.50, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(5.40, 1.40, 4.60), Vector3(0.0, 3.70, 0.0), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.80, 2.20, 0.80), Vector3(-1.60, 4.20, -1.20), STONE),
		AssetVisual.part(AssetVisual.SHAPE_PLANE, Vector3(1.40, 0.0, 1.30), Vector3(0.60, 1.60, 2.12),
			AMBER, AssetVisual.TINT_NONE, 2.80),
	], 3.818)
	# Props/Tower: 4616 triangles, 3.28 x 7.98 x 3.94. A timber watchtower on
	# stilts with a ladder up one side. Scaled to the placeholder's height rather
	# than clamped, because at that height it is still inside its 4.2 by 4.2 plot;
	# shifted 0.246 along Z, which is where the ladder pulls its box.
	#
	# It keeps the rock tint its placeholder carried even though the model is
	# timber, at the placeholder's own 0.35: the row's colour is a property of the
	# tag, and a third of a shift towards a highland's grey is what stops the one
	# tall thing on a ridge from being the only warm object in a cold frame.
	_row(rows, AssetTags.TOWER, "res://assets/tag_scenes/tower.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(3.40, 8.00, 3.40), Vector3(0.0, 4.00, 0.0),
			STONE, AssetVisual.TINT_ROCK, 0.0, Vector3.ZERO, 0.35),
		AssetVisual.part(AssetVisual.SHAPE_CONE, Vector3(4.20, 2.60, 4.20), Vector3(0.0, 9.30, 0.0), CLOTH),
		AssetVisual.part(AssetVisual.SHAPE_PLANE, Vector3(0.70, 0.0, 0.90), Vector3(0.0, 6.20, 1.72),
			AMBER, AssetVisual.TINT_NONE, 2.40),
	], 7.983, AssetVisual.TINT_ROCK, 0.35)
	# Props/Well: 4010 triangles, 2.38 x 2.42 x 1.64 -- stone drum, timber frame,
	# tiled roof, exactly the placeholder's four parts in geometry. It is the only
	# well in the pack and it needed no choosing; what it needed was measuring,
	# and at 1.022 it stands the height the placeholder did inside a plot it fits.
	_row(rows, AssetTags.WELL, "res://assets/tag_scenes/well.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(1.80, 0.90, 1.80), Vector3(0.0, 0.45, 0.0),
			STONE, AssetVisual.TINT_ROCK, 0.0, Vector3.ZERO, 0.35),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.14, 1.90, 0.14), Vector3(-0.75, 1.35, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.14, 1.90, 0.14), Vector3(0.75, 1.35, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_PRISM, Vector3(2.20, 0.70, 1.80), Vector3(0.0, 2.60, 0.0), THATCH),
	], 2.420, AssetVisual.TINT_ROCK, 0.35)

	# --- Bridges ---------------------------------------------------------
	#
	# A bridge is laid along +Z, so the layer that places one only has to turn it
	# to face the crossing.

	_row(rows, AssetTags.BRIDGE_WOOD, "res://assets/tag_scenes/bridge_wood.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(2.60, 0.24, 8.00), Vector3(0.0, 0.12, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.12, 0.14, 8.00), Vector3(-1.20, 0.95, 0.0), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.12, 0.14, 8.00), Vector3(1.20, 0.95, 0.0), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.16, 0.90, 0.16), Vector3(-1.20, 0.45, -3.60), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.16, 0.90, 0.16), Vector3(1.20, 0.45, -3.60), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.16, 0.90, 0.16), Vector3(-1.20, 0.45, 3.60), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.16, 0.90, 0.16), Vector3(1.20, 0.45, 3.60), DARK_WOOD),
	], 3.161)
	_row(rows, AssetTags.BRIDGE_STONE, "res://assets/tag_scenes/bridge_stone.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(3.00, 0.40, 9.00), Vector3(0.0, 0.20, 0.0),
			STONE, AssetVisual.TINT_ROCK, 0.0, Vector3.ZERO, 0.35),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.34, 0.70, 9.00), Vector3(-1.33, 0.75, 0.0),
			STONE, AssetVisual.TINT_ROCK, 0.0, Vector3.ZERO, 0.35),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.34, 0.70, 9.00), Vector3(1.33, 0.75, 0.0),
			STONE, AssetVisual.TINT_ROCK, 0.0, Vector3.ZERO, 0.35),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(3.20, 3.00, 3.20), Vector3(0.0, -0.60, 0.0),
			DARK_STONE, AssetVisual.TINT_ROCK, 0.0, Vector3(90.0, 0.0, 0.0), 0.35),
	], 1.170, AssetVisual.TINT_ROCK, 0.35)
	_row(rows, AssetTags.ROPE_LADDER, "res://assets/tag_scenes/rope_ladder.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.07, 6.00, 0.07), Vector3(-0.42, 3.00, 0.0), DRY_LEAF),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.07, 6.00, 0.07), Vector3(0.42, 3.00, 0.0), DRY_LEAF),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.95, 0.09, 0.14), Vector3(0.0, 1.00, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.95, 0.09, 0.14), Vector3(0.0, 2.20, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.95, 0.09, 0.14), Vector3(0.0, 3.40, 0.0), WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.95, 0.09, 0.14), Vector3(0.0, 4.60, 0.0), WOOD),
	], 6.000)

	# --- Lanterns --------------------------------------------------------

	# Lantern_02: 586 triangles, a timber post with a lantern hanging off an arm.
	# The only lamp post in the pack -- Lantern_01 is the hand lantern on the row
	# below. Scaled 1.146 to the placeholder's height; shifted 0.549 back along
	# its arm, which is the model's own box centre out of the inventory, so that
	# the post and the lamp straddle the point the simulation lit rather than the
	# post standing on it with the flame a metre away from the light Atmosphere
	# hangs there. Half a unit is well inside the 2.6-to-5.0 band a road's props
	# stand in, so the post cannot be shifted into the road.
	_row(rows, AssetTags.LANTERN_POST, "res://assets/tag_scenes/lantern_post.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.16, 2.80, 0.16), Vector3(0.0, 1.40, 0.0), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.60, 0.10, 0.16), Vector3(0.22, 2.75, 0.0), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.40, 0.46, 0.40), Vector3(0.42, 2.48, 0.0),
			AMBER, AssetVisual.TINT_NONE, 3.20),
	], 2.799)
	# Lantern_01: 340 triangles, the pack's hand lantern, hung rather than carried.
	# Scaled 1.2 and lifted 1.604 so that the middle of the lantern sits at 1.9 --
	# the height Atmosphere puts this tag's light at -- which is the whole job of
	# this row: the light and the thing that is supposed to be making it in the
	# same place.
	_row(rows, AssetTags.HANGING_LANTERN, "res://assets/tag_scenes/hanging_lantern.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.04, 0.45, 0.04), Vector3(0.0, 2.28, 0.0), DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.34, 0.40, 0.34), Vector3(0.0, 1.86, 0.0),
			AMBER, AssetVisual.TINT_NONE, 3.00),
	], 2.196)
	# Props/Fire: 492 triangles, a ring of stones with flames inside it. Unscaled --
	# the pack drew it 0.637 tall and the placeholder stood 0.64 -- and lifted
	# 0.125, which is how far the stone ring is drawn below its own origin, so the
	# ring sits on the ground rather than in it.
	#
	# What it gives up is the placeholder's emissive core: the model's flames are
	# painted, not lit. The warm pool on the ground around a campfire comes from
	# the point light Atmosphere hangs on this tag, which is untouched, and that
	# is the part that carries the night.
	_row(rows, AssetTags.CAMPFIRE, "res://assets/tag_scenes/campfire.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.16, 1.10, 0.16), Vector3(0.0, 0.22, 0.0),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(70.0, 0.0, 0.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.16, 1.10, 0.16), Vector3(0.0, 0.22, 0.0),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(70.0, 120.0, 0.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.16, 1.10, 0.16), Vector3(0.0, 0.22, 0.0),
			DARK_WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(70.0, 240.0, 0.0)),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.55, 0.60, 0.55), Vector3(0.0, 0.34, 0.0),
			Color(1.00, 0.58, 0.24), AssetVisual.TINT_NONE, 4.50),
	], 0.637)
	_row(rows, AssetTags.GLOWING_ORB, "", [
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.42, 0.42, 0.42), Vector3(0.0, 1.30, 0.0),
			MARSH_GLOW, AssetVisual.TINT_NONE, 5.00),
	])
	# The lit window itself: one upright emissive pane, at first-storey height on
	# whatever wall it was fitted to. It carries no frame and no sill, because it
	# is not a thing standing in the world -- it is the light in a window the
	# building model already has drawn on it.
	#
	# It is now the village pack's own pane rather than a quad this file drew.
	# SFV_Windows_Glow_001 is the one model in either pack whose whole content is
	# the SFV_GLOW_WINDOW material -- leaded glass in six triangles rather than a
	# flat rectangle in two -- and it is the same material the buildings above
	# carry on their own windows, so a fitted pane and the window it stands in
	# front of are lit by one thing. What the pack does not ship is any light:
	# the FBX carries a diffuse colour and nothing else, because the glow lived
	# in a Unity shader that does not travel in the file. So the emission is
	# still AMBER at 2.40, exactly what the quad below emitted, applied to the
	# pack's material by tools/bake_mistage.sh. The pane comes out 0.348 x 0.451,
	# inside the 0.45 by 0.45 the fit reserves, centred on the point it is given
	# and facing +Z, which is the way the placeholder quad faces.
	_row(rows, AssetTags.WINDOW_GLOW, "res://assets/mistage_baked/window_glow_mistage.tscn", [
		AssetVisual.part(AssetVisual.SHAPE_PLANE, Vector3(WINDOW_WIDTH, 0.0, WINDOW_TALL),
			Vector3(0.0, WINDOW_HEIGHT, 0.0), AMBER, AssetVisual.TINT_NONE, 2.40),
	])


	# --- Characters ------------------------------------------------------
	#
	# The six rigged adventurers, one per tag, all on the shared `Rig_Medium`
	# skeleton -- so the animation setup that plays a knight plays a mage, and
	# swapping which one a character is is a change to one row of this table.
	# Heights are measured, not guessed (tools/measure_rigs.sh, reports/
	# creature-packs.md §2), and include headgear: the mage is mostly hat.
	#
	# Every one of them keeps the colours the pack drew it in. A character is not
	# scenery: a knight walking out of a meadow into a deep forest is the same
	# knight, and shifting his armour towards the forest's foliage green -- which
	# is what the tree role would do -- would be the biome painting a person. The
	# placeholders below take no role either, so dropped_tints() has nothing to
	# hold this against, which is correct rather than an oversight.
	#
	# The placeholder is a body, a head and two legs at the model's own height,
	# so a checkout with no packs still has something person-shaped standing
	# where a character is. It cannot be animated -- there are no bones in a
	# stack of capsules -- and CharacterView draws it standing still.

	_row(rows, AssetTags.BARBARIAN, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Characters/gltf/Barbarian.glb",
		_person_placeholder(2.398, Color(0.72, 0.48, 0.34), Color(0.55, 0.34, 0.22)),
		2.398, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)
	_row(rows, AssetTags.KNIGHT, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb",
		_person_placeholder(2.543, Color(0.70, 0.72, 0.76), Color(0.42, 0.45, 0.52)),
		2.543, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)
	_row(rows, AssetTags.MAGE, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Characters/gltf/Mage.glb",
		_person_placeholder(2.655, Color(0.38, 0.34, 0.62), Color(0.26, 0.23, 0.44)),
		2.655, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)
	_row(rows, AssetTags.RANGER, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Characters/gltf/Ranger.glb",
		_person_placeholder(2.275, Color(0.36, 0.50, 0.32), Color(0.28, 0.36, 0.24)),
		2.275, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)
	_row(rows, AssetTags.ROGUE, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Characters/gltf/Rogue.glb",
		_person_placeholder(2.180, Color(0.40, 0.36, 0.34), Color(0.26, 0.24, 0.24)),
		2.180, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)
	_row(rows, AssetTags.HOODED_ROGUE, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Characters/gltf/Rogue_Hooded.glb",
		_person_placeholder(2.173, Color(0.30, 0.30, 0.36), Color(0.20, 0.20, 0.26)),
		2.173, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)

	# --- Creatures -------------------------------------------------------

	# The four minions of section 3.3, and the one honest thing to say about
	# them: **no installed pack holds a toadstool, a cat, an ent or a frog as a
	# creature.** reports/creature-packs.md §4 measured that and it has not
	# changed -- the packs that would are KayKit's three Mystery Monthly series
	# at $19.99 each, and nothing was bought.
	#
	# So these four rows point at Board Game Bits, which the design itself names
	# for "game-piece minions" (§9.10) and which is free and installed. Each
	# piece is chosen for the chess analog the design gives the minion, not for
	# looking like the animal: the Toadstool is a pawn and gets the pawn, the Cat
	# is a bishop and gets the taller pointed pawn, the Ent is a rook and gets
	# the tower, and the Frog is a knight and gets the meeple, the one piece in
	# the pack shaped like a figure. They are all one colour because they are one
	# side; the pack ships four, which is what §3.8's several commanders will
	# want.
	#
	# This is an abstract stand-in and it is meant to be recognised as one. It is
	# not a rigged creature, it has no skeleton and therefore no rig, and
	# CharacterView will draw it standing still whatever the simulation says it
	# is doing. Whoever fills these in properly is buying a pack, not editing
	# code: it is four `scene_path` strings and four heights.

	_row(rows, AssetTags.MINION_TOADSTOOL, "res://assets/kaykit_board_game_bits/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/pawn_A_blue.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.30, 0.42, 0.30), Vector3(0.0, 0.21, 0.0),
			CREAM),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.50, 0.36, 0.50), Vector3(0.0, 0.55, 0.0),
			CAP_RED),
	], 0.915, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.MINION_CAT, "res://assets/kaykit_board_game_bits/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/pawn_B_blue.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CAPSULE, Vector3(0.34, 0.80, 0.34), Vector3(0.0, 0.44, 0.0),
			Color(0.42, 0.38, 0.44)),
		AssetVisual.part(AssetVisual.SHAPE_CONE, Vector3(0.36, 0.36, 0.36), Vector3(0.0, 1.02, 0.0),
			Color(0.42, 0.38, 0.44)),
	], 1.215, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.MINION_ENT, "res://assets/kaykit_board_game_bits/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/building_blue.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.62, 0.70, 0.62), Vector3(0.0, 0.35, 0.0),
			DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.80, 0.30, 0.80), Vector3(0.0, 0.85, 0.0),
			WOOD),
	], 1.000, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.MINION_FROG, "res://assets/kaykit_board_game_bits/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/meeple_blue.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CAPSULE, Vector3(0.44, 0.72, 0.44), Vector3(0.0, 0.40, 0.0),
			Color(0.34, 0.58, 0.36)),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.46, 0.46, 0.46), Vector3(0.0, 1.00, 0.0),
			Color(0.34, 0.58, 0.36)),
	], 1.240, AssetVisual.TINT_NONE, 0.0)

	# The four rigged undead, and the only enemy species any free pack holds. On
	# the same `Rig_Medium` skeleton as the six adventurers -- measured, not
	# assumed -- so one library animates heroes and enemies alike and the two
	# `handslot` bones that will hold an adventurer's sword hold a skeleton's axe.
	# They are cheaper to draw than the heroes, which matters because enemies
	# outnumber commanders on a board.
	_row(rows, AssetTags.SKELETON_WARRIOR, "res://assets/kaykit_skeletons/KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Warrior.glb",
		_person_placeholder(2.590, CREAM, Color(0.52, 0.50, 0.44)),
		2.590, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)
	_row(rows, AssetTags.SKELETON_ROGUE, "res://assets/kaykit_skeletons/KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Rogue.glb",
		_person_placeholder(2.308, CREAM, Color(0.44, 0.42, 0.40)),
		2.308, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)
	_row(rows, AssetTags.SKELETON_MAGE, "res://assets/kaykit_skeletons/KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Mage.glb",
		_person_placeholder(2.630, CREAM, Color(0.36, 0.36, 0.46)),
		2.630, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)
	_row(rows, AssetTags.SKELETON_MINION, "res://assets/kaykit_skeletons/KayKit_Skeletons_1.1_FREE/characters/gltf/Skeleton_Minion.glb",
		_person_placeholder(2.166, CREAM, Color(0.48, 0.46, 0.42)),
		2.166, AssetVisual.TINT_NONE, 0.0, CharacterRig.RIG_MEDIUM)

	# --- Gear ------------------------------------------------------------

	# What a generated item looks like. Thirteen rows for the thirteen names in
	# the catalog's gear category: seven shapes a held thing comes in, four worn
	# slots, a draught, and the bundle an item nobody recorded a shape for is
	# drawn as.
	#
	# Every one of them takes no biome colour. Steel is steel in a marsh and in a
	# meadow, and a sword that turned pink in the blossom grove would be reading
	# the world's palette as if it had grown there. That is the same judgement the
	# fence and the bridge already carry, and it is stated on every row rather
	# than inherited, because these are the rows most likely to be repointed at a
	# bought armoury pack later.
	#
	# Nine of the thirteen name an installed model; four keep their placeholder,
	# and all four are worn armour. The three bought armoury packs hold 293 gear
	# models between them and not one piece of armour off a body: the whole of
	# what exists is `SFFA_Armor_001`, a 2.243-unit display suit welded to its own
	# stand in one 9,780-triangle mesh -- helm, breast, greaves and post together,
	# so it cannot be three different tags and is scenery for a smithy rather than
	# a thing that lies on grass -- and `AWS_Wizard_Hat_001`, a soft pointed hat
	# 0.336 tall. Nothing anywhere on this machine is a boot or a legging. So
	# those four rows keep primitives that are at least the right *thing*, and the
	# gap is named here rather than papered over with the wrong model.
	# reports/gear-models.md is the roll call and the measurements.
	#
	# Sizes are drawn to be *read*, not to be right: the shell normalises every
	# item to GroundItems.DRAWN_SPAN before it lies down -- measured off what it
	# built, because these packs draw a sword along its height and a bow along its
	# depth -- so what matters here is the silhouette and not the scale.

	_row(rows, AssetTags.GEAR_BLADE, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Assets/gltf/sword_1handed.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.09, 0.62, 0.03), Vector3(0.0, 0.55, 0.0),
			STEEL),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.26, 0.05, 0.06), Vector3(0.0, 0.23, 0.0),
			DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.06, 0.20, 0.06), Vector3(0.0, 0.11, 0.0),
			LEATHER),
	], 1.775, AssetVisual.TINT_NONE, 0.0)
	# The blade's small sibling, and the one shape that was drawn as something
	# else until now: `ItemModel.BY_SHAPE` folded "dagger" into the blade, so a
	# dagger came out as the long cruciform sword above -- and at the same size,
	# because the shell normalises both. The pack's own dagger is a short curved
	# knife, 1.206 along its height and 172 triangles. Wisp, the bystander in the
	# encounter scenario, carries one.
	_row(rows, AssetTags.GEAR_DAGGER, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Assets/gltf/dagger.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.07, 0.34, 0.03), Vector3(0.0, 0.33, 0.0),
			STEEL),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.16, 0.04, 0.05), Vector3(0.0, 0.14, 0.0),
			DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 0.14, 0.05), Vector3(0.0, 0.07, 0.0),
			LEATHER),
	], 1.206, AssetVisual.TINT_NONE, 0.0)
	# A plain leaf point on a plain shaft, which is what the tag means and what
	# the forge packs' eighteen "spears" are not: `SFFA_Weapon_Spear_Iron_001`
	# through `_006` are ornate glaives and halberds with curved or winged heads.
	# The market pack's armoury stall ships the straight one, 1.463 along its
	# height and 300 triangles.
	_row(rows, AssetTags.GEAR_SPEAR, "res://assets/mistage_market/FBX/Armory Stall/Weapons/SFM_Spear_002.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 1.30, 0.05), Vector3(0.0, 0.65, 0.0),
			WOOD),
		AssetVisual.part(AssetVisual.SHAPE_CONE, Vector3(0.12, 0.30, 0.12), Vector3(0.0, 1.45, 0.0),
			STEEL),
	], 1.463, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.GEAR_BOW, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Assets/gltf/bow_withString.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 0.70, 0.05), Vector3(0.0, 0.60, 0.0),
			WOOD),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 0.34, 0.05), Vector3(0.06, 1.06, 0.0),
			WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 0.0, 28.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.05, 0.34, 0.05), Vector3(0.06, 0.14, 0.0),
			WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(0.0, 0.0, -28.0)),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.02, 1.16, 0.02), Vector3(0.14, 0.60, 0.0),
			CREAM),
	], 0.156, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.GEAR_STAFF, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Assets/gltf/staff.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.06, 1.30, 0.06), Vector3(0.0, 0.65, 0.0),
			DARK_WOOD),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.22, 0.22, 0.22), Vector3(0.0, 1.40, 0.0),
			MARSH_GLOW, AssetVisual.TINT_NONE, 1.4),
	], 2.155, AssetVisual.TINT_NONE, 0.0)
	# A spiked ball on a haft. Not a chain, and no pack on this machine has one --
	# 4,689 models were searched for a chained weapon and the three loose forge
	# chains are smithy dressing. What is lost by taking the mace is exactly what
	# the placeholder underneath never drew either: three stacked primitives are a
	# rigid haft and ball too, so the pack model is the same silhouette with real
	# art on it. 1.103 along its height, 894 triangles.
	_row(rows, AssetTags.GEAR_FLAIL, "res://assets/mistage_battle/FBX/Weapons/Mace/SFBP_Mace_004.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.07, 0.44, 0.07), Vector3(0.0, 0.22, 0.0),
			LEATHER),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.03, 0.26, 0.03), Vector3(0.0, 0.57, 0.0),
			STEEL),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.26, 0.26, 0.26), Vector3(0.0, 0.82, 0.0),
			DARK_STONE),
	], 1.103, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.GEAR_BUCKLER, "res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Assets/gltf/shield_round.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.62, 0.07, 0.62), Vector3(0.0, 0.04, 0.0),
			WOOD, AssetVisual.TINT_NONE, 0.0, Vector3(90.0, 0.0, 0.0)),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.20, 0.20, 0.12), Vector3(0.0, 0.31, 0.0),
			STEEL),
	], 0.883, AssetVisual.TINT_NONE, 0.0)

	# The four worn slots, and the four rows in the whole catalog that a bought
	# pack could not fill. Every model on this machine was searched by name and
	# by category: no footwear and no leg armour exists at all, and the two
	# near misses for the other pair are measured in the note at the head of this
	# section. A primitive that is the right thing beats a model that is a
	# different thing, so these stay as they were drawn.
	_row(rows, AssetTags.GEAR_BOOTS, "", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.17, 0.30, 0.34), Vector3(-0.11, 0.15, 0.0),
			LEATHER),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.17, 0.30, 0.34), Vector3(0.11, 0.15, 0.0),
			LEATHER),
	], 0.0, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.GEAR_LEGGINGS, "", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.18, 0.52, 0.18), Vector3(-0.11, 0.26, 0.0),
			DARK_STONE),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.18, 0.52, 0.18), Vector3(0.11, 0.26, 0.0),
			DARK_STONE),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.44, 0.12, 0.24), Vector3(0.0, 0.56, 0.0),
			LEATHER),
	], 0.0, AssetVisual.TINT_NONE, 0.0)
	_row(rows, AssetTags.GEAR_CHESTPLATE, "", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.46, 0.52, 0.28), Vector3(0.0, 0.30, 0.0),
			STEEL),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.26, 0.20, 0.28), Vector3(-0.28, 0.52, 0.0),
			DARK_STONE),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.26, 0.20, 0.28), Vector3(0.28, 0.52, 0.0),
			DARK_STONE),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.50, 0.08, 0.32), Vector3(0.0, 0.06, 0.0),
			LEATHER),
	], 0.0, AssetVisual.TINT_NONE, 0.0)
	# A helmet has to not read as a boulder, which a bare dome does: the brim and
	# the dark slit across the front are what say which way it is facing and that
	# it is a made thing.
	_row(rows, AssetTags.GEAR_HELMET, "", [
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(0.38, 0.42, 0.38), Vector3(0.0, 0.24, 0.0),
			STEEL),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.50, 0.05, 0.50), Vector3(0.0, 0.14, 0.0),
			DARK_STONE),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.30, 0.08, 0.20), Vector3(0.0, 0.28, 0.14),
			Color(0.14, 0.14, 0.17)),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.06, 0.14, 0.34), Vector3(0.0, 0.46, 0.0),
			CLOTH),
	], 0.0, AssetVisual.TINT_NONE, 0.0)

	_row(rows, AssetTags.GEAR_DRAUGHT, "res://assets/kaykit_dungeon_remastered/KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf/bottle_A_green.gltf", [
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.24, 0.28, 0.24), Vector3(0.0, 0.14, 0.0),
			GLASS_GREEN),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.10, 0.16, 0.10), Vector3(0.0, 0.36, 0.0),
			GLASS_GREEN),
		AssetVisual.part(AssetVisual.SHAPE_CYLINDER, Vector3(0.11, 0.06, 0.11), Vector3(0.0, 0.47, 0.0),
			WOOD),
	], 0.886, AssetVisual.TINT_NONE, 0.0)
	# The one row that is not a shape anything forges: what an item nobody
	# recorded a shape for is drawn as. A tied sack, which is what an unidentified
	# thing on the ground looks like -- readable as "there is something here" and
	# deliberately not readable as any particular thing. The village pack's sack
	# is 0.830 along its height, 400 triangles, and unlike every other gear model
	# it already stands with its lowest point at its own origin.
	_row(rows, AssetTags.GEAR_BUNDLE, "res://assets/mistage_village/FBX/Exterior Props/Sacks/SFV_Sack_002.fbx", [
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.42, 0.32, 0.34), Vector3(0.0, 0.16, 0.0),
			THATCH),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.06, 0.34, 0.36), Vector3(0.0, 0.17, 0.0),
			LEATHER),
		AssetVisual.part(AssetVisual.SHAPE_BOX, Vector3(0.44, 0.34, 0.06), Vector3(0.0, 0.17, 0.0),
			LEATHER),
	], 0.830, AssetVisual.TINT_NONE, 0.0)

	_table = rows
	return _table


## One row of the table.
##
## The tint arguments are the last two and both are optional, because the
## documented way to install art is "fill in one string per row" -- and that is
## exactly what has to keep working without losing the biome's colour. A row that
## says nothing about its model's tint is answered by the placeholder underneath
## it (AssetVisual.placeholder_tint()), which is the row's own record of what the
## thing is made of: a bare tree whose placeholder branches take the foliage
## colour gets the foliage colour, a fence whose slats take nothing gets nothing.
##
## It did not used to be. The default was TINT_NONE, which is also what a fence
## deliberately carries, so a repoint that simply stopped after `scene_height`
## produced a model the render layer could not tell from one that had chosen to
## keep the pack's colours -- and shipped the twilight marsh a row of bright
## orange bare trees. Stating the role is still preferred and nineteen rows do,
## because three of them mean something different from their placeholder; what
## changed is that saying nothing can no longer mean "no colour", and a row that
## says something contradicting its placeholder is caught by dropped_tints().
static func _row(
	rows: Dictionary, tag: String, scene_path: String, parts: Array,
	scene_height: float = 0.0,
	scene_tint_role: String = AssetVisual.TINT_UNSTATED,
	scene_tint_mix: float = 0.0,
	scene_rig: String = "",
) -> void:
	var row := AssetVisual.new(tag)
	row.scene_path = scene_path
	row.scene_height = scene_height
	row.scene_rig = scene_rig
	for entry in parts:
		row.parts.append(entry)
	if scene_tint_role == AssetVisual.TINT_UNSTATED:
		var inherited := row.placeholder_tint()
		row.scene_tint_role = inherited["role"]
		row.scene_tint_mix = inherited["mix"]
	else:
		row.scene_tint_role = scene_tint_role
		row.scene_tint_mix = scene_tint_mix
	rows[tag] = row


## A person-shaped placeholder at a given height: two legs, a body and a head,
## in a cloth colour and a darker one under it.
##
## The fourteen character and creature rows would otherwise carry fourteen
## near-identical stacks of four primitives, which is a lot of table for
## something nobody sees unless the packs are missing. Proportions are a rough
## human: legs to two fifths, body to four fifths, head on top. It takes no biome
## colour -- see the note above the character rows.
static func _person_placeholder(
	tall: float, cloth: Color, under: Color
) -> Array:
	var leg := tall * 0.42
	var body := tall * 0.38
	var head := tall * 0.20
	return [
		AssetVisual.part(AssetVisual.SHAPE_CAPSULE, Vector3(tall * 0.13, leg, tall * 0.13),
			Vector3(-tall * 0.08, leg * 0.5, 0.0), under),
		AssetVisual.part(AssetVisual.SHAPE_CAPSULE, Vector3(tall * 0.13, leg, tall * 0.13),
			Vector3(tall * 0.08, leg * 0.5, 0.0), under),
		AssetVisual.part(AssetVisual.SHAPE_CAPSULE, Vector3(tall * 0.30, body, tall * 0.22),
			Vector3(0.0, leg + body * 0.5, 0.0), cloth),
		AssetVisual.part(AssetVisual.SHAPE_SPHERE, Vector3(head, head, head),
			Vector3(0.0, leg + body + head * 0.5, 0.0), cloth),
	]
