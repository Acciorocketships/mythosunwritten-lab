extends RefCounted
## Where the world's floating islands are: the aerial layer of the stack.
##
## This is the fourth layer, over the ground's height, the biomes and the water.
## Unlike those three it is not a continuous field but a *sparse* one: most
## positions have no island over them at all. So instead of a value per position
## it works on a lattice of cells, each of which either holds one island or does
## not, decided by a hash of the cell and the world seed. To find out what is
## over a position you look at the handful of cells whose island could reach it.
##
## Nothing here is drawn from a stream, and nothing depends on what has been
## asked before: which cells hold islands, and what those islands are, is a pure
## function of the cell, the band and the world seed. Islands therefore appear
## and disappear as you walk without ever changing, and two processes building
## the same island build the same island.
##
## ## The two bands
##
## Islands come in two bands, and the difference between them is the whole
## design of the layer:
##
## * **Aerial** islands are ground, in two storeys. They are small, they are
##   common enough to be a routine part of a walk, and their top surface is a
##   surface the terrain query hands out like any other -- you stand on one, and
##   the void off its edge is a hole in the world.
## * **Far-sky** islands are scenery. They are large, they hang far above
##   everything, and they are never walkable and never part of any answer about
##   the surface. They exist so that the sky has depth, and they drift, which
##   aerial islands deliberately do not.
##
## ## Why the aerial band is a staircase
##
## An island has to read as floating and be routine to walk onto, and those pull
## against each other: anything high enough to look airborne is too high to step
## onto, and anything low enough to step onto looks like a rock sitting on a
## hill. Neither a jump check nor a required bridge is a good way out -- the
## first puts the whole layer behind an ability score, the second makes wild
## islands unreachable and belongs to the settlement layer anyway.
##
## The way out taken here is that every island is placed a hop above *whatever it
## overhangs*, and what it overhangs need not be the ground. The lower storey's
## rim goes a hop above the highest ground under that rim, so you walk onto it
## from the ridge it overhangs. The upper storey's rim goes a hop above the
## highest thing under *its* rim, which -- because it laps over the lower island
## -- is the lower island, so you walk onto it from there. Two hops from the land, an upper island's rim stands about ten units up
## with sky under both plates -- airborne by any reading, and reached without a
## single check.
##
## An island of either storey is only placed at all when there is room under it
## for a keel that clears what is below. That single rule is the whole of where
## islands are: they hang where there is somewhere to hang. The reasoning, the
## numbers and the measured distributions are in reports/islands.md.
class_name IslandField

## World units across one cell of the aerial lattice. One island at most per
## cell, so this and the chance below are what "sparse" means in numbers.
const AERIAL_CELL := 88.0

## How many aerial cells hold an island before the room-underneath rule is
## applied. Many of these are then rejected for having nowhere to hang, so the
## density that survives is lower -- measured, and written down, in the report.
const AERIAL_CHANCE := 0.48

## How wide a lower-storey aerial island is, in world units.
##
## Wide, on purpose, and the reason is a ratio rather than an altitude. The band
## is already low -- an island's rim goes one hop above the ground it overhangs,
## which is a median of about five and a half units up. What made the old
## islands read as hovering saucers was not that number but its ratio to their
## width: a thirteen-unit plate five units up hovers, and a twenty-unit chunk
## five units up is a mesa that broke off. So the lever is the radius, and this
## is the lever pulled: roughly double the old 6.5-13, which takes the median
## island from about two of its own radii above the land to about four.
const AERIAL_RADIUS_MIN := 10.0
const AERIAL_RADIUS_MAX := 24.0

## How many lower-storey islands carry an upper storey above them.
const UPPER_CHANCE := 0.85

## How wide an upper-storey island is, as a share of the island under it, and how
## far its centre is shifted sideways from it -- also as a share of the lower
## island's radius.
##
## The shift is measured against the two radii added together, so it means the
## same thing whatever size the pair are: at 1.0 the outlines would just touch,
## and everything below that is overlap. It is kept high on purpose, so the upper
## plate hangs *beside* the lower one and only laps over its rim. That is what
## makes the pair a staircase rather than a lid: the overlap is the stretch of
## rim you walk up at, and everywhere else there is open sky under the upper
## plate for its keel to hang into. Directly overhead there would be no room for
## a keel at all, and the two would read as one lumpy island.
##
## The ceiling on the size share is also what keeps the cell scan cheap. A cell's
## island has to be found from any position its outline reaches, and `band_reach`
## below turns these four numbers into that distance; at 0.70 it stays under the
## 88-unit cell, so a query looks at five cells across rather than seven.
const UPPER_RADIUS_SHARE_MIN := 0.50
const UPPER_RADIUS_SHARE_MAX := 0.70
const UPPER_OFFSET_SHARE_MIN := 0.82
const UPPER_OFFSET_SHARE_MAX := 0.99

## How far an aerial island's rim stands above the highest thing under *the rim*
## -- the ground for the lower storey, the lower storey for the upper one.
##
## Under the rim rather than under the whole island, because the rim is the only
## part of an island you can arrive at: a hillock under the middle of a plate is
## something the plate has to clear, not something anyone can step up from. This is the step up onto it. The floor is what makes every island
## reachable, and the ceiling is what keeps that step a hop rather than a climb:
## it is below TerrainQuery.HOP_HEIGHT, which is what ordinary movement can
## carry someone up in one go. An observer marker is 1.2 units tall, so this is
## one to two body-heights.
const AERIAL_LIFT_MIN := 1.8
const AERIAL_LIFT_MAX := 2.9

## How thick an aerial island is at its rim: the cliff you stand at the top of.
## Thick enough to read as a cliff from the diorama camera rather than as a line
## where two colours meet, and still thin enough that the lip clears the ground
## at the landing, where the island comes closest to what is under it.
const AERIAL_RIM_THICKNESS := 1.2

## How far the middle of an aerial island stands above its rim, as a share of
## its radius.
##
## A share rather than a fixed number of units, and a large one. The old fixed
## 1.1-2.9 units on a 6.5-13 unit radius made a top that was nearly flat -- the
## island was a lid with a slight curve, which is half of what made it a saucer.
##
## The share that replaced it, a third to a half, was still not enough, and the
## camera the game is played from is why. It stands 42 units up and 52 back and
## looks down 31.6 degrees, and a downward view foreshortens height twice over:
## once by the cosine of that angle, and again because the frame is wider than it
## is tall, so a degree across the frame is 10.7 pixels and a degree up it is
## only 8.6. Together a world unit of height reads as 0.69 of a world unit of
## width. An island whose summit stood a third of its radius above its rim
## therefore drew a hill one *tenth* of its own width tall -- a lid, measured.
##
## At half to three quarters of the radius, with the surface standing most of
## that rather than half of it (FloatingIsland.RELIEF_FLOOR), the same island
## draws a hill about three tenths of its width tall. An eighteen-unit island
## rises eleven or twelve units from rim to summit, over shelves that are each a
## step rather than a climb.
const AERIAL_RELIEF_SHARE_MIN := 0.55
const AERIAL_RELIEF_SHARE_MAX := 0.75

