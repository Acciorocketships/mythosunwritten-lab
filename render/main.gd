extends Node3D
## The engine shell: it renders the simulation and takes input. It is deliberately
## thin -- it owns no world state of its own, and every frame it just reads a
## snapshot and moves visuals to match. Deleting this whole directory would leave
## the simulation fully runnable.
##
## The terrain it draws is not generated here. The simulation's field, mesher and
## streamer decide what ground exists and what shape it is; this file only asks
## the streamer for the geometry of the chunks the snapshot says are loaded, and
## hands those numbers to the graphics card. What comes back from that ask is a
## detached copy of the chunk, so nothing done to it here -- deliberately or by
## accident -- can reach the ground the simulation is standing on.
##
## The floating islands are not generated here either. The simulation streams
## them one island at a time, exactly as it streams the ground in chunks, and
## hands over the same kind of geometry -- so an island becomes a drawable
## through the very same code a chunk does. The far-sky ones drift, and even that
## is not decided here: how far and how fast each one wanders is placement data
## the simulation hashed out of the island's cell, and this file only turns the
## clock. The islands anyone can stand on do not move at all.
##
## The water is not generated here either, and it is not drawn per chunk. The
## simulation builds one sheet over a wide window of the world, on a lattice
## fixed to the world origin, and this file turns that one sheet into one
## drawable with one animated material. There is no tile boundary anywhere in it
## for a seam to show on, and the ripples are a function of world position, so
## they do not restart when the sheet is rebuilt around a moving viewer.
##
## The grass is the one layer that *is* built here, and that is a decision with a
## reason: nothing in the world can interact with a blade of grass, so it is a
## property of the picture rather than of the place. It is instanced per chunk
## out of the ground the simulation handed over, animated by a wind shader, and
## bent aside by wherever the characters are standing -- and a headless process,
## which never loads a single file of this directory, therefore creates none of
## it at all. reports/grass.md is the write-up.
##
## The colours are not decided here either. Every chunk arrives with a ground
## tint per vertex, blended by the simulation from whichever biomes have a share
## of that corner, and the fog, sky and ambient light are read each frame off the
## blended biome profile where the observer is standing. This file chooses none
## of those values -- it only decides which knob each one is turned into. Walk
## across a biome border and the mood shifts because the simulation says it does.
##
## How the world is *lit* is not here either, and for the same reason the grass
## is not in the simulation: render/atmosphere.gd owns the key light and its long
## soft shadows, the sky, the fog and the ground mist, the warm-neutral fill, the
## bloom, the miniature depth of field, the warm point lights on every glowing
## tag, the wandering of the twilight orbs, and the drifting motes. It is one
## layer with one switch -- `--no-atmosphere` draws the identical world with none
## of it -- and reports/atmosphere.md is the write-up.
##
## Run it with:  ./run_render.sh --seed 1234

const DEFAULT_SEED := 1234

## Simulation ticks per second. Fixed, so the sim advances at the same rate no
## matter what frame rate the renderer manages.
const TICKS_PER_SECOND := 20.0

## Which character the observer is drawn as.
##
## One line, because that is what the character scene's shape is for: the model
## is a swappable child, so changing which adventurer walks the world is
## changing this tag and nothing else -- not the animation setup, not the clip
## library, not one line of the simulation, which has never heard of any of them.
const OBSERVER_TAG := AssetTags.RANGER

## Where the camera sits relative to the observer: behind, above, looking down.
const CAMERA_OFFSET := Vector3(0.0, 42.0, 52.0)

## How far above the observer the camera aims.
##
## Aiming straight at the observer's feet from forty units up puts the top edge
## of the frame below the horizon, so the sky is never actually in shot -- which
## does not matter while everything worth seeing is on the ground, and matters a
## great deal once there are islands in the air. Lifting the aim by this much
## tilts the view up by about eight degrees: enough for the horizon, the sky
## gradient and the far-sky band to be in frame, and not so much that the
## diorama stops being looked down on.
const CAMERA_AIM_LIFT := 10.0

## How far the camera can see. Far enough for the far-sky islands, which are
## streamed out to several hundred units because they are the horizon.
const CAMERA_FAR := 900.0

## How far the board overlay is lifted off the ground it describes, in world
## units, so its quads do not fight the terrain for the same pixels.
##
## Re-chosen now that a square follows the surface instead of lying flat across
## it. When a cell was one flat quad the lift was fighting the cell's own relief
## -- 0.34 units of it on average over a hillside board, 1.93 at worst -- which
## no lift that small was ever going to win, and 0.09 was a compromise between
## hovering and sinking. All that is left to clear now is the ground *mesh's*
## own faceting: the overlay samples the height function, the ground is that
## function read on a 2-unit lattice and joined by flat triangles, and where the
## ground is convex the triangle cuts the corner and stands above the function by
## 0.008 units on average. 0.045 clears all but 0.54% of the painted area of a
## hillside board; going on to 0.09 buys the last half a percent and costs twice
## as much hover. See reports/board-overlay.md and tools/measure_overlay.sh.
const BOARD_LIFT := 0.045

## How many times a cell is cut in each direction before it is drawn: a cell
## comes out as this many quads across and this many deep, with the terrain
## sampled afresh at every one of their corners.
##
## Chosen against the ground it lies on rather than by taste. A painted square is
## 2.58 units across, and the ground under it is meshed at 2.0-unit cells, so at
## 2 the square's own steps are 1.29 units -- already finer than the ground it is
## lying on, and there is no detail below that for a finer square to find. The
## measured gap between the drawn square and the ground agrees: one flat quad per
## cell sits 0.340 units off the surface on average, cutting in uphill and
## floating downhill; 2 brings that to 0.0045, and 3 to 0.0020 for 1.95x the
## vertices. A board is 17 640 vertices at 2 against 2 646 flat, and rebuilding
## the 21 cells one step of walking exposes costs 34-43 ms against the 68-96 ms
## the board read itself already costs. See tools/measure_overlay.sh.
const BOARD_CUTS := 2

## How much of a cell the filled quad covers, leaving a gutter between cells so
## the lattice reads as squares rather than as one sheet.
const BOARD_FILL := 0.86

## How far above its cell a piece of the fight is drawn, in world units. Nothing:
## the models are drawn with their feet at their own origin, and a cell's height
## is the surface a piece stands on. It is named so the number is a decision
## rather than an omission.
const PIECE_LIFT := 0.0

## What each kind of cell is drawn in. Cool white for ground a piece may stand
## on, a paler cool tint one storey up, warm amber for a cliff edge it can be
## shoved off, dull red for something built on, and a dark plate at the anchor's
## own height for a hole -- water, or the void off an island's rim -- so a hole
## reads as a missing square rather than as nothing at all.
const BOARD_GROUND := Color(0.86, 0.94, 1.0, 0.20)
const BOARD_AERIAL := Color(0.62, 0.92, 0.86, 0.34)
const BOARD_CLIFF := Color(1.0, 0.66, 0.26, 0.52)
const BOARD_BUILT := Color(0.92, 0.36, 0.36, 0.5)
const BOARD_HOLE := Color(0.05, 0.07, 0.12, 0.44)

## The colour a traced route is drawn in, and how far above the ground it floats.
##
## Warm amber against cool ground, which is the palette's own contrast and the
## only colour on screen that nothing in the world is. It exists so that a route
## found headless by tools/measure_mountains.sh can be photographed on the
## mountain it climbs; it draws a line and changes nothing else, so the world's
## fingerprint is the same with it and without it.
const TRACE_TINT := Color(1.0, 0.72, 0.28, 1.0)
const TRACE_LIFT := 0.55
const TRACE_HALF_WIDTH := 1.30

## The water's look, as a shader.
##
## Every animated quantity is a function of *world* position and time, never of
## anything belonging to the sheet or to a tile of it. That is what makes the
## surface seamless in motion as well as in shape: the ripples belong to the
## world, so rebuilding the sheet around a walking viewer does not shift them,
## and two stretches of the same river are two windows onto one moving surface
## rather than two animations that happen to be side by side.
##
## The colour is the simulation's: it arrives per vertex, blended from the
## biomes at that position, with the depth in the alpha so a shore fades out.
## This only turns it into light.
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

// How tight the ripples are. At 0.8 the longest swell is about eight world
// units across and the finest about two -- ripples you could step over, on the
// scale of a world whose chunks are sixteen units wide.
uniform float wave_scale = 0.8;
uniform float wave_speed = 1.1;
uniform float wave_slope = 0.30;
uniform float sparkle = 0.05;

// The world drawn again upside down, by render/water_reflection.gd, and how
// much of it the water shows. `reflection_amount` at zero is the whole of
// switching the mirror off: the sampler is then never read and the water is
// exactly the surface it was before there was a reflection.
//
// `source_color` because what arrives is a rendered frame in display colours
// and the shader works in linear light -- the same conversion the vertex tint
// gets by hand below, done here by the sampler.
uniform sampler2D reflection_map : source_color, filter_linear, repeat_disable;
uniform float reflection_amount = 0.0;
// In screen widths, so it has to be small: the swells run to about one either
// way, and at 0.055 a reflected roof was dragged sixty pixels sideways and
// arrived as a smear.
uniform float reflection_warp = 0.012;
uniform float reflection_floor = 0.40;
uniform float reflection_tint = 0.12;
uniform float reflection_ceiling = 0.72;

varying vec3 world_position;
varying vec4 tint;

// Four crossing swells, each running in its own direction at its own speed and
// wavelength, none of them a multiple of another. Axis-aligned waves would show
// as a grid of highlights; these do not line up into a pattern at any scale a
// viewer sees.
float swell(vec2 p, float t) {
	return sin(dot(p, vec2(0.93, 0.37)) * 1.00 + t * 1.00) * 0.50
		+ sin(dot(p, vec2(-0.44, 0.90)) * 1.53 - t * 1.27) * 0.30
		+ sin(dot(p, vec2(0.71, -0.71)) * 2.31 + t * 0.71) * 0.15
		+ sin(dot(p, vec2(0.15, 0.99)) * 3.77 - t * 1.90) * 0.08;
}

// The vertex colours are ordinary colours, the same numbers a painter would
// name; the renderer works in linear light. The ground says so with a material
// flag, and this is the same conversion by hand.
vec3 to_linear(vec3 c) {
	return mix(
		pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4)),
		c / vec3(12.92),
		lessThan(c, vec3(0.04045))
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR;
}

