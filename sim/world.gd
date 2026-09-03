extends RefCounted
## The whole state of the world at one instant.
##
## This is plain data plus the arithmetic that moves it forward. It holds no
## nodes, no scenes, no meshes and no reference to anything under res://render.
## The render shell reads it; it never reads the render shell.
##
## What exists so far is the ground: an endless stack of fields behind one
## terrain query, a mesher that turns it into chunk geometry, a streamer that
## keeps the chunks near the observer built, one sheet of water lying over all
## of it, a sparse layer of floating islands above it, a sparse layer of villages
## and the roads between them cut into it, the flora and props scattered over the
## lot, and a cast of characters living on top of all of it.
##
## ## The world holds a cast, and asks it
##
## `step()` services every character in the world through one `ControlLoop` over
## the world's own `ActionScene` -- the same loop, over the same class of scene,
## that the headless character runs are played on. So there is one path: the
## render shell and the headless runner both call this `step()`, and what happens
## in it is that everybody is asked what they are doing and `ActionEngine`
## answers. Nothing in this file decides anything for anybody; the deciding is on
## `Character.decide`, and who put it there is `sim/world_cast.gd`'s business or a
## scenario's.
##
## The observer is no longer a walker of its own. It is the world's *view*: the
## position the terrain streams around and the camera is put behind, and it is
## read off whichever character `follow_id` names. Being followed is the whole of
## what that character gets -- it is asked the same question on the same tick as
## everybody else. With nobody followed the observer stands where it was put,
## which is what a scenario wanting a fixed camera beside a fight asks for.
class_name SimWorld

## The seed every random decision in this world descends from.
var world_seed: int = 0

## How many times step() has been called.
var tick: int = 0

## Everything anything asks about a patch of ground: how high it is, which
## biome it belongs to, whether it is water, whether it is a bank, and whether
## it can be walked on. Sampled, never stored. It is just as much a part of the
## world as the observer is: what a place is like is a fact about the place, not
## about the picture of it.
var terrain: TerrainQuery = null

## The ground's height and its biomes, reachable directly for the things that
## want one layer rather than the composed answer. Both are the query's.
var surface_field: TerrainSurfaceField = null
var biome_field: BiomeField = null

## Turns the fields into per-chunk geometry.
var chunk_mesher: TerrainChunkMesher = null

## Keeps the chunks near the observer built and drops the rest.
var terrain_streamer: TerrainStreamer = null

## Where the floating islands are. The query's, reachable directly for the same
## reason the height and biome fields are.
var island_field: IslandField = null

## Keeps the islands near the observer built and drops the rest, on the same
## rule the ground streamer follows.
var island_streamer: IslandStreamer = null

## Where the villages are and what stands in them, and which places the roads
## join. Both are the query's, reachable directly for the same reason the height
## and biome fields are.
var settlement_field: SettlementField = null
var path_network: PathNetwork = null

## Keeps the villages and roads near the observer loaded, on the same rule
## again.
var settlement_streamer: SettlementStreamer = null

## What grows and what stands on the ground: the flora and props scattered per
## cell over everything above. The query's fields decide where it may go; this
## decides what goes there.
var scatter_field: DecorationScatter = null

## Keeps the dressing of the chunks near the observer built, on the ground
## streamer's own rule, so dressing and ground appear and vanish together.
var scatter_streamer: ScatterStreamer = null

## Builds the one sheet of water around the observer.
var water_sheet_builder: WaterSheetBuilder = null

## Reads a rectangle of the world as a tactical board. Nothing streams it and
## nothing keeps one: a board is built for a fight when there is a fight, and
## read off the terrain query alone, so it has no state to fall out of step with
## the world.
var combat_board_builder: CombatBoardBuilder = null

## Everyone in the world who can fight, and whichever fight is under way. Its
## `scene` is the world's action scene: where everybody stands, what is lying
## about, what has been said and what has been offered.
##
## An ordinary world fills it with `WorldCast.muster`; a scenario clears it and
## fills it with its own cast (see sim/scripted_encounter.gd and
## sim/scripted_scenario.gd). An empty roster is still stepped, fingerprinted and
## snapshotted as nothing at all, so a world somebody has emptied is exactly the
## world it was before combat existed.
var combat: CombatantRoster = null

