extends RefCounted
## Ground-cover grass: a baked patch of tufts, thousands of copies per chunk,
## bending in the wind and parting around whoever walks through it.
##
## The instanced unit is a *patch* rather than a tuft, and that is the answer to
## the grass reading sparse. A single KayKit tuft is three blades a third of a
## metre across; on this layer's lattice that is about one tuft per square metre
## of meadow, which covers under a tenth of the ground it stands on. The lattice
## is not the problem -- shrinking it would buy coverage at one instance per
## blade -- so instead PATCH_COPIES turns of the same tuft are baked into one
## mesh, spread over a patch a couple of metres across. A patch is still one
## instance, one transform and one row of the buffer; it just holds that many
## times the art. See reports/grass.md for the counts before and after.
##
## This whole layer lives in the render shell, and that is a decision rather than
## an accident. Every other layer of the world -- the ground, the biomes, the
## water, the islands, the villages, the scattered flora and props -- lives in
## the simulation, because what is there is a fact about the place: a character
## can walk into a tree, shelter behind a boulder, cross a bridge. Grass is the
## one piece of ground cover nothing can interact with. Nothing collides with it,
## nothing picks it up, no tactical rule reads it, and the world is exactly the
## same world whether or not a blade is drawn. So it is a property of the picture
## and not of the place, and putting it here is what makes "headless creates no
## grass at all" true by construction rather than by a flag: a headless process
## never loads this file, so the grass layer is not merely disabled there, it
## does not exist. tests/test_grass.gd is where that is checked from the outside.
##
## Nothing here invents the world either. Where the ground is, how high it is,
## what colour it is, which way it faces, whether it is water, whether a road or
## a building is on it and how thickly the biome grows things are all read off
## the simulation -- most of them off the chunk geometry the shell was already
## handed to draw, which is why a blade sits exactly on the triangle under it
## rather than a finger above or below it.
##
## The write-up, with the two open questions of section 13 answered and the cost
## measured, is reports/grass.md.
class_name GrassLayer

## How many copies of the tuft one baked patch holds, and how wide the square
## they are spread over is in the mesh's own frame.
##
## This is the one number that decides the coverage of the whole layer, and it is
## stated once here rather than at the call sites: everything else -- the
## triangle count, the blades per square metre, the size of the box the engine is
## told to cull against, how far a patch reaches over a bank -- follows from it.
##
## Twelve was chosen by measuring, not by taste. reports/grass.md has the table:
## four copies still reads as scattered clumps, eight closes most of the ground,
## twelve closes it, and past that the triangles double again for a picture that
## does not change. The span is in the frame the tuft was modelled in, so a patch
## of tall grass is a wider patch, which is what a patch of tall grass is.
const PATCH_COPIES := 12
const PATCH_SPAN := 1.9

## Candidate patches along one side of a chunk. A chunk is sixteen units, so this
## is a patch every 0.57 units before the biome thins it out.
const LATTICE := 28

## World units between candidates.
const CELL := TerrainChunkMesher.CHUNK_SIZE / float(LATTICE)

## How far off its cell's centre a patch may sit, as a share of half a cell.
## Below 1 so that two neighbours can never swap places, which would show as a
## lattice however hard the jitter tried to hide it.
const JITTER := 0.85

## How tall the tufts in a patch stand, in world units, before the biome and the
## hash between them pick a value. Short: this is ground cover, and the scatter
## layer's ferns and bushes are what stands above it. The copies inside a patch
## vary about this by a further fifth either way, baked in.
const HEIGHT_MIN := 0.36
const HEIGHT_MAX := 0.78

## How much wider than tall a tuft may be drawn, so that a field is not a field
## of identical clones.
const SPREAD_MIN := 1.00
const SPREAD_MAX := 1.60

## The steepest ground grass grows on, as the cosine of the slope: 0.72 is about
## forty-four degrees. Anything steeper is cliff, and a tuft on a cliff face
## stands out of it sideways.
const SLOPE_COS := 0.72

## How far towards the biome's foliage colour the ground colour is carried to
## get the colour of the blades standing on it.
##
## The ground tint under the blade is where this starts, not the biome's own,
## because that tint already carries the biome blend, the dirt of a road and the
## trodden earth of a village green -- so grass on a track is the colour of the
## track it is growing at the edge of.
##
## A quarter of the way, and the quarter was measured rather than judged by eye.
## tools/measure_stipple.sh grows the same paused meadow again at each candidate
## and reports what the blades do to each channel of the ground they cover. A
## blade catches less light than the flat ground under it whatever colour it is
## painted, so every mix darkens the picture a little; what separates them is
## whether they darken the three channels *evenly*, because grass that moves one
## channel much further than the others is a different colour laid over the
## ground rather than the same ground in less light. Measured on the meadow at
## the shipped shading: at 0.35 the three fall 9.9%, 7.5% and 9.0%, a gap of 2.4
## points; at 0.25, 7.9%, 6.2% and 8.9%, a gap of 2.7; at 0.20 the gap widens to
## 3.3 as red and green outrun blue's floor. Everything from 0.20 to 0.35 is
## inside three points of even, and a quarter is the largest of them that leaves
## the blades no further from their ground than the build this replaced.
## reports/grass.md §10 has the tables and the two things that had to be fixed
## before this number meant anything at all.
##
## Nothing is lost by being close to the ground: the ground colour is itself the
## biome's, so grass still shifts across a biome border, and the quarter that is
## left of the foliage colour is what keeps a marsh's grass from reading as a
## meadow's on the same brown.
##
## This is not the `grass` row's own `scene_tint_mix`, and it is not meant to be:
## a row's mix says how far a *model* is carried towards the biome's colour for
## its role, and this says how far the *ground* is carried towards the biome's
## foliage colour to decide what is growing out of it.
const LEAF_MIX := 0.25

## How much of the ground each biome would carry if nothing thinned it: this
## layer's own number, one per named biome, in [0, 1].
##
## This used to be the biome profile's `foliage_density`, and that was backwards.
## That field is what the tree scatter grows from -- how thickly a biome puts
## *things* on the ground -- so reading it here made the deep forest (0.95) grow
## half again as much grass as the meadow (0.45), when a closed canopy is exactly
## what shades a floor bare and an opening is exactly what lets grass flourish.
## The meadow is the design's first reference beat and the one that has to read
## lush, so the ordering here is the other way up and is deliberately the grass
## layer's own: the simulation's foliage density is left alone, because the tree
## scatter reads it and moving it would move the world.
##
## The ordering is not invented here. Two of the five biome profiles advertise
## `grass` among their own prop tags -- the meadow and the blossom grove -- and
## the other three advertise hardy shrubs, ferns and cattails instead. So the
## catalog already says where grass belongs; this table is how much, and the two
## that say yes are generous while the three that say no keep enough to bind the
## ground together. The three thin ones are thin for three different reasons: the
## deep forest because a closed canopy shades its floor, the highland because of
## wind and thin soil, the marsh because what grows in standing water is reeds
## and cattails, which are the scatter layer's job and not this one's.
## tests/test_grass.gd checks that agreement rather than leaving it to drift.
const GRASS_COVERAGE := {
	BiomeCatalog.MEADOW: 0.95,
	BiomeCatalog.BLOSSOM_GROVE: 0.78,
	BiomeCatalog.TWILIGHT_MARSH: 0.36,
	BiomeCatalog.HIGHLAND: 0.32,
	BiomeCatalog.DEEP_FOREST: 0.30,
}