void fragment() {
	vec2 p = world_position.xz * wave_scale;
	float t = TIME * wave_speed;
	float step_size = 0.35;
	float here = swell(p, t);
	float along_x = swell(p + vec2(step_size, 0.0), t);
	float along_z = swell(p + vec2(0.0, step_size), t);

	vec3 ripple = normalize(vec3(
		-(along_x - here) * wave_slope, 1.0, -(along_z - here) * wave_slope
	));
	NORMAL = normalize((VIEW_MATRIX * vec4(ripple, 0.0)).xyz);

	vec3 colour = to_linear(tint.rgb);
	vec3 surface = colour * (0.96 + 0.07 * here);
	float alpha = clamp(tint.a * (0.92 + 0.12 * here), 0.0, 1.0);
	float mirror_strength = 0.0;

	if (reflection_amount > 0.0) {
		// Where on the mirrored frame this fragment is. The mirror camera is
		// aimed with look_at rather than built by reflecting a basis -- see
		// render/water_reflection.gd -- which draws the world the right way up
		// and the wrong way round, so the horizontal lookup is flipped back
		// here. The ripple's own slope then warps it, which is what makes a
		// reflected window wobble rather than sit there like a decal.
		vec2 mirror_uv = vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y);
		mirror_uv += vec2(along_x - here, along_z - here) * reflection_warp;
		vec3 mirrored = texture(reflection_map, clamp(mirror_uv, 0.002, 0.998)).rgb;
		// Pulled part of the way towards the water's own colour. A perfect
		// mirror is not what this water is: it is a stylised pond with a biome
		// tint, and an untinted mirror throws that tint away and hands back a
		// white sky. `colour` is doubled first because the tint is a mid-tone
		// and multiplying by it unchanged would darken everything it touched.
		mirrored *= mix(vec3(1.0), colour * 2.0, reflection_tint);
		// And held below full brightness, hue intact. The mirror is a rendered
		// frame with its own bloom already in it, so the sun's disc arrives as
		// a saturated white blob; laid on the water at full strength it is a
		// hole in the picture rather than a highlight. Scaling the whole colour
		// by one factor rather than clamping each channel keeps a warm window
		// warm while it comes down.
		float brightest = max(mirrored.r, max(mirrored.g, mirrored.b));
		if (brightest > reflection_ceiling) {
			mirrored *= reflection_ceiling / brightest;
		}

		// Fresnel: a surface seen edge-on is a mirror and one seen from
		// overhead is not, which is why a pond reflects the far bank and not
		// the ground under it. The floor keeps a little reflection straight
		// down, because stylised water reads as dead without it.
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		float grazing = pow(1.0 - facing, 3.0);
		// Scaled by the water's own alpha, which is its depth. A shore fades
		// out because there is barely any water there, and a mirror that did
		// not fade with it would lay a film of sky over the last few
		// centimetres of wet sand and read as the sheet overlapping the bank.
		float mirror = reflection_amount * mix(reflection_floor, 1.0, grazing)
			* clamp(tint.a, 0.0, 1.0);
		mirror_strength = mirror;
		surface = mix(surface, mirrored, mirror);
		// A mirror is opaque where it mirrors. Without this a bright reflected
		// window on shallow water is half a window, because the shore's own
		// fade-out is showing the bed through it. Scaled by the same alpha, so
		// that where there is no water there is still no water.
		alpha = clamp(mix(alpha, 1.0, mirror * alpha * 0.6), 0.0, 1.0);
	}

	ALBEDO = surface;
	ALPHA = alpha;
	EMISSION = colour * sparkle * max(0.0, here);
	ROUGHNESS = 0.30;
	METALLIC = 0.0;
	// Turned down where the mirror is doing the work. The analytic highlight is
	// the renderer's guess at the reflection of the key light; where there is a
	// real reflection it is already in `mirrored`, and leaving both on counts
	// the sun twice and burns a white hole in the water.
	SPECULAR = mix(0.55, 0.12, mirror_strength);
}
"""

## The waterfall's look, as a shader.
##
## Exactly the split the ripples already use, and for the same reason. The
## simulation decided that this island's basin overflows, where on its rim the
## water leaves, how wide the fall is and how far it drops -- all of that is in
## the island's own numbers and reproduces across processes. What is *not* in
## them is that the water is moving, because nothing about the world depends on
## it: this shader scrolls a set of streaks downwards and fades the bottom into
## nothing, and if it were deleted the island, its pond and the terrain query's
## answers would all be unchanged.
##
## The streaks run in the sheet's own coordinates rather than in world space,
## which is the one place this differs from the ripples: a fall is a narrow
## vertical thing and the streaks have to run down *it*, not down the world.
const FALL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 fall_tint : source_color = vec4(0.72, 0.86, 0.94, 0.75);
uniform float fall_speed = 1.9;
uniform float fall_streaks = 9.0;

varying vec2 sheet;

// Where on the fall this fragment is: x across it, y down it, both in [0, 1].
// The mesh is built with those in its UVs, so the shader never has to know how
// long the fall is or which way it faces.
void vertex() {
	sheet = UV;
}

float streak(vec2 p, float t) {
	float across = p.x * fall_streaks;
	float lane = floor(across);
	float phase = fract(p.y * 1.7 + t + sin(lane * 12.9898) * 0.5);
	return 0.55 + 0.45 * sin(phase * 6.2831853 * 2.0);
}

void fragment() {
	float t = TIME * fall_speed;
	float lit = streak(sheet, t) * (0.75 + 0.35 * sin(sheet.y * 24.0 - t * 4.0));
	// Bright where it leaves the rim, breaking into spray and then into nothing
	// on the way down; narrower at the bottom, so the fall reads as a plume.
	float down = 1.0 - smoothstep(0.35, 1.0, sheet.y);
	float across = 1.0 - smoothstep(0.5 - 0.5 * sheet.y, 1.0, abs(sheet.x - 0.5) * 2.0);
	ALBEDO = fall_tint.rgb * (0.85 + 0.4 * lit);
	EMISSION = fall_tint.rgb * 0.25 * lit;
	ALPHA = clamp(fall_tint.a * lit * down * across, 0.0, 1.0);
}
"""

var _sim: Simulation = null
var _paused := false
var _accumulator := 0.0
var _frames := 0
var _camera: Camera3D = null
var _observer_view: Node3D = null

## How long the last drawn frame took, in seconds. The character's cross-fades
## are paced by it: the simulation steps twenty times a second and this draws as
## fast as it can, so a blend measured in ticks would run at whatever speed the
## machine happens to manage.
var _last_delta := 0.0
var _terrain_material: StandardMaterial3D = null
var _water_view: MeshInstance3D = null
var _water_material: ShaderMaterial = null
## The waterfalls' material. One instance shared by every fall on screen, so
## they all run off the same clock -- and so a fall that streams in mid-flight
## does not start its animation from the beginning.
var _fall_material: ShaderMaterial = null
## The version of the water sheet currently on screen. The simulation counts its
## rebuilds, so comparing counters is how this asks for the water again only
## when there is new water, rather than once a frame.
var _water_sheet_version := -1
## The world drawn a second time upside down so the water can mirror it, or null
## when the run was started with --no-reflection. Null is the whole of turning it
## off: no second viewport, no second camera, and the water shader's mirror
## strength left at zero, which is the branch it never takes.
var _reflection: WaterReflection = null
## How much of the mirror the water shows, when there is one. Set once, on the
## one material every stretch of water on screen shares.
const REFLECTION_AMOUNT := 1.0
## The lighting and atmosphere stack, or null when the run was started with
## --no-atmosphere. Null is the whole of turning it off: no environment, no key
## light, no bloom, no depth of field, no warm point lights, no motes.
var _atmosphere: Atmosphere = null

# Chunk coordinate (Vector2i) -> the node drawing it. One entry per loaded chunk.
var _chunk_views := {}

## The ground past the streamed chunks, drawn at a cell that doubles with the
## level, or null when the run was started with --no-distant-ground. Null is the
## whole of turning it off: no tile, no sample, no drawable, and the picture is
## the forty-unit disc it was before.
var _distant: DistantGround = null

# Vector3i(level, tile_x, tile_z) -> {view, sig, triangles}: the node drawing one
# coarse tile, the signature of the cells it was built to emit, and how many
# triangles that came to. A tile is rebuilt only when its signature changes,
# which happens when the ground it is standing in for is meshed at a finer level.
var _distant_views := {}

# The snapshot the last sync read, kept only so that a paused run can go on
# filling in the distance from it. Nothing else reads it.
var _last_snapshot := {}

## How many coarse tiles and triangles are on screen, and how long the last
## batch of tile building took. Reported on the stop line, which is how the cost
## measurement and the tests read them without a screen to look at.
var _distant_tiles := 0
var _distant_triangles := 0
var _distant_build_usec := 0

## Where the coarse rings are centred, when a capture wants them somewhere other
## than under the observer, and whether that override is on.
##
## Walking is what normally moves the rings, and it moves the camera with them,
## so a frame before and a frame after are two different views and cannot be
## compared. This holds the camera still and moves the rings instead: the same
## ground, meshed at a different level, from the same place. It is only ever used
## to photograph a boundary; see reports/terrain-lod.md.
var _lod_centre := Vector2.ZERO
var _lod_centre_set := false

## Whether each coarse level is drawn in its own tint, so a capture can show
## where the boundaries between them actually are. A diagnostic overlay, like the
## tactical lattice: it changes the colours and nothing else.
var _lod_levels := false

## The tint each level is washed with under --lod-levels, coarsest last.
const LOD_LEVEL_TINTS := [
	Color(0.55, 1.00, 0.55),
	Color(1.00, 0.92, 0.45),
	Color(1.00, 0.60, 0.40),
	Color(0.70, 0.65, 1.00),
	Color(1.00, 0.45, 0.85),
]

## How long a frame may spend building coarse tiles.
##
## The whole ring is about 1.4 seconds of work on this machine and it is all
## paid in the first second of a run, so it is spread over frames rather than
## taken as one stall: at this budget the view fills out from the observer
## outwards over about fifty frames and is complete well before a capture at
## frame 140. Afterwards it is almost never reached -- walking only ever adds
## the few tiles the rings have moved onto, and rebuilding a tile whose boundary
## has shifted re-uses every corner it already sampled.
const DISTANT_BUDGET_USEC := 40000

# Island key (Vector3i) -> the node drawing it. One entry per loaded island.
var _island_views := {}

# Settlement cell (Vector2i) -> the node drawing that village, and road name
# (String) -> the node drawing that road's bridges and lamps. One entry each per
# loaded village and road.
var _settlement_views := {}
var _road_views := {}

# Chunk coordinate (Vector2i) -> the node drawing everything the scatter layer
# put on that chunk. One entry per loaded patch.
var _scatter_views := {}

# Chunk coordinate (Vector2i) -> the one drawable holding that chunk's grass.
# A smaller set than the chunks: grass is built over a shorter radius than the
# ground it stands on.
var _grass_views := {}

# Island key (Vector3i) -> {view, at}: the drawable holding that island's grass
# and where its middle is, for the level of detail. The view itself hangs off the
# island's own node, so dropping the island drops its grass with it; this is only
# the handle the per-frame detail pass needs, and it is pruned alongside
# _island_views.
var _island_grass := {}

## The grass layer, or null when the run was started with --no-grass. Null is the
## whole of turning it off: no material, no baked mesh, no drawable, nothing.
var _grass: GrassLayer = null

