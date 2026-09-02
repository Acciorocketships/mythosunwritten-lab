extends TestSuite
## The asset-tag indirection is a deliverable, so it is tested like one.
##
## Four claims, and each of them is what makes the next one worth having:
##
##   1. The catalog is a closed vocabulary, and everything the simulation names
##      is in it.
##   2. Every name in it resolves to something drawable in the render layer's
##      table -- so a tag can never be placed and then silently not appear.
##   3. Repointing a tag changes what is drawn and nothing else: not the world,
##      not one byte of the simulation's source.
##   4. A headless run loads no visual material at all: not a scene, not a
##      texture, not one script of the render layer.
##
## The checker that enforces (1) on disk is exercised on lines of source that do
## not exist, for the same reason the layer check is: a check that can never fail
## is worth nothing.
class_name TestAssetTags

const SEED := 11

## A tag whose visual the repoint test swaps, and the tag it borrows a look
## from. Any pair would do; these two are both single-shape rocks, so the swap
## is unmistakable in a description and harmless if it ever leaked.
const REPOINT_TAG := AssetTags.PEBBLE
const REPOINT_TO := AssetTags.BOULDER

## A hand-made scene standing in for a model out of a pack, kept at the pack
## root exactly where an installed one would sit. Nothing points at it by
## default; it exists so that the scene half of the table -- the half every row
## eventually becomes -- is a path that really loads rather than a promise.
const EXAMPLE_SCENE := "res://assets/example_well.tscn"

## The tag the model-tint checks are made on, and one that deliberately takes no
## tint. A fir is the case the whole change exists for -- it should be deep green
## under canopy and bright green in a meadow -- and a wooden bridge is the case
## that should not move, because wood is wood in every biome.
const TINTED_TAG := AssetTags.FIR
const UNTINTED_TAG := AssetTags.BRIDGE_WOOD


func _init() -> void:
	suite_name = "asset tags"


func run() -> void:
	_the_catalog_is_a_closed_vocabulary()
	_the_simulation_names_only_catalog_tags()
	_every_tag_resolves_to_something_drawable()
	_a_row_handed_out_is_not_the_table()
	_a_placeholder_takes_the_biome_colour()
	_a_model_takes_the_biome_colour()
	_a_dead_tree_takes_the_biome_and_does_not_stay_orange()
	_a_repoint_cannot_lose_the_biome_colour()
	_a_tinted_model_leaves_the_packs_own_resources_alone()
	_tinted_models_share_their_materials()
	_a_tag_can_point_at_a_scene()
	_repointing_a_tag_changes_nothing_in_the_simulation()
	_the_asset_check_holds()
	_the_asset_check_would_notice()
	_a_headless_run_loads_no_visual_asset()
	AssetLibrary.restore_defaults()


## Every tag belongs to exactly one category, and every category has tags. The
## catalog is walked by category everywhere else, so a tag in none of them would
## be a name nothing could ever find.
func _the_catalog_is_a_closed_vocabulary() -> void:
	var seen := {}
	for category in AssetTags.CATEGORIES:
		var tags := AssetTags.in_category(category)
		check(tags.size() > 0, "category '%s' has no tags" % category)
		for tag in tags:
			check(not seen.has(tag), "tag '%s' is in both %s and %s"
				% [tag, seen.get(tag, "?"), category])
			seen[tag] = category
			equal(AssetTags.category_of(tag), category,
				"tag '%s' does not report the category it is listed in" % tag)
			check(AssetTags.is_tag(tag), "listed tag '%s' is not recognised" % tag)

	equal(AssetTags.all().size(), seen.size(),
		"the flat tag list and the per-category lists disagree")

	# The six groups the later layers need. Named individually rather than by
	# counting, because "six categories" would still pass if one of them were
	# the wrong six.
	for required in [
		AssetTags.FLORA, AssetTags.ROCKS, AssetTags.PROPS,
		AssetTags.BUILDINGS, AssetTags.BRIDGES, AssetTags.LANTERNS,
	]:
		check(AssetTags.CATEGORIES.has(required),
			"the catalog has no '%s' category" % required)

	check(not AssetTags.is_tag("res://render/main.tscn"),
		"the catalog accepted a scene path as a tag")
	equal(AssetTags.category_of("not_a_tag"), "",
		"an unknown name was given a category")


