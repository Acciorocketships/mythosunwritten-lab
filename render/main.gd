extends Node3D
## The engine shell: it renders the simulation and takes input. It is deliberately
## thin -- it owns no world state of its own, and every frame it just reads a
## snapshot and moves visuals to match. Deleting this whole directory would leave
## the simulation fully runnable.
##
## **The world it draws is the adopted base's own, and so is the scene.**
## `render/main.tscn` is an *inherited* scene: its parent is
## `res://scenes/world.tscn`, the world scene this repository adopted, and this
## script is that scene's root script. Everything that puts the ground on the
## screen is therefore theirs and runs exactly where they hung it -- the
## streamed, storey-quantised heightfield with its rivers and cliffs, the shader
## water, the villages and paths, the dressing, the grass, the sun and the sky,
## all of it `FieldTerrainStreamer` and its neighbours under `scripts/`. This
## file does not mesh a chunk, build a blade of grass or lay a sheet of water,
## and the code that used to do each of those is out of the tree rather than
## sitting beside theirs.
##
## What this file does is the other half: this game's conventions, built as
## children of their world. The tactical lattice and the cells it paints, the
## pieces standing on them, the blows that travel, what is lying on the ground,
## the floating islands, the props and villages the *simulation* placed, the
## characters, and the pixel interface over all of it.
##
## The two halves meet at exactly one number. The simulation's ground
## (`sim/adopted_ground.gd`) and the streamer that draws it both build their
## plans with `TerrainWorldTuning.make_water(seed)` and
## `TerrainWorldTuning.make_heightfield(seed, water)`, so handing the streamer
## the simulation's seed is the whole of making the ground drawn the ground the
## simulation is reading. That is done in `_enter_tree` below, before the
## streamer's own `_ready` runs.
##
## The floating islands are the one piece of ground this shell still draws
## itself, and that is named rather than assumed: the adopted base has no aerial
## layer at all, so there is nothing of theirs to build one on. The simulation
## streams them one island at a time and hands over geometry; the far-sky ones
## drift, and even that is not decided here -- how far and how fast each one
## wanders is placement data the simulation hashed out of the island's cell, and
## this file only turns the clock.
##
## How the world is *lit* is theirs too. `AtmosphereDirector`, hung in their
## world scene, owns the sun, the sky, the fog, the bloom, the ambient fill and
## the depth of field. `render/atmosphere.gd` is what is left over for this
## game: the warm point lights on every glowing tag, the wandering of the
## twilight orbs, the drifting motes, and the mist that pools in the low ground
## -- written onto their Environment rather than onto a second one. It is one
## layer with one switch, and `--no-atmosphere` now means "none of that layer"
## rather than "no lighting": the adopted world still lights itself.
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
##
## Chosen against how big the person is on the screen, which is the one thing a
## camera in a game about steering somebody has to get right. The shipped
## character measures 1.93 world units. At the old `(0, 42, 52)` -- 66.8 units
## away -- that is **13 pixels** tall in the 648-pixel window the game ships in,
## two per cent of the height, which the second playtest photographed and could
## not find without being told where to look. At this offset -- 16.7 units away,
## a quarter of the distance -- the same character measures **49 pixels**, or
## 7.5% of the height.
##
## Why 49 and not more: the view still has to hold a fight. A board cell is 3.0
## units (`CombatBoard.CELL_SIZE`), the vertical span of the view at the
## person's own depth is `2 tan(37.5 deg) * 16.7` = 25 units, and the ground
## plane is looked down on at 39 degrees, so a fight eight cells across is in
## frame with room around it. Nearer than this and a board runs off the top.
##
## The *direction* is exactly the old one: 10.5 / 13.0 is 42 / 52 to four
## figures, so this is the same picture from four times closer and not a
## different angle on the world. `CAMERA_AIM_LIFT` below is scaled by the same
## quarter for the same reason. See `reports/camera-read.md`.
const CAMERA_OFFSET := Vector3(0.0, 10.5, 13.0)

## How far above the observer the camera aims.
##
## Aiming straight at the observer's feet puts the top edge of the frame below
## the horizon, so the sky is never actually in shot -- which does not matter
## while everything worth seeing is on the ground, and matters a great deal once
## there are islands in the air. Lifting the aim by this much tilts the view up
## by about seven degrees: enough for the horizon, the sky gradient and the
## far-sky band to be in frame, and not so much that the diorama stops being
## looked down on.
##
## Scaled with `CAMERA_OFFSET` when the camera came in, and by exactly the same
## quarter: the tilt a lift produces is the ratio of the lift to the camera's
## distance, so 2.5 at 16.7 units away is the 10.0 at 66.8 units the view was
## composed at. A lift left at 10.0 from 16.7 units away would have aimed the
## camera over the horizon at the sky.
const CAMERA_AIM_LIFT := 2.5

## How far the camera can see. Far enough for the far-sky islands, which are
## streamed out to several hundred units because they are the horizon.
const CAMERA_FAR := 900.0

## For how many opening frames the camera is placed outright rather than eased
## into place.
##
## The adopted camera eases after the person, which is right while the game is
## being played and wrong for the first frame of a run: the world scene authored
## it a couple of units from the origin, and a capture at an early tick would
## photograph it still on its way in. Two frames is enough -- the first puts it
## where it belongs and the second holds it there while the streamer's opening
## chunks land -- and after that it is the smoothed follow it is meant to be.
const CAMERA_SNAP_FRAMES := 2

## How far past what `--focus` names the far blur begins, as a multiple of it.
##
## The adopted director focuses for a third-person camera about seven units off
## the person, with the far band opening at 190; this is that ratio kept, so a
## capture that names a focus gets the same depth of field moved rather than a
## differently shaped one.
const DOF_FAR_SHARE := 1.8

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

# What each kind of cell is drawn in, and what each colour means, are both out of
# one table now: `render/board_legend.gd`. The colours used to be nine constants
# here and the screen said nothing about any of them, so a fight could be fought
# across a field of amber squares with nothing to say that amber is a cliff edge.
# The legend panel is generated from the same table this paints from, so the
# ground and the legend cannot disagree.