## How many tufts are loaded and how many are being drawn, reported on the stop
## line so a test can tell a run with grass from a run without one.
var _grass_blades := 0
var _grass_drawn := 0

# The far-sky islands that drift, as {view, island}. Kept as its own list so the
# per-frame drift does not have to walk every island to find the few that move.
var _drifting := []

## From which frame onwards the frame time is averaged, and what has been
## averaged so far. Reported on the stop line, which is how a cost measurement
## reads it without a screen to look at.
const TIMED_FROM_FRAME := 90
var _timed_seconds := 0.0
var _timed_frames := 0

## How many chunk views have ever been built, including ones since dropped. One
## per chunk handed over, so it is also the number of copies this shell has asked
## the simulation for -- reported at exit next to the frame count, which is how a
## test can see that the copying does not repeat per frame.
var _chunk_views_built := 0

## The tactical lattice drawn over the ground, or null when it is switched off.
## One drawable for the whole board: a filled quad per cell and an outline round
## each, rebuilt only when the observer walks into a different cell.
## The route read off a trace file, as world positions, and the ribbon drawn
## along it. Empty unless --trace named a file.
var _trace: PackedVector3Array = PackedVector3Array()
var _trace_view: MeshInstance3D = null

var _board_view: MeshInstance3D = null
var _board_material: StandardMaterial3D = null
var _board_cell := Vector2i(2147483647, 2147483647)
var _board_lifted := false
## The sampled surface under each cell of the drawn board, keyed by the cell and
## the storey it was read on, so that walking one cell along re-samples the one
## new column rather than the whole board.
##
## Sound because the lattice is fixed to the world and the terrain does not move:
## a cell's sub-vertex heights are a function of the cell, the storey and the
## seed, so a height once read is a height for good. Bounded because every
## rebuild keeps only what the board it just drew asked for.
var _board_surface := {}
## Where the drawn board reaches in world x and z, and the middle and the spread
## of the heights it lies at. Handed to the grass every frame so the grass over
## its squares gives way; an empty rectangle means there is no board.
var _board_reach := Rect2()
var _board_level := 0.0
var _board_relief := 0.0
## How many cells the drawn board last had, and how many of them were holes.
## Printed on the stop line so a capture can be told apart from a run without
## the overlay without needing a screen to look at.
var _board_cells := 0
var _board_holes := 0
## Which board the lattice overlay was last drawn for, so it is rebuilt when the
## fight puts a different one under it.
var _board_fight := -1

## One drawable per combatant the snapshot lists, keyed by the simulation's id.
##
## View bookkeeping and nothing else: which node stands for which id, in the same
## way _chunk_views records which node stands for which chunk. Every value drawn
## into these nodes -- position, turn, clip -- is read off the snapshot on the
## frame it is drawn, so throwing this dictionary away and rebuilding it from the
## same snapshot draws the identical picture. There is no board here, no match,
## no hit points and no position of this layer's own.
var _piece_views := {}
var _pieces_drawn := 0

## The interface, when --sheet or --readout asked for one: one CanvasLayer at a
## whole-number scale holding the character sheet, the combat readout, or both.
## Null in every run that asked for neither, and in a run where the Sprout Lands
## pack has not been unpacked.
##
## It owns no fact about any character and none about any fight. The sheet is
## handed the simulation's own `Character` objects and the readout the world
## itself, and both read every number off those on every frame; there is no copy
## of a score, a level, an inventory, a turn order or a cooldown anywhere on this
## side of the line. render/ui/ is the whole of the interface and
## bin/check_layers.gd covers it.
var _sheet_ui: PixelUi = null

var _screenshot_path := ""
var _screenshot_frame := 0
var _screenshot_tick := 0
## Where the camera sits and what it aims at, in the same terms as CAMERA_OFFSET
## and CAMERA_AIM_LIFT. Those two are the view the game is played from; these
## are what a capture for a report may move it to, and nothing else ever changes
## them. Moving the camera changes the picture and nothing about the world.
var _camera_offset := CAMERA_OFFSET
var _camera_aim := CAMERA_AIM_LIFT
## How wide the camera's view is, in degrees, or zero for the engine's default.
## The third of the three capture dials, beside where the camera stands and what
## it looks at: a narrow view is how a shot of something across a stretch of
## water gets both the thing and its reflection at a size worth looking at.
var _camera_fov := 0.0

## How far away the miniature depth of field is focused, or zero for "as far as
## the camera is from the observer", which is what the game is played with. Only
## a capture ever sets it, and like the camera it moves the picture and nothing
## about the world: a shot whose subject is in the water in front of the observer
## rather than at the observer wants the sharp band there instead.
var _camera_focus := 0.0


func _ready() -> void:
	var options := _parse_args()
	_camera_offset = options["camera"]
	_camera_aim = float(options["aim"])
	_camera_focus = float(options["focus"])
	_camera_fov = float(options["fov"])
	_screenshot_path = options["screenshot"]
	_screenshot_frame = options["screenshot_frame"]
	_screenshot_tick = options["screenshot_tick"]
	var aa := String(options["aa"])
	if aa != "" and not AntiAliasing.apply(get_viewport(), aa):
		printerr("render-shell unknown --aa %s, keeping %s" % [
			aa, AntiAliasing.from_project_settings(),
		])
	_sim = Simulation.new(options["seed"])
	# The scenario first, because it stands up a cast of its own in place of the
	# world's and puts the view where that cast is; --start then has the last
	# word on where the camera goes, which is what somebody typing both means and
	# what the headless entry point does with the same pair.
	var scenario := String(options["scenario"])
	if not _sim.begin_scenario(scenario, options["frozen"]):
		printerr("render-shell unknown or unavailable --scenario %s" % scenario)
	if options["start"]:
		_sim.world.place_observer(options["start_x"], options["start_z"])
	_paused = options["paused"]
	AssetLibrary.model_tint_enabled = options["model_tint"]
	if options["grass"]:
		_grass = GrassLayer.new(_sim.world.terrain, _sim.world.world_seed)
	if options["distant"]:
		_distant = DistantGround.new(_sim.world.terrain)
	_lod_levels = options["lod_levels"]
	_lod_centre_set = options["lod_centre"]
	_lod_centre = Vector2(float(options["lod_centre_x"]), float(options["lod_centre_z"]))
	if options["atmosphere"]:
		_atmosphere = Atmosphere.new(_sim.world.world_seed)
	if options["reflection"]:
		_reflection = WaterReflection.new()
		if String(options["mirror_aa"]) != "":
			_reflection.anti_aliasing = String(options["mirror_aa"])
	if String(options["trace"]) != "":
		_build_trace(String(options["trace"]))
	if options["board"]:
		_board_view = MeshInstance3D.new()
		_board_material = StandardMaterial3D.new()
		_board_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_board_material.vertex_color_use_as_albedo = true
		_board_material.vertex_color_is_srgb = true
		_board_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_board_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_board_view.material_override = _board_material
		_board_view.extra_cull_margin = 100.0
		add_child(_board_view)
	if options["sheet"] or options["readout"]:
		_sheet_ui = PixelUi.build(options["sheet"], options["readout"])
		if _sheet_ui == null:
			printerr(
				"render-shell --sheet/--readout: the Sprout Lands UI pack is not"
				+ " unpacked; run ./tools/extract_sprout_lands.sh"
			)
		else:
			add_child(_sheet_ui)
	_build_scenery()
	_sync_views()
	# Printed so that an automated smoke test can confirm the shell really booted
	# and really drove the simulation, without needing a screen to look at.
	var motes := Vector2i.ZERO if _atmosphere == null else _atmosphere.mote_counts()
	# aa= stays last on purpose: tests/test_anti_aliasing.gd reads it as the rest
	# of the line, so anything added here goes in front of it.
	print("render-shell boot seed=%d chunks=%d far=%d fartris=%d islands=%d grass=%d motes=%d sheet=%d/%d aa=%s" % [
		_sim.world.world_seed, _chunk_views.size(),
		_distant_tiles, _distant_triangles, _island_views.size(),
		_grass_blades, motes.y,
		0 if _sheet_ui == null else _sheet_ui.art_scale,
		0 if _sheet_ui == null or _sheet_ui.panel == null \
			else _sheet_ui.panel.sheets.size(),
		AntiAliasing.of(get_viewport()),
	])


func _exit_tree() -> void:
	# Where the interface actually landed, in screen pixels, printed so that a
	# measurement of it is a command rather than a guess. tools/measure_ui.sh
	# reads this line and then asks the saved frame whether that rectangle is
	# made of whole art pixels.
	if _sheet_ui != null and _sheet_ui.panel != null:
		var panel := _sheet_ui.panel
		var at := _sheet_ui.geometry_of(panel)
		print("render-shell sheet scale=%d x=%d y=%d w=%d h=%d sheets=%d showing=%d" % [
			_sheet_ui.art_scale, at.position.x, at.position.y,
			at.size.x, at.size.y, panel.sheets.size(), panel.showing,
		])
	# The same line for the readout, in the same shape and for the same reason:
	# tools/measure_ui.sh reads a rectangle off it and then asks the saved frame
	# whether that rectangle is made of whole art pixels.
	if _sheet_ui != null and _sheet_ui.readout != null:
		var readout := _sheet_ui.readout
		var box := _sheet_ui.geometry_of(readout)
		print("render-shell readout scale=%d x=%d y=%d w=%d h=%d fight=%d" % [
			_sheet_ui.art_scale, box.position.x, box.position.y,
			box.size.x, box.size.y, 1 if readout.has_fight() else 0,
		])
	var motes := Vector2i.ZERO if _atmosphere == null else _atmosphere.mote_counts()
	print("render-shell stop tick=%d frames=%d views=%d handles=%d far=%d fartris=%d farbuilt=%d farcorners=%d faruse=%d islands=%d water=%d grass=%d drawn=%d patches=%d isles=%d motes=%d lights=%d orbs=%d board=%d/%d pieces=%d mirror=%d frame_ms=%.2f timed=%d digest=%s" % [
		_sim.world.tick, _frames, _chunk_views_built,
		_sim.world.terrain_streamer.handles_handed_out,
		_distant_tiles, _distant_triangles,
		0 if _distant == null else _distant.tiles_built,
		0 if _distant == null else _distant.corners_sampled,
		_distant_build_usec,
		_sim.world.island_streamer.handles_handed_out,
		_sim.world.water_sheets_handed_out,
		_grass_blades, _grass_drawn,
		0 if _grass == null else _grass.chunks_built,
		0 if _grass == null else _grass.islands_grown,
		motes.y,
		0 if _atmosphere == null else _atmosphere.lights_made,
		0 if _atmosphere == null else _atmosphere.orb_count(),
		_board_cells, _board_holes,
		_pieces_drawn,
		0 if _reflection == null else _reflection.frames_drawn,
		0.0 if _timed_frames == 0 else _timed_seconds * 1000.0 / float(_timed_frames),
		_timed_frames,
		_sim.world.digest(),
	])