## What the simulation actually names, checked against the catalog. This is the
## claim the whole indirection rests on, taken from the generation side: every
## prop the biome catalog allows is a tag, not a description of a model.
func _the_simulation_names_only_catalog_tags() -> void:
	var named := 0
	for biome_id in BiomeCatalog.IDS:
		var profile := BiomeCatalog.profile(biome_id)
		check(profile != null, "no profile for biome '%s'" % biome_id)
		if profile == null:
			continue
		check(profile.prop_tags.size() > 0, "biome '%s' names no props" % biome_id)
		for tag in profile.prop_tags:
			named += 1
			check(AssetTags.is_tag(tag),
				"biome '%s' names '%s', which is not a catalog tag" % [biome_id, tag])
			check(AssetLibrary.has_visual(tag),
				"biome '%s' names '%s', which nothing can draw" % [biome_id, tag])
	check(named >= 20, "expected the biomes to name a good many props, found %d" % named)


func _every_tag_resolves_to_something_drawable() -> void:
	var missing := AssetLibrary.missing_tags()
	check(missing.is_empty(), "no visual for: %s" % ", ".join(missing))
	var unknown := AssetLibrary.unknown_rows()
	check(unknown.is_empty(), "rows for names that are not tags: %s" % ", ".join(unknown))
	equal(AssetLibrary.tags().size(), AssetTags.all().size(),
		"the table and the catalog cover different numbers of tags")

	for tag in AssetTags.all():
		var row := AssetLibrary.visual(tag)
		check(row != null, "no row for tag '%s'" % tag)
		if row == null:
			continue
		equal(row.tag, tag, "the row for '%s' answers for a different tag" % tag)
		check(not row.is_placeholder() or row.parts.size() > 0,
			"tag '%s' resolves to nothing at all" % tag)

		for entry in row.parts:
			check(AssetVisual.SHAPES.has(entry["shape"]),
				"tag '%s' uses unknown shape '%s'" % [tag, entry["shape"]])
			check(AssetVisual.TINT_ROLES.has(entry["tint_role"]),
				"tag '%s' uses unknown tint role '%s'" % [tag, entry["tint_role"]])
			var size: Vector3 = entry["size"]
			check(size.x > 0.0 and size.y >= 0.0 and size.z > 0.0,
				"tag '%s' has a part with no size: %s" % [tag, size])

		# And it really builds. An invisible prop is the failure this whole
		# layer exists to make impossible, so every tag is put together once.
		var built := AssetLibrary.build(tag)
		check(built != null, "tag '%s' would not build" % tag)
		if built == null:
			continue
		var meshes := _mesh_count(built)
		check(meshes > 0, "tag '%s' built nothing drawable" % tag)
		built.free()


## The table hands out copies, for the same reason the biome catalog does: a
## caller that wrote into a row it was shown would be rewriting what every later
## lookup returns.
func _a_row_handed_out_is_not_the_table() -> void:
	var first := AssetLibrary.visual(AssetTags.FIR)
	check(first != null, "no row for a fir")
	if first == null:
		return
	var before := first.describe()
	first.scene_path = "res://somewhere/else.tscn"
	first.parts.clear()

	var second := AssetLibrary.visual(AssetTags.FIR)
	equal(second.describe(), before,
		"writing into a row handed out by AssetLibrary.visual() changed the table")


## The palette still lives in the simulation. A part with a tint role takes its
## colour from the biome profile it is built for, so the same tag is a different
## green in the meadow and under canopy without the table knowing either colour.
func _a_placeholder_takes_the_biome_colour() -> void:
	var meadow := BiomeCatalog.profile(BiomeCatalog.MEADOW)
	var forest := BiomeCatalog.profile(BiomeCatalog.DEEP_FOREST)
	not_equal(meadow.tree_tint, forest.tree_tint,
		"the two biomes used for this check have the same foliage colour")

	var entry := AssetVisual.part(
		AssetVisual.SHAPE_CONE, Vector3.ONE, Vector3.ZERO,
		AssetLibrary.LEAF, AssetVisual.TINT_TREE
	)
	var in_meadow := AssetLibrary._colour_of(entry, meadow)
	var in_forest := AssetLibrary._colour_of(entry, forest)
	not_equal(in_meadow, in_forest,
		"a foliage-tinted part is the same colour in the meadow and the deep forest")
	equal(AssetLibrary._colour_of(entry, null), AssetLibrary.LEAF,
		"with no profile, a part should fall back to its own colour")

	var plain := AssetVisual.part(
		AssetVisual.SHAPE_BOX, Vector3.ONE, Vector3.ZERO, AssetLibrary.WOOD
	)
	equal(AssetLibrary._colour_of(plain, forest), AssetLibrary.WOOD,
		"a part with no tint role should keep its own colour in every biome")


