extends TestSuite
## The random number generator is the root of every determinism guarantee, so it
## is checked on its own before anything that depends on it.
class_name TestRng


func _init() -> void:
	suite_name = "rng"


func run() -> void:
	_same_seed_repeats()
	_different_seeds_diverge()
	_forks_are_independent()
	_values_stay_in_range()


func _same_seed_repeats() -> void:
	var a := SimRng.new(42)
	var b := SimRng.new(42)
	for i in 100:
		equal(a.next_u32(), b.next_u32(), "seed 42 draw %d should repeat" % i)


func _different_seeds_diverge() -> void:
	var a := SimRng.new(42)
	var b := SimRng.new(43)
	var same := 0
	for i in 100:
		if a.next_u32() == b.next_u32():
			same += 1
	check(same < 5, "seeds 42 and 43 produced %d identical draws out of 100" % same)


func _forks_are_independent() -> void:
	var root := SimRng.new(7)
	var left := root.fork("terrain")
	var right := root.fork("weather")
	not_equal(left.get_state(), right.get_state(),
		"forks with different labels should start from different states")

	# Forking is reproducible: same parent seed and same label, same stream.
	var again := SimRng.new(7).fork("terrain")
	for i in 20:
		equal(left.next_u32(), again.next_u32(), "fork 'terrain' draw %d should repeat" % i)


func _values_stay_in_range() -> void:
	var rng := SimRng.new(11)
	var min_seen := 1.0
	var max_seen := 0.0
	for i in 1000:
		var v := rng.next_float()
		check(v >= 0.0 and v < 1.0, "next_float() returned %f, outside [0, 1)" % v)
		min_seen = minf(min_seen, v)
		max_seen = maxf(max_seen, v)
	check(min_seen < 0.1, "1000 draws never went below 0.1 (lowest was %f)" % min_seen)
	check(max_seen > 0.9, "1000 draws never went above 0.9 (highest was %f)" % max_seen)

	var rng_int := SimRng.new(12)
	for i in 200:
		var n := rng_int.next_int(3, 9)
		check(n >= 3 and n <= 9, "next_int(3, 9) returned %d" % n)
	equal(rng_int.next_int(5, 5), 5, "next_int with an empty range should return the bound")