func _process(delta: float) -> void:
	_frames += 1
	_last_delta = delta
	# Frame time, but only once the run has settled: the opening frames are the
	# boot, the streaming and the distance filling in, and averaging those into
	# the number would price the load rather than the picture.
	if _frames > TIMED_FROM_FRAME and is_finite(delta):
		_timed_seconds += delta
		_timed_frames += 1
	if not _paused:
		_accumulator += delta
		var tick_seconds := 1.0 / TICKS_PER_SECOND
		while _accumulator >= tick_seconds:
			_accumulator -= tick_seconds
			_sim.step()
		_sync_views()
	# Outside the pause check, for the same reason the drifting sky is: how much
	# of the distance has been meshed yet is a property of the picture and not of
	# the world, so a held frame goes on filling out to the far plane instead of
	# being captured with whatever fitted in the opening frame.
	if _paused and not _last_snapshot.is_empty():
		_sync_distant(_last_snapshot)
	# Outside the pause check: the sky keeps breathing while the world is paused,
	# because where a far-sky island has drifted to is a property of the picture
	# rather than of the world. The orbs wander for the same reason.
	_drift_far_islands()
	if _atmosphere != null:
		_atmosphere.drift(float(Time.get_ticks_msec()) / 1000.0)
	_aim_reflection()
	# Waiting for a tick rather than a frame makes a capture reproducible: the
	# world is at the same place every time, however fast the machine drew it.
	var ready_to_capture := _frames >= _screenshot_frame
	if _screenshot_tick > 0:
		ready_to_capture = _sim.world.tick >= _screenshot_tick
	if _screenshot_path != "" and ready_to_capture:
		var path := _screenshot_path
		_screenshot_path = ""
		_save_screenshot(path)


## Point the mirror at whatever the camera is looking at, through the plane the
## standing water there is level with.
##
## Outside the pause check, with the drifting sky and the wandering orbs, and for
## the same reason: where the mirror is aimed is a property of the picture rather
## than of the world. A paused capture still gets a reflection of the frame it is
## holding still on.
##
## The plane is the *water table* at the observer, read out of the water field.
## Standing water is defined as ground that has fallen below that table, so every
## pond and lake is exactly level with it -- which makes one number the right
## plane for every still surface in the frame, without anyone having to find the
## pond first.
func _aim_reflection() -> void:
	if _reflection == null:
		return
	_reflection.aim(
		_camera.global_transform,
		_camera.fov,
		_sim.world.terrain.water_field.table_level_at(
			_sim.world.observer_x, _sim.world.observer_z
		),
		get_viewport().size,
		_water_view.visible,
	)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			get_tree().quit(0)
		KEY_SPACE:
			_paused = not _paused
		KEY_R:
			# Restart from the next seed along, to show a different world.
			_sim = Simulation.new(_sim.world.world_seed + 1)
			_clear_chunk_views()
			_water_sheet_version = -1
			_sync_views()


## Copy what the simulation says exists onto the visuals. This is the only place
## the two layers meet, and the traffic is one-way.
func _sync_views() -> void:
	var snapshot := _sim.world.snapshot()
	_last_snapshot = snapshot
	var loaded: Array = snapshot["loaded_chunks"]

	# Chunks the streamer has since dropped stop being drawn.
	var still_loaded := {}
	for key in loaded:
		still_loaded[key] = true
	for key in _chunk_views.keys():
		if not still_loaded.has(key):
			(_chunk_views[key] as Node3D).queue_free()
			_chunk_views.erase(key)

	# Chunks it has built since last frame start being drawn. Geometry never
	# changes once built, so a chunk is asked for, copied and turned into a mesh
	# exactly once, however many frames it then stays on screen for.
	for key in loaded:
		if _chunk_views.has(key):
			continue
		var geometry := _sim.world.terrain_streamer.geometry(key)
		if geometry == null:
			continue
		var view := _build_chunk_view(geometry)
		add_child(view)
		_chunk_views[key] = view
		_chunk_views_built += 1

	_sync_distant(snapshot)
	_sync_islands(snapshot)
	_sync_settlements(snapshot)
	_sync_scatter(snapshot)
	_sync_grass(snapshot)
	_sync_water(snapshot)
	_sync_board(snapshot)
	_sync_combat(snapshot)
	_sync_sheet()

	var observer := Vector3(
		snapshot["observer_x"], snapshot["observer_y"], snapshot["observer_z"]
	)
	if _atmosphere != null:
		_atmosphere.take(_sim.world.observer_profile(), observer)
	# The character stands *on* the surface -- the models are drawn with their
	# feet at their own origin -- and turns to face the way the world says it is
	# walking. Which clip that becomes is CharacterView's business and is decided
	# out of the snapshot; this only hands the snapshot over.
	#
	# When the world is looking through one of its own characters, that character
	# is already on screen -- _sync_combat drew it, wearing its own model -- so
	# the shell's own observer would be a second body standing inside the first.
	# The simulation says which case this is; the shell only reads it.
	_observer_view.visible = int(snapshot["observer_follows"]) == 0
	_observer_view.position = observer
	_observer_view.rotation.y = CharacterView.yaw_for_heading(
		float(snapshot["observer_heading"])
	)
	(_observer_view as CharacterView).apply(
		CharacterView.observer_state(snapshot), _last_delta
	)
	_camera.position = observer + _camera_offset
	_camera.look_at_from_position(
		_camera.position, observer + Vector3(0.0, _camera_aim, 0.0), Vector3.UP
	)


## Put the floating islands on screen, one drawable per island.
##
## Fill the view out past the streamed ground, at a cell that doubles the further
## it goes.
##
## The same three steps the chunks get -- drop, add, leave the rest alone -- with
## one extra: a coarse tile is also dropped when the *cells it emits* change,
## because the simulation has meshed some of the ground under it at full
## resolution and the coarse tile must stop drawing that part. That is what the
## signature is; it changes rarely, and only for the handful of tiles at a
## boundary.
##
## Nothing about this reaches the simulation. The observer's position and the
## list of loaded chunks are read out of the snapshot; every vertex comes from
## the world's own height function; and the world's fingerprint is the same with
## this layer and without it.
func _sync_distant(snapshot: Dictionary) -> void:
	if _distant == null:
		return
	var loaded := {}
	for key in snapshot["loaded_chunks"]:
		loaded[key] = true
	var centre := Vector2(
		float(snapshot["observer_x"]), float(snapshot["observer_z"])
	)
	if _lod_centre_set:
		centre = _lod_centre
	_distant.update(centre.x, centre.y, loaded)
	var wanted := _distant.wanted()

	# Tiles the rings have moved past, and tiles whose hole has changed shape.
	for key in _distant_views.keys():
		var held: Dictionary = _distant_views[key]
		if not wanted.has(key) or wanted[key] != held["sig"]:
			(held["view"] as Node3D).queue_free()
			_distant_views.erase(key)

	# Tiles that are missing, nearest level first, so the view fills outwards. A
	# frame spends at most DISTANT_BUDGET_USEC on this and the rest arrive on the
	# frames after, which is invisible because everything this layer draws is
	# hundreds of units away.
	var started := Time.get_ticks_usec()
	var deadline := started + DISTANT_BUDGET_USEC
	for key in _distant.wanted_keys():
		if _distant_views.has(key):
			continue
		var geometry := _distant.build(key)
		if _lod_levels:
			_wash_level(geometry, key.x)
		var view := _build_chunk_view(geometry)
		add_child(view)
		_distant_views[key] = {
			"view": view, "sig": wanted[key], "triangles": geometry.triangle_count(),
		}
		if Time.get_ticks_usec() >= deadline:
			break
	_distant_build_usec = Time.get_ticks_usec() - started

	_distant_tiles = _distant_views.size()
	_distant_triangles = 0
	for key in _distant_views:
		_distant_triangles += int((_distant_views[key] as Dictionary)["triangles"])


## The same three steps the chunks get, for the same reasons: drop the views of
## islands the streamer has let go, build a view for each new one, and never
## rebuild a view for an island that is still loaded -- an island's geometry
## never changes once built. What arrives is a detached copy, so the islands the
## simulation is holding cannot be reached from here.
func _sync_islands(snapshot: Dictionary) -> void:
	var loaded: Array = snapshot["loaded_islands"]
	var still_loaded := {}
	for key in loaded:
		still_loaded[key] = true
	for key in _island_views.keys():
		if not still_loaded.has(key):
			(_island_views[key] as Node3D).queue_free()
			_island_views.erase(key)
			_island_grass.erase(key)
	if _drifting.size() > 0:
		var kept := []
		for entry in _drifting:
			if still_loaded.has(entry["key"]):
				kept.append(entry)
		_drifting = kept

	for key in loaded:
		if _island_views.has(key):
			continue
		var geometry := _sim.world.island_streamer.geometry(key)
		var island := _sim.world.island_streamer.island(key)
		if geometry == null or island == null:
			continue
		var view := _build_chunk_view(geometry)
		if not island.walkable:
			# The far-sky band does not cast. It is scenery hundreds of units
			# off, tens of units wide, and a shadow from something that big and
			# that high lands as a hard-edged stain across the whole meadow --
			# which reads as a stain rather than as a cloud. What the walkable
			# islands cast is the opposite: a shadow directly under a plate is
			# most of what says it is off the ground.
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dress_island(view, key, island, geometry)
		add_child(view)
		_island_views[key] = view
		if island.drift_radius > 0.0:
			_drifting.append({"key": key, "view": view, "island": island})


## Everything on an island that is not the island itself: the grass on its top,
## what grows on that top and hangs off its keel, the pond in its basin, and the
## waterfall where that pond runs over the rim.
##
## All three hang off the island's own view rather than off the world, so an
## island that is dropped takes its dressing with it in one call, and a far-sky
## island that drifts would carry its own with it.
##
## Nothing here is decided in this file. What grows where, how tall it stands,
## which triangles the pond is made of and where the fall leaves the rim are all
## in what the simulation handed over; this turns each tag into something
## drawable and each list of numbers into a mesh.
func _dress_island(
	view: Node3D, key: Vector3i, island: FloatingIsland, geometry: TerrainChunkGeometry
) -> void:
	# The grass, grown off the same geometry this island is drawn from, so an
	# island's top is a field of tufts rather than flat colour beside the ground.
	# It is the island's child, so it streams out with the island in one call and
	# would travel with a far-sky island if one ever grew any.
	if _grass != null:
		var grass := _grass.build_island(geometry, island)
		if grass != null:
			view.add_child(grass)
			_island_grass[key] = {
				"view": grass, "at": Vector2(island.centre_x, island.centre_z),
			}

	var cover := _sim.world.island_streamer.cover_of(key)
	if cover != null and cover.count() > 0:
		var grown := Node3D.new()
		grown.name = "cover"
		# One profile for the whole island, and the island's own colours stamped
		# into it. An island is a single chunk of land that broke off one place
		# and carries that place's biome and that place's ground, rock and water
		# colours -- the same colours its cliff and its keel are drawn in, and
		# the same biome its cover was gated on. Reading the profile under each
		# item instead would colour a tree by the country a long way below it.
		var profile := _sim.world.terrain.profile_at(island.centre_x, island.centre_z)
		profile.ground_tint = island.ground_tint
		profile.rock_tint = island.rock_tint
		profile.water_tint = island.water_tint
		for item in cover.items:
			_add_scattered(grown, item, profile)
		view.add_child(grown)

	var pond := _sim.world.island_streamer.water_of(key)
	if pond != null and pond.triangle_count() > 0:
		var surface := MeshInstance3D.new()
		surface.name = "pond"
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pond.vertices
		arrays[Mesh.ARRAY_NORMAL] = pond.normals
		arrays[Mesh.ARRAY_COLOR] = pond.colors
		arrays[Mesh.ARRAY_INDEX] = pond.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		surface.mesh = mesh
		surface.material_override = _water_material
		surface.layers = WaterReflection.HIDDEN_LAYER
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.add_child(surface)

	if island.has_spill():
		view.add_child(_build_fall(island))