## What asks the cast what it is doing: section 2.2's control loop, over the
## roster's scene. Rebuilt whenever the cast is, because a loop remembers what
## each character is part-way through and a new cast is part-way through nothing.
##
## Its bias draws are hashed from the world seed, so two worlds of one seed ask
## and answer identically.
var loop: ControlLoop = null

## Which member of the cast the world looks through, or 0 for nobody.
##
## The camera follows the observer and the terrain streams around it, so this is
## the one thing a character can be given that the others are not. It is given by
## `follow()` and taken away by `place_observer()`, which stands the view
## somewhere and leaves it there.
var follow_id: int = 0

## Whatever the fights in this world have written down, in order. The world
## carries it rather than the entry point, because a fight is something that
## happened in the world.
var combat_lines := PackedStringArray()

## How many times the water sheet has been rebuilt. A viewer watches this rather
## than the sheet itself, so it only re-reads the water when there is new water
## to read -- the sheet is one object covering a wide window, and most ticks do
## not move the window at all.
var water_sheet_version: int = 0

## How many detached copies water_sheet() has ever handed out. Diagnostic only,
## and the same diagnostic the streamer keeps for chunks.
var water_sheets_handed_out: int = 0

# The live sheet, and the window centre it was built for. Handed out only as a
# copy, for the same reason chunk geometry is.
var _water_sheet: WaterSheet = null
var _water_sheet_centre := Vector2.ZERO

## Where the observer is standing, in world units.
##
## The height is state rather than a lookup, because there is more than one
## surface over a position now: standing on a floating island and standing on
## the ground under it are the same x and z. What decides which one you are on
## is where you came from, so the height has to be carried.
var observer_x: float = 0.0
var observer_z: float = 0.0
var observer_y: float = 0.0
var observer_heading: float = 0.0

## How the observer moved on the last tick: how far across the ground, and how
## far up or down. Both in world units per tick, both zero before anything has
## stepped and zero again after it is picked up and put down somewhere.
##
## These are motion, not display. A viewer cannot work them out for itself
## without remembering where the observer was last frame, and a viewer that
## remembers where the world was is a viewer holding a second copy of the world.
## So the world says. `observer_rise` is signed and is how the one-hop climb onto
## a floating island's rim reaches anyone watching: nothing else in the world
## lifts a walker off the surface it was on.
##
## Deliberately outside digest(): both are differences of a position the
## fingerprint already covers, so folding them in would fold the same fact in
## twice and would move the fingerprint of a world that has not changed.
var observer_speed: float = 0.0
var observer_rise: float = 0.0


func _init(seed_value: int = 0) -> void:
	reset(seed_value)


## Rebuild the world from scratch for the given seed. Called by the constructor,
## and callable again to restart without allocating a new world.
func reset(seed_value: int) -> void:
	world_seed = seed_value
	tick = 0
	terrain = TerrainQuery.for_seed(seed_value)
	surface_field = terrain.surface_field
	biome_field = terrain.biome_field
	island_field = terrain.island_field
	settlement_field = terrain.settlement_field
	path_network = terrain.path_network
	chunk_mesher = TerrainChunkMesher.new(terrain)
	terrain_streamer = TerrainStreamer.new(chunk_mesher)
	island_streamer = IslandStreamer.new(island_field, IslandMesher.new())
	settlement_streamer = SettlementStreamer.new(settlement_field, path_network)
	scatter_field = DecorationScatter.new(terrain)
	scatter_streamer = ScatterStreamer.new(scatter_field)
	water_sheet_builder = WaterSheetBuilder.new(terrain)
	combat_board_builder = CombatBoardBuilder.new(terrain)
	_empty_the_cast()

	observer_x = 0.0
	observer_z = 0.0
	observer_y = terrain.ground_height_at(0.0, 0.0)
	observer_heading = 0.0
	observer_speed = 0.0
	observer_rise = 0.0
	_water_sheet = null
	water_sheet_version = 0
	water_sheets_handed_out = 0
	_settle_observer()
	# The people who live here, and the one the world looks through. A scenario
	# that wants a different cast clears this one and stands up its own.
	follow_id = WorldCast.muster(self)
	_look_through_the_followed()
	_restream()