## How deep the deepest spur of the keel would like to be, as a share of the
## radius, and the least it may be before the island is not placed at all.
##
## The share is lower than it was because the radius is much larger: at the old
## 0.62 a full-sized island would want a fifteen-unit keel, which is a stalactite
## rather than the underside of a piece of ground. What the keel loses in depth
## the top gains in relief, so the island as a whole is no shallower -- it is
## land-shaped rather than lens-shaped.
const AERIAL_KEEL_SHARE := 0.45
const AERIAL_KEEL_MIN := 2.0

## How far an island's keel must stay clear of whatever is below it, in world
## units. This is the whole placement rule: an island exists where there is room
## under it, and nowhere else. It is daylight as much as a constraint -- a keel
## that stopped exactly at the ground would read as a stalk holding the island
## up rather than as nothing holding it up.
const CLEARANCE := 1.0

## World units across one cell of the far-sky lattice, and how many of its cells
## hold an island. Much coarser: these are landmarks on the horizon, and a sky
## crowded with them would read as rubble rather than as distance. The lattice is
## also wider than the ground the camera can see, so most of the ones in view are
## a long way off -- one directly overhead is possible and dramatic, but it
## should be a surprise rather than the usual case.
const FAR_CELL := 320.0
const FAR_CHANCE := 0.85

## How wide a far-sky island is. Large, because it is seen from a long way off.
const FAR_RADIUS_MIN := 18.0
const FAR_RADIUS_MAX := 46.0

## What a far-sky island's profile is, as shares of its radius: how far its top
## rises above its rim, how thick the plate is at the rim, and how far its
## deepest spur hangs.
##
## These are the numbers that used to read most strongly as a flying saucer, and
## for a reason worth writing down: a far-sky island is only ever seen in
## silhouette against the sky, so its outline *is* the whole of it. A plate one
## fourteenth of its width thick, under a top that rose a tenth of its width,
## over a smooth cone six tenths of its width deep, is a saucer seen edge-on
## whatever the top surface is doing. A thick rim, a top with as much relief as
## an aerial island's, and a shallower keel of uneven spurs give a silhouette
## with a broken edge instead.
const FAR_RELIEF_SHARE_MIN := 0.34
const FAR_RELIEF_SHARE_MAX := 0.48
const FAR_RIM_SHARE := 0.20
const FAR_KEEL_SHARE := 0.40

## The far-sky altitude band, in world units above the world's datum. The ground
## itself lives roughly within plus or minus twelve units of the datum, so the
## floor of this band is three times the tallest hill: high enough that a far-sky
## island is unmistakably sky rather than terrain, and low enough that from the
## diorama camera -- which sits forty units up and looks down -- one a couple of
## hundred units away sits just above the horizon rather than out of frame.
const FAR_ALTITUDE_MIN := 24.0
const FAR_ALTITUDE_MAX := 66.0

## How far a far-sky island wanders, how fast, in world units and radians per
## second. Slow and small: this is parallax, not motion anyone watches.
const FAR_DRIFT_RADIUS_MIN := 1.5
const FAR_DRIFT_RADIUS_MAX := 5.0
const FAR_DRIFT_RATE_MIN := 0.04
const FAR_DRIFT_RATE_MAX := 0.13

## How many walkable islands hold a pond, before the shape of the island is
## allowed to refuse one.
##
## A third, not all of them, because a pond has to read as something you find
## rather than as what an island is. Some of these are then refused for having
## a bowl too shallow to hold anything worth the name, so the share that
## survives is lower; the report measures it.
const BASIN_CHANCE := 0.34

## How far out the bowl reaches, as a share of the way from the island's middle
## to its outline.
##
## Stated in that share rather than in world units so that the basin is a
## smaller copy of the island's own torn plan -- a pond with inlets and a
## peninsula in it, not a circle stamped on a chunk of land. Kept well inside
## the shelved band at the rim, so the bowl never eats into the boundary and
## `rim_height` stays the lowest the top surface gets there.
const BASIN_REACH_MIN := 0.30
const BASIN_REACH_MAX := 0.50

## How far the floor of the basin dips *below* the island's rim, in world units.
##
## This is the number that makes the island read as ground with a hollow in it
## rather than as a hill with a puddle on top, and it is why the top surface is
## allowed under the rim at all. Its ceiling is under AERIAL_RIM_THICKNESS, so
## the floor of the deepest pond still stands above the underside of the rim's
## own lip and the plate never cuts through itself.
const BASIN_DIP_MIN := 0.25
const BASIN_DIP_MAX := 0.85

## How deep the water in a basin may stand at its deepest, in world units.
##
## The cut itself has to reach from the island's middle down to just under the
## rim, so on an island standing twelve units above its rim the hollow is twelve
## units deep. Filling that hollow to its lip would put a four-metre crater lake
## on a floating island, and -- because the pond's floor would then climb the
## whole way up the bowl's wall -- one whose two sides are not the same storey:
## measured on the island the combat board suite picks, the floor of the pond
## fell four units across its own width, past TerrainQuery.DROP_REACH, and the
## board stopped calling the far side of its own pond water.
##
## Capped here instead, the hollow stays as deep as the island is high and the
## water in it is a tarn at the bottom of it. The ceiling is under
## TerrainQuery.HOP_HEIGHT on purpose: the floor of a pond rises by exactly the
## pond's depth from its middle to its shore, so a pond no deeper than a hop is a
## pond whose whole floor is one storey.
const BASIN_MAX_DEPTH := 2.40

## How full the bowl stands, as a share of the way from its floor up to its
## lowest lip, and how far below that lip the water has to stop.
##
## The freeboard is what keeps the pond inside the bowl: the water may not reach
## the lowest point of the ring where the bowl meets the hillside, or it would
## be leaning on ground that slopes away from it in every direction.
const BASIN_FILL_SHARE := 0.72
const BASIN_FREEBOARD := 0.30

## How deep the pond has to be at its middle before it is worth having. Below
## this the bowl is a damp patch, and the island is built without one.
const BASIN_MIN_DEPTH := 0.35

## How many directions the bowl's lip is sampled in to find the lowest point of
## it. The water level is decided from that one number, so it is sampled about
## as finely as the rim itself.
const BASIN_LIP_DIRECTIONS := 24

## How far above the rim the spillway's floor has to sit before an overflow is
## allowed at all.
##
## The channel is cut to `water_level - FloatingIsland.SPILL_DEPTH`, and that
## has to stay above `rim_height` or the cut would reach the boundary and the
## rim would stop being the lowest point along it. A pond whose surface is not
## this far clear of its island's rim simply has no outlet.
const SPILL_MARGIN := 0.12