## The waterfall, as a curtain hanging from the point on the rim the simulation
## picked.
##
## Two quads at right angles rather than one, so the fall still reads as water
## when the camera comes round the side of the island; a single billboarded quad
## would be a sheet of nothing seen edge-on, and this diorama camera orbits.
## Their UVs run across and down the fall, which is what lets the shader animate
## it without knowing where in the world it is or which way it faces.
func _build_fall(island: FloatingIsland) -> MeshInstance3D:
	var top := Vector3(island.spill_x, island.water_level, island.spill_z)
	var outward := Vector3(
		island.spill_x - island.centre_x, 0.0, island.spill_z - island.centre_z
	).normalized()
	if outward == Vector3.ZERO:
		outward = Vector3.RIGHT
	var sideways := Vector3(-outward.z, 0.0, outward.x)
	var half := maxf(0.5, island.spill_width * 0.5)
	var drop := Vector3(0.0, -island.spill_fall, 0.0)

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var faces: Array[Vector3] = [sideways, outward]
	for across in faces:
		var edge := across * half
		# The fall leans outwards as it goes, so it clears the cliff under it
		# instead of running down the rock.
		var lean := outward * (island.spill_fall * 0.16)
		var corners: Array[Vector3] = [
			top - edge, top + edge, top + edge + drop + lean, top - edge + drop + lean,
		]
		var facing := across.cross(Vector3.UP).normalized()
		var triangles: Array[Array] = [[0, 1, 2], [0, 2, 3]]
		for triangle in triangles:
			for at in triangle:
				vertices.append(corners[at])
				normals.append(facing)
				uvs.append(Vector2(
					0.0 if at == 0 or at == 3 else 1.0,
					0.0 if at < 2 else 1.0,
				))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var fall := MeshInstance3D.new()
	fall.name = "waterfall"
	fall.mesh = mesh
	fall.material_override = _fall_material
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return fall


## Move the far-sky islands. Two circles of different periods, so a pair of
## neighbours never look like they are on the same turntable, and slow enough
## that the motion reads as the sky being alive rather than as anything
## happening. Nothing here touches the simulation: these islands are scenery,
## the terrain query does not know they exist, and no answer about the world
## depends on where they have drifted to.
func _drift_far_islands() -> void:
	var seconds := float(Time.get_ticks_msec()) / 1000.0
	for entry in _drifting:
		var island: FloatingIsland = entry["island"]
		var angle := seconds * island.drift_rate + island.drift_phase
		(entry["view"] as Node3D).position = Vector3(
			cos(angle) * island.drift_radius,
			sin(angle * 0.63 + island.drift_phase) * island.drift_radius * 0.35,
			sin(angle * 0.81) * island.drift_radius,
		)


## Put the villages and the roads on screen.
##
## The same three steps the chunks and the islands get, and for the same reasons:
## drop what the streamer has let go, build what is new, and never rebuild what
## is still loaded. Nothing about a village is decided here. Where every building
## and every prop stands, which way it faces and what it is are the simulation's;
## this only turns each tag into something drawable through the asset table, and
## puts it where it was told.
func _sync_settlements(snapshot: Dictionary) -> void:
	var villages: Array = snapshot["loaded_settlements"]
	var still_here := {}
	for key in villages:
		still_here[key] = true
	for key in _settlement_views.keys():
		if not still_here.has(key):
			(_settlement_views[key] as Node3D).queue_free()
			_settlement_views.erase(key)
	for key in villages:
		if _settlement_views.has(key):
			continue
		var site := _sim.world.settlement_streamer.settlement(key)
		if site == null:
			continue
		var view := Node3D.new()
		view.name = "village_%d_%d" % [key.x, key.y]
		for building in site.buildings:
			_add_placed(view, building, 0.0)
		for prop in site.props:
			_add_placed(view, prop, 0.0)
		for at in site.glows.size():
			var pane := _add_window_glow(view, site, site.glows[at])
			if pane != null:
				# Named rather than left to the engine's numbering, so that the
				# lit windows can be found again in the tree -- which is how
				# tools/measure_lights.gd prices them.
				pane.name = "window_glow_%d" % at
		add_child(view)
		_settlement_views[key] = view

	var roads: PackedStringArray = snapshot["loaded_roads"]
	var road_here := {}
	for name_of in roads:
		road_here[name_of] = true
	for name_of in _road_views.keys():
		if not road_here.has(name_of):
			(_road_views[name_of] as Node3D).queue_free()
			_road_views.erase(name_of)
	for name_of in roads:
		if _road_views.has(name_of):
			continue
		var road := _sim.world.settlement_streamer.road(name_of)
		if road.is_empty():
			continue
		var view := Node3D.new()
		view.name = "road_%s" % name_of
		for bridge in road["bridges"]:
			# A bridge tag is one span of deck. The simulation says how long this
			# one has to be; the placeholder is drawn at a fixed length, so it is
			# stretched along its own axis to close the gap. A real pack would be
			# repeated instead, which is a change to this line and to nothing in
			# the simulation.
			var span := _add_placed(view, bridge, float(bridge["height"]))
			if span != null:
				var unit: float = PathNetwork.BRIDGE_UNIT[bridge["tag"]]
				span.scale = Vector3(1.0, 1.0, float(bridge["span"]) / unit)
		for prop in road["props"]:
			_add_placed(view, prop, 0.0)
		add_child(view)
		_road_views[name_of] = view


## Put the flora and props on screen, one node per dressed chunk.
##
## The same three steps everything else gets, and nothing about the dressing is
## decided here either. What grows where, which way it faces, how tall it stands
## and what height it stands at are all the simulation's; this turns each tag
## into something drawable through the asset table and scales it to the size it
## was told, so a stunted highland fir and a deep-forest one are the same row of
## the table drawn at two sizes.
func _sync_scatter(snapshot: Dictionary) -> void:
	var loaded: Array = snapshot["loaded_scatter"]
	var still_here := {}
	for key in loaded:
		still_here[key] = true
	for key in _scatter_views.keys():
		if not still_here.has(key):
			(_scatter_views[key] as Node3D).queue_free()
			_scatter_views.erase(key)
	for key in loaded:
		if _scatter_views.has(key):
			continue
		var patch := _sim.world.scatter_streamer.patch(key)
		if patch == null:
			continue
		var view := Node3D.new()
		view.name = "scatter_%d_%d" % [key.x, key.y]
		for item in patch.items:
			_add_scattered(view, item)
		add_child(view)
		_scatter_views[key] = view


## Grow the grass on the chunks near enough to be worth it, and tell the shader
## where the view is and who is walking through it.
##
## The same three steps every other layer gets -- drop what is far, build what is
## new, never rebuild what is still there -- on a shorter radius than the ground,
## because a thirty-centimetre tuft forty units away is a few pixels and there are
## thousands of them.
##
## What is *not* the same is the level of detail. A chunk is built once, at full
## density, with its tufts in a shuffled order; how many of them are drawn is a
## single integer on the multimesh, changed as the observer moves. Nothing is
## rebuilt to thin a chunk out, which is the whole reason it is done this way
## round -- see reports/grass.md.
func _sync_grass(snapshot: Dictionary) -> void:
	if _grass == null:
		return
	var observer := Vector2(snapshot["observer_x"], snapshot["observer_z"])

	for key in _grass_views.keys():
		if GrassLayer.dropped_at(
			TerrainChunkMesher.distance_to_chunk(key, observer.x, observer.y)
		):
			(_grass_views[key] as Node3D).queue_free()
			_grass_views.erase(key)

	for key in snapshot["loaded_chunks"]:
		if _grass_views.has(key):
			continue
		if not GrassLayer.wanted_at(
			TerrainChunkMesher.distance_to_chunk(key, observer.x, observer.y)
		):
			continue
		var geometry := _sim.world.terrain_streamer.geometry(key)
		if geometry == null:
			continue
		var view := _grass.build(geometry)
		if view == null:
			# Nothing grows on this chunk -- all water, all cliff, all village
			# floor. Remembered as nothing rather than as an absence, so it is
			# not tried again every frame.
			_grass_views[key] = _empty_grass(key)
			add_child(_grass_views[key])
			continue
		add_child(view)
		_grass_views[key] = view

	_grass_blades = 0
	_grass_drawn = 0
	for key in _grass_views:
		var view := _grass_views[key] as MultiMeshInstance3D
		if view.multimesh == null:
			continue
		_grass.set_detail(view, TerrainChunkMesher.distance_to_chunk(
			key, observer.x, observer.y
		))
		var counts := GrassLayer.counts_of(view)
		_grass_blades += counts.x
		_grass_drawn += counts.y

	# The islands' grass, on the same level-of-detail rule. Distance is measured
	# to the island's middle rather than to its nearest edge, because an island
	# is one drawable however wide it is and the count has to be one number.
	for key in _island_grass:
		var entry: Dictionary = _island_grass[key]
		var view := entry["view"] as MultiMeshInstance3D
		if view.multimesh == null:
			continue
		_grass.set_detail(view, (entry["at"] as Vector2).distance_to(observer))
		var counts := GrassLayer.counts_of(view)
		_grass_blades += counts.x
		_grass_drawn += counts.y

	_grass.look_from(observer, _walkers(snapshot))
	# One write for the whole world however many chunks are drawn, exactly as the
	# walkers above are: the grass over the board's squares stands shorter so the
	# lattice reads through it.
	if _board_view != null and _board_reach.size.x > 0.0:
		_grass.stand_over_board(
			_board_reach.get_center(),
			_board_reach.size * 0.5,
			_board_level,
			_board_relief,
			CombatBoard.CELL_SIZE,
			BOARD_FILL,
		)
	else:
		_grass.stand_clear()


## An empty stand-in for a chunk nothing grows on, so that the answer is
## remembered instead of recomputed.
func _empty_grass(key: Vector2i) -> MultiMeshInstance3D:
	var view := MultiMeshInstance3D.new()
	view.name = "grass_%d_%d_bare" % [key.x, key.y]
	return view