## The other half of that claim, for the half of the table that names models.
##
## A pack model arrives with its own colours, so the tint is applied as a shift
## rather than a replacement: the biome's colour for the row's role, divided by
## the colour the pack's art already reads as. The check is the one that matters
## on screen -- the same tag built at two positions whose biomes differ comes out
## two colours -- stated over real world positions rather than over hand-made
## profiles, because "either side of a border" is where anyone would notice.
func _a_model_takes_the_biome_colour() -> void:
	var pair := _two_positions_with_different_foliage()
	check(not pair.is_empty(),
		"found no two positions with different foliage colours to compare")
	if pair.is_empty():
		return

	var row := AssetLibrary.visual(TINTED_TAG)
	check(row != null and not row.is_placeholder(),
		"'%s' does not name a model, so this check would prove nothing" % TINTED_TAG)
	if row == null or row.is_placeholder():
		return
	check(row.takes_scene_tint(),
		"'%s' names a model but takes no biome tint" % TINTED_TAG)

	var here := AssetLibrary.build(TINTED_TAG, pair["near"])
	var there := AssetLibrary.build(TINTED_TAG, pair["far"])
	check(here != null and there != null, "'%s' would not build" % TINTED_TAG)
	if here == null or there == null:
		return

	var here_colour = _drawn_colour(here)
	var there_colour = _drawn_colour(there)
	check(here_colour != null and there_colour != null,
		"'%s' built no surface to take a colour" % TINTED_TAG)
	if here_colour != null and there_colour != null:
		not_equal(here_colour, there_colour,
			"'%s' is the same colour in %s and in %s" % [
				TINTED_TAG, pair["near"].display_name, pair["far"].display_name,
			])

	# And with no profile it keeps the pack's own colours, which is what a
	# caller with nothing to say about the biome should get.
	var plain := AssetLibrary.build(TINTED_TAG)
	check(plain != null, "'%s' would not build without a profile" % TINTED_TAG)
	if plain != null:
		equal(_override_count(plain), 0,
			"'%s' built with no profile still hung a tinted material on itself"
			% TINTED_TAG)
		plain.free()

	# A row that names no role is left alone in every biome. Wood is wood.
	var untinted := AssetLibrary.visual(UNTINTED_TAG)
	check(untinted != null and not untinted.is_placeholder(),
		"'%s' does not name a model, so this check would prove nothing" % UNTINTED_TAG)
	if untinted != null and not untinted.is_placeholder():
		check(not untinted.takes_scene_tint(),
			"'%s' was expected to keep the pack's own colours" % UNTINTED_TAG)
		var wooden := AssetLibrary.build(UNTINTED_TAG, pair["far"])
		if wooden != null:
			equal(_override_count(wooden), 0,
				"'%s' took a biome tint it does not carry a role for" % UNTINTED_TAG)
			wooden.free()

	here.free()
	there.free()

	# Every row that names a model says something coherent about its tint.
	for tag in AssetTags.all():
		var each := AssetLibrary.visual(tag)
		if each == null or each.is_placeholder():
			continue
		check(AssetVisual.TINT_ROLES.has(each.scene_tint_role),
			"'%s' names unknown scene tint role '%s'" % [tag, each.scene_tint_role])
		check(each.scene_tint_mix >= 0.0 and each.scene_tint_mix <= 1.0,
			"'%s' has a scene tint mix outside [0, 1]: %f" % [tag, each.scene_tint_mix])
		if each.scene_tint_role == AssetVisual.TINT_NONE:
			equal(each.scene_tint_mix, 0.0,
				"'%s' mixes towards a biome colour without naming which" % tag)
		else:
			check(each.scene_tint_mix > 0.0,
				"'%s' names a tint role and then mixes none of it in" % tag)