## The clearing mask, and the scales it is built from -- in world units, which
## are metres.
##
## A biome coverage on its own cannot make patches. Every cell was an independent
## coin flip against one number, which is uniform confetti: at 0.41 a meadow was
## never bare anywhere and never closed anywhere, just evenly two-fifths covered
## everywhere, and no amount of art in one tuft fixes that. What makes patches is
## a second field that varies at a scale a walker can see across, multiplied into
## the coverage before the flip.
##
## The two fields, the multiply and the curve below are the reference build's
## arrangement. Its scales are not, and the difference is worth stating: it
## clears at about 228 m with a boundary lattice at about 144 m, and this layer
## does the same thing at a third of that. The reason is BUILD_RADIUS. Grass here
## reaches 38 m from whoever is looking, so the ground a frame can show is a disc
## 76 m across; a clearing 228 m wide is three of those end to end, and no frame
## would ever hold an edge of one. What would arrive instead is a walk of several
## minutes over bare ground followed by a walk of several minutes over grass,
## which is not what "in patches" means. The ratio between the two scales is kept
## exactly (76 : 48 is 228 : 144), so what changes is how far away a clearing is
## and not what one looks like.
##
## Two fields multiplied together, because they do different jobs:
##
## * A **clearing field** -- smooth value noise at CLEARING_SCALE with a smaller
##   octave at CLEARING_DETAIL folded in, so the broad shape is a clearing forty
##   metres or so across and the detail is what keeps its edge from being an
##   oval. Two octaves of value noise are a hill, not a clearing, so the sum
##   is pushed through its own contrast window (CLEARING_OPEN to CLEARING_FULL)
##   first: below the one the ground is open and above the other it is whatever
##   the biome wants, and what is left between them is the edge of the clearing.
##   Without that step the field spends nearly all of its time in the middle of
##   its range, the curve below is crossed almost everywhere, and what comes out
##   is a soft gradient rather than a patch -- measured, and in reports/grass.md.
## * A **boundary field** -- a jittered Voronoi lattice at BOUNDARY_SCALE, read
##   not by which cell a point is in but by how far it is from the nearest
##   *edge*: the difference between the distance to the closest site and to the
##   second closest. That difference falls to zero exactly along the boundary
##   between two cells, so the zeroes form a connected network, and at
##   BOUNDARY_PATH wide they read as bare paths worn through the grass.
##   Connected is what a Voronoi buys and a scatter of round holes does not; what
##   it does not buy is wandering, because a Voronoi edge is a straight segment
##   however hard the sites are jittered, and a field of them read as a pane of
##   leaded glass. So the position is bent before the lattice is asked -- offset
##   by a noise field of its own at BOUNDARY_WANDER_SCALE -- which leaves the
##   network connected and makes every edge of it a curve.
##
## Both are pure functions of world position and the seed, which is what lets the
## whole thing stay in the render shell: a mask that is the same in every process
## for the same seed cannot move the world, and tests/test_grass.gd checks that
## across two processes rather than taking it on trust.
const CLEARING_SCALE := 76.0
const CLEARING_DETAIL := 28.0
## How much of the mask the smaller octave is, against the broad one.
const CLEARING_DETAIL_SHARE := 0.34
## The contrast window the two octaves are pushed through, on the noise's own
## [0, 1]: below the first is open ground, above the second is untouched.
const CLEARING_OPEN := 0.24
const CLEARING_FULL := 0.62
const BOUNDARY_SCALE := 48.0
## How wide a boundary reads as bare, in world units.
const BOUNDARY_PATH := 5.0
## How far the lattice is bent before it is asked, as a share of a cell, and the
## scale of the noise that bends it, in world units.
const BOUNDARY_WANDER := 0.40
const BOUNDARY_WANDER_SCALE := 62.0
## How far a Voronoi site may sit from the middle of its cell, as a share of the
## cell. Below 1 so that a site stays inside its own cell and the nearest two of
## them are always among the nine cells around a point.
const BOUNDARY_JITTER := 0.85

## The curve the masked coverage is pushed through: below the first it is exactly
## bare, above the second exactly a closed carpet, and between them it ramps.
##
## This is the whole of what turns a coverage into a patch. Without it a mask
## that halves the coverage just halves the confetti; with it, ground the mask
## has weakened goes to nothing at all and ground the mask has left alone goes to
## every cell on the lattice. The window is narrow on purpose -- 0.22 wide -- so
## that the band where grass is *thinning* is a metre or two of edge rather than
## the whole field, which is what makes a bed read as a bed and a clearing as a
## clearing.
##
## There is no floor under this any more. The old one held every cell of every
## biome at 0.28 so the highland would not read as unfinished, and that floor is
## exactly why nowhere could be bare. What replaces it is per-biome: a biome that
## should carry some grass carries it in GRASS_COVERAGE above, where the number
## is about that biome rather than about all of them at once.
const CURVE_LOW := 0.20
const CURVE_HIGH := 0.42

## How much of the grass a road takes away where it is at full strength. Not all
## of it: a cart track has grass at its edges, and the strength field fades out
## across the verge, so this thins rather than shaves.
const ROAD_THINNING := 0.92

## How far outside a building's reserved rectangle grass still refuses to grow,
## in world units.
const BUILDING_MARGIN := 0.25

## How far above the local water surface the ground has to stand before grass
## grows on it, in world units.
##
## Being water is the water field's own answer -- the surface standing above the
## bed -- and this is that comparison with a little air added, so the last hand's
## breadth of bank is bare. That strip is where the scatter layer's reeds,
## cattails and lily pads belong, and grass growing into it would hide them.
const FREEBOARD := 0.12

## Which chunks get grass at all, in world units from an observer, and which are
## dropped again. The gap is the same kind of hysteresis the ground streamer
## uses: walking back and forth across the boundary must not rebuild the same
## grass every step.
##
## The first is just inside the ground's own load radius of 40, so grass covers
## as much of the ground as is drawn at all; the second is well inside the
## ground's unload radius of 56, so grass can never be left hanging in the air
## where the chunk under it has been dropped.
const BUILD_RADIUS := 38.0
const DROP_RADIUS := 46.0

## The level-of-detail band, in world units from the observer: every tuft inside
## the first, and a falling share of them out to the second, never below the
## floor. See reports/grass.md for why this is done by hiding a suffix of the
## instances rather than by building thinner chunks.
const FULL_RADIUS := 16.0
const THIN_SHARE := 0.3

## How finely the visible share is stepped. Quantising it means a walking
## observer changes a chunk's instance count a few times on its way past rather
## than every frame.
const LOD_STEPS := 8

## Where a blade starts shrinking into the ground and where it has vanished, in
## world units from the observer. Inside BUILD_RADIUS on both counts, so a chunk
## is never built with anything visible in it that then pops.
const FADE_START := 30.0
const FADE_END := 37.0

## The most the biome tint may brighten one channel of the tuft's own art, in
## linear light.
##
## The asset table caps a model's tint at 1.5, and does it on colours the engine
## then converts from ordinary sRGB numbers to linear light. This layer does its
## arithmetic in linear light already -- the texture arrives linearised and the
## instance colour does not -- so the same cap is 1.5 raised to the gamma, about
## 2.5.
##
## Four rather than that 2.5, and the extra is for one channel. The art the tint
## divides by is a warm yellow-green whose blue is 0.044 in linear light against
## 0.14 red and 0.43 green, so asking a blade to be the colour of pale highland
## turf needs its blue multiplied by about 3.9 while its red and green need less
## than 1.4. Capping at 2.5 clipped the blue of the two pale biomes and left
## their grass more saturated than anything had asked for -- the cap silently
## becoming the colour. There is no cost to the headroom: the instance buffer
## stores the gain as a share of this number, so raising it moves where the same
## share lands and nothing else. It still binds where the table's does, on the
## blossom grove, which asks its foliage for more red than a green atlas can be
## multiplied into.
const MAX_GAIN := 4.0

## How many characters the shader will part the grass around at once.
const WALKERS := 8

## How far from a character the grass is pushed aside, in world units, and how
## far above or below them a blade still counts as under their feet -- so
## someone standing on a floating island does not flatten the meadow below.
const WALKER_REACH := 2.4
const WALKER_BAND := 2.5

## The wind. Lengths and travel speeds are in world units and world units per
## second, so they are calibrated against the size of the world rather than
## against anything on a screen.
##
## Two waves running the same way at different scales: a long slow one that
## crosses a whole view in a few seconds and spends most of its cycle at rest --
## that is the rolling gust -- and a short quick one that is always going, which
## is the fidget of individual blades. The gust multiplies rather than adds, so
## between gusts the field is calm rather than merely less busy.
const WIND_HEADING := 0.9
const GUST_LENGTH := 26.0
const GUST_TRAVEL := 7.0
const CROSS_LENGTH := 41.0
const CROSS_TRAVEL := 4.5
const RIPPLE_LENGTH := 3.2
const RIPPLE_TRAVEL := 9.0
## Tip displacement in world units: what a blade does between gusts, and what a
## gust adds on top of that.
const SWAY_CALM := 0.05
const SWAY_GUST := 0.24