## Advance the world by one tick.
##
## The order is the whole of what this file says about a living world, and it is
## the order every character run under sim/ already keeps:
##
##   1. **everybody is asked** -- the control loop services every character in
##      the world: what it is part-way through runs on, what has run out is
##      resolved by `ActionEngine`, and whoever is free is asked again. Nothing
##      here knows whether the answer came from a rule, a model or a person.
##   2. **the combatants walk and the fight takes its turn** -- the roster's own
##      step, unchanged, which is also where a fight begins when two commanders
##      of different bands have met.
##   3. **the world is built around them** -- the view moves to whoever is being
##      followed, and the ground, the islands, the villages, the dressing and the
##      water are streamed to it.
##
## Streaming last rather than first is deliberate: the ground is built around
## where the cast actually got to on this tick, not around where it was on the
## last one.
func step() -> void:
	# Where everybody stood before anything was asked, so that after the tick the
	# world can say how each of them actually moved. It is the same reading
	# `observer_speed` and `observer_rise` are, taken for the whole cast rather
	# than only for the one being looked through, and it is the world's to take
	# because a viewer that worked it out for itself would be a viewer keeping a
	# second copy of where everybody was.
	var stood := {}
	for one in combat.members:
		stood[one.id] = Vector3(one.x, one.y, one.z)
		# Last tick's jump belonged to last tick.
		one.jumped = false

	loop.step()
	combat_lines.append_array(combat.step(terrain))
	_note_how_the_cast_moved(stood)

	# What the view came to. The distance across is how far the character being
	# followed actually got; the rise is whatever settling on the surface added,
	# which is a hop onto an island rim or a drop off one. With nobody followed
	# the view stands still and both are zero.
	var was_x := observer_x
	var was_y := observer_y
	var was_z := observer_z
	_look_through_the_followed()
	observer_speed = Vector2(observer_x - was_x, observer_z - was_z).length()
	observer_rise = observer_y - was_y
	_restream()
	tick += 1


## Take everybody out of the world, so that a cast can be stood up in an empty
## one. What every scenario's muster calls before it puts its own people in.
##
## The loop goes with them: it remembers what each character was part-way
## through, and a new cast is part-way through nothing.
func clear_cast() -> void:
	_empty_the_cast()
	follow_id = 0


## Look through a character in the cast: the terrain streams around it and the
## camera is put behind it. Being followed is the whole of what it gets.
##
## Zero, or an id nobody has, means nobody is followed and the view stays where
## it is.
func follow(id: int) -> void:
	follow_id = id
	_look_through_the_followed()
	_restream()


## The character the world is looking through, or null.
func followed() -> Combatant:
	return null if follow_id == 0 else combat.member_of(follow_id)


# Whether that character jumped on this tick. False with nobody followed, which
# is what a view standing still did.
func _followed_jumped() -> bool:
	var one := followed()
	return one != null and one.jumped


# A fresh roster, its scene standing on this world's ground, and a fresh loop
# over it.
func _empty_the_cast() -> void:
	combat = CombatantRoster.new()
	combat.scene.terrain = terrain
	loop = ControlLoop.on(combat.scene, world_seed)
	combat_lines = PackedStringArray()


# How far each character got on this tick, written onto the character. Somebody
# who was not in the world when the tick started reads as having stood still,
# which is what arriving is: nothing moved it, it was put down.
func _note_how_the_cast_moved(stood: Dictionary) -> void:
	for one in combat.members:
		var was: Vector3 = stood.get(one.id, Vector3(one.x, one.y, one.z))
		one.moved = Vector2(one.x - was.x, one.z - was.z).length()
		one.rose = one.y - was.y


# Put the view where the followed character is standing, facing the way it just
# moved. Nothing happens when nobody is followed.
func _look_through_the_followed() -> void:
	var one := followed()
	if one == null:
		return
	var moved := Vector2(one.x - observer_x, one.z - observer_z)
	observer_x = one.x
	observer_z = one.z
	observer_y = one.y
	if moved.length() > 0.0001:
		observer_heading = fposmod(atan2(moved.y, moved.x), TAU)


# Build the ground, the islands, the villages and the dressing around the view,
# and refresh the water under it.
func _restream() -> void:
	terrain_streamer.update(observers())
	island_streamer.update(observers())
	settlement_streamer.update(observers())
	scatter_streamer.update(observers())
	_refresh_water_sheet()


