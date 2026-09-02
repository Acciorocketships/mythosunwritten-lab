extends RefCounted
## What grows and what stands on the world, decided one cell at a time.
##
## The sixth layer of the generation stack. The ground says how high it is, the
## biomes say what sort of country it is, the water says where the wet is, the
## islands say what is overhead and the settlements say what has been built; this
## layer reads all five and dresses the result -- trees, undergrowth, waterside
## flora, loose stone, and a catalog of made props.
##
## ## Cells, not chunks
##
## The world is covered by two lattices of square cells -- a fine one for flora,
## a coarse one for the large and the made -- and **each cell makes one
## independent decision**: either it holds one thing, or it holds nothing. That
## decision is hashed from the cell's coordinates and the world seed, exactly as
## the height of the ground is hashed from a position. A cell never looks at its
## neighbours, nothing is carried from one cell to the next, and no stream of
## random numbers is drawn from -- a stream would make what a cell holds depend
## on how many cells were decided before it, which is precisely the bug that
## makes two chunks disagree about the ground they share.
##
## Both cell sizes divide the chunk size exactly, so every cell belongs to one
## chunk and no cell is on a border. A chunk's dressing is therefore the same
## whether it was built first, built after its neighbours, or built again after
## being dropped -- and the same in another process, which is what the headless
## fingerprint is really asserting.
##
## ## One roll decides both "anything" and "what"
##
## Every row of the catalog carries a per-biome weight that is a probability, not
## a ratio. At a position the weights are blended across the biomes there and
## multiplied by whether the row's context is satisfied, and the results are laid
## end to end along [0, 1). One roll lands somewhere: inside a row's stretch and
## that row is placed, past the end of the last stretch and the cell is empty.
##
## Two things fall out of this and both are wanted. Adding a row cannot move the
## rows before it, so a table can be extended without re-rolling the world it has
## already grown. And the roll can be taken *before* anything is asked about the
## ground, so every cell whose roll lands past the largest total any biome can
## reach costs one hash and nothing else -- about three cells in eight.
##
## ## Context is what makes a prop read as intentional
##
## Every question this layer asks about a cell -- is it wet, is it a bank, is
## there a building here, how far is the road, how level is it -- is a question
## TerrainQuery already answers for somebody else. Nothing is recomputed, so a
## fern cannot disagree with the settlement layer about where a house is, and a
## cattail cannot disagree with the water field about where the water is.
class_name DecorationScatter

## How wide one cell of each lattice is, in world units. Both divide
## TerrainChunkMesher.CHUNK_SIZE exactly, which is what keeps a cell inside one
## chunk, and a lattice's cell size is also the closest two of its things can
## ever stand.
const FLORA_CELL := 2.0
const PROP_CELL := 8.0

## Where in its cell a thing stands, as a fraction of the cell. Kept off the
## edges so that two things in neighbouring cells cannot end up touching, and
## wide enough that the lattice does not show as a grid.
const JITTER_LOW := 0.18
const JITTER_HIGH := 0.82

## How far a footprint is widened before a cell inside it is refused. The
## settlement layer reserves the ground its buildings stand on; this is the
## scatter layer honouring that reservation with a little to spare, so that
## nothing grows through a wall it is merely touching.
const RESERVED_CLEAR := 0.35

## How far outside a footprint counts as that building's yard. Crates and
## barrels go here: against the wall, never inside it.
const YARD_REACH := 4.5

## The band beside a road that a road's props stand in, measured from the
## centreline. The roadway itself is 2.3 units wide and its carving eases out to
## 4.3, so this starts just outside the wheel ruts and ends a step past where the
## ground stops being road.
const PATH_SIDE_MIN := 2.6
const PATH_SIDE_MAX := 5.0

## Nothing at all stands closer to a road's centreline than this: a cart track is
## a track because things do not grow in it.
const TRACK_CLEAR := 2.4

## How much of its usual flora a village's trodden ground grows. Not none -- a
## green with nothing on it looks swept -- but thin enough that the village reads
## as inhabited.
const VILLAGE_THINNING := 0.35

## How steep the ground may be under something, as the fall in world units per
## unit walked. Above this the ground is a cliff face rather than a hillside, and
## a tree on it would hang out of the rock rather than stand in it.
##
## The land is gentle -- over a wide sample of dry ground the steepest fall is
## 0.85 per unit and 1.1% of it is steeper than 0.75 -- so this refuses the
## banks and the shoulders and nothing else. It is measured on the carved bed
## rather than on the finished ground, which costs a third as much and can only
## ever over-estimate: levelling a village or wearing a road makes ground
## flatter, never steeper, and neither grows much anyway.
const SLOPE_LIMIT := 0.75

## How far the slope is measured over, in world units.
const SLOPE_STEP := 1.0