## The bare tree goes cold in the twilight marsh and stays brown in the meadow.
##
## Its own row, because it is the one model whose whole surface is bark: there is
## no canopy on a dead tree, so the pack's warm orange-brown is the entire thing,
## and against the marsh's teal it was the brightest object in the frame. Taking
## the foliage role fixes it without inventing a second rule -- the gain is the
## biome's foliage colour over the reference green -- and this is that stated as
## arithmetic rather than as a look: cold in the marsh, untouched in the meadow,
## and moving by the same mix as the living tree standing beside it.
func _a_dead_tree_takes_the_biome_and_does_not_stay_orange() -> void:
	var dead := AssetLibrary.visual(AssetTags.DEAD_TREE)
	check(dead != null and not dead.is_placeholder(),
		"the dead tree does not name a model, so this check would prove nothing")
	if dead == null or dead.is_placeholder():
		return
	check(dead.takes_scene_tint(),
		"the dead tree names a model and takes no biome tint, which is what made "
		+ "it read bright orange against the marsh")
	equal(dead.scene_tint_role, AssetVisual.TINT_TREE,
		"the dead tree follows '%s' rather than the foliage colour"
		% dead.scene_tint_role)

	# And it moves at least as far as the living tree beside it. A fir's green is
	# already most of the way to any biome's green; a bare tree's bark is not, so
	# it needs the whole shift rather than a nudge.
	var fir := AssetLibrary.visual(AssetTags.FIR)
	if fir != null and not fir.is_placeholder():
		check(dead.scene_tint_mix >= fir.scene_tint_mix,
			"a dead tree takes %.2f of the biome colour and the fir beside it "
			% dead.scene_tint_mix + "takes %.2f; the bare one has more to correct"
			% fir.scene_tint_mix)

	# In the meadow the foliage colour *is* the reference the gain is taken
	# against, so the gain is exactly white and the pack's bark is untouched.
	var meadow := AssetLibrary._scene_tint(dead, BiomeCatalog.profile(BiomeCatalog.MEADOW))
	check(absf(meadow.r - 1.0) < 0.02 and absf(meadow.g - 1.0) < 0.02
			and absf(meadow.b - 1.0) < 0.02,
		"a dead tree in the meadow is repainted (%.3f, %.3f, %.3f) rather than "
		% [meadow.r, meadow.g, meadow.b] + "left the colour the pack drew")

	# In the marsh the gain takes the red out and leaves the blue, which is the
	# whole of the fix: an orange-brown multiplied by it comes out cold.
	var marsh := AssetLibrary._scene_tint(
		dead, BiomeCatalog.profile(BiomeCatalog.TWILIGHT_MARSH)
	)
	check(marsh.r < marsh.b,
		"a dead tree in the twilight marsh is gained (%.3f, %.3f, %.3f), which "
		% [marsh.r, marsh.g, marsh.b] + "does not take the red out of orange bark")
	check(marsh.r < 0.55,
		"a dead tree in the twilight marsh keeps %.0f%% of its red, which is not "
		% (marsh.r * 100.0) + "enough of a shift to stop it reading as orange")

	# And the same claim about the thing that actually stands in the frame rather
	# than about the row that describes it. Everything above is arithmetic on the
	# table; this builds the model in the marsh and in the meadow and asks what
	# was hung on it, which is the step the bug lived in -- the row said one thing
	# and the instance was built with no override at all.
	var marsh_profile := BiomeCatalog.profile(BiomeCatalog.TWILIGHT_MARSH)
	var in_marsh := AssetLibrary.build(AssetTags.DEAD_TREE, marsh_profile)
	var in_meadow := AssetLibrary.build(
		AssetTags.DEAD_TREE, BiomeCatalog.profile(BiomeCatalog.MEADOW)
	)
	check(in_marsh != null and in_meadow != null,
		"the dead tree would not build")
	if in_marsh == null or in_meadow == null:
		return
	check(_override_count(in_marsh) > 0,
		"a dead tree built in the twilight marsh carries no tinted material, so "
		+ "it is drawn in the orange the pack shipped")
	var drawn = _drawn_colour(in_marsh)
	if drawn != null:
		check(drawn.r < drawn.b,
			"a dead tree standing in the twilight marsh is drawn with "
			+ "(%.3f, %.3f, %.3f), which is still warmer than it is cold"
			% [drawn.r, drawn.g, drawn.b])
	# In the meadow the gain is white, so nothing is hung at all: the pack's own
	# brown is the right answer there and the cheapest way to draw it is to leave
	# the model alone.
	equal(_override_count(in_meadow), 0,
		"a dead tree in the meadow was repainted, when the meadow's foliage "
		+ "colour is the very colour the gain is measured against")
	in_marsh.free()
	in_meadow.free()


