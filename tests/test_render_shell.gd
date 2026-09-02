extends TestSuite
## The render shell boots, drives the simulation, and cannot change it.
##
## Two separate claims live here. The first is about detection: a write into the
## ground the simulation is holding must show up in the world's fingerprint, or
## no comparison of fingerprints could ever notice that rendering had meddled.
## The second is about prevention: the handle the shell is actually given is a
## detached copy, so the write it could make never reaches the world at all. The
## first check is what makes the second one mean something -- without it, "the
## digest did not change" would be indistinguishable from "the digest never
## notices anything".
##
## A third check sweeps every handle a streamer hands out -- ground geometry, an
## island and its geometry, cover and pond, the water sheet, a village, a scatter
## patch, a biome profile -- looking for the one way a detached copy can still be
## a way in: a copied container that hands some object inside it across by
## reference. Nothing reached from a handle may be the same object as anything
## reached from the world.
##
## The shell itself is launched as a subprocess under the engine's headless
## display server, at a fixed frame rate so the number of ticks it runs is
## predictable. That is the strongest available end-to-end check: rendering must
## never affect simulation, so the world the shell arrives at must be exactly the
## world a headless run arrives at from the same seed.
class_name TestRenderShell

const SEED := 5
const FIXED_FPS := 60
const FRAMES := 120
## FRAMES / FIXED_FPS seconds of simulated time, at the shell's tick rate.
const EXPECTED_TICKS := 40

## The key the handle sweep writes into a dictionary to find out whether it is
## the world's own. Chosen not to collide with anything a layer stores.
const SENTINEL := "__handle_sweep_probe"



func _init() -> void:
	suite_name = "render shell"


func run() -> void:
	_a_write_into_the_live_ground_is_visible_to_the_world_digest()
	_a_write_through_the_render_handle_cannot_reach_the_world()
	_no_handle_hands_out_anything_the_world_still_holds()
	# One launch, two questions asked of it, because starting the engine is by
	# far the slowest thing this suite does.
	var shell := _run_render_shell(FIXED_FPS, FRAMES)
	_the_shell_reaches_the_headless_world(shell)
	_copying_a_chunk_is_paid_per_chunk_not_per_frame(shell)


## The world's fingerprint has to cover the ground the world is holding.
##
## live_geometry() is the simulation's own way in to a loaded chunk -- the way
## the world's own fingerprint reads it. A write through it is a real change to
## the world, and the fingerprint has to say so. If it did not, then no
## comparison of fingerprints, including this suite's shell-versus-headless
## comparison below, could ever notice that the ground had been edited, and the
## isolation check that follows would pass for the wrong reason.
func _a_write_into_the_live_ground_is_visible_to_the_world_digest() -> void:
	var world := SimWorld.new(SEED)
	var keys := world.terrain_streamer.loaded_keys()
	check(keys.size() > 0, "a fresh world should have ground loaded around the observer")
	if keys.is_empty():
		return

	var before := world.digest()
	var key: Vector2i = keys[keys.size() / 2]
	var geometry := world.terrain_streamer.live_geometry(key)
	check(geometry != null, "chunk (%d, %d) is listed as loaded but has no geometry"
		% [key.x, key.y])
	if geometry == null:
		return

	# Raise one corner of one triangle by a millimetre.
	var original: Vector3 = geometry.vertices[0]
	geometry.vertices[0] = original + Vector3(0.0, 0.001, 0.0)
	not_equal(world.digest(), before,
		"a write through terrain_streamer.live_geometry(%d, %d) left the world digest "
		% [key.x, key.y] + "unchanged: the simulation cannot detect being edited")

	# Undoing it restores the fingerprint, so the check above is reacting to the
	# contents of the ground rather than to the world having moved on.
	geometry.vertices[0] = original
	equal(world.digest(), before,
		"undoing the write did not restore the world digest")

	# And the fingerprint reads the ground itself, not a copy of it. Copying
	# first would still see this write -- the copy would be taken after it -- so
	# the write alone cannot tell the two apart; what tells them apart is that
	# taking a copy is counted, and fingerprinting the world must count none.
	var handles_before: int = world.terrain_streamer.handles_handed_out
	world.digest()
	equal(world.terrain_streamer.handles_handed_out, handles_before,
		"fingerprinting the world copied %d chunk(s): the digest is answering for "
		% (world.terrain_streamer.handles_handed_out - handles_before)
		+ "copies of the ground rather than for the ground")


