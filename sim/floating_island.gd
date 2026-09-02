extends RefCounted
## One floating island: where it is, what shape it is, and what it looks like.
##
## An island is a chunk of land hanging in the air, and this is the whole of it
## as plain numbers -- a centre, a torn outline, a rim height, its own little
## heightfield for the relief on top, and how far its underside hangs below. It
## holds no geometry and draws nothing; the mesher turns one into triangles and
## the terrain query answers questions about one.
##
## Every method here is a pure function of the island's own numbers and the
## position asked about. The island itself was hashed out of its lattice cell and
## the world seed, so two of these built in different processes for the same cell
## are the same island, and everything below therefore agrees across processes
## too.
##
## The shape is radial rather than a field sampled on a grid, because an island
## is a *thing* with a middle and an edge, unlike the ground, which is a field
## with neither. That is what makes a clean cliff possible: the rim is a curve
## the island knows about, not a contour someone has to go looking for.
##
## ## Why none of the three surfaces is a surface of revolution
##
## An earlier version of this file made all three out of one radius: a circle
## with three bounded sine lobes for the outline, a smooth dome for the top, a
## smooth cone for the keel. A convex dome over a smooth cone on a near-circular
## rim is a flying saucer by construction, which is what it looked like. Each of
## the three is now built to break that:
##
## * the **outline** is the union of two to four overlapping blobs at different
##   offsets, so the boundary has inlets where two blob arcs cross and
##   peninsulas where one sticks out;
## * the **top** is a stepped rim of several shelves under an inner dome,
##   carrying two octaves of noise rather than one and standing most of its
##   relief above the rim rather than half of it, so it has relief a walker --
##   and, which is harder, the playing camera -- notices rather than a
##   barely-curved lid;
## * the **keel** hangs by an amount that depends on the direction, and tapers
##   at a rate that depends on the direction too, so the underside is a cluster
##   of spurs of different depth and sharpness rather than one point.
##
## All three stay cheap -- a handful of sines, one square root per blob, and no
## allocation -- because IslandField samples them about a hundred and fifty
## times to place a single island and TerrainQuery calls them per position.
class_name FloatingIsland

## The bands islands come in. Which band an island is in decides everything about
## how it is treated: the two aerial bands are walkable ground you can stand on,
## and a far-sky island is scenery on the horizon that is never part of the
## world's surface.
##
## The aerial layer is two storeys rather than one because a single storey cannot
## be both airborne and reachable. The lower storey is placed a hop above the
## ground it overhangs, so you can walk onto it; the upper storey is placed a hop
## above *the lower storey*, so you can walk onto that too -- and by then you are
## ten or more units above the land, with daylight under both plates. The climb
## is the reason the band can be as high as it is.
const AERIAL := 0
const FAR_SKY := 1
const AERIAL_UPPER := 2

## The two walkable bands, in the order they are built: the upper storey is
## placed on top of the lower one, so the lower one has to exist first.
const WALKABLE_BANDS := [AERIAL, AERIAL_UPPER]

## How sharply the keel narrows as it goes down. The underside hangs
## `keel_depth * keel_profile_at(x, z)` below the rim's lip, and the profile is
## `(1 - ratio)` raised to a power drawn from this range -- per island *and* per
## direction, so one side of the keel is a broad shoulder and another is a
## spike.
##
## The floor of the range is the one that matters to anything but the eye: it is
## the slowest the keel can possibly narrow, so `(1 - ratio) ** KEEL_TAPER_MIN`
## bounds the profile in every direction at once, which is what lets the
## placement rule work out how deep a keel will fit without asking about every
## direction separately. Both ends stay above 1 so the profile is zero *at* the
## outline: the underside meets the rim's lip exactly there, and the rim samples
## therefore never constrain the keel, which is what keeps the landing -- where
## the island comes closest to what is under it -- from refusing every island.
const KEEL_TAPER_MIN := 1.7
const KEEL_TAPER_MAX := 3.1