## The shader.
##
## Everything animated is a function of *world* position and time, exactly as the
## water's ripples are and for the same reason: grass belongs to the world, so a
## chunk that streams in beside one already on screen is part of the same gust
## rather than starting its own.
##
## It works in world coordinates (`world_vertex_coords`), which is what lets the
## wind push a blade along a world direction without having to undo the
## instance's own rotation and scale first. The root of a blade stays where it
## is; how far up the blade a vertex is decides how far it is carried, so a tuft
## bends rather than slides.
##
## The root of a blade is *the blade's own root*, not the instance's origin. With
## one tuft per instance those were the same thing and the shader took the
## origin; with a dozen tufts in a patch they are not, and taking the origin
## would gust a whole patch as one object and let a character standing at one
## corner of it flatten the other corner two metres away. So every vertex carries
## the root of the copy it belongs to in its second texture-coordinate channel,
## written when the patch was baked, and the shader puts that through the model
## matrix to get where that blade is standing in the world.
const GRASS_SHADER := """
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, specular_disabled;

// How tall the mesh is in its own frame, so a vertex can say how far up the
// blade it is, and the most the biome tint may brighten a channel -- the
// instance colour is stored as a share of it so it stays inside [0, 1].
//
// There is no texture here at all. The tuft carries the pack's own palette
// colour per vertex, in linear light, read off the atlas once when the mesh was
// baked; see AssetLibrary.instanced_mesh().
uniform float natural_height = 1.0;
uniform float max_gain = 4.0;

// The wind, in world units and world units per second.
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float gust_length = 26.0;
uniform float gust_travel = 7.0;
uniform float cross_length = 41.0;
uniform float cross_travel = 4.5;
uniform float ripple_length = 3.2;
uniform float ripple_travel = 9.0;
uniform float sway_calm = 0.05;
uniform float sway_gust = 0.24;

// Where the view is centred, and the band over which a blade shrinks into the
// ground rather than popping out of existence.
uniform vec2 focus = vec2(0.0, 0.0);
uniform float fade_start = 30.0;
uniform float fade_end = 37.0;

// Who is walking through it: xyz is where they are standing, w is how far their
// feet reach. A radius of zero is an unused slot.
uniform vec4 walkers[8];
uniform float walker_band = 2.5;
uniform float walker_push = 0.55;
uniform float walker_flatten = 0.72;

void vertex() {
	// Where this blade is rooted: UV2 is the root of this vertex's own copy in
	// the patch's frame, so a patch of a dozen tufts has a dozen roots and the
	// wind and the walkers below act on each of them separately.
	vec3 root = (MODEL_MATRIX * vec4(UV2.x, 0.0, UV2.y, 1.0)).xyz;
	float tall = natural_height * length(MODEL_MATRIX[1].xyz);
	// How far up the blade this vertex is, and how far that carries it: the
	// square is what makes the root hold still and the tip do the moving.
	float up = clamp((VERTEX.y - root.y) / max(tall, 0.0001), 0.0, 1.0);
	float lean = up * up;

	vec2 across = vec2(-wind_dir.y, wind_dir.x);
	float along = dot(root.xz, wind_dir);
	float sideways = dot(root.xz, across);
	// One number per instance, shifted by where the blade stands inside its
	// patch, so blades sharing a patch fidget independently of one another.
	float phase = INSTANCE_CUSTOM.x * 6.2831853 + dot(UV2, vec2(11.7, 7.3));

	// The gust: a long wave rolling downwind, pushed through a smoothstep so
	// that most of its cycle is calm and the crest arrives as a front.
	float gust_wave = sin((along - TIME * gust_travel) * 6.2831853 / gust_length);
	float gust = smoothstep(-0.15, 0.90, gust_wave);
	// A second, longer wave running across the wind, so a front is a ragged
	// band rather than a straight line the width of the view.
	float cross_wave = sin((sideways - TIME * cross_travel) * 6.2831853 / cross_length);
	gust *= 0.55 + 0.45 * (cross_wave * 0.5 + 0.5);

	float ripple = sin((along - TIME * ripple_travel) * 6.2831853 / ripple_length + phase);
	float amount = sway_calm * ripple + sway_gust * gust * (0.6 + 0.4 * ripple);
	vec2 push = wind_dir * amount + across * amount * 0.22 * cos(phase);

	// Whoever is walking through it. Stateless on purpose: the push is a pure
	// function of where the blade is and where the characters are now, so it
	// costs nothing to stream, survives a chunk being dropped and rebuilt, and
	// needs no memory anywhere. See reports/grass.md.
	float flattened = 0.0;
	for (int i = 0; i < 8; i++) {
		float reach = walkers[i].w;
		if (reach <= 0.0) { continue; }
		if (abs(root.y - walkers[i].y) > walker_band) { continue; }
		vec2 away = root.xz - walkers[i].xz;
		float gap = length(away);
		if (gap > reach) { continue; }
		float near = 1.0 - smoothstep(0.0, reach, gap);
		near *= near;
		vec2 outward = gap > 0.001 ? away / gap : vec2(1.0, 0.0);
		push += outward * near * walker_push;
		flattened = max(flattened, near);
	}

	float shrink = 1.0 - smoothstep(fade_start, fade_end, distance(root.xz, focus));
	shrink *= 1.0 - flattened * walker_flatten;

	VERTEX.y = root.y + (VERTEX.y - root.y) * shrink;
	VERTEX.xz += push * lean * shrink;
	// A blade that has been pushed over is not as tall as one standing up.
	VERTEX.y -= lean * length(push) * 0.30;

}

void fragment() {
	// Stylised shading: pulling every normal most of the way towards straight
	// up makes a tuft read as one soft shape catching the sky rather than as a
	// handful of separately lit facets, which is the look the rest of the world
	// is drawn in and is also what keeps a field from sparkling as it moves. It
	// is also what makes a single-sided blade work: both of its faces are lit as
	// if they faced the sky, so there is no black side to the grass.
	//
	// It is done *here*, and that is the whole of it. A blade is one sheet drawn
	// from both sides, and the engine turns the normal of a back-facing fragment
	// around before this function runs so that it points out of the side being
	// looked at. Flattening in the vertex stage happened before that turn, so
	// every back-facing fragment got the flattened normal *negated* -- aimed at
	// the ground rather than at the sky -- and a quarter of the grass on screen
	// was lit from below. That is the light-side-dark-side blade the request
	// remembered, and it survived the earlier check because forcing the flatten
	// the rest of the way to straight up makes the far side point straight down,
	// which is worse rather than better. Flattening here, after the turn, lights
	// both faces as if they faced the sky, which is what was always intended.
	//
	// Straight up is the world's, carried into the camera's frame, because that
	// is the frame a fragment's normal is in.
	//
	// Most of the way, rather than all of it: the sixth of its own normal a blade
	// keeps is what stops a tuft being one flat colour. How far to go was worth
	// measuring once the stage was right, because in the vertex stage it had been
	// pulling in two directions at once -- more flattening meant a better near
	// face and a worse far one. Here it only helps: over the meadow, going from
	// 0.70 to 0.85 takes the noise from 0.0748 to 0.0709 and the spread of what
	// the grass does to its ground from 0.0553 to 0.0469, and going all the way
	// to 1.00 buys a further 0.002 of noise for the last of the blade's form.
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up, 0.85));

	// COLOR is the tuft's own palette colour multiplied by the instance's,
	// which carries the biome tint at this tuft as a share of max_gain so the
	// instance buffer never has to hold a number above one.
	ALBEDO = COLOR.rgb * max_gain;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	SPECULAR = 0.1;
}
"""

## How many chunks have ever had grass built for them, including rebuilds after
## an unload. What the cost measurement divides its build time by.
var chunks_built := 0

var _terrain: TerrainQuery = null
var _world_seed := 0
var _material: ShaderMaterial = null
var _mesh: Mesh = null
var _natural_height := 1.0
## How tall the tallest copy in a patch stands and how far the furthest of them
## sits from the middle, both in the mesh's own frame -- the box the engine is
## told to cull against and the margin a patch keeps from a bank are these.
var _patch_height := 1.0
var _patch_reach := 0.0
var _reference := Color(1.0, 1.0, 1.0)

## How far towards the foliage colour this layer is carrying the ground, which is
## LEAF_MIX for every run the game is played in.
##
## It is a property and not just the constant because the value was chosen by
## measuring: tools/measure_stipple.gd grows the same paused frame's grass again
## at each candidate mix and reads what each one does to the ground under it. The
## constant remains the single statement of the shipped value; this is the dial
## that sweep turns, and nothing in the shell ever writes it.
var leaf_mix := LEAF_MIX

# The order the lattice is walked in: a fixed shuffle of every candidate cell,
# computed once. Walking it in this order means the instances land in the buffer
# already shuffled, so hiding a suffix of them thins the field evenly instead of
# clearing one corner of every chunk. Nothing else depends on the order.
static var _walk_order := PackedInt32Array()