## The handle the shell is given is not a way in.
##
## geometry() is the accessor render/main.gd calls, once per chunk, to get the
## numbers it hands to the graphics card. The exact write the check above proved
## is detectable is made here through that accessor instead, and this time
## nothing about the world may move.
func _a_write_through_the_render_handle_cannot_reach_the_world() -> void:
	var world := SimWorld.new(SEED)
	var keys := world.terrain_streamer.loaded_keys()
	check(keys.size() > 0, "a fresh world should have ground loaded around the observer")
	if keys.is_empty():
		return

	var before := world.digest()
	var key: Vector2i = keys[keys.size() / 2]
	var handle := world.terrain_streamer.geometry(key)
	check(handle != null, "chunk (%d, %d) is listed as loaded but has no geometry"
		% [key.x, key.y])
	if handle == null:
		return

	# It is the same ground: what the shell draws has to be what the world holds,
	# or isolation would have been bought by handing over something else.
	var live := world.terrain_streamer.live_geometry(key)
	var live_before := live.digest()
	equal(handle.digest(), live_before,
		"the geometry handed to a viewer is not the geometry of chunk (%d, %d)"
		% [key.x, key.y])
	check(handle != live,
		"terrain_streamer.geometry() handed back the loaded chunk itself")

	# Every part of it that gets drawn, written through as hard as a viewer could.
	handle.vertices[0] = handle.vertices[0] + Vector3(0.0, 0.001, 0.0)
	handle.normals[0] = -handle.normals[0]
	handle.indices[0] = 7
	handle.lowest = -999.0
	handle.chunk_x = 12345

	equal(world.digest(), before,
		"a write through terrain_streamer.geometry(%d, %d) changed the world: "
		% [key.x, key.y] + "the render layer can edit the simulation it is drawing")
	equal(world.terrain_streamer.live_geometry(key).digest(), live_before,
		"the loaded chunk (%d, %d) changed when a viewer wrote into its copy"
		% [key.x, key.y])

	# The writes did land -- on the copy. Without this, the checks above would
	# pass for a handle that silently ignored writes, or for one that was empty.
	not_equal(handle.vertices[0], live.vertices[0],
		"writing into the handed-over vertices changed nothing at all, so the "
		+ "check that the world stayed put proves nothing")
	not_equal(handle.normals[0], live.normals[0],
		"writing into the handed-over normals changed nothing at all")
	not_equal(handle.indices[0], live.indices[0],
		"writing into the handed-over indices changed nothing at all")


## No handle shares anything with the world it describes.
##
## The checks above write into a handle and watch the world; this one asks the
## structural question instead, of every handle at once: is any object reachable
## from the copy the same object as the one reachable from the world? That is the
## shape the island heightfields went wrong in -- every packed array duplicated,
## and two whole objects handed across untouched -- and a copy can be wrong that
## way without anyone thinking to write into the part that is shared.
##
## Three ways of sharing count, and all three are looked for: the same object,
## the same array or dictionary, and the same packed-array storage (which is
## shared by assignment in this engine and leaves nothing to compare, so it is
## found by writing a value and looking for it on the other side).
func _no_handle_hands_out_anything_the_world_still_holds() -> void:
	var world := SimWorld.new(SEED)
	# Somewhere with an island in view, so its four handles are testable.
	var island := world.island_field.island_in_cell(FloatingIsland.AERIAL, Vector2i(-4, -4))
	if island != null:
		world.place_observer(island.centre_x, island.centre_z)
	world.step()

	var handles := {}
	var chunk_keys := world.terrain_streamer.loaded_keys()
	if not chunk_keys.is_empty():
		var chunk_key: Vector2i = chunk_keys[0]
		handles["chunk geometry"] = [
			world.terrain_streamer.live_geometry(chunk_key),
			world.terrain_streamer.geometry(chunk_key),
		]
	if island != null and world.island_streamer.is_loaded(island.key()):
		var island_key := island.key()
		handles["island"] = [
			world.island_streamer.live_island(island_key),
			world.island_streamer.island(island_key),
		]
		handles["island geometry"] = [
			world.island_streamer.live_geometry(island_key),
			world.island_streamer.geometry(island_key),
		]
		handles["island cover"] = [
			world.island_streamer.live_cover(island_key),
			world.island_streamer.cover_of(island_key),
		]
		handles["island pond"] = [
			world.island_streamer.live_water(island_key),
			world.island_streamer.water_of(island_key),
		]
	handles["water sheet"] = [world._water_sheet, world.water_sheet()]
	var scatter_keys := world.scatter_streamer.loaded_keys()
	if not scatter_keys.is_empty():
		var scatter_key: Vector2i = scatter_keys[0]
		handles["scatter patch"] = [
			world.scatter_streamer.live_patch(scatter_key),
			world.scatter_streamer.patch(scatter_key),
		]
	var village_keys := world.settlement_streamer.loaded_keys()
	if not village_keys.is_empty():
		var village_key: Vector2i = village_keys[0]
		handles["settlement"] = [
			world.settlement_streamer.live_settlement(village_key),
			world.settlement_streamer.settlement(village_key),
		]
	var biome := world.biome_field.biome_at(world.observer_x, world.observer_z)
	handles["biome profile"] = [
		BiomeCatalog._built().get(biome, null), BiomeCatalog.profile(biome),
	]

	# Every handle the render shell can reach is in here. If one goes missing --
	# because nothing of that kind happened to be loaded -- the sweep would
	# quietly stop covering it, so the count is checked too.
	equal(handles.size(), 9,
		"the handle sweep covered %d of the 9 handle kinds; something the world "
		% handles.size() + "hands out was not loaded to test")
	for label in handles:
		var live: Object = handles[label][0]
		var handle: Object = handles[label][1]
		check(live != null and handle != null,
			"the %s handle or the live object behind it is missing" % label)
		if live == null or handle == null:
			continue
		check(live != handle, "%s: the handle IS the live object" % label)
		var shared := PackedStringArray()
		_shared_between(live, handle, "", shared)
		equal(shared.size(), 0, "%s: the handle shares %s with the world"
			% [label, ", ".join(shared)])