## Everyone the streamer keeps ground under. One for now.
func observers() -> Array[Vector2]:
	return [Vector2(observer_x, observer_z)]


## How high the ground is under the observer: the carved ground, so an observer
## standing in a river bed stands in the river bed. This is the ground plane
## even when the observer is on an island above it.
func observer_ground_height() -> float:
	return terrain.ground_height_at(observer_x, observer_z)


## How high the observer actually is: the surface it is standing on, which is an
## island's top when it is on one and the ground otherwise.
func observer_surface_height() -> float:
	return observer_y


## Whether the observer is standing on a floating island rather than on the
## ground. Being *under* one does not count.
func observer_on_island() -> bool:
	for island in terrain.islands_at(observer_x, observer_z):
		if absf(island.top_height_at(observer_x, observer_z) - observer_y) < 0.001:
			return true
	return false


## Put the observer somewhere, on the topmost surface there.
##
## The world has two storeys now, so "put it at (x, z)" is ambiguous and this
## resolves it the way anything arriving from outside would want: on the island
## if there is one, on the ground if there is not. It is what a test that wants
## an observer standing on an island uses, and what the entry points' --start
## option goes through.
##
## It also stops the view following anybody: standing it somewhere and having it
## snap back to a character on the next tick would not be standing it anywhere.
## That is what a scenario wanting a camera beside a fight asks for.
func place_observer(x: float, z: float) -> void:
	follow_id = 0
	observer_x = x
	observer_z = z
	observer_y = terrain.surface_height_at(x, z)
	# Put down, not walked: nothing moved, so nothing is moving.
	observer_speed = 0.0
	observer_rise = 0.0
	_restream()


## Put the observer down on whatever is under it.
##
## One hop up is allowed, which is the whole of how anyone gets onto an island:
## every island's rim is placed within a hop of the highest ground beneath it, so
## walking into that stretch of its edge carries you up onto it, and walking off
## the edge anywhere else drops you back to the ground. Nothing here is physics
## -- there is no fall, only an arrival -- and there is nothing to fall through,
## because the surface is looked up rather than collided with.
func _settle_observer() -> void:
	var support := terrain.support_at(observer_x, observer_z, observer_y)
	if support == -INF:
		# Over water: the observer has no gameplay meaning yet and is not stopped
		# by it, so it wades along the bed rather than standing on nothing. The
		# bed is whichever storey it was on -- the ground beside a lake, and the
		# floor of the basin when the water is a pond on an island.
		observer_y = terrain.wading_height_at(observer_x, observer_z, observer_y)
		return
	observer_y = support


## Whether the observer is standing in water, and whether it is on a bank. The
## observer has no gameplay meaning yet and is not stopped by either; these are
## here because they are what a character will be asking, and because they put
## the water into the traced report where two runs can be compared on it.
##
## The water question is asked of the storey the observer is on, so an observer
## in a pond on a floating island reports being in water and one standing on the
## island above a lake does not.
func observer_in_water() -> bool:
	return terrain.is_water_at(observer_x, observer_z, observer_y)


func observer_on_bank() -> bool:
	return terrain.is_bank_at(observer_x, observer_z)


## The village the observer is standing in, or null. Its name in the trace is
## how a headless run says "it walked through the village".
func observer_settlement() -> Settlement:
	return terrain.settlement_at(observer_x, observer_z)


## How much of a road the observer is standing on, in [0, 1].
func observer_on_path() -> float:
	return terrain.path_strength_at(observer_x, observer_z)


## How far out `place_near_observer()` looks for somewhere with a name, in world
## units. The road network's own linking radius, read from it rather than typed
## again: a place further away than that is not joined to where you are standing
## by anything, so "the nearest named place" would be naming somewhere with no
## way to it.
const PLACE_REACH := PathNetwork.LINK_RADIUS


