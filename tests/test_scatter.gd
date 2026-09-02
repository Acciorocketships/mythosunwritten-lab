extends TestSuite
## The scatter layer: what grows and what stands, and why it is allowed to.
##
## Four claims live here, and they are the four the layer is for.
##
## *What a cell holds is a fact about that cell and the seed.* The same cells are
## asked from a fresh field, from one that has already been asked hundreds of
## unrelated questions, and in the other order; and a whole block of chunks is
## dressed front to back by one field and back to front by another, and dropped
## and reloaded through the streamer. Every route has to produce the same things
## in the same places at the same sizes -- and so does a second process, which is
## checked by running the documented headless command twice and comparing what it
## printed. The two order checks sweep a block rather than naming a chunk,
## because how much of an order-dependence a check notices is simply how much of
## the layer it sweeps.
##
## *Placement is gated by biome, in size as well as in kind.* Deep forest has to
## grow taller trees than highland does, and highland has to grow bigger rocks
## than deep forest does. That is asserted on the measured distributions rather
## than on the table, so a table edit that broke the intent would be caught.
##
## *Placement is gated by context.* Nothing may stand inside a building's
## reserved footprint or in a cart track; waterside flora may only stand on wet
## or bank ground; a road's props may only stand beside a road; a yard's props
## may only stand beside a building; and a stone circle may only stand in a
## clearing.
##
## *Everything placed is named by tag.* Every tag the layer can name has to be in
## the catalog, and the catalog's own promises about a biome -- the prop tags on
## its profile -- have to be things this layer can actually grow there.
class_name TestScatter

const SEED := 1234

## The block of chunks the waterside checks sample: the chunk holding the wettest
## 360-unit square within a kilometre of this seed's origin. The origin's own
## block is a mountain now and holds no water at all, and a claim about where
## reeds are allowed to grow needs some reeds in the sample.
const WATER_SAMPLE_CHUNK := Vector2i(30, -30)
const OTHER_SEED := 7

## How far out, in chunks, the suite looks for ground of a given biome to
## measure. Twelve chunks is about two hundred units, which for these fields
## reaches several biomes from most starting points.
const SEARCH_REACH := 12

## How many chunks of one biome the size comparison gathers. Enough that the
## medians are not one lucky tree.
const BIOME_CHUNKS := 26

## How far out, in chunks, the order sweep reaches from the origin. Six is a
## thirteen-by-thirteen block, 169 chunks.
##
## A block, rather than a chunk somebody named. An order-dependence in this layer
## does not change every chunk it touches -- it changes the ones where a roll
## happened to be sitting near the edge of a decision -- so how much of it a
## check notices is simply how much of the layer the check sweeps. The rule that
## prompted this shape (thin a cell's roll a little when the cell before it
## placed something) moves ten chunks in a block of 289 and two in a block of
## 121; naming one chunk sees it about one time in thirty.
const ORDER_REACH := 6


func _init() -> void:
	suite_name = "scatter"


func run() -> void:
	var terrain := TerrainQuery.for_seed(SEED)
	var scatter := DecorationScatter.new(terrain)

	_the_catalog_adds_up()
	_the_catalog_keeps_every_biome_profiles_promise()
	_a_cell_is_a_pure_function_of_its_cell_and_the_seed(scatter)
	_a_block_of_chunks_is_the_same_dressed_in_either_order(scatter)
	_every_chunk_dropped_and_reloaded_comes_back_identical()
	_a_different_seed_dresses_the_world_differently(scatter)
	_everything_placed_names_a_catalog_tag(scatter)
	_deep_forest_grows_taller_trees_than_highland_and_smaller_rocks(terrain, scatter)
	_nothing_stands_in_a_building_or_in_a_cart_track(terrain, scatter)
	_wet_flora_only_grows_on_wet_or_bank_ground(terrain, scatter)
	_road_props_only_stand_beside_a_road(terrain, scatter)
	_yard_props_only_stand_beside_a_building(terrain, scatter)
	_a_stone_circle_only_stands_in_a_clearing(terrain, scatter)
	_the_world_carries_the_dressing_in_its_fingerprint()
	_two_processes_dress_the_world_the_same_way()