## How wide the spillway is, as a half-angle in radians measured from the
## island's middle.
const SPILL_HALF_ANGLE_MIN := 0.13
const SPILL_HALF_ANGLE_MAX := 0.26

## How far the waterfall falls, as a multiple of the island's keel depth, and
## how many steps the search for the point on the outline it falls from takes.
##
## Past the tip of the keel, so the water is last seen falling below the lowest
## thing the island has -- a fall that stopped at the underside would read as
## water running along the bottom of the plate.
const SPILL_FALL_MIN := 1.15
const SPILL_FALL_MAX := 1.85
const SPILL_EDGE_STEPS := 22

## How far an island's centre is jittered inside its cell, as a share of the
## cell. Kept off the cell's own edges so that two islands in neighbouring cells
## cannot end up on top of each other.
const JITTER_LOW := 0.22
const JITTER_HIGH := 0.78

## What an island's plan outline is made of.
##
## Two to four overlapping blobs, unioned. Blob 0 is centred and is most of the
## island; the others are offset in shares of the radius and spread round it, so
## where two blob arcs cross the boundary turns a corner *into* the island -- an
## inlet -- and where one reaches past the rest it runs out and back -- a
## peninsula. A circle with a few bounded sine lobes on it, which is what this
## replaces, can do neither: it is a radius that varies, so it is convex-ish
## everywhere and reads as a cookie-cutter disc.
##
## The union is read along a ray from the island's middle, so the outline is
## still one radius per direction and `ratio_at` is still single-valued. What
## that costs is the concave *pockets* a true union can have -- a channel between
## two blobs that the middle cannot see is filled in. That is a fair trade: a
## pocket the middle cannot see is a place where "how far out are you" has no
## answer, and every caller of `ratio_at` needs one.
##
## The numbers are set by how far apart the blobs have to stand before the union
## stops reading as one slightly dented disc. At a core of 0.66 radii with the
## others offset 0.34-0.62 and 0.38-0.62 across, every offset blob sat almost
## entirely *inside* the core, and what came out was an oval: measured from the
## playing camera, the deepest inward turn of the boundary was real (a third of
## the widest reach) but it was the ovalness, not a bay. A core of 0.56 with the
## others offset 0.46-0.74 puts each of them mostly outside the core, so the
## union is a two-to-four-lobed chunk. The floor of the offset range and the
## ceiling of the radius range are what keep the pieces joined: the furthest an
## offset blob's near edge can fall from the middle is 0.74 - 0.34 = 0.40 radii,
## which is inside the core, so no blob can ever float free of the island.
const BLOB_COUNT_MIN := 2
const BLOB_COUNT_MAX := 4
const BLOB_CORE_SHARE := 0.56
const BLOB_OFFSET_MIN := 0.46
const BLOB_OFFSET_MAX := 0.74
const BLOB_RADIUS_MIN := 0.34
const BLOB_RADIUS_MAX := 0.52

## How far the extra blobs are pushed off the even spacing they would otherwise
## take round the island, in radians. Even spacing keeps an island from growing
## all its peninsulas on one side; the jitter keeps the spacing from reading as
## a rosette.
const BLOB_SPREAD_JITTER := 0.35

## How much the fine crenellation on the outline wobbles it, summed over its two
## short lobes. Small: this is the roughness on a torn edge, and the shape of the
## tear is the blobs' job.
##
## Left where it was, and that is a result rather than an omission. Doubling it
## to 0.15 was tried as a way of roughening the silhouette from the playing
## camera and measurably did not: on the same island the outline's mean deviation
## from its own mean reach went from 0.092 to 0.098 of that reach -- a fifth of a
## pixel on an island a hundred and forty pixels wide. The reason is in the
## arithmetic. The bound is split over two lobes whose amplitudes are hashed
## uniformly either side of zero, so an average island uses a quarter of it per
## lobe, and two sine waves at five and nine cycles with unrelated phases cancel
## as often as they add. What it does do is raise OUTLINE_REACH_MAX, and through
## it the cell scan, the crowding rule and the density -- so it changes which
## cells hold islands while leaving the edge of each one where it was. The lever
## that actually roughened the outline is the blob offsets above.
const OUTLINE_WOBBLE := 0.07

## The most an island's outline can reach, as a multiple of its nominal radius.
## An offset blob always reaches further than the centred one (0.74 + 0.52 is
## more than 0.56), and the crenellation can add its whole span on top of that.
## This is the bound `band_reach` and the crowding rule are written in terms of,
## and `FloatingIsland.max_reach()` never exceeds it. Pushing the blobs apart
## raises it, and through it the reach the cell scan and the crowding rule use:
## 1.327 radii became 1.348, and a band reach of 75.9 units became 77.1 -- still
## inside the 88-unit cell, so a query still looks at five cells across and not
## seven.
const OUTLINE_REACH_MAX := (BLOB_OFFSET_MAX + BLOB_RADIUS_MAX) * (1.0 + OUTLINE_WOBBLE)

## How far the keel's depth varies with direction. `SPUR_BASE` is the share of
## the full depth an average direction hangs to, and the two lobes take it up to
## all of it on one side and down to about four tenths on another. Their
## amplitudes are chosen so the two can only just reach 1.0 together, which is
## what makes `keel_depth` mean "the deepest spur" rather than "roughly the
## depth".
const SPUR_BASE := 0.72

## How sharply the keel narrows, per island and per direction: a base drawn from
## this range and a swing drawn from the one below, so the exponent stays inside
## FloatingIsland's KEEL_TAPER_MIN..MAX whatever is rolled. The floor is what the
## placement rule bounds every direction with at once.
const SPUR_TAPER_BASE_MIN := 2.2
const SPUR_TAPER_BASE_MAX := 2.6
const SPUR_TAPER_SWING_MIN := 0.30
const SPUR_TAPER_SWING_MAX := 0.50

## How many cells either way the crowding rule looks. Two rather than one,
## because an upper storey hangs almost a full island's width off to the side of
## the lower one it stands on, so two upper islands whose cells are not
## neighbours can still end up beside each other.
const CROWD_REACH := 2

## How the footprint under an island is sampled when its height is being
## decided: rings out to the rim, and this many directions on each. Dense,
## because the whole placement rule is a statement about the ground under the
## island, and a rule enforced on too few samples is not enforced.
const FOOTPRINT_RINGS := 8
const FOOTPRINT_DIRECTIONS := 16

## How many directions the rim itself is sampled in. More than the inner rings,
## because the highest point of the rim is what the island's whole height is
## measured from, and a rim sampled coarsely would put the landing between two
## samples.
const RIM_DIRECTIONS := 32