func _init(terrain: TerrainQuery, world_seed: int) -> void:
	_terrain = terrain
	_world_seed = world_seed
	var baked := AssetLibrary.instanced_mesh(AssetTags.GRASS, PATCH_COPIES, PATCH_SPAN)
	_mesh = baked["mesh"]
	# One *tuft's* height, not the patch's: this is what a wanted height in world
	# units is divided by to get the instance's scale, and the copies inside a
	# patch are deliberately a little taller and shorter than one another.
	_natural_height = maxf(0.0001, float(baked["base_height"]))
	_patch_height = maxf(_natural_height, float(baked["height"]))
	_patch_reach = float(baked["reach"])
	_reference = baked["reference"]
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GRASS_SHADER
	_material.shader = shader
	_material.set_shader_parameter("natural_height", _natural_height)
	_material.set_shader_parameter("max_gain", MAX_GAIN)
	_material.set_shader_parameter("wind_dir", Vector2(
		cos(WIND_HEADING), sin(WIND_HEADING)
	))
	_material.set_shader_parameter("gust_length", GUST_LENGTH)
	_material.set_shader_parameter("gust_travel", GUST_TRAVEL)
	_material.set_shader_parameter("cross_length", CROSS_LENGTH)
	_material.set_shader_parameter("cross_travel", CROSS_TRAVEL)
	_material.set_shader_parameter("ripple_length", RIPPLE_LENGTH)
	_material.set_shader_parameter("ripple_travel", RIPPLE_TRAVEL)
	_material.set_shader_parameter("sway_calm", SWAY_CALM)
	_material.set_shader_parameter("sway_gust", SWAY_GUST)
	_material.set_shader_parameter("fade_start", FADE_START)
	_material.set_shader_parameter("fade_end", FADE_END)
	_material.set_shader_parameter("walker_band", WALKER_BAND)
	_clear_walkers()


## The one material every chunk of grass is drawn with. Shared, so that setting
## the wind or the characters is one write however many chunks are on screen.
func material() -> ShaderMaterial:
	return _material


## The mesh one patch is made of: PATCH_COPIES turns of the grass tag's own row,
## baked out of the asset table into a single surface.
func blade_mesh() -> Mesh:
	return _mesh


## What one patch holds, for the cost measurement and for the report: the number
## of copies, the number of blades in it, and its triangles.
func patch_facts() -> Dictionary:
	return AssetLibrary.instanced_mesh(AssetTags.GRASS, PATCH_COPIES, PATCH_SPAN)


## Whether a chunk that far from the nearest observer should have grass.
static func wanted_at(distance: float) -> bool:
	return distance <= BUILD_RADIUS


## Whether a chunk that far from every observer should lose the grass it has.
static func dropped_at(distance: float) -> bool:
	return distance > DROP_RADIUS


## The share of a chunk's tufts that are drawn at that distance, in [0, 1],
## quantised so a walking observer changes it a handful of times rather than
## every frame.
static func visible_share(distance: float) -> float:
	if distance <= FULL_RADIUS:
		return 1.0
	var span := maxf(0.0001, BUILD_RADIUS - FULL_RADIUS)
	var along := clampf((distance - FULL_RADIUS) / span, 0.0, 1.0)
	var share := lerpf(1.0, THIN_SHARE, along)
	return ceilf(share * LOD_STEPS) / float(LOD_STEPS)


## How finely the fields that the drawn ground cannot answer are sampled across a
## chunk: how thickly the biome grows things and what colour its foliage is, and
## how high the water stands and how much road there is.
##
## These are the layer's whole cost, because a question put to the terrain query
## is expensive -- 26 microseconds for the water surface and 28 for the road on
## the machine this was measured on -- while everything read off the chunk's own
## triangles is free. So they are sampled coarsely and interpolated: the biome
## fields turn over across hundreds of units, so a sixteen-unit chunk needs only
## its four corners, and water and roads at four-unit spacing keep a river's edge
## and a cart track's verge to within a fraction of a unit of where they are.
## reports/grass.md has the numbers this costs and what it would cost otherwise.
##
## The clearing mask gets a grid of its own, and a finer one, for a reason worth
## saying: the other fields are smooth, but the mask's boundary field has an edge
## in it -- a bare path BOUNDARY_PATH wide -- and the whole point of that edge is
## its shape. Sampled at four-unit spacing a wandering path would come back as a
## chain of straight segments long enough to see from the playing camera. Two
## units is under a fifth of the path's own width, so what is interpolated is
## already a gradient rather than a step. The mask costs no terrain query at all,
## only arithmetic, which is why it can afford eighty-one samples where the water
## and the roads get twenty-five.
const PROFILE_SIDE := 2
const FIELD_SIDE := 5
const MASK_SIDE := 9

## How much of the ground this biome blend would carry, before the clearing mask
## and the curve: the weighted average of GRASS_COVERAGE over whichever biomes
## have a share of the position.
##
## Averaged rather than switched on the strongest biome, and that is the whole of
## keeping a border organic. The weights are the same continuous weights the
## profile blends its colours and its fog with, so grass coverage crosses a
## border exactly the way the ground colour does -- over the width of the blend
## -- rather than stepping at the line where one biome starts outweighing the
## other. A step there would draw the border as a straight edge in the grass,
## which is the one thing biome borders are arranged not to be.
static func coverage_for(weights: Dictionary) -> float:
	var total := 0.0
	var covered := 0.0
	for id in BiomeCatalog.IDS:
		var share := maxf(0.0, float(weights.get(id, 0.0)))
		total += share
		covered += share * float(GRASS_COVERAGE.get(id, 0.0))
	if total <= 0.0:
		return float(GRASS_COVERAGE[BiomeCatalog.MEADOW])
	return covered / total


## The clearing mask at a world position: how much of whatever the biome would
## grow actually grows here, in [0, 1].
##
## A pure function of x, z and the seed and of nothing else -- no time, no chunk,
## no observer, nothing kept between calls. That is not a nicety: it is what lets
## a layer that lives in the render shell decide where grass grows without the
## world being able to tell, and it is what makes a chunk streamed out and walked
## back to come back the same. tests/test_grass.gd asserts it across two separate
## processes, and demonstrates the assertion failing when something that is not
## position and seed is fed in.
##
## The two fields and why they are the two are on CLEARING_SCALE above.
static func clearing_at(x: float, z: float, world_seed: int) -> float:
	var broad := _value_noise(x, z, CLEARING_SCALE, world_seed ^ 0x3C7A11)
	var detail := _value_noise(x, z, CLEARING_DETAIL, world_seed ^ 0x51B9C3)
	var clearing := smoothstep(
		CLEARING_OPEN, CLEARING_FULL, lerpf(broad, detail, CLEARING_DETAIL_SHARE)
	)
	return clearing * _boundary_field(x, z, world_seed ^ 0x7A4D2F)


## Smooth value noise on a square lattice `scale` world units across, in [0, 1].
##
## Ordinary bilinear value noise with a smoothstep on each axis, which is enough
## here: what this field has to be is broad, smooth and seeded, and nothing about
## a clearing needs the extra structure of a gradient noise.
static func _value_noise(x: float, z: float, scale: float, salt: int) -> float:
	var u := x / scale
	var v := z / scale
	var cell_x := floori(u)
	var cell_z := floori(v)
	var fu := u - float(cell_x)
	var fv := v - float(cell_z)
	fu = fu * fu * (3.0 - 2.0 * fu)
	fv = fv * fv * (3.0 - 2.0 * fv)
	var top := lerpf(
		_lattice_value(cell_x, cell_z, salt),
		_lattice_value(cell_x + 1, cell_z, salt), fu
	)
	var bottom := lerpf(
		_lattice_value(cell_x, cell_z + 1, salt),
		_lattice_value(cell_x + 1, cell_z + 1, salt), fu
	)
	return lerpf(top, bottom, fv)


## How far this position is from the nearest boundary of a jittered Voronoi
## lattice BOUNDARY_SCALE across, as a number in [0, 1]: zero on a boundary,
## one well inside a cell.
##
## The distance to a boundary is not the distance to a site. It is the difference
## between the distance to the nearest site and to the second nearest, which is
## zero exactly where two sites are equally close -- the boundary between them --
## and grows either side of it. Reading the field that way is what makes the
## bare ground a connected wandering network rather than a scatter of round
## holes, and a network of bare ground through grass is a path.
##
## Five cells by five, not three by three, and that is a bug fixed rather than a
## precaution. Confining a site to its own cell is enough to put the *nearest*
## one in the ring around a point, but not the second nearest: from a corner of
## the middle cell the nearest site can be 1.35 cells away while a site two cells
## out is only 1.08 away, so with a ring of one the second-nearest distance jumps
## whenever the ring shifts. It showed as the mask moving by 0.40 between two
## lattice cells half a metre apart -- a hard seam through the grass -- and
## tests/test_grass.gd now measures that step and would catch it again.
static func _boundary_field(x: float, z: float, salt: int) -> float:
	# Bend the position first, so a straight Voronoi edge is met along a curve.
	var wander := BOUNDARY_WANDER * 2.0
	var u := x / BOUNDARY_SCALE + (
		_value_noise(x, z, BOUNDARY_WANDER_SCALE, salt ^ 0x1D3A57) - 0.5
	) * wander
	var v := z / BOUNDARY_SCALE + (
		_value_noise(x, z, BOUNDARY_WANDER_SCALE, salt ^ 0x62F80B) - 0.5
	) * wander
	var cell_x := floori(u)
	var cell_z := floori(v)
	var nearest := INF
	var second := INF
	for row in 5:
		for column in 5:
			var site_x := cell_x + column - 2
			var site_z := cell_z + row - 2
			var h := _mix(site_x, site_z, salt)
			var jitter_u := (float(h & 0xFF) / 255.0 - 0.5) * BOUNDARY_JITTER
			var jitter_v := (float((h >> 8) & 0xFF) / 255.0 - 0.5) * BOUNDARY_JITTER
			var at_u := float(site_x) + 0.5 + jitter_u
			var at_v := float(site_z) + 0.5 + jitter_v
			var gap_u := u - at_u
			var gap_v := v - at_v
			var away := gap_u * gap_u + gap_v * gap_v
			if away < nearest:
				second = nearest
				nearest = away
			elif away < second:
				second = away
	var edge := (sqrt(second) - sqrt(nearest)) * BOUNDARY_SCALE
	return smoothstep(0.0, BOUNDARY_PATH, edge)