## How the rim is stepped, as shares of the way in from the outline and of the
## island's relief.
##
## The outer SHELF_BAND of the way in is a staircase of SHELF_COUNT shelves
## rising to SHELF_TOP of the full relief; inside that the surface domes the rest
## of the way up. Each shelf is a flat tread with a short riser at its *inner*
## edge, and SHELF_RISER is how much of the shelf's width the riser takes.
##
## Inner rather than outer, which it used to be, and the reason is the landing.
## The outermost tread is now a flat lip at exactly rim height, about a tenth of
## the way in -- a couple of world units on a typical island. That lip is where
## somebody arriving from the ground actually puts their feet, and on the combat
## lattice, whose cells are three units across, it is the difference between an
## island having a cell you can step onto and having none: with the riser on the
## outer edge the surface starts climbing at the boundary itself, so a cell
## centre a stride inside the rim was already out of hop range of the ground
## below, and whether an island could be entered at all came down to where the
## lattice happened to fall.
##
## The staircase is why the edge of an island reads as a broken-off piece rather
## than as a lip: from the side you see several distinct terraces stacked back
## from the cliff. Every riser is well under TerrainQuery.HOP_HEIGHT for any
## island this layer builds, so the terraces are walked up rather than climbed --
## and the count is what holds that: a riser is SHELF_TOP/SHELF_COUNT of the
## island's relief, so the count had to rise with the relief.
const SHELF_COUNT := 3
const SHELF_BAND := 0.42
const SHELF_TOP := 0.48
const SHELF_RISER := 0.34

## How much of the top's relief comes from the finer of its two noise octaves.
## The coarse octave is the island's hills; this one is the lumps on them.
const DETAIL_SHARE := 0.30

## The least of its own relief the top surface takes anywhere inside the shelved
## band, as a share.
##
## The relief profile is multiplied by a noise sample in [0, 1], and a noise
## sample in [0, 1] has a mean of a half -- so an island whose relief was set to
## a third of its radius stood, in fact, a *sixth* of its radius above its rim,
## and its summit only reached the full figure where the noise happened to peak.
## Measured from the camera the game is played from, that was the whole of why
## the top read as a lid: the summit stood eleven to twenty-three pixels above
## the rim of an island a hundred to a hundred and seventy pixels wide.
##
## Remapping the sample into [RELIEF_FLOOR, 1] fixes both halves of that at once.
## The summit reaches most of the relief rather than half of it, and the swing
## between neighbouring samples *shrinks* by the same factor the floor leaves --
## so the top gets taller without getting locally steeper, which is what keeps
## every step of it inside TerrainQuery.HOP_HEIGHT.
const RELIEF_FLOOR := 0.42

## How deep the water in the spillway is, in world units: the depth of the
## channel that carries the pond's overflow from the basin to the rim.
##
## This is the one number the pond's shape is written in that is not hashed per
## island, because it is what makes the channel read as a channel. The floor of
## the wedge is cut to exactly this far below the pond's surface, so the stream
## running out of the basin is ankle-deep the whole way rather than a slot of
## water at the level of the lake behind it.
const SPILL_DEPTH := 0.22

## Which band this island belongs to.
var band: int = AERIAL

## The lattice cell it was hashed out of. With the band, this is its identity --
## the streamer keys on it, and it is stable across processes.
var cell := Vector2i.ZERO

## Where it hangs, on the ground plane.
var centre_x: float = 0.0
var centre_z: float = 0.0

## The nominal radius of the island, in world units: the scale everything about
## its plan is measured in. The outline itself is a union of blobs sized and
## offset in shares of this, so it reaches further than this in some directions
## and less far in others; `max_reach()` is the honest upper bound.
var radius: float = 10.0

## The height of its rim: the level its top surface meets its cliff at. The top
## rises above this towards the middle by up to `relief`; nothing on the island
## is ever below it.
var rim_height: float = 0.0

## How far the middle of the island stands above the rim, in world units. This
## is the amplitude of the island's own small heightfield, and it is a large
## share of the radius rather than a small one -- an island is a chunk of hill,
## not a plate.
var relief: float = 1.5

## How thick the plate is at its rim -- the height of the cliff you would stand
## at the top of.
var rim_thickness: float = 0.6

## How far below the rim's underside the island's deepest spur hangs. Other
## directions hang less far; `keel_profile_at` is what says how much less.
var keel_depth: float = 4.0

## Which biome the island took its look from: whichever the ground below its
## centre belongs to, so an island over deep forest is a dark green plate and one
## over a marsh is a teal one.
var biome: String = ""

