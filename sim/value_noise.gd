extends RefCounted
## Fractal value noise, sampled per world position.
##
## This is the shape every continuous field in the generation stack is made of:
## a few layers of smoothly interpolated random values, each layer half as tall
## and twice as fine as the one before, which is what gives broad regions with
## smaller wobbles riding on them.
##
## Every layer's lattice value is a *hash of the lattice corner* rather than a
## draw from a stream. A stream is the wrong tool for something sampled per
## position, because its numbers depend on how many were drawn before them --
## two chunks covering the same ground would then disagree about it. Hashing
## makes a sample a pure function of (position, seed, layer): the order samples
## are asked for, and the process they are asked in, cannot change any answer.
##
## The height field and the biome fields are the same arithmetic with different
## seeds and periods, so they share this one implementation.
class_name ValueNoise

## How many layers are summed. More layers means finer detail and more work.
var octaves: int = 4

## World units across one lattice cell of the coarsest layer -- roughly the
## width of the broadest features.
var period: float = 96.0

## Peak contribution of the coarsest layer.
var amplitude: float = 1.0

## Each layer after the first is this much finer...
var lacunarity: float = 2.0

## ...and this much shorter.
var gain: float = 0.5

## The seed this field descends from.
var field_seed: int = 0


func _init(
	seed_value: int = 0,
	octave_count: int = 4,
	base_period: float = 96.0,
	base_amplitude: float = 1.0,
	layer_lacunarity: float = 2.0,
	layer_gain: float = 0.5,
) -> void:
	field_seed = seed_value
	octaves = octave_count
	period = base_period
	amplitude = base_amplitude
	lacunarity = layer_lacunarity
	gain = layer_gain


## A detached copy: the same six numbers in a field of its own.
##
## A field is *not* immutable -- its six numbers are plain vars, so anyone
## holding one can retune it and change every height it answers. That is why
## anything handed outside the simulation has to hand over one of these rather
## than the field it is sampling from: a holder that writes into a copy moves
## nothing but the copy.
func detached_copy() -> ValueNoise:
	return ValueNoise.new(field_seed, octaves, period, amplitude, lacunarity, gain)


## The six numbers that decide what this field answers, at fixed precision, for
## folding into the fingerprint of whatever holds the field. Two fields with the
## same text answer the same thing everywhere; two with different text do not,
## which is what lets a fingerprint notice a retuned field.
func parameter_text() -> String:
	return "seed=%d oct=%d period=%.4f amp=%.4f lac=%.4f gain=%.4f" % [
		field_seed, octaves, period, amplitude, lacunarity, gain,
	]


## The field's value at a world position. Roughly in [-amplitude, amplitude];
## the extremes need every layer to peak at once, so they are rare.
func sample(x: float, z: float) -> float:
	var total := 0.0
	var layer_period := period
	var layer_amplitude := amplitude
	for octave in octaves:
		total += layer_amplitude * _layer(octave, x / layer_period, z / layer_period)
		layer_period /= lacunarity
		layer_amplitude *= gain
	return total


## The same layers folded into ridges, summed: `1 - |value|` per layer instead
## of the value itself, in [0, sum of the layer amplitudes].
##
## The fold is what turns a field of rounded swells into a field of ridges. An
## ordinary layer has its maximum at isolated points; a folded one has its
## maximum wherever the raw layer crosses zero, and the set of positions where a
## smooth field is zero is a *curve*. So the tops of this are lines running
## across the world rather than dots, which is what a mountain range is and what
## a river band already uses the same trick for.
##
## The fold does not change how steep a layer can be -- `1 - |v|` has the same
## slope as `v` everywhere except exactly at the crease -- so a field summed
## this way is no harder to walk on than the same field sampled the ordinary
## way. It only moves where the high ground is.
func ridged_sample(x: float, z: float) -> float:
	var total := 0.0
	var layer_period := period
	var layer_amplitude := amplitude
	for octave in octaves:
		total += layer_amplitude * (
			1.0 - absf(_layer(octave, x / layer_period, z / layer_period))
		)
		layer_period /= lacunarity
		layer_amplitude *= gain
	return total


## The same value squashed into [0, 1], which is the form the biome axes want.
##
## The squash is a soft one rather than a clamp of sample() / theoretical range:
## the theoretical range is almost never reached, so dividing by it would leave
## every axis bunched around the middle and the far ends of the biome space
## unreachable. This maps the *typical* range onto [0, 1] and lets the rare
## extremes clip.
func unit_sample(x: float, z: float) -> float:
	return clampf(0.5 + 0.5 * sample(x, z) / _typical_range(), 0.0, 1.0)


## The amplitude a sample usually stays inside: the first layer plus a shrinking
## share of the rest, rather than the sum of every layer at full stretch.
func _typical_range() -> float:
	var total := 0.0
	var layer_amplitude := amplitude
	for octave in octaves:
		total += layer_amplitude
		layer_amplitude *= gain
	return maxf(0.0001, total * 0.62)


## One layer of smoothly interpolated lattice values, in [-1, 1].
func _layer(octave: int, u: float, v: float) -> float:
	var cell_u := floori(u)
	var cell_v := floori(v)
	var frac_u := u - float(cell_u)
	var frac_v := v - float(cell_v)
	# Ease the blend at cell borders, so the seams between lattice cells do not
	# show up as creases in the field.
	var weight_u := _smooth(frac_u)
	var weight_v := _smooth(frac_v)

	var bottom := lerpf(_corner(octave, cell_u, cell_v), _corner(octave, cell_u + 1, cell_v), weight_u)
	var top := lerpf(
		_corner(octave, cell_u, cell_v + 1),
		_corner(octave, cell_u + 1, cell_v + 1),
		weight_u,
	)
	return lerpf(bottom, top, weight_v)


## The lattice value at one integer corner of one layer, in [-1, 1].
func _corner(octave: int, cell_u: int, cell_v: int) -> float:
	# The octave is folded into the seed so that the layers do not repeat each
	# other, and the whole thing is a hash rather than a stream so that the
	# order corners are asked for cannot change any of the answers.
	var seed_for_layer := field_seed + octave * 0x51ED2701
	return SimRng.hash_unit(seed_for_layer, cell_u, cell_v) * 2.0 - 1.0


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