## Seed offsets, so the two bands are independent of each other and of every
## other field in the stack, and so that each hashed quantity of an island is
## independent of the others. Arbitrary large odd numbers.
const BAND_SEED_OFFSETS := [0x27D4EB2F, 0x165667B1, 0x4F1BBCDD]
const SALT_STRIDE := 0x9E3779B1

## How many islands are remembered at once. Building an island samples the
## ground under it more than a hundred times, and a walking observer asks about
## the same few cells every tick, so they are memoised. This changes no answer:
## a forgotten island is rebuilt into exactly the same island, because building
## one reads nothing but its cell, its band and the seed.
const MEMO_LIMIT := 512

## How many candidates are remembered at once. Larger than the island memo,
## because a candidate is a handful of floats where an island is two
## heightfields, and because the cell scan asks for far more candidates than it
## builds islands -- that is the whole point of asking.
const CANDIDATE_MEMO_LIMIT := 8192

## The seed the whole island layer descends from.
var world_seed: int = 0

## The ground an aerial island has to hang clear of. This is the carved bed --
## the same ground anything walks on -- so an island over a river valley is
## measured against the valley floor rather than against the land before the
## river cut it.
var water: WaterField = null

## Which biome the ground below an island is, which is the biome the island
## takes its colours from.
var biomes: BiomeField = null

## Whether the shared cell scan asks each cell's candidate bound before building
## it. On is what the world runs with, and turning it off changes no answer --
## only the price -- which is exactly what the suite checks by running both.
## Nothing but that check should ever turn it off.
var gate_cells_by_candidate := true

## How many cells this field has actually built, over its whole life, counting
## the ones that turned out to hold no island. It is the field's own cost in the
## unit that costs: a build samples the ground about a hundred and fifty times,
## and everything else here is hashes. Benches read it; nothing in the world
## does, and it is not part of any answer.
var builds := 0

# Vector3i(cell x, cell z, band) -> FloatingIsland or null for "no island here".
var _memo := {}

# Vector3i(cell x, cell z, band) -> the cell's candidate, empty for "none here".
var _candidate_memo := {}


func _init(water_field: WaterField = null, biome_field: BiomeField = null) -> void:
	water = water_field
	world_seed = water_field.world_seed if water_field != null else 0
	biomes = biome_field if biome_field != null else BiomeField.new(world_seed)


## World units across one cell of a band's lattice. Both aerial storeys share
## one lattice, because the upper storey is placed on top of the lower one and
## so lives in the same cell.
static func cell_size(band: int) -> float:
	return FAR_CELL if band == FloatingIsland.FAR_SKY else AERIAL_CELL


## The furthest an island of a band can reach from its own centre.
static func band_reach(band: int) -> float:
	if band == FloatingIsland.FAR_SKY:
		return FAR_RADIUS_MAX * OUTLINE_REACH_MAX
	# An upper island sits off to one side of the lower one, so its reach has to
	# be measured from the lower island's cell position.
	var spread := (1.0 + UPPER_RADIUS_SHARE_MAX) * UPPER_OFFSET_SHARE_MAX \
		+ UPPER_RADIUS_SHARE_MAX
	return AERIAL_RADIUS_MAX * spread * OUTLINE_REACH_MAX


## Which cell of a band's lattice a world position falls in.
static func cell_at(band: int, x: float, z: float) -> Vector2i:
	var size := cell_size(band)
	return Vector2i(floori(x / size), floori(z / size))


## The island in one cell of one band, or null if that cell holds none.
##
## This is the whole of the sparse field: everything else here is a way of
## deciding which cells to ask it about. It is a pure function of (band, cell,
## seed) -- it reads the ground and the biomes, which are themselves pure
## functions of position and seed, and nothing else.
func island_in_cell(band: int, cell: Vector2i) -> FloatingIsland:
	var key := Vector3i(cell.x, cell.y, band)
	if _memo.has(key):
		return _memo[key]
	builds += 1
	var built := _build(band, cell)
	if _memo.size() >= MEMO_LIMIT:
		_memo.clear()
	_memo[key] = built
	return built


## Every island of a band that covers a world position. Usually none, sometimes
## one; two only where a pair of neighbouring islands happen to overlap.
func islands_over(band: int, x: float, z: float) -> Array[FloatingIsland]:
	var found: Array[FloatingIsland] = []
	for island in _cells_around(band, x, z, 0.0):
		if island.covers(x, z):
			found.append(island)
	return found


## Every walkable island over a position, lowest top surface first.
##
## Only the aerial storeys are considered: a far-sky island is scenery and is
## never something anyone is standing on, however directly overhead it is. Both
## storeys can cover the same position, which is exactly what makes the aerial
## layer a stack rather than a plane -- so this returns a list, and the caller
## says which of them it means.
func walkable_islands_over(x: float, z: float) -> Array[FloatingIsland]:
	var found: Array[FloatingIsland] = []
	for band in FloatingIsland.WALKABLE_BANDS:
		found.append_array(islands_over(band, x, z))
	found.sort_custom(func(a: FloatingIsland, b: FloatingIsland) -> bool:
		return a.top_height_at(x, z) < b.top_height_at(x, z))
	return found


## The first walkable island whose centre falls inside a fixed square around the
## world origin, in band order and then cell order, or null.
##
## A place to hold a fight in the air, chosen by the world rather than by a
## coordinate anyone typed, so a scenario or a report that wants "an island"
## keeps answering when the seed changes. It walks the bands and cells in a fixed
## order, so it is the same island in every process.
func first_walkable_island(span: float = 400.0) -> FloatingIsland:
	for band in FloatingIsland.WALKABLE_BANDS:
		var size := cell_size(band)
		var reach := int(ceil(span / size))
		for cell_x in range(-reach, reach + 1):
			for cell_z in range(-reach, reach + 1):
				var island := island_in_cell(band, Vector2i(cell_x, cell_z))
				if island == null or not island.walkable:
					continue
				if absf(island.centre_x) > span or absf(island.centre_z) > span:
					continue
				return island
	return null


## The walkable island whose top surface is highest over a position, or null.
func walkable_island_over(x: float, z: float) -> FloatingIsland:
	var over := walkable_islands_over(x, z)
	if over.is_empty():
		return null
	return over[over.size() - 1]


## Every island of a band whose outline comes within `distance` of a position,
## in a fixed order regardless of how the cells were walked. This is what the
## streamer builds its loaded set out of.
func islands_near(band: int, x: float, z: float, distance: float) -> Array[FloatingIsland]:
	var found: Array[FloatingIsland] = []
	for island in _cells_around(band, x, z, distance):
		if distance_to(island, x, z) <= distance:
			found.append(island)
	return found


