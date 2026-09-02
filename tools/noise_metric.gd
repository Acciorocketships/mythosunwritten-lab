extends RefCounted
## How noisy a picture is, as one number.
##
## The number is the standard deviation of the discrete Laplacian of luminance
## over a rectangle of pixels. The Laplacian of a pixel is how far it sits from
## the average of its four neighbours, so a smooth slope of ground scores near
## zero however bright or dark it is, and a stipple of blades that flips light
## and dark from one pixel to the next scores high. That is exactly what
## "noisy" means when someone says a field of grass looks noisy, and it is what
## aliasing does to thin geometry, so it is the number anti-aliasing is judged
## on here.
##
## Shared by tools/measure_noise.gd (which reads a saved frame) and
## tools/measure_aa.gd (which measures frames it renders itself), so the table
## of anti-aliasing modes and a one-off look at a screenshot report the same
## quantity computed by the same code.

## The meadow the user's complaint was measured over: seed 1234 at (228, -60),
## the rows and columns of the default 1152x648 frame that are grass rather than
## sky or foreground. Left as the default so that quoting "the noise number"
## without further qualification always means the same patch of the same view.
const MEADOW := Rect2i(250, 380, 550, 180)


## Every measurement of one image over one rectangle.
##
## `laplacian_std` is the noise number. `lum_mean` and `lum_std` describe the
## brightness itself: anti-aliasing should flatten the first and leave the
## second roughly alone, and a change that darkens or lightens the picture shows
## up here rather than hiding inside the noise number. `spread` is the 95th
## percentile of luminance minus the 5th, which is the tint story -- how far
## apart the light and dark pixels are, whatever the pixel-to-pixel jitter.
static func measure(image: Image, region: Rect2i) -> Dictionary:
	var clipped := region.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
	if clipped.size.x < 3 or clipped.size.y < 3:
		return {}
	# Luminance is read once per pixel into a plain array, one row of padding on
	# every side (clamped at the image edge), so the Laplacian of a pixel on the
	# rectangle's own border is a real neighbourhood rather than a special case.
	var width := clipped.size.x + 2
	var height := clipped.size.y + 2
	var lum := PackedFloat32Array()
	lum.resize(width * height)
	for row in height:
		var y := clampi(clipped.position.y + row - 1, 0, image.get_height() - 1)
		for column in width:
			var x := clampi(clipped.position.x + column - 1, 0, image.get_width() - 1)
			lum[row * width + column] = image.get_pixel(x, y).get_luminance()

	var values := PackedFloat32Array()
	values.resize(clipped.size.x * clipped.size.y)
	var lum_total := 0.0
	var lap_total := 0.0
	var index := 0
	for row in range(1, height - 1):
		for column in range(1, width - 1):
			var here := lum[row * width + column]
			var lap := 4.0 * here \
				- lum[(row - 1) * width + column] \
				- lum[(row + 1) * width + column] \
				- lum[row * width + column - 1] \
				- lum[row * width + column + 1]
			values[index] = here
			index += 1
			lum_total += here
			lap_total += lap

	var count := float(values.size())
	var lum_mean := lum_total / count
	var lap_mean := lap_total / count
	var lum_var := 0.0
	var lap_var := 0.0
	index = 0
	for row in range(1, height - 1):
		for column in range(1, width - 1):
			var here := lum[row * width + column]
			var lap := 4.0 * here \
				- lum[(row - 1) * width + column] \
				- lum[(row + 1) * width + column] \
				- lum[row * width + column - 1] \
				- lum[row * width + column + 1]
			lum_var += (here - lum_mean) * (here - lum_mean)
			lap_var += (lap - lap_mean) * (lap - lap_mean)
			index += 1

	var sorted := values.duplicate()
	sorted.sort()
	var p05 := sorted[int(count * 0.05)]
	var p95 := sorted[mini(int(count) - 1, int(count * 0.95))]
	return {
		"region": clipped,
		"pixels": int(count),
		"lum_mean": lum_mean,
		"lum_std": sqrt(lum_var / count),
		"laplacian_std": sqrt(lap_var / count),
		"p05": p05,
		"p95": p95,
		"spread": p95 - p05,
	}


## The same measurement, taken from a file on disk.
static func measure_file(path: String, region: Rect2i) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var image := Image.load_from_file(path)
	if image == null:
		return {}
	return measure(image, region)


## One line of the table these numbers are always reported in.
static func line(label: String, found: Dictionary) -> String:
	return "%-22s %8.4f %8.4f %10.4f %8.3f" % [
		label, found["lum_mean"], found["lum_std"], found["laplacian_std"], found["spread"],
	]


static func header() -> String:
	return "%-22s %8s %8s %10s %8s" % ["", "lum mean", "lum std", "lap std", "p95-p5"]