## Everyone the grass has to part around, in world units.
##
## One entry today, because the world holds one observer and it is a placeholder
## for a character. When there are characters this is the list of them, and
## nothing else in the layer changes: the shader already carries eight slots and
## reads whichever are filled.
func _walkers(snapshot: Dictionary) -> Array[Vector3]:
	return [Vector3(
		snapshot["observer_x"], snapshot["observer_y"], snapshot["observer_z"]
	)]


## One scattered thing, at the height and the size the simulation gave it.
func _add_scattered(
	parent: Node3D, item: Dictionary, profile: BiomeProfile = null
) -> Node3D:
	var node := _add_placed(parent, item, float(item["y"]), profile)
	if node == null:
		return null
	# The size is in world units, because generation has no idea what any of
	# this looks like. The table does, so the division happens here.
	var natural := AssetLibrary.natural_height(String(item["tag"]))
	if natural > 0.0:
		node.scale = Vector3.ONE * (float(item["size"]) / natural)
	return node


## Put one tagged thing on the ground where the simulation said it stands.
##
## `height` of zero means "on the ground here", which is what everything but a
## bridge wants; a bridge carries its own deck height because it stands over
## water, where there is no ground to sit on.
func _add_placed(
	parent: Node3D,
	placed: Dictionary,
	height: float,
	profile: BiomeProfile = null,
) -> Node3D:
	var tag := String(placed["tag"])
	var x := float(placed["x"])
	var z := float(placed["z"])
	# The biome under the position, unless the caller has one of its own -- an
	# island's cover takes the island's biome rather than the country below it.
	if profile == null:
		profile = _sim.world.terrain.profile_at(x, z)
	var node := AssetLibrary.build(tag, profile)
	if node == null:
		return null
	node.position = Vector3(
		x, height if height != 0.0 else _sim.world.terrain.ground_height_at(x, z), z
	)
	node.rotation.y = float(placed["yaw"])
	parent.add_child(node)
	if _atmosphere != null:
		var light := _atmosphere.light_for(tag, profile)
		if light != null:
			node.add_child(light)
		if tag == AssetTags.GLOWING_ORB:
			_atmosphere.hold_orb(node, _sim.world.world_seed)
	return node


## One lit window, on the wall of the building the simulation hung it on.
##
## The simulation decided which building, which of its walls, and where along
## that wall -- and it decided all of that from the rectangle of ground the
## building reserved, because that is the only shape it knows. The asset table,
## which is the only thing here that has seen the model, moves the point from the
## reserved rectangle's facade onto the wall the model really has there; without
## that step a pane would hang up to 3.8 units off the side of a tavern.
##
## The height comes from the building rather than from under the pane itself, so
## that a window is at the same height as its own floor. On a village pad the two
## are the same to within the levelling, but saying so costs nothing.
##
## Which storey it is on is the table's too, for the same reason the wall is: the
## installed models do not all have flat wall at the same height.
func _add_window_glow(parent: Node3D, site: Settlement, glow: Dictionary) -> Node3D:
	var index := int(glow["building"])
	if index < 0 or index >= site.buildings.size():
		return null
	var building: Dictionary = site.buildings[index]
	var fitted := AssetLibrary.window_glow_point(building, glow)
	# The table draws the pane WINDOW_HEIGHT above the node, so lifting the node
	# by the difference puts it on the storey the fit chose -- and takes the
	# light with it, because the light hangs off the same node at the same
	# height. A cottage is lit at head height, a tower one storey up.
	var ground := _sim.world.terrain.ground_height_at(
		float(building["x"]), float(building["z"])
	)
	return _add_placed(parent, {
		"tag": glow["tag"],
		"x": fitted["x"],
		"z": fitted["z"],
		"yaw": fitted["yaw"],
	}, ground + float(fitted["height"]) - AssetLibrary.WINDOW_HEIGHT)


## Put the world's water on screen, as one drawable.
##
## The sheet the simulation hands over spans far more than a chunk and is
## rebuilt only when the viewer leaves the window it was built for, so this
## replaces the mesh a couple of times a minute rather than every frame. What
## arrives is a detached copy, so the water the simulation is holding cannot be
## reached from here any more than the ground can.
func _sync_water(snapshot: Dictionary) -> void:
	var version: int = snapshot["water_sheet_version"]
	if version == _water_sheet_version:
		return
	_water_sheet_version = version
	var sheet := _sim.world.water_sheet()
	if sheet == null or sheet.triangle_count() == 0:
		_water_view.visible = false
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sheet.vertices
	arrays[Mesh.ARRAY_NORMAL] = sheet.normals
	arrays[Mesh.ARRAY_COLOR] = sheet.colors
	arrays[Mesh.ARRAY_INDEX] = sheet.indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_water_view.mesh = mesh
	_water_view.visible = true


## Draw the tactical lattice the observer is standing on.
##
## The board is read out of the simulation, never computed here: this asks
## SimWorld for the board around the observer and turns what comes back into
## quads. It is rebuilt only when the observer walks into a different cell or
## steps onto a different storey, because until then it is the same board -- the
## lattice is fixed to the world, so walking about inside one cell does not move
## a single square.
func _sync_board(snapshot: Dictionary) -> void:
	if _board_view == null:
		return
	var combat: Dictionary = snapshot["combat"]
	# While a fight is on, the lattice drawn is the one the fight is *on* --
	# a different rectangle from the one under the observer, and possibly a
	# different storey. The version number says when it changed, exactly as the
	# water sheet's does, so the overlay is rebuilt once per board and not once
	# per frame.
	var fight_board: int = int(combat["board_version"]) if bool(combat["fighting"]) else -1
	var here := CombatBoard.cell_of(
		float(snapshot["observer_x"]), float(snapshot["observer_z"])
	)
	var lifted: bool = snapshot["observer_on_island"]
	if here == _board_cell and lifted == _board_lifted and fight_board == _board_fight:
		return
	_board_cell = here
	_board_lifted = lifted
	_board_fight = fight_board
	# Asked for only now: reading a board is tens of milliseconds, and the
	# lattice is fixed to the world, so walking about inside one cell does not
	# move a single square and there is nothing to redraw. What comes back is a
	# detached copy in both cases, so nothing done to it here reaches the world.
	var board := _sim.world.combat_board() if fight_board >= 0 else _sim.world.board_here()
	if board == null:
		return

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var lines := PackedVector3Array()
	var line_colors := PackedColorArray()
	var holes := 0
	var kept := {}
	var wide := BOARD_CUTS + 1
	var half := board.cell_size * BOARD_FILL * 0.5
	for row in board.cells_deep:
		for column in board.cells_across:
			var cell := board.min_cell + Vector2i(column, row)
			var middle := board.centre(cell)
			var tint := BOARD_GROUND
			if board.is_hole(cell):
				holes += 1
				tint = BOARD_HOLE
			elif board.blocks_move(cell):
				tint = BOARD_BUILT
			elif board.is_cliff_edge(cell):
				tint = BOARD_CLIFF
			elif board.storey_at(cell) > CombatBoard.GROUND_STOREY:
				tint = BOARD_AERIAL
			var surface := _cell_surface(board, cell, kept)

			# The square, as BOARD_CUTS x BOARD_CUTS quads bounded in x and z by
			# the cell exactly as one quad was, each corner standing at the
			# height the terrain has there. Same winding as before.
			for down in BOARD_CUTS:
				for across in BOARD_CUTS:
					var at := down * wide + across
					var quad := [
						_board_point(middle, half, surface, at, across, down),
						_board_point(middle, half, surface, at + 1, across + 1, down),
						_board_point(
							middle, half, surface, at + wide + 1, across + 1, down + 1
						),
						_board_point(middle, half, surface, at + wide, across, down + 1),
					]
					for corner in [0, 1, 2, 0, 2, 3]:
						vertices.append(quad[corner])
						colors.append(tint)

			# The outline, in the same colour at full strength, so a cliff edge
			# reads as an edge and not only as a shade. It walks the same
			# sub-vertices the fill is built from, so the edge of a square is the
			# edge of the square and never floats off it.
			var edge := Color(tint.r, tint.g, tint.b, minf(1.0, tint.a * 2.4))
			var ring := PackedInt32Array()
			for step in BOARD_CUTS:
				ring.append(step)
			for step in BOARD_CUTS:
				ring.append(step * wide + BOARD_CUTS)
			for step in BOARD_CUTS:
				ring.append(BOARD_CUTS * wide + BOARD_CUTS - step)
			for step in BOARD_CUTS:
				ring.append((BOARD_CUTS - step) * wide)
			for step in ring.size():
				var from_at := ring[step]
				var to_at := ring[(step + 1) % ring.size()]
				lines.append(_board_point(
					middle, half, surface, from_at, from_at % wide, from_at / wide
				))
				lines.append(_board_point(
					middle, half, surface, to_at, to_at % wide, to_at / wide
				))
				line_colors.append(edge)
				line_colors.append(edge)
	# Only what this board asked for is kept, so the store cannot grow without
	# bound as the observer walks across the world.
	_board_surface = kept
	_board_cells = board.cell_count()
	_board_holes = holes
	# What the grass needs to know about the board, worked out here because this
	# is where the board is already in hand: how far it reaches, and the middle
	# and the spread of the heights it lies at.
	var low := board.centre(board.min_cell) - Vector2(board.cell_size, board.cell_size) * 0.5
	var high := low + Vector2(
		float(board.cells_across) * board.cell_size,
		float(board.cells_deep) * board.cell_size,
	)
	_board_reach = Rect2(low, high - low)
	var lowest := INF
	var highest := -INF
	for surface in kept.values():
		for height in (surface as PackedFloat64Array):
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	if lowest > highest:
		lowest = board.anchor_height
		highest = board.anchor_height
	_board_level = (lowest + highest) * 0.5
	_board_relief = highest - lowest

	var mesh := ArrayMesh.new()
	var fills := []
	fills.resize(Mesh.ARRAY_MAX)
	fills[Mesh.ARRAY_VERTEX] = vertices
	fills[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fills)
	var outlines := []
	outlines.resize(Mesh.ARRAY_MAX)
	outlines[Mesh.ARRAY_VERTEX] = lines
	outlines[Mesh.ARRAY_COLOR] = line_colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, outlines)
	_board_view.mesh = mesh


## Where one sub-vertex of a square stands: bounded in x and z by its cell, and
## at whatever height the terrain was found to have there.
func _board_point(
	middle: Vector2, half: float, surface: PackedFloat64Array, at: int, across: int, down: int
) -> Vector3:
	return Vector3(
		middle.x - half + 2.0 * half * float(across) / float(BOARD_CUTS),
		surface[at] + BOARD_LIFT,
		middle.y - half + 2.0 * half * float(down) / float(BOARD_CUTS),
	)