## The nearest place the world has a name for, as plain data, or an empty
## dictionary when there is none in reach.
##
## The world already names two kinds of place -- a village and a landmark -- and
## the road network holds both under one description, `{id, x, z, kind, tag}`,
## because a road to a stone circle is decided exactly as a road to a village is.
## This is that description with how far away it is added, and it is a question
## about the world rather than about anybody in it: a person asking their
## character to walk somewhere named needs to know which place is meant, and so
## does a rule.
##
## Nothing about walking there is decided here. The answer is a position, which
## whoever asked turns into an ordinary `Action.go_to` for the engine to resolve
## or refuse like any other.
func place_near_observer(reach: float = PLACE_REACH) -> Dictionary:
	var nearest := INF
	var found := {}
	for place in path_network.places_near(observer_x, observer_z, reach):
		var gap := Vector2(
			float(place["x"]) - observer_x, float(place["z"]) - observer_z
		).length()
		if gap >= nearest:
			continue
		nearest = gap
		found = place.duplicate()
		found["distance"] = gap
	return found


## Which biome the observer is standing in.
func observer_biome() -> String:
	return biome_field.biome_at(observer_x, observer_z)


## The blended look of where the observer is standing, as plain data.
##
## Built fresh on every call out of the catalog, so what comes back belongs to
## the caller: a viewer that writes into it changes nothing here. This is the
## whole surface through which the world's mood reaches a viewer -- colours,
## fog, sky and ambient light are read off it, never decided by it.
func observer_profile() -> BiomeProfile:
	return biome_field.profile_at(observer_x, observer_z)


## The water around the observer, as anyone outside the simulation gets it: a
## detached copy of the one sheet. Copying is what keeps a viewer from editing
## the world's water, exactly as it does for chunk geometry, and it is paid once
## per rebuild rather than once per frame because a viewer watches
## water_sheet_version to decide when to ask again.
func water_sheet() -> WaterSheet:
	if _water_sheet == null:
		return null
	water_sheets_handed_out += 1
	return _water_sheet.detached_copy()


## The live sheet itself. Only the simulation may use this -- writing into what
## it returns changes the world, which is why the world's fingerprint reads the
## water through here rather than through a copy of it.
func live_water_sheet() -> WaterSheet:
	return _water_sheet


## Rebuild the water sheet if the observer has left the window it was built for.
##
## The window is snapped, so walking mostly does not move it; when it does, the
## new sheet is built on the same world-fixed lattice as the old one, so the
## water does not shift under the viewer at the moment of the rebuild.
func _refresh_water_sheet() -> void:
	var centre := WaterSheetBuilder.window_centre_for(observer_x, observer_z)
	if _water_sheet != null and centre.is_equal_approx(_water_sheet_centre):
		return
	_water_sheet_centre = centre
	_water_sheet = water_sheet_builder.build(centre)
	water_sheet_version += 1


## The tactical board over a rectangle of world around a position, read on the
## storey reached from `from_height`.
##
## Built on demand and handed straight over: a board is a reading of the ground,
## not a thing the world keeps, so there is nothing here to copy defensively and
## nothing that two callers could share by accident.
func board_around(
	x: float, z: float, from_height: float,
	span: float = CombatBoardBuilder.DEFAULT_SPAN,
) -> CombatBoard:
	return combat_board_builder.build(x, z, from_height, span)


## The tactical board around the observer, on the storey the observer is on.
func board_here(span: float = CombatBoardBuilder.DEFAULT_SPAN) -> CombatBoard:
	return board_around(observer_x, observer_z, observer_y, span)


## The board the fight under way is on, as a detached copy, or null when no
## fight is on. The roster's, forwarded, so a viewer has one place to ask.
func combat_board() -> CombatBoard:
	return combat.board_copy()