## A repoint cannot lose the biome colour the row it replaced was carrying.
##
## This is the cause the bare tree was a symptom of, held as a check rather than
## as a fixed-up row. Every row has a placeholder underneath whatever model it
## names, and that placeholder is the row's own record of what the thing is made
## of; the tint reached a model only if the row *also* said so in two trailing
## arguments that defaulted to "no colour". So a repoint that filled in the model
## and stopped -- which is exactly the documented way to install art -- produced a
## row indistinguishable from a fence that had deliberately kept the pack's
## paint, and nothing downstream could tell the difference. Three checks, one per
## way that can go wrong now:
##
##   1. No row in the table drops its placeholder's colour today.
##   2. The repoint that caused the bug, replayed: a model filled in with nothing
##      said about its tint now inherits the placeholder's role instead of none.
##   3. Saying it wrongly is caught, so (2) cannot be talked out of.
func _a_repoint_cannot_lose_the_biome_colour() -> void:
	var dropped := AssetLibrary.dropped_tints()
	check(dropped.is_empty(),
		"models that take less of the biome than the placeholder they replaced: "
		+ ", ".join(dropped))

	# (2) The repoint that caused this, replayed. The row is built through the
	# same helper the table is written with, given the model and the placeholder
	# and nothing else -- five arguments, which is what the dead tree's row had.
	var real := AssetLibrary.visual(AssetTags.DEAD_TREE)
	if real == null or real.is_placeholder():
		return
	var rebuilt := {}
	AssetLibrary._row(
		rebuilt, AssetTags.DEAD_TREE, real.scene_path, real.parts, real.scene_height
	)
	var silent: AssetVisual = rebuilt[AssetTags.DEAD_TREE]
	check(silent.takes_scene_tint(),
		"a row that names a model and says nothing about its tint still ships "
		+ "untinted, which is the whole of why the bare tree was orange")
	equal(silent.scene_tint_role, real.placeholder_tint()["role"],
		"a silent row inherited '%s' rather than the '%s' its own placeholder "
		% [silent.scene_tint_role, real.placeholder_tint()["role"]]
		+ "takes")
	equal(silent.scene_tint_mix, real.placeholder_tint()["mix"],
		"a silent row inherited a mix of %.2f rather than its placeholder's %.2f"
		% [silent.scene_tint_mix, real.placeholder_tint()["mix"]])

	# (3) And a row that says the wrong thing out loud is named. Built from the
	# real dead tree, so the placeholder underneath really does take the foliage
	# colour, with the model told to keep the pack's paint -- the state the table
	# was in when the marsh was photographed.
	var muted := real.detached_copy()
	muted.scene_tint_role = AssetVisual.TINT_NONE
	muted.scene_tint_mix = 0.0
	AssetLibrary.repoint(AssetTags.DEAD_TREE, muted)
	var caught := AssetLibrary.dropped_tints()
	var names_it := false
	for line in caught:
		if line.begins_with("%s:" % AssetTags.DEAD_TREE):
			names_it = true
	check(names_it,
		"a model told to keep the pack's colours over a placeholder that takes "
		+ "the foliage colour was not reported: %s" % ", ".join(caught))
	AssetLibrary.restore_defaults()
	equal(AssetLibrary.dropped_tints().size(), 0,
		"the table did not come back clean after the disconnected row was undone")