## The colours it is dressed in, both taken from that biome: the top surface and
## the cliff and keel.
var ground_tint := Color(0.5, 0.6, 0.4)
var rock_tint := Color(0.5, 0.5, 0.5)

## How far the top of the island stands above the highest ground under its
## footprint. For an aerial island this is the step up onto it, and it is the
## number the traversal decision is written in terms of; for a far-sky island it
## is meaningless and is left at zero.
var landing_step: float = 0.0

## How the island moves, for a viewer that wants to animate it: how far it
## wanders, how fast, and where in its cycle it starts.
##
## This is placement data, not state -- nothing here changes, and the simulation
## never applies it. Far-sky islands carry a drift because they are scenery on
## the horizon and a still sky reads as a painted backdrop; aerial islands carry
## none, because they are ground somebody stands on and moving ground is a later
## idea, deliberately out of scope.
var drift_radius: float = 0.0
var drift_rate: float = 0.0
var drift_phase: float = 0.0

## The basin in the island's middle, and the pond standing in it.
##
## `basin_ratio` is how far out the bowl reaches as a share of the outline -- so
## the basin is a smaller copy of the island's own plan rather than a circle
## stamped on it -- and zero means this island has no basin at all. Everything
## else is only meaningful when it is positive.
##
## The bowl is cut *downwards* out of the top surface, and it is cut deep enough
## that its floor is below `rim_height`: an island whose middle dips under its
## own rim is the whole point, because that is what lets it hold water without
## the water running off the edge. Nothing about the rim changes, so the step up
## onto the island and the room under its keel mean exactly what they meant
## before -- see the note on `top_height_at`.
var basin_ratio: float = 0.0
var basin_depth: float = 0.0
var water_level: float = 0.0

## The level the island's top surface stood at, at its very middle, before the
## bowl was cut out of it. The bowl is a blend between the hillside at its lip
## and a *flat floor* `basin_depth` below this, so this is what "flat" means.
##
## It is stored rather than sampled because the blend is in the hot path and
## reading the heightfield at the island's middle to find it again would be a
## second pair of noise lookups on every query.
var basin_top: float = 0.0

## Where the pond overflows, if it does: a wedge of directions, measured from
## the island's middle, whose floor is cut to `spill_floor` so the water runs
## out along it and over the rim. `spill_half_angle` of zero means this pond has
## no outlet and simply sits in its bowl.
##
## The wedge is stated in *directions* rather than as a channel of some width in
## world units, and that is deliberate: the island is meshed as a fan of
## directions, so a wedge lands exactly on mesh edges and the channel the walker
## falls into is the channel the viewer sees.
var spill_half_angle: float = 0.0
var spill_angle: float = 0.0
var spill_floor: float = 0.0

## Where the waterfall is and how far it falls, in world units. This is
## placement data in exactly the sense the far-sky drift is: the simulation says
## where the water leaves the island and how big the fall is, and a viewer
## animates it. Nothing about the world depends on the animation.
var spill_x: float = 0.0
var spill_z: float = 0.0
var spill_width: float = 0.0
var spill_fall: float = 0.0

## Which colour the pond takes: the water colour of the biome under the island's
## centre, so a pond on a marsh island is the same near-black teal the marsh's
## own water is.
var water_tint := Color(0.30, 0.55, 0.70)

## Whether this is ground: whether the terrain query counts its top surface as a
## surface anyone can stand on. Aerial islands are; far-sky ones never are.
var walkable: bool = true

# The blobs whose union is the plan outline, in world units relative to the
# island's centre. Blob 0 is always centred, which is what guarantees the
# island's own middle is inside its outline and so that `outline_radius` is
# positive in every direction.
var _blob_x := PackedFloat32Array()
var _blob_z := PackedFloat32Array()
var _blob_radius := PackedFloat32Array()
# |offset|^2 - r^2 for each blob, kept because the outline solves a ray against
# every blob and this is the only part of it that does not change with the
# direction asked about.
var _blob_offset := PackedFloat32Array()