## How far above the local water surface a position can be and still have water
## within reach of it.
##
## Whether a position is a bank is eight samples around it, which is the most
## expensive question this layer asks; almost every position it is asked about is
## nowhere near water. A bank is where the bed meets the surface, so a bank cell
## stands at most the depth of a river channel above the water line -- 2.4 units
## cut, 3.0 at the lip. Anything standing further above the water than this
## cannot have water within reach, and is refused without the eight samples.
const BANK_LIFT := 4.0

## How deep water may be and still have something standing in it -- reeds wade,
## and the depth is measured to the bed they stand on.
const WADE_DEPTH := 0.55

## How deep water has to be for a lily pad to float on it, and how deep it may
## be. The lower bound keeps pads off the waterline where the sheet fades out.
const FLOAT_MIN_DEPTH := 0.25
const FLOAT_MAX_DEPTH := 1.80

## What a clearing is: no road within this far, no village, nothing overhead, and
## less than this much relief across a circle of this radius. Only the stone
## circles need one, and this is what keeps them on open moor.
const CLEARING_ROAD_CLEAR := 5.0
const CLEARING_RADIUS := 6.0
const CLEARING_RELIEF := 1.4
const CLEARING_DIRECTIONS := 8

## This layer's own corner of the seed space, and the strides that keep its
## several rolls from ever being the same roll.
const SEED_OFFSET := 0x4D2B7A11
const SALT_STRIDE := 0x9E3779B1
const LATTICE_STRIDE := 0x27D4EB2F

# Which roll is which. Independent salts rather than successive draws, so that
# adding a roll cannot shift the ones already there.
const SALT_PICK := 1
const SALT_JITTER_X := 2
const SALT_JITTER_Z := 3
const SALT_SIZE := 4
const SALT_YAW := 5

## The seed the whole layer descends from.
var world_seed: int = 0

## Everything this layer asks about the ground. It asks; it never recomputes.
var terrain: TerrainQuery = null


func _init(query: TerrainQuery = null) -> void:
	terrain = query
	world_seed = query.world_seed if query != null else 0


## How wide one cell of a lattice is.
static func cell_size(lattice: String) -> float:
	return PROP_CELL if lattice == ScatterCatalog.LATTICE_PROP else FLORA_CELL


## Which cell of a lattice a world position falls in.
static func cell_at(lattice: String, x: float, z: float) -> Vector2i:
	var size := cell_size(lattice)
	return Vector2i(int(floor(x / size)), int(floor(z / size)))


## Everything the scatter layer puts inside one chunk.
##
## Both lattices are walked in a fixed order -- flora first, then props, each in
## cell order -- so a patch's contents are in the same order in every process. No
## state survives the call.
func build(chunk_x: int, chunk_z: int) -> ScatterPatch:
	var patch := ScatterPatch.new(Vector2i(chunk_x, chunk_z))
	for lattice in ScatterCatalog.LATTICES:
		var size := cell_size(lattice)
		var per_chunk := int(round(TerrainChunkMesher.CHUNK_SIZE / size))
		for step_x in per_chunk:
			for step_z in per_chunk:
				var cell := Vector2i(
					chunk_x * per_chunk + step_x, chunk_z * per_chunk + step_z
				)
				var item := item_in_cell(lattice, cell)
				if not item.is_empty():
					patch.items.append(item)
	return patch


## What one cell of one lattice holds: a placed thing, or an empty dictionary.
##
## This is the whole of the layer's decision, and it depends on the cell, the
## seed, and what the fields under it say about that patch of world. It depends
## on nothing else -- not on which chunk asked, not on what has been asked
## before, and not on which process is asking.
func item_in_cell(lattice: String, cell: Vector2i) -> Dictionary:
	var pick := _roll(lattice, cell, SALT_PICK)
	# The cheap way out, taken by about three cells in eight: no weight anywhere
	# can reach this far along the line, so nothing here can be placed and
	# nothing about the ground here needs to be asked.
	if lattice == ScatterCatalog.LATTICE_FLORA and pick >= ScatterCatalog.FLORA_CEILING:
		return {}

	var size := cell_size(lattice)
	var x := (float(cell.x) + lerpf(
		JITTER_LOW, JITTER_HIGH, _roll(lattice, cell, SALT_JITTER_X)
	)) * size
	var z := (float(cell.y) + lerpf(
		JITTER_LOW, JITTER_HIGH, _roll(lattice, cell, SALT_JITTER_Z)
	)) * size

	var site := _site_at(x, z)
	# Three refusals that apply to everything, whatever it is. A building's
	# reserved ground is the settlement layer's contract with this one; a cart
	# track stays a cart track; and nothing stands on a cliff face.
	if terrain.is_reserved_at(x, z, RESERVED_CLEAR):
		return {}
	if _road_distance(site) < TRACK_CLEAR:
		return {}
	if not site["water"] and _too_steep(site):
		return {}

	var running := 0.0
	for entry in ScatterCatalog.entries(lattice):
		var weight := ScatterCatalog.weight_of(entry, site["shares"])
		if weight <= 0.0:
			continue
		weight *= _context_factor(entry, site)
		if weight <= 0.0:
			continue
		running += weight
		if pick < running:
			return _placed(entry, site, lattice, cell)
	return {}