## The tint is hung on the instance, never written into the pack.
##
## This is the check that keeps the whole approach honest. The mesh and the
## material a model loads with are one resource shared by every instance of it in
## the world, so tinting by writing to them would repaint every fir already
## standing the colour of the last one built -- and the failure would only show
## up as a forest that changes colour as you walk. So: two instances, two
## colours, and the resource they were both built from still exactly as the pack
## ships it afterwards.
func _a_tinted_model_leaves_the_packs_own_resources_alone() -> void:
	var row := AssetLibrary.visual(TINTED_TAG)
	if row == null or row.is_placeholder():
		return
	var pair := _two_positions_with_different_foliage()
	if pair.is_empty():
		return

	var packed: PackedScene = load(row.scene_path)
	check(packed != null, "'%s' names %s, which will not load" % [
		TINTED_TAG, row.scene_path,
	])
	if packed == null:
		return
	var untouched := packed.instantiate()
	var pack_colour = _pack_colour(untouched)
	check(pack_colour != null, "%s has no material to compare against" % row.scene_path)

	var here := AssetLibrary.build(TINTED_TAG, pair["near"])
	var there := AssetLibrary.build(TINTED_TAG, pair["far"])
	if here == null or there == null:
		untouched.free()
		return

	# The two instances really are reading one shared mesh: that is the thing a
	# careless tint would have written through.
	var shared := _first_mesh(here)
	check(shared != null and shared == _first_mesh(there),
		"the two instances do not share a mesh, so the check below proves nothing")

	# Nothing about the resource moved: not the material's colour, and not which
	# material the mesh's surface points at.
	equal(_pack_colour(here), pack_colour,
		"building a tinted '%s' changed the colour of the material the pack loaded"
		% TINTED_TAG)
	equal(_pack_colour(untouched), pack_colour,
		"a model instanced afterwards came out already tinted")
	var here_drawn = _drawn_colour(here)
	if here_drawn != null:
		not_equal(here_drawn, pack_colour,
			"the tinted instance is drawn with the pack's own colour, so nothing "
			+ "was applied")

	here.free()
	there.free()
	untouched.free()


## A thousand firs in one biome share one material, the way a thousand
## placeholder firs share one green. Without that the tint would have cost a
## material -- and a draw call -- per instance, which is the version of this
## change that would not have been worth shipping.
func _tinted_models_share_their_materials() -> void:
	var pair := _two_positions_with_different_foliage()
	if pair.is_empty():
		return
	var first := AssetLibrary.build(TINTED_TAG, pair["near"])
	var second := AssetLibrary.build(TINTED_TAG, pair["near"])
	if first == null or second == null:
		return
	var one := _drawn_material(first)
	var two := _drawn_material(second)
	check(one != null and one == two,
		"two '%s' built in the same biome do not share one material" % TINTED_TAG)

	var elsewhere := AssetLibrary.build(TINTED_TAG, pair["far"])
	if elsewhere != null:
		var other := _drawn_material(elsewhere)
		check(other != null and other != one,
			"'%s' shares one material across two different biomes" % TINTED_TAG)
		elsewhere.free()
	first.free()
	second.free()


## Two real world positions whose biomes give foliage two different colours, as
## profiles. Empty when the sampled square happens to be all one biome, which
## would make the checks above vacuous rather than failing.
func _two_positions_with_different_foliage() -> Dictionary:
	var terrain := TerrainQuery.for_seed(SEED)
	var origin := terrain.profile_at(0.0, 0.0)
	var step := 24.0
	for ring in range(1, 20):
		for corner in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
			var at: Vector2 = corner * float(ring) * step
			var other := terrain.profile_at(at.x, at.y)
			if _colour_gap(origin.tree_tint, other.tree_tint) > 0.08:
				return {"near": origin, "far": other}
	return {}


## How far apart two colours are, as a plain distance in RGB. Enough to say
## "these two biomes would visibly differ" without pretending to be perceptual.
static func _colour_gap(one: Color, other: Color) -> float:
	return Vector3(one.r - other.r, one.g - other.g, one.b - other.b).length()


## The colour one instance is actually drawn in: the albedo of the first tinted
## material hung on it, or null when nothing was hung.
func _drawn_colour(node: Node):
	var material := _drawn_material(node)
	return null if material == null else (material as BaseMaterial3D).albedo_color


## The first material an instance carries of its own, as an object, so that two
## instances can be asked whether they share one.
func _drawn_material(node: Node) -> Material:
	var view := node as MeshInstance3D
	if view != null and view.mesh != null:
		for surface in view.mesh.get_surface_count():
			var found := view.get_surface_override_material(surface)
			if found != null:
				return found
	for child in node.get_children():
		var deeper := _drawn_material(child)
		if deeper != null:
			return deeper
	return null


## The colour the *pack's* material has, reached through the shared mesh rather
## than through anything the instance carries.
func _pack_colour(node: Node):
	var view := node as MeshInstance3D
	if view != null and view.mesh != null:
		for surface in view.mesh.get_surface_count():
			var material := view.mesh.surface_get_material(surface)
			if material is BaseMaterial3D:
				return (material as BaseMaterial3D).albedo_color
	for child in node.get_children():
		var deeper = _pack_colour(child)
		if deeper != null:
			return deeper
	return null