## A read-only copy of the state a viewer needs. The render shell is handed one
## of these; handing over a copy is what keeps a viewer from mutating the world.
##
## Chunk geometry is deliberately not carried in here -- it is large, and most
## frames add no chunks at all. A viewer reads it off the streamer for the
## coordinates this lists, one chunk at a time, and what the streamer hands over
## is itself a detached copy, so that route cannot write into the world either.
## The islands are listed and read the same way.
func snapshot() -> Dictionary:
	return {
		"seed": world_seed,
		"tick": tick,
		"chunk_size": TerrainChunkMesher.CHUNK_SIZE,
		"observer_x": observer_x,
		"observer_z": observer_z,
		"observer_y": observer_y,
		"observer_ground_y": observer_ground_height(),
		"observer_heading": observer_heading,
		"observer_speed": observer_speed,
		"observer_rise": observer_rise,
		# And whether what moved the character being looked through was a jump.
		# Read off that character, so a shell drawing its own observer says the
		# same thing about it as the diorama says about everybody else.
		"observer_jumped": _followed_jumped(),
		"observer_biome": observer_biome(),
		"observer_in_water": observer_in_water(),
		"observer_on_bank": observer_on_bank(),
		"observer_on_island": observer_on_island(),
		# Which member of the cast the view is reading, or 0. A viewer that draws
		# an observer of its own needs to know when the observer it would draw is
		# already on screen as one of the characters.
		"observer_follows": follow_id,
		"loaded_chunks": terrain_streamer.loaded_keys(),
		"loaded_islands": island_streamer.loaded_keys(),
		"loaded_settlements": settlement_streamer.loaded_keys(),
		"loaded_scatter": scatter_streamer.loaded_keys(),
		"loaded_roads": settlement_streamer.loaded_roads(),
		"observer_on_path": observer_on_path(),
		"water_sheet_version": water_sheet_version,
		# The combat layer, as one nested dictionary of plain numbers and tags.
		# Everything a viewer needs to draw a fight is in here; there is nothing
		# else for it to read and nothing for it to remember between frames.
		"combat": combat.snapshot(),
	}


## A short, stable fingerprint of the current state.
##
## Two worlds with the same digest at the same tick are the same world for every
## purpose the determinism test cares about. It folds in every loaded chunk's
## own fingerprint, in sorted coordinate order, so it covers the terrain as well
## as the observer, and so the order the chunks happened to be built in cannot
## change it. Positions are rendered at fixed precision first so that the
## fingerprint does not depend on how floats happen to print.
func digest() -> String:
	var parts := PackedStringArray()
	parts.append("seed=%d" % world_seed)
	parts.append("tick=%d" % tick)
	parts.append("observer=%.6f,%.6f,%.6f,%.6f" % [
		observer_x, observer_z, observer_y, observer_heading,
	])
	parts.append("island=%d" % (1 if observer_on_island() else 0))
	parts.append("path=%.4f" % observer_on_path())
	parts.append("biome=%s:%s" % [observer_biome(), observer_profile().digest()])
	parts.append("water=%s:%s" % [
		"in" if observer_in_water() else ("bank" if observer_on_bank() else "dry"),
		_water_sheet.digest() if _water_sheet != null else "none",
	])
	for key in terrain_streamer.loaded_keys():
		parts.append("%d,%d:%s" % [key.x, key.y, terrain_streamer.live_geometry(key).digest()])
	# The islands are folded in the same way and for the same reason: in sorted
	# key order, through the live geometry rather than a copy, so the fingerprint
	# answers for the aerial layer that actually exists.
	for key in island_streamer.loaded_keys():
		# The island's placement, its geometry, what is growing on it and the
		# pond standing in it, all four through the live objects: what an island
		# is dressed with is as much a part of the world as its shape, and a
		# fingerprint that read a copy would answer for the copy.
		parts.append("i%d,%d,%d:%s:%s:%s:%s" % [
			key.x, key.y, key.z,
			island_streamer.live_island(key).digest(),
			island_streamer.live_geometry(key).digest(),
			island_streamer.live_cover(key).digest(),
			island_streamer.live_water(key).digest(),
		])
	# And the villages and roads, in the same fixed key order and through the
	# live objects rather than through copies, for the same reason again: the
	# fingerprint has to answer for the settlement layer that actually exists.
	for key in settlement_streamer.loaded_keys():
		parts.append("v%d,%d:%s" % [
			key.x, key.y, settlement_streamer.live_settlement(key).digest(),
		])
	for name_of in settlement_streamer.loaded_roads():
		parts.append("r%s:%s" % [name_of, SettlementStreamer.road_digest(
			settlement_streamer.live_road(name_of)
		)])
	# And the dressing, once more in sorted key order and through the live
	# patches: what is growing on a chunk is as much a part of the world as the
	# shape of it.
	for key in scatter_streamer.loaded_keys():
		parts.append("d%d,%d:%s" % [
			key.x, key.y, scatter_streamer.live_patch(key).digest(),
		])
	# And the combatants -- but only when there are any. An empty roster adds
	# nothing at all, so a world with nobody in it fingerprints exactly as it
	# did before there was a combat layer to fingerprint.
	var fighters := combat.digest()
	if fighters != "":
		parts.append("c%s" % fighters)
	return "|".join(parts).sha256_text().substr(0, 16)