# --- Gathering -----------------------------------------------------------

## Every thing placed in a square of chunks, with the patch it came from.
func _items_in(scatter: DecorationScatter, chunks: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for key in chunks:
		for item in scatter.build(key.x, key.y).items:
			found.append(item)
	return found


func _square(reach: int) -> Array:
	return _square_around(Vector2i.ZERO, reach)


## A block of chunks centred anywhere. The waterside checks need one: since the
## mountains went in, the ground around this seed's origin stands forty units
## above the water table and there is no reed within a hundred chunks of it.
func _square_around(middle: Vector2i, reach: int) -> Array:
	var keys := []
	for chunk_x in range(middle.x - reach, middle.x + reach + 1):
		for chunk_z in range(middle.y - reach, middle.y + reach + 1):
			keys.append(Vector2i(chunk_x, chunk_z))
	return keys


## Chunks whose middle is the given biome, nearest the origin first, up to a
## count. This is how the suite gets a fair sample of one biome's ground without
## assuming where in the world that biome happens to be for a seed.
func _chunks_of_biome(terrain: TerrainQuery, biome: String, wanted: int) -> Array:
	var found := []
	for ring in range(0, SEARCH_REACH + 1):
		for chunk_x in range(-ring, ring + 1):
			for chunk_z in range(-ring, ring + 1):
				if maxi(absi(chunk_x), absi(chunk_z)) != ring:
					continue
				var middle_x := (float(chunk_x) + 0.5) * TerrainChunkMesher.CHUNK_SIZE
				var middle_z := (float(chunk_z) + 0.5) * TerrainChunkMesher.CHUNK_SIZE
				if terrain.biome_at(middle_x, middle_z) != biome:
					continue
				found.append(Vector2i(chunk_x, chunk_z))
				if found.size() >= wanted:
					return found
	return found


func _sizes_of_kind(items: Array[Dictionary], kind: String) -> Array[float]:
	var sizes: Array[float] = []
	for item in items:
		if String(item["kind"]) == kind:
			sizes.append(float(item["size"]))
	sizes.sort()
	return sizes


func _sizes_of_tag(items: Array[Dictionary], tag: String) -> Array[float]:
	var sizes: Array[float] = []
	for item in items:
		if String(item["tag"]) == tag:
			sizes.append(float(item["size"]))
	sizes.sort()
	return sizes


## The big end of a sorted set of measurements: the ninetieth percentile.
func _high(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	return values[mini(values.size() - 1, int(float(values.size()) * 0.9))]


func _median(values: Array[float]) -> float:
	return 0.0 if values.is_empty() else values[values.size() / 2]


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _digests(scatter: DecorationScatter, chunks: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for key in chunks:
		out.append(scatter.build(key.x, key.y).digest())
	return out


# --- The catalog ---------------------------------------------------------

## The weights are probabilities laid end to end along [0, 1), so a lattice's
## rows have to add up to less than one or the tail of the table could never be
## reached. The flora lattice carries a second, tighter bound as well: the
## shortcut that throws out most cells before anything is asked about the ground
## refuses everything past it, so it has to sit at or above the real maximum.
func _the_catalog_adds_up() -> void:
	for lattice in ScatterCatalog.LATTICES:
		for biome in BiomeCatalog.IDS:
			var total := ScatterCatalog.total_weight(lattice, biome)
			check(total <= ScatterCatalog.WEIGHT_CEILING,
				"the %s rows of %s add up to %.3f, past the ceiling of %.2f"
				% [lattice, biome, total, ScatterCatalog.WEIGHT_CEILING])
			if lattice == ScatterCatalog.LATTICE_FLORA:
				check(total <= ScatterCatalog.FLORA_CEILING,
					"the flora of %s adds up to %.3f, past the shortcut's %.2f "
					% [biome, total, ScatterCatalog.FLORA_CEILING]
					+ "-- placements past it would be silently lost")

	# The one number that has to be tight rather than merely safe: a shortcut far
	# above the real maximum would throw away no cells and cost the layer its
	# speed.
	var highest := 0.0
	for biome in BiomeCatalog.IDS:
		highest = maxf(highest, ScatterCatalog.total_weight(
			ScatterCatalog.LATTICE_FLORA, biome
		))
	check(ScatterCatalog.FLORA_CEILING - highest < 0.05,
		"the flora shortcut is %.3f but nothing reaches past %.3f, so it throws "
		% [ScatterCatalog.FLORA_CEILING, highest] + "away nothing")


## The biome catalog says how thickly a biome grows (`foliage_density`) and the
## scatter catalog says what it grows. Nothing forces the two to agree, so this
## checks that they do: the biomes in order of how much flora they actually grow
## have to be the biomes in order of the density their profile advertises.
func _the_catalog_keeps_every_biome_profiles_promise() -> void:
	var ordered := BiomeCatalog.IDS.duplicate()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		return _flora_weight(a) > _flora_weight(b))
	var previous := INF
	for biome in ordered:
		var density := BiomeCatalog.profile(biome).foliage_density
		check(density <= previous,
			"%s grows more flora than a biome whose profile claims a higher "
			% biome + "foliage density (%.2f, after %.2f)" % [density, previous])
		previous = density

	# And what a profile allows has to be something the scatter layer can grow
	# there. A biome advertising a prop it never puts down is a promise the
	# world does not keep.
	for biome in BiomeCatalog.IDS:
		for tag in BiomeCatalog.profile(biome).prop_tags:
			var entry := ScatterCatalog.entry_for(tag)
			if entry.is_empty():
				# Placed by another layer -- grass by the grass layer, a
				# signpost by the path layer. Not this layer's business.
				continue
			check(float((entry["weights"] as Dictionary).get(biome, 0.0)) > 0.0,
				"%s lists '%s' among its props but the scatter table never "
				% [biome, tag] + "grows one there")


## How much flora one biome grows altogether: everything that is not stone.
##
## The waterside rows count, even though they only apply on a bank -- the marsh's
## profile calls it a thickly grown biome because of its reed beds, not in spite
## of them, and a measure that left them out would say the opposite.
func _flora_weight(biome: String) -> float:
	var total := 0.0
	for kind in [
		ScatterCatalog.KIND_TREE,
		ScatterCatalog.KIND_UNDERGROWTH,
		ScatterCatalog.KIND_WATERSIDE,
	]:
		total += ScatterCatalog.kind_weight(ScatterCatalog.LATTICE_FLORA, biome, kind)
	return total


# --- A cell is a fact about a cell and a seed -----------------------------

func _a_cell_is_a_pure_function_of_its_cell_and_the_seed(
	scatter: DecorationScatter
) -> void:
	var cells := []
	for cell_x in range(-6, 7):
		for cell_z in range(-6, 7):
			cells.append(Vector2i(cell_x, cell_z))

	var forwards := {}
	for cell in cells:
		for lattice in ScatterCatalog.LATTICES:
			forwards["%s%s" % [lattice, cell]] = _describe(
				scatter.item_in_cell(lattice, cell)
			)

	# The same cells from a field that has been asked hundreds of unrelated
	# questions, walked in the other order, with the two lattices asked the other
	# way round as well. Nothing about a cell may depend on any of that.
	var busy := DecorationScatter.new(TerrainQuery.for_seed(SEED))
	for noise in 200:
		busy.item_in_cell(
			ScatterCatalog.LATTICE_FLORA, Vector2i(300 + noise, -400 - noise)
		)
	cells.reverse()
	var mismatches := 0
	for cell in cells:
		for lattice in [ScatterCatalog.LATTICE_PROP, ScatterCatalog.LATTICE_FLORA]:
			var key := "%s%s" % [lattice, cell]
			if _describe(busy.item_in_cell(lattice, cell)) != forwards[key]:
				mismatches += 1
	equal(mismatches, 0,
		"%d cells answered differently when asked in another order from a "
		% mismatches + "field with unrelated history")


func _describe(item: Dictionary) -> String:
	if item.is_empty():
		return "-"
	return "%s,%.4f,%.4f,%.4f,%.4f,%.4f" % [
		item["tag"], item["x"], item["z"], item["y"], item["yaw"], item["size"],
	]


## A chunk's dressing has to be the same whichever order the chunks around it
## were dressed in, which is the claim the streaming rests on.
##
## Swept over a whole block, in the shape the island suite uses for the same
## claim: one field dresses 169 chunks from one corner, a second dresses the same
## 169 from the opposite corner, and the two maps of fingerprints are compared
## chunk by chunk. A single named chunk would not do -- see ORDER_REACH -- and
## neither would a check that walked both routes in the same order, which is why
## the second field is asked in reverse rather than merely being a second field.
func _a_block_of_chunks_is_the_same_dressed_in_either_order(
	scatter: DecorationScatter
) -> void:
	var chunks := _square(ORDER_REACH)

	var forwards := DecorationScatter.new(TerrainQuery.for_seed(SEED))
	var one := {}
	for key in chunks:
		one[key] = forwards.build(key.x, key.y).digest()

	var backwards_order := chunks.duplicate()
	backwards_order.reverse()
	var backwards := DecorationScatter.new(TerrainQuery.for_seed(SEED))
	var other := {}
	for key in backwards_order:
		other[key] = backwards.build(key.x, key.y).digest()

	# Chunk by chunk rather than map against map, so a failure names the chunks
	# that moved instead of only saying that something did.
	for key in chunks:
		equal(other[key], one[key],
			"chunk (%d,%d) came out different dressed back to front" % [key.x, key.y])

	# And a third route: the field this suite has been using all along, which by
	# now has answered several thousand unrelated questions.
	var strays := PackedStringArray()
	for key in chunks:
		if scatter.build(key.x, key.y).digest() != one[key]:
			strays.append("(%d,%d)" % [key.x, key.y])
	equal(strays, PackedStringArray(),
		"%d chunks were dressed differently by a field with unrelated history: %s"
		% [strays.size(), ", ".join(strays)])


## The claim the streamer rests on, made through the streamer: walk away until
## the chunks are dropped, walk back, and check that what comes back is what
## left -- for every chunk the streamer had, not for one of them.
##
## The return is made from the other side of the world, so the block is rebuilt
## with a different amount of history behind it and reached from a different
## direction. That is the failure this is really guarding against: a player
## arriving from the north finding different flora than one arriving from the
## south.
func _every_chunk_dropped_and_reloaded_comes_back_identical() -> void:
	var world := SimWorld.new(SEED)
	var block := world.scatter_streamer.loaded_keys()
	check(block.size() >= 25,
		"the streamer had only %d chunks dressed at spawn, too few to sweep"
		% block.size())
	if block.size() < 25:
		return
	var before := {}
	for key in block:
		before[key] = world.scatter_streamer.live_patch(key).digest()
	var built_before := world.scatter_streamer.patches_built

	# Far enough that every one of them is well outside the unload radius, and
	# then as far again the other way, so the walk back arrives from the far side.
	world.place_observer(world.observer_x + 400.0, world.observer_z + 400.0)
	var clinging := PackedStringArray()
	for key in block:
		if world.scatter_streamer.is_loaded(key):
			clinging.append("(%d,%d)" % [key.x, key.y])
	equal(clinging, PackedStringArray(),
		"%d chunks four hundred units away were never dropped: %s"
		% [clinging.size(), ", ".join(clinging)])
	world.place_observer(-400.0, -400.0)
	world.place_observer(0.0, 0.0)

	var missing := PackedStringArray()
	var changed := PackedStringArray()
	for key in block:
		if not world.scatter_streamer.is_loaded(key):
			missing.append("(%d,%d)" % [key.x, key.y])
			continue
		if world.scatter_streamer.live_patch(key).digest() != before[key]:
			changed.append("(%d,%d)" % [key.x, key.y])
	equal(missing, PackedStringArray(),
		"%d chunks did not come back when the observer did: %s"
		% [missing.size(), ", ".join(missing)])
	equal(changed, PackedStringArray(),
		"%d chunks came back from an unload dressed differently: %s"
		% [changed.size(), ", ".join(changed)])
	check(world.scatter_streamer.patches_built > built_before + block.size(),
		"the streamer never rebuilt the block, so the reload proved nothing")

	# The whole block again, against a field that has never dressed anything.
	var fresh := DecorationScatter.new(TerrainQuery.for_seed(SEED))
	var strays := PackedStringArray()
	for key in block:
		if fresh.build(key.x, key.y).digest() != before[key]:
			strays.append("(%d,%d)" % [key.x, key.y])
	equal(strays, PackedStringArray(),
		"%d chunks the streamer dressed differ from a fresh dressing: %s"
		% [strays.size(), ", ".join(strays)])

	# And what it hands out is a copy: writing into it must not reach the world.
	var here: Vector2i = block[0]
	var handed := world.scatter_streamer.patch(here)
	handed.items.clear()
	equal(world.scatter_streamer.live_patch(here).digest(), before[here],
		"clearing a handed-over patch changed the world's own dressing")


func _a_different_seed_dresses_the_world_differently(
	scatter: DecorationScatter
) -> void:
	var other := DecorationScatter.new(TerrainQuery.for_seed(OTHER_SEED))
	var chunks := _square(2)
	not_equal(_digests(other, chunks), _digests(scatter, chunks),
		"two seeds dressed the same chunks identically")


func _everything_placed_names_a_catalog_tag(scatter: DecorationScatter) -> void:
	var strangers := PackedStringArray()
	for item in _items_in(scatter, _square(4)):
		var tag := String(item["tag"])
		if not AssetTags.is_tag(tag) and not strangers.has(tag):
			strangers.append(tag)
	equal(strangers, PackedStringArray(),
		"the scatter layer placed things that are not catalog tags: %s"
		% ", ".join(strangers))
	for tag in ScatterCatalog.tags():
		check(AssetTags.is_tag(tag),
			"the scatter table names '%s', which is not a catalog tag" % tag)


# --- Gated by biome ------------------------------------------------------

## The task's own words: deep forest reads as tall canopy, highland as big
## boulders. Measured on what the layer actually put down, in two stretches of
## real world of each biome, rather than read back off the table it came from.
func _deep_forest_grows_taller_trees_than_highland_and_smaller_rocks(
	terrain: TerrainQuery, scatter: DecorationScatter
) -> void:
	var forest_chunks := _chunks_of_biome(terrain, BiomeCatalog.DEEP_FOREST, BIOME_CHUNKS)
	var highland_chunks := _chunks_of_biome(terrain, BiomeCatalog.HIGHLAND, BIOME_CHUNKS)
	check(forest_chunks.size() >= 8 and highland_chunks.size() >= 8,
		"expected ground of both biomes to measure, found %d forest and %d "
		% [forest_chunks.size(), highland_chunks.size()] + "highland chunks")
	if forest_chunks.size() < 8 or highland_chunks.size() < 8:
		return

	var forest := _items_in(scatter, forest_chunks)
	var highland := _items_in(scatter, highland_chunks)
	var forest_trees := _sizes_of_kind(forest, ScatterCatalog.KIND_TREE)
	var highland_trees := _sizes_of_kind(highland, ScatterCatalog.KIND_TREE)
	var forest_rocks := _sizes_of_kind(forest, ScatterCatalog.KIND_ROCK)
	var highland_rocks := _sizes_of_kind(highland, ScatterCatalog.KIND_ROCK)

	check(forest_trees.size() >= 20 and highland_trees.size() >= 5,
		"not enough trees to compare: %d in deep forest, %d in highland"
		% [forest_trees.size(), highland_trees.size()])
	check(forest_rocks.size() >= 5 and highland_rocks.size() >= 20,
		"not enough rocks to compare: %d in deep forest, %d in highland"
		% [forest_rocks.size(), highland_rocks.size()])
	if forest_trees.is_empty() or highland_trees.is_empty():
		return
	if forest_rocks.is_empty() or highland_rocks.is_empty():
		return

	check(_median(forest_trees) > _median(highland_trees) * 1.3,
		"deep forest should read as tall canopy: its trees run %.2f at the "
		% _median(forest_trees) + "median against highland's %.2f"
		% _median(highland_trees))
	check(_mean(forest_trees) > _mean(highland_trees),
		"deep forest trees average %.2f, highland's %.2f"
		% [_mean(forest_trees), _mean(highland_trees)])
	check(forest_trees[forest_trees.size() - 1] > highland_trees[highland_trees.size() - 1],
		"the tallest highland tree (%.2f) is taller than the tallest deep "
		% highland_trees[highland_trees.size() - 1] + "forest one (%.2f)"
		% forest_trees[forest_trees.size() - 1])

	# Stone is compared at the top of the range rather than at the median,
	# because both biomes are mostly pebbles and the claim is about boulders:
	# highland's scree keeps its median small while its big stones are the
	# largest things standing on it.
	check(_mean(highland_rocks) > _mean(forest_rocks) * 1.3,
		"highland should read as big boulders: its stone averages %.2f against "
		% _mean(highland_rocks) + "deep forest's %.2f" % _mean(forest_rocks))
	check(_high(highland_rocks) > _high(forest_rocks) * 1.3,
		"the big end of highland's stone runs %.2f against deep forest's %.2f"
		% [_high(highland_rocks), _high(forest_rocks)])

	var forest_boulders := _sizes_of_tag(forest, AssetTags.BOULDER)
	var highland_boulders := _sizes_of_tag(highland, AssetTags.BOULDER)
	check(highland_boulders.size() > forest_boulders.size(),
		"highland grew %d boulders and deep forest %d"
		% [highland_boulders.size(), forest_boulders.size()])
	if not highland_boulders.is_empty() and not forest_boulders.is_empty():
		check(_median(highland_boulders) > _median(forest_boulders) * 1.3,
			"a highland boulder runs %.2f at the median against a deep forest "
			% _median(highland_boulders) + "one's %.2f" % _median(forest_boulders))

	# And the mix differs in kind as well as in size: the canopy belongs to the
	# forest and the moor grows none of it.
	var forest_canopy := 0
	var highland_canopy := 0
	for item in forest:
		if String(item["tag"]) == AssetTags.CANOPY_TREE:
			forest_canopy += 1
	for item in highland:
		if String(item["tag"]) == AssetTags.CANOPY_TREE:
			highland_canopy += 1
	check(forest_canopy > highland_canopy,
		"deep forest grew %d canopy trees and highland %d"
		% [forest_canopy, highland_canopy])


# --- Gated by context ----------------------------------------------------

## The contract the settlement layer wrote down when it reserved its footprints,
## and the one the path layer wrote down when it carved its roads.
func _nothing_stands_in_a_building_or_in_a_cart_track(
	terrain: TerrainQuery, scatter: DecorationScatter
) -> void:
	var villages := terrain.settlement_field.settlements_near(0.0, 0.0, 400.0)
	check(not villages.is_empty(), "expected a village within reach of the origin")
	var chunks := []
	for site in villages:
		var middle := TerrainChunkMesher.chunk_at(site.centre_x, site.centre_z)
		for offset_x in range(-2, 3):
			for offset_z in range(-2, 3):
				chunks.append(Vector2i(middle.x + offset_x, middle.y + offset_z))
	var items := _items_in(scatter, chunks)
	check(items.size() > 100,
		"only %d things stand around the villages, which is too few to be "
		% items.size() + "evidence of anything")

	var inside := 0
	var in_track := 0
	for item in items:
		var x := float(item["x"])
		var z := float(item["z"])
		if terrain.is_reserved_at(x, z):
			inside += 1
		if terrain.road_distance_at(x, z) < DecorationScatter.TRACK_CLEAR:
			in_track += 1
	equal(inside, 0,
		"%d of %d things stand inside a building's reserved footprint"
		% [inside, items.size()])
	equal(in_track, 0,
		"%d of %d things stand in a cart track" % [in_track, items.size()])

	# The check is only worth anything if the villages really are being scattered
	# over: a layer that put nothing anywhere near a village would pass it.
	var near_building := 0
	for item in items:
		if terrain.is_reserved_at(
			float(item["x"]), float(item["z"]), DecorationScatter.YARD_REACH
		):
			near_building += 1
	check(near_building > 0,
		"nothing at all stands within a few steps of a building, so the "
		+ "footprint check proved nothing")


## Reeds, cattails, toadstools and lily pads: the water field's own vocabulary
## decides where they are allowed, and this asks the water field about every one
## of them.
func _wet_flora_only_grows_on_wet_or_bank_ground(
	terrain: TerrainQuery, scatter: DecorationScatter
) -> void:
	var items := _items_in(scatter, _square_around(WATER_SAMPLE_CHUNK, 6))
	var wet_things := 0
	var dry_mistakes := 0
	var floating := 0
	var floating_mistakes := 0
	for item in items:
		if String(item["kind"]) != ScatterCatalog.KIND_WATERSIDE:
			continue
		var x := float(item["x"])
		var z := float(item["z"])
		wet_things += 1
		if not terrain.is_water_at(x, z) and not terrain.is_bank_at(x, z):
			dry_mistakes += 1
		if String(item["context"]) == ScatterCatalog.CONTEXT_WATER:
			floating += 1
			if not terrain.is_water_at(x, z):
				floating_mistakes += 1
	check(wet_things >= 10,
		"only %d pieces of waterside flora were found, which is too few to be "
		% wet_things + "evidence")
	equal(dry_mistakes, 0,
		"%d of %d pieces of waterside flora stand on ground that is neither wet "
		% [dry_mistakes, wet_things] + "nor a bank")
	equal(floating_mistakes, 0,
		"%d of %d floating things are not on water" % [floating_mistakes, floating])

	# And the other way round: dry-ground flora never stands in water.
	var drowned := 0
	for item in items:
		if String(item["context"]) != ScatterCatalog.CONTEXT_GROUND:
			continue
		if terrain.is_water_at(float(item["x"]), float(item["z"])):
			drowned += 1
	equal(drowned, 0, "%d dry-ground things are standing in water" % drowned)


func _road_props_only_stand_beside_a_road(
	terrain: TerrainQuery, scatter: DecorationScatter
) -> void:
	var items := _items_in(scatter, _square(8))
	var beside := 0
	var strays := 0
	for item in items:
		if String(item["context"]) != ScatterCatalog.CONTEXT_PATHSIDE:
			continue
		beside += 1
		var away := terrain.road_distance_at(float(item["x"]), float(item["z"]))
		if away < DecorationScatter.PATH_SIDE_MIN or away > DecorationScatter.PATH_SIDE_MAX:
			strays += 1
	check(beside >= 3,
		"only %d road props were found in a sixteen-chunk square, which is too "
		% beside + "few to be evidence")
	equal(strays, 0,
		"%d of %d road props are not beside a road" % [strays, beside])


func _yard_props_only_stand_beside_a_building(
	terrain: TerrainQuery, scatter: DecorationScatter
) -> void:
	var villages := terrain.settlement_field.settlements_near(0.0, 0.0, 700.0)
	var chunks := []
	for site in villages:
		var middle := TerrainChunkMesher.chunk_at(site.centre_x, site.centre_z)
		for offset_x in range(-2, 3):
			for offset_z in range(-2, 3):
				chunks.append(Vector2i(middle.x + offset_x, middle.y + offset_z))
	var yards := 0
	var strays := 0
	for item in _items_in(scatter, chunks):
		if String(item["context"]) != ScatterCatalog.CONTEXT_YARD:
			continue
		yards += 1
		if not terrain.is_reserved_at(
			float(item["x"]), float(item["z"]), DecorationScatter.YARD_REACH
		):
			strays += 1
	check(yards >= 3,
		"only %d yard props were found around %d villages, which is too few to "
		% [yards, villages.size()] + "be evidence")
	equal(strays, 0,
		"%d of %d yard props are not beside a building" % [strays, yards])


func _a_stone_circle_only_stands_in_a_clearing(
	terrain: TerrainQuery, scatter: DecorationScatter
) -> void:
	var circles := 0
	var strays := 0
	for item in _items_in(scatter, _square(10)):
		if String(item["tag"]) != AssetTags.STONE_HENGE:
			continue
		circles += 1
		var x := float(item["x"])
		var z := float(item["z"])
		if terrain.road_distance_at(x, z) <= DecorationScatter.CLEARING_ROAD_CLEAR:
			strays += 1
		elif terrain.settlement_at(x, z) != null:
			strays += 1
		elif terrain.is_over_island_at(x, z):
			strays += 1
	check(circles >= 1,
		"no stone circles at all were found in a twenty-chunk square")
	equal(strays, 0,
		"%d of %d stone circles stand on a road, in a village, or under an "
		% [strays, circles] + "island")


# --- The world and the outside world -------------------------------------

## The dressing is part of the world, so the world's fingerprint has to move when
## it changes. Without this the determinism checks could pass on a world that had
## quietly stopped dressing anything.
func _the_world_carries_the_dressing_in_its_fingerprint() -> void:
	var world := SimWorld.new(SEED)
	check(world.scatter_streamer.item_count() > 50,
		"a world at rest has dressed only %d things"
		% world.scatter_streamer.item_count())
	var before := world.digest()
	# Any dressed chunk will do, and it has to be one with something on it: the
	# chunk under the observer can be the middle of a lake.
	var patch: ScatterPatch = null
	for key in world.scatter_streamer.loaded_keys():
		var found := world.scatter_streamer.live_patch(key)
		if found != null and found.count() > 0:
			patch = found
			break
	check(patch != null, "no loaded chunk has anything on it to change")
	if patch == null:
		return
	patch.items.remove_at(0)
	not_equal(world.digest(), before,
		"taking a thing out of the world did not change the world's fingerprint")


## The claim made from outside: two processes told nothing but a seed have to
## report the same dressing, thing by thing, and two seeds must not. This runs
## the documented headless command as a real subprocess, which is the only way a
## shared object or a stale bit of state cannot make two answers agree for the
## wrong reason.
##
## The third run is the one that matters for headless mode: it asks the same
## process what visual material it loaded, and the answer has to be none while
## the dressing was still placed.
func _two_processes_dress_the_world_the_same_way() -> void:
	var same_a := _run_headless(["--seed", "1234", "--ticks", "0", "--scatter"])
	var same_b := _run_headless(["--seed", "1234", "--ticks", "0", "--scatter"])
	var different := _run_headless(["--seed", "4321", "--ticks", "0", "--scatter"])

	equal(same_a["exit_code"], 0,
		"the scatter report should exit 0 (stdout: %s)" % same_a["output"])
	check(same_a["output"].contains("scatter-summary"),
		"the scatter report printed no summary line")
	check(same_a["output"].split("\n").size() > 200,
		"the scatter report found almost nothing to report")
	equal(same_a["output"], same_b["output"],
		"two processes dressed the same world differently")
	not_equal(different["output"], same_a["output"],
		"two seeds dressed the world identically")

	var headless := _run_headless(["--seed", "1234", "--ticks", "8", "--assets"])
	equal(headless["exit_code"], 0, "the headless run should exit 0")
	check(headless["output"].contains("assets visual-files found="),
		"the headless run printed no asset report")
	check(not headless["output"].contains("assets visual-files found=0"),
		"there is no visual material in the project to have avoided loading")
	check(headless["output"].contains("loaded=0 -> ") == false,
		"the headless run loaded visual material")
	for line in headless["output"].split("\n"):
		if line.begins_with("assets visual-files") or line.begins_with("assets render-scripts"):
			check(line.contains("loaded=0"),
				"a headless run loaded something visual: %s" % line)
	var placed := 0
	for line in headless["output"].split("\n"):
		if not line.begins_with("tick "):
			continue
		for field in line.split(" "):
			if field.begins_with("props="):
				placed = maxi(placed, field.substr(6).to_int())
	check(placed > 50,
		"a headless run placed only %d things, so it cannot show that the "
		% placed + "dressing happens without any visual asset")


## Run the documented headless command and capture what it printed.
func _run_headless(arguments: Array) -> Dictionary:
	var command: Array = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://bin/headless_main.gd",
		"--",
	]
	command.append_array(arguments)
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), command, output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}