## How far above the lattice the offered cells are painted, in world units. Just
## clear of it, so a square that is both drawn and offered reads as the offer
## rather than fighting the lattice for the same pixels.
const CHOICE_LIFT := 0.02

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
## The islands' water, as a shader.
##
## Only the islands': the ground's water is the adopted base's own
## (`terrain/water/water_unified.gdshader`, laid by `WaterSurfaceBuilder` inside
## their streamer), and this repository's wide ground sheet is out of the tree.
## What is left is the pond in a floating island's basin, which is a piece of
## ground the base has no equivalent for, so its surface has none either.
const ISLAND_WATER_SHADER := """
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
## The islands' own surface material, and the material their ponds are drawn
## with. One instance each, shared by every island on screen.
var _island_material: StandardMaterial3D = null
var _water_material: ShaderMaterial = null
## The waterfalls' material. One instance shared by every fall on screen, so
## they all run off the same clock -- and so a fall that streams in mid-flight
## does not start its animation from the beginning.
var _fall_material: ShaderMaterial = null
## Whether the adopted streamer has finished the chunks it holds a run back for.
##
## The base waits on exactly this before letting anybody walk -- that is what
## `ui/loading_screens/MythosLoadingScreen.gd` is -- and this shell waits on it
## for the same reason and one more. The reason: a character cannot stand on
## ground that has not been built, and the streamer builds a chunk a frame, so a
## world stepped from the first frame would have its cast fall through the floor
## and its first frames photographed over empty sky. The one more: it makes a
## capture reproducible, because the tick a frame is taken at is then a tick of
## a world with ground under it however long the machine took to mesh it.
var _ground_ready := false

## This game's own half of the atmosphere, or null when the run was started with
## --no-atmosphere. Null is the whole of turning it off: no warm point lights,
## no orbs, no motes, no ground mist. The adopted world's own grade -- sun, sky,
## fog, bloom, fill, depth of field -- is `AtmosphereDirector`'s and stays.
var _atmosphere: Atmosphere = null

## The adopted world scene's own nodes, found by name in `_enter_tree` because
## this scene *is* that scene. Nothing here is built: the shell reaches for what
## the world it inherited already hung in the tree.
var _ground: FieldTerrainStreamer = null
var _world_environment: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _atmosphere_director: AtmosphereDirector = null
var _camera_rig: Node = null
var _characters: Node = null

# The snapshot the last sync read, kept so a paused run can be re-read from it.
var _last_snapshot := {}

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

# The far-sky islands that drift, as {view, island}. Kept as its own list so the
# per-frame drift does not have to walk every island to find the few that move.
var _drifting := []

## From which frame onwards the frame time is averaged, and what has been
## averaged so far. Reported on the stop line, which is how a cost measurement
## reads it without a screen to look at.
const TIMED_FROM_FRAME := 90
var _timed_seconds := 0.0
var _timed_frames := 0

## How many island views have ever been built, including ones since dropped.
## One per island handed over, so it is also the number of copies this shell has
## asked the simulation for -- reported at exit next to the frame count, which
## is how a test can see that the copying does not repeat per frame.
var _island_views_built := 0

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
## Whether this run keeps the lattice up all the time. True for a run that asked
## for it with --board, which is what a survey of the squares wants; false for a
## play run, where the lattice is a board and a board is a thing that arrives
## when a fight does and goes away with it.
var _lattice_always := false
## Which board the lattice overlay was last drawn for, so it is rebuilt when the
## fight puts a different one under it.
var _board_fight := -1

## The cells offered to whoever is taking a turn, painted over the lattice: one
## drawable, rebuilt when what is on offer changes and not once a frame.
##
## It holds no cell of its own. `_choice_mark` is a written-out signature of the
## lists the simulation last handed over, and its only use is to answer "is this
## the same offer as last frame" without re-reading the board -- which costs tens
## of milliseconds and is the reason the lattice itself is not rebuilt per frame
## either.
var _choice_view: MeshInstance3D = null
var _choice_material: StandardMaterial3D = null
var _choice_mark := ""

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

## One drawable per blow still crossing the board, keyed by `BlowFlights`' own
## key -- which blow it is. The same bookkeeping-and-nothing-else contract as
## `_piece_views`: which cells a flight is between, what it wears and how far
## across it is are all read off the snapshot's blow record on the frame they
## are drawn, so throwing this away and rebuilding it from the same snapshot
## draws the identical picture.
var _flight_views := {}
var _flights_launched := 0

## Every scattered prop currently standing out of the person's way, as the
## node's instance id -> how transparent it is being drawn at this instant.
##
## The id rather than the node itself, because the streamer frees a patch's
## props when it unloads it and a freed object is not a thing to be holding as a
## dictionary key. `instance_from_id` gives the node back while it is alive and
## `is_instance_id_valid` says when it stopped being.
##
## Only the props that are thinned or are on their way back to solid are in
## here, so a frame with a clear view of the person walks an empty dictionary.
## A prop stays in it while it thickens back up and is dropped the moment it is
## solid again, which is what keeps the per-frame work proportional to how many
## trees are actually in the way rather than to how many trees exist.
var _foliage_fades := {}

## The most props thinned on any one frame of this run, and the deepest any of
## them was ever drawn at. Peaks rather than a running total, because what a
## reader of the stop line wants to know is how much work the worst frame did --
## a run with no screen at it says what the rule cost by these two numbers and
## the frame time beside them.
var _foliage_thinned := 0
var _foliage_deepest := 0.0

## How many props were giving way when that was last said out loud, so the
## sentence is printed when the number changes rather than every frame.
var _foliage_said := 0

## How long the fade rule has spent deciding, in microseconds, and over how
## many frames. Its own clock rather than the frame's, because the frame time
## beside it prices what the rule costs to *draw* -- a thinned tree goes through
## the transparent pass -- and these two numbers are what it costs to work out.
var _foliage_usec := 0
var _foliage_frames := 0

## Whether foliage gives way at all, or the run was started with --no-fade.
## Only a measurement ever turns it off: the cost of the rule is the difference
## between two runs that differ in this and nothing else.
var _fade_foliage := true

## One drawable per item lying on the ground, keyed by `GroundItems`' own key --
## which object it is in and which place in it -- so a pile that gains or loses
## something costs one add or one free rather than a rebuild.
##
## Nothing about an item is kept here. The key is a string, the value is a node,
## and every fact about what the item is worth stays in the simulation: the
## shell has no rarity, no level and no budget of its own to disagree with.
var _ground_views := {}
var _ground_drawn := 0

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

## Whether a person is driving one of the world's characters this run, and which
## way that character was last sent.
##
## `--play` hands the character the world is looking through over to whoever is
## at the keyboard -- see `Simulation.hand_over_followed` -- and from then on
## every key below goes into that character's `LiveChoice` and nowhere else. The
## shell chooses nothing and resolves nothing: it builds an action out of the
## catalogue and puts it in a holder, and the world's own control loop picks it
## up on its next tick exactly as it picks up a wandering rule's choice.
##
## Off by default, so a run nobody asked to play is the world walking itself and
## every capture ever taken of it still reproduces.
var _playing := false

## The controls themselves: which key means what, and what the person has aimed
## at, is holding, is taking and has dialled up in coin.
##
## The whole of it is `render/player_controls.gd`; what is here is one of them,
## because what a person has aimed at is a thing that lasts between presses. It
## builds actions out of the catalogue and resolves nothing.
var _controls := PlayerControls.new()

## The same thing for a turn on a board: which key spends which part of the turn,
## and what the person has picked to spend it on.
##
## `render/board_controls.gd` is the whole of it, and it is a second object for
## the same reason it is a second file: what a press means in real time and what
## it means on a board are different questions, and a turn is a thing that has to
## be picked at before it can be spent. It builds no rule either -- every answer
## it gives back is the simulation's, asked through `Simulation.driven_turn()`.
var _board_controls := BoardControls.new()

## Whether to print the world's own journal as it is written. What makes a run
## driven from a script a trace rather than only a picture: it is the control
## loop's account of who chose what on which tick, printed unchanged.
var _journalling := false
var _journal_said := 0

## Whether a fight was on when the shell last looked, so that the board arriving
## and the board going away are each said once, with the tick.
var _was_fighting := false

## Which answer to the driven character has already been printed, by the loop's
## own count of the answers it has given -- `ControlLoop.answer_of`'s `serial`.
## Counted rather than dated so that one answer is said once and two answers are
## said twice, whether or not they fell on the same tick: a person refused the
## same thing twice has been refused twice.
var _answer_said := 0

## Key presses to make on behalf of a person who is not there: `{tick, keycode}`
## rows out of `--input`, fed through the engine's own input queue on the tick
## they name. This machine has no display, so a run that shows a person playing
## has to press the keys from inside; they arrive at `_unhandled_input` by the
## same path a real press does, which is the whole point of doing it this way
## rather than calling the handler directly.
var _synthetic: Array = []

var _screenshot_path := ""
var _screenshot_frame := 0
var _screenshot_tick := 0

## Several frames of one run, as `{tick, path}` rows in tick order, from
## `--screenshot-ticks`.
##
## A single capture answers "what did it look like"; a story answers "what
## happened", and a story photographed across six separate runs is six runs a
## reader has to be told are the same. So a run may name several moments and be
## photographed at each of them, and the run quits after the last. The spelling
## is `--input`'s, because it is the same sort of list: `tick:thing`.
var _screenshot_ticks: Array = []
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


## What the arguments said, kept from `_enter_tree` to `_ready`.
var _options := {}


## Before anything in the inherited world scene has had its own `_ready`.
##
## That timing is the whole reason this function exists. The world scene hangs
## the adopted terrain streamer in the tree with a seed of its own, and a node's
## `_ready` runs before its parent's -- so by the time this shell's `_ready`
## could speak, the streamer would already have built its plans for the wrong
## world and started its worker thread on them. `_enter_tree` runs the other way
## round, parent first, which is where the simulation's seed is put on the
## streamer and where the base's two in-world debug overlays are taken back off.
func _enter_tree() -> void:
	_options = _parse_args()
	_sim = Simulation.new(_options["seed"])
	_ground = $FieldTerrain
	_world_environment = $WorldEnvironment
	_sun = $DirectionalLight3D
	_atmosphere_director = $AtmosphereDirector
	_camera_rig = $Camera3D
	_camera = $Camera3D
	_characters = $Characters
	# The observer is the world scene's own character, wearing this game's view
	# script (render/main.tscn overrides it there). Their camera, their terrain
	# streamer, their water ripples and their atmosphere director were all
	# authored pointing at this node, so making it the observer is the whole of
	# making the adopted world follow the simulation about.
	_observer_view = $Characters/Character
	# One number is the whole of drawing the ground the simulation is standing
	# on: both sides build their plans from the seed through the same two calls
	# in `TerrainWorldTuning`, so the same seed is the same world.
	_ground.SEED_OVERRIDE = _sim.world.world_seed
	_ground.GRASS_ENABLED = _options["grass"]
	# The base's own in-world development tools: a teleport menu and a
	# coordinate read-out, both drawn over the picture. They belong to somebody
	# building the terrain, not to somebody playing the game or photographing a
	# frame of it, so this scene does not carry them.
	for tool_name in ["ReviewTeleporter", "CoordOverlay"]:
		var node := get_node_or_null(NodePath(tool_name))
		if node != null:
			node.queue_free()


func _ready() -> void:
	var options := _options
	_camera_offset = options["camera"]
	_camera_aim = float(options["aim"])
	_camera_focus = float(options["focus"])
	_camera_fov = float(options["fov"])
	_screenshot_path = options["screenshot"]
	_screenshot_frame = options["screenshot_frame"]
	_screenshot_tick = options["screenshot_tick"]
	_screenshot_ticks = _parse_screenshot_ticks(String(options["screenshot_ticks"]))
	var aa := String(options["aa"])
	if aa != "" and not AntiAliasing.apply(get_viewport(), aa):
		printerr("render-shell unknown --aa %s, keeping %s" % [
			aa, AntiAliasing.from_project_settings(),
		])
	# The scenario first, because it stands up a cast of its own in place of the
	# world's and puts the view where that cast is; --start then has the last
	# word on where the camera goes, which is what somebody typing both means and
	# what the headless entry point does with the same pair.
	var scenario := String(options["scenario"])
	# The two scenarios with model-driven minds in them need a channel of
	# replies, and where replies come from is the entry point's business, never
	# the simulation's: the shell hands in the shipped recorded exchange, so
	# these runs need no key, no network and no model.
	var minds: ModelChannel = null
	if scenario == Simulation.SCENARIO_BARGAIN:
		minds = ModelChannel.for_run(ModelRecording.bargain_exchange())
	elif scenario == Simulation.SCENARIO_AGENT:
		minds = ModelChannel.for_run(ModelRecording.exchange())
	if not _sim.begin_scenario(scenario, options["frozen"], minds):
		printerr("render-shell unknown or unavailable --scenario %s" % scenario)
	if options["start"]:
		_sim.world.place_observer(options["start_x"], options["start_z"])
	_paused = options["paused"]
	AssetLibrary.model_tint_enabled = options["model_tint"]
	_fade_foliage = options["fade"]
	if options["atmosphere"]:
		_atmosphere = Atmosphere.new(_sim.world.world_seed)
	# Nothing steps until the ground the cast stands on has been built. The
	# streamer says so itself; asking as well covers a run whose startup landed
	# before this line (the signal has already been emitted and will not be
	# again).
	_ground.startup_loading_completed.connect(_on_ground_ready, CONNECT_ONE_SHOT)
	if _ground.startup_loading_complete():
		_ground_ready = true
	# ...unless nobody is looking. The wait is about the picture -- a character
	# must not be drawn standing over ground that has not been built yet -- and
	# a run with no display draws no picture for anyone to be wrong about. The
	# shell is run that way on purpose, by tests/test_render_shell.gd, to ask
	# whether drawing the world changes it; making that run sit through ten
	# minutes of meshing would price the ground rather than answer the question.
	if Helper.is_headless():
		_ground_ready = true
	if String(options["trace"]) != "":
		_build_trace(String(options["trace"]))
	# Built for a run that asked for the lattice and for one that asked to play.
	# A play run does not keep it up: `_sync_board` draws it while a fight is on
	# and puts it away when the fight is, because a lattice over the meadow is
	# what a board looks like when there is no board.
	_lattice_always = options["board"]
	if options["board"] or options["play"]:
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
	# The offered cells are painted on the same terms as the lattice they lie
	# over, in a drawable of their own so that a fresh offer is a small rebuild
	# rather than the whole board again. Built for a run that asked for the
	# lattice and for one that asked to play, because a person taking a turn has
	# to be shown where they may go whether or not they asked to see the squares.
	if options["board"] or options["play"]:
		_choice_view = MeshInstance3D.new()
		_choice_material = StandardMaterial3D.new()
		_choice_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_choice_material.vertex_color_use_as_albedo = true
		_choice_material.vertex_color_is_srgb = true
		_choice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_choice_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_choice_view.material_override = _choice_material
		_choice_view.extra_cull_margin = 100.0
		add_child(_choice_view)
	# Who is driving. After the scenario and --start, because it hands over
	# whichever character the world ended up looking through.
	_journalling = options["journal"]
	if options["play"]:
		_playing = _sim.hand_over_followed()
		if not _playing:
			printerr(
				"render-shell --play: the world is looking through nobody, so"
				+ " there is no character to hand over"
			)
		else:
			print("render-shell play driving=#%d" % _sim.driven_id)
			for line in PlayerControls.bindings():
				print("render-shell keys %s" % line)
			for line in BoardControls.bindings():
				print("render-shell keys %s" % line)
			# The shell's own key, printed with the rest so a person at the
			# keyboard is not guessing about it either.
			print("render-shell keys Z            open or shut the character sheet")
	_synthetic = _parse_input_script(String(options["input"]))
	# A person playing gets the trade and dialogue panels whether or not they
	# asked, for the reason they get the sheet: an offer that cannot be read
	# cannot be accepted, and a reply that cannot be read cannot be answered.
	var with_dialogue: bool = options["dialogue"] or _playing
	var with_trade: bool = options["trade"] or _playing
	# And the combat readout, for the same reason again: a fight that starts by
	# itself in the running world is a fight nobody asked for, and a turn that
	# cannot be read cannot be taken. The panel hides itself when no fight is on
	# -- `CombatPanel.refresh` -- so a play run with no fight in it looks exactly
	# as it did before.
	var with_readout: bool = options["readout"] or _playing
	# And the legend, for the same reason again: a colour painted on the ground
	# with nothing on screen saying what it means is a colour a person has to
	# guess at, and one of them is a cliff edge. It hides itself while no board
	# is drawn -- `LegendPanel.show_board` -- so a play run with no fight in it
	# looks exactly as it did before.
	#
	# For a run with somebody playing, and not for every run that draws a
	# lattice: `--board` on its own is how a frame of the squares is taken for a
	# report, and a panel over that frame is a panel in the photograph. A legend
	# is for whoever is at the keyboard.
	var with_legend: bool = _playing
	if options["sheet"] or with_readout or _playing \
			or with_dialogue or with_trade or options["territory"] or with_legend:
		_sheet_ui = PixelUi.build(
			options["sheet"], with_readout, _playing,
			with_dialogue, with_trade, options["territory"], with_legend)
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
	print("render-shell boot seed=%d ground=%d islands=%d motes=%d sheet=%d/%d aa=%s" % [
		_sim.world.world_seed, _ground.world_seed, _island_views.size(),
		motes.y,
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
	# The same line again for the dialogue and trade panels, in the same shape
	# and for the same reason: tools/measure_ui.sh reads a rectangle off each
	# and asks the saved frame whether it is made of whole art pixels.
	if _sheet_ui != null and _sheet_ui.dialogue != null and _sheet_ui.dialogue.visible:
		var words := _sheet_ui.geometry_of(_sheet_ui.dialogue)
		print("render-shell dialogue scale=%d x=%d y=%d w=%d h=%d" % [
			_sheet_ui.art_scale, words.position.x, words.position.y,
			words.size.x, words.size.y,
		])
	if _sheet_ui != null and _sheet_ui.trade != null and _sheet_ui.trade.visible:
		var table := _sheet_ui.geometry_of(_sheet_ui.trade)
		print("render-shell trade scale=%d x=%d y=%d w=%d h=%d" % [
			_sheet_ui.art_scale, table.position.x, table.position.y,
			table.size.x, table.size.y,
		])
	if _sheet_ui != null and _sheet_ui.territory != null and _sheet_ui.territory.visible:
		var ground := _sheet_ui.geometry_of(_sheet_ui.territory)
		print("render-shell territory scale=%d x=%d y=%d w=%d h=%d" % [
			_sheet_ui.art_scale, ground.position.x, ground.position.y,
			ground.size.x, ground.size.y,
		])
	# And the legend, with how many colours it drew, so a run says from outside
	# whether the key to the ground was on the screen and how much of it.
	if _sheet_ui != null and _sheet_ui.legend != null and _sheet_ui.legend.visible:
		var key := _sheet_ui.geometry_of(_sheet_ui.legend)
		print("render-shell legend scale=%d x=%d y=%d w=%d h=%d colours=%d" % [
			_sheet_ui.art_scale, key.position.x, key.position.y,
			key.size.x, key.size.y, LegendPanel.lines().size(),
		])
	var motes := Vector2i.ZERO if _atmosphere == null else _atmosphere.mote_counts()
	print("render-shell stop tick=%d frames=%d views=%d handles=%d ground=%d islands=%d motes=%d lights=%d orbs=%d board=%d/%d pieces=%d faded=%d deepest=%.2f fade_us=%.1f frame_ms=%.2f timed=%d digest=%s" % [
		_sim.world.tick, _frames, _island_views_built,
		_sim.world.island_streamer.handles_handed_out,
		_ground.world_seed,
		_island_views.size(),
		motes.y,
		0 if _atmosphere == null else _atmosphere.lights_made,
		0 if _atmosphere == null else _atmosphere.orb_count(),
		_board_cells, _board_holes,
		_pieces_drawn,
		_foliage_thinned,
		_foliage_deepest,
		0.0 if _foliage_frames == 0 else float(_foliage_usec) / float(_foliage_frames),
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
	if not _ground_ready:
		# The ground is still being built. The world is held at tick 0 and the
		# views are synced anyway, so the observer is standing where it belongs
		# and the camera is already framing it when the first chunk lands.
		_sync_views()
		return
	if not _paused:
		_accumulator += delta
		var tick_seconds := 1.0 / TICKS_PER_SECOND
		while _accumulator >= tick_seconds:
			_accumulator -= tick_seconds
			_sim.step()
			# Pressed between one tick and the next, so a script that names a
			# tick gets that tick whatever frame rate the machine managed.
			_press_the_scripted_keys()
		_sync_views()
	_say_what_happened()
	# Outside the pause check: the sky keeps breathing while the world is paused,
	# because where a far-sky island has drifted to is a property of the picture
	# rather than of the world. The orbs wander for the same reason.
	_drift_far_islands()
	if _atmosphere != null:
		_atmosphere.drift(float(Time.get_ticks_msec()) / 1000.0)
	# A held frame has no later frames to ease the camera into place over, so it
	# asks the adopted camera for the pose it is easing towards outright. The
	# same call on the opening frames is what stops a capture at an early tick
	# photographing the camera still on its way in from the scene's own pose.
	if _paused or _frames < CAMERA_SNAP_FRAMES:
		(_camera_rig as Node).call("snap")
	# Waiting for a tick rather than a frame makes a capture reproducible: the
	# world is at the same place every time, however fast the machine drew it.
	if not _screenshot_ticks.is_empty():
		_capture_the_named_moments()
		return
	var ready_to_capture := _frames >= _screenshot_frame
	if _screenshot_tick > 0:
		ready_to_capture = _sim.world.tick >= _screenshot_tick
	if _screenshot_path != "" and ready_to_capture:
		var path := _screenshot_path
		_screenshot_path = ""
		_save_screenshot(path)


## The key that opens and shuts the character sheet.
##
## It is here rather than in `render/player_controls.gd` because it is not an
## intention for a character: opening a panel changes nothing in the world, so it
## belongs beside pause and quit, which are the shell's own furniture.
const KEY_SHEET := KEY_Z


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var keycode := (event as InputEventKey).keycode
	match keycode:
		KEY_ESCAPE:
			get_tree().quit(0)
			return
		KEY_SPACE:
			_paused = not _paused
			return
		KEY_SHEET:
			# The interface's own state and nothing else: the world is not told,
			# nothing is chosen and nothing is resolved. A sheet that cannot be
			# shut is a sheet a person cannot look past.
			if _sheet_ui != null and _sheet_ui.panel != null:
				_sheet_ui.panel.toggle()
				print("render-shell play t=%d sheet %s" % [
					_sim.world.tick,
					"open" if _sheet_ui.panel.open else "shut",
				])
			return
		KEY_R:
			# Restart from the next seed along, to show a different world.
			_sim = Simulation.new(_sim.world.world_seed + 1)
			_playing = false
			_clear_world_views()
			_restart_ground()
			_sync_views()
			return
	if _playing:
		if _drive_the_board(keycode):
			return
		_drive(keycode)


## Turn a key press into what the person driving wants their character to do
## next, and put it where that character's decision function will read it.
##
## The whole of the input half of a person being one of the minds, and it is a
## hand-over and a print. Which key means what, and what the person has picked to
## aim it at, is `render/player_controls.gd`'s; what may be aimed at is the
## simulation's answer, read through `Simulation.driven_surroundings()`, which is
## `Observation` -- the same packet a language-model mind is handed; where the
## choice goes is `LiveChoice`'s; what becomes of it is `ActionEngine`'s. Nothing
## is decided here and nothing is resolved here -- in particular there is no test
## that a step is walkable, no measure of how far a character can jump, no reach,
## no earshot and no second movement path: the action goes into the holder and
## the world's control loop picks it up.
##
## Returns whether the key meant anything.
func _drive(keycode: int) -> bool:
	if _sim.driven == null:
		return false
	var view := _sim.driven_surroundings()
	var chosen := _controls.press(keycode, view)
	if chosen == null:
		# Either the key picked something rather than choosing an action, or the
		# person has not yet picked what the action needs. The second one says
		# so; neither is a refusal, which is the engine's word and goes on the
		# answer panel.
		if _controls.note != "":
			print("render-shell play t=%d %s" % [_sim.world.tick, _controls.note])
			return true
		if PlayerControls.picks(keycode):
			print("render-shell play t=%d aims at %s · %s" % [
				_sim.world.tick, _controls.aim_line(view), _controls.holding_line(),
			])
			return true
		return false
	if keycode == PlayerControls.KEY_PLACE and not view.place.is_empty():
		print("render-shell play t=%d place %s %s at %.1f away" % [
			_sim.world.tick, String(view.place["kind"]), String(view.place["id"]),
			float(view.place["distance"]),
		])
	# Offered rather than simply put in the holder: an action the world already
	# refuses -- walking or jumping while a board holds the character -- is
	# answered on the spot instead of standing in the holder until a turn that
	# may never come to it. The answer is the engine's own and reaches the screen
	# through `_say_what_happened` and the answer panel, as every other answer
	# does; nothing is decided here. See `Simulation.drive`.
	var said := _sim.drive(chosen)
	if said.is_empty():
		# The world had nothing to say, which is the ordinary case -- the choice
		# stands and the loop picks it up next tick. It is also what happens when
		# there is nobody left to offer anything to: a character that was beaten
		# is taken out of the world when the fight it fell in ends, and from then
		# on the loop has nobody to answer for. Saying "chose" there would be a
		# key taken and never answered, so the world is asked what became of them
		# and its own sentence is quoted. See `FightSource.defeat_in`.
		var beaten := FightSource.defeat_of(_sim.world, _sim.driven_id)
		if beaten != "":
			print("render-shell play t=%d %s" % [_sim.world.tick, beaten])
			return true
	print("render-shell play t=%d chose %s" % [_sim.world.tick, chosen.line()])
	return true


## Spend one key press out of the board turn the simulation is holding open, and
## say what it answered.
##
## The board's half of `_drive` above, and the same shape: a hand-over and a
## print. Which key spends which part of a turn is `render/board_controls.gd`'s;
## what may be spent, where a piece may go and what a weapon covers is the
## simulation's, read through `Simulation.driven_turn()`; what becomes of it is
## the match's. Nothing is decided here -- in particular there is no legality
## test, no cooldown, no capture and no damage -- and both halves of what is
## printed below are the simulation's own sentences, quoted: the refusal is the
## match's, and what a weapon action did is the resolution layer's report of the
## blow. See `_what_the_turn_answered`.
##
## Returns whether the key was one of the board's. A key that is meant one thing
## on a board and another in real time does not exist: `BoardControls.binds` and
## `PlayerControls` share no key, so this consumes what it binds and nothing else.
func _drive_the_board(keycode: int) -> bool:
	if not BoardControls.binds(keycode):
		return false
	var turn := _sim.driven_turn()
	if turn == null:
		# There is no turn to spend, and which of the four reasons that is is
		# the world's answer rather than this file's. This shell used to hold
		# one sentence of its own -- "it is not your turn on a board" -- and
		# print it whenever the world had not handed it something better, so
		# somebody standing in an empty field with no board anywhere was told to
		# wait for a turn on one. Now the world is asked and its own sentence is
		# quoted, which is what a beaten character, a character that walked out
		# of a fight and a character who is simply not in one are each told.
		# See `Simulation.no_turn_because` and `BoardTurn.why_none`.
		print("render-shell play t=%d %s" % [
			_sim.world.tick, _sim.no_turn_because()])
		return true
	var answered := _board_controls.press(keycode, turn)
	if _board_controls.note != "":
		print("render-shell play t=%d %s" % [_sim.world.tick, _board_controls.note])
		return true
	if answered.is_empty():
		print("render-shell play t=%d round %d picks %s" % [
			_sim.world.tick, turn.round_number(), _board_controls.picked_line(),
		])
		return true
	print("render-shell play t=%d round %d turn %s -> %s" % [
		_sim.world.tick, turn.round_number(), _the_key_named(keycode),
		_what_the_turn_answered(answered),
	])
	return true


## What the simulation answered one board key, for the line above.
##
## An answer that carries the simulation's own sentence is quoted, and nothing is
## added to it: a weapon action comes back carrying the resolution layer's report
## of the blow -- who it found, which attack it was, how many cells it covered,
## how many pieces it landed on and what they took -- which is the same sentence
## a character that chose `attack` for itself is answered with. See
## `BoardTurn.swing`. Before this, a blow struck by hand had nothing to quote and
## this line said "done", so a person was told less about their own blow than a
## rule-driven character was told about the identical one.
##
## The two short words are for the answers that carry no sentence: stepping,
## turning, sending a minion, ending the turn and leaving. They say whether it
## happened, and when it did not they quote the match's own reason.
static func _what_the_turn_answered(answered: Dictionary) -> String:
	var sentence := String(answered.get("said", ""))
	if sentence != "":
		return sentence
	if bool(answered.get("ok", false)):
		return "done"
	return "refused: %s" % String(answered.get("reason", ""))


## What a board key is called, for the line above. Interface furniture: the
## simulation has no name for a key and no opinion about one.
static func _the_key_named(keycode: int) -> String:
	var at := BoardControls.SWING_KEYS.find(keycode)
	if at >= 0:
		return "weapon action %d" % (at + 1)
	match keycode:
		BoardControls.KEY_STEP:
			return "step"
		BoardControls.KEY_SEND:
			return "send a minion"
		BoardControls.KEY_TURN_LEFT:
			return "turn left"
		BoardControls.KEY_TURN_RIGHT:
			return "turn right"
		BoardControls.KEY_END_TURN:
			return "end the turn"
		BoardControls.KEY_LEAVE:
			return "leave the fight"
	return "pick"


## Paint the cells the simulation is offering whoever is taking a turn.
##
## Read, never worked out: `BoardControls.marks` asks the turn where the
## commander may step, what its weapons cover, where the picked minion may go and
## what is picked, and this turns four lists of cells into four colours of quad
## over the lattice. There is no rule here about any of the four, which is the
## whole point -- the interface asks what is legal and draws the answer.
##
## Rebuilt only when the offer changes, because reading the board out of the
## simulation costs tens of milliseconds and an offer changes on a key press, not
## on a frame.
func _sync_choice() -> void:
	if _choice_view == null:
		return
	var turn := _sim.driven_turn()
	var marks := BoardControls.marks(turn, _board_controls)
	var wanted := _choice_signature(marks)
	if wanted == _choice_mark:
		return
	_choice_mark = wanted
	if wanted == "":
		_choice_view.mesh = null
		return
	var board := _sim.world.combat_board()
	if board == null:
		_choice_view.mesh = null
		return
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var kept := {}
	# Painted in this order so that the brighter, narrower answer is the one on
	# top: where you may go, then what you could hit from here, then where the
	# minion may go, then the cell actually picked.
	for layer in BoardLegend.OFFERS:
		var tint := Color((layer as Dictionary)["tint"])
		for cell in (marks[String((layer as Dictionary)["key"])] as Array[Vector2i]):
			if not board.contains(cell):
				continue
			_paint_cell(board, cell, tint, kept, vertices, colors)
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_choice_view.mesh = mesh


# One offered cell, as the same grid of quads a lattice square is made of, a
# little higher up. The height under every corner is the surface the square
# itself follows, so an offer lies on the ground the way the lattice does.
func _paint_cell(
	board: CombatBoard,
	cell: Vector2i,
	tint: Color,
	kept: Dictionary,
	vertices: PackedVector3Array,
	colors: PackedColorArray,
) -> void:
	var wide := BOARD_CUTS + 1
	var half := board.cell_size * BOARD_FILL * 0.5
	var middle := board.centre(cell)
	var surface := _cell_surface(board, cell, kept)
	for down in BOARD_CUTS:
		for across in BOARD_CUTS:
			var at := down * wide + across
			var quad := [
				_board_point(middle, half, surface, at, across, down),
				_board_point(middle, half, surface, at + 1, across + 1, down),
				_board_point(middle, half, surface, at + wide + 1, across + 1, down + 1),
				_board_point(middle, half, surface, at + wide, across, down + 1),
			]
			for corner in [0, 1, 2, 0, 2, 3]:
				vertices.append(quad[corner] + Vector3(0.0, CHOICE_LIFT, 0.0))
				colors.append(tint)


# What is on offer, written out, so that "the same offer as last frame" is one
# string comparison. Empty when there is nothing on offer at all.
static func _choice_signature(marks: Dictionary) -> String:
	var written := PackedStringArray()
	var anything := false
	for named in ["move", "reach", "minion", "picked"]:
		var cells: Array[Vector2i] = marks[named]
		anything = anything or not cells.is_empty()
		var one := PackedStringArray()
		for cell in cells:
			one.append("%d,%d" % [cell.x, cell.y])
		written.append("%s:%s" % [named, ";".join(one)])
	return "" if not anything else "|".join(written)


## Press the keys a run was given instead of the keys a person would press.
##
## This machine has no display, so the only way to show somebody playing is to
## play it from inside. The press goes through `Input.parse_input_event`, which
## puts it on the engine's own input queue, so it reaches `_unhandled_input`
## along the path a real key takes -- the binding under test is the binding a
## person uses, not a copy of it called directly.
func _press_the_scripted_keys() -> void:
	while not _synthetic.is_empty() \
			and int((_synthetic[0] as Dictionary)["tick"]) <= _sim.world.tick:
		var press: Dictionary = _synthetic.pop_front()
		var event := InputEventKey.new()
		event.keycode = int(press["key"])
		event.physical_keycode = int(press["key"])
		event.pressed = true
		Input.parse_input_event(event)


## Print what the world wrote down since the last frame: its control loop's
## journal when `--journal` asked for it, and the engine's answer to whoever is
## being driven whenever there is a new one.
##
## Both are quoted rather than phrased. The journal lines are the loop's own and
## the answer is `ActionOutcome.line()` carried through `ControlLoop.answer_of`
## unchanged, which is the same sentence the answer panel puts on screen.
## Whether the person this run is about is standing on a board right now.
##
## One reading, asked in the two places the shell draws or says something about a
## board being up: the lattice over the ground and the line that says the board
## appeared. It is the per-character answer the simulation carries in its
## snapshot (`FightSource.on_the_board_in`), not `snapshot["fighting"]`, which
## says only that some fight is on somewhere in the world. A run with nobody
## driven and nobody followed falls back to the world's answer, which is what a
## photographed board with a fixed camera beside it needs.
func _on_a_board(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var combat: Dictionary = snapshot["combat"]
	var about := _sim.driven_id if _playing else _sim.world.follow_id
	if about == 0:
		return bool(combat["fighting"])
	return FightSource.on_the_board_in(combat, about)


func _say_what_happened() -> void:
	# The board arriving and going away, said once each with the tick it happened
	# on. Read off the snapshot rather than watched for: the shell asks whether a
	# fight is on and compares that with what it said last time, which is the
	# same reading the board overlay is rebuilt from.
	var fighting := _on_a_board(_last_snapshot)
	if fighting != _was_fighting:
		_was_fighting = fighting
		print("render-shell fight t=%d %s" % [
			_sim.world.tick,
			"the board appears" if fighting else "the board is put away",
		])
	# And how many trees are standing out of the person's way, said when the
	# number changes and not once a frame. A run with no screen at it has no
	# other way to know the rule fired, and a run with a screen at it has the
	# picture; this is what lets a capture name the tick to photograph.
	if _foliage_said != _foliage_fades.size():
		_foliage_said = _foliage_fades.size()
		print("render-shell foliage t=%d giving way=%d deepest=%.2f" % [
			_sim.world.tick, _foliage_said, _foliage_deepest,
		])
	if _journalling:
		var journal := _sim.world.loop.journal
		for at in range(_journal_said, journal.size()):
			print("  %s" % journal[at])
		_journal_said = journal.size()
	if not _playing:
		return
	var answer := _sim.driven_answer()
	if answer.is_empty() or int(answer["serial"]) == _answer_said:
		return
	_answer_said = int(answer["serial"])
	print("render-shell play t=%d %s -> %s" % [
		int(answer["tick"]), String(answer["action"]), String(answer["line"]),
	])


## The moments a run was told to photograph, as `{tick, path}` rows in tick
## order. Spelled `20:one.png,60:two.png`, which is `--input`'s spelling with a
## file where the key goes; anything unreadable is reported and skipped.
func _parse_screenshot_ticks(script: String) -> Array:
	var wanted := []
	if script.strip_edges() == "":
		return wanted
	for entry in script.split(",", false):
		var parts := entry.strip_edges().split(":", false)
		if parts.size() != 2 or not parts[0].is_valid_int():
			printerr("render-shell --screenshot-ticks: cannot read '%s'" % entry)
			continue
		wanted.append({"tick": parts[0].to_int(), "path": parts[1].strip_edges()})
	wanted.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["tick"]) < int(right["tick"]))
	return wanted


## The keys a run was told to press, as `{tick, key}` rows in tick order.
##
## The spelling is `tick:key`, comma-separated: `--input "20:w,60:g,120:k"`. A
## key is named by the letter or arrow a person would press, and anything else in
## the list is reported and skipped rather than silently dropped.
func _parse_input_script(script: String) -> Array:
	var pressed := []
	if script.strip_edges() == "":
		return pressed
	for entry in script.split(",", false):
		var parts := entry.strip_edges().split(":", false)
		if parts.size() != 2 or not parts[0].is_valid_int():
			printerr("render-shell --input: cannot read '%s'" % entry)
			continue
		var keycode := OS.find_keycode_from_string(parts[1].strip_edges())
		if keycode == KEY_NONE:
			printerr("render-shell --input: no such key '%s'" % parts[1])
			continue
		pressed.append({"tick": parts[0].to_int(), "key": keycode})
	pressed.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["tick"]) < int(right["tick"]))
	return pressed


## Copy what the simulation says exists onto the visuals. This is the only place
## the two layers meet, and the traffic is one-way.
func _sync_views() -> void:
	var snapshot := _sim.world.snapshot()
	_last_snapshot = snapshot

	# No chunk loop any more. The ground on the screen is the adopted streamer's
	# and it is not asked for once a frame: `FieldTerrainStreamer` follows the
	# observer on its own worker thread and hangs its chunks in this scene. The
	# only thing this shell says about the ground is where the observer is, and
	# it says that by being the node the streamer was pointed at.
	_sync_islands(snapshot)
	_sync_settlements(snapshot)
	_sync_scatter(snapshot)
	_sync_board(snapshot)
	_sync_choice()
	_sync_combat(snapshot)
	_sync_flights(snapshot)
	_sync_ground(snapshot)
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
	# The camera is not placed here any more. The adopted world scene's own
	# camera follows the observer in its own `_physics_process`, smoothing,
	# swinging behind a walk and easing round anything that would come between
	# it and the person. What this shell still decides is the *framing* -- how
	# far behind, how far above, how far up the aim is lifted and how wide the
	# view is -- and that is said once, in `_build_scenery`, on their camera.
	_sync_foliage(observer)


## Thin whatever stands between the camera and the person, and let whatever has
## stopped standing there thicken back up.
##
## What counts as in the way is `FoliageFade`, which is a pure function of
## positions and sizes; this only finds the props worth asking about and carries
## the answer onto the nodes. Nothing about the world is touched: a prop that
## gives way is drawn differently and stands in exactly the place the simulation
## scattered it.
##
## The scatter patches and nothing else, so what grows on a floating island's top
## does not thin: an island's cover hangs off that island's own view rather than
## off a patch, and a walkable island is somewhere a person can stand. That is a
## known gap and not an oversight -- the rule itself is told positions and sizes
## and would answer for an island's tree as readily -- and closing it is another
## loop over `_island_views`, which is worth writing when somebody is actually
## standing up there.
##
## Two passes, and the second is why a tree ever comes back. The first walks the
## scatter patches near enough to hold an obstruction and works out what each
## prop's transparency should be; the second walks the props that were being
## thinned on the *previous* frame and were not named by the first -- the ones
## the person has walked out from behind, or that the streamer is about to
## unload -- and moves them back towards solid. A node is dropped from the
## record the moment it is solid again, so a clear view costs an empty loop.
func _sync_foliage(observer: Vector3) -> void:
	if not _fade_foliage:
		return
	var began := Time.get_ticks_usec()
	var thinned := 0
	var camera := _camera.position
	# How far from the person a prop can stand and still cross the sight line:
	# the whole length of that line, plus the fattest crown anything could be
	# drawn with. A patch further away than this holds nothing worth measuring.
	var reach := _camera_offset.length() + FoliageFade.WIDEST_CROWN
	var named := {}
	for key in _scatter_views:
		if ScatterPatch.distance_to_patch(key, observer.x, observer.z) > reach:
			continue
		for node in (_scatter_views[key] as Node3D).get_children():
			if not (node is Node3D):
				continue
			var prop := node as Node3D
			var covered := FoliageFade.cover(
				camera, observer, prop.position,
				float(prop.get_meta("crown", 0.0)),
				float(prop.get_meta("stands", 0.0)),
			)
			var want := FoliageFade.transparency_for(covered)
			var id := prop.get_instance_id()
			if want <= 0.0 and not _foliage_fades.has(id):
				continue
			named[id] = true
			thinned += _thin(prop, want)
	for id in _foliage_fades.keys():
		if named.has(id):
			continue
		if not is_instance_id_valid(id):
			_foliage_fades.erase(id)
			continue
		thinned += _thin(instance_from_id(id) as Node3D, 0.0)
	_foliage_thinned = maxi(_foliage_thinned, thinned)
	_foliage_usec += Time.get_ticks_usec() - began
	_foliage_frames += 1


## Move one prop a frame's worth towards the transparency it should have, and
## carry that onto the meshes under it.
##
## The engine's own per-instance transparency rather than a material of this
## prop's own: the pack models share their materials between every copy of a
## tree in the world, so fading a material would fade the forest. It also leaves
## the shadow alone, which is the point -- a tree that thins still lies across
## the grass, so the picture goes on saying there is a tree there.
##
## Hands back 1 if the prop is still being thinned after this frame's step and 0
## if it has arrived back at solid, so the caller can count a frame's work
## without walking the record a second time.
func _thin(prop: Node3D, want: float) -> int:
	var id := prop.get_instance_id()
	var now := float(_foliage_fades.get(id, 0.0))
	var next := FoliageFade.toward(now, want, _last_delta)
	if next <= 0.0:
		_foliage_fades.erase(id)
		_wash(prop, 0.0)
		return 0
	_foliage_fades[id] = next
	_wash(prop, next)
	_foliage_deepest = maxf(_foliage_deepest, next)
	return 1


## Set one transparency on every mesh under a node.
func _wash(node: Node, amount: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = amount
	for child in node.get_children():
		_wash(child, amount)


## Put the floating islands on screen, one drawable per island.
##
## The one piece of ground this shell still meshes, and the reason is named
## rather than assumed: the adopted base has no aerial layer, so there is
## nothing of theirs to build an island on. Three steps -- drop the views of
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
		var view := _build_island_view(geometry)
		_island_views_built += 1
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
	view: Node3D, key: Vector3i, island: FloatingIsland, geometry: IslandGeometry
) -> void:
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


## One scattered thing, at the height and the size the simulation gave it.
func _add_scattered(
	parent: Node3D, item: Dictionary, profile: SimBiomeProfile = null
) -> Node3D:
	var node := _add_placed(parent, item, float(item["y"]), profile)
	if node == null:
		return null
	# The size is in world units, because generation has no idea what any of
	# this looks like. The table does, so the division happens here.
	var natural := AssetLibrary.natural_height(String(item["tag"]))
	if natural > 0.0:
		node.scale = Vector3.ONE * (float(item["size"]) / natural)
	# How much room this prop takes up, measured off the model that was actually
	# built rather than off the size that was asked for. `FoliageFade` needs a
	# cylinder to test a sight line against and the packs do not agree on how
	# wide a thing of a given height is -- a fir is a third as broad as it is
	# tall, an oak nearly as broad as tall. Measured once, here, because this is
	# the one moment the node exists and nothing has been asked of it yet; a
	# per-frame measurement of every tree in the meadow would cost more than the
	# rule it feeds.
	var box := _bounds_of(node, Transform3D.IDENTITY)
	node.set_meta("crown", maxf(box.size.x, box.size.z) * 0.5 * node.scale.x)
	node.set_meta("stands", box.size.y * node.scale.y)
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
	profile: SimBiomeProfile = null,
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
	#
	# "A fight is on" is asked of the person this run is about rather than of the
	# world, for the reason `CombatPanel.read_id` gives: a board somebody has
	# walked off is not their board, and a lattice still drawn under them says
	# they are on it.
	var fight_board: int = int(combat["board_version"]) if _on_a_board(snapshot) else -1
	var here := CombatBoard.cell_of(
		float(snapshot["observer_x"]), float(snapshot["observer_z"])
	)
	var lifted: bool = snapshot["observer_on_island"]
	if here == _board_cell and lifted == _board_lifted and fight_board == _board_fight:
		return
	_board_cell = here
	_board_lifted = lifted
	_board_fight = fight_board
	# A run that did not ask for the squares gets them only while a fight is on,
	# and gets them taken away when it ends. The overworld is not a board and
	# must not be drawn as one; a fight is, from the tick it begins.
	if fight_board < 0 and not _lattice_always:
		_board_view.mesh = null
		_board_surface = {}
		_board_reach = Rect2()
		_board_cells = 0
		_board_holes = 0
		return
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
			# Which of the legend's rows this cell reads as, and the colour
			# filed under it. The order the five are tested in is the table's,
			# not this loop's, so the legend is read in the order the painting
			# decides.
			var key := BoardLegend.lattice_key(board, cell)
			if key == BoardLegend.HOLE:
				holes += 1
			# Which of that meaning's shades this cell is painted in: ordinary
			# ground is checkered by the parity of the cell, so a field of it
			# reads as squares rather than as one sheet. The parity is the
			# table's and not this loop's.
			var tint := BoardLegend.shade_of(key, cell)
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
			var edge := BoardLegend.edge_of(tint)
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
		# The controls, so the sheet can mark which carried thing they are aimed
		# at, and the way a button press leaves the panel: the shell's own input
		# path, so a click and a key press are one thing. Both are handles; the
		# panel reads the first every frame and stores nothing off it.
		_sheet_ui.panel.controls = _controls
		if _playing and not _sheet_ui.panel.on_key.is_valid():
			_sheet_ui.panel.on_key = _drive
	# The world itself, for the readout: the same handle every frame, so that a
	# restart onto a different world is picked up without anything being pushed.
	# What is on the readout it reads through render/ui/fight_source.gd.
	if _sheet_ui.readout != null:
		# The readout is about whoever the run is about: the character being
		# driven when somebody is playing, and otherwise the one the world is
		# looking through. It draws the board *they* are standing on -- see
		# `CombatPanel.read_id`.
		_sheet_ui.readout.watch(
			_sim.world, _sim.driven_id if _playing else _sim.world.follow_id)
		# And, in a run somebody is playing, the three handles the controls need:
		# where to ask for the turn standing now, what has been picked to spend
		# it on, and the shell's own input path, so that a button and a key are
		# one thing. The first is a call rather than a turn, so the panel reads
		# the turn on the frame it draws and keeps no copy of it.
		if _playing and not _sheet_ui.readout.on_key.is_valid():
			_sheet_ui.readout.play(
				_sim.driven_turn, _board_controls, _drive_the_board)
	# And the answer panel, the same way: the world, who is being driven and
	# where their choices go. It reads all three again on every frame.
	if _sheet_ui.answer != null:
		_sheet_ui.answer.watch(_sim.world, _sim.driven_id, _sim.driven)
	# And what there is to choose from: the world, who is being driven and the
	# controls they are driving with. The panel reads the world again on every
	# frame and keeps no copy of what it says.
	if _sheet_ui.play != null:
		_sheet_ui.play.watch(_sim.world, _sim.driven_id, _controls)
	# The two reading panels follow whoever the run is about: the character
	# being driven when somebody is playing, and otherwise the one the world is
	# looking through -- a photographed scenario has a followed character and
	# nobody driving. Both panels read the world again on every frame.
	var read_id := _sim.driven_id if _playing else _sim.world.follow_id
	if _sheet_ui.dialogue != null:
		_sheet_ui.dialogue.watch(_sim.world, read_id)
	if _sheet_ui.trade != null:
		_sheet_ui.trade.watch(_sim.world, read_id)
	if _sheet_ui.territory != null:
		_sheet_ui.territory.watch(_sim.world, read_id)
	# The legend is the key to the lattice, so it is shown exactly when there is
	# a lattice on screen. The shell is the one that knows; the panel is told.
	if _sheet_ui.legend != null:
		_sheet_ui.legend.show_board(_board_view != null and _board_view.mesh != null)


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


## Put whatever is flying on screen: one drawable per blow of the record whose
## effect is still crossing the board, between the cell it left and the cell it
## landed on.
##
## The same three steps every other layer gets -- drop what has landed, launch
## what is new, move the rest -- keyed by the blow the flight belongs to. What
## flies, from where to where, wearing which art and how far across it is are
## all `BlowFlights.flights()`, a pure function of the snapshot's own blow
## record; by the time a row exists here the blow has been resolved and written
## down, so nothing this draws can reach the fight. An instant blow never gets
## a row, so a swing launches nothing.
func _sync_flights(snapshot: Dictionary) -> void:
	var rows := BlowFlights.flights(snapshot)
	var still_flying := {}
	for row in rows:
		still_flying[String(row["key"])] = true
	for key in _flight_views.keys():
		if not still_flying.has(key):
			(_flight_views[key] as Node3D).queue_free()
			_flight_views.erase(key)

	for row in rows:
		var key := String(row["key"])
		var view: FlightView = _flight_views.get(key, null)
		if view == null:
			view = FlightView.new()
			add_child(view)
			view.launch(
				row["from_cell"], row["to_cell"],
				String(row["sprite"]), String(row["animation"]),
				float(row["from_height"]), float(row["to_height"]),
			)
			_flight_views[key] = view
			_flights_launched += 1
		view.show_phase(float(row["phase"]))


## Put what is lying on the ground on screen: one drawable per item, where the
## simulation says its pile is, at the height of the ground under it.
##
## The same three steps every other layer gets -- drop what has gone, add what
## has arrived, leave the rest alone -- keyed by the item's place in its pile, so
## picking one thing off a heap of five frees one node.
##
## Where each item goes is `GroundItems`, which is a pure function of the
## snapshot and holds nothing; the height is sampled here because how high the
## ground is under a point is the world's answer and not the snapshot's. An item
## is normalised to one size: what it is built from is measured and divided, so a
## bottle and a two-metre staff lie on the grass as things of the same order and
## a pile reads as a pile.
func _sync_ground(snapshot: Dictionary) -> void:
	var rows := GroundItems.placements(snapshot)
	var still_here := {}
	for row in rows:
		still_here[String(row["key"])] = true
	for key in _ground_views.keys():
		if not still_here.has(key):
			(_ground_views[key] as Node3D).queue_free()
			_ground_views.erase(key)

	for row in rows:
		var key := String(row["key"])
		var x := float(row["x"])
		var z := float(row["z"])
		var view: Node3D = _ground_views.get(key, null)
		if view == null:
			view = AssetLibrary.build(
				String(row["tag"]), _sim.world.terrain.profile_at(x, z))
			if view == null:
				continue
			add_child(view)
			# Measured after it is in the tree and before it is scaled, because
			# a model's own size is the only thing that says how much to divide
			# by -- the packs draw a sword along its height and a bow along its
			# depth, so a single axis would not do.
			var box := _bounds_of(view, Transform3D.IDENTITY)
			var factor := GroundItems.scale_for(box.size)
			view.scale = Vector3.ONE * factor
			# And it rests on the ground rather than sinking into it: the models
			# are not all drawn with their lowest point at their own origin.
			view.set_meta("floor", box.position.y * factor)
			_ground_views[key] = view
			_ground_drawn += 1
		view.position = Vector3(
			x,
			_sim.world.terrain.ground_height_at(x, z)
				- float(view.get_meta("floor", 0.0)) + GroundItems.LIFT,
			z,
		)
		view.rotation.y = float(row["yaw"])


## The box a built visual occupies, in its own space: what every mesh under it
## covers, together. The shell's own measurement of what the table handed it.
func _bounds_of(node: Node, so_far: Transform3D) -> AABB:
	var box := AABB()
	var started := false
	if node is VisualInstance3D:
		var here: AABB = so_far * (node as VisualInstance3D).get_aabb()
		box = here
		started = true
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var below := _bounds_of(child, so_far * (child as Node3D).transform)
		if below.size == Vector3.ZERO:
			continue
		box = below if not started else box.merge(below)
		started = true
	return box


## Turn one island's geometry -- plain arrays of numbers, copied out of the
## simulation -- into something the graphics card can draw. The arrays go
## straight into the mesh, which is the whole reason the copy has to be a real
## one: a mesh built from arrays that still belonged to the world would leave the
## world reachable from here.
func _build_island_view(geometry: IslandGeometry) -> MeshInstance3D:
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
	view.material_override = _island_material
	return view


## Forget everything drawn, for a restart into a different world.
##
## The ground is not in this list and cannot be: the adopted streamer owns its
## own chunks and its own worker thread, so a new world means a new streamer.
## `_restart_ground` does that; this drops what *this* shell built.
func _clear_world_views() -> void:
	for key in _island_views.keys():
		(_island_views[key] as Node3D).queue_free()
	_island_views.clear()
	_drifting.clear()
	for key in _settlement_views.keys():
		(_settlement_views[key] as Node3D).queue_free()
	_settlement_views.clear()
	for key in _scatter_views.keys():
		(_scatter_views[key] as Node3D).queue_free()
	_scatter_views.clear()
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
		"scenario": Simulation.SCENARIO_NONE, "frozen": false,
		"sheet": false, "readout": false, "dialogue": false, "trade": false,
		"territory": false,
		"aa": "", "trace": "",
		"play": false, "journal": false, "input": "", "screenshot_ticks": "",
		"camera": CAMERA_OFFSET, "aim": CAMERA_AIM_LIFT, "focus": 0.0, "fov": 0.0,
		"fade": true,
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
			"--screenshot-ticks":
				# Several moments of one run, `tick:path` and comma-separated,
				# in `--input`'s own spelling. The run quits after the last.
				if has_value:
					options["screenshot_ticks"] = args[i + 1]
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
			"--dialogue":
				# Put the dialogue panel on screen: what the followed character
				# said and what it heard, read off the same observation a
				# model-driven mind is handed. A run with --play gets it
				# unasked, for the reason it gets the sheet.
				options["dialogue"] = true
			"--trade":
				# Put the trade panel on screen: both sides of every proposal
				# standing for the followed character, and the engine's answer
				# to the last trade verb, quoted whole. A run with --play gets
				# it unasked too.
				options["trade"] = true
			"--territory":
				# Put the territory readout on screen: how the followed
				# character stands with the characters it knows of, and who
				# owns the point it is standing on -- the simulation's own
				# ownership rule asked on the frame each picture is drawn. It
				# reads and writes nothing back, so the world's fingerprint is
				# the same with it and without it -- which is what
				# tests/test_ui_territory.gd checks by running both.
				options["territory"] = true
			"--play":
				# Hand the character the world is looking through over to
				# whoever is at the keyboard: from here on its next action is
				# whatever they choose, and on every tick they have not chosen
				# anything it waits in the world while everybody else carries
				# on. It replaces that character's decision function and
				# nothing else -- same sheet, same roster, same loop, same
				# engine -- which is section 1's no-preferential-treatment
				# principle being one line rather than a promise.
				options["play"] = true
			"--journal":
				# Print the world's own control-loop journal as it is written:
				# who chose what on which tick and what the engine answered. It
				# reads the simulation and changes nothing, so a run with it and
				# a run without it have the same fingerprint.
				options["journal"] = true
			"--input":
				# Press keys on behalf of a person who is not at the keyboard:
				# "20:w,60:g,120:k", a tick and a key. This machine has no
				# display, so it is how a run showing somebody playing gets
				# taken at all; the presses go through the engine's own input
				# queue, so they arrive at the same binding a person's would.
				if has_value:
					options["input"] = args[i + 1]
			"--board":
				# Draw the tactical lattice over the ground the observer is
				# standing on. It reads the board out of the simulation and
				# draws it; it changes nothing, which is why the world's
				# fingerprint is the same with it and without it.
				options["board"] = true
			"--no-fade":
				# Foliage stops giving way in front of the person. Nothing but a
				# cost measurement wants this: it is the other half of the pair
				# of runs that prices the rule.
				options["fade"] = false
			"--no-grass":
				# Draw the world with no grass at all. The switch is now the
				# adopted streamer's own `GRASS_ENABLED`, set before its `_ready`
				# runs, so nothing is baked, instanced or shaded. It exists so
				# that "the grass changes nothing about the world" can be shown
				# by running the same seed both ways and comparing fingerprints,
				# which is what tests/test_grass.gd does.
				options["grass"] = false
			"--no-atmosphere":
				# Draw the world with none of *this game's* atmosphere layer: no
				# warm point lights, no orbs, no motes, no ground mist. The
				# adopted world still lights itself -- the sun, the sky, the
				# fog, the bloom and the depth of field belong to
				# AtmosphereDirector in the world scene this one inherits, and
				# they are not a render option. It exists so that "this layer
				# changes nothing about the world" can be shown by running the
				# same seed both ways and comparing fingerprints, which is what
				# tests/test_atmosphere.gd does.
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
## Photograph whichever of the named moments have come round, and quit after the
## last one. One row is taken per frame, so two moments a tick apart are two
## pictures and never the same picture saved twice.
func _capture_the_named_moments() -> void:
	var due: Dictionary = _screenshot_ticks[0]
	if _sim.world.tick < int(due["tick"]):
		return
	_screenshot_ticks.pop_front()
	_save_screenshot(String(due["path"]), _screenshot_ticks.is_empty())


func _save_screenshot(path: String, then_quit: bool = true) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("render-shell screenshot t=%d %s" % [_sim.world.tick, path])
	else:
		printerr("render-shell screenshot failed (%d) for %s" % [error, path])
	if then_quit or error != OK:
		get_tree().quit(0 if error == OK else 1)


func _build_scenery() -> void:
	# The camera is the adopted world scene's own, found in `_enter_tree`, and
	# what happens here is framing rather than building. Their camera holds the
	# person from behind and above, eases after a walk and swings round anything
	# that would come between it and the body; this says how far behind, how far
	# above, how far up the aim is lifted and how wide the view is, which is
	# exactly the three dials `--camera`, `--aim` and `--fov` turn.
	#
	# Pushing the far plane out to the far-sky islands stretches the depth
	# buffer, and moving the near plane out with it keeps the precision where
	# the world is, which is what stops the ground shadow-fighting with itself.
	_camera.near = 1.0
	_camera.far = CAMERA_FAR
	if _camera_fov > 0.0:
		_camera.fov = _camera_fov
	# `--camera x y z` is an offset from the person: how far above is the y, and
	# how far behind is the length of the other two, which is the pair their
	# camera is steered by. The default (0, 10.5, 13.0) is 10.5 up and 13.0
	# back, which is the framing reports/camera-read.md was composed at.
	_camera_rig.set("height", maxf(_camera_offset.y, 1.4))
	_camera_rig.set("distance", Vector2(_camera_offset.x, _camera_offset.z).length())
	_camera_rig.set("aim_lift", _camera_aim)
	_camera_rig.set("target", _observer_holder())
	# Where the miniature depth of field is focused, when a capture asks for
	# somewhere other than the person. The band itself is the adopted
	# director's -- it built the CameraAttributes in its own `_ready`, which
	# has already run by the time this does -- so this moves that band rather
	# than building a second one. The two distances keep their ratio to the
	# focus, which is what stops a detail shot going soft all over.
	if _camera_focus > 0.0:
		var attributes := _camera.attributes as CameraAttributesPractical
		if attributes != null:
			var was := attributes.dof_blur_far_distance
			var near_share := attributes.dof_blur_near_distance / maxf(was, 0.001)
			attributes.dof_blur_far_distance = _camera_focus * DOF_FAR_SHARE
			attributes.dof_blur_near_distance = \
				_camera_focus * DOF_FAR_SHARE * near_share

	# This game's half of the atmosphere: the warm point lights, the orbs, the
	# motes and the ground mist. The sun, the sky, the fog, the bloom, the fill
	# and the depth of field are the adopted `AtmosphereDirector`'s, hung in the
	# world scene this one inherits, and they stay whatever this switch says.
	# With --no-atmosphere none of *this* layer is built and the world underneath
	# is unchanged, which is what tests/test_atmosphere.gd checks by
	# fingerprinting the two runs against each other.
	if _atmosphere != null:
		_atmosphere.attach(self, _world_environment)
		# Start on the mood of wherever the observer opened its eyes, so the
		# first frame already has the right air in it.
		_atmosphere.take(_sim.world.observer_profile(), Vector3(
			_sim.world.observer_x, _sim.world.observer_y, _sim.world.observer_z
		))

	# The islands' own surfaces. Flat-shaded and untextured on purpose: the
	# colour is not chosen here -- the material takes it from the per-vertex
	# tint the simulation generated, so the palette lives in the biome catalog
	# and this is only the wiring that shows it.
	# The observer wears whichever model OBSERVER_TAG names. Nothing about it
	# reaches the simulation, which holds a position, a heading and how fast it
	# is going and has never heard of an animation.
	(_observer_view as CharacterView).set_model(OBSERVER_TAG)

	_island_material = StandardMaterial3D.new()
	_island_material.albedo_color = Color(1.0, 1.0, 1.0)
	_island_material.vertex_color_use_as_albedo = true
	# The tints the simulation writes are ordinary colours, the same numbers a
	# painter would name; the renderer works in linear light. Saying so here is
	# what keeps a dark marsh floor dark instead of washing it out by two stops.
	_island_material.vertex_color_is_srgb = true

	# The islands' ponds and waterfalls, as two materials built once and shared
	# by every pond and every fall on screen, so they all run off one clock and
	# a fall that streams in mid-flight does not start from the beginning.
	_water_material = ShaderMaterial.new()
	var water_shader := Shader.new()
	water_shader.code = ISLAND_WATER_SHADER
	_water_material.shader = water_shader
	_fall_material = ShaderMaterial.new()
	var fall_shader := Shader.new()
	fall_shader.code = FALL_SHADER
	_fall_material.shader = fall_shader


## The adopted streamer has finished the chunks it holds a run back for.
func _on_ground_ready() -> void:
	_ground_ready = true
	print("render-shell ground ready frames=%d seed=%d" % [_frames, _ground.world_seed])
	# The camera has been framing an observer standing over nothing; now that
	# there is ground it is put where it belongs outright rather than eased.
	(_camera_rig as Node).call("snap")


## Start the adopted ground again on a different seed.
##
## The streamer builds its plans once, in its own `_ready`, and runs a worker
## thread off them, so a new world is a new streamer rather than a reseeded one.
## Freeing the node is what stops that thread -- `FieldTerrainStreamer._exit_tree`
## joins it -- and the replacement is stood up with the same exports the world
## scene authored, pointed at the same observer, with the new seed.
func _restart_ground() -> void:
	var settings := {
		"CHUNK_RADIUS": _ground.CHUNK_RADIUS,
		"KEEP_RADIUS": _ground.KEEP_RADIUS,
		"GRASS_ENABLED": _ground.GRASS_ENABLED,
	}
	var old := _ground
	remove_child(old)
	old.queue_free()
	var fresh := FieldTerrainStreamer.new()
	fresh.name = "FieldTerrain"
	for key in settings:
		fresh.set(key, settings[key])
	fresh.SEED_OVERRIDE = _sim.world.world_seed
	fresh.player = _observer_view
	fresh.terrain_parent = fresh
	add_child(fresh)
	_ground = fresh
	_ground_ready = false
	fresh.startup_loading_completed.connect(_on_ground_ready, CONNECT_ONE_SHOT)
	if _atmosphere_director != null:
		_atmosphere_director.streamer = fresh


## The node the adopted camera and the adopted streamer follow.
##
## Both were pointed at the world scene's own `Characters/Character` when the
## scene was authored, and that is the node this shell keeps them on: the
## observer *is* that character. Handing them a node this shell made instead
## would be the base's world following ours around, which is the thing this
## seam is not allowed to do.
func _observer_holder() -> Node3D:
	return _observer_view