## Whether any island of a band could possibly come within `distance` of a
## position, judged from the hashes alone.
##
## Nothing is built and no ground is read: this walks the same cells
## `islands_near` would and asks each one only for its *candidate* -- where its
## island would stand and how far its outline could reach, both of which fall
## out of the cell, the band and the seed. So the two answers are not the same
## answer. `false` is certain: no island of that band is within `distance`, and
## asking again with an island in hand cannot find one. `true` means only that
## the hashes cannot rule one out -- the ground may still refuse to hang it, a
## neighbour may stand it down, or its real outline may fall short of the bound
## its radius allows.
##
## It is worth having because the two questions cost wildly different amounts.
## Building one island samples the ground about a hundred and fifty times, and
## an upper storey has to build the lower one under it first; a candidate is a
## handful of hashes. A caller whose question is usually answered "nothing
## there" -- is anything hanging over this village site -- should put this in
## front of `islands_near` and pay the real price only where this cannot say no.
func could_reach(band: int, x: float, z: float, distance: float) -> bool:
	var size := cell_size(band)
	var reach := int(ceil((distance + band_reach(band)) / size)) + 1
	var centre := cell_at(band, x, z)
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var cell := Vector2i(centre.x + offset_x, centre.y + offset_z)
			if _cell_could_reach(band, cell, x, z, distance):
				return true
	return false


## The same bound for one cell: could the island this cell would hold, if the
## ground allows it one at all, come within `distance` of a position?
##
## `false` is certain and `true` means only that the hashes cannot rule it out,
## for exactly the reasons `could_reach` gives -- this is that question asked of
## one cell rather than of a scan, and `could_reach` is the disjunction of this
## over the cells it walks.
##
## Why it bounds what the cell would hold: the built island's centre *is* the
## candidate's centre and its `radius` *is* the candidate's radius, and
## `FloatingIsland.max_reach()` never exceeds radius * OUTLINE_REACH_MAX. So the
## island's `distance_to` is at least the gap this measures, and a cell this
## refuses could not have been within `distance` whatever the ground did with it.
func _cell_could_reach(
	band: int, cell: Vector2i, x: float, z: float, distance: float
) -> bool:
	var plan := _candidate(band, cell)
	if plan.is_empty():
		return false
	var away_x: float = x - float(plan["x"])
	var away_z: float = z - float(plan["z"])
	var apart := sqrt(away_x * away_x + away_z * away_z)
	return apart - float(plan["reach"]) <= distance


## How far a world position is from the nearest part of an island's outline,
## measured on the ground plane. Zero when the position is under or over it.
static func distance_to(island: FloatingIsland, x: float, z: float) -> float:
	var away := Vector2(x - island.centre_x, z - island.centre_z).length()
	return maxf(0.0, away - island.max_reach())


## Every island of a band in the cells that could reach a position, in cell
## order. Cell order rather than discovery order, so what comes back does not
## depend on where the scan started.
##
## The scan has to walk a wide square of cells, because an island stands
## anywhere in its own cell and reaches well past it -- but nearly every cell in
## that square holds nothing near the position, and building one to find that
## out costs about a hundred and fifty ground samples. So each cell is asked its
## candidate bound first (`_cell_could_reach`) and is built only where the
## hashes cannot rule it out. That is the same set of islands, not an
## approximation of it: the bound is refused only where the built island's own
## `distance_to` would have exceeded `distance` and every caller here discards
## it -- `islands_near` by distance, `islands_over` by `covers`, which is
## stricter still. Every consumer of the layer gets the saving: the streamer,
## the terrain query, the mesher and the settlement veto alike.
##
## A cell the memo already holds skips the bound instead, because the bound is
## only ever a way of not paying for a build and that build is already paid for.
## Hashing a candidate is cheap against a build and dear against a dictionary
## lookup: a walking observer asks about the same few cells every tick, and
## measured, asking the hashes there rather than the memo cost six times what the
## lookup does.
func _cells_around(band: int, x: float, z: float, distance: float) -> Array[FloatingIsland]:
	var size := cell_size(band)
	var reach := int(ceil((distance + band_reach(band)) / size)) + 1
	var centre := cell_at(band, x, z)
	var found: Array[FloatingIsland] = []
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var cell := Vector2i(centre.x + offset_x, centre.y + offset_z)
			var island: FloatingIsland = null
			if _memo.has(Vector3i(cell.x, cell.y, band)):
				island = _memo[Vector3i(cell.x, cell.y, band)]
			elif not gate_cells_by_candidate \
					or _cell_could_reach(band, cell, x, z, distance):
				island = island_in_cell(band, cell)
			if island != null:
				found.append(island)
	return found


## Hash one number out of a cell, in [0, 1). The salt is what keeps an island's
## radius independent of its height and of whether it exists at all, so retuning
## one of them does not shuffle the others.
func _roll(band: int, cell: Vector2i, salt: int) -> float:
	var band_seed: int = BAND_SEED_OFFSETS[band]
	return SimRng.hash_unit(world_seed + band_seed + salt * SALT_STRIDE, cell.x, cell.y)


func _roll_range(band: int, cell: Vector2i, salt: int, low: float, high: float) -> float:
	return low + (high - low) * _roll(band, cell, salt)


func _build(band: int, cell: Vector2i) -> FloatingIsland:
	var below: FloatingIsland = null
	if band == FloatingIsland.AERIAL_UPPER:
		# An upper storey exists only where there is a lower one to stand on.
		below = island_in_cell(FloatingIsland.AERIAL, cell)
		if below == null:
			return null

	var plan := _candidate(band, cell)
	if plan.is_empty():
		return null
	# Two islands of one band may not overlap, so one of any overlapping pair
	# stands down. Far-sky islands are exempt: their lattice is wide enough that
	# two of them cannot reach each other, so the rule would never fire.
	if band != FloatingIsland.FAR_SKY and _crowded(band, cell, plan):
		return null
	# An upper storey may lap over the lower island it stands on -- that overlap
	# is the staircase -- but not over anybody else's.
	if band == FloatingIsland.AERIAL_UPPER and _crowded_by_lower(cell, plan):
		return null

	var island := _blank(band, cell)
	island.centre_x = float(plan["x"])
	island.centre_z = float(plan["z"])
	island.radius = float(plan["radius"])
	_shape(island, cell)

	var placed := false
	if band == FloatingIsland.AERIAL:
		# The lower storey stands on the ground, so what is under it is the
		# carved bed -- the same ground anything walks on.
		placed = _place_over(island, cell, func(x: float, z: float) -> float:
			return water.bed_height_at(x, z))
	elif band == FloatingIsland.AERIAL_UPPER:
		placed = _place_upper(island, cell, below)
	else:
		placed = _place_far_sky(island, cell)
	if not placed:
		return null
	_dress(island)
	# The basin is cut last, because how deep it may go and whether it can spill
	# are both measured against `rim_height`, which the placement rule above is
	# what decides.
	if band != FloatingIsland.FAR_SKY:
		_carve_basin(island, cell)
	return island