# The fine crenellation riding on the union of blobs: two short lobes, so the
# blob arcs do not read as arcs.
var _edge_amplitudes := PackedFloat32Array([0.0, 0.0])
var _edge_phases := PackedFloat32Array([0.0, 0.0])
# The total of the two amplitudes, which is what turns a blob's reach into a
# bound on the whole outline.
var _edge_span: float = 0.0

# How the keel's depth and sharpness vary with direction: two lobes each. The
# peak is the deepest the keel can hang in any direction at all, which the
# placement rule needs because every direction meets at the island's middle.
var _spur_amplitudes := PackedFloat32Array([0.0, 0.0])
var _spur_phases := PackedFloat32Array([0.0, 0.0])
var _spur_base: float = 1.0
var _spur_peak: float = 1.0
var _taper_amplitude: float = 0.0
var _taper_phase: float = 0.0
var _taper_base: float = 2.4

# The island's own heightfield, in two octaves: broad hills, and lumps on them.
var _relief_noise: ValueNoise = null
var _detail_noise: ValueNoise = null

## The frequencies the outline's crenellation and the keel's spurs run at, in
## cycles round the island. The edge pair are high enough to read as a torn edge
## rather than as a wobble; the keel pair are low, because a keel with a dozen
## spurs is gravel rather than a broken-off root.
##
## The edge pair are also as high as the mesh can carry. IslandMesher draws an
## aerial island as a fan of forty directions, so nine cycles round the island is
## sampled four and a half times a cycle and five cycles eight times. Raising them
## further -- thirteen and seven were tried -- puts the faster of the two under
## the rate at which a wave can be sampled at all, and the crenellation then
## exists in every answer the island gives about itself and in none of the
## geometry anybody sees.
const EDGE_FREQUENCIES := [5.0, 9.0]
const SPUR_FREQUENCIES := [2.0, 3.0]


## The island's identity: its cell and its band, in one value the streamer and
## the reports can key on.
func key() -> Vector3i:
	return Vector3i(cell.x, cell.y, band)


## Install the island's plan outline: the blobs whose union it is, and the fine
## crenellation on top of them. Offsets and radii are in world units, relative
## to the island's centre; blob 0 must be the centred one.
##
## All of it is hashed from the island's identity by IslandField, so this only
## stores it and precomputes the two quantities the outline is solved with.
func shape_outline(
	blob_x: PackedFloat32Array,
	blob_z: PackedFloat32Array,
	blob_radius: PackedFloat32Array,
	edge_amplitudes: PackedFloat32Array,
	edge_phases: PackedFloat32Array,
) -> void:
	_blob_x = blob_x
	_blob_z = blob_z
	_blob_radius = blob_radius
	_blob_offset = PackedFloat32Array()
	for at in _blob_radius.size():
		var away := _blob_x[at] * _blob_x[at] + _blob_z[at] * _blob_z[at]
		_blob_offset.append(away - _blob_radius[at] * _blob_radius[at])
	_edge_amplitudes = edge_amplitudes
	_edge_phases = edge_phases
	_edge_span = 0.0
	for at in _edge_amplitudes.size():
		_edge_span += absf(_edge_amplitudes[at])


## Install the island's two relief octaves and the way its keel varies with
## direction. `spur_base` plus the spur amplitudes is the share of the full keel
## depth that hangs in a given direction, and the taper pair say how sharply it
## narrows there.
func shape_body(
	relief_noise: ValueNoise,
	detail_noise: ValueNoise,
	spur_base: float,
	spur_amplitudes: PackedFloat32Array,
	spur_phases: PackedFloat32Array,
	taper_base: float,
	taper_amplitude: float,
	taper_phase: float,
) -> void:
	_relief_noise = relief_noise
	_detail_noise = detail_noise
	_spur_base = spur_base
	_spur_amplitudes = spur_amplitudes
	_spur_phases = spur_phases
	_spur_peak = spur_base
	for at in _spur_amplitudes.size():
		_spur_peak += absf(_spur_amplitudes[at])
	_spur_peak = clampf(_spur_peak, 0.0, 1.0)
	_taper_base = taper_base
	_taper_amplitude = taper_amplitude
	_taper_phase = taper_phase