## One lattice corner's value, in [0, 1].
static func _lattice_value(cell_x: int, cell_z: int, salt: int) -> float:
	return float(_mix(cell_x, cell_z, salt) & 0xFFFFFF) / 16777216.0


## The bit mixer as a call, for the mask. The same one the per-blade loop writes
## out inline: the mask is sampled eighty-one times a chunk rather than eight
## hundred, so it can afford to be readable here.
static func _mix(a: int, b: int, salt: int) -> int:
	var h := ((a * 0x27D4EB2D) ^ (b * 0x165667B1) ^ salt) & HASH_MASK
	h ^= h >> 16
	h = (h * 0x7FEB352D) & HASH_MASK
	h ^= h >> 15
	h = (h * 0x846CA68B) & HASH_MASK
	h ^= h >> 16
	return h


## How much of the ground actually grows, at a position where the biome would
## carry `cover` and the clearing mask reads `mask`: the product pushed through
## the curve, so weak ground is exactly bare and moderate ground exactly closed.
static func grown_share(mask: float, cover: float) -> float:
	return smoothstep(CURVE_LOW, CURVE_HIGH, mask * cover)


## The bit mixer, written out inline below rather than called.
##
## It is the same one `SimRng` uses -- the same constants in the same order, so a
## tuft would land in the same place either way -- but it is run six or seven
## hundred times per chunk, and in this language four nested static calls at that
## rate cost about a millisecond a chunk on their own. Grass is the one place in
## the project where that matters, because it is the one thing there are
## thousands of.
const HASH_MASK := 0xFFFFFFFF