## Where a cell's island would stand and how far it would reach, if the ground
## allowed one at all: its centre, its nominal radius, the bound on its outline,
## and how it ranks against its neighbours.
##
## Everything here is hashed out of the cell, the band and the seed and nothing
## else -- no ground is read and no island is built. That is what lets one cell
## decide whether it is crowded by another without building the other, which
## would mean building that one's neighbours, and so on outwards forever.
##
## The price is that a candidate can be crowded out by a neighbour the ground
## then refuses to place. The alternative is a rule whose answer depends on the
## order cells are asked in, which would break the one thing this layer promises.
##
## Candidates are memoised, for the same reason islands are and with more force:
## the cell scan asks every cell in range for one on every query, and a walking
## observer asks about the same cells every tick. They are hashes, so a forgotten
## one comes back identical; the memo changes no answer, only the price.
## The dictionary handed back is the field's own and is never written into by
## anything here, so callers must read it and not keep it.
func _candidate(band: int, cell: Vector2i) -> Dictionary:
	var key := Vector3i(cell.x, cell.y, band)
	if _candidate_memo.has(key):
		return _candidate_memo[key]
	var plan := _hash_candidate(band, cell)
	if _candidate_memo.size() >= CANDIDATE_MEMO_LIMIT:
		_candidate_memo.clear()
	_candidate_memo[key] = plan
	return plan


func _hash_candidate(band: int, cell: Vector2i) -> Dictionary:
	if band == FloatingIsland.AERIAL_UPPER:
		var under := _candidate(FloatingIsland.AERIAL, cell)
		if under.is_empty() or _roll(band, cell, 1) >= UPPER_CHANCE:
			return {}
		var below_radius := float(under["radius"])
		var radius := below_radius * _roll_range(
			band, cell, 4, UPPER_RADIUS_SHARE_MIN, UPPER_RADIUS_SHARE_MAX
		)
		var offset := (below_radius + radius) * _roll_range(
			band, cell, 2, UPPER_OFFSET_SHARE_MIN, UPPER_OFFSET_SHARE_MAX
		)
		var direction := _roll_range(band, cell, 3, 0.0, TAU)
		return {
			"x": float(under["x"]) + cos(direction) * offset,
			"z": float(under["z"]) + sin(direction) * offset,
			"radius": radius,
			"reach": radius * OUTLINE_REACH_MAX,
			"rank": _roll(band, cell, 12),
		}

	var chance := AERIAL_CHANCE if band == FloatingIsland.AERIAL else FAR_CHANCE
	if _roll(band, cell, 1) >= chance:
		return {}
	var size := cell_size(band)
	var radius_min := AERIAL_RADIUS_MIN if band == FloatingIsland.AERIAL else FAR_RADIUS_MIN
	var radius_max := AERIAL_RADIUS_MAX if band == FloatingIsland.AERIAL else FAR_RADIUS_MAX
	var radius := _roll_range(band, cell, 4, radius_min, radius_max)
	return {
		"x": (float(cell.x) + _roll_range(band, cell, 2, JITTER_LOW, JITTER_HIGH)) * size,
		"z": (float(cell.y) + _roll_range(band, cell, 3, JITTER_LOW, JITTER_HIGH)) * size,
		"radius": radius,
		"reach": radius * OUTLINE_REACH_MAX,
		"rank": _roll(band, cell, 12),
	}


## Whether a higher-ranked candidate of the same band would overlap this one.
##
## Islands of one band must not overlap, because two plates through each other
## leave a stretch of world where the question "what am I standing on" has two
## answers at once and neither is the surface anyone can see. Growing the radius
## is what made this possible: two lower-storey cells sit at least 38.7 units
## apart, and two full-sized islands now reach 32.4 each.
##
## The rule is symmetric and decided from hashes alone, so the pair agree about
## which of them stands down however either is asked for, and neither has to be
## built to settle it. The rank is a hashed number; equal ranks are broken by
## cell order, which never happens in practice and costs nothing to be sure of.
func _crowded(band: int, cell: Vector2i, here: Dictionary) -> bool:
	var reach: float = float(here["reach"])
	for offset_x in range(-CROWD_REACH, CROWD_REACH + 1):
		for offset_z in range(-CROWD_REACH, CROWD_REACH + 1):
			if offset_x == 0 and offset_z == 0:
				continue
			var other_cell := Vector2i(cell.x + offset_x, cell.y + offset_z)
			var other := _candidate(band, other_cell)
			if other.is_empty():
				continue
			if not _outranks(other, other_cell, here, cell):
				continue
			var away_x: float = float(other["x"]) - float(here["x"])
			var away_z: float = float(other["z"]) - float(here["z"])
			var apart := sqrt(away_x * away_x + away_z * away_z)
			if apart < reach + float(other["reach"]):
				return true
	return false


## Whether an upper storey would lap over a lower island other than its own.
##
## Its own is skipped, because overlapping that one is the whole point: the
## stretch of rim where the two plates lap is where you walk up from one to the
## other. Any other lower island is a plate at an unrelated height, and standing
## inside one is the same ambiguity two islands of one band would make.
##
## No rank is needed. A lower island is not negotiating: the upper storey exists
## only because a lower one does, so it is the one that stands down.
func _crowded_by_lower(cell: Vector2i, here: Dictionary) -> bool:
	var reach: float = float(here["reach"])
	for offset_x in range(-CROWD_REACH, CROWD_REACH + 1):
		for offset_z in range(-CROWD_REACH, CROWD_REACH + 1):
			if offset_x == 0 and offset_z == 0:
				continue
			var other := _candidate(
				FloatingIsland.AERIAL, Vector2i(cell.x + offset_x, cell.y + offset_z)
			)
			if other.is_empty():
				continue
			var away_x: float = float(other["x"]) - float(here["x"])
			var away_z: float = float(other["z"]) - float(here["z"])
			var apart := sqrt(away_x * away_x + away_z * away_z)
			if apart < reach + float(other["reach"]):
				return true
	return false


## Which of two candidates keeps its place: the higher-ranked one, and on a tie
## the one in the earlier cell.
func _outranks(
	first: Dictionary, first_cell: Vector2i,
	second: Dictionary, second_cell: Vector2i,
) -> bool:
	var gap: float = float(first["rank"]) - float(second["rank"])
	if absf(gap) > 0.0:
		return gap > 0.0
	if first_cell.x != second_cell.x:
		return first_cell.x < second_cell.x
	return first_cell.y < second_cell.y