## How far the outline reaches in one direction, in world units.
##
## The union of the blobs, read along a ray from the island's middle: for each
## blob, how far along the ray its far side is, and the furthest of those wins.
## Because blob 0 is centred, the ray always leaves at least one blob, so this is
## always positive and every direction has exactly one answer -- which is what
## lets `ratio_at` below be a well-defined "how far out are you", with no
## direction in which the boundary doubles back.
##
## Where two blob arcs cross, the winner changes and the outline turns a corner
## into the island: that is an inlet. Where one blob reaches past the others,
## the outline runs out and back: that is a peninsula.
func outline_radius(angle: float) -> float:
	var toward_x := cos(angle)
	var toward_z := sin(angle)
	var reach := 0.0
	for at in _blob_radius.size():
		# Where the ray meets this blob's circle: t^2 - 2*b*t + offset = 0.
		var half := toward_x * _blob_x[at] + toward_z * _blob_z[at]
		var inside := half * half - _blob_offset[at]
		if inside <= 0.0:
			continue
		var far_side := half + sqrt(inside)
		if far_side > reach:
			reach = far_side
	var crenellation := 0.0
	for at in _edge_amplitudes.size():
		crenellation += _edge_amplitudes[at] * sin(
			float(EDGE_FREQUENCIES[at]) * angle + _edge_phases[at]
		)
	return reach * (1.0 + crenellation)


## The furthest the outline can possibly reach. What the field scans with and
## the streamer measures distance against, so neither has to evaluate the
## outline in every direction.
##
## A blob's furthest point from the island's middle is its own centre's distance
## plus its own radius, and the crenellation can add its whole span on top.
func max_reach() -> float:
	var reach := 0.0
	for at in _blob_radius.size():
		var away := sqrt(_blob_x[at] * _blob_x[at] + _blob_z[at] * _blob_z[at])
		reach = maxf(reach, away + _blob_radius[at])
	return reach * (1.0 + _edge_span)


## How far out a position is, as a fraction of the outline: 0 at the middle, 1
## exactly on the edge, more than 1 outside the island altogether.
func ratio_at(x: float, z: float) -> float:
	var dx := x - centre_x
	var dz := z - centre_z
	var distance := sqrt(dx * dx + dz * dz)
	if distance <= 0.0:
		return 0.0
	return distance / maxf(0.0001, outline_radius(atan2(dz, dx)))


## Whether this position is over the island at all.
func covers(x: float, z: float) -> bool:
	return ratio_at(x, z) <= 1.0


## How far the top surface stands above the rim here, as a share of `relief`:
## zero at the outline, one at the middle of a fully-risen island.
##
## The outer part is the staircase -- flat treads with short risers between them
## -- and the inner part domes the rest of the way. It is flat at the rim and
## never negative, which is what makes `rim_height` the floor of the whole top
## surface.
func terrace_at(ratio: float) -> float:
	if ratio >= 1.0:
		return 0.0
	var inward := 1.0 - ratio
	if inward >= SHELF_BAND:
		var climbed := (inward - SHELF_BAND) / (1.0 - SHELF_BAND)
		return SHELF_TOP + (1.0 - SHELF_TOP) * (2.0 - climbed) * climbed
	var along := inward / SHELF_BAND * float(SHELF_COUNT)
	var tread := floorf(along)
	var into := along - tread
	var riser := clampf((into - (1.0 - SHELF_RISER)) / SHELF_RISER, 0.0, 1.0)
	return (tread + riser) / float(SHELF_COUNT) * SHELF_TOP


## The height of the island's top surface here *before* any basin is cut out of
## it: the hill the island would be if it held no water.
##
## The rim is the floor of this one. The island's own heightfield only ever
## adds, and the terrace profile fades it to nothing at the edge, so this is at
## or above `rim_height` everywhere and exactly `rim_height` on the outline.
##
## Two octaves of noise, not one: a broad one about two-thirds of the island
## across, and a finer one a sixth of it across. The coarse octave alone gave a
## surface with a single hump in it, which at this relief would be a dome. Their
## weighted sum is then lifted off the floor by `RELIEF_FLOOR`, so the relief the
## island was given is most of the relief it actually stands in.
func base_top_height_at(x: float, z: float) -> float:
	var ratio := clampf(ratio_at(x, z), 0.0, 1.0)
	return _base_top_at(x, z, ratio)