## Every place the two values reach the same thing, as paths into them.
func _shared_between(
	live: Variant, copy: Variant, path: String, shared: PackedStringArray
) -> void:
	if live is Object and copy is Object:
		if live == copy and path != "":
			shared.append("%s (the same object)" % path)
			return
		for property in (live as Object).get_property_list():
			if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var name_of: String = property["name"]
			_shared_between((live as Object).get(name_of), (copy as Object).get(name_of),
				"%s.%s" % [path, name_of], shared)
		return
	if live is Array and copy is Array:
		var live_array: Array = live
		var copy_array: Array = copy
		var was := live_array.size()
		copy_array.append(copy_array[0] if copy_array.size() > 0 else null)
		var same := live_array.size() != was
		copy_array.resize(copy_array.size() - 1)
		if same:
			shared.append("%s (the same array)" % path)
			return
		for i in mini(live_array.size(), copy_array.size()):
			_shared_between(live_array[i], copy_array[i], "%s[%d]" % [path, i], shared)
		return
	if live is Dictionary and copy is Dictionary:
		var live_map: Dictionary = live
		var copy_map: Dictionary = copy
		copy_map[SENTINEL] = true
		var same := live_map.has(SENTINEL)
		copy_map.erase(SENTINEL)
		live_map.erase(SENTINEL)
		if same:
			shared.append("%s (the same dictionary)" % path)
			return
		for key in live_map:
			if copy_map.has(key):
				_shared_between(live_map[key], copy_map[key], "%s[%s]" % [path, key], shared)
		return
	if _is_packed(live) and _is_packed(copy) and live.size() > 0 and copy.size() > 0:
		var was_value: Variant = live[0]
		var probe: Variant = copy[0]
		copy[0] = _nudged(probe)
		var same: bool = live[0] != was_value
		copy[0] = probe
		if same:
			shared.append("%s (the same storage)" % path)


func _is_packed(value: Variant) -> bool:
	return value is PackedVector3Array or value is PackedVector2Array \
		or value is PackedFloat32Array or value is PackedFloat64Array \
		or value is PackedInt32Array or value is PackedInt64Array \
		or value is PackedColorArray or value is PackedStringArray


## The same value, changed, whatever kind of value it is.
func _nudged(value: Variant) -> Variant:
	if value is float:
		return float(value) + 1.0
	if value is int:
		return int(value) + 1
	if value is Vector3:
		return (value as Vector3) + Vector3.ONE
	if value is Vector2:
		return (value as Vector2) + Vector2.ONE
	if value is Color:
		return Color(1.0, 0.0, 1.0, 1.0)
	if value is String:
		return String(value) + "-x"
	return value