# --- The decision --------------------------------------------------------

## How much of its weight a row keeps here: zero when its context is not
## satisfied, and usually one when it is.
##
## Every branch is a question asked of TerrainQuery rather than answered here,
## which is the point: this layer decides what belongs where, and the fields
## decide what the world is like.
func _context_factor(entry: Dictionary, site: Dictionary) -> float:
	match String(entry["context"]):
		ScatterCatalog.CONTEXT_GROUND:
			if site["water"]:
				return 0.0
			return _village_factor(site)
		ScatterCatalog.CONTEXT_WET:
			# Wet ground: a bank, or water shallow enough to stand a stem in.
			# Both are the water field's own vocabulary, so nothing here can
			# disagree with it about where the wet is.
			if site["water"]:
				return 1.0 if float(site["depth"]) <= WADE_DEPTH else 0.0
			return 1.0 if _is_bank(site) else 0.0
		ScatterCatalog.CONTEXT_WATER:
			if not site["water"]:
				return 0.0
			var depth := float(site["depth"])
			return 1.0 if depth >= FLOAT_MIN_DEPTH and depth <= FLOAT_MAX_DEPTH else 0.0
		ScatterCatalog.CONTEXT_PATHSIDE:
			if site["water"]:
				return 0.0
			var away := _road_distance(site)
			return 1.0 if away >= PATH_SIDE_MIN and away <= PATH_SIDE_MAX else 0.0
		ScatterCatalog.CONTEXT_YARD:
			if site["water"]:
				return 0.0
			return 1.0 if _in_yard(site) else 0.0
		ScatterCatalog.CONTEXT_CLEARING:
			if site["water"]:
				return 0.0
			return 1.0 if _is_clearing(site) else 0.0
	return 0.0


## The placed thing itself: where it stands, which way it faces, how big it is.
func _placed(
	entry: Dictionary, site: Dictionary, lattice: String, cell: Vector2i
) -> Dictionary:
	var range_of := ScatterCatalog.size_of(entry, site["shares"])
	var size := lerpf(range_of.x, range_of.y, _roll(lattice, cell, SALT_SIZE))
	var context := String(entry["context"])
	var hover := float(entry["hover"])

	var height := _ground(site)
	if context == ScatterCatalog.CONTEXT_WATER or (hover > 0.0 and site["water"]):
		# Something that floats floats on the water, not on the bed under it.
		height = float(site["water_surface"])
	height += hover

	# A road's props line up with the road; everything else faces wherever its
	# cell's roll points it. A fence across a track would read as a mistake.
	var yaw := _roll(lattice, cell, SALT_YAW) * TAU
	if context == ScatterCatalog.CONTEXT_PATHSIDE:
		var road := _road(site)
		if not road.is_empty():
			var along: Vector2 = road["along"]
			yaw = atan2(along.x, along.y)

	return {
		"tag": String(entry["tag"]),
		"x": float(site["x"]),
		"z": float(site["z"]),
		"y": height,
		"yaw": yaw,
		"size": size,
		"kind": String(entry["kind"]),
		"context": context,
	}


# --- What the ground says here -------------------------------------------

## What is known about a candidate position, gathered once.
##
## Only the three answers every cell needs are taken up front: which biomes this
## is, where the bed is, and whether there is water over it. All three come out
## of the water field's own column, which is deliberate -- whether a position is
## water is that field's answer alone, and reading it anywhere else would let
## this layer disagree with it.
##
## Everything else is looked up only if a row asks for it, and is kept on the
## same dictionary once it has been. Most cells never need to know how far the
## nearest road is, whether they are a bank, or even what height the finished
## ground is, and asking anyway would cost more than the rest of the layer put
## together.
func _site_at(x: float, z: float) -> Dictionary:
	var column := terrain.water_field.sample_column(x, z)
	return {
		"x": x,
		"z": z,
		"shares": terrain.biome_field.weights_at(x, z),
		"bed": column.x,
		"water_surface": column.y,
		"water": column.y > column.x,
		"depth": maxf(0.0, column.y - column.x),
	}