## The surface under one cell of the board, as one height per sub-vertex.
##
## The terrain is asked the same question the board builder asked it -- what
## would you be standing on here, coming from this height -- so a square lies on
## the surface the simulation says its cell is, rather than on a second opinion
## about it. Where there is nothing within reach of the cell's own height, which
## is a sub-vertex out over a cliff face or off an island's rim, the cell's
## height stands: better a square that stops following than one that stretches
## down a wall.
##
## A hole is the exception, and it is the same exception the flat version made:
## there is no surface under a hole to follow, so its plate stays flat at the
## anchor height -- the level a piece would have been standing at had there been
## anything there.
func _cell_surface(board: CombatBoard, cell: Vector2i, kept: Dictionary) -> PackedFloat64Array:
	var wide := BOARD_CUTS + 1
	var key := Vector3i(cell.x, cell.y, board.storey_at(cell))
	if _board_surface.has(key):
		var known: PackedFloat64Array = _board_surface[key]
		kept[key] = known
		return known
	var surface := PackedFloat64Array()
	surface.resize(wide * wide)
	if board.is_hole(cell):
		surface.fill(board.anchor_height)
		kept[key] = surface
		return surface
	var middle := board.centre(cell)
	var height := board.height_at(cell)
	var half := board.cell_size * BOARD_FILL * 0.5
	var terrain := _sim.world.terrain
	for down in wide:
		for across in wide:
			var x := middle.x - half + 2.0 * half * float(across) / float(BOARD_CUTS)
			var z := middle.y - half + 2.0 * half * float(down) / float(BOARD_CUTS)
			var found := terrain.support_at(x, z, height)
			surface[down * wide + across] = height if found == -INF else found
	kept[key] = surface
	return surface


## Put the fight on screen, as a diorama standing on the generated ground.
##
## Three steps, and they are the same three the chunks and the islands get: drop
## the drawable of anything the snapshot no longer lists, build one for anything
## new, and move every one that is still there to where the snapshot says it is.
##
## Nothing about the fight is decided here and nothing about it is kept here.
## Where a piece stands, which way it is turned and which clip it plays all come
## out of `CombatDiorama.placements()`, which is a pure function of the snapshot;
## the only thing this file remembers is which node stands for which id, which is
## view bookkeeping in exactly the way `_chunk_views` is. Throw `_piece_views`
## away and rebuild it from the same snapshot and the picture is identical.
## Hand the panel whichever characters the world is holding now.
##
## The handles rather than their contents: the panel reads every number off the
## `Character` itself on every frame, so this only has to keep the list right as
## characters arrive and are dropped. Nothing is written back, and the world does
## not know there is a panel.
func _sync_sheet() -> void:
	if _sheet_ui == null:
		return
	if _sheet_ui.panel != null:
		_sheet_ui.panel.show_sheets(SheetSource.sheets_in(_sim.world))
	# The world itself, for the readout: the same handle every frame, so that a
	# restart onto a different world is picked up without anything being pushed.
	# What is on the readout it reads through render/ui/fight_source.gd.
	if _sheet_ui.readout != null:
		_sheet_ui.readout.watch(_sim.world)


func _sync_combat(snapshot: Dictionary) -> void:
	var rows := CombatDiorama.placements(snapshot)
	var still_here := {}
	for row in rows:
		still_here[int(row["id"])] = true
	for id in _piece_views.keys():
		if not still_here.has(id):
			(_piece_views[id] as Node3D).queue_free()
			_piece_views.erase(id)

	for row in rows:
		var id: int = row["id"]
		var at: Vector3 = row["position"]
		var view: Node3D = _piece_views.get(id, null)
		if view == null:
			view = _build_piece_view(row)
			if view == null:
				continue
			_piece_views[id] = view
			_pieces_drawn += 1
		view.position = at + Vector3(0.0, PIECE_LIFT, 0.0)
		view.rotation.y = CharacterView.yaw_for_heading(float(row["heading"]))
		if view is CharacterView:
			(view as CharacterView).apply(row["state"], _last_delta)


## One drawable for one piece: an animated character for a commander, and the
## tag's own model for a minion.
##
## Which model a tag is remains the asset table's business, here as everywhere
## else -- the simulation said `minion_frog` and has never heard of what one
## looks like.
func _build_piece_view(row: Dictionary) -> Node3D:
	var tag := String(row["tag"])
	var at: Vector3 = row["position"]
	if bool(row["commander"]):
		# The observer's own construction, and for the same reason: the scene
		# owns the animation and the model is a swappable child, so a commander
		# is one line and a tag.
		var scene: PackedScene = load(CharacterView.SCENE)
		var character: Node3D = scene.instantiate()
		add_child(character)
		(character as CharacterView).set_model(tag)
		return character
	var model := AssetLibrary.build(tag, _sim.world.terrain.profile_at(at.x, at.z))
	if model == null:
		return null
	add_child(model)
	return model


## Wash one tile's colours towards the tint that stands for its level, so a
## capture can show where a boundary is. Nothing but the colours changes, and it
## happens only when --lod-levels asked for it.
func _wash_level(geometry: TerrainChunkGeometry, level: int) -> void:
	var tint: Color = LOD_LEVEL_TINTS[(level - 1) % LOD_LEVEL_TINTS.size()]
	for at in geometry.colors.size():
		geometry.colors[at] = geometry.colors[at].lerp(tint, 0.6)


## Turn one chunk's geometry -- plain arrays of numbers, copied out of the
## simulation -- into something the graphics card can draw. The arrays go
## straight into the mesh, which is the whole reason the copy has to be a real
## one: a mesh built from arrays that still belonged to the world would leave the
## world reachable from here.
func _build_chunk_view(geometry: TerrainChunkGeometry) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geometry.vertices
	arrays[Mesh.ARRAY_NORMAL] = geometry.normals
	arrays[Mesh.ARRAY_COLOR] = geometry.colors
	arrays[Mesh.ARRAY_INDEX] = geometry.indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _terrain_material
	return view


func _clear_chunk_views() -> void:
	for key in _chunk_views.keys():
		(_chunk_views[key] as Node3D).queue_free()
	_chunk_views.clear()
	for key in _distant_views.keys():
		((_distant_views[key] as Dictionary)["view"] as Node3D).queue_free()
	_distant_views.clear()
	if _distant != null:
		_distant = DistantGround.new(_sim.world.terrain)
	for key in _island_views.keys():
		(_island_views[key] as Node3D).queue_free()
	_island_views.clear()
	_island_grass.clear()
	_drifting.clear()
	for key in _settlement_views.keys():
		(_settlement_views[key] as Node3D).queue_free()
	_settlement_views.clear()
	for key in _scatter_views.keys():
		(_scatter_views[key] as Node3D).queue_free()
	_scatter_views.clear()
	for key in _grass_views.keys():
		(_grass_views[key] as Node3D).queue_free()
	_grass_views.clear()
	_grass_blades = 0
	_grass_drawn = 0
	for key in _road_views.keys():
		(_road_views[key] as Node3D).queue_free()
	_road_views.clear()
	# The board belongs to a place, so a restart in a different world has to
	# forget which cell it was drawn for or it will never be redrawn -- and the
	# surface it sampled is a fact about the old world's seed, not this one's.
	_board_cell = Vector2i(2147483647, 2147483647)
	_board_surface.clear()
	_board_lifted = false


