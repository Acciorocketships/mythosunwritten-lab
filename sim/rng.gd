extends RefCounted
## Deterministic pseudo-random number generator, written out by hand.
##
## The engine ships a RandomNumberGenerator, but the simulation layer does not
## use it: this class is plain integer arithmetic so the same seed produces the
## same stream on any host that has 64-bit integers, engine or not. Everything
## is masked to 32 bits, so every intermediate value stays non-negative and the
## shifts below behave identically regardless of how the host signs them.
class_name SimRng

const MASK := 0xFFFFFFFF

var _state: int = 0


func _init(seed_value: int = 0) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	# Fold the (possibly 64-bit, possibly negative) seed into 32 bits, then run
	# it through the mixer so nearby seeds do not produce nearby streams.
	var folded := (seed_value ^ (seed_value >> 32)) & MASK
	_state = _mix(folded ^ 0x9E3779B9)


func get_state() -> int:
	return _state


func set_state(state: int) -> void:
	_state = state & MASK


## An independent stream derived from this one, addressed by a text label.
## Used so that adding a new consumer of randomness cannot shift the numbers
## every existing consumer sees.
func fork(label: String) -> SimRng:
	var h := 0x811C9DC5
	for i in label.length():
		h = ((h ^ label.unicode_at(i)) * 0x01000193) & MASK
	var child := SimRng.new()
	child.set_state(_mix(_state ^ h))
	return child


## Next raw 32-bit value.
func next_u32() -> int:
	# A 32-bit linear congruential step, whose low bits are weak, followed by a
	# bit-mixing finalizer that spreads the good high bits over the whole word.
	_state = (_state * 1664525 + 1013904223) & MASK
	return _mix(_state)


## Uniform float in [0, 1).
func next_float() -> float:
	return float(next_u32()) / 4294967296.0


## Uniform float in [low, high).
func next_range(low: float, high: float) -> float:
	return low + (high - low) * next_float()


## Uniform integer in [low, high] inclusive.
func next_int(low: int, high: int) -> int:
	if high <= low:
		return low
	return low + (next_u32() % (high - low + 1))


static func _mix(x: int) -> int:
	x &= MASK
	x ^= x >> 16
	x = (x * 0x7FEB352D) & MASK
	x ^= x >> 15
	x = (x * 0x846CA68B) & MASK
	x ^= x >> 16
	return x


## A value hashed from a position rather than drawn from a stream.
##
## A stream is the wrong tool for a field sampled per world position: its
## numbers depend on how many were drawn before, so two chunks covering the
## same ground would disagree about it. These are stateless -- the same inputs
## always give the same value, whatever has been generated before or beside it.
static func hash_ints(a: int, b: int, c: int) -> int:
	var h := _mix((a & MASK) ^ 0x9E3779B9)
	h = _mix(h ^ ((b * 0x85EBCA6B) & MASK))
	h = _mix(h ^ ((c * 0xC2B2AE35) & MASK))
	return h


## The same hash as a float in [0, 1).
static func hash_unit(a: int, b: int, c: int) -> float:
	return float(hash_ints(a, b, c)) / 4294967296.0