## Grow the grass on one chunk, or null where nothing grows.
##
## The geometry is the copy the shell was handed to draw, and that is what makes
## this affordable: the height, the slope and the ground colour under every blade
## are read off the triangle the blade stands on rather than asked of the fields
## again. Only what the triangles cannot answer -- how thickly this biome grows,
## what colour its foliage is, how high the water stands and where the roads are
## -- comes from the simulation, on the coarse grids above.
##
## The tests are ordered by what they cost. The density test rejects most
## candidates and needs nothing but a hash and four floats; the road, the water,
## the slope and the buildings are only asked about the ones that survive it.
func build(geometry: TerrainChunkGeometry) -> MultiMeshInstance3D:
	chunks_built += 1
	var origin_x := float(geometry.chunk_x) * TerrainChunkMesher.CHUNK_SIZE
	var origin_z := float(geometry.chunk_z) * TerrainChunkMesher.CHUNK_SIZE

	# The biome's share of the chunk, asked once per corner. The weights are what
	# is asked for rather than the blended profile, because this layer wants two
	# different averages of them -- its own grass coverage, which the profile
	# does not carry, and the foliage tint, which it does -- and weighting them
	# both here is one sample rather than two.
	var profile_step := TerrainChunkMesher.CHUNK_SIZE / float(PROFILE_SIDE - 1)
	var density := PackedFloat32Array()
	var leaf := PackedColorArray()
	for row in PROFILE_SIDE:
		for column in PROFILE_SIDE:
			var weights := _terrain.biome_field.weights_at(
				origin_x + float(column) * profile_step,
				origin_z + float(row) * profile_step
			)
			density.append(coverage_for(weights))
			leaf.append(BiomeCatalog.blend(weights).tree_tint)

	# The clearing mask over the chunk, on a grid of its own. Arithmetic only --
	# no terrain query -- so this is the one field the layer can afford finely.
	var mask_step := TerrainChunkMesher.CHUNK_SIZE / float(MASK_SIDE - 1)
	var mask := PackedFloat32Array()
	for row in MASK_SIDE:
		for column in MASK_SIDE:
			mask.append(clearing_at(
				origin_x + float(column) * mask_step,
				origin_z + float(row) * mask_step,
				_world_seed
			))

	var field_step := TerrainChunkMesher.CHUNK_SIZE / float(FIELD_SIDE - 1)
	var water_level := PackedFloat32Array()
	var road := PackedFloat32Array()
	for row in FIELD_SIDE:
		for column in FIELD_SIDE:
			var x := origin_x + float(column) * field_step
			var z := origin_z + float(row) * field_step
			water_level.append(_terrain.water_surface_at(x, z))
			road.append(_terrain.path_strength_at(x, z))

	# Buildings are asked about per blade rather than on a grid, because a
	# reserved rectangle has a hard edge and interpolating across one would put
	# grass through a wall. Only where there is a village to ask about: almost
	# everywhere there is not, and the question is skipped entirely.
	var built_on := _settled_near(origin_x, origin_z)

	var cells := TerrainChunkMesher.CELLS
	var cell_size := TerrainChunkMesher.CELL_SIZE
	var salt_one := _world_seed ^ 0x6C7A55
	var salt_two := _world_seed ^ 0x33D9E7

	# Written by index into a buffer big enough for every candidate, and cut down
	# to what was actually grown at the end. Twenty floats an instance: twelve of
	# transform, four of colour, four of custom data.
	var transforms := PackedFloat32Array()
	transforms.resize(LATTICE * LATTICE * 20)
	var written := 0
	var kept := 0

	for at in _order():
		var cell_x := at % LATTICE
		var cell_z := at / LATTICE
		var lattice_x := geometry.chunk_x * LATTICE + cell_x
		var lattice_z := geometry.chunk_z * LATTICE + cell_z

		var h := ((lattice_x * 0x85EBCA6B) ^ (lattice_z * 0xC2B2AE35) ^ salt_one) & HASH_MASK
		h ^= h >> 16
		h = (h * 0x7FEB352D) & HASH_MASK
		h ^= h >> 15
		h = (h * 0x846CA68B) & HASH_MASK
		h ^= h >> 16

		var local_x := (float(cell_x) + 0.5
			+ (float((h >> 16) & 0xFF) / 255.0 - 0.5) * JITTER) * CELL
		var local_z := (float(cell_z) + 0.5
			+ (float((h >> 24) & 0xFF) / 255.0 - 0.5) * JITTER) * CELL

		# How much of the ground grows here: what the biome would carry, cut down
		# by the clearing mask, pushed through the curve. Both fields are
		# interpolated first and the curve applied afterwards -- the other way
		# round would smooth the curve back out and there would be no edge to a
		# bed at all.
		var pu := local_x / profile_step
		var pv := local_z / profile_step
		var pc := clampi(int(pu), 0, PROFILE_SIDE - 2)
		var pr := clampi(int(pv), 0, PROFILE_SIDE - 2)
		var pfu := pu - float(pc)
		var pfv := pv - float(pr)
		var here_cover := lerpf(
			lerpf(density[pr * PROFILE_SIDE + pc], density[pr * PROFILE_SIDE + pc + 1], pfu),
			lerpf(
				density[(pr + 1) * PROFILE_SIDE + pc],
				density[(pr + 1) * PROFILE_SIDE + pc + 1], pfu
			),
			pfv
		)
		var here_density := grown_share(
			_on_grid(mask, MASK_SIDE, local_x, local_z, mask_step), here_cover
		)

		var pick := float(h & 0xFFFF) / 65536.0
		if pick >= here_density:
			continue
		var here_road := _on_grid(road, FIELD_SIDE, local_x, local_z, field_step)
		if here_road > 0.0 and pick >= here_density * (1.0 - ROAD_THINNING * here_road):
			continue

		# The ground under the blade, read off the triangle it stands on. The
		# mesher's layout is fixed -- two triangles per cell, in row then column
		# order, three unshared vertices each -- so which triangle covers a point
		# is arithmetic rather than a search, and the answer is the drawn surface
		# itself rather than a second opinion about it.
		var across := local_x / cell_size
		var down := local_z / cell_size
		var column := clampi(int(across), 0, cells - 1)
		var row := clampi(int(down), 0, cells - 1)
		var fu := clampf(across - float(column), 0.0, 1.0)
		var fv := clampf(down - float(row), 0.0, 1.0)
		var half := 0
		var wa := 0.0
		var wb := 0.0
		var wc := 0.0
		if fu + fv <= 1.0:
			# Corners (0, 0), (1, 0), (0, 1).
			wa = 1.0 - fu - fv
			wb = fu
			wc = fv
		else:
			# Corners (1, 0), (1, 1), (0, 1).
			half = 1
			wa = 1.0 - fv
			wb = fu + fv - 1.0
			wc = 1.0 - fu
		var base := ((row * cells + column) * 2 + half) * 3

		var normal := geometry.normals[base]
		if normal.y < SLOPE_COS:
			continue
		var height := (
			geometry.vertices[base].y * wa
			+ geometry.vertices[base + 1].y * wb
			+ geometry.vertices[base + 2].y * wc
		)

		# How big this patch is has to be known before the ground under it is
		# judged, because a patch is metres wide and what has to clear the water
		# and miss the buildings is its edge rather than its middle. With one
		# tuft per instance the two were the same point and this hash came last.
		var g := ((lattice_x * 0x9E3779B1) ^ (lattice_z * 0x85EBCA77) ^ salt_two) & HASH_MASK
		g ^= g >> 16
		g = (g * 0x7FEB352D) & HASH_MASK
		g ^= g >> 15
		g = (g * 0x846CA68B) & HASH_MASK
		g ^= g >> 16

		var tall := lerpf(HEIGHT_MIN, HEIGHT_MAX, float(g & 0xFF) / 255.0)
		var spread := lerpf(SPREAD_MIN, SPREAD_MAX, float((g >> 8) & 0xFF) / 255.0)
		var yaw := float((g >> 16) & 0xFF) / 255.0 * TAU
		var scale_y := tall / _natural_height
		var scale_xz := scale_y * spread
		var turn_cos := cos(yaw) * scale_xz
		var turn_sin := sin(yaw) * scale_xz
		var reach := _patch_reach * scale_xz

		# The ground a patch sits on tilts, and the patch is laid along that
		# tilt (the shear below), so its downhill edge stands a slope's worth of
		# its reach lower than its middle. That edge is what has to clear the
		# water, not the middle -- otherwise a patch on a bank hangs its far
		# blades out over the pond.
		var lean_down := reach * sqrt(maxf(1.0 - normal.y * normal.y, 0.0)) \
			/ maxf(normal.y, 0.001)
		# Whether this is water is the ground the shell is drawing measured
		# against the water surface over it -- the same comparison the water
		# field makes, asked of the surface the blade would actually stand on.
		if height - lean_down < _on_grid(
			water_level, FIELD_SIDE, local_x, local_z, field_step
		) + FREEBOARD:
			continue
		var x := origin_x + local_x
		var z := origin_z + local_z
		# Widened by the patch's reach for the same reason: what must miss the
		# floor of a house is the whole patch, not the point it is pinned at.
		if built_on and _terrain.is_reserved_at(x, z, BUILDING_MARGIN + reach):
			continue

		var tint := _blade_tint(
			geometry.colors[base] * wa
			+ geometry.colors[base + 1] * wb
			+ geometry.colors[base + 2] * wc,
			_leaf_on_grid(leaf, local_x, local_z, profile_step)
		)

		# The middle row of the basis is a shear, not a rotation: the ground's
		# own gradient, so the patch's base plane lies along the slope while
		# every blade in it stays upright. A shear that depends only on x and z
		# leaves vertical lines vertical, which is exactly the difference
		# between grass growing out of a hillside and grass lying on it.
		var slide_x := -normal.x / maxf(normal.y, 0.001)
		var slide_z := -normal.z / maxf(normal.y, 0.001)

		transforms[written] = turn_cos
		transforms[written + 2] = turn_sin
		transforms[written + 3] = x
		transforms[written + 4] = slide_x * turn_cos - slide_z * turn_sin
		transforms[written + 5] = scale_y
		transforms[written + 6] = slide_x * turn_sin + slide_z * turn_cos
		transforms[written + 7] = height
		transforms[written + 8] = -turn_sin
		transforms[written + 10] = turn_cos
		transforms[written + 11] = z
		transforms[written + 12] = tint.r
		transforms[written + 13] = tint.g
		transforms[written + 14] = tint.b
		transforms[written + 15] = 1.0
		transforms[written + 16] = float((g >> 24) & 0xFF) / 255.0
		written += 20
		kept += 1

	if kept == 0:
		return null
	transforms.resize(written)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _mesh
	multimesh.instance_count = kept
	multimesh.buffer = transforms

	var view := MultiMeshInstance3D.new()
	view.name = "grass_%d_%d" % [geometry.chunk_x, geometry.chunk_z]
	view.multimesh = multimesh
	view.material_override = _material
	# Grass does not cast. Blades a third of a unit tall cast shadows a shadow
	# map stretched over 160 units cannot resolve, so what arrives is not shadows
	# but a shimmering stain; and the vertex shader moves every blade, which the
	# shadow pass would have to repeat. It still receives, which is what matters
	# -- grass under a tree is grass in shade.
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The engine works the bounds out from the instance transforms and knows
	# neither how wide a patch is nor that the wind moves it, so the box is
	# stated: the chunk, widened by how far a patch pinned at its edge reaches
	# outside it, and raised by the tallest copy in one.
	var margin := _patch_reach * (HEIGHT_MAX / _natural_height) * SPREAD_MAX + 1.0
	var lift := _patch_height * (HEIGHT_MAX / _natural_height) + 2.0
	view.custom_aabb = AABB(
		Vector3(origin_x - margin, geometry.lowest - 1.0, origin_z - margin),
		Vector3(
			TerrainChunkMesher.CHUNK_SIZE + margin * 2.0,
			geometry.highest - geometry.lowest + lift,
			TerrainChunkMesher.CHUNK_SIZE + margin * 2.0
		)
	)
	return view


## An island's grass, and the three things about an island that the ground layer
## has no way to ask.
##
## The rest of the layer is shared outright: the same patch mesh, the same
## material, the same lattice spacing, the same tint rule, the same level of
## detail. What changes is only what an island is.
##
## **Its cover is decided on its own lattice, not on the world's.** The two
## walkable storeys overlap in plan -- an upper island laps over the rim of the
## lower one, which is how you walk from one to the other -- so a position on the
## ground can have two islands over it. Hashed from world x and z, both storeys
## would grow the same patch of grass in the same place, one directly above the
## other. So a cell here is counted out from the island's own middle, and the
## hash takes the island's cell, its band and that local cell. That is the rule
## sim/island_cover.gd already scatters an island's flora on, applied to the
## grass, and tests/test_grass.gd shows it failing when world position is fed in
## instead.
##
## **It is one biome at full weight.** The ground blends across a border and this
## layer averages the coverage and the foliage colour over the blend; an island
## is a single chunk of land that broke off one place and carries that place's
## name, so the average is over one term and the coarse grid of biome samples the
## ground pays for collapses to two numbers taken once.
##
## **Its ground is a fan, not a grid.** The chunk mesher lays two triangles per
## square cell in a fixed order, so which triangle a blade stands on is
## arithmetic; the island mesher lays rings of triangles out from the middle, so
## it is not. The loop is therefore turned inside out -- walk the triangles the
## shell was handed and find the lattice cells over each one, rather than walk
## the lattice and hunt for the triangle -- which reads the same drawn surface
## the ground path reads and costs one pass over the geometry.
##
## What the clearing mask does here is settled and stated, and the answer is that
## **an island gets no clearing mask at all**. The reasoning is measured and is
## in reports/islands.md; the short version is that the mask is a field about the
## ground plane and its scales are larger than an island. A clearing is 76 units
## broad and the bare paths run on a lattice 48 units across, while an island is
## 27 to 65 units wide -- so a plate does not get a *texture* out of that field,
## it gets a *verdict*. Measured by tools/survey_island_grass.sh over the 81
## walkable islands within 600 units of the origin on seed 1234, reading the
## field in the island's own frame leaves 27 of them with under a seventh of
## their lattice grown, and reading it in the world's leaves 24; the two islands
## in reports/assets/islands-aerial-band.png come out at 0.000 and 0.029 of their
## lattice while the ground within the same 38 units grows a mean 0.403 of its
## own. A rule that leaves a third of all islands bare puts back exactly the
## flat-colour plate this layer exists to remove.
##
## So the density here is one number for the whole island: the biome's coverage
## through the same curve, which is what the ground reaches wherever its mask is
## open. Near the frame above that lands within a tenth of what the ground beside
## it is doing -- a highland island grows 0.456 of its plan area against the
## ground's 0.403. What an island has instead of a second field is its own shape:
## the slope gate below takes a fifth of every top, and takes it exactly on the
## risers of the terraces and the steep flanks, so the grass on a plate is banded
## by the plate's own relief rather than by a noise field it is too small to
## sample.

