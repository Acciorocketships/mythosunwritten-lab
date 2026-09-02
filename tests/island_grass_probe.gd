extends SceneTree
## Grow the grass on a fixed list of islands, from a fresh process, and print a
## fingerprint of each.
##
## This exists so that "an island's grass is the same island's grass in every
## process" can be *shown* across a process boundary rather than asserted inside
## one. A layer that quietly depended on anything else -- a clock, a counter, the
## order islands happened to stream in, an allocation address -- would agree with
## itself perfectly well inside a single run; the only way to catch it is to ask
## a second process that shares nothing with the first.
##
## Two fingerprints are printed per island, and the second is the control.
## `pure` is the grass grown from the world seed, the island's cell, its band and
## the island's own lattice. `impure` is the same island grown by a layer built
## on this process's own id where the seed goes -- something that is emphatically
## not the island and not the seed. The suite requires every `pure` to match and
## at least one `impure` not to, so a run in which the comparison passed because
## it was comparing nothing cannot be mistaken for a run in which the grass is
## a function of the island.
##
## Run by tests/test_grass.gd. Not a suite itself: it is loaded and run as its
## own process, which is the whole point of it.
##
##   godot --headless --path . --script res://tests/island_grass_probe.gd -- --seed 5

## How many cells either way to scan for islands. Small: what is wanted is a
## handful of islands that both processes agree on, not a survey.
const SCAN_CELLS := 4


func _initialize() -> void:
	var world_seed := 1234
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			world_seed = args[i + 1].to_int()
	# Something that is not the island and not the seed, and that a second
	# process cannot possibly share.
	var not_the_seed := world_seed ^ OS.get_process_id()

	var world := SimWorld.new(world_seed)
	var mesher := IslandMesher.new()
	var pure := GrassLayer.new(world.terrain, world_seed)
	var impure := GrassLayer.new(world.terrain, not_the_seed)

	for band in FloatingIsland.WALKABLE_BANDS:
		for cell_x in range(-SCAN_CELLS, SCAN_CELLS + 1):
			for cell_z in range(-SCAN_CELLS, SCAN_CELLS + 1):
				var island := world.island_field.island_in_cell(band, Vector2i(cell_x, cell_z))
				if island == null or not island.walkable:
					continue
				var geometry := mesher.build(island)
				print("islandgrass %d %d %d %s %s" % [
					band, cell_x, cell_z,
					_digest(pure.build_island(geometry, island)),
					_digest(impure.build_island(geometry, island)),
				])
	quit(0)


## A fingerprint of one island's grass: how many patches, and the whole instance
## buffer hashed at fixed precision so it does not depend on how floats print.
func _digest(view: MultiMeshInstance3D) -> String:
	if view == null:
		return "0/none"
	var buffer: PackedFloat32Array = view.multimesh.buffer
	var count := view.multimesh.instance_count
	var parts := PackedStringArray()
	for value in buffer:
		parts.append("%.5f" % value)
	var digest := "|".join(parts).sha256_text().substr(0, 16)
	view.free()
	return "%d/%s" % [count, digest]