func _first_mesh(node: Node) -> Mesh:
	var view := node as MeshInstance3D
	if view != null and view.mesh != null:
		return view.mesh
	for child in node.get_children():
		var deeper := _first_mesh(child)
		if deeper != null:
			return deeper
	return null


func _override_count(node: Node) -> int:
	var found := 0
	var view := node as MeshInstance3D
	if view != null:
		if view.material_override != null:
			found += 1
		if view.mesh != null:
			for surface in view.mesh.get_surface_count():
				if view.get_surface_override_material(surface) != null:
					found += 1
	for child in node.get_children():
		found += _override_count(child)
	return found


## A row may name a scene instead of describing primitives, and when it does,
## the tag builds from that file.
##
## This is the shape every row takes once the packs arrive, so it is worth one
## check now: an indirection whose destination form has never been run is a
## guess. The default table is left as it was found.
func _a_tag_can_point_at_a_scene() -> void:
	check(ResourceLoader.exists(EXAMPLE_SCENE),
		"the example installed model is missing from %s" % EXAMPLE_SCENE)
	if not ResourceLoader.exists(EXAMPLE_SCENE):
		return

	# Whatever the well's default row is -- a placeholder before the packs were
	# installed, a pack scene after -- the swap and the restore are the same
	# operation, so the check is that the table comes back to what it was rather
	# than to any particular form.
	var before := AssetLibrary.visual(AssetTags.WELL)
	var before_says := before.describe()

	var row := AssetVisual.new(AssetTags.WELL)
	row.scene_path = EXAMPLE_SCENE
	AssetLibrary.repoint(AssetTags.WELL, row)

	var swapped := AssetLibrary.visual(AssetTags.WELL)
	check(not swapped.is_placeholder(), "the repointed row is still a placeholder")
	equal(swapped.describe(), "scene %s" % EXAMPLE_SCENE,
		"the repointed row does not report the scene it names")

	var built := AssetLibrary.build(AssetTags.WELL)
	check(built != null, "a tag pointing at %s would not build" % EXAMPLE_SCENE)
	if built != null:
		check(_mesh_count(built) > 0,
			"the scene at %s built nothing drawable" % EXAMPLE_SCENE)
		built.free()

	AssetLibrary.restore_defaults()
	equal(AssetLibrary.visual(AssetTags.WELL).describe(), before_says,
		"restoring the defaults left the well pointing somewhere else")


## Repointing a tag is a change to the table and to nothing else.
##
## The strong form of the claim is about files, and tools/repoint_tag_demo.sh
## makes it by editing the table on disk and showing every file under sim/
## unchanged byte for byte. This is the same claim from inside a running world:
## the swap happens, what the tag resolves to changes, and neither the world's
## fingerprint nor the simulation's sources move.
func _repointing_a_tag_changes_nothing_in_the_simulation() -> void:
	var world := SimWorld.new(SEED)
	var world_before := world.digest()
	var sources_before := _simulation_sources_digest()
	var was := AssetLibrary.visual(REPOINT_TAG)
	check(was != null, "no row for '%s'" % REPOINT_TAG)
	if was == null:
		return

	AssetLibrary.repoint(REPOINT_TAG, AssetLibrary.visual(REPOINT_TO))
	var now := AssetLibrary.visual(REPOINT_TAG)
	not_equal(now.describe(), was.describe(),
		"repointing '%s' did not change what it resolves to, so the checks below "
		% REPOINT_TAG + "prove nothing")
	equal(now.tag, REPOINT_TAG, "the repointed row answers for the wrong tag")

	equal(world.digest(), world_before,
		"repointing '%s' changed the world: generation is reading the asset table"
		% REPOINT_TAG)
	equal(_simulation_sources_digest(), sources_before,
		"the simulation's sources changed while a tag was repointed")

	AssetLibrary.restore_defaults()
	equal(AssetLibrary.visual(REPOINT_TAG).describe(), was.describe(),
		"restoring the defaults did not put '%s' back" % REPOINT_TAG)


func _the_asset_check_holds() -> void:
	var violations := AssetCheck.run()
	var report := PackedStringArray()
	for violation in violations:
		report.append(AssetCheck.format_violation(violation))
	check(violations.is_empty(),
		"sim/ names art rather than tags:\n      %s" % "\n      ".join(report))

	# Guard against the check silently passing because it found nothing to scan.
	var files := AssetCheck._files_under(AssetCheck.SIM_DIR)
	check(files.size() >= 3,
		"expected the checker to find the simulation sources, found %d file(s)" % files.size())