## The height of the island's top surface here -- the ground you stand on when
## you are on it -- with the basin and its spillway cut into it.
##
## ## What the basin does and does not change
##
## The bowl in the middle may take the surface *below* `rim_height`, which is the
## one thing the old surface promised never to happen. It is allowed here
## because of what the rim height is actually load-bearing for, which is two
## things and neither of them is the middle:
##
## * `landing_step` is the gap between the rim and the highest ground under the
##   rim, and it is what makes the island reachable in one hop. It is measured
##   at the rim.
## * the clearance rule keeps the keel off what is below, and the keel hangs
##   from `rim_height - rim_thickness`. It is measured from the rim.
##
## So the guarantee that has to survive is that **the rim is still the lowest
## the top surface gets anywhere on the boundary**, and it is: the bowl is a
## share of the way out to the outline and stops well short of it, and the
## spillway's floor is cut to a level that is above `rim_height` by
## construction -- so on the boundary itself this returns `rim_height` in every
## direction, basin or no basin.
func top_height_at(x: float, z: float) -> float:
	var ratio := clampf(ratio_at(x, z), 0.0, 1.0)
	var height := _base_top_at(x, z, ratio)
	if basin_ratio <= 0.0:
		return height
	# The bowl, as a blend from the hillside at its lip to a flat floor at its
	# middle. Subtracting a bowl-shaped profile from the hillside instead --
	# which is what this did -- gives a hollow that inherits every bump of the
	# hill at full amplitude, and once the relief rose to half the radius that
	# meant a pond whose own floor fell four units across its width. A pond is a
	# flat-bottomed thing; this is what says so.
	var share := bowl_at(ratio)
	height += (basin_top - basin_depth - height) * share
	if spill_half_angle > 0.0 and in_spill_wedge(x, z):
		height = minf(height, spill_floor)
	return height


## How far the bowl has taken the surface from the hillside towards its own flat
## floor at a given distance out, in [0, 1]: all the way in the middle, none at
## the bowl's lip and beyond.
##
## Flat at both ends, so the floor of the pond is a floor rather than a cone and
## the shore meets the hillside without a crease. The cube inside the square
## rather than the square inside the square is what widens the flat part: with
## the relief the tops now carry, the wall of the bowl climbs several units
## within a stride, and a profile that started curving away at once left a pond
## barely five units across on a forty-unit island.
func bowl_at(ratio: float) -> float:
	if basin_ratio <= 0.0 or ratio >= basin_ratio:
		return 0.0
	var across := ratio / basin_ratio
	var left := 1.0 - across * across * across
	return left * left


## Whether a position lies in the wedge of directions the pond drains along.
func in_spill_wedge(x: float, z: float) -> bool:
	if spill_half_angle <= 0.0:
		return false
	var away := atan2(z - centre_z, x - centre_x) - spill_angle
	while away > PI:
		away -= TAU
	while away < -PI:
		away += TAU
	return absf(away) <= spill_half_angle


## The height of the pond's own surface here, or -INF where the island holds no
## water at this position.
##
## The pond is flat at `water_level` over the bowl, and steps down along the
## spillway to stay a constant depth over the channel's floor -- so what runs
## out of the basin reads as a stream rather than as the lake continuing at its
## own level to the edge of a cliff. The two agree exactly where they meet: at
## the bowl's lip the channel floor is `water_level - SPILL_DEPTH`, so the
## channel's surface there is `water_level`.
##
## Water only ever stands where this says it does -- the bowl and the wedge --
## which is what keeps a pond from appearing round the whole rim, where the top
## surface also falls below `water_level`.
func pond_surface_at(x: float, z: float) -> float:
	if basin_ratio <= 0.0:
		return -INF
	var ratio := ratio_at(x, z)
	if ratio > 1.0:
		return -INF
	var in_basin := ratio <= basin_ratio
	if not in_basin and not in_spill_wedge(x, z):
		return -INF
	var top := top_height_at(x, z)
	var surface := water_level if in_basin else minf(water_level, top + SPILL_DEPTH)
	return surface if surface > top else -INF


## How deep the island's own water is here. Zero on its dry ground.
func pond_depth_at(x: float, z: float) -> float:
	var surface := pond_surface_at(x, z)
	if surface == -INF:
		return 0.0
	return maxf(0.0, surface - top_height_at(x, z))