## How steep an island's top may be under grass, as the cosine of the angle from
## straight up.
##
## Looser than the ground's SLOPE_COS, and by exactly the amount the island cover
## is looser than the ground scatter -- IslandCover.SLOPE_LIMIT, the fall per
## unit walked that layer allows, converted to a cosine. The reason is the reason
## written there: an island is not a hillside. Its relief is half to three
## quarters of its radius, so measured against the ground's gate the ground's
## number keeps only 0.635 of an island's top by plan area, against 0.802 at this
## one -- the difference between an island dressed like the country it broke off
## and an island stripped bare down its every flank.
static var ISLAND_SLOPE_COS := 1.0 / sqrt(
	1.0 + IslandCover.SLOPE_LIMIT * IslandCover.SLOPE_LIMIT
)

## This layer's own corner of the seed space for islands, kept away from the
## ground's so that a plate and the chunk under it can never make the same roll.
const ISLAND_SALT := 0x4B19D7

## How many islands have ever had grass built for them. The cost measurement's
## divisor, and what the shell's stop line reports.
var islands_grown := 0

# One shuffle of the triangle indices per triangle count, computed once.
static var _island_orders := {}


## Grow the grass on one island, or null where nothing grows.
##
## `geometry` is the island's own copy of the same TerrainChunkGeometry the
## ground is made of -- the copy the shell was handed to draw -- and `island` is
## what the simulation knows about it. Nothing is written back to either.
func build_island(geometry: TerrainChunkGeometry, island: FloatingIsland) -> MultiMeshInstance3D:
	if not island.walkable:
		# A far-sky island is a silhouette hundreds of units off. Nothing on it
		# would ever be seen, and it is not ground.
		return null
	islands_grown += 1

	var reach := island.max_reach()
	var centre_x := island.centre_x
	var centre_z := island.centre_z
	var shares := {island.biome: 1.0}
	var here_cover := coverage_for(shares)
	var leaf := BiomeCatalog.blend(shares).tree_tint

	# The island's own corner of the seed space: its cell, its band, and the
	# world seed. Everything below hashes from this and from a *local* cell.
	var island_salt := _world_seed ^ ISLAND_SALT ^ SimRng.hash_ints(
		island.cell.x, island.cell.y, island.band
	)
	var salt_one := island_salt ^ 0x6C7A55
	var salt_two := island_salt ^ 0x33D9E7

	# How much of the island's lattice grows, as one number: no mask, so the
	# curve is crossed once here rather than once per candidate.
	var here_density := grown_share(1.0, here_cover)

	# Where the island's own pond could possibly reach, so that the pond is only
	# asked about where it might answer yes. It is asked exactly rather than off
	# a grid: a spillway is a channel a couple of units wide and a grid coarse
	# enough to be free would step straight over one, which showed up as patches
	# standing in the water. Outside this bound no call is made at all, which on
	# the minority of islands that hold a pond is most of the plate.
	var basin := island.has_basin()
	var spill := basin and island.has_spill()
	var spill_arc := island.spill_half_angle if spill else 0.0
	var pond_bound := 0.0
	if basin:
		# `ratio_at` divides by the outline in the blade's own direction, which
		# is never more than the island's furthest reach, so the bowl's lip can
		# never stand further out than this.
		pond_bound = island.basin_ratio * reach

	var steps := int(ceil(reach / CELL)) + 1
	var transforms := PackedFloat32Array()
	transforms.resize((steps * 2 + 1) * (steps * 2 + 1) * 20)
	var room := transforms.size()
	var written := 0
	var kept := 0

	# The triangles in a shuffled order, so that hiding a suffix of the instances
	# thins the whole island rather than clearing its outer rings. A triangle of
	# an island's top is a couple of units across and holds a handful of patches,
	# which is the granularity this buys; the ground shuffles one cell at a time
	# because it can afford to walk its lattice directly.
	for triangle in _island_order(geometry.triangle_count()):
		var base := triangle * 3
		var normal := geometry.normals[base]
		# The cliff at the rim faces outwards and the keel faces down, so the
		# same gate that keeps grass off a hillside keeps it on the top surface
		# and nowhere else. No knowledge of the mesher's layout is needed.
		if normal.y < ISLAND_SLOPE_COS:
			continue
		var a := geometry.vertices[base]
		var b := geometry.vertices[base + 1]
		var c := geometry.vertices[base + 2]
		# Barycentric coordinates in plan, set up once per triangle: the island's
		# top is single-valued over the disc, so a position is inside exactly one
		# of these.
		var area := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(area) < 0.000001:
			continue
		var inverse := 1.0 / area

		# Which cells of the island's own lattice this triangle can hold. The
		# jitter is under one cell wide, so a cell's blade always lands inside
		# that cell and the bounding box needs no margin.
		var low_x := floori((minf(a.x, minf(b.x, c.x)) - centre_x) / CELL)
		var high_x := floori((maxf(a.x, maxf(b.x, c.x)) - centre_x) / CELL)
		var low_z := floori((minf(a.z, minf(b.z, c.z)) - centre_z) / CELL)
		var high_z := floori((maxf(a.z, maxf(b.z, c.z)) - centre_z) / CELL)

		for cell_x in range(low_x, high_x + 1):
			for cell_z in range(low_z, high_z + 1):
				var h := ((cell_x * 0x85EBCA6B) ^ (cell_z * 0xC2B2AE35) ^ salt_one) & HASH_MASK
				h ^= h >> 16
				h = (h * 0x7FEB352D) & HASH_MASK
				h ^= h >> 15
				h = (h * 0x846CA68B) & HASH_MASK
				h ^= h >> 16

				var x := centre_x + (float(cell_x) + 0.5
					+ (float((h >> 16) & 0xFF) / 255.0 - 0.5) * JITTER) * CELL
				var z := centre_z + (float(cell_z) + 0.5
					+ (float((h >> 24) & 0xFF) / 255.0 - 0.5) * JITTER) * CELL

				var wa := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) * inverse
				if wa < 0.0:
					continue
				var wb := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) * inverse
				if wb < 0.0:
					continue
				var wc := 1.0 - wa - wb
				if wc < 0.0:
					continue

				var pick := float(h & 0xFFFF) / 65536.0
				if pick >= here_density:
					continue

				var height := (
					a.y * wa + b.y * wb + c.y * wc
				)
				# From here down this is the ground path's own block, on the same
				# numbers: a size and a turn from a second hash, the patch laid
				# along the slope by a shear, and twenty floats written by index.
				var g := ((cell_x * 0x9E3779B1) ^ (cell_z * 0x85EBCA77) ^ salt_two) & HASH_MASK
				g ^= g >> 16
				g = (g * 0x7FEB352D) & HASH_MASK
				g ^= g >> 15
				g = (g * 0x846CA68B) & HASH_MASK
				g ^= g >> 16

				var tall := lerpf(HEIGHT_MIN, HEIGHT_MAX, float(g & 0xFF) / 255.0)
				var spread := lerpf(SPREAD_MIN, SPREAD_MAX, float((g >> 8) & 0xFF) / 255.0)
				var yaw := float((g >> 16) & 0xFF) / 255.0 * TAU
				var scale_y := tall / _natural_height
				var scale_xz := scale_y * spread
				var turn_cos := cos(yaw) * scale_xz
				var turn_sin := sin(yaw) * scale_xz

				# The pond is a hole in the island's surface, exactly as a lake
				# is a hole in the ground, and what has to stay out of it is the
				# whole patch rather than the point it is pinned at -- which is
				# why the size above is worked out first. Asked only where the
				# bowl or its spillway could possibly reach.
				if basin:
					var away_x := x - centre_x
					var away_z := z - centre_z
					var far := away_x * away_x + away_z * away_z
					var edge := _patch_reach * scale_xz
					var bound := pond_bound + edge
					var ask := far <= bound * bound
					if not ask and spill:
						# Beyond the bowl only the channel's own wedge of
						# directions can be wet.
						ask = absf(angle_difference(
							atan2(away_z, away_x), island.spill_angle
						)) <= spill_arc + atan2(edge, maxf(sqrt(far), 0.001))
					if ask and _pond_covers(island, x, z, edge):
						continue

				var tint := _blade_tint(
					geometry.colors[base] * wa
					+ geometry.colors[base + 1] * wb
					+ geometry.colors[base + 2] * wc,
					leaf
				)
				var slide_x := -normal.x / maxf(normal.y, 0.001)
				var slide_z := -normal.z / maxf(normal.y, 0.001)

				if written + 20 > room:
					continue
				transforms[written] = turn_cos
				transforms[written + 2] = turn_sin
				transforms[written + 3] = x
				transforms[written + 4] = slide_x * turn_cos - slide_z * turn_sin
				transforms[written + 5] = scale_y
				transforms[written + 6] = slide_x * turn_sin + slide_z * turn_cos
				transforms[written + 7] = height
				transforms[written + 8] = -turn_sin
				transforms[written + 10] = turn_cos
				transforms[written + 11] = z
				transforms[written + 12] = tint.r
				transforms[written + 13] = tint.g
				transforms[written + 14] = tint.b
				transforms[written + 15] = 1.0
				transforms[written + 16] = float((g >> 24) & 0xFF) / 255.0
				written += 20
				kept += 1

	if kept == 0:
		return null
	transforms.resize(written)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _mesh
	multimesh.instance_count = kept
	multimesh.buffer = transforms

	var view := MultiMeshInstance3D.new()
	view.name = "grass"
	view.multimesh = multimesh
	view.material_override = _material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var margin := _patch_reach * (HEIGHT_MAX / _natural_height) * SPREAD_MAX + 1.0
	var lift := _patch_height * (HEIGHT_MAX / _natural_height) + 2.0
	view.custom_aabb = AABB(
		Vector3(centre_x - reach - margin, geometry.lowest - 1.0, centre_z - reach - margin),
		Vector3(
			(reach + margin) * 2.0,
			geometry.highest - geometry.lowest + lift,
			(reach + margin) * 2.0
		)
	)
	return view