## The rules, exercised on lines of source that do not exist on disk.
func _the_asset_check_would_notice() -> void:
	var offending := [
		"var tree = preload(\"res://assets/kaykit/forest/tree_pine.glb\")",
		"const TREE_SCENE := \"res://render/props/fir.tscn\"",
		"var packed: PackedScene = null",
		"scene = ResourceLoader.load(path)",
		"var model := \"models/rock_large.glb\"",
		"return node.instantiate()",
		"var pack_dir := \"assets/\"",
		"var visual = AssetLibrary.visual(tag)",
		"var mesh_file := \"boulder.obj\"",
	]
	for line in offending:
		not_equal(AssetCheck.first_match(line), {},
			"the checker should have flagged: %s" % line)

	var innocent = [
		"var tags := PackedStringArray([\"fir\", \"boulder\", \"bridge_wood\"])",
		"# a fir is res://assets/kaykit/tree.glb, and this comment must not trip it",
		"var blended := BiomeCatalog.blend(weights)",
		"var load_radius := 96.0",
		"func _load_chunk(key: Vector2i) -> void:",
		"parts.append(\"foliage=%.4f\" % foliage_density)",
		"var downloaded := 0",
		"profile.prop_tags = PackedStringArray([AssetTags.FIR])",
	]
	for line in innocent:
		equal(AssetCheck.first_match(line), {},
			"the checker should not have flagged: %s" % line)


## A headless run loads no visual material at all.
##
## Asked of a separate process, because the only honest way to ask is from a run
## that has nothing to do with this suite: this suite has itself loaded the whole
## render layer by the time it gets here. The run reports what the engine's own
## resource cache holds, which is a record kept without anything having to be
## loaded to keep it.
func _a_headless_run_loads_no_visual_asset() -> void:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
		"--seed", str(SEED), "--ticks", "40", "--assets",
	], output, true)
	var text := "\n".join(output)
	equal(exit_code, 0, "a headless run should exit 0 (output: %s)" % text)

	var visual := _asset_line(text, "visual-files")
	var render := _asset_line(text, "render-scripts")
	var simulation := _asset_line(text, "sim-scripts")
	check(not visual.is_empty(), "the run did not report its visual files: %s" % text)
	check(not render.is_empty(), "the run did not report its render scripts: %s" % text)
	check(not simulation.is_empty(), "the run did not report its sim scripts: %s" % text)
	if visual.is_empty() or render.is_empty() or simulation.is_empty():
		return

	equal(visual["loaded"], 0,
		"a headless run loaded %d visual asset(s): %s" % [visual["loaded"], text])
	equal(render["loaded"], 0,
		"a headless run loaded %d render-layer script(s): %s" % [render["loaded"], text])

	# The controls. Without these the two zeros above would be indistinguishable
	# from a probe that had nothing to look for, or one that never worked.
	check(visual["found"] > 0,
		"there is no visual asset in the project for the check to have missed")
	check(render["found"] > 0,
		"there is no render-layer script for the check to have missed")
	check(simulation["loaded"] > 0,
		"the run reports having loaded none of the simulation either, so its "
		+ "answer about visual assets means nothing: %s" % text)


## The "assets <label> found=N loaded=M" line for one label, as {found, loaded}.
func _asset_line(text: String, label: String) -> Dictionary:
	for line in text.split("\n"):
		if not line.contains("assets %s " % label):
			continue
		var counts := {}
		for field in line.strip_edges().split(" "):
			var parts := field.split("=")
			if parts.size() == 2 and parts[1].is_valid_int():
				counts[parts[0]] = parts[1].to_int()
		if counts.has("found") and counts.has("loaded"):
			return counts
	return {}


## A fingerprint of every source file in the simulation layer, so that "nothing
## in generation changed" can be stated as a comparison rather than as a claim.
func _simulation_sources_digest() -> String:
	var files := AssetCheck._files_under(AssetCheck.SIM_DIR)
	var sorted := Array(files)
	sorted.sort()
	var parts := PackedStringArray()
	for path in sorted:
		parts.append("%s:%s" % [path, FileAccess.get_file_as_string(path).sha256_text()])
	return "|".join(parts).sha256_text()


func _mesh_count(node: Node) -> int:
	var found := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh.get_surface_count() > 0:
			found += 1
	for child in node.get_children():
		found += _mesh_count(child)
	return found