func _parse_args() -> Dictionary:
	var options := {
		"seed": DEFAULT_SEED, "screenshot": "", "screenshot_frame": 60, "screenshot_tick": 0,
		"start": false, "start_x": 0.0, "start_z": 0.0, "paused": false,
		"model_tint": true, "grass": true, "atmosphere": true, "board": false,
		"distant": true, "lod_levels": false, "lod_centre": false,
		"lod_centre_x": 0.0, "lod_centre_z": 0.0,
		"scenario": Simulation.SCENARIO_NONE, "frozen": false,
		"sheet": false, "readout": false,
		"reflection": true, "aa": "", "mirror_aa": "", "trace": "",
		"camera": CAMERA_OFFSET, "aim": CAMERA_AIM_LIFT, "focus": 0.0, "fov": 0.0,
	}
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var has_value := i + 1 < args.size()
		match args[i]:
			"--seed":
				if has_value and args[i + 1].is_valid_int():
					options["seed"] = args[i + 1].to_int()
			"--screenshot":
				if has_value:
					options["screenshot"] = args[i + 1]
			"--screenshot-frame":
				if has_value and args[i + 1].is_valid_int():
					options["screenshot_frame"] = args[i + 1].to_int()
			"--screenshot-tick":
				if has_value and args[i + 1].is_valid_int():
					options["screenshot_tick"] = args[i + 1].to_int()
			"--camera":
				# Where the camera sits relative to the observer, for a capture
				# that wants a closer or a lower view than the one the game is
				# played from. It moves the picture and nothing else.
				if i + 3 < args.size() and args[i + 1].is_valid_float() \
						and args[i + 2].is_valid_float() and args[i + 3].is_valid_float():
					options["camera"] = Vector3(
						args[i + 1].to_float(),
						args[i + 2].to_float(),
						args[i + 3].to_float(),
					)
			"--aim":
				# How far above the observer that camera looks. Raising it tilts
				# the view up, which is what a shot of something overhead wants.
				if has_value and args[i + 1].is_valid_float():
					options["aim"] = args[i + 1].to_float()
			"--fov":
				# How wide the view is, in degrees. Narrowing it is how a shot
				# gets a distant subject and its reflection at a readable size
				# in one frame; it moves the picture and nothing else.
				if has_value and args[i + 1].is_valid_float():
					options["fov"] = args[i + 1].to_float()
			"--focus":
				# How far away the miniature depth of field is sharp. Left
				# alone it is however far the camera is from the observer,
				# which is right when the observer is the subject; a shot of
				# something nearer than that says so here.
				if has_value and args[i + 1].is_valid_float():
					options["focus"] = args[i + 1].to_float()
			"--aa":
				# Draw this run with a named anti-aliasing mode instead of the
				# one project.godot asks for. See AntiAliasing.MODES. It exists
				# so a capture of a given mode is a command rather than an edit
				# to the project file, which is what makes the comparison in
				# reports/grass.md reproducible; it changes the picture and
				# nothing about the world.
				if has_value:
					options["aa"] = args[i + 1]
			"--mirror-aa":
				# Draw the water's mirror with a named anti-aliasing mode. It
				# ships with none, deliberately; this is how a frame of the
				# alternative gets taken so the decision is answered with a
				# picture. See WaterReflection.anti_aliasing.
				if has_value:
					options["mirror_aa"] = args[i + 1]
			"--scenario":
				# Set a named scenario out in the world before the first frame:
				# the encounter on the ground, or the one on a floating island's
				# top. The name goes straight to the simulation, which is what
				# keeps every combat class on that side of the line -- this file
				# names a string and nothing else.
				if has_value:
					options["scenario"] = args[i + 1]
			"--frozen":
				# Photograph a scenario instead of playing it: the simulation
				# plays the run headless to a stated tick and stands the cast
				# where that run left them, which is what a still of one
				# particular moment wants. Without it the scenario is set out
				# where it starts and lived forward in front of the camera.
				options["frozen"] = true
			"--trace":
				# Draw a route read from a file of "x z height" lines: what
				# tools/measure_mountains.sh writes when it finds a way to the
				# top of a mountain. The shell draws the line and nothing else
				# -- it does not search, it does not check, and it does not
				# touch the world -- so a capture of a climb is a picture of a
				# result the simulation produced headless.
				if has_value:
					options["trace"] = args[i + 1]
			"--sheet":
				# Put the character sheet on screen: one panel in the Sprout
				# Lands pixel pack, over whichever characters the scenario put
				# in the world. It reads the simulation's own `Character`
				# objects and writes nothing back, so the world's fingerprint is
				# the same with it and without it -- which is what
				# tests/test_ui_panel.gd checks by running both.
				options["sheet"] = true
			"--readout":
				# Put the combat readout on screen: one panel in the same Sprout
				# Lands pixel pack, showing whose turn it is, the order the
				# commanders act in and what the one acting can swing. It reads
				# the fight the simulation is holding and writes nothing back,
				# so the world's fingerprint is the same with it and without it
				# -- which is what tests/test_ui_readout.gd checks by running
				# both.
				options["readout"] = true
			"--board":
				# Draw the tactical lattice over the ground the observer is
				# standing on. It reads the board out of the simulation and
				# draws it; it changes nothing, which is why the world's
				# fingerprint is the same with it and without it.
				options["board"] = true
			"--lod-levels":
				# Draw each coarse level in its own tint, so a capture can show
				# where the boundaries between them are. A diagnostic overlay
				# and nothing else: the geometry, the world and the fingerprint
				# are the same with it and without it.
				options["lod_levels"] = true
			"--lod-centre":
				# Put the coarse rings somewhere other than under the observer.
				# Walking moves the rings and the camera together, so a frame
				# before and a frame after cannot be compared; this moves the
				# rings alone, which is how the same ground gets photographed at
				# two different levels from one place.
				if i + 2 < args.size() and args[i + 1].is_valid_float() \
						and args[i + 2].is_valid_float():
					options["lod_centre"] = true
					options["lod_centre_x"] = args[i + 1].to_float()
					options["lod_centre_z"] = args[i + 2].to_float()
			"--no-distant-ground":
				# Draw only the ground the simulation streams: the forty-unit
				# disc of chunks and nothing beyond it. It exists so that "the
				# distant ground changes nothing about the world" can be shown
				# by running the same seed both ways and comparing fingerprints,
				# which is what tests/test_terrain_lod.gd does, and so the layer
				# can be priced against its absence.
				options["distant"] = false
			"--no-grass":
				# Draw the world with no grass layer at all: nothing baked,
				# nothing instanced, no shader. It exists so that "the grass
				# changes nothing about the world" can be shown by running the
				# same seed both ways and comparing fingerprints, which is what
				# tests/test_grass.gd does.
				options["grass"] = false
			"--no-reflection":
				# Draw the water with no reflection at all: no second viewport,
				# no second camera, and the shader's mirror branch never taken.
				# It exists so that "the reflection changes nothing about the
				# world" can be shown by running the same seed both ways and
				# comparing fingerprints, which is what tests/test_water.gd
				# does, and so that the mirror can be priced against its absence.
				options["reflection"] = false
			"--no-atmosphere":
				# Draw the world with no lighting or atmosphere stack at all: no
				# environment, no key light, no fog, no bloom, no depth of field,
				# no warm point lights and no motes. It exists so that "the
				# atmosphere changes nothing about the world" can be shown by
				# running the same seed both ways and comparing fingerprints,
				# which is what tests/test_atmosphere.gd does.
				options["atmosphere"] = false
			"--no-model-tint":
				# Draw the pack models in the colours they ship in, instead of
				# shifting each towards the biome colour where it stands. Only
				# ever used to photograph the difference; see
				# AssetLibrary.model_tint_enabled.
				options["model_tint"] = false
			"--paused":
				# Start with the world held still. A capture can then wait as
				# many frames as the renderer needs to settle without the world
				# walking away underneath it, which is what makes a screenshot
				# of a particular island reproducible.
				options["paused"] = true
			"--start":
				# Where the observer opens its eyes. The world has two storeys
				# now, so this is also how a run is aimed at a particular island
				# rather than at whatever happens to be near the origin.
				if i + 2 < args.size() and args[i + 1].is_valid_float() \
						and args[i + 2].is_valid_float():
					options["start"] = true
					options["start_x"] = args[i + 1].to_float()
					options["start_z"] = args[i + 2].to_float()
	return options


## Draw a route found headless, as a ribbon floating just over the ground it
## climbs.
##
## The file is what tools/measure_mountains.gd writes: one "x z height" line per
## cell of the route, in order. Nothing here checks it, re-finds it, or asks the
## world about it -- the heights are the ones the search walked, so what is drawn
## is the result rather than a redrawing of it. Purely a picture: no chunk, no
## field and no fingerprint is touched.
func _build_trace(path_name: String) -> void:
	var file := FileAccess.open(path_name, FileAccess.READ)
	if file == null:
		printerr("render-shell could not read the trace %s" % path_name)
		return
	while not file.eof_reached():
		var parts := file.get_line().strip_edges().split(" ", false)
		if parts.size() < 3:
			continue
		_trace.append(Vector3(
			parts[0].to_float(), parts[2].to_float(), parts[1].to_float()
		))
	file.close()
	if _trace.size() < 2:
		printerr("render-shell trace %s has no route in it" % path_name)
		return

	# A flat ribbon, two triangles per step, laid along the route and turned to
	# face the sky. Drawn unshaded so it reads the same in fog and at night.
	var vertices := PackedVector3Array()
	for step in range(1, _trace.size()):
		var from := _trace[step - 1] + Vector3(0.0, TRACE_LIFT, 0.0)
		var to := _trace[step] + Vector3(0.0, TRACE_LIFT, 0.0)
		var run := to - from
		var side := Vector3(-run.z, 0.0, run.x).normalized() * TRACE_HALF_WIDTH
		var corners := [from - side, from + side, to + side, to - side]
		for at in [0, 1, 2, 0, 2, 3]:
			vertices.append(corners[at])

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = TRACE_TINT
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	_trace_view = MeshInstance3D.new()
	_trace_view.mesh = mesh
	_trace_view.material_override = material
	_trace_view.extra_cull_margin = 4000.0
	add_child(_trace_view)
	print("render-shell trace %s points=%d" % [path_name, _trace.size()])


## Save what is on screen to a file and quit. Used to capture the view for a
## report; it changes nothing about the world.
func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("render-shell screenshot %s" % path)
	else:
		printerr("render-shell screenshot failed (%d) for %s" % [error, path])
	get_tree().quit(0 if error == OK else 1)


func _build_scenery() -> void:
	_camera = Camera3D.new()
	# The camera sits tens of units back from anything it draws, and pushing the
	# far plane out to the far-sky islands stretches the depth buffer. Moving the
	# near plane out with it keeps the precision where the world is, which is
	# what stops the ground shadow-fighting with itself.
	_camera.near = 1.0
	_camera.far = CAMERA_FAR
	if _camera_fov > 0.0:
		_camera.fov = _camera_fov
	add_child(_camera)

	# The whole lighting and atmosphere stack, in one object with one switch:
	# the key light and its shadows, the sky, the fog, the fill, the bloom, the
	# depth of field and the motes. With --no-atmosphere none of it is built and
	# the world underneath is unchanged, which is what tests/test_atmosphere.gd
	# checks by fingerprinting the two runs against each other.
	if _atmosphere != null:
		_atmosphere.attach(self)
		_atmosphere.focus_at(
			_camera_focus if _camera_focus > 0.0 else _camera_offset.length()
		)
		_camera.attributes = _atmosphere.camera_attributes()

	# Flat-shaded and untextured on purpose: the shape is placeholder geometry.
	# The colour is not chosen here -- the material takes it from the per-vertex
	# ground tint the simulation generated, so the palette lives in the biome
	# catalog and this is only the wiring that shows it.
	_terrain_material = StandardMaterial3D.new()
	_terrain_material.albedo_color = Color(1.0, 1.0, 1.0)
	_terrain_material.vertex_color_use_as_albedo = true
	# The tints the simulation writes are ordinary colours, the same numbers a
	# painter would name; the renderer works in linear light. Saying so here is
	# what keeps a dark marsh floor dark instead of washing it out by two stops.
	_terrain_material.vertex_color_is_srgb = true

	# Start on the mood of wherever the observer opened its eyes, so the first
	# frame is already the right biome rather than a default that fades away.
	if _atmosphere != null:
		_atmosphere.take(_sim.world.observer_profile(), Vector3(
			_sim.world.observer_x, _sim.world.observer_y, _sim.world.observer_z
		))

	# The water, as one drawable for the whole sheet. Its mesh is replaced when
	# the simulation rebuilds the sheet; its material never changes, so the
	# animation runs continuously across those replacements.
	_water_view = MeshInstance3D.new()
	_water_material = ShaderMaterial.new()
	var water_shader := Shader.new()
	water_shader.code = WATER_SHADER
	_water_material.shader = water_shader
	_water_view.material_override = _water_material
	# The waterfalls' material, built once here for the same reason: every fall
	# on screen shares it, so they all run off one clock.
	_fall_material = ShaderMaterial.new()
	var fall_shader := Shader.new()
	fall_shader.code = FALL_SHADER
	_fall_material.shader = fall_shader
	_water_view.visible = false
	# Water is a wide, flat thing whose bounding box the engine cannot guess from
	# a mesh that keeps being replaced; without this it is culled at the edges of
	# the view as the camera turns.
	_water_view.extra_cull_margin = 200.0
	# Off the layer the mirror camera draws. Water reflecting water is a feedback
	# loop with nothing in it, and the sheet is between the mirror camera and
	# everything it is there to see.
	_water_view.layers = WaterReflection.HIDDEN_LAYER
	add_child(_water_view)

	# The mirror. It is a second view of this same scene rather than a scene of
	# its own, so it has to be hung in the tree beside everything it draws.
	if _reflection != null:
		_reflection.attach(self)
		_water_material.set_shader_parameter(
			"reflection_map", _reflection.texture()
		)
		_water_material.set_shader_parameter("reflection_amount", REFLECTION_AMOUNT)

	# The observer, as a character standing on the ground and animated.
	#
	# It used to be a 0.6-unit emissive sphere -- a marker for the camera to
	# follow while there was nothing to look at but terrain. There is something
	# to look at now: one CharacterView, wearing whichever model OBSERVER_TAG
	# names, playing whichever clip the snapshot works out to. Nothing about it
	# reaches the simulation, which still holds a position, a heading and how fast
	# it is going and has never heard of an animation.
	var character: PackedScene = load(CharacterView.SCENE)
	_observer_view = character.instantiate()
	add_child(_observer_view)
	(_observer_view as CharacterView).set_model(OBSERVER_TAG)
