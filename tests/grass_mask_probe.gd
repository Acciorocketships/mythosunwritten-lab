extends SceneTree
## Print the clearing mask at a fixed list of positions, from a fresh process.
##
## This exists so that "the mask is a pure function of world position and the
## seed" can be *shown* across a process boundary rather than asserted inside
## one. A function that quietly depended on anything else -- a clock, a counter,
## an allocation address, a chunk it was first asked about -- would agree with
## itself perfectly well inside a single run; the only way to catch it is to ask
## a second process that shares nothing with the first.
##
## Two numbers are printed per position, and the second is the control. `pure` is
## the mask asked for the position and the world seed and nothing else. `impure`
## is the same mask function fed this process's own id where the seed goes --
## something that is emphatically not position and not seed. The suite requires
## every `pure` to match and at least one `impure` not to, so a run in which the
## comparison passed because it was comparing nothing cannot be mistaken for a
## run in which the mask is pure.
##
## Run by tests/test_grass.gd. Not a suite itself: it is loaded and run as its
## own process, which is the whole point of it.
##
##   godot --headless --path . --script res://tests/grass_mask_probe.gd -- --seed 5

## The positions, in world units. Deliberately spread across several of the
## clearing field's lattice cells and several of the boundary field's, and
## deliberately not on any round number, so a mask that agreed only at its own
## lattice corners would not pass.
const SPOTS := [
	Vector2(0.0, 0.0),
	Vector2(12.375, -7.5),
	Vector2(-133.25, 91.125),
	Vector2(228.0, -60.0),
	Vector2(-512.5, -640.25),
	Vector2(1024.75, 2048.125),
	Vector2(-3333.5, 777.25),
	Vector2(96.0, -240.0),
]


func _initialize() -> void:
	var world_seed := 1234
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			world_seed = args[i + 1].to_int()
	# Something that is not position and not seed, and that a second process
	# cannot possibly share.
	var not_the_seed := world_seed ^ OS.get_process_id()
	for spot in SPOTS:
		print("mask %s %s %s %s" % [
			var_to_str(spot.x), var_to_str(spot.y),
			var_to_str(GrassLayer.clearing_at(spot.x, spot.y, world_seed)),
			var_to_str(GrassLayer.clearing_at(spot.x, spot.y, not_the_seed)),
		])
	quit(0)