func _the_shell_reaches_the_headless_world(shell: Dictionary) -> void:
	equal(shell["exit_code"], 0, "render shell should exit 0 (output: %s)" % shell["output"])

	var output: String = shell["output"]
	check(output.contains("render-shell boot seed=%d" % SEED),
		"render shell did not report booting with seed %d: %s" % [SEED, output])

	var shell_digest := _digest_from(output)
	check(shell_digest != "", "render shell did not report a final world digest: %s" % output)
	check(output.contains("tick=%d " % EXPECTED_TICKS),
		"render shell should have run %d ticks: %s" % [EXPECTED_TICKS, output])

	# The same seed, run without any renderer at all.
	var headless := Simulation.new(SEED)
	headless.run(EXPECTED_TICKS)
	equal(shell_digest, headless.world.digest(),
		"rendering changed the simulation: the shell and a headless run of seed %d "
		% SEED + "reached different worlds at tick %d" % EXPECTED_TICKS)


## Copying a chunk on the way out costs something, so it has to be paid once per
## chunk and not once per frame.
##
## The shell reports how many frames it drew, how many chunk views and how many
## chunks of grass it built, and how many copies it asked the streamer for.
## Running it twice over the same two seconds of simulated time --
## once at 60 frames per second, once at 240 -- holds the world fixed and
## multiplies the frames by four. If copying grew with frames on screen, the
## second run would ask for four times as many.
func _copying_a_chunk_is_paid_per_chunk_not_per_frame(slow: Dictionary) -> void:
	var fast := _run_render_shell(FIXED_FPS * 4, FRAMES * 4)
	equal(slow["exit_code"], 0, "render shell should exit 0 (output: %s)" % slow["output"])
	equal(fast["exit_code"], 0, "render shell should exit 0 (output: %s)" % fast["output"])

	var slow_counts := _counts_from(slow["output"])
	var fast_counts := _counts_from(fast["output"])
	check(not slow_counts.is_empty(), "render shell did not report its counters: %s"
		% slow["output"])
	check(not fast_counts.is_empty(), "render shell did not report its counters: %s"
		% fast["output"])
	if slow_counts.is_empty() or fast_counts.is_empty():
		return

	equal(slow_counts["frames"], FRAMES, "the shell drew a different number of frames")
	equal(fast_counts["frames"], FRAMES * 4, "the shell drew a different number of frames")
	equal(fast_counts["tick"], slow_counts["tick"],
		"the two runs did not cover the same simulated time, so their copy counts "
		+ "are not comparable")

	# Two things ask the streamer for a chunk now -- the ground view, and the
	# grass grown on it -- and each asks once, when it first needs that chunk. So
	# the count is still one copy per thing built and not one per frame, which is
	# the claim; it is just two things.
	equal(slow_counts["handles"], slow_counts["views"] + slow_counts["patches"],
		"the shell asked for %d copies to draw %d chunks and grow grass on %d of "
		% [slow_counts["handles"], slow_counts["views"], slow_counts["patches"]]
		+ "them: something is copying a chunk it already had")
	equal(fast_counts["handles"], slow_counts["handles"],
		"four times the frames over the same simulated time asked for a different "
		+ "number of chunk copies: the cost grows with frames, not with chunks")
	check(slow_counts["handles"] < slow_counts["frames"],
		"the shell asked for at least one chunk copy per frame (%d copies over %d "
		% [slow_counts["handles"], slow_counts["frames"]] + "frames)")

	# Same world at the end of both, which is the same claim as the check above
	# made from a second angle: frame rate is not part of the simulation.
	equal(_digest_from(fast["output"]), _digest_from(slow["output"]),
		"the same seed over the same simulated time reached different worlds at "
		+ "different frame rates")


func _run_render_shell(fps: int, frames: int) -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", str(fps),
		"--quit-after", str(frames),
		"--",
		"--seed", str(SEED),
	], output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _digest_from(output: String) -> String:
	for line in output.split("\n"):
		var marker := "render-shell stop tick="
		if not line.contains(marker):
			continue
		var at := line.find("digest=")
		if at == -1:
			continue
		return line.substr(at + "digest=".length()).strip_edges()
	return ""


## The integer counters off the shell's stop line, keyed by name. Empty if the
## line is missing.
func _counts_from(output: String) -> Dictionary:
	for line in output.split("\n"):
		if not line.contains("render-shell stop tick="):
			continue
		var counts := {}
		for field in line.strip_edges().split(" "):
			var parts := field.split("=")
			if parts.size() == 2 and parts[1].is_valid_int():
				counts[parts[0]] = parts[1].to_int()
		return counts
	return {}