## Whether an island's own pond covers a patch pinned here and reaching `edge`
## units out from that pin.
##
## The middle and four points at the patch's own reach, which is IslandCover's
## rule for what stands clear of a basin applied to a thing that is metres
## across: the shore of a pond is soft ground and the whole patch has to be off
## it, not just the point it hangs from.
func _pond_covers(island: FloatingIsland, x: float, z: float, edge: float) -> bool:
	if island.holds_water_at(x, z):
		return true
	for step in 4:
		var angle := TAU * float(step) / 4.0
		if island.holds_water_at(x + cos(angle) * edge, z + sin(angle) * edge):
			return true
	return false


## The order an island's triangles are walked in: every one exactly once,
## shuffled by a hash of its index, cached per triangle count.
##
## The ground's `_order` shuffles one fixed lattice; an island's fan has as many
## triangles as its rings and sectors give it, and two islands with the same
## count share the shuffle. Nothing but the level of detail depends on it.
static func _island_order(count: int) -> PackedInt32Array:
	if _island_orders.has(count):
		return _island_orders[count]
	var order := PackedInt32Array()
	order.resize(count)
	for at in count:
		order[at] = at
	for at in range(count - 1, 0, -1):
		var pick := SimRng.hash_ints(at, count, 0x15A4D) % (at + 1)
		var swap := order[at]
		order[at] = order[pick]
		order[pick] = swap
	_island_orders[count] = order
	return order


## Tell the shader where the view is centred and who is walking through the
## grass. One write for the whole world, because every chunk shares the material.
func look_from(focus: Vector2, walkers: Array[Vector3]) -> void:
	_material.set_shader_parameter("focus", focus)
	var slots: Array[Plane] = []
	for at in WALKERS:
		if at < walkers.size():
			var walker: Vector3 = walkers[at]
			slots.append(Plane(walker.x, walker.y, walker.z, WALKER_REACH))
		else:
			slots.append(Plane(0.0, 0.0, 0.0, 0.0))
	_material.set_shader_parameter("walkers", slots)


## Draw fewer of a chunk's tufts the further away it is. Changing the count is a
## single property write -- no rebuild, no new buffer -- which is the whole
## reason the level of detail is done this way round.
func set_detail(view: MultiMeshInstance3D, distance: float) -> void:
	var multimesh := view.multimesh
	var wanted := int(round(float(multimesh.instance_count) * visible_share(distance)))
	wanted = clampi(wanted, 0, multimesh.instance_count)
	if multimesh.visible_instance_count != wanted:
		multimesh.visible_instance_count = wanted


## How many tufts one built chunk holds, and how many of them are being drawn.
static func counts_of(view: MultiMeshInstance3D) -> Vector2i:
	var multimesh := view.multimesh
	var shown := multimesh.visible_instance_count
	if shown < 0:
		shown = multimesh.instance_count
	return Vector2i(multimesh.instance_count, shown)


## The colour of a blade standing on ground of a given colour under foliage of a
## given colour, as a share of the most the tint may brighten a channel.
##
## Stored as a share rather than as the multiplier itself so that the instance
## buffer never has to hold a number above one. The multiplier is the same rule
## the pack models follow: the colour wanted divided by the colour the art
## already reads as, so the tuft's own light and shade survive being tinted. The
## division is done in linear light because that is where the shader multiplies
## it back onto a texture the sampler has already converted.
func _blade_tint(ground: Color, foliage: Color) -> Color:
	var wanted := ground.lerp(foliage, leaf_mix).srgb_to_linear()
	var base := _reference.srgb_to_linear()
	return Color(
		clampf(wanted.r / maxf(base.r, 0.0005), 0.0, MAX_GAIN) / MAX_GAIN,
		clampf(wanted.g / maxf(base.g, 0.0005), 0.0, MAX_GAIN) / MAX_GAIN,
		clampf(wanted.b / maxf(base.b, 0.0005), 0.0, MAX_GAIN) / MAX_GAIN,
	)


## Bilinear lookup into one of the coarse grids sampled over the chunk.
func _on_grid(
	grid: PackedFloat32Array, side: int, local_x: float, local_z: float, step: float
) -> float:
	var across := clampf(local_x / step, 0.0, float(side - 1) - 0.0001)
	var down := clampf(local_z / step, 0.0, float(side - 1) - 0.0001)
	var column := int(across)
	var row := int(down)
	var fu := across - float(column)
	var fv := down - float(row)
	var top := lerpf(grid[row * side + column], grid[row * side + column + 1], fu)
	var bottom := lerpf(
		grid[(row + 1) * side + column], grid[(row + 1) * side + column + 1], fu
	)
	return lerpf(top, bottom, fv)


## The same, for the grid of foliage colours.
func _leaf_on_grid(
	grid: PackedColorArray, local_x: float, local_z: float, step: float
) -> Color:
	var side := PROFILE_SIDE
	var across := clampf(local_x / step, 0.0, float(side - 1) - 0.0001)
	var down := clampf(local_z / step, 0.0, float(side - 1) - 0.0001)
	var column := int(across)
	var row := int(down)
	var fu := across - float(column)
	var fv := down - float(row)
	var top := grid[row * side + column].lerp(grid[row * side + column + 1], fu)
	var bottom := grid[(row + 1) * side + column].lerp(
		grid[(row + 1) * side + column + 1], fu
	)
	return top.lerp(bottom, fv)


## Whether any village pad reaches this chunk, so that the per-blade building
## question is worth asking at all. Sampled at the corners and the middle,
## widened by the margin, which is what a pad has to miss all of to be absent.
func _settled_near(origin_x: float, origin_z: float) -> bool:
	var size := TerrainChunkMesher.CHUNK_SIZE
	for offset in [
		Vector2(0.0, 0.0), Vector2(size, 0.0), Vector2(0.0, size), Vector2(size, size),
		Vector2(size * 0.5, size * 0.5),
	]:
		if _terrain.settlement_at(origin_x + offset.x, origin_z + offset.y) != null:
			return true
	return false


## The order the candidate cells are walked in: every cell exactly once, shuffled
## by a hash of its index. Built once for the process, and identical in every
## chunk, so that hiding the last half of a chunk's instances hides half of every
## part of it rather than half of the field.
static func _order() -> PackedInt32Array:
	if _walk_order.size() == LATTICE * LATTICE:
		return _walk_order
	var indices: Array[int] = []
	for at in LATTICE * LATTICE:
		indices.append(at)
	indices.sort_custom(func(left: int, right: int) -> bool:
		var a := SimRng.hash_ints(left, 0x5EED, 0)
		var b := SimRng.hash_ints(right, 0x5EED, 0)
		if a != b:
			return a < b
		return left < right)
	_walk_order = PackedInt32Array(indices)
	return _walk_order


func _clear_walkers() -> void:
	var slots: Array[Plane] = []
	for _at in WALKERS:
		slots.append(Plane(0.0, 0.0, 0.0, 0.0))
	_material.set_shader_parameter("walkers", slots)