## Whether the island's top surface is under its own water here.
##
## This is what makes a basin a hole in the board: a position the pond covers is
## not a surface anyone stands on, exactly as a position the world's water
## covers is not one. The terrain query reads it through the same call.
func holds_water_at(x: float, z: float) -> bool:
	return pond_surface_at(x, z) != -INF


## Whether this island holds a pond at all.
func has_basin() -> bool:
	return basin_ratio > 0.0


## Whether that pond runs over the rim as a waterfall.
func has_spill() -> bool:
	return spill_half_angle > 0.0 and spill_width > 0.0


## Install the basin: how far out the bowl reaches, how deep it is cut at the
## middle, how high the water in it stands, and the level the top surface stood
## at before the cut, which is what the bowl's flat floor is measured from.
func shape_basin(reach: float, depth: float, level: float, top: float) -> void:
	basin_ratio = reach
	basin_depth = depth
	water_level = level
	basin_top = top


## Install the spillway and the waterfall it ends in. All of it is hashed or
## derived by IslandField; this only stores it.
func shape_spill(
	angle: float,
	half_angle: float,
	floor_height: float,
	at_x: float,
	at_z: float,
	width: float,
	fall: float,
) -> void:
	spill_angle = angle
	spill_half_angle = half_angle
	spill_floor = floor_height
	spill_x = at_x
	spill_z = at_z
	spill_width = width
	spill_fall = fall


func _base_top_at(x: float, z: float, ratio: float) -> float:
	var lift := _relief_noise.unit_sample(x, z) * (1.0 - DETAIL_SHARE) \
		+ _detail_noise.unit_sample(x, z) * DETAIL_SHARE
	return rim_height + terrace_at(ratio) * relief \
		* (RELIEF_FLOOR + (1.0 - RELIEF_FLOOR) * lift)


## How much of the island's full keel depth hangs below the rim's lip here, in
## [0, 1]. Zero at the outline, and deepest under the middle of whichever
## direction the spurs favour.
##
## Both the share and the sharpness depend on the direction, which is the whole
## of why the underside reads as torn: one side hangs to its full depth on a
## sharp spike, the opposite side hangs to under half of it on a broad shoulder,
## and the outline's own inlets and peninsulas carry that in and out.
func keel_profile_at(x: float, z: float) -> float:
	var dx := x - centre_x
	var dz := z - centre_z
	var distance := sqrt(dx * dx + dz * dz)
	var angle := atan2(dz, dx)
	var ratio := clampf(distance / maxf(0.0001, outline_radius(angle)), 0.0, 1.0)
	var share := _spur_base
	for at in _spur_amplitudes.size():
		share += _spur_amplitudes[at] * sin(
			float(SPUR_FREQUENCIES[at]) * angle + _spur_phases[at]
		)
	var taper := _taper_base + _taper_amplitude * sin(angle + _taper_phase)
	return clampf(share, 0.0, 1.0) * pow(1.0 - ratio, taper)


## The deepest the keel could hang anywhere at a given distance out, whatever
## direction is asked about.
##
## This is what the placement rule bounds the keel with. It has to be a bound
## over all directions at once and not the profile in one of them, because a
## sample of the ground under the island is a statement about the ground and not
## about the direction it happened to be taken in -- and at the island's middle
## every direction meets, so no single direction's profile would cover it. The
## slowest taper gives the deepest keel at any ratio, and `_spur_peak` is the
## largest share any direction takes.
func keel_profile_bound(ratio: float) -> float:
	return _spur_peak * pow(1.0 - clampf(ratio, 0.0, 1.0), KEEL_TAPER_MIN)


## The height of the island's underside here: the rim's lip at the edge, falling
## away to the keel's spurs under the middle.
func bottom_height_at(x: float, z: float) -> float:
	return rim_height - rim_thickness - keel_depth * keel_profile_at(x, z)