## Place the upper storey over the lower island in its own cell.
##
## Everything about it is measured from what is beneath it rather than from the
## ground: it is narrower, it is shifted off to one side so each plate has open
## sky over part of the other, and its rim goes one hop above the highest surface
## under its footprint -- which, because it overlaps the lower island, is the
## lower island. So the way onto it is to walk up from the plate below.
##
## Only the lower island in its own cell is consulted, and that is sound rather
## than convenient: `_crowded_by_lower` has already refused any upper storey that
## would lap over a different lower island, so the only plate its footprint can
## meet is this one. Deciding that from hashes rather than by looking is what
## keeps the cost down -- looking would mean building every lower island round
## about before this one could be placed, which measured twenty times slower on a
## cold field.
func _place_upper(
	island: FloatingIsland, cell: Vector2i, below: FloatingIsland
) -> bool:
	# What is under the upper storey: the lower island where it covers, and the
	# ground where it does not. Written as one function of position so that the
	# placement rule is literally the same rule the lower storey followed.
	var under := func(x: float, z: float) -> float:
		if below.covers(x, z):
			return below.top_height_at(x, z)
		return water.bed_height_at(x, z)
	return _place_over(island, cell, under)


## An island with its band and cell set and nothing else decided yet.
func _blank(band: int, cell: Vector2i) -> FloatingIsland:
	var island := FloatingIsland.new()
	island.band = band
	island.cell = cell
	return island


## Give an island the whole of its shape: the blobs its plan outline is the union
## of, the crenellation on that outline, the two noise octaves its top surface is
## made of, and the way its keel varies with direction.
##
## All of it is hashed from the island's identity, and all of it has to be
## installed before anything asks the island a question about its shape -- the
## footprint scan below is written in terms of outline_radius(), and the placement
## rule in terms of the keel profile.
func _shape(island: FloatingIsland, cell: Vector2i) -> void:
	var band := island.band
	var radius := island.radius

	# The plan outline: a centred core blob plus one to three offset ones, spread
	# evenly round the island and then jittered off that spacing.
	var blob_count := clampi(
		int(_roll_range(band, cell, 13, float(BLOB_COUNT_MIN), float(BLOB_COUNT_MAX + 1))),
		BLOB_COUNT_MIN, BLOB_COUNT_MAX,
	)
	var blob_x := PackedFloat32Array([0.0])
	var blob_z := PackedFloat32Array([0.0])
	var blob_radius := PackedFloat32Array([radius * BLOB_CORE_SHARE])
	var spread := TAU / float(maxi(1, blob_count - 1))
	var first := _roll_range(band, cell, 19, 0.0, TAU)
	for at in range(1, blob_count):
		var away := radius * _roll_range(band, cell, 20 + at, BLOB_OFFSET_MIN, BLOB_OFFSET_MAX)
		var direction := first + spread * float(at - 1) + _roll_range(
			band, cell, 30 + at, -BLOB_SPREAD_JITTER, BLOB_SPREAD_JITTER
		)
		blob_x.append(cos(direction) * away)
		blob_z.append(sin(direction) * away)
		blob_radius.append(
			radius * _roll_range(band, cell, 40 + at, BLOB_RADIUS_MIN, BLOB_RADIUS_MAX)
		)

	var edge_amplitudes := PackedFloat32Array()
	var edge_phases := PackedFloat32Array()
	var edge_share := OUTLINE_WOBBLE / 2.0
	for at in 2:
		edge_amplitudes.append(_roll_range(band, cell, 50 + at, -edge_share, edge_share))
		edge_phases.append(_roll_range(band, cell, 55 + at, 0.0, TAU))
	island.shape_outline(blob_x, blob_z, blob_radius, edge_amplitudes, edge_phases)

	# How high the top stands over the rim, as a share of the radius in both
	# bands -- a far-sky island is only ever a silhouette, so a flat one is a
	# saucer whatever its size.
	var relief_min := FAR_RELIEF_SHARE_MIN if band == FloatingIsland.FAR_SKY \
		else AERIAL_RELIEF_SHARE_MIN
	var relief_max := FAR_RELIEF_SHARE_MAX if band == FloatingIsland.FAR_SKY \
		else AERIAL_RELIEF_SHARE_MAX
	island.relief = radius * _roll_range(band, cell, 5, relief_min, relief_max)

	# How the keel hangs: a base share every direction gets, two lobes that take
	# it up to all of the depth on one side and under half on another, and a
	# taper that swings with the direction so one spur is a spike and the next a
	# shoulder.
	var spur_amplitudes := PackedFloat32Array()
	var spur_phases := PackedFloat32Array()
	var spur_share := (1.0 - SPUR_BASE) / 2.0
	for at in 2:
		spur_amplitudes.append(_roll_range(band, cell, 61 + at, -spur_share, spur_share))
		spur_phases.append(_roll_range(band, cell, 65 + at, 0.0, TAU))

	var band_offset: int = BAND_SEED_OFFSETS[band]
	var identity := world_seed + band_offset + SimRng.hash_ints(cell.x, cell.y, band)
	island.shape_body(
		ValueNoise.new(identity, 3, maxf(4.0, radius * 0.66), 1.0),
		ValueNoise.new(identity + SALT_STRIDE, 2, maxf(1.5, radius * 0.13), 1.0),
		SPUR_BASE,
		spur_amplitudes,
		spur_phases,
		_roll_range(band, cell, 70, SPUR_TAPER_BASE_MIN, SPUR_TAPER_BASE_MAX),
		_roll_range(band, cell, 71, SPUR_TAPER_SWING_MIN, SPUR_TAPER_SWING_MAX),
		_roll_range(band, cell, 72, 0.0, TAU),
	)


## The colours an island is dressed in: the biome under its centre, so an island
## over deep forest is a dark green plate and one over a marsh is a teal one.
func _dress(island: FloatingIsland) -> void:
	island.biome = biomes.biome_at(island.centre_x, island.centre_z)
	island.ground_tint = biomes.ground_tint_at(island.centre_x, island.centre_z)
	island.rock_tint = biomes.rock_tint_at(island.centre_x, island.centre_z)
	island.water_tint = biomes.water_tint_at(island.centre_x, island.centre_z)