## The height something actually stands at: the finished ground, with the
## village levelling and the road wear already in it.
##
## This is the one answer that has to come from the whole composed stack rather
## than from the water field alone, because a fern on a village green stands on
## the green rather than on the hillside that was there before it. It is asked
## only for a cell that is placing something -- about one surviving cell in two.
func _ground(site: Dictionary) -> float:
	if not site.has("ground"):
		site["ground"] = float(site["bed"]) if bool(site["water"]) \
			else terrain.ground_height_at(float(site["x"]), float(site["z"]))
	return float(site["ground"])


func _is_bank(site: Dictionary) -> bool:
	if not site.has("bank"):
		# The cheap half of the question first: something standing well above
		# the water line cannot have water within reach of it.
		site["bank"] = float(site["bed"]) - float(site["water_surface"]) <= BANK_LIFT \
			and terrain.is_bank_at(float(site["x"]), float(site["z"]))
	return bool(site["bank"])


## Whether the ground falls away faster than anything should stand on.
##
## Measured on the carved bed, one step either side, against the bed already
## known at the middle -- so it costs two samples rather than the four a full
## normal would, and it asks the same question.
func _too_steep(site: Dictionary) -> bool:
	if site.has("steep"):
		return bool(site["steep"])
	var x := float(site["x"])
	var z := float(site["z"])
	var here := float(site["bed"])
	var across := absf(terrain.water_field.bed_height_at(x + SLOPE_STEP, z) - here)
	var along := absf(terrain.water_field.bed_height_at(x, z + SLOPE_STEP) - here)
	site["steep"] = maxf(across, along) / SLOPE_STEP > SLOPE_LIMIT
	return bool(site["steep"])


## The nearest stretch of road, or an empty dictionary when there is none within
## reach. Asked once per cell at most.
func _road(site: Dictionary) -> Dictionary:
	if not site.has("road"):
		site["road"] = terrain.road_beside(float(site["x"]), float(site["z"]))
	return site["road"]


func _road_distance(site: Dictionary) -> float:
	var road := _road(site)
	return INF if road.is_empty() else float(road["distance"])


## How much of its flora a position grows, thinned where a village has trodden
## the ground flat.
func _village_factor(site: Dictionary) -> float:
	if not site.has("village"):
		site["village"] = terrain.settlement_at(
			float(site["x"]), float(site["z"])
		) != null
	return VILLAGE_THINNING if bool(site["village"]) else 1.0


## Whether this is the yard of a building: outside its reserved ground, close
## enough to be against its wall.
##
## The inside of the footprint has already been refused for everything, so this
## only has to ask about the widened one.
func _in_yard(site: Dictionary) -> bool:
	if not site.has("yard"):
		site["yard"] = terrain.is_reserved_at(
			float(site["x"]), float(site["z"]), YARD_REACH
		)
	return bool(site["yard"])


## Whether this is open, level ground away from anything anyone built.
##
## The relief is measured on a ring the placement rule never otherwise samples,
## so a stone circle stands on ground that really is flat rather than on ground
## that was assumed to be. Like the slope, it is measured on the carved bed:
## levelling only ever flattens, and a levelled site is a village or a road,
## both of which this refuses anyway.
func _is_clearing(site: Dictionary) -> bool:
	if site.has("clearing"):
		return bool(site["clearing"])
	var x := float(site["x"])
	var z := float(site["z"])
	var open := true
	if _road_distance(site) <= CLEARING_ROAD_CLEAR:
		open = false
	elif terrain.settlement_at(x, z) != null:
		open = false
	elif terrain.is_over_island_at(x, z):
		open = false
	else:
		var low := float(site["bed"])
		var high := low
		for step in CLEARING_DIRECTIONS:
			var angle := TAU * float(step) / float(CLEARING_DIRECTIONS)
			var around := terrain.water_field.bed_height_at(
				x + cos(angle) * CLEARING_RADIUS, z + sin(angle) * CLEARING_RADIUS
			)
			low = minf(low, around)
			high = maxf(high, around)
		open = high - low <= CLEARING_RELIEF
	site["clearing"] = open
	return open


# --- Rolls ---------------------------------------------------------------

## One value in [0, 1) for a cell of a lattice, hashed rather than drawn.
##
## Hashed, because a drawn number depends on how many were drawn before it and
## this layer's whole claim is that a cell does not care what was decided
## elsewhere. The lattice and the salt go into the seed rather than into the
## coordinates so that the same cell coordinates on the two lattices, and the
## several rolls of one cell, cannot collide.
func _roll(lattice: String, cell: Vector2i, salt: int) -> float:
	var lattice_index := ScatterCatalog.LATTICES.find(lattice)
	return SimRng.hash_unit(
		world_seed + SEED_OFFSET + lattice_index * LATTICE_STRIDE + salt * SALT_STRIDE,
		cell.x,
		cell.y,
	)