## A detached copy: same numbers, no shared storage. The packed arrays are
## duplicated for the same reason chunk geometry duplicates its own -- this
## engine's packed arrays share storage when assigned across.
##
## The two heightfields are copied for the same reason and not shared, which is
## what an earlier version of this got wrong: it handed them across on the
## ground that a ValueNoise is immutable, and a ValueNoise is not. Its octaves,
## period, amplitude, lacunarity and gain are plain vars, so a holder of a
## "copy" that shared them could retune the island's relief and change the
## height a character stands on, everywhere, for everyone.
func detached_copy() -> FloatingIsland:
	var copy := FloatingIsland.new()
	copy.band = band
	copy.cell = cell
	copy.centre_x = centre_x
	copy.centre_z = centre_z
	copy.radius = radius
	copy.rim_height = rim_height
	copy.relief = relief
	copy.rim_thickness = rim_thickness
	copy.keel_depth = keel_depth
	copy.biome = biome
	copy.ground_tint = ground_tint
	copy.rock_tint = rock_tint
	copy.water_tint = water_tint
	copy.shape_basin(basin_ratio, basin_depth, water_level, basin_top)
	copy.shape_spill(
		spill_angle, spill_half_angle, spill_floor,
		spill_x, spill_z, spill_width, spill_fall,
	)
	copy.landing_step = landing_step
	copy.drift_radius = drift_radius
	copy.drift_rate = drift_rate
	copy.drift_phase = drift_phase
	copy.walkable = walkable
	copy.shape_outline(
		_blob_x.duplicate(), _blob_z.duplicate(), _blob_radius.duplicate(),
		_edge_amplitudes.duplicate(), _edge_phases.duplicate(),
	)
	copy.shape_body(
		_relief_noise.detached_copy() if _relief_noise != null else null,
		_detail_noise.detached_copy() if _detail_noise != null else null,
		_spur_base,
		_spur_amplitudes.duplicate(), _spur_phases.duplicate(),
		_taper_base, _taper_amplitude, _taper_phase,
	)
	return copy


## A short, stable fingerprint of the island's placement, at fixed precision so
## it does not depend on how floats happen to print. Two islands with the same
## fingerprint were hashed out of the same cell of the same world.
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("band=%d cell=%d,%d" % [band, cell.x, cell.y])
	parts.append("centre=%.4f,%.4f" % [centre_x, centre_z])
	parts.append("radius=%.4f rim=%.4f relief=%.4f" % [radius, rim_height, relief])
	parts.append("lip=%.4f keel=%.4f step=%.4f" % [rim_thickness, keel_depth, landing_step])
	parts.append("drift=%.4f,%.4f,%.4f" % [drift_radius, drift_rate, drift_phase])
	parts.append("biome=%s walkable=%d" % [biome, 1 if walkable else 0])
	parts.append("tints=%.4f,%.4f,%.4f/%.4f,%.4f,%.4f/%.4f,%.4f,%.4f" % [
		ground_tint.r, ground_tint.g, ground_tint.b,
		rock_tint.r, rock_tint.g, rock_tint.b,
		water_tint.r, water_tint.g, water_tint.b,
	])
	parts.append("basin=%.4f,%.4f,%.4f,%.4f" % [
		basin_ratio, basin_depth, water_level, basin_top,
	])
	parts.append("spill=%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f" % [
		spill_angle, spill_half_angle, spill_floor,
		spill_x, spill_z, spill_width, spill_fall,
	])
	for at in _blob_radius.size():
		parts.append("blob=%.4f,%.4f,%.4f" % [_blob_x[at], _blob_z[at], _blob_radius[at]])
	for at in _edge_amplitudes.size():
		parts.append("edge=%.4f,%.4f" % [_edge_amplitudes[at], _edge_phases[at]])
	parts.append("spur=%.4f" % _spur_base)
	for at in _spur_amplitudes.size():
		parts.append("spur=%.4f,%.4f" % [_spur_amplitudes[at], _spur_phases[at]])
	parts.append("taper=%.4f,%.4f,%.4f" % [_taper_base, _taper_amplitude, _taper_phase])
	# The two heightfields are in here as their parameters, because the relief
	# on top of the island is as much its shape as its outline is: two islands
	# whose fields are tuned differently are different islands, and a
	# fingerprint that left the fields out would call them the same one.
	parts.append("relief=%s" % (
		_relief_noise.parameter_text() if _relief_noise != null else "none"
	))
	parts.append("detail=%s" % (
		_detail_noise.parameter_text() if _detail_noise != null else "none"
	))
	return "|".join(parts).sha256_text().substr(0, 16)