## Cut the basin in the island's middle, fill it, and decide whether it runs
## over the rim -- or leave the island without one.
##
## Everything here is measured against the island the placement rule has already
## finished, and nothing here can change any of it: the rim, the keel and the
## step up onto the island are all decided before this runs and are not touched.
## What this adds is a hollow in the middle and some water in it.
##
## The order of the three decisions is the order they constrain each other in.
## How far the floor dips below the rim is free, so it is hashed. How high the
## water stands is not: it has to clear the floor by enough to be a pond, stop
## short of the lowest point of the bowl's lip by enough to stay in the bowl, and
## stop short of BASIN_MAX_DEPTH above its own floor so that the pond is one
## storey. If those cannot all hold there is no basin. Whether it spills
## is not free either: the channel's floor has to stay above the rim, or the cut
## would reach the boundary and the rim would stop being the lowest point along
## it -- which is the guarantee the whole aerial layer's reachability rests on.
func _carve_basin(island: FloatingIsland, cell: Vector2i) -> void:
	if _roll(island.band, cell, 80) >= BASIN_CHANCE:
		return
	var reach := _roll_range(island.band, cell, 81, BASIN_REACH_MIN, BASIN_REACH_MAX)
	var dip := _roll_range(island.band, cell, 82, BASIN_DIP_MIN, BASIN_DIP_MAX)

	var middle := island.base_top_height_at(island.centre_x, island.centre_z)
	var floor_height := island.rim_height - dip
	var depth := middle - floor_height

	# The lowest point of the ring where the bowl meets the hillside. The water
	# has to stop below it, or the pond would be leaning on ground that falls
	# away from it in every direction.
	var lip := INF
	for step in BASIN_LIP_DIRECTIONS:
		var angle := TAU * float(step) / float(BASIN_LIP_DIRECTIONS)
		var away := island.outline_radius(angle) * reach
		lip = minf(lip, island.base_top_height_at(
			island.centre_x + cos(angle) * away,
			island.centre_z + sin(angle) * away,
		))

	var level := minf(
		minf(
			floor_height + (lip - floor_height) * BASIN_FILL_SHARE,
			lip - BASIN_FREEBOARD,
		),
		floor_height + BASIN_MAX_DEPTH,
	)
	if level - floor_height < BASIN_MIN_DEPTH:
		return
	island.shape_basin(reach, depth, level, middle)

	# The outlet, if the water stands high enough above the rim for a channel to
	# be cut without reaching the boundary.
	var channel := level - FloatingIsland.SPILL_DEPTH
	if channel < island.rim_height + SPILL_MARGIN:
		return
	var angle_of := _roll_range(island.band, cell, 83, 0.0, TAU)
	var half := _roll_range(
		island.band, cell, 84, SPILL_HALF_ANGLE_MIN, SPILL_HALF_ANGLE_MAX
	)
	var edge := island.outline_radius(angle_of)
	var fall := island.rim_thickness + island.keel_depth * _roll_range(
		island.band, cell, 85, SPILL_FALL_MIN, SPILL_FALL_MAX
	)
	island.shape_spill(
		angle_of, half, channel,
		island.centre_x + cos(angle_of) * edge,
		island.centre_z + sin(angle_of) * edge,
		2.0 * edge * sin(half),
		fall,
	)


## Decide a walkable island's height over whatever is beneath it, or refuse to
## place it.
##
## The rim goes one hop above the highest surface the island overhangs, which is
## what makes it reachable from there. The keel then goes as deep as that surface
## allows and no deeper, which is what keeps daylight under the island. If that
## leaves no room for a keel worth the name -- because what is below is flat, or
## rises into the island -- there is no island here at all.
##
## `under` is the surface being stood over: the ground for the lower storey, and
## the lower storey itself for the upper one. Passing it in rather than reading
## the ground directly is what lets one rule build a staircase.
func _place_over(island: FloatingIsland, cell: Vector2i, under: Callable) -> bool:
	island.rim_thickness = AERIAL_RIM_THICKNESS
	var lift := _roll_range(island.band, cell, 6, AERIAL_LIFT_MIN, AERIAL_LIFT_MAX)

	var footprint := _footprint(island, under)
	# Measured from the highest point of what is under the *rim*: that is where
	# the step up onto the island happens, so that is what the step is measured
	# against.
	island.rim_height = float(footprint["rim_highest"]) + lift
	island.landing_step = lift

	# How deep the keel may go before it would touch what is below. Each sample
	# bounds it, because the keel's profile at that sample is a known share of
	# its full depth.
	var allowed := INF
	for entry in footprint["undersides"]:
		var profile: float = entry["profile"]
		if profile <= 0.0001:
			continue
		var room: float = island.rim_height - island.rim_thickness - CLEARANCE - float(entry["ground"])
		allowed = minf(allowed, room / profile)
	var keel := minf(island.radius * AERIAL_KEEL_SHARE, allowed)
	if keel < AERIAL_KEEL_MIN:
		return false
	island.keel_depth = keel
	island.walkable = true
	return true


## Decide a far-sky island's height. Nothing to refuse: they hang far above
## every hill there is, so no ground can be in the way of one.
func _place_far_sky(island: FloatingIsland, cell: Vector2i) -> bool:
	island.rim_height = _roll_range(
		FloatingIsland.FAR_SKY, cell, 6, FAR_ALTITUDE_MIN, FAR_ALTITUDE_MAX
	)
	island.rim_thickness = island.radius * FAR_RIM_SHARE
	island.keel_depth = island.radius * FAR_KEEL_SHARE
	island.landing_step = 0.0
	island.walkable = false
	island.drift_radius = _roll_range(
		FloatingIsland.FAR_SKY, cell, 7, FAR_DRIFT_RADIUS_MIN, FAR_DRIFT_RADIUS_MAX
	)
	island.drift_rate = _roll_range(
		FloatingIsland.FAR_SKY, cell, 8, FAR_DRIFT_RATE_MIN, FAR_DRIFT_RATE_MAX
	)
	island.drift_phase = _roll_range(FloatingIsland.FAR_SKY, cell, 9, 0.0, TAU)
	return true


## What is under an island, sampled on rings out to its rim.
##
## Two things come back. `rim_highest` is the highest surface found under the
## rim, which is what the island's height is measured from, because the rim is
## the only part of an island anyone can arrive at. `undersides` is every sample
## with how much of the keel's depth hangs over it, which is what bounds the
## keel -- and that one covers the whole footprint, because the keel has to clear
## all of it, the middle included.
##
## The samples follow the island's own wobbly outline rather than a circle, so
## the ring at the rim really is the rim.
func _footprint(island: FloatingIsland, under: Callable) -> Dictionary:
	var rim_highest := -INF
	var undersides: Array = []
	for ring in FOOTPRINT_RINGS + 1:
		var ratio := float(ring) / float(FOOTPRINT_RINGS)
		var at_rim := ring == FOOTPRINT_RINGS
		# How much of the keel's full depth could hang below the rim at this
		# ratio, in the worst direction. A bound rather than the profile in the
		# direction the sample was taken in, because a sample of the ground is a
		# statement about the ground and not about a direction -- and at the
		# island's middle every direction meets, so no one direction covers it.
		var profile := island.keel_profile_bound(ratio)
		var directions := 1 if ring == 0 else FOOTPRINT_DIRECTIONS
		if at_rim:
			directions = RIM_DIRECTIONS
		for direction in directions:
			var angle := TAU * float(direction) / float(directions)
			var reach := island.outline_radius(angle) * ratio
			var x := island.centre_x + cos(angle) * reach
			var z := island.centre_z + sin(angle) * reach
			var ground: float = under.call(x, z)
			if at_rim:
				rim_highest = maxf(rim_highest, ground)
			undersides.append({"profile": profile, "ground": ground})
	return {"rim_highest": rim_highest, "undersides": undersides}
